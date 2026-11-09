extends SceneTree
## Real coastal floor, road seam, closed street-end and water-boundary regression.
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func ray(g,a: Vector3,b: Vector3) -> Dictionary:
 return g.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
func crossing(a: Vector3,motion: Vector3,mask: int=1) -> KinematicCollision3D:
 var actor:=CharacterBody3D.new();actor.collision_layer=2;actor.collision_mask=mask
 var collision:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.height=1.4;capsule.radius=.24;collision.shape=capsule;collision.position.y=.7;actor.add_child(collision)
 root.add_child(actor);actor.position=a
 var hit:=actor.move_and_collide(motion);actor.free();return hit
func contact_in_group(hit: KinematicCollision3D,group: String,normal: Vector3=Vector3.ZERO) -> bool:
 if hit==null:return false
 for contact_index in hit.get_collision_count():
  var body: Object=hit.get_collider(contact_index)
  if body is Node and body.is_in_group(group):
   if normal==Vector3.ZERO or hit.get_normal(contact_index).dot(normal)>.8:return true
 return false
func horizontal_faces_at(node: Node,point: Vector2,low: float,high: float) -> int:
 var count:=0
 for mesh in node.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh==null:continue
  var faces: PackedVector3Array=mesh.mesh.get_faces()
  for i in range(0,faces.size(),3):
   var a: Vector3=mesh.to_global(faces[i]);var b: Vector3=mesh.to_global(faces[i+1]);var c: Vector3=mesh.to_global(faces[i+2])
   if minf(a.y,minf(b.y,c.y))<low or maxf(a.y,maxf(b.y,c.y))>high:continue
   if absf(a.y-b.y)>.0001 or absf(a.y-c.y)>.0001:continue
   if Geometry2D.is_point_in_polygon(point,PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])):count+=1
 return count
func release_walk() -> void:
 for key in ["harbor_left","harbor_right","harbor_up","harbor_down"]:
  if InputMap.has_action(key):Input.action_release(key)
func steer(g,target: Vector3) -> void:
 var direction: Vector3=target-g.walker.position;direction.y=0;direction=direction.normalized()
 var right:=Vector3(g.camera.global_basis.x.x,0,g.camera.global_basis.x.z).normalized()
 var toward:=Vector3(g.camera.global_basis.z.x,0,g.camera.global_basis.z.z).normalized()
 var x: float=direction.dot(right);var z: float=direction.dot(toward)
 release_walk();Input.action_press("harbor_right" if x>=0 else "harbor_left",absf(x));Input.action_press("harbor_down" if z>=0 else "harbor_up",absf(z))
func walk_to(g,target: Vector3) -> bool:
 for frame in Engine.physics_ticks_per_second*14:
  var distance: Vector3=target-g.walker.position;distance.y=0
  if distance.length()<.18:release_walk();return true
  steer(g,target);await physics_frame
 release_walk();printerr("COAST WALK STOP ",g.walker.position," target ",target);return false
func run() -> void:
 # Scenic road slabs remain physical, while the protagonist stays east of the
 # dressed-pavement seam. The main quay now shares the plaza's straight coast.
 check(not Profile.contains_ground(Vector3(-73,.055,11)),"incoming seaside road remains scenic outside player walking ground")
 check(Profile.contains_ground(Vector3(-52.2,.055,-18)),"western public band remains walkable up to the closed north facade")
 check(not Profile.contains_ground(Vector3(-40,.055,16)),"removed south plaza extension is actual sea")
 check(not Profile.contains_ground(Vector3(-24,.055,16)),"removed connector excess is actual sea")
 check(Profile.contains_ground(Vector3(-20,.055,15.1)),"clipped connector still reaches the original quay")
 check(not Profile.contains_ground(Vector3(Profile.WEST_GATE_X-.2,.055,11)),"western seam excludes the scenic road before the player footprint crosses it")
 check(not Profile.wrong_way_exit(Vector3(-57,.055,-21.2)),"north street end is visibly closed rather than an invisible warning exit")
 check(not Profile.wrong_way_exit(Vector3(-52.2,.055,11)) and Profile.wrong_way_exit(Vector3(Profile.WEST_GATE_X-.2,.055,11)),"wrong-way warning belongs to the adjacent pavement/road seam")
 check(Profile.rearm_wrong_way(Vector3(-52.2,.055,11)),"returning inward along the public band rearms a future deliberate exit")
 check(Profile.wrong_way_exit(Vector3(-24,.055,-22.8)),"existing north promenade narrative gate remains")
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 await physics_frame;await physics_frame
 for point in [Vector3(-73,.055,11),Vector3(-65,.055,11),Vector3(-57,.055,-18),Vector3(-52,.055,11),Vector3(-50,.055,11)]:
  var support:=ray(g,point+Vector3.UP*.3,point-Vector3.UP*.4)
  check(not support.is_empty() and absf(Vector3(support.get("position",Vector3.ZERO)).y-.055)<.025,"real flush road floor at "+str(point))
 var end_hit:=crossing(Vector3(-57,.2,-19),Vector3(0,0,-5))
 check(contact_in_group(end_hit,"harbor_town_end_building"),"actual north facade stops a physical actor")
 check(not get_nodes_in_group("harbor_town_end_cargo").is_empty(),"modest street-end cargo has matching native solids")
 check(ray(g,Vector3(-51.6,.75,14),Vector3(-51.6,.75,14)+Vector3.RIGHT*.25).is_empty(),"former junction lamp no longer occupies the carriageway")
 check(not ray(g,Vector3(-52.1,.75,16.4),Vector3(-51.1,.75,16.4)).is_empty(),"moved junction lamp stands on the southern footway")
 for point in [Vector2(-40,16.3),Vector2(-24,16.3),Vector2(-73,18.2),Vector2(0,16.3)]:
  check(horizontal_faces_at(g.world.backdrop,point,-.2,.3)==0,"backdrop has no hidden foreground land at sea sample "+str(point))
  check(ray(g,Vector3(point.x,.4,point.y),Vector3(point.x,-.30,point.y)).is_empty(),"removed foreground has no remaining solid floor at "+str(point))
  check(horizontal_faces_at(g.world,point,-.2,.3)==0,"complete scene leaves real visible water at "+str(point))
 # Isolate the real rail bodies on a test query layer: unrelated retained pier
 # furnishings cannot hide an accidental rail across a boarding/cargo opening.
 var edge_mask:=1<<19
 for body in g.world.quay_edge.find_children("*","StaticBody3D",true,false):body.collision_layer=edge_mask
 for pair in [[Vector3(-73,.75,16.3),Vector3(0,0,2)],[Vector3(-52,.75,16.4),Vector3(2,0,0)],[Vector3(-40,.75,14.3),Vector3(0,0,2)],[Vector3(0,.75,14.2),Vector3(0,0,2)]]:
  var hit:=crossing(pair[0],pair[1],edge_mask);check(contact_in_group(hit,"harbor_quay_edge"),"coastline has actual capped sea rail from "+str(pair[0]))
 check(crossing(Vector3(-19,.75,16.5),Vector3(2,0,0),edge_mask)==null,"removed x=-18 coast step leaves open water with no ghost rail")
 var straight_joint:=crossing(Vector3(-18.7,.75,14.3),Vector3(1.4,0,2),edge_mask)
 check(contact_in_group(straight_joint,"harbor_quay_edge",Vector3.FORWARD),"plaza/main-quay rail joint is physically continuous on the straight z=15.4 edge")
 for x in [11.2,13.0,14.8]:check(crossing(Vector3(x,.2,3.2),Vector3(0,0,-2.2),edge_mask)==null,"original boarding gap remains open at x "+str(x))
 for z in [-29,-72,-110,-148,-186]:check(crossing(Vector3(-22,.2,z),Vector3(7,0,0),edge_mask)==null,"original cargo throat remains open at z "+str(z))
 for body in g.world.quay_edge.find_children("*","StaticBody3D",true,false):body.collision_layer=1
 var routes=g.world.town_routes
 check(horizontal_faces_at(routes,Vector2(-51.3,11),.053,.063)>0,"small road cobbles continue across the former east footway")
 check(horizontal_faces_at(g.world.plaza.street,Vector2(-49.38,10.85),.064,.066)==0,"old western threshold does not stripe the joined road")
 g.start_arrival();g.skip_arrival()
 for point in [Vector3(-43,.055,-7.3),Vector3(-41,.055,-5.5),Vector3(-45,.055,-3),Vector3(-49.5,.055,-3),Vector3(-52.2,.055,-3),Vector3(-52.2,.055,11),Vector3(-52.2,.055,14)]:
  var reached: bool=await walk_to(g,point);check(reached,"actual connected approach "+str(point))
  if not reached:break
 for frame in Engine.physics_ticks_per_second:
  steer(g,Vector3(-60,.055,14));await physics_frame
 release_walk();g.tick(0)
 check(g.ui.bark_panel.visible and g.walker.position.x>=Profile.WEST_GATE_X-.001 and g.walker.position.x-.24>=Profile.WEST_LINE_X-.001 and g.walker.position.y>.03,"actual west movement warns with the full capsule inside the pavement seam")
 check(await walk_to(g,Vector3(-52.2,.055,14)),"actor can return inward from the adjacent seam warning")
 check(not g.walker.wrong_way_latched,"inward pavement return rearms wrong-way warning")
 check(await walk_to(g,Vector3(-52.2,.055,-3)),"actor returns along the bounded west pavement")
 check(await walk_to(g,Vector3(-52.2,.055,-18)) and await walk_to(g,Vector3(-51.65,.055,-18)),"actor approaches the visible closed north facade through the narrow public band")
 g.route_bark_time=0;g.ui.hide_actor_bark()
 var building_contact:=false
 for frame in Engine.physics_ticks_per_second:
  steer(g,Vector3(-51.65,.055,-24));await physics_frame
  for index in g.walker.get_slide_collision_count():
   var hit: KinematicCollision3D=g.walker.get_slide_collision(index)
   if contact_in_group(hit,"harbor_town_end_building",Vector3.BACK):building_contact=true
 release_walk()
 check(building_contact and not g.ui.bark_panel.visible,"north end is stopped by its visible building rather than narrative rollback")
 release_walk();g.free();await process_frame
 print("HARBOR COASTAL LAYOUT ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
