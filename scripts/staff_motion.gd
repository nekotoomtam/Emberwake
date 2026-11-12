extends RefCounted
## One committed basic fire shot. The caller creates a projectile on release;
## this model never performs melee damage, actor movement or attack chaining.

const EPSILON := 0.00000001
const Charge = preload("res://scripts/staff_charge.gd")
const WEAPON_LENGTH := 1.45
const LIFT_TIME := 0.063
const CHARGED_FIRE_ID := "staff_charged_fire"
const ICE_VOLLEY_ID := "staff_ice_volley"
const CHAIN_LIGHTNING_ID := "staff_chain_lightning"
const FIRE_BREATH_ID := "staff_fire_breath"
const ICE_CRYSTAL_ID := "staff_ice_crystal"
const MANA_FIELD_ID := "staff_mana_field"
const FOCUS_ID := "staff_focus"
const METEOR_ID := "staff_meteor"
const BASE_WEAPON_POWER := 42.0
const GROUND_CAST_REACH := 8.0
const ICE_CRYSTAL_RADIUS := 3.2
const ICE_CRYSTAL_DAMAGE := 95.0
const ICE_CRYSTAL_DELAY := 1.0
const MANA_FIELD_RADIUS := 4.5
const MANA_FIELD_DURATION := 12.0
const MANA_FIELD_REFUND := 8.0
const METEOR_DELAY := .8
const METEOR_RADIUS := 3.6
const METEOR_DAMAGE := 180.0
const METEOR_SPARK_DAMAGE := 32.0
const METEOR_SPARK_REACH := 2.5
const BREATH_INTERVAL := .25
const BREATH_TICKS := 6
const BREATH_DAMAGE := 30.0
const BREATH_REACH := 3.0
const BREATH_HALF_ANGLE := PI / 7.0
const BREATH_TURN_RATE := 3.5
const WEAK_TO := {"fire": "ice", "ice": "lightning", "lightning": "fire"}
const SKILLS := {CHARGED_FIRE_ID: {"name": "ลูกไฟชาร์จ", "level": 5, "cost": 22.0, "cooldown": 0.0,
	"element": "fire", "orbs": 3, "charge_time": .9, "tier": 3,
	"description": "ชาร์จ 0.9 วิแล้วปล่อย • ใช้ลูกแก้วซ้ายสุด 3 ลูก • โดนตรง 135 • ระเบิด 65\nต่อลูกที่ใช้: ไฟ +5% ดาเมจ • น้ำแข็ง −5% ดาเมจ • สายฟ้า +1% รัศมีระเบิด",
	"tags": [&"projectile", &"fire", &"charge"]},
	ICE_VOLLEY_ID: {"name": "ลูกน้ำแข็งชะลอ", "level": 5, "cost": 26.0, "cooldown": 0.0,
		"element": "ice", "orbs": 2, "charge_time": .65, "tier": 1,
		"description": "ชาร์จ 0.65 วิ • ใช้ลูกแก้วซ้ายสุด 2 ลูก • ยิงน้ำแข็ง 3 ลูก ดาเมจลูกละ 24\nโดนแล้วช้าลงลูกละ 10% สูงสุด 30% นาน 5 วิ โดนซ้ำเริ่มนับเวลาใหม่\nต่อลูกที่ใช้: น้ำแข็ง +5% ดาเมจ • สายฟ้า −5% ดาเมจ • ไฟ +1% รัศมีกระสุน",
		"tags": [&"projectile", &"ice", &"charge"]},
	CHAIN_LIGHTNING_ID: {"name": "สายฟ้าลูกโซ่", "level": 10, "cost": 32.0, "cooldown": 0.0,
		"element": "lightning", "orbs": 3, "charge_time": .75, "tier": 1,
		"description": "ชาร์จ 0.75 วิ • ใช้ลูกแก้วซ้ายสุด 3 ลูก • โดนเป้าแรกแล้วชิ่งไปอีก 2 ตัว ดาเมจ 60 → 45 → 34\nต่อลูกที่ใช้: สายฟ้า +5% ดาเมจ • ไฟ −5% ดาเมจ • น้ำแข็ง +1% ระยะชิ่ง",
		"tags": [&"projectile", &"charge"]},
	FIRE_BREATH_ID: {"name": "พ่นไฟ", "level": 10, "cost": 34.0, "cooldown": 0.0,
		"element": "fire", "orbs": 4,
		"description": "กดสกิลตั้งท่า แล้วคลิกซ้ายค้างเพื่อพ่นไฟระยะใกล้ 1.5 วิ • ใช้ลูกแก้วซ้ายสุด 4 ลูกตอนเริ่มพ่น\nดาเมจ 30 ทุก 0.25 วิ • ปล่อยคลิกเพื่อหยุด\nต่อลูกที่ใช้: ไฟ +5% ดาเมจ • น้ำแข็ง −5% ดาเมจ • สายฟ้า +1% ความกว้างกรวย",
		"tags": [&"stance", &"area", &"fire", &"multi_hit"]},
	ICE_CRYSTAL_ID: {"name": "ผลึกน้ำแข็ง", "level": 15, "cost": 38.0, "cooldown": 0.0,
		"element": "ice", "orbs": 4, "charge_time": .65,
		"description": "ชาร์จแล้วปล่อยลงจุดที่เล็ง • ใช้ลูกแก้วซ้ายสุด 4 ลูก\nหลังลงพื้น 1 วิ ผลึกผุดทั้งวง ดาเมจ 95 และตรึงเท้า 0.75 วิ\nต่อลูกที่ใช้: น้ำแข็ง +5% ดาเมจ • สายฟ้า −5% ดาเมจ • ไฟ +1% รัศมี",
		"tags": [&"ground_area", &"charge"]},
	MANA_FIELD_ID: {"name": "วงสายฟ้าคืนมานา", "level": 15, "cost": 36.0, "cooldown": 0.0,
		"element": "lightning", "orbs": 3, "charge_time": .65,
		"description": "ชาร์จแล้ววางวง 12 วิ • ใช้ลูกแก้วซ้ายสุด 3 ลูก\nฆ่ามอนในวงได้คืน 8 มานาต่อตัว วางซ้ำจะย้ายวง\nต่อลูกที่ใช้: สายฟ้า +1 วิ • น้ำแข็ง +5% รัศมี • ไฟ −1 วิ",
		"tags": [&"ground_area", &"persistent_area", &"charge"]},
	FOCUS_ID: {"name": "กักพลังคทา", "level": 20, "cost": 40.0, "cooldown": 25.0, "orbs": 0,
		"description": "แทรกลูกแก้วไร้ธาตุ 2 ลูกหน้าคิว ดันลูกท้ายที่เกินออก • บัฟ 10 วิ\nสกิลคทาจ่ายมานาครึ่งเดียว และคืนลูกแก้วไร้ธาตุครึ่งหนึ่งของที่ใช้ (ปัดลง) เมื่อร่ายสำเร็จ\nลูกแก้วไร้ธาตุนับเป็นธาตุตรงกับสกิลที่ใช้",
		"tags": [&"buff"]},
	METEOR_ID: {"name": "ดาวตกสามธาตุ", "level": 20, "cost": 48.0, "cooldown": 0.0,
		"element": "fire", "orbs": 5, "charge_time": .85,
		"description": "ชาร์จแล้วเลือกจุดลง • ใช้ลูกแก้ว 5 ลูก • ดาวตกกระแทกวงหลัง 0.8 วิ ดาเมจ 180\nต่อลูกที่ใช้: ไฟ +5% ดาเมจกระแทก • น้ำแข็ง +5% รัศมี • สายฟ้าเพิ่มประกาย 1 เป้านอกวง ดาเมจ 32\nลูกแก้วดำเสริมดาเมจกระแทกเหมือนลูกไฟ",
		"tags": [&"ground_area", &"fire", &"charge"]}}
const DEFAULT_SLOTS := [CHARGED_FIRE_ID, ICE_VOLLEY_ID, CHAIN_LIGHTNING_ID]
const ICE_VOLLEY := {
	"ice_angles": [0.0, -9.0, 9.0],
	"damage": 24.0, "projectile_radius": .21, "projectile_speed": 10.0, "knockback": .5,
}
const CHAIN_LIGHTNING := {
	"damage": 60.0, "projectile_radius": .24, "projectile_speed": 16.0, "knockback": .5,
	"chain_radius": 3.0, "chain_damage": [45.0, 34.0],
}
const ATTACK := {
	"kind": "projectile", "element": "fire",
	"windup": 0.28, "active": 0.10, "recovery": 0.82,
	"damage": BASE_WEAPON_POWER, "reach": 6.0, "arc": 0.0,
	"projectile_range": 6.0, "projectile_speed": 8.0,
	"projectile_radius": 0.24, "knockback": 1.4,
}
const CAST_PROFILES := [
	{},
	{"damage": 84.0, "projectile_radius": .34,
		"splash_radius": 1.4, "splash_damage": 36.0, "splash_on_stop": true},
	{"damage": 135.0, "projectile_radius": .48,
		"splash_radius": 2.0, "splash_damage": 65.0, "splash_on_stop": true,
		"pierce_after_exit": .75, "max_targets": 2, "pierce_damage_multiplier": .75,
		"ground_fire": true},
]

var cast_tier:=1
var element := "fire"
var cast_orbs: Array[String] = []
var cast_skill := ""
var cast_scale := Vector2.ONE
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
	result.merge(CAST_PROFILES[cast_tier - 1], true)
	if cast_tier == 1 and cast_skill.is_empty(): result.basic_staff_art = true
	if cast_skill == CHARGED_FIRE_ID: result.charged_fire_art = true
	if cast_skill == ICE_VOLLEY_ID: result.merge(ICE_VOLLEY, true)
	if cast_skill == CHAIN_LIGHTNING_ID: result.merge(CHAIN_LIGHTNING, true)
	var orb_scale := orb_multipliers(element, cast_orbs) if not cast_orbs.is_empty() else Vector2.ONE
	var bonus := cast_scale * orb_scale
	result.damage *= bonus.x
	if result.has("splash_damage"): result.splash_damage *= bonus.x
	if result.has("splash_radius"): result.splash_radius *= bonus.y
	elif cast_skill == ICE_VOLLEY_ID: result.projectile_radius *= orb_scale.y
	elif cast_skill == CHAIN_LIGHTNING_ID:
		result.chain_radius *= bonus.y
		var jumps: Array[float] = []
		for damage: float in result.chain_damage: jumps.append(damage * bonus.x)
		result.chain_damage = jumps
	result.element=element
	result.cast_tier=cast_tier
	return result

static func orb_multipliers(spell_element: String, orbs: Array[String]) -> Vector2:
	var matching := orbs.count(spell_element) + orbs.count(Charge.NEUTRAL)
	var weakness := orbs.count(WEAK_TO[spell_element])
	var neutral := orbs.size() - matching - weakness
	return Vector2(1.0 + .05 * (matching - weakness), 1.0 + .01 * neutral)

static func level_steps(id: String, level: int) -> int:
	if not SKILLS.has(id): return 0
	return floori(maxi(0, level - int(SKILLS[id].level)) / 3.0)

static func scaling(id: String, power: float, intelligence: float, level: int) -> Vector2:
	var steps := level_steps(id, level)
	var int_bonus := .01 * maxf(0.0, intelligence - 3.0)
	var damage := maxf(1.0, power) / BASE_WEAPON_POWER * (1.0 + int_bonus) * (1.0 + .08 * steps)
	return Vector2(damage, 1.0 + .02 * steps)

static func charge_speed(intelligence: float) -> float:
	return 1.0 + minf(.20, .01 * maxf(0.0, intelligence - 3.0))

static func focus_cooldown(level: int) -> float:
	return float(SKILLS[FOCUS_ID].cooldown) - mini(5, level_steps(FOCUS_ID, level))

static func mana_refund(level: int) -> float:
	return MANA_FIELD_REFUND + mini(4, level_steps(MANA_FIELD_ID, level))

static func ground_spell(id: String, orbs: Array[String], scale: Vector2 = Vector2.ONE, level: int = 1) -> Dictionary:
	match id:
		ICE_CRYSTAL_ID:
			var bonus := orb_multipliers("ice", orbs) * scale
			return {"radius": ICE_CRYSTAL_RADIUS * bonus.y, "duration": ICE_CRYSTAL_DELAY,
				"damage": ICE_CRYSTAL_DAMAGE * bonus.x, "color": Color("#83dcff"), "element": "ice"}
		MANA_FIELD_ID:
			return {"radius": MANA_FIELD_RADIUS * scale.y * (1.0 + .05 * orbs.count("ice")), "refund": mana_refund(level),
				"duration": MANA_FIELD_DURATION + orbs.count("lightning") + orbs.count(Charge.NEUTRAL) - orbs.count("fire"),
				"color": Color("#c29aff")}
		METEOR_ID:
			var fire_orbs := orbs.count("fire") + orbs.count(Charge.NEUTRAL)
			return {"radius": METEOR_RADIUS * scale.y * (1.0 + .05 * orbs.count("ice")),
				"duration": METEOR_DELAY, "damage": METEOR_DAMAGE * scale.x * (1.0 + .05 * fire_orbs),
				"sparks": orbs.count("lightning"), "spark_damage": METEOR_SPARK_DAMAGE * scale.x,
				"color": Color("#ff9b53"), "element": "fire"}
	return {}
func set_cast_tier(tier: int, shot_element: String = "fire", orbs: Array[String] = [], skill: String = "", scale: Vector2 = Vector2.ONE) -> void:
	cast_tier=clampi(tier,1,3)
	element=shot_element
	cast_orbs.assign(orbs)
	cast_skill = skill
	cast_scale = scale

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
