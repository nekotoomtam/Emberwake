extends SceneTree
## Real delivery meshes/solids, retained clearance and native porter movement.
const NPC=preload("res://scripts/opening/harbor_npc.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func finish(scene=null) -> void:
 if scene!=null:scene.free()
 print("HARBOR CARGO STREET ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func mesh_bounds(node: Node) -> AABB:
 var result:=AABB();var first:=true
 for mesh in node.find_children("*","MeshInstance3D",true,false):
  var bounds: AABB=mesh.global_transform*mesh.mesh.get_aabb()
  result=bounds if first else result.merge(bounds);first=false
 return result
func solid_bounds(body: PhysicsBody3D) -> AABB:
 var result:=AABB();var first:=true
 for child in body.get_children():
  if child is CollisionShape3D and not child.disabled:
   var bounds: AABB=child.global_transform*child.shape.get_debug_mesh().get_aabb()
   result=bounds if first else result.merge(bounds);first=false
 return result
func bounds_of(bodies: Array) -> AABB:
 var result:=AABB();var first:=true
 for body in bodies:
  var bounds:=solid_bounds(body);result=bounds if first else result.merge(bounds);first=false
 return result
func crossing(at: Vector3,motion: Vector3) -> KinematicCollision3D:
 var actor:=CharacterBody3D.new();actor.collision_layer=2;actor.collision_mask=1
 var collision:=CollisionShape3D.new();var shape:=CapsuleShape3D.new();shape.radius=.24;shape.height=1.4;collision.shape=shape;collision.position.y=.7;actor.add_child(collision);root.add_child(actor);actor.position=at
 var hit:=actor.move_and_collide(motion);actor.free();return hit
func reset_worker(worker) -> void:
 worker.position=worker.route[0];worker._target=1;worker._wait=0;worker._arrived=false;worker.carrying=true
func run() -> void:
 var path:="res://scripts/opening/harbor_cargo_street.gd"
 check(ResourceLoader.exists(path),"covered delivery wagon and working porters have a local scene owner")
 if not ResourceLoader.exists(path):finish();return
 var scene:=Node3D.new();root.add_child(scene)
 var town=load("res://scripts/opening/harbor_town_routes.gd").new();scene.add_child(town)
 var helper=load(path).new();scene.add_child(helper)
 var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(-48,14,10);camera.look_at(Vector3(-59,1,-10))
 helper.tick(0,camera,0)
 await physics_frame;await physics_frame
 check(helper.workers.size()==2,"delivery scene owns exactly two native porters")
 check(helper.geometry_count>150,"covered wagon and cargo emit substantial authored native geometry")
 check(helper.main.name=="CoveredDeliveryWagonGeometry" and helper.props_geometry.name=="StreetDeliveryCargoGeometry","wagon and cargo meshes have separate native inspection labels")
 var wagon_nodes: Array=get_nodes_in_group("harbor_delivery_wagon")
 var wagon_actual:=bounds_of(wagon_nodes);var wagon_visible:=mesh_bounds(helper.main)
 check(wagon_nodes.size()>=10,"bed wheels canopy and resting shafts have bounded matching solids")
 check(wagon_actual.size.x>=2.1 and wagon_actual.size.x<2.6 and wagon_actual.size.z>=6.1 and wagon_actual.size.z<6.7,"covered wagon retains human-scale parked dimensions including shafts")
 check(wagon_visible.size.y>2.4 and wagon_visible.size.y<3.1,"covered wagon has a readable raised canvas canopy")
 check(helper.wagon_bounds.position.distance_to(wagon_actual.position)<.01 and helper.wagon_bounds.end.distance_to(wagon_actual.end)<.01,"published wagon extent matches actual native shapes")
 check(Vector2(wagon_actual.position.x,wagon_actual.position.z).distance_to(Vector2(wagon_visible.position.x,wagon_visible.position.z))<.16 and Vector2(wagon_actual.end.x,wagon_actual.end.z).distance_to(Vector2(wagon_visible.end.x,wagon_visible.end.z))<.16,"visible wheels body and shafts agree with their actual occupied footprint")
 check(helper.cargo_bounds.size()==2 and get_nodes_in_group("harbor_delivery_cargo").size()>=5,"two restrained delivery piles have native cargo solids")
 var overlap:=0;var footway:=Rect2(Vector2(-53.45,-21),Vector2(2.45,27.3))
 for body in helper.find_children("*","StaticBody3D",true,false):
  var bounds:=solid_bounds(body)
  if footway.intersects(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))):overlap+=1
  for retained in town.find_children("*","StaticBody3D",true,false):
   if retained.is_in_group("harbor_town_ground"):continue
   if bounds.intersects(solid_bounds(retained)):overlap+=1
 check(overlap==0,"new solids leave the west footway and retained stores cart/lamps/cargo clear")
 for x in [-57.7,-56,-54.3]:
  check(crossing(Vector3(x,.2,5.7),Vector3(0,0,-23.2))==null,"continuous centre/east carriageway remains physically open at x "+str(x))
 var visual_ids: Array=[];var original_profiles: Array=[]
 for worker in helper.workers:
  check(worker.human_blocker is AnimatableBody3D and worker.human_blocker.is_in_group("harbor_person"),"porter uses the original native people footprint")
  check(worker.profile.get("carry",false) and worker.work and worker.sprite.texture!=null,"porter uses original carrying and working art")
  check(worker.route[0].x< -53.72 and worker.route[1].x< -53.72,"porter work stays entirely on the scenic side of the player seam")
  visual_ids.append(worker.get_instance_id());original_profiles.append(worker.profile.duplicate(true))
 var moved: Array=[0.0,0.0];var seen_empty: Array=[false,false];var seen_work: Array=[false,false]
 var faces_wagon: Array=[false,false];var faces_source: Array=[false,false]
 var moving_lane_blocked:=false
 var lane_shape:=CapsuleShape3D.new();lane_shape.radius=.24;lane_shape.height=1.4
 var sources: Array=[Vector3(-62.2,.055,-4.35),Vector3(-59.05,.055,-19.25)]
 var start: Array=[helper.workers[0].position,helper.workers[1].position]
 var original_meshes: Array=[]
 for mesh in helper.main.find_children("*","MeshInstance3D",true,false):original_meshes.append(mesh.mesh)
 for step in 900:
  await physics_frame;helper.tick(.05,camera,float(step)*.05)
  for i in 2:
   var worker=helper.workers[i]
   moved[i]=maxf(float(moved[i]),worker.position.distance_to(start[i]))
   if not worker.carrying:seen_empty[i]=true
   if not worker.walking and worker._arrived:
    seen_work[i]=true
    var target: Vector3=Vector3(-59.8,.055,-11.5) if worker._target==1 else sources[i]
    var direction: Vector3=(target-worker.position).normalized()
    if worker.aim.dot(direction)>.85:
     if worker._target==1:faces_wagon[i]=true
     else:faces_source[i]=true
  var east_worker=helper.workers[1]
  if east_worker.position.z> -17:
   var lane_query:=PhysicsShapeQueryParameters3D.new();lane_query.shape=lane_shape;lane_query.collision_mask=1;lane_query.transform.origin=Vector3(-57.5,.785,east_worker.position.z)
   if not scene.get_world_3d().direct_space_state.intersect_shape(lane_query,1).is_empty():moving_lane_blocked=true
 for i in 2:
  check(float(moved[i])>4.0 and seen_empty[i] and seen_work[i],"porter "+str(i+1)+" genuinely traverses and works at delivery ends")
  check(faces_wagon[i] and faces_source[i],"porter "+str(i+1)+" faces the actual pile or wagon while placing and inspecting")
  check(helper.workers[i].get_instance_id()==visual_ids[i] and helper.workers[i].profile==original_profiles[i],"porter identity and appearance remain stable through the work loop")
 check(not moving_lane_blocked,"working porter leaves the minimum clear middle carriageway available throughout movement")
 var meshes_after: Array=[]
 for mesh in helper.main.find_children("*","MeshInstance3D",true,false):meshes_after.append(mesh.mesh)
 check(meshes_after==original_meshes,"delivery ticks reuse static wagon geometry")
 # Test the actual porter/prop query, not only authored route coordinates.
 var worker=helper.workers[0];reset_worker(worker)
 var middle: Vector3=worker.route[0].lerp(worker.route[1],.5)
 var blocker:=StaticBody3D.new();blocker.position=middle+Vector3.UP*.75
 var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.8,1.5,.8);col.shape=box;blocker.add_child(col);scene.add_child(blocker)
 await physics_frame;await physics_frame
 var tangent: Vector3=(worker.route[1]-worker.route[0]).normalized();var crossed:=false
 for step in 260:
  await physics_frame;helper.tick(.05,camera,45+float(step)*.05)
  if (worker.position-middle).dot(tangent)>-.5:crossed=true
 check(not crossed and worker.position.distance_to(worker.route[0])>1,"working porter stops before actual occupied cargo rather than crossing it")
 blocker.free();await physics_frame;await physics_frame
 var reached:=false
 for step in 260:
  await physics_frame;helper.tick(.05,camera,58+float(step)*.05)
  if worker.position.distance_to(worker.route[1])<.03:reached=true
 check(reached,"working porter resumes and reaches wagon after cargo obstruction clears")
 reset_worker(worker)
 var other=NPC.new();other.profile={"id":"DeliveryHumanFixture","hairstyle":2,"male":true,"hair":"6f5a48","skin":"d29b77","coat":"527b7c","cap":false,"phase":0};other.route.assign([middle]);scene.add_child(other);other.tick(0,camera,0)
 await physics_frame;await physics_frame;crossed=false
 for step in 260:
  await physics_frame;helper.tick(.05,camera,71+float(step)*.05)
  if (worker.position-middle).dot(tangent)>-.50:crossed=true
 check(not crossed,"working porter also waits for an actual person on the delivery route")
 print("CARGO STREET bounds wagon=",helper.wagon_bounds," piles=",helper.cargo_bounds," workers=",helper.workers.size()," geometry=",helper.geometry_count)
 finish(scene)
