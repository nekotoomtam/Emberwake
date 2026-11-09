extends SceneTree
## v93 consumer evidence: actual prologue, actual player controller, native
## contacts and the one cafe suitcase through stand, walk, menu and replay.
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
func advance(seconds: float) -> void:
 for frame in ceili(seconds*Engine.physics_ticks_per_second):await step()
func walk_to(target: Vector3) -> bool:
 var offset: Vector3=target-g.walker.position;offset.y=0
 for frame in ceili((offset.length()/2.4+3)*Engine.physics_ticks_per_second):
  offset=target-g.walker.position;offset.y=0
  if offset.length()<.16:release_walk();return true
  steer(target);await step()
 release_walk();printerr("BENCH TRAVEL WALK STOP ",g.walker.position," target ",target);return false
func route(points: Array) -> bool:
 for point in points:
  if not await walk_to(point):return false
 return true
func contact(target: Vector3,owner: Node,seconds: float=1.35) -> bool:
 var touched:=false
 for frame in ceili(seconds*Engine.physics_ticks_per_second):
  steer(target);await step()
  for index in g.walker.get_slide_collision_count():
   var hit: KinematicCollision3D=g.walker.get_slide_collision(index)
   # One native slide can report pavement first and person/crate second.
   for contact_index in hit.get_collision_count():
    var body: Object=hit.get_collider(contact_index);var normal: Vector3=hit.get_normal(contact_index)
    if body is Node and (body==owner or owner.is_ancestor_of(body)) and Vector2(normal.x,normal.z).length()>.75:touched=true
 release_walk();return touched
func snapshot(people: Array) -> Array:
 var result: Array=[]
 for person in people:result.append([person.get_instance_id(),person.profile.duplicate(true)])
 return result
func person_counts() -> Array:
 return [g.world.townspeople.size(),g.world.crew.size(),g.world.pigeons.size(),g.world.plaza.people.size(),g.world.plaza.birds.size()]
func no_solids(at: Vector3) -> bool:
 var query:=PhysicsShapeQueryParameters3D.new();var shape:=CapsuleShape3D.new();shape.radius=.24;shape.height=1.34
 query.shape=shape;query.transform=Transform3D(Basis.IDENTITY,at+Vector3.UP*.73);query.collision_mask=1
 return g.world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func body_in_physics(body: PhysicsBody3D) -> bool:
 for child in body.get_children():
  if child is CollisionShape3D and child.shape!=null:
   var query:=PhysicsShapeQueryParameters3D.new();query.shape=child.shape;query.transform=child.global_transform;query.collision_mask=1
   for hit in body.get_world_3d().direct_space_state.intersect_shape(query,64):
    if hit.collider==body:return true
 return false
func rendered_seat_at(at: Vector3) -> bool:
 # Match the hip against actual rendered horizontal triangles in the existing
 # furniture mesh. Marker coordinates alone do not prove contact with a seat.
 for node in g.world.plaza.main.find_children("*","MeshInstance3D",true,false):
  var mesh: Mesh=node.mesh
  if mesh==null:continue
  for surface in mesh.get_surface_count():
   var arrays: Array=mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:=PackedInt32Array()
   if arrays[Mesh.ARRAY_INDEX]!=null:indices=arrays[Mesh.ARRAY_INDEX]
   var count_: int=indices.size() if not indices.is_empty() else vertices.size()
   for index in range(0,count_-2,3):
    var a: Vector3=node.global_transform*vertices[indices[index] if not indices.is_empty() else index]
    var b: Vector3=node.global_transform*vertices[indices[index+1] if not indices.is_empty() else index+1]
    var c: Vector3=node.global_transform*vertices[indices[index+2] if not indices.is_empty() else index+2]
    if absf(a.y-at.y)>.006 or absf(b.y-at.y)>.006 or absf(c.y-at.y)>.006:continue
    var point:=Vector2(at.x,at.z);var triangle:=PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])
    if Geometry2D.is_point_in_polygon(point,triangle):return true
    # The pelvis spans the bench's narrow gaps between timber slats.
    for edge in 3:
     if Geometry2D.get_closest_point_to_segment(point,triangle[edge],triangle[(edge+1)%3]).distance_to(point)<.065:return true
 return false
func feet_proportionate(actor) -> bool:
 # The protagonist's short chibi legs may dangle from a fixed bench. Do not
 # force adult-length shins just to reach the pavement, as the v92 fixture did.
 var hip: Vector3=actor.hip_anchor.global_position
 for foot in actor.feet:
  var at: Vector3=foot.global_position
  if at.y<.05 or at.y>=hip.y or hip.distance_to(at)>.48:return false
 return true
func finish() -> void:
 release_walk();g.audio.shutdown();g.free()
 print("HARBOR BENCH TRAVEL v93 ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func run() -> void:
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 var bench=g.world.get("bench_life");var cargo=g.world.get("passage_cargo");var luggage=g.world.plaza.get("travel_luggage")
 check(bench!=null and cargo!=null and luggage!=null,"actual prologue composes bench residents, passage goods and the reusable cafe bag")
 if bench==null or cargo==null or luggage==null:finish();return
 check(bench.actors.size()==3 and bench.couple.size()==2 and bench.single in bench.actors,"production composition contains one pair and one lone bench resident")
 check(bool(bench.couple[0].profile.male)!=bool(bench.couple[1].profile.male),"the seated pair has distinct male and female identities")
 check(person_counts()==[8,4,6,8,4],"all original town, deck, bird and plaza population arrays retain their counts")
 var town_before:=snapshot(g.world.townspeople);var crew_before:=snapshot(g.world.crew);var plaza_before:=snapshot(g.world.plaza.people)
 var private_ownership:=true;var tick_before: Array=[]
 for actor in bench.actors:
  private_ownership=private_ownership and actor.get_parent()==bench and actor not in g.world.townspeople and actor not in g.world.crew and actor not in g.world.plaza.people
  tick_before.append(actor.tick_count)
 check(private_ownership,"new seated identities belong exclusively to the bench helper")
 g.world.tick(.01,g.camera)
 var once:=true
 for index in bench.actors.size():once=once and bench.actors[index].tick_count==tick_before[index]+1
 check(once,"one production world tick advances each bench resident exactly once")
 await physics_frame
 for actor in bench.actors:
  check(rendered_seat_at(actor.hip_anchor.global_position) and feet_proportionate(actor),"rendered seat supports the hips while short chibi feet remain clear of paving: "+str(actor.name))
  var bent:=true
  for index in actor.knees.size():
   var hip: Vector3=actor.hip_anchor.global_position;var knee: Vector3=actor.knees[index].global_position;var foot: Vector3=actor.feet[index].global_position
   bent=bent and knee.distance_to(hip)<.42 and knee.y<=hip.y+.05 and foot.y<knee.y+.01
  check(bent and actor.sprite.texture!=null and is_equal_approx(actor.sprite.pixel_size,g.world.hero.pixel_size),"complete folded seated sprite shares the protagonist's pixel scale: "+str(actor.name))
 check(cargo.crates.size()==3 and cargo.bounds.end.x< -26.1 and cargo.bounds.position.z< -19 and cargo.bounds.end.y<1.6,"native modest crate group stays against the left passage wall")
 var crate_bodies:=true
 for body in cargo.crates:crate_bodies=crate_bodies and body_in_physics(body)
 check(crate_bodies,"each visible passage crate has a live production solid")
 var bag_id: int=luggage.get_instance_id();var visual_id: int=luggage.visual_root.get_instance_id();var floor_id: int=luggage.floor_body.get_instance_id()
 var rest_position: Vector3=luggage.visual_root.global_position
 check(luggage.state==&"resting" and body_in_physics(luggage.floor_body),"the one original cafe suitcase is physically present beside the seated protagonist")
 # Exercise the actual non-skipped production phase transitions with small
 # ticks. Only the arrival clock is fast-forwarded; stand duration stays .85s.
 g.start_arrival();g.phase_age=g.camera.intro_duration;g.tick(0)
 g.phase_age=2.0;g.tick(0)
 check(g.phase==&"rising" and g.walker==null,"normal coffee sequence reaches its original stand phase")
 await advance(.85*.65)
 check(luggage.state==&"lifting" and luggage.visual_root.global_position.distance_to(rest_position)>.08 and not body_in_physics(luggage.floor_body),"stand gesture lifts the same floor suitcase and releases its ground blocker")
 await advance(.85*.4)
 check(g.phase==&"play" and g.walker is CharacterBody3D and luggage.state==&"carried","normal stand completion hands the same bag to the real player")
 if g.walker==null:finish();return
 g.walker.wrong_way_attempted.connect(func():wrong_way_events+=1)
 check(await route([Vector3(-43,.055,-7.3),Vector3(-43,.055,-3),Vector3(-40.6,.055,-3)]),"real carrying player clears the original cafe chair and table exit")
 check(luggage.visual_root.global_position.distance_to(rest_position)>3 and not body_in_physics(luggage.floor_body),"cafe departure leaves no suitcase visual or active bag blocker at its original floor position")
 # Native camera-space input proves the visible hand/handle agreement while
 # the ordinary controller really moves in every direction.
 var actions: Dictionary={"front":"harbor_down","back":"harbor_up","left":"harbor_left","right":"harbor_right"}
 for direction in ["front","back","left","right"]:
  release_walk();Input.action_press(actions[direction]);var before: Vector3=g.walker.position
  await advance(.24)
  check(g.walker.position.distance_to(before)>.3 and g.walker.facing==direction and luggage.carry_facing==direction,"real moving controller uses the correct carried pose: "+direction)
  check(luggage.grip.global_position.distance_to(luggage.hand_world)<.025 and not body_in_physics(luggage.floor_body),"native bag handle meets the visible walking hand without collider drag: "+direction)
 release_walk()
 # Approach the front of each body; this distinguishes a person hit from the
 # pre-existing bench box, which sits behind the visible knees and boots.
 check(await route([Vector3(-40.6,.055,-3),Vector3(-40.6,.055,4.05)]),"original promenade gives a visible front approach to the occupied benches")
 for actor in bench.actors:
  var front: Vector3=actor.global_position+Vector3(0,0,1.55)
  check(await route([Vector3(g.walker.position.x,.055,4.05),front]),"actual player reaches the open front of "+str(actor.name))
  check(await contact(actor.human_blocker.global_position,actor),"seated person physically stops the actual player before the bench: "+str(actor.name))
  check(await walk_to(front),"person contact immediately permits retreat to the visible lane: "+str(actor.name))
 check(await route([Vector3(-28.1,.055,4.05),Vector3(-25,.055,4.05),Vector3(-25,.055,-3),Vector3(-25,.055,-18.0),Vector3(-25,.055,-21.7)]),"front bench lane and the centre of the crate passage remain continuously walkable")
 var clear:=true
 for z in [-21.7,-20.8,-19.8,-18.8,-17.8]:clear=clear and no_solids(Vector3(-25,.055,z))
 check(clear,"native player-sized clearance samples confirm the visibly empty north bypass")
 var gate_events:=wrong_way_events
 for frame in ceili(1.0*Engine.physics_ticks_per_second):steer(Vector3(-25,.055,-26));await step()
 release_walk()
 check(wrong_way_events==gate_events+1 and g.walker.wrong_way_latched and g.walker.position.z>=Profile.NORTH_GATE_Z-.001 and g.walker.position.z< -22.35,"original north stop and its existing warning remain at z=-22.5")
 check(await route([Vector3(-25,.055,-20.6),Vector3(-25,.055,-19.6)]),"north stop allows an immediate inward return beside the new crates")
 check(await contact(Vector3(-27.2,.055,-19.6),cargo),"wall-side crate really stops the actual player capsule")
 check(g.walker.position.x>cargo.bounds.end.x+.18,"native contact keeps the whole player on the visible side of the crate")
 check(await route([Vector3(-25,.055,-19.6),Vector3(-25,.055,-17.0),Vector3(-25,.055,-3)]),"crate contact retains the centre-lane bypass and ordinary square return")
 check(snapshot(g.world.townspeople)==town_before and snapshot(g.world.crew)==crew_before and snapshot(g.world.plaza.people)==plaza_before and person_counts()==[8,4,6,8,4],"bench and travel activity preserves original identity objects, appearance profiles and population ownership")
 # Preserve the prior porter bypass at the quay; no new shortcut teleports.
 var boarding: Array=[Vector3(-43,.055,-3),Vector3(-43,.055,-7.3)]
 for index in Profile.WALK_ROUTE.size():
  if index==6:boarding.append(Vector3(-1.8,.055,13.2));boarding.append(Vector3(13.5,.055,13.2))
  boarding.append(Profile.WALK_ROUTE[index])
 var aboard: bool=await route(boarding)
 check(aboard and g.walker.position.y>2.2 and luggage.state==&"carried","cafe-to-original-deck journey stays supported while carrying the suitcase")
 check(lowest_y>-.05,"bench, passage, cafe and boarding routes stay on real supported ground")
 g.return_title();await physics_frame;g.tick(0)
 check(g.phase==&"title" and g.walker==null and luggage.state==&"resting" and luggage.visual_root.global_position.is_equal_approx(rest_position) and body_in_physics(luggage.floor_body),"menu reset restores the original bag to its floor position and blocker")
 g.start_arrival();g.skip_arrival();g.tick(0);await step()
 check(g.phase==&"play" and luggage.state==&"carried" and not body_in_physics(luggage.floor_body),"intro skip uses the same one-time pickup and immediate playable lifecycle")
 g.skip_arrival();g.tick(0)
 check(luggage.get_instance_id()==bag_id and luggage.visual_root.get_instance_id()==visual_id and luggage.floor_body.get_instance_id()==floor_id,"stand, walk, reset and repeated skip reuse exactly one bag object, visual and floor body")
 check(g.world.bench_life.actors.size()==3 and person_counts()==[8,4,6,8,4],"replay creates no duplicate seated or original residents")
 g.return_title();g.tick(0)
 finish()
