extends SceneTree
var failures: Array[String] = []
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("FAIL: ", label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run(true)
	game.test_aim = Vector3.RIGHT
	game.fx.clear_transients()
	check(game.fx.has_method("legacy_sword_trail"), "archived fan emitter available")
	if game.fx.has_method("legacy_sword_trail"):
		for direction in [-1.0, 1.0]:
			game.fx.clear_transients()
			game.fx.legacy_sword_trail(Vector3.ZERO, 2.1, 0, direction * .4)
			check(game.fx.trails.size() == 2, "two archived fan layers")
			var fan = game.fx.trails[0]
			var edge = game.fx.trails[1]
			check(is_equal_approx(fan.total, .12) and is_equal_approx(edge.total, .09), "archived lifetimes")
			check(fan.color.is_equal_approx(Color(.55,.95,.91,.7)), "archived cyan fan")
			check(edge.color.is_equal_approx(Color(1,1,.85,.9)), "archived bright edge")
			for entry in game.fx.trails:
				var arrays = entry.node.mesh.surface_get_arrays(0)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var bounded := true
				var endpoint := false
				for v in vertices:
					bounded = bounded and Vector2(v.x,v.z).length() <= 2.1001
					endpoint = endpoint or absf(Vector2(v.x,v.z).length()-2.1)<.0001
				check(bounded and endpoint, "fan ends at real skill reach")
		game.fx.clear_transients()
		check(game.request_skill(), "Q skill starts")
		game.tick(.09)
		check(game.fx.trails.size() == 2, "actual skill uses both old layers")
		check(game.hits == 1 and game.total_damage == 18, "unchanged first-cut damage")
		check(game.request_dodge(Vector3.LEFT), "Space still cancels")
		game.tick(.5)
		check(game.hits == 1 and not game.skill_active, "cancelled second cut never damages")
		check(game.fx.trails.is_empty(), "old fans naturally expire after cancellation")
		game.start_run(true)
		game.fx.clear_transients()
		check(game.request_attack(), "normal basic starts")
		game.tick(.20)
		check(not game.fx.trails.is_empty() and is_equal_approx(game.fx.trails[0].total,.055), "ordinary Sword keeps current edge")
	game.queue_free()
	await process_frame
	print("LEGACY SLASH FX TESTS: %d/%d passed" % [checks-failures.size(),checks])
	quit(0 if failures.is_empty() else 1)
