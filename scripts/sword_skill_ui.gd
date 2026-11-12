extends CanvasLayer
const Motion = preload("res://scripts/sword_skill_motion.gd")
const MaceSkills = preload("res://scripts/mace_skill_motion.gd")
const RifleSkills = preload("res://scripts/rifle_motion.gd")
const StaffSkills = preload("res://scripts/staff_motion.gd")
const SkillTags = preload("res://scripts/skill_tags.gd")
var game
var model
var surface: Control
var combat_bar: HBoxContainer
var catalog: Control
var catalog_panel: PanelContainer
var status: Label
var slot_buttons: Array[Button] = []
var equip_buttons: Array = []
var catalog_details: Dictionary = {}
var catalog_rows: Dictionary = {}
var catalog_title: Label

func _label(value: String, font_size: int = 16) -> Label:
	var result := Label.new()
	result.text = value
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", font_size)
	return result

func _ready() -> void:
	layer = 23
	surface = Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Tahoma", "sans-serif"])
	theme.default_font = font
	surface.theme = theme
	add_child(surface)
	combat_bar = HBoxContainer.new()
	surface.add_child(combat_bar)
	combat_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	combat_bar.offset_left = -255
	combat_bar.offset_right = 255
	combat_bar.offset_top = -292
	combat_bar.offset_bottom = -232
	combat_bar.add_theme_constant_override("separation", 6)
	for i in range(3):
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(func():
			if not _is_charge_slot(i): game.request_skill_slot(i))
		button.button_down.connect(func():
			if _is_charge_slot(i): game.request_skill_slot(i, true))
		button.button_up.connect(func():
			if _is_charge_slot(i): game.release_charged_skill_slot(i))
		combat_bar.add_child(button)
		slot_buttons.append(button)
	_build_catalog()
	model.changed.connect(refresh)
	surface.resized.connect(_layout_catalog)
	_layout_catalog()
	refresh()

func _build_catalog() -> void:
	catalog = Control.new()
	surface.add_child(catalog)
	catalog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.04, 0.93)
	catalog.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catalog_panel = PanelContainer.new()
	catalog.add_child(catalog_panel)
	catalog_panel.add_theme_stylebox_override("panel", game.ui.panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	catalog_panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	catalog_title = _label("", 24)
	catalog_title.max_lines_visible = 1
	catalog_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(catalog_title)
	var close := Button.new()
	close.text = "กลับ [K / ESC]"
	close.pressed.connect(func(): game.toggle_sword_skills())
	header.add_child(close)
	var introduction := _label("ต้นแบบ: ปลดล็อกทุกสกิลให้ทดลอง • Lv เป็นระดับปลดล็อกที่วางไว้\nใช้ 1 / 2 / 3 เมื่อถืออาวุธที่ตรงกับชุดสกิล", 15)
	# Bound wrapped text before the first container pass, when its width is zero.
	# The catalog body must yield height to the scroll viewport immediately.
	introduction.max_lines_visible = 2
	column.add_child(introduction)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	for id: String in model.SKILL_IDS + MaceSkills.SKILLS.keys() + RifleSkills.SKILLS.keys() + StaffSkills.SKILLS.keys():
		var info := _skill_info(id)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		list.add_child(row)
		catalog_rows[id] = row
		row.add_child(_label("%s   •   Lv %d" % [info.name, info.level], 19))
		var details := _label("", 15)
		catalog_details[id] = details
		row.add_child(details)
		var choices := HBoxContainer.new()
		row.add_child(choices)
		for slot in range(3):
			var button := Button.new()
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(_equip.bind(slot, id))
			choices.add_child(button)
			equip_buttons.append({"button": button, "id": id, "slot": slot})
		row.add_child(HSeparator.new())
	status = _label("", 15)
	status.max_lines_visible = 2
	status.custom_minimum_size.y = 38
	column.add_child(status)

func _layout_catalog() -> void:
	if catalog_panel == null: return
	var available := surface.size
	var dimensions := Vector2(minf(880, available.x - 48), maxf(300, available.y - 64))
	catalog_panel.position = (available - dimensions) * 0.5
	catalog_panel.size = dimensions

func _equip(slot: int, id: String) -> void:
	model.equip_skill(slot, id)
	refresh()

func _cost_label(cost: float) -> String:
	return "มานา %s" % String.num(cost, 2)

func _catalog_family() -> String:
	var family: String = game.primary_family()
	return family if family in ["mace", "rifle", "staff"] else "sword"

func _skill_family(id: String) -> String:
	if RifleSkills.SKILLS.has(id): return "rifle"
	if StaffSkills.SKILLS.has(id): return "staff"
	if MaceSkills.SKILLS.has(id): return "mace"
	return "sword"

func _skill_info(id: String) -> Dictionary:
	match _skill_family(id):
		"rifle": return RifleSkills.SKILLS[id]
		"staff": return StaffSkills.SKILLS[id]
		"mace": return MaceSkills.SKILLS[id]
		_: return Motion.SKILLS[id]

func _skill_cost(id: String, info: Dictionary) -> float:
	var family := _skill_family(id)
	if family == "staff": return game.staff_skill_cost(id)
	var base_cost := float(info.cost)
	if family == "rifle": base_cost = RifleSkills.skill_cost(id, game.stats.attributes)
	elif family == "sword": base_cost = Motion.mana_cost(id, game.stats.attributes)
	return base_cost * game.stats.talent_factor("skill_mana")

func _rifle_description(id: String, info: Dictionary) -> String:
	var profile: Dictionary = game.rifle_projectile_profile(id)
	if profile.is_empty():
		var ammo_note := "กระสุนธรรมดาใช้ 100% ของพลังยิงก่อนสเกล DEX" if id == RifleSkills.REFILL_SKILL_ID else "ดาเมจตามชนิดกระสุนที่ยิง"
		return "%s • %s" % [ammo_note, info.description]
	var ratio := _power_percent(profile.power_ratio)
	var damage := String.num(profile.damage, 2)
	match id:
		RifleSkills.SPLIT_ROUND_ID:
			ratio += " ก่อนแตก / %s ในกรวย" % _power_percent(profile.rifle_split.power_ratio)
			damage += " ก่อนแตก / %s ต่อเป้าในกรวย" % String.num(profile.rifle_split.damage, 2)
		RifleSkills.SCATTER_ROUND_ID:
			ratio += " ต่อเม็ด"
			damage += " ต่อเม็ด"
	return "%s ของพลังยิง • ดาเมจปัจจุบัน %s\n%s" % [ratio, damage, info.description]

func _is_charge_slot(index: int) -> bool:
	if game.primary_family() == "staff":
		return StaffSkills.SKILLS.get(model.staff_skill_slots[index], {}).has("charge_time")
	return game.primary_family() == "mace" and MaceSkills.SKILLS[model.mace_skill_slots[index]].get("chargeable", false)

func _mace_damage_label(id: String, info: Dictionary) -> String:
	var first := _power_percent(info.power_ratio)
	match id:
		"mace_sweep": return first + " + " + _power_percent(MaceSkills.SECOND_SWEEP.power_ratio)
		"mace_double_impact": return first + " + " + _power_percent(MaceSkills.SECOND_IMPACT.power_ratio)
		"mace_earth_wave":
			var grades := PackedStringArray()
			for grade in MaceSkills.LEAP_GRADES:
				grades.append("%s/%s" % [_power_percent(grade.power_ratio), _power_percent(grade.edge_power_ratio)])
			return " → ".join(grades) + " (โคน/ปลายกรวย)"
		"mace_aftershock": return first + " ตอนวาง"
		"mace_fissure": return "คมงัด %s / ระเบิดไฟ %s" % [_power_percent(info.lift_power_ratio), _power_percent(info.blast_power_ratio)]
	return first

func _power_percent(ratio: float) -> String:
	return "%s%%" % String.num(ratio * 100.0, 1)

func refresh() -> void:
	if status == null: return
	status.text = model.message
	var family := _catalog_family()
	catalog_title.text = "สกิล%s • เลือกติดตั้ง 3 ช่อง" % {"sword": "ดาบ", "mace": "กระบอง", "rifle": "ปืนยาว", "staff": "คทา"}[family]
	for id: String in catalog_details:
		var row_family := _skill_family(id)
		catalog_rows[id].visible = family == row_family
		var info := _skill_info(id)
		var cost := _skill_cost(id, info)
		var cooldown: float = info.cooldown
		var description: String = info.description
		if row_family == "sword":
			description = "%s\n%s" % [Motion.power_label(id), description]
		elif row_family == "mace":
			description = "%s ของพลังอาวุธ • %s" % [_mace_damage_label(id, info), description]
		elif row_family == "rifle" and family == "rifle":
			cooldown = RifleSkills.skill_cooldown(id, game.stats.level)
			description = _rifle_description(id, info)
		elif row_family == "staff" and family == "staff":
			if id == StaffSkills.FOCUS_ID: cooldown = StaffSkills.focus_cooldown(game.stats.level)
			description += _staff_scaling_line(id, info)
		cooldown *= game.stats.talent_factor("skill_cooldown")
		catalog_details[id].text = "%s\n%s" % [_cost_label(cost), description] if row_family == "staff" and cooldown <= 0.0 else "%s • คูลดาวน์ %s วิ\n%s" % [_cost_label(cost), String.num(cooldown, 2), description]
		if not info.tags.is_empty():
			catalog_details[id].text += "\n" + SkillTags.label(info.tags)
		if info.has("impact_tags"):
			catalog_details[id].text += "\nระเบิดลูกไฟ • " + SkillTags.label(info.impact_tags)
		if info.has("wave_tags"):
			catalog_details[id].text += "\nคลื่นจากฟันปกติ • " + SkillTags.label(info.wave_tags)
	for entry: Dictionary in equip_buttons:
		var slots: Array = model.slots_for_family(_skill_family(entry.id))
		var equipped: bool = slots[entry.slot] == entry.id
		entry.button.text = ("✓ ช่อง %d" if equipped else "ใส่ช่อง %d") % (entry.slot + 1)
		entry.button.disabled = equipped
	_update_combat()

func _process(_delta: float) -> void:
	_update_combat()
	if catalog.visible: _layout_catalog()

func _staff_scaling_line(id: String, info: Dictionary) -> String:
	var details := PackedStringArray()
	if id == StaffSkills.MANA_FIELD_ID:
		details.append("คืน %s มานาต่อตัว" % String.num(StaffSkills.mana_refund(game.stats.level), 2))
	elif id != StaffSkills.FOCUS_ID:
		var scale: Vector2 = game.staff_skill_scaling(id)
		details.append("ดาเมจ ×%s ก่อนคิดธาตุ" % String.num(scale.x, 3))
	if info.has("charge_time"):
		details.append("ชาร์จ %s วิ" % String.num(game.staff_charge_time(id) / game.attack_rate(), 2))
	return "" if details.is_empty() else "\nค่าปัจจุบัน • " + " • ".join(details)

func _update_combat() -> void:
	if game == null or catalog == null: return
	catalog.visible = game.sword_skills_open
	var overlay: bool = game.inventory_open or game.stats_open or game.body_lab_open or game.sword_skills_open
	var peek = game.get("dungeon_peek")
	overlay = overlay or game.get("_arrival_locked") == true or (is_instance_valid(peek) and peek.visible)
	combat_bar.visible = game.mode in ["practice", "combat"] and not overlay
	var family := _catalog_family()
	var using_mace := family == "mace"
	var slots: Array = model.slots_for_family(family)
	var rifle_queue: Array[String] = []
	var rifle_capacity := 0
	var available := false
	match family:
		"rifle":
			var cycle = game.equipped_rifle_cycle()
			rifle_queue = game.rifle_display_queue()
			rifle_capacity = cycle.capacity
		"mace": available = game.mace_skills_available()
		"staff": pass
		_: available = game.sword_skills_available()
	for i in range(slot_buttons.size()):
		slot_buttons[i].visible = i < slots.size() and slots[i] != ""
		if not slot_buttons[i].visible: continue
		var id: String = slots[i]
		var info := _skill_info(id)
		var skill_available: bool = game.rifle_skills_available(id) if family == "rifle" else available
		if family == "staff": skill_available = game.staff_skills_available(id)
		var cooldown: float = float(game.sword_skill_cooldowns.get(id, 0.0))
		var cost := _skill_cost(id, info)
		var mana_short: bool = game.mana < cost
		var refill := int(info.get("refill", 0))
		var duration := float(info.get("duration", 0.0)) if family == "rifle" else 0.0
		var ammo_needed := int(info.get("rounds", 1))
		var ammo_short := family == "rifle" and duration == 0.0 and refill == 0 and rifle_queue.size() < ammo_needed
		var space_short := refill > 0 and rifle_capacity - rifle_queue.size() < refill
		var suffix := "พร้อม" if cooldown <= 0 else "%.1f วิ" % cooldown
		if cooldown <= 0 and mana_short: suffix = "มานาไม่พอ"
		if cooldown <= 0 and ammo_short: suffix = "ต้องมีกระสุน %d นัด" % ammo_needed
		if cooldown <= 0 and space_short: suffix = "ต้องมีช่องว่าง %d ช่อง" % refill
		if duration > 0.0 and game.rifle_rapid_fire_left() > 0.0:
			suffix = "บัฟ %.1f วิ" % game.rifle_rapid_fire_left()
		var queued := rifle_queue.count(id)
		if queued > 0:
			var position_hint := "นัดถัดไป" if rifle_queue[0] == id else "ในคิว"
			suffix += " • %s %d" % [position_hint, queued]
		if id == "storm_blade" and float(game.get("sword_wave_buff_left")) > 0.0:
			suffix = "บัฟ %.1f วิ" % float(game.sword_wave_buff_left)
		if id == "mace_fissure" and float(game.mace_fire_buff_left) > 0.0:
			suffix = "บัฟ %.1f วิ" % float(game.mace_fire_buff_left)
		var charge_grade: int = game.mace_charge_grade(i) if using_mace else 0
		if charge_grade > 0: suffix = "ชาร์จ %d/3 • ปล่อยเพื่อทุบ" % charge_grade
		var staff_charging: bool = family == "staff" and game.staff_skill_charging(i)
		if family == "staff":
			var orb_count := int(info.orbs)
			var breath_status: String = game.staff_breath_status(i)
			if not breath_status.is_empty():
				suffix = breath_status
			elif id == StaffSkills.FOCUS_ID and game.staff_energy.focus_left > 0.0:
				suffix = "บัฟ %.1f วิ" % game.staff_energy.focus_left
			elif staff_charging:
				var charge_label := "พร้อมปล่อย" if game.staff_energy.cast_ready() else "กำลังชาร์จ"
				if game.staff_energy.cast_ready() and &"ground_area" in info.tags: charge_label = "ปล่อยเพื่อลงวง"
				suffix = "%s • %d ลูก" % [charge_label, orb_count]
			elif not mana_short and game.staff_energy.units < orb_count:
				suffix = "ต้องมีลูกแก้ว %d ลูก" % orb_count
		slot_buttons[i].text = "[%d] %s\n%s" % [i + 1, info.name, suffix]
		if using_mace:
			slot_buttons[i].tooltip_text = "%s\n%s ของพลังอาวุธ • %s • คูลดาวน์ %s วิ • เลือกสกิล [K]" % [info.description, _mace_damage_label(id, info), _cost_label(cost), String.num(float(info.cooldown) * game.stats.talent_factor("skill_cooldown"), 2)]
		elif family == "rifle":
			var base_cooldown: float = RifleSkills.skill_cooldown(id, game.stats.level) * game.stats.talent_factor("skill_cooldown")
			slot_buttons[i].tooltip_text = "%s\n%s • คูลดาวน์ %s วิ • เลือกสกิล [K]" % [_rifle_description(id, info), _cost_label(cost), String.num(base_cooldown, 2)]
		elif family == "staff":
			var cost_text := _cost_label(cost)
			if id == StaffSkills.FOCUS_ID: cost_text += " • คูลดาวน์ %s วิ" % String.num(StaffSkills.focus_cooldown(game.stats.level) * game.stats.talent_factor("skill_cooldown"), 2)
			slot_buttons[i].tooltip_text = "%s%s\n%s • เลือกช่องสกิล [K]" % [info.description, _staff_scaling_line(id, info), cost_text]
		else:
			slot_buttons[i].tooltip_text = "%s\n%s\n%s • คูลดาวน์ %s วิ • ดูสกิลทั้งหมด [K]" % [Motion.power_label(id), info.description, _cost_label(cost), String.num(float(info.cooldown) * game.stats.talent_factor("skill_cooldown"), 2)]
		slot_buttons[i].disabled = overlay or (charge_grade == 0 and not staff_charging and (cooldown > 0 or mana_short or ammo_short or space_short or not skill_available))
