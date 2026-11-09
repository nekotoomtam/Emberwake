extends Node3D
## Square stone coping and low iron rails on the public sea boundary only.
const Detail=preload("res://scripts/opening/harbor_detail.gd")
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var materials: Dictionary={}
var geometry_count:=0
var b
func _ready() -> void:
 name="PublicQuayEdges"
 for entry in [["stone","aaa99a","stone"],["stone2","898e87","stone"],["cream","d6c6a6","plaster"],["iron","4a5452","iron"]]:
  if not materials.has(entry[0]):materials[entry[0]]=Detail.material(entry[1],entry[2],8510+materials.size())
 b=Detail.new();add_child(b)
 # Keep the northeast passage visually open; the protagonist warns at its end.
 # Low water-edge coping stays, with no tall post/pickets or invisible rail body.
 _coping(Vector3(-19.55,0,-20),Vector3(-19.55,0,-17.4))
 _rail("PlazaSeaRail",Vector3(-19.55,0,-17.4),Vector3(-19.55,0,2.1))
 _rail("QuayWestRail",Vector3(-19.55,0,2.1),Vector3(4.8,0,2.1))
 # The complete 4.4m boarding opening and original pier/gangway stay free.
 _rail("QuayEastRail",Vector3(9.2,0,2.1),Vector3(22,0,2.1))
 _rail("QuayEndRail",Vector3(22,0,2.1),Vector3(22,0,Profile.QUAY_RECT.end.y))
 # The actual shore steps from the incoming road to the compact plaza, then
 # returns to the original quay. Every rail stands on matching capped masonry.
 _rail("TownSeafrontRail",Vector3(-79,0,17.5),Vector3(-51,0,17.5))
 _rail("TownShoreStep",Vector3(-51,0,17.5),Vector3(-51,0,15.4))
 _rail("PlazaSouthRail",Vector3(-51,0,15.4),Vector3(-18,0,15.4))
 _rail("QuaySouthRail",Vector3(-18,0,Profile.QUAY_RECT.end.y),Vector3(22,0,Profile.QUAY_RECT.end.y))
 geometry_count=b.count;b.finish()
func _coping(a: Vector3,z: Vector3) -> void:
 var delta: Vector3=z-a
 var length: float=delta.length()
 var center: Vector3=(a+z)*.5
 var horizontal: bool=absf(delta.x)>absf(delta.z)
 var coping:=Vector3(length,.18,.68) if horizontal else Vector3(.68,.18,length)
 var wall:=Vector3(length,.85,.44) if horizontal else Vector3(.44,.85,length)
 b.box(center+Vector3.UP*.10,coping,materials.cream)
 b.box(center-Vector3.UP*.40,wall,materials.stone2)
func _rail(label: String,a: Vector3,z: Vector3) -> void:
 _coping(a,z)
 var delta:=z-a;var length:=delta.length();var along:=delta/length
 var center: Vector3=(a+z)*.5
 var horizontal: bool=absf(delta.x)>absf(delta.z)
 # The continuous collision envelope follows the visible post-and-picket rail.
 # It stays inside each endpoint, especially beside the boarding opening.
 var body:=StaticBody3D.new();body.name=label;body.position=center+Vector3.UP*.48;body.collision_layer=1
 body.add_to_group("harbor_quay_edge")
 var col:=CollisionShape3D.new();var shape:=BoxShape3D.new()
 shape.size=Vector3(length,.96,.34) if horizontal else Vector3(.34,.96,length)
 col.shape=shape;body.add_child(col);add_child(body)
 for y in [.30,.60,.91]:
  var rail_size:=Vector3(length,.07,.07) if horizontal else Vector3(.07,.07,length)
  b.box(center+Vector3.UP*y,rail_size,materials.iron)
 var panels:=maxi(1,int(ceil((length-.36)/2.4)))
 for i in panels+1:
  var p: Vector3=a+along*(.18+(length-.36)*float(i)/panels)
  b.box(p+Vector3.UP*.44,Vector3(.34,.88,.34),materials.stone)
  b.box(p+Vector3.UP*.92,Vector3(.40,.08,.40),materials.cream)
 var pickets:=maxi(1,int(ceil(length/.43)))
 for i in range(1,pickets):
  var p: Vector3=a+along*(length*float(i)/pickets)
  b.box(p+Vector3.UP*.59,Vector3(.045,.64,.045),materials.iron)
