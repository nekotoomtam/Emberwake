extends Node3D
## Stone courtyard with low foreground masonry and native collision.
const Art = preload("res://scripts/pixel_art.gd")
var obstacles: Array[Vector3] = []

func material(color: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = 0.92
	return m

func block(where: Vector3, size: Vector3, color: String, solid: bool = true) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color)
	node.position = where
	add_child(node)
	if solid:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.position = where
		body.add_child(collider)
		add_child(body)
	return node

func _ready() -> void:
	var env := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("#0b1520")
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color("#9caeb7")
	sky.ambient_light_energy = 0.72
	sky.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = sky
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-58, -30, 0)
	key.light_color = Color("#b4c5d6")
	key.light_energy = 0.85
	key.shadow_enabled = true
	add_child(key)
	var floor_node := block(Vector3(0, -0.22, 0), Vector3(25, 0.4, 20), "#737b7e")
	var stone := material("#879598")
	stone.albedo_texture = Art.floor_texture()
	stone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	stone.uv1_scale = Vector3(16, 13, 1)
	floor_node.material_override = stone
	# The central duelling area remains unobstructed.
	for side in [-1, 1]:
		block(Vector3(side * 12.3, 0.55, 0), Vector3(0.7, 1.2, 20), "#293a49")
		block(Vector3(0, 0.28, side * 9.7), Vector3(25, 0.65 if side == 1 else 1.2, 0.65), "#293a49")
	for x in [-8.0, 8.0]:
		for z in [-5.4, 5.4]:
			var pos := Vector3(x, 0, z)
			obstacles.append(pos)
			block(pos + Vector3(0, 0.18, 0), Vector3(1.25, 0.4, 1.25), "#273845")
			block(pos + Vector3(0, 1.0, 0), Vector3(0.7, 1.65, 0.7), "#40515b")
			block(pos + Vector3(0, 1.85, 0), Vector3(1.0, 0.22, 1.0), "#647076")
			brazier(pos + Vector3(0, 2.05, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3919
	for i in range(38):
		var edge: int = -1 if i % 2 else 1
		var pos := Vector3(rng.randf_range(-11, 11), 0, edge * rng.randf_range(7.6, 9.1))
		var chunk := block(pos + Vector3(0, 0.08, 0), Vector3(rng.randf_range(0.15, 0.6), 0.16, rng.randf_range(0.12, 0.4)), "#3e5260", false)
		chunk.rotation.y = rng.randf_range(-PI, PI)
	for x in [-4.0, 0.0, 4.0]:
		block(Vector3(x, 0.01, -7.6), Vector3(2.6, 0.05, 0.25), "#57605d", false)
		block(Vector3(x, 0.015, -7.2), Vector3(0.22, 0.055, 0.65), "#a4814e", false)
	# A central inlaid cross helps judge the player's ground position.
	block(Vector3(0, 0.008, 0), Vector3(6.6, 0.025, 0.08), "#505f65", false)
	block(Vector3(0, 0.009, 0), Vector3(0.08, 0.025, 5.2), "#505f65", false)

func brazier(where: Vector3) -> void:
	block(where, Vector3(0.45, 0.12, 0.45), "#151f2b", false)
	var fire := block(where + Vector3(0, 0.17, 0), Vector3(0.23, 0.3, 0.23), "#ffbd65", false)
	var m := material("#ffbd65")
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = Color("#ef7b3b")
	m.emission_energy_multiplier = 1.5
	fire.material_override = m
	var light := OmniLight3D.new()
	light.position = where + Vector3(0, 0.6, 0)
	light.light_color = Color("#ff9952")
	light.light_energy = 1.8
	light.omni_range = 5.5
	add_child(light)
