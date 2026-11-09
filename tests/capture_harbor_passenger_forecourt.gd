extends SceneTree
## Eight native photographs from the actual v94 prologue. No mockup art,
## resized humans, visible launch, alternate world or capture-only residents.
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var g
var forecourt
var output:=""
var checks:=0
var failures: Array=[]
var shots: Array=[]
var views: Array=[]
func _initialize() -> void:
 root.unfocusable=true
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func has_property(object: Object,label: String) -> bool:
 for property in object.get_property_list():
  if property.name==label:return true
 return false
func release_walk() -> void:
 for key in ["harbor_left","harbor_right","harbor_up","harbor_down"]:
  if InputMap.has_action(key):Input.action_release(key)
func steer(target: Vector3) -> void:
 var direction: Vector3=target-g.walker.position;direction.y=0;direction=direction.normalized()
 var right:=Vector3(g.camera.global_basis.x.x,0,g.camera.global_basis.x.z).normalized()
 var toward:=Vector3(g.camera.global_basis.z.x,0,g.camera.global_basis.z.z).normalized()
 var x: float=direction.dot(right);var z: float=direction.dot(toward)
 release_walk();Input.action_press("harbor_right" if x>=0 else "harbor_left",absf(x));Input.action_press("harbor_down" if z>=0 else "harbor_up",absf(z))
func step(world_only: bool=false) -> void:
 await physics_frame
 var dt:=1.0/Engine.physics_ticks_per_second
 if world_only:
  g.world.tick(dt,g.camera)
  if g.walker!=null:
   var movement: Vector3=g.walker.velocity;movement.y=0
   g.walker.update_art(0,movement);g.world.plaza.travel_luggage.update_carry(g.walker,g.camera)
 else:g.tick(dt)
func advance(seconds: float,world_only: bool=false) -> void:
 # Tiny real physics yields keep the porter's native route queries current.
 for frame in ceili(seconds*Engine.physics_ticks_per_second):await step(world_only)
func walk_to(target: Vector3) -> bool:
 var offset: Vector3=target-g.walker.position;offset.y=0
 for frame in ceili((offset.length()/2.4+3)*Engine.physics_ticks_per_second):
  offset=target-g.walker.position;offset.y=0
  if offset.length()<.16:release_walk();return true
  steer(target);await step()
 release_walk();printerr("NATIVE PASSENGER WALK STOP ",g.walker.position," target ",target);return false
func route(points: Array) -> bool:
 for point in points:
  if not await walk_to(point):return false
 return true
func inspection_ui() -> void:
 g.ui.menu.visible=false;g.ui.footer.visible=false;g.ui.back_button.visible=false;g.ui.caption.visible=false
func frame_view(at: Vector3,target: Vector3,fov_: float) -> void:
 g.camera._duration=0;g.camera.flying=false;g.camera.position=at;g.camera.look_at(target);g.camera.fov=fov_
 g.world.tick(0,g.camera)
 if g.walker!=null:
  var movement: Vector3=g.walker.velocity;movement.y=0
  g.walker.update_art(0,movement);g.world.plaza.travel_luggage.update_carry(g.walker,g.camera)
func shot(label: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 var image: Image=root.get_texture().get_image()
 check(image.save_png(output+"/"+label+".png")==OK,"native PNG written: "+label);shots.append(label)
 var people: Array=[]
 for actor in forecourt.life.actors:
  people.append({"id":str(actor.profile.id),"position":str(actor.global_position),"body_position":str(actor.human_blocker.global_position),"action":str(actor.get("action")),"pose":actor.get("pose_index"),"pixel_size":actor.sprite.pixel_size,"tick_count":actor.tick_count})
 views.append({"name":label,"width":image.get_width(),"height":image.get_height(),"camera":str(g.camera.transform),"fov":g.camera.fov,"phase":str(g.phase),"world_clock":g.world.clock,"caption_visible":g.ui.caption.visible,"menu_visible":g.ui.menu.visible,"footer_visible":g.ui.footer.visible,"walker":str(g.walker.position) if g.walker!=null else null,"people":people,"board_heading":forecourt.props.get_node("DeparturePierHeading").text,"board_times":forecourt.props.get_node("DepartureTimes").text})
func finish() -> void:
 release_walk()
 if not output.is_empty():
  var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
  if file!=null:
   file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":shots,"views":views,"offscreen":true,"native_window_position":str(DisplayServer.window_get_position()),"unfocusable":root.unfocusable,"no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS)},"  "));file.close()
  else:check(false,"write native passenger evidence manifest")
 if g!=null:g.audio.shutdown();await create_timer(.25).timeout;g.free();await process_frame
 print("NATIVE HARBOR PASSENGER FORECOURT ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 check(not output.is_empty(),"explicit native passenger capture destination supplied")
 if output.is_empty():await finish();return
 DirAccess.make_dir_recursive_absolute(output)
 root.content_scale_size=Vector2i(1280,800);root.size=Vector2i(1280,800)
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 forecourt=g.world.get("passenger_forecourt") if has_property(g.world,"passenger_forecourt") else null
 check(forecourt!=null,"actual prologue composes the production passenger forecourt")
 if forecourt==null:await finish();return
 check(forecourt.life.actors.size()==4 and forecourt.props.bench_body!=null,"native scene contains the one bench and all four private passengers")
 inspection_ui()
 # Quay-wide composition keeps the added groups, open public lane, ship and
 # old gangway in the same real perspective, like the user's empty-quay view.
 frame_view(Vector3(-6.6,11.8,22.5),Vector3(-7.8,.9,3.5),57);await advance(.25,true)
 await shot("01-passenger-forecourt-wide")
 frame_view(Vector3(-14.2,2.9,9.1),Vector3(-14.0,.95,3.8),48);await advance(.25,true)
 await shot("02-bench-traveller-and-sea-watcher")
 # Low front view gives the unchanged human bitmap scale and readable native
 # board lettering, with the ticket reader in front/right of its actual sign.
 frame_view(Vector3(-14.0,3.1,7.4),Vector3(-8.0,1.25,3.65),36);await advance(.25,true)
 await shot("03-pier-board-and-ticket-reader")
 frame_view(Vector3(-2.0,2.7,9.0),Vector3(-2.4,.80,4.25),47);await advance(.3,true)
 var porter_a: Vector3=forecourt.life.porter.position;var action_a: String=forecourt.life.porter.action
 await shot("04-luggage-trolley-and-porter-phase-a")
 await advance(4.2,true)
 check(forecourt.life.porter.position.distance_to(porter_a)>.15 or str(forecourt.life.porter.action)!=action_a,"two native trolley photographs observe different production porter phases")
 await shot("05-luggage-trolley-and-porter-phase-b")
 frame_view(Vector3(-14.0,3.1,7.4),Vector3(-8.0,1.25,3.65),36)
 var ticket_a: int=forecourt.life.reader.pose_index
 for frame in ceili(8.0*Engine.physics_ticks_per_second):
  await step(true)
  if forecourt.life.reader.pose_index!=ticket_a:break
 check(forecourt.life.reader.pose_index!=ticket_a,"time-separated native board photograph observes an actual different ticket gesture")
 await shot("06-pier-board-ticket-gesture-later")
 g.start_arrival();g.skip_arrival();g.tick(0);await advance(.1)
 var entered: bool=await route([Vector3(-43,.055,-7.3),Vector3(-43,.055,-3),Vector3(-25,.055,-3),Vector3(-22,.055,6),Vector3(-16.5,.055,7.2),Vector3(-10.0,.055,7.2)])
 check(entered,"actual carrying player walks from the cafe into the central forecourt")
 if not entered:await finish();return
 # Restore the actual gameplay caption and allow the ordinary follow camera
 # to settle. This photo does not set a capture camera or replace the HUD.
 g.ui.caption.visible=true;await advance(1.8)
 check(g.phase==&"play" and g.ui.caption.visible and not g.ui.menu.visible,"central-route image retains the ordinary gameplay camera and HUD")
 await shot("07-actual-gameplay-central-forecourt")
 inspection_ui()
 var gangway: bool=await route([Vector3(-16,.055,11.6),Vector3(-1.8,.055,11.6),Vector3(-1.8,.055,13.2),Vector3(13.5,.055,13.2),Vector3(13.5,.055,11.6),Vector3(13,.055,2.7)])
 check(gangway,"the same actual player reaches the original boarding mouth using the old porter bypass")
 frame_view(Vector3(17.0,7.9,9.5),Vector3(10.7,1.3,-.7),57);await advance(.25,true)
 await shot("08-original-boarding-mouth-context")
 check(shots.size()==8,"eight useful native scene photographs captured")
 await finish()
