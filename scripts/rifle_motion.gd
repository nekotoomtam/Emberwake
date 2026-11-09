extends RefCounted
## One committed rifle shot. The caller owns ammunition, reload and flight.
## recoil_offset is a cumulative backward budget; only the caller moves actors.

const WEAPON_LENGTH := 1.35
const RECOIL_PITCH := 0.13
const ATTACK := {
	"kind": "projectile", "element": "physical",
	"projectile_visual": "rifle",
	"windup": 0.16, "active": 0.08, "recovery": 0.66,
	"damage": 52.0, "reach": 9.0, "arc": 0.0,
	"projectile_range": 9.0, "projectile_speed": 22.0,
	"projectile_radius": 0.10, "knockback": 2.0,
	"magazine_capacity": 5, "reload_time": 1.2,
	"pierce_after_exit": 0.55,
	"recoil_distance": 0.22, "recoil_duration": 0.12,
}

var aimed:=false
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
	_released = false
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

func configure_aim(value: bool) -> void:aimed=value
func definition(index: int) -> Dictionary:
	if index!=0:return {}
	var result:=ATTACK.duplicate(true)
	result.windup=.20 if aimed else .16;result.recovery=.92 if aimed else .66
	result.projectile_range=12.0 if aimed else 9.0;result.reach=result.projectile_range
	result.rifle_aimed=aimed
	result.pierce_after_exit=12.0 if aimed else .55
	result.max_targets=4 if aimed else 0
	return result

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
	var spec:=definition(0)
	var active_start: float = spec.windup
	var active_end: float = active_start + spec.active
	var total: float = active_end + spec.recovery
	var before := elapsed
	elapsed = minf(elapsed + delta, total)
	result.active = before < active_end and elapsed >= active_start
	if not _released and elapsed >= active_start:
		_released = true
		result.entered_active = true
		result.projectile_ready = true
		# Release uses the exact muzzle pose, even if one frame crosses the
		# whole shot and the current sample already retains terminal recoil.
		result.release_pose = _pose_at(active_start)
	if elapsed >= total - .00000001:
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
		"radius": 0.42, "pitch": 0.0, "grip_height": 0.80,
		"blade_length": WEAPON_LENGTH, "body_lean": 0.0,
		"trail": false, "lunge_offset": 0.0,
		# Preserve the terminal budget until the caller starts or rebases.
		"recoil_offset": ATTACK.recoil_distance if _released else 0.0,
	}

func _pose_at(time: float) -> Dictionary:
	var pose := _rest_pose()
	var spec:=definition(0)
	var active_start: float = spec.windup
	var active_end: float = active_start + spec.active
	var recoil_progress := clampf((time - active_start) / ATTACK.recoil_duration, 0.0, 1.0)
	pose.recoil_offset = ATTACK.recoil_distance * _smooth(recoil_progress)
	if time < active_start:
		pose.phase = "windup"
		pose.progress = clampf(time / active_start, 0.0, 1.0)
	elif time < active_end:
		pose.phase = "active"
		pose.progress = clampf((time - active_start) / spec.active, 0.0, 1.0)
		pose.pitch = RECOIL_PITCH * _smooth(pose.progress)
	else:
		pose.phase = "recovery"
		pose.progress = clampf((time - active_end) / spec.recovery, 0.0, 1.0)
		pose.pitch = RECOIL_PITCH * (1.0 - _smooth(pose.progress))
	return pose

func _smooth(progress: float) -> float:
	return progress * progress * (3.0 - 2.0 * progress)
