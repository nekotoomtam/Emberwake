extends SceneTree
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func projected(sprite: AnimatedSprite3D,pixel: Vector2,height: float) -> Vector3:
	var local:=Vector3((pixel.x-64)*sprite.pixel_size,(64-pixel.y)*sprite.pixel_size,0)
	var world: Vector3=sprite.global_transform*local
	var ray:=sprite.global_basis.z.normalized()
	return world+ray*((height-world.y)/ray.y)
func run() -> void:
	var game=load("res://scenes/game.tscn").instantiate();game.loadout.save_path="";root.add_child(game);game.set_physics_process(false)
	for trial in ["start_fisherman_trial","start_brinehound_trial","start_crewman_trial"]:
		game.call(trial);var enemy=game.enemies[0]
		enemy.sprite.global_basis=game.camera.global_basis
		enemy.sprite.global_position=enemy.global_position+game.camera.global_basis.y*((float(enemy._profile.foot_pixel)-64)*enemy.sprite.pixel_size)
		for view in ["left","right","front","back"]:
			for phase in (["idle","run","sequence"] if trial=="start_brinehound_trial" else ["idle","walk","windup","attack"]):
				enemy.sprite.animation=view+"_"+phase
				for frame_index in range(enemy.sprite.sprite_frames.get_frame_count(enemy.sprite.animation)):
					enemy.sprite.frame=frame_index
					var image: Image=enemy.sprite.sprite_frames.get_frame_texture(enemy.sprite.animation,frame_index).get_image()
					var regions: Array=enemy.hurt_regions()
					var sprite: AnimatedSprite3D = enemy.sprite
					var texture := sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
					var image_hurt = preload("res://scripts/enemy_image_hurt.gd")
					var cell_rects: Array = image_hurt.cells(texture,enemy._profile.body_crop)
					var plane: float = enemy.global_position.y + .7
					var same := regions.size() == cell_rects.size()
					for cell_index in mini(regions.size(),cell_rects.size()):
						var cell: Rect2 = cell_rects[cell_index]
						var center: Vector3 = image_hurt.point(sprite,cell.get_center(),plane,texture.get_size())
						var reference_radius := 0.0
						for corner: Vector2 in [cell.position,Vector2(cell.end.x,cell.position.y),cell.end,Vector2(cell.position.x,cell.end.y)]:
							reference_radius = maxf(reference_radius,center.distance_to(image_hurt.point(sprite,corner,plane,texture.get_size())))
						var region: Dictionary = regions[cell_index]
						same = same and center.distance_to(region.position) < .00001 and absf(reference_radius - region.radius) < .00001
						same = same and image_hurt.may_overlap(sprite,center+Vector3.RIGHT*reference_radius,plane,.001)
					check(same,"affine projection preserves cell centres, radii and conservative bounds")
					var tested:=0;var missed:=0
					for y in range(48,97,8):
						for x in range(48,81,8):
							if image.get_pixel(x,y).a<.5:continue
							var point:=projected(enemy.sprite,Vector2(x+.5,y+.5),enemy.global_position.y+.7)
							var found:=false
							for region in regions:
								var offset: Vector3=point-region.position;offset.y=0
								if offset.length()<=float(region.radius)+.001:found=true;break
							tested+=1
							if not found:missed+=1
					check(tested>0 and missed==0,trial+" "+enemy.sprite.animation+" frame "+str(frame_index)+" visible body pixels covered; misses="+str(missed))
					var empty:=projected(enemy.sprite,Vector2(4,4),enemy.global_position.y+.7)
					var outside:=true
					for region in regions:
						var offset: Vector3=empty-region.position;offset.y=0
						if offset.length()<float(region.radius):outside=false
					check(outside,"transparent far corner not targetable")
		# Real gameplay consumers: aim at a visible upper-body pixel whose ground
		# projection lies outside the old tiny foot disk. No attack-range buff.
		enemy.sprite.animation="right_idle";enemy.sprite.frame=0
		var aim_point:=projected(enemy.sprite,Vector2(64,60),enemy.global_position.y+.7)
		for family in ["sword","greatsword","mace"]:
			game.motion.reset();game.set_weapon_family(family)
			var reach: float=game.motion.definition(0).reach
			game.player.position=aim_point-game.camera.global_basis.x*reach*.85;game.player.position.y=enemy.position.y
			var direction: Vector3=aim_point-game.player.position;direction.y=0
			game.motion.start(0,atan2(direction.z,direction.x))
			if family=="greatsword":game.motion.release_great_charge()
			var step:={"previous_angle":atan2(direction.z,direction.x)-.5,"current_angle":atan2(direction.z,direction.x)+.5}
			check(game._melee_contact_region(enemy,step)=="body",trial+" "+family+" actual melee consumer hits visible upper body")
			game.motion.reset()
		for height in [.6,1.2]:
			var center:=projected(enemy.sprite,Vector2(64,60),height)
			var start: Vector3=center-game.camera.global_basis.x*4
			var end: Vector3=center+game.camera.global_basis.x*4
			var contact: Dictionary=game.staff_flight._first_contact(start,end,.1,[enemy],null)
			check(contact.get("enemy")==enemy,trial+" projectile consumer hits body at height "+str(height))
			if not contact.is_empty():
				var expected_exit:=0.0
				for region in enemy.image_hurt_regions(height):
					var offset: Vector3=region.position-start;offset.y=0
					var along: float=offset.dot(game.camera.global_basis.x)
					var across_squared: float=maxf(0,offset.length_squared()-along*along)
					var radius: float=region.radius+.1
					if across_squared<=radius*radius:expected_exit=maxf(expected_exit,along+sqrt(radius*radius-across_squared))
				check(absf(start.distance_to(contact.exit_position)-expected_exit)<.001,trial+" rifle exit uses complete body rather than first cell")
			check(game.staff_flight._first_contact(start+Vector3.UP*0,end+Vector3.UP*0,.1,[],null).is_empty(),"empty targets stay empty")
		game.motion.reset()
	game.free()
	print("ENEMY IMAGE HURT ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
