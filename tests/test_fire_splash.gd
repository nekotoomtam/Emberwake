extends SceneTree
## Real swept fire contacts, actor damage and world cover; no game-level damage injection.

const Projectile = preload("res://scripts/staff_projectiles.gd")
const Enemy = preload("res://scripts/enemy.gd")
const FIRE := {"element": "fire", "damage": 72.0, "projectile_speed": 5.5, "projectile_range": 6.0, "projectile_radius": 0.18, "knockback": 1.4, "splash_radius": 1.20, "splash_damage": 36.0}
var scene: Node3D
var manager
var hits: Array[Dictionary] = []
var events: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
var areas: Array[Dictionary] = []
var checks := 0
var failures: Array[String] = []

class InvalidEnemy extends Node3D:
	var dead := false
	var health := 10.0
	var kind := "dummy"


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _near(actual: float, expected: float, message: String) -> void:
	_check(absf(actual - expected) < 0.0001, "%s (got %.6f, expected %.6f)" % [message, actual, expected])


func _run() -> void:
	await _fresh()
	_check(manager.has_signal("area_impact"), "projectile manager exposes one typed area-impact event")
	await _test_direct_and_round_geometry()
	await _test_primary_death_and_signal_only()
	await _test_invalid_and_duplicate_targets()
	await _test_splash_cover()
	await _test_cover_and_range_do_not_detonate()
	await _test_launch_safety_and_nearest_cover()
	await _test_large_frames_and_subdivision()
	await _test_physical_and_legacy_no_splash()
	await _test_opt_in_validation_and_clear()
	await _test_clear_during_damage_callbacks()
	if is_instance_valid(scene): scene.free()
	print("FIRE SPLASH TESTS: %d/%d passed" % [checks - failures.size(), checks])
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
	areas.clear()
	manager.damage_hit.connect(func(enemy, damage: float, knock: Vector3, element: String): events.append({"id": enemy.get_instance_id(), "damage": damage, "knock": knock, "element": element}))
	manager.impact_element.connect(func(position: Vector3, reason: String, element: String): impacts.append({"position": position, "reason": reason, "element": element}))
	if manager.has_signal("area_impact"):
		manager.connect("area_impact", func(position: Vector3, radius: float, element: String): areas.append({"position": position, "radius": radius, "element": element}))
	await physics_frame
	await physics_frame


func _enemy(position: Vector3, kind: String = "dummy"):
	var target = Enemy.new()
	target.kind = kind
	scene.add_child(target)
	target.position = position
	return target


func _hit(enemy, damage: float, knock: Vector3) -> void:
	hits.append({"id": enemy.get_instance_id(), "damage": damage})
	enemy.receive_damage(damage, knock)


func _spawn(definition: Dictionary = FIRE, where: Vector3 = Vector3(0, 0.9, 0)) -> bool:
	return manager.spawn_fireball(where, Vector3.RIGHT, definition, null)


func _tick(delta: float, targets: Array, callback: Callable = _hit) -> void:
	manager.tick(delta, targets, scene.get_world_3d(), callback, null)


func _record() -> Dictionary:
	return manager.resolved.back() if not manager.resolved.is_empty() else {}


func _wall(position: Vector3, size: Vector3, layer: int = 1) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = layer
	wall.collision_mask = 0
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	wall.add_child(collider)
	scene.add_child(wall)
	wall.position = position
	return wall


func _test_direct_and_round_geometry() -> void:
	# A square AoE, double primary damage, omitted body radius or added chain blast fails this.
	await _fresh()
	var primary = _enemy(Vector3(2, 0, 0))
	var near_target = _enemy(Vector3(1.46, 0, 0.8))
	var normal_edge = _enemy(Vector3(1.46, 0, 1.56))
	var normal_outside = _enemy(Vector3(1.46, 0, 1.561))
	var elite_edge = _enemy(Vector3(1.46, 0, -1.75), "elite")
	var elite_outside = _enemy(Vector3(1.46, 0, -1.751), "elite")
	var square_corner = _enemy(Vector3(2.66, 0, 1.2))
	_check(_spawn(), "explicit staff splash configuration spawns one fireball")
	_check(hits.is_empty() and areas.is_empty(), "spawning does not apply direct or area damage")
	_tick(100.0, [normal_outside, square_corner, elite_outside, near_target, normal_edge, elite_edge, primary])
	_near(primary.health, 928.0, "primary receives 72 direct damage without its own splash")
	_near(near_target.health, 964.0, "nearby secondary receives 36 splash damage")
	_near(normal_edge.health, 964.0, "normal body touching the 1.20 circle receives splash")
	_near(normal_outside.health, 1000.0, "normal body beyond the circular edge is excluded")
	_near(elite_edge.health, 114.0, "elite .55 body radius participates in the inclusive circular edge")
	_near(elite_outside.health, 150.0, "elite body beyond its expanded circular edge is excluded")
	_near(square_corner.health, 1000.0, "corner inside a bounding box but outside the circle is excluded")
	_check(hits.size() == 4 and events.size() == 4, "direct and three area contacts emit exactly one callback and damage signal each")
	_check(areas.size() == 1 and impacts.size() == 1 and manager.active.is_empty(), "one real enemy detonation resolves and removes the projectile once")
	if areas.size() == 1:
		_near(areas[0].position.x, 1.46, "blast centre is the first swept contact point")
		_near(areas[0].radius, 1.20, "area event carries the exact damage circle radius")
		_check(areas[0].element == "fire", "area event keeps the fire element")
	_near(float(_record().get("splash_radius", -1.0)), 1.20, "resolved detonation records its splash radius")
	var ids: Array = _record().get("splash_hitids", [])
	_check(ids.size() == 3 and primary.get_instance_id() not in ids and near_target.get_instance_id() in ids and normal_edge.get_instance_id() in ids and elite_edge.get_instance_id() in ids, "resolved splash IDs list each secondary and exclude the direct primary")
	_tick(100.0, [primary, near_target, normal_edge, elite_edge])
	_check(hits.size() == 4 and areas.size() == 1, "resolved blast cannot repeat damage or start a chain explosion")


func _test_primary_death_and_signal_only() -> void:
	# A dead primary must not suppress its one blast; signal-only consumers must receive all damage.
	await _fresh()
	var primary = _enemy(Vector3(2, 0, 0), "melee")
	var secondary = _enemy(Vector3(1.46, 0, 1.0))
	_spawn()
	_tick(10.0, [primary, secondary, primary, secondary])
	_check(primary.dead and is_zero_approx(primary.health), "configured direct damage kills a normal primary")
	_near(secondary.health, 964.0, "primary dying during its direct callback still permits its one secondary blast")
	_check(hits.size() == 2 and areas.size() == 1, "duplicate entries cannot repeat the dead primary or its secondary")
	await _fresh()
	primary = _enemy(Vector3(2, 0, 0))
	secondary = _enemy(Vector3(1.46, 0, 1.0))
	manager.damage_hit.connect(func(enemy, damage: float, knock: Vector3, _element: String): enemy.receive_damage(damage, knock))
	_spawn()
	_tick(10.0, [primary, secondary], Callable())
	_near(primary.health, 928.0, "signal-only consumer receives direct damage once")
	_near(secondary.health, 964.0, "signal-only consumer receives area damage once")
	_check(hits.is_empty() and events.size() == 2, "empty legacy callback does not suppress or duplicate damage events")


func _test_invalid_and_duplicate_targets() -> void:
	# Corrupt or duplicate entries cannot steal damage or pollute the blast's unique-ID record.
	await _fresh()
	var primary = _enemy(Vector3(2, 0, 0))
	var secondary = _enemy(Vector3(1.46, 0, 1.0))
	var dead = _enemy(Vector3(1.46, 0, -0.9))
	dead.receive_damage(2000.0, Vector3.ZERO)
	var empty_health = _enemy(Vector3(1.46, 0, -1.0))
	empty_health.health = 0.0
	var corrupt := InvalidEnemy.new()
	scene.add_child(corrupt)
	corrupt.position = Vector3(NAN, 0, 1)
	var invalid_health := InvalidEnemy.new()
	scene.add_child(invalid_health)
	invalid_health.position = Vector3(1.46, 0, 1.1)
	invalid_health.health = NAN
	var removed = Enemy.new()
	removed.free()
	_spawn()
	_tick(10.0, [primary, secondary, secondary, dead, empty_health, corrupt, invalid_health, null, removed])
	_check(hits.size() == 2 and events.size() == 2, "only the live primary and unique valid secondary receive damage")
	_check(_record().get("splash_hitids", []) == [secondary.get_instance_id()], "resolved secondary IDs omit invalid, dead and duplicate entries")


func _test_splash_cover() -> void:
	# Splash queries use real mask-one torso-height rays, not distance alone or arbitrary layers.
	for layer in [1, 2]:
		await _fresh()
		var primary = _enemy(Vector3(2, 0, 0))
		var covered = _enemy(Vector3(1.46, 0, 1.1))
		var clear_target = _enemy(Vector3(2.46, 0, -0.5))
		_wall(Vector3(1.46, 0.68, 0.6), Vector3(0.4, 1.3, 0.1), layer)
		await physics_frame
		await physics_frame
		_spawn()
		_tick(10.0, [covered, clear_target, primary])
		_near(primary.health, 928.0, "splash cover does not hide the direct target")
		_near(covered.health, 1000.0 if layer == 1 else 964.0, "only mask-one cover blocks an otherwise eligible secondary")
		_near(clear_target.health, 964.0, "an uncovered secondary on the other side still takes splash")
		_check(areas.size() == 1, "cover filtering does not duplicate or suppress the real explosion")
	await _fresh()
	var primary = _enemy(Vector3(2, 0, 0))
	var secondary = _enemy(Vector3(1.46, 0, 1.1))
	_wall(Vector3(1.46, -0.2, 0.6), Vector3(0.4, 0.5, 0.1))
	await physics_frame
	await physics_frame
	_spawn()
	_tick(10.0, [secondary, primary])
	_near(secondary.health, 964.0, "low geometry below the .68 torso ray cannot falsely block splash")


func _test_cover_and_range_do_not_detonate() -> void:
	# A wall impact or range expiry must never become an enemy explosion.
	for reason in ["cover", "range"]:
		await _fresh()
		var target = _enemy(Vector3(2, 0, 1.0) if reason == "cover" else Vector3(6, 0, 1.0))
		if reason == "cover": _wall(Vector3(1, 0.68, 0), Vector3(0.2, 2, 2))
		await physics_frame
		await physics_frame
		_spawn()
		_tick(1e300, [target])
		_near(target.health, 1000.0, "non-enemy resolution cannot splash a nearby enemy")
		_check(_record().get("reason") == reason and not _record().has("splash_radius") and not _record().has("splash_hitids"), "non-enemy resolution retains its original reason without blast metadata")
		_check(areas.is_empty() and events.is_empty() and impacts.size() == 1 and manager.active.is_empty(), "non-enemy impact keeps existing feedback without any area event or damage")


func _test_launch_safety_and_nearest_cover() -> void:
	# A visible muzzle beyond a close enemy still uses the original launch sweep and cover priority.
	await _fresh()
	var primary = _enemy(Vector3(0.4, 0, 0))
	var secondary = _enemy(Vector3(0.1, 0, 1.0))
	var definition := FIRE.duplicate()
	definition.launch_origin = Vector3(0, 0.9, 0)
	_spawn(definition, Vector3(2, 0.9, 0))
	_check(hits.is_empty(), "launch safety segment still waits for simulation")
	_tick(0.01, [secondary, primary])
	_near(primary.health, 928.0, "close primary behind the visible muzzle receives direct damage")
	_near(secondary.health, 964.0, "launch-sweep enemy contact receives the same one-off area behavior")
	_check(_record().get("reason") == "enemy" and areas.size() == 1, "launch safety segment resolves as one enemy explosion")
	await _fresh()
	primary = _enemy(Vector3(2, 0, 0))
	secondary = _enemy(Vector3(1.46, 0, 1.0))
	_wall(Vector3(1.56, 0.68, 0), Vector3(0.2, 2, 0.4))
	await physics_frame
	await physics_frame
	_spawn()
	_tick(100.0, [primary, secondary])
	_check(_record().get("reason") == "cover" and events.is_empty() and areas.is_empty(), "solid cover owns an equal swept contact before an enemy and prevents detonation")


func _test_large_frames_and_subdivision() -> void:
	# One huge frame and many short frames must resolve the same first blast exactly once.
	for delta in [1e300, 1.0 / 60.0, 1.0 / 240.0]:
		await _fresh()
		var primary = _enemy(Vector3(2, 0, 0))
		var secondary = _enemy(Vector3(1.46, 0, 1.0))
		_spawn()
		for frame in range(360):
			if manager.active.is_empty(): break
			_tick(delta, [secondary, primary, secondary])
		_near(primary.health, 928.0, "frame subdivision preserves one configured direct hit")
		_near(secondary.health, 964.0, "frame subdivision preserves one configured secondary hit")
		_check(manager.active.is_empty() and areas.size() == 1 and hits.size() == 2, "subdivided and huge frames consume exactly one projectile and blast")
		_near(_record().get("position", Vector3.ZERO).x, 1.46, "swept detonation centre is independent of frame length")


func _test_physical_and_legacy_no_splash() -> void:
	# AoE settings cannot turn either physical gun into a blast or alter rifle's fixed exit cutoff.
	for rifle in [false, true]:
		await _fresh()
		var first = _enemy(Vector3(2, 0, 0))
		var second = _enemy(Vector3(3, 0, 0))
		var adjacent = _enemy(Vector3(2, 0, 1))
		var definition := FIRE.duplicate()
		definition.element = "physical"
		definition.damage = 49.5 if rifle else 18.0
		definition.projectile_radius = 0.10
		definition.projectile_range = 9.0 if rifle else 7.0
		definition.projectile_speed = 22.0 if rifle else 18.0
		if rifle: definition.pierce_after_exit = 0.55
		_spawn(definition)
		_tick(100.0, [adjacent, second, first])
		_near(first.health, 950.5 if rifle else 982.0, "physical gun preserves configured direct damage")
		_near(second.health, 950.5 if rifle else 1000.0, "only rifle retains its original short physical pierce")
		_near(adjacent.health, 1000.0, "physical projectiles ignore supplied splash settings")
		_check(areas.is_empty() and not _record().has("splash_radius"), "guns emit no blast metadata or area signal")
		if rifle: _near(_record().get("pierce_cutoff", -1.0), 3.01, "rifle cutoff remains .55 after the original first exit")
	await _fresh()
	var primary = _enemy(Vector3(2, 0, 0))
	var secondary = _enemy(Vector3(1.46, 0, 1.0))
	_spawn({})
	_tick(100.0, [primary, secondary])
	_near(primary.health, 976.0, "legacy fire caller keeps its original direct default")
	_near(secondary.health, 1000.0, "fire caller without explicit area settings receives no splash")
	_check(areas.is_empty() and not _record().has("splash_radius"), "legacy fire remains opt-out from area feedback")


func _test_opt_in_validation_and_clear() -> void:
	# Malformed opt-in must not spawn or emit, and paused/cleared simulation must not detonate later.
	await _fresh()
	for key in ["splash_radius", "splash_damage"]:
		for value in [0.0, -1.0, INF, NAN, "invalid"]:
			var invalid := FIRE.duplicate()
			invalid[key] = value
			_check(not _spawn(invalid), "nonpositive, nonfinite and nonnumeric area settings are rejected")
	for missing in ["splash_radius", "splash_damage"]:
		var incomplete := FIRE.duplicate()
		incomplete.erase(missing)
		_check(not _spawn(incomplete), "partial splash opt-in is rejected")
	_check(manager.active.is_empty() and manager.shots_fired == 0 and areas.is_empty(), "rejected opt-in leaves no projectile, counter or feedback")
	await _fresh()
	var primary = _enemy(Vector3(2, 0, 0))
	var secondary = _enemy(Vector3(1.46, 0, 1.0))
	_spawn()
	for delta in [0.0, -1.0, INF, NAN]: _tick(delta, [primary, secondary])
	_check(hits.is_empty() and areas.is_empty() and manager.active.size() == 1, "invalid or paused time never resolves a projectile or explosion")
	manager.clear()
	_tick(100.0, [primary, secondary])
	_check(manager.active.is_empty() and manager.resolved.is_empty() and manager.shots_fired == 0 and hits.is_empty() and areas.is_empty(), "clear removes projectile and blast history without delayed damage or area feedback")
	for index in range(35):
		_spawn()
		_tick(100.0, [primary, secondary])
	_check(manager.resolved.size() == 32, "blast resolution history remains bounded to the latest 32 shots")


func _test_clear_during_damage_callbacks() -> void:
	# Clear from either public damage route must cancel this blast's remaining
	# work immediately, including a clear triggered by its first secondary.
	for route in ["primary_on_hit", "primary_damage_hit", "secondary_on_hit", "secondary_damage_hit"]:
		await _fresh()
		var primary = _enemy(Vector3(2, 0, 0))
		var first_secondary = _enemy(Vector3(1.46, 0, 0.8))
		var second_secondary = _enemy(Vector3(1.46, 0, 1.2))
		var primary_clear: bool = route.begins_with("primary")
		var callback_clear: bool = route.ends_with("on_hit")
		var trigger_id: int = primary.get_instance_id() if primary_clear else first_secondary.get_instance_id()
		var state := {"cleared": false, "late_callbacks": 0, "late_signals": 0}
		manager.damage_hit.connect(func(enemy, _damage: float, _knock: Vector3, _element: String):
			if state.cleared: state.late_signals += 1
			if not callback_clear and not state.cleared and enemy.get_instance_id() == trigger_id:
				manager.clear()
				state.cleared = true)
		_spawn()
		_tick(10.0, [primary, first_secondary, second_secondary], func(enemy, damage: float, knock: Vector3):
			if state.cleared: state.late_callbacks += 1
			_hit(enemy, damage, knock)
			if callback_clear and not state.cleared and enemy.get_instance_id() == trigger_id:
				manager.clear()
				state.cleared = true)
		_check(state.cleared, "%s actually invokes public clear during damage" % route)
		_near(primary.health, 928.0, "%s retains its already delivered direct hit" % route)
		_near(first_secondary.health, 1000.0 if primary_clear else 964.0, "%s stops before the next uncommitted secondary" % route)
		_near(second_secondary.health, 1000.0, "%s cannot damage a later secondary after clear" % route)
		_check(state.late_callbacks == 0 and state.late_signals == 0, "%s emits no callback or damage signal after clear" % route)
		_check(areas.is_empty() and impacts.is_empty(), "%s emits no stale blast or impact feedback after clear" % route)
		_check(manager.active.is_empty() and manager.resolved.is_empty() and manager.shots_fired == 0, "%s keeps actors, history and shot counter cleared" % route)
