extends SceneTree
## Controlled attack fixtures; native rendering and game-clock progression.
## No user focus, no guides, fixed inspection camera and 30fps image sequences.
## Camera follow is deliberately outside this controlled fixture's scope.
const STEP:=1.0/120
const FPS:=30
var game
var output:=""
var safe:=false
var failures: Array[String]=[]
var frames: Array[Dictionary]=[]
var clips: Array[Dictionary]=[]
var current_case:=""
var fixture_kind:=""
var tick_index:=0
var hold_idle:=false
func _initialize() -> void:
 root.unfocusable=true;Engine.physics_ticks_per_second=120
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func _process(_delta: float) -> bool:
 if safe and (not root.unfocusable or not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS) or DisplayServer.window_get_position()!=Vector2i(20000,20000)):
  printerr("QC window safety invariant lost");quit(1)
 return false
func check(ok: bool,why: String) -> void:
 if not ok:failures.append(current_case+": "+why);printerr("FAIL: ",current_case+": "+why)
func v3(v: Vector3) -> Array:return [v.x,v.y,v.z]
func v2(v: Vector2) -> Array:return [v.x,v.y]
func actor():return game.enemies[0] if not game.enemies.is_empty() else null
func point_camera(at: Vector3) -> void:
 game._camera_focus=at;game.camera.position=at+game.CAMERA_OFFSET;game.camera.look_at(at)
func aim_at_actor() -> void:
 var e=actor()
 if is_instance_valid(e):
  var direction: Vector3=e.position-game.player.position;direction.y=0
  game.test_aim=direction.normalized()
  var motion:=InputEventMouseMotion.new();motion.position=game.camera.unproject_position(e.position);root.push_input(motion,true)
func advance(count: int=1) -> void:
 for i in range(count):
  await physics_frame;aim_at_actor();game.tick(STEP);point_camera(Vector3.ZERO);game.vision.update_view(0);tick_index+=1
  var e=actor()
  if hold_idle and is_instance_valid(e) and e.state=="chase":e.cooldown=999
func button(which: int,down: bool) -> void:
 var event:=InputEventMouseButton.new();event.button_index=which;event.pressed=down;event.position=game._mouse_position;root.push_input(event,true);Input.flush_buffered_events()
func key(code: int) -> void:
 for down in [true,false]:
  var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=down;root.push_input(event,true);Input.flush_buffered_events()
func find_button(node: Node,text: String) -> Button:
 if node is Button and node.text==text:return node
 for child in node.get_children():
  var found: Button=find_button(child,text)
  if found!=null:return found
 return null
func click_ui(control: Button) -> void:
 check(control!=null,"menu button exists")
 if control==null:return
 await process_frame
 var at: Vector2=control.get_global_rect().get_center()
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=at;root.push_input(event,true);Input.flush_buffered_events()
 await process_frame
func fresh() -> void:
 button(MOUSE_BUTTON_RIGHT,false);button(MOUSE_BUTTON_LEFT,false)
 game.loadout.defaults();game.loadout.unequip({"kind":"slot","set":0,"hand":"off"});game.loadout.save_path="";game.loadout_edited();game.start_captain();game.debug_range=false
 game.move_input=Vector2.ZERO;game.stats.reset_modifiers();game.stats.flat.critical_chance=-.05
 game.fx.clear_transients();tick_index=0;hold_idle=false
func prepare(id: String,angle: float,distance: float=3.5) -> void:
 fresh();var e=actor();e.position=Vector3(0,.03,0)
 game.player.position=e.position+Vector3(cos(angle),0,sin(angle))*distance
 point_camera(Vector3.ZERO);aim_at_actor()
 e.attack_data=e.Rules.definition(id);e.attack_angle=angle;e.state="windup";e.telegraph_left=e.attack_data.windup;e.cooldown=0;e.attack_hit=false;e.elapsed=0
 e.sprite.flip_h=e.view_right.dot(Vector3(cos(angle),0,sin(angle)))<0
 e.tick(.00000001,game);game.vision.update_view(0)
func geometry_record(e) -> Dictionary:
 if not is_instance_valid(e):return {}
 var view=e.captain_view
 var pose: Dictionary=e.Pose.sample(e.attack_data,e.state,e.telegraph_left,e.elapsed,e.cooldown,e.attack_angle)
 return {"state":e.state,"attack":e.attack_data.get("id",""),"elapsed":e.elapsed,"telegraph_left":e.telegraph_left,"cooldown":e.cooldown,"animation":e.sprite.animation,"frame":e.sprite.frame,"beat":pose.beat,"flip_h":e.sprite.flip_h,"attack_angle":e.attack_angle,"forward":v3(Vector3(cos(e.attack_angle),0,sin(e.attack_angle))),"position":v3(e.global_position),"screen_position":v2(game.camera.unproject_position(e.global_position)),"anchor":v3(view.anchor.global_position),"anchor_screen":v2(game.camera.unproject_position(view.anchor.global_position)),"ring":v3(view.anchor_ring_world()),"ring_screen":v2(game.camera.unproject_position(view.anchor_ring_world())),"hand":v3(e.chain_wrist()),"hand_screen":v2(game.camera.unproject_position(e.chain_wrist())),"chain_start":v3(view.chain_start),"chain_end":v3(view.chain_end),"ground_tip":v3(view.ground_tip),"chain_links":view.chain_links,"anchor_visible":view.anchor.visible,"actor_visible":e.visible,"actor_mask":game.vision.material.get_shader_parameter("actor_enabled"),"weapon_mask":game.vision.material.get_shader_parameter("weapon_enabled"),"health":e.health,"arm_cut":e.arm_cut,"contacts":e.contact_count,"landed":e.landed_count,"anchor_head":v2(Vector2((-view.anchor.global_basis.y).dot(game.camera.global_basis.x),(-view.anchor.global_basis.y).dot(game.camera.global_basis.y))),"ring_error":view.chain_end.distance_to(view.anchor_ring_world()),"guides":view.fill.get_surface_count(),"damaging":not e.attack_data.is_empty() and e.state=="attack" and e.Rules.damaging(e.attack_data,e.elapsed)}
func shot(mark: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 var directory:=output.path_join(current_case);DirAccess.make_dir_recursive_absolute(directory)
 var file:=current_case+"/"+mark+".png"
 check(root.get_texture().get_image().save_png(output.path_join(file))==OK,"save "+file)
 var record:={"case":current_case,"fixture":fixture_kind,"camera_fixture":"fixed inspection focus at world zero; camera follow untested","file":file,"tick":tick_index,"time":tick_index*STEP,"fps":FPS,"player":v3(game.player.position),"player_health":game.health,"mode":game.mode,"debug_range":game.debug_range,"camera_position":v3(game.camera.global_position),"camera_right":v3(game.camera.global_basis.x),"camera_up":v3(game.camera.global_basis.y),"camera_size":game.camera.size,"test_aim":v3(game.test_aim),"captain":geometry_record(actor())}
 frames.append(record)
 var metadata:=FileAccess.open(output.path_join(current_case+"/"+mark+".json"),FileAccess.WRITE);metadata.store_string(JSON.stringify(record,"\t"));metadata.close()
 if is_instance_valid(actor()):
  check(actor().captain_view.fill.get_surface_count()==0,"no ground guides")
  if not actor().dead:check(actor().captain_view.chain_end.distance_to(actor().captain_view.anchor_ring_world())<.00001,"exact rotated ring endpoint")
func manifest() -> void:
 var file:=FileAccess.open(output.path_join("capture-manifest.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"native_no_focus":safe,"viewport":[1280,800],"fps":FPS,"clips":clips,"frames":frames,"failures":failures},"\t"));file.close()
func timeline(id: String,left: bool) -> void:
 current_case="timeline-"+id+("-left" if left else "-right");fixture_kind="controlled attack start; subsequent real game ticks; next AI attack suppressed after recovery"
 prepare(id,PI if left else 0.0);hold_idle=true
 var spec: Dictionary=actor().attack_data.duplicate();var seconds: float=spec.windup+spec.active+spec.recovery+.4
 var count:=ceili(seconds*FPS)+1;var start:=frames.size()
 for i in range(count):
  await shot("%04d"%i)
  if i<count-1:await advance(4)
 check(is_instance_valid(actor()) and actor().state=="chase","timeline reaches idle after recovery")
 clips.append({"case":current_case,"kind":"timeline","fps":FPS,"frames":count,"first_record":start,"duration":float(count-1)/FPS,"attack_definition":str(spec)})
 manifest()
func orientation_stills() -> void:
 fixture_kind="controlled phase and angle fixture; no claim of natural AI selection"
 for id in ["sweep","throw","slam"]:
  for i in range(8):
   var angle:=TAU*i/8
   for phase in ["windup75","active50"]:
    current_case="orientation-"+id+"-%03d-"%roundi(rad_to_deg(angle))+phase
    prepare(id,angle);var e=actor()
    if phase=="windup75":e.telegraph_left=float(e.attack_data.windup)*.25
    else:
     e.state="attack";e.elapsed=float(e.attack_data.active)*.5;e.active_left=float(e.attack_data.active)-e.elapsed
     if id=="throw":e.configure_throw_launch()
     e.last_tip=e.position+e.Rules.tip(e.attack_data,e.attack_angle,e.elapsed)
    e.tick(.00000001,game);game.vision.update_view(0);await shot("still")
 manifest()
func actual_melee_cut() -> void:
 current_case="actual-melee-cut";fixture_kind="actual LMB hit routing, fixed idle Captain geometry fixture; fixed inspection camera"
 fresh();var e=actor();e.position=Vector3(0,.03,0);e.state="recover";e.cooldown=999;e.stagger=999;e.sprite.flip_h=false;e.attack_angle=0;game.player.position=Vector3(-.85,.03,.10);point_camera(Vector3.ZERO);await advance(10);await shot("before")
 for i in range(12):
  if e.arm_cut:break
  aim_at_actor();button(MOUSE_BUTTON_LEFT,true);button(MOUSE_BUTTON_LEFT,false);await advance(115)
 check(e.arm_cut and e.health>0,"actual LMB sharp attacks sever arm without kill");await shot("after")
func lifecycle() -> void:
 current_case="parry-rmb";fixture_kind="controlled sweep start; actual RMB inside 0.15s parry window"
 prepare("sweep",PI,1.9);await advance(137);button(MOUSE_BUTTON_RIGHT,true);await advance(20)
 check(game.readiness.parries==1 and game.health==100 and actor().state=="parried","actual RMB parry interrupts");await shot("clash");button(MOUSE_BUTTON_RIGHT,false);await advance(36);await shot("settled")
 current_case="cut-handoff";fixture_kind="controlled sever callback; validates visual lifecycle, not actual melee hit routing"
 prepare("throw",0);await advance(222);await shot("before");var e=actor();check(e.register_melee_contact("chain_arm",108,"sword"),"sever callback")
 for i in range(9):await advance(4);await shot("handoff-%02d"%i)
 check(e.arm_cut and e.attack_data.is_empty() and e.state=="recover","cut cancels throw")
 current_case="death-replay";fixture_kind="controlled lethal damage callback; actual T replay input"
 e.receive_damage(10000,Vector3.ZERO);await advance(1);await shot("death-start");await advance(30);await shot("death-fade");await advance(100);check(game.mode=="victory","victory transition");await shot("victory")
 key(KEY_T);await advance(2);check(game.encounter_mode=="captain" and is_instance_valid(actor()) and not actor().arm_cut and actor().health==680,"T creates fresh Captain");await shot("replay")
 manifest()
func run() -> void:
 if output=="" or DisplayServer.get_name()=="headless":printerr("Requires native renderer and --output=<absolute path>");quit(1);return
 root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(1280,800);root.size=Vector2i(1280,800)
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
 DirAccess.make_dir_recursive_absolute(output)
 game=load("res://scenes/game.tscn").instantiate();root.add_child(game);game.set_physics_process(false);game.loadout.save_path=""
 current_case="menu-entry";fixture_kind="actual menu pointer input";await click_ui(find_button(game.ui,"ท่าเรือ • นายท้ายผู้ลากสมอ"));check(game.encounter_mode=="captain","actual Captain menu entry");await advance(20);await shot("arena")
 for id in ["sweep","throw","slam"]:
  for left in [false,true]:await timeline(id,left)
 await orientation_stills();await actual_melee_cut();await lifecycle()
 button(MOUSE_BUTTON_RIGHT,false);button(MOUSE_BUTTON_LEFT,false);manifest();game.queue_free();await process_frame;await process_frame
 print("CAPTAIN QC NATIVE: ",frames.size()," images, ",clips.size()," clips, failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
