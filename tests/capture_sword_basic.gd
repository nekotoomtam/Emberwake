extends SceneTree
## Actual viewport input and real physics-scheduled ticks; never supply poses or damage.
## Launch hidden with --minimized --position 20000,20000 -- --output=<absolute folder>.

const STEP := 1.0 / 120.0
const RAW_COUNT := 120
const EXPECTED_REACHES := [2.1, 2.2, 2.55]
const WALK_LEG_TICKS := 108
var game
var output := ""
var safety_ready := false
var failures: Array[String] = []
var saved: Array[String] = []
var screenshot_states: Array[Dictionary] = []
var raw_frames: Array[String] = []
var raw_states: Array[Dictionary] = []
var contacts: Array[Dictionary] = []
var geometry_samples: Array[Dictionary] = []
var swing_starts: Array[Dictionary] = []
var directions: Array[Dictionary] = []
var marked: Dictionary = {}
var case_label := "right"
var direction := Vector3.RIGHT
var primary
var outside_arc
var case_origin := Vector3.ZERO
var case_swing_index := 0
var case_contact_index := 0
var observed_busy := false
var presses := 0
var releases := 0
var space_presses := 0
var space_releases := 0
var aim_at_primary := false
var primary_min_health := 1000.0
var outside_min_health := 1000.0
var capture_main_phases := false
var physics_context := {"ticks": 0, "outside_physics_ticks": 0, "physics_ticks_per_second": 120, "model_delta": STEP, "min_physics_delta": INF, "max_physics_delta": 0.0, "min_physical_weapon_length": INF, "max_physical_weapon_length": 0.0, "max_rendered_tip_error": 0.0, "max_active_ground_reach_error": 0.0}


func _initialize() -> void:
	root.unfocusable = true
	Engine.physics_ticks_per_second = 120
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	call_deferred("_run")


func _process(_delta: float) -> bool:
	if safety_ready and not _window_is_offscreen():
		printerr("SWORD BASIC CAPTURE FAILED: native window lost offscreen/no-focus state")
		quit(1)
	return false


func _run() -> void:
	if output.is_empty() or not output.is_absolute_path() or DisplayServer.get_name() == "headless":
		printerr("SWORD BASIC CAPTURE FAILED: native renderer and absolute --output folder required")
		quit(1)
		return
	root.unfocusable = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_position(Vector2i(20000, 20000))
	safety_ready = true
	await process_frame
	if not _window_is_offscreen():
		printerr("SWORD BASIC CAPTURE FAILED: safe native window setup failed")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output.path_join("combo"))
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	_expect(_window_is_offscreen(), "initialization reset safe native window state")
	_expect(game.weapon_family == "sword", "initial menu did not default to ordinary sword")
	await _capture("01-menu")
	await _start_practice("right", Vector3.RIGHT)
	await _capture("02-ready")
	capture_main_phases = true
	var timeline_start: float = game.run_time
	var released := false
	for frame_index in range(RAW_COUNT):
		if frame_index == 8: _mouse(true)
		for substep in range(4):
			await _tick()
			if game.motion.busy and game.motion.stage == 2 and not released:
				_mouse(false)
				released = true
		var frame_path := output.path_join("combo/combo_%03d.png" % frame_index)
		await _save_frame(frame_path)
		raw_frames.append(frame_path)
		var state := _state()
		state.frame_index = frame_index
		state.timeline_seconds = game.run_time - timeline_start
		raw_states.append(state)
	capture_main_phases = false
	_expect(released, "main hold did not reach third windup")
	await _capture("12-combo-complete")
	var main_result := _combo_result("right")
	directions.append(main_result)
	for stage in range(3):
		for phase in ["windup", "active", "recovery"]:
			_expect(marked.has("%d-%s" % [stage, phase]), "missing main phase: %d %s" % [stage + 1, phase])
	await _direction_combo("left", Vector3.LEFT, 13)
	await _direction_combo("away", Vector3.FORWARD, 15)
	await _direction_combo("toward", Vector3.BACK, 17)
	var walking_continuation: Dictionary = await _walking_continuation()
	var dodge_reset: Dictionary = await _dodge_reset()
	_expect(raw_frames.size() == RAW_COUNT, "expected 120 contiguous native 30-fps frames")
	_expect(saved.size() == 24, "expected 24 native stills")
	_expect(physics_context.outside_physics_ticks == 0, "some ticks ran outside real physics")
	var manifest := {
		"renderer": DisplayServer.get_name(), "engine": Engine.get_version_info().string,
		"native_window": {"unfocusable": root.unfocusable, "native_no_focus_flag": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS), "requested_position": [20000, 20000], "actual_position": [DisplayServer.window_get_position().x, DisplayServer.window_get_position().y], "checked_every_frame_and_tick": true},
		"input": "Viewport.push_input normal mouse aim and LMB press/hold/release; hold released as third windup begins; walking continuation uses normal W then S key press/release via Input.parse_input_event; dodge reset uses viewport Space press/release; no supplied poses, attack requests, health, knockback or damage",
		"combo_policy": "walking and idle retain melee stage progression; accepted dodge resets next cut to first",
		"fixture": "start_run(true); ordinary sword; primary practice dummy 1.80 units along aim; second dummy 1.80 units at 90 degrees outside the compact arcs; fixed target positions only",
		"raw_frame_count": RAW_COUNT, "raw_fps": 30, "raw_simulation_seconds": RAW_COUNT / 30.0,
		"preview": "all 120 contiguous frames in chronological order, eight initial idle frames, normal three cuts and natural completion; no inserted/repeated/ping-pong frames",
		"physical_weapon_length": 1.9, "stage_reaches": EXPECTED_REACHES,
		"stage_damage": [18.0, 19.0, 34.0], "stage_arcs": [1.35, 1.45, 1.55],
		"physics_context": physics_context, "main_combo": main_result, "directions": directions,
		"walking_continuation": walking_continuation, "dodge_reset": dodge_reset, "contacts": contacts, "geometry_samples": geometry_samples,
		"swing_starts": swing_starts, "screenshots": saved, "screenshot_states": screenshot_states,
		"raw_frames": raw_frames, "raw_states": raw_states, "failures": failures,
	}
	var file := FileAccess.open(output.path_join("capture-manifest.json"), FileAccess.WRITE)
	if file == null: failures.append("could not save manifest")
	else:
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()
	game.queue_free()
	await process_frame
	for failure in failures: printerr("SWORD BASIC CAPTURE FAILED: ", failure)
	print("SWORD BASIC CAPTURE: %d stills + %d native frames; directions=%s; walking_continuation=%s; dodge_reset=%s" % [saved.size(), raw_frames.size(), JSON.stringify(directions), JSON.stringify(walking_continuation), JSON.stringify(dodge_reset)])
	quit(0 if failures.is_empty() else 1)


func _start_practice(label: String, aim_direction: Vector3) -> void:
	case_label = label
	direction = aim_direction
	game.start_run(true)
	game.set_physics_process(false)
	_expect(game.set_weapon_family("sword"), label + " could not equip ordinary sword")
	game.move_input = Vector2.ZERO
	game.test_aim = Vector3.ZERO
	primary = game.enemies[0]
	primary.position = game.player.position + direction * 1.8
	outside_arc = game.spawn_enemy("dummy", game.player.position + direction.rotated(Vector3.UP, PI * .5) * 1.8)
	primary_min_health = 1000.0
	outside_min_health = 1000.0
	presses = 0
	releases = 0
	space_presses = 0
	space_releases = 0
	aim_at_primary = false
	observed_busy = false
	case_swing_index = swing_starts.size()
	case_contact_index = contacts.size()
	# Let the fixture spawn rings expire before measuring the short blade traces.
	for index in range(72): await _tick()
	case_origin = game.player.position


func _point_mouse() -> Vector2:
	var target: Vector3 = game.player.position + direction * 4.0
	if aim_at_primary and is_instance_valid(primary): target = primary.position
	target.y = 0.0
	var point: Vector2 = game.camera.unproject_position(target)
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	return point


func _mouse(pressed: bool) -> void:
	var point := _point_mouse()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	if pressed: presses += 1
	else: releases += 1
	_record_start()


func _key(physical_key: int, action: String, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical_key
	event.keycode = physical_key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	_expect(Input.is_action_pressed(action) == pressed, "normal %s key did not update movement action" % OS.get_keycode_string(physical_key))


func _space(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.keycode = KEY_SPACE
	event.pressed = pressed
	root.push_input(event, true)
	if pressed: space_presses += 1
	else: space_releases += 1


func _direction_combo(label: String, aim_direction: Vector3, start_index: int) -> void:
	await _start_practice(label, aim_direction)
	_mouse(true)
	var released := false
	var prepared := false
	var diagonal := false
	for index in range(420):
		await _tick()
		if game.motion.busy and game.motion.stage == 2:
			if not released:
				_mouse(false)
				released = true
			var pose: Dictionary = game.current_visual_sample()
			if pose.phase == "windup" and pose.progress >= .85 and not prepared:
				await _capture("%02d-%s-diagonal-preparation" % [start_index, label])
				prepared = true
			if pose.phase == "active" and pose.progress >= .70 and not diagonal:
				await _capture("%02d-%s-diagonal-active" % [start_index + 1, label])
				diagonal = true
		if released and not game.motion.busy: break
	_expect(prepared and diagonal, label + " missing diagonal native stills")
	directions.append(_combo_result(label))


func _walking_continuation() -> Dictionary:
	await _start_practice("walking-continuation", Vector3.RIGHT)
	aim_at_primary = true
	_mouse(true)
	for index in range(3): await _tick()
	_mouse(false)
	for index in range(160):
		await _tick()
		if not game.motion.busy: break
	_expect(game._next_combo == 1, "first ordinary click did not queue second stage before movement")
	await _capture("19-before-movement-next-is-second")
	var before: Vector3 = game.player.position
	var before_time: float = game.run_time
	_key(KEY_W, "move_up", true)
	for index in range(WALK_LEG_TICKS):
		await _tick()
		_expect(game._next_combo == 1, "W walking cleared the queued second cut")
	_key(KEY_W, "move_up", false)
	await _tick()
	var travel: float = game.player.position.distance_to(before)
	var outbound_seconds: float = game.run_time - before_time
	_expect(travel > .1 and outbound_seconds > .85 and game._next_combo == 1, "normal W walking did not retain second cut past old expiry")
	await _capture("20-normal-walking-keeps-second")
	# Return with real movement so both clicks can hit the unchanged fixed fixture.
	_key(KEY_S, "move_down", true)
	for index in range(WALK_LEG_TICKS):
		await _tick()
		_expect(game._next_combo == 1, "S return walking cleared the queued second cut")
	_key(KEY_S, "move_down", false)
	await _tick()
	var return_error: float = game.player.position.distance_to(before)
	_expect(return_error < .15, "normal return walk did not regain fixed target range")
	_mouse(true)
	for index in range(3): await _tick()
	_mouse(false)
	for index in range(160):
		await _tick()
		if game.motion.busy and game.current_visual_sample().phase == "active":
			await _capture("21-after-walking-second-cut-active")
			break
	for index in range(160):
		await _tick()
		if not game.motion.busy: break
	var sequence := _stage_sequence()
	_expect(sequence == [0, 1], "walking did not continue first click into second stage")
	_expect(presses == 2 and releases == 2 and game.hits == 2 and is_equal_approx(game.total_damage, 37.0), "walking continuation click/hit/damage totals mismatch")
	_expect(outside_min_health == 1000.0, "walking continuation reached outside-arc fixture")
	return {"policy": "walking retains next cut beyond old .85-second expiry", "stage_sequence": sequence, "mouse_presses": presses, "mouse_releases": releases, "normal_key": "W", "return_key": "S", "key_held_physics_ticks": WALK_LEG_TICKS, "return_key_held_physics_ticks": WALK_LEG_TICKS, "outbound_simulation_seconds": outbound_seconds, "actual_movement_units": travel, "return_position_error": return_error, "hits": game.hits, "damage": game.total_damage, "final_phase": game.current_visual_sample().phase, "outside_arc_min_health": outside_min_health}


func _dodge_reset() -> Dictionary:
	await _start_practice("dodge-reset", Vector3.RIGHT)
	aim_at_primary = true
	_mouse(true)
	for index in range(3): await _tick()
	_mouse(false)
	for index in range(160):
		await _tick()
		if not game.motion.busy: break
	_expect(game._next_combo == 1, "first ordinary click did not queue second stage before dodge")
	await _capture("22-before-dodge-next-is-second")
	_point_mouse()
	var stamina_before: float = game.stamina
	var before: Vector3 = game.player.position
	_space(true)
	var stamina_after_press: float = game.stamina
	var dodge_left_after_press: float = game._dodge_left
	var next_combo_after_press: int = game._next_combo
	_space(false)
	_expect(dodge_left_after_press > 0 and stamina_after_press < stamina_before, "viewport Space binding did not start a successful stamina-consuming dodge")
	_expect(next_combo_after_press == 0, "accepted Space dodge did not reset next cut to first")
	await _tick()
	await _capture("23-space-dodge-resets-first")
	for index in range(120):
		await _tick()
		if game._dodge_left <= 0: break
	var travel: float = game.player.position.distance_to(before)
	_expect(travel > .1 and game._dodge_left <= 0, "Space dodge did not move and finish naturally")
	_mouse(true)
	for index in range(3): await _tick()
	_mouse(false)
	for index in range(160):
		await _tick()
		if game.motion.busy and game.current_visual_sample().phase == "active":
			await _capture("24-after-dodge-first-cut-active")
			break
	for index in range(160):
		await _tick()
		if not game.motion.busy: break
	var sequence := _stage_sequence()
	_expect(sequence == [0, 0], "accepted dodge did not produce two first-stage clicks")
	_expect(presses == 2 and releases == 2 and game.hits == 2 and is_equal_approx(game.total_damage, 36.0), "dodge reset click/hit/damage totals mismatch")
	_expect(space_presses == 1 and space_releases == 1, "dodge did not use one viewport Space press/release")
	_expect(outside_min_health == 1000.0, "dodge reset reached outside-arc fixture")
	return {"policy": "accepted dodge resets next cut to first", "stage_sequence": sequence, "mouse_presses": presses, "mouse_releases": releases, "normal_key": "Space", "space_presses": space_presses, "space_releases": space_releases, "input_route": "Viewport.push_input", "stamina_before": stamina_before, "stamina_after_press": stamina_after_press, "dodge_left_after_press": dodge_left_after_press, "next_combo_after_press": next_combo_after_press, "actual_movement_units": travel, "hits": game.hits, "damage": game.total_damage, "final_phase": game.current_visual_sample().phase, "outside_arc_min_health": outside_min_health}


func _combo_result(label: String) -> Dictionary:
	var sequence := _stage_sequence()
	var damage_steps: Array[float] = []
	for contact: Dictionary in contacts.slice(case_contact_index): damage_steps.append(contact.damage_this_tick)
	_expect(sequence == [0, 1, 2], label + " did not perform exactly three ordered swings")
	_expect(game.hits == 3 and is_equal_approx(game.total_damage, 71.0) and damage_steps == [18.0, 19.0, 34.0], label + " actual hits/damage did not equal 18 + 19 + 34")
	_expect(presses == 1 and releases == 1 and not game.motion.busy, label + " did not complete one hold/release cycle")
	_expect(outside_min_health == 1000.0, label + " hit the 90-degree outside-arc fixture")
	_expect(game.mace_dash_travelled == 0.0, label + " ordinary sword used mace dash")
	return {"aim": label, "aim_vector": _vector(game.aim), "mouse_presses": presses, "mouse_releases": releases, "stage_sequence": sequence, "damage_steps": damage_steps, "hits": game.hits, "damage": game.total_damage, "primary_min_health": primary_min_health, "outside_arc_min_health": outside_min_health, "actual_displacement": _vector(game.player.position - case_origin), "mace_dash_travelled": game.mace_dash_travelled, "final_phase": game.current_visual_sample().phase}


func _stage_sequence() -> Array[int]:
	var result: Array[int] = []
	for entry: Dictionary in swing_starts.slice(case_swing_index): result.append(entry.stage)
	return result


func _record_start() -> void:
	if game.motion.busy and not observed_busy:
		swing_starts.append({"case": case_label, "stage": game.motion.stage, "simulation_time": game.run_time, "physics_tick": physics_context.ticks})
	observed_busy = game.motion.busy


func _tick() -> void:
	await physics_frame
	if not _window_is_offscreen():
		printerr("SWORD BASIC CAPTURE FAILED: unsafe native window at physics tick")
		quit(1)
		return
	var in_physics := Engine.is_in_physics_frame()
	var physical_delta: float = game.player.get_physics_process_delta_time()
	physics_context.ticks += 1
	physics_context.min_physics_delta = minf(physics_context.min_physics_delta, physical_delta)
	physics_context.max_physics_delta = maxf(physics_context.max_physics_delta, physical_delta)
	if not in_physics: physics_context.outside_physics_ticks += 1
	_expect(in_physics and absf(physical_delta - STEP) < .000001 and Engine.physics_ticks_per_second == 120, "native tick was not in real 120-Hz physics")
	if not game.motion.busy: _point_mouse()
	var old_hits: int = game.hits
	var old_damage: float = game.total_damage
	game.tick(STEP)
	_record_start()
	primary_min_health = minf(primary_min_health, primary.health)
	outside_min_health = minf(outside_min_health, outside_arc.health)
	var state := _state()
	physics_context.min_physical_weapon_length = minf(physics_context.min_physical_weapon_length, state.weapon_length)
	physics_context.max_physical_weapon_length = maxf(physics_context.max_physical_weapon_length, state.weapon_length)
	physics_context.max_rendered_tip_error = maxf(physics_context.max_rendered_tip_error, state.rendered_tip_error)
	_expect(absf(state.weapon_length - 1.9) < .0001, "ordinary sword changed its rigid 1.90-unit length")
	_expect(state.rendered_tip_error < .0001, "transformed sword sprite endpoint disagreed with rigid pose")
	if state.phase == "active":
		var error: float = absf(state.ground_tip_reach - state.stage_reach)
		physics_context.max_active_ground_reach_error = maxf(physics_context.max_active_ground_reach_error, error)
		_expect(error < .0001, "active rendered sword tip did not match stage ground reach")
		geometry_samples.append(state)
	if game.hits > old_hits:
		var contact: Dictionary = state.duplicate(true)
		contact.damage_this_tick = game.total_damage - old_damage
		contact.hits_this_tick = game.hits - old_hits
		contact.in_physics_frame = in_physics
		contact.physics_delta = physical_delta
		contacts.append(contact)
	if capture_main_phases and game.motion.busy:
		var phase: String = state.phase
		var threshold: float = .55 if phase == "windup" else (.70 if phase == "active" else .45)
		var key := "%d-%s" % [state.stage, phase]
		if state.progress >= threshold and not marked.has(key):
			marked[key] = true
			var phase_index: int = ["windup", "active", "recovery"].find(phase)
			await _capture("%02d-stage%d-%s" % [3 + state.stage * 3 + phase_index, state.stage + 1, phase])


func _state() -> Dictionary:
	var pose: Dictionary = game.current_visual_sample()
	var blade: Dictionary = game.avatar.get_blade_points()
	var angle: float = pose.angle
	var pitch: float = pose.get("pitch", 0.0)
	var forward := Vector3(cos(angle), 0, sin(angle))
	var expected_tip: Vector3 = game.player.position + forward * pose.radius + Vector3.UP * pose.get("grip_height", .68) + (forward * cos(pitch) + Vector3.UP * sin(pitch)) * 1.9
	var ground_tip: Vector3 = blade.tip - game.player.position
	ground_tip.y = 0
	var definition: Dictionary = game.motion.definition(game.motion.stage)
	return {"case": case_label, "physics_tick": physics_context.ticks, "simulation_time": game.run_time, "stage": game.motion.stage, "phase": pose.phase, "progress": pose.progress, "busy": game.motion.busy, "next_combo": game._next_combo, "stamina": game.stamina, "dodge_left": game._dodge_left, "angle": angle, "aim_angle": game.motion.aim_angle, "pitch": pitch, "radius": pose.radius, "grip_height": pose.get("grip_height", .68), "stage_reach": definition.get("reach", 0.0), "hits": game.hits, "damage": game.total_damage, "primary_health": primary.health if is_instance_valid(primary) else -1.0, "outside_arc_health": outside_arc.health if is_instance_valid(outside_arc) else -1.0, "trails_active": game.fx.trails.size(), "weapon_length": blade.grip.distance_to(blade.tip), "ground_tip_reach": ground_tip.length(), "rendered_tip_error": blade.tip.distance_to(expected_tip), "weapon_grip": _vector(blade.grip), "weapon_tip": _vector(blade.tip), "expected_tip": _vector(expected_tip), "player_position": _vector(game.player.position), "target_position": _vector(primary.position) if is_instance_valid(primary) else [], "screen_points": [_vector2(game.camera.unproject_position(game.player.position)), _vector2(game.camera.unproject_position(blade.grip)), _vector2(game.camera.unproject_position(blade.tip)), _vector2(game.camera.unproject_position(primary.position + Vector3.UP)) if is_instance_valid(primary) else [640, 400]]}


func _capture(name: String) -> void:
	var path := output.path_join(name + ".png")
	await _save_frame(path)
	saved.append(path)
	var state := {} if name == "01-menu" else _state()
	state.file = path.get_file()
	screenshot_states.append(state)
	print("SWORD BASIC CAPTURE: ", path)


func _save_frame(path: String) -> void:
	if not _window_is_offscreen():
		_expect(false, "native capture window lost offscreen/no-focus state")
		return
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(_window_is_offscreen(), "native window moved during frame readback")
	var picture: Image = root.get_texture().get_image()
	_expect(picture != null and not picture.is_empty() and picture.get_size() == Vector2i(1280, 800) and picture.save_png(path) == OK, "could not save full 1280x800 native viewport: " + path)


func _window_is_offscreen() -> bool:
	return root.unfocusable and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS) and DisplayServer.window_get_position() == Vector2i(20000, 20000)


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)


func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _vector2(value: Vector2) -> Array[float]:
	return [value.x, value.y]
