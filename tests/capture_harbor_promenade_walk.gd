extends SceneTree
## Final-pack native views; no scene dressing or production test hooks.
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var g
var output:=""
var checks:=0
var failures: Array=[]
var shots: Array=[]
var events:=0
func _initialize() -> void:
 root.unfocusable=true
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func release_walk() -> void:
 for key in ["harbor_left","harbor_right","harbor_up","harbor_down"]:
  if InputMap.has_action(key):Input.action_release(key)
func steer(target: Vector3) -> void:
 var direction: Vector3=target-g.walker.position;direction.y=0;direction=direction.normalized()
 var right:=Vector3(g.camera.global_basis.x.x,0,g.camera.global_basis.x.z).normalized()
 var toward:=Vector3(g.camera.global_basis.z.x,0,g.camera.global_basis.z.z).normalized()
 var x: float=direction.dot(right);var z: float=direction.dot(toward)
 release_walk();Input.action_press("harbor_right" if x>=0 else "harbor_left",absf(x));Input.action_press("harbor_down" if z>=0 else "harbor_up",absf(z))
func step() -> void:await physics_frame;g.tick(1.0/Engine.physics_ticks_per_second)
func walk_to(target: Vector3) -> bool:
 var delta: Vector3=target-g.walker.position;delta.y=0
 for frame in ceili((delta.length()/2.4+3)*Engine.physics_ticks_per_second):
  delta=target-g.walker.position;delta.y=0
  if delta.length()<.16:release_walk();return true
  steer(target);await step()
 release_walk();printerr("NATIVE PROMENADE WALK STOP ",g.walker.position," target ",target);return false
func route(points: Array) -> bool:
 for point in points:
  if not await walk_to(point):return false
 return true
func place(at: Vector3) -> void:
 release_walk();g.walker.position=at+Vector3.UP*.025;g.walker.velocity=Vector3.ZERO
 for frame in ceili(.15*Engine.physics_ticks_per_second):await step()
func attempt(target: Vector3,seconds: float) -> Dictionary:
 var min_x: float=g.walker.position.x;var max_z: float=g.walker.position.z;var south:=false
 for frame in ceili(seconds*Engine.physics_ticks_per_second):
  steer(target);await step();min_x=minf(min_x,g.walker.position.x);max_z=maxf(max_z,g.walker.position.z)
  for index in g.walker.get_slide_collision_count():
   var hit: KinematicCollision3D=g.walker.get_slide_collision(index)
   for contact_index in hit.get_collision_count():
    var body: Object=hit.get_collider(contact_index)
    if body is Node and body.is_in_group("harbor_quay_edge") and hit.get_normal(contact_index).z<-.8:south=true
 release_walk();return {"min_x":min_x,"max_z":max_z,"south":south}
func frame_view(at: Vector3,target: Vector3,fov_: float=48) -> void:
 g.camera._duration=0;g.camera.flying=false;g.camera.position=at;g.camera.look_at(target);g.camera.fov=fov_;g.world.tick(0,g.camera)
 if g.walker!=null:
  g.walker.update_art(0,Vector3.ZERO)
  if g.ui.bark_panel.visible:g.ui.position_actor_bark(g.camera.unproject_position(g.walker.global_position+Vector3.UP*2))
func shot(label: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,"capture "+label);shots.append(label)
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 check(not output.is_empty(),"explicit native capture destination supplied")
 if output.is_empty():quit(1);return
 DirAccess.make_dir_recursive_absolute(output)
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 g.start_arrival();g.skip_arrival();g.tick(0)
 g.walker.wrong_way_attempted.connect(func():events+=1)
 check(await route([Vector3(-43,.055,-7.3),Vector3(-43,.055,-3),Vector3(-52.3,.055,-3)]),"real cafe departure reaches the western border")
 frame_view(Vector3(-36,25,28),Vector3(-38,0,-6),57);await shot("01-full-native-L-tile-border")
 frame_view(Vector3(-43,9,17),Vector3(-50,.3,5),45);await shot("02-flush-aligned-L-junction")
 var west: Dictionary=await attempt(Vector3(-59,.055,-3),1.25)
 check(west.min_x>=-53.201 and west.min_x-.24>=-53.451 and g.walker.position.x< -53.1,"actual player footprint stops inside the annotated west seam")
 check(events==1 and g.ui.bark_panel.visible,"actual held input produces the existing single character line")
 frame_view(Vector3(-46,7,8),Vector3(-52.4,.9,-3),45);await shot("03-player-at-west-limit")
 check(await route([Vector3(-52.3,.055,-3),Vector3(-49,.055,-3)]) and not g.walker.wrong_way_latched,"player can walk immediately inward and rearm")
 await place(Vector3(-16,.055,13.8))
 frame_view(Vector3(-15,30,46),Vector3(-15,0,12),62);await shot("04-straight-long-coast-and-water")
 await place(Vector3(8,.055,13.8))
 var south: Dictionary=await attempt(Vector3(8,.055,18),1.4)
 check(south.south and south.max_z<15.1,"actual controller meets the new south rail before water")
 frame_view(Vector3(13,6,24),Vector3(8,.5,15.3),47);await shot("05-trimmed-main-quay-close")
 await place(Vector3(-19.2,.055,13.8))
 south=await attempt(Vector3(-16.5,.055,17.2),1.8)
 check(south.south and south.max_z<15.1,"actual diagonal walk meets the continuous former-step joint")
 frame_view(Vector3(-10,8,25),Vector3(-18,.5,15),45);await shot("06-former-quay-step-now-straight")
 g.return_title();g.start_arrival();g.skip_arrival();g.tick(0)
 var boarding: Array=[Vector3(-43,.055,-7.3)]
 for index in Profile.WALK_ROUTE.size():
  if index==6:boarding.append(Vector3(-1.8,.055,13.2));boarding.append(Vector3(13.5,.055,13.2))
  boarding.append(Profile.WALK_ROUTE[index])
 check(await route(boarding) and g.walker.position.y>2.2,"original cafe-to-deck route remains usable around actual porter")
 frame_view(Vector3(18,10,5),Vector3(10,3,-6),47);await shot("07-original-route-player-aboard")
 release_walk();g.return_title();g.tick(0)
 check(g.phase==&"title" and g.walker==null and not g.ui.bark_panel.visible,"original ship replay clears controller and old warning")
 await shot("08-original-ship-replay")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 if file!=null:file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":shots},"  "));file.close()
 else:check(false,"write native capture manifest")
 g.audio.shutdown();await create_timer(.25).timeout;g.free();await process_frame
 print("NATIVE HARBOR PROMENADE WALK ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
