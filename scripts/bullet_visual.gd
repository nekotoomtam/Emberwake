extends Node3D
## Plain physical ivory/gold projectile. Flight and contact belong to the manager;
## the bright head stays at this root while a short faded trail points backward.

const PIXEL_SIZE := 0.02
const CORE := Vector2(28, 12)
static var _frames: Array[Texture2D] = []
var bullet: Sprite3D
var contact_radius:=PIXEL_SIZE*4.0
func configure_contact(radius: float) -> void:
	if is_finite(radius) and radius>0:contact_radius=radius

func _ready() -> void:
	_ensure_sprite()

func _ensure_sprite() -> void:
	if bullet != null:
		return
	bullet = Sprite3D.new()
	bullet.name = "bullet"
	bullet.texture = _frame_texture(0)
	bullet.pixel_size = PIXEL_SIZE
	bullet.offset = Vector2(18, 12) - CORE
	bullet.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	bullet.shaded = false
	bullet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bullet)

func update_visual(camera: Camera3D, direction: Vector3, age: float) -> void:
	_ensure_sprite()
	var projected := Vector2(camera.global_basis.x.dot(direction), camera.global_basis.y.dot(direction))
	var angle := atan2(projected.y, projected.x) if projected.length_squared() > 0.000001 else 0.0
	var pixels: float=preload("res://scripts/projectile_image_geometry.gd").cross_radius(_frame_texture(0),CORE)
	var core_scale:=contact_radius/(PIXEL_SIZE*pixels)
	bullet.global_basis = camera.global_basis * Basis(Vector3.BACK, angle) * Basis.from_scale(Vector3(core_scale,core_scale,1))
	bullet.texture = _frame_texture(int(floor(maxf(age, 0.0) * 12.0)) % 2)

static func _frame_texture(frame: int) -> Texture2D:
	if _frames.is_empty():
		for index in 2:
			_frames.append(_draw_frame(index))
	return _frames[frame]

static func _draw_frame(frame: int) -> ImageTexture:
	var image := Image.create(36, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var gold := Color("dcc178")
	# Straight, short motion streak; no flame tongues, red edges or burn halo.
	for x in range(4, 26, 2):
		var shade := gold
		shade.a = lerpf(0.14, 0.70, float(x - 4) / 20.0) * (1.0 if frame == 0 else 0.90)
		image.fill_rect(Rect2i(x, 12, 2, 2), shade)
	for y in range(8, 16):
		for x in range(24, 32):
			var distance := Vector2(x + 0.5 - 28.0, y + 0.5 - 12.0).length_squared()
			if distance > 16.0: continue
			var color := gold
			if distance < 10.0: color = Color("f6e7b4")
			if distance < 4.0: color = Color("fff6d8")
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
