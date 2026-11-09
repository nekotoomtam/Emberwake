extends SceneTree
const STEP:=1.0/120
var game
var output:=""
var safe:=false
var face:=Vector3.RIGHT
var name:=""
var failures: Array[String]=[]
var frames: Array[Dictionary]=[]
var cases: Array[Dictionary]=[]
var clips: Array[Dictionary]=[]
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
func tick(count: int=1) -> void:
 for i in range(count):
  await physics_frame
  var e:=InputEventMouseMotion.new();e.position=game.camera.unproject_position(game.player.position+face*5);root.push_input(e,true)
  game.tick(STEP)
func rmb(down: bool) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=down;e.position=game.camera.unproject_position(game.player.position+face*4);root.push_input(e,true)
func equip(id: String,hand: String) -> void:
 var source: Dictionary={};var index: int=game.loadout.bag.find(id)
 if index>=0:source={"kind":"bag","index":index}
 else:
  for i in range(2):
   for slot in ["main","off"]:
    if game.loadout.sets[i][slot]==id:source={"kind":"slot","set":i,"hand":slot}
 var target:={"kind":"slot","set":0,"hand":hand}
 if source!=target:check(game.loadout.move_item(source,target),"fixture equipment")
func shot(mark: String) -> Dictionary:
 await process_frame;await RenderingServer.frame_post_draw
 var file:=name+"-"+mark+".png";root.get_texture().get_image().save_png(output.path_join(file))
 var row:={"case":name,"mark":mark,"file":file,"health":game.health,"parries":game.readiness.parries,"clashes":game.fx.clashes.size(),"point":game.fx.last_clash,"counter":game.rewards.counter_left,"stage":game.motion.stage,"perfects":game.rewards.perfects,"stamina":game.stamina,"energy_rate":game.energy.rate}
 frames.append(row);return row
func left_click() -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=game.camera.unproject_position(game.player.position+face*4);root.push_input(e,true)
 e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=false;e.position=game.camera.unproject_position(game.player.position+face*4);root.push_input(e,true)
func fixture(main: String,off: String,kind: String="melee") -> void:
 game.loadout.defaults();game.loadout.unequip({"kind":"slot","set":0,"hand":"off"});equip(main,"main")
 if off!="":equip(off,"off")
 game.loadout_edited();game.start_parry_drill(kind);game.stats.flat.critical_chance=-.05
 var enemy=game.enemies[0];enemy.position=game.player.position+face*(2.0 if kind=="elite" else (4.0 if kind=="ranged" else 1.2));enemy.max_health=500;enemy.health=500
 await tick(24);await process_frame
func obtain_parry() -> void:
 var enemy=game.enemies[0]
 for i in range(400):
  await tick()
  if enemy.state=="windup" and enemy.telegraph_left<=.10:rmb(true);break
 for i in range(60):
  await tick()
  if game.readiness.parries>0:break
 check(game.readiness.parries==1 and game.health==100,"real parry")
 rmb(false)
func counter_case(main: String,off: String,expired: bool=false) -> void:
 name="counter-"+main+"-"+(off if off!="" else "solo")+("-expired" if expired else "");face=Vector3.RIGHT
 await fixture(main,off);await obtain_parry();await shot("parried")
 await tick(88 if expired else 6);left_click()
 check(game.motion.stage==(0 if expired else 2),"third move only within0.7")
 await shot("start")
 var second:=false;var hit:=false;var enemy=game.enemies[0]
 for i in range(180):
  if main=="sword0" and off=="" and not expired and i<90 and i%2==0:clips.append(await shot("attack-frame-%02d"%i))
  await tick()
  if not second and game.pair_strikes.active and game.pair_strikes.cursor==1:
   second=true;check(game.motion.stage==(0 if game.weapon_family in ["pistol","rifle","staff"] else 2),"offhand follows third move or single-shot ranged action");await shot("offhand")
  if not hit and enemy.health<500:
   hit=true;check(enemy.state!="parried","actual hit ends parry stagger");await shot("hit")
  if not game.motion.busy and not game.pair_strikes.active:break
 check(hit,"counter hits actual monster")
 if off!="" and not expired:check(second,"paired counter uses both hands")
 check(game.rewards.counter_left==0,"counter not retained")
 cases.append({"case":name,"health":game.health,"stamina":game.stamina,"energy_rate":game.energy.rate})
func stagger_case() -> void:
 name="stagger-one-second";face=Vector3.RIGHT;await fixture("sword0","");await obtain_parry()
 var enemy=game.enemies[0];await tick(108);check(enemy.state=="parried","enemy stays parried0.9s");await shot("hold")
 await tick(15);check(enemy.state!="parried","enemy resumes after1s");await shot("resume");cases.append({"case":name})
func dodge_case(kind: String,perfect: bool) -> void:
 name="dodge-"+kind+("-perfect" if perfect else "-early");face=Vector3.RIGHT;await fixture("sword0","",kind)
 var enemy=game.enemies[0];var triggered:=false
 for i in range(650):
  await tick()
  if kind=="ranged":
   if game.projectiles.is_empty():continue
   var bolt=game.projectiles[0]
   var until: float=game.Enemy.Attacks.projectile_contact_time(bolt.node.position,bolt.direction,game.player.position)
   if until<=(.05 if perfect else .12):triggered=true;break
  elif enemy.state=="windup" and enemy.telegraph_left<=(.05 if perfect else .12):triggered=true;break
 check(triggered,"real attack approaches")
 # Actual viewport Space with a perpendicular direction selected through movement input.
 game.move_input=Vector2(0,1)
 var e:=InputEventKey.new();e.physical_keycode=KEY_SPACE;e.pressed=true;root.push_input(e,true)
 e=InputEventKey.new();e.physical_keycode=KEY_SPACE;e.pressed=false;root.push_input(e,true)
 game.move_input=Vector2.ZERO
 check(game._dodge_left>0 and game.stamina<71,"actual Space spends30")
 for i in range(24):
  if i%2==0:clips.append(await shot("frame-%02d"%i))
  await tick()
 check(game.rewards.perfects==(1 if perfect else 0),"perfect timing distinguishes early iframe")
 check(game.health==100,"real attack evaded")
 check(game.stamina>84 if perfect else game.stamina<72,"refund15 only for perfect")
 await shot("result");cases.append({"case":name,"perfects":game.rewards.perfects,"stamina":game.stamina,"energy_rate":game.energy.rate,"health":game.health})
func key_press(code: Key) -> void:
 var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=true;root.push_input(e,true)
 e=InputEventKey.new();e.physical_keycode=code;e.pressed=false;root.push_input(e,true)
func energy_case(main: String,off: String="",aimed: bool=false) -> void:
 name="energy-"+main+"-"+(off if off!="" else "solo")+("-ADS" if aimed else "-hip");face=Vector3.RIGHT
 await fixture(main,off)
 game.clear_actors();game.spawn_enemy("dummy",game.player.position+face*3);game.enemies[0].max_health=500;game.enemies[0].health=500
 if aimed:rmb(true)
 var first: float=game.attack_cost(game.loadout.items[main].family,0,aimed)
 var second: float=game.attack_cost(game.loadout.items[off].family,0,aimed) if off!="" else 0.0
 left_click();await tick()
 check(absf(game.stamina-(100-first))<.01,"actual click spends first hand")
 await shot("first")
 var paired:=false
 for i in range(220):
  await tick()
  if game.pair_strikes.active and game.pair_strikes.cursor==1 and not paired:
   paired=true;check(absf(game.stamina-(100-first-second))<.01,"actual offhand cost");await shot("second")
  if not game.motion.busy and not game.pair_strikes.active:break
 check(absf(game.stamina-(100-first-second))<.01,"no regen during whole action")
 check(game.stats.base.stamina_regen==26,"base regen retained")
 await shot("end");rmb(false)
 await tick(60);check(game.stamina>100-first-second,"idle recovers after delay")
 await shot("recover");cases.append({"case":name,"paid":first+second,"stamina_after_rest":game.stamina})
func guard_case() -> void:
 name="guard-free-zero-energy";face=Vector3.RIGHT;await fixture("sword0","");game.stamina=0;rmb(true)
 for i in range(500):
  await tick()
  if game.readiness.blocks>0:break
 check(game.readiness.blocks==1 and game.health==93,"actual guard reduces30percent")
 check(game.readiness.breaks==0,"no guard break at low energy")
 check(game.stamina>0,"guard allows half regen")
 await shot("block");rmb(false);cases.append({"case":name,"health":game.health,"stamina":game.stamina})
func panel_case() -> void:
 name="stats-panel";face=Vector3.RIGHT;await fixture("sword0","");game.clear_actors();game.stats.reset_modifiers()
 key_press(KEY_F);key_press(KEY_E);check(not game.skill_active and game.stamina==100,"actual F/E inactive")
 key_press(KEY_P);check(game.stats_open,"actual P opens stats")
 await shot("open");var before: float=game.run_time;await tick(30);check(game.run_time==before,"stats pauses simulation")
 key_press(KEY_ESCAPE);check(not game.stats_open,"actual ESC closes stats")
 cases.append({"case":name})
func run() -> void:
 if output=="" or DisplayServer.get_name()=="headless":quit(1);return
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
 DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 await panel_case()
 var file:=FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"cases":cases,"frames":frames,"clips":clips,"failures":failures,"native_no_focus":safe,"physics_hz":120,"clip_fps":60,"input":"viewport mouse/RMB/LMB/Space, real drill AI; equipment/HP fixtures only"},"\t"));file.close()
 game.queue_free();await process_frame
 print("COUNTER NATIVE: ",cases.size()," cases / ",frames.size()," images; failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
