extends SceneTree
const Rules=preload("res://scripts/weapon_ready.gd")
const Attacks=preload("res://scripts/enemy_attacks.gd")
const STEP:=1.0/120
var game
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,why: String) -> void:
 checks+=1
 if not ok:failures.append(why);printerr("FAIL: ",why)
func rmb(down: bool) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=down;root.push_input(e,true)
func step(count: int=1) -> void:
 for i in range(count):await physics_frame;game.tick(STEP)
func fresh() -> void:
 game.loadout.defaults();game.loadout_edited();game.start_run(true);game.test_aim=Vector3.RIGHT
 for enemy in game.enemies:enemy.position=Vector3(100,0,100)
func waiting(enemy,remaining: float=.10) -> void:
 for i in range(500):
  await step()
  if enemy.state=="windup" and enemy.telegraph_left<=remaining:return
 check(false,"AI reaches windup")
func run() -> void:
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 var normal:=Attacks.definition("melee",0)
 for angle in [0.0,PI*.5,PI,-PI*.5]:
  var direction:=Vector3(cos(angle),0,sin(angle))
  check(Attacks.contains(Vector3.ZERO,angle,direction*(normal.reach-.01),normal),"contact inside footprint")
  check(not Attacks.contains(Vector3.ZERO,angle,direction*(normal.reach+.01),normal),"outside reach misses")
  check(not Attacks.contains(Vector3.ZERO,angle,-direction,normal),"behind locked swing misses")
 for kind in ["melee","ranged","elite"]:
  var has_red:=false;var has_normal:=false
  for i in range(6):
   var d:=Attacks.definition(kind,i);has_red=has_red or not d.parryable;has_normal=has_normal or d.parryable
   check(d.windup>.15 and d.active>0 and d.recovery>0 and d.reach>0,"readable definition")
  check(has_red and has_normal,"both normal/red attacks")
 # Fresh edge/tap and repeat suppression.
 fresh();rmb(true);check(is_equal_approx(game.readiness.parry_left,.15),"fresh press opens150ms")
 await step(10);var left: float=game.readiness.parry_left;rmb(true);check(is_equal_approx(game.readiness.parry_left,left),"duplicate held press does not refresh")
 await step(10);check(game.readiness.parry_left==0 and game.right_action()=="guard","held becomes ordinary guard")
 rmb(false);rmb(true);rmb(false);check(game.readiness.parry_left>0,"tap retains short parry window")
 game.incoming_attack(10,game.player.position+Vector3.RIGHT,true)
 check(game.health==100 and game.stamina>=95 and game.readiness.parries==1,"tap timed parry prevents damage")
 game._iframes=0;game.incoming_attack(10,game.player.position+Vector3.RIGHT,true)
 check(game.readiness.parries==1 and game.health==90,"single edge cannot parry twice after release")
 fresh();rmb(true);game.incoming_attack(20,game.player.position+Vector3.RIGHT,false,null,1.5)
 check(game.readiness.parries==0 and is_equal_approx(game.health,94) and is_equal_approx(game.stamina,73),"red never parries; guard still works at heavier stamina cost")
 fresh();rmb(true);game.incoming_attack(10,game.player.position+Vector3.LEFT,true)
 check(game.health==90 and game.readiness.parries==0,"rear cannot parry")
 fresh();rmb(true);await step(25);game.incoming_attack(10,game.player.position+Vector3.RIGHT,true)
 check(is_equal_approx(game.health,97) and game.readiness.parries==0,"early held press falls back to guard")
 fresh();game.incoming_attack(10,game.player.position+Vector3.RIGHT,true);rmb(true)
 check(game.health==90 and game.readiness.parries==0,"late press cannot undo applied damage")
 fresh();rmb(true);check(game.request_dodge() and game.readiness.parry_left==0,"dodge clears parry window")
 fresh();rmb(true);game.toggle_pause();check(game.readiness.parry_left==0,"pause clears window");game.toggle_pause()
 rmb(true);game.toggle_inventory();check(game.readiness.parry_left==0,"inventory clears window");game.toggle_inventory()
 rmb(true);game.start_run(true);check(game.readiness.parries==0 and game.readiness.parry_left==0,"retry resets parry")
 fresh();rmb(true);rmb(false)
 check(game.readiness.mode("pistol",true,true)=="","released melee tap never becomes gun ADS")
 check(game.activate_loadout(1),"swap weapon set during tap")
 check(game.readiness.parry_left==0 and game.right_action()=="","set swap cannot carry old parry window")
 # Real AI timed impact for both melee archetypes.
 for kind in ["melee","elite"]:
  fresh();var enemy=game.spawn_enemy(kind,game.player.position+Vector3.RIGHT*1.15)
  await waiting(enemy);rmb(true);await step(20)
  check(game.readiness.parries==1 and game.health==100 and enemy.state=="parried" and enemy.stagger>0,"real AI parry and stagger "+kind)
 fresh();game.set_weapon_family("pistol");rmb(true);game.incoming_attack(10,game.player.position+Vector3.RIGHT,true)
 check(game.readiness.parry_left==0 and game.readiness.parries==0 and game.health==90,"gun primary cannot parry")
 fresh();check(game.request_attack(),"start paired attack");rmb(true)
 check(game.readiness.parry_left==0,"press during attack cannot queue a later parry")
 await step(220);check(game.readiness.parry_left==0,"held input never rearms after attack")
 fresh();var block_enemy=game.spawn_enemy("melee",game.player.position+Vector3.RIGHT*1.15)
 await step(180);check(game.health==90,"one damage contact per active attack")
 fresh();var wall_enemy=game.spawn_enemy("melee",game.player.position+Vector3.RIGHT*1.15)
 await waiting(wall_enemy,.25)
 var wall:=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.2,2,3);shape.shape=box;wall.add_child(shape);wall.position=Vector3(.6,1,0);root.add_child(wall)
 await step(60);check(game.health==100,"melee footprint cannot hit through cover");wall.queue_free();await step(2)
 # Actual projectile can be parried at arrival and stagger its live owner.
 fresh();var shooter=game.spawn_enemy("ranged",Vector3(100,0,100));game.shoot(game.player.position+Vector3(1,.6,0),Vector3.LEFT,11,true,shooter)
 await step(7);rmb(true);await step(12)
 check(game.readiness.parries==1 and game.health==100 and game.projectiles.is_empty() and shooter.state=="parried","real projectile parry consumes bolt and staggers owner")
 fresh();game.shoot(game.player.position+Vector3(1,.6,0),Vector3.LEFT,11,true);rmb(true)
 await physics_frame;game.tick(.2)
 check(game.readiness.parries==1 and game.health==100,"coarse projectile contact occurs before window expiry")
 var lane:=Attacks.definition("ranged",0)
 check(Attacks.contains(Vector3.ZERO,0,Vector3(6.39,0,0),lane) and not Attacks.contains(Vector3.ZERO,0,Vector3(6.41,0,0),lane),"lane endcap matches target contact radius")
 # A projectile starts at release, not at the beginning of the windup tick.
 fresh();var ranged=game.spawn_enemy("ranged",game.player.position+Vector3.RIGHT*4)
 for wait in range(200):
  await step()
  if ranged.state=="windup":break
 var until_release: float=ranged.telegraph_left
 await physics_frame;game.tick(until_release)
 check(game.health==100 and game.projectiles.size()==1,"fresh bolt cannot hit instantly at coarse release")
 if game.projectiles.size()==1:check(game.projectiles[0].node.position.distance_to(ranged.position+Vector3.UP*.6)<.001,"new bolt has zero age at release boundary")
 await physics_frame;game.tick(.3);check(game.health==100,"bolt travel consumes future time")
 await physics_frame;game.tick(.5);check(game.health==89,"coarse future travel reaches actual impact")
 # Released projectiles survive their shooter being freed.
 fresh();var departed=game.spawn_enemy("ranged",Vector3(100,0,100))
 game.shoot(game.player.position+Vector3(1.4,.6,0),Vector3.LEFT,11,true,departed)
 game.enemies.erase(departed);departed.queue_free();await process_frame
 await step(12);rmb(true);await step(30)
 check(game.readiness.parries==1 and game.health==100 and game.projectiles.is_empty(),"orphaned live bolt remains parryable after owner freed")
 # Locked swing can be sidestepped; no homing at impact.
 fresh();var enemy=game.spawn_enemy("melee",game.player.position+Vector3.RIGHT*1.15)
 await waiting(enemy,.25);game.player.position=enemy.position+Vector3.FORWARD*1.15;await step(50)
 check(game.health==100,"move out of locked sector avoids damage")
 # One coarse frame spanning contact must preserve the150ms timing window.
 fresh();enemy=game.spawn_enemy("melee",game.player.position+Vector3.RIGHT*1.15)
 await waiting(enemy,.10);rmb(true);await physics_frame;game.tick(.2)
 check(game.readiness.parries==1 and game.health==100,"coarse tick respects chronological parry contact")
 game.start_parry_drill();check(game.drill_kind=="melee" and game.enemies.size()==1,"one-enemy drill")
 game.cycle_drill();check(game.drill_kind=="ranged","cycle drill archetype")
 game.restart();check(game.drill_kind=="ranged" and game.enemies.size()==1,"restart preserves drill")
 game.queue_free();await process_frame
 print("PARRY: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
