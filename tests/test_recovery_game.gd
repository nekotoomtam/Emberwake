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
 g.loadout_edited();g.start_run(true);g.test_aim=Vector3.RIGHT;g.move_input=Vector2.ZERO;g.stats.base.critical_chance=0
 for e in g.enemies:e.position=Vector3(100,0,100)
func advance(t: float) -> void:
 while t>.0000001:
  var dt: float=minf(t,1.0/120);g.tick(dt);t-=dt
func right(on: bool) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=on;root.push_input(e,true)
func run() -> void:
 g=load("res://scenes/game.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.loadout.save_path=""
 check(g.has_method("use_health_flask"),"flask controller absent")
 if not g.has_method("use_health_flask"):g.queue_free();await process_frame;print("RECOVERY GAME: FAIL",failures);quit(1);return
 fresh("pistol0");close(g.anatomy.part_max("head"),50,"head capacity50");close(g.anatomy.part_max("torso"),75,"torso75");close(g.anatomy.part_max("right_arm"),25,"arm25");g.set_body_integrity("right_arm",55);close(g.attack_rate(),.9,"onehand injury90");close(g.reload_rate(),.9,"reload90");close(g.motion.definition(0).damage,18,"damage unchanged")
 fresh("pistol0","pistol1");g.set_body_integrity("right_arm",55);close(g.attack_rate(),.675,"dual injury multiplicative");g.request_attack();advance(.1);close(g.motion.elapsed,.0675,"actual injuredhand timing")
 fresh("rifle0");g.set_body_integrity("right_arm",55);close(g.attack_rate(),.95,"2H one injury5percent");g.set_body_integrity("left_arm",55);close(g.attack_rate(),.9,"2H both injury10percent");g.set_body_integrity("head",55);close(g.vision.reach(),8,"head range80");right(true);advance(.55);close(g.vision.reach(),11.2,"injury scalesADSrange");close(rad_to_deg(g.vision.half_angle())*2,32,"cone unchanged");close(g.stats.value("sense_radius"),5,"sense unchanged")
 fresh("sword0");g.set_body_integrity("left_leg",55);g.set_body_integrity("right_leg",55);g.request_dodge(Vector3.RIGHT);close(g.stamina,62.5,"twoinjuredlegs cost once25percent")
 fresh("sword0");g.set_body_integrity("left_leg",55);g.set_body_integrity("torso",55);g.request_dodge(Vector3.RIGHT);close(g.stamina,55,"leg torso dash45")
 fresh("pistol0");g.set_body_integrity("torso",55);g.request_attack();close(g.stamina,96.4,"torso attackcost20percent")
 fresh("pistol0");g.incoming_attack(10,g.player.position+Vector3.RIGHT,true,null,1,"right_arm");close(g.anatomy.part_hp("right_arm"),23,"bodydamage20percent rawHP");close(g.health,90,"HPdamageindependent")
 fresh("pistol0");g.health=10;var e:=InputEventKey.new();e.physical_keycode=KEY_F;e.pressed=true;root.push_input(e,true);close(g.health,35,"actualF instant25");check(g.flasks.charges==2,"onecharge");advance(1);close(g.health,40,"one second5");advance(4);close(g.health,60,"total50 over5");close(g.anatomy.integrity.right_upper_arm,100,"potion not bodyheal")
 g.health=100;check(not g.use_health_flask() and g.flasks.charges==2,"fullhealth no waste")
 g.health=10;g.use_health_flask();g.toggle_pause();advance(2);close(g.health,35,"pausedHoT frozen");g.toggle_pause();advance(1);close(g.health,40,"resumeHoT");g.toggle_body_lab();advance(2);close(g.health,40,"labHoT frozen");g.toggle_body_lab()
 g.start_run(true);check(g.flasks.charges==3 and g.flasks.effects.is_empty(),"newrun resets3");g.set_debug_health_zero();check(g.use_health_flask(),"critical can drink");close(g.health,25,"critical recovery instant");check(g.use_health_flask(),"second dose");close(g.flasks.rate(),10,"streams stack");advance(2);close(g.health,70,"overlap healing exact")
 fresh("pistol0");g.remove_body_part("right_arm");g.health=20;check(g.use_health_flask(),"remainingbody drinks");close(g.health,45,"instant afterlimbloss");advance(5);close(g.health,70,"heals cap90 notpart");check(not g.anatomy.present("right_arm"),"never regrowsarm")
 fresh("pistol0");g.set_body_integrity("head",0);check(not g.use_health_flask(),"cannot revive deadhead")
 fresh("pistol0");g.remove_body_part("left_leg");g.remove_body_part("right_leg");g.health=10;g.move_input=Vector2.RIGHT;check(not g.use_health_flask(),"movingcrawl no drink");g.move_input=Vector2.ZERO;advance(.26);check(g.use_health_flask(),"stationarycrawl can drink")
 fresh("pistol0");g.stats.base.max_health=200;g.remove_body_part("left_arm");close(g.max_health(),180,"200 preloss scalarcap180");close(g.anatomy.part_max("right_arm"),50,"part capacity from200 not180");close(g.anatomy.part_max("head"),100,"head100 atbase200");g.health=175;g.use_health_flask();close(g.health,180,"potion clamps adjustedcap");g.stats.base.max_health=100
 g.queue_free();await process_frame
 print("RECOVERY GAME: ",count," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
