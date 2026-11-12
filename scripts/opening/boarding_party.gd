extends CanvasLayer
## Boarding mock. Every card is a unique recruit and each slot holds one card.
signal confirmed(party: Array[Dictionary])
signal cancelled

const Talents = preload("res://scripts/character_talents.gd")
const Roster = preload("res://scripts/opening/expedition_roster.gd")
const CharacterStats = preload("res://scripts/character_stats.gd")
const Flask = preload("res://scripts/health_flask.gd")
const Stage = preload("res://scripts/opening/boarding_stage.gd")
const Look = preload("res://modular/scripts/city_npc_pose.gd")
const PAPER := Color("#f3e6ce")
const MUTED := Color("#a8bcb8")
const GOLD := Color("#eac28b")
const EDGE := Color("#426164")
const POSITIONS := ["ตัวหลัก", "Sub 1", "Sub 2"]
const PROFILES := [
	["อาเดล", "นักดาบ", "ดาบมือเดียว", "sword"],
	["ไอรา", "หมอสนาม", "ปืนพก", "pistol"],
	["โรวาน", "ผู้คุ้มกัน", "กระบอง", "mace"],
	["ไซลัส", "พลแม่นปืน", "ไรเฟิล", "rifle"],
	["มีรา", "จอมเวท", "คทาธาตุ", "staff"],
]

class RecruitCard extends PanelContainer:
	var board
	var recruit_id := -1
	var slot := -1
	var click_started := false

	func _gui_input(event: InputEvent) -> void:
		if slot < 0 or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			click_started = true
		else:
			if click_started and not get_viewport().gui_is_dragging():
				board.select_gear(slot)
			click_started = false

	func _get_drag_data(_at_position: Vector2) -> Variant:
		click_started = false
		if recruit_id < 0:
			return null
		set_drag_preview(board.make_preview(recruit_id))
		return {"board": board, "recruit": recruit_id}

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return slot >= 0 and data is Dictionary and data.get("board") == board and board.has_recruit(data.get("recruit"))

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		board.assign(data.recruit, slot)

var attribute_seed := randi()
var recruits: Array[Dictionary] = []
var slots: Array[int] = [0, 1, 2]
var slot_cards: Array[RecruitCard] = []
var pool_cards: Array[RecruitCard] = []
var status: Label
var stage: Node3D
var deck_targets: Control
var roster_view: VBoxContainer
var gear_view: VBoxContainer
var roster_tab: Button
var depart_button: Button
var gear_tab: Button
var gear_title: Label
var gear_position: Label
var gear_weapon: Label
var gear_attributes: Label
var gear_top: OptionButton
var gear_bottom: OptionButton
var flask_count: Label
var flask_minus: Button
var flask_plus: Button
var selected_slot := 0
var _departing := false


func _ready() -> void:
	layer = 30
	var shade := ColorRect.new()
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("#0e1a2220")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Leelawadee UI", "Tahoma"])
	var theme := Theme.new()
	theme.default_font = font
	shade.theme = theme
	stage = Stage.new()
	add_child(stage)
	deck_targets = Control.new()
	deck_targets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(deck_targets)
	deck_targets.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index in POSITIONS.size():
		var card := make_card(index, Vector2.ZERO)
		deck_targets.add_child(card)
		slot_cards.append(card)

	var center := CenterContainer.new()
	shade.add_child(center)
	center.anchor_left = 1.0
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.offset_left = -500
	center.offset_right = -20
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(468, 0)
	panel.add_theme_stylebox_override("panel", box(Color("#14262cf4"), EDGE, 15))
	center.add_child(panel)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 11)
	panel.add_child(page)

	page.add_child(caption("EMBERWAKE   /   ท่าเรือ", 14, GOLD))
	page.add_child(caption("จัดทีมบนดาดฟ้า", 30, PAPER))
	page.add_child(caption("ลากการ์ดลงเรือ   ·   คลิกคนเพื่อจัดของพก", 16, MUTED))

	var divider := HSeparator.new()
	page.add_child(divider)
	var roster := VBoxContainer.new()
	roster.custom_minimum_size.x = 438
	roster.add_theme_constant_override("separation", 10)
	page.add_child(roster)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	roster.add_child(tabs)
	roster_tab = action("ผู้สมัคร  /  05", show_roster)
	gear_tab = action("จัดของทีม", func(): select_gear(selected_slot))
	for tab in [roster_tab, gear_tab]:
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_stylebox_override("disabled", box(Color("#364940"), GOLD, 9))
		tab.add_theme_color_override("font_disabled_color", GOLD)
		tabs.add_child(tab)
	roster_view = VBoxContainer.new()
	roster_view.add_theme_constant_override("separation", 8)
	roster.add_child(roster_view)
	var roster_header := HBoxContainer.new()
	roster_view.add_child(roster_header)
	var roster_title := caption("ลากเข้าทีม", 18, PAPER)
	roster_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_header.add_child(roster_title)
	roster_header.add_child(action("สุ่มผู้สมัครใหม่", roll))
	var gallery := GridContainer.new()
	gallery.columns = 2
	gallery.add_theme_constant_override("h_separation", 10)
	gallery.add_theme_constant_override("v_separation", 10)
	roster_view.add_child(gallery)
	for index in PROFILES.size():
		var card := make_card(-1, Vector2(205, 103))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gallery.add_child(card)
		pool_cards.append(card)
	var hint := caption("ลากการ์ดไปวางบนคนที่ต้องการสับเปลี่ยน", 15, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 184
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gallery.add_child(hint)

	build_gear(roster)
	show_roster()

	page.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	page.add_child(footer)
	status = caption("", 15, MUTED)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(status)
	page.move_child(status, footer.get_index())
	footer.add_child(action("กลับท่าเรือ", func(): cancelled.emit()))
	depart_button = action("ออกเรือ  →", confirm, true)
	footer.add_child(depart_button)
	roll()
	shade.modulate.a = 0
	create_tween().tween_property(shade, "modulate:a", 1.0, .42).set_delay(.22)


func roll() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var talent_rng := RandomNumberGenerator.new()
	talent_rng.randomize()
	var attributes_rng := RandomNumberGenerator.new()
	attributes_rng.seed = attribute_seed
	var previous := recruits.duplicate()
	recruits.clear()
	var used: Dictionary = {}
	var lost := Roster.losses()
	for index in PROFILES.size():
		var profile: Array = PROFILES[index]
		var look: Dictionary
		for attempt in 16:
			var identifier := "crew/%d/%d" % [index, rng.randi()]
			look = Look.appearance({"id": identifier, "male": index in [2, 3]}, profile[0], "Middle")
			var signature := [look.face, look.hair]
			if not used.has(signature):
				used[signature] = true
				break
		if index < previous.size():
			look.top = previous[index].look.top
			look.bottom = previous[index].look.bottom
		var portrait: Texture2D = Look.frame(look, "front", "idle", 0).texture
		var roster_id := "harbor_recruit_%d" % index
		recruits.append({"roster_id": roster_id, "lost": lost.has(roster_id), "name": profile[0], "role": profile[1], "weapon_label": profile[2],
			"weapon": profile[3], "look": look, "portrait": portrait,
			"attributes": CharacterStats.roll_level_one(attributes_rng),
			"talents": Talents.roll_start(talent_rng),
			"flasks": previous[index].flasks if index < previous.size() else Flask.RUN_CHARGES})
	var available: Array[int] = []
	for index in recruits.size():
		if has_recruit(index) and index not in slots: available.append(index)
	for index in slots.size():
		if not has_recruit(slots[index]):
			slots[index] = available.pop_front() if not available.is_empty() else -1
	refresh_cards()


func has_recruit(id: Variant) -> bool:
	return id is int and id >= 0 and id < recruits.size() and not bool(recruits[id].lost)


func assign(recruit_id: int, slot: int) -> void:
	if not has_recruit(recruit_id) or slot < 0 or slot >= slots.size() or slots[slot] == recruit_id:
		return
	var previous := slots.find(recruit_id)
	if previous == 0 and not has_recruit(slots[slot]): return
	if previous >= 0:
		slots[previous] = slots[slot]
	slots[slot] = recruit_id
	refresh_cards()


func refresh_cards() -> void:
	for index in slot_cards.size():
		fill_stage_slot(index, slots[index])
	for index in pool_cards.size():
		pool_cards[index].visible = has_recruit(index)
		if not pool_cards[index].visible: continue
		var assigned := slots.find(index)
		fill_card(pool_cards[index], index, POSITIONS[assigned] if assigned >= 0 else "ว่าง")
	refresh_gear()
	depart_button.disabled = not has_recruit(slots[0])
	gear_tab.disabled = depart_button.disabled or gear_view.visible
	if depart_button.disabled:
		status.text = "ไม่มีผู้รอดชีวิตที่พร้อมออกเรือ"
	else:
		status.text = "พร้อมออกเรือ  %d / 3     •     คุม %s" % [slots.size() - slots.count(-1), recruits[slots[0]].name]


func build_gear(parent: VBoxContainer) -> void:
	gear_view = VBoxContainer.new()
	gear_view.add_theme_constant_override("separation", 12)
	parent.add_child(gear_view)
	gear_position = caption("", 14, GOLD)
	gear_view.add_child(gear_position)
	gear_title = caption("", 25, PAPER)
	gear_view.add_child(gear_title)
	gear_weapon = caption("", 17, MUTED)
	gear_view.add_child(gear_weapon)
	gear_attributes = caption("", 16, GOLD)
	gear_view.add_child(gear_attributes)
	gear_view.add_child(HSeparator.new())
	gear_top = outfit_option("เสื้อ", "top")
	gear_bottom = outfit_option("กางเกง", "bottom")
	gear_view.add_child(HSeparator.new())
	var supplies := HBoxContainer.new()
	supplies.add_theme_constant_override("separation", 9)
	gear_view.add_child(supplies)
	var label := caption("ยาฟื้นพลัง", 18, PAPER)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	supplies.add_child(label)
	flask_minus = action("−", func(): change_flasks(-1))
	flask_plus = action("+", func(): change_flasks(1))
	flask_count = caption("", 18, GOLD)
	supplies.add_child(flask_minus)
	supplies.add_child(flask_count)
	supplies.add_child(flask_plus)
	gear_view.add_child(caption("ของจะติดไปกับคนนี้เมื่อสลับตำแหน่ง", 14, MUTED))


func outfit_option(label_text: String, part: String) -> OptionButton:
	var row := HBoxContainer.new()
	gear_view.add_child(row)
	var label := caption(label_text, 18, PAPER)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(255, 44)
	option.item_selected.connect(func(index: int): change_outfit(part, index))
	row.add_child(option)
	return option


func show_roster() -> void:
	roster_view.show()
	gear_view.hide()
	update_tabs()
	if not recruits.is_empty():
		refresh_cards()


func select_gear(slot: int) -> void:
	if not has_recruit(slots[slot]): return
	selected_slot = slot
	roster_view.hide()
	gear_view.show()
	update_tabs()
	refresh_cards()


func update_tabs() -> void:
	roster_tab.disabled = roster_view.visible
	gear_tab.disabled = gear_view.visible


func refresh_gear() -> void:
	if not has_recruit(slots[selected_slot]): selected_slot = 0
	if not has_recruit(slots[selected_slot]): return
	var recruit := recruits[slots[selected_slot]]
	gear_position.text = POSITIONS[selected_slot] + "  /  ของพก"
	gear_title.text = "%s  ·  %s" % [recruit.name, recruit.role]
	gear_weapon.text = "อาวุธประจำตัว   ·   " + recruit.weapon_label
	gear_attributes.text = CharacterStats.level_one_text(recruit.attributes)
	fill_outfit_options(gear_top, recruit, "top")
	fill_outfit_options(gear_bottom, recruit, "bottom")
	flask_count.text = "%d / %d" % [recruit.flasks, Flask.RUN_CHARGES]
	flask_minus.disabled = recruit.flasks == 0
	flask_plus.disabled = recruit.flasks == Flask.RUN_CHARGES


func change_flasks(amount: int) -> void:
	var recruit := recruits[slots[selected_slot]]
	recruit.flasks = clampi(recruit.flasks + amount, 0, Flask.RUN_CHARGES)
	refresh_gear()


func fill_outfit_options(option: OptionButton, recruit: Dictionary, part: String) -> void:
	option.clear()
	for outfit: Dictionary in Look.CLOTHES.data:
		if outfit.sex != recruit.look.sex or outfit.tier != recruit.look.tier:
			continue
		option.add_item(outfit.name_th)
		var index := option.item_count - 1
		option.set_item_metadata(index, outfit)
		if outfit.id == recruit.look[part].id and outfit.alt == recruit.look[part].alt:
			option.select(index)


func change_outfit(part: String, index: int) -> void:
	var recruit := recruits[slots[selected_slot]]
	var option := gear_top if part == "top" else gear_bottom
	recruit.look[part] = option.get_item_metadata(index)
	recruit.portrait = Look.frame(recruit.look, "front", "idle", 0).texture
	refresh_cards()


func confirm() -> void:
	if _departing or not has_recruit(slots[0]):
		return
	var party: Array[Dictionary] = []
	for id in slots:
		if not has_recruit(id): continue
		party.append(recruits[id].duplicate(true))
	confirmed.emit(party)


func set_departing(active: bool) -> void:
	_departing = active
	var controls := deck_targets.get_parent() as Control
	controls.visible = not active
	for ring: MeshInstance3D in stage.rings:
		ring.visible = not active
	if not active:
		var no_party: Array[Dictionary] = []
		stage.departure_party = no_party
		stage.bow_progress = 0.0
		stage.bow_walk_elapsed = 0.0
		for index in slots.size():
			fill_stage_slot(index, slots[index])


func make_card(slot: int, minimum: Vector2) -> RecruitCard:
	var card := RecruitCard.new()
	card.board = self
	card.slot = slot
	card.custom_minimum_size = minimum
	card.mouse_default_cursor_shape = Control.CURSOR_MOVE
	return card


func sync_deck(world, camera: Camera3D) -> void:
	stage.sync(world, camera)
	for index in slot_cards.size():
		var card := slot_cards[index]
		var foot: Vector3 = stage.feet[index]
		card.visible = not camera.is_position_behind(foot)
		if not card.visible:
			continue
		var bottom := camera.unproject_position(foot)
		var top := camera.unproject_position(foot + camera.global_basis.y * 2.17)
		var width := clampf(bottom.distance_to(top) * .66, 110.0, 220.0)
		card.position = Vector2(bottom.x - width * .5, top.y)
		card.size = Vector2(width, maxf(42.0, bottom.y - top.y + 29.0))


func clear_card(card: RecruitCard, id: int) -> void:
	card.recruit_id = id
	card.tooltip_text = "%s • %s\n%s" % [recruits[id].role, recruits[id].weapon_label, Talents.summary(recruits[id].talents, true)]
	for child in card.get_children():
		card.remove_child(child)
		child.queue_free()


func fill_stage_slot(index: int, id: int) -> void:
	var card := slot_cards[index]
	var occupied := has_recruit(id)
	stage.set_portrait(index, Look.frame(recruits[id].look, "right", "idle", 0).texture if occupied else null)
	stage.rings[index].visible = occupied and not _departing
	if not occupied:
		card.recruit_id = -1
		card.tooltip_text = ""
		for child in card.get_children():
			card.remove_child(child)
			child.queue_free()
		return
	clear_card(card, id)
	card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var bottom := CenterContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.size_flags_vertical = Control.SIZE_SHRINK_END
	card.add_child(bottom)
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border := GOLD if index == 0 else EDGE
	if gear_view.visible and index == selected_slot:
		border = Color("#83cbb6")
	tag.add_theme_stylebox_override("panel", box(Color("#14262ced"), border, 4))
	bottom.add_child(tag)
	tag.add_child(caption("%s  ·  %s" % [POSITIONS[index], recruits[id].name], 16, GOLD if index == 0 else PAPER))


func fill_card(card: RecruitCard, id: int, badge: String) -> void:
	clear_card(card, id)
	var assigned := badge != "ว่าง"
	card.add_theme_stylebox_override("panel", box(Color("#29424a") if assigned else Color("#1e343a"), GOLD if badge == POSITIONS[0] else EDGE, 8))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var portrait := TextureRect.new()
	portrait.texture = recruits[id].portrait
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)
	info.add_theme_constant_override("separation", 0)
	info.add_child(caption(recruits[id].name, 18, PAPER))
	var subtitle: String = recruits[id].weapon_label
	if assigned: subtitle += " · " + badge
	info.add_child(caption(subtitle, 12, MUTED))
	var talent_label := caption(Talents.summary(recruits[id].talents), 12, GOLD)
	talent_label.add_theme_constant_override("line_spacing", 0)
	info.add_child(talent_label)


func make_preview(id: int) -> Control:
	var card := make_card(-1, Vector2(215, 62))
	fill_card(card, id, "ลาก")
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = .9
	return card


func caption(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func action(text: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_stylebox_override("normal", box(Color("#565038") if primary else Color("#21363c"), GOLD if primary else EDGE, 9))
	button.add_theme_stylebox_override("hover", box(Color("#655b40") if primary else Color("#2b464c"), GOLD, 9))
	button.pressed.connect(callback)
	return button


func box(fill: Color, border: Color, padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, padding)
	return style


func _unhandled_key_input(event: InputEvent) -> void:
	if _departing:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cancelled.emit()
