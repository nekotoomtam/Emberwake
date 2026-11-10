extends Node3D
## One ambush at a time. The locked ground lane drives both the tell and impact.

const WINDUP := .78
const STRIKE := .12
const RECOVERY := .92
const HALF_WIDTH := .48
const TRIGGER_REACH := 4.3
const SEGMENTS := 11

var _edges := PackedVector2Array()
var _outline := PackedVector2Array()
var _rng := RandomNumberGenerator.new()
var _retry := .45
var _elapsed := -1.0
var _draw_left := 0.0
var _origin := Vector3.ZERO
var _forward := Vector3.FORWARD
var _length := 0.0
var _can_hurt := false
var _segments: Array[MeshInstance3D] = []
var _lane: MeshInstance3D


func setup(outline: PackedVector2Array, seed_: int) -> void:
	_rng.seed = seed_
	_outline = outline
	for i in outline.size():
		var start := outline[i]
		var end := outline[(i + 1) % outline.size()]
		var count := maxi(1, ceili(start.distance_to(end) / 1.8))
		for j in count:
			var point := start.lerp(end, (j + .5) / count)
			if minf(absf(point.x), absf(point.y)) >= 1.5:
				_edges.append(point)
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color("#60433f")
	bark.roughness = .94
	for i in SEGMENTS:
		var piece := CylinderMesh.new()
		piece.radial_segments = 7
		piece.rings = 1
		piece.height = 1.0
		piece.bottom_radius = lerpf(.27, .025, float(i) / SEGMENTS)
		piece.top_radius = lerpf(.27, .025, float(i + 1) / SEGMENTS)
		var segment := _mesh(piece, bark)
		_segments.append(segment)
	var tell := StandardMaterial3D.new()
	tell.albedo_color = Color(.69, .38, .78, .38)
	tell.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tell.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lane = _mesh(BoxMesh.new(), tell)
	hide()


func tick(delta: float, game) -> void:
	if _elapsed < 0.0:
		_retry = maxf(0.0, _retry - delta)
		var velocity: Vector3 = game.player.velocity
		if _retry > 0.0 or Vector2(velocity.x, velocity.z).length_squared() < .1:
			return
		_retry = _rng.randf_range(.85, 1.45)
		_try_ambush(game.player.global_position)
		if _elapsed < 0.0:
			return
		_can_hurt = game.has_sanity_revelation()
		_present(_can_hurt)
		return

	var previous := _elapsed
	_elapsed += delta
	var sees_root: bool = game.has_sanity_revelation()
	if previous < WINDUP + STRIKE and _elapsed >= WINDUP + STRIKE and sees_root and _can_hurt:
		if _contains(game.player.global_position):
			game.damage_player(14.0, Vector3.INF, 1.0, "physical", "torso", -1.0, false, &"area")
	if _elapsed >= WINDUP + STRIKE + RECOVERY:
		_finish()
		return
	_draw_left -= delta
	if _draw_left <= 0.0 or visible != sees_root:
		_present(sees_root)


func _try_ambush(target: Vector3) -> void:
	var point := Vector2(target.x, target.z)
	var candidates := PackedVector2Array()
	for edge in _edges:
		var distance := edge.distance_squared_to(point)
		if distance >= .8 * .8 and distance <= TRIGGER_REACH * TRIGGER_REACH and Geometry2D.is_point_in_polygon(edge.lerp(point, .25), _outline):
			candidates.append(edge)
	if candidates.is_empty() or _rng.randf() > .68:
		return
	var edge := candidates[_rng.randi_range(0, candidates.size() - 1)]
	_origin = Vector3(edge.x, 0.0, edge.y)
	var direction := Vector3(target.x, 0.0, target.z) - _origin
	_forward = direction.normalized()
	_length = direction.length() + .65
	_elapsed = 0.0
	_lane.position = to_local(_origin + _forward * (_length * .5) + Vector3.UP * .064)
	_lane.rotation.y = atan2(_forward.x, _forward.z)
	_lane.scale = Vector3(HALF_WIDTH * 2.0, .018, _length)


func _contains(point: Vector3) -> bool:
	var offset := point - _origin
	offset.y = 0.0
	var along := offset.dot(_forward)
	return along >= 0.0 and along <= _length and absf(offset.dot(_forward.cross(Vector3.UP))) <= HALF_WIDTH


func try_melee(origin: Vector3, motion, from_angle: float, to_angle: float) -> bool:
	if _elapsed < WINDUP + STRIKE:
		return false
	for i in range(1, SEGMENTS + 1):
		var target := _origin + _forward * (_length * float(i) / SEGMENTS)
		if motion.is_target_hit(origin, target, .29, from_angle, to_angle):
			_finish()
			return true
	return false


func mark_point(point: Vector3) -> Vector3:
	if not visible:
		return point
	var target := _origin + _forward * clampf((point - _origin).dot(_forward), 0.0, _length)
	return target if target.distance_squared_to(point) < 1.0 else point


func _finish() -> void:
	_elapsed = -1.0
	_retry = _rng.randf_range(3.0, 5.0)
	hide()


func _present(revealed: bool) -> void:
	visible = revealed
	_draw_left = 1.0 / 30.0
	if not revealed:
		return
	_lane.visible = _elapsed < WINDUP + STRIKE
	var lift := smoothstep(0.0, WINDUP * .85, _elapsed)
	lift *= 1.0 - smoothstep(WINDUP, WINDUP + STRIKE, _elapsed)
	var retract := smoothstep(WINDUP + STRIKE + RECOVERY * .63, WINDUP + STRIKE + RECOVERY, _elapsed)
	var previous := _root_point(0.0, lift, retract)
	for i in SEGMENTS:
		var point := _root_point(float(i + 1) / SEGMENTS, lift, retract)
		var offset := point - previous
		var segment := _segments[i]
		segment.position = to_local((point + previous) * .5)
		segment.quaternion = Quaternion(Vector3.UP, offset.normalized())
		segment.scale = Vector3(1.0, offset.length() + .045, 1.0)
		previous = point


func _root_point(u: float, lift: float, retract: float) -> Vector3:
	var curl := sin(u * 4.7 - _elapsed * 2.6) * u * lift
	var emerge := smoothstep(0.0, WINDUP * .52, _elapsed)
	var spread := lerpf(.18, 1.0, emerge) * (1.0 - retract * .98) * (1.0 - lift * .33)
	var height := lerpf(-.10, .12, emerge) - retract * .24
	height += lift * (sin(u * 2.4) * 1.55 + curl * .38)
	return _origin + _forward * (_length * u * spread) + _forward.cross(Vector3.UP) * curl * .55 + Vector3.UP * height


func _mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance
