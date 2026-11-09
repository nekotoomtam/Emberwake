extends Node3D
## One short physical bullet streak per shot. Its head follows the swept contact
## center; the finite trailing sprite never connects back to the muzzle.

const PIXEL_SIZE := 0.03
const CORE := Vector2(28, 12)
static var _texture: Texture2D
var bullet: Sprite3D
var contact_radius:=PIXEL_SIZE
func configure_contact(radius: float) -> void:
	if is_finite(radius) and radius>0:contact_radius=radius

func _ready() -> void:
	_ensure_sprite()

func _ensure_sprite() -> void:
	if bullet != null: return
	bullet = Sprite3D.new()
	bullet.name = "bullet"
	bullet.texture = _frame_texture()
	bullet.pixel_size = PIXEL_SIZE
	bullet.offset = Vector2(18, 12) - CORE
	bullet.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	bullet.shaded = false
	bullet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bullet)

func update_visual(camera: Camera3D, direction: Vector3, _age: float) -> void:
	_ensure_sprite()
	var projected := Vector2(camera.global_basis.x.dot(direction), camera.global_basis.y.dot(direction))
	var angle := atan2(projected.y, projected.x) if projected.length_squared() > 0.000001 else 0.0
	# Keep streak length; scale its cross section to the swept bullet radius.
	var pixels: float=preload("res://scripts/projectile_image_geometry.gd").cross_radius(_frame_texture(),CORE)
	bullet.global_basis = camera.global_basis * Basis(Vector3.BACK, angle) * Basis.from_scale(Vector3(1,contact_radius/(PIXEL_SIZE*pixels),1))

static func _frame_texture() -> Texture2D:
	if _texture != null: return _texture
	var image := Image.create(36, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	# A narrow ivory slug with a short fading gold tail, without a round head.
	for x in range(2, 13):
		var shade := Color("dcc178")
		shade.a = lerpf(0.10, 0.72, float(x - 2) / 10.0)
		image.fill_rect(Rect2i(x, 11, 1, 2), shade)
	image.fill_rect(Rect2i(13, 11, 16, 2), Color("fff2ca"))
	image.fill_rect(Rect2i(29, 11, 2, 2), Color("dcc178"))
	_texture = ImageTexture.create_from_image(image)
	return _texture
