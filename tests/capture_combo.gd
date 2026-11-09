extends SceneTree
## Captures the real held-input combo, never supplies damage or animation poses.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var output: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.start_run(true)
	game.set_weapon_family("sword")
	game.test_aim = Vector3.RIGHT
	game._held = true
	for index in range(90):
		for substep in range(4):
			game.tick(1.0 / 120.0)
			if game.motion.stage == 2: game._held = false
		await process_frame
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(output.path_join("combo_%03d.png" % index)) != OK:
			quit(1)
			return
	print("COMBO CAPTURE:90frames at30fps,real hits=", game.hits, ",damage=", game.total_damage)
	var success: bool = game.hits == 3 and game.total_damage == 71
	game.queue_free()
	await process_frame
	quit(0 if success else 1)
