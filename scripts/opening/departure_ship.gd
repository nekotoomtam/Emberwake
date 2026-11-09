extends Node3D
const Gangway=preload("res://scripts/opening/harbor_gangway.gd")
const Detail=preload("res://scripts/opening/harbor_detail.gd")
const HullSurface=preload("res://scripts/opening/ship_hull_surface.gd")
var materials: Dictionary={}
var geometry_count:=0
var visual_root: Node3D
var hull_geometry: Dictionary={}
func _ready() -> void:
 var b=Detail.new();b.name="ClosedShipGeometry";visual_root=b;add_child(b)
 hull_geometry=HullSurface.build(b,materials)
 for side in [-1.0,1.0]:
  for section in 24:
   var t: float=(section+.5)/24;var x: float=-14.2+t*28.4;var width: float=4.4*pow(sin(t*PI),.45)
   if absf(x-Gangway.ENTRY_LOCAL_X)<Gangway.WIDTH*.5+.60:continue # Identical midship gates on both boarding sides.
   b.beam(Vector3(x,3.0,side*width),Vector3(x,3.6,side*width),.1,materials.darkwood)
   b.beam(Vector3(x-.6,3.6,side*width),Vector3(x+.6,3.6,side*width),.12,materials.gold)
 b.box(Vector3(-9.5,4.1,0),Vector3(5,2.5,5.1),materials.teal)
 b.box(Vector3(-9.5,5.5,0),Vector3(5.5,.22,5.5),materials.darkwood)
 for side in [-1.0,1.0]:
  for i in 4:
   b.box(Vector3(-11+i*1.05,4.4,side*2.61),Vector3(.72,.95,.1),materials.window)
   b.box(Vector3(-11+i*1.05,4.4,side*2.69),Vector3(.04,.98,.05),materials.gold)
   b.box(Vector3(-11+i*1.05,4.4,side*2.69),Vector3(.75,.04,.05),materials.gold)
 for mast in [[-3.5,13.0],[5.2,10.0]]:
  var x: float=mast[0];var height: float=mast[1]
  b.cylinder(Vector3(x,(height+2.8)*.5,0),.17,height-2.8,materials.darkwood)
  for y in [height*.63,height*.84]:
   var span:=Vector3(.83,0,.56)
   b.beam(Vector3(x,y,0)-span*3.7,Vector3(x,y,0)+span*3.7,.13,materials.wood)
   for strip in 8:
    var z: float=-3.5+strip*.88
    var at:=Vector3(x+.15,y-.1,0)+span*z
    b.quad(at,at+span*.89,at+span*.89+Vector3(.45,-2.3,0),at+Vector3(.45,-2.3,0),materials.canvas)
  for side in [-1.0,1.0]:b.beam(Vector3(x,height,0),Vector3(x-4,3.5,side*3.6),.025,materials.rope)
 b.beam(Vector3(11,3.1,0),Vector3(18,4.6,0),.22,materials.darkwood)
 for side in [-1.0,1.0]:
  for x in [-10.0,-5.0,0.0,5.0,10.0]:b.cylinder(Vector3(x,1.8,side*3.8),.23,.4,materials.gold,10)
 # Identical fixed tackle belongs to the ship model, not to each scene.
 for i in 4:b.cylinder(Vector3(-5.3,2.89+i*.025,2.95),.29-i*.045,.025,materials.rope,20)
 b.cylinder(Vector3(9.6,3.195,.1),.27,.66,materials.wood)
 for y in [.10,.54]:b.cylinder(Vector3(9.6,2.865+y,.1),.28,.045,materials.iron)
 geometry_count=b.count;b.finish()
