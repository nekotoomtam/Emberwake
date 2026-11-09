extends Node3D
## One world-aligned dressed-stone grid across the west/front promenade L.
## The existing continuous ground owns physics; these recessed joints add no
## steps or collider seams to the .055m walking plane.
const Detail=preload("res://scripts/opening/harbor_detail.gd")
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
const GRID_ORIGIN:=Vector2(-51,4.3)
const SLAB_PITCH:=.8
const JOINT_WIDTH:=.025
const SURFACE_Y:=.055
const JOINT_TOP_Y:=.043
var materials: Dictionary={}
var geometry_count:=0
var geometry
func _ready() -> void:
 name="HarborPromenadePaving";add_to_group("harbor_promenade_paving")
 for entry in [["promenade_slab","d5c8ad"],["promenade_slab_light","ded1b7"],["promenade_slab_warm","cdbfa2"],["promenade_grout","929082"]]:
  if not materials.has(entry[0]):materials[entry[0]]=Detail.material(entry[1],"plaster",9520+materials.size())
 geometry=Detail.new();geometry.name="PromenadeSlabGeometry";add_child(geometry)
 for rect in [Profile.PROMENADE_WEST_RECT,Profile.PROMENADE_FRONT_RECT]:_band(rect)
 geometry_count=geometry.count;geometry.finish()
func _band(rect: Rect2) -> void:
 var center:=rect.get_center()
 geometry.box(Vector3(center.x,JOINT_TOP_Y-.01,center.y),Vector3(rect.size.x,.02,rect.size.y),materials.promenade_grout)
 var first_x:=int(floor((rect.position.x-GRID_ORIGIN.x)/SLAB_PITCH))
 var last_x:=int(ceil((rect.end.x-GRID_ORIGIN.x)/SLAB_PITCH))
 var first_z:=int(floor((rect.position.y-GRID_ORIGIN.y)/SLAB_PITCH))
 var last_z:=int(ceil((rect.end.y-GRID_ORIGIN.y)/SLAB_PITCH))
 for row in range(first_z,last_z):
  for col in range(first_x,last_x):
   var cell:=Rect2(GRID_ORIGIN+Vector2(col,row)*SLAB_PITCH,Vector2.ONE*SLAB_PITCH)
   var tile:=cell.intersection(rect).grow(-JOINT_WIDTH*.5)
   if tile.size.x<=.02 or tile.size.y<=.02:continue
   var at:=tile.get_center()
   var shade:=posmod(row*7+col*11,13)
   var stone: Material=materials.promenade_slab_light if shade==0 else (materials.promenade_slab_warm if shade==4 else materials.promenade_slab)
   geometry.box(Vector3(at.x,SURFACE_Y-.02,at.y),Vector3(tile.size.x,.04,tile.size.y),stone)
