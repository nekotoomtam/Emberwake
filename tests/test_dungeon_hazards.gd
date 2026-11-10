extends SceneTree
const Wetland = preload("res://scripts/dungeon_wetland.gd")
const Forest = preload("res://scripts/dungeon_forest.gd")
const WeaponMotion = preload("res://scripts/weapon_motion.gd")

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
	var wet_growth: MeshInstance3D = game.arena.revelation_growth
	var forest_wide := wet_growth != null and wet_growth.mesh != null and not wet_growth.visible
	game.add_sanity(100)
	game._visual_tick(0)
	forest_wide = forest_wide and wet_growth.visible
	game.start_dungeon(seed_)
	var start_growth: MeshInstance3D = game.arena.revelation_growth
	forest_wide = forest_wide and start_growth != null and start_growth.mesh != null and not start_growth.visible
	var spore_direction: Vector2i = spores - dungeon.start
	var spore_axis := Vector3(spore_direction.x, 0, spore_direction.y)
	var spore_border: float = game.arena.room_half.x if spore_direction.x != 0 else game.arena.room_half.y
	game.player.position = spore_axis * (spore_border - 1.3) + Vector3.UP * .03
	var preview_grove := PackedVector3Array()
	var preview_trees: Array[Vector3] = []
	var preview_spores: Array[Vector3] = []
	var preview_growth := PackedVector3Array()
	if game.try_peek_dungeon_exit():
		var room = game.dungeon_peek.preview_room
		preview_grove = grove_vertices(room)
		preview_trees = room.obstacles.duplicate()
		preview_spores = spore_centers(room.hazards)
		preview_growth = room.revelation_growth.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		game.dungeon_peek.close()
	dungeon.enter(game, spores)
	var grove: bool = not preview_grove.is_empty() and preview_grove == grove_vertices(game.arena)
	var growth: MeshInstance3D = game.arena.revelation_growth
	var occupied_growth: PackedVector3Array = growth.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var growth_stable := not preview_growth.is_empty() and preview_growth == occupied_growth
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
	var integrity: Dictionary = game.anatomy.integrity.duplicate()
	game.add_sanity(95 - game.sanity)
	var hidden_root := check_root_ambush(game, hazards.root_ambush, false)
	game.player.position = Vector3(100, .03, 100)
	hazards.tick(.25, game)
	var warning: bool = patch.ring.visible and not patch.cloud.visible and game.sanity == 95
	game.player.position = mushroom_center
	hazards.tick(.34, game)
	game._visual_tick(0)
	var pulse: bool = game.sanity == 99 and patch.cloud.visible and not patch.ring.visible
	pulse = pulse and not game.has_sanity_revelation() and not game.ui.revelation_mist.visible
	growth_stable = growth_stable and not growth.visible
	var detour: Vector3 = hazards.companion_motion(mushroom_center + Vector3(0, 0, -2.1), Vector3.BACK * 4.0)
	var avoided: bool = absf(detour.x) > .1
	game.player.position = Vector3(100, .03, 100)
	hazards.tick(.7, game)
	var safe: bool = game.sanity == 99
	game.player.position = mushroom_center
	hazards.tick(.65, game)
	var capped: bool = game.sanity == 100
	game._visual_tick(0)
	var revealed: bool = game.has_sanity_revelation() and game.ui.revelation_mist.visible
	growth_stable = growth_stable and growth.visible
	game.ui._animate_revelation_mist(.35)
	var peak: float = game.ui.revelation_mist.self_modulate.a
	var mist_material: ShaderMaterial = game.ui.revelation_mist.material
	var filter_timed: bool = is_zero_approx(float(mist_material.get_shader_parameter("perception")))
	game.add_sanity(20)
	hazards.tick(.65, game)
	var above_cap: bool = game.sanity == 120
	var unharmed: bool = game.health == hp and game.anatomy.integrity == integrity and enemy.health == enemy_hp
	game.player.position = Vector3(100, .03, 100)
	game.add_sanity(-120)
	game._visual_tick(0)
	game.ui._animate_revelation_mist(1.0)
	var lingering: float = game.ui.revelation_mist.self_modulate.a
	filter_timed = filter_timed and is_equal_approx(float(mist_material.get_shader_parameter("perception")), 1.0)
	revealed = revealed and game.sanity == 100 and game.ui.revelation_mist.visible and peak > lingering and lingering > 0.0
	var visible_root := check_root_ambush(game, hazards.root_ambush, true)
	game.start_dungeon(185)
	game._visual_tick(0)
	revealed = revealed and not game.ui.revelation_mist.visible and not game.has_sanity_revelation()
	filter_timed = filter_timed and is_zero_approx(float(mist_material.get_shader_parameter("perception")))
	var passed := grove and scout and layouts and wet and warning and pulse and safe and avoided and capped and above_cap and unharmed and revealed and filter_timed and hidden_root and visible_root and growth_stable and forest_wide
	print("DUNGEON HAZARDS ", "PASS" if passed else "FAIL", " grove=", grove, " layouts=", layouts, " scout=", scout, " terrain=", wet, " warning=", warning, " spores=", pulse, " detour=", avoided, " outside=", safe, " capped=", capped and above_cap, " unharmed=", unharmed, " revelation=", revealed, " filter=", filter_timed)
	print("ROOT AMBUSH hidden=", hidden_root, " revealed=", visible_root)
	print("LIVING FOREST consistent across views and visible at 100=", growth_stable)
	print("LIVING FOREST available in wetland and start room=", forest_wide)
	quit(0 if passed else 1)


func check_root_ambush(game, root_ambush, revealed: bool) -> bool:
	var edge: Vector2 = root_ambush._edges[0]
	var point := edge - edge.normalized() * 2.7
	var player_at := Vector3(point.x, .03, point.y)
	game.player.position = player_at
	game.player.velocity = Vector3.ZERO
	root_ambush.tick(6.0, game)
	if root_ambush._elapsed >= 0.0:
		return false
	game.player.velocity = Vector3.RIGHT
	for i in 24:
		root_ambush.tick(.65, game)
		if root_ambush._elapsed >= 0.0:
			break
	game.player.velocity = Vector3.ZERO
	if root_ambush._elapsed < 0.0 or root_ambush.visible != revealed:
		return false
	var hp: float = game.health
	game._iframes = 0.0
	var direction: Vector3 = root_ambush._forward
	root_ambush.tick(.45, game)
	if game.health != hp or not root_ambush._forward.is_equal_approx(direction):
		return false
	root_ambush.tick(.50, game)
	if (game.health < hp) != revealed:
		return false
	var across := direction.cross(Vector3.UP)
	var target := player_at + across * .75
	var swing := atan2(-across.z, -across.x)
	var motion := WeaponMotion.new()
	motion.family = "sword"
	motion.start(0, swing)
	return root_ambush.try_melee(target, motion, swing, swing) and root_ambush._elapsed < 0.0


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
