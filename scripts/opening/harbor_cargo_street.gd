extends Node3D
## Covered warehouse delivery scene. Props and its two native porters have one
## local owner; the existing scenic street, player boundary and look RNG stay owned
## by the surrounding harbor. No automatic process duplicates World's tick.
const Detail=preload("res://scripts/opening/harbor_detail.gd")
const NPC=preload("res://scripts/opening/harbor_npc.gd")
const WAGON_AT:=Vector3(-59.8,.055,-11.5)
var materials: Dictionary={}
var geometry_count:=0
var workers: Array=[]
var wagon_bounds:=AABB()
var cargo_bounds: Dictionary={}
var main
var props_geometry
var _draw
var _collider_id:=0
var _wagon_bodies: Array[PhysicsBody3D]=[]
var _pile_bodies: Dictionary={"west_pile":[],"north_pile":[]}
func _ready() -> void:
 name="HarborCargoStreet"
 for entry in [["delivery_wood","947255","wood"],["delivery_darkwood","5d4c3e","wood"],["delivery_iron","465350","iron"],["delivery_canvas","d1c19d","plaster"],["delivery_canvas_shade","baaa88","plaster"],["delivery_rope","bba77b","wood"],["delivery_sack","b9ab88","plaster"],["delivery_gold","b99a62","wood"]]:
  if not materials.has(entry[0]):materials[entry[0]]=Detail.material(entry[1],entry[2],9710+materials.size())
 materials.delivery_canvas.cull_mode=BaseMaterial3D.CULL_DISABLED
 materials.delivery_canvas_shade.cull_mode=BaseMaterial3D.CULL_DISABLED
 main=Detail.new();main.name="CoveredDeliveryWagonGeometry";add_child(main);_draw=main;_wagon();main.finish()
 props_geometry=Detail.new();props_geometry.name="StreetDeliveryCargoGeometry";add_child(props_geometry);_draw=props_geometry;_cargo_piles();props_geometry.finish()
 wagon_bounds=_bounds(_wagon_bodies)
 for id in _pile_bodies:cargo_bounds[id]=_bounds(_pile_bodies[id])
 geometry_count=main.count+props_geometry.count
 _workers()
func _body(label: String,at: Vector3,shape: Shape3D,pile: String="") -> StaticBody3D:
 var body:=StaticBody3D.new();body.name=label+str(_collider_id);_collider_id+=1;body.position=at;body.collision_layer=1;body.collision_mask=3
 body.add_to_group("harbor_delivery_wagon" if pile.is_empty() else "harbor_delivery_cargo")
 body.set_meta("delivery_prop",label)
 var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);add_child(body)
 if pile.is_empty():_wagon_bodies.append(body)
 else:body.set_meta("cargo_cluster",pile);_pile_bodies[pile].append(body)
 return body
func _box(at: Vector3,size_: Vector3,mat: Material,label: String,pile: String="") -> void:
 _draw.box(at,size_,mat)
 var shape:=BoxShape3D.new();shape.size=size_;_body(label,at,shape,pile)
func _bounds(bodies: Array) -> AABB:
 var result:=AABB();var first:=true
 for body in bodies:
  var collision: CollisionShape3D=body.get_child(0)
  var part: AABB=body.transform*collision.transform*collision.shape.get_debug_mesh().get_aabb()
  result=part if first else result.merge(part);first=false
 return result
func _wheel(at: Vector3) -> void:
 var ring: Array[Vector3]=[]
 for i in 25:
  var angle: float=TAU*i/24;ring.append(at+Vector3(0,cos(angle)*.60,sin(angle)*.60))
 _draw.tube(ring,.045,materials.delivery_iron,1)
 for side in [-1.0,1.0]:
  var inner: Array[Vector3]=[]
  for i in 25:
   var angle: float=TAU*i/24;inner.append(at+Vector3(side*.055,cos(angle)*.545,sin(angle)*.545))
  _draw.tube(inner,.038,materials.delivery_wood,1)
 for i in 12:
  var angle: float=TAU*i/12;_draw.beam(at,at+Vector3(0,cos(angle)*.55,sin(angle)*.55),.045,materials.delivery_darkwood)
 _draw.beam(at+Vector3(-.11,0,0),at+Vector3(.11,0,0),.15,materials.delivery_iron)
 var shape:=CylinderShape3D.new();shape.radius=.645;shape.height=.22
 var body:=_body("CoveredWagonWheel",at,shape);body.rotation.z=PI*.5
func _wagon() -> void:
 var at:=WAGON_AT
 for z in [-1.55,1.55]:
  main.beam(at+Vector3(-1.10,.65,z),at+Vector3(1.10,.65,z),.14,materials.delivery_iron)
  for side in [-1.0,1.0]:
   _wheel(at+Vector3(side*1.03,.65,z))
   for layer in 3:main.beam(at+Vector3(side*.70,.78+layer*.045,z-.49),at+Vector3(side*.70,.78+layer*.045,z+.49),.042,materials.delivery_iron)
 for side in [-1.0,1.0]:main.box(at+Vector3(side*.73,.83,0),Vector3(.17,.19,4.70),materials.delivery_darkwood)
 _box(at+Vector3.UP*.96,Vector3(2,.36,4.8),materials.delivery_darkwood,"CoveredWagonBed")
 for board in 12:main.box(at+Vector3(0,1.16,-2.2+board*.4),Vector3(2.02,.10,.38),materials.delivery_wood)
 for side in [-1.0,1.0]:
  for row in 2:main.box(at+Vector3(side*1.01,1.31+row*.18,0),Vector3(.09,.15,4.72),materials.delivery_wood)
  for z in [-2.25,-1.1,0,1.1,2.25]:main.box(at+Vector3(side*1.055,1.34,z),Vector3(.035,.50,.075),materials.delivery_iron)
 # Canvas is a full arched cover with open loading ends, not a rectangular roof.
 var canopy_points:=PackedVector3Array()
 for z in [-2.15,2.15]:
  for i in 13:
   var angle: float=PI*i/12
   canopy_points.append(Vector3(cos(angle)*1.05,1.65+sin(angle)*1.05,z))
  canopy_points.append(Vector3(-1.05,1.12,z));canopy_points.append(Vector3(1.05,1.12,z))
 var canopy_shape:=ConvexPolygonShape3D.new();canopy_shape.points=canopy_points;_body("CoveredWagonCanvas",at,canopy_shape)
 for i in 12:
  var a: float=PI*i/12;var b: float=PI*(i+1)/12
  var p:=Vector3(cos(a)*1.05,1.65+sin(a)*1.05,0);var q:=Vector3(cos(b)*1.05,1.65+sin(b)*1.05,0)
  main.quad(at+p+Vector3(0,0,-2.15),at+p+Vector3(0,0,2.15),at+q+Vector3(0,0,2.15),at+q+Vector3(0,0,-2.15),materials.delivery_canvas_shade if i%4==0 else materials.delivery_canvas)
 for side in [-1.0,1.0]:
  main.quad(at+Vector3(side*1.05,1.12,-2.15),at+Vector3(side*1.05,1.65,-2.15),at+Vector3(side*1.05,1.65,2.15),at+Vector3(side*1.05,1.12,2.15),materials.delivery_canvas)
  for z in [-1.7,-.55,.55,1.7]:
   main.beam(at+Vector3(side*1.075,1.35,z),at+Vector3(side*1.08,.94,z+.17),.018,materials.delivery_rope)
 for z in [-2.15,-1.06,0,1.06,2.15]:
  var arch: Array[Vector3]=[]
  for i in 17:
   var angle: float=PI*i/16;arch.append(at+Vector3(cos(angle)*1.063,1.65+sin(angle)*1.063,z))
  main.tube(arch,.030,materials.delivery_darkwood,1)
 # A restrained visible load and rear step support the delivery activity.
 _crate(at+Vector3(-.40,1.49,1.48),Vector3(.75,.56,.82))
 _sack(at+Vector3(.43,1.47,1.42),Vector3(.70,.55,.81),9723)
 _box(at+Vector3(0,.63,2.50),Vector3(1.2,.12,.38),materials.delivery_darkwood,"CoveredWagonRearStep")
 # Unhitched shafts rest on their own narrow trestle; no horse/driver scope.
 for side in [-1.0,1.0]:
  _box(at+Vector3(side*.65,.75,-3.15),Vector3(.08,.08,1.50),materials.delivery_darkwood,"CoveredWagonShaft")
  _box(at+Vector3(side*.65,.38,-3.62),Vector3(.08,.76,.08),materials.delivery_wood,"CoveredWagonShaftRest")
 _box(at+Vector3(0,.69,-3.62),Vector3(1.42,.10,.09),materials.delivery_wood,"CoveredWagonShaftCrossrest")
func _crate(at: Vector3,size_: Vector3,pile: String="") -> void:
 _box(at,size_,materials.delivery_wood,"DeliveryCrate",pile)
 for side in [-1.0,1.0]:
  for x in [-size_.x*.39,size_.x*.39]:_draw.box(at+Vector3(x,0,side*(size_.z*.5+.023)),Vector3(.055,size_.y,.040),materials.delivery_darkwood)
  _draw.beam(at+Vector3(-size_.x*.4,-size_.y*.38,side*(size_.z*.5+.046)),at+Vector3(size_.x*.4,size_.y*.38,side*(size_.z*.5+.046)),.035,materials.delivery_darkwood)
 for row in 3:_draw.box(at+Vector3(0,-size_.y*.26+row*size_.y*.26,size_.z*.5+.01),Vector3(size_.x,.018,.014),materials.delivery_darkwood)
func _barrel(at: Vector3,radius: float,height: float,pile: String) -> void:
 _draw.cylinder(at+Vector3.UP*height*.5,radius,height,materials.delivery_wood,16)
 for y in [.11,height*.32,height*.75,height-.10]:_draw.cylinder(at+Vector3.UP*y,radius+.014,.045,materials.delivery_iron,16)
 _draw.cylinder(at+Vector3.UP*(height+.012),radius*.84,.024,materials.delivery_darkwood,16)
 var shape:=CylinderShape3D.new();shape.radius=radius+.014;shape.height=height+.024;_body("DeliveryBarrel",at+Vector3.UP*(height+.024)*.5,shape,pile)
func _sack(at: Vector3,size_: Vector3,seed_: int,pile: String="") -> void:
 _draw.boulder(at,size_,materials.delivery_sack,seed_)
 _draw.cylinder(at+Vector3.UP*(size_.y*.45),.055,.08,materials.delivery_sack,8,.035)
 var shape:=BoxShape3D.new();shape.size=size_*.94;_body("DeliverySack",at,shape,pile)
func _cargo_piles() -> void:
 _crate(Vector3(-62.2,.455,-4.35),Vector3(.95,.80,.90),"west_pile")
 _crate(Vector3(-62.2,1.105,-4.35),Vector3(.72,.50,.72),"west_pile")
 _barrel(Vector3(-63.15,.055,-4.55),.32,.90,"west_pile")
 _sack(Vector3(-61.5,.345,-4.45),Vector3(.60,.58,.63),9731,"west_pile")
 _crate(Vector3(-59.05,.455,-19.25),Vector3(1.05,.80,.90),"north_pile")
 _crate(Vector3(-59.05,1.055,-19.25),Vector3(.72,.40,.70),"north_pile")
 _barrel(Vector3(-60.15,.055,-19.15),.34,.88,"north_pile")
 _sack(Vector3(-58.7,.325,-20.05),Vector3(.62,.54,.60),9732,"north_pile")
func _workers() -> void:
 var profiles: Array[Dictionary]=[
  {"id":"DeliveryWestPorter","hairstyle":0,"male":true,"hair":"594338","skin":"e5b591","coat":"6b8580","cap":false,"apron":true,"carry":true,"phase":0},
  {"id":"DeliveryStoresPorter","hairstyle":3,"male":true,"hair":"6c4e42","skin":"d29b77","coat":"947363","cap":false,"apron":true,"carry":true,"phase":3}]
 var paths: Array=[
  [Vector3(-62,.055,-5.8),Vector3(-61.5,.055,-11.2)],
  [Vector3(-58.1,.055,-18.2),Vector3(-58.1,.055,-11.9)]]
 for i in 2:
  var worker=NPC.new();worker.name=profiles[i].id;worker.profile=profiles[i].duplicate(true);worker.route.assign(paths[i]);worker.speed=.72 if i==0 else .78;worker.work=true
  worker.set_meta("cargo_street_owned",true);worker.set_meta("delivery_job","carry_place_inspect");add_child(worker);workers.append(worker)
func tick(delta: float,camera: Camera3D,clock: float) -> void:
 var sources: Array[Vector3]=[Vector3(-62.2,.055,-4.35),Vector3(-59.05,.055,-19.25)]
 for i in workers.size():
  var worker=workers[i]
  if worker._arrived and not worker.walking:
   var inspect: Vector3=WAGON_AT if worker._target==1 else sources[i]
   worker.aim=(inspect-worker.position).normalized()
  worker.tick(delta,camera,clock)
