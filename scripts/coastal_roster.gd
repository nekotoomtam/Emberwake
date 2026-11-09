extends RefCounted
const Anatomy = preload("res://scripts/anatomy_state.gd")
## Ordinary coast enemies: attack data is shared by poses and combat footprints.
static func kinds() -> Array[String]:return ["fisherman","brinehound","net_hauler","harpooner","spitter"]
static func stats(kind: String) -> Dictionary:
 var values: Dictionary={"fisherman":[75.0,100.0,1.7,11.0],"brinehound":[62.0,100.0,2.5,10.0],"net_hauler":[110.0,120.0,1.25,10.0],"harpooner":[75.0,100.0,1.45,12.0],"spitter":[68.0,100.0,1.6,11.0]}
 var v: Array=values.get(kind,values.fisherman)
 return {"health":v[0],"armor":v[1],"speed":v[2],"detection":7.5,"leash":10.0}
static func attack(kind: String,index: int) -> Dictionary:
 var alt:=posmod(index,2)==1
 var a:={"id":"hook","shape":"sector","arc":deg_to_rad(100),"reach":1.65,"trigger":1.5,"windup":1.0,"active":.42,"recovery":1.4,"damage":14.0,"parryable":true,"guard_cost":1.0,"variant":false,"impact":.35,"projectiles":0,"lunge":0.0}
 match kind:
  "fisherman":
   if alt:a.merge({"id":"thrust","shape":"lane","width":.55,"reach":2.05,"trigger":1.8,"windup":1.15,"recovery":1.6,"damage":17.0,"variant":true},true)
  "brinehound":a.merge({"id":"bite","shape":"sector","arc":deg_to_rad(70),"reach":.95,"trigger":1.45,"windup":.85,"active":.48,"recovery":1.45,"damage":13.0,"lunge":.65},true)
  "net_hauler":
   a.merge({"id":"overhead","shape":"lane","width":.8,"reach":1.95,"trigger":1.7,"windup":1.3,"active":.5,"recovery":2.1,"damage":24.0,"parryable":false,"guard_cost":1.5},true)
   if alt:a.merge({"id":"sweep","shape":"sector","arc":deg_to_rad(135),"reach":2.05,"windup":1.15,"recovery":1.85,"damage":18.0,"parryable":true,"guard_cost":1.0,"variant":true},true)
  "harpooner":a.merge({"id":"harpoon","shape":"lane","width":.8,"reach":9.0,"trigger":9.0,"windup":1.2,"active":.45,"recovery":2.8,"damage":22.0,"projectiles":1,"style":"harpoon"},true)
  "spitter":
   a.merge({"id":"glob","shape":"lane","width":.8,"reach":6.5,"trigger":6.5,"windup":.95,"active":.42,"recovery":2.0,"damage":9.0,"projectiles":1,"style":"glob"},true)
   if alt:a.merge({"id":"fan","damage":6.0,"projectiles":3,"spread":deg_to_rad(13),"windup":1.1,"recovery":2.2,"variant":true},true)
 a.base_parryable=a.parryable
 var parts := Anatomy.STRIKE_TARGETS
 a.body_part=parts[posmod(index,parts.size())];a.body_damage=float(a.damage)*.2
 return a


