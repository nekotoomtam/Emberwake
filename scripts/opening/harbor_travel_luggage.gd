extends Node3D
## One authored cafe suitcase, with a private harbor-only gripping pose.
## The resting body never follows the visual when the traveller carries it.
const Detail=preload("res://scripts/opening/harbor_detail.gd")
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
const Directions=preload("res://scripts/opening/harbor_hero_appearance.gd")
const Coffee=preload("res://scripts/opening/harbor_hero_appearance.gd")
const TravelerFrames=preload("res://scripts/opening/traveler_harbor_frames.gd")
const TravelerArt=preload("res://scripts/opening/traveler_appearance_art.gd")
const Art=preload("res://scripts/pixel_art.gd")
const REST_POSITION:=Profile.CAFE+Vector3(-.25,.24,.80)
const HANDLE:=Vector3(-.005,.37,0)
const PALETTE:={"o":Color("262333"),"T":Color("2f5869"),"t":Color("50888c"),"b":Color("b38c5d"),"D":Color("24394c"),"F":Color("ffddbc"),"s":Color("e7a183")}
static var carry_cache: Dictionary={}
static var stand_cache: Dictionary={}
var materials: Dictionary={}
var visual_root: Node3D
var floor_body: StaticBody3D
var grip: Marker3D
var stand_arm: Sprite3D
var state: StringName=&"resting"
var stand_progress:=0.0
var carry_facing:="right"
var hand_world:=Vector3.ZERO
var geometry_count:=0
func _ready() -> void:
 for entry in [["wood","956d51","wood"],["darkwood","5d483d","wood"],["gold","cfa76f","wood"],["canvas","eddfb9","plaster"]]:
  if not materials.has(entry[0]):materials[entry[0]]=Detail.material(entry[1],entry[2],8870+materials.size())
 visual_root=Node3D.new();visual_root.name="OriginalTravellerSuitcase";add_child(visual_root)
 var detail=Detail.new();detail.name="LeatherCaseStrapsAndHandle";visual_root.add_child(detail)
 detail.box(Vector3.ZERO,Vector3(.6,.46,.3),materials.wood)
 for x in [-.20,.18]:
  detail.box(Vector3(x,0,.17),Vector3(.07,.46,.025),materials.darkwood)
  detail.box(Vector3(x,.02,.19),Vector3(.08,.09,.025),materials.gold)
 detail.tube([Vector3(-.16,.22,0),Vector3(-.13,.37,0),Vector3(.12,.37,0),Vector3(.15,.22,0)],.027,materials.darkwood,.8)
 detail.box(Vector3(.07,.16,.19),Vector3(.13,.16,.018),materials.canvas)
 geometry_count=detail.count;detail.finish()
 grip=Marker3D.new();grip.name="HandleInsideFingers";grip.position=HANDLE;visual_root.add_child(grip)
 floor_body=StaticBody3D.new();floor_body.name="RestingSuitcaseCollision";floor_body.collision_layer=1;floor_body.collision_mask=0;floor_body.add_to_group("harbor_plaza_prop");add_child(floor_body)
 var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.6,.46,.3);collision.shape=shape;floor_body.add_child(collision)
 stand_arm=Sprite3D.new();stand_arm.name="TravellerReachingSleeveAndFingers";stand_arm.pixel_size=.018;stand_arm.shaded=false;stand_arm.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;stand_arm.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;add_child(stand_arm)
 reset_resting()
func reset_resting() -> void:
 state=&"resting";stand_progress=0;carry_facing="right"
 visual_root.transform=Transform3D(Basis.IDENTITY,REST_POSITION)
 floor_body.position=REST_POSITION;floor_body.collision_layer=1
 hand_world=grip.global_position;stand_arm.visible=false
func update_stand(progress: float,hero: Sprite3D,camera: Camera3D,target_override: Vector3=Vector3.INF) -> void:
 stand_progress=clampf(progress,0,1)
 if stand_progress<=0:reset_resting();return
 state=&"lifting";stand_arm.visible=stand_progress<1
 var index: int=mini(3,int(stand_progress*4))
 hero.texture=_stand_texture(index)
 var rest_grip: Vector3=global_transform*(REST_POSITION+HANDLE)
 # The initial walker includes the original .1 m spawn clearance and .045 m
 # foot offset. Reach that same hand before the standing actor takes over.
 var target: Vector3=_pixel_world(hero,carry_hand_pixel("right","idle",0),camera)+Vector3.UP*.145
 if target_override.is_finite():target=target_override
 var lift: float=smoothstep(.25,1.0,stand_progress)
 var held: Vector3=rest_grip.lerp(target,lift)
 if stand_progress<.25:
  hand_world=_pixel_world(hero,Vector2(11.5,22.5),camera).lerp(rest_grip,smoothstep(0,.25,stand_progress))
  visual_root.transform=Transform3D(Basis.IDENTITY,REST_POSITION)
 else:
  floor_body.collision_layer=0;hand_world=held
  _place_handle(held,camera,0)
 if not target_override.is_finite():_stand_arm_pose(hero,camera,index)
 if stand_progress>=1:hero.texture=carry_texture("right","idle",0)
func update_carry(walker,camera: Camera3D) -> void:
 state=&"carried";stand_progress=1;carry_facing=walker.facing
 stand_arm.visible=false;floor_body.collision_layer=0
 hand_world=walker.modular_grip() if not walker.modular_frame.is_empty() else _pixel_world(walker.sprite,carry_hand_pixel(walker.facing,walker.art_action,walker.art_frame),camera)
 var swing: float=sin(walker.clock*8.0)*.055 if walker.art_action=="walk" else sin(walker.clock*2.0)*.008
 _place_handle(hand_world,camera,swing)
func follow_standing_grip(point: Vector3,camera: Camera3D) -> void:
 stand_arm.hide()
 if stand_progress>=.25:
  hand_world=point
  _place_handle(point,camera,0)
func _place_handle(at: Vector3,camera: Camera3D,swing: float) -> void:
 var right:=Vector3(camera.global_basis.x.x,0,camera.global_basis.x.z).normalized()
 var basis_:=Basis(right,Vector3.UP,right.cross(Vector3.UP)).rotated(right.cross(Vector3.UP),swing)
 visual_root.global_transform=Transform3D(basis_,at-basis_*HANDLE)
func _stand_arm_pose(hero: Sprite3D,camera: Camera3D,index: int) -> void:
 var relative: Vector3=hand_world-hero.global_position
 var hand:=Vector2(16+relative.dot(camera.global_basis.x)/.072,16-relative.dot(camera.global_basis.y)/.072)
 var image:=Image.create(32,32,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 var offset: int=[5,3,1,0][index]
 _arm(image,Vector2(11,19+offset),hand)
 image.resize(128,128,Image.INTERPOLATE_NEAREST);stand_arm.texture=ImageTexture.create_from_image(image)
 stand_arm.global_basis=hero.global_basis;stand_arm.global_position=hero.global_position+camera.global_basis.z*.035
static func _pixel_world(sprite: Sprite3D,pixel: Vector2,camera: Camera3D) -> Vector3:
 return sprite.global_position+sprite.global_basis.x*((pixel.x-16)*.072)+sprite.global_basis.y*((16-pixel.y)*.072)+camera.global_basis.z*.018
static func carry_hand_pixel(facing: String,action: String,index: int) -> Vector2:
 var bob: int=-1 if action=="walk" and index%2==1 else 0
 return Vector2(23.5 if facing in ["back","left"] else 8.5,18.5+bob)
static func carry_texture(facing: String,action: String,index: int) -> Texture2D:
 var key:=Directions.profile_id+":"+facing+":"+action+":"+str(index)
 if carry_cache.has(key):return carry_cache[key]
 var source: String="right" if facing=="left" else facing
 var image: Image
 if Directions.is_traveler():
  image=Image.create(32,32,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
  var pieces:=TravelerFrames.logical_parts(source,action,index)
  for id in TravelerArt.PARTS:
   if id!="left_arm":image.blend_rect(pieces[id],Rect2i(0,0,32,32),Vector2i.ZERO)
 else:
  image=Directions.frames(source).get_frame_texture(action,index).get_image().duplicate();image.resize(32,32,Image.INTERPOLATE_NEAREST)
  if source!="back":Art._stamp(image,["oTT","oTT","oTb","oDD"],Vector2i(10,20),PALETTE)
 var hand:=carry_hand_pixel(source,action,index)
 _arm(image,Vector2(20,19) if source=="back" else Vector2(11,19),hand)
 if facing=="left":image.flip_x()
 image.resize(128,128,Image.INTERPOLATE_NEAREST)
 if Directions.is_traveler():TravelerArt.refine_front_mouth(image,facing,-4 if index%2==1 and action in ["idle","walk"] else 0)
 var texture:=ImageTexture.create_from_image(image);carry_cache[key]=texture;return texture
static func _stand_texture(index: int) -> Texture2D:
 var key:=Directions.profile_id+":"+str(index)
 if stand_cache.has(key):return stand_cache[key]
 var image: Image
 if Directions.is_traveler() and index>0:
  image=Image.create(32,32,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
  var pieces:=TravelerArt.layers("right")
  var offset:=Vector2i(0,[5,3,1,0][index])
  for id in TravelerArt.PARTS:
   if id=="left_arm":continue
   var piece: Image=pieces[id].get_image().duplicate();piece.resize(32,32,Image.INTERPOLATE_NEAREST)
   image.blend_rect(piece,Rect2i(0,0,32,32-offset.y),offset)
 else:
  image=Coffee.rising(index).get_image().duplicate();image.resize(32,32,Image.INTERPOLATE_NEAREST)
  if index>0:Art._stamp(image,["oTT","oTT","oTb","oDD"],Vector2i(10,20+[5,3,1,0][index]),PALETTE)
 image.resize(128,128,Image.INTERPOLATE_NEAREST)
 var texture:=ImageTexture.create_from_image(image);stand_cache[key]=texture;return texture
static func _arm(image: Image,shoulder: Vector2,hand: Vector2) -> void:
 var palette:=PALETTE
 if Directions.is_traveler():palette={"o":TravelerArt.PALETTE.o,"T":TravelerArt.PALETTE.I,"t":TravelerArt.PALETTE.i,"F":TravelerArt.PALETTE.F,"s":TravelerArt.PALETTE.s}
 var elbow:=shoulder.lerp(hand,.6)+Vector2(0,1.5)
 _stroke(image,shoulder,elbow,palette.o,3);_stroke(image,elbow,hand,palette.o,3)
 _stroke(image,shoulder,elbow,palette.T,2);_stroke(image,elbow,hand,palette.s,1)
 Art._stamp(image,[".oo.","osFo","oFsF",".oo."],Vector2i(floori(hand.x)-1,floori(hand.y)-1),palette)
static func _stroke(image: Image,from: Vector2,to: Vector2,color: Color,width: int) -> void:
 var steps: int=maxi(1,ceili(from.distance_to(to)*2))
 for i in steps+1:
  var point: Vector2=from.lerp(to,float(i)/steps)
  for y in width:
   for x in width:Art._pixel(image,Vector2i(roundi(point.x)+x-width/2,roundi(point.y)+y-width/2),color)
