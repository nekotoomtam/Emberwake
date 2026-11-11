extends Sprite3D
## A painted contact flash, with an expanding ground ring for the styles that use one.

const ART := preload("res://assets/combat/mace_impact_shockwave.png")
const FRACTURE_ART := preload("res://assets/combat/mace_double_impact_flash.png")
const BLUNT_ART := preload("res://assets/combat/mace_basic_blunt_impact.png")
const BLUNT_REGION := Rect2(268, 355, 1000, 500)
const BLUNT_WIDTH := 975.0
const ART_RADIUS := 615.0
const FRACTURE_RADIUS := 546.0
const EXPANSION_TIME := .10
const LIFETIME := .32
enum Style { STANDARD, BASIC, DOUBLE_START, DOUBLE_FINISHER }

static var _glow_texture: GradientTexture2D
var age := 0.0
var _opacity := .92
var _lifetime := LIFETIME
var _expansion_time := EXPANSION_TIME
var _strike_center := Vector3.ZERO
var _flash_center := Vector3.ZERO
var _floor_glow: MeshInstance3D
var _floor_glow_material: StandardMaterial3D
var _glow_peak := 0.0
var _blunt_flash: Sprite3D

func configure(center: Vector3, radius: float, style: Style = Style.STANDARD) -> void:
	texture = ART
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pixel_size = radius / ART_RADIUS
	offset = Vector2(-1, -1)
	_place_on_floor(center)
	match style:
		Style.BASIC:
			texture = null
			_lifetime = .23
			_add_floor_glow(radius * .78, .56)
		Style.DOUBLE_START:
			_opacity = .85
			_lifetime = .26
			_add_floor_glow(radius, .60)
		Style.DOUBLE_FINISHER:
			texture = FRACTURE_ART
			pixel_size = radius / FRACTURE_RADIUS
			offset = Vector2(4, -16)
			_opacity = .96
			_lifetime = .37
			_expansion_time = .12
			_add_floor_glow(radius, .84)
		Style.STANDARD:
			_add_floor_glow(radius, .62)
	_add_blunt_flash(radius)
	_update_frame()

func _add_blunt_flash(radius: float, ember: bool = false) -> void:
	var flash_radius := radius if ember else clampf(radius * .66, .88, 1.08)
	_blunt_flash = Sprite3D.new()
	_blunt_flash.texture = BLUNT_ART
	_blunt_flash.region_enabled = true
	_blunt_flash.region_rect = BLUNT_REGION
	_blunt_flash.offset = Vector2(0, 218)
	_blunt_flash.pixel_size = flash_radius * 2.0 / BLUNT_WIDTH
	_blunt_flash.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_blunt_flash.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_blunt_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blunt_flash.no_depth_test = true
	_blunt_flash.render_priority = 1
	if ember:
		_blunt_flash.modulate = Color("#ffb36d")
	add_child(_blunt_flash)

func configure_ember_contact(center: Vector3, radius: float) -> void:
	_place_on_floor(center)
	_lifetime = .24
	_add_floor_glow(radius, .83)
	_add_blunt_flash(radius, true)
	_update_frame()

func configure_contact(center: Vector3, radius: float, strength: float) -> void:
	_place_on_floor(center)
	_opacity = 0.0
	_lifetime = .20
	_add_floor_glow(radius, strength)
	_add_blunt_flash(radius)
	_update_frame()

func _place_on_floor(center: Vector3) -> void:
	rotation.x = -PI * .5
	_strike_center = center + Vector3.UP * .065
	_flash_center = _strike_center

func _add_floor_glow(radius: float, strength: float) -> void:
	_glow_peak = strength
	if _glow_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, .19, .53, 1.0])
		gradient.colors = PackedColorArray([Color(1.0, .89, .62, 1.0),
			Color(1.0, .65, .25, .78), Color(.94, .39, .13, .36), Color(.82, .22, .06, 0.0)])
		_glow_texture = GradientTexture2D.new()
		_glow_texture.width = 128
		_glow_texture.height = 128
		_glow_texture.gradient = gradient
		_glow_texture.fill = GradientTexture2D.FILL_RADIAL
		_glow_texture.fill_from = Vector2(.5, .5)
		_glow_texture.fill_to = Vector2(1.0, .5)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * radius * 2.45
	_floor_glow_material = StandardMaterial3D.new()
	_floor_glow_material.albedo_texture = _glow_texture
	_floor_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_floor_glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_floor_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_floor_glow = MeshInstance3D.new()
	_floor_glow.mesh = quad
	_floor_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_floor_glow.material_override = _floor_glow_material
	_floor_glow.position.z = -.014
	add_child(_floor_glow)

func align_flash(head: Vector3, view: Vector3) -> void:
	if age > .05 or absf(view.y) < .001: return
	# Put the first flash under the visible head in camera space, then settle
	# the expanded ring on the damage center without moving the hit area.
	_flash_center = head + view * ((_strike_center.y - head.y) / view.y)
	_update_frame()

func tick(delta: float) -> bool:
	age = minf(age + delta, _lifetime)
	_update_frame()
	return age < _lifetime

func _update_frame() -> void:
	var spread := lerpf(.29, 1.0, ease(clampf(age / _expansion_time, 0.0, 1.0), .55))
	var fade := 1.0 - smoothstep(.09, _lifetime, age)
	position = _flash_center.lerp(_strike_center, smoothstep(.018, _expansion_time, age))
	scale = Vector3(spread, spread, 1.0)
	modulate.a = _opacity * fade
	if _floor_glow != null:
		var glow_spread := lerpf(.70, 1.0, smoothstep(0.0, .11, age)) / spread
		_floor_glow.scale = Vector3(glow_spread, glow_spread, 1.0)
		_floor_glow_material.albedo_color.a = _glow_peak * (1.0 - smoothstep(.025, .20, age))
		_floor_glow.visible = age < .20
	if _blunt_flash != null:
		var opening := smoothstep(0.0, .075, age)
		_blunt_flash.scale = Vector3(lerpf(.52, 1.0, opening), lerpf(.66, 1.0, opening), 1.0) / spread
		_blunt_flash.modulate.a = .96 * (1.0 - smoothstep(.033, .19, age))
