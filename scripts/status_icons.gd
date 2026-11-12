extends CanvasLayer
## Per-enemy sight-aware icons; timers use a perimeter arc instead of seconds.
const CoastalEnemy = preload("res://scripts/coastal_enemy.gd")
const Captain = preload("res://scripts/captain.gd")
const RifleMark = preload("res://scripts/rifle_mark.gd")
var game
var drawer: Node2D
var shown:=0
class Drawer extends Node2D:
 var owner_icons
 func _draw() -> void:owner_icons.paint(self)
func _ready() -> void:
 layer=8;drawer=Drawer.new();drawer.owner_icons=self;add_child(drawer)
func refresh() -> void:drawer.queue_redraw()
func icons_for(enemy) -> Array:
 var icons: Array=[]
 if enemy.mace_armor.stacks>0:icons.append(["shield",str(enemy.mace_armor.stacks),enemy.mace_armor.remaining/10.0])
 if enemy.armor_break_remaining>0:icons.append(["shield","%d%%"%roundi(enemy.armor_break_fraction*100),enemy.armor_break_remaining/enemy._armor_break_duration])
 if enemy.rifle_mark.stacks>0:icons.append(["mark","",enemy.rifle_mark.remaining/RifleMark.DURATION])
 if enemy.crossbow_wound_ticks>0:
  var wound_left: float=enemy.crossbow_wound_ticks-enemy.crossbow_wound_time
  icons.append(["wound","",wound_left/game.CROSSBOW_WOUND_TICKS])
 if enemy.ice_slow_remaining > 0.0 and enemy.ice_slow_fraction() >= enemy.movement_slow:
  icons.append(["slow","%d%%"%roundi(enemy.ice_slow_fraction()*100),enemy.ice_slow_remaining/enemy.ICE_SLOW_DURATION])
 elif enemy.movement_slow_remaining>0:
  icons.append(["slow","%d%%"%roundi(enemy.movement_slow*100),enemy.movement_slow_remaining/enemy.movement_slow_duration])
 if enemy.ice_root_remaining > 0.0:
  icons.append(["root","",enemy.ice_root_remaining/enemy.ICE_ROOT_DURATION])
 if enemy is CoastalEnemy and game.encounter_mode=="dungeon" and is_instance_valid(game.arena.hazards):
  var terrain_speed: float=game.arena.hazards.speed_scale(enemy.global_position)
  if terrain_speed<1.0:icons.append(["terrain","%d%%"%roundi((1.0-terrain_speed)*100),-1.0])
 if enemy.stagger>0:icons.append(["stagger","",-1.0])
 if enemy is Captain and enemy.arm_cut:icons.append(["injury","",-1.0])
 return icons

func paint(canvas: Node2D) -> void:
 shown=0
 if not is_instance_valid(game) or game.mode not in ["practice","combat"] or game.inventory_open or game.stats_open or game.body_lab_open or game.sword_skills_open or game.dungeon_peek.visible:return
 var font:=ThemeDB.fallback_font
 for enemy in game.enemies:
  if not is_instance_valid(enemy) or enemy.dead:continue
  var icons := icons_for(enemy)
  if icons.is_empty():continue
  if not game.vision.can_see(enemy.position):continue
  var center: Vector2=game.camera.unproject_position(enemy.bar.global_position)+Vector2(0,-24)
  for i in range(icons.size()):
   var entry: Array=icons[i];var at: Vector2=(center+Vector2((i-(icons.size()-1)*.5)*36,-8)).round()
   var color: Color=(Color("#ffad6a") if entry[1]=="5" else Color("#ffd365")) if entry[0]=="shield" else (Color("#ff9eb5") if entry[1]=="3" else Color("#8fe9f2"))
   if entry[0]=="wound":color=Color("#ff8798")
   if entry[0]=="mark":color=Color("#e7acff")
   if entry[0]=="slow":color=Color("#83d7ff")
   if entry[0]=="root":color=Color("#a6efff")
   if entry[0]=="terrain":color=Color("#96c7ab")
   if entry[0]=="stagger":color=Color("#ebc37c")
   if entry[0]=="injury":color=Color("#ff9f94")
   canvas.draw_circle(at,16,Color("#11212a"))
   if entry[2]>=0.0:canvas.draw_arc(at,15,-PI/2,-PI/2+TAU*clampf(entry[2],0,1),32,color,2.0,true)
   if entry[0]=="shield":
    var p:=PackedVector2Array([at+Vector2(-8,-8),at+Vector2(8,-8),at+Vector2(7,2),at+Vector2(0,9),at+Vector2(-7,2)])
    canvas.draw_colored_polygon(p,Color("#6c5838"));canvas.draw_polyline(p,color,1.6,true)
    canvas.draw_polyline(PackedVector2Array([at+Vector2(1,-8),at+Vector2(-3,-1),at+Vector2(2,1),at+Vector2(-1,8)]),Color.WHITE,2)
    if entry[1]=="5":canvas.draw_line(at+Vector2(-5,-3),at+Vector2(5,5),Color.WHITE,2)
   elif entry[0]=="wound":
    var drop:=PackedVector2Array([at+Vector2(0,-10),at+Vector2(6,-1),at+Vector2(7,3),
     at+Vector2(4,8),at+Vector2(-4,8),at+Vector2(-7,3),at+Vector2(-6,-1)])
    canvas.draw_colored_polygon(drop,Color("#d74d67"))
    canvas.draw_polyline(PackedVector2Array([at+Vector2(-3,1),at+Vector2(-4,3),at+Vector2(-2,5)]),Color("#ffd4dc"),1.5,true)
   elif entry[0] in ["slow","terrain"]:
    for y in [-7.0,0.0]:
     canvas.draw_polyline(PackedVector2Array([at+Vector2(-6,y),at+Vector2(0,y+5),at+Vector2(6,y)]),color,2.2,true)
   elif entry[0]=="root":
    for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2(.7,.7),Vector2(.7,-.7)]:
     canvas.draw_line(at-direction*9,at+direction*9,color,1.8,true)
   elif entry[0]=="stagger":
    var star := PackedVector2Array()
    for point in range(10):
     var angle := -PI / 2.0 + point * TAU / 10.0
     star.append(at + Vector2.from_angle(angle) * (10.0 if point % 2 == 0 else 4.0))
    canvas.draw_colored_polygon(star,color)
   elif entry[0]=="injury":
    canvas.draw_line(at+Vector2(-8,-7),at+Vector2(-2,-1),color,4,true)
    canvas.draw_line(at+Vector2(2,3),at+Vector2(7,8),color,4,true)
    canvas.draw_line(at+Vector2(4,-6),at+Vector2(-5,4),color,1.8,true)
   else:
    canvas.draw_circle(at,9,color,false,1.5,true);canvas.draw_circle(at,4,color,false,1.5,true)
    canvas.draw_line(at+Vector2(-12,0),at+Vector2(12,0),color,1.5,true)
    canvas.draw_line(at+Vector2(0,-12),at+Vector2(0,12),color,1.5,true)
   if not entry[1].is_empty():
    var badge: String=entry[1]
    var pos:=at+Vector2(-font.get_string_size(badge,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x*.5,15)
    canvas.draw_string_outline(font,pos,badge,HORIZONTAL_ALIGNMENT_LEFT,-1,13,4,Color.BLACK)
    canvas.draw_string(font,pos,badge,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
   shown+=1
