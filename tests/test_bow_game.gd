extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var entry = load("res://scenes/opening/coastal_combat_entry.tscn").instantiate()
	root.add_child(entry)
	current_scene = entry
	var game = entry.game
	game.set_physics_process(false)
	game.start_dungeon(173)
	game.clear_actors()
	await physics_frame
	await physics_frame
	game.test_aim = Vector3.RIGHT
	if not game.set_weapon_family("bow"):
		printerr("Bow cannot be equipped")
		quit(1)
		return
	var origin: Vector3 = game.player.position
	var ranges: Array[float] = []
	var damage: Array[float] = []
	for count in [0, 55, 115]:
		send_click(true)
		if game.bow_tier() != 1:
			printerr("Bow could not start from left click")
			quit(1)
			return
		for frame in count:
			game.tick(1.0 / 120.0)
		var before: int = game.staff_flight.shots_fired
		send_click(false)
		if game.staff_flight.shots_fired != before + 1:
			printerr("Bow could not release from left click")
			quit(1)
			return
		var shot: Dictionary = game.staff_flight.active.back()
		ranges.append(shot.max_range)
		damage.append(shot.damage)
		for frame in 25:
			game.tick(1.0 / 120.0)
		var moved: float = game.player.position.x - origin.x
		if (count < 115 and absf(moved) > 0.05) or (count == 115 and (moved > -0.6 or moved < -1.4)):
			printerr("Wrong backstep for charge ", count, ": ", moved)
			quit(1)
			return
	var passed: bool = ranges[0] < ranges[1] and ranges[1] < ranges[2] and damage[0] < damage[1] and damage[1] < damage[2]
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, 3.0, 3.0)
	collision.shape = shape
	wall.add_child(collision)
	game.add_child(wall)
	wall.position = game.player.position + Vector3(-0.72, 0.5, 0)
	await physics_frame
	await physics_frame
	var before_wall: Vector3 = game.player.position
	var shots_before: int = game.staff_flight.shots_fired
	send_click(true)
	for frame in 115:
		game.tick(1.0 / 120.0)
	send_click(false)
	for frame in 25:
		game.tick(1.0 / 120.0)
	var wall_distance: float = before_wall.x - game.player.position.x
	passed = passed and wall_distance > 0.0 and wall_distance < 0.60 and game.staff_flight.shots_fired == shots_before + 1
	send_click(true)
	game.toggle_pause()
	send_click(false)
	passed = passed and game.bow_tier() == 0 and game.staff_flight.shots_fired == shots_before + 1
	game.toggle_pause()
	game.start_run(true)
	game.clear_actors()
	game.set_weapon_family("bow")
	await physics_frame
	await physics_frame
	var target = game.spawn_enemy("dummy", game.player.position + Vector3.RIGHT * 2.0)
	var health_before: float = target.health
	send_click(true)
	send_click(false)
	for frame in 19:
		game.tick(1.0 / 120.0)
	passed = passed and target.health < health_before
	print("Backstep against wall: ", wall_distance, ", arrow damage applied: ", health_before - target.health)
	print("Bow charge ", "PASS" if passed else "FAIL", " ranges=", ranges, " damage=", damage)
	quit(0 if passed else 1)

func send_click(pressed: bool) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = pressed
	click.position = Vector2(620, 400)
	root.push_input(click, true)
