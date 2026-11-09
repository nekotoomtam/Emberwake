extends Node3D
## Three small departure-side groups, with one owner for their four residents.
const Props=preload("res://scripts/opening/harbor_passenger_props.gd")
const Life=preload("res://scripts/opening/harbor_passenger_life.gd")
var materials: Dictionary={}
var props
var life
var geometry_count:=0
func _ready() -> void:
 name="PassengerDepartureForecourt"
 props=Props.new();props.materials=materials.duplicate();add_child(props)
 life=Life.new();life.materials=materials.duplicate();life.props=props;add_child(life)
 geometry_count=props.geometry_count+life.geometry_count
func tick(delta: float,camera: Camera3D,clock: float) -> void:
 life.tick(delta,camera,clock)
