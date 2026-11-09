extends SceneTree
## Native opening-scene street checks. No persistence or test-only product hooks.
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var failures: Array=[]
var checks:=0
var lowest_y:=INF
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
 checks+=1
 if not value:failures.append(label);printerr("FAIL: ",label)
func has_property(object: Object,key: String) -> bool:
 for entry in object.get_property_list():
  if entry.name==key:return true
 return false
func finish(g) -> void:
 release_walk();g.free()
 print("HARBOR STREETS ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func release_walk() -> void:
 for key in ["harbor_left","harbor_right","harbor_up","harbor_down"]:
  if InputMap.has_action(key):Input.action_release(key)
func steer(g,target: Vector3) -> void:
 var direction: Vector3=target-g.walker.position;direction.y=0;direction=direction.normalized()
 var right:=Vector3(g.camera.global_basis.x.x,0,g.camera.global_basis.x.z).normalized()
 var toward:=Vector3(g.camera.global_basis.z.x,0,g.camera.global_basis.z.z).normalized()
 var x: float=direction.dot(right);var z: float=direction.dot(toward)
 release_walk()
 Input.action_press("harbor_right" if x>=0 else "harbor_left",absf(x))
 Input.action_press("harbor_down" if z>=0 else "harbor_up",absf(z))
func walk_to(g,target: Vector3) -> bool:
 for frame in Engine.physics_ticks_per_second*10:
  var delta: Vector3=target-g.walker.position;delta.y=0
  if delta.length()<.18:release_walk();return true
  steer(g,target);await physics_frame;g.tick(0)
  lowest_y=minf(lowest_y,g.walker.position.y)
 release_walk();print("STREET WALK STOP ",g.walker.position," target ",target)
 return false
func push_into(g,target: Vector3,group: String) -> bool:
 # A horizontal contact with the intended solid is required. A support-guard
 # rollback or contact with a neighbouring decorative prop cannot pass.
 var contact:=false
 for frame in ceili(1.8*Engine.physics_ticks_per_second):
  steer(g,target);await physics_frame;g.tick(0)
  for index in g.walker.get_slide_collision_count():
   var collision: KinematicCollision3D=g.walker.get_slide_collision(index)
   var body: Object=collision.get_collider();var normal: Vector3=collision.get_normal()
   if body is Node and body.is_in_group(group) and Vector2(normal.x,normal.z).length()>.8:contact=true
 release_walk();return contact
func mesh_vertices(node: Node) -> Array[Vector3]:
 var vertices: Array[Vector3]=[]
 if node is MeshInstance3D and node.mesh!=null:
  for surface in node.mesh.get_surface_count():
   var arrays: Array=node.mesh.surface_get_arrays(surface)
   for vertex in arrays[Mesh.ARRAY_VERTEX]:vertices.append(node.global_transform*vertex)
 for child in node.get_children():vertices.append_array(mesh_vertices(child))
 return vertices
func has_vertex(vertices: Array[Vector3],bounds: AABB) -> bool:
 for vertex in vertices:
  if bounds.has_point(vertex):return true
 return false
func vertex_bounds(vertices: Array[Vector3]) -> AABB:
 if vertices.is_empty():return AABB()
 var bounds:=AABB(vertices[0],Vector3.ZERO)
 for vertex in vertices:bounds=bounds.expand(vertex)
 return bounds
func solid_bounds(body: StaticBody3D) -> AABB:
 var bounds:=AABB();var first:=true
 for child in body.get_children():
  if child is CollisionShape3D and child.shape!=null and not child.disabled:
   var shape_bounds: AABB=child.global_transform*child.shape.get_debug_mesh().get_aabb()
   bounds=shape_bounds if first else bounds.merge(shape_bounds);first=false
 return bounds
func group_bounds(group: String) -> AABB:
 var bounds:=AABB();var first:=true
 for node in get_nodes_in_group(group):
  if node is StaticBody3D:
   var bound:=solid_bounds(node)
   bounds=bound if first else bounds.merge(bound);first=false
 return bounds
func supported_at(g,at: Vector3) -> bool:
 var query:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.5,at-Vector3.UP*.5,1)
 var hit: Dictionary=g.get_world_3d().direct_space_state.intersect_ray(query)
 return not hit.is_empty() and Vector3(hit.normal).y>.99 and absf(Vector3(hit.position).y-.055)<.025
func route(g,points: Array,label: String) -> bool:
 for index in points.size():
  var reached: bool=await walk_to(g,points[index])
  check(reached,label+" leg "+str(index+1))
  if not reached:return false
 return true
func run() -> void:
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 var plaza=g.world.plaza
 var street=plaza.get("street") if has_property(plaza,"street") else null
 check(street!=null,"opening composes the harbor loading street")
 if street==null:finish(g);return
 var vertices: Array[Vector3]=mesh_vertices(street)
 check(vertices.size()>300 and street.geometry_count>0,"lower street emits visible native geometry")
 var plaza_vertices: Array[Vector3]=mesh_vertices(plaza.main)
 # Wrong spacing, a displaced pole, or invisible geometry must break this row.
 var lamps: Array=[]
 for body in get_nodes_in_group("harbor_plaza_lamp"):
  if body is StaticBody3D and absf(body.global_position.z-4.8)<.01:lamps.append(body)
 lamps.sort_custom(func(a,b):return a.global_position.x<b.global_position.x)
 check(lamps.size()==4,"front promenade has one regular four-lamp row")
 var lamp_x: Array=[-48.5,-39.5,-30.5,-21.5]
 for index in mini(lamps.size(),lamp_x.size()):
  var pole: StaticBody3D=lamps[index];var bounds:=solid_bounds(pole)
  check(absf(pole.global_position.x-float(lamp_x[index]))<.01 and bounds.size.y>3.0 and bounds.size.x>.1,"front lamp "+str(index+1)+" has its real solid at the aligned datum")
  var base:=AABB(Vector3(lamp_x[index]-.3,.055,4.5),Vector3(.6,.4,.6))
  var crown:=AABB(Vector3(lamp_x[index]-.3,3.4,4.5),Vector3(.6,1,.6))
  check(has_vertex(plaza_vertices,base) and has_vertex(plaza_vertices,crown),"front lamp "+str(index+1)+" renders at its physical base and crown")
 await physics_frame;await physics_frame
 var road_points: Array[Vector3]=[Vector3(-46,.055,8.4),Vector3(-44.6,.055,14.2),Vector3(-33,.055,8.5),Vector3(-27,.055,10.5),Vector3(-24,.055,14.2)]
 for index in road_points.size():check(supported_at(g,road_points[index]),"loading road has actual continuous floor at sample "+str(index+1))
 var wagon_bounds:=group_bounds("harbor_loading_wagon")
 print("STREET WAGON actual solids ",wagon_bounds," authored ",street.cart_bounds)
 check(wagon_bounds.size.x>4.4 and wagon_bounds.size.z>1.8,"parked goods wagon has full-size solid body and wheel footprint")
 check(street.cart_bounds.position.distance_to(wagon_bounds.position)<.16 and street.cart_bounds.end.distance_to(wagon_bounds.end)<.16,"wagon advertised bounds match its actual physical extent")
 var wagon_vertices: Array[Vector3]=mesh_vertices(street.wagon_geometry)
 var visible_bounds:=vertex_bounds(wagon_vertices)
 check(wagon_vertices.size()>300 and has_vertex(wagon_vertices,AABB(Vector3(-42.7,.3,10.6),Vector3(4.6,1.7,2.4))),"goods wagon has rendered body and load over its occupied road position")
 var visible_min:=Vector2(visible_bounds.position.x,visible_bounds.position.z);var solid_min:=Vector2(wagon_bounds.position.x,wagon_bounds.position.z)
 var visible_end:=Vector2(visible_bounds.end.x,visible_bounds.end.z);var solid_end:=Vector2(wagon_bounds.end.x,wagon_bounds.end.z)
 check(visible_min.distance_to(solid_min)<.18 and visible_end.distance_to(solid_end)<.18,"wagon mesh and native solids occupy the same road footprint")
 check(not get_nodes_in_group("harbor_loading_cargo").is_empty(),"curbside cargo supplies real solids beside the parked wagon")
 g.start_arrival();g.skip_arrival();g.tick(0)
 check(g.phase==&"play" and g.walker is CharacterBody3D,"street exploration starts through the real playable opening")
 if g.walker==null:finish(g);return
 await physics_frame;await physics_frame
 # Leave the newly solid cafe table on its visible west side before rejoining
 # every original authored route landmark.
 var boarding: Array=[Vector3(-43,.055,-7.3)]
 for index in Profile.WALK_ROUTE.size():
  if index==6:boarding.append(Vector3(-1.8,.055,13.2));boarding.append(Vector3(13.5,.055,13.2))
  boarding.append(Profile.WALK_ROUTE[index])
 var outbound: bool=await route(g,boarding,"original cafe-to-deck route with table-side passage")
 check(outbound and g.walker.position.y>2.2,"new street layout preserves real gangway and original deck support")
 if not outbound:finish(g);return
 var inbound: Array=[]
 for index in range(boarding.size()-2,-1,-1):inbound.append(boarding[index])
 inbound.append(Vector3(-43,.055,-7.2))
 if not await route(g,inbound,"unchanged deck-to-cafe return"):finish(g);return
 # Approach the row in the visible plaza and prove its solid is encountered.
 if not await route(g,[Vector3(-39.5,.055,-3),Vector3(-39.5,.055,2.7)],"front-lamp approach"):finish(g);return
 var lamp_contact: bool=await push_into(g,Vector3(-39.5,.055,7),"harbor_plaza_lamp")
 check(lamp_contact and g.walker.position.z<4.55,"actual actor collides with the visible aligned lamp")
 if not await route(g,[Vector3(-38.5,.055,3.5),Vector3(-38.5,.055,7.1),Vector3(-40.4,.055,8.7)],"clear lamp-side passage to loading road"):finish(g);return
 var wagon_contact: bool=await push_into(g,Vector3(-40.4,.055,13.5),"harbor_loading_wagon")
 check(wagon_contact and g.walker.position.z<10.8,"actual actor cannot walk through the parked wagon body")
 # Pass the west end, the clear gap behind the wagon and in front of the cargo,
 # then the east shaft end. The removed foreground beyond z=15.4 is actual sea.
 var around: Array[Vector3]=[Vector3(-40.4,.055,8.7),Vector3(-44.6,.055,8.7),Vector3(-44.6,.055,11.8),Vector3(-44.6,.055,13.4),Vector3(-34.5,.055,13.4),Vector3(-34.5,.055,11.8),Vector3(-34.5,.055,8.7),Vector3(-40.4,.055,8.7)]
 var alternatives: bool=await route(g,around,"clear alternatives around wagon and curbside cargo")
 check(alternatives,"parked freight leaves both ends and the lower road passable")
 check(lowest_y>-.05,"all original and new street walks remain on supported harbor ground")
 finish(g)
