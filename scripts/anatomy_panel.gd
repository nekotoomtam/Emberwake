extends CanvasLayer
## Compact body readout. Detailed controls live in the separate body lab.
const Anatomy = preload("res://scripts/anatomy_state.gd")
const PARTS = Anatomy.PARTS
const NAMES := {
 "head":"ศีรษะ", "torso":"ลำตัว",
 "right_upper_arm":"ต้นแขนขวา", "left_upper_arm":"ต้นแขนซ้าย",
 "right_forearm":"ท่อนแขนขวา", "left_forearm":"ท่อนแขนซ้าย",
 "right_thigh":"ต้นขาขวา", "left_thigh":"ต้นขาซ้าย",
 "right_lower_leg":"หน้าแข้งขวา + เท้า", "left_lower_leg":"หน้าแข้งซ้าย + เท้า",
}
const GOOD := Color("#9bdbc6")
const WARN := Color("#e9bb73")
const BAD := Color("#ed8684")
var game
var surface: Control
var compact: PanelContainer
var modal: Control
var diagram: BodyDiagram
var part_buttons: Dictionary = {}
var selected: String = "left_upper_arm"
var selected_label: Label
var consequences: Label
var slider: HSlider
var slider_value: Label
var _syncing := false

class BodyDiagram extends Control:
 var states: Dictionary = {}
 func _draw() -> void:
  var shapes := {
   "head":Rect2(33,3,24,23), "torso":Rect2(27,31,36,43),
   "right_upper_arm":Rect2(12,32,12,23), "left_upper_arm":Rect2(66,32,12,23),
   "right_forearm":Rect2(12,58,12,22), "left_forearm":Rect2(66,58,12,22),
   "right_thigh":Rect2(27,78,16,25), "left_thigh":Rect2(47,78,16,25),
   "right_lower_leg":Rect2(27,106,16,25), "left_lower_leg":Rect2(47,106,16,25)}
  for part in shapes:
   var state: Dictionary = states.get(part,{"value":100.0,"present":true})
   var value: float = float(state.value)
   var present: bool = bool(state.present)
   var tint := Color("#9bdbc6") if value > 60 else Color("#e9bb73") if value > 0 else Color("#ed8684")
   if not present:tint=Color("#555b65")
   var rect: Rect2 = shapes[part]
   draw_rect(rect, Color(tint,0.18))
   if present and value > 0:
    draw_rect(Rect2(rect.position+Vector2(2,rect.size.y*(1-value/100.0)),Vector2(rect.size.x-4,maxf(1,rect.size.y*value/100.0-2))),Color(tint,0.58))
   draw_rect(rect,tint,false,1.5)
   if not present:
    draw_line(rect.position,rect.end,tint,2)
    draw_line(Vector2(rect.end.x,rect.position.y),Vector2(rect.position.x,rect.end.y),tint,2)

func _ready() -> void:
 layer=11
 surface=Control.new()
 surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(surface)
 var theme:=Theme.new()
 var font:=SystemFont.new()
 font.font_names=PackedStringArray(["Tahoma","Noto Sans Thai"])
 theme.default_font=font
 theme.default_font_size=15
 surface.theme=theme
 _build_compact()
 _build_lab()
 refresh()

func _box() -> StyleBoxFlat:
 var style:=StyleBoxFlat.new()
 style.bg_color=Color("#101e29",0.95)
 style.border_color=Color("#62717a")
 style.set_border_width_all(1)
 style.set_corner_radius_all(6)
 style.set_content_margin_all(12)
 return style

func _label(text: String, font_size: int=15, color: Color=Color("#e6e8e8")) -> Label:
 var result:=Label.new()
 result.text=text
 result.add_theme_font_size_override("font_size",font_size)
 result.add_theme_color_override("font_color",color)
 result.mouse_filter=Control.MOUSE_FILTER_IGNORE
 return result

func _button(text: String, action: Callable, parent: Node) -> Button:
 var button:=Button.new()
 button.text=text
 button.custom_minimum_size.y=36
 button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 button.pressed.connect(action)
 parent.add_child(button)
 return button

func _build_compact() -> void:
 compact=PanelContainer.new()
 compact.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 compact.position=Vector2(20,124)
 compact.size=Vector2(118,166)
 compact.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var style:=_box()
 style.set_content_margin_all(7)
 compact.add_theme_stylebox_override("panel",style)
 surface.add_child(compact)
 var column:=VBoxContainer.new()
 column.add_theme_constant_override("separation",3)
 column.mouse_filter=Control.MOUSE_FILTER_IGNORE
 compact.add_child(column)
 var title:=_label("สภาพร่างกาย [B]",13,WARN)
 title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 column.add_child(title)
 var center:=CenterContainer.new()
 center.mouse_filter=Control.MOUSE_FILTER_IGNORE
 column.add_child(center)
 diagram=BodyDiagram.new()
 diagram.custom_minimum_size=Vector2(90,134)
 diagram.mouse_filter=Control.MOUSE_FILTER_IGNORE
 center.add_child(diagram)

func _build_lab() -> void:
 modal=Control.new()
 modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 modal.mouse_filter=Control.MOUSE_FILTER_STOP
 surface.add_child(modal)
 var shade:=ColorRect.new()
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 shade.color=Color(0.015,0.025,0.04,0.88)
 shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
 modal.add_child(shade)
 var center:=CenterContainer.new()
 center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 center.mouse_filter=Control.MOUSE_FILTER_IGNORE
 modal.add_child(center)
 var panel:=PanelContainer.new()
 panel.custom_minimum_size=Vector2(740,510)
 panel.add_theme_stylebox_override("panel",_box())
 center.add_child(panel)
 var column:=VBoxContainer.new()
 column.add_theme_constant_override("separation",8)
 panel.add_child(column)
 column.add_child(_label("ห้องทดสอบร่างกาย",24,WARN))
 column.add_child(_label("หยุดการเล่นชั่วคราว • เลือกส่วนร่างกาย แล้วทดลองผลที่เกิดขึ้น",15))
 var grid:=GridContainer.new()
 grid.columns=5
 grid.add_theme_constant_override("h_separation",8)
 grid.add_theme_constant_override("v_separation",6)
 column.add_child(grid)
 var group:=ButtonGroup.new()
 for part in PARTS:
  var button:=_button(NAMES[part],_select.bind(part),grid)
  button.toggle_mode=true
  button.button_group=group
  button.custom_minimum_size.x=131
  part_buttons[part]=button
 selected_label=_label("",17,GOOD)
 column.add_child(selected_label)
 var slider_row:=HBoxContainer.new()
 column.add_child(slider_row)
 slider=HSlider.new()
 slider.min_value=0
 slider.max_value=100
 slider.step=1
 slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 slider.custom_minimum_size.y=26
 slider.value_changed.connect(_slider_changed)
 slider_row.add_child(slider)
 slider_value=_label("100%",16)
 slider_value.custom_minimum_size.x=55
 slider_row.add_child(slider_value)
 var presets:=HBoxContainer.new()
 presets.add_theme_constant_override("separation",8)
 column.add_child(presets)
 for value in [100,60,30,0]:
  _button("ตั้ง %d%%"%value,_set_integrity.bind(float(value)),presets)
 var actions:=HBoxContainer.new()
 actions.add_theme_constant_override("separation",8)
 column.add_child(actions)
 _button("โจมตีปกติ −30 HPย่อย",_hit.bind(false),actions)
 _button("โจมตีแดง −30 HPย่อย",_hit.bind(true),actions)
 _button("ทำลาย / สูญเสีย",_remove,actions)
 _button("คืนส่วนที่เลือก",_restore_selected,actions)
 consequences=_label("",16)
 consequences.custom_minimum_size.y=58
 column.add_child(consequences)
 column.add_child(_label("ศีรษะ 0% = ตาย • ลำตัว 0% ยังมีแกนชีวิต แต่ร่างกายอ่อนแรง",14,WARN))
 column.add_child(_label("ส่วนที่สูญเสีย: ใช้ปุ่มคืนส่วนที่เลือก • T เริ่มใหม่ ฟื้นร่างกายทั้งหมด",14))
 var bottom:=HBoxContainer.new()
 bottom.add_theme_constant_override("separation",8)
 column.add_child(bottom)
 _button("ฟื้นร่างกายทั้งหมด",_restore_all,bottom)
 _button("ทดสอบชีวิต 0",_zero_health,bottom)
 _button("กลับไปเล่น [B / ESC]",toggle,bottom)
 modal.visible=false

func _select(part: String) -> void:
 selected=part
 refresh()

func _set_integrity(value: float) -> void:
 game.set_body_integrity(selected,value)
 refresh()

func _slider_changed(value: float) -> void:
 if not _syncing:_set_integrity(value)

func _hit(red: bool) -> void:
 game.hit_body_part(selected,30.0,red)
 refresh()

func _remove() -> void:
 game.remove_body_part(selected)
 refresh()

func _restore_selected() -> void:
 game.restore_body_part(selected)
 refresh()

func _restore_all() -> void:
 game.restore_body()
 refresh()

func _zero_health() -> void:
 game.set_debug_health_zero()
 refresh()

func toggle() -> void:
 game.toggle_body_lab()
 refresh()

func _input(event: InputEvent) -> void:
 if game==null or not event is InputEventKey:return
 var key:=event as InputEventKey
 if not key.pressed or key.echo:return
 var code: int=key.physical_keycode if key.physical_keycode else key.keycode
 if code==KEY_B or (code==KEY_ESCAPE and bool(game.body_lab_open)):
  toggle()
  get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
 if game!=null and bool(game.body_lab_open):refresh()

func refresh() -> void:
 if not is_instance_valid(surface) or game==null:return
 modal.visible=bool(game.body_lab_open)
 var states: Dictionary={}
 for part in PARTS:
  var value: float=float(game.anatomy.integrity.get(part,100.0))
  var present: bool=bool(game.anatomy.present(part))
  states[part]={"value":value,"present":present}
  var suffix: String="%d%%"%roundi(value) if present else "สูญเสีย"
  if modal.visible:
   part_buttons[part].text="%s  %s"%[NAMES[part],suffix]
   part_buttons[part].set_pressed_no_signal(part==selected)
 if diagram.states != states:
  diagram.states=states
  diagram.queue_redraw()
 if not modal.visible:return
 var selected_value: float=float(game.anatomy.integrity.get(selected,100.0))
 var selected_present: bool=bool(game.anatomy.present(selected))
 var status: String="ใช้งานได้" if game.anatomy.functional(selected) else "ใช้งานไม่ได้"
 if game.anatomy.functional(selected) and selected_value<=60:
  var effects := {"head":"มองไกล 80%","torso":"ค่าพลังงาน 120%"}
  var limb_effect := "ตี / รีโหลด 90%" if selected.ends_with("arm") else "พลังงานแดช 125%"
  status="บาดเจ็บ: "+effects.get(selected,limb_effect)
 if not selected_present:status="สูญเสีย"
 selected_label.text="%s • %.1f / %.1f HP • %d%% • %s"%[NAMES[selected],float(game.anatomy.part_hp(selected)),float(game.anatomy.part_max(selected)),roundi(selected_value),status]
 _syncing=true
 slider.set_value_no_signal(selected_value)
 slider.editable=selected_present
 slider_value.text="%d%%"%roundi(selected_value)
 _syncing=false
 consequences.text="ชีวิตสูงสุด %.0f  •  เพดานชีวิต %d%%  •  ความเร็วเดิน %d%%\nแขนที่ใช้ได้ %d/2  •  ขาที่ใช้ได้ %d/2  •  แดช %d%%"%[float(game.max_health()),roundi(float(game.anatomy.hp_multiplier())*100),roundi(float(game.anatomy.move_multiplier())*100),int(game.anatomy.arm_count()),int(game.anatomy.leg_count()),roundi(float(game.anatomy.dash_multiplier())*100)]
