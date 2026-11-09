extends Node3D
## Three privately styled residents on existing benches; no new furniture.
const Actor=preload("res://scripts/opening/harbor_bench_actor.gd")
var materials: Dictionary={}
var actors: Array=[]
var couple: Array[Node3D]=[]
var single: Node3D
var seat_positions: Array[Vector3]=[]
var geometry_count:=0
func _resident(label: String,at: Vector3,profile_: Dictionary,phase_: float) -> Node3D:
 var actor=Actor.new();actor.name=label;actor.profile=profile_.duplicate(true);actor.profile.id=label;actor.phase=phase_;actor.position=at;add_child(actor);actors.append(actor);seat_positions.append(actor.hip_anchor.global_position);geometry_count+=actor.geometry_count;return actor
func _ready() -> void:
 set_process(false);set_physics_process(false)
 couple.append(_resident("BenchCompanionMan",Vector3(-36.9,.055,2.5),{"male":true,"hairstyle":2,"hair":"655347","skin":"dcae8c","coat":"667c83","pants":"4f5968","boots":"3c414a","scarf":"d9c6a6","waistcoat":true},0.0))
 couple.append(_resident("BenchCompanionWoman",Vector3(-35.5,.055,2.5),{"male":false,"hairstyle":8,"hair":"554a48","skin":"f1c3aa","coat":"a97978","pants":"626579","boots":"51453f","scarf":"e6d3b6"},2.7))
 single=_resident("BenchHarborReader",Vector3(-28.1,.055,2.5),{"male":false,"hairstyle":4,"hair":"a38867","skin":"b77e60","coat":"788568","pants":"5e6d71","boots":"41474c","scarf":"d4bd8f"},6.1)
func tick(delta: float,camera: Camera3D,clock: float) -> void:
 for actor in actors:actor.tick(delta,camera,clock)

