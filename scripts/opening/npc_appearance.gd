extends RefCounted
const Body = preload("res://scripts/hero_directions.gd")
const Art = preload("res://scripts/pixel_art.gd")
const NAMES = ["Tidy crop", "Tousled", "Side part", "Undercut", "Short bob", "Shoulder bob", "Long hair", "Ponytail", "Hair bun", "Braid"]
const HAIR = ["594338", "a57149", "3d363c", "6c4e42", "7a4546", "c1a073", "443f58", "a95f47", "4b5556", "b09a76"]
const SKIN = ["f2cfad", "b77e60", "e5b591", "d29b77", "f1c3aa", "e7bfa3", "c38c70", "efc7a2", "a97054", "dcae8c"]
static func ellipse(im: Image, cx: int, cy: int, rx: int, ry: int, color: Color) -> void:
 for y in range(maxi(0,cy-ry),mini(32,cy+ry+1)):
  for x in range(maxi(0,cx-rx),mini(32,cx+rx+1)):
   if pow(float(x-cx)/rx,2)+pow(float(y-cy)/ry,2)<=1.0:im.set_pixel(x,y,color)
static func stamp(im: Image, rows: Array, at: Vector2i, p: Dictionary) -> void:
 Art._stamp(im,rows,at,p)
static func draw(style: int, male: bool, direction: String, variant: int = -1, action: String = "idle", index: int = 0, profile: Dictionary = {}) -> Image:
 var k: int=style if variant<0 else variant%10
 var hair:=Color(profile.get("hair",HAIR[k]));var skin:=Color(profile.get("skin",SKIN[k]));var outline:=Color("292b36")
 var p: Dictionary={"o":outline,"h":hair,"s":hair.darkened(.24),"l":hair.lightened(.22),"f":skin,"d":skin.darkened(.2)}
 var im:=Image.create(32,32,false,Image.FORMAT_RGBA8);im.fill(Color.TRANSPARENT)
 var side:=direction in ["left","right"]
 var cx:=18 if side else 16
 # Long silhouettes are drawn behind the torso, never pasted over the face.
 if style in [5,6]:
  ellipse(im,cx,15,9,9 if style==6 else 6,outline)
  ellipse(im,cx,14,8,9 if style==6 else 6,hair.darkened(.1))
  for x in [cx-6,cx-3,cx+4]:im.fill_rect(Rect2i(x,13,1,8 if style==6 else 5),hair.lightened(.1))
 if style==7:
  ellipse(im,cx-8,13,4,7,outline);ellipse(im,cx-8,13,3,6,hair)
  im.fill_rect(Rect2i(cx-9,9,3,2),Color("bd8a62"))
 if style==9:
  var bx:=cx-7 if side else cx+5
  for i in 5:
   ellipse(im,bx+(i%2),15+i*2,2,2,outline)
   ellipse(im,bx+(i%2),15+i*2,1,1,hair.lightened(.12 if i%2 else 0))
  im.fill_rect(Rect2i(bx,24,2,1),Color("b77667"))
 # Reuse the original body proportions without its painted-in ponytail/ribbon.
 var coat:=Color(profile.get("coat","586f75"))
 var clothes: Dictionary={"o":outline,"T":coat,"t":coat.lightened(.18),"D":coat.darkened(.28),"d":coat.darkened(.1),"c":Color("d6c6a5"),"b":Color("92765c"),"B":Color("18293a"),"k":Color("5b6c7c"),"F":skin,"s":skin.darkened(.2)}
 var walking: bool=action in ["walk","carry_walk"]
 var step: int=[0,1,0,-1][index%4] if walking else 0
 Art._draw_boots(im,step,clothes)
 stamp(im,["..oo.cc.oo..",".oTTTccTTTo.","oTTtTTTTtTTo","oTTtTTTTtTTo",".oTTbbbbTTo.","..oDDDDDDoo.",".oDDdDDDdDo.","..oDDDDDDDo."],Vector2i(10,18),clothes)
 stamp(im,["oTo","oTo",".sF","..o"],Vector2i(10,20),clothes)
 stamp(im,["oTo","oTo","Fs.","o.."],Vector2i(20,20),clothes)
 if direction=="back":
  im.fill_rect(Rect2i(14,18,4,5),coat)
  if style in [5,6]:
   var length: int=23 if style==6 else 20
   for y in range(15,length):
    var half: int=6 if y<length-2 else 5
    im.fill_rect(Rect2i(cx-half,y,half*2+1,1),outline)
    im.fill_rect(Rect2i(cx-half+1,y,half*2-1,1),hair)
    for xx in [cx-3,cx+2]:im.set_pixel(xx,y,hair.lightened(.12))
 ellipse(im,cx,10,9,8,outline);ellipse(im,cx,10,8,7,hair)
 if direction!="back":
  ellipse(im,cx+1 if side else cx,12,6,6,skin.darkened(.2))
  ellipse(im,cx+1 if side else cx,12,5,5,skin)
  if male:
   im.fill_rect(Rect2i(cx-3,15,8 if side else 7,2),skin)
  var eye_xs: Array=[cx+2] if side else [cx-3,cx+3]
  for ex: int in eye_xs:
   im.fill_rect(Rect2i(ex-1,12,3,1),outline)
   im.set_pixel(ex,13,Color("6b9090"));im.set_pixel(ex+1,13,outline)
   im.set_pixel(ex-1,13,Color("fff0d3"))
   im.set_pixel(ex,14,outline)
   if not male:im.set_pixel(ex-1,14,Color("6b9090"))
   if male:im.fill_rect(Rect2i(ex-1,10,3,1),hair.darkened(.35))
   else:im.set_pixel(ex-2,12,outline)
  im.set_pixel(cx+3 if side else cx,16,Color("b77c78"))
  if not male:
   im.set_pixel(cx-4,15,skin.lerp(Color("d67d7e"),.38))
   if not side:im.set_pixel(cx+4,15,skin.lerp(Color("d67d7e"),.38))
 else:
  ellipse(im,cx,11,7,6,hair)
  for x in [cx-4,cx,cx+4]:im.fill_rect(Rect2i(x,9,1,7),hair.darkened(.12))
 # Ten authored crowns/fringes retain their silhouette in every direction.
 match style:
  0:
   stamp(im,["...oosssooo...","..oshhhhhhhso.",".oshlllhhhhhs.",".ohhhhhhhhhhso","..ssshhsshhss."],Vector2i(cx-7,3),p)
   if direction!="back":stamp(im,["hhhhhhhhhhh","ss.hh.ss.hh"],Vector2i(cx-5,7),p)
  1:
   stamp(im,["....o...o......","..oohoolhoo....",".oshllhhhhhsoo.","oshhhhhhhhlhhso",".shhshhshhhhs.","..s..ss..ss..."],Vector2i(cx-8,1),p)
  2:
   stamp(im,["...oosssssoo..",".ooshllllhhso.","oshllllhhhhhs.","shhhhsshhhhhhs","hhhss..shhhhhs","ss......shhhs."],Vector2i(cx-7,3),p)
  3:
   im.fill_rect(Rect2i(cx-7,8,3,5),hair.darkened(.42))
   stamp(im,["....oossoo....","..ooshllhsoo..",".oshllllhhhso.",".shhhhhhhhhs..","..sssssssss..."],Vector2i(cx-7,2),p)
  4:
   for xx in [cx-7,cx+6]:im.fill_rect(Rect2i(xx,8,2,9),hair.darkened(.18))
   stamp(im,["..oosssssssoo..",".oshlllllhhhso.","oshhhhhhhhhhhs.","shhhhhhhhhhhhs.","ssshhsshhsssss."],Vector2i(cx-7,3),p)
  5:
   stamp(im,["..oossssssoo..",".oshllllhhhso.","oshhhhhhhhhhs.","shhhsshhhhhhs.","hhss..sshhhhs.","ss......shhhs."],Vector2i(cx-7,3),p)
  6:
   stamp(im,["...oossssoo...","..oshlllhhso..",".oshllhhhhhs..","oshhhsshhhhhs.","shhss..sshhhs.","sss......shhs."],Vector2i(cx-7,2),p)
  7:
   stamp(im,["..oossssssso..",".oshllllhhhso.","oshhhhhhhhhhs.","shhhsssshhhhhs","ss......sshhhs"],Vector2i(cx-7,3),p)
  8:
   ellipse(im,cx-3,3,4,3,outline);ellipse(im,cx-3,3,3,2,hair.lightened(.12))
   stamp(im,["..oosssssssoo..",".oshlllllhhhso.","oshhhhhhhhhhs..","shhhhhhhhhhhhs.","sshhsshhsshhss."],Vector2i(cx-7,5),p)
  9:
   stamp(im,["..oosssssssoo..",".oshlllllhhhso.","oshhhhhhhhhhhso","shhhhssshhhhhs.","shhss...sshhhs.","ss........shss"],Vector2i(cx-7,3),p)
 if action=="work":
  var shift: int=[0,-1,0,1][index%4]
  im.fill_rect(Rect2i(21,21+shift,2,2),skin)
 var bob: int=-1 if index%2 else 0
 if bob!=0:
  var head: Image=im.get_region(Rect2i(0,0,32,18))
  im.fill_rect(Rect2i(0,0,32,18),Color.TRANSPARENT)
  im.blit_rect(head,Rect2i(0,0,32,18),Vector2i(0,bob))
 if direction=="left":im.flip_x()
 im.resize(128,128,Image.INTERPOLATE_NEAREST)
 return im
