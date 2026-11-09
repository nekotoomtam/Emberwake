extends SceneTree
## Independent native contracts: private people, original proportions and real contacts.
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:call_deferred("_run")
func _check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);push_error(label)
func _finish() -> void:
 print("HARBOR PASSENGER LIFE v94 ",checks," checks; ","PASS" if failures.is_empty() else "FAIL "+str(failures))
 quit(0 if failures.is_empty() else 1)
func _run() -> void:
 _check(ResourceLoader.exists("res://scripts/opening/harbor_passenger_life.gd"),"passenger life owner exists")
 if not failures.is_empty():_finish();return
 var scene:=Node3D.new();root.add_child(scene)
 var Props=load("res://scripts/opening/harbor_passenger_props.gd")
 var Life=load("res://scripts/opening/harbor_passenger_life.gd")
 var StandingArt=load("res://scripts/opening/harbor_human_art.gd")
 var shared_cache_before: int=StandingArt.cache.size()
 var props=Props.new();scene.add_child(props)
 var life=Life.new();life.props=props;scene.add_child(life)
 var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(-8,7,13);camera.look_at(Vector3(-8,.7,4))
 await process_frame;await physics_frame
 _check(life.actors.size()==4 and life.actors.has(life.seated) and life.actors.has(life.watcher) and life.actors.has(life.reader) and life.actors.has(life.porter),"four named identities are exclusively owned")
 var profiles: Array=[];var ticks: Array=[];var identities: Array=[]
 for actor in life.actors:
  profiles.append(actor.profile.duplicate(true));ticks.append(actor.tick_count);identities.append(actor.get_instance_id())
  _check(actor.get_parent()==life and not actor.is_processing() and not actor.is_physics_processing(),"only passenger owner advances "+actor.name)
  _check(is_equal_approx(actor.sprite.pixel_size,.018) and actor.sprite.texture.get_width()==128,"native complete .018 human scale: "+actor.name)
 _check(life.seated.position.is_equal_approx(Vector3(-12.7,.055,3.9)) and life.seated.hip_anchor.position.is_equal_approx(Vector3(0,.4725,.25)),"exact corrected bench actor sits on actual forward seat")
 var compact:=true
 var seated_image: Image=life.seated.sprite.texture.get_image()
 for y in range(120,128):
  for x in 128:
   if seated_image.get_pixel(x,y).a>.1:compact=false
 _check(compact,"five-row compact seated legs end without stretching")
 life.tick(0.0,camera,0.0)
 for foot in life.seated.feet:_check(foot.global_position.y>.055 and foot.global_position.distance_to(life.seated.hip_anchor.global_position)<.46,"short boots remain proportionate above pavement")
 var TicketArt=load("res://scripts/opening/harbor_passenger_art.gd")
 var Appearance=load("res://scripts/opening/npc_appearance.gd")
 var original_head:=true;var ticket_changes:=true
 for direction: String in ["front","back","left","right"]:
  var normal: Image=Appearance.draw(int(life.reader.profile.hairstyle),bool(life.reader.profile.male),direction,-1,"idle",0,life.reader.profile)
  var low: Image=TicketArt.frame(life.reader.profile,direction,"ticket",0).get_image()
  var raised: Image=TicketArt.frame(life.reader.profile,direction,"ticket",1).get_image()
  original_head=original_head and normal.get_region(Rect2i(0,0,128,72)).get_data()==raised.get_region(Rect2i(0,0,128,72)).get_data()
  ticket_changes=ticket_changes and low.get_data()!=raised.get_data()
 _check(original_head,"ticket gestures preserve the complete original normal-size head in all four views")
 _check(ticket_changes,"held ticket and hands visibly raise in all four views")
 var front: Image=TicketArt.frame(life.reader.profile,"front","ticket",1).get_image()
 _check(front.get_pixel(56,84).to_html(false)=="e7d7b3" and front.get_pixel(52,84).a>.9 and front.get_pixel(80,84).a>.9,"cream card sits between both visible hands on the torso")
 var changed_profile: Dictionary=life.reader.profile.duplicate(true);changed_profile.coat="b95d67"
 _check(TicketArt.frame(changed_profile,"front","ticket",1)!=TicketArt.frame(life.reader.profile,"front","ticket",1),"private appearance cache distinguishes changed clothes with same identity")
 var starts: Array=[]
 for actor in life.actors:starts.append(actor.position)
 var min_z:=100.0;var max_z:=-100.0;var actions: Dictionary={};var orientations: Dictionary={};var route_safe:=true
 for step in 1800:
  life.tick(1.0/60.0,camera,float(step)/60.0)
  if step%10==0:await physics_frame
  min_z=minf(min_z,life.porter.position.z);max_z=maxf(max_z,life.porter.position.z)
  actions[life.porter.action]=true;orientations[life.watcher.aim]=true
  for actor in life.actors:
   route_safe=route_safe and not (actor.position.x>=-17 and actor.position.x<=-5 and actor.position.z>=5.7 and actor.position.z<=8.3)
  route_safe=route_safe and life.porter.position.x>=-1.30 and life.porter.position.x<=-.95 and life.porter.position.z>=3.89 and life.porter.position.z<=5.11
 _check(max_z-min_z>.8 and actions.has("inspect") and actions.has("hold_tag") and actions.has("walk"),"porter visibly walks, inspects luggage and pauses with a tag on a bounded loop")
 _check(orientations.size()>=2 and life.watcher.position==starts[1] and life.reader.position==starts[2],"stationary companion watches sea and glances while reader stays beside board")
 _check(route_safe,"people remain outside central lane and porter stays outside existing yard route")
 var unchanged:=true;var once:=true
 for i in 4:
  unchanged=unchanged and life.actors[i].profile==profiles[i] and life.actors[i].get_instance_id()==identities[i]
  once=once and life.actors[i].tick_count-int(ticks[i])==1801
 _check(unchanged and once,"exactly one tick per helper call preserves four private identities")
 var before_large_step: Vector3=life.porter.position
 life.tick(8.0,camera,30.0)
 _check(life.porter.position.distance_to(before_large_step)<=.0141,"late frame cannot teleport the porter beyond the native bounded movement step")
 var before_negative_step: Vector3=life.porter.position
 life.tick(-1.0,camera,30.1)
 _check(life.porter.position==before_negative_step,"negative elapsed time cannot reverse or advance an authored route")
 var warmed: int=TicketArt.cache.size()
 for step in 1800:life.tick(1.0/60.0,camera,float(step)/60.0)
 _check(TicketArt.cache.size()==warmed,"repeated activity reuses finite private textures")
 _check(StandingArt.cache.size()==shared_cache_before,"private passengers do not add or modify shared standing-art cache")
 var player:=CharacterBody3D.new();player.collision_layer=2;player.collision_mask=1
 var capsule:=CapsuleShape3D.new();capsule.radius=.26;capsule.height=1.3
 var shape:=CollisionShape3D.new();shape.shape=capsule;shape.position.y=.65;player.add_child(shape);scene.add_child(player)
 await physics_frame
 for actor in life.actors:
  player.global_position=actor.human_blocker.global_position+Vector3(0,0,1.2)
  var hit:=player.move_and_collide(Vector3(0,0,-1.2))
  _check(hit!=null and hit.get_collider()==actor.human_blocker,"visible passenger has native blocking footprint: "+actor.name)
 player.global_position=Vector3(-16,.055,7)
 _check(player.move_and_collide(Vector3(10,0,0))==null,"broad central public lane remains open")
 var obstruction:=StaticBody3D.new();obstruction.collision_layer=1;var obstruction_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.7,1.8,.7);obstruction_shape.shape=box;obstruction_shape.position.y=.9;obstruction.add_child(obstruction_shape);scene.add_child(obstruction)
 obstruction.position=life.porter.position+Vector3(0,0,.10);await physics_frame
 var before: Vector3=life.porter.position
 var desired: Vector3=before+Vector3(0,0,.20)
 _check(not life.porter.move_on_route(desired) and life.porter.position==before,"porter native query waits at an occupied next step rather than passing through people or props")
 for step in 600:life.tick(1.0/60.0,camera,60.0+float(step)/60.0)
 _check(life.porter.position.distance_to(before)<.001 and not life.porter.walking,"authored porter activity actually remains waiting while its native next step is occupied")
 _check(get_nodes_in_group("harbor_person").size()==4,"only four visible native people solids and no invisible forecourt barriers")
 scene.queue_free();await process_frame;_finish()
