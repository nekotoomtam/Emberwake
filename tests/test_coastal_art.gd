extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var path := "res://scripts/coastal_art.gd"
	if not ResourceLoader.exists(path):
		check(false,"Coastal art missing")
		quit(1)
		return
	var art = load(path)
	var hashes := {}
	for kind: String in ["fisherman","brinehound","net_hauler","harpooner","spitter"]:
		var p: Dictionary = art.profile(kind)
		var frames: SpriteFrames = art.frames(kind)
		check(frames == art.frames(kind),"Shared cache " + kind)
		check(p.foot_pixel == 112,"Baseline " + kind)
		check(p.body_radius >= .30 and p.body_radius <= .40,"Body radius " + kind)
		var counts := {"idle":2,"walk":4,"windup":4,"attack":3,"recover":3,"hit":2,"death":3,"windup_alt":4,"attack_alt":3,"recover_alt":3}
		for anim: String in counts:
			check(frames.has_animation(anim),kind + anim)
			check(frames.get_frame_count(anim) >= counts[anim],kind + anim + " count")
			var distinct := {}
			for i in frames.get_frame_count(anim):
				var im: Image = frames.get_frame_texture(anim,i).get_image()
				check(im.get_size() == Vector2i(128,128),"128 canvas")
				var bounds := im.get_used_rect()
				check(im.get_pixel(0,0).a == 0 and im.get_pixel(127,127).a == 0,"Transparent RGBA corners")
				var opaque := 0
				for yy in 128:
					for xx in 128:
						if im.get_pixel(xx,yy).a > .5: opaque += 1
				check(opaque >= (100 if anim == "death" else 600),"Substantial alpha silhouette")
				check(bounds.end.y <= 112,"No pixels below feet")
				check(bounds.position.x > 0 and bounds.end.x < 128,"No clipped weapon %s %s %d" % [kind,anim,i])
				distinct[hash(im.get_data())] = true
			check(distinct.size() >= 2,"Distinct poses " + kind + anim)
		var idle: Image = frames.get_frame_texture("idle",0).get_image()
		hashes[hash(idle.get_data())] = true
		check(idle.get_used_rect().size.y * p.pixel_size >= (1.25 if kind == "brinehound" else 1.94),"Adult/lean dog scale")
		check(idle.get_used_rect().end.y == 112,"Feet touch baseline")
		# Torso rows exclude arms/weapons; collider diameter covers central coat/ribs.
		var central_width := 0
		for x in range(50,78):
			if idle.get_pixel(x,74).a > .5:
				central_width += 1
		check(central_width * p.pixel_size <= p.body_radius * 2 + .05,"Torso fits body collider")
		check(hash(frames.get_frame_texture("windup",3).get_image().get_data()) != hash(frames.get_frame_texture("attack",1).get_image().get_data()),"Tell changes into release")
	check(art.profile("fisherman").name == "ชาวประมงจมน้ำ","Correct fisherman Thai name")
	check(art.has_method("muzzle_pixel"),"Painted muzzle pixel API")
	if art.has_method("muzzle_pixel"):
		for kind: String in ["harpooner","spitter"]:
			for variant: bool in [false,true]:
				var muzzle: Vector2 = art.muzzle_pixel(kind,variant)
				var anim := "attack_alt" if variant else "attack"
				var active: Image = art.frames(kind).get_frame_texture(anim,1).get_image()
				check(active.get_pixelv(Vector2i(muzzle)).a == 1.0,"Muzzle lies on painted active release " + kind + anim)
				var expected := Vector2(120,50 if variant else 56) if kind == "harpooner" else Vector2(86,44)
				check(muzzle == expected,"Muzzle follows active frame1 barrel tip / mouth")
	check(hashes.size() == 5,"Five distinct silhouettes")
	check(art.projectile("harpooner").get_size() == Vector2(32,16),"Harpoon dimensions")
	check(art.projectile("spitter").get_size() == Vector2(16,16),"Brine dimensions")
	print("Coastal art: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)



