extends SceneTree

var failures: Array[String] = []
var checks := 0
var great_art: Script

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not FileAccess.file_exists("res://scripts/greatsword_art.gd"):
		push_error("FAIL: dedicated greatsword art is missing")
		quit(1)
		return
	great_art = load("res://scripts/greatsword_art.gd")
	_check(great_art != null and great_art.can_instantiate(), "greatsword art loads")
	if great_art == null or not great_art.can_instantiate():
		_finish()
		return
	_test_straight_cached_art()
	await _test_switching_and_projected_blade()
	_finish()

func _test_straight_cached_art() -> void:
	var sword_art: Script = load("res://scripts/sword_art.gd")
	_test_art_contract(great_art, 2, "greatsword")
	_test_art_contract(sword_art, 1, "ordinary sword")
	_check(great_art.texture().get_width() > sword_art.texture().get_width(), "greatsword retains a longer silhouette than the ordinary sword")

func _test_art_contract(art: Script, hand_count: int, label: String) -> void:
	var texture: Texture2D = art.texture()
	var geometry: Dictionary = art.geometry()
	var preserved: Dictionary = geometry.duplicate(true)
	var image := texture.get_image()
	_check(texture == art.texture(), label + " reuses its cached texture")
	_check(geometry.tip.x > geometry.pivot.x and is_equal_approx(geometry.tip.y, geometry.pivot.y), label + " grip and tip share the straight +X axis")
	_check(image.get_pixel(int(geometry.tip.x) - 1, int(geometry.tip.y)).a > 0.0, label + " visible blade reaches the declared tip")
	_check(image.get_pixelv(Vector2i(geometry.pivot)).is_equal_approx(Color("ffd4ad")), label + " pivot belongs to its small hand")
	var opaque: Dictionary = {}
	var skin: Dictionary = {}
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				opaque[Vector2i(x, y)] = true
			if image.get_pixel(x, y).is_equal_approx(Color("ffd4ad")):
				skin[Vector2i(x, y)] = true
	_check(_components(opaque).size() == 1, label + " hilt, hands, guard and blade remain connected")
	var hands := _components(skin)
	var small_hands: bool = hands.size() == hand_count
	for hand_pixels: Dictionary in hands:
		var low := Vector2i(hand_pixels.keys()[0])
		var high := low
		for point: Vector2i in hand_pixels:
			low = low.min(point)
			high = high.max(point)
		small_hands = small_hands and hand_pixels.size() == 16 and high - low + Vector2i.ONE == Vector2i(4, 4)
	_check(small_hands, label + " has only native 4x4 skin clusters")
	geometry.pivot = Vector2.ZERO
	geometry.tip = Vector2.ZERO
	_check(art.geometry() == preserved, label + " geometry cannot be mutated through returned collections")

func _components(pixels: Dictionary) -> Array[Dictionary]:
	var remaining: Dictionary = pixels.duplicate()
	var result: Array[Dictionary] = []
	while not remaining.is_empty():
		var pending: Array[Vector2i] = [remaining.keys()[0]]
		var component: Dictionary = {}
		remaining.erase(pending[0])
		while not pending.is_empty():
			var point: Vector2i = pending.pop_back()
			component[point] = true
			for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbour := point + direction
				if remaining.erase(neighbour):
					pending.append(neighbour)
		result.append(component)
	return result

func _test_switching_and_projected_blade() -> void:
	var hero_script: Script = load("res://scripts/hero_visual.gd")
	var hero = hero_script.new()
	_check(hero.has_method("set_weapon_family") and hero.has_method("get_blade_points"), "hero exposes family selection and rendered blade endpoints")
	if not hero.has_method("set_weapon_family") or not hero.has_method("get_blade_points"):
		hero.free()
		return
	_check(hero.set_weapon_family("greatsword"), "greatsword can be selected before ready")
	root.add_child(hero)
	hero.position = Vector3(2.0, 0.0, -3.0)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0.0, 12.5, 11.5)
	camera.look_at(Vector3.ZERO)
	await process_frame
	var sword_art: Script = load("res://scripts/pixel_art.gd")
	var refined_sword: Script = load("res://scripts/sword_art.gd")
	var geometry: Dictionary = great_art.geometry()
	_check(hero.body.sprite_frames == sword_art.frames("player"), "weapon selection preserves the original heroine frames")
	_check(hero.weapon_family == "greatsword" and hero.weapon.texture == great_art.texture(), "selection applies the cached greatsword")
	var original_texture: Texture2D = hero.weapon.texture
	_check(not hero.set_weapon_family("unknown"), "unknown weapon family is rejected")
	_check(hero.weapon_family == "greatsword" and hero.weapon.texture == original_texture, "rejected family retains current art")
	var aims := [
		{"angle": 0.0, "direction": Vector3.RIGHT},
		{"angle": PI / 2.0, "direction": Vector3.BACK},
		{"angle": PI, "direction": Vector3.LEFT},
		{"angle": -PI / 2.0, "direction": Vector3.FORWARD},
	]
	for fixture: Dictionary in aims:
		for pitch: float in [-0.65, 0.0, 0.9, PI / 2.0]:
			var sample := {"phase": "active", "angle": fixture.angle, "radius": 0.5, "pitch": pitch, "grip_height": 1.75, "blade_length": 2.475}
			hero.update_pose(camera, fixture.direction, false, sample, 2.975, 0.0, 0.0, 0.0)
			var grip: Vector3 = hero.position + fixture.direction * 0.5 + Vector3.UP * 1.75
			var blade: Vector3 = (fixture.direction * cos(pitch) + Vector3.UP * sin(pitch)) * 2.475
			var points: Dictionary = hero.get_blade_points()
			_near_vec(points.grip, grip, "reported grip follows the real hilt")
			_near_vec(points.tip, grip + blade, "physical blade endpoint retains constant length and pitch")
			_near(hero.weapon.pixel_size, 2.475 / (geometry.tip.x - geometry.pivot.x), "pitch never changes native blade pixel size")
			_check(absf(hero.weapon.pixel_size - hero.body.pixel_size) < 0.003, "greatsword hand clusters stay close to the heroine's native scale")
			_check(hero.weapon.scale.y == 1.0, "pitch does not squash blade width")
			var mesh_points := _mesh_blade_points(hero.weapon, geometry.pivot, geometry.tip)
			_near_screen(mesh_points.grip, grip, camera, "rendered mesh grip is the physical grip")
			_near_screen(mesh_points.tip, grip + blade, camera, "rendered mesh tip exactly projects the physical blade")
			_near_vec(hero.body.global_position - hero.body.global_basis.y * (48.0 * 0.018), hero.global_position, "body feet remain anchored while the greatsword is raised")
	# A vertical finisher is held above the head, then drops along one locked plane.
	var upper := {"phase": "windup", "angle": 0.0, "radius": 0.5, "pitch": PI / 2.0, "grip_height": 1.75, "blade_length": 2.475}
	hero.update_pose(camera, Vector3.RIGHT, false, upper, 2.975, 0.0, 0.0, 0.0)
	var top: Dictionary = hero.get_blade_points()
	_near(top.tip.y, hero.position.y + 1.75 + 2.475, "finisher raises the full extended rigid blade above the heroine")
	upper.phase = "active"
	upper.pitch = -0.45
	upper.grip_height = 1.1
	hero.update_pose(camera, Vector3.RIGHT, false, upper, 2.975, 0.0, 0.0, 0.0)
	var down: Dictionary = hero.get_blade_points()
	_check(down.tip.y < down.grip.y and is_equal_approx(down.tip.z, down.grip.z), "finisher falls straight forward without a sideways sweep")
	_check(hero.set_weapon_family("sword"), "ordinary sword can be selected")
	var sword_sample := {"phase": "active", "angle": 0.0, "radius": 0.2, "pitch": 0.0, "grip_height": 0.68, "blade_length": 1.9}
	hero.update_pose(camera, Vector3.RIGHT, false, sword_sample, 2.1, 0.0, 0.0, 0.0)
	_check(hero.weapon.texture == refined_sword.texture(), "ordinary sword uses its refined cached art")
	var sword_geometry: Dictionary = refined_sword.geometry()
	_near(hero.weapon.pixel_size, 1.9 / (sword_geometry.tip.x - sword_geometry.pivot.x), "ordinary sword uses its fixed rigid length")
	_check(absf(hero.weapon.pixel_size - hero.body.pixel_size) < 0.003, "ordinary sword hand stays close to the heroine's native scale")
	_near_vec(hero.hand.global_position, hero.position + Vector3(0.2, 0.68, 0.0), "ordinary sword uses the authored close grip")
	_near_vec(hero.get_blade_points().tip, hero.position + Vector3(2.1, 0.68, 0.0), "ordinary sword rendered tip agrees with first-hit ground reach")
	# Use a fresh ordinary visual for the engine quad: generate_triangle_mesh()
	# retains its first generated texture dimensions on a reused Sprite3D.
	# The original hero above still verifies real family switching and endpoints.
	var sword_hero = hero_script.new()
	root.add_child(sword_hero)
	sword_hero.position = hero.position
	await process_frame
	sword_hero.update_pose(camera, Vector3.RIGHT, false, sword_sample, 2.1, 0.0, 0.0, 0.0)
	var sword_mesh := _mesh_blade_points(sword_hero.weapon, sword_geometry.pivot, sword_geometry.tip)
	_near_screen(sword_mesh.grip, hero.hand.global_position, camera, "refined ordinary sword mesh shares its physical grip")
	_near_screen(sword_mesh.tip, hero.position + Vector3(2.1, 0.68, 0.0), camera, "refined ordinary sword mesh retains the original first-hit reach")
	sword_hero.queue_free()
	_check(hero.set_weapon_family("greatsword") and hero.weapon.texture == original_texture, "repeated swaps reuse greatsword texture")
	hero.queue_free()
	camera.queue_free()
	await process_frame

func _mesh_blade_points(sprite: Sprite3D, pivot: Vector2, tip: Vector2) -> Dictionary:
	# Read the generated quad, independently of the hero endpoint API. An offset,
	# rotation, or scale error must move these measured endpoints and fail above.
	var faces: PackedVector3Array = sprite.generate_triangle_mesh().get_faces()
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for vertex: Vector3 in faces:
		low = low.min(vertex)
		high = high.max(vertex)
	var texture_size := sprite.texture.get_size()
	var local_grip := Vector3(lerpf(low.x, high.x, pivot.x / texture_size.x), lerpf(high.y, low.y, pivot.y / texture_size.y), 0.0)
	var local_tip := Vector3(lerpf(low.x, high.x, tip.x / texture_size.x), lerpf(high.y, low.y, tip.y / texture_size.y), 0.0)
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
		print("GREATSWORD_VISUAL_PASS: %d checks; cached straight art; all cardinal aims and pitches; actual projected mesh endpoints; sword parity" % checks)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
