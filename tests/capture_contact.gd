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
const Profile=preload("res://scripts/projectile_image_geometry.gd")
var pins: Array=[]
func clear_pins() -> void:
	for p in pins:
		if is_instance_valid(p):p.free()
	pins.clear()
func pin_at(point: Vector3) -> void:
	var node:=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radius=.045;mesh.height=.09;node.mesh=mesh
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("70fff1");mat.no_depth_test=true;node.material_override=mat
	game.add_child(node);node.global_position=point;pins.append(node)
func shot(label: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,"capture "+label)
	var meta:={"label":label,"mode":game.mode,"health":game.health,"parries":game.readiness.parries,"weapon":game.weapon_family,"fixture":"controlled poses/camera plus actual viewport RMB on arriving spear"}
	var bodies: Array=[]
	for entry: Dictionary in game.staff_flight.active:
		var sprite: Sprite3D=entry.node.get_node_or_null("flame") if entry.element=="fire" else entry.node.get_node_or_null("bullet")
		if sprite!=null:bodies.append({"radius":entry.radius,"basis_x":sprite.global_basis.x.length(),"basis_y":sprite.global_basis.y.length(),"pixel_size":sprite.pixel_size,"element":entry.element})
	meta.bodies=bodies
	var f:=FileAccess.open(output+"/"+label+".json",FileAccess.WRITE);f.store_string(JSON.stringify(meta,"\t"));f.close();captures.append(meta)
func run() -> void:
	check(not output.is_empty(),"output specified")
	if output.is_empty():quit(1);return
	DirAccess.make_dir_recursive_absolute(output);DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
	game=load("res://scenes/game.tscn").instantiate();game.loadout.save_path="";root.add_child(game);game.set_physics_process(false)
	game.stats=game.stats.duplicate();game.stats.flat.critical_chance=-1
	await process_frame;await process_frame;await shot("menu")
	for view: String in ["left","front","back","right"]:
		await fresh(view);game.loadout_mode=false;game.set_weapon_family("sword");game.debug_range=true
		await advance(1.23);var wait:=flight_time();await advance(maxf(0,wait-.12))
		check(game.projectiles.size()==1,"incoming spear remains before contact")
		if not game.projectiles.is_empty():
			var node=game.projectiles[0].node;var quad: QuadMesh=node.mesh
			var anchor:=Profile.pin(node.material_override.albedo_texture,"harpoon")
			var tip:=Vector3((anchor.x/64-.5)*quad.size.x,(.5-anchor.y/16)*quad.size.y,0)+quad.center_offset
			check((node.global_transform*tip).distance_to(node.global_position)<.001,view+" rendered leading edge at collision point")
			check(node.material_override.albedo_color.is_equal_approx(Color("fffbd3")),view+" 120ms parry cue")
		await shot(view+"-spear-contact-pin");mouse(MOUSE_BUTTON_RIGHT,true);await advance(.16)
		check(game.health==100 and game.readiness.parries==1,view+" actual RMB parry with unchanged150ms window");await shot(view+"-actual-parry")
	game.debug_range=false;target=null
	game.start_run(true);game.clear_actors();game.loadout_mode=false;game.set_weapon_family("staff");game.player.position=Vector3(-2,.03,0);game.test_aim=Vector3.RIGHT;game.aim=Vector3.RIGHT;game._visual_tick(0);update_camera()
	for tier in 3:
		game.staff_flight.spawn_fireball(Vector3(1,.8,(tier-1)*1.15),Vector3.RIGHT,{"damage":20,"projectile_radius":[.12,.20,.30][tier],"projectile_range":6,"projectile_speed":5.5},game.camera)
	await shot("fire-three-radii-birth")
	game.staff_flight.tick(.06,[],game.get_world_3d(),Callable(),game.camera)
	for entry: Dictionary in game.staff_flight.active:
		var flame=entry.node.get_node("flame");check(absf(flame.global_basis.x.length()*flame.pixel_size*8-float(entry.radius))<.001,"native fire radius stays registered after update")
	await shot("fire-three-radii-after-update");game.staff_flight.clear()
	for family: String in ["pistol","rifle"]:
		var spec:={"element":"physical","damage":18,"projectile_radius":.1,"projectile_range":7,"projectile_speed":18}
		if family=="rifle":spec.projectile_visual="rifle"
		game.staff_flight.spawn_fireball(Vector3(1,.8,0),Vector3.RIGHT,spec,game.camera);game.staff_flight.tick(.03,[],game.get_world_3d(),Callable(),game.camera)
		var entry: Dictionary=game.staff_flight.active[0];pin_at(entry.node.global_position);await shot(family+"-contact-body");clear_pins();game.staff_flight.clear()
	for family: String in ["sword","greatsword","mace","staff","pistol","rifle"]:
		for view: String in ["left","front","back","right"]:
			for stage in (3 if family in ["sword","greatsword","mace"] else 1):
				game.start_run(true);game.clear_actors();game.loadout_mode=false;game.set_weapon_family(family);game.player.position=Vector3(0,.03,0)
				var direction: Vector3=VIEWS[view];game.test_aim=direction;game.aim=direction;var angle:=atan2(direction.z,direction.x)
				check(game.motion.start(stage,angle),family+" pose starts")
				if family=="greatsword" and stage<2:game.motion.advance(1.01);check(game.motion.release_great_charge(),"greatsword charge released")
				var data: Dictionary=game.motion.definition(stage);game.motion.advance(float(data.windup)+float(data.active)*.5)
				game._visual_tick(0);update_camera();var blade: Dictionary=game.avatar.get_blade_points();pin_at(blade.tip)
				check(game.current_visual_sample().phase=="active",family+" actual active pose")
				await shot("pose-%s-%s-%d"%[family,view,stage]);clear_pins()
	game.start_coast();target=game.enemies[6];game.player.position=target.position+Vector3.RIGHT*4;update_camera();await advance(.98);await shot("coast-unchanged-three-actors")
	game.audio.set_enabled(false);await create_timer(.2).timeout
	var f:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"scope":"actual PCK, controlled poses and actual RMB at120ms before real swept contact; not human playthrough"},"\t"));f.close()
	game.free();await process_frame;print("NATIVE CONTACT: ",checks," checks; ",captures.size()," captures; failures=",failures);quit(0 if failures.is_empty() else 1)
