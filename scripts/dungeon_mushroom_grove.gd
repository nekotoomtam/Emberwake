extends RefCounted
## Seeded dressing for the walkable clearing and its forest edge.
const SporePatch = preload("res://scripts/dungeon_spore_patch.gd")
const Wetland = preload("res://scripts/dungeon_wetland.gd")
const CELL := 4.6
const CAP := [
	"......sss......",
	"....sshhhss....",
	"...shhhllhhs...",
	"..shllhhphhhs..",
	".shllhphhhmhhs.",
	".shhhhhhhhmhhs.",
	"shhhphhhmmmmhhs",
	"shhhhhhmmmmmmhs",
	"shmmmmmmmmmmmhs",
	".sggggggggggs..",
	"..ssgggggsss...",
	".....sbts......",
	".....sbts......",
	"....sbtts......",
	"....sbtbs......",
	".....sss.......",
]
const PALETTES := [
	{"s":"#49352d", "h":"#b26945", "l":"#d7975d", "p":"#e7b877", "m":"#99523b", "g":"#755043", "b":"#b79a71", "t":"#ded0a0"},
	{"s":"#482c46", "h":"#b365a9", "l":"#d792ca", "p":"#f1bce2", "m":"#86538a", "g":"#684462", "b":"#a991ad", "t":"#dcc5d4"},
]
static var _material: StandardMaterial3D


static func plan(outline: PackedVector2Array, seed_: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point in outline: bounds = bounds.expand(point)
	var cells: Array[Dictionary] = []
	for y in ceili(bounds.size.y / CELL):
		for x in ceili(bounds.size.x / CELL):
			var corner := bounds.position + Vector2(x, y) * CELL
			var box := PackedVector2Array([corner, corner + Vector2(CELL, 0), corner + Vector2.ONE * CELL, corner + Vector2(0, CELL)])
			var area := 0.0
			for patch in Geometry2D.intersect_polygons(outline, box):
				area += Wetland.area(patch)
			if area < 5.0: continue
			var at := corner + Vector2(rng.randf_range(1.3, 3.3), rng.randf_range(1.3, 3.3))
			if not _inside(outline, at, 1.35): continue
			cells.append({"at": at, "area": area, "order": rng.randf()})
	cells.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.order < b.order)
	var area := Wetland.area(outline)
	var trees: Array[Vector2] = []
	var tree_area := 0.0
	var groups: Array[Vector2] = []
	var fungus_area := 0.0
	for cell in cells:
		var at: Vector2 = cell.at
		if absf(at.x) > 2.9 and absf(at.y) > 2.9:
			if absf(tree_area + cell.area - area * .20) < absf(tree_area - area * .20):
				if not trees.any(func(other: Vector2) -> bool: return other.distance_to(at) < 3.9):
					trees.append(at)
					tree_area += cell.area
		if absf(fungus_area + cell.area - area * .40) < absf(fungus_area - area * .40):
			groups.append(at)
			fungus_area += cell.area
	var poison: Array[Vector2] = []
	var target := roundi(groups.size() * .40)
	# Prefer open ground so the smoke can be seen under the canopy.
	for open_ground in [true, false]:
		for at in groups:
			if poison.size() == target: break
			if open_ground == trees.has(at) or not _inside(outline, at, SporePatch.RADIUS):
				continue
			if poison.any(func(other: Vector2) -> bool: return other.distance_to(at) < SporePatch.RADIUS * 2.0):
				continue
			poison.append(at)
	return {"trees": trees, "groups": groups, "poison": poison,
		"tree_share": tree_area / area, "fungus_share": fungus_area / area}



static func _inside(outline: PackedVector2Array, at: Vector2, margin: float) -> bool:
	for direction in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		if not Geometry2D.is_point_in_polygon(at + direction * margin, outline): return false
	return true


static func build(parent: Node3D, outline: PackedVector2Array, groups: Array[Vector2],
		poison: Array[Vector2], links: Dictionary, half: Vector2, seed_: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for at in groups:
		_group(mesh, at, rng, poison.has(at))
	var outward := -1.0 if Geometry2D.is_polygon_clockwise(outline) else 1.0
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		var middle := (a + b) * .5
		var doorway := Vector2i.ZERO
		if is_equal_approx(absf(middle.x), half.x): doorway.x = int(signf(middle.x))
		if is_equal_approx(absf(middle.y), half.y): doorway.y = int(signf(middle.y))
		if links.has(doorway): continue
		var inward := -(b - a).normalized().orthogonal() * outward
		var count := maxi(1, roundi(a.distance_to(b) / 4.5))
		for offset in count:
			var at := a.lerp(b, (offset + rng.randf_range(.24, .76)) / count)
			_group(mesh, at + inward * rng.randf_range(1.0, 1.9), rng)
			if index % 3 == 1:
				_group(mesh, at - inward * rng.randf_range(1.0, 2.6), rng)
	var node := MeshInstance3D.new()
	node.name = "MushroomGrove"
	node.mesh = mesh.commit()
	node.material_override = _sprite_material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


static func _group(mesh: SurfaceTool, at: Vector2, rng: RandomNumberGenerator, danger := false) -> void:
	var count := rng.randi_range(3, 5)
	var turn := rng.randf_range(0, TAU)
	for index in count:
		var angle := turn + TAU * index / count + rng.randf_range(-.32, .32)
		var spread := rng.randf_range(.29, .92)
		var center := at + Vector2(cos(angle), sin(angle)) * spread
		var height := rng.randf_range(.30, .55) if index > 0 else rng.randf_range(.53, .72)
		var tint := Color.WHITE.darkened(rng.randf_range(.0, .19))
		_card(mesh, center, height, tint, danger, index % 2 == 0)


static func _card(mesh: SurfaceTool, center: Vector2, height: float, tint: Color, danger: bool, flip: bool) -> void:
	var frame := .5 if danger else 0.0
	for uv: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1)]:
		var rise := height * (1.0 - uv.y)
		var point := Vector3(center.x + (uv.x - .5) * height * .94, .025 + rise * .84, center.y - rise * .54)
		var horizontal := 1.0 - uv.x if flip else uv.x
		mesh.set_color(tint)
		mesh.set_uv(Vector2(frame + (1.0 + horizontal * 15.0) / 34.0, (1.0 + uv.y * 16.0) / 18.0))
		mesh.add_vertex(point)


static func _sprite_material() -> StandardMaterial3D:
	if _material != null: return _material
	var pixels := Image.create_empty(34, 18, false, Image.FORMAT_RGBA8)
	for frame in PALETTES.size():
		for y in CAP.size():
			for x in CAP[y].length():
				var symbol: String = CAP[y][x]
				if symbol != ".": pixels.set_pixel(frame * 17 + x + 1, y + 1, Color(PALETTES[frame][symbol]))
	_material = StandardMaterial3D.new()
	_material.albedo_texture = ImageTexture.create_from_image(pixels)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_material.alpha_scissor_threshold = .5
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_material.vertex_color_use_as_albedo = true
	return _material
