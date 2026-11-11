extends RefCounted
const SkillTags = preload("res://scripts/skill_tags.gd")
const STORM_BLADE_DURATION := 5.0
## Authored one-handed skills. Sequencing and resource spending belong to the actor.
## Angles remain unwrapped across active frames so a whole revolution is measurable.
const EPSILON := 0.00000001
const DEFAULT_SLOTS := ["impaling_thrust", "double_slash", "spinning_slash"]
const SKILLS := {
	"impaling_thrust": {"name": "ก้าวแทง", "level": 5, "description": "พุ่งแทงตรงในแนวแคบ ดาเมจ 43 เป้าที่โดนเสียหลัก 0.20 วิและเปิดเกราะ 1 ชั้น", "cost": 16.0, "resource": "mana", "cooldown": 4.0,
		"tags": [SkillTags.THRUST, SkillTags.ARMOR_BREAK]},
	"double_slash": {"name": "ฟันกลับคู่", "level": 5, "description": "ฟันเร็วสองคม ดาเมจ 23 + 26 โดนเป้าเดิมทั้งสองคมทำให้เสียหลัก 0.25 วิ", "cost": 20.0, "resource": "mana", "cooldown": 5.0,
		"tags": [SkillTags.SWEEP, SkillTags.MULTI_HIT]},
	"square_off": {"name": "ตั้งคมเปิดช่อง", "level": 10, "description": "ตั้งท่าแล้วคลิกซ้ายฟันงัด ดาเมจ 47 และทำให้เสียหลัก 0.30 วิ หรือคลิกขวาพุ่งแทง ดาเมจ 53", "cost": 22.0, "resource": "mana", "cooldown": 6.0,
		"tags": [SkillTags.STANCE], "stage_tags": {1: [SkillTags.SWEEP], 2: [SkillTags.THRUST]}},
	"sword_dance": {"name": "ระบำรุก", "level": 10, "description": "ก้าวฟันสองครั้งก่อนหมุนฟันรอบตัว ดาเมจ 22 + 22 + 40 คมสุดท้ายทำให้เสียหลัก 0.25 วิ", "cost": 28.0, "resource": "mana", "cooldown": 8.0,
		"tags": [SkillTags.SWEEP, SkillTags.MULTI_HIT, SkillTags.SPIN],
		"stage_tags": {0: [SkillTags.SWEEP], 1: [SkillTags.SWEEP], 2: [SkillTags.SWEEP, SkillTags.SPIN]}},
	"spinning_slash": {"name": "พายุสองคม", "level": 15, "description": "หมุนตัวฟันรอบกายสองรอบ ดาเมจรอบละ 30 ต่อเป้าที่โดน", "cost": 26.0, "resource": "mana", "cooldown": 7.0,
		"tags": [SkillTags.SWEEP, SkillTags.SPIN, SkillTags.MULTI_HIT]},
	"storm_blade": {"name": "ปาดคลื่นดาบ", "level": 15, "description": "เคลือบลมที่ดาบ 5 วิ โจมตีเร็วขึ้น 10% และฟันปกติปล่อยหนึ่งคลื่น ดาเมจคลื่นตามลำดับคอมโบ 12 / 14 / 16", "cost": 24.0, "resource": "mana", "cooldown": 6.0,
		"tags": [SkillTags.BUFF], "wave_tags": [SkillTags.PROJECTILE, SkillTags.WAVE]},
	"stormcaller": {"name": "วงพายุคมดาบ", "level": 20, "description": "ก้าวตั้งดาบแล้วหมุนฟันอยู่กับที่สามรอบ ดาเมจ 27 + 31 + 35 กดทิศเพื่อพุ่งสั้น ๆ ระหว่างรอบ วงสุดท้ายผลักศัตรูออกแรง", "cost": 38.0, "resource": "mana", "cooldown": 12.0,
		"tags": [SkillTags.AREA, SkillTags.GROUND_AREA, SkillTags.SPIN, SkillTags.MULTI_HIT, SkillTags.PUSH]},
	"vacuum_slice": {"name": "ผ่าคลื่นสุญญากาศ", "level": 20, "description": "คลื่นระยะไกลทะลุศัตรู ดาเมจ 64 ต่อเป้าที่โดน และทำให้เสียหลัก 0.45 วิ", "cost": 34.0, "resource": "mana", "cooldown": 10.0,
		"tags": [SkillTags.PROJECTILE, SkillTags.WAVE, SkillTags.PIERCE]},
}
var family := "sword"
var skill_id := "impaling_thrust"
var busy := false
var stage := -1
var elapsed := 0.0
var aim_angle := 0.0
var _entry: Dictionary = {}
var _held: Dictionary = {}
var _projectile_emitted := false
var _thrust_interval: Dictionary = {}
var _radial_interval: Dictionary = {}
var _strength_points := 0.0
var _dexterity_points := 0.0
var _intelligence_points := 0.0

static func _bonus_points(attributes: Dictionary, key: String) -> float:
	return maxf(0.0, float(attributes.get(key, 3)) - 3.0)

static func mana_cost(id: String, attributes: Dictionary) -> float:
	var base_cost: float = SKILLS[id].cost
	if id in ["storm_blade", "vacuum_slice"]:
		return base_cost - minf(base_cost * .20, _bonus_points(attributes, "intelligence") * .5)
	return base_cost

func configure(id: String, attributes: Dictionary = {}) -> bool:
	if busy or not SKILLS.has(id): return false
	reset()
	skill_id = id
	_strength_points = _bonus_points(attributes, "strength")
	_dexterity_points = _bonus_points(attributes, "dexterity")
	_intelligence_points = _bonus_points(attributes, "intelligence")
	return true

func stage_count() -> int:
	return {"double_slash": 2, "square_off": 3, "sword_dance": 3, "spinning_slash": 2, "stormcaller": 3}.get(skill_id, 1)

func definition(index: int) -> Dictionary:
	if index < 0 or index >= stage_count(): return {}
	var d := {"kind": "sweep", "windup": .16, "active": .18, "recovery": .2, "damage": 25.0, "reach": 2.4, "width": .24, "arc": 1.8, "direction": -1.0, "pitch_from": .12, "pitch_to": -.12, "projectile": false, "lunge_distance": .0, "spin": false}
	var strength_damage := _strength_points * .015
	var dexterity_damage := _dexterity_points * .015
	var intelligence_damage := _intelligence_points * .015
	var quick_time := 1.0 - minf(.15, _dexterity_points * .0125)
	var precise_time := 1.0 - minf(.15, _dexterity_points * .0075)
	var wave_speed := 1.0 + minf(.15, _intelligence_points * .01)
	var damage_bonus := 0.0
	match skill_id:
		"impaling_thrust":
			d.merge({"kind": "thrust", "windup": .22, "active": .16, "recovery": .28, "damage": 43.0, "reach": 2.6, "width": .22, "arc": .0, "lunge_distance": 1.3, "stagger_duration": .20, "armor_stacks": 1}, true)
			damage_bonus = strength_damage + dexterity_damage * .5
			d.windup *= precise_time
		"double_slash":
			d.merge({"windup": .08, "active": .085, "recovery": .09, "arc": 2.16, "damage": 23.0 + index * 3, "direction": -1.0 if index == 0 else 1.0, "pitch_from": .4 if index == 0 else -.3, "pitch_to": -.3 if index == 0 else .4, "lunge_distance": .25}, true)
			damage_bonus = dexterity_damage
			_scale_stage_time(d, quick_time)
			if index == 1: d.repeat_target_stagger = .25
		"square_off":
			if index == 0: d.merge({"windup": .15, "active": 1.15, "recovery": .2, "damage": .0, "arc": .0}, true)
			elif index == 1: d.merge({"windup": .12, "active": .2, "damage": 47.0, "pitch_from": -.65, "pitch_to": .75, "arc": .7, "lunge_distance": .7, "stagger_duration": .30}, true)
			else: d.merge({"kind": "thrust", "windup": .18, "active": .2, "damage": 53.0, "reach": 2.75, "width": .24, "arc": .0, "lunge_distance": 1.8}, true)
			if index > 0:
				damage_bonus = dexterity_damage if index == 1 else strength_damage
				d.windup *= precise_time
		"sword_dance":
			d.merge({"windup": .12 if index < 2 else .20, "active": .14 if index < 2 else .40, "recovery": .12 if index < 2 else .22, "damage": 22.0 if index < 2 else 40.0, "pitch_from": -.6 if index < 2 else .0, "pitch_to": .6 if index < 2 else .0, "direction": -1.0 if index % 2 == 0 else 1.0, "arc": 1.8 if index < 2 else TAU, "spin": index == 2, "lunge_distance": .55 if index < 2 else .0}, true)
			if index < 2:
				damage_bonus = dexterity_damage
				_scale_stage_time(d, quick_time)
			else:
				damage_bonus = strength_damage
				d.stagger_duration = .25
		"spinning_slash":
			d.merge({"windup": .2 if index == 0 else .1, "active": .4, "recovery": .16, "damage": 30.0, "reach": 2.6, "arc": TAU, "spin": true, "pitch_from": .0, "pitch_to": .0, "lunge_distance": .3}, true)
			damage_bonus = strength_damage + dexterity_damage * .5
			d.windup *= precise_time
			d.recovery *= precise_time
		"storm_blade":
			d.merge({"windup": .12, "active": .10, "recovery": .15, "damage": .0, "projectile": false, "buff_duration": STORM_BLADE_DURATION, "arc": 2.4, "pitch_from": .25, "pitch_to": .7, "reach": 2.2}, true)
			d.windup *= precise_time
			d.wave_damage_multiplier = 1.0 + minf(.30, intelligence_damage)
			d.wave_speed_multiplier = wave_speed
		"stormcaller":
			d.merge({"windup": .3 if index == 0 else .14, "active": .55, "recovery": .2, "damage": 27.0 + index * 4, "reach": 2.2, "arc": TAU, "spin": true, "pitch_from": -.15, "pitch_to": .15, "radial": true, "effect_radius": 2.4 + index * .8, "ring_width": .2, "knockback": 9.0 if index == 2 else 1.1, "push": index == 2}, true)
			damage_bonus = strength_damage
			if index == 0:
				d.lunge_distance = .35
				d.windup_lunge = true
			if index == 2:
				damage_bonus += intelligence_damage * .5
				d.recovery *= precise_time
		"vacuum_slice":
			d.merge({"windup": .65, "active": .32, "recovery": .45, "damage": 64.0, "arc": .45, "pitch_from": 1.1, "pitch_to": -.8, "projectile": true, "projectile_speed": 8.0, "projectile_range": 13.0, "projectile_radius": .8, "stagger_duration": .45}, true)
			damage_bonus = intelligence_damage
			d.windup *= precise_time
			d.projectile_speed *= wave_speed
	var info: Dictionary = SKILLS[skill_id]
	d.tags = info.get("stage_tags", {}).get(index, info.tags)
	if skill_id == "stormcaller" and index < 2:
		d.tags = d.tags.filter(func(tag: StringName) -> bool: return tag != SkillTags.PUSH)
	d.damage *= 1.0 + minf(.30, damage_bonus)
	return d

func _scale_stage_time(definition: Dictionary, time_scale: float) -> void:
	definition.windup *= time_scale
	definition.active *= time_scale
	definition.recovery *= time_scale

func start(index: int, angle: float) -> bool:
	if busy or definition(index).is_empty() or not is_finite(angle): return false
	aim_angle = wrapf(angle, -PI, PI)
	_entry = sample()
	stage = index
	elapsed = 0.0
	_projectile_emitted = false
	_thrust_interval.clear()
	_radial_interval.clear()
	busy = true
	return true

## Capture the visible ordinary/previous skill pose after configure, before start.
## Actor travel is stage-local and intentionally excluded from the blade seed.
func seed_pose(pose: Dictionary) -> void:
	if busy: return
	var seeded := _rest()
	for key in ["angle", "radius", "pitch", "grip_height", "blade_length", "body_lean"]:
		if pose.has(key) and is_finite(float(pose[key])): seeded[key] = float(pose[key])
	_held = seeded

func advance(delta: float) -> Dictionary:
	_thrust_interval.clear()
	_radial_interval.clear()
	var angle: float = sample().angle
	var r := {"entered_active": false, "active": false, "damage_ready": false, "projectile_ready": false, "finished": false, "previous_angle": angle, "current_angle": angle, "trail_from": {}, "trail_to": {}}
	if not busy or not is_finite(delta) or delta <= 0: return r
	var d := definition(stage)
	var before := elapsed
	var end: float = d.windup + d.active
	var total: float = end + d.recovery
	elapsed = minf(elapsed + delta, total)
	r.entered_active = before < d.windup - EPSILON and elapsed >= d.windup - EPSILON
	r.active = before < end - EPSILON and elapsed >= d.windup - EPSILON
	r.damage_ready = r.active and d.damage > 0 and not d.projectile
	if r.active:
		r.trail_from = _active_pose(clampf((before - d.windup) / d.active, 0, 1))
		r.trail_to = _active_pose(clampf((elapsed - d.windup) / d.active, 0, 1))
		r.previous_angle = r.trail_from.angle
		r.current_angle = r.trail_to.angle
		if d.get("radial", false):
			r.effect_radius_from = r.trail_from.effect_radius
			r.effect_radius_to = r.trail_to.effect_radius
			_radial_interval = {"from": r.effect_radius_from, "to": r.effect_radius_to}
		if d.kind == "thrust":
			# The rigid blade translates along its locked axis. Cache its union
			# over this clipped frame, including frames spanning all of active.
			_thrust_interval = {"from": minf(r.trail_from.radius, r.trail_to.radius), "to": maxf(r.trail_from.radius + r.trail_from.blade_length, r.trail_to.radius + r.trail_to.blade_length)}
	var release_time: float = d.windup + d.active * .5
	if d.projectile and not _projectile_emitted and before < release_time and elapsed >= release_time:
		r.projectile_ready = true
		_projectile_emitted = true
	if elapsed >= total - EPSILON:
		_held = _pose_at(total)
		busy = false
		r.finished = true
	return r

func sample() -> Dictionary:
	if busy: return _pose_at(elapsed)
	var pose := _rest() if _held.is_empty() else _held.duplicate(true)
	pose.phase = "idle"
	pose.trail = false
	return pose

func _rest() -> Dictionary:
	return {"phase": "idle", "progress": .0, "angle": aim_angle + .35, "radius": .3, "pitch": .0, "grip_height": .68, "blade_length": 1.9, "body_lean": .0, "trail": false, "lunge_offset": .0, "body_spin": .0}

func _active_pose(p: float) -> Dictionary:
	var d := definition(stage)
	var pose := _rest()
	pose.phase = "active"
	pose.progress = p
	pose.angle = aim_angle + d.direction * d.arc * (p - .5)
	pose.pitch = lerpf(d.pitch_from, d.pitch_to, p)
	pose.radius = d.reach - cos(pose.pitch) * pose.blade_length
	pose.body_lean = lerpf(-.035, .09, p)
	pose.lunge_offset = d.lunge_distance if d.get("windup_lunge", false) else d.lunge_distance * _smooth(minf(p / .8, 1))
	pose.trail = d.damage > 0
	if d.kind == "thrust":
		pose.pitch = .0
		pose.radius = lerpf(.1, d.reach - pose.blade_length, minf(p / .8, 1))
	if d.spin: pose.body_spin = d.direction * TAU * p
	if d.get("radial", false):
		pose.radial = true
		pose.effect_radius = d.effect_radius * p
	if skill_id == "square_off" and stage == 0:
		pose.pitch = .18
		pose.radius = .12
		pose.body_lean = -.025
	return pose

func _pose_at(time: float) -> Dictionary:
	var d := definition(stage)
	if time < d.windup - EPSILON:
		var pose := _active_pose(0)
		pose.phase = "windup"
		pose.progress = clampf(time / d.windup, 0, 1)
		pose.trail = false
		if pose.get("radial", false): pose.effect_radius = .0
		var t := _smooth(pose.progress)
		if d.get("windup_lunge", false):
			pose.lunge_offset = d.lunge_distance * _smooth(minf(pose.progress / .7, 1.0))
		for key in ["angle", "radius", "pitch", "grip_height", "body_lean"]:
			pose[key] = lerpf(float(_entry.get(key, _rest()[key])), pose[key], t)
		pose.angle = lerp_angle(float(_entry.get("angle", _rest().angle)), _active_pose(0).angle, t)
		return pose
	if time < d.windup + d.active - EPSILON: return _active_pose(clampf((time - d.windup) / d.active, 0, 1))
	var pose := _active_pose(1)
	pose.phase = "recovery"
	pose.progress = clampf((time - d.windup - d.active) / d.recovery, 0, 1)
	pose.trail = false
	pose.radius = lerpf(pose.radius, .3, _smooth(pose.progress))
	pose.body_lean *= 1 - _smooth(pose.progress)
	return pose

func is_target_hit(origin: Vector3, target: Vector3, target_radius: float, from_angle: float, to_angle: float) -> bool:
	if stage < 0 or not origin.is_finite() or not target.is_finite() or not is_finite(target_radius) or target_radius < 0 or not is_finite(from_angle) or not is_finite(to_angle): return false
	var d := definition(stage)
	if d.damage <= 0 or d.projectile: return false
	var offset := Vector2(target.x - origin.x, target.z - origin.z)
	if d.get("radial", false):
		if _radial_interval.is_empty(): return false
		var padding: float = target_radius + d.ring_width * .5
		return offset.length() + padding >= _radial_interval.from - EPSILON and offset.length() - padding <= _radial_interval.to + EPSILON
	if d.kind == "thrust":
		if _thrust_interval.is_empty(): return false
		var direction := Vector2(cos(aim_angle), sin(aim_angle))
		var base: Vector2 = direction * _thrust_interval.from
		var tip: Vector2 = direction * _thrust_interval.to
		return offset.distance_to(Geometry2D.get_closest_point_to_segment(offset, base, tip)) <= target_radius + d.width * .5 + EPSILON
	if offset.length() > d.reach + target_radius + EPSILON: return false
	if offset.length() <= target_radius + EPSILON: return true
	var sweep := to_angle - from_angle
	if absf(sweep) >= TAU - EPSILON: return true
	var relative := wrapf(offset.angle() - from_angle, 0, TAU) if sweep >= 0 else wrapf(from_angle - offset.angle(), 0, TAU)
	if relative <= absf(sweep) + EPSILON: return true
	for angle in [from_angle, to_angle]:
		var tip: Vector2 = Vector2(cos(angle), sin(angle)) * d.reach
		if offset.distance_to(Geometry2D.get_closest_point_to_segment(offset, Vector2.ZERO, tip)) <= target_radius + EPSILON: return true
	return false

func rebase_idle_aim(angle: float) -> bool:
	if busy or not is_finite(angle): return false
	var next := wrapf(angle, -PI, PI)
	if not _held.is_empty(): _held.angle += wrapf(next - aim_angle, -PI, PI)
	aim_angle = next
	return true

func is_great_charging() -> bool:
	return false

func reset() -> void:
	busy = false
	stage = -1
	elapsed = 0
	aim_angle = 0
	_projectile_emitted = false
	_thrust_interval.clear()
	_radial_interval.clear()
	_entry.clear()
	_held.clear()

func _smooth(t: float) -> float:
	return t * t * (3 - 2 * t)
