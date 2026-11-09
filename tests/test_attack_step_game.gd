extends SceneTree
## Attack travel through the playable controller and actual CharacterBody physics.
## Fixtures move actors only; all stages and damage arise from normal requests.

const STEP := 1.0 / 120.0
const DISTANCES := {"sword": [0.18, 0.20, 0.30], "greatsword": [0.28, 0.30, 0.42], "mace": [0.16, 0.75, 0.24]}
var game
var checks := 0
var failures: Array[String] = []
var has_step_counter := false


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)


func _run() -> void:
	Engine.physics_ticks_per_second = 240
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	_check(game.player is CharacterBody3D, "attack steps use the real collision body")
	has_step_counter = game.get("attack_step_travelled") != null
	_check(has_step_counter, "controller exposes actual ordinary attack-step travel")
	await _test_authored_travel()
	await _test_cursor_lock()
	await _test_long_frame_hit_order()
	await _test_target_stops()
	await _test_solid_world_stops()
	await _test_pause()
	await _test_incoming_damage()
	await _test_walking_chain_and_space()
	game.queue_free()
	await process_frame
	print("ATTACK STEP GAME TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _dummy():
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.kind == "dummy" and not enemy.dead:
			return enemy
	return null


func _fresh(family: String) -> void:
	game.start_run(true)
	game.set_physics_process(false)
	_check(game.set_weapon_family(family), "fixture equips %s" % family)
	game.move_input = Vector2.ZERO
	game.test_aim = Vector3.RIGHT
	game.player.position = Vector3(-3.5, 0.03, 0)
	# Retain the genuine practice actor, avoiding practice's empty-list respawn.
	_dummy().position = Vector3(-7, 0.03, -7)
	await _tick()


func _tick(delta: float = STEP) -> void:
	await physics_frame
	game.tick(delta)


func _step(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.000001:
		await _tick(minf(STEP, remaining))
		remaining -= STEP


func _recover(delta: float = STEP) -> bool:
	for index in range(400):
		if not game.motion.busy:
			return true
		await _tick(delta)
	return false


func _prepare(family: String, stage: int) -> void:
	await _fresh(family)
	for previous in range(stage):
		_check(game.request_attack() and game.motion.stage == previous, "%s fixture earns prerequisite stage %d" % [family, previous + 1])
		_check(await _recover(), "%s prerequisite stage completes" % family)


func _ground(offset: Vector3) -> Vector3:
	return Vector3(offset.x, 0, offset.z)


func _reported(family: String, stage: int) -> float:
	if family == "mace" and stage == 1:
		return game.mace_dash_travelled
	return float(game.get("attack_step_travelled")) if has_step_counter else -1.0


func _test_authored_travel() -> void:
	# Independent actor displacement catches omitted steps, old additive velocity,
	# frame-rate scaling, repeated cumulative offsets, and recovery/idle rewinds.
	for rate in [30, 120, 240]:
		for family in DISTANCES:
			await _fresh(family)
			for stage in range(3):
				var label := "%s stage %d at %d Hz" % [family, stage + 1, rate]
				var before: Vector3 = game.player.position
				_check(game.request_attack() and game.motion.stage == stage, "%s starts in earned combo order" % label)
				if has_step_counter:
					_check(is_zero_approx(game.attack_step_travelled), "%s begins with a fresh ordinary-step counter" % label)
				var definition: Dictionary = game.motion.definition(stage)
				await _tick(definition.windup * 0.8)
				_check(_ground(game.player.position - before).length() < 0.001, "%s has no forward travel during preparation" % label)
				var protected := false
				var previous_travel := 0.0
				var monotonic := true
				var finished_on_release := true
				var expected: float = DISTANCES[family][stage]
				var contact_progress: float = 1.0 if family == "mace" and stage == 1 else definition.get("impact_progress", 1.0)
				var travel_deadline: float = definition.windup + definition.active * contact_progress
				for frame_index in range(180):
					if not game.motion.busy:
						break
					await _tick(1.0 / float(rate))
					var travel: float = game.player.position.x - before.x
					monotonic = monotonic and travel >= previous_travel - 0.0001
					previous_travel = travel
					if game.motion.elapsed >= travel_deadline - 0.000001:
						finished_on_release = finished_on_release and absf(travel - expected) < 0.002
					protected = protected or game._iframes > 0 or game._dodge_left > 0
				var actual: Vector3 = _ground(game.player.position - before)
				_check(not game.motion.busy, "%s completes normally" % label)
				_check(absf(actual.x - expected) < 0.002 and absf(actual.z) < 0.001, "%s moves its actual body exactly %.2f units (got %s)" % [label, expected, actual])
				_check(finished_on_release, "%s finishes travel by its release/contact deadline and holds that position throughout recovery" % label)
				_check(monotonic, "%s never rewinds during recovery" % label)
				_check(not protected and is_equal_approx(game.stamina, 100.0), "%s grants no dodge state, invulnerability, or stamina cost" % label)
				if has_step_counter:
					_check(absf(_reported(family, stage) - actual.length()) < 0.002, "%s reports actual displacement" % label)
					if family == "mace" and stage == 1:
						_check(is_zero_approx(game.attack_step_travelled), "Mace second stage uses only its accepted .75 lunge")
				var stopped: Vector3 = game.player.position
				await _tick(0.20)
				_check(_ground(game.player.position - stopped).length() < 0.001, "%s has no repeated idle displacement" % label)
			_check(game.hits == 0, "unblocked %s fixture never damages or removes its far practice actor" % family)


func _point(direction: Vector3) -> void:
	var event := InputEventMouseMotion.new()
	event.position = game.camera.unproject_position(game.player.position + direction * 2.0)
	event.global_position = event.position
	root.push_input(event, true)


func _test_cursor_lock() -> void:
	# Use real camera-projected mouse events, including a diagonal final stroke.
	var directions := [Vector3.RIGHT, Vector3.FORWARD, Vector3(1, 0, 1).normalized()]
	for family in DISTANCES:
		await _fresh(family)
		game.test_aim = Vector3.ZERO
		for stage in range(3):
			var direction: Vector3 = directions[stage]
			_point(direction)
			var before: Vector3 = game.player.position
			_check(game.request_attack() and game.motion.stage == stage, "%s cursor starts earned stage %d" % [family, stage + 1])
			var locked: float = game.motion.aim_angle
			var locked_direction := Vector3(cos(locked), 0, sin(locked))
			_check(locked_direction.dot(direction) > 0.999, "%s stage %d reads the current mouse direction" % [family, stage + 1])
			_point(-direction)
			_check(await _recover(), "cursor-locked stroke completes")
			var travel := _ground(game.player.position - before)
			_check(absf(travel.dot(locked_direction) - DISTANCES[family][stage]) < 0.002 and travel.cross(locked_direction).length() < 0.001, "%s stage %d keeps its locked direction after cursor reversal (got %s)" % [family, stage + 1, travel])
			_check(absf(wrapf(game.motion.aim_angle - locked, -PI, PI)) < 0.001, "%s stage %d cannot steer midstroke" % [family, stage + 1])


func _test_long_frame_hit_order() -> void:
	# The real target sits beyond the stationary blade. A full elapsed tick must
	# apply the bounded actor step before checking the crossed damage interval.
	for family in DISTANCES:
		for stage in range(3):
			if family == "mace" and stage == 1:
				continue # Existing Mace lunge has its separate accepted contact curve.
			await _prepare(family, stage)
			var definition: Dictionary = game.motion.definition(stage)
			var expected: float = DISTANCES[family][stage]
			var target = _dummy()
			var before: Vector3 = game.player.position
			# Keep this ordinary-step fixture beyond stationary range while leaving
			# the v14 .12 approach inset inside the authored original budget.
			var gap := minf(expected * 0.55, expected - 0.13)
			target.position = before + Vector3.RIGHT * (definition.reach + 0.36 + gap)
			await physics_frame
			_check(game.request_attack() and game.motion.stage == stage, "%s long-frame stage %d starts naturally" % [family, stage + 1])
			await _tick(1.10)
			_check(not game.motion.busy and absf(game.player.position.x - before.x - expected) < 0.002, "%s stage %d consumes its full bounded step across active and recovery" % [family, stage + 1])
			_check(game.hits == 1 and is_equal_approx(game.total_damage, definition.damage), "%s stage %d reaches the beyond-stationary target before its one full damage contact (hits=%d damage=%.1f)" % [family, stage + 1, game.hits, game.total_damage])
			await _tick(0.20)
			_check(game.hits == 1 and absf(game.player.position.x - before.x - expected) < 0.002, "%s stage %d does not repeat travel or hit on the next idle tick" % [family, stage + 1])


func _test_target_stops() -> void:
	for family in DISTANCES:
		for stage in range(3):
			for kind in ["dummy", "elite"]:
				await _prepare(family, stage)
				var before: Vector3 = game.player.position
				var radius := 0.86 if kind == "elite" else 0.74
				var target = _dummy() if kind == "dummy" else game.spawn_enemy("elite", before + Vector3.RIGHT * (radius + 0.11))
				target.position = before + Vector3.RIGHT * (radius + 0.11)
				if kind == "elite":
					target.cooldown = 10.0
				await physics_frame
				_check(game.request_attack() and game.motion.stage == stage, "%s stage %d starts against a real %s" % [family, stage + 1, kind])
				await _tick(1.10)
				var actual := _ground(game.player.position - before).length()
				_check(actual > 0.09 and actual <= 0.111, "%s stage %d stops at the living %s's %.2f separation (travel=%.4f)" % [family, stage + 1, kind, radius, actual])
				if has_step_counter:
					_check(absf(_reported(family, stage) - actual) < 0.002, "target-blocked travel reports actual clipping")
				_check(game.hits == 1, "target clipping preserves one actual contact")
				_check(game._next_combo == (stage + 1) % 3, "target clipping preserves combo continuation")


func _test_solid_world_stops() -> void:
	for family in DISTANCES:
		for stage in range(3):
			await _prepare(family, stage)
			game.player.position = Vector3(6.98, 0.03, 5.4)
			await physics_frame
			var before: Vector3 = game.player.position
			_check(game.request_attack() and game.motion.stage == stage, "%s stage %d starts before the real arena pillar" % [family, stage + 1])
			await _tick(1.10)
			var actual := _ground(game.player.position - before).length()
			_check(actual > 0.02 and game.player.position.x <= 7.08 and actual < 0.12, "%s stage %d sweeps into the pillar without crossing it (x=%.4f travel=%.4f)" % [family, stage + 1, game.player.position.x, actual])
			if has_step_counter:
				_check(absf(_reported(family, stage) - actual) < 0.002, "world-blocked step reports clipped actual travel")
			_check(game._next_combo == (stage + 1) % 3, "world-blocked stroke preserves combo order")


func _test_pause() -> void:
	for family in DISTANCES:
		await _fresh(family)
		game.request_attack()
		var definition: Dictionary = game.motion.definition(0)
		await _tick(definition.windup + definition.active * 0.20)
		var before: Vector3 = game.player.position
		var elapsed: float = game.motion.elapsed
		var reported := _reported(family, 0)
		game.toggle_pause()
		await _tick(2.0)
		_check(game.mode == "paused" and game.player.position.is_equal_approx(before) and is_equal_approx(game.motion.elapsed, elapsed), "%s paused active step freezes its actor and motion clock" % family)
		if has_step_counter:
			_check(is_equal_approx(_reported(family, 0), reported), "%s paused step does not consume cumulative travel" % family)
		game.toggle_pause()
		_check(await _recover(), "%s step resumes and completes after pause" % family)
		_check(absf(game.player.position.x + 3.5 - DISTANCES[family][0]) < 0.002, "%s pause does not add or lose its authored travel" % family)


func _test_incoming_damage() -> void:
	for family in DISTANCES:
		await _fresh(family)
		game.request_attack()
		var definition: Dictionary = game.motion.definition(0)
		await _tick(definition.windup + definition.active * 0.20)
		_check(is_zero_approx(game._iframes) and is_zero_approx(game._dodge_left), "%s actual forward step has no dodge protection" % family)
		game.shoot(game.player.position + Vector3(0, 0.6, 0.1), Vector3.RIGHT, 11.0)
		await _tick()
		_check(is_equal_approx(game.health, 89.0) and game.motion.busy, "%s incoming projectile applies full damage without replacing its attack" % family)
		_check(await _recover(), "%s damaged attack still completes" % family)


func _key_space(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _test_walking_chain_and_space() -> void:
	for family in DISTANCES:
		await _fresh(family)
		for stage in range(2):
			_check(game.request_attack() and game.motion.stage == stage, "%s walking fixture earns stage %d" % [family, stage + 1])
			_check(await _recover(), "walking fixture finishes committed stroke")
			var before: Vector3 = game.player.position
			game.move_input = Vector2(0, 1)
			await _step(0.12)
			game.move_input = Vector2.ZERO
			_check(_ground(game.player.position - before).length() > 0.10, "%s really walks between strikes" % family)
		_check(game.request_attack() and game.motion.stage == 2, "%s walking preserves the earned third stage" % family)
		await _recover()
		_check(game.request_attack() and game.motion.stage == 0, "%s next combo starts normally" % family)
		await _recover()
		_check(game._next_combo == 1, "%s earns a follow-up before physical Space" % family)
		_key_space(true)
		await process_frame
		_key_space(false)
		_check(game._dodge_left > 0 and game.stamina < 80.0 and game._next_combo == 0, "%s physical Space remains the paid combo-reset dodge" % family)
		await _step(0.50)
		_check(game.request_attack() and game.motion.stage == 0, "%s attack after Space restarts at stage one" % family)
		await _recover()
