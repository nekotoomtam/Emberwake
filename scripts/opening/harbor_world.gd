extends Node3D
const Detail=preload("res://scripts/opening/harbor_detail.gd")
const Ship=preload("res://scripts/opening/departure_ship.gd")
const Coffee=preload("res://scripts/opening/harbor_hero_appearance.gd")
const NPC=preload("res://scripts/opening/harbor_npc.gd")
const Pigeon=preload("res://scripts/opening/harbor_pigeon.gd")
const Appearance=preload("res://scripts/opening/npc_appearance.gd")
const Swell=preload("res://scripts/opening/ship_swell.gd")
const PlazaProfile=preload("res://scripts/opening/harbor_plaza_profile.gd")
const Gangway=preload("res://scripts/opening/harbor_gangway.gd")
const WaterContact=preload("res://scripts/opening/ship_water_contact.gd")
@export var appearance_seed: int=20261102
var _looks_rng:=RandomNumberGenerator.new()
var _hair_bag: Array[int]=[]
var townspeople: Array=[]
var crew: Array=[]
var pigeons: Array=[]
var _barrier_count:=0
var materials: Dictionary={}
var main
var ship
var arrival
var ship_water: Node3D
var departure_supplies: Node3D
var lighthouse
var backdrop
var plaza
var life
var town_routes
var public_solids
var cargo_street
var square_garden
var bench_life
var passage_cargo
var passenger_forecourt
var city_matte
var hybrid_waterfront
var horizon_fill
var city_continuation
var far_shore_city
var chimney_smoke
var dock_life
var foliage_study
var quay_edge
var hero_offset:=1.08
var sip_lift:=0.0
var modular_protagonist:=false
var cup
var sip_enabled:=true
var sip_age:=0.0
var hero: Sprite3D
var steam: Array[Sprite3D]=[]
var clock:=0.0
var sea_surface
var water_material: ShaderMaterial
var cloth_materials: Array[ShaderMaterial]=[]
var geometry_count:=0
var anchors: Dictionary={"cafe":PlazaProfile.CAFE,"market":PlazaProfile.FOUNTAIN+Vector3(0,0,5.5),"quay":Vector3(7.5,0,3),"gangway":Vector3(7,.43,-2)}
func spawn_anchor(id: StringName) -> Transform3D:return Transform3D(Basis.IDENTITY,anchors.get(String(id),Vector3.ZERO))
func _ready() -> void:
 for entry in [["wood","956d51","wood"],["darkwood","5d483d","wood"],["shipwood","405c61","wood"],["gold","cfa76f","wood"],["stone","b7b0a0","plaster"],["stone2","a7a596","plaster"],["cream","e9dabb","plaster"],["teal","487d80","wood"],["canvas","eddfb9","plaster"],["red","ba6f5b","plaster"],["iron","3e5357","slate"],["rope","bbaa7d","wood"],["leaves","6b8558","moss"],["clay","b47759","plaster"],["window","789aab","slate"],["coffee","493329","wood"]]:
  materials[entry[0]]=Detail.material(entry[1],entry[2],7700+materials.size())
 materials.canvas.cull_mode=BaseMaterial3D.CULL_DISABLED
 main=Detail.new();main.name="WarmHarborGeometry";add_child(main)
 _environment();_water();_quay();_cafe();_pier();_distant();_seated_hero()
 geometry_count=main.count+plaza.geometry_count+quay_edge.geometry_count+life.geometry_count+town_routes.geometry_count+sea_surface.geometry_count;main.finish()
 ship=Ship.new();ship.name="IntactDepartureVessel";ship.materials=materials;ship.position=Vector3(7,-.55,-7.6);add_child(ship)
 ship_water=WaterContact.new();ship_water.hull=ship.visual_root;ship_water.phase=2.1;add_child(ship_water)
 # Mooring lines lead from the actual hull to bollards on the quay.
 var ropes=Detail.new();add_child(ropes)
 for x in [-3.0,4.0,13.0]:ropes.beam(Vector3(x,1.7,-4.2),Vector3(x+1,.45,1.9),.035,materials.rope)
 ropes.finish();geometry_count+=ship.geometry_count+lighthouse.geometry_count+backdrop.geometry_count
 arrival=preload("res://scripts/opening/arrival_vessel.gd").new();arrival.materials=materials;add_child(arrival);geometry_count+=arrival.geometry_count
 _walking_surfaces()
 _living_harbor();_clear_boarding_apron_people()
 public_solids=preload("res://scripts/opening/harbor_public_solids.gd").new();public_solids.world=self;add_child(public_solids)
 cargo_street=preload("res://scripts/opening/harbor_cargo_street.gd").new();cargo_street.materials=materials.duplicate();add_child(cargo_street)
 square_garden=preload("res://scripts/opening/harbor_square_garden.gd").new();square_garden.materials=materials.duplicate();square_garden.plaza=plaza;add_child(square_garden)
 bench_life=preload("res://scripts/opening/harbor_bench_life.gd").new();bench_life.materials=materials.duplicate();add_child(bench_life)
 passage_cargo=preload("res://scripts/opening/harbor_passage_cargo.gd").new();passage_cargo.materials=materials.duplicate();add_child(passage_cargo)
 passenger_forecourt=preload("res://scripts/opening/harbor_passenger_forecourt.gd").new();passenger_forecourt.materials=materials.duplicate();add_child(passenger_forecourt)
 city_matte=preload("res://scripts/opening/harbor_city_matte.gd").new();add_child(city_matte)
 hybrid_waterfront=preload("res://scripts/opening/harbor_city_waterfront_3d.gd").new();hybrid_waterfront.materials=backdrop.mats.duplicate();add_child(hybrid_waterfront)
 horizon_fill=preload("res://scripts/opening/harbor_city_horizon_fill.gd").new();horizon_fill.source_matte=city_matte;horizon_fill.source_waterfront=hybrid_waterfront;horizon_fill.ridge_material=materials.leaves;add_child(horizon_fill)
 city_continuation=preload("res://scripts/opening/harbor_city_continuation.gd").new();city_continuation.source_matte=city_matte;add_child(city_continuation)
 far_shore_city=preload("res://scripts/opening/harbor_far_shore_city.gd").new();add_child(far_shore_city)
 geometry_count+=far_shore_city.geometry_count
 chimney_smoke=preload("res://scripts/opening/harbor_chimney_smoke.gd").new();chimney_smoke.outlets=backdrop.chimney_outlets+hybrid_waterfront.chimney_outlets;add_child(chimney_smoke)
 dock_life=preload("res://scripts/opening/harbor_dock_life.gd").new();dock_life.world=self;add_child(dock_life)
 foliage_study=preload("res://scripts/opening/harbor_foliage_study.gd").new();foliage_study.garden=square_garden;add_child(foliage_study)
 geometry_count+=cargo_street.geometry_count+square_garden.geometry_count+bench_life.geometry_count+passage_cargo.geometry_count+passenger_forecourt.geometry_count+city_matte.geometry_count+hybrid_waterfront.geometry_count+horizon_fill.geometry_count
func _environment() -> void:
 var world:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_SKY
 env.sky=preload("res://scripts/opening/harbor_clear_sky.gd").make_sky()
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("cbdff1");env.ambient_light_energy=.32
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.tonemap_exposure=.72;env.fog_enabled=false
 world.environment=env;add_child(world)
 var sun:=DirectionalLight3D.new();sun.name="WarmAfternoonSun";sun.rotation_degrees=Vector3(-48,-38,0);sun.light_color=Color("ffe2b6");sun.light_energy=.6;sun.shadow_enabled=true;sun.directional_shadow_max_distance=80;add_child(sun)
func _water() -> void:
 sea_surface=preload("res://scripts/opening/harbor_sea_surface.gd").new()
 add_child(sea_surface)
 water_material=sea_surface.water_material
func _box(at: Vector3,size: Vector3,mat: Material,solid: bool=false) -> void:
 main.box(at,size,mat)
 if solid:
  var body:=StaticBody3D.new();body.position=at;body.collision_layer=1;var c:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;c.shape=shape;body.add_child(c);add_child(body)
func _quay() -> void:
 var rect: Rect2=PlazaProfile.QUAY_RECT
 var center: Vector2=rect.get_center()
 _box(Vector3(center.x,-.6,center.y),Vector3(rect.size.x,1.2,rect.size.y),materials.stone,true)
 var random:=RandomNumberGenerator.new();random.seed=7711
 # Crop staggered paving to the exact masonry boundary instead of toothy overhangs.
 for row in 18:
  for col in range(-1,41):
   var left: float=maxf(rect.position.x,-18.0+col+.5*(row%2))
   var right: float=minf(rect.end.x,-17.0+col+.5*(row%2))
   if right-left<.08:continue
   var z: float=2.1+(row+.5)*16.0/18.0
   var top: float=maxf(rect.position.y,z-8.0/18.0)
   var bottom: float=minf(rect.end.y,z+8.0/18.0)
   if bottom-top<.05:continue
   main.box(Vector3((left+right)*.5,.015,(top+bottom)*.5),Vector3(right-left-.035,.055,bottom-top-.035),materials.stone if random.randf()>.35 else materials.stone2)
 for i in 40:
  if i in [22,23,24,25,26]:continue # Boarding opening in the quay curb.
  main.box(Vector3(-17+i,.16,2.12),Vector3(.95,.3,.5),materials.cream)
  main.box(Vector3(-17+i,-.6,2.13),Vector3(.93,.95,.15),materials.stone2)
 for x in [-12.0,-6.0,0.0,4.5,12.0,19.0]:
  main.cylinder(Vector3(x,.26,2.1),.16,.55,materials.iron)
  main.box(Vector3(x,.49,2.1),Vector3(.52,.12,.19),materials.iron)
func _cafe() -> void:
 plaza=preload("res://scripts/opening/harbor_cafe_plaza.gd").new();plaza.materials=materials;add_child(plaza)
 cup=plaza.cup
 life=preload("res://scripts/opening/harbor_plaza_life.gd").new();life.materials=materials;add_child(life);plaza.life=life
 town_routes=preload("res://scripts/opening/harbor_town_routes.gd").new();town_routes.materials=materials;add_child(town_routes)
 quay_edge=preload("res://scripts/opening/harbor_quay_edge.gd").new();quay_edge.materials=materials;add_child(quay_edge)
func _table(at: Vector3) -> void:
 main.cylinder(at+Vector3.UP*.46,.7,.08,materials.wood,32)
 main.cylinder(at+Vector3.UP*.23,.055,.43,materials.iron)
 for i in 3:
  var direction:=Vector3(cos(TAU*i/3),0,sin(TAU*i/3));main.beam(at+Vector3.UP*.22,at+direction*.4+Vector3.UP*.04,.05,materials.iron)
func _chair(at: Vector3) -> void:
 main.cylinder(at+Vector3.UP*.27,.27,.06,materials.wood)
 for x in [-.19,.19]:
  for z in [-.18,.18]:main.beam(at+Vector3(x,.28,z),at+Vector3(x*.9,.02,z*.9),.045,materials.darkwood)
  main.beam(at+Vector3(x,.25,-.2),at+Vector3(x,.87,-.65),.035,materials.darkwood)
 for y in [.56,.74]:main.box(at+Vector3(0,y,-.2-(y-.25)*.72),Vector3(.43,.1,.05),materials.wood)
func _plant(at: Vector3,size_: float) -> void:
 main.cylinder(at+Vector3.UP*size_*.4,size_*.35,size_*.8,materials.clay,12,size_*.46)
 for i in 7:
  var angle: float=i*TAU/7
  main.boulder(at+Vector3(cos(angle)*size_*.25,size_*1.1,sin(angle)*size_*.25),Vector3(.22,.6,.25)*size_*1.8,materials.leaves,7740+i)
func _sign(at: Vector3,text_: String,font_size_: int,color_: Color,size_: Vector2) -> void:
 main.box(at,Vector3(size_.x,size_.y,.06),materials.teal)
 var label:=Label3D.new();label.text=text_;label.font_size=font_size_;label.pixel_size=.006;label.position=at+Vector3(0,0,.04);label.modulate=color_;label.outline_size=2;label.no_depth_test=false;add_child(label)
func _new_npc(profile: Dictionary,path: Array[Vector3],working: bool=false,aboard: bool=false):
 profile=profile.duplicate(true)
 if _hair_bag.is_empty():
  for style in 10:_hair_bag.append(style)
  for i in range(9,0,-1):
   var j: int=_looks_rng.randi_range(0,i)
   var swap: int=_hair_bag[i];_hair_bag[i]=_hair_bag[j];_hair_bag[j]=swap
 profile.hairstyle=_hair_bag.pop_front()
 profile.male=_looks_rng.randf()<.5
 profile.hair=Appearance.HAIR[_looks_rng.randi_range(0,9)]
 profile.skin=Appearance.SKIN[_looks_rng.randi_range(0,9)]
 profile.cap=false
 if not profile.male:profile.beard=false
 var npc=NPC.new();npc.profile=profile;npc.route=path;npc.work=working;npc.speed=float(profile.get("speed",.8));npc.name=profile.id
 add_child(npc)
 if aboard:crew.append(npc)
 else:townspeople.append(npc)
 return npc
func _living_harbor() -> void:
 _looks_rng.seed=appearance_seed
 _hair_bag.clear()
 var vendor_profiles: Array=[
  {"id":"bread_seller","hair":"936c48","coat":"81714f","hat":"d5c49b","skin":"f0d2ae","apron":true,"phase":0},
  {"id":"fish_seller","hair":"554a42","coat":"597f88","hat":"4b6175","skin":"dcb58d","apron":true,"beard":true,"phase":2},
  {"id":"pot_seller","hair":"8a5950","coat":"a57061","hat":"bd997a","skin":"f1ccad","apron":true,"phase":4}]
 for i in 3:
  var path: Array[Vector3]=[Vector3(1.5+i*4.4,.04,9.05)]
  _new_npc(vendor_profiles[i],path,true)
 var carry_path: Array[Vector3]=[Vector3(1.1,.04,4.6),Vector3(9.4,.04,4.6)]
 _new_npc({"id":"yard_porter","hair":"665245","coat":"637a73","hat":"9d8869","skin":"dfba93","carry":true,"speed":1.0,"phase":1},carry_path,true)
 var street_path: Array[Vector3]=[Vector3(.6,.04,11.6),Vector3(9.1,.04,11.6)]
 _new_npc({"id":"market_porter","hair":"514d4b","coat":"8a715c","hat":"777369","skin":"efd2b3","carry":true,"speed":.85,"phase":4},street_path,true)
 var rope_path: Array[Vector3]=[Vector3(9.5,.04,6.3)]
 _new_npc({"id":"yard_ropehand","hair":"8c8377","coat":"6b7e8b","hat":"b6a98a","beard":true,"phase":6},rope_path,true)
 var buyer_path: Array[Vector3]=[Vector3(5.1,.04,10.95)]
 var buyer=_new_npc({"id":"market_customer","hair":"634c45","coat":"797193","hat":"a4a08e","skin":"e6bc98","phase":5},buyer_path);buyer.aim=Vector3.FORWARD
 var cafe_path: Array[Vector3]=[PlazaProfile.CAFE+Vector3(-1,.0,4)]
 var standing_guest=_new_npc({"id":"cafe_patron","hair":"a27a4d","coat":"aa8064","hat":"c9af85","cap":false,"skin":"f4d4b5","phase":3},cafe_path)
 var guest_slot: int=townspeople.find(standing_guest)
 var seated_guest=life.adopt_patron(standing_guest.profile)
 standing_guest.free();townspeople[guest_slot]=seated_guest
 var deck: float=ship.position.y+2.865
 var loading_path: Array[Vector3]=[Vector3(1.4,deck,-5.9),Vector3(9.8,deck,-5.9)]
 _new_npc({"id":"deck_porter","hair":"6a594c","coat":"607b8c","hat":"c7c6ae","carry":false,"speed":.85,"phase":0},loading_path,true,true)
 var sweep_path: Array[Vector3]=[Vector3(10.0,deck,-8.9),Vector3(15.8,deck,-8.9)]
 _new_npc({"id":"deck_sweeper","hair":"8c7152","coat":"697f8e","hat":"c7c6ae","broom":true,"speed":.65,"phase":4},sweep_path,true,true)
 var tie_path: Array[Vector3]=[Vector3(1.1,deck,-4.9)]
 _new_npc({"id":"deck_ropehand","hair":"6b5b4a","coat":"6c8790","hat":"c7c6ae","phase":6},tie_path,true,true)
 var mate_path: Array[Vector3]=[Vector3(18.5,deck,-6.4)]
 _new_npc({"id":"deck_mate","hair":"817b71","coat":"3f5a6b","hat":"4b5c6c","beard":true,"phase":3},mate_path,true,true)
 var tools=Detail.new();tools.name="DepartureSupplies";add_child(tools)
 departure_supplies=tools
 tools.finish();geometry_count+=tools.count
 var homes: Array[Vector3]=[Vector3(-3.8,.04,5.8),Vector3(-1.3,.04,5.6),Vector3(1,.04,12.3),Vector3(5.4,.04,12.7),Vector3(10.6,.04,12.4),Vector3(14.8,.04,6.1)]
 for i in homes.size():
  var bird=Pigeon.new();bird.name="HarborPigeon"+str(i);bird.home=homes[i];bird.phase=i*2.1;add_child(bird);pigeons.append(bird)
func _clear_boarding_apron_people() -> void:
 # Consume the original appearance seed first, then remove only this workplace.
 # Every retained cafe/deck resident keeps their accepted appearance.
 for actor in townspeople.duplicate():
  if String(actor.profile.id) in ["bread_seller","fish_seller","pot_seller","yard_porter","market_porter","yard_ropehand","market_customer"]:
   townspeople.erase(actor);actor.free()
func _pier() -> void:
 _box(Vector3(7,.27,-.3),Vector3(4,.32,5.2),materials.darkwood,true)
 for i in 25:main.box(Vector3(7,.375,2.2-i*.21),Vector3(4,.11,.19),materials.wood)
 for x in [5.1,8.9]:
  for z in [1.9,-.2,-2.4]:
   main.cylinder(Vector3(x,-.4,z),.12,1.8,materials.darkwood)
 Gangway.build(main,Gangway.DEPARTURE_SHORE,Gangway.DEPARTURE_DECK)
 for at in [Vector3(9,0,3.4),Vector3(15,0,4.1),Vector3(17,0,3.0)]:
  main.box(at+Vector3.UP*.4,Vector3(.9,.8,.8),materials.wood)
  for sign_ in [-1.0,1.0]:main.box(at+Vector3(sign_*.3,.4,.42),Vector3(.09,.8,.06),materials.darkwood)
  main.beam(at+Vector3(-.42,.06,.45),at+Vector3(.42,.76,.45),.055,materials.gold)
func _distant() -> void:
 backdrop=preload("res://scripts/opening/harbor_backdrop.gd").new();add_child(backdrop)
 lighthouse=preload("res://scripts/opening/harbor_lighthouse.gd").new();add_child(lighthouse)
 for at in [Vector3(39,0,-90)]:
  main.boulder(at,Vector3(4,.8,1.3),materials.darkwood,7980)
  main.beam(at,at+Vector3.UP*4.6,.04,materials.wood)
  main.quad(at+Vector3(0,4.3,0),at+Vector3(1.9,.7,0),at+Vector3(0,.7,0),at+Vector3(0,4.3,0),materials.canvas)
func _solid_box(at: Vector3,size_: Vector3) -> void:
 var body:=StaticBody3D.new();body.position=at;body.collision_layer=1
 var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size_;col.shape=shape;body.add_child(col);add_child(body)
func _walking_surfaces() -> void:
 for x in range(-12,13):
  var width: float=4.0*pow(sin((x+14.2)/28.4*PI),.45)
  _solid_box(ship.position+Vector3(x,2.8,0),Vector3(.99,.13,width*2))
  for side in [-1.0,1.0]:
   if absf(float(x)-Gangway.ENTRY_LOCAL_X)<Gangway.WIDTH*.5+.60:continue
   _solid_box(ship.position+Vector3(x,3.25,side*width),Vector3(1.0,.9,.12))
 _solid_box(ship.position+Vector3(-9.5,4.1,0),Vector3(5,2.5,5.1))
 _ramp_surface(Gangway.DEPARTURE_SHORE,Gangway.DEPARTURE_DECK,Gangway.WIDTH,Gangway.DEPARTURE_LANDING,"BoardingGangwayFloor")
 for side in [-1.0,1.0]:_boarding_rail(side)
 _ramp_surface(Vector3(7,.045,3.2),Vector3(7,.43,2.5),3.8,Vector3(7,.43,2.1))
 var lip=Detail.new();add_child(lip)
 lip.quad(Vector3(5.1,.045,3.2),Vector3(8.9,.045,3.2),Vector3(8.9,.43,2.5),Vector3(5.1,.43,2.5),materials.wood)
 lip.quad(Vector3(5.1,.43,2.5),Vector3(8.9,.43,2.5),Vector3(8.9,.43,2.1),Vector3(5.1,.43,2.1),materials.wood)
 lip.finish();geometry_count+=2
func _ramp_surface(a: Vector3,b: Vector3,width: float,landing: Vector3=Vector3.INF,label: String="HarborRampSurface") -> void:
 var body:=StaticBody3D.new();body.name=label;var col:=CollisionShape3D.new();var shape:=ConvexPolygonShape3D.new()
 var points:=PackedVector3Array()
 var sections: Array[Vector3]=[a,b]
 if landing!=Vector3.INF:sections.append(landing)
 for x in [-width*.5,width*.5]:
  for at in sections:
   points.append(at+Vector3(x,0,0));points.append(at+Vector3(x,-.22,0))
 shape.points=points;col.shape=shape;body.add_child(col);add_child(body)
func _boarding_rail(side: float) -> void:
 var points:=PackedVector3Array()
 for center in [Gangway.DEPARTURE_SHORE,Gangway.DEPARTURE_DECK]:
  for offset in [-.045,.045]:
   for height in [.01,.96]:points.append(center+Vector3(side*Gangway.WIDTH*.5+offset,height,0))
 var shape:=ConvexPolygonShape3D.new();shape.points=points
 var collision:=CollisionShape3D.new();collision.shape=shape
 var body:=StaticBody3D.new();body.name="BoardingRopeRail";body.add_to_group("harbor_boarding_rail");body.add_child(collision);add_child(body)
func _seated_hero() -> void:
 hero=Sprite3D.new();hero.name="SeatedProtagonist";hero.texture=Coffee.seated();hero.pixel_size=.018;hero.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;hero.shaded=false;hero.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;add_child(hero)
 var image:=Image.create(24,24,false,Image.FORMAT_RGBA8)
 for y in 24:
  for x in 24:
   var d: float=Vector2(x-11.5,y-11.5).length()/12;image.set_pixel(x,y,Color(1,.98,.9,pow(maxf(0,1-d),2)*.3))
 for i in 5:
  var puff:=Sprite3D.new();puff.texture=ImageTexture.create_from_image(image);puff.pixel_size=.007;puff.shaded=false;puff.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR;puff.transparency=.35;add_child(puff);steam.append(puff)
func tick(delta: float,camera: Camera3D) -> void:
 clock+=delta
 ship.visual_root.transform=Swell.pose(clock,0.0,2.1)
 departure_supplies.transform=ship.transform*ship.visual_root.transform*ship.transform.affine_inverse()
 ship_water.tick(delta)
 arrival.tick(delta,camera);backdrop.set_arrival_ready(arrival.docked);_tick_population(delta,camera);backdrop.tick(delta,camera,clock)
 ship_water.set_sea_clock(clock);arrival.water_contact.set_sea_clock(clock)
 backdrop.district.apply_ship_motion(arrival,camera)
 plaza.tick(delta,camera,clock)
 square_garden.tick(delta,camera,clock)
 dock_life.tick(delta,camera,clock)
 foliage_study.tick(delta,camera,clock)
 chimney_smoke.tick(delta,camera,clock)
 bench_life.tick(delta,camera,clock)
 passenger_forecourt.tick(delta,camera,clock)
 cargo_street.tick(delta,camera,clock)
 life.tick(delta,camera,clock)
 public_solids.tick()
 sea_surface.set_clock(clock)
 for mat in cloth_materials:mat.set_shader_parameter("clock",clock)
 hero.global_basis=camera.global_basis;hero.global_position=anchors.cafe+camera.global_basis.y*hero_offset
 var lift:=0.0;var frame:=0
 if sip_enabled and (hero.visible or modular_protagonist):
  sip_age+=delta;var t: float=fposmod(sip_age,8.0)
  if t>=4.8 and t<5.25:frame=1;lift=smoothstep(4.8,5.25,t)*.25
  elif t>=5.25 and t<5.7:frame=2;lift=lerpf(.25,1,smoothstep(5.25,5.7,t))
  elif t>=5.7 and t<6.4:frame=3;lift=1.0
  elif t>=6.4 and t<6.9:frame=4;lift=1-smoothstep(6.4,6.9,t)
  elif t>=6.9 and t<7.4:frame=5
  if hero.visible:hero.texture=Coffee.sipping(frame)
 sip_lift=lift
 cup.global_position=PlazaProfile.CUP_REST.lerp(anchors.cafe+camera.global_basis.x*.38+camera.global_basis.y*.72,lift)
 for i in steam.size():
  var t:=fposmod(clock*.30+i*.2,1)
  steam[i].global_basis=camera.global_basis;steam[i].global_position=cup.global_position+Vector3(sin(t*5+i)*.035,.09+t*.55,0);steam[i].modulate.a=(1-t)*.8;steam[i].scale=Vector3.ONE*(.6+t*.7)

func _tick_population(delta: float,camera: Camera3D) -> void:
 var positions: Array[Vector3]=[anchors.cafe]
 for npc in townspeople+crew:
  if not npc.get_meta("social_life_owned",false):npc.tick(delta,camera,clock)
  positions.append(npc.global_position)
 for npc in crew:npc.apply_deck_offset(main_ship_offset(npc.global_position),camera)
 for bird in pigeons:bird.tick(delta,camera,clock,positions)
func main_ship_offset(rest_world_point: Vector3) -> Vector3:
 var local: Vector3=ship.global_transform.affine_inverse()*rest_world_point
 return ship.global_transform*(ship.visual_root.transform*local)-rest_world_point
