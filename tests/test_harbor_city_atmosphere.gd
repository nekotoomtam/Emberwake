extends SceneTree
var g
var checks:=0
var failures: Array=[]
func _initialize() -> void:
 root.unfocusable=true;call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func property_exists(object: Object,key: String) -> bool:
 for property in object.get_property_list():
  if property.name==key:return true
 return false
func finish() -> void:
 if g!=null:
  g.audio.shutdown();await create_timer(.25).timeout;g.free();await process_frame
 print("CITY ATMOSPHERE ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func run() -> void:
 var declared=load("res://scripts/opening/harbor_world.gd").new()
 var available:=property_exists(declared,"city_continuation") and property_exists(declared,"chimney_smoke");declared.free()
 check(available,"actual harbor world owns fixed gap-filling city scenery and chimney smoke")
 if not available:finish();return
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 var city=g.world.city_continuation;var smoke=g.world.chimney_smoke
 var has_gpu:=DisplayServer.get_name()!="headless"
 check(city.layers.size()>0 and city.build_errors.is_empty(),"original city artwork loads into the real gap-filling scenery")
 var original_resources:=true;var frozen: Array=[]
 for layer in city.layers:
  original_resources=original_resources and g.world.city_matte.materials.has(layer.material_override) and not layer.material_override.no_depth_test
  frozen.append([layer.get_instance_id(),layer.transform,layer.mesh.get_instance_id()])
 check(original_resources,"continuation reuses original aspect-cropped city materials with normal 3D depth")
 check(city.find_children("*","CollisionObject3D",true,false).is_empty() and smoke.find_children("*","CollisionObject3D",true,false).is_empty(),"background and smoke add no physical blockers")
 check(smoke.sources.size()>=12 and smoke.batch.multimesh.instance_count==smoke.sources.size()*smoke.PUFFS_PER_CHIMNEY,"bounded prewarmed smoke is attached to multiple actual rooftops")
 var outlets: Array=g.world.backdrop.chimney_outlets+g.world.hybrid_waterfront.chimney_outlets
 var real_outlets:=true
 for source in smoke.sources:real_outlets=real_outlets and outlets.has(source)
 check(real_outlets,"every emitter starts at a chimney outlet published by the rendered building owner")
 check(smoke.material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and not smoke.material.no_depth_test and smoke.batch.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"smoke blends softly, respects solid depth and casts no square shadows")
 g.world.tick(0,g.camera)
 var first: Transform3D=smoke.batch.multimesh.get_instance_transform(0)
 var mesh_id: int=smoke.batch.multimesh.get_instance_id()
 g.tick(1)
 if has_gpu:check(not smoke.batch.multimesh.get_instance_transform(0).is_equal_approx(first),"the actual world clock moves the retained smoke puffs")
 check(smoke.batch.multimesh.get_instance_id()==mesh_id,"animated smoke reuses its existing GPU batch")
 g.ui.start_button.pressed.emit();g.tick(12)
 g.ui.open_settings();var paused: Transform3D=smoke.batch.multimesh.get_instance_transform(0);g.tick(2)
 if has_gpu:check(smoke.batch.multimesh.get_instance_transform(0).is_equal_approx(paused),"settings pause smoke with the rest of the opening")
 g.ui.close_settings();g.tick(.1)
 if has_gpu:check(not smoke.batch.multimesh.get_instance_transform(0).is_equal_approx(paused),"closing settings resumes the same plume")
 var after: Array=[]
 for layer in city.layers:after.append([layer.get_instance_id(),layer.transform,layer.mesh.get_instance_id()])
 check(after==frozen,"city pictures stay fixed in the world during the camera pan")
 g.skip_arrival();check(g.phase==&"play" and g.walker!=null,"atmosphere additions preserve the actual playable handoff")
 finish()
