extends SceneTree
## Real controller acceptance for the west pavement seam and trimmed main quay.
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
const WEST_SEAM:=-53.45
const WEST_CENTRE:=-53.20
const SOUTH_EDGE:=15.4
var checks:=0
var failures: Array=[]
var events:=0
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
 await physics_frame;g.tick(1.0/Engine.physics_ticks_per_second)
 lowest_y=minf(lowest_y,g.walker.position.y)
func walk_to(g,target: Vector3) -> bool:
 var offset: Vector3=target-g.walker.position;offset.y=0
 for frame in ceili((offset.length()/2.4+3)*Engine.physics_ticks_per_second):
  offset=target-g.walker.position;offset.y=0
  if offset.length()<.16:release_walk();return true
  steer(g,target);await step(g)
 release_walk();printerr("PROMENADE WALK STOP ",g.walker.position," target ",target);return false
func route(g,points: Array) -> bool:
 for point in points:
  if not await walk_to(g,point):return false
 return true
func place(g,at: Vector3) -> void:
 # Independent coast probes retain the real controller, support guard and mask.
 release_walk();g.walker.position=at+Vector3.UP*.025;g.walker.velocity=Vector3.ZERO
 for frame in ceili(.15*Engine.physics_ticks_per_second):await step(g)
func attempt(g,target: Vector3,seconds: float) -> Dictionary:
 var min_x: float=g.walker.position.x;var max_z: float=g.walker.position.z
 var side_contact:=false;var south_contact:=false;var east_contact:=false
 for frame in ceili(seconds*Engine.physics_ticks_per_second):
  steer(g,target);await step(g)
  min_x=minf(min_x,g.walker.position.x);max_z=maxf(max_z,g.walker.position.z)
  for index in g.walker.get_slide_collision_count():
   var hit: KinematicCollision3D=g.walker.get_slide_collision(index)
   # A slide can contain floor and wall contacts together. Inspect every
   # native contact; index0 alone can be the upward floor normal.
   for contact_index in hit.get_collision_count():
    var body: Object=hit.get_collider(contact_index);var normal: Vector3=hit.get_normal(contact_index)
    if body is Node and body.is_in_group("harbor_quay_edge"):
     side_contact=side_contact or Vector2(normal.x,normal.z).length()>.8
     south_contact=south_contact or normal.z<-.8
     east_contact=east_contact or normal.x<-.8
 release_walk()
 return {"min_x":min_x,"max_z":max_z,"side":side_contact,"south":south_contact,"east":east_contact}
func capsule_radius(g) -> float:
 for child in g.walker.get_children():
  if child is CollisionShape3D and child.shape is CapsuleShape3D:return child.shape.radius
 return INF
func kept_west_footprint(result: Dictionary,radius: float) -> bool:
 return result.min_x>=WEST_CENTRE-.001 and result.min_x-radius>=WEST_SEAM-.001
func floor_at(g,at: Vector3) -> Dictionary:
 return g.world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP,at-Vector3.UP*.9,1))
func ground_mesh_in_strip(node: Node,rect: Rect2) -> bool:
 # Inspect the actual native flat triangles at paving/slab-top height, not
 # counters or declared bounds. Water is owned by a separate scene node.
 if node is MeshInstance3D and node.mesh!=null:
  var corners:=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
  for surface in node.mesh.get_surface_count():
   var arrays: Array=node.mesh.surface_get_arrays(surface)
   var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   for index in range(0,vertices.size()-2,3):
    var a: Vector3=node.global_transform*vertices[index];var b: Vector3=node.global_transform*vertices[index+1];var c: Vector3=node.global_transform*vertices[index+2]
    if minf(a.y,minf(b.y,c.y))<-.08 or maxf(a.y,maxf(b.y,c.y))>.25:continue
    if absf((b-a).cross(c-a).normalized().y)<.99:continue
    var triangle:=PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])
    var bound:=Rect2(triangle[0],Vector2.ZERO).expand(triangle[1]).expand(triangle[2])
    if rect.intersects(bound,true) and not Geometry2D.intersect_polygons(triangle,corners).is_empty():return true
 for child in node.get_children():
  if ground_mesh_in_strip(child,rect):return true
 return false
func finish(g) -> void:
 release_walk();g.audio.shutdown();g.free()
 print("HARBOR PROMENADE WALK ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func run() -> void:
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 g.start_arrival();g.skip_arrival();g.tick(0)
 check(g.phase==&"play" and g.walker is CharacterBody3D,"normal opening hands control to the real protagonist")
 if g.walker==null:finish(g);return
 g.walker.wrong_way_attempted.connect(func():events+=1)
 await step(g);await step(g)
 var radius:=capsule_radius(g)
 check(is_equal_approx(radius,.24),"western seam is tested with the actual 24cm player capsule")
 if not await route(g,[Vector3(-43,.055,-7.3),Vector3(-43,.055,-3),Vector3(-52.3,.055,-3)]):
  check(false,"cafe initial exit reaches the west pavement band");finish(g);return
 check(events==0,"cafe-to-west-band movement gives no premature wrong-way line")
 var west: Dictionary=await attempt(g,Vector3(-59,.055,-3),1.25)
 check(kept_west_footprint(west,radius) and g.walker.position.x<WEST_CENTRE+.1,"held west input stops the complete capsule on the marked tile seam")
 check(events==1 and g.walker.wrong_way_latched and g.ui.bark_panel.visible and g.ui.bark_text.text=="นั่นไม่ใช่ทางไปที่เรือนะ","western seam gives the existing short line once")
 var pause_at: Vector3=g.walker.position;var remaining: float=g.route_bark_time
 g.ui.open_settings();g.tick(0)
 await attempt(g,Vector3(-60,.055,-3),.5)
 check(not g.walker.enabled and g.walker.position.distance_to(pause_at)<.002 and is_equal_approx(g.route_bark_time,remaining),"settings pauses actual boundary movement and the existing speech countdown")
 g.ui.close_settings();g.tick(.1)
 check(g.walker.enabled and g.route_bark_time<remaining,"closing settings resumes the same playable response")
 west=await attempt(g,Vector3(-60,.055,-3),3.6)
 check(kept_west_footprint(west,radius) and events==1 and not g.ui.bark_panel.visible,"continued held input neither crosses the seam nor repeats speech after timeout")
 check(await route(g,[Vector3(-52.3,.055,-3),Vector3(-49,.055,-3)]) and not g.walker.wrong_way_latched,"inward return stays immediately usable and rearms a later attempt")
 # Traverse the actual narrow band between cases. Diagonal attempts cannot
 # put even the capsule edge into the scenic western road.
 for z in [-16.0,8.5,14.0]:
  var before_events:=events
  var reached: bool=await route(g,[Vector3(-52.3,.055,-3),Vector3(-52.3,.055,z)])
  check(reached,"real actor traverses the western band to z="+str(z))
  if not reached:finish(g);return
  west=await attempt(g,Vector3(-59,.055,z+2),1.25)
  var repeated: Dictionary=await attempt(g,Vector3(-59,.055,z-2),.8)
  check(kept_west_footprint(west,radius) and kept_west_footprint(repeated,radius) and g.walker.position.x<WEST_CENTRE+.1,"diagonal/reversed input keeps the entire footprint inside at z="+str(z))
  check(events==before_events+1,"one deliberate band-edge attempt produces one warning at z="+str(z))
  var return_z: float=g.walker.position.z
  check(await route(g,[Vector3(-52.3,.055,return_z),Vector3(-52.3,.055,-3),Vector3(-49,.055,-3)]) and not g.walker.wrong_way_latched,"inward route from z="+str(z)+" returns to the square and rearms")
 # The unrelated northeast narrative gate keeps its original location/line.
 var north_events:=events
 check(await route(g,[Vector3(-25,.055,-3),Vector3(-25,.055,-21.7)]),"original north passage remains reachable")
 await attempt(g,Vector3(-25,.055,-26),1)
 check(events==north_events+1 and g.walker.position.z>=-22.501 and g.walker.position.z< -22.35,"original north warning still stops at z=-22.5")
 check(await walk_to(g,Vector3(-25,.055,-17.3)),"original north warning permits its immediate inward return")
 var no_floor:=true
 for x in [-16.0,-1.0,13.0,20.8]:
  for z in [16.0,17.6]:no_floor=no_floor and floor_at(g,Vector3(x,0,z)).is_empty()
 check(no_floor,"removed original main-quay strip is actual sea with no hidden floor")
 check(not ground_mesh_in_strip(g.world.main,Rect2(Vector2(-17.4,15.85),Vector2(38.8,2.15))),"actual main-quay slab/paver triangles end before the removed foreground strip")
 for x in [-16.0,0.0,20.5]:
  await place(g,Vector3(x,.055,13.8))
  var edge: Dictionary=await attempt(g,Vector3(x,.055,18),1.4)
  check(edge.south and edge.max_z<SOUTH_EDGE-.3,"real player meets the new physical south rail at x="+str(x))
 await place(g,Vector3(-19.2,.055,13.8))
 var joint: Dictionary=await attempt(g,Vector3(-16.5,.055,17.2),1.8)
 check(joint.south and joint.max_z<SOUTH_EDGE-.3,"diagonal input cannot escape through the former x=-18 coast step")
 await place(g,Vector3(20.5,.055,13.8))
 var corner: Dictionary=await attempt(g,Vector3(23.5,.055,17),2)
 check(corner.south and corner.east and corner.max_z<SOUTH_EDGE-.3 and g.walker.position.x<21.7,"new south/east corner has native contacts on both sides without an escape")
 g.return_title();g.start_arrival();g.skip_arrival();g.tick(0)
 check(g.phase==&"play" and not g.walker.wrong_way_latched and not g.ui.bark_panel.visible,"replay and skip clear all old boundary speech state")
 var boarding: Array=[Vector3(-43,.055,-7.3)]
 for index in Profile.WALK_ROUTE.size():
  if index==6:boarding.append(Vector3(-1.8,.055,13.2));boarding.append(Vector3(13.5,.055,13.2))
  boarding.append(Profile.WALK_ROUTE[index])
 var aboard: bool=await route(g,boarding)
 check(aboard and g.walker.position.y>2.2,"same cafe-to-original-deck journey remains supported with the ordinary porter bypass")
 var inbound: Array=[]
 for index in range(boarding.size()-2,-1,-1):inbound.append(boarding[index])
 check(aboard and await route(g,inbound),"actual player can return from the original deck through the unchanged route landmarks")
 check(lowest_y>-.05,"all accepted walking routes and contact approaches remain on real supported ground")
 g.return_title();g.tick(0)
 check(g.phase==&"title" and g.walker==null and not g.ui.bark_panel.visible and g.route_bark_time==0,"final replay restores original ship title without stale movement or warning")
 finish(g)
