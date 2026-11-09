extends SceneTree
var game
var target
var output:=""
var failures: Array=[]
var captures: Array=[]
var checks:=0
var safe:=false
const STEP:=1.0/120.0
const DIRECTIONS:={"right":Vector3.RIGHT,"left":Vector3.LEFT,"front":Vector3.BACK,"back":Vector3.FORWARD}
func _initialize() -> void:
	root.unfocusable=true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	call_deferred("run")
func _process(_delta: float) -> bool:
	if safe and (not root.unfocusable or not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS) or DisplayServer.window_get_position()!=Vector2i(20000,20000)):
		printerr("FAIL native window safety");quit(1)
	return false
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL: ",label)
func key(code: int) -> void:
	for pressed in [true,false]:
		var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed;root.push_input(event,true)
	Input.flush_buffered_events()
func mouse(button: int,pressed: bool,position_: Vector2=Vector2.ZERO) -> void:
	var event:=InputEventMouseButton.new();event.button_index=button;event.pressed=pressed;event.position=position_;root.push_input(event,true);Input.flush_buffered_events()
func update_camera() -> void:
	var focus: Vector3=target.position if is_instance_valid(target) else game.player.position
	game._camera_focus=focus;game._shake=0;game.camera.position=focus+game.CAMERA_OFFSET;game.camera.look_at(focus)
	if is_instance_valid(target):game.test_aim=(target.position-game.player.position).normalized()
	game.vision.update_view(0)
func advance(duration: float) -> void:
	var remaining:=duration
	while remaining>.000001:
		await physics_frame
		var dt:=minf(STEP,remaining);game.tick(dt);remaining-=dt;update_camera()
func shot(label: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,"capture "+label)
	var meta:={"label":label,"mode":game.mode,"health":game.health,"fixture":"controlled placement/timing; actual runtime", "stamina":game.stamina}
	if is_instance_valid(target):meta.merge({"view":target.brinehound_direction(),"phase":target.phase,"animation":target.sprite.animation,"frame":target.sprite.frame,"contacts":target.contact_count,"attempts":target.bite_attempts,"enemy_hp":target.health,"enemy_position":[target.position.x,target.position.y,target.position.z],"no_mirror":not target.sprite.flip_h})
	var f:=FileAccess.open(output+"/"+label+".json",FileAccess.WRITE);f.store_string(JSON.stringify(meta,"\t"));f.close();captures.append(meta)
func fresh(view: String,distance: float=2.0) -> void:
	mouse(MOUSE_BUTTON_RIGHT,false);mouse(MOUSE_BUTTON_LEFT,false)
	game.start_brinehound_trial();target=game.enemies[0];target.cooldown=0
	target.position=Vector3(0,.03,0);target.home_position=target.position;game.player.position=target.position+DIRECTIONS[view]*distance
	game.test_aim=-DIRECTIONS[view];game.move_input=Vector2.ZERO;update_camera();await physics_frame;await physics_frame
func run() -> void:
	check(not output.is_empty(),"output specified");DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
	game=load("res://scenes/game.tscn").instantiate();game.loadout.save_path="";root.add_child(game);game.set_physics_process(false)
	game.stats=game.stats.duplicate();game.stats.flat.critical_chance=-1.0
	await process_frame;await process_frame;await shot("menu")
	var entry=game.ui.buttons.get_child(0);check(entry.text.contains("หมาน้ำเค็ม"),"first menu offers dog trial")
	var at: Vector2=entry.get_global_rect().get_center();var motion:=InputEventMouseMotion.new();motion.position=at;root.push_input(motion,true)
	mouse(MOUSE_BUTTON_LEFT,true,at);mouse(MOUSE_BUTTON_LEFT,false,at);await process_frame
	check(game.mode=="practice" and game.drill_kind=="brinehound","actual viewport entry")
	target=game.enemies[0];update_camera();await shot("trial-entry")
	for view: String in ["left","front","back","right"]:
		await fresh(view,4);var before: Vector3=target.position;await advance(.22)
		check(target.position.distance_to(before)>.55 and target.position.distance_to(before)<.75,view+" actual fast run")
		check(target.sprite.animation==view+"_run" and not target.sprite.flip_h,view+" actual four-view run")
		await shot(view+"-run")
		await fresh(view);before=target.position;await advance(.30)
		check(target.phase==0 and target.position.distance_to(before)<.01 and game.health==100,view+" crouch stationary harmless")
		await shot(view+"-crouch");await advance(.22)
		check(target.phase==1 and target.position.distance_to(before)>.25 and game.health==100,view+" physical pounce no early damage")
		await shot(view+"-pounce");await advance(.10)
		check(target.phase==2 and target.contact_count==1 and game.health==89,view+" first11 damage once")
		await shot(view+"-bite1");var landed: Vector3=target.position;await advance(.24)
		check(target.phase==3 and game.health==89,view+" separate second warning")
		await shot(view+"-recoil");await advance(.30)
		check(target.phase==4 and target.contact_count==2 and game.health==81,view+" second8 damage once")
		check(target.position.distance_to(landed)<.01,view+" grounded followup")
		await shot(view+"-bite2");await advance(.25)
		check(target.phase==5 and game.health==81,view+" harmless recovery")
		await shot(view+"-recover")
	await fresh("right");await advance(.54);mouse(MOUSE_BUTTON_RIGHT,true);await advance(.10)
	check(game.health==100 and game.readiness.parries==1 and target.phase<0,"actual first RMB parry cancels both")
	await shot("actual-parry1");await advance(.65);check(game.health==100,"parry cancels followup")
	await fresh("left");await advance(1.07);mouse(MOUSE_BUTTON_RIGHT,true);await advance(.12)
	check(game.health==89 and game.readiness.parries==1 and target.state=="parried","actual second RMB parry")
	await shot("actual-parry2")
	await fresh("front");mouse(MOUSE_BUTTON_RIGHT,true);await advance(1.30)
	check(game.health>81 and game.health<100 and game.readiness.parries==0,"actual held guard both bites")
	await shot("actual-guard")
	await fresh("back");await advance(.54);key(KEY_SPACE);await advance(.12)
	check(game.health==100 and game.rewards.refunded,"actual first SPACE dodge")
	await shot("actual-dodge1")
	await fresh("front");await advance(1.07);key(KEY_SPACE);await advance(.12)
	check(game.health==89 and game.rewards.refunded,"actual second SPACE dodge")
	await shot("actual-dodge2")
	await fresh("right",.7);target.cooldown=20;var hp: float=target.health
	mouse(MOUSE_BUTTON_LEFT,true,game.camera.unproject_position(target.position+Vector3.UP*.6));await advance(.70);mouse(MOUSE_BUTTON_LEFT,false)
	check(target.health<hp,"actual LMB hits new dog");await shot("actual-player-attack")
	key(KEY_I);await process_frame;check(game.inventory_open,"actual inventory");await shot("actual-inventory");key(KEY_I)
	key(KEY_Q);await advance(.05);await shot("actual-weapon-swap")
	key(KEY_T);await process_frame;check(game.drill_kind=="brinehound" and game.enemies.size()==1,"actual T retains trial");target=game.enemies[0];update_camera();await shot("actual-restart")
	await fresh("right");game.debug_range=true;await advance(.30);await shot("diagnostic-pounce-range");await advance(.32);await shot("diagnostic-bite-range");game.debug_range=false
	await fresh("right");await advance(.02);var start: Vector3=target.position
	var wall:=StaticBody3D.new();wall.collision_layer=1;var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.2,3,3);col.shape=shape;wall.add_child(col);wall.position=start+Vector3(.9,1.5,0);game.add_child(wall);await physics_frame;await physics_frame;await advance(1.20)
	check(game.health==100 and target.position.x<start.x+.55,"native wall stops pounce and both hits");await shot("wall-blocked");wall.free()
	await fresh("left");await advance(.52);target.receive_damage(10000,Vector3.ZERO);await advance(.2)
	check(target.dead and target.phase<0 and game.health==100,"airborne death cancels contacts");await shot("airborne-death")
	game.start_coast();target=game.enemies[2];game.player.position=target.position+Vector3.RIGHT*3.1;update_camera();await advance(.12)
	check(game.enemies[0].has_method("fisherman_direction") and game.coast.living(game)==10,"coast keeps both approved actors");await shot("coast-dog")
	game.audio.set_enabled(false);await create_timer(.2).timeout
	var f:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"scope":"actual standalone PCK, controlled timing/placements, actual viewport menu and controls; not natural dungeon playthrough"},"\t"));f.close()
	game.queue_free();await process_frame;await process_frame
	print("BRINEHOUND NATIVE: ",captures.size()," images; ",checks," checks; failures=",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
