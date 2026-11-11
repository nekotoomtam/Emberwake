extends MeshInstance3D
## Two wind ribbons wrap around the rendered sword and flow toward its tip.

const SEGMENTS := 48
const WIND_COLOR := Color("#c7fff3")
var _ribbons := ImmediateMesh.new()

func _ready() -> void:
	mesh = _ribbons
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material_override = material

func follow(camera: Camera3D, grip: Vector3, tip: Vector3, time: float, opacity: float) -> void:
	var axis := grip.direction_to(tip)
	if axis.is_zero_approx():
		hide()
		return
	var view := camera.global_basis.z
	var side := view.cross(axis)
	if side.length_squared() < 0.0001:
		side = camera.global_basis.x.slide(axis)
	side = side.normalized()
	var depth := axis.cross(side)
	grip = to_local(grip)
	tip = to_local(tip)
	_ribbons.clear_surfaces()
	_ribbons.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for strand in 2:
		var phase := PI * strand - time * 7.5
		for i in SEGMENTS:
			var a := float(i) / SEGMENTS
			var b := float(i + 1) / SEGMENTS
			var angle := a * TAU * 1.65 + phase
			var point_a := _wind_point(grip, tip, side, depth, a, phase)
			var point_b := _wind_point(grip, tip, side, depth, b, phase)
			var across := view.cross(point_a.direction_to(point_b)).normalized() * (0.024 + 0.021 * absf(sin(angle)))
			var light := (0.42 + 0.48 * maxf(0.0, sin(angle))) * sin(lerpf(0.23, 2.9, a))
			_ribbons.surface_set_color(Color(WIND_COLOR, light * opacity))
			for vertex in [point_a - across, point_a + across, point_b + across, point_a - across, point_b + across, point_b - across]:
				_ribbons.surface_add_vertex(vertex)
	_ribbons.surface_end()
	show()

func _wind_point(grip: Vector3, tip: Vector3, side: Vector3, depth: Vector3, along: float, phase: float) -> Vector3:
	var angle := along * TAU * 1.65 + phase
	var radius := 0.21 * sin(lerpf(0.2, 2.65, along))
	return grip.lerp(tip, lerpf(0.09, 0.98, along)) + (side * cos(angle) + depth * sin(angle)) * radius
