extends Node3D
const Cluster=preload("res://scripts/opening/harbor_leaf_cluster.gd")
var garden
var cards: Array[MeshInstance3D]=[]
var clusters: Array[Node3D]=[]
var old_leaf_meshes: Array[MeshInstance3D]=[]
var crowns: Array[Node3D]=[]
func _ready() -> void:
 name="HarborFullLeafCanopies"
 var mat:=StandardMaterial3D.new()
 mat.albedo_texture=preload("res://assets/foliage/branch-cluster.png")
 mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;mat.alpha_scissor_threshold=.45
 mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.roughness=1
 mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 var mesh:=QuadMesh.new();mesh.size=Vector2(1.65,1.55)
 # Broad overlapping lower tufts, an interior fill and a rounded upper crown.
 var tips: Array[Vector3]=[Vector3(-.90,3.65,.15),Vector3(.90,3.8,-.05),Vector3(-.20,4.45,-.15),Vector3(.35,4.05,.75),Vector3(-.55,4.0,-.75),Vector3(.38,3.38,-.65),Vector3(-.65,3.35,.65),Vector3(0,3.75,0),Vector3(-.75,4.22,.35),Vector3(.75,4.28,.28),Vector3(.1,4.3,-.65),Vector3(-.15,3.3,-.05),Vector3(.15,4.65,.05)]
 for tree_index in garden.trees.size():
  var tree: Node3D=garden.trees[tree_index]
  for child in tree.get_node("TreeGeometry").get_children():
   if child is MeshInstance3D and child.get_active_material(0) in garden.leaf_materials:
    child.hide();old_leaf_meshes.append(child)
  var crown:=Node3D.new();crown.name="HybridFoliage";tree.add_child(crown);crowns.append(crown)
  for i in tips.size():
   var cluster=Cluster.new();cluster.name="LeafCluster"+str(i+1);cluster.position=tips[i]
   if tree_index%2==1:cluster.position.x=-cluster.position.x
   cluster.rotation.y=i*.91+tree_index*.51;cluster.scale=Vector3.ONE*(1.0+.075*sin(i*1.6))
   crown.add_child(cluster);cluster.configure(mat,mesh,i+tree_index*19);clusters.append(cluster);cards.append_array(cluster.cards)
func tick(_delta: float,_camera: Camera3D,time_: float) -> void:
 for cluster in clusters:cluster.set_wind(time_)
