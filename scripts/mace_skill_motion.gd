extends "res://scripts/mace_motion.gd"

const DEFAULT_SLOTS := ["mace_impact", "mace_sweep", "mace_double_impact"]
const FIRE_BUFF_DURATION := 5.0
const ARMOR_COUNTER_WINDOW := .50
const LEAP_GRADES := [
	{"dash_count": 0.0, "arc": PI / 3.0, "damage": 64.0, "edge_damage": 38.0},
	{"dash_count": 1.0, "arc": TAU * 80.0 / 360.0, "damage": 82.0, "edge_damage": 49.0},
	{"dash_count": 2.0, "arc": TAU * 100.0 / 360.0, "damage": 100.0, "edge_damage": 60.0},
]
const SKILLS := {
	"mace_impact": {"name": "ก้าวกระแทก", "level": 5, "cost": 18.0, "cooldown": 5.0,
		"tags": [SkillTags.AREA, SkillTags.GROUND_AREA, SkillTags.GROUND_IMPACT, SkillTags.ARMOR_BREAK],
		"description": "Lv5 • ก้าวสั้นแล้วทุบ วงออกตรงหัวกระบองที่แตะพื้น • เปิดเกราะ 1 ชั้น",
		"kind": "slam", "windup": .28, "active": .20, "recovery": .27,
		"impact_progress": .75, "lunge_distance": .65, "reach": SLAM_REACH,
		"area_radius": 1.35, "arc": TAU, "damage": 50.0, "knockback": 4.0, "armor_stacks": 1},
	"mace_sweep": {"name": "ทุบกวาด", "level": 5, "cost": 20.0, "cooldown": 6.0,
		"tags": [SkillTags.SWEEP, SkillTags.MULTI_HIT],
		"description": "Lv5 • ฟาดเป็นพัดด้านหน้า แล้วหมุนตัวฟาดซ้ำทางเดิม",
		"kind": "sweep", "windup": .23, "active": .22, "recovery": .065,
		"impact_progress": .55, "lunge_distance": 0.0, "reach": 2.35,
		"area_radius": 2.35, "arc": PI * .8, "damage": 18.0, "knockback": .9},
	"mace_double_impact": {"name": "โถมทุบคู่", "level": 10, "cost": 28.0, "cooldown": 8.0,
		"tags": [SkillTags.AREA, SkillTags.GROUND_AREA, SkillTags.GROUND_IMPACT, SkillTags.MULTI_HIT],
		"description": "โถมทุบพื้นแล้วหมุนตัวทุบซ้ำ • เล็งเบนทิศได้เล็กน้อยขณะหมุน",
		"kind": "slam", "windup": .29, "active": .20, "recovery": .12,
		"impact_progress": .75, "lunge_distance": .90, "reach": SLAM_REACH,
		"area_radius": 1.45, "arc": TAU, "damage": 34.0, "knockback": 1.3},
	"mace_gather": {"name": "ปักกระบองรวมเป้า", "level": 10, "cost": 24.0, "cooldown": 8.0,
		"tags": [SkillTags.AREA, SkillTags.GROUND_AREA, SkillTags.GROUND_IMPACT, SkillTags.CHARGE, SkillTags.PULL],
		"description": "ดึงศัตรูมารวมใกล้หัวกระบอง • เดินและหันได้ขณะชาร์จ • ทำให้เป้าเดินช้า 5% / 10% / 20% นาน 5 วิ",
		"kind": "slam", "windup": .33, "active": .19, "recovery": .26,
		"impact_progress": .75, "lunge_distance": 0.0, "reach": SLAM_REACH,
		"area_radius": 1.35, "arc": TAU, "damage": 24.0, "knockback": 0.0, "gathers": true, "slow_fraction": .05, "chargeable": true},
	"mace_fissure": {"name": "งัดเพลิง", "level": 15, "cost": 29.0, "cooldown": 8.0,
		"tags": [SkillTags.BUFF, SkillTags.PROJECTILE, SkillTags.FIRE],
		"impact_tags": [SkillTags.AREA],
		"description": "บัฟ 5 วิ • ลูกไฟชนศัตรูแล้วระเบิดทันที • ถ้าตกพื้นจะเด้ง 1 ครั้งก่อนแตก 3 ลูก",
		"kind": "buff", "windup": .18, "active": .16, "recovery": .21,
		"impact_progress": .55, "lunge_distance": 0.0, "reach": 2.1,
		"damage": 0.0, "fire_buff": true},
	"mace_aftershock": {"name": "ทุบฝังแรง", "level": 15, "cost": 20.0, "cooldown": 9.0,
		"tags": [SkillTags.AREA, SkillTags.GROUND_AREA, SkillTags.GROUND_IMPACT, SkillTags.PERSISTENT_AREA],
		"description": "ทุบเบาแล้ววางรอยแยก 10 วิ • ทุบลงในวงให้แรงสะท้อนตามหลัง เพิ่มดาเมจ 70% ใส่เป้าที่โดนทุบ สูงสุด 3 ครั้ง",
		"kind": "slam", "windup": .31, "active": .20, "recovery": .25,
		"impact_progress": .75, "lunge_distance": 0.0, "reach": SLAM_REACH,
		"area_radius": 1.35, "arc": TAU, "damage": 14.0, "knockback": 1.0, "rift_radius": 2.80},
	"mace_earth_wave": {"name": "กระโดดฟาดแผ่นดิน", "level": 20, "cost": 32.0, "cooldown": 10.0,
		"tags": [SkillTags.AREA, SkillTags.GROUND_AREA, SkillTags.GROUND_IMPACT, SkillTags.CHARGE, SkillTags.LEAP],
		"description": "ฟาดเป็นกรวยด้านหน้า • กดสั้นทุบอยู่กับที่ • ชาร์จเพื่อกระโดดไกลขึ้น กรวยกว้างขึ้น และฟาดแรงขึ้น",
		"kind": "slam", "windup": .37, "active": .20, "recovery": .32,
		"impact_progress": .75, "lunge_distance": 0.0, "reach": SLAM_REACH,
		"area_radius": 3.0, "core_radius": 1.15, "arc": LEAP_GRADES[0].arc,
		"damage": LEAP_GRADES[0].damage, "edge_damage": LEAP_GRADES[0].edge_damage,
		"knockback": 2.4, "stagger_duration": .32, "chargeable": true},
	"mace_armor_counter": {"name": "ฟาดเปิดเกราะ", "level": 20, "cost": 30.0, "cooldown": 11.0,
		"tags": [SkillTags.SWEEP, SkillTags.PARRY, SkillTags.ARMOR_BREAK],
		"description": "ตั้งรับ 0.5 วิ แล้วฟาดเปิดเกราะ 2 ชั้น • ฟาดโดนตัวที่แพร์รีจะเปิดเกราะเต็มเพดาน",
		"kind": "sweep", "windup": ARMOR_COUNTER_WINDOW, "active": .23, "recovery": .29,
		"impact_progress": .55, "lunge_distance": 0.0, "reach": 2.35,
		"area_radius": 2.35, "arc": TAU / 3.0, "damage": 78.0, "knockback": 1.5, "armor_stacks": 2},
}
const SECOND_SWEEP := {"windup": .30, "active": .18, "recovery": .24, "damage": 22.0, "knockback": 1.9}
const SWEEP_TURN_START := -PI * .24
const SWEEP_TURN_END := PI * .16
const SECOND_IMPACT := {"windup": .32, "recovery": .28, "lunge_distance": .25, "area_radius": 1.65, "damage": 42.0, "knockback": 3.4}
const GATHER_RADII := [1.35, 1.85, 2.50]
const GATHER_SLOWS := [.05, .10, .20]
const GATHER_SLOW_DURATION := 5.0
const CHARGE_MID_TIME := .40
const CHARGE_FULL_TIME := .90
const LEAP_GRIP_RADIUS := .32
const GATHER_TURN_RATE := TAU * 1.5
const FOLLOWUP_TURN_LIMIT := PI * (25.0 / 180.0)
const FOLLOWUP_TURN_RATE := PI * (120.0 / 180.0)

var skill_id := "mace_impact"
var _followup: Dictionary = {}
var _charge_spec: Dictionary = {}
var charging := false
var _charge_elapsed := 0.0
var _followup_base_angle := 0.0

func is_great_charging() -> bool:
	return false

func configure(id: String, entry_pose: Dictionary) -> bool:
	if busy or id not in SKILLS: return false
	reset()
	skill_id = id
	if SKILLS[id].get("chargeable", false): _charge_spec = SKILLS[id].duplicate()
	_followup.clear()
	if id in ["mace_sweep", "mace_double_impact"]:
		_followup = SKILLS[id].duplicate()
		_followup.merge(SECOND_SWEEP if id == "mace_sweep" else SECOND_IMPACT, true)
	_held_pose = entry_pose.duplicate()
	_held_pose.lunge_offset = 0.0
	return true

func definition(index: int) -> Dictionary:
	if index == 0: return _charge_spec if SKILLS[skill_id].get("chargeable", false) else SKILLS[skill_id]
	if index == 1: return _followup
	return {}

func start(index: int, angle: float) -> bool:
	if definition(index).is_empty() or not super.start(index, angle): return false
	if index == 1: _followup_base_angle = aim_angle
	return true

func can_steer_followup() -> bool:
	return busy and skill_id == "mace_double_impact" and stage == 1 and elapsed < float(SECOND_IMPACT.windup) - EPSILON

func steer_followup(requested_angle: float, delta: float) -> void:
	var desired := clampf(angle_difference(_followup_base_angle, requested_angle), -FOLLOWUP_TURN_LIMIT, FOLLOWUP_TURN_LIMIT)
	var current := angle_difference(_followup_base_angle, aim_angle)
	var steering_time := minf(delta, float(SECOND_IMPACT.windup) - elapsed)
	_locked_aim = wrapf(_followup_base_angle + move_toward(current, desired, FOLLOWUP_TURN_RATE * steering_time), -PI, PI)
	aim_angle = _locked_aim

func reset() -> void:
	super.reset()
	charging = false
	_charge_elapsed = 0.0

func charge_grade() -> int:
	if _charge_elapsed + EPSILON >= CHARGE_FULL_TIME: return 3
	if _charge_elapsed + EPSILON >= CHARGE_MID_TIME: return 2
	return 1

func charge_footprint() -> Dictionary:
	var tier := charge_grade() - 1
	if skill_id == "mace_gather":
		return {"area_radius": GATHER_RADII[tier], "arc": TAU}
	return {"area_radius": _charge_spec.area_radius, "core_radius": _charge_spec.core_radius,
		"arc": LEAP_GRADES[tier].arc}

func charge_contact_pose() -> Dictionary:
	var spec := definition(stage)
	return _pose_at(float(spec.windup) + float(spec.active) * float(spec.impact_progress))

func steer_charge(requested_angle: float, delta: float) -> void:
	var turn := clampf(angle_difference(aim_angle, requested_angle), -GATHER_TURN_RATE * delta, GATHER_TURN_RATE * delta)
	aim_angle = wrapf(aim_angle + turn, -PI, PI)
	_locked_aim = aim_angle
	_entry_pose.angle = wrapf(float(_entry_pose.angle) + turn, -PI, PI)

func release_charge() -> void:
	if not charging: return
	var tier := charge_grade() - 1
	if skill_id == "mace_gather":
		elapsed = _charge_pose_time()
		_charge_spec.area_radius = GATHER_RADII[tier]
		_charge_spec.slow_fraction = GATHER_SLOWS[tier]
	else:
		_entry_pose = sample()
		elapsed = 0.0
		var leap: Dictionary = LEAP_GRADES[tier]
		_charge_spec.arc = leap.arc
		_charge_spec.damage = leap.damage
		_charge_spec.edge_damage = leap.edge_damage
	charging = false

func advance(delta: float) -> Dictionary:
	if not charging: return super.advance(delta)
	_charge_elapsed = minf(CHARGE_FULL_TIME, _charge_elapsed + delta)
	return super.advance(0.0)

func sample() -> Dictionary:
	if charging:
		var pose := _pose_at(_charge_pose_time())
		pose.charge_walk = true
		return pose
	return super.sample()

func _charge_pose_time() -> float:
	return minf(_charge_elapsed, float(definition(stage).windup) * .82)

func _prepared_pose() -> Dictionary:
	if skill_id == "mace_fissure":
		return {"radius": .26, "pitch": -.55, "grip_height": .72}
	if skill_id == "mace_armor_counter":
		return {"angle": _locked_aim - float(definition(stage).arc) * .5,
			"radius": .40, "pitch": .10, "grip_height": 1.12}
	if skill_id != "mace_sweep":
		return {"radius": .45, "pitch": 1.25, "grip_height": 2.3}
	return {"angle": _locked_aim - float(SKILLS.mace_sweep.arc) * .5,
		"radius": .45, "pitch": -.14, "grip_height": .88}

func _apply_active_pose(pose: Dictionary, progress: float) -> void:
	if skill_id == "mace_earth_wave":
		var drop := clampf(progress / .75, 0.0, 1.0) ** 2
		pose.radius = lerpf(.45, LEAP_GRIP_RADIUS, drop)
		pose.pitch = lerpf(1.25, -PI * .5, drop)
		pose.grip_height = lerpf(2.3, WEAPON_LENGTH, drop)
		pose.body_lean = lerpf(-.035, .13, drop)
		return
	if skill_id == "mace_fissure":
		var lift := _smooth(progress)
		pose.radius = .26
		pose.pitch = lerpf(-.55, 1.1, lift)
		pose.grip_height = lerpf(.72, 1.12, lift)
		return
	if skill_id == "mace_armor_counter":
		var sweep := _smooth(progress)
		pose.angle = _locked_aim + float(definition(stage).arc) * (sweep - .5)
		pose.radius = .40 + sin(PI * progress) * .12
		pose.pitch = lerpf(.10, -.12, sweep)
		pose.grip_height = lerpf(1.12, .88, sweep)
		pose.body_lean = sin(PI * progress) * .13
		return
	if skill_id != "mace_sweep":
		_apply_slam_pose(pose, progress)
		pose.lunge_offset = float(definition(stage).lunge_distance)
		return
	var arc: float = SKILLS.mace_sweep.arc
	pose.angle = _locked_aim + arc * (_smooth(progress) - .5)
	pose.radius = .45
	pose.pitch = lerpf(-.14, -.20, sin(progress * PI))
	pose.grip_height = .88
	pose.body_lean = sin(progress * PI) * .10

func _pose_at(time: float) -> Dictionary:
	if skill_id == "mace_armor_counter" and time < ARMOR_COUNTER_WINDOW - EPSILON:
		# Set the guard quickly, then hold it until the one heavy sweep.
		return super._pose_at(minf(time / .12, 1.0) * (ARMOR_COUNTER_WINDOW - .0001))
	var pose := super._pose_at(time)
	if skill_id == "mace_earth_wave" and pose.phase == "recovery":
		var settle := _smooth(pose.progress)
		pose.pitch = lerpf(-PI * .5, 0.0, settle)
		pose.grip_height = lerpf(WEAPON_LENGTH, .8, settle)
		pose.radius = lerpf(LEAP_GRIP_RADIUS, LIFT_HAND_RADIUS, settle)
		return pose
	if skill_id == "mace_sweep" and stage == 1:
		_apply_sweep_turn(pose)
		return pose
	if pose.phase != "windup": return pose
	if skill_id != "mace_sweep":
		pose.lunge_offset = float(definition(stage).lunge_distance) * _smooth(pose.progress)
		if skill_id == "mace_double_impact" and stage == 1:
			pose.body_spin = TAU * _smooth(pose.progress)
			pose.angle += pose.body_spin
	return pose

func _apply_sweep_turn(pose: Dictionary) -> void:
	var progress: float = pose.progress
	var eased := _smooth(progress)
	match pose.phase:
		"windup":
			# Carry the raised head forward through the turn instead of reversing it across the front.
			var next_sweep_start := _locked_aim + TAU - float(SKILLS.mace_sweep.arc) * .5
			pose.angle = lerpf(float(_entry_pose.angle), next_sweep_start, eased)
			pose.body_spin = (TAU + SWEEP_TURN_START) * eased
			var lift := sin(PI * progress)
			pose.grip_height += .58 * lift
			pose.radius -= .23 * lift
			pose.pitch += .92 * lift
		"active":
			pose.body_spin = lerpf(SWEEP_TURN_START, SWEEP_TURN_END, eased)
		"recovery":
			pose.body_spin = lerpf(SWEEP_TURN_END, 0.0, eased)

func area_center(origin: Vector3, contact_pose: Dictionary) -> Vector3:
	if definition(stage).kind == "sweep": return origin
	# The rigid head and the impact circle share the rendered contact pose.
	var angle: float = contact_pose.angle
	var direction := Vector3(cos(angle), 0.0, sin(angle))
	var head_distance: float = contact_pose.radius + cos(contact_pose.pitch) * contact_pose.blade_length
	return origin + direction * head_distance

func area_contains(center: Vector3, target: Vector3) -> bool:
	var area: Dictionary = definition(stage)
	var offset := Vector2(target.x - center.x, target.z - center.z)
	if offset.length_squared() > float(area.area_radius) ** 2: return false
	return offset.is_zero_approx() or absf(wrapf(offset.angle() - aim_angle, -PI, PI)) <= float(area.arc) * .5
