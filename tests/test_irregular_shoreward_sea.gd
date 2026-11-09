extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
 var sea=load("res://scripts/opening/harbor_sea_surface.gd").new();root.add_child(sea)
 var left_error:=0.0;var right_error:=0.0;var repeat_difference:=0.0
 for i in 160:
  var p:=Vector2(38+i*.4,-53+i*.07);var initial: float=sea.surface_height(p,0)
  left_error+=absf(initial-sea.surface_height(p+Vector2(-1.2,0),.4))
  right_error+=absf(initial-sea.surface_height(p+Vector2(1.2,0),.4))
  repeat_difference+=absf(initial-sea.surface_height(p,4))
 check(left_error<right_error*.8,"dominant wave travel is shoreward -X, screen right to left")
 check(repeat_difference/160>.04,"sea does not repeat the old four-second pattern")
 var peaks: Array[float]=[];var times: Array[float]=[];var low:=INF;var high:=-INF
 var previous: float=sea.surface_height(Vector2(68,-53),-.05);var current: float=sea.surface_height(Vector2(68,-53),0)
 for i in range(1,801):
  var next: float=sea.surface_height(Vector2(68,-53),i*.05);low=minf(low,next);high=maxf(high,next)
  if current>previous and current>next:peaks.append(current);times.append((i-1)*.05)
  previous=current;current=next
 check(high-low>.7,"offshore waves have substantial real vertical displacement")
 var peak_range:=0.0;var spacing_range:=0.0
 if peaks.size()>3:
  peak_range=peaks.max()-peaks.min()
  var intervals: Array[float]=[]
  for i in range(1,times.size()):intervals.append(times[i]-times[i-1])
  spacing_range=intervals.max()-intervals.min()
 check(peak_range>.15,"successive waves have visibly different crest heights")
 check(spacing_range>.2,"successive wave arrivals have unequal spacing")
 var dry:=true
 var profile=load("res://scripts/opening/harbor_plaza_profile.gd")
 for p in profile.WALK_ROUTE:
  for i in 121:dry=dry and sea.surface_height(Vector2(p.x,p.z),i*.23)<.04
 check(dry,"sheltered quay and walking route remain above the water")
 var source=load("res://scripts/opening/harbor_sea_water.gdshader")
 check(not "seamless four-second" in source.code,"rendering is not tied to the retired loop")
 print("IRREGULAR SEA METRICS left_error=",left_error," right_error=",right_error," range=",high-low," peak_variation=",peak_range," spacing_variation=",spacing_range)
 sea.free();await process_frame
 print("IRREGULAR SHOREWARD SEA ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
