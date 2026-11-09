extends RefCounted
## Private finite passenger frames; original complete heads and body pixels stay native.
const Appearance=preload("res://scripts/opening/npc_appearance.gd")
static var cache: Dictionary={}
static func _stamp(image: Image,rows: Array,at: Vector2i,palette: Dictionary) -> void:
 # Paint on the returned 128px image. Never resample or alter shared source art.
 for y in rows.size():
  for x in str(rows[y]).length():
   var code: String=str(rows[y])[x]
   if palette.has(code):image.fill_rect(Rect2i((at+Vector2i(x,y))*4,Vector2i(4,4)),palette[code])
static func frame(profile: Dictionary,direction: String,action: String,pose: int) -> Texture2D:
 var count:=4 if action=="walk" else 3 if action in ["ticket","inspect","hold_tag"] else 2
 var index:=posmod(pose,count)
 var key:=str(profile.get("id","passenger"))+":"+str(profile.hash())+":"+direction+":"+action+":"+str(index)
 if cache.has(key):return cache[key]
 var base_action: String="walk" if action=="walk" else "idle"
 var base_pose: int=index if action in ["walk","idle"] else 0
 var image: Image=Appearance.draw(int(profile.get("hairstyle",2)),bool(profile.get("male",false)),direction,-1,base_action,base_pose,profile)
 if action in ["ticket","inspect","hold_tag"]:
  var coat:=Color(profile.get("coat","657f83"));var skin:=Color(profile.get("skin","e5b591"))
  var palette: Dictionary={"o":Color("292b36"),"T":coat,"t":coat.lightened(.18),"F":skin,"s":skin.darkened(.20),"c":Color("e7d7b3"),"i":Color("597b7b"),"g":Color("bb9661")}
  var overlay:=Image.create(128,128,false,Image.FORMAT_RGBA8);overlay.fill(Color.TRANSPARENT)
  var y: int=[23,20,21][index]
  if action=="inspect":
   # A low bent wrist checks the parked trunk handle; no loose baggage prop.
   _stamp(overlay,["oTo....","oTTo...",".oTTo..","..sFFo.","...oFo."],Vector2i(10,20),palette)
   _stamp(overlay,["...oTo","..oTTo",".oTTo.","oFFs..",".oFo.."],Vector2i(18,20),palette)
  elif direction=="back":
   # The body occludes the ticket; its near edge stays attached to the outside hand.
   _stamp(overlay,["oTo..","oTTo.",".osFF","..oFo"],Vector2i(20,20),palette)
   _stamp(overlay,["oooo","ocgo","oico","oooo"],Vector2i(23,y+1),palette)
   _stamp(overlay,["FF","oF"],Vector2i(22,y+2),palette)
  elif direction in ["left","right"]:
   _stamp(overlay,["oTo...","oTTo..",".oTTo.","..osFF","...oFo"],Vector2i(19,20),palette)
   _stamp(overlay,["ooooo","occgo","ocico","ooooo"],Vector2i(22,y+1),palette)
   _stamp(overlay,["FF","oF"],Vector2i(21,y+2),palette)
   if direction=="left":overlay.flip_x()
  else:
   _stamp(overlay,["oooooooo","occcccco","ociccico","occcccco","oooooooo"],Vector2i(13,y),palette)
   _stamp(overlay,["oTo..","oTTo.",".oTTo","..sFF","..oFo"],Vector2i(10,20),palette)
   _stamp(overlay,["..oTo",".oTTo","oTTo.","FFs..","oFo.."],Vector2i(18,20),palette)
   # Both wrists meet the card edge at each discrete lift.
   _stamp(overlay,["sF","oF"],Vector2i(12,y+1),palette)
   _stamp(overlay,["Fs","Fo"],Vector2i(20,y+1),palette)
  image.blend_rect(overlay,Rect2i(0,0,128,128),Vector2i.ZERO)
 var texture:=ImageTexture.create_from_image(image);cache[key]=texture;return texture
