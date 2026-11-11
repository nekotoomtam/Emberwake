extends Sprite3D
## Start at the charged hit radius and sweep the painted wind into the fixed impact point.

const ART := preload("res://assets/combat/mace_gather_vortex.png")
const ART_RADIUS := 583.0
const LIFETIME := .32
var age := 0.0

func configure(center: Vector3, radius: float) -> void:
	texture = ART
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pixel_size = radius / ART_RADIUS
	offset = Vector2(23, -1)
	rotation.x = -PI * .5
	position = center + Vector3.UP * .043
	_update_frame()

func tick(delta: float) -> bool:
	age = minf(age + delta, LIFETIME)
	_update_frame()
	return age < LIFETIME

func _update_frame() -> void:
	var progress := smoothstep(0.0, LIFETIME, age)
	var radius_scale := lerpf(1.0, .14, progress)
	rotation.y = -.88 * progress
	scale = Vector3(radius_scale, radius_scale, 1.0)
	modulate.a = .86 * (1.0 - smoothstep(.10, LIFETIME, age))
