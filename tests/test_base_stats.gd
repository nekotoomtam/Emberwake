extends SceneTree
var game
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
 checks+=1
 if not ok:failures.append(why);printerr("FAIL: ",why)
func close(a: float,b: float,why: String) -> void:check(absf(a-b)<.001,why+" got="+str(a)+" expected="+str(b))
func fresh(family: String="sword") -> void:
 game.stats.reset_modifiers();game.stats.flat.critical_chance=-.05
 if game.stats_open:game.toggle_stats()
 game.start_run(true);game.clear_actors();game.set_weapon_family(family);game.test_aim=Vector3.RIGHT;game._refresh_aim()
func press(key: Key) -> void:
 var e:=InputEventKey.new();e.physical_keycode=key;e.pressed=true;root.push_input(e,true)
 e=InputEventKey.new();e.physical_keycode=key;e.pressed=false;root.push_input(e,true)
func rmb(down: bool=true) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=down;root.push_input(e,true)
func step(time: float) -> void:
 await physics_frame;game.tick(time)
func finish() -> void:
 for i in range(200):
  if not game.motion.busy and not game.pair_strikes.active:return
  await step(.01)
 check(false,"action finishes")
func equip(id: String,hand: String) -> void:
 var source: Dictionary={};var index: int=game.loadout.bag.find(id)
 if index>=0:source={"kind":"bag","index":index}
 else:
  for i in range(2):
   for h in ["main","off"]:
    if game.loadout.sets[i][h]==id:source={"kind":"slot","set":i,"hand":h}
 var target:={"kind":"slot","set":0,"hand":hand}
 if source!=target:check(game.loadout.move_item(source,target),"equip fixture")
func paired(main: String,off: String) -> void:
 fresh();game.loadout.defaults();game.loadout.unequip({"kind":"slot","set":0,"hand":"off"});equip(main,"main");equip(off,"off");game.loadout_edited()
func run() -> void:
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 check(game.stats.base.max_health==100 and game.stats.base.max_stamina==100,"authored resource")
 close(game.stats.value("stamina_regen"),26,"base regen26")
 var original: Dictionary=game.stats.base.duplicate(true)
 game.stats.flat.stamina_regen=4;game.stats.increased.stamina_regen=.1
 close(game.stats.value("stamina_regen"),33,"flat then increased")
 check(game.stats.base==original,"modifiers preserve authored base")
 game.stats.flat.armor=100;close(game.stats.incoming(100),50,"armor formula")
 game.stats.flat.resist_fire=1;close(game.stats.incoming(100,"fire"),25,"resistance cap75")
 close(game.stats.incoming(100,"ice"),100,"independent elements")
 game.stats.reset_modifiers();close(game.stats.critical_multiplier(.01),1.5,"critical150")
 close(game.stats.critical_multiplier(.5),1,"normal critical roll")
 for family in ["sword","greatsword","mace","staff","pistol","rifle"]:
  for stage in range(3 if family in ["sword","greatsword","mace"] else 1):
   fresh(family);game._next_combo=stage;game.rewards.combo_left=.7
   var cost: float=game.attack_cost(family,stage)
   if family=="staff":
    check(game.begin_staff_load(),"staff preparation starts");await step(.450001);game.staff_energy.stop_load()
    check(game.request_staff_basic(),"staff spends one prepared orb for a basic shot")
   else:check(game.request_attack(),family+" starts")
   close(game.stamina,100-cost,family+" stage"+str(stage)+" pays once")
   if game.motion.is_great_charging():game.release_great_charge()
   await step(.02);close(game.stamina,100-cost,"no regen during attack")
   await finish();close(game.stamina,100-cost,"whole action cost unchanged")
   await step(.2);close(game.stamina,100-cost,"recovery delay")
   await step(.25);close(game.stamina,100-cost+2.6,"26/sec after0.35 delay")
 fresh("pistol");rmb();check(game.right_action()=="aim","ADS fixture");check(game.request_attack(),"aimed pistol")
 close(game.stamina,96.1,"aimed pistol cost3.9");rmb(false)
 check(game._shot_aimed,"aimed accuracy retained after release")
 fresh("rifle");rmb();game.request_attack();close(game.stamina,85,"aimed rifle cost15")
 fresh("pistol");game.request_attack();rmb();check(not game._shot_aimed,"cannot gain free ADS after hip shot starts")
 fresh();game.stamina=7;check(not game.request_attack() and not game.motion.busy,"insufficient basic rejected")
 close(game.stamina,7,"no overspend");check(game.energy.flash>0,"low energy feedback")
 press(KEY_F);press(KEY_E);check(not game.skill_active and not game.request_skill() and not game.request_armor_skill() and not game._begin_skill("twin_cut"),"F/E disabled all paths")
 fresh();game.stamina=50;await step(.5);close(game.stamina,63,"idle regen26")
 fresh();game.stamina=50;rmb();await step(.5);close(game.stamina,56.5,"guard regen13")
 fresh("pistol");game.stamina=50;rmb();await step(.5);close(game.stamina,56.5,"ADS regen13")
 fresh("pistol");game.active_magazine().rounds=0;game.stamina=50;check(game.request_reload(),"reload starts")
 await step(.2);close(game.stamina,52.6,"reload regen13 no cost")
 fresh();game.stamina=0;rmb();game.readiness.parry_left=0
 game.damage_player(100,game.player.position+Vector3.RIGHT)
 close(game.health,30,"free guard30percent reduction at zero energy")
 close(game.stamina,0,"guard free");check(game.readiness.breaks==0,"no guard break")
 fresh();game.stats.flat.armor=100;rmb();game.readiness.parry_left=0
 game.damage_player(100,game.player.position+Vector3.RIGHT);close(game.health,65,"armor then guard multiplicative")
 fresh();game.stats.flat.resist_fire=.5;game.damage_player(20,Vector3.INF,1,"fire");close(game.health,90,"actual fire resistance")
 fresh();game.spawn_enemy("dummy",Vector3(1,0,0));var enemy=game.enemies.back();enemy.max_health=500;enemy.health=500
 game.stats.flat.critical_chance=.95;game.enemy_hit(enemy,20,Vector3.ZERO);close(enemy.health,470,"actual critical damage")
 fresh();game.stats.flat.max_health=50;game.stats.flat.max_stamina=20;game.start_run(true)
 close(game.health,150,"maxHP affects reset");close(game.stamina,120,"maxstamina affects reset")
 game.health=100;game.stats.flat.health_regen=2;await step(.5);close(game.health,101,"HP regen")
 fresh();game.stats.flat.stamina_regen=4;game.stamina=50;rmb();await step(.5);close(game.stamina,57.5,"half regen follows modified base30")
 await paired("sword0","sword1");game.stamina=15;check(not game.request_attack(),"pair requires full16")
 close(game.stamina,15,"pair admission free on refusal")
 game.stamina=46;check(game.request_attack(),"pair admitted");close(game.stamina,38,"first hand only cost8")
 check(game.request_dodge(Vector3.LEFT),"dash cancels before second hand");close(game.stamina,8,"no charge for unstarted offhand")
 await paired("sword0","pistol0");game.stamina=50;game.request_attack();await finish();close(game.stamina,39,"mixed pair8plus3")
 await paired("pistol0","pistol1");game.stamina=50;rmb();check(game.request_attack(),"dual ADS admitted");await finish();close(game.stamina,42.2,"dual ADS costs3.9 each")
 fresh();game.request_dodge(Vector3.LEFT);await step(.5);close(game.stamina,70,"coarse dash cannot recover before0.59")
 await step(.1);close(game.stamina,70.26,"dodge regen starts0.35 after actual end")
 fresh();game.request_attack();var total: float=game.motion.definition(0).windup+game.motion.definition(0).active+game.motion.definition(0).recovery
 await step(total+.5);close(game.stamina,95.9,"coarse attack regen measured from recovery end")
 fresh();game.stats.flat.attack_speed=1;game.request_attack();await step(.05);close(game.motion.elapsed,.1,"attack speed affects animation clock")
 fresh("pistol");game.stats.flat.reload_speed=1;game.active_magazine().rounds=0;game.request_reload();await step(.25);check(game.active_magazine().rounds==10,"reload speed affects reload")
 fresh();game.stats.flat.move_speed=1;game.move_input=Vector2.RIGHT;await step(.01);close(Vector2(game.player.velocity.x,game.player.velocity.z).length(),9.4,"move speed affects actual velocity");game.move_input=Vector2.ZERO
 fresh();game.stats.flat.stamina_cost_multiplier=-.5;game.request_attack();close(game.stamina,96,"cost modifier applies without changing base");close(game.energy.cost("sword",0),8,"authored action cost retained")
 fresh();game.stamina=50;press(KEY_P);check(game.stats_open and game.stats_panel.surface.visible,"stats panel opens")
 check(game.stats_panel.left.text.contains("100") and game.stats_panel.right.text.contains("75%"),"stats values rendered in panel")
 await step(1);close(game.stamina,50,"stats panel pauses")
 press(KEY_ESCAPE);check(not game.stats_open,"stats panel closes")
 game.queue_free();await process_frame
 print("BASE STATS: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
