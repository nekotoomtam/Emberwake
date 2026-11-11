extends Sprite3D
## The painted pressure front follows the current head. Its tail faces the path just traveled.

const ART := preload("res://assets/combat/mace_sweep_streak.png")
const ART_REGION := Rect2(620, 214, 1018, 310)
const ART_WIDTH := 992.0
const FADE_TIME := .075
const SILVER_SHADER := preload("res://shaders/mace_silver_streak.gdshader")

enum Style { SWEEP, ARMOR, COUNTER }

var _strike := Vector2i(-1, -1)
var _head := Vector3.ZERO
var _progress := 0.0
var _screen_angle := 0.0
var _life := 0.0
var _opacity := 0.0
var _silver_material: ShaderMaterial

func _ready() -> void:
	texture = ART
	region_enabled = true
	region_rect = ART_REGION
	offset = Vector2(-411, 0)
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	no_depth_test = true
	render_priority = 1
	_silver_material = ShaderMaterial.new()
	_silver_material.shader = SILVER_SHADER
	_silver_material.set_shader_parameter("streak_art", ART)
	hide()

func follow(camera: Camera3D, head: Vector3, swing_direction: Vector3, progress: float, strike: Vector2i, style: Style = Style.SWEEP) -> void:
	var new_strike := not visible or strike != _strike or progress < _progress
	var travel := head - _head
	var direction := swing_direction if new_strike or travel.length_squared() < .000004 else travel
	var view := camera.global_basis
	var tangent := Vector2(direction.dot(view.x), direction.dot(view.y))
	if new_strike or tangent.length_squared() > .000001:
		_screen_angle = tangent.angle()
	global_basis = view.rotated(view.z, _screen_angle)
	global_position = head
	var second := strike.y == 1
	var rise := smoothstep(0.0, .29, progress)
	var width := .86 if second else .62
	var opacity := .96 if second else .77
	match style:
		Style.ARMOR:
			width = .99
			opacity = .90
		Style.COUNTER:
			width = 1.34
			opacity = 1.0
	pixel_size = width * lerpf(.70, 1.0, rise) / ART_WIDTH
	_opacity = opacity * rise
	material_override = _silver_material if style == Style.ARMOR else null
	_set_alpha(_opacity)
	_strike = strike
	_head = head
	_progress = progress
	_life = FADE_TIME
	show()

func tick(delta: float) -> void:
	if not visible: return
	_life = maxf(0.0, _life - delta)
	_set_alpha(_opacity * _life / FADE_TIME)
	if _life <= 0.0: hide()

func _set_alpha(opacity: float) -> void:
	if material_override == _silver_material:
		_silver_material.set_shader_parameter("opacity", opacity)
	else:
		modulate.a = opacity
