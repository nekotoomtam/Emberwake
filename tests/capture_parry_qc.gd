extends SceneTree
const STEP:=1.0/120
var game
var output:=""
var safe:=false
var name:=""
var face:=Vector3.RIGHT
var frames: Array[Dictionary]=[]
var clips: Array[Dictionary]=[]
var cases: Array[Dictionary]=[]
var failures: Array[String]=[]
var checks:=0
var smoke:=false
func _initialize() -> void:
 root.unfocusable=true;Engine.physics_ticks_per_second=120
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 smoke="--smoke" in OS.get_cmdline_user_args();call_deferred("run")
func _process(_delta: float) -> bool:
 if safe and (not root.unfocusable or DisplayServer.window_get_position()!=Vector2i(20000,20000)):quit(1)
 return false
func check(ok: bool,why: String) -> void:
 checks+=1
 if not ok:failures.append(name+": "+why);printerr("FAIL: ",name+": "+why)
func rmb(down: bool) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=down;e.position=game.camera.unproject_position(game.player.position+face*4);root.push_input(e,true)
func key(code: Key,down: bool) -> void:
 var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;Input.parse_input_event(e)
func tick(count: int=1) -> void:
 for i in range(count):
  await physics_frame
  var e:=InputEventMouseMotion.new();e.position=game.camera.unproject_position(game.player.position+face*5);root.push_input(e,true)
  game.tick(STEP)
func shot(mark: String,enemy) -> Dictionary:
 await process_frame;await RenderingServer.frame_post_draw
 var file:=name+"-"+mark+".png";root.get_texture().get_image().save_png(output.path_join(file))
 var row:={"case":name,"mark":mark,"file":file,"health":game.health,"stamina":game.stamina,"parries":game.readiness.parries,"blocks":game.readiness.blocks,"held":game.readiness.held,"action":game.right_action(),"aim":game.aim,"primary":game.primary_family(),"window":game.readiness.parry_left,"enemy_state":enemy.state,"windup_left":enemy.telegraph_left,"data":enemy.attack_data.duplicate(),"angle":enemy.attack_angle}
 frames.append(row);return row
func episode(kind: String,facing: String,forward: Vector3,outcome: String) -> void:
 name=kind+"-"+facing+"-"+outcome;face=forward
 game.loadout.defaults();game.loadout_edited();game.start_parry_drill(kind)
 var enemy=game.enemies[0];enemy.position=game.player.position+face*(3.2 if kind=="ranged" else 1.2)
 if outcome=="red":enemy.attack_index=1 if kind=="elite" else 2
 await tick(24);await process_frame
 if outcome=="early":
  rmb(true);check(game.readiness.held,"early RMB press accepted by viewport")
 var armed:=outcome=="early"
 var windup_saved:=false;var resolved:=false;var result_saved:=false;var attack_seen:=false
 var clip_ticks:=-1
 var record: bool=facing=="right" and ((kind=="melee" and outcome in ["perfect","early"]) or (kind=="ranged" and outcome=="perfect") or (kind=="elite" and outcome=="red"))
 var move_key: Key=KEY_NONE
 var data: Dictionary={}
 for i in range(700):
  await tick()
  if enemy.state=="attack" or not game.projectiles.is_empty():attack_seen=true
  if enemy.state=="windup" and not windup_saved:
   windup_saved=true;data=enemy.attack_data.duplicate();await shot("windup",enemy)
   if record:clip_ticks=0
  if not armed and outcome in ["perfect","red"]:
   var due: bool=enemy.state=="windup" and enemy.telegraph_left<=.10 if kind!="ranged" else false
   if kind=="ranged" and not game.projectiles.is_empty():due=game.projectiles[0].node.position.distance_to(game.player.position+Vector3.UP*.6)<=.95
   if due:
    await shot("cue",enemy);rmb(true);armed=true
  if outcome=="late" and not armed and game.health<100:rmb(true);armed=true
  if outcome=="evade" and not armed and enemy.state=="windup" and enemy.telegraph_left<=(.45 if kind=="elite" else .25):
   var travel:=Vector3(-face.z,0,face.x) if kind=="ranged" else -face
   move_key=KEY_D if travel.x>.5 else (KEY_A if travel.x<-.5 else (KEY_S if travel.z>.5 else KEY_W))
   key(move_key,true);await process_frame;armed=true
  if windup_saved and not resolved:
   if outcome=="perfect":resolved=game.readiness.parries>0
   elif outcome in ["early","red","late"]:resolved=game.health<100 and armed
   else:resolved=attack_seen and enemy.state!="attack" and game.projectiles.is_empty()
   if resolved:await shot("impact",enemy);result_saved=true
  if record and clip_ticks>=0:
   if clip_ticks%4==0:clips.append(await shot("frame-%03d"%(clip_ticks/4),enemy))
   clip_ticks+=1
  if resolved and (not record or clip_ticks>=180):break
 check(windup_saved and resolved and result_saved,"real attack resolves expected scenario")
 if outcome=="perfect":check(game.health==100 and game.readiness.parries==1,"timed parry, no damage, one edge")
 elif outcome in ["early","red"]:
  check(game.readiness.parries==0 and game.readiness.blocks>=1,"ordinary guard / red cannot parry")
  check(absf(game.health-(100-float(data.get("damage",0))*.3))<.01,"guard reduction retained")
 elif outcome=="late":check(game.readiness.parries==0 and game.health<100,"late press never undoes damage")
 else:check(game.health==100,"out of footprint/flight lane avoids hit")
 if outcome=="red":check(not data.get("parryable",true),"red metadata matches visual/impact")
 if move_key!=KEY_NONE:key(move_key,false);await process_frame
 rmb(false);await tick(24);await shot("return",enemy)
 cases.append({"case":name,"kind":kind,"facing":facing,"outcome":outcome,"data":data,"health":game.health,"parries":game.readiness.parries,"blocks":game.readiness.blocks})
func run() -> void:
 if output=="" or DisplayServer.get_name()=="headless":quit(1);return
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
 DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 for kind in ["melee","ranged","elite"]:
  var facings: Array=[["front",Vector3.BACK],["back",Vector3.FORWARD],["left",Vector3.LEFT],["right",Vector3.RIGHT]]
  if smoke:facings=[["right",Vector3.RIGHT]]
  for entry in facings:
   for outcome in ["perfect","early","red","late","evade"]:await episode(kind,entry[0],entry[1],outcome)
 var file:=FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"cases":cases,"frames":frames,"clips":clips,"checks":checks,"failures":failures,"native_no_focus":safe,"physics_hz":120,"clip_fps":30,"input":"actual viewport mouse aim/RMB and parsed WASD; real drill AI and projectiles; initial attack-pattern index chooses normal/red; no supplied attack pose, damage, stagger or parry window"},"\t"));file.close()
 game.queue_free();await process_frame
 print("PARRY NATIVE: ",cases.size()," cases / ",frames.size()," views incl.",clips.size()," clip frames; ",checks," checks; failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
