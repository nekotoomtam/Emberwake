extends SceneTree
## v94 consumer evidence: real prologue/controller, native contacts and the
## original cafe/deck journey. All route movement uses ordinary input.
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var g
var checks:=0
var failures: Array=[]
var lowest_y:=INF
var wrong_way_events:=0
func _initialize() -> void:call_deferred("run")
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
func step() -> void:
 await physics_frame;g.tick(1.0/Engine.physics_ticks_per_second)
 if g.walker!=null:lowest_y=minf(lowest_y,g.walker.position.y)
func walk_to(target: Vector3) -> bool:
 var offset: Vector3=target-g.walker.position;offset.y=0
 for frame in ceili((offset.length()/2.4+3)*Engine.physics_ticks_per_second):
  offset=target-g.walker.position;offset.y=0
  if offset.length()<.16:release_walk();return true
  steer(target);await step()
 release_walk();printerr("PASSENGER FORECOURT WALK STOP ",g.walker.position," target ",target);return false
func route(points: Array) -> bool:
 for point in points:
  if not await walk_to(point):return false
 return true
func contact(target: Vector3,owner: Node,seconds: float=1.65,moving: bool=false) -> bool:
 var touched:=false
 for frame in ceili(seconds*Engine.physics_ticks_per_second):
  steer(owner.global_position if moving else target);await step()
  for index in g.walker.get_slide_collision_count():
   var hit: KinematicCollision3D=g.walker.get_slide_collision(index)
   # Native floor and side normals can share a slide; inspect every contact.
   for contact_index in hit.get_collision_count():
    var body: Object=hit.get_collider(contact_index);var normal: Vector3=hit.get_normal(contact_index)
    if body is Node and (body==owner or owner.is_ancestor_of(body)) and Vector2(normal.x,normal.z).length()>.75:touched=true
 release_walk();return touched
func push(target: Vector3,seconds: float) -> void:
 for frame in ceili(seconds*Engine.physics_ticks_per_second):steer(target);await step()
 release_walk()
func snapshot(people: Array) -> Array:
 var result: Array=[]
 for person in people:result.append([person.get_instance_id(),person.profile.duplicate(true)])
 return result
func population() -> Array:
 return [g.world.townspeople.size(),g.world.crew.size(),g.world.pigeons.size(),g.world.plaza.people.size(),g.world.plaza.birds.size(),g.world.bench_life.actors.size()]
func body_in_physics(body: PhysicsBody3D) -> bool:
 for child in body.get_children():
  if child is CollisionShape3D and child.shape!=null:
   var query:=PhysicsShapeQueryParameters3D.new();query.shape=child.shape;query.transform=child.global_transform;query.collision_mask=1
   for hit in body.get_world_3d().direct_space_state.intersect_shape(query,64):
    if hit.collider==body:return true
 return false
func clear_capsule(at: Vector3) -> bool:
 var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.24;capsule.height=1.34
 query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,at+Vector3.UP*.73);query.collision_mask=1
 return g.world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func native_resources(node: Node,result: Dictionary) -> void:
 if node is MeshInstance3D:
  if node.mesh!=null:result[node.mesh.get_instance_id()]=true
  if node.material_override!=null:result[node.material_override.get_instance_id()]=true
 if node is CollisionShape3D and node.shape!=null:result[node.shape.get_instance_id()]=true
 for child in node.get_children():native_resources(child,result)
func active_materials(node: Node,result: Dictionary) -> void:
 if node is MeshInstance3D and node.mesh!=null:
  for surface in node.mesh.get_surface_count():
   var material: Material=node.get_active_material(surface)
   if material!=null:result[material.get_instance_id()]=true
 for child in node.get_children():active_materials(child,result)
func rendered_seat_at(main: Node,at: Vector3) -> bool:
 for node in main.find_children("*","MeshInstance3D",true,false):
  if node.mesh==null:continue
  for surface in node.mesh.get_surface_count():
   var arrays: Array=node.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:=PackedInt32Array()
   if arrays[Mesh.ARRAY_INDEX]!=null:indices=arrays[Mesh.ARRAY_INDEX]
   var count_: int=indices.size() if not indices.is_empty() else vertices.size()
   for index in range(0,count_-2,3):
    var a: Vector3=node.global_transform*vertices[indices[index] if not indices.is_empty() else index]
    var b: Vector3=node.global_transform*vertices[indices[index+1] if not indices.is_empty() else index+1]
    var c: Vector3=node.global_transform*vertices[indices[index+2] if not indices.is_empty() else index+2]
    if maxf(absf(a.y-at.y),maxf(absf(b.y-at.y),absf(c.y-at.y)))>.006:continue
    var point:=Vector2(at.x,at.z);var triangle:=PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])
    if Geometry2D.is_point_in_polygon(point,triangle):return true
    for edge in 3:
     if Geometry2D.get_closest_point_to_segment(point,triangle[edge],triangle[(edge+1)%3]).distance_to(point)<.065:return true
 return false
func finish() -> void:
 release_walk();g.audio.shutdown();g.free()
 print("HARBOR PASSENGER FORECOURT ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func run() -> void:
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 var forecourt=g.world.get("passenger_forecourt") if has_property(g.world,"passenger_forecourt") else null
 check(forecourt!=null,"actual prologue composes the passenger forecourt owner")
 if forecourt==null:finish();return
 check(forecourt.props!=null and forecourt.life!=null,"one forecourt owner composes native props and four private residents")
 var props=forecourt.props;var life=forecourt.life
 if props==null or life==null:finish();return
 await physics_frame
 check(life.actors.size()==4 and life.actors==[life.seated,life.watcher,life.reader,life.porter],"forecourt contains exactly the four approved roles")
 check(population()==[8,4,6,8,4,3],"original town, crew, birds, plaza and old bench cohorts retain their counts")
 var original: Array=g.world.townspeople+g.world.crew+g.world.plaza.people+g.world.bench_life.actors
 var original_before:=snapshot(original);var actors_before:=snapshot(life.actors)
 var tick_before: Array=[];var private_ids: Dictionary={};var native:=true
 for actor in life.actors:
  tick_before.append(actor.tick_count);private_ids[str(actor.profile.id)]=true
  native=native and actor.get_parent()==life and actor not in original and body_in_physics(actor.human_blocker)
  check(is_equal_approx(actor.sprite.pixel_size,.018) and is_equal_approx(actor.sprite.pixel_size,g.world.hero.pixel_size),"new passenger retains the exact normal human pixel scale: "+str(actor.name))
 check(native and private_ids.size()==4,"all four unique private residents own live native human footprints outside the old cohorts")
 g.world.tick(.013,g.camera)
 var once:=true
 for index in life.actors.size():once=once and life.actors[index].tick_count==tick_before[index]+1
 check(once,"one production World tick advances each new actor exactly once")
 var seat=life.seated;var folded:=true
 for index in seat.feet.size():
  var hip: Vector3=seat.hip_anchor.global_position;var knee: Vector3=seat.knees[index].global_position;var foot: Vector3=seat.feet[index].global_position
  folded=folded and hip.distance_to(knee)<.42 and hip.distance_to(foot)<.48 and foot.y>.05 and foot.y<knee.y+.01
 check(rendered_seat_at(props.main,seat.hip_anchor.global_position) and folded,"the exact v93 seated art has real bench hip support and proportionate clear knees/boots")
 var all_props:=true
 for body in props.prop_bodies:all_props=all_props and body_in_physics(body)
 check(all_props and props.prop_bodies.size()>=6,"every substantial native prop and both small rope coils own live fitted solids")
 var before_resources: Dictionary={};native_resources(forecourt,before_resources)
 var observed: Dictionary={};var reader_poses: Dictionary={};var porter_start: Vector3=life.porter.position;var porter_distance:=0.0
 for frame in ceili(20.0*Engine.physics_ticks_per_second):
  await step()
  for actor in life.actors:
   if actor.sprite.texture!=null:observed[actor.sprite.texture.get_instance_id()]=true
  reader_poses[life.reader.pose_index]=true
  porter_distance=maxf(porter_distance,porter_start.distance_to(life.porter.position))
 var after_resources: Dictionary={};native_resources(forecourt,after_resources)
 check(reader_poses.size()>=2 and porter_distance>.25,"ordinary small production ticks visibly change ticket reading and porter inspection/short travel")
 check(before_resources==after_resources and observed.size()<=64,"activity reuses bounded native geometry, materials, shapes and private sprite frames")
 # The input dictionary includes all inherited town/ship palettes. Measure the
 # materials actually used by this new geometry, and require reuse of the world.
 var used_materials: Dictionary={};active_materials(props.main,used_materials)
 var inherited_materials: Dictionary={}
 for material in g.world.materials.values():inherited_materials[material.get_instance_id()]=true
 var reused_materials:=true
 for id in used_materials:reused_materials=reused_materials and inherited_materials.has(id)
 print("FORECOURT BUDGET props=",props.geometry_count," forecourt=",forecourt.geometry_count," used_materials=",used_materials.size()," inherited_material_input=",props.materials.size())
 check(props.geometry_count>40 and forecourt.geometry_count<350 and used_materials.size()>0 and used_materials.size()<=12 and reused_materials,"new native detail uses a modest palette of actual inherited materials")
 var crossing_clear:=true
 for x in [-16.5,-14.0,-11.5,-9.0,-6.5,-4.0,-1.0]:crossing_clear=crossing_clear and clear_capsule(Vector3(x,.055,7.2))
 check(crossing_clear,"real player-sized capsule samples leave the broad central forecourt crossing empty")
 g.start_arrival();g.skip_arrival();g.tick(0);await step()
 check(g.phase==&"play" and g.walker is CharacterBody3D,"the ordinary intro handoff supplies the actual player controller")
 if g.walker==null:finish();return
 g.walker.wrong_way_attempted.connect(func():wrong_way_events+=1)
 var entered: bool=await route([Vector3(-43,.055,-7.3),Vector3(-43,.055,-3),Vector3(-25,.055,-3),Vector3(-22,.055,6),Vector3(-16.5,.055,7.2)])
 check(entered,"real player leaves the cafe and reaches the forecourt through the original connector")
 if not entered:finish();return
 check(await route([Vector3(-1.0,.055,7.2),Vector3(-16.5,.055,7.2)]),"actual controller crosses the entire open middle forecourt in both directions")
 # Bench contact is offset from its occupied middle; the board's west post
 # and the trolley front each have an unobstructed visible approach.
 var prop_probes: Array=[
  ["bench",Vector3(-13.55,.055,6.5),Vector3(-13.55,.055,3.9),props.bench_body],
  ["departure board",Vector3(-8.94,.055,6.5),Vector3(-8.94,.055,3.65),props.board_bodies[0]],
  ["parked trolley",Vector3(-2.8,.055,6.5),Vector3(-2.8,.055,4.1),props]]
 for probe in prop_probes:
  var front: Vector3=probe[1]
  var approached: bool=await route([Vector3(g.walker.position.x,.055,7.2),Vector3(front.x,.055,7.2),front])
  check(approached and await contact(probe[2],probe[3]),"visible "+probe[0]+" physically stops the real controller")
  check(await route([front,Vector3(front.x,.055,7.2)]),"the visible central bypass remains usable immediately after "+probe[0]+" contact")
 for actor in life.actors:
  var centre: Vector3=actor.human_blocker.global_position
  var front:=Vector3(centre.x,.055,6.7)
  var approached: bool=await route([Vector3(g.walker.position.x,.055,7.2),Vector3(front.x,.055,7.2),front])
  check(approached and await contact(centre,actor.human_blocker,2.1,true),"private passenger physically stops the real controller: "+str(actor.name))
  check(await route([front,Vector3(front.x,.055,7.2)]),"person contact permits immediate visible retreat and bypass: "+str(actor.name))
 check(await route([Vector3(-16.5,.055,7.2),Vector3(-22,.055,6),Vector3(-25,.055,-3),Vector3(-25,.055,-21.7)]),"the old north approach remains reachable from the forecourt")
 var before_events:=wrong_way_events
 await push(Vector3(-25,.055,-26),1.0)
 check(wrong_way_events==before_events+1 and g.walker.position.z>=Profile.NORTH_GATE_Z-.001 and g.walker.position.z< -22.35,"the original north warning/stop remains at z=-22.5")
 check(await route([Vector3(-25,.055,-3),Vector3(-52.3,.055,-3)]),"the original west pavement band remains reachable")
 before_events=wrong_way_events;await push(Vector3(-59,.055,-3),1.25)
 check(wrong_way_events==before_events+1 and g.walker.position.x>=Profile.WEST_GATE_X-.001 and g.walker.position.x<Profile.WEST_GATE_X+.1,"the original western capsule boundary and warning remain unchanged")
 check(await route([Vector3(-52.3,.055,-3),Vector3(-43,.055,-3),Vector3(-43,.055,-7.3)]),"the player can return inward to the original cafe exit")
 var boarding: Array=[Vector3(-43,.055,-7.3)]
 for index in Profile.WALK_ROUTE.size():
  if index==6:boarding.append(Vector3(-1.8,.055,13.2));boarding.append(Vector3(13.5,.055,13.2))
  boarding.append(Profile.WALK_ROUTE[index])
 var aboard: bool=await route(boarding)
 check(aboard and g.walker.position.y>2.2,"the unchanged cafe-to-original-deck journey and old porter bypass remain supported")
 var inbound: Array=[]
 for index in range(boarding.size()-2,-1,-1):inbound.append(boarding[index])
 check(aboard and await route(inbound),"the actual player returns through the same gangway mouth and cafe route")
 check(lowest_y>-.05,"central lane, all contact approaches and both deck journeys stay on real supported ground")
 check(snapshot(original)==original_before and snapshot(life.actors)==actors_before and population()==[8,4,6,8,4,3],"activity and journey preserve every original and private identity/profile/ownership")
 g.return_title();g.tick(0);g.start_arrival();g.skip_arrival();g.tick(0)
 check(snapshot(life.actors)==actors_before and life.actors.size()==4,"menu/skip replay retains exactly the same four private resident objects")
 finish()
