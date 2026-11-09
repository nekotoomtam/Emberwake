extends SceneTree

var checks := 0
var failures: Array[String] = []
var game: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _run() -> void:
	var scene = load("res://scenes/game.tscn")
	game = scene.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await physics_frame
	await process_frame
	_test_restart_clears_shake()
	_test_menu_clears_shake()
	_test_defeat_shake_settles()
	await _test_solid_pillar_blocks_bolt()
	_test_player_before_cover_still_gets_hit()
	_test_unobstructed_bolt_still_hits()
	game.queue_free()
	await process_frame
	print("COMBAT EDGE TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _fresh() -> void:
	game.start_run(true)
	game.set_physics_process(false)
	game.move_input = Vector2.ZERO
	game.test_aim = Vector3.RIGHT

func _test_restart_clears_shake() -> void:
	# Missing run reset must not carry an old damage jolt into the new run.
	_fresh()
	game.damage_player(12.0)
	_check(game._shake > 0.0, "damage starts a camera jolt before restart fixture")
	game.restart()
	_check(is_zero_approx(game._shake), "restart clears the previous run's camera shake")

func _test_menu_clears_shake() -> void:
	# The menu must not inherit damage shake whose decay lived only in combat.
	_fresh()
	game.damage_player(12.0)
	game.return_menu()
	_check(game.mode == "menu", "return menu enters menu mode")
	_check(is_zero_approx(game._shake), "return menu clears camera shake")

func _test_defeat_shake_settles() -> void:
	# A lethal hit must not leave the defeat camera shaking forever.
	_fresh()
	game.damage_player(1000.0)
	_check(game.mode == "dead", "lethal damage enters the defeat fixture")
	for frame in range(180):
		game.tick(1.0 / 120.0)
	_check(game._shake < 0.001, "defeat camera jolt settles after combat stops")
	var before: Vector3 = game.camera.position
	game.tick(1.0 / 120.0)
	_check(game.camera.position.distance_to(before) < 0.002, "settled defeat camera stays visually still")

func _test_solid_pillar_blocks_bolt() -> void:
	# A segment crossing a pillar and the player in one frame must hit cover first.
	_fresh()
	game.player.position = Vector3(8.0, 0.03, 6.8)
	await physics_frame
	await process_frame
	var start := Vector3(8.0, 0.6, 4.0)
	var end := Vector3(8.0, 0.6, 7.85)
	var ray := PhysicsRayQueryParameters3D.create(start, end, 1)
	var obstacle: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
	_check(not obstacle.is_empty(), "bolt test crosses the arena's real solid pillar")
	var initial: float = game.health
	game.shoot(start, Vector3.BACK, 11.0)
	game._update_projectiles(0.7)
	_check(is_equal_approx(game.health, initial), "solid pillar blocks a bolt before it damages the player behind cover")
	_check(game.projectiles.is_empty(), "bolt hitting solid cover is consumed")

func _test_player_before_cover_still_gets_hit() -> void:
	# A wall later in the same long segment must not shield a player in front of it.
	_fresh()
	game.player.position = Vector3(8.0, 0.03, 4.5)
	game.shoot(Vector3(8.0, 0.6, 3.0), Vector3.BACK, 11.0)
	game._update_projectiles(0.9)
	_check(is_equal_approx(game.health, 89.0), "player before a pillar is hit before the later wall collision")
	_check(game.projectiles.is_empty(), "bolt is consumed by the first player collision before cover")

func _test_unobstructed_bolt_still_hits() -> void:
	# Deleting every projectile is not a valid fix for cover collision.
	_fresh()
	game.player.position = Vector3(0.0, 0.03, 0.0)
	game.shoot(Vector3(0.0, 0.6, -2.0), Vector3.BACK, 11.0)
	game._update_projectiles(0.5)
	_check(is_equal_approx(game.health, 89.0), "unobstructed bolt still deals its real damage")
	_check(game.projectiles.is_empty(), "bolt is consumed after hitting the player")
