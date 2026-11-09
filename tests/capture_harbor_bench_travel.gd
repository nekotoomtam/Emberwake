extends SceneTree
## Native v92 photographs from the actual prologue. This temporary process is
## offscreen and unfocusable from initialization until its own clean shutdown.
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var g
var luggage
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
   g.walker.update_art(0,movement);luggage.update_carry(g.walker,g.camera)
 else:g.tick(dt)
func advance(seconds: float,world_only: bool=false) -> void:
 # Yield small native physics steps so NPC route queries see current bodies.
 for frame in ceili(seconds*Engine.physics_ticks_per_second):await step(world_only)
func walk_to(target: Vector3) -> bool:
 var offset: Vector3=target-g.walker.position;offset.y=0
 for frame in ceili((offset.length()/2.4+3)*Engine.physics_ticks_per_second):
  offset=target-g.walker.position;offset.y=0
  if offset.length()<.16:release_walk();return true
  steer(target);await step()
 release_walk();printerr("NATIVE BENCH TRAVEL WALK STOP ",g.walker.position," target ",target);return false
func frame_view(at: Vector3,target: Vector3,fov_: float=48) -> void:
 g.camera._duration=0;g.camera.flying=false;g.camera.position=at;g.camera.look_at(target);g.camera.fov=fov_
 g.world.tick(0,g.camera)
 if g.walker!=null:
  var movement: Vector3=g.walker.velocity;movement.y=0
  g.walker.update_art(0,movement);luggage.update_carry(g.walker,g.camera)
 elif g.phase==&"rising":
  luggage.update_stand(clampf(g.phase_age/.85,0,1),g.world.hero,g.camera)
func shot(label: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 var image: Image=root.get_texture().get_image()
 check(image.save_png(output+"/"+label+".png")==OK,"capture "+label);shots.append(label)
 var people: Array=[]
 for actor in g.world.bench_life.actors:
  people.append({"id":str(actor.profile.id),"position":str(actor.global_position)})
 views.append({"name":label,"width":image.get_width(),"height":image.get_height(),"camera":str(g.camera.transform),"fov":g.camera.fov,"phase":str(g.phase),"world_clock":g.world.clock,"caption_visible":g.ui.caption.visible,"bench_residents":people,"bag_state":str(luggage.state),"bag_instance":luggage.get_instance_id(),"bag_position":str(luggage.visual_root.global_position),"grip":str(luggage.grip.global_position),"hand":str(luggage.hand_world),"facing":str(g.walker.facing) if g.walker!=null else "seated"})
func walking_photo(direction: String,label: String,gameplay_view: bool=false) -> void:
 var actions: Dictionary={"front":"harbor_down","back":"harbor_up","left":"harbor_left","right":"harbor_right"}
 release_walk();Input.action_press(actions[direction])
 await advance(.23,not gameplay_view)
 check(g.walker.facing==direction and luggage.carry_facing==direction,"actual camera-relative carried pose faces "+direction)
 check(luggage.state==&"carried" and luggage.grip.global_position.distance_to(luggage.hand_world)<.025,"visible handle follows walking hand in "+direction)
 await shot(label);release_walk()
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 check(not output.is_empty(),"explicit native bench/travel capture destination supplied")
 if output.is_empty():quit(1);return
 DirAccess.make_dir_recursive_absolute(output)
 root.content_scale_size=Vector2i(1280,800);root.size=Vector2i(1280,800)
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 luggage=g.world.plaza.get("travel_luggage")
 check(g.world.get("bench_life")!=null and g.world.get("passage_cargo")!=null and luggage!=null,"actual prologue composes all three v92 additions")
 if g.world.get("bench_life")==null or g.world.get("passage_cargo")==null or luggage==null:
  g.audio.shutdown();g.free();quit(1);return
 # Low front cameras stay below the cafe canopy and show contact with the seat.
 # Inspection photos hide existing title controls and the fixed caption.
 # The real gameplay photo below retains its ordinary follow camera and HUD.
 g.ui.cinematic(true)
 g.ui.caption.visible=false
 frame_view(Vector3(-36.2,2.65,8.0),Vector3(-36.2,.90,2.6),44);await advance(.2,true)
 await shot("01-bench-couple-front")
 frame_view(Vector3(-28.1,2.6,7.9),Vector3(-28.1,.90,2.6),44);await advance(.2,true)
 await shot("02-bench-single-front")
 frame_view(Vector3(-36,10.2,17.8),Vector3(-36,.7,2.4),58);await advance(.2,true)
 await shot("03-bench-promenade-clear-lane")
 frame_view(Vector3(-21.6,3.5,-15.2),Vector3(-25.8,.75,-19.5),53);await advance(.2,true)
 await shot("04-wall-crates-and-north-bypass")
 frame_view(Profile.CAFE+Vector3(-.55,1.72,4.4),Profile.CAFE+Vector3(-.40,.80,.12),46);await advance(.2,true)
 check(luggage.state==&"resting" and luggage.floor_body.collision_layer==1,"same visible cafe suitcase rests on a physical floor body")
 await shot("05-cafe-seated-ground-bag")
 var bag_id: int=luggage.get_instance_id()
 # Freeze one point of the real production stand phase; retain its hero art
 # and production lift interpolation rather than replacing either with props.
 g.start_arrival();g.phase=&"rising";g.phase_age=.85*.65;g.world.sip_enabled=false;g.tick(0)
 frame_view(Profile.CAFE+Vector3(-.55,1.72,4.4),Profile.CAFE+Vector3(-.40,.80,.12),46)
 check(luggage.state==&"lifting" and luggage.get_instance_id()==bag_id,"production stand gesture lifts the original suitcase")
 await shot("06-cafe-standing-mid-lift")
 g.tick(.85);await advance(.1)
 check(g.phase==&"play" and g.walker!=null,"real stand phase releases the normal protagonist")
 if g.walker==null:g.audio.shutdown();g.free();quit(1);return
 var reached: bool=await walk_to(Vector3(-43,.055,-7.3))
 reached=reached and await walk_to(Vector3(-43,.055,-3))
 reached=reached and await walk_to(Vector3(-40.6,.055,-3))
 check(reached,"real carrying player leaves cafe through the original safe exit")
 # One unmodified follow-camera/UI view, followed by closer views. Every new
 # camera is established BEFORE native input chooses its camera-space facing.
 g.ui.caption.visible=true;await advance(.45)
 await walking_photo("front","07-actual-gameplay-walking-front",true)
 g.ui.caption.visible=false
 var at: Vector3=g.walker.position
 frame_view(at+Vector3(0,2.05,5.0),at+Vector3(0,.90,0),40)
 await walking_photo("back","08-carry-detail-back")
 at=g.walker.position;frame_view(at+Vector3(0,2.05,5.0),at+Vector3(0,.90,0),40)
 await walking_photo("left","09-carry-detail-left")
 at=g.walker.position;frame_view(at+Vector3(0,2.05,5.0),at+Vector3(0,.90,0),40)
 await walking_photo("right","10-carry-detail-right")
 check(luggage.get_instance_id()==bag_id and luggage.floor_body.collision_layer==0,"all walk photographs carry one original bag with its floor blocker released")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 if file!=null:
  file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":shots,"views":views,"offscreen":true,"native_window_position":str(DisplayServer.window_get_position()),"unfocusable":root.unfocusable,"no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS)},"  "));file.close()
 else:check(false,"write native bench/travel evidence manifest")
 release_walk();g.audio.shutdown();await create_timer(.25).timeout;g.free();await process_frame
 print("NATIVE HARBOR BENCH TRAVEL ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
