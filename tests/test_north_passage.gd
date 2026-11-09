extends SceneTree
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func high_mouth_faces(node: Node3D) -> int:
 var region:=AABB(Vector3(-19.92,.4,-24.5),Vector3(.95,1.4,7.0))
 var count:=0
 for mesh in node.find_children("*","MeshInstance3D",true,false):
  var faces: PackedVector3Array=mesh.mesh.get_faces()
  for i in range(0,faces.size(),3):
   var a: Vector3=mesh.to_global(faces[i]);var b: Vector3=mesh.to_global(faces[i+1]);var c: Vector3=mesh.to_global(faces[i+2])
   var low: Vector3=a.min(b).min(c);var high: Vector3=a.max(b).max(c)
   # Include thin axis-aligned faces rather than dropping zero-thickness bounds.
   if region.intersects(AABB(low-Vector3.ONE*.0001,high-low+Vector3.ONE*.0002)):count+=1
 return count
func ray(g,at: Vector3,end: Vector3) -> Dictionary:
 return g.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at,end,1))
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
 release_walk();printerr("NORTH WALK STOP ",g.walker.position," target ",target);return false
func run() -> void:
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 await physics_frame;await physics_frame
 var rail_faces:=high_mouth_faces(g.world.quay_edge)
 var shore_faces:=high_mouth_faces(g.world.backdrop)
 check(rail_faces==0,"visible high rail and end posts removed at passage mouth")
 check(shore_faces==0,"chunky old shore post removed beside passage mouth")
 print("NORTH MOUTH HIGH FACES rail=",rail_faces," backdrop=",shore_faces)
 check(ray(g,Vector3(-20.6,.75,-18.8),Vector3(-19.0,.75,-18.8)).is_empty(),"no invisible old rail collider remains in cleared mouth")
 check(not ray(g,Vector3(-20.6,.75,-15),Vector3(-19,.75,-15)).is_empty(),"sea rail resumes beyond the local mouth opening")
 check(not ray(g,Vector3(0,.75,3.2),Vector3(0,.75,1)).is_empty(),"original foreground safety rail remains")
 check(not ray(g,Vector3(21,.75,10),Vector3(23,.75,10)).is_empty(),"far quay end safety rail remains")
 check(not ray(g,Vector3(-20.3,.4,-19),Vector3(-20.3,-.2,-19)).is_empty(),"mouth approach has actual supported ground")
 g.start_arrival();g.skip_arrival()
 for point in [Vector3(-41,.055,-5.5),Vector3(-36,.055,-3),Vector3(-23,.055,-3),Vector3(-20.3,.055,-3),Vector3(-20.3,.055,-19)]:
  var reached: bool=await walk_to(g,point);check(reached,"actual grounded approach "+str(point))
  if not reached:break
 for i in Engine.physics_ticks_per_second:
  steer(g,Vector3(-18,.055,-19));await physics_frame
 release_walk()
 check(g.walker.position.x<=-19.7 and g.walker.position.y>.03,"water-edge support guard still prevents falling through the opened mouth")
 check(not g.ui.bark_panel.visible,"lateral sea-edge attempt does not produce wrong-route dialogue")
 check(await walk_to(g,Vector3(-20.3,.055,-19)),"player can return to center of mouth")
 for i in Engine.physics_ticks_per_second*2:
  steer(g,Vector3(-20.3,.055,-24));await physics_frame
 release_walk();g.tick(0)
 check(g.ui.bark_panel.visible and g.ui.bark_text.text=="นั่นไม่ใช่ทางไปที่เรือนะ","actual northward attempt still raises the requested character line")
 check(g.walker.position.z>=Profile.NORTH_GATE_Z-.01 and g.walker.position.y>.03,"wrong route retains supported position without a replacement fence")
 check(await walk_to(g,Vector3(-20.3,.055,-17.3)),"actor can immediately walk back toward original ship route")
 release_walk();g.free();await process_frame
 print("NORTH PASSAGE ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
