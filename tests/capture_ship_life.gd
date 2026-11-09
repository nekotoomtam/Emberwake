extends SceneTree
var g
var output:=""
var shots: Array=[]
var failures: Array=[]
var checks:=0
func _initialize() -> void:
 root.unfocusable=true
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func advance(seconds: float) -> void:
 while seconds>.0001:
  g.tick(minf(seconds,1.0/60));seconds-=1.0/60
  await process_frame
func shot(label: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,"capture "+label);shots.append(label)
func frame_ship(offset: Vector3,target: Vector3) -> void:
 g.camera._duration=0;g.camera.flying=false
 g.camera.position=g.world.arrival.position+offset
 g.camera.look_at(g.world.arrival.position+target)
 g.camera.fov=42
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000));DirAccess.make_dir_recursive_absolute(output)
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 await advance(.6);await shot("01-title-closed-bow")
 g.ui.visible=false
 frame_ship(Vector3(-21,9,15),Vector3(-7,1,0))
 await shot("02-bow-three-quarter")
 frame_ship(Vector3(-27,4,.2),Vector3(-12,.8,0))
 await shot("03-bow-head-on")
 frame_ship(Vector3(-3,5,20),Vector3(-2,1,0))
 await shot("04-side-rest-water-a")
 var initial: Transform3D=g.world.arrival.motion.transform
 var first_clock: float=g.world.arrival.water_contact.phase_clock
 await advance(2);await shot("05-side-rest-water-b")
 check(g.world.arrival.motion.transform!=initial,"stationary ship pose advances")
 check(g.world.arrival.water_contact.phase_clock>first_clock,"water material clock advances")
 check(g.world.arrival.water_contact.contact_count==56,"curved water contacts built")
 check(absf(g.world.arrival.water_contact.global_position.y-g.world.sea_surface.MEAN_LEVEL)<.001,"water contact stays at mean sea level")
 g.start_arrival();await advance(2.5)
 g.ui.visible=false;frame_ship(Vector3(-3,5,20),Vector3(-2,1,0));await shot("06-cruising-water")
 check(g.world.arrival.water_contact.intensity>.42,"cruising wake stronger than stationary lap")
 await advance(5.6);frame_ship(Vector3(-18,9,21),Vector3(-2,1,0));await shot("07-docked-crew")
 check(g.world.arrival.docked,"native ship docks")
 for actor in g.world.arrival.crew:
  var at: Vector3=g.world.arrival.motion.to_global(Vector3(actor.position.x,2.865,actor.position.z))
  check(actor.global_position.distance_to(at)<.0001,"native crew feet follow deck")
 g.return_title();g.set_view(&"quay");await advance(1.3);g.ui.visible=false;await shot("08-moored-main-ship")
 g.return_title();g.ui.visible=true;await advance(.2);await shot("09-title-reset")
 var report:={"checks":checks,"failures":failures,"captures":shots}
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 g.audio.shutdown();await create_timer(.25).timeout;g.free();await process_frame
 print("NATIVE SHIP LIFE ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
