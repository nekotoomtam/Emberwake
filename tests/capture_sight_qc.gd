extends SceneTree
var game
var output:=""
var failures: Array[String]=[]
var cases: Array[Dictionary]=[]
var frames: Array[Dictionary]=[]
var safe:=false
const STEP:=1.0/120
func _initialize() -> void:
 root.unfocusable=true;Engine.physics_ticks_per_second=120
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func _process(_delta: float) -> bool:
 if safe and (not root.unfocusable or DisplayServer.window_get_position()!=Vector2i(20000,20000)):quit(1)
 return false
func check(ok: bool,why: String) -> void:
 if not ok:failures.append(why);printerr("FAIL: ",why)
func aim(direction: Vector3) -> void:
 var e:=InputEventMouseMotion.new();e.position=game.camera.unproject_position(game.player.position+direction*5);root.push_input(e,true)
func advance(count: int,direction: Vector3) -> void:
 for i in range(count):
  await physics_frame;aim(direction);game.tick(STEP)
func shot(name: String,kind: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 var file:=name+"-"+kind+".png";var image:=root.get_texture().get_image();image.save_png(output.path_join(file))
 frames.append({"case":name,"kind":kind,"file":file,"warnings":game.vision.warnings.size(),"seen":game.vision.seen,"sense":game.stats.value("sense_radius"),"aim":game.aim})
func fixture() -> void:
 game.start_run(true);game.clear_actors();game.player.position=Vector3.ZERO;game.fx.clear_transients()
func add_enemy(point: Vector3):
 var enemy=game.spawn_enemy("melee",point);enemy.stagger=100;enemy.cooldown=100;return enemy
func run() -> void:
 if output=="" or DisplayServer.get_name()=="headless":quit(1);return
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
 DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 for entry in [["right",Vector3.RIGHT],["front",Vector3.BACK],["left",Vector3.LEFT],["back",Vector3.FORWARD]]:
  fixture();var enemies: Array=[]
  for point in [Vector3(3,0,0),Vector3(-3,0,0),Vector3(0,0,3),Vector3(0,0,-3)]:enemies.append(add_enemy(point))
  game.fx.clear_transients();await advance(30,entry[1]);var count:=0
  for enemy in enemies:
   if enemy.visible:count+=1
  check(count==1,"only front enemy visible "+entry[0]);check(game.vision.warnings.size()==3,"three rear/side cues "+entry[0]);await shot(entry[0],"overview")
  for i in range(24):await advance(2,entry[1]);await shot(entry[0],"frame-%02d"%i)
  cases.append({"case":entry[0],"visible":count,"warnings":game.vision.warnings.size()})
 fixture();var behind=add_enemy(Vector3(-3,0,0));game.fx.clear_transients();await advance(20,Vector3.RIGHT)
 game.stats.flat.sense_radius=-3;await advance(8,Vector3.RIGHT);check(not behind.visible and game.vision.warnings.is_empty(),"outside reduced sense no cues");await shot("sense-small","hidden");cases.append({"case":"sense-small"})
 game.stats.flat.sense_radius=2;await advance(8,Vector3.RIGHT);check(not behind.visible and game.vision.warnings.size()==1,"expanded sense detects hidden");await shot("sense-large","cue");cases.append({"case":"sense-large"})
 # Keep combat aim committed while actual mouse turns sight behind.
 game.set_weapon_family("sword");aim(Vector3.RIGHT);await advance(2,Vector3.RIGHT);game.request_attack()
 var locked: Vector3=game.aim;await advance(2,Vector3.LEFT)
 check(behind.visible and game.aim==locked,"native mouse turns sight during attack without redirect")
 await shot("attack-look","rear-revealed");cases.append({"case":"attack-look"})
 await advance(120,Vector3.RIGHT)
 game.stats.reset_modifiers()
 var wall=game.arena.block(Vector3(-1.5,1,0),Vector3(.3,2,3),"#40515b")
 await advance(10,Vector3.RIGHT);check(game.vision.warnings.is_empty(),"wall blocks actual hidden sensor");await shot("wall-rear","no-cue");cases.append({"case":"wall-rear"})
 await advance(10,Vector3.LEFT);check(not behind.visible and game.vision.warnings.is_empty(),"wall blocks front vision too");await shot("wall-front","shadow");cases.append({"case":"wall-front"})
 # Turn away from the wall: foreground cone should be bright, rear dark.
 await advance(8,Vector3.RIGHT)
 await process_frame;await RenderingServer.frame_post_draw
 var im:=root.get_texture().get_image()
 var bright: Vector2i=Vector2i(game.camera.unproject_position(Vector3(2.5,0,1.6)))
 var dark: Vector2i=Vector2i(game.camera.unproject_position(Vector3(-2.5,0,1.6)))
 var b:=im.get_pixelv(bright);var d:=im.get_pixelv(dark)
 game.vision.fog.visible=false
 await process_frame;await RenderingServer.frame_post_draw
 var original:=root.get_texture().get_image();original.save_png(output.path_join("unfiltered-reference.png"))
 game.vision.fog.visible=true
 await process_frame;await RenderingServer.frame_post_draw
 var filtered:=root.get_texture().get_image();filtered.save_png(output.path_join("blur-reference.png"))
 var before:=original.get_pixelv(dark);var after:=filtered.get_pixelv(dark)
 check(absf(before.get_luminance()-after.get_luminance())<.10,"blurred region retains scene brightness with mild dimming")
 game.toggle_stats();await shot("stats","panel");check(game.stats_panel.surface.visible,"stats UI above fog");game.toggle_stats();game.toggle_inventory();await shot("inventory","panel");check(game.arsenal.surface.visible,"inventory UI above fog");game.toggle_inventory()
 cases.append({"case":"UI","bright_luminance":b.get_luminance(),"dark_luminance":d.get_luminance()})
 var manifest:=FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE)
 manifest.store_string(JSON.stringify({"cases":cases,"frames":frames,"failures":failures,"native_no_focus":safe,"physics_hz":120,"clip_fps":60,"input":"viewport mouse plus stationary enemy fixtures and actual wall colliders, stat modifier API and panel API"},"\t"));manifest.close()
 game.queue_free();await process_frame
 print("SIGHT NATIVE: ",cases.size()," cases / ",frames.size()," frames; failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
