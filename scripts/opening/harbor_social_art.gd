extends RefCounted
## Original social poses; caches belong to these NPCs, never to the traveller.
const Appearance=preload("res://scripts/opening/npc_appearance.gd")
const Pixel=preload("res://scripts/pixel_art.gd")
static var cache: Dictionary={}
static var canvas_cache: Texture2D
static func frame(profile: Dictionary,role: String,side: String,pose: int) -> Texture2D:
 var key: String=str(profile.get("id","social"))+":"+str(profile.hash())+":"+role+":"+side+":"+str(pose)
 if cache.has(key):return cache[key]
 var im: Image
 if role=="coffee":im=_seated(profile,side,pose)
 else:im=_standing(profile,role,side,pose)
 im.resize(128,128,Image.INTERPOLATE_NEAREST)
 var result:=ImageTexture.create_from_image(im);cache[key]=result;return result
static func _palette(profile: Dictionary) -> Dictionary:
 var coat:=Color(profile.get("coat","657f83"));var skin:=Color(profile.get("skin","e5b591"))
 return {"o":Color("292b36"),"T":coat,"t":coat.lightened(.19),"D":coat.darkened(.30),"d":coat.darkened(.14),"b":Color("86654f"),"c":Color("e5d5b6"),"B":Color("233242"),"k":Color("586675"),"F":skin,"s":skin.darkened(.2)}
static func _head(profile: Dictionary,side: String) -> Image:
 # Appearance supplies this resident's own hairstyle/face, not player art.
 var source:=Appearance.draw(int(profile.get("hairstyle",2)),bool(profile.get("male",false)),side,-1,"idle",0,profile)
 source.resize(32,32,Image.INTERPOLATE_NEAREST)
 return source
static func _seated(profile: Dictionary,side: String,pose: int) -> Image:
 var im:=Image.create(32,32,false,Image.FORMAT_RGBA8);im.fill(Color.TRANSPARENT)
 var p:=_palette(profile)
 var head:=_head(profile,"right")
 # Slightly lower shoulders, a horizontal thigh, bent knees and grounded boots.
 im.blit_rect(head,Rect2i(0,0,32,19),Vector2i(0,2))
 Pixel._stamp(im,["..oo.cc.oo...",".oTTTccTTTo..","oTTtTTTTtTTo.","oTTtTTTTtTTo.",".oTTbbbbTTo..","..oDDddddDDDo","...oDDDDddDDo","....ooooDDDo.","........oDDo.","........oDDo.",".......oBBBo.",".......oBkkBo",".......oooooo"],Vector2i(10,18),p)
 # Outer arm reaches the table at rest; the elbow stays bent during a sip.
 var arms: Array=[
  ["oTTo........","oTtTo.......",".oTTTo......","..oTTsFFFo..","...oooooo..."],
  ["oTTo........","oTtTo...oFFo",".oTTTo.oFFo.","..oTTsFFo...","...ooooo...."],
  ["oTTo...oFFo.","oTtTo..oFFo.",".oTTTooFFo..","..oTTsFFo...","...ooooo...."],
  ["oTTo..oFFo..","oTtTo.oFFo..",".oTTToFFo...","..oTTsFFo...","...ooooo...."]]
 Pixel._stamp(im,arms[clampi(pose,0,3)],Vector2i(17,19),p)
 Pixel._stamp(im,["oTTo","oTtTo",".osFFo","..oooo"],Vector2i(10,20),p)
 if side=="left":im.flip_x()
 return im
static func _standing(profile: Dictionary,role: String,side: String,pose: int) -> Image:
 var im:=_head(profile,side)
 var p:=_palette(profile)
 # Remove only the old hands: every social role gets an authored arm gesture.
 im.fill_rect(Rect2i(7,19,7,8),Color.TRANSPARENT);im.fill_rect(Rect2i(21,19,8,8),Color.TRANSPARENT)
 if role=="painter":
  Pixel._stamp(im,["oTTo...","oTtTo..",".oTtTo.","..osFFo","...oFFo"],Vector2i(10,19),p)
  var y: int=17-(pose%3)
  Pixel._stamp(im,["......oFFo",".....oFFFo","....oTsFFo","...oTtTTo.","..oTtTTo..",".oTTToo...",".oTTo....."],Vector2i(20,y),p)
 else:
  # Hand on hip and the other hand resting on the skirt; a readable portrait pose.
  Pixel._stamp(im,["..oTTo",".oTtTo","osFFo.",".oFFo.","..oo.."],Vector2i(8,19),p)
  Pixel._stamp(im,["oTTo..","oTtTo.",".oTtTo","..osFF","...oFF"],Vector2i(21,19),p)
  if pose%2:
   im.set_pixel(14,16,Color(profile.get("skin","e5b591")));im.set_pixel(19,16,Color("b77c78"))
 return im
static func portrait() -> Texture2D:
 if canvas_cache:return canvas_cache
 var im:=Image.create(40,48,false,Image.FORMAT_RGBA8);im.fill(Color("d8c29a"))
 for y in 48:
  for x in 40:
   if (x*7+y*11)%23==0:im.set_pixel(x,y,Color("cfb78f"))
 # An unfinished harbor portrait: sea, warm sky, bun, face and rose dress.
 im.fill_rect(Rect2i(3,4,34,16),Color("aebbbb"));im.fill_rect(Rect2i(3,20,34,22),Color("699193"))
 for y in range(23,40,5):im.fill_rect(Rect2i(4,y,11,1),Color("b2c7b6"))
 Appearance.ellipse(im,22,16,8,9,Color("68624f"));Appearance.ellipse(im,22,18,5,7,Color("d7ae87"))
 Appearance.ellipse(im,20,9,4,3,Color("68624f"));im.fill_rect(Rect2i(17,11,12,4),Color("68624f"))
 im.fill_rect(Rect2i(19,18,2,1),Color("534f4c"));im.fill_rect(Rect2i(25,18,2,1),Color("534f4c"));im.fill_rect(Rect2i(22,23,3,1),Color("9c6c62"))
 for y in range(26,43):
  var half: int=5+(y-26)/4;im.fill_rect(Rect2i(22-half,y,half*2,1),Color("a3747c"))
 im.fill_rect(Rect2i(18,29,3,9),Color("b98c8a"));im.fill_rect(Rect2i(29,35,4,5),Color("d8c29a"))
 canvas_cache=ImageTexture.create_from_image(im);return canvas_cache
