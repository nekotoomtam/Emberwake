extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
 check(ResourceLoader.exists("res://scripts/village_study.gd"),"new visual slice exists")
 if not failures.is_empty():finish();return
 var g=load("res://scenes/game.tscn").instantiate();g.loadout.save_path="";root.add_child(g);g.set_physics_process(false)
 check(g.has_method("start_village_study"),"menu route")
 g.start_village_study();await physics_frame;await physics_frame
 check(g.encounter_mode=="village_study" and g.mode=="practice","isolated study mode")
 check(g.enemies.is_empty(),"no automatic enemy during scene review")
 check(not g.ui.header_panel.visible and not g.anatomy_panel.compact.visible,"scene-only HUD declutter")
 check(not g.vision.fog.visible,"full scene visible only in art study")
 check(g.arena.geometry_count>800,"detailed assembled geometry")
 check(g.arena.batch_count<35,"geometry batched into bounded material meshes")
 check(g.arena.materials.size()>=10,"distinct authored wet/wood/stone materials")
 check(g.arena.house_roof.visible,"roof exterior visible")
 var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true;g._unhandled_input(wheel);g.tick(.5)
 check(g.village_zoom==19.5 and g.camera.size<21,"study-only wheel zoom works")
 g.village_zoom=21

 g.player.position=Vector3(0,.3,-5);g.arena.update_player(g.player.position)
 check(not g.arena.house_roof.visible,"roof cutaway inside cottage")
 g.player.position=Vector3(0,.03,4);g.arena.update_player(g.player.position)
 check(g.arena.house_roof.visible,"roof restored outside")
 g.tick(2);check(g.enemies.is_empty(),"study never spawns practice dummy")
 g.restart();check(g.encounter_mode=="village_study","T returns to same study")
 for point in [Vector3(0,.4,5),Vector3(0,.4,2),Vector3(0,.5,0),Vector3(0,.7,-2),Vector3(0,.8,-3.5),Vector3(0,.8,-5)]:
  var query:=PhysicsRayQueryParameters3D.create(point,point-Vector3.UP*2,1)
  check(not g.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"continuous route floor "+str(point))
 var q:=PhysicsRayQueryParameters3D.create(Vector3(-2,1,-2),Vector3(-2,1,-5),1)
 check(not g.get_world_3d().direct_space_state.intersect_ray(q).is_empty(),"front wall has collision")
 q=PhysicsRayQueryParameters3D.create(Vector3(0,1,-2),Vector3(0,1,-5),1)
 check(g.get_world_3d().direct_space_state.intersect_ray(q).is_empty(),"doorway is real opening")
 g.start_spitter_trial();check(g.drill_kind=="spitter" and g.enemies.size()==1 and g.vision.fog.visible,"existing combat trial still works")
 check(g.ui.header_panel.visible and g.anatomy_panel.compact.visible,"normal combat HUD restored")
 g.return_menu();g.free();await process_frame;finish()
func finish() -> void:
 print("VILLAGE ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
