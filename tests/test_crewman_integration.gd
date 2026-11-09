extends SceneTree
var failures: Array=[]
var checks:=0
var game
const VIEWS:={"left":Vector3.LEFT,"right":Vector3.RIGHT,"front":Vector3.BACK,"back":Vector3.FORWARD}
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);printerr("FAIL: ",label)
func advance(time_: float) -> void:
	while time_>.000001:
		var dt:=minf(time_,1.0/120);game.tick(dt);time_-=dt
func right(on: bool) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=on;root.push_input(event,true)
func fresh(view: String="right",distance: float=4.0):
	right(false);game.start_crewman_trial();var enemy=game.enemies[0];enemy.cooldown=0
	enemy.position=Vector3(0,.03,0);enemy.home_position=enemy.position;game.player.position=enemy.position+VIEWS[view]*distance;game.test_aim=-VIEWS[view]
	return enemy
func flight_time() -> float:
	var p: Dictionary=game.projectiles[0];var aim: Vector3=game.player.position-p.node.position;aim.y=0
	return maxf(0,(aim.length()-.39)/5.5)
func run() -> void:
	for name in ["crewman_art","crewman_enemy"]:check(ResourceLoader.exists("res://scripts/"+name+".gd"),name+" exists")
	if not failures.is_empty():finish();return
	var art=load("res://scripts/crewman_art.gd");var frames: SpriteFrames=art.frames()
	for view: String in VIEWS:
		check(frames.get_frame_count(view+"_walk")==6,view+" six walk frames")
		check(frames.get_frame_count(view+"_windup")==3 and frames.get_frame_count(view+"_attack")==1,view+" windup and empty release pose")
		var t: Texture2D=frames.get_frame_texture(view+"_attack",0)
		check(t.get_size()==Vector2(128,128) and not t is AtlasTexture,view+" standalone128 vision alpha")
	game=load("res://scenes/game.tscn").instantiate();game.loadout.save_path="";root.add_child(game);game.set_physics_process(false)
	game.start_coast();check(game.enemies[6].has_method("crewman_direction"),"coast replaces old ordinary gunner with hand thrower")
	check(game.enemies[0].has_method("fisherman_direction") and game.enemies[2].has_method("brinehound_direction"),"previous approved actors kept")
	for view: String in VIEWS:
		var e=fresh(view);var start: Vector3=e.position;advance(.95)
		check(e.state=="windup" and e.sprite.animation==view+"_windup" and e.sprite.frame==2,view+" readable held windup")
		check(game.projectiles.is_empty() and game.health==100 and e.position.distance_to(start)<.01,view+" no early projectile or damage")
		advance(.28)
		check(e.throws==1 and game.projectiles.size()==1 and e.sprite.animation==view+"_attack",view+" one projectile at empty-hand release")
		check(not e.sprite.flip_h,view+" no mirror")
		if not game.projectiles.is_empty():
			check(game.projectiles[0].node.material_override.albedo_texture==art.projectile(),view+" simple hand harpoon artwork")
			advance(flight_time()+.04)
		check(game.health==78 and game.projectiles.is_empty(),view+" actual projectile22 exactly once hp="+str(game.health))
		advance(.5);check(e.throws==1 and game.health==78,view+" long recovery no duplicate")
	var enemy=fresh();check(enemy.health==75 and enemy._stats.speed==1.45,"retained ordinary stats")
	advance(.03);var aim: Vector3=enemy.target_point;game.player.position+=Vector3.BACK*3;advance(2.0)
	check(enemy.throws==1 and game.health==100 and enemy.target_point==aim,"committed old aim can be dodged by moving")
	enemy=fresh();advance(1.23);var wait:=flight_time();advance(maxf(0,wait-.07));right(true);advance(.15)
	check(game.readiness.parries==1 and game.health==100 and enemy.state=="parried","actual timed projectile parry")
	enemy=fresh();right(true);advance(2.0);check(game.health>78 and game.health<100 and game.readiness.parries==0,"held guard reduces projectile")
	enemy=fresh();advance(1.23);wait=flight_time();advance(maxf(0,wait-.07));check(game.request_dodge(Vector3.FORWARD),"dodge accepted");advance(.15)
	check(game.health==100 and game.rewards.refunded,"actual projectile perfect evade")
	enemy=fresh();advance(.95);enemy.receive_damage(2,Vector3.ZERO);advance(.60)
	check(enemy.throws==0 and game.projectiles.is_empty(),"hurt cancels unreleased spear")
	enemy=fresh();advance(.95);enemy.receive_damage(10000,Vector3.ZERO);advance(.8);check(enemy.dead and enemy.throws==0,"death cancels unreleased spear")
	enemy=fresh();advance(.3);var clock: float=enemy.telegraph_left;game.toggle_pause();advance(.7);check(enemy.telegraph_left==clock,"pause freezes throw");game.toggle_pause()
	game.restart();check(game.drill_kind=="crewman" and game.enemies.size()==1 and game.flasks.charges==3,"T resets new trial")
	enemy=fresh();game.tick(2.2);check(enemy.throws==1 and game.health==78,"coarse Game tick keeps release damage once hp="+str(game.health))
	enemy=fresh();advance(.9)
	var wall:=StaticBody3D.new();wall.collision_layer=1;var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.2,4,6);col.shape=box;wall.add_child(col);wall.position=Vector3(2,2,0);game.add_child(wall);await physics_frame;await physics_frame
	advance(1.1);check(enemy.throws==1 and game.health==100 and game.projectiles.is_empty(),"swept thrown harpoon stopped by new wall")
	wall.free()
	enemy=fresh();enemy.engaged=true;enemy.position=Vector3.LEFT*11;advance(.05);check(enemy.returning and enemy.throws==0,"leash prevents throw")
	enemy=fresh("right",2);enemy.cooldown=20;var origin: Vector3=enemy.position;advance(.2);check(enemy.position.distance_to(origin)>.20 and enemy.sprite.animation.ends_with("walk"),"close retreat uses real walking animation")
	game.start_brinehound_trial();check(game.enemies[0].has_method("brinehound_direction"),"dog trial retained")
	game.start_fisherman_trial();check(game.enemies[0].has_method("fisherman_direction"),"fisherman trial retained")
	game.audio.set_enabled(false);await create_timer(.2).timeout;game.free();await process_frame;finish()
func finish() -> void:
	print("CREWMAN INTEGRATION: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
