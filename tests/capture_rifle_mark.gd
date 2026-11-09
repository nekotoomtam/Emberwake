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
func key(code: int) -> void:
 var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=true;root.push_input(e,true)
 e=InputEventKey.new();e.physical_keycode=code;e.pressed=false;root.push_input(e,true)
func equip(id: String,index: int) -> void:
 var at: int=game.loadout.bag.find(id)
 check(at>=0,"fixture item "+id)
 if at>=0:check(game.loadout.move_item({"kind":"bag","index":at},{"kind":"slot","set":index,"hand":"main"}),"equip "+id)
func fixture(distance: float=2.5):
 game.loadout.defaults();equip("rifle0",0);equip("sword0",1);game.loadout_edited();game.start_run(true);game.clear_actors();game.player.position=Vector3.ZERO
 game.stats.reset_modifiers();game.stats.flat.critical_chance=-.05;game.move_input=Vector2.ZERO;game.shot_rng.seed=5271
 var enemy=game.spawn_enemy("dummy",Vector3(distance,.03,0));enemy.max_health=1000;enemy.health=1000
 game.fx.clear_transients();await advance(30);return enemy
func shot(mark: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 var foes: Array=[]
 for enemy in game.enemies:
  if is_instance_valid(enemy):foes.append({"position":str(enemy.position),"health":enemy.health,"mark":enemy.rifle_mark.stacks,"mark_left":enemy.rifle_mark.remaining,"armor_stacks":enemy.mace_armor.stacks,"visible":enemy.visible})
 var mag=game.active_magazine()
 var file:=name+"-"+mark+".png"
 if FileAccess.file_exists(output.path_join(file)):file=name+"-"+mark+"-%d.png"%frames.size()
 root.get_texture().get_image().save_png(output.path_join(file))
 frames.append({"case":name,"mark":mark,"file":file,"damage":game.total_damage,"stamina":game.stamina,"shots":game.staff_flight.shots_fired,"rounds":mag.rounds,"reloading":mag.reloading,"bolt":mag.needs_bolt if mag.has_method("start_bolt") else false,"phase":mag.phase if mag.has_method("start_bolt") else "","icons":game.status_icons.shown,"sight":game.vision.reach(),"cone":rad_to_deg(game.vision.half_angle())*2,"camera_size":game.camera.size,"enemies":foes})
func finish() -> void:
 for i in range(500):
  var mag=game.active_magazine()
  if not game.motion.busy and (not mag.has_method("start_bolt") or not mag.bolt_active) and game.staff_flight.active.is_empty():return
  await advance()
 check(false,"shot completes")
func fire(ads: bool,clip: int=0) -> void:
 right(ads);await advance(2);var energy: float=game.stamina
 mouse(true);mouse(false);check(game.motion.busy,"actual LMBstarts paidshot")
 check(absf(game.stamina-energy+(15 if ads else 10))<.01,"actualshotmodecost")
 for i in range(clip):await shot("frame-%02d"%i);await advance(2)
 await finish()
func hip_case() -> void:
 name="hip-mark";var enemy=await fixture()
 for i in range(4):
  var before: float=game.total_damage;await fire(false,60 if i==0 else 0)
  check(absf(game.total_damage-before-[52.0,57.2,62.4,67.6][i])<.02,"hip actualmarkdamage")
  check(enemy.rifle_mark.stacks==mini(3,i+1),"hip buildsMark")
  await shot("mark%d"%(i+1))
 check(game.active_magazine().rounds==1,"fourshots fourrounds")
 cases.append({"case":name})
func aimed_case() -> void:
 name="ADS-four-targets";await fixture();game.clear_actors();var targets: Array=[]
 for x in [2.5,5.0,7.5,10.0,11.5]:
  var enemy=game.spawn_enemy("dummy",Vector3(x,.03,0));enemy.max_health=1000;enemy.health=1000;targets.append(enemy)
 right(true);await advance(100);await shot("aim")
 await fire(true,60)
 check(absf(game.total_damage-130)<.02,"fourline actual52+39+26+13")
 for i in range(5):check(targets[i].rifle_mark.stacks==(1 if i<4 else 0),"Mark appliedonly actual4hits")
 check(game.staff_flight.resolved.back().reason=="hit_limit","bulletstops4")
 await shot("result");cases.append({"case":name})
func reload_case() -> void:
 name="reload-per-round";await fixture();var mag=game.active_magazine();mag.rounds=0
 key(KEY_R);await advance(77);check(mag.rounds==0,"no partialround")
 await advance(1);check(mag.rounds==1,"firstlivebullet at.65")
 await shot("one");await advance(54);check(mag.rounds==2,"secondlivebullet .45later")
 await shot("two");key(KEY_SPACE);check(not mag.reloading and mag.rounds==2 and mag.needs_bolt,"dash keeps2 but actionopen")
 await advance(70);await shot("interrupted")
 key(KEY_R);await advance(54);await shot("inserting");await advance(240)
 check(mag.rounds==5 and mag.can_fire(),"resume fills remainingwithclose")
 await shot("full");cases.append({"case":name})
func close_queue_case() -> void:
 name="reload-click-close";await fixture();var mag=game.active_magazine();mag.rounds=1
 key(KEY_R);await advance(78);check(mag.rounds==2,"actual oneinsert")
 mouse(true);mouse(false);check(mag.phase=="close" and game.staff_flight.shots_fired==0,"click closesbeforefiring")
 await shot("closing");await advance(23);check(game.staff_flight.shots_fired==0,"no shotduringclose")
 await advance(24);check(game.staff_flight.shots_fired==1,"queuedshot afterclose andwindup")
 await finish();await shot("fired");cases.append({"case":name})
func bolt_swap_case() -> void:
 name="dash-Q-bolt";await fixture();var mag=game.active_magazine()
 right(true);mouse(true);await advance(25);mouse(false)
 check(game.staff_flight.shots_fired==1,"shotreleased beforedash")
 key(KEY_SPACE);await advance(80);check(mag.needs_bolt,"dash cannoterasebolt")
 key(KEY_Q);await advance(2);key(KEY_Q);await advance(2)
 check(game.weapon_family=="rifle" and game.active_magazine()==mag and mag.needs_bolt,"Q preservesweapondebt")
 await shot("returned");mouse(true);mouse(false)
 check(mag.bolt_active and not game.motion.busy,"nextclick startsstandalonebolt")
 await advance(109);check(game.staff_flight.shots_fired==1,"cannotfire beforefullbolt")
 await shot("bolt");await advance(45);await finish();check(game.staff_flight.shots_fired==2,"queuedsecondshot afterbolt")
 await shot("ready");cases.append({"case":name})
func spread_case() -> void:
 name="hip-wide-spread";await fixture(8.8);await shot("fan")
 for i in range(5):await fire(false)
 var maximum:=.0
 for item in game.staff_flight.resolved:maximum=maxf(maximum,absf(atan2(item.direction.z,item.direction.x)))
 check(maximum>deg_to_rad(6) and maximum<=deg_to_rad(12)+.001,"actual hipbullets spreadnotjustUI")
 await shot("outcome");cases.append({"case":name,"max_degrees":rad_to_deg(maximum)})
func icons_case() -> void:
 name="shield-and-Mark";await fixture();equip("mace0",1);key(KEY_Q);await advance(2)
 for i in range(3):
  mouse(true);mouse(false);await finish()
 check(game.enemies[0].mace_armor.stacks==1,"real mace thirdcreatesarmorstack")
 key(KEY_Q);await advance(2);await fire(true);await shot("both")
 check(game.status_icons.shown==2 and not game.ui.mace_status_panel.visible,"twoicons replace longpanel")
 cases.append({"case":name})
func view_case(direction: Vector3,label: String) -> void:
 name="ADS-view-"+label;await fixture();game.clear_actors()
 var enemy=game.spawn_enemy("dummy",direction*8+Vector3.UP*.03);enemy.max_health=1000;enemy.health=1000
 right(true);await advance(120,direction)
 check(game.vision.can_see(enemy.position) and game.vision.reach()==14,"longsightclear")
 check(absf(game.camera.size-13)<.1,"ADSzoom settles")
 await shot("aim");right(false);await advance(90,direction)
 check(absf(game.camera.size-13.5)<.1,"return todefaultcamera")
 cases.append({"case":name})
func run() -> void:
 if output=="" or DisplayServer.get_name()=="headless":quit(1);return
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
 DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 await hip_case();await aimed_case();await reload_case();await close_queue_case();await bolt_swap_case();await spread_case();await icons_case()
 for entry in [[Vector3.RIGHT,"right"],[Vector3.LEFT,"left"],[Vector3.FORWARD,"up"],[Vector3.BACK,"down"]]:await view_case(entry[0],entry[1])
 var f:=FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"cases":cases,"frames":frames,"failures":failures,"native_no_focus":safe,"physics_hz":120,"clip_fps":60,"input":"actual viewport LMB/RMB, R/Q/Space, natural shots and macecombo; equipment/HP/crit/empty-magazine fixtures only"},"\t"));f.close()
 game.queue_free();await process_frame
 print("RIFLE MARK NATIVE: ",cases.size()," cases / ",frames.size()," images; failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
