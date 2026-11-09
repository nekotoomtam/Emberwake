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
func ui_shot(mark: String) -> void:
 game.ui.refresh();await process_frame;await RenderingServer.frame_post_draw
 var ui=game.ui
 var bounds: Rect2=Rect2(Vector2.ZERO,root.get_visible_rect().size)
 var panels: Array=[ui.vital_panel,ui.ammo_panel,ui.header_panel,ui.help_panel]
 if ui.status_panel.visible:panels.append(ui.status_panel)
 if ui.charge_panel.visible:panels.append(ui.charge_panel)
 for p in panels:check(bounds.grow(.5).encloses(p.get_global_rect()),"panel insideviewport "+str(p.name))
 for i in range(panels.size()):
  for j in range(i+1,panels.size()):check(not panels[i].get_global_rect().intersects(panels[j].get_global_rect()),"no paneloverlap "+str(i)+"/"+str(j))
 for entry in [[ui.health_text,ui.vital_panel],[ui.health_bar,ui.vital_panel],[ui.ammo_text,ui.ammo_panel],[ui.reload_bar,ui.ammo_panel],[ui.counter,ui.ammo_panel],[ui.control_hint,ui.help_panel],[ui.weapon_hint,ui.help_panel],[ui.ready_text,ui.help_panel],[ui.stage_text,ui.help_panel],[ui.objective,ui.header_panel]]:
  if entry[0].is_visible_in_tree():check(entry[1].get_global_rect().grow(.5).encloses(entry[0].get_global_rect()),"label/bar inside its panel "+str(entry[0].name))
 check(ui.health_bar.get_global_rect().position.y<bounds.size.y*.5 and ui.health_bar.get_global_rect().end.x<bounds.size.x*.5,"health upperleft")
 check(ui.ammo_panel.get_global_rect().position.x>bounds.size.x*.5 and ui.ammo_panel.get_global_rect().end.y<bounds.size.y*.5,"ammo upperright")
 if ui.status_panel.visible:check(ui.status_panel.get_global_rect().end.x<bounds.size.x*.5 and ui.status_panel.get_global_rect().end.y<bounds.size.y*.5,"effects upperleft")
 await shot(mark)
 frames[-1]["window_size"]=str(root.size);frames[-1]["logical_size"]=str(bounds.size);frames[-1]["effects"]=ui.status_view.shown_effects.duplicate()
func statuses_fixture() -> void:
 # UI-only fixtures for simultaneous positive/negative timed cards, not combat proof.
 game.rewards.grant_counter();game.readiness.broken_left=.65;game._visual_tick(0)
func run() -> void:
 if output=="" or DisplayServer.get_name()=="headless":quit(1);return
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
 DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 for size in [Vector2i(1280,800),Vector2i(1024,640)]:
  root.size=size;await process_frame;await process_frame
  name="hud-%d"%size.x
  await setup("pistol0","pistol1");await ui_shot("dual-idle")
  right(true);await advance(30)
  for i in range(3):mouse(true);mouse(false);await finish()
  check(game.pistol_aim_state.stacks==5,"actualbullets granttempo foricon");await ui_shot("tempo")
  check(game.ui.status_view.shown_effects==["tempo"],"only playerbuff instatusrow")
  statuses_fixture();await ui_shot("all-effects");check(game.ui.status_view.shown_effects.size()==3,"threeeffects visible")
  right(false);await advance(90);await ui_shot("expired");check(not game.ui.status_panel.visible,"expired/released effects disappear")
  check(game.request_reload(),"individualreload starts");await advance(25);await ui_shot("reloading")
  await setup("staff0");await ui_shot("staff")
  await setup("greatsword0");mouse(true);await advance(60);check(game.ui.charge_panel.visible,"greatcharge visible");await ui_shot("great-charge");mouse(false);await finish()
  await setup("rifle0");right(true);await advance(66);await ui_shot("rifle-ADS")
  game.drill_kind="elite";game._visual_tick(0);await ui_shot("long-objective")
  game.drill_kind="";right(false)
  # Actual UI click on relocated inventory button must still open inventory.
  var at: Vector2=game.ui.weapon_button.get_global_rect().get_center()
  var motion:=InputEventMouseMotion.new();motion.position=at;root.push_input(motion,true)
  for down in [true,false]:
   var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=at;root.push_input(e,true);Input.flush_buffered_events()
  check(game.inventory_open,"relocatedbutton actualclick opensinventory");await shot("inventory");key(KEY_ESCAPE);await advance(2)
 var f:=FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"frames":frames,"failures":failures,"native_no_focus":safe,"status_fixture":"counter/guardbreak injected only for UI; tempo from actualshots"},"\t"));f.close()
 game.queue_free();await process_frame
 print("HUD NATIVE: ",frames.size()," images; failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
