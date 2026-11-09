extends SceneTree
const PlazaProfile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var g
var output:=""
var failures: Array=[]
var checks:=0
var shots: Array=[]
func _initialize() -> void:
 root.unfocusable=true
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func check(value: bool,label: String) -> void:
 checks+=1
 if not value:failures.append(label);printerr("FAIL: ",label)
func advance(seconds: float) -> void:
 while seconds>.0001:
  await process_frame;var dt:=minf(seconds,1.0/60);g.tick(dt);seconds-=dt
func shot(label: String) -> void:
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output+"/"+label+".png")==OK,"capture "+label);shots.append(label)
func click(control: Control) -> void:
 var at:=control.get_global_rect().get_center()
 var move:=InputEventMouseMotion.new();move.position=at;root.push_input(move,true)
 var event:=InputEventMouseButton.new();event.position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;root.push_input(event,true);Input.flush_buffered_events();await process_frame
 event.pressed=false;root.push_input(event,true);Input.flush_buffered_events();await process_frame
func key(code: int) -> void:
 var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true;root.push_input(event,true);Input.flush_buffered_events();await process_frame
 event.pressed=false;root.push_input(event,true);Input.flush_buffered_events();await process_frame
func release_walk() -> void:
 for key in ["harbor_left","harbor_right","harbor_up","harbor_down"]:Input.action_release(key)
func walk_to(target: Vector3) -> bool:
 # Solid residents occupy the old straight porter lane. Take the ordinary
 # public-side bypass in both directions, retaining every route landmark.
 if g.walker.position.distance_to(PlazaProfile.CAFE)<.65 and target.z>PlazaProfile.CAFE.z+1.5:
  if not await _walk_direct(PlazaProfile.CAFE+Vector3(0,0,1.7)):return false
 var from: Vector3=g.walker.position
 if absf(from.z-11.6)<.5 and absf(target.z-11.6)<.1 and absf(target.x-from.x)>4:
  if not await _walk_direct(Vector3(from.x,.055,13.2)):return false
  if not await _walk_direct(Vector3(target.x,.055,13.2)):return false
 return await _walk_direct(target)
func _walk_direct(target: Vector3) -> bool:
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
  await physics_frame;g.tick(1.0/Engine.physics_ticks_per_second)
 release_walk();print("WALK STOP ",g.walker.position," target ",target);return false
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000));DirAccess.make_dir_recursive_absolute(output)
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false);await advance(1)
 await shot("01-lighthouse-title")
 check(g.world.townspeople.size()==8 and g.world.crew.size()==4 and g.world.pigeons.size()==6,"living harbor population counts")
 var looks: Dictionary={};var face_bases: Dictionary={};var hats:=0;var profiles: Array=[]
 for npc in g.world.townspeople+g.world.crew:
  looks[npc.profile.get("hairstyle",-1)]=true;face_bases[npc.profile.get("male",false)]=true
  if npc.profile.get("cap",true):hats+=1
  profiles.append(npc.profile)
 check(looks.size()==10 and not looks.has(-1),"ten approved hairstyles rendered in live population")
 check(face_bases.size()==2,"both approved face bases rendered")
 check(hats==0,"no hats obscure live hairstyles")
 var appearance_file:=FileAccess.open(output+"/npc-profiles.json",FileAccess.WRITE)
 appearance_file.store_string(JSON.stringify(profiles,"  "));appearance_file.close()
 check(get_nodes_in_group("harbor_staff_barrier").size()>=4,"visible staff area has real collision")
 var saved_positions: Array=[]
 for npc in g.world.townspeople+g.world.crew:saved_positions.append(npc.position)
 await advance(3)
 var moved:=0;var index:=0
 for npc in g.world.townspeople+g.world.crew:
  if npc.position.distance_to(saved_positions[index])>.1:moved+=1
  index+=1
 check(moved>=3,"real rendered workers move over time")
 for npc in g.world.crew:check(absf(npc.position.y-(g.world.ship.position.y+2.865))<.001,"rendered crew grounded on deck")

 check(not g.ui.start_button.disabled and g.ui.continue_button.disabled,"honest art-stage menu")
 var hero: Vector2=g.camera.unproject_position(g.world.lighthouse.global_position+Vector3.UP*19.5)
 check(g.camera.is_position_behind(g.world.lighthouse.global_position+Vector3.UP*19.5) or not Rect2(Vector2.ZERO,Vector2(root.size)).has_point(hero),"sea-only title hides lighthouse geometrically")
 check(g.ui.menu.get_global_rect().position.x>root.get_visible_rect().size.x*.58,"menu on right")
 await click(g.ui.settings_button);check(g.ui.settings.visible,"real click opens settings");await shot("02-settings")
 await key(KEY_LEFT);check(absf(g.audio.volume-.60)<.001,"real keyboard adjusts ambient volume")
 await key(KEY_2);check(g.ui.settings.visible and g.camera.view_id==&"lighthouse","modal blocks scene-preview shortcuts")
 g.ui.volume_slider.value=.25;check(absf(g.audio.volume-.25)<.001,"volume slider controls actual stream")
 await click(g.ui.mute_button);check(g.audio.muted and g.audio.sound.stream_paused,"mute pauses ambient sound")
 for i in 8:
  await key(KEY_TAB)
  var owner: Control=root.gui_get_focus_owner()
  check(owner!=null and g.ui.settings.is_ancestor_of(owner),"settings Tab focus stays modal "+str(i))
 for code in [KEY_RIGHT,KEY_LEFT]:
  await key(code)
  var owner: Control=root.gui_get_focus_owner()
  check(owner!=null and g.ui.settings.is_ancestor_of(owner),"settings horizontal focus stays modal "+str(code))
 await key(KEY_ESCAPE);check(not g.ui.settings.visible,"Escape closes settings")
 await click(g.ui.start_button);check(g.phase==&"flyin" and not g.ui.menu.visible,"real Start begins cinematic")
 await advance(2);await shot("11-lighthouse-reveal")
 await advance(4);await shot("12-flyin-approach")
 await advance(2.1);check(g.world.arrival.docked,"arriving vessel reaches real berth");await shot("20-arrival-docked")
 await advance(3);await shot("21-city-pullback")
 await advance(3);await shot("13-coffee-line");check(g.phase==&"line","camera reaches seated line")
 await advance(2.5);await shot("14-rising")
 await advance(.6);check(g.phase==&"play" and g.walker!=null,"rise releases actual walking controller");await shot("15-walking-ready")
 var initial_player: Vector3=g.walker.position
 Input.action_press("harbor_down")
 for i in 60:await physics_frame;g.tick(1.0/120)
 Input.action_release("harbor_down")
 check(g.walker.position.distance_to(initial_player)>.3,"real input moves physical player");await shot("16-walked")
 for point in PlazaProfile.WALK_ROUTE:
  check(await walk_to(point),"native physical route "+str(point))
 check(g.walker.position.y>2.2,"native walker stands on actual deck");await shot("17-player-aboard")
 await key(KEY_ESCAPE);check(g.phase==&"title" and g.walker==null and g.world.hero.visible,"Escape restores repeatable lighthouse menu")
 await click(g.ui.views[&"market"]);await advance(1);check(g.camera.view_id==&"market" and not g.ui.menu.visible,"market inspection control");await shot("03-market")
 await key(KEY_3);await advance(1);check(g.camera.view_id==&"quay","quay keyboard view");await shot("04-departure-ship")
 await advance(3);await shot("09-crew-at-work")
 await key(KEY_4);await advance(1);check(g.camera.view_id==&"port","fourth inspection camera reaches port district")
 check(g.world.backdrop.district.berths.size()==5 and g.world.backdrop.district.workers.size()>=20,"live backdrop has working berths and human cast")
 await shot("18-working-port");await advance(8);await shot("19-port-workers")
 for i in 3600:g.tick(1.0/30)
 check(g.world.backdrop.district.deliveries>=2,"ship unloading delivers cargo into visible shore piles")
 check(g.world.backdrop.district.arrival_ready,"unloading begins after vessel docking")
 await shot("22-cargo-delivered")
 await click(g.ui.back_button);await advance(1);check(g.ui.menu.visible,"return lighthouse view")
 root.content_scale_size=Vector2i(1024,640);root.size=Vector2i(1024,640);await advance(.3);await shot("05-small-window")
 var bounds:=Rect2(Vector2.ZERO,Vector2(1024,640))
 for control in [g.ui.menu,g.ui.start_button,g.ui.continue_button,g.ui.settings_button,g.ui.exit_button,g.ui.legacy_button]:check(bounds.encloses(control.get_global_rect()),"small-window menu in bounds "+str(control.text if control is Button else "panel"))
 await click(g.ui.settings_button);await shot("06-small-settings");check(bounds.encloses(g.ui.settings.get_global_rect()),"small settings in viewport");await key(KEY_ESCAPE)
 root.content_scale_size=Vector2i(1280,800);root.size=Vector2i(1280,800);await advance(.2)
 var sheet:=Image.create(128*6,128*2,false,Image.FORMAT_RGBA8);sheet.fill(Color("dfd7bd"));var n:=0
 for npc in g.world.townspeople+g.world.crew:
  var texture=load("res://scripts/opening/harbor_human_art.gd").frame(npc.profile,"front","idle",0)
  sheet.blit_rect(texture.get_image(),Rect2i(0,0,128,128),Vector2i((n%6)*128,(n/6)*128));n+=1
 check(sheet.save_png(output+"/10-human-variants.png")==OK,"human variant contact sheet")
 Engine.set_meta("harbor_native_qa",true)
 await click(g.ui.legacy_button);await process_frame;await process_frame
 check(current_scene.get_script().resource_path.ends_with("legacy_entry.gd"),"actual legacy menu switch")
 g=current_scene.game;g.set_physics_process(false)
 check(g.loadout.save_path=="","legacy QA never writes real equipment save")
 g.start_wreck_shore();await advance(.1);await shot("07-legacy-wreck-access")
 await key(KEY_F10);await process_frame;await process_frame
 g=current_scene;g.set_process(false);await advance(.3)
 check(g.get_script().resource_path.ends_with("harbor_game.gd") and g.ui.menu.visible,"F10 returns actual harbor scene")
 Engine.remove_meta("harbor_native_qa");await shot("08-return-to-lighthouse")
 g.audio.set_muted(true)
 g.ui.exit_button.pressed.connect(finish)
 await click(g.ui.exit_button)
func finish() -> void:
 check(g.closing and g.audio.sound.stream==null,"actual Exit drains ambient stream before shutdown")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":shots,"geometry":g.world.geometry_count,"scope":"v85 relocated cafe/plaza/fountain/people and actual full walking route; original sea-only ship opening, v84 hull/swell/water and v83 sky/reveal/masonry inherited; lighthouse title/fly-in/rise/walking; seeded NPC appearance; Living harbor8townspeople/4crew/6pigeons; rendered movement and deck anchoring, existing UI/resize/legacy/F10/Exit; cosmetic routes only, no boarding story/dialogue tree/continue save; saves disabled"},"\t"));file.close()
 print("HARBOR ART ",checks," checks;",shots.size()," images; failures=",failures)
