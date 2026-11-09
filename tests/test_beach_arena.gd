extends SceneTree
## Behavior coverage: rectangular shores, sloped floors, missing sea barriers,
## blocked combat routes, and clamp leaks all break these cases.
var checks := 0
var failures: Array[String] = []
var arena

func _initialize() -> void:
	if "--beach-capture" in OS.get_cmdline_user_args():
		root.set_flag(Window.FLAG_NO_FOCUS, true)
		root.position = Vector2i(-20000, -20000)
	call_deferred("run_tests")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func run_tests() -> void:
	check(ResourceLoader.exists("res://scripts/beach_arena.gd"), "coastal arena module exists")
	if not ResourceLoader.exists("res://scripts/beach_arena.gd"):
		quit(1)
		return
	arena = load("res://scripts/beach_arena.gd").new()
	root.add_child(arena)
	await physics_frame
	await physics_frame
	var lowest := 100.0
	var highest := -100.0
	for i in range(97):
		var x := -24.0 + i * 0.5
		var shore: float = arena.shoreline(x)
		lowest = minf(lowest, shore)
		highest = maxf(highest, shore)
		check(shore >= 6.5 and shore <= 11.5, "shore remains beyond combat paths at x %.1f" % x)
		var p: Vector3 = arena.clamp_point(Vector3(x, 2.7, 99))
		check(arena.is_walkable(p), "clamp produces walkable sea-edge point")
		check(is_equal_approx(p.y, 2.7), "clamp preserves actor height")
		check(not arena.is_walkable(Vector3(x, 0, shore + 0.2)), "sea is not walkable")
		var capsule := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = .3
		capsule.shape = sphere
		capsule.collision_mask = 9
		capsule.transform.origin = Vector3(p.x, .7, p.z)
		check(root.get_world_3d().direct_space_state.intersect_shape(capsule).is_empty(), "default shore clamp leaves clearance for the real player radius")
	check(highest - lowest > 2.0, "shore has visible bays and spits rather than a straight edge")
	for raw in [Vector3(-80, 5, -80), Vector3(80, -2, 80), Vector3(0, 0, -100)]:
		var p: Vector3 = arena.clamp_point(raw)
		check(absf(p.x) <= 23.0 and p.z >= -11.5, "clamp respects inland and side limits")
		check(arena.is_walkable(p), "clamp handles distant dash/recoil endpoints")
	for x in range(-18, 19, 3):
		for z in range(-6, 5, 2):
			var p := Vector3(x, 0, z)
			check(arena.is_walkable(p), "central combat route is legal")
			var hit := ray(p + Vector3.UP * 3, p - Vector3.UP)
			check(not hit.is_empty() and absf(hit.position.y) < 0.001, "central combat floor is physically flat at y=0")
			check(ray(p + Vector3.UP * .6, p + Vector3(1.0, .6, 0)).is_empty(), "central combat route has no blocking decor")
	for p in [arena.spawn_point, arena.captain_point, Vector3(-15.5, 0, 3), Vector3(-8.5, 0, 1.5), Vector3(-1, 0, 3.7), Vector3(7, 0, 1.5), Vector3(14, 0, 4)]:
		for i in range(12):
			var endpoint: Vector3 = p + Vector3(cos(i * TAU / 12), 0, sin(i * TAU / 12)) * 2.8
			check(ray(p + Vector3.UP * .7, endpoint + Vector3.UP * .7).is_empty(), "spawn/encounter area has a clear approach")
	for x in [-22.0, -13.0, -3.0, 6.0, 15.0, 22.0]:
		var shore: float = arena.shoreline(x)
		var hit := ray(Vector3(x, .7, shore - 1), Vector3(x, .7, shore + 1))
		check(not hit.is_empty(), "physical sea barrier stops motion at the irregular shoreline")
		check(ray(Vector3(x, 2, shore - .7), Vector3(x, -1, shore - .7)).size() > 0, "flat floor reaches legal wet-sand edge")
		check(ray(Vector3(x, 2, shore + 2), Vector3(x, -1, shore + 2)).is_empty(), "land collision does not extend into sea")
	check(not arena.is_processing(), "water has no autonomous processing during pause")
	arena.tick(.25)
	if "--beach-capture" in OS.get_cmdline_user_args():
		await capture_overview()
	arena.queue_free()
	await process_frame
	print("BEACH ARENA TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func ray(a: Vector3, b: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(a, b, 9)
	return root.get_world_3d().direct_space_state.intersect_ray(query)

func capture_overview() -> void:
	root.size = Vector2i(1600, 900)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 32
	camera.position = Vector3(0, 30, 32)
	arena.add_child(camera)
	camera.look_at(Vector3(0, 0, -3))
	camera.current = true
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://tests/beach_native_overview.png")
	check(image.save_png(path) == OK, "native beach overview saved")
	print("BEACH CAPTURE: ", path)
