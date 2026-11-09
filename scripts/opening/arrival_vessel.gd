extends Node3D
## Full-size harbor arrival; the root owns when the eight-second approach begins.
const Hull=preload("res://scripts/opening/arrival_hull.gd")
const Crew=preload("res://scripts/opening/arrival_crew.gd")
const Detail=preload("res://scripts/opening/harbor_detail.gd")
const Swell=preload("res://scripts/opening/ship_swell.gd")
const WaterContact=preload("res://scripts/opening/ship_water_contact.gd")
const START_POSITION:=Vector3(88,-.55,-38)
const BERTH_POSITION:=Vector3(12,-.55,-38)
const ARRIVAL_SECONDS:=8.0
const CINEMATIC_SECONDS:=12.0
const OPEN_WATER_START:=Vector3(154,-.55,-38)
const OPEN_WATER_WAIT:=Vector3(124,-.55,-38)
const DECK_HEIGHT:=2.865
var materials: Dictionary={}
var geometry_count:=0
var crew: Array=[]
var progress:=0.0
var docked:=false
var wake_intensity:=0.0
var ship: Node3D
var _started:=false
var _clock:=0.0
var _previewing:=false
var _preview_age:=0.0
var _approach_origin:=START_POSITION
var _approach_seconds:=ARRIVAL_SECONDS
var _entry_slope:=0.0
var motion: Node3D
var water_contact: Node3D

func _ready() -> void:
 name="ArrivingCargoVessel"
 rotation.y=PI
 motion=Node3D.new();motion.name="DeckSwell";add_child(motion)
 ship=Hull.new();ship.name="OriginalScaleArrivalHull";ship.materials=materials;motion.add_child(ship)
 geometry_count=ship.geometry_count
 _deck_crew()
 _cargo_and_tackle()
 water_contact=WaterContact.new();water_contact.hull=ship;water_contact.phase=.7;add_child(water_contact)
 reset_arrival()

func begin_arrival() -> void:
 if docked:return
 _started=true

func begin_open_water_preview() -> void:
 reset_arrival()
 _previewing=true
 position=OPEN_WATER_START
 wake_intensity=.64
 water_contact.cruising=wake_intensity;water_contact.tick(0)

func begin_cinematic_arrival() -> void:
 if _previewing:
  _approach_origin=position
  _approach_seconds=CINEMATIC_SECONDS
  var speed: float=OPEN_WATER_START.distance_to(OPEN_WATER_WAIT)*.075*exp(-_preview_age*.075)
  _entry_slope=speed*_approach_seconds/position.distance_to(BERTH_POSITION)
  _previewing=false
 begin_arrival()

func reset_arrival() -> void:
 progress=0.0;docked=false;_started=false;wake_intensity=0.0
 _previewing=false;_preview_age=0.0;_approach_origin=START_POSITION
 _approach_seconds=ARRIVAL_SECONDS;_entry_slope=0.0
 position=START_POSITION
 rotation.y=PI
 _clock=0.0
 motion.transform=Swell.pose(0)
 water_contact.cruising=0.0;water_contact.phase_clock=0.0;water_contact.intensity=.42;water_contact.tick(0)

func tick(delta: float,camera: Camera3D) -> void:
 var elapsed: float=maxf(delta,0.0)
 _clock+=elapsed
 if _previewing:
  _preview_age+=elapsed
  position=OPEN_WATER_START.lerp(OPEN_WATER_WAIT,1.0-exp(-_preview_age*.075))
 elif _started and not docked:
  progress=minf(1.0,progress+elapsed/_approach_seconds)
  if progress>=1.0-.000001:progress=1.0
  var eased: float=progress*progress*(3.0-2.0*progress)
  var inherited: float=_entry_slope*progress*pow(1.0-progress,2.0)
  position=_approach_origin.lerp(BERTH_POSITION,eased+inherited)
  docked=progress>=1.0
  if docked:position=BERTH_POSITION;_started=false
 var target_wake: float=sin(progress*PI)*.75+.25 if _started else 0.0
 if _previewing:target_wake=.64
 wake_intensity=move_toward(wake_intensity,target_wake,elapsed*1.5)
 motion.transform=Swell.pose(_clock,wake_intensity)
 water_contact.cruising=wake_intensity;water_contact.tick(elapsed)
 if not is_instance_valid(camera):return
 for actor in crew:actor.tick(elapsed,camera,_clock)

func _new_crew(profile: Dictionary,path: Array[Vector3],working: bool=true) -> void:
 var actor=Crew.new();actor.name=profile.id;actor.profile=profile
 actor.route=path;actor.work=working;actor.speed=float(profile.get("speed",.75))
 motion.add_child(actor);crew.append(actor)

func _deck_crew() -> void:
 _new_crew({"id":"arrival_porter","hair":"5c4840","skin":"d3a67c","coat":"7b6c52","hat":"c4b58d","cap":false,"male":true,"hairstyle":2,"carry":false,"speed":.85,"phase":0},[Vector3(-4.9,DECK_HEIGHT,-2.0),Vector3(4.3,DECK_HEIGHT,-2.0)])
 _new_crew({"id":"arrival_sweeper","hair":"715841","skin":"e4bc96","coat":"688489","hat":"c4b58d","cap":false,"male":false,"hairstyle":7,"broom":true,"speed":.6,"phase":4},[Vector3(-.9,DECK_HEIGHT,1.65),Vector3(6.9,DECK_HEIGHT,1.65)])
 _new_crew({"id":"arrival_ropehand","hair":"867464","skin":"edc9a6","coat":"536f7b","hat":"d2c7a5","cap":false,"male":true,"hairstyle":4,"beard":true,"phase":6},[Vector3(1.9,DECK_HEIGHT,-3.15)])
 _new_crew({"id":"arrival_mate","hair":"49413e","skin":"d8b28d","coat":"3c596b","hat":"4b5c6c","cap":false,"male":true,"hairstyle":1,"phase":2},[Vector3(9.3,DECK_HEIGHT,-1.35)],false)
 crew[2].aim=Vector3.FORWARD;crew[3].aim=Vector3.RIGHT

func _cargo_and_tackle() -> void:
 var b=Detail.new();b.name="ArrivalDeckCargo";motion.add_child(b)
 b.finish();geometry_count+=b.count

func deck_motion_offset(rest_world_point: Vector3) -> Vector3:
 return deck_visual_transform()*rest_world_point-rest_world_point
func deck_visual_transform() -> Transform3D:
 return global_transform*motion.transform*global_transform.affine_inverse()
