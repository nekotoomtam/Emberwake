extends RefCounted
## Visual force direction only: neither the flight center nor collision is changed.
const Pose=preload("res://scripts/captain_pose.gd")
const Rules=preload("res://scripts/captain_rules.gd")
static func point(pose: Dictionary,up: Vector3) -> Vector3:
 return Vector3(pose.tip)+up*(Rules.VISUAL_HEIGHT+float(pose.lift))
static func project(v: Vector3,right: Vector3,up: Vector3) -> Vector2:
 return Vector2(v.dot(right),v.dot(up))
static func force(data: Dictionary,time: float,angle: float,right: Vector3,up: Vector3,wrist: Vector3) -> Vector2:
 # Keep the impact heading after a slam lands; zero ground velocity is not a
 # new swing force and must not suddenly turn a falling anchor upside down.
 var t:=minf(time,float(data.active)*float(data.impact)-.00001) if data.id=="slam" else time
 var current: Dictionary=Pose.sample(data,"attack",0,t,0,angle)
 var before: Dictionary=Pose.sample(data,"attack",0,maxf(0,t-.008),0,angle)
 var after: Dictionary=Pose.sample(data,"attack",0,minf(float(data.active),t+.008),0,angle)
 var center:=point(current,up);var velocity:=project(point(after,up)-point(before,up),right,up);var tension:=project(center-wrist,right,up)
 if data.id=="throw" and t>=float(data.out_end) and t<float(data.return_start):
  var outbound: Dictionary=Pose.sample(data,"attack",0,float(data.out_end)-.016,0,angle)
  var outbound_before: Dictionary=Pose.sample(data,"attack",0,float(data.out_end)-.024,0,angle)
  velocity=project(point(outbound,up)-point(outbound_before,up),right,up)
 if tension.length_squared()<.000001:tension=Vector2.UP
 var direction:=tension.normalized()
 if velocity.length_squared()>.00000001:
  if data.id=="throw":direction=velocity.normalized()+direction*.18 if t<float(data.return_start) else direction+velocity.normalized()*.10
  elif data.id=="sweep":direction=velocity.normalized()+direction*.15
  else:direction=velocity.normalized()+direction*.20
 return direction.normalized() if direction.length_squared()>.000001 else Vector2.UP
static func heading(v: Vector2) -> float:return atan2(v.x,-v.y)
static func roll(data: Dictionary,state: String,pose: Dictionary,elapsed: float,cooldown: float,angle: float,right: Vector3,up: Vector3,wrist: Vector3,first_wrist: Vector3,last_wrist: Vector3) -> float:
 var across: float=right.dot(Vector3(cos(angle),0,sin(angle)));var side: float=-1 if across<-.08 else 1
 var base: float=float(pose.roll)*side
 if data.is_empty():return base
 if state=="windup":
  if data.id=="sweep":return lerp_angle(0,heading(force(data,0,angle,right,up,first_wrist)),smoothstep(.12,.9,float(pose.progress)))
  return base
 if state not in ["attack","recover"]:return base
 var end: float=float(data.active) if state=="recover" else elapsed
 var current: Dictionary=Pose.sample(data,"attack",0,end,0,angle)
 if current.held:return base
 var reference_time: float=(float(data.release)+float(data.out_end))*.5 if data.id=="throw" else 0.0
 var reference:=heading(force(data,reference_time,angle,right,up,last_wrist if data.id=="throw" else first_wrist))
 var target:=heading(force(data,end,angle,right,up,last_wrist if state=="recover" else wrist))
 # Unwrap relative to one fixed stroke reference. Re-selecting the shortest
 # branch against a moving recovery pose caused an intermediate half-turn.
 target=reference+wrapf(target-reference,-PI,PI)
 var strength:=1.0
 if data.id=="throw":strength=smoothstep(float(data.release),float(data.release)+.10,end)*(1-smoothstep(float(data.catch_time)-.18,float(data.catch_time),end));base=0
 elif data.id=="slam":strength=smoothstep(0,.04,end);base=-.25*side
 var result:=lerpf(base,target,strength)
 if state=="recover":result=lerp_angle(result,0,smoothstep(0,.85,clampf(1-cooldown/float(data.recovery),0,1)))
 return result
