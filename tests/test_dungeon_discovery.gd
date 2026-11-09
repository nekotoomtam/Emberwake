extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	var dungeon = game.dungeon
	var expect_trap := "--trap" in OS.get_cmdline_user_args()
	var seed_ := 173
	var found := false
	for candidate in range(seed_, seed_ + 64):
		dungeon.generate(candidate)
		var first: Vector2i = dungeon.rooms[dungeon.start].links.values()[0]
		if dungeon.rooms[first].has_trap == expect_trap:
			seed_ = candidate
			found = true
			break
	if not found:
		printerr("Could not find a test room with trap=", expect_trap)
		quit(1)
		return
	game.start_dungeon(seed_)
	if not dungeon.has_method("map_rooms"):
		printerr("Dungeon still exposes the entire room graph")
		quit(1)
		return
	var start: Vector2i = dungeon.start
	var links: Dictionary = dungeon.rooms[start].links
	var seen: Dictionary = dungeon.map_rooms()
	var masked: bool = seen.size() == links.size() + 1 and seen[start] and not seen.has(dungeon.goal)
	for target: Vector2i in links.values(): masked = masked and not seen[target]
	var direction: Vector2i = links.keys()[0]
	var outward = game.arena.layout.get_node_or_null("UnexploredExit_%d_%d" % [direction.x, direction.y])
	var dark_outbound: bool = outward != null
	var next_room: Vector2i = links[direction]
	if not game.has_method("try_peek_dungeon_exit"):
		printerr("Dungeon peek is unavailable")
		quit(1)
		return
	var axis := Vector3(direction.x, 0, direction.y)
	var boundary: float = game.arena.room_half.x if direction.x != 0 else game.arena.room_half.y
	game.player.position = axis * (boundary - 1.2) + Vector3.UP * .03
	var prior_camera: Transform3D = game.camera.global_transform
	var trail := game.arena.layout.find_child("ForestTrail_%d_%d" % [direction.x, direction.y], true, false) as MeshInstance3D
	if trail == null or not trail.mesh is ArrayMesh:
		printerr("A forest exit should have an irregular terrain trail")
		quit(1)
		return
	press_key(KEY_E)
	var peek = game.dungeon_peek
	var opened: bool = peek.visible and peek.preview_room != null and dungeon.current == start and not dungeon.visited.has(next_room)
	var preview: Node3D = peek.preview_room
	var half: float = game.arena.HALF.x if direction.x != 0 else game.arena.HALF.y
	if preview == null or preview.get_viewport() == root:
		printerr("Scout view must show only the other room")
		quit(1)
		return
	var eye: Vector3 = peek._eyes
	var at_entry: bool = is_equal_approx(eye.dot(axis), -half + .45)
	var scout_camera: Camera3D = peek.scene_camera
	var forward: Vector3 = peek.forward
	var side := Vector3(-axis.z, 0, axis.x)
	var target: Vector3 = eye + axis * 6.0
	peek.aim_at(scout_camera.unproject_position(target + side * 5.0))
	var right: bool = peek.forward.dot(side) > 0.05
	peek.aim_at(scout_camera.unproject_position(target - side * 5.0))
	var left: bool = peek.forward.dot(side) < -0.05
	var range_matches: bool = is_equal_approx(peek.sight_range, game.vision.reach())
	var wall := AABB(eye + axis * 2.0 - Vector3(.35, 0, .35), Vector3(.7, 2.0, .7))
	peek.sight_boxes.append(wall)
	var clipped: bool = peek.ray_distance(axis) < 2.5
	peek.sight_boxes.pop_back()
	var sight_open: bool = scout_camera.global_basis.is_equal_approx(prior_camera.basis) and at_entry and trail.is_visible_in_tree() and game.camera.global_transform.is_equal_approx(prior_camera) and forward.is_equal_approx(axis) and left and right and range_matches and clipped
	var prior_time: float = game.run_time
	game.tick(.2)
	var frozen: bool = is_equal_approx(game.run_time, prior_time)
	var contents: Array = peek.get("encounter_props") if "encounter_props" in peek else []
	if contents.is_empty() or is_instance_valid(peek.preview_room.trap) != expect_trap:
		printerr("Scout room contents do not match the roll")
		quit(1)
		return
	var opening: Dictionary = dungeon.rooms[next_room].opening
	var old_position: Vector3 = contents[0].position
	peek._process(.5)
	var animation: String = contents[0].sprite.animation
	var walking: bool = old_position.distance_to(contents[0].position) > .1 and (animation.ends_with("_walk") or animation.ends_with("_run"))
	var saved_position: bool = contents[0].position.is_equal_approx(opening.enemies[0].position)
	var trap_position: Vector3 = peek.preview_room.trap.position if expect_trap else Vector3.ZERO
	var actors_frozen: bool = game.enemies.is_empty() and game.health == game.max_health()
	peek.aim_at(scout_camera.unproject_position(target))
	var shows_trap: bool = contents[0].visible and (not expect_trap or contents.back().visible)
	peek.aim_at(scout_camera.unproject_position(target + side * 9.0))
	var hides_trap: bool = not expect_trap or not contents.back().visible
	if not "walkable_outline" in peek.preview_room:
		printerr("Forest preview has no shaped walkable boundary")
		quit(1)
		return
	var scout_outline: PackedVector2Array = peek.preview_room.walkable_outline
	var floor_preview := soil_signature(peek.preview_room)
	if floor_preview.size() < 5:
		printerr("Forest floor should blend multiple independent 2D illustrations")
		quit(1)
		return
	var seen_cover: Array = peek.preview_room.obstacles.duplicate() if opened else []
	press_key(KEY_ESCAPE)
	var closed: bool = not peek.visible and peek.preview_room == null and game.arena.peek_exits.has(direction) \
		and trail.is_visible_in_tree() and game.camera.global_transform.is_equal_approx(prior_camera)
	var after_peek: Vector3 = opening.enemies[0].position
	dungeon.tick(game, .35)
	var continued: bool = after_peek.distance_to(opening.enemies[0].position) > .1
	var enemy_positions: Array = []
	for placement in opening.enemies: enemy_positions.append(placement.position)
	game.player.position = axis * (boundary + game.arena.CORRIDOR - .7) + Vector3.UP * .03
	dungeon.tick(game)
	await game._room_fade.finished
	seen = dungeon.map_rooms()
	var same_actors := true
	for index in enemy_positions.size():
		var enemy = game.enemies[index]
		same_actors = same_actors and enemy.position.is_equal_approx(enemy_positions[index]) and enemy.engaged and enemy.kind == opening.enemies[index].kind
	var trap_matches := not is_instance_valid(game.arena.trap)
	var trap_works: bool = opening.trap.is_empty()
	if expect_trap:
		trap_matches = is_instance_valid(game.arena.trap) and game.arena.trap.position.is_equal_approx(trap_position)
		game.player.position = trap_position
		var before_trap: float = game.health
		dungeon.tick(game)
		trap_works = game.health < before_trap and opening.trap.spent and not is_instance_valid(game.arena.trap)
	var soil_matches: bool = floor_preview == soil_signature(game.arena) and grass_crosses_edge(game.arena)
	var matches: bool = seen_cover == game.arena.obstacles and not seen_cover.is_empty() and scout_outline == game.arena.walkable_outline and soil_matches
	var outlines := []
	var paths_open := true
	for variant in 3:
		var forest = game.arena
		forest.build_room({Vector2i.UP: true, Vector2i.DOWN: true, Vector2i.LEFT: true, Vector2i.RIGHT: true}, variant, true)
		outlines.append(forest.walkable_outline)
		paths_open = paths_open and not forest.is_walkable(Vector3(forest.HALF.x - 1.0, .03, forest.HALF.y - 1.0))
		for door in forest.DIRECTIONS:
			var entry: Vector3 = forest.entry_position(door)
			for index in 10:
				paths_open = paths_open and forest.is_walkable(entry.lerp(Vector3.ZERO, index / 10.0))
	var first_ground := soil_signature(game.arena)
	var no_dark_exits: Array[Vector2i] = []
	game.arena.build_room({Vector2i.UP: true, Vector2i.DOWN: true, Vector2i.LEFT: true, Vector2i.RIGHT: true}, 2, true, false, no_dark_exits, Vector2i.ZERO, "", Vector3.ZERO, 0, 735)
	var second_ground := soil_signature(game.arena)
	var ground_varies: bool = first_ground != second_ground
	matches = matches and ground_varies and paths_open and outlines[0] != outlines[1] and outlines[0] != outlines[2] and outlines[1] != outlines[2]
	var revealed: bool = dungeon.current == next_room and seen[start] and seen[next_room] and game.arena.layout.get_node_or_null("UnexploredExit_%d_%d" % [-direction.x, -direction.y]) == null
	dungeon.enter(game, start, direction)
	seen = dungeon.map_rooms()
	var remembered: bool = seen[next_room] and game.arena.layout.get_node_or_null("UnexploredExit_%d_%d" % [direction.x, direction.y]) == null and not game.arena.peek_exits.has(direction)
	game.start_dungeon(seed_)
	var reset: bool = dungeon.map_rooms().size() == links.size() + 1
	var passed: bool = saved_position and continued and walking and actors_frozen and shows_trap and hides_trap and same_actors and trap_matches and trap_works and masked and dark_outbound and revealed and remembered and reset and opened and sight_open and closed and frozen and matches and not game.arena.peek_exits.is_empty()
	print("DUNGEON DISCOVERY ", "PASS" if passed else "FAIL", " expected trap=", expect_trap, " masked=", masked, " dark passage=", dark_outbound, " reveal=", revealed, " remembered=", remembered, " reset=", reset, " opened=", opened, " kept bush=", closed, " actual layout=", matches, " soil parity and variation=", [soil_matches, ground_varies], " forest routes=", paths_open, " walking=", [walking, saved_position, continued], " frozen actors=", actors_frozen, " trap visibility=", [shows_trap, hides_trap], " same encounter=", same_actors, " trap=", [trap_matches, trap_works])
	quit(0 if passed else 1)

func press_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)

func soil_signature(room: Node3D) -> Array:
	var detail := room.find_child("SoilDetails", true, false)
	var result := []
	if detail == null: return result
	for node in detail.get_children():
		result.append(node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	return result

func grass_crosses_edge(room: Node3D) -> bool:
	var grass := room.find_child("Soil_green_floor", true, false) as MeshInstance3D
	if grass == null: return false
	for point: Vector3 in grass.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if not room.is_walkable(point): return true
	return false
