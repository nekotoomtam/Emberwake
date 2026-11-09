extends SceneTree
var game
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
 checks+=1
 if not ok:failures.append(why);printerr("FAIL: ",why)
func fresh(family: String="sword") -> void:
 game.start_run(true);game.clear_actors();game.set_weapon_family(family);game.stats.reset_modifiers();game.stats.flat.critical_chance=-.05;game.test_aim=Vector3.RIGHT;game._refresh_aim()
func press() -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=true;root.push_input(e,true)
func parry() -> void:
 press();game.incoming_attack(10,game.player.position+Vector3.RIGHT,true);game.readiness.release()
func advance(seconds: float) -> void:
 await physics_frame;game.tick(seconds)
func finish() -> void:
 for i in range(300):
  await advance(.01)
  if not game.motion.busy and not game.pair_strikes.active:return
 check(false,"attack finishes")
func run() -> void:
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 for family in ["sword","greatsword","mace"]:
  fresh(family);parry()
  check(game.rewards.counter_left==.7,"counter0.7 grant")
  check(game.request_attack() and game.motion.stage==2,"counter begins third move")
  check(game.rewards.counter_left==0,"counter consumed on accepted start")
  await finish();check(game._next_combo==0,"counter returns first move")
 fresh();parry();await advance(.71);check(game.request_attack() and game.motion.stage==0,"counter expiry")
 fresh();parry();check(game.request_dodge(Vector3.LEFT) and game.rewards.counter_left==0,"dodge cancels counter")
 fresh();parry();game.loadout_edited();check(game.rewards.counter_left==0,"equipment cancels counter")
 fresh();check(game.request_attack() and game.motion.stage==0,"chain first")
 await finish();check(game._next_combo==1,"chain second earned")
 await advance(.6);check(game.request_attack() and game.motion.stage==1,"chain resumes inside0.7")
 await finish();await advance(.71);check(game.request_attack() and game.motion.stage==0,"cannot store finisher indefinitely")
 fresh();game.spawn_enemy("melee",game.player.position+Vector3.RIGHT*1.2);var enemy=game.enemies.back()
 enemy.receive_parry();check(enemy.stagger==1 and enemy.cooldown==1,"one second parry stagger")
 enemy.tick(.9,game);check(enemy.state=="parried","still staggered at0.9")
 enemy.tick(.11,game);check(enemy.state!="parried","recovers at1.0")
 enemy.receive_parry();enemy.receive_damage(0,Vector3.ZERO);check(enemy.state=="parried","zero damage cannot wake")
 enemy.receive_damage(1,Vector3.ZERO);check(enemy.state=="chase" and enemy.stagger<=.24 and enemy.cooldown==.4,"damage breaks parry into normal hit reaction")
 fresh();check(game.request_dodge(Vector3.LEFT),"dodge starts");check(game.stamina==70,"dodge cost30")
 game.damage_player(10);check(game.health==100,"dodge iframe immediate")
 await advance(.14);game.damage_player(10);check(game.health==100,"dodge iframe early")
 await advance(.03);game.damage_player(10);check(game.health==90 and game._dodge_left>0,"dash tail vulnerable")
 fresh();game.request_dodge(Vector3.LEFT);await advance(.02);var before: float=game.stamina
 game.spawn_enemy("melee",game.rewards.dodge_origin+Vector3.RIGHT*1.2);enemy=game.enemies.back()
 enemy.attack_data=enemy.Attacks.definition("melee",0);enemy.attack_angle=PI
 game.check_perfect_evade(enemy);check(is_equal_approx(game.stamina,before+15) and game.rewards.perfects==1,"real footprint refunds15")
 game.check_perfect_evade(enemy);check(is_equal_approx(game.stamina,before+15),"once per dash")
 fresh();game.request_dodge(Vector3.LEFT);await advance(.09);game.spawn_enemy("melee",game.rewards.dodge_origin+Vector3.RIGHT*1.2);enemy=game.enemies.back()
 enemy.attack_data=enemy.Attacks.definition("melee",0);enemy.attack_angle=PI;game.check_perfect_evade(enemy)
 check(game.rewards.perfects==0,"late iframe has no perfect reward")
 fresh();game.request_dodge(Vector3.LEFT);game.spawn_enemy("melee",game.rewards.dodge_origin+Vector3.RIGHT*5);enemy=game.enemies.back()
 enemy.attack_data=enemy.Attacks.definition("melee",0);enemy.attack_angle=PI;game.check_perfect_evade(enemy)
 check(game.rewards.perfects==0,"out of range no reward")
 fresh();game.shoot(game.player.position+Vector3(.5,.6,0),Vector3.LEFT,10,true);game.request_dodge(Vector3.FORWARD)
 await advance(.04);check(game.rewards.perfects==1 and game.health==100,"live bolt crossing dodge origin rewards")
 fresh();press();game.readiness.parry_left=0
 game.incoming_attack(10,game.player.position+Vector3.RIGHT,false)
 game.incoming_attack(10,game.player.position+Vector3.RIGHT,false)
 check(game.readiness.blocks==2 and game.health==86 and game._iframes==0,"guard no free0.5 iframe against separate hits")
 fresh();game.damage_player(10);game.damage_player(10);check(game.health==90,"unguarded hurt immunity retained")
 # Stationary dash fixture isolates contact time at iframe expiry.
 for contact in [.005,.015]:
  fresh();game.request_dodge(Vector3.LEFT);game._dodge_left=0;game.rewards.dodge_age=.15
  game.shoot(game.player.position+Vector3(.4+5.5*contact,.6,0),Vector3.LEFT,10,true)
  await advance(.02)
  check(game.health==(100 if contact<.01 else 90),"projectile contact respects exact iframe boundary")
 game.queue_free();await process_frame
 print("COUNTER DODGE: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)

