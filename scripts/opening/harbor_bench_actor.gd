extends Node3D
## A complete seated billboard at the normal protagonist's world pixel scale.
## Only the bench-life owner advances gestures and camera registration.
const Art=preload("res://scripts/opening/harbor_bench_art.gd")
const SEAT_HEIGHT:=.4725
const PIXEL_SIZE:=.018
const HIP_PIXEL:=Vector2(64,100)
var profile: Dictionary={}
var phase:=0.0
var tick_count:=0
var pose_index:=0
var action:="bench_rest"
var sprite: Sprite3D
var shadow: MeshInstance3D
var hip_anchor: Marker3D
var knees: Array[Marker3D]=[]
var feet: Array[Marker3D]=[]
var human_blocker: AnimatableBody3D
var geometry_count:=2
func _anchor(label: String) -> Marker3D:
 var result:=Marker3D.new();result.name=label;add_child(result);return result
func _pixel_position(pixel: Vector2) -> Vector3:
 return Vector3((pixel.x-64.0)*PIXEL_SIZE,(64.0-pixel.y)*PIXEL_SIZE,0.0)
func _register_pose(camera_basis: Basis,breath: float) -> void:
 sprite.global_basis=camera_basis.scaled_local(Vector3(1.0,breath,1.0))
 # Transform the actual image hip, rather than treating the image centre as a seat.
 sprite.global_position=hip_anchor.global_position-sprite.global_basis*_pixel_position(HIP_PIXEL)
 for i in 2:
  knees[i].global_position=sprite.global_transform*_pixel_position(Vector2(float([13.5,19.5][i])*4.0,25.5*4.0))
  feet[i].global_position=sprite.global_transform*_pixel_position(Vector2(float([13.5,19.5][i])*4.0,30.0*4.0))
func _ready() -> void:
 set_process(false);set_physics_process(false);set_meta("bench_life_owned",true)
 # Seat front=.19+.05=.24; one centimetre clearance keeps short knees in front
 # of the timber instead of hiding them inside the final seat slat.
 hip_anchor=_anchor("SeatHip");hip_anchor.position=Vector3(0,SEAT_HEIGHT,.25)
 for side in 2:
  knees.append(_anchor("FoldedKnee"));feet.append(_anchor("DanglingBoot"))
 sprite=Sprite3D.new();sprite.name="SeatedResident";sprite.pixel_size=PIXEL_SIZE;sprite.texture=Art.frame(profile,0);sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;sprite.shaded=false;sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;add_child(sprite)
 _register_pose(Basis.IDENTITY,1.0)
 shadow=MeshInstance3D.new();shadow.name="SeatedFootShadow";var disc:=CylinderMesh.new();disc.top_radius=.31;disc.bottom_radius=.31;disc.height=.003;disc.radial_segments=12;shadow.mesh=disc;shadow.position=Vector3(0,.004,.28);shadow.scale.z=.66
 var shade:=StandardMaterial3D.new();shade.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;shade.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;shade.albedo_color=Color(0,.05,.07,.12);shadow.material_override=shade;add_child(shadow)
 # Preserve the normal native human capsule. Existing benches own furniture solids.
 human_blocker=AnimatableBody3D.new();human_blocker.name="SeatedHumanFootprint";human_blocker.sync_to_physics=false;human_blocker.collision_layer=1;human_blocker.collision_mask=3;human_blocker.position.z=.40;human_blocker.add_to_group("harbor_person")
 var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.27;capsule.height=1.4;shape.shape=capsule;shape.position.y=.7;human_blocker.add_child(shape);add_child(human_blocker)
func tick(_delta: float,camera: Camera3D,clock: float) -> void:
 tick_count+=1
 var cycle:=fposmod(clock+phase,14.0)
 pose_index=1 if cycle>=4.0 and cycle<5.5 else 2 if cycle>=9.0 and cycle<10.5 else 0
 action="bench_hand_rest" if pose_index==1 else "bench_glance" if pose_index==2 else "bench_rest"
 sprite.texture=Art.frame(profile,pose_index)
 _register_pose(camera.global_basis,1.0+sin(clock*1.15+phase)*.004)
