extends SceneTree
var g
var count:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 count+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func close(a: float,b: float,label: String) -> void:check(absf(a-b)<.001,label+" got="+str(a))
func equip(id: String,hand: String) -> void:
 var index: int=g.loadout.bag.find(id)
 var src: Dictionary={"kind":"bag","index":index}
 if index<0:
  for i in range(2):
   for h in ["main","off"]:
    if g.loadout.sets[i][h]==id:src={"kind":"slot","set":i,"hand":h}
 var dst:={"kind":"slot","set":0,"hand":hand}
 if src!=dst:check(g.loadout.move_item(src,dst),"equip fixture")
func fresh(main: String,off: String="") -> void:
 g.loadout.defaults();g.loadout.unequip({"kind":"slot","set":0,"hand":"off"});equip(main,"main")
 if off!="":equip(off,"off")
 g.loadout_edited();g.start_run(true);g.test_aim=Vector3.RIGHT;g.stats.base.critical_chance=0
 for e in g.enemies:e.position=Vector3(100,0,100)
func advance(t: float) -> void:
 while t>.0000001:
  var dt: float=minf(t,1.0/120);g.tick(dt);t-=dt
func right(on: bool) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=on;root.push_input(e,true)
func run() -> void:
 g=load("res://scenes/game.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.loadout.save_path=""
 fresh("pistol0");check(g.request_attack(),"single starts");advance(.2);close(g.motion.elapsed,.2,"single full attackspeed")
 fresh("pistol0","pistol1");check(g.request_attack(),"dual starts");advance(.08);close(g.motion.elapsed,.06,"dual attackspeed75");check(g.item_magazines.pistol0.rounds==10,"dual delayed release");advance(.02);check(g.item_magazines.pistol0.rounds==9 and g.item_magazines.pistol1.rounds==10,"firsthand spends only ownround")
 advance(.66);check(g.motion.busy,"dual .76stillbusy");advance(.03);check(not g.motion.busy,"dual .79finished");check(g.item_magazines.pistol0.rounds==9 and g.item_magazines.pistol1.rounds==9,"independent magazines");close(g.motion.definition(0).damage,18,"damage unchanged");close(g.stamina,94,"paircost6 unchanged")
 fresh("pistol0","sword0");g.request_attack();advance(.1);close(g.motion.elapsed,.075,"mixedpair also slower")
 fresh("sword0","mace0");g.request_attack();advance(.1);close(g.motion.elapsed,.075,"meleepair slower")
 fresh("pistol0","pistol1");g.item_magazines.pistol0.rounds=3;g.item_magazines.pistol1.rounds=7;check(g.request_reload(),"reload starts");advance(.51);check(g.item_magazines.pistol0.rounds==3,"dual reload slowed");advance(.17);check(g.item_magazines.pistol0.rounds==10 and g.item_magazines.pistol1.rounds==7,"only selected pistol reloaded")
 fresh("pistol0");right(true);advance(.25);check(not g.ready_visual.line_visible,"pistol no helperray");check(not g.rifle_scope.visible,"pistol no scopevignette");close(g.camera.size,13.5,"no pistol camerazoom");close(g.vision.reach(),10,"no sightboost");g.request_attack();close(g.stamina,96.1,"aim cost30percent");advance(.08)
 check(not g.staff_flight.active.is_empty(),"actualbullet released")
 if not g.staff_flight.active.is_empty():close(g.staff_flight.active[0].damage,18,"actualbullet damage18");close(g.staff_flight.active[0].max_range,7,"actualbullet rangeunchanged")
 check(g.has_method("gun_spread"),"dynamic pistol spread available")
 if g.has_method("gun_spread"):
  fresh("pistol0");close(rad_to_deg(g.gun_spread("pistol",false)),8,"hip8");right(true);advance(.125);var mid: float=rad_to_deg(g.gun_spread("pistol",true));check(mid>2.5 and mid<8,"gradual realspread");advance(.125);close(rad_to_deg(g.gun_spread("pistol",true)),2.5,"ADS2.5");right(false)
  fresh("pistol0","pistol1");close(rad_to_deg(g.gun_spread("pistol",false)),8/.75,"dual hip wider");right(true);advance(.25);close(rad_to_deg(g.gun_spread("pistol",true)),2.5/.75,"dual ADS wider");g.request_attack();advance(.8);close(g.stamina,92.2,"dual aimedcost7.8");right(false)
  fresh("rifle0");close(rad_to_deg(g.gun_spread("rifle",false)),12,"riflehip unchanged");g.request_attack();advance(.2);close(g.motion.elapsed,.2,"twohandfullspeed")
 edge_cases()
 dispersion_cases()
 g.queue_free();await process_frame
 print("PISTOL DUAL BALANCE: ",count," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)

func edge_cases() -> void:
 fresh("pistol0","pistol1");g.request_attack();g.tick(.8)
 check(not g.motion.busy and not g.pair_strikes.active,"coarse pair completes")
 check(g.item_magazines.pistol0.rounds==9 and g.item_magazines.pistol1.rounds==9,"coarse pair spends1each")
 fresh("pistol0","pistol1");g.item_magazines.pistol0.rounds=3;g.item_magazines.pistol1.rounds=7;g.request_reload();g.tick(.2);g.toggle_pause();var elapsed: float=g.item_magazines.pistol0.elapsed;g.tick(1);close(g.item_magazines.pistol0.elapsed,elapsed,"pause freezesdualreload");g.toggle_pause();g.tick(.48);check(g.item_magazines.pistol0.rounds==10 and g.item_magazines.pistol1.rounds==7,"coarse resumereload selected only")
 fresh("pistol0","pistol1");g.request_attack();advance(.1);check(g.request_dodge(Vector3.LEFT),"dash interrupts pair");check(not g.pair_strikes.active,"dash cancelsqueuedhand");check(g.item_magazines.pistol0.rounds==9 and g.item_magazines.pistol1.rounds==10,"dash no phantomammo")
 fresh("pistol0","pistol1");g.request_attack();check(g.request_loadout_swap() and g.pending_set==1,"Q queuesduringpair");advance(.9);check(g.loadout.active==1 and not g.has_dual_weapons(),"Q activates afterpair andremovespenalty");close(g.attack_rate(),1,"twohandfull rate afterQ");check(g.item_magazines.pistol0.rounds==9 and g.item_magazines.pistol1.rounds==9,"Q no refill")
 fresh("pistol0","pistol1");g.item_magazines.pistol1.configure({"magazine_capacity":6,"reload_time":.9});g.request_attack();advance(.8);check(g.item_magazines.pistol0.rounds==9 and g.item_magazines.pistol1.rounds==5,"unequalmagazines independent");g.request_reload();advance(.91);check(g.item_magazines.pistol1.reloading,"custom .9reload uses75percent");advance(.3);check(g.item_magazines.pistol1.rounds==6 and g.item_magazines.pistol0.rounds==9,"customreload fills owncapacity only")

func dispersion_cases() -> void:
 for dual in [false,true]:
  for aimed in [false,true]:
   for seed_value in [151,5271,999]:
    fresh("pistol0","pistol1" if dual else "");right(aimed);advance(.25)
    var rng:=RandomNumberGenerator.new();rng.seed=seed_value;g.shot_rng.seed=seed_value
    var expected: float=rng.randf_range(-1,1)*deg_to_rad(2.5 if aimed else 8)/( .75 if dual else 1)
    g.request_attack();right(not aimed);advance(.1)
    check(not g.staff_flight.active.is_empty(),"snapshot actualbullet exists")
    if not g.staff_flight.active.is_empty():
     var direction: Vector3=g.staff_flight.active[0].direction
     close(atan2(direction.z,direction.x),expected,"actualdispersion stayscommitted acrossRMB toggle")
