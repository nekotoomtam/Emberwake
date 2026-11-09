extends "res://scripts/opening/harbor_npc.gd"
## A forecourt-owned resident: native NPC movement/contact, private appearance frames.
var role:="watcher"
var action:="idle"
var pose_index:=0
var tick_count:=0
var phase:=0.0
func _ready() -> void:
 super._ready()
 set_process(false);set_physics_process(false);set_meta("passenger_life_owned",true)
 _wait=3.2 if role=="porter" else 0.0
func _walk_porter(delta: float) -> void:
 var dt:=minf(maxf(delta,0.0),.05)
 var target: Vector3=route[_target]
 if _wait>0:
  _wait=maxf(0.0,_wait-dt);aim=Vector3.LEFT
  action="hold_tag" if _target in [0,3] else "inspect"
  return
 if position.distance_to(target)<.025:
  if move_on_route(target):
   _target=(_target+1)%route.size()
   _wait=2.6 if _target in [0,3] else 2.0
   action="hold_tag" if _target in [0,3] else "inspect";aim=Vector3.LEFT
 else:
  aim=(target-position).normalized()
  move_on_route(position.move_toward(target,speed*dt))
  action="walk" if walking else "inspect"
func tick(delta: float,camera: Camera3D,clock: float) -> void:
 tick_count+=1;actor_clock=clock
 var before:=position;var cycle:=fposmod(clock+phase,15.0)
 var art_action: String="idle"
 if role=="porter":
  _walk_porter(delta);walking=position.distance_squared_to(before)>.0000001
  if walking:action="walk"
  elif action=="walk":action="inspect"
  art_action=action;pose_index=int(clock*(5.0 if walking else 1.1))%(4 if walking else 3)
 elif role=="ticket":
  walking=false;pose_index=0 if cycle<3.0 or cycle>=12.5 else 1 if cycle<8.0 else 2
  aim=Vector3.FORWARD if cycle>=10.0 and cycle<12.5 else Vector3.BACK
  action="board_glance" if cycle>=10.0 and cycle<12.5 else "ticket_read";art_action="ticket"
 else:
  walking=false;aim=Vector3(.62,0,-.32).normalized() if cycle>=10.0 and cycle<12.0 else Vector3.FORWARD
  action="companion_glance" if cycle>=10.0 and cycle<12.0 else "sea_watch";pose_index=int(clock*.45)%2
 facing=Directions.choose(aim,camera,facing)
 render_modular(camera,art_action,pose_index,"Worker" if role=="porter" else "Middle")
 human_blocker.position=Vector3.ZERO
