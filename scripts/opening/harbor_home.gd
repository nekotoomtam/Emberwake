extends Node
func _input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F10:
  get_viewport().set_input_as_handled();get_tree().change_scene_to_file("res://scenes/prologue.tscn")
