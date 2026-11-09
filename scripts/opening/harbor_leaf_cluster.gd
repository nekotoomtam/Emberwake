class_name HarborLeafCluster
extends Node3D
## Reusable crossed-branch tuft, placed at native branch tips.
var cards: Array[MeshInstance3D]=[]
var rests: Array[Vector3]=[]
var phase:=0.0
var rest_rotation:=Vector3.ZERO
func configure(material: Material,mesh: Mesh,index: int) -> void:
 phase=index*1.73;rest_rotation=rotation
 for i in 6:
  var card:=MeshInstance3D.new();card.mesh=mesh;card.material_override=material
  card.position=Vector3(.13*cos(i*2.4+phase),.06*sin(i+phase),.13*sin(i*2.4+phase))
  card.rotation=Vector3(.18*sin(i+phase),i*PI/3+phase,.17*cos(i*2.2+phase))
  add_child(card);cards.append(card);rests.append(card.rotation)
func set_wind(time_: float) -> void:
 rotation=rest_rotation+Vector3(.025*sin(time_*.43+phase),.012*sin(time_*.32+phase),.022*sin(time_*.38+phase))
 for i in cards.size():cards[i].rotation=rests[i]+Vector3(.007*sin(time_*.65+phase+i),0,.009*sin(time_*.52+phase+i*.7))
