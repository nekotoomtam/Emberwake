extends RefCounted
## Ground-plane blade motion. Angles are radians: +X is zero and +Z is PI / 2.
## The small hand/root travels with the weapon; reach is the blade-tip radius.

const ATTACKS: Array[Dictionary] = [
	{"windup": 0.18, "active": 0.11, "recovery": 0.24, "damage": 18.0, "reach": 2.1, "arc": 2.1},
	{"windup": 0.20, "active": 0.12, "recovery": 0.27, "damage": 19.0, "reach": 2.2, "arc": 2.3},
	{"windup": 0.34, "active": 0.16, "recovery": 0.38, "damage": 34.0, "reach": 2.55, "arc": 2.7},
]
const EPSILON := 0.00000001
const REST_ANGLE := 0.35
const GREATSWORD_LENGTH := 2.475
const GREATSWORD_HAND_RADIUS := 0.5
const GREATSWORD_SWEEP_REACH := GREATSWORD_HAND_RADIUS + GREATSWORD_LENGTH
const SLAM_GRIP_HEIGHT := 0.8
const SLAM_PITCH := -asin(SLAM_GRIP_HEIGHT / GREATSWORD_LENGTH)
const SLAM_REACH := GREATSWORD_HAND_RADIUS + sqrt(GREATSWORD_LENGTH * GREATSWORD_LENGTH - SLAM_GRIP_HEIGHT * SLAM_GRIP_HEIGHT)
const GREAT_ATTACKS: Array[Dictionary] = [
	{"kind": "sweep", "windup": 0.18, "active": 0.11, "recovery": 0.25, "damage": 45.0, "reach": GREATSWORD_SWEEP_REACH, "arc": 2.3},
	{"kind": "sweep", "windup": 0.19, "active": 0.12, "recovery": 0.24, "damage": 47.5, "reach": GREATSWORD_SWEEP_REACH, "arc": 2.4},
	{"kind": "slam", "windup": 0.25, "active": 0.13, "recovery": 0.29, "damage": 85.0, "reach": SLAM_REACH, "arc": 0.0, "width": 0.65, "impact_progress": 0.75},
]

var great_charge=preload("res://scripts/greatsword_charge.gd").new()
var family: String = "sword"
var busy := false
var stage := -1
var elapsed := 0.0
var aim_angle := 0.0
var _locked_aim := 0.0
var _entry_pose: Dictionary = {}
var _held_pose: Dictionary = {}
var _sword_motion = preload("res://scripts/sword_motion.gd").new()
var _mace_motion = preload("res://scripts/mace_motion.gd").new()
var _staff_motion = preload("res://scripts/staff_motion.gd").new()
var _pistol_motion = preload("res://scripts/pistol_motion.gd").new()
var _rifle_motion = preload("res://scripts/rifle_motion.gd").new()

func set_family(id: String) -> bool:
	if busy or id not in ["sword", "greatsword", "mace", "staff", "pistol", "rifle", "bow", "crossbow", "shield"]:
		return false
	family = id
	reset()
	return true

func rebase_idle_aim(new_angle: float) -> bool:
	if family == "sword":
		var accepted: bool = _sword_motion.rebase_idle_aim(new_angle)
		_sync_sword_state()
		return accepted
	if family == "rifle":
		var accepted: bool = _rifle_motion.rebase_idle_aim(new_angle)
		_sync_rifle_state()
		return accepted
	if family == "pistol":
		var accepted: bool = _pistol_motion.rebase_idle_aim(new_angle)
		_sync_pistol_state()
		return accepted
	if family == "staff":
		var accepted: bool = _staff_motion.rebase_idle_aim(new_angle)
		_sync_staff_state()
		return accepted
	if family == "mace":
		var accepted: bool = _mace_motion.rebase_idle_aim(new_angle)
		_sync_mace_state()
		return accepted
	if busy or not is_finite(new_angle):
		return false
	var next_aim := wrapf(new_angle, -PI, PI)
	var turn := wrapf(next_aim - _locked_aim, -PI, PI)
	_locked_aim = next_aim
	aim_angle = next_aim
	if not _held_pose.is_empty():
		_held_pose.angle += turn
	return true

func start(index: int, angle: float) -> bool:
	if family in ["bow", "crossbow", "shield"]: return false
	if family == "sword":
		var accepted: bool = _sword_motion.start(index, angle)
		_sync_sword_state()
		return accepted
	if family == "rifle":
		var accepted: bool = _rifle_motion.start(index, angle)
		_sync_rifle_state()
		return accepted
	if family == "pistol":
		var accepted: bool = _pistol_motion.start(index, angle)
		_sync_pistol_state()
		return accepted
	if family == "staff":
		var accepted: bool = _staff_motion.start(index, angle)
		_sync_staff_state()
		return accepted
	if family == "mace":
		var accepted: bool = _mace_motion.start(index, angle)
		_sync_mace_state()
		return accepted
	if busy or index < 0 or index >= ATTACKS.size() or not is_finite(angle):
		return false
	if family=="greatsword":
		if index<2:
			if index==0:great_charge.clear_finisher()
			great_charge.begin()
		else:great_charge.begin_slam()
	stage = index
	elapsed = 0.0
	_locked_aim = wrapf(angle, -PI, PI)
	aim_angle = _locked_aim
	if family == "greatsword":
		_entry_pose = _great_rest_pose(_locked_aim) if _held_pose.is_empty() else _held_pose.duplicate(true)
	busy = true
	return true

func start_mace_fire_lift(index: int, angle: float) -> bool:
	if family != "mace": return false
	var accepted: bool = _mace_motion.start_fire_lift(index, angle)
	_sync_mace_state()
	return accepted

func finish_mace_fire_lift() -> void:
	_mace_motion.fire_lift = false

func definition(index: int) -> Dictionary:
	if family == "sword":
		return _sword_motion.definition(index)
	if family == "rifle":
		return _rifle_motion.definition(index)
	if family == "pistol":
		return _pistol_motion.definition(index)
	if family == "staff":
		return _staff_motion.definition(index)
	if family == "mace":
		return _mace_motion.definition(index)
	if index < 0 or index >= ATTACKS.size():
		return {}
	return great_charge.definition(GREAT_ATTACKS[index],index) if family == "greatsword" else ATTACKS[index].duplicate(true)

func advance(delta: float) -> Dictionary:
	if family == "sword":
		var result: Dictionary = _sword_motion.advance(delta)
		_sync_sword_state()
		return result
	if family == "rifle":
		var result: Dictionary = _rifle_motion.advance(delta)
		_sync_rifle_state()
		return result
	if family == "pistol":
		var result: Dictionary = _pistol_motion.advance(delta)
		_sync_pistol_state()
		return result
	if family == "staff":
		var result: Dictionary = _staff_motion.advance(delta)
		_sync_staff_state()
		return result
	if family == "mace":
		var result: Dictionary = _mace_motion.advance(delta)
		_sync_mace_state()
		return result
	var angle: float = sample().angle
	var result := {
		"entered_active": false,
		"active": false,
		"damage_ready": false,
		"finished": false,
		"previous_angle": angle,
		"current_angle": angle,
	}
	if not busy or not is_finite(delta) or delta <= 0.0:
		return result
	if is_great_charging():
		great_charge.advance(delta)
		return result
	var attack := definition(stage)
	var active_start: float = attack.windup
	var active_end: float = attack.windup + attack.active
	var total: float = active_end + attack.recovery
	var before := elapsed
	elapsed = minf(elapsed + delta, total)
	result.entered_active = before < active_start - EPSILON and elapsed >= active_start - EPSILON
	# "active" describes the crossed release interval even if the final pose is
	# recovery. Damage consumers use damage_ready (slam waits for ground contact).
	result.active = before < active_end - EPSILON and elapsed >= active_start - EPSILON
	result.damage_ready = result.active
	if family == "greatsword" and stage == 2:
		var contact_time: float = active_start + attack.active * attack.impact_progress
		result.damage_ready = before < contact_time - EPSILON and elapsed >= contact_time - EPSILON
	if result.active:
		result.previous_angle = _active_angle(clampf((before - active_start) / attack.active, 0.0, 1.0))
		result.current_angle = _active_angle(clampf((elapsed - active_start) / attack.active, 0.0, 1.0))
	else:
		result.current_angle = _pose_at(elapsed).angle
	if elapsed >= total - EPSILON:
		elapsed = total
		if family == "greatsword":
			_held_pose = _great_pose_at(total)
		busy = false
		result.finished = true
	return result

func sample() -> Dictionary:
	if family == "sword":
		return _sword_motion.sample()
	if family == "rifle":
		return _rifle_motion.sample()
	if family == "pistol":
		return _pistol_motion.sample()
	if family == "staff":
		return _staff_motion.sample()
	if family == "mace":
		return _mace_motion.sample()
	if not busy:
		if family == "greatsword":
			var pose := _great_rest_pose(_locked_aim) if _held_pose.is_empty() else _held_pose.duplicate(true)
			pose.phase = "idle"
			pose.progress = 0.0
			pose.trail = false
			return pose
		return {"phase": "idle", "progress": 0.0, "angle": _locked_aim + REST_ANGLE, "radius": 0.5, "body_lean": 0.0, "trail": false}
	if is_great_charging():return _charge_pose()
	return _pose_at(elapsed)

func _pose_at(time: float) -> Dictionary:
	if family == "greatsword":
		return _great_pose_at(time)
	var attack := ATTACKS[stage]
	var direction := -1.0 if stage == 1 else 1.0
	var start_angle: float = _locked_aim - direction * attack.arc * 0.5
	var end_angle: float = _locked_aim + direction * attack.arc * 0.5
	var phase := "windup"
	var progress := 0.0
	var angle := _locked_aim + REST_ANGLE
	var radius := 0.5
	var lean := 0.0
	if time < attack.windup - EPSILON:
		progress = clampf(time / attack.windup, 0.0, 1.0)
		var anticipation := _smooth(progress)
		angle = lerpf(_locked_aim + REST_ANGLE, start_angle, anticipation)
		radius = lerpf(0.5, 0.46, anticipation)
		lean = -0.04 * anticipation
	elif time < attack.windup + attack.active - EPSILON:
		phase = "active"
		progress = clampf((time - attack.windup) / attack.active, 0.0, 1.0)
		angle = _active_angle(progress)
		radius = lerpf(0.46, 0.65, progress * progress)
		lean = 0.1 * progress
	else:
		phase = "recovery"
		progress = clampf((time - attack.windup - attack.active) / attack.recovery, 0.0, 1.0)
		# A short follow-through carries momentum past impact, then the blade slowly settles.
		var follow_through := end_angle + direction * (0.24 if stage == 2 else 0.18)
		if progress < 0.2:
			var coast := 1.0 - pow(1.0 - progress / 0.2, 2.0)
			angle = lerpf(end_angle, follow_through, coast)
		else:
			var settle := (progress - 0.2) / 0.8
			angle = lerpf(follow_through, _locked_aim + REST_ANGLE, _smooth(settle))
		radius = lerpf(0.65, 0.5, _smooth(progress))
		lean = 0.1 * (1.0 - progress)
	return {"phase": phase, "progress": progress, "angle": angle, "radius": radius, "body_lean": lean, "trail": phase == "active"}

func _active_angle(progress: float) -> float:
	if family == "greatsword" and stage == 2:
		return _locked_aim
	var direction := -1.0 if stage == 1 else 1.0
	if family == "greatsword":
		direction = -direction
	var arc: float = definition(stage).arc
	# Longer anticipation, accelerating release, and a separate slow recovery avoid pendulum motion.
	return _locked_aim + direction * arc * (progress * progress - 0.5)

func _great_rest_pose(angle: float) -> Dictionary:
	return {"phase": "idle", "progress": 0.0, "angle": angle + REST_ANGLE, "radius": GREATSWORD_HAND_RADIUS, "pitch": 0.0, "grip_height": SLAM_GRIP_HEIGHT, "blade_length": GREATSWORD_LENGTH, "body_lean": 0.0, "trail": false}

func _great_pose_at(time: float) -> Dictionary:
	var attack := definition(stage)
	var pose := _great_rest_pose(_locked_aim)
	# Actor right is forward.cross(UP): the first cut travels right to left.
	var direction := 1.0 if stage == 1 else -1.0
	var start_angle: float = _locked_aim - direction * attack.arc * 0.5
	var end_angle: float = _locked_aim + direction * attack.arc * 0.5
	if time < attack.windup - EPSILON:
		pose.phase = "windup"
		pose.progress = clampf(time / attack.windup, 0.0, 1.0)
		var anticipation := _smooth(pose.progress)
		pose.angle = lerp_angle(_entry_pose.angle, start_angle, anticipation)
		pose.pitch = lerpf(_entry_pose.pitch, 1.25 if stage == 2 else 0.0, anticipation)
		pose.grip_height = lerpf(_entry_pose.grip_height, 2.55 if stage == 2 else SLAM_GRIP_HEIGHT, anticipation)
		pose.body_lean = -0.045 * anticipation
	elif time < attack.windup + attack.active - EPSILON:
		pose.phase = "active"
		pose.progress = clampf((time - attack.windup) / attack.active, 0.0, 1.0)
		pose.angle = _active_angle(pose.progress)
		pose.trail = true
		if stage == 2:
			# Contact is three quarters through the short downstroke. The rigid
			# tip reaches ground exactly here; later active time holds the landing.
			var drop: float = clampf(pose.progress / attack.impact_progress, 0.0, 1.0)
			var release := drop * drop
			pose.pitch = lerpf(1.25, SLAM_PITCH, release)
			pose.grip_height = lerpf(2.55, SLAM_GRIP_HEIGHT, release)
			pose.body_lean = lerpf(-0.045, 0.13, release)
		else:
			pose.body_lean = lerpf(-0.045, 0.1, pose.progress)
	else:
		pose.phase = "recovery"
		pose.progress = clampf((time - attack.windup - attack.active) / attack.recovery, 0.0, 1.0)
		if stage == 2:
			var lift := _smooth(pose.progress)
			pose.angle = lerpf(_locked_aim, _locked_aim + REST_ANGLE, lift)
			pose.pitch = lerpf(SLAM_PITCH, 0.0, lift)
			pose.body_lean = 0.13 * (1.0 - lift)
		else:
			# Keep the blade at this side after the coast, ready to reverse or
			# lift overhead. Neither recovery nor the idle gap returns to rest.
			var coast := 1.0 - pow(1.0 - minf(pose.progress / 0.25, 1.0), 2.0)
			pose.angle = end_angle + direction * 0.16 * coast
			pose.body_lean = 0.1 * (1.0 - _smooth(pose.progress))
	return pose

func _smooth(progress: float) -> float:
	return progress * progress * (3.0 - 2.0 * progress)

func is_target_hit(origin: Vector3, target: Vector3, target_radius: float, from_angle: float, to_angle: float) -> bool:
	if family in ["staff", "pistol", "rifle"]:
		return false
	if family == "mace":
		return _mace_motion.is_target_hit(origin, target, target_radius, from_angle, to_angle)
	if stage < 0 or stage >= ATTACKS.size() or not origin.is_finite() or not target.is_finite():
		return false
	if not is_finite(target_radius) or target_radius < 0.0 or not is_finite(from_angle) or not is_finite(to_angle):
		return false
	var attack := definition(stage)
	var reach: float = attack.reach
	var offset := Vector2(target.x - origin.x, target.z - origin.z)
	if family == "greatsword" and stage == 2:
		# Finite forward blade lane. Target radius rounds the edges without
		# extending the authored lane behind the player or beyond its tip.
		var forward := Vector2(cos(_locked_aim), sin(_locked_aim))
		var along := offset.dot(forward)
		var across := offset.dot(Vector2(-forward.y, forward.x))
		var half_width: float = attack.width * 0.5
		var nearest := Vector2(clampf(along, 0.0, reach), clampf(across, -half_width, half_width))
		return Vector2(along, across).distance_to(nearest) <= target_radius + EPSILON
	var distance := offset.length()
	if distance > reach + target_radius + EPSILON:
		return false
	if distance <= target_radius + EPSILON:
		return true
	# Every authored active arc is below PI. Shortest signed difference also handles +/-PI seams.
	var sweep := wrapf(to_angle - from_angle, -PI, PI)
	var target_angle := offset.angle()
	var relative := wrapf(target_angle - from_angle, 0.0, TAU) if sweep >= 0.0 else wrapf(from_angle - target_angle, 0.0, TAU)
	if relative <= absf(sweep) + EPSILON:
		return true
	# Outside the angular interval, test the two finite radial edges, including tip corners.
	var start_tip := Vector2(cos(from_angle), sin(from_angle)) * reach
	var end_tip := Vector2(cos(from_angle + sweep), sin(from_angle + sweep)) * reach
	return minf(_distance_to_edge(offset, start_tip), _distance_to_edge(offset, end_tip)) <= target_radius + EPSILON

func _distance_to_edge(point: Vector2, tip: Vector2) -> float:
	var along := clampf(point.dot(tip) / tip.length_squared(), 0.0, 1.0)
	return point.distance_to(tip * along)

func reset() -> void:
	great_charge.reset()
	_sword_motion.reset()
	_mace_motion.reset()
	_staff_motion.reset()
	_pistol_motion.reset()
	_rifle_motion.reset()
	busy = false
	stage = -1
	elapsed = 0.0
	aim_angle = 0.0
	_locked_aim = 0.0
	_entry_pose.clear()
	_held_pose.clear()

func _sync_sword_state() -> void:
	busy = _sword_motion.busy
	stage = _sword_motion.stage
	elapsed = _sword_motion.elapsed
	aim_angle = _sword_motion.aim_angle

func _sync_mace_state() -> void:
	busy = _mace_motion.busy
	stage = _mace_motion.stage
	elapsed = _mace_motion.elapsed
	aim_angle = _mace_motion.aim_angle

func _sync_staff_state() -> void:
	busy = _staff_motion.busy
	stage = _staff_motion.stage
	elapsed = _staff_motion.elapsed
	aim_angle = _staff_motion.aim_angle

func _sync_pistol_state() -> void:
	busy = _pistol_motion.busy
	stage = _pistol_motion.stage
	elapsed = _pistol_motion.elapsed
	aim_angle = _pistol_motion.aim_angle

func _sync_rifle_state() -> void:
	busy = _rifle_motion.busy
	stage = _rifle_motion.stage
	elapsed = _rifle_motion.elapsed
	aim_angle = _rifle_motion.aim_angle

func is_great_charging() -> bool:
	return family=="greatsword" and busy and stage in [0,1] and great_charge.charging
func retarget_charge(angle: float) -> void:
	if family!="greatsword" or not busy or stage==2 or elapsed>0 or not is_finite(angle):return
	var turn:=wrapf(angle-_locked_aim,-PI,PI)
	_locked_aim=wrapf(angle,-PI,PI);aim_angle=_locked_aim
	if not _entry_pose.is_empty():_entry_pose.angle+=turn
func release_great_charge() -> bool:
	if not is_great_charging():return false
	var held:=_charge_pose()
	if not great_charge.release():return false
	if stage==1:great_charge.prime_finisher(great_charge.selected)
	_entry_pose=held;elapsed=0
	return true
func _charge_pose() -> Dictionary:
	var pose:=_great_rest_pose(_locked_aim)
	var direction: float=1.0 if stage==1 else -1.0
	var anticipation:=clampf(great_charge.elapsed/.08,0,1)
	pose.angle=lerp_angle(pose.angle,_locked_aim-direction*float(GREAT_ATTACKS[stage].arc)*.5,_smooth(anticipation))
	pose.pitch=.25*anticipation;pose.grip_height=.8+.18*anticipation
	pose.body_lean=-.055*anticipation;pose.phase="windup";pose.progress=anticipation;pose.trail=false
	return pose

func configure_staff(tier: int) -> void:
	_staff_motion.set_cast_tier(tier)

func configure_rifle(aimed: bool) -> void:
	_rifle_motion.configure_aim(aimed)
