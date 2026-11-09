extends SceneTree
var game
var checks:=0
var fails: Array[String]=[]
var impacts: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:fails.append(label);printerr("FAIL: ",label)
func close(a: float,b: float,label: String) -> void:check(absf(a-b)<.001,label+" got="+str(a)+" expected="+str(b))
func step(t: float) -> void:
 await physics_frame;game.tick(t)
func fresh():
 game.start_run(true);game.clear_actors();game.stats.reset_modifiers();game.stats.flat.critical_chance=-.05;game.set_weapon_family("rifle");game.test_aim=Vector3.RIGHT;game._refresh_aim();game._visual_tick(0)
 var enemy=game.spawn_enemy("dummy",Vector3(2.5,.03,0));enemy.max_health=1000;enemy.health=1000;return enemy
func right(down: bool=true) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=down;root.push_input(e,true)
func finish() -> void:
 for i in range(500):
  if not game.motion.busy and not game.active_magazine().bolt_active and game.staff_flight.active.is_empty():return
  await step(1.0/120)
 check(false,"shot finishes")
func fire(ads: bool=false) -> void:
 right(ads);check(game.request_attack(),"shot accepted");await finish()
func run() -> void:
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 var enemy=fresh()
 for ads in [false,true]:
  enemy=fresh();right(ads)
  check(game.request_attack(),"mode snapshot starts")
  var spec: Dictionary=game.motion.definition(0)
  close(spec.windup+spec.active+spec.recovery,1.2 if ads else .9,"actual mode attacktotal")
  close(spec.damage,52,"base52");close(game.stamina,85 if ads else 90,"10or15paidonce")
  right(not ads);await finish()
  close(enemy.rifle_mark.stacks,1,"both modes mark")
  check(game.active_magazine().can_fire(),"normal recovery finishes actual bolt")
  close(game.total_damage,52,"first contact no retroactiveMark")
 enemy=fresh()
 var expected: Array=[52.0,57.2,62.4,67.6]
 for i in range(4):
  var before: float=game.total_damage;await fire(i%2==1)
  close(game.total_damage-before,expected[i],"postcontactstack damage")
  close(enemy.rifle_mark.stacks,mini(3,i+1),"cap3")
 enemy.advance_armor_status(9);check(enemy.rifle_mark.stacks==3,"Mark lasts morethan9")
 enemy.apply_rifle_mark();close(enemy.rifle_mark.remaining,10,"cap hit refresh10")
 enemy.advance_armor_status(10);close(enemy.rifle_mark.multiplier(),1,"expiry removesbonus")
 enemy.apply_rifle_mark();var before: float=game.total_damage;game._projectile_damage(enemy,20,Vector3.ZERO,"physical");close(game.total_damage-before,20,"pistol noMarkbonus")
 enemy.receive_damage(2000,Vector3.ZERO);check(enemy.dead and enemy.rifle_mark.stacks==0,"death clearsMark")
 for ads in [false,true]:
  enemy=fresh();right(ads);game.request_attack();await step(1.2 if ads else .9)
  check(not game.motion.busy and game.active_magazine().can_fire(),"coarse whole shot completes bolt justlike fine steps ADS=%s busy=%s ready=%s elapsed=%.12f"%[str(ads),str(game.motion.busy),str(game.active_magazine().can_fire()),game.motion.elapsed])
  close(game.active_magazine().rounds,4,"coarse one bullet consumed")
 # Mechanical clock: extraction once, canceled motion must repeat full bolt.
 var mag=load("res://scripts/rifle_cycle.gd").new()
 check(mag.consume() and mag.rounds==4 and not mag.can_fire(),"fired round needsbolt")
 mag.start_bolt();mag.tick_bolt(.3);check(mag.events.count("eject")==1,"one spentcaseextraction")
 mag.cancel_bolt();mag.start_bolt();mag.tick_bolt(.65);check(not mag.can_fire(),"interrupt restarts fullbolt")
 mag.tick_bolt(.01);check(mag.can_fire() and mag.events.count("eject")==1,"ready and no duplicatecase")
 mag.reset();mag.configure_shot(true);mag.consume();mag.sync_bolt(.91);check(not mag.can_fire(),"ADSbolt .92")
 mag.sync_bolt(.92);check(mag.can_fire(),"ADSboltfinishes")
 mag.reset();mag.rounds=0;check(mag.start_reload(),"emptyreload starts");close(mag.reload_duration,2.65,"empty total2.65")
 mag.tick(.649);close(mag.rounds,0,"partialround not granted");mag.tick(.001);close(mag.rounds,1,"first completedround at.65")
 mag.cancel_reload();close(mag.rounds,1,"cancel retainscompletedround");check(mag.needs_bolt,"cancelledopen cannotfire")
 mag.start_reload();mag.tick(2.2);check(mag.rounds==5 and mag.can_fire(),"resume fills remaining4 with openclose")
 mag.reset();mag.rounds=2;mag.start_reload();mag.tick(.65);mag.close_reload();mag.tick(.2)
 check(mag.rounds==3 and mag.can_fire(),"stopreload closes and keeps3")
 mag.reset();mag.configure_shot(true);mag.consume();mag.start_reload();mag.close_reload();mag.tick(.4)
 check(not mag.can_fire(),"reloadabort cannot bypass pendingbolt")
 mag.tick(.52);check(mag.can_fire(),"abort close also satisfies mechanicaldebt")
 mag.reset();mag.rounds=1;mag.start_reload();mag.tick(.65)
 var pose: Dictionary=game.RiflePose.reload_pose(mag,0)
 check(pose.progress>=.14 and pose.pitch>.8,"nextinsert keeps rifle raised without restblend snap")
 game.ui.refresh();check(not ("1/3" in game.ui.stage_text.text),"rifle UI has no meleecombo count")
 # Real dash afterrelease remembersbolt; nextclick cannotfireuntil repeating.
 enemy=fresh();right();game.request_attack();await step(.21)
 check(game.staff_flight.shots_fired==1 and game.active_magazine().needs_bolt,"real fired beforedash")
 check(game.request_dodge(Vector3.LEFT),"dash afterrelease")
 await step(.6);check(game.rifle_aiming(),"held right resumes ADSafterdash")
 var count: int=game.staff_flight.shots_fired
 check(not game.request_attack() and game.active_magazine().bolt_active,"nextclick beginsbolt instead ofshoot")
 await step(.91);close(game.staff_flight.shots_fired,count,"no newshot beforebolt")
 await step(.01);close(game.staff_flight.shots_fired,count,"completion frame cannot reuse bolt time forshot")
 await step(.21);close(game.staff_flight.shots_fired,count+1,"queuedshot begins onlyafterready thenwindup")
 # Spread and sight truly differ, shader defaults stay normal.
 enemy=fresh();close(rad_to_deg(game.ReadyRules.spread("rifle",false)),12,"hip spread12")
 close(rad_to_deg(game.ReadyRules.spread("rifle",true)),.5,"ADSspread.5")
 close(game.vision.reach(),10,"normal sight10");close(rad_to_deg(game.vision.half_angle())*2,120,"normalcone120")
 right();await step(.55);close(game.vision.reach(),14,"ADSsight14");close(rad_to_deg(game.vision.half_angle())*2,32,"ADScone32")
 # Actual reload interrupt queue closes before firing and pays onlyatshot.
 enemy=fresh();game.active_magazine().rounds=1;check(game.request_reload(),"real partialreload starts")
 await step(.649);close(game.active_magazine().rounds,1,"real incompleteinsert notgranted")
 await step(.001);close(game.active_magazine().rounds,2,"real firstinsert complete")
 check(not game.request_attack(),"click duringreload queues instead ofinstantshot")
 var energy: float=game.stamina
 await step(.19);close(game.staff_flight.shots_fired,0,"wait forclose")
 await step(.01);close(game.staff_flight.shots_fired,0,"close completion nofreewindup")
 await step(.17);close(game.staff_flight.shots_fired,1,"queued shot after properwindup")
 close(game.stamina,energy-10,"queue pays onlyonce")
 enemy=fresh();game.active_magazine().rounds=0;game.request_reload();await step(.65)
 check(game.request_dodge(Vector3.LEFT),"dash duringinsert")
 close(game.active_magazine().rounds,1,"dash keeps exactly completedone")
 check(game.active_magazine().needs_bolt and not game.active_magazine().reloading,"dash leaves openactionunready")
 # Exact attenuation and4targetcap in actualprojectile manager.
 game.clear_actors();var targets: Array=[]
 for x in [2.0,4.0,6.0,8.0,10.0]:
  var foe=game.spawn_enemy("dummy",Vector3(x,.03,0));foe.health=1000;foe.max_health=1000;targets.append(foe)
 var flight=load("res://scripts/staff_projectiles.gd").new();root.add_child(flight)
 flight.rifle_hit.connect(func(target,amount,_knock):impacts.append(amount);target.health-=amount)
 game.motion.configure_rifle(true);var spec: Dictionary=game.motion.definition(0)
 check(flight.spawn_fireball(Vector3(0,.8,0),Vector3.RIGHT,spec,game.camera),"ADSprojectile accepted")
 flight.tick(1,targets,null,Callable(),game.camera)
 check(impacts.size()==4 and flight.active.is_empty(),"4targets includingfirst cap")
 for i in range(mini(impacts.size(),4)):close(impacts[i],[52,39,26,13][i],"linear25percentfalloff")
 close(targets[4].health,1000,"fifth untouched")
 flight.clear();impacts.clear();game.motion.configure_rifle(false);spec=game.motion.definition(0)
 flight.spawn_fireball(Vector3(0,.8,0),Vector3.RIGHT,spec,game.camera);flight.tick(1,targets,null,Callable(),game.camera)
 check(impacts.size()==1,"hip short exit cannotreach separatedsecond")
 flight.queue_free();game.queue_free();await process_frame
 print("RIFLE MARK: ",checks," checks; ","PASS" if fails.is_empty() else "FAIL",fails);quit(0 if fails.is_empty() else 1)
