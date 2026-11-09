extends "res://scripts/opening/harbor_npc.gd"
## A porter follows a real outbound/return path and changes load only at its ends.
signal picked_up(courier)
signal delivered(courier)
var transfer_path: Array[Vector3]=[]
var cargo_kind: String="crate"
var enabled:=false
var completed_deliveries:=0
var state: String="waiting"
var waypoint:=0
var direction:=1
var pause:=0.0
var departure_delay:=0.0
var cargo_size:=.60
var pickup_anchor:=Vector3.INF
var dropoff_anchor:=Vector3.INF
var _acquired:=false
var _released:=false
func _ready() -> void:
 profile.native_cargo=true;profile.cargo_size=cargo_size;profile.cargo_kind=cargo_kind
 super._ready()
 reset_activity()
func reset_activity() -> void:
 enabled=false
 waypoint=0;direction=1;pause=departure_delay;carrying=false;walking=false
 completed_deliveries=0;state="waiting"
 _acquired=false;_released=false;pickup_anchor=Vector3.INF;dropoff_anchor=Vector3.INF
 if native_load!=null:native_load.hide()
 if not transfer_path.is_empty():position=transfer_path[0]
func set_enabled(value: bool) -> void:
 enabled=value
 if enabled and state=="waiting":state="outbound"
func prepare_at_source() -> void:
 reset_activity()
 if transfer_path.is_empty():return
 position=transfer_path[-1];waypoint=transfer_path.size()-1;direction=1;state="pickup";pause=1.2
func tick(delta: float,camera: Camera3D,time_: float) -> void:
 actor_clock=time_;walking=false
 var remaining: float=minf(delta,.05)
 if enabled and transfer_path.size()>1:
  if pause>0:
   pause=maxf(0,pause-remaining)
   if state=="pickup" and not _acquired and pause<=.85:
    carrying=true;_acquired=true;picked_up.emit(self)
   if state=="dropoff" and not _released and pause<=.35:
    carrying=false;_released=true;completed_deliveries+=1;delivered.emit(self)
  elif state=="pickup":
   direction=-1;waypoint=transfer_path.size()-2;state="returning"
  elif state=="dropoff":
   direction=1;waypoint=1;state="outbound";pause=.8
  else:
   if state=="waiting":state="outbound";waypoint=1
   if waypoint==0 and direction==1:waypoint=1
   var target: Vector3=transfer_path[waypoint]
   var before:=position
   if position.distance_to(target)>.012:
    aim=(target-position).normalized();move_on_route(position.move_toward(target,speed*remaining))
   walking=position.distance_squared_to(before)>.0000001
   if position.distance_to(target)<=.012 and move_on_route(target):
    if direction==1 and waypoint==transfer_path.size()-1:state="pickup";pause=1.2;_acquired=false
    elif direction==-1 and waypoint==0:state="dropoff";pause=1.1;_released=false
    else:waypoint+=direction
 var target_anchor: Vector3=pickup_anchor if state=="pickup" else dropoff_anchor if state=="dropoff" else Vector3.INF
 if target_anchor!=Vector3.INF:
  var toward: Vector3=target_anchor-global_position;toward.y=0
  if toward.length_squared()>.001:aim=toward.normalized()
 facing=Directions.choose(aim,camera,facing)
 var action: String="lift" if state=="pickup" else "place" if state=="dropoff" else "carry_walk" if carrying else "walk" if walking else "idle"
 var index: int=int(time_*(7 if walking else 2)+float(profile.get("phase",0)))%(4 if walking or action=="work" else 2)
 render_modular(camera,action,index)
 _sync_load(camera)
func _sync_load(camera: Camera3D) -> void:
 native_load.visible=carrying
 var forward:=Vector3(aim.x,0,aim.z).normalized()
 var grip: Vector3=carry_grip(camera)+forward*.14+camera.global_basis.z*.13
 var at: Vector3=grip
 var yaw: float=atan2(forward.x,forward.z)
 if state=="pickup" and carrying:
  var source: Vector3=pickup_anchor if pickup_anchor!=Vector3.INF else global_position+forward*.7+Vector3.UP*cargo_size*.5
  var lift: float=smoothstep(0,.70,.85-pause)
  at=source.lerp(grip,lift);yaw=lerp_angle(0,yaw,lift)
 elif state=="dropoff" and carrying:
  var target: Vector3=dropoff_anchor if dropoff_anchor!=Vector3.INF else global_position+forward*.7+Vector3.UP*cargo_size*.5
  var lower: float=smoothstep(0,.70,1.1-pause)
  at=grip.lerp(target,lower);yaw=lerp_angle(yaw,0,lower)
 native_load.global_position=at;native_load.global_rotation=Vector3(0,yaw,0)
 if state in ["pickup","dropoff"]:
  var bend: float=sin(clampf((1.2-pause)/1.2,0,1)*PI)*.045
  sprite.global_position-=camera.global_basis.y*bend
func apply_deck_offset(offset: Vector3,camera: Camera3D) -> void:
 super.apply_deck_offset(offset,camera)
 _sync_load(camera)
 native_load.global_position+=offset
