extends Resource
## Authored base values remain unchanged; future item/passive modifiers resolve here.
@export var base: Dictionary={}
const ATTRIBUTE_KEYS := ["strength", "dexterity", "intelligence"]
var attributes: Dictionary = {}
var flat: Dictionary={}
var increased: Dictionary={}
func value(key: String) -> float:
 var number: float=float(base.get(key,0))
 number=(number+float(flat.get(key,0))+_attribute_bonus(key))*(1.0+float(increased.get(key,0)))
 if not is_finite(number):number=float(base.get(key,0))
 if key.begins_with("resist_"):return clampf(number,-1,.75)
 if key=="critical_chance":return clampf(number,0,1)
 if key=="critical_multiplier":return maxf(1,number)
 if key in ["attack_speed","move_speed","reload_speed","sight_range","max_health","max_stamina","max_mana"]:return maxf(.01,number)
 return maxf(0,number)
func incoming(amount: float,element: String="physical") -> float:
 if not is_finite(amount) or amount<=0:return 0
 if element in ["physical",""]:return amount*100.0/(100.0+value("armor"))
 if element in ["fire","ice","lightning"]:return amount*(1-value("resist_"+element))
 return amount
func critical_multiplier(roll: float) -> float:
 return value("critical_multiplier") if roll<value("critical_chance") else 1.0
func reset_modifiers() -> void:flat.clear();increased.clear()

static func roll_level_one(rng: RandomNumberGenerator) -> Dictionary:
 var rolled := {"strength": 3, "dexterity": 3, "intelligence": 3}
 rolled[ATTRIBUTE_KEYS[rng.randi_range(0, ATTRIBUTE_KEYS.size() - 1)]] += 1
 return rolled

static func level_one_text(rolled: Dictionary) -> String:
 return "Lv. 1   •   STR %d   DEX %d   INT %d" % [rolled.strength, rolled.dexterity, rolled.intelligence]

func _attribute_bonus(key: String) -> float:
 match key:
  "max_health": return attributes.get("strength", 0) * 3.0
  "max_stamina": return attributes.get("dexterity", 0) * 2.0
  "intelligence": return attributes.get("intelligence", 0)
  "max_mana": return value("intelligence")
 return 0.0
