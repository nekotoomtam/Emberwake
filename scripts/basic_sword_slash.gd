extends Node3D
## Build the afterimage from rendered blade positions. The art is the flash at its head.

const CUTS := preload("res://assets/combat/sword_slashes.png")
const FINISHER := preload("res://assets/combat/sword_finisher.png")
const CUT_FLASH := Rect2(749, 327, 40, 16)
const FINISHER_FLASH := Rect2(146, 990, 50, 45)
const CUT_TAIL := 0.07
const FINISHER_TAIL := 0.13
const MIN_SAMPLE_DISTANCE := 0.012

var double_slash := false
var smooth_spin := false

var _tips: Array[Vector3] = []
var _grips: Array[Vector3] = []
var _trail := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
var _flash := Sprite3D.new()
var _stage := -1
var _left_hand := false
var _progress := 0.0
var _tail_left := 0.0
var _tail_duration := CUT_TAIL

func _ready() -> void:
	var ribbon := MeshInstance3D.new()
	ribbon.mesh = _trail
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.no_depth_test = true
	_material.vertex_color_use_as_albedo = true
	ribbon.material_override = _material
	add_child(ribbon)

	_flash.region_enabled = true
	_flash.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.no_depth_test = true
	_flash.render_priority = 1
	add_child(_flash)
	hide()

func follow(camera: Camera3D, grip: Vector3, tip: Vector3, progress: float, stage: int, left_hand: bool) -> void:
	var heavy := smooth_spin or stage == (1 if double_slash else 2)
	if not visible or stage != _stage or left_hand != _left_hand or progress < _progress:
		clear()
		_flash.texture = FINISHER if heavy else CUTS
		_flash.region_rect = FINISHER_FLASH if heavy else CUT_FLASH
		_tail_duration = FINISHER_TAIL if heavy else CUT_TAIL
		if double_slash: _tail_duration = 0.115 if heavy else 0.075
		if smooth_spin: _tail_duration = 0.15
	_stage = stage
	_left_hand = left_hand
	_progress = progress
	_tail_left = _tail_duration
	show()
	_set_opacity(1.0)

	var local_tip := to_local(tip)
	var local_grip := to_local(grip)
	var tangent := Vector3.ZERO
	if not _tips.is_empty():
		tangent = tip - to_global(_tips.back())
	_flash.global_position = tip
	var view := camera.global_basis
	var on_screen := Vector2(tangent.dot(view.x), tangent.dot(view.y))
	if on_screen.length_squared() > 0.000001:
		_flash.global_basis = view.rotated(view.z, on_screen.angle())
	elif _tips.is_empty():
		_flash.global_basis = view
	_flash.pixel_size = 0.0055 if heavy else 0.0045
	if smooth_spin: _flash.pixel_size = 0.0065
	if double_slash:
		var pulse := clampf(1.0 - absf(progress - 0.12) / 0.40, 0.0, 1.0)
		_flash.pixel_size = lerpf(0.007, 0.012, pulse) if heavy else 0.0048
	_flash.visible = progress >= 0.12
	if _tips.is_empty() or tangent.length() >= MIN_SAMPLE_DISTANCE:
		_tips.append(local_tip)
		_grips.append(local_grip)
		var sample_limit := 17 if heavy else 13
		if double_slash: sample_limit = 13 if heavy else 10
		if smooth_spin: sample_limit = 28
		if _tips.size() > sample_limit:
			_tips.pop_front()
			_grips.pop_front()
		_rebuild_ribbon(heavy)

func _rebuild_ribbon(heavy: bool) -> void:
	_trail.clear_surfaces()
	if _tips.size() < 2: return
	var width := 1.03 if heavy else 0.83
	var edge := Color("#f7fbff")
	var body := Color("#dbe7ed")
	var body_opacity := 0.62 if heavy else 0.53
	if double_slash:
		width = 1.18 if heavy else 0.77
		edge = Color("#edffff")
		body = Color("#67c9ff") if heavy else Color("#4c8fff")
		body_opacity = 0.80 if heavy else 0.59
	if smooth_spin:
		width = 0.94
		body = Color("#55dcbf")
		body_opacity = 0.75
	var edge_width := width * (0.19 if double_slash else 0.22)
	var tips := _smooth_spin_points(_tips) if smooth_spin else _tips
	var grips := _smooth_spin_points(_grips) if smooth_spin else _grips
	_trail.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(_tips.size() - 1):
		_add_strip(tips, grips, i, 0.0, edge_width, edge, 0.90)
		_add_strip(tips, grips, i, edge_width, width, body, body_opacity)
	_trail.surface_end()

func _smooth_spin_points(points: Array[Vector3]) -> Array[Vector3]:
	# Soften the older samples where the cutout changes facing. Keep the head at the visible blade.
	var smoothed: Array[Vector3] = []
	var last := points.size() - 1
	for index in last:
		var total := Vector3.ZERO
		var weight_sum := 0.0
		for neighbor in range(maxi(0, index - 4), mini(last, index + 4) + 1):
			var weight := float(5 - absi(neighbor - index))
			total += points[neighbor] * weight
			weight_sum += weight
		smoothed.append(points[index].lerp(total / weight_sum, smoothstep(0.0, 4.0, float(last - index))))
	smoothed.append(points[last])
	return smoothed

func _add_strip(tips: Array[Vector3], grips: Array[Vector3], i: int, outer: float, inner: float, color: Color, opacity: float) -> void:
	for corner in [Vector2i(i, 0), Vector2i(i, 1), Vector2i(i + 1, 1),
			Vector2i(i, 0), Vector2i(i + 1, 1), Vector2i(i + 1, 0)]:
		var tip := tips[corner.x]
		var inward := tip.direction_to(grips[corner.x])
		var freshness := float(corner.x) / float(tips.size() - 1)
		var alpha := freshness * opacity
		if corner.y == 1: alpha *= 0.10
		_trail.surface_set_color(Color(color, alpha))
		var distance := outer if corner.y == 0 else inner
		var taper := freshness * (0.66 + 0.34 * sin(freshness * PI))
		_trail.surface_add_vertex(tip + inward * distance * taper)

func tick(delta: float) -> void:
	if not visible: return
	_tail_left = maxf(0.0, _tail_left - delta)
	if _tail_left <= 0.0:
		clear()
		return
	_set_opacity(_tail_left / _tail_duration)

func _set_opacity(opacity: float) -> void:
	_material.albedo_color = Color(1.0, 1.0, 1.0, opacity)
	# Balance the warm source art against the white ribbon.
	_flash.modulate = Color(0.955, 0.97, 1.0, opacity) if smooth_spin or _stage == 2 else Color(0.89, 0.93, 1.0, opacity)
	if double_slash:
		_flash.modulate = Color(0.90, 1.03, 1.14, opacity)

func clear() -> void:
	hide()
	_tail_left = 0.0
	_tips.clear()
	_grips.clear()
	_trail.clear_surfaces()
