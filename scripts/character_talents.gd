extends RefCounted
## Each row defines one mutually exclusive pair and the signed effects of its first member.
const MAX_SLOTS := 7
const MAX_RANK := 3
const START_SLOTS := 3
const TRADEOFF_START := 6
const PAIRS := [
	["มือไว", "มือช้า", {"attack_speed": [.05, .10, .15]}],
	["ฟื้นตัวไว", "ฟื้นตัวช้า", {"flask_heal": [.08, .15, .22]}],
	["ใจนิ่ง", "ขวัญเสียง่าย", {"stand_up_sanity": [-2, -5, -8]}],
	["อึด", "เหนื่อยง่าย", {"max_stamina": [.05, .10, .15]}],
	["มานาเหลือเฟือ", "มานาพร่อง", {"max_mana": [.05, .10, .15]}],
	["ตาไว", "สายตาสั้น", {"sight_range": [.05, .10, .15]}],
	["มือหนัก", "มือเบา", {"melee_damage": [.08, .15, .22], "melee_speed": [-.05, -.10, -.15]}],
	["เล็งนิ่ง", "ขึ้นลำไว", {"spread": [-.08, -.15, -.22], "reload_speed": [-.05, -.10, -.15]}],
	["เชี่ยวชาญกระบวนท่า", "ออมพลัง", {"skill_cooldown": [-.05, -.10, -.15], "skill_mana": [.04, .08, .12]}],
	["กวาดวงกว้าง", "ลงมือฉับไว", {"skill_area": [.05, .10, .15], "area_windup": [.05, .10, .15]}],
	["ก้าวยาว", "ก้าวประหยัด", {"dash_distance": [.05, .10, .15], "dash_cost": [.05, .10, .15]}],
	["ยืนรับแรง", "ตัวเบา", {"physical_taken": [-.03, -.06, -.09], "move_speed": [-.03, -.06, -.09]}],
	["ถนัดประชิด", "ถนัดระยะไกล", {"near_damage": [.05, .10, .15], "far_damage": [-.05, -.10, -.15]}],
	["ตั้งหลักไว", "รวมสมาธิไว", {"stamina_regen": [.08, .15, .22], "mana_regen": [-.08, -.15, -.22]}],
	["มือช่วยชีวิต", "เอาตัวรอดเก่ง", {"revive_time": [-.10, -.20, -.30], "stand_up_health": [-.03, -.06, -.09]}],
]
const EFFECT_LABELS := {
	"attack_speed": "ความเร็วโจมตี", "flask_heal": "การฟื้นเลือดจากยา",
	"stand_up_sanity": "สติที่เพิ่มตอนลุก", "max_stamina": "ความอึดสูงสุด",
	"max_mana": "มานาสูงสุด", "sight_range": "ระยะมองเห็น",
	"melee_damage": "ดาเมจตีประชิดปกติ", "melee_speed": "ความเร็วตีประชิดปกติ",
	"spread": "การกระจายกระสุน", "reload_speed": "ความเร็วรีโหลด",
	"skill_cooldown": "คูลดาวน์สกิล", "skill_mana": "มานาที่ใช้กับสกิล",
	"skill_area": "รัศมีสกิลพื้นที่", "area_windup": "เวลาง้างสกิลพื้นที่",
	"dash_distance": "ระยะแดช", "dash_cost": "ความอึดที่ใช้แดช",
	"physical_taken": "ดาเมจกายภาพที่ได้รับ", "move_speed": "ความเร็วเคลื่อนที่",
	"near_damage": "ดาเมจในระยะ 3 เมตร", "far_damage": "ดาเมจเกิน 3 เมตร",
	"stamina_regen": "การฟื้นความอึด", "mana_regen": "การฟื้นมานา",
	"revive_time": "เวลาช่วยเพื่อนลุก", "stand_up_health": "สัดส่วนเลือดที่คืนตอนลุก",
}

static func roll_start(rng: RandomNumberGenerator) -> Dictionary:
	var result := {}
	var tradeoff := rng.randi_range(TRADEOFF_START, PAIRS.size() - 1)
	var pool := range(PAIRS.size())
	pool.erase(tradeoff)
	for index in START_SLOTS:
		var pair: int = tradeoff if index == 0 else pool.pop_at(rng.randi_range(0, pool.size() - 1))
		result[pair * 2 + rng.randi_range(0, 1)] = 2 if rng.randf() < .20 else 1
	return result

static func grant(entries: Dictionary, id: int) -> bool:
	if id < 0 or id >= PAIRS.size() * 2: return false
	if entries.has(id):
		if int(entries[id]) >= MAX_RANK: return false
		entries[id] += 1
		return true
	if entries.size() >= MAX_SLOTS or entries.has(id ^ 1): return false
	entries[id] = 1
	return true

static func roll_gain(entries: Dictionary, rng: RandomNumberGenerator) -> int:
	var eligible: Array[int] = []
	for id in PAIRS.size() * 2:
		if entries.has(id):
			if int(entries[id]) < MAX_RANK: eligible.append(id)
		elif entries.size() < MAX_SLOTS and not entries.has(id ^ 1):
			eligible.append(id)
	if eligible.is_empty(): return -1
	var id: int = eligible[rng.randi_range(0, eligible.size() - 1)]
	grant(entries, id)
	return id

static func bonuses(entries: Dictionary) -> Dictionary:
	var result := {}
	for id: int in entries:
		if id < 0 or id >= PAIRS.size() * 2: continue
		var effects: Dictionary = PAIRS[id >> 1][2]
		var rank := clampi(int(entries[id]), 1, MAX_RANK)
		var sign_factor := 1.0 if id % 2 == 0 else -1.0
		for effect: String in effects:
			result[effect] = float(result.get(effect, 0.0)) + float(effects[effect][rank - 1]) * sign_factor
	return result

static func title(id: int, rank: int) -> String:
	return "%s Lv%d" % [PAIRS[id >> 1][id % 2], rank]

static func summary(entries: Dictionary, detailed: bool = false) -> String:
	var lines := PackedStringArray()
	for id: int in entries:
		var line := title(id, entries[id])
		if detailed:
			var effects := PackedStringArray()
			for key: String in PAIRS[id >> 1][2]:
				var amount: float = PAIRS[id >> 1][2][key][int(entries[id]) - 1] * (1.0 if id % 2 == 0 else -1.0)
				var unit := "%" if key != "stand_up_sanity" else ""
				if key == "stand_up_health": unit = " จุดเปอร์เซ็นต์"
				var displayed := roundi(amount if key == "stand_up_sanity" else amount * 100.0)
				effects.append("%s %+d%s" % [EFFECT_LABELS[key], displayed, unit])
			line += "   ·   " + " / ".join(effects)
		lines.append(line)
	return "\n".join(lines)
