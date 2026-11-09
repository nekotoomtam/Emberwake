extends SceneTree
## Native actual-input evidence; absolute external --script beside exported PCK.
const STEP := 1.0 / 120.0
var game
var output := ""
var record_frames := false
var safe := false
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var screenshots: Array[Dictionary] = []
var raw_frames: Array[String] = []
var raw_states: Array[Dictionary] = []
var events: Array[Dictionary] = []
var case_label := ""
var keys: Array[String] = []
var mouse_presses := 0
var mouse_releases := 0
var dummy
var dummy_position := Vector3(1.7, .03, 0)
var initial_health := 0.0
var minimum_health := 0.0
var label: Label
var physics := {"ticks": 0, "outside_physics_ticks": 0, "min_physics_delta": INF, "max_physics_delta": 0.0, "physics_ticks_per_second": 120}

func _initialize() -> void:
	root.unfocusable = true
	Engine.physics_ticks_per_second = 120
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		if argument == "--frames": record_frames = true
	call_deferred("_run")

func _process(_delta: float) -> bool:
	if safe and not _window_safe():
		printerr("ARMOR PIERCE CAPTURE FAILED: safe window state lost")
		quit(1)
	return false

func _run() -> void:
	if output.is_empty() or not output.is_absolute_path() or DisplayServer.get_name() == "headless":
		printerr("ARMOR PIERCE CAPTURE FAILED: native renderer and absolute --output required")
		quit(1)
		return
	root.unfocusable = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_position(Vector2i(20000, 20000))
	safe = true
	await process_frame
	if not _window_safe():
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output.path_join("armor-pierce"))
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.staff_flight.damage_hit.connect(_observe_projectile_contact)
	_add_label()
	await _full_sequence()
	for timing: String in ["first-windup", "after-slash", "stab-precontact", "post-contact"]: await _cancel_case(timing)
	await _element_followup("staff", 72.0)
	await _element_followup("pistol", 22.5)
	await _refresh_case()
	await _expiry_pause()
	await _cover_case()
	await _q_reuse()
	_expect(cases.size() == 11, "expected eleven native cases")
	_expect(physics.outside_physics_ticks == 0, "model tick outside actual physics")
	if record_frames: _expect(raw_frames.size() == 90, "expected 90 chronological frames")
	var manifest := {"renderer": DisplayServer.get_name(), "engine": Engine.get_version_info().string,
		"native_window": {"unfocusable": root.unfocusable, "native_no_focus_flag": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS), "actual_position": [DisplayServer.window_get_position().x, DisplayServer.window_get_position().y], "mode": root.mode, "checked_every_frame_and_tick": true},
		"input": "Viewport.push_input actual E, Q, Space, Escape, T and LMB press/release; mouse aim on central playfield. No direct attack/skill/dodge/reload/damage/projectile APIs.",
		"fixture": "Original practice dummy positioned once per case at (1.7,.03,0), original player spawn. No armor, health, pose, stage or damage injection. Status earned exclusively through actual E. Cover case adds world-mask-1 StaticBody3D box at (.85,.7,0), size(.2,1.4,2), between original player and original dummy. Family preparation via set_weapon_family only; T actually restarts fixture. Production camera untouched.",
		"physics_context": physics, "cases": cases, "events": events, "screenshot_states": screenshots,
		"raw_fps": 30, "raw_frame_count": raw_frames.size(), "raw_frames": raw_frames, "raw_states": raw_states,
		"failures": failures}
	var file := FileAccess.open(output.path_join("capture-manifest.json"), FileAccess.WRITE)
	if file == null:
		printerr("Cannot write capture manifest")
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	for failure in failures: printerr("ARMOR PIERCE CAPTURE FAILED: ", failure)
	print("ARMOR PIERCE CAPTURE: %d cases / %d stills / %d raw frames; failures=%s" % [cases.size(), screenshots.size(), raw_frames.size(), JSON.stringify(failures)])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _fixture(family: String, name: String, target_distance: float = 1.7) -> void:
	case_label = name
	game.start_run(true)
	_key(KEY_T)
	game.set_physics_process(false)
	_expect(game.set_weapon_family(family), name + " family setup rejected")
	dummy = game.enemies[0]
	_expect(game.mode == "practice" and game.hits == 0 and game.total_damage == 0 and dummy.armor_rating == 100 and dummy.armor_break_remaining == 0, "actual T did not reset original fixture")
	dummy_position = Vector3(target_distance, .03, 0)
	dummy.position = dummy_position
	initial_health = dummy.health
	minimum_health = dummy.health
	keys.clear()
	mouse_presses = 0
	mouse_releases = 0
	for index in range(72): await _tick()
	_point_mouse()

func _finish_cast(limit: int = 240) -> void:
	for index in range(limit):
		await _tick()
		if not game.skill_active and not game.motion.busy: return
	_expect(false, case_label + " cast failed to finish")

func _earn_break() -> void:
	_key(KEY_E)
	_expect(game.skill_active and game.active_skill_id == "armor_pierce", "actual E failed")
	await _finish_cast()
	_expect(game.hits == 2 and is_equal_approx(game.total_damage, 42), "E must deal 18 + 24 before debuff")
	_expect(is_equal_approx(dummy.armor_rating, 100) and is_equal_approx(dummy.effective_armor(), 80) and dummy.armor_break_remaining > 3.5, "stab failed to earn real armor break")

func _full_sequence() -> void:
	await _fixture("sword", "e-full-then-first-physical")
	_key(KEY_E)
	var basic_sent := false
	var slash_seen := false
	var stab_seen := false
	for index in range(360):
		await _tick()
		if game.hits == 1 and not slash_seen:
			slash_seen = true
			_expect(dummy.armor_break_remaining == 0 and game.total_damage == 18, "first slash applied break")
			await _capture("e-01-slash-no-break")
		if game.hits == 2 and not stab_seen:
			stab_seen = true
			_expect(game.total_damage == 42 and dummy.armor_break_remaining > 0, "stab damage/status order incorrect")
			await _capture("e-02-stab-break")
		if not game.skill_active and not game.motion.busy and not basic_sent:
			_mouse(true)
			_mouse(false)
			basic_sent = true
		if record_frames and index % 4 == 3:
			var path := output.path_join("armor-pierce/frame_%03d.png" % raw_frames.size())
			await _save(path)
			raw_frames.append(path)
			var frame := _state()
			frame.frame_index = raw_frames.size() - 1
			frame.native_elapsed_seconds = (index + 1) * STEP
			raw_states.append(frame)
	_expect(slash_seen and stab_seen and basic_sent and game.hits == 3 and is_equal_approx(game.total_damage, 64.5), "physical first followup must be 18 -> 22.5")
	await _capture("e-03-physical-followup")
	cases.append(_result())

func _cancel_case(timing: String) -> void:
	await _fixture("sword", "e-cancel-" + timing)
	_key(KEY_E)
	for index in range(180):
		await _tick()
		if timing == "first-windup" and index == 2: break
		if timing == "after-slash" and game.hits == 1: break
		if timing == "stab-precontact" and game.skill_cut_index == 1 and game.current_visual_sample().phase == "active" and game.hits == 1: break
		if timing == "post-contact" and game.hits == 2: break
	var before := _state()
	var expected_hits := 0 if timing == "first-windup" else (2 if timing == "post-contact" else 1)
	_expect(game.skill_active and game.hits == expected_hits, timing + " cancellation prerequisite")
	_key(KEY_SPACE)
	_expect(not game.skill_active and not game.motion.busy and game._dodge_left > 0, "Space failed immediate E cancel")
	var lunge: float = game.armor_lunge_travelled
	await _capture(case_label)
	for index in range(180): await _tick()
	_expect(game.hits == expected_hits and is_equal_approx(game.total_damage, 0 if expected_hits == 0 else (42 if expected_hits == 2 else 18)), "cancelled E resurrected damage")
	_expect(is_equal_approx(game.armor_lunge_travelled, lunge), "cancelled stab lunge continued")
	_expect((dummy.armor_break_remaining > 0) == (expected_hits == 2), "cancelled E debuff incorrect")
	var result := _result()
	result.before_dodge = before
	result.cancel_lunge = lunge
	cases.append(result)

func _element_followup(family: String, expected: float) -> void:
	await _fixture("sword", "e-then-" + family)
	await _earn_break()
	_expect(game.set_weapon_family(family), "followup family failed")
	_mouse(true)
	_mouse(false)
	for index in range(240):
		await _tick()
		if game.hits >= 3: break
	_expect(game.hits == 3 and is_equal_approx(game.total_damage - 42, expected), family + " armor response incorrect")
	await _capture(case_label)
	cases.append(_result())

func _refresh_case() -> void:
	await _fixture("sword", "e-refresh-not-stack")
	await _earn_break()
	for index in range(120): await _tick()
	var remaining_before: float = dummy.armor_break_remaining
	_key(KEY_E)
	await _finish_cast()
	_expect(game.hits == 4 and is_equal_approx(game.total_damage, 94.5), "second E physical damage incorrect")
	_expect(is_equal_approx(dummy.armor_break_fraction, .2) and is_equal_approx(dummy.effective_armor(), 80) and dummy.armor_break_remaining > remaining_before, "refresh must reset 4s without stacking")
	await _capture(case_label)
	var result := _result()
	result.remaining_before_refresh = remaining_before
	cases.append(result)

func _expiry_pause() -> void:
	await _fixture("sword", "e-expiry-and-pause-freeze")
	await _earn_break()
	_key(KEY_ESCAPE)
	var frozen: float = dummy.armor_break_remaining
	for index in range(120): await _tick()
	_expect(game.mode == "paused" and is_equal_approx(dummy.armor_break_remaining, frozen), "pause consumed armor break time")
	await _capture("e-paused-break-timer")
	_key(KEY_ESCAPE)
	var sim_start: float = game.run_time
	var remaining_start: float = dummy.armor_break_remaining
	for index in range(600):
		await _tick()
		if dummy.armor_break_remaining <= 0: break
	var elapsed: float = game.run_time - sim_start
	_expect(absf(elapsed - remaining_start) <= STEP * 2 and dummy.armor_break_fraction == 0 and dummy.effective_armor() == 100, "break did not expire in simulation seconds")
	await _capture("e-expired-real-armor-restored")
	var result := _result()
	result.paused_remaining = frozen
	result.expiry_sim_elapsed = elapsed
	result.expiry_start_remaining = remaining_start
	cases.append(result)

func _cover_case() -> void:
	await _fixture("sword", "e-world-cover-blocks-status")
	var cover := StaticBody3D.new()
	cover.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.2, 1.4, 2)
	shape.shape = box
	cover.add_child(shape)
	game.add_child(cover)
	cover.position = Vector3(.85, .7, 0)
	for index in range(3): await _tick()
	_key(KEY_E)
	await _finish_cast()
	_expect(game.hits == 0 and game.total_damage == 0 and dummy.armor_break_remaining == 0, "world cover failed to stop damage/status")
	await _capture(case_label)
	cases.append(_result())
	cover.queue_free()
	await process_frame

func _q_reuse() -> void:
	await _fixture("sword", "q-retains-37-and-immediate-reuse")
	_key(KEY_F)
	await _finish_cast()
	_expect(game.hits == 2 and game.total_damage == 37 and dummy.armor_break_remaining == 0, "Q regression 37 / no status")
	_key(KEY_F)
	_expect(game.skill_active and game.active_skill_id == "twin_cut", "Q immediate reuse failed")
	await _finish_cast()
	_expect(game.hits == 4 and game.total_damage == 74, "Q reuse data changed")
	await _capture(case_label)
	cases.append(_result())

func _tick() -> void:
	await physics_frame
	if not _window_safe():
		printerr("ARMOR PIERCE CAPTURE FAILED: unsafe physics window")
		quit(1)
		return
	var actual: bool = Engine.is_in_physics_frame()
	var delta: float = game.player.get_physics_process_delta_time()
	physics.ticks += 1
	if not actual: physics.outside_physics_ticks += 1
	physics.min_physics_delta = minf(physics.min_physics_delta, delta)
	physics.max_physics_delta = maxf(physics.max_physics_delta, delta)
	_expect(actual and absf(delta - STEP) < .000001 and Engine.physics_ticks_per_second == 120, "not actual 120-Hz physics")
	var previous_hits: int = game.hits
	if not game.motion.busy and not game.skill_active: _point_mouse()
	game.tick(STEP)
	minimum_health = minf(minimum_health, dummy.health)
	_expect(dummy.position.distance_to(dummy_position) < .0001, case_label + " original dummy moved")
	if game.hits != previous_hits: events.append(_state())
	_refresh_label()

func _observe_projectile_contact(enemy, _amount: float, _force: Vector3, _element: String) -> void:
	# Production contact handler runs first; read health before normal practice auto-heal.
	if enemy == dummy: minimum_health = minf(minimum_health, enemy.health)

func _state() -> Dictionary:
	var flights: Array[Dictionary] = []
	for entry: Dictionary in game.staff_flight.active:
		flights.append({"position": _vec(entry.node.global_position), "screen_position": _vec2(game.camera.unproject_position(entry.node.global_position)), "age": entry.age})
	return {"case": case_label, "family": game.weapon_family, "physics_tick": physics.ticks, "time": game.run_time,
		"phase": game.current_visual_sample().phase, "skill_active": game.skill_active, "skill_cut_index": game.skill_cut_index,
		"active_skill_id": game.active_skill_id, "armor_lunge_travelled": game.armor_lunge_travelled,
		"armor_rating": dummy.armor_rating, "effective_armor": dummy.effective_armor(), "armor_break_fraction": dummy.armor_break_fraction, "armor_break_remaining": dummy.armor_break_remaining, "mode": game.mode,
		"motion_busy": game.motion.busy, "hits": game.hits, "damage": game.total_damage, "shots": game.staff_flight.shots_fired,
		"rounds": game.active_magazine().rounds, "capacity": game.active_magazine().capacity, "reloading": game.active_magazine().reloading,
		"stamina": game.stamina, "dodge_left": game._dodge_left, "player_position": _vec(game.player.position), "target_position": _vec(dummy.position),
		"target_damage": initial_health - minimum_health, "target_current_health": dummy.health, "flights": flights,
		"screen_player_ground": _vec2(game.camera.unproject_position(game.player.position)), "screen_player_top": _vec2(game.camera.unproject_position(game.player.position + Vector3.UP * 1.9)),
		"screen_target_ground": _vec2(game.camera.unproject_position(dummy.position)), "screen_target_top": _vec2(game.camera.unproject_position(dummy.position + Vector3.UP * 2.2))}

func _result() -> Dictionary:
	var result := _state()
	result.fixture_restart_key = "T"
	result.keys = keys.duplicate()
	result.mouse_presses = mouse_presses
	result.mouse_releases = mouse_releases
	return result

func _point_mouse() -> Vector2:
	var target: Vector3 = game.player.position + Vector3.RIGHT * 2.5
	target.y = 0
	var point: Vector2 = game.camera.unproject_position(target)
	_expect(point.y > 190 and point.y < 690 and point.x > 25 and point.x < 1255, "aim point outside HUD-free central playfield")
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
	if pressed: mouse_presses += 1
	else: mouse_releases += 1

func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	keys.append(OS.get_keycode_string(code))

func _add_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	game.add_child(layer)
	label = Label.new()
	label.position = Vector2(26, 122)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("#ffe7a9"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)

func _refresh_label() -> void:
	label.text = "NATIVE E / SPACE / LMB / ESC / T : %s\nHITS %d / DAMAGE %.1f / STAGE %d / DODGE %.3f / AMMO %d\nFIXED ORIGINAL DUMMY / REAL ARMOR / ACTUAL INPUT / 120 Hz" % [case_label.to_upper(), game.hits, game.total_damage, game.skill_cut_index + 1, game._dodge_left, game.active_magazine().rounds]

func _capture(name: String) -> void:
	_refresh_label()
	var path := output.path_join(name + ".png")
	await _save(path)
	var state := _state()
	state.file = path.get_file()
	screenshots.append(state)
	print("ARMOR PIERCE CAPTURE: ", path)

func _save(path: String) -> void:
	_expect(_window_safe(), "unsafe before frame readback")
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(_window_safe(), "unsafe during frame readback")
	var picture: Image = root.get_texture().get_image()
	_expect(picture != null and not picture.is_empty() and picture.get_size() == Vector2i(1280, 800) and picture.save_png(path) == OK, "frame readback failed " + path)

func _window_safe() -> bool:
	return root.unfocusable and root.mode == Window.MODE_WINDOWED and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS) and DisplayServer.window_get_position() == Vector2i(20000, 20000)

func _vec(value: Vector3) -> Array[float]: return [value.x, value.y, value.z]
func _vec2(value: Vector2) -> Array[float]: return [value.x, value.y]
func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)

