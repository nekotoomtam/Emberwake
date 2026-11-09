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
func put(id: String,hand: String,set_index: int=0) -> void:
 var index: int=game.loadout.bag.find(id)
 var src: Dictionary={"kind":"bag","index":index}
 if index<0:
  for i in range(2):
   for h in ["main","off"]:
    if game.loadout.sets[i][h]==id:src={"kind":"slot","set":i,"hand":h}
 var dst:={"kind":"slot","set":set_index,"hand":hand}
 if src!=dst:check(game.loadout.move_item(src,dst),"fixture equip")
func setup(main: String,off: String="") -> void:
 right(false);game.loadout.defaults();game.loadout.unequip({"kind":"slot","set":0,"hand":"off"});put(main,"main")
 if off!="":put(off,"off")
 game.loadout_edited();game.start_run(true);game.clear_actors();game.player.position=Vector3.ZERO
 game.stats.reset_modifiers();game.stats.flat.critical_chance=-.05;game.move_input=Vector2.ZERO;game.shot_rng.seed=5271
 var enemy=game.spawn_enemy("dummy",Vector3(3,.03,0));enemy.max_health=1000;enemy.health=1000
 game.fx.clear_transients();await advance(30)
func shot(mark: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 var foes: Array=[]
 for enemy in game.enemies:
  if is_instance_valid(enemy):foes.append({"position":str(enemy.position),"health":enemy.health,"mark":enemy.rifle_mark.stacks,"mark_left":enemy.rifle_mark.remaining,"armor_stacks":enemy.mace_armor.stacks,"visible":enemy.visible})
 var mag=game.active_magazine()
 var file:=name+"-"+mark+".png"
 if FileAccess.file_exists(output.path_join(file)):file=name+"-"+mark+"-%d.png"%frames.size()
 root.get_texture().get_image().save_png(output.path_join(file))
 frames.append({"case":name,"mark":mark,"file":file,"damage":game.total_damage,"stamina":game.stamina,"shots":game.staff_flight.shots_fired,"rounds":mag.rounds,"reloading":mag.reloading,"bolt":mag.needs_bolt if mag.has_method("start_bolt") else false,"phase":mag.phase if mag.has_method("start_bolt") else "","icons":game.status_icons.shown,"sight":game.vision.reach(),"cone":rad_to_deg(game.vision.half_angle())*2,"camera_size":game.camera.size,"focus":game.rifle_focus_state.amount(),"scope":game.rifle_scope.visible,"spread":rad_to_deg(game.gun_spread("pistol",game.right_action()=="aim")),"reticle_radius":game.pistol_reticle.radius,"right_rounds":game.item_magazines.pistol0.rounds,"left_rounds":game.item_magazines.pistol1.rounds,"tempo_stacks":game.pistol_aim_state.stacks,"tempo_bonus":game.pistol_aim_state.speed_bonus(),"attack_rate":game.attack_rate(),"reload_rate":game.reload_rate(),"enemies":foes})
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
func click_ui(control: Control) -> void:
 await process_frame
 var at: Vector2=control.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new();motion.position=at;root.push_input(motion,true)
 for pressed in [true,false]:
  var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=at;e.pressed=pressed;root.push_input(e,true);Input.flush_buffered_events()
 await process_frame
func find_button(node: Node,text: String) -> Button:
 if node is Button and node.text==text:return node
 for c in node.get_children():
  var found: Button=find_button(c,text)
  if found!=null:return found
 return null
func body_shot(mark: String) -> void:
 await shot(mark)
 frames[-1]["integrity"]=game.anatomy.integrity.duplicate();frames[-1]["missing"]=game.anatomy.missing.duplicate();frames[-1]["max_hp"]=game.max_health();frames[-1]["mode"]=game.mode;frames[-1]["lab"]=game.body_lab_open
 var visible: Array=[]
 for id in game.avatar.modular_body.parts:
  if game.avatar.modular_body.parts[id].visible:visible.append(id)
 frames[-1]["visible_parts"]=visible
func run() -> void:
 if output=="" or DisplayServer.get_name()=="headless":quit(1);return
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
 DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 name="body-lab";await setup("pistol0","pistol1");await body_shot("complete")
 key(KEY_B);check(game.body_lab_open,"actualB openslab");await body_shot("open")
 await click_ui(game.anatomy_panel.part_buttons.right_arm);await click_ui(find_button(game.anatomy_panel,"ทำลาย / สูญเสีย"));check(not game.anatomy.present("right_arm") and game.max_health()==90,"actualUI removes arm andmaxHP");await body_shot("right-arm-removed")
 key(KEY_ESCAPE);check(not game.body_lab_open and game.mode=="practice","actualESC closeslab withoutpause");mouse(true);mouse(false);await finish();check(game.item_magazines.pistol0.rounds==10 and game.item_magazines.pistol1.rounds==9,"real leftonly shot spendsleft");await body_shot("left-only-fire")
 for part in ["left_arm","right_arm","left_leg","right_leg"]:
  name="missing-"+part;await setup("pistol0","pistol1");game.remove_body_part(part);await advance(2);await body_shot("idle")
  check(not game.avatar.modular_body.parts[part].visible,"actual sprite absent "+part)
 name="twohand-block";await setup("greatsword0");game.remove_body_part("left_arm");mouse(true);mouse(false);check(not game.motion.busy,"actualLMB twohand blocked");await body_shot("blocked")
 name="one-leg-dash";await setup("pistol0");game.remove_body_part("left_leg");var start: Vector3=game.player.position;key(KEY_SPACE);await advance(30);check(Vector2(game.player.position.x-start.x,game.player.position.z-start.z).length()<1.7,"oneleg shortdash");await body_shot("done")
 name="crawl";await setup("pistol0","pistol1");game.remove_body_part("left_leg");game.remove_body_part("right_leg");game.move_input=Vector2.RIGHT;await advance(30);check(not game.body_action_ready(),"movingcrawl cannotattack");await body_shot("moving")
 mouse(true);mouse(false);check(not game.motion.busy,"actualmoving LMB blocked");game.move_input=Vector2.ZERO;await advance(35);await body_shot("ready");mouse(true);mouse(false)
 var crawl_start: Vector3=game.player.position;game.move_input=Vector2.RIGHT;await advance(20);check(Vector2(game.player.position.x-crawl_start.x,game.player.position.z-crawl_start.z).length()<.001,"cannotwalkduringcrawlshot");await body_shot("shooting");game.move_input=Vector2.ZERO;await finish()
 game.remove_body_part("right_arm");name="one-arm-crawl";game.move_input=Vector2.RIGHT;await advance(20);await body_shot("moving");game.move_input=Vector2.ZERO
 game.remove_body_part("left_arm");name="wriggle";var start2: Vector3=game.player.position;game.move_input=Vector2.RIGHT;await advance(30);check(game.player.position.distance_to(start2)>.01 and not game.request_attack(),"fourlost wriggles nofire");await body_shot("moving");game.move_input=Vector2.ZERO
 key(KEY_T);check(game.anatomy.arm_count()==2 and game.anatomy.leg_count()==2 and game.max_health()==100,"T restores all");await advance(2);await body_shot("reset")
 for entry in [["front",Vector3.BACK],["back",Vector3.FORWARD],["left",Vector3.LEFT],["right",Vector3.RIGHT]]:
  name="direction-"+entry[0];await setup("pistol0","pistol1");game.remove_body_part("right_arm");await advance(30,entry[1]);await body_shot("singlearm")
 name="real-enemy";await setup("sword0");game.clear_actors();var enemy=game.spawn_enemy("melee",Vector3(1.15,.03,0));await advance(150);check(game.anatomy.integrity.right_upper_arm<100,"realAI contact damages authoredarm");await body_shot("hit")
 game.set_debug_health_zero();await advance(130);check(game.mode=="practice" and not enemy.attack_data.get("parryable",true),"HP0 AI allred andalive");await body_shot("critical-red")
 name="torso-spill";await setup("pistol0");game.set_body_integrity("torso",0);game.hit_body_part("torso",20,false);check(game.anatomy.integrity.head==80 and game.mode=="practice","torso0 spills notdead");await body_shot("alive")
 game.set_body_integrity("head",0);check(game.mode=="dead","head0 actualdeath");await body_shot("dead");key(KEY_T)
 root.size=Vector2i(1024,640);await process_frame;await process_frame;name="small-layout";await advance(2);await body_shot("HUD");key(KEY_B);await process_frame;check(game.body_lab_open,"small B opens");await body_shot("lab")
 var bounds: Rect2=Rect2(Vector2.ZERO,root.get_visible_rect().size);check(bounds.encloses(game.anatomy_panel.compact.get_global_rect()),"compactonscreen");check(not game.anatomy_panel.compact.get_global_rect().intersects(game.ui.vital_panel.get_global_rect()),"bodypanel no HPoverlap")
 if game.body_lab_open:key(KEY_ESCAPE)
 root.content_scale_size=Vector2i(1280,800);root.size=Vector2i(1280,800)
 name="recovery";await setup("pistol0");game.health=10;game.set_body_integrity("right_arm",55);key(KEY_F);check(game.health==35 and game.flasks.charges==2,"nativeF drinks instant25");await body_shot("instant")
 await advance(120);check(absf(game.health-40)<.02,"nativeHoT one sec5");await body_shot("healing")
 await click_ui(game.ui.flask_button);check(game.flasks.charges==1 and absf(game.health-65)<.2,"actualHUD potion click");await body_shot("stacked")
 var before: float=game.health;key(KEY_B);await advance(120);check(is_equal_approx(before,game.health),"lab pauses healing");await body_shot("weighted-hp-lab");key(KEY_ESCAPE)
 key(KEY_T);check(game.flasks.charges==3 and game.flasks.effects.is_empty(),"nativeT resets flask");game.health=100;key(KEY_F);check(game.flasks.charges==3,"nativefullHPno waste")
 root.content_scale_size=Vector2i(1024,640);root.size=Vector2i(1024,640);name="recovery-small";await advance(2);await body_shot("HUD");check(not game.anatomy_panel.compact.get_global_rect().intersects(game.ui.vital_panel.get_global_rect()),"newflask no bodyoverlap");check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(game.ui.vital_panel.get_global_rect()),"vitals on screen")
 root.content_scale_size=Vector2i(1280,800);root.size=Vector2i(1280,800)
 for entry in [["front",Vector2.RIGHT],["back",Vector2.LEFT],["side-up",Vector2.UP],["side-down",Vector2.DOWN]]:
  name="elbow-"+entry[0];await setup("pistol0","pistol1");game.remove_body_part("left_leg");game.remove_body_part("right_leg");await advance(35);game.move_input=entry[1];var start_push: Vector3=game.player.position;key(KEY_SPACE);game.move_input=Vector2.ZERO;await advance(12)
  check(game._dodge_left>0 and game.avatar.body.animation!="dodge","actualSPACE prone push art");check(not game.avatar.weapon.visible and game.avatar.grip_visual.visible,"push arms not weapon");check(not game.body_action_ready(),"push invalidates stationary readiness");await body_shot("push")
  await advance(20);var distance: float=Vector2(game.player.position.x-start_push.x,game.player.position.z-start_push.z).length();check(distance>.55 and distance<.70,"quarterdash actualphysics distance="+str(distance));await body_shot("land")
 name="elbow-one-arm";await setup("pistol0");game.remove_body_part("left_leg");game.remove_body_part("right_leg");game.remove_body_part("right_arm");key(KEY_SPACE);await advance(12);check(game._dodge_left>0 and game.avatar.grip_visual.grip_count==1,"one functional arm pushes");await body_shot("push");await advance(50);game.remove_body_part("left_arm");key(KEY_SPACE);check(game._dodge_left<=0,"no arms no push")
 var f:=FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"frames":frames,"failures":failures,"native_no_focus":safe},"\t"));f.close()
 if game.body_lab_open:key(KEY_ESCAPE)
 right(false);mouse(false);await process_frame
 game.queue_free();await process_frame;await process_frame
 print("BODY NATIVE: ",frames.size()," images; failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
