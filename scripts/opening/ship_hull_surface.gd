extends RefCounted
## Shared closed timber skin. The nominal deck/collision datum remains 2.865 m.
const HALF_LENGTH:=14.2
const HALF_BEAM:=4.4
const DECK_HEIGHT:=2.865
const Spectrum=preload("res://scripts/opening/harbor_wave_spectrum.gd")
const WATERLINE_Y:=Spectrum.MEAN+.55
const STATION_COUNT:=37
const PROFILE_HEIGHTS: Array[float]=[0.0,.12,.25,.39,.53,.67,.80,.91,1.0]
const PROFILE_BREADTHS: Array[float]=[0.0,.38,.62,.79,.89,.96,1.0,1.0,1.0]

static func _station_x(index: int) -> float:
 if index==0:return -HALF_LENGTH
 if index==STATION_COUNT-1:return HALF_LENGTH
 # Closely spaced end stations keep the pointed stems smooth in silhouette.
 return -HALF_LENGTH*cos(PI*float(index)/float(STATION_COUNT-1))

static func _half_width(x: float) -> float:
 if absf(x)>=HALF_LENGTH:return 0.0
 return HALF_BEAM*pow(maxf(0.0,sin((x+HALF_LENGTH)/(HALF_LENGTH*2.0)*PI)),.45)

static func _profile_point(x: float,row: int,side: float=1.0) -> Vector3:
 var keel: float=-1.15+pow(absf(x)/HALF_LENGTH,3.0)*.85
 return Vector3(x,lerpf(keel,DECK_HEIGHT,PROFILE_HEIGHTS[row]),side*_half_width(x)*PROFILE_BREADTHS[row])

static func _vertex(point: Vector3,vertices: Array[Vector3],lookup: Dictionary) -> int:
 var key:=Vector3i(roundi(point.x*1000000.0),roundi(point.y*1000000.0),roundi(point.z*1000000.0))
 if lookup.has(key):return int(lookup[key])
 var index: int=vertices.size();vertices.append(point);lookup[key]=index
 return index

static func _triangle(a: int,b: int,c: int,vertices: Array[Vector3],triangles: Array[int],surfaces: Array[String],surface: String,normals: Array[Vector3],normal_: Vector3) -> void:
 if a==b or b==c or a==c:return
 if (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).length_squared()<.000000000001:return
 triangles.append_array([a,b,c]);surfaces.append(surface);normals.append(normal_)

static func mesh_data() -> Dictionary:
 var vertices: Array[Vector3]=[]
 var triangles: Array[int]=[]
 var surfaces: Array[String]=[]
 var normals: Array[Vector3]=[]
 var lookup: Dictionary={}
 var rings: Array=[]
 # Inlaid caulking bands share the deck plane and vertices with the wood.
 var deck_fractions: Array[float]=[1.0]
 for plank in range(10,-11,-1):
  deck_fractions.append((plank*.42+.006)/HALF_BEAM)
  deck_fractions.append((plank*.42-.006)/HALF_BEAM)
 deck_fractions.append(-1.0)
 var deck_start: int=PROFILE_HEIGHTS.size()-1
 var deck_end: int=deck_start+deck_fractions.size()-1
 var station_positions:=PackedFloat32Array()
 for station in STATION_COUNT:
  var x: float=_station_x(station);station_positions.append(x)
  var ring: Array[int]=[]
  for row in PROFILE_HEIGHTS.size():ring.append(_vertex(_profile_point(x,row),vertices,lookup))
  # Every inlaid seam belongs to the same closed cap, with no overlapping faces.
  for fraction in range(1,deck_fractions.size()):ring.append(_vertex(Vector3(x,DECK_HEIGHT,_half_width(x)*deck_fractions[fraction]),vertices,lookup))
  for row in range(PROFILE_HEIGHTS.size()-2,0,-1):ring.append(_vertex(_profile_point(x,row,-1.0),vertices,lookup))
  rings.append(ring)
 var ring_size: int=rings[0].size()
 for station in STATION_COUNT-1:
  for edge in ring_size:
   var next: int=(edge+1)%ring_size
   var surface: String="shipwood"
   if edge>=deck_start and edge<deck_end:surface="darkwood" if (edge-deck_start)%2==1 else "wood"
   elif edge in [deck_start-2,deck_start-1,deck_end,deck_end+1]:surface="cream"
   var a: int=rings[station][edge];var b: int=rings[station+1][edge]
   var c: int=rings[station+1][next];var d: int=rings[station][next]
   var normal_: Vector3=((vertices[b]-vertices[a]).cross(vertices[c]-vertices[a])+(vertices[c]-vertices[a]).cross(vertices[d]-vertices[a])).normalized()
   # Shared indices weld both sides to the keel and the two end stem profiles.
   # Both triangles use one loft-panel normal, avoiding diagonal lighting seams.
   _triangle(a,b,c,vertices,triangles,surfaces,surface,normals,normal_)
   _triangle(a,c,d,vertices,triangles,surfaces,surface,normals,normal_)
 return {"vertices":PackedVector3Array(vertices),"triangles":PackedInt32Array(triangles),"triangle_materials":PackedStringArray(surfaces),"triangle_normals":PackedVector3Array(normals),"stations":station_positions,"station_count":STATION_COUNT,"profile_row_count":PROFILE_HEIGHTS.size(),"deck_height":DECK_HEIGHT}

static func geometry_report(data: Dictionary={}) -> Dictionary:
 if data.is_empty():data=mesh_data()
 var vertices: PackedVector3Array=data.vertices
 var triangles: PackedInt32Array=data.triangles
 var edges: Dictionary={};var directions: Dictionary={}
 var degenerate:=0;var volume:=0.0
 for i in range(0,triangles.size(),3):
  var a: int=triangles[i];var b: int=triangles[i+1];var c: int=triangles[i+2]
  if (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).length_squared()<.000000000001:degenerate+=1
  volume+=vertices[a].dot(vertices[b].cross(vertices[c]))/6.0
  for edge in [[a,b],[b,c],[c,a]]:
   var key:=Vector2i(mini(edge[0],edge[1]),maxi(edge[0],edge[1]))
   edges[key]=int(edges.get(key,0))+1
   directions[key]=int(directions.get(key,0))+(1 if edge[0]<edge[1] else -1)
 var boundary:=0;var nonmanifold:=0;var mismatched:=0
 for edge in edges:
  if edges[edge]==1:boundary+=1
  if edges[edge]!=2:nonmanifold+=1
  if directions[edge]!=0:mismatched+=1
 return {"vertex_count":vertices.size(),"triangle_count":triangles.size()/3,"edge_count":edges.size(),"boundary_edge_count":boundary,"nonmanifold_edge_count":nonmanifold,"orientation_mismatch_count":mismatched,"degenerate_triangle_count":degenerate,"enclosed_volume":volume,"euler_characteristic":vertices.size()-edges.size()+triangles.size()/3,"station_count":data.station_count,"profile_row_count":data.profile_row_count,"deck_height":DECK_HEIGHT,"half_length":HALF_LENGTH,"half_beam":HALF_BEAM}

static func _triangle_width_at(a: Vector3,b: Vector3,c: Vector3,x: float,y: float) -> float:
 var determinant: float=(b.y-c.y)*(a.x-c.x)+(c.x-b.x)*(a.y-c.y)
 if absf(determinant)<.00000001:return -1.0
 var u: float=((b.y-c.y)*(x-c.x)+(c.x-b.x)*(y-c.y))/determinant
 var v: float=((c.y-a.y)*(x-c.x)+(a.x-c.x)*(y-c.y))/determinant
 var w: float=1.0-u-v
 if minf(u,minf(v,w))<-.000001:return -1.0
 return maxf(0.0,u*a.z+v*b.z+w*c.z)

static func waterline_half_width(x: float,water_y: float=WATERLINE_Y) -> float:
 if absf(x)>=HALF_LENGTH or water_y>DECK_HEIGHT:return 0.0
 var station:=0
 while station<STATION_COUNT-2 and _station_x(station+1)<x:station+=1
 var x0: float=_station_x(station);var x1: float=_station_x(station+1)
 for row in PROFILE_HEIGHTS.size()-1:
  var a: Vector3=_profile_point(x0,row);var b: Vector3=_profile_point(x1,row)
  var c: Vector3=_profile_point(x1,row+1);var d: Vector3=_profile_point(x0,row+1)
  var width: float=_triangle_width_at(a,b,c,x,water_y)
  if width>=0.0:return width
  width=_triangle_width_at(a,c,d,x,water_y)
  if width>=0.0:return width
 return 0.0

static func _skin_seams(builder,materials: Dictionary) -> void:
 # Narrow caulking ribbons sit outside an already closed skin, never open gaps.
 for side in [-1.0,1.0]:
  for row in range(1,PROFILE_HEIGHTS.size()-1):
   for station in range(1,STATION_COUNT-2):
    var a: Vector3=_profile_point(_station_x(station),row,side)
    var b: Vector3=_profile_point(_station_x(station+1),row,side)
    a.z+=side*.009;b.z+=side*.009
    var normal_:=Vector3(0,0,side)
    var down:=Vector3.DOWN*.007
    builder._triangle(a+down,b+down,b-down,normal_,materials.darkwood)
    builder._triangle(a+down,b-down,a-down,normal_,materials.darkwood)
    builder.count+=1

static func build(builder,materials: Dictionary) -> Dictionary:
 var data: Dictionary=mesh_data()
 var vertices: PackedVector3Array=data.vertices
 var triangles: PackedInt32Array=data.triangles
 for index in range(0,triangles.size(),3):
  var a: Vector3=vertices[triangles[index]];var b: Vector3=vertices[triangles[index+1]];var c: Vector3=vertices[triangles[index+2]]
  var normal_: Vector3=data.triangle_normals[index/3]
  builder._triangle(a,b,c,normal_,materials[data.triangle_materials[index/3]])
  builder.count+=1
 _skin_seams(builder,materials)
 return geometry_report(data)
