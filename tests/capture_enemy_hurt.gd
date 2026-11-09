extends SceneTree
var game
var target
var output:=""
var checks:=0
var failures: Array=[]
var captures: Array=[]
func _initialize() -> void:
	root.unfocusable=true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL: ",label)
func camera() -> void:
	game._camera_focus=target.position;game._shake=0
	game.camera.position=target.position+game.CAMERA_OFFSET;game.camera.look_at(target.position)
	game.vision.update_view(0)
func fresh(trial: String) -> void:
	game.call(trial);target=game.enemies[0];target.stagger=100;target.cooldown=100
	target.position=Vector3(0,.03,0);target.home_position=target.position
	game.loadout_mode=false;game.debug_range=true;game.player.position=Vector3(-3,.03,0);game.test_aim=Vector3.RIGHT;game.aim=Vector3.RIGHT
	camera();target._pose(game);game._visual_tick(0)
	await physics_frame;await physics_frame
func shot(label: String) -> void:
	camera();game._visual_tick(0);target._update_hurt_debug(game)
	await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,"capture "+label)
	captures.append({"label":label,"health":target.health,"animation":String(target.sprite.animation),"cells":target.hurt_regions().size(),"family":game.weapon_family,"stage":game.motion.stage})
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
	check(not output.is_empty(),"output provided")
	if output.is_empty():quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://scenes/game.tscn").instantiate();game.loadout.save_path="";root.add_child(game);game.set_physics_process(false)
	game.stats=game.stats.duplicate();game.stats.flat.critical_chance=-1
	await process_frame;await process_frame
	var geometry=load("res://scripts/enemy_image_hurt.gd")
	for trial: String in ["start_fisherman_trial","start_brinehound_trial","start_crewman_trial"]:
		for view: String in ["left","right","front","back"]:
			await fresh(trial);target.sprite.animation=view+"_idle";target.sprite.frame=0
			await shot(trial+"-"+view+"-body-overlay")
		for family: String in ["sword","greatsword","mace"]:
			for stage in 3:
				await fresh(trial);game.set_weapon_family(family)
				var point: Vector3=geometry.point(target.sprite,Vector2(64,60),.73,Vector2(128,128))
				var reach: float=game.motion.definition(stage).reach
				game.player.position=point-game.camera.global_basis.x*reach*.85;game.player.position.y=.03
				game.test_aim=Vector3.RIGHT;game.aim=Vector3.RIGHT;game._next_combo=stage;game.rewards.combo_left=.6
				var before: float=target.health
				check(game.request_attack(),family+" attack accepted")
				check(game.motion.stage==stage,family+" requested stage "+str(stage))
				if family=="greatsword" and stage<2:
					game.motion.advance(1.01);game.release_great_charge()
				for tick in 180:
					await physics_frame;game.tick(1.0/120)
					if target.health<before:break
				check(target.health<before,trial+" "+family+" stage "+str(stage)+" actual damage")
				await shot(trial+"-"+family+"-"+str(stage)+"-hit")
		for family: String in ["staff","pistol","rifle"]:
			await fresh(trial);game.set_weapon_family(family)
			var point: Vector3=geometry.point(target.sprite,Vector2(64,60),.8,Vector2(128,128))
			var start: Vector3=point-game.camera.global_basis.x*3
			var spec:={"damage":10,"element":"fire" if family=="staff" else "physical","projectile_radius":.1,"projectile_speed":18,"projectile_range":7}
			if family=="rifle":spec.projectile_visual="rifle";spec.pierce_after_exit=.5
			var before: float=target.health
			game.staff_flight.spawn_fireball(start,game.camera.global_basis.x,spec,game.camera)
			for tick in 120:
				await physics_frame;game.tick(1.0/120)
				if target.health<before:break
			check(target.health<before,trial+" "+family+" actual projectile damage to body")
			await shot(trial+"-"+family+"-projectile-hit")
	check(root.unfocusable and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS),"native QA never takes focus")
	var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"scope":"controlled actual attack/damage and projectile simulation, twelve direction overlays; no human playthrough; save disabled before ready"},"\t"));file.close()
	game.audio.set_enabled(false);await create_timer(.2).timeout;game.free();await process_frame
	print("NATIVE ENEMY HURT ",checks," checks, ",captures.size()," captures; failures=",failures)
	quit(0 if failures.is_empty() else 1)
