extends SceneTree
## Native garden geometry/physics and reuse of existing plaza identities.
const GARDEN_PATH:="res://scripts/opening/harbor_square_garden.gd"
var checks:=0
var failures: Array=[]
var scene: Node3D
var probe: CharacterBody3D
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func finish() -> void:
 if scene!=null:scene.free()
 print("HARBOR SQUARE GARDEN ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func named(nodes: Array,label: String):
 for node in nodes:
  if String(node.name)==label:return node
 return null
func mesh_bounds(node: Node,materials: Array=[]) -> AABB:
 var bounds:=AABB();var first:=true
 for mesh in node.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh==null or (not materials.is_empty() and mesh.get_active_material(0) not in materials):continue
  var part: AABB=mesh.global_transform*mesh.mesh.get_aabb()
  bounds=part if first else bounds.merge(part);first=false
 return bounds
func solid_bounds(body: PhysicsBody3D) -> AABB:
 var bounds:=AABB();var first:=true
 for child in body.get_children():
  if child is CollisionShape3D and child.shape!=null:
   var part: AABB=child.global_transform*child.shape.get_debug_mesh().get_aabb()
   bounds=part if first else bounds.merge(part);first=false
 return bounds
func mesh_state(node: Node) -> Array:
 var result: Array=[]
 for mesh in node.find_children("*","MeshInstance3D",true,false):
  result.append(mesh.get_instance_id());result.append(mesh.mesh.get_instance_id());result.append(mesh.get_active_material(0).get_instance_id())
 return result
func walk_to(at: Vector3) -> bool:
 for frame in ceili(4.0*Engine.physics_ticks_per_second):
  var direction:=at-probe.position;direction.y=0
  if direction.length()<.12:return true
  await physics_frame;probe.velocity=direction.normalized()*3.1+Vector3.DOWN*2;probe.move_and_slide()
 return false
func push(target: Vector3,wanted: PhysicsBody3D) -> bool:
 var touched:=false
 for frame in ceili(1.2*Engine.physics_ticks_per_second):
  var direction:=target-probe.position;direction.y=0
  await physics_frame;probe.velocity=direction.normalized()*3.1+Vector3.DOWN*2;probe.move_and_slide()
  for index in probe.get_slide_collision_count():
   var hit: KinematicCollision3D=probe.get_slide_collision(index)
   for contact_index in hit.get_collision_count():
    var normal: Vector3=hit.get_normal(contact_index)
    if hit.get_collider(contact_index)==wanted and Vector2(normal.x,normal.z).length()>.8:touched=true
 return touched
func run() -> void:
 check(ResourceLoader.exists(GARDEN_PATH),"native square-garden helper exists")
 if not ResourceLoader.exists(GARDEN_PATH):finish();return
 scene=Node3D.new();root.add_child(scene)
 var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(-24,10,14);camera.look_at(Vector3(-36,1,-6))
 var plaza=load("res://scripts/opening/harbor_cafe_plaza.gd").new();scene.add_child(plaza)
 var original_people: Array=plaza.people.duplicate();var original_birds: Array=plaza.birds.duplicate()
 var visitor=named(plaza.people,"FountainVisitor")
 var profile: Dictionary=visitor.profile.duplicate(true);var human_id: int=visitor.human_blocker.get_instance_id()
 var garden=load(GARDEN_PATH).new();garden.plaza=plaza;garden.materials=plaza.materials.duplicate();scene.add_child(garden)
 await physics_frame;await physics_frame
 check(garden.trees.size()==2 and garden.bed_bounds.size()==2 and garden.geometry_count>0,"two native trees and their low garden beds are composed")
 check(plaza.people==original_people and plaza.birds==original_birds,"garden retains every existing plaza person and bird without adding replacements")
 check(garden.feeder==visitor and visitor.profile==profile and visitor.human_blocker.get_instance_id()==human_id,"feeding visitor keeps its actual identity, appearance and native human body")
 check(garden.feeding_pigeon in original_birds and garden.feeding_pigeon.home.distance_to(Vector3(-29.2,.055,-4.9))<.25,"one existing pigeon is rehomed beside the actual grains")
 check(visitor.position.distance_to(Vector3(-28.1,.055,-5.7))<.02 and visitor.route.size()==1 and visitor.work,"original visitor uses the agreed single feeding/watch position and work hand pose")
 for index in garden.trees.size():
  var tree: Node3D=garden.trees[index];var whole:=mesh_bounds(tree);var crown:=mesh_bounds(tree.get_node("TreeGeometry"),garden.leaf_materials);var bed:=mesh_bounds(tree.get_node("BedGeometry"))
  print("GARDEN TREE ",index+1," whole=",whole," crown=",crown," root=",tree.position)
  check(whole.size.y>=4.5 and whole.size.y<=5.05 and crown.size.x>=2.0 and crown.size.x<=2.4 and crown.size.z<=2.4 and crown.position.y-tree.position.y>3.1,"tree "+str(index+1)+" has a slender native trunk and high open-sized crown")
  check(bed.size.x<=1.70 and bed.size.z<=1.70 and bed.size.y<.5 and garden.bed_bounds[index].position.distance_to(bed.position)<.005 and garden.bed_bounds[index].end.distance_to(bed.end)<.005,"tree "+str(index+1)+" exposes the real low stone/flower bed footprint")
  var clear:=true
  for group in ["harbor_plaza_bench","harbor_plaza_planter","harbor_plaza_lamp"]:
   for body in get_nodes_in_group(group):
    var occupied:=solid_bounds(body)
    var feet:=Rect2(Vector2(bed.position.x,bed.position.z),Vector2(bed.size.x,bed.size.z)).grow(.24)
    clear=clear and not feet.intersects(Rect2(Vector2(occupied.position.x,occupied.position.z),Vector2(occupied.size.x,occupied.size.z)),true)
  check(clear,"tree "+str(index+1)+" and its player margin stay clear of existing benches, planters and lamps")
  var trunk_hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(tree.position+Vector3(-.7,1.2,0),tree.position+Vector3(.7,1.2,0),1))
  check(not trunk_hit.is_empty() and trunk_hit.collider.is_in_group("harbor_garden_trunk"),"tree "+str(index+1)+" visible trunk has its matched native side solid")
 probe=CharacterBody3D.new();probe.collision_layer=2;probe.collision_mask=1;var collision:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.24;capsule.height=1.4;collision.shape=capsule;collision.position.y=.7;probe.add_child(collision);scene.add_child(probe)
 for index in garden.trees.size():
  var tree: Node3D=garden.trees[index];probe.position=tree.position+Vector3(0,.025,-1.8);probe.velocity=Vector3.ZERO
  var bed_body: PhysicsBody3D=tree.get_node("BedFootprint")
  check(await push(tree.position+Vector3(0,0,1.5),bed_body) and probe.position.z<tree.position.z-.95,"actual character capsule is stopped by tree "+str(index+1)+" stone/soil bed")
  probe.position=tree.position+Vector3(1.30,.025,-1.5);probe.velocity=Vector3.ZERO
  check(await walk_to(tree.position+Vector3(1.30,0,1.4)),"tree "+str(index+1)+" keeps the adjacent ordinary crossing usable below its crown")
 var resources:=mesh_state(garden);var grains_before: Array=[];var textures: Dictionary={};var changed:=false;var appeared:=false
 for grain in garden.grains:grains_before.append(grain.position)
 var feeder_clock: float=visitor.actor_clock;var bird_position: Vector3=garden.feeding_pigeon.position
 garden.tick(.5,camera,9.1)
 check(is_equal_approx(visitor.actor_clock,feeder_clock) and garden.feeding_pigeon.position==bird_position,"garden tick does not tick its reused person or pigeon a second time")
 for sample in 24:
  var time: float=float(sample)*.17
  plaza.tick(.05,camera,time)
  var clock_after_plaza: float=visitor.actor_clock;var bird_after_plaza: Vector3=garden.feeding_pigeon.position
  garden.tick(.05,camera,time)
  if visitor.sprite.texture!=null:textures[hash(visitor.sprite.texture.get_image().get_data())]=true
  for index in garden.grains.size():
   changed=changed or garden.grains[index].position.distance_to(grains_before[index])>.15
   appeared=appeared or garden.grains[index].visible
  if not is_equal_approx(visitor.actor_clock,clock_after_plaza) or garden.feeding_pigeon.position!=bird_after_plaza:check(false,"Plaza remains sole activity tick owner");break
 check(changed and appeared and garden.grains.size()>=4,"native grain flecks visibly travel from the visitor toward the pigeon feeding spot")
 check(textures.size()>=2,"reused visitor actually changes its existing work-hand sprite frames")
 check(mesh_state(garden)==resources,"feeding time reuses all original garden mesh/material instances")
 check(plaza.people==original_people and plaza.birds==original_birds and visitor.profile==profile,"activity preserves original population references and appearance after animation")
 print("GARDEN NATIVE geometry_count=",garden.geometry_count," bed_bounds=",garden.bed_bounds," grains=",garden.grains.size())
 finish()
