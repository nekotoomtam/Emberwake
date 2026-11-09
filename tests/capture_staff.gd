extends SceneTree
## Actual native-render evidence from mouse events and physics-scheduled ticks.
## Launch --minimized --position 20000,20000 and -- --output=<absolute folder>.

const STEP := 1.0 / 120.0
var game
var output := ""
var saved: Array[String] = []
var raw_frames: Array[String] = []
var failures: Array[String] = []
var marked: Dictionary = {}
var directions: Array[Dictionary] = []
var muzzles: Array[Dictionary] = []
var contacts: Array[Dictionary] = []
var direction_label := "right"
var direction := Vector3.RIGHT
var primary
var rear
var main_case := false
var impact_health := -1.0
var impact_tick := -1
var rear_min_health := 1000.0
var presses := 0
var releases := 0
var physics_context := {"ticks": 0, "outside_physics_ticks": 0, "physics_ticks_per_second": 120, "model_delta": STEP, "min_physics_delta": INF, "max_physics_delta": 0.0, "min_physical_weapon_length": INF, "max_physical_weapon_length": 0.0}


func _initialize() -> void:
	root.unfocusable = true
	Engine.physics_ticks_per_second = 120
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	call_deferred("_run")


func _run() -> void:
	if output.is_empty() or not output.is_absolute_path():
		printerr("STAFF CAPTURE FAILED: supply an absolute --output folder")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		printerr("STAFF CAPTURE FAILED: native renderer required")
		quit(1)
		return
	# Startup placement may be clamped by the engine. Start minimized, then set
	# native no-focus and offscreen placement after its startup window is ready.
	root.unfocusable = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_position(Vector2i(20000, 20000))
	await process_frame
	if not _window_is_offscreen():
		printerr("STAFF CAPTURE FAILED: native window must remain unfocusable at 20000,20000")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output.path_join("shot"))
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	if not _window_is_offscreen():
		printerr("STAFF CAPTURE FAILED: initialization reset safe native window state")
		quit(1)
		return
	if game.weapon_family != "sword": failures.append("initial menu did not default to ordinary sword")
	await _capture("01-menu")
	await _start_practice("right", Vector3.RIGHT)
	main_case = true
	await _capture("02-ready")
	_mouse(true)
	for frame_index in range(90):
		for substep in range(4):
			if frame_index == 0 and substep == 3: _mouse(false)
			await _tick()
		var frame_path := output.path_join("shot/shot_%03d.png" % frame_index)
		await _save_frame(frame_path)
		raw_frames.append(frame_path)
	await _capture("08-single-shot-idle")
	main_case = false
	directions.append(_direction_result("right"))
	for key in ["windup", "release", "midflight", "impact", "rear"]:
		if not marked.has(key): failures.append("missing right-facing evidence: " + key)
	await _direction_shot("left", Vector3.LEFT, 9)
	await _direction_shot("away", Vector3.FORWARD, 11)
	await _direction_shot("toward", Vector3.BACK, 13)
	var range_result: Dictionary = await _range_shot()
	if saved.size() != 17: failures.append("expected 17 full-resolution native stills")
	if raw_frames.size() != 90: failures.append("expected 90 contiguous 30-fps raw frames")
	var manifest := {
		"renderer": DisplayServer.get_name(), "engine": Engine.get_version_info().string,
		"native_window": {"unfocusable": root.unfocusable, "native_no_focus_flag": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS), "requested_position": [20000, 20000], "actual_position": [DisplayServer.window_get_position().x, DisplayServer.window_get_position().y]},
		"input": "Viewport.push_input mouse motion and left mouse press/release; early release after 3 physics ticks; no supplied poses, projectile requests or damage",
		"fixture": "start_run(true), one primary dummy 5.4 units away, rear dummy 6.8 units away; range case primary 8.6 units away",
		"raw_frame_count": 90, "raw_fps": 30, "raw_simulation_seconds": 3.0,
		"preview": "contiguous initial 42 raw frames, natural GIF loop, final pause; one physical click and one fireball",
		"physics_context": physics_context, "muzzles": muzzles, "contacts": contacts,
		"physical_weapon_length": 1.45, "fire_element": "fire",
		"directions": directions, "range_expiry": range_result,
		"screenshots": saved, "raw_frames": raw_frames, "failures": failures,
	}
	var file := FileAccess.open(output.path_join("capture-manifest.json"), FileAccess.WRITE)
	if file == null:
		failures.append("could not save capture manifest")
	else:
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()
	game.queue_free()
	await process_frame
	for failure in failures: printerr("STAFF CAPTURE FAILED: ", failure)
	print("STAFF CAPTURE: %d stills + %d native frames; directions=%s; range=%s" % [saved.size(), raw_frames.size(), JSON.stringify(directions), JSON.stringify(range_result)])
	quit(0 if failures.is_empty() else 1)


func _start_practice(label: String, aim_direction: Vector3, target_distance: float = 5.4, with_rear: bool = true) -> void:
	direction_label = label
	direction = aim_direction
	game.start_run(true)
	game.set_physics_process(false)
	if not game.set_weapon_family("staff"): failures.append(label + " cannot equip staff")
	game.move_input = Vector2.ZERO
	game.test_aim = Vector3.ZERO
	primary = game.enemies[0]
	primary.position = game.player.position + direction * target_distance
	rear = game.spawn_enemy("dummy", game.player.position + direction * 6.8) if with_rear else null
	impact_health = -1.0
	impact_tick = -1
	rear_min_health = 1000.0
	presses = 0
	releases = 0
	for index in range(36): await _tick()


func _point_mouse() -> Vector2:
	var target: Vector3 = game.player.position + direction * 4.0
	target.y = 0.0
	var point: Vector2 = game.camera.unproject_position(target)
	var motion_event := InputEventMouseMotion.new()
	motion_event.position = point
	motion_event.global_position = point
	root.push_input(motion_event, true)
	return point


func _window_is_offscreen() -> bool:
	return root.unfocusable and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS) and DisplayServer.window_get_position() == Vector2i(20000, 20000)


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
	var midflight := false
	var impact := false
	for index in range(150):
		if index == 3: _mouse(false)
		await _tick()
		if not midflight and not game.staff_flight.active.is_empty() and game.staff_flight.active[0].travelled >= 1.3:
			await _capture("%02d-%s-midflight" % [start_index, label])
			midflight = true
		if not impact and game.hits == 1:
			await _capture("%02d-%s-impact" % [start_index + 1, label])
			impact = true
		if impact and index >= 120: break
	if not midflight or not impact: failures.append(label + " missing midflight/impact capture")
	directions.append(_direction_result(label))


func _direction_result(label: String) -> Dictionary:
	var flight = game.staff_flight
	if flight.shots_fired != 1 or flight.resolved.size() != 1 or not flight.active.is_empty():
		failures.append(label + " did not resolve exactly one projectile")
	if game.hits != 1 or not is_equal_approx(game.total_damage, 24.0) or not is_equal_approx(impact_health, 976.0):
		failures.append(label + " did not land exactly one real 24-damage hit")
	if rear_min_health < 1000.0: failures.append(label + " projectile pierced its first target")
	if presses != 1 or releases != 1: failures.append(label + " did not use one mouse press/release")
	if flight.resolved.size() == 1:
		if flight.resolved[0].reason != "enemy" or flight.resolved[0].element != "fire" or flight.resolved[0].targetid != primary.get_instance_id():
			failures.append(label + " first-target/fire resolution mismatch")
	return {"aim": label, "aim_vector": _vector(game.aim), "mouse_presses": presses, "mouse_releases": releases, "shots": flight.shots_fired, "hits": game.hits, "damage": game.total_damage, "primary_health_at_impact": impact_health, "rear_min_health": rear_min_health, "rear_final_health": rear.health, "remaining_projectiles": flight.active.size(), "resolved": _resolved_records(), "final_phase": game.motion.sample().phase}


func _range_shot() -> Dictionary:
	await _start_practice("range", Vector3.RIGHT, 8.6, false)
	await _capture("15-range-ready")
	_mouse(true)
	var near_end := false
	var expired := false
	for index in range(180):
		if index == 3: _mouse(false)
		await _tick()
		if not near_end and not game.staff_flight.active.is_empty() and game.staff_flight.active[0].travelled >= 5.7:
			await _capture("16-range-last-flight")
			near_end = true
		if not expired and not game.staff_flight.resolved.is_empty():
			await _capture("17-range-expired")
			expired = true
		if expired and index >= 150: break
	var flight = game.staff_flight
	if not near_end or not expired or flight.shots_fired != 1 or flight.resolved.size() != 1 or game.hits != 0 or game.total_damage != 0 or not flight.active.is_empty():
		failures.append("range scenario did not expire one unhit projectile")
	if flight.resolved.size() == 1 and (flight.resolved[0].reason != "range" or not is_equal_approx(flight.resolved[0].travelled, 6.0) or flight.resolved[0].element != "fire"):
		failures.append("range scenario reason, six-unit distance or fire element mismatch")
	return {"target_distance": 8.6, "target_health": primary.health, "mouse_presses": presses, "mouse_releases": releases, "shots": flight.shots_fired, "hits": game.hits, "damage": game.total_damage, "remaining_projectiles": flight.active.size(), "resolved": _resolved_records(), "last_flight_captured": near_end, "expiry_captured": expired}


func _resolved_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for item: Dictionary in game.staff_flight.resolved:
		var record: Dictionary = item.duplicate()
		record.position = _vector(item.position)
		records.append(record)
	return records


func _tick() -> void:
	await physics_frame
	if not _window_is_offscreen():
		printerr("STAFF CAPTURE FAILED: native window lost its safe offscreen state")
		quit(1)
		return
	var in_physics := Engine.is_in_physics_frame()
	var physical_delta: float = game.player.get_physics_process_delta_time()
	physics_context.ticks += 1
	physics_context.min_physics_delta = minf(physics_context.min_physics_delta, physical_delta)
	physics_context.max_physics_delta = maxf(physics_context.max_physics_delta, physical_delta)
	if not in_physics:
		physics_context.outside_physics_ticks += 1
		if physics_context.outside_physics_ticks == 1: failures.append("capture tick ran outside the physics frame")
	if not game.motion.busy: _point_mouse()
	var old_shots: int = game.staff_flight.shots_fired
	var old_hits: int = game.hits
	game.tick(STEP)
	var blade: Dictionary = game.avatar.get_blade_points()
	var length: float = blade.grip.distance_to(blade.tip)
	physics_context.min_physical_weapon_length = minf(physics_context.min_physical_weapon_length, length)
	physics_context.max_physical_weapon_length = maxf(physics_context.max_physical_weapon_length, length)
	if absf(length - 1.45) > 0.0001 and not failures.has("staff physical length changed"):
		failures.append("staff physical length changed")
	if is_instance_valid(rear): rear_min_health = minf(rear_min_health, rear.health)
	if game.staff_flight.shots_fired > old_shots:
		if game.staff_flight.active.is_empty(): failures.append(direction_label + " no launch entry available for muzzle proof")
		else:
			var entry: Dictionary = game.staff_flight.active[0]
			var error: float = blade.tip.distance_to(entry.origin)
			muzzles.append({"aim": direction_label, "origin": _vector(entry.origin), "rendered_tip": _vector(blade.tip), "error_world_units": error, "element": entry.element, "damage": entry.damage, "motion_phase": game.motion.sample().phase, "motion_elapsed": game.motion.elapsed, "in_physics_frame": in_physics})
			if error > 0.001 or entry.element != "fire" or entry.damage != 24.0: failures.append(direction_label + " muzzle origin/fire/damage mismatch")
		if main_case: await _capture_once("release", "04-release")
	if game.hits > old_hits:
		impact_health = primary.health
		impact_tick = physics_context.ticks
		contacts.append({"aim": direction_label, "hits": game.hits, "damage": game.total_damage, "primary_health": primary.health, "rear_health": rear.health if is_instance_valid(rear) else -1.0, "remaining_projectiles": game.staff_flight.active.size(), "in_physics_frame": in_physics, "physics_delta": physical_delta, "motion_phase": game.motion.sample().phase})
		if main_case: await _capture_once("impact", "06-impact")
	if main_case:
		var pose: Dictionary = game.motion.sample()
		if pose.phase == "windup" and pose.progress >= 0.4: await _capture_once("windup", "03-windup")
		if not game.staff_flight.active.is_empty() and game.staff_flight.active[0].travelled >= 1.3: await _capture_once("midflight", "05-midflight")
		if game.hits == 1 and marked.has("impact") and physics_context.ticks >= impact_tick + 8: await _capture_once("rear", "07-rear-target-unharmed")


func _capture_once(key: String, name: String) -> void:
	if marked.has(key): return
	marked[key] = true
	await _capture(name)


func _capture(name: String) -> void:
	var path := output.path_join(name + ".png")
	await _save_frame(path)
	saved.append(path)
	print("STAFF CAPTURE: ", path)


func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _save_frame(path: String) -> void:
	if not _window_is_offscreen():
		failures.append("native capture window lost offscreen/no-focus state")
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	if picture == null or picture.is_empty() or picture.get_size() != Vector2i(1280, 800) or picture.save_png(path) != OK:
		failures.append("could not save full 1280x800 native viewport: " + path)
