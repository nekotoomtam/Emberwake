extends RefCounted
## Shared plank deck, timber stringers and rope rails for both large vessels.
const Detail=preload("res://scripts/opening/harbor_detail.gd")
const ENTRY_LOCAL_X:=0.0
const WIDTH:=2.3
static var shared_materials: Dictionary={}
const DEPARTURE_SHORE:=Vector3(7.0,.43,.6)
const DEPARTURE_DECK:=Vector3(7.0,2.315,-3.2)
const DEPARTURE_LANDING:=Vector3(7.0,2.315,-4.2)
const ARRIVAL_SHORE:=Vector3(12.0,.43,-29.8)
const ARRIVAL_DECK:=Vector3(12.0,2.315,-33.6)
static func build(builder,a: Vector3,b: Vector3) -> void:
 if shared_materials.is_empty():
  shared_materials={"wood":Detail.material("956d51","wood",7700),"darkwood":Detail.material("5d483d","wood",7701),"rope":Detail.material("bbaa7d","wood",7711)}
 var materials:=shared_materials
 var half: float=WIDTH*.5
 var dark: Material=materials.get("darkwood",materials.get("dark"))
 var planks:=maxi(14,ceili(a.distance_to(b)/.22))
 for j in planks:
  var start: Vector3=a.lerp(b,float(j)/planks);var end: Vector3=a.lerp(b,float(j+1)/planks)
  builder.quad(start+Vector3(-half,0,0),start+Vector3(half,0,0),end+Vector3(half,0,0),end+Vector3(-half,0,0),materials.wood)
  if j%3==0:builder.beam(start+Vector3(-half,.006,0),start+Vector3(half,.006,0),.013,dark)
 for side in [-1.0,1.0]:
  builder.beam(a+Vector3(side*half,-.10,0),b+Vector3(side*half,-.10,0),.16,dark)
  for height in [.48,.85]:builder.beam(a+Vector3(side*half,height,0),b+Vector3(side*half,height,0),.045,materials.rope)
  for t in [0.0,.5,1.0]:builder.beam(a.lerp(b,t)+Vector3(side*half,0,0),a.lerp(b,t)+Vector3(side*half,.9,0),.055,materials.wood)

 var landing:=b+Vector3(0,0,-1.0)
 builder.quad(b+Vector3(-half,0,0),b+Vector3(half,0,0),landing+Vector3(half,0,0),landing+Vector3(-half,0,0),materials.wood)
