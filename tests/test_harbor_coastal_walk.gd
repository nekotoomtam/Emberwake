extends SceneTree
## Consumer checks: real opening controller, native contact, and usable bypasses.
## Geometry/complete object inventories belong to the separate authored audit.
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var checks:=0
var failures: Array=[]
var lowest_y:=INF
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func release_walk() -> void:
 for key in ["harbor_left","harbor_right","harbor_up","harbor_down"]:
  if InputMap.has_action(key):Input.action_release(key)
func steer(g,target: Vector3) -> void:
 var direction: Vector3=target-g.walker.position;direction.y=0;direction=direction.normalized()
 var right:=Vector3(g.camera.global_basis.x.x,0,g.camera.global_basis.x.z).normalized()
 var toward:=Vector3(g.camera.global_basis.z.x,0,g.camera.global_basis.z.z).normalized()
 var x: float=direction.dot(right);var z: float=direction.dot(toward)
 release_walk();Input.action_press("harbor_right" if x>=0 else "harbor_left",absf(x));Input.action_press("harbor_down" if z>=0 else "harbor_up",absf(z))
func step(g) -> void:
 await physics_frame;g.tick(0)
 lowest_y=minf(lowest_y,g.walker.position.y)
func place(g,at: Vector3) -> void:
 # Independent native probes share the production actor. Only its starting
 # position is arranged; movement, support guard, masks and shapes stay real.
 release_walk();g.walker.position=at+Vector3.UP*.025;g.walker.velocity=Vector3.ZERO
 for frame in ceili(.15*Engine.physics_ticks_per_second):await step(g)
func walk_to(g,target: Vector3) -> bool:
 var distance: Vector3=target-g.walker.position;distance.y=0
 var budget:=ceili((distance.length()/2.4+3.0)*Engine.physics_ticks_per_second)
 for frame in budget:
  var delta: Vector3=target-g.walker.position;delta.y=0
  if delta.length()<.16:release_walk();return true
  steer(g,target);await step(g)
 release_walk();printerr("COAST WALK STOP ",g.walker.position," target ",target);return false
func route(g,points: Array) -> bool:
 for point in points:
  if not await walk_to(g,point):return false
 return true
func named_body(group: String,label: String) -> PhysicsBody3D:
 for body in get_nodes_in_group(group):
  if body is PhysicsBody3D and body.name==label:return body
 return null
func first_body(group: String) -> PhysicsBody3D:
 for body in get_nodes_in_group(group):
  if body is PhysicsBody3D:return body
 return null
func push_into(g,target: Vector3,wanted: PhysicsBody3D,seconds: float=1.4) -> bool:
 var touched:=false
 for frame in ceili(seconds*Engine.physics_ticks_per_second):
  steer(g,target);await step(g)
  for index in g.walker.get_slide_collision_count():
   var hit: KinematicCollision3D=g.walker.get_slide_collision(index)
   for contact_index in hit.get_collision_count():
    var normal: Vector3=hit.get_normal(contact_index)
    if hit.get_collider(contact_index)==wanted and Vector2(normal.x,normal.z).length()>.8:touched=true
 release_walk();return touched
func ray_body(g,a: Vector3,b: Vector3) -> PhysicsBody3D:
 var hit: Dictionary=g.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
 return hit.get("collider") as PhysicsBody3D
func person_probe(g,person,start: Vector3,target: Vector3,bypass: Array,label: String,ignore_seat: bool=false) -> void:
 var body: PhysicsBody3D=person.get("human_blocker")
 check(body!=null,label+" owns a native body")
 if body==null:return
 var exceptions: Array[PhysicsBody3D]=[]
 if ignore_seat:
  # Chairs are intentionally slightly wider than seated capsules. Isolate the
  # actual person's consumer contact, then immediately restore ordinary props.
  for group in ["harbor_social_chair","harbor_social_table"]:
   for prop in get_nodes_in_group(group):
    if prop is PhysicsBody3D:g.walker.add_collision_exception_with(prop);exceptions.append(prop)
 await place(g,start)
 var contact: bool=await push_into(g,target,body)
 var delta: Vector3=g.walker.position-person.global_position;delta.y=0
 check(contact and delta.length()>=.45,label+" stops the real controller with horizontal person contact")
 for prop in exceptions:g.walker.remove_collision_exception_with(prop)
 check(await route(g,bypass),label+" leaves an adjacent ordinary passage")
func prop_probe(g,body: PhysicsBody3D,start: Vector3,target: Vector3,bypass: Array,label: String) -> void:
 check(body!=null,label+" is present in the playable scene")
 if body==null:return
 await place(g,start)
 var contact: bool=await push_into(g,target,body)
 check(contact,label+" stops actual player movement with native side contact")
 check(await route(g,bypass),label+" has a clear nearby bypass")
func finish(g) -> void:
 release_walk();g.audio.shutdown();g.free()
 print("HARBOR COASTAL WALK ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func run() -> void:
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 g.start_arrival();g.skip_arrival();g.tick(0)
 check(g.phase==&"play" and g.walker is CharacterBody3D,"normal opening creates the real playable protagonist")
 if g.walker==null:finish(g);return
 await step(g);await step(g)
 # Keep every original route landmark, with a public-side pedestrian detour
 # around the newly solid porter rather than walking through the resident.
 var boarding: Array=[Vector3(-43,.055,-7.3)]
 for index in Profile.WALK_ROUTE.size():
  if index==6:boarding.append(Vector3(-1.8,.055,13.2));boarding.append(Vector3(13.5,.055,13.2))
  boarding.append(Profile.WALK_ROUTE[index])
 var boarded: bool=await route(g,boarding)
 check(boarded and g.walker.position.y>2.2,"original cafe-to-gangway/deck journey remains usable around real people")
 check(lowest_y>-.05,"original journey remains on actual supported ground")
 await place(g,Vector3(-52.2,.055,8.5))
 check(await route(g,[Vector3(-49,.055,8.5),Vector3(-52.2,.055,8.5)]),"loading road and public west pavement join in both directions without an internal fence")
 check(await route(g,[Vector3(-52.2,.055,11),Vector3(-52.2,.055,14)]),"west public band remains traversable beside the scenic incoming road")
 for frame in ceili(1.4*Engine.physics_ticks_per_second):steer(g,Vector3(-60,.055,14));await step(g)
 release_walk()
 check(g.walker.position.x>=Profile.WEST_GATE_X-.001 and g.walker.position.x<Profile.WEST_GATE_X+.2 and g.walker.position.x-.24>=Profile.WEST_LINE_X-.001 and g.ui.bark_panel.visible,"west pavement seam retains the actual player footprint before the scenic road")
 check(await route(g,[Vector3(-52.2,.055,14),Vector3(-52.2,.055,11)]),"adjacent seam limit lets the player return inward immediately")
 var building:=first_body("harbor_town_end_building")
 check(building!=null,"north street ends in a real building")
 if building!=null:
  await place(g,Vector3(-51.65,.055,-18))
  var contact: bool=await push_into(g,Vector3(-51.65,.055,-24),building,1.8)
  check(contact and g.walker.position.z> -20.85,"north facade visibly blocks the real controller before the closed street")
  check(await route(g,[Vector3(-51.65,.055,-17),Vector3(-52.2,.055,-17),Vector3(-52.2,.055,-15)]),"north frontage leaves the bounded public band usable beside retained cargo")
 var painter=g.world.life.portrait_pair[0]
 await person_probe(g,painter,Vector3(-24.3,.055,.8),Vector3(-21.8,.055,.8),[Vector3(-24.3,.055,2),Vector3(-20.5,.055,2)],"standing painter")
 var reader=g.world.life.coffee_pair[0]
 await person_probe(g,reader,Vector3(-48.25,.055,-6.7),Vector3(-48.25,.055,-9.7),[Vector3(-49.4,.055,-6.7),Vector3(-49.4,.055,-9.8),Vector3(-48.25,.055,-9.8)],"seated coffee reader",true)
 await prop_probe(g,named_body("harbor_public_prop","MarketFlagPost3"),Vector3(17,.055,8),Vector3(17,.055,4.8),[Vector3(18,.055,7.1),Vector3(18,.055,4.8)],"visible market flag post")
 var chair:=first_body("harbor_social_chair")
 if chair!=null:
  await prop_probe(g,chair,Vector3(-48.25,.055,-6.7),Vector3(-48.25,.055,-9.7),[Vector3(-49.4,.055,-6.7),Vector3(-49.4,.055,-9.8)],"visible cafe chair")
 var barrel:=named_body("harbor_public_deck_prop","DepartureSupplyBarrel")
 await prop_probe(g,barrel,Vector3(16.6,2.315,-9.1),Vector3(16.6,2.315,-6.2),[Vector3(17.65,2.315,-8.7),Vector3(17.65,2.315,-6.4)],"visible departure-deck barrel")
 await place(g,Vector3(-47,.055,13.7))
 var rail: PhysicsBody3D=ray_body(g,Vector3(-47,.65,14.3),Vector3(-47,.65,16.7))
 check(rail!=null and rail.is_in_group("harbor_quay_edge"),"trimmed plaza edge has its real sea-side rail")
 if rail!=null:
  check(await push_into(g,Vector3(-47,.055,18),rail) and g.walker.position.z<15.2,"straight coast rail blocks the player at the trimmed edge")
  check(await route(g,[Vector3(-47,.055,13.7),Vector3(-49,.055,13.7)]),"trimmed coast retains a usable land-side passage")
 check(ray_body(g,Vector3(-47,1,16.4),Vector3(-47,-.9,16.4))==null,"old foreground beyond the trimmed edge no longer supports an invisible walk")
 check(lowest_y>-.05,"all public street and obstacle bypass probes remain supported")
 finish(g)
