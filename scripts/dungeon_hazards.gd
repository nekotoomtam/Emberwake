extends Node3D
## Local footprints drive both the visible terrain and its effects.
const WetlandArt = preload("res://scripts/dungeon_wetland_art.gd")
const Wetland = preload("res://scripts/dungeon_wetland.gd")
const SporePatch = preload("res://scripts/dungeon_spore_patch.gd")

var feature: String
var wetland_zones: Array[Dictionary] = []
var _spore_patches: Array[SporePatch] = []
var _ripple_left := 0.0


func configure(kind: String, outline: PackedVector2Array, seed_: int, poison_groups: Array[Vector2]) -> void:
	feature = kind
	match feature:
		"wetland":
			wetland_zones = Wetland.plan(outline, seed_)
			_draw_wetland()
		"mushrooms":
			_build_spore_patches(poison_groups)


func _draw_wetland() -> void:
	var surfaces := Node3D.new()
	surfaces.name = "WetlandSurfaces"
	add_child(surfaces)
	var shores := SurfaceTool.new()
	shores.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zone in wetland_zones:
		var water: bool = zone.kind == "water"
		surfaces.add_child(WetlandArt.surface(zone.outline, zone.bounds, water))
		_shore_details(shores, zone.outline, water)
	var mesh := shores.commit()
	if mesh != null and mesh.get_surface_count() > 0:
		var material := _surface(Color.WHITE)
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_prop(mesh, material, Vector3.ZERO)


func _shore_details(builder: SurfaceTool, outline: PackedVector2Array, water: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([outline, "wetland_shore"])
	var spacing := rng.randf_range(.2, 1.8)
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		var length := a.distance_to(b)
		while spacing < length:
			var point := a.lerp(b, spacing / length)
			var normal := (b - a).normalized().orthogonal()
			if Geometry2D.is_point_in_polygon(point + normal * .10, outline):
				normal = -normal
			var edge := Vector3(point.x, .046, point.y)
			var outward := Vector3(normal.x, 0, normal.y)
			var roll := rng.randf()
			if roll < .43:
				_gravel(builder, edge - outward * .09, rng.randf_range(.63, 1.15), water)
			spacing += rng.randf_range(1.0, 2.85)
		spacing -= length


func _gravel(builder: SurfaceTool, at: Vector3, size: float, water: bool) -> void:
	var tone := Color("#8e8b70") if water else Color("#987e60")
	var a := at + Vector3(-.16, 0, .035) * size
	var b := at + Vector3(-.09, .029, -.11) * size
	var c := at + Vector3(.12, .018, -.078) * size
	var d := at + Vector3(.18, 0, .045) * size
	var e := at + Vector3(.025, 0, .12) * size
	var top := at + Vector3(.004, .06, -.026) * size
	_shore_triangle(builder, a, b, top, tone.lightened(.16))
	_shore_triangle(builder, b, c, top, tone)
	_shore_triangle(builder, c, d, top, tone.darkened(.12))
	_shore_triangle(builder, d, e, top, tone.darkened(.22))
	_shore_triangle(builder, e, a, top, tone.darkened(.09))


func _shore_triangle(builder: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
	var normal := (c - a).cross(b - a).normalized()
	if normal.y < 0.0: normal = -normal
	for point in [a, b, c]:
		builder.set_color(tint)
		builder.set_normal(normal)
		builder.add_vertex(point)



func _build_spore_patches(centers: Array[Vector2]) -> void:
	var patches := Node3D.new()
	patches.name = "SporePatches"
	add_child(patches)
	for at in centers:
		var patch := SporePatch.new()
		patch.position = Vector3(at.x, 0, at.y) - position
		patches.add_child(patch)
		patch.setup(hash(at))
		_spore_patches.append(patch)


func _prop(mesh: Mesh, surface: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = surface
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _surface(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .91
	if color.a < 1.0: material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func speed_scale(at: Vector3) -> float:
	match _wetland_at(at):
		"water": return .85
		"mud": return .65
	return 1.0


func _wetland_at(at: Vector3) -> String:
	var point := Vector2(at.x, at.z)
	for zone in wetland_zones:
		if zone.bounds.has_point(point) and Geometry2D.is_point_in_polygon(point, zone.outline):
			return zone.kind
	return ""

func companion_motion(at: Vector3, motion: Vector3) -> Vector3:
	var result := motion
	var nearest := INF
	for patch in _spore_patches:
		var distance := at.distance_squared_to(patch.global_position)
		if distance >= nearest: continue
		var detour := patch.companion_motion(at, motion)
		if detour != motion:
			result = detour
			nearest = distance
	return result


func tick(delta: float, game) -> void:
	if delta <= 0.0: return
	if feature == "wetland":
		_ripple_left = maxf(0.0, _ripple_left - delta)
		var at: Vector3 = game.player.global_position
		if _ripple_left == 0.0 and game.player.velocity.length_squared() > 1.0 and _wetland_at(at) == "water":
			game.fx.ring(at, .48, Color("#a7d3c5"), .25)
			_ripple_left = .22
		return
	for patch in _spore_patches:
		patch.tick(delta, game)
