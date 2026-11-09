extends SceneTree
var game
var output:=""
var seen: Dictionary={}
var reached: Array=[]
func _initialize() -> void:
 root.unfocusable=true
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func release() -> void:
 for id in ["harbor_left","harbor_right","harbor_up","harbor_down"]:Input.action_release(id)
func frame() -> void:
 game.tick(1.0/30)
 if game.walker.art_action=="walk":seen[game.walker.facing]=true
 await process_frame
func walk_to(target: Vector3) -> bool:
 for index in 180:
  var offset: Vector3=target-game.walker.position;offset.y=0
  if offset.length()<.16:release();return true
  var direction: Vector3=offset.normalized()
  var right:=Vector3(game.camera.global_basis.x.x,0,game.camera.global_basis.x.z).normalized()
  var toward:=Vector3(game.camera.global_basis.z.x,0,game.camera.global_basis.z.z).normalized()
  var x: float=direction.dot(right);var z: float=direction.dot(toward)
  release();Input.action_press("harbor_right" if x>=0 else "harbor_left",absf(x));Input.action_press("harbor_down" if z>=0 else "harbor_up",absf(z))
  await frame()
 release();return false
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 game=load("res://scenes/prologue.tscn").instantiate();root.add_child(game);current_scene=game;game.set_process(false)
 game.ui.start_button.pressed.emit();game.skip_arrival()
 for index in 15:await frame()
 for point in [Vector3(-43,.055,-7.3),Vector3(-43,.055,-3),Vector3(-40.6,.055,-3),Vector3(-40.6,.055,1),Vector3(-43,.055,1),Vector3(-43,.055,-3)]:
  reached.append(await walk_to(point))
 release()
 for index in 30:await frame()
 var file:=FileAccess.open(output,FileAccess.WRITE)
 file.store_string(JSON.stringify({"reached":reached,"walking_directions":seen.keys(),"final_position":str(game.walker.position),"carrying":game.world.plaza.travel_luggage.state==&"carried","native_case_handle_error":game.world.plaza.travel_luggage.grip.global_position.distance_to(game.world.plaza.travel_luggage.hand_world)},"  "));file.close()
 var okay: bool=reached.all(func(value):return value) and seen.size()==4
 game.audio.shutdown();game.free();await process_frame
 quit(0 if okay else 1)
