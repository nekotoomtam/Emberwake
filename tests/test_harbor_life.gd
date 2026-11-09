extends SceneTree
var g
var probe: CharacterBody3D
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func move_for(direction: Vector3,seconds: float) -> void:
 for i in ceili(seconds*Engine.physics_ticks_per_second):
  await physics_frame;probe.velocity=direction*3.2+Vector3.DOWN*6;probe.move_and_slide()
func walk_to(target: Vector3) -> bool:
 # The porter now has a real footprint. Walk the public side of its lane,
 # retaining the original journey endpoints and all native collision checks.
 var from: Vector3=probe.position
 if absf(from.z-11.6)<.5 and absf(target.z-11.6)<.1 and absf(target.x-from.x)>4:
  if not await _walk_direct(Vector3(from.x,.08,13.2)):return false
  if not await _walk_direct(Vector3(target.x,.08,13.2)):return false
 return await _walk_direct(target)
func _walk_direct(target: Vector3) -> bool:
 for i in Engine.physics_ticks_per_second*10:
  await physics_frame
  var direction:=target-probe.position;direction.y=0
  if direction.length()<.16:return true
  probe.velocity=direction.normalized()*3.2+Vector3.DOWN*6;probe.move_and_slide()
 print("PROBE STOP ",probe.position," target ",target," physics_hz ",Engine.physics_ticks_per_second)
 return false
func run() -> void:
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false);await physics_frame;await physics_frame
 check(g.world.get("townspeople")!=null,"townspeople exist")
 check(g.world.get("crew")!=null,"crew preparing ship")
 check(g.world.get("pigeons")!=null,"pigeons at harbor")
 check(get_nodes_in_group("harbor_staff_barrier").size()>=4,"visible service-yard barriers registered")
 if g.world.get("townspeople")!=null:
  check(g.world.townspeople.size()==8 and g.world.crew.size()==4 and g.world.pigeons.size()==6,"bounded living population")
  var hero_before: PackedByteArray=g.world.hero.texture.get_image().get_data();var movers:=0
  var positions: Array=[]
  for npc in g.world.townspeople+g.world.crew:positions.append(npc.position)
  for i in 240:g.tick(1.0/60)
  var index:=0
  for npc in g.world.townspeople+g.world.crew:
   if npc.position.distance_to(positions[index])>.1:movers+=1
   index+=1
  check(movers>=3,"workers visibly move along authored routes")
  check(hero_before==g.world.hero.texture.get_image().get_data(),"civilian generation preserves protagonist pixels")
  var art=load("res://scripts/opening/harbor_human_art.gd");var profile: Dictionary=g.world.townspeople[0].profile.duplicate();var original: PackedByteArray=art.frame(profile,"front","idle",0).get_image().get_data();profile.coat="b45c5a"
  check(original!=art.frame(profile,"front","idle",0).get_image().get_data(),"appearance cache respects changed clothes with same role id")

  var grounded_birds:=0;var bird_feet_ok:=true
  for bird in g.world.pigeons:
   if bird.flight>.01:continue
   grounded_birds+=1
   var image: Image=bird.sprite.texture.get_image();var baseline: float=(float(image.get_used_rect().end.y)-image.get_height()*.5)*bird.sprite.pixel_size
   var foot: Vector3=bird.sprite.global_position-g.camera.global_basis.y*baseline
   if foot.distance_to(bird.global_position)>.02:bird_feet_ok=false
  check(grounded_birds>0 and bird_feet_ok,"pigeon visible foot pixels rest on ground")
  for npc in g.world.crew:check(absf(npc.position.y-(g.world.ship.position.y+2.865))<.001,"crew feet anchored to actual deck")
  probe=CharacterBody3D.new();probe.collision_layer=2;probe.collision_mask=1;var col:=CollisionShape3D.new();var cap:=CapsuleShape3D.new();cap.radius=.28;cap.height=1.4;col.shape=cap;col.position.y=.7;probe.add_child(col);root.add_child(probe)
  probe.position=Vector3(-1.5,.08,5.5);await move_for(Vector3.RIGHT,1.4);check(probe.position.x<-.5,"cannot walk behind stalls through service-yard side")
  probe.position=Vector3(3.7,.08,11.5);await move_for(Vector3.FORWARD,1.4);check(probe.position.z>10.1,"cannot enter through gaps between counters")
  probe.position=Vector3(-2.0,.08,5.5)
  check(await walk_to(Vector3(-1.8,.08,11.6)),"coffee to front market route")
  check(await walk_to(Vector3(13.5,.08,11.6)),"front market route remains clear")
  check(await walk_to(Vector3(13.5,.08,3)),"right quay approach remains clear")
  probe.free()
 g.free();await process_frame;print("HARBOR LIFE ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)
