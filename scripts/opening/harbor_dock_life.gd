extends Node3D
## Exactly the two marked haulers, one shared doorway, fixed visible pickup stock.
const NPC=preload("res://scripts/opening/harbor_npc.gd")
const Courier=preload("res://scripts/opening/harbor_cargo_courier.gd")
var world
var chat: Array=[]
var marked_workers: Array=[]
var source_boxes: Array[Node3D]=[]
var active_index:=0
var turn_start_deliveries:=0
var pickups:=0
var deliveries:=0
func _ready() -> void:
 name="WarehouseDockLife"
 var positions: Array[Vector3]=[Vector3(-24.8,.055,-12),Vector3(-22.9,.055,-12)]
 for i in 2:
  var actor=NPC.new();actor.name="DockConversation"+str(i+1)
  actor.profile=world.backdrop.district._profile(60+i,false);actor.profile.id=actor.name
  actor.position=positions[i];actor.route.assign([positions[i]]);actor.aim=(positions[1-i]-positions[i]).normalized();actor.carrying=false
  add_child(actor);chat.append(actor)
 source_boxes.assign([world.backdrop.district.marked_stocks.red,world.backdrop.district.marked_stocks.orange])
 var red_path: Array[Vector3]=[Vector3(-27.65,.055,-29),Vector3(-25.9,.055,-29),Vector3(-24,.055,-31.5),Vector3(-23.4,.055,-34),Vector3(-23.4,.055,-36.3),Vector3(-24.6,.055,-36.3)]
 var orange_path: Array[Vector3]=[Vector3(-27.65,.055,-29),Vector3(-25.9,.055,-29),Vector3(-23.5,.055,-28),Vector3(-21,.055,-27.6),Vector3(-20.5,.055,-27.6),Vector3(-18.5,.43,-27.6),Vector3(-11.5,.43,-27.6),Vector3(-10.88,.43,-27.15)]
 for i in 2:
  var actor=Courier.new();actor.name="PortWorker20" if i==0 else "CargoCourier30"
  actor.profile=world.backdrop.district._profile(20 if i==0 else 30,true)
  actor.transfer_path=red_path if i==0 else orange_path;actor.cargo_size=float(source_boxes[i].get_meta("cargo_size"));actor.speed=1.05
  actor.picked_up.connect(_pickup.bind(i));actor.delivered.connect(_deliver.bind(i))
  add_child(actor);marked_workers.append(actor)
 reset_activity()
func _targets(index: int) -> void:
 var actor=marked_workers[index]
 actor.pickup_anchor=source_boxes[index].global_position
 actor.dropoff_anchor=Vector3(-27.78,.055+actor.cargo_size*.5,-29)
 actor.aim=Vector3(0,0,1)
func reset_activity() -> void:
 active_index=0;turn_start_deliveries=0;pickups=0;deliveries=0
 for i in marked_workers.size():
  marked_workers[i].prepare_at_source();source_boxes[i].show();_targets(i)
  marked_workers[i].set_enabled(i==active_index)
func _pickup(_actor,index: int) -> void:
 pickups+=1;source_boxes[index].hide()
func _deliver(_actor,_index: int) -> void:
 deliveries+=1 # The box is received inside the real doorway; no new yard pile.
func tick(delta: float,camera: Camera3D,time_: float) -> void:
 for i in chat.size():chat[i].work=fposmod(time_+float(i)*3.5,7)<2.;chat[i].tick(delta,camera,time_)
 var active=marked_workers[active_index]
 if active.state=="pickup" and active.completed_deliveries>turn_start_deliveries:
  active.set_enabled(false);source_boxes[active_index].show()
  active_index=1-active_index;turn_start_deliveries=marked_workers[active_index].completed_deliveries
 for i in marked_workers.size():
  var actor=marked_workers[i];actor.set_enabled(i==active_index)
  actor.tick(delta if i==active_index else 0.,camera,time_)
