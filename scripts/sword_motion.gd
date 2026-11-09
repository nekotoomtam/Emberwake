extends RefCounted
## Compact ordinary cuts. The blade stays rigid and its active ground tip
## follows the authored damage reach, including the descending third cut.

const EPSILON := 0.00000001
const BLADE_LENGTH := 1.9
const GRIP_HEIGHT := 0.68
const REST_ANGLE := 0.35
const REST_RADIUS := 0.3
const ATTACKS: Array[Dictionary] = [
	{"windup": 0.13, "active": 0.11, "recovery": 0.18, "damage": 18.0, "reach": 2.1, "arc": 1.35},
	{"windup": 0.14, "active": 0.12, "recovery": 0.20, "damage": 19.0, "reach": 2.2, "arc": 1.45},
	{"windup": 0.25, "active": 0.16, "recovery": 0.28, "damage": 34.0, "reach": 2.55, "arc": 1.55},
]

var busy := false
var stage := -1
var elapsed := 0.0
var aim_angle := 0.0
var _locked_aim := 0.0
var _entry_pose: Dictionary = {}
var _held_pose: Dictionary = {}

func start(index: int, angle: float) -> bool:
	if busy or index < 0 or index >= ATTACKS.size() or not is_finite(angle):
		return false
	stage = index
	elapsed = 0.0
	_locked_aim = wrapf(angle, -PI, PI)
	aim_angle = _locked_aim
	_entry_pose = _rest_pose(_locked_aim) if _held_pose.is_empty() else _held_pose.duplicate(true)
	busy = true
	return true

func definition(index: int) -> Dictionary:
	return {} if index < 0 or index >= ATTACKS.size() else ATTACKS[index].duplicate(true)

func advance(delta: float) -> Dictionary:
	var angle: float = sample().angle
	var result := {
		"entered_active": false, "active": false, "damage_ready": false,
		"finished": false, "previous_angle": angle, "current_angle": angle,
		"trail_from": {}, "trail_to": {},
	}
	if not busy or not is_finite(delta) or delta <= 0.0:
		return result
	var attack := definition(stage)
	var active_start: float = attack.windup
	var active_end: float = active_start + attack.active
	var total: float = active_end + attack.recovery
	var before := elapsed
	elapsed = minf(elapsed + delta, total)
	result.entered_active = before < active_start - EPSILON and elapsed >= active_start - EPSILON
	result.active = before < active_end - EPSILON and elapsed >= active_start - EPSILON
	result.damage_ready = result.active
	if result.active:
		# The frame may span windup, all of active, and recovery. Carry the
		# actual active blade endpoints rather than the frame's idle poses.
		result.trail_from = _active_pose(clampf((before - active_start) / attack.active, 0.0, 1.0))
		result.trail_to = _active_pose(clampf((elapsed - active_start) / attack.active, 0.0, 1.0))
		result.previous_angle = result.trail_from.angle
		result.current_angle = result.trail_to.angle
	else:
		result.current_angle = _pose_at(elapsed).angle
	if elapsed >= total - EPSILON:
		elapsed = total
		_held_pose = _pose_at(total)
		busy = false
		result.finished = true
	return result

func sample() -> Dictionary:
	if busy:
		return _pose_at(elapsed)
	var pose := _rest_pose(_locked_aim) if _held_pose.is_empty() else _held_pose.duplicate(true)
	pose.phase = "idle"
	pose.progress = 0.0
	pose.trail = false
	return pose

func _rest_pose(angle: float) -> Dictionary:
	return {"phase": "idle", "progress": 0.0, "angle": angle + REST_ANGLE, "radius": REST_RADIUS, "pitch": 0.0, "grip_height": GRIP_HEIGHT, "blade_length": BLADE_LENGTH, "body_lean": 0.0, "trail": false}

func _pose_at(time: float) -> Dictionary:
	var attack := ATTACKS[stage]
	if time < attack.windup - EPSILON:
		var pose := _rest_pose(_locked_aim)
		pose.phase = "windup"
		pose.progress = clampf(time / attack.windup, 0.0, 1.0)
		var anticipation := _smooth(pose.progress)
		var prepared := _active_pose(0.0)
		pose.angle = lerp_angle(_entry_pose.angle, prepared.angle, anticipation)
		pose.radius = lerpf(_entry_pose.radius, prepared.radius, anticipation)
		pose.pitch = lerpf(_entry_pose.pitch, prepared.pitch, anticipation)
		pose.grip_height = lerpf(_entry_pose.grip_height, GRIP_HEIGHT, anticipation)
		pose.body_lean = lerpf(_entry_pose.body_lean, prepared.body_lean, anticipation)
		return pose
	if time < attack.windup + attack.active - EPSILON:
		return _active_pose(clampf((time - attack.windup) / attack.active, 0.0, 1.0))
	var pose := _active_pose(1.0)
	pose.phase = "recovery"
	pose.progress = clampf((time - attack.windup - attack.active) / attack.recovery, 0.0, 1.0)
	pose.trail = false
	var settle := _smooth(pose.progress)
	var coast := 1.0 - pow(1.0 - minf(pose.progress / 0.25, 1.0), 2.0)
	# Retain the side reached by the cut, ready for its reverse. Recovery
	# relaxes the wrist and grip without making a second damaging sweep.
	pose.angle += _direction() * 0.1 * coast
	pose.radius = lerpf(pose.radius, REST_RADIUS, settle)
	pose.pitch = lerpf(pose.pitch, 0.0, settle)
	pose.body_lean *= 1.0 - settle
	return pose

func _active_pose(progress: float) -> Dictionary:
	var attack := ATTACKS[stage]
	var pose := _rest_pose(_locked_aim)
	var release := progress * progress
	pose.phase = "active"
	pose.progress = progress
	pose.angle = _locked_aim + _direction() * attack.arc * (release - 0.5)
	pose.pitch = lerpf(0.32, -0.24, release) if stage == 2 else 0.0
	pose.radius = attack.reach - cos(pose.pitch) * BLADE_LENGTH
	pose.body_lean = lerpf(-0.025, 0.045, progress)
	pose.trail = true
	return pose

func _direction() -> float:
	# Actor right is forward.cross(UP), independent of the camera.
	return 1.0 if stage == 1 else -1.0

func rebase_idle_aim(new_angle: float) -> bool:
	if busy or not is_finite(new_angle):
		return false
	var next_aim := wrapf(new_angle, -PI, PI)
	var turn := wrapf(next_aim - _locked_aim, -PI, PI)
	_locked_aim = next_aim
	aim_angle = next_aim
	if not _held_pose.is_empty():
		_held_pose.angle += turn
	return true

func reset() -> void:
	busy = false
	stage = -1
	elapsed = 0.0
	aim_angle = 0.0
	_locked_aim = 0.0
	_entry_pose.clear()
	_held_pose.clear()

func _smooth(progress: float) -> float:
	return progress * progress * (3.0 - 2.0 * progress)
