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
		printerr("TWIN CUT CAPTURE FAILED: safe window state lost")
		quit(1)
	return false

func _run() -> void:
	if output.is_empty() or not output.is_absolute_path() or DisplayServer.get_name() == "headless":
		printerr("TWIN CUT CAPTURE FAILED: native renderer and absolute --output required")
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
	DirAccess.make_dir_recursive_absolute(output.path_join("twin-cut"))
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.staff_flight.damage_hit.connect(_observe_projectile_contact)
	_add_label()
	await _skill_sequence()
	await _skill_cancel(false)
	await _skill_cancel(true)
	for family: String in ["sword", "greatsword", "mace", "staff", "pistol", "rifle"]:
		await _basic_cancel(family)
	for family: String in ["pistol", "rifle"]: await _reload_cancel(family)
	await _released_fireball()
	_expect(cases.size() == 12, "expected twelve native cases")
	_expect(physics.outside_physics_ticks == 0, "model tick outside actual physics")
	if record_frames: _expect(raw_frames.size() == 90, "expected 90 chronological frames")
	var manifest := {"renderer": DisplayServer.get_name(), "engine": Engine.get_version_info().string,
		"native_window": {"unfocusable": root.unfocusable, "native_no_focus_flag": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS), "actual_position": [DisplayServer.window_get_position().x, DisplayServer.window_get_position().y], "mode": root.mode, "checked_every_frame_and_tick": true},
		"input": "Viewport.push_input actual Q, Space, R and LMB press/release; mouse aim on central playfield. No direct attack/skill/dodge/reload/damage/projectile APIs.",
		"fixture": "Original practice dummy positioned once at (1.7,.03,0), except released-fireball persistence at (4,.03,0) to observe free flight beyond launch safety sweep; original player spawn. Production camera untouched. Family preparation only via set_weapon_family; all rounds consumed by actual LMB. No health, pose, stage, cooldown, or damage injection. No target movement after setup.",
		"authored_cut_seconds": [.15, .20], "authored_total_seconds": .35,
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
	for failure in failures: printerr("TWIN CUT CAPTURE FAILED: ", failure)
	print("TWIN CUT CAPTURE: %d cases / %d stills / %d raw frames; failures=%s" % [cases.size(), screenshots.size(), raw_frames.size(), JSON.stringify(failures)])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _fixture(family: String, name: String, target_distance: float = 1.7) -> void:
	case_label = name
	game.start_run(true)
	game.set_physics_process(false)
	_expect(game.set_weapon_family(family), name + " family setup rejected")
	dummy = game.enemies[0]
	dummy_position = Vector3(target_distance, .03, 0)
	dummy.position = dummy_position
	initial_health = dummy.health
	minimum_health = dummy.health
	keys.clear()
	mouse_presses = 0
	mouse_releases = 0
	for index in range(72): await _tick()
	_point_mouse()

func _skill_sequence() -> void:
	await _fixture("sword", "q-automatic-two-cuts-and-reuse")
	_key(KEY_F)
	_expect(game.skill_active, "actual Q failed to start skill")
	var start_tick: int = physics.ticks
	var first_hit_tick := -1
	var second_hit_tick := -1
	var first_seen := false
	var second_seen := false
	var completed := false
	var reused := false
	var completed_tick := -1
	var reuse_tick := -1
	for index in range(360):
		await _tick()
		if not first_seen and game.hits >= 1:
			first_seen = true
			first_hit_tick = physics.ticks
			await _capture("q-01-first-hit")
		if not second_seen and game.hits >= 2:
			second_seen = true
			second_hit_tick = physics.ticks
			await _capture("q-02-second-hit")
		if not completed and not game.skill_active:
			completed = true
			completed_tick = physics.ticks
			_expect(game.hits == 2 and is_equal_approx(game.total_damage, 37), "one Q must deliver exactly 18+19 damage")
			_key(KEY_F)
			reuse_tick = physics.ticks
			reused = game.skill_active
			_expect(reused, "immediate second Q blocked after completion")
		if record_frames and index % 4 == 3:
			var path := output.path_join("twin-cut/frame_%03d.png" % raw_frames.size())
			await _save(path)
			raw_frames.append(path)
			var frame := _state()
			frame.frame_index = raw_frames.size() - 1
			frame.native_elapsed_seconds = (index + 1) * STEP
			raw_states.append(frame)
	_expect(first_seen and second_seen and completed and reused, "automatic/reuse sequence incomplete")
	_expect(game.hits == 4 and is_equal_approx(game.total_damage, 74) and not game.skill_active, "two Q presses must finish four hits / 74 damage")
	await _capture("q-03-immediate-reuse-finished")
	var result := _result()
	result.first_completion_tick = completed_tick
	result.first_hit_seconds = (first_hit_tick - start_tick) * STEP
	result.second_hit_seconds = (second_hit_tick - start_tick) * STEP
	result.first_completion_seconds = (completed_tick - start_tick) * STEP
	_expect(result.first_hit_seconds < .13, "first Q hit must beat ordinary windup")
	_expect(result.second_hit_seconds - result.first_hit_seconds < .20, "rapid followup within .20s")
	_expect(result.first_completion_seconds < .42, "both Q cuts finish faster than one normal cut, including actual hitstop")
	result.reuse_press_tick = reuse_tick
	cases.append(result)

func _skill_cancel(after_first: bool) -> void:
	var name := "q-dodge-after-first-hit" if after_first else "q-dodge-first-windup"
	await _fixture("sword", name)
	_key(KEY_F)
	if after_first:
		for index in range(180):
			await _tick()
			if game.hits == 1: break
	else:
		for index in range(4): await _tick()
	_expect(game.skill_active and game.hits == (1 if after_first else 0), name + " prerequisite missing")
	var before := _state()
	_key(KEY_SPACE)
	_expect(game._dodge_left > 0 and not game.skill_active and not game.motion.busy, name + " Space did not immediately cancel")
	await _capture(name)
	for index in range(180): await _tick()
	_expect(game.hits == (1 if after_first else 0) and is_equal_approx(game.total_damage, 18 if after_first else 0), name + " cancelled cut delivered later damage")
	var result := _result()
	result.before_dodge = before
	cases.append(result)

func _basic_cancel(family: String) -> void:
	var name := family + "-basic-windup-dodge"
	await _fixture(family, name)
	_mouse(true)
	_mouse(false)
	for index in range(2): await _tick()
	_expect(game.motion.busy and game.current_visual_sample().phase == "windup", name + " real LMB windup missing")
	var before := _state()
	_key(KEY_SPACE)
	_expect(game._dodge_left > 0 and not game.motion.busy, name + " Space failed immediate priority")
	await _capture(name)
	for index in range(180): await _tick()
	_expect(game.hits == 0 and game.total_damage == 0 and game.staff_flight.shots_fired == 0, name + " cancelled windup released contact or projectile")
	if family in ["pistol", "rifle"]:
		_expect(game.active_magazine().rounds == game.active_magazine().capacity, name + " unreleased shot spent a round")
	var result := _result()
	result.before_dodge = before
	cases.append(result)

func _reload_cancel(family: String) -> void:
	var name := family + "-reload-dodge"
	await _fixture(family, name)
	_mouse(true)
	_mouse(false)
	for index in range(300):
		await _tick()
		if game.staff_flight.shots_fired == 1 and not game.motion.busy: break
	var rounds: int = game.active_magazine().rounds
	_expect(rounds == game.active_magazine().capacity - 1, name + " natural priming shot did not spend one round")
	_key(KEY_R)
	for index in range(12): await _tick()
	_expect(game.active_magazine().reloading, name + " actual R failed to start reload")
	var before := _state()
	_key(KEY_SPACE)
	_expect(game._dodge_left > 0 and not game.active_magazine().reloading and game.active_magazine().rounds == rounds, name + " Space did not cancel reload without refill")
	await _capture(name)
	for index in range(240): await _tick()
	_expect(not game.active_magazine().reloading and game.active_magazine().rounds == rounds, name + " cancelled reload refilled later")
	var result := _result()
	result.before_dodge = before
	cases.append(result)

func _released_fireball() -> void:
	await _fixture("staff", "released-fireball-survives-dodge", 4.0)
	_mouse(true)
	_mouse(false)
	for index in range(240):
		await _tick()
		if game.staff_flight.shots_fired == 1: break
	_expect(game.staff_flight.active.size() == 1 and game.hits == 0, "staff released projectile prerequisite missing")
	var before := _state()
	_key(KEY_SPACE)
	_expect(game._dodge_left > 0 and game.staff_flight.active.size() == 1, "dodge removed released fireball")
	await _capture("released-fireball-survives-dodge")
	for index in range(240): await _tick()
	_expect(game.hits == 1 and is_equal_approx(game.total_damage, 72) and game.staff_flight.shots_fired == 1, "released projectile failed normal damage after dodge")
	var result := _result()
	result.before_dodge = before
	cases.append(result)

func _tick() -> void:
	await physics_frame
	if not _window_safe():
		printerr("TWIN CUT CAPTURE FAILED: unsafe physics window")
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
		"motion_busy": game.motion.busy, "hits": game.hits, "damage": game.total_damage, "shots": game.staff_flight.shots_fired,
		"rounds": game.active_magazine().rounds, "capacity": game.active_magazine().capacity, "reloading": game.active_magazine().reloading,
		"stamina": game.stamina, "dodge_left": game._dodge_left, "player_position": _vec(game.player.position), "target_position": _vec(dummy.position),
		"target_damage": initial_health - minimum_health, "target_current_health": dummy.health, "flights": flights,
		"screen_player_ground": _vec2(game.camera.unproject_position(game.player.position)), "screen_player_top": _vec2(game.camera.unproject_position(game.player.position + Vector3.UP * 1.9)),
		"screen_target_ground": _vec2(game.camera.unproject_position(dummy.position)), "screen_target_top": _vec2(game.camera.unproject_position(dummy.position + Vector3.UP * 2.2))}

func _result() -> Dictionary:
	var result := _state()
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
	label.text = "NATIVE Q / SPACE / LMB / R : %s\nHITS %d / DAMAGE %.0f / CUT %d / DODGE %.3f / AMMO %d\nFIXED ORIGINAL DUMMY / ACTUAL INPUT / 120 Hz" % [case_label.to_upper(), game.hits, game.total_damage, game.skill_cut_index + 1, game._dodge_left, game.active_magazine().rounds]

func _capture(name: String) -> void:
	_refresh_label()
	var path := output.path_join(name + ".png")
	await _save(path)
	var state := _state()
	state.file = path.get_file()
	screenshots.append(state)
	print("TWIN CUT CAPTURE: ", path)

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
