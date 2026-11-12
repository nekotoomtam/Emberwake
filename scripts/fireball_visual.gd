extends Node3D
## Original animated pixel flame. The manager owns position and collision;
## the hot head stays at this node's origin while its tail trails in screen space.

const PIXEL_SIZE := 0.03375
const ChargedFireArt = preload("res://scripts/staff_charged_fire_art.gd")
const BasicStaffArt = preload("res://scripts/staff_basic_projectile_art.gd")
const IceVolleyArt = preload("res://scripts/staff_ice_volley_art.gd")
const StaffLv10Art = preload("res://scripts/staff_lv10_art.gd")
const CORE := Vector2(28, 12)
static var _frames: Dictionary = {}
var flame: Sprite3D
var contact_radius:=PIXEL_SIZE*8.0
var element := "fire"
var charged_art := false
var basic_staff_art := false
var ice_volley_art := false
var chain_lightning_art := false

func configure_element(value: String) -> void:
	element = value
	flame.texture = _frame_texture(0, element)
func configure_contact(radius: float) -> void:
	if is_finite(radius) and radius>0:contact_radius=radius

func _ready() -> void:
	_ensure_sprite()

func _ensure_sprite() -> void:
	if flame != null:
		return
	flame = Sprite3D.new()
	flame.name = "flame"
	flame.texture = _frame_texture(0)
	flame.pixel_size = PIXEL_SIZE
	flame.offset = Vector2(20, 12) - CORE
	flame.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	flame.shaded = false
	flame.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flame)

func update_visual(camera: Camera3D, direction: Vector3, age: float) -> void:
	_ensure_sprite()
	var projected := Vector2(camera.global_basis.x.dot(direction), camera.global_basis.y.dot(direction))
	var angle := atan2(projected.y, projected.x) if projected.length_squared() > 0.000001 else 0.0
	if charged_art or ice_volley_art or chain_lightning_art:
		var spell_art := IceVolleyArt if ice_volley_art else ChargedFireArt
		if chain_lightning_art: spell_art = StaffLv10Art
		var frame := int(floor(maxf(age, 0.0) * 16.0)) % spell_art.FRAME_COUNT
		flame.texture = spell_art.frame(spell_art.FLIGHT, frame)
		flame.offset = spell_art.offset_3d(spell_art.FLIGHT, frame)
		flame.pixel_size = contact_radius / (45.0 if chain_lightning_art else 52.0)
		flame.global_basis = camera.global_basis * Basis(Vector3.BACK, angle)
		return
	if basic_staff_art:
		var frame := int(floor(maxf(age, 0.0) * 16.0)) % 4
		flame.texture = BasicStaffArt.frame(element, frame)
		flame.offset = BasicStaffArt.offset_3d(element, frame)
		flame.pixel_size = contact_radius / 40.0
		flame.global_basis = camera.global_basis * Basis(Vector3.BACK, angle)
		return
	var pixels: float=preload("res://scripts/projectile_image_geometry.gd").cross_radius(_frame_texture(0),CORE)
	var core_scale:=contact_radius/(PIXEL_SIZE*pixels)
	flame.global_basis = camera.global_basis * Basis(Vector3.BACK, angle) * Basis.from_scale(Vector3(core_scale,core_scale,1))
	flame.texture = _frame_texture(int(floor(maxf(age, 0.0) * 12.0)) % 4, element)

static func _frame_texture(frame: int, shot_element: String = "fire") -> Texture2D:
	if not _frames.has(shot_element):
		var frames: Array[Texture2D] = []
		for index in 4:
			frames.append(_draw_frame(index, shot_element))
		_frames[shot_element] = frames
	return _frames[shot_element][frame]

static func _draw_frame(frame: int, shot_element: String = "fire") -> ImageTexture:
	var image := Image.create(40, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var red := Color("b9432e")
	var orange := Color("f4772d")
	var yellow := Color("ffd46b")
	var white := Color("fff2b8")
	if shot_element == "ice":
		red = Color("#2765b0")
		orange = Color("#55c4f4")
		yellow = Color("#a4ebff")
		white = Color("#e7fdff")
	elif shot_element == "lightning":
		red = Color("#6540a8")
		orange = Color("#ad77ff")
		yellow = Color("#dfbaff")
		white = Color("#f6eaff")
	for y in 12:
		for x in 20:
			var offset := Vector2(x + 0.5 - 14.0, y + 0.5 - 6.0)
			var radius_squared := offset.length_squared()
			var color := Color.TRANSPARENT
			if radius_squared <= 16.0:
				color = red
				if radius_squared <= 10.0: color = orange
				if radius_squared <= 5.0: color = yellow
				if radius_squared <= 2.5: color = white
			elif x >= 1 and x <= 13:
				# Two-pixel flame tongues bend independently between cached frames.
				var wave: int = [0, -1, 0, 1][(x / 3 + frame) % 4] if x < 11 else 0
				var center: int = 6 + wave
				var half_width: int = x / 4
				var distance := absi(y - center)
				if distance <= half_width:
					color = red
					if distance < half_width: color = orange
					if x >= 9 and distance == 0: color = yellow
			if color.a > 0.0:
				image.fill_rect(Rect2i(x * 2, y * 2, 2, 2), color)
	return ImageTexture.create_from_image(image)
