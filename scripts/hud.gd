extends CanvasLayer
var game
var menu_scroll: ScrollContainer
var study_panel: PanelContainer
var mace_status_panel: PanelContainer
var mace_status: Label
var charge_panel: PanelContainer
var charge_label: Label
var charge_gauge
var ready_text: Label
var health_bar: ProgressBar
var flask_button: Button
var stamina_bar: ProgressBar
var health_text: Label
var stage_text: Label
var counter: Label
var dungeon_map_panel: VBoxContainer
var companion_panel: PanelContainer
var revive_bar: ProgressBar
var companion_bars: Array[ProgressBar] = []
var companion_labels: Array[Label] = []
var dungeon_map
var objective: Label
var overlay: Control
var title: Label
var description: Label
var buttons: VBoxContainer
var weapon_button: Button
var control_hint: Label
var weapon_hint: Label
var vital_panel: PanelContainer
var status_panel: PanelContainer
var status_view
var ammo_panel: PanelContainer
var header_panel: PanelContainer
var help_panel: PanelContainer
var stamina_fill: StyleBoxFlat
var bow_meter: HBoxContainer
var ammo_text: Label
var reload_bar: ProgressBar
const GOLD = Color("#edc182")
const PAPER = Color("#e6e7dc")
const DIM = Color("#a1b7bb")

func panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.055, 0.09, 0.13, 0.94)
	s.border_color = Color("#63736c")
	s.set_border_width_all(1)
	s.set_corner_radius_all(5)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s

func label(text: String, size: int = 18, color: Color = PAPER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(390, 46)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", panel())
	var hover := panel()
	hover.bg_color = Color("#324a50")
	hover.border_color = GOLD
	b.add_theme_stylebox_override("hover", hover)
	b.pressed.connect(action)
	return b

func _ready() -> void:
	layer=10
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Tahoma", "Noto Sans Thai", "sans-serif"])
	theme.default_font = font
	theme.default_font_size = 18
	root.theme = theme
	add_child(root)
	mace_status_panel=PanelContainer.new();root.add_child(mace_status_panel)
	mace_status_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	mace_status_panel.offset_left=-300;mace_status_panel.offset_right=300;mace_status_panel.offset_top=122;mace_status_panel.offset_bottom=190
	mace_status_panel.add_theme_stylebox_override("panel",panel());mace_status_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	mace_status=label("",16,GOLD);mace_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;mace_status_panel.add_child(mace_status);mace_status_panel.visible=false
	charge_panel=PanelContainer.new();root.add_child(charge_panel)
	charge_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	charge_panel.offset_left=-185;charge_panel.offset_right=185;charge_panel.offset_top=-224;charge_panel.offset_bottom=-148
	charge_panel.add_theme_stylebox_override("panel",panel());charge_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var charge_column:=VBoxContainer.new();charge_panel.add_child(charge_column)
	charge_label=label("",16,GOLD);charge_column.add_child(charge_label)
	charge_gauge=preload("res://scripts/charge_gauge.gd").new();charge_gauge.custom_minimum_size=Vector2(320,18);charge_gauge.mouse_filter=Control.MOUSE_FILTER_IGNORE;charge_column.add_child(charge_gauge)
	charge_panel.visible=false
	status_panel=PanelContainer.new();root.add_child(status_panel)
	status_panel.position=Vector2(20,302)
	status_panel.add_theme_stylebox_override("panel",compact_panel())
	status_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var status_column:=VBoxContainer.new();status_column.add_theme_constant_override("separation",5);status_panel.add_child(status_column)
	status_column.add_child(label("สถานะตัวละคร",13,DIM))
	status_view=preload("res://scripts/player_status_bar.gd").new();status_column.add_child(status_view)
	header_panel=PanelContainer.new();root.add_child(header_panel)
	header_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	header_panel.offset_left=-150;header_panel.offset_right=150;header_panel.offset_top=16;header_panel.offset_bottom=112
	header_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;header_panel.add_theme_stylebox_override("panel",compact_panel())
	var middle:=VBoxContainer.new();header_panel.add_child(middle)
	var brand:=label("EMBERWAKE",23,GOLD);brand.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;middle.add_child(brand)
	objective=label("ลานฝึก",14,DIM);objective.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;objective.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;middle.add_child(objective)
	ammo_panel=PanelContainer.new();root.add_child(ammo_panel)
	ammo_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	ammo_panel.offset_left=-320;ammo_panel.offset_right=-20;ammo_panel.offset_top=16;ammo_panel.offset_bottom=152
	ammo_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;ammo_panel.add_theme_stylebox_override("panel",compact_panel())
	var weapon_stack:=VBoxContainer.new();weapon_stack.add_theme_constant_override("separation",2);ammo_panel.add_child(weapon_stack)
	weapon_button=button("อาวุธ [I]",func():game.toggle_inventory());weapon_button.custom_minimum_size=Vector2(0,32);weapon_stack.add_child(weapon_button)
	for state in ["normal","hover","pressed","disabled"]:
		var button_style:=compact_panel();button_style.content_margin_top=6;button_style.content_margin_bottom=6
		if state=="hover":button_style.bg_color=Color("#324a50");button_style.border_color=GOLD
		weapon_button.add_theme_stylebox_override(state,button_style)
	ammo_text=label("",14,GOLD);ammo_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;weapon_stack.add_child(ammo_text)
	reload_bar=bar(GOLD);reload_bar.custom_minimum_size=Vector2(0,4);reload_bar.max_value=1;weapon_stack.add_child(reload_bar)
	counter=label("",13,DIM);counter.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;weapon_stack.add_child(counter)
	dungeon_map_panel = VBoxContainer.new()
	dungeon_map_panel.hide()
	dungeon_map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_stack.add_child(dungeon_map_panel)
	dungeon_map_panel.add_child(label("แผนที่ดันเจี้ยน", 14, GOLD))
	dungeon_map = preload("res://scripts/dungeon_map.gd").new()
	dungeon_map.custom_minimum_size = Vector2(0, 180)
	dungeon_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dungeon_map_panel.add_child(dungeon_map)
	var map_legend := HBoxContainer.new()
	map_legend.add_theme_constant_override("separation", 8)
	map_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dungeon_map_panel.add_child(map_legend)
	_build_companion_panel(root)
	map_legend.add_child(label("□ ห้องนี้", 12, GOLD))
	map_legend.add_child(label("✓ เคลียร์แล้ว", 12, Color("#84d3b2")))
	map_legend.add_child(label("● จุดเริ่ม", 12, Color("#8fd3f3")))
	map_legend.add_child(label("■ ยังไม่เข้า", 12, Color("#8094a1")))
	vital_panel=PanelContainer.new();root.add_child(vital_panel)
	vital_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	vital_panel.offset_left=20;vital_panel.offset_right=256;vital_panel.offset_top=16;vital_panel.offset_bottom=112
	vital_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;vital_panel.add_theme_stylebox_override("panel",compact_panel())
	var vital:=VBoxContainer.new();vital.add_theme_constant_override("separation",3);vital_panel.add_child(vital)
	health_text=label("เลือด 100 / 100",16,PAPER);vital.add_child(health_text)
	health_bar=bar(Color("#de6c7b"));health_bar.custom_minimum_size=Vector2(0,16);vital.add_child(health_bar)
	stamina_bar = bar(Color("#65c3b7"))
	stamina_bar.custom_minimum_size = Vector2(8, 38)
	stamina_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	stamina_bar.size = stamina_bar.custom_minimum_size
	var track := stamina_bar.get_theme_stylebox("background") as StyleBoxFlat
	track.bg_color = Color("#182229")
	track.border_color = Color("#40535a")
	track.set_border_width_all(1)
	track.set_corner_radius_all(2)
	stamina_fill = stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat
	stamina_fill.set_corner_radius_all(2)
	stamina_bar.modulate.a = 0.0
	stamina_bar.hide()
	root.add_child(stamina_bar)
	revive_bar = bar(Color("#a9e4b4"))
	revive_bar.custom_minimum_size = Vector2(82, 8)
	revive_bar.size = revive_bar.custom_minimum_size
	revive_bar.max_value = game.REVIVE_DURATION
	revive_bar.step = 0.0
	revive_bar.hide()
	root.add_child(revive_bar)
	bow_meter = HBoxContainer.new()
	bow_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bow_meter.add_theme_constant_override("separation", 3)
	for index in 3:
		var segment := bar(Color("#edbd74") if index == 2 else Color("#81d8c4"))
		segment.custom_minimum_size = Vector2(14, 6)
		segment.max_value = 1.0
		segment.step = 0.0
		bow_meter.add_child(segment)
	bow_meter.hide()
	root.add_child(bow_meter)
	flask_button=button("F  ยา 3/3",func():game.use_health_flask());flask_button.custom_minimum_size=Vector2(0,28);flask_button.add_theme_font_size_override("font_size",14);vital.add_child(flask_button)
	flask_button.tooltip_text="ฟื้นเลือด 25 ทันที + 5/วินาที นาน 5 วินาที\nไม่รักษาชิ้นส่วน • T เริ่มใหม่รับ 3 ขวด"
	for state in ["normal","hover","pressed","disabled"]:
		var style:=compact_panel();style.content_margin_top=4;style.content_margin_bottom=4
		if state=="hover":style.bg_color=Color("#324a50");style.border_color=GOLD
		flask_button.add_theme_stylebox_override(state,style)
	help_panel=PanelContainer.new();root.add_child(help_panel)
	help_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	help_panel.offset_left=340;help_panel.offset_right=-20;help_panel.offset_top=-134;help_panel.offset_bottom=-20
	help_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;help_panel.add_theme_stylebox_override("panel",compact_panel())
	var foot:=VBoxContainer.new();foot.add_theme_constant_override("separation",3);help_panel.add_child(foot)
	control_hint=label("",14);control_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;foot.add_child(control_hint)
	weapon_hint=label("",12,DIM);weapon_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;foot.add_child(weapon_hint)
	var action_row:=HBoxContainer.new();action_row.add_theme_constant_override("separation",10);foot.add_child(action_row)
	ready_text=label("",13,DIM);ready_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;ready_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;action_row.add_child(ready_text)
	stage_text=label("Ⅰ → Ⅱ → Ⅲ",16,GOLD);stage_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;action_row.add_child(stage_text)
	study_panel=PanelContainer.new();root.add_child(study_panel)
	study_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);study_panel.offset_left=20;study_panel.offset_right=-20;study_panel.offset_top=-58;study_panel.offset_bottom=-16
	study_panel.add_theme_stylebox_override("panel",compact_panel());study_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	study_panel.add_child(label("หมู่บ้านร้างริมทะเล  •  WASD เดินสำรวจ  •  เข้าประตูดูภายใน  •  ล้อเมาส์ ซูม  •  SPACE แดช  •  T เริ่มใหม่  •  ESC พัก",14,DIM));study_panel.visible=false
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.015, 0.035, 0.05, 0.67)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(510, 0)
	card.add_theme_stylebox_override("panel", panel())
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)
	title = label("EMBERWAKE", 39, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	description = label("", 17, PAPER)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(460, 74)
	col.add_child(description)
	buttons = VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	menu_scroll=ScrollContainer.new();menu_scroll.custom_minimum_size=Vector2(0,380);menu_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	buttons.size_flags_horizontal=Control.SIZE_EXPAND_FILL;menu_scroll.add_child(buttons);col.add_child(menu_scroll)
	show_mode("menu")

func _build_companion_panel(root: Control) -> void:
	companion_panel = PanelContainer.new()
	companion_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	companion_panel.add_theme_stylebox_override("panel", compact_panel())
	companion_panel.hide()
	root.add_child(companion_panel)
	companion_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	companion_panel.offset_left = -238
	companion_panel.offset_right = -20
	companion_panel.offset_top = 372
	companion_panel.offset_bottom = 372

	var team := VBoxContainer.new()
	team.mouse_filter = Control.MOUSE_FILTER_IGNORE
	team.add_theme_constant_override("separation", 6)
	companion_panel.add_child(team)
	team.add_child(label("เพื่อนร่วมทีม", 14, GOLD))
	team.add_child(label("C ปักเป้า · Shift+C เรียกถอย", 12, DIM))
	for recruit: Dictionary in game.expedition_companions:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		team.add_child(row)

		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(48, 48)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var texture: Texture2D = recruit.get("portrait")
		if texture != null:
			var head := AtlasTexture.new()
			head.atlas = texture
			head.region = Rect2(texture.get_width() * .18, 0, texture.get_width() * .64, texture.get_height() * .58)
			head.filter_clip = true
			portrait.texture = head
		row.add_child(portrait)

		var details := VBoxContainer.new()
		details.mouse_filter = Control.MOUSE_FILTER_IGNORE
		details.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(details)
		details.add_child(label(recruit.get("name", ""), 16))
		var state := label(recruit.get("role", ""), 13, DIM)
		details.add_child(state)
		companion_labels.append(state)
		var life := bar(Color("#78bea1"))
		life.custom_minimum_size = Vector2(122, 4)
		life.max_value = 100.0
		details.add_child(life)
		companion_bars.append(life)


func _process(delta: float) -> void:
	if not is_instance_valid(stamina_bar):
		return
	var revive_target = game.revive_target
	revive_bar.visible = is_instance_valid(revive_target) and game.mode == "combat"
	if revive_bar.visible:
		revive_bar.value = game.revive_elapsed
		var marker: Vector3 = revive_target.revive_marker.global_position
		var center: Vector2 = game.camera.unproject_position(marker)
		revive_bar.position = (center - Vector2(revive_bar.size.x * .5, 24.0)).round()
	var tier: int = game.bow_tier()
	bow_meter.visible = tier > 0 and vital_panel.visible and game.mode in ["practice", "combat"] and not game.body_lab_open
	if bow_meter.visible:
		for index in 3:
			bow_meter.get_child(index).value = float(index < tier)
		var bow_camera: Camera3D = game.camera
		var above: Vector3 = game.player.global_position + bow_camera.global_basis.y * 2.45
		bow_meter.position = (bow_camera.unproject_position(above) - bow_meter.size * 0.5).round()
	if not vital_panel.visible or game.mode not in ["practice", "combat"] or game.inventory_open or game.stats_open or game.body_lab_open:
		stamina_bar.hide()
		stamina_bar.modulate.a = 0.0
		return
	var capacity: float = game.stats.value("max_stamina")
	stamina_bar.max_value = capacity
	stamina_bar.value = game.stamina
	var low: bool = game.stamina <= capacity * .25
	var flash: bool = game.energy.flash > 0
	var color := Color("#ee7771") if flash else (Color("#edbd74") if low else Color("#65c3b7"))
	if stamina_fill.bg_color != color:
		stamina_fill.bg_color = color
	if flash or game.stamina < capacity - .05:
		stamina_bar.modulate.a = 1.0
	else:
		stamina_bar.modulate.a = move_toward(stamina_bar.modulate.a, 0.0, delta * 3.4)
	stamina_bar.visible = stamina_bar.modulate.a > 0.0
	if stamina_bar.visible:
		var camera: Camera3D = game.camera
		var point: Vector3 = game.player.global_position + camera.global_basis.y * .92 - camera.global_basis.x * 1.30
		stamina_bar.position = (camera.unproject_position(point) - stamina_bar.size * .5).round()


func bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(260, 13)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#17222c")
	b.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	b.add_theme_stylebox_override("fill", fill)
	return b

func show_mode(mode: String) -> void:
	overlay.visible = mode in ["menu", "paused", "victory", "dead","shore_end"]
	for child in buttons.get_children():
		buttons.remove_child(child)
		child.queue_free()
	match mode:
		"menu":
			title.text = "EMBERWAKE"
			description.text = "ชายหาดร้าง • ศัตรูชายฝั่ง 5 ประเภท • นายท้ายสมอ\nอำพัน: ปัดได้ • แดง: ปัดไม่ได้ • ขอบเติม: จังหวะโจมตี\nR รีโหลด • Q สลับชุด • I เปิดของ • T เริ่มใหม่"
			buttons.add_child(button("เริ่มเรื่อง • คลื่นพัดเกยฝั่ง",game.start_wreck_shore))
			buttons.add_child(button("เส้นทางเลียบฝั่ง • ทดลอง 5 รูปแบบ",game.start_coast_forms))
			buttons.add_child(button("หมู่บ้านร้าง • ทดลองภาพชายหาดถึงบ้าน",game.start_village_study))
			buttons.add_child(button("ผู้สำรอกน้ำเค็ม • สายอ้วกและคราบพิษ",game.start_spitter_trial))
			buttons.add_child(button("ลูกเรือลากอวน • ค้อนฟาดหนัก",game.start_net_hauler_trial))
			buttons.add_child(button("ลูกเรือ • ขว้างฉมวก",game.start_crewman_trial))
			buttons.add_child(button("หมาน้ำเค็ม • กระโจนกัดแล้วกัดซ้ำ",game.start_brinehound_trial))
			buttons.add_child(button("ชาวประมง • ทดลองภาพ 4 มุม",game.start_fisherman_trial))
			buttons.add_child(button("ชายหาดร้าง • สำรวจและต่อสู้",game.start_coast))
			buttons.add_child(button("ด่านสุ่ม • 30–50 ห้อง",game.start_dungeon))
			buttons.add_child(button("ท่าเรือ • นายท้ายผู้ลากสมอ",game.start_captain))
			buttons.add_child(button("ซ้อมกับหุ่น", func(): game.start_run(true)))
			buttons.add_child(button("ฝึกปัด • มอนตัวเดียว",func():game.start_parry_drill()))
			buttons.add_child(button("เข้าลานประลอง", func(): game.start_run(false)))
			buttons.add_child(button("ออกจากเกม", func(): get_tree().quit()))
		"paused":
			title.text = "พักที่ลานเถ้า"
			description.text = "จังหวะการต่อสู้หยุดอยู่ตรงนี้"
			buttons.add_child(button("เล่นต่อ", game.toggle_pause))
			buttons.add_child(button("เริ่มใหม่", game.restart))
			buttons.add_child(button("กลับหน้าหลัก", game.return_menu))
		"victory":
			title.text = "ลานสงบแล้ว"
			description.text = "ผ่านครบ 3 ระลอก • กำจัด %d ตัว\nเวลา %.1f วินาที • โจมตีโดน %d ครั้ง" % [game.kills, game.run_time, game.hits]
			if game.encounter_mode=="coast":
				title.text="ชายหาดสงบแล้ว";description.text="ฝ่าฝูงชายฝั่งและปราบนายท้าย • %.1f วินาที\nกำจัด %d ตัว • กลับมาเริ่มใหม่ได้"%[game.run_time,game.kills]
				buttons.add_child(button("สำรวจชายหาดอีกครั้ง",game.start_coast))
			elif game.encounter_mode=="dungeon":
				title.text="ผ่านด่านสุ่มแล้ว"
				description.text="ปราบนายท้าย • เคลียร์ %d / %d ห้อง\nกำจัด %d ตัว • %.1f วินาที"%[game.dungeon.cleared,game.dungeon.rooms.size(),game.kills,game.run_time]
				buttons.add_child(button("สุ่มด่านใหม่",game.start_dungeon))
			elif game.encounter_mode=="captain":
				title.text="นายท้ายล้มแล้ว";description.text="ท่าเรือสงบลง • %.1f วินาที\nตัดแขนควบคุมโซ่เพื่อหยุดท่าขว้างได้"%game.run_time
				buttons.add_child(button("สู้กับนายท้ายอีกครั้ง",game.start_captain))
			else:buttons.add_child(button("ประลองอีกครั้ง", func(): game.start_run(false)))
			buttons.add_child(button("กลับไปซ้อม", func(): game.start_run(true)))
			buttons.add_child(button("กลับหน้าหลัก", game.return_menu))
		"shore_end":
			title.text="แนวป่าเบื้องหน้า"
			description.text="คุณผ่านชายหาดเรือแตกมาถึงทางเข้าป่าแล้ว\nจบพื้นที่เปิดเรื่อง • พื้นที่ป่าถัดไปยังอยู่ระหว่างออกแบบ"
			buttons.add_child(button("กลับไปริมหาด",game.start_wreck_shore))
			buttons.add_child(button("กลับหน้าหลัก",game.return_menu))
		"dead":
			title.text = "เปลวไฟยังไม่ดับ"
			description.text = "เว้นจังหวะให้คืนท่า แล้วหลบตอนศัตรูง้าง\nกำจัดแล้ว %d ตัว" % game.kills
			buttons.add_child(button("ลองอีกครั้ง", game.restart))
			buttons.add_child(button("กลับหน้าหลัก", game.return_menu))

	menu_scroll.custom_minimum_size.y=minf(380,buttons.get_child_count()*54)
	menu_scroll.scroll_vertical=0

func refresh() -> void:
	_refresh_mace_status()
	var dungeon_combat: bool = game.encounter_mode == "dungeon" and game.mode == "combat"
	charge_panel.visible=game.motion.is_great_charging() and game.mode in ["practice","combat"]
	if charge_panel.visible:
		var level: int=game.motion.great_charge.level()
		charge_label.text="ดาบใหญ่ • ระดับ %d/3 • %s"%[level,"เต็ม! ปล่อยเพื่อฟัน" if level==3 else "ค้างชาร์จ / ปล่อยฟัน"]
		charge_gauge.show_charge(game.motion.great_charge.elapsed)
	var ready_action: String=game.right_action()
	ready_text.text="การ์ดแตก • %.1f วิ"%game.readiness.broken_left if game.readiness.broken_left>0 else ("เล็ง • กระจาย ±%.2f°"%rad_to_deg(game.gun_spread(game.primary_family(),true)) if ready_action=="aim" else ("ตั้งการ์ด • ลดดาเมจด้านหน้า 30% • ไม่เสียพลัง" if ready_action=="guard" else "ขวาค้าง: เล็งปืน / การ์ดประชิด • ยึดมือหลัก"))
	if game.readiness.parry_flash>0:ready_text.text="PARRY! • ปัดสำเร็จ"
	elif game.readiness.parry_left>0:ready_text.text="พร้อมปัด • รับจังหวะกระทบ"
	if game.weapon_family=="greatsword" and not game.motion.busy and game._next_combo==2 and game.motion.great_charge.finisher_valid:
		var tier: int=game.motion.great_charge.finisher_level
		ready_text.text="ท่า 3 พร้อม • ระดับ %d/3 • ดาเมจ %d"%[tier,game.motion.great_charge.DAMAGE[2][tier-1]]
	if game.readiness.broken_left>0:ready_text.text=""
	ready_text.modulate=Color("ff9985") if game.readiness.broken_left>0 else Color.WHITE
	var pistol: bool = game.weapon_family == "pistol"
	var rifle: bool = game.weapon_family == "rifle"
	var gun: bool = pistol or rifle
	var magazine = game.active_magazine()
	if not game.loadout_mode:
		weapon_button.text = {"shield": "โล่ [I]", "crossbow": "หน้าไม้ [I]", "bow": "ธนู [I]", "rifle": "ปืนยาว [I]", "pistol": "ปืนพก [I]", "staff": "คทาไฟ [I]", "mace": "กระบอง [I]", "greatsword": "ดาบใหญ่ [I]", "sword": "ดาบมือเดียว [I]"}.get(game.weapon_family, "อาวุธ [I]")
	weapon_button.custom_minimum_size.y = 32 if gun else 42
	ammo_text.visible = gun
	ammo_text.text = "%d / %d • %s" % [magazine.rounds, magazine.capacity, "รีโหลด" if magazine.reloading else "R รีโหลด"]
	if game.has_dual_weapons():
		var parts: Array[String]=[]
		var pair: Dictionary=game.loadout.sets[game.loadout.active]
		for hand in ["main","off"]:
			var id: String=pair[hand]
			if game.item_magazines.has(id):
				var mag=game.item_magazines[id]
				parts.append(("ขวา " if hand=="main" else "ซ้าย ")+"%d/%d"%[mag.rounds,mag.capacity]+(" เติม" if mag.reloading else ""))
		if not parts.is_empty():ammo_text.visible=true;ammo_text.text=" | ".join(parts)
	reload_bar.visible = gun and magazine.reloading
	reload_bar.value = magazine.progress()
	control_hint.text = "WASD เดิน  •  ซ้ายโจมตี  •  ขวาค้าง: เล็ง / การ์ด  •  SPACE หลบ"
	var weapon_details: String = ("คลิกค้าง: ยิงซ้ำ    |    R รีโหลด    " if gun else ("คลิกค้าง: ยิงท่าเดิมซ้ำ    |    " if game.weapon_family == "staff" else "คลิกค้าง: 3 จังหวะ    |    ")) + ("" if game.sword_skills_available() else "") + "Q สลับชุด    I ของ    H ดูระยะ    T เริ่มใหม่    P สถานะ    ESC พัก    M เสียง"
	if game.weapon_family=="greatsword":weapon_details="ท่า1–2: ค้างชาร์จ / ปล่อยฟัน • ท่า3: คลิกฟาด | Q ชุด I ของ P สถานะ SPACE หลบ"
	weapon_button.disabled = game.motion.busy or game.guns_reloading() or game._dodge_left > 0 or game.mode not in ["menu", "practice", "combat"]
	if game.loadout_mode:
		weapon_button.text = "ชุด %d • ของ [I]" % [game.loadout.active + 1]
		weapon_button.disabled = false
		if not dungeon_combat:objective.text = "ชุด %d • %s" % [game.loadout.active + 1, game.loadout.items[game.active_item].name if game.active_item != "" else "ไม่มีอาวุธ"]
	if game.encounter_mode=="captain":objective.text="ท่าเรือร้าง • นายท้าย\nH ดูฮิตบ็อกซ์ • ตัดแขนโซ่ด้วยอาวุธมีคม"
	health_bar.max_value=game.max_health()
	health_bar.value = game.health
	flask_button.text="F  ยา %d/3%s"%[game.flasks.charges,"  •  +%.0f/วิ"%game.flasks.rate() if game.flasks.rate()>0 else ""]
	flask_button.disabled=game.mode not in ["practice","combat"] or game.inventory_open or game.stats_open or not game.body_action_ready() or game.flasks.charges<=0 or game.health>=game.max_health()
	health_text.text="เลือด %d / %d"%[ceili(game.health),int(game.max_health())]
	if game.mode == "practice":
		objective.text = "ลานซ้อม • ลูกไฟช้าแต่แรง ระเบิดใส่ตัวใกล้เคียง" if game.weapon_family == "staff" else "ลานซ้อม • เดินเข้าระยะ แล้วลองโจมตีต่อเนื่อง"
		if pistol: objective.text = "ลานซ้อม • ยิงทีละนัด โดนตัวแรกแล้วหาย • R รีโหลด"
		if rifle: objective.text = "ลานซ้อม • ปืนยาวแรงถอยหลัง • ทะลุเฉพาะตัวที่ยืนชิด"
		var damage_text: String = str(int(game.total_damage)) if is_equal_approx(game.total_damage, roundf(game.total_damage)) else "%.1f" % game.total_damage
		counter.text = "โดน %d ครั้ง\nดาเมจรวม %s" % [game.hits, damage_text]
	elif game.mode == "combat" and not dungeon_combat:
		objective.text = "ระลอก %d / 3 • ระวังวงเตือนก่อนศัตรูโจมตี" % game.wave
		counter.text = "กำจัด %d / 11\n%.1f วินาที" % [game.kills, game.run_time]
	elif not dungeon_combat:
		counter.text = ""
	if game.loadout_mode and not dungeon_combat:
		var pair: Dictionary = game.loadout.sets[game.loadout.active]
		var main_name: String = game.loadout.items[pair.main].name if pair.main != "" else "ว่าง"
		var off_name: String = game.loadout.items[pair.off].name if pair.off != "" else "—"
		objective.text = "ชุด %d • %s / %s%s" % [game.loadout.active + 1, main_name, off_name, " • รอเปลี่ยนชุด" if game.pending_set >= 0 else ""]
	if game.drill_kind!="" and game.mode=="practice":
		objective.text="ชาวประมง • เดินวนดู 4 มุม • ง้างนานแล้วฟาดลง\nขวากัน/ปัด • SPACE หลบ • H ตรวจ • T เริ่มใหม่" if game.drill_kind=="fisherman" else "ฝึกปัด • %s • V เปลี่ยนมอน • แสงแดงปัดไม่ได้ แต่กันได้"%{"melee":"นักรบ","ranged":"พลยิง","elite":"อัศวิน"}.get(game.drill_kind,"มอน")
	var dungeon_hud: bool = game.encounter_mode == "dungeon" and game.mode in ["combat", "victory"]
	var panels_available: bool = dungeon_hud and not game.inventory_open and not game.stats_open and not game.body_lab_open
	var current_room: Dictionary = game.dungeon.rooms.get(game.dungeon.current, {}) if dungeon_hud else {}
	var show_map: bool = panels_available and current_room.get("cleared", false)
	if dungeon_map_panel.visible != show_map:
		dungeon_map_panel.visible = show_map
		if not show_map: ammo_panel.set_deferred("size", Vector2(300, 136))
	if show_map:
		dungeon_map.refresh(game.dungeon)
	companion_panel.visible = panels_available and not game.expedition_companions.is_empty()
	if companion_panel.visible:
		for index in game.companions.size():
			var companion = game.companions[index]
			companion_bars[index].value = companion.health
			var state: String = game.expedition_companions[index].get("role", "")
			if companion.downed: state = "ล้มอยู่ · กด E ค้างเพื่อชุบ"
			elif companion.dash_left > 0.0: state = "กำลังแดชหลบ"
			elif companion.recalling(): state = "กำลังถอย"
			elif is_instance_valid(game.party_mark_target) and not game.party_mark_target.dead: state = "โจมตีเป้าที่ปัก"
			elif game.party_mark_left > 0.0: state = "ไปจุดที่ปัก"
			companion_labels[index].text = state
	if dungeon_combat:
		var room: Dictionary=game.dungeon.rooms[game.dungeon.current]
		var directions := ""
		for direction in room.links:
			directions += {Vector2i.UP:"↑ ",Vector2i.RIGHT:"→ ",Vector2i.DOWN:"↓ ",Vector2i.LEFT:"← "}[direction]
		objective.text = "ห้องบอส • ปราบนายท้าย" if game.dungeon.current==game.dungeon.goal else (
			("จุดเริ่มปลอดภัย" if game.dungeon.current == game.dungeon.start else "ห้องโล่ง") + " • เดินผ่านทางออก " + directions if room.cleared else "กำจัดมอนให้หมดเพื่อเปิดประตู "+directions)
		counter.text="มอนเหลือ %d\nผ่าน %d / %d ห้อง"%[game.dungeon.remaining,game.dungeon.cleared,game.dungeon.rooms.size()]
	var phase: String = game.current_visual_sample().get("phase", "idle")
	if game.drill_kind=="brinehound" and game.mode=="practice":objective.text="หมาน้ำเค็ม • ย่อตัว → กระโจนกัด → กัดซ้ำ\nขวากัน/ปัด • SPACE หลบ • H ตรวจ • T เริ่มใหม่"
	if game.drill_kind=="crewman" and game.mode=="practice":objective.text="ลูกเรือ • ง้าง → ขว้างฉมวก → พัก\nขวากัน/ปัด • SPACE หลบ • H ตรวจ • T เริ่มใหม่"
	if game.encounter_mode=="village_study":objective.text="หมู่บ้านร้างริมทะเล • พื้นที่ตัวอย่าง\nWASD เดินสำรวจ • เข้าประตูดูภายใน • T เริ่มใหม่ • ESC พัก"
	if game.drill_kind=="spitter" and game.mode=="practice":objective.text="ผู้สำรอกน้ำเค็ม • ง้าง → อ้วกเป็นสาย → คราบพิษ 3 วิ\nแดงปัดไม่ได้ • กันได้ • SPACE หลบออกข้าง • H ตรวจ • T เริ่มใหม่"
	if game.drill_kind=="net_hauler" and game.mode=="practice":objective.text="ลูกเรือลากอวน • ยก → ง้างค้าง → ฟาดลง\nขวากัน/ปัด • แดงปัดไม่ได้ • SPACE หลบ • H ตรวจ • T เริ่มใหม่"
	var stage_label: String = ("Ⅰ  ฟันขวา" if game.motion.stage == 0 else ("Ⅱ  ฟันกลับซ้าย" if game.motion.stage == 1 else "Ⅲ  ฟันเฉียง")) if game.motion.busy else "Ⅰ → Ⅱ → Ⅲ"
	if game.weapon_family == "greatsword" and game.motion.busy:
		stage_label = "Ⅰ  กวาดข้าง" if game.motion.stage == 0 else ("Ⅱ  กวาดกลับ" if game.motion.stage == 1 else "Ⅲ  ฟาดตรง")
	if game.weapon_family == "mace" and game.motion.busy:
		stage_label = "Ⅰ  ฟาดขึ้น" if game.motion.stage == 0 else ("Ⅱ  พุ่งตี" if game.motion.stage == 1 else "Ⅲ  ฟาดลง")
	if game.weapon_family == "staff":
		stage_label = {"windup": "เตรียมยิง", "active": "ปล่อยลูกไฟ", "recovery": "คืนท่า"}.get(phase, "ลูกไฟ • ระเบิดวงเล็ก")
	if pistol:
		stage_label = "หมุนปืน / รีโหลด" if game.active_magazine().reloading else {"windup": "เตรียมยิง", "active": "ยิง", "recovery": "คืนท่า"}.get(phase, "ยิงทีละนัด")
	if rifle:
		stage_label = "รีโหลดปืนยาว" if game.active_magazine().reloading else {"windup": "ประทับยิง", "active": "ยิง / แรงถอย", "recovery": "คืนท่า"}.get(phase, "ปืนยาว • 5 นัด")
	if game.skill_active:
		if game.active_skill_id == "armor_pierce":
			var action: String = "ฟัน" if game.skill_cut_index == 0 else "แทง / เจาะเกราะ"
			stage_label = "เจาะเกราะ %d/2 • %s" % [game.skill_cut_index + 1, {"windup": "ง้าง", "active": action, "recovery": "คืนท่า"}.get(phase, "")]
		else:
			stage_label = "Twin Cut %d/2 • %s" % [game.skill_cut_index + 1, {"windup": "ง้าง", "active": "ฟัน", "recovery": "คืนท่า"}.get(phase, "")]
	if game.loadout_mode and not game.skill_active:
		var hand_hint: String = ("ขวา→ซ้าย 1/2" if game.pair_strikes.cursor==0 else "ขวา→ซ้าย 2/2") if game.pair_strikes.active else ""
		stage_label = "%d/3 %s • %s" % [(game._loadout_attack_index if game.motion.busy else game._next_combo)+1, hand_hint, stage_label]
	stage_text.modulate = Color("#ffdb8c") if phase == "active" else Color.WHITE
	if rifle:
		var cycle=game.active_magazine()
		ammo_text.text="%d / %d • %s"%[cycle.rounds,cycle.capacity,{"open":"เปิดกลไก","insert":"เติมทีละนัด","close":"ปิดกลไก"}.get(cycle.phase,"ขึ้นลำ" if cycle.needs_bolt else "R เติมกระสุน")]
		if cycle.reloading:reload_bar.value=cycle.action_progress()
		stage_label="เล็ง • ปืนยาว" if game.rifle_aiming() else "ปืนยาว"
		if game.motion.busy:stage_label="เตรียมยิง" if game.current_visual_sample().phase=="windup" else "ยิง / คืนท่า"
		if cycle.needs_bolt or cycle.bolt_active:stage_label="ขึ้นลำก่อนยิง"
		if cycle.reloading:stage_label="เติมกระสุนทีละนัด"
		weapon_details="ปกติ: เป้าบาน • ขวา: เล็งไกล / ทะลุ • ยิงโดนสะสม Mark • R เติมทีละนัด • Q ชุด I ของ SPACE หลบ"
	if game.primary_family() == "bow":
		var bow_tier: int = game.bow_tier()
		stage_label = "ชาร์จ %d/3" % bow_tier if bow_tier > 0 else "ธนู"
		ready_text.text = "เต็มขั้น • ปล่อยเพื่อยิงแล้วถอย" if bow_tier == 3 else ""
		control_hint.text = "WASD เดิน  •  คลิกซ้ายค้างชาร์จ / ปล่อยยิง  •  SPACE หลบ"
		weapon_details = "ธนู • ชาร์จ 3 ขั้น • Q สลับชุด • I ของ • ESC พัก"
	if game.primary_family() == "crossbow":
		var bolt = game.crossbow_magazine()
		ammo_text.visible = true
		ammo_text.text = "พร้อมยิง • 1 ลูก" if bolt.can_fire() else ("กำลังขึ้นลำ" if bolt.reloading else "ยังไม่ขึ้นลำ • กด R")
		reload_bar.visible = bolt.reloading
		reload_bar.value = bolt.progress()
		stage_label = "หน้าไม้"
		ready_text.text = ""
		control_hint.text = "WASD เดิน  •  R ขึ้นลำ  •  คลิกซ้ายยิง  •  SPACE หลบ"
		weapon_details = "หน้าไม้ • ขึ้นลำเก็บไว้ได้ • ยิงโดนสร้างแผลลึก"
	if game.has_shield():
		ready_text.text = "กางโล่ • รับแรงด้วยสแตมิน่า • กันดาเมจพื้นที่ไม่ได้" if ready_action == "guard" else "คลิกขวาค้างเพื่อกางโล่"
		if game.primary_family() == "shield": stage_label = "โล่"
	stage_text.text = stage_label
	_staff_instructions()
	_arrange_status_and_hints(weapon_details)
	if game.encounter_mode=="captain":objective.text="ท่าเรือร้าง • นายท้าย\nอาวุธมีคมตัดแขนโซ่ • H ดูระยะ"
	if game.encounter_mode=="coast":
		objective.text="ชายหาดร้าง • เหลือ %d ตัว\nสำรวจตามชายฝั่งไปทางขวา"%game.coast.living(game) if game.coast.stage=="ordinary" else "นายท้ายสมอ • ปลายชายหาด\nแสงแดงปัดไม่ได้ แต่กันได้"
		counter.text="กำจัด %d • %.1f วินาที"%[game.kills,game.run_time]

	var study: bool=game.encounter_mode in ["village_study","coast_forms","wreck_shore"]
	for panel_: Control in [header_panel,vital_panel,ammo_panel,help_panel]:panel_.visible=not study
	study_panel.visible=study and game.mode=="practice"
	if game.encounter_mode=="wreck_shore":
		study_panel.get_child(0).text="คลื่นพัดคุณมาเกยฝั่ง…  •  Enter ข้ามช่วงตื่น  •  ESC พัก" if not game.arena.intro_done() else ("เรือลำนั้น…  •  เดินเฉียงขึ้นขวาไปยังแนวป่า  •  WASD เดิน  •  SPACE แดช  •  T เริ่มใหม่  •  ESC พัก" if game.arena.reveal_seen else "ไม่มีอาวุธติดตัว  •  เดินเลียบหาดเฉียงขึ้นขวา  •  WASD เดิน  •  SPACE แดช  •  T เริ่มใหม่  •  ESC พัก")
	elif game.encounter_mode=="coast_forms":
		var form: int=game.arena.form_index(game.player.position.x)
		study_panel.get_child(0).text="แบบ %d/5 • %s    |    1–5 ข้ามดูแต่ละแบบ • WASD เดิน • ล้อเมาส์ซูม • T เริ่มใหม่ • ESC พัก"%[form+1,game.arena.FORMS[form]]
	else:study_panel.get_child(0).text="หมู่บ้านร้างริมทะเล  •  WASD เดินสำรวจ  •  เข้าประตูดูภายใน  •  ล้อเมาส์ ซูม  •  SPACE แดช  •  T เริ่มใหม่  •  ESC พัก"
	if study:status_panel.visible=false;charge_panel.visible=false

func _refresh_mace_status() -> void:
	mace_status_panel.visible=false

func _staff_instructions() -> void:
	if game.primary_family()!="staff":return
	ready_text.text="ขวาค้าง: เติมลูกไฟรอบคถา • ซ้ายค้างรวมพลัง / ปล่อยยิง"
	control_hint.text="WASD เดิน • ขวาค้างเติมพลัง • ซ้ายค้างร่าย / ปล่อยยิง • SPACE หลบ"
	weapon_hint.text="ลูกไฟรอบคถาคือพลังสำรอง • Q สลับชุด • I ของ • P สถานะ • ESC พัก"
	stage_text.text="เติมพลัง" if game.staff_energy.loading else ("รวมพลัง" if game.staff_energy.casting else "คถาไฟ")

func compact_panel() -> StyleBoxFlat:
	var style:=panel()
	style.content_margin_left=14;style.content_margin_right=14;style.content_margin_top=10;style.content_margin_bottom=10
	return style
func _arrange_status_and_hints(weapon_details: String) -> void:
	status_view.refresh(game)
	status_panel.visible=not status_view.shown_effects.is_empty() and game.mode in ["practice","combat"] and not game.inventory_open and not game.stats_open
	status_panel.reset_size()
	if game.health<=0 and game.mode in ["practice","combat"]:ready_text.text="วิกฤต • เลือด 0 • ระวังทุกท่าสีแดง"
	weapon_hint.tooltip_text=weapon_details
	weapon_hint.text="R รีโหลด • Q ชุด • I ของ • P สถานะ • H ตรวจ • T ใหม่ • M เสียง • ESC พัก"
	if game.primary_family() == "crossbow":weapon_hint.text = "ยิงโดนสร้างแผลลึก • ขึ้นลำขณะเดินช้าได้ • I ของ"
	if game.primary_family() == "bow":weapon_hint.text = "ธนู • ค้างคลิกซ้ายชาร์จ 3 ขั้น • ปล่อยขั้นเต็มเพื่อยิงแล้วถอย"
	if game.primary_family()=="staff":weapon_hint.text="ลูกไฟรอบคถา = พลังสำรอง • Q ชุด • I ของ • P สถานะ • H ตรวจ • T ใหม่ • M เสียง • ESC พัก"
	if game.primary_family()=="greatsword":weapon_hint.text="ท่า1–2 ค้างชาร์จ / ปล่อยฟัน • ท่า3 คลิกฟาด • Q ชุด • I ของ • P สถานะ • ESC พัก"

