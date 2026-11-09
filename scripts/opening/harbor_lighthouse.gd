extends Node3D
const Detail=preload("res://scripts/opening/harbor_detail.gd")
var geometry_count:=0
func _ready() -> void:
 name="HarborLighthouse";position=Vector3(42,0,-155)
 var b=Detail.new();add_child(b)
 var stone=Detail.material("b4b8ae","plaster",8020)
 var trim=Detail.material("c9c7b6","plaster",8021)
 var stripe=Detail.material("8a7770","plaster",8022)
 var iron=Detail.material("42575b","slate",8023)
 var copper=Detail.material("648281","slate",8024)
 var glass=Detail.material("a6b9ac","plaster",8025)
 var light_mat:=StandardMaterial3D.new();light_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;light_mat.albedo_color=Color("ffe5a6")
 var rock=Detail.material("65797b","slate",8026)
 var sea_stone=Detail.material("8c9790","plaster",8027)
 # A compact offshore foundation; no enclosure remains beside the town.
 b.boulder(Vector3(-.5,-.4,.5),Vector3(16,4.4,12),rock,8210)
 for i in 13:
  var a: float=i*TAU/13
  var at:=Vector3(cos(a)*5.5,-.15,sin(a)*4.0)
  b.boulder(at,Vector3(3.8,2.0,2.9),rock,8211+i)
 b.cylinder(Vector3(0,.16,0),4.0,.65,sea_stone,20)
 for i in 20:
  var a: float=i*TAU/20;var c: float=(i+1)*TAU/20
  b.beam(Vector3(cos(a)*3.7,.55,sin(a)*3.7),Vector3(cos(c)*3.7,.55,sin(c)*3.7),.36,sea_stone)
 b.cylinder(Vector3(0,.3,0),2.7,.6,iron,24)
 b.cylinder(Vector3(0,8.9,0),2.18,17.2,stone,32,1.62)
 for y in [4.5,10.8]:
  var r: float=2.18-(y-.3)/17.2*.56
  b.cylinder(Vector3(0,y,0),r+.025,1.1,stripe,32,r-.013)
 for y in [1.0,16.7,17.4]:b.cylinder(Vector3(0,y,0),2.22 if y<2 else 1.93,.20,trim,32)
 for y in [3.0,7.1,13.7]:
  var r: float=2.18-(y-.3)/17.2*.56
  b.box(Vector3(0,y,r+.02),Vector3(.78,1.23,.12),iron)
  b.box(Vector3(0,y,r+.10),Vector3(.53,.97,.08),glass)
  b.box(Vector3(0,y-.66,r+.13),Vector3(1.05,.16,.23),trim)
 b.box(Vector3(0,1.3,2.1),Vector3(1.2,2.0,.15),iron)
 b.cylinder(Vector3(0,17.8,0),2.75,.35,trim,32)
 for i in 20:
  var a: float=i*TAU/20;var c: float=(i+1)*TAU/20
  var p:=Vector3(cos(a)*2.58,18.5,sin(a)*2.58);var q:=Vector3(cos(c)*2.58,18.5,sin(c)*2.58)
  b.beam(p-Vector3.UP*.5,p+Vector3.UP*.45,.055,iron)
  for y in [-.15,.4]:b.beam(p+Vector3.UP*y,q+Vector3.UP*y,.055,iron)
 b.cylinder(Vector3(0,18.25,0),1.72,.35,iron,16)
 b.cylinder(Vector3(0,19.6,0),1.51,2.3,glass,12)
 for i in 12:
  var a: float=i*TAU/12
  b.beam(Vector3(cos(a)*1.54,18.4,sin(a)*1.54),Vector3(cos(a)*1.54,20.8,sin(a)*1.54),.075,iron)
 b.cylinder(Vector3(0,20.9,0),1.85,.22,iron,24)
 b.cylinder(Vector3(0,21.85,0),2.05,1.7,copper,24,.10)
 b.cylinder(Vector3(0,22.9,0),.10,.6,iron,12)
 b.cylinder(Vector3(0,19.6,1.56),.26,.95,light_mat,12)
 geometry_count=b.count;b.finish()
 var body:=StaticBody3D.new();body.collision_layer=1
 var col:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=2.25;shape.height=17.7;col.shape=shape;col.position.y=8.85;body.add_child(col);add_child(body)
