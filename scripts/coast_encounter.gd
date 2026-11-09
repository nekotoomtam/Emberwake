extends RefCounted
## Exploration orchestration only; actor AI and authored land own their behavior.
const Roster=preload("res://scripts/coastal_roster.gd")
var stage:="ordinary"
var wait:=0.0
const TOTAL:=10
func populate(game) -> void:
 stage="ordinary";wait=0
 var centers: Array[Vector3]=[Vector3(-15.5,.03,3),Vector3(-8.5,.03,1.5),Vector3(-1,.03,3.7),Vector3(7,.03,1.5),Vector3(14,.03,4)]
 var kinds: Array[String]=Roster.kinds()
 for i in range(kinds.size()):
  for side in [-1.0,1.0]:game.spawn_enemy(kinds[i],centers[i]+Vector3(side*.7,0,side*.9))
func living(game) -> int:
 var amount:=0
 for enemy in game.enemies:
  if is_instance_valid(enemy) and not enemy.dead:amount+=1
 return amount
func tick(delta: float,game) -> void:
 if stage=="complete" or game.mode!="combat" or living(game)>0:return
 wait+=delta
 if stage=="ordinary" and wait>=1.0:
  stage="captain";wait=0;game.clear_hostile_projectiles()
  game.health=minf(game.max_health(),game.health+25);game.stamina=game.stats.value("max_stamina");game.flasks.charges=mini(3,game.flasks.charges+1)
  game.spawn_enemy("captain",game.arena.captain_point)
  game.fx.number(game.player.position+Vector3.UP*2.0,"เสบียง +25 HP • ยา +1",true);game.audio.play("warning")
 elif stage=="captain" and wait>=1.0:
  stage="complete";game.finish_coast()
