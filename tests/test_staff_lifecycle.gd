extends SceneTree
var fails: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
 if not ok:fails.append(why);printerr("FAIL: ",why)
func run() -> void:
 var game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path="";game.start_run(true)
 game.ground_fire.spawn_patch(Vector3(2,0,0));game.restart();check(game.ground_fire.zones.is_empty(),"restart clears old groundfire")
 game.ground_fire.spawn_patch(Vector3(2,0,0));game.return_menu();check(game.ground_fire.zones.is_empty(),"menu clears old groundfire")
 game.start_run(true);check(game.ground_fire.zones.is_empty(),"newrun no old zone")
 game.tick(.5);check(game.total_damage==0,"oldpatch cannot hurtnewtarget")
 game.queue_free();await process_frame
 print("STAFF LIFECYCLE: 4 checks; ","PASS" if fails.is_empty() else "FAIL",fails);quit(0 if fails.is_empty() else 1)
