extends SceneTree

var failures: Array[String] = []
var checks := 0
var rifle_art: Script

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(FileAccess.get_sha256("res://scripts/pixel_art.gd").to_upper() == "BD3073938A3ADA849FEAB955067EB410E5ECF387DCE289AE9B2653A962A28047", "accepted heroine and fireball pixel source remains unchanged")
	_check(FileAccess.file_exists("res://scripts/rifle_art.gd"), "dedicated original long rifle art exists")
	if FileAccess.file_exists("res://scripts/rifle_art.gd"):
		rifle_art = load("res://scripts/rifle_art.gd")
		_check(rifle_art != null and rifle_art.can_instantiate(), "rifle art loads")
		if rifle_art != null and rifle_art.can_instantiate():
			_test_art()
	await _test_rigid_rifle()
	_check(FileAccess.file_exists("res://scripts/casing_fx.gd"), "dedicated visual-only casing manager exists")
	if FileAccess.file_exists("res://scripts/casing_fx.gd"):
		await _test_casings()
	_finish()

func _test_art() -> void:
	var texture: Texture2D = rifle_art.texture()
	var geometry: Dictionary = rifle_art.geometry()
	var image := texture.get_image()
	_check(texture is ImageTexture and texture == rifle_art.texture(), "rifle reuses one cached native pixel texture")
	_check(texture.get_size() == Vector2(128, 40), "long gun has room for stock and extended steel barrel")
	_check(geometry.pivot == Vector2(26, 22) and geometry.tip == Vector2(122, 22), "tiny hand center and muzzle define a rigid +X rifle")
	_check(image.get_pixel(0, 0).a == 0.0 and image.get_pixel(127, 39).a == 0.0, "rifle retains transparent padding")
	var skin := 0
	var wood := 0
	var brass := 0
	var steel := 0
	var crisp := true
	var clustered := true
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			crisp = crisp and (color.a == 0.0 or color.a == 1.0)
			if color.is_equal_approx(Color("ffd4ad")): skin += 1
			if color.is_equal_approx(Color("83523e")): wood += 1
			if color.is_equal_approx(Color("c3a069")): brass += 1
			if color.is_equal_approx(Color("8ca6b6")): steel += 1
			clustered = clustered and color.is_equal_approx(image.get_pixel((x / 4) * 4, (y / 4) * 4))
	_check(crisp and clustered, "rifle uses crisp four-pixel clusters matching the heroine")
	_check(skin == 16 and image.get_pixel(26, 22).is_equal_approx(Color("ffd4ad")), "one tiny attached hand contains the rifle pivot")
	_check(wood >= 96 and brass >= 64 and steel >= 128, "wood stock, brass receiver, and long steel barrel remain readable")
	var connected := true
	for x in range(26, 123): connected = connected and image.get_pixel(x, 22).a > 0.0
	_check(connected, "hand, receiver and muzzle are one continuous rigid silhouette")
	var side := rifle_art.texture(false).get_image() as Image
	var side_pixels := side.get_data()
	for rear: bool in [false, true]:
		var view: Texture2D = rifle_art.end_view(rear)
		var end := view.get_image()
		_check(view == rifle_art.end_view(rear) and view.get_size() == texture.get_size(), "end view reuses the rifle's canvas and cache")
		_check(end.get_pixel(26, 22).a == 1.0 and end.get_pixel(122, 22).a == 1.0, "end view retains the grip and muzzle anchors")
		_check(end.get_pixel(85, 21).is_equal_approx(side.get_pixel(85, 21)), "barrel band stays at the same position and color in every view")
		_check(end.get_pixel(16, 24).is_equal_approx(side.get_pixel(16, 24)), "end view keeps the same wooden stock")
	_check(rifle_art.end_view(false) != rifle_art.end_view(true), "front muzzle and rear stock have separate drawings")
	_check(rifle_art.texture(false).get_image().get_data() == side_pixels, "end views leave the original side art intact")
	geometry.pivot = Vector2.ZERO
	_check(rifle_art.geometry().pivot == Vector2(26, 22), "callers cannot mutate cached rifle geometry")

func _test_rigid_rifle() -> void:
	var hero = load("res://scripts/hero_visual.gd").new()
	var accepted: bool = hero.set_weapon_family("rifle")
	_check(accepted, "hero accepts rifle before entering the scene")
	if not accepted or rifle_art == null:
		hero.free()
		return
	root.add_child(hero)
	hero.position = Vector3(2, 0, -3)
	var camera := _camera()
	await process_frame
	_check(hero.body.sprite_frames == load("res://scripts/pixel_art.gd").frames("player"), "rifle retains original heroine frames")
	_check(hero.weapon.texture == rifle_art.texture(), "rifle selects its dedicated original pixel art")
	for direction: Vector3 in [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]:
		for pose: Dictionary in [{"pitch": 0.0, "radius": 0.42, "height": 0.80}, {"pitch": 0.10, "radius": 0.42, "height": 0.80}, {"pitch": -0.18, "radius": 0.34, "height": 0.72}]:
			var pitch: float = pose.pitch
			var grip: Vector3 = hero.position + direction * float(pose.radius) + Vector3.UP * float(pose.height)
			var tip: Vector3 = grip + (direction * cos(pitch) + Vector3.UP * sin(pitch)) * 1.35
			var sample := {"phase": "reload" if pitch < 0.0 else "active", "angle": atan2(direction.z, direction.x), "radius": pose.radius, "grip_height": pose.height, "blade_length": 1.35, "pitch": pitch, "screen_roll": PI}
			hero.update_pose(camera, direction, false, sample, 1.77, 0.0, 0.0, 0.0)
			var points: Dictionary = hero.get_blade_points()
			_near_vec(points.grip, grip, "rifle hand follows the supplied world-space grip at four aims")
			_near_vec(points.tip, tip, "rifle pitch tilts the rigid muzzle and ignores screen roll")
			_near(points.grip.distance_to(points.tip), 1.35, "rifle physical length remains 1.35 through lift and reload")
			var mesh := _mesh_points(hero.weapon, Vector2(26, 22), Vector2(122, 22))
			_near_screen(mesh.grip, grip, camera, "actual rifle mesh keeps its tiny hand attached")
			_near_screen(mesh.tip, tip, camera, "actual rifle mesh follows physical projection")
			_near_vec(hero.body.global_position - hero.body.global_basis.y * (48.0 * 0.018), hero.position, "rifle pose preserves heroine ground anchor")
	hero.update_pose(camera, Vector3.RIGHT, false, {"phase": "idle", "angle": 0.0}, 1.77, 0.0, 0.0, 2.0)
	_near_vec(hero.get_blade_points().grip, hero.position + Vector3(0.19, 0.79, 0), "rifle low-ready grip stays near shoulder")
	_near_vec(hero.get_blade_points().tip, hero.position + Vector3(.19+1.35*cos(-.19), .79+1.35*sin(-.19), 0), "rifle low-ready keeps full barrel length below aim")
	hero.set_weapon_family("pistol")
	hero.update_pose(camera, Vector3.RIGHT, false, {"phase": "idle", "angle": 0.0}, 1.2, 0.0, 0.0, 0.0)
	_near(hero.get_blade_points().grip.distance_to(hero.get_blade_points().tip), 0.72, "accepted pistol retains its shorter physical length")
	for family: String in ["sword", "greatsword", "mace", "staff", "pistol", "rifle"]:
		_check(hero.set_weapon_family(family), "all accepted families remain selectable: " + family)
	_check(not hero.set_weapon_family("missing"), "unknown family remains rejected")
	hero.free()
	camera.free()

func _test_casings() -> void:
	var script: Script = load("res://scripts/casing_fx.gd")
	_check(script != null and script.can_instantiate(), "casing manager loads")
	if script == null or not script.can_instantiate(): return
	var fx = script.new()
	_check(fx is Node3D and fx.has_method("spawn") and fx.has_method("tick") and fx.has_method("clear"), "owner can spawn, tick and clear visual-only casings")
	root.add_child(fx)
	var camera := _camera()
	await process_frame
	for direction: Vector3 in [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]:
		fx.clear()
		fx.spawn(Vector3(2, 0.8, -3), direction, camera)
		_check(fx.spawned_count == 1 and fx.active.size() == 1 and fx.get_child_count() == 1, "one successful rifle shot creates exactly one casing")
		if fx.active.is_empty(): continue
		var entry: Dictionary = fx.active[0]
		var sprite: Sprite3D = entry.sprite
		var velocity: Vector3 = entry.velocity
		_check(velocity.dot(direction.cross(Vector3.UP)) > 0.8 and velocity.y > 1.0 and absf(velocity.dot(direction)) < 0.3, "casing ejects to the shot's side and upward, not along the projectile")
		_near_vec(sprite.global_position, Vector3(2, 0.8, -3), "casing spawns at the supplied receiver location")
		_check(sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST and not sprite.shaded, "small brass shell stays crisp and visible without a light")
		_check(sprite.pixel_size * sprite.texture.get_width() >= 0.10 and sprite.pixel_size * sprite.texture.get_width() <= 0.20, "brass casing is small but readable")
		_check(sprite.get_child_count() == 0 and sprite is Sprite3D, "shell is a single visual sprite with no light, collision, damage or pickup children")
		var still: Vector3 = sprite.global_position
		await process_frame
		_near_vec(sprite.global_position, still, "manager does not advance casings when its owner stops ticking")
		_near(float(entry.age), 0.0, "unticked casing lifetime stays frozen during pause")
		fx.tick(0.10, camera)
		_check(float(fx.active[0].age) > 0.09 and fx.active[0].velocity.y < velocity.y, "owner tick advances age and gravity")
		_check((sprite.global_position - still).dot(direction.cross(Vector3.UP)) > 0.08, "ejected shell visibly travels sideways")
		_check(absf(camera.global_basis.x.dot(sprite.global_basis.y)) > 0.01, "casing visibly spins in the screen plane")
	fx.clear()
	fx.spawn(Vector3(0, 0.8, 0), Vector3.RIGHT, camera)
	var texture: Texture2D = fx.active[0].sprite.texture
	var image := texture.get_image()
	_check(image.get_pixel(0, 0).a == 0.0 and image.get_pixel(image.get_width() - 1, image.get_height() - 1).a == 0.0, "casing texture keeps transparent padding")
	var bright := 0
	var brass_pixels := 0
	var crisp := true
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			crisp = crisp and (color.a == 0.0 or color.a == 1.0)
			if color.a > 0.0 and color.r > 0.9 and color.g > 0.7: bright += 1
			if color.a > 0.0 and color.r > color.g and color.g > color.b: brass_pixels += 1
	_check(crisp and bright > 0 and brass_pixels >= 12, "original opaque brass pixels have a readable warm highlight without flame glow")
	var survivor: Sprite3D = fx.active[0].sprite
	for index in 80:
		fx.tick(0.02, camera)
		if not fx.active.is_empty():
			_check(fx.active[0].sprite.global_position.y >= 0.0349, "visual casing bounces above the floor")
	_check(fx.active.size() == 1 and int(fx.active[0].bounces) > 0, "casing visibly bounces before its lifetime expires")
	_check(survivor.modulate.a > 0.0 and survivor.modulate.a < 0.9, "casing fades near the end of its two-second lifetime")
	fx.tick(0.50, camera)
	_check(fx.active.is_empty() and not is_instance_valid(survivor) and fx.get_child_count() == 0, "expired casing is removed and freed after about two seconds")
	fx.clear()
	for index in 40:
		fx.spawn(Vector3(0, 0.8, 0), Vector3.RIGHT, camera)
	_check(fx.spawned_count == 40 and fx.active.size() == 32 and fx.get_child_count() == 32, "repeated fire preserves the counter while bounding active shells at 32")
	var cached := true
	for entry: Dictionary in fx.active: cached = cached and entry.sprite.texture == texture
	_check(cached, "all shells reuse the same cached pixel texture")
	fx.clear()
	_check(fx.active.is_empty() and fx.spawned_count == 0 and fx.get_child_count() == 0, "clear frees every shell and resets native proof counter")
	fx.spawn(Vector3(INF, 0.8, 0), Vector3.RIGHT, camera)
	fx.spawn(Vector3.ZERO, Vector3(NAN, 0, 0), camera)
	fx.spawn(Vector3.ZERO, Vector3.ZERO, camera)
	fx.spawn(Vector3.ZERO, Vector3.UP, camera)
	fx.spawn(Vector3.ZERO, Vector3.RIGHT, null)
	_check(fx.active.is_empty() and fx.spawned_count == 0, "invalid spawn vectors or missing camera do not create corrupt shells")
	fx.spawn(Vector3(0, 0.8, 0), Vector3.RIGHT, camera)
	var valid_sprite: Sprite3D = fx.active[0].sprite
	var valid_position := valid_sprite.global_position
	for delta: float in [NAN, INF, -0.1]: fx.tick(delta, camera)
	fx.tick(0.1, null)
	_near_vec(valid_sprite.global_position, valid_position, "invalid deltas or camera do not corrupt visual positions")
	_near(float(fx.active[0].age), 0.0, "invalid ticks do not consume casing lifetime")
	fx.tick(0.10, camera)
	_check(valid_sprite.global_position.is_finite(), "valid owner tick still works after rejected inputs")
	fx.clear()
	fx.free()
	camera.free()

func _camera() -> Camera3D:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0, 12.5, 11.5)
	camera.look_at(Vector3.ZERO)
	return camera

func _mesh_points(sprite: Sprite3D, pivot: Vector2, tip: Vector2) -> Dictionary:
	var faces: PackedVector3Array = sprite.generate_triangle_mesh().get_faces()
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for vertex: Vector3 in faces:
		low = low.min(vertex)
		high = high.max(vertex)
	var size := sprite.texture.get_size()
	return {"grip": sprite.global_transform * Vector3(lerpf(low.x, high.x, pivot.x / size.x), lerpf(high.y, low.y, pivot.y / size.y), 0.0), "tip": sprite.global_transform * Vector3(lerpf(low.x, high.x, tip.x / size.x), lerpf(high.y, low.y, tip.y / size.y), 0.0)}

func _near_screen(actual: Vector3, expected: Vector3, camera: Camera3D, message: String) -> void:
	_near(camera.global_basis.x.dot(actual), camera.global_basis.x.dot(expected), message + " screen x")
	_near(camera.global_basis.y.dot(actual), camera.global_basis.y.dot(expected), message + " screen y")

func _near_vec(actual: Vector3, expected: Vector3, message: String) -> void:
	_check(actual.distance_to(expected) < 0.0001, "%s: got %s expected %s" % [message, actual, expected])

func _near(actual: float, expected: float, message: String) -> void:
	_check(absf(actual - expected) < 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("RIFLE_VISUAL_PASS: %d checks; original heroine; wood/brass/steel rifle; fixed hand and rigid actual mesh at four aims; bounded brass casing ejection, gravity, spin, bounce, fade, freeze and reset" % checks)
	else:
		for failure in failures: push_error("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
