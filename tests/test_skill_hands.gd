extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
	for skill in ["twin_cut","armor_pierce"]:
		game.loadout.defaults();game.loadout_edited();game.start_run(true);game.test_aim=Vector3.RIGHT
		game.request_skill() if skill=="twin_cut" else game.request_armor_skill()
		await physics_frame;game.tick(.02)
		if not game.dual_visual.visible or not game.dual_visual.rigs[1].weapon.visible:failures.append(skill+" hides equipped offhand")
		for i in range(200):await physics_frame;game.tick(1.0/120)
	game.queue_free();await process_frame
	for fail in failures:printerr("FAIL: ",fail)
	print("SKILL HANDS: ","PASS" if failures.is_empty() else "FAIL");quit(0 if failures.is_empty() else 1)
