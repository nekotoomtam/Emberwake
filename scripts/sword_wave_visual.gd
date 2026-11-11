extends Node3D
## The painted crest travels in the ground plane. Its leading center stays at
## the projectile origin while the outer wind wisps extend past the hit radius.

const WIND := preload("res://assets/combat/storm_blade_wind.png")
const ART_SPAN := 560.0
const VISUAL_WIDTH := 1.22
const CRESTS := [
	Vector2(313.5, 323.0), Vector2(312.5, 257.0),
	Vector2(315.0, 163.0), Vector2(314.0, 201.0),
]

var contact_radius := 0.45
var crest: Sprite3D

func _ready() -> void:
	crest = Sprite3D.new()
	crest.name = "wind_crest"
	crest.texture = WIND
	crest.hframes = 2
	crest.vframes = 2
	crest.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	crest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crest)

func configure_contact(radius: float) -> void:
	if is_finite(radius) and radius > 0.0:
		contact_radius = radius

func update_visual(_camera: Camera3D, direction: Vector3, age: float) -> void:
	var forward := Vector3(direction.x, 0.0, direction.z).normalized()
	if forward.is_zero_approx(): return
	var side := forward.cross(Vector3.UP)
	crest.global_basis = Basis(side * VISUAL_WIDTH, forward, Vector3.UP)
	crest.pixel_size = contact_radius * 2.0 / ART_SPAN
	# Build, roll and break the crest as it travels, with a readable rim at range.
	var frame := 0
	if age >= 0.39:
		frame = 3
	elif age >= 0.18:
		frame = 2
	elif age >= 0.075:
		frame = 1
	crest.frame = frame
	var center := WIND.get_size() * 0.25
	var front: Vector2 = CRESTS[frame]
	crest.offset = Vector2(center.x - front.x, front.y - center.y)
	crest.modulate.a = lerpf(1.0, 0.68, clampf((age - 0.39) / 0.19, 0.0, 1.0))
