extends SceneTree
var checks := 0
var failures: Array = []
var g
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ",label)
func advance(duration: float) -> void:
	var remaining := duration
	while remaining>0.000001:
		var dt := minf(remaining,1.0/120.0)
		g.tick(dt);remaining-=dt
func run() -> void:
	check(ResourceLoader.exists("res://scripts/fisherman_art.gd"),"approved art controller exists")
	check(ResourceLoader.exists("res://scripts/fisherman_enemy.gd"),"dedicated fisherman actor exists")
	if failures.size()>0: finish();return
	var art=load("res://scripts/fisherman_art.gd")
	var frames: SpriteFrames=art.frames()
	for direction in ["left","front","back","right"]:
		check(frames.get_frame_count(direction+"_walk")==6,direction+" six walk frames")
		check(frames.get_frame_count(direction+"_windup")==3,direction+" readable anticipation")
		check(frames.get_frame_count(direction+"_attack")==1,direction+" contact frame")
		check(frames.get_frame_count(direction+"_recover")==2,direction+" recovery frames")
		var texture: Texture2D=frames.get_frame_texture(direction+"_attack",0)
		check(texture.get_size()==Vector2(128,128),direction+" real128 frame")
		check(not texture is AtlasTexture,direction+" sight shader receives exact frame not full atlas")
	var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,12.5,11.5);camera.look_at(Vector3.ZERO)
	for data in [[Vector3.RIGHT,"right"],[Vector3.LEFT,"left"],[Vector3.BACK,"front"],[Vector3.FORWARD,"back"]]:
		check(art.direction(data[0],camera)==data[1],"camera direction "+data[1])
	camera.free()
	g=load("res://scenes/game.tscn").instantiate();g.loadout.save_path="";root.add_child(g);g.set_physics_process(false)
	g.start_coast();var fish=g.enemies[0]
	check(fish.has_method("fisherman_direction"),"coast spawns new actor")
	check(not fish.sprite.flip_h,"no whole-sprite mirror")
	check(absf(fish._stats.speed-1.0)<.001,"slow live movement speed")
	check(g.enemies[2].kind=="brinehound" and not g.enemies[2].has_method("fisherman_direction"),"other monster unchanged")
	g.start_fisherman_trial();check(g.mode=="practice" and g.enemies.size()==1 and g.drill_kind=="fisherman","focused practice entry")
	fish=g.enemies[0];fish.cooldown=0;g.player.position=fish.position+Vector3.RIGHT*.8;g.test_aim=Vector3.LEFT
	advance(.01);check(fish.state=="windup","live AI starts anticipation")
	var angle: float=fish.attack_angle;g.player.position=fish.position+Vector3.BACK*.8
	advance(.45);check(fish.attack_angle==angle and fish.fisherman_direction()=="right","committed attack facing locked")
	g.player.position=fish.position+Vector3.RIGHT*.8
	advance(1.13);check(g.health==100 and fish.sprite.animation=="right_windup","no damage before windup end")
	advance(.04);check(g.health==86 and fish.contact_count==1,"one14 damage hit at contact")
	check(fish.sprite.animation=="right_attack","painted contact frame at actual damage")
	advance(.2);check(g.health==86 and fish.sprite.animation=="right_recover","no repeated hit in recovery")
	fish.receive_parry();advance(.05);check(fish.state=="parried" and fish.sprite.animation.ends_with("_hit"),"parry cancels to same direction hit")
	fish.receive_damage(10000,Vector3.ZERO);fish.tick(.2,g);check(fish.dead and fish.sprite.animation.ends_with("_death"),"same character death fade")
	fish=fresh();advance(1.50);mouse_right(true);advance(.15)
	check(g.health==100 and g.readiness.parries==1 and fish.state=="parried","new actor actual timed parry")
	fish=fresh();mouse_right(true);advance(1.65)
	check(g.health>86 and g.health<100 and g.readiness.parries==0,"new actor held guard reduces damage")
	fish=fresh();advance(1.55);check(g.request_dodge(Vector3.FORWARD),"new actor dodge allowed");advance(.2)
	check(g.health==100 and g.rewards.refunded,"new actor perfect dodge contact reward")
	fish=fresh();advance(.01);g.player.position=fish.position+Vector3.BACK*.8;advance(1.61)
	check(g.health==100,"committed strike misses target moved sideways")
	g.player.position=fish.position+Vector3.RIGHT*.8;advance(.03)
	check(g.health==100,"missed impact cannot hit a late entrant")
	fish=fresh();advance(.01)
	check(fish.threatens(fish.position+Vector3.RIGHT*1.2),"painted forward short strike covers tip")
	check(not fish.threatens(fish.position+Vector3.RIGHT*1.8),"strike cannot hit beyond tip")
	check(not fish.threatens(fish.position+Vector3.LEFT*.8),"strike cannot hit behind")
	g.restart();check(g.drill_kind=="fisherman" and g.anatomy.arm_count()==2 and g.flasks.charges==3,"trial restart restores player and trial")
	fish=fresh();g.player.position=fish.position+Vector3(.7,0,.7);var before_diagonal: Vector3=fish.position
	advance(.03);check(fish.state=="chase" and fish.position.distance_to(before_diagonal)>.01,"diagonal target is approached instead of repeated empty strikes")
	advance(.6);check(fish.state=="windup","diagonal target becomes aligned before committing")
	advance(1.7);check(g.health<100,"stationary diagonal target can actually be hit")
	g.start_run(true);check(g.drill_kind=="" and g.mode=="practice","legacy practice retained")
	for child in g.audio.get_children():
		if child is AudioStreamPlayer:child.stop()
	await create_timer(.2).timeout
	g.free();await process_frame
	finish()
func mouse_right(on: bool) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=on;root.push_input(event,true)
func fresh():
	mouse_right(false);g.start_fisherman_trial();var fish=g.enemies[0];fish.cooldown=0
	g.player.position=fish.position+Vector3.RIGHT*.8;g.test_aim=Vector3.LEFT
	return fish
func finish() -> void:
	print("FISHERMAN INTEGRATION: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
