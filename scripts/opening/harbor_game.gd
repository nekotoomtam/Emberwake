extends Node3D
const SharedSeats=preload("res://modular/scripts/shared_seats.gd")
const CityPose=preload("res://modular/scripts/city_npc_pose.gd")
const World=preload("res://scripts/opening/harbor_world.gd")
const Gangway=preload("res://scripts/opening/harbor_gangway.gd")
const Voyage=preload("res://scripts/opening/expedition_voyage.gd")
const BoardingParty=preload("res://scripts/opening/boarding_party.gd")
var boarding_party
var departing:=false
var _roster_attribute_seed := randi()
var boarding_latched:=false
var boarding_previous_fov:=42.0
var boarding_return: Tween
const Camera=preload("res://scripts/opening/harbor_camera.gd")
const UI=preload("res://scripts/opening/harbor_ui.gd")
const Audio=preload("res://scripts/opening/harbor_audio.gd")
var world
var camera
var ui
var audio
var closing:=false
var phase: StringName=&"title"
var phase_age:=0.0
var walker
var shared_seats
var route_bark_time:=0.0
const WRONG_WAY_LINE:="นั่นไม่ใช่ทางไปที่เรือนะ"
func _ready() -> void:
 DisplayServer.window_set_title("Emberwake — Identical Midship Boarding v115")
 world=preload("res://scenes/opening/harbor_world.tscn").instantiate();add_child(world)
 camera=Camera.new();add_child(camera)
 shared_seats=SharedSeats.new();add_child(shared_seats);shared_seats.bind(world)
 audio=Audio.new();add_child(audio);audio.set_volume(.65)
 ui=UI.new();ui.audio=audio;add_child(ui);ui.view_requested.connect(set_view);ui.legacy_requested.connect(open_legacy);ui.exit_requested.connect(exit_game)
 ui.start_requested.connect(start_arrival);ui.set_view(&"lighthouse")
 ui.appearance_requested.connect(open_appearance_review)
 world.modular_protagonist=true;world.hero.hide()
 world.arrival.begin_open_water_preview()
 camera.frame_open_water(world.arrival.position)
 world.tick(0,camera)
 shared_seats.pose_intro(camera,world)
func _process(delta: float) -> void:tick(delta)
func tick(delta: float) -> void:
 if is_instance_valid(boarding_party):
  if not departing:camera.tick(delta)
  world.tick(delta,camera)
  boarding_party.sync_deck(world,camera)
  return
 if walker!=null:walker.enabled=not ui.settings.visible and shared_seats.seat.is_empty()
 if ui.settings.visible and phase!=&"title":return
 camera.tick(delta);phase_age+=delta
 if phase==&"flyin" and phase_age>=camera.intro_duration:
  phase=&"line";phase_age=0;world.sip_age=4.9;camera.set_view(&"cafe",0);ui.show_caption("ใกล้ถึงเวลาแล้วสินะ…")
 elif phase==&"line" and phase_age>=2.0:
  phase=&"rising";phase_age=0;world.sip_enabled=false;ui.show_caption("")
 elif phase==&"rising":
  var t: float=clampf(phase_age/.85,0,1)
  world.hero_offset=lerpf(1.08,.864,t)
 if phase==&"play" and walker!=null:
  camera.follow_actor(walker.position,delta)
 world.tick(delta,camera)
 if phase==&"title" and camera.view_id==&"lighthouse":
  camera.frame_open_water(world.arrival.position)
 shared_seats.tick(delta,camera,world)
 if phase==&"rising":
  var rise: float=clampf(phase_age/.85,0,1)
  shared_seats.pose_intro(camera,world,rise)
  if phase_age>=.85:_begin_walk()
 elif walker==null:
  shared_seats.pose_intro(camera,world)
 if walker!=null:
  world.plaza.update_departure_chair(walker.position,true)
  var aboard: bool=walker.position.y>2.1 and walker.position.z< -3.8
  var at_landing := aboard and _has_crossed_departure_landing()
  if not at_landing:boarding_latched=false
  if phase==&"play" and at_landing and not boarding_latched:
   _open_boarding_party()
   return
  walker.visual_offset=world.main_ship_offset(walker.position) if aboard else Vector3.ZERO
  var movement: Vector3=walker.velocity;movement.y=0;walker.update_art(0,movement)
  if shared_seats.seat.is_empty():world.plaza.travel_luggage.update_carry(walker,camera)
  if route_bark_time>0:
   route_bark_time=maxf(0,route_bark_time-delta)
   ui.position_actor_bark(camera.unproject_position(walker.global_position+Vector3.UP*2.0))
   if route_bark_time<=0:ui.hide_actor_bark()
func _open_boarding_party() -> void:
 boarding_latched=true
 walker.enabled=false
 walker.hide()
 ui.show_caption("")
 if boarding_return and boarding_return.is_running():boarding_return.kill()
 boarding_previous_fov=camera.fov
 camera.set_view(&"boarding",.95)
 world.set_boarding_crew_only(true)
 boarding_party=BoardingParty.new()
 boarding_party.attribute_seed=_roster_attribute_seed
 add_child(boarding_party)
 boarding_party.sync_deck(world,camera)
 boarding_party.confirmed.connect(_depart_with_party)
 boarding_party.cancelled.connect(_close_boarding_party)

func _close_boarding_party() -> void:
 boarding_party.queue_free()
 boarding_party=null
 world.set_boarding_crew_only(false)
 walker.show()
 walker.enabled=true
 boarding_return=create_tween()
 boarding_return.tween_property(camera,"fov",boarding_previous_fov,.45)
 ui.show_caption("WASD · เดิน    |    E · นั่ง/ลุกใกล้ที่นั่ง    |    F · จิบกาแฟ")

func _depart_with_party(party: Array[Dictionary]) -> void:
 if departing:return
 departing=true
 ui.cinematic(true)
 ui.show_caption("")
 boarding_party.set_departing(true)
 var voyage=Voyage.new()
 get_tree().root.add_child(voyage)
 voyage.run(self,party)

func cancel_departure() -> void:
 departing=false
 world.departure_offset=Vector3.ZERO
 world.departure_heading=0.0
 camera.set_view(&"boarding",.65)
 boarding_party.set_departing(false)

func _has_crossed_departure_landing() -> bool:
 var at: Vector3=walker.position
 var landing: Vector3=Gangway.DEPARTURE_LANDING
 return walker.is_on_floor() and at.y>=landing.y-.10 and at.z<landing.z-.30 and absf(at.x-landing.x)<Gangway.WIDTH*.5
func start_arrival() -> void:
 if phase!=&"title":return
 world.plaza.travel_luggage.reset_resting()
 world.sip_enabled=true;world.sip_age=0;world.backdrop.reset_activity();world.dock_life.reset_activity()
 var from_open_water: bool=camera.view_id==&"lighthouse"
 if not from_open_water:world.arrival.reset_arrival()
 world.arrival.begin_cinematic_arrival()
 camera.start_flyin(from_open_water);phase=&"flyin";phase_age=0;ui.cinematic(true);ui.show_caption("")
func _begin_walk() -> void:
 if walker!=null:return
 phase=&"play";phase_age=0;world.sip_enabled=false;world.hero.visible=false
 shared_seats.player_pose.hide()
 walker=preload("res://scripts/opening/harbor_walker.gd").new();walker.camera=camera;walker.carrying_luggage=true;walker.modular_look=CityPose.player_look();walker.position=world.anchors.cafe+Vector3.UP*.1;add_child(walker)
 world.plaza.travel_luggage.update_carry(walker,camera)
 walker.wrong_way_attempted.connect(_wrong_way)
 ui.show_caption("WASD · เดิน    |    E · นั่ง/ลุกใกล้ที่นั่ง    |    F · จิบกาแฟ")
func _wrong_way() -> void:
 if phase!=&"play" or route_bark_time>0:return
 route_bark_time=3.2;ui.show_actor_bark(WRONG_WAY_LINE,camera.unproject_position(walker.global_position+Vector3.UP*2.0))
func skip_arrival() -> void:
 if phase not in [&"flyin",&"line",&"rising"]:return
 world.arrival.begin_arrival();world.arrival.tick(world.arrival.CINEMATIC_SECONDS,camera);world.backdrop.set_arrival_ready(true)
 camera.set_view(&"cafe",0);world.hero_offset=.864;world.tick(0,camera)
 world.plaza.travel_luggage.update_stand(1,world.hero,camera);_begin_walk()
func return_title() -> void:
 route_bark_time=0;ui.hide_actor_bark()
 shared_seats.release(walker,world)
 world.plaza.update_departure_chair(Vector3.ZERO,false)
 if walker!=null:walker.free();walker=null
 world.plaza.travel_luggage.reset_resting()
 world.sip_enabled=true;world.sip_age=0;world.arrival.begin_open_water_preview();world.backdrop.reset_activity();world.dock_life.reset_activity()
 phase=&"title";phase_age=0;world.hero_offset=1.08
 camera.set_view(&"lighthouse",0);camera.frame_open_water(world.arrival.position);ui.cinematic(false);ui.show_caption("");ui.set_view(&"lighthouse");ui.start_button.grab_focus()
func set_view(id: StringName) -> void:
 if phase!=&"title":return
 if id==&"lighthouse":return_title();return
 if camera.view_id==&"lighthouse":world.arrival.reset_arrival()
 if id==&"port":world.arrival.begin_arrival()
 camera.set_view(id,.85);ui.set_view(id)
func open_legacy() -> void:audio.set_paused(true);get_tree().change_scene_to_file("res://scenes/opening/legacy_entry.tscn")
func open_appearance_review() -> void:
 if phase!=&"title":return
 audio.set_paused(true);get_tree().change_scene_to_file("res://scenes/review/traveler_appearance.tscn")
func exit_game() -> void:
 if closing:return
 closing=true;ui.exit_button.disabled=true;audio.shutdown()
 await get_tree().create_timer(.20).timeout
 get_tree().quit()
func _unhandled_key_input(event: InputEvent) -> void:
 if is_instance_valid(boarding_party):return
 if not event is InputEventKey or not event.pressed or event.echo:return
 if ui.settings.visible and event.physical_keycode!=KEY_ESCAPE:return
 if event.physical_keycode==KEY_SPACE:skip_arrival();return
 if phase==&"play" and walker!=null:
  if event.physical_keycode==KEY_E:
   if shared_seats.toggle_seat(walker,world):
    ui.show_caption("F · จิบกาแฟ    |    E · ลุก" if shared_seats.seat=="cafe" else
      "E · ลุกจากม้านั่ง" if shared_seats.seat=="bench" else
      "WASD · เดิน    |    E · นั่ง/ลุกใกล้ที่นั่ง    |    F · จิบกาแฟ")
   return
  if event.physical_keycode==KEY_F:shared_seats.drink();return
 if phase!=&"title":
  if event.physical_keycode==KEY_ESCAPE:return_title()
  return
 match event.physical_keycode:
  KEY_1:set_view(&"cafe")
  KEY_2:set_view(&"market")
  KEY_3:set_view(&"quay")
  KEY_4:set_view(&"port")
  KEY_5:open_appearance_review()
  KEY_ESCAPE:
   if ui.settings.visible:ui.close_settings()
   else:return_title()
