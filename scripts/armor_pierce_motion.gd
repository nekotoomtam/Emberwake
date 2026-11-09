extends RefCounted
## Ordinary first slash, then one contact-timed rigid forward thrust.
const Sword = preload("res://scripts/sword_motion.gd")
const EPSILON := .00000001
const STAB := {"kind": "lunge", "windup": .10, "active": .13, "recovery": .22, "damage": 24.0, "reach": 2.25, "width": .55, "arc": 0.0, "impact_progress": .8, "lunge_distance": .65}
var family := "sword"
var busy := false
var stage := -1
var elapsed := 0.0
var aim_angle := 0.0
var _slash = Sword.new()
var _entry_pose: Dictionary = {}

func definition(index: int) -> Dictionary:
	if index == 0: return _slash.definition(0)
	return STAB.duplicate(true) if index == 1 else {}

func start(index: int, angle: float) -> bool:
	if busy or index not in [0, 1] or not is_finite(angle): return false
	_entry_pose = _slash.sample()
	stage = index
	elapsed = 0
	aim_angle = wrapf(angle, -PI, PI)
	busy = true
	if index == 0:
		_slash.reset()
		_slash.start(0, aim_angle)
	return true

func rebase_idle_aim(angle: float) -> bool:
	if busy or not is_finite(angle): return false
	aim_angle = wrapf(angle, -PI, PI)
	return true

func advance(delta: float) -> Dictionary:
	var angle: float = sample().angle
	var result := {"entered_active": false, "active": false, "damage_ready": false, "finished": false, "previous_angle": angle, "current_angle": angle, "trail_from": {}, "trail_to": {}}
	if not busy or not is_finite(delta) or delta <= 0: return result
	if stage == 0:
		result = _slash.advance(delta)
		elapsed = _slash.elapsed
		busy = _slash.busy
		return result
	var before := elapsed
	var total: float = STAB.windup + STAB.active + STAB.recovery
	elapsed = minf(elapsed + delta, total)
	var contact_time: float = STAB.windup + STAB.active * STAB.impact_progress
	result.entered_active = before < STAB.windup - EPSILON and elapsed >= STAB.windup - EPSILON
	result.active = before < STAB.windup + STAB.active - EPSILON and elapsed >= STAB.windup - EPSILON
	result.damage_ready = before < contact_time - EPSILON and elapsed >= contact_time - EPSILON
	result.previous_angle = aim_angle
	result.current_angle = aim_angle
	if result.active:
		result.trail_from = _stab_pose(clampf(before, STAB.windup, STAB.windup + STAB.active))
		result.trail_to = _stab_pose(clampf(elapsed, STAB.windup, STAB.windup + STAB.active))
	if result.damage_ready: result.contact_pose = _stab_pose(contact_time)
	if elapsed >= total - EPSILON:
		elapsed = total
		busy = false
		result.finished = true
	return result

func sample() -> Dictionary:
	if stage == 0: return _slash.sample()
	if stage == 1: return _stab_pose(elapsed)
	var pose := _slash.sample()
	pose.lunge_offset = 0.0
	return pose

func _stab_pose(time: float) -> Dictionary:
	var pose := {"phase": "windup", "progress": 0.0, "angle": aim_angle, "radius": .15, "pitch": 0.0, "grip_height": .68, "blade_length": 1.9, "body_lean": -.025, "trail": false, "lunge_offset": 0.0}
	if time < STAB.windup - EPSILON:
		pose.progress = clampf(time / STAB.windup, 0, 1)
		var preparation: float = pose.progress * pose.progress * (3 - 2 * pose.progress)
		pose.angle = lerp_angle(_entry_pose.get("angle", aim_angle + .35), aim_angle, preparation)
		pose.radius = lerpf(_entry_pose.get("radius", .3), .15, preparation)
	elif time < STAB.windup + STAB.active - EPSILON:
		pose.phase = "active"
		pose.progress = clampf((time - STAB.windup) / STAB.active, 0, 1)
		var extension := clampf(pose.progress / float(STAB.impact_progress), 0, 1)
		pose.radius = lerpf(.15, .35, extension)
		pose.body_lean = lerpf(-.025, .075, extension)
		pose.lunge_offset = .65 * extension
		pose.trail = true
	else:
		pose.phase = "recovery"
		pose.progress = clampf((time - STAB.windup - STAB.active) / STAB.recovery, 0, 1)
		pose.radius = lerpf(.35, .3, pose.progress)
		pose.angle = aim_angle + .35 * pose.progress
		pose.body_lean = .075 * (1 - pose.progress)
		pose.lunge_offset = .65
	return pose

func is_target_hit(origin: Vector3, target: Vector3, target_radius: float, from_angle: float, to_angle: float) -> bool:
	if stage not in [0, 1] or not origin.is_finite() or not target.is_finite() or not is_finite(target_radius) or target_radius < 0 or not is_finite(from_angle) or not is_finite(to_angle): return false
	var offset := Vector2(target.x - origin.x, target.z - origin.z)
	var attack := definition(stage)
	if stage == 0:
		var reach: float = attack.reach
		if offset.length() > reach + target_radius + EPSILON: return false
		if offset.length() <= target_radius + EPSILON: return true
		var sweep := wrapf(to_angle - from_angle, -PI, PI)
		var relative := wrapf(offset.angle() - from_angle, 0, TAU) if sweep >= 0 else wrapf(from_angle - offset.angle(), 0, TAU)
		if relative <= absf(sweep) + EPSILON: return true
		var first := Vector2(cos(from_angle), sin(from_angle)) * reach
		var last := Vector2(cos(from_angle + sweep), sin(from_angle + sweep)) * reach
		return minf(offset.distance_to(Geometry2D.get_closest_point_to_segment(offset, Vector2.ZERO, first)), offset.distance_to(Geometry2D.get_closest_point_to_segment(offset, Vector2.ZERO, last))) <= target_radius + EPSILON
	var direction := Vector2(cos(aim_angle), sin(aim_angle))
	var along := offset.dot(direction)
	var across := offset.dot(Vector2(-direction.y, direction.x))
	var nearest := Vector2(clampf(along, 0, STAB.reach), clampf(across, -float(STAB.width) * .5, float(STAB.width) * .5))
	return Vector2(along, across).distance_to(nearest) <= target_radius + EPSILON

func reset() -> void:
	busy = false
	stage = -1
	elapsed = 0
	aim_angle = 0
	_slash.reset()
	_entry_pose.clear()
