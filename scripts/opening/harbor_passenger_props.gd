extends Node3D
## Compact native departure furniture. Static components own fitted solids;
## the forecourt owner alone owns the separate passenger activity clock.
const Detail=preload("res://scripts/opening/harbor_detail.gd")
var materials: Dictionary={}
var geometry_count:=0
var main
var bench_anchor:=Vector3(-12.7,.055,3.9)
var board_anchor:=Vector3(-8,.055,3.65)
var cart_anchor:=Vector3(-2.8,.055,4.1)
var prop_bodies: Array[PhysicsBody3D]=[]
var bench_body: StaticBody3D
var board_bodies: Array[PhysicsBody3D]=[]
var cart_bodies: Array[PhysicsBody3D]=[]
var bounds: Dictionary={}
var _font: SystemFont
func _ready() -> void:
 _palette()
 main=Detail.new();main.name="PassengerForecourtNativeGeometry";add_child(main)
 _bench();_departure_board();_luggage_trolley()
 _rope_coil(Vector3(-11.2,.055,2.85),0)
 _rope_coil(Vector3(-4.9,.055,2.8),1)
 geometry_count=main.count;main.finish()
func _palette() -> void:
 for entry in [["wood","956d51","wood"],["darkwood","5d483d","wood"],["gold","cfa76f","wood"],["cream","e9dabb","plaster"],["teal","487d80","wood"],["iron","3e5357","slate"],["rope","bbaa7d","wood"],["red","ba6f5b","plaster"],["canvas","eddfb9","plaster"]]:
  if not materials.has(entry[0]):materials[entry[0]]=Detail.material(entry[1],entry[2],9400+materials.size())
 _font=SystemFont.new();_font.font_names=PackedStringArray(["Tahoma","Segoe UI"])
func _body(name_: String,at: Vector3,kind: String) -> StaticBody3D:
 var body:=StaticBody3D.new();body.name=name_;body.position=at;body.collision_layer=1;body.collision_mask=0
 body.add_to_group("harbor_passenger_prop");body.add_to_group("harbor_passenger_"+kind)
 add_child(body);prop_bodies.append(body)
 if kind=="board":board_bodies.append(body)
 if kind=="cart":cart_bodies.append(body)
 return body
func _include(kind: String,box: AABB) -> void:
 bounds[kind]=box if not bounds.has(kind) else bounds[kind].merge(box)
func _box(kind: String,body: StaticBody3D,at: Vector3,size_: Vector3,mat: Material,rotation_: Vector3=Vector3.ZERO) -> void:
 var basis_:=Basis.from_euler(rotation_)
 main.box(at,size_,mat,rotation_)
 _include(kind,Transform3D(basis_,at)*AABB(-size_*.5,size_))
 if body==null:return
 var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size_
 collision.shape=shape;collision.transform=Transform3D(basis_,at-body.position);body.add_child(collision)
func _beam(kind: String,body: StaticBody3D,a: Vector3,b: Vector3,width: float,mat: Material) -> void:
 var basis_:=Basis(Quaternion(Vector3.UP,(b-a).normalized()))
 _box(kind,body,(a+b)*.5,Vector3(width,a.distance_to(b),width),mat,basis_.get_euler())
func _tube(kind: String,body: StaticBody3D,points: Array[Vector3],radius: float,mat: Material) -> void:
 main.tube(points,radius,mat,1.0)
 for i in range(points.size()-1):
  var a: Vector3=points[i];var b: Vector3=points[i+1]
  _include(kind,AABB(a,Vector3.ZERO).expand(b).grow(radius))
  if body==null:continue
  var collision:=CollisionShape3D.new();var shape:=CapsuleShape3D.new()
  shape.radius=radius;shape.height=a.distance_to(b)+radius*2
  collision.shape=shape;collision.transform=Transform3D(Basis(Quaternion(Vector3.UP,(b-a).normalized())),(a+b)*.5-body.position);body.add_child(collision)
func _bench() -> void:
 bench_body=_body("DepartureBenchFittedSolids",bench_anchor,"bench")
 # Exact cafe width, slats, back and iron geometry retain its .4725 m seat top.
 for i in 4:_box("bench",bench_body,bench_anchor+Vector3(0,.43,-.20+i*.13),Vector3(2.1,.085,.10),materials.wood)
 for y in [.71,.92]:_box("bench",bench_body,bench_anchor+Vector3(0,y,-.32),Vector3(2.1,.12,.075),materials.wood)
 for x in [-.82,.82]:
  _beam("bench",bench_body,bench_anchor+Vector3(x,.08,.25),bench_anchor+Vector3(x,.47,.22),.075,materials.iron)
  _beam("bench",bench_body,bench_anchor+Vector3(x,.08,-.25),bench_anchor+Vector3(x,1.02,-.35),.075,materials.iron)
  _beam("bench",bench_body,bench_anchor+Vector3(x,.65,-.29),bench_anchor+Vector3(x,.65,.26),.045,materials.iron)
func _departure_board() -> void:
 # Thin board and separated posts leave the open space below the sign real.
 for side in [-1.0,1.0]:
  var post:=_body("DepartureBoardPost"+str(int(side)),board_anchor+Vector3(side*.94,0,0),"board")
  _box("board",post,post.position+Vector3.UP*.99,Vector3(.12,1.98,.14),materials.darkwood)
  _box("board",post,post.position+Vector3(0,.06,0),Vector3(.25,.12,.30),materials.iron)
 var panel:=_body("DepartureBoardThinPanel",board_anchor,"board")
 _box("board",panel,board_anchor+Vector3(0,1.40,0),Vector3(2.14,1.13,.12),materials.wood)
 _box("board",panel,board_anchor+Vector3(0,1.40,.075),Vector3(1.94,.96,.03),materials.teal)
 for x in [-.98,.98]:_box("board",null,board_anchor+Vector3(x,1.4,.101),Vector3(.035,1.0,.012),materials.gold)
 for y in [.91,1.89]:_box("board",null,board_anchor+Vector3(0,y,.101),Vector3(1.995,.035,.012),materials.gold)
 _label("DeparturePierHeading",board_anchor+Vector3(0,1.73,.112),"PIER 1",22,.008)
 _label("DepartureTimes",board_anchor+Vector3(0,1.33,.112),"DEPARTURES\n09:00   12:30\n15:00   18:00",18,.0065)
func _label(name_: String,at: Vector3,text_: String,font_size_: int,pixel_: float) -> void:
 var label:=Label3D.new();label.name=name_;label.text=text_;label.font=_font
 label.font_size=font_size_;label.pixel_size=pixel_;label.position=at
 label.modulate=Color("f4e6c7");label.outline_size=0;label.no_depth_test=false
 label.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR;add_child(label)
func _luggage_trolley() -> void:
 var deck:=_body("ParkedLuggageTrolleyDeck",cart_anchor,"cart")
 _box("cart",deck,cart_anchor+Vector3(0,.34,0),Vector3(1.72,.12,.96),materials.darkwood)
 for i in 6:_box("cart",null,cart_anchor+Vector3(-.725+i*.29,.409,0),Vector3(.265,.018,.9),materials.wood)
 for side in [-1.0,1.0]:
  _beam("cart",deck,cart_anchor+Vector3(-.80,.43,side*.47),cart_anchor+Vector3(.80,.43,side*.47),.055,materials.iron)
  for x in [-.57,.57]:_wheel(cart_anchor+Vector3(x,.24,side*.53),str(side)+str(x))
 _beam("cart",deck,cart_anchor+Vector3(-.57,.24,-.55),cart_anchor+Vector3(-.57,.24,.55),.055,materials.iron)
 _beam("cart",deck,cart_anchor+Vector3(.57,.24,-.55),cart_anchor+Vector3(.57,.24,.55),.055,materials.iron)
 # Both cases stay below the handle and carry twin straps, buckles and corners.
 for i in 2:
  var at: Vector3=cart_anchor+Vector3(-.42+i*.81,.68,0)
  var trunk:=_body("TrolleyStrappedTrunk"+str(i+1),at,"cart")
  var mat: Material=materials.teal if i==0 else materials.red
  _box("cart",trunk,at,Vector3(.73,.54,.74),mat)
  _box("cart",null,at+Vector3(0,.225,0),Vector3(.75,.055,.76),materials.darkwood)
  for x in [-.22,.22]:
   _box("cart",null,at+Vector3(x,.005,.38),Vector3(.052,.55,.022),materials.darkwood)
   _box("cart",null,at+Vector3(x,.28,0),Vector3(.052,.022,.77),materials.darkwood)
   _box("cart",null,at+Vector3(x,-.015,.397),Vector3(.075,.085,.018),materials.gold)
  for side in [-1.0,1.0]:_box("cart",null,at+Vector3(side*.345,-.205,.38),Vector3(.07,.10,.025),materials.gold)
  _tube("cart",null,[at+Vector3(-.1,.27,0),at+Vector3(-.08,.34,0),at+Vector3(.08,.34,0),at+Vector3(.1,.27,0)],.018,materials.darkwood)
 var handle:=_body("TrolleyFittedPushHandle",cart_anchor,"cart")
 for z in [-.42,.42]:_beam("cart",handle,cart_anchor+Vector3(.77,.36,z),cart_anchor+Vector3(1.0,1.12,z),.05,materials.iron)
 _beam("cart",handle,cart_anchor+Vector3(1.0,1.12,-.42),cart_anchor+Vector3(1.0,1.12,.42),.055,materials.darkwood)
func _wheel(at: Vector3,id_: String) -> void:
 var wheel:=_body("TrolleyWheel"+id_,at,"cart")
 var points: Array[Vector3]=[]
 for i in 25:
  var angle: float=TAU*i/24
  points.append(at+Vector3(cos(angle)*.214,sin(angle)*.214,0))
 # A wheel's thin collision disc shares the rim's radius and axle thickness.
 _tube("cart",null,points,.026,materials.iron)
 for i in 8:
  var angle: float=TAU*i/8
  _beam("cart",null,at,at+Vector3(cos(angle)*.205,sin(angle)*.205,0),.021,materials.gold)
 _box("cart",null,at,Vector3(.095,.095,.10),materials.iron)
 var collision:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=.24;shape.height=.055
 collision.shape=shape;collision.rotation.x=PI*.5;wheel.add_child(collision)
func _rope_coil(at: Vector3,index: int) -> void:
 var body:=_body("SmallMooringRopeCoil"+str(index+1),at,"rope")
 for turn in 3:
  var points: Array[Vector3]=[]
  for i in 25:
   var angle: float=TAU*i/24
   points.append(at+Vector3(cos(angle)*(.22+turn*.05),.025+turn*.014,sin(angle)*(.22+turn*.05)))
  _tube("ropes",body,points,.022,materials.rope)
 var tail: Array[Vector3]=[at+Vector3(.22,.025,0),at+Vector3(.15,.025,.13),at+Vector3(.02,.025,.15)]
 _tube("ropes",body,tail,.022,materials.rope)
