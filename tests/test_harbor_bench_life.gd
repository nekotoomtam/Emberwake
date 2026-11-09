extends SceneTree
## Isolated native checks: no World import or unrelated scene population.
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:
 call_deferred("_run")
func _check(condition: bool,label: String) -> void:
 checks+=1
 if not condition:failures.append(label);push_error(label)
func _run() -> void:
 _check(ResourceLoader.exists("res://scripts/opening/harbor_bench_life.gd"),"requested bench residents helper is available")
 if not failures.is_empty():_finish();return
 var Bench=load("res://scripts/opening/harbor_bench_life.gd")
 var HumanArt=load("res://scripts/opening/harbor_human_art.gd")
 var SocialArt=load("res://scripts/opening/harbor_social_art.gd")
 var human_cache_count: int=HumanArt.cache.size()
 var social_cache_count: int=SocialArt.cache.size()
 var scene:=Node3D.new();root.add_child(scene)
 var life=Bench.new();scene.add_child(life)
 var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(-33,5.8,10);camera.look_at(Vector3(-33,.7,2.5))
 await process_frame
 _check(life.actors.size()==3 and life.couple.size()==2 and is_instance_valid(life.single),"one pair and one lone resident are exclusively owned")
 _check(bool(life.couple[0].profile.male)!=bool(life.couple[1].profile.male),"the couple has a distinct male and female identity")
 var profiles: Array=[]
 for actor in life.actors:profiles.append(actor.profile.duplicate(true))
 _check(life.couple[0].position.x< -36.2 and life.couple[1].position.x> -36.2 and absf(life.single.position.x+28.1)<.9,"occupied benches match the two requested bench seats")
 var bodies: Array=[]
 for actor in life.actors:
  bodies.append(actor.human_blocker)
  _check(absf(actor.hip_anchor.global_position.y-.5275)<.005,"hip meets the actual bench top: "+actor.name)
  _check(actor.sprite.texture.get_width()==128 and is_equal_approx(actor.sprite.pixel_size,.018),"complete nearest-neighbour seated art uses normal player pixels: "+actor.name)
  life.tick(0.0,camera,0.0)
  var short_legs:=true
  for foot in actor.feet:short_legs=short_legs and foot.global_position.y>actor.global_position.y and foot.global_position.distance_to(actor.hip_anchor.global_position)<.46
  for knee in actor.knees:short_legs=short_legs and knee.global_position.distance_to(actor.hip_anchor.global_position)<.28
  _check(short_legs,"folded short legs stay proportionate without stretching to the ground: "+actor.name)
  _check(not actor.is_processing() and not actor.is_physics_processing(),"only the helper tick owns animation: "+actor.name)
  var bottom: Image=actor.sprite.texture.get_image()
  var no_extended_legs:=true
  for y in range(120,128):
   for x in range(128):
    if bottom.get_pixel(x,y).a>.1:no_extended_legs=false
  _check(no_extended_legs,"dedicated folded pose ends after five lower-limb rows: "+actor.name)
 life.tick(1.0/120.0,camera,0.0)
 var first_textures: Array=[];var first_transforms: Array=[];var changed: Array[bool]=[false,false,false]
 var initial_ticks: Array=[]
 for actor in life.actors:first_textures.append(actor.sprite.texture);first_transforms.append(actor.sprite.transform);initial_ticks.append(actor.tick_count)
 var maximum_hip_drift:=0.0
 for step in 240:
  life.tick(1.0/120.0,camera,float(step)*.1)
  for i in 3:
   var actor=life.actors[i]
   changed[i]=changed[i] or actor.sprite.texture!=first_textures[i] or not actor.sprite.transform.is_equal_approx(first_transforms[i])
   var painted_hip: Vector3=actor.sprite.global_transform*Vector3(0,-.648,0)
   maximum_hip_drift=maxf(maximum_hip_drift,painted_hip.distance_to(actor.hip_anchor.global_position))
 _check(changed.all(func(value):return value),"all three residents breathe or gesture during a bounded idle interval")
 _check(maximum_hip_drift<.005,"subtle animation keeps seated hips registered")
 var Art=load("res://scripts/opening/harbor_bench_art.gd")
 var warmed_cache_count: int=Art.cache.size()
 for step in 480:life.tick(1.0/120.0,camera,float(step)*.1)
 _check(Art.cache.size()==warmed_cache_count,"long idle loop reuses the finite seated texture set")
 life.tick(1.0/120.0,camera,0.0)
 var reused:=true;var unchanged:=true;var tick_owned:=true
 for i in 3:
  reused=reused and life.actors[i].sprite.texture==first_textures[i]
  unchanged=unchanged and life.actors[i].profile==profiles[i]
  tick_owned=tick_owned and life.actors[i].tick_count-initial_ticks[i]==721
 _check(reused and unchanged and tick_owned,"helper ticks each resident once and reuses the original private identity/resources")
 _check(HumanArt.cache.size()==human_cache_count and SocialArt.cache.size()==social_cache_count,"existing standing/social caches remain untouched")
 var changed_profile: Dictionary=profiles[0].duplicate(true);changed_profile.coat="bc567a"
 _check(Art.frame(changed_profile,0)!=Art.frame(profiles[0],0),"appearance changes with a reused identity cannot return stale seated art")
 await physics_frame
 var player:=CharacterBody3D.new();player.collision_layer=2;player.collision_mask=1
 var capsule:=CapsuleShape3D.new();capsule.radius=.26;capsule.height=1.3
 var shape:=CollisionShape3D.new();shape.shape=capsule;shape.position.y=.65;player.add_child(shape);scene.add_child(player)
 for actor in life.actors:
  player.global_position=actor.global_position+Vector3(0,0,1.8)
  var hit:=player.move_and_collide(Vector3(0,0,-2.4))
  _check(hit!=null and hit.get_collider()==actor.human_blocker,"native traveller capsule stops at the seated person: "+actor.name)
 player.global_position=Vector3(-46.6,.055,4.3)
 _check(player.move_and_collide(Vector3(0,0,-3.0))==null,"the western bench area receives no resident or invisible blocker")
 var group_bodies:=get_nodes_in_group("harbor_person")
 _check(group_bodies.size()==3 and bodies.size()==3,"exactly three human footprints and no helper barriers are present")
 scene.queue_free();await process_frame
 _finish()
func _finish() -> void:
 print("HARBOR BENCH LIFE v93 ",checks," checks; ","PASS" if failures.is_empty() else "FAIL "+str(failures))
 quit(0 if failures.is_empty() else 1)
