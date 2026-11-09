extends RefCounted
## The first two ACTUAL archived ordinary sword cuts, independently timed.
## Pose/reach/damage math is retained; rapid two-cut sequence totals .35s. No archive loads.
const ATTACKS: Array[Dictionary] = [
	{"windup": .055, "active": .050, "recovery": .045, "damage": 18.0, "reach": 2.1, "arc": 2.1},
	{"windup": .040, "active": .055, "recovery": .105, "damage": 19.0, "reach": 2.2, "arc": 2.3},
]
const EPSILON := .00000001
const REST_ANGLE := .35
var family := "sword"
var busy := false
var stage := -1
var elapsed := 0.0
var aim_angle := 0.0
var _locked_aim := 0.0

func start(index: int, angle: float) -> bool:
	if busy or index < 0 or index >= ATTACKS.size() or not is_finite(angle): return false
	stage = index
	elapsed = 0
	_locked_aim = wrapf(angle, -PI, PI)
	aim_angle = _locked_aim
	busy = true
	return true

func definition(index: int) -> Dictionary:
	return ATTACKS[index].duplicate(true) if index >= 0 and index < ATTACKS.size() else {}

func rebase_idle_aim(angle: float) -> bool:
	if busy or not is_finite(angle): return false
	_locked_aim = wrapf(angle, -PI, PI)
	aim_angle = _locked_aim
	return true

func advance(delta: float) -> Dictionary:
	var angle: float = sample().angle
	var result := {"entered_active": false, "active": false, "damage_ready": false, "finished": false, "previous_angle": angle, "current_angle": angle}
	if not busy or not is_finite(delta) or delta <= 0: return result
	var attack := definition(stage)
	var active_start: float = attack.windup
	var active_end: float = attack.windup + attack.active
	var total: float = active_end + attack.recovery
	var before := elapsed
	elapsed = minf(elapsed + delta, total)
	result.entered_active = before < active_start - EPSILON and elapsed >= active_start - EPSILON
	result.active = before < active_end - EPSILON and elapsed >= active_start - EPSILON
	result.damage_ready = result.active
	if result.active:
		result.previous_angle = _active_angle(clampf((before - active_start) / attack.active, 0, 1))
		result.current_angle = _active_angle(clampf((elapsed - active_start) / attack.active, 0, 1))
		result.trail_from = _pose_at(clampf(before, active_start, active_end))
		result.trail_to = _pose_at(clampf(elapsed, active_start, active_end))
	else:
		result.current_angle = _pose_at(elapsed).angle
	if elapsed >= total - EPSILON:
		elapsed = total
		busy = false
		result.finished = true
	return result

func sample() -> Dictionary:
	if busy: return _pose_at(elapsed)
	return _compatible({"phase": "idle", "progress": 0.0, "angle": _locked_aim + REST_ANGLE, "radius": .5, "body_lean": 0.0, "trail": false})

func _pose_at(time: float) -> Dictionary:
	var attack := ATTACKS[stage]
	var direction := -1.0 if stage == 1 else 1.0
	var start_angle: float = _locked_aim - direction * attack.arc * .5
	var end_angle: float = _locked_aim + direction * attack.arc * .5
	var phase := "windup"
	var progress := 0.0
	var angle := _locked_aim + REST_ANGLE
	var radius := .5
	var lean := 0.0
	if time < attack.windup - EPSILON:
		progress = clampf(time / attack.windup, 0, 1)
		var anticipation := _smooth(progress)
		angle = lerpf(_locked_aim + REST_ANGLE, start_angle, anticipation)
		radius = lerpf(.5, .46, anticipation)
		lean = -.04 * anticipation
	elif time < attack.windup + attack.active - EPSILON:
		phase = "active"
		progress = clampf((time - attack.windup) / attack.active, 0, 1)
		angle = _active_angle(progress)
		radius = lerpf(.46, .65, progress * progress)
		lean = .1 * progress
	else:
		phase = "recovery"
		progress = clampf((time - attack.windup - attack.active) / attack.recovery, 0, 1)
		var follow_through := end_angle + direction * .18
		if progress < .2:
			var coast := 1.0 - pow(1.0 - progress / .2, 2.0)
			angle = lerpf(end_angle, follow_through, coast)
		else:
			var settle := (progress - .2) / .8
			angle = lerpf(follow_through, _locked_aim + REST_ANGLE, _smooth(settle))
		radius = lerpf(.65, .5, _smooth(progress))
		lean = .1 * (1.0 - progress)
	return _compatible({"phase": phase, "progress": progress, "angle": angle, "radius": radius, "body_lean": lean, "trail": phase == "active"})

func _compatible(pose: Dictionary) -> Dictionary:
	# Design refinement: the old renderer placed the tip at authored reach.
	# Keep that tip orbit with today's rigid 1.9 Sword by mapping hand radius;
	# retaining the old renderer's grip radius would visibly overshoot damage.
	pose.pitch = 0.0
	pose.grip_height = .68
	pose.blade_length = 1.9
	pose.radius = maxf(0, definition(stage).get("reach", 2.1) - pose.blade_length)
	return pose

func _active_angle(progress: float) -> float:
	var direction := -1.0 if stage == 1 else 1.0
	var arc: float = definition(stage).arc
	return _locked_aim + direction * arc * (progress * progress - .5)

func _smooth(progress: float) -> float:
	return progress * progress * (3.0 - 2.0 * progress)

func is_target_hit(origin: Vector3, target: Vector3, target_radius: float, from_angle: float, to_angle: float) -> bool:
	if stage < 0 or stage >= ATTACKS.size() or not origin.is_finite() or not target.is_finite(): return false
	if not is_finite(target_radius) or target_radius < 0 or not is_finite(from_angle) or not is_finite(to_angle): return false
	var reach: float = definition(stage).reach
	var offset := Vector2(target.x - origin.x, target.z - origin.z)
	var distance := offset.length()
	if distance > reach + target_radius + EPSILON: return false
	if distance <= target_radius + EPSILON: return true
	var sweep := wrapf(to_angle - from_angle, -PI, PI)
	var target_angle := offset.angle()
	var relative := wrapf(target_angle - from_angle, 0, TAU) if sweep >= 0 else wrapf(from_angle - target_angle, 0, TAU)
	if relative <= absf(sweep) + EPSILON: return true
	var start_tip := Vector2(cos(from_angle), sin(from_angle)) * reach
	var end_tip := Vector2(cos(from_angle + sweep), sin(from_angle + sweep)) * reach
	return minf(_distance_to_edge(offset, start_tip), _distance_to_edge(offset, end_tip)) <= target_radius + EPSILON

func _distance_to_edge(point: Vector2, tip: Vector2) -> float:
	var along := clampf(point.dot(tip) / tip.length_squared(), 0, 1)
	return point.distance_to(tip * along)

func reset() -> void:
	busy = false
	stage = -1
	elapsed = 0
	aim_angle = 0
	_locked_aim = 0
