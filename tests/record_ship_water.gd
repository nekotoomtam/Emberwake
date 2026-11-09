extends SceneTree
var game
func _initialize() -> void:root.unfocusable=true;call_deferred("run")
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 game=load("res://scenes/prologue.tscn").instantiate();root.add_child(game);current_scene=game;game.set_process(false);game.ui.start_button.pressed.emit()
 for i in 48:game.tick(1.0/30)
 for i in 120:
  game.tick(1.0/30)
  if i<60:
   game.camera.position=game.world.arrival.position+Vector3(-20,12,28)
   game.camera.look_at(game.world.arrival.position+Vector3(0,2.0,0));game.camera.fov=50
  else:
   var bow: Vector3=game.world.arrival.water_contact.to_global(Vector3(11.1,.1,1.4))
   game.camera.position=bow+Vector3(-8,5.3,10);game.camera.look_at(bow+Vector3(0,.4,0));game.camera.fov=45
  await process_frame
 game.audio.shutdown();game.free();await process_frame;quit()
