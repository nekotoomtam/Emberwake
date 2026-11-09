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
func equip(id: String,set_index: int) -> void:
 var index: int=game.loadout.bag.find(id)
 check(index>=0,"available fixture "+id)
 if index>=0:check(game.loadout.move_item({"kind":"bag","index":index},{"kind":"slot","set":set_index,"hand":"main"}),"equip "+id)
func fixture():
 game.loadout.defaults();equip("staff0",0);equip("sword0",1);game.loadout_edited();game.start_run(true);game.clear_actors();game.player.position=Vector3.ZERO
 game.stats.reset_modifiers();game.stats.flat.critical_chance=-.05;game.move_input=Vector2.ZERO
 var enemy=game.spawn_enemy("dummy",Vector3(3.8,.03,0));enemy.max_health=1000;enemy.health=1000
 game.fx.clear_transients();await advance(30);return enemy
func shot(mark: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 var orbs:=0
 for orb in game.staff_orbs.orbs:
  if orb.visible:orbs+=1
 var file:=name+"-"+mark+".png"
 if FileAccess.file_exists(output.path_join(file)):file=name+"-"+mark+"-%d.png"%frames.size()
 root.get_texture().get_image().save_png(output.path_join(file))
 frames.append({"case":name,"mark":mark,"file":file,"units":game.staff_energy.units,"level":game.staff_energy.level(),"loading":game.staff_energy.loading,"casting":game.staff_energy.casting,"orb_nodes":orbs,"stamina":game.stamina,"shots":game.staff_flight.shots_fired,"damage":game.total_damage,"fields":game.ground_fire.zones.size(),"no_meter":not game.ui.charge_panel.visible,"hint":game.ui.stage_text.text})
func fill(count: int) -> void:
 var energy: float=game.stamina
 right(true);await advance(count*54+1);right(false)
 check(game.staff_energy.units==count,"actual RMB fillsreserve")
 check(absf(game.stamina-(energy-count*14))<.01,"only14perammo")
 await shot("reserve%d"%count)
func finish() -> void:
 for i in range(400):
  if not game.motion.busy and game.staff_flight.active.is_empty():return
  await advance()
 check(false,"cast/projectile finishes")
func cast_ticks(ticks: int,tier: int,clip: bool=false) -> void:
 var before: int=game.staff_flight.shots_fired
 var units: int=game.staff_energy.units
 mouse(true);await advance(ticks)
 check(game.staff_energy.casting and game.staff_energy.level()==tier,"actual held LMB correcttier")
 check(game.staff_flight.shots_fired==before,"holding doesnot autofire")
 await shot("gather%d"%tier);mouse(false)
 check(game.motion.busy and game.staff_energy.units==units-tier,"release consumes onlyselected units")
 if clip:
  for i in range(40):await shot("frame-%02d"%i);await advance(2)
 await finish();await shot("released%d"%tier)
 check(game.staff_flight.shots_fired==before+1,"one release one shot")
func split_case() -> void:
 name="split-two";await fixture();await shot("empty")
 mouse(true);await advance(30);mouse(false);check(game.staff_flight.shots_fired==0,"empty LMB cannotshoot")
 await fill(2);await cast_ticks(1,1,true)
 check(absf(game.total_damage-20)<.01 and game.staff_energy.units==1,"first single20 remaining1")
 await cast_ticks(1,1)
 check(absf(game.total_damage-40)<.01 and game.staff_energy.units==0 and game.ground_fire.zones.is_empty(),"two singles40 no ground")
 cases.append({"case":name})
func limited_case() -> void:
 name="limited-two";await fixture();await fill(2);await cast_ticks(180,2)
 check(absf(game.total_damage-44)<.01 and game.ground_fire.zones.is_empty(),"reserve2 caps2 and44 no ground")
 cases.append({"case":name})
func partition_case() -> void:
 name="two-plus-one";await fixture();await fill(3);await cast_ticks(50,2);await cast_ticks(1,1)
 check(absf(game.total_damage-64)<.01 and game.staff_energy.units==0,"two plusone direct64")
 cases.append({"case":name})
func ground_case() -> void:
 name="full-ground";await fixture();await fill(3);await cast_ticks(110,3,true)
 check(game.ground_fire.zones.size()==1,"actual fullshot createsfield")
 await shot("burning");await advance(700)
 check(absf(game.total_damage-86)<.01,"66impact plus10burnpulses of2")
 check(game.ground_fire.zones.is_empty(),"field expires5s");await shot("expired")
 cases.append({"case":name})
func dodge_case() -> void:
 name="dash-cancel";await fixture();await fill(3)
 mouse(true);await advance(55);key(KEY_SPACE);mouse(false)
 check(not game.staff_energy.casting and game._dodge_left>0 and game.staff_energy.units==3,"Space cancels uncommittedchannel keepsammo")
 await advance(90);check(game.staff_flight.shots_fired==0,"no delayed cast")
 await shot("clear");cases.append({"case":name})
func swap_case() -> void:
 name="Q-stored-ammo";await fixture();await fill(2)
 key(KEY_Q);check(game.weapon_family=="sword","actual Q to sword");await advance(10);key(KEY_Q)
 check(game.weapon_family=="staff" and game.staff_energy.units==2,"Q returns preparedammo")
 await shot("returned");await cast_ticks(1,1);check(absf(game.total_damage-20)<.01,"returnedammo usable")
 cases.append({"case":name})
func steering_case() -> void:
 name="move-steer";await fixture();await fill(1)
 var start: Vector3=game.player.position
 mouse(true);game.move_input=Vector2.LEFT;await advance(24,Vector3.BACK);game.move_input=Vector2.ZERO
 check(game.aim.z>.99 and game.player.position.distance_to(start)>.1,"walk and aim duringchannel")
 await shot("channel");mouse(false);var locked: float=game.motion.aim_angle;await advance(10,Vector3.LEFT)
 check(absf(wrapf(game.motion.aim_angle-locked,-PI,PI))<.01,"releasedcast commitsdirection")
 await finish();cases.append({"case":name})
func restart_case() -> void:
 name="restart-field";await fixture();await fill(3);await cast_ticks(110,3)
 check(game.ground_fire.zones.size()==1,"field before restart")
 key(KEY_T);check(game.ground_fire.zones.is_empty() and game.staff_energy.units==0,"real T resetsfireandammo")
 await shot("newrun");cases.append({"case":name})
func run() -> void:
 if output=="" or DisplayServer.get_name()=="headless":quit(1);return
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
 DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 await split_case();await limited_case();await partition_case();await ground_case();await dodge_case();await swap_case();await steering_case();await restart_case()
 var f:=FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"cases":cases,"frames":frames,"failures":failures,"native_no_focus":safe,"physics_hz":120,"clip_fps":60,"input":"actual viewport RMB/LMB hold/release, Q/Space/T, mouse+movement. Only equipment/HP/crit fixtures; no injected ammo/damage."},"\t"));f.close()
 game.queue_free();await process_frame
 print("STAFF CHARGE NATIVE: ",cases.size()," cases / ",frames.size()," images; failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
