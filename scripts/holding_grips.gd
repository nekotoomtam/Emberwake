extends Sprite3D
## Small original pixel sleeves link shoulders to rigid weapon grips.
const UNIT := .072
var signature := ""
var support_visible := false
var grip_count := 0
var shoulder_world := Vector3.ZERO
var wrist_world := Vector3.ZERO
func _ready() -> void:
 pixel_size=.018;texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 shaded=false;no_depth_test=true;render_priority=2
func update_grips(camera: Camera3D,origin: Vector3,primary: Vector3,support: Vector3,use_support: bool,paired: bool,left: bool,dead: bool,anchor: Vector3=Vector3.INF,support_anchor: Vector3=Vector3.INF) -> void:
 visible=not dead;support_visible=use_support;grip_count=2 if use_support else 1
 global_transform=Transform3D(camera.global_basis,origin+Vector3.UP*.76)
 var side := -1.0 if left else 1.0
 var shoulder := origin+Vector3.UP*.88+camera.global_basis.x*(.0 if paired else .13*side)
 if anchor.is_finite():shoulder=anchor
 shoulder_world=shoulder;wrist_world=primary
 var shoulder2 := origin+Vector3.UP*.88-camera.global_basis.x*.14*side
 if support_anchor.is_finite():shoulder2=support_anchor
 var points: Array[Vector2i]=[_point(camera,shoulder),_point(camera,primary)]
 if use_support:points.append(_point(camera,shoulder2));points.append(_point(camera,support))
 var key := str(paired)+str(points)
 if key==signature:return
 signature=key
 var image := Image.create(48,40,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 for i in range(0,points.size(),2):
  var a: Vector2i=points[i];var b: Vector2i=points[i+1]
  var elbow := Vector2i(roundi(lerpf(a.x,b.x,.45)),maxi(a.y,b.y)+(1 if paired else 2))
  _line(image,a,elbow,(2 if paired else 3),Color("263141"));_line(image,elbow,b,(2 if paired else 3),Color("263141"))
  _line(image,a,elbow,(1 if paired else 2),Color("2f5869"));_line(image,elbow,b,(1 if paired else 2),Color("50888c"))
  _dot(image,b,1 if paired else 2,Color("ffd4ad"))
 image.resize(192,160,Image.INTERPOLATE_NEAREST);texture=ImageTexture.create_from_image(image)
func _point(camera: Camera3D,world: Vector3) -> Vector2i:
 var local := world-global_position
 return Vector2i(roundi(24+camera.global_basis.x.dot(local)/UNIT),roundi(20-camera.global_basis.y.dot(local)/UNIT))
func _dot(image: Image,p: Vector2i,size: int,c: Color) -> void:
 var rect := Rect2i(p-Vector2i(size/2,size/2),Vector2i(size,size)).intersection(Rect2i(0,0,48,40))
 if rect.has_area():image.fill_rect(rect,c)
func _line(image: Image,a: Vector2i,b: Vector2i,size: int,c: Color) -> void:
 var distance := maxi(absi(b.x-a.x),absi(b.y-a.y))
 for i in range(distance+1):_dot(image,Vector2i(Vector2(a).lerp(Vector2(b),float(i)/maxi(1,distance)).round()),size,c)
