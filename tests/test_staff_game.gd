extends SceneTree
## Actual controller/physics/input evidence for the one-shot fire staff.
const STEP := 1.0 / 120.0
var game
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_tests")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func run_tests() -> void:
	Engine.physics_ticks_per_second = 120
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	check(game.weapon_family == "sword", "v10 launches with ordinary sword equipped")
	check(game.set_weapon_family("staff"), "controller accepts staff")
	if failures.is_empty():
		await single_shot()
		await repeat_and_aim()
		await first_contact()
		await range_expiry()
		await close_target()
		await lifecycle()
		await selection_and_legacy()
	game.queue_free()
	await process_frame
	print("STAFF GAME TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func fresh(direction: Vector3 = Vector3.RIGHT, distance: float = 4.5) -> void:
	mouse(false)
	game.start_run(true)
	game.set_physics_process(false)
	check(game.set_weapon_family("staff"), "fresh fixture selects staff")
	game.test_aim = direction
	game.move_input = Vector2.ZERO
	dummy().position = game.player.position + direction * distance
	await tick()

func dummy():
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.kind == "dummy" and not enemy.dead:
			return enemy
	return null

func tick(delta: float = STEP) -> void:
	await physics_frame
	game.tick(delta)

func step(seconds: float) -> void:
	for i in range(int(ceil(seconds / STEP))):
		await tick()

func mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = game.camera.unproject_position(game.player.position + game.aim * 4.0)
	event.global_position = event.position
	root.push_input(event, true)
	Input.flush_buffered_events()

func finish_attack() -> void:
	for i in range(160):
		if not game.motion.busy: return
		await tick()
	check(false, "committed staff shot finishes")

func single_shot() -> void:
	await fresh()
	var origin: Vector3 = game.player.position
	check(game.motion.definition(0).element == "fire", "basic staff attack always defines fire damage")
	mouse(true)
	mouse(false)
	check(game.motion.busy and game.motion.stage == 0, "click begins the only staff pose")
	game.stamina = 0.0 # Unaffordable dodge preserves the attack/reload under test.
	check(not game.request_dodge(), "unaffordable dodge preserves committed staff shot")
	check(not game.set_weapon_family("sword"), "switch cannot cancel a committed shot")
	await step(.12)
	check(game.staff_flight.shots_fired == 0 and game.hits == 0, "windup deals no instant melee damage or early projectile")
	await step(.18)
	check(game.staff_flight.shots_fired == 1 and game.hits == 0, "released click still spawns exactly one travelling fireball")
	check(game.staff_flight.active.size() == 1, "fireball remains visible while flying toward a distant monster")
	var shot: Dictionary = game.staff_flight.active[0]
	check(shot.element == "fire" and is_equal_approx(shot.max_range, 6.0), "actual flight preserves fire tag and limited range")
	var pose: Dictionary = game.motion.definition(0)
	check(is_equal_approx(pose.damage, 72.0), "basic fire damage is configurable in definition")
	await step(.85)
	check(game.hits == 1 and is_equal_approx(game.total_damage, 72.0), "one fireball damages its first target exactly once for72 direct fire damage")
	check(game.staff_flight.active.is_empty(), "fireball disappears on monster impact")
	check(game.staff_flight.shots_fired == 1 and game._next_combo == 0, "release does not create additional shots or a second combo stage")
	check(Vector2(game.player.position.x - origin.x, game.player.position.z - origin.z).length() < .001, "casting never adds a melee forward lunge")
	await finish_attack()
	check(game.ui.stage_text.text.contains("ไฟ"), "idle staff HUD names its fire shot")

func repeat_and_aim() -> void:
	await fresh(Vector3.RIGHT, 4.5)
	mouse(true)
	await step(2.80)
	mouse(false)
	await step(.65)
	check(game.staff_flight.shots_fired == 3, "holding repeats the same single shot at authored attack cadence")
	check(game.hits == 3 and game.total_damage == 216.0 and game.motion.stage == 0, "repeated staff shots stay stage zero and retain equal damage")
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		await fresh(direction, 4.0)
		check(game.request_attack(), "staff accepts cardinal aim")
		await step(.06)
		game.test_aim = -direction
		await step(1.0)
		check(game.hits == 1 and game.total_damage == 72.0, "committed fire shot keeps its aim until it hits")
		var resolved: Dictionary = game.staff_flight.resolved.back()
		check(resolved.reason == "enemy" and resolved.element == "fire", "all cardinal shots resolve as a fire contact")

func first_contact() -> void:
	await fresh(Vector3.RIGHT, 4.5)
	var behind = dummy()
	var front = game.spawn_enemy("dummy", game.player.position + Vector3(3.0, 0, 0))
	var adjacent = game.spawn_enemy("dummy", front.position + Vector3(0, 0, 1.0))
	game.enemies = [behind, adjacent, front]
	check(game.request_attack(), "shot with two aligned targets begins")
	await step(1.0)
	check(game.hits == 2 and game.total_damage == 108.0, "nearest direct72 contact adds one adjacent36 blast hit")
	check(adjacent.health == 964.0, "nearby off-axis actor receives exactly one36 splash contact")
	check(behind.health == behind.max_health, "farther target remains unharmed despite earlier array order")
	check(game.staff_flight.resolved.back().reason == "enemy", "shot resolves at the first monster")

func range_expiry() -> void:
	await fresh(Vector3.RIGHT, 8.6)
	check(game.request_attack(), "out-of-range shot still fires normally")
	await step(1.45)
	check(game.hits == 0 and game.total_damage == 0, "beyond-range monster takes no damage")
	check(game.staff_flight.active.is_empty(), "unhit fireball disappears at range limit")
	check(game.staff_flight.resolved.back().reason == "range", "range expiry is explicit")
	check(absf(game.staff_flight.resolved.back().travelled - 6.0) < .001, "range stops at six units from muzzle")

func close_target() -> void:
	await fresh(Vector3.RIGHT, .8)
	check(game.request_attack(), "point-blank shot begins")
	await step(.4)
	check(game.hits == 1 and game.total_damage == 72.0, "monster between grip and staff tip still blocks the launch")
	check(game.staff_flight.active.is_empty(), "point-blank contact consumes the fireball")

func lifecycle() -> void:
	await fresh(Vector3.RIGHT, 8.6)
	game.request_attack()
	await step(.31)
	check(game.staff_flight.active.size() == 1, "pause fixture has a live shot")
	var position: Vector3 = game.staff_flight.active[0].node.position
	game.toggle_pause()
	await step(.35)
	check(game.staff_flight.active[0].node.position.is_equal_approx(position), "pause freezes fireball flight")
	game.toggle_pause()
	await step(.05)
	check(not game.staff_flight.active[0].node.position.is_equal_approx(position), "resume continues the same fireball")
	game.restart()
	check(game.staff_flight.active.is_empty() and game.staff_flight.shots_fired == 0, "restart removes shots and resets flight statistics")
	game.test_aim = Vector3.RIGHT
	game.request_attack()
	await step(.31)
	game.return_menu()
	check(game.staff_flight.active.is_empty(), "return to menu clears old shots")
	await fresh(Vector3.RIGHT, 8.6)
	game.request_attack()
	await step(.31)
	game.damage_player(1000.0)
	check(game.mode == "dead" and game.staff_flight.active.is_empty(), "death removes harmful orphan shots")

func selection_and_legacy() -> void:
	await fresh()
	for family in ["mace", "greatsword", "sword", "rifle", "pistol", "staff"]:
		check(game.cycle_weapon() and game.weapon_family == family, "six-way cycle reaches " + family)
	check(game.ui.weapon_button.text.contains("คทา"), "visible selector labels the staff")
	for family in ["sword", "greatsword", "mace"]:
		game.start_run(true)
		game.set_weapon_family(family)
		game.test_aim = Vector3.RIGHT
		dummy().position = game.player.position + Vector3(1.25, 0, 0)
		var damage := 0.0
		for index in range(3):
			check(game.request_attack(), "legacy " + family + " stage starts")
			await finish_attack()
			damage = game.total_damage
		var expected: float = {"sword": 71.0, "greatsword": 177.5, "mace": 92.0}[family]
		check(is_equal_approx(damage, expected) and game.hits == 3, "legacy " + family + " retains its full accepted combo")
		check(game.staff_flight.shots_fired == 0, "legacy melee never emits fireballs")
