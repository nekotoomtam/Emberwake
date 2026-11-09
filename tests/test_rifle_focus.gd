extends SceneTree
var count:=0
var failures: Array=[]
func check(ok: bool,message: String) -> void:
 count+=1
 if not ok:failures.append(message);printerr("FAIL: ",message)
func close(a: float,b: float,message: String) -> void:check(absf(a-b)<.001,message+" got="+str(a))
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var focus=load("res://scripts/rifle_focus.gd").new()
 close(focus.camera_size(),13.5,"normal camera")
 focus.advance(.1,true);check(focus.amount()>0 and focus.amount()<.3,"entry gradual notinstant")
 check(rad_to_deg(focus.half_angle())*2<120 and rad_to_deg(focus.half_angle())*2>32,"cone moves gradually")
 focus.advance(.175,true);close(focus.amount(),.5,"halfway smooth")
 focus.advance(.275,true);close(focus.amount(),1,"full after.55")
 close(rad_to_deg(focus.half_angle())*2,32,"full narrow32")
 close(focus.camera_size(),13,"actual zoomIN")
 close(focus.sight_multiplier(),1.4,"same longrange")
 focus.advance(.1,false);check(focus.amount()<1 and focus.amount()>.7,"exit gradual")
 focus.advance(.45,false);close(focus.amount(),0,"returnsnormal")
 focus.advance(NAN,true);close(focus.amount(),0,"invaliddelta ignored")
 var game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path="";game.start_run(true);game.set_weapon_family("rifle");game.test_aim=Vector3.RIGHT
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=true;root.push_input(e,true)
 close(game.vision.reach(),10,"RMBpress noinstantfarvision")
 game.tick(.1);check(game.vision.reach()>10 and game.vision.reach()<14,"controller intermediate reach")
 game.tick(.45);close(game.vision.reach(),14,"controller fullreach")
 close(rad_to_deg(game.vision.half_angle())*2,32,"controller fullcone")
 close(game.camera.size,13,"controller zoomin")
 check(game.rifle_scope.visible,"softscopeframe active")
 check(not game.vision.in_cone(Vector3(5,0,3)),"side target clipped")
 check(game.vision.in_cone(Vector3(10,0,0)),"forward linevisible")
 check(game.request_attack(),"shooting still immediate afterfocus");close(game.stamina,85,"ADS cost15 unchanged")
 close(game.motion.definition(0).windup+game.motion.definition(0).active+game.motion.definition(0).recovery,1.2,"ADS timing unchanged")
 e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=false;root.push_input(e,true);game.tick(.55)
 close(game.camera.size,13.5,"camera restored")
 close(rad_to_deg(game.vision.half_angle())*2,120,"cone restored")
 check(not game.rifle_scope.visible,"frame removed")
 for action in ["toggle_inventory","toggle_stats","toggle_pause"]:
  game.start_run(true);game.set_weapon_family("rifle")
  e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=true;root.push_input(e,true);game.tick(.55)
  check(game.rifle_scope.visible,"menu test focused before "+action)
  game.call(action);check(not game.rifle_scope.visible,"scope hidden in "+action)
  game.call(action);game.tick(.55);check(not game.rifle_scope.visible,"scope safelyrestored after "+action)
 game.queue_free();await process_frame
 print("RIFLE FOCUS: ",count," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
