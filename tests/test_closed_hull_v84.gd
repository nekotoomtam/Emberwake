extends SceneTree
var failures: Array[String]=[]
var checks:=0
func check(value: bool,label: String) -> void:
 checks+=1
 if not value:failures.append(label)
func _initialize() -> void:
 var path: String="res://scripts/opening/ship_hull_surface.gd"
 check(ResourceLoader.exists(path),"shared closed hull geometry exists")
 if not failures.is_empty():finish();return
 var hull=load(path)
 var data: Dictionary=hull.mesh_data()
 var vertices: PackedVector3Array=data.vertices
 var triangles: PackedInt32Array=data.triangles
 check(vertices.size()>300 and triangles.size()>1500,"continuous surface has sufficient longitudinal/profile sampling")
 var edge_use: Dictionary={}
 var edge_direction: Dictionary={}
 var degenerate:=0
 var volume:=0.0
 var low:=Vector3(INF,INF,INF);var high:=Vector3(-INF,-INF,-INF)
 for vertex in vertices:low=low.min(vertex);high=high.max(vertex)
 for i in range(0,triangles.size(),3):
  var a: int=triangles[i];var b: int=triangles[i+1];var c: int=triangles[i+2]
  if (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).length_squared()<.0000000001:degenerate+=1
  volume+=vertices[a].dot(vertices[b].cross(vertices[c]))/6.0
  for edge in [[a,b],[b,c],[c,a]]:
   var key:=Vector2i(mini(edge[0],edge[1]),maxi(edge[0],edge[1]))
   edge_use[key]=int(edge_use.get(key,0))+1
   edge_direction[key]=int(edge_direction.get(key,0))+(1 if edge[0]<edge[1] else -1)
 var boundary:=0;var nonmanifold:=0;var mismatched:=0
 for key in edge_use:
  if edge_use[key]==1:boundary+=1
  if edge_use[key]!=2:nonmanifold+=1
  if edge_direction[key]!=0:mismatched+=1
 check(boundary==0,"stem stern keel and deck have no open boundary edges")
 check(nonmanifold==0,"every closed shell edge is shared by exactly two faces")
 check(mismatched==0,"shared face edges use consistent orientation")
 check(degenerate==0,"pointed stem fans contain no collapsed triangles")
 check(volume>300.0,"closed hull encloses outward-oriented volume")
 check(absf(low.x+14.2)<.0001 and absf(high.x-14.2)<.0001,"full original 28.4 metre hull length")
 check(absf(high.z-4.4)<.0001 and absf(low.z+4.4)<.0001,"full original 8.8 metre beam")
 check(absf(high.y-2.865)<.0001,"all top deck vertices keep original physical height")
 for side in [-14.2,14.2]:
  for vertex in vertices:
   if absf(vertex.x-side)<.0001:check(absf(vertex.z)<.0001,"end profile converges to closed pointed center stem")
 var centre_water: float=hull.waterline_half_width(0.0)
 check(centre_water>3.0 and centre_water<4.4,"waterline follows immersed bilge instead of deck beam")
 check(hull.waterline_half_width(14.2)==0.0 and hull.waterline_half_width(16.0)==0.0,"waterline terminates at pointed bow")
 var report: Dictionary=hull.geometry_report()
 check(report.boundary_edge_count==boundary and report.nonmanifold_edge_count==nonmanifold,"exposed geometry evidence is computed from actual triangles")
 print("HULL_METRICS ",JSON.stringify({"vertices":vertices.size(),"triangles":triangles.size()/3,"boundary":boundary,"nonmanifold":nonmanifold,"orientation_mismatch":mismatched,"volume":volume,"waterline_centre":centre_water,"bounds_min":str(low),"bounds_max":str(high)}))
 finish()
func finish() -> void:
 print("CLOSED HULL ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
