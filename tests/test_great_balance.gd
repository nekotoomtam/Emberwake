extends SceneTree
var game
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
 checks+=1
 if not ok:failures.append(why);printerr("FAIL: ",why)
func close(a: float,b: float,why: String) -> void:check(absf(a-b)<.001,why+" got="+str(a)+" expected="+str(b))
func fresh() -> void:
 game.start_run(true);game.clear_actors();game.stats.reset_modifiers();game.stats.flat.critical_chance=-.05;game.set_weapon_family("greatsword");game.test_aim=Vector3.RIGHT;game._refresh_aim()
func mouse(down: bool) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true);Input.flush_buffered_events()
func step(time: float) -> void:
 await physics_frame;game.tick(time)
func finish() -> void:
 for i in range(240):
  if not game.motion.busy:return
  await step(1.0/120)
 check(false,"attack finishes")
func attack(hold: float) -> void:
 mouse(true);await step(hold+.000001);mouse(false);await finish()
func foe(kind: String="melee"):
 var enemy=game.spawn_enemy(kind,game.player.position+Vector3.RIGHT*2.2);enemy.max_health=500;enemy.health=500;return enemy
func parry() -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=true;root.push_input(e,true)
 game.incoming_attack(10,game.player.position+Vector3.RIGHT,true)
 e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=false;root.push_input(e,true)
func run() -> void:
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 for tier in range(1,4):
  fresh();var target=foe("dummy")
  await attack(0)
  await attack([0.0,.41,1.01][tier-1])
  check(game._next_combo==2 and game.motion.great_charge.finisher_valid,"released second earns finisher")
  close(game.motion.great_charge.finisher_level,tier,"correct inherited tier")
  var before: float=game.total_damage;var energy: float=game.stamina
  mouse(true);check(game.motion.stage==2 and not game.motion.is_great_charging(),"third immediate")
  close(game.motion.definition(2).damage,[24.0,36.0,55.0][tier-1],"third has own damage row")
  check(not game.motion.great_charge.finisher_valid,"third consumes earned tier")
  close(game.stamina,energy-20,"third cost remains20")
  mouse(false);await finish()
  close(game.total_damage-before,[24.0,36.0,55.0][tier-1],"actual finisher damage")
  close(target.stagger,[.2,.3,.4][tier-1],"controller supplies total stagger not additive")
 fresh();await attack(0);await attack(1.01);await step(.71)
 check(not game.motion.great_charge.finisher_valid and game._next_combo==0,"timeout clears tier")
 mouse(true);check(game.motion.stage==0,"expired chain cannot use inherited finisher")
 fresh();await attack(0);await attack(1.01);check(game.request_dodge(Vector3.LEFT),"dodge after second")
 check(not game.motion.great_charge.finisher_valid,"dodge clears finisher")
 fresh();await attack(0);await attack(1.01);game.loadout_edited();check(not game.motion.great_charge.finisher_valid,"equipment clears finisher")
 fresh();await attack(0);await step(1.0);parry();mouse(true)
 close(game.motion.definition(2).damage,55,"idle-pose relaxation cannot erase parry full tier")
 check(not game.motion.is_great_charging() and game.motion.great_charge.slam_level==3,"parry third max tier no charge")
 for kind in ["melee","ranged","elite"]:
  for tier in range(1,4):
   fresh();var enemy=foe(kind);enemy.state="windup";enemy.attack_data=enemy.Attacks.definition(kind,0);enemy.telegraph_left=.5
   var duration: float=[.2,.3,.4][tier-1]
   var applied: float=enemy.receive_great_slam(10,Vector3.RIGHT*7,duration)
   var expected: float=duration*(.5 if kind=="elite" else 1)
   close(applied,expected,"normal reaction tier and heavy resistance")
   close(enemy.stagger,expected,"replaces standard0.24 stagger")
   check(enemy.state=="chase" and enemy.attack_data.is_empty(),"normal windup interrupted")
   close(enemy.health,490,"damage once without second armor")
 for kind in ["melee","ranged","elite"]:
  for phase in ["windup","attack"]:
   fresh();var enemy=foe(kind);enemy.state=phase;enemy.attack_data=enemy.Attacks.definition(kind,1 if kind=="elite" else 2);enemy.telegraph_left=.6;enemy.active_left=.1;enemy.attack_hit=false
   var before: Dictionary=enemy.attack_data.duplicate(true)
   close(enemy.receive_great_slam(10,Vector3.RIGHT*7,.4),0,"red receives no stagger")
   check(enemy.state==phase and enemy.attack_data==before,"red committed action remains")
   close(enemy.telegraph_left,.6,"red windup preserved");close(enemy.active_left,.1,"red active clock preserved")
   close(enemy.stagger,0,"red no new stagger");check(enemy.knockback==Vector3.ZERO,"red no new displacement")
   close(enemy.health,490,"red still takes damage")
 fresh();var enemy=foe();enemy.state="windup";enemy.attack_data=enemy.Attacks.definition("melee",2)
 enemy.receive_great_slam(1000,Vector3.RIGHT*7,.4);check(enemy.dead and enemy.state=="dead","lethal damage kills red normally")
 fresh();enemy=foe();enemy.receive_parry();enemy.receive_great_slam(10,Vector3.ZERO,.4)
 close(enemy.stagger,.4,"slam replaces parry1s reaction")
 fresh();enemy=foe();enemy.receive_damage(10,Vector3.RIGHT*7);close(enemy.stagger,.24,"ordinary hit reaction unchanged")
 game.queue_free();await process_frame
 print("GREAT BALANCE: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
