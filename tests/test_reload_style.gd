extends SceneTree
var game
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.start_run(true);game.set_weapon_family("pistol")
 game.pistol_magazine.consume();check(game.request_reload(),"pistol reload starts after spent round")
 game.pistol_magazine.tick(.30)
 var pose: Dictionary=game.current_visual_sample()
 check(float(pose.get("screen_roll",0))>TAU*1.5,"pistol completes rapid multiple-turn spin before reload ends")
 check(absf(float(pose.get("progress",-1))-.6)<.001,"reload pose exposes real magazine progress to both-hand rigs")
 game.start_run(true);game.set_weapon_family("rifle");game.rifle_magazine.consume();check(game.request_reload(),"rifle reload starts")
 game.rifle_magazine.tick(.48);pose=game.current_visual_sample()
 check(float(pose.pitch)>.7,"rifle lifts clearly for loading")
 check(float(pose.get("support_pull",0))>.5,"rifle support hand reaches loading port")
 game.queue_free();await process_frame
 print("RELOAD STYLE: ","PASS" if failures.is_empty() else "FAIL", " ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
