extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path="";game.loadout.defaults()
	game.loadout.move_item({"kind":"slot","set":0,"hand":"off"},{"kind":"slot","set":0,"hand":"main"});game.loadout_edited();game.start_run(true);game.test_aim=Vector3.RIGHT
	game.request_attack()
	for i in range(150):await physics_frame;game.tick(1.0/120)
	var valid: bool=game.active_item=="sword0" and game.item_magazines.pistol0.rounds==9 and game.request_reload() and game.active_item=="pistol0" and game.active_magazine().reloading
	game.queue_free();await process_frame
	print("MIXED RELOAD: ","PASS" if valid else "FAIL");quit(0 if valid else 1)
