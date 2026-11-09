extends SceneTree
var g
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
 g=load("res://scenes/game.tscn").instantiate();g.loadout.save_path="";root.add_child(g);g.set_physics_process(false);g.start_wreck_shore();await physics_frame;await physics_frame
 check(g.arena.get("east_rocks")!=null,"continuous right headland authored")
 if g.arena.get("east_rocks")!=null:check(g.arena.east_rocks.size()>=12,"overlapping headland reaches sea")
 var profile_=load("res://scripts/wreck_shore_profile.gd")
 for offset in [1.0,3.0,5.0]:
  var query:=PhysicsShapeQueryParameters3D.new();var ball:=SphereShape3D.new();ball.radius=.25;query.shape=ball;query.collision_mask=1
  query.transform=Transform3D(Basis.IDENTITY,Vector3(61,.8,profile_.coast_z(61)+offset))
  var hits: Array=g.player.get_world_3d().direct_space_state.intersect_shape(query)
  check(not hits.is_empty() and hits[0].collider.get_parent()==g.arena.main,"physical right headland seals shoreline band "+str(offset))
 var surf=g.arena.surge
 check(surf.has_method("surf_front"),"repeating swash independent of capped intro age")
 if surf.has_method("surf_front"):
  var profile=load("res://scripts/wreck_shore_profile.gd");var values: Array=[]
  for i in 25:values.append(surf.surf_front(20,i*.25,0))
  check(values.max()-values.min()>2.5,"surf advances several units onto sand")
  check(values.min()<profile.sea_z(20)-2,"wave visibly crosses shoreline")
  check(absf(surf.surf_front(20,1,0)-surf.surf_front(20,7,0))<.001,"seamless recurring wave period")
  surf.update_wave(1,4.2,g.arena.landing_point,g.arena.wash_origin)
  var before: float=surf.clock;var front: float=surf.surf_front(20,surf.clock,0)
  surf.update_wave(1,4.2,g.arena.landing_point,g.arena.wash_origin)
  check(surf.clock>before and absf(front-surf.surf_front(20,surf.clock,0))>.01,"swash advances after intro age is capped")
 g.free();await process_frame;print("HEADLAND SURF ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
