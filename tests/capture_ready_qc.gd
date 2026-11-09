extends SceneTree
const STEP:=1.0/120
var game
var output:=""
var safe:=false
var name:=""
var face:=Vector3.RIGHT
var failures: Array[String]=[]
var cases: Array[Dictionary]=[]
var frames: Array[Dictionary]=[]
var clip: Array[Dictionary]=[]
var checks:=0
var smoke:=false
func _initialize() -> void:
 root.unfocusable=true;Engine.physics_ticks_per_second=120
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 smoke="--smoke" in OS.get_cmdline_user_args()
 call_deferred("run")
func _process(_delta: float) -> bool:
 if safe and (not root.unfocusable or DisplayServer.window_get_position()!=Vector2i(20000,20000)):quit(1)
 return false
func check(ok: bool,why: String) -> void:
 checks+=1
 if not ok:failures.append(name+": "+why);printerr("FAIL: ",name+": "+why)
func mouse(button: MouseButton,down: bool) -> void:
 var e:=InputEventMouseButton.new();e.button_index=button;e.pressed=down;e.position=game.camera.unproject_position(game.player.position+face*4);root.push_input(e,true)
func key(code: Key,down: bool) -> void:
 var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down
 if code==KEY_SPACE:root.push_input(e,true)
 else:Input.parse_input_event(e)
func tick(count: int=1) -> void:
 for i in range(count):
  await physics_frame
  var e:=InputEventMouseMotion.new();e.position=game.camera.unproject_position(game.player.position+face*5);root.push_input(e,true)
  game.tick(STEP)
  if game._uses_dual_hands():
   for hand in range(2):check(game.dual_visual.rigs[hand].grip_visual.shoulder_world.distance_to(game.avatar.paired_shoulders()[hand])<.00001,"hand stays on animated shoulder")
func equip(id: String,hand: String) -> void:
 var source: Dictionary={};var index: int=game.loadout.bag.find(id)
 if index>=0:source={"kind":"bag","index":index}
 else:
  for i in range(2):
   for slot in ["main","off"]:
    if game.loadout.sets[i][slot]==id:source={"kind":"slot","set":i,"hand":slot}
 var target:={"kind":"slot","set":0,"hand":hand}
 if source!=target:check(game.loadout.move_item(source,target),"fixture equip")
func fixture(main: String,off: String) -> void:
 game.loadout.defaults();game.loadout.unequip({"kind":"slot","set":0,"hand":"off"});equip(main,"main")
 if off!="":equip(off,"off")
 game.loadout_edited();game.start_run(true)
 for enemy in game.enemies:enemy.position=Vector3(100,.03,100)
func shot(mark: String) -> Dictionary:
 await process_frame;await RenderingServer.frame_post_draw
 var filename:=name+"-"+mark+".png";root.get_texture().get_image().save_png(output.path_join(filename))
 var row:={"case":name,"mark":mark,"file":filename,"main_family":game.primary_family(),"active_item":game.active_item,"action":game.right_action(),"health":game.health,"stamina":game.stamina,"blocks":game.readiness.blocks,"breaks":game.readiness.breaks,"aim_start":game.ready_visual.center_start,"aim_end":game.ready_visual.center_end}
 frames.append(row);return row
func episode(main: String,off: String,facing: String,forward: Vector3) -> void:
 name=main+"_"+(off if off!="" else "solo")+"-"+facing;face=forward;fixture(main,off);await tick(12)
 mouse(MOUSE_BUTTON_RIGHT,true);await tick(36)
 var family: String=game.primary_family()
 var expected: String="aim" if family in ["pistol","rifle"] else ("guard" if family in ["sword","greatsword","mace"] else "")
 check(game.right_action()==expected,"primary RMB mode");check(game.ready_visual.line_visible==(expected=="aim"),"aim trajectory visibility")
 await shot("ready")
 var code: Key=KEY_D if face.x>.5 else (KEY_A if face.x<-.5 else (KEY_S if face.z>.5 else KEY_W))
 key(code,true);await process_frame;await tick(12)
 var speed: float=Vector2(game.player.velocity.x,game.player.velocity.z).length()
 check(absf(speed-(2.585 if expected=="aim" else (2.115 if expected=="guard" else 4.7)))<.01,"stance movement speed")
 await shot("walk");key(code,false);await process_frame;await tick(4)
 mouse(MOUSE_BUTTON_LEFT,true);mouse(MOUSE_BUTTON_LEFT,false)
 if expected=="guard":
  check(not game.motion.busy,"guard blocks simultaneous attack")
  var enemy=game.spawn_enemy("melee",game.player.position+face*1.1)
  for i in range(200):
   await tick()
   if game.readiness.blocks>0:break
  check(game.readiness.blocks>0 and game.health>=96.99 and game.health<100,"real AI frontal impact blocked: hp="+str(game.health)+" blocks="+str(game.readiness.blocks)+" state="+enemy.state+" dist="+str(enemy.position.distance_to(game.player.position))+" action="+game.right_action()+" cd="+str(enemy.cooldown)+" wind="+str(enemy.telegraph_left)+" clock="+str(enemy.clock))
  await shot("block");enemy.position=Vector3(100,.03,100)
  if main=="sword0" and off=="pistol0":
   game.stamina=1
   var elite=game.spawn_enemy("elite",game.player.position+face*1.8)
   for i in range(240):
    await tick()
    if game.readiness.breaks>0:break
   check(game.readiness.breaks>0 and game.readiness.broken_left>0,"real elite breaks depleted guard")
   await shot("break");elite.position=Vector3(100,.03,100)
   await tick(90)
 else:
  var first:=true
  for i in range(200):
   await tick()
   if first and game.staff_flight.shots_fired>0:
    first=false;await shot("fire");break
  check(not first,"actual aimed/fire projectile released")
 mouse(MOUSE_BUTTON_RIGHT,false);await tick(2)
 check(game.right_action()=="" and not game.ready_visual.line_visible,"release clears line and stance")
 while game.stamina<31:await tick()
 mouse(MOUSE_BUTTON_RIGHT,true);await tick()
 key(KEY_SPACE,true);key(KEY_SPACE,false);await tick()
 check(game._dodge_left>0 and not game.readiness.held and game.right_action()=="","Space overrides RMB and in-flight action")
 await shot("dodge");await tick(36);await shot("return")
 cases.append({"case":name,"expected":expected})
func cover_case() -> void:
 name="rifle-cover";face=Vector3.RIGHT;fixture("rifle0","")
 var wall:=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.35,1.5,2);shape.shape=box;wall.add_child(shape)
 var art:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=box.size;art.mesh=mesh;wall.add_child(art)
 wall.position=game.player.position+Vector3(3,.75,0);root.add_child(wall)
 await tick(12);mouse(MOUSE_BUTTON_RIGHT,true);await tick(36)
 check(game.ready_visual.center_end.x<3 and game.ready_visual.center_end.x>2.5,"aim line stops at actual cover")
 await shot("clip");mouse(MOUSE_BUTTON_LEFT,true);mouse(MOUSE_BUTTON_LEFT,false)
 await tick(70);check(not game.staff_flight.resolved.is_empty(),"actual bullet resolves on cover")
 await shot("impact");wall.queue_free();mouse(MOUSE_BUTTON_RIGHT,false);await tick(2)
func close_cover_case() -> void:
 name="pistol-close-cover";face=Vector3.RIGHT;fixture("pistol0","")
 var wall:=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.06,1.5,2);shape.shape=box;wall.add_child(shape)
 var art:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=box.size;art.mesh=mesh;wall.add_child(art)
 wall.position=game.player.position+Vector3(.38,.75,0);root.add_child(wall)
 await tick(12);mouse(MOUSE_BUTTON_RIGHT,true);await tick(36)
 mouse(MOUSE_BUTTON_LEFT,true);mouse(MOUSE_BUTTON_LEFT,false)
 for wait in range(60):
  await tick()
  if game.staff_flight.shots_fired>0:break
 check(game.staff_flight.shots_fired==1 and game.ready_visual.center_end.x<.36,"close-cover line checks actual launch segment even with grip beyond wall")
 await shot("clip");mouse(MOUSE_BUTTON_RIGHT,false);wall.queue_free();await tick(2)
func clips() -> void:
 for setup in [["pistol0","","aim"],["rifle0","","aim"],["sword0","pistol0","guard"],["pistol0","sword0","aim"]]:
  name=setup[0]+"_"+(setup[1] if setup[1]!="" else "solo")+"-clip";face=Vector3.RIGHT;fixture(setup[0],setup[1]);await tick(12)
  for i in range(42):
   if i==4:mouse(MOUSE_BUTTON_RIGHT,true)
   if i==14:mouse(MOUSE_BUTTON_LEFT,true);mouse(MOUSE_BUTTON_LEFT,false)
   if i==32:mouse(MOUSE_BUTTON_RIGHT,false)
   await tick(4);clip.append(await shot("frame-%02d"%i))
func run() -> void:
 if output=="" or DisplayServer.get_name()=="headless":quit(1);return
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);root.mode=Window.MODE_WINDOWED;DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
 DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 var setups: Array=[]
 for family in ["sword","greatsword","mace","staff","pistol","rifle"]:setups.append([family+"0",""])
 for a in ["sword","mace","pistol"]:
  for b in ["sword","mace","pistol"]:setups.append([a+"0",b+("1" if a==b else "0")])
 if smoke:setups=[["sword0",""]]
 for setup in setups:
  for entry in [["front",Vector3.BACK],["back",Vector3.FORWARD],["left",Vector3.LEFT],["right",Vector3.RIGHT]]:await episode(setup[0],setup[1],entry[0],entry[1])
 if not smoke:await cover_case();await close_cover_case();await clips()
 var file:=FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"cases":cases,"frames":frames,"clip":clip,"checks":checks,"failures":failures,"native_no_focus":safe,"physics_hz":120,"clip_fps":30,"input":"actual viewport mouse aim/RMB/LMB/Space; parsed WASD; inventory API fixture; real hostile AI; depleted stamina fixture for break; actual cover collider"},"\t"));file.close()
 game.queue_free();await process_frame
 print("READY NATIVE: ",cases.size()," cases / ",frames.size()," views incl.",clip.size()," clip frames; ",checks," checks; failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
