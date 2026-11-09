extends RefCounted
const Art=preload("res://scripts/pixel_art.gd")
static func seated() -> ImageTexture:
 var source:=Art._actor_image("player","idle",0);var image:=Image.create(32,32,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 image.blit_rect(source,Rect2i(0,0,32,19),Vector2i(0,5))
 var p: Dictionary={"o":Color("262333"),"T":Color("2f5869"),"t":Color("50888c"),"c":Color("e8d9bc"),"b":Color("b38c5d"),"D":Color("24394c"),"d":Color("385568"),"B":Color("18293a"),"k":Color("5b6c7c"),"F":Color("ffddbc"),"s":Color("e7a183")}
 Art._stamp(image,["..oTTccTTTo..",".oTtTccTTtTo.",".oTTTbbbbbTo.","..oDDddddDDo.","...oDDDDDDDo.","....oooDDDDo."],Vector2i(10,23),p)
 Art._stamp(image,["oTTTo...",".oTtTo..","..osFFo.","....oFFo"],Vector2i(20,22),p)
 Art._stamp(image,["oDDDDDDDo",".oDDDdDDDo","..oBBBoBBBo","..oBkBoBkBo","..oBBBoBBBo"],Vector2i(18,27),p)
 image.resize(128,128,Image.INTERPOLATE_NEAREST);return ImageTexture.create_from_image(image)

static var rise_cache: Dictionary={}
static var sip_cache: Dictionary={}
static func sipping(index: int) -> ImageTexture:
 index=clampi(index,0,5)
 if sip_cache.has(index):return sip_cache[index]
 if index in [0,5]:
  var rest:=seated();sip_cache[index]=rest;return rest
 # Rebuild the same seated body beneath the hand instead of clearing face pixels.
 var source:=Art._actor_image("player","idle",0)
 var image:=Image.create(32,32,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 image.blit_rect(source,Rect2i(0,0,32,19),Vector2i(0,5))
 var p: Dictionary={"o":Color("262333"),"T":Color("2f5869"),"t":Color("50888c"),"c":Color("e8d9bc"),"b":Color("b38c5d"),"D":Color("24394c"),"d":Color("385568"),"B":Color("18293a"),"k":Color("5b6c7c"),"F":Color("ffddbc"),"s":Color("e7a183")}
 Art._stamp(image,["..oTTccTTTo..",".oTtTccTTtTo.",".oTTTbbbbbTo.","..oDDddddDDo.","...oDDDDDDDo.","....oooDDDDo."],Vector2i(10,23),p)
 var arms: Array=[
  [],
  ["oTTTo.....",".oTtTToo..","..ooTTsFFo","....ooFFo."],
  ["oTTToo..",".oTtsFFo","..oTsFFo","...oooo."],
  ["osFFo..","oTFFo..",".oTTo..","..oo..."],
  ["oTTTo...",".oTtTo..","..oTsFFo","...oFFo."]]
 Art._stamp(image,arms[index],Vector2i(20,22),p)
 Art._stamp(image,["oDDDDDDDo",".oDDDdDDDo","..oBBBoBBBo","..oBkBoBkBo","..oBBBoBBBo"],Vector2i(18,27),p)
 image.resize(128,128,Image.INTERPOLATE_NEAREST)
 var result:=ImageTexture.create_from_image(image);sip_cache[index]=result;return result

static func rising(index: int) -> ImageTexture:
 index=clampi(index,0,3)
 if rise_cache.has(index):return rise_cache[index]
 if index==0:return seated()
 var source: Image=Art._actor_image("player","idle",0)
 var image:=Image.create(32,32,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 var offset: int=[5,3,1,0][index]
 image.blit_rect(source,Rect2i(0,0,32,32-offset),Vector2i(0,offset))
 image.resize(128,128,Image.INTERPOLATE_NEAREST)
 var result:=ImageTexture.create_from_image(image);rise_cache[index]=result;return result
