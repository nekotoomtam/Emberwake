extends Node3D
## Missing physical counterparts of the original reachable native harbor props.
## New plaza furniture owns its own shapes. Scenic distant streets stay scenic.
var world: Node3D
var blockers: Array[PhysicsBody3D]=[]
var deck_blockers: Array[PhysicsBody3D]=[]
var _deck_rest: Array[Transform3D]=[]
func _ready() -> void:
 name="HarborPublicSolids"
 _quay();_pier();_deck()
 tick()
func _body(label: String,at: Vector3,shape: Shape3D,deck: bool=false) -> PhysicsBody3D:
 var body: PhysicsBody3D
 if deck:
  var moving:=AnimatableBody3D.new();moving.sync_to_physics=false;body=moving
 else:body=StaticBody3D.new()
 body.name=label;body.position=at;body.collision_layer=1;body.collision_mask=3;body.add_to_group("harbor_public_prop")
 body.set_meta("visible_source",label);body.set_meta("rest_center",at)
 var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);add_child(body);blockers.append(body)
 if deck:
  body.add_to_group("harbor_public_deck_prop");deck_blockers.append(body);_deck_rest.append(body.global_transform)
 return body
func _box(label: String,at: Vector3,size_: Vector3,deck: bool=false) -> void:
 var shape:=BoxShape3D.new();shape.size=size_;_body(label,at,shape,deck)
func _round(label: String,at: Vector3,radius: float,height: float,deck: bool=false) -> void:
 var shape:=CylinderShape3D.new();shape.radius=radius;shape.height=height;_body(label,at,shape,deck)
func _quay() -> void:
 var index:=0
 for x in [-12.0,-6.0,0.0,4.5,12.0,19.0]:
  _round("QuayBollardStem"+str(index),Vector3(x,.26,2.1),.16,.55)
  _box("QuayBollardHorn"+str(index),Vector3(x,.49,2.1),Vector3(.52,.12,.19));index+=1
func _pier() -> void:
 var index:=0
 for at in [Vector3(9,0,3.4),Vector3(15,0,4.1),Vector3(17,0,3.0)]:
  _box("QuayCrate"+str(index),at+Vector3.UP*.4,Vector3(.9,.8,.8));index+=1
 index=0
 for x in [5.1,8.9]:
  for z in [1.9,-.2,-2.4]:
   _round("PierSupportPost"+str(index),Vector3(x,-.4,z),.12,1.8);index+=1
func _deck() -> void:
 var deck: float=world.ship.position.y+2.865
 var index:=0
 _round("DepartureSupplyBarrel",Vector3(16.6,deck+.33,-7.5),.28,.66,true)
 index=0
 for mast in [[-3.5,13.0],[5.2,10.0]]:
  var height: float=mast[1]-2.8
  var at: Vector3=world.ship.position+Vector3(mast[0],(mast[1]+2.8)*.5,0)
  _round("DepartureMast"+str(index),at,.17,height,true);index+=1
func tick() -> void:
 if not is_instance_valid(world) or not is_instance_valid(world.ship):return
 var motion: Transform3D=world.ship.global_transform*world.ship.visual_root.transform*world.ship.global_transform.affine_inverse()
 for i in deck_blockers.size():deck_blockers[i].global_transform=motion*_deck_rest[i]
