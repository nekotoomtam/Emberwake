extends RefCounted
## Ground geometry shared by the anchor, telegraphs, and swept contact.
const PLAYER_RADIUS:=.30
const ANCHOR_RADIUS:=.40
const ANCHOR_PIXEL_SIZE:=.010
const VISUAL_HEIGHT:=.12
static func definition(id: String) -> Dictionary:
 var d:={"id":id,"shape":"annulus","windup":1.05,"active":.46,"recovery":1.25,"reach":1.9,"arc":deg_to_rad(145),"radius":ANCHOR_RADIUS+PLAYER_RADIUS,"damage":18.0,"parryable":true,"guard_cost":1.0,"body_part":"right_upper_arm"}
 if id=="throw":d.merge({"shape":"lane","release":.18,"out_end":.80,"return_start":.92,"catch_time":1.55,"launch":Vector3.ZERO,"launch_lift":0.0,"windup":1.35,"active":1.65,"recovery":1.65,"reach":5.2,"damage":24.0,"body_part":"torso"},true)
 if id=="slam":d.merge({"shape":"circle","impact":.4,"windup":1.30,"active":.18,"recovery":1.45,"reach":2.0,"radius":1.10,"damage":30.0,"parryable":false,"guard_cost":1.5,"body_part":"left_lower_leg"},true)
 d.reach=float(d.reach)*1.15;d.trigger=(5.4 if id=="throw" else 2.3)*1.15
 d.base_parryable=d.parryable;d.body_damage=d.damage*.2;return d
static func tip(d: Dictionary,angle: float,elapsed: float) -> Vector3:
 var p:=clampf(elapsed/float(d.active),0,1)
 if d.id=="sweep":
  var a:=angle-float(d.arc)*.5+float(d.arc)*p
  return Vector3(cos(a),0,sin(a))*float(d.reach)
 var distance: float=float(d.reach)
 if d.id=="throw":return Vector3(d.launch).lerp(Vector3(cos(angle),0,sin(angle))*distance,throw_fraction(d,elapsed))
 return Vector3(cos(angle),0,sin(angle))*distance
static func contact(a: Vector3,b: Vector3,target: Vector3,d: Dictionary) -> bool:
 var p:=Vector3(target.x,0,target.z);a.y=0;b.y=0
 return Geometry3D.get_closest_point_to_segment(p,a,b).distance_squared_to(p)<=float(d.radius)*float(d.radius)+.0000001
static func contains(origin: Vector3,angle: float,target: Vector3,d: Dictionary) -> bool:
 var p:=Vector3(target.x-origin.x,0,target.z-origin.z)
 if d.shape=="circle":return p.distance_to(tip(d,angle,0))<=float(d.radius)+.00001
 if d.shape=="lane":return contact(Vector3(d.launch),Vector3(cos(angle),0,sin(angle))*float(d.reach),p,d)
 var r:=p.length();var delta:=absf(wrapf(atan2(p.z,p.x)-angle,-PI,PI));var half: float=float(d.arc)*.5
 # Rounded end caps are the same anchor/player contact radius as the sweep.
 if delta>half:return minf(p.distance_to(tip(d,angle,0)),p.distance_to(tip(d,angle,d.active)))<=float(d.radius)+.00001
 return absf(r-float(d.reach))<=float(d.radius)+.00001
static func outline(d: Dictionary,angle: float) -> Array[Vector3]:
 var out: Array[Vector3]=[]
 if d.shape=="circle":
  var c:=tip(d,angle,0)
  for i in range(49):var a:=TAU*i/48;out.append(c+Vector3(cos(a),0,sin(a))*float(d.radius))
 elif d.shape=="lane":
  var start: Vector3=d.launch;var end:=Vector3(cos(angle),0,sin(angle))*float(d.reach);var f: Vector3=(end-start).normalized();var side:=Vector3(-f.z,0,f.x)
  for i in range(25):var a: float=-PI*.5+PI*i/24;out.append(end+(f*cos(a)+side*sin(a))*float(d.radius))
  for i in range(25):var a: float=PI*.5+PI*i/24;out.append(start+(f*cos(a)+side*sin(a))*float(d.radius))
 else:
  var half: float=float(d.arc)*.5;var r: float=float(d.radius);var reach: float=float(d.reach)
  for i in range(49):var a:=angle-half+float(d.arc)*i/48;out.append(Vector3(cos(a),0,sin(a))*(reach+r))
  var end:=tip(d,angle,d.active)
  for i in range(1,25):var a:=angle+half+PI*i/24;out.append(end+Vector3(cos(a),0,sin(a))*r)
  for i in range(1,49):var a:=angle+half-float(d.arc)*i/48;out.append(Vector3(cos(a),0,sin(a))*(reach-r))
  var start:=tip(d,angle,0)
  for i in range(1,25):var a:=angle-half+PI+PI*i/24;out.append(start+Vector3(cos(a),0,sin(a))*r)
 return out

static func throw_fraction(d: Dictionary,elapsed: float) -> float:
 if elapsed<d.release:return 0.0
 if elapsed<d.out_end:return (elapsed-float(d.release))/float(d.out_end-d.release)
 if elapsed<d.return_start:return 1.0
 if elapsed<d.catch_time:return 1-(elapsed-float(d.return_start))/float(d.catch_time-d.return_start)
 return 0.0
static func visual_lift(d: Dictionary,elapsed: float) -> float:
 if d.id!="throw":return 0.0
 var lift: float=d.launch_lift
 if elapsed<d.release:return lift
 if elapsed<d.out_end:
  var p: float=(elapsed-float(d.release))/float(d.out_end-d.release)
  return lerpf(lift,0,p)+.18*sin(PI*p)
 if elapsed<d.return_start:return 0.0
 if elapsed<d.catch_time:
  var p: float=(elapsed-float(d.return_start))/float(d.catch_time-d.return_start)
  return lerpf(0,lift,p)+.10*sin(PI*p)
 return lift
static func damaging(d: Dictionary,elapsed: float) -> bool:
 if d.id=="throw":return elapsed+0.0000001>=float(d.release) and elapsed<float(d.catch_time)-.0000001
 return d.id!="slam" or elapsed+0.0000001>=float(d.active)*float(d.impact)
