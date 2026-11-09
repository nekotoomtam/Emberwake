extends SceneTree
## Probe real authored mesh triangles, rather than trusting footprint metadata.
var checks:=0
var failures: Array[String]=[]
var face_cache: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures.append(message);printerr("FAIL: "+message)
func mesh_bounds(node: Node3D) -> AABB:
 var box:=AABB();var first:=true
 for mesh in node.find_children("*","MeshInstance3D",true,false):
  var actual: AABB=mesh.global_transform*mesh.get_aabb()
  box=actual if first else box.merge(actual);first=false
 return box
func faces(node: Node3D) -> PackedVector3Array:
 var id_: int=node.get_instance_id()
 if face_cache.has(id_):return face_cache[id_]
 var result:=PackedVector3Array()
 for mesh in node.find_children("*","MeshInstance3D",true,false):
  for point in mesh.mesh.get_faces():result.append(mesh.global_transform*point)
 face_cache[id_]=result
 return result
func native_hit(node: Node3D,from: Vector3,direction: Vector3,reach: float) -> Variant:
 var points:=faces(node);var nearest: Variant=null;var distance:=reach
 for i in range(0,points.size(),3):
  var hit: Variant=Geometry3D.ray_intersects_triangle(from,direction,points[i],points[i+1],points[i+2])
  if hit==null:continue
  var length_: float=from.distance_to(hit)
  if length_<=distance:distance=length_;nearest=hit
 return nearest
func house_vertices_bounds(house: Dictionary) -> AABB:
 var box:=AABB();var first:=true
 var region:=Rect2(Vector2(house.at.x-house.width*.66,house.at.z-house.depth*.66),Vector2(house.width*1.32,house.depth*1.32))
 for point in faces(house.node):
  if not region.has_point(Vector2(point.x,point.z)):continue
  if first:box=AABB(point,Vector3.ZERO);first=false
  else:box=box.expand(point)
 return box
func run() -> void:
 var path:="res://scripts/opening/harbor_city_waterfront_3d.gd"
 check(FileAccess.file_exists(path),"native waterfront extension helper exists")
 if not FileAccess.file_exists(path):finish();return
 var script=load(path)
 if script==null:check(false,"native waterfront extension parses");finish();return
 var city: Node3D=script.new();root.add_child(city);await process_frame
 check(city.geometry_count>500,"working district contains authored native detail")
 check(city.land_rect==Rect2(-164,-420,144,200),"new foundation uses the actual original city's northern land seam")
 var land:=mesh_bounds(city.main)
 check(land.position.x<=-164 and land.end.x>=-20 and land.position.z<=-420 and land.end.z>=-220,"real land mesh fills its entire seam-connected footprint")
 for x in [-160.0,-92.0,-25.0]:
  var hit: Variant=native_hit(city.main,Vector3(x,2,-220.01),Vector3.DOWN,4)
  check(hit!=null and absf(hit.y)<.002,"native foundation top meets the old ground datum at seam x="+str(x))
  hit=native_hit(city.main,Vector3(x,2,-419.5),Vector3.DOWN,4)
  check(hit!=null and absf(hit.y)<.002,"new northern land retains a real zero-height mesh surface")
 check(city.warehouses.size()==4 and city.loading_courts.size()==4 and city.jetties.size()==4,"four separated 3D loading bays continue the original working frontage")
 check(city.hoists.size()==4,"every working bay has an actual three-dimensional loading hoist")
 for warehouse in city.warehouses:
  var box:=mesh_bounds(warehouse.node)
  check(box.size.x>10 and box.size.z>12 and box.size.y>6 and box.size.y<12,"warehouse is a bounded 3D building at the native harbor scale")
  check(warehouse.wall_height>=4.5 and warehouse.wall_height<=7,"warehouse wall height stays within ordinary native two-storey proportions")
  var door: Vector3=warehouse.door
  var hit: Variant=native_hit(warehouse.node,door+Vector3(3,1.4,0),Vector3.LEFT,5)
  check(hit!=null and hit.x>door.x-.25,"real warehouse loading door faces the eastern wharf")
  var roof: Variant=native_hit(warehouse.node,warehouse.at+Vector3(0,14,-2),Vector3.DOWN,14)
  check(roof!=null and roof.y>warehouse.wall_height+1,"native pitched roof has an actual raised ridge")
 for court in city.loading_courts:
  var center: Vector2=court.rect.get_center()
  var hit: Variant=native_hit(court.node,Vector3(center.x,3,center.y),Vector3.DOWN,4)
  check(hit!=null and hit.y>=0 and hit.y<.15,"visible low loading court occupies the door-to-shore ground")
 for jetty in city.jetties:
  var middle: Vector3=jetty.start.lerp(jetty.end,.5)
  var hit: Variant=native_hit(jetty.node,middle+Vector3.UP*3,Vector3.DOWN,4)
  check(hit!=null and absf(hit.y-.43)<.015,"jetty has native timber deck triangles at the original ship-side working height")
  var ramp: Vector3=jetty.ramp_start.lerp(jetty.ramp_end,.5)
  hit=native_hit(jetty.node,ramp+Vector3.UP*2,Vector3.DOWN,3)
  check(hit!=null and absf(hit.y-ramp.y)<.015,"visible ramp genuinely rises from quay to pier rather than hovering or stepping")
  check(jetty.start.x< -19.5 and jetty.end.x<=9 and jetty.start.z< -230,"short eastern jetties remain in the distant extension beyond lighthouse waters")
 for hoist in city.hoists:
  var box:=mesh_bounds(hoist.node)
  check(box.size.x>2.5 and box.size.z>.5 and box.size.y>3.5,"working hoist has real mast, boom, foot and crosswise thickness")
  check(hoist.hook.y>1 and hoist.hook.y<hoist.tip.y-1,"suspended loading hook hangs below a genuine three-dimensional boom")
 check(city.houses.size()>=30 and city.rear_rows.size()>=6,"rear streets supply a substantial 3D transition into the two retained image layers")
 for house in city.houses:
  var box:=house_vertices_bounds(house)
  check(box.size.x>=7 and box.size.x<13 and box.size.z>7 and box.size.y<12,"rear house is a full small 3D volume, not a giant painted facade")
 var whole:=mesh_bounds(city)
 print("WATERFRONT 3D native pieces=",city.geometry_count," meshes=",city.find_children("*","MeshInstance3D",true,false).size()," rear_bounds=",city.bounds.rear," frontage_bounds=",city.bounds.frontage," all_bounds=",whole)
 check(whole.position.x>=-164.1 and whole.end.x<=9.1 and whole.position.z>=-421 and whole.end.z<=-219.9,"all new native geometry stays within the bounded northern district")
 check(city.find_children("*","CollisionObject3D",true,false).is_empty() and city.find_children("*","CollisionShape3D",true,false).is_empty(),"decorative city extension adds no physics or new exploration floor")
 check(city.find_children("*","NavigationRegion3D",true,false).is_empty() and city.find_children("*","Sprite3D",true,false).is_empty(),"waterfront uses native 3D buildings without a replacement painted front layer or navigation region")
 check(not city.is_processing() and not city.is_physics_processing() and not city.has_method("tick"),"static district owns no actor or per-frame activity clock")
 var ids: Array=[]
 for mesh in city.find_children("*","MeshInstance3D",true,false):ids.append([mesh.get_instance_id(),mesh.mesh.get_instance_id(),mesh.transform])
 await process_frame;await process_frame
 var after: Array=[]
 for mesh in city.find_children("*","MeshInstance3D",true,false):after.append([mesh.get_instance_id(),mesh.mesh.get_instance_id(),mesh.transform])
 check(ids==after,"native district retains exactly the same mesh resources and transforms across frames")
 city.queue_free();await process_frame
 finish()
func finish() -> void:
 print("HARBOR CITY WATERFRONT 3D "+str(checks)+" checks; "+("PASS[]" if failures.is_empty() else "FAIL "+str(failures)))
 quit(0 if failures.is_empty() else 1)
