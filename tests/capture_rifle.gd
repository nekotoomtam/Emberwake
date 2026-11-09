extends SceneTree
## Native actual-input proof. Never inject poses, projectiles, ammo or damage.
## Launch hidden: --minimized --position 20000,20000 -- --output=<absolute folder>.

const STEP := 1.0 / 120.0
const RAW_COUNT := 180
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
var cutoff_samples: Array[Dictionary] = []
var casing_samples: Array[Dictionary] = []
var reload_samples: Array[Dictionary] = []
var reload_events: Array[Dictionary] = []
var direction_label := "right"
var direction := Vector3.RIGHT
var primary
var nearby
var far_target
var initial_player := Vector3.ZERO
var main_case := false
var safety_ready := false
var primary_min_health := 1000.0
var near_min_health := 1000.0
var far_min_health := 1000.0
var presses := 0
var releases := 0
var reload_count := 0
var reload_start_time := -1.0
var reload_start_tick := -1
var min_reload_pitch := INF
var max_reload_pitch := -INF
var max_reload_screen_roll := 0.0
var physics_context := {"ticks": 0, "outside_physics_ticks": 0, "physics_ticks_per_second": 120, "model_delta": STEP, "min_physics_delta": INF, "max_physics_delta": 0.0, "min_physical_weapon_length": INF, "max_physical_weapon_length": 0.0}


func _initialize() -> void:
	root.unfocusable = true
	Engine.physics_ticks_per_second = 120
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	call_deferred("_run")


func _process(_delta: float) -> bool:
	if safety_ready and not _window_is_offscreen():
		printerr("RIFLE CAPTURE FAILED: native window lost offscreen/no-focus state")
		quit(1)
	return false


func _run() -> void:
	if output.is_empty() or not output.is_absolute_path() or DisplayServer.get_name() == "headless":
		printerr("RIFLE CAPTURE FAILED: native renderer and absolute --output folder required")
		quit(1)
		return
	root.unfocusable = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_position(Vector2i(20000, 20000))
	safety_ready = true
	await process_frame
	if not _window_is_offscreen():
		printerr("RIFLE CAPTURE FAILED: safe native window setup failed")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output.path_join("shot"))
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	if not _window_is_offscreen():
		printerr("RIFLE CAPTURE FAILED: initialization reset safe window state")
		quit(1)
		return
	_expect(game.weapon_family == "sword", "initial menu did not default to ordinary sword")
	await _capture("01-menu")
	await _start_practice("right", Vector3.RIGHT, true)
	main_case = true
	await _capture("02-ready-five-rounds")
	var timeline_start: float = game.run_time
	_mouse(true)
	for frame_index in range(RAW_COUNT):
		for substep in range(4):
			await _tick()
			if game.staff_flight.shots_fired == 6 and releases == 0: _mouse(false)
		var frame_path := output.path_join("shot/shot_%03d.png" % frame_index)
		await _save_frame(frame_path)
		raw_frames.append(frame_path)
		var state := _state()
		state.frame_index = frame_index
		state.timeline_seconds = game.run_time - timeline_start
		raw_states.append(state)
	await _capture("16-post-reload-idle")
	var magazine_result := _result("right-six-shot-magazine", 6, 2)
	magazine_result.reload_count = reload_count
	magazine_result.final_rounds = game.rifle_magazine.rounds
	magazine_result.reload_pitch_range = [min_reload_pitch, max_reload_pitch]
	magazine_result.max_reload_screen_roll = max_reload_screen_roll
	_expect(reload_count == 1, "six shots did not use exactly one automatic reload")
	_expect(game.rifle_magazine.rounds == 4 and not game.rifle_magazine.reloading, "sixth shot did not leave four rounds")
	_expect(absf(magazine_result.actual_backward_travel - 1.32) < .003, "six shots did not move the player backward 1.32 units")
	for key in ["fire", "bullet", "first-pierce", "near-hit", "far-unharmed", "casing", "stepback", "empty", "reload-start", "reload-mid", "refill", "sixth"]:
		_expect(marked.has(key), "missing native still: " + key)
	main_case = false
	await _direction_shot("right", Vector3.RIGHT, 17)
	await _direction_shot("left", Vector3.LEFT, 19)
	await _direction_shot("away", Vector3.FORWARD, 21)
	await _direction_shot("toward", Vector3.BACK, 23)
	_expect(raw_frames.size() == RAW_COUNT, "expected 180 contiguous native 30-fps frames")
	_expect(physics_context.outside_physics_ticks == 0, "some ticks ran outside real physics")
	var manifest := {
		"renderer": DisplayServer.get_name(), "engine": Engine.get_version_info().string,
		"native_window": {"unfocusable": root.unfocusable, "native_no_focus_flag": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS), "requested_position": [20000, 20000], "actual_position": [DisplayServer.window_get_position().x, DisplayServer.window_get_position().y], "checked_every_frame_and_tick": true},
		"input": "Viewport.push_input mouse motion and left mouse press/hold/release; main press held until sixth real shot; each directional click released after three real physics ticks; no supplied poses, projectile requests, ammunition or damage",
		"fixture": "start_run(true); fixed world first dummy x=4.0, near dummy x=5.0, separated far dummy x=7.0; four aim fixtures contain one dummy four units along aim",
		"raw_frame_count": RAW_COUNT, "raw_fps": 30, "raw_simulation_seconds": RAW_COUNT / 30.0,
		"preview": "all 180 raw frames in uninterrupted chronological order, one natural GIF loop; actual recorded ammo/reload/recoil/casings overlay",
		"physics_context": physics_context, "muzzles": muzzles, "contacts": contacts,
		"physical_weapon_length": 1.35, "projectile_element": "physical", "projectile_damage": 49.5, "original_range": 9.0, "pierce_after_first_exit": .55,
		"magazine": magazine_result, "reload_events": reload_events, "reload_samples": reload_samples,
		"cutoff_samples": cutoff_samples, "casing_samples": casing_samples, "casing_max_active": game.casing_fx.MAX_ACTIVE, "casing_lifetime": game.casing_fx.LIFETIME,
		"directions": directions, "screenshots": saved, "raw_frames": raw_frames, "raw_states": raw_states, "failures": failures,
	}
	var file := FileAccess.open(output.path_join("capture-manifest.json"), FileAccess.WRITE)
	if file == null: failures.append("could not save manifest")
	else:
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()
	game.queue_free()
	await process_frame
	for failure in failures: printerr("RIFLE CAPTURE FAILED: ", failure)
	print("RIFLE CAPTURE: %d stills + %d native frames; magazine=%s; directions=%s" % [saved.size(), raw_frames.size(), JSON.stringify(magazine_result), JSON.stringify(directions)])
	quit(0 if failures.is_empty() else 1)


func _start_practice(label: String, aim_direction: Vector3, with_pair: bool) -> void:
	direction_label = label
	direction = aim_direction
	game.start_run(true)
	game.set_physics_process(false)
	_expect(game.set_weapon_family("rifle"), label + " could not equip rifle")
	game.move_input = Vector2.ZERO
	game.test_aim = Vector3.ZERO
	primary = game.enemies[0]
	primary.position = game.player.position + direction * 4.0
	nearby = game.spawn_enemy("dummy", game.player.position + direction * 5.0) if with_pair else null
	far_target = game.spawn_enemy("dummy", game.player.position + direction * 7.0) if with_pair else null
	if with_pair: game.enemies = [far_target, nearby, primary]
	primary_min_health = 1000.0
	near_min_health = 1000.0
	far_min_health = 1000.0
	presses = 0
	releases = 0
	for index in range(36): await _tick()
	initial_player = game.player.position


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
	await _start_practice(label, aim_direction, false)
	_mouse(true)
	var flight_captured := false
	var impact_captured := false
	for index in range(120):
		if index == 3: _mouse(false)
		await _tick()
		if not flight_captured and not game.staff_flight.active.is_empty() and game.staff_flight.active[0].travelled >= .9:
			await _capture("%02d-%s-bullet" % [start_index, label])
			flight_captured = true
		if not impact_captured and game.hits == 1 and not game.motion.busy:
			await _capture("%02d-%s-stepback-impact" % [start_index + 1, label])
			impact_captured = true
	_expect(flight_captured and impact_captured, label + " missing flight/impact still")
	directions.append(_result(label, 1, 1))


func _result(label: String, expected_shots: int, hits_per_shot: int) -> Dictionary:
	var flight = game.staff_flight
	_expect(flight.shots_fired == expected_shots and flight.resolved.size() == expected_shots and flight.active.is_empty(), label + " shot/resolution count mismatch")
	_expect(game.hits == expected_shots * hits_per_shot and is_equal_approx(game.total_damage, expected_shots * hits_per_shot * 49.5), label + " actual hit/damage mismatch")
	_expect(far_min_health == 1000.0, label + " separated far dummy was hit")
	_expect(presses == 1 and releases == 1, label + " did not use exactly one mouse press/release")
	_expect(game.casing_fx.spawned_count == expected_shots, label + " did not eject exactly one casing per shot")
	var displacement: Vector3 = game.player.position - initial_player
	var ground_displacement := Vector3(displacement.x, 0.0, displacement.z)
	_expect(ground_displacement.distance_to(-direction * .22 * expected_shots) < .003, label + " actual backward displacement mismatch")
	for entry: Dictionary in flight.resolved:
		_expect(entry.reason == "pierce_limit" and entry.element == "physical" and entry.hitids.size() == hits_per_shot and entry.hitids[0] == primary.get_instance_id(), label + " first target / physical / short pierce resolution mismatch")
		if hits_per_shot == 2: _expect(entry.hitids[1] == nearby.get_instance_id(), label + " near target missing from fixed cutoff")
		_expect(entry.cutoff_position.distance_to(entry.first_exit_position + direction * .55) < .001, label + " cutoff was not fixed .55 after first exit")
	return {"aim": label, "aim_vector": _vector(game.aim), "mouse_presses": presses, "mouse_releases": releases, "shots": flight.shots_fired, "hits": game.hits, "damage": game.total_damage, "primary_min_health": primary_min_health, "near_min_health": near_min_health, "far_min_health": far_min_health, "casings_spawned": game.casing_fx.spawned_count, "actual_displacement": _vector(displacement), "actual_backward_travel": -displacement.dot(direction), "last_shot_reported_recoil": game.rifle_recoil_travelled, "remaining_projectiles": flight.active.size(), "resolved": _resolved_records(), "final_phase": game.motion.sample().phase}


func _tick() -> void:
	await physics_frame
	if not _window_is_offscreen():
		printerr("RIFLE CAPTURE FAILED: unsafe native window at physics tick")
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
	_expect(absf(physical_delta - STEP) < .000001 and Engine.physics_ticks_per_second == 120, "native tick was not at 120 Hz")
	if not game.motion.busy: _point_mouse()
	var old_shots: int = game.staff_flight.shots_fired
	var old_hits: int = game.hits
	var was_reloading: bool = game.rifle_magazine.reloading
	var previous_rounds: int = game.rifle_magazine.rounds
	game.tick(STEP)
	var blade: Dictionary = game.avatar.get_blade_points()
	var length: float = blade.grip.distance_to(blade.tip)
	physics_context.min_physical_weapon_length = minf(physics_context.min_physical_weapon_length, length)
	physics_context.max_physical_weapon_length = maxf(physics_context.max_physical_weapon_length, length)
	_expect(absf(length - 1.35) < .0001, "rifle physical length changed")
	primary_min_health = minf(primary_min_health, primary.health)
	if is_instance_valid(nearby): near_min_health = minf(near_min_health, nearby.health)
	if is_instance_valid(far_target): far_min_health = minf(far_min_health, far_target.health)
	var pose: Dictionary = game.current_visual_sample()
	_expect(game.active_magazine() == game.rifle_magazine, "active rifle magazine changed")
	_expect(game.casing_fx.active.size() <= game.casing_fx.MAX_ACTIVE, "casing active count exceeded finite bound")
	if game.staff_flight.shots_fired > old_shots:
		_expect(not game.staff_flight.active.is_empty(), direction_label + " no launch entry for muzzle proof")
		if not game.staff_flight.active.is_empty():
			var entry: Dictionary = game.staff_flight.active.back()
			var bullet: Sprite3D = entry.node.get_node("bullet")
			var core: Vector3 = _texture_world(bullet, Vector2(28, 12))
			var error: float = blade.tip.distance_to(entry.origin)
			var core_error: float = core.distance_to(entry.node.global_position)
			muzzles.append({"aim": direction_label, "main_case": main_case, "shot": game.staff_flight.shots_fired, "origin": _vector(entry.origin), "rendered_tip": _vector(blade.tip), "error_world_units": error, "element": entry.element, "damage": entry.damage, "original_range": entry.max_range, "bullet_center": _vector(entry.node.global_position), "actual_sprite_core": _vector(core), "core_error_world_units": core_error, "motion_phase": pose.phase, "motion_pitch": pose.pitch, "in_physics_frame": in_physics})
			_expect(error < .001 and core_error < .001 and entry.element == "physical" and entry.damage == 49.5 and entry.max_range == 9.0, direction_label + " muzzle/core/physical/damage/range mismatch")
		if main_case:
			await _capture_once("fire", "03-first-fire")
			if game.staff_flight.shots_fired == 5: await _capture_once("empty", "10-empty-five-cases-spawned")
			if game.staff_flight.shots_fired == 6: await _capture_once("sixth", "15-sixth-shot-four-rounds")
	if game.hits > old_hits:
		contacts.append({"aim": direction_label, "main_case": main_case, "hits": game.hits, "damage": game.total_damage, "primary_health": primary.health, "near_health": nearby.health if is_instance_valid(nearby) else -1.0, "far_health": far_target.health if is_instance_valid(far_target) else -1.0, "in_physics_frame": in_physics, "physics_delta": physical_delta})
		if main_case and game.hits == 1: await _capture_once("first-pierce", "05-first-target-pierced")
		if main_case and game.hits == 2: await _capture_once("near-hit", "06-near-target-hit-99-total")
	for entry: Dictionary in game.staff_flight.active:
		if entry.pierce_started:
			var cutoff_error: float = entry.cutoff_position.distance_to(entry.first_exit_position + direction * .55)
			cutoff_samples.append({"aim": direction_label, "main_case": main_case, "shot": game.staff_flight.shots_fired, "hit_count": entry.hitids.size(), "pierce_cutoff": entry.pierce_cutoff, "cutoff_position": _vector(entry.cutoff_position), "first_exit_position": _vector(entry.first_exit_position), "fixed_world_cutoff_error": cutoff_error, "original_range": entry.max_range})
			_expect(cutoff_error < .001, "subsequent hit moved the first-target cutoff")
	for entry: Dictionary in game.casing_fx.active:
		_expect(is_instance_valid(entry.sprite) and entry.sprite is Sprite3D and entry.age < game.casing_fx.LIFETIME, "invalid/unbounded actual casing sprite")
		if main_case and game.staff_flight.shots_fired == 1 and entry.age >= .40 and not marked.has("casing"):
			casing_samples.append({"shot": 1, "age": entry.age, "actual_sprite_position": _vector(entry.sprite.global_position), "screen_position": _vector2(game.camera.unproject_position(entry.sprite.global_position)), "texture_size": _vector2(entry.sprite.texture.get_size()), "alpha": entry.sprite.modulate.a, "pixel_size": entry.sprite.pixel_size, "velocity": _vector(entry.velocity)})
			await _capture_once("casing", "08-visible-ejected-brass")
	if main_case:
		if not game.staff_flight.active.is_empty() and game.staff_flight.shots_fired == 1 and game.staff_flight.active[0].travelled >= .9: await _capture_once("bullet", "04-visible-native-bullet")
		if game.hits == 2 and game.staff_flight.active.is_empty(): await _capture_once("far-unharmed", "07-fixed-cutoff-far-unharmed")
		if game.staff_flight.shots_fired == 1 and game.rifle_recoil_travelled >= .219: await _capture_once("stepback", "09-first-actual-backward-step")
		if not was_reloading and game.rifle_magazine.reloading:
			reload_count += 1
			reload_start_time = game.run_time
			reload_start_tick = physics_context.ticks
			reload_events.append({"event": "start", "tick": physics_context.ticks, "simulation_time": game.run_time, "shots": game.staff_flight.shots_fired, "rounds": game.rifle_magazine.rounds, "reload_elapsed": game.rifle_magazine.elapsed})
			await _capture_once("reload-start", "11-long-reload-start")
		if game.rifle_magazine.reloading:
			min_reload_pitch = minf(min_reload_pitch, pose.pitch)
			max_reload_pitch = maxf(max_reload_pitch, pose.pitch)
			max_reload_screen_roll = maxf(max_reload_screen_roll, absf(pose.get("screen_roll", 0.0)))
			reload_samples.append({"tick": physics_context.ticks, "progress": game.rifle_magazine.progress(), "rounds": game.rifle_magazine.rounds, "shots": game.staff_flight.shots_fired, "pitch": pose.pitch, "screen_roll": pose.get("screen_roll", 0.0), "actual_sprite_rotation_z": game.avatar.weapon.rotation.z, "physical_length": length, "in_physics_frame": in_physics})
			_expect(game.rifle_magazine.rounds == 0 and game.staff_flight.shots_fired == 5 and absf(pose.get("screen_roll", 0.0)) < .001, "rifle reload ammo/shot/no-spin mismatch")
			if game.rifle_magazine.progress() >= .5: await _capture_once("reload-mid", "12-long-reload-mid-tilt")
			if game.rifle_magazine.progress() >= .9: await _capture_once("reload-late", "13-long-reload-late")
		if was_reloading and not game.rifle_magazine.reloading:
			var duration: float = game.run_time - reload_start_time
			reload_events.append({"event": "refill", "tick": physics_context.ticks, "simulation_time": game.run_time, "duration_world_seconds": duration, "duration_physics_ticks": physics_context.ticks - reload_start_tick, "shots": game.staff_flight.shots_fired, "rounds": game.rifle_magazine.rounds, "previous_rounds": previous_rounds})
			_expect(absf(duration - 1.2) <= STEP + .000001 and previous_rounds == 0 and game.rifle_magazine.rounds == 5, "reload did not refill at 1.2 world-simulation seconds")
			await _capture_once("refill", "14-magazine-refill-five-rounds")


func _state() -> Dictionary:
	var pose: Dictionary = game.current_visual_sample()
	return {"physics_tick": physics_context.ticks, "simulation_time": game.run_time, "rounds": game.rifle_magazine.rounds, "capacity": game.rifle_magazine.capacity, "reloading": game.rifle_magazine.reloading, "reload_elapsed": game.rifle_magazine.elapsed, "reload_progress": game.rifle_magazine.progress(), "phase": pose.phase, "pitch": pose.pitch, "screen_roll": pose.get("screen_roll", 0.0), "shots": game.staff_flight.shots_fired, "hits": game.hits, "damage": game.total_damage, "casings_spawned": game.casing_fx.spawned_count, "casings_active": game.casing_fx.active.size(), "last_shot_recoil": game.rifle_recoil_travelled, "actual_backward_travel": -(game.player.position - initial_player).dot(direction), "player_position": _vector(game.player.position), "far_min_health": far_min_health}


func _resolved_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for item: Dictionary in game.staff_flight.resolved:
		var record: Dictionary = item.duplicate()
		for key in ["position", "cutoff_position", "first_exit_position"]:
			if record.has(key): record[key] = _vector(record[key])
		var ids: Array[String] = []
		for id in item.get("hitids", []): ids.append(str(id))
		record.hitids = ids
		records.append(record)
	return records


func _texture_world(sprite: Sprite3D, point: Vector2) -> Vector3:
	var size := sprite.texture.get_size()
	return sprite.global_transform * (Vector3(point.x - size.x * .5 + sprite.offset.x, size.y * .5 - point.y + sprite.offset.y, 0.0) * sprite.pixel_size)


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
	print("RIFLE CAPTURE: ", path)


func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _vector2(value: Vector2) -> Array[float]:
	return [value.x, value.y]


func _save_frame(path: String) -> void:
	if not _window_is_offscreen():
		_expect(false, "native capture window lost offscreen/no-focus state")
		return
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(_window_is_offscreen(), "native window moved during frame readback")
	var picture: Image = root.get_texture().get_image()
	_expect(picture != null and not picture.is_empty() and picture.get_size() == Vector2i(1280, 800) and picture.save_png(path) == OK, "could not save full 1280x800 native viewport: " + path)
