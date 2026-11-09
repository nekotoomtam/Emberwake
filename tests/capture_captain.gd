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
func setup_captain_fixture() -> void:
 right(false);game.loadout.defaults();game.loadout.unequip({"kind":"slot","set":0,"hand":"off"});put("sword0","main");game.loadout_edited();game.start_captain();game.stats.reset_modifiers();game.stats.flat.critical_chance=-.05;game.move_input=Vector2.ZERO
func prepare(id: String,point: Vector3) -> void:
 setup_captain_fixture();var e=game.enemies[0];e.position=Vector3(0,.03,0);game.player.position=point;e.attack_data=e.Rules.definition(id);e.attack_angle=PI;e.state="windup";e.telegraph_left=e.attack_data.windup;e.cooldown=0;e.attack_hit=false;e.elapsed=0;e.sprite.flip_h=true
func captain_shot(mark: String) -> void:
 await body_shot(mark)
 if not game.enemies.is_empty():
  var e=game.enemies[0]
  frames[-1]["captain"]={"health":e.health,"arm_cut":e.arm_cut,"arm_hp":e.arm_hp,"state":e.state,"attack":e.attack_data.get("id",""),"elapsed":e.elapsed,"contacts":e.contact_count,"landed":e.landed_count,"position":str(e.position)}
func run() -> void:
 if output=="" or DisplayServer.get_name()=="headless":quit(1);return
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));safe=true;DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 name="harbor-entry";await click_ui(find_button(game.ui,"ท่าเรือ • นายท้ายผู้ลากสมอ"));check(game.encounter_mode=="captain","actualmenu Captain");await advance(20);await captain_shot("arena")
 key(KEY_H);check(game.debug_range,"actualH hitboxes");await advance(2);await captain_shot("hurt-regions")
 name="sweep";prepare("sweep",Vector3(-1.9,.03,0));await advance(90);await captain_shot("windup");check(game.health==100,"windup no damage");await advance(74);check(game.health==82,"actual movinganchor hit once");await captain_shot("impact")
 name="sweep-inner";prepare("sweep",Vector3(-1,.03,0));await advance(185);check(game.health==100,"inside sweep inner gap safe");await captain_shot("safe")
 name="throw-return";prepare("throw",Vector3(-3,.03,0));await advance(116);await captain_shot("aim");await advance(100);await captain_shot("outgoing");await advance(110);await captain_shot("return");await advance(35);check(game.health==52 and game.enemies[0].contact_count==2,"both visible passes hit")
 name="red-slam";prepare("slam",Vector3(-2,.03,0));await advance(100);await captain_shot("red-telegraph");right(true);await advance(75);check(game.health==79 and game.readiness.parries==0,"red guard works notparry");await captain_shot("block")
 name="parry";prepare("sweep",Vector3(-1.9,.03,0));await advance(137);right(true);await advance(20);check(game.health==100 and game.readiness.parries==1,"actual timedRMB parry");await captain_shot("clash")
 name="dodge";prepare("sweep",Vector3(-1.9,.03,0));await advance(139);key(KEY_SPACE);await advance(20);check(game.health==100 and game.rewards.refunded,"actualSPACE precise evade refund");await captain_shot("evade")
 name="arm-cut";setup_captain_fixture();var e=game.enemies[0];e.position=Vector3(0,.03,0);e.state="recover";e.cooldown=999;e.stagger=999;e.sprite.flip_h=false;game.player.position=-game.camera.global_basis.x*.85;game.player.position.y=.03;await advance(10);await captain_shot("before")
 for i in range(16):
  if e.arm_cut:break
  aim(game.camera.global_basis.x);mouse(true);mouse(false);await advance(115)
 check(e.arm_cut and e.health>0,"actual melee cuts arm without killing");game.player.position=Vector3(-2.4,.03,0);await advance(15);await captain_shot("after")
 # Low-health fixture isolates the actual last-hit/victory transition.
 name="victory";e.health=1;mouse(true);mouse(false);await advance(160);check(game.mode=="victory","actual attack finishes mini");await captain_shot("screen")
 key(KEY_T);await advance(2);check(game.encounter_mode=="captain" and game.enemies.size()==1 and not game.enemies[0].arm_cut and game.flasks.charges==3,"T replay resets encounter");name="replay";await captain_shot("fresh")
 root.content_scale_size=Vector2i(1024,640);root.size=Vector2i(1024,640);await advance(2);name="small-layout";await captain_shot("HUD")
 right(false);mouse(false);game.queue_free();await process_frame;await process_frame
 var f:=FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"frames":frames,"failures":failures,"native_no_focus":safe},"\t"));f.close()
 print("CAPTAIN NATIVE: ",frames.size()," images; failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
