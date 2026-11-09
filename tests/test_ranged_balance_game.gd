extends SceneTree
## Real playable owner, projected LMB input, live flight and damageable actors.
## Fixtures place targets/cover; no player projectile or enemy damage is supplied.

const STEP := 1.0 / 120.0
const TUNING := {
	"staff": {"windup": 0.28, "active": 0.10, "recovery": 0.82, "period": 1.20, "damage": 72.0, "speed": 5.5, "range": 6.0},
	"pistol": {"windup": 0.065, "active": 0.055, "recovery": 0.30, "period": 0.42, "damage": 18.0, "speed": 18.0, "range": 7.0},
	"rifle": {"windup": 0.16, "active": 0.08, "recovery": 0.66, "period": 0.90, "damage": 49.5, "speed": 22.0, "range": 9.0},
}
var game
var checks := 0
var failures: Array[String] = []
var areas: Array[Dictionary] = []
var damage_events: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)


func _run() -> void:
	Engine.physics_ticks_per_second = 120
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	_check(game.player is CharacterBody3D, "ranged trial uses the real playable body")
	_check(game.staff_flight.has_signal("area_impact"), "friendly flight exposes the real enemy-blast event")
	if game.staff_flight.has_signal("area_impact"):
		game.staff_flight.connect("area_impact", _on_area)
	game.staff_flight.damage_hit.connect(_on_damage)
	await _test_tuning_cadence_and_flight()
	await _test_staff_cluster()
	await _test_guns_have_no_splash()
	await _test_launch_cover_and_expiry()
	await _test_pause_and_blast_lifecycle()
	await _test_magazines_recoil_and_pierce()
	await _test_melee_retained()
	game.queue_free()
	await process_frame
	print("RANGED BALANCE GAME TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _on_area(position: Vector3, radius: float, element: String) -> void:
	areas.append({"position": position, "radius": radius, "element": element})


func _on_damage(enemy, damage: float, _knock: Vector3, element: String) -> void:
	damage_events.append({"id": enemy.get_instance_id(), "damage": damage, "element": element})


func _tick(delta: float = STEP) -> void:
	await physics_frame
	game.tick(delta)


func _step(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.000001:
		await _tick(minf(STEP, remaining))
		remaining -= STEP


func _dummy():
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.kind == "dummy" and not enemy.dead:
			return enemy
	return null


func _fresh(family: String, distance: float = 4.0) -> void:
	_mouse(false)
	game.start_run(true)
	game.set_physics_process(false)
	_check(game.set_weapon_family(family), "fixture equips " + family)
	game.player.position = Vector3(-3.5, 0.03, 0)
	game.move_input = Vector2.ZERO
	game.test_aim = Vector3.RIGHT
	_dummy().position = game.player.position + Vector3.RIGHT * distance
	areas.clear()
	damage_events.clear()
	await _tick()


func _point(direction: Vector3) -> Vector2:
	var foot: Vector3 = game.player.position + direction * 4.0
	foot.y = 0
	var position: Vector2 = game.camera.unproject_position(foot)
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	root.push_input(event, true)
	return position


func _mouse(pressed: bool) -> void:
	if game == null:
		return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = game._mouse_position
	event.global_position = event.position
	root.push_input(event, true)


func _click() -> void:
	game.test_aim = Vector3.ZERO
	_point(Vector3.RIGHT)
	_mouse(true)
	_mouse(false)
	_check(game.motion.busy and game.motion.stage == 0, "physical ground-projected LMB commits the one ranged pose")


func _recover() -> void:
	for index in range(400):
		if not game.motion.busy:
			return
		await _tick()
	_check(false, "committed shot must recover")


func _resolve() -> void:
	for index in range(400):
		if game.staff_flight.shots_fired > 0 and game.staff_flight.active.is_empty():
			return
		await _tick()
	_check(false, "real shot must resolve within its finite flight")


func _ground(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0, vector.z)


func _blasts() -> Array:
	var value = game.fx.get("fire_blasts")
	return value if value is Array else []


func _test_tuning_cadence_and_flight() -> void:
	var observed := {}
	for family in TUNING:
		await _fresh(family, 12.0)
		var definition: Dictionary = game.motion.definition(0)
		var expected: Dictionary = TUNING[family]
		for field in ["windup", "active", "recovery", "damage"]:
			_check(is_equal_approx(float(definition[field]), expected[field]), "%s has approved %s=%.3f" % [family, field, expected[field]])
		_check(is_equal_approx(definition.projectile_speed, expected.speed) and is_equal_approx(definition.projectile_range, expected.range), "%s retains its approved visible speed and finite range" % family)
		_check(is_equal_approx(definition.windup + definition.active + definition.recovery, expected.period), "%s one-shot period is %.2fs" % [family, expected.period])
		game.test_aim = Vector3.ZERO
		_point(Vector3.RIGHT)
		_mouse(true)
		_check(game.motion.busy and game.staff_flight.shots_fired == 0 and game.hits == 0, "%s physical press commits before a shot can release" % family)
		var time := 0.0
		var releases: Array[float] = []
		var prior_count := 0
		for index in range(500):
			await _tick()
			time += STEP
			if game.staff_flight.shots_fired > prior_count:
				releases.append(time)
				prior_count = game.staff_flight.shots_fired
			if releases.size() == 3:
				break
		_mouse(false)
		_check(releases.size() == 3, "%s held physical LMB emits exactly three observable releases" % family)
		if releases.size() == 3:
			_check(absf(releases[0] - expected.windup) <= STEP + 0.0001, "%s first release observes the new windup" % family)
			for index in [1, 2]:
				_check(absf(releases[index] - releases[index - 1] - expected.period) <= STEP * 2.0, "%s held release interval follows %.2fs cadence" % [family, expected.period])
			observed[family] = releases[1] - releases[0]
		await _recover()
		await _step(0.1)
		_check(game.staff_flight.shots_fired == 3, "%s release never repeats a fourth shot" % family)
		await _fresh(family, 12.0)
		_click()
		await _step(expected.windup + STEP)
		_check(game.staff_flight.active.size() == 1, "%s has a live visible flight after release" % family)
		if game.staff_flight.active.size() == 1:
			var shot: Dictionary = game.staff_flight.active[0]
			var before: Vector3 = shot.node.position
			await _tick(0.05)
			_check(absf(_ground(shot.node.position - before).length() - expected.speed * 0.05) < 0.0002, "%s actual projectile advances at approved speed %.1f" % [family, expected.speed])
		_check(game.hits == 0 and areas.is_empty(), "empty-lane flight cannot manufacture contacts or explosions")
	if observed.has_all(["staff", "pistol", "rifle"]):
		_check(observed.staff > observed.rifle and observed.rifle > observed.pistol, "actual release cadence orders staff slowest, rifle next, pistol fastest")
	_check(TUNING.staff.damage > TUNING.rifle.damage and TUNING.rifle.damage > TUNING.pistol.damage, "approved staff direct shot is strongest")


func _wall(position: Vector3, size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	game.add_child(wall)
	wall.position = position
	return wall


func _test_staff_cluster() -> void:
	for large_frame in [false, true]:
		await _fresh("staff")
		var primary = _dummy()
		var adjacent = game.spawn_enemy("dummy", primary.position + Vector3(0, 0, 1.0))
		var far = game.spawn_enemy("dummy", primary.position + Vector3(0, 0, 2.2))
		var covered = game.spawn_enemy("dummy", primary.position + Vector3(0, 0, -1.0))
		var wall := _wall(primary.position + Vector3(-0.27, 0.8, -0.5), Vector3(0.35, 2.0, 0.14))
		await physics_frame
		_click()
		if large_frame:
			# Cross release/flight/contact in one large frame while the shot is
			# still committed, before practice mode's intended idle health reset.
			await _tick(0.70)
		else:
			await _resolve()
		_check(game.hits == 2 and is_equal_approx(game.total_damage, 108.0), "staff primary72 plus one nearby36 resolve exactly once (large=%s hits=%d damage=%.1f)" % [large_frame, game.hits, game.total_damage])
		_check(primary.health == 928.0 and adjacent.health == 964.0 and covered.health == 1000.0 and far.health == 1000.0, "actual cluster respects primary exclusion, radius and solid-world splash cover")
		_check(areas.size() == 1 and damage_events.size() == 2, "one enemy impact emits one area event and exactly two real damage events")
		if areas.size() == 1:
			_check(is_equal_approx(areas[0].radius, 1.20) and areas[0].element == "fire", "real fire explosion declares its1.20 ground radius")
		if not game.staff_flight.resolved.is_empty():
			var record: Dictionary = game.staff_flight.resolved.back()
			_check(record.reason == "enemy" and record.get("targetid", 0) == primary.get_instance_id(), "staff still resolves at its first actual enemy")
			_check(is_equal_approx(float(record.get("splash_radius", 0)), 1.20), "resolved detonation records the blast radius")
			var hitids: Array = record.get("splash_hitids", [])
			_check(hitids == [adjacent.get_instance_id()], "resolved splash IDs contain the nearby target once and exclude primary/covered/far")
		var event_count := damage_events.size()
		await _tick(2.0)
		_check(game.staff_flight.active.is_empty() and game.hits == 2 and damage_events.size() == event_count and areas.size() == 1, "removed fireball cannot repeat direct damage, splash or area event")
		wall.queue_free()
		await physics_frame


func _test_guns_have_no_splash() -> void:
	for family in ["pistol", "rifle"]:
		await _fresh(family)
		var primary = _dummy()
		var adjacent = game.spawn_enemy("dummy", primary.position + Vector3(0, 0, 1.0))
		var before: Vector3 = game.player.position
		_click()
		await _resolve()
		_check(game.hits == 1 and is_equal_approx(game.total_damage, TUNING[family].damage) and adjacent.health == 1000.0, "%s remains one physical direct shot without a nearby explosion" % family)
		_check(areas.is_empty() and damage_events.size() == 1 and damage_events[0].element == "physical", "%s emits only its physical contact" % family)
		if not game.staff_flight.resolved.is_empty():
			var record: Dictionary = game.staff_flight.resolved.back()
			_check(float(record.get("splash_radius", 0)) == 0 and record.get("splash_hitids", []).is_empty(), "%s resolved flight has no blast payload" % family)
		await _recover()
		var expected := 0.22 if family == "rifle" else 0.0
		_check(absf(_ground(game.player.position - before).length() - expected) < 0.003, "%s preserves its accepted recoil or stationary shot" % family)


func _test_launch_cover_and_expiry() -> void:
	await _fresh("staff", 0.70)
	_click()
	await _resolve()
	_check(game.hits == 1 and game.total_damage == 72.0 and areas.size() == 1, "enemy between hand and visible staff tip receives one safe direct hit and one blast")
	for fixture in ["launch_cover", "flight_cover", "range"]:
		await _fresh("staff", 12.0 if fixture == "range" else 4.0)
		var wall: StaticBody3D
		if fixture != "range":
			wall = _wall(game.player.position + Vector3(0.50 if fixture == "launch_cover" else 2.5, 0.8, 0), Vector3(0.10, 2.0, 1.0))
			await physics_frame
		_click()
		await _resolve()
		_check(game.hits == 0 and game.total_damage == 0 and areas.is_empty() and _blasts().is_empty(), "%s removes the fireball without an enemy explosion" % fixture)
		if not game.staff_flight.resolved.is_empty():
			var record: Dictionary = game.staff_flight.resolved.back()
			_check(record.reason == ("range" if fixture == "range" else "cover"), "%s retains its explicit flight resolution reason" % fixture)
			_check(not record.has("splash_radius") or float(record.splash_radius) == 0, "non-enemy resolution cannot claim a detonation")
			if fixture == "range":
				_check(absf(record.travelled - 6.0) < 0.001, "slower fireball still expires exactly six muzzle units away")
		if is_instance_valid(wall):
			wall.queue_free()
			await physics_frame


func _end_lifecycle(route: String) -> void:
	match route:
		"restart": game.restart()
		"menu": game.return_menu()
		"death": game.damage_player(2000.0)
		"victory":
			# Terminal fixture only: let the real wave/victory transition execute.
			game.mode = "combat"
			game.wave = 3
			game._wave_wait = 0.999
			for enemy in game.enemies:
				enemy.dead = true
			await _tick()


func _test_pause_and_blast_lifecycle() -> void:
	await _fresh("staff")
	_click()
	await _step(0.36)
	_check(game.staff_flight.active.size() == 1 and areas.is_empty() and game.hits == 0, "pause fixture contains an actual travelling slow fireball")
	if game.staff_flight.active.size() == 1:
		var before: Vector3 = game.staff_flight.active[0].node.position
		game.toggle_pause()
		await _tick(2.0)
		_check(game.staff_flight.active[0].node.position.is_equal_approx(before) and areas.is_empty() and game.hits == 0, "paused flight cannot move, hit or detonate")
		game.toggle_pause()
	await _resolve()
	_check(_blasts().size() == 1, "actual enemy hit creates one visible blast owned by effects")
	if _blasts().size() == 1:
		var blast = _blasts()[0]
		_check(is_equal_approx(float(blast.get("radius")), 1.20), "actual visible blast matches the approved damage-circle radius")
		var age: float = blast.get("age")
		game.toggle_pause()
		await _tick(2.0)
		_check(is_instance_valid(blast) and is_equal_approx(float(blast.get("age")), age), "pause freezes the visible blast's fade clock")
		game.toggle_pause()
		await _step(0.41)
		_check(_blasts().is_empty(), "visible fire blast naturally expires after its short fade")
	for route in ["restart", "menu", "death", "victory"]:
		for with_blast in [false, true]:
			await _fresh("staff", 4.0 if with_blast else 12.0)
			_click()
			if with_blast:
				await _resolve()
				_check(_blasts().size() == 1, "%s fixture owns one freshly generated blast" % route)
			else:
				await _step(0.30)
				_check(game.staff_flight.active.size() == 1, "%s fixture owns one real travelling fireball" % route)
			await _end_lifecycle(route)
			game.set_physics_process(false)
			_check(game.staff_flight.active.is_empty() and _blasts().is_empty(), "%s synchronously clears orphan flight and blast effects" % route)


func _test_magazines_recoil_and_pierce() -> void:
	for family in ["pistol", "rifle"]:
		await _fresh(family)
		var magazine = game.active_magazine()
		var capacity := 10 if family == "pistol" else 5
		var reload_time := 0.5 if family == "pistol" else 1.2
		_check(magazine.capacity == capacity and magazine.rounds == capacity and is_equal_approx(magazine.reload_duration, reload_time), "%s retains its approved magazine and reload" % family)
		game.test_aim = Vector3.ZERO
		_point(Vector3.RIGHT)
		_mouse(true)
		for index in range(900):
			await _tick()
			if game.staff_flight.shots_fired == capacity:
				break
		_mouse(false)
		_check(game.staff_flight.shots_fired == capacity and magazine.rounds == 0, "%s held physical trigger consumes exactly its magazine" % family)
		for index in range(200):
			if magazine.reloading:
				break
			await _tick()
		_check(magazine.reloading and not game.motion.busy, "%s automatically reloads after final recovery" % family)
		game.stamina = 0.0 # Unaffordable dodge preserves the attack/reload under test.
		_check(not game.request_attack() and not game.request_dodge() and not game.set_weapon_family("staff"), "reload guards shooting/switch; unaffordable dodge preserves reload")
		var elapsed: float = magazine.elapsed
		game.toggle_pause()
		await _tick(2.0)
		_check(magazine.rounds == 0 and is_equal_approx(magazine.elapsed, elapsed), "%s pause retains exact empty-magazine reload state" % family)
		game.toggle_pause()
		await _tick(reload_time - elapsed - 0.001)
		_check(magazine.rounds == 0 and magazine.reloading, "%s has no premature refill before its unchanged reload boundary" % family)
		await _tick(0.001)
		_check(magazine.rounds == capacity and not magazine.reloading and game.staff_flight.shots_fired == capacity, "%s refills exactly once and released trigger remains idle" % family)
	await _fresh("rifle")
	var first = _dummy()
	var near = game.spawn_enemy("dummy", first.position + Vector3.RIGHT)
	var far = game.spawn_enemy("dummy", first.position + Vector3.RIGHT * 3.0)
	game.enemies = [far, near, first]
	var before: Vector3 = game.player.position
	_click()
	await _resolve()
	await _recover()
	_check(game.hits == 2 and game.total_damage == 99.0 and near.health < 1000.0 and far.health == 1000.0, "slower rifle retains two direct49.5 contacts and its short third-target cutoff")
	_check(game.casing_fx.spawned_count == 1 and game.rifle_magazine.rounds == 4 and absf(game.rifle_recoil_travelled - 0.22) < 0.003 and absf(before.x - game.player.position.x - 0.22) < 0.003, "rifle preserves one casing, one round and one real .22 recoil budget")
	_check(areas.is_empty() and game.staff_flight.resolved.back().reason == "pierce_limit", "rifle penetration never becomes an explosion")


func _test_melee_retained() -> void:
	for family in ["sword", "greatsword", "mace"]:
		await _fresh(family, 1.25)
		for stage in range(3):
			_check(game.request_attack() and game.motion.stage == stage, "%s retains actual combo stage %d" % [family, stage + 1])
			await _recover()
		var expected: float = {"sword": 71.0, "greatsword": 177.5, "mace": 92.0}[family]
		_check(game.hits == 3 and is_equal_approx(game.total_damage, expected) and game.staff_flight.shots_fired == 0 and areas.is_empty(), "%s accepted combo retains its normal three contacts and never enters ranged dispatch" % family)
