extends SceneTree

var failures: Array[String] = []
var checks := 0
var pistol_art: Script

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(FileAccess.get_sha256("res://scripts/pixel_art.gd").to_upper() == "BD3073938A3ADA849FEAB955067EB410E5ECF387DCE289AE9B2653A962A28047", "accepted heroine pixels remain unchanged")
	_check(FileAccess.file_exists("res://scripts/pistol_art.gd"), "dedicated original pistol art exists")
	if FileAccess.file_exists("res://scripts/pistol_art.gd"):
		pistol_art = load("res://scripts/pistol_art.gd")
		_check(pistol_art != null and pistol_art.can_instantiate(), "pistol art loads")
		if pistol_art != null and pistol_art.can_instantiate():
			_test_art()
	await _test_projected_pistol()
	_check(FileAccess.file_exists("res://scripts/bullet_visual.gd"), "physical bullet visual exists")
	if FileAccess.file_exists("res://scripts/bullet_visual.gd"):
		await _test_bullet()
	_finish()

func _test_art() -> void:
	var texture: Texture2D = pistol_art.texture()
	var geometry: Dictionary = pistol_art.geometry()
	var image := texture.get_image()
	_check(texture is ImageTexture and texture == pistol_art.texture(), "pistol reuses its cached native pixel texture")
	_check(texture.get_size() == Vector2(64, 36), "small gun has a compact pixel canvas")
	_check(geometry.pivot == Vector2(10, 18) and geometry.tip == Vector2(58, 18), "hand center and muzzle define the rigid +X pistol")
	_check(image.get_pixel(0, 0).a == 0.0 and image.get_pixel(63, 35).a == 0.0, "gun retains transparent padding")
	var skin := 0
	var brass := 0
	var steel := 0
	var crisp := true
	var clustered := true
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			crisp = crisp and (color.a == 0.0 or color.a == 1.0)
			if color.is_equal_approx(Color("ffd4ad")): skin += 1
			if color.is_equal_approx(Color("c3a069")): brass += 1
			if color.is_equal_approx(Color("8ca6b6")): steel += 1
			clustered = clustered and color.is_equal_approx(image.get_pixel((x / 4) * 4, (y / 4) * 4))
	_check(crisp and clustered, "gun uses crisp four-pixel clusters matching accepted heroine art")
	_check(skin == 16 and image.get_pixel(10, 18).is_equal_approx(Color("ffd4ad")), "one tiny attached hand contains the actual spin pivot")
	_check(brass >= 64 and steel >= 64, "brass receiver and blue steel barrel remain readable")
	var connected := true
	for x in range(10, 59): connected = connected and image.get_pixel(x, 18).a > 0.0
	_check(connected, "tiny hand, receiver and muzzle form one continuous rigid silhouette")
	var profile := pistol_art.texture(false).get_image() as Image
	var original := profile.get_data()
	for rear: bool in [false, true]:
		var view: Texture2D = pistol_art.end_view(rear)
		var pixels := view.get_image()
		_check(view == pistol_art.end_view(rear) and view.get_size() == texture.get_size(), "end view uses the same cached canvas")
		_check(pixels.get_pixel(10, 18).a == 1.0 and pixels.get_pixel(58, 18).a == 1.0, "end view retains the grip and muzzle")
		_check(pixels.get_pixel(20, 15).is_equal_approx(profile.get_pixel(20, 15)), "brass receiver matches the side art")
	_check(pistol_art.end_view(false) != pistol_art.end_view(true), "front and rear are separate drawings")
	_check(pistol_art.texture(false).get_image().get_data() == original, "end view painting does not mutate the side art")
	geometry.pivot = Vector2.ZERO
	_check(pistol_art.geometry().pivot == Vector2(10, 18), "caller cannot mutate cached gun geometry")

func _test_projected_pistol() -> void:
	var hero = load("res://scripts/hero_visual.gd").new()
	var accepted: bool = hero.set_weapon_family("pistol")
	_check(accepted, "hero accepts pistol before entering scene")
	if not accepted or pistol_art == null:
		hero.free()
		return
	root.add_child(hero)
	hero.position = Vector3(2, 0, -3)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0, 12.5, 11.5)
	camera.look_at(Vector3.ZERO)
	await process_frame
	_check(hero.body.sprite_frames == load("res://scripts/pixel_art.gd").frames("player"), "pistol uses unchanged original heroine frames")
	_check(hero.weapon.texture == pistol_art.texture(), "pistol family selects its dedicated original gun art")
	var aims: Array[Vector3] = [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD, Vector3(1, 0, 1).normalized(), Vector3(-1, 0, 1).normalized(), Vector3(-1, 0, -1).normalized(), Vector3(1, 0, -1).normalized()]
	for direction: Vector3 in aims:
		var grip: Vector3 = hero.position + direction * 0.48 + Vector3.UP * 0.80
		var projected := Vector2(camera.global_basis.x.dot(direction), camera.global_basis.y.dot(direction))
		var depth: Vector3 = camera.global_basis.z * camera.global_basis.z.dot(direction) * 0.72
		for roll: float in [0.0, TAU * 0.125, TAU * 0.25, TAU * 0.375, TAU * 0.5, TAU * 0.625, TAU * 0.75, TAU * 0.875, TAU]:
			var sample := {"phase": "reload", "angle": atan2(direction.z, direction.x), "radius": 0.48, "grip_height": 0.80, "blade_length": 0.72, "pitch": 0.0, "screen_roll": roll}
			hero.update_pose(camera, direction, false, sample, 1.2, 0.0, 0.0, 0.0)
			var expected_screen := projected.rotated(roll) * 0.72
			var tip: Vector3 = grip + camera.global_basis.x * expected_screen.x + camera.global_basis.y * expected_screen.y + depth
			var points: Dictionary = hero.get_blade_points()
			_near_vec(points.grip, grip, "reload keeps tiny hand fixed for every aim and spin angle")
			_near_vec(points.tip, tip, "reload spins the projected gun around its hand in the screen plane")
			_near(points.grip.distance_to(points.tip), 0.72, "reload retains rigid physical grip-to-muzzle length")
			var mesh := _mesh_points(hero.weapon, Vector2(10, 18), Vector2(58, 18))
			_near_screen(mesh.grip, grip, camera, "real sprite hand never orbits during reload")
			_near_screen(mesh.tip, tip, camera, "real sprite muzzle follows the centered screen-plane spin")
			_near_vec(hero.body.global_position - hero.body.global_basis.y * (48.0 * 0.018), hero.position, "reload preserves heroine ground anchor")
	# Omitting sample overrides still uses the pistol's physical rest pose.
	hero.update_pose(camera, Vector3.RIGHT, false, {"phase": "idle", "angle": 0.0}, 1.2, 0.0, 0.0, 2.0)
	_near_vec(hero.get_blade_points().grip, hero.position + Vector3(0.28, 0.68, 0), "pistol lowered carry keeps grip close to torso")
	_near_vec(hero.get_blade_points().tip, hero.position + Vector3(.28+.72*cos(-.53), .68+.72*sin(-.53), 0), "pistol carry lowers muzzle with unchanged .72 length")
	hero.update_pose(camera, Vector3.RIGHT, false, {"phase": "active", "angle": 0.0, "pitch": 0.08, "blade_length": 0.72}, 1.2, 0.0, 0.0, 0.0)
	_near_vec(hero.get_blade_points().tip, hero.position + Vector3(0.48 + cos(0.08) * 0.72, 0.80 + sin(0.08) * 0.72, 0), "small supplied firing kick lifts the rigid barrel without moving its hand")
	for family: String in ["sword", "greatsword", "mace", "staff", "pistol"]:
		_check(hero.set_weapon_family(family), "accepted weapon remains selectable: " + family)
	_check(not hero.set_weapon_family("missing"), "unknown weapon family remains rejected")
	hero.queue_free()
	camera.queue_free()
	await process_frame

func _test_bullet() -> void:
	var script: Script = load("res://scripts/bullet_visual.gd")
	_check(script != null and script.can_instantiate(), "bullet visual loads")
	if script == null or not script.can_instantiate(): return
	var visual = script.new()
	_check(visual is Node3D and visual.has_method("update_visual"), "projectile manager can use the bullet update API")
	root.add_child(visual)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 12.5, 11.5)
	camera.look_at(Vector3.ZERO)
	await process_frame
	visual.position = Vector3(1, 0.8, -2)
	visual.update_visual(camera, Vector3.RIGHT, 0.0)
	var bullet: Sprite3D = visual.get_node_or_null("bullet")
	_check(bullet != null, "physical projectile has a dedicated bullet sprite")
	if bullet == null:
		visual.queue_free()
		camera.queue_free()
		await process_frame
		return
	_check(bullet.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST and not bullet.shaded, "small bullet pixels remain nearest and unshaded")
	_near(bullet.pixel_size * 8.0, 0.16, "bullet head has a readable .16 world-unit diameter")
	var first: Texture2D = bullet.texture
	var image := first.get_image()
	_check(image.get_pixel(0, 0).a == 0.0 and image.get_pixel(35, 23).a == 0.0, "bullet canvas retains transparent padding")
	var core := image.get_pixel(28, 12)
	_check(core.r > 0.95 and core.g > 0.85 and core.b > 0.60 and core.a == 1.0, "physical head is bright opaque ivory at its root")
	_check(image.get_pixel(6, 12).a > 0.0 and image.get_pixel(6, 12).a < image.get_pixel(22, 12).a, "short gold trail fades toward its rear")
	var physical_palette := true
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a > 0.0:
				physical_palette = physical_palette and color.g > 0.65 * color.r and color.b > 0.30 * color.r
	_check(physical_palette, "plain physical bullet contains ivory/gold pixels without red-orange flame")
	var textures: Array[Texture2D] = []
	for index in 40:
		visual.update_visual(camera, Vector3.RIGHT, float(index) * 0.031)
		if bullet.texture not in textures: textures.append(bullet.texture)
	_check(textures.size() <= 4, "bullet reuses a bounded small texture cache during flight")
	for direction: Vector3 in [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]:
		visual.update_visual(camera, direction, 0.0)
		_near_vec(visual.position, Vector3(1, 0.8, -2), "bullet update preserves manager-owned projectile origin")
		var projected := Vector2(camera.global_basis.x.dot(direction), camera.global_basis.y.dot(direction)).normalized()
		var actual := Vector2(camera.global_basis.x.dot(bullet.global_basis.x), camera.global_basis.y.dot(bullet.global_basis.x)).normalized()
		_check(actual.dot(projected) > 0.999, "head points forward and short trail points behind motion")
		_near_vec(_texture_world(bullet, Vector2(28, 12)), visual.global_position, "ivory bullet head stays anchored to manager contact center")
	visual.update_visual(camera, Vector3.RIGHT, 0.0)
	_check(bullet.texture == first, "bullet texture choice is deterministic")
	visual.queue_free()
	camera.queue_free()
	await process_frame

func _texture_world(sprite: Sprite3D, point: Vector2) -> Vector3:
	var size := sprite.texture.get_size()
	return sprite.global_transform * (Vector3(point.x - size.x * 0.5 + sprite.offset.x, size.y * 0.5 - point.y + sprite.offset.y, 0.0) * sprite.pixel_size)

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
		print("PISTOL_VISUAL_PASS: %d checks; original heroine; brass/steel gun; fixed hand and rigid actual mesh at 8 aims x 9 reload angles; physical ivory bullet" % checks)
	else:
		for failure in failures: push_error("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
