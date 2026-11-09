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
 if g.walker!=null and g.ui.bark_panel.visible:g.ui.position_actor_bark(g.camera.unproject_position(g.walker.global_position+Vector3.UP*2))
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
 release_walk();printerr("NATIVE CITY WALK STOP ",g.walker.position," target ",target);return false
func contact(target: Vector3,seconds: float,group: String) -> bool:
 var touched:=false
 for frame in ceili(seconds*Engine.physics_ticks_per_second):
  steer(target);await physics_frame;g.tick(1.0/Engine.physics_ticks_per_second)
  for index in g.walker.get_slide_collision_count():
   var hit: KinematicCollision3D=g.walker.get_slide_collision(index)
   for contact_index in hit.get_collision_count():
    var body: Object=hit.get_collider(contact_index);var normal: Vector3=hit.get_normal(contact_index)
    if body is Node and body.is_in_group(group) and Vector2(normal.x,normal.z).length()>.8:touched=true
 release_walk();return touched
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000));DirAccess.make_dir_recursive_absolute(output)
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 g.tick(.2);await shot("01-original-ship-title")
 g.set_view(&"cafe");g.camera.tick(1);g.world.tick(0,g.camera);await shot("02-cafe-with-seated-pair")
 check(g.world.life.coffee_pair.size()==2 and g.world.life.portrait_pair.size()==2,"both social scenes composed")
 frame_view(Vector3(-46,3.5,-1.5),Vector3(-47.3,.9,-8.2),38)
 g.world.life.tick(0,g.camera,4.8);await shot("03-coffee-first-sip")
 var first_cup: Vector3=g.world.life.coffee_pair[0].cup.position
 g.world.life.tick(0,g.camera,0);await shot("04-coffee-partner-sip")
 check(g.world.life.coffee_pair[0].cup.position.distance_to(first_cup)>.1,"cups alternate between saucer and mouth")
 frame_view(Vector3(-17,5.8,9),Vector3(-22,1,-.2),42)
 g.world.life.tick(0,g.camera,2);await shot("05-painter-and-model")
 var brush: Transform3D=g.world.life.portrait_pair[0].brush.transform
 g.world.life.tick(0,g.camera,3.6);await shot("06-painter-next-stroke")
 check(g.world.life.portrait_pair[0].brush.transform!=brush,"artist brush actually moves")
 frame_view(Vector3(-13,8,-7),Vector3(-25,1,-19.5),48);await shot("07-former-pottery-walkway")
 var space: PhysicsDirectSpaceState3D=g.world.get_world_3d().direct_space_state
 check(space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-25,.75,-15),Vector3(-25,.75,-21.5),1)).is_empty(),"former building/counter has no ghost collision")
 frame_view(Vector3(-42,14,21),Vector3(-55,1,-5),54);await shot("08-large-west-street")
 g.return_title();g.start_arrival();g.skip_arrival()
 for point in [Vector3(-43,.055,-7.3),Vector3(-41,.055,-5.5),Vector3(-36,.055,-3),Vector3(-25,.055,-3),Vector3(-25,.055,-15),Vector3(-25,.055,-21.7)]:check(await walk_to(point),"actual cleared north approach "+str(point))
 for i in Engine.physics_ticks_per_second:
  steer(Vector3(-25,.055,-24));await physics_frame;g.tick(1.0/Engine.physics_ticks_per_second)
  if g.ui.bark_panel.visible:break
 release_walk();g.tick(.01);await shot("09-north-walkway-warning")
 check(g.ui.bark_panel.visible and g.walker.position.z>=Profile.NORTH_GATE_Z-.01,"north route warns at its supported end")
 for point in [Vector3(-25,.055,-15),Vector3(-25,.055,-3),Vector3(-49,.055,-3),Vector3(-52.2,.055,-3),Vector3(-52.2,.055,-18),Vector3(-51.65,.055,-18)]:check(await walk_to(point),"actual public-band north-stores approach "+str(point))
 check(await contact(Vector3(-51.65,.055,-24),1.8,"harbor_town_end_building"),"native player meets actual terminal building")
 frame_view(Vector3(-46,12,-6),Vector3(-57.5,1.9,-19.6),53);await shot("10a-north-street-building-closure")
 for point in [Vector3(-51.65,.055,-17),Vector3(-52.2,.055,-17),Vector3(-52.2,.055,11)]:check(await walk_to(point),"actual western public pavement "+str(point))
 for i in Engine.physics_ticks_per_second:
  steer(Vector3(-60,.055,11));await physics_frame;g.tick(1.0/Engine.physics_ticks_per_second)
  if g.ui.bark_panel.visible:break
 release_walk();g.tick(.01);frame_view(Vector3(-46,9,22),Vector3(-52.5,1,9),50);await shot("10-west-street-warning")
 check(g.ui.bark_panel.visible and g.walker.position.x>=Profile.WEST_GATE_X-.001 and g.walker.position.x<Profile.WEST_GATE_X+.2 and g.walker.position.x-.24>=Profile.WEST_LINE_X-.001,"adjacent pavement seam keeps the player footprint outside the scenic road")
 for point in [Vector3(-52.2,.055,11),Vector3(-52.2,.055,-3),Vector3(-49,.055,-3)]:check(await walk_to(point),"player can immediately return inward from the seam "+str(point))
 g.return_title();g.tick(0);await shot("11-original-ship-replay")
 check(not g.ui.bark_panel.visible and g.phase==&"title","replay clears speech and restores original opening")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":shots},"  "));file.close()
 g.audio.shutdown();await create_timer(.25).timeout;g.free();await process_frame
 print("NATIVE HARBOR CITY LIFE ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
