extends RefCounted
## Harbor-only idle and walk poses, using the four authored six-part bodies.
const Standing=preload("res://scripts/opening/traveler_appearance_art.gd")
static var cache: Dictionary={}
static func logical_parts(direction: String,action: String,index: int) -> Dictionary:
 var result: Dictionary={};var original:=Standing.layers(direction)
 var bob: int=-1 if (action=="idle" and index%2==1) or (action=="walk" and index%2==1) else 0
 var step: int=[0,1,0,-1][posmod(index,4)] if action=="walk" else 0
 for id in Standing.PARTS:
  var image: Image=original[id].get_image().duplicate();image.resize(32,32,Image.INTERPOLATE_NEAREST)
  var offset:=Vector2i.ZERO
  if id=="head":offset.y=bob
  elif id=="right_leg":offset=Vector2i(-step,-1 if step>0 else 0)
  elif id=="left_leg":offset=Vector2i(step,-1 if step<0 else 0)
  elif id=="right_arm":offset.y=-1 if step<0 else 0
  elif id=="left_arm":offset.y=-1 if step>0 else 0
  var placed:=Image.create(32,32,false,Image.FORMAT_RGBA8);placed.fill(Color.TRANSPARENT)
  placed.blit_rect(image,Rect2i(0,0,32,32),offset);result[id]=placed
 return result
static func image(direction: String,action: String,index: int) -> Image:
 var result:=Image.create(32,32,false,Image.FORMAT_RGBA8);result.fill(Color.TRANSPARENT)
 var parts:=logical_parts(direction,action,index)
 for id in Standing.PARTS:result.blend_rect(parts[id],Rect2i(0,0,32,32),Vector2i.ZERO)
 return result
static func frames(direction: String) -> SpriteFrames:
 if cache.has(direction):return cache[direction]
 var result:=SpriteFrames.new();result.remove_animation("default")
 for action in ["idle","walk"]:
  result.add_animation(action);result.set_animation_loop(action,true);result.set_animation_speed(action,2.4 if action=="idle" else 8.0)
  for index in (2 if action=="idle" else 4):
   var pose:=image(direction,action,index);pose.resize(128,128,Image.INTERPOLATE_NEAREST)
   Standing.refine_front_mouth(pose,direction,-4 if index%2==1 else 0)
   result.add_frame(action,ImageTexture.create_from_image(pose))
 cache[direction]=result;return result
