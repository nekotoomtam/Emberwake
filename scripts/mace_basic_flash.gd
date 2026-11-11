extends Sprite3D
## The compact painted flash follows the mace head in the rendered pose.

const FLASH_ART := preload("res://assets/combat/sword_slashes.png")
const FLASH_REGION := Rect2(749, 327, 40, 16)
const SIZES := [.011, .014, .016]
const HEIGHT_SCALES := [.92, .55, 1.14]
const OPACITIES := [.76, .68, .90]
const FADE_TIME := .065

var _stage := -1
var _left_hand := false
var _progress := 0.0
var _last_head := Vector3.ZERO
var _screen_angle := 0.0
var _life := 0.0

func _ready() -> void:
	texture = FLASH_ART
	region_enabled = true
	region_rect = FLASH_REGION
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hide()

func follow(camera: Camera3D, head: Vector3, forward: Vector3, progress: float, stage: int, left_hand: bool) -> void:
	var new_strike := not visible or stage != _stage or left_hand != _left_hand or progress < _progress
	var direction := forward if stage == 1 else (Vector3.DOWN if stage == 2 else Vector3.UP)
	if not new_strike and stage != 1 and head.distance_squared_to(_last_head) > .000004:
		direction = head - _last_head
	var view := camera.global_basis
	var tangent := Vector2(direction.dot(view.x), direction.dot(view.y))
	if new_strike or tangent.length_squared() > .000001:
		_screen_angle = tangent.angle()
	var face := view.rotated(view.z, _screen_angle)
	global_basis = face.scaled_local(Vector3(1.0, HEIGHT_SCALES[stage], 1.0))
	global_position = head
	pixel_size = SIZES[stage]
	_stage = stage
	_left_hand = left_hand
	_progress = progress
	_last_head = head
	_life = FADE_TIME
	modulate.a = OPACITIES[stage] * smoothstep(0.0, .22, progress)
	show()

func tick(delta: float) -> void:
	if not visible: return
	_life = maxf(0.0, _life - delta)
	modulate.a = minf(modulate.a, OPACITIES[_stage] * _life / FADE_TIME)
	if _life <= 0.0: hide()
