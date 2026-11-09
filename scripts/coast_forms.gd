extends "res://scripts/village_study.gd"
const Organic=preload("res://scripts/coast_form_detail.gd")
const Cottage=preload("res://scripts/shore_cottage.gd")
const FORMS:=["หาดเปิดและของเกยฝั่ง","ทางชิดโขดหินใหญ่","ชายป่าทึบและรากไม้","ทางโค้งผ่านช่องหิน","จุดพักร้างริมฝั่ง"]
var cottage
var route_length:=80.0
static func path_center(x: float) -> float:return -.065*x+.55*sin(x*.105)
static func sea_edge(x: float) -> float:return path_center(x)+6.8+.45*sin(x*.21)
static func forest_edge(x: float) -> float:return path_center(x)-3.7+.28*sin(x*.4)
func form_index(x: float) -> int:return clampi(int(floor(x/16)),0,4)
func inspection_point(index: int) -> Vector3:
 var x: float=clampi(index,0,4)*16+7.0;return Vector3(x,.03,path_center(x)+1.0)
func _ready() -> void:
 _rng.seed=72202;spawn_point=inspection_point(0);camera_limits=Vector2(84,24)
 for entry in [["wood","#424a44","wood"],["oldwood","#5d6252","wood"],["brick","#575653","brick"],["plaster","#7a7e70","plaster"],["slate","#343e43","slate"],["iron","#252e32","slate"],["sand","#3c4845","sand"],["wet","#3c504d","sand"],["moss","#34443b","moss"],["stone","#525d58","plaster"],["shadow","#18272c","slate"],["rope","#78745b","wood"],["shell","#8d998a","slate"],["bark","#3c423a","wood"],["leaves","#263b32","moss"],["cliff","#465654","plaster"]]:
  materials[entry[0]]=Detail.material(entry[1],entry[2],722+materials.size())
 _wood=materials.wood;_stone=materials.stone;_iron=materials.iron
 main=Organic.new();main.name="FiveConnectedCoastalForms";add_child(main)
 _environment();_coastal_ground();_forest();_forms();_bounds();_mist_layer()
 var mist_node: Node3D=get_node("DriftingGroundMist");mist_node.position.x=40;mist_node.position.z=path_center(40)-2;mist_node.scale.x=3.3
 geometry_count=main.count;batch_count=main.finish()
 cottage=Cottage.new();cottage.materials=materials;cottage.position=Vector3(72,0,path_center(72)+1.6);add_child(cottage)
 geometry_count+=cottage.geometry_count;batch_count+=cottage.batch_count
func _band(label_: String,inland: float,seaward: float,height: float,mat: Material,collision: bool=false) -> void:
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var faces:=PackedVector3Array()
 for i in 320:
  var x: float=-24+i*.4;var next: float=x+.4
  var a:=Vector3(x,height,sea_edge(x)+inland);var b:=Vector3(next,height,sea_edge(next)+inland);var c:=Vector3(next,height,sea_edge(next)+seaward);var d:=Vector3(x,height,sea_edge(x)+seaward)
  for point: Vector3 in [a,b,c,a,c,d]:tool.set_normal(Vector3.UP);tool.set_uv(Vector2(point.x,point.z)*.32);tool.add_vertex(point)
  faces.append_array(PackedVector3Array([a,c,b,a,d,c]))
 var node:=MeshInstance3D.new();node.name=label_;node.mesh=tool.commit();node.material_override=mat;add_child(node)
 if collision:
  var body:=StaticBody3D.new();body.collision_layer=1;var col:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.set_faces(faces);shape.backface_collision=true;col.shape=shape;body.add_child(col);add_child(body)
func _coastal_ground() -> void:
 for key in ["sand","wet"]:materials[key].cull_mode=BaseMaterial3D.CULL_DISABLED
 materials.wet.roughness=.23;materials.wet.metallic=.12
 _band("ContinuousCoastalFloor",-29,0,0,materials.sand,true)
 _band("WetTideEdge",-1.7,0,.008,materials.wet)
 var sea:=Detail.material("#1e3940","sand",18);sea.cull_mode=BaseMaterial3D.CULL_DISABLED;sea.roughness=.26
 _band("ContinuousSea",0,35,-.04,sea)
 _foam=_material(Color("#526e70"));_foam.cull_mode=BaseMaterial3D.CULL_DISABLED
 _band("SurfFoam",.1,.17,.012,_foam)
 for i in 310:
  var x:=_rng.randf_range(0,80);var z:=sea_edge(x)+_rng.randf_range(.2,13)
  main.box(Vector3(x,0,z),Vector3(_rng.randf_range(.12,.9),.008,.018),materials.wet if i%3 else materials.stone)
 for i in 150:
  var x:=_rng.randf_range(0,80);var z:=path_center(x)+_rng.randf_range(-3,6)
  if absf(z-path_center(x)-.8)<.7:continue
  main.patch(Vector3(x,.012,z),Vector2(_rng.randf_range(.2,.8),_rng.randf_range(.12,.4)),materials.wet,900+i)
func _forest() -> void:
 for i in 70:
  var x: float=-1+i*1.2+_rng.randf_range(-.3,.3);var z: float=forest_edge(x)-_rng.randf_range(.8,3.5)
  if absf(x-72)<4.8:continue
  main.tree(Vector3(x,0,z),_rng.randf_range(4.0,6.5),7220+i,materials.bark,materials.leaves)
 for i in 35:
  var x: float=i*2.35;var z: float=forest_edge(x)-5.5
  main.tree(Vector3(x,0,z),_rng.randf_range(5,7.2),8220+i,materials.shadow,materials.leaves,false)
func _coast_rock(at: Vector3,size: Vector3,seed_: int) -> void:
 main.boulder(at+Vector3.UP*size.y*.46,size,materials.cliff,seed_,true);obstacles.append(at)
 # Dark moss at its damp foot and a few salt-colored chips.
 main.patch(at+Vector3.UP*.018,Vector2(size.x*.65,size.z*.65),materials.moss,seed_)
 for i in 3:main.boulder(at+Vector3(_rng.randf_range(-size.x*.6,size.x*.6),.12,_rng.randf_range(-size.z*.6,size.z*.6)),Vector3(.3,.25,.4),materials.stone,seed_+i+30)
func _forms() -> void:
 # 1: broad tidal sand, storm wrack, driftwood and a single skiff skeleton.
 for i in 56:
  var x:=_rng.randf_range(.4,15.6);var z:=sea_edge(x)-_rng.randf_range(.7,2.1)
  main.box(Vector3(x,.03,z),Vector3(_rng.randf_range(.08,.6),.035,.06),materials.oldwood if i%3 else materials.shell,Vector3(0,_rng.randf_range(-PI,PI),0))
 for i in 7:
  var x: float=4+i*.44;var z: float=path_center(x)+4.5
  main.beam(Vector3(x,.04,z),Vector3(x,.4,z+.8),.07,materials.oldwood)
  main.beam(Vector3(x,.04,z),Vector3(x,.35,z-.7),.07,materials.wood)
 main.beam(Vector3(3.7,.1,path_center(4)+4.5),Vector3(7.2,.12,path_center(7)+4.5),.12,materials.wood)
 # 2: large angular coastal boulders physically constrain the inland edge.
 for i in 8:
  var x: float=16.5+i*1.9;_coast_rock(Vector3(x,0,path_center(x)-2.5),Vector3(_rng.randf_range(2.1,3.4),_rng.randf_range(2.8,4.2),2.7),920+i)
 for x in [19.0,25.0,30.0]:_coast_rock(Vector3(x,0,sea_edge(x)-.3),Vector3(1.5,.7,1.3),950+int(x))
 # 3: thicker low tree wall and exposed roots along the trail margin.
 for i in 11:
  var x: float=33+i*1.3
  main.tree(Vector3(x,0,path_center(x)-2.3),_rng.randf_range(4.2,5.8),1020+i,materials.bark,materials.leaves)
  for j in 3:
   var root: Array[Vector3]=[Vector3(x,.7,path_center(x)-2.2),Vector3(x+.4,.28,path_center(x)-1.5),Vector3(x+1,.08,path_center(x)-.6+j*.13)]
   main.tube(root,.17,materials.bark,.18)
 # 4: a gently rising-inland coastline, cliff teeth and an open combat-width bay.
 for i in 6:
  var x: float=49+i*2.7;_coast_rock(Vector3(x,0,path_center(x)-2.1),Vector3(2.5,3.3,2.6),1120+i)
 for x in [51.0,61.5]:_coast_rock(Vector3(x,0,path_center(x)+4.6),Vector3(1.5,.75,1.6),1140+int(x))
 for i in 22:
  var x:=_rng.randf_range(49,63);var z:=sea_edge(x)-_rng.randf_range(.5,1.1)
  main.box(Vector3(x,.025,z),Vector3(.1,.02,.045),materials.shell)
 # 5: one abandoned cottage plus fishing equipment; no important landmark yet.
 for at in [Vector3(67,0,path_center(67)+3),Vector3(77,0,path_center(77)+2.8)]:
  for row in 4:
   for side in [-1.0,1.0]:
    main.box(at+Vector3(side*.42,.12+row*.18,0),Vector3(.08,.15,.8),materials.oldwood)
    main.box(at+Vector3(0,.12+row*.18,side*.42),Vector3(.8,.15,.08),materials.wood)
  _collider(at+Vector3.UP*.4,Vector3(.85,.8,.85),"InspectionCrate")
 for x in [66.0,68.0]:main.beam(Vector3(x,0,path_center(x)-1.0),Vector3(x,1.8,path_center(x)-1.0),.12,materials.wood)
 for row in 8:
  for column in 8:
   var x: float=66+column*.25;var y: float=.25+row*.18
   main.beam(Vector3(x,y,path_center(67)-1),Vector3(x+.25,y+.18,path_center(67)-1),.014,materials.rope)
func _bounds() -> void:
 for i in 160:
  var x: float=i*.5;var z: float=forest_edge(x)
  if absf(x-72)<4.1:continue
  _collider(Vector3(x+.25,1.3,z-.6),Vector3(.60,2.6,1.0),"ForestMass")
 for i in 160:
  var x: float=i*.5;var a:=Vector3(x,1.3,sea_edge(x));var b:=Vector3(x+.5,1.3,sea_edge(x+.5))
  var body:=_collider((a+b)*.5+Vector3(0,0,.12),Vector3(a.distance_to(b)+.03,2.6,.18),"ShoreBarrier");body.rotation.y=-atan2(b.z-a.z,b.x-a.x)
 _collider(Vector3(-.15,1.5,-2),Vector3(.2,3,28),"WestBoundary")
 _collider(Vector3(80.15,1.5,-7),Vector3(.2,3,28),"EastBoundary")
func clamp_point(p: Vector3,margin: float=.45) -> Vector3:
 var x:=clampf(p.x,.45,79.55)
 var north:=forest_edge(x)-.05
 if absf(x-72)<3.6:north=path_center(72)-7.3
 return Vector3(x,p.y,clampf(p.z,north,sea_edge(x)-margin))
func is_walkable(p: Vector3,margin: float=.45) -> bool:
 var clamped:=clamp_point(p,margin);return absf(p.x-clamped.x)<.001 and absf(p.z-clamped.z)<.001
func update_player(point: Vector3) -> void:
 if is_instance_valid(cottage):cottage.update_player(point)
func tick(delta: float) -> void:
 _time+=delta
 if _mist!=null:_mist.set_shader_parameter("clock",_time)
 if is_instance_valid(cottage):cottage.tick(delta)
