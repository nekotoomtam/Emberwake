extends Sprite3D
## Cosmetic, camera-facing metal impact. Fixed pixel paths never touch gameplay RNG.
const LIFETIME:=.30
static var textures: Dictionary={}
var age:=.0
var perfect:=true
func _ready() -> void:
 pixel_size=.021 if perfect else .012;billboard=BaseMaterial3D.BILLBOARD_ENABLED
 texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;shaded=false
 no_depth_test=true;render_priority=9;cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 texture=frame(0,perfect)
func tick(delta: float) -> bool:
 if not is_finite(delta) or delta<=0:return age<LIFETIME
 age=minf(LIFETIME,age+delta)
 texture=frame(mini(17,int(age*60)),perfect)
 modulate.a=clampf((LIFETIME-age)/.08,0,1)
 return age<LIFETIME
static func dot(image: Image,point: Vector2,width: int,color: Color) -> void:
 var rect:=Rect2i(Vector2i(point.round())-Vector2i(width/2,width/2),Vector2i(width,width)).intersection(Rect2i(0,0,128,128))
 if rect.has_area():image.fill_rect(rect,color)
static func line(image: Image,a: Vector2,b: Vector2,width: int,color: Color) -> void:
 var count:=maxi(1,ceili(a.distance_to(b)))
 for i in range(count+1):dot(image,a.lerp(b,float(i)/count),width,color)
static func frame(index: int,heavy: bool=true) -> Texture2D:
 index=clampi(index,0,17)
 var key:=index+(0 if heavy else 18)
 if textures.has(key):return textures[key]
 var image:=Image.create(128,128,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 var t:=float(index)/60
 var center:=Vector2(64,64)
 # Broad white impact mass with an irregular radial edge: a heavy clash flash.
 # It blooms immediately, remains white for three frames, then collapses fast.
 if t<.10:
  var bloom:=1.0 if t<.034 else clampf((.10-t)/.066,0,1)
  var radius:=20.0*bloom
  for y in range(128):
   for x in range(128):
    var offset:=Vector2(x,y)-center
    var theta:=offset.angle()
    var edge:=radius*(1.0+.13*cos(theta*7)+.08*sin(theta*11))
    var distance:=offset.length()
    if distance<edge+7*bloom:
     var alpha:=clampf((edge+7*bloom-distance)/maxf(1,7*bloom),0,1)*.50
     image.set_pixel(x,y,Color(1,.94,.76,alpha))
    if distance<=edge:image.set_pixel(x,y,Color(1,1,1,1))
  for i in range(10):
   var theta:=TAU*i/10+.16
   var ray:=Vector2(cos(theta),sin(theta))*(49 if i%2==0 else 36)*bloom
   line(image,center,center+ray,maxi(1,roundi(5*bloom)),Color("#fff8df"))
   line(image,center,center+ray,maxi(1,roundi(2*bloom)),Color.WHITE)
 for i in range(24 if heavy else 10):
  var theta:=i*2.399963+.21
  var outward:=Vector2(cos(theta),sin(theta))
  var speed: float=82+13*(i%4)
  var tip:=center+outward*(3+speed*t)+Vector2(0,90*t*t)
  var tail:=tip-outward*(3+6*(1-t/LIFETIME))
  line(image,tail,tip,2,Color("#b77832"))
  line(image,tail.lerp(tip,.3),tip,1,Color("#ffd16a"))
  dot(image,tip,2,Color("#fff6c1") if t<.14 else Color("#eab558"))
  # Expanding screen-facing shock ring belongs to the impact, never the weapon.
 if heavy and t>.016 and t<.22:
  var radius:=25+31*t/.22
  var color:=Color(.8,1,1,clampf(1-t/.22,0,1))
  for i in range(72):
   var a:=TAU*i/72
   var b:=TAU*(i+1)/72
   line(image,center+Vector2(cos(a),sin(a))*radius,center+Vector2(cos(b),sin(b))*radius,2,color)
 if not heavy:
  for y in range(128):
   for x in range(128):
    var color:=image.get_pixel(x,y)
    if color.a>0:image.set_pixel(x,y,Color(.65+.35*color.r,.9+.1*color.g,1,color.a*.8))
 var result:=ImageTexture.create_from_image(image);textures[key]=result;return result
