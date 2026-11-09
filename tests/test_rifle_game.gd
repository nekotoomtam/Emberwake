extends SceneTree
const STEP := 1.0 / 120.0
var game
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_tests")

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		printerr("FAIL: ", text)

func run_tests() -> void:
	Engine.physics_ticks_per_second = 120
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	check(game.weapon_family == "sword", "v10 defaults to ordinary sword")
	check(game.set_weapon_family("rifle"), "controller accepts rifle")
	if failures.is_empty():
		await shot_and_pierce()
		await recoil_directions()
		await magazine_reload()
		await independent_ammo()
		await lifecycle()
	game.queue_free()
	await process_frame
	print("RIFLE GAME TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func tick(delta: float = STEP) -> void:
	await physics_frame
	game.tick(delta)

func step(seconds: float) -> void:
	var left := seconds
	while left > .0000001:
		await tick(minf(left, STEP))
		left -= STEP

func fresh(direction: Vector3 = Vector3.RIGHT) -> void:
	game.start_run(true)
	game.set_physics_process(false)
	check(game.set_weapon_family("rifle"), "fresh fixture selects rifle")
	game.test_aim = direction
	game.move_input = Vector2.ZERO
	game.enemies[0].position = game.player.position + direction * 4.0
	await tick()

func mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = game.camera.unproject_position(game.player.position + game.aim * 4.0)
	event.global_position = event.position
	root.push_input(event, true)
	Input.flush_buffered_events()

func shot_and_pierce() -> void:
	await fresh()
	var first = game.enemies[0]
	var near = game.spawn_enemy("dummy", game.player.position + Vector3(5.0, 0, 0))
	var far = game.spawn_enemy("dummy", game.player.position + Vector3(7.0, 0, 0))
	game.enemies = [far, near, first]
	var origin: Vector3 = game.player.position
	check(game.rifle_magazine.capacity == 5 and game.rifle_magazine.rounds == 5, "rifle starts with five rounds")
	check(is_equal_approx(game.motion.definition(0).damage / 18.0, 2.75), "rifle base hit is 2.75 times pistol")
	mouse(true)
	mouse(false)
	await step(.10)
	check(game.staff_flight.shots_fired == 0 and game.rifle_magazine.rounds == 5, "rifle windup has no early damage or ammo spend")
	check(game.player.position.x >= origin.x - .001, "rifle does not move backward before release")
	await step(.82)
	check(game.staff_flight.shots_fired == 1 and game.rifle_magazine.rounds == 4, "one committed click fires one rifle round")
	check(game.hits == 2 and game.total_damage == 99.0, "near aligned pair takes full rifle damage")
	check(far.health == far.max_health, "farther third target is outside short penetration")
	check(game.staff_flight.active.is_empty() and game.staff_flight.resolved.back().reason == "pierce_limit", "rifle bullet ends at its fixed short cutoff")
	check(game.casing_fx.spawned_count == 1, "successful shot ejects exactly one casing")
	check(absf(origin.x - game.player.position.x - .22) < .003, "free shot moves character backward .22 units")
	check(absf(game.rifle_recoil_travelled - .22) < .003, "reported recoil is real character displacement")
	check(not game.motion.busy and game._next_combo == 0, "rifle uses one firing pose without combo")

func recoil_directions() -> void:
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		await fresh(direction)
		game.move_input = Vector2(1, 0)
		var origin: Vector3 = game.player.position
		check(game.request_attack(), "cardinal recoil shot begins")
		for i in range(120):
			await tick()
			if not game.motion.busy: break
		var travel: Vector3 = game.player.position - origin
		travel.y = 0
		check(travel.distance_to(-direction * .22) < .003, "held movement cannot cancel or enlarge recoil in each aim")
		check(game.casing_fx.spawned_count == 1, "each aimed shot ejects a casing")
	await fresh()
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.20, 2, 3)
	shape.shape = box
	wall.add_child(shape)
	wall.position = game.player.position + Vector3(-.55, .8, 0)
	game.add_child(wall)
	await tick()
	var origin: Vector3 = game.player.position
	game.request_attack()
	await step(.92)
	check(game.rifle_recoil_travelled < .20 and game.player.position.x > origin.x - .20, "solid cover safely clips backward recoil")
	check(game.staff_flight.shots_fired == 1 and game.casing_fx.spawned_count == 1, "blocked recoil still fires and ejects once")
	wall.queue_free()
	await physics_frame

func magazine_reload() -> void:
	await fresh()
	check(game.rifle_magazine.reload_duration == 1.2, "rifle reload is longer than pistol")
	mouse(true)
	for i in range(700):
		await tick()
		if game.staff_flight.shots_fired == 5:
			mouse(false)
			break
	check(game.rifle_magazine.rounds == 0 and game.casing_fx.spawned_count == 5, "five shots spend five rounds and eject five shells")
	for i in range(100):
		if game.rifle_magazine.reloading: break
		await tick()
	check(game.rifle_magazine.reloading, "empty rifle reloads after recovery")
	game.stamina = 0.0 # Unaffordable dodge preserves the attack/reload under test.
	check(not game.request_attack() and not game.request_dodge() and not game.set_weapon_family("pistol"), "reload blocks firing/switch; unaffordable dodge preserves reload")
	await step(1.19)
	check(game.rifle_magazine.rounds == 0 and game.rifle_magazine.reloading, "rifle receives no early refill")
	await step(.01)
	check(game.rifle_magazine.rounds == 5 and not game.rifle_magazine.reloading, "rifle refills at 1.2 seconds")
	check(game.staff_flight.shots_fired == 5, "released trigger stays idle after reload")

func independent_ammo() -> void:
	await fresh()
	game.request_attack()
	await step(.92)
	check(game.set_weapon_family("pistol"), "idle rifle can switch to pistol")
	check(game.pistol_magazine.rounds == 10 and game.active_magazine() == game.pistol_magazine, "pistol has independent full ten-round magazine")
	game.request_attack()
	await step(.45)
	check(game.pistol_magazine.rounds == 9 and game.rifle_magazine.rounds == 4, "pistol shot does not consume rifle ammo")
	check(game.set_weapon_family("rifle") and game.active_magazine().rounds == 4, "switching back retains rifle rounds")
	for family in ["pistol", "staff", "mace", "greatsword", "sword", "bow", "crossbow", "shield", "rifle"]:
		check(game.cycle_weapon() and game.weapon_family == family, "weapon cycle reaches " + family)

func lifecycle() -> void:
	await fresh()
	game.request_attack()
	await step(.92)
	check(game.request_reload(), "partial rifle reload is available")
	await step(.25)
	game.toggle_pause()
	var elapsed: float = game.rifle_magazine.elapsed
	var cases: int = game.casing_fx.active.size()
	await step(.7)
	check(game.rifle_magazine.elapsed == elapsed and game.casing_fx.active.size() == cases, "pause freezes rifle reload and casings")
	game.toggle_pause()
	game.restart()
	check(game.rifle_magazine.rounds == 5 and game.pistol_magazine.rounds == 10 and not game.rifle_magazine.reloading, "restart restores independent gun magazines")
	check(game.casing_fx.active.is_empty() and game.casing_fx.spawned_count == 0, "restart clears casing effects")
	game.request_attack()
	await step(.18)
	game.damage_player(1000)
	check(game.mode == "dead" and game.staff_flight.active.is_empty() and game.casing_fx.active.is_empty(), "death clears rifle projectiles and casings")
