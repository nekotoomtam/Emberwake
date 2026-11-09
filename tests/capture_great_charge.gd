extends SceneTree
const STEP:=1.0/120
var game
var output:=""
var safe:=false
var failures: Array[String]=[]
var cases: Array[Dictionary]=[]
var frames: Array[Dictionary]=[]
var name:=""
func _initialize() -> void:
 root.unfocusable=true;Engine.physics_ticks_per_second=120
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func _process(_delta: float) -> bool:
 if safe and (not root.unfocusable or DisplayServer.window_get_position()!=Vector2i(20000,20000)):quit(1)
 return false
func check(ok: bool,why: String) -> void:
 if not ok:failures.append(name+": "+why);printerr("FAIL: ",name+": "+why)
func aim(direction: Vector3) -> void:
 var e:=InputEventMouseMotion.new();e.position=game.camera.unproject_position(game.player.position+direction*5);root.push_input(e,true)
func advance(count: int=1,direction: Vector3=Vector3.RIGHT) -> void:
 for i in range(count):
  await physics_frame;aim(direction);game.tick(STEP)
func mouse(down: bool) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=game._mouse_position;root.push_input(e,true);Input.flush_buffered_events()
func right(down: bool) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=down;e.position=game._mouse_position;root.push_input(e,true);Input.flush_buffered_events()
func shot(mark: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 var enemies: Array=[]
 for enemy in game.enemies:
  if is_instance_valid(enemy):enemies.append({"kind":enemy.kind,"health":enemy.health,"state":enemy.state,"stagger":enemy.stagger,"active":enemy.active_left,"windup":enemy.telegraph_left,"attack_hit":enemy.attack_hit})
 var file:=name+"-"+mark+".png";root.get_texture().get_image().save_png(output.path_join(file))
 frames.append({"case":name,"mark":mark,"file":file,"stage":game.motion.stage,"charging":game.motion.is_great_charging(),"tier":game.motion.great_charge.level(),"stamina":game.stamina,"hits":game.hits,"damage":game.total_damage,"gauge":game.ui.charge_panel.visible,"enemies":enemies})
func fixture(kind: String="dummy") -> void:
 game.loadout.defaults()
 check(game.loadout.move_item({"kind":"slot","set":1,"hand":"main"},{"kind":"slot","set":0,"hand":"main"}),"equip greatsword fixture")
 game.loadout_edited();game.start_run(true);game.clear_actors();game.player.position=Vector3.ZERO
 game.stats.reset_modifiers();game.stats.flat.critical_chance=-.05
 var enemy=game.spawn_enemy(kind,Vector3(1.2 if kind=="melee" else 2.2,.03,0));enemy.max_health=1000;enemy.health=1000
 game.fx.clear_transients();await advance(30)
func finish() -> void:
 for i in range(240):
  if not game.motion.busy:return
  await advance()
 check(false,"finish within2s")
func warmup(ticks: int=1) -> void:
 mouse(true);await advance(ticks);mouse(false);await finish();await advance(2)
func tier_case(stage: int,tier: int,ticks: int) -> void:
 name="stage%d-tier%d"%[stage+1,tier];await fixture()
 for i in range(stage):await warmup()
 var before: float=game.total_damage;var stamina: float=game.stamina;var start: Vector3=game.player.position
 mouse(true);await advance(ticks)
 check(game.motion.is_great_charging() and game.motion.stage==stage,"actual LMB charges intended combo")
 check(game.motion.great_charge.level()==tier and game.ui.charge_panel.visible,"correct gauge tier")
 check(game.total_damage==before and absf(game.stamina-(stamina-14))<.01,"no premature hit/extra cost")
 check(Vector2(game.player.position.x-start.x,game.player.position.z-start.z).length()<.01,"no assisted lunge while charging")
 await shot("gauge");mouse(false)
 var contact:=false
 for i in range(40):
  if stage==0:await shot("frame-%02d"%i)
  await advance(2)
  if not contact and game.total_damage>before:contact=true;await shot("hit")
 var expected: float=([18.0,27.0,42.0][tier-1] if stage==0 else [20.0,30.0,46.0][tier-1])
 check(absf(game.total_damage-before-expected)<.01,"real monster tier damage")
 check(not game.motion.busy and not game.ui.charge_panel.visible,"release completes and hides gauge")
 await shot("end");cases.append({"case":name,"damage":game.total_damage-before,"tier":tier,"stage":stage+1})
func third_case(tier: int,ticks: int) -> void:
 name="third-tier%d"%tier;await fixture();await warmup();await warmup(ticks);var before: float=game.total_damage;var stamina: float=game.stamina
 mouse(true);check(game.motion.stage==2 and not game.motion.is_great_charging(),"third starts without charging")
 check(absf(game.stamina-(stamina-20))<.01,"third costs20")
 await advance();await shot("start");await advance(130)
 check(not game.motion.busy and not game.motion.is_great_charging() and absf(game.total_damage-before-[24.0,36.0,55.0][tier-1])<.01,"held third slams once without automatic next charge")
 mouse(false);await shot("end");cases.append({"case":name,"damage":game.total_damage-before})
func dodge_case() -> void:
 name="dodge-cancel";await fixture();mouse(true);await advance(30);await shot("hold")
 var e:=InputEventKey.new();e.physical_keycode=KEY_SPACE;e.pressed=true;game.move_input=Vector2.LEFT;root.push_input(e,true)
 e=InputEventKey.new();e.physical_keycode=KEY_SPACE;e.pressed=false;root.push_input(e,true);game.move_input=Vector2.ZERO
 check(game._dodge_left>0 and not game.motion.busy and absf(game.stamina-56)<.01,"actual Space cancels charge with14plus30 cost")
 mouse(false);await advance(100);check(game.hits==0 and not game.motion.busy,"no delayed canceled swing")
 await shot("clear");cases.append({"case":name})
func parry_case() -> void:
 name="parry-third";await fixture("melee");var enemy=game.enemies[0]
 for i in range(500):
  await advance()
  if enemy.state=="windup" and enemy.telegraph_left<=.10:right(true);break
 for i in range(80):
  await advance()
  if game.readiness.parries>0:break
 check(game.readiness.parries==1 and game.health==100,"real AI parried")
 right(false);mouse(true);check(game.motion.stage==2 and not game.motion.is_great_charging(),"parry grants immediate third")
 check(absf(game.stamina-76)<.01,"parry and counter costs")
 mouse(false);await advance();await shot("start");await finish();await shot("end")
 check(absf(game.total_damage-55)<.01,"counter max55 slam damage")
 cases.append({"case":name,"damage":game.total_damage})
func steer_case() -> void:
 name="steer-hold";await fixture();mouse(true);await advance(30,Vector3.BACK)
 check(game.motion.is_great_charging() and game.aim.z>.99,"actual mouse steers charging")
 await shot("gauge");mouse(false);var angle: float=game.motion.aim_angle;await advance(5,Vector3.LEFT)
 check(absf(wrapf(game.motion.aim_angle-angle,-PI,PI))<.01,"released swing stays committed")
 await finish();cases.append({"case":name})
func control_case(kind: String,tier: int,red: bool=false) -> void:
 name="stagger-"+kind+"-tier%d"%tier+("-red" if red else "-normal")
 await fixture();await warmup();await warmup([1,50,122][tier-1]);game.clear_actors()
 var enemy=game.spawn_enemy(kind,game.player.position+Vector3.RIGHT*1.2);enemy.max_health=1000;enemy.health=1000;enemy.cooldown=0;enemy.attack_index=(1 if kind=="elite" else 2) if red else 0
 await advance();check(enemy.state=="windup","real AI preparing normal/red attack")
 var before: float=game.total_damage;mouse(true);await advance();mouse(false)
 for i in range(120):
  await advance()
  if game.total_damage>before:break
 check(absf(game.total_damage-before-[24.0,36.0,55.0][tier-1])<.01,"real controlled target damage")
 if red:
  check(enemy.state=="windup" and enemy.stagger==0 and not enemy.attack_data.get("parryable",true),"red attack survives impact")
  check(enemy.knockback==Vector3.ZERO,"red not displaced")
 else:
  var expected: float=[.2,.3,.4][tier-1]*(.5 if kind=="elite" else 1.0)
  check(enemy.state=="chase" and enemy.stagger<=expected+.001 and enemy.stagger>expected-.03,"normal total stagger with heavy resistance")
 await shot("impact")
 if red:
  for i in range(240):
   await advance()
   if enemy.attack_hit:break
  check(enemy.attack_hit and game.health<100,"red attack actually completes and hits player")
  await shot("attack-continues")
 cases.append({"case":name,"tier":tier,"red":red})
func run() -> void:
 if output=="" or DisplayServer.get_name()=="headless":quit(1);return
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
 DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 for stage in range(2):
  for entry in [[1,1],[2,50],[3,122]]:await tier_case(stage,entry[0],entry[1])
 for entry in [[1,1],[2,50],[3,122]]:await third_case(entry[0],entry[1])
 await dodge_case();await parry_case();await steer_case()
 for tier in [1,2,3]:await control_case("melee",tier)
 await control_case("elite",3);await control_case("melee",3,true);await control_case("elite",3,true)
 var f:=FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"cases":cases,"frames":frames,"failures":failures,"native_no_focus":safe,"physics_hz":120,"clip_fps":60,"input":"actual viewport LMB hold/release, mouse/RMB/Space, real combo warmups and drill AI; equipment and HP/crit fixtures only"},"\t"));f.close()
 game.queue_free();await process_frame
 print("GREAT CHARGE NATIVE: ",cases.size()," cases / ",frames.size()," images; failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
