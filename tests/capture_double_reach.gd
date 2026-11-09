extends SceneTree
## Native viewport input / real physics evidence; no supplied attacks or damage.
## Load by absolute external --script path alongside the exported adjacent PCK.
## --output=C:/absolute/folder [--frames] captures 90 contiguous 30-fps Sword frames.
## The only mid-case fixture mutation is a recorded target reposition between Mace attacks.

const STEP := 1.0 / 120.0
const BASE_DISTANCES := {"sword": [0.18, 0.20, 0.30], "greatsword": [0.28, 0.30, 0.42], "mace": [0.16, 0.75, 0.24]}
const DAMAGE := {"sword": [18.0, 19.0, 34.0], "greatsword": [45.0, 47.5, 85.0], "mace": [34.0, 12.0, 46.0]}
const TARGET_RADIUS := 0.36
const DISTANCE_FACTOR := 1.9
var game
var output := ""
var record_frames := false
var safety_ready := false
var failures: Array[String] = []
var saved: Array[String] = []
var screenshots: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var strokes: Array[Dictionary] = []
var contacts: Array[Dictionary] = []
var raw_frames: Array[String] = []
var raw_states: Array[Dictionary] = []
var physics := {"ticks": 0, "outside_physics_ticks": 0, "physics_ticks_per_second": 120, "model_delta": STEP, "min_physics_delta": INF, "max_physics_delta": 0.0}
var case_label := ""
var direction := Vector3.RIGHT
var primary
var origin := Vector3.ZERO
var initial_target_position := Vector3.ZERO
var initial_target_distance := 0.0
var initial_weapon_reach := 0.0
var expected_approach := 0.0
var expected_case_travel := 0.0
var mouse_target_override := Vector3.INF
var fixture_events: Array[Dictionary] = []
var active_stroke: Dictionary = {}
var stroke_origin := Vector3.ZERO
var stroke_direction := Vector3.RIGHT
var case_stroke_index := 0
var case_contact_index := 0
var presses := 0
var releases := 0
var markers: Node3D
var evidence_label: Label
var cursor_turn_state: Dictionary = {}
var minimum_gap := INF


func _initialize() -> void:
	root.unfocusable = true
	Engine.physics_ticks_per_second = 120
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument == "--frames": record_frames = true
	call_deferred("_run")


func _process(_delta: float) -> bool:
	if safety_ready and not _window_is_offscreen():
		printerr("DOUBLE REACH CAPTURE FAILED: native window lost safe offscreen/no-focus state")
		quit(1)
	return false


func _run() -> void:
	if output.is_empty() or not output.is_absolute_path() or DisplayServer.get_name() == "headless":
		printerr("DOUBLE REACH CAPTURE FAILED: native renderer and absolute --output required")
		quit(1)
		return
	root.unfocusable = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_position(Vector2i(20000, 20000))
	safety_ready = true
	await process_frame
	if not _window_is_offscreen():
		printerr("DOUBLE REACH CAPTURE FAILED: safe native window setup failed")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output.path_join("combo"))
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	_expect(_window_is_offscreen(), "game initialization changed native safety state")
	_add_evidence_label()
	for family: String in ["sword", "greatsword", "mace"]:
		await _assisted_combo(family, family == "sword" and record_frames)
	await _nearest_target_case()
	await _single_boundary("sword-exact-2r", 4.2, true, true)
	await _single_boundary("sword-outside-2r", 4.22, false, false)
	await _single_boundary("sword-in-range", 1.55, false, true)
	await _pillar_case()
	await _locked_direction_case()
	await _mace_second_case()
	_expect(active_stroke.is_empty(), "a stroke did not finish naturally")
	_expect(physics.outside_physics_ticks == 0, "model ticks ran outside native physics")
	if record_frames: _expect(raw_frames.size() == 90, "expected 90 contiguous sword frames")
	var manifest := {
		"renderer": DisplayServer.get_name(), "engine": Engine.get_version_info().string,
		"native_window": {"unfocusable": root.unfocusable, "native_no_focus_flag": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS), "requested_position": [20000, 20000], "actual_position": [DisplayServer.window_get_position().x, DisplayServer.window_get_position().y], "mode": root.mode, "checked_every_frame_and_tick": true},
		"input": "Viewport.push_input mouse motion and LMB press/hold/release; no request_attack/request_dodge calls, no supplied poses, movement, health, knockback, or damage",
		"fixtures": "Fixed practice dummy per case; player fixture set only before original solid arena pillar. Competing-target case adds one fixed practice dummy and retains aligned viewport mouse intent. Mace-second case completes a real first LMB attack, then repositions its fixed dummy ONCE between naturally completed attacks; fixture_events records this. No poses, combo stages, player motion, damage, health, or knockback are supplied. Cyan origin/gold endpoint/coral target marks are visual only.",
		"base_distances": BASE_DISTANCES, "expected_damage": DAMAGE,
		"target_radius": TARGET_RADIUS, "default_target_distance_factor": DISTANCE_FACTOR, "search_radius_rule": "2 * current strike reach", "distance_limit_rule": "max(base_distance, current strike reach + .12)", "fixture_events": fixture_events,
		"assisted_timing_rule": "Assisted AttackStep approaches during original windup and completes by active start with no early damage; Mace second retains only its scaled authored active lunge curve. Normal base curve and original attack phases remain unchanged.",
		"physics_context": physics, "cases": cases, "strokes": strokes, "contacts": contacts,
		"cursor_turn": cursor_turn_state, "screenshots": saved, "screenshot_states": screenshots,
		"raw_fps": 30, "raw_frame_count": raw_frames.size(), "raw_frames": raw_frames, "raw_states": raw_states,
		"failures": failures,
	}
	var file := FileAccess.open(output.path_join("capture-manifest.json"), FileAccess.WRITE)
	if file == null: failures.append("could not save manifest")
	else:
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()
	game.queue_free()
	await process_frame
	for failure in failures: printerr("DOUBLE REACH CAPTURE FAILED: ", failure)
	print("DOUBLE REACH CAPTURE: %d cases, %d strokes, %d stills, %d native frames; failures=%s" % [cases.size(), strokes.size(), saved.size(), raw_frames.size(), JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)


func _fixture(family: String, label: String, dummy_distance: float = -1.0, player_position: Vector3 = Vector3.ZERO) -> void:
	_expect(active_stroke.is_empty(), label + " began during a previous stroke")
	case_label = label
	direction = Vector3.RIGHT
	game.start_run(true)
	game.set_physics_process(false)
	_expect(game.set_weapon_family(family), label + " could not equip weapon")
	game.move_input = Vector2.ZERO
	game.test_aim = Vector3.ZERO
	if player_position != Vector3.ZERO: game.player.position = player_position
	primary = game.enemies[0]
	initial_weapon_reach = game.motion.definition(0).reach
	initial_target_distance = initial_weapon_reach * DISTANCE_FACTOR if dummy_distance < 0 else dummy_distance
	expected_approach = maxf(float(BASE_DISTANCES[family][0]), initial_target_distance - initial_weapon_reach - TARGET_RADIUS + .12)
	expected_case_travel = expected_approach if dummy_distance < 0 else float(BASE_DISTANCES[family][0])
	mouse_target_override = Vector3.INF
	primary.position = game.player.position + direction * initial_target_distance
	initial_target_position = primary.position
	presses = 0
	releases = 0
	minimum_gap = INF
	case_stroke_index = strokes.size()
	case_contact_index = contacts.size()
	for index in range(72): await _tick()
	origin = game.player.position
	_add_markers(expected_approach if dummy_distance < 0 else BASE_DISTANCES[family][0])
	_point_ground(primary.position)
	_expect(game._mouse_position.is_equal_approx(game.camera.unproject_position(Vector3(primary.position.x, 0, primary.position.z))), label + " did not receive actual target ground mouse point")


func _assisted_combo(family: String, with_frames: bool) -> void:
	var label := family + "-assisted-combo"
	await _fixture(family, label)
	expected_case_travel = expected_approach + float(BASE_DISTANCES[family][1]) + float(BASE_DISTANCES[family][2])
	_expect(expected_approach > .85, label + " is not beyond v14 assist cap")
	_expect(initial_target_distance <= 2 * initial_weapon_reach, label + " is outside dynamic detection radius")
	await _capture(label + "-00-before")
	_mouse(true)
	_expect(not active_stroke.is_empty() and active_stroke.plan.assisted, label + " first native press did not accept assistance")
	_expect(active_stroke.plan.target_id == primary.get_instance_id(), label + " did not select fixture target")
	_expect_plan_contract(active_stroke.plan, initial_weapon_reach, float(BASE_DISTANCES[family][0]), label)
	_expect(absf(float(active_stroke.plan.distance) - expected_approach) < .003, label + " planned first approach differs from dynamic expected distance")
	var released := false
	var captured_entry := false
	var last_photographed_hits := 0
	var timeline_start: float = game.run_time
	var frame_index := 0
	for index in range(600):
		await _tick()
		if game.motion.busy and game.motion.stage == 2 and not released:
			_mouse(false)
			released = true
		if game.motion.busy and game.motion.stage == 0 and not captured_entry and game.attack_step_travelled > expected_approach * .25:
			captured_entry = true
			var closing_pose: Dictionary = game.current_visual_sample()
			_expect(closing_pose.phase == "windup" and game.attack_step_travelled < expected_approach - .003, label + " did not capture partial approach during original windup")
			_expect(game.hits == 0 and game.total_damage == 0, label + " dealt early damage during approach windup")
			await _capture(label + "-01-closing")
		if game.hits > last_photographed_hits:
			last_photographed_hits = game.hits
			await _capture("%s-%02d-hit" % [label, game.hits + 1])
		if with_frames and index % 4 == 3 and frame_index < 90:
			var path := output.path_join("combo/combo_%03d.png" % frame_index)
			await _save_frame(path)
			raw_frames.append(path)
			var state := _state()
			state.frame_index = frame_index
			state.timeline_seconds = game.run_time - timeline_start
			raw_states.append(state)
			frame_index += 1
		if released and not game.motion.busy and (not with_frames or frame_index == 90): break
	_expect(released and not game.motion.busy, label + " did not naturally finish hold/release")
	_expect(captured_entry and last_photographed_hits == 3, label + " did not capture closing and all three actual hits")
	var result := _case_result()
	_expect(result.stage_sequence == [0, 1, 2], label + " did not retain ordered three-stage combo")
	_expect(presses == 1 and releases == 1, label + " did not use one LMB hold/release")
	_expect(game.hits == 3 and is_equal_approx(game.total_damage, _damage_sum(family)), label + " did not land real three-hit damage")
	var case_strokes := strokes.slice(case_stroke_index)
	if case_strokes.size() == 3:
		_expect(absf(case_strokes[0].actual_positive_projection - expected_approach) < .003, label + " actual first step differs from dynamic expected distance")
		for stroke: Dictionary in case_strokes:
			_expect(stroke.maximum_perpendicular_displacement < .003, label + " moved sideways without input")
			_expect(stroke.minimum_stamina == 100 and stroke.maximum_dodge_left == 0, label + " used dodge or stamina")
			_expect(stroke.target_maximum_displacement < .0001, label + " fixture target moved during the stroke")
			if stroke.stage > 0:
				_expect(not stroke.plan.assisted, label + " in-range follow-up added assistance")
				_expect(absf(stroke.actual_positive_projection - float(BASE_DISTANCES[family][stroke.stage])) < .003, label + " in-range follow-up changed original travel")
			if family == "mace" and stroke.stage == 1:
				_expect(stroke.attack_step_travelled == 0 and absf(stroke.mace_dash_travelled - .75) < .003, label + " mace second stage duplicated its accepted lunge")
	cases.append(result)


func _single_boundary(label: String, dummy_distance: float, should_assist: bool, should_hit: bool) -> void:
	await _fixture("sword", label, dummy_distance)
	expected_case_travel = expected_approach if should_assist else .18
	_add_markers(expected_case_travel)
	await _capture(label + "-00-before")
	_mouse(true)
	_mouse(false)
	_expect(not active_stroke.is_empty() and active_stroke.plan.assisted == should_assist, label + " assistance differs from detection boundary")
	_expect_plan_contract(active_stroke.plan, initial_weapon_reach, .18, label)
	for index in range(300):
		await _tick()
		if not game.motion.busy: break
	var result := _case_result()
	var expected := expected_approach if should_assist else .18
	_expect(result.stage_sequence == [0] and absf(result.actual_forward_displacement - expected) < .003, label + " actual travel differs from expected")
	_expect(game.hits == (1 if should_hit else 0) and is_equal_approx(game.total_damage, 18.0 if should_hit else 0.0), label + " real contact outcome differs")
	await _capture(label + "-01-after")
	cases.append(result)


func _nearest_target_case() -> void:
	await _fixture("sword", "sword-nearest-off-angle", 3.6)
	var mouse_intent := Vector3.RIGHT
	direction = Vector3(cos(deg_to_rad(15)), 0, sin(deg_to_rad(15)))
	primary.position = origin + direction * 3.6
	initial_target_position = primary.position
	expected_approach = 3.6 - initial_weapon_reach - TARGET_RADIUS + .12
	expected_case_travel = expected_approach
	game.spawn_enemy("dummy", origin + mouse_intent * 4.0)
	var competitor = game.enemies[game.enemies.size() - 1]
	mouse_target_override = origin + mouse_intent * 4.0
	_point_ground(mouse_target_override)
	_add_markers(expected_approach)
	await _capture(case_label + "-00-before")
	var near_health: float = primary.health
	var far_health: float = competitor.health
	_mouse(true)
	_mouse(false)
	var accepted := _plan()
	var received_mouse: Vector2 = game._mouse_position
	var expected_mouse: Vector2 = game.camera.unproject_position(Vector3(mouse_target_override.x, 0, mouse_target_override.z))
	var ray_origin: Vector3 = game.camera.project_ray_origin(received_mouse)
	var ray_direction: Vector3 = game.camera.project_ray_normal(received_mouse)
	var actual_mouse_ground: Vector3 = ray_origin + ray_direction * (-ray_origin.y / ray_direction.y)
	var actual_mouse_direction: Vector3 = actual_mouse_ground - game.player.position
	actual_mouse_direction.y = 0
	actual_mouse_direction = actual_mouse_direction.normalized()
	_expect(received_mouse.is_equal_approx(expected_mouse) and actual_mouse_direction.dot(mouse_intent) > .99999, case_label + " actual viewport mouse did not retain farther aligned target intent")
	_expect(accepted.assisted and accepted.target_id == primary.get_instance_id(), case_label + " did not choose nearest off-angle target over aligned farther target")
	_expect(game.aim.distance_to(direction) < .0001 and absf(game.motion.aim_angle - deg_to_rad(15)) < .0001, case_label + " did not lock aim toward selected nearest target")
	_expect_plan_contract(accepted, initial_weapon_reach, .18, case_label)
	for index in range(300):
		await _tick()
		if not game.motion.busy: break
	var result := _case_result()
	result.input_mouse_direction = _vector(actual_mouse_direction)
	result.injected_mouse_position = _vector2(expected_mouse)
	result.received_mouse_position = _vector2(received_mouse)
	result.projected_mouse_ground = _vector(actual_mouse_ground)
	result.selected_target_angle_degrees = 15.0
	result.selected_target_initial_distance = 3.6
	result.competitor_id = competitor.get_instance_id()
	result.competitor_initial_distance = 4.0
	result.competitor_alignment_degrees = 0.0
	result.selected_target_damage = near_health - primary.health
	result.competitor_damage = far_health - competitor.health
	_expect(result.stage_sequence == [0] and absf(result.actual_forward_displacement - expected_approach) < .003, case_label + " actual approach differs from nearest target plan")
	_expect(result.selected_target_damage == 18 and game.hits >= 1, case_label + " selected nearest target did not receive real contact")
	await _capture(case_label + "-01-selected-hit")
	cases.append(result)


func _mace_second_case() -> void:
	await _fixture("mace", "mace-second-assisted", 6.0)
	await _capture(case_label + "-00-before-prime")
	_mouse(true)
	_mouse(false)
	for index in range(300):
		await _tick()
		if not game.motion.busy: break
	_expect(strokes.size() == case_stroke_index + 1 and game._next_combo == 1 and game.hits == 0, case_label + " natural first LMB attack did not earn second combo stage")
	var old_target: Vector3 = primary.position
	var second_origin: Vector3 = game.player.position
	initial_weapon_reach = game.motion.definition(1).reach
	initial_target_distance = 4.18
	primary.position = second_origin + direction * initial_target_distance
	initial_target_position = primary.position
	expected_approach = initial_target_distance - initial_weapon_reach - TARGET_RADIUS + .12
	expected_case_travel = .16 + expected_approach
	fixture_events.append({"case": case_label, "event": "single fixed dummy reposition between naturally completed LMB attacks", "physics_tick": physics.ticks, "prior_stage": game.motion.stage, "next_combo": game._next_combo, "from": _vector(old_target), "to": _vector(primary.position), "second_attack_origin": _vector(second_origin), "second_attack_target_distance": initial_target_distance})
	_add_markers(.16 + expected_approach)
	_point_ground(primary.position)
	await _capture(case_label + "-01-before-second")
	_mouse(true)
	_mouse(false)
	_expect(game.motion.stage == 1 and active_stroke.plan.assisted and active_stroke.plan.target_id == primary.get_instance_id(), case_label + " second real LMB did not assist against new far fixture")
	_expect_plan_contract(active_stroke.plan, initial_weapon_reach, .75, case_label)
	_expect(expected_approach > .75 and absf(expected_approach - 1.74) < .003, case_label + " fixture does not require extended Mace second travel")
	for index in range(300):
		await _tick()
		if not game.motion.busy: break
	var result := _case_result()
	var second: Dictionary = strokes[case_stroke_index + 1] if strokes.size() > case_stroke_index + 1 else {}
	result.priming_stroke_travel = strokes[case_stroke_index].actual_positive_projection
	result.second_attack_origin = _vector(second_origin)
	result.second_actual_travel = second.get("actual_positive_projection", -1)
	result.second_expected_travel = expected_approach
	result.second_attack_step_travelled = second.get("attack_step_travelled", -1)
	result.second_mace_dash_travelled = second.get("mace_dash_travelled", -1)
	_expect(result.stage_sequence == [0, 1] and presses == 2 and releases == 2, case_label + " did not use two naturally ordered LMB attacks")
	_expect(game.hits == 1 and is_equal_approx(game.total_damage, 12), case_label + " extended second stroke did not land exact native damage")
	_expect(absf(result.second_actual_travel - expected_approach) < .003 and result.second_attack_step_travelled == 0 and absf(result.second_mace_dash_travelled - expected_approach) < .003, case_label + " did not use only scaled original Mace lunge path")
	await _capture(case_label + "-02-second-hit")
	cases.append(result)


func _pillar_case() -> void:
	await _fixture("greatsword", "greatsword-blocked-target", -1, Vector3(6.95, 0.03, 5.4))
	expected_case_travel = (8.0 - .625 - .3) - origin.x
	var eye := Vector3(game.player.position.x, .68, game.player.position.z)
	var end := Vector3(primary.position.x, .68, primary.position.z)
	var query := PhysicsRayQueryParameters3D.create(eye, end, 1)
	var obstruction: Dictionary = game.player.get_world_3d().direct_space_state.intersect_ray(query)
	_expect(not obstruction.is_empty(), case_label + " fixture has no actual solid line-of-sight obstruction")
	await _capture(case_label + "-00-before")
	_mouse(true)
	_mouse(false)
	_expect(not active_stroke.is_empty() and not active_stroke.plan.assisted, case_label + " selected a target through the solid pillar")
	for index in range(240):
		await _tick()
		if not game.motion.busy: break
	var result := _case_result()
	result.line_of_sight_blocked = not obstruction.is_empty()
	result.original_pillar_position = [8.0, 0.0, 5.4]
	result.player_collision_radius = .3
	result.pillar_base_half_width = .625
	result.solid_boundary_player_center_x = 8.0 - .625 - .3
	_expect(result.stage_sequence == [0] and result.actual_forward_displacement > .01 and result.actual_forward_displacement < .28 - .03, case_label + " did not clip the ordinary greatsword step")
	_expect(game.player.position.x <= 8.0 - .625 - .3 + .003, case_label + " crossed existing solid pillar base")
	_expect(game.hits == 0 and game.stamina == 100 and game._dodge_left == 0, case_label + " unexpectedly hit or dodged")
	await _capture(case_label + "-01-stopped")
	cases.append(result)


func _locked_direction_case() -> void:
	await _fixture("sword", "sword-cursor-lock")
	await _capture(case_label + "-00-before")
	_mouse(true)
	_mouse(false)
	_expect(not active_stroke.is_empty() and active_stroke.plan.assisted, case_label + " did not accept original target")
	var moved_cursor := false
	var input_received := false
	var cursor_intent_changed := false
	var maximum_game_aim_error := 0.0
	var maximum_motion_aim_error := 0.0
	var accepted_plan := _plan()
	_expect_plan_contract(accepted_plan, initial_weapon_reach, .18, case_label)
	for index in range(240):
		await _tick()
		var pose: Dictionary = game.current_visual_sample()
		if game.motion.busy and pose.phase == "windup" and pose.progress >= .5 and not moved_cursor:
			var mouse_point := _point_ground(game.player.position + Vector3.BACK * 4)
			moved_cursor = true
			input_received = game._mouse_position.is_equal_approx(mouse_point)
			var ray_origin: Vector3 = game.camera.project_ray_origin(game._mouse_position)
			var ray_direction: Vector3 = game.camera.project_ray_normal(game._mouse_position)
			var ground_point: Vector3 = ray_origin + ray_direction * (-ray_origin.y / ray_direction.y)
			var cursor_direction: Vector3 = ground_point - game.player.global_position
			cursor_direction.y = 0
			cursor_direction = cursor_direction.normalized()
			cursor_intent_changed = cursor_direction.dot(Vector3.BACK) > .99 and absf(cursor_direction.dot(direction)) < .01
			cursor_turn_state = {"case": case_label, "event_physics_tick": physics.ticks, "accepted_plan": accepted_plan, "initial_aim_vector": _vector(direction), "new_mouse_direction": _vector(Vector3.BACK), "locked_attack_angle": game.motion.aim_angle, "injected_mouse_position": _vector2(mouse_point), "received_mouse_position": _vector2(game._mouse_position), "actual_input_received": input_received, "projected_cursor_ground_point": _vector(ground_point), "projected_cursor_direction": _vector(cursor_direction), "cursor_intent_changed": cursor_intent_changed}
		if moved_cursor and game.motion.busy:
			maximum_game_aim_error = maxf(maximum_game_aim_error, game.aim.distance_to(direction))
			maximum_motion_aim_error = maxf(maximum_motion_aim_error, absf(wrapf(game.motion.aim_angle, -PI, PI)))
			_expect(_plan() == accepted_plan, case_label + " changed its accepted plan midstroke")
		if not game.motion.busy: break
	var result := _case_result()
	cursor_turn_state.maximum_game_aim_error_while_busy = maximum_game_aim_error
	cursor_turn_state.maximum_motion_aim_error_while_busy = maximum_motion_aim_error
	cursor_turn_state.actual_game_aim_locked_midstroke = maximum_game_aim_error < .0001
	cursor_turn_state.actual_forward_displacement = result.actual_forward_displacement
	cursor_turn_state.actual_perpendicular_displacement = absf((game.player.position - origin).dot(Vector3.BACK))
	_expect(moved_cursor and input_received and cursor_intent_changed, case_label + " did not receive changed viewport mouse intent")
	_expect(maximum_game_aim_error < .0001 and maximum_motion_aim_error < .0001, case_label + " changed locked game or motion aim while busy")
	_expect(result.stage_sequence == [0] and absf(result.actual_forward_displacement - expected_approach) < .003 and cursor_turn_state.actual_perpendicular_displacement < .003, case_label + " cursor steered accepted target approach")
	_expect(game.hits == 1 and is_equal_approx(game.total_damage, 18), case_label + " lost original target contact after new mouse intent")
	await _capture(case_label + "-01-locked-hit")
	cases.append(result)


func _mouse(pressed: bool) -> void:
	var point := _point_ground(mouse_target_override if mouse_target_override.is_finite() else primary.position)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	if pressed: presses += 1
	else: releases += 1
	if game.motion.busy and active_stroke.is_empty(): _begin_stroke(game.player.position)


func _point_ground(target: Vector3) -> Vector2:
	target.y = 0
	var point: Vector2 = game.camera.unproject_position(target)
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	return point


func _begin_stroke(at: Vector3) -> void:
	stroke_origin = at
	stroke_direction = Vector3(cos(game.motion.aim_angle), 0, sin(game.motion.aim_angle))
	_expect_plan_contract(_plan(), game.motion.definition(game.motion.stage).reach, BASE_DISTANCES[game.weapon_family][game.motion.stage], case_label)
	active_stroke = {"case": case_label, "family": game.weapon_family, "stage": game.motion.stage, "start_tick": physics.ticks, "start_position": _vector(at), "locked_direction": _vector(stroke_direction), "plan": _plan(), "base_distance": BASE_DISTANCES[game.weapon_family][game.motion.stage], "weapon_reach": game.motion.definition(game.motion.stage).reach, "target_distance_at_start": at.distance_to(primary.position), "actual_positive_projection": 0.0, "actual_horizontal_path_length": 0.0, "maximum_perpendicular_displacement": 0.0, "helper_requested": 0.0, "helper_travelled": 0.0, "attack_step_travelled": 0.0, "mace_dash_travelled": 0.0, "minimum_stamina": game.stamina, "maximum_dodge_left": game._dodge_left, "target_maximum_displacement": 0.0, "windup_maximum_travel": 0.0, "windup_early_hit_count": 0, "active_start_checked": false, "first_active_travel": 0.0, "trajectory": []}


func _tick() -> void:
	await physics_frame
	if not _window_is_offscreen():
		printerr("DOUBLE REACH CAPTURE FAILED: unsafe native window at physics tick")
		quit(1)
		return
	var in_physics := Engine.is_in_physics_frame()
	var physical_delta: float = game.player.get_physics_process_delta_time()
	physics.ticks += 1
	physics.min_physics_delta = minf(physics.min_physics_delta, physical_delta)
	physics.max_physics_delta = maxf(physics.max_physics_delta, physical_delta)
	if not in_physics: physics.outside_physics_ticks += 1
	_expect(in_physics and absf(physical_delta - STEP) < .000001 and Engine.physics_ticks_per_second == 120, "tick was not real native 120-Hz physics")
	if not game.motion.busy: _point_ground(mouse_target_override if mouse_target_override.is_finite() else primary.position)
	var before: Vector3 = game.player.position
	var old_hits: int = game.hits
	var old_damage: float = game.total_damage
	game.tick(STEP)
	if game.motion.busy and active_stroke.is_empty(): _begin_stroke(before)
	if is_instance_valid(primary):
		var offset: Vector3 = primary.position - game.player.position
		offset.y = 0
		minimum_gap = minf(minimum_gap, offset.length())
	if not active_stroke.is_empty():
		var displacement: Vector3 = game.player.position - before
		displacement.y = 0
		var from_start: Vector3 = game.player.position - stroke_origin
		from_start.y = 0
		active_stroke.actual_positive_projection += maxf(0, displacement.dot(stroke_direction))
		active_stroke.actual_horizontal_path_length += displacement.length()
		active_stroke.maximum_perpendicular_displacement = maxf(active_stroke.maximum_perpendicular_displacement, (from_start - stroke_direction * from_start.dot(stroke_direction)).length())
		var legacy_mace: bool = game.weapon_family == "mace" and game.motion.stage == 1
		var helper = game._short_lunge if legacy_mace else game._attack_step
		active_stroke.helper_requested = maxf(active_stroke.helper_requested, helper.requested)
		active_stroke.helper_travelled = maxf(active_stroke.helper_travelled, helper.travelled)
		active_stroke.attack_step_travelled = maxf(active_stroke.attack_step_travelled, game.attack_step_travelled)
		active_stroke.mace_dash_travelled = maxf(active_stroke.mace_dash_travelled, game.mace_dash_travelled if legacy_mace else 0.0)
		active_stroke.minimum_stamina = minf(active_stroke.minimum_stamina, game.stamina)
		active_stroke.maximum_dodge_left = maxf(active_stroke.maximum_dodge_left, game._dodge_left)
		active_stroke.target_maximum_displacement = maxf(active_stroke.target_maximum_displacement, primary.position.distance_to(initial_target_position))
		var current_pose: Dictionary = game.current_visual_sample()
		if current_pose.phase == "windup":
			active_stroke.windup_maximum_travel = maxf(active_stroke.windup_maximum_travel, active_stroke.actual_positive_projection)
			active_stroke.windup_early_hit_count += game.hits - old_hits
			_expect(game.hits == old_hits and is_equal_approx(game.total_damage, old_damage), case_label + " dealt damage before original active phase")
		if current_pose.phase == "active" and not active_stroke.active_start_checked:
			active_stroke.active_start_checked = true
			active_stroke.first_active_travel = active_stroke.actual_positive_projection
			if active_stroke.plan.assisted and not legacy_mace:
				_expect(absf(active_stroke.first_active_travel - float(active_stroke.plan.distance)) < .003, case_label + " assisted approach was not complete by original active start")
		active_stroke.trajectory.append(_state())
		_expect(game.stamina == 100 and game._dodge_left == 0, case_label + " melee used dodge or stamina")
		if not game.motion.busy:
			_expect(active_stroke.active_start_checked, case_label + " native stroke did not sample original active phase")
			active_stroke.end_tick = physics.ticks
			active_stroke.end_position = _vector(game.player.position)
			active_stroke.actual_net_projection = from_start.dot(stroke_direction)
			strokes.append(active_stroke)
			active_stroke = {}
	if game.hits > old_hits:
		var contact := _state()
		contact.damage_this_tick = game.total_damage - old_damage
		contact.hits_this_tick = game.hits - old_hits
		contact.in_physics_frame = in_physics
		contact.physics_delta = physical_delta
		contacts.append(contact)
	_refresh_evidence_label()


func _case_result() -> Dictionary:
	var sequence: Array[int] = []
	var plans: Array[Dictionary] = []
	for stroke: Dictionary in strokes.slice(case_stroke_index):
		sequence.append(stroke.stage)
		plans.append(stroke.plan)
	var damage_steps: Array[float] = []
	for contact: Dictionary in contacts.slice(case_contact_index): damage_steps.append(contact.damage_this_tick)
	var displacement: Vector3 = game.player.position - origin
	displacement.y = 0
	return {"case": case_label, "family": game.weapon_family, "target_id": primary.get_instance_id(), "initial_target_position": _vector(initial_target_position), "initial_target_distance": initial_target_distance, "initial_weapon_reach": initial_weapon_reach, "initial_contact_range": initial_weapon_reach + TARGET_RADIUS, "previous_first_step": BASE_DISTANCES[game.weapon_family][0], "required_approach_distance": expected_approach, "expected_total_travel": expected_case_travel, "dynamic_search_radius": 2 * initial_weapon_reach, "dynamic_distance_limit": maxf(float(BASE_DISTANCES[game.weapon_family][0]), initial_weapon_reach + .12), "stage_sequence": sequence, "accepted_plans": plans, "mouse_presses": presses, "mouse_releases": releases, "space_presses": 0, "stamina": game.stamina, "dodge_left": game._dodge_left, "hits": game.hits, "damage": game.total_damage, "damage_steps": damage_steps, "actual_displacement": _vector(displacement), "actual_forward_displacement": displacement.dot(direction), "minimum_target_gap": minimum_gap, "target_final_displacement": primary.position.distance_to(initial_target_position), "final_phase": game.current_visual_sample().phase}


func _state() -> Dictionary:
	var pose: Dictionary = game.current_visual_sample()
	var displacement: Vector3 = game.player.position - origin
	displacement.y = 0
	return {"case": case_label, "family": game.weapon_family, "physics_tick": physics.ticks, "simulation_time": game.run_time, "stage": game.motion.stage, "phase": pose.phase, "progress": pose.progress, "busy": game.motion.busy, "next_combo": game._next_combo, "stamina": game.stamina, "dodge_left": game._dodge_left, "aim": _vector(game.aim), "locked_aim_angle": game.motion.aim_angle, "plan": _plan(), "attack_step_travelled": game.attack_step_travelled, "attack_step_requested": game._attack_step.requested, "mace_dash_travelled": game.mace_dash_travelled, "hits": game.hits, "damage": game.total_damage, "player_position": _vector(game.player.position), "case_forward_displacement": displacement.dot(direction), "target_id": primary.get_instance_id() if is_instance_valid(primary) else 0, "target_position": _vector(primary.position) if is_instance_valid(primary) else [], "target_health": primary.health if is_instance_valid(primary) else -1.0, "screen_player_ground": _vector2(game.camera.unproject_position(game.player.position)), "screen_case_origin": _vector2(game.camera.unproject_position(origin)), "screen_target_ground": _vector2(game.camera.unproject_position(initial_target_position))}


func _plan() -> Dictionary:
	var source: Dictionary = game.melee_approach_plan
	var result := source.duplicate(true)
	for key: String in ["direction", "target_position"]:
		if result.has(key) and result[key] is Vector3: result[key] = _vector(result[key])
	return result


func _add_markers(first_distance: float) -> void:
	if is_instance_valid(markers):
		game.remove_child(markers)
		markers.queue_free()
	markers = Node3D.new()
	markers.name = "EvidenceOnlyGroundMarkers"
	game.add_child(markers)
	for entry: Array in [[origin, Color("#5ee4e6")], [origin + direction * first_distance, Color("#ffd06a")], [initial_target_position, Color("#ff8f7a")]]:
		for size: Vector3 in [Vector3(.025, .008, .64), Vector3(.18, .008, .025)]:
			var marker := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = size
			marker.mesh = mesh
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = entry[1]
			marker.material_override = material
			marker.position = entry[0]
			marker.position.y = .038
			markers.add_child(marker)


func _add_evidence_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	game.add_child(layer)
	evidence_label = Label.new()
	evidence_label.position = Vector2(26, 122)
	evidence_label.add_theme_font_size_override("font_size", 18)
	evidence_label.add_theme_color_override("font_color", Color("#eafff7"))
	evidence_label.add_theme_color_override("font_shadow_color", Color("#071018"))
	evidence_label.add_theme_constant_override("shadow_offset_x", 2)
	evidence_label.add_theme_constant_override("shadow_offset_y", 2)
	evidence_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(evidence_label)


func _refresh_evidence_label() -> void:
	if not is_instance_valid(evidence_label): return
	var travelled: float = game.mace_dash_travelled if game.weapon_family == "mace" and game.motion.stage == 1 else game.attack_step_travelled
	var plan := _plan()
	var displacement: Vector3 = game.player.position - origin
	evidence_label.text = "NATIVE LMB / %s\nSTEP %d: %.3f u   PLAN: %s   TOTAL: %.3f u   HITS: %d   DAMAGE: %.1f\nCYAN = ORIGIN / GOLD = FIRST END / CORAL = FIXED TARGET / FIXTURE MARKERS ONLY" % [case_label.to_upper(), game.motion.stage + 1, travelled, "ASSISTED" if plan.get("assisted", false) else str(plan.get("reason", "none")).to_upper(), displacement.dot(direction), game.hits, game.total_damage]


func _capture(name: String) -> void:
	_refresh_evidence_label()
	var path := output.path_join(name + ".png")
	await _save_frame(path)
	saved.append(path)
	var state := _state()
	state.file = path.get_file()
	screenshots.append(state)
	print("DOUBLE REACH CAPTURE: ", path)


func _save_frame(path: String) -> void:
	if not _window_is_offscreen():
		_expect(false, "unsafe native window before frame readback")
		return
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(_window_is_offscreen(), "unsafe native window during frame readback")
	var picture: Image = root.get_texture().get_image()
	_expect(picture != null and not picture.is_empty() and picture.get_size() == Vector2i(1280, 800) and picture.save_png(path) == OK, "could not save full native viewport: " + path)


func _window_is_offscreen() -> bool:
	return root.unfocusable and root.mode == Window.MODE_WINDOWED and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS) and DisplayServer.window_get_position() == Vector2i(20000, 20000)


func _expect_plan_contract(plan: Dictionary, reach: float, base: float, label: String) -> void:
	_expect(plan.has("search_radius") and absf(float(plan.get("search_radius", -1)) - 2 * reach) < .003, label + " plan search radius is not 2R")
	_expect(plan.has("distance_limit") and absf(float(plan.get("distance_limit", -1)) - maxf(base, reach + .12)) < .003, label + " plan distance limit is not dynamic R+.12")
	_expect(float(plan.get("distance", INF)) <= float(plan.get("distance_limit", -1)) + .003, label + " planned movement exceeds dynamic limit")


func _damage_sum(family: String) -> float:
	var result := 0.0
	for amount: float in DAMAGE[family]: result += amount
	return result


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)


func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _vector2(value: Vector2) -> Array[float]:
	return [value.x, value.y]
