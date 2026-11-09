extends RefCounted
## Painted pixels at different scales. Only their composition is randomized per room.
const Stamp = preload("res://scripts/dungeon_floor_stamp.gd")
const MOSS_PATCH = preload("res://assets/foliage/forest-moss-patch.png")
const KINDS := ["shade", "worn", "green_floor", "green_floor_light", "moss", "leaves", "gravel", "twigs"]
const SHADE := [Vector4(25, 32, 19, 15), Vector4(44, 25, 24, 16), Vector4(68, 34, 19, 15), Vector4(54, 47, 18, 13)]
const WORN := [Vector4(25, 40, 19, 11), Vector4(46, 36, 28, 13), Vector4(67, 29, 20, 13), Vector4(55, 25, 14, 10)]
const MOSS := [Vector4(17, 39, 9, 7), Vector4(33, 32, 17, 12), Vector4(50, 29, 14, 10), Vector4(63, 38, 13, 10), Vector4(79, 34, 7, 6)]
const LEAVES := [Vector3i(13, 37, 4), Vector3i(24, 30, 4), Vector3i(33, 38, 6), Vector3i(43, 27, 4), Vector3i(47, 41, 5), Vector3i(57, 30, 4), Vector3i(61, 44, 5), Vector3i(73, 38, 3), Vector3i(81, 43, 3)]
const GRAVEL := [Vector3i(15, 32, 3), Vector3i(27, 42, 4), Vector3i(35, 28, 6), Vector3i(47, 39, 5), Vector3i(54, 35, 3), Vector3i(63, 44, 5), Vector3i(74, 29, 4), Vector3i(81, 36, 3)]

static var _materials: Dictionary = {}


static func decorate(parent: Node3D, outline: PackedVector2Array, seed_: int) -> void:
	var detail := Node3D.new()
	detail.name = "SoilDetails"
	parent.add_child(detail)
	var builders: Dictionary = {}
	var occupied := {}
	for kind: String in KINDS:
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		builders[kind] = builder
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_

	for index in 11:
		var point := _margin_point(outline, rng, rng.randf_range(.67, .91))
		var extent := rng.randf_range(5.4, 9.6)
		_add(builders, occupied, outline, "shade", point, Vector2(extent, extent * .68), rng.randf_range(-PI, PI))

	for index in 6:
		var point := _margin_point(outline, rng, rng.randf_range(.16, .59))
		var extent := rng.randf_range(4.8, 8.4)
		_add(builders, occupied, outline, "worn", point, Vector2(extent, extent * .51), rng.randf_range(-PI, PI))

	_greens(builders, occupied, outline, rng)

	# Detail gathers in groups around the forest edge. The middle stays lower contrast.
	var detail_kinds := ["moss", "leaves", "gravel", "twigs"]
	for index in 24:
		var depth := rng.randf_range(.29, .51) if index >= 18 else rng.randf_range(.53, .94)
		var point := _margin_point(outline, rng, depth)
		var main: String = detail_kinds[index % detail_kinds.size()]
		var other: String = detail_kinds[(index + rng.randi_range(1, 3)) % detail_kinds.size()]
		var width := rng.randf_range(1.8, 3.2) if index >= 18 else rng.randf_range(2.3, 4.6)
		_add(builders, occupied, outline, main, point, Vector2(width, width * .67), rng.randf_range(-PI, PI))
		var offset := Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.3, 1.3))
		_add(builders, occupied, outline, other, point + offset, Vector2(width * .75, width * .48), rng.randf_range(-PI, PI))

	for kind: String in KINDS:
		if not occupied.has(kind): continue
		var node := MeshInstance3D.new()
		node.name = "Soil_" + kind
		node.mesh = builders[kind].commit()
		node.material_override = _material(kind)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		detail.add_child(node)


static func _greens(builders: Dictionary, occupied: Dictionary, outline: PackedVector2Array, rng: RandomNumberGenerator) -> void:
	const BANK_PATCHES := 19
	for index in BANK_PATCHES:
		var edge_index := floori((index + rng.randf()) * outline.size() / BANK_PATCHES)
		var a := outline[edge_index]
		var b := outline[(edge_index + 1) % outline.size()]
		var point := a.lerp(b, rng.randf_range(.24, .76)) * rng.randf_range(.83, 1.02)
		var size := Vector2(rng.randf_range(12.5, 17.8), rng.randf_range(8.6, 13.2))
		var angle := (b - a).angle() + rng.randf_range(-.68, .68)
		var kind := "green_floor" if index % 3 != 0 else "green_floor_light"
		_add(builders, occupied, PackedVector2Array(), kind, point, size, angle)

	for index in 11:
		var point := _margin_point(outline, rng, rng.randf_range(.31, .73))
		var size := Vector2(rng.randf_range(7.4, 11.8), rng.randf_range(6.6, 9.7))
		_add(builders, occupied, outline, "green_floor_light", point, size, rng.randf_range(-PI, PI))


static func _margin_point(outline: PackedVector2Array, rng: RandomNumberGenerator, depth: float) -> Vector2:
	var index := rng.randi_range(0, outline.size() - 1)
	return outline[index].lerp(outline[(index + 1) % outline.size()], rng.randf()) * depth


static func _add(builders: Dictionary, occupied: Dictionary, outline: PackedVector2Array, kind: String,
		at: Vector2, size: Vector2, angle: float) -> void:
	var height := .013 + KINDS.find(kind) * .0015
	if Stamp.append(builders[kind], outline, at, size, angle, height): occupied[kind] = true


static func _material(kind: String) -> StandardMaterial3D:
	if _materials.has(kind): return _materials[kind]
	var surface := StandardMaterial3D.new()
	if kind in ["green_floor", "green_floor_light"]:
		surface.albedo_texture = MOSS_PATCH
		surface.albedo_color = Color(1.0, 1.0, .92, .96) if kind == "green_floor" else Color(1.0, .99, .88, .79)
	else:
		surface.albedo_texture = _painted_texture(kind)
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surface.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	surface.roughness = .97
	surface.render_priority = KINDS.find(kind) - 5
	_materials[kind] = surface
	return surface


static func _painted_texture(kind: String) -> ImageTexture:
	var image := Image.create_empty(96, 72, false, Image.FORMAT_RGBA8)
	match kind:
		"shade": _paint_patch(image, SHADE, Color("#5a4d36"), .37)
		"worn": _paint_patch(image, WORN, Color("#a08a61"), .33)
		"moss": _paint_patch(image, MOSS, Color("#586144"), .67)
		"leaves": _paint_scatter(image, LEAVES, Color("#ad8952"), Color("#7e6040"), true)
		"gravel": _paint_scatter(image, GRAVEL, Color("#ad9973"), Color("#827458"), false)
		"twigs": _paint_twigs(image)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


static func _paint_patch(image: Image, forms: Array, color: Color, opacity: float) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var nearest := INF
			for form: Vector4 in forms:
				var offset := Vector2((x - form.x) / form.z, (y - form.y) / form.w)
				nearest = minf(nearest, offset.length())
			var texture := sin(x * .64 + y * .37) * cos(y * .71 - x * .29)
			var edge := nearest + texture * .073
			if edge >= 1.0: continue
			var shade := color.lightened(maxf(0.0, texture) * .11)
			shade.a = opacity * roundf((1.0 - smoothstep(.27, 1.0, edge)) * 8.0) / 8.0
			image.set_pixel(x, y, shade)


static func _paint_scatter(image: Image, pieces: Array, lit: Color, shade: Color, leaves: bool) -> void:
	for index in pieces.size():
		var piece: Vector3i = pieces[index]
		for y in range(-piece.z, piece.z + 1):
			for x in range(-piece.z, piece.z + 1):
				var lean := .6 if leaves and index % 2 == 0 else -.43
				var metric := absf(x + y * lean) * (.71 if leaves else 1.0) + absf(y)
				if metric > piece.z: continue
				var tint := lit if y < 0 and metric < piece.z * .82 else shade
				tint.a = .66 if metric < piece.z * .9 else .41
				image.set_pixel(piece.x + x, piece.y + y, tint)


static func _paint_twigs(image: Image) -> void:
	for branch: Vector4i in [Vector4i(17, 39, 23, -6), Vector4i(46, 29, 18, 7), Vector4i(61, 46, 17, -4)]:
		for x in branch.z:
			var y := branch.y + roundi(float(x) * branch.w / branch.z)
			image.set_pixel(branch.x + x, y, Color("#8e735188"))
			if x > 2 and x < branch.z - 2:
				image.set_pixel(branch.x + x, y + 1, Color("#5c4e3c73"))
			if x == branch.z / 2:
				for twig in 5: image.set_pixel(branch.x + x + twig, y - twig, Color("#836b4f80"))
