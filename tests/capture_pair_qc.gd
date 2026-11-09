extends SceneTree
const STEP := 1.0/120
var game
var output := ""
var native := false
var baseline := false
var safe := false
var cases: Array[Dictionary]=[]
var frames: Array[Dictionary]=[]
var failures: Array[String]=[]
var current := ""
var face := Vector3.RIGHT
var direction_name := "right"
var max_tip_error := .0
func _initialize() -> void:
 root.unfocusable=true;Engine.physics_ticks_per_second=120
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 if "--baseline" in OS.get_cmdline_user_args():baseline=true
 native=DisplayServer.get_name()!="headless";call_deferred("run")
func _process(_delta: float) -> bool:
 if safe and (not root.unfocusable or DisplayServer.window_get_position()!=Vector2i(20000,20000)):quit(1)
 return false
func check(ok: bool,why: String) -> void:
 if not ok:failures.append(current+"/"+direction_name+": "+why);printerr("FAIL: ",current+"/"+direction_name,": ",why)
func key(code: Key,down: bool) -> void:
 var e := InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e)
func press(code: Key) -> void:key(code,true);key(code,false)
func aim() -> void:
 var e := InputEventMouseMotion.new();e.position=game.camera.unproject_position(game.player.position+face*5);root.push_input(e,true)
func click() -> void:
 for down in [true,false]:
  var e := InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=game.camera.unproject_position(game.player.position+face*5);root.push_input(e,true)
func equip(id: String,hand: String) -> void:
 var source: Dictionary={};var index: int=game.loadout.bag.find(id)
 if index>=0:source={"kind":"bag","index":index}
 else:
  for i in range(2):
   for slot in ["main","off"]:
    if game.loadout.sets[i][slot]==id:source={"kind":"slot","set":i,"hand":slot}
 var target := {"kind":"slot","set":0,"hand":hand}
 if source!=target:check(game.loadout.move_item(source,target),"fixture equip")
func fixture(main: String,off: String) -> void:
 current=main+"_"+(off if off!="" else "solo")
 game.loadout.defaults();game.loadout.save_path="";game.loadout.unequip({"kind":"slot","set":0,"hand":"off"})
 equip(main,"main")
 if off!="":equip(off,"off")
 game.loadout_edited();game.start_run(true)
 for enemy in game.enemies:enemy.position=Vector3(100,.03,100)
func tick() -> void:
 await physics_frame;check(Engine.is_in_physics_frame(),"physics owner")
 aim();game.tick(STEP)
 check(game.avatar.facing==direction_name,"body follows camera-space mouse aim")
 check(not game.avatar.body.flip_h,"uses directional frames, no accidental second flip")
 if not baseline and game._uses_dual_hands():
  var expected: Array[Vector3]=game.avatar.paired_shoulders()
  for hand in range(2):check(game.dual_visual.rigs[hand].grip_visual.shoulder_world.distance_to(expected[hand])<.00001,"rendered arm follows animated shirt shoulder")
 if game.motion.busy and game.current_visual_sample().phase=="active":
  var rig=game.dual_visual.rigs[1 if game._is_left_hand() else 0] if game._uses_dual_hands() else game.avatar
  max_tip_error=maxf(max_tip_error,rig.get_blade_points().tip.distance_to(game._staff_tip(game.current_visual_sample())))
func save(mark: String) -> void:
 var row := {"case":current,"direction":direction_name,"mark":mark,"body_frame":game.avatar.body.frame,"body_animation":game.avatar.body.animation,"item":game.active_item,"facing":game.avatar.facing}
 if not baseline:
  row.hands=[]
  for i in range(2):
   var rig=game.dual_visual.rigs[i]
   row.hands.append({"id":game.dual_visual.ids[i],"shoulder":rig.grip_visual.shoulder_world,"grip":rig.get_blade_points().grip,"tip":rig.get_blade_points().tip,"priority":rig.weapon.render_priority,"acting":game.dual_visual.was_active[i]})
 if native:
  await process_frame;await RenderingServer.frame_post_draw
  var name := current+"-"+direction_name+"-"+mark+".png"
  root.get_texture().get_image().save_png(output.path_join(name));row.file=name
 frames.append(row)
func loadout_case(main: String,off: String) -> void:
 fixture(main,off)
 for entry in [["front",Vector3.BACK,KEY_S],["back",Vector3.FORWARD,KEY_W],["left",Vector3.LEFT,KEY_A],["right",Vector3.RIGHT,KEY_D]]:
  direction_name=entry[0];face=entry[1]
  for i in range(30):await tick()
  await save("idle")
  if baseline:continue
  key(entry[2],true)
  for i in range(24):await tick()
  check(game.avatar.body.animation=="walk","actual walking animation")
  await save("walk");key(entry[2],false)
  click();check(game.motion.busy,"click starts original attack")
  var captured := false
  for i in range(400):
   await tick()
   if not captured and game.motion.busy and game.current_visual_sample().phase=="active":await save("attack");captured=true
   if not game.motion.busy and not game.pair_strikes.active:break
  check(captured and not game.motion.busy and not game.pair_strikes.active,"attack completed")
 cases.append({"case":current})
func reload_views() -> void:
 for setup in [["sword0","pistol0"],["mace0","pistol0"],["pistol0","sword0"],["pistol0","mace0"],["pistol0","pistol1"]]:
  fixture(setup[0],setup[1])
  for entry in [["front",Vector3.BACK],["back",Vector3.FORWARD],["left",Vector3.LEFT],["right",Vector3.RIGHT]]:
   direction_name=entry[0];face=entry[1]
   for i in range(24):await tick()
   click()
   for i in range(400):
    await tick()
    if not game.motion.busy and not game.pair_strikes.active:break
   press(KEY_R);await tick();check(game.guns_reloading(),"actual shot followed by R")
   var captured := false
   for i in range(200):
    await tick()
    if not captured and game.guns_reloading() and game.active_magazine().progress()>=.4:await save("reload");captured=true
    if not game.guns_reloading():break
   check(captured and not game.guns_reloading(),"four-direction reload completed")
func walking_clip() -> Array:
 fixture("sword0","pistol0")
 var records: Array=[]
 for entry in [["front",Vector3.BACK,KEY_S],["back",Vector3.FORWARD,KEY_W],["left",Vector3.LEFT,KEY_A],["right",Vector3.RIGHT,KEY_D]]:
  direction_name=entry[0];face=entry[1]
  for i in range(30):await tick()
  key(entry[2],true)
  for i in range(30):
   for sub in range(4):await tick()
   if native:
    await process_frame;await RenderingServer.frame_post_draw
    var name := "walk-"+direction_name+"-%02d.png" % i
    root.get_texture().get_image().save_png(output.path_join(name));records.append({"file":name,"direction":direction_name,"frame":game.avatar.body.frame})
  key(entry[2],false)
 return records
func run() -> void:
 if native:
  if output=="":quit(1);return
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
 if output!="":DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
 for a in ["sword","mace","pistol"]:
  for b in ["sword","mace","pistol"]:await loadout_case(a+"0",b+("1" if a==b else "0"))
 var clips: Array=[]
 if not baseline:
  await reload_views()
  clips=await walking_clip()
 check(max_tip_error<.0001,"unchanged authored active hit/muzzle alignment")
 if output!="":
  var directions=load("res://scripts/hero_directions.gd")
  for dir in ["front","back","left","right"]:
   for i in range(4):directions.frames(dir).get_frame_texture("walk",i).get_image().save_png(output.path_join("sprite-"+dir+"-%d.png" % i))
  var file := FileAccess.open(output.path_join("directions-manifest.json"),FileAccess.WRITE)
  file.store_string(JSON.stringify({"cases":cases,"frames":frames,"walk_clip":clips,"failures":failures,"max_tip_error":max_tip_error,"native":native,"native_no_focus":safe,"physics_hz":120,"fps":30,"input":"actual viewport aim/LMB, parsed WASD; inventory API fixture; original dummy outside crop; no supplied poses/ammo/damage"},"\t"));file.close()
 game.queue_free();await process_frame
 print("PAIR QC NATIVE: ",cases.size()," loadouts / ",frames.size()," views / ",clips.size()," walking frames; failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
