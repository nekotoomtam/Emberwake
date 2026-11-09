extends Node3D
## Small stores delivery against the wall, leaving the northern route open.
const Detail=preload("res://scripts/opening/harbor_detail.gd")
var materials: Dictionary={}
var geometry_count:=0
var crates: Array[StaticBody3D]=[]
var bounds:=AABB()
var main
func _ready() -> void:
 name="HarborPassageCargo"
 for row in [["passage_wood","9a7959","wood"],["passage_dark","73563f","wood"],["passage_brace","b4966c","wood"],["passage_iron","495956","slate"]]:
  if not materials.has(row[0]):materials[row[0]]=Detail.material(row[1],row[2],9260+materials.size())
 main=Detail.new();main.name="WallSideGoodsGeometry";add_child(main)
 _crate(Vector3(-26.82,.055,-19.6),Vector3(.96,.82,.82))
 _crate(Vector3(-26.84,.875,-19.58),Vector3(.62,.54,.62))
 _crate(Vector3(-26.78,.055,-18.35),Vector3(.86,.58,.76))
 main.finish();geometry_count=main.count
 var first:=true
 for mesh in main.find_children("*","MeshInstance3D",true,false):
  var part: AABB=mesh.global_transform*mesh.mesh.get_aabb()
  bounds=part if first else bounds.merge(part);first=false
func _crate(base: Vector3,size_: Vector3) -> void:
 var centre:=base+Vector3.UP*size_.y*.5
 main.box(centre,size_,materials.passage_dark)
 for index in 5:
  var plank_x: float=-size_.x*.5+(float(index)+.5)*size_.x/5
  main.box(centre+Vector3(plank_x,0,size_.z*.5+.008),Vector3(size_.x/5-.014,size_.y-.04,.016),materials.passage_wood)
  main.box(centre+Vector3(plank_x,size_.y*.5+.008,0),Vector3(size_.x/5-.014,.016,size_.z-.04),materials.passage_wood)
 for index in 4:
  var plank_z: float=-size_.z*.5+(float(index)+.5)*size_.z/4
  for side in [-1.0,1.0]:main.box(centre+Vector3(side*(size_.x*.5+.008),0,plank_z),Vector3(.016,size_.y-.04,size_.z/4-.013),materials.passage_wood)
 for y in [-1.0,1.0]:
  main.box(centre+Vector3(0,y*(size_.y*.5-.055),size_.z*.5+.025),Vector3(size_.x+.025,.075,.040),materials.passage_brace)
  for side in [-1.0,1.0]:main.box(centre+Vector3(side*(size_.x*.5+.025),y*(size_.y*.5-.055),0),Vector3(.040,.075,size_.z+.025),materials.passage_brace)
 main.beam(centre+Vector3(-size_.x*.40,-size_.y*.35,size_.z*.5+.048),centre+Vector3(size_.x*.40,size_.y*.35,size_.z*.5+.048),.058,materials.passage_brace)
 for side in [-1.0,1.0]:
  for y in [-1.0,1.0]:main.box(centre+Vector3(side*size_.x*.39,y*size_.y*.36,size_.z*.5+.052),Vector3(.025,.025,.015),materials.passage_iron)
 var body:=StaticBody3D.new();body.name="PassageCrate"+str(crates.size()+1);body.position=centre;body.collision_layer=1;body.collision_mask=3;body.add_to_group("harbor_passage_cargo")
 var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size_+Vector3(.09,.016,.09);collision.shape=shape;body.add_child(collision);add_child(body);crates.append(body)
