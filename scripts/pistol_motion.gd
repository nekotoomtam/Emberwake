extends RefCounted
## One committed physical shot. The caller owns ammunition, reload and flight.
## The attached hand stays fixed; only a small barrel lift follows the release.

const WEAPON_LENGTH := 0.72
const RECOIL_PITCH := 0.10
const ATTACK := {
	"kind": "projectile", "element": "physical",
	"windup": 0.065, "active": 0.055, "recovery": 0.30,
	"damage": 18.0, "reach": 7.0, "arc": 0.0,
	"projectile_range": 7.0, "projectile_speed": 18.0,
	"projectile_radius": 0.10, "knockback": 0.8,
	"magazine_capacity": 10, "reload_time": 0.5,
}

var busy := false
var stage := -1
var elapsed := 0.0
var aim_angle := 0.0
var _locked_aim := 0.0
var _released := false

func reset() -> void:
	busy = false
	stage = -1
	elapsed = 0.0
	aim_angle = 0.0
	_locked_aim = 0.0
	_released = false

func rebase_idle_aim(angle: float) -> bool:
	if busy or not is_finite(angle):
		return false
	_locked_aim = wrapf(angle, -PI, PI)
	aim_angle = _locked_aim
	return true

func start(index: int, angle: float) -> bool:
	if busy or index != 0 or not is_finite(angle):
		return false
	stage = 0
	elapsed = 0.0
	_locked_aim = wrapf(angle, -PI, PI)
	aim_angle = _locked_aim
	_released = false
	busy = true
	return true

func definition(index: int) -> Dictionary:
	return ATTACK.duplicate(true) if index == 0 else {}

func advance(delta: float) -> Dictionary:
	var angle: float = sample().angle
	var result := {
		"entered_active": false, "active": false, "damage_ready": false,
		"projectile_ready": false, "finished": false,
		"previous_angle": angle, "current_angle": angle,
		"release_pose": {}, "contact_pose": {},
	}
	if not busy or not is_finite(delta) or delta <= 0.0:
		return result
	var active_start: float = ATTACK.windup
	var active_end: float = active_start + ATTACK.active
	var total: float = active_end + ATTACK.recovery
	var before := elapsed
	elapsed = minf(elapsed + delta, total)
	result.active = before < active_end and elapsed >= active_start
	if not _released and elapsed >= active_start:
		_released = true
		result.entered_active = true
		result.projectile_ready = true
		# Consumers always receive the exact muzzle pose at release, even when
		# this step ends during recovery or beyond the complete shot.
		result.release_pose = _pose_at(active_start)
	if elapsed >= total:
		elapsed = total
		busy = false
		result.finished = true
	return result

func sample() -> Dictionary:
	return _pose_at(elapsed) if busy else _rest_pose()

func is_target_hit(_origin: Vector3, _target: Vector3, _target_radius: float, _from_angle: float, _to_angle: float) -> bool:
	return false

func _rest_pose() -> Dictionary:
	return {
		"phase": "idle", "progress": 0.0, "angle": _locked_aim,
		"radius": 0.48, "pitch": 0.0, "grip_height": 0.80,
		"blade_length": WEAPON_LENGTH, "body_lean": 0.0,
		"trail": false, "lunge_offset": 0.0,
	}

func _pose_at(time: float) -> Dictionary:
	var pose := _rest_pose()
	var active_start: float = ATTACK.windup
	var active_end: float = active_start + ATTACK.active
	if time < active_start:
		pose.phase = "windup"
		pose.progress = clampf(time / active_start, 0.0, 1.0)
	elif time < active_end:
		pose.phase = "active"
		pose.progress = clampf((time - active_start) / ATTACK.active, 0.0, 1.0)
		pose.pitch = RECOIL_PITCH * _smooth(pose.progress)
	else:
		pose.phase = "recovery"
		pose.progress = clampf((time - active_end) / ATTACK.recovery, 0.0, 1.0)
		pose.pitch = RECOIL_PITCH * (1.0 - _smooth(pose.progress))
	return pose

func _smooth(progress: float) -> float:
	return progress * progress * (3.0 - 2.0 * progress)
