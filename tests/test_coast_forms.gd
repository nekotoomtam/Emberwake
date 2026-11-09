extends SceneTree
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func run() -> void:
 check(ResourceLoader.exists("res://scripts/coast_forms.gd"),"five-form arena exists")
 if not failures.is_empty():finish();return
 var g=load("res://scenes/game.tscn").instantiate();g.loadout.save_path="";root.add_child(g);g.set_physics_process(false);g.start_coast_forms()
 await physics_frame;await physics_frame
 check(g.encounter_mode=="coast_forms" and g.enemies.is_empty(),"isolated empty visual study")
 check(g.arena.FORMS.size()==5,"five authored forms")
 for index in 5:
  g.jump_coast_form(index);g.tick(.02)
  check(g.arena.form_index(g.player.position.x)==index,"jump form "+str(index))
  check(g.arena.is_walkable(g.player.position),"form route walkable "+str(index))
  var floor_query:=PhysicsRayQueryParameters3D.create(g.player.position+Vector3.UP,g.player.position-Vector3.UP,1)
  check(not g.get_world_3d().direct_space_state.intersect_ray(floor_query).is_empty(),"physical floor "+str(index))
  check(not g.vision.fog.visible and not g.ui.header_panel.visible,"study-only view "+str(index))
 for x in range(1,80):
  var point:=Vector3(x,.03,g.arena.path_center(x)+.8)
  check(g.arena.is_walkable(point),"connected center route "+str(x))
  var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.7,point+Vector3.RIGHT*.3+Vector3.UP*.7,1)
  check(g.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"no hidden center blocker "+str(x))
 # Traverse with the actual movement controller, not only floor rays.
 g.player.position=Vector3(1,.04,g.arena.path_center(1)+.8)
 for step in 2300:
  var target:=Vector3(g.player.position.x+1,.03,g.arena.path_center(g.player.position.x+1)+.8)
  var direction: Vector3=(target-g.player.position);direction.y=0;direction=direction.normalized();g.move_input=Vector2(direction.x,direction.z);g.tick(1.0/120)
  if g.player.position.x>78.5:break
 g.move_input=Vector2.ZERO
 check(g.player.position.x>78.5,"actual controller traverses all five forms x="+str(g.player.position.x))
 for x in [-18.0,100.0]:
  var point:=Vector3(x,1,g.arena.sea_edge(x)-2)
  var ray:=PhysicsRayQueryParameters3D.create(point,point-Vector3.UP*2,1)
  check(not g.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"camera padding hides terrain end "+str(x))
 check(g.arena.geometry_count>1500 and g.arena.batch_count<60,"detailed batched environment")
 var house=g.arena.cottage;var inside: Vector3=house.to_global(Vector3(0,.3,-5))
 house.update_player(inside);house.tick(.25)
 check(house.cover_alpha>0 and house.cover_alpha<1,"interior revealed gradually")
 house.tick(.4);check(house.cover_alpha<.01 and not house.house_roof.visible,"complete interior cutaway")
 house.update_player(house.to_global(Vector3(0,.03,0)));house.tick(.25)
 check(house.cover_alpha>0 and house.cover_alpha<1,"exterior restores gradually")
 house.tick(.4);check(house.house_roof.visible and house.cover_alpha>.99,"roof restored")
 g.restart();check(g.encounter_mode=="coast_forms" and g.enemies.is_empty(),"restart same study")
 g.start_village_study();check(g.encounter_mode=="village_study","v71 study retained")
 g.start_spitter_trial();check(g.vision.fog.visible and g.ui.header_panel.visible,"normal combat restored")
 g.free();await process_frame;finish()
func finish() -> void:
 print("COAST FORMS ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
