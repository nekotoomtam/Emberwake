extends RefCounted
const Appearance=preload("res://scripts/opening/npc_appearance.gd")
const Directions=preload("res://scripts/hero_directions.gd")
const Art=preload("res://scripts/pixel_art.gd")
static var cache: Dictionary={}
static func frame(profile: Dictionary,direction: String,action: String,index: int) -> Texture2D:
 var key: String=profile.id+":"+str(profile.hash())+":"+direction+":"+action+":"+str(index)
 if cache.has(key):return cache[key]
 var walking:=action in ["walk","carry_walk"]
 var image: Image
 if profile.has("hairstyle"):
  image=Appearance.draw(int(profile.hairstyle),bool(profile.male),direction,-1,action,index,profile)
  image.resize(32,32,Image.INTERPOLATE_NEAREST)
 else:image=Directions.draw(direction,"walk" if walking else "idle",index%4 if walking else index%2)
 var hair: Color=Color(profile.get("hair","705246"));var coat: Color=Color(profile.get("coat","537580"));var skin: Color=Color(profile.get("skin","ffddbc"))
 var colors: Dictionary={"a44260":hair.darkened(.25),"c55372":hair,"ed7b8d":hair.lightened(.18),"ffb0a8":hair.lightened(.36),"2f5869":coat.darkened(.13),"50888c":coat.lightened(.2),"24394c":coat.darkened(.38),"385568":coat.darkened(.18),"ffddbc":skin,"e7a183":skin.darkened(.19),"419f9e":Color(profile.get("eyes","617f77"))}
 for y in 32:
  for x in 32:
   var c:=image.get_pixel(x,y)
   if c.a>.5 and colors.has(c.to_html(false)):image.set_pixel(x,y,colors[c.to_html(false)])
 var center: int=13 if direction=="left" else 19 if direction=="right" else 16
 var bob: int=-1 if index%2 else 0
 var outline:=Color("29343d");var hat:=Color(profile.get("hat","c6b18b"))
 if profile.get("cap",true):
  image.fill_rect(Rect2i(center-8,3+bob,16,4),hat.darkened(.3));image.fill_rect(Rect2i(center-7,2+bob,14,4),hat)
  image.fill_rect(Rect2i(center-9,6+bob,18,2),outline);image.fill_rect(Rect2i(center-7,6+bob,14,1),hat.lightened(.2))
 if profile.get("apron",false) and direction!="back":
  image.fill_rect(Rect2i(14,21,7,6),Color("d9cfb3"));image.fill_rect(Rect2i(17,21,1,6),Color("b1a58c"))
 if profile.get("beard",false) and direction!="back":
  image.fill_rect(Rect2i(center-3,16+bob,7,2),hair.lightened(.15));image.set_pixel(center,18+bob,hair)
 if action=="work":
  var shift: int=[0,-1,0,1][index%4]
  image.fill_rect(Rect2i(center+4,22+shift,3,2),skin)
 if action=="carry_walk" and profile.get("native_cargo",false):
  # Empty supporting hands; the crate is a shaded native mesh.
  for x in [center-5,center+4]:
   image.fill_rect(Rect2i(x,21,3,3),coat.darkened(.13))
   image.fill_rect(Rect2i(x,23,3,2),skin)
 elif action=="carry_walk":
  var p: Dictionary={"o":outline,"w":Color("ad855f"),"s":Color("75543e"),"h":Color("d2ae7c"),"F":skin}
  Art._stamp(image,[".ooooooooooo.","oFwwhwwhwwFo","ossswsswssso","owwwhwwhwwwo","ossswsswssso",".ooooooooooo."],Vector2i(10,20),p)
 if profile.get("broom",false):
  for y in range(19,30):image.set_pixel(25+(y-19)/5,y,Color("987654"))
  image.fill_rect(Rect2i(25,28,5,3),Color("bcaa7a"))
 image.resize(128,128,Image.INTERPOLATE_NEAREST);var texture:=ImageTexture.create_from_image(image);cache[key]=texture;return texture
