extends Node3D
## Shared pulse clock deduplicates overlapping patches. Burning never flinches.
signal damage_hit(enemy,amount: float)
const DURATION:=5.0
const INTERVAL:=.5
const DAMAGE:=2.0
const RADIUS:=1.35
var zones: Array[Dictionary]=[]
var pulse_elapsed:=.0
var pulses:=0
var _generation:=0
func spawn_patch(where: Vector3) -> void:
 if not where.is_finite():return
 var node=preload("res://scripts/fire_blast_visual.gd").new()
 add_child(node);node.configure(Vector3(where.x,.045,where.z),RADIUS,"fire",DURATION)
 zones.append({"node":node,"point":Vector3(where.x,.03,where.z),"remaining":DURATION})
func clear() -> void:
 _generation+=1
 for zone in zones:
  if is_instance_valid(zone.node):zone.node.queue_free()
 zones.clear();pulse_elapsed=0;pulses=0
func _covers(zone: Dictionary,enemy,world: World3D) -> bool:
 var offset: Vector3=enemy.position-zone.point;offset.y=0
 if offset.length_squared()>RADIUS*RADIUS+.00000001:return false
 if world!=null:
  var a: Vector3=zone.point+Vector3.UP*.65
  var b: Vector3=enemy.position+Vector3.UP*.65
  if not a.is_equal_approx(b):
   var ray:=PhysicsRayQueryParameters3D.create(a,b,1);ray.hit_from_inside=true
   if not world.direct_space_state.intersect_ray(ray).is_empty():return false
 return true
func tick(delta: float,enemies: Array,world: World3D=null) -> void:
 if not is_finite(delta) or delta<=0:return
 var left:=delta
 var generation:=_generation
 while left>.00000001 and not zones.is_empty():
  var step:=minf(left,INTERVAL-pulse_elapsed)
  for zone in zones:step=minf(step,maxf(.00000001,zone.remaining))
  for zone in zones:
   zone.remaining=maxf(0,zone.remaining-step)
   if is_instance_valid(zone.node):zone.node.tick(step)
  pulse_elapsed+=step;left=maxf(0,left-step)
  if pulse_elapsed>=INTERVAL-.00000001:
   pulse_elapsed=0;pulses+=1
   var hitids: Dictionary={}
   for enemy in enemies.duplicate():
    if not is_instance_valid(enemy) or enemy.get("dead")==true or enemy.health<=0 or hitids.has(enemy.get_instance_id()):continue
    for zone in zones:
     if _covers(zone,enemy,world):
      hitids[enemy.get_instance_id()]=true;damage_hit.emit(enemy,DAMAGE)
      if generation!=_generation:return
      break
  for zone in zones.duplicate():
   if zone.remaining<=.00000001:
    if is_instance_valid(zone.node):zone.node.queue_free()
    zones.erase(zone)
 if zones.is_empty():pulse_elapsed=0
