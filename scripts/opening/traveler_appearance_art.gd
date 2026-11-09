extends RefCounted
## Four standing views. The accepted right-facing 3/4 pixels remain intact.
## Drawn on the established 32px grid and enlarged nearest to 128px.
## Six authored parts retain their own complete canvas and shared foot datum.
const Art=preload("res://scripts/pixel_art.gd")
const PARTS: Array[String]=["right_leg","left_leg","torso","left_arm","right_arm","head"]
const PALETTE: Dictionary={
 "o":Color("302b2a"),"M":Color("50372b"),"H":Color("795039"),"h":Color("a16b49"),"L":Color("ce976b"),
 "I":Color("e9d9bd"),"i":Color("bca78b"),"l":Color("fff0d7"),
 "V":Color("2c4035"),"v":Color("4d644b"),"e":Color("7f8d68"),
 "P":Color("715747"),"p":Color("4e3e35"),"B":Color("49352b"),"b":Color("956947"),"g":Color("d1aa66"),
 "F":Color("ffdfbd"),"s":Color("d5a17e"),"E":Color("323930"),"G":Color("6b8677"),"w":Color("fff6dc"),"r":Color("e8a78e"),
 "T":Color("344c3b"),"t":Color("7b8b63")}
static var _layers: Dictionary={}
static var _textures: Dictionary={}
static var _direction_layers: Dictionary={}
static func layers(direction: String="right") -> Dictionary:
 if direction=="right" or direction not in ["front","back","left"]:return _right_layers()
 if _direction_layers.has(direction):return _direction_layers[direction]
 if direction=="left":
  var mirrored: Dictionary={}
  var original:=_right_layers()
  for id in PARTS:
   var source_id: String={"right_arm":"left_arm","left_arm":"right_arm","right_leg":"left_leg","left_leg":"right_leg"}.get(id,id)
   var image: Image=original[source_id].get_image().duplicate();image.flip_x()
   mirrored[id]=ImageTexture.create_from_image(image)
  _direction_layers[direction]=mirrored;return mirrored
 _direction_layers[direction]=_face_on_layers(direction=="back")
 return _direction_layers[direction]
static func _right_layers() -> Dictionary:
 if not _layers.is_empty():return _layers
 var raw: Dictionary={}
 for id in PARTS:
  raw[id]=Image.create(32,32,false,Image.FORMAT_RGBA8);raw[id].fill(Color.TRANSPARENT)
 # The same ankle/sole rows and separated shoulders as the existing hero.
 Art._stamp(raw.right_leg,["oPPPo","oPpPo","oBBBo","oBgBo","oBBBo"],Vector2i(12,23),PALETTE)
 Art._stamp(raw.left_leg,["oPPPo","oPPpo","oBBBo","oBbBo","oBBBo"],Vector2i(18,23),PALETTE)
 Art._stamp(raw.torso,[
  "..oo.II.oo..",".oIIoIIoIIo.","oIlVVlVVViIo","oIivVgVvViIo",
  ".oIVVgVVVVo.","..oPPPPPoo..","..oPppPPPo..","..oPPoPPoo.."
 ],Vector2i(10,18),PALETTE)
 # Tiny waistcoat buttons and a short U of brass suggest the pocket watch.
 for point in [Vector2i(17,20),Vector2i(17,22),Vector2i(19,22),Vector2i(20,23),Vector2i(21,22)]:raw.torso.set_pixelv(point,PALETTE.g)
 Art._stamp(raw.left_arm,[".oIi","oIIl",".oIi","..sF","...o"],Vector2i(8,19),PALETTE)
 Art._stamp(raw.right_arm,["oIio.","oIIl.","oIiIo",".sFFo","..oo."],Vector2i(21,19),PALETTE)
 # Shorter half-up chestnut hair: a simple wave silhouette rather than the
 # original long ponytail. The lower curl is part of the head, not a sleeve.
 Art._stamp(raw.head,[
  "......oooooo......","....ooMMHHhMoo....","...oMHhLLhhHMMo...",
  "..oMHhLLhhhHHMMo..",".oMHhLhhhhhhHMMMo.",".oMhLhhhhhhHHHMMo.",
  "oMHhhhhhhhHHHMMMo.","oMHhhhhhhHHHMMMMo.","oMHHhhhhHHHMMMMMo.",
  "oMHMMhhhHHMMMMMMo.","oMHHMMhhHMMMMMMMo.","oMHHMMhHHMMMMMMMo.",
  ".oHHMMHHMMMMMMMo..","oMHMMHHMMMMMMMo...","oMHMMHMMMMMMMo....",
  ".oMMoMMMMMMMo.....","..oo..oooooo......"
 ],Vector2i(7,2),PALETTE)
 Art._stamp(raw.head,[
  "...ssss...","..sFFFFss.",".sFFFFFFFs","sFFFFFFFFs","sFFFFFFFFs",
  "sFFFFFFFFs",".sFFFFFFs.","..sFFFFs..","...ssss..."
 ],Vector2i(12,9),PALETTE)
 # Swept side part leaves both eyes readable at the actual game scale.
 Art._stamp(raw.head,[
  "hLLLhhhhHHhhh","hLLhhhhHHHhhh","hhhhhhHHHHhhh","hhhhHHHH.Hhh.",
  "hhhHHHH...Hh.","hhHHHH.....H.","hHHHH........","HHH.........."
 ],Vector2i(10,5),PALETTE)
 Art._stamp(raw.head,["oT..o","oTToT",".tTTo","oTtTo","oT.o."],Vector2i(6,9),PALETTE)
 Art._stamp(raw.head,["oTo","oT.",".t.",".o."],Vector2i(7,14),PALETTE)
 # Bring the near eye one logical pixel inside the cheek; a 3/4 face must
 # retain two eyes rather than reading as a strict side profile.
 for point in [Vector2i(15,12),Vector2i(16,12),Vector2i(15,13),Vector2i(16,14),Vector2i(20,12),Vector2i(21,12),Vector2i(21,13),Vector2i(20,14)]:raw.head.set_pixelv(point,PALETTE.E)
 for point in [Vector2i(16,13),Vector2i(20,13)]:raw.head.set_pixelv(point,PALETTE.G)
 for point in [Vector2i(15,13),Vector2i(20,12)]:raw.head.set_pixelv(point,PALETTE.w)
 for point in [Vector2i(14,15),Vector2i(21,15)]:raw.head.set_pixelv(point,PALETTE.r)
 raw.head.set_pixel(19,15,PALETTE.s);raw.head.set_pixel(18,16,Color("a96c5b"))
 raw.head.fill_rect(Rect2i(14,18,6,2),Color.TRANSPARENT)
 raw.head.set_pixel(16,18,PALETTE.F);raw.head.set_pixel(17,18,PALETTE.s)
 for point in [Vector2i(14,19),Vector2i(15,20),Vector2i(18,19)]:raw.torso.set_pixelv(point,PALETTE.l)
 for id in PARTS:
  raw[id].resize(128,128,Image.INTERPOLATE_NEAREST)
  _layers[id]=ImageTexture.create_from_image(raw[id])
 return _layers
static func texture(direction: String="right") -> ImageTexture:
 if _textures.has(direction):return _textures[direction]
 var image:=Image.create(128,128,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 var pieces:=layers(direction)
 for id in PARTS:image.blend_rect(pieces[id].get_image(),Rect2i(0,0,128,128),Vector2i.ZERO)
 _textures[direction]=ImageTexture.create_from_image(image)
 return _textures[direction]
static func _face_on_layers(back: bool) -> Dictionary:
 var raw: Dictionary={}
 for id in PARTS:
  raw[id]=Image.create(32,32,false,Image.FORMAT_RGBA8);raw[id].fill(Color.TRANSPARENT)
 var first: String="left_leg" if back else "right_leg"
 var second: String="right_leg" if back else "left_leg"
 Art._stamp(raw[first],["oPPPo","oPpPo","oBBBo","oBgBo","oBBBo"],Vector2i(11,23),PALETTE)
 Art._stamp(raw[second],["oPPPo","oPPpo","oBBBo","oBbBo","oBBBo"],Vector2i(17,23),PALETTE)
 if back:
  Art._stamp(raw.torso,[
   "..ooIIIIoo..",".oIVVVVVVIo.","oIIVvVVvVIIo","oIIVVVVVVIIo",
   ".oIVVvVVIo..","..oPPPPPoo..","..oPppPPPo..","..oPPoPPoo.."
  ],Vector2i(10,18),PALETTE)
 else:
  Art._stamp(raw.torso,[
   "..oo.II.oo..",".oIIoIIoIIo.","oIlVVlVVViIo","oIivVgVvViIo",
   ".oIVVgVVVVo.","..oPPPPPoo..","..oPppPPPo..","..oPPoPPoo.."
  ],Vector2i(10,18),PALETTE)
  for point in [Vector2i(16,20),Vector2i(16,22),Vector2i(19,22),Vector2i(20,23),Vector2i(21,22)]:raw.torso.set_pixelv(point,PALETTE.g)
  for point in [Vector2i(14,19),Vector2i(17,19)]:raw.torso.set_pixelv(point,PALETTE.l)
 var left_id: String="right_arm" if back else "left_arm"
 var right_id: String="left_arm" if back else "right_arm"
 Art._stamp(raw[left_id],[".oIi","oIIl",".oIi","..sF","...o"],Vector2i(8,19),PALETTE)
 Art._stamp(raw[right_id],["oIio.","oIIl.","oIiIo",".sFFo","..oo."],Vector2i(21,19),PALETTE)
 Art._stamp(raw.head,[
  "......oooooo......","....ooMMHHMMoo....","...oMHHhhLhhHMo...",
  "..oMHhLLLhhHHMMo..",".oMHhLLLhhhHHMMMo.","oMHhLLhhhhHHHMMMo.",
  "oMHhhhhhhHHHHMMMo.","oMHhhhhhHHHHMMMMo.","oMHHhhhhHHHHMMMMo.",
  "oMHHHhhHHHMMMMMMo.","oMHHMhhHHMMMMMMMo.","oMHHMHHHMMMMMMMMo.",
  ".oHHMMHHMMMMMMMo..","oMHHMMHHMMMMMMMo..","oMHMMHMMMMMMMMo...",
  ".oMMoMMMMoMMMo....","..oo..ooooooo....."
 ],Vector2i(7,2),PALETTE)
 if back:
  # A centered half-up tie and two short tails show why this is the rear.
  Art._stamp(raw.head,["oTTo.oTTo","oTtToTtTo",".oTTtTTo.","..oTTo...","..oTtTo..","..oT.oT..","..ot..o.."],Vector2i(12,11),PALETTE)
 else:
  Art._stamp(raw.head,[
   "...ssssss...","..sFFFFFFs..",".sFFFFFFFFs.","sFFFFFFFFFFs","sFFFFFFFFFFs",
   "sFFFFFFFFFFs",".sFFFFFFFFs.","..sFFFFFFs..","...ssssss..."
  ],Vector2i(10,9),PALETTE)
  Art._stamp(raw.head,[
   "hhLLLhhhhhhh","hLLLhhhhHHhh","LLLhhhhHHHhh","LhhhhHHHHHhh",
   "hhhhHHHH.HHh","hhhHHHH...HH","hhHHHH.....H","hHHH........"
  ],Vector2i(10,4),PALETTE)
  # Compact 3x2 eyes fit this narrower face; retain the NPC-inspired lash.
  var eye_outline:=Color("292b36")
  for side in 2:
   var reflected: bool=side==1
   for point in [Vector2i(11,12),Vector2i(12,12),Vector2i(13,12),Vector2i(13,13)]:
    raw.head.set_pixel(31-point.x if reflected else point.x,point.y,eye_outline)
   raw.head.set_pixel(19 if reflected else 12,13,PALETTE.G)
   raw.head.set_pixel(20 if reflected else 11,13,PALETTE.w)
  for point in [Vector2i(11,15),Vector2i(20,15)]:raw.head.set_pixelv(point,PALETTE.r)
  raw.head.set_pixel(16,15,PALETTE.s);raw.head.set_pixel(16,16,Color("a96c5b"))
  raw.head.fill_rect(Rect2i(13,18,7,2),Color.TRANSPARENT)
  raw.head.set_pixel(15,18,PALETTE.F);raw.head.set_pixel(16,18,PALETTE.s)
  Art._stamp(raw.head,["oTo","otT",".oT"],Vector2i(7,11),PALETTE)
 var result: Dictionary={}
 for id in PARTS:
  raw[id].resize(128,128,Image.INTERPOLATE_NEAREST)
  if not back and id=="head":
   refine_front_mouth(raw[id],"front")
  result[id]=ImageTexture.create_from_image(raw[id])
 return result
static func refine_front_mouth(image: Image,direction: String,bob_pixels: int=0) -> void:
 if direction!="front":return
 # Keep this fine detail after the animation factories' logical-grid resize.
 image.fill_rect(Rect2i(64,64+bob_pixels,4,4),PALETTE.F)
 image.fill_rect(Rect2i(65,65+bob_pixels,2,2),Color("a96c5b"))
