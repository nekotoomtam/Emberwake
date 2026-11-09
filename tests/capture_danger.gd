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
const Attacks=preload("res://scripts/enemy_attacks.gd")
const Roster=preload("res://scripts/coastal_roster.gd")
const BossRules=preload("res://scripts/captain_rules.gd")
const Facing=preload("res://scripts/fisherman_art.gd")
func shot(label: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,"capture "+label)
	var meta:={"label":label,"mode":game.mode,"health":game.health,"debug":game.debug_range,"fixture":"controlled attack state and inspection camera; actual exported renderer"}
	if is_instance_valid(target):meta.merge({"kind":target.kind,"attack":target.attack_data.get("id",""),"phase":target.state,"angle":target.attack_angle,"area_visible":target.attack_visual.is_visible_in_tree(),"outline_points":target.attack_visual.boundary_points.size(),"progress":target.attack_visual.display_progress,"color":str(target.attack_visual.display_color)})
	var f:=FileAccess.open(output+"/"+label+".json",FileAccess.WRITE);f.store_string(JSON.stringify(meta,"\t"));f.close();captures.append(meta)
func fixture(kind: String,angle: float,id: String="",index: int=0) -> void:
	game.start_run(true);game.clear_actors();target=game.spawn_enemy(kind,Vector3(0,.03,0));target.cooldown=0
	var direction:=Vector3(cos(angle),0,sin(angle));game.player.position=target.position+direction*4;game.test_aim=-direction;game.aim=-direction
	target.target_point=game.player.position;target.attack_angle=angle;target.state="windup";target.clock=1
	if kind=="captain":target.attack_data=BossRules.definition(id)
	elif kind in ["melee","ranged","elite"]:target.attack_data=Attacks.definition(kind,index)
	else:target.attack_data=target._attack_definition(index)
	target.telegraph_left=float(target.attack_data.windup)*.5
	if kind in ["harpooner","fisherman"]:target._committed_view=Facing.direction(direction,game.camera)
	if kind=="brinehound":
		game.player.position=target.position+direction*2;target._begin(game,direction*2);target.phase_left=.22;target.telegraph_left=.22
	await physics_frame;await physics_frame
	target.tick(.000001,game);game._visual_tick(0);game.camera.size=12;update_camera()
func run() -> void:
	check(not output.is_empty(),"output specified")
	if output.is_empty():quit(1);return
	DirAccess.make_dir_recursive_absolute(output);DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000));safe=true
	game=load("res://scenes/game.tscn").instantiate();game.loadout.save_path="";root.add_child(game);game.set_physics_process(false)
	await process_frame;await process_frame;await shot("menu")
	check(game.ui.buttons.get_child(8).get_global_rect().end.y<=root.size.y,"default menu fits")
	for kind: String in ["melee","ranged","elite","fisherman","brinehound","net_hauler","harpooner","spitter"]:
		for angle: float in [0,PI*.5,PI,PI*1.5]:
			await fixture(kind,angle,"",1 if kind in ["elite","spitter"] else 0)
			check(target.attack_visual.is_visible_in_tree() and not game.debug_range,kind+" visible normal at"+str(angle))
			check(target.attack_visual.fill.get_surface_count()==1 and target.attack_visual.outline.get_surface_count()==1,kind+" filled footprint + thick border")
			if kind=="spitter":check(target.fan_guides[0].is_visible_in_tree() and target.fan_guides[1].is_visible_in_tree(),"all three fan rays")
			await shot(kind+"-"+str(roundi(angle*180/PI)))
	for id: String in ["sweep","throw","slam"]:
		for angle: float in [0,PI*.5,PI,PI*1.5]:
			await fixture("captain",angle,id)
			check(target.attack_visual.is_visible_in_tree() and target.attack_visual.fill.get_surface_count()==1,"boss "+id+" normal footprint")
			await shot("boss-"+id+"-"+str(roundi(angle*180/PI)))
	await fixture("harpooner",0);target.telegraph_left=1.1;target._pose(game);await shot("crew-early")
	target.telegraph_left=.08;target._pose(game);await shot("crew-late")
	target.state="attack";target.elapsed=0;target.active_left=.25;target._pose(game);await shot("crew-impact")
	target.clock+=.15;target._pose(game);await shot("crew-impact-settled")
	key(KEY_H);target._pose(game);check(game.debug_range and target.attack_visual.is_visible_in_tree(),"H retains normal floor warnings");await shot("extra-diagnostics");key(KEY_H)
	target.state="recover";target.cooldown=2.0;target._pose(game);check(not target.attack_visual.visible,"recovery clears warning");await shot("crew-recovery")
	await fixture("spitter",0,"",1);game.test_aim=Vector3.RIGHT;game.aim=Vector3.RIGHT;game.vision.update_view(0)
	check(not target.is_visible_in_tree() and not target.attack_visual.is_visible_in_tree(),"off-sight actor and warning hidden");await shot("out-of-sight")
	await fixture("harpooner",0);var wall:=StaticBody3D.new();wall.collision_layer=1;var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.2,4,1.0);col.shape=box;wall.add_child(col)
	var launch: Dictionary=target.projectile_launch(game);var contact: Vector3=launch.origin+launch.direction*((2-launch.origin.x)/launch.direction.x)
	wall.position=Vector3(2,2,contact.z);game.add_child(wall);await physics_frame;await physics_frame;target._pose(game);game.vision.update_view(0)
	var farthest:=-100.0
	for p: Vector3 in target.attack_visual.boundary_points:farthest=maxf(farthest,target.attack_visual.to_global(p).x)
	check(farthest<=1.901,"native actual-hand warning clipped before wall x="+str(farthest));await shot("wall-clipped-lane");wall.free()
	await fixture("brinehound",atan2(.7,1.0))
	game.player.position=Vector3(-1,.03,2)
	wall=StaticBody3D.new();wall.collision_layer=1;col=CollisionShape3D.new();box=BoxShape3D.new();box.size=Vector3(.16,3,6);col.shape=box;wall.add_child(col);wall.position=Vector3(.8,1.5,0);game.add_child(wall);await physics_frame;await physics_frame
	target._pose(game);update_camera();var predicted: Vector3=target.attack_visual.global_position;await shot("dog-slide-warning");await advance(.37)
	check(target.phase==2 and target.position.distance_to(predicted)<.03,"native slide actual landing matches warning");await shot("dog-slide-landing");wall.free()
	game.start_coast();target=game.enemies[6];game.player.position=target.position+Vector3.RIGHT*4;update_camera();await advance(.9);await shot("coast-normal")
	game.audio.set_enabled(false);await create_timer(.2).timeout
	var f:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"scope":"actual exported renderer with controlled attack states, four directions for every hostile kind and boss move, real H event; not natural playthrough"},"\t"));f.close()
	game.free();await process_frame;print("NATIVE DANGER: ",checks," checks; ",captures.size()," captures; failures=",failures);quit(0 if failures.is_empty() else 1)
