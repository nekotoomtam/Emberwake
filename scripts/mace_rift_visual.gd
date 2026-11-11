extends Sprite3D

const ART := preload("res://assets/combat/mace_rift_cracks.png")
const CRACK_SHADER := preload("res://shaders/mace_rift_cracks.gdshader")

enum Phase { PLACEMENT, CHARGE, ECHO }

var _duration := .20
var _age := 0.0
var _material: ShaderMaterial

func configure(center: Vector3, radius: float, angle: float, phase: Phase, duration: float) -> void:
	texture = ART
	pixel_size = radius * 2.0 / float(ART.get_width())
	rotation = Vector3(-PI * .5, -angle, 0.0)
	position = center + Vector3.UP * (.033 + .007 * float(phase))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_duration = duration
	_material = ShaderMaterial.new()
	_material.shader = CRACK_SHADER
	_material.set_shader_parameter("crack_art", ART)
	_material.set_shader_parameter("phase", phase)
	material_override = _material
	name = ["MaceRiftPlacement", "MaceRiftCharge", "MaceRiftEcho"][phase]

func tick(delta: float) -> bool:
	_age = minf(_age + delta, _duration)
	_material.set_shader_parameter("progress", _age / _duration)
	return _age < _duration
