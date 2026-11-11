extends GridContainer
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
  elif kind=="wind":
   draw_polyline(PackedVector2Array([Vector2(6,13),Vector2(21,13),Vector2(25,10),Vector2(23,7)]),tint,2,true)
   draw_polyline(PackedVector2Array([Vector2(8,19),Vector2(27,19),Vector2(27,22),Vector2(23,24)]),tint,2,true)
   draw_line(Vector2(10,25),Vector2(18,25),tint,2,true)
  elif kind=="heal":
   draw_line(Vector2(17,8),Vector2(17,26),tint,4)
   draw_line(Vector2(8,17),Vector2(26,17),tint,4)
  elif kind=="ember":
   draw_colored_polygon(PackedVector2Array([Vector2(17,5),Vector2(22,14),Vector2(24,11),Vector2(27,21),Vector2(22,27),Vector2(12,27),Vector2(7,21),Vector2(12,12),Vector2(13,18)]),tint)
   draw_circle(Vector2(17,22),3,Color("#fff0bb"))
  elif kind in ["revelation","focus"]:
   draw_polyline(PackedVector2Array([Vector2(6,17),Vector2(12,11),Vector2(22,11),Vector2(28,17),Vector2(22,23),Vector2(12,23),Vector2(6,17)]),tint,2,true)
   draw_circle(c,3,tint)
  elif kind=="frenzy":
   draw_colored_polygon(PackedVector2Array([Vector2(19,5),Vector2(9,19),Vector2(16,19),Vector2(14,29),Vector2(26,14),Vector2(19,14)]),tint)
  elif kind=="terrain":
   for y in [12.0,19.0]:draw_polyline(PackedVector2Array([Vector2(8,y),Vector2(17,y+5),Vector2(26,y)]),tint,2.5,true)
  elif kind=="protected":
   draw_circle(c,10,tint,false,2.0,true)
   draw_circle(c,4,tint)
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
 columns=3
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_theme_constant_override("h_separation",6)
 add_theme_constant_override("v_separation",6)
 var effects := [
  ["tempo","ยิงเร็ว",Color("#8fe9da")],
  ["counter","สวนกลับ",Color("#ffd365")],
  ["break","เสียการ์ด",Color("#ff8c88")],
  ["wind","ดาบเคลือบลม",Color("#84dafa")],
  ["ember","งัดเพลิง",Color("#ffae69")],
  ["heal","ฟื้นเลือด",Color("#8ee6a9")],
  ["revelation","ญาณเปิด",Color("#bbabff")],
  ["frenzy","คลุ้มคลั่ง",Color("#ff9aae")],
  ["focus","เล็งปืนยาว",Color("#b7e6ef")],
  ["terrain","เดินช้าจากพื้น",Color("#88c9e8")],
  ["protected","กันความเสียหาย",Color("#dce6a9")],
 ]
 for entry in effects:
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
 var wind_left: float=game.sword_wave_buff_left
 var wind_text := "+10%% โจมตี • %.1f วิ"%wind_left if game._storm_blade_has_current_sword() else "ที่ดาบเดิม • %.1f วิ"%wind_left
 _show("wind",wind_left>0,wind_text,0,wind_left/game.SwordSkillMotion.STORM_BLADE_DURATION)
 var ember_left: float=game.mace_fire_buff_left
 _show("ember",ember_left>0.0,"%.1f วิ"%ember_left,0,ember_left/game.MaceSkillMotion.FIRE_BUFF_DURATION)
 var flask_left: float=0.0 if game.flasks.effects.is_empty() else game.flasks.effects.max()
 _show("heal",flask_left>0,"+%.0f HP/วิ"%game.flasks.rate(),game.flasks.effects.size(),flask_left/game.flasks.EFFECT_SECONDS)
 _show("revelation",game.has_sanity_revelation(),"เห็นสิ่งที่ซ่อน",0,-1)
 _show("frenzy",game.frenzy,"ฟื้น HP ถูกระงับ",0,-1)
 var focus: float=game.rifle_focus_state.amount()
 _show("focus",game.primary_family()=="rifle" and focus>0,"ระยะมอง +%d%%"%roundi((game.rifle_focus_state.sight_multiplier()-1.0)*100),0,focus)
 var terrain_speed := 1.0
 if game.encounter_mode=="dungeon" and is_instance_valid(game.arena.hazards):
  terrain_speed=game.arena.hazards.speed_scale(game.player.global_position)
 _show("terrain",terrain_speed<1.0,"เดิน -%d%%"%roundi((1.0-terrain_speed)*100),0,-1)
 var dodge_left: float=maxf(0.0,game.rewards.DODGE_IFRAMES-game.rewards.dodge_age)
 var protection: float=maxf(game._iframes,dodge_left)
 var protection_fraction: float=maxf(game._iframes/.5,dodge_left/game.rewards.DODGE_IFRAMES)
 _show("protected",protection>0.0,"%.1f วิ"%protection,0,protection_fraction)
func _show(id: String,on: bool,text: String,stacks: int,fraction: float) -> void:
 var view: Dictionary=cards[id];view.card.visible=on
 if not on:return
 shown_effects.append(id);view.value.text=text;view.icon.stacks=stacks;view.icon.fraction=fraction;view.icon.queue_redraw()
