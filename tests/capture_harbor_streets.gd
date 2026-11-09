extends SceneTree
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var g
var output:=""
var checks:=0
var failures: Array=[]
var shots: Array=[]
func _initialize() -> void:
 root.unfocusable=true
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func shot(label: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,"capture "+label);shots.append(label)
func frame_view(at: Vector3,target: Vector3,fov_: float=48) -> void:
 g.camera._duration=0;g.camera.flying=false;g.camera.position=at;g.camera.look_at(target);g.camera.fov=fov_;g.world.tick(0,g.camera)
func release_walk() -> void:
 for key in ["harbor_left","harbor_right","harbor_up","harbor_down"]:Input.action_release(key)
func steer(target: Vector3) -> void:
 var direction: Vector3=target-g.walker.position;direction.y=0;direction=direction.normalized()
 var right:=Vector3(g.camera.global_basis.x.x,0,g.camera.global_basis.x.z).normalized()
 var toward:=Vector3(g.camera.global_basis.z.x,0,g.camera.global_basis.z.z).normalized()
 var x: float=direction.dot(right);var z: float=direction.dot(toward)
 release_walk();Input.action_press("harbor_right" if x>=0 else "harbor_left",absf(x));Input.action_press("harbor_down" if z>=0 else "harbor_up",absf(z))
func walk_to(target: Vector3) -> bool:
 for i in Engine.physics_ticks_per_second*10:
  var delta: Vector3=target-g.walker.position;delta.y=0
  if delta.length()<.18:release_walk();return true
  steer(target);await physics_frame;g.tick(1.0/Engine.physics_ticks_per_second)
 release_walk();printerr("NATIVE NORTH WALK STOP ",g.walker.position," target ",target);return false
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000));DirAccess.make_dir_recursive_absolute(output)
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 g.start_arrival();g.skip_arrival()
 g.walker.set_physics_process(false);g.walker.position=Vector3(-34,.055,14)
 frame_view(Vector3(-29,13,29),Vector3(-35,1,-2),54);await shot("01-street-square-wide")
 frame_view(g.walker.position+Vector3(2.9,7.8,10.2),g.walker.position+Vector3(2.9,1.7,-3.2));g.walker.update_art(0,Vector3.ZERO);await shot("02-walking-loading-lane")
 frame_view(Vector3(-34,6,21),Vector3(-40.4,1.0,11.8),48);await shot("03-wagon-cargo-detail")
 frame_view(Vector3(-34,9,15),Vector3(-34,1,-1),52);await shot("04-aligned-public-furniture")
 check(get_nodes_in_group("harbor_plaza_lamp").size()==4,"four aligned actual lamp bodies")
 check(g.world.plaza.street.geometry_count>1000,"loading road and detailed parked equipment render")
 g.return_title();g.start_arrival();g.skip_arrival()
 for point in [Vector3(-43,.055,-7.3),Vector3(-41,.055,-5.5),Vector3(-36,.055,-3),Vector3(-23,.055,-3),Vector3(-20.3,.055,-3),Vector3(-20.3,.055,-19)]:check(await walk_to(point),"actual wrong-turn approach "+str(point))
 await shot("04b-open-shop-side-mouth")
 var space: PhysicsDirectSpaceState3D=g.world.get_world_3d().direct_space_state
 check(space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-20.6,.75,-18.8),Vector3(-19,.75,-18.8),1)).is_empty(),"removed mouth rail leaves no invisible collision")
 check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-20.6,.75,-15),Vector3(-19,.75,-15),1)).is_empty(),"remaining sea-side rail still blocks")
 for i in Engine.physics_ticks_per_second*2:
  steer(Vector3(-20.3,.055,-24));await physics_frame;g.tick(1.0/Engine.physics_ticks_per_second)
  if g.ui.bark_panel.visible:break
 release_walk();g.tick(.02);await process_frame;g.tick(0)
 check(g.ui.bark_panel.visible and g.ui.bark_text.text=="นั่นไม่ใช่ทางไปที่เรือนะ","native visible protagonist line comes from actual movement")
 check(g.walker.position.z>=Profile.NORTH_GATE_Z-.01,"wrong route stays bounded")
 check(g.ui.bark_panel.size.y<=100,"short readable speech panel")
 await shot("05-protagonist-wrong-turn-line")
 root.content_scale_size=Vector2i(1024,640);root.size=Vector2i(1024,640);await process_frame;g.tick(.02);await process_frame;g.tick(0)
 check(root.get_visible_rect().encloses(g.ui.bark_panel.get_global_rect()),"small-window speech remains visible")
 await shot("06-small-window-wrong-turn")
 root.content_scale_size=Vector2i(1280,800);root.size=Vector2i(1280,800);await process_frame
 check(await walk_to(Vector3(-20.3,.055,-17.3)),"player can return immediately from wrong turn")
 g.return_title();g.tick(0)
 check(not g.ui.bark_panel.visible and g.route_bark_time==0,"replay clears warning")
 await shot("07-original-ship-replay")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":shots},"  "));file.close()
 g.audio.shutdown();await create_timer(.25).timeout;g.free();await process_frame
 print("NATIVE HARBOR STREETS ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
