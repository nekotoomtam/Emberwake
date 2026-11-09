extends Node3D
var particles: Array[Dictionary] = []
var trails: Array[Dictionary] = []

func tint(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	return material

func sector(origin: Vector3, radius: float, from_angle: float, to_angle: float, color: Color, inner: float = 0.0, lifetime: float = 0.12) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(16):
		var a: float = lerpf(from_angle, to_angle, i / 16.0)
		var b: float = lerpf(from_angle, to_angle, (i + 1) / 16.0)
		var pa := Vector3(cos(a), 0, sin(a))
		var pb := Vector3(cos(b), 0, sin(b))
		for v in [pa * inner, pa * radius, pb * radius, pa * inner, pb * radius, pb * inner]:
			mesh.surface_add_vertex(v)
	mesh.surface_end()
	instance.mesh = mesh
	instance.material_override = tint(color)
	instance.position = origin
	add_child(instance)
	trails.append({"node": instance, "life": lifetime, "total": lifetime, "color": color})
	return instance

func ring(where: Vector3, radius: float, color: Color, lifetime: float = 0.2) -> void:
	sector(where + Vector3(0, 0.035, 0), radius, 0, TAU, color, radius - 0.05, lifetime)

func blade_ribbon(origin: Vector3, angle: float, radius: float, length: float, from_pitch: float, to_pitch: float, from_height: float, to_height: float, color: Color, lifetime: float) -> void:
	var forward := Vector3(cos(angle), 0, sin(angle))
	var instance := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(12):
		var a: float = i / 12.0
		var b: float = (i + 1) / 12.0
		var pa: float = lerpf(from_pitch, to_pitch, a)
		var pb: float = lerpf(from_pitch, to_pitch, b)
		var ga := forward * radius + Vector3.UP * lerpf(from_height, to_height, a)
		var gb := forward * radius + Vector3.UP * lerpf(from_height, to_height, b)
		var va := (forward * cos(pa) + Vector3.UP * sin(pa)) * length
		var vb := (forward * cos(pb) + Vector3.UP * sin(pb)) * length
		for point in [ga + va * 0.45, ga + va, gb + vb, ga + va * 0.45, gb + vb, gb + vb * 0.45]:
			mesh.surface_add_vertex(point)
	mesh.surface_end()
	instance.mesh = mesh
	instance.position = origin
	instance.material_override = tint(color)
	add_child(instance)
	trails.append({"node": instance, "life": lifetime, "total": lifetime, "color": color})

func lane(origin: Vector3, angle: float, length: float, width: float, color: Color, lifetime: float) -> void:
	var instance := MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	var forward := Vector3(cos(angle), 0, sin(angle))
	var side := Vector3(-forward.z, 0, forward.x) * width * 0.5
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [-side, side, forward * length + side, -side, forward * length + side, forward * length - side]:
		mesh.surface_add_vertex(point)
	mesh.surface_end()
	instance.mesh = mesh
	instance.position = origin + Vector3(0, 0.036, 0)
	instance.material_override = tint(color)
	add_child(instance)
	trails.append({"node": instance, "life": lifetime, "total": lifetime, "color": color})

func burst(where: Vector3, color: Color, count: int = 10) -> void:
	for i in range(count):
		var piece := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * randf_range(0.035, 0.09)
		piece.mesh = mesh
		piece.material_override = tint(color)
		piece.position = where
		add_child(piece)
		particles.append({"node": piece, "velocity": Vector3(randf_range(-2.5, 2.5), randf_range(1.0, 3.5), randf_range(-2.5, 2.5)), "life": 0.4, "total": 0.4})

func number(where: Vector3, text: String, heavy: bool = false) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 46 if heavy else 34
	label.pixel_size = 0.005
	label.modulate = Color("#ffcf78") if heavy else Color("#fff6d4")
	label.outline_size = 8
	label.position = where
	label.no_depth_test = true
	add_child(label)
	particles.append({"node": label, "velocity": Vector3(randf_range(-0.3, 0.3), 1.1, 0), "life": 0.65, "total": 0.65})

func tick(delta: float) -> void:
	for entry in particles.duplicate():
		entry.life -= delta
		if entry.life <= 0.0:
			entry.node.queue_free()
			particles.erase(entry)
			continue
		entry.node.position += entry.velocity * delta
		if entry.node is MeshInstance3D:
			entry.velocity.y -= 6.0 * delta
			entry.node.scale = Vector3.ONE * (entry.life / entry.total)
		else:
			entry.node.modulate.a = minf(1.0, entry.life * 4)
	for entry in trails.duplicate():
		entry.life -= delta
		if entry.life <= 0.0:
			entry.node.queue_free()
			trails.erase(entry)
			continue
		var color: Color = entry.color
		color.a *= entry.life / entry.total
		entry.node.material_override.albedo_color = color
