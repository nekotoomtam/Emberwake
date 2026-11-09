extends SceneTree
## Profile walking seam and actual flat slab/joint geometry, without GUI jobs.
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func flat_faces(node: Node,low: float,high: float,exclude: Node=null) -> Array:
 var result: Array=[]
 if node==exclude:return result
 if node is MeshInstance3D and node.mesh!=null:
  var faces: PackedVector3Array=node.mesh.get_faces()
  for i in range(0,faces.size(),3):
   var a: Vector3=node.to_global(faces[i]);var b: Vector3=node.to_global(faces[i+1]);var c: Vector3=node.to_global(faces[i+2])
   if a.y<low or a.y>high or absf(a.y-b.y)>.00001 or absf(a.y-c.y)>.00001:continue
   if absf((b-a).cross(c-a).y)<.000001:continue
   result.append([a,b,c])
 for child in node.get_children():result.append_array(flat_faces(child,low,high,exclude))
 return result
func faces_at(faces: Array,point: Vector2) -> int:
 var count:=0
 for face in faces:
  var a: Vector3=face[0];var b: Vector3=face[1];var c: Vector3=face[2]
  if Geometry2D.is_point_in_polygon(point,PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])):count+=1
 return count
func in_promenade(point: Vector2) -> bool:
 return (point.x>=-53.45-.0001 and point.x<=-51+.0001 and point.y>=-21-.0001 and point.y<=6.3+.0001) or (point.x>=-51-.0001 and point.x<=-19.7+.0001 and point.y>=4.3-.0001 and point.y<=6.3+.0001)
func run() -> void:
 # Keeping the v88 broad-road access would put the capsule across the marked
 # seam, while an over-inset limit would remove this usable inner walkway.
 for point in [Vector3(-53.3,.055,-3),Vector3(-53.3,.055,11),Vector3(-57,.055,-18),Vector3(-73,.055,11)]:
  check(not Profile.contains_ground(point),"scenic side is excluded from player ground at "+str(point))
 for point in [Vector3(-53.1,.055,-3),Vector3(-53.1,.055,11),Vector3(-52,.055,-18)]:
  check(Profile.contains_ground(point),"inner promenade remains available at "+str(point))
 for z in [-20.9,-3.0,6.3,16.9]:check(Profile.wrong_way_exit(Vector3(-53.3,.055,z)),"west seam warns throughout its authored extent at z "+str(z))
 check(not Profile.wrong_way_exit(Vector3(-53.1,.055,-3)),"inner promenade does not issue a premature warning")
 check(not Profile.rearm_wrong_way(Vector3(-53.1,.055,-3)),"held boundary input cannot rearm in the capsule margin")
 check(not Profile.rearm_wrong_way(Vector3(-52.55,.055,-3)) and Profile.rearm_wrong_way(Vector3(-52.49,.055,-3)),"moving inward about .7m rearms the next deliberate attempt")
 check(Profile.wrong_way_exit(Vector3(-24,.055,-22.8)) and Profile.contains_ground(Vector3(-24,.055,-22)),"existing north gate and supported approach remain")
 check(not Profile.rearm_wrong_way(Vector3(-24,.055,-22.4)),"western rearm rule cannot unlatch a held north-gate attempt")
 var profile=Profile.new()
 var constants: Dictionary=profile.get_script().get_script_constant_map()
 check(constants.has("QUAY_RECT"),"shared main-quay footprint is available to scene consumers")
 if constants.has("QUAY_RECT"):
  var quay: Rect2=constants.QUAY_RECT
  check(quay.has_point(Vector2(21.5,15.1)) and not quay.has_point(Vector2(0,16.0)),"shared quay footprint retains the route and removes the old foreground strip")
 var routes=load("res://scripts/opening/harbor_town_routes.gd").new();root.add_child(routes)
 var paving=routes.get("promenade")
 check(paving!=null,"town routes compose separately inspectable promenade tile geometry")
 if paving!=null:
  check(paving.is_in_group("harbor_promenade_paving"),"promenade meshes have their native inspection label")
  var slabs:=flat_faces(paving,.05499,.05501)
  var joints:=flat_faces(paving,.04299,.04301)
  check(slabs.size()>350,"both L arms emit real slab top faces at the flush .055 plane")
  check(joints.size()>=4,"both L arms have a visibly recessed joint bed")
  var outside:=0
  for face in slabs:
   for point in face:
    if not in_promenade(Vector2(point.x,point.z)):outside+=1
  check(outside==0,"actual tile faces stay inside the two exact promenade bands")
  for point in [Vector2(-52.2,-2.5),Vector2(-51.4,-19.3),Vector2(-40.2,4.7),Vector2(-40.2,5.5),Vector2(-20.2,5.5)]:
   check(faces_at(slabs,point)>0,"regular slabs cover the dressed walkway at "+str(point))
  for point in [Vector2(-51,4.7),Vector2(-40.6,4.7),Vector2(-52.2,-2.9)]:
   check(faces_at(slabs,point)==0 and faces_at(joints,point)>0,"world-aligned grid leaves a real visible joint at "+str(point))
  var retained:=flat_faces(routes,.050,.075,paving)
  for point in [Vector2(-53.36,-3),Vector2(-52.2,-2.5),Vector2(-51.4,6.25),Vector2(-50,6.25)]:
   check(faces_at(retained,point)==0,"old town footway and crossing trim do not overlap the new slab band at "+str(point))
 routes.free();await process_frame
 # The continuous collision floor must have a recessed visual base: lowering
 # only its decorative pavers leaves a coplanar support face over the new slabs
 # and hides the new grout. Exercise the actual consumer rather than a fixture.
 var plaza=load("res://scripts/opening/harbor_cafe_plaza.gd").new();root.add_child(plaza)
 var old_front:=flat_faces(plaza,.043,.0551)
 for point in [Vector2(-40.2,4.7),Vector2(-40.6,4.7),Vector2(-50,6.25),Vector2(-20.2,5.5)]:
  check(faces_at(old_front,point)==0,"plaza support and old pavers remain below the new tile/joint surfaces at "+str(point))
 plaza.free();await process_frame
 print("HARBOR PROMENADE PAVING ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
