extends SceneTree
var game
var target
var output:=""
var checks:=0
var failures: Array=[]
var captures: Array=[]
const STEP:=1.0/120
func _initialize() -> void:
	root.unfocusable=true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL: ",label)
func mouse(on: bool) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=on;root.push_input(event,true);Input.flush_buffered_events()
func camera() -> void:
	var focus: Vector3=target.position if is_instance_valid(target) else Vector3.ZERO
	game._camera_focus=focus;game._shake=0;game.camera.position=focus+game.CAMERA_OFFSET;game.camera.look_at(focus);game.vision.update_view(0)
func advance(time: float) -> void:
	while time>.000001:
		await physics_frame;var dt:=minf(STEP,time);game.tick(dt);time-=dt;camera()
func fresh(view: String="right",far: bool=false,index: int=0) -> void:
	mouse(false);game.start_net_hauler_trial();target=game.enemies[0];target.position=Vector3(0,.03,0);target.home_position=target.position;target.cooldown=0;target.attack_index=index
	game.loadout_mode=false;game.set_weapon_family("sword");game.debug_range=false
	var forward: Vector3=load("res://scripts/net_hauler_art.gd").ground_direction(view,game.camera)
	var hit: Dictionary=target.impact_geometry(view,game.camera)
	game.player.position=target.position+forward*(3.5 if far else maxf(.4,hit.offset.dot(forward)))
	game.test_aim=-forward;game.aim=-forward;camera();target._pose(game);game._visual_tick(0)
	await physics_frame;await physics_frame
func shot(label: String) -> void:
	camera();game._visual_tick(0)
	if is_instance_valid(target):target._pose(game);target._update_hurt_debug(game)
	await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,"capture "+label)
	var row:={"label":label,"mode":game.mode,"player_health":game.health,"parries":game.readiness.parries,"weapon":game.weapon_family}
	if is_instance_valid(target):row.merge({"view":target.net_hauler_direction(),"state":target.state,"animation":String(target.sprite.animation),"frame":target.sprite.frame,"enemy_health":target.health,"contacts":target.contact_count,"radius":float(target.attack_data.get("width",0))*.5})
	captures.append(row)
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
	check(not output.is_empty(),"output provided");if output.is_empty():quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://scenes/game.tscn").instantiate();game.loadout.save_path="";root.add_child(game);game.set_physics_process(false)
	game.stats=game.stats.duplicate();game.stats.flat.critical_chance=-1
	await process_frame;await process_frame;await shot("menu")
	for view: String in ["left","front","back","right"]:
		await fresh(view,true);var start: Vector3=target.position;await advance(.55)
		check(target.position.distance_to(start)>.3 and target.sprite.animation==view+"_walk",view+" actual slow walking")
		await shot(view+"-walk")
		await fresh(view);await advance(.15);await shot(view+"-anticipation")
		await advance(.4);await shot(view+"-lift")
		await advance(.6);check(target.sprite.frame==2 and game.health==100,view+" visible overhead before damage");await shot(view+"-held-windup")
		await advance(.53);check(game.health==76 and target.contact_count==1 and target.sprite.animation==view+"_attack",view+" single24 with impact frame");await shot(view+"-impact")
		await advance(.2);await shot(view+"-follow-through")
		await advance(.35);check(game.health==76,view+" recovery no extra damage");await shot(view+"-return")
	await fresh();await advance(1.59);mouse(true);await advance(.09);check(game.health==100 and game.readiness.parries==1,"native RMB parry cancels overhead");await shot("actual-parry");mouse(false)
	await fresh();mouse(true);await advance(1.68);check(game.health>76 and game.health<100,"native held guard");await shot("actual-guard");mouse(false)
	await fresh("right",false,2);await advance(1.15);await shot("red-overhead-warning");mouse(true);await advance(.53);check(game.health>76 and game.health<100 and game.readiness.parries==0,"native red cannot parry but guards");await shot("red-guard");mouse(false)
	await fresh();await advance(1.60);check(game.request_dodge(Vector3.BACK),"native dodge starts");await advance(.1);check(game.health==100 and game.rewards.refunded,"native perfect evade refund");await shot("perfect-evade")
	await fresh("right",true);game.debug_range=true;await advance(.1);await shot("image-receiving-body-H")
	for family: String in ["sword","greatsword","mace"]:
		for stage in 3:
			await fresh();target.stagger=100;target.cooldown=100;target.state="parried";target._committed_view="right";target._pose(game);game.set_weapon_family(family)
			var point: Vector3=load("res://scripts/enemy_image_hurt.gd").point(target.sprite,Vector2(56,65),.73,Vector2(128,128))
			var reach: float=game.motion.definition(stage).reach
			game.player.position=point-game.camera.global_basis.x*reach*.85;game.player.position.y=.03
			game.test_aim=Vector3.RIGHT;game.aim=Vector3.RIGHT;game._next_combo=stage;game.rewards.combo_left=.6
			var before: float=target.health;check(game.request_attack(),family+" attack accepted");check(game.motion.stage==stage,family+" stage "+str(stage))
			if family=="greatsword" and stage<2:game.motion.advance(1.01);game.release_great_charge()
			for tick in 180:
				await physics_frame;game.tick(STEP);camera()
				if target.health<before:break
			check(target.health<before,family+str(stage)+" actual damage to image body");await shot("player-%s-%d-hit"%[family,stage])
	for family: String in ["staff","pistol","rifle"]:
		await fresh();target.stagger=100;target.cooldown=100;target.state="parried";target._committed_view="right";target._pose(game);game.set_weapon_family(family)
		var point: Vector3=load("res://scripts/enemy_image_hurt.gd").point(target.sprite,Vector2(56,65),.8,Vector2(128,128))
		var spec:={"damage":10,"element":"fire" if family=="staff" else "physical","projectile_radius":.1,"projectile_speed":18,"projectile_range":7}
		if family=="rifle":spec.projectile_visual="rifle";spec.pierce_after_exit=.5
		var before: float=target.health;game.staff_flight.spawn_fireball(point-game.camera.global_basis.x*3,game.camera.global_basis.x,spec,game.camera)
		for tick in 120:
			await physics_frame;game.tick(STEP);camera()
			if target.health<before:break
		check(target.health<before,family+" actual projectile damage");await shot("player-"+family+"-hit")
	game.start_coast()
	for enemy in game.enemies:
		if enemy.kind=="net_hauler":target=enemy;break
	game.player.position=target.position+Vector3.RIGHT*3;game.test_aim=Vector3.LEFT;camera();await advance(.4);await shot("coast-net-hauler")
	check(root.unfocusable and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS),"QA never steals focus")
	var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"scope":"actual PCK, controlled native AI/defense and player damage fixtures, save disabled before scene ready; not human playthrough"},"\t"));file.close()
	game.audio.set_enabled(false);await create_timer(.2).timeout;game.free();await process_frame
	print("NATIVE NET HAULER ",checks," checks; ",captures.size()," captures; failures=",failures);quit(0 if failures.is_empty() else 1)
