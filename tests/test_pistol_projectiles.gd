extends SceneTree

const Enemy = preload("res://scripts/enemy.gd")
const Projectile = preload("res://scripts/staff_projectiles.gd")
var checks := 0
var failures: Array[String] = []
var scene: Node3D
var manager
var hits: Array[Dictionary] = []
var damage_events: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
var element_impacts: Array[Dictionary] = []
var signal_applies_damage := false

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
	await _test_physical_defaults_and_visual()
	await _test_nearest_target_consumes_bullet()
	await _test_range_and_radius()
	await _test_cover_order()
	await _test_launch_safety()
	await _test_signal_owned_damage()
	await _test_fire_compatibility()
	await _test_clear_lifecycle()
	if is_instance_valid(scene): scene.free()
	print("PISTOL PROJECTILE TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _fresh() -> void:
	if is_instance_valid(scene): scene.free()
	scene = Node3D.new()
	root.add_child(scene)
	manager = Projectile.new()
	scene.add_child(manager)
	hits.clear()
	damage_events.clear()
	impacts.clear()
	element_impacts.clear()
	signal_applies_damage = false
	manager.impact.connect(func(position: Vector3, reason: String): impacts.append({"position": position, "reason": reason}))
	if manager.has_signal("damage_hit"):
		manager.connect("damage_hit", _damage_event)
	if manager.has_signal("impact_element"):
		manager.connect("impact_element", func(position: Vector3, reason: String, element: String): element_impacts.append({"position": position, "reason": reason, "element": element}))
	await physics_frame
	await physics_frame

func _enemy(where: Vector3, kind := "melee"):
	var enemy = Enemy.new()
	enemy.kind = kind
	scene.add_child(enemy)
	enemy.position = where
	return enemy

func _wall(x: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, 2.0, 2.0)
	collider.shape = shape
	body.add_child(collider)
	scene.add_child(body)
	body.position = Vector3(x, 0.6, 0)

func _hit(enemy, damage: float, knock: Vector3) -> void:
	hits.append({"id": enemy.get_instance_id(), "damage": damage, "knock": knock})
	enemy.receive_damage(damage, knock)

func _damage_event(enemy, damage: float, knock: Vector3, element: String) -> void:
	damage_events.append({"id": enemy.get_instance_id(), "damage": damage, "knock": knock, "element": element})
	if signal_applies_damage: enemy.receive_damage(damage, knock)

func _spawn(where := Vector3(0, 0.9, 0), definition: Dictionary = {"element": "physical"}, direction := Vector3.RIGHT) -> bool:
	return manager.spawn_fireball(where, direction, definition, null)

func _tick(delta: float, enemies: Array, callback: Callable = _hit) -> void:
	manager.tick(delta, enemies, scene.get_world_3d(), callback, null)

func _test_physical_defaults_and_visual() -> void:
	# Catches physical shots inheriting fire metadata, flight tuning, or flame art.
	await _fresh()
	_check(manager.has_signal("damage_hit"), "shared flight exposes element-aware damage signal")
	_check(manager.has_signal("impact_element"), "shared flight exposes element-aware impact signal")
	_check(_spawn(Vector3(0, 0.9, 0), {"element": "physical"}, Vector3(9, 4, 0)), "physical shot accepts ground-normalized aim")
	_check(manager.active.size() == 1 and manager.shots_fired == 1, "one pistol release creates one flight")
	if manager.active.is_empty(): return
	var shot: Dictionary = manager.active[0]
	_check(shot.element == "physical" and shot.direction == Vector3.RIGHT, "bullet carries physical element and normalized aim")
	_near(shot.damage, 18.0, "physical default damage is eighteen")
	_near(shot.max_range, 7.0, "physical default muzzle range is seven")
	_near(shot.speed, 18.0, "physical default speed is eighteen")
	_near(shot.radius, 0.10, "physical default radius is one tenth")
	_near(shot.knockback, 0.8, "physical default knockback is eight tenths")
	var visual: Script = shot.node.get_script()
	_check(visual != null and visual.resource_path == "res://scripts/bullet_visual.gd", "physical shot selects the plain bullet visual")
	_check(visual == null or visual.resource_path != "res://scripts/fireball_visual.gd", "physical shot never instantiates the fire visual")
	_check(shot.node.get_node_or_null("flame") == null, "physical shot has no flame child")
	_tick(0.1, [])
	_near(manager.active[0].node.global_position.x, 1.8, "bullet visibly advances at its finite speed")
	_near(manager.active[0].age, 0.1, "bullet visual receives finite flight age")
	_check(hits.is_empty() and damage_events.is_empty() and impacts.is_empty(), "flight before contact has no damage or impact")

func _test_nearest_target_consumes_bullet() -> void:
	# Catches piercing, array-order targeting, repeated hits, and broken legacy callbacks.
	for reverse in [false, true]:
		await _fresh()
		var near_enemy = _enemy(Vector3(2, 12, 0))
		var far_enemy = _enemy(Vector3(3, 0, 0))
		_spawn()
		_near(near_enemy.health, 38.0, "spawn alone never damages a pistol target")
		_tick(1.0, [far_enemy, near_enemy] if reverse else [near_enemy, far_enemy])
		_near(near_enemy.health, 20.0, "first swept target takes exactly eighteen damage")
		_near(far_enemy.health, 38.0, "first target consumes the bullet before a farther enemy")
		_check(manager.active.is_empty() and hits.size() == 1, "legacy callback runs exactly once per consumed bullet")
		_near(hits[0].knock.x, 0.8, "legacy callback retains pistol knockback")
		_check(damage_events.size() == 1, "one element-aware damage event accompanies the legacy callback")
		if not damage_events.is_empty():
			_check(damage_events[0].id == near_enemy.get_instance_id() and damage_events[0].element == "physical", "damage signal names the actual first target and physical element")
			_near(damage_events[0].damage, 18.0, "damage signal carries configured damage")
			_check(damage_events[0].knock == Vector3(0.8, 0, 0), "damage signal carries configured direction and knockback")
		_check(manager.resolved.back().element == "physical" and manager.resolved.back().reason == "enemy", "resolution retains physical enemy impact metadata")
		_near(manager.resolved.back().position.x, 1.54, "bullet contacts expanded target circle at its entry edge")
		_check(impacts.size() == 1 and element_impacts.size() == 1, "legacy and element-aware impact signals each emit once")
		if not element_impacts.is_empty():
			_check(element_impacts[0].element == "physical" and element_impacts[0].reason == "enemy", "impact signal carries physical enemy outcome")
			_check(element_impacts[0].position == impacts[0].position, "both impact interfaces report the same contact position")
		_tick(10.0, [near_enemy, far_enemy])
		_near(near_enemy.health, 20.0, "spent bullet cannot add repeated or burn damage")
		_check(hits.size() == 1 and damage_events.size() <= 1, "spent bullet never emits another hit")

func _test_range_and_radius() -> void:
	# Catches unbounded long-frame travel and accidentally reusing the larger fire radius.
	await _fresh()
	var beyond = _enemy(Vector3(7.48, 0, 0))
	_spawn()
	_tick(1000.0, [beyond])
	_near(beyond.health, 38.0, "a long frame cannot hit beyond seven meters plus contact radius")
	_check(manager.active.is_empty() and manager.resolved.back().reason == "range", "unhit physical bullet expires at range")
	_near(manager.resolved.back().position.x, 7.0, "physical expiry is exactly seven meters from muzzle")
	_near(manager.resolved.back().travelled, 7.0, "physical travel budget stops at seven meters")
	_check(manager.resolved.back().element == "physical", "range history retains physical element")
	_check(damage_events.is_empty(), "range expiry never emits damage")
	_check(element_impacts.size() == 1, "range expiry emits one element-aware impact")
	if not element_impacts.is_empty():
		_check(element_impacts[0].reason == "range" and element_impacts[0].element == "physical", "range impact identifies physical expiry")
	await _fresh()
	var edge = _enemy(Vector3(7.46, 0, 0))
	_spawn()
	_tick(1000.0, [edge])
	_near(edge.health, 20.0, "enemy exactly touching the seven-meter range edge is eligible")
	await _fresh()
	var grazing = _enemy(Vector3(2, 0, 0.5))
	_spawn()
	_tick(1.0, [grazing])
	_near(grazing.health, 38.0, "narrow physical bullet cannot inherit the wider flame collision")
	await _fresh()
	_spawn(Vector3(0, 0.9, 0), {"element": "physical", "damage": 9.0, "projectile_range": 2.0, "projectile_speed": 1.0, "projectile_radius": 0.2, "knockback": 2.0})
	_tick(1.0, [])
	_near(manager.active[0].travelled, 1.0, "pistol definition can override finite projectile speed")
	_tick(100.0, [])
	_near(manager.resolved.back().position.x, 2.0, "pistol definition can override range")

func _test_cover_order() -> void:
	# Catches damaging through real solid cover or letting cover after a target cancel it.
	await _fresh()
	_wall(2.0)
	var behind = _enemy(Vector3(3, 0, 0))
	await physics_frame
	await physics_frame
	_spawn()
	_tick(1.0, [behind])
	_near(behind.health, 38.0, "real nearer cover protects the target from a bullet")
	_check(manager.resolved.back().reason == "cover" and manager.resolved.back().element == "physical", "physical cover consumes the shot with correct history")
	_near(manager.resolved.back().position.x, 1.9, "physical cover resolves at the real wall surface")
	_check(damage_events.is_empty(), "cover impact never emits damage")
	_check(element_impacts.size() == 1, "physical cover emits one element-aware impact")
	if not element_impacts.is_empty(): _check(element_impacts[0].reason == "cover" and element_impacts[0].element == "physical", "cover impact carries physical identity")
	await _fresh()
	_wall(2.0)
	var before = _enemy(Vector3(1.2, 0, 0))
	await physics_frame
	await physics_frame
	_spawn()
	_tick(1.0, [before])
	_near(before.health, 20.0, "target before cover owns the first contact")
	await _fresh()
	_wall(2.0)
	var tied = _enemy(Vector3(2.36, 0, 0))
	await physics_frame
	await physics_frame
	_spawn()
	_tick(1.0, [tied])
	_near(tied.health, 38.0, "cover owns an equal-distance bullet contact")

func _test_launch_safety() -> void:
	# Catches a muzzle born beyond a close monster or a thin wall bypassing that contact.
	await _fresh()
	var close = _enemy(Vector3(0.7, 0, 0))
	var farther = _enemy(Vector3(2.5, 0, 0))
	_spawn(Vector3(1.2, 0.9, 0), {"element": "physical", "launch_origin": Vector3(0, 0.9, 0)})
	_near(manager.active[0].node.global_position.x, 1.2, "bullet visual begins at the muzzle")
	_near(close.health, 38.0, "launch safety does not damage during spawn")
	_tick(1.0, [farther, close])
	_near(close.health, 20.0, "pre-muzzle safety catches the close target")
	_near(farther.health, 38.0, "launch contact consumes bullet before further travel")
	_near(manager.resolved.back().position.x, 0.24, "launch contact uses bullet radius and earliest circle entry")
	_near(manager.resolved.back().travelled, 0.0, "launch safety does not spend muzzle range")
	await _fresh()
	_wall(0.6)
	var behind = _enemy(Vector3(2.5, 0, 0))
	await physics_frame
	await physics_frame
	_spawn(Vector3(1.2, 0.9, 0), {"element": "physical", "launch_origin": Vector3(0, 0.9, 0)})
	_tick(1.0, [behind])
	_near(behind.health, 38.0, "wall before pistol muzzle blocks a shot born beyond it")
	_check(manager.resolved.back().reason == "cover", "pre-muzzle wall is recorded as cover")
	await _fresh()
	_wall(0.0)
	await physics_frame
	await physics_frame
	_spawn()
	_tick(0.1, [])
	_check(manager.resolved.size() == 1 and manager.resolved.back().reason == "cover", "bullet born inside cover cannot escape")

func _test_signal_owned_damage() -> void:
	# Catches the new integration requiring a legacy callback or applying damage twice.
	await _fresh()
	signal_applies_damage = true
	var target = _enemy(Vector3(2, 0, 0))
	_spawn()
	_tick(1.0, [target], Callable())
	_near(target.health, 20.0, "element-aware consumer with empty legacy callback applies damage exactly once")
	_check(hits.is_empty() and damage_events.size() == 1, "empty legacy callback does not suppress or duplicate new hit signal")

func _test_fire_compatibility() -> void:
	# Catches element routing accidentally changing default staff behavior or its new events.
	for definition in [{}, {"element": "fire"}, {"element": "unknown"}]:
		await _fresh()
		var target = _enemy(Vector3(2, 0, 0))
		_spawn(Vector3(0, 0.9, 0), definition)
		var shot: Dictionary = manager.active[0]
		_check(shot.element == "fire", "only explicit physical routes away from fire")
		var visual: Script = shot.node.get_script()
		_check(visual != null and visual.resource_path == "res://scripts/fireball_visual.gd", "default staff keeps its existing fireball visual")
		_tick(1.0, [target])
		_near(target.health, 14.0, "default staff damage stays twenty-four")
		_check(hits.size() == 1, "legacy staff callback still runs once")
		_check(damage_events.size() == 1, "fire also emits one element-aware hit")
		if not damage_events.is_empty(): _check(damage_events[0].element == "fire", "staff hit signal stays fire")
		_check(element_impacts.size() == 1, "fire also emits one element-aware impact")
		if not element_impacts.is_empty(): _check(element_impacts[0].element == "fire", "staff impact signal stays fire")

func _test_clear_lifecycle() -> void:
	# Catches stale bullet actors, harmful paused/reset flights, and false impacts on clear.
	await _fresh()
	_spawn()
	_tick(1.0, [])
	_spawn()
	var bullet: Node3D = manager.active[0].node
	manager.clear()
	_check(manager.active.is_empty() and manager.resolved.is_empty() and manager.shots_fired == 0, "clear resets bullet actors, history, and release count")
	_check(not is_instance_valid(bullet) or bullet.get_parent() == null, "clear immediately detaches bullet visual")
	_check(impacts.size() == 1 and element_impacts.size() == 1, "clear adds no legacy or element impact")
	var target = _enemy(Vector3(2, 0, 0))
	_tick(1.0, [target])
	_near(target.health, 38.0, "cleared bullet cannot damage in a later tick")
	_check(damage_events.is_empty(), "clear never emits delayed damage")
