extends SceneTree
const STEP:=1.0/120
const Dash=preload("res://scripts/dash_visual.gd")
var game
var output:=""
var native:=false
var safe:=false
var checks:=0
var failures: Array[String]=[]
var cases: Array[Dictionary]=[]
var clips: Array[Dictionary]=[]
var name:=""
var face:=Vector3.RIGHT
var current_facing:="right"
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
 if not ok:failures.append(name+": "+why);printerr("FAIL: ",name+": "+why)
func key(code: Key,down: bool) -> void:
 var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down
 if code==KEY_SPACE:root.push_input(e,true)
 else:Input.parse_input_event(e)
func aim() -> void:
 var e:=InputEventMouseMotion.new();e.position=game.camera.unproject_position(game.player.position+face*5);root.push_input(e,true)
func tick() -> void:
 await physics_frame;aim();game.tick(STEP)
 if game._dodge_left>0:
  check(game.avatar.body.animation=="dodge","dedicated dash frames")
  check(game.avatar.facing==current_facing,"retains mouse-facing during retreat/side-step")
  if game._uses_dual_hands():
   var anchors: Array=game.avatar.paired_shoulders()
   for i in range(2):
    check(game.dual_visual.rigs[i].grip_visual.shoulder_world.distance_to(anchors[i])<.00001,"paired arm follows crouched/leaning shoulder")
    check(game.dual_visual.ids[i]==game.loadout.sets[0]["main" if i==0 else "off"],"gear stays in its own hand")
  else:check(game.avatar.grip_visual.shoulder_world.distance_to(game.avatar.paired_shoulders()[0])<.00001,"solo arm follows dash shoulder")
func equip(id: String,hand: String) -> void:
 var source: Dictionary={};var index: int=game.loadout.bag.find(id)
 if index>=0:source={"kind":"bag","index":index}
 else:
  for i in range(2):
   for slot in ["main","off"]:
    if game.loadout.sets[i][slot]==id:source={"kind":"slot","set":i,"hand":slot}
 var target:={"kind":"slot","set":0,"hand":hand}
 if source!=target:check(game.loadout.move_item(source,target),"fixture equipment move")
func fixture(main: String,off: String) -> void:
 game.loadout.defaults();game.loadout.unequip({"kind":"slot","set":0,"hand":"off"});equip(main,"main")
 if off!="":equip(off,"off")
 game.loadout_edited();game.start_run(true)
 for enemy in game.enemies:enemy.position=Vector3(100,.03,100)
func shot(mark: String) -> Dictionary:
 var row:={"case":name,"mark":mark,"animation":game.avatar.body.animation,"frame":game.avatar.body.frame,"facing":game.avatar.facing,"kind":game.avatar.dodge_kind,"remaining":game._dodge_left}
 if native:
  await process_frame;await RenderingServer.frame_post_draw
  row.file=name+"-"+mark+".png";root.get_texture().get_image().save_png(output.path_join(row.file))
 return row
func episode(main: String,off: String,facing: String,forward: Vector3,kind: String) -> void:
 name=main+"_"+(off if off!="" else "solo")+"-"+facing+"-"+kind;face=forward;current_facing=facing
 fixture(main,off)
 for i in range(3):await tick()
 var right:=Vector3(-forward.z,0,forward.x)
 var travel: Vector3={"front":forward,"back":-forward,"left":-right,"right":right}[kind]
 var code: Key=KEY_D if travel.x>.5 else (KEY_A if travel.x<-.5 else (KEY_S if travel.z>.5 else KEY_W))
 key(code,true);await process_frame;await tick();aim();key(KEY_SPACE,true)
 for wait in range(4):
  await tick()
  if game._dodge_left>0:break
 key(KEY_SPACE,false);key(code,false);await process_frame
 check(game._dodge_left>0,"actual Space starts dash")
 check(game.avatar.dodge_kind==kind,"mouse-relative kind")
 var start: Vector3=game.player.position
 var expected_distance: float=floor(game._dodge_left/STEP)*10.5*STEP
 var row:={"case":name,"views":[]}
 for i in range(1,48):
  await tick()
  if i in [5,12,20]:row.views.append(await shot("pose-%02d"%i))
  if main=="sword0" and off=="pistol0" and i%2==0:clips.append(await shot("clip-%02d"%i))
 check(game._dodge_left<=0 and game.avatar.body.animation!="dodge","pose returns after original duration")
 var distance: float=game.player.position.distance_to(start)
 check(absf(distance-expected_distance)<.01,"unchanged post-first-tick travel: "+str(distance))
 row.travel_after_first_tick=distance;row.return_view=await shot("return")
 check(game.request_attack(),"attack immediately available after dash")
 cases.append(row)
func run() -> void:
 if native:
  if output=="":quit(1);return
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
 if output!="":DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 var setups: Array=[]
 for family in ["sword","greatsword","mace","staff","pistol","rifle"]:setups.append([family+"0",""])
 for a in ["sword","mace","pistol"]:
  for b in ["sword","mace","pistol"]:setups.append([a+"0",b+("1" if a==b else "0")])
 for setup in setups:
  for entry in [["front",Vector3.BACK],["back",Vector3.FORWARD],["left",Vector3.LEFT],["right",Vector3.RIGHT]]:
   for kind in ["front","back","left","right"]:await episode(setup[0],setup[1],entry[0],entry[1],kind)
 if output!="":
  var file:=FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE)
  file.store_string(JSON.stringify({"native":native,"native_no_focus":safe,"physics_hz":120,"clip_fps":60,"cases":cases,"clips":clips,"checks":checks,"failures":failures,"input":"actual viewport mouse aim and parsed WASD+Space; inventory API fixture; no supplied poses or dodge direction"},"\t"));file.close()
 game.queue_free();await process_frame
 print("DASH MATRIX: ",cases.size()," cases; ",checks," checks; failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
