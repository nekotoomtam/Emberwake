extends SceneTree

var game: Node3D
var output_dir := "res://captures"
const STEP := 1.0 / 120.0


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_dir = argument.trim_prefix("--output=")
	call_deferred("_run")


func _step(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.00001:
		var dt: float = minf(STEP, remaining)
		game.tick(dt)
		remaining -= dt


func _wait_for_sword_recovery() -> void:
	for frame_index in range(300):
		if not game.motion.busy:
			return
		game.tick(STEP)


func _capture(name: String) -> void:
	# Native viewport capture preserves the actual 3D renderer and live game UI.
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := output_dir.path_join(name + ".png")
	var result := root.get_texture().get_image().save_png(path)
	if result != OK:
		printerr("CAPTURE FAILED: ", path, " error ", result)
		quit(1)
	print("CAPTURE: ", path)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("CAPTURE FAILED: native rendering is required; omit --headless")
		quit(1)
		return
	if not ResourceLoader.exists("res://scripts/game.gd"):
		printerr("CAPTURE FAILED: playable main game is missing")
		quit(1)
		return
	DisplayServer.window_set_position(Vector2i(1300, 20))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var scene = load("res://scenes/game.tscn")
	if not scene is PackedScene:
		printerr("CAPTURE FAILED: playable scene cannot load")
		quit(1)
		return
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	await _capture("01-menu")
	game.start_run(true)
	game.set_weapon_family("sword")
	game.test_aim = Vector3.RIGHT
	game.move_input = Vector2.ZERO
	game.tick(STEP)
	await _capture("02-practice")
	game.request_attack()
	_step(0.09)
	await _capture("03-windup")
	_step(0.18)
	await _capture("04-sword-sweep")
	_wait_for_sword_recovery()
	game.request_attack()
	_step(0.28)
	_wait_for_sword_recovery()
	game.request_attack()
	_step(0.45)
	await _capture("05-heavy-impact")
	game.start_run(false)
	game.test_aim = Vector3.RIGHT
	var telegraph_visible := false
	for frame_index in range(960):
		game.tick(STEP)
		for enemy in game.enemies:
			if is_instance_valid(enemy) and enemy.kind == "melee" and enemy.state == "windup":
				telegraph_visible = true
				break
		if telegraph_visible:
			break
	if telegraph_visible:
		# Capture within the readable windup, after its first warning ring has drawn.
		_step(0.12)
	await _capture("06-combat-encounter")
	for round_index in range(18):
		if game.mode == "victory":
			break
		var targets: Array = game.enemies.duplicate()
		for enemy in targets:
			if is_instance_valid(enemy) and not enemy.dead:
				game.enemy_hit(enemy, enemy.health + 1.0, Vector3.ZERO)
		_step(2.5)
		await process_frame
	if game.mode != "victory":
		printerr("CAPTURE FAILED: run did not reach victory")
		quit(1)
		return
	await _capture("07-victory")
	game.queue_free()
	await process_frame
	print("CAPTURES COMPLETE: 7 native viewport screenshots")
	quit(0)
