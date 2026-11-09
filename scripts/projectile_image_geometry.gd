extends RefCounted
## Authored pixel pins define where the simulation point lives in the image.
## Trails/shafts behind a leading contact pin are not independent damage events.
static var _pins: Dictionary={}
static var _radii: Dictionary={}
static func cross_radius(texture: Texture2D,core: Vector2) -> float:
	var key:=str(texture.get_instance_id())+str(core)
	if _radii.has(key):return _radii[key]
	var image:=texture.get_image();var x:=clampi(floori(core.x),0,image.get_width()-1)
	var top:=image.get_height();var bottom:=-1
	# Sample through the authored hot core, excluding decorative trailing pixels.
	for y in image.get_height():
		if image.get_pixel(x,y).a>=.5:top=mini(top,y);bottom=maxi(bottom,y)
	var radius:=maxf(core.y-top,bottom+1-core.y) if bottom>=top else .5
	_radii[key]=radius;return radius
static func pin(texture: Texture2D,style: String) -> Vector2:
	var key:=str(texture.get_instance_id())+style
	if _pins.has(key):return _pins[key]
	var image:=texture.get_image();var point:=Vector2(image.get_width(),image.get_height())*.5
	if style=="harpoon":
		var right:=-1;var top:=image.get_height();var bottom:=-1
		for x in range(image.get_width()-1,-1,-1):
			for y in image.get_height():
				if image.get_pixel(x,y).a>=.5:right=x;top=mini(top,y);bottom=maxi(bottom,y)
			if right>=0:break
		if right>=0:point=Vector2(right+1,(top+bottom+1)*.5)
	elif style=="glob":point=Vector2(8.5,8.5) # native16px round head, excludes its left tail
	_pins[key]=point;return point
static func quad_offset(texture: Texture2D,size: Vector2,style: String) -> Vector3:
	var p:=pin(texture,style);var pixels:=texture.get_size()
	return -Vector3((p.x/pixels.x-.5)*size.x,(.5-p.y/pixels.y)*size.y,0)
static func pixel_world(sprite: Sprite3D,pixel: Vector2) -> Vector3:
	var pixels:=sprite.texture.get_size()
	return sprite.global_transform*(Vector3(pixel.x-pixels.x*.5+sprite.offset.x,pixels.y*.5-pixel.y+sprite.offset.y,0)*sprite.pixel_size)
