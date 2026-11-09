extends RefCounted

const PARTS: Array[String] = [
	"head", "torso", "right_upper_arm", "left_upper_arm", "right_forearm", "left_forearm",
	"right_thigh", "left_thigh", "right_lower_leg", "left_lower_leg",
]
const STRIKE_TARGETS: Array[String] = [
	"right_upper_arm", "left_thigh", "torso", "left_upper_arm", "right_thigh",
	"head", "right_forearm", "left_lower_leg", "left_forearm", "right_lower_leg",
]
const LIMBS := {
	"right_arm": ["right_upper_arm", "right_forearm"],
	"left_arm": ["left_upper_arm", "left_forearm"],
	"right_leg": ["right_thigh", "right_lower_leg"],
	"left_leg": ["left_thigh", "left_lower_leg"],
}
const BODY_WEIGHTS := {
	"head": .20, "torso": .30,
	"right_upper_arm": .05, "left_upper_arm": .05, "right_forearm": .05, "left_forearm": .05,
	"right_thigh": .075, "left_thigh": .075, "right_lower_leg": .075, "left_lower_leg": .075,
}
const PROXIMAL := {
	"right_forearm": "right_upper_arm", "left_forearm": "left_upper_arm",
	"right_lower_leg": "right_thigh", "left_lower_leg": "left_thigh",
}

var reference_max_hp := 100.0
var _part_hp: Dictionary = {}
var integrity: Dictionary = {}
var missing: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	for id in PARTS:
		integrity[id] = 100.0
		missing[id] = false
		_part_hp[id] = part_max(id)


func bind_max_hp(value: float) -> void:
	if not is_finite(value) or value <= 0:
		return
	reference_max_hp = value
	for id in PARTS:
		_part_hp[id] = part_max(id) * float(integrity[id]) / 100.0


func part_hp(id: String) -> float:
	if LIMBS.has(id):
		return part_hp(LIMBS[id][0]) + part_hp(LIMBS[id][1])
	return float(_part_hp.get(id, 0.0)) if present(id) else 0.0


func part_max(id: String) -> float:
	if LIMBS.has(id):
		return part_max(LIMBS[id][0]) + part_max(LIMBS[id][1])
	return reference_max_hp * 2.5 * float(BODY_WEIGHTS.get(id, 0.0))


func present(id: String) -> bool:
	if LIMBS.has(id):
		return present(LIMBS[id][0])
	return id in PARTS and not missing[id] and (not PROXIMAL.has(id) or not missing[PROXIMAL[id]])


func functional(id: String) -> bool:
	if LIMBS.has(id):
		return functional(LIMBS[id][0]) and functional(LIMBS[id][1])
	return present(id) and float(integrity[id]) > 0


func dead() -> bool:
	return not functional("head")


func set_integrity(id: String, value: float) -> void:
	if LIMBS.has(id):
		for part: String in LIMBS[id]:
			set_integrity(part, value)
		return
	if not present(id) or not is_finite(value):
		return
	_set_part_hp(id, part_max(id) * clampf(value, 0, 100) / 100.0)


func reduce_all_integrity(amount: float) -> void:
	for id in PARTS:
		set_integrity(id, float(integrity[id]) - amount)


func _set_part_hp(id: String, value: float) -> void:
	_part_hp[id] = clampf(value, 0, part_max(id))
	integrity[id] = float(_part_hp[id]) / part_max(id) * 100.0


func restore(id: String) -> void:
	if LIMBS.has(id):
		for part: String in LIMBS[id]:
			restore(part)
	elif id in PARTS:
		missing[id] = false
		_set_part_hp(id, part_max(id))


func remove(id: String) -> void:
	if LIMBS.has(id):
		for part: String in LIMBS[id]:
			remove(part)
	elif id in PARTS:
		_set_part_hp(id, 0)
		if id != "torso":
			missing[id] = true
			for distal: String in PROXIMAL:
				if PROXIMAL[distal] == id:
					_set_part_hp(distal, 0)
					missing[distal] = true


func damage(id: String, amount: float, red: bool = false) -> void:
	if not is_finite(amount) or amount <= 0 or dead():
		return
	if LIMBS.has(id):
		var limb: Array = LIMBS[id]
		if present(limb[1]):
			damage(limb[1], amount * .5, red)
			damage(limb[0], amount * .5, red)
		else:
			damage(limb[0], amount, red)
		return
	if id not in PARTS:
		return
	if not present(id):
		id = "torso"
	var before: float = integrity[id]
	if id == "torso" and before <= 0:
		_set_part_hp("head", part_hp("head") - amount * .5)
		return
	_set_part_hp(id, part_hp(id) - amount)
	if id not in ["head", "torso"] and red and before <= 30 and float(integrity[id]) <= 0:
		remove(id)


func injured(id: String) -> bool:
	if LIMBS.has(id):
		return injured(LIMBS[id][0]) or injured(LIMBS[id][1])
	return present(id) and float(integrity[id]) <= 60.0


func weapon_speed(arm: String, two_hand: bool = false) -> float:
	if two_hand:
		return 1.0 - .05 * (int(injured("right_arm")) + int(injured("left_arm")))
	return .9 if arm in ["right_arm", "left_arm"] and injured(arm) else 1.0


func sight_multiplier() -> float:
	return .8 if injured("head") else 1.0


func action_cost_multiplier() -> float:
	return 1.2 if injured("torso") else 1.0


func dash_cost_multiplier() -> float:
	return 1.25 if injured("right_leg") or injured("left_leg") else 1.0


func arm_count() -> int:
	return int(functional("right_arm")) + int(functional("left_arm"))


func leg_count() -> int:
	return int(functional("right_leg")) + int(functional("left_leg"))


func hp_multiplier() -> float:
	var result := 1.0
	for id in PARTS:
		if id not in ["head", "torso"] and missing[id]:
			result -= float(BODY_WEIGHTS[id])
	return clampf(result, .5, 1)


func move_multiplier() -> float:
	var legs := leg_count()
	var arms := arm_count()
	var result := 1.0 if legs == 2 else (.7 if legs == 1 else (.22 if arms == 2 else (.12 if arms == 1 else .045)))
	return result * (.45 if not functional("torso") else 1.0)


func dash_multiplier() -> float:
	return 1.0 if leg_count() == 2 else (.6 if leg_count() == 1 else (.25 if arm_count() > 0 else 0.0))


func capability_key() -> String:
	var key := ""
	for id in PARTS:
		key += str(int(functional(id))) + str(int(missing[id]))
	return key
