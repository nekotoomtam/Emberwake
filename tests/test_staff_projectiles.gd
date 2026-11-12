extends SceneTree

const Enemy = preload("res://scripts/enemy.gd")
const StaffMotion = preload("res://scripts/staff_motion.gd")
var checks := 0
var failures: Array[String] = []
var scene: Node3D
var manager
var hits: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
var projectile_script: Script

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _near(actual: float, expected: float, message: String, tolerance := 0.0001) -> void:
	_check(absf(actual - expected) < tolerance, "%s (got %.6f, expected %.6f)" % [message, actual, expected])

func _run() -> void:
	_check(FileAccess.file_exists("res://scripts/staff_projectiles.gd"), "finite staff projectile module exists")
	if failures.is_empty():
		projectile_script = load("res://scripts/staff_projectiles.gd")
		await _test_spawn_and_flight()
		await _test_nearest_first_contact()
		await _test_entry_point_beats_center_order()
		await _test_range_boundary_and_high_delta()
		await _test_subdivision()
		await _test_real_cover_order()
		await _test_charged_bursts()
		await _test_muzzle_launch_path()
		await _test_dead_invalid_and_elite_targets()
		await _test_clear_and_bounded_history()
		await _test_invalid_inputs()
	if is_instance_valid(scene):
		scene.free()
	print("STAFF PROJECTILE TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _fresh() -> void:
	if is_instance_valid(scene):
		scene.free()
	scene = Node3D.new()
	root.add_child(scene)
	manager = projectile_script.new()
	scene.add_child(manager)
	manager.impact.connect(func(position: Vector3, reason: String): impacts.append({"position": position, "reason": reason}))
	hits.clear()
	impacts.clear()
	await physics_frame
	await physics_frame

func _enemy(where: Vector3, kind := "melee"):
	var enemy = Enemy.new()
	enemy.kind = kind
	scene.add_child(enemy)
	enemy.position = where
	return enemy

func _wall(x: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 2.0, 2.0)
	collider.shape = box
	body.add_child(collider)
	scene.add_child(body)
	body.position = Vector3(x, 0.6, 0)
	return body

func _hit(enemy, damage: float, force: Vector3) -> void:
	hits.append({"id": enemy.get_instance_id(), "damage": damage, "force": force})
	enemy.receive_damage(damage, force)

func _tick(delta: float, enemies: Array) -> void:
	manager.tick(delta, enemies, scene.get_world_3d(), _hit, null)

func _spawn(where := Vector3(0, 0.9, 0), direction := Vector3.RIGHT, definition: Dictionary = {}) -> bool:
	return manager.spawn_fireball(where, direction, definition, null)

func _test_spawn_and_flight() -> void:
	# Catches instant damage, unnormalised direction, and a projectile that never advances.
	await _fresh()
	var enemy = _enemy(Vector3(4, 0, 0))
	_check(_spawn(Vector3(0, 0.9, 0), Vector3(9, 4, 0)), "valid shot spawns")
	_check(hits.is_empty() and enemy.health == 38.0, "spawning alone never damages a target")
	_check(manager.active.size() == 1 and manager.shots_fired == 1, "one release creates exactly one active shot")
	if manager.active.is_empty(): return
	var shot: Dictionary = manager.active[0]
	_check(shot.element == "fire" and shot.direction == Vector3.RIGHT, "shot carries explicit fire and normalised ground aim")
	_tick(0.1, [enemy])
	_near(manager.active[0].node.global_position.x, 0.85, "projectile travels its finite speed")
	_near(manager.active[0].travelled, 0.85, "travel budget tracks actual muzzle displacement")
	_near(manager.active[0].age, 0.1, "visual age advances with flight")
	_check(hits.is_empty(), "target outside the current segment remains undamaged")
	_tick(1.0, [enemy])
	_check(manager.active.is_empty() and hits.size() == 1, "projectile is consumed by its first enemy")
	_near(enemy.health, 14.0, "fireball deals direct damage once")
	_near(hits[0].force.x, 1.4, "damage callback receives the configured ground knockback")
	_check(manager.resolved.back().reason == "enemy" and manager.resolved.back().element == "fire", "impact history retains direct fire outcome")
	_check(impacts.size() == 1 and impacts[0].reason == "enemy", "one impact signal is emitted")
	_tick(10.0, [enemy])
	_near(enemy.health, 14.0, "spent shot never pierces, repeats, or adds burn damage")

func _test_nearest_first_contact() -> void:
	# Catches selecting the first array entry instead of the first swept contact.
	for reverse in [false, true]:
		await _fresh()
		var near_enemy = _enemy(Vector3(2, 20, 0))
		var far_enemy = _enemy(Vector3(3, 0, 0))
		_spawn()
		_tick(2.0, [far_enemy, near_enemy] if reverse else [near_enemy, far_enemy])
		_near(near_enemy.health, 14.0, "nearest ground target is hit independent of height and array order")
		_near(far_enemy.health, 38.0, "farther monster is protected by the first hit")
		_near(manager.resolved.back().travelled, 1.46, "normal target contact uses expanded ground circle entry")
		_near(manager.resolved.back().position.x, 1.46, "impact occurs on contact rather than the end of a long frame")

func _test_entry_point_beats_center_order() -> void:
	# Catches sorting target centers or closest-point projections instead of circle entry.
	await _fresh()
	var closer_center = _enemy(Vector3(2, 0, 0))
	var earlier_edge = _enemy(Vector3(2.1, 0, 0), "elite")
	_spawn()
	_tick(1.0, [closer_center, earlier_edge])
	_near(earlier_edge.health, 126.0, "larger enemy whose edge comes first receives the shot")
	_near(closer_center.health, 38.0, "closer center does not override an earlier collision edge")
	_near(manager.resolved.back().travelled, 1.37, "elite ground circle has its actual combat radius")
	await _fresh()
	var off_axis = _enemy(Vector3(1.8, 0, 0.5))
	var on_axis = _enemy(Vector3(2, 0, 0))
	_spawn()
	_tick(1.0, [off_axis, on_axis])
	_near(on_axis.health, 14.0, "on-axis entry precedes the nearer off-axis center")
	_near(off_axis.health, 38.0, "grazing target cannot steal an earlier collision")

func _test_range_boundary_and_high_delta() -> void:
	# Catches checking enemies on an unclamped segment and missing the exact range edge.
	await _fresh()
	var edge = _enemy(Vector3(6.54, 0, 0))
	_spawn()
	_tick(1000.0, [edge])
	_near(edge.health, 14.0, "contact exactly at the maximum range is eligible")
	_near(manager.resolved.back().travelled, 6.0, "range-edge hit never exceeds its budget")
	await _fresh()
	var beyond = _enemy(Vector3(6.56, 0, 0))
	_spawn()
	_tick(1000.0, [beyond])
	_near(beyond.health, 38.0, "even a huge frame cannot hit beyond maximum range")
	_check(manager.active.is_empty() and manager.resolved.back().reason == "range", "unhit projectile expires at its range")
	_near(manager.resolved.back().position.x, 6.0, "range expiry position is clamped")
	await _fresh()
	_spawn(Vector3(0, 0.9, 0), Vector3.RIGHT, {"damage": 12.0, "projectile_range": 2.0, "projectile_speed": 1.0, "projectile_radius": 0.1, "knockback": 2.0})
	_tick(1.0, [])
	_near(manager.active[0].travelled, 1.0, "canonical projectile speed controls flight")
	_tick(100.0, [])
	_near(manager.resolved.back().travelled, 2.0, "canonical projectile range controls expiry")

func _test_subdivision() -> void:
	# Catches tunnelling or frame-count-dependent flight and damage.
	await _fresh()
	var target = _enemy(Vector3(4, 0, 0))
	_spawn()
	for index in range(120):
		_tick(1.0 / 120.0, [target])
	_near(target.health, 14.0, "subdivided flight still damages only once")
	_near(manager.resolved.back().travelled, 3.46, "subdivided collision has the same entry as one long frame")

func _test_real_cover_order() -> void:
	# Uses actual PhysicsDirectSpaceState cover, not a collision mock.
	await _fresh()
	_wall(2.0)
	var behind = _enemy(Vector3(3, 0, 0))
	await physics_frame
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0, 0.9, 0), Vector3(4, 0.9, 0), 1)
	_check(not scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "cover fixture is present in the real physics world")
	_spawn()
	_tick(1.0, [behind])
	_near(behind.health, 38.0, "nearer solid wall blocks damage behind it")
	_check(manager.resolved.back().reason == "cover", "wall collision consumes the shot")
	_near(manager.resolved.back().position.x, 1.9, "cover impact uses the real wall surface")
	await _fresh()
	_wall(2.0)
	var before = _enemy(Vector3(1.2, 0, 0))
	await physics_frame
	await physics_frame
	_spawn()
	_tick(1.0, [before])
	_near(before.health, 14.0, "target before cover is hit first in the same long segment")
	_check(manager.resolved.back().reason == "enemy", "later wall cannot cancel a nearer enemy contact")
	await _fresh()
	_wall(2.0)
	var equal = _enemy(Vector3(2.44, 0, 0))
	await physics_frame
	await physics_frame
	_spawn()
	_tick(1.0, [equal])
	_near(equal.health, 38.0, "solid cover wins equal-distance contact")

func _test_charged_bursts() -> void:
	var staff := StaffMotion.new()
	staff.set_cast_tier(2)
	var middle := staff.definition(0)
	await _fresh()
	var primary = _enemy(Vector3(3, 0, 0))
	var side = _enemy(Vector3(3, 0, 1.2))
	for target in [primary, side]: target.health = 500.0
	_spawn(Vector3(0, .9, 0), Vector3.RIGHT, middle)
	_tick(1.0, [side, primary])
	_near(500.0 - primary.health, 84.0, "middle charge direct target is excluded from splash")
	_near(500.0 - side.health, 36.0, "middle charge deals splash to a nearby off-axis target")
	await _fresh()
	side = _enemy(Vector3(6, 0, 1.25))
	side.health = 500.0
	_spawn(Vector3(0, .9, 0), Vector3.RIGHT, middle)
	_tick(1.0, [side])
	_check(manager.resolved.back().reason == "range", "charged fireball reaches the range limit")
	_near(500.0 - side.health, 36.0, "a near miss can be caught by the burst at maximum range")
	await _fresh()
	_wall(2.0)
	side = _enemy(Vector3(1.45, 0, .82))
	var behind = _enemy(Vector3(2.6, 0, .1))
	for target in [side, behind]: target.health = 500.0
	await physics_frame
	await physics_frame
	_spawn(Vector3(0, .9, 0), Vector3.RIGHT, middle)
	_tick(1.0, [side, behind])
	_check(manager.resolved.back().reason == "cover", "charged fireball bursts at the wall")
	_near(500.0 - side.health, 36.0, "wall burst hits the exposed side")
	_near(500.0 - behind.health, 0.0, "wall blocks splash damage on the other side")
	staff.set_cast_tier(3)
	var full := staff.definition(0)
	await _fresh()
	primary = _enemy(Vector3(3, 0, 0))
	var second = _enemy(Vector3(4.4, 0, 0))
	side = _enemy(Vector3(4.1, 0, 1.5))
	for target in [primary, second, side]: target.health = 500.0
	_spawn(Vector3(0, .9, 0), Vector3.RIGHT, full)
	_tick(1.0, [side, second, primary])
	var record: Dictionary = manager.resolved.back()
	_check(record.reason == "hit_limit" and record.hitids.size() == 2, "full charge bursts after two direct hits")
	_near(500.0 - primary.health, 135.0, "first direct target takes full damage once")
	_near(500.0 - second.health, 101.25, "second direct target takes reduced damage once")
	_near(500.0 - side.health, 65.0, "full charge burst hits a third, off-axis target")
	await _fresh()
	primary = _enemy(Vector3(3, 0, 0))
	second = _enemy(Vector3(6, 0, 0))
	for target in [primary, second]: target.health = 500.0
	_spawn(Vector3(0, .9, 0), Vector3.RIGHT, full)
	_tick(1.0, [second, primary])
	record = manager.resolved.back()
	_check(record.reason == "pierce_limit" and record.hitids.size() == 1, "full charge stops when there is no nearby second contact")
	_near(record.position.distance_to(record.first_exit_position), .75, "the remaining flight starts at the first target's exit")
	_near(500.0 - second.health, 65.0, "a target past penetration reach only takes splash damage")

func _test_muzzle_launch_path() -> void:
	# Catches a physical staff tip spawning beyond nearby monsters or through solid cover.
	await _fresh()
	var close = _enemy(Vector3(0.9, 0, 0))
	var far_enemy = _enemy(Vector3(2.5, 0, 0))
	_check(_spawn(Vector3(1.58, 0.9, 0), Vector3.RIGHT, {"launch_origin": Vector3(0, 0.9, 0)}), "staff-tip shot accepts a finite launch origin")
	_near(manager.active[0].node.global_position.x, 1.58, "visible shot begins at the physical staff tip")
	_near(close.health, 38.0, "close enemy is not damaged until flight is ticked")
	_tick(1.0, [far_enemy, close])
	_near(close.health, 14.0, "launch safety sweep catches a monster between player and staff tip")
	_near(far_enemy.health, 38.0, "launch collision consumes the shot before normal travel")
	_near(manager.resolved.back().travelled, 0.0, "launch safety does not consume the muzzle range budget")
	_near(manager.resolved.back().position.x, 0.36, "close impact uses earliest launch-segment contact")
	await _fresh()
	_wall(0.8)
	var behind = _enemy(Vector3(2.5, 0, 0))
	await physics_frame
	await physics_frame
	_spawn(Vector3(1.58, 0.9, 0), Vector3.RIGHT, {"launch_origin": Vector3(0, 0.9, 0)})
	_tick(1.0, [behind])
	_near(behind.health, 38.0, "solid cover between player and muzzle blocks a shot born beyond it")
	_check(manager.resolved.back().reason == "cover", "launch-path obstruction is recorded as cover")
	await _fresh()
	_wall(0.0)
	await physics_frame
	await physics_frame
	_spawn()
	_tick(0.1, [])
	_check(manager.resolved.size() == 1 and manager.resolved.back().reason == "cover", "a shot born inside solid cover is consumed instead of escaping")

func _test_dead_invalid_and_elite_targets() -> void:
	# Catches corpses shielding living monsters and radius drift for elite targets.
	await _fresh()
	var dead = _enemy(Vector3(1, 0, 0))
	dead.receive_damage(100.0, Vector3.ZERO)
	var invalid = _enemy(Vector3(1.5, 0, 0))
	invalid.free()
	var elite = _enemy(Vector3(3, 0, 0.7), "elite")
	_spawn()
	_tick(1.0, [dead, invalid, null, elite])
	_near(elite.health, 126.0, "living elite is hit within its expanded circle after dead and invalid targets")
	_check(hits.size() == 1, "only the living target receives a damage callback")

func _test_clear_and_bounded_history() -> void:
	# Catches stale run actors, counters, and unlimited QA history growth.
	await _fresh()
	for index in range(35):
		_spawn(Vector3(index, 0.9, 5))
		_tick(1.0, [])
	_check(manager.resolved.size() == 32 and manager.shots_fired == 35, "QA history is bounded to the latest 32 impacts")
	_near(manager.resolved[0].position.x, 9.0, "oldest retained resolution belongs to the fourth shot")
	_spawn()
	var node: Node3D = manager.active[0].node
	manager.clear()
	_check(manager.active.is_empty() and manager.resolved.is_empty() and manager.shots_fired == 0, "clear resets actors, history, and counters for a new run")
	_check(not is_instance_valid(node) or node.get_parent() == null, "clear immediately detaches visible projectile nodes")
	_check(impacts.size() == 35, "clear never emits a false impact")

func _test_invalid_inputs() -> void:
	# Catches non-finite or zero inputs corrupting positions, budgets, or counters.
	await _fresh()
	for direction in [Vector3.ZERO, Vector3.UP, Vector3(NAN, 0, 0), Vector3(INF, 0, 0)]:
		_check(not _spawn(Vector3.ZERO, direction), "invalid ground direction is rejected")
	_check(not _spawn(Vector3(INF, 0, 0)), "non-finite muzzle position is rejected")
	for key in ["damage", "projectile_range", "projectile_speed", "projectile_radius", "knockback"]:
		for value in [0.0, -1.0, INF, NAN, "invalid"]:
			_check(not _spawn(Vector3.ZERO, Vector3.RIGHT, {key: value}), "invalid %s is rejected without a shot" % key)
	_check(not _spawn(Vector3.ZERO, Vector3.RIGHT, {"launch_origin": Vector3(NAN, 0, 0)}), "non-finite launch origin is rejected")
	_check(not _spawn(Vector3.ZERO, Vector3.RIGHT, {"launch_origin": "invalid"}), "invalid launch origin type is rejected")
	_check(manager.active.is_empty() and manager.shots_fired == 0, "rejected shots have no actor or counter side effects")
	_spawn()
	for delta in [0.0, -1.0, INF, NAN]:
		_tick(delta, [])
	_near(manager.active[0].travelled, 0.0, "invalid time steps cannot move a valid projectile")
	_near(manager.active[0].age, 0.0, "invalid time steps cannot age a valid projectile")
