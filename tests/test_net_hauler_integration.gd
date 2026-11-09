extends SceneTree
var g
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL: ",label)
func advance(time: float) -> void:
	while time>.0000001:
		var dt:=minf(time,1.0/120);g.tick(dt);time-=dt
func fresh(view: String="right",index: int=0):
	g.start_net_hauler_trial();var e=g.enemies[0]
	e.position=Vector3(0,.03,0);e.home_position=e.position;e.cooldown=0;e.attack_index=index
	var hit: Dictionary=e.impact_geometry(view,g.camera)
	var forward: Vector3=load("res://scripts/net_hauler_art.gd").ground_direction(view,g.camera)
	g.player.position=e.position+forward*maxf(.4,hit.offset.dot(forward));g.test_aim=(e.position-g.player.position).normalized()
	return e
func right(on: bool) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=on;root.push_input(event,true);Input.flush_buffered_events()
func run() -> void:
	check(ResourceLoader.exists("res://scripts/net_hauler_enemy.gd"),"dedicated actor exists")
	if not failures.is_empty():finish();return
	g=load("res://scenes/game.tscn").instantiate();g.loadout.save_path="";root.add_child(g);g.set_physics_process(false)
	check(g.has_method("start_net_hauler_trial"),"new trial route")
	if not failures.is_empty():g.free();finish();return
	var art=load("res://scripts/net_hauler_art.gd")
	for view in ["left","front","back","right"]:
		var frames: SpriteFrames=art.frames()
		check(frames.get_frame_count(view+"_walk")==6,view+" six walk frames")
		check(frames.get_frame_count(view+"_windup")==3,view+" three visible windup phases")
		check(frames.get_frame_count(view+"_attack")==1,view+" one contact frame")
		check(frames.get_frame_count(view+"_recover")==2,view+" followthrough and recovery")
		var e=fresh(view);advance(.01)
		check(e.state=="windup" and e.net_hauler_direction()==view,view+" actual AI begins facing locked attack")
		var hit: Dictionary=e.impact_geometry(view,g.camera)
		var box: Rect2=art.IMPACT_BOX[view]
		var actual_pixel_ground: Vector3=load("res://scripts/enemy_image_hurt.gd").point(e.sprite,Vector2(box.get_center().x,box.end.y),e.global_position.y,Vector2(128,128))
		check(actual_pixel_ground.distance_to(e.global_position+hit.offset)<.001,view+" real sprite mallet ground pin equals hit center")
		check(e.attack_visual.global_position.distance_to(actual_pixel_ground)<.001,view+" warning shares exact landing pin")
		check(e.threatens(actual_pixel_ground+Vector3.RIGHT*float(hit.radius)*.99),view+" threat inside drawn circle")
		check(not e.threatens(actual_pixel_ground+Vector3.RIGHT*float(hit.radius)*1.01),view+" no hidden damage outside circle")
		var texture: Texture2D=frames.get_frame_texture(view+"_attack",0)
		check(texture.get_size()==Vector2(128,128) and not texture is AtlasTexture,view+" standalone alpha for sight/receiving geometry")
		advance(1.61);check(g.health==100 and e.sprite.frame==2 and e.sprite.animation==view+"_windup",view+" full overhead warning no early damage")
		advance(.04);check(g.health==76 and e.contact_count==1 and e.sprite.animation==view+"_attack",view+" exact one24 damage with impact art")
		advance(.5);check(g.health==76,view+" no repeat damage in recovery")
		check(not e.sprite.flip_h,view+" real authored direction not mirrored")
		e.state="idle";e._pose(g)
		var tool_pixel: Vector2={"left":Vector2(30,99),"front":Vector2(108,99),"back":Vector2(34,99),"right":Vector2(109,99)}[view]
		var tool_point: Vector3=load("res://scripts/enemy_image_hurt.gd").point(e.sprite,tool_pixel,e.position.y+.7,Vector2(128,128))
		var remote_tool_receives:=false
		for region in e.image_hurt_regions(e.position.y+.7):
			if region.position.distance_to(tool_point)<=float(region.radius):remote_tool_receives=true
		check(not remote_tool_receives,view+" remote idle wooden head is not a body target")
		var core: Vector3=load("res://scripts/enemy_image_hurt.gd").point(e.sprite,Vector2(float(art.ROOT_X[view]),70),e.position.y+.7,Vector2(128,128))
		var receives:=false
		for region in e.image_hurt_regions(e.position.y+.7):
			if region.position.distance_to(core)<=float(region.radius):receives=true
		check(receives,view+" real body remains hittable after excluding held tool")
		var geometry: Dictionary=e.impact_geometry(view,g.camera)
		check(geometry.radius>0 and geometry.radius<1.3,view+" bounded actual hammer radius")
	var e=fresh();advance(1.57);right(true);advance(.10)
	check(g.health==100 and g.readiness.parries==1 and e.state=="parried","actual timed parry cancels slam")
	right(false);e=fresh();right(true);advance(1.68)
	check(g.health>76 and g.health<100,"held guard reduces slam")
	right(false);e=fresh("right",2);right(true);advance(1.68)
	check(g.readiness.parries==0 and g.health>76 and g.health<100,"red attack cannot parry but can guard")
	right(false);e=fresh();advance(1.60);check(g.request_dodge(Vector3.BACK),"dodge allowed");advance(.13)
	check(g.health==100 and g.rewards.refunded,"perfect evade of physical slam hp="+str(g.health)+" refund="+str(g.rewards.refunded)+" state="+str(e.state))
	e=fresh();advance(.01);var locked: String=e.net_hauler_direction();g.player.position=e.position+Vector3(0,0,4);advance(1.65)
	check(g.health==100 and e.net_hauler_direction()==locked,"committed aim misses moving target")
	var geo: Dictionary=e.impact_geometry(locked,g.camera);g.player.position=e.position+geo.offset;advance(.08)
	check(g.health==100,"missed strike cannot hit late entrant")
	e=fresh();advance(.9);e.receive_damage(2,Vector3.ZERO);advance(.8)
	check(e.contact_count==0 and g.health==100,"hurt cancels unreleased slam")
	e=fresh();advance(.1)
	var wall:=StaticBody3D.new();wall.collision_layer=1;var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.2,4,4);shape.shape=box;wall.add_child(shape);wall.position=Vector3(g.player.position.x*.5,2,0);g.add_child(wall)
	await physics_frame;await physics_frame;advance(1.6)
	check(g.health==100 and e.contact_count==0,"wall inserted after windup blocks impact damage");wall.free()
	e=fresh();advance(.01)
	var landing: Vector3=e.position+e.attack_data.impact_offset
	g.player.position=landing+Vector3.BACK*.55
	wall=StaticBody3D.new();wall.collision_layer=1;shape=CollisionShape3D.new();box=BoxShape3D.new();box.size=Vector3(.3,4,.08);shape.shape=box;wall.add_child(shape);wall.position=landing+Vector3(0,2,.275);g.add_child(wall)
	await physics_frame;await physics_frame
	check(e.line_of_sight(g.player.position),"root ray deliberately remains clear in warning-occlusion fixture")
	check(not e.threatens(g.player.position),"landing wall clips physical threat just like warning")
	advance(1.66);check(g.health==100,"no damage in clipped-out warning sector");wall.free()
	for diagonal in [Vector3(1,0,1),Vector3(-1,0,-1),Vector3(1,0,-1),Vector3(-1,0,1)]:
		e=fresh();g.player.position=e.position+diagonal*2
		for step in 100:
			advance(.1)
			if e.attack_index>0:break
		check(e.attack_index>0,"real AI finds lateral strike position for diagonal "+str(diagonal))
	e=fresh();advance(.4);var left: float=e.telegraph_left;g.toggle_pause();advance(.7);check(e.telegraph_left==left,"pause freezes windup");g.toggle_pause()
	g.restart();check(g.drill_kind=="net_hauler" and g.enemies.size()==1 and g.health==100,"T restarts trial")
	g.start_coast();var count:=0
	for mob in g.enemies:
		if mob.kind=="net_hauler":count+=1;check(mob.has_method("net_hauler_direction"),"coast uses new actor")
	check(count==2,"coast retains two net haulers")
	g.audio.set_enabled(false);await create_timer(.2).timeout;g.free();await process_frame;finish()
func finish() -> void:
	print("NET HAULER ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
