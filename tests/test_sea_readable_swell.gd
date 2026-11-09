extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
 var sea=load("res://scripts/opening/harbor_sea_surface.gd").new();root.add_child(sea)
 var max_motion:=0.0;var highest:=-INF;var lowest:=INF
 for point in [Vector2(70,-38),Vector2(12,-38),Vector2(-43,19),Vector2(20,-7)]:
  var low:=INF;var high:=-INF
  for i in 121:
   var y: float=sea.surface_height(point,float(i)/30);low=minf(low,y);high=maxf(high,y)
  max_motion=maxf(max_motion,high-low);highest=maxf(highest,high);lowest=minf(lowest,low)
 check(max_motion>.30,"sea has visibly readable vertical swell instead of centimetre-scale shimmer")
 check(highest<sea.MEAN_LEVEL+sea.WAVE_LIMIT and lowest>sea.MEAN_LEVEL-sea.WAVE_LIMIT,"offshore swell stays within its enlarged visual bounds")
 var bounds: AABB=sea.near_mesh.custom_aabb
 check(bounds.position.y<=sea.MEAN_LEVEL-sea.WAVE_LIMIT and bounds.end.y>=sea.MEAN_LEVEL+sea.WAVE_LIMIT,"culling bounds contain the full visible swell")
 var mesh=sea.near_mesh.mesh;sea.set_clock(.7)
 check(sea.near_mesh.mesh==mesh and float(sea.water_material.get_shader_parameter("clock"))==.7,"swell reuses geometry and follows the scene clock")
 var repeated: float=sea.surface_height(Vector2(44,-38),.7)
 check(absf(repeated-sea.surface_height(Vector2(44,-38),4.7))>.00001,"water no longer repeats the old short cycle")
 sea.free();await process_frame
 print("READABLE SEA SWELL ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
