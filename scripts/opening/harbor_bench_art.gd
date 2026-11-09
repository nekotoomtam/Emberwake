extends RefCounted
## Original seated pose in the protagonist's 32-source-pixel body language.
## One complete image avoids joints between differently projected body parts.
const Appearance=preload("res://scripts/opening/npc_appearance.gd")
const Pixel=preload("res://scripts/pixel_art.gd")
static var cache: Dictionary={}
static func _palette(profile: Dictionary) -> Dictionary:
 var coat:=Color(profile.get("coat","647d82"));var skin:=Color(profile.get("skin","e5b591"));var pants:=Color(profile.get("pants","53616b"));var boots:=Color(profile.get("boots","35404c"))
 return {"o":Color("292b36"),"T":coat,"t":coat.lightened(.18),"D":coat.darkened(.28),"d":coat.darkened(.1),"c":Color(profile.get("scarf","e5d5b6")),"p":pants,"P":pants.lightened(.16),"q":pants.darkened(.25),"B":boots,"k":boots.lightened(.21),"F":skin,"s":skin.darkened(.2)}
static func frame(profile: Dictionary,pose: int) -> Texture2D:
 var key:=str(profile.get("id","bench"))+":"+str(profile.hash())+":seated:"+str(pose)
 if cache.has(key):return cache[key]
 var image:=Image.create(32,32,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 var normal:=Appearance.draw(int(profile.get("hairstyle",2)),bool(profile.get("male",false)),"front",-1,"idle",0,profile)
 normal.resize(32,32,Image.INTERPOLATE_NEAREST)
 # The unchanged full resident head shares the player's normal world pixel size.
 image.blit_rect(normal,Rect2i(0,0,32,18),Vector2i.ZERO)
 var p:=_palette(profile)
 # Same eight torso rows and shoulder width as normal standing residents/player.
 Pixel._stamp(image,["..oo.cc.oo..",".oTTTccTTTo.","oTTtTTTTtTTo","oTTtTTTTtTTo",".oTTddddTTo.","..oDDDDDDoo.",".oDDdDDDdDo.","..oDDDDDDDo."],Vector2i(10,18),p)
 if bool(profile.get("waistcoat",false)):
  Pixel._stamp(image,[".DcD.",".DcD.",".DcD.",".DoD."],Vector2i(14,20),p)
 # Elbows fold beside the unchanged torso, hands settle on the upper lap.
 Pixel._stamp(image,["oTo..","oTTo.",".oTTo","..sFF","..oFo"],Vector2i(9,20),p)
 Pixel._stamp(image,["..oTo",".oTTo","oTTo.","FFs..","oFo.."],Vector2i(18,20),p)
 if pose==1:Pixel._stamp(image,[".sFFo","oFFFo",".ooo."],Vector2i(14,23),p)
 if pose==2:
  # A small sideways eye glance changes expression without translating the skull.
  for x in [13,19]:
   image.set_pixel(x,13,Color("292b36"));image.set_pixel(x-1,13,Color("6b9090"))
 # Five rows TOTAL: compact folded knee/shin, then the player's three-row boots.
 # These short legs may dangle; they are never lengthened to reach furniture.
 for x in [11,17]:
  Pixel._stamp(image,["oPPpo","opppo","oBBo.","oBkBo","oBBBo"],Vector2i(x,25),p)
 image.resize(128,128,Image.INTERPOLATE_NEAREST)
 var texture:=ImageTexture.create_from_image(image);cache[key]=texture;return texture
