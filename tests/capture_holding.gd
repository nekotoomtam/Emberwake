extends SceneTree
const STEP := 1.0/120
var game
var output := ""
var native := false
var cases: Array[Dictionary]=[]
var clips: Array[Dictionary]=[]
var failures: Array[String]=[]
var safe := false
var current := ""
var checks := 0
var max_tip_error := .0
func _initialize() -> void:
 root.unfocusable=true;Engine.physics_ticks_per_second=120
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 native=DisplayServer.get_name()!="headless";call_deferred("run")
func _process(_delta: float) -> bool:
 if safe and (not root.unfocusable or DisplayServer.window_get_position()!=Vector2i(20000,20000)):quit(1)
 return false
func check(ok: bool,why: String) -> void:
 checks+=1
 if not ok:failures.append(current+": "+why);printerr("FAIL: ",current,": ",why)
func key(code: Key,down: bool) -> void:
 var event := InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;Input.parse_input_event(event)
func aim(face: Vector3) -> void:
 var event := InputEventMouseMotion.new();event.position=game.camera.unproject_position(game.player.position+face*5);root.push_input(event,true)
func click(face: Vector3,down: bool) -> void:
 var event := InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=game.camera.unproject_position(game.player.position+face*5);root.push_input(event,true)
func equip(id: String,hand: String) -> void:
 var source: Dictionary={};var index: int=game.loadout.bag.find(id)
 if index>=0:source={"kind":"bag","index":index}
 else:
  for i in range(2):
   for slot in ["main","off"]:
    if game.loadout.sets[i][slot]==id:source={"kind":"slot","set":i,"hand":slot}
 var target := {"kind":"slot","set":0,"hand":hand}
 if source!=target:check(game.loadout.move_item(source,target),"inventory equip "+id)
func fixture(main: String,off: String) -> void:
 current=main+"_"+(off if off!="" else "solo")
 game.loadout.defaults();game.loadout.save_path="";game.loadout.unequip({"kind":"slot","set":0,"hand":"off"})
 equip(main,"main")
 if off!="":equip(off,"off")
 game.loadout_edited();game.start_run(true)
 for enemy in game.enemies:enemy.position=Vector3(100,.03,100)
func tick(face: Vector3) -> void:
 await physics_frame;check(Engine.is_in_physics_frame(),"physics driver")
 aim(face);game.tick(STEP)
 if game.motion.busy and game.current_visual_sample().phase=="active":
  var rig=game.dual_visual.rigs[1 if game._is_left_hand() else 0] if game._uses_dual_hands() else game.avatar
  var tip: Vector3=rig.get_blade_points().tip
  max_tip_error=maxf(max_tip_error,tip.distance_to(game._staff_tip(game.current_visual_sample())))
func save(name: String) -> void:
 if not native:return
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name))
func state() -> Dictionary:
 var rigs: Array=game.dual_visual.rigs if game._uses_dual_hands() else [game.avatar]
 var hands: Array=[]
 for rig in rigs:
  var points: Dictionary=rig.get_blade_points()
  hands.append({"family":rig.weapon_family,"grip":points.grip,"tip":points.tip,"grips":rig.grip_visual.grip_count,"support":rig.grip_visual.support_visible})
 return {"hands":hands,"aim":game.aim,"phase":game.current_visual_sample().phase,"stage":game.motion.stage,"player":game.player.position,"body_animation":game.avatar.body.animation}
func stance_case(main: String,off: String) -> void:
 fixture(main,off)
 var shots: Array=[]
 for face in [Vector3.RIGHT,Vector3.LEFT]:
  for i in range(100):await tick(face)
  check(game.aim.dot(face)>.99,"face follows mouse")
  var rigs: Array=game.dual_visual.rigs if off!="" else [game.avatar]
  for rig in rigs:
   check(rig.weapon.visible and rig.grip_visual.visible,"held weapon/sleeve visible")
   var supported: bool=rig.weapon_family in ["greatsword","staff","rifle"] or (rig.weapon_family=="pistol" and off=="")
   check(rig.grip_visual.support_visible==supported,"correct support hand count")
   var blade: Vector3=rig.get_blade_points().tip-rig.get_blade_points().grip
   if rig.weapon_family=="greatsword":check(blade.normalized().dot(face)<-.5 and blade.y>.8,"greatsword carried up/back")
   if rig.weapon_family=="pistol":check(blade.y<-.2,"pistol lowered in rest")
  if off!="":
   var a: Dictionary=rigs[0].get_blade_points();var b: Dictionary=rigs[1].get_blade_points()
   check(Geometry2D.segment_intersects_segment(game.camera.unproject_position(a.grip),game.camera.unproject_position(a.tip),game.camera.unproject_position(b.grip),game.camera.unproject_position(b.tip))==null,"resting weapon silhouettes do not cross")
  var suffix := "right" if face==Vector3.RIGHT else "left"
  var name := current+"-"+suffix+"-idle.png"
  await save(name);var row := state();row.file=name;shots.append(row)
  key(KEY_D if face==Vector3.RIGHT else KEY_A,true)
  for i in range(24):await tick(face)
  check(game.avatar.body.animation=="walk","real movement uses walk frames")
  name=current+"-"+suffix+"-walk.png"
  await save(name);row=state();row.file=name;shots.append(row)
  key(KEY_D if face==Vector3.RIGHT else KEY_A,false)
 cases.append({"case":current,"views":shots})
func clip_case(main: String,off: String) -> void:
 fixture(main,off)
 for i in range(100):await tick(Vector3.RIGHT)
 var label := current;DirAccess.make_dir_recursive_absolute(output.path_join(label))
 var frames: Array=[]
 var released := false
 for frame in range(160):
  if frame==12:click(Vector3.RIGHT,true)
  for i in range(4):
   await tick(Vector3.RIGHT)
   if not released and game.motion.busy and game._loadout_attack_index==2:click(Vector3.RIGHT,false);released=true
  var name := label+"/frame_%03d.png" % frame
  await save(name);var row := state();row.file=name;frames.append(row)
 check(released and not game.motion.busy and not game.pair_strikes.active,"three stages return to rest")
 clips.append({"case":label,"frames":frames})
func run() -> void:
 if native:
  if output=="":quit(1);return
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
 if output!="":DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
 for family in ["sword","mace","pistol","greatsword","staff","rifle"]:await stance_case(family+"0","")
 for a in ["sword","mace","pistol"]:
  for b in ["sword","mace","pistol"]:await stance_case(a+"0",b+("1" if a==b else "0"))
 for pair in [["greatsword0",""],["staff0",""],["rifle0",""],["sword0","pistol0"]]:await clip_case(pair[0],pair[1])
 check(max_tip_error<.0001,"authored active tip unchanged for solo and paired")
 if output!="":
  var file := FileAccess.open(output.path_join("holding-manifest.json"),FileAccess.WRITE)
  file.store_string(JSON.stringify({"cases":cases,"clips":clips,"failures":failures,"checks":checks,"max_tip_error":max_tip_error,"native":native,"physics_hz":120,"fps":30,"native_no_focus":safe,"input":"viewport mouse and parsed keyboard input; original practice dummy moved outside framing; no injected weapon poses/damage/ammo"},"\t"));file.close()
 game.queue_free();await process_frame
 print("HOLDING MATRIX: ",cases.size()," loadouts / 60 stance views / ",clips.size()," clips; checks=",checks," failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
