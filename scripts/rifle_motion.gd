extends RefCounted
## One committed rifle shot. The caller owns ammunition, reload and flight.
## recoil_offset is a cumulative backward budget; only the caller moves actors.

const WEAPON_LENGTH := 1.35
const AIM_HEIGHT := .80
const RAISED_AIM_HEIGHT := 1.45
const RECOIL_PITCH := 0.13
const BASE_POWER := 52.0
const DEFAULT_WEAPON_STATS := {"power": BASE_POWER, "handling": 0.0, "reload": 0.0, "accuracy": 0.0}
const PIERCING_ROUND_ID := "rifle_piercing_round"
const PIERCING_ROUND_COST := 16.0
const PIERCING_ROUND_COOLDOWN := 5.0
const ARMOR_ROUND_ID := "rifle_armor_round"
const MARK_ROUND_ID := "rifle_mark_round"
const SCATTER_ROUND_ID := "rifle_scatter_round"
const SCATTER_ANGLES := [0.0, -6.0, 6.0, -12.0, 12.0]
const SPLIT_ROUND_ID := "rifle_split_round"
const REFILL_SKILL_ID := "rifle_quick_refill"
const RAPID_FIRE_ID := "rifle_rapid_fire"
const RAPID_FIRE_DURATION := 5.0
const FINISHER_ID := "rifle_finisher"
const FINISHER_CHARGE := 1.0
const FINISHER_RANGE := 16.0
const PIERCING_ROUND := {
	"power_ratio": 1.10, "projectile_range": 12.0, "pierce_after_exit": 12.0,
	"max_targets": 4, "rifle_falloff": .10, "piercing_round": true,
}
const SKILLS := {
	PIERCING_ROUND_ID: {"name": "กระสุนทะลุ", "level": 5, "cost": PIERCING_ROUND_COST,
		"cooldown": PIERCING_ROUND_COOLDOWN, "profile": PIERCING_ROUND, "color": Color("#9adeff"),
		"description": "เตรียมกระสุน แล้วคลิกซ้ายยิง • ทะลุสูงสุด 4 เป้า ดาเมจลดตามลำดับ",
		"tags": [&"projectile", &"pierce"]},
	ARMOR_ROUND_ID: {"name": "กระสุนเปิดเกราะ", "level": 5, "cost": 14.0,
		"cooldown": 6.0, "color": Color("#ffd276"),
		"profile": {"power_ratio": 1.0, "max_targets": 1, "armor_break_stacks": 1},
		"description": "เตรียมกระสุน แล้วคลิกซ้ายยิง • โดนเป้าเดียวและเปิดเกราะ 1 ขั้น 10 วิ",
		"tags": [&"projectile", &"armor_break"]},
	MARK_ROUND_ID: {"name": "กระสุนตีตรา", "level": 10, "cost": 24.0, "rounds": 3,
		"cooldown": 8.0, "color": Color("#e7acff"),
		"profile": {"power_ratio": .95, "max_targets": 1, "mark_round": true},
		"description": "เตรียม 3 นัด • ยิงตีตราซ้ำเริ่มเวลา 5 วิใหม่ สูงสุด 1 ตราต่อเป้า • นัดปืนยาวชนิดอื่นใช้ตราเพื่อเพิ่มดาเมจ 10%",
		"tags": [&"projectile"]},
	SCATTER_ROUND_ID: {"name": "กระสุนถอยฉาก", "level": 10, "cost": 14.0,
		"cooldown": 7.0, "color": Color("#b7f4a2"),
		"profile": {"power_ratio": .20, "projectile_range": 3.0, "projectile_radius": .045,
			"projectile_speed": 24.0, "knockback": .42, "max_targets": 1},
		"description": "ยิงลูกปรายเล็ก 5 เม็ดในกรวยแคบ • ยิงแล้วถอยหนึ่งช่วงแดช",
		"tags": [&"projectile"]},
	SPLIT_ROUND_ID: {"name": "กระสุนแตกปลาย", "level": 15, "cost": 18.0,
		"cooldown": 8.0, "color": Color("#ffc18e"),
		"profile": {"power_ratio": 1.0, "projectile_range": 3.5, "max_targets": 1,
			"rifle_split": {"power_ratio": 1.60, "reach": 2.2, "half_angle": deg_to_rad(26.0), "knockback": 1.6}},
		"description": "แตกที่ระยะ 3.5 เมตรจากปากกระบอก • ดาเมจกรวยโดนทุกตัวในพื้นที่",
		"tags": [&"projectile", &"area"]},
	REFILL_SKILL_ID: {"name": "เติมกระสุนด่วน", "level": 15, "cost": 12.0,
		"cooldown": 8.0, "refill": 2,
		"description": "เติมกระสุนธรรมดา 2 นัดเข้าท้ายคิวทันที • ต้องมีช่องว่าง 2 ช่อง",
		"tags": []},
	RAPID_FIRE_ID: {"name": "ยิงต่อเนื่อง", "level": 20, "cost": 24.0,
		"cooldown": 16.0, "duration": RAPID_FIRE_DURATION,
		"description": "ข้ามการขึ้นลำหลังยิง 5 วิ • ยิงได้ทุก 0.4 วิ • ใช้กระสุนตามคิว",
		"tags": [&"buff"]},
	FINISHER_ID: {"name": "ยิงทะลวง", "level": 20, "cost": 32.0, "cooldown": 20.0,
		"profile": {"power_ratio": 2.20, "projectile_range": FINISHER_RANGE, "pierce_after_exit": FINISHER_RANGE,
			"projectile_speed": 48.0, "projectile_radius": .24, "max_targets": 0, "rifle_falloff": 0.0,
			"piercing_round": true, "tracer_length": 2.4},
		"color": Color("#d2f2ff"),
		"description": "ยืนชาร์จ 1 วิ ลากเมาส์เล็งแล้วยิงอัตโนมัติ • ถอย 1.5 ช่วงแดช",
		"tags": [&"projectile", &"pierce", &"charge"]},
}
const DEFAULT_SLOTS := [PIERCING_ROUND_ID, ARMOR_ROUND_ID, MARK_ROUND_ID]
const ATTACK := {
	"kind": "projectile", "element": "physical",
	"projectile_visual": "rifle",
	"windup": 0.16, "active": 0.08, "recovery": 0.66,
	"damage": BASE_POWER, "reach": 9.0, "arc": 0.0,
	"projectile_range": 9.0, "projectile_speed": 22.0,
	"projectile_radius": 0.10, "knockback": 2.0,
	"magazine_capacity": 5, "reload_time": 1.2,
	"pierce_after_exit": 0.55, "max_targets": 2,
	"recoil_distance": 0.22, "recoil_duration": 0.12,
}

var aimed:=false
var rapid := false
var finisher := false
var shot_time_scale := 1.0
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
	finisher = false

func finisher_charging() -> bool:
	return busy and finisher and not _released

func retarget_finisher(angle: float) -> void:
	if not finisher_charging() or not is_finite(angle): return
	_locked_aim = wrapf(angle, -PI, PI)
	aim_angle = _locked_aim

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

static func bonus_points(attributes: Dictionary, key: String) -> float:
	return maxf(0.0, float(attributes.get(key, 3)) - 3.0)

static func level_steps(id: String, level: int) -> int:
	if not SKILLS.has(id): return 0
	return floori(maxi(0, level - int(SKILLS[id].level)) / 3.0)

static func skill_cost(id: String, attributes: Dictionary) -> float:
	var cost: float = SKILLS[id].cost
	if id in [ARMOR_ROUND_ID, MARK_ROUND_ID, REFILL_SKILL_ID, RAPID_FIRE_ID]:
		cost -= minf(cost * .20, bonus_points(attributes, "intelligence") * .5)
	return cost

static func skill_cooldown(id: String, level: int) -> float:
	var cooldown: float = SKILLS[id].cooldown
	if id in [REFILL_SKILL_ID, RAPID_FIRE_ID]:
		cooldown = maxf(.4, cooldown - .4 * level_steps(id, level))
	return cooldown

static func time_scale(attributes: Dictionary, weapon_bonus: float) -> float:
	var dex_scale := 1.0 - minf(.15, bonus_points(attributes, "dexterity") * .01)
	return clampf(dex_scale * (1.0 - weapon_bonus), .25, 2.0)

static func projectile_profile(id: String, power: float, attributes: Dictionary, level: int) -> Dictionary:
	var dex := bonus_points(attributes, "dexterity")
	var intelligence := bonus_points(attributes, "intelligence")
	if id.is_empty(): return {"damage": maxf(1.0, power) * (1.0 + .008 * dex)}
	var profile: Dictionary = SKILLS.get(id, {}).get("profile", {}).duplicate(true)
	if profile.is_empty(): return profile
	var steps := level_steps(id, level)
	var growth := 1.0 + .08 * steps
	var shot_power := maxf(1.0, power)
	var intelligence_rate := 0.0
	match id:
		PIERCING_ROUND_ID:
			intelligence_rate = .0035
		SCATTER_ROUND_ID:
			profile.projectile_speed *= 1.0 + .004 * intelligence
			var angles: Array[float] = []
			var angle_scale := 1.0 + steps / 24.0
			for angle: float in SCATTER_ANGLES: angles.append(angle * angle_scale)
			profile.scatter_angles = angles
		SPLIT_ROUND_ID:
			profile.rifle_split.damage = shot_power * float(profile.rifle_split.power_ratio) * growth * (1.0 + .004 * dex + .012 * intelligence)
			profile.rifle_split.half_angle += deg_to_rad(steps)
		FINISHER_ID:
			intelligence_rate = .006
			profile.projectile_radius += .01 * steps
	profile.damage = shot_power * float(profile.power_ratio) * growth * (1.0 + .008 * dex + intelligence_rate * intelligence)
	return profile

func configure_aim(value: bool, rapid_fire: bool = false, finisher_shot: bool = false, timing_scale: float = 1.0) -> void:
	aimed = value
	rapid = rapid_fire
	finisher = finisher_shot
	shot_time_scale = timing_scale
func definition(index: int) -> Dictionary:
	if index!=0:return {}
	var result:=ATTACK.duplicate(true)
	result.windup=.20 if aimed else .16;result.recovery=.92 if aimed else .66
	if not rapid and not finisher:
		result.windup *= shot_time_scale
		result.recovery *= shot_time_scale
	if rapid:
		result.windup = .16
		result.recovery = .16
	if finisher:
		result.windup = FINISHER_CHARGE
		if rapid: result.recovery = .32
	result.projectile_range=12.0 if aimed else 9.0;result.reach=result.projectile_range
	result.rifle_aimed=aimed
	result.rifle_rapid = rapid
	result.rifle_finisher = finisher
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
		"radius": 0.42, "pitch": 0.0, "grip_height": AIM_HEIGHT,
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
