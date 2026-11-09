extends RefCounted
## Presentation-only carry poses. Attack definitions and damage origins stay authored.
static func rest(family: String, angle: float, hand: int=-1) -> Dictionary:
 var facing := cos(angle)
 var pose := {"phase":"idle","angle":angle,"grip_angle":angle,"radius":.22,"pitch":.0,"grip_height":.66,"body_lean":.0,"trail":false,"progress":.0,"stance_managed":true}
 match family:
  "sword":
   pose.angle=angle+(.375 if hand==0 else (-.375 if hand==1 else .0));pose.pitch=.56;pose.grip_height=.61;pose.blade_length=1.9
  "mace":
   pose.angle=angle+(.15 if hand==0 else (-.15 if hand==1 else .0));pose.pitch=.85-.15*facing*(1 if hand==0 else -1) if hand>=0 else .88;pose.grip_height=.62;pose.radius=.18;pose.blade_length=1.9
  "greatsword":
   pose.angle=angle+PI-.20*facing;pose.pitch=.68;pose.radius=.13;pose.grip_height=.81;pose.blade_length=2.475
  "staff":
   pose.angle=angle+.10*facing;pose.pitch=.88;pose.radius=.18;pose.grip_height=.57;pose.blade_length=1.45
  "pistol":
   pose.angle=angle;pose.pitch=-.53;pose.radius=.28;pose.grip_height=.68;pose.blade_length=.72
   if hand>=0:
    var front: float=facing*(1 if hand==0 else -1)
    pose.radius=.04+.22*front;pose.grip_height=.48+.16*front;pose.pitch=-.60
  "shield":
   pose.radius=.16;pose.grip_height=.67;pose.blade_length=.70
  "crossbow":
   pose.radius=.25;pose.grip_height=.76;pose.pitch=-.12;pose.blade_length=.91
  "bow":
   pose.radius=.34;pose.grip_height=.76;pose.pitch=-.14;pose.blade_length=.23
  "rifle":
   pose.angle=angle;pose.pitch=-.19;pose.radius=.19;pose.grip_height=.79;pose.blade_length=1.35
 return pose
static func blend(a: Dictionary,b: Dictionary,t: float) -> Dictionary:
 var result := b.duplicate(true)
 for field in ["angle","grip_angle","radius","pitch","grip_height","body_lean"]:
  var start: float=a.get(field,a.get("angle",0) if field=="grip_angle" else b.get(field,0))
  var finish: float=b.get(field,b.get("angle",0) if field=="grip_angle" else start)
  result[field]=lerp_angle(start,finish,t) if field in ["angle","grip_angle"] else lerpf(start,finish,t)
 return result
