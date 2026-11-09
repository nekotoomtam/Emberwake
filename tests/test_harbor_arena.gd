extends SceneTree
## Bounded native harbor checks: flat floor coverage and clear combat rectangle.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var arena := load("res://scripts/harbor_arena.gd").new() as Node3D
	root.add_child(arena)
	await physics_frame
	await physics_frame
	var space := arena.get_world_3d().direct_space_state
	var checks := 0
	for x in [-7.0,-3.5,0.0,3.5,7.0]:
		for z in [-5.0,-2.5,0.0,2.5,5.0]:
			var floor_query := PhysicsRayQueryParameters3D.create(Vector3(x,2,z),Vector3(x,-1,z),1)
			var hit := space.intersect_ray(floor_query)
			if hit.is_empty() or absf(hit.position.y + 0.02) > 0.005:
				_fail("Center floor missing or obstructed at %s,%s" % [x,z])
				return
			checks += 1
	for point in arena.obstacles:
		if absf(point.x) <= 7.0 and absf(point.z) <= 5.0:
			_fail("Avoidance point inside clear combat rectangle")
			return
		checks += 1
	for side in [-1.0,1.0]:
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(side*11.6,0.5,0),Vector3(side*13,0.5,0),1)).is_empty():
			_fail("Side boundary missing")
			return
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,0.5,side*9),Vector3(0,0.5,side*11),1)).is_empty():
			_fail("End boundary missing")
			return
		checks += 2
	if "--harbor-capture" in OS.get_cmdline_user_args():
		var camera := Camera3D.new()
		arena.add_child(camera)
		camera.position = Vector3(0,14,16)
		camera.fov = 50
		camera.look_at(Vector3(0,0,-1))
		camera.current = true
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var capture_path := OS.get_environment("TEMP") + "/emberwake-harbor-v58.png"
		root.get_texture().get_image().save_png(capture_path)
		print("HARBOR CAPTURE: " + capture_path)
	print("HARBOR ARENA PASS: %s native floor / clear-center / bounds checks" % checks)
	quit(0)

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)

