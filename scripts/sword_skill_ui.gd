extends CanvasLayer
const Motion = preload("res://scripts/sword_skill_motion.gd")
const MaceSkills = preload("res://scripts/mace_skill_motion.gd")
const MaceFireLobs = preload("res://scripts/mace_fire_lobs.gd")
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
			if _is_charge_slot(i): game.release_mace_charge(i))
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
	for id: String in model.SKILL_IDS + MaceSkills.SKILLS.keys():
		var info: Dictionary = MaceSkills.SKILLS.get(id, Motion.SKILLS.get(id))
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

func _is_charge_slot(index: int) -> bool:
	return game.primary_family() == "mace" and MaceSkills.SKILLS[model.mace_skill_slots[index]].get("chargeable", false)

func _mace_damage_label(id: String, info: Dictionary) -> String:
	var first := str(info.damage)
	if id == "mace_sweep": return first + " + " + str(MaceSkills.SECOND_SWEEP.damage)
	if id == "mace_double_impact": return first + " + " + str(MaceSkills.SECOND_IMPACT.damage)
	if info.has("edge_damage"):
		var grades := PackedStringArray()
		for grade in MaceSkills.LEAP_GRADES:
			grades.append("%d/%d" % [grade.damage, grade.edge_damage])
		return " → ".join(grades) + " (โคน/ปลายกรวย)"
	if info.has("rift_radius"): return first + " ตอนวาง • แรงสะท้อนเพิ่ม 70% ของดาเมจที่ทุบโดน"
	if info.get("fire_buff", false): return "ไฟ %s ต่อระเบิด • ลูกเล็กโดนเป้าเดิมได้ครั้งเดียวต่อชุด" % str(MaceFireLobs.DAMAGE)
	return first

func refresh() -> void:
	if status == null: return
	status.text = model.message
	var using_mace: bool = game.primary_family() == "mace"
	catalog_title.text = ("สกิลกระบอง" if using_mace else "สกิลดาบ") + " • เลือกติดตั้ง 3 ช่อง"
	for id: String in catalog_details:
		var mace_row := MaceSkills.SKILLS.has(id)
		catalog_rows[id].visible = using_mace == mace_row
		var info: Dictionary = MaceSkills.SKILLS[id] if mace_row else Motion.SKILLS[id]
		var cost: float = info.cost if mace_row else Motion.mana_cost(id, game.stats.attributes)
		var description: String = info.description
		if mace_row:
			description = "ดาเมจพื้นฐาน %s • %s" % [_mace_damage_label(id, info), description]
		catalog_details[id].text = "%s • คูลดาวน์ %s วิ\n%s\n%s" % [
			_cost_label(cost), str(info.cooldown), description, SkillTags.label(info.tags)]
		if info.has("impact_tags"):
			catalog_details[id].text += "\nระเบิดลูกไฟ • " + SkillTags.label(info.impact_tags)
		if info.has("wave_tags"):
			catalog_details[id].text += "\nคลื่นจากฟันปกติ • " + SkillTags.label(info.wave_tags)
	for entry: Dictionary in equip_buttons:
		var slots: Array = model.mace_skill_slots if MaceSkills.SKILLS.has(entry.id) else model.skill_slots
		var equipped: bool = slots[entry.slot] == entry.id
		entry.button.text = ("✓ ช่อง %d" if equipped else "ใส่ช่อง %d") % (entry.slot + 1)
		entry.button.disabled = equipped
	_update_combat()

func _process(_delta: float) -> void:
	_update_combat()
	if catalog.visible: _layout_catalog()

func _update_combat() -> void:
	if game == null or catalog == null: return
	catalog.visible = game.sword_skills_open
	var overlay: bool = game.inventory_open or game.stats_open or game.body_lab_open or game.sword_skills_open
	var peek = game.get("dungeon_peek")
	overlay = overlay or game.get("_arrival_locked") == true or (is_instance_valid(peek) and peek.visible)
	combat_bar.visible = game.mode in ["practice", "combat"] and not overlay
	var using_mace: bool = game.primary_family() == "mace"
	var slots: Array = model.mace_skill_slots if using_mace else model.skill_slots
	var available: bool = game.mace_skills_available() if using_mace else game.sword_skills_available()
	for i in range(slot_buttons.size()):
		slot_buttons[i].visible = i < slots.size()
		if i >= slots.size(): continue
		var id: String = slots[i]
		var info: Dictionary = MaceSkills.SKILLS[id] if using_mace else Motion.SKILLS[id]
		var cooldown: float = float(game.sword_skill_cooldowns.get(id, 0.0))
		var cost: float = info.cost if using_mace else Motion.mana_cost(id, game.stats.attributes)
		var mana_short: bool = game.mana < cost
		var suffix := "พร้อม" if cooldown <= 0 else "%.1f วิ" % cooldown
		if cooldown <= 0 and mana_short: suffix = "มานาไม่พอ"
		if id == "storm_blade" and float(game.get("sword_wave_buff_left")) > 0.0:
			suffix = "บัฟ %.1f วิ" % float(game.sword_wave_buff_left)
		if id == "mace_fissure" and float(game.mace_fire_buff_left) > 0.0:
			suffix = "บัฟ %.1f วิ" % float(game.mace_fire_buff_left)
		var charge_grade: int = game.mace_charge_grade(i) if using_mace else 0
		if charge_grade > 0: suffix = "ชาร์จ %d/3 • ปล่อยเพื่อทุบ" % charge_grade
		slot_buttons[i].text = "[%d] %s\n%s" % [i + 1, info.name, suffix]
		if using_mace:
			slot_buttons[i].tooltip_text = "%s\nดาเมจพื้นฐาน %s • %s • คูลดาวน์ %s วิ • เลือกสกิล [K]" % [info.description, _mace_damage_label(id, info), _cost_label(cost), str(info.cooldown)]
		else:
			slot_buttons[i].tooltip_text = "ดาเมจพื้นฐาน • %s\n%s • คูลดาวน์ %s วิ • ดูสกิลทั้งหมด [K]" % [info.description, _cost_label(cost), str(info.cooldown)]
		slot_buttons[i].disabled = overlay or (charge_grade == 0 and (cooldown > 0 or mana_short or not available))
