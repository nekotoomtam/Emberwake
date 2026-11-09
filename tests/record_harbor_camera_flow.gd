extends SceneTree
## Native MovieWriter records every rendered frame, with no camera pose
## overrides or screenshot waits inside the shot. Silent review footage.
func _initialize() -> void:
 root.unfocusable=true;call_deferred("run")
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 root.size=Vector2i(960,600);root.content_scale_size=root.size
 var game=load("res://scenes/prologue.tscn").instantiate();root.add_child(game);current_scene=game;game.set_process(false)
 await process_frame
 game.ui.start_button.pressed.emit()
 for frame in 960:
  game.tick(1.0/30)
  await process_frame
 game.audio.shutdown();game.free();await process_frame
 quit()
