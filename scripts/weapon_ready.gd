extends RefCounted
## Base RMB rules, separate from later item/skill modifiers.
const GUNS := ["pistol","rifle"]
const MELEE := ["sword","greatsword","mace"]
const BLOCK_REDUCTION := .30
const SHIELD_REDUCTION := .55
const BLOCK_DOT := .5 # 120 degree frontal arc.
const BREAK_TIME := .65
const PARRY_WINDOW := .15
const PARRY_COST := 4.0
var parry_left:=.0
var parry_flash:=.0
var parries:=0
var held := false
var broken_left := .0
var blocks := 0
var breaks := 0
func press(eligible: bool) -> void:
 if not held:parry_left=PARRY_WINDOW if eligible else .0
 held=true
func release(keep_window: bool=false) -> void:
 held=false
 if not keep_window:parry_left=0
func reset() -> void:held=false;broken_left=0;blocks=0;breaks=0;parry_left=0;parry_flash=0;parries=0
func tick(delta: float) -> void:
 broken_left=maxf(0,broken_left-delta);parry_left=maxf(0,parry_left-delta);parry_flash=maxf(0,parry_flash-delta)
func mode(family: String,available: bool,can_guard: bool) -> String:
 if not available or (not held and parry_left<=0) or broken_left>0:return ""
 if family in GUNS:return "aim" if held else ""
 return "guard" if (family in MELEE or (family == "shield" and held)) and can_guard else ""
static func spread(family: String,aimed: bool) -> float:
 if family=="pistol":return deg_to_rad(2.5 if aimed else 8)
 if family=="rifle":return deg_to_rad(.5 if aimed else 12)
 return .0
static func shot_direction(family: String,aimed: bool,angle: float,roll: float) -> Vector3:
 var a:=angle+spread(family,aimed)*clampf(roll,-1,1)
 return Vector3(cos(a),0,sin(a))
func receive(amount: float,source: Vector3,position: Vector3,facing: Vector3,stamina: float,cost_multiplier: float=1.0) -> Dictionary:
 var result:={"damage":amount,"stamina":stamina,"blocked":false,"broken":false}
 if not source.is_finite():return result
 var incoming:=Vector3(source.x-position.x,0,source.z-position.z)
 if incoming.length_squared()<.00001 or incoming.normalized().dot(facing.normalized())<BLOCK_DOT-.00001:return result
 blocks+=1;result.damage=amount*(1-BLOCK_REDUCTION);result.blocked=true
 return result

static func frontal(source: Vector3,position: Vector3,facing: Vector3) -> bool:
 if not source.is_finite():return false
 var incoming:=Vector3(source.x-position.x,0,source.z-position.z)
 return incoming.length_squared()>.00001 and incoming.normalized().dot(facing.normalized())>=BLOCK_DOT-.00001
func try_parry(source: Vector3,position: Vector3,facing: Vector3,stamina: float,cost: float=PARRY_COST,skill_window: bool=false) -> bool:
 if (parry_left<=0 and not skill_window) or broken_left>0 or stamina<cost or not frontal(source,position,facing):return false
 parry_left=0;parry_flash=.22;parries+=1;return true
