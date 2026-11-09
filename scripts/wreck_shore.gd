extends "res://scripts/village_study.gd"
const Profile=preload("res://scripts/wreck_shore_profile.gd")
const Organic=preload("res://scripts/coast_form_detail.gd")
const Ship=preload("res://scripts/wreck_ship.gd")
const Surge=preload("res://scripts/shore_surge.gd")
var ship
var wreck_pose:=Transform3D(Basis.from_euler(Vector3(.20,1.15,.09)),Vector3.ZERO)
var west_rocks: Array=[]
var west_growth:=0
var west_backdrop_count:=0
var east_rocks: Array[Vector3]=[]
var impact_rocks: Array[Vector3]=[]
var surge
var intro_age:=0.0
var reveal_seen:=false
var exit_reached:=false
var reveal_amount:=0.0
var landing_point:=Vector3(7,.03,.12)
var wash_origin:=Vector3(5,.03,5.1)
var player_point:=Vector3.ZERO
static func coast_z(x: float) -> float:return Profile.coast_z(x)
static func travel_z(x: float) -> float:return Profile.travel_z(x)
func _ready() -> void:
 _rng.seed=73303;landing_point=Vector3(7,.03,travel_z(7)+.7);wash_origin=Vector3(5,.03,Profile.sea_z(5)-.65);spawn_point=wash_origin;camera_limits=Vector2(85,45)
 for entry in [["wood","#424a44","wood"],["oldwood","#5d6252","wood"],["brick","#575653","brick"],["plaster","#7a7e70","plaster"],["slate","#343e43","slate"],["iron","#252e32","slate"],["sand","#3c4845","sand"],["wet","#3c504d","sand"],["moss","#34443b","moss"],["stone","#525d58","plaster"],["shadow","#18272c","slate"],["rope","#78745b","wood"],["shell","#8d998a","slate"],["bark","#3c423a","wood"],["leaves","#263b32","moss"],["cliff","#465654","plaster"],["canvas","#747d73","plaster"]]:
  materials[entry[0]]=Detail.material(entry[1],entry[2],733+materials.size())
 materials.canvas.cull_mode=BaseMaterial3D.CULL_DISABLED
 _wood=materials.wood;_stone=materials.stone;_iron=materials.iron
 wreck_pose.origin=Vector3(46,-.4,Profile.sea_z(46)+9.0)
 main=Organic.new();main.name="OpeningCoastDetails";add_child(main)
 _environment();_terrain_opening();_forest_opening();_west_backdrop();_rocks_opening();_bow_impact_rocks();_wrack();_impact_scar();_small_shack();_borders();_mist_layer()
 var mist: Node3D=get_node("DriftingGroundMist");mist.position=Vector3(32,.18,-12);mist.scale=Vector3(3.4,1,2.3)
 geometry_count=main.count;batch_count=main.finish()
 ship=Ship.new();ship.materials=materials;ship.transform=wreck_pose;add_child(ship);geometry_count+=ship.geometry_count;batch_count+=ship.batch_count
 surge=Surge.new();surge.materials=materials;add_child(surge);surge.update_wave(0,0,landing_point,wash_origin)
func _terrain_band(name_: String,inner: float,outer: float,height: float,material_: Material,solid: bool=false) -> void:
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);var faces:=PackedVector3Array()
 for i in 340:
  var x: float=-24+i*.4;var next: float=x+.4
  var a:=Vector3(x,height,Profile.sea_z(x)+inner);var b:=Vector3(next,height,Profile.sea_z(next)+inner);var c:=Vector3(next,height,Profile.sea_z(next)+outer);var d:=Vector3(x,height,Profile.sea_z(x)+outer)
  for point: Vector3 in [a,b,c,a,c,d]:tool.set_normal(Vector3.UP);tool.set_uv(Vector2(point.x,point.z)*.32);tool.add_vertex(point)
  faces.append_array(PackedVector3Array([a,c,b,a,d,c]))
 var node:=MeshInstance3D.new();node.name=name_;node.mesh=tool.commit();node.material_override=material_;add_child(node)
 if solid:
  var body:=StaticBody3D.new();body.collision_layer=1;var col:=CollisionShape3D.new();var shape:=ConcavePolygonShape3D.new();shape.set_faces(faces);shape.backface_collision=true;col.shape=shape;body.add_child(col);add_child(body)
func _terrain_opening() -> void:
 for key in ["sand","wet"]:materials[key].cull_mode=BaseMaterial3D.CULL_DISABLED
 materials.wet.roughness=.24;materials.wet.metallic=.12
 _terrain_band("ContinuousShore",-42,0,0,materials.sand,true)
 _terrain_band("StormWetSand",-2.5,0,.008,materials.wet)
 var water:=Detail.material("#1a343c","sand",733);water.cull_mode=BaseMaterial3D.CULL_DISABLED;water.roughness=.26
 _terrain_band("StormSea",0,48,-.045,water)
 for i in 180:
  var x:=_rng.randf_range(2,64);var z:=Profile.sea_z(x)-_rng.randf_range(.4,3)
  main.patch(Vector3(x,.013,z),Vector2(_rng.randf_range(.2,.9),_rng.randf_range(.12,.5)),materials.wet,1230+i)
 for i in 190:
  var x:=_rng.randf_range(-8,90);var z:=Profile.sea_z(x)+_rng.randf_range(.8,18)
  main.box(Vector3(x,-.01,z),Vector3(_rng.randf_range(.2,1.2),.009,.022),materials.wet)
 # The final footpath bends away from the sea into a gap in the forest.
 for i in 60:
  var x: float=44+i*.33;var z: float=travel_z(x)
  for side in [-1.0,1.0]:
   main.patch(Vector3(x+side*.7,.014,z+side*.4),Vector2(.19,.09),materials.wet,2330+i+int(side))
func _forest_opening() -> void:
 for i in 69:
  var x: float=-1+i*.99;var z: float=Profile.forest_z(x)-_rng.randf_range(.9,3.2)
  if absf(x-24)<3.0:continue
  main.tree(Vector3(x,0,z),_rng.randf_range(4.2,6.6),3330+i,materials.bark,materials.leaves)
 for i in 28:
  var x: float=i*2.5;var z: float=Profile.forest_z(x)-6
  main.tree(Vector3(x,0,z),_rng.randf_range(5,7),3430+i,materials.shadow,materials.leaves,false)
 # Foreground trees frame the exit only, leaving the giant-wreck vista clear.
 for x in [57.0,60.0,63.0,66.0]:
  main.tree(Vector3(x,0,travel_z(x)+5.5),4.8,3500+int(x),materials.bark,materials.leaves)
func _west_backdrop() -> void:
 # Continue the inland ridge beyond the playable left edge, not an isolated island.
 var random:=RandomNumberGenerator.new();random.seed=7751
 for i in 9:
  var x: float=-17+i*1.9;var z: float=-5.9+sin(i*1.3)*.9
  _opening_rock(Vector3(x,0,z),Vector3(random.randf_range(4.6,6),random.randf_range(3.8,5.5),random.randf_range(4.2,6)),7750+i)
 for i in 23:
  var x: float=-18+i*.85;var z: float=Profile.forest_z(x)-random.randf_range(2.8,7)
  main.tree(Vector3(x,0,z),random.randf_range(5.5,8),7780+i,materials.bark,materials.leaves,false)
  main.boulder(Vector3(x,.55,z+1.0),Vector3(3.1,1.7,2.4),materials.leaves,7820+i)
  west_backdrop_count+=1
func _bow_impact_rocks() -> void:
 # The crushed starboard forecastle is physically wrapped around this outcrop.
 for entry in [[Vector3(12.8,0,2.1),Vector3(5.2,4.9,4.8)],
  [Vector3(16.0,0,3.1),Vector3(3.6,2.7,3.4)],
  [Vector3(14.2,0,5.2),Vector3(3.2,3.8,3.0)]]:
  var at: Vector3=wreck_pose*entry[0];at.y=0;impact_rocks.append(at)
  _opening_rock(at,entry[1],7900+impact_rocks.size())
 var random:=RandomNumberGenerator.new();random.seed=7930
 for i in 17:
  var at: Vector3=impact_rocks[0]+Vector3(random.randf_range(-2.6,3),.08,random.randf_range(-2.1,2.4))
  main.boulder(at,Vector3(.5,.3,.6)*random.randf_range(.6,1.4),materials.stone,7930+i)
  if i%2==0:main.box(at+Vector3.UP*.12,Vector3(random.randf_range(.5,1.7),.1,.16),materials.oldwood,Vector3(.1,random.randf_range(-PI,PI),.25))
func _opening_rock(point: Vector3,size: Vector3,seed_: int) -> void:
 main.boulder(point+Vector3.UP*size.y*.45,size,materials.cliff,seed_,true);obstacles.append(point)
 main.patch(point+Vector3.UP*.012,Vector2(size.x*.6,size.z*.6),materials.moss,seed_)
func _rocks_opening() -> void:
 # Overlapping outcrops make a crooked cove edge rather than a row of stones.
 var sea: float=Profile.sea_z(0)
 west_rocks=[
  [Vector3(-1.5,0,sea-3),Vector3(6.8,4.8,6.2)],
  [Vector3(-.4,0,sea-7.7),Vector3(6.5,6,5.3)],
  [Vector3(-3.8,0,sea-9.8),Vector3(7.8,5.2,6.5)],
  [Vector3(1,0,sea-11.7),Vector3(4,3.2,3.8)],
  [Vector3(-2.4,0,sea-13.7),Vector3(6.4,6.1,6)],
  [Vector3(.6,0,sea-.8),Vector3(4.5,2,4)],
  [Vector3(2.8,0,sea-3.2),Vector3(1.2,.7,1.3)],
  [Vector3(1.5,0,sea-6),Vector3(3,1.4,2.5)]]
 for i in west_rocks.size():_opening_rock(west_rocks[i][0],west_rocks[i][1],7430+i)
 var random:=RandomNumberGenerator.new();random.seed=7444
 for i in 19:
  var at:=Vector3(random.randf_range(.4,3.1),.03,sea-random.randf_range(2,9))
  var size:=Vector3(random.randf_range(.3,1),random.randf_range(.15,.65),random.randf_range(.4,.9))
  main.boulder(at+Vector3.UP*size.y*.3,size,materials.stone,7470+i)
 for i in 8:
  var at:=Vector3(-3.2+random.randf_range(-1.3,2),0,sea-6.5-i*.9)
  main.tree(at,random.randf_range(4.4,6.7),7510+i,materials.bark,materials.leaves);west_growth+=1
  main.boulder(at+Vector3(.5,.5,.7),Vector3(3,1.5,2),materials.leaves,7550+i)
 for i in 5:
  var z: float=sea-7-i*.9
  var root_points: Array[Vector3]=[Vector3(-1,2.7,z-1),Vector3(.2,1.2,z),Vector3(1.7,.18,z+1.2),Vector3(2.3,.03,z+1.6)]
  main.tube(root_points,.24,materials.bark,.18)
 var fallen_trunk: Array[Vector3]=[Vector3(-3,.45,sea-4),Vector3(-.3,1.6,sea-5),Vector3(1.4,1.15,sea-7.6)]
 main.tube(fallen_trunk,.32,materials.oldwood,.6)
 for x in [13.0,16.0,30.0,33.0]:_opening_rock(Vector3(x,0,travel_z(x)-2.5),Vector3(2.7,3.2,2.5),4500+int(x))
 for x in [10.0,19.0,28.0]:
  _opening_rock(Vector3(x,0,Profile.sea_z(x)+.4),Vector3(1.4,1.1,1.6),4600+int(x))
 # A continuous headland seals the old eastbound shoreline, leaving the inland turn.
 var headland_random:=RandomNumberGenerator.new();headland_random.seed=7606
 for i in 9:
  var x: float=56.9+i*1.35;var z: float=travel_z(minf(x,63.0))+5.0+sin(i*1.7)*.35
  var at:=Vector3(x,0,z);east_rocks.append(at)
  _opening_rock(at,Vector3(headland_random.randf_range(4.0,4.6),headland_random.randf_range(2.0,3.1),headland_random.randf_range(5.8,6.4)),8100+i)
  if i%2==0:main.boulder(at+Vector3(-.7,.6,-2.0),Vector3(1.7,1.2,1.5),materials.stone,8150+i)
 for i in 8:
  var x: float=57.3+i*1.65;var at:=Vector3(x,0,coast_z(x)+4.2)
  east_rocks.append(at);_opening_rock(at,Vector3(4.8,4.3+(i%3)*.65,6.2),8180+i)
  if i%2==0:main.tree(at+Vector3(.1,2.8,-.5),4.1,8210+i,materials.bark,materials.leaves,false)
func _wrack() -> void:
 for i in 95:
  var x:=_rng.randf_range(3,55);var z:=Profile.sea_z(x)-_rng.randf_range(.7,3.2)
  main.box(Vector3(x,.035,z),Vector3(_rng.randf_range(.2,.95),.045,.11),materials.oldwood if i%4 else materials.shell,Vector3(0,_rng.randf_range(-PI,PI),0))
 for at in [Vector3(10,0,Profile.sea_z(10)-2),Vector3(18,0,Profile.sea_z(18)-1.6),Vector3(34,0,Profile.sea_z(34)-1)]:
  for row in 3:
   for side in [-1.0,1.0]:
    main.box(at+Vector3(side*.4,.12+row*.18,0),Vector3(.08,.15,.8),materials.wood)
    if row!=2:main.box(at+Vector3(0,.12+row*.18,side*.4),Vector3(.8,.15,.08),materials.oldwood)
 # A long broken spar points diagonally along the direction of travel.
 main.beam(Vector3(8,.08,travel_z(8)+2),Vector3(13,.13,travel_z(13)+2),.16,materials.oldwood)
func _impact_scar() -> void:
 # Keel scrape, displaced sand and splinters follow the ship's actual axis.
 var forward: Vector3=wreck_pose.basis.x;forward.y=0;forward=forward.normalized()
 var side:=Vector3(-forward.z,0,forward.x)
 var random:=RandomNumberGenerator.new();random.seed=7620
 for i in 23:
  var at: Vector3=wreck_pose.origin+forward*(5+i*.45);at.y=.018
  if at.z>Profile.sea_z(at.x)-.05:continue
  main.patch(at,Vector2(.8,.55),materials.shadow,7620+i)
  for sign_ in [-1.0,1.0]:
   var edge: Vector3=at+side*sign_*random.randf_range(.8,1.3)
   main.boulder(edge+Vector3.UP*.08,Vector3(.7,.2,.8),materials.sand,7660+i+int(sign_))
   if i%3==0:
    main.box(edge+side*sign_*.6+Vector3.UP*.04,Vector3(random.randf_range(.5,1.6),.07,.13),materials.oldwood,Vector3(0,1.15+random.randf_range(-1,1),.07))
func _small_shack() -> void:
 var at:=Vector3(24,0,travel_z(24)-4.4)
 for side in [-1.0,1.0]:
  for row in 13:main.box(at+Vector3(side*1.7,.15+row*.16,0),Vector3(.13,.14,2.7),materials.wood)
 for row in 13:
  main.box(at+Vector3(0,.15+row*.16,-1.3),Vector3(3.5,.14,.14),materials.oldwood)
  for side in [-1.0,1.0]:main.box(at+Vector3(side*1.2,.15+row*.16,1.3),Vector3(.9,.14,.14),materials.wood)
 main.box(at+Vector3(0,1.05,1.24),Vector3(1.5,1.9,.12),materials.shadow)
 main.box(at+Vector3(.15,1.0,1.4),Vector3(.7,1.8,.1),materials.oldwood,Vector3(0,.24,.06))
 for x in 8:
  for z in 7:
   if x>4 and z in [2,3]:continue
   main.box(at+Vector3(-1.9+x*.52,2.35+sin(x*.4)*.08,-1.6+z*.5),Vector3(.55,.065,.56),materials.slate,Vector3(0,0,.1))
 _collider(at+Vector3.UP,Vector3(3.5,2.2,2.8),"ClosedFishingShack")
func _borders() -> void:
 for i in 128:
  var x: float=i*.5;var z: float=Profile.forest_z(x)
  _collider(Vector3(x+.25,1.3,z-.6),Vector3(.65,2.6,1.05),"ForestMass")
 for i in 128:
  var x: float=i*.5;var a:=Vector3(x,1.3,Profile.sea_z(x));var b:=Vector3(x+.5,1.3,Profile.sea_z(x+.5))
  var body:=_collider((a+b)*.5+Vector3(0,0,.12),Vector3(a.distance_to(b)+.04,2.6,.18),"ShoreBarrier");body.rotation.y=-atan2(b.z-a.z,b.x-a.x)
 _collider(Vector3(64.1,1.5,-18),Vector3(.2,3,36),"EastBoundary")
func clamp_point(point: Vector3,margin: float=.45) -> Vector3:
 var x:=clampf(point.x,-.5,63.5)
 return Vector3(x,point.y,clampf(point.z,Profile.forest_z(x)-.05,Profile.sea_z(x)-margin))
func is_walkable(point: Vector3,margin: float=.45) -> bool:
 var clamped:=clamp_point(point,margin);return absf(clamped.x-point.x)<.001 and absf(clamped.z-point.z)<.001
func intro_done() -> bool:return intro_age>=Profile.INTRO
func skip_intro() -> void:intro_age=Profile.INTRO
func apply_intro(game) -> void:
 var t:=clampf(intro_age/1.8,0,1);game.player.position=wash_origin.lerp(landing_point,1-pow(1-t,2));game.player.velocity=Vector3.ZERO
func update_player(point: Vector3) -> void:
 player_point=point
 if intro_done() and point.x>=38:reveal_seen=true
 if intro_done() and reveal_seen and point.x>=61 and point.z<=travel_z(61)+1.2:exit_reached=true
func camera_focus(point: Vector3) -> Vector3:
 if not intro_done():return point+Vector3(2,0,-1.4)
 var normal:=point+Vector3(2.5,0,-2)
 return normal.lerp(Vector3(47,0,Profile.sea_z(46)+4.5),reveal_amount)
func camera_size() -> float:return lerpf(18.5,31.5,reveal_amount)
func present(game) -> void:
 game.avatar.set_equipment_visible(false);game.dual_visual.visible=false;game.pistol_reticle.visible=false
 if not intro_done():
  var rise:=smoothstep(2.9,Profile.INTRO,intro_age)
  game.avatar.body.global_basis=game.camera.global_basis*Basis(Vector3.FORWARD,lerpf(1.35,0,rise))
  game.avatar.body.global_position=game.player.global_position+game.camera.global_basis.y*lerpf(.28,.86,rise)
 surge.set_audio(game.audio.enabled and game.mode=="practice")
func tick(delta: float) -> void:
 _time+=delta;intro_age=minf(Profile.INTRO,intro_age+delta)
 if _mist!=null:_mist.set_shader_parameter("clock",_time)
 var target:=1.0 if player_point.x>=37 and player_point.x<51 and intro_done() else 0.0
 reveal_amount=move_toward(reveal_amount,target,delta*.8)
 if is_instance_valid(surge):surge.update_wave(delta,intro_age,landing_point,wash_origin)
