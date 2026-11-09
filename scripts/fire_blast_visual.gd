extends Node3D
## Cosmetic ground coverage for one real fire impact; advanced only by game tick.

const LIFETIME := 0.40
var lifetime:=LIFETIME
var age := 0.0
var radius := 0.0
var element := "fire"
var _materials: Array[Dictionary] = []
var _flames: Array[Dictionary] = []


func configure(where: Vector3, coverage_radius: float, impact_element: String,duration: float=LIFETIME) -> void:
	lifetime=duration if is_finite(duration) and duration>0 else LIFETIME
	position = Vector3(where.x, .045, where.z)
	radius = coverage_radius
	element = impact_element
	_ground_circle(radius, maxf(0, radius - .065), Color("#ffb447"), .9)
	_ground_circle(radius - .065, 0, Color("#f77523"), .18)
	# Fixed ground positions stay inside the damage circle; there is no growing hitbox.
	for index in range(17):
		var angle := index * TAU / 10.0 + .23
		var ring := .69 if index < 10 else .34
		var offset := Vector3(cos(angle), 0, sin(angle)) * radius * ring
		var height := .28 + .085 * (index % 4)
		var width := .105 + .025 * (index % 3)
		_flame(offset, width, height, Color("#ff7c28"), index)
		_flame(offset + Vector3(0, height * .26, 0), width * .55, height * .78, Color("#ffdd74"), index + 3)
	_flame(Vector3.ZERO, .24, .62, Color("#ff9e35"), 2)
	_flame(Vector3(0, .17, 0), .13, .43, Color("#fff1a5"), 4)
	_update()


func tick(delta: float) -> bool:
	if not is_finite(delta) or delta <= 0: return age < lifetime
	age = minf(lifetime, age + delta)
	_update()
	return age < lifetime


func _ground_circle(outer: float, inner: float, color: Color, opacity: float) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(40):
		var a := Vector3(cos(index * TAU / 40.0), 0, sin(index * TAU / 40.0))
		var b := Vector3(cos((index + 1) * TAU / 40.0), 0, sin((index + 1) * TAU / 40.0))
		for point: Vector3 in [a * inner, a * outer, b * outer, a * inner, b * outer, b * inner]:
			mesh.surface_add_vertex(point)
	mesh.surface_end()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(color, opacity)
	add_child(node)


func _flame(offset: Vector3, width: float, height: float, color: Color, phase: int) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, width)
	node.mesh = mesh
	node.material_override = _material(color, .94)
	node.position = offset + Vector3.UP * height * .5
	add_child(node)
	_flames.append({"node": node, "origin": node.position, "phase": phase})


func _material(color: Color, opacity: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color, opacity)
	_materials.append({"material": material, "color": color, "opacity": opacity})
	return material


func _update() -> void:
	var progress := clampf(age / lifetime, 0, 1)
	var fade := (1.0 - progress) * (1.0 - progress * .35)
	for entry: Dictionary in _materials:
		entry.material.albedo_color = Color(entry.color, entry.opacity * fade)
	for entry: Dictionary in _flames:
		var step := int(age * 25.0) + int(entry.phase)
		var flicker := .88 + .08 * (step % 3)
		entry.node.scale = Vector3(1, maxf(.12, (1 - progress * .7) * flicker), 1)
		entry.node.position = entry.origin + Vector3.UP * progress * .13
