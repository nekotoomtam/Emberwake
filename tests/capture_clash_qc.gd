extends SceneTree
const STEP:=1.0/120
var game
var output:=""
var safe:=false
var face:=Vector3.RIGHT
var name:=""
var failures: Array[String]=[]
var frames: Array[Dictionary]=[]
var cases: Array[Dictionary]=[]
var clips: Array[Dictionary]=[]
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
func tick(count: int=1) -> void:
 for i in range(count):
  await physics_frame
  var e:=InputEventMouseMotion.new();e.position=game.camera.unproject_position(game.player.position+face*5);root.push_input(e,true)
  game.tick(STEP)
func rmb(down: bool) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=down;e.position=game.camera.unproject_position(game.player.position+face*4);root.push_input(e,true)
func equip(id: String,hand: String) -> void:
 var source: Dictionary={};var index: int=game.loadout.bag.find(id)
 if index>=0:source={"kind":"bag","index":index}
 else:
  for i in range(2):
   for slot in ["main","off"]:
    if game.loadout.sets[i][slot]==id:source={"kind":"slot","set":i,"hand":slot}
 var target:={"kind":"slot","set":0,"hand":hand}
 if source!=target:check(game.loadout.move_item(source,target),"fixture equipment")
func shot(mark: String) -> Dictionary:
 await process_frame;await RenderingServer.frame_post_draw
 var file:=name+"-"+mark+".png";root.get_texture().get_image().save_png(output.path_join(file))
 var row:={"case":name,"mark":mark,"file":file,"health":game.health,"parries":game.readiness.parries,"clashes":game.fx.clashes.size(),"point":game.fx.last_clash,"age":game.fx.clashes[0].age if not game.fx.clashes.is_empty() else -1}
 frames.append(row);return row
func episode(main: String,off: String,facing: String,direction: Vector3,perfect: bool=true) -> void:
 name=("parry-" if perfect else "guard-")+main+"_"+(off if off!="" else "solo")+"-"+facing;face=direction
 game.loadout.defaults();game.loadout.unequip({"kind":"slot","set":0,"hand":"off"});equip(main,"main")
 if off!="":equip(off,"off")
 game.loadout_edited();game.start_parry_drill();var enemy=game.enemies[0];enemy.position=game.player.position+face*1.2
 await tick(24);await process_frame
 if not perfect:rmb(true)
 var before: int=game.fx.clash_count
 for i in range(400):
  await tick()
  if enemy.state=="windup" and enemy.telegraph_left<=.10:
   if perfect:rmb(true)
   break
 for i in range(40):
  await tick()
  if game.readiness.parries>0 or game.readiness.blocks>0:break
 check((game.readiness.parries==1 and game.health==100) if perfect else (game.readiness.blocks==1 and game.health==97),"real AI defense")
 check(game.fx.clash_count==before+1 and game.fx.clashes.size()==1,"one clash at successful contact")
 var expected: Vector3=game.player.position+face*.8+Vector3.UP*.85
 check(game.fx.last_clash.distance_to(expected)<.01,"directional defense contact")
 check(game.fx.clashes[0].perfect==perfect,"actual defense tier")
 await shot("flash")
 var record: bool=facing=="right" and main in ["sword0","greatsword0","mace0"] and off==""
 for i in range(24):
  if record:clips.append(await shot("frame-%02d"%i))
  await tick(2)
  if i==4:await shot("sparks")
 check(game.fx.clashes.is_empty(),"effect cleans up within0.4s")
 await shot("clear");rmb(false);cases.append({"case":name,"point":game.fx.last_clash})
func run() -> void:
 if output=="" or DisplayServer.get_name()=="headless":quit(1);return
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
 DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 for setup in [["sword0",""],["greatsword0",""],["mace0",""]]:
  for entry in [["front",Vector3.BACK],["back",Vector3.FORWARD],["left",Vector3.LEFT],["right",Vector3.RIGHT]]:
   for perfect in [true,false]:await episode(setup[0],setup[1],entry[0],entry[1],perfect)
 var file:=FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"cases":cases,"frames":frames,"clips":clips,"failures":failures,"native_no_focus":safe,"physics_hz":120,"clip_fps":60,"input":"actual viewport mouse/RMB; real drill AI; inventory API; no supplied damage, parry or effect"},"\t"));file.close()
 game.queue_free();await process_frame
 print("CLASH NATIVE: ",cases.size()," cases / ",frames.size()," views incl.",clips.size()," clip frames; failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
