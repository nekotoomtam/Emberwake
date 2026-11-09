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
	check(game.weapon_family == "sword", "v10 launches with ordinary sword")
	check(game.set_weapon_family("pistol"), "controller accepts pistol")
	if failures.is_empty():
		await single_shot()
		await full_magazine()
		await partial_reload_and_pause()
		await lifecycle_and_selection()
		await aim_and_projectile_type()
	game.queue_free()
	await process_frame
	print("PISTOL GAME TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func tick(delta: float = STEP) -> void:
	await physics_frame
	game.tick(delta)

func step(seconds: float) -> void:
	var remaining := seconds
	while remaining > .0000001:
		await tick(minf(remaining, STEP))
		remaining -= STEP

func fresh(direction: Vector3 = Vector3.RIGHT) -> void:
	mouse(false)
	game.start_run(true)
	game.set_physics_process(false)
	check(game.set_weapon_family("pistol"), "fresh fixture selects pistol")
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

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	Input.flush_buffered_events()

func single_shot() -> void:
	await fresh()
	check(game.pistol_magazine.capacity == 10 and game.pistol_magazine.rounds == 10, "base pistol begins with ten rounds")
	check(is_equal_approx(game.pistol_magazine.reload_duration, .5), "reload duration comes from base weapon definition")
	check(game.motion.definition(0).magazine_capacity == 10 and game.motion.definition(0).reload_time == .5, "weapon definition owns magazine and reload values")
	var origin: Vector3 = game.player.position
	mouse(true)
	mouse(false)
	check(game.motion.busy and game.motion.stage == 0, "click commits the only gun pose")
	await step(.03)
	check(game.pistol_magazine.rounds == 10 and game.staff_flight.shots_fired == 0 and game.hits == 0, "windup neither spends a round nor applies melee damage")
	await step(.05)
	check(game.pistol_magazine.rounds == 9 and game.staff_flight.shots_fired == 1, "release creates one bullet and spends exactly one round")
	check(game.staff_flight.active.size() == 1 and game.staff_flight.active[0].element == "physical", "visible bullet carries physical rather than fire data")
	await step(.4)
	check(game.hits == 1 and game.total_damage == 18, "one bullet contacts once for normal gun damage")
	check(game.staff_flight.active.is_empty() and game._next_combo == 0, "hit consumes bullet and basic gun remains stage zero")
	check(game.pistol_magazine.rounds == 9 and not game.pistol_magazine.reloading, "partial magazine waits for reload command")
	check(Vector2(game.player.position.x - origin.x, game.player.position.z - origin.z).length() < .001, "shooting adds no automatic lunge")
	check(game.ui.ammo_text.text.contains("9") and game.ui.ammo_text.visible, "HUD shows remaining pistol rounds")

func full_magazine() -> void:
	await fresh()
	mouse(true)
	for i in range(600):
		await tick()
		if game.staff_flight.shots_fired == 10:
			mouse(false)
			break
	check(game.staff_flight.shots_fired == 10 and game.pistol_magazine.rounds == 0, "ten held shots exhaust the ten-round magazine")
	for i in range(100):
		if game.pistol_magazine.reloading: break
		await tick()
	check(game.pistol_magazine.reloading and not game.motion.busy, "empty magazine automatically reloads after shot recovery")
	game.stamina = 0.0 # Unaffordable dodge preserves the attack/reload under test.
	check(not game.request_attack() and not game.request_dodge() and not game.set_weapon_family("staff"), "reload blocks firing/switch; unaffordable dodge preserves reload")
	var rounds_before: int = game.pistol_magazine.rounds
	await step(.25)
	check(game.pistol_magazine.reloading and game.pistol_magazine.rounds == rounds_before, "half reload grants no premature ammunition")
	check(absf(game.pistol_magazine.progress() - .5) < .02, "reload midpoint is one quarter second")
	var pose: Dictionary = game.current_visual_sample()
	check(pose.phase == "reload" and float(pose.screen_roll)>TAU*1.4 and float(pose.screen_roll)<TAU*2, "fast flourish passes one full turn before reload midpoint")
	await step(.24)
	check(game.pistol_magazine.rounds == 0 and game.pistol_magazine.reloading, "reload is still incomplete at .49 seconds")
	await step(.01)
	check(game.pistol_magazine.rounds == 10 and not game.pistol_magazine.reloading, "reload refills exactly at .5 seconds")
	check(game.staff_flight.shots_fired == 10, "released trigger never fires an eleventh shot on refill")
	check(game.request_attack(), "reloaded pistol can shoot again")
	await step(.50)
	check(game.staff_flight.shots_fired == 11 and game.pistol_magazine.rounds == 9, "post-reload shot spends one round")

func partial_reload_and_pause() -> void:
	await fresh()
	check(not game.request_reload(), "full magazine cannot reload or spin needlessly")
	game.request_attack()
	await step(.50)
	key(KEY_R)
	check(game.pistol_magazine.reloading and game.hits == 1, "physical R starts partial reload without restarting run")
	await step(.2)
	game.toggle_pause()
	var elapsed: float = game.pistol_magazine.elapsed
	await step(.5)
	check(is_equal_approx(game.pistol_magazine.elapsed, elapsed) and game.pistol_magazine.rounds == 9, "pause freezes reload and ammunition")
	game.toggle_pause()
	await step(.3)
	check(game.pistol_magazine.rounds == 10 and not game.pistol_magazine.reloading, "resume completes only the remaining reload time")

func lifecycle_and_selection() -> void:
	await fresh()
	game.request_attack()
	await step(.50)
	check(game.set_weapon_family("staff") and game.set_weapon_family("pistol"), "idle weapon changes remain available")
	check(game.pistol_magazine.rounds == 9, "weapon switching does not refill pistol rounds")
	for family in ["staff", "mace", "greatsword", "sword", "rifle", "pistol"]:
		check(game.cycle_weapon() and game.weapon_family == family, "six-way cycle reaches " + family)
	game.request_reload()
	await step(.1)
	key(KEY_T)
	check(game.mode == "practice" and game.pistol_magazine.rounds == 10 and not game.pistol_magazine.reloading, "T restarts and cancels reload cleanly")
	game.request_attack()
	await step(.50)
	game.request_reload()
	game.damage_player(1000)
	check(game.mode == "dead" and not game.pistol_magazine.reloading and game.staff_flight.active.is_empty(), "death clears reload and orphan bullets")
	game.return_menu()
	check(not game.pistol_magazine.reloading, "menu has no lingering reload")

func aim_and_projectile_type() -> void:
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		await fresh(direction)
		check(game.request_attack(), "cardinal gun shot begins")
		game.test_aim = -direction
		await step(.4)
		check(game.hits == 1 and game.total_damage == 18 and game.staff_flight.resolved.back().element == "physical", "bullet retains its locked cardinal aim and physical type")
	await fresh()
	check(game.set_weapon_family("staff"), "staff remains selectable")
	check(not game.request_reload(), "staff cannot reload the pistol")
	game.request_attack()
	await step(1.0)
	check(game.hits == 1 and game.total_damage == 72 and game.staff_flight.resolved.back().element == "fire", "shared flight retains the accepted fire staff behavior")
	check(game.pistol_magazine.rounds == 10, "staff firing consumes no pistol ammunition")
