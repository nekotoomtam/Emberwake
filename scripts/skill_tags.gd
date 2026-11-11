extends RefCounted

const AREA := &"area"
const GROUND_AREA := &"ground_area"
const GROUND_IMPACT := &"ground_impact"
const PERSISTENT_AREA := &"persistent_area"
const SWEEP := &"sweep"
const MULTI_HIT := &"multi_hit"
const CHARGE := &"charge"
const PULL := &"pull"
const BUFF := &"buff"
const PROJECTILE := &"projectile"
const FIRE := &"fire"
const LEAP := &"leap"
const PARRY := &"parry"
const ARMOR_BREAK := &"armor_break"
const THRUST := &"thrust"
const STANCE := &"stance"
const SPIN := &"spin"
const WAVE := &"wave"
const PIERCE := &"pierce"
const PUSH := &"push"

const LABELS := {
	AREA: "พื้นที่",
	GROUND_AREA: "มีผลบนพื้น",
	GROUND_IMPACT: "ทุบพื้น",
	PERSISTENT_AREA: "พื้นที่คงอยู่",
	SWEEP: "ฟาดกวาด",
	MULTI_HIT: "โจมตีหลายจังหวะ",
	CHARGE: "ชาร์จ",
	PULL: "รวบศัตรู",
	BUFF: "บัฟ",
	PROJECTILE: "ลูกยิง",
	FIRE: "ไฟ",
	LEAP: "กระโดด",
	PARRY: "แพร์รี",
	ARMOR_BREAK: "เปิดเกราะ",
	THRUST: "แทง",
	STANCE: "ตั้งท่า",
	SPIN: "หมุนฟัน",
	WAVE: "คลื่นดาบ",
	PIERCE: "ทะลุเป้า",
	PUSH: "ผลักศัตรู",
}

static func has_tag(definition: Dictionary, tag: StringName) -> bool:
	return tag in definition.get("tags", [])

static func label(tags: Array) -> String:
	var names := PackedStringArray()
	for tag: StringName in tags:
		if LABELS.has(tag):
			names.append(LABELS[tag])
	return " • ".join(names)
