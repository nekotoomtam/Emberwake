extends SceneTree
## Native evidence only: original runtime actors, then their unchanged harbor.
## The labelled stage temporarily moves actors, never rescales or redraws them.
const Hero=preload("res://scripts/hero_directions.gd")
const Profile=preload("res://scripts/opening/harbor_plaza_profile.gd")
var g
var luggage
var output:=""
var checks:=0
var failures: Array=[]
var shots: Array=[]
var views: Array=[]
var lineup_restore: Array=[]
var stage: Node3D
var labels: CanvasLayer
var lineup_actors: Array=[]
var identity_before: Dictionary={}
var bag_instance:=0
func _initialize() -> void:
 root.unfocusable=true
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func has_property(object: Object,key: String) -> bool:
 for entry in object.get_property_list():
  if entry.name==key:return true
 return false
func humans(node: Node) -> Array:
 var result: Array=[]
 if has_property(node,"profile") and has_property(node,"sprite") and node.get("sprite") is Sprite3D:result.append(node)
 for child in node.get_children():result.append_array(humans(child))
 return result
func identities() -> Dictionary:
 var result: Dictionary={}
 for actor in humans(g.world):result[str(actor.get_instance_id())]={"id":str(actor.profile.id),"profile":actor.profile.duplicate(true)}
 return result
func actor_id(actor) -> String:
 return str(actor.profile.id) if has_property(actor,"profile") else "normal_player"
func release_walk() -> void:
 for key in ["harbor_left","harbor_right","harbor_up","harbor_down"]:
  if InputMap.has_action(key):Input.action_release(key)
func inspect_ui() -> void:
 g.ui.cinematic(true);g.ui.caption.visible=false;g.ui.hide_actor_bark()
func step(world_only: bool=false) -> void:
 await physics_frame
 var dt:=1.0/Engine.physics_ticks_per_second
 if world_only:
  g.world.tick(dt,g.camera)
  if g.walker!=null:
   var movement: Vector3=g.walker.velocity;movement.y=0
   g.walker.update_art(0,movement);luggage.update_carry(g.walker,g.camera)
 else:g.tick(dt)
func advance(seconds: float,world_only: bool=false) -> void:
 for frame in ceili(seconds*Engine.physics_ticks_per_second):await step(world_only)
func steer(target: Vector3) -> void:
 var direction: Vector3=target-g.walker.position;direction.y=0;direction=direction.normalized()
 var right:=Vector3(g.camera.global_basis.x.x,0,g.camera.global_basis.x.z).normalized()
 var toward:=Vector3(g.camera.global_basis.z.x,0,g.camera.global_basis.z.z).normalized()
 var x: float=direction.dot(right);var z: float=direction.dot(toward)
 release_walk();Input.action_press("harbor_right" if x>=0 else "harbor_left",absf(x));Input.action_press("harbor_down" if z>=0 else "harbor_up",absf(z))
func walk_to(target: Vector3) -> bool:
 var offset: Vector3=target-g.walker.position;offset.y=0
 for frame in ceili((offset.length()/2.4+3)*Engine.physics_ticks_per_second):
  offset=target-g.walker.position;offset.y=0
  if offset.length()<.16:release_walk();return true
  steer(target);await step()
 release_walk();printerr("HUMAN PROPORTION CAPTURE WALK STOP ",g.walker.position," target ",target);return false
func frame_view(at: Vector3,target: Vector3,fov_: float=44) -> void:
 g.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;g.camera._duration=0;g.camera.flying=false;g.camera.position=at;g.camera.look_at(target);g.camera.fov=fov_
 g.world.tick(0,g.camera)
 if g.walker!=null:
  var movement: Vector3=g.walker.velocity;movement.y=0
  g.walker.update_art(0,movement);luggage.update_carry(g.walker,g.camera)
func pixel_world(sprite: Sprite3D,pixel: Vector2) -> Vector3:
 var extent:=Vector2(sprite.texture.get_width(),sprite.texture.get_height())*.5
 return sprite.global_transform*Vector3((pixel.x-extent.x)*sprite.pixel_size,(extent.y-pixel.y)*sprite.pixel_size,0)
func source_bounds(image: Image,region: Rect2i,colors: Array=[]) -> Rect2i:
 var low:=Vector2i(32,32);var high:=Vector2i(-1,-1)
 for y in range(region.position.y,region.end.y):
  for x in range(region.position.x,region.end.x):
   var color:=image.get_pixel(x,y);var matched:=colors.is_empty()
   for reference: Color in colors:
    if absf(color.r-reference.r)<=1.01/255 and absf(color.g-reference.g)<=1.01/255 and absf(color.b-reference.b)<=1.01/255:matched=true
   if color.a>.5 and matched:
    low.x=mini(low.x,x);low.y=mini(low.y,y);high.x=maxi(high.x,x);high.y=maxi(high.y,y)
 return Rect2i(low,high-low+Vector2i.ONE) if high.x>=0 else Rect2i()
func rect_array(rect: Rect2i) -> Array:return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
func projected_rect(sprite: Sprite3D,rect: Rect2i) -> Array:
 if rect.size==Vector2i.ZERO:return [0,0,0,0]
 var first: Vector2=g.camera.unproject_position(pixel_world(sprite,Vector2(rect.position)))
 var bounds:=Rect2(first,Vector2.ZERO)
 for pixel in [rect.position,Vector2i(rect.end.x,rect.position.y),rect.end,Vector2i(rect.position.x,rect.end.y)]:bounds=bounds.expand(g.camera.unproject_position(pixel_world(sprite,Vector2(pixel))))
 return [bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]
func actor_record(actor) -> Dictionary:
 var sprite: Sprite3D=actor.sprite
 var image:=sprite.texture.get_image().duplicate();image.resize(32,32,Image.INTERPOLATE_NEAREST)
 var skin:=Color(actor.profile.get("skin","ffddbc")) if has_property(actor,"profile") else Color("ffddbc")
 var skin_colors: Array=[skin,skin.darkened(.18),skin.darkened(.2)]
 if not has_property(actor,"profile"):skin_colors.append(Color("e7a183"))
 var head_end:=20 if has_property(actor,"role") and actor.role=="coffee" else 18
 var head:=source_bounds(image,Rect2i(0,0,32,head_end));var face:=source_bounds(image,Rect2i(0,0,32,head_end),skin_colors)
 var result: Dictionary={"id":actor_id(actor),"instance":actor.get_instance_id(),"script":actor.get_script().resource_path,"position":str(actor.global_position),"texture_size":[sprite.texture.get_width(),sprite.texture.get_height()],"texture_hash":hash(sprite.texture.get_image().get_data()),"pixel_size":sprite.pixel_size,"effective_pixel_world":[sprite.pixel_size*sprite.global_basis.x.length(),sprite.pixel_size*sprite.global_basis.y.length()],"effective_logical_pixel_world":[sprite.pixel_size*4*sprite.global_basis.x.length(),sprite.pixel_size*4*sprite.global_basis.y.length()],"sprite_camera_depth":-g.camera.to_local(sprite.global_position).z,"basis":str(sprite.global_basis),"source_head_roi":rect_array(head),"source_face_roi":rect_array(face),"source_torso_band":rect_array(source_bounds(image,Rect2i(0,18,32,8))),"source_lower_band":rect_array(source_bounds(image,Rect2i(0,25,32,7))),"projected_alpha_rect":projected_rect(sprite,sprite.texture.get_image().get_used_rect()),"projected_head_roi":projected_rect(sprite,Rect2i(head.position*4,head.size*4)),"projected_face_roi":projected_rect(sprite,Rect2i(face.position*4,face.size*4))}
 if has_property(actor,"hip_anchor"):
  result.hip_world=str(actor.hip_anchor.global_position);result.actual_hip_pixel_world=str(pixel_world(sprite,Vector2(64,100)));result.hip_contact_error=pixel_world(sprite,Vector2(64,100)).distance_to(actor.hip_anchor.global_position)
 return result
func shot(label: String,subjects: Array,diagnostic: bool=false,hud: bool=false) -> void:
 if not hud:check(not g.ui.menu.visible and not g.ui.footer.visible and not g.ui.caption.visible,"inspection UI is hidden: "+label)
 await process_frame;await RenderingServer.frame_post_draw
 var image: Image=root.get_texture().get_image()
 check(image.get_width()==1280 and image.get_height()==800 and image.save_png(output+"/"+label+".png")==OK,"save native 1280x800 capture "+label);shots.append(label)
 var people: Array=[]
 for actor in subjects:people.append(actor_record(actor))
 views.append({"name":label,"width":image.get_width(),"height":image.get_height(),"diagnostic_stage":diagnostic,"original_runtime_actors":true,"manual_actor_rescale":false,"camera_projection":"orthographic" if g.camera.projection==Camera3D.PROJECTION_ORTHOGONAL else "perspective","camera_transform":str(g.camera.global_transform),"camera_fov":g.camera.fov,"camera_orthographic_size":g.camera.size,"phase":str(g.phase),"world_clock":g.world.clock,"menu_visible":g.ui.menu.visible,"footer_visible":g.ui.footer.visible,"caption_visible":g.ui.caption.visible,"ordinary_gameplay_hud":hud,"actors":people,"bag_instance":luggage.get_instance_id(),"bag_state":str(luggage.state)})
func stage_label(value: String,at: Vector2,size_: int=20,width: float=250) -> void:
 var label:=Label.new();label.text=value;label.position=at;label.size.x=width;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",size_);label.add_theme_color_override("font_color",Color("253e46"));labels.add_child(label)
func child_transforms(node: Node) -> Array:
 var result: Array=[]
 for child in node.get_children():
  if child is Node3D:result.append({"node":child,"transform":child.transform})
  result.append_array(child_transforms(child))
 return result
func snapshot_actor(actor) -> Dictionary:
 var fields: Dictionary={}
 for key in ["route","facing","aim","_target","_wait","_arrived","carrying","walking","actor_clock","phase","pose_index","action","tick_count","time_phase","sip_lift","carrying_luggage","clock","enabled","art_action","art_frame","visual_offset","_safe_position","wrong_way_latched"]:
  if has_property(actor,key):
   var value=actor.get(key);fields[key]=value.duplicate(true) if value is Array or value is Dictionary else value
 var record: Dictionary={"actor":actor,"parent":actor.get_parent(),"index":actor.get_index(),"transform":actor.transform,"fields":fields,"processing":actor.is_processing(),"physics_processing":actor.is_physics_processing(),"profile":actor.profile.duplicate(true) if has_property(actor,"profile") else {},"sprite_texture":actor.sprite.texture,"sprite_transform":actor.sprite.transform,"sprite_scale":actor.sprite.scale,"descendants":child_transforms(actor),"props":[]}
 for key in ["cup","brush","palette_prop"]:
  if has_property(actor,key) and is_instance_valid(actor.get(key)):record.props.append({"node":actor.get(key),"transform":actor.get(key).transform})
 if has_property(actor,"human_blocker"):record.blocker_layer=actor.human_blocker.collision_layer
 return record
func make_stage() -> void:
 stage=Node3D.new();stage.name="DiagnosticOriginalActorStage";root.add_child(stage)
 labels=CanvasLayer.new();stage.add_child(labels)
 var background:=MeshInstance3D.new();var plane:=QuadMesh.new();plane.size=Vector2(12,7);background.mesh=plane;background.position=Vector3(0,1,-.4)
 var paper:=StandardMaterial3D.new();paper.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;paper.albedo_color=Color("e8e3d6");background.material_override=paper;stage.add_child(background)
 var line:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(11,.012,.012);line.mesh=mesh;line.position=Vector3(0,.055,-.1)
 var ink:=StandardMaterial3D.new();ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ink.albedo_color=Color("8b9c99");line.material_override=ink;stage.add_child(line)
func lineup(label: String,actors: Array,titles: Array) -> void:
 lineup_actors=actors;lineup_restore=[]
 # Capture every state before removing any siblings, including original indexes.
 for actor in actors:lineup_restore.append(snapshot_actor(actor))
 for actor in actors:
  actor.reparent(stage,true);actor.set_process(false);actor.set_physics_process(false)
  if has_property(actor,"human_blocker"):actor.human_blocker.collision_layer=0
  if has_property(actor,"route"):
   var empty_route: Array[Vector3]=[];actor.route=empty_route
  if has_property(actor,"carrying_luggage"):actor.carrying_luggage=false
 g.camera._duration=0;g.camera.flying=false;g.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;g.camera.size=5.9;g.camera.position=Vector3(0,1.1,10);g.camera.look_at(Vector3(0,1.1,0))
 stage_label("Native diagnostic · original harbor actors",Vector2(240,36),28,800)
 stage_label("Equal depth and camera · original pixel scale · normal player is the reference",Vector2(160,79),20,960)
 var depths: Array=[]
 for index in actors.size():
  var actor=actors[index];actor.position=Vector3((index-2)*1.8,.055,0)
  if actor==g.walker:actor.facing="front";actor.update_art(0,Vector3.ZERO)
  else:
   if has_property(actor,"aim"):actor.aim=Vector3.BACK
   if has_property(actor,"facing"):actor.facing="front"
   actor.tick(0,g.camera,-actor.phase if has_property(actor,"phase") else 0.0)
  # Compare visible image planes, not actor origins: a bench pose may offset
  # its hip toward the seat edge. Translation keeps the source scale intact.
  var plane_z: float=actor.sprite.global_position.z
  actor.position.z-=plane_z
  if actor==g.walker:actor.update_art(0,Vector3.ZERO)
  else:actor.tick(0,g.camera,-actor.phase if has_property(actor,"phase") else 0.0)
  var at: Vector2=g.camera.unproject_position(Vector3(actor.position.x,-.19,0))
  stage_label(str(titles[index])+"\n"+actor_id(actor),at-Vector2(108,0),19,216)
  depths.append(-g.camera.to_local(actor.sprite.global_position).z)
  check(absf(actor.sprite.pixel_size-.018)<.000001,"diagnostic retains original player-scale sprite: "+actor_id(actor))
 for depth in depths:check(absf(float(depth)-float(depths[0]))<.001,"diagnostic actors share exactly the same native projection depth")
 await shot(label,actors,true)
 for record in lineup_restore:
  var actor=record.actor;actor.reparent(record.parent,true);record.parent.move_child(actor,mini(record.index,record.parent.get_child_count()-1));actor.transform=record.transform
  for key in record.fields:actor.set(key,record.fields[key])
  for child in record.descendants:child.node.transform=child.transform
  for prop in record.props:prop.node.transform=prop.transform
  actor.sprite.texture=record.sprite_texture;actor.sprite.transform=record.sprite_transform
  actor.set_process(record.processing);actor.set_physics_process(record.physics_processing)
  if record.has("blocker_layer"):actor.human_blocker.collision_layer=record.blocker_layer
  check(actor.get_parent()==record.parent and actor.transform.is_equal_approx(record.transform),"diagnostic restores original parent and transform: "+actor_id(actor))
  check(actor.sprite.scale.is_equal_approx(record.sprite_scale) and (not has_property(actor,"profile") or actor.profile==record.profile),"diagnostic preserves original scale and appearance: "+actor_id(actor))
 lineup_restore=[];lineup_actors=[]
 for label_node in labels.get_children():label_node.free()
func cleanup() -> void:
 release_walk()
 # A runtime failure still returns all original actors before releasing a stage.
 for record in lineup_restore:
  if is_instance_valid(record.actor):record.actor.reparent(record.parent,true);record.actor.transform=record.transform
 lineup_restore=[]
 if is_instance_valid(stage):stage.free()
 if is_instance_valid(g):g.audio.shutdown();await create_timer(.25).timeout;g.free()
 await process_frame
func run() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(20000,20000))
 check(not output.is_empty(),"explicit native human-proportion capture destination supplied")
 if output.is_empty():quit(1);return
 DirAccess.make_dir_recursive_absolute(output);root.content_scale_size=Vector2i(1280,800);root.size=Vector2i(1280,800)
 g=load("res://scenes/prologue.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 luggage=g.world.plaza.get("travel_luggage")
 check(g.world.get("bench_life")!=null and g.world.get("life")!=null and luggage!=null,"actual prologue owns bench, social and luggage actors")
 if g.world.get("bench_life")==null or g.world.get("life")==null or luggage==null:await cleanup();quit(1);return
 g.start_arrival();g.skip_arrival();g.tick(0);inspect_ui()
 check(g.phase==&"play" and g.walker!=null,"ordinary start/skip path creates the real protagonist")
 if g.walker==null:await cleanup();quit(1);return
 bag_instance=luggage.get_instance_id();identity_before=identities()
 var player_texture_before: Texture2D=g.walker.sprite.texture
 var player_normal: Texture2D=Hero.frames("front").get_frame_texture("idle",0)
 var player_normal_hash:=hash(player_normal.get_image().get_data())
 var bench: Array=g.world.bench_life.actors
 var villager
 for actor in g.world.townspeople:
  if not actor.get_meta("social_life_owned",false):villager=actor;break
 check(villager!=null,"diagnostic uses an actual existing standing villager")
 if villager==null:await cleanup();quit(1);return
 var camera_before: Transform3D=g.camera.transform;var camera_projection_before: int=g.camera.projection;var camera_fov_before: float=g.camera.fov;var world_visible_before: bool=g.world.visible
 make_stage();g.world.visible=false
 await lineup("01-native-player-villager-three-benches",[g.walker,villager,bench[0],bench[1],bench[2]],["Normal protagonist","Standing villager","Seated companion","Seated companion","Seated reader"])
 await lineup("02-native-player-social-painter-model",[g.walker,villager,g.world.life.coffee_pair[0],g.world.life.portrait_pair[0],g.world.life.portrait_pair[1]],["Normal protagonist","Standing villager","Cafe seated side pose","Working painter","Portrait model"])
 check(stage.get_child_count()==3,"stage retains only its diagnostic labels and guides after all original actors return")
 stage.free();stage=null;labels=null;g.world.visible=world_visible_before;g.camera.transform=camera_before;g.camera.projection=camera_projection_before;g.camera.fov=camera_fov_before
 check(identities()==identity_before,"both diagnostic lineups restore every actual human instance, count, ID and profile")
 check(g.walker.sprite.texture==player_texture_before and hash(player_normal.get_image().get_data())==player_normal_hash,"normal player source and original carried texture survive diagnostic inspection")
 check(luggage.get_instance_id()==bag_instance and luggage.state==&"carried" and g.walker.carrying_luggage,"same original suitcase and carry lifecycle survive diagnostic inspection")
 frame_view(Vector3(-36.2,2.65,8),Vector3(-36.2,.90,2.6),44);await advance(.2,true)
 await shot("03-actual-bench-couple-front",[bench[0],bench[1]])
 frame_view(Vector3(-28.1,2.6,7.9),Vector3(-28.1,.90,2.6),44);await advance(.2,true)
 await shot("04-actual-bench-single-front",[bench[2]])
 frame_view(Vector3(-46,3.1,-2.2),Vector3(-47.3,.9,-8.2),43);await advance(.2,true)
 await shot("06-actual-cafe-social-reference",g.world.life.coffee_pair)
 frame_view(Vector3(-19.5,3.25,7.1),Vector3(-21.9,.9,-.3),42);await advance(.2,true)
 await shot("07-actual-painter-model-reference",g.world.life.portrait_pair)
 # Walk the original controller on the original floor; inspection never teleports
 # a player into the seating or replaces any furniture or collision object.
 for point in [Vector3(-43,.055,-7.3),Vector3(-43,.055,-3),Vector3(-40.3,.055,-3),Vector3(-40.3,.055,2.7)]:
  check(await walk_to(point),"actual carrying player reaches bench comparison via original pavement "+str(point))
 release_walk();g.walker.velocity=Vector3.ZERO
 frame_view(Vector3(-37.7,2.65,8.2),Vector3(-37.7,.95,2.5),44);g.walker.facing="front";g.walker.update_art(0,Vector3.ZERO);luggage.update_carry(g.walker,g.camera);await advance(.2,true)
 await shot("05-actual-player-beside-seated-couple",[g.walker,bench[0],bench[1]])
 # Let the unchanged production follow camera settle. This photograph retains
 # the ordinary play HUD and the real carried suitcase for in-game context.
 g.ui.caption.visible=true;await advance(1.4)
 var expected_target: Vector3=g.walker.position+Vector3(2.9,1.7,-3.2)
 check(g.camera.projection==Camera3D.PROJECTION_PERSPECTIVE and (-g.camera.global_basis.z).dot((expected_target-g.camera.position).normalized())>.999,"usual production follow camera supplies the gameplay evidence")
 check(g.ui.caption.visible and not g.ui.menu.visible and not g.ui.footer.visible,"ordinary gameplay HUD is retained without title controls")
 check(luggage.get_instance_id()==bag_instance and luggage.state==&"carried" and luggage.grip.global_position.distance_to(luggage.hand_world)<.025,"gameplay comparison retains the original bag held by its real handle")
 await shot("08-usual-follow-camera-player-carrying-bag",[g.walker,bench[0],bench[1]],false,true)
 check(identities()==identity_before,"all native photographs retain original human identities and appearances")
 check(shots.size()==8,"eight bounded native reference and actual-scene photographs are captured")
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 check(file!=null,"write native human-proportion evidence manifest")
 if file!=null:
  file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":shots,"views":views,"actual_human_count":identity_before.size(),"normal_player_source_hash":player_normal_hash,"physics_ticks_per_second":Engine.physics_ticks_per_second,"offscreen":true,"native_window_position":str(DisplayServer.window_get_position()),"unfocusable":root.unfocusable,"no_focus":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS),"scope":"Native player-referenced human proportions and original harbor context; not a full-game acceptance claim."},"  "));file.close()
 await cleanup()
 print("NATIVE HARBOR HUMAN PROPORTIONS v93 ",checks," checks; ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
