extends SceneTree
## Target-aware approach through the actual controller, physical bodies and inputs.
## Fixtures place actors; attacks, combo stages and damage are earned normally.

const STEP := 1.0 / 120.0
const BASE := {"sword": [0.18, 0.20, 0.30], "greatsword": [0.28, 0.30, 0.42], "mace": [0.16, 0.75, 0.24]}
var game
var checks := 0
var failures: Array[String] = []
var has_plan := false


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
	has_plan = game.get("melee_approach_plan") is Dictionary
	_check(game.player is CharacterBody3D, "approach uses the actual playable collision body")
	_check(has_plan, "controller exposes its accepted melee approach plan")
	await _test_all_stages_reach_fixed_targets()
	await _test_in_range_keeps_base()
	await _test_detection_boundary()
	await _test_fallbacks()
	await _test_selection_and_los_fallthrough()
	await _test_physical_mouse_lock()
	await _test_long_frames()
	await _test_blocked_budget()
	await _test_target_clips()
	await _test_pause_and_lifecycle()
	await _test_walking_and_space()
	game.queue_free()
	await process_frame
	print("MELEE APPROACH GAME TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)


func _dummy():
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.kind == "dummy" and not enemy.dead:
			return enemy
	return null


func _tick(delta: float = STEP) -> void:
	await physics_frame
	game.tick(delta)


func _step(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.000001:
		await _tick(minf(STEP, remaining))
		remaining -= STEP


func _recover() -> bool:
	for frame_index in range(400):
		if not game.motion.busy:
			return true
		await _tick()
	return false


func _fresh(family: String) -> void:
	_mouse(false)
	game.start_run(true)
	game.set_physics_process(false)
	_check(game.set_weapon_family(family), "fixture equips %s" % family)
	game.move_input = Vector2.ZERO
	game.test_aim = Vector3.RIGHT
	game.player.position = Vector3(-3.5, 0.03, 0)
	_dummy().position = Vector3(-7, 0.03, -7)
	await _tick()


func _prepare(family: String, stage: int) -> void:
	await _fresh(family)
	for previous in range(stage):
		_check(game.request_attack() and game.motion.stage == previous, "%s earns prerequisite stage %d" % [family, previous + 1])
		_check(await _recover(), "prerequisite recovers through actual controller")


func _ground(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0, vector.z)


func _direction(degrees: float) -> Vector3:
	return Vector3(cos(deg_to_rad(degrees)), 0, sin(deg_to_rad(degrees)))


func _place_target(stage: int, gap: float = 0.45, degrees: float = 0.0):
	var target = _dummy()
	target.position = game.player.position + _direction(degrees) * (game.motion.definition(stage).reach + 0.36 + gap)
	return target


func _place_distant_target(stage: int, ratio: float = 1.9, degrees: float = 20.0):
	var target = _dummy()
	target.position = game.player.position + _direction(degrees) * (game.motion.definition(stage).reach * ratio)
	return target


func _expected_travel(family: String, stage: int, target) -> float:
	return maxf(BASE[family][stage], _ground(target.position - game.player.position).length() - game.motion.definition(stage).reach - 0.36 + 0.12)


func _plan() -> Dictionary:
	return game.get("melee_approach_plan") if has_plan else {}


func _reported(family: String, stage: int) -> float:
	return game.mace_dash_travelled if family == "mace" and stage == 1 else game.attack_step_travelled


func _check_plan(assisted: bool, target, direction: Vector3, distance: float, label: String) -> void:
	if not has_plan:
		return
	var plan := _plan()
	_check(plan.has_all(["assisted", "target_id", "direction", "distance", "reason", "search_radius", "distance_limit"]), "%s has the explicit plan contract" % label)
	_check(plan.get("assisted", false) == assisted, "%s assistance=%s" % [label, assisted])
	if assisted:
		_check(plan.get("target_id", 0) == target.get_instance_id(), "%s selects the actual living target" % label)
	_check(plan.get("direction", Vector3.ZERO).dot(direction) > 0.9999, "%s stores the accepted locked direction" % label)
	_check(absf(float(plan.get("distance", -1)) - distance) < 0.0001, "%s stores its %.2f-unit total budget" % [label, distance])
	_check(not str(plan.get("reason", "")).is_empty(), "%s records the decision reason" % label)
	var reach: float = game.motion.definition(game.motion.stage).reach
	var base: float = BASE[game.weapon_family][game.motion.stage]
	_check(absf(float(plan.get("search_radius", -1)) - reach * 2.0) < 0.0001, "%s searches exactly twice the current strike reach" % label)
	_check(absf(float(plan.get("distance_limit", -1)) - maxf(base, reach + 0.12)) < 0.0001, "%s exposes the strike-specific travel bound" % label)


func _test_all_stages_reach_fixed_targets() -> void:
	# Fixed target centres at1.9R are inside2R but beyond every v14 assist.
	# Mace2 scales its one authored path; no second helper can contribute.
	for family in BASE:
		for stage in range(3):
			await _prepare(family, stage)
			var target = _place_distant_target(stage)
			await physics_frame
			var fixed_position: Vector3 = target.position
			var before: Vector3 = game.player.position
			var definition: Dictionary = game.motion.definition(stage)
			var expected := _expected_travel(family, stage, target)
			var label := "%s stage %d distant-target" % [family, stage + 1]
			_check(game.request_attack() and game.motion.stage == stage, "%s starts in real combo order" % label)
			_check_plan(true, target, _direction(20), expected, label)
			_check(game.hits == 0, "%s cannot damage at request time" % label)
			await _tick(definition.windup * 0.8)
			var authored_mace_second: bool = family == "mace" and stage == 1
			var windup_travel := _ground(game.player.position - before).length()
			if authored_mace_second:
				_check(windup_travel < 0.001, "%s keeps its authored preparation stationary" % label)
			else:
				_check(windup_travel > expected * 0.5 and windup_travel <= expected + 0.0001, "%s closes the gap during preparation" % label)
			_check(game.hits == 0, "%s movement during preparation cannot damage early" % label)
			await _tick(definition.windup * 0.2)
			_check(game.hits == 0, "%s original contact cannot occur at active entry" % label)
			if not authored_mace_second:
				_check(absf(_ground(game.player.position - before).length() - expected) < 0.002, "%s finishes the approach by original active entry" % label)
			var monotonic := true
			var completed_by_contact := true
			var previous_travel := _ground(game.player.position - before).length()
			var protected := false
			var deadline: float = definition.windup + definition.active if authored_mace_second else definition.windup
			for frame_index in range(400):
				if not game.motion.busy:
					break
				await _tick()
				var travel: float = _ground(game.player.position - before).dot(_direction(20))
				monotonic = monotonic and travel >= previous_travel - 0.0001
				previous_travel = travel
				if game.motion.elapsed >= deadline - 0.000001:
					completed_by_contact = completed_by_contact and absf(travel - expected) < 0.002
				protected = protected or game._iframes > 0 or game._dodge_left > 0
			var actual := _ground(game.player.position - before)
			_check(not game.motion.busy and absf(actual.length() - expected) < 0.002 and actual.cross(_direction(20)).length() < 0.001, "%s body travels one locked %.2f-unit approach (got %s)" % [label, expected, actual])
			_check(completed_by_contact and monotonic, "%s meets its accepted movement deadline and never rewinds" % label)
			_check(game.hits == 1 and is_equal_approx(game.total_damage, definition.damage), "%s lands exactly its unchanged %.0f damage once (hits=%d damage=%.1f)" % [label, definition.damage, game.hits, game.total_damage])
			_check(target.position.is_equal_approx(fixed_position), "%s proves reach against the fixed target centre" % label)
			_check(absf(_reported(family, stage) - actual.length()) < 0.002, "%s reports actual swept movement" % label)
			_check(not protected and is_equal_approx(game.stamina, 100.0), "%s adds no dodge, invulnerability or stamina charge" % label)
			if family == "mace" and stage == 1:
				_check(is_zero_approx(game.attack_step_travelled) and game.mace_dash_travelled > 0.75, "Mace2 scales its sole authored curve past .75 without a helper push")
			_check(game._next_combo == (stage + 1) % 3, "%s retains normal combo continuation" % label)
			var settled: Vector3 = game.player.position
			await _tick(0.1)
			_check(_ground(game.player.position - settled).length() < 0.001 and game.hits == 1, "%s recovery cannot repeat movement or damage" % label)


func _test_in_range_keeps_base() -> void:
	for family in BASE:
		for stage in range(3):
			await _prepare(family, stage)
			var target = _place_target(stage, -0.10)
			await physics_frame
			var before: Vector3 = game.player.position
			_check(game.request_attack(), "in-range %s stage %d starts" % [family, stage + 1])
			_check_plan(false, target, Vector3.RIGHT, BASE[family][stage], "in-range %s stage %d" % [family, stage + 1])
			_check(await _recover(), "in-range attack recovers")
			_check(absf(_ground(game.player.position - before).length() - BASE[family][stage]) < 0.002, "in-range %s stage %d preserves exactly its ordinary movement" % [family, stage + 1])
			_check(game.hits == 1 and is_equal_approx(game.total_damage, game.motion.definition(stage).damage), "in-range attack retains one normal damage contact")


func _test_detection_boundary() -> void:
	for family in BASE:
		for stage in range(3):
			for outside in [false, true]:
				await _prepare(family, stage)
				var target = _place_distant_target(stage, 2.0, 0.0)
				if outside:
					target.position.x += 0.02
				await physics_frame
				var before: Vector3 = game.player.position
				var expected: float = BASE[family][stage] if outside else _expected_travel(family, stage, target)
				var label := "%s stage %d at2R outside=%s" % [family, stage + 1, outside]
				_check(game.request_attack(), "%s starts normally" % label)
				_check_plan(not outside, target, Vector3.RIGHT, expected, label)
				await _tick(1.10)
				var actual := _ground(game.player.position - before).length()
				_check(not game.motion.busy and absf(actual - expected) < 0.002, "%s actual body obeys the inclusive centre-distance boundary" % label)
				_check(game.hits == (0 if outside else 1) and is_equal_approx(game.total_damage, 0.0 if outside else game.motion.definition(stage).damage), "%s preserves its real hit or miss" % label)
				if has_plan and outside:
					_check(_plan().get("target_id", -1) == 0, "target radius cannot expand the2R detection boundary")


func _test_fallbacks() -> void:
	for family in BASE:
		for fixture in ["empty", "far", "outside_cone", "behind", "dead"]:
			await _prepare(family, 0)
			var target = _dummy()
			if fixture != "empty":
				target = _place_target(0, 0.45, 31.0 if fixture == "outside_cone" else (180.0 if fixture == "behind" else 0.0))
			if fixture == "far":
				target.position = game.player.position + Vector3.RIGHT * (game.motion.definition(0).reach * 2.0 + 0.02)
			if fixture == "dead":
				target.dead = true
			await physics_frame
			var before: Vector3 = game.player.position
			_check(game.request_attack(), "%s %s fallback starts an ordinary attack" % [family, fixture])
			_check_plan(false, target, Vector3.RIGHT, BASE[family][0], "%s %s fallback" % [family, fixture])
			_check(await _recover(), "fallback attack recovers")
			_check(absf(_ground(game.player.position - before).length() - BASE[family][0]) < 0.002, "%s %s fallback preserves the old ordinary step" % [family, fixture])
			_check(game.hits == 0 and is_zero_approx(game.total_damage), "%s %s fallback cannot invent damage" % [family, fixture])


func _wall(position: Vector3, size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	wall.add_child(collision)
	game.add_child(wall)
	wall.position = position
	return wall


func _test_selection_and_los_fallthrough() -> void:
	for fixture in ["nearest_offangle", "alignment_tie", "inrange_nearest", "occluded_nearest"]:
		await _fresh("sword")
		var reach: float = game.motion.definition(0).reach
		var best = _place_distant_target(0, 1.6, 15.0)
		var other = game.spawn_enemy("dummy", game.player.position + Vector3.RIGHT * reach * 1.9)
		if fixture == "alignment_tie":
			best.position = game.player.position + _direction(15.0) * reach * 1.8
			other.position = game.player.position + _direction(5.0) * reach * 1.8
			best = other
		elif fixture == "inrange_nearest":
			best.position = game.player.position + _direction(15.0) * (reach + 0.36 - 0.10)
		var wall: StaticBody3D
		if fixture == "occluded_nearest":
			best.position = game.player.position + _direction(20.0) * reach * 1.9
			other.position = game.player.position + Vector3.RIGHT * reach * 1.6
			wall = _wall(game.player.position + Vector3(1.2, 0.65, 0), Vector3(0.10, 1.3, 0.16))
		await physics_frame
		var before: Vector3 = game.player.position
		var expected := _expected_travel("sword", 0, best) if fixture != "inrange_nearest" else 0.18
		_check(game.request_attack(), "%s target selection starts" % fixture)
		if has_plan:
			_check(_plan().get("assisted", false) == (fixture != "inrange_nearest") and _plan().get("target_id", 0) == best.get_instance_id(), "%s selects the nearest eligible actual target before alignment" % fixture)
		_check(await _recover(), "selected-target attack recovers")
		_check(game.hits >= 1 and game.hits <= 2 and game._hit_targets.has(best.get_instance_id()), "%s lands a real contact on the selected target" % fixture)
		_check(absf(_ground(game.player.position - before).length() - expected) < 0.002, "%s uses the selected nearest target's actual movement budget" % fixture)
		if is_instance_valid(wall):
			wall.queue_free()
			await physics_frame
	# A sole occluded actor must produce the ordinary fallback, not a wall lunge.
	await _fresh("sword")
	var target = _place_target(0)
	var blocker := _wall(game.player.position + Vector3(1.2, 0.65, 0), Vector3(0.10, 1.3, 0.4))
	await physics_frame
	var before: Vector3 = game.player.position
	_check(game.request_attack(), "sole occluded target permits the ordinary stroke")
	_check_plan(false, target, Vector3.RIGHT, 0.18, "sole occluded target")
	await _recover()
	_check(absf(_ground(game.player.position - before).length() - 0.18) < 0.002 and game.hits == 0, "world LOS excludes the sole target without extending the ordinary attack")
	blocker.queue_free()
	await physics_frame


func _point(direction: Vector3) -> Vector2:
	# Project a point on the feet's y=0 ground plane, not sprite/torso height.
	var foot: Vector3 = game.player.global_position + direction * 2.0
	foot.y = 0.0
	var position: Vector2 = game.camera.unproject_position(foot)
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	root.push_input(event, true)
	return position


func _mouse(pressed: bool, position: Vector2 = Vector2(-1, -1)) -> void:
	if game == null:
		return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = game._mouse_position if position.x < 0 else position
	event.global_position = event.position
	root.push_input(event, true)


func _test_physical_mouse_lock() -> void:
	for family in BASE:
		await _fresh(family)
		var target = _place_distant_target(0)
		await physics_frame
		var expected := _expected_travel(family, 0, target)
		game.test_aim = Vector3.ZERO
		var mouse := _point(Vector3.RIGHT)
		var before: Vector3 = game.player.position
		_mouse(true, mouse)
		await process_frame
		_mouse(false, mouse)
		_check(game.motion.busy and game.motion.stage == 0, "%s actual LMB commits the attack immediately" % family)
		_check_plan(true, target, _direction(20), expected, "%s physical ground-projected aim" % family)
		var locked: float = game.motion.aim_angle
		_point(Vector3.LEFT)
		_check(await _recover(), "physical click completes after release and cursor reversal")
		var travel := _ground(game.player.position - before)
		_check(absf(travel.dot(_direction(20)) - expected) < 0.002 and travel.cross(_direction(20)).length() < 0.001, "%s cursor changes cannot steer the committed target approach" % family)
		_check(absf(wrapf(game.motion.aim_angle - locked, -PI, PI)) < 0.0001 and game.hits == 1, "%s locked physical approach lands exactly once" % family)


func _test_long_frames() -> void:
	for family in BASE:
		for stage in range(3):
			for ratio in [1.9, 2.0]:
				await _prepare(family, stage)
				var target = _place_distant_target(stage, ratio)
				await physics_frame
				var before: Vector3 = game.player.position
				var expected := _expected_travel(family, stage, target)
				var limit: float = game.motion.definition(stage).reach + 0.12
				_check(game.request_attack(), "long-frame assisted stroke starts")
				_check_plan(true, target, _direction(20), expected, "%s stage %d long frame at %.1fR" % [family, stage + 1, ratio])
				await _tick(1.10)
				var actual := _ground(game.player.position - before).length()
				_check(not game.motion.busy and absf(actual - expected) < 0.002 and actual <= limit - 0.36 + 0.0001, "%s stage %d large frame consumes exactly one bounded %.2f approach" % [family, stage + 1, expected])
				_check(game.hits == 1 and is_equal_approx(game.total_damage, game.motion.definition(stage).damage), "%s stage %d applies approach before crossed original damage contact" % [family, stage + 1])
				var stopped: Vector3 = game.player.position
				await _tick(1.10)
				_check(_ground(game.player.position - stopped).length() < 0.001 and game.hits == 1, "long frame cannot repeat the exhausted movement or hit")
				if family == "mace" and stage == 1:
					_check(is_zero_approx(game.attack_step_travelled) and game.mace_dash_travelled > 0.75, "large-frame Mace2 scales only its single authored movement path")


func _test_blocked_budget() -> void:
	for family in BASE:
		for stage in range(3):
			await _prepare(family, stage)
			_place_distant_target(stage, 1.9, 0.0)
			await physics_frame
			var before: Vector3 = game.player.position
			_check(game.request_attack(), "blocked-budget attack selects its unobstructed target")
			# Introduce real world collision after selection; the already committed
			# stroke must sweep against it, consume its budget, and never teleport.
			var wall := _wall(before + Vector3(0.65, 0.65, 0), Vector3(0.10, 1.3, 1.0))
			await physics_frame
			await _tick(1.10)
			var actual := _ground(game.player.position - before).length()
			_check(actual > 0.1 and actual < 0.305, "%s stage %d actual collision clips the assisted body sweep (%.4f)" % [family, stage + 1, actual])
			_check(absf(_reported(family, stage) - actual) < 0.002, "clipped approach reports actual travel")
			if family == "mace" and stage == 1:
				_check(is_zero_approx(game.attack_step_travelled) and game.mace_dash_travelled < 0.305, "blocked Mace2 has one clipped scaled-lunge budget")
			var stopped: Vector3 = game.player.position
			wall.queue_free()
			await physics_frame
			await _tick(1.10)
			_check(_ground(game.player.position - stopped).length() < 0.001, "removing blocker cannot replay consumed approach travel")


func _test_target_clips() -> void:
	for family in BASE:
		for stage in range(3):
			await _prepare(family, stage)
			var target = _place_distant_target(stage, 1.9, 0.0)
			await physics_frame
			var before: Vector3 = game.player.position
			_check(game.request_attack(), "target-clipping fixture accepts the far approach")
			# A target that moves inward after selection must clip the existing
			# swept body path; an approach must never tunnel through living actors.
			target.position = before + Vector3.RIGHT * 0.85
			await physics_frame
			await _tick(1.10)
			var actual := _ground(game.player.position - before).length()
			_check(actual > 0.09 and actual <= 0.111, "%s stage %d living target clips newly assisted travel at .74 separation (%.4f)" % [family, stage + 1, actual])
			_check(absf(_reported(family, stage) - actual) < 0.002, "target-clipped approach reports its actual movement")
			_check(game.hits == 1 and is_equal_approx(game.total_damage, game.motion.definition(stage).damage), "target clipping preserves exactly one normal damage contact")
			var stopped: Vector3 = game.player.position
			target.position += Vector3.RIGHT * 4.0
			await physics_frame
			await _tick(1.10)
			_check(_ground(game.player.position - stopped).length() < 0.001 and game.hits == 1, "departing target cannot replay exhausted approach movement or damage")


func _test_pause_and_lifecycle() -> void:
	for family in BASE:
		await _fresh(family)
		var target = _place_distant_target(0, 1.9, 0.0)
		await physics_frame
		var expected := _expected_travel(family, 0, target)
		_check(game.request_attack(), "pause fixture starts an assisted attack")
		await _tick(game.motion.definition(0).windup * 0.40)
		var before: Vector3 = game.player.position
		var elapsed: float = game.motion.elapsed
		var travelled: float = game.attack_step_travelled
		_check(travelled > 0 and travelled < expected and game.hits == 0, "%s pause fixture interrupts a real harmless approach in progress" % family)
		var accepted: Dictionary = _plan().duplicate(true)
		game.stamina = 0.0 # Unaffordable dodge preserves the attack/reload under test.
		_check(not game.request_attack() and not game.request_dodge(Vector3.LEFT), "committed approach rejects replacement attack and unaffordable dodge")
		if has_plan:
			_check(_plan() == accepted, "failed actions preserve the current accepted plan")
		game.toggle_pause()
		await _tick(2.0)
		_check(game.mode == "paused" and game.player.position.is_equal_approx(before) and is_equal_approx(game.motion.elapsed, elapsed) and is_equal_approx(game.attack_step_travelled, travelled), "%s pause freezes actual assisted travel and its clock" % family)
		game.toggle_pause()
		_check(await _recover(), "assisted attack resumes normally")
		_check(absf(game.player.position.x + 3.5 - expected) < 0.002 and game.hits == 1, "%s pause does not lose or duplicate the approach and contact (travel=%.4f hits=%d)" % [family, game.player.position.x + 3.5, game.hits])
		_check(game.set_weapon_family("rifle"), "idle weapon replacement succeeds")
		if has_plan:
			_check(_plan().is_empty(), "successful family replacement clears the old melee plan")
		game.start_run(true)
		game.set_physics_process(false)
		if has_plan:
			_check(_plan().is_empty(), "new run clears the old melee plan")


func _space(pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = pressed
	Input.parse_input_event(key)
	Input.flush_buffered_events()


func _test_walking_and_space() -> void:
	for family in BASE:
		await _fresh(family)
		for stage in range(3):
			_place_distant_target(stage)
			await physics_frame
			var prior_hits: int = game.hits
			_check(game.request_attack() and game.motion.stage == stage, "%s assisted walking combo earns stage %d" % [family, stage + 1])
			_check(await _recover(), "assisted walking combo completes its strike")
			_check(game.hits == prior_hits + 1, "%s walking stage %d lands exactly one actual contact (before=%d after=%d)" % [family, stage + 1, prior_hits, game.hits])
			if stage < 2:
				var before: Vector3 = game.player.position
				game.move_input = Vector2(0, 1)
				await _step(0.12)
				game.move_input = Vector2.ZERO
				_check(_ground(game.player.position - before).length() > 0.1, "walking between assisted strikes moves the real body")
		_check(game.hits == 3, "%s walking approach chain lands all three real contacts" % family)
		_place_distant_target(0)
		await physics_frame
		game.request_attack()
		await _recover()
		_check(game._next_combo == 1, "assisted strike earns a follow-up before Space")
		_space(true)
		await process_frame
		_space(false)
		_check(game._dodge_left > 0 and game._next_combo == 0 and game.stamina < 80, "%s physical Space retains its paid combo-reset dodge" % family)
		if has_plan:
			_check(_plan().is_empty(), "successful Space dodge clears the old assistance plan")
		await _step(0.50)
		_place_distant_target(0)
		await physics_frame
		_check(game.request_attack() and game.motion.stage == 0, "attack after physical Space restarts at first stage")
		_check(await _recover(), "post-dodge approach completes")
