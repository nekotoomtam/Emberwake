extends SceneTree
var game
var target
var output:=""
var captures: Array=[]
var failures: Array=[]
var checks:=0
var safe:=false
const STEP:=1.0/120
const VIEWS:={"left":Vector3.LEFT,"right":Vector3.RIGHT,"front":Vector3.BACK,"back":Vector3.FORWARD}
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
func mouse(button: int,on: bool,at: Vector2=Vector2.ZERO) -> void:
	var event:=InputEventMouseButton.new();event.button_index=button;event.pressed=on;event.position=at;root.push_input(event,true);Input.flush_buffered_events()
func key(code: int) -> void:
	for on in [true,false]:
		var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=on;root.push_input(event,true)
	Input.flush_buffered_events()
func hold_key(code: int,on: bool) -> void:
	# Movement is polled through Input.get_vector: viewport push alone delivers
	# callbacks but does not set the Input action state in this offscreen fixture.
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=on;Input.parse_input_event(event);Input.flush_buffered_events()
func update_camera() -> void:
	var focus: Vector3=target.position if is_instance_valid(target) else game.player.position
	game._camera_focus=focus;game._shake=0;game.camera.position=focus+game.CAMERA_OFFSET;game.camera.look_at(focus)
	if is_instance_valid(target):game.test_aim=(target.position-game.player.position).normalized()
	game.vision.update_view(0)
func advance(time_: float) -> void:
	while time_>.000001:
		await physics_frame;var dt:=minf(STEP,time_);game.tick(dt);time_-=dt;update_camera()
func fresh(view: String="right",distance: float=4.0) -> void:
	mouse(MOUSE_BUTTON_LEFT,false);mouse(MOUSE_BUTTON_RIGHT,false);game.start_crewman_trial();target=game.enemies[0];target.cooldown=0
	target.position=Vector3(0,.03,0);target.home_position=target.position;game.player.position=target.position+VIEWS[view]*distance;game.test_aim=-VIEWS[view];game.move_input=Vector2.ZERO;update_camera();await physics_frame;await physics_frame
func flight_time() -> float:
	var aim: Vector3=game.player.position-game.projectiles[0].node.position;aim.y=0
	return maxf(0,(aim.length()-.39)/5.5)
func shot(label: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,"capture "+label)
	var meta:={"label":label,"mode":game.mode,"health":game.health,"projectiles":game.projectiles.size(),"perfect_dodge":game.rewards.refunded,"fixture":"controlled placement/timing and real viewport inputs"}
	if is_instance_valid(target):meta.merge({"view":target.crewman_direction(),"state":target.state,"animation":target.sprite.animation,"frame":target.sprite.frame,"throws":target.throws,"enemy_hp":target.health,"position":[target.position.x,target.position.y,target.position.z],"no_mirror":not target.sprite.flip_h})
	var f:=FileAccess.open(output+"/"+label+".json",FileAccess.WRITE);f.store_string(JSON.stringify(meta,"\t"));f.close();captures.append(meta)
func run() -> void:
	check(not output.is_empty(),"output specified");DirAccess.make_dir_recursive_absolute(output)
	if output.is_empty():quit(1);return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
	game=load("res://scenes/game.tscn").instantiate();game.loadout.save_path="";root.add_child(game);game.set_physics_process(false)
	game.stats=game.stats.duplicate();game.stats.flat.critical_chance=-1
	await process_frame;await process_frame;await shot("menu")
	var last=game.ui.buttons.get_child(game.ui.buttons.get_child_count()-1)
	check(last.get_global_rect().end.y<=root.size.y,"nine menu entries fit actual default viewport")
	var entry=game.ui.buttons.get_child(0);check(entry.text.contains("ลูกเรือ"),"new first menu")
	var at: Vector2=entry.get_global_rect().get_center();var motion:=InputEventMouseMotion.new();motion.position=at;root.push_input(motion,true)
	mouse(MOUSE_BUTTON_LEFT,true,at);mouse(MOUSE_BUTTON_LEFT,false,at);await process_frame
	check(game.mode=="practice" and game.drill_kind=="crewman","actual menu enters trial");target=game.enemies[0];update_camera();await shot("trial-entry")
	for view: String in VIEWS:
		await fresh(view,2);target.cooldown=20;var start: Vector3=target.position;await advance(.24)
		check(target.position.distance_to(start)>.2 and target.sprite.animation.ends_with("walk") and not target.sprite.flip_h,view+" physical retreat walk")
		await shot(view+"-walk")
		await fresh(view);await advance(.15);await shot(view+"-ready");await advance(.30);await shot(view+"-raise");await advance(.53)
		check(game.health==100 and game.projectiles.is_empty() and target.sprite.frame==2,view+" no damage during held aim")
		await shot(view+"-aim");await advance(.25)
		check(game.projectiles.size()==1 and target.throws==1 and target.sprite.animation==view+"_attack",view+" one real release")
		await shot(view+"-release");await advance(.12);await shot(view+"-flight")
		await advance(flight_time()+.05)
		check(game.health==78 and game.projectiles.is_empty(),view+" projectile22 consumed once")
		await shot(view+"-hit");await advance(.20);await shot(view+"-followthrough")
		await advance(1.7);check(target.sprite.animation.ends_with("recover") and target.sprite.frame==1 and target.throws==1,view+" replacement spear during long rest")
		await shot(view+"-reload")
	await fresh();await advance(1.23);var wait:=flight_time();await advance(maxf(0,wait-.07));mouse(MOUSE_BUTTON_RIGHT,true);await advance(.15)
	check(game.health==100 and game.readiness.parries==1 and target.state=="parried","actual RMB parry");await shot("actual-parry")
	await fresh("front");mouse(MOUSE_BUTTON_RIGHT,true);await advance(2.2);check(game.health>78 and game.health<100,"actual held guard");await shot("actual-guard")
	await fresh();await advance(1.23);wait=flight_time();await advance(maxf(0,wait-.07));hold_key(KEY_W,true);check(game._movement().length()>.5,"native engine movement input active");key(KEY_SPACE);hold_key(KEY_W,false);await advance(.15)
	check(game.health==100 and game.rewards.refunded,"actual SPACE precise dodge");await shot("actual-dodge")
	await fresh("right",.7);target.cooldown=20;var hp: float=target.health;mouse(MOUSE_BUTTON_LEFT,true,game.camera.unproject_position(target.position+Vector3.UP*.6));await advance(.7);mouse(MOUSE_BUTTON_LEFT,false)
	check(target.health<hp,"actual LMB harms thrower");await shot("actual-player-attack")
	key(KEY_I);await process_frame;check(game.inventory_open,"actual I inventory");await shot("actual-inventory");key(KEY_I);key(KEY_Q);await advance(.05);await shot("actual-swap")
	key(KEY_T);await process_frame;check(game.drill_kind=="crewman" and game.enemies.size()==1,"actual T resets trial");target=game.enemies[0];update_camera();await shot("actual-restart")
	await fresh();game.debug_range=true;await advance(.98);await shot("diagnostic-throw-range");game.debug_range=false
	await fresh();await advance(.9);var wall:=StaticBody3D.new();wall.collision_layer=1;var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.2,4,6);col.shape=box;wall.add_child(col);wall.position=Vector3(2,2,0);game.add_child(wall);await physics_frame;await physics_frame;await advance(1.1)
	check(game.health==100 and game.projectiles.is_empty() and target.throws==1,"native wall stops projectile");await shot("wall-blocked");wall.free()
	await fresh("back");await advance(.9);target.receive_damage(10000,Vector3.ZERO);await advance(.4);check(target.dead and target.throws==0,"death stops throw");await shot("death")
	game.start_coast();target=game.enemies[6];game.player.position=target.position+Vector3.RIGHT*4;update_camera();await advance(.98)
	check(game.coast.living(game)==10 and game.enemies[0].has_method("fisherman_direction") and game.enemies[2].has_method("brinehound_direction"),"all three approved actors in coast");await shot("coast-crewman")
	game.audio.set_enabled(false);await create_timer(.2).timeout
	var f:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"scope":"actual exported PCK, controlled fixtures and actual viewport input, not full human dungeon playthrough"},"\t"));f.close()
	game.free();await process_frame;print("NATIVE CREWMAN: ",checks," checks; ",captures.size()," captures; failures=",failures);quit(0 if failures.is_empty() else 1)
