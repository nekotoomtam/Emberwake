extends RefCounted
## Magazine-clock-driven presentation. No ammunition or attack timing ownership.
const Stance = preload("res://scripts/weapon_stance.gd")
var family := ""
var serial := 0
var active := false
var sent: Dictionary={}
func begin(value: String) -> void:
 family=value;serial+=1;active=true;sent.clear()
func cancel() -> void:active=false;sent.clear()
func events(progress: float) -> Array[String]:
 var result: Array[String]=[]
 if not active:return result
 var cues: Array=[[.14,"pistol_spin"],[.76,"pistol_catch"]] if family=="pistol" else [[.42,"rifle_insert"],[.73,"rifle_rack"]]
 for cue in cues:
  if progress>=float(cue[0]) and not sent.has(cue[1]):sent[cue[1]]=true;result.append(cue[1])
 return result
static func curve(value: float) -> float:
 var p := clampf(value,0,1)
 return p*p*(3-2*p)
static func pose(value: String,progress: float,angle: float,hand: int) -> Dictionary:
 var p := clampf(progress,0,1)
 var result := Stance.rest(value,angle,hand)
 result.phase="reload";result.progress=p;result.stance_managed=false
 var lift := curve(p/.14) if p<.14 else (1.0 if p<.78 else 1-curve((p-.78)/.22))
 if value=="pistol":
  result.angle=angle;result.grip_angle=angle
  result.pitch=lerpf(result.pitch,.08,lift)
  result.radius=lerpf(result.radius,.28,lift)
  result.grip_height=lerpf(result.grip_height,.84,lift)
  var spin := clampf((p-.14)/.50,0,1)
  result.screen_roll=2*TAU*curve(spin)
  result.spin_blur=sin(PI*spin) if spin>0 and spin<1 else .0
  result.body_lean=-.025*sin(PI*p)
 else:
  lift=curve(p/.20) if p<.20 else (1.0 if p<.73 else 1-curve((p-.73)/.27))
  result.pitch=lerpf(result.pitch,.90,lift)
  result.radius=lerpf(result.radius,.18,lift)
  result.grip_height=lerpf(result.grip_height,.91,lift)
  result.support_pull=curve((p-.20)/.18) if p<.38 else 1-curve((p-.48)/.22)
  result.body_lean=-.035*lift
 return result
