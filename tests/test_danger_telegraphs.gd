extends SceneTree
var checks:=0
var failures: Array=[]
var game
const KINDS:=["melee","ranged","elite","fisherman","brinehound","net_hauler","harpooner","spitter","captain"]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL: ",label)
func advance(time_: float) -> void:
	while time_>.000001:
		var dt:=minf(time_,1.0/120);game.tick(dt);time_-=dt
func run() -> void:
	check(ResourceLoader.exists("res://scripts/danger_geometry.gd"),"shared geometry exists")
	if not failures.is_empty():finish();return
	var geometry=load("res://scripts/danger_geometry.gd");var attacks=load("res://scripts/enemy_attacks.gd");var boss=load("res://scripts/captain_rules.gd")
	for data: Dictionary in [attacks.definition("melee",0),attacks.definition("elite",1),attacks.definition("ranged",0),boss.definition("sweep"),boss.definition("throw"),boss.definition("slam")]:
		var frozen:=data.duplicate(true)
		for angle: float in [0,PI*.5,PI,PI*1.5]:
			var points: Array=geometry.outline(data,angle);check(points.size()>=24,"sampled "+str(data.shape))
			for p: Vector3 in points:
				var inside: bool=boss.contains(Vector3.ZERO,angle,p,data) if data.has("radius") else attacks.contains(Vector3.ZERO,angle,p,data)
				if data.shape=="lane":
					var end:=Vector3(cos(angle),0,sin(angle))*float(data.reach)
					var nearest:=Geometry3D.get_closest_point_to_segment(p,data.get("launch",Vector3.ZERO),end)
					inside=p.distance_to(nearest)<=float(data.get("radius",float(data.get("width",.8))*.5))+.00001
				check(inside,"outline on actual collision boundary "+str(data.shape))
		check(data==frozen,"geometry never mutates damage definition")
	check(geometry.progress({"windup":1.2},"windup",.6)==.5 and geometry.progress({},"attack",0)==1,"timing fraction")
	game=load("res://scenes/game.tscn").instantiate();game.loadout.save_path="";root.add_child(game);game.set_physics_process(false)
	for kind: String in KINDS:
		game.start_run(true);game.clear_actors();var enemy=game.spawn_enemy(kind,Vector3(0,.03,0));enemy.cooldown=0;game.player.position=Vector3(1,.03,0);game.test_aim=Vector3.LEFT
		if kind=="captain":
			enemy.attack_data=boss.definition("slam");enemy.attack_angle=0;enemy.state="windup";enemy.telegraph_left=enemy.attack_data.windup;enemy.captain_view.update_view(game)
		else:
			advance(.025)
		check(not game.debug_range and enemy.attack_visual.visible and enemy.attack_visual.fill.get_surface_count()==1,kind+" footprint in normal play")
		check(enemy.attack_visual.outline.get_surface_count()==1,kind+" thick edge mesh")
		var before: Dictionary=enemy.attack_data.duplicate(true)
		enemy.attack_visual.update_view(enemy.attack_data,enemy.attack_angle,"windup",float(enemy.attack_data.windup)*.5)
		check(absf(enemy.attack_visual.display_progress-.5)<.001,kind+" perimeter timer halfway")
		check(enemy.attack_data==before,kind+" cosmetic only")
		enemy.attack_visual.update_view(enemy.attack_data,enemy.attack_angle,"recover",0)
		check(not enemy.attack_visual.visible and enemy.attack_visual.fill.get_surface_count()==0 and not enemy.attack_visual.get_children()[0].visible,kind+" recovery clears floor")
		enemy.attack_visual.update_view(enemy.attack_data,enemy.attack_angle,"windup",.1)
		var normal: Color=enemy.attack_visual.display_color;var red: Dictionary=enemy.attack_data.duplicate();red.parryable=false;enemy.attack_visual.update_view(red,enemy.attack_angle,"windup",.1)
		check(normal.g>normal.r*.5 or not before.parryable,kind+" amber parryable")
		check(enemy.attack_visual.display_color.r>enemy.attack_visual.display_color.g*2,kind+" red unparryable")
	game.start_crewman_trial();var thrower=game.enemies[0];thrower.cooldown=0;thrower.position=Vector3(0,.03,0);thrower.home_position=thrower.position;game.player.position=Vector3(4,.03,0);game.test_aim=Vector3.LEFT;advance(.2)
	var preview=thrower.attack_visual;check(preview.global_position.distance_to(Vector3(thrower.projectile_launch(game).origin.x,.03,thrower.projectile_launch(game).origin.z))<.01,"preview rooted below actual throwing hand")
	var wall:=StaticBody3D.new();wall.collision_layer=1;var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.2,4,10);col.shape=box;wall.add_child(col);wall.position=Vector3(2,2,0);game.add_child(wall);await physics_frame;await physics_frame
	thrower._pose(game);var farthest:=-100.0
	for p: Vector3 in preview.boundary_points:farthest=maxf(farthest,preview.to_global(p).x)
	check(farthest<=1.901,"wall clips warning at same wall plane, x="+str(farthest));wall.free()
	game.start_brinehound_trial();var dog=game.enemies[0];dog.cooldown=0;dog.position=Vector3(0,.03,0);dog.home_position=dog.position;game.player.position=Vector3(2,.03,0);game.test_aim=Vector3.LEFT;advance(.1)
	check(dog.attack_visual.position.x>1.2 and dog.attack_visual.position.x<1.4,"dog warns landing bite rather than harmless travel")
	var progress: float=dog.attack_visual.display_progress;game.toggle_pause();advance(.5);check(dog.attack_visual.display_progress==progress,"pause freezes displayed timer");game.toggle_pause()
	advance(.7);check(dog.phase==3 and dog.attack_visual.position.length()<.01 and dog.attack_visual.visible,"independent grounded secondbite warning")
	dog.receive_damage(10000,Vector3.ZERO);advance(.01);check(not dog.attack_visual.visible,"death removes landing area")
	game.start_brinehound_trial();dog=game.enemies[0];dog.cooldown=0;dog.position=Vector3(0,.03,0);dog.home_position=dog.position
	var diagonal:=Vector3(1,0,.7).normalized();game.player.position=diagonal*2.4+Vector3.UP*.03;game.test_aim=-diagonal;advance(.05)
	var angled_wall:=StaticBody3D.new();angled_wall.collision_layer=1;var angled_col:=CollisionShape3D.new();var angled_box:=BoxShape3D.new();angled_box.size=Vector3(.16,3,6);angled_col.shape=angled_box;angled_wall.add_child(angled_col);angled_wall.position=Vector3(.8,1.5,0);game.add_child(angled_wall);await physics_frame;await physics_frame
	dog._pose(game);var predicted: Vector3=dog.attack_visual.global_position;advance(.55)
	check(dog.phase==2 and dog.position.distance_to(predicted)<.03,"angled wall slide lands inside predicted bite root; error="+str(dog.position.distance_to(predicted)))
	angled_wall.free()
	game.start_run(true);game.clear_actors();var spit=game.spawn_enemy("spitter",Vector3(0,.03,0));game.player.position=Vector3(2.5,.03,0);game.test_aim=Vector3.LEFT;spit.attack_index=1;spit.cooldown=0;advance(.02)
	check(spit.attack_visual.visible and not spit.fan_guides[0].visible and not spit.fan_guides[1].visible and not game.debug_range and spit.attack_data.id=="brine_stream","new single stream lane replaces obsolete fan")
	game._visual_tick(0);game.test_aim=Vector3.RIGHT;game.vision.update_view(0)
	check(not spit.is_visible_in_tree() and not spit.attack_visual.is_visible_in_tree(),"no off-sight warning leakage")
	game.audio.set_enabled(false);await create_timer(.2).timeout;game.free();await process_frame;finish()
func finish() -> void:
	print("DANGER TELEGRAPHS: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
