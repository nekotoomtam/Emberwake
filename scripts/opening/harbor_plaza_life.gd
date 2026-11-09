extends Node3D
## Native props and four personally owned social actors in harbor coordinates.
const Detail=preload("res://scripts/opening/harbor_detail.gd")
const Actor=preload("res://scripts/opening/harbor_social_actor.gd")
const Art=preload("res://scripts/opening/harbor_social_art.gd")
const Appearance=preload("res://scripts/opening/npc_appearance.gd")
const TABLE_CENTER:=Vector3(-47.3,.055,-8.2)
var materials: Dictionary={}
var geometry_count:=0
var portrait_pair: Array[Node3D]=[]
var coffee_pair: Array[Node3D]=[]
var actors: Array=[]
var cups: Array[Node3D]=[]
var saucers: Array[Vector3]=[]
var main
var _collider_id:=0
func _ready() -> void:
 for entry in [["wood","956d51","wood"],["darkwood","5d483d","wood"],["cream","e9dabb","plaster"],["iron","3e5357","slate"],["gold","cfa76f","wood"],["coffee","493329","wood"],["teal","487d80","wood"],["red","ba6f5b","plaster"]]:
  if not materials.has(entry[0]):materials[entry[0]]=Detail.material(entry[1],entry[2],8710+materials.size())
 main=Detail.new();main.name="HarborSocialNativeProps";add_child(main)
 _coffee_scene();_portrait_scene();main.finish();geometry_count+=main.count
 for mug in cups:geometry_count+=mug.count
func _solid(at: Vector3,size_: Vector3,group: String) -> void:
 var body:=StaticBody3D.new();body.name="SocialPropCollision"+str(_collider_id);_collider_id+=1;body.position=at;body.collision_layer=1;body.add_to_group(group)
 var shape:=BoxShape3D.new();shape.size=size_;var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);add_child(body)
func _round_solid(at: Vector3,radius: float,height: float,group: String) -> void:
 var body:=StaticBody3D.new();body.name="SocialRoundCollision"+str(_collider_id);_collider_id+=1;body.position=at;body.collision_layer=1;body.add_to_group(group)
 var shape:=CylinderShape3D.new();shape.radius=radius;shape.height=height;var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);add_child(body)
func _new_actor(id: String,role_: String,at: Vector3,profile_: Dictionary,side: String="front",phase: float=0.0) -> Node3D:
 var actor=Actor.new();actor.name=id;actor.profile=profile_.duplicate(true);actor.profile.id=id;actor.role=role_;actor.position=at;actor.facing_side=side;actor.time_phase=phase;actor.set_meta("social_life_owned",true);add_child(actor);actors.append(actor);return actor
func _chair(at: Vector3,inward: float) -> void:
 # Seat, feet and back face the table on the x axis; actor pelvis meets y=.40.
 main.box(at+Vector3.UP*.40,Vector3(.53,.075,.53),materials.wood)
 for x in [-.21,.21]:
  for z in [-.21,.21]:main.beam(at+Vector3(x,.39,z),at+Vector3(x*.94,.025,z*.94),.045,materials.darkwood)
 for z in [-.22,.22]:main.beam(at+Vector3(-inward*.23,.4,z),at+Vector3(-inward*.37,1.0,z),.04,materials.darkwood)
 for y in [.67,.88]:main.box(at+Vector3(-inward*(.23+(y-.4)*.23),y,0),Vector3(.05,.12,.51),materials.wood)
 _solid(at+Vector3(0,.50,0),Vector3(.58,1.0,.58),"harbor_social_chair")
func _coffee_scene() -> void:
 main.cylinder(TABLE_CENTER+Vector3.UP*.46,.71,.08,materials.wood,32)
 main.cylinder(TABLE_CENTER+Vector3.UP*.23,.055,.43,materials.iron,16)
 for i in 3:
  var radial:=Vector3(cos(TAU*i/3),0,sin(TAU*i/3));main.beam(TABLE_CENTER+Vector3.UP*.25,TABLE_CENTER+radial*.45+Vector3.UP*.035,.05,materials.iron)
 _round_solid(TABLE_CENTER+Vector3.UP*.25,.71,.50,"harbor_social_table")
 var profiles: Array[Dictionary]=[
  {"id":"CafeReader","hairstyle":7,"male":false,"hair":Appearance.HAIR[7],"skin":Appearance.SKIN[1],"coat":"b28c67","cap":false,"phase":7},
  {"id":"cafe_patron","hairstyle":2,"male":true,"hair":"a27a4d","skin":"f4d4b5","coat":"aa8064","cap":false,"phase":3}]
 for i in 2:
  var inward: float=1.0 if i==0 else -1.0
  var seat: Vector3=TABLE_CENTER+Vector3(-.95 if i==0 else .95,0,0)
  _chair(seat,inward)
  var actor=_new_actor(profiles[i].id,"coffee",seat,profiles[i],"right" if i==0 else "left",float(i)*4.8)
  var saucer: Vector3=TABLE_CENTER+Vector3(-.54 if i==0 else .54,.512,.04)
  actor.saucer=saucer;actor.cup_rest=saucer+Vector3.UP*.078
  actor.cup_mouth=seat+Vector3(inward*.24,.80,.035)
  main.cylinder(saucer,.145,.024,materials.cream,24)
  main.cylinder(saucer+Vector3.UP*.014,.095,.008,materials.cream,24)
  var mug=Detail.new();mug.name="CafeReaderCup" if i==0 else "CafePatronCup";mug.position=actor.cup_rest;add_child(mug)
  mug.cylinder(Vector3.ZERO,.073,.13,materials.cream,24,.091);mug.cylinder(Vector3(0,.068,0),.076,.005,materials.coffee,24)
  var handle: Array[Vector3]=[Vector3(-inward*.07,.04,0),Vector3(-inward*.16,.04,0),Vector3(-inward*.18,-.03,0),Vector3(-inward*.08,-.04,0)]
  mug.tube(handle,.018,materials.cream,.9);mug.finish();actor.cup=mug;cups.append(mug);saucers.append(saucer);coffee_pair.append(actor)
 # Two spoons and a modest sugar bowl keep the table visibly shared.
 main.cylinder(TABLE_CENTER+Vector3(0,.56,-.24),.075,.10,materials.cream,16)
 main.cylinder(TABLE_CENTER+Vector3(0,.62,-.24),.083,.02,materials.cream,16,.04)
 for side in [-1.0,1.0]:main.beam(TABLE_CENTER+Vector3(side*.27,.511,.28),TABLE_CENTER+Vector3(side*.41,.511,.31),.018,materials.iron)
func adopt_patron(profile: Dictionary) -> Node3D:
 var actor: Node3D=coffee_pair[1];actor.profile=profile.duplicate(true);actor.name=str(profile.get("id","cafe_patron"));return actor
func _portrait_scene() -> void:
 var artist_profile: Dictionary={"id":"WaterfrontPainter","hairstyle":2,"male":true,"hair":"6f5a48","skin":"d29b77","coat":"527b7c","cap":false,"phase":1}
 var model_profile: Dictionary={"id":"PortraitSitter","hairstyle":8,"male":false,"hair":"68624f","skin":"d7ae87","coat":"a3747c","cap":false,"phase":4}
 var painter=_new_actor("WaterfrontPainter","painter",Vector3(-22.8,.055,.8),artist_profile,"right")
 var model=_new_actor("PortraitSitter","model",Vector3(-20.8,.055,-2),model_profile,"front",1.7)
 portrait_pair.assign([painter,model])
 var easel:=Vector3(-22,.055,.1)
 # The easel is a real wooden tripod with a lower shelf and stretched canvas.
 for x in [-.39,.39]:
  main.beam(easel+Vector3(x,.04,.22),easel+Vector3(x*.67,1.94,-.04),.045,materials.darkwood)
 main.beam(easel+Vector3(0,.04,-.55),easel+Vector3(0,1.64,0),.045,materials.darkwood)
 main.box(easel+Vector3(0,.81,.055),Vector3(1.01,.07,.17),materials.wood)
 main.box(easel+Vector3(0,1.73,.035),Vector3(.89,.06,.08),materials.wood)
 main.box(easel+Vector3(0,1.28,.04),Vector3(.83,.89,.055),materials.cream)
 var painting:=Sprite3D.new();painting.name="OriginalPaintedPortrait";painting.texture=Art.portrait();painting.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;painting.pixel_size=.0185;painting.position=easel+Vector3(0,1.28,.073);painting.shaded=false;add_child(painting)
 _solid(easel+Vector3(0,.86,-.10),Vector3(.88,1.72,.68),"harbor_artist_easel")
 # Paint box and jars sit at the easel's feet, inside the same prop footprint.
 main.box(easel+Vector3(.13,.12,.12),Vector3(.44,.22,.27),materials.wood)
 main.box(easel+Vector3(.13,.235,.12),Vector3(.47,.025,.30),materials.darkwood)
 main.cylinder(easel+Vector3(-.27,.16,.14),.072,.27,materials.cream,12)
 for i in 3:main.beam(easel+Vector3(-.29+float(i)*.02,.25,.13),easel+Vector3(-.31+float(i)*.035,.49,.15),.011,materials.darkwood)
 var brush=Detail.new();brush.name="PainterWorkingBrush";brush.position=painter.position+Vector3(.62,.80,-.09);add_child(brush)
 brush.beam(Vector3.ZERO,Vector3(.23,.03,-.19),.014,materials.darkwood);brush.beam(Vector3(.23,.03,-.19),Vector3(.29,.04,-.24),.021,materials.cream);brush.finish();painter.brush=brush
 var palette=Detail.new();palette.name="PainterHandPalette";palette.position=painter.position+Vector3(-.18,.40,.08);add_child(palette)
 palette.cylinder(Vector3.ZERO,.12,.025,materials.wood,14)
 for i in 3:palette.cylinder(Vector3(-.065+float(i)*.065,.018,.035),.025,.008,[materials.red,materials.teal,materials.gold][i],8)
 palette.finish();painter.palette_prop=palette;geometry_count+=palette.count+brush.count
 # A small mat marks the model's selected standing spot without collision.
 main.box(model.position+Vector3(0,.006,0),Vector3(.84,.012,.71),materials.cream)
func tick(delta: float,camera: Camera3D,clock: float) -> void:
 for actor in actors:actor.tick(delta,camera,clock)
