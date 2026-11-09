extends RefCounted
## The established six sipping and four standing timings, dressed as the
## new traveler. Original coffee artwork remains available via the profile.
const Art=preload("res://scripts/pixel_art.gd")
const Standing=preload("res://scripts/opening/traveler_appearance_art.gd")
static var cache: Dictionary={}
const P: Dictionary={"o":Color("302b2a"),"T":Color("2c4035"),"t":Color("4d644b"),"c":Color("e9d9bd"),"b":Color("d1aa66"),"D":Color("715747"),"d":Color("4e3e35"),"B":Color("49352b"),"k":Color("956947"),"F":Color("ffdfbd"),"s":Color("d5a17e")}
static func seated() -> Texture2D:return sipping(0)
static func sipping(index: int) -> Texture2D:
 index=clampi(index,0,5);var key: String="sip:"+str(index)
 if cache.has(key):return cache[key]
 var source: Image=Standing.texture("right").get_image().duplicate();source.resize(32,32,Image.INTERPOLATE_NEAREST)
 var image:=Image.create(32,32,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 image.blit_rect(source,Rect2i(0,0,32,19),Vector2i(0,5))
 Art._stamp(image,["..oTTccTTTo..",".oTtTccTTtTo.",".oTTTbbbbbTo.","..oDDddddDDo.","...oDDDDDDDo.","....oooDDDDo."],Vector2i(10,23),P)
 var arms: Array=[
  ["oTTTo...",".oTtTo..","..osFFo.","....oFFo"],
  ["oTTTo.....",".oTtTToo..","..ooTTsFFo","....ooFFo."],
  ["oTTToo..",".oTtsFFo","..oTsFFo","...oooo."],
  ["osFFo..","oTFFo..",".oTTo..","..oo..."],
  ["oTTTo...",".oTtTo..","..oTsFFo","...oFFo."],
  ["oTTTo...",".oTtTo..","..osFFo.","....oFFo"]]
 var sleeve:=P.duplicate();sleeve.T=Standing.PALETTE.I;sleeve.t=Standing.PALETTE.i
 Art._stamp(image,arms[index],Vector2i(20,22),sleeve)
 Art._stamp(image,["oDDDDDDDo",".oDDDdDDDo","..oBBBoBBBo","..oBkBoBkBo","..oBBBoBBBo"],Vector2i(18,27),P)
 image.resize(128,128,Image.INTERPOLATE_NEAREST);cache[key]=ImageTexture.create_from_image(image);return cache[key]
static func rising(index: int) -> Texture2D:
 index=clampi(index,0,3)
 if index==0:return seated()
 var key: String="rise:"+str(index)
 if cache.has(key):return cache[key]
 var source: Image=Standing.texture("right").get_image().duplicate();source.resize(32,32,Image.INTERPOLATE_NEAREST)
 var image:=Image.create(32,32,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 var offset: int=[5,3,1,0][index]
 image.blit_rect(source,Rect2i(0,0,32,32-offset),Vector2i(0,offset))
 image.resize(128,128,Image.INTERPOLATE_NEAREST);cache[key]=ImageTexture.create_from_image(image);return cache[key]
