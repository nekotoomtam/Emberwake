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
# Idle carry for the articulated avatar. Cant end-on weapons away from the face.
static func cutout_rest(family: String, angle: float, view: String) -> Dictionary:
 var pose := rest(family, angle)
 var end_on := view in ["front", "back"]
 var outward := -1.0 if view == "front" else 1.0
 if end_on:
  var yaw := {"sword": .79, "pistol": .53, "rifle": -.94,
   "crossbow": -.76, "bow": .72, "greatsword": -.98}
  pose.angle = angle + float(yaw.get(family, 0.0))
  if view == "front" and family in ["sword", "greatsword"]:
   var carry_yaw := .14 if family == "sword" else -1.10
   pose.angle = lerp_angle(PI * .5, angle, .16 if family == "sword" else .25) + carry_yaw
  if view == "back" and family in ["rifle", "crossbow"]:
   pose.angle = angle - 1.17
 pose.grip_side = outward * (.21 if end_on else .05)
 match family:
  "sword":
   pose.radius = .16; pose.grip_height = .64; pose.pitch = .38 if view == "front" else (.28 if end_on else .35)
  "mace":
   pose.radius = .13; pose.grip_height = .63; pose.pitch = .72
   if end_on: pose.merge(long_weapon_axial_carry(angle, view), true)
  "greatsword":
   pose.radius = .18; pose.grip_height = .67; pose.pitch = .43 if view == "front" else (.20 if end_on else .48)
  "staff":
   pose.radius = .15; pose.grip_height = .57; pose.pitch = .98
   if end_on:
    pose.radius = .13; pose.grip_height = .63
    pose.merge(staff_axial_carry(angle, view), true)
  "pistol":
   pose.radius = .15; pose.grip_height = .64; pose.pitch = -.36
  "rifle":
   pose.radius = .18; pose.grip_height = .77; pose.pitch = -.32 if view == "back" else -.12
  "bow":
   pose.radius = .24; pose.grip_height = .74; pose.pitch = -.04
   pose.grip_side *= -1.0
  "crossbow":
   pose.radius = .20; pose.grip_height = .72; pose.pitch = -.31 if view == "back" else -.11
  "shield":
   pose.radius = .19; pose.grip_height = .69
 return pose

static func long_weapon_axial_carry(angle: float, view: String) -> Dictionary:
 var view_angle := PI * .5 if view == "front" else -PI * .5
 return {"angle": lerp_angle(view_angle, angle, .24) + 1.15, "pitch": .79}

static func staff_axial_carry(angle: float, view: String) -> Dictionary:
 var pose := long_weapon_axial_carry(angle, view)
 pose.grip_side = -.21 if view == "front" else .48
 if view == "back": pose.pitch = .53
 return pose

static func blend(a: Dictionary,b: Dictionary,t: float) -> Dictionary:
 var result := b.duplicate(true)
 for field in ["angle","grip_angle","radius","pitch","grip_height","body_lean"]:
  var start: float=a.get(field,a.get("angle",0) if field=="grip_angle" else b.get(field,0))
  var finish: float=b.get(field,b.get("angle",0) if field=="grip_angle" else start)
  result[field]=lerp_angle(start,finish,t) if field in ["angle","grip_angle"] else lerpf(start,finish,t)
 result.grip_side = lerpf(a.get("grip_side", 0.0), b.get("grip_side", 0.0), t)
 return result
