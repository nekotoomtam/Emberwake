extends SceneTree
var failures: Array[String]=[]
var checks:=0
func check(value: bool,label: String) -> void:
 checks+=1
 if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var helper=load("res://scripts/opening/ship_hull_surface.gd")
 var data: Dictionary=helper.mesh_data()
 var incomplete: Dictionary=data.duplicate()
 var indices: PackedInt32Array=data.triangles.duplicate()
 indices.resize(indices.size()-3);incomplete.triangles=indices
 var broken: Dictionary=helper.geometry_report(incomplete)
 check(broken.boundary_edge_count==3,"geometry report detects a genuinely removed skin triangle")
 for path in ["res://scripts/opening/departure_ship.gd","res://scripts/opening/arrival_hull.gd"]:
  var ship=load(path).new()
  for key in ["shipwood","cream","wood","darkwood","gold","teal","window","canvas","rope"]:ship.materials[key]=StandardMaterial3D.new()
  get_root().add_child(ship)
  await process_frame
  check(is_instance_valid(ship.visual_root) and ship.visual_root.get_parent()==ship,"visual motion pivot owns complete ship geometry")
  check(ship.visual_root.get_child_count()==9,"native batched mesh construction retains material groups")
  check(ship.hull_geometry.boundary_edge_count==0 and ship.hull_geometry.enclosed_volume>300.0,"both consumers construct the actual closed skin")
  check(ship.geometry_count>1600,"closed skin and retained cabin rigging details are built")
  ship.queue_free();await process_frame
 var vertices: PackedVector3Array=data.vertices
 var indices_full: PackedInt32Array=data.triangles
 for x in [-13.0,-10.0,-5.0,0.0,5.0,10.0,13.0]:
  for y in [.1,.23,.5]:
   var found: float=-1.0
   for i in range(0,indices_full.size(),3):
    var a: Vector3=vertices[indices_full[i]];var b: Vector3=vertices[indices_full[i+1]];var c: Vector3=vertices[indices_full[i+2]]
    if maxf(a.z,maxf(b.z,c.z))<=0.0:continue
    var den: float=(b.y-c.y)*(a.x-c.x)+(c.x-b.x)*(a.y-c.y)
    if absf(den)<.00000001:continue
    var wa: float=((b.y-c.y)*(x-c.x)+(c.x-b.x)*(y-c.y))/den
    var wb: float=((c.y-a.y)*(x-c.x)+(a.x-c.x)*(y-c.y))/den
    var wc: float=1.0-wa-wb
    if minf(wa,minf(wb,wc))>=-.000001:found=wa*a.z+wb*b.z+wc*c.z;break
   check(found>=0.0 and absf(helper.waterline_half_width(x,y)-found)<.00001,"foam width agrees with an independent triangle intersection")
 print("CLOSED HULL INTEGRATION ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
