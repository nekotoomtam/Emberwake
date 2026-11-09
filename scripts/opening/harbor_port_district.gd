extends Node3D
## Scenic working waterfront at the same metre/pixel scale as the playable quay.
const Gangway=preload("res://scripts/opening/harbor_gangway.gd")
const Detail=preload("res://scripts/opening/harbor_detail.gd")
const NPC=preload("res://scripts/opening/harbor_npc.gd")
const Courier=preload("res://scripts/opening/harbor_cargo_courier.gd")
const Appearance=preload("res://scripts/opening/npc_appearance.gd")
const BERTH_Z: Array[float]=[-29.0,-72.0,-110.0,-148.0,-186.0]
var geometry_count:=0
var berths: Array=[]
var boats: Array=[]
var workers: Array=[]
var couriers: Array=[]
var deliveries:=0
var delivery_piles: Array[Node3D]=[]
var ship_cargo: Array[Node3D]=[]
var warehouse_fronts: Array[Vector3]=[]
var obstacles: Array[Rect2]=[]
var materials: Dictionary={}
var arrival_ready:=false
var deck_transfer_owner: Node3D
var marked_stocks: Dictionary={}
var transfer_bridge: Node3D
var b
func _ready() -> void:
 name="WorkingPortDistrict"
 b=Detail.new();add_child(b)
 for row in [["wood","927252","wood"],["dark","60574c","wood"],["rope","b6a481","wood"],["iron","4b6266","slate"],["cream","d2c3a5","plaster"],["blue","6c8b8d","wood"],["red","9f7565","wood"],["glass","8aafb0","plaster"],["canvas","d6c9a9","plaster"]]:
  materials[row[0]]=Detail.material(row[1],row[2],8200+materials.size())
 for row in [["quay_stone","b7b0a0","plaster"],["quay_stone2","a7a596","slate"],["quay_mortar","777e77","slate"],["quay_cap","d2c3a5","slate"],["quay_brick","ad9480","brick"],["quay_brick2","a48e7c","brick"]]:
  materials[row[0]]=Detail.material(row[1],row[2],8360+materials.size())
 materials.canvas.cull_mode=BaseMaterial3D.CULL_DISABLED
 _promenade()
 var kinds: Array=["cargo","fishing","passenger","timber","repair"]
 var lengths: Array=[42.7,28.0,31.2,29.5,26.0]
 var widths: Array=[6.0,6.0,7.0,7.5,6.5]
 for i in 5:_pier(i,kinds[i],BERTH_Z[i],lengths[i],widths[i])
 geometry_count=b.count;b.finish()
 _arrival_bridge()
 _transfer_activity()
 set_arrival_ready(false)
func _prop(at: Vector3,size_: Vector3,mat: Material) -> void:
 b.box(at,size_,mat)
 obstacles.append(Rect2(Vector2(at.x-size_.x*.5,at.z-size_.z*.5),Vector2(size_.x,size_.z)))
func _crate(at: Vector3,size_: float=.65) -> void:
 var marked: String=""
 if not warehouse_fronts.is_empty() and at.distance_to(warehouse_fronts[0]+Vector3(2.62,0,-6.3))<.01:marked="red"
 if at.distance_to(Vector3(-10.88,.43,-26.42))<.01:marked="orange"
 if not marked.is_empty():
  var stock=preload("res://scripts/opening/harbor_carried_cargo.gd").new()
  stock.name="MarkedStock_"+marked;stock.position=at+Vector3.UP*size_*.5;add_child(stock);stock.configure(size_,"crate")
  var body:=StaticBody3D.new();body.name="CrateFootprint";body.collision_layer=1
  var col:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(size_,size_,size_*.96);col.shape=shape;body.add_child(col);stock.add_child(body)
  stock.set_meta("cargo_size",size_);marked_stocks[marked]=stock
  stock.visibility_changed.connect(func():body.collision_layer=1 if stock.visible else 0)
  obstacles.append(Rect2(Vector2(at.x-size_*.5,at.z-size_*.5),Vector2.ONE*size_))
  return
 _prop(at+Vector3.UP*size_*.5,Vector3.ONE*size_,materials.wood)
 for side in [-1.0,1.0]:b.box(at+Vector3(side*size_*.33,size_*.5,size_*.51),Vector3(.065,size_,.04),materials.dark)
 b.beam(at+Vector3(-size_*.45,.06,size_*.53),at+Vector3(size_*.45,size_*.92,size_*.53),.055,materials.canvas)
func _barrel(at: Vector3) -> void:
 b.cylinder(at+Vector3.UP*.34,.26,.68,materials.wood,12,.24)
 for y in [.12,.55]:b.cylinder(at+Vector3.UP*y,.27,.055,materials.iron,12)
 obstacles.append(Rect2(Vector2(at.x-.27,at.z-.27),Vector2(.54,.54)))
func _coil(at: Vector3) -> void:
 for j in 4:b.cylinder(at+Vector3.UP*(.025+j*.025),.28-j*.045,.025,materials.rope,16)
func _promenade() -> void:
 # A continuous 4.8m waterfront walk; the wider loading courts sit to its west.
 for row in 307:
  for col in 6:
   var paving: Material=materials.quay_cap if absf(6-row*.72-BERTH_Z[0])<3.35 else materials.cream
   b.box(Vector3(-24.25+col*.79,.035,6-row*.72),Vector3(.74,.055,.67),paving)
 for i in 5:
  var z: float=BERTH_Z[i]
  for offset in [-7.0,7.0]:
   var at:=Vector3(-20.6,0,z+offset)
   b.cylinder(at+Vector3.UP*1.4,.065,2.8,materials.iron,10)
   b.box(at+Vector3(.24,2.8,0),Vector3(.55,.08,.08),materials.iron)
   b.box(at+Vector3(.48,2.55,0),Vector3(.26,.38,.26),materials.canvas)
   b.box(at+Vector3(.48,2.77,0),Vector3(.38,.08,.38),materials.dark)
  var door: Vector3=warehouse_fronts[i] if i<warehouse_fronts.size() else Vector3(-27,0,z)
  _handcart(door+Vector3(1.25,0,5.5))
  for j in 3:_crate(door+Vector3(1.1+j*.76,0,-6.3),.68)
  _crate(door+Vector3(1.1,.68,-6.3),.58)
  _barrel(door+Vector3(1.1,0,-7.5))
  # Sorting benches stay outside the direct warehouse-to-pier line.
  _prop(door+Vector3(.9,.43,3.6),Vector3(1.3,.13,1.0),materials.wood)
  for side in [-1.0,1.0]:b.box(door+Vector3(.9+side*.46,.22,3.6),Vector3(.10,.44,.7),materials.dark)
  var yard_route: Array[Vector3]=[door+Vector3(.85,.045,-2.0),Vector3(-22.8,.045,z-2.0)]
  if i!=0:_worker(20+i,yard_route,true,true) # first-yard porter is owned by the marked routes
func _handcart(at: Vector3) -> void:
 _prop(at+Vector3.UP*.5,Vector3(1.25,.16,1.55),materials.wood)
 for side in [-1.0,1.0]:
  b.box(at+Vector3(side*.61,.78,0),Vector3(.09,.5,1.6),materials.dark)
  b.beam(at+Vector3(side*.45,.5,.4),at+Vector3(side*.45,.6,2.0),.065,materials.wood)
  var ring: Array[Vector3]=[]
  for j in 13:ring.append(at+Vector3(side*.73,.33+sin(j*TAU/12)*.30,cos(j*TAU/12)*.30))
  b.tube(ring,.045,materials.iron,.9)
 _crate(at+Vector3(-.25,.6,-.25),.55)
func _pier(i: int,kind: String,z: float,length_: float,width: float) -> void:
 var start:=Vector3(-19.7,.43,z)
 var end:=start+Vector3.RIGHT*length_
 var area:=Rect2(Vector2(start.x,z-width*.5),Vector2(length_,width))
 if kind=="cargo":_cargo_quay(start,end,width)
 else:
  b.box(Vector3(start.x+length_*.5,.22,z),Vector3(length_,.32,width),materials.dark)
  var count_: int=int(length_*2.0)
  for j in count_:b.box(Vector3(start.x+(j+.5)*length_/count_,.40,z),Vector3(length_/count_-.025,.05,width),materials.wood)
  for x in range(0,int(length_)+1,3):
   for side in [-1.0,1.0]:
    var p:=Vector3(start.x+x,-.13,z+side*(width*.5-.15))
    b.cylinder(p,.12,1.4,materials.dark,10)
    b.cylinder(p+Vector3.UP*.12,.135,.12,materials.iron,10)
    b.box(p+Vector3.UP*.85,Vector3(.3,.12,.3),materials.iron)
   if x<int(length_)-2:b.beam(Vector3(start.x+x,-.3,z-width*.5),Vector3(start.x+x,.28,z+width*.5),.09,materials.dark)
  b.quad(Vector3(-20.5,.055,z-width*.5),Vector3(-20.5,.055,z+width*.5),Vector3(-18.5,.43,z+width*.5),Vector3(-18.5,.43,z-width*.5),materials.wood)
 # Props occupy edge strips, leaving a broad working route down every pier.
 var edge: float=width*.5-.42
 _crate(Vector3(start.x+2.0,.43,z+edge))
 _barrel(Vector3(end.x-1.1,.43,z-edge))
 _coil(Vector3(start.x+1.0,.43,z-edge))
 match kind:
  "cargo":
   _crane(Vector3(17.8,.43,z-edge))
   for j in 5:_crate(Vector3(-14+j*.78,.43,z+edge),.65)
   _crate(Vector3(-14,.43+.65,z+edge),.55)
   for staging_x in [-5.0,3.0,18.0]:
    _crate(Vector3(staging_x,.43,z+edge),.65)
    _crate(Vector3(staging_x,.43+.65,z+edge),.55)
    _barrel(Vector3(staging_x+1.25,.43,z+edge))
   # The large arriving vessel is authored by the world; this is its berth metadata.
   boats.append({"kind":"arriving_cargo","at":Vector3(12,-.55,-38),"length":28.4,"width":8.8,"deck":2.315,"arriving":true})
  "fishing":
   for j in 5:
    var at:=Vector3(start.x+3+j*.8,.43,z+edge)
    _prop(at+Vector3.UP*.12,Vector3(.7,.24,.62),materials.dark)
    for k in 3:b.box(at+Vector3(-.2+k*.2,.27,0),Vector3(.13,.05,.36),materials.glass,Vector3(0,.25*k,0))
   _net(Vector3(start.x+8,.50,z-edge))
   _boat(Vector3(start.x+length_*.54,0,z-width*.5-1.9),7.7,2.5,"fishing",i)
   _boat(Vector3(start.x+length_*.74,0,z+width*.5+1.8),6.5,2.3,"skiff",i)
  "passenger":
   for j in 5:
    var at:=Vector3(start.x+2+j*2.2,.43,z+edge)
    _prop(at+Vector3.UP*.42,Vector3(1.4,.12,.55),materials.wood)
    b.box(at+Vector3(0,.8,.28),Vector3(1.4,.7,.08),materials.blue)
    for side in [-1.0,1.0]:b.box(at+Vector3(side*.5,.22,0),Vector3(.08,.44,.42),materials.iron)
   for x in [start.x+1,start.x+10]:b.cylinder(Vector3(x,1.8,z-edge),.055,2.8,materials.dark,10)
   b.quad(Vector3(start.x+.5,3.2,z-edge-.4),Vector3(start.x+10.5,3.2,z-edge-.4),Vector3(start.x+10.5,2.9,z-edge+.7),Vector3(start.x+.5,2.9,z-edge+.7),materials.canvas)
   _boat(Vector3(start.x+length_*.62,0,z-width*.5-2.6),14.5,4.2,"ferry",i)
  "timber":
   _crane(Vector3(start.x+length_*.68,.43,z-edge))
   for j in 8:b.box(Vector3(start.x+6,.51+(j/2)*.11,z+edge+(j%2)*.20-.10),Vector3(6,.10,.18),materials.wood)
   obstacles.append(Rect2(Vector2(start.x+3,z+edge-.20),Vector2(6,.4)))
   _boat(Vector3(start.x+length_*.63,0,z-width*.5-2.0),10.5,2.8,"barge",i)
  "repair":
   _net(Vector3(start.x+3,.48,z+edge))
   for j in 3:b.box(Vector3(start.x+6,.5+j*.09,z+edge),Vector3(4,.08,.5),materials.wood)
   obstacles.append(Rect2(Vector2(start.x+4,z+edge-.25),Vector2(4,.5)))
   _boat(Vector3(start.x+length_*.63,0,z-width*.5-2.0),8,2.7,"repair",i)
 var clearance: float=width
 for rect in obstacles:
  if rect.intersects(area):clearance=minf(clearance,2*maxf(0,minf(absf(rect.position.y-z),absf(rect.end.y-z))))
 berths.append({"kind":kind,"start":start,"end":end,"width":width,"length":length_,"path_clearance":clearance,"surface":"masonry" if kind=="cargo" else "timber","construction":"masonry_quay" if kind=="cargo" else "timber_pier"})
 var route: Array[Vector3]=[Vector3(-18.2,.43,z),Vector3(end.x-2.2,.43,z)]
 _worker(i*2,route,true,false)
 var door: Vector3=warehouse_fronts[i] if i<warehouse_fronts.size() else Vector3(-27,0,z)
 var station: Array[Vector3]=[door+Vector3(.8,.045,1.0)]
 if i==0:station.assign([door+Vector3(.8,.045,2.4)]) # clear the actual receiving doorway
 _worker(i*2+1,station,true,false)
 if kind!="cargo":
  # Local boat transfer boards and slack mooring lines use the actual deck height.
  var boat_x: float=start.x+length_*(.54 if kind=="fishing" else .62 if kind=="passenger" else .63)
  var deck: float=.95 if kind=="passenger" else .78
  var boat_edge: float=z-width*.5-(.5 if kind=="fishing" else .7)
  b.quad(Vector3(boat_x-.6,.43,z-width*.5+.15),Vector3(boat_x+.6,.43,z-width*.5+.15),Vector3(boat_x+.6,deck,boat_edge),Vector3(boat_x-.6,deck,boat_edge),materials.wood)
  for x in [boat_x-2.4,boat_x+2.4]:
   var line: Array[Vector3]=[Vector3(x,.70,z-width*.5),Vector3(x+.4,.48,z-width*.5-.7),Vector3(x+.9,deck,z-width*.5-1.5)]
   b.tube(line,.027,materials.rope,.9)
func _cargo_quay(start: Vector3,end: Vector3,width: float) -> void:
 # The terminal grows out of the town seawall; its foundation extends below water.
 # Keep the original ramp crest and .43m cargo surface for every transfer path.
 var crest: float=-18.5;var run: float=end.x-crest;var half: float=width*.5
 b.box(Vector3((crest+end.x)*.5,-1.08,start.z),Vector3(run,2.88,width),materials.quay_mortar)
 for side in [-1.0,1.0]:
  var edge_z: float=start.z+side*(half-.20)
  for course in 4:
   var cells: int=int(ceil(run/1.65));var step_: float=run/cells
   for j in range(-1,cells):
    var left: float=maxf(crest,crest+(j+(course%2)*.5)*step_)
    var right: float=minf(end.x,crest+(j+1+(course%2)*.5)*step_)
    if right-left>.06:
     b.box(Vector3((left+right)*.5,.16-course*.35,edge_z),Vector3(right-left-.035,.32,.44),materials.quay_stone if (j+course)%3 else materials.quay_stone2)
  # The sloping stone throat overlaps the shore cap without a timber threshold.
  var a:=Vector3(-20.5,.055,start.z+side*half);var c:=Vector3(crest,.43,start.z+side*half)
  var d:=Vector3(crest,-2.52,start.z+side*half);var e:=Vector3(-20.5,-2.52,start.z+side*half)
  if side<0:b.quad(a,c,d,e,materials.quay_stone2)
  else:b.quad(e,d,c,a,materials.quay_stone2)
 for course in 4:
  for j in 4:
   b.box(Vector3(end.x-.18,.16-course*.35,start.z-half+(j+.5)*width/4),Vector3(.42,.32,width/4-.035),materials.quay_stone if (j+course)%2 else materials.quay_stone2)
 # Warm brick panels sit within the same pale stone used along the promenade.
 var paving_width: float=width-.80;var paving_end: float=end.x-.40
 var columns: int=int(ceil((paving_end-crest)/1.60));var step_x: float=(paving_end-crest)/columns
 for row in 7:
  for col in range(-1,columns):
   var left: float=maxf(crest,crest+(col+(row%2)*.5)*step_x)
   var right: float=minf(paving_end,crest+(col+1+(row%2)*.5)*step_x)
   if right-left>.04:
    b.box(Vector3((left+right)*.5,.3975,start.z-paving_width*.5+(row+.5)*paving_width/7),Vector3(right-left-.025,.065,paving_width/7-.022),materials.quay_brick if (col+row)%4 else materials.quay_brick2)
 for side in [-1.0,1.0]:
  for j in int(ceil(run/1.25)):
   var left: float=crest+j*1.25;var right: float=minf(end.x,left+1.25)
   b.box(Vector3((left+right)*.5,.385,start.z+side*(half-.20)),Vector3(right-left-.025,.09,.40),materials.quay_cap)
 for j in 7:
  b.box(Vector3(end.x-.20,.385,start.z-half+(j+.5)*width/7),Vector3(.40,.09,width/7-.022),materials.quay_cap)
 # Individual sloping paving bands follow the retained courier ramp exactly.
 for row in 8:
  for col in 8:
   var x0: float=-20.5+col*.25;var x1: float=x0+.24
   var y0: float=lerpf(.055,.43,(x0+20.5)*.5);var y1: float=lerpf(.055,.43,(x1+20.5)*.5)
   var z0: float=start.z-half+row*width/8;var z1: float=z0+width/8-.022
   b.quad(Vector3(x0,y0,z0),Vector3(x0,y0,z1),Vector3(x1,y1,z1),Vector3(x1,y1,z0),materials.quay_cap if row in [0,7] or col%3==0 else materials.quay_stone)
 # Low coping is broken into working bays, with a generous gap at the ship bridge.
 for side in [-1.0,1.0]:
  for x in [-15.5,-8.0,0.0,5.5,14.0,19.5]:
   _prop(Vector3(x,.56,start.z+side*(half-.12)),Vector3(1.10,.26,.24),materials.quay_cap)
  for x in [-14.5,-6.8,1.5,14.0,20.0]:
   var edge_z: float=start.z+side*(half-.16)
   # Mooring furniture stays outside the measured central loading route.
   b.box(Vector3(x,.47,edge_z),Vector3(.38,.08,.34),materials.iron)
   b.cylinder(Vector3(x,.64,edge_z),.13,.30,materials.iron,12)
   b.box(Vector3(x,.79,edge_z),Vector3(.48,.11,.18),materials.iron)
   obstacles.append(Rect2(Vector2(x-.24,edge_z-.17),Vector2(.48,.34)))
   b.box(Vector3(x,-.12,start.z+side*(half+.12)),Vector3(.23,1.02,.22),materials.dark)
   for y in [-.37,.16]:b.box(Vector3(x,y,start.z+side*(half+.14)),Vector3(.29,.07,.26),materials.iron)
func _arrival_bridge() -> void:
 var bridge=Detail.new();bridge.name="ArrivalTransferBridge";add_child(bridge)
 var shore: Vector3=Gangway.ARRIVAL_SHORE;var deck: Vector3=Gangway.ARRIVAL_DECK
 Gangway.build(bridge,shore,deck)
 geometry_count+=bridge.count;bridge.finish();transfer_bridge=bridge
func _transfer_activity() -> void:
 # The first terminal now has exactly the two user-marked local haulers.
 # The former second ship hauler sorts cargo away from that shared passage.
 var sorting: Array[Vector3]=[Vector3(6,.43,-30.7)]
 _worker(31,sorting,true,false)
 # A fish carrier works between the moored fishing boat and its sorting yard.
 var fish_x: float=-19.7+28*.54
 # Round the end of the dockhand's patrol instead of crossing head-on.
 var fish_path: Array[Vector3]=[Vector3(-25,.045,-70.4),Vector3(-20.5,.055,-70.4),Vector3(-18.5,.43,-70.4),Vector3(7.4,.43,-70.4),Vector3(7.4,.43,-73.5),Vector3(fish_x,.43,-73.5),Vector3(fish_x,.43,-74.85),Vector3(fish_x,.78,-75.5),Vector3(fish_x,.78,-76.7)]
 _courier(32,fish_path,"fish",2.1)
func _courier(index: int,path: Array[Vector3],kind: String,delay_: float) -> void:
 var npc=Courier.new();npc.name="CargoCourier%02d"%index;npc.profile=_profile(index,true)
 npc.transfer_path=path;npc.cargo_kind=kind;npc.speed=1.12;npc.departure_delay=delay_
 npc.picked_up.connect(_cargo_picked_up);npc.delivered.connect(_cargo_delivered)
 add_child(npc);couriers.append(npc);workers.append(npc)
func _cargo_visual(at: Vector3,kind: String,size_: float) -> Node3D:
 var node=Detail.new();node.position=at;add_child(node)
 if kind=="fish":
  node.box(Vector3(0,.12,0),Vector3(.70,.24,.58),materials.dark)
  for j in 3:node.box(Vector3(-.22+j*.22,.26,0),Vector3(.13,.055,.40),materials.glass,Vector3(0,j*.18,0))
 else:
  node.box(Vector3.UP*size_*.5,Vector3.ONE*size_,materials.wood)
  for side in [-1.0,1.0]:node.box(Vector3(side*size_*.34,size_*.5,size_*.51),Vector3(.06,size_,.04),materials.dark)
  node.beam(Vector3(-size_*.44,.06,size_*.53),Vector3(size_*.44,size_*.91,size_*.53),.05,materials.canvas)
 node.finish();return node
func _cargo_picked_up(courier) -> void:
 var slot: int=courier.completed_deliveries%9
 courier.dropoff_anchor=_delivery_position(courier,slot)+Vector3.UP*.30
 if courier.cargo_kind=="crate":
  var chosen: Node3D=null;var nearest:=INF
  for crate in ship_cargo:
   if crate.visible and crate.global_position.distance_squared_to(courier.global_position)<nearest:
    chosen=crate;nearest=crate.global_position.distance_squared_to(courier.global_position)
  if chosen!=null:
   courier.pickup_anchor=chosen.global_position+Vector3.UP*.30;chosen.visible=false
func _delivery_position(courier,slot: int) -> Vector3:
 var side: float=1.0 if courier==couriers[0] or courier.cargo_kind=="fish" else -1.0
 return courier.transfer_path[0]+Vector3(-.3,.01,side*.9)+Vector3((slot%3)*.70,(slot/3)*.62,0)
func _cargo_delivered(courier) -> void:
 deliveries+=1
 var slot: int=(courier.completed_deliveries-1)%9
 for i in range(delivery_piles.size()-1,-1,-1):
  var previous: Node3D=delivery_piles[i]
  if previous.get_meta("courier_id","")==courier.name and previous.get_meta("slot",-1)==slot:
   previous.free();delivery_piles.remove_at(i)
 # Place each load within arm's reach of its real dropoff, outside the walking lane.
 var at: Vector3=_delivery_position(courier,slot)
 var pile: Node3D=_cargo_visual(at,courier.cargo_kind,.60)
 pile.name="Delivered_%s_%02d"%[courier.name,slot];pile.set_meta("cargo_kind",courier.cargo_kind)
 pile.set_meta("courier_id",courier.name);pile.set_meta("slot",slot);delivery_piles.append(pile)
 # Keep the scenic storage bounded during long-running menu sessions.
 if delivery_piles.size()>24:
  delivery_piles[0].free();delivery_piles.remove_at(0)
func set_arrival_ready(value: bool) -> void:
 var changed: bool=value!=arrival_ready
 arrival_ready=value
 if transfer_bridge!=null:transfer_bridge.visible=value
 for courier in couriers:courier.set_enabled(value)
 if not value or changed:
  for crate in ship_cargo:crate.visible=value
func reset_activity() -> void:
 deliveries=0
 deck_transfer_owner=null
 for pile in delivery_piles:pile.free()
 delivery_piles.clear()
 for courier in couriers:courier.reset_activity()
 set_arrival_ready(false)
func _crane(at: Vector3) -> void:
 _prop(at+Vector3.UP*.12,Vector3(.7,.24,.7),materials.dark)
 b.cylinder(at+Vector3.UP*2.2,.13,4.4,materials.wood,12)
 var tip:=at+Vector3(2.7,3.8,0)
 b.beam(at+Vector3.UP*3.5,tip,.16,materials.wood)
 b.beam(at+Vector3.UP*4.35,tip,.035,materials.iron)
 b.beam(at+Vector3(-.4,.25,0),at+Vector3.UP*2.3,.09,materials.dark)
 b.beam(tip,tip-Vector3.UP*1.65,.025,materials.rope)
 b.beam(tip-Vector3.UP*1.65,tip+Vector3(.12,-1.8,0),.04,materials.iron)
func _net(at: Vector3) -> void:
 for j in 6:b.beam(at+Vector3(-.5+j*.18,0,-.28),at+Vector3(-.5+j*.18,.1,.28),.018,materials.blue)
 for j in 4:b.beam(at+Vector3(-.5,.02,-.28+j*.18),at+Vector3(.4,.1,-.28+j*.18),.018,materials.rope)
func _boat(at: Vector3,length_: float,width: float,kind: String,dock: int) -> void:
 var hull: Material=materials.blue if kind in ["fishing","ferry"] else materials.red
 var sections: int=14 if dock<3 else 10
 var deck: float=.78 if kind!="ferry" else .95
 for j in sections:
  var t: float=(j+.5)/sections;var x: float=(t-.5)*length_
  var beam_: float=width*.5*pow(sin(t*PI),.5)
  for side in [-1.0,1.0]:
   for row in 4:b.box(at+Vector3(x,-.55+(deck+.55)*(row+.5)/4,side*beam_*(.65+row*.11)),Vector3(length_/sections+.025,(deck+.55)/4-.018,.09),hull if row<3 else materials.cream)
  b.box(at+Vector3(x,deck-.055,0),Vector3(length_/sections-.025,.11,beam_*1.8),materials.wood)
  if j%3==0:
   for side in [-1.0,1.0]:b.cylinder(at+Vector3(x,deck+.24,side*beam_*.94),.035,.48,materials.dark,8)
 if kind=="ferry":
  b.box(at+Vector3(-1,deck+1.1,0),Vector3(length_*.38,2.2,width*.64),materials.cream)
  b.box(at+Vector3(-1,deck+2.3,0),Vector3(length_*.42,.16,width*.77),materials.dark)
  for j in 4:
   for side in [-1.0,1.0]:b.box(at+Vector3(-3+j*1.2,deck+1.25,side*width*.325),Vector3(.75,.7,.07),materials.glass)
  b.cylinder(at+Vector3(1.3,deck+2.7,0),.27,1.6,materials.iron,12)
  b.cylinder(at+Vector3(1.3,deck+3.52,0),.34,.13,materials.dark,12)
  b.box(at+Vector3(length_*.19,deck+1.0,0),Vector3(.08,2.0,.85),materials.dark)
  var route: Array[Vector3]=[at+Vector3(length_*.34,deck+.01,0)]
  _worker(10,route,true,false)
 elif kind not in ["skiff","barge"]:
  var mast: Vector3=at+Vector3(-length_*.14,deck,0)
  b.cylinder(mast+Vector3.UP*2.7,.065,5.4,materials.dark,10)
  b.beam(mast+Vector3(0,1.1,0),mast+Vector3(length_*.37,1.1,0),.07,materials.wood)
  b.quad(mast+Vector3(0,4.9,0),mast+Vector3(length_*.33,1.2,0),mast+Vector3(0,1.2,0),mast+Vector3(0,4.9,0),materials.canvas)
  for side in [-1.0,1.0]:b.beam(mast+Vector3.UP*4.9,at+Vector3(length_*.3,deck,side*width*.45),.018,materials.rope)
 if kind=="repair":
  var route: Array[Vector3]=[at+Vector3(length_*.22,deck+.01,0)]
  _worker(11,route,true,false)
 boats.append({"kind":kind,"at":at,"length":length_,"width":width,"deck":deck})
func _profile(index: int,carrying: bool) -> Dictionary:
 var rng:=RandomNumberGenerator.new();rng.seed=82100+index
 return {"id":"PortWorker%02d"%index,"hairstyle":rng.randi_range(0,9),"male":rng.randf()<.5,"hair":Appearance.HAIR[rng.randi_range(0,9)],"skin":Appearance.SKIN[rng.randi_range(0,9)],"coat":["737c77","8d7963","758b94"][index%3],"cap":false,"phase":index*1.3,"carry":carrying,"apron":index%3==0}
func _worker(index: int,path: Array[Vector3],working: bool,carrying: bool) -> void:
 var npc=NPC.new();npc.name="PortWorker%02d"%index;npc.profile=_profile(index,carrying)
 npc.route=path;npc.speed=.75;npc.work=working;add_child(npc);workers.append(npc)
func tick(delta: float,camera: Camera3D,clock: float) -> void:
 for npc in workers:
  # One worker at a time on the narrow ship transfer; others wait on their
  # separate dock lane until the returning worker has cleared the bridge.
  if npc in couriers and npc.cargo_kind=="crate" and npc.direction==1 and npc.waypoint>=4:
   if deck_transfer_owner==null:deck_transfer_owner=npc
   if deck_transfer_owner!=npc:npc.tick(0,camera,clock);continue
  npc.tick(delta,camera,clock)
  if deck_transfer_owner==npc and npc.direction==-1 and npc.waypoint<=2:deck_transfer_owner=null
func apply_ship_motion(vessel: Node3D,camera: Camera3D) -> void:
 for crate in ship_cargo:
  if not crate.has_meta("ship_rest_transform"):crate.set_meta("ship_rest_transform",crate.global_transform)
  var rest: Transform3D=crate.get_meta("ship_rest_transform")
  crate.global_transform=vessel.deck_visual_transform()*rest
 for actor in couriers:
  var aboard: bool=actor.position.y>2.1 and actor.position.z< -34.2
  actor.apply_deck_offset(vessel.deck_motion_offset(actor.global_position) if aboard else Vector3.ZERO,camera)
