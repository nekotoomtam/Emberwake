extends SceneTree
const PATH:="res://scripts/opening/harbor_passage_cargo.gd"
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
 print("HARBOR PASSAGE CARGO ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func solids_at(at: Vector3) -> Array:
 var query:=PhysicsShapeQueryParameters3D.new();var shape:=CapsuleShape3D.new();shape.radius=.24;shape.height=1.4
 query.shape=shape;query.transform=Transform3D(Basis.IDENTITY,at+Vector3.UP*.76);query.collision_mask=1
 return scene.get_world_3d().direct_space_state.intersect_shape(query)
func run() -> void:
 check(ResourceLoader.exists(PATH),"passage contains the requested wall-side cargo helper")
 if not ResourceLoader.exists(PATH):finish();return
 scene=Node3D.new();root.add_child(scene)
 var cargo=load(PATH).new();scene.add_child(cargo)
 await physics_frame;await physics_frame
 check(cargo.crates.size()==3,"wall-side cargo has three modest stacked wooden crates")
 check(cargo.geometry_count>30 and cargo.main.get_child_count()>0,"crates contain real rendered timber and braces")
 check(cargo.bounds.position.x>=-27.5 and cargo.bounds.end.x<=-26.0,"crate faces stay at the passage wall, outside its centre lane")
 check(cargo.bounds.position.z>=-21 and cargo.bounds.end.z<=-17.5 and cargo.bounds.size.y<1.6,"goods stay low and clear of the northern gate and flower frontage")
 var lane_clear:=true
 for z in [-22.0,-21.0,-20.0,-19.0,-18.0,-17.0]:lane_clear=lane_clear and solids_at(Vector3(-25,.055,z)).is_empty()
 check(lane_clear,"actual player capsule fits along the original north approach")
 var matched:=true
 for body in cargo.crates:
  matched=matched and body.collision_layer==1 and body.is_in_group("harbor_passage_cargo")
  var shape: CollisionShape3D=body.get_child(0)
  matched=matched and shape.shape is BoxShape3D and shape.shape.size.x>.5
 check(matched,"every rendered crate has its own solid wooden footprint")
 check(not solids_at(Vector3(-26.82,.055,-19.6)).is_empty(),"player-sized native collision query hits the low cargo")
 probe=CharacterBody3D.new();probe.collision_layer=2;probe.collision_mask=1;scene.add_child(probe)
 var collider:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.24;capsule.height=1.4;collider.shape=capsule;collider.position.y=.76;probe.add_child(collider);probe.position=Vector3(-25,.055,-19.6)
 var side_hit:=false
 for frame in ceili(1.1*Engine.physics_ticks_per_second):
  await physics_frame;probe.velocity=Vector3.LEFT*2.4;probe.move_and_slide()
  for slide in probe.get_slide_collision_count():
   var hit: KinematicCollision3D=probe.get_slide_collision(slide)
   for contact in hit.get_collision_count():
    var body: Object=hit.get_collider(contact)
    if body is Node and body.is_in_group("harbor_passage_cargo") and hit.get_normal(contact).x>.8:side_hit=true
 check(side_hit and probe.position.x>-26.2,"real native moving capsule stops on the visible crate side")
 finish()
