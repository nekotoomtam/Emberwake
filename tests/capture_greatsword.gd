extends SceneTree
## Native render evidence driven by physical click input and the normal game tick.
## -- --output=C:/absolute/folder outside this source project.

const STEP := 1.0 / 120.0
var game
var output := ""
var saved: Array[String] = []
var failures: Array[String] = []
var marked: Dictionary = {}
var direction_results: Array[Dictionary] = []
var context_probe := false
var direction_label := "right"
var contacts: Array[Dictionary] = []
var impacts: Dictionary = {}
var physics_context := {"ticks": 0, "outside_physics_ticks": 0, "physics_ticks_per_second": 120, "model_delta": STEP, "min_physics_delta": INF, "max_physics_delta": 0.0}


func _initialize() -> void:
	Engine.physics_ticks_per_second = 120
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif argument == "--context-probe":
			context_probe = true
	call_deferred("_run")


func _run() -> void:
	if output.is_empty() or not output.is_absolute_path():
		printerr("CAPTURE FAILED: supply --output with an absolute folder")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		printerr("CAPTURE FAILED: native renderer required; omit --headless")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output.path_join("combo"))
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	await _capture("01-menu")
	await _start_practice(Vector3.RIGHT)
	await _capture("02-practice")
	_mouse(true)
	await process_frame
	var released := false
	for frame_index in range(90):
		for substep in range(4):
			if game.motion.busy and game.motion.stage == 2 and not released:
				_mouse(false)
				released = true
			await _capture_tick(STEP)
		await _capture_named_phase()
		await _save_frame(output.path_join("combo/combo_%03d.png" % frame_index))
	_mouse(false)
	await _capture("10-combo-complete")
	if game.hits != 3 or not is_equal_approx(game.total_damage, 177.5):
		failures.append("right-facing physical-input combo did not land exactly 45 + 47.5 + 85")
	for name in ["first-windup", "first-sweep", "first-followthrough", "reverse-sweep", "overhead-lift", "slam-impact", "overhead-recovery"]:
		if not marked.has(name):
			failures.append("missing required main-combo pose: " + name)
	var right_result := {"aim": "right", "hits": game.hits, "damage": game.total_damage, "impact": impacts.get("right", {})}
	direction_results.append(right_result)
	await _direction_overhead("left", Vector3.LEFT, 11)
	await _direction_overhead("away", Vector3.FORWARD, 13)
	await _direction_overhead("toward", Vector3.BACK, 15)
	var manifest := {
		"renderer": DisplayServer.get_name(),
		"engine": Engine.get_version_info().string,
		"input": "physical left mouse press, release during third windup; no supplied animation poses or damage",
		"combo_frames": 90,
		"combo_fps": 30,
		"combo_simulation_seconds": 3.0,
		"physics_context": physics_context,
		"contacts": contacts,
		"directional_lift_min_progress": 0.965,
		"screenshots": saved,
		"directions": direction_results,
		"failures": failures,
	}
	var file := FileAccess.open(output.path_join("capture-manifest.json"), FileAccess.WRITE)
	if file == null:
		failures.append("could not save capture manifest")
	else:
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()
	game.queue_free()
	await process_frame
	for failure in failures:
		printerr("CAPTURE FAILED: ", failure)
	print("GREATSWORD CAPTURE: %d stills + 90 native frames; real-hit directions=%s" % [saved.size(), JSON.stringify(direction_results)])
	quit(0 if failures.is_empty() else 1)


func _start_practice(direction: Vector3, label: String = "right") -> void:
	direction_label = label
	game.start_run(true)
	game.set_physics_process(false)
	game.set_weapon_family("greatsword")
	game.move_input = Vector2.ZERO
	game.test_aim = direction
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.kind == "dummy":
			enemy.position = game.player.position + direction * 2.0
	await _capture_tick(STEP)


func _mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = game.camera.unproject_position(game.player.position + game.test_aim * 2.0)
	event.global_position = event.position
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _capture_named_phase() -> void:
	if not game.motion.busy:
		return
	var pose: Dictionary = game.motion.sample()
	var stage: int = game.motion.stage
	if stage == 0 and pose.phase == "windup" and pose.progress >= 0.4:
		await _capture_once("first-windup", "03-first-windup")
	if stage == 0 and pose.phase == "active" and pose.progress >= 0.5:
		await _capture_once("first-sweep", "04-first-sweep")
	if stage == 0 and pose.phase == "recovery" and pose.progress >= 0.3:
		await _capture_once("first-followthrough", "05-first-followthrough")
	if stage == 1 and pose.phase == "active" and pose.progress >= 0.5:
		await _capture_once("reverse-sweep", "06-reverse-sweep")
	if stage == 2 and pose.phase == "windup" and pose.progress >= 0.7:
		await _capture_once("overhead-lift", "07-overhead-lift")
	if stage == 2 and game.hits >= 3:
		await _capture_once("slam-impact", "08-slam-impact")
	if stage == 2 and pose.phase == "recovery" and pose.progress >= 0.4:
		await _capture_once("overhead-recovery", "09-overhead-recovery")


func _capture_once(key: String, name: String) -> void:
	if marked.has(key):
		return
	marked[key] = true
	await _capture(name)


func _direction_overhead(label: String, direction: Vector3, start_index: int) -> void:
	await _start_practice(direction, label)
	_mouse(true)
	await process_frame
	var lifted := false
	var impacted := false
	var released := false
	for index in range(420):
		if game.motion.busy and game.motion.stage == 2:
			if not released:
				_mouse(false)
				released = true
			var pose: Dictionary = game.motion.sample()
			if not lifted and pose.phase == "windup" and pose.progress >= 0.965:
				await _capture("%02d-%s-overhead-lift" % [start_index, label])
				lifted = true
			if not impacted and game.hits >= 3:
				await _capture("%02d-%s-overhead-impact" % [start_index + 1, label])
				impacted = true
				break
		await _capture_tick(STEP)
	_mouse(false)
	direction_results.append({"aim": label, "hits": game.hits, "damage": game.total_damage, "lift_captured": lifted, "impact_captured": impacted, "impact": impacts.get(label, {})})
	if not lifted or not impacted or game.hits != 3 or not is_equal_approx(game.total_damage, 177.5):
		failures.append(label + " overhead evidence did not include its real three-hit combo")


func _capture(name: String) -> void:
	var path := output.path_join(name + ".png")
	await _save_frame(path)
	saved.append(path)
	print("CAPTURE: ", path)


func _capture_tick(delta: float) -> void:
	# CharacterBody3D.move_and_slide uses the engine's current frame delta.
	# Matching its physics context to the model step prevents PNG-write/render
	# latency from turning a fixed model tick into a much larger movement step.
	await physics_frame
	var in_physics: bool = Engine.is_in_physics_frame()
	var physics_delta: float = game.player.get_physics_process_delta_time()
	physics_context.ticks += 1
	physics_context.min_physics_delta = minf(physics_context.min_physics_delta, physics_delta)
	physics_context.max_physics_delta = maxf(physics_context.max_physics_delta, physics_delta)
	if not in_physics:
		physics_context.outside_physics_ticks += 1
		if physics_context.outside_physics_ticks == 1:
			failures.append("capture tick ran outside the physics frame")
	var before: Vector3 = game.player.position
	var before_hits: int = game.hits
	game.tick(delta)
	if game.hits > before_hits:
		var target_position: Vector3 = game.enemies[0].position
		var offset: Vector3 = target_position - game.player.position
		offset.y = 0.0
		var forward: Vector3 = game.test_aim.normalized()
		var contact := {
			"aim": direction_label,
			"stage": game.motion.stage,
			"stage_elapsed": game.motion.elapsed,
			"hits": game.hits,
			"in_physics_frame": in_physics,
			"model_delta": delta,
			"physics_delta": physics_delta,
			"process_delta": game.player.get_process_delta_time(),
			"player_position": _vector(game.player.position),
			"target_position": _vector(target_position),
			"forward_distance": offset.dot(forward),
			"movement_this_tick": _vector(game.player.position - before),
		}
		contacts.append(contact)
		if game.motion.stage == 2:
			impacts[direction_label] = contact
			if contact.forward_distance <= 0.0:
				failures.append(direction_label + " impact target is no longer in front of the player")
	if context_probe and game.motion.stage == 2 and game.motion.elapsed >= 0.30 and game.motion.elapsed <= 0.36:
		print("CAPTURE CONTEXT: ", JSON.stringify({"in_physics_frame": Engine.is_in_physics_frame(), "model_delta": delta, "process_delta": game.player.get_process_delta_time(), "physics_delta": game.player.get_physics_process_delta_time(), "stage_elapsed": game.motion.elapsed, "player": str(game.player.position), "actual_movement": str(game.player.position - before), "hits": game.hits}))


func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _save_frame(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	if picture == null or picture.is_empty() or picture.save_png(path) != OK:
		failures.append("could not save native viewport: " + path)
