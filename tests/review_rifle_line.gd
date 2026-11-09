extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)

func _mesh_world(sprite: Sprite3D, point: Vector2) -> Vector3:
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for vertex: Vector3 in sprite.generate_triangle_mesh().get_faces():
		low = low.min(vertex)
		high = high.max(vertex)
	var size := sprite.texture.get_size()
	return sprite.global_transform * Vector3(lerpf(low.x, high.x, point.x / size.x), lerpf(high.y, low.y, point.y / size.y), 0.0)

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0, 12.5, 11.5)
	camera.look_at(Vector3.ZERO)
	var manager = load("res://scripts/staff_projectiles.gd").new()
	scene.add_child(manager)
	var definition: Dictionary = load("res://scripts/rifle_motion.gd").new().definition(0)
	var start := Vector3(2, 0.9, -1)
	_check(manager.spawn_fireball(start, Vector3.RIGHT, definition, camera), "actual rifle definition spawns")
	var visual: Node3D = manager.active[0].node
	_check(visual.get_script().resource_path == "res://scripts/rifle_bullet_visual.gd", "actual rifle definition selects dedicated visual")
	var sprite: Sprite3D = visual.get_node("bullet")
	var image := sprite.texture.get_image()
	var min_pixel := Vector2i(image.get_width(), image.get_height())
	var max_pixel := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				min_pixel = min_pixel.min(Vector2i(x, y))
				max_pixel = max_pixel.max(Vector2i(x, y))
	var span := max_pixel - min_pixel + Vector2i.ONE
	_check(span.x == 29 and span.y == 2, "actual visible alpha bounds are a 29 by 2 line")
	_check(float(span.x) / float(span.y) >= 10.0, "visible shape is thin and linear")
	_check(span.x * sprite.pixel_size < 1.0, "visible shot remains shorter than one world unit")
	for direction: Vector3 in [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD, Vector3(1, 0, 1).normalized(), Vector3(-1, 0, 1).normalized(), Vector3(-1, 0, -1).normalized(), Vector3(1, 0, -1).normalized()]:
		visual.update_visual(camera, direction, 0.25)
		var projected := Vector2(camera.global_basis.x.dot(direction), camera.global_basis.y.dot(direction)).normalized()
		var actual := Vector2(camera.global_basis.x.dot(sprite.global_basis.x), camera.global_basis.y.dot(sprite.global_basis.x)).normalized()
		_check(actual.dot(projected) > 0.999, "actual sprite long axis points along projected travel")
		_check(_mesh_world(sprite, Vector2(28, 12)).distance_to(visual.global_position) < 0.0001, "actual sprite contact anchor matches flight root")
		_check(visual.global_position.distance_to(start) < 0.0001, "visual update preserves manager-owned flight position")
	_check(manager.spawn_fireball(start + Vector3(0, 0, 2), Vector3.RIGHT, definition, camera), "second rifle shot spawns separately")
	_check(manager.active.size() == 2 and manager.active[0].node != manager.active[1].node, "each shot owns an independent actor")
	_check(manager.active[0].node.get_child_count() == 1 and manager.active[1].node.get_child_count() == 1, "each actor contains one finite sprite")
	var pistol_definition: Dictionary = load("res://scripts/pistol_motion.gd").new().definition(0)
	_check(manager.spawn_fireball(start, Vector3.RIGHT, pistol_definition, camera), "actual pistol definition spawns")
	_check(manager.active.back().node.get_script().resource_path == "res://scripts/bullet_visual.gd", "actual pistol retains original round-head visual")
	manager.clear()
	scene.free()
	print("RIFLE V09 REVIEW LINE TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
