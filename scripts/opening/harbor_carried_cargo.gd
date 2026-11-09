extends Node3D
## Native load centred on its origin, independent from the character bitmap.
const Detail=preload("res://scripts/opening/harbor_detail.gd")
static var palette: Dictionary={}
func configure(size_: float,kind: String) -> void:
 if palette.is_empty():
  palette={"wood":Detail.material("967151","wood",10110),"edge":Detail.material("5d483d","wood",10111),"brace":Detail.material("cfaf7b","wood",10112),"fish":Detail.material("9caeb0","slate",10113)}
 var wood: Material=palette.wood;var edge: Material=palette.edge;var brace: Material=palette.brace
 var geometry=Detail.new();geometry.name="NativeCrateGeometry";add_child(geometry)
 geometry.box(Vector3.ZERO,Vector3(size_,size_,size_*.96),wood)
 for side in [-1.,1.]:
  for face in [-1.,1.]:geometry.box(Vector3(side*size_*.36,0,face*size_*.493),Vector3(size_*.075,size_,size_*.035),edge)
  geometry.beam(Vector3(-size_*.43,-size_*.43,side*size_*.515),Vector3(size_*.43,size_*.43,side*size_*.515),size_*.055,brace)
 for stripe in [-.25,0.,.25]:geometry.box(Vector3(0,stripe*size_,size_*.485),Vector3(size_,size_*.025,.012),edge)
 if kind=="fish":
  var fish: Material=palette.fish
  for i in 3:geometry.box(Vector3((i-1)*size_*.23,size_*.52,0),Vector3(size_*.17,.035,size_*.6),fish)
 geometry.finish()
