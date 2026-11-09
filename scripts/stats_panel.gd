extends CanvasLayer
var game
var surface: Control
var left: Label
var right: Label
func _ready() -> void:
 layer=30
 surface=Control.new();surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(surface)
 var shade:=ColorRect.new();shade.color=Color(.015,.025,.04,.9);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);surface.add_child(shade)
 var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);surface.add_child(center)
 var panel:=PanelContainer.new();panel.custom_minimum_size=Vector2(960,550);panel.add_theme_stylebox_override("panel",game.ui.panel());center.add_child(panel)
 var theme:=Theme.new();var font:=SystemFont.new();font.font_names=PackedStringArray(["Tahoma","Noto Sans Thai"]);theme.default_font=font;panel.theme=theme
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",16);panel.add_child(column)
 column.add_child(game.ui.label("สถานะตัวละคร • ค่าพื้นฐาน → ค่าที่ใช้จริง",25,game.ui.GOLD))
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",45);column.add_child(row)
 left=game.ui.label("",18);left.custom_minimum_size.x=430;row.add_child(left)
 right=game.ui.label("",18);row.add_child(right)
 column.add_child(game.ui.label("ค่าสแตมิน่า: ดาบ 8/8/12 • ดาบใหญ่ 14/14/20 • กระบอง 12/8/18",18))
 column.add_child(game.ui.label("คทา 14 • ปืนพก 3 / เล็ง 3.9 • ปืนยาว 10 / เล็ง 15 • แดช 30",18))
 column.add_child(game.ui.label("ฟื้นพลัง: ปกติ 100% • เล็ง/กัน/รีโหลด 50% • โจมตี/แดช 0%",17,game.ui.DIM))
 var close:=Button.new();close.text="กลับไปเล่น [P / ESC]";close.custom_minimum_size.y=42;close.pressed.connect(game.toggle_stats);column.add_child(close)
 surface.visible=false
func entry(title: String,key: String,mult: float=1,suffix: String="") -> String:
 return "%s   %s%s → %s%s\n"%[title,str(float(game.stats.base[key])*mult),suffix,str((game.max_health() if key=="max_health" else game.stats.value(key))*mult),suffix]
func refresh() -> void:
 left.text=entry("ชีวิตสูงสุด","max_health")+entry("ฟื้นชีวิต / วิ","health_regen")+entry("สแตมิน่าสูงสุด","max_stamina")+entry("ฟื้นสแตมิน่า / วิ","stamina_regen")+entry("รอฟื้นพลัง","stamina_delay",1," วิ")+entry("เกราะกายภาพ","armor")+entry("โอกาสคริติคอล","critical_chance",100,"%")+entry("ความแรงคริติคอล","critical_multiplier",100,"%")
 right.text=entry("ต้านทานไฟ","resist_fire",100,"%")+entry("ต้านทานน้ำแข็ง","resist_ice",100,"%")+entry("ต้านทานสายฟ้า","resist_lightning",100,"%")+entry("ความเร็วโจมตี","attack_speed",100,"%")+entry("ความเร็วเคลื่อนที่","move_speed",100,"%")+entry("ความเร็วรีโหลด","reload_speed",100,"%")+entry("ระยะสายตา","sight_range")+entry("ระยะรับรู้","sense_radius")+"\nกันด้านหน้า: ลดดาเมจ 30% / ฟรี\nต้านทานธาตุสูงสุด 75%"
