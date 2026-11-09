extends SceneTree
const Rules=preload("res://scripts/weapon_ready.gd")
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
func tick(count: int=1) -> void:
 for i in range(count):await physics_frame;game.tick(STEP)
func equip(id: String,hand: String) -> void:
 var source: Dictionary={};var index: int=game.loadout.bag.find(id)
 if index>=0:source={"kind":"bag","index":index}
 else:
  for i in range(2):
   for slot in ["main","off"]:
    if game.loadout.sets[i][slot]==id:source={"kind":"slot","set":i,"hand":slot}
 var target:={"kind":"slot","set":0,"hand":hand}
 if source!=target:check(game.loadout.move_item(source,target),"fixture equipment move")
func fresh(main: String="sword0",off: String="") -> void:
 game.loadout.defaults();game.loadout.unequip({"kind":"slot","set":0,"hand":"off"});equip(main,"main")
 if off!="":equip(off,"off")
 game.loadout_edited();game.start_run(true);game.test_aim=Vector3.RIGHT
 for enemy in game.enemies:enemy.position=Vector3(100,0,100)
func run() -> void:
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 for family in ["pistol","rifle"]:
  var max_hip:=.0
  for i in range(101):
   var roll:=float(i)/50-1
   for aimed in [false,true]:
    var direction:=Rules.shot_direction(family,aimed,1.2,roll)
    var error:=absf(wrapf(atan2(direction.z,direction.x)-1.2,-PI,PI))
    check(error<=Rules.spread(family,aimed)+.00001,"cone bounds")
    if not aimed:max_hip=maxf(max_hip,error)
  check(max_hip>Rules.spread(family,true)*8,"hip wider than ADS")
 for family in ["pistol","rifle"]:
  var widest: Array=[.0,.0]
  for aimed in [false,true]:
   for i in range(4):
    fresh(family+"0");game.shot_rng.seed=123+i;rmb(aimed);await tick();check(game.request_attack(),"real projectile starts")
    for wait in range(100):
     await tick()
     if game.staff_flight.shots_fired>0:break
    check(game.staff_flight.active.size()>0,"actual live bullet")
    if game.staff_flight.active.size()>0:
     var bullet: Dictionary=game.staff_flight.active.back()
     var error: float=absf(atan2(bullet.direction.z,bullet.direction.x))
     check(error<=Rules.spread(family,aimed)+.00001,"released direction obeys RMB spread")
     widest[1 if aimed else 0]=maxf(widest[1 if aimed else 0],error)
  check(widest[0]>widest[1]*8,"controller hip dispersion wider than ADS")
 for family in ["sword","greatsword","mace","staff","pistol","rifle"]:
  fresh(family+"0");rmb(true);await tick()
  check(game.right_action()==("aim" if family in Rules.GUNS else ("guard" if family in Rules.MELEE else "")),"weapon-specific RMB "+family)
  rmb(false);await tick(20);check(game.right_action()=="","release clears stance after short tap/parry window")
 for setup in [["sword0","pistol0","guard"],["pistol0","sword0","aim"],["mace0","pistol0","guard"],["pistol0","mace0","aim"],["pistol0","pistol1","aim"]]:
  fresh(setup[0],setup[1]);rmb(true);await tick();check(game.right_action()==setup[2],"main slot governs mixed pair")
  if setup[2]=="aim":
   check(game.request_attack() and game.active_item==setup[0],"main attacks first")
   var saw_off:=false
   for i in range(220):
    await tick()
    if game.active_item==setup[1] and game.motion.busy:saw_off=true;check(game.right_action()=="aim","main aim survives offhand attack");break
   check(saw_off,"then other hand acts")
 fresh();rmb(true);await tick();game._iframes=0;game.damage_player(20,game.player.position+Vector3.RIGHT)
 check(is_equal_approx(game.health,94) and is_equal_approx(game.stamina,82) and game.readiness.blocks==1,"frontal guard damage/stamina")
 game._iframes=0;game.damage_player(20,game.player.position+Vector3.LEFT);check(is_equal_approx(game.health,74),"rear bypasses guard")
 game._iframes=0;game.damage_player(20);check(is_equal_approx(game.health,54),"unknown nondirectional damage bypasses guard")
 check(not game.request_attack() and not game.request_skill(),"guard prevents attack/skill")
 game._iframes=0;game.stamina=8;game.damage_player(20,game.player.position+Vector3.RIGHT)
 check(game.readiness.broken_left>0 and is_zero_approx(game.stamina) and is_equal_approx(game.health,34),"stamina exhaustion breaks guard and hit passes")
 check(not game.request_attack(),"break recovery blocks attack")
 await tick(85);check(game.readiness.broken_left<=0,"guard recovers")
 fresh();check(game.readiness.blocks==0 and game.readiness.breaks==0 and game.readiness.broken_left==0 and not game.readiness.held,"new run resets readiness state");rmb(true);await tick();check(game.request_dodge(Vector3.LEFT) and not game.readiness.held and game.right_action()=="","dash supersedes guard")
 fresh("pistol0");rmb(true);await tick();check(game.request_dodge(Vector3.LEFT) and game.right_action()=="","dash supersedes ADS")
 fresh("pistol0");rmb(true);await tick();game.item_magazines.pistol0.rounds=8;check(game.request_reload(),"reload while aim allowed");await tick();check(game.right_action()=="","reload suppresses ADS")
 fresh();rmb(true);await tick();game.toggle_pause();check(not game.readiness.held and game.right_action()=="","pause clears RMB")
 game.toggle_pause();rmb(true);await tick();game.toggle_inventory();check(not game.readiness.held and game.right_action()=="","inventory clears RMB");game.toggle_inventory()
 rmb(true);game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT);check(not game.readiness.held,"focus loss clears RMB")
 # Close cover must match the real launch-safety segment, even when grip passes it.
 fresh("pistol0");rmb(true);await tick()
 var wall:=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.06,2,2);shape.shape=box;wall.add_child(shape)
 wall.position=Vector3(.38,1,0);root.add_child(wall);await tick(2)
 check(game.request_attack(),"close-cover shot starts")
 for wait in range(30):
  await tick()
  if game.staff_flight.shots_fired>0:break
 check(game.staff_flight.shots_fired==1 and game.ready_visual.center_end.x<.36,"beam respects wall between player and projected grip")
 var inside:=Vector3(.38,.8,0)
 await physics_frame
 check(game.ready_visual.clipped(game,inside,inside+Vector3.RIGHT*3).distance_to(inside)<.001,"beam ray starting inside cover stops immediately")
 wall.queue_free();await tick(2)
 # Real hostile projectile direction reaches the same frontal/rear guard path.
 for direction in [Vector3.LEFT,Vector3.RIGHT]:
  fresh();rmb(true);await tick();game.shoot(game.player.position-direction*1.4+Vector3.UP*.6,direction,20)
  await tick(45)
  check(is_equal_approx(game.health,94 if direction==Vector3.LEFT else 80),"hostile projectile directional guard")
 # An ordinary AI melee attacker reaches a guarded impact without injected damage.
 fresh();rmb(true);await tick();game.spawn_enemy("melee",game.player.position+Vector3.RIGHT*1.1)
 await tick(180);check(game.readiness.blocks>=1 and game.health<100 and game.health>=94,"real melee AI guarded impact: hp="+str(game.health)+" blocks="+str(game.readiness.blocks))
 game.queue_free();await process_frame
 print("WEAPON READY: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
