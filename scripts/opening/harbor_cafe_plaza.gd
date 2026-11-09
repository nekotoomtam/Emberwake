extends Node3D
## Authored public square, cafe terrace and enclosed rear market.
## Coordinates remain in the original harbor's metre scale; all walkable slabs
## meet the original quay at Profile.CAFE.y. The hero and steam stay world-owned.
const Detail=preload("res://scripts/opening/harbor_detail.gd")
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
const Fountain=preload("res://scripts/opening/harbor_plaza_fountain.gd")
const LoadingStreet=preload("res://scripts/opening/harbor_loading_street.gd")
const NPC=preload("res://scripts/opening/harbor_npc.gd")
const Pigeon=preload("res://scripts/opening/harbor_pigeon.gd")
const Appearance=preload("res://scripts/opening/npc_appearance.gd")
const TravelLuggage=preload("res://scripts/opening/harbor_travel_luggage.gd")
var materials: Dictionary={}
var geometry_count:=0
var cup: Node3D
var people: Array=[]
var birds: Array=[]
var fountain: Node3D
var street: Node3D
var life: Node3D
var departure_chair: StaticBody3D
var travel_luggage: Node3D
var main
var _collider_id:=0
func _ready() -> void:
 _palette()
 main=Detail.new();main.name="CafePlazaAuthoredGeometry";add_child(main)
 _ground();_cafe();_rear_frontage();_market();_square_furniture();_living_square()
 street=LoadingStreet.new();street.name="HarborLoadingStreet";street.materials=materials;add_child(street)
 fountain=Fountain.new();fountain.name="PublicPlazaFountain";fountain.materials=materials;fountain.position=Profile.FOUNTAIN;add_child(fountain)
 geometry_count=main.count+cup.count+fountain.geometry_count+street.geometry_count+travel_luggage.geometry_count
 main.finish()
func _palette() -> void:
 for entry in [["wood","956d51","wood"],["darkwood","5d483d","wood"],["gold","cfa76f","wood"],["stone","b7b0a0","plaster"],["stone2","a7a596","plaster"],["cream","e9dabb","plaster"],["teal","487d80","wood"],["canvas","eddfb9","plaster"],["red","ba6f5b","plaster"],["iron","3e5357","slate"],["rope","bbaa7d","wood"],["leaves","6b8558","moss"],["clay","b47759","plaster"],["window","789aab","slate"],["coffee","493329","wood"],["slate","65777a","slate"],["paving","c6bfae","plaster"],["brick","ae7964","brick"],["flower","bc7b83","plaster"],["flower2","d8b968","plaster"],["soil","5e5b45","moss"]]:
  if not materials.has(entry[0]):materials[entry[0]]=Detail.material(entry[1],entry[2],8870+materials.size())
 # Every awning is authored with visible undersides.
 materials.canvas.cull_mode=BaseMaterial3D.CULL_DISABLED
func _solid_box(at: Vector3,size_: Vector3,group: String="harbor_plaza_prop") -> StaticBody3D:
 var body:=StaticBody3D.new();body.name="PlazaCollision"+str(_collider_id);_collider_id+=1;body.position=at;body.collision_layer=1;body.add_to_group(group)
 var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size_;collision.shape=shape;body.add_child(collision);add_child(body)
 return body
func _box(at: Vector3,size_: Vector3,mat: Material,solid: bool=false,group: String="harbor_plaza_prop") -> void:
 main.box(at,size_,mat)
 if solid:_solid_box(at,size_,group)
func _solid_cylinder(at: Vector3,radius: float,height: float,group: String="harbor_plaza_prop") -> void:
 var body:=StaticBody3D.new();body.name="PlazaRoundCollision"+str(_collider_id);_collider_id+=1;body.position=at;body.collision_layer=1;body.add_to_group(group)
 var collision:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=radius;shape.height=height;collision.shape=shape;body.add_child(collision);add_child(body)
func _ground() -> void:
 # The paving is decoration over the same continuous collision top, never raised
 # stepping stones. The connector overlaps each end, eliminating a seam gap.
 for rect in [Profile.PLAZA_RECT,Profile.CONNECTOR_RECT]:
  var center: Vector2=rect.get_center()
  _solid_box(Vector3(center.x,Profile.CAFE.y-.55,center.y),Vector3(rect.size.x,1.1,rect.size.y),"harbor_plaza_ground")
  # Keep physics flush while the visual backing sits below recessed grout.
  main.box(Vector3(center.x,Profile.CAFE.y-.565,center.y),Vector3(rect.size.x,1.1,rect.size.y),materials.stone)
 var rect: Rect2=Profile.PLAZA_RECT
 var random:=RandomNumberGenerator.new();random.seed=8851
 for row in 40:
  var z: float=rect.position.y+.46+row*.93
  if z>rect.end.y-.2:continue
  for col in 33:
   var x: float=rect.position.x+.46+col*.94
   if x>rect.end.x-.2:continue
   # The authored goods lane has its own smaller flush cobbles.
   var road: Rect2=LoadingStreet.ROAD_RECT.merge(Profile.ROAD_JOIN_RECT)
   var color_: Material=materials.paving if random.randf()>.24 else materials.stone
   var tile:=Rect2(Vector2(x-.45,z-.445),Vector2(.90,.89)).intersection(rect)
   _paving_without_road(tile,road,color_)
 # A darker double-line border and a thin warm stripe organize the broad square.
 for x in [rect.position.x+.18,rect.end.x-.18]:
  if x< -49.5:continue # The new dressed-tile border owns the whole west seam.
  var start: float=rect.position.y+.3
  var end: float=6.3 if x< -49.5 else rect.end.y-.3
  main.box(Vector3(x,Profile.CAFE.y+.001,(start+end)*.5),Vector3(.16,.012,end-start),materials.stone2)
 for z in [rect.position.y+.18,rect.end.y-.18]:
  main.box(Vector3(rect.get_center().x,Profile.CAFE.y+.001,z),Vector3(rect.size.x-.4,.012,.16),materials.stone2)
 for i in 10:
  var at:=Vector3(-46.8+i*2.72,Profile.CAFE.y+.006,3.8)
  main.box(at,Vector3(2.65,.01,.10),materials.cream)
 # Radial stone inlay surrounds the basin while leaving it visually low.
 for i in 48:
  var angle: float=TAU*i/48;var radial:=Vector3(cos(angle),0,sin(angle))
  main.box(Profile.FOUNTAIN+radial*2.62+Vector3.UP*.005,Vector3(.29,.012,.22),materials.cream,Vector3(0,-angle,0))
 # Drains lie flush at the rear and beside the cafe; narrow slots are human scale.
 for at in [Vector3(-40.1,Profile.CAFE.y,-13.4),Vector3(-23,Profile.CAFE.y,-13.4),Vector3(-20.9,Profile.CAFE.y,13.7)]:
  main.box(at,Vector3(.55,.012,.29),materials.stone2)
  for i in 7:main.box(at+Vector3(-.21+i*.07,.009,0),Vector3(.025,.008,.21),materials.iron)
func _paving_without_road(tile: Rect2,road: Rect2,mat: Material) -> void:
 var pieces: Array[Rect2]=[tile]
 for excluded in [road,Profile.PROMENADE_WEST_RECT,Profile.PROMENADE_FRONT_RECT]:
  var remaining: Array[Rect2]=[]
  for piece in pieces:
   if not piece.intersects(excluded):remaining.append(piece);continue
   var cut: Rect2=piece.intersection(excluded)
   remaining.append(Rect2(piece.position,Vector2(cut.position.x-piece.position.x,piece.size.y)))
   remaining.append(Rect2(Vector2(cut.end.x,piece.position.y),Vector2(piece.end.x-cut.end.x,piece.size.y)))
   remaining.append(Rect2(Vector2(cut.position.x,piece.position.y),Vector2(cut.size.x,cut.position.y-piece.position.y)))
   remaining.append(Rect2(Vector2(cut.position.x,cut.end.y),Vector2(cut.size.x,piece.end.y-cut.end.y)))
  pieces=remaining
 for piece in pieces:
  if piece.size.x<.002 or piece.size.y<.002:continue
  var center: Vector2=piece.get_center()
  main.box(Vector3(center.x,Profile.CAFE.y-.016,center.y),Vector3(piece.size.x,.031,piece.size.y),mat)
func _cafe() -> void:
 # A two-storey cafe entirely behind the terrace and west of the old warehouse.
 var at:=Vector3(-46,Profile.CAFE.y,-19.6)
 _box(at+Vector3.UP*3.55,Vector3(10,7.1,7.8),materials.cream,true,"harbor_plaza_building")
 _box(at+Vector3(0,.28,3.96),Vector3(10.2,.56,.25),materials.stone)
 for y in [3.0,6.7,7.12]:main.box(at+Vector3(0,y,4.0),Vector3(10.4,.18,.32),materials.cream)
 # Vertical corner quoins and framed sash windows give the frontage a civic scale.
 for x in [-4.91,4.91]:
  for y in 13:main.box(at+Vector3(x,.54+y*.48,3.99),Vector3(.39,.40,.22),materials.stone)
 for x in [-3.65,-1.25,1.25,3.65]:
  _window(at+Vector3(x,4.94,3.97),Vector2(1.43,2.0),true)
  if absf(x)>2:
   _window(at+Vector3(x,1.65,3.98),Vector2(1.82,2.12),false)
   main.box(at+Vector3(x,2.84,4.04),Vector3(2.08,.14,.32),materials.stone)
 # Recessed closed glass entrance; the facade remains a physical building.
 main.box(at+Vector3(0,1.32,4.01),Vector3(1.84,2.65,.14),materials.darkwood)
 main.box(at+Vector3(0,1.52,4.10),Vector3(1.57,1.85,.05),materials.window)
 for x in [-.46,.46]:
  main.box(at+Vector3(x,1.52,4.145),Vector3(.055,1.87,.035),materials.cream)
  main.cylinder(at+Vector3(x*.20,1.18,4.18),.032,.10,materials.gold,8)
 main.box(at+Vector3(0,.43,4.13),Vector3(1.6,.43,.05),materials.teal)
 # Hipped slate roof, complete returns and two dormers.
 main.quad(at+Vector3(-5.35,7.18,4.35),at+Vector3(5.35,7.18,4.35),at+Vector3(4.10,8.7,0),at+Vector3(-4.10,8.7,0),materials.slate)
 main.quad(at+Vector3(5.35,7.18,-4.35),at+Vector3(-5.35,7.18,-4.35),at+Vector3(-4.10,8.7,0),at+Vector3(4.10,8.7,0),materials.slate)
 for side in [-1.0,1.0]:
  main.quad(at+Vector3(side*5.35,7.18,-4.35),at+Vector3(side*5.35,7.18,4.35),at+Vector3(side*4.10,8.7,0),at+Vector3(side*4.10,8.7,0),materials.slate)
 main.beam(at+Vector3(-4.1,8.72,0),at+Vector3(4.1,8.72,0),.13,materials.iron)
 for x in [-2.5,2.5]:
  main.box(at+Vector3(x,7.65,2.60),Vector3(1.3,.97,.45),materials.cream)
  _window(at+Vector3(x,7.66,2.85),Vector2(.75,.72),false)
  main.box(at+Vector3(x,8.18,2.6),Vector3(1.5,.12,.72),materials.slate)
 for x in [-4.0,3.8]:
  main.box(at+Vector3(x,8.45,-1.55),Vector3(.62,1.7,.72),materials.brick)
  main.box(at+Vector3(x,9.33,-1.55),Vector3(.80,.16,.88),materials.stone2)
 # Shop awning hangs against the building, well behind the hero camera sightline.
 for i in 20:
  var x: float=-5.04+i*.51
  var color_: Material=materials.canvas if i%2==0 else materials.teal
  main.quad(at+Vector3(x,3.03,4.05),at+Vector3(x+.53,3.03,4.05),at+Vector3(x+.53,2.74,5.30),at+Vector3(x,2.74,5.30),color_)
  main.box(at+Vector3(x+.255,2.65,5.30),Vector3(.53,.18,.045),color_)
 _sign(at+Vector3(0,3.43,4.18),"CAFÉ  DU  PORT",26,Vector2(6.1,.59),materials.teal)
 # The main table and chair keep v84's exact relative cup and saucer contact.
 _table(Profile.CAFE+Vector3(1.05,0,.15))
 _chair(Profile.CAFE+Vector3(0,0,-.15),false)
 departure_chair=_solid_box(Profile.CAFE+Vector3(0,.43,-.31),Vector3(.52,.86,.72),"harbor_departure_chair")
 departure_chair.name="DepartureChairSafeExit";departure_chair.collision_layer=0
 _parasol(Profile.CAFE+Vector3(-.45,0,-.73),1.96,3.25,materials.teal)
 # The paired seated guests own this table and its opposing chairs in Life.
 _parasol(Profile.CAFE+Vector3(-4.45,0,.10),1.45,2.98,materials.red)
 _table(Profile.CAFE+Vector3(-1.2,0,-3.7));_chair(Profile.CAFE+Vector3(-2.1,0,-3.8));_chair(Profile.CAFE+Vector3(-.4,0,-3.6))
 # The same authored suitcase leaves this floor position with the traveller.
 travel_luggage=TravelLuggage.new();travel_luggage.name="TravellerLuggage";travel_luggage.materials=materials.duplicate();add_child(travel_luggage)
 main.cylinder(Profile.SAUCER,.145,.025,materials.cream,24)
 cup=Detail.new();cup.name="CoffeeCup";cup.position=Profile.CUP_REST;add_child(cup)
 cup.cylinder(Vector3.ZERO,.073,.13,materials.cream,24,.091)
 cup.cylinder(Vector3(0,.068,0),.076,.005,materials.coffee,24)
 var cup_handle: Array[Vector3]=[Vector3(-.07,.04,0),Vector3(-.16,.04,0),Vector3(-.18,-.03,0),Vector3(-.08,-.04,0)]
 cup.tube(cup_handle,.018,materials.cream,.9);cup.finish()
 main.beam(Profile.CAFE+Vector3(1.18,.485,-.15),Profile.CAFE+Vector3(1.06,.485,-.05),.02,materials.iron)
 for point in [Vector3(-49.8,0,-11.8),Vector3(-40.8,0,-13.7),Vector3(-49.5,0,-5.2)]:_planter(point+Vector3.UP*Profile.CAFE.y,.40,.68)
 # Chalkboard sits safely against the shop rather than in the hero's path.
 var board:=Vector3(-41.7,Profile.CAFE.y,-14.15)
 _box(board+Vector3.UP*.62,Vector3(.63,1.24,.36),materials.darkwood,true)
 main.box(board+Vector3(0,.68,.20),Vector3(.51,.95,.035),materials.iron)
 _label(board+Vector3(0,.82,.225),"CAFÉ\nTHÉ\nPAIN",15,.007,Color("efe0b8"))
func update_departure_chair(player_position: Vector3,active: bool) -> void:
 if not active:departure_chair.collision_layer=0;return
 if departure_chair.collision_layer!=0:return
 # Initial capsule overlaps its own seated chair. Once outside, the visible
 # chair becomes solid for every later approach until the next menu replay.
 var seat:=Rect2(Vector2(Profile.CAFE.x-.26,Profile.CAFE.z-.67),Vector2(.52,.72)).grow(.29)
 if not seat.has_point(Vector2(player_position.x,player_position.z)):departure_chair.collision_layer=1
func _window(at: Vector3,size_: Vector2,shutters: bool) -> void:
 main.box(at,Vector3(size_.x+.19,size_.y+.18,.15),materials.stone)
 main.box(at+Vector3(0,0,.10),Vector3(size_.x,size_.y,.045),materials.darkwood)
 main.box(at+Vector3(0,0,.14),Vector3(size_.x-.12,size_.y-.12,.035),materials.window)
 main.box(at+Vector3(0,0,.17),Vector3(.065,size_.y,.025),materials.cream)
 for y in [-size_.y*.19,size_.y*.20]:main.box(at+Vector3(0,y,.18),Vector3(size_.x,.055,.025),materials.cream)
 main.box(at+Vector3(0,-size_.y*.5-.07,.11),Vector3(size_.x+.36,.13,.39),materials.stone)
 if shutters:
  for side in [-1.0,1.0]:
   main.box(at+Vector3(side*(size_.x*.5+.30),0,.08),Vector3(.42,size_.y+.12,.08),materials.teal)
   for i in 8:main.box(at+Vector3(side*(size_.x*.5+.30),-size_.y*.42+i*size_.y*.12,.133),Vector3(.34,.045,.025),materials.darkwood)
func _rear_frontage() -> void:
 # Shallow civic facades close the square without entering the original warehouse.
 for i in 2:
  var x: float=-37.0+i*6
  var height: float=6.05+(.5 if i==1 else 0)
  _box(Vector3(x,Profile.CAFE.y+height*.5,-20.45),Vector3(5.86,height,.86),materials.brick if i==1 else materials.stone,true,"harbor_plaza_building")
  for y in [.28,3.25,height-.20]:main.box(Vector3(x,Profile.CAFE.y+y,-19.97),Vector3(6.0,.17,.26),materials.cream)
  for side in [-1.0,1.0]:
   _window(Vector3(x+side*1.45,Profile.CAFE.y+4.70,-19.96),Vector2(1.36,1.57),true)
   main.box(Vector3(x+side*2.82,Profile.CAFE.y+height*.5,-19.95),Vector3(.22,height,.18),materials.cream)
  # Closed timber shutters behind each working stall make the rear physically clear.
  main.box(Vector3(x,Profile.CAFE.y+1.45,-19.96),Vector3(3.8,2.6,.10),materials.darkwood)
  for j in 9:main.box(Vector3(x-1.7+j*.425,Profile.CAFE.y+1.45,-19.88),Vector3(.025,2.45,.035),materials.wood)
  main.box(Vector3(x,Profile.CAFE.y+height+.13,-20.45),Vector3(6.12,.24,1.25),materials.slate)
  _sign(Vector3(x,Profile.CAFE.y+3.04,-19.76),["BOULANGERIE","FLEURS & HERBES","CÉRAMIQUE"][i],16,Vector2(3.8,.37),materials.teal)
func _market() -> void:
 for i in 2:
  var at:=Vector3(-37.0+i*6,Profile.CAFE.y,-18.2)
  var color_: Material=[materials.red,materials.teal,materials.gold][i]
  # Enclosed back/side panels and the complete front counter share their meshes'
  # dimensions with collision, eliminating the walk-through tents of scenery.
  _box(at+Vector3(0,.78,-1.43),Vector3(3.62,1.56,.14),materials.darkwood,true,"harbor_plaza_stall")
  for side in [-1.0,1.0]:
   _box(at+Vector3(side*1.74,.73,-.40),Vector3(.14,1.46,2.20),materials.wood,true,"harbor_plaza_stall")
   main.cylinder(at+Vector3(side*1.74,1.49,.98),.048,2.98,materials.darkwood,12)
  _box(at+Vector3(0,.55,.95),Vector3(3.35,1.10,.70),materials.wood,true,"harbor_plaza_stall")
  for row in 3:main.box(at+Vector3(0,.17+row*.29,1.32),Vector3(3.38,.23,.055),materials.darkwood)
  for x in [-1.52,1.52]:main.box(at+Vector3(x,.55,1.36),Vector3(.10,1.1,.05),materials.gold)
  for stripe in 10:
   var x: float=-1.96+stripe*.392
   var stripe_mat: Material=materials.canvas if stripe%2 else color_
   main.quad(at+Vector3(x,3.0,-1.5),at+Vector3(x+.405,3.0,-1.5),at+Vector3(x+.405,2.67,1.38),at+Vector3(x,2.67,1.38),stripe_mat)
   main.box(at+Vector3(x+.196,2.56,1.38),Vector3(.405,.22,.04),stripe_mat)
  for item in 10:
   var at_item: Vector3=at+Vector3(-1.30+(item%5)*.63,1.16,.73+floorf(item/5.0)*.37)
   if i==0:
    main.boulder(at_item,Vector3(.41,.19,.22),materials.gold,8910+item)
    for cut in 3:main.box(at_item+Vector3(-.10+cut*.10,.083,.02),Vector3(.027,.012,.11),materials.cream,Vector3(0,.45,0))
   elif i==1:
    main.cylinder(at_item+Vector3.UP*.02,.095,.20,materials.clay,10,.12)
    for stem in 3:
     var top: Vector3=at_item+Vector3((stem-1)*.07,.34+float(item%3)*.035,.02)
     main.beam(at_item+Vector3.UP*.1,top,.014,materials.leaves)
     main.boulder(top,Vector3(.13,.12,.13),materials.flower if item%2 else materials.flower2,8930+item*3+stem)
   else:
    main.cylinder(at_item,.12,.25,materials.clay if item%2 else materials.teal,12,.085)
    main.cylinder(at_item+Vector3.UP*.14,.09,.025,materials.cream,12)
  # Modest baskets and a price slate sit outside the clear east/west front walk.
  _planter(at+Vector3(-2.18,0,1.1),.27,.43)
  _box(at+Vector3(1.28,1.23,1.31),Vector3(.32,.24,.04),materials.iron)
func _table(at: Vector3) -> void:
 main.cylinder(at+Vector3.UP*.46,.7,.08,materials.wood,32)
 main.cylinder(at+Vector3.UP*.23,.055,.43,materials.iron)
 for i in 3:
  var direction:=Vector3(cos(TAU*i/3),0,sin(TAU*i/3));main.beam(at+Vector3.UP*.22,at+direction*.4+Vector3.UP*.04,.05,materials.iron)
 _solid_cylinder(at+Vector3.UP*.25,.70,.50,"harbor_plaza_table")
func _chair(at: Vector3,solid: bool=true) -> void:
 main.cylinder(at+Vector3.UP*.27,.27,.06,materials.wood)
 for x in [-.19,.19]:
  for z in [-.18,.18]:main.beam(at+Vector3(x,.28,z),at+Vector3(x*.9,.02,z*.9),.045,materials.darkwood)
  main.beam(at+Vector3(x,.25,-.2),at+Vector3(x,.87,-.65),.035,materials.darkwood)
 for y in [.56,.74]:main.box(at+Vector3(0,y,-.2-(y-.25)*.72),Vector3(.43,.1,.05),materials.wood)
 if solid:_solid_box(at+Vector3(0,.43,-.16),Vector3(.52,.86,.72))
func _parasol(at: Vector3,radius: float,height: float,color_: Material) -> void:
 main.cylinder(at+Vector3.UP*(height*.5),.034,height,materials.iron,12)
 main.cylinder(at+Vector3.UP*.04,.23,.08,materials.stone2,16)
 _solid_cylinder(at+Vector3.UP*(height*.5),.045,height,"harbor_plaza_parasol_pole")
 for i in 16:
  var a: float=TAU*i/16;var b: float=TAU*(i+1)/16
  var da:=Vector3(cos(a),0,sin(a));var db:=Vector3(cos(b),0,sin(b))
  var material_: Material=color_ if i%2==0 else materials.canvas
  main.quad(at+Vector3.UP*(height+.30),at+da*radius*.55+Vector3.UP*(height+.13),at+db*radius*.55+Vector3.UP*(height+.13),at+Vector3.UP*(height+.30),material_)
  main.quad(at+da*radius*.55+Vector3.UP*(height+.13),at+da*radius+Vector3.UP*(height-.11),at+db*radius+Vector3.UP*(height-.11),at+db*radius*.55+Vector3.UP*(height+.13),material_)
  main.quad(at+da*radius+Vector3.UP*(height-.11),at+da*radius+Vector3.UP*(height-.26),at+db*radius+Vector3.UP*(height-.26),at+db*radius+Vector3.UP*(height-.11),material_)
  main.beam(at+Vector3.UP*(height+.27),at+da*radius+Vector3.UP*(height-.12),.017,materials.wood)
 main.cylinder(at+Vector3.UP*(height+.34),.055,.12,materials.gold,12,.025)
func _planter(at: Vector3,radius: float,height: float) -> void:
 main.cylinder(at+Vector3.UP*height*.5,radius*.76,height,materials.clay,16,radius)
 main.cylinder(at+Vector3.UP*(height-.025),radius*.93,.05,materials.soil,16)
 for i in 7:
  var a: float=TAU*i/7;var top: Vector3=at+Vector3(cos(a)*radius*.6,height+.22+float(i%3)*.08,sin(a)*radius*.6)
  main.boulder(top,Vector3(.23,.53,.23),materials.leaves,8890+i)
  if i%2==0:main.boulder(top+Vector3.UP*.21,Vector3(.13,.13,.13),materials.flower,8880+i)
 _solid_cylinder(at+Vector3.UP*height*.5,radius,height)
func _bench(at: Vector3,rotation_: float=0) -> void:
 var basis:=Basis(Vector3.UP,rotation_)
 for i in 4:main.box(at+basis*Vector3(0,.43,-.20+i*.13),Vector3(2.1,.085,.10),materials.wood,Vector3(0,rotation_,0))
 for y in [.71,.92]:main.box(at+basis*Vector3(0,y,-.32),Vector3(2.1,.12,.075),materials.wood,Vector3(0,rotation_,0))
 for x in [-.82,.82]:
  main.beam(at+basis*Vector3(x,.08,.25),at+basis*Vector3(x,.47,.22),.075,materials.iron)
  main.beam(at+basis*Vector3(x,.08,-.25),at+basis*Vector3(x,1.02,-.35),.075,materials.iron)
  main.beam(at+basis*Vector3(x,.65,-.29),at+basis*Vector3(x,.65,.26),.045,materials.iron)
 # These benches use cardinal rotations, so their physical boxes fit the slats.
 _solid_box(at+basis*Vector3(0,.51,-.06),Vector3(.74,1.02,2.18) if absf(sin(rotation_))>.5 else Vector3(2.18,1.02,.74),"harbor_plaza_bench")
func _lamp(at: Vector3) -> void:
 main.cylinder(at+Vector3.UP*.12,.18,.24,materials.iron,12,.12)
 main.cylinder(at+Vector3.UP*1.73,.048,3.20,materials.iron,12,.035)
 main.cylinder(at+Vector3.UP*3.26,.17,.13,materials.iron,12,.23)
 main.box(at+Vector3.UP*3.55,Vector3(.29,.48,.29),materials.canvas)
 for x in [-.17,.17]:
  for z in [-.17,.17]:main.beam(at+Vector3(x,3.25,z),at+Vector3(x*.75,3.82,z*.75),.028,materials.iron)
 main.cylinder(at+Vector3.UP*3.86,.25,.19,materials.iron,4,.045)
 main.cylinder(at+Vector3.UP*4.02,.045,.16,materials.gold,8,.015)
 # Native pole collision is explicitly grouped for layout/physical inspection.
 var body:=StaticBody3D.new();body.name="PromenadeLamp"+str(_collider_id);_collider_id+=1;body.position=at+Vector3.UP*1.7;body.collision_layer=1
 body.add_to_group("harbor_plaza_lamp");body.set_meta("ground_datum",at);body.set_meta("furniture_line","public_promenade")
 var collision:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=.09;shape.height=3.4;collision.shape=shape;body.add_child(collision);add_child(body)
func _square_furniture() -> void:
 # A continuous furniture band belongs to the public promenade, ahead of the
 # road. Regular lamp spacing and cardinal bench axes make the plan legible.
 for at in [Vector3(-46.6,Profile.CAFE.y,2.5),Vector3(-36.2,Profile.CAFE.y,2.5),Vector3(-28.1,Profile.CAFE.y,2.5)]:_bench(at)
 _bench(Vector3(-21.4,Profile.CAFE.y,-7.6),PI*.5)
 for at in [Vector3(-49.7,Profile.CAFE.y,2.5),Vector3(-38.8,Profile.CAFE.y,2.5),Vector3(-30.7,Profile.CAFE.y,2.5),Vector3(-21.3,Profile.CAFE.y,-10.8)]:_planter(at,.52,.72)
 for x in [-48.5,-39.5,-30.5,-21.5]:_lamp(Vector3(x,Profile.CAFE.y,4.8))
func _new_person(id: String,index: int,path: Array[Vector3],working: bool=false,coat: String="6b8390",carry: bool=false) -> void:
 var person=NPC.new();person.name=id
 person.profile={"id":id,"hairstyle":index%10,"male":index%2==0,"hair":Appearance.HAIR[index%10],"skin":Appearance.SKIN[(index*3)%10],"coat":coat,"cap":false,"phase":index,"apron":working and index<3,"carry":carry}
 person.route=path;person.work=working;person.speed=.65+float(index%3)*.09
 add_child(person);people.append(person)
func _living_square() -> void:
 var y: float=Profile.CAFE.y
 for i in 2:
  _new_person(["PlazaBaker","PlazaFlorist","PlazaPotter"][i],i,[Vector3(-37+i*6,y,-18.55)],true,["96715a","6b886a","9d7462"][i])
 # Patrol loops stay on pavement, never cut through the basin, terraces or props.
 _new_person("CafeWaiter",3,[Vector3(-40.3,y,-12.9),Vector3(-39.1,y,-12.9),Vector3(-39.1,y,-7),Vector3(-40.3,y,-7)],true,"7d6b62",true)
 _new_person("PlazaPromenader",4,[Vector3(-38.2,y,-4.6),Vector3(-26.3,y,-4.6)],false,"6d8189")
 _new_person("FlowerCustomer",5,[Vector3(-30,y,-15.45)],false,"9b788c")
 _new_person("PlazaMessenger",6,[Vector3(-25,y,2.0),Vector3(-25,y,10.7)],false,"788366",true)
 _new_person("PlazaSweeper",8,[Vector3(-46,y,8.2),Vector3(-43,y,8.2)],true,"738b84")
 people[-1].profile.broom=true
 _new_person("FountainVisitor",9,[Vector3(-28.4,y,-10.4),Vector3(-27.5,y,-6.2)],false,"9a7b68")
 for i in 2:people[i].aim=Vector3.BACK
 for person in people:
  if person.name=="FlowerCustomer":person.aim=Vector3.FORWARD
 var homes: Array[Vector3]=[Vector3(-37,y,-6.5),Vector3(-34.4,y,-4.9),Vector3(-30.2,y,.6),Vector3(-43.3,y,5.8)]
 for i in homes.size():
  var bird=Pigeon.new();bird.name="PlazaPigeon"+str(i);bird.home=homes[i];bird.phase=1.3+i*2.8;add_child(bird);birds.append(bird)
func _sign(at: Vector3,text_: String,font_size_: int,size_: Vector2,mat: Material) -> void:
 main.box(at,Vector3(size_.x,size_.y,.055),mat)
 _label(at+Vector3(0,0,.036),text_,font_size_,.006,Color("f4e6c7"))
func _label(at: Vector3,text_: String,font_size_: int,pixel_: float,color_: Color) -> void:
 var label:=Label3D.new();label.text=text_;label.font_size=font_size_;label.pixel_size=pixel_;label.position=at;label.modulate=color_;label.outline_size=2;label.no_depth_test=false;add_child(label)
func tick(delta: float,camera: Camera3D,clock: float) -> void:
 fountain.tick(delta,camera,clock)
 var positions: Array[Vector3]=[]
 for person in people:
  person.tick(delta,camera,clock);positions.append(person.position)
 for bird in birds:bird.tick(delta,camera,clock,positions)
