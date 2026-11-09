extends SceneTree
var checks:=0
var failures: Array=[]
var game
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL: ",label)
func advance(seconds: float) -> void:
	var left:=seconds
	while left>.000001:
		var dt:=minf(left,1.0/120.0);game.tick(dt);left-=dt
func fresh(distance: float=2.0):
	right(false);game.start_brinehound_trial();var dog=game.enemies[0];dog.cooldown=0
	game.player.position=dog.position+Vector3.RIGHT*distance;game.test_aim=Vector3.LEFT
	return dog
func right(on: bool) -> void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=on;root.push_input(e,true)
func run() -> void:
	for path in ["brinehound_rules","brinehound_art","brinehound_enemy"]:
		check(ResourceLoader.exists("res://scripts/"+path+".gd"),path+" exists")
	if not failures.is_empty():finish();return
	var rules=load("res://scripts/brinehound_rules.gd")
	var art=load("res://scripts/brinehound_art.gd")
	var frames: SpriteFrames=art.frames()
	for view in ["left","front","back","right"]:
		check(frames.get_frame_count(view+"_run")==6,view+" six run frames")
		check(frames.get_frame_count(view+"_sequence")==6,view+" six attack phases")
		var texture: Texture2D=frames.get_frame_texture(view+"_sequence",2)
		check(texture.get_size()==Vector2(128,128) and not texture is AtlasTexture,view+" standalone128 shader mask")
	check(absf(rules.total_duration()-1.64)<.001,"sequence preserves player hit immunity with readable second tell")
	check(rules.pounce_distance(0)==0 and rules.pounce_distance(8)<=1.8,"bounded lunge")
	game=load("res://scenes/game.tscn").instantiate();game.loadout.save_path="";root.add_child(game);game.set_physics_process(false)
	game.start_coast();check(game.enemies[2].has_method("brinehound_direction"),"coast factory uses approved dog")
	check(game.enemies[0].has_method("fisherman_direction"),"approved fisherman retained")
	var dog=fresh();check(dog.health==62 and dog._stats.speed==3.0,"moderate lowHP fast movement")
	var origin: Vector3=dog.position;advance(.40)
	check(game.health==100 and dog.position.distance_to(origin)<.01 and dog.phase==0,"stationary readable crouch")
	advance(.12);check(dog.position.distance_to(origin)>.2 and dog.phase==1 and game.health==100,"real harmless airborne pounce")
	advance(.10);check(game.health==89 and dog.contact_count==1 and dog.phase==2,"first bite11 at landing")
	var landed: Vector3=dog.position;advance(.25)
	check(game.health==89 and dog.phase==3,"second bite has separate warning")
	advance(.30);check(game.health==81 and dog.contact_count==2,"second bite8 once hp="+str(game.health)+" phase="+str(dog.phase)+" contacts="+str(dog.contact_count)+" attempts="+str(dog.bite_attempts))
	check(dog.position.distance_to(landed)<.01,"second bite grounded no second lunge")
	advance(.30);check(game.health==81,"recovery cannot hit again")
	dog=fresh();advance(.54);right(true);advance(.10)
	check(game.health==100 and dog.state=="parried" and dog.phase<0,"first parry cancels combo")
	advance(.6);check(game.health==100,"cancelled second bite never fires")
	dog=fresh();right(true);advance(1.30)
	check(game.health>81 and game.health<100 and game.readiness.parries==0,"held guard reduces both bites")
	dog=fresh();advance(.54);check(game.request_dodge(Vector3.FORWARD),"dash accepted before landing");advance(.15)
	check(game.health==100 and game.rewards.refunded,"first bite precise dodge reward")
	dog=fresh();advance(.02);game.player.position=dog.position+Vector3.BACK*3;advance(1.10)
	check(game.health==100 and dog.contact_count==0,"pounce locks old position and both misses stay misses")
	dog=fresh();advance(.50);dog.receive_damage(2,Vector3.ZERO);advance(.15)
	check(dog.phase<0 and game.health==100,"damage interrupts airborne bite")
	dog=fresh();advance(.50);dog.receive_damage(10000,Vector3.ZERO);advance(.8)
	check(dog.dead and game.health==100,"death cancels both bites")
	dog=fresh();advance(.25);var frozen: Vector3=dog.position;var phase_left: float=dog.phase_left
	game.toggle_pause();advance(.6);check(dog.position==frozen and dog.phase_left==phase_left,"pause freezes pounce timeline");game.toggle_pause()
	game.restart();check(game.drill_kind=="brinehound" and game.enemies.size()==1 and game.flasks.charges==3,"trial T reset retained")
	dog=fresh();game.tick(1.7)
	check(game.health==81 and dog.bite_attempts==2 and dog.contact_count==2,"coarse game tick preserves exactly both contacts hp="+str(game.health)+" attempts="+str(dog.bite_attempts)+" contacts="+str(dog.contact_count))
	dog=fresh();advance(1.07);right(true);advance(.12)
	check(game.health==89 and game.readiness.parries==1 and dog.state=="parried","second bite independently parryable")
	dog=fresh();advance(1.07);check(game.request_dodge(Vector3.FORWARD),"second bite dash accepted");advance(.13)
	check(game.health==89 and game.rewards.refunded,"second bite independently perfect-dodgeable")
	dog=fresh();advance(.02);game.player.position=dog.position+Vector3.BACK*3;advance(.60)
	game.player.position=dog.position+Vector3.RIGHT*.7;advance(.05)
	check(game.health==100,"missed first contact does not hit late entrant")
	advance(.5);check(game.health==92 and dog.contact_count==1,"second strike remains independent after first miss")
	dog=fresh();var wall_start: Vector3=dog.position;advance(.02)
	var wall:=StaticBody3D.new();wall.collision_layer=1
	var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.2,3,3);collision.shape=box;wall.add_child(collision)
	wall.position=wall_start+Vector3(.9,1.5,0);game.add_child(wall);await physics_frame;await physics_frame
	advance(1.20)
	check(dog.position.x<wall_start.x+.55,"swept pounce cannot tunnel wall")
	check(game.health==100 and dog.contact_count==0,"wall blocks both bites")
	wall.free()
	dog=fresh();advance(.50);dog.position=dog.home_position+Vector3.RIGHT*11;advance(.10)
	check(dog.phase<0 and dog.returning and game.health==100,"leash interrupts airborne combo")
	game.start_fisherman_trial();check(game.enemies[0].has_method("fisherman_direction"),"fisherman trial retained")
	game.audio.set_enabled(false);await create_timer(.2).timeout;game.free();await process_frame;finish()
func finish() -> void:
	print("BRINEHOUND INTEGRATION: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
