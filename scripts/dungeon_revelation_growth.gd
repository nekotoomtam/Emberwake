extends MeshInstance3D
## One room-local batch for growth attached to existing forest anchors.

const GrowthShader = preload("res://shaders/dungeon_revelation_growth.gdshader")
const EyeTissue = preload("res://assets/foliage/revelation-eye-tissue.png")
const NODULE := 0.0
const EYE := 0.5
const MEMBRANE := 1.0
const STRANDS := 0
const SHEET := 1
const CRUST := 2
const SITE_SHARE := .60
const CARD_UP := Vector3(0, .82, -.57)

var _material := ShaderMaterial.new()
var _surface := SurfaceTool.new()
var _rng := RandomNumberGenerator.new()


func setup(sites: Array[Dictionary], borders: PackedVector3Array, seed_: int) -> void:
	_rng.seed = seed_
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var infected := _select_sites(sites)
	for site in infected:
		var distant: bool = site.distant
		var underbrush: bool = site.get("underbrush", false)
		var at: Vector3 = site.at
		var tone := _rng.randf_range(.70, .92) if distant else _rng.randf_range(.88, 1.0)
		var size := _rng.randf_range(.58, .97)
		var axis := Vector3.RIGHT.rotated(Vector3.UP, _rng.randf_range(0.0, TAU))
		var spread := _rng.randf_range(.66, 1.42)
		_membrane(at - axis * .32, at + axis * spread, tone * .86, .82, _rng.randi_range(SHEET, CRUST))
		if underbrush:
			_card(at + Vector3(0, .22, .11), Vector2(size, size * .60), NODULE, tone * .85)
			if _rng.randf() < .64:
				_eye(at + Vector3(.22, .23, .42), .45, tone * .77)
			continue
		_card(at + Vector3(_rng.randf_range(-.17, .17), _rng.randf_range(.25, .53), .25), Vector2(size, size * .67), NODULE, tone)
		if not distant and _rng.randf() < .62:
			_card(at + Vector3(_rng.randf_range(-.30, .30), .75, .25), Vector2(size * .66, size * .57), NODULE, tone)
			var root_side := _rng.randf_range(.38, .66) * (-1.0 if _rng.randf() < .5 else 1.0)
			_card(at + Vector3(root_side, .17, .43), Vector2(size * .53, size * .34), NODULE, tone * .94)
		if _rng.randf() < (.58 if distant else .77):
			var eye_size := _rng.randf_range(.31, .50) if distant else _rng.randf_range(.52, .80)
			var side := -1.0 if _rng.randf() < .5 else 1.0
			var eye_at := at + Vector3(side * _rng.randf_range(.4, .93), .23, _rng.randf_range(.36, .85))
			if not distant:
				_membrane(at, eye_at + Vector3(side * .92, -.12, .18), tone * .86, .40)
			_eye(eye_at, eye_size, tone)
	for i in infected.size():
		var a: Vector3 = infected[i].at
		var best := 6.5 * 6.5
		var next := -1
		for j in range(i + 1, infected.size()):
			var b: Vector3 = infected[j].at
			var distance := a.distance_squared_to(b)
			if distance < 1.6 * 1.6 or distance > best:
				continue
			if a.x * b.x < 0.0 or a.z * b.z < 0.0:
				continue
			best = distance
			next = j
		if next >= 0 and _rng.randf() < .75:
			var b: Vector3 = infected[next].at
			var tissue_tone := .72 if infected[i].distant else .92
			_membrane(a, b, tissue_tone)
			if _rng.randf() < .42:
				var eye_at := a.lerp(b, _rng.randf_range(.38, .62)) + Vector3(0.0, .20, .12)
				_eye(eye_at, .64 * tissue_tone, tissue_tone)
	_add_border_tissue(borders)
	mesh = _surface.commit()
	_material.shader = GrowthShader
	_material.set_shader_parameter("eye_tissue", EyeTissue)
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hide()


func _select_sites(sites: Array[Dictionary]) -> Array[Dictionary]:
	var nearby: Array[Dictionary] = []
	var backdrop: Array[Dictionary] = []
	for site in sites:
		if site.distant:
			backdrop.append(site)
		else:
			nearby.append(site)
	var result: Array[Dictionary] = []
	for pool in [nearby, backdrop]:
		for i in roundi(pool.size() * SITE_SHARE):
			var selected := _rng.randi_range(i, pool.size() - 1)
			var site: Dictionary = pool[selected]
			pool[selected] = pool[i]
			pool[i] = site
			result.append(site)
	return result


func _add_border_tissue(borders: PackedVector3Array) -> void:
	for i in range(0, borders.size(), 2):
		var a := borders[i]
		var b := borders[i + 1]
		var length := a.distance_to(b)
		var inward := (b - a).normalized().cross(Vector3.UP)
		var count := maxi(1, ceili(length / 3.5))
		for j in count:
			var overlap := minf(.12, .26 / length)
			var first := a.lerp(b, maxf(0.0, float(j) / count - overlap)) + inward * .65
			var last := a.lerp(b, minf(1.0, float(j + 1) / count + overlap)) + inward * .65
			_membrane(first, last, _rng.randf_range(.82, .97), 1.58, _rng.randi_range(SHEET, CRUST))


func present(revealed: bool, observer: Vector3) -> void:
	visible = revealed
	if revealed:
		_material.set_shader_parameter("observer", Vector2(observer.x, observer.z))


func _eye(center: Vector3, width: float, tone: float) -> void:
	_card(center, Vector2(width * 2.75, width * 1.40), EYE, tone)


func _card(center: Vector3, size: Vector2, kind: float, tone: float) -> void:
	var right := Vector3.RIGHT * size.x * .5
	var up_axis := Vector3(0, .58, -.81) if kind == EYE else CARD_UP
	var up := up_axis * size.y * .5
	_quad([center - right + up, center + right + up, center - right - up, center + right - up],
		[Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Vector2.ONE], center, kind, tone)


func _membrane(a: Vector3, b: Vector3, tone: float, width_scale: float = 1.0, style: int = STRANDS) -> void:
	var side := (b - a).normalized().cross(Vector3.UP)
	var width := _rng.randf_range(.48, .88) * width_scale
	var bend := _rng.randf_range(-.52, .52)
	var middle := a.lerp(b, .5)
	var phase := _rng.randf()
	for i in 6:
		var u := i / 6.0
		var v := (i + 1) / 6.0
		var first := a.lerp(b, u) + side * sin(u * PI) * bend + Vector3.UP * (.035 + absf(u - .5) * .22)
		var last := a.lerp(b, v) + side * sin(v * PI) * bend + Vector3.UP * (.035 + absf(v - .5) * .22)
		var first_width := side * width * (.13 + .87 * sin(u * PI))
		var last_width := side * width * (.13 + .87 * sin(v * PI))
		_quad([first - first_width, last - last_width, first + first_width, last + last_width],
			[Vector2(u, 0), Vector2(v, 0), Vector2(u, 1), Vector2(v, 1)], middle, MEMBRANE, tone, phase, style * .5)


func _quad(points: Array[Vector3], uvs: Array[Vector2], center: Vector3, kind: float, tone: float, phase: float = -1.0, style: float = 1.0) -> void:
	var timing := _rng.randf() if phase < 0.0 else phase
	for i in [0, 2, 1, 1, 2, 3]:
		_surface.set_color(Color(kind, tone, timing, style))
		_surface.set_uv(uvs[i])
		_surface.set_uv2(Vector2(center.x, center.z))
		_surface.add_vertex(points[i])
