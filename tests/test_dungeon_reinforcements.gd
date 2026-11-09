extends SceneTree

const Game = preload("res://scenes/game.tscn")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func check_spawn(game) -> void:
	check(game.enemies.size() == 20 and game.dungeon.remaining == 50, "20 active of 50 total")
	for enemy in game.enemies:
		check(not game.vision.in_cone(enemy.position) and not enemy.visible, "spawn stays hidden")
		if enemy.kind != "captain":
			check(enemy.engaged and is_inf(enemy._stats.leash), "pursuit starts regardless of range")

func run() -> void:
	var game = Game.instantiate()
	game.loadout.save_path = ""
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.start_dungeon(173)
	var dungeon = game.dungeon
	var start: Vector2i = dungeon.current
	var neighbor: Vector2i = dungeon.rooms[start].links.values()[0]
	var direction := neighbor - start
	check(game.enemies.is_empty() and dungeon.remaining == 0 and dungeon.rooms[start].cleared, "start is safe immediately")
	var size: Variant = game.arena.get("room_half")
	check(size is Vector2 and size.x > game.arena.HALF.x and size.y > game.arena.HALF.y, "start room is larger")
	if failures > 0: quit(1); return
	check(not is_instance_valid(game.arena.gates) or game.arena.gates.get_child_count() == 0, "start gates are open")
	var start_depth: float = game.arena.CORRIDOR - .7
	game.player.position = Vector3(direction.x * (size.x + start_depth), .03, direction.y * (size.y + start_depth))
	dungeon.tick(game)
	if not "_room_fade" in game or game._room_fade == null:
		printerr("Crossing a doorway must begin a screen fade")
		quit(1)
		return
	var wipe: Vector2 = game._room_shade.material.get_shader_parameter("direction")
	var expected_wipe := Vector2(direction.x, direction.y)
	check(wipe.dot(expected_wipe) > .99, "curtain follows the doorway direction")
	var fade: Tween = game._room_fade
	fade.pause()
	fade.custom_step(.05)
	check(dungeon.current == start and float(game._room_shade.material.get_shader_parameter("progress")) > 0.0 and float(game._room_shade.material.get_shader_parameter("progress")) < 1.0, "old room fades before crossing")
	var paused_at: float = game.run_time
	game.tick(.02)
	check(game.run_time == paused_at, "combat waits for the door transition")
	fade.custom_step(.091)
	check(dungeon.current == neighbor and is_equal_approx(game._room_shade.material.get_shader_parameter("progress"), 1.0), "room swaps behind the black screen")
	fade.custom_step(.07)
	var progress: float = game._room_shade.material.get_shader_parameter("progress")
	check(progress > 1.0 and progress < 2.0, "new room fades in")
	fade.custom_step(.20)
	check(game._room_fade == null and not game._room_shade.visible, "transition releases control and hides the shade")
	check(dungeon.current == neighbor, "walk out of the safe start")
	check_spawn(game)
	var fight_room: Vector2i = neighbor
	var exit_room: Vector2i = start
	var exit_direction := exit_room - fight_room
	for entrance in [Vector2i.ZERO, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		for index in 8:
			var angle := index * TAU / 8.0
			game.test_aim = Vector3(cos(angle), 0, sin(angle))
			dungeon.enter(game, fight_room, entrance)
			check_spawn(game)
			await process_frame

	# Force a long approach with a stone cover centered on the direct route.
	game.test_aim = Vector3.LEFT
	dungeon.enter(game, fight_room)
	game.clear_actors()
	var cover: Vector3 = game.arena.obstacles[0]
	var axis := Vector3(signf(cover.x), 0, 0)
	game.player.position = cover - axis * 5.0 + Vector3.UP * .03
	var enemy = game.spawn_enemy("fisherman", cover + axis * 4.0 + Vector3.UP * .03)
	enemy.engaged = true
	enemy._stats.leash = INF
	enemy._stats.speed *= 1.35
	var initial_distance: float = enemy.position.distance_to(game.player.position)
	await physics_frame
	for frame in 780:
		enemy.tick(1.0 / 120.0, game)
	check(initial_distance > enemy._stats.detection and enemy.position.distance_to(game.player.position) < 2.5, "distant enemy approaches around solid cover")

	dungeon.enter(game, fight_room)
	var first = game.enemies[0]
	first.receive_damage(100000, Vector3.ZERO)
	dungeon.tick(game)
	check(dungeon.remaining == 49 and is_instance_valid(game.arena.gates), "one death counts and gates stay locked")
	check(game.enemies.size() == 20, "the fading body still occupies its slot")
	first.death_time = 1.0
	await physics_frame
	game.tick(1.0/120.0)
	check(game.enemies.size() == 20 and dungeon.remaining == 49 and not game.enemies.has(first), "one reinforcement fills the released slot")
	check(not game.vision.in_cone(game.enemies.back().position) and not game.enemies.back().visible, "reinforcement spawns hidden")
	dungeon.enter(game, fight_room)
	await clear_room(game)
	check(dungeon.rooms[fight_room].cleared and dungeon.remaining == 0 and dungeon.cleared == 1, "room clears after 50 kills")
	check(not is_instance_valid(game.arena.gates), "gate opens at zero remaining")

	var room_half: Vector2 = game.arena.HALF
	var exit_depth: float = game.arena.CORRIDOR - .7
	game.player.position = Vector3(exit_direction.x * (room_half.x + exit_depth), .03, exit_direction.y * (room_half.y + exit_depth))
	dungeon.tick(game)
	await game._room_fade.finished
	check(dungeon.current == exit_room and game.enemies.is_empty(), "open gate leads back into the safe start")
	dungeon.enter(game, fight_room)
	check(game.enemies.is_empty() and dungeon.remaining == 0, "cleared rooms stay empty")

	dungeon.enter(game, dungeon.goal)
	check_spawn(game)
	var captains := await clear_room(game)
	check(captains == 1 and game.mode == "victory", "boss room includes captain among the 50")
	check_layout_seeds(dungeon)
	print("DUNGEON ENCOUNTERS ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func clear_room(game) -> int:
	var captains := 0
	var defeated := 0
	for batch in [20, 20, 10]:
		check(game.enemies.size() == batch, "active count stays capped")
		for actor in game.enemies:
			if actor.kind == "captain":
				captains += 1
			actor.receive_damage(100000, Vector3.ZERO)
			actor.death_time = 1.0
			defeated += 1
		if defeated < 50:
			game.dungeon.tick(game)
			check(game.dungeon.remaining == 50 - defeated and is_instance_valid(game.arena.gates), "pending enemies keep doors locked")
		await physics_frame
		game.tick(1.0 / 120.0)
	check(defeated == 50, "exactly fifty opponents")
	return captains

func check_layout_seeds(dungeon) -> void:
	var has_interior_goal := false
	for seed_value in range(64):
		dungeon.generate(seed_value)
		var inward: Vector2i = dungeon.inward_direction
		var origin: Vector2i = dungeon.start
		var trapped := 0
		var extent := 0
		for room: Vector2i in dungeon.rooms:
			if dungeon.rooms[room].get("has_trap", false): trapped += 1
			var progress: int = (room.x - origin.x) * inward.x + (room.y - origin.y) * inward.y
			check(progress >= 0, "entrance is on the outer edge")
			extent = maxi(extent, progress)
		check(trapped > 0 and trapped < dungeon.rooms.size() - 1, "layout mixes trapped and safe rooms")
		check(not dungeon.rooms[origin].get("has_trap", false), "the starting room has no trap")
		var goal_progress: int = (dungeon.goal.x - origin.x) * inward.x + (dungeon.goal.y - origin.y) * inward.y
		check(goal_progress >= ceili(extent * .65), "goal falls in the opposite part of the map")
		check(dungeon.rooms[dungeon.goal].depth >= 4, "goal is several rooms away")
		check(dungeon.rooms[origin].enemies.is_empty() and dungeon.rooms[origin].cleared, "seeded start contains no monsters")
		has_interior_goal = has_interior_goal or goal_progress < extent
	check(has_interior_goal, "some seeds place the objective before the outer edge")
