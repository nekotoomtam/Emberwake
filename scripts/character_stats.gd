extends Resource
## Authored base values remain unchanged; future item/passive modifiers resolve here.
@export var base: Dictionary={}
var flat: Dictionary={}
var increased: Dictionary={}
func value(key: String) -> float:
 var number: float=float(base.get(key,0))
 number=(number+float(flat.get(key,0)))*(1.0+float(increased.get(key,0)))
 if not is_finite(number):number=float(base.get(key,0))
 if key.begins_with("resist_"):return clampf(number,-1,.75)
 if key=="critical_chance":return clampf(number,0,1)
 if key=="critical_multiplier":return maxf(1,number)
 if key in ["attack_speed","move_speed","reload_speed","sight_range","max_health","max_stamina"]:return maxf(.01,number)
 return maxf(0,number)
func incoming(amount: float,element: String="physical") -> float:
 if not is_finite(amount) or amount<=0:return 0
 if element in ["physical",""]:return amount*100.0/(100.0+value("armor"))
 if element in ["fire","ice","lightning"]:return amount*(1-value("resist_"+element))
 return amount
func critical_multiplier(roll: float) -> float:
 return value("critical_multiplier") if roll<value("critical_chance") else 1.0
func reset_modifiers() -> void:flat.clear();increased.clear()
