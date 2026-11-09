extends SceneTree
const PlazaProfile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var failures: Array=[]
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
 checks+=1
 if not value:failures.append(label);printerr("FAIL: ",label)
func release_walk() -> void:
 for key in ["harbor_left","harbor_right","harbor_up","harbor_down"]:Input.action_release(key)
func walk_to(g,target: Vector3) -> bool:
 # Solid residents occupy the old straight porter lane. Take the ordinary
 # public-side bypass in both directions, retaining every route landmark.
 var from: Vector3=g.walker.position
 if absf(from.z-11.6)<.5 and absf(target.z-11.6)<.1 and absf(target.x-from.x)>4:
  if not await _walk_direct(g,Vector3(from.x,.055,13.2)):return false
  if not await _walk_direct(g,Vector3(target.x,.055,13.2)):return false
 return await _walk_direct(g,target)
func _walk_direct(g,target: Vector3) -> bool:
 for i in Engine.physics_ticks_per_second*10:
  var delta: Vector3=target-g.walker.position;delta.y=0
  if delta.length()<.18:release_walk();return true
  var direction: Vector3=delta.normalized()
  var right:=Vector3(g.camera.global_basis.x.x,0,g.camera.global_basis.x.z).normalized()
  var toward:=Vector3(g.camera.global_basis.z.x,0,g.camera.global_basis.z.z).normalized()
  var x: float=direction.dot(right);var y: float=direction.dot(toward)
  release_walk()
  Input.action_press("harbor_right" if x>=0 else "harbor_left",absf(x))
  Input.action_press("harbor_down" if y>=0 else "harbor_up",absf(y))
  await physics_frame
 release_walk();print("WALK STOP ",g.walker.position," target ",target);return false
func run() -> void:
 var g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);g.set_process(false)
 check(g.camera.view_id==&"lighthouse","sea approach title uses the retained camera preset id")
 check(not g.ui.start_button.disabled,"Start available")
 check(g.world.get_node_or_null("HarborLighthouse")!=null,"real lighthouse landmark")
 check(g.world.get_node_or_null("CoastalTownBackdrop")!=null,"coastal town backdrop")
 check(g.world.get_node_or_null("OpenSea")!=null,"open sea replaces green island horizon")
 check(g.has_method("start_arrival"),"Start has opening controller")
 if g.has_method("start_arrival"):
  var profiles: Array=[]
  for npc in g.world.townspeople+g.world.crew:profiles.append(npc.profile.duplicate(true))
  var origin: Transform3D=g.camera.transform
  g.ui.start_button.pressed.emit()
  check(g.phase==&"flyin" and not g.ui.menu.visible,"Start runs fly-in and hides menu")
  for i in 180:g.tick(1.0/60)
  check(g.camera.transform.origin.distance_to(origin.origin)>2,"camera travels from the approaching ship")
  check(g.phase==&"flyin","fly-in not an instant camera cut")
  for i in ceili((g.camera.intro_duration-3+.1)*60):g.tick(1.0/60)
  check(g.phase==&"line","arrives at seated protagonist with spoken line")
  check(g.camera.view_id==&"cafe","fly-in lands at cafe")
  for i in 220:g.tick(1.0/60)
  check(g.phase==&"play" and g.walker!=null,"protagonist rises into controllable actor")
  check(not g.world.hero.visible,"seated sprite hidden after standing")
  check(g.walker is CharacterBody3D,"walk uses physical character collision")
  var before: Vector3=g.walker.position
  Input.action_press("harbor_down")
  for i in 50:await physics_frame
  Input.action_release("harbor_down")
  check(g.walker.position.distance_to(before)>.3,"WASD action moves actual character")
  check(g.walker.position.y>-.1,"walker stays on quay floor")
  await physics_frame;await physics_frame;g.tick(.016)
  var frames: SpriteFrames=load("res://scripts/hero_directions.gd").frames(g.walker.facing)
  var idle_index: int=int(g.walker.clock*2)%frames.get_frame_count("idle")
  var idle: Image=load("res://scripts/opening/harbor_travel_luggage.gd").carry_texture(g.walker.facing,"idle",idle_index).get_image() if g.walker.carrying_luggage else frames.get_frame_texture("idle",idle_index).get_image()
  check(g.walker.art_action=="idle" and g.walker.sprite.texture.get_image().get_data()==idle.get_data(),"stationary actor uses its idle gripping pose despite downward floor velocity")
  for point in PlazaProfile.WALK_ROUTE:check(await walk_to(g,point),"actual plaza-to-ship route "+str(point))
  check(g.walker.position.y>2.2,"walkable ship deck matches visible deck height")
  g.walker.position=Vector3(13.95,.20,-2.5);g.walker.velocity=Vector3.ZERO
  for i in 5:await physics_frame
  var escaped: bool=await walk_to(g,Vector3(13.95,.15,-4.8))
  check(not escaped and g.walker.position.z>-3.0,"cannot walk into unsupported sea beside gangway")
  check(g.walker.position.y>.10,"pier edge retains a grounded position instead of floating under ship")
  g.return_title()
  check(g.phase==&"title" and g.walker==null and g.world.hero.visible,"return resets seated title without duplicate player")
  check(g.camera.view_id==&"lighthouse" and g.ui.menu.visible,"title restores lighthouse menu")
  var people: Array=g.world.townspeople+g.world.crew
  for i in people.size():check(people[i].profile==profiles[i],"NPC identity survives intro "+people[i].name)
  g.start_arrival()
  g.skip_arrival()
  check(g.phase==&"play","Space skip has stable playable destination")
 g.free();await process_frame
 print("LIGHTHOUSE ARRIVAL ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
