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
 frames.append({"case":name,"mark":mark,"file":file,"damage":game.total_damage,"stamina":game.stamina,"shots":game.staff_flight.shots_fired,"rounds":mag.rounds,"reloading":mag.reloading,"bolt":mag.needs_bolt if mag.has_method("start_bolt") else false,"phase":mag.phase if mag.has_method("start_bolt") else "","icons":game.status_icons.shown,"sight":game.vision.reach(),"cone":rad_to_deg(game.vision.half_angle())*2,"camera_size":game.camera.size,"focus":game.rifle_focus_state.amount(),"scope":game.rifle_scope.visible,"spread":rad_to_deg(game.gun_spread("pistol",game.right_action()=="aim")),"reticle_radius":game.pistol_reticle.radius,"right_rounds":game.item_magazines.pistol0.rounds,"left_rounds":game.item_magazines.pistol1.rounds,"attack_rate":game.attack_rate(),"reload_rate":game.reload_rate(),"enemies":foes})
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
func run() -> void:
 if output=="" or DisplayServer.get_name()=="headless":quit(1);return
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
 DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 name="pistol-single";await setup("pistol0");await shot("hip");check(game.pistol_reticle.center.distance_to(game._mouse_position)<1,"reticle follows actualaiminput");right(true);await advance(15);await shot("half-focus");await advance(15);await shot("ADS")
 check(not game.ready_visual.line_visible and not game.rifle_scope.visible,"no rays or scope");check(absf(game.vision.reach()-10)<.01,"no rangebonus")
 mouse(true);mouse(false)
 for i in range(9):await shot("fire-%02d"%i);await advance(8)
 check(absf(game.total_damage-18)<.01,"actualADS damage18");check(game.item_magazines.pistol0.rounds==9,"single realshot consumes1")
 name="pistol-dual";await setup("pistol0","pistol1");await shot("hip");right(true);await advance(30);await shot("ADS");mouse(true);mouse(false)
 for i in range(14):await shot("fire-%02d"%i);await advance(8)
 check(game.item_magazines.pistol0.rounds==9 and game.item_magazines.pistol1.rounds==9,"two sequential handshots andindependentrounds")
 check(absf(game.stamina-92.2)<.01,"pairaimcost7.8")
 key(KEY_R);await advance(25);await shot("reload-middle");check(game.active_magazine().reloading,"slower reload active");await advance(58)
 check(game.item_magazines.pistol1.rounds==10 and game.item_magazines.pistol0.rounds==9,"reload selected hand only");await shot("reloaded")
 name="mixed-pistol-sword";await setup("pistol0","sword0");right(true);await advance(30);mouse(true);mouse(false)
 for i in range(7):await shot("action-%02d"%i);await advance(20)
 name="mixed-sword-pistol";await setup("sword0","pistol0");mouse(true);mouse(false)
 for i in range(7):await shot("action-%02d"%i);await advance(20)
 name="melee-pair";await setup("sword0","mace0");mouse(true);mouse(false)
 for i in range(7):await shot("action-%02d"%i);await advance(20)
 name="dash-and-set";await setup("pistol0","pistol1");right(true);await advance(30);mouse(true);mouse(false);await advance(12);key(KEY_SPACE);await shot("dash")
 await advance(80);check(not game.pair_strikes.active and game.item_magazines.pistol0.rounds==9 and game.item_magazines.pistol1.rounds==10,"dash cancels second hand without spending itsround")
 key(KEY_Q);await advance(2);key(KEY_Q);await advance(2);check(game.item_magazines.pistol0.rounds==9 and game.item_magazines.pistol1.rounds==10,"Q preserves magazines");await shot("returned")
 key(KEY_ESCAPE);check(not game.pistol_reticle.visible,"pause hidesreticle");key(KEY_ESCAPE);await advance(2);await shot("resumed")
 var f:=FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"frames":frames,"failures":failures,"native_no_focus":safe},"\t"));f.close()
 game.queue_free();await process_frame
 print("PISTOL DUAL NATIVE: ",frames.size()," images; failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
