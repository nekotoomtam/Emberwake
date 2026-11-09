extends RefCounted
## One committed basic fire shot. The caller creates a projectile on release;
## this model never performs melee damage, actor movement or attack chaining.

const EPSILON := 0.00000001
const WEAPON_LENGTH := 1.45
const LIFT_TIME := 0.063
const ATTACK := {
	"kind": "projectile", "element": "fire",
	"windup": 0.28, "active": 0.10, "recovery": 0.82,
	"damage": 72.0, "reach": 6.0, "arc": 0.0,
	"projectile_range": 6.0, "projectile_speed": 5.5,
	"projectile_radius": 0.18, "knockback": 1.4,
	"splash_radius": 1.20, "splash_damage": 36.0,
}

var cast_tier:=1
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
	if index!=0:return {}
	var result:=ATTACK.duplicate(true)
	result.erase("splash_radius");result.erase("splash_damage")
	result.damage=[20.0,44.0,66.0][cast_tier-1]
	result.projectile_radius=[.12,.20,.30][cast_tier-1]
	result.cast_tier=cast_tier
	result.ground_fire=cast_tier==3
	return result
func set_cast_tier(tier: int) -> void:cast_tier=clampi(tier,1,3)

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
	result.active = before < active_end - EPSILON and elapsed >= active_start - EPSILON
	if not _released and elapsed >= active_start - EPSILON:
		_released = true
		result.entered_active = true
		result.projectile_ready = true
		# A frame may end in recovery or idle. Muzzle consumers always receive
		# the exact release pose, independently of the terminal sampled pose.
		result.release_pose = _pose_at(active_start)
	if elapsed >= total - EPSILON:
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
		"radius": 0.28, "pitch": 1.1, "grip_height": 0.72,
		"blade_length": WEAPON_LENGTH, "body_lean": 0.0,
		"trail": false, "lunge_offset": 0.0,
	}

func _pose_at(time: float) -> Dictionary:
	var pose := _rest_pose()
	var active_start: float = ATTACK.windup
	var active_end: float = active_start + ATTACK.active
	if time < active_start - EPSILON:
		pose.phase = "windup"
		pose.progress = clampf(time / active_start, 0.0, 1.0)
		if time < LIFT_TIME:
			var lift := _smooth(clampf(time / LIFT_TIME, 0.0, 1.0))
			pose.pitch = lerpf(1.1, 1.25, lift)
			pose.radius = lerpf(0.28, 0.25, lift)
			pose.grip_height = lerpf(0.72, 0.78, lift)
			pose.body_lean = lerpf(0.0, -0.015, lift)
		else:
			var present := _smooth(clampf((time - LIFT_TIME) / (active_start - LIFT_TIME), 0.0, 1.0))
			pose.pitch = lerpf(1.25, 0.60, present)
			pose.radius = lerpf(0.25, 0.38, present)
			pose.grip_height = lerpf(0.78, 0.76, present)
			pose.body_lean = lerpf(-0.015, 0.035, present)
	elif time < active_end - EPSILON:
		pose.phase = "active"
		pose.progress = clampf((time - active_start) / ATTACK.active, 0.0, 1.0)
		_apply_release_pose(pose)
	else:
		pose.phase = "recovery"
		pose.progress = clampf((time - active_end) / ATTACK.recovery, 0.0, 1.0)
		var settle := _smooth(pose.progress)
		pose.pitch = lerpf(0.60, 1.1, settle)
		pose.radius = lerpf(0.38, 0.28, settle)
		pose.grip_height = lerpf(0.76, 0.72, settle)
		pose.body_lean = lerpf(0.035, 0.0, settle)
	return pose

func _apply_release_pose(pose: Dictionary) -> void:
	pose.pitch = 0.60
	pose.radius = 0.38
	pose.grip_height = 0.76
	pose.body_lean = 0.035

func _smooth(progress: float) -> float:
	return progress * progress * (3.0 - 2.0 * progress)
