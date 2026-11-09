extends Node3D
## Scenic native extension of the original western city at its northern seam.
## Ground, work bays and rear streets are visual meshes only: the existing
## playable harbor retains all physics, navigation, people and activity clocks.
const Detail=preload("res://scripts/opening/harbor_detail.gd")
const BAY_Z: Array[float]=[-243.0,-291.0,-340.0,-390.0]
const ROW_Z: Array[float]=[-234.0,-264.0,-295.0,-326.0,-357.0,-388.0,-410.0]
var materials: Dictionary={}
var geometry_count:=0
var main
var land_rect:=Rect2(-164,-420,144,200)
var shore_x: float=-19.6
var seam: Dictionary={"z":-220.0,"x_min":-164.0,"x_max":-20.0,"top_y":0.0}
var bounds: Dictionary={}
var warehouses: Array[Dictionary]=[]
var loading_courts: Array[Dictionary]=[]
var jetties: Array[Dictionary]=[]
var hoists: Array[Dictionary]=[]
var houses: Array[Dictionary]=[]
var chimney_outlets: Array[Vector3]=[]
var rear_rows: Array[Dictionary]=[]
func _ready() -> void:
 name="NativeNorthernWaterfront"
 _palette()
 main=_geometry("ConnectedNorthernLandAndSeawall")
 _land();_finish(main);bounds["land"]=_mesh_bounds(main)
 for i in BAY_Z.size():_working_bay(i,BAY_Z[i])
 _rear_streets()
 bounds["all"]=_mesh_bounds(self)
func _palette() -> void:
 for row in [["stone","b1aa97","plaster"],["mortar","898f86","slate"],["trim","d6c6a6","wood"],["roof","72615e","slate"],["glass","78949a","plaster"],["timber","6f655a","wood"],["cream","c6bca5","plaster"],["brick","a9907e","brick"],["blue","9ba9a4","plaster"],["iron","4b6266","slate"],["rope","b6a481","wood"],["teal","487d80","wood"]]:
  if not materials.has(row[0]):materials[row[0]]=Detail.material(row[1],row[2],9700+materials.size())
func _geometry(name_: String):
 var node=Detail.new();node.name=name_;add_child(node);return node
func _finish(node) -> void:
 geometry_count+=node.count;node.finish()
func _mesh_bounds(node: Node3D) -> AABB:
 var result:=AABB();var first:=true
 for mesh in node.find_children("*","MeshInstance3D",true,false):
  var box: AABB=mesh.transform*mesh.get_aabb()
  result=box if first else result.merge(box);first=false
 return result
func _extend_bounds(kind: String,box: AABB) -> void:
 bounds[kind]=box if not bounds.has(kind) else bounds[kind].merge(box)
func _land() -> void:
 # Same full width, top datum and submerged depth as the original town slab.
 # The exact z=-220 edge shares vertices with the old foundation, without a
 # strip of ocean or an elevated platform separating the two urban masses.
 main.box(Vector3(-92,-1.2,-320),Vector3(144,2.4,200),materials.stone)
 for i in 84:
  var far_z: float=maxf(-420,-220-(i+1)*2.4)
  var near_z: float=-220-i*2.4
  var z: float=(far_z+near_z)*.5;var length_: float=near_z-far_z
  main.box(Vector3(-19.8,-.55,z),Vector3(.5,1.1,length_-.025),materials.mortar)
  main.box(Vector3(shore_x,.10,z),Vector3(.7,.25,length_-.025),materials.trim)
  # Alternating masonry joints remain low, matching the inherited harbor cap.
  if i%3==1:main.box(Vector3(-19.3,.25,z),Vector3(.30,.28,.48),materials.stone)
func _working_bay(index: int,z: float) -> void:
 var building=_geometry("NorthernWarehouse%02d"%(index+1))
 var at:=Vector3(-34.0-float(index%2)*.4,0,z)
 var width_: float=12.4+float(index%2)*1.0
 var wall_height: float=5.2+float(index%3)*.6
 var depth_: float=15.0+float(index%2)*1.6
 var roof_peak: float=wall_height+2.0+width_*.1
 _building(building,at,width_,wall_height,depth_,materials[["cream","brick","blue","cream"][index]],true,index)
 var door:=at+Vector3(width_*.5+.08,0,0)
 _finish(building)
 warehouses.append({"node":building,"at":at,"width":width_,"wall_height":wall_height,"depth":depth_,"roof_peak":roof_peak,"door":door,"door_width":3.2,"door_height":3.0})
 _extend_bounds("frontage",_mesh_bounds(building))
 var court=_geometry("WarehouseLoadingCourt%02d"%(index+1))
 var rect:=Rect2(Vector2(door.x-.2,z-7.4),Vector2(-20.4-door.x+.2,14.8))
 var center: Vector2=rect.get_center()
 court.box(Vector3(center.x,.025,center.y),Vector3(rect.size.x,.05,rect.size.y),materials.mortar)
 for row in 10:
  for col in 5:
   court.box(Vector3(door.x+.40+col*(rect.size.x-.7)/5,.061,z-6.7+row*1.4),Vector3((rect.size.x-.7)/5-.035,.022,1.34),materials.stone if (row+col)%4 else materials.trim)
 # Sort goods along the bay edges, leaving the door-to-pier center open.
 for j in 4:
  _crate(court,Vector3(door.x+.65+j*.85,0,z+6.2),.73)
 _crate(court,Vector3(door.x+.65,.73,z+6.2),.64)
 for j in 3:_barrel(court,Vector3(door.x+1.0+j*.75,0,z-6.1))
 court.box(Vector3(door.x+1.6,.42,z-4.65),Vector3(2.4,.14,1.0),materials.timber)
 for side in [-1.0,1.0]:court.box(Vector3(door.x+1.6+side*.92,.21,z-4.65),Vector3(.12,.42,.78),materials.timber)
 _finish(court);loading_courts.append({"node":court,"rect":rect,"clear_center_width":3.2,"door":door})
 _extend_bounds("frontage",_mesh_bounds(court))
 _jetty(index,z,24.0+float(index%3)*2.0,5.6+float(index%2)*.4)
 _hoist(index,Vector3(-18.0,.43,z-2.1))
func _building(node,at: Vector3,w: float,h: float,d: float,wall: Material,warehouse: bool,index: int) -> void:
 node.box(at+Vector3.UP*h*.5,Vector3(w,h,d),wall)
 node.box(at+Vector3.UP*.22,Vector3(w+.20,.44,d+.20),materials.mortar)
 for y in [.46,h-.10]:node.box(at+Vector3(0,y,0),Vector3(w+.18,.12,d+.18),materials.trim)
 var eave: float=h+.12;var peak: float=h+2.0+w*.1
 var a:=at+Vector3(-w*.57,eave,-d*.57);var c:=at+Vector3(w*.57,eave,-d*.57)
 var e:=at+Vector3(-w*.57,eave,d*.57);var f:=at+Vector3(w*.57,eave,d*.57)
 var p:=at+Vector3(0,peak,-d*.57);var q:=at+Vector3(0,peak,d*.57)
 node.quad(a,e,q,p,materials.roof);node.quad(p,q,f,c,materials.roof)
 node.quad(e,f,q,e,wall);node.quad(a,p,c,a,wall);node.beam(p,q,.12,materials.timber)
 for side in [-1.0,1.0]:
  node.beam(at+Vector3(side*w*.57,eave,-d*.58),at+Vector3(side*w*.57,eave,d*.58),.13,materials.trim)
  for z_side in [-1.0,1.0]:node.box(at+Vector3(side*(w*.5-.14),h*.5,z_side*(d*.5-.13)),Vector3(.25,h,.25),materials.trim)
 node.box(at+Vector3(w*.25,peak-.15,-d*.15),Vector3(.58,1.65,.62),materials.brick)
 node.box(at+Vector3(w*.25,peak+.72,-d*.15),Vector3(.78,.16,.82),materials.trim)
 chimney_outlets.append(at+Vector3(w*.25,peak+.82,-d*.15))
 var floors: int=2 if warehouse else maxi(1,int(h/2.3))
 for level in floors:
  var y: float=1.65+level*2.3
  for bay in 3:
   _window(node,at+Vector3(-w*.31+bay*w*.31,y,d*.5+.06),false)
   if not warehouse or level>0 or bay!=1:_window(node,at+Vector3(w*.5+.06,y,-d*.31+bay*d*.31),true)
 if warehouse:
  var door:=at+Vector3(w*.5+.08,0,0)
  node.box(door+Vector3(.02,1.5,0),Vector3(.14,3.0,3.2),materials.timber)
  for plank in 12:node.box(door+Vector3(.105,1.5,-1.46+plank*.265),Vector3(.045,2.95,.245),materials.teal if index%2==0 else materials.timber)
  for side in [-1.0,1.0]:
   node.box(door+Vector3(.16,1.55,side*1.64),Vector3(.22,3.25,.18),materials.trim)
   node.beam(door+Vector3(.15,.18,side*.12),door+Vector3(.15,2.85,side*1.42),.07,materials.iron)
  node.box(door+Vector3(.16,3.18,0),Vector3(.28,.18,3.55),materials.trim)
  node.box(door+Vector3(.22,.08,0),Vector3(.6,.16,3.5),materials.stone)
 else:
  node.box(at+Vector3(0,.90,d*.5+.10),Vector3(.95,1.8,.13),materials.timber)
  node.box(at+Vector3(0,1.87,d*.5+.13),Vector3(1.18,.14,.22),materials.trim)
func _window(node,at: Vector3,east: bool) -> void:
 var rotation_:=Vector3(0,PI*.5 if east else 0,0)
 var outward:=Vector3.RIGHT if east else Vector3.BACK
 var basis_:=Basis.from_euler(rotation_)
 node.box(at,Vector3(.96,1.22,.10),materials.timber,rotation_)
 node.box(at+outward*.07,Vector3(.73,1.02,.055),materials.glass,rotation_)
 node.box(at+outward*.105,Vector3(.055,1.03,.035),materials.trim,rotation_)
 node.box(at+basis_*Vector3(0,-.14,.11),Vector3(.75,.055,.035),materials.trim,rotation_)
 node.box(at+basis_*Vector3(0,-.65,.10),Vector3(1.13,.11,.25),materials.trim,rotation_)
func _jetty(index: int,z: float,length_: float,width_: float) -> void:
 var node=_geometry("NorthernLoadingJetty%02d"%(index+1))
 var start:=Vector3(-19.7,.43,z);var end:=start+Vector3.RIGHT*length_
 var deck_start:=Vector3(-18.5,.43,z);var deck_length: float=end.x-deck_start.x
 # The raised timber begins at the ramp crest, never over its sloping throat.
 node.box(deck_start.lerp(end,.5)-Vector3.UP*.14,Vector3(deck_length,.24,width_),materials.timber)
 var planks: int=ceili(deck_length*1.6)
 for i in planks:
  node.box(Vector3(deck_start.x+(i+.5)*deck_length/planks,.405,z),Vector3(deck_length/planks-.025,.05,width_),materials.timber if i%4 else materials.trim)
 for side in [-1.0,1.0]:
  node.beam(deck_start+Vector3(0,-.12,side*(width_*.5-.12)),end+Vector3(0,-.12,side*(width_*.5-.12)),.20,materials.timber)
  for i in range(0,int(deck_length)+1,3):
   var post:=deck_start+Vector3(i,-.56,side*(width_*.5-.18))
   node.cylinder(post,.13,2.1,materials.timber,10)
   node.cylinder(post+Vector3.UP*.91,.15,.10,materials.iron,10)
   if i%6==0:
    node.box(post+Vector3.UP*1.09,Vector3(.34,.10,.30),materials.iron)
    node.cylinder(post+Vector3.UP*1.26,.09,.25,materials.iron,10)
    node.box(post+Vector3.UP*1.40,Vector3(.42,.09,.16),materials.iron)
 var ramp_start:=Vector3(-20.5,.055,z);var ramp_end:=Vector3(-18.5,.43,z)
 node.quad(ramp_start+Vector3(0,0,-1.8),ramp_start+Vector3(0,0,1.8),ramp_end+Vector3(0,0,1.8),ramp_end+Vector3(0,0,-1.8),materials.trim)
 for side in [-1.0,1.0]:node.beam(ramp_start+Vector3(0,-.08,side*1.8),ramp_end+Vector3(0,-.08,side*1.8),.12,materials.timber)
 for j in 5:_crate(node,Vector3(start.x+5+j*.84,.43,z+width_*.5-.55),.68)
 for j in 4:node.box(Vector3(start.x+length_*.60,.48+j*.10,z-width_*.5+.55),Vector3(4.1,.085,.75),materials.timber)
 _barrel(node,end+Vector3(-1.2,0,width_*.5-.58))
 _finish(node);jetties.append({"node":node,"start":start,"deck_start":deck_start,"end":end,"width":width_,"ramp_start":ramp_start,"ramp_end":ramp_end})
 _extend_bounds("frontage",_mesh_bounds(node))
func _hoist(index: int,at: Vector3) -> void:
 var node=_geometry("NorthernWarehouseHoist%02d"%(index+1))
 node.box(at+Vector3.UP*.12,Vector3(.95,.24,.95),materials.timber)
 for z in [-.32,.32]:node.beam(at+Vector3(-.35,.2,z),at+Vector3(.05,2.6,z*.45),.13,materials.timber)
 node.cylinder(at+Vector3.UP*2.25,.15,4.5,materials.timber,12)
 var tip:=at+Vector3(3.0,4.0,0)
 node.beam(at+Vector3.UP*3.45,tip,.19,materials.timber)
 node.beam(at+Vector3.UP*4.50,tip,.045,materials.iron)
 node.box(at+Vector3(.05,1.05,0),Vector3(.55,.20,.55),materials.iron)
 node.beam(at+Vector3(0,1.08,-.52),at+Vector3(0,1.08,.52),.09,materials.iron)
 var wheel: Array[Vector3]=[]
 for i in 17:wheel.append(at+Vector3(cos(TAU*i/16)*.32,1.08+sin(TAU*i/16)*.32,.50))
 node.tube(wheel,.032,materials.iron,1.0)
 var hook:=tip-Vector3.UP*1.9
 node.beam(tip,hook,.028,materials.rope)
 var hook_points: Array[Vector3]=[hook,hook+Vector3(.0,-.18,0),hook+Vector3(.18,-.30,0),hook+Vector3(.34,-.18,0),hook+Vector3(.28,-.07,0)]
 node.tube(hook_points,.055,materials.iron,1.0)
 _finish(node);hoists.append({"node":node,"base":at,"tip":tip,"hook":hook})
 _extend_bounds("frontage",_mesh_bounds(node))
func _crate(node,at: Vector3,size_: float) -> void:
 node.box(at+Vector3.UP*size_*.5,Vector3.ONE*size_,materials.timber)
 for side in [-1.0,1.0]:
  node.box(at+Vector3(side*size_*.34,size_*.5,size_*.51),Vector3(.06,size_,.04),materials.trim)
  node.box(at+Vector3(size_*.51,size_*.5,side*size_*.34),Vector3(.04,size_,.06),materials.trim)
 node.beam(at+Vector3(-size_*.44,.07,size_*.54),at+Vector3(size_*.44,size_*.91,size_*.54),.055,materials.trim)
func _barrel(node,at: Vector3) -> void:
 node.cylinder(at+Vector3.UP*.35,.27,.70,materials.timber,12,.245)
 for y in [.13,.57]:node.cylinder(at+Vector3.UP*y,.28,.06,materials.iron,12)
func _rear_streets() -> void:
 for row in ROW_Z.size():
  # One material batch per street, retaining actual 3D roofs without hundreds
  # of per-window nodes or changing the existing town's random generator.
  var node=_geometry("NorthernRearStreet%02d"%(row+1))
  for col in 7:
   var at:=Vector3(-49.0-col*17.0+float(row%2)*.75,0,ROW_Z[row])
   var width_: float=7.5+float((row+col)%3)*.62
   var height_: float=4.5+float((row*2+col)%4)*.55
   var depth_: float=8.2+float((row+col*2)%3)*.55
   _building(node,at,width_,height_,depth_,materials[["cream","brick","blue"][(row+col)%3]],false,row*7+col)
   houses.append({"node":node,"at":at,"width":width_,"wall_height":height_,"depth":depth_,"roof_peak":height_+2.0+width_*.1,"row":row})
  _finish(node)
  var box:=_mesh_bounds(node)
  rear_rows.append({"z":ROW_Z[row],"rect":Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)),"top_y":box.end.y,"node":node})
  _extend_bounds("rear",box)
