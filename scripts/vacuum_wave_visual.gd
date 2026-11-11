extends Node3D
## Upright wind blade with two slim trailing streamers. Local +X is travel;
## the ivory bowed spine's foremost center stays at the swept contact origin.
## This is presentation only: the manager retains its ordinary circle collision.

var contact_radius := 0.8
const WAKE_HEIGHT := 0.058
var _ground_y := NAN
var spine: MeshInstance3D
var wisps: MeshInstance3D
static var _spine_mesh: ArrayMesh
static var _wisp_mesh: ArrayMesh

func _ready() -> void:
	_ensure_meshes()

func configure_contact(radius: float) -> void:
	if is_finite(radius) and radius > 0.0: contact_radius = radius

func configure_ground(ground_y: float) -> void:
	_ground_y = ground_y

func ground_anchor(head: Vector3, forward: Vector3, radius: float, ground_y: float) -> Vector3:
	var anchor := head + forward * (_blade_point(-1.0, 0.0).x * radius)
	anchor.y = ground_y + WAKE_HEIGHT
	return anchor

func _ensure_meshes() -> void:
	if spine != null: return
	if _spine_mesh == null:
		var blade := SurfaceTool.new()
		blade.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index in 32:
			var a := -1.0 + float(index) / 16.0
			var b := -1.0 + float(index + 1) / 16.0
			# A broad ivory vertical edge and a cyan concave back, split in depth.
			for band in 2:
				var front := float(band) * 0.085
				var back := float(band + 1) * 0.085
				_quad(blade, _blade_point(a, front), _blade_point(b, front), _blade_point(a, back), _blade_point(b, back), Color("fffbe6") if band == 0 else Color("9debf5"))
		_spine_mesh = blade.commit()
		var wind := SurfaceTool.new()
		wind.begin(Mesh.PRIMITIVE_TRIANGLES)
		for strand in 2:
			for index in 24:
				var a := float(index) / 24.0
				var b := float(index + 1) / 24.0
				_quad(wind, _wind_point(a, strand, 0.0), _wind_point(b, strand, 0.0), _wind_point(a, strand, 0.06), _wind_point(b, strand, 0.06), Color("d9ffff") if strand == 0 else Color("78cddd"))
		_wisp_mesh = wind.commit()
	spine = _part("spine", _spine_mesh)
	wisps = _part("wisps", _wisp_mesh)

func _part(part_name: String, mesh: ArrayMesh) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	part.material_override = material
	add_child(part)
	return part

func update_visual(_camera: Camera3D, direction: Vector3, age: float) -> void:
	_ensure_meshes()
	var forward := Vector3(direction.x, 0.0, direction.z).normalized()
	if forward.length_squared() < 0.000001: return
	global_basis = Basis(forward, Vector3.UP, forward.cross(Vector3.UP)) * Basis.from_scale(Vector3.ONE * contact_radius)
	if is_finite(_ground_y):
		var foot := _blade_point(-1.0, 0.0)
		spine.position.y = (_ground_y + WAKE_HEIGHT - global_position.y) / contact_radius - foot.y
		wisps.position.y = spine.position.y
	# Only the trailing wind rotates; the ivory contact spine does not wander.
	wisps.rotation.x = maxf(0.0, age) * 7.0

static func _blade_point(t: float, width: float) -> Vector3:
	var thickness := lerpf(1.95, 0.70, (t + 1.0) * 0.5)
	var height := t * (0.86 if t < 0.0 else 1.42)
	return Vector3(-0.88 * t * t - width * thickness * sqrt(maxf(0.0, 1.0 - t * t)), height, sin(t * PI) * 0.18)

static func _wind_point(t: float, strand: int, width: float) -> Vector3:
	var angle := float(strand) * PI + t * PI * 1.3
	var radius := (0.18 + 0.32 * sin(t * PI * 0.7)) + width * sin(t * PI)
	return Vector3(-0.08 - t * 1.7, cos(angle) * radius, sin(angle) * radius)

static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, shade: Color) -> void:
	for vertex in [a, c, b, b, c, d]:
		surface.set_color(shade)
		surface.set_normal(Vector3.UP)
		surface.add_vertex(vertex)
