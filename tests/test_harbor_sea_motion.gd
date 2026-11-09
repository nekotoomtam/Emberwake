extends SceneTree
## Static render geometry, bounded water reference and absolute shader clock.
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func finish(helper=null) -> void:
 if helper!=null:helper.free()
 print("HARBOR SEA MOTION ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func near_float(a: float,b: float) -> bool:return absf(a-b)<.00001
func run() -> void:
 var path:="res://scripts/opening/harbor_sea_surface.gd"
 check(ResourceLoader.exists(path),"native sea helper supplies local heave and shoreward wave rendering")
 if not ResourceLoader.exists(path):finish();return
 var sea=load(path).new();root.add_child(sea)
 check(sea.name=="OpenSea","sea remains directly addressable by its existing scene name")
 check(sea.near_mesh is MeshInstance3D and sea.far_mesh is MeshInstance3D and sea.shore_mesh is MeshInstance3D,"near, far and shoreline geometry are independently inspectable")
 check(sea.water_material is ShaderMaterial and sea.shore_material is ShaderMaterial,"water and wash use reusable shader materials")
 check(sea.near_mesh.material_override==sea.water_material and sea.far_mesh.material_override==sea.water_material,"near and far geometry share the exact same animated water material")
 check(sea.find_children("*","CollisionObject3D",true,false).is_empty(),"visual waves introduce no collision or navigation bodies")
 var near_arrays: Array=sea.near_mesh.mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array=near_arrays[Mesh.ARRAY_VERTEX]
 var indices: PackedInt32Array=near_arrays[Mesh.ARRAY_INDEX]
 check(vertices.size()>25000 and indices.size()>120000,"near harbor receives dense local displacement geometry")
 var longest:=0.0
 for i in range(0,indices.size(),3):
  var a: Vector3=vertices[indices[i]];var b: Vector3=vertices[indices[i+1]];var c: Vector3=vertices[indices[i+2]]
  longest=maxf(longest,maxf(a.distance_to(b),maxf(b.distance_to(c),c.distance_to(a))))
 check(longest<=2.2,"near-surface triangle edges resolve harbor-scale waves")
 var bounds: AABB=sea.near_mesh.mesh.get_aabb()
 check(near_float(bounds.position.y,-.85) and near_float(sea.MEAN_LEVEL,bounds.position.y),"water mesh rests 85 cm below the quay datum")
 check(bounds.position.x<=-110 and bounds.end.x>=145 and bounds.position.z<=-245 and bounds.end.z>=45,"near-surface covers all foreground harbor views")
 var far_intrusions:=0
 var edge_keys: Dictionary={}
 for vertex in vertices:
  if near_float(vertex.x,-110) or near_float(vertex.x,145) or near_float(vertex.z,-245) or near_float(vertex.z,45):edge_keys[Vector2(vertex.x,vertex.z)]=false
 for surface in sea.far_mesh.mesh.get_surface_count():
  var arrays: Array=sea.far_mesh.mesh.surface_get_arrays(surface)
  var far_vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var far_indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
  for vertex in far_vertices:
   var key:=Vector2(vertex.x,vertex.z)
   if edge_keys.has(key):edge_keys[key]=true
  for i in range(0,far_indices.size(),3):
   var center: Vector3=(far_vertices[far_indices[i]]+far_vertices[far_indices[i+1]]+far_vertices[far_indices[i+2]])/3.0
   if center.x> -110.0001 and center.x<144.9999 and center.z> -244.9999 and center.z<44.9999:far_intrusions+=1
 check(far_intrusions==0,"far ocean cannot cover near-surface troughs with overlapping triangles")
 var seam_missing:=0
 for present in edge_keys.values():
  if not present:seam_missing+=1
 check(seam_missing==0,"every displaced near-ocean boundary vertex is shared by an exterior patch")
 var minimum:=INF;var maximum:=-INF;var motion:=0.0
 for point in [Vector2(-62,19),Vector2(3,-2),Vector2(24,11),Vector2(70,-90)]:
  var low:=INF;var high:=-INF
  for i in 81:
   var height: float=sea.surface_height(point,float(i)*.05)
   minimum=minf(minimum,height);maximum=maxf(maximum,height);low=minf(low,height);high=maxf(high,height)
  motion=maxf(motion,high-low)
 check(minimum>=sea.MEAN_LEVEL-sea.WAVE_LIMIT-.00001 and maximum<=sea.MEAN_LEVEL+sea.WAVE_LIMIT+.00001,"sampled heave remains inside the authored swell envelope below the quay")
 check(motion>.045,"the harbor surface genuinely rises and falls over time")
 var spatial: float=absf(sea.surface_height(Vector2(-62,19),1.1)-sea.surface_height(Vector2(24,11),1.1))
 check(spatial>.01,"surface includes local rolling shape rather than uniform translation")
 check(not near_float(sea.surface_height(Vector2(12,-4),.6),sea.surface_height(Vector2(12,-4),4.6)),"water no longer repeats the retired four-second cycle")
 var before_meshes: Array=[sea.near_mesh.mesh,sea.far_mesh.mesh,sea.shore_mesh.mesh]
 var before_materials: Array=[sea.water_material,sea.shore_material]
 sea.set_clock(1.25)
 check(near_float(sea.clock,1.25) and near_float(float(sea.water_material.get_shader_parameter("clock")),1.25) and near_float(float(sea.shore_material.get_shader_parameter("clock")),1.25),"one absolute clock reaches both animated render layers")
 sea.set_clock(1.25)
 check(near_float(sea.clock,1.25),"paused/repeated clock updates do not accumulate another delta")
 sea.set_clock(.25)
 check(near_float(sea.clock,.25) and near_float(float(sea.shore_material.get_shader_parameter("clock")),.25),"replay can set an earlier absolute wave time")
 check(sea.near_mesh.mesh==before_meshes[0] and sea.far_mesh.mesh==before_meshes[1] and sea.shore_mesh.mesh==before_meshes[2] and sea.water_material==before_materials[0] and sea.shore_material==before_materials[1],"clock updates reuse every uploaded mesh and material")
 check(sea.shore_segments.size()==7,"all authored public shoreline intervals are represented")
 var allowed: Array=[]
 for row in sea.shore_segments:
  var a: Vector2=row.a;var b: Vector2=row.b;var out: Vector2=row.outward
  check(absf(out.length()-1)<.0001 and absf((b-a).normalized().dot(out))<.0001,"shore segment has a unit seaward normal")
  allowed.append({"a":a,"b":b,"outward":out})
 var shore_arrays: Array=sea.shore_mesh.mesh.surface_get_arrays(0)
 var shore_vertices: PackedVector3Array=shore_arrays[Mesh.ARRAY_VERTEX]
 check(shore_vertices.size()>1000,"washing waves have enough static geometry to follow the local water height")
 var invalid_foam:=0;var boarding_foam:=0
 for vertex in shore_vertices:
  var point:=Vector2(vertex.x,vertex.z);var found:=false
  for row in allowed:
   var tangent: Vector2=(row.b-row.a).normalized();var offset: Vector2=point-row.a
   var along: float=offset.dot(tangent);var outward: float=offset.dot(row.outward)
   if along>=.1 and along<=(row.b-row.a).length()-.1 and outward>=.249 and outward<=2.5:found=true;break
  if not found:invalid_foam+=1
  if point.x>4.8 and point.x<9.2 and point.y<2.1 and point.y> -2.6:boarding_foam+=1
 check(invalid_foam==0,"every wash vertex stays seaward with padded shore endpoints")
 check(boarding_foam==0,"shore foam never spills into the original boarding opening")
 print("SEA RESOURCES near_vertices=",sea.near_vertex_count," far_vertices=",sea.far_vertex_count," shore_vertices=",sea.shore_vertex_count," shore_patches=",sea.shore_patch_count," triangles=",sea.geometry_count," meshes=3 materials=2 shaders=2 clock=",sea.clock)
 finish(sea)
