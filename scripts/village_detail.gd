extends Node3D
## Original native pixel materials and static geometry merged per material.
var groups: Dictionary={}
var count:=0
func box(at: Vector3,size: Vector3,material: Material,rotation_: Vector3=Vector3.ZERO) -> void:
 var key:=material.get_instance_id()
 if not groups.has(key):groups[key]={"material":material,"tool":SurfaceTool.new()};groups[key].tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var tool: SurfaceTool=groups[key].tool
 var basis:=Basis.from_euler(rotation_);var h:=size*.5
 var faces: Array=[
  [Vector3.RIGHT,Vector3(h.x,-h.y,h.z),Vector3(h.x,-h.y,-h.z),Vector3(h.x,h.y,-h.z),Vector3(h.x,h.y,h.z)],
  [Vector3.LEFT,Vector3(-h.x,-h.y,-h.z),Vector3(-h.x,-h.y,h.z),Vector3(-h.x,h.y,h.z),Vector3(-h.x,h.y,-h.z)],
  [Vector3.UP,Vector3(-h.x,h.y,h.z),Vector3(h.x,h.y,h.z),Vector3(h.x,h.y,-h.z),Vector3(-h.x,h.y,-h.z)],
  [Vector3.DOWN,Vector3(-h.x,-h.y,-h.z),Vector3(h.x,-h.y,-h.z),Vector3(h.x,-h.y,h.z),Vector3(-h.x,-h.y,h.z)],
  [Vector3.BACK,Vector3(-h.x,-h.y,h.z),Vector3(h.x,-h.y,h.z),Vector3(h.x,h.y,h.z),Vector3(-h.x,h.y,h.z)],
  [Vector3.FORWARD,Vector3(h.x,-h.y,-h.z),Vector3(-h.x,-h.y,-h.z),Vector3(-h.x,h.y,-h.z),Vector3(h.x,h.y,-h.z)]]
 var uv: Array=[Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
 for face in faces:
  for index in [0,2,1,0,3,2]:
   tool.set_normal(basis*face[0]);tool.set_uv(uv[index]);tool.add_vertex(at+basis*face[index+1])
 count+=1
func beam(a: Vector3,b: Vector3,width: float,material: Material) -> void:
 var direction: Vector3=(b-a).normalized();var basis:=Basis(Quaternion(Vector3.UP,direction))
 box((a+b)*.5,Vector3(width,a.distance_to(b),width),material,basis.get_euler())
func finish() -> int:
 for group in groups.values():
  var node:=MeshInstance3D.new();node.mesh=group.tool.commit();node.material_override=group.material;add_child(node)
 return groups.size()
func patch(at: Vector3,radius: Vector2,material_: Material,seed_: int) -> void:
 var key:=material_.get_instance_id()
 if not groups.has(key):groups[key]={"material":material_,"tool":SurfaceTool.new()};groups[key].tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var tool: SurfaceTool=groups[key].tool
 var random:=RandomNumberGenerator.new();random.seed=seed_
 var points: Array[Vector3]=[]
 for i in 12:
  var a: float=i*TAU/12;var scale_: float=random.randf_range(.68,1)
  points.append(at+Vector3(cos(a)*radius.x,0,sin(a)*radius.y)*scale_)
 for i in 12:
  for point in [at,points[i],points[(i+1)%12]]:
   tool.set_normal(Vector3.UP);tool.set_uv(Vector2((point.x-at.x)/radius.x,(point.z-at.z)/radius.y)*.5+Vector2.ONE*.5);tool.add_vertex(point)
 count+=1
static func material(base: String,kind: String,seed_: int) -> StandardMaterial3D:
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color.WHITE;mat.roughness=.87;mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 var image:=Image.create(128,128,false,Image.FORMAT_RGB8);var random:=RandomNumberGenerator.new();random.seed=seed_
 var color:=Color(base)
 for y in 128:
  for x in 128:
   var shade:=random.randf_range(-.025,.025)
   match kind:
    "wood":
     shade+=sin(x*.31+sin(y*.075)*1.2)*.026
     if posmod(x+int(sin(y*.025)*3),29)<2:shade-=.06
     if posmod(y+int(x/24)*19,89)<2:shade-=.05
    "brick":
     if y%32<3 or (x+(y/32%2)*32)%64<3:shade-=.09
     if y%32>26:shade-=.025
    "plaster":
     shade+=sin(x*.03)*sin(y*.04)*.04
     if y>85 and sin(x*.09+y*.023)>.35:shade-=.055
     if posmod(x*13+int(y*.35),101)<2:shade-=.04
    "slate":
     shade+=sin((x+y)*.06)*.018
     if x<3 or y<3:shade+=.07
     if x>122 or y>122:shade-=.06
    "sand":shade+=sin(y*.4+sin(x*.065)*2)*.004
    "moss":shade+=sin(x*.2)*cos(y*.16)*.045
   image.set_pixel(x,y,Color(clampf(color.r+shade,0,1),clampf(color.g+shade,0,1),clampf(color.b+shade,0,1)))
 mat.albedo_texture=ImageTexture.create_from_image(image);return mat
