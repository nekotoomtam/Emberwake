extends CanvasLayer
signal view_requested(id: StringName)
signal start_requested
signal legacy_requested
signal appearance_requested
signal exit_requested
var footer: HBoxContainer
var caption: PanelContainer
var caption_text: Label
var bark_panel: PanelContainer
var bark_text: Label
var audio
var menu: PanelContainer
var settings_shade: ColorRect
var settings: PanelContainer
var start_button: Button
var continue_button: Button
var settings_button: Button
var exit_button: Button
var legacy_button: Button
var appearance_button: Button
var back_button: Button
var volume_slider: HSlider
var mute_button: CheckButton
var fullscreen_button: CheckButton
var settings_close: Button
var views: Dictionary={}
var tint:=Color("243c43")
func _ready() -> void:
 var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
 var theme:=Theme.new();var font:=SystemFont.new();font.font_names=PackedStringArray(["Leelawadee UI","Tahoma"]);theme.default_font=font;theme.default_font_size=20;root.theme=theme
 menu=PanelContainer.new();menu.name="RightMenu";menu.anchor_left=.625;menu.anchor_top=.08;menu.anchor_right=.965;menu.anchor_bottom=.94
 var paper:=StyleBoxFlat.new();paper.bg_color=Color(.93,.89,.79,.94);paper.corner_radius_top_left=6;paper.corner_radius_bottom_left=6;paper.border_width_left=2;paper.border_color=Color("b69b72");paper.shadow_size=18;paper.shadow_color=Color(0,.07,.10,.20);menu.add_theme_stylebox_override("panel",paper);root.add_child(menu)
 var margin:=MarginContainer.new();margin.add_theme_constant_override("margin_left",26);margin.add_theme_constant_override("margin_right",26);margin.add_theme_constant_override("margin_top",20);margin.add_theme_constant_override("margin_bottom",16);menu.add_child(margin)
 var col:=VBoxContainer.new();col.add_theme_constant_override("separation",5);margin.add_child(col)
 var eyebrow:=_label("บันทึกการเดินทาง",16);eyebrow.modulate=Color("7d6d54");col.add_child(eyebrow)
 var title:=_label("EMBERWAKE",36);var serif:=SystemFont.new();serif.font_names=PackedStringArray(["Georgia"]);title.add_theme_font_override("font",serif);col.add_child(title)
 col.add_child(_label("ก่อนการเดินทางครั้งใหม่",23))
 var line:=HSeparator.new();col.add_child(line)
 var subtitle:=_label("เรือลำใหม่กำลังมาถึงเมืองท่า",17);subtitle.modulate=Color("6f7973");col.add_child(subtitle)
 var spacer:=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;col.add_child(spacer)
 start_button=_button("เริ่มเรื่อง");start_button.disabled=false;start_button.pressed.connect(func():start_requested.emit());col.add_child(start_button)
 continue_button=_button("เล่นต่อ");continue_button.disabled=true;continue_button.tooltip_text="ยังไม่มีบทที่บันทึกไว้";col.add_child(continue_button)
 settings_button=_button("ตั้งค่า");settings_button.pressed.connect(open_settings);col.add_child(settings_button)
 exit_button=_button("ออกจากเกม");exit_button.pressed.connect(func():exit_requested.emit());col.add_child(exit_button)
 var lower_space:=Control.new();lower_space.size_flags_vertical=Control.SIZE_EXPAND_FILL;col.add_child(lower_space)
 var gap:=Control.new();gap.custom_minimum_size.y=8;col.add_child(gap)
 legacy_button=_button("ฉากทดลองเดิม  ↗",16);legacy_button.custom_minimum_size.y=34;legacy_button.pressed.connect(func():legacy_requested.emit());col.add_child(legacy_button)
 var note:=_label("เริ่มเรื่องเพื่อชมเรือเข้าท่าและพบตัวเอก",13);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;note.modulate=Color("827d6e");col.add_child(note)
 footer=HBoxContainer.new();footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);footer.position=Vector2(22,-58);footer.add_theme_constant_override("separation",8);root.add_child(footer)
 for row in [[&"cafe","1 · โต๊ะกาแฟ"],[&"market","2 · ตลาดริมท่า"],[&"quay","3 · ท่าเรือ"],[&"port","4 · เมืองท่า"]]:
  var button:=_button(row[1],16);button.custom_minimum_size=Vector2(140,36);button.pressed.connect(func():view_requested.emit(row[0]));footer.add_child(button);views[row[0]]=button
 appearance_button=_button("5 · ตัวละคร 4 ทิศ",16);appearance_button.custom_minimum_size=Vector2(170,36);appearance_button.pressed.connect(func():appearance_requested.emit());footer.add_child(appearance_button)
 back_button=_button("← กลับเมนูเมืองท่า",18);back_button.position=Vector2(24,24);back_button.custom_minimum_size=Vector2(210,42);back_button.visible=false;back_button.pressed.connect(func():view_requested.emit(&"lighthouse"));root.add_child(back_button)
 caption=PanelContainer.new();caption.anchor_left=.22;caption.anchor_right=.78;caption.anchor_top=.80;caption.anchor_bottom=.92;caption.visible=false;root.add_child(caption)
 var speech:=StyleBoxFlat.new();speech.bg_color=Color(.94,.90,.80,.96);speech.content_margin_left=20;speech.content_margin_right=20;speech.content_margin_top=12;speech.content_margin_bottom=12;speech.corner_radius_top_left=6;speech.corner_radius_bottom_right=6;caption.add_theme_stylebox_override("panel",speech)
 caption_text=_label("",22);caption_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption_text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;caption_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.add_child(caption_text)
 _actor_speech(root)
 _settings(root)
 start_button.grab_focus()
func _actor_speech(root: Control) -> void:
 bark_panel=PanelContainer.new();bark_panel.name="ProtagonistSpeech";bark_panel.visible=false;bark_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;bark_panel.custom_minimum_size=Vector2(380,62)
 var paper:=StyleBoxFlat.new();paper.bg_color=Color(.96,.93,.85,.98);paper.border_width_bottom=2;paper.border_color=Color("a38e6c");paper.corner_radius_top_left=7;paper.corner_radius_top_right=7;paper.corner_radius_bottom_left=7;paper.corner_radius_bottom_right=7;paper.content_margin_left=16;paper.content_margin_right=16;paper.content_margin_top=12;paper.content_margin_bottom=12;bark_panel.add_theme_stylebox_override("panel",paper);root.add_child(bark_panel)
 bark_text=_label("",21);bark_text.custom_minimum_size.x=348;bark_text.size.x=348;bark_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;bark_text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;bark_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;bark_text.mouse_filter=Control.MOUSE_FILTER_IGNORE;bark_panel.add_child(bark_text)
func show_actor_bark(value: String,at: Vector2) -> void:
 bark_text.text=value;bark_panel.size=Vector2(380,62);bark_panel.visible=true;position_actor_bark(at)
func position_actor_bark(at: Vector2) -> void:
 var viewport: Vector2=get_viewport().get_visible_rect().size
 bark_panel.position=Vector2(clampf(at.x-bark_panel.size.x*.5,16,maxf(16,viewport.x-bark_panel.size.x-16)),clampf(at.y-bark_panel.size.y-12,16,maxf(16,viewport.y-bark_panel.size.y-16)))
func hide_actor_bark() -> void:bark_panel.visible=false;bark_text.text=""
func _label(value: String,size_: int) -> Label:
 var label:=Label.new();label.text=value;label.add_theme_color_override("font_color",tint);label.add_theme_font_size_override("font_size",size_);return label
func _button(value: String,size_: int=21) -> Button:
 var button:=Button.new();button.text=value;button.custom_minimum_size=Vector2(0,42);button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.add_theme_font_size_override("font_size",size_)
 for state in ["normal","hover","pressed","focus","disabled"]:
  var style:=StyleBoxFlat.new();style.bg_color=Color("dfd6be") if state=="disabled" else Color("c5d1c5") if state in ["hover","focus"] else Color("b8c9bd") if state=="pressed" else Color("e9e3d1")
  style.content_margin_left=14;style.content_margin_right=14;style.border_width_bottom=1;style.border_color=Color("c1b89f");style.corner_radius_top_left=3;style.corner_radius_bottom_right=3
  button.add_theme_stylebox_override(state,style)
 button.add_theme_color_override("font_focus_color",tint);button.add_theme_color_override("font_pressed_color",tint);button.add_theme_color_override("font_color",tint);button.add_theme_color_override("font_hover_color",Color("173d40"));button.add_theme_color_override("font_disabled_color",Color("938b78"));return button
func _settings(root: Control) -> void:
 settings_shade=ColorRect.new();settings_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);settings_shade.color=Color(0,.06,.08,.35);settings_shade.visible=false;root.add_child(settings_shade)
 settings=PanelContainer.new();settings.name="Settings";settings.anchor_left=.26;settings.anchor_right=.74;settings.anchor_top=.22;settings.anchor_bottom=.78;settings.visible=false
 var style:=StyleBoxFlat.new();style.bg_color=Color("eee5cf");style.border_width_top=2;style.border_color=Color("9c835d");style.content_margin_left=28;style.content_margin_right=28;style.content_margin_top=22;style.content_margin_bottom=22;settings.add_theme_stylebox_override("panel",style);root.add_child(settings)
 var col:=VBoxContainer.new();col.add_theme_constant_override("separation",14);settings.add_child(col);col.add_child(_label("ตั้งค่า",28));col.add_child(_label("ระดับเสียงบรรยากาศ",19))
 volume_slider=HSlider.new();volume_slider.min_value=0;volume_slider.max_value=1;volume_slider.step=.05;volume_slider.value=.65;volume_slider.custom_minimum_size.y=30;volume_slider.value_changed.connect(func(value):if audio!=null:audio.set_volume(value));col.add_child(volume_slider)
 mute_button=CheckButton.new();mute_button.text="ปิดเสียง";mute_button.toggled.connect(func(value):if audio!=null:audio.set_muted(value));col.add_child(mute_button)
 fullscreen_button=CheckButton.new();fullscreen_button.text="เต็มหน้าจอ";fullscreen_button.button_pressed=DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN;fullscreen_button.toggled.connect(func(value):DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED));col.add_child(fullscreen_button)
 col.add_spacer(false);settings_close=_button("กลับ",20);settings_close.pressed.connect(close_settings);col.add_child(settings_close)
 var focus_controls: Array[Control]=[volume_slider,mute_button,fullscreen_button,settings_close]
 for i in focus_controls.size():
  var next: Control=focus_controls[(i+1)%focus_controls.size()];var previous: Control=focus_controls[(i-1+focus_controls.size())%focus_controls.size()]
  focus_controls[i].focus_next=next.get_path();focus_controls[i].focus_previous=previous.get_path();focus_controls[i].focus_neighbor_top=previous.get_path();focus_controls[i].focus_neighbor_bottom=next.get_path();focus_controls[i].focus_neighbor_left=previous.get_path();focus_controls[i].focus_neighbor_right=next.get_path()
 for toggle in [mute_button,fullscreen_button]:
  for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color","font_hover_pressed_color"]:toggle.add_theme_color_override(state,tint)
func open_settings() -> void:settings_shade.visible=true;settings.visible=true;volume_slider.grab_focus()
func close_settings() -> void:settings.visible=false;settings_shade.visible=false;settings_button.grab_focus()
func set_view(id: StringName) -> void:
 menu.visible=id==&"lighthouse";back_button.visible=id!=&"lighthouse";settings.visible=false;settings_shade.visible=false

func show_caption(value: String) -> void:
 caption_text.text=value;caption.visible=not value.is_empty()
func cinematic(active: bool) -> void:
 if active:menu.visible=false;back_button.visible=false
 footer.visible=not active
