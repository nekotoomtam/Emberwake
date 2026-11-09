extends "res://scripts/village_study.gd"
var cover_alpha:=1.0
var _inside:=false
var covers: Array[Material]=[]
func _ready() -> void:
 main=Detail.new();front=Detail.new();house_roof=Detail.new()
 for builder in [main,front,house_roof]:add_child(builder)
 _rng.seed=7221;_wood=materials.wood;_stone=materials.stone;_iron=materials.iron
 _house();_track()
 for builder in [front,house_roof]:
  for group in builder.groups.values():
   var material_: StandardMaterial3D=group.material.duplicate();material_.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;group.material=material_;covers.append(material_)
 for builder in [main,front,house_roof]:geometry_count+=builder.count;batch_count+=builder.finish()
func update_player(point: Vector3) -> void:
 var local:=to_local(point);_inside=absf(local.x)<3.55 and local.z< -3.15 and local.z> -8.8
func tick(delta: float) -> void:
 super.tick(delta)
 cover_alpha=move_toward(cover_alpha,0.0 if _inside else 1.0,delta/.5)
 for material_: StandardMaterial3D in covers:material_.albedo_color.a=cover_alpha
 front.visible=cover_alpha>.005;house_roof.visible=cover_alpha>.005
