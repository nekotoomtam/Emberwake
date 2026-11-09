extends Node3D
## Painted districts follow the far shore, with native land and quays beneath.
const Detail := preload("res://scripts/opening/harbor_detail.gd")
const Matte := preload("res://scripts/opening/harbor_city_matte.gd")
const FIRST_X := -190
const LAST_X := 1130
const TERRACE_DEPTH := 235.0
const WATERFRONT := "res://assets/city_backdrop/waterfront-low-v96.png"
const CENTRAL_WHARVES := "res://assets/city_backdrop/waterfront.png"
const ROOFS := "res://assets/city_backdrop/rooftops.png"
const UPPER_TERRACE := "res://assets/city_backdrop/upper-terrace.png"
const UPPER_BASE := 17.0

var geometry_count := 0
var painted_districts: Matte


func _ready() -> void:
	name = "FarShoreCity"
	var geometry := Detail.new()
	add_child(geometry)
	var ground := _material("667d70")
	var masonry := _material("778682")
	var streets := _material("8a9388")
	for x: int in range(FIRST_X, LAST_X, 20):
		var shore_left := _site(x, 0)
		var shore_right := _site(x + 20, 0)
		geometry.quad(shore_right, shore_left, shore_left - Vector3.UP * 5.0,
			shore_right - Vector3.UP * 5.0, masonry)
		for row: int in 5:
			var front := row * TERRACE_DEPTH / 5.0
			var back := (row + 1) * TERRACE_DEPTH / 5.0
			geometry.quad(_site(x, front), _site(x + 20, front), _site(x + 20, back),
				_site(x, back), streets if row == 0 else ground)
	for x: int in [75, 325, 565, 815]:
		var at := _site(x, 0)
		geometry.box(at + Vector3(0, -1.2, 17), Vector3(15, 2.8, 37), masonry)
		geometry.box(at + Vector3(0, 0.22, 17), Vector3(15.6, 0.34, 37.4), streets)
	geometry.finish()
	for mesh: MeshInstance3D in geometry.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	painted_districts = Matte.new()
	painted_districts.definitions = [
		_panel("west_wharves", WATERFRONT, -20, 380, 6, -2.2),
		_panel("central_wharves", CENTRAL_WHARVES, 333, 380, 9, -1.8),
		_panel("east_wharves", WATERFRONT, 686, 380, 6, -2.0),
		_panel("outer_wharves", WATERFRONT, 1002, 315, 9, -2.1),
		_panel("west_roofs", ROOFS, 26, 415, 55, 3.8),
		_panel("central_roofs", ROOFS, 406, 415, 62, 4.4),
		_panel("east_roofs", ROOFS, 788, 430, 55, 4.0),
		{"id": "upper_terrace", "path": UPPER_TERRACE, "center_x": -380.0,
			"z": -781.0, "width": 670.0, "base_y": UPPER_BASE},
	]
	add_child(painted_districts)
	for material: StandardMaterial3D in painted_districts.materials:
		material.albedo_color = Color(0.84, 0.91, 0.94)
	for layer: MeshInstance3D in painted_districts.layers:
		var id: String = layer.get_meta("city_layer_id")
		if id == "upper_terrace":
			var quad := layer.mesh as QuadMesh
			quad.size.y *= 0.72
			layer.position.y = UPPER_BASE + quad.size.y * 0.5
			layer.material_override.albedo_color = Color(0.92, 0.96, 0.99)
			painted_districts.bounds[id] = layer.transform * quad.get_aabb()
		elif id == "central_roofs":
			var mat := layer.material_override as StandardMaterial3D
			mat.uv1_offset.x += mat.uv1_scale.x
			mat.uv1_scale.x *= -1.0
	geometry_count = geometry.count + painted_districts.geometry_count


func _panel(id: String, path: String, x: float, width: float, depth: float, y: float) -> Dictionary:
	var a := _site(x - width * 0.5, depth)
	var b := _site(x + width * 0.5, depth)
	var edge := Vector2(b.x - a.x, b.z - a.z)
	return {"id": id, "path": path, "center_x": x, "z": (a.z + b.z) * 0.5,
		"width": edge.length(), "base_y": y, "rotation_y": -edge.angle()}


func _site(x: float, depth: float) -> Vector3:
	var shoreline := -701.0 - 92.0 * sin(clampf((x + 115.0) / 1030.0, 0.0, 1.0) * PI)
	shoreline += 24.0 * sin(x * 0.009) + 11.0 * cos(x * 0.017)
	var rise := depth / TERRACE_DEPTH
	var hill := 29.0 + 12.0 * sin(x * 0.011) + 7.0 * cos(x * 0.022)
	var crest := rise * (1.0 - 0.8 * smoothstep(0.62, 1.0, rise))
	return Vector3(x, 0.6 + crest * hill + sin(rise * PI) * 2.0, shoreline - depth)


func _material(hex: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(hex)
	material.roughness = 1.0
	material.disable_receive_shadows = true
	return material
