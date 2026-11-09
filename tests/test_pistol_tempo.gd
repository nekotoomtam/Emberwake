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
func finish() -> void:
 for i in range(400):
  if not g.motion.busy and not g.pair_strikes.active:return
  advance(1.0/120)
 check(false,"shot finishes")
func run() -> void:
 g=load("res://scenes/game.tscn").instantiate();root.add_child(g);g.set_physics_process(false);g.loadout.save_path=""
 fresh("pistol0");right(true);advance(.125);check(rad_to_deg(g.vision.half_angle())*2>90 and rad_to_deg(g.vision.half_angle())*2<120,"pistol gradual narrower vision");advance(.125);close(rad_to_deg(g.vision.half_angle())*2,90,"pistol full90");close(g.vision.reach(),10,"no sightdistance boost");check(not g.rifle_scope.visible,"no pistol vignette")
 check(g.pistol_aim_state.has_method("speed_bonus"),"pistol tempo implemented")
 if g.pistol_aim_state.has_method("speed_bonus"):
  close(g.pistol_aim_state.speed_bonus(),0,"aim alone no stacks")
  for i in range(7):
   var expected: float=minf(i*.05,.25);check(g.request_attack(),"aimed shot starts");close(g.pistol_aim_state.speed_bonus(),expected,"windup no extra stack");advance(.08);close(g.motion.elapsed,.08*(1+expected),"current shot snapshot no midshot acceleration");close(g.pistol_aim_state.speed_bonus(),minf((i+1)*.05,.25),"actualrelease grants capped5percent");finish()
  close(g.stamina,72.7,"no extra energycost");close(g.reload_rate(),1,"reload unaffected bytempo");right(false);close(g.pistol_aim_state.speed_bonus(),0,"RMBrelease immediately clearsbuff");advance(.001);close(rad_to_deg(g.vision.half_angle())*2,120,"released restoresvision")
  fresh("pistol0");g.request_attack();advance(.08);close(g.pistol_aim_state.speed_bonus(),0,"hipfire no stack");finish();right(true);advance(.25);g.request_attack();right(false);advance(.08);close(g.pistol_aim_state.speed_bonus(),0,"releasebeforemuzzle earns no buff")
  fresh("pistol0","pistol1");right(true);advance(.25);g.request_attack();advance(.1);close(g.pistol_aim_state.speed_bonus(),.05,"dual firsthand givesone");close(g.motion.elapsed,.075,"dual firstshot remains75");finish();close(g.pistol_aim_state.speed_bonus(),.10,"dual secondhand grants second stack");check(g.item_magazines.pistol0.rounds==9 and g.item_magazines.pistol1.rounds==9,"two bullets counted separately")
  g.request_attack();finish();g.request_attack();finish();close(g.pistol_aim_state.speed_bonus(),.25,"dual capped afterfivebullets");check(g.request_attack(),"fulltempo pair starts");advance(.1);close(g.motion.elapsed,.09375,"25percent multipliesdual75");finish()
  check(g.request_reload(),"reload withbuff starts");advance(.7);close(g.pistol_aim_state.speed_bonus(),.25,"heldRMB retainsbuff throughreload");close(g.reload_rate(),.75,"tempo never boostsreload");right(false)
  fresh("pistol0");g.item_magazines.pistol0.rounds=0;right(true);advance(.25);check(not g.request_attack(),"dryfire reloads instead");close(g.pistol_aim_state.speed_bonus(),0,"dryfire nostack")
  fresh("pistol0");right(true);advance(.25);g.request_attack();advance(.08);g.request_dodge(Vector3.LEFT);close(g.pistol_aim_state.speed_bonus(),0,"dash clearsaimbuff");finish()
  fresh("pistol0","sword0");right(true);advance(.25);g.request_attack();finish();close(g.pistol_aim_state.speed_bonus(),.05,"mixed melee offhand adds no stack")
 fresh("rifle0");right(true);advance(.55);check(g.pistol_reticle.visible,"rifle gets cursorbrackets");check(not g.ready_visual.line_visible,"rifle still no ray");close(rad_to_deg(g.vision.half_angle())*2,32,"rifle cone unchanged");g.request_attack();advance(.21);close(g.motion.elapsed,.21,"rifle rate unaffected")
 lifecycle_cases()
 g.queue_free();await process_frame
 print("PISTOL TEMPO: ",count," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)

func set_second_pistol() -> void:
 var index: int=g.loadout.bag.find("pistol1")
 check(g.loadout.move_item({"kind":"bag","index":index},{"kind":"slot","set":1,"hand":"main"}),"secondset fixture")
func lifecycle_cases() -> void:
 fresh("pistol0");right(true);advance(.25);g.request_attack();finish();g.toggle_pause();close(g.pistol_aim_state.speed_bonus(),0,"pause clearsbuff");g.toggle_pause()
 fresh("pistol0");right(true);advance(.25);g.request_attack();finish();g._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT);close(g.pistol_aim_state.speed_bonus(),0,"focusloss clearsbuff")
 fresh("pistol0");set_second_pistol();right(true);advance(.25);g.request_attack();finish();check(g.activate_loadout(1),"pistol to pistol swap");close(g.pistol_aim_state.speed_bonus(),.05,"continuousRMB pistolstance retainsbuff acrosspistols");right(false);close(g.pistol_aim_state.speed_bonus(),0,"releaseafterQ clearsbuff")
 fresh("rifle0");set_second_pistol();right(true);advance(.55);check(g.rifle_scope.visible,"rifle focused beforeQ");check(g.activate_loadout(1),"rifle to pistol swap");check(not g.rifle_scope.visible,"pistol cannot inherit rifle darkframe");close(g.vision.reach(),10,"pistol cannot inherit rifle sightrange");close(g.camera.size,13.5,"pistol cannot inherit rifle camerazoom")
