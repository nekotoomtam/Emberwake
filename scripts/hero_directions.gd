extends RefCounted
## Original four-direction body art. Shared combat/weapon art is untouched.
const Art = preload("res://scripts/pixel_art.gd")
const DIRECTIONS := ["front","back","left","right"]
static var cache: Dictionary={}
static var head_cache: Dictionary={}
static var paired_cache: Dictionary={}
static func choose(aim: Vector3,camera: Camera3D,current: String) -> String:
 if aim.length_squared()<.001:return current
 var x: float=camera.global_basis.x.dot(aim)
 var toward := Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()
 var y: float=toward.dot(aim)
 if current in ["left","right"] and x*(-1 if current=="left" else 1)>=0 and absf(x)*1.12>=absf(y):return current
 if current in ["front","back"] and y*(-1 if current=="back" else 1)>=0 and absf(y)*1.12>=absf(x):return current
 if absf(x)>absf(y):return "right" if x>0 else "left"
 return "front" if y>0 else "back"
static func frames(direction: String,paired: bool=false) -> SpriteFrames:
 if paired:return paired_frames(direction)
 if direction=="right" or direction not in DIRECTIONS:return Art.frames("player")
 if cache.has(direction):return cache[direction]
 var result := SpriteFrames.new();result.remove_animation("default")
 var counts := {"idle":2,"walk":4,"attack":3,"hit":1,"death":3}
 var rates := {"idle":2.4,"walk":8.0,"attack":13.0,"hit":8.0,"death":6.0}
 for animation: String in counts:
  result.add_animation(animation);result.set_animation_loop(animation,animation in ["idle","walk"]);result.set_animation_speed(animation,rates[animation])
  for index in range(counts[animation]):
   var image := draw(direction,animation,index)
   image.resize(128,128,Image.INTERPOLATE_NEAREST)
   result.add_frame(animation,ImageTexture.create_from_image(image))
 cache[direction]=result
 return result
static func draw(direction: String,animation: String,index: int) -> Image:
 if direction in ["left","right"]:
  var quarter: Image=Art._actor_image("player",animation,index)
  if direction=="left":quarter.flip_x()
  return quarter
 var image := Image.create(32,32,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 var bob := -index if animation=="idle" else (-1 if animation=="walk" and index%2==1 else 0)
 var step: int=[0,1,0,-1][index] if animation=="walk" else 0
 var lean: int=[0,2,1][index] if animation=="attack" else (-1 if animation=="hit" else 0)
 if animation=="death":bob=index*2;lean=index+1
 var p := {"o":Color("262333"),"M":Color("a44260"),"H":Color("c55372"),"h":Color("ed7b8d"),"L":Color("ffb0a8"),"F":Color("ffddbc"),"s":Color("e7a183"),"T":Color("2f5869"),"t":Color("50888c"),"D":Color("24394c"),"d":Color("385568"),"c":Color("e8d9bc"),"b":Color("b38c5d"),"B":Color("18293a"),"k":Color("5b6c7c")}
 Art._draw_boots(image,step,p)
 if direction=="back":
  Art._stamp(image,["..oo....oo..",".oTTttttTTo.","oTTTtTTtTTTo","oTTTtTTtTTTo",".oTTbbbbTTo.","..oDDdDDDo..",".oDDddDDdDo.","..oDDDDDDo.."],Vector2i(10,18),p)
  Art._stamp(image,["......oooooo......","....ooMMMMMMoo....","...oMMhhhhhhMMo...","..oMhhLLLLLLhhMMo.",".oMhhLLLhhhhhhhMMo","oMhhhhhhhhhhhhhhMo","oMhhhHhhhhhhHhhhMo","oMhhHHHhhhhHHHhhMo","oMhHHMMhhhhMMHHhMo","oMHHMMMhhhhMMMHHMo","oMMMMMMhhhhMMMMMMo",".oMMMMMhhhhMMMMMo.","..oMMMMHhhHMMMMo..","...oMMMMHHMMMMo...","....ooMMMMMMoo....","......oooooo......"],Vector2i(7,2+bob),p)
  Art._stamp(image,[".oTo.","oTTTo",".obo.",".oMo.","oMhMo","oMhMo","oMHMo",".oMo.","..o.."],Vector2i(14+step,16+bob),p)
 else:
  image.fill_rect(Rect2i(0,25,32,7),Color.TRANSPARENT)
  var left_y := 25-(1 if step>0 else 0)
  var right_y := 25-(1 if step<0 else 0)
  Art._stamp(image,["oBBo.","oBkBo","oBBBo"],Vector2i(11-step,left_y),p)
  Art._stamp(image,["oBBo.","oBkBo","oBBBo"],Vector2i(17+step,right_y),p)
  Art._stamp(image,["...oMMo..","..oMhhMo.",".oMhhHMo.","oMhhHMMo.","oMhHMMo..",".oHMMMo..",".oMMMo...","..ooo...."],Vector2i(6+lean,14+bob),p)
  Art._stamp(image,["..oo.cc.oo..",".oTTTccTTTo.","oTTtTTTTtTTo","oTTtTTTTtTTo",".oTTbbbbTTo.","..oDDDDDDoo.",".oDDdDDDdDo.","..oDDDDDDDo."],Vector2i(10+lean/2,18),p)
  Art._stamp(image,["oTo","oTo",".sF","..o"],Vector2i(10+lean/2,20),p)
  Art._stamp(image,["......oooooo......","....ooMMMMMMoo....","...oMMhhhhhhMMo...","..oMhhLLLLLLhhMMo.",".oMhhLLLhhhhhhhMMo","oMhhhhhhhhhhhhhhMo","oMhhhHhhhhhhHhhhMo","oMhhHHHhhhhHHHhhMo","oMhHHMMhhhhMMHHhMo","oMHHMMMhhhhMMMHHMo","oMMMMMMhhhhMMMMMMo",".oMMMMMhhhhMMMMMo.","..oMMMMHhhHMMMMo..","...oMMMMHHMMMMo...","....ooMMMMMMoo....","......oooooo......"],Vector2i(7+lean,2+bob),p)
  Art._stamp(image,["...ssssss...","..sFFFFFFs..",".sFFFFFFFFs.","sFFFFFFFFFFs","sFFFFFFFFFFs","sFFFFFFFFFFs",".sFFFFFFFFs.","..sFFFFFFs..","...ssssss..."],Vector2i(10+lean,9+bob),p)
  Art._stamp(image,["hhhLLLLLhhhh","hhhhLLLhhhhh","hhhhhhhhhhhh","hhhHHhhHHhhh","hhHH.h.hHHhh","hHH......HHh","HH........HH","H..........H"],Vector2i(10+lean,5+bob),p)
  for pixel in [Vector2i(12,12),Vector2i(13,12),Vector2i(12,13),Vector2i(13,14),Vector2i(19,12),Vector2i(18,12),Vector2i(19,13),Vector2i(18,14)]:Art._pixel(image,pixel+Vector2i(lean,bob),Color("25313e"))
  for pixel in [Vector2i(13,13),Vector2i(18,13)]:Art._pixel(image,pixel+Vector2i(lean,bob),Color("419f9e"))
  for pixel in [Vector2i(12,12),Vector2i(19,12)]:Art._pixel(image,pixel+Vector2i(lean,bob),Color("fff3df"))
  for pixel in [Vector2i(11,15),Vector2i(20,15)]:Art._pixel(image,pixel+Vector2i(lean,bob),Color("f4a49a"))
  for pixel in [Vector2i(15,16),Vector2i(16,16)]:Art._pixel(image,pixel+Vector2i(lean,bob),Color("bb6d72"))
  Art._stamp(image,["oT.o","oTTo",".bo.","oTTo","oT.o"],Vector2i(7+lean,10+bob),p)
 if animation=="hit":Art._flash(image)
 if animation=="death" and index==2:image=Art._fallen(image)
 if direction=="left":image.flip_x()
 return image

static func back_head(animation: String,index: int) -> Texture2D:
 var key := animation+":"+str(index)
 if head_cache.has(key):return head_cache[key]
 var source: Image=frames("back").get_frame_texture(animation,index).get_image()
 var image := Image.create(128,128,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 image.blit_rect(source,Rect2i(0,0,128,72),Vector2i.ZERO)
 var texture := ImageTexture.create_from_image(image);head_cache[key]=texture
 return texture

static func paired_frames(direction: String) -> SpriteFrames:
 if paired_cache.has(direction):return paired_cache[direction]
 var source := frames(direction)
 var result := SpriteFrames.new();result.remove_animation("default")
 for animation in source.get_animation_names():
  result.add_animation(animation);result.set_animation_loop(animation,source.get_animation_loop(animation));result.set_animation_speed(animation,source.get_animation_speed(animation))
  for index in range(source.get_frame_count(animation)):
   var image: Image=source.get_frame_texture(animation,index).get_image()
   if direction!="back" and animation!="death":
    image=image.duplicate();image.resize(32,32,Image.INTERPOLATE_NEAREST)
    if direction=="left":image.flip_x()
    var lean: int=[0,2,1][index] if animation=="attack" else (-1 if animation=="hit" else 0)
    var patch := Image.create(32,32,false,Image.FORMAT_RGBA8);patch.fill(Color.TRANSPARENT)
    Art._stamp(patch,["oTTtTTTTtTTo","oTTtTTTTtTTo",".oTTbbbbTTo.","..oDDDDDDoo."],Vector2i(10+lean/2,20),{"o":Color("262333"),"T":Color("2f5869"),"t":Color("50888c"),"b":Color("b38c5d"),"D":Color("24394c")})
    if animation=="hit":Art._flash(patch)
    var start := Vector2i(10+lean/2,20)
    image.blit_rect(patch,Rect2i(start,Vector2i(3,4)),start)
    if direction=="left":image.flip_x()
    image.resize(128,128,Image.INTERPOLATE_NEAREST)
   result.add_frame(animation,ImageTexture.create_from_image(image))
 paired_cache[direction]=result
 return result
static func shoulder_pixels(direction: String,animation: String,index: int) -> Array[Vector2]:
 var offset := .0
 if animation=="attack" and direction!="back":offset=float([0,1,0][mini(index,2)])*(-1 if direction=="left" else 1)
 var main_x := 12.0 if direction=="front" else 20.0
 var off_x := 20.0 if direction=="front" else 12.0
 return [Vector2((main_x+offset)*4,19.5*4),Vector2((off_x+offset)*4,19.5*4)]
