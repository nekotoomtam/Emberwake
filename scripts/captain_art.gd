class_name CaptainArt
extends RefCounted
## Original native pixel clusters; logical64 enlarged with nearest sampling.
## Feet baseline112, face three-quarter right. Parent owns facing and world anchor.
const BODY_RADIUS := 0.25
const ARM_RADIUS := 0.14
const ARM_OFFSET := -0.36
const INK := Color("111b21")
const COAT := Color("25363c")
const LIGHT := Color("496065")
const SEA := Color("748d80")
const SKIN := Color("a9b6a2")
const RUST := Color("926649")
static var _cache: Dictionary = {}
static var _anchor: Texture2D

static func frames(cut: bool = false) -> SpriteFrames:
	if _cache.has(cut):
		return _cache[cut]
	var result := SpriteFrames.new()
	result.remove_animation("default")
	var counts := {"idle": 2, "walk": 4, "attack": 3, "hit": 1, "death": 3, "sweep_windup":5,"sweep_active":4,"throw_windup":5,"throw_active":4,"slam_windup":5,"slam_active":3,"recover":4,"throw_reel":6,"sweep_recover":6,"throw_recover":6,"slam_recover":6}
	var speeds := {"idle": 2.0, "walk": 6.0, "attack": 5.0, "hit": 7.0, "death": 5.0,"sweep_windup":6.0,"sweep_active":10.0,"throw_windup":6.0,"throw_active":10.0,"slam_windup":6.0,"slam_active":10.0,"recover":6.0,"throw_reel":8.0,"sweep_recover":8.0,"throw_recover":8.0,"slam_recover":8.0}
	for animation: String in counts:
		result.add_animation(animation)
		result.set_animation_speed(animation, speeds[animation])
		result.set_animation_loop(animation, animation in ["idle", "walk"])
		for index: int in counts[animation]:
			var image := _figure(animation,index,cut)
			image.resize(128,128,Image.INTERPOLATE_NEAREST)
			result.add_frame(animation,ImageTexture.create_from_image(image))
	_cache[cut] = result
	return result

static func _rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	image.fill_rect(Rect2i(x,y,w,h),color)

static func _poly(image: Image, points: Array, color: Color) -> void:
	var polygon := PackedVector2Array()
	for point: Vector2 in points:
		polygon.append(point)
	for y in 64:
		for x in 64:
			if Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),polygon):
				image.set_pixel(x,y,color)

# Logical64 joints are the sole pose authority for pixels and external attachment.
# Row: torso x/y, control wrist x/y, control elbow x/y,
# weapon wrist x/y, weapon elbow x/y, head offset x/y.
static func _pose(animation: String, index: int) -> Dictionary:
	var rest := [0,0,22,31,24,28,38,36,38,30,0,0]
	# Phase joins reference these rows, including torso, elbows and head.
	var sweep_loaded := [-5,1,40,25,31,29,31,23,33,27,-1,0]
	var sweep_released := [5,2,14,37,22,32,46,39,43,32,1,0]
	var throw_loaded := [-5,-1,13,22,18,25,23,21,29,24,-2,-1]
	var throw_released := [5,3,48,34,38,29,50,31,44,27,2,0]
	var slam_loaded := [-2,-2,24,5,20,15,40,5,44,15,-2,-3]
	var slam_released := [5,12,34,48,28,39,44,47,43,38,3,2]
	var row: Array = rest.duplicate()
	var stride := 0
	if animation == "idle":
		row[1] = -index
	elif animation == "walk":
		row[1] = -1 if index % 2 else 0
		stride = [0,1,0,-1][index]
	elif animation == "attack":
		row = [[-1,0,22,23,25,24,38,30,39,26,0,0],[1,-1,22,28,24,26,43,28,40,25,0,0],[0,1,22,35,24,30,39,39,39,31,0,0]][index]
	elif animation == "hit":
		row = [-1,1,20,33,23,29,37,38,37,31,-1,0]
	elif animation == "death":
		row[1] = [2,4,6][index]
	else:
		var keys := {
			"sweep_windup": [rest,sweep_loaded,5],
			"sweep_active": [sweep_loaded,sweep_released,4],
			"throw_windup": [rest,throw_loaded,5],
			"throw_active": [throw_loaded,throw_released,4],
			"slam_windup": [rest,slam_loaded,5],
			"slam_active": [slam_loaded,slam_released,3],
			"recover": [slam_released,rest,4],
			"sweep_recover": [sweep_released,rest,6],
			"throw_recover": [throw_released,rest,6],
			"slam_recover": [slam_released,rest,6]
		}
		if animation == "throw_reel":
			# Standing hand-over-hand tug and reach; never borrow the slam fold.
			var pull := [2,2,38,35,30,31,42,33,38,28,1,0]
			var reach := [4,3,46,34,37,29,48,31,43,27,2,0]
			row = [throw_released,pull,reach,pull,reach,throw_released][clampi(index,0,5)]
		elif keys.has(animation):
			var key: Array = keys[animation]
			var t := float(clampi(index,0,key[2]-1))/float(key[2]-1)
			for part in row.size():
				row[part] = roundi(lerpf(float(key[0][part]),float(key[1][part]),t))
	var torso := Vector2(row[0],row[1])
	# Legacy bob moves all joints; authored tells already specify absolute wrists.
	var joint_bob := Vector2(0,row[1]) if animation in ["idle","walk","death"] else Vector2.ZERO
	return {"torso":torso,"stride":stride,"head":Vector2(row[10],row[11]),
		"left_shoulder":Vector2(27,25)+torso,"left_elbow":Vector2(row[4],row[5])+joint_bob,"left_hand":Vector2(row[2],row[3])+joint_bob,
		"right_shoulder":Vector2(37,26)+torso,"right_elbow":Vector2(row[8],row[9])+joint_bob,"right_hand":Vector2(row[6],row[7])+joint_bob}

static func _death_point(point: Vector2, animation: String, index: int) -> Vector2:
	if animation == "death":
		var height: int = [41,32,20][index]
		point.y = 56-height+floorf(point.y*height/64.0)
	return point*2.0

static func hand_pixel(animation: String, index: int, cut: bool = false) -> Vector2:
	var pose := _pose(animation,index)
	return _death_point(pose.right_hand if cut else pose.left_hand,animation,index)

static func arm_center_pixel(animation: String, index: int) -> Vector2:
	var pose := _pose(animation,index)
	return _death_point((pose.left_shoulder+pose.left_hand)*0.5,animation,index)

static func _segment(image: Image, start: Vector2, finish: Vector2, width: int, color: Color) -> void:
	var steps := maxi(1,int(ceilf(start.distance_to(finish)*2.0)))
	for step in steps+1:
		var point := start.lerp(finish,float(step)/steps).round()
		_rect(image,int(point.x)-width/2,int(point.y)-width/2,width,width,color)

static func _arm(image: Image, shoulder: Vector2, elbow: Vector2, wrist: Vector2) -> void:
	_segment(image,shoulder,elbow,4,INK)
	_segment(image,elbow,wrist,4,INK)
	_segment(image,shoulder+Vector2(-1,0),elbow+Vector2(-1,0),2,COAT)
	_segment(image,elbow+Vector2(-1,0),wrist+Vector2(-1,-1),2,LIGHT)
	_rect(image,int(wrist.x)-1,int(wrist.y)-1,3,3,SKIN)
	_rect(image,int(wrist.x)-1,int(wrist.y)+1,2,1,SEA)
	_rect(image,int(wrist.x),int(wrist.y)-2,2,1,RUST)

static func _figure(animation: String, index: int, cut: bool) -> Image:
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var pose := _pose(animation,index)
	var h: Vector2 = pose.torso
	var bob := int(h.y)
	var lean := int(h.x)
	var stride: int = pose.stride
	# Long split coat and narrow boots; lowered shoulders fold during death.
	_rect(image,29-stride,45,4,10,INK)
	_rect(image,34+stride,45,4,10,INK)
	_rect(image,29-stride,50,3,4,COAT)
	_rect(image,34+stride,50,3,4,COAT)
	_rect(image,28-stride,54,6,2,INK)
	_rect(image,34+stride,54,6,2,INK)
	_rect(image,30-stride,54,3,1,LIGHT)
	_rect(image,36+stride,54,3,1,LIGHT)
	_poly(image,[Vector2(28,23)+h,Vector2(35,22)+h,Vector2(38,27)+h,Vector2(39,47),Vector2(35,49),Vector2(33,43),Vector2(31,49),Vector2(26,48),Vector2(27,29)+h],INK)
	_poly(image,[Vector2(29,24)+h,Vector2(34,24)+h,Vector2(36,28)+h,Vector2(37,46),Vector2(35,47),Vector2(33,41),Vector2(30,47),Vector2(28,46)],COAT)
	_poly(image,[Vector2(28,27)+h,Vector2(30,29)+h,Vector2(29,43),Vector2(27,46)],LIGHT)
	_poly(image,[Vector2(33,26)+h,Vector2(35,28)+h,Vector2(36,43),Vector2(34,40)],Color("33494d"))
	# Stiff collar, asymmetric lapels, brass buttons, frayed coat hem.
	_poly(image,[Vector2(29,21)+h,Vector2(31,22)+h,Vector2(32,28)+h,Vector2(28,25)+h],SEA)
	_poly(image,[Vector2(35,21)+h,Vector2(36,24)+h,Vector2(33,28)+h,Vector2(33,23)+h],LIGHT)
	for button_y in [29,33,37]:
		_rect(image,33+lean,button_y+bob,1,1,RUST)
	_rect(image,28,45,1,3,SEA)
	_rect(image,36,44,1,3,SEA)
	_rect(image,29,47,1,2,Color.TRANSPARENT)
	_rect(image,36,47,1,2,Color.TRANSPARENT)
	# Sparse barnacle clusters, not heavy armor.
	_rect(image,28+lean,25+bob,1,1,Color("a0a78e"))
	_rect(image,29+lean,26+bob,1,1,SEA)
	_rect(image,28,40,1,1,Color("a0a78e"))
	_rect(image,29,41,1,1,SEA)
	# Both limbs use the same joints as chain attachment and moving hurt geometry.
	_arm(image,pose.right_shoulder,pose.right_elbow,pose.right_hand)
	if not cut:
		_arm(image,pose.left_shoulder,pose.left_elbow,pose.left_hand)
	else:
		_rect(image,26+lean,24+bob,3,3,INK)
		_rect(image,26+lean,26+bob,3,1,Color("735047"))
		_rect(image,27+lean,27+bob,1,2,SEA)
	# The slam throws the chin upward; the fold tips it forward.
	h += pose.head
	lean = int(h.x)
	bob = int(h.y)
	# Pallid small adult head, recessed eye, long nose and salt-stained jaw.
	_poly(image,[Vector2(30,14)+h,Vector2(35,14)+h,Vector2(37,18)+h,Vector2(36,21)+h,Vector2(33,23)+h,Vector2(30,21)+h],INK)
	_rect(image,31+lean,15+bob,5,5,SKIN)
	_rect(image,31+lean,18+bob,1,3,SEA)
	_rect(image,33+lean,20+bob,3,2,SEA)
	_rect(image,35+lean,18+bob,2,1,SKIN)
	_rect(image,34+lean,17+bob,2,1,INK)
	_rect(image,35+lean,17+bob,1,1,Color("d8dec0"))
	_rect(image,34+lean,20+bob,2,1,INK)
	# Peaked sailor cap: crown, band, offset visor and dull insignia.
	_poly(image,[Vector2(29,13)+h,Vector2(31,11)+h,Vector2(35,11)+h,Vector2(37,13)+h,Vector2(37,15)+h,Vector2(29,15)+h],INK)
	_rect(image,30+lean,12+bob,6,2,COAT)
	_rect(image,30+lean,14+bob,7,1,LIGHT)
	_rect(image,33+lean,13+bob,1,1,RUST)
	_rect(image,33+lean,15+bob,5,1,INK)
	if animation == "death":
		# Fold into the same narrow footprint; never slide the contact baseline.
		var compact := Image.create(64,64,false,Image.FORMAT_RGBA8)
		compact.fill(Color.TRANSPARENT)
		var height: int = [41,32,20][index]
		image.resize(64,height,Image.INTERPOLATE_NEAREST)
		compact.blit_rect(image,Rect2i(0,0,64,height),Vector2i(0,56-height))
		return compact
	return image

static func anchor_ring_pixel() -> Vector2:
	# The opening spans logical x29..34, y11..15; center is x32,y13.5.
	return Vector2(64,27)

static func anchor_texture() -> Texture2D:
	if _anchor != null:
		return _anchor
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	# Forged anchor with open ring, long shank, cross-stock and curved flukes.
	_poly(image,[Vector2(29,8),Vector2(35,8),Vector2(38,11),Vector2(38,16),Vector2(35,19),Vector2(29,19),Vector2(26,16),Vector2(26,11)],INK)
	_rect(image,29,11,6,5,Color.TRANSPARENT)
	_rect(image,30,18,4,31,INK)
	_rect(image,31,19,1,29,LIGHT)
	_rect(image,21,24,22,4,INK)
	_rect(image,23,24,18,1,LIGHT)
	_poly(image,[Vector2(15,37),Vector2(22,41),Vector2(20,43),Vector2(25,48),Vector2(31,49),Vector2(31,45),Vector2(34,45),Vector2(34,49),Vector2(40,47),Vector2(44,42),Vector2(41,41),Vector2(49,36),Vector2(48,46),Vector2(45,44),Vector2(40,51),Vector2(33,55),Vector2(25,52),Vector2(19,46),Vector2(16,48)],INK)
	_poly(image,[Vector2(19,42),Vector2(25,49),Vector2(32,52),Vector2(40,48),Vector2(45,41),Vector2(44,45),Vector2(39,50),Vector2(32,54),Vector2(24,51)],LIGHT)
	_rect(image,32,28,2,8,RUST)
	_rect(image,23,25,4,2,RUST)
	_rect(image,36,49,3,2,RUST)
	_rect(image,28,9,2,2,RUST)
	image.resize(128,128,Image.INTERPOLATE_NEAREST)
	_anchor = ImageTexture.create_from_image(image)
	return _anchor


