extends SceneTree
## Proves the removed main-quay strip is sea in native geometry and physics.
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func ray(world: Node3D,point: Vector3) -> Dictionary:
 return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*.8,point-Vector3.UP*.9,1))
func faces_at(node: Node,point: Vector2) -> int:
 var count:=0
 for mesh in node.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh==null:continue
  var faces: PackedVector3Array=mesh.mesh.get_faces()
  for i in range(0,faces.size(),3):
   var a: Vector3=mesh.to_global(faces[i]);var b: Vector3=mesh.to_global(faces[i+1]);var c: Vector3=mesh.to_global(faces[i+2])
   if minf(a.y,minf(b.y,c.y))<-.05 or maxf(a.y,maxf(b.y,c.y))>.10:continue
   if absf(a.y-b.y)>.0001 or absf(a.y-c.y)>.0001:continue
   if Geometry2D.is_point_in_polygon(point,PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])):count+=1
 return count
func crossing(at: Vector3,motion: Vector3,mask: int) -> KinematicCollision3D:
 var actor:=CharacterBody3D.new();actor.collision_layer=2;actor.collision_mask=mask
 var col:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.24;capsule.height=1.4;col.shape=capsule;col.position.y=.7;actor.add_child(col)
 root.add_child(actor);actor.position=at;var hit:=actor.move_and_collide(motion);actor.free();return hit
func run() -> void:
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 await physics_frame;await physics_frame
 for x in [-12.0,0.0,18.0,21.3]:
  check(ray(g.world,Vector3(x,0,16.8)).is_empty(),"removed main-quay strip has no hidden floor at x "+str(x))
  check(faces_at(g.world.main,Vector2(x,16.8))==0,"removed main-quay strip has no paving at x "+str(x))
 for x in [-12.0,0.0,18.0]:check(not ray(g.world,Vector3(x,0,14.5)).is_empty(),"remaining main quay is supported at x "+str(x))
 var south=g.world.quay_edge.get_node_or_null("QuaySouthRail")
 check(south!=null and absf(south.position.z-15.4)<.001,"main-quay south rail is flush with the long plaza edge")
 check(g.world.quay_edge.get_node_or_null("QuayShoreStep")==null,"obsolete original-quay south step is removed")
 var mask:=1<<21
 for body in g.world.quay_edge.find_children("*","StaticBody3D",true,false):body.collision_layer=mask
 await physics_frame
 for x in [-12.0,0.0,18.0]:
  var contact:=crossing(Vector3(x,.055,14.2),Vector3(0,0,2.5),mask)
  check(contact!=null and contact.get_collider()==south and absf(contact.get_normal().y)<.2,"actual player footprint meets the new straight rail at x "+str(x))
 check(crossing(Vector3(21.3,.055,14.3),Vector3(1.5,0,1.5),mask)!=null,"new southeast corner has no diagonal escape")
 for x in [11.2,13.0,14.8]:check(crossing(Vector3(x,.055,3.2),Vector3(0,0,-2.2),mask)==null,"original boarding opening remains clear at x "+str(x))
 g.free();await process_frame
 print("HARBOR FLAT QUAY ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
