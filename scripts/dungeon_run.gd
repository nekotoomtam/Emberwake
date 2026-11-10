extends RefCounted
## A seeded tree of walkable rooms. Combat state belongs to the active room.
const WETLAND_CHANCE := .18
const Room = preload("res://scripts/dungeon_room.gd")
const Roster = preload("res://scripts/coastal_roster.gd")
const CoastalEnemy = preload("res://scripts/coastal_enemy.gd")
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const GRAPH_ORIGIN := Vector2i.ZERO
const ACTIVE_ENEMY_LIMIT := 20
const ENEMIES_PER_ROOM := 50
const TRAP_CHANCE := .35
const PURSUIT_SPEED_MULTIPLIER := 1.35
const SPAWN_SIGHT_MARGIN := 0.85

var rooms: Dictionary = {}
var visited: Dictionary = {}
var current := GRAPH_ORIGIN
var start := GRAPH_ORIGIN
var goal := GRAPH_ORIGIN
var inward_direction := Vector2i.RIGHT
var seed_value: int
var cleared := 0
var remaining := 0
var _next_enemy := 0
var _spawn_retry_at := 0.0
var _spawn_candidates: Array[Vector3] = []


func generate(seed_: int) -> void:
	seed_value = seed_
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	rooms.clear()
	visited.clear()
	current = GRAPH_ORIGIN
	cleared = 0
	remaining = 0
	_next_enemy = 0
	_spawn_retry_at = 0.0
	_spawn_candidates.clear()
	var count := rng.randi_range(30, 50)
	rooms[GRAPH_ORIGIN] = make_room(rng)
	var frontier: Array[Vector2i] = [GRAPH_ORIGIN]
	var first_direction := rng.randi_range(0, 3)
	for offset in [0, rng.randi_range(1, 3)]:
		var direction: Vector2i = DIRECTIONS[(first_direction + offset) % 4]
		add_room(GRAPH_ORIGIN, direction, rng)
		frontier.append(direction)
	while rooms.size() < count:
		var index := rng.randi_range(0, frontier.size() - 1)
		var parent := frontier[index]
		var open: Array[Vector2i] = []
		for direction: Vector2i in DIRECTIONS:
			if not rooms.has(parent + direction):
				open.append(direction)
		if open.is_empty():
			frontier.remove_at(index)
			continue
		var direction := open[rng.randi_range(0, open.size() - 1)]
		add_room(parent, direction, rng)
		frontier.append(parent + direction)
	# Separate reserve rolls preserve the seeded room graph and opening roster.
	var reserve_rng := RandomNumberGenerator.new()
	reserve_rng.seed = hash([seed_, "reserves"])
	for room: Dictionary in rooms.values():
		_append_enemies(room.enemies, ENEMIES_PER_ROOM, reserve_rng)
	_pick_route_ends(rng)
	var trap_rng := RandomNumberGenerator.new()
	trap_rng.seed = hash([seed_, "room_traps"])
	var terrain_rng := RandomNumberGenerator.new()
	terrain_rng.seed = hash([seed_, "special_forest_rooms"])
	for at: Vector2i in rooms:
		var room: Dictionary = rooms[at]
		var roll := terrain_rng.randf()
		room.feature = ""
		if at != start and at != goal:
			if roll < WETLAND_CHANCE: room.feature = "wetland"
			elif roll < .36: room.feature = "mushrooms"
		room.feature_origin = Vector3.ZERO
		room.floor_seed = hash([seed_, at, "forest_ground"])
		room.feature_seed = hash([seed_, at, "wetland_shape"]) if room.feature == "wetland" else 0
		room.has_trap = at != start and trap_rng.randf() < TRAP_CHANCE and room.feature.is_empty()
	rooms[start].enemies.clear()
	rooms[start].cleared = true
	var boss_room: Dictionary = rooms[goal]
	boss_room.enemies[boss_room.enemies.size() - 1] = "captain"


func _pick_route_ends(rng: RandomNumberGenerator) -> void:
	var low := GRAPH_ORIGIN
	var high := GRAPH_ORIGIN
	for at: Vector2i in rooms:
		low = low.min(at)
		high = high.max(at)
	var span := high - low
	var directions: Array[Vector2i] = []
	for direction: Vector2i in DIRECTIONS:
		if (span.x if direction.x != 0 else span.y) >= 4:
			directions.append(direction)
	inward_direction = directions[rng.randi_range(0, directions.size() - 1)]
	var edge := mini(_along_route(low), _along_route(high))
	var extent := span.x if inward_direction.x != 0 else span.y
	var starts: Array[Vector2i] = []
	var goals: Array[Vector2i] = []
	var goal_progress := maxi(4, ceili(extent * .65))
	for at: Vector2i in rooms:
		var progress := _along_route(at) - edge
		if progress == 0: starts.append(at)
		if progress >= goal_progress: goals.append(at)
	start = starts[rng.randi_range(0, starts.size() - 1)]
	goal = goals[rng.randi_range(0, goals.size() - 1)]
	current = start

	# The graph is a tree. Recompute travel depth from the chosen entrance.
	var pending: Array[Vector2i] = [start]
	rooms[start].depth = 0
	while not pending.is_empty():
		var at: Vector2i = pending.pop_front()
		for neighbor: Vector2i in rooms[at].links.values():
			if rooms[neighbor].depth >= 0: continue
			rooms[neighbor].depth = rooms[at].depth + 1
			pending.append(neighbor)


func _along_route(at: Vector2i) -> int:
	return at.x * inward_direction.x + at.y * inward_direction.y


func make_room(rng: RandomNumberGenerator) -> Dictionary:
	var enemies: Array[String] = []
	_append_enemies(enemies, ACTIVE_ENEMY_LIMIT, rng)
	return {"links": {}, "depth": -1, "enemies": enemies, "cleared": false,
		"variant": rng.randi_range(0, 2)}


func _append_enemies(enemies: Array[String], total: int, rng: RandomNumberGenerator) -> void:
	var kinds := Roster.kinds()
	for i in range(enemies.size(), total):
		# Leave most slots for melee so that a single room is still readable.
		var pool := kinds.size() if i % 4 == 0 else 3
		enemies.append(kinds[rng.randi_range(0, pool - 1)])


func add_room(parent: Vector2i, direction: Vector2i, rng: RandomNumberGenerator) -> void:
	var at := parent + direction
	var room := make_room(rng)
	room.links[-direction] = parent
	rooms[parent].links[direction] = at
	rooms[at] = room


func map_rooms() -> Dictionary:
	var known := visited.duplicate()
	for at: Vector2i in visited:
		for neighbor: Vector2i in rooms[at].links.values():
			if not known.has(neighbor): known[neighbor] = false
	return known


func prepare_room(at: Vector2i, entrance: Vector2i) -> Dictionary:
	var room: Dictionary = rooms[at]
	if room.cleared: return {}
	if not room.has("opening"):
		var axis := Vector3(entrance.x, 0, entrance.y)
		var across := Vector3(-axis.z, 0, axis.x)
		var half := Room.HALF.x if entrance.x != 0 else Room.HALF.y
		var edge := axis * half + Vector3.UP * .03
		var enemies: Array[Dictionary] = []
		var slots := [Vector2(5.6, 0), Vector2(8.0, -1.1), Vector2(10.4, 1.1)]
		for index in mini(slots.size(), room.enemies.size()):
			var slot: Vector2 = slots[index]
			var point := edge - axis * slot.x + across * slot.y
			enemies.append({"kind": room.enemies[index], "position": point, "center": point, "facing": across})
		var trap: Dictionary = {}
		if room.has_trap:
			trap = {"position": edge - axis * 3.2, "spent": false}
		room.opening = {"enemies": enemies, "trap": trap, "across": across, "patrol_time": 0.0}
		advance_patrol(room.opening, 0.0)
	return room.opening


static func advance_patrol(opening: Dictionary, delta: float) -> void:
	if opening.is_empty(): return
	opening.patrol_time += delta
	for index in opening.enemies.size():
		var placement: Dictionary = opening.enemies[index]
		var phase: float = opening.patrol_time * (.83 + .07 * index) + index * 1.2
		placement.position = placement.center + opening.across * (1.45 * sin(phase))
		placement.facing = opening.across * (1.0 if cos(phase) >= 0.0 else -1.0)


func enter(game, at: Vector2i, entrance: Vector2i = Vector2i.ZERO) -> void:
	current = at
	visited[at] = true
	var room: Dictionary = rooms[current]
	var dark_exits: Array[Vector2i] = []
	for direction: Vector2i in room.links:
		if not visited.has(room.links[direction]): dark_exits.append(direction)
	game.clear_actors()
	game.vision.reset_cues()
	game.arena.build_room(room.links, room.variant, room.cleared, at == start, dark_exits, Vector2i.ZERO, room.feature, room.feature_origin, room.feature_seed, room.floor_seed)
	game.player.position = game.arena.entry_position(entrance)
	game.player.velocity = Vector3.ZERO
	game.place_companions()
	game._camera_focus = game.player.position
	game.camera.position = game._camera_focus + game.CAMERA_OFFSET
	game.camera.look_at(game._camera_focus)
	remaining = 0
	_next_enemy = 0
	_spawn_retry_at = 0.0
	_spawn_candidates.clear()
	if room.cleared:
		if room.has("opening"): game.arena.show_trap(room.opening.trap)
		return
	var approach := entrance if entrance != Vector2i.ZERO else Vector2i.LEFT
	var opening := prepare_room(at, approach)
	game.arena.show_trap(opening.trap)
	var room_half: Vector2 = game.arena.room_half
	for x in range(-int(room_half.x) + 1, int(room_half.x), 2):
		for z in range(-int(room_half.y) + 1, int(room_half.y), 2):
			var point := Vector3(x, .03, z)
			if game.arena.is_walkable(point, .85) and game.arena.obstacles.all(func(cover: Vector3) -> bool: return cover.distance_squared_to(point) >= 4.0):
				_spawn_candidates.append(point)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, at])
	for index in range(_spawn_candidates.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var point := _spawn_candidates[index]
		_spawn_candidates[index] = _spawn_candidates[other]
		_spawn_candidates[other] = point
	remaining = room.enemies.size()
	if room.get("scouted", false):
		for placement in opening.enemies:
			_spawn_dungeon_enemy(game, placement.kind, placement.position)
	_spawn_hidden_enemies(game, room.enemies)


func _spawn_hidden_enemies(game, roster: Array) -> void:
	var player_position: Vector3 = game.player.position
	for index in range(_spawn_candidates.size() - 1, -1, -1):
		if _next_enemy >= roster.size() or game.enemies.size() >= ACTIVE_ENEMY_LIMIT:
			break
		var point := _spawn_candidates[index]
		if player_position.distance_squared_to(point) < 16.0:
			continue
		# Use the cone itself because a newly built room's walls may not yet
		# be visible to the physics ray queries on the entry frame.
		if game.vision.in_cone(point) or DIRECTIONS.any(func(side: Vector2i) -> bool:
			return game.vision.in_cone(point + Vector3(side.x, 0, side.y) * SPAWN_SIGHT_MARGIN)
		):
			continue
		if game.enemies.any(func(enemy) -> bool:
			return is_instance_valid(enemy) and point.distance_squared_to(enemy.position) < 2.25
		):
			continue
		_spawn_dungeon_enemy(game, roster[_next_enemy], point).hide()
	if _next_enemy < roster.size() and game.enemies.size() < ACTIVE_ENEMY_LIMIT:
		_spawn_retry_at = game.run_time + .1


func _spawn_dungeon_enemy(game, kind: String, point: Vector3) -> Node3D:
	var enemy: Node3D = game.spawn_enemy(kind, point)
	if enemy is CoastalEnemy:
		enemy.engaged = true
		enemy._stats.leash = INF
		enemy._stats.speed *= PURSUIT_SPEED_MULTIPLIER
	_next_enemy += 1
	return enemy


func tick(game, delta: float = 0.0) -> void:
	var room: Dictionary = rooms[current]
	if room.cleared and delta > 0.0:
		for next: Vector2i in room.links.values():
			var neighbor: Dictionary = rooms[next]
			if neighbor.get("scouted", false) and not visited.has(next):
				advance_patrol(neighbor.opening, delta)
	if is_instance_valid(game.arena.hazards): game.arena.hazards.tick(delta, game)
	if is_instance_valid(game.arena.trap):
		var trap_position: Vector3 = game.arena.trap.position
		var offset: Vector3 = game.player.position - trap_position
		if Vector2(offset.x, offset.z).length_squared() <= .65 * .65:
			room.opening.trap.spent = true
			game.arena.hide_trap()
			game.fx.ring(trap_position, .65, Color("#ef8058"), .42)
			game.damage_player(12.0, Vector3.INF, 1.0, "physical", "left_shin", -1.0, false, &"area")
	if game.mode != "combat": return
	if not room.cleared:
		var roster: Array = room.enemies
		# Fading corpses keep their slots until the normal actor cleanup.
		if _next_enemy < roster.size() and game.enemies.size() < ACTIVE_ENEMY_LIMIT and game.run_time >= _spawn_retry_at:
			_spawn_hidden_enemies(game, roster)
		remaining = roster.size() - _next_enemy
		for enemy in game.enemies:
			if is_instance_valid(enemy) and not enemy.dead:
				remaining += 1
		if remaining > 0:
			return
		room.cleared = true
		cleared += 1
		game.clear_hostile_projectiles()
		game.arena.unlock_doors()
		game.reward_dungeon_clear_health()
		game.stamina = game.stats.value("max_stamina")
		game.flasks.charges = mini(3, game.flasks.charges + 1)
		if current == goal:
			game.finish_coast()
			return
	var direction: Vector2i = game.arena.exit_direction(game.player.position)
	if room.links.has(direction):
		game.change_dungeon_room(room.links[direction], direction)
