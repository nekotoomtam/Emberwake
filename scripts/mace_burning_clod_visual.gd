extends Sprite3D

const ART := preload("res://assets/combat/mace_molten_fireball.png")
const ART_WIDTH := 1108.0

func _ready() -> void:
	texture = ART
	region_enabled = true
	region_rect = Rect2(153, 156, 1108, 723)
	offset = Vector2(-238, 0)
	set_width(.98)
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	no_depth_test = true
	render_priority = 1

func set_width(width: float) -> void:
	pixel_size = width / ART_WIDTH

func update_visual(camera: Camera3D, direction: Vector3, age: float) -> void:
	var view := camera.global_basis
	var screen := Vector2(direction.dot(view.x), direction.dot(view.y))
	if screen.length_squared() > .000001:
		global_basis = view.rotated(view.z, screen.angle() + sin(age * 25.0) * .13)
