extends SceneTree
var game
var checks:=0
var failures: Array[String]=[]
var total_burn:=.0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
 checks+=1
 if not ok:failures.append(why);printerr("FAIL: ",why)
func close(a: float,b: float,why: String) -> void:check(absf(a-b)<.001,why+" got="+str(a)+" expected="+str(b))
func step(t: float) -> void:
 await physics_frame;game.tick(t)
func fresh():
 game.start_run(true);game.clear_actors();game.stats.reset_modifiers();game.stats.flat.critical_chance=-.05;game.set_weapon_family("staff");game.test_aim=Vector3.RIGHT;game._refresh_aim();game._visual_tick(0)
 var enemy=game.spawn_enemy("dummy",Vector3(3,.03,0));enemy.max_health=1000;enemy.health=1000;return enemy
func load_units(count: int) -> void:
 check(game.begin_staff_load(),"RMB preparation starts")
 await step(count*.45+.000001);game.staff_energy.stop_load()
 close(game.staff_energy.units,count,"prepared requested units")
func finish() -> void:
 for i in range(300):
  if not game.motion.busy and game.staff_flight.active.is_empty():return
  await step(1.0/120)
 check(false,"cast/projectile complete")
func cast(hold: float) -> void:
 check(game.begin_staff_cast(),"LMB begins concentration")
 if hold>0:await step(hold)
 check(game.release_staff_cast(),"LMB release commits")
 await finish()
func run() -> void:
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 var enemy=fresh()
 check(not game.begin_staff_cast() and not game.motion.busy,"uncharged LMB cannot shoot")
 check(game.begin_staff_load(),"begin empty fill");await step(.44)
 close(game.staff_energy.units,0,"partial fill doesnot grant ammo");close(game.stamina,100,"partial fill doesnot pay yet")
 await step(.01);close(game.staff_energy.units,1,"first unit at.45");close(game.stamina,86,"14 per prepared unit")
 await step(.9);close(game.staff_energy.units,3,"full3reserve");close(game.stamina,58,"full reserve costs42 once")
 check(not game.staff_energy.loading,"full stops fill")
 await step(.1);close(game.staff_energy.units,3,"held full cannot overflow")
 check(not game.ui.charge_panel.visible and not ("3/3" in game.ui.stage_text.text),"no numeric staff charge gauge")
 var energy: float=game.stamina
 check(game.begin_staff_cast(),"ready cast")
 await step(.399);close(game.staff_energy.level(),1,"level1before.4")
 await step(.001);close(game.staff_energy.level(),2,"level2at.4")
 await step(.5);close(game.staff_energy.level(),3,"level3at.9")
 close(game.staff_energy.units,3,"concentration doesnot consume early");close(game.stamina,energy,"no second stamina charge")
 check(game.release_staff_cast(),"release full")
 close(game.staff_energy.units,0,"fullcast consumes3")
 close(game.motion.definition(0).damage,66,"fullimpact66")
 check(game.motion.definition(0).ground_fire,"only full marks ground")
 await finish();close(game.staff_flight.shots_fired,1,"one release one projectile")
 close(game.total_damage-game.ground_fire.pulses*2,66,"directhit66 with existingburn accounted once")
 check(game.ground_fire.zones.size()==1,"fullactual projectile creates groundpatch")
 await step(5);check(game.ground_fire.zones.is_empty(),"real patch expires")
 # 2 ammo caps casting at2 and can alternatively feed two singles.
 enemy=fresh();await load_units(2);energy=game.stamina
 check(game.begin_staff_cast(),"two reserve concentration");await step(2)
 close(game.staff_energy.level(),2,"cannot cast3with2ammo");game.release_staff_cast();await finish()
 close(game.total_damage,44,"tier2actual44");check(game.ground_fire.zones.is_empty(),"tier2no groundfire")
 close(game.staff_energy.units,0,"tier2uses2")
 enemy=fresh();await load_units(2);await cast(0)
 close(game.total_damage,20,"tier1actual20");close(game.staff_energy.units,1,"single leaves1")
 await cast(0);close(game.total_damage,40,"two singles total40");close(game.staff_energy.units,0,"second single empty")
 check(not game.begin_staff_cast(),"no free thirdshot")
 # Pool2+1, weapon ownership, speed modifiers, pause/focus/dash.
 enemy=fresh();await load_units(3);await cast(.4);close(game.staff_energy.units,1,"3reserve two leaves1")
 await cast(0);close(game.total_damage,64,"2plus1 direct64")
 enemy=fresh();game.stamina=13;check(game.begin_staff_load(),"attemptlowenergy");await step(.46)
 close(game.staff_energy.units,0,"no ammo withoutenergy");close(game.stamina,13,"no negative energy")
 enemy=fresh();game.stats.flat.attack_speed=1;game.begin_staff_load();await step(.225001);game.staff_energy.stop_load();close(game.staff_energy.units,1,"attack_speed scalesbasefill")
 game.begin_staff_cast();await step(.200001);close(game.staff_energy.level(),1,"ammo cap despitefastcast");game.staff_energy.cancel_actions()
 enemy=fresh();await load_units(3);check(game.begin_staff_cast(),"cancelchargefixture");await step(.5)
 check(game.request_dodge(Vector3.LEFT),"dash overrides castchannel");close(game.staff_energy.units,3,"uncommitted concentration retainsammo");check(not game.staff_energy.casting,"dash cancelschannel")
 await step(.6);check(not game.motion.busy and game.staff_flight.shots_fired==0,"cancel emitsnothing")
 game.stamina=100;game.begin_staff_cast();game.release_staff_cast();check(game.request_dodge(Vector3.LEFT),"dash overrides committedwindup")
 close(game.staff_energy.units,2,"committed ammo notrefunded");await step(.6);close(game.staff_flight.shots_fired,0,"windup cancel no lateprojectile")
 enemy=fresh();await load_units(1);game.begin_staff_cast();game.release_staff_cast();await step(.29)
 check(game.staff_flight.shots_fired==1,"projectile released beforedash");check(game.request_dodge(Vector3.LEFT),"dash afterrelease");await finish();close(game.staff_flight.shots_fired,1,"releasedprojectile survivesdash")
 enemy=fresh();await load_units(2);game.begin_staff_cast();game.toggle_pause();await step(1)
 check(not game.staff_energy.casting and game.staff_energy.units==2,"pause cancelschannel keepsammo");game.toggle_pause()
 game.begin_staff_load();await step(.1);game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
 check(not game.staff_energy.loading and game.staff_energy.units==2,"focus cancelsfraction not completedammo")
 # Independent model binding simulates different item IDs without transferring ammo.
 var model=game.staff_energy;model.bind("staffA");model.units=2;model.bind("staffB");close(model.units,0,"otherstaff starts empty");model.units=1;model.bind("staffA");close(model.units,2,"perstaff pool survives swapping")
 # Standalone ground manager deterministic pulse, overlap and no reaction.
 var field=load("res://scripts/ground_fire.gd").new();root.add_child(field)
 field.damage_hit.connect(func(target,amount):total_burn+=amount;target.receive_burn(amount))
 enemy=fresh();enemy.health=1000;enemy.state="windup";enemy.attack_data=enemy.Attacks.definition("melee",0);enemy.telegraph_left=.4
 field.spawn_patch(enemy.position);field.spawn_patch(enemy.position)
 field.tick(.499,[enemy,enemy]);close(total_burn,0,"burn waits.5")
 field.tick(.001,[enemy,enemy]);close(total_burn,2,"overlap/doublearray burns once")
 check(enemy.state=="windup" and enemy.stagger==0,"burn doesnotinterruptattack")
 field.tick(4.5,[enemy]);close(total_burn,20,"10ticks in5s includingexpiry endpoint");check(field.zones.is_empty(),"expiredfields removed")
 close(enemy.health,980,"twopatches not40damage")
 field.tick(10,[enemy]);close(total_burn,20,"no damage afterexpiry")
 field.spawn_patch(Vector3(9,0,9));field.tick(.5,[enemy]);close(total_burn,20,"outsidecircle no damage")
 field.clear();total_burn=0;enemy.position=Vector3(4,.03,0)
 var wall:=StaticBody3D.new();wall.collision_layer=1
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.2,2,2);shape.shape=box;wall.add_child(shape);wall.position=Vector3(3.5,1,0);root.add_child(wall)
 await physics_frame;await physics_frame
 field.spawn_patch(Vector3(3,.03,0));field.tick(.5,[enemy],game.player.get_world_3d());close(total_burn,0,"cover blocks groundburn through wall")
 wall.queue_free();await physics_frame;await physics_frame
 field.tick(.5,[enemy],game.player.get_world_3d());close(total_burn,2,"uncovered target insidepatch burns")
 field.clear();field.spawn_patch(enemy.position);enemy.health=1;field.tick(.5,[enemy]);check(enemy.dead,"burn cankill")
 field.clear();check(field.zones.is_empty(),"resetclearsfire")
 field.queue_free();game.queue_free();await process_frame
 print("STAFF CHARGE: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
