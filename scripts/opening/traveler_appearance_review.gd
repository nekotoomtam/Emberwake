extends Node3D
## Appearance-only comparison. The accepted prologue and playable character
## remain untouched; both specimens use the same real Sprite3D pixel size.
const Art=preload("res://scripts/pixel_art.gd")
const Traveler=preload("res://scripts/opening/traveler_appearance_art.gd")
const LegacyDirections=preload("res://scripts/hero_directions.gd")
const Appearance=preload("res://scripts/opening/harbor_hero_appearance.gd")
const DIRECTIONS: Array[String]=["right","front","left","back"]
const DIRECTION_NAMES: Dictionary={"right":"3/4 ขวา","front":"หน้าตรง","left":"3/4 ซ้าย","back":"ด้านหลัง"}
const CENTER:=Vector3(-43,.055,5)
var world
var camera: Camera3D
var old_actor: Sprite3D
var new_actor: Sprite3D
var old_foot:=CENTER+Vector3(-1.8,0,0)
var new_foot:=CENTER+Vector3(1.8,0,0)
var close_view:=false
var direction: String="right"
var direction_label: Label
var direction_buttons: Dictionary={}
var ui: CanvasLayer
var normal_button: Button
var close_button: Button
func _ready() -> void:
 DisplayServer.window_set_title("Emberwake - Identical Midship Boarding v115")
 world=preload("res://scenes/opening/harbor_world.tscn").instantiate();add_child(world)
 camera=Camera3D.new();camera.near=.1;camera.far=5000;camera.current=true;add_child(camera)
 old_actor=_specimen("PreviousAppearance",Art.frames("player").get_frame_texture("idle",0))
 new_actor=_specimen("TravelerStudy",Traveler.texture())
 _ui();set_close(false);set_direction("front");tick(0)
func set_direction(value: String) -> void:
 if value not in DIRECTIONS:return
 direction=value;old_actor.texture=LegacyDirections.frames(direction).get_frame_texture("idle",0);new_actor.texture=Traveler.texture(direction)
 if direction_label!=null:direction_label.text="ทิศ: "+DIRECTION_NAMES[direction]+"   ·   ← → เปลี่ยนทิศ"
 for id in direction_buttons:direction_buttons[id].disabled=id==direction
 tick(0)
func launch_profile(id: String) -> void:
 Appearance.select(id);get_tree().change_scene_to_file("res://scenes/prologue.tscn")
func _specimen(label: String,texture: Texture2D) -> Sprite3D:
 var actor:=Sprite3D.new();actor.name=label;actor.texture=texture;actor.pixel_size=.018
 actor.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;actor.shaded=false;actor.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
 add_child(actor);return actor
func set_close(value: bool) -> void:
 close_view=value
 if value:
  camera.position=CENTER+Vector3(0,4.3,7.4);camera.look_at(CENTER+Vector3.UP*1.0);camera.fov=40
 else:
  # Exactly the settled playable follow-camera offset and lens.
  camera.position=CENTER+Vector3(2.9,7.8,10.2);camera.look_at(CENTER+Vector3(2.9,1.7,-3.2));camera.fov=48
 if is_instance_valid(normal_button):normal_button.disabled=not value;close_button.disabled=value
 tick(0)
func tick(delta: float) -> void:
 world.tick(delta,camera)
 for pair in [[old_actor,old_foot],[new_actor,new_foot]]:
  pair[0].global_basis=camera.global_basis
  pair[0].global_position=pair[1]+Vector3.UP*.045+camera.global_basis.y*.864
func _process(delta: float) -> void:tick(delta)
func _font() -> SystemFont:
 var font:=SystemFont.new();font.font_names=PackedStringArray(["Tahoma","Noto Sans Thai"]);return font
func _label(value: String,size_: int) -> Label:
 var label:=Label.new();label.text=value;label.add_theme_font_override("font",_font());label.add_theme_font_size_override("font_size",size_)
 label.add_theme_color_override("font_color",Color("314445"));return label
func _button(value: String,callback: Callable) -> Button:
 var button:=Button.new();button.text=value;button.custom_minimum_size=Vector2(185,42)
 button.add_theme_font_override("font",_font());button.add_theme_font_size_override("font_size",20);button.pressed.connect(callback);return button
func _ui() -> void:
 ui=CanvasLayer.new();add_child(ui)
 var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);ui.add_child(root)
 var title:=PanelContainer.new();title.position=Vector2(24,20);root.add_child(title)
 var style:=StyleBoxFlat.new();style.bg_color=Color(.95,.92,.84,.96);style.content_margin_left=20;style.content_margin_right=20;style.content_margin_top=12;style.content_margin_bottom=12;title.add_theme_stylebox_override("panel",style)
 var title_column:=VBoxContainer.new();title.add_child(title_column)
 title_column.add_child(_label("ตัวละครใหม่ · ครบ 4 ทิศ",25))
 title_column.add_child(_label("ซ้าย: ตัวเดิม     |     ขวา: นักเดินทางสาว",19))
 direction_label=_label("ทิศ: 3/4 ขวา   ·   ← → เปลี่ยนทิศ",18);title_column.add_child(direction_label)
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",6);title_column.add_child(row)
 for id in DIRECTIONS:
  var button:=_button(DIRECTION_NAMES[id],func():set_direction(id));button.custom_minimum_size=Vector2(115,36);direction_buttons[id]=button;row.add_child(button)
 direction_buttons.right.disabled=true
 var bottom:=HBoxContainer.new();bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);bottom.position=Vector2(-488,-64);bottom.add_theme_constant_override("separation",12);root.add_child(bottom)
 normal_button=_button("ขนาดเล่นจริง",func():set_close(false));bottom.add_child(normal_button)
 close_button=_button("ดูใกล้",func():set_close(true));bottom.add_child(close_button)
 bottom.add_child(_button("ใช้ตัวใหม่ในท่าเรือ",func():launch_profile("traveler")))
 bottom.add_child(_button("ใช้ตัวเดิมในท่าเรือ",func():launch_profile("legacy")))
 bottom.add_child(_button("ออก",func():get_tree().quit()))
func _unhandled_key_input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo:return
 if event.physical_keycode==KEY_1:set_close(false)
 if event.physical_keycode==KEY_2:set_close(true)
 if event.physical_keycode==KEY_LEFT:set_direction(DIRECTIONS[posmod(DIRECTIONS.find(direction)-1,4)])
 if event.physical_keycode==KEY_RIGHT:set_direction(DIRECTIONS[posmod(DIRECTIONS.find(direction)+1,4)])
 if event.physical_keycode==KEY_ESCAPE:launch_profile("traveler")
