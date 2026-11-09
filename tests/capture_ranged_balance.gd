extends SceneTree
## Native viewport mouse/keys and real 120-Hz model ticks; no supplied attacks/damage.
## Use absolute external --script alongside adjacent exported PCK; --output=<absolute> [--frames].

const STEP := 1.0 / 120.0
const CYCLES := {"staff": 1.20, "pistol": .42, "rifle": .90}
var game
var output := ""
var record_frames := false
var safe := false
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var damage_events: Array[Dictionary] = []
var area_events: Array[Dictionary] = []
var reload_events: Array[Dictionary] = []
var screenshots: Array[Dictionary] = []
var raw_frames: Array[String] = []
var raw_states: Array[Dictionary] = []
var case_label := ""
var targets: Dictionary = {}
var origin := Vector3.ZERO
var direction := Vector3.RIGHT
var presses := 0
var releases := 0
var keys: Array[String] = []
var shot_start := 0
var damage_start := 0
var area_start := 0
var reload_start := 0
var evidence_label: Label
var pause_evidence: Dictionary = {}
var restart_evidence: Dictionary = {}
var fixture_blocker: StaticBody3D
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
		printerr("RANGED BALANCE CAPTURE FAILED: offscreen/no-focus state lost")
		quit(1)
	return false


func _run() -> void:
	if output.is_empty() or not output.is_absolute_path() or DisplayServer.get_name() == "headless":
		printerr("RANGED BALANCE CAPTURE FAILED: native renderer and absolute --output required")
		quit(1)
		return
	root.unfocusable = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	root.mode = Window.MODE_WINDOWED
	DisplayServer.window_set_position(Vector2i(20000, 20000))
	safe = true
	await process_frame
	if not _window_safe():
		printerr("RANGED BALANCE CAPTURE FAILED: safe native setup failed")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output.path_join("fireball"))
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.staff_flight.damage_hit.connect(_damage)
	game.staff_flight.area_impact.connect(_area)
	_add_label()
	await _cluster_case()
	for family: String in ["staff", "pistol", "rifle"]: await _cadence_case(family, 3, false)
	await _cadence_case("rifle", 6, true)
	await _non_enemy_impact("staff-cover", true)
	await _non_enemy_impact("staff-range", false)
	await _restart_case()
	_expect(physics.outside_physics_ticks == 0, "model tick outside real physics")
	if record_frames: _expect(raw_frames.size() == 90, "missing 90 contiguous native fireball frames")
	var manifest := {
		"renderer": DisplayServer.get_name(), "engine": Engine.get_version_info().string,
		"native_window": {"unfocusable": root.unfocusable, "native_no_focus_flag": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS), "actual_position": [DisplayServer.window_get_position().x, DisplayServer.window_get_position().y], "mode": root.mode, "checked_every_frame_and_tick": true},
		"input": "Viewport.push_input real mouse motion/LMB hold/release and Escape/T key events. No attack/damage/pose/projectile/ammo APIs invoked by helper.",
		"fixtures": "Original practice dummy plus original dummy actors, positioned once before each case. Central cluster: player(0,0), primary(4,0), near(3.6,1), far(3.6,2.4), covered(3.6,-1.46). ONE TEST-ONLY solid visible dark-stone blocker centred(3.6,.65,-.8), size(1,1.3,.12), world collision layer1/mask0 blocks splash torso LOS without crossing the straight shot; it is removed before the next case. Covered dummy remains outside this blocker. Empty-aim cadence dummy is behind player. Separate cover case uses original pillar(8,5.4). Production camera/game are untouched. No supplied health, damage, knockback, poses, or per-frame target movement.",
		"authored_cycles": CYCLES, "fire_speed": 5.5, "fire_range": 6.0, "blast_radius": 1.20, "blast_lifetime": .40,
		"physics_context": physics, "cases": cases, "shots": shots, "damage_events": damage_events, "area_events": area_events, "reload_events": reload_events,
		"pause": pause_evidence, "restart": restart_evidence, "screenshot_states": screenshots,
		"raw_fps": 30, "raw_frame_count": raw_frames.size(), "raw_frames": raw_frames, "raw_states": raw_states,
		"raw_timeline": "90 chronological frames at four model physics ticks per frame; native elapsed time continues through actual Escape pause while simulation freezes.",
		"failures": failures,
	}
	var file := FileAccess.open(output.path_join("capture-manifest.json"), FileAccess.WRITE)
	if file == null: failures.append("cannot write capture manifest")
	else:
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()
	game.queue_free()
	await process_frame
	for failure in failures: printerr("RANGED BALANCE CAPTURE FAILED: ", failure)
	print("RANGED BALANCE CAPTURE: %d cases / %d stills / %d raw frames; failures=%s" % [cases.size(), screenshots.size(), raw_frames.size(), JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)


func _fixture(family: String, label: String, player_position: Vector3 = Vector3(0, .03, 0), primary_position: Vector3 = Vector3(-8, .03, 0)) -> void:
	if is_instance_valid(fixture_blocker):
		game.remove_child(fixture_blocker)
		var removed: bool = fixture_blocker.get_parent() != game
		_expect(removed, "test-only cluster blocker survived into another fixture")
		for previous: Dictionary in cases:
			if previous.has("fixture_blocker"): previous.fixture_blocker.removed_before_next_case = removed
		fixture_blocker.queue_free()
		fixture_blocker = null
	case_label = label
	game.start_run(true)
	game.set_physics_process(false)
	_expect(game.set_weapon_family(family), label + " could not equip weapon")
	game.move_input = Vector2.ZERO
	game.test_aim = Vector3.ZERO
	game.player.position = player_position
	direction = Vector3.RIGHT
	targets.clear()
	var primary = game.enemies[0]
	primary.position = primary_position
	_track_target("primary", primary)
	presses = 0
	releases = 0
	keys.clear()
	shot_start = shots.size()
	damage_start = damage_events.size()
	area_start = area_events.size()
	reload_start = reload_events.size()
	for index in range(72): await _tick()
	origin = game.player.position
	_point_mouse()


func _track_target(label: String, target) -> void:
	targets[label] = {"node": target, "id": target.get_instance_id(), "initial_position": target.position, "initial_health": target.health, "min_health": target.health}


func _cluster_case() -> void:
	await _fixture("staff", "staff-cluster-pause", Vector3(0, .03, 0), Vector3(4, .03, 0))
	_track_target("near", game.spawn_enemy("dummy", Vector3(3.6, .03, 1)))
	_track_target("far", game.spawn_enemy("dummy", Vector3(3.6, .03, 2.4)))
	_track_target("covered", game.spawn_enemy("dummy", Vector3(3.6, .03, -1.46)))
	_add_cluster_blocker()
	await _tick()
	await _capture("staff-cluster-00-ready")
	_mouse(true)
	_mouse(false)
	var flight_seen := false
	var blast_seen := false
	var paused_once := false
	var resumed := false
	var paused_ticks := 0
	for index in range(360):
		await _tick()
		if not flight_seen and not game.staff_flight.active.is_empty() and game.staff_flight.active[0].travelled >= .55:
			flight_seen = true
			await _capture("staff-cluster-01-slow-fireball")
		if not blast_seen and not game.fx.fire_blasts.is_empty():
			blast_seen = true
			await _capture("staff-cluster-02-round-blast")
		if blast_seen and not paused_once and not game.fx.fire_blasts.is_empty() and game.fx.fire_blasts[0].age >= .06:
			_key(KEY_ESCAPE)
			paused_once = true
			pause_evidence = {"start_tick": physics.ticks, "mode": game.mode, "age_before": game.fx.fire_blasts[0].age, "radius": game.fx.fire_blasts[0].radius, "simulation_before": game.run_time}
		if paused_once and not resumed:
			paused_ticks += 1
			_expect(game.mode == "paused" and game.fx.fire_blasts.size() == 1 and game.fx.fire_blasts[0].age == pause_evidence.age_before and game.run_time == pause_evidence.simulation_before, "actual Escape pause did not freeze blast/simulation")
			if paused_ticks == 49:
				pause_evidence.end_tick = physics.ticks
				pause_evidence.age_after = game.fx.fire_blasts[0].age
				pause_evidence.simulation_after = game.run_time
				await _capture("staff-cluster-03-pause-frozen")
				_key(KEY_ESCAPE)
				resumed = true
		if record_frames and index % 4 == 3:
			var path := output.path_join("fireball/fireball_%03d.png" % raw_frames.size())
			await _save(path)
			raw_frames.append(path)
			var state := _state()
			state.frame_index = raw_frames.size() - 1
			state.native_elapsed_seconds = (index + 1) * STEP
			raw_states.append(state)
	_expect(flight_seen and blast_seen and paused_once and resumed, "cluster missing real fireball/blast/pause sequence")
	_expect(game.staff_flight.shots_fired == 1 and game.hits == 2 and is_equal_approx(game.total_damage, 108), "cluster direct/splash contact totals differ")
	_expect(_target_damage("primary") == 72 and _target_damage("near") == 36 and _target_damage("far") == 0 and _target_damage("covered") == 0, "cluster expected primary72 near36 far0 covered0")
	_expect(area_events.size() - area_start == 1 and game.fx.fire_blasts.is_empty(), "cluster detonation count or natural .40s expiry differs")
	var result := _result()
	result.fixture_blocker = {"test_only": true, "position": [3.6, .65, -.8], "size": [1.0, 1.3, .12], "collision_layer": 1, "collision_mask": 0, "purpose": "splash torso LOS only; straight projectile lane remains clear", "visible_mesh_matches_collision": true, "removed_before_next_case": false}
	result.pause_ticks = paused_ticks - 1
	await _capture("staff-cluster-04-settled")
	cases.append(result)


func _add_cluster_blocker() -> void:
	fixture_blocker = StaticBody3D.new()
	fixture_blocker.name = "TestOnlySplashCoverStone"
	fixture_blocker.collision_layer = 1
	fixture_blocker.collision_mask = 0
	fixture_blocker.position = Vector3(3.6, .65, -.8)
	var bounds := Vector3(1.0, 1.3, .12)
	var shape := BoxShape3D.new()
	shape.size = bounds
	var collision := CollisionShape3D.new()
	collision.shape = shape
	fixture_blocker.add_child(collision)
	var mesh := BoxMesh.new()
	mesh.size = bounds
	var visible_stone := MeshInstance3D.new()
	visible_stone.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#34414b")
	material.roughness = 1.0
	visible_stone.material_override = material
	fixture_blocker.add_child(visible_stone)
	game.add_child(fixture_blocker)


func _cadence_case(family: String, count: int, with_reload: bool) -> void:
	var label := family + ("-six-shot-reload" if with_reload else "-three-shot-cadence")
	await _fixture(family, label)
	await _capture(label + "-00-ready")
	_mouse(true)
	var released := false
	var first_seen := false
	for index in range(2000):
		await _tick()
		if not first_seen and game.staff_flight.shots_fired > 0:
			first_seen = true
			await _capture(label + "-01-first-shot")
		if game.staff_flight.shots_fired == count and not released:
			_mouse(false)
			released = true
		if released and not game.motion.busy and game.staff_flight.active.is_empty() and not game.guns_reloading(): break
	var result := _result()
	result.expected_cycle = CYCLES[family]
	var case_shots := shots.slice(shot_start)
	var intervals: Array[float] = []
	for index in range(1, case_shots.size()):
		var interval: float = case_shots[index].time - case_shots[index - 1].time
		intervals.append(interval)
		var expected: float = CYCLES[family] + (1.2 if with_reload and index == 5 else 0)
		_expect(absf(interval - expected) <= STEP * 2.1, label + " native intershot interval differs from authored cadence/reload")
	result.shot_intervals = intervals
	_expect(released and game.staff_flight.shots_fired == count and presses == 1 and releases == 1, label + " did not use one real hold/release for exact shot count")
	_expect(game.hits == 0 and game.total_damage == 0 and area_events.size() == area_start and game.fx.fire_blasts.is_empty(), label + " empty aim unexpectedly hit or detonated")
	if family != "staff":
		var expected_rounds: int = 4 if with_reload else (10 if family == "pistol" else 5) - count
		_expect(game.active_magazine().rounds == expected_rounds, label + " native magazine count differs")
		_expect(reload_events.size() - reload_start == (1 if with_reload else 0), label + " automatic reload count differs")
	if family == "rifle":
		_expect(game.casing_fx.spawned_count == count and absf((game.player.position - origin).dot(direction) + .22 * count) < .003, label + " original rifle casings/recoil changed")
	await _capture(label + "-02-finished")
	cases.append(result)


func _non_enemy_impact(label: String, cover: bool) -> void:
	await _fixture("staff", label, Vector3(6, .03, 5.4) if cover else Vector3(0, .03, 0), Vector3(10, .03, 5.4) if cover else Vector3(10, .03, 0))
	await _capture(label + "-00-ready")
	_mouse(true)
	_mouse(false)
	for index in range(360):
		await _tick()
		if game.staff_flight.shots_fired == 1 and game.staff_flight.active.is_empty() and not game.motion.busy: break
	var result := _result()
	_expect(game.staff_flight.resolved.size() == 1 and game.staff_flight.resolved[0].reason == ("cover" if cover else "range"), label + " wrong real projectile resolution")
	_expect(game.hits == 0 and game.total_damage == 0 and area_events.size() == area_start and game.fx.fire_blasts.is_empty(), label + " non-enemy removal created damage circle")
	await _capture(label + "-01-no-blast")
	cases.append(result)


func _restart_case() -> void:
	await _fixture("staff", "staff-native-restart", Vector3(0, .03, 0), Vector3(4, .03, 0))
	_mouse(true)
	_mouse(false)
	for index in range(240):
		await _tick()
		if not game.fx.fire_blasts.is_empty(): break
	_expect(game.fx.fire_blasts.size() == 1, "restart fixture did not create real blast")
	var old_blast = game.fx.fire_blasts[0] if not game.fx.fire_blasts.is_empty() else null
	var old_nodes: Array[Node] = []
	for node: Node in game.fx.get_children(): old_nodes.append(node)
	restart_evidence = {"before": _state(), "old_transient_node_count": old_nodes.size()}
	await _capture("staff-restart-00-active-blast")
	var result := _result()
	_key(KEY_T)
	var removed := true
	for node: Node in old_nodes:
		if is_instance_valid(node) and node.get_parent() == game.fx: removed = false
	restart_evidence.old_nodes_removed_from_owner = removed
	restart_evidence.old_blast_removed = not is_instance_valid(old_blast) or old_blast.get_parent() != game.fx
	targets.clear()
	_track_target("reset_dummy", game.enemies[0])
	restart_evidence.after = _state()
	_expect(removed and game.fx.fire_blasts.is_empty() and game.staff_flight.active.is_empty() and game.staff_flight.shots_fired == 0 and game.hits == 0 and game.total_damage == 0, "native T restart retained old blast/projectile/effects state")
	await _capture("staff-restart-01-cleared")
	result.native_restart = true
	cases.append(result)


func _tick() -> void:
	await physics_frame
	if not _window_safe():
		printerr("RANGED BALANCE CAPTURE FAILED: unsafe native physics window")
		quit(1)
		return
	var in_physics := Engine.is_in_physics_frame()
	var delta: float = game.player.get_physics_process_delta_time()
	physics.ticks += 1
	if not in_physics: physics.outside_physics_ticks += 1
	physics.min_physics_delta = minf(physics.min_physics_delta, delta)
	physics.max_physics_delta = maxf(physics.max_physics_delta, delta)
	_expect(in_physics and absf(delta - STEP) < .000001 and Engine.physics_ticks_per_second == 120, "native tick is not real 120-Hz physics")
	if not game.motion.busy: _point_mouse()
	var prior_shots: int = game.staff_flight.shots_fired
	var prior_reload: bool = game.active_magazine().reloading
	game.tick(STEP)
	for entry: Dictionary in targets.values():
		if not is_instance_valid(entry.node): continue
		entry.min_health = minf(entry.min_health, entry.node.health)
		_expect(entry.node.position.distance_to(entry.initial_position) < .0001, case_label + " fixture moved after setup")
	if game.staff_flight.shots_fired > prior_shots:
		var shot := {"case": case_label, "family": game.weapon_family, "tick": physics.ticks, "time": game.run_time, "shot_number": game.staff_flight.shots_fired, "rounds": game.active_magazine().rounds, "player_position": _vec(game.player.position)}
		if not game.staff_flight.active.is_empty():
			var entry: Dictionary = game.staff_flight.active.back()
			shot.merge({"muzzle": _vec(entry.origin), "speed": entry.speed, "range": entry.max_range, "element": entry.element, "damage": entry.damage})
		shots.append(shot)
	if not prior_reload and game.active_magazine().reloading:
		reload_events.append({"case": case_label, "tick": physics.ticks, "time": game.run_time, "duration": game.active_magazine().reload_duration, "rounds": game.active_magazine().rounds})
	_refresh_label()


func _damage(enemy, amount: float, _knock: Vector3, element: String) -> void:
	damage_events.append({"case": case_label, "tick": physics.ticks, "time": game.run_time, "target_id": enemy.get_instance_id(), "damage": amount, "element": element})


func _area(where: Vector3, radius: float, element: String) -> void:
	area_events.append({"case": case_label, "tick": physics.ticks, "time": game.run_time, "position": _vec(where), "radius": radius, "element": element, "visible_blast_count": game.fx.fire_blasts.size()})
	_expect(radius == 1.2 and element == "fire" and game.fx.fire_blasts.size() == 1 and game.fx.fire_blasts[0].radius == radius, "real area event did not create matching visible ground circle")


func _result() -> Dictionary:
	return {"case": case_label, "family": game.weapon_family, "mouse_presses": presses, "mouse_releases": releases, "keys": keys.duplicate(), "shots": game.staff_flight.shots_fired, "hits": game.hits, "damage": game.total_damage, "targets": _target_states(), "shot_events": shots.slice(shot_start), "damage_events": damage_events.slice(damage_start), "area_events": area_events.slice(area_start), "reload_events": reload_events.slice(reload_start), "resolved": _json_safe(game.staff_flight.resolved), "rounds": game.active_magazine().rounds, "reloading": game.active_magazine().reloading, "casings_spawned": game.casing_fx.spawned_count, "player_displacement": _vec(game.player.position - origin), "remaining_projectiles": game.staff_flight.active.size(), "remaining_blasts": game.fx.fire_blasts.size()}


func _target_states() -> Dictionary:
	var result := {}
	for label: String in targets:
		var entry: Dictionary = targets[label]
		var top: Vector3 = entry.node.bar.global_position + Vector3.UP * .10 if is_instance_valid(entry.node) else entry.initial_position + Vector3.UP * 2.2
		result[label] = {"id": entry.id, "position": _vec(entry.initial_position), "min_health": entry.min_health, "damage_taken": entry.initial_health - entry.min_health, "screen_ground": _vec2(game.camera.unproject_position(entry.initial_position)), "screen_top": _vec2(game.camera.unproject_position(top))}
	return result


func _target_damage(label: String) -> float:
	return targets[label].initial_health - targets[label].min_health


func _state() -> Dictionary:
	var blast_states: Array[Dictionary] = []
	for blast: Node3D in game.fx.fire_blasts:
		var screen_bounds: Array = []
		for axis: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
			screen_bounds.append(_vec2(game.camera.unproject_position(blast.global_position + axis * blast.radius)))
		blast_states.append({"age": blast.age, "radius": blast.radius, "position": _vec(blast.position), "screen_center": _vec2(game.camera.unproject_position(blast.global_position)), "screen_radius_points": screen_bounds})
	var flight_states: Array[Dictionary] = []
	for entry: Dictionary in game.staff_flight.active: flight_states.append({"position": _vec(entry.node.global_position), "travelled": entry.travelled, "speed": entry.speed, "age": entry.age, "screen_position": _vec2(game.camera.unproject_position(entry.node.global_position))})
	return {"case": case_label, "family": game.weapon_family, "physics_tick": physics.ticks, "simulation_time": game.run_time, "mode": game.mode, "phase": game.current_visual_sample().phase, "shots": game.staff_flight.shots_fired, "hits": game.hits, "damage": game.total_damage, "rounds": game.active_magazine().rounds, "reloading": game.active_magazine().reloading, "player_position": _vec(game.player.position), "screen_player_ground": _vec2(game.camera.unproject_position(game.player.position)), "screen_player_top": _vec2(game.camera.unproject_position(game.player.position + Vector3.UP * 1.9)), "targets": _target_states(), "flights": flight_states, "blasts": blast_states, "area_count": area_events.size() - area_start}


func _point_mouse() -> Vector2:
	var target: Vector3 = game.player.position + direction * 4
	target.y = 0
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
	evidence_label = Label.new()
	evidence_label.position = Vector2(26, 122)
	evidence_label.add_theme_font_size_override("font_size", 17)
	evidence_label.add_theme_color_override("font_color", Color("#ffe7a9"))
	evidence_label.add_theme_color_override("font_shadow_color", Color("#071018"))
	evidence_label.add_theme_constant_override("shadow_offset_x", 2)
	evidence_label.add_theme_constant_override("shadow_offset_y", 2)
	evidence_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(evidence_label)


func _refresh_label() -> void:
	if not is_instance_valid(evidence_label): return
	evidence_label.text = "NATIVE LMB / %s\nCYCLE %.2fs / SHOTS %d / HITS %d / DAMAGE %.1f / BLAST RADIUS 1.20u\nFIXED DUMMIES / ACTUAL PROJECTILE + AREA EVENTS / NO SUPPLIED DAMAGE" % [case_label.to_upper(), CYCLES[game.weapon_family], game.staff_flight.shots_fired, game.hits, game.total_damage]


func _capture(name: String) -> void:
	_refresh_label()
	var path := output.path_join(name + ".png")
	await _save(path)
	var state := _state()
	state.file = path.get_file()
	screenshots.append(state)
	print("RANGED BALANCE CAPTURE: ", path)


func _save(path: String) -> void:
	_expect(_window_safe(), "unsafe native window before frame readback")
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(_window_safe(), "unsafe native window during frame readback")
	var picture: Image = root.get_texture().get_image()
	_expect(picture != null and not picture.is_empty() and picture.get_size() == Vector2i(1280, 800) and picture.save_png(path) == OK, "failed saving native viewport " + path)


func _window_safe() -> bool:
	return root.unfocusable and root.mode == Window.MODE_WINDOWED and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS) and DisplayServer.window_get_position() == Vector2i(20000, 20000)


func _json_safe(value: Variant) -> Variant:
	if value is Vector3: return _vec(value)
	if value is Vector2: return _vec2(value)
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_json_safe(item))
		return result
	if value is Dictionary:
		var result := {}
		for key: Variant in value: result[key] = _json_safe(value[key])
		return result
	return value


func _vec(value: Vector3) -> Array[float]: return [value.x, value.y, value.z]
func _vec2(value: Vector2) -> Array[float]: return [value.x, value.y]
func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message): failures.append(message)
