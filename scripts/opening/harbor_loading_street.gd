extends Node3D
## The public square's quiet goods lane. All surface stones are flush with the
## supported plaza; parked equipment has matching native physical shapes.
const Detail=preload("res://scripts/opening/harbor_detail.gd")
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
const ROAD_RECT:=Rect2(Vector2(-49.5,6.3),Vector2(26.5,9.1))
const WAGON_AT:=Vector3(-40.4,.055,11.8)
var materials: Dictionary={}
var geometry_count:=0
var road_bounds:=ROAD_RECT
## Aggregate native collision bounds, including the resting shafts and bench.
var cart_bounds:=AABB(Vector3(-42.675,.055,10.675),Vector3(6.875,2.055,2.25))
var prop_bounds: Dictionary={}
var wagon_geometry
var main
var _collider_id:=0
func _ready() -> void:
 ensure_road_materials(materials)
 main=Detail.new();main.name="LoadingStreetAuthoredGeometry";add_child(main)
 _road()
 var road_geometry=main
 wagon_geometry=Detail.new();wagon_geometry.name="ParkedGoodsWagonGeometry";wagon_geometry.add_to_group("harbor_loading_wagon_visual");wagon_geometry.set_meta("prop_id","goods_wagon");add_child(wagon_geometry)
 main=wagon_geometry;_goods_wagon();wagon_geometry.finish()
 main=road_geometry;_loading_cluster();_handcart()
 prop_bounds.goods_wagon=cart_bounds
 geometry_count=main.count+wagon_geometry.count;main.finish()
static func ensure_road_materials(palette: Dictionary) -> void:
 var entries: Array=[["street_stone","969b95"],["street_stone_light","a6aaa0"],["street_stone_dark","868f88"],["street_gutter","7d8882"]]
 for i in entries.size():
  var entry: Array=entries[i]
  if not palette.has(entry[0]):palette[entry[0]]=Detail.material(entry[1],"plaster",9082+i)
static func cobble_road(detail,rect: Rect2,palette: Dictionary) -> void:
 # One world-anchored stone grid joins the old loading lane to the coastal
 # approach. Separate owners clip at their seam without overlaying a footway.
 var center:=rect.get_center();var y: float=Profile.CAFE.y
 detail.box(Vector3(center.x,y-.004,center.y),Vector3(rect.size.x,.012,rect.size.y),palette.street_gutter)
 for row in 26:
  var z: float=6.49+row*.344
  if z<rect.position.y or z>rect.end.y:continue
  var first:=int(floor((rect.position.x+49.25)/.497))-1
  var last:=int(ceil((rect.end.x+49.25)/.497))+1
  for col in range(first,last):
   var x: float=-49.25+col*.497+(0.245 if row%2 else 0.0)
   var left: float=maxf(rect.position.x,x-.234);var right: float=minf(rect.end.x,x+.234)
   if right-left<.025:continue
   var shade: float=float(posmod(row*7919+col*104729,100))*.01
   var material_: Material=palette.street_stone_dark if shade<.21 else (palette.street_stone_light if shade>.80 else palette.street_stone)
   detail.box(Vector3((left+right)*.5,y+.001,z),Vector3(right-left,.010,.315),material_)
func _solid_box(at: Vector3,size_: Vector3,group: String,id: String) -> StaticBody3D:
 var body:=StaticBody3D.new();body.name=id+"Collision"+str(_collider_id);_collider_id+=1
 body.position=at;body.collision_layer=1;body.add_to_group(group);body.set_meta("prop_id",id)
 var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size_;collision.shape=shape
 body.add_child(collision);add_child(body);return body
func _solid_wheel(at: Vector3,radius: float,width: float,group: String,id: String) -> void:
 var body:=StaticBody3D.new();body.name=id+"WheelCollision"+str(_collider_id);_collider_id+=1
 body.position=at;body.rotation.x=PI*.5;body.collision_layer=1;body.add_to_group(group);body.set_meta("prop_id",id)
 var collision:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=radius;shape.height=width;collision.shape=shape
 body.add_child(collision);add_child(body)
func _road() -> void:
 var y: float=Profile.CAFE.y
 # Close-jointed small cobbles contrast with the square's broad pale flagstones.
 cobble_road(main,ROAD_RECT,materials)
 # Low dressed-stone edges read as a road, without kerbs that catch a walker.
 for side_z in [6.30,15.4]:
  main.box(Vector3(-36.25,y+.005,side_z),Vector3(26.5,.016,.18),materials.stone2)
  for i in 32:
   main.box(Vector3(-49.08+i*.82,y+.015,side_z),Vector3(.025,.004,.17),materials.street_gutter)
 # A shallow stone drainage channel follows the goods-side curb. Open east end
 # stays a broad level crossing to the quay and the messenger's route.
 main.box(Vector3(-38.75,y+.004,15.12),Vector3(21.5,.014,.20),materials.street_gutter)
 for x in [-46.1,-36.7,-29.6]:
  main.box(Vector3(x,y+.014,15.10),Vector3(.62,.012,.25),materials.iron)
  for slot in 7:main.box(Vector3(x-.25+slot*.083,y+.023,15.1),Vector3(.035,.006,.20),materials.street_gutter)
 # Chisel-set threshold stones mark each end with the same material as the curb.
 for x in [-23.12]:
  main.box(Vector3(x,y+.003,10.85),Vector3(.16,.014,8.9),materials.stone2)
func _wheel(at: Vector3,radius: float,width: float,seed_: int) -> void:
 var ring: Array[Vector3]=[]
 for i in 25:
  var angle: float=TAU*i/24;ring.append(at+Vector3(cos(angle)*radius,sin(angle)*radius,0))
 main.tube(ring,.055,materials.iron,1)
 for side in [-1.0,1.0]:
  var wooden_ring: Array[Vector3]=[]
  for i in 25:
   var angle: float=TAU*i/24;wooden_ring.append(at+Vector3(cos(angle)*(radius-.055),sin(angle)*(radius-.055),side*width*.30))
  main.tube(wooden_ring,.042,materials.wood,1)
 for i in 12:
  var angle: float=TAU*i/12
  main.beam(at,at+Vector3(cos(angle)*(radius-.06),sin(angle)*(radius-.06),0),.048,materials.darkwood)
 main.beam(at+Vector3(0,0,-width*.57),at+Vector3(0,0,width*.57),.14,materials.iron)
 main.boulder(at+Vector3(0,0,width*.50),Vector3(.19,.19,.07),materials.gold,seed_)
func _goods_wagon() -> void:
 var at:=WAGON_AT
 # Four iron-tyred spoked wheels, with visible two-axle running gear.
 for axle_x in [-1.48,1.48]:
  main.beam(at+Vector3(axle_x,.64,-1.12),at+Vector3(axle_x,.64,1.12),.14,materials.iron)
  for side in [-1.0,1.0]:
   var center: Vector3=at+Vector3(axle_x,.64,side*1.03)
   _wheel(center,.62,.18,9080+int(axle_x*10))
   _solid_wheel(center,.62,.19,"harbor_loading_wagon","goods_wagon")
  # Layered leaf springs sit above each axle rather than floating at the bed.
  for side in [-1.0,1.0]:
   for layer in 3:
    main.beam(at+Vector3(axle_x-.52,.78+layer*.045,side*.69),at+Vector3(axle_x+.52,.78+layer*.045,side*.69),.044,materials.iron)
 for side in [-1.0,1.0]:main.box(at+Vector3(0,.86,side*.68),Vector3(4.5,.19,.15),materials.darkwood)
 for board in 11:main.box(at+Vector3(-2.05+board*.41,1.015,0),Vector3(.39,.16,1.85),materials.wood)
 _solid_box(at+Vector3(0,1.04,0),Vector3(4.5,.46,1.85),"harbor_loading_wagon","goods_wagon")
 # Low plank sides, end gates, iron straps, pegs and rivet heads.
 for side in [-1.0,1.0]:
  for row in 3:main.box(at+Vector3(0,1.20+row*.18,side*.92),Vector3(4.48,.16,.10),materials.wood)
  for x in [-2.17,-.72,.72,2.17]:
   main.box(at+Vector3(x,1.39,side*.985),Vector3(.075,.70,.045),materials.iron)
   for height in [1.16,1.57]:main.boulder(at+Vector3(x,height,side*1.015),Vector3(.045,.045,.025),materials.gold,9100+int((x+3)*10))
  _solid_box(at+Vector3(0,1.43,side*.92),Vector3(4.5,.67,.11),"harbor_loading_wagon","goods_wagon")
 for end_x in [-2.22,2.22]:
  for row in 3:main.box(at+Vector3(end_x,1.20+row*.18,0),Vector3(.10,.16,1.80),materials.wood)
  main.beam(at+Vector3(end_x-.015,1.12,-.75),at+Vector3(end_x-.015,1.68,.75),.055,materials.darkwood)
  _solid_box(at+Vector3(end_x,1.43,0),Vector3(.11,.67,1.85),"harbor_loading_wagon","goods_wagon")
 # Unhitched shafts rest on a short trestle. Their boxes share visible dimensions.
 for side in [-1.0,1.0]:
  main.box(at+Vector3(3.37,.72,side*.65),Vector3(2.46,.085,.085),materials.darkwood)
  _solid_box(at+Vector3(3.37,.72,side*.65),Vector3(2.46,.085,.085),"harbor_loading_wagon","goods_wagon")
  main.box(at+Vector3(3.95,.35,side*.65),Vector3(.08,.70,.08),materials.wood)
  _solid_box(at+Vector3(3.95,.35,side*.65),Vector3(.08,.70,.08),"harbor_loading_wagon","goods_wagon")
 main.box(at+Vector3(3.95,.64,0),Vector3(.10,.12,1.6),materials.wood)
 _solid_box(at+Vector3(3.95,.64,0),Vector3(.10,.12,1.6),"harbor_loading_wagon","goods_wagon")
 # Raised driver's bench and footboard make the front unambiguous.
 for side in [-1.0,1.0]:main.box(at+Vector3(1.50,1.54,side*.66),Vector3(.13,.92,.12),materials.darkwood)
 main.box(at+Vector3(1.50,1.90,0),Vector3(.55,.12,1.65),materials.wood)
 main.box(at+Vector3(1.28,2.02,0),Vector3(.10,.22,1.65),materials.darkwood)
 main.box(at+Vector3(2.43,1.20,0),Vector3(.48,.10,1.65),materials.darkwood)
 _solid_box(at+Vector3(1.50,1.84,0),Vector3(.58,.43,1.70),"harbor_loading_wagon","goods_wagon")
 _solid_box(at+Vector3(2.43,1.20,0),Vector3(.48,.10,1.65),"harbor_loading_wagon","goods_wagon")
 # A restrained mixed load leaves the craftsmanship of the bed visible.
 _crate(at+Vector3(-1.48,1.38,-.30),Vector3(.76,.63,.80),false)
 _crate(at+Vector3(-.65,1.38,-.31),Vector3(.72,.63,.80),false)
 _sack(at+Vector3(-1.42,1.96,-.21),Vector3(.55,.63,.56),9092,false)
 _sack(at+Vector3(.26,1.40,.20),Vector3(.76,.68,.86),9093,false)
 _sack(at+Vector3(-.47,1.42,.40),Vector3(.63,.68,.69),9094,false)
 var tie: Array[Vector3]=[at+Vector3(-1.96,1.10,-1.0),at+Vector3(-1.7,2.22,-.32),at+Vector3(-1.35,2.26,.10),at+Vector3(-1.03,1.10,1.0)]
 main.tube(tie,.025,materials.rope,1)
func _crate(at: Vector3,size_: Vector3,solid: bool=true) -> void:
 main.box(at,size_,materials.wood)
 for side in [-1.0,1.0]:
  for row in 4:
   main.box(at+Vector3(0,-size_.y*.38+row*size_.y*.255,side*(size_.z*.5+.008)),Vector3(size_.x,.017,.017),materials.darkwood)
  for x in [-size_.x*.39,size_.x*.39]:
   main.box(at+Vector3(x,0,side*(size_.z*.5+.025)),Vector3(.058,size_.y+.04,.042),materials.darkwood)
  main.beam(at+Vector3(-size_.x*.40,-size_.y*.38,side*(size_.z*.5+.052)),at+Vector3(size_.x*.40,size_.y*.38,side*(size_.z*.5+.052)),.041,materials.gold)
 for side in [-1.0,1.0]:main.box(at+Vector3(side*size_.x*.35,size_.y*.5+.012,0),Vector3(.06,.032,size_.z+.035),materials.darkwood)
 if solid:_solid_box(at,size_+Vector3(.03,.03,.10),"harbor_loading_cargo","loading_cargo")
func _sack(at: Vector3,size_: Vector3,seed_: int,solid: bool=true) -> void:
 main.boulder(at,size_,materials.canvas,seed_)
 main.cylinder(at+Vector3.UP*(size_.y*.45),.06,.10,materials.canvas,8,.035)
 var seam: Array[Vector3]=[at+Vector3(-size_.x*.34,-size_.y*.21,size_.z*.36),at+Vector3(-size_.x*.42,size_.y*.10,size_.z*.32),at+Vector3(0,size_.y*.42,0)]
 main.tube(seam,.012,materials.rope,1)
 if solid:_solid_box(at,size_*.86,"harbor_loading_cargo","loading_cargo")
func _barrel(at: Vector3,radius: float,height: float) -> void:
 main.cylinder(at+Vector3.UP*height*.5,radius,height,materials.wood,16,radius*.87)
 for y in [.12,height*.32,height*.75,height-.1]:
  main.cylinder(at+Vector3.UP*y,radius+.014,.045,materials.iron,16,radius+.014)
 for i in 16:
  var angle: float=TAU*i/16;var radial:=Vector3(cos(angle),0,sin(angle))
  main.beam(at+radial*(radius+.007)+Vector3.UP*.06,at+radial*(radius*.89+.01)+Vector3.UP*(height-.04),.013,materials.darkwood)
 main.cylinder(at+Vector3.UP*(height+.01),radius*.85,.025,materials.darkwood,16)
 for z in [-.16,0,.16]:main.box(at+Vector3(0,height+.029,z),Vector3(radius*1.42,.022,.12),materials.wood)
 _solid_box(at+Vector3.UP*height*.5,Vector3(radius*2,height,radius*2),"harbor_loading_cargo","loading_cargo")
func _loading_cluster() -> void:
 var y: float=Profile.CAFE.y
 # Cargo is consolidated beside one curb, not scattered across the public route.
 _crate(Vector3(-42.95,y+.39,14.30),Vector3(.89,.78,.83))
 _crate(Vector3(-42.05,y+.32,14.37),Vector3(.78,.64,.75))
 _crate(Vector3(-42.75,y+1.08,14.30),Vector3(.64,.60,.65))
 _barrel(Vector3(-39.0,y,14.25),.36,.94)
 _barrel(Vector3(-38.20,y,14.29),.32,.83)
 _sack(Vector3(-40.30,y+.34,14.22),Vector3(.71,.68,.77),9110)
 _sack(Vector3(-40.95,y+.29,14.49),Vector3(.60,.58,.62),9111)
 # Rope coil and two tied bundles explain the cargo without adding actors.
 for coil in 4:
  var ring: Array[Vector3]=[]
  for i in 25:
   var angle: float=TAU*i/24;var radius: float=.18+coil*.035
   ring.append(Vector3(-37.35+cos(angle)*radius,y+.036+coil*.012,14.37+sin(angle)*radius))
  main.tube(ring,.022,materials.rope,1)
 prop_bounds.loading_cargo=AABB(Vector3(-43.42,y,13.80),Vector3(6.40,1.40,1.12))
func _handcart() -> void:
 var at:=Vector3(-47.2,Profile.CAFE.y,12.8)
 # The older two-wheel porter cart belongs to the same loading bay.
 main.box(at+Vector3.UP*.65,Vector3(1.65,.13,1.04),materials.wood)
 _solid_box(at+Vector3.UP*.65,Vector3(1.65,.13,1.04),"harbor_loading_handcart","handcart")
 for side in [-1.0,1.0]:
  var center: Vector3=at+Vector3(-.18,.40,side*.64)
  _wheel(center,.38,.14,9130)
  _solid_wheel(center,.38,.15,"harbor_loading_handcart","handcart")
  for row in 2:main.box(at+Vector3(0,.83+row*.17,side*.50),Vector3(1.65,.14,.065),materials.wood)
  main.box(at+Vector3(1.27,.66,side*.40),Vector3(.90,.065,.065),materials.darkwood)
  _solid_box(at+Vector3(1.27,.66,side*.40),Vector3(.90,.065,.065),"harbor_loading_handcart","handcart")
 _solid_box(at+Vector3(0,.90,0),Vector3(1.65,.47,1.08),"harbor_loading_handcart","handcart")
 for i in 2:_sack(at+Vector3(-.38+i*.68,1.04,0),Vector3(.61,.62,.75),9134+i,false)
 prop_bounds.handcart=AABB(at+Vector3(-.84,0,-.72),Vector3(2.56,1.38,1.44))
