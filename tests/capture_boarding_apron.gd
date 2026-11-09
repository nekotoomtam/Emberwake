extends SceneTree
var game
var output:=""
var checks:=0
var failures: Array=[]
var shots: Array=[]
var reached: Array=[]
func _initialize() -> void:
 root.unfocusable=true
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func release_walk() -> void:
 for key in ["harbor_left","harbor_right","harbor_up","harbor_down"]:Input.action_release(key)
func walk_to(target: Vector3) -> bool:
 var budget:=ceili((game.walker.position.distance_to(target)/2.5+3.0)*Engine.physics_ticks_per_second)
 for i in budget:
  var offset: Vector3=target-game.walker.position;offset.y=0
  if offset.length()<.16:release_walk();return true
  var aim: Vector3=offset.normalized()
  var right:=Vector3(game.camera.global_basis.x.x,0,game.camera.global_basis.x.z).normalized()
  var toward:=Vector3(game.camera.global_basis.z.x,0,game.camera.global_basis.z.z).normalized()
  var x: float=aim.dot(right);var z: float=aim.dot(toward)
  release_walk();Input.action_press("harbor_right" if x>=0 else "harbor_left",absf(x));Input.action_press("harbor_down" if z>=0 else "harbor_up",absf(z))
  await physics_frame;game.tick(1.0/Engine.physics_ticks_per_second)
 release_walk();printerr("BOARDING WALK STOP ",game.walker.position," target ",target);return false
func shot(label: String,at: Vector3,target: Vector3,lens: float) -> void:
 game.ui.caption.hide()
 game.camera.flying=false;game.camera._duration=0;game.camera.position=at;game.camera.look_at(target);game.camera.fov=lens
 game.world.tick(0,game.camera)
 if game.walker!=null:game.walker.update_art(0,Vector3.ZERO);game.world.plaza.travel_luggage.update_carry(game.walker,game.camera)
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,label);shots.append(label)
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 root.size=Vector2i(1280,800);root.content_scale_size=root.size;DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/prologue.tscn").instantiate();root.add_child(game);current_scene=game;game.set_process(false)
 game.ui.start_button.pressed.emit();game.skip_arrival()
 for i in 20:await physics_frame;game.tick(1.0/Engine.physics_ticks_per_second)
 for point in [Vector3(-41,.055,-5.5),Vector3(-36,.055,-3),Vector3(-25,.055,-3),Vector3(-22,.055,6),Vector3(-16,.055,11.6),Vector3(-1.8,.055,11.6),Vector3(6,.055,7.3)]:
  var ok:=await walk_to(point);reached.append(ok)
  if not ok:break
 check(reached.size()==7 and reached.all(func(v):return v),"real carrying player walks from cafe across the cleared former market and yard")
 await shot("01-open-boarding-apron",Vector3(13,7.8,21),Vector3(5.3,1.4,-1.6),51)
 for point in [Vector3(7.5,.055,3),Vector3(7.2,.43,1.2),Vector3(7,.43,.6),Vector3(7,2.315,-3.2),Vector3(7,2.315,-4.2)]:
  var ok:=await walk_to(point);reached.append(ok)
  if not ok:break
 check(reached.size()==12 and reached.all(func(v):return v) and game.walker.position.y>2.1,"real player walks up the new continuous gangway onto the ship deck")
 await shot("02-matched-departure-gangway",Vector3(12,5.7,5.5),Vector3(7,1.1,-1.5),47)
 check(game.world.plaza.travel_luggage.grip.global_position.distance_to(game.world.plaza.travel_luggage.hand_world)<.025,"carried suitcase stays attached on the new slope")
 for point in [Vector3(7,2.315,-3.2),Vector3(7,.43,.6),Vector3(7.2,.43,1.2),Vector3(7.5,.055,3),Vector3(6,.055,7.3)]:
  var ok:=await walk_to(point);reached.append(ok)
  if not ok:break
 check(reached.size()==17 and reached.all(func(v):return v) and game.walker.position.y<.3,"real player walks back down into the open apron")
 await shot("03-arrival-gangway-same-style",Vector3(18,6,-24),Vector3(12,1.2,-33.2),44)
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"shots":shots,"route_waypoints_reached":reached,"final_player_position":str(game.walker.position),"offscreen":true,"unfocusable":true,"normal_visible_launch":false},"  "));file.close()
 release_walk();game.audio.shutdown();await create_timer(.25).timeout;game.free();await process_frame
 print("NATIVE BOARDING APRON ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
