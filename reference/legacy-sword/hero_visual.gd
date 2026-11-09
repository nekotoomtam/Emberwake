extends Node3D
const Art = preload("res://scripts/pixel_art.gd")
const GreatArt = preload("res://scripts/greatsword_art.gd")
const MaceArt = preload("res://scripts/mace_art.gd")
const StaffArt = preload("res://scripts/staff_art.gd")
const PistolArt = preload("res://scripts/pistol_art.gd")
const RifleArt = preload("res://scripts/rifle_art.gd")
const PIXEL: float = 0.018
var body: AnimatedSprite3D
var weapon: Sprite3D
var hand: Node3D
var clock: float = 0.0
var weapon_family: String = "sword"
var _weapon_pivot := Vector2(12, 8)
var _weapon_tip := Vector2(60, 8)
var _blade_depth := Vector3.ZERO

func _ready() -> void:
	body = AnimatedSprite3D.new()
	body.sprite_frames = Art.frames("player")
	body.pixel_size = PIXEL
	body.position.y = 48 * PIXEL
	body.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	body.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	body.shaded = false
	body.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	var shadow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.38
	disc.bottom_radius = 0.38
	disc.height = 0.007
	disc.radial_segments = 20
	shadow.mesh = disc
	shadow.position.y = 0.015
	var shade := StandardMaterial3D.new()
	shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shade.albedo_color = Color(0.03, 0.07, 0.11, 0.45)
	shadow.material_override = shade
	add_child(shadow)
	hand = Node3D.new()
	add_child(hand)
	weapon = Sprite3D.new()
	weapon.pixel_size = 0.032
	_apply_weapon_art()
	weapon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	weapon.shaded = false
	weapon.no_depth_test = true
	weapon.render_priority = 4
	hand.add_child(weapon)

func set_weapon_family(id: String) -> bool:
	if id not in ["sword", "greatsword", "mace", "staff", "pistol", "rifle"]:
		return false
	weapon_family = id
	if weapon != null:
		_apply_weapon_art()
	return true

func _apply_weapon_art() -> void:
	if weapon_family in ["greatsword", "mace", "staff", "pistol", "rifle"]:
		var art: Script = RifleArt if weapon_family == "rifle" else (PistolArt if weapon_family == "pistol" else (StaffArt if weapon_family == "staff" else (MaceArt if weapon_family == "mace" else GreatArt)))
		weapon.texture = art.texture()
		var geometry: Dictionary = art.geometry()
		_weapon_pivot = geometry.pivot
		_weapon_tip = geometry.tip
		var size := weapon.texture.get_size()
		weapon.offset = Vector2(size.x * 0.5 - _weapon_pivot.x, _weapon_pivot.y - size.y * 0.5)
	else:
		weapon.texture = Art.sword_texture()
		weapon.offset = Vector2(20, -2)
		_weapon_pivot = Vector2(12, 8)
		_weapon_tip = Vector2(60, 8)

func get_blade_points() -> Dictionary:
	# Read the actual transformed sprite axes. The billboard omits only depth;
	# restore that physical component for effects and world-space diagnostics.
	return {"grip": _texture_point_world(_weapon_pivot), "tip": _texture_point_world(_weapon_tip) + _blade_depth}

func _texture_point_world(point: Vector2) -> Vector3:
	var size := weapon.texture.get_size()
	var local := Vector3(point.x - size.x * 0.5 + weapon.offset.x, size.y * 0.5 - point.y + weapon.offset.y, 0.0) * weapon.pixel_size
	return weapon.global_transform * local

func update_pose(camera: Camera3D, aim: Vector3, walking: bool, sample: Dictionary, reach: float, hurt: float, dodge: float, delta: float, dead: bool = false) -> void:
	clock += delta
	var phase: String = sample.get("phase", "idle")
	var facing_left: bool = camera.global_basis.x.dot(aim) < -0.05
	body.flip_h = facing_left
	var animation: String = "death" if dead else ("hit" if hurt > 0.0 else ("attack" if phase != "idle" else ("walk" if walking else "idle")))
	if body.animation != animation:
		body.animation = animation
		if animation == "death": clock = 0
	if animation in ["walk", "idle"]:
		body.frame = int(clock * (10.0 if walking else 2.0)) % body.sprite_frames.get_frame_count(animation)
	elif animation == "attack":
		body.frame = {"windup": 0, "active": 1, "recovery": 2}.get(phase, 0) % body.sprite_frames.get_frame_count(animation)
	elif dead:
		body.frame = mini(2, int(clock * 3.0))
	body.modulate = Color(1.0, 0.48, 0.45) if hurt > 0.0 else (Color(0.6, 1.0, 1.0, 0.6) if dodge > 0.0 else Color.WHITE)
	var squash: float = 0.06 if phase == "windup" else (-0.04 if phase == "active" else 0.0)
	var lean: float = float(sample.get("body_lean", 0.0)) * (1.0 if facing_left else -1.0)
	body.global_basis = camera.global_basis * Basis(Vector3.BACK, lean)
	body.scale = Vector3(1.0 + squash, 1.0 - squash, 1.0)
	# Put the baseline on the ground before leaning; the visible feet are the pivot.
	body.global_position = global_position + body.global_basis.y * (48 * PIXEL) + camera.global_basis.y * (0.025 * sin(clock * 17.0) if walking else 0.0)
	weapon.visible = not dead
	var angle: float = float(sample.get("angle", atan2(aim.z, aim.x)))
	var direction := Vector3(cos(angle), 0, sin(angle))
	var radius: float = float(sample.get("radius", 0.42 if weapon_family == "rifle" else 0.48))
	if weapon_family in ["greatsword", "mace", "staff", "pistol", "rifle"]:
		var pitch: float = float(sample.get("pitch", 0.0))
		var grip_height: float = float(sample.get("grip_height", 0.80 if weapon_family in ["pistol", "rifle"] else 0.68))
		var blade_length: float = float(sample.get("blade_length", 1.35 if weapon_family == "rifle" else (0.72 if weapon_family == "pistol" else reach - radius)))
		var blade_vector := direction * cos(pitch) + Vector3.UP * sin(pitch)
		hand.global_transform = Transform3D(camera.global_basis, global_position + direction * radius + Vector3.UP * grip_height)
		var projected := Vector2(camera.global_basis.x.dot(blade_vector), camera.global_basis.y.dot(blade_vector))
		weapon.rotation.z = atan2(projected.y, projected.x)
		# Spin the already projected gun in the screen plane. The image offset
		# places the tiny hand exactly at this origin, so no orbit is introduced.
		if weapon_family == "pistol":
			weapon.rotation.z += float(sample.get("screen_roll", 0.0))
		weapon.pixel_size = blade_length / (_weapon_tip.x - _weapon_pivot.x)
		# This removes only the camera-depth component. Pitch changes the rigid
		# blade's projection rather than inventing a shorter physical weapon.
		weapon.scale = Vector3(projected.length(), 1.0, 1.0)
		_blade_depth = camera.global_basis.z * camera.global_basis.z.dot(blade_vector) * blade_length
	else:
		hand.global_transform = Transform3D(camera.global_basis, global_position + direction * radius + Vector3(0, 0.68, 0))
		var projected := Vector2(camera.global_basis.x.dot(direction), camera.global_basis.y.dot(direction))
		weapon.rotation.z = atan2(projected.y, projected.x)
		weapon.pixel_size = (reach - radius) / 48.0
		weapon.scale = Vector3(projected.length(), 1.0, 1.0)
		_blade_depth = camera.global_basis.z * camera.global_basis.z.dot(direction) * (reach - radius)
	weapon.modulate = Color("#ffe3a0") if phase == "active" else Color.WHITE
