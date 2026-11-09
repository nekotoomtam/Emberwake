extends SceneTree
## Actual native v91 scene captures. This fixture opens only an unfocusable
## offscreen window, saves stills, then shuts down its own temporary process.
var g
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
func step() -> void:await physics_frame;g.tick(1.0/Engine.physics_ticks_per_second)
func walk_to(target: Vector3) -> bool:
 var offset: Vector3=target-g.walker.position;offset.y=0
 for frame in ceili((offset.length()/2.4+3)*Engine.physics_ticks_per_second):
  offset=target-g.walker.position;offset.y=0
  if offset.length()<.16:release_walk();return true
  steer(target);await step()
 release_walk();printerr("NATIVE CARGO GARDEN WALK STOP ",g.walker.position," target ",target);return false
func advance(seconds: float,world_only: bool=false) -> void:
 # Small steps honour the original native NPC movement limit. Yield physics
 # between steps so every subsequent route query observes the new people poses.
 for frame in ceili(seconds*60):
  await physics_frame
  if world_only:
   g.world.tick(1.0/60,g.camera)
   if g.walker!=null:g.walker.update_art(1.0/60,Vector3.ZERO)
  else:g.tick(1.0/60)
func frame_view(at: Vector3,target: Vector3,fov_: float=48) -> void:
 g.camera._duration=0;g.camera.flying=false;g.camera.position=at;g.camera.look_at(target);g.camera.fov=fov_
 g.world.tick(0,g.camera)
 if g.walker!=null:g.walker.update_art(0,Vector3.ZERO)
func activity() -> Array:
 var result: Array=[]
 for worker in g.world.cargo_street.workers:
  result.append({"id":str(worker.profile.id),"position":str(worker.position),"carrying":worker.carrying,"walking":worker.walking,"work":worker.work,"arrived":worker._arrived,"route_target":worker._target})
 return result
func shot(label: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 var image: Image=root.get_texture().get_image()
 check(image.save_png(output+"/"+label+".png")==OK,"capture "+label);shots.append(label)
 views.append({"name":label,"width":image.get_width(),"height":image.get_height(),"camera":str(g.camera.transform),"fov":g.camera.fov,"world_clock":g.world.clock,"caption_visible":g.ui.caption.visible,"workers":activity(),"feeder_position":str(g.world.square_garden.feeder.position),"bird_position":str(g.world.square_garden.feeding_pigeon.position)})
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 check(not output.is_empty(),"explicit native cargo/garden capture destination supplied")
 if output.is_empty():quit(1);return
 DirAccess.make_dir_recursive_absolute(output)
 root.content_scale_size=Vector2i(1280,800);root.size=Vector2i(1280,800)
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 var cargo=g.world.get("cargo_street");var garden=g.world.get("square_garden")
 check(cargo!=null and garden!=null,"actual native prologue contains both composed v91 helpers")
 if cargo==null or garden==null:g.audio.shutdown();g.free();quit(1);return
 g.start_arrival();g.skip_arrival();g.tick(0);await advance(.25)
 var reached: bool=await walk_to(Vector3(-43,.055,-7.3))
 reached=reached and await walk_to(Vector3(-43,.055,-3))
 check(reached and g.phase==&"play","ordinary controllable protagonist reaches the square through the real cafe exit")
 release_walk();await advance(.6);await shot("01-actual-play-square")
 # Inspection views remove only the fixed walking caption, leaving the same
 # production world, actors, animation, lighting, materials and physical props.
 g.ui.caption.visible=false;g.ui.bark_panel.visible=false
 frame_view(Vector3(-46,11,9),Vector3(-58,.7,-9),48);await advance(.3,true)
 await shot("02-delivery-street-overview")
 frame_view(Vector3(-51.4,7.8,-1.5),Vector3(-60,.9,-11.2),50);await advance(.3,true)
 var before: Array=[]
 for worker in cargo.workers:before.append(worker.position)
 await shot("03-covered-wagon-activity-a")
 await advance(4.0,true)
 await shot("04-covered-wagon-activity-b")
 var moved:=false
 for index in cargo.workers.size():moved=moved or cargo.workers[index].position.distance_to(before[index])>.5
 check(moved,"time-separated native wagon views contain actual moving workers")
 frame_view(Vector3(-35,13,16),Vector3(-36,1,-8),53);await advance(.2,true)
 await shot("05-fountain-square-garden")
 frame_view(Vector3(-36.2,6.8,4.5),Vector3(-28.8,.9,-4.8),47);await advance(.3,true)
 await shot("06-feeding-and-flowers")
 frame_view(Vector3(-45.8,7.2,8),Vector3(-48.1,1,-4.9),49);await advance(.3,true)
 await shot("07-west-tree-and-cafe-sightline")
 check(garden.feeder in g.world.plaza.people and garden.feeding_pigeon in g.world.plaza.birds,"native garden captures the original reused fountain actor and pigeon")
 check(g.world.townspeople.size()==8 and g.world.plaza.people.size()==8 and g.world.plaza.birds.size()==4,"native screenshots retain the original resident populations")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 if file!=null:
  file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":shots,"views":views,"offscreen":true,"native_window_position":str(DisplayServer.window_get_position()),"unfocusable":root.unfocusable},"  "));file.close()
 else:check(false,"write native cargo/garden evidence manifest")
 release_walk();g.audio.shutdown();await create_timer(.25).timeout;g.free();await process_frame
 print("NATIVE HARBOR CARGO GARDEN ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
