extends SceneTree

var failures: Array[String] = []
var checks := 0
var mace_art: Script

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not FileAccess.file_exists("res://scripts/mace_art.gd"):
		push_error("FAIL: dedicated one-hand mace art is missing")
		quit(1)
		return
	mace_art = load("res://scripts/mace_art.gd")
	_check(mace_art != null and mace_art.can_instantiate(), "mace art loads")
	if mace_art == null or not mace_art.can_instantiate():
		_finish()
		return
	_test_cached_crowned_head_art()
	await _test_switching_and_projected_head()
	_finish()

func _test_cached_crowned_head_art() -> void:
	var texture: Texture2D = mace_art.texture()
	var geometry: Dictionary = mace_art.geometry()
	var preserved: Dictionary = geometry.duplicate(true)
	var image := texture.get_image()
	_check(texture == mace_art.texture(), "mace texture reuses the cached resource")
	_check(geometry.tip.x > geometry.pivot.x and is_equal_approx(geometry.pivot.y, geometry.tip.y), "mace grip and striking edge share the rigid +X axis")
	_check(image.get_pixel(int(geometry.tip.x) - 1, int(geometry.tip.y)).a > 0.0, "mace visible striking face reaches its declared endpoint")
	_check(image.get_pixelv(Vector2i(geometry.pivot)).is_equal_approx(Color("ffd4ad")), "mace pivot remains in its small hand")
	var opaque: Dictionary = {}
	var skin: Dictionary = {}
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				opaque[Vector2i(x, y)] = true
			if image.get_pixel(x, y).is_equal_approx(Color("ffd4ad")):
				skin[Vector2i(x, y)] = true
	_check(_connected(opaque), "mace hand, handle and head form one connected rigid silhouette")
	var low := Vector2i(skin.keys()[0])
	var high := low
	for point: Vector2i in skin:
		low = low.min(point)
		high = high.max(point)
	_check(skin.size() == 16 and high - low + Vector2i.ONE == Vector2i(4, 4), "mace has exactly one native 4x4 hand cluster")
	geometry.pivot = Vector2.ZERO
	geometry.tip = Vector2.ZERO
	_check(mace_art.geometry() == preserved, "callers cannot mutate returned mace geometry")

func _connected(pixels: Dictionary) -> bool:
	if pixels.is_empty():
		return false
	var remaining: Dictionary = pixels.duplicate()
	var pending: Array[Vector2i] = [remaining.keys()[0]]
	remaining.erase(pending[0])
	while not pending.is_empty():
		var point: Vector2i = pending.pop_back()
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbour := point + direction
			if remaining.erase(neighbour):
				pending.append(neighbour)
	return remaining.is_empty()

func _test_switching_and_projected_head() -> void:
	var hero_script: Script = load("res://scripts/hero_visual.gd")
	var hero = hero_script.new()
	_check(hero.set_weapon_family("mace"), "one-hand mace can be selected before ready")
	root.add_child(hero)
	hero.position = Vector3(2.0, 0.0, -3.0)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0.0, 12.5, 11.5)
	camera.look_at(Vector3.ZERO)
	await process_frame
	var original_art: Script = load("res://scripts/pixel_art.gd")
	var sword_art: Script = load("res://scripts/sword_art.gd")
	var geometry: Dictionary = mace_art.geometry()
	_check(hero.body.sprite_frames == original_art.frames("player"), "mace retains the original female chibi body frames")
	_check(hero.weapon_family == "mace" and hero.weapon.texture == mace_art.texture(), "mace selection applies its cached art")
	var texture: Texture2D = hero.weapon.texture
	_check(not hero.set_weapon_family("unknown"), "unknown family is rejected")
	_check(hero.weapon_family == "mace" and hero.weapon.texture == texture, "rejected family retains the current mace")
	var aims := [
		{"angle": 0.0, "direction": Vector3.RIGHT},
		{"angle": PI / 2.0, "direction": Vector3.BACK},
		{"angle": PI, "direction": Vector3.LEFT},
		{"angle": -PI / 2.0, "direction": Vector3.FORWARD},
	]
	for fixture: Dictionary in aims:
		for pitch: float in [-0.95, 0.0, 0.95, PI / 2.0]:
			var sample := {"phase": "active", "angle": fixture.angle, "radius": 0.38, "pitch": pitch, "grip_height": 0.86, "blade_length": 1.9}
			hero.update_pose(camera, fixture.direction, false, sample, 2.28, 0.0, 0.0, 0.0)
			var grip: Vector3 = hero.position + fixture.direction * 0.38 + Vector3.UP * 0.86
			var shaft: Vector3 = (fixture.direction * cos(pitch) + Vector3.UP * sin(pitch)) * 1.9
			var points: Dictionary = hero.get_blade_points()
			_near_vec(points.grip, grip, "reported mace grip follows the real hand pixel")
			_near_vec(points.tip, grip + shaft, "physical head endpoint retains constant shaft length and pitch")
			_near(hero.weapon.pixel_size, 1.9 / (geometry.tip.x - geometry.pivot.x), "pitch retains the mace's native pixel scale")
			_check(absf(hero.weapon.pixel_size - hero.body.pixel_size) < 0.003, "mace hand cluster stays close to the heroine's native scale")
			_check(hero.weapon.scale.y == 1.0, "pitch never squashes the head thickness")
			var mesh_points := _mesh_points(hero.weapon, geometry.pivot, geometry.tip)
			_near_screen(mesh_points.grip, grip, camera, "actual sprite mesh grip projects the physical grip")
			_near_screen(mesh_points.tip, grip + shaft, camera, "actual sprite mesh head projects the physical striking edge")
			_near_vec(hero.body.global_position - hero.body.global_basis.y * (48.0 * 0.018), hero.global_position, "mace pitch retains the original body foot anchor")
	# A rising strike and descending finish use one rigid weapon; the light
	# middle strike is a compact pose carried by movement of the whole hero.
	var pose := {"phase": "active", "angle": 0.0, "radius": 0.38, "pitch": -0.95, "grip_height": 0.86, "blade_length": 1.9}
	hero.update_pose(camera, Vector3.RIGHT, false, pose, 2.28, 0.0, 0.0, 0.0)
	var low: Dictionary = hero.get_blade_points()
	pose.pitch = 0.95
	hero.update_pose(camera, Vector3.RIGHT, false, pose, 2.28, 0.0, 0.0, 0.0)
	var high: Dictionary = hero.get_blade_points()
	_check(low.tip.y < low.grip.y and high.tip.y > high.grip.y + 1.0, "first heavy strike visibly travels from low to high")
	pose.pitch = 1.25
	hero.update_pose(camera, Vector3.RIGHT, false, pose, 2.28, 0.0, 0.0, 0.0)
	var top: Dictionary = hero.get_blade_points()
	pose.pitch = -0.85
	hero.update_pose(camera, Vector3.RIGHT, false, pose, 2.28, 0.0, 0.0, 0.0)
	var down: Dictionary = hero.get_blade_points()
	_check(top.tip.y > top.grip.y + 1.2 and down.tip.y < down.grip.y, "finish visibly travels from above to below the grip")
	_near(top.tip.z, down.tip.z, "pitch-only finisher retains its locked forward plane")
	pose.pitch = 0.9
	pose.radius = 0.25
	pose.grip_height = 0.83
	hero.update_pose(camera, Vector3.RIGHT, false, pose, 2.28, 0.0, 0.0, 0.0)
	var compact: Dictionary = hero.get_blade_points()
	var foot_before: Vector3 = hero.body.global_position - hero.body.global_basis.y * (48.0 * 0.018)
	hero.position += Vector3(0.42, 0.0, 0.0)
	hero.update_pose(camera, Vector3.RIGHT, false, pose, 2.28, 0.0, 0.0, 0.0)
	var moved: Dictionary = hero.get_blade_points()
	_near_vec(moved.grip - compact.grip, Vector3(0.42, 0.0, 0.0), "short dash carries the compact weapon with the body root")
	_near_vec(moved.tip - compact.tip, Vector3(0.42, 0.0, 0.0), "short dash translates the head without a separate elbow animation")
	_near_vec(hero.body.global_position - hero.body.global_basis.y * (48.0 * 0.018) - foot_before, Vector3(0.42, 0.0, 0.0), "short dash visibly carries the original heroine")
	_check(hero.set_weapon_family("sword") and hero.weapon.texture == sword_art.texture(), "ordinary sword can be restored with its refined cached art")
	_check(hero.set_weapon_family("greatsword") and hero.weapon.texture == load("res://scripts/greatsword_art.gd").texture(), "greatsword remains selectable")
	_check(hero.set_weapon_family("mace") and hero.weapon.texture == texture, "repeated mace swaps reuse the cached art")
	hero.queue_free()
	camera.queue_free()
	await process_frame

func _mesh_points(sprite: Sprite3D, pivot: Vector2, tip: Vector2) -> Dictionary:
	# Measure the engine's actual quad independently of the endpoint API.
	var faces: PackedVector3Array = sprite.generate_triangle_mesh().get_faces()
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for vertex: Vector3 in faces:
		low = low.min(vertex)
		high = high.max(vertex)
	var size := sprite.texture.get_size()
	var local_grip := Vector3(lerpf(low.x, high.x, pivot.x / size.x), lerpf(high.y, low.y, pivot.y / size.y), 0.0)
	var local_tip := Vector3(lerpf(low.x, high.x, tip.x / size.x), lerpf(high.y, low.y, tip.y / size.y), 0.0)
	return {"grip": sprite.global_transform * local_grip, "tip": sprite.global_transform * local_tip}

func _near_screen(actual: Vector3, expected: Vector3, camera: Camera3D, message: String) -> void:
	_near(camera.global_basis.x.dot(actual), camera.global_basis.x.dot(expected), message + " (screen x)")
	_near(camera.global_basis.y.dot(actual), camera.global_basis.y.dot(expected), message + " (screen y)")

func _near_vec(actual: Vector3, expected: Vector3, message: String) -> void:
	_check(actual.distance_to(expected) < 0.0001, "%s: got %s expected %s" % [message, actual, expected])

func _near(actual: float, expected: float, message: String) -> void:
	_check(absf(actual - expected) < 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("MACE_VISUAL_PASS: %d checks; cached crowned head; cardinal pitch projections; actual mesh endpoints; original body and weapon parity" % checks)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
