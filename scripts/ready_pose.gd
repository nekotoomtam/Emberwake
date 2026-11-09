extends RefCounted
const Stance=preload("res://scripts/weapon_stance.gd")
static func pose(family: String,angle: float,mode: String) -> Dictionary:
 var result:=Stance.rest(family,angle)
 result.stance_managed=false;result.ready_carry=true
 if mode=="aim":
  result.pitch=.02;result.radius=.30;result.grip_height=.85;result.body_lean=.035
  result.angle=angle;result.grip_angle=angle
 elif mode=="shield" and family=="shield":
  result.radius=.46;result.grip_height=.92
 elif mode=="guard":
  result.angle=angle+.85;result.grip_angle=angle;result.pitch=.65
  result.radius=.16;result.grip_height=.88;result.body_lean=-.025
 return result
