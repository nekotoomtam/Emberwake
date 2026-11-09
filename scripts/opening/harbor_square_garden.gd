extends Node3D
## Restrained native planting and props for one existing plaza feeding activity.
## Plaza owns every existing person's and pigeon's tick; this helper owns props.
const Detail=preload("res://scripts/opening/harbor_detail.gd")
const TREE_CENTRES: Array[Vector3]=[Vector3(-49.7,.055,-.4),Vector3(-26.3,.055,-.4)]
const FEEDER_AT:=Vector3(-28.1,.055,-5.7)
const GRAIN_GROUND:=Vector3(-29.2,.055,-4.9)
var plaza: Node3D
var materials: Dictionary={}
var geometry_count:=0
var trees: Array[Node3D]=[]
var bed_bounds: Array[AABB]=[]
var leaf_materials: Array[Material]=[]
var feeder
var feeding_pigeon
var grains: Array[Node3D]=[]
var ground_grains: Node3D
var feeding_bag: Node3D
func _ready() -> void:
 name="HarborSquareGarden"
 _palette()
 for index in TREE_CENTRES.size():_tree(TREE_CENTRES[index],index)
 _reuse_activity();_feeding_props()
func _palette() -> void:
 for row in [["cream","e9dabb","plaster"],["stone2","a7a596","plaster"],["garden_bark","806954","wood"],["garden_soil","78715b","sand"],["garden_leaf_dark","526f48","moss"],["garden_leaf_mid","668955","moss"],["garden_leaf_light","7d9b65","moss"],["garden_rose","bd7f7b","plaster"],["garden_gold","c9ad67","plaster"],["garden_flower_cream","e2d3a3","plaster"],["garden_grain","cdb783","wood"],["garden_bag","bca47b","plaster"]]:
  if not materials.has(row[0]):materials[row[0]]=Detail.material(row[1],row[2],9120+materials.size())
 leaf_materials.assign([materials.garden_leaf_dark,materials.garden_leaf_mid,materials.garden_leaf_light])
func _body(parent: Node3D,label: String,shape: Shape3D,at: Vector3,group: String) -> StaticBody3D:
 var body:=StaticBody3D.new();body.name=label;body.position=at;body.collision_layer=1;body.collision_mask=3;body.add_to_group(group);body.add_to_group("harbor_garden_prop")
 var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);parent.add_child(body);return body
func _ring(detail,outer: float,inner: float) -> void:
 for index in 20:
  var a: float=TAU*index/20;var b: float=TAU*(index+1)/20
  var oa:=Vector3(cos(a)*outer,.23,sin(a)*outer);var ob:=Vector3(cos(b)*outer,.23,sin(b)*outer)
  var ia:=Vector3(cos(a)*inner,.23,sin(a)*inner);var ib:=Vector3(cos(b)*inner,.23,sin(b)*inner)
  detail.quad(oa,ob,ib,ia,materials.cream)
  detail.quad(Vector3(oa.x,.045,oa.z),Vector3(ob.x,.045,ob.z),ob,oa,materials.cream)
  detail.quad(Vector3(ia.x,.045,ia.z),ia,ib,Vector3(ib.x,.045,ib.z),materials.stone2)
  detail.beam(ia+Vector3.UP*.004,oa+Vector3.UP*.004,.014,materials.stone2)
func _bed(detail,index: int) -> void:
 _ring(detail,.82,.70)
 detail.cylinder(Vector3(0,.09,0),.70,.10,materials.garden_soil,24)
 # Small separate herbs and flowers leave visible soil and keep the stone rim.
 for item in 9:
  var angle: float=item*TAU/9+float(index)*.23;var distance: float=.42+.12*float(item%2)
  var at:=Vector3(cos(angle)*distance,.14,sin(angle)*distance)
  var height: float=.14+.035*float(item%3)
  for blade in 3:
   var direction:=Vector3(cos(angle+blade*2.1),0,sin(angle+blade*2.1))
   detail.quad(at,at+direction*.085+Vector3.UP*height,at+direction*.13+Vector3.UP*.025,at,leaf_materials[(item+blade)%3])
  if item%2==0:
   var bloom:=at+Vector3.UP*(height+.015)
   detail.beam(at,bloom,.012,materials.garden_leaf_dark)
   var flower: Material=[materials.garden_rose,materials.garden_gold,materials.garden_flower_cream][item%3]
   detail.boulder(bloom,Vector3(.11,.055,.10),flower,9150+item+index*20)
func _tree(at: Vector3,index: int) -> void:
 var tree:=Node3D.new();tree.name="OpenSquareTree"+str(index+1);tree.position=at;add_child(tree);trees.append(tree)
 var bed=Detail.new();bed.name="BedGeometry";tree.add_child(bed);_bed(bed,index);bed.finish();geometry_count+=bed.count
 bed_bounds.append(_mesh_bounds(bed))
 var bed_shape:=CylinderShape3D.new();bed_shape.radius=.83;bed_shape.height=.24
 _body(tree,"BedFootprint",bed_shape,Vector3.UP*.12,"harbor_garden_bed")
 var geometry=Detail.new();geometry.name="TreeGeometry";tree.add_child(geometry)
 var side: float=1 if index==0 else -1
 geometry.tube([Vector3.ZERO,Vector3(.035*side,1.15,-.015),Vector3(-.045*side,2.15,.035),Vector3(.065*side,3.05,.025),Vector3(.16*side,3.95,.05)],.145,materials.garden_bark,.18)
 # Unequal forks and smaller tips remain visible below the high leaf clusters.
 var tips: Array[Vector3]=[Vector3(-.56,3.78,.05),Vector3(.56,3.9,-.03),Vector3(-.14,4.42,-.10),Vector3(.25,4.25,.35),Vector3(-.32,4.1,-.42),Vector3(.18,3.62,-.38),Vector3(-.40,3.70,.43)]
 for item in tips.size():
  var tip: Vector3=tips[item]
  var fork:=Vector3(.02*side,2.36+float(item%3)*.21,.02)
  geometry.tube([fork,Vector3(tip.x*.55,3.13+float(item%2)*.16,tip.z*.5),tip],.063 if item<3 else .044,materials.garden_bark,.16)
 var clusters: Array[Vector3]=[Vector3(1.03,.85,.90),Vector3(1.03,.85,.90),Vector3(.92,.85,.85),Vector3(.86,.86,.90),Vector3(.86,.82,.84),Vector3(.70,.72,.68),Vector3(.75,.75,.72)]
 for item in tips.size():geometry.boulder(tips[item],clusters[item],leaf_materials[(item+index)%3],9180+index*31+item)
 geometry.finish();geometry_count+=geometry.count
 var trunk:=CapsuleShape3D.new();trunk.radius=.15;trunk.height=2.9
 _body(tree,"TrunkFootprint",trunk,Vector3.UP*1.45,"harbor_garden_trunk")
func _mesh_bounds(node: Node3D) -> AABB:
 var bounds:=AABB();var first:=true
 for mesh in node.find_children("*","MeshInstance3D",true,false):
  var part: AABB=mesh.global_transform*mesh.mesh.get_aabb()
  bounds=part if first else bounds.merge(part);first=false
 return bounds
func _reuse_activity() -> void:
 if plaza==null:return
 for person in plaza.people:
  if String(person.name)=="FountainVisitor":feeder=person;break
 if feeder!=null:
  feeder.route.assign([FEEDER_AT]);feeder.position=FEEDER_AT;feeder._target=0;feeder._wait=0;feeder._arrived=false
  feeder.work=true;feeder.aim=(GRAIN_GROUND-FEEDER_AT).normalized()
 if plaza.birds.size()>1:
  feeding_pigeon=plaza.birds[1];feeding_pigeon.home=GRAIN_GROUND+Vector3(.06,0,.02)
  feeding_pigeon.position=feeding_pigeon.home;feeding_pigeon._last=feeding_pigeon.home
func _feeding_props() -> void:
 feeding_bag=Detail.new();feeding_bag.name="VisitorGrainBag";add_child(feeding_bag)
 feeding_bag.boulder(Vector3.ZERO,Vector3(.18,.22,.14),materials.garden_bag,9220)
 var handle: Array[Vector3]=[Vector3(-.05,.07,0),Vector3(0,.14,0),Vector3(.05,.07,0)]
 feeding_bag.tube(handle,.012,materials.garden_bark,.8)
 feeding_bag.position=FEEDER_AT+Vector3(.18,.5,.02);feeding_bag.finish();geometry_count+=feeding_bag.count
 ground_grains=Detail.new();ground_grains.name="PigeonGroundGrains";add_child(ground_grains)
 for item in 7:
  var angle: float=item*2.4;var distance: float=.07+.035*float(item%3)
  ground_grains.box(GRAIN_GROUND+Vector3(cos(angle)*distance,.012,sin(angle)*distance),Vector3(.032,.016,.025),materials.garden_grain,Vector3(0,angle,0))
 ground_grains.finish();geometry_count+=ground_grains.count
 for item in 5:
  var grain=Detail.new();grain.name="TossedGrain"+str(item);add_child(grain)
  grain.box(Vector3.ZERO,Vector3(.036,.022,.027),materials.garden_grain);grain.finish();geometry_count+=grain.count
  grain.position=FEEDER_AT+Vector3.UP*.79;grain.visible=false;grains.append(grain)
func tick(_delta: float,camera: Camera3D,clock: float) -> void:
 if feeder==null or camera==null:return
 var right: Vector3=camera.global_basis.x
 var hand: Vector3=feeder.global_position+right*.27+Vector3.UP*.76
 feeding_bag.global_position=feeder.global_position+right*.15+Vector3.UP*.48
 for item in grains.size():
  var phase:=fposmod(clock/3.4+float(item)*.052,1)
  var t:=clampf(phase/.59,0,1)
  var landing: Vector3=GRAIN_GROUND+Vector3(sin(item*2.1)*.12,.018,cos(item*2.1)*.1)
  grains[item].visible=phase<.59
  grains[item].global_position=hand.lerp(landing,t)+Vector3.UP*sin(t*PI)*.23
  grains[item].rotation=Vector3(t*2.1,float(item)+t*3.0,t*.9)
