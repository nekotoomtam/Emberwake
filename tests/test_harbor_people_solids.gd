extends SceneTree
const NPC=preload("res://scripts/opening/harbor_npc.gd")
const Courier=preload("res://scripts/opening/harbor_cargo_courier.gd")
class FixtureShip extends Node3D:
 var visual_root: Node3D
class FixtureHarbor extends Node3D:
 var ship: Node3D
var checks:=0
var failures: Array=[]
var scene: Node3D
var camera: Camera3D
var probe: CharacterBody3D
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func person(at: Vector3):
 var npc=NPC.new();npc.profile={"id":"CollisionFixture","hairstyle":2,"male":true,"hair":"6f5a48","skin":"d29b77","coat":"527b7c","phase":0};npc.route.assign([at]);scene.add_child(npc);return npc
func run() -> void:
 scene=Node3D.new();root.add_child(scene)
 camera=Camera3D.new();scene.add_child(camera);camera.position=Vector3(0,6,10);camera.look_at(Vector3(0,1,0))
 var floor_body:=StaticBody3D.new();var floor_col:=CollisionShape3D.new();var floor_shape:=BoxShape3D.new();floor_shape.size=Vector3(60,1,60);floor_col.shape=floor_shape;floor_col.position.y=-.5;floor_body.add_child(floor_col);scene.add_child(floor_body)
 var npc=person(Vector3(-2,0,0));npc.tick(0,camera,0)
 probe=CharacterBody3D.new();probe.collision_layer=2;probe.collision_mask=1;var col:=CollisionShape3D.new();var cap:=CapsuleShape3D.new();cap.radius=.24;cap.height=1.4;col.shape=cap;col.position.y=.7;probe.add_child(col);scene.add_child(probe)
 await physics_frame;await physics_frame
 check(npc.get("human_blocker") is PhysicsBody3D,"human owns native physics body")
 var ray:=PhysicsRayQueryParameters3D.create(Vector3(-2,.7,1),Vector3(-2,.7,-1),1)
 check(not scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"native ray hits visible standing person")
 probe.position=Vector3(-2,.02,1.2);var collided:=false
 for i in Engine.physics_ticks_per_second:
  await physics_frame;probe.velocity=Vector3(0,-2,-3.1);probe.move_and_slide()
  for j in probe.get_slide_collision_count():
   if absf(probe.get_slide_collision(j).get_normal().y)<.5:collided=true
 check(collided and probe.position.z>.48,"actual capsule walk is stopped by standing human")
 probe.position=Vector3(0,0,0);npc.position=Vector3(-2,0,0);npc.route.assign([Vector3(-2,0,0),Vector3(2,0,0)]);npc._target=1;npc._wait=0
 var crossed:=false
 for i in 180:
  await physics_frame;npc.tick(.05,camera,float(i)*.05)
  if npc.position.x>-.48:crossed=true
 check(not crossed and npc.position.x> -1,"authored moving resident waits before stationary player without crossing")
 probe.position=Vector3(0,0,3)
 for i in 100:await physics_frame;npc.tick(.05,camera,9+float(i)*.05)
 check(npc.position.x> .6,"resident resumes original path after player clears it")
 var offset:=Vector3(.07,.08,-.06);npc.apply_deck_offset(offset,camera)
 if npc.get("human_blocker")!=null:
  check(npc.human_blocker.global_position.distance_to(npc.global_position+offset)<.001,"human physics feet follow the displayed deck offset")
 else:check(false,"human physics feet follow the displayed deck offset")
 probe.position=Vector3(0,0,6)
 var other=person(Vector3(0,0,0));npc.position=Vector3(-2,0,0);npc.route.assign([Vector3(-2,0,0),Vector3(2,0,0)]);npc._target=1;npc._wait=0;npc.apply_deck_offset(Vector3.ZERO,camera)
 crossed=false
 for i in 120:
  await physics_frame;npc.tick(.05,camera,15+float(i)*.05)
  if npc.position.x>-.51:crossed=true
 check(not crossed and npc.position.x> -1,"moving person also stops before another resident")
 other.free();npc.position=Vector3(-2,0,3);npc.route.assign([Vector3(-2,0,3),Vector3(2,0,3)]);npc._target=1;npc._wait=0
 var wall:=StaticBody3D.new();wall.position=Vector3(0,.5,3);var wc:=CollisionShape3D.new();var ws:=BoxShape3D.new();ws.size=Vector3(.8,1,1);wc.shape=ws;wall.add_child(wc);scene.add_child(wall)
 crossed=false
 for i in 120:
  await physics_frame;npc.tick(.05,camera,21+float(i)*.05)
  if npc.position.x>-.64:crossed=true
 check(not crossed and npc.position.x> -1,"authored movement does not pass a visible solid wall or crate")
 wall.free()
 for i in 100:await physics_frame;npc.tick(.05,camera,27+float(i)*.05)
 check(npc.position.x> .6,"movement resumes when solid obstruction is removed")
 check(ResourceLoader.exists("res://scripts/opening/harbor_public_solids.gd"),"accessible original harbor props have a native collision owner")
 var courier=Courier.new();courier.profile=npc.profile.duplicate(true);courier.transfer_path.assign([Vector3(-2,0,-3),Vector3(2,0,-3)]);scene.add_child(courier);courier.set_enabled(true);probe.position=Vector3(0,0,-3)
 crossed=false
 for i in 120:
  await physics_frame;courier.tick(.05,camera,float(i)*.05)
  if courier.position.x>-.48:crossed=true
 check(not crossed and courier.position.x> -1 and courier.state=="outbound","cargo courier override also waits without fake pickup")
 probe.position=Vector3(0,0,6)
 for i in 120:
  await physics_frame;courier.tick(.05,camera,6+float(i)*.05)
  if courier.state=="pickup":break
 check(courier.position.distance_to(Vector3(2,0,-3))<.02 and courier.state=="pickup","courier resumes and only picks up at its actual destination")
 var fixture:=FixtureHarbor.new();var vessel:=FixtureShip.new();vessel.position=Vector3(7,-.55,-7.6);fixture.ship=vessel;fixture.add_child(vessel);vessel.visual_root=Node3D.new();vessel.add_child(vessel.visual_root);scene.add_child(fixture)
 var solids=load("res://scripts/opening/harbor_public_solids.gd").new();solids.world=fixture;fixture.add_child(solids);await physics_frame;await physics_frame
 check(solids.blockers.size()==50 and solids.deck_blockers.size()==6,"reachable native props receive bounded exact shapes")
 var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(15,.4,5.5),Vector3(15,.4,3),1))
 check(not hit.is_empty() and str(hit.collider.name)=="QuayCrate1","native physical ray hits drawn pier-crate footprint")
 hit=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(17,1.5,5),Vector3(17,1.5,7),1))
 check(not hit.is_empty() and str(hit.collider.name)=="MarketFlagPost3","slender visible market post has a matching narrow collision")
 probe.position=Vector3(15,.02,5.8);collided=false
 for i in Engine.physics_ticks_per_second:
  await physics_frame;probe.velocity=Vector3(0,-2,-3.1);probe.move_and_slide()
  for j in probe.get_slide_collision_count():
   if absf(probe.get_slide_collision(j).get_normal().y)<.5:collided=true
 check(collided and probe.position.z>4.65,"actual player-size capsule cannot cross the original pier crate")
 var rest: Transform3D=solids.deck_blockers[0].global_transform
 vessel.visual_root.rotation=Vector3(.03,.015,.02);vessel.visual_root.position.y=.08;solids.tick();await physics_frame;await physics_frame
 var expected: Transform3D=vessel.global_transform*vessel.visual_root.transform*vessel.global_transform.affine_inverse()*rest
 check(solids.deck_blockers[0].global_position.distance_to(expected.origin)<.0001 and expected.origin.distance_to(rest.origin)>.02,"departure cargo collision follows actual visual deck motion")
 var center: Vector3=expected.origin
 hit=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(center+Vector3(0,0,1),center-Vector3(0,0,1),1))
 check(not hit.is_empty() and hit.collider==solids.deck_blockers[0],"native physics updates the moved cargo body rather than leaving a ghost")
 scene.free();await process_frame
 print("HARBOR PEOPLE SOLIDS ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
