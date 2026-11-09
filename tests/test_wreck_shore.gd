extends SceneTree
var g
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func advance(seconds: float) -> void:
 while seconds>.000001:
  var dt:=minf(seconds,1.0/120);g.tick(dt);seconds-=dt
func run() -> void:
 check(ResourceLoader.exists("res://scripts/wreck_shore.gd"),"opening coast exists")
 if not failures.is_empty():finish();return
 g=load("res://scenes/game.tscn").instantiate();g.loadout.save_path="";root.add_child(g);g.set_physics_process(false)
 g.start_wreck_shore();await physics_frame;await physics_frame
 check(g.encounter_mode=="wreck_shore" and not g.arena.intro_done(),"wash intro starts")
 var start: Vector3=g.player.position;g.move_input=Vector2.RIGHT;advance(1)
 check(g.player.position.distance_to(start)>.5 and g.player.position.x<8,"wave carries instead of movement input")
 check(not g.request_attack() and not g.request_dodge(Vector3.RIGHT),"intro controls locked")
 var age: float=g.arena.intro_age;g.toggle_pause();advance(.4);check(g.arena.intro_age==age,"pause freezes opening");g.toggle_pause()
 g.move_input=Vector2.ZERO;advance(3.3)
 check(g.arena.intro_done() and g.player.position.distance_to(g.arena.landing_point)<.15,"landed and standing")
 check(not g.active_weapon_possible() and not g.avatar.weapon.visible,"opening is unarmed without clearing saved loadout")
 var stream: AudioStreamWAV=g.arena.surge._surf_sound()
 check(stream.mix_rate==11025 and stream.data.size()==132300 and stream.loop_end==66150,"original surf audio stream valid")
 var a: Vector2=g.camera.unproject_position(Vector3(10,0,g.arena.travel_z(10)))
 var b: Vector2=g.camera.unproject_position(Vector3(53,0,g.arena.travel_z(53)))
 check(b.x>a.x and b.y<a.y,"route projects diagonally lower-left to upper-right")
 for x in range(8,63,5):check(g.arena.is_walkable(Vector3(x,.03,g.arena.travel_z(x))),"authored route walkable "+str(x))
 g.set_weapon_family("pistol");g._visual_tick(0);check(not g.pistol_reticle.visible,"unarmed opening suppresses saved-gun reticle");g.set_weapon_family("sword")
 check(g.arena.ship.length_>25 and g.arena.ship.mast_height>12,"large grounded ship")
 g.player.position=Vector3(2,.1,g.arena.travel_z(2));g.move_input=Vector2.LEFT;advance(.6);g.move_input=Vector2.ZERO
 check(g.player.position.x>1,"west rock boundary blocks backtracking")
 g.player.position=g.arena.landing_point
 for step in 2700:
  var target_x:=minf(62.0,g.player.position.x+1)
  var target:=Vector3(target_x,.03,g.arena.travel_z(target_x))
  var direction: Vector3=target-g.player.position;direction.y=0;direction=direction.normalized();g.move_input=Vector2(direction.x,direction.z);g.tick(1.0/120)
  if g.mode=="shore_end":break
 g.move_input=Vector2.ZERO
 check(g.arena.reveal_seen,"wreck vista crossed before exit")
 check(g.mode=="shore_end" and g.arena.exit_reached,"forest entrance ends coastal area")
 check(g.ui.overlay.visible and g.ui.title.text.contains("ป่า"),"specific forest arrival screen")
 g.restart();check(g.encounter_mode=="wreck_shore" and not g.arena.intro_done(),"T replays opening")
 g.arena.skip_intro();advance(.02);check(g.arena.intro_done(),"skip sets landed state")
 g.start_coast_forms();check(g.arena.FORMS.size()==5,"v72 retained")
 g.start_spitter_trial();check(g.active_weapon_possible() and g.ui.header_panel.visible and g.vision.fog.visible,"combat controls/view restored")
 g.set_weapon_family("pistol");g._visual_tick(0);check(g.pistol_reticle.visible,"gun reticle restored on combat route")
 g.return_menu();check(g.ui.menu_scroll.custom_minimum_size.y<=400,"menu entry accessible with scroll")
 g.free();await process_frame;finish()
func finish() -> void:
 print("WRECK SHORE ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures);quit(0 if failures.is_empty() else 1)

