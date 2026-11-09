extends SceneTree
const STEP := 1.0/120
var game
var output := ""
var native := false
var safe := false
var failures: Array[String]=[]
var cases: Array[Dictionary]=[]
var cues: Array[Dictionary]=[]
var current := ""
var ticks := 0
var max_rotation_error := .0
func _initialize() -> void:
 root.unfocusable=true;Engine.physics_ticks_per_second=120
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 native=DisplayServer.get_name()!="headless";call_deferred("run")
func _process(_delta: float) -> bool:
 if safe and (not root.unfocusable or DisplayServer.window_get_position()!=Vector2i(20000,20000)):quit(1)
 return false
func check(ok: bool,why: String) -> void:
 if not ok:failures.append(current+": "+why);printerr("FAIL: ",current,": ",why)
func cue(name: String) -> void:cues.append({"cue":name,"tick":ticks})
func key(code: Key) -> void:
 for down in [true,false]:
  var e := InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;root.push_input(e,true)
func aim() -> void:
 var e := InputEventMouseMotion.new();e.position=game.camera.unproject_position(game.player.position+Vector3.RIGHT*5);root.push_input(e,true)
func click() -> void:
 aim()
 for down in [true,false]:
  var e := InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=game.camera.unproject_position(game.player.position+Vector3.RIGHT*5);root.push_input(e,true)
func equip(id: String,hand: String) -> void:
 var source: Dictionary={};var index: int=game.loadout.bag.find(id)
 if index>=0:source={"kind":"bag","index":index}
 else:
  for i in range(2):
   for slot in ["main","off"]:
    if game.loadout.sets[i][slot]==id:source={"kind":"slot","set":i,"hand":slot}
 var target := {"kind":"slot","set":0,"hand":hand}
 if source!=target:check(game.loadout.move_item(source,target),"fixture equipment")
func fixture(main: String,off: String) -> void:
 current=main+"_"+(off if off!="" else "solo")
 game.loadout.defaults();game.loadout.save_path="";game.loadout.unequip({"kind":"slot","set":0,"hand":"off"})
 equip(main,"main")
 if off!="":equip(off,"off")
 game.loadout_edited();game.start_run(true)
 for enemy in game.enemies:enemy.position=Vector3(100,.03,100)
 cues.clear();ticks=0
 for i in range(60):await tick()
func tick() -> void:
 await physics_frame;check(Engine.is_in_physics_frame(),"actual physics driver")
 aim();game.tick(STEP);ticks+=1
 if game.guns_reloading():
  var pose: Dictionary=game.current_visual_sample()
  var rig=game.dual_visual.rigs[1 if game._is_left_hand() else 0] if game._uses_dual_hands() else game.avatar
  if float(pose.progress)>.16:
   var vector := Vector3(cos(pose.angle)*cos(pose.pitch),sin(pose.pitch),sin(pose.angle)*cos(pose.pitch))
   var axis := Vector2(game.camera.global_basis.x.dot(vector),game.camera.global_basis.y.dot(vector))
   var expected: float=atan2(axis.y,axis.x)+float(pose.get("screen_roll",0))
   max_rotation_error=maxf(max_rotation_error,absf(wrapf(rig.weapon.rotation.z-expected,-PI,PI)))
  if game.weapon_family=="pistol" and float(pose.get("spin_blur",0))>.2:
   check(rig.spin_ghosts[0].visible and rig.spin_ghosts[1].visible,"active hand shows spin smear")
  if game._uses_dual_hands():
   check(game.dual_visual.rigs[0].weapon.visible and game.dual_visual.rigs[1].weapon.visible,"both held weapons remain")
   check(not game.avatar.weapon.visible and not game.avatar.spin_ghosts[0].visible,"no hidden-avatar ghost duplicates")
func snapshot() -> Dictionary:
 var pose: Dictionary=game.current_visual_sample()
 var row := {"tick":ticks,"family":game.weapon_family,"item":game.active_item,"phase":pose.phase,"reloading":game.guns_reloading(),"progress":pose.get("progress",0),"roll":pose.get("screen_roll",0),"pitch":pose.get("pitch",0),"support_pull":pose.get("support_pull",0),"casings":game.casing_fx.spawned_count,"ammo":game.active_magazine().rounds}
 return row
func case(main: String,off: String="") -> void:
 await fixture(main,off)
 DirAccess.make_dir_recursive_absolute(output.path_join(current))
 var frames: Array=[]
 var started := false
 var second := false
 var peak_pitch := .0
 var peak_roll := .0
 for frame in range(180):
  if frame==6:click()
  if not started and frame>6 and not game.motion.busy and not game.pair_strikes.active:
   key(KEY_R);check(game.guns_reloading(),"R starts after real shot");started=true
  if main=="pistol0" and off=="pistol1" and started and not second and not game.guns_reloading():key(KEY_R);check(game.guns_reloading(),"second pistol R starts");second=true
  for i in range(2):await tick()
  var state := snapshot();peak_pitch=maxf(peak_pitch,state.pitch);peak_roll=maxf(peak_roll,state.roll)
  if native:
   await process_frame;await RenderingServer.frame_post_draw
   var name := current+"/frame_%03d.png" % frame
   root.get_texture().get_image().save_png(output.path_join(name));state.file=name
  frames.append(state)
 check(started and not game.guns_reloading(),"reload completes inside clip")
 check(game.active_magazine().rounds==game.active_magazine().capacity,"refill at completion")
 var gun_count := 2 if main=="pistol0" and off=="pistol1" else 1
 check(game.casing_fx.spawned_count==gun_count,"one physical brass casing for each real gun shot")
 if main=="rifle0":check(peak_pitch>.85,"rifle lifted well above aim")
 else:check(peak_roll>TAU*1.8,"two fast turns are visible")
 var names: Array=[]
 for record in cues:
  if record.cue.begins_with("pistol_") or record.cue.begins_with("rifle_"):names.append(record.cue)
 var family := "rifle" if main=="rifle0" else "pistol"
 var expected: Array=["rifle_reload_open","rifle_insert","rifle_rack","rifle_reload_done"] if family=="rifle" else ["pistol_reload_open","pistol_spin","pistol_catch","pistol_reload_done"]
 for name in expected:check(names.count(name)==gun_count,"one staged cue per reload: "+name)
 if native:
  for name in expected:
   check(game.audio._streams.has(name) and game.audio._streams[name].data.size()>1000,"real synthesized mechanical audio: "+name)
 cases.append({"case":current,"frames":frames,"cues":cues.duplicate(true),"peak_roll":peak_roll,"peak_pitch":peak_pitch,"casings":game.casing_fx.spawned_count})
func run() -> void:
 if native:
  if output=="":quit(1);return
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
 if output!="":DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.audio.cue_requested.connect(cue)
 for setup in [["pistol0",""],["rifle0",""],["sword0","pistol0"],["pistol0","sword0"],["pistol0","pistol1"]]:await case(setup[0],setup[1])
 check(max_rotation_error<.0001,"rendered gun rotation follows actual reload clock")
 if native:
  for name in ["rifle_reload_open","rifle_insert","rifle_rack","rifle_reload_done"]:game.audio._streams[name].save_to_wav(output.path_join(name+".wav"))
 if output!="":
  var file := FileAccess.open(output.path_join("reload-manifest.json"),FileAccess.WRITE)
  file.store_string(JSON.stringify({"cases":cases,"failures":failures,"max_rotation_error":max_rotation_error,"native":native,"fps":60,"physics_hz":120,"native_no_focus":safe,"input":"viewport LMB/R + aim; inventory API fixtures; dummy out of frame; actual shots and magazines, no supplied poses/ammo/damage"},"\t"));file.close()
 game.queue_free();await process_frame
 print("RELOAD NATIVE: ",cases.size()," cases / 900 frames; failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
