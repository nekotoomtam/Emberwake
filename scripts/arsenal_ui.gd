extends CanvasLayer
const Slot = preload("res://scripts/arsenal_slot.gd")
const Arts := {"sword":preload("res://scripts/sword_art.gd"), "mace":preload("res://scripts/mace_art.gd"), "pistol":preload("res://scripts/pistol_art.gd"), "greatsword":preload("res://scripts/greatsword_art.gd"), "staff":preload("res://scripts/staff_art.gd"), "rifle":preload("res://scripts/rifle_art.gd"), "bow":preload("res://scripts/bow_art.gd"), "crossbow":preload("res://scripts/crossbow_art.gd"), "shield":preload("res://scripts/shield_art.gd")}
var game
var model
var surface: Control
var slots: Array = []
var icons: Dictionary = {}
var selected: Dictionary = {}
var status: Label
var active_labels: Array[Label] = []
var swap_buttons: Array[Button] = []

func slot_style(selected_slot: bool, blocked: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#131c26") if not blocked else Color("#20242a")
	style.border_color = Color("#f0c786") if selected_slot else Color("#536269")
	style.set_border_width_all(3 if selected_slot else 1)
	style.set_corner_radius_all(3)
	return style

func text(value: String,size: int = 18) -> Label:
	var label := Label.new(); label.text=value
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("#e9e2cc"))
	return label

func _ready() -> void:
	layer=20
	for family: String in Arts:
		var image: Image = Arts[family].texture().get_image()
		icons[family] = ImageTexture.create_from_image(image.get_region(image.get_used_rect()))
	layer=20
	surface=Control.new();surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new();var font := SystemFont.new();font.font_names=PackedStringArray(["Tahoma","sans-serif"]);theme.default_font=font;surface.theme=theme
	add_child(surface)
	var shade := ColorRect.new();shade.color=Color(0.015,.025,.04,.85);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);surface.add_child(shade)
	var center := CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);surface.add_child(center)
	var panel := PanelContainer.new();panel.custom_minimum_size=Vector2(1080,620);panel.add_theme_stylebox_override("panel",game.ui.panel());center.add_child(panel)
	var column := VBoxContainer.new();column.add_theme_constant_override("separation",12);panel.add_child(column)
	var header := HBoxContainer.new();column.add_child(header)
	var heading := text("คลังอาวุธ / ชุดที่ 1 และ 2",27);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(heading)
	var close := Button.new();close.text="กลับไปเล่น [I / ESC]";close.pressed.connect(func():game.toggle_inventory());header.add_child(close)
	var skills := Button.new();skills.text="สกิลดาบ [K]";skills.pressed.connect(func():game.toggle_sword_skills());header.add_child(skills)
	column.add_child(text("ลากของลงช่อง หรือคลิกของแล้วคลิกช่อง • คลิกขวาที่ช่องเพื่อถอด",16))
	var row := HBoxContainer.new();row.add_theme_constant_override("separation",32);column.add_child(row)
	var bag_column := VBoxContainer.new();row.add_child(bag_column);bag_column.add_child(text("ช่องเก็บของ   20 ช่อง",20))
	var grid := GridContainer.new();grid.columns=5;grid.add_theme_constant_override("h_separation",7);grid.add_theme_constant_override("v_separation",7);bag_column.add_child(grid)
	for i in range(model.CAPACITY): add_slot(grid,{"kind":"bag","index":i})
	var equipment := VBoxContainer.new();equipment.add_theme_constant_override("separation",10);equipment.custom_minimum_size.x=460;row.add_child(equipment)
	for i in range(2):
		var title := text("",22);equipment.add_child(title);active_labels.append(title)
		var pair := HBoxContainer.new();pair.add_theme_constant_override("separation",12);equipment.add_child(pair)
		for hand: String in ["main","off"]:
			var hand_column := VBoxContainer.new();pair.add_child(hand_column)
			hand_column.add_child(text("มือขวา / ออกก่อน" if hand=="main" else "มือซ้าย / ตามทันที",15))
			add_slot(hand_column,{"kind":"slot","set":i,"hand":hand})
		var activate := Button.new();activate.text="ใช้ชุดนี้";activate.custom_minimum_size.y=32
		activate.pressed.connect(func():game.activate_loadout(i));equipment.add_child(activate);swap_buttons.append(activate)
	equipment.add_child(text("Q สลับทั้งชุด • P ดูสถานะตัวละคร",15))
	status=text("",16);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.custom_minimum_size.y=46;column.add_child(status)
	surface.visible=false
	model.changed.connect(refresh)
	refresh()

func add_slot(parent: Node,location: Dictionary) -> void:
	var slot := Slot.new();slot.owner_ui=self;slot.location=location;parent.add_child(slot);slots.append(slot)

func refresh() -> void:
	for slot in slots:
		slot.id=model.item_at(slot.location);slot.texture=null;slot.blocked=false
		if slot.id!="":
			var item: Dictionary=model.items[slot.id];slot.texture=icons[item.family]
			slot.tooltip_text=str(item.name)+(" • สองมือ" if item.two_hand else " • มือเดียว")+"\n"+details(item.family)
			if game.item_magazines.has(slot.id):
				var magazine = game.item_magazines[slot.id]
				slot.tooltip_text += "\nกระสุนคงเหลือ %d / %d" % [magazine.rounds, magazine.capacity]
		else: slot.tooltip_text="ช่องว่าง"
		if slot.location.kind=="slot" and slot.location.hand=="off":
			var main: String=model.sets[int(slot.location.set)].main
			slot.blocked=main!="" and model.items[main].two_hand
		slot.queue_redraw()
	for i in range(2):
		active_labels[i].text="ชุด %d   %s" % [i+1,"● กำลังใช้" if model.active==i else "สำรอง"]
		swap_buttons[i].disabled=model.active==i or model.primary(i)==""
	status.text=model.message

func details(family: String) -> String:
	return {"sword":"ฟัน 18 / 19 / 34 • 1 / 2 / 3 ใช้สกิล • K จัดสกิล", "mace":"ฟาดขึ้น → พุ่งกระแทก → ฟาดลง", "pistol":"ยิงทีละนัด • 18 ดาเมจ • 10 นัด • รีโหลด 0.5 วิ", "greatsword":"กวาดข้างสองที → ฟาดลง • ใช้ทั้งสองมือ", "staff":"ลูกไฟ 72 ดาเมจ • ระเบิด 36 รอบจุดกระทบ", "shield":"คลิกขวาค้างกางโล่ • รับแรงด้วยสแตมิน่า • ลดดาเมจด้านหน้า 55%", "crossbow":"R ขึ้นลำ • คลิกซ้ายยิง • แผลลึกทำดาเมจต่อเนื่อง", "bow":"ค้างคลิกซ้ายชาร์จ 3 ขั้น • ปล่อยขั้นเต็มแล้วถอย", "rifle":"49.5 ดาเมจ • 5 นัด • แรงถอยหลัง • ทะลุระยะสั้น"}.get(family,"")

func clicked(location: Dictionary) -> void:
	if not selected.is_empty() and selected!=location:
		transfer(selected,location)
	elif model.item_at(location)!="":
		selected=location.duplicate();model.message="เลือก "+str(model.items[model.item_at(location)].name)+" แล้ว • คลิกช่องปลายทาง";refresh()
	else: selected={};refresh()

func transfer(source: Dictionary,target: Dictionary) -> void:
	if model.move_item(source,target): selected={};game.loadout_edited()
	refresh()

func remove_item(location: Dictionary) -> void:
	if location.kind=="slot" and model.unequip(location): selected={};game.loadout_edited()
	refresh()
