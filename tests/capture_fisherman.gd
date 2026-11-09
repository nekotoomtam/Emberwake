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
func mouse(button: int,pressed: bool,position_: Vector2) -> void:
	var event:=InputEventMouseButton.new();event.button_index=button;event.pressed=pressed;event.position=position_;root.push_input(event,true);Input.flush_buffered_events()
func update_camera() -> void:
	var focus: Vector3=target.position if is_instance_valid(target) else game.player.position
	game._camera_focus=focus;game._shake=0;game.camera.position=focus+game.CAMERA_OFFSET;game.camera.look_at(focus)
	if is_instance_valid(target):
		game.test_aim=(target.position-game.player.position).normalized()
	game.vision.update_view(0)
func advance(duration: float) -> void:
	var remaining:=duration
	while remaining>.000001:
		await physics_frame
		var dt:=minf(STEP,remaining);game.tick(dt);remaining-=dt
		update_camera()
func shot(label: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	var path:=output+"/"+label+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"capture "+label)
	var meta:={"label":label,"mode":game.mode,"health":game.health,"checks":checks,"fixture":"controlled placement and attack timing; actual game runtime"}
	if is_instance_valid(target):
		meta.merge({"view":target.fisherman_direction(),"phase":target.state,"animation":target.sprite.animation,"frame":target.sprite.frame,"contacts":target.contact_count,"enemy_hp":target.health,"no_mirror":not target.sprite.flip_h})
	var f:=FileAccess.open(output+"/"+label+".json",FileAccess.WRITE);f.store_string(JSON.stringify(meta,"\t"));f.close();captures.append(meta)
func fresh(view: String,distance: float=.9) -> void:
	game.start_fisherman_trial();target=game.enemies[0];target.cooldown=0
	target.position=Vector3(0,.03,0);target.home_position=target.position
	game.player.position=target.position+DIRECTIONS[view]*distance
	game.test_aim=-DIRECTIONS[view];game.move_input=Vector2.ZERO;update_camera()
	await physics_frame;await physics_frame
func run() -> void:
	check(not output.is_empty(),"capture output specified")
	DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
	game=load("res://scenes/game.tscn").instantiate();game.loadout.save_path="";root.add_child(game);game.set_physics_process(false)
	game.stats=game.stats.duplicate();game.stats.flat.critical_chance=-1.0
	await process_frame;await process_frame
	await shot("menu")
	var entry=game.ui.buttons.get_child(0)
	check(entry.text.contains("ชาวประมง"),"first menu entry is new trial")
	var at: Vector2=entry.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=at;root.push_input(motion,true)
	mouse(MOUSE_BUTTON_LEFT,true,at);mouse(MOUSE_BUTTON_LEFT,false,at)
	await process_frame
	check(game.mode=="practice" and game.drill_kind=="fisherman","actual viewport menu click opens trial")
	target=game.enemies[0];update_camera();await shot("trial-entry")
	for view: String in ["left","front","back","right"]:
		await fresh(view,3.0);var old: Vector3=target.position
		await advance(.28);check(target.position.distance_to(old)>.2 and target.position.distance_to(old)<.4,view+" actual slow movement")
		check(target.sprite.animation==view+"_walk" and not target.sprite.flip_h,view+" actual walking direction")
		await shot(view+"-walk")
		await fresh(view)
		await advance(.02);check(target.state=="windup" and game.health==100,view+" anticipation begins safely")
		await shot(view+"-idle")
		await advance(.40);check(target.sprite.frame==1,view+" raised hook")
		await shot(view+"-raise")
		await advance(.60);check(target.sprite.frame==2 and game.health==100,view+" held windup harmless")
		await shot(view+"-hold")
		await advance(.60);check(target.state=="attack" and target.sprite.animation==view+"_attack",view+" contact frame")
		check(game.health==86 and target.contact_count==1,view+" contact once with14 damage")
		await shot(view+"-contact")
		await advance(.20);check(target.state=="recover" and game.health==86,view+" follow-through harmless")
		await shot(view+"-follow")
		await advance(.40);check(target.sprite.frame==1,view+" return pose")
		await shot(view+"-return")
	await fresh("right");await advance(1.51)
	mouse(MOUSE_BUTTON_RIGHT,true,game.camera.unproject_position(target.position));await advance(.14)
	check(game.health==100 and game.readiness.parries==1 and target.state=="parried","actual RMB timed parry")
	await shot("actual-parry");mouse(MOUSE_BUTTON_RIGHT,false,Vector2.ZERO)
	await fresh("left");mouse(MOUSE_BUTTON_RIGHT,true,game.camera.unproject_position(target.position));await advance(1.65)
	check(game.health<100 and game.health>86 and game.readiness.parries==0,"actual held RMB guard")
	await shot("actual-guard");mouse(MOUSE_BUTTON_RIGHT,false,Vector2.ZERO)
	await fresh("front");await advance(1.55);key(KEY_SPACE);await advance(.10)
	check(game.health==100 and game.rewards.refunded,"actual SPACE precise dodge")
	await shot("actual-dodge")
	await fresh("right");target.cooldown=20;game._held=false
	var enemy_hp: float=target.health
	mouse(MOUSE_BUTTON_LEFT,true,game.camera.unproject_position(target.position+Vector3.UP*.6));await advance(.70)
	mouse(MOUSE_BUTTON_LEFT,false,Vector2.ZERO)
	check(target.health<enemy_hp,"actual LMB attacks new sprite")
	await shot("actual-player-attack")
	key(KEY_I);await process_frame;check(game.inventory_open,"actual I inventory retained");await shot("actual-inventory");key(KEY_I)
	key(KEY_Q);await advance(.05);await shot("actual-weapon-swap")
	key(KEY_T);await process_frame;check(game.drill_kind=="fisherman" and game.enemies.size()==1,"actual T keeps trial")
	target=game.enemies[0];update_camera();await shot("actual-restart")
	await fresh("back");game.debug_range=true;await advance(1.62);await shot("diagnostic-back-contact")
	for view: String in ["right","front"]:
		await fresh(view);game.debug_range=true;await advance(1.62);await shot("diagnostic-"+view+"-contact")
	game.debug_range=false;target.receive_damage(10000,Vector3.ZERO);target.tick(.2,game);update_camera();await shot("same-view-death")
	await fresh("right");game.player.position=target.position+Vector3(.7,0,.7);update_camera()
	var diagonal_before: Vector3=target.position;await advance(.10)
	check(target.position.distance_to(diagonal_before)>.05 and target.state=="chase","native diagonal target approached")
	await shot("diagonal-approach");await advance(2.1)
	check(game.health==86 and target.contact_count==1,"native diagonal target hit after alignment")
	await shot("diagonal-contact")
	game.start_coast();target=game.enemies[0];game.player.position=target.position+Vector3.RIGHT*2.0;update_camera();await advance(.15)
	check(target.has_method("fisherman_direction") and game.coast.living(game)==10,"coast uses new fisherman with other roster")
	await shot("coast-fisherman")
	game.audio.set_enabled(false);await create_timer(.2).timeout
	var f:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"scope":"actual standalone PCK; controlled placements/timing; actual viewport menu/LMB/RMB/SPACE/I/Q/T; not a natural complete playthrough"},"\t"));f.close()
	game.queue_free();await process_frame;await process_frame
	print("FISHERMAN NATIVE: ",captures.size()," images; ",checks," checks; failures=",JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
