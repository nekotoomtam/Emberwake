extends Sprite3D
## Rotate the painted wind around the active sweep, at the same radius as the skill.

const RINGS := preload("res://assets/combat/stormcaller_silver_ring.png")
const ART_CENTERS := [Vector2(429.5, 439.0), Vector2(443.0, 448.5)]
const ART_SPANS := [Vector2(783.0, 732.0), Vector2(834.0, 783.0)]
const FADE_TIME := 0.12

var _life := 0.0
var _opacity := 0.0

func _ready() -> void:
	texture = RINGS
	hframes = 2
	pixel_size = 1.0
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hide()

func follow(origin: Vector3, radius: float, angle: float, final_sweep: bool) -> void:
	if radius <= 0.05: return
	frame = int(final_sweep)
	var center: Vector2 = ART_CENTERS[frame]
	var half_cell := Vector2(RINGS.get_width() * 0.25, RINGS.get_height() * 0.5)
	offset = Vector2(half_cell.x - center.x, center.y - half_cell.y)
	var span: Vector2 = ART_SPANS[frame]
	var radial := Vector3(cos(angle), 0, sin(angle))
	var tangent := Vector3(sin(angle), 0, -cos(angle))
	global_basis = Basis(radial * (2.0 * radius / span.x), tangent * (2.0 * radius / span.y), Vector3.UP)
	global_position = origin + Vector3.UP * 0.12
	_opacity = minf(1.0, radius / 0.50) * (1.0 if final_sweep else 0.86)
	_life = FADE_TIME
	modulate.a = _opacity
	show()

func tick(delta: float) -> void:
	if not visible: return
	_life = maxf(0.0, _life - delta)
	modulate.a = _opacity * _life / FADE_TIME
	if _life <= 0.0: hide()
