extends SceneTree
## Exercises the playable controller through real input and damageable actors.

var checks := 0
var failures: Array[String] = []
var game
const STEP := 1.0 / 120.0


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
	await process_frame
	game.set_physics_process(false)
	# Removing family selection must fail as a behavior prerequisite, not a crash.
	_check(game.has_method("set_weapon_family"), "playable game supports switching weapon family")
	if failures.is_empty():
		_test_default_and_selection()
		await _test_visible_switch_button()
		await _test_physical_switch()
		await _test_released_click()
		await _test_held_combo()
		_test_compact_timing()
		_test_windup_and_long_frame()
		_test_narrow_finisher()
		_test_one_hit_per_target()
		_test_movement_combo_continuation()
		_test_movement_request_order()
		_test_idle_aim_rebase()
		_test_sword_compatibility()
	game.queue_free()
	await process_frame
	_finish()


func _fresh(family: String = "greatsword") -> void:
	game.start_run(true)
	game.set_physics_process(false)
	_check(game.set_weapon_family(family), "idle fixture selects %s" % family)
	game.move_input = Vector2.ZERO
	game.test_aim = Vector3.RIGHT
	game.tick(STEP)


func _step(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.00001:
		var delta: float = minf(STEP, remaining)
		game.tick(delta)
		remaining -= delta


func _dummy():
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.kind == "dummy" and not enemy.dead:
			return enemy
	return null


func _wait_recovery() -> bool:
	for index in range(360):
		if not game.motion.busy:
			return true
		game.tick(STEP)
	return false


func _mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = game.camera.unproject_position(game.player.position + game.test_aim * 2.0)
	event.global_position = event.position
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _key_g(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_G
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _test_default_and_selection() -> void:
	# A menu that silently starts with the old weapon breaks the new default.
	_check(game.weapon_family == "sword" and game.motion.family == "sword", "v10 defaults to ordinary sword")
	game.start_run(true)
	_check(game.set_weapon_family("greatsword"), "greatsword fixture explicitly selects its weapon")
	_check(game.weapon_family == "greatsword" and game.motion.family == "greatsword", "practice uses the explicitly selected greatsword motion family")
	_check(_dummy() != null and is_equal_approx(_dummy().health, 1000.0), "practice uses a real 1000-health dummy")
	_check(not game.set_weapon_family("missing-weapon"), "unknown weapon family is rejected")
	_check(game.weapon_family == "greatsword", "rejected family selection leaves the active weapon intact")
	_check(game.request_attack(), "greatsword attack can start through playable controller")
	_check(not game.set_weapon_family("sword"), "weapon switching is refused during attack")
	_check(game.weapon_family == "greatsword", "busy switch refusal preserves active greatsword")
	_check(_wait_recovery(), "greatsword recovers without release input")
	_check(game._next_combo == 1, "completed first attack opens the second combo slot")
	_check(game.set_weapon_family("sword"), "idle player can switch to sword")
	_check(game._next_combo == 0, "switching weapon resets the combo to its first strike")
	game.start_run(false)
	_check(game.weapon_family == "sword" and game.motion.family == "sword", "starting combat retains the chosen family")
	game.start_run(true)
	_check(game.request_dodge(Vector3.LEFT), "idle dodge establishes a real switching guard")
	_check(not game.set_weapon_family("greatsword"), "weapon switching is refused during dodge")
	_check(game.weapon_family == "sword", "dodge switch refusal preserves sword")
	_step(0.5)
	_check(game.set_weapon_family("greatsword"), "weapon selection resumes when dodge ends")


func _test_physical_switch() -> void:
	# A dead G binding cannot hide behind direct family-selection calls.
	_fresh()
	_key_g(true)
	await process_frame
	_key_g(false)
	_check(game.weapon_family == "sword", "physical G key switches idle greatsword to sword")
	_key_g(true)
	await process_frame
	_key_g(false)
	_check(game.weapon_family == "rifle", "physical G key switches idle sword to rifle")
	_key_g(true)
	await process_frame
	_key_g(false)
	_check(game.weapon_family == "pistol", "physical G key switches idle rifle to pistol")
	_key_g(true)
	await process_frame
	_key_g(false)
	_check(game.weapon_family == "staff", "physical G key switches idle pistol to staff")
	_key_g(true)
	await process_frame
	_key_g(false)
	_check(game.weapon_family == "mace", "physical G key switches idle staff to mace")
	_key_g(true)
	await process_frame
	_key_g(false)
	_check(game.weapon_family == "greatsword", "physical G key completes the six-family cycle back to greatsword")
	game.request_attack()
	_key_g(true)
	await process_frame
	_key_g(false)
	_check(game.weapon_family == "greatsword", "physical G cannot replace a committed attack")
	_wait_recovery()


func _click_weapon_button() -> void:
	var position: Vector2 = game.ui.weapon_button.get_global_rect().get_center()
	var cursor := InputEventMouseMotion.new()
	cursor.position = position
	cursor.global_position = position
	root.push_input(cursor, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event, true)
		await process_frame


func _test_visible_switch_button() -> void:
	# A disconnected HUD button must not hide behind a working keyboard shortcut.
	_fresh()
	await process_frame
	await _click_weapon_button()
	_check(game.weapon_family == "sword", "clicking the visible weapon button switches idle greatsword to sword")
	_check(not game.motion.busy, "weapon-button click is consumed without starting a combat attack")
	await _click_weapon_button()
	_check(game.weapon_family == "rifle", "visible weapon button switches sword to rifle")
	await _click_weapon_button()
	_check(game.weapon_family == "pistol", "visible weapon button switches rifle to pistol")
	await _click_weapon_button()
	_check(game.weapon_family == "staff", "visible weapon button switches pistol to staff")
	await _click_weapon_button()
	_check(game.weapon_family == "mace", "visible weapon button switches staff to mace")
	await _click_weapon_button()
	_check(game.weapon_family == "greatsword", "visible weapon button completes the six-family cycle back to greatsword")
	game.request_attack()
	game.tick(STEP)
	_check(game.ui.weapon_button.disabled, "visible weapon button is disabled throughout a committed attack")
	await _click_weapon_button()
	_check(game.weapon_family == "greatsword", "clicking the disabled weapon button preserves the committed family")
	_wait_recovery()


func _test_released_click() -> void:
	# Release-gated charging, cancelled windup, or duration-scaled damage breaks this.
	_fresh()
	_mouse(true)
	await process_frame
	_check(game.motion.busy and game.motion.stage == 0, "physical click immediately starts the first normal greatsword attack")
	_mouse(false)
	await process_frame
	_step(0.10)
	_check(game.hits == 0, "released click retains a visible preparation before damage")
	game.stamina = 0.0 # Unaffordable dodge preserves the attack/reload under test.
	_check(not game.request_dodge(Vector3.LEFT), "unaffordable dodge preserves released-click preparation")
	_check(_wait_recovery(), "early-released normal attack completes automatically")
	_check(game.hits == 1 and is_equal_approx(game.total_damage, 45.0), "quick press and release deals the full 45 damage once")
	_step(0.15)
	_check(game.hits == 1 and not game.motion.busy, "released click does not begin an unwanted second attack")


func _test_held_combo() -> void:
	# Repeating stage zero, a release gate, charge scaling, or skipped finisher breaks this.
	_fresh()
	_mouse(true)
	await process_frame
	var observed: Array[int] = []
	var released := false
	for index in range(420):
		if game.motion.busy and not observed.has(game.motion.stage):
			observed.append(game.motion.stage)
		if game.motion.busy and game.motion.stage == 2 and not released:
			_mouse(false)
			await process_frame
			released = true
		game.tick(STEP)
		if released and not game.motion.busy:
			break
	_mouse(false)
	_check(observed == [0, 1, 2], "physical held click automatically chains the three ordered strikes")
	_check(released and not game.motion.busy, "releasing during overhead preparation still completes the finisher")
	_check(game.hits == 3, "one held combo lands exactly three real hits on the dummy")
	_check(is_equal_approx(game.total_damage, 177.5), "held combo deals uncharged 45 + 47.5 + 85 damage")


func _test_compact_timing() -> void:
	# A slow side cut or an excessively delayed overhead finish breaks the locked rhythm.
	_fresh()
	game.test_aim = Vector3.LEFT # Miss the dummy so hitstop cannot distort authored timing.
	var durations: Array[float] = []
	for stage in range(3):
		_check(game.request_attack(), "timing fixture starts combo strike %d" % (stage + 1))
		var elapsed := 0.0
		while game.motion.busy and elapsed < 2.0:
			game.tick(STEP)
			elapsed += STEP
		durations.append(elapsed)
	_check(durations[0] <= 0.60 and durations[1] <= 0.60, "both lateral greatsword cuts finish within six tenths of a second")
	_check(absf(durations[0] - durations[1]) < 0.08, "first and reverse cuts share a compact continuous rhythm")
	var mean_side: float = (durations[0] + durations[1]) * 0.5
	_check(durations[2] > mean_side and durations[2] <= mean_side * 1.35, "overhead finisher is only modestly slower than the side cuts")
	_check(game.hits == 0, "cadence fixture used real misses without hitstop")


func _test_windup_and_long_frame() -> void:
	# Applying damage at request time or losing an active window in a long tick breaks this.
	_fresh()
	game.request_attack()
	_check(game.hits == 0, "requesting an attack cannot damage before time advances")
	_step(0.10)
	_check(game.hits == 0 and game.motion.sample().phase == "windup", "greatsword windup remains harmless")
	game.tick(0.75)
	_check(game.hits == 1 and is_equal_approx(game.total_damage, 45.0), "long frame crossing the active interval still applies exactly one full hit")
	_prepare_third()
	_step(0.20)
	_check(game.hits == 0, "raised overhead blade does not hit before its downstroke")
	game.tick(0.90)
	_check(game.hits == 1 and is_equal_approx(game.total_damage, 85.0), "long frame crossing overhead contact preserves one finisher hit")


func _prepare_third() -> void:
	_fresh()
	game.test_aim = Vector3.LEFT
	game.request_attack()
	_wait_recovery()
	game.request_attack()
	_wait_recovery()
	game.test_aim = Vector3.RIGHT
	_check(game.request_attack() and game.motion.stage == 2, "two real missed cuts prepare the forward third strike")


func _test_narrow_finisher() -> void:
	# Reusing the old broad sector or ignoring finite reach breaks this fixture.
	_prepare_third()
	var front = _dummy()
	var side = game.spawn_enemy("dummy", game.player.position + Vector3(1.8, 0.0, 1.3))
	var behind = game.spawn_enemy("dummy", game.player.position + Vector3(-1.4, 0.0, 0.0))
	var far = game.spawn_enemy("dummy", game.player.position + Vector3(4.2, 0.0, 0.0))
	_wait_recovery()
	_check(is_equal_approx(front.health, 915.0), "overhead finisher hits the dummy directly in its forward lane")
	_check(is_equal_approx(side.health, 1000.0), "overhead finisher misses side target inside the former broad sword sector")
	_check(is_equal_approx(behind.health, 1000.0), "overhead finisher misses target behind the player")
	_check(is_equal_approx(far.health, 1000.0), "overhead finisher cannot hit beyond the blade's finite reach")
	_check(game.hits == 1 and is_equal_approx(game.total_damage, 85.0), "narrow slam applies only its one actual forward contact")


func _test_one_hit_per_target() -> void:
	# Clearing hit-target state during an active sweep would damage these actors repeatedly.
	_fresh()
	var second = game.spawn_enemy("dummy", game.player.position + Vector3(1.6, 0.0, 0.2))
	game.request_attack()
	_wait_recovery()
	_check(game.hits == 2 and is_equal_approx(game.total_damage, 90.0), "one lateral sweep hits each of two actual targets once")
	_check(is_equal_approx(second.health, 955.0), "second intersecting target receives exactly one 45-damage strike")


func _test_movement_combo_continuation() -> void:
	# Movement must neither replace a busy strike nor clear the next follow-up.
	_fresh()
	game.test_aim = Vector3.LEFT
	game.request_attack()
	_wait_recovery()
	_check(game.request_attack() and game.motion.stage == 1, "stationary follow-up begins the reverse cut")
	game.move_input = Vector2(0.0, 1.0)
	_step(0.10)
	_check(game.motion.busy and game.motion.stage == 1, "movement during an attack does not replace its committed stage")
	_wait_recovery()
	game.tick(STEP)
	game.move_input = Vector2.ZERO
	_check(game.request_attack() and game.motion.stage == 2, "movement between attacks retains the third cut")
	_wait_recovery()


func _test_sword_compatibility() -> void:
	# Selecting sword must retain the original playable three-stage damage behavior.
	_fresh("sword")
	var damages: Array[float] = []
	for stage in range(3):
		var before: float = game.total_damage
		_check(game.request_attack(), "legacy sword strike %d starts" % (stage + 1))
		_wait_recovery()
		damages.append(game.total_damage - before)
	_check(damages == [18.0, 19.0, 34.0], "legacy sword still deals its original three ordered damage values")
	_check(game.hits == 3, "legacy sword still hits the dummy once per stage")


func _test_movement_request_order() -> void:
	# A real click may arrive before the next idle physics tick sees movement.
	_fresh()
	game.test_aim = Vector3.LEFT
	game.request_attack()
	_wait_recovery()
	game.move_input = Vector2(1.0, 0.0)
	var accepted: bool = game.request_attack()
	_check(accepted and game.motion.stage == 1, "movement retains the second cut even when click arrives before the idle tick")
	_wait_recovery()


func _test_idle_aim_rebase() -> void:
	# Changing idle aim must rotate the held blade without an idle-rest snap.
	_fresh()
	game.request_attack()
	_wait_recovery()
	var before: Dictionary = game.motion.sample()
	game.test_aim = Vector3.LEFT
	game.tick(STEP)
	var turned: Dictionary = game.motion.sample()
	var rotation: float = absf(wrapf(turned.angle - before.angle, -PI, PI))
	_check(absf(rotation - PI) < 0.02, "idle aim reversal rotates the held greatsword by PI with its pose offset intact")
	_check(game.request_attack() and game.motion.stage == 1, "idle aim change preserves the available reverse-cut stage")
	var entry: Dictionary = game.motion.sample()
	_check(absf(wrapf(entry.angle - turned.angle, -PI, PI)) < 0.02 and absf(entry.pitch - turned.pitch) < 0.02 and absf(entry.grip_height - turned.grip_height) < 0.02, "reverse cut starts continuously from the rebased held blade pose")
	_wait_recovery()


func _finish() -> void:
	print("GREATSWORD GAME TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
