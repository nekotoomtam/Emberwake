extends SceneTree
## Native-render evidence from physical input and actual physics-scheduled ticks.
## -- --output=C:/absolute/folder outside this source project.

const STEP := 1.0 / 120.0
var game
var output := ""
var saved: Array[String] = []
var failures: Array[String] = []
var marked: Dictionary = {}
var directions: Array[Dictionary] = []
var contacts: Array[Dictionary] = []
var impacts: Dictionary = {}
var direction_label := "right"
var combo_origin := Vector3.ZERO
var physics_context := {"ticks": 0, "outside_physics_ticks": 0, "physics_ticks_per_second": 120, "model_delta": STEP, "min_physics_delta": INF, "max_physics_delta": 0.0, "min_physical_weapon_length": INF, "max_physical_weapon_length": 0.0}


func _initialize() -> void:
	# Keep hardware input in the user's app; this harness injects its own events.
	root.unfocusable = true
	Engine.physics_ticks_per_second = 120
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	call_deferred("_run")


func _run() -> void:
	if output.is_empty() or not output.is_absolute_path():
		printerr("MACE CAPTURE FAILED: supply --output with an absolute folder")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		printerr("MACE CAPTURE FAILED: native renderer required; omit --headless")
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
			await _tick()
		await _capture_named_phase()
		await _save_frame(output.path_join("combo/combo_%03d.png" % frame_index))
	_mouse(false)
	await _capture("10-combo-complete")
	if game.hits != 3 or not is_equal_approx(game.total_damage, 92.0):
		failures.append("right-facing physical-input combo did not land exactly 34 + 12 + 46")
	for name in ["uppercut-preparation", "uppercut-contact", "uppercut-followthrough", "short-dash-contact", "overhead-lift", "slam-impact", "overhead-recovery"]:
		if not marked.has(name):
			failures.append("missing required main-combo pose: " + name)
	directions.append(_direction_result("right", true, true))
	await _direction_slam("left", Vector3.LEFT, 11)
	await _direction_slam("away", Vector3.FORWARD, 13)
	await _direction_slam("toward", Vector3.BACK, 15)
	if saved.size() != 16:
		failures.append("expected exactly 16 native evidence stills")
	var manifest := {
		"renderer": DisplayServer.get_name(), "engine": Engine.get_version_info().string,
		"input": "physical left mouse press, release during third windup; normal damage, no supplied poses",
		"combo_frames": 90, "combo_fps": 30, "combo_simulation_seconds": 3.0,
		"physics_context": physics_context, "contacts": contacts,
		"dash_maximum_units": 0.75, "target_radius_plus_player_clearance": 0.74,
		"physical_weapon_length": 1.9, "ordinary_sword_contact_reaches": [2.1, 2.2, 2.55],
		"screenshots": saved, "directions": directions, "failures": failures,
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
		printerr("MACE CAPTURE FAILED: ", failure)
	print("MACE CAPTURE: %d stills + 90 native frames; real-hit directions=%s" % [saved.size(), JSON.stringify(directions)])
	quit(0 if failures.is_empty() else 1)


func _dummy():
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.kind == "dummy" and not enemy.dead:
			return enemy
	return null


func _start_practice(direction: Vector3, label: String = "right") -> void:
	direction_label = label
	game.start_run(true)
	game.set_physics_process(false)
	if not game.set_weapon_family("mace"):
		failures.append("practice cannot equip Mace")
	game.move_input = Vector2.ZERO
	game.test_aim = direction
	# Keep the actual ordinary practice spacing: short dash closes this gap.
	_dummy().position = game.player.position + direction * 2.0
	combo_origin = game.player.position
	await _tick()


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
		await _capture_once("uppercut-preparation", "03-uppercut-preparation")
	if stage == 0 and game.hits >= 1:
		await _capture_once("uppercut-contact", "04-uppercut-contact")
	if stage == 0 and pose.phase == "recovery" and pose.progress >= 0.3:
		await _capture_once("uppercut-followthrough", "05-uppercut-followthrough")
	if stage == 1 and game.hits >= 2:
		await _capture_once("short-dash-contact", "06-short-dash-contact")
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


func _direction_slam(label: String, direction: Vector3, start_index: int) -> void:
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
		await _tick()
	_mouse(false)
	directions.append(_direction_result(label, lifted, impacted))
	if not lifted or not impacted or game.hits != 3 or not is_equal_approx(game.total_damage, 92.0):
		failures.append(label + " overhead evidence did not include its real three-hit combo")


func _direction_result(label: String, lifted: bool, impacted: bool) -> Dictionary:
	var displacement: Vector3 = game.player.position - combo_origin
	displacement.y = 0.0
	if game.mace_dash_travelled > 0.7501 or displacement.length() > 0.7501:
		failures.append(label + " combo exceeded short-dash maximum travel")
	if game.mace_dash_travelled < 0.749 or displacement.length() < 0.749:
		failures.append(label + " ordinary practice combo did not complete its .75-unit short dash")
	return {"aim": label, "hits": game.hits, "damage": game.total_damage, "lift_captured": lifted, "impact_captured": impacted, "actual_dash_travel": game.mace_dash_travelled, "combo_ground_displacement": displacement.length(), "player_position": _vector(game.player.position), "target_position": _vector(_dummy().position), "impact": impacts.get(label, {})}


func _tick() -> void:
	# move_and_slide consumes engine frame delta; always enter actual physics first.
	await physics_frame
	var in_physics: bool = Engine.is_in_physics_frame()
	var physical_delta: float = game.player.get_physics_process_delta_time()
	physics_context.ticks += 1
	physics_context.min_physics_delta = minf(physics_context.min_physics_delta, physical_delta)
	physics_context.max_physics_delta = maxf(physics_context.max_physics_delta, physical_delta)
	if not in_physics:
		physics_context.outside_physics_ticks += 1
		if physics_context.outside_physics_ticks == 1:
			failures.append("capture tick ran outside the physics frame")
	var before: Vector3 = game.player.position
	var before_hits: int = game.hits
	game.tick(STEP)
	var blade: Dictionary = game.avatar.get_blade_points()
	var physical_length: float = blade.grip.distance_to(blade.tip)
	physics_context.min_physical_weapon_length = minf(physics_context.min_physical_weapon_length, physical_length)
	physics_context.max_physical_weapon_length = maxf(physics_context.max_physical_weapon_length, physical_length)
	if absf(physical_length - 1.9) > 0.0001 and not failures.has("native weapon changes its rigid 1.90-unit physical length"):
		failures.append("native weapon changes its rigid 1.90-unit physical length")
	if game.hits > before_hits:
		var target_position: Vector3 = _dummy().position
		var offset: Vector3 = target_position - game.player.position
		offset.y = 0.0
		var forward: Vector3 = game.test_aim.normalized()
		var contact := {"aim": direction_label, "stage": game.motion.stage, "stage_elapsed": game.motion.elapsed, "hits": game.hits, "total_damage": game.total_damage, "in_physics_frame": in_physics, "model_delta": STEP, "physics_delta": physical_delta, "process_delta": game.player.get_process_delta_time(), "player_position": _vector(game.player.position), "target_position": _vector(target_position), "forward_distance": offset.dot(forward), "movement_this_tick": _vector(game.player.position - before), "actual_dash_travel": game.mace_dash_travelled, "physical_weapon_length": physical_length, "weapon_grip": _vector(blade.grip), "weapon_tip": _vector(blade.tip), "rendered_tip_forward_projection": (blade.tip - game.player.position).dot(forward)}
		contacts.append(contact)
		if contact.forward_distance < 0.735:
			failures.append(direction_label + " contact crosses the target clearance")
		if game.motion.stage == 2:
			impacts[direction_label] = contact


func _capture(name: String) -> void:
	var path := output.path_join(name + ".png")
	await _save_frame(path)
	saved.append(path)
	print("MACE CAPTURE: ", path)


func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _save_frame(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	if picture == null or picture.is_empty() or picture.save_png(path) != OK:
		failures.append("could not save native viewport: " + path)
