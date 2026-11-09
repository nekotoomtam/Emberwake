extends Node3D
## Scenic coastal city: working frontage, market gaps, then compact inland blocks.
const Detail=preload("res://scripts/opening/harbor_detail.gd")
const Plaza=preload("res://scripts/opening/harbor_plaza_profile.gd")
const BERTH_Z: Array[float]=[-29.0,-72.0,-110.0,-148.0,-186.0]
var geometry_count:=0
var district
var warehouse_fronts: Array[Vector3]=[]
var buildings: Array=[]
var chimney_outlets: Array[Vector3]=[]
var markets: Array=[]
var loading_yards: Array=[]
var coastline_depth:=235.0
var coast_length:=235.0
var city_bounds:=Rect2(Vector2(-164,-220),Vector2(144,235))
var b
var mats: Dictionary={}
func _ready() -> void:
 name="CoastalTownBackdrop"
 b=Detail.new();add_child(b)
 for row in [["stone","b1aa97","plaster"],["mortar","898f86","slate"],["trim","d6c6a6","wood"],["roof","72615e","slate"],["glass","78949a","plaster"],["timber","6f655a","wood"],["cream","c6bca5","plaster"],["brick","a9907e","plaster"],["blue","9ba9a4","plaster"],["canvas","cbb992","plaster"],["red_canvas","a87968","plaster"],["green_canvas","879584","plaster"]]:
  mats[row[0]]=Detail.material(row[1],row[2],8300+mats.size())
 for key in ["canvas","red_canvas","green_canvas"]:mats[key].cull_mode=BaseMaterial3D.CULL_DISABLED
 # Inland scenery ends at the new real coastline. No old foundation slab may
 # project under the water south of the compact plaza or its connector.
 b.box(Vector3(-92,-1.2,-106.85),Vector3(144,2.4,226.3),mats.stone)
 b.box(Vector3(-121.5,-1.2,10.65),Vector3(85,2.4,8.7),mats.stone)
 b.box(Vector3(-51.5,-.6,10.85),Vector3(55,1.2,9.1),mats.stone)
 b.box(Vector3(-65,-.6,16.45),Vector3(28,1.2,2.1),mats.stone)
 for i in 98:
  var z: float=13.8-i*2.4
  if absf(z+29.0)<4.4:continue # Clear the masonry terminal throat and cargo walking lanes.
  # This former shore is now the open land connection to the original quay.
  if z+1.15>Plaza.CONNECTOR_RECT.position.y and z-1.15<Plaza.CONNECTOR_RECT.end.y:continue
  b.box(Vector3(-19.8,-.55,z),Vector3(.5,1.1,2.3),mats.mortar)
  b.box(Vector3(-19.6,.10,z),Vector3(.7,.25,2.3),mats.trim)
  # Public coping/rails are one continuous separate assembly; retain distant posts.
  # The nearest chunky post is omitted at the shop-side wrong-turn mouth.
  if i%3==0 and z<-24.5:b.box(Vector3(-19.3,.65,z),Vector3(.6,1.3,.6),mats.stone)
 _working_frontage()
 var rng:=RandomNumberGenerator.new();rng.seed=8319
 # 3-4m lanes divide compact 9-11m houses instead of overscaled empty streets.
 for row in 15:
  for col in 9:
   var z: float=3-row*14.5
   var x: float=-47-col*13.0
   # Two market squares and a civic court interrupt the roof grid.
   if (row in [4,5] and col in [1,2]) or (row in [9,10] and col in [3,4]) or (row in [7,8] and col in [6,7]):continue
   var at:=Vector3(x+(row%2)*.6,0,z)
   var w: float=rng.randf_range(7.6,9.6);var h: float=rng.randf_range(4.3,10.5);var d: float=rng.randf_range(8.4,10.9)
   # Test the full roof/foundation footprint, not just the house centre.
   # Keep the RNG draws in place so every retained block keeps its existing shape.
   if Plaza.reserve_overlaps(at,maxf(w*1.14,w+.25),maxf(d*1.16,d+.25)):continue
   _building(at,w,h,d,mats[["cream","brick","blue"][(row+col)%3]],false,row*9+col)
 _inland_market(Vector3(-66,0,-62),0)
 _inland_market(Vector3(-92,0,-135),1)
 _civic_roof(Vector3(-131,0,-106))
 # Smaller roofs taper the final coast and inland edge into a believable town silhouette.
 for j in 7:
  _building(Vector3(-32-j*15.5,0,-212),7.2,4.5+(j%3),8,mats.cream,false,200+j)
 geometry_count=b.count;b.finish()
 district=preload("res://scripts/opening/harbor_port_district.gd").new()
 district.warehouse_fronts=warehouse_fronts;add_child(district);geometry_count+=district.geometry_count
func _building(at: Vector3,w: float,h: float,d: float,wall: Material,warehouse: bool,index: int) -> void:
 if warehouse and index==0:
  # A shallow real receiving recess: the bulk and facade sides leave the
  # central3.2m doorway open, visually and in the native collision world.
  _warehouse_block(at+Vector3(-1.25,h*.5,0),Vector3(w-2.5,h,d),wall)
  for side in [-1.,1.]:_warehouse_block(at+Vector3(w*.5-1.25,h*.5,side*(d*.25+.8)),Vector3(2.5,h,d*.5-1.6),wall)
  _warehouse_block(at+Vector3(w*.5-1.25,(h+3.1)*.5,0),Vector3(2.5,h-3.1,3.2),wall)
 else:b.box(at+Vector3.UP*h*.5,Vector3(w,h,d),wall)
 if not (warehouse and index==0):b.box(at+Vector3.UP*.3,Vector3(w+.25,.6,d+.25),mats.mortar)
 var yf: float=h+.1;var peak: float=h+1.8+w*.12
 var a:=at+Vector3(-w*.57,yf,-d*.58);var c:=at+Vector3(w*.57,yf,-d*.58)
 var e:=at+Vector3(-w*.57,yf,d*.58);var f:=at+Vector3(w*.57,yf,d*.58)
 var p:=at+Vector3(0,peak,-d*.58);var q:=at+Vector3(0,peak,d*.58)
 b.quad(a,e,q,p,mats.roof);b.quad(p,q,f,c,mats.roof)
 b.quad(e,f,q,e,wall);b.quad(a,p,c,a,wall)
 b.beam(p,q,.13,mats.timber)
 b.box(at+Vector3(w*.25,peak,.2),Vector3(.65,2.2,.7),mats.brick)
 b.box(at+Vector3(w*.25,peak+1.05,.2),Vector3(.9,.18,.9),mats.trim)
 chimney_outlets.append(at+Vector3(w*.25,peak+1.16,.2))
 for level in range(1,int(h/2.3)+1):
  for bay in 3:
   var x: float=-w*.31+bay*w*.31;var y: float=level*2.2-.45
   b.box(at+Vector3(x,y,d*.5+.04),Vector3(.96,1.24,.10),mats.timber)
   b.box(at+Vector3(x,y,d*.5+.11),Vector3(.73,1.04,.06),mats.glass)
   b.box(at+Vector3(x,y,d*.5+.15),Vector3(.06,1.05,.04),mats.trim)
   b.box(at+Vector3(x,y-.2,d*.5+.16),Vector3(.74,.06,.04),mats.trim)
   b.box(at+Vector3(x,y-.68,d*.5+.14),Vector3(1.15,.12,.26),mats.trim)
  for bay in 3:
   if warehouse and level==1 and bay==1:continue
   b.box(at+Vector3(w*.5+.05,level*2.2-.45,-d*.30+bay*d*.30),Vector3(.10,1.1,.8),mats.glass)
 b.box(at+Vector3(0,.9,d*.5+.08),Vector3(.95,1.8,.12),mats.timber)
 if warehouse:
  var door:=at+Vector3(w*.5+.08,0,0);warehouse_fronts.append(door)
  if index==0:
   if not mats.has("receiving_shadow"):mats.receiving_shadow=Detail.material("293c3c","wood",10201)
   b.box(door+Vector3(-2.56,1.5,0),Vector3(.03,3.0,3.1),mats.receiving_shadow)
   for side in [-1.,1.]:b.box(door+Vector3(.04,1.55,side*1.65),Vector3(.16,3.1,.17),mats.timber)
   b.box(door+Vector3(-1.17,.025,0),Vector3(2.7,.05,3.2),mats.mortar)
  else:
   b.box(door+Vector3.UP*1.55,Vector3(.14,3.1,3.2),mats.timber)
   for strip in 9:b.box(door+Vector3(.09,.22+strip*.32,0),Vector3(.06,.27,3.0),mats.mortar)
   b.box(door+Vector3(.20,.10,0),Vector3(.6,.20,3.5),mats.stone)
  b.box(door+Vector3(.18,3.25,0),Vector3(.4,.18,3.5),mats.trim)
  var sign_:=Label3D.new();sign_.text=["CARGO EXCHANGE","FISH AUCTION","FERRY STORES","TIMBER YARD","SHIPWRIGHTS"][index]
  sign_.font_size=28;sign_.pixel_size=.009;sign_.outline_size=1;sign_.position=door+Vector3(.20,3.6,0);sign_.rotation.y=PI*.5;sign_.modulate=Color("62564b");add_child(sign_)
  # Warehouse hoists project into the court without blocking the door.
  b.beam(door+Vector3(0,4.6,-2.5),door+Vector3(2.4,4.6,-2.5),.13,mats.timber)
  b.beam(door+Vector3(2.35,4.6,-2.5),door+Vector3(2.35,1.9,-2.5),.025,mats.timber)
 buildings.append({"at":at,"width":w,"height":h,"depth":d,"warehouse":warehouse})
func _warehouse_block(at: Vector3,size_: Vector3,mat: Material) -> void:
 b.box(at,size_,mat)
 var body:=StaticBody3D.new();body.name="WarehouseReceivingWall";body.position=at;body.collision_layer=1
 var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size_;col.shape=shape;body.add_child(col);add_child(body)
func _working_frontage() -> void:
 for i in 5:
  var z: float=BERTH_Z[i]
  _building(Vector3(-33.8,0,z),13.0,5.7+(i%2)*1.2,16,mats[["cream","brick","blue"][i%3]],true,i)
  # A 7m-deep loading court is a workplace between door and promenade.
  b.box(Vector3(-24.0,.02,z),Vector3(6.8,.04,14.0),mats.mortar)
  for j in 8:b.box(Vector3(-26.7+j*.75,.05,z+6.7),Vector3(.67,.05,.45),mats.stone)
  loading_yards.append(Rect2(Vector2(-27.4,z-7),Vector2(7.4,14)))
  # Small storehouses share the frontage with open market and sorting spaces.
  if i<4:
   var gap_z: float=(BERTH_Z[i]+BERTH_Z[i+1])*.5
   _building(Vector3(-35.2,0,gap_z-3.8),9.8,4.2,8.4,mats.brick,false,150+i)
   for stall in 3:_stall(Vector3(-27.7,0,gap_z+3.0+(stall-1)*3.1),i+stall)
   _stall(Vector3(-34.5,0,gap_z+5.6),i+2)
func _stall(at: Vector3,index: int) -> void:
 var canopy: Material=mats[["canvas","red_canvas","green_canvas"][index%3]]
 for x in [-1.2,1.2]:
  for z in [-.8,.8]:b.box(at+Vector3(x,1.15,z),Vector3(.075,2.3,.075),mats.timber)
 b.box(at+Vector3(0,.88,0),Vector3(2.5,.14,1.7),mats.timber)
 b.quad(at+Vector3(-1.4,2.35,-1),at+Vector3(1.4,2.35,-1),at+Vector3(1.4,2.1,1.1),at+Vector3(-1.4,2.1,1.1),canopy)
 for bay in 3:
  var p:=at+Vector3(-.78+bay*.78,.99,0)
  b.box(p,Vector3(.64,.12,1.2),mats.trim)
  for item in 3:b.cylinder(p+Vector3(0,.15,-.34+item*.34),.15,.18,mats[["brick","blue","cream"][(index+bay)%3]],8)
 markets.append({"at":at,"width":2.8,"depth":2.1})
func _inland_market(at: Vector3,index: int) -> void:
 b.box(at+Vector3(0,.025,0),Vector3(21,.05,20),mats.mortar)
 for side in [-1.0,1.0]:
  for j in 4:_stall(at+Vector3(side*7.0,0,-6+j*4),index+j)
 b.cylinder(at+Vector3(0,.40,0),1.3,.8,mats.stone,12)
 b.cylinder(at+Vector3(0,.85,0),1.4,.12,mats.trim,12)
 b.cylinder(at+Vector3(0,1.5,0),.25,1.5,mats.mortar,10)
func _civic_roof(at: Vector3) -> void:
 _building(at,14,10,17,mats.cream,false,250)
 b.box(at+Vector3(0,8,-2),Vector3(5,16,5),mats.cream)
 b.cylinder(at+Vector3(0,19,-2),3.1,7,mats.roof,8,0)
 b.beam(at+Vector3(0,22.5,-2),at+Vector3(0,25,-2),.1,mats.timber)
 for side in [-1.0,1.0]:
  b.box(at+Vector3(side*2.52,13,-2),Vector3(.08,1.8,1.3),mats.glass)
func set_arrival_ready(value: bool) -> void:
 if district!=null:district.set_arrival_ready(value)
func reset_activity() -> void:
 if district!=null:district.reset_activity()
func tick(delta: float,camera: Camera3D,clock: float) -> void:
 district.tick(delta,camera,clock)
