extends Node3D
## Connected coastal approach and western street with an authored solid end.
const Detail=preload("res://scripts/opening/harbor_detail.gd")
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
const LoadingStreet=preload("res://scripts/opening/harbor_loading_street.gd")
const PromenadePaving=preload("res://scripts/opening/harbor_promenade_paving.gd")
var materials: Dictionary={}
var geometry_count:=0
var north_region:=Profile.NORTH_APPROACH_RECT
var west_region:=Profile.WEST_STREET_RECT
var west_approach:=Profile.WEST_APPROACH_RECT
var main
var end_geometry
var promenade
var _collider_id:=0
func _ready() -> void:
 name="HarborTownRoutes"
 for entry in [["town_cobble","9a9c92","plaster"],["town_cobble_light","aaa99b","plaster"],["town_cobble_dark","898f86","plaster"],["town_gutter","727d76","slate"],["town_flag","c6bfae","plaster"],["town_masonry","898e87","slate"],["stone","b7b0a0","plaster"],["stone2","a7a596","plaster"],["cream","e9dabb","plaster"],["iron","3e5357","slate"],["canvas","eddfb9","plaster"],["gold","cfa76f","wood"],["town_wall","b4aa94","plaster"],["town_roof","6e6e68","slate"],["town_glass","7d9b9b","plaster"],["town_wood","8e7054","wood"],["town_darkwood","5e5144","wood"],["town_brick","ae8c72","brick"]]:
  if not materials.has(entry[0]):materials[entry[0]]=Detail.material(entry[1],entry[2],9370+materials.size())
 LoadingStreet.ensure_road_materials(materials)
 main=Detail.new();main.name="TownRouteAuthoredGeometry";add_child(main)
 _west_street();_north_approach();_retained_geometry_collision()
 var paving=main
 end_geometry=Detail.new();end_geometry.name="TownEndFacadeGeometry";add_child(end_geometry)
 main=end_geometry;_town_end();end_geometry.finish();main=paving
 promenade=PromenadePaving.new();promenade.materials=materials;add_child(promenade)
 geometry_count=main.count+end_geometry.count+promenade.geometry_count;main.finish()
func _body_box(label: String,at: Vector3,size_: Vector3,group: String) -> void:
 var body:=StaticBody3D.new();body.name=label+str(_collider_id);_collider_id+=1;body.position=at;body.collision_layer=1;body.add_to_group(group)
 var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size_;collision.shape=shape;body.add_child(collision);add_child(body)
func _floor(rect: Rect2,label: String,draw_base: bool=true) -> void:
 var center:=rect.get_center()
 # Physical slabs meet the square exactly at .055, including the x=-51 seam.
 # The inset visual mortar stays below the individual flush paving stones.
 _body_box(label,Vector3(center.x,Profile.CAFE.y-.55,center.y),Vector3(rect.size.x,1.1,rect.size.y),"harbor_town_ground")
 if draw_base:main.box(Vector3(center.x,Profile.CAFE.y-.565,center.y),Vector3(rect.size.x,1.1,rect.size.y),materials.town_masonry)
func _flags(rect: Rect2) -> void:
 var rows:=maxi(1,int(ceil(rect.size.y/.93)));var step_z: float=rect.size.y/rows
 var columns:=maxi(1,int(ceil(rect.size.x/.94)));var step_x: float=rect.size.x/columns
 for row in rows:
  for col in columns:
   var at:=Vector3(rect.position.x+(col+.5)*step_x,Profile.CAFE.y-.016,rect.position.y+(row+.5)*step_z)
   main.box(at,Vector3(step_x-.026,.031,step_z-.026),materials.town_flag if (row*7+col)%5 else materials.stone)
func _west_street() -> void:
 _floor(west_region,"WestTownStreetFloor")
 _floor(Profile.SEAFRONT_RECT,"IncomingSeafrontFloor")
 # The north/south street terminates at the warehouse facade. Its carriageway
 # joins the east/west road at z=6.3; no footway or gutter crosses the junction.
 var carriageway:=Rect2(Vector2(-61.55,-21),Vector2(8.10,27.3))
 _flags(Rect2(Vector2(-64,-21),Vector2(2.27,27.3)))
 _flags(Rect2(Vector2(-79,15.4),Vector2(28,2.1)))
 var rows:=int(ceil(carriageway.size.y/.35));var step_z: float=carriageway.size.y/rows
 var columns:=int(ceil(carriageway.size.x/.50));var step_x: float=carriageway.size.x/columns
 var random:=RandomNumberGenerator.new();random.seed=9387
 for row in rows:
  var z: float=carriageway.position.y+(row+.5)*step_z
  for col in range(-1,columns):
   var left: float=maxf(carriageway.position.x,carriageway.position.x+(col+(row%2)*.5)*step_x)
   var right: float=minf(carriageway.end.x,carriageway.position.x+(col+1+(row%2)*.5)*step_x)
   if right-left<.04:continue
   var shade: float=random.randf();var material_: Material=materials.town_cobble
   if shade<.22:material_=materials.town_cobble_dark
   elif shade>.80:material_=materials.town_cobble_light
   main.box(Vector3((left+right)*.5,Profile.CAFE.y-.007,z),Vector3(right-left-.022,.014,step_z-.024),material_)
 for x in [-61.64]:
  main.box(Vector3(x,Profile.CAFE.y-.007,-7.35),Vector3(.18,.014,27.3),materials.stone2)
  for row in 32:
   var z: float=-21+(row+.5)*27.3/32
   main.box(Vector3(x,Profile.CAFE.y+.001,z),Vector3(.17,.003,.024),materials.town_gutter)
 for x in [-61.42,-53.58]:
  main.box(Vector3(x,Profile.CAFE.y-.008,-7.35),Vector3(.18,.012,27.3),materials.town_gutter)
  for z in [-19.0,-7.0,5.0]:_drain(Vector3(x,Profile.CAFE.y,z))
 LoadingStreet.cobble_road(main,Rect2(Vector2(-79,6.3),Vector2(29.5,9.1)),materials)
 main.box(Vector3(-64.25,Profile.CAFE.y+.005,15.4),Vector3(29.5,.016,.18),materials.stone2)
 for span in [Vector2(-79,-61.73)]:
  main.box(Vector3((span.x+span.y)*.5,Profile.CAFE.y+.005,6.3),Vector3(span.y-span.x,.016,.18),materials.stone2)
 # A low inland property wall gives the closed side footway a visible edge;
 # its southern end leaves the full seaside carriageway open.
 main.box(Vector3(-64,.46,-7.35),Vector3(.28,.81,27.3),materials.town_masonry)
 main.box(Vector3(-64,.91,-7.35),Vector3(.38,.10,27.3),materials.cream)
 _body_box("InlandPropertyWall",Vector3(-64,.505,-7.35),Vector3(.28,.90,27.3),"harbor_town_boundary")
 # Lamps belong to regular footway bands, leaving the middle and plaza seam open.
 for z in [-19.5,-10.0,2.0,16.4]:
  _lamp(Vector3(-63.35,Profile.CAFE.y,z))
  # The retained cafe already occupies the northeast frontage.
  if z> -15.0:_lamp(Vector3(-51.60,Profile.CAFE.y,z))
func _drain(at: Vector3) -> void:
 main.box(at+Vector3.DOWN*.006,Vector3(.22,.012,.60),materials.iron)
 for slot in 7:main.box(at+Vector3(0,.001,-.25+slot*.083),Vector3(.17,.003,.032),materials.town_gutter)
func _lamp(at: Vector3) -> void:
 main.cylinder(at+Vector3.UP*.12,.18,.24,materials.iron,12,.12)
 main.cylinder(at+Vector3.UP*1.73,.048,3.20,materials.iron,12,.035)
 main.cylinder(at+Vector3.UP*3.26,.17,.13,materials.iron,12,.23)
 main.box(at+Vector3.UP*3.55,Vector3(.29,.48,.29),materials.canvas)
 for x in [-.17,.17]:
  for z in [-.17,.17]:main.beam(at+Vector3(x,3.25,z),at+Vector3(x*.75,3.82,z*.75),.028,materials.iron)
 main.cylinder(at+Vector3.UP*3.86,.25,.19,materials.iron,4,.045)
 main.cylinder(at+Vector3.UP*4.02,.045,.16,materials.gold,8,.015)
 var body:=StaticBody3D.new();body.name="TownStreetLamp"+str(_collider_id);_collider_id+=1;body.position=at+Vector3.UP*1.7;body.collision_layer=1
 body.add_to_group("harbor_town_lamp");body.set_meta("ground_datum",at);body.set_meta("furniture_line","town_footway")
 var collision:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=.09;shape.height=3.4;collision.shape=shape;body.add_child(collision);add_child(body)
func _north_approach() -> void:
 # The first retained warehouse's actual wall ends at x=-27.3,z=-21.
 # Clip this 20cm corner rather than author supported floor inside that wall.
 _floor(Rect2(Vector2(-27.3,-22.5),Vector2(7.6,1.5)),"NorthWarehouseSideFloor")
 _floor(Rect2(Vector2(-27.5,-21),Vector2(7.8,4.2)),"NorthOpenApproachFloor",false)
 # South of z=-20 the cleared pottery frontage already has square paving.
 # Only the newly exposed northern strip needs additional matching flagstones.
 _flags(Rect2(Vector2(-27.3,-22.5),Vector2(7.6,1.5)))
 _flags(Rect2(Vector2(-27.5,-21),Vector2(7.8,1.0)))
func _town_end() -> void:
 var y: float=Profile.CAFE.y
 # A real two-storey stores building closes the western street. Its full wall
 # footprint is physical; the retained cafe roof sits independently to its east.
 var at:=Vector3(-57.5,y,-25)
 main.box(at+Vector3.UP*3.15,Vector3(13,6.3,8),materials.town_wall)
 _body_box("WestStreetEndStores",at+Vector3.UP*3.15,Vector3(13,6.3,8),"harbor_town_end_building")
 main.box(at+Vector3.UP*.20,Vector3(13,.40,8),materials.town_masonry)
 for height in [.42,3.15,6.28]:
  main.box(Vector3(-57.5,y+height,-20.96),Vector3(13,.16,.12),materials.cream)
 for x in [-63.82,-51.18]:
  for row in 12:main.box(Vector3(x,y+.65+row*.46,-20.92),Vector3(.32,.36,.17),materials.cream)
 for x in [-62.2,-59.9,-57.5,-55.1,-52.8]:
  main.box(Vector3(x,y+4.68,-20.91),Vector3(1.32,1.70,.16),materials.town_darkwood)
  main.box(Vector3(x,y+4.68,-20.80),Vector3(1.12,1.49,.06),materials.town_glass)
  main.box(Vector3(x,y+4.68,-20.75),Vector3(.065,1.49,.035),materials.cream)
  main.box(Vector3(x,y+4.55,-20.75),Vector3(1.12,.065,.035),materials.cream)
  main.box(Vector3(x,y+3.77,-20.87),Vector3(1.49,.13,.32),materials.cream)
 for x in [-60.9,-54.1]:
  main.box(Vector3(x,y+1.42,-20.89),Vector3(2.55,2.45,.18),materials.town_darkwood)
  for board in 8:main.box(Vector3(x-1.10+board*.315,y+1.42,-20.76),Vector3(.29,2.34,.10),materials.town_wood)
  for height in [.64,2.21]:main.box(Vector3(x,y+height,-20.69),Vector3(2.50,.13,.08),materials.iron)
 main.box(Vector3(-57.5,y+1.38,-20.88),Vector3(1.65,2.55,.18),materials.town_darkwood)
 for x in [-57.91,-57.09]:main.box(Vector3(x,y+1.84,-20.74),Vector3(.63,1.18,.08),materials.town_glass)
 main.box(Vector3(-57.5,y+.58,-20.73),Vector3(1.46,.70,.10),materials.town_wood)
 main.cylinder(Vector3(-57.02,y+1.20,-20.65),.045,.09,materials.gold,8)
 # Hipped slate roof: the east verge is inset, avoiding the cafe's west eave.
 var a:=Vector3(-64,y+6.42,-29);var b:=Vector3(-51.6,y+6.42,-29)
 var c:=Vector3(-51.6,y+6.42,-21);var d:=Vector3(-64,y+6.42,-21)
 var p:=Vector3(-62.6,y+8.10,-25);var q:=Vector3(-53.0,y+8.10,-25)
 main.quad(a,b,q,p,materials.town_roof);main.quad(d,p,q,c,materials.town_roof)
 main.quad(a,p,d,a,materials.town_roof);main.quad(b,c,q,b,materials.town_roof)
 main.box(Vector3(-51.30,y+6.38,-25),Vector3(.60,.23,8),materials.cream)
 main.beam(p,q,.14,materials.town_darkwood)
 main.box(Vector3(-62.3,y+7.4,-26.5),Vector3(.60,1.9,.65),materials.town_brick)
 main.box(Vector3(-62.3,y+8.35,-26.5),Vector3(.83,.15,.87),materials.cream)
 var sign_:=Label3D.new();sign_.name="WestStoresSign";sign_.text="MAGASINS  DU  QUAI";sign_.font_size=22;sign_.pixel_size=.009;sign_.outline_size=1;sign_.position=Vector3(-57.5,y+3.20,-20.78);sign_.modulate=Color("615a4d");add_child(sign_)
 _end_crate(Vector3(-53.0,y+.42,-19.4),Vector3(1.10,.84,.90))
 _end_crate(Vector3(-53.0,y+1.14,-19.4),Vector3(.83,.60,.78))
 _end_barrel(Vector3(-54.2,y,-19.2),.42,1.0)
 _end_handcart(Vector3(-61.8,y,-18.9))
func _end_crate(at: Vector3,size_: Vector3) -> void:
 main.box(at,size_,materials.town_wood)
 for x in [-size_.x*.4,size_.x*.4]:main.box(at+Vector3(x,0,size_.z*.5+.02),Vector3(.07,size_.y,.04),materials.town_darkwood)
 main.beam(at+Vector3(-size_.x*.4,-size_.y*.4,size_.z*.5+.04),at+Vector3(size_.x*.4,size_.y*.4,size_.z*.5+.04),.045,materials.town_darkwood)
 _body_box("EndStoresCrate",at,size_,"harbor_town_end_cargo")
func _end_barrel(at: Vector3,radius: float,height: float) -> void:
 main.cylinder(at+Vector3.UP*height*.5,radius,height,materials.town_wood,16)
 for height_ in [.10,.29,height-.25,height-.08]:main.cylinder(at+Vector3.UP*height_,radius+.012,.04,materials.iron,16)
 var body:=StaticBody3D.new();body.name="EndStoresBarrel";body.position=at+Vector3.UP*height*.5;body.collision_layer=1;body.add_to_group("harbor_town_end_cargo")
 var collision:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=radius+.012;shape.height=height;collision.shape=shape;body.add_child(collision);add_child(body)
func _end_handcart(at: Vector3) -> void:
 main.box(at+Vector3.UP*.62,Vector3(1.4,.18,1.65),materials.town_wood)
 _body_box("EndStoresHandcartBed",at+Vector3.UP*.62,Vector3(1.4,.18,1.65),"harbor_town_end_cargo")
 for side in [-1.0,1.0]:
  var center: Vector3=at+Vector3(side*.81,.39,.14)
  var ring: Array[Vector3]=[]
  for i in 17:
   var angle: float=TAU*i/16;ring.append(center+Vector3(0,cos(angle)*.37,sin(angle)*.37))
  main.tube(ring,.035,materials.iron,1)
  for i in 8:
   var angle: float=TAU*i/8;main.beam(center,center+Vector3(0,cos(angle)*.35,sin(angle)*.35),.035,materials.town_wood)
  var body:=StaticBody3D.new();body.name="EndStoresHandcartWheel"+str(side);body.position=center;body.rotation.z=PI*.5;body.collision_layer=1;body.add_to_group("harbor_town_end_cargo")
  var collision:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=.405;shape.height=.07;collision.shape=shape;body.add_child(collision);add_child(body)
  main.box(at+Vector3(side*.63,.90,0),Vector3(.08,.43,1.65),materials.town_wood)
  _body_box("EndStoresHandcartSide",at+Vector3(side*.63,.90,0),Vector3(.08,.43,1.65),"harbor_town_end_cargo")
  main.box(at+Vector3(side*.49,.62,1.35),Vector3(.07,.07,1.10),materials.town_darkwood)
  _body_box("EndStoresHandcartHandle",at+Vector3(side*.49,.62,1.35),Vector3(.07,.07,1.10),"harbor_town_end_cargo")
 _end_crate(at+Vector3(0,.94,-.15),Vector3(.95,.46,1.05))
func _retained_geometry_collision() -> void:
 # Visible objects that were scenic before the new public approach opened.
 # Preserve every warehouse mesh and port lamp; these shapes match them.
 # The first warehouse now owns matching bulk/side/header colliders around
 # its real receiving opening in harbor_backdrop.gd. A full scenic box here
 # would silently seal that doorway again.
 var body:=StaticBody3D.new();body.name="RetainedNorthPromenadePole";body.position=Vector3(-20.6,1.4,-22);body.collision_layer=1;body.add_to_group("harbor_town_boundary")
 var collision:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=.065;shape.height=2.8;collision.shape=shape;body.add_child(collision);add_child(body)
