extends SceneTree
## Native-render evidence. Never inject a projectile, pose, hit, or magazine state.
## Launch hidden: --minimized --position 20000,20000 -- --output=<absolute folder>.

const STEP := 1.0 / 120.0
const RAW_COUNT := 120
var game
var output := ""
var saved: Array[String] = []
var raw_frames: Array[String] = []
var raw_states: Array[Dictionary] = []
var failures: Array[String] = []
var marked: Dictionary = {}
var directions: Array[Dictionary] = []
var muzzles: Array[Dictionary] = []
var contacts: Array[Dictionary] = []
var reload_samples: Array[Dictionary] = []
var reload_events: Array[Dictionary] = []
var direction_label := "right"
var direction := Vector3.RIGHT
var primary
var rear
var main_case := false
var safety_ready := false
var primary_min_health := 1000.0
var rear_min_health := 1000.0
var presses := 0
var releases := 0
var reload_count := 0
var reload_start_time := -1.0
var reload_start_tick := -1
var previous_reload_rotation := 0.0
var measured_reload_turn := 0.0
var physics_context := {"ticks": 0, "outside_physics_ticks": 0, "physics_ticks_per_second": 120, "model_delta": STEP, "min_physics_delta": INF, "max_physics_delta": 0.0, "min_physical_weapon_length": INF, "max_physical_weapon_length": 0.0}


func _initialize() -> void:
	root.unfocusable = true
	Engine.physics_ticks_per_second = 120
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	call_deferred("_run")


func _process(_delta: float) -> bool:
	if safety_ready and not _window_is_offscreen():
		printerr("PISTOL CAPTURE FAILED: native window lost offscreen/no-focus state")
		quit(1)
	return false


func _run() -> void:
	if output.is_empty() or not output.is_absolute_path() or DisplayServer.get_name() == "headless":
		printerr("PISTOL CAPTURE FAILED: native renderer and absolute --output folder required")
		quit(1)
		return
	# The startup position may be clamped. Apply the actual native flags and
	# placement after startup, and verify them on every frame and capture tick.
	root.unfocusable = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_position(Vector2i(20000, 20000))
	safety_ready = true
	await process_frame
	if not _window_is_offscreen():
		printerr("PISTOL CAPTURE FAILED: safe native window setup failed")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output.path_join("shot"))
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	if not _window_is_offscreen():
		printerr("PISTOL CAPTURE FAILED: initialization reset safe window state")
		quit(1)
		return
	_expect(game.weapon_family == "sword", "initial menu did not default to ordinary sword")
	await _capture("01-menu")
	await _start_practice("right", Vector3.RIGHT)
	main_case = true
	await _capture("02-ready")
	var timeline_start: float = game.run_time
	_mouse(true)
	for frame_index in range(RAW_COUNT):
		for substep in range(4):
			await _tick()
			if game.staff_flight.shots_fired == 11 and releases == 0: _mouse(false)
		var frame_path := output.path_join("shot/shot_%03d.png" % frame_index)
		await _save_frame(frame_path)
		raw_frames.append(frame_path)
		var state := _state()
		state.frame_index = frame_index
		state.timeline_seconds = game.run_time - timeline_start
		raw_states.append(state)
	await _capture("13-post-reload-idle")
	var magazine_result := _result("right-full-magazine", 11)
	magazine_result.reload_count = reload_count
	magazine_result.measured_reload_turn_radians = measured_reload_turn
	magazine_result.final_rounds = game.pistol_magazine.rounds
	_expect(reload_count == 1, "full magazine did not use exactly one automatic reload")
	_expect(game.pistol_magazine.rounds == 9 and not game.pistol_magazine.reloading, "eleventh shot did not leave nine rounds")
	_expect(absf(measured_reload_turn - TAU) < 0.001, "native sprite did not complete exactly one reload turn")
	for key in ["bullet", "impact", "empty", "reload-start", "quarter", "half", "three-quarter", "refill", "post-reload-bullet"]:
		_expect(marked.has(key), "missing full-magazine still: " + key)
	main_case = false
	await _direction_shot("right", Vector3.RIGHT, 14)
	await _direction_shot("left", Vector3.LEFT, 16)
	await _direction_shot("away", Vector3.FORWARD, 18)
	await _direction_shot("toward", Vector3.BACK, 20)
	var range_result: Dictionary = await _range_shot()
	_expect(saved.size() == 24, "expected 24 full-resolution native stills")
	_expect(raw_frames.size() == RAW_COUNT, "expected 120 contiguous native 30-fps frames")
	var manifest := {
		"renderer": DisplayServer.get_name(), "engine": Engine.get_version_info().string,
		"native_window": {"unfocusable": root.unfocusable, "native_no_focus_flag": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS), "requested_position": [20000, 20000], "actual_position": [DisplayServer.window_get_position().x, DisplayServer.window_get_position().y], "checked_every_frame_and_tick": true},
		"input": "Viewport.push_input mouse motion and left mouse press/hold/release; main press held until eleventh real shot; directional clicks released after three physics ticks; no supplied poses, projectile requests, ammunition or damage",
		"fixture": "start_run(true); primary dummy 4.5 units away, rear dummy 6.0 units away; range case primary 9.5 units away",
		"raw_frame_count": RAW_COUNT, "raw_fps": 30, "raw_simulation_seconds": RAW_COUNT / 30.0,
		"preview": "all 120 raw frames in uninterrupted chronological order, one natural GIF loop; actual recorded per-frame ammo overlay",
		"physics_context": physics_context, "muzzles": muzzles, "contacts": contacts,
		"physical_weapon_length": 0.72, "projectile_element": "physical", "projectile_damage": 18.0,
		"magazine": magazine_result, "reload_events": reload_events, "reload_samples": reload_samples,
		"directions": directions, "range_expiry": range_result,
		"screenshots": saved, "raw_frames": raw_frames, "raw_states": raw_states, "failures": failures,
	}
	var file := FileAccess.open(output.path_join("capture-manifest.json"), FileAccess.WRITE)
	if file == null: failures.append("could not save manifest")
	else:
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()
	game.queue_free()
	await process_frame
	for failure in failures: printerr("PISTOL CAPTURE FAILED: ", failure)
	print("PISTOL CAPTURE: %d stills + %d native frames; magazine=%s; directions=%s" % [saved.size(), raw_frames.size(), JSON.stringify(magazine_result), JSON.stringify(directions)])
	quit(0 if failures.is_empty() else 1)


func _start_practice(label: String, aim_direction: Vector3, target_distance: float = 4.5, with_rear: bool = true) -> void:
	direction_label = label
	direction = aim_direction
	game.start_run(true)
	game.set_physics_process(false)
	_expect(game.set_weapon_family("pistol"), label + " could not equip pistol")
	game.move_input = Vector2.ZERO
	game.test_aim = Vector3.ZERO
	primary = game.enemies[0]
	primary.position = game.player.position + direction * target_distance
	rear = game.spawn_enemy("dummy", game.player.position + direction * 6.0) if with_rear else null
	primary_min_health = 1000.0
	rear_min_health = 1000.0
	presses = 0
	releases = 0
	for index in range(36): await _tick()


func _point_mouse() -> Vector2:
	var target: Vector3 = game.player.position + direction * 4.0
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


func _direction_shot(label: String, aim_direction: Vector3, start_index: int) -> void:
	await _start_practice(label, aim_direction)
	_mouse(true)
	var flight_captured := false
	var impact_captured := false
	for index in range(150):
		if index == 3: _mouse(false)
		await _tick()
		if not flight_captured and not game.staff_flight.active.is_empty() and game.staff_flight.active[0].travelled >= 1.3:
			await _capture("%02d-%s-bullet" % [start_index, label])
			flight_captured = true
		if not impact_captured and game.hits == 1:
			await _capture("%02d-%s-impact" % [start_index + 1, label])
			impact_captured = true
	_expect(flight_captured and impact_captured, label + " missing flight/impact still")
	directions.append(_result(label, 1))


func _result(label: String, expected_shots: int) -> Dictionary:
	var flight = game.staff_flight
	_expect(flight.shots_fired == expected_shots and flight.resolved.size() == expected_shots and flight.active.is_empty(), label + " shot/resolution count mismatch")
	_expect(game.hits == expected_shots and is_equal_approx(game.total_damage, expected_shots * 18.0), label + " actual hit/damage mismatch")
	_expect(rear_min_health == 1000.0, label + " rear dummy was hit")
	_expect(presses == 1 and releases == 1, label + " did not use exactly one mouse press/release")
	for entry: Dictionary in flight.resolved:
		_expect(entry.reason == "enemy" and entry.element == "physical" and entry.targetid == primary.get_instance_id(), label + " first-target/physical resolution mismatch")
	return {"aim": label, "aim_vector": _vector(game.aim), "mouse_presses": presses, "mouse_releases": releases, "shots": flight.shots_fired, "hits": game.hits, "damage": game.total_damage, "primary_min_health": primary_min_health, "rear_min_health": rear_min_health, "remaining_projectiles": flight.active.size(), "resolved": _resolved_records(), "final_phase": game.motion.sample().phase}


func _range_shot() -> Dictionary:
	await _start_practice("range", Vector3.RIGHT, 9.5, false)
	await _capture("22-range-ready")
	_mouse(true)
	var near_end := false
	var expired := false
	for index in range(180):
		if index == 3: _mouse(false)
		await _tick()
		if not near_end and not game.staff_flight.active.is_empty() and game.staff_flight.active[0].travelled >= 6.5:
			await _capture("23-range-last-flight")
			near_end = true
		if not expired and not game.staff_flight.resolved.is_empty():
			await _capture("24-range-expired")
			expired = true
	var flight = game.staff_flight
	_expect(near_end and expired and flight.shots_fired == 1 and flight.resolved.size() == 1 and game.hits == 0 and game.total_damage == 0.0 and flight.active.is_empty(), "range case did not expire one unhit bullet")
	if flight.resolved.size() == 1:
		_expect(flight.resolved[0].reason == "range" and is_equal_approx(flight.resolved[0].travelled, 7.0) and flight.resolved[0].element == "physical", "range reason/seven-unit distance/physical element mismatch")
	return {"target_distance": 9.5, "target_health": primary.health, "mouse_presses": presses, "mouse_releases": releases, "shots": flight.shots_fired, "hits": game.hits, "damage": game.total_damage, "resolved": _resolved_records()}


func _tick() -> void:
	await physics_frame
	if not _window_is_offscreen():
		printerr("PISTOL CAPTURE FAILED: unsafe native window at physics tick")
		quit(1)
		return
	var in_physics := Engine.is_in_physics_frame()
	var physical_delta: float = game.player.get_physics_process_delta_time()
	physics_context.ticks += 1
	physics_context.min_physics_delta = minf(physics_context.min_physics_delta, physical_delta)
	physics_context.max_physics_delta = maxf(physics_context.max_physics_delta, physical_delta)
	if not in_physics:
		physics_context.outside_physics_ticks += 1
		_expect(false, "capture tick ran outside physics frame")
	if not game.motion.busy: _point_mouse()
	var old_shots: int = game.staff_flight.shots_fired
	var old_hits: int = game.hits
	var was_reloading: bool = game.pistol_magazine.reloading
	var previous_rounds: int = game.pistol_magazine.rounds
	game.tick(STEP)
	var blade: Dictionary = game.avatar.get_blade_points()
	var length: float = blade.grip.distance_to(blade.tip)
	physics_context.min_physical_weapon_length = minf(physics_context.min_physical_weapon_length, length)
	physics_context.max_physical_weapon_length = maxf(physics_context.max_physical_weapon_length, length)
	_expect(absf(length - 0.72) < 0.0001, "pistol physical length changed")
	primary_min_health = minf(primary_min_health, primary.health)
	if is_instance_valid(rear): rear_min_health = minf(rear_min_health, rear.health)
	var pose: Dictionary = game.current_visual_sample()
	if game.staff_flight.shots_fired > old_shots:
		_expect(not game.staff_flight.active.is_empty(), direction_label + " no launch entry for muzzle proof")
		if not game.staff_flight.active.is_empty():
			var entry: Dictionary = game.staff_flight.active.back()
			var bullet: Sprite3D = entry.node.get_node("bullet")
			var core: Vector3 = _texture_world(bullet, Vector2(28, 12))
			var error: float = blade.tip.distance_to(entry.origin)
			var core_error: float = core.distance_to(entry.node.global_position)
			muzzles.append({"aim": direction_label, "shot": game.staff_flight.shots_fired, "origin": _vector(entry.origin), "rendered_tip": _vector(blade.tip), "error_world_units": error, "element": entry.element, "damage": entry.damage, "bullet_center": _vector(entry.node.global_position), "actual_sprite_core": _vector(core), "core_error_world_units": core_error, "motion_phase": pose.phase, "motion_pitch": pose.pitch, "in_physics_frame": in_physics})
			_expect(error < 0.001 and core_error < 0.001 and entry.element == "physical" and entry.damage == 18.0, direction_label + " muzzle/core/physical/damage mismatch")
		if main_case and game.staff_flight.shots_fired == 10: await _capture_once("empty", "05-empty-magazine")
	if game.hits > old_hits:
		contacts.append({"aim": direction_label, "hits": game.hits, "damage": game.total_damage, "primary_health": primary.health, "rear_health": rear.health if is_instance_valid(rear) else -1.0, "in_physics_frame": in_physics, "physics_delta": physical_delta})
		if main_case: await _capture_once("impact", "04-first-impact")
	if main_case:
		if not game.staff_flight.active.is_empty() and game.staff_flight.active[0].travelled >= 1.3:
			if game.staff_flight.shots_fired == 1: await _capture_once("bullet", "03-visible-bullet")
			if game.staff_flight.shots_fired == 11: await _capture_once("post-reload-bullet", "12-post-reload-bullet")
		if not was_reloading and game.pistol_magazine.reloading:
			reload_count += 1
			reload_start_time = game.run_time
			reload_start_tick = physics_context.ticks
			previous_reload_rotation = game.avatar.weapon.rotation.z
			measured_reload_turn = 0.0
			reload_events.append({"event": "start", "tick": physics_context.ticks, "simulation_time": game.run_time, "shots": game.staff_flight.shots_fired, "rounds": game.pistol_magazine.rounds, "reload_elapsed": game.pistol_magazine.elapsed})
			await _capture_once("reload-start", "06-reload-start")
		if game.pistol_magazine.reloading:
			var rotation: float = game.avatar.weapon.rotation.z
			measured_reload_turn += wrapf(rotation - previous_reload_rotation, -PI, PI)
			previous_reload_rotation = rotation
			var expected_grip: Vector3 = game.player.position + direction * 0.48 + Vector3.UP * 0.80
			var actual_hand: Vector3 = _texture_world(game.avatar.weapon, Vector2(10, 18))
			var projected := Vector2(game.camera.global_basis.x.dot(direction), game.camera.global_basis.y.dot(direction))
			var expected_angle: float = projected.angle() + pose.screen_roll
			var hand_error: float = actual_hand.distance_to(expected_grip)
			var rotation_error: float = absf(wrapf(rotation - expected_angle, -PI, PI))
			var progress: float = game.pistol_magazine.progress()
			reload_samples.append({"tick": physics_context.ticks, "simulation_time": game.run_time, "elapsed": game.pistol_magazine.elapsed, "progress": progress, "rounds": game.pistol_magazine.rounds, "shots": game.staff_flight.shots_fired, "sample_screen_roll": pose.screen_roll, "actual_sprite_rotation_z": rotation, "actual_hand": _vector(actual_hand), "expected_hand": _vector(expected_grip), "hand_error_world_units": hand_error, "rotation_error_radians": rotation_error})
			_expect(game.pistol_magazine.rounds == 0 and game.staff_flight.shots_fired == 10, "early rounds or shot during reload")
			_expect(hand_error < 0.001 and rotation_error < 0.001, "actual gun spin moved hand or diverged from reload sample")
			if progress >= 0.25: await _capture_once("quarter", "07-reload-quarter-spin")
			if progress >= 0.50: await _capture_once("half", "08-reload-half-spin")
			if progress >= 0.75: await _capture_once("three-quarter", "09-reload-three-quarter-spin")
		if was_reloading and not game.pistol_magazine.reloading:
			measured_reload_turn += wrapf(game.avatar.weapon.rotation.z - previous_reload_rotation, -PI, PI)
			var duration: float = game.run_time - reload_start_time
			reload_events.append({"event": "refill", "tick": physics_context.ticks, "simulation_time": game.run_time, "duration_world_seconds": duration, "duration_physics_ticks": physics_context.ticks - reload_start_tick, "shots": game.staff_flight.shots_fired, "rounds": game.pistol_magazine.rounds, "previous_rounds": previous_rounds, "reload_elapsed": game.pistol_magazine.elapsed, "actual_measured_turn_radians": measured_reload_turn})
			_expect(absf(duration - 0.5) <= STEP + 0.000001 and previous_rounds == 0 and game.pistol_magazine.rounds == 10, "reload did not refill at half a world-simulation second")
			await _capture_once("refill", "10-magazine-refill")
		if game.staff_flight.shots_fired == 11 and pose.phase == "recovery": await _capture_once("post-reload-recovery", "11-post-reload-recovery")


func _state() -> Dictionary:
	var pose: Dictionary = game.current_visual_sample()
	return {"physics_tick": physics_context.ticks, "simulation_time": game.run_time, "rounds": game.pistol_magazine.rounds, "capacity": game.pistol_magazine.capacity, "reloading": game.pistol_magazine.reloading, "reload_elapsed": game.pistol_magazine.elapsed, "reload_progress": game.pistol_magazine.progress(), "phase": pose.phase, "pitch": pose.pitch, "screen_roll": pose.get("screen_roll", 0.0), "sprite_rotation_z": game.avatar.weapon.rotation.z, "shots": game.staff_flight.shots_fired, "hits": game.hits, "damage": game.total_damage}


func _resolved_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for item: Dictionary in game.staff_flight.resolved:
		var record: Dictionary = item.duplicate()
		record.position = _vector(item.position)
		record["targetid"] = str(item.get("targetid", 0))
		records.append(record)
	return records


func _texture_world(sprite: Sprite3D, point: Vector2) -> Vector3:
	var size := sprite.texture.get_size()
	return sprite.global_transform * (Vector3(point.x - size.x * 0.5 + sprite.offset.x, size.y * 0.5 - point.y + sprite.offset.y, 0.0) * sprite.pixel_size)


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)


func _window_is_offscreen() -> bool:
	return root.unfocusable and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS) and DisplayServer.window_get_position() == Vector2i(20000, 20000)


func _capture_once(key: String, name: String) -> void:
	if marked.has(key): return
	marked[key] = true
	await _capture(name)


func _capture(name: String) -> void:
	var path := output.path_join(name + ".png")
	await _save_frame(path)
	saved.append(path)
	print("PISTOL CAPTURE: ", path)


func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _save_frame(path: String) -> void:
	if not _window_is_offscreen():
		_expect(false, "native capture window lost offscreen/no-focus state")
		return
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(_window_is_offscreen(), "native window moved during frame readback")
	var picture: Image = root.get_texture().get_image()
	_expect(picture != null and not picture.is_empty() and picture.get_size() == Vector2i(1280, 800) and picture.save_png(path) == OK, "could not save full 1280x800 native viewport: " + path)
