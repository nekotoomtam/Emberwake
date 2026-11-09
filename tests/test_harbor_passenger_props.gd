extends SceneTree
## Standalone native fixture: removal or oversizing of a real solid must fail.
var checks:=0
var failures: Array[String]=[]
var props: Node3D
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures.append(message);printerr("FAIL: "+message)
func ray(a: Vector3,b: Vector3) -> Dictionary:
 return props.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
func blocked(a: Vector3,b: Vector3,expected: PhysicsBody3D=null) -> bool:
 var hit:=ray(a,b)
 return not hit.is_empty() and (expected==null or hit.collider==expected)
func clear_sweep(a: Vector3,b: Vector3) -> bool:
 var capsule:=CapsuleShape3D.new();capsule.radius=.27;capsule.height=1.82
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1
 query.transform=Transform3D(Basis.IDENTITY,a+Vector3.UP*.96);query.motion=b-a;query.margin=.001
 var space:=props.get_world_3d().direct_space_state
 return space.intersect_shape(query,1).is_empty() and space.cast_motion(query)[0]>.999
func mesh_bounds(node: Node3D) -> AABB:
 var result:=AABB();var first:=true
 for child in node.find_children("*","MeshInstance3D",true,false):
  var box: AABB=child.global_transform*child.get_aabb()
  result=box if first else result.merge(box);first=false
 return result
func run() -> void:
 var path:="res://scripts/opening/harbor_passenger_props.gd"
 check(FileAccess.file_exists(path),"passenger prop helper exists")
 if not FileAccess.file_exists(path):finish();return
 var script=load(path)
 if script==null:check(false,"passenger prop helper parses");finish();return
 props=script.new();root.add_child(props)
 await process_frame;await physics_frame;await physics_frame
 check(props.main!=null and props.geometry_count>70,"authored furniture produces native geometry")
 var visual:=mesh_bounds(props)
 check(visual.position.x> -14 and visual.end.x< -1.5 and visual.position.z>2.35 and visual.end.z<4.9,"native visible groups stay inside their compact approved furniture band")
 check(visual.end.y<2.2,"departure props leave sea and ship sightlines above human height")
 check(props.bounds.keys().size()==4,"bench, board, cart and rope footprints are available to composition")
 check(props.bench_body!=null and props.prop_bodies.has(props.bench_body),"bench belongs to the actual prop collision inventory")
 check(blocked(Vector3(-12.7,1.3,3.83),Vector3(-12.7,.1,3.83),props.bench_body),"real bench slats support the seated traveller")
 var seat:=ray(Vector3(-12.7,1.3,3.83),Vector3(-12.7,.1,3.83))
 check(not seat.is_empty() and absf(seat.position.y-.5275)<.004,"bench seat keeps the cafe's original corrected world contact height")
 check(blocked(Vector3(-12.7,.975,4.6),Vector3(-12.7,.975,3.2),props.bench_body),"bench back has contact at its actual upper slat")
 check(blocked(Vector3(-13.52,.27,4.6),Vector3(-13.52,.27,3.4),props.bench_body),"bench iron leg has native contact")
 check(ray(Vector3(-12.7,.25,4.6),Vector3(-12.7,.25,3.25)).is_empty(),"bench open space below the seat has no broad invisible wall")
 check(clear_sweep(Vector3(-14.5,.055,5.4),Vector3(-10.7,.055,5.4)),"public bypass in front of bench is wide enough for the actor capsule")
 check(blocked(Vector3(-8,1.45,5),Vector3(-8,1.45,3.1)),"departure board face physically blocks an approach")
 check(blocked(Vector3(-8.94,.45,4.4),Vector3(-8.94,.45,3.0)),"departure board post physically blocks at shin height")
 check(ray(Vector3(-8,.45,4.4),Vector3(-8,.45,3.0)).is_empty(),"departure board has real open space between narrow posts")
 var labels:=props.find_children("*","Label3D",true,false)
 check(labels.size()>=2,"native departure marker includes a pier heading and schedule")
 var readable:=true
 for label in labels:
  if label.font==null:readable=false;continue
  for index in label.text.length():
   var character: int=label.text.unicode_at(index)
   if character>32 and not label.font.has_char(character):readable=false
 check(readable,"every visible departure glyph has a native font character")
 check(blocked(Vector3(-3.22,.65,5.2),Vector3(-3.22,.65,3.1)),"strapped trunk body physically blocks an approach")
 check(blocked(Vector3(-3.37,.295,5.2),Vector3(-3.37,.295,4.45)),"trolley's visible wheel has native solid contact")
 check(blocked(Vector3(-1.80,1.175,5.2),Vector3(-1.80,1.175,3.1)),"trolley handle crossbar physically blocks at its rendered height")
 check(ray(Vector3(-1.80,.75,4.1),Vector3(-1.80,.75,4.25)).is_empty(),"empty trolley handle opening has no broad hidden box")
 check(clear_sweep(Vector3(-1.0,.055,3.2),Vector3(-1.0,.055,5.4)),"porter-side bypass remains clear outside the actual trolley")
 for center in [Vector3(-11.2,.055,2.85),Vector3(-4.9,.055,2.8)]:
  check(blocked(center+Vector3(.32,.7,0),center+Vector3(.32,-.03,0)),"rope coil outer turn has ground-level contact "+str(center.x))
  check(ray(center+Vector3(0,.7,0),center+Vector3(0,-.03,0)).is_empty(),"rope coil center remains a visible and physical hole "+str(center.x))
 for z in [6.0,7.4,11.6,13.2]:
  check(clear_sweep(Vector3(-17,.055,z),Vector3(18,.055,z)),"full-width retained crossing lane stays clear at z="+str(z))
 check(clear_sweep(Vector3(1.1,.055,4.6),Vector3(9.4,.055,4.6)),"original yard porter's route stays outside new solids")
 check(clear_sweep(Vector3(13,.055,-4.8),Vector3(13,.055,3.0)),"original boarding gangway envelope stays outside new solids")
 var shape_count:=0
 for body in props.prop_bodies:
  check(body.collision_layer==1 and body.collision_mask==0,"static forecourt solid has the public scenery collision layer")
  for child in body.get_children():
   if child is CollisionShape3D and child.shape!=null:shape_count+=1
 check(shape_count>30,"substantial details use fitted component solids")
 props.queue_free();await process_frame
 finish()
func finish() -> void:
 print("HARBOR PASSENGER PROPS "+str(checks)+" checks; "+("PASS[]" if failures.is_empty() else "FAIL "+str(failures)))
 quit(0 if failures.is_empty() else 1)
