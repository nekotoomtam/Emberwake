extends SceneTree

var failures: Array[String] = []
var checks := 0
var staff_art: Script

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(FileAccess.get_sha256("res://scripts/pixel_art.gd").to_upper() == "BD3073938A3ADA849FEAB955067EB410E5ECF387DCE289AE9B2653A962A28047", "accepted heroine source remains byte unchanged")
	_check(FileAccess.file_exists("res://scripts/staff_art.gd"), "dedicated original staff art exists")
	if FileAccess.file_exists("res://scripts/staff_art.gd"):
		staff_art = load("res://scripts/staff_art.gd")
		_check(staff_art != null and staff_art.can_instantiate(), "staff art loads")
		if staff_art != null and staff_art.can_instantiate():
			_test_staff_art()
	await _test_hero_projection()
	_check(FileAccess.file_exists("res://scripts/fireball_visual.gd"), "animated fireball visual exists")
	if FileAccess.file_exists("res://scripts/fireball_visual.gd"):
		await _test_fireball_visual()
	_finish()

func _test_staff_art() -> void:
	var texture: Texture2D = staff_art.texture()
	var geometry: Dictionary = staff_art.geometry()
	var image := texture.get_image()
	_check(texture is ImageTexture and texture == staff_art.texture(), "staff supplies one cached native pixel ImageTexture")
	_check(texture.get_size() == Vector2(96, 40), "staff keeps a small 96x40 pixel canvas")
	_check(geometry.pivot == Vector2(12, 20) and geometry.tip == Vector2(92, 20), "tiny hand and fire crown share the rigid staff axis")
	_check(image.get_used_rect() == Rect2i(4, 4, 88, 32), "staff has transparent padding around its complete silhouette")
	var skin := 0
	var wood := 0
	var bronze := 0
	var fire := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			_check(color.a == 0.0 or color.a == 1.0, "staff alpha remains crisp at %d,%d" % [x, y])
			if color.is_equal_approx(Color("ffd4ad")): skin += 1
			if color.is_equal_approx(Color("83523e")): wood += 1
			if color.is_equal_approx(Color("c38c4f")): bronze += 1
			if color.r > 0.7 and color.g > 0.15 and color.g < 0.7 and color.b < 0.3: fire += 1
	_check(skin == 16 and image.get_pixel(12, 20).is_equal_approx(Color("ffd4ad")), "exactly one tiny four-pixel hand is attached at the pivot")
	_check(wood >= 128 and bronze >= 96 and fire >= 96, "staff reads as wood, bronze crown and warm fire gem")
	for x in range(4, 92):
		_check(image.get_pixel(x, 20).a > 0.0, "staff silhouette remains connected along the grip-to-tip axis at %d" % x)
	for y in range(0, 40, 4):
		for x in range(0, 96, 4):
			var color := image.get_pixel(x, y)
			var uniform := true
			for dy in 4:
				for dx in 4:
					uniform = uniform and image.get_pixel(x + dx, y + dy).is_equal_approx(color)
			_check(uniform, "staff matches the heroine's four-pixel clusters at %d,%d" % [x, y])
	geometry.pivot = Vector2.ZERO
	_check(staff_art.geometry().pivot == Vector2(12, 20), "staff geometry cannot be mutated by a caller")

func _test_hero_projection() -> void:
	var hero = load("res://scripts/hero_visual.gd").new()
	var accepts_staff: bool = hero.set_weapon_family("staff")
	_check(accepts_staff, "hero accepts staff before entering the scene")
	if not accepts_staff or staff_art == null:
		hero.free()
		return
	root.add_child(hero)
	hero.position = Vector3(2.0, 0.0, -3.0)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0.0, 12.5, 11.5)
	camera.look_at(Vector3.ZERO)
	await process_frame
	_check(hero.body.sprite_frames == load("res://scripts/pixel_art.gd").frames("player"), "staff keeps the accepted heroine's original animation frames")
	_check(hero.weapon.texture == staff_art.texture(), "staff selects the original fire-crown texture")
	var aims := [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]
	for direction: Vector3 in aims:
		for pitch: float in [-0.3, 0.0, 0.55, 1.1]:
			var sample := {"phase": "active", "angle": atan2(direction.z, direction.x), "radius": 0.32, "pitch": pitch, "grip_height": 0.82, "blade_length": 1.45}
			hero.update_pose(camera, direction, false, sample, 1.77, 0.0, 0.0, 0.0)
			var grip: Vector3 = hero.position + direction * 0.32 + Vector3.UP * 0.82
			var shaft: Vector3 = (direction * cos(pitch) + Vector3.UP * sin(pitch)) * 1.45
			var points: Dictionary = hero.get_blade_points()
			_near_vec(points.grip, grip, "staff grip follows its actual tiny hand")
			_near_vec(points.tip, grip + shaft, "staff's physical tip retains supplied length, cardinal direction and pitch")
			_near(points.grip.distance_to(points.tip), 1.45, "foreshortening keeps the physical staff length")
			_near(hero.weapon.pixel_size, 1.45 / 80.0, "staff has the same pixel density as the accepted heroine")
			_check(hero.weapon.scale.y == 1.0, "foreshortening retains crown thickness")
			var mesh := _mesh_points(hero.weapon, Vector2(12, 20), Vector2(92, 20))
			_near_screen(mesh.grip, grip, camera, "real staff mesh grip projects the physical hand")
			_near_screen(mesh.tip, grip + shaft, camera, "real staff mesh crown projects the physical muzzle")
			_near_vec(hero.body.global_position - hero.body.global_basis.y * (48.0 * 0.018), hero.global_position, "cardinal staff aiming preserves the heroine's ground anchor")
	for family: String in ["sword", "greatsword", "mace", "staff"]:
		_check(hero.set_weapon_family(family), "existing selection remains available: " + family)
	hero.queue_free()
	camera.queue_free()
	await process_frame

func _test_fireball_visual() -> void:
	var fireball_script: Script = load("res://scripts/fireball_visual.gd")
	_check(fireball_script != null and fireball_script.can_instantiate(), "fireball script loads")
	if fireball_script == null or not fireball_script.can_instantiate(): return
	var fireball = fireball_script.new()
	_check(fireball is Node3D and fireball.has_method("update_visual"), "manager can instantiate fireball and call the update API")
	root.add_child(fireball)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0.0, 12.5, 11.5)
	camera.look_at(Vector3.ZERO)
	await process_frame
	var origin := Vector3(1.0, 0.82, -2.0)
	fireball.position = origin
	fireball.update_visual(camera, Vector3.RIGHT, 0.0)
	var flame: Sprite3D = fireball.get_node_or_null("flame")
	_check(flame != null, "fireball creates a dedicated flame sprite")
	if flame == null:
		fireball.queue_free()
		camera.queue_free()
		await process_frame
		return
	_check(flame.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST and not flame.shaded, "fireball pixels keep nearest filtering and readable unshaded colors")
	_near(flame.pixel_size * 16.0, 0.54, "enlarged fireball visual head has a 0.54 world-unit diameter")
	var first: Texture2D = flame.texture
	var image := first.get_image()
	_check(image.get_pixel(0, 0).a == 0.0 and image.get_pixel(39, 23).a == 0.0, "flame canvas retains transparent corners")
	var center := image.get_pixel(28, 12)
	_check(center.r > 0.95 and center.g > 0.85 and center.b > 0.45, "fireball has a warm white-yellow core at the manager-owned contact center")
	_check(image.get_used_rect().position.x < 12 and image.get_used_rect().end.x > 32, "fireball includes a readable trailing flame behind the round head")
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			_check(color.a == 0.0 or color.a == 1.0, "fireball silhouette alpha remains crisp at %d,%d" % [x, y])
	for direction: Vector3 in [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]:
		fireball.update_visual(camera, direction, 0.0)
		_near_vec(fireball.position, origin, "visual update preserves the manager's projectile position")
		var projected := Vector2(camera.global_basis.x.dot(direction), camera.global_basis.y.dot(direction)).normalized()
		var actual := Vector2(camera.global_basis.x.dot(flame.global_basis.x), camera.global_basis.y.dot(flame.global_basis.x)).normalized()
		_check(actual.dot(projected) > 0.999, "fireball head points with motion and tail trails in each cardinal direction")
		var core_world := _texture_world(flame, Vector2(28, 12))
		_near_vec(core_world, fireball.global_position, "visible hot core remains at the collision center after aiming")
	fireball.update_visual(camera, Vector3.RIGHT, 0.1)
	_check(flame.texture != first and flame.texture.get_image().get_data() != image.get_data(), "projectile age animates the flame silhouette")
	fireball.update_visual(camera, Vector3.RIGHT, 0.0)
	_check(flame.texture == first, "fireball animation is deterministic and reuses cached frames")
	fireball.queue_free()
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
		print("STAFF_VISUAL_PASS: %d checks; original heroine bytes; cached staff art; actual mesh projection for four aims; animated fireball core and trailing direction" % checks)
	else:
		for failure in failures: push_error("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
