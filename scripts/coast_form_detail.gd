extends "res://scripts/village_detail.gd"
## Native irregular boulders and tapered, bent tree/root geometry.
func _triangle(a: Vector3,b: Vector3,c: Vector3,normal_: Vector3,material_: Material) -> void:
 var key:=material_.get_instance_id()
 if not groups.has(key):groups[key]={"material":material_,"tool":SurfaceTool.new()};groups[key].tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var tool: SurfaceTool=groups[key].tool
 var points: Array=[a,b,c] if (b-a).cross(c-a).dot(normal_)<0 else [a,c,b]
 for point in points:
  tool.set_normal(normal_);tool.set_uv(Vector2(point.x,point.y+point.z)*.35);tool.add_vertex(point)
func boulder(at: Vector3,size: Vector3,material_: Material,seed_: int,solid: bool=false) -> void:
 var random:=RandomNumberGenerator.new();random.seed=seed_
 var rings: Array=[];var hull:=PackedVector3Array()
 for row in 8:
  var latitude: float=-PI*.5+PI*row/7
  var ring: Array[Vector3]=[]
  for col in 11:
   var angle: float=TAU*col/10
   var wobble: float=1.0+sin(col*3.7+seed_)*.12+sin(row*4.9+seed_)*.07
   var p:=at+Vector3(cos(angle)*cos(latitude)*size.x*.5*wobble,sin(latitude)*size.y*.5,sin(angle)*cos(latitude)*size.z*.5*wobble)
   ring.append(p);hull.append(p)
  rings.append(ring)
 for row in 7:
  for col in 10:
   var a: Vector3=rings[row][col];var b: Vector3=rings[row+1][col];var c: Vector3=rings[row+1][col+1];var d: Vector3=rings[row][col+1]
   var normal_: Vector3=((a+b+c)/3-at).normalized()
   _triangle(a,b,c,normal_,material_);_triangle(a,c,d,((a+c+d)/3-at).normalized(),material_)
 if solid:
  var body:=StaticBody3D.new();body.collision_layer=1;var col:=CollisionShape3D.new();var shape:=ConvexPolygonShape3D.new();shape.points=hull;col.shape=shape;body.add_child(col);add_child(body)
 count+=1
func tube(points: Array[Vector3],radius: float,material_: Material,taper: float=.25) -> void:
 for i in range(points.size()-1):
  var direction: Vector3=(points[i+1]-points[i]).normalized();var right:=direction.cross(Vector3.FORWARD).normalized()
  if right.length_squared()<.01:right=Vector3.RIGHT
  var side:=direction.cross(right).normalized()
  var ra: float=radius*lerpf(1,taper,float(i)/maxi(1,points.size()-1));var rb: float=radius*lerpf(1,taper,float(i+1)/maxi(1,points.size()-1))
  for j in 7:
   var a: float=TAU*j/7;var b: float=TAU*(j+1)/7
   var na: Vector3=right*cos(a)+side*sin(a);var nb: Vector3=right*cos(b)+side*sin(b)
   var p: Vector3=points[i]+na*ra;var q: Vector3=points[i+1]+na*rb;var u: Vector3=points[i+1]+nb*rb;var v: Vector3=points[i]+nb*ra
   _triangle(p,q,u,(na+nb).normalized(),material_);_triangle(p,u,v,(na+nb).normalized(),material_)
 count+=1
func tree(at: Vector3,height: float,seed_: int,bark: Material,leaves: Material,solid: bool=true, canopy: Callable=Callable()) -> void:
 var random:=RandomNumberGenerator.new();random.seed=seed_
 var lean:=Vector3(random.randf_range(-.8,.8),0,random.randf_range(-.4,.3))
 var trunk: Array[Vector3]=[]
 for i in 6:
  var t: float=i/5.0;trunk.append(at+Vector3(0,height*t,0)+lean*t*t+Vector3(sin(t*4)*.12,0,0))
 tube(trunk,.26,bark,.22)
 for i in 7:
  var angle: float=i*TAU/7+random.randf_range(-.2,.2);var direction:=Vector3(cos(angle),0,sin(angle))
  var branch: Vector3=at+Vector3(0,height*(.42+i*.055),0)+lean*.4
  tube([branch,branch+direction*.8+Vector3.UP*.45,branch+direction*1.5+Vector3.UP*.65],.1,bark,.15)
  var root_end:=at+direction*random.randf_range(.8,1.6)
  tube([at+Vector3.UP*.3,at+direction*.5+Vector3.UP*.12,root_end+Vector3.UP*.025],.16,bark,.15)
 for i in 6:
  var angle: float=i*TAU/6
  var center: Vector3=at+lean+Vector3(cos(angle)*.65,height*(.77+random.randf_range(-.08,.12)),sin(angle)*.6)
  var size:=Vector3(2.6,1.4,2.1)*random.randf_range(.85,1.15)
  if canopy.is_valid():canopy.call(center,size,seed_+i)
  else:boulder(center,size,leaves,seed_+i)
 if canopy.is_valid():canopy.call(at+lean+Vector3.UP*height*.94,Vector3(2.65,1.74,2.2),seed_+61)
 if solid:
  var body:=StaticBody3D.new();body.position=at+Vector3.UP*1.2;body.collision_layer=1;var col:=CollisionShape3D.new();var shape:=CapsuleShape3D.new();shape.radius=.30;shape.height=2.4;col.shape=shape;body.add_child(col);add_child(body)
