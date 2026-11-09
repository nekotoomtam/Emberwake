extends "res://scripts/coast_form_detail.gd"
## Wreck Shore vegetation arranged around three traversable forest clearings.
const SoilArt = preload("res://scripts/dungeon_soil_art.gd")
const GRASS_TILE = preload("res://assets/foliage/forest-grass.png")
const WIDE := [Vector2(.25,.96), Vector2(.52,.92), Vector2(.78,.74), Vector2(.94,.45)]
const NECK := [Vector2(.18,.82), Vector2(.18,.39), Vector2(.26,.34), Vector2(.49,.75), Vector2(.73,.79), Vector2(.94,.53)]
const INNER_ARC := [Vector2(.20,.86), Vector2(.23,.44), Vector2(.44,.33), Vector2(.65,.33), Vector2(.84,.46), Vector2(.95,.35)]
const OUTER_ARC := [Vector2(.31,.96), Vector2(.55,.93), Vector2(.83,.86), Vector2(.98,.57)]
const ARCHES := [Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]

static var _surfaces: Dictionary = {}


static func outline_for(half: Vector2, door_width: float, variant: int) -> PackedVector2Array:
	var outline := PackedVector2Array()
	for quadrant in 4:
		var profile: Array = WIDE
		if variant == 1: profile = NECK
		elif variant == 2: profile = INNER_ARC if quadrant in [0, 3] else OUTER_ARC
		var flank := [Vector2(door_width * .5, half.y)]
		for point: Vector2 in profile:
			flank.append(point * half)
		flank.append(Vector2(half.x, door_width * .5))
		if quadrant % 2 != 0: flank.reverse()
		for point: Vector2 in flank:
			outline.append(point * ARCHES[quadrant])
	return outline


static func surfaces() -> Dictionary:
	if _surfaces.is_empty():
		_surfaces = {
			"soil": _soil_material(),
			"understory": material("#354637", "moss", 702),
			"moss": material("#4d6244", "moss", 703),
			"stone": material("#62685c", "plaster", 705),
			"bark": material("#484637", "wood", 706),
			"leaves": _leaf_material(),
			"forest_floor": StandardMaterial3D.new(),
		}
		_surfaces.soil.cull_mode = BaseMaterial3D.CULL_DISABLED
		_surfaces.trail = _surfaces.soil.duplicate()
		_surfaces.trail.vertex_color_use_as_albedo = true
		_surfaces.trail.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_surfaces.trail.render_priority = -6
		_surfaces.forest_floor.albedo_texture = GRASS_TILE
		_surfaces.forest_floor.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_surfaces.forest_floor.uv1_scale = Vector3(42, 38, 1)
		_surfaces.forest_floor.roughness = 1.0
	return _surfaces


static func _soil_material() -> StandardMaterial3D:
	const SIZE := 128
	var pixels := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7421
	var ochre := Color("#776648")
	var dark := Color("#66563f")
	var pale := Color("#887657")
	for y in SIZE:
		for x in SIZE:
			var u := x * TAU / SIZE
			var v := y * TAU / SIZE
			var broad := sin(u * 2.0 + cos(v * 2.0) * .9) * sin(v * 3.0 - u * 2.0)
			var fine := sin(u * 8.0 + sin(v * 6.0)) * cos(v * 7.0 + u * 4.0)
			var grain := broad * .16 + fine * .10 + rng.randf_range(-.18, .18)
			var tone := ochre.lerp(pale if grain > 0.0 else dark, absf(grain))
			pixels.set_pixel(x, y, tone)
	for index in 68:
		var x := rng.randi_range(0, SIZE - 1)
		var y := rng.randi_range(0, SIZE - 1)
		var tint := Color("#938060") if index % 4 == 0 else Color("#695c45")
		pixels.set_pixel(x, y, tint)
		pixels.set_pixel(posmod(x + 1, SIZE), y, tint.darkened(.08))
		if index % 5 == 0:
			pixels.set_pixel(x, posmod(y + 1, SIZE), tint.darkened(.12))
			pixels.set_pixel(posmod(x + 1, SIZE), posmod(y - 1, SIZE), tint.lightened(.09))
	pixels.generate_mipmaps()
	var surface := StandardMaterial3D.new()
	surface.albedo_texture = ImageTexture.create_from_image(pixels)
	surface.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	surface.uv1_scale = Vector3(.53, .53, 1.0)
	surface.roughness = .98
	return surface



static func _leaf_material() -> StandardMaterial3D:
	var surface := StandardMaterial3D.new()
	surface.albedo_texture = _dense_leaf_texture()
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	surface.alpha_scissor_threshold = .42
	surface.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	surface.vertex_color_use_as_albedo = true
	return surface


static func _dense_leaf_texture() -> ImageTexture:
	var pixels := Image.create_empty(80, 64, false, Image.FORMAT_RGBA8)
	var lobes := [
		Vector4(23, 44, 17, 13), Vector4(45, 46, 21, 13), Vector4(63, 39, 14, 13),
		Vector4(15, 31, 12, 12), Vector4(65, 27, 12, 11), Vector4(53, 31, 17, 13),
		Vector4(29, 32, 17, 14), Vector4(28, 17, 13, 11), Vector4(46, 19, 17, 13),
		Vector4(45, 10, 10, 7),
	]
	var shade := Color("#253d31")
	var green := Color("#4f6d40")
	var light := Color("#869b59")
	for index in lobes.size():
		var lobe: Vector4 = lobes[index]
		for y in range(maxi(0, floori(lobe.y - lobe.w - 2)), mini(64, ceili(lobe.y + lobe.w + 2))):
			for x in range(maxi(0, floori(lobe.x - lobe.z - 2)), mini(80, ceili(lobe.x + lobe.z + 2))):
				var point := Vector2((x - lobe.x) / lobe.z, (y - lobe.y) / lobe.w)
				var serration := .07 * sin(floorf(x / 2.0) * 2.7 + floorf(y / 2.0) * 3.1)
				var edge := point.length() + serration
				if edge > 1.0: continue
				var sun := clampf(.55 - .48 * point.y - .24 * point.x, 0.0, 1.0)
				var patch := sin(floorf(x / 3.0) * .66 + index) * cos(floorf(y / 3.0) * .83)
				var tone := green.lerp(light, .67 if sun > .78 and patch > -.30 else .28 if sun > .50 else 0.0)
				if edge > .90 and sun < .66: tone = shade
				elif sun < .38: tone = tone.lerp(shade, .46)
				pixels.set_pixel(x, y, tone)
	pixels.generate_mipmaps()
	return ImageTexture.create_from_image(pixels)



func _leaf_cluster(center: Vector3, size: Vector3, seed_: int, light: float = 1.0) -> void:
	var surface: Material = surfaces().leaves
	var key := surface.get_instance_id()
	if not groups.has(key):
		groups[key] = {"material": surface, "tool": SurfaceTool.new()}
		groups[key].tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tool: SurfaceTool = groups[key].tool
	var tint := Color("#a1ac96").lerp(Color("#e3e5bf"), .5 + .5 * sin(seed_ * 3.19))
	tint = tint.darkened(1.0 - light)
	for card in 3:
		var angle := .25 * sin(seed_ * 2.4 + card * 3.1)
		var tilt := -.79 + (card - 1) * .18
		var pose := Basis(Vector3.UP, angle) * Basis(Vector3.RIGHT, tilt)
		var width := size.x * (.54 if card == 1 else .45)
		var height := size.y * (.66 if card == 1 else .55)
		var offset := Vector3((card - 1) * size.x * .16, .16 * sin(seed_ + card), (1 - card) * .31)
		for uv in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
			var corner := Vector3((uv.x * 2.0 - 1.0) * width, (1.0 - uv.y * 2.0) * height, 0)
			tool.set_color(tint)
			tool.set_uv(uv)
			tool.add_vertex(center + offset + pose * corner)



func ground(outline: PackedVector2Array, seed_: int, links: Dictionary, half: Vector2) -> void:
	var mats := surfaces()
	var dirt := Geometry2D.offset_polygon(outline, -1.92, Geometry2D.JOIN_ROUND)
	for direction: Vector2i in links:
		var axis := Vector2(direction)
		var across := axis.orthogonal()
		var edge := axis * (half.x if direction.x != 0 else half.y)
		var trail := PackedVector2Array([
			edge - across * 1.75, edge + across * 1.75,
			edge - axis * 2.2 + across * 1.57, edge - axis * 4.0 + across * 1.9,
			edge - axis * 4.0 - across * 1.9, edge - axis * 2.0 - across * 1.55,
		])
		for index in dirt.size():
			var joined := Geometry2D.merge_polygons(dirt[index], trail)
			if joined.size() != 1: continue
			dirt[index] = joined[0]
			break

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for patch in dirt:
		for index in Geometry2D.triangulate_polygon(patch):
			var point := patch[index]
			surface.set_normal(Vector3.UP)
			surface.set_uv(point * .42)
			surface.add_vertex(Vector3(point.x, .011, point.y))
	var floor := MeshInstance3D.new()
	floor.mesh = surface.commit()
	floor.material_override = mats.soil
	add_child(floor)
	SoilArt.decorate(self, outline, seed_)



func backdrop(half: Vector2, outline: PackedVector2Array, links: Dictionary, variant: int) -> void:
	var mats := surfaces()
	var extent := half + Vector2(31, 31)
	var floor := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = extent * 2.0
	floor.mesh = mesh
	floor.position.y = .001
	floor.material_override = mats.forest_floor
	add_child(floor)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1737 + variant
	const SPACING := 3.55
	var count_x := ceili(extent.x / SPACING)
	var count_z := ceili(extent.y / SPACING)
	for row in range(-count_z, count_z + 1):
		for column in range(-count_x, count_x + 1):
			var offset := .5 if posmod(row, 2) == 0 else 0.0
			var point := Vector2((column + offset) * SPACING, row * SPACING)
			point += Vector2(rng.randf_range(-.77, .77), rng.randf_range(-.77, .77))
			if Geometry2D.is_point_in_polygon(point, outline): continue
			var distance := _distance_to_edge(point, outline)
			if distance < 3.1 or _keeps_passage_clear(point, half, links): continue

			var depth := clampf(distance / 21.0, 0.0, 1.0)
			var at := Vector3(point.x, 0, point.y)
			var seed_ := rng.randi_range(1, 16384)
			var height := rng.randf_range(2.0, 4.5)
			var spread := rng.randf_range(3.9, 5.3)
			var light := lerpf(.86, .51, depth) * rng.randf_range(.87, 1.04)
			if distance < 9.0 and seed_ % 3 == 0:
				tube([at, at + Vector3(.10, height * .60, -.11), at + Vector3(-.16, height, .15)],
					.19, mats.bark, .30)
			_leaf_cluster(at + Vector3.UP * height, Vector3(spread, spread * .62, spread), seed_, light)
			if distance < 10.0:
				var low := at + Vector3(rng.randf_range(-1.7, 1.7), .62, rng.randf_range(-1.3, 1.3))
				_leaf_cluster(low, Vector3(3.15, 1.45, 2.8), seed_ + 31, light * .89)
				if seed_ % 5 == 0:
					boulder(at + Vector3(.46, .28, .27), Vector3(1.36, .67, 1.12), mats.moss, seed_)


func _distance_to_edge(point: Vector2, outline: PackedVector2Array) -> float:
	var nearest := INF
	for index in outline.size():
		var edge := Geometry2D.get_closest_point_to_segment(point, outline[index], outline[(index + 1) % outline.size()])
		nearest = minf(nearest, point.distance_squared_to(edge))
	return sqrt(nearest)


func _keeps_passage_clear(point: Vector2, half: Vector2, links: Dictionary) -> bool:
	for link: Vector2i in links:
		var axis := Vector2(link)
		var forward := point.dot(axis)
		var edge := half.x if link.x != 0 else half.y
		if forward > edge - .5 and forward < edge + 8.0 and absf(point.cross(axis)) < 4.45:
			return true
	return false



func scout_bush(edge: Vector3, axis: Vector3, across: Vector3) -> void:
	var seed_ := 7920 + int(axis.x) * 29 + int(axis.z) * 61
	for side in [-1.0, 1.0]:
		var flank: Vector3 = edge + axis * .35 + across * side * 1.54
		var side_seed := seed_ + int(side) * 11
		_leaf_cluster(flank + Vector3.UP * 1.02, Vector3(2.60, 1.78, 2.0), side_seed, .88)
		_leaf_cluster(flank + across * side * .21 + axis * .42 + Vector3.UP * 1.70,
			Vector3(2.16, 1.63, 1.9), side_seed + 1)
		_leaf_cluster(flank + across * side * .22 - axis * .25 + Vector3.UP * .53,
			Vector3(2.45, 1.22, 1.8), side_seed + 2, .78)
		if axis.x != 0:
			_leaf_cluster(flank - across * side * .47 + axis * .25 + Vector3.UP * 1.14,
				Vector3(1.93, 1.50, 1.7), side_seed + 3, .86)



func passage(parent: Node3D, direction: Vector2i, edge: Vector3, width: float, length: float) -> void:
	var mats := surfaces()
	var axis := Vector3(direction.x, 0, direction.y)
	var across := Vector3(-axis.z, 0, axis.x)
	var bend := 1.0 if direction.x + direction.y > 0 else -1.0
	var stations := [
		Vector3(-1.55, 0, width * .54), Vector3(-.42, .04, width * .51),
		Vector3(length * .34, -.09, width * .43), Vector3(length * .69, .12, width * .46),
		Vector3(length, .20, width * .34), Vector3(length + .86, .49, width * .27),
		Vector3(length + 1.83, .93, width * .18), Vector3(length + 2.48, 1.19, .12),
	]
	var points: Array[Vector3] = []
	var tints: Array[Color] = []
	const ACROSS := [-1.0, -.55, .55, 1.0]
	for row in stations.size():
		var station: Vector3 = stations[row]
		var center := edge + axis * station.x + across * station.y * bend + Vector3.UP * .012
		var tint := Color.WHITE.lerp(Color("#596448"), smoothstep(.3, length + 2.2, station.x))
		for fraction: float in ACROSS:
			points.append(center + across * station.z * fraction)
			tint.a = 0.0 if absf(fraction) == 1.0 or row == 0 or row == stations.size() - 1 else 1.0
			tints.append(tint)

	# Draw the trail below the painted moss so the ground detail crosses its edges.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(stations.size() - 1):
		for column in range(ACROSS.size() - 1):
			var top := row * ACROSS.size() + column
			var bottom := top + ACROSS.size()
			for index in [top, bottom, top + 1, top + 1, bottom, bottom + 1]:
				var vertex := points[index]
				surface.set_color(tints[index])
				surface.set_normal(Vector3.UP)
				surface.set_uv(Vector2(vertex.x, vertex.z) * .42)
				surface.add_vertex(vertex)
	var path := MeshInstance3D.new()
	path.name = "ForestTrail_%d_%d" % [direction.x, direction.y]
	path.mesh = surface.commit()
	path.material_override = mats.trail
	parent.add_child(path)

	for side in [-1.0, 1.0]:
		for index in 7:
			var depth: float = .2 + index * .76
			var offset: float = width * (.55 - .036 * index) + .11 * sin(index * 2.1 + side)
			var at: Vector3 = edge + axis * depth + across * side * offset + Vector3.UP * .029
			var seed_ := 1210 + direction.x * 29 + direction.y * 73 + index + int(side) * 19
			patch(at, Vector2(.34, .25), mats.moss, seed_)
			if index % 2 == 0:
				boulder(at + across * side * .23, Vector3(.38, .27, .32), mats.stone, seed_)

	var end := edge + axis * (length + 2.58) + across * bend * 1.2
	_leaf_cluster(end + Vector3.UP * .77, Vector3(3.10, 1.55, 2.4), 519 + direction.x + direction.y * 8, .66)



func thicket(a: Vector3, b: Vector3, seed_: int) -> void:
	var mats := surfaces()
	var along := (b - a).normalized()
	var out := Vector3(along.z, 0, -along.x)
	var length := a.distance_to(b)
	var clumps := maxi(1, ceili(length / 2.0))
	for index in clumps:
		var variation := .5 + .5 * sin(seed_ * 1.7 + index * 3.1)
		var at := a.lerp(b, (index + .5) / clumps) + out * (.56 + variation * .40)
		_leaf_cluster(at + Vector3.UP * (.64 + variation * .24),
			Vector3(2.9, 1.30 + variation * .48, 2.3), seed_ + index)
		_leaf_cluster(at + out * 1.26 + Vector3.UP * (.83 + variation * .34),
			Vector3(3.2, 1.46 + variation * .48, 2.7), seed_ + index + 70)
		if (index + seed_) % 3 != 1:
			boulder(at - out * .32 + Vector3.UP * .26, Vector3(1.1, .8, 1.0), mats.stone, seed_ + index + 500)
		if (index + seed_) % 3 == 0:
			tree(at + out * 1.12, 2.9 + variation * 1.4, seed_ + index, mats.bark,
				mats.leaves, false, _leaf_cluster)
		if (index + seed_) % 4 == 1:
			tree(at + out * 2.85, 3.9 + variation * 1.3, seed_ + index + 203, mats.bark,
				mats.leaves, false, _leaf_cluster)


func grove_tree(at: Vector3, seed_: int) -> void:
	var mats := surfaces()
	var height := 2.65 + .95 * (.5 + .5 * sin(seed_ * .031))
	tree(at, height, seed_, mats.bark, mats.leaves, false, _leaf_cluster)


func cover(at: Vector3, variant: int, index: int) -> void:
	var mats := surfaces()
	var seed_ := 2840 + variant * 50 + index
	if index == 1 or index == 3:
		tree(at, 3.6 if index == 1 else 3.15, seed_, mats.bark, mats.leaves, false, _leaf_cluster)
		boulder(at + Vector3(.37, .30, -.25), Vector3(1.12, .65, 1.06), mats.moss, seed_)
	else:
		boulder(at + Vector3.UP * .44, Vector3(1.86, 1.26, 1.63), mats.stone, seed_)
		boulder(at + Vector3(.40, .68, -.22), Vector3(1.03, .64, .78), mats.moss, seed_ + 2)
