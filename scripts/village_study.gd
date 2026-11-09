extends "res://scripts/beach_arena.gd"
const Detail=preload("res://scripts/village_detail.gd")
var materials: Dictionary={}
var main
var front
var house_roof
var geometry_count:=0
var batch_count:=0
var lanterns: Array=[]
var _mist: ShaderMaterial
func _ready() -> void:
 _rng.seed=711102;spawn_point=Vector3(0,.03,5.5);camera_limits=Vector2(10,9)
 for entry in [["wood","#424a44","wood"],["oldwood","#5d6252","wood"],["brick","#575653","brick"],["plaster","#7a7e70","plaster"],["slate","#343e43","slate"],["iron","#252e32","slate"],["sand","#3c4845","sand"],["wet","#3c504d","sand"],["moss","#34443b","moss"],["stone","#525d58","plaster"],["shadow","#18272c","slate"],["rope","#78745b","wood"],["shell","#8d998a","slate"]]:
  materials[entry[0]]=Detail.material(entry[1],entry[2],711+materials.size())
 _wood=materials.wood;_stone=materials.stone;_iron=materials.iron
 main=Detail.new();main.name="BatchedShoreDetails";add_child(main)
 front=Detail.new();front.name="CottageFrontCutaway";add_child(front)
 house_roof=Detail.new();house_roof.name="CottageRoofCutaway";add_child(house_roof)
 _environment();_terrain();_track();_house();_props();_fences();_trees();_mist_layer()
 for builder in [main,front,house_roof]:geometry_count+=builder.count;batch_count+=builder.finish()
 _shore_boundary()
func _environment() -> void:
 var world:=WorldEnvironment.new();world.name="StudyNightEnvironment"
 var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("#0b161f")
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("#a2b7c2");env.ambient_light_energy=.28
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.fog_enabled=true;env.fog_light_color=Color("#233940");env.fog_light_energy=.5;env.fog_density=.018
 world.environment=env;add_child(world)
 var moon:=DirectionalLight3D.new();moon.name="ColdMoon";moon.rotation_degrees=Vector3(-48,-32,0);moon.light_color=Color("#93b8c9");moon.light_energy=.48;moon.shadow_enabled=true;moon.directional_shadow_max_distance=55;add_child(moon)
func _terrain() -> void:
 var mat: StandardMaterial3D=materials.sand;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
 _strip("DarkDampBeach",0,0,0,mat,true,true)
 mat=materials.wet;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.roughness=.23;mat.metallic=.12;mat.metallic_specular=.8
 _strip("SaturatedTideLine",-2.2,0,.006,mat)
 var sea:=Detail.material("#1e3940","sand",11);sea.cull_mode=BaseMaterial3D.CULL_DISABLED;sea.roughness=.26
 _strip("NightSea",0,40,-.035,sea)
 _foam=_material(Color("#526e70"));_foam.cull_mode=BaseMaterial3D.CULL_DISABLED
 _strip("ThinBrokenSurf",.1,.2,.012,_foam)
 for i in 70:
  var x:=_rng.randf_range(-14,14);var z:=shoreline(x)+_rng.randf_range(.4,12)
  main.box(Vector3(x,-.01,z),Vector3(_rng.randf_range(.12,1.4),.012,.025),materials.wet)
 # Low dark ground patches simulate contact dampness without screen-space AO.
 for i in 72:
  var x:=_rng.randf_range(-10.5,10.5);var z:=_rng.randf_range(-9,6.8)
  if absf(x)<1.8:continue
  var patch_mat: Material=materials.moss if z<0 and absf(x)>3.5 else materials.wet
  main.patch(Vector3(x,.012,z),Vector2(_rng.randf_range(.25,.75),_rng.randf_range(.12,.4)),patch_mat,810+i)
 for i in 44:
  var x:=_rng.randf_range(-12,12);var z:=shoreline(x)+_rng.randf_range(.15,1.7)
  main.box(Vector3(x,.01,z),Vector3(_rng.randf_range(.1,.6),.008,.018),materials.stone)
func _track() -> void:
 # Central clear passage; debris is clustered at its edges.
 for row in 26:
  var z:=6.0-row*.34;var bend:=sin(row*.18)*.35
  for side in [-1.0,1.0]:
   main.box(Vector3(bend+side*.72,.018,z),Vector3(.11,.018,.28),materials.wet,Vector3(0,side*.06,0))
 for row in 15:
  for column in 7:
   var x: float=(column-3)*.39+sin(row)*.05;var z: float=2.3-row*.37
   main.box(Vector3(x,.025,z),Vector3(.34,.045,.30),materials.stone if (row+column)%5 else materials.moss,Vector3(_rng.randf_range(-.03,.03),_rng.randf_range(-.08,.08),0))
 for row in 7:
  var z: float=-1.55-row*.25;var y: float=.04+row*.032
  for column in 4:main.box(Vector3((column-1.5)*.48,y,z),Vector3(.45,.065,.23),materials.oldwood)
 # A gentle ramp under the visual broken steps keeps the controller traversable.
 var body:=StaticBody3D.new();body.name="PorchRamp";body.collision_layer=1;var col:=CollisionShape3D.new();var shape:=ConvexPolygonShape3D.new()
 shape.points=PackedVector3Array([Vector3(-1.1,-.15,-1.4),Vector3(1.1,-.15,-1.4),Vector3(-1.1,-.15,-3.25),Vector3(1.1,-.15,-3.25),Vector3(-1.1,0,-1.4),Vector3(1.1,0,-1.4),Vector3(-1.1,.24,-3.25),Vector3(1.1,.24,-3.25)])
 col.shape=shape;body.add_child(col);add_child(body)
 for at in [Vector3(-1.3,.22,-2.4),Vector3(1.3,.22,-2.4)]:
  main.box(at,Vector3(.22,.45,2.1),materials.stone);_collider(at,Vector3(.22,.45,2.1),"PorchEdging")
func _house() -> void:
 # 19th-century fisher cottage, real doorway and two tall sash window openings.
 main.box(Vector3(0,.1,-6),Vector3(7.5,.28,5.7),materials.brick)
 _collider(Vector3(0,.04,-6),Vector3(7.4,.4,5.7),"CottageFloor")
 for x in [-3.7,3.7]:
  _collider(Vector3(x,1.8,-6),Vector3(.22,3.6,5.7),"CottageSide")
  for row in 24:main.box(Vector3(x,.36+row*.145,-6),Vector3(.20,.13,5.8),materials.wood if row%4 else materials.oldwood)
 _collider(Vector3(0,1.8,-8.85),Vector3(7.5,3.6,.2),"CottageBack")
 for row in 24:main.box(Vector3(0,.36+row*.145,-8.85),Vector3(7.5,.13,.2),materials.wood)
 for x in [-2.26,2.26]:_collider(Vector3(x,1.8,-3.15),Vector3(2.8,3.6,.20),"FrontWall")
 # Front board segments explicitly skip the doorway/windows.
 for row in 24:
  var y: float=.37+row*.145
  for column in 36:
   var x: float=-3.6+column*.205
   if absf(x)<.88 and y<2.85:continue
   if absf(absf(x)-2.2)<.62 and y>1.1 and y<2.65:continue
   front.box(Vector3(x,y,-3.12),Vector3(.20,.132,.19),materials.oldwood if (row+column)%7==0 else materials.plaster)
 for x in [-3.7,-.92,.92,3.7]:front.box(Vector3(x,1.9,-2.99),Vector3(.13,3.8,.17),materials.wood)
 front.box(Vector3(0,2.9,-3.0),Vector3(2.0,.18,.28),materials.wood)
 for x in [-2.2,2.2]:_window(x)
 # A door hanging inward on one hinge; entrance itself is clear.
 main.box(Vector3(-.72,1.48,-3.90),Vector3(.13,2.48,1.3),materials.wood,Vector3(0,-.24,.035))
 for z in [-3.44,-4.12]:main.box(Vector3(-.62,1.48,z),Vector3(.025,.14,.16),materials.iron)
 for row in 10:
  for column in 16:main.box(Vector3(-3.3+column*.435,.255,-3.5-row*.51),Vector3(.415,.035,.49),materials.oldwood if (row+column)%9 else materials.wood)
 # Broken gable: infill under roof slope and visible structural timbers.
 for row in 9:
  var width: float=7.6-row*.73
  front.box(Vector3(0,3.85+row*.16,-3.14),Vector3(width,.14,.18),materials.plaster)
 front.beam(Vector3(-3.9,3.7,-3),Vector3(0,5.5,-3),.14,materials.wood)
 front.beam(Vector3(0,5.5,-3),Vector3(3.9,3.7,-3),.14,materials.wood)
 front.box(Vector3(0,4.45,-2.99),Vector3(.15,1.8,.18),materials.wood)
 # Roof is individual uneven slates, merged into a few material meshes.
 for side in [-1.0,1.0]:
  for row in 13:
   var x: float=side*(row*.31+.16);var y: float=5.45-absf(x)*.46
   for column in 15:
    if side>0 and row in [7,8,9] and column in [10,11]:continue
    var z: float=-9.25+column*.435+(row%2)*.09
    house_roof.box(Vector3(x,y,z),Vector3(.39,.055,.48),materials.slate,Vector3(0,0,-side*.43))
  house_roof.beam(Vector3(0,5.53,-9.5),Vector3(side*4.15,3.62,-9.5),.14,materials.wood)
 house_roof.box(Vector3(0,5.56,-6.1),Vector3(.18,.16,6.7),materials.iron)
 for row in 13:
  for col in 4:
   var x: float=-2.8+(col%2)*.35;var z: float=-7.4+floor(col/2.0)*.35
   main.box(Vector3(x,3.5+row*.18,z),Vector3(.32,.16,.32),materials.brick)
 for x in [-2.8,-2.45]:main.box(Vector3(x,5.97,-7.22),Vector3(.22,.42,.25),materials.iron)
 _lantern(Vector3(1.27,2.2,-2.73))
 # Empty table, bowl, missing chair and dark back wall tell a stopped meal.
 main.box(Vector3(2.2,1.0,-7.45),Vector3(1.7,.12,.85),materials.oldwood)
 for x in [1.5,2.9]:
  for z in [-7.1,-7.8]:main.box(Vector3(x,.61,z),Vector3(.08,.75,.08),materials.wood)
 main.box(Vector3(2.15,1.10,-7.4),Vector3(.32,.08,.26),materials.shell)
func _window(x: float) -> void:
 front.box(Vector3(x,1.9,-3.16),Vector3(1.18,1.5,.05),materials.shadow)
 for dx in [-.65,.65]:front.box(Vector3(x+dx,1.9,-2.96),Vector3(.09,1.7,.2),materials.oldwood)
 for y in [1.06,1.83,2.75]:front.box(Vector3(x,y,-2.94),Vector3(1.4,.075,.22),materials.oldwood)
 front.box(Vector3(x,1.9,-2.92),Vector3(.065,1.6,.08),materials.wood)
 front.box(Vector3(x,1.03,-2.85),Vector3(1.5,.1,.42),materials.stone)
 for i in 3:
  front.box(Vector3(x-.48+i*.36,1.6,-2.83),Vector3(.2,1.1 if i!=1 else .6,.09),materials.wood,Vector3(0,0,-.13+i*.1))
 # Small diagonal splinters and sill moss.
 front.beam(Vector3(x-.7,2.3,-2.76),Vector3(x+.6,1.5,-2.76),.11,materials.oldwood)
 front.box(Vector3(x,1.09,-2.63),Vector3(1.4,.04,.11),materials.moss)
func _lantern(at: Vector3) -> void:
 var glow:=_material(Color("#b78b4a"));glow.emission_enabled=true;glow.emission=Color("#d69b4e");glow.emission_energy_multiplier=1.0
 var node:=_box(at,Vector3(.19,.33,.19),glow);node.name="AmberLanternGlass"
 for x in [-.13,.13]:main.box(at+Vector3(x,0,0),Vector3(.025,.43,.24),materials.iron)
 for y in [-.22,.22]:main.box(at+Vector3(0,y,0),Vector3(.34,.06,.32),materials.iron)
 main.beam(at+Vector3(0,.26,0),at+Vector3(0,.52,-.20),.035,materials.iron)
 var light:=OmniLight3D.new();light.position=at+Vector3(0,.05,.18);light.light_color=Color("#e3ad69");light.light_energy=2.8;light.omni_range=5.0;light.shadow_enabled=true;add_child(light);lanterns.append(light)
func _props() -> void:
 # Collapsed fishing skiff, ropes, open crates and waterlogged debris.
 for side in [-1.0,1.0]:
  for row in 4:
   for section in 9:
    var t: float=section/8.0;var z: float=2.1+t*4;var x: float=-5.2+side*sin(t*PI)*.85
    main.box(Vector3(x,.12+row*.13,z),Vector3(.13,.12,.55),materials.wood,Vector3(0,-side*cos(t*PI)*.25,.18))
 for section in 7:
  var t: float=section/6.0;var z: float=2.4+t*3.4;var width: float=sin((.1+t*.8)*PI)*.8
  main.beam(Vector3(-5.2-width,.3,z),Vector3(-5.2,.03,z),.08,materials.oldwood)
  main.beam(Vector3(-5.2,.03,z),Vector3(-5.2+width,.3,z),.08,materials.oldwood)
 for i in 120:
  var x:=_rng.randf_range(-10,10);var z:=_rng.randf_range(1,7.3)
  if absf(x)<1.8 or Vector2(x+5.2,z-4).length()<1.1:continue
  main.box(Vector3(x,.035,z),Vector3(_rng.randf_range(.08,.28),.025,.04),materials.shell if i%3==0 else materials.oldwood,Vector3(0,_rng.randf_range(-PI,PI),0))
 for point in [Vector3(4.7,0,-1.8),Vector3(-4.8,0,-2.0),Vector3(5.4,0,-3.0)]:
  _crate(point);obstacles.append(point);_collider(point+Vector3.UP*.4,Vector3(.85,.8,.85),"CrateCollision")
 for i in 18:
  var angle: float=i*TAU/18
  var next: float=(i+1)*TAU/18
  main.beam(Vector3(4.0+cos(angle)*.6,.05,1.6+sin(angle)*.42),Vector3(4.0+cos(next)*.6,.05,1.6+sin(next)*.42),.045,materials.rope)
 # Sagging hanging fishing net, individual knotted diagonal strands.
 for x in [-5.8,-3.7]:main.box(Vector3(x,1.05,-.4),Vector3(.12,2.1,.12),materials.oldwood)
 main.beam(Vector3(-5.8,2.05,-.4),Vector3(-3.7,2.05,-.4),.1,materials.wood)
 for i in 11:
  var x: float=-5.8+i*.21
  for j in 7:
   var y: float=.5+j*.18+absf(x+4.75)*.12
   main.beam(Vector3(x,y,-.4),Vector3(x+.21,y+.18,-.4),.014,materials.rope)
   main.beam(Vector3(x+.21,y,-.4),Vector3(x,y+.18,-.4),.014,materials.rope)
func _crate(at: Vector3) -> void:
 for side in [-1.0,1.0]:
  for row in 4:
   main.box(at+Vector3(side*.43,.15+row*.18,0),Vector3(.08,.15,.86),materials.oldwood)
   main.box(at+Vector3(0,.15+row*.18,side*.43),Vector3(.86,.15,.08),materials.wood)
 main.beam(at+Vector3(-.4,.1,.49),at+Vector3(.4,.75,.49),.08,materials.oldwood)
func _fences() -> void:
 for side in [-1.0,1.0]:
  for index in 10:
   var x: float=side*(2.0+index*.38)
   if index in [3,7]:continue
   var y: float=.48+_rng.randf_range(-.12,.12)
   main.box(Vector3(x,y,-1.1),Vector3(.13,y*2,.13),materials.wood,Vector3(0,0,_rng.randf_range(-.12,.12)))
  main.box(Vector3(side*3.8,.35,-1.14),Vector3(3.6,.1,.12),materials.oldwood)
  main.box(Vector3(side*3.8,.8,-1.14),Vector3(3.6,.1,.12),materials.wood)
  _collider(Vector3(side*3.9,.45,-1.1),Vector3(4.2,.9,.2),"FenceCollision")
func _trees() -> void:
 for i in 15:
  var x:=_rng.randf_range(-15,15);var z:=_rng.randf_range(-16,-11);var height:=_rng.randf_range(3.5,7)
  main.beam(Vector3(x,0,z),Vector3(x+.3,height,z),.18,materials.shadow)
  for branch in 4:
   var y: float=height*(.35+branch*.15);var side: float=-1 if branch%2 else 1
   main.beam(Vector3(x,y,z),Vector3(x+side*(1.4-branch*.17),y+.7,z-.3),.07,materials.shadow)
 # Only broken neighboring facades: the first cottage owns the composition.
 for x in [-8.7,8.7]:
  for row in 9:
   for column in 8:
    if row>4 and ((column+row)%5==0 or column<2):continue
    main.box(Vector3(x+(column-3.5)*.37,.12+row*.18,-8.9),Vector3(.35,.16,.25),materials.brick if row%3 else materials.moss)
  for side in [-1.0,1.0]:
   main.box(Vector3(x+side*1.6,1.45,-8.8),Vector3(.12,2.9,.16),materials.wood,Vector3(0,0,side*.06))
   main.beam(Vector3(x+side*1.65,2.8,-8.8),Vector3(x+side*.35,3.7,-8.8),.10,materials.oldwood)
  for i in 14:
   main.box(Vector3(x+_rng.randf_range(-1.8,1.8),.09,-8.1+_rng.randf_range(-.3,.6)),Vector3(.3,.16,.2),materials.brick,Vector3(0,_rng.randf_range(-PI,PI),0))
func _mist_layer() -> void:
 var shader:=Shader.new();shader.code="""shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float clock=0.0;
void fragment(){
 float wave=sin(UV.x*27.0+clock*.18+sin(UV.y*13.0))*sin(UV.y*21.0-clock*.13);
 float edge=smoothstep(0.0,.2,UV.x)*smoothstep(0.0,.2,1.0-UV.x)*smoothstep(0.0,.2,UV.y)*smoothstep(0.0,.2,1.0-UV.y);
 ALBEDO=vec3(.24,.33,.34);ALPHA=max(0.0,wave)*.11*edge;
}"""
 _mist=ShaderMaterial.new();_mist.shader=shader
 var node:=MeshInstance3D.new();node.name="DriftingGroundMist";var plane:=PlaneMesh.new();plane.size=Vector2(28,24);node.mesh=plane;node.material_override=_mist;node.position=Vector3(0,.18,-2);node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
func update_player(point: Vector3) -> void:
 var inside:=absf(point.x)<3.55 and point.z< -3.15 and point.z> -8.8
 house_roof.visible=not inside;front.visible=not inside
func tick(delta: float) -> void:
 _time+=delta
 if _mist!=null:_mist.set_shader_parameter("clock",_time)
 for light in lanterns:light.light_energy=2.75+sin(_time*4.1)*.055+sin(_time*7.7)*.035

func clamp_point(p: Vector3,margin: float=.45) -> Vector3:
 var point:=super.clamp_point(p,margin);point.x=clampf(point.x,-11.5,11.5);point.z=maxf(point.z,-10.5);return point
func is_walkable(p: Vector3,margin: float=.45) -> bool:
 return absf(p.x)<=11.5001 and p.z>=-10.5001 and super.is_walkable(p,margin)
