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
 frames.append({"case":name,"kind":kind,"file":file,"warnings":game.vision.warnings.size(),"seen":game.vision.seen,"sense":game.stats.value("sense_radius"),"cue_states":game.vision.cues.states.duplicate(true),"aim":game.aim})
func fixture() -> void:
 game.start_run(true);game.clear_actors();game.player.position=Vector3.ZERO;game.fx.clear_transients()
func add_enemy(point: Vector3):
 var enemy=game.spawn_enemy("melee",point);enemy.stagger=100;enemy.cooldown=100;return enemy
func run() -> void:
 if output=="" or DisplayServer.get_name()=="headless":quit(1);return
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
 DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 fixture();var side55=add_enemy(Vector3(cos(deg_to_rad(55.0)),0,sin(deg_to_rad(55.0)))*3)
 var side70=add_enemy(Vector3(cos(deg_to_rad(70.0)),0,sin(deg_to_rad(70.0)))*3)
 game.fx.clear_transients();await advance(30,Vector3.RIGHT)
 check(side55.visible and not side70.visible,"120degree reveals55 but conceals70")
 check(game.vision.warnings.size()==1,"only unseen side threat warns")
 await shot("wide-edge","overview")
 game.vision.indicator.visible=false;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join("edge-no-cues.png"))
 game.vision.indicator.visible=true;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join("edge-clipped-cues.png"))
 var sz: Vector2=root.get_texture().get_size()
 var zero: Vector2=game.vision.cue_material.get_shader_parameter("world_origin")
 var dx: Vector2=game.vision.cue_material.get_shader_parameter("world_dx")
 var dy: Vector2=game.vision.cue_material.get_shader_parameter("world_dy")
 var edge_geometry:={"world_origin":[zero.x,zero.y],"world_dx":[dx.x,dx.y],"world_dy":[dy.x,dy.y],"player_ground":[game.player.position.x,game.player.position.z],"facing":[game.vision.forward.x,game.vision.forward.z]}
 cases.append({"case":"wide-edge","visible55":side55.visible,"visible70":side70.visible})
 var manifest:=FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE)
 manifest.store_string(JSON.stringify({"cases":cases,"frames":frames,"failures":failures,"edge_geometry":edge_geometry,"native_no_focus":safe,"physics_hz":120,"clip_fps":60,"input":"viewport mouse plus stationary enemy fixtures and actual wall colliders, stat modifier API and panel API"},"\t"));manifest.close()
 game.queue_free();await process_frame
 print("SIGHT NATIVE: ",cases.size()," cases / ",frames.size()," frames; failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
