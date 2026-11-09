extends Node3D
const Detail=preload("res://scripts/coast_form_detail.gd")
var materials: Dictionary={}
var length_:=29.0
var mast_height:=14.0
var geometry_count:=0
var batch_count:=0
var crushed_planks:=0
var crushed_deck_tiles:=0
var fallen_mast_starts: Array[Vector3]=[]
var fallen_mast_tips: Array[Vector3]=[]
func _ready() -> void:
 var b=Detail.new();add_child(b)
 # Broadside clinker planks and exposed heavy frames; bow is smashed open.
 for side in [-1.0,1.0]:
  for section in 20:
   var t: float=(section+.5)/20;var x: float=-14.2+t*28.4
   var width: float=4.6*pow(sin(t*PI),.45)
   for row in 12:
    if side>0 and section in [8,9,10,11] and row in [3,4,5,6,7,8,9]:continue
    if side>0 and section>=15 and row>=2:crushed_planks+=1;continue
    if section>17 and row>4 and (row+section)%3==0:continue
    var z: float=side*width*(.45+row*.047);var y: float=-.65+row*.43+pow(absf(x)/14.2,3)*.65
    b.box(Vector3(x,y,z),Vector3(1.37,.34,.16),materials.wood if row%3 else materials.oldwood,Vector3(0,0,.025*sin(section)))
   if side>0 and section>=15:
    b.beam(Vector3(x,-.5,0),Vector3(x,.8,width*.65),.23,materials.oldwood)
    b.beam(Vector3(x,.8,width*.65),Vector3(x+.7,1.8,width*.9),.18,materials.wood)
    continue
   if section%2==0:
    b.beam(Vector3(x,-.5,0),Vector3(x,.25,side*width*.6),.20,materials.iron)
    b.beam(Vector3(x,.25,side*width*.6),Vector3(x,4.3,side*width),.24,materials.oldwood)
   if section not in [8,9,10]:b.beam(Vector3(x-.6,4.3,side*width),Vector3(x+.6,4.3,side*width),.19,materials.wood)
 for x in range(-12,13):
  var width: float=4.2*pow(sin((x+14.2)/28.4*PI),.45)
  for row in 13:
   var z: float=(row-6)*.55
   if absf(z)>width or (absf(x)<3 and absf(z)<2):continue
   if x>=8 and z>-.3:crushed_deck_tiles+=1;continue
   if (x*3+row)%19==0:continue
   b.box(Vector3(x,3.55,z),Vector3(.94,.10,.51),materials.oldwood)
 b.beam(Vector3(-14.2,-.8,0),Vector3(14.2,-.35,0),.45,materials.wood)
 # Port rim survives; starboard bow is torn back around the impact rock.
 for i in 7:
  var x: float=9.4+i*.57;var z: float=-1.4+i*.1
  b.beam(Vector3(x,2.5,z),Vector3(x+1.0,3.3+sin(i)*.5,z-.2),.14,materials.oldwood)
 for i in 15:
  var x: float=8.3+(i%5)*1.02;var z: float=.1+(i/5)*.68
  b.beam(Vector3(x,1.0+sin(i)*.6,z),Vector3(x+.4+sin(i*2)*.7,1.4+cos(i)*.65,z+1.4),.16,materials.oldwood)
 b.beam(Vector3(10.5,3.7,-.3),Vector3(17.3,.7,-.2),.28,materials.wood)
 # Stern cabin with broken sash panes and a collapsed upper rail.
 for side in [-1.0,1.0]:
  for row in 13:
   for col in 5:
    var x: float=-12+col*.9;var y: float=3.7+row*.24
    if row in [5,6,7,8] and col in [1,3]:continue
    b.box(Vector3(x,y,side*2.7),Vector3(.86,.22,.13),materials.wood if row%4 else materials.oldwood)
  for x in [-11.1,-9.3]:
   for y in [4.85,5.95]:b.box(Vector3(x,y,side*2.78),Vector3(.8,.07,.09),materials.iron)
   b.box(Vector3(x,5.4,side*2.78),Vector3(.06,1.05,.1),materials.iron)
 b.box(Vector3(-10,6.8,0),Vector3(5.5,.18,6),materials.wood,Vector3(.08,0,.05))
 for i in 8:b.beam(Vector3(-12+i*.6,6.9,-2.9),Vector3(-12+i*.6,7.45,-2.9),.07,materials.iron)
 # Both mast tops have fallen to screen-left; the foremast lands on the beach.
 _fallen_mast(b,Vector3(-3.5,3.8,0),Vector3(-9.0,-2.5,-4.0),.25)
 var forward_base:=Vector3(6.8,4.6,0)
 var ground_tip:=to_global(forward_base)+Vector3(-8,0,-4.4);ground_tip.y=.38
 _fallen_mast(b,forward_base,ground_tip-to_global(forward_base),.29)
 # Ropes sag along the hull and drift to the water.
 for side in [-1.0,1.0]:
  b.tube([Vector3(-5,2.8,side*4.3),Vector3(0,1.9,side*4.8),Vector3(7,2.6,side*3.9)],.04,materials.rope,.8)
 b.beam(Vector3(-1,3.6,-3),Vector3(11,4.9,4),.22,materials.oldwood)
 geometry_count=b.count;batch_count=b.finish()
 var body:=StaticBody3D.new();body.name="InaccessibleWreckHull";body.collision_layer=1;var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(26,4.2,7.6);col.shape=shape;col.position.y=1.0;body.add_child(col);add_child(body)
func _fallen_mast(b,at: Vector3,offset_world: Vector3,radius: float) -> void:
 var end: Vector3=to_local(to_global(at)+offset_world)
 fallen_mast_starts.append(to_global(at));fallen_mast_tips.append(to_global(end))
 var stump: Array[Vector3]=[Vector3(at.x,3.25,0),at]
 b.tube(stump,radius*1.2,materials.wood,.65)
 for i in 5:
  var angle: float=TAU*i/5
  b.beam(at+Vector3(cos(angle)*radius,-.1,sin(angle)*radius),at+Vector3(cos(angle)*radius,.35+sin(i)*.15,sin(angle)*radius),.07,materials.oldwood)
 var pole: Array[Vector3]=[at,end]
 b.tube(pole,radius,materials.oldwood,.62);_fallen_collision(at,end,radius)
 var right: Vector3=(end-at).cross(Vector3.UP).normalized()
 for t in [.38,.69]:
  var center: Vector3=at.lerp(end,t)
  b.beam(center-right*2.6,center+right*2.6,.12,materials.wood)
  _fallen_collision(center-right*2.6,center+right*2.6,.12)
 for row in 5:
  for col in 8:
   if (row*3+col)%9==0 or (row==4 and col%3==0):continue
   var a: Vector3=at.lerp(end,.36+row*.065)+right*(col-4)*.6
   var q: Vector3=a+right*.59;var c: Vector3=q+(end-at)*.063;var d: Vector3=a+(end-at)*.063
   b._triangle(a,q,c,Vector3.UP,materials.canvas);b._triangle(a,c,d,Vector3.UP,materials.canvas)
 for sign_ in [-1.0,1.0]:
  var rope: Array[Vector3]=[at+right*sign_*2,at.lerp(end,.55)+right*sign_*2.3+Vector3.DOWN*.6,end+right*sign_*.8]
  b.tube(rope,.025,materials.rope,.6)
func _fallen_collision(a: Vector3,b: Vector3,radius: float) -> void:
 var body:=StaticBody3D.new();body.name="FallenMastBlocker";body.collision_layer=1;body.position=(a+b)*.5
 body.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
 var col:=CollisionShape3D.new();var shape:=CapsuleShape3D.new();shape.radius=radius;shape.height=a.distance_to(b)+radius*2;col.shape=shape;body.add_child(col);add_child(body)
func landmark_points() -> Array[Vector3]:
 return [to_global(Vector3(-14,2,0)),to_global(Vector3(17.3,.7,-.2)),fallen_mast_tips[0],to_global(Vector3(0,.2,4.5))]
