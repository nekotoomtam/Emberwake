extends RefCounted
const Anatomy = preload("res://scripts/anatomy_state.gd")
## One definition drives anticipation, footprint, contact, and recovery.
static func definition(kind: String,index: int,enraged: bool=false) -> Dictionary:
 var red: bool=(index%2==1) if kind=="elite" else (index%3==2)
 var result:={"parryable":not red,"guard_cost":1.5 if red else 1.0,"active":.12,"recovery":.85,"shape":"sector","arc":deg_to_rad(110),"reach":1.75,"trigger":1.4,"windup":.55,"damage":10.0}
 if kind=="melee" and red:result.merge({"arc":deg_to_rad(135),"reach":1.95,"windup":.8,"damage":14.0,"recovery":1.0},true)
 if kind=="elite":result.merge({"arc":TAU if red else deg_to_rad(140),"reach":2.8 if red else 2.65,"trigger":2.3,"windup":1.05 if red else (.65 if enraged else .95),"damage":22.0,"recovery":1.1 if red else (.5 if enraged else 1.2)},true)
 if kind=="ranged":result.merge({"shape":"lane","width":.8,"reach":6.0,"trigger":6.0,"windup":1.0 if red else .8,"damage":11.0,"recovery":.85},true)
 var targets := Anatomy.STRIKE_TARGETS
 result.body_part=targets[posmod(index,targets.size())];result.body_damage=float(result.damage)*.2;result.base_parryable=not red
 return result
static func contains(origin: Vector3,angle: float,target: Vector3,data: Dictionary) -> bool:
 var offset:=Vector3(target.x-origin.x,0,target.z-origin.z)
 var direction:=Vector3(cos(angle),0,sin(angle))
 if data.shape=="lane":
  var closest:=direction*clampf(offset.dot(direction),0,float(data.reach))
  return offset.distance_to(closest)<=float(data.width)*.5
 if offset.length()>float(data.reach)+.00001:return false
 return float(data.arc)>=TAU-.001 or offset.length_squared()<.00001 or absf(wrapf(atan2(offset.z,offset.x)-angle,-PI,PI))<=float(data.arc)*.5+.00001

static func projectile_contact_time(origin: Vector3,direction: Vector3,target: Vector3) -> float:
 var offset:=Vector3(origin.x-target.x,0,origin.z-target.z)
 var c:=offset.length_squared()-.4*.4
 if c<=0:return .0
 var b:=offset.dot(direction)
 var discriminant:=b*b-c
 if discriminant<0:return INF
 var distance: float=-b-sqrt(discriminant)
 return (distance/5.5) if distance>=0 else INF
