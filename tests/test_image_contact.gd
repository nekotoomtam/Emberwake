extends SceneTree
var checks:=0
var failures: Array=[]
var game
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
	var profile=load("res://scripts/projectile_image_geometry.gd")
	for radius in [2,5]:
		var image:=Image.create(16,16,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT);image.fill_rect(Rect2i(7,8-radius,2,radius*2),Color.WHITE)
		check(profile.cross_radius(ImageTexture.create_from_image(image),Vector2(8,8))==radius,"body width derives from actual opaque pixels radius="+str(radius))
	game=load("res://scenes/game.tscn").instantiate();game.loadout.save_path="";root.add_child(game);game.set_physics_process(false);game.start_crewman_trial()
	var e=game.enemies[0]
	for direction: Vector3 in [Vector3.RIGHT,Vector3.BACK,Vector3.LEFT,Vector3.FORWARD]:
		game.clear_hostile_projectiles();game.shoot(Vector3(0,1,0),direction,22,true,e,1,9)
		var bolt=game.projectiles[0].node;var quad: QuadMesh=bolt.mesh
		# Reference pixel pin is the opaque leading edge of the authored spear,
		# not the center of its long shaft. Raw width64, last opaque column60.
		var local_tip:=Vector3((61.0/64-.5)*quad.size.x,(.5-8.5/16)*quad.size.y,0)+quad.center_offset
		check((bolt.global_transform*local_tip).distance_to(bolt.global_position)<.001,"hostile visible harpoon head equals collision point "+str(direction))
	game.clear_hostile_projectiles()
	var spit=game.spawn_enemy("spitter",Vector3(5,.03,0));game.shoot(Vector3(0,1,0),Vector3.RIGHT,9,true,spit,1,6)
	var glob=game.projectiles[0].node;var glob_quad: QuadMesh=glob.mesh
	var glob_pin:=Vector3((8.5/16-.5)*glob_quad.size.x,(.5-8.5/16)*glob_quad.size.y,0)+glob_quad.center_offset
	check((glob.global_transform*glob_pin).distance_to(glob.global_position)<.001,"hostile round head center matches point; decorative tail excluded")
	for height: float in [.6,1.7,2.2]:
		game.clear_hostile_projectiles();game.player.position=Vector3.ZERO
		game.shoot(Vector3(-1.15,height,0),Vector3.RIGHT,11,true);game._update_projectiles(.000001)
		check(game.projectiles[0].node.material_override.albedo_color.is_equal_approx(Color("fffbd3")),"parry-ready color uses arrival time independent of visual height "+str(height))
	game.clear_hostile_projectiles()
	var manager=game.staff_flight
	for radius: float in [.12,.20,.30]:
		manager.clear();manager.spawn_fireball(Vector3(0,.8,0),Vector3.RIGHT,{"damage":20,"projectile_radius":radius,"projectile_range":6,"projectile_speed":5.5},game.camera)
		for i in 3:
			var entry: Dictionary=manager.active[0];var flame=entry.node.get_node("flame")
			var actual: float=flame.global_basis.x.length()*flame.pixel_size*8
			check(absf(actual-float(entry.radius))<.001,"fire image core radius "+str(radius)+" aftertick"+str(i)+" got="+str(actual))
			manager.tick(.01,[],game.get_world_3d(),Callable(),game.camera)
	for visual: String in ["pistol","rifle"]:
		for direction: Vector3 in [Vector3.RIGHT,Vector3.BACK,Vector3.LEFT,Vector3.FORWARD]:
			manager.clear();var spec:={"element":"physical","damage":18,"projectile_radius":.10,"projectile_range":7,"projectile_speed":18}
			if visual=="rifle":spec.projectile_visual="rifle"
			manager.spawn_fireball(Vector3(0,.8,0),direction,spec,game.camera)
			for i in 3:
				var entry: Dictionary=manager.active[0];var bullet=entry.node.get_node("bullet")
				var radius_: float=bullet.global_basis.y.length()*bullet.pixel_size*(1 if visual=="rifle" else 4)
				check(absf(radius_-float(entry.radius))<.001,visual+" image contact width matches sweep "+str(direction)+" tick"+str(i))
				var pixel_world: Vector3=load("res://scripts/projectile_image_geometry.gd").pixel_world(bullet,Vector2(28,12))
				check(pixel_world.distance_to(entry.node.global_position)<.001,visual+" core at collision root")
				manager.tick(.01,[],game.get_world_3d(),Callable(),game.camera)
	manager.clear();game.audio.set_enabled(false);await create_timer(.2).timeout;game.free();await process_frame
	print("IMAGE CONTACT: ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
