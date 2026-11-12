extends RefCounted

const StaffLv15Art = preload("res://scripts/staff_lv15_art.gd")
const StaffLv20Art = preload("res://scripts/staff_lv20_art.gd")
const METEOR_START := Vector3(2.0, 6.0, -1.4)
const METEOR_CONTACT := Vector3(0, .16, 0)

var _delayed_fields: Array[Dictionary] = []
var _mana_field: Dictionary = {}
var _preview: MeshInstance3D

func show_preview(fx, center: Vector3, radius: float, color: Color, ready: bool) -> void:
	if not is_instance_valid(_preview):
		_preview = fx.sector(center, 1.0, 0.0, TAU, Color(color, .7), .97, 0.0)
	_preview.position = center + Vector3.UP * .055
	_preview.scale = Vector3(radius, 1.0, radius)
	_preview.material_override.albedo_color = Color(color, .85 if ready else .4)

func clear_preview() -> void:
	_remove_visual(_preview)
	_preview = null

func place(fx, center: Vector3, spec: Dictionary, camera: Camera3D) -> void:
	var field := spec.duplicate()
	field.center = center
	field.remaining = float(spec.duration)
	var radius: float = field.radius
	var color: Color = field.color
	var fill: MeshInstance3D = fx.sector(center + Vector3.UP * .035, radius, 0.0, TAU, Color(color, .13), 0.0, 0.0)
	field.fill = fill
	field.visuals = [fill]
	if field.has("damage"):
		field.visuals.append(fx.sector(center + Vector3.UP * .039, radius, 0.0, TAU, Color(color, .75), radius - .075, 0.0))
		if field.element == "fire":
			var meteor := Sprite3D.new()
			meteor.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			meteor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			meteor.pixel_size = .013
			fx.add_child(meteor)
			field.meteor = meteor
			field.visuals.append(meteor)
			_update_meteor(field, camera, 0.0)
		_delayed_fields.append(field)
		return
	_remove_field(_mana_field)
	var ring := Sprite3D.new()
	ring.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.pixel_size = 2.0 * radius / StaffLv15Art.RING_DIAMETER
	ring.rotation.x = -PI * .5
	fx.add_child(ring)
	ring.global_position = center + Vector3.UP * .055
	field.visuals.append(ring)
	field.ring = ring
	_mana_field = field
	_update_mana_ring()

func advance(delta: float, camera: Camera3D = null) -> Array[Dictionary]:
	if not _mana_field.is_empty():
		_mana_field.remaining -= delta
		if _mana_field.remaining <= .00000001:
			_remove_field(_mana_field)
			_mana_field = {}
		else:
			_update_mana_ring()
	var ready: Array[Dictionary] = []
	for field in _delayed_fields:
		field.remaining -= delta
		if field.remaining <= .00000001:
			_remove_field(field)
			ready.append(field)
		else:
			var progress: float = 1.0 - field.remaining / field.duration
			field.fill.material_override.albedo_color.a = lerpf(.13, .36, progress)
			if field.has("meteor"): _update_meteor(field, camera, progress)
	for field in ready: _delayed_fields.erase(field)
	return ready

func _update_mana_ring() -> void:
	var elapsed: float = _mana_field.duration - _mana_field.remaining
	var frame := int(elapsed * 8.0) % StaffLv15Art.FRAME_COUNT
	var ring: Sprite3D = _mana_field.ring
	ring.texture = StaffLv15Art.ring_frame(frame)
	ring.offset = StaffLv15Art.ring_offset(frame)
	ring.modulate.a = clampf(_mana_field.remaining / .45, .15, 1.0)

func _update_meteor(field: Dictionary, camera: Camera3D, progress: float) -> void:
	var meteor: Sprite3D = field.meteor
	meteor.global_position = field.center + METEOR_START.lerp(METEOR_CONTACT, progress * progress)
	var frame := int(progress * field.duration * 13.0) % StaffLv20Art.FRAME_COUNT
	meteor.texture = StaffLv20Art.frame(StaffLv20Art.FLIGHT, frame)
	meteor.offset = StaffLv20Art.offset_3d(StaffLv20Art.FLIGHT, frame)
	if is_instance_valid(camera):
		var direction := METEOR_CONTACT - METEOR_START
		var projected := Vector2(camera.global_basis.x.dot(direction), camera.global_basis.y.dot(direction))
		var authored_angle := Vector2(1, -.75).angle()
		meteor.global_basis = camera.global_basis * Basis(Vector3.BACK, projected.angle() - authored_angle)

func time_to_boundary() -> float:
	var time: float = INF if _mana_field.is_empty() else _mana_field.remaining
	for field in _delayed_fields: time = minf(time, field.remaining)
	return time

func mana_refund(at: Vector3) -> float:
	if _mana_field.is_empty() or not contains(_mana_field, at): return 0.0
	return float(_mana_field.refund)

static func contains(field: Dictionary, at: Vector3) -> bool:
	var gap: Vector3 = at - field.center
	return Vector2(gap.x, gap.z).length_squared() <= float(field.radius) ** 2

func clear() -> void:
	clear_preview()
	for field in _delayed_fields: _remove_field(field)
	_delayed_fields.clear()
	_remove_field(_mana_field)
	_mana_field = {}

func _remove_field(field: Dictionary) -> void:
	for visual in field.get("visuals", []): _remove_visual(visual)

func _remove_visual(visual: Node3D) -> void:
	if not is_instance_valid(visual): return
	visual.hide()
	visual.queue_free()
