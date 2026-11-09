extends Node3D
## Abandoned Victorian quay. Local geometry/textures only; center stays open.
var obstacles: Array[Vector3] = []
var _wood: StandardMaterial3D
var _stone: StandardMaterial3D
var _iron: StandardMaterial3D
var _rng := RandomNumberGenerator.new()

func _mat(color: String) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(color)
	result.roughness = 0.94
	return result

func _texture(planks: bool) -> ImageTexture:
	var image := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var random := RandomNumberGenerator.new()
	random.seed = 58191 if planks else 58192
	for y in range(128):
		for x in range(128):
			var variation := random.randf_range(-0.025, 0.025)
			var seam: bool
			if planks:
				seam = y % 16 == 0 or (x + (int(y / 16) % 2) * 48) % 96 == 0
				variation += sin(float(x) * 0.22 + float(int(y / 16)) * 9.0) * 0.014
			else:
				seam = y % 16 < 2 or (x + (int(y / 16) % 2) * 12) % 24 < 2
			var base := Color(0.24, 0.255, 0.25) if planks else Color(0.29, 0.32, 0.33)
			if seam:
				base *= 0.65
			image.set_pixel(x, y, Color(base.r + variation, base.g + variation, base.b + variation))
	return ImageTexture.create_from_image(image)

func _box(at: Vector3, size: Vector3, surface: Material, solid: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = surface
	node.position = at
	add_child(node)
	if solid:
		_collider(at, size)
	return node

func _collider(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	add_child(body)

func _rod(a: Vector3, b: Vector3, radius: float, surface: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	node.mesh = mesh
	node.material_override = surface
	node.position = (a + b) * 0.5
	var direction := (b - a).normalized()
	var axis := Vector3.UP.cross(direction)
	if axis.length_squared() > 0.00001:
		node.quaternion = Quaternion(axis.normalized(), acos(clampf(Vector3.UP.dot(direction), -1, 1)))
	add_child(node)
	return node

func _ready() -> void:
	_rng.seed = 5803
	_wood = _mat("#626b67")
	_wood.albedo_texture = _texture(true)
	_wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_wood.uv1_scale = Vector3(7, 8, 1)
	_stone = _mat("#858c8b")
	_stone.albedo_texture = _texture(false)
	_stone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_stone.uv1_scale = Vector3(3, 2, 1)
	_iron = _mat("#17252a")
	_environment()
	# All traversable geometry has one flat collision plane. Surface dressing is visual.
	_box(Vector3(0, -0.22, 0), Vector3(25, 0.4, 20), _wood, true)
	_box(Vector3(0, -0.008, -7.7), Vector3(25, 0.025, 4.55), _stone)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 11.65, -0.008, 0), Vector3(1.7, 0.025, 20), _stone)
		_collider(Vector3(side * 12.5, 1, 0), Vector3(1, 3, 21))
		_collider(Vector3(0, 1, side * 10), Vector3(26, 3, 1))
		# Low, narrow quay coping leaves foreground actors visible.
		_box(Vector3(side * 12.05, 0.08, 0), Vector3(0.28, 0.2, 20), _mat("#46514f"))
		for z in [-8.4, -3.0, 3.0, 8.3]:
			_pile(Vector3(side * 11.8, 0, z), 0.85)
		for z in [-6.65, 6.65]:
			_lamp(Vector3(side * 9.8, 0, z))
		for z in [-8.4, -3.0, 3.0]:
			_rope(Vector3(side * 11.8, 0.65, z), Vector3(side * 11.8, 0.65, z + (5.4 if z == -8.4 else 6.0 if z == -3.0 else 5.3)))
		_box(Vector3(side * 11.7, -0.55, 0), Vector3(0.4, 1, 20), _mat("#202c2b"))
	# Dock boards have slender end-grain beams, kept outside the combat rectangle.
	for z in [-9.2, 8.9]:
		_box(Vector3(0, 0.012, z), Vector3(22.3, 0.045, 0.18), _mat("#333d3b"))
	for x in [-8.7, 8.7]:
		_cargo(Vector3(x, 0, -8.0))
	_water_and_boats()
	_skyline()

func _environment() -> void:
	var world := WorldEnvironment.new()
	var atmosphere := Environment.new()
	atmosphere.background_mode = Environment.BG_COLOR
	atmosphere.background_color = Color("#172b35")
	atmosphere.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.ambient_light_color = Color("#a3bac2")
	atmosphere.ambient_light_energy = 0.64
	atmosphere.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	atmosphere.fog_enabled = true
	atmosphere.fog_light_color = Color("#455e68")
	atmosphere.fog_light_energy = 0.45
	atmosphere.fog_density = 0.009
	atmosphere.fog_sky_affect = 0.6
	world.environment = atmosphere
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-62, -35, 0)
	moon.light_color = Color("#a7c6d8")
	moon.light_energy = 0.85
	moon.shadow_enabled = true
	add_child(moon)

func _pile(at: Vector3, height: float) -> void:
	var timber := _mat("#263734")
	_rod(at, at + Vector3.UP * height, 0.13, timber)
	_box(at + Vector3.UP * (height - 0.12), Vector3(0.3, 0.08, 0.3), _iron)
	_collider(at + Vector3.UP * height * 0.5, Vector3(0.3, height, 0.3))
	obstacles.append(at)

func _rope(a: Vector3, b: Vector3) -> void:
	var hemp := _mat("#5d6256")
	var previous := a
	for i in range(1, 9):
		var weight := float(i) / 8.0
		var next := a.lerp(b, weight) - Vector3.UP * sin(weight * PI) * 0.27
		_rod(previous, next, 0.025, hemp)
		previous = next

func _lamp(at: Vector3) -> void:
	obstacles.append(at)
	_collider(at + Vector3.UP * 0.8, Vector3(0.34, 1.6, 0.34))
	_box(at + Vector3.UP * 0.1, Vector3(0.48, 0.2, 0.48), _iron)
	_rod(at, at + Vector3.UP * 2.6, 0.06, _iron)
	_rod(at + Vector3(0, 2.55, 0), at + Vector3(-0.42, 2.55, 0), 0.045, _iron)
	var center := at + Vector3(-0.42, 2.24, 0)
	var glass := _mat("#ffcc80")
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.emission_enabled = true
	glass.emission = Color("#ffc876")
	_box(center, Vector3(0.27, 0.39, 0.27), glass)
	_box(center + Vector3.UP * 0.23, Vector3(0.43, 0.1, 0.43), _iron)
	_box(center - Vector3.UP * 0.23, Vector3(0.36, 0.09, 0.36), _iron)
	for dx in [-0.15, 0.15]:
		for dz in [-0.15, 0.15]:
			_rod(center + Vector3(dx, -0.2, dz), center + Vector3(dx, 0.2, dz), 0.02, _iron)
	var light := OmniLight3D.new()
	light.position = center
	light.light_color = Color("#ffb665")
	light.light_energy = 2.0
	light.omni_range = 6.0
	light.omni_attenuation = 1.5
	add_child(light)

func _cargo(at: Vector3) -> void:
	var crate := _mat("#36413b")
	_box(at + Vector3(0, 0.35, 0), Vector3(1.25, 0.7, 0.8), crate, true)
	obstacles.append(at)
	for x in [-0.47, 0.47]:
		_box(at + Vector3(x, 0.72, 0), Vector3(0.09, 0.06, 0.85), _iron)
		_box(at + Vector3(x, 0.35, 0.42), Vector3(0.09, 0.7, 0.05), _iron)

func _water_and_boats() -> void:
	var water := _mat("#152c35")
	water.roughness = 0.4
	_box(Vector3(0, -0.84, 0), Vector3(95, 0.1, 85), water)
	var glint := _mat("#28434a")
	for i in range(95):
		var x := _rng.randf_range(-28, 28)
		var z := _rng.randf_range(-20, 23)
		if absf(x) < 13.2 and absf(z) < 10.5:
			continue
		_box(Vector3(x, -0.78, z), Vector3(_rng.randf_range(0.4, 2.0), 0.008, 0.025), glint)
	for side in [-1.0, 1.0]:
		_boat(Vector3(side * 16.0, -0.6, -4), side * 0.15)
	_boat(Vector3(-6, -0.6, -15.5), 1.4)

func _boat(at: Vector3, angle: float) -> void:
	# Tapered six-sided hull, with a recessed dark deck and gunwales.
	var points: Array[Vector2] = [Vector2(-0.8,-2.5),Vector2(0,-3.3),Vector2(0.8,-2.5),Vector2(0.95,2.2),Vector2(0,3.0),Vector2(-0.95,2.2)]
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(6):
		var a := points[i]
		var b := points[(i + 1) % 6]
		for vertex in [Vector3(a.x,0.55,a.y),Vector3(b.x,0.55,b.y),Vector3(b.x*0.65,0,b.y*0.85),Vector3(a.x,0.55,a.y),Vector3(b.x*0.65,0,b.y*0.85),Vector3(a.x*0.65,0,a.y*0.85)]:
			mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	var hull := MeshInstance3D.new()
	hull.mesh = mesh
	var hull_mat := _mat("#101c21")
	hull_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	hull.material_override = hull_mat
	hull.position = at
	hull.rotation.y = angle
	add_child(hull)
	for i in range(6):
		var a := points[i]
		var b := points[(i+1)%6]
		_rod(at + Vector3(a.x,0.55,a.y).rotated(Vector3.UP,angle), at + Vector3(b.x,0.55,b.y).rotated(Vector3.UP,angle),0.07,_mat("#384441"))
	_rod(at, at + Vector3.UP * 4.5, 0.055, _iron)
	_rope(at + Vector3.UP * 4.4, at + Vector3(0,0.55,2.7).rotated(Vector3.UP,angle))

func _skyline() -> void:
	var distant := _mat("#182a30")
	var roof := _mat("#101e26")
	for i in range(10):
		var x := -25.0 + i * 5.4
		var height := _rng.randf_range(2.2, 4.5)
		var z := -23.0 - _rng.randf_range(0, 3)
		_box(Vector3(x,height*0.5-0.4,z),Vector3(4.4,height,4.5),distant)
		_box(Vector3(x,height-0.15,z+2.31),Vector3(4.55,0.16,0.18),roof)
		for column in [-1.5,0.0,1.5]:
			var window_at := Vector3(x+column,height*0.58,z+2.28)
			_box(window_at,Vector3(0.52,0.95,0.05),roof)
			_box(window_at+Vector3(0,0,0.035),Vector3(0.06,0.95,0.035),distant)
			_box(window_at+Vector3(0,0,0.04),Vector3(0.52,0.06,0.035),distant)
			if (i + int(column*2)) % 3 == 0:
				var shutter := _box(window_at+Vector3(0,0,0.08),Vector3(0.65,0.09,0.05),_mat("#39403b"))
				shutter.rotation.z = 0.4
		for edge in [-2.05,2.05]:
			_box(Vector3(x+edge,height*0.5-0.4,z+2.3),Vector3(0.12,height,0.16),roof)
		var ridge := PrismMesh.new()
		ridge.size = Vector3(5.2, 1.7, 5.0)
		var roof_node := MeshInstance3D.new()
		roof_node.mesh = ridge
		roof_node.material_override = roof
		roof_node.position = Vector3(x,height+0.35,z)
		add_child(roof_node)
		_box(Vector3(x+1.3,height+1.0,z+0.6),Vector3(0.4,1.6,0.45),roof)
	# Thin conifers make a jagged distant coastline instead of a foreground wall.
	for i in range(46):
		var x := _rng.randf_range(-38,38)
		var z := _rng.randf_range(-36,-28)
		var height := _rng.randf_range(3.5,7.5)
		var tree := MeshInstance3D.new()
		var canopy := CylinderMesh.new()
		canopy.top_radius = 0
		canopy.bottom_radius = _rng.randf_range(0.8,1.5)
		canopy.height = height
		canopy.radial_segments = 5
		tree.mesh = canopy
		tree.material_override = roof
		tree.position = Vector3(x,height*0.5-0.5,z)
		add_child(tree)

