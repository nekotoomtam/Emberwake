extends HBoxContainer
## Read-only presentation of actual player effects. Enemy status icons stay in world space.
var cards: Dictionary={}
var shown_effects: Array[String]=[]
class EffectIcon extends Control:
 var kind: String="tempo"
 var tint:=Color("#edc182")
 var stacks:=0
 var fraction: float=-1
 func _draw() -> void:
  var c:=Vector2(17,17)
  draw_style_box(_box(Color("#13232b"),tint),Rect2(1,1,32,32))
  if kind=="tempo":
   for x in [10,17]:draw_polyline(PackedVector2Array([Vector2(x,9),Vector2(x+7,17),Vector2(x,25)]),tint,3,false)
  elif kind=="counter":
   draw_line(Vector2(10,25),Vector2(25,8),tint,4)
   draw_line(Vector2(8,18),Vector2(17,26),tint,2)
  else:
   var p:=PackedVector2Array([Vector2(8,7),Vector2(26,7),Vector2(24,23),Vector2(17,29),Vector2(10,23),Vector2(8,7)])
   draw_polyline(p,tint,2,false)
   draw_polyline(PackedVector2Array([Vector2(18,7),Vector2(14,15),Vector2(20,18),Vector2(16,27)]),Color.WHITE,2,false)
  if fraction>=0:draw_arc(c,17,-PI/2,-PI/2+TAU*clampf(fraction,0,1),32,tint,2,false)
  if stacks>0:
   draw_rect(Rect2(22,23,14,14),Color("#101923"));draw_string(ThemeDB.fallback_font,Vector2(25,35),str(stacks),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
 func _box(bg: Color,border: Color) -> StyleBoxFlat:
  var s:=StyleBoxFlat.new();s.bg_color=bg;s.border_color=border;s.set_border_width_all(1);return s
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE;add_theme_constant_override("separation",6)
 for entry in [["tempo","ยิงเร็ว",Color("#8fe9da")],["counter","สวนกลับ",Color("#ffd365")],["break","เสียการ์ด",Color("#ff8c88")]]:
  var card:=PanelContainer.new();card.custom_minimum_size=Vector2(92,76);card.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var style:=StyleBoxFlat.new();style.bg_color=Color("#182733");style.set_content_margin_all(4);card.add_theme_stylebox_override("panel",style);add_child(card)
  var col:=VBoxContainer.new();col.add_theme_constant_override("separation",1);card.add_child(col)
  var icon:=EffectIcon.new();icon.kind=entry[0];icon.tint=entry[2];icon.custom_minimum_size=Vector2(36,38);icon.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;col.add_child(icon)
  var title:=Label.new();title.text=entry[1];title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",12);title.mouse_filter=Control.MOUSE_FILTER_IGNORE;col.add_child(title)
  var value:=Label.new();value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;value.add_theme_font_size_override("font_size",11);value.add_theme_color_override("font_color",entry[2]);value.mouse_filter=Control.MOUSE_FILTER_IGNORE;col.add_child(value)
  cards[entry[0]]={"card":card,"icon":icon,"value":value};card.visible=false
func refresh(game) -> void:
 shown_effects.clear()
 _show("tempo",game.primary_family()=="pistol" and game.pistol_aim_state.stacks>0,"+%d%% โจมตี"%roundi(game.pistol_aim_state.speed_bonus()*100),game.pistol_aim_state.stacks,-1)
 _show("counter",game.rewards.counter_left>0,"ท่า 3 • %.1f วิ"%game.rewards.counter_left,0,game.rewards.counter_left/game.rewards.COUNTER_WINDOW)
 _show("break",game.readiness.broken_left>0,"%.1f วิ"%game.readiness.broken_left,0,game.readiness.broken_left/game.readiness.BREAK_TIME)
func _show(id: String,on: bool,text: String,stacks: int,fraction: float) -> void:
 var view: Dictionary=cards[id];view.card.visible=on
 if not on:return
 shown_effects.append(id);view.value.text=text;view.icon.stacks=stacks;view.icon.fraction=fraction;view.icon.queue_redraw()
