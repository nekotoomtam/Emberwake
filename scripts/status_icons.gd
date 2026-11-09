extends CanvasLayer
## Per-enemy sight-aware icons; timers use a perimeter arc instead of seconds.
var game
var drawer: Node2D
var shown:=0
class Drawer extends Node2D:
 var owner_icons
 func _draw() -> void:owner_icons.paint(self)
func _ready() -> void:
 layer=8;drawer=Drawer.new();drawer.owner_icons=self;add_child(drawer)
func refresh() -> void:drawer.queue_redraw()
func paint(canvas: Node2D) -> void:
 shown=0
 if not is_instance_valid(game) or game.mode not in ["practice","combat"] or game.inventory_open or game.stats_open or game.body_lab_open:return
 var font:=ThemeDB.fallback_font
 for enemy in game.enemies:
  if not is_instance_valid(enemy) or enemy.dead:continue
  if enemy.mace_armor.stacks<=0 and enemy.armor_break_remaining<=0 and enemy.rifle_mark.stacks<=0 and enemy.crossbow_wound_ticks<=0:continue
  if not game.vision.can_see(enemy.position):continue
  var icons: Array=[]
  if enemy.mace_armor.stacks>0:icons.append(["shield",enemy.mace_armor.stacks,enemy.mace_armor.remaining/10.0])
  elif enemy.armor_break_remaining>0:icons.append(["shield",roundi(enemy.armor_break_fraction*10),enemy.armor_break_remaining/4.0])
  if enemy.rifle_mark.stacks>0:icons.append(["mark",enemy.rifle_mark.stacks,enemy.rifle_mark.remaining/10.0])
  if enemy.crossbow_wound_ticks>0:
   var wound_left: float=enemy.crossbow_wound_ticks-enemy.crossbow_wound_time
   icons.append(["wound",0,wound_left/game.CROSSBOW_WOUND_TICKS])
  var center: Vector2=game.camera.unproject_position(enemy.bar.global_position)+Vector2(0,-24)
  for i in range(icons.size()):
   var entry: Array=icons[i];var at: Vector2=(center+Vector2((i-(icons.size()-1)*.5)*36,-8)).round()
   var color: Color=(Color("#ffad6a") if int(entry[1])>=5 else Color("#ffd365")) if entry[0]=="shield" else (Color("#ff9eb5") if int(entry[1])>=3 else Color("#8fe9f2"))
   if entry[0]=="wound":color=Color("#ff8798")
   canvas.draw_circle(at,16,Color("#11212a"))
   canvas.draw_arc(at,15,-PI/2,-PI/2+TAU*clampf(entry[2],0,1),32,color,2.0,true)
   if entry[0]=="shield":
    var p:=PackedVector2Array([at+Vector2(-8,-8),at+Vector2(8,-8),at+Vector2(7,2),at+Vector2(0,9),at+Vector2(-7,2)])
    canvas.draw_colored_polygon(p,Color("#6c5838"));canvas.draw_polyline(p,color,1.6,true)
    canvas.draw_polyline(PackedVector2Array([at+Vector2(1,-8),at+Vector2(-3,-1),at+Vector2(2,1),at+Vector2(-1,8)]),Color.WHITE,2)
    if int(entry[1])>=5:canvas.draw_line(at+Vector2(-5,-3),at+Vector2(5,5),Color.WHITE,2)
   elif entry[0]=="wound":
    var drop:=PackedVector2Array([at+Vector2(0,-10),at+Vector2(6,-1),at+Vector2(7,3),
     at+Vector2(4,8),at+Vector2(-4,8),at+Vector2(-7,3),at+Vector2(-6,-1)])
    canvas.draw_colored_polygon(drop,Color("#d74d67"))
    canvas.draw_polyline(PackedVector2Array([at+Vector2(-3,1),at+Vector2(-4,3),at+Vector2(-2,5)]),Color("#ffd4dc"),1.5,true)
   else:
    canvas.draw_circle(at,9,color,false,1.5,true);canvas.draw_circle(at,4,color,false,1.5,true)
    canvas.draw_line(at+Vector2(-12,0),at+Vector2(12,0),color,1.5,true)
    canvas.draw_line(at+Vector2(0,-12),at+Vector2(0,12),color,1.5,true)
   if entry[0]!="wound":
    var pos:=at+Vector2(7,12)
    canvas.draw_string_outline(font,pos,str(entry[1]),HORIZONTAL_ALIGNMENT_LEFT,-1,16,4,Color.BLACK)
    canvas.draw_string(font,pos,str(entry[1]),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
   shown+=1
