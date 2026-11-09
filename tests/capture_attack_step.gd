extends SceneTree
## Native input/physics evidence only. No attack calls, supplied poses, or damage.
## Launch hidden/minimized with --position 20000,20000 -- --output=C:/absolute/folder.
## Optional --frames records exactly 90 contiguous 30-fps sword-combo frames.

const STEP := 1.0 / 120.0
const DISTANCES := {"sword": [0.18, 0.20, 0.30], "greatsword": [0.28, 0.30, 0.42], "mace": [0.16, 0.75, 0.24]}
const DAMAGE := {"sword": [18.0, 19.0, 34.0], "greatsword": [45.0, 47.5, 85.0], "mace": [34.0, 12.0, 46.0]}
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
var active_stroke: Dictionary = {}
var stroke_origin := Vector3.ZERO
var stroke_direction := Vector3.RIGHT
var case_stroke_index := 0
var case_contact_index := 0
var presses := 0
var releases := 0
var space_presses := 0
var markers: Node3D
var evidence_label: Label
var moved_cursor := false
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
		printerr("ATTACK STEP CAPTURE FAILED: native window lost safe offscreen/no-focus state")
		quit(1)
	return false


func _run() -> void:
	if output.is_empty() or not output.is_absolute_path() or DisplayServer.get_name() == "headless":
		printerr("ATTACK STEP CAPTURE FAILED: native renderer and absolute --output required")
		quit(1)
		return
	root.unfocusable = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_position(Vector2i(20000, 20000))
	safety_ready = true
	await process_frame
	if not _window_is_offscreen():
		printerr("ATTACK STEP CAPTURE FAILED: safe native window setup failed")
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
		await _combo(family, false, family == "sword" and record_frames)
	for family: String in ["sword", "greatsword", "mace"]:
		await _combo(family, true, false)
	await _locked_direction_case()
	await _pillar_case()
	_expect(active_stroke.is_empty(), "a stroke did not finish naturally")
	_expect(physics.outside_physics_ticks == 0, "model ticks ran outside native physics")
	if record_frames: _expect(raw_frames.size() == 90, "expected 90 contiguous sword frames")
	var manifest := {
		"renderer": DisplayServer.get_name(), "engine": Engine.get_version_info().string,
		"native_window": {"unfocusable": root.unfocusable, "native_no_focus_flag": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS), "requested_position": [20000, 20000], "actual_position": [DisplayServer.window_get_position().x, DisplayServer.window_get_position().y], "mode": root.mode, "checked_every_frame_and_tick": true},
		"input": "Viewport.push_input mouse motion and LMB press/hold/release; no request_attack/request_dodge calls, no supplied pose, player movement, health, knockback, or damage",
		"fixtures": "Fixed practice dummy only: 5u for open combos and .86u for clipping; original solid arena pillar at (8,0,5.4). Player position is set only before the pillar fixture. Cyan ground cross marks case origin; gold cross marks authored final endpoint; all markers are visual only.",
		"expected_distances": DISTANCES, "expected_damage": DAMAGE, "target_clearance": 0.74,
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
	for failure in failures: printerr("ATTACK STEP CAPTURE FAILED: ", failure)
	print("ATTACK STEP CAPTURE: %d cases, %d strokes, %d stills, %d native frames; failures=%s" % [cases.size(), strokes.size(), saved.size(), raw_frames.size(), JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)


func _fixture(family: String, label: String, dummy_distance: float, player_position: Vector3 = Vector3.ZERO) -> void:
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
	primary.position = game.player.position + direction * dummy_distance
	presses = 0
	releases = 0
	space_presses = 0
	moved_cursor = false
	minimum_gap = INF
	case_stroke_index = strokes.size()
	case_contact_index = contacts.size()
	for index in range(72): await _tick()
	origin = game.player.position
	_add_markers(float(DISTANCES[family][0]) + float(DISTANCES[family][1]) + float(DISTANCES[family][2]))
	_point_mouse(direction)


func _combo(family: String, close_target: bool, with_frames: bool) -> void:
	var label := family + ("-target-stop" if close_target else "-open-combo")
	await _fixture(family, label, 0.86 if close_target else 5.0)
	await _capture(label + "-00-origin")
	_mouse(true)
	var released := false
	var photographed: Dictionary = {}
	var timeline_start: float = game.run_time
	var frame_index := 0
	for index in range(600):
		await _tick()
		if game.motion.busy and game.motion.stage == 2 and not released:
			_mouse(false)
			released = true
		var pose: Dictionary = game.current_visual_sample()
		if game.motion.busy and pose.phase == "recovery" and not photographed.has(game.motion.stage):
			photographed[game.motion.stage] = true
			await _capture("%s-%02d-step-complete" % [label, game.motion.stage + 1])
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
	_expect(photographed.size() == 3, label + " did not capture all three completed steps")
	var result := _case_result()
	_expect(result.stage_sequence == [0, 1, 2], label + " did not retain ordered three-stage combo")
	_expect(presses == 1 and releases == 1, label + " did not use one LMB hold/release")
	_expect(space_presses == 0 and game._dodge_left == 0 and game.stamina == 100, label + " used Space/dodge/stamina")
	if close_target:
		_expect(game.hits == 3 and is_equal_approx(game.total_damage, _damage_sum(family)), label + " did not land real three-hit damage")
		_expect(absf(minimum_gap - 0.74) < 0.003, label + " did not stop at .74 target clearance")
		_expect(absf(result.actual_forward_displacement - .12) < .003, label + " target clip actual travel differs from .12")
	else:
		_expect(game.hits == 0 and game.total_damage == 0, label + " distant fixture was unexpectedly hit")
		for stroke: Dictionary in strokes.slice(case_stroke_index):
			_expect(absf(stroke.actual_positive_projection - stroke.authored_distance) < .003, label + " actual per-stroke travel differs from authored cap")
			_expect(absf(stroke.helper_travelled - stroke.actual_positive_projection) < .003, label + " helper and actual player travel differ")
			_expect(stroke.maximum_perpendicular_displacement < .003, label + " moved sideways without input")
			if family == "mace" and stroke.stage == 1:
				_expect(stroke.attack_step_travelled == 0 and absf(stroke.mace_dash_travelled - .75) < .003, label + " mace second stage duplicated its accepted lunge")
	await _capture(label + "-04-final")
	cases.append(result)


func _locked_direction_case() -> void:
	await _fixture("sword", "sword-cursor-turn", 5.0)
	await _capture("sword-cursor-turn-00-origin")
	_mouse(true)
	_mouse(false)
	var input_received := false
	var cursor_intent_changed := false
	var maximum_game_aim_error := 0.0
	var maximum_motion_aim_error := 0.0
	for index in range(180):
		await _tick()
		var pose: Dictionary = game.current_visual_sample()
		if game.motion.busy and pose.phase == "windup" and pose.progress >= .5 and not moved_cursor:
			var mouse_point := _point_mouse(Vector3.BACK)
			moved_cursor = true
			input_received = game._mouse_position.is_equal_approx(mouse_point)
			var ray_origin: Vector3 = game.camera.project_ray_origin(game._mouse_position)
			var ray_direction: Vector3 = game.camera.project_ray_normal(game._mouse_position)
			var ground_point: Vector3 = ray_origin + ray_direction * (-ray_origin.y / ray_direction.y)
			var cursor_direction: Vector3 = ground_point - game.player.global_position
			cursor_direction.y = 0
			cursor_direction = cursor_direction.normalized()
			cursor_intent_changed = cursor_direction.dot(Vector3.BACK) > .99 and absf(cursor_direction.dot(direction)) < .01
			cursor_turn_state = {"case": case_label, "event_physics_tick": physics.ticks, "initial_aim_vector": _vector(direction), "new_mouse_direction": _vector(Vector3.BACK), "locked_attack_angle": game.motion.aim_angle, "injected_mouse_position": _vector2(mouse_point), "received_mouse_position": _vector2(game._mouse_position), "actual_input_received": input_received, "projected_cursor_ground_point": _vector(ground_point), "projected_cursor_direction": _vector(cursor_direction), "cursor_intent_changed": cursor_intent_changed}
		if moved_cursor and game.motion.busy:
			maximum_game_aim_error = maxf(maximum_game_aim_error, game.aim.distance_to(direction))
			maximum_motion_aim_error = maxf(maximum_motion_aim_error, absf(wrapf(game.motion.aim_angle, -PI, PI)))
		if moved_cursor and game.motion.busy and pose.phase == "recovery":
			await _capture("sword-cursor-turn-01-locked-step")
			break
	for index in range(180):
		await _tick()
		if not game.motion.busy: break
	var result := _case_result()
	cursor_turn_state.maximum_game_aim_error_while_busy = maximum_game_aim_error
	cursor_turn_state.maximum_motion_aim_error_while_busy = maximum_motion_aim_error
	cursor_turn_state.actual_game_aim_locked_midstroke = maximum_game_aim_error < .0001
	cursor_turn_state.actual_forward_displacement = result.actual_forward_displacement
	cursor_turn_state.actual_perpendicular_displacement = absf((game.player.position - origin).dot(Vector3.BACK))
	_expect(moved_cursor and input_received and cursor_intent_changed, "cursor-turn case did not receive changed viewport mouse intent")
	_expect(maximum_game_aim_error < .0001 and maximum_motion_aim_error < .0001, "cursor-turn case changed locked game or motion aim while busy")
	_expect(result.stage_sequence == [0] and absf(result.actual_forward_displacement - .18) < .003 and cursor_turn_state.actual_perpendicular_displacement < .003, "cursor movement steered an in-flight attack step")
	cases.append(result)


func _pillar_case() -> void:
	# This is the arena's existing base, not a newly supplied collision object.
	await _fixture("greatsword", "greatsword-solid-pillar", 5.0, Vector3(6.95, 0.03, 5.4))
	await _capture("greatsword-solid-pillar-00-origin")
	_mouse(true)
	_mouse(false)
	for index in range(240):
		await _tick()
		if not game.motion.busy: break
	var result := _case_result()
	result.original_pillar_position = [8.0, 0.0, 5.4]
	result.player_collision_radius = .3
	result.pillar_base_half_width = .625
	result.solid_boundary_player_center_x = 8.0 - .625 - .3
	_expect(result.stage_sequence == [0] and result.actual_forward_displacement > .01 and result.actual_forward_displacement < .28 - .03, "solid pillar did not clip the actual greatsword step")
	_expect(game.player.position.x <= 8.0 - .625 - .3 + .003, "greatsword crossed existing solid pillar base")
	_expect(game.hits == 0 and game.stamina == 100 and game._dodge_left == 0, "pillar fixture unexpectedly hit or dodged")
	await _capture("greatsword-solid-pillar-01-stopped")
	cases.append(result)


func _mouse(pressed: bool) -> void:
	var point := _point_mouse(direction)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	if pressed: presses += 1
	else: releases += 1
	if game.motion.busy and active_stroke.is_empty(): _begin_stroke(game.player.position)


func _point_mouse(aim_direction: Vector3) -> Vector2:
	var target: Vector3 = game.player.position + aim_direction * 4.0
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
	active_stroke = {"case": case_label, "family": game.weapon_family, "stage": game.motion.stage, "start_tick": physics.ticks, "start_position": _vector(at), "locked_direction": _vector(stroke_direction), "authored_distance": DISTANCES[game.weapon_family][game.motion.stage], "actual_positive_projection": 0.0, "actual_horizontal_path_length": 0.0, "maximum_perpendicular_displacement": 0.0, "helper_requested": 0.0, "helper_travelled": 0.0, "attack_step_travelled": 0.0, "mace_dash_travelled": 0.0, "minimum_stamina": game.stamina, "maximum_dodge_left": game._dodge_left, "trajectory": []}


func _tick() -> void:
	await physics_frame
	if not _window_is_offscreen():
		printerr("ATTACK STEP CAPTURE FAILED: unsafe native window at physics tick")
		quit(1)
		return
	var in_physics := Engine.is_in_physics_frame()
	var physical_delta: float = game.player.get_physics_process_delta_time()
	physics.ticks += 1
	physics.min_physics_delta = minf(physics.min_physics_delta, physical_delta)
	physics.max_physics_delta = maxf(physics.max_physics_delta, physical_delta)
	if not in_physics: physics.outside_physics_ticks += 1
	_expect(in_physics and absf(physical_delta - STEP) < .000001 and Engine.physics_ticks_per_second == 120, "tick was not real native 120-Hz physics")
	if not game.motion.busy: _point_mouse(direction)
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
		active_stroke.trajectory.append(_state())
		_expect(game.stamina == 100 and game._dodge_left == 0, case_label + " melee used dodge or stamina")
		if not game.motion.busy:
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
	for stroke: Dictionary in strokes.slice(case_stroke_index): sequence.append(stroke.stage)
	var damage_steps: Array[float] = []
	for contact: Dictionary in contacts.slice(case_contact_index): damage_steps.append(contact.damage_this_tick)
	var displacement: Vector3 = game.player.position - origin
	displacement.y = 0
	return {"case": case_label, "family": game.weapon_family, "stage_sequence": sequence, "mouse_presses": presses, "mouse_releases": releases, "space_presses": space_presses, "stamina": game.stamina, "dodge_left": game._dodge_left, "hits": game.hits, "damage": game.total_damage, "damage_steps": damage_steps, "actual_displacement": _vector(displacement), "actual_forward_displacement": displacement.dot(direction), "minimum_target_gap": minimum_gap, "final_phase": game.current_visual_sample().phase}


func _state() -> Dictionary:
	var pose: Dictionary = game.current_visual_sample()
	var displacement: Vector3 = game.player.position - origin
	displacement.y = 0
	return {"case": case_label, "family": game.weapon_family, "physics_tick": physics.ticks, "simulation_time": game.run_time, "stage": game.motion.stage, "phase": pose.phase, "progress": pose.progress, "busy": game.motion.busy, "next_combo": game._next_combo, "stamina": game.stamina, "dodge_left": game._dodge_left, "aim": _vector(game.aim), "locked_aim_angle": game.motion.aim_angle, "attack_step_travelled": game.attack_step_travelled, "attack_step_requested": game._attack_step.requested, "mace_dash_travelled": game.mace_dash_travelled, "hits": game.hits, "damage": game.total_damage, "player_position": _vector(game.player.position), "case_forward_displacement": displacement.dot(direction), "target_position": _vector(primary.position) if is_instance_valid(primary) else [], "target_health": primary.health if is_instance_valid(primary) else -1.0, "screen_player_ground": _vector2(game.camera.unproject_position(game.player.position)), "screen_case_origin": _vector2(game.camera.unproject_position(origin))}


func _add_markers(total_distance: float) -> void:
	if is_instance_valid(markers):
		game.remove_child(markers)
		markers.queue_free()
	markers = Node3D.new()
	markers.name = "EvidenceOnlyGroundMarkers"
	game.add_child(markers)
	for entry: Array in [[origin, Color("#5ee4e6")], [origin + direction * total_distance, Color("#ffd06a")]]:
		for size: Vector3 in [Vector3(.025, .008, .72), Vector3(.18, .008, .025)]:
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
	var cap: float = DISTANCES[game.weapon_family][game.motion.stage] if game.motion.stage >= 0 else 0.0
	var displacement: Vector3 = game.player.position - origin
	evidence_label.text = "NATIVE INPUT / %s\nSTEP %d: %.3f / %.3f u   TOTAL: %.3f u   STAMINA: %.0f   DODGE: %.3f\nCYAN = ORIGIN   GOLD = AUTHORED COMBO END   FIXTURE MARKERS ONLY" % [case_label.to_upper(), game.motion.stage + 1, travelled, cap, displacement.dot(direction), game.stamina, game._dodge_left]


func _capture(name: String) -> void:
	_refresh_evidence_label()
	var path := output.path_join(name + ".png")
	await _save_frame(path)
	saved.append(path)
	var state := _state()
	state.file = path.get_file()
	screenshots.append(state)
	print("ATTACK STEP CAPTURE: ", path)


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
