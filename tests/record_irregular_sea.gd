extends SceneTree
var game
var output:=""
func _initialize() -> void:
 root.unfocusable=true
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 game=load("res://scenes/prologue.tscn").instantiate();root.add_child(game);current_scene=game;game.set_process(false);game.ui.start_button.pressed.emit()
 for i in 66:game.tick(1.0/30)
 var fixed_camera: Transform3D=game.camera.transform;var lens: float=game.camera.fov
 for i in 240:
  game.tick(1.0/30);game.camera.transform=fixed_camera;game.camera.fov=lens
  await process_frame
  if i in [15,19,60,120,180]:
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(output+"/fixed-water-%03d.png"%i)
 var result:=FileAccess.open(output+"/fixed-camera.json",FileAccess.WRITE)
 result.store_string(JSON.stringify({"fixed_camera":true,"frames":240,"camera_right":str(game.camera.global_basis.x),"shoreward_screen_projection":Vector3.LEFT.dot(game.camera.global_basis.x),"scene_clock":game.world.clock},"  "));result.close()
 game.audio.shutdown();game.free();await process_frame;quit()
