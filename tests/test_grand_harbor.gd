extends SceneTree
const PlazaProfile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 var vessel=g.world.get("arrival")
 check(vessel!=null,"large scripted incoming vessel integrated")
 check(g.world.lighthouse.position.distance_to(g.world.anchors.cafe)>140,"lighthouse distant from main berth")
 check(g.camera.get("intro_duration")!=null,"ship-tracking opening camera")
 check(g.world.get("cup")!=null,"real movable coffee cup")
 if vessel!=null:
  var port=g.world.backdrop.district
  check(vessel.crew.size()==4,"incoming large ship has animated attached crew")
  check(not vessel.docked and vessel.progress==0,"incoming ship waits for Start")
  var initial: Vector3=vessel.position
  g.start_arrival()
  for i in 120:g.tick(1.0/60)
  check(vessel.position.distance_to(initial)>3,"ship actually approaches harbor")
  check(not port.arrival_ready and port.deliveries==0,"no unloading from ship before docking")
  for actor in vessel.crew:
   var deck_point: Vector3=vessel.motion.to_global(Vector3(actor.position.x,2.865,actor.position.z))
   check(actor.global_position.distance_to(deck_point)<.0001,"crew remains on moving ship deck")
  for i in 365:g.tick(1.0/60)
  check(vessel.docked and vessel.position.distance_to(Vector3(12,-.55,-38))<.01,"large vessel docks at reserved terminal")
  check(port.arrival_ready,"docking enables unloading")
  check(g.phase==&"flyin","camera continues pulling back after docking")
  for i in 370:g.tick(1.0/60)
  check(g.phase==&"line","camera ends at seated coffee line")
  check(g.camera.position.distance_to(PlazaProfile.CAFE_CAMERA)<.01,"continuous rail ends at exact cafe camera")
  for i in 6600:g.tick(1.0/60)
  check(port.deliveries>=2 and port.delivery_piles.size()>=2,"real unloading loops create delivered cargo piles")
  check(g.phase==&"play","opening still hands off walking")
  if g.world.get("cup")!=null:check(g.world.cup.global_position.distance_to(PlazaProfile.CUP_REST)<.01,"cup rests on saucer after standing")
  g.return_title()
  check(vessel.position==initial and not vessel.docked and port.deliveries==0,"replay resets ship and unload cycle")
  g.start_arrival();g.skip_arrival()
  check(g.phase==&"play" and vessel.docked and port.arrival_ready,"skip leaves coherent docked world")
 g.free();await process_frame
 print("GRAND HARBOR ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
