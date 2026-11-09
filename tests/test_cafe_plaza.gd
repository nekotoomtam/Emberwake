extends SceneTree
## Exercises the real opening controller and physical actor, without save access.
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
 release_walk()
 g.free()
 print("CAFE PLAZA ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
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
 # Solid residents occupy the old straight porter lane. Take the ordinary
 # public-side bypass in both directions, retaining every route landmark.
 var from: Vector3=g.walker.position
 if absf(from.z-11.6)<.5 and absf(target.z-11.6)<.1 and absf(target.x-from.x)>4:
  if not await _walk_direct(g,Vector3(from.x,.055,13.2)):return false
  if not await _walk_direct(g,Vector3(target.x,.055,13.2)):return false
 return await _walk_direct(g,target)
func _walk_direct(g,target: Vector3) -> bool:
 for frame in Engine.physics_ticks_per_second*10:
  var delta: Vector3=target-g.walker.position;delta.y=0
  if delta.length()<.18:release_walk();return true
  steer(g,target);await physics_frame
  lowest_y=minf(lowest_y,g.walker.position.y)
 release_walk();print("PLAZA WALK STOP ",g.walker.position," target ",target)
 return false
func push_into(g,target: Vector3,seconds: float=1.8) -> bool:
 # Require an actual horizontal collision, not just the walker's support guard.
 var collided:=false
 for frame in ceili(seconds*Engine.physics_ticks_per_second):
  steer(g,target);await physics_frame
  for index in g.walker.get_slide_collision_count():
   var normal: Vector3=g.walker.get_slide_collision(index).get_normal()
   if Vector2(normal.x,normal.z).length()>.8:collided=true
 release_walk();return collided
func advance(g,seconds: float) -> void:
 var frames:=ceili(seconds*60)
 for frame in frames:g.tick(seconds/frames)
func camera_at(camera: Camera3D,at: Vector3,target: Vector3) -> bool:
 return camera.global_position.distance_to(at)<.002 and (-camera.global_basis.z).dot((target-at).normalized())>.99999
func run() -> void:
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 check(g.world.anchors.cafe.distance_to(Vector3(-43,.055,-9))<.001,"coffee actor is relocated to the far-left public plaza")
 var plaza=g.world.get("plaza") if has_property(g.world,"plaza") else null
 check(plaza!=null,"opening composes the playable cafe plaza")
 if plaza==null:finish(g);return
 check(g.world.anchors.cafe.distance_to(g.world.anchors.gangway)>40,"coffee remains a substantial walk from the original gangway")
 check(g.world.cup==plaza.cup,"sip animation owns the cup shown on the new cafe table")
 check(g.world.cup.global_position.distance_to(Vector3(-42.12,.615,-9.26))<.001,"new cup starts at its authored table rest")
 check(camera_at(g.camera,Vector3(62,11.45,-13),Vector3(88,3.45,-39)) and is_equal_approx(g.camera.fov,50),"title retains the exact original ship framing")
 check(g.world.arrival.position.distance_to(Vector3(88,-.55,-38))<.001 and is_equal_approx(g.world.arrival.rotation.y,PI),"original arriving ship starts at unchanged sea transform")
 check(g.world.ship.position.distance_to(Vector3(7,-.55,-7.6))<.001,"original departure ship stays at its berth")
 check(plaza.people.size()>=6 and plaza.birds.size()>=4,"new public plaza has a bounded resident and bird population")
 check(plaza.fountain!=null,"new public plaza includes its central fountain")
 var residents: Array=[];var birds: Array=[]
 for person in plaza.people:residents.append(person.position)
 for bird in plaza.birds:birds.append(bird.position)
 var water_before: float=plaza.fountain.water_time
 var water_phase: float=plaza.fountain.water_phase
 advance(g,4)
 var resident_movers:=0;var bird_movers:=0
 for i in plaza.people.size():
  if plaza.people[i].position.distance_to(residents[i])>.1:resident_movers+=1
 for i in plaza.birds.size():
  if plaza.birds[i].position.distance_to(birds[i])>.02:bird_movers+=1
 check(resident_movers>=2,"new residents actually traverse their routes during world time")
 check(bird_movers>=2,"new plaza birds actually move during world time")
 check(plaza.fountain.water_time>water_before+3.9 and plaza.fountain.water_phase!=water_phase,"fountain phase and water clock advance through world tick")
 check(is_equal_approx(float(plaza.fountain.water_material.get_shader_parameter("clock")),plaza.fountain.water_time),"fountain animation clock reaches its rendered water material")
 g.return_title();g.tick(0)
 check(g.phase==&"title" and g.world.cup.global_position.distance_to(Profile.CUP_REST)<.001,"title reset returns cup to the relocated table")
 g.ui.start_button.pressed.emit()
 check(g.phase==&"flyin" and not g.ui.menu.visible,"Start begins the original ship opening")
 advance(g,4)
 check(g.camera.global_position.distance_to(Vector3(62,11.45,-8))<.003,"first half of the retained ship orbit is unchanged")
 advance(g,4)
 check(g.world.arrival.docked and g.world.arrival.position.distance_to(Vector3(12,-.55,-38))<.001,"original ship still completes its eight-second arrival")
 check(g.camera.global_position.distance_to(Vector3(24,11.45,-8))<.003,"eight-second ship camera reaches its original handoff")
 advance(g,6);g.tick(.001)
 check(g.phase==&"line" and g.camera.view_id==&"cafe","fourteen-second opening reaches the seated cafe line")
 check(camera_at(g.camera,Vector3(-37.5,7.255,4.5),Vector3(-37.5,1.355,-11)) and is_equal_approx(g.camera.fov,48),"camera rail ends at the relocated cafe framing")
 advance(g,1.9)
 check(g.phase==&"line" and g.walker==null,"seated line stays visible before rise")
 advance(g,.2)
 check(g.phase==&"rising" and g.walker==null,"line transitions into the standing animation")
 advance(g,.9)
 check(g.phase==&"play" and g.walker is CharacterBody3D and not g.world.hero.visible,"rise hands control to the real physical protagonist")
 check(g.world.cup.global_position.distance_to(Profile.CUP_REST)<.001,"cup is left at the new table after standing")
 if g.walker==null:finish(g);return
 await physics_frame;await physics_frame
 var route_ok:=true
 for i in Profile.WALK_ROUTE.size():
  var reached: bool=await walk_to(g,Profile.WALK_ROUTE[i])
  check(reached,"actual actor walks cafe-to-deck leg "+str(i+1))
  if not reached:route_ok=false;break
 check(route_ok and g.walker.position.y>2.2,"whole cafe-to-original-deck route has physical floor and gangway support")
 if route_ok:
  for i in range(Profile.WALK_ROUTE.size()-2,-1,-1):
   var reached: bool=await walk_to(g,Profile.WALK_ROUTE[i])
   check(reached,"actual actor returns deck-to-cafe leg "+str(Profile.WALK_ROUTE.size()-i))
   if not reached:route_ok=false;break
  check(await walk_to(g,Vector3(-43,.055,-7.2)),"actual actor returns beside the relocated coffee seat")
 check(lowest_y>-.05,"physical route never drops below the supported harbor surface")
 if route_ok:
  check(await walk_to(g,Vector3(-39,.055,-7.2)),"fountain approach starts from reachable cafe paving")
  check(await walk_to(g,Vector3(-36,.055,-8.5)),"fountain approach reaches open paving")
  var fountain_collision: bool=await push_into(g,Vector3(-32,.055,-8.5))
  check(fountain_collision and g.walker.position.x< -34.3,"physical fountain basin stops an attempted walk through its center")
  check(await walk_to(g,Vector3(-36,.055,-3)),"actor can leave the fountain edge")
  check(await walk_to(g,Vector3(-23,.055,-3)),"actor reaches plaza sea-side route")
  # The authored bench faces the sea at (-21.4,-7.6); approach on its sea side.
  check(await walk_to(g,Vector3(-20.3,.055,-3)),"actor rounds the sea-side bench on clear paving")
  check(await walk_to(g,Vector3(-20.3,.055,-8)),"sea railing approach remains usable")
  var rail_collision: bool=await push_into(g,Vector3(-18,.055,-8))
  check(rail_collision and g.walker.position.x< -19.8,"physical sea railing stops the actor before unsupported water")
  check(await walk_to(g,Vector3(-20.3,.055,-4.5)),"actor can leave the sea railing beside the bench")
  check(await walk_to(g,Vector3(-23,.055,-4.5)),"actor rounds the bench back toward the square")
  check(await walk_to(g,Vector3(-26,.055,-13)),"actor reaches clear paving in front of facade market")
  check(await walk_to(g,Vector3(-31,.055,-15)),"actor reaches the new stall frontage")
  var stall_collision: bool=await push_into(g,Vector3(-31,.055,-19.6))
  check(stall_collision and g.walker.position.z> -16.8,"physical new market counter denies passage into rear stalls")
 g.return_title();g.tick(0)
 check(g.phase==&"title" and g.walker==null and g.world.hero.visible and g.ui.menu.visible,"return removes the actor and restores the seated menu")
 check(camera_at(g.camera,Vector3(62,11.45,-13),Vector3(88,3.45,-39)) and g.world.arrival.progress==0,"replay reset restores the unchanged ship opening")
 check(g.world.cup.global_position.distance_to(Profile.CUP_REST)<.001,"replay reset keeps cup at its new table")
 g.start_arrival();g.skip_arrival();g.tick(0)
 check(g.phase==&"play" and g.walker is CharacterBody3D and g.world.arrival.docked,"skip lands at the new playable cafe with the original ship docked")
 check(g.walker.position.distance_to(Profile.CAFE)<1.5 and g.world.cup.global_position.distance_to(Profile.CUP_REST)<.001,"skip has a coherent relocated actor and cup destination")
 finish(g)
