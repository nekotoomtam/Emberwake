extends SceneTree
## Native final-pack visual evidence. Run only after source/integration QA.
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
func release_walk() -> void:
 for key in ["harbor_left","harbor_right","harbor_up","harbor_down"]:
  if InputMap.has_action(key):Input.action_release(key)
func frame_view(at: Vector3,target: Vector3,fov_: float=48) -> void:
 g.camera._duration=0;g.camera.flying=false;g.camera.position=at;g.camera.look_at(target);g.camera.fov=fov_;g.world.tick(0,g.camera)
 g.walker.update_art(0,Vector3.ZERO)
 if g.ui.bark_panel.visible:g.ui.position_actor_bark(g.camera.unproject_position(g.walker.global_position+Vector3.UP*2))
func shot(label: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,"capture "+label);shots.append(label)
func step() -> void:await physics_frame;g.tick(0)
func steer(target: Vector3) -> void:
 var direction: Vector3=target-g.walker.position;direction.y=0;direction=direction.normalized()
 var right:=Vector3(g.camera.global_basis.x.x,0,g.camera.global_basis.x.z).normalized()
 var toward:=Vector3(g.camera.global_basis.z.x,0,g.camera.global_basis.z.z).normalized()
 var x: float=direction.dot(right);var z: float=direction.dot(toward)
 release_walk();Input.action_press("harbor_right" if x>=0 else "harbor_left",absf(x));Input.action_press("harbor_down" if z>=0 else "harbor_up",absf(z))
func place(at: Vector3) -> void:
 release_walk();g.walker.position=at+Vector3.UP*.025;g.walker.velocity=Vector3.ZERO
 for frame in ceili(.15*Engine.physics_ticks_per_second):await step()
func walk_to(target: Vector3) -> bool:
 var delta: Vector3=target-g.walker.position;delta.y=0
 for frame in ceili((delta.length()/2.4+3)*Engine.physics_ticks_per_second):
  delta=target-g.walker.position;delta.y=0
  if delta.length()<.16:release_walk();return true
  steer(target);await step()
 release_walk();printerr("NATIVE COAST WALK STOP ",g.walker.position," target ",target);return false
func contact(target: Vector3,wanted: PhysicsBody3D,seconds: float=1.5) -> bool:
 var touched:=false
 for frame in ceili(seconds*Engine.physics_ticks_per_second):
  steer(target);await step()
  for index in g.walker.get_slide_collision_count():
   var hit: KinematicCollision3D=g.walker.get_slide_collision(index)
   for contact_index in hit.get_collision_count():
    var normal: Vector3=hit.get_normal(contact_index)
    if hit.get_collider(contact_index)==wanted and Vector2(normal.x,normal.z).length()>.8:touched=true
 release_walk();return touched
func body_named(group: String,label: String="") -> PhysicsBody3D:
 for body in get_nodes_in_group(group):
  if body is PhysicsBody3D and (label.is_empty() or body.name==label):return body
 return null
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 check(not output.is_empty(),"explicit capture destination supplied")
 if output.is_empty():quit(1);return
 DirAccess.make_dir_recursive_absolute(output)
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 g.start_arrival();g.skip_arrival();g.tick(0)
 check(g.walker is CharacterBody3D and g.phase==&"play","capture uses the production playable opening")
 await place(Vector3(-51.65,.055,-18))
 var building:=body_named("harbor_town_end_building")
 check(building!=null,"north terminal facade is composed")
 if building!=null:check(await contact(Vector3(-51.65,.055,-24),building,1.8),"actual player meets the north facade from the public band")
 frame_view(Vector3(-46,12,-6),Vector3(-57.5,1.9,-19.6),53);await shot("01-north-street-closed-building-cargo")
 await place(Vector3(-52.2,.055,8.5))
 check(await walk_to(Vector3(-49,.055,8.5)),"actual player crosses loading-road/public-pavement join")
 frame_view(Vector3(-43,13,25),Vector3(-53,1,9.8),54);await shot("02-connected-road-crossing")
 check(await walk_to(Vector3(-52.2,.055,11)) and await walk_to(Vector3(-52.2,.055,14)),"actual player walks the public band beside the scenic seaside road")
 for frame in Engine.physics_ticks_per_second:steer(Vector3(-60,.055,14));await step()
 release_walk();check(g.walker.position.x>=Profile.WEST_GATE_X-.001 and g.walker.position.x-.24>=Profile.WEST_LINE_X-.001 and g.ui.bark_panel.visible,"actual player stays inside the marked seam before the scenic road")
 frame_view(Vector3(-46,12,27),Vector3(-58,1,11),54);await shot("03-scenic-seaside-road-at-player-limit")
 frame_view(Vector3(-28,43,64),Vector3(-29,0,11),64);await shot("04-straight-main-coast-and-actual-water")
 var painter=g.world.life.portrait_pair[0]
 await place(Vector3(-24.3,.055,.8))
 check(await contact(Vector3(-21.8,.055,.8),painter.human_blocker),"real standing NPC blocks actual movement")
 frame_view(Vector3(-18,5,9),Vector3(-22.6,.8,.8),43);await shot("05-player-blocked-by-standing-person")
 check(await walk_to(Vector3(-24.3,.055,2)) and await walk_to(Vector3(-20.5,.055,2)),"standing NPC leaves ordinary nearby bypass")
 frame_view(Vector3(-18,5,9),Vector3(-22.6,.8,.8),43);await shot("06-clear-person-side-bypass")
 var reader=g.world.life.coffee_pair[0]
 var exceptions: Array[PhysicsBody3D]=[]
 for group in ["harbor_social_chair","harbor_social_table"]:
  for prop in get_nodes_in_group(group):
   if prop is PhysicsBody3D:g.walker.add_collision_exception_with(prop);exceptions.append(prop)
 await place(Vector3(-48.25,.055,-6.7))
 check(await contact(Vector3(-48.25,.055,-9.7),reader.human_blocker),"real seated NPC footprint blocks the actual player")
 for prop in exceptions:g.walker.remove_collision_exception_with(prop)
 frame_view(Vector3(-43,4.6,-.8),Vector3(-47.5,.8,-8.2),40);await shot("07-player-blocked-by-seated-person")
 var post:=body_named("harbor_public_prop","MarketFlagPost3")
 check(post!=null,"visible market post has its native body")
 if post!=null:
  await place(Vector3(17,.055,8))
  check(await contact(Vector3(17,.055,4.8),post),"visible post blocks actual walking")
  frame_view(Vector3(21,5.3,14),Vector3(17,.9,6),43);await shot("08-player-blocked-by-visible-prop")
  check(await walk_to(Vector3(18,.055,7.1)) and await walk_to(Vector3(18,.055,4.8)),"visible prop leaves a clear nearby bypass")
  frame_view(Vector3(21,5.3,14),Vector3(17,.9,6),43);await shot("09-clear-prop-side-bypass")
 var barrel:=body_named("harbor_public_deck_prop","DepartureSupplyBarrel")
 check(barrel!=null,"departure supplies have native deck bodies")
 if barrel!=null:
  await place(Vector3(16.6,2.315,-9.1))
  check(await contact(Vector3(16.6,2.315,-6.2),barrel),"actual player meets visible departure barrel")
  frame_view(Vector3(22,9,1),Vector3(16.6,3.1,-7.5),42);await shot("10-player-blocked-by-deck-supplies")
 release_walk();g.return_title();g.tick(0)
 check(g.phase==&"title" and g.walker==null and not g.ui.bark_panel.visible,"original ship replay clears walking and speech")
 await shot("11-original-ship-replay")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 if file!=null:file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":shots},"  "));file.close()
 else:check(false,"write capture manifest")
 g.audio.shutdown();await create_timer(.25).timeout;g.free();await process_frame
 print("NATIVE HARBOR COASTAL WALK ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
