extends Sprite3D
## The painted sparks lift from the head when the fireball leaves it.

const ART := preload("res://assets/combat/mace_fire_scoop.png")
const SOIL_ART := preload("res://assets/combat/mace_ember_soil.png")
const ART_REGION := Rect2(238, 185, 880, 894)
const LIFETIME := .20

var age := 0.0
var _birth := Vector3.ZERO

func configure(origin: Vector3, mirrored: bool, soil: bool = false) -> void:
	texture = SOIL_ART if soil else ART
	region_enabled = true
	region_rect = Rect2(355, 175, 790, 840) if soil else ART_REGION
	flip_h = mirrored
	var anchor := Vector2(245, 379) if soil else Vector2(188, 408)
	offset = Vector2(-anchor.x if mirrored else anchor.x, anchor.y)
	pixel_size = .95 / 735.0 if soil else .93 / 824.0
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	no_depth_test = true
	render_priority = 1
	_birth = origin
	_update_frame()

func align_head(head: Vector3) -> void:
	if age > .04: return
	_birth = head
	_update_frame()

func tick(delta: float) -> bool:
	age = minf(age + delta, LIFETIME)
	_update_frame()
	return age < LIFETIME

func _update_frame() -> void:
	var rise := smoothstep(0.0, .09, age)
	scale = Vector3(lerpf(.66, 1.04, rise), lerpf(.59, 1.05, rise), 1.0)
	position = _birth + Vector3.UP * (.13 * age / LIFETIME)
	modulate.a = .92 * (1.0 - smoothstep(.04, LIFETIME, age))
