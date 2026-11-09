extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var camera := Camera3D.new();root.add_child(camera);camera.position=Vector3(0,12.5,11.5);camera.look_at(Vector3.ZERO)
 var visual=load("res://scripts/dual_hand_visual.gd").new();root.add_child(visual)
 for a in ["sword","mace","pistol"]:
  for b in ["sword","mace","pistol"]:
   for dir in [Vector3.RIGHT,Vector3.LEFT]:
    visual.reset_stance();visual.update_hands(camera,dir,[a+"0",b+"1"],[a,b],0,{},false,.016,false)
    var p: Dictionary=visual.rigs[0].get_blade_points();var q: Dictionary=visual.rigs[1].get_blade_points()
    if Geometry2D.segment_intersects_segment(camera.unproject_position(p.grip),camera.unproject_position(p.tip),camera.unproject_position(q.grip),camera.unproject_position(q.tip))!=null:failures.append(a+"/"+b+"/"+str(dir))
 visual.queue_free();camera.queue_free();await process_frame
 print("HOLDING SILHOUETTES: 18 cases ","PASS" if failures.is_empty() else "FAIL", " ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
