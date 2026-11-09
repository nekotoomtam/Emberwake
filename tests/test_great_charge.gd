extends SceneTree
const Motion=preload("res://scripts/weapon_motion.gd")
var game
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
 checks+=1
 if not ok:failures.append(why);printerr("FAIL: ",why)
func close(a: float,b: float,why: String) -> void:check(absf(a-b)<.001,why+" got="+str(a)+" expected="+str(b))
func fresh(family: String="greatsword") -> void:
 game.start_run(true);game.clear_actors();game.stats.reset_modifiers();game.stats.flat.critical_chance=-.05;game.set_weapon_family(family);game.test_aim=Vector3.RIGHT;game._refresh_aim()
func mouse(down: bool) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true);Input.flush_buffered_events()
func rmb(down: bool) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=down;root.push_input(e,true);Input.flush_buffered_events()
func step(time: float) -> void:
 await physics_frame;game.tick(time)
func finish() -> void:
 for i in range(240):
  if not game.motion.busy:return
  await step(1.0/120)
 check(false,"released attack finishes")
func run() -> void:
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 for stage in [0,1]:
  for entry in [[0.0,1],[.41,2],[1.01,3]]:
   var motion=Motion.new();motion.set_family("greatsword");check(motion.start(stage,0),"charge starts")
   var before: Dictionary=motion.advance(entry[0]);check(not before.active and not before.damage_ready,"hold has no hit")
   check(motion.great_charge.level()==entry[1],"gauge threshold")
   check(motion.release_great_charge(),"release accepted once")
   check(not motion.release_great_charge(),"release cannot duplicate attack")
   var spec: Dictionary=motion.definition(stage);var base: Dictionary=Motion.GREAT_ATTACKS[stage]
   close(spec.arc,float(base.arc)*entry[1]/3.0,"exact old-area fraction")
   close(spec.reach,base.reach,"blade reach unchanged")
   close(spec.damage,([18.0,20.0][stage] if entry[1]==1 else ([27.0,30.0][stage] if entry[1]==2 else [42.0,46.0][stage])),"tier damage")
   var half: float=spec.arc*.5
   check(motion.is_target_hit(Vector3.ZERO,Vector3.RIGHT*2,0,-half,half),"central target")
   check(motion.is_target_hit(Vector3.ZERO,Vector3(cos(deg_to_rad(30.0)),0,sin(deg_to_rad(30.0)))*2,0,-half,half)==(entry[1]>=2),"mid angular target")
   check(motion.is_target_hit(Vector3.ZERO,Vector3(cos(deg_to_rad(55.0)),0,sin(deg_to_rad(55.0)))*2,0,-half,half)==(entry[1]==3),"wide angular target")
   fresh();game._next_combo=stage;game.rewards.combo_left=.7
   game.spawn_enemy("dummy",game.player.position+Vector3.RIGHT*2.2);var enemy=game.enemies.back();enemy.max_health=1000;enemy.health=1000
   mouse(true);check(game.motion.is_great_charging(),"actual LMB begins hold")
   close(game.stamina,86,"charge costs14 once")
   await step(entry[0]+.000001);check(game.hits==0,"real monster no premature hit")
   close(game.stamina,86,"no hold regen or extra cost")
   check(game.ui.charge_panel.visible,"gauge visible")
   mouse(false);await finish()
   close(game.total_damage,spec.damage,"real damage matches tier")
   check(game.hits==1,"one hit per target")
   close(game.stamina,86,"no release charge")
   check(game._next_combo==(stage+1)%3,"combo advances after recovery")
 fresh();mouse(true);await step(1.2);check(game.motion.is_great_charging() and game.motion.great_charge.level()==3,"full gauge waits for release")
 close(game.stamina,86,"overhold costs no more");mouse(false);await finish();await step(.8);check(not game.motion.busy and not game._held,"no greatsword auto repeat")
 fresh();mouse(true);game.test_aim=Vector3.LEFT;await step(.05);check(game.aim.x<-.99,"aim can steer while holding")
 var angle: float=game.motion.aim_angle;mouse(false);game.test_aim=Vector3.RIGHT;await step(.02);close(game.motion.aim_angle,angle,"release commits swing aim")
 fresh();mouse(true);game.move_input=Vector2.RIGHT;await step(.05);close(Vector2(game.player.velocity.x,game.player.velocity.z).length(),4.7*.55,"charge slow walk");game.move_input=Vector2.ZERO
 fresh();mouse(true);await step(.21);check(game.request_dodge(Vector3.LEFT),"dodge supersedes charge")
 close(game.stamina,56,"charge14 plus dodge30");check(not game.motion.is_great_charging(),"charge canceled")
 mouse(false);await step(.7);check(game.hits==0 and not game.motion.busy,"release after canceled charge cannot attack")
 fresh();game.stamina=40;mouse(true);check(not game.request_dodge(Vector3.LEFT) and game.motion.is_great_charging(),"unaffordable dodge does not erase paid charge")
 fresh();mouse(true);game.toggle_pause();check(game.mode=="paused" and not game.motion.busy,"pause cancels charge safely")
 mouse(false);game.toggle_pause();await step(.6);check(not game.motion.busy,"no release queued through pause")
 fresh();mouse(true);game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT);check(not game.motion.busy,"focus loss cancels charge")
 fresh();mouse(true);game.toggle_inventory();mouse(false);check(not game.motion.busy and game.inventory_open,"inventory cancels charge")
 game.toggle_inventory()
 fresh();game.stamina=13;mouse(true);check(not game.motion.busy,"insufficient stamina refuses hold")
 fresh();game.stats.flat.attack_speed=1;mouse(true);await step(.51);check(game.motion.great_charge.level()==3,"attack speed scales charge base time")
 fresh();game._next_combo=2;game.rewards.combo_left=.7;mouse(true)
 check(game.motion.stage==2 and not game.motion.is_great_charging(),"third move never charges")
 close(game.motion.definition(2).damage,24,"third defaults to first tier without earned second");close(game.stamina,80,"third cost20")
 mouse(false);await finish();check(game._next_combo==0,"third closes combo")
 fresh();rmb(true);game.incoming_attack(10,game.player.position+Vector3.RIGHT,true);rmb(false);mouse(true)
 check(game.motion.stage==2 and not game.motion.is_great_charging(),"parry counter immediately uses unchanged third")
 close(game.stamina,76,"parry4 plus third20")
 fresh("sword");mouse(true);await step(.9);mouse(false);check(not game.motion.is_great_charging() and game.motion.stage>=1,"ordinary sword retains hold auto-combo")
 game.queue_free();await process_frame
 print("GREAT CHARGE: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)

