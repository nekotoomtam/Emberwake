extends SceneTree
## Controller regression: walking preserves melee order; accepted dodge restarts it.
## Keep normal physics enabled: movement, held input, recovery and pause use real frames.

const MELEE: Array[String] = ["sword", "greatsword", "mace"]
const PHYSICS_HZ := 120.0
var game
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _run() -> void:
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await _frame()
	for family in MELEE:
		await _test_walk_between_strikes(family)
		await _test_click_before_walk_tick(family)
		await _test_held_walk_and_attack(family)
		await _test_accepted_space_dodge(family)
		await _test_rejected_dodge(family)
		await _test_combat_idle_and_pause(family)
		await _test_weapon_and_run_resets(family)
	await _test_mace_commit_lock()
	_release_inputs()
	game.queue_free()
	await process_frame
	print("COMBO CONTINUATION TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _frame() -> void:
	await physics_frame
	await process_frame


func _advance(seconds: float) -> void:
	for index in range(ceili(seconds * PHYSICS_HZ)):
		await _frame()


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = game.camera.unproject_position(game.player.position + game.test_aim * 2.0)
	event.global_position = event.position
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _release_inputs() -> void:
	_key(KEY_D, false)
	_key(KEY_SPACE, false)
	_mouse(false)


func _fresh(family: String, combat: bool = false) -> void:
	_release_inputs()
	game.start_run(not combat)
	_check(game.set_weapon_family(family), "%s fixture selects its real weapon" % family)
	game.move_input = Vector2.ZERO
	game.test_aim = Vector3.RIGHT
	# Preserve the live practice dummy. An empty practice list spawns a new
	# nearby target, introducing damage/hitstop into movement and time checks.
	for enemy in game.enemies:
		enemy.position = Vector3(-10.0, 0.03, -8.0)
	await _frame()
	_check(game.is_physics_processing(), "%s uses the live physics loop" % family)


func _click(expected: int, message: String) -> void:
	_mouse(true)
	_mouse(false)
	_check(game.motion.busy and game.motion.stage == expected, message)


func _recover(message: String) -> void:
	for index in range(360):
		if not game.motion.busy:
			_check(true, message)
			return
		await _frame()
	_check(false, message)


func _two_strikes(family: String) -> void:
	_click(0, "%s first click starts stage 1" % family)
	await _recover("%s first strike completes through physics" % family)
	_click(1, "%s second click starts stage 2" % family)
	await _recover("%s second strike completes through physics" % family)
	_check(game._next_combo == 2, "%s two actual attacks retain stage 3" % family)


func _test_walk_between_strikes(family: String) -> void:
	await _fresh(family)
	_click(0, "%s walking fixture starts stage 1" % family)
	await _recover("%s stage 1 recovers before walking" % family)
	var before: Vector3 = game.player.position
	_key(KEY_D, true)
	await _advance(1.15)
	_key(KEY_D, false)
	_check(game.player.position.distance_to(before) > 2.0, "%s physical D actually repositions the player" % family)
	_check(game._next_combo == 1, "%s walking longer than the old timeout preserves stage 2" % family)
	_click(1, "%s click after long reposition starts stage 2" % family)
	await _recover("%s stage 2 recovers before the next walk" % family)
	_key(KEY_D, true)
	await _advance(0.12)
	_key(KEY_D, false)
	_click(2, "%s click after another walk starts stage 3" % family)
	await _recover("%s walking sequence completes stage 3" % family)
	_check(game._next_combo == 0, "%s completed third strike wraps naturally to stage 1" % family)


func _test_click_before_walk_tick(family: String) -> void:
	await _fresh(family)
	_click(0, "%s request-order fixture starts stage 1" % family)
	await _recover("%s request-order fixture recovers" % family)
	# Input is already walking when the click arrives, before an idle tick.
	_key(KEY_D, true)
	_click(1, "%s movement and click in one frame retain stage 2" % family)
	_key(KEY_D, false)
	await _recover("%s simultaneous input strike completes" % family)


func _test_held_walk_and_attack(family: String) -> void:
	await _fresh(family)
	_key(KEY_D, true)
	_mouse(true)
	var observed: Array[int] = []
	var last_stage := -1
	for index in range(480):
		if game.motion.busy and game.motion.stage != last_stage:
			last_stage = game.motion.stage
			observed.append(last_stage)
			if observed.size() == 3:
				break
		await _frame()
	_mouse(false)
	_key(KEY_D, false)
	_check(observed == [0, 1, 2], "%s held D plus held LMB produces ordered stages 1, 2, 3" % family)
	await _recover("%s releasing held input lets the committed strike finish" % family)
	_check(not game._held, "%s physical LMB release clears repeat input" % family)


func _test_accepted_space_dodge(family: String) -> void:
	await _fresh(family)
	await _two_strikes(family)
	var before: Vector3 = game.player.position
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	_check(game._dodge_left > 0.0 and game.stamina < 100.0, "%s physical Space accepts an affordable idle dodge" % family)
	_check(game._next_combo == 0, "%s accepted Space resets the retained stage 3" % family)
	_check(not game.request_attack(), "%s cannot cancel an accepted dodge into an attack" % family)
	await _advance(0.30)
	_check(game.player.position.distance_to(before) > 1.5, "%s accepted Space performs the actual dodge movement" % family)
	_click(0, "%s first click after dodge starts stage 1" % family)
	await _recover("%s post-dodge stage 1 completes" % family)


func _test_rejected_dodge(family: String) -> void:
	await _fresh(family)
	_click(0, "%s rejected-dodge fixture starts stage 1" % family)
	await _recover("%s rejected-dodge first strike recovers" % family)
	_click(1, "%s rejected-dodge fixture commits stage 2" % family)
	game.stamina = 0.0 # Unaffordable dodge preserves the attack/reload under test.
	_check(not game.request_dodge(Vector3.LEFT), "%s unaffordable dodge preserves busy attack" % family)
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	_check(game.motion.busy and game.motion.stage == 1 and game._dodge_left == 0.0, "%s unaffordable Space neither cancels nor replaces stage 2" % family)
	_check(game._next_combo == 1, "%s rejected unaffordable dodge leaves the current chain index intact" % family)
	await _recover("%s committed stage 2 survives rejected dodge" % family)
	_check(game._next_combo == 2, "%s rejected unaffordable dodge still opens stage 3" % family)
	game.stamina = 29.0
	_check(not game.request_dodge(Vector3.LEFT), "%s insufficient stamina rejects request_dodge" % family)
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	_check(game._dodge_left == 0.0 and game._next_combo == 2, "%s unaffordable Space preserves retained stage 3" % family)
	_click(2, "%s click after both rejected dodges starts stage 3" % family)
	await _recover("%s stage 3 completes after rejected dodges" % family)


func _test_combat_idle_and_pause(family: String) -> void:
	await _fresh(family, true)
	_click(0, "%s combat idle fixture starts stage 1" % family)
	await _recover("%s combat idle fixture recovers" % family)
	await _advance(1.15)
	_check(game.mode == "combat" and game._next_combo == 1, "%s standing over one second in combat retains stage 2" % family)
	_click(1, "%s delayed stationary combat click starts stage 2" % family)
	await _advance(0.05)
	game.toggle_pause()
	var frozen_position: Vector3 = game.player.position
	var frozen_elapsed: float = game.motion.elapsed
	var frozen_run_time: float = game.run_time
	var frozen_stamina: float = game.stamina
	var frozen_health: float = game.health
	var frozen_combo: int = game._next_combo
	var enemy_position: Vector3 = game.enemies[0].position
	_key(KEY_D, true)
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	await _advance(1.15)
	_check(game.mode == "paused" and game.motion.busy and is_equal_approx(game.motion.elapsed, frozen_elapsed), "%s pause freezes the committed attack" % family)
	_check(game.player.position.is_equal_approx(frozen_position) and game.enemies[0].position.is_equal_approx(enemy_position), "%s pause freezes player and enemy movement" % family)
	_check(is_equal_approx(game.run_time, frozen_run_time) and is_equal_approx(game.stamina, frozen_stamina) and is_equal_approx(game.health, frozen_health), "%s pause freezes run time, stamina, and health" % family)
	_check(game._next_combo == frozen_combo and game._dodge_left == 0.0, "%s paused movement and Space preserve combo and dodge state" % family)
	_key(KEY_D, false)
	game.toggle_pause()
	await _recover("%s unpause resumes the existing stage 2" % family)
	_click(2, "%s click after unpause continues to stage 3" % family)
	await _recover("%s combat stage 3 completes after pause" % family)


func _test_weapon_and_run_resets(family: String) -> void:
	await _fresh(family)
	await _two_strikes(family)
	var replacement := "sword" if family != "sword" else "greatsword"
	_check(game.set_weapon_family(replacement), "%s can switch weapon after recovery" % family)
	_check(game._next_combo == 0, "%s accepted weapon change resets the retained combo" % family)
	_click(0, "%s replacement weapon starts stage 1" % family)
	await _recover("%s replacement strike recovers" % family)
	_check(game._next_combo == 1, "%s replacement strike establishes a nonzero index" % family)
	game.start_run(true)
	for enemy in game.enemies:
		enemy.position = Vector3(-10.0, 0.03, -8.0)
	_check(game._next_combo == 0 and not game.motion.busy, "%s new run resets retained combo and motion" % family)
	_click(0, "%s new run starts stage 1" % family)
	_check(not game.set_weapon_family(family), "%s busy weapon switch remains rejected" % family)
	await _recover("%s new-run strike completes" % family)


func _test_mace_commit_lock() -> void:
	await _fresh("mace")
	_key(KEY_D, true)
	_click(0, "mace moving click begins its committed lift")
	var before: Vector3 = game.player.position
	await _advance(0.30)
	_check(game.motion.busy and game.motion.stage == 0, "mace lift stays committed while D is held")
	var offset: Vector3 = game.player.position - before
	offset.y = 0.0
	var expected_step := Vector3(cos(game.motion.aim_angle), 0.0, sin(game.motion.aim_angle)) * 0.16
	_check(offset.distance_to(expected_step) < 0.01, "mace permits its authored step while ordinary D movement stays locked")
	game.stamina = 0.0 # Unaffordable dodge preserves the attack/reload under test.
	_check(not game.request_dodge(), "unaffordable dodge preserves mace committed lift")
	_key(KEY_D, false)
	await _recover("mace committed lift finishes without cancellation")
