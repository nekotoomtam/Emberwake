extends SceneTree
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var checks:=0
var failures: Array=[]
var events:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func release_walk() -> void:
 for key in ["harbor_left","harbor_right","harbor_up","harbor_down"]:Input.action_release(key)
func steer(g,target: Vector3) -> void:
 var direction: Vector3=target-g.walker.position;direction.y=0;direction=direction.normalized()
 var right:=Vector3(g.camera.global_basis.x.x,0,g.camera.global_basis.x.z).normalized()
 var toward:=Vector3(g.camera.global_basis.z.x,0,g.camera.global_basis.z.z).normalized()
 var x: float=direction.dot(right);var z: float=direction.dot(toward)
 release_walk();Input.action_press("harbor_right" if x>=0 else "harbor_left",absf(x));Input.action_press("harbor_down" if z>=0 else "harbor_up",absf(z))
func walk_to(g,target: Vector3) -> bool:
 for i in Engine.physics_ticks_per_second*10:
  var delta: Vector3=target-g.walker.position;delta.y=0
  if delta.length()<.18:release_walk();return true
  steer(g,target);await physics_frame
 release_walk();printerr("BARK WALK STOP ",g.walker.position," target ",target);return false
func attempt(g,seconds: float) -> void:
 for i in ceili(Engine.physics_ticks_per_second*seconds):
  steer(g,Vector3(-20.3,.055,-24));await physics_frame
 release_walk()
func run() -> void:
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 check(g.get("route_bark_time")!=null,"protagonist has a timed wrong-turn response")
 check(g.ui.get("bark_panel")!=null,"wrong-turn line has a visible actor speech panel")
 g.start_arrival();g.skip_arrival()
 check(g.walker.has_signal("wrong_way_attempted"),"actual movement reports the wrong turn")
 if g.get("route_bark_time")==null or g.ui.get("bark_panel")==null or not g.walker.has_signal("wrong_way_attempted"):
  g.free();await process_frame;print("WRONG WAY BARK ",checks," checks; FAIL",failures);quit(1);return
 g.walker.wrong_way_attempted.connect(func():events+=1)
 check(not g.ui.bark_panel.visible and events==0,"normal cafe handoff has no wrong-turn speech")
 for point in [Vector3(-41,.055,-5.5),Vector3(-36,.055,-3),Vector3(-23,.055,-3),Vector3(-20.3,.055,-3),Vector3(-20.3,.055,-19)]:
  var reached: bool=await walk_to(g,point);check(reached,"actual actor approaches north passage "+str(point))
  if not reached:break
 check(events==0,"merely walking toward passage does not fire a premature warning")
 await attempt(g,1.5)
 check(events==1 and g.walker.wrong_way_latched,"outward movement produces one warning event")
 check(g.ui.bark_panel.visible and g.ui.bark_text.text=="นั่นไม่ใช่ทางไปที่เรือนะ","protagonist visibly says the requested Thai line")
 check(g.walker.position.z>=Profile.NORTH_GATE_Z-.01 and g.walker.position.y>0,"narrative boundary retains safe grounded position")
 await attempt(g,1.5);check(events==1,"held outward input does not repeat the line")
 g.tick(.01);await process_frame
 check(root.get_visible_rect().encloses(g.ui.bark_panel.get_global_rect()),"speech remains within the logical viewport")
 check(g.ui.bark_panel.size.y<=100,"short speech does not stretch into a tall panel")
 var remaining: float=g.route_bark_time
 g.ui.open_settings();g.tick(.5)
 check(is_equal_approx(g.route_bark_time,remaining) and not g.walker.enabled,"settings pauses speech countdown and movement")
 g.ui.close_settings();g.tick(.1)
 check(g.walker.enabled and g.route_bark_time<remaining,"closing settings resumes existing speech")
 for i in 200:g.tick(1.0/60)
 check(g.route_bark_time==0 and not g.ui.bark_panel.visible,"line clears after its short display time")
 await attempt(g,.5);check(events==1,"holding boundary after timeout still does not spam")
 check(await walk_to(g,Vector3(-20.3,.055,-17.3)),"movement back toward the plaza remains available")
 check(not g.walker.wrong_way_latched,"returning to plaza rearms a future deliberate wrong turn")
 await attempt(g,2.0);check(events==2 and g.ui.bark_panel.visible,"a new deliberate wrong turn can speak again")
 g.return_title()
 check(g.walker==null and not g.ui.bark_panel.visible and g.route_bark_time==0,"title reset clears speech and actor")
 g.start_arrival();g.skip_arrival()
 check(g.phase==&"play" and not g.ui.bark_panel.visible and not g.walker.wrong_way_latched,"replay and skip start with clean warning state")
 release_walk()
 g.free();await process_frame
 print("WRONG WAY BARK ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
