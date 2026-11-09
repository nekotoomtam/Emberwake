extends Node3D
static var cache: Dictionary={}
var home:=Vector3.ZERO
var phase:=0.0
var sprite: Sprite3D
var flight:=0.0
var _last:=Vector3.ZERO
func _ready() -> void:
 sprite=Sprite3D.new();sprite.pixel_size=.018;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;sprite.shaded=false;sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;add_child(sprite);position=home;_last=home
func tick(delta: float,camera: Camera3D,time_: float,people: Array[Vector3]) -> void:
 var t: float=time_+phase;var near_person:=false
 for p in people:
  if Vector2(p.x-position.x,p.z-position.z).length()<.7:near_person=true;break
 var flutter: bool=fposmod(t,13)>10.5 or near_person
 flight=move_toward(flight,.75 if flutter else 0,minf(delta,.05)*1.7)
 position=home+Vector3(sin(t*.38)*(.25+flight*.4),0,cos(t*.29)*.23)
 var left: bool=camera.global_basis.x.dot(position-_last)<0;_last=position
 var pose: int=2+int(t*10)%3 if flight>.15 else 1 if fposmod(t,2.7)<.9 else 0
 sprite.texture=_texture(pose,left);sprite.global_basis=camera.global_basis;sprite.global_position=global_position+Vector3.UP*flight+camera.global_basis.y*.504
static func _texture(pose: int,left: bool) -> Texture2D:
 var key: String=str(pose)+str(left)
 if cache.has(key):return cache[key]
 var image:=Image.create(16,16,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 var dark:=Color("3b4a56");var gray:=Color("8898a2");var light:=Color("c1cbd0");var neck:=Color("5a777d")
 for y in range(8,13):
  for x in range(4,11):
   if pow((x-7.0)/3.8,2)+pow((y-10.0)/2.6,2)<1:image.set_pixel(x,y,gray)
 image.fill_rect(Rect2i(3,9,3,2),dark);image.fill_rect(Rect2i(6,9,4,1),dark);image.fill_rect(Rect2i(6,11,3,1),light)
 var bob: int=2 if pose==1 else 0
 image.fill_rect(Rect2i(9,6+bob,3,4-bob),neck);image.fill_rect(Rect2i(9,5+bob,4,3),gray);image.set_pixel(11,6+bob,Color("242e36"));image.set_pixel(13,7+bob,Color("bac1ba"))
 image.set_pixel(9,9,Color("706b85"));image.set_pixel(10,8,Color("659087"));image.set_pixel(6,10,dark);image.set_pixel(8,11,dark)
 if pose>=2:
  var wing: int=[4,1,3][pose-2]
  for i in 6:
   image.set_pixel(7-i,8-i*wing/5,dark);image.set_pixel(8+i,8-i*wing/5,light)
 else:
  image.set_pixel(6,13,Color("b27a66"));image.set_pixel(9,13,Color("b27a66"));image.set_pixel(5,14,Color("b27a66"));image.set_pixel(8,14,Color("b27a66"))
 if left:image.flip_x()
 image.resize(64,64,Image.INTERPOLATE_NEAREST);var texture:=ImageTexture.create_from_image(image);cache[key]=texture;return texture
