extends RefCounted
## Body-only image cells, projected along the viewing ray onto the attack plane.
## Small enclosing disks retain the existing swept-circle combat consumers.
## Explicit body crops exclude carried weapons/tails; alpha excludes empty pixels.
const CELL:=8
static var _cache: Dictionary={}
static func cells(texture: Texture2D,body: Rect2i) -> Array:
	var key:=str(texture.get_instance_id())+":"+str(body)
	if _cache.has(key):return _cache[key]
	var result: Array=[]
	var image:=texture.get_image()
	var bounds:=body.intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	for y in range(bounds.position.y,bounds.end.y,CELL):
		for x in range(bounds.position.x,bounds.end.x,CELL):
			var lo:=Vector2i(10000,10000);var hi:=Vector2i(-1,-1)
			for py in range(y,mini(y+CELL,bounds.end.y)):
				for px in range(x,mini(x+CELL,bounds.end.x)):
					if image.get_pixel(px,py).a<.5:continue
					lo=lo.min(Vector2i(px,py));hi=hi.max(Vector2i(px+1,py+1))
			if hi.x>=0:result.append(Rect2(Vector2(lo),Vector2(hi-lo)))
	_cache[key]=result
	return result
static func point(sprite: AnimatedSprite3D,pixel: Vector2,height: float,texture_size: Vector2) -> Vector3:
	var xy:=pixel-texture_size*.5 if sprite.centered else pixel
	xy.y=-xy.y
	if sprite.flip_h:xy.x=-xy.x
	if sprite.flip_v:xy.y=-xy.y
	xy+=sprite.offset
	var world: Vector3=sprite.global_transform*Vector3(xy.x*sprite.pixel_size,xy.y*sprite.pixel_size,0)
	var ray:=sprite.global_basis.z.normalized()
	return world+ray*((height-world.y)/ray.y)
# Every projected cell disk is contained in the full frame's enclosing disk
# expanded by a half-cell diagonal. Use that bound before touching image data.
static func may_overlap(sprite: AnimatedSprite3D, origin: Vector3, height: float, reach: float) -> bool:
	if sprite.sprite_frames == null:
		return true
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
	var basis := sprite.global_basis
	var ray := basis.z.normalized()
	if texture == null or absf(ray.y) < .05:
		return true
	var x := basis.x - ray * (basis.x.y / ray.y)
	var y := basis.y - ray * (basis.y.y / ray.y)
	var texture_size := texture.get_size()
	var radius := (x.length() * (texture_size.x + CELL) + y.length() * (texture_size.y + CELL)) * sprite.pixel_size * .5
	var offset := point(sprite, texture_size * .5, height, texture_size) - origin
	offset.y = 0
	return offset.length_squared() <= (reach + radius) * (reach + radius)

static func regions(sprite: AnimatedSprite3D,body: Rect2i,height: float) -> Array:
	var transform := sprite.global_transform
	var ray := transform.basis.z.normalized()
	if sprite.sprite_frames == null or absf(ray.y) < .05:
		return []
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
	if texture == null:
		return []
	var pixel_zero := sprite.offset
	if sprite.centered:
		pixel_zero += texture.get_size() * Vector2(.5 if sprite.flip_h else -.5, -.5 if sprite.flip_v else .5)
	var world_zero := transform * Vector3(pixel_zero.x * sprite.pixel_size, pixel_zero.y * sprite.pixel_size, 0)
	var projected_zero := world_zero + ray * ((height - world_zero.y) / ray.y)
	var axis_x := transform.basis.x * sprite.pixel_size * (-1.0 if sprite.flip_h else 1.0)
	var axis_y := transform.basis.y * sprite.pixel_size * (1.0 if sprite.flip_v else -1.0)
	axis_x -= ray * (axis_x.y / ray.y)
	axis_y -= ray * (axis_y.y / ray.y)
	var result: Array = []
	for cell: Rect2 in cells(texture,body):
		var pixel_center := cell.get_center()
		var center := projected_zero + axis_x * pixel_center.x + axis_y * pixel_center.y
		var half_x := axis_x * cell.size.x * .5
		var half_y := axis_y * cell.size.y * .5
		var radius := sqrt(maxf((half_x + half_y).length_squared(), (half_x - half_y).length_squared()))
		result.append({"id":"body","position":center,"radius":radius})
	return result
