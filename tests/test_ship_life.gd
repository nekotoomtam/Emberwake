extends SceneTree
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 var w=g.world;var a=w.arrival
 check(a.get("motion")!=null,"arrival has shared hull/crew/cargo swell pivot")
 check(w.get("ship_water")!=null,"moored foreground ship has water contact")
 check(a.get("water_contact")!=null,"arriving ship has water contact")
 check(w.has_method("main_ship_offset"),"playable deck provides render motion")
 if a.get("motion")!=null and w.has_method("main_ship_offset"):
  var initial: Transform3D=a.motion.transform
  var main_initial: Transform3D=w.ship.visual_root.transform
  var logical: Vector3=w.ship.position
  for i in 120:g.tick(1.0/60)
  check(a.motion.transform!=initial,"stationary arrival still gently floats")
  check(w.ship.visual_root.transform!=main_initial,"moored ship gently floats")
  check(w.ship.position==logical,"walk physics anchor stays stable")
  check(a.position==a.START_POSITION,"swell preserves exact scripted route anchor")
  check(a.crew[0].get_parent()==a.motion,"crew shares the moving deck transform")
  check(a.motion.get_node("ArrivalDeckCargo")!=null,"deck props share moving deck transform")
  for actor in a.crew:
   var deck_point: Vector3=a.motion.to_global(Vector3(actor.position.x,a.DECK_HEIGHT,actor.position.z))
   check(actor.global_position.distance_to(deck_point)<.0001,"incoming crew feet remain on transformed deck")
  for actor in w.crew:
   var expected: Vector3=actor.global_position+w.main_ship_offset(actor.global_position)+g.camera.global_basis.y*.864
   check(actor.sprite.global_position.distance_to(expected)<.0001,"moored crew art follows rendered deck")
  check(a.water_contact.intensity>0 and w.ship_water.intensity>0,"both stationary ships retain water laps")
  g.start_arrival()
  var water_clock: float=a.water_contact.phase_clock
  for i in 120:g.tick(1.0/60)
  check(a.water_contact.phase_clock>water_clock,"water shader animation advances")
  check(a.water_contact.cruising>0,"approach strengthens wake")
  check(absf(a.water_contact.global_position.y-a.water_contact.water_height)<.001,"foam stays at sea surface during swell")
  for i in 365:g.tick(1.0/60)
  check(a.docked and a.position==a.BERTH_POSITION,"swell preserves exact dock endpoint")
  var port=w.backdrop.district
  var crate: Node3D=port.ship_cargo[0]
  var rest: Transform3D=crate.get_meta("ship_rest_transform")
  check(crate.global_position.distance_to(rest.origin+a.deck_motion_offset(rest.origin))<.0001,"external ship stock follows deck")
  var aboard:=0
  for i in 4800:
   g.tick(1.0/60)
   for actor in port.couriers:
    if actor.position.y>2.1 and actor.position.z< -34.2:
     aboard+=1
     var expected: Vector3=actor.global_position+a.deck_motion_offset(actor.global_position)+g.camera.global_basis.y*.864
     check(actor.sprite.global_position.distance_to(expected)<.0001,"unloader art follows deck while aboard")
     break
   if aboard>0:break
  check(aboard>0,"unloader deck-motion case exercised")
  g.skip_arrival()
  g.walker.position=Vector3(10,2.315,-7)
  g.tick(1.0/60)
  check(g.walker.visual_offset.distance_to(w.main_ship_offset(g.walker.position))<.0001,"player art follows moving deck")
  g.walker.position=w.anchors.cafe
  g.tick(1.0/60)
  check(g.walker.visual_offset==Vector3.ZERO,"player on land gets no ship sway")
  g.return_title()
  check(a.position==a.START_POSITION and not a.docked,"replay restores sea-only ship start")
  check(a.water_contact.cruising==0,"replay clears cruise wake")
 g.free();await process_frame
 print("SHIP LIFE ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
