extends Node3D
## Original procedural shore: sea is +Z, derelict Victorian waterfront is -Z.
## Flat collision and sampled shore share geometry; raised scenery is off routes.
const boundary := Rect2(-24, -12, 48, 25)
var spawn_point := Vector3(-20, .03, 3)
var captain_point := Vector3(18, .03, 2)
var camera_limits := Vector2(23, 11)
var obstacles: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()
var _foam: StandardMaterial3D
var _time := 0.0
var _wood: StandardMaterial3D
var _stone: StandardMaterial3D
var _iron: StandardMaterial3D

static func shoreline(x: float) -> float:
	return 8.9 + 1.08 * sin(x * .24 + .5) + .67 * sin(x * .51 - .8) + .25 * cos(x * .91)

func clamp_point(p: Vector3, margin: float = .45) -> Vector3:
	var x := clampf(p.x, -23, 23)
	return Vector3(x, p.y, clampf(p.z, -11.5, shoreline(x) - maxf(margin, 0)))

func is_walkable(p: Vector3, margin: float = .45) -> bool:
	return absf(p.x) <= 23.00001 and p.z >= -11.50001 and p.z <= shoreline(p.x) - maxf(margin, 0) + .00001

func _ready() -> void:
	_rng.seed = 621101
	_wood = _material(Color("#5b5546"))
	_wood.albedo_texture = _pixels(Color("#625f51"), 2)
	_stone = _material(Color("#888b80"))
	_stone.albedo_texture = _pixels(Color("#929082"), 1)
	_iron = _material(Color("#293b3c"))
	_environment()
	_land_and_sea()
	_shore_boundary()
	_dressing()
	_waterfront()

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = .96
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat

func _pixels(base: Color, kind: int = 0) -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var random := RandomNumberGenerator.new()
	random.seed = 6200 + kind
	for y in range(64):
		for x in range(64):
			var shade := random.randf_range(-.025, .025)
			if kind == 0:
				shade += .012 * sin(float(y) * .57 + sin(float(x) * .23))
			elif kind == 1 and (y % 12 < 1 or (x + int(y / 12) * 9) % 23 < 1):
				shade -= .14
			elif kind == 2:
				shade += sin(float(y) * .72) * .045
				if y % 13 == 0: shade -= .12
			image.set_pixel(x, y, Color(clampf(base.r + shade, 0, 1), clampf(base.g + shade, 0, 1), clampf(base.b + shade, 0, 1)))
	return ImageTexture.create_from_image(image)

func _sand(color: String) -> StandardMaterial3D:
	var mat := _material(Color.WHITE)
	mat.albedo_texture = _pixels(Color(color))
	return mat

func _strip(label: String, near_offset: float, far_offset: float, height: float, mat: Material, inland: bool = false, floor_collision: bool = false) -> void:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var normals := PackedVector3Array()
	for i in range(256):
		var xa := -40.0 + i * .3125
		var xb := xa + .3125
		var za := -36.0 if inland else shoreline(xa) + near_offset
		var zb := -36.0 if inland else shoreline(xb) + near_offset
		var a := Vector3(xa, height, za)
		var b := Vector3(xb, height, zb)
		var c := Vector3(xb, height, shoreline(xb) + far_offset)
		var d := Vector3(xa, height, shoreline(xa) + far_offset)
		for point in [a, b, c, a, c, d]:
			vertices.append(point)
			uv.append(Vector2(point.x, point.z) * .32)
			normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = mat
	add_child(node)
	if floor_collision:
		var body := StaticBody3D.new()
		body.name = "FlatBeachFloor"
		body.collision_layer = 1
		body.collision_mask = 0
		var holder := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		# Reversed triangle winding gives the physics surface its upward front face.
		var faces := PackedVector3Array()
		for j in range(0, vertices.size(), 3):
			faces.append(vertices[j])
			faces.append(vertices[j + 2])
			faces.append(vertices[j + 1])
		shape.set_faces(faces)
		shape.backface_collision = true
		holder.shape = shape
		body.add_child(holder)
		add_child(body)

func _land_and_sea() -> void:
	# One continuous y=0 collision surface, with thin visual pigment bands above.
	var sand := _sand("#8c897c")
	sand.cull_mode = BaseMaterial3D.CULL_DISABLED
	_strip("IrregularSand", 0, 0, 0, sand, true, true)
	var damp := _sand("#747f78")
	damp.cull_mode = BaseMaterial3D.CULL_DISABLED
	_strip("DampTideBand", -3.0, 0, .002, damp)
	var wet := _sand("#657e79")
	wet.cull_mode = BaseMaterial3D.CULL_DISABLED
	wet.roughness = .7
	_strip("WetSand", -1.15, 0, .004, wet)
	var shallows := _sand("#3e686c")
	shallows.cull_mode = BaseMaterial3D.CULL_DISABLED
	shallows.roughness = .46
	_strip("ShallowSea", 0, 3.1, -.025, shallows)
	var sea := _sand("#244a58")
	sea.cull_mode = BaseMaterial3D.CULL_DISABLED
	sea.roughness = .4
	_strip("DeepSea", 3.1, 45, -.045, sea)
	_foam = _material(Color("#a4bdb1"))
	_foam.cull_mode = BaseMaterial3D.CULL_DISABLED
	_strip("SurfLace", .12, .27, -.003, _foam)
	var backwash := _material(Color("#668e8d"))
	backwash.cull_mode = BaseMaterial3D.CULL_DISABLED
	_strip("OuterSurf", 1.1, 1.16, -.006, backwash)
	# Broken horizontal glints retain the pixel character instead of a glossy ocean.
	var glint := _material(Color("#4c747a"))
	for i in range(110):
		var x := _rng.randf_range(-36, 36)
		var z := shoreline(x) + _rng.randf_range(1.5, 23)
		_box(Vector3(x, -.018, z), Vector3(_rng.randf_range(.18, 1.6), .009, .035), glint)

func _shore_boundary() -> void:
	# Fine segments follow the actual curved land. Their inner faces never reach
	# the default clamp band; this also blocks enemies and physical projectiles.
	for i in range(192):
		var x := -24.0 + i * .25
		var a := Vector3(x, 1, shoreline(x))
		var b := Vector3(x + .25, 1, shoreline(x + .25))
		var body := _collider((a + b) * .5 + Vector3(0, 0, .09), Vector3(a.distance_to(b) + .025, 3, .12), "ShoreBarrier")
		body.rotation.y = -atan2(b.z - a.z, b.x - a.x)
	_collider(Vector3(-24, 1, -1), Vector3(.2, 3, 27), "WestBoundary")
	_collider(Vector3(24, 1, -1), Vector3(.2, 3, 27), "EastBoundary")
	_collider(Vector3(0, 1, -12.1), Vector3(48, 3, .2), "InlandBoundary")

func _box(at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	add_child(node)
	return node

func _collider(at: Vector3, size: Vector3, label: String = "SceneryCollider") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 8 if label == "ShoreBarrier" or label.ends_with("Boundary") else 1
	body.collision_mask = 0
	body.position = at
	var holder := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	holder.shape = shape
	body.add_child(holder)
	add_child(body)
	return body

func _rod(a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.1
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 6
	node.mesh = mesh
	node.material_override = mat
	node.position = (a + b) * .5
	var direction := (b - a).normalized()
	if absf(direction.dot(Vector3.UP)) < .999:
		node.quaternion = Quaternion(Vector3.UP, direction)
	add_child(node)

func _rock(at: Vector3, size: Vector3, mat: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 7
	mesh.rings = 3
	node.mesh = mesh
	node.position = at
	node.scale = size
	node.rotation.y = _rng.randf_range(-PI, PI)
	node.material_override = mat
	add_child(node)

func _dressing() -> void:
	var basalt := _material(Color("#465b5b"))
	var dune := _sand("#8b9078")
	# All height remains beyond the traversal boundaries. Foreground silhouettes
	# stay low, leaving the actors and their tell rings legible.
	for x in [-29.0, -25.5, 25.8, 29.0]:
		for z in [-7.0, -1.0, 4.0]:
			_rock(Vector3(x, -.15, z), Vector3(3.9, 1.3, 3.1), dune)
	for i in range(26):
		var x := _rng.randf_range(-29, 29)
		var z := shoreline(x) + _rng.randf_range(.9, 2.5)
		var size := _rng.randf_range(.25, .8)
		_rock(Vector3(x, .04, z), Vector3(size * 1.7, size * .65, size), basalt)
	# Thin shell flecks and tide debris are visual-only, below ankle height.
	var shell := _material(Color("#bbc1a7"))
	for i in range(86):
		var x := _rng.randf_range(-23, 23)
		var z := shoreline(x) - _rng.randf_range(1.4, 2.5)
		_box(Vector3(x, .015, z), Vector3(.06, .02, .04), shell)
	for x in [-20.0, -10.0, 4.0, 21.0]:
		var z := shoreline(x) + .65
		var stick := _box(Vector3(x, .12, z), Vector3(2.2, .13, .22), _wood)
		stick.rotation.y = x * .12
		_rod(Vector3(x, .17, z), Vector3(x + .5, .35, z + .45), .045, _wood)
	_wreck(Vector3(-23.4, .03, 5.0), -.6)
	_wreck(Vector3(25.8, -.01, 7.6), .8)
	for i in range(35):
		var x := _rng.randf_range(-30, 30)
		var z := _rng.randf_range(-16.2, -13.3)
		_rock(Vector3(x, -.23, z), Vector3(_rng.randf_range(1.8, 3.7), .8, 1.5), dune)
		for j in range(3):
			_rod(Vector3(x + j * .12, .15, z), Vector3(x + j * .12 + .18, .7 + j * .08, z), .025, _material(Color("#626e58")))

func _wreck(at: Vector3, angle: float) -> void:
	# Skeleton of a clinker-built fishing skiff, open enough to see the sand.
	for side in [-1.0, 1.0]:
		var last := at + Vector3(0, .14, -2.1).rotated(Vector3.UP, angle)
		for i in range(1, 9):
			var t := float(i) / 8
			var point := at + Vector3(sin(t * PI) * .75 * side, .2 + sin(t * PI) * .32, -2.1 + t * 4.2).rotated(Vector3.UP, angle)
			_rod(last, point, .07, _wood)
			last = point
	for i in range(1, 7):
		var t := float(i) / 8
		var z := -2.1 + 4.2 * t
		var width := sin(t * PI) * .74
		var middle := at + Vector3(0, .09, z).rotated(Vector3.UP, angle)
		for side in [-1.0, 1.0]:
			_rod(middle, at + Vector3(side * width, .47, z).rotated(Vector3.UP, angle), .045, _wood)
	_rod(at + Vector3(0, .1, -2.1).rotated(Vector3.UP, angle), at + Vector3(0, .1, 2.1).rotated(Vector3.UP, angle), .09, _wood)

func _waterfront() -> void:
	var shadow := _material(Color("#263d43"))
	var brick := _material(Color("#606e69"))
	var roof := _material(Color("#344b50"))
	# Ruined facades: openings are real gaps between piers and lintels.
	for index in range(4):
		var x := -22.0 + index * 13.4
		var z := -18.2 - float(index % 2) * 1.6
		var height := 3.6 + float(index % 3) * .6
		for dx in [-3.4, -1.15, 1.15, 3.4]:
			_box(Vector3(x + dx, height * .5, z), Vector3(.48, height, .65), _stone)
		_box(Vector3(x, .4, z), Vector3(7.3, .8, .7), brick)
		_box(Vector3(x, height - .35, z), Vector3(7.4, .48, .8), _stone)
		for dx in [-2.25, 0.0, 2.25]:
			_box(Vector3(x + dx, 1.8, z - .18), Vector3(1.7, 2.1, .15), shadow)
			_box(Vector3(x + dx, 1.8, z + .24), Vector3(.07, 2.1, .08), _wood)
			_box(Vector3(x + dx, 2.1, z + .25), Vector3(1.7, .07, .08), _wood)
			var plank := _box(Vector3(x + dx, 1.3, z + .35), Vector3(1.9, .15, .1), _wood)
			plank.rotation.z = .2 if index % 2 else -.15
		# Distinct broken roofline, slanted rafters, chimney pots and a gable.
		_rod(Vector3(x - 3.5, height, z), Vector3(x, height + 2.0, z), .13, roof)
		_rod(Vector3(x, height + 2.0, z), Vector3(x + 2.7, height + .4, z), .13, roof)
		_box(Vector3(x - 2.2, height + 1, z - 1.1), Vector3(.8, 2.6, .75), brick)
		for dx in [-2.4, -2.0]:
			_box(Vector3(x + dx, height + 2.5, z - 1.1), Vector3(.19, .48, .23), roof)
		_box(Vector3(x + 3.4, 1.1, z - 2.0), Vector3(.55, 2.2, 4.0), brick)
		for i in range(6):
			var rubble := Vector3(x + _rng.randf_range(-4, 4), .17, z + _rng.randf_range(.9, 2.3))
			_box(rubble, Vector3(.65, .35, .45), brick).rotation.y = _rng.randf_range(-1, 1)
	# Sparse wind-bent conifers beyond the ruins, no wall of foreground trunks.
	for i in range(19):
		var x := _rng.randf_range(-40, 40)
		var z := _rng.randf_range(-29, -23)
		var height := _rng.randf_range(4.3, 7.2)
		_rod(Vector3(x, 0, z), Vector3(x + .25, height, z), .1, shadow)
		for j in range(3):
			var node := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0
			cone.bottom_radius = (1.55 - j * .28) * height / 6.0
			cone.height = height * .46
			cone.radial_segments = 5
			node.mesh = cone
			node.material_override = shadow
			node.position = Vector3(x + .13 * j, height * (.42 + j * .17), z)
			add_child(node)
	# Two surviving iron promenade lamps give small warm points inland.
	for x in [-16.0, 13.0]:
		var at := Vector3(x, 0, -13.8)
		_rod(at, at + Vector3.UP * 3.3, .055, _iron)
		var glass := _material(Color("#d7ad72"))
		glass.emission_enabled = true
		glass.emission = Color("#a36e37")
		_box(at + Vector3.UP * 3.0, Vector3(.3, .45, .3), glass)
		_box(at + Vector3.UP * 3.29, Vector3(.46, .11, .46), _iron)

func _environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#304f5c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#bbcdca")
	env.ambient_light_energy = .52
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("#526c72")
	env.fog_light_energy = .5
	env.fog_density = .006
	world.environment = env
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-62, -28, 0)
	moon.light_color = Color("#c7d8db")
	moon.light_energy = .68
	moon.shadow_enabled = true
	add_child(moon)

func tick(delta: float) -> void:
	_time += delta
	if _foam != null:
		_foam.albedo_color = Color("#a4bdb1") * (.94 + sin(_time * 1.3) * .06)
