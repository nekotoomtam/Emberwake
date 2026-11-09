extends Node3D
## Four private departure-side residents. World/forecourt calls this owner once.
const SeatedActor=preload("res://scripts/opening/harbor_bench_actor.gd")
const StandingActor=preload("res://scripts/opening/harbor_passenger_actor.gd")
var materials: Dictionary={}
var props: Node3D
var actors: Array=[]
var seated: Node3D
var watcher: Node3D
var reader: Node3D
var porter: Node3D
var geometry_count:=0
func _standing(label: String,at: Vector3,role_: String,profile_: Dictionary,phase_: float) -> Node3D:
 var actor=StandingActor.new();actor.name=label;actor.profile=profile_.duplicate(true);actor.profile.id=label;actor.role=role_;actor.position=at;actor.phase=phase_
 if role_=="porter":
  actor.route.assign([Vector3(-1.16,.055,3.92),Vector3(-1.16,.055,4.72),Vector3(-1.16,.055,5.08),Vector3(-1.16,.055,4.72)])
  actor.speed=.28
 add_child(actor);actors.append(actor);geometry_count+=2;return actor
func _ready() -> void:
 set_process(false);set_physics_process(false)
 seated=SeatedActor.new();seated.name="ForecourtSeatedTraveller"
 seated.profile={"id":"ForecourtSeatedTraveller","male":true,"hairstyle":2,"hair":"675447","skin":"dcae8c","coat":"687f83","pants":"515d68","boots":"3b414a","scarf":"dac8a7","waistcoat":true}
 seated.position=props.bench_anchor if is_instance_valid(props) else Vector3(-12.7,.055,3.9)
 seated.phase=1.3;add_child(seated);actors.append(seated);geometry_count+=seated.geometry_count
 watcher=_standing("ForecourtSeaCompanion",Vector3(-15.4,.055,3.35),"watcher",{"male":false,"hairstyle":8,"hair":"554b45","skin":"f1c3aa","coat":"a47976","scarf":"e0ceb0","cap":false},.6)
 reader=_standing("ForecourtTicketReader",Vector3(-7.8,.055,5.10),"ticket",{"male":false,"hairstyle":4,"hair":"ad8c68","skin":"b77e60","coat":"75846f","scarf":"dcc8a7","cap":false},0.0)
 porter=_standing("ForecourtLuggagePorter",Vector3(-1.16,.055,3.92),"porter",{"male":true,"hairstyle":0,"hair":"594c43","skin":"c38c70","coat":"587e82","scarf":"d4c29e","cap":false},2.4)
func tick(delta: float,camera: Camera3D,clock: float) -> void:
 for actor in actors:actor.tick(delta,camera,clock)
