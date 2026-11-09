extends SceneTree
## Mace behavior through the real playable controller, inputs and physics.

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
	Engine.physics_ticks_per_second = 120
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	_check(game.weapon_family == "sword" and game.motion.family == "sword", "v10 equips ordinary sword by default")
	_check(game.has_method("cycle_weapon"), "playable controller exposes the shared six-family weapon cycle")
	_check(game.set_weapon_family("mace"), "playable controller accepts the Mace family")
	if failures.is_empty():
		await _test_rendered_idle_entry_continuity()
		await _test_default_and_selection()
		await _test_physical_cycle()
		await _test_visible_cycle()
		await _test_released_click()
		await _test_held_combo()
		await _test_mouse_reaim()
		await _test_per_stage_damage()
		await _test_contact_once_and_range()
		await _test_extended_range_edges()
		await _test_rendered_contact_reach()
		await _test_dash_variants()
		await _test_repeated_dash_budget()
		await _test_near_target_stop()
		await _test_solid_pillar_stop()
		await _test_dash_incoming_damage()
		await _test_three_hit_directions()
	game.queue_free()
	await process_frame
	print("MACE GAME TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _fresh(direction: Vector3 = Vector3.RIGHT, target_distance: float = 1.25) -> void:
	_mouse(false)
	game.start_run(true)
	game.set_physics_process(false)
	_check(game.set_weapon_family("mace"), "idle fixture equips Mace")
	game.move_input = Vector2.ZERO
	game.test_aim = direction
	_dummy().position = game.player.position + direction * target_distance
	await _tick()


func _dummy():
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.kind == "dummy" and not enemy.dead:
			return enemy
	return null


func _tick(delta: float = STEP) -> void:
	# Every body operation runs at a physics boundary, including headless tests.
	await physics_frame
	game.tick(delta)


func _step(seconds: float, delta: float = STEP) -> void:
	var remaining := seconds
	while remaining > 0.000001:
		await _tick(minf(delta, remaining))
		remaining -= delta


func _recover(delta: float = STEP) -> bool:
	for index in range(600):
		if not game.motion.busy:
			return true
		await _tick(delta)
	return false


func _point(direction: Vector3) -> void:
	var event := InputEventMouseMotion.new()
	event.position = game.camera.unproject_position(game.player.position + direction * 2.0)
	event.global_position = event.position
	# Camera projects viewport coordinates. Headless OS windows can be 64x64,
	# so parsing them as window coordinates would apply stretch twice.
	root.push_input(event, true)


func _mouse(pressed: bool) -> void:
	if game == null:
		return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	var direction: Vector3 = game.test_aim if game.test_aim.length_squared() > 0.001 else game.aim
	event.position = game.camera.unproject_position(game.player.position + direction * 2.0)
	event.global_position = event.position
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _key_g(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_G
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _click_button() -> void:
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


func _test_default_and_selection() -> void:
	game.start_run(true)
	_check(game.weapon_family == "mace" and game.motion.family == "mace", "practice retains the explicitly selected Mace")
	_check(not game.set_weapon_family("missing-weapon") and game.weapon_family == "mace", "invalid family cannot replace Mace")
	_check(game.request_attack(), "Mace attack starts through the playable controller")
	_check(not game.set_weapon_family("sword"), "selection refuses to replace a committed Mace attack")
	game.cycle_weapon()
	_check(game.weapon_family == "mace", "shared weapon cycle refuses to replace a committed Mace attack")
	_check(await _recover(), "Mace uppercut completes without a release gate")
	_check(game._next_combo == 1, "completed uppercut makes the short dash available")
	_check(game.set_weapon_family("sword") and game._next_combo == 0, "family selection resets the combo")
	_check(game.set_weapon_family("mace"), "idle player selects Mace again")
	_check(game.request_dodge(Vector3.LEFT), "normal dodge establishes its real weapon-switch guard")
	game.cycle_weapon()
	_check(game.weapon_family == "mace" and not game.set_weapon_family("greatsword"), "cycle and selection both refuse to replace a dodge")
	await _step(0.5)
	_check(game.set_weapon_family("greatsword"), "weapon selection resumes after the dodge")


func _test_rendered_idle_entry_continuity() -> void:
	# A generic sword idle angle must not rotate the rendered Mace before windup.
	await _fresh()
	for reset_case in ["fresh idle", "timed-out combo idle"]:
		if reset_case == "timed-out combo idle":
			await _recover()
			await _step(0.90)
		game._visual_tick(0.0)
		var before: Dictionary = game.avatar.get_blade_points()
		_check(game.request_attack(), "%s starts a real Mace attack" % reset_case)
		game._visual_tick(0.0)
		var after: Dictionary = game.avatar.get_blade_points()
		var grip_distance: float = before.grip.distance_to(after.grip)
		var tip_distance: float = before.tip.distance_to(after.tip)
		_check(grip_distance < 0.001, "%s preserves the rendered grip at windup zero (jump=%.4f)" % [reset_case, grip_distance])
		_check(tip_distance < 0.001, "%s preserves the rendered tip at windup zero (jump=%.4f)" % [reset_case, tip_distance])
	await _recover()


func _test_physical_cycle() -> void:
	await _fresh()
	for family in ["greatsword", "sword", "rifle", "pistol", "staff", "mace"]:
		_key_g(true)
		await process_frame
		_key_g(false)
		_check(game.weapon_family == family, "physical G cycles to %s" % family)
	game.request_attack()
	_key_g(true)
	await process_frame
	_key_g(false)
	_check(game.weapon_family == "mace", "physical G preserves a committed Mace attack")
	await _recover()


func _test_visible_cycle() -> void:
	await _fresh()
	await process_frame
	for family in ["greatsword", "sword", "rifle", "pistol", "staff", "mace"]:
		await _click_button()
		_check(game.weapon_family == family, "visible HUD button cycles to %s" % family)
		_check(not game.motion.busy, "HUD cycle click is consumed without starting an attack")
	game.request_attack()
	await _tick()
	_check(game.ui.weapon_button.disabled, "HUD weapon button disables during a committed Mace attack")
	await _click_button()
	_check(game.weapon_family == "mace", "disabled HUD button preserves Mace")
	await _recover()


func _test_released_click() -> void:
	# A charge gate, release cancellation or held-duration multiplier breaks this.
	await _fresh()
	_mouse(true)
	await process_frame
	_check(game.motion.busy and game.motion.stage == 0, "physical click immediately starts the Mace uppercut")
	_mouse(false)
	await _step(0.10)
	_check(game.hits == 0, "quick release preserves harmless uppercut preparation")
	game.stamina = 0.0 # Unaffordable dodge preserves the attack/reload under test.
	_check(not game.request_dodge(Vector3.LEFT), "unaffordable dodge preserves uppercut preparation")
	_check(await _recover(), "quick-release uppercut completes automatically")
	_check(game.hits == 1 and is_equal_approx(game.total_damage, 34.0), "quick release deals the full uncharged 34 damage once")
	await _step(0.15)
	_check(game.hits == 1 and not game.motion.busy, "released click does not repeat the uppercut")


func _test_held_combo() -> void:
	# Repeated stage zero, skipped dash/finisher or unintended charging breaks this.
	await _fresh()
	_mouse(true)
	await process_frame
	var stages: Array[int] = []
	var released := false
	for index in range(420):
		if game.motion.busy and not stages.has(game.motion.stage):
			stages.append(game.motion.stage)
		if game.motion.busy and game.motion.stage == 2 and not released:
			_mouse(false)
			released = true
		await _tick()
		if released and not game.motion.busy:
			break
	_mouse(false)
	_check(stages == [0, 1, 2], "held mouse chains uppercut, short dash and downward slam in order")
	_check(released and not game.motion.busy, "released finisher completes its downstroke")
	_check(game.hits == 3 and is_equal_approx(game.total_damage, 92.0), "held combo lands exactly 34 + 12 + 46 damage")
	_check(game.mace_dash_travelled <= 0.7501, "held combo dash preserves its lifetime travel budget")


func _test_mouse_reaim() -> void:
	# Caching first-strike aim or steering during the dash breaks these real cursor inputs.
	await _fresh(Vector3.FORWARD)
	game.test_aim = Vector3.ZERO
	_point(Vector3.FORWARD)
	_check(game.request_attack(), "cursor-directed uppercut starts")
	_check(absf(wrapf(game.motion.aim_angle + PI / 2.0, -PI, PI)) < 0.03, "uppercut reads the upward cursor direction (angle=%.4f cursor=%s viewport=%s)" % [game.motion.aim_angle, game._mouse_position, root.get_visible_rect()])
	await _recover()
	_dummy().position = game.player.position + Vector3.RIGHT * 1.25
	_point(Vector3.RIGHT)
	_check(game.request_attack() and game.motion.stage == 1, "fresh cursor direction starts the second strike")
	_check(absf(game.motion.aim_angle) < 0.03, "dash re-reads cursor to the right between strikes (angle=%.4f cursor=%s)" % [game.motion.aim_angle, game._mouse_position])
	var dash_start: Vector3 = game.player.position
	_point(Vector3.BACK)
	await _recover()
	var travel: Vector3 = game.player.position - dash_start
	_check(travel.x > 0.40 and absf(travel.z) < 0.02, "short dash travels along its newly selected rightward aim (travel=%s)" % travel)
	_check(absf(game.motion.aim_angle) < 0.03, "cursor motion cannot steer the committed short dash (angle=%.4f)" % game.motion.aim_angle)
	game.test_aim = Vector3.RIGHT
	_check(game.request_attack() and game.motion.stage == 2, "third strike remains reachable after the redirected dash")
	await _recover()
	_check(game.hits == 3 and is_equal_approx(game.total_damage, 92.0), "redirected real-cursor combo lands all three normal damage contacts")


func _test_per_stage_damage() -> void:
	await _fresh()
	var damages: Array[float] = []
	for stage in range(3):
		var before: float = game.total_damage
		_check(game.request_attack() and game.motion.stage == stage, "ordered Mace strike %d starts" % (stage + 1))
		await _recover()
		damages.append(game.total_damage - before)
	_check(damages == [34.0, 12.0, 46.0], "middle dash contact is weaker than both weighted Mace strikes")
	_check(game.hits == 3, "per-stage Mace contacts each damage the target once")


func _test_contact_once_and_range() -> void:
	await _fresh()
	var adjacent = game.spawn_enemy("dummy", game.player.position + Vector3(1.20, 0.0, 0.12))
	var behind = game.spawn_enemy("dummy", game.player.position + Vector3(-1.25, 0.0, 0.0))
	var far = game.spawn_enemy("dummy", game.player.position + Vector3(3.5, 0.0, 0.0))
	game.request_attack()
	await _recover()
	_check(game.hits == 2 and is_equal_approx(game.total_damage, 68.0), "uppercut damages each of two intersecting real targets once")
	_check(is_equal_approx(adjacent.health, 966.0), "adjacent uppercut target takes one full contact")
	_check(is_equal_approx(behind.health, 1000.0), "upward strike cannot hit a target behind the player")
	_check(is_equal_approx(far.health, 1000.0), "Mace uppercut has finite short reach")


func _prepare_dash(direction: Vector3 = Vector3.RIGHT) -> void:
	game.test_aim = Vector3.LEFT
	_check(game.request_attack(), "dash fixture completes a real first strike")
	await _recover()
	game.test_aim = direction
	_check(game.request_attack() and game.motion.stage == 1, "second strike starts as the real combo follow-up")


func _test_extended_range_edges() -> void:
	# These real targets sat beyond the old short weapon's hit boundary.
	for target_distance: float in [2.30, 4.30]:
		await _fresh(Vector3.RIGHT, target_distance)
		_check(game.request_attack() and game.motion.stage == 0, "range-edge fixture starts a real first strike at %.2f" % target_distance)
		await _recover()
		var expected_damage := 34.0 if target_distance < 3.0 else 0.0
		_check(is_equal_approx(game.total_damage, expected_damage), "first strike at %.2f deals %.0f damage with the ordinary .36 target radius (got %.0f)" % [target_distance, expected_damage, game.total_damage])
	# v15 searches to twice this strike's2.55 reach, so the far-miss centre
	# stays beyond5.10 while the existing normal hit remains unchanged.
	for target_distance: float in [2.80, 5.20]:
		await _fresh(Vector3.RIGHT, 7.0)
		# Complete the first two attacks away from the dummy; never write stage,
		# elapsed, hit counters or damage to manufacture a standalone finisher.
		game.test_aim = Vector3.LEFT
		for stage in range(2):
			_check(game.request_attack() and game.motion.stage == stage, "finisher-edge fixture completes real prerequisite strike %d" % (stage + 1))
			await _recover()
		_check(game.hits == 0 and is_zero_approx(game.total_damage), "finisher-edge prerequisites aimed away cannot pre-damage the target")
		_dummy().position = game.player.position + Vector3.RIGHT * target_distance
		game.test_aim = Vector3.RIGHT
		_check(game.request_attack() and game.motion.stage == 2, "range-edge fixture reaches its real third strike at %.2f" % target_distance)
		await _recover()
		var expected_damage := 46.0 if target_distance < 3.0 else 0.0
		_check(is_equal_approx(game.total_damage, expected_damage), "third strike at %.2f deals %.0f standalone damage with the ordinary .36 target radius (got %.0f)" % [target_distance, expected_damage, game.total_damage])


func _test_rendered_contact_reach() -> void:
	var expected_reaches: Array[float] = [2.1, 2.2, 2.55]
	for direction: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		await _fresh(direction, 7.0)
		_check_rigid_weapon("fresh idle toward %s" % str(direction))
		for stage in range(3):
			_check(game.request_attack() and game.motion.stage == stage, "rendered reach fixture starts real stage %d toward %s" % [stage, str(direction)])
			var attack: Dictionary = game.motion.definition(stage)
			await _step(attack.windup * 0.5)
			_check_rigid_weapon("stage %d windup toward %s" % [stage, str(direction)])
			var contact_time: float = attack.windup + attack.active * attack.impact_progress
			await _step(contact_time - game.motion.elapsed)
			_check_rigid_weapon("stage %d contact toward %s" % [stage, str(direction)])
			var points: Dictionary = game.avatar.get_blade_points()
			var physical_reach: float = (points.tip - game.player.position).dot(direction)
			_check(absf(physical_reach - expected_reaches[stage]) < 0.0001, "real rendered stage %d contact projects to %.2f toward %s (got %.6f)" % [stage, expected_reaches[stage], str(direction), physical_reach])
			var recovery_time: float = attack.windup + attack.active + attack.recovery * 0.5
			await _step(recovery_time - game.motion.elapsed)
			_check_rigid_weapon("stage %d recovery toward %s" % [stage, str(direction)])
			await _recover()
			_check_rigid_weapon("stage %d held idle toward %s" % [stage, str(direction)])


func _check_rigid_weapon(label: String) -> void:
	var points: Dictionary = game.avatar.get_blade_points()
	var length: float = points.grip.distance_to(points.tip)
	_check(absf(length - 1.9) < 0.0001, "%s retains the same physical 1.90-unit Mace (got %.6f)" % [label, length])


func _test_dash_variants() -> void:
	# Render delta, ordinary held movement, or frame subdivision must not extend a dash.
	for rate in [30, 60, 120, 240]:
		Engine.physics_ticks_per_second = rate
		await _fresh(Vector3.RIGHT, 7.0)
		await _prepare_dash()
		var start: Vector3 = game.player.position
		game.move_input = Vector2.RIGHT
		await _recover(1.0 / float(rate))
		var distance: float = Vector2(game.player.position.x - start.x, game.player.position.z - start.z).length()
		_check(distance >= 0.73 and distance <= 0.7501, "empty short dash stays within .75 units at %d Hz with movement held" % rate)
		_check(absf(game.mace_dash_travelled - distance) < 0.005, "reported dash travel matches actual ground movement at %d Hz" % rate)
		game.move_input = Vector2.ZERO
		_check(game.request_attack() and game.motion.stage == 2, "finisher remains reachable after %d Hz dash" % rate)
		await _recover(1.0 / float(rate))
	Engine.physics_ticks_per_second = 120
	await _fresh(Vector3.RIGHT, 7.0)
	await _prepare_dash()
	var start: Vector3 = game.player.position
	await _tick(0.75)
	_check(not game.motion.busy and game.player.position.x - start.x <= 0.7501, "one long tick cannot overshoot the entire short dash budget")
	_check(game.player.position.x - start.x >= 0.73, "one long tick preserves the dash's actual forward displacement")
	_check(game.request_attack() and game.motion.stage == 2, "long tick crossing the dash still exposes the third strike")
	await _recover()


func _test_near_target_stop() -> void:
	await _fresh(Vector3.RIGHT, 7.0)
	game.test_aim = Vector3.LEFT
	game.request_attack()
	await _recover()
	var start: Vector3 = game.player.position
	_dummy().position = start + Vector3.RIGHT * 0.85
	game.test_aim = Vector3.RIGHT
	_check(game.request_attack() and game.motion.stage == 1, "near-target fixture starts a real short dash")
	var minimum_separation := INF
	for index in range(600):
		if not game.motion.busy:
			break
		await _tick()
		minimum_separation = minf(minimum_separation, _dummy().position.x - game.player.position.x)
	_check(not game.motion.busy, "near-target dash completes after its clipped movement")
	_check(game.player.position.x - start.x <= 0.115, "nearby living target clips dash travel before the combined .74 radius")
	_check(minimum_separation >= 0.735, "short dash never overlaps or crosses the nearby living target")
	_check(game.hits == 1 and is_equal_approx(game.total_damage, 12.0), "short dash still lands its one weak hit when a nearby target stops movement")
	_check(game.request_attack() and game.motion.stage == 2, "target-blocked short dash still chains into its finisher")
	await _recover()
	_check(game.hits == 2 and is_equal_approx(game.total_damage, 58.0), "target-blocked dash and following finisher both land")


func _test_solid_pillar_stop() -> void:
	await _fresh(Vector3.RIGHT, 7.0)
	game.test_aim = Vector3.LEFT
	_check(game.request_attack(), "pillar fixture completes a real uppercut prerequisite")
	await _recover()
	# Place the fixture after the uppercut's new .16 step, so this still tests
	# the accepted dash's original short gap to the solid pillar surface.
	game.player.position = Vector3(6.85, 0.03, 5.4)
	await _tick()
	game.test_aim = Vector3.RIGHT
	_check(game.request_attack() and game.motion.stage == 1, "pillar fixture starts its real second-stage dash")
	var start: Vector3 = game.player.position
	await _recover()
	_check(game.player.position.x > start.x and game.player.position.x <= 7.08, "real solid pillar stops the short dash at its front collision surface")
	_check(game.mace_dash_travelled < 0.30, "blocked dash reports clipped actual travel rather than authored maximum")
	_check(game.request_attack() and game.motion.stage == 2, "pillar-blocked dash still makes its finisher reachable")
	await _recover()


func _test_dash_incoming_damage() -> void:
	await _fresh(Vector3.RIGHT, 7.0)
	await _prepare_dash()
	for index in range(100):
		if not game.motion.busy or game.motion.sample().phase == "active":
			break
		await _tick()
	_check(game.motion.busy and game.motion.stage == 1, "incoming-damage fixture reaches the actual dash active interval")
	_check(is_zero_approx(game._iframes) and is_zero_approx(game._dodge_left), "Mace basic dash grants no dodge or invulnerability state")
	_check(is_equal_approx(game.stamina, 100.0), "Mace basic dash spends no dodge stamina")
	game.shoot(game.player.position + Vector3(0.0, 0.6, 0.10), Vector3.RIGHT, 11.0)
	await _tick()
	_check(is_equal_approx(game.health, 89.0), "ordinary incoming projectile applies full damage during the Mace dash")
	_check(game.motion.busy and game.motion.stage == 1, "taking normal damage does not replace the committed basic dash")
	await _recover()


func _test_repeated_dash_budget() -> void:
	# Carrying a prior cumulative offset/counter into the next combo breaks this.
	await _fresh(Vector3.RIGHT, 7.0)
	for cycle in range(2):
		_check(game.request_attack() and game.motion.stage == 0, "new combo %d starts with its first strike" % (cycle + 1))
		_check(is_zero_approx(game.mace_dash_travelled), "new combo %d resets reported short-dash travel" % (cycle + 1))
		await _recover()
		_check(game.request_attack() and game.motion.stage == 1, "new combo %d reaches its short dash" % (cycle + 1))
		var before: Vector3 = game.player.position
		await _recover()
		_check(absf(game.player.position.x - before.x - 0.75) < 0.002, "new combo %d gets one fresh .75-unit dash budget" % (cycle + 1))
		_check(game.request_attack() and game.motion.stage == 2, "new combo %d reaches its finisher" % (cycle + 1))
		await _recover()


func _test_three_hit_directions() -> void:
	# All quadrants must use the same real three-contact behavior.
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		await _fresh(direction)
		for stage in range(3):
			game.request_attack()
			await _recover()
		_check(game.hits == 3 and is_equal_approx(game.total_damage, 92.0), "Mace combo lands all three full contacts toward %s" % str(direction))
		var offset: Vector3 = _dummy().position - game.player.position
		_check(offset.dot(direction) >= 0.735, "Mace dash keeps its target in front toward %s" % str(direction))
