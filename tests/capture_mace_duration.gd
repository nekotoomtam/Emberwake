extends SceneTree
const STEP:=1.0/120
var game
var output:=""
var safe:=false
var failures: Array[String]=[]
var cases: Array[Dictionary]=[]
var frames: Array[Dictionary]=[]
var name:=""
var contacts: Array=[]
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
func shot(mark: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 var foes: Array=[]
 for enemy in game.enemies:
  if is_instance_valid(enemy):foes.append({"kind":enemy.kind,"health":enemy.health,"armor":enemy.armor_rating,"effective":enemy.effective_armor(),"stacks":enemy.mace_armor.stacks,"remaining":enemy.mace_armor.remaining,"broken":enemy.mace_armor.broken(),"visible":enemy.visible})
 var file:=name+"-"+mark+".png";root.get_texture().get_image().save_png(output.path_join(file))
 frames.append({"case":name,"mark":mark,"file":file,"stage":game.motion.stage,"family":game.weapon_family,"stamina":game.stamina,"hits":game.hits,"damage":game.total_damage,"status_panel":game.ui.mace_status_panel.visible,"status_text":game.ui.mace_status.text,"enemies":foes})
func equip(id: String,set_index: int,hand: String="main") -> void:
 var bag_index: int=game.loadout.bag.find(id)
 check(bag_index>=0,"fixture item available: "+id)
 if bag_index>=0:check(game.loadout.move_item({"kind":"bag","index":bag_index},{"kind":"slot","set":set_index,"hand":hand}),"equip fixture "+id)
func fixture(off: String="",armor: float=100.0):
 game.loadout.defaults()
 check(game.loadout.move_item({"kind":"slot","set":0,"hand":"off"},{"kind":"bag","index":game.loadout.bag.find("")}),"remove initial offhand")
 equip("mace0",0);equip("sword0",1)
 if off!="":equip(off,0,"off")
 game.loadout_edited();game.start_run(true);game.clear_actors();game.player.position=Vector3.ZERO
 game.stats.reset_modifiers();game.stats.flat.critical_chance=-.05
 var enemy=game.spawn_enemy("dummy",Vector3(2,.03,0));enemy.max_health=1000;enemy.health=1000;enemy.armor_rating=armor
 game.fx.clear_transients();await advance(30);return enemy
func finish() -> void:
 for i in range(300):
  if not game.motion.busy and not game.pair_strikes.active:return
  await advance()
 check(false,"attack completes")
func swing(clip: bool=false) -> void:
 mouse(true);mouse(false)
 check(game.motion.busy,"actual LMB accepted")
 if clip:
  for i in range(40):await shot("frame-%02d"%i);await advance(2)
 await finish();await advance(2)
func stack_case(armor: float) -> void:
 name="armor%d"%int(armor);var enemy=await fixture("",armor)
 for count in range(1,6):
  for stage in range(3):
   var before: float=game.total_damage
   var multiplier: float=enemy.calculate_incoming_damage(1,"physical")
   var origin: Vector3=game.player.position
   await swing(armor==100 and count==5 and stage==2)
   var expected: float=[34.0,12.0,46.0][stage]*multiplier
   contacts.append({"case":name,"count":count,"stage":stage+1,"origin":str(origin),"end":str(game.player.position),"target":str(enemy.position),"angle":game.motion.aim_angle,"actual":game.total_damage-before,"expected":expected,"hit":game._hit_targets.has(enemy.get_instance_id())})
   check(absf(game.total_damage-before-expected)<.02,"natural combo prehit damage count%d stage%d actual=%f expected=%f angle=%f player=%s target=%s"%[count,stage+1,game.total_damage-before,expected,game.motion.aim_angle,str(game.player.position),str(enemy.position)])
   check(enemy.mace_armor.stacks==(count if stage==2 else count-1),"one stack only on actual third")
  await shot("stack%d"%count)
  if count<5:await advance(180)
 check(game.ui.mace_status_panel.visible and "เกราะแตก" in game.ui.mace_status.text,"readable fullstackHUD")
 var left: float=enemy.mace_armor.remaining
 key(KEY_Q);check(game.weapon_family=="sword" and game.loadout.active==1,"actual Q swaps separate weaponset")
 check(enemy.mace_armor.stacks==5 and absf(enemy.mace_armor.remaining-left)<.001,"Q does not alter targetdebuff")
 var before: float=game.total_damage
 mouse(true);var base: float=game.motion.definition(0).damage;mouse(false);await finish()
 check(absf(game.total_damage-before-base*(2.2 if armor>0 else 1.1))<.02,"actual swapped sword receives full debuff")
 await shot("sword-after-Q")
 if armor>0:
  equip("pistol0",0);key(KEY_Q);check(game.weapon_family=="pistol","Q switches to pistol testset")
  before=game.total_damage;mouse(true);base=game.motion.definition(0).damage;mouse(false);await finish();await advance(40)
  check(absf(game.total_damage-before-base*2.2)<.02,"actual pistol projectile receives physical bonus once")
  await shot("pistol-after-Q")
  key(KEY_ESCAPE);check(game.mode=="paused","real Escape pauses")
  left=enemy.mace_armor.remaining;await advance(120);check(absf(enemy.mace_armor.remaining-left)<.001,"pause freezes actualstatus")
  await shot("paused");key(KEY_ESCAPE);await advance(650)
  check(enemy.mace_armor.stacks==0 and not game.ui.mace_status_panel.visible,"actual timer expires and HUD clears")
  await shot("expired")
  before=game.total_damage;mouse(true);base=game.motion.definition(0).damage;mouse(false);await finish();await advance(40)
  check(absf(game.total_damage-before-base)<.02,"physical damage restores after expiry")
 cases.append({"case":name,"base_armor":armor,"natural_stacks":5,"real_Q":true})
func pair_case(off: String) -> void:
 name="paired-"+off;var enemy=await fixture(off)
 for stage in range(3):
  await swing()
  check(enemy.mace_armor.stacks==((2 if off=="mace1" else 1) if stage==2 else 0),"paired only actual mace third adds stack")
  await shot("stage%d"%(stage+1))
 check(game.loadout_mode and game.loadout.for_pair().size()==2,"actual paired controller path")
 cases.append({"case":name,"stacks":enemy.mace_armor.stacks})
func run() -> void:
 if output=="" or DisplayServer.get_name()=="headless":quit(1);return
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
 DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 name="ten-second-timer";var enemy=await fixture()
 for i in range(3):await swing()
 check(enemy.mace_armor.stacks==1 and enemy.mace_armor.remaining>9.6,"natural third starts10seconds");await shot("fresh")
 await advance(720)
 check(enemy.mace_armor.stacks==1 and enemy.mace_armor.remaining>3.6 and game.ui.mace_status_panel.visible,"stillactive after6seconds");await shot("after6seconds")
 key(KEY_Q);check(game.weapon_family=="sword" and enemy.mace_armor.stacks==1,"Q retains10seconddebuff")
 await advance(500);check(enemy.mace_armor.stacks==0 and not game.ui.mace_status_panel.visible,"expiresafter10seconds");await shot("expired")
 var f:=FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"frames":frames,"failures":failures,"native_no_focus":safe},"\t"));f.close()
 game.queue_free();await process_frame
 print("MACE10 NATIVE: 1case / ",frames.size()," images; failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
