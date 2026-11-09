extends RefCounted
signal changed
const CAPACITY := 20
const FAMILIES := ["sword", "mace", "pistol", "greatsword", "staff", "rifle", "bow", "crossbow", "shield"]
const NAMES := {"sword":"ดาบมือเดียว", "mace":"กระบอง", "pistol":"ปืนพก", "greatsword":"ดาบใหญ่", "staff":"คทาไฟ", "rifle":"ปืนยาว", "bow":"ธนู", "crossbow":"หน้าไม้", "shield":"โล่"}
const TWO_HAND := ["greatsword", "staff", "rifle", "bow", "crossbow"]
var items: Dictionary = {}
var bag: Array = []
var sets: Array = []
var active := 0
var message := "เลือกของแล้วคลิกช่อง หรือ ลากวาง • คลิกขวาที่ช่องเพื่อถอด"
var save_path := "user://arsenal-v24.json"

func _init() -> void:
	defaults()

func defaults() -> void:
	items.clear()
	bag.clear()
	bag.resize(CAPACITY)
	bag.fill("")
	var index := 0
	for family: String in FAMILIES:
		for copy in range(2):
			var id := family + str(copy)
			items[id] = {"family":family, "name":NAMES[family], "two_hand":family in TWO_HAND}
			bag[index] = id
			index += 1
	sets = [{"main":"sword0", "off":"pistol0"}, {"main":"greatsword0", "off":""}]
	for id in ["sword0", "pistol0", "greatsword0"]: bag[bag.find(id)] = ""
	active = 0

func item_at(location: Dictionary) -> String:
	if location.get("kind", "") == "bag":
		var index := int(location.get("index", -1))
		return str(bag[index]) if index >= 0 and index < CAPACITY else ""
	var index := int(location.get("set", -1))
	var hand: String = location.get("hand", "")
	return str(sets[index][hand]) if index in [0,1] and hand in ["main","off"] else ""

func _put(location: Dictionary, id: String) -> void:
	if location.kind == "bag": bag[int(location.index)] = id
	else: sets[int(location.set)][str(location.hand)] = id

func valid_location(location: Dictionary) -> bool:
	return (location.get("kind") == "bag" and int(location.get("index", -1)) >= 0 and int(location.get("index", -1)) < CAPACITY) or (location.get("kind") == "slot" and int(location.get("set", -1)) in [0,1] and location.get("hand") in ["main","off"])

func move_item(source: Dictionary, target: Dictionary) -> bool:
	if not valid_location(source) or not valid_location(target): return false
	var id := item_at(source)
	if id.is_empty() or source == target: return false
	var before_bag := bag.duplicate()
	var before_sets := sets.duplicate(true)
	var displaced := item_at(target)
	_put(source, displaced)
	_put(target, id)
	# A two-handed weapon reserves the off hand; return that item to the bag.
	for pair: Dictionary in sets:
		if not str(pair.main).is_empty() and items[pair.main].two_hand and not str(pair.off).is_empty():
			var free := bag.find("")
			if free < 0:
				bag = before_bag; sets = before_sets
				message = "ช่องเก็บของเต็ม ต้องมีที่ว่างสำหรับมือรอง"
				return false
			# Dropping into a reserved off slot is an invalid operation.
			if target.kind == "slot" and target.hand == "off" and sets[int(target.set)] == pair:
				bag = before_bag; sets = before_sets
				message = "อาวุธสองมือใช้ทั้งสองช่อง กรุณาถอดมือหลักก่อน"
				return false
			bag[free] = pair.off
			pair.off = ""
	if not valid_state():
		bag = before_bag; sets = before_sets
		message = "อาวุธสองมือต้องใส่ช่องมือหลัก"
		return false
	message = "ใส่ " + str(items[id].name) + " แล้ว"
	save_data()
	changed.emit()
	return true

func unequip(location: Dictionary) -> bool:
	var free := bag.find("")
	if free < 0:
		message = "ช่องเก็บของเต็ม"
		return false
	return move_item(location, {"kind":"bag", "index":free})

func valid_state() -> bool:
	if bag.size() != CAPACITY or sets.size() != 2 or active not in [0,1]: return false
	var seen: Array = []
	for id in bag:
		if not id is String: return false
		if id != "":
			if not items.has(id) or id in seen: return false
			seen.append(id)
	for pair in sets:
		if not pair is Dictionary or not pair.has_all(["main","off"]): return false
		for hand in ["main","off"]:
			var id = pair[hand]
			if not id is String: return false
			if id != "":
				if not items.has(id) or id in seen: return false
				seen.append(id)
		if pair.off != "" and items[pair.off].two_hand: return false
		if pair.main != "" and items[pair.main].two_hand and pair.off != "": return false
	return seen.size() == items.size()

func primary(index: int = -1) -> String:
	var pair: Dictionary = sets[active if index < 0 else index]
	return str(pair.main) if pair.main != "" else str(pair.off)

func for_pair() -> Array:
	var pair: Dictionary = sets[active]
	if pair.main != "" and pair.off != "": return [str(pair.main), str(pair.off)]
	var id := primary()
	return [] if id == "" else [id]

func save_data() -> bool:
	if save_path == "": return true
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"version":4, "bag":bag, "sets":sets, "active":active}))
	file.close()
	return DirAccess.rename_absolute(save_path + ".tmp", save_path) == OK

func load_data() -> bool:
	if save_path == "" or not FileAccess.file_exists(save_path): return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(save_path)) != OK: return false
	var data = parser.data
	if not data is Dictionary or (data.get("version") != 1 and data.get("version") != 2 and data.get("version") != 3 and data.get("version") != 4) or not data.get("bag") is Array or not data.get("sets") is Array: return false
	if not data.get("active",0) is float and not data.get("active",0) is int: return false
	var old_bag := bag.duplicate(); var old_sets := sets.duplicate(true); var old_active := active
	bag = data.bag; sets = data.sets; active = int(data.get("active",0))
	var additions: Array[String] = []
	if data.version == 1: additions.append_array(["bow0", "bow1"])
	if data.version <= 2: additions.append_array(["crossbow0", "crossbow1"])
	if data.version <= 3: additions.append_array(["shield0", "shield1"])
	for id in additions:
		var free := bag.find("")
		if free >= 0: bag[free] = id
	if not valid_state():
		bag = old_bag; sets = old_sets; active = old_active
		return false
	return true
