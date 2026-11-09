extends SceneTree

const Enemy = preload("res://scripts/enemy.gd")
const Projectile = preload("res://scripts/staff_projectiles.gd")
const RIFLE := {"element": "physical", "damage": 49.5, "projectile_range": 9.0, "projectile_speed": 22.0, "projectile_radius": 0.10, "knockback": 2.0, "pierce_after_exit": 0.55}
var checks := 0
var failures: Array[String] = []
var scene: Node3D
var manager
var hits: Array[int] = []
var events: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
var element_impacts: Array[Dictionary] = []

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
	await _test_fixed_short_pierce()
	await _test_subdivision_and_same_enemy()
	await _test_first_surface_geometry()
	await _test_callback_movement_and_invalid_targets()
	await _test_real_cover_order()
	await _test_launch_cutoff()
	await _test_range_boundary()
	await _test_arbitrary_heading()
	await _test_lifecycle_and_guards()
	if is_instance_valid(scene): scene.free()
	print("RIFLE PROJECTILE TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _fresh() -> void:
	if is_instance_valid(scene): scene.free()
	scene = Node3D.new()
	root.add_child(scene)
	manager = Projectile.new()
	scene.add_child(manager)
	hits.clear()
	events.clear()
	impacts.clear()
	element_impacts.clear()
	manager.impact.connect(func(position: Vector3, reason: String): impacts.append({"position": position, "reason": reason}))
	manager.damage_hit.connect(func(enemy, damage: float, knock: Vector3, element: String): events.append({"id": enemy.get_instance_id(), "damage": damage, "knock": knock, "element": element}))
	manager.impact_element.connect(func(position: Vector3, reason: String, element: String): element_impacts.append({"position": position, "reason": reason, "element": element}))
	await physics_frame
	await physics_frame

func _enemy(x: float, z := 0.0, kind := "dummy"):
	var enemy = Enemy.new()
	enemy.kind = kind
	scene.add_child(enemy)
	enemy.position = Vector3(x, 0, z)
	return enemy

func _wall(x: float, layer := 1) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 2.0, 2.0)
	collider.shape = box
	body.add_child(collider)
	scene.add_child(body)
	body.position = Vector3(x, 0.6, 0)

func _hit(enemy, damage: float, knock: Vector3) -> void:
	hits.append(enemy.get_instance_id())
	enemy.receive_damage(damage, knock)

func _spawn(where := Vector3(0, 0.9, 0), definition: Dictionary = RIFLE) -> bool:
	return manager.spawn_fireball(where, Vector3.RIGHT, definition, null)

func _tick(delta: float, enemies: Array, callback: Callable = _hit) -> void:
	manager.tick(delta, enemies, scene.get_world_3d(), callback, null)

func _record() -> Dictionary:
	return manager.resolved.back() if not manager.resolved.is_empty() else {}

func _test_fixed_short_pierce() -> void:
	# First-hit consumption, later-hit extension, or array ordering would break this.
	for reverse in [false, true]:
		await _fresh()
		var first = _enemy(2.0)
		var near_target = _enemy(3.0)
		var third = _enemy(3.6)
		var far_target = _enemy(4.2)
		_check(_spawn(), "rifle flight accepts explicit short penetration")
		_near(first.health, 1000.0, "spawning does not deal rifle damage")
		_tick(1000.0, [far_target, third, near_target, first] if reverse else [first, near_target, third, far_target])
		_near(first.health, 950.5, "first target receives configured physical damage once")
		_near(near_target.health, 950.5, "one-meter aligned center gap is inside short penetration")
		_near(third.health, 1000.0, "second hit never refreshes the first cutoff")
		_near(far_target.health, 1000.0, "2.2-meter separated target is outside penetration")
		_check(hits == [first.get_instance_id(), near_target.get_instance_id()], "one long frame processes contacts in swept order")
		_check(manager.active.is_empty() and _record().get("reason") == "pierce_limit", "short penetration terminates with a distinct reason")
		_near(_record().get("position", Vector3.ZERO).x, 3.01, "terminal position is first expanded exit plus .55")
		_near(_record().get("pierce_cutoff", -1.0), 3.01, "resolution exposes the fixed muzzle-relative cutoff")
		_check(_record().get("hitids", []) == hits, "resolution retains ordered unique hit IDs")
		_check(events.size() == 2 and impacts.size() == 3 and element_impacts.size() == 3, "each contact emits once and expiry never emits damage")
		if events.size() == 2:
			_check(events[1].element == "physical" and events[1].knock == Vector3(2, 0, 0), "pierced event preserves element and knockback")
		_tick(100.0, [first, near_target])
		_check(hits.size() == 2, "resolved flight cannot deal delayed or terminal duplicate damage")

func _test_subdivision_and_same_enemy() -> void:
	# Removing per-flight ID memory or resetting the cutoff per frame would break this.
	await _fresh()
	var first = _enemy(2.0)
	var second = _enemy(3.0)
	_spawn()
	for index in range(240): _tick(1.0 / 240.0, [second, first, first])
	_check(hits == [first.get_instance_id(), second.get_instance_id()], "small frames and duplicate inputs hit each enemy only once")
	_near(first.health, 950.5, "remaining inside a living enemy never repeats damage")
	_near(_record().get("position", Vector3.ZERO).x, 3.01, "subdivided flight expires at the same cutoff as a long frame")
	await _fresh()
	first = _enemy(2.0)
	_spawn()
	_tick(0.075, [first])
	_check(manager.active.size() == 1 and hits.size() == 1, "first enemy impact keeps a short-pierce projectile alive")
	first.position.x = 2.6
	_tick(1.0, [first, first])
	_check(hits.size() == 1, "a previously hit enemy moved ahead cannot take another hit")
	_near(_record().get("position", Vector3.ZERO).x, 3.01, "moving the first target later cannot move the locked cutoff")

func _test_first_surface_geometry() -> void:
	# Center-plus-range or entry-plus-range would give the wrong elite/off-axis cutoff.
	await _fresh()
	var elite = _enemy(2.0, 0.0, "elite")
	var inside = _enemy(3.65)
	var outside = _enemy(3.68)
	_spawn()
	_tick(1.0, [outside, inside, elite])
	_near(elite.health, 100.5, "first elite takes rifle damage")
	_near(inside.health, 950.5, "elite far surface permits the last inside target")
	_near(outside.health, 1000.0, "elite exit cutoff excludes the next target")
	_near(_record().get("position", Vector3.ZERO).x, 3.20, "elite expanded radius .65 sets the far surface")
	await _fresh()
	var off_axis = _enemy(2.0, 0.30)
	inside = _enemy(3.35)
	outside = _enemy(3.37)
	_spawn()
	_tick(1.0, [outside, inside, off_axis])
	_near(inside.health, 950.5, "off-axis first exit includes the just-inside target")
	_near(outside.health, 1000.0, "off-axis exit is shorter than center plus radius")
	_near(_record().get("position", Vector3.ZERO).x, 2.8987119, "off-axis cutoff uses the swept chord far root")
	await _fresh()
	var closer_center = _enemy(2.0)
	var earlier_edge = _enemy(2.1, 0.0, "elite")
	_spawn()
	_tick(1.0, [closer_center, earlier_edge])
	_check(hits.size() == 2 and hits[0] == earlier_edge.get_instance_id(), "first entry edge rather than center order chooses cutoff owner")
	_near(_record().get("position", Vector3.ZERO).x, 3.30, "cutoff belongs to the earliest elite surface")

func _test_callback_movement_and_invalid_targets() -> void:
	# Snapshotting all hits before callbacks or retaining dead/invalid entries breaks this.
	await _fresh()
	var dead = _enemy(0.7)
	dead.receive_damage(2000.0, Vector3.ZERO)
	var invalid = _enemy(1.0)
	invalid.free()
	var first = _enemy(2.0)
	var moved_out = _enemy(2.8)
	var moved_in = _enemy(4.2)
	_spawn()
	_tick(1.0, [dead, invalid, null, moved_in, moved_out, first, first], func(enemy, damage: float, knock: Vector3):
		_hit(enemy, damage, knock)
		if enemy == first:
			first.position.x = 8.0
			moved_out.position.z = 4.0
			moved_in.position.x = 3.0)
	_check(hits == [first.get_instance_id(), moved_in.get_instance_id()], "each next contact rechecks callback-moved and live targets")
	_near(moved_out.health, 1000.0, "enemy moved off the line during first callback is not hit")
	_near(_record().get("position", Vector3.ZERO).x, 3.01, "first far surface is captured before callback movement")

func _test_real_cover_order() -> void:
	# Uses actual collision-mask-one ray queries, including ties after a first hit.
	await _fresh()
	_wall(1.0)
	var first = _enemy(2.0)
	await physics_frame
	await physics_frame
	_spawn()
	_tick(100.0, [first])
	_check(hits.is_empty() and _record().get("reason") == "cover", "cover before first target prevents all damage")
	_near(_record().get("position", Vector3.ZERO).x, 0.9, "near cover resolves at its real surface")
	await _fresh()
	_wall(2.9)
	first = _enemy(2.0)
	var tied = _enemy(3.26)
	await physics_frame
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 0.9, 0), Vector3(4, 0.9, 0), 1)
	_check(not scene.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "cover fixture exists in the actual physics world")
	_spawn()
	_tick(100.0, [tied, first])
	_near(first.health, 950.5, "first target ahead of wall is still damaged")
	_near(tied.health, 1000.0, "wall wins equal-distance next-enemy contact")
	_check(_record().get("reason") == "cover" and events.size() == 1, "cover after first hit stops short penetration immediately")
	_near(_record().get("position", Vector3.ZERO).x, 2.8, "post-enemy cover retains real surface")
	await _fresh()
	_wall(3.5)
	first = _enemy(2.0)
	await physics_frame
	await physics_frame
	_spawn()
	_tick(100.0, [first])
	_check(_record().get("reason") == "pierce_limit", "cover beyond short cutoff cannot steal terminal outcome")
	_near(_record().get("position", Vector3.ZERO).x, 3.01, "sweep is clipped before cover after cutoff")
	await _fresh()
	_wall(1.0, 4)
	first = _enemy(2.0)
	await physics_frame
	await physics_frame
	_spawn()
	_tick(100.0, [first])
	_near(first.health, 950.5, "non-cover collision layers do not block rifle fire")

func _test_launch_cutoff() -> void:
	# A close first exit can put the terminal point behind the visible muzzle.
	for reverse in [false, true]:
		await _fresh()
		var first = _enemy(0.2)
		var near_target = _enemy(1.2)
		var far_target = _enemy(1.8)
		var forward = _enemy(3.0)
		var definition := RIFLE.duplicate()
		definition.launch_origin = Vector3(0, 0.9, 0)
		_spawn(Vector3(2.0, 0.9, 0), definition)
		_near(manager.active[0].node.global_position.x, 2.0, "visual still begins at the physical muzzle")
		_tick(100.0, [forward, far_target, near_target, first] if reverse else [first, near_target, far_target, forward])
		_near(first.health, 950.5, "launch sweep hits close enemy even when muzzle is beyond it")
		_near(near_target.health, 950.5, "launch sweep processes another target before its short cutoff")
		_near(far_target.health, 1000.0, "launch sweep clips targets after cutoff before reaching muzzle")
		_near(forward.health, 1000.0, "launch hit cannot reset into a full forward flight")
		_near(_record().get("position", Vector3.ZERO).x, 1.21, "inside-first launch ends at the true far surface plus .55")
		_near(_record().get("pierce_cutoff", 0.0), -0.79, "pre-muzzle cutoff stays signed relative to visible muzzle")
		_check(_record().get("reason") == "pierce_limit" and hits.size() == 2, "launch resolution has one damage event per target")
	await _fresh()
	var first = _enemy(1.0)
	var next = _enemy(2.0)
	var outside = _enemy(2.6)
	var definition := RIFLE.duplicate()
	definition.launch_origin = Vector3(0, 0.9, 0)
	_spawn(Vector3(1.5, 0.9, 0), definition)
	_tick(100.0, [outside, next, first])
	_near(next.health, 950.5, "launch cutoff continues correctly across the muzzle into flight")
	_near(outside.health, 1000.0, "cross-muzzle continuation does not add another .55")
	_near(_record().get("position", Vector3.ZERO).x, 2.01, "cross-muzzle cutoff is a single world point")
	await _fresh()
	_wall(1.1)
	first = _enemy(0.2)
	var behind_wall = _enemy(1.5)
	await physics_frame
	await physics_frame
	definition = RIFLE.duplicate()
	definition.launch_origin = Vector3(0, 0.9, 0)
	_spawn(Vector3(2.0, 0.9, 0), definition)
	_tick(100.0, [behind_wall, first])
	_near(first.health, 950.5, "launch enemy before wall takes damage")
	_near(behind_wall.health, 1000.0, "real wall after first launch contact stops further launch damage")
	_check(_record().get("reason") == "cover", "pre-muzzle wall after enemy owns terminal outcome")
	_near(_record().get("position", Vector3.ZERO).x, 1.0, "pre-muzzle wall is swept before cutoff")

func _test_range_boundary() -> void:
	# Unlimited travel, unclipped exits, or excluding the exact last contact breaks this.
	await _fresh()
	var beyond = _enemy(9.48)
	_spawn()
	_tick(1e300, [beyond])
	_near(beyond.health, 1000.0, "huge finite delta cannot hit after original nine-meter range")
	_check(_record().get("reason") == "range", "unhit rifle retains normal range expiry")
	_near(_record().get("position", Vector3.ZERO).x, 9.0, "unhit rifle ends at nine meters")
	await _fresh()
	var first = _enemy(8.7)
	var edge = _enemy(9.46)
	beyond = _enemy(9.48)
	_spawn()
	_tick(100.0, [beyond, edge, first])
	_near(first.health, 950.5, "first late-range contact is eligible")
	_near(edge.health, 950.5, "target exactly touching original range is eligible")
	_near(beyond.health, 1000.0, "late first hit cannot extend the original range")
	_near(_record().get("position", Vector3.ZERO).x, 9.0, "short cutoff clips to original nine-meter range")
	_near(_record().get("pierce_cutoff", -1.0), 9.0, "reported fixed cutoff is also clipped")

func _test_arbitrary_heading() -> void:
	# World-space projection roundoff must not leave a completed diagonal flight alive.
	await _fresh()
	_check(manager.spawn_fireball(Vector3(0, 0.9, 0), Vector3(1, 0, 1), RIFLE, null), "diagonal rifle direction is accepted")
	_tick(100.0, [])
	_check(manager.active.is_empty() and _record().get("reason") == "range", "one long diagonal frame resolves at original range")
	_near(_record().get("travelled", 0.0), 9.0, "diagonal completed flight records exact range budget")
	_near(_record().get("position", Vector3.ZERO).x, 6.363961, "diagonal range endpoint follows normalized aim")
	await _fresh()
	var first = _enemy(2.0, 2.0)
	var near_target = _enemy(2.7, 2.7)
	var far_target = _enemy(3.2, 3.2)
	manager.spawn_fireball(Vector3(0, 0.9, 0), Vector3(1, 0, 1), RIFLE, null)
	_tick(100.0, [far_target, near_target, first])
	_check(hits == [first.get_instance_id(), near_target.get_instance_id()], "diagonal short penetration uses world distance in swept order")
	_near(far_target.health, 1000.0, "diagonal later target cannot extend cutoff")
	_near(_record().get("position", Vector3.ZERO).x, 2.714178, "diagonal cutoff lies .55 past first expanded far surface")

func _test_lifecycle_and_guards() -> void:
	# Invalid pierce configuration, lost IDs on clear, or unbounded history breaks this.
	await _fresh()
	for value in [0.0, -1.0, INF, NAN, "invalid"]:
		var definition := RIFLE.duplicate()
		definition.pierce_after_exit = value
		_check(not _spawn(Vector3.ZERO, definition), "invalid penetration setting is rejected")
	_check(manager.active.is_empty() and manager.shots_fired == 0, "rejected penetration has no actor or shot side effects")
	for index in range(35):
		_spawn(Vector3(index, 0.9, 5))
		_tick(100.0, [])
	_check(manager.resolved.size() == 32, "rifle history is bounded to the latest 32 flights")
	_spawn()
	for delta in [0.0, -1.0, INF, NAN]: _tick(delta, [])
	_near(manager.active[0].travelled, 0.0, "invalid time never advances rifle flight")
	var before_clear := impacts.size()
	manager.clear()
	_check(manager.active.is_empty() and manager.resolved.is_empty() and manager.shots_fired == 0, "clear resets rifle actors, IDs, counters, and history")
	_check(impacts.size() == before_clear, "clear emits no false rifle impact")
	await _fresh()
	var first = _enemy(2.0)
	var next = _enemy(3.0)
	_spawn()
	manager.damage_hit.connect(func(enemy, damage: float, knock: Vector3, _element: String): enemy.receive_damage(damage, knock))
	_tick(100.0, [first, next], Callable())
	_near(first.health, 950.5, "signal-only consumer applies one first hit without legacy callback")
	_near(next.health, 950.5, "signal-only consumer applies one pierced hit")
	_check(hits.is_empty() and events.size() == 2, "empty callback never suppresses or duplicates hit events")
