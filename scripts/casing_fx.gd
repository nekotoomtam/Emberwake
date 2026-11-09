extends Node3D
## Visual-only spent brass. The game owns tick, so a paused game freezes it.

const MAX_ACTIVE := 32
const LIFETIME := 2.0
const FADE_START := 1.4
const FLOOR_HEIGHT := 0.035
const GRAVITY := 6.0

static var _texture_cache: ImageTexture
var active: Array[Dictionary] = []
var spawned_count: int = 0

func spawn(where: Vector3, shot_direction: Vector3, camera: Camera3D) -> void:
	if not where.is_finite() or not shot_direction.is_finite() or not _valid_camera(camera):
		return
	var direction := Vector3(shot_direction.x, 0.0, shot_direction.z)
	if direction.length_squared() < 0.000001:
		return
	direction = direction.normalized()
	while active.size() >= MAX_ACTIVE:
		_remove_at(0)
	var sprite := Sprite3D.new()
	sprite.name = "spent_brass"
	sprite.texture = _texture()
	sprite.pixel_size = 0.014
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	sprite.global_position = Vector3(where.x, maxf(where.y, FLOOR_HEIGHT), where.z)
	var variation := spawned_count % 4
	var angle := float(variation) * 0.37
	sprite.global_basis = camera.global_basis * Basis(Vector3.BACK, angle)
	active.append({
		"sprite": sprite,
		"velocity": direction.cross(Vector3.UP) * (1.30 + variation * 0.08) + Vector3.UP * (1.75 + variation * 0.06) - direction * 0.12,
		"age": 0.0,
		"angle": angle,
		"spin": 8.5 + variation * 0.7,
		"bounces": 0,
		"settled": false,
	})
	spawned_count += 1

func tick(delta: float, camera: Camera3D) -> void:
	if not is_finite(delta) or delta <= 0.0 or not _valid_camera(camera):
		return
	for index in range(active.size() - 1, -1, -1):
		var entry: Dictionary = active[index]
		var sprite: Sprite3D = entry.sprite
		if not is_instance_valid(sprite):
			active.remove_at(index)
			continue
		entry.age = float(entry.age) + delta
		if float(entry.age) >= LIFETIME:
			_remove_at(index)
			continue
		if not bool(entry.settled):
			var velocity: Vector3 = entry.velocity
			sprite.global_position += velocity * delta + Vector3.DOWN * (0.5 * GRAVITY * delta * delta)
			velocity.y -= GRAVITY * delta
			if sprite.global_position.y <= FLOOR_HEIGHT:
				sprite.global_position.y = FLOOR_HEIGHT
				velocity = Vector3(velocity.x * 0.58, absf(velocity.y) * 0.28, velocity.z * 0.58)
				entry.spin = float(entry.spin) * 0.62
				entry.bounces = int(entry.bounces) + 1
				if velocity.y < 0.38:
					velocity = Vector3.ZERO
					entry.settled = true
			entry.velocity = velocity
		entry.angle = float(entry.angle) + float(entry.spin) * delta
		sprite.global_basis = camera.global_basis * Basis(Vector3.BACK, float(entry.angle))
		sprite.modulate.a = clampf((LIFETIME - float(entry.age)) / (LIFETIME - FADE_START), 0.0, 1.0)

func clear() -> void:
	for index in range(active.size() - 1, -1, -1):
		_remove_at(index)
	spawned_count = 0

func _remove_at(index: int) -> void:
	var sprite: Sprite3D = active[index].sprite
	if is_instance_valid(sprite):
		sprite.free()
	active.remove_at(index)

func _valid_camera(camera: Camera3D) -> bool:
	return is_instance_valid(camera) and camera.is_inside_tree() and camera.global_basis.is_finite()

static func _texture() -> ImageTexture:
	if _texture_cache != null:
		return _texture_cache
	var image := Image.create(12, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(2, 2, 8, 4), Color("705332"))
	image.fill_rect(Rect2i(2, 2, 6, 2), Color("ffe2a1"))
	image.fill_rect(Rect2i(2, 4, 6, 2), Color("c3a069"))
	image.fill_rect(Rect2i(8, 2, 2, 4), Color("e4bd70"))
	_texture_cache = ImageTexture.create_from_image(image)
	return _texture_cache
