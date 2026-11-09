extends RefCounted
## Six original pixel poses per relative dodge, retaining accepted heads/outfit.
const Directions=preload("res://scripts/hero_directions.gd")
const Art=preload("res://scripts/pixel_art.gd")
static var cache: Dictionary={}
static var heads: Dictionary={}
static func amount(index: int) -> float:return sin(PI*float(index)/5)
static func crouch(kind: String,index: int) -> int:return roundi(amount(index)*(1 if kind=="back" else 2))
static func screen_travel(facing: String,kind: String) -> Vector2:
 var forward: Vector2={"front":Vector2.DOWN,"back":Vector2.UP,"right":Vector2.RIGHT,"left":Vector2.LEFT}[facing]
 var right := Vector2(-forward.y,forward.x)
 return forward if kind=="front" else (-forward if kind=="back" else (right if kind=="right" else -right))
static func frames(facing: String,kind: String) -> SpriteFrames:
 var key:=facing+":"+kind
 if cache.has(key):return cache[key]
 var result: SpriteFrames=Directions.frames(facing,true).duplicate()
 result.add_animation("dodge");result.set_animation_loop("dodge",false);result.set_animation_speed("dodge",25)
 for index in range(6):
  var image:=draw(facing,kind,index)
  image.resize(128,128,Image.INTERPOLATE_NEAREST)
  result.add_frame("dodge",ImageTexture.create_from_image(image))
 cache[key]=result;return result
static func draw(facing: String,kind: String,index: int) -> Image:
 var source: Image=Directions.frames(facing,true).get_frame_texture("idle",0).get_image().duplicate()
 source.resize(32,32,Image.INTERPOLATE_NEAREST)
 if index in [0,5]:return source
 var image:=Image.create(32,32,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 var dip:=crouch(kind,index)
 var power:=amount(index)
 var travel:=screen_travel(facing,kind)
 var across:=roundi(travel.x*power*5)
 var lift:=roundi(power*(2 if kind=="back" else 1))
 # Legs first; torso/head remain on top. Pixel knees and feet articulate,
 # rather than rotating the entire unchanged standing sprite.
 var hip_a:=Vector2i(14,24+dip);var hip_b:=Vector2i(19,24+dip)
 var knee_a:=Vector2i(14+across,26+dip-lift)
 var knee_b:=Vector2i(19-across/2,25+dip-lift)
 var foot_a:=Vector2i(12+across,27+(1 if travel.y>0 else -1)*roundi(power))
 var foot_b:=Vector2i(18-across,27-roundi(power*(2 if kind=="back" else 1)))
 if kind=="back":
  knee_a.x-=roundi(power*2);knee_b.x+=roundi(power*2)
 if kind in ["left","right"]:
  foot_a.y=26 if kind=="left" else 28
  foot_b.y=28 if kind=="left" else 26
  knee_a.y=25+dip if kind=="left" else 27+dip
  knee_b.y=27+dip if kind=="left" else 25+dip
 for pair in [[hip_a,knee_a],[knee_a,foot_a+Vector2i(1,0)],[hip_b,knee_b],[knee_b,foot_b+Vector2i(1,0)]]:
  line(image,pair[0],pair[1],4,Color("18293a"));line(image,pair[0],pair[1],2,Color("385568"))
 var palette:={"o":Color("18293a"),"B":Color("24394c"),"k":Color("5b6c7c")}
 for foot in [foot_a,foot_b]:Art._stamp(image,["oBBo","oBkB","oBBk"],foot,palette)
 image.blit_rect_mask(source,source,Rect2i(0,0,32,24),Vector2i(0,dip))
 return image
static func line(image: Image,a: Vector2i,b: Vector2i,width: int,color: Color) -> void:
 var count:=maxi(absi(b.x-a.x),absi(b.y-a.y))
 for i in range(count+1):
  var point:=Vector2i(Vector2(a).lerp(Vector2(b),float(i)/maxi(1,count)).round())
  var rect:=Rect2i(point-Vector2i(width/2,0),Vector2i(width,2)).intersection(Rect2i(0,0,32,32))
  if rect.has_area():image.fill_rect(rect,color)
static func head(facing: String,kind: String,index: int) -> Texture2D:
 var key:=facing+kind+str(index)
 if heads.has(key):return heads[key]
 var source:=frames(facing,kind).get_frame_texture("dodge",index).get_image()
 var image:=Image.create(128,128,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 image.blit_rect(source,Rect2i(0,0,128,72+crouch(kind,index)*4),Vector2i.ZERO)
 var texture:=ImageTexture.create_from_image(image);heads[key]=texture;return texture
static func shoulders(facing: String,kind: String,index: int) -> Array[Vector2]:
 var points:=Directions.shoulder_pixels(facing,"idle",0)
 for i in range(2):points[i].y+=crouch(kind,index)*4
 return points
