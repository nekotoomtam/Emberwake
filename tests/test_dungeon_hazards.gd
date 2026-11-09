extends SceneTree
const Wetland = preload("res://scripts/dungeon_wetland.gd")
const Forest = preload("res://scripts/dungeon_forest.gd")

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var game = load("res://scenes/game.tscn").instantiate()
	game.loadout.save_path = ""
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	var dungeon = game.dungeon
	var water = null
	var spores = null
	var seed_ := 173
	for candidate in range(173, 900):
		dungeon.generate(candidate)
		for at: Vector2i in dungeon.rooms[dungeon.start].links.values():
			match dungeon.rooms[at].get("feature", ""):
				"wetland": water = at
				"mushrooms": spores = at
		if water != null and spores != null:
			seed_ = candidate
			break
		water = null
		spores = null
	if water == null or spores == null:
		printerr("Test seed needs both special rooms connected to the start")
		quit(1)
		return
	game.start_dungeon(seed_)
	var direction: Vector2i = water - dungeon.start
	var axis := Vector3(direction.x, 0, direction.y)
	var border: float = game.arena.room_half.x if direction.x != 0 else game.arena.room_half.y
	game.player.position = axis * (border - 1.3) + Vector3.UP * .03
	var scout_zones: Array[Dictionary] = []
	var scout: bool = game.try_peek_dungeon_exit()
	if scout:
		var preview = game.dungeon_peek.preview_room.hazards
		scout = preview != null and preview.feature == "wetland" and preview.position == dungeon.rooms[water].feature_origin
		if scout: scout_zones = preview.wetland_zones.duplicate(true)
		game.dungeon_peek.close()
	dungeon.enter(game, water)
	var hazards = game.arena.hazards
	if not "wetland_zones" in hazards:
		printerr("Wetland should have seeded irregular terrain footprints")
		quit(1)
		return
	var layouts := varied_layouts()
	var dry_at: Vector3 = game.arena.entry_position(-direction)
	var wet: bool = hazards.speed_scale(dry_at) == 1.0
	var surfaces: Node3D = hazards.get_node_or_null("WetlandSurfaces")
	wet = wet and surfaces != null and surfaces.get_child_count() == hazards.wetland_zones.size()
	if surfaces != null:
		for patch in surfaces.get_children():
			wet = wet and patch.material_override is ShaderMaterial
	scout = scout and scout_zones == hazards.wetland_zones
	game.move_input = Vector2.RIGHT
	game.clear_actors()
	game.player.position = dry_at
	game.tick(1.0 / 120.0)
	var dry_speed: float = absf(game.player.velocity.x)
	for kind in ["water", "mud"]:
		if not hazards.wetland_zones.any(func(zone: Dictionary) -> bool: return zone.kind == kind):
			continue
		var at := inside_patch(hazards.wetland_zones, kind)
		var scale := .85 if kind == "water" else .65
		wet = wet and is_equal_approx(hazards.speed_scale(at), scale)
		game.player.position = at
		game.tick(1.0 / 120.0)
		wet = wet and dry_speed > 0.0 and is_equal_approx(absf(game.player.velocity.x), dry_speed * scale)
	game.move_input = Vector2.ZERO
	game.start_dungeon(seed_)
	var spore_direction: Vector2i = spores - dungeon.start
	var spore_axis := Vector3(spore_direction.x, 0, spore_direction.y)
	var spore_border: float = game.arena.room_half.x if spore_direction.x != 0 else game.arena.room_half.y
	game.player.position = spore_axis * (spore_border - 1.3) + Vector3.UP * .03
	var preview_grove := PackedVector3Array()
	var preview_trees: Array[Vector3] = []
	var preview_spores: Array[Vector3] = []
	if game.try_peek_dungeon_exit():
		var room = game.dungeon_peek.preview_room
		preview_grove = grove_vertices(room)
		preview_trees = room.obstacles.duplicate()
		preview_spores = spore_centers(room.hazards)
		game.dungeon_peek.close()
	dungeon.enter(game, spores)
	var grove: bool = not preview_grove.is_empty() and preview_grove == grove_vertices(game.arena)
	grove = grove and not preview_trees.is_empty() and preview_trees == game.arena.obstacles
	hazards = game.arena.hazards
	game.clear_actors()
	var poison_positions := spore_centers(hazards)
	if poison_positions.size() < 2:
		printerr("Expected scattered spore patches")
		quit(1)
		return
	grove = grove and preview_spores == poison_positions
	var patch = hazards.get_node("SporePatches").get_child(0)
	var mushroom_center: Vector3 = patch.global_position + Vector3.UP * .03
	var enemy = game.spawn_enemy("fisherman", mushroom_center + Vector3.RIGHT)
	game.player.position = Vector3(100, .03, 100)
	var enemy_hp: float = enemy.health
	var hp: float = game.health
	hazards.tick(.25, game)
	var warning: bool = patch.ring.visible and not patch.cloud.visible and game.health == hp and enemy.health == enemy_hp
	game.player.position = mushroom_center
	hazards.tick(.34, game)
	var pulse: bool = is_equal_approx(hp - game.health, 4.0) and enemy.health < enemy_hp and patch.cloud.visible and not patch.ring.visible
	for part in game.anatomy.PARTS:
		pulse = pulse and is_equal_approx(game.anatomy.integrity[part], 99.0)
	var detour: Vector3 = hazards.companion_motion(mushroom_center + Vector3(0, 0, -2.1), Vector3.BACK * 4.0)
	var avoided: bool = absf(detour.x) > .1
	game.player.position = Vector3(100, .03, 100)
	var safe_hp: float = game.health
	hazards.tick(.7, game)
	var safe: bool = game.health == safe_hp
	var passed := grove and scout and layouts and wet and warning and pulse and safe and avoided
	print("DUNGEON HAZARDS ", "PASS" if passed else "FAIL", " grove=", grove, " layouts=", layouts, " scout=", scout, " terrain=", wet, " warning=", warning, " poison=", pulse, " detour=", avoided, " outside=", safe)
	quit(0 if passed else 1)


func spore_centers(hazards: Node3D) -> Array[Vector3]:
	var centers: Array[Vector3] = []
	var patches := hazards.get_node_or_null("SporePatches")
	if patches == null: return centers
	for patch in patches.get_children():
		centers.append(patch.position)
	return centers


func grove_vertices(room: Node3D) -> PackedVector3Array:
	var mushrooms := room.layout.get_node_or_null("MushroomGrove") as MeshInstance3D
	if mushrooms == null: return PackedVector3Array()
	return mushrooms.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


func varied_layouts() -> bool:
	var mixes := {}
	for variant in 3:
		var outline := Forest.outline_for(Vector2(21.0, 15.7), 3.6, variant)
		var previous: Array[Dictionary] = []
		var crosses_center := false
		for seed_ in range(1, 101):
			var zones := Wetland.plan(outline, seed_)
			var total := 0.0
			var kinds := {}
			for index in zones.size():
				var zone: Dictionary = zones[index]
				total += Wetland.area(zone.outline)
				kinds[zone.kind] = true
				for point: Vector2 in zone.outline:
					if not Geometry2D.is_point_in_polygon(point, outline): return false
				crosses_center = crosses_center or Geometry2D.is_point_in_polygon(Vector2.ZERO, zone.outline)
				for other in range(index):
					if not Geometry2D.intersect_polygons(zone.outline, zones[other].outline).is_empty():
						return false
			var coverage := total / Wetland.area(outline)
			if zones.is_empty() or coverage > .4 or zones == previous or zones != Wetland.plan(outline, seed_):
				printerr("Wetland layout failed variant=", variant, " seed=", seed_, " coverage=", coverage)
				return false
			mixes["mixed" if kinds.size() == 2 else kinds.keys()[0]] = true
			previous = zones
		if not crosses_center: return false
	return mixes.size() == 3



func inside_patch(zones: Array[Dictionary], kind: String) -> Vector3:
	var point := Vector2.ZERO
	var largest := 0.0
	for zone in zones:
		if zone.kind != kind: continue
		var outline: PackedVector2Array = zone.outline
		var indices := Geometry2D.triangulate_polygon(outline)
		for i in range(0, indices.size(), 3):
			var a := outline[indices[i]]
			var b := outline[indices[i + 1]]
			var c := outline[indices[i + 2]]
			var size := absf((b - a).cross(c - a))
			if size > largest:
				largest = size
				point = (a + b + c) / 3.0
	return Vector3(point.x, .03, point.y)
