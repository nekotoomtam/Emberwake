extends Sprite3D

const ART := preload("res://assets/combat/mace_leap_wave.png")
const WAVE_SHADER := preload("res://shaders/mace_leap_wave.gdshader")
const LIFETIME := .46

var _age := 0.0
var _material: ShaderMaterial

func configure(center: Vector3, radius: float, angle: float, arc: float, strength: float) -> void:
	name = "MaceLeapWave"
	texture = ART
	# The quad runs forward one radius from the landing and spans two radii across.
	pixel_size = radius / float(ART.get_width())
	offset.x = float(ART.get_width()) * .5
	scale.y = 2.0 * float(ART.get_width()) / float(ART.get_height())
	rotation = Vector3(-PI * .5, -angle, 0.0)
	position = center + Vector3.UP * .052
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = WAVE_SHADER
	_material.set_shader_parameter("wave_art", ART)
	_material.set_shader_parameter("half_arc", arc * .5)
	_material.set_shader_parameter("strength", strength)
	material_override = _material

func tick(delta: float) -> bool:
	_age = minf(_age + delta, LIFETIME)
	_material.set_shader_parameter("progress", _age / LIFETIME)
	return _age < LIFETIME
