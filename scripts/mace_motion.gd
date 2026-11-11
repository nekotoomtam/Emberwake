extends RefCounted
## Rigid one-handed mace: weighted lift, quick positioning shove, overhead slam.
## Motion never moves the actor or chains attacks; the caller applies lunge diffs.

const EPSILON := 0.00000001
const SkillTags = preload("res://scripts/skill_tags.gd")
const WEAPON_LENGTH := 1.9
const LUNGE_DISTANCE := 0.75
const LIFT_HAND_RADIUS := 0.2
const LUNGE_HAND_RADIUS := 0.3
const LIFT_CONTACT_PROGRESS := sqrt(0.35 / 1.55)
const SLAM_PITCH := -asin(0.65 / WEAPON_LENGTH)
const SLAM_REACH := 2.55
const SLAM_HAND_RADIUS := SLAM_REACH - sqrt(WEAPON_LENGTH * WEAPON_LENGTH - 0.65 * 0.65)
const FIRE_SCOOP_GRIP_HEIGHT := .70
const FIRE_SCOOP_PITCH := -asin(FIRE_SCOOP_GRIP_HEIGHT / WEAPON_LENGTH)
const FIRE_SCOOP_FRACTION := .18
const FIRE_LIFT := {"kind": "fire_lift", "windup": .19, "active": .20, "recovery": .19,
	"damage": 22.0, "reach": 2.1, "arc": 0.0, "width": .85, "knockback": 1.6, "impact_progress": .58}
const ATTACKS: Array[Dictionary] = [
	{"kind": "lift", "windup": 0.23, "active": 0.13, "recovery": 0.21, "damage": 34.0, "reach": LIFT_HAND_RADIUS + WEAPON_LENGTH, "arc": 0.0, "width": 0.7, "knockback": 2.3, "impact_progress": LIFT_CONTACT_PROGRESS},
	{"kind": "lunge", "windup": 0.05, "active": 0.13, "recovery": 0.14, "damage": 12.0, "reach": LUNGE_HAND_RADIUS + WEAPON_LENGTH, "arc": 0.0, "width": 0.7, "knockback": 0.8, "impact_progress": 0.8, "lunge_distance": LUNGE_DISTANCE},
	{"kind": "slam", "windup": 0.24, "active": 0.14, "recovery": 0.25, "damage": 46.0, "reach": SLAM_REACH, "arc": 0.0, "width": 0.7, "knockback": 5.5, "impact_progress": 0.75,
		"tags": [SkillTags.AREA, SkillTags.GROUND_AREA, SkillTags.GROUND_IMPACT]},
]

var busy := false
var stage := -1
var elapsed := 0.0
var aim_angle := 0.0
var _locked_aim := 0.0
var _entry_pose: Dictionary = {}
var _held_pose: Dictionary = {}
var fire_lift := false

func start(index: int, angle: float) -> bool:
	return _start(index, angle, false)

func start_fire_lift(index: int, angle: float) -> bool:
	return _start(index, angle, true)

func _start(index: int, angle: float, use_fire_lift: bool) -> bool:
	if busy or index < 0 or index >= ATTACKS.size() or not is_finite(angle):
		return false
	_entry_pose = sample()
	fire_lift = use_fire_lift
	# A new shove has its own cumulative travel budget. Callers baseline the
	# offset at start, then consume positive differences, never an idle rewind.
	if index == 1 or fire_lift:
		_entry_pose.lunge_offset = 0.0
	stage = index
	elapsed = 0.0
	_locked_aim = wrapf(angle, -PI, PI)
	aim_angle = _locked_aim
	busy = true
	return true

func definition(index: int) -> Dictionary:
	if fire_lift and index in [0, 1]: return FIRE_LIFT
	return {} if index < 0 or index >= ATTACKS.size() else ATTACKS[index].duplicate(true)

func advance(delta: float) -> Dictionary:
	var angle: float = sample().angle
	var result := {
		"entered_active": false, "active": false, "damage_ready": false,
		"finished": false, "previous_angle": angle, "current_angle": angle,
		"contact_pose": {},
	}
	if not busy or not is_finite(delta) or delta <= 0.0:
		return result
	var attack := definition(stage)
	var active_start: float = attack.windup
	var active_end: float = active_start + attack.active
	var total: float = active_end + attack.recovery
	var contact_time: float = active_start + attack.active * attack.impact_progress
	var before := elapsed
	elapsed = minf(elapsed + delta, total)
	result.entered_active = before < active_start - EPSILON and elapsed >= active_start - EPSILON
	if fire_lift and result.entered_active:
		result.ground_pose = _pose_at(active_start)
	# Crossed intervals retain their events even when this step ends in idle.
	result.active = before < active_end - EPSILON and elapsed >= active_start - EPSILON
	result.damage_ready = before < contact_time - EPSILON and elapsed >= contact_time - EPSILON
	if result.active:
		result.previous_angle = _locked_aim
		result.current_angle = _locked_aim
	else:
		result.current_angle = _pose_at(elapsed).angle
	if result.damage_ready:
		result.contact_pose = _pose_at(contact_time)
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
	return {"phase": "idle", "progress": 0.0, "angle": angle, "radius": LIFT_HAND_RADIUS, "pitch": 0.0, "grip_height": 0.8, "blade_length": WEAPON_LENGTH, "body_lean": 0.0, "trail": false, "lunge_offset": 0.0}

func _pose_at(time: float) -> Dictionary:
	var attack := definition(stage)
	var pose := _rest_pose(_locked_aim)
	pose.lunge_offset = _entry_pose.lunge_offset
	var prepared := _prepared_pose()
	if time < attack.windup - EPSILON:
		pose.phase = "windup"
		pose.progress = clampf(time / attack.windup, 0.0, 1.0)
		var preparation := _smooth(pose.progress)
		pose.angle = lerp_angle(_entry_pose.angle, prepared.get("angle", _locked_aim), preparation)
		pose.radius = lerpf(_entry_pose.radius, prepared.radius, preparation)
		pose.pitch = lerpf(_entry_pose.pitch, prepared.pitch, preparation)
		pose.grip_height = lerpf(_entry_pose.grip_height, prepared.grip_height, preparation)
		pose.body_lean = lerpf(_entry_pose.body_lean, -0.035, preparation)
	elif time < attack.windup + attack.active - EPSILON:
		pose.phase = "active"
		pose.progress = clampf((time - attack.windup) / attack.active, 0.0, 1.0)
		_apply_active_pose(pose, pose.progress)
		pose.trail = true
	else:
		pose.phase = "recovery"
		pose.progress = clampf((time - attack.windup - attack.active) / attack.recovery, 0.0, 1.0)
		_apply_active_pose(pose, 1.0)
		var settle := _smooth(pose.progress)
		pose.body_lean *= 1.0 - settle
		if attack.kind == "slam":
			# Lift away from the grounded head without snapping back at idle.
			pose.pitch = lerpf(SLAM_PITCH, 0.0, settle)
			pose.grip_height = lerpf(0.65, 0.8, settle)
			pose.radius = lerpf(SLAM_HAND_RADIUS, LIFT_HAND_RADIUS, settle)
	return pose

func _prepared_pose() -> Dictionary:
	if fire_lift:
		var side := -1.0 if stage == 0 else 1.0
		return {"angle": _locked_aim + side * .85, "radius": .34, "pitch": FIRE_SCOOP_PITCH, "grip_height": FIRE_SCOOP_GRIP_HEIGHT}
	if stage == 0:
		return {"radius": LIFT_HAND_RADIUS, "pitch": -0.35, "grip_height": 0.65}
	if stage == 1:
		return {"radius": 0.18, "pitch": 0.2, "grip_height": 1.1}
	return {"radius": 0.45, "pitch": 1.25, "grip_height": 2.3}

func _apply_active_pose(pose: Dictionary, progress: float) -> void:
	if fire_lift:
		var side := -1.0 if stage == 0 else 1.0
		# Scrape the head along the ground before lifting it to throw the fireball.
		var scrape := _smooth(minf(1.0, progress / FIRE_SCOOP_FRACTION))
		var lift_progress := clampf((progress - FIRE_SCOOP_FRACTION) / (1.0 - FIRE_SCOOP_FRACTION), 0.0, 1.0)
		var lift := _ease_out(lift_progress)
		pose.angle = _locked_aim + side * lerpf(lerpf(.85, .69, scrape), -.12, lift)
		pose.radius = lerpf(lerpf(.34, .40, scrape), .27, lift)
		pose.pitch = lerpf(FIRE_SCOOP_PITCH, 1.15, lift)
		pose.grip_height = lerpf(FIRE_SCOOP_GRIP_HEIGHT, 1.10, lift)
		pose.body_lean = lerpf(-.035, .095, lift)
	elif stage == 0:
		var lift := progress * progress
		pose.radius = LIFT_HAND_RADIUS
		pose.pitch = lerpf(-0.35, 1.2, lift)
		pose.grip_height = lerpf(0.65, 1.1, lift)
		pose.body_lean = lerpf(-0.035, 0.075, progress)
	elif stage == 1:
		# Hand extension is complete at the light contact. Actor travel still
		# decelerates over the full active interval, with no recovery rewind.
		var shove := _ease_out(clampf(progress / 0.8, 0.0, 1.0))
		pose.radius = lerpf(0.18, LUNGE_HAND_RADIUS, shove)
		pose.pitch = lerpf(0.2, 0.0, shove)
		pose.grip_height = lerpf(1.1, 0.85, shove)
		pose.body_lean = lerpf(-0.035, 0.09, shove)
		pose.lunge_offset = LUNGE_DISTANCE * _ease_out(progress)
	else:
		_apply_slam_pose(pose, progress)

func _apply_slam_pose(pose: Dictionary, progress: float) -> void:
	var drop := clampf(progress / 0.75, 0.0, 1.0)
	var slam := drop * drop
	# The hand extends as the rigid head drops to the matched sword reach.
	pose.radius = lerpf(0.45, SLAM_HAND_RADIUS, slam)
	pose.pitch = lerpf(1.25, SLAM_PITCH, slam)
	pose.grip_height = lerpf(2.3, 0.65, slam)
	pose.body_lean = lerpf(-0.035, 0.13, slam)

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

func is_target_hit(origin: Vector3, target: Vector3, target_radius: float, from_angle: float, to_angle: float) -> bool:
	if stage < 0 or stage >= ATTACKS.size() or not origin.is_finite() or not target.is_finite():
		return false
	if not is_finite(target_radius) or target_radius < 0.0 or not is_finite(from_angle) or not is_finite(to_angle):
		return false
	var attack := definition(stage)
	var forward := Vector2(cos(_locked_aim), sin(_locked_aim))
	var offset := Vector2(target.x - origin.x, target.z - origin.z)
	var along := offset.dot(forward)
	var across := offset.dot(Vector2(-forward.y, forward.x))
	var half_width: float = attack.width * 0.5
	var nearest := Vector2(clampf(along, 0.0, attack.reach), clampf(across, -half_width, half_width))
	return Vector2(along, across).distance_to(nearest) <= target_radius + EPSILON

func reset() -> void:
	fire_lift = false
	busy = false
	stage = -1
	elapsed = 0.0
	aim_angle = 0.0
	_locked_aim = 0.0
	_entry_pose.clear()
	_held_pose.clear()

func _smooth(progress: float) -> float:
	return progress * progress * (3.0 - 2.0 * progress)

func _ease_out(progress: float) -> float:
	return 1.0 - (1.0 - progress) * (1.0 - progress)
