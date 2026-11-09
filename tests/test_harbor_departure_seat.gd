extends SceneTree
var failures: Array=[]
var checks:=0
var g
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func has_property(object: Object,key: String) -> bool:
 for entry in object.get_property_list():
  if entry.name==key:return true
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
func finish() -> void:
 release_walk();g.free()
 print("HARBOR DEPARTURE SEAT ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func run() -> void:
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 check(g.world.plaza.has_method("update_departure_chair"),"departure chair has bounded safe-exit handoff")
 check(has_property(g.world.plaza,"departure_chair"),"visible initial chair has a real physics body")
 if not g.world.plaza.has_method("update_departure_chair") or not has_property(g.world.plaza,"departure_chair"):finish();return
 var chair: StaticBody3D=g.world.plaza.departure_chair
 check(chair!=null and chair.collision_layer==0,"seated title safely disables only the departure chair")
 g.start_arrival();g.skip_arrival();g.tick(0)
 await physics_frame;await physics_frame
 check(chair.collision_layer==0,"initial standing anchor is not trapped inside chair")
 for frame in Engine.physics_ticks_per_second*3:
  steer(Vector3(-43,.055,-7.3));await physics_frame;g.tick(0)
  if g.walker.position.z> -7.5:break
 release_walk()
 check(g.walker.position.z> -7.6,"real player can leave the initial seat")
 check(chair.collision_layer==1,"chair becomes solid after player clears its footprint")
 var contacted:=false
 for frame in Engine.physics_ticks_per_second*2:
  steer(Vector3(-43,.055,-10));await physics_frame;g.tick(0)
  for index in g.walker.get_slide_collision_count():
   var collision: KinematicCollision3D=g.walker.get_slide_collision(index)
   if collision.get_collider()==chair and absf(collision.get_normal().y)<.3:contacted=true
 release_walk()
 check(contacted and g.walker.position.z> -8.9,"returning player hits the actual chair rather than walking through it")
 g.return_title();g.tick(0)
 check(chair.collision_layer==0 and g.walker==null,"replay restores seated safe-exit state")
 g.start_arrival();g.skip_arrival();g.tick(0);await physics_frame
 check(chair.collision_layer==0 and g.walker!=null,"second Start restores an untrapped initial departure")
 finish()
