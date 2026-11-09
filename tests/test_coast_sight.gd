extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(v: bool,s: String) -> void:
 checks+=1
 if not v:failures.append(s);printerr("FAIL: ",s)
func masks(g) -> float:
 var amount:=0.0
 for i in range(6):
  var v=g.vision.material.get_shader_parameter("npc%d_enabled"%i)
  if v!=null:amount+=float(v)
 return amount
func run() -> void:
 var g=load("res://scenes/game.tscn").instantiate();g.loadout.save_path="";root.add_child(g);g.set_physics_process(false);g.start_run(true);g.clear_actors();g.player.position=Vector3.ZERO;g.test_aim=Vector3.RIGHT
 for at in [Vector3(2,.03,0),Vector3(2.5,.03,.6)]:
  var e=g.spawn_enemy("fisherman",at);e.tick(.0001,g)
 g.vision.update_view(0);check(masks(g)>1.9,"visible ordinary bodies keep pixel alpha sharp")
 g.test_aim=Vector3.LEFT;g.vision.update_view(0);check(masks(g)==0,"offscreen-direction normals have no reveal")
 var wall:=StaticBody3D.new();wall.collision_layer=1;var c:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.2,3,4);c.shape=shape;wall.add_child(c);wall.position=Vector3(1,1,0);g.add_child(wall);await physics_frame;await physics_frame;g.test_aim=Vector3.RIGHT;g.vision.update_view(0);check(masks(g)==0,"wall disables ordinary alpha masks")
 wall.free();g.start_coast();g.player.position=Vector3(0,.03,g.arena.shoreline(0)-.6);g.test_aim=Vector3.BACK;await physics_frame;await physics_frame
 check(g.vision.clear_line(g.player.position,g.player.position+Vector3.BACK*3),"movement-only shoreline does not occlude sea")
 check(g.player.collision_mask & 8 != 0,"coast player collides with movement boundary layer")
 g.start_run(true);check(g.player.collision_mask==1,"legacy player collision mask restored")
 g.queue_free();await process_frame;await process_frame
 print("COAST SIGHT: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
