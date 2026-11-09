class_name EmberPixelArt
extends RefCounted
## Native 32px pixel clusters, enlarged with nearest sampling to 128px.
## All upright actors stand at y=28 logical / y=112 texture pixels.
## Sprite2D center=(64,64); use offset.y=-48 to place feet at actor origin.
## Sword pivot is Vector2(12,8) in its 64x20 texture; blade points +X.

const LOGICAL_SIZE := 32
const SCALE := 4
const BASELINE := 112
const SWORD_PIVOT := Vector2(12, 8)
static var _frame_cache: Dictionary = {}
static var _sword_cache: Texture2D
static var _floor_cache: Texture2D

static func frames(kind: String) -> SpriteFrames:
	if not kind in ["player", "melee", "ranged", "elite", "dummy"]:
		kind = "player"
	if _frame_cache.has(kind):
		return _frame_cache[kind]
	var result := SpriteFrames.new()
	result.remove_animation("default")
	var counts := {"idle": 2, "walk": 4, "attack": 3, "hit": 1, "death": 3}
	var speeds := {"idle": 2.4, "walk": 8.0, "attack": 13.0, "hit": 8.0, "death": 6.0}
	for animation: String in counts:
		result.add_animation(animation)
		result.set_animation_speed(animation, speeds[animation])
		result.set_animation_loop(animation, animation in ["idle", "walk"])
		for index: int in counts[animation]:
			result.add_frame(animation, _texture(_actor_image(kind, animation, index)))
	_frame_cache[kind] = result
	return result

static func sword_texture() -> Texture2D:
	if _sword_cache != null:
		return _sword_cache
	var image := Image.create(16, 5, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	_stamp(image, [
		".....g..........",
		"....ogooSSSSSo..",
		"obbfgggLLLLLLSo.",
		"....ogooSSSSSo..",
		".....g..........",
	], Vector2i.ZERO, {
		"o": Color("263141"), "g": Color("c3a069"), "b": Color("67505b"),
		"f": Color("ffd4ad"), "S": Color("8ca6b6"), "L": Color("e5f6f7")
	})
	image.resize(64, 20, Image.INTERPOLATE_NEAREST)
	_sword_cache = ImageTexture.create_from_image(image)
	return _sword_cache

static func floor_texture() -> Texture2D:
	if _floor_cache != null:
		return _floor_cache
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color("414a52"))
	var stone := [Color("46515a"), Color("4c5761"), Color("3e4852"), Color("48545d")]
	for y in 32:
		for x in 32:
			var row: int = 0 if y < 15 else 1
			var shifted_x: int = (x + row * 16) % 32
			var shade: int = (int(shifted_x / 16.0) + row * 2) % 4
			var c: Color = stone[shade]
			if y == 0 or y == 15 or shifted_x == 0:
				c = Color("2a333d")
			elif y == 1 or y == 16 or shifted_x == 1:
				c = Color("57646b")
			elif (x * 17 + y * 29) % 67 == 0:
				c = c.lightened(0.07)
			image.set_pixel(x, y, c)
	# Small chipped edges and a broken seam, never a regular noise blanket.
	for p in [Vector2i(11, 7), Vector2i(12, 8), Vector2i(12, 9), Vector2i(13, 10), Vector2i(27, 21), Vector2i(26, 22)]:
		image.set_pixelv(p, Color("35414b"))
	image.set_pixel(12, 7, Color("5a6670"))
	image.set_pixel(27, 22, Color("56646b"))
	_floor_cache = ImageTexture.create_from_image(image)
	return _floor_cache

static func _texture(image: Image) -> Texture2D:
	image.resize(128, 128, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)

static func _actor_image(kind: String, animation: String, index: int) -> Image:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var bob := 0
	var lean := 0
	var step := 0
	if animation == "idle":
		bob = -index
	elif animation == "walk":
		bob = -1 if index % 2 == 1 else 0
		step = [0, 1, 0, -1][index]
	elif animation == "attack":
		lean = [0, 2, 1][index]
		bob = [0, 1, 0][index]
	elif animation == "hit":
		lean = -1
		bob = 1
	elif animation == "death":
		lean = index + 1
		bob = index * 2
	if kind == "player":
		_draw_player(image, bob, lean, step)
	elif kind == "dummy":
		_draw_dummy(image, bob, lean)
	else:
		_draw_enemy(image, kind, bob, lean, step)
	if animation == "hit":
		_flash(image)
	if animation == "death" and index == 2:
		image = _fallen(image)
	return image

static func _draw_player(image: Image, bob: int, lean: int, step: int) -> void:
	var p := {
		"o": Color("262333"), "M": Color("a44260"), "H": Color("c55372"),
		"h": Color("ed7b8d"), "L": Color("ffb0a8"), "F": Color("ffddbc"),
		"s": Color("e7a183"), "T": Color("2f5869"), "t": Color("50888c"),
		"D": Color("24394c"), "d": Color("385568"), "c": Color("e8d9bc"),
		"b": Color("b38c5d"), "B": Color("18293a"), "k": Color("5b6c7c")
	}
	_draw_boots(image, step, p)
	# The low ponytail makes the tiny silhouette read before facial detail.
	_stamp(image, [
		"...oMMo...", "..oMhhMo..", ".oMhhHMo..", "oMhhHMMo..",
		"oMhHMMo...", ".oHMMMo...", ".oMMMo....", "..ooo....."
	], Vector2i(6 + lean, 14 + bob), p)
	_stamp(image, [
		"..oo.cc.oo..", ".oTTTccTTTo.", "oTTtTTTTtTTo", "oTTtTTTTtTTo",
		".oTTbbbbTTo.", "..oDDDDDDoo.", ".oDDdDDDdDo.", "..oDDDDDDDo."
	], Vector2i(10 + lean / 2, 18), p)
	# Left sleeve and a single skin cluster; weapon hand belongs to the sword.
	_stamp(image, ["oTo", "oTo", ".sF", "..o"], Vector2i(10 + lean / 2, 20), p)
	_stamp(image, [
		"......oooooo......", "....ooMMMMMMoo....", "...oMMhhhhhhMMo...",
		"..oMhhLLLLLLhhMo..", ".oMhhLLLhhhhhhhMo.", ".oMhhLhhhhhhhhhMo.",
		"oMhhhhhhhhhhhhhhMo", "oMhMhhhhhhhhhhhhMo", "oMhMMhhhhhhhhhhhMo",
		"oMhMMhhhhhhhhhhhMo", "oMMMhMhhhhhhhhhhMo", "oMMMhMMhhhhhhhhhMo",
		".oMMhMMMMhhhhhhMo.", ".oMMhMMMMhhhhhhMo.", "..oMMMMMMMhhhhMo..",
		"..oMMoMMMMMhhMo...", "...oo.oMMMMMo....", ".......ooooo....."
	], Vector2i(7 + lean, 2 + bob), p)
	_stamp(image, [
		"...ssss...", "..sFFFFss.", ".sFFFFFFFs", "sFFFFFFFFs", "sFFFFFFFFs",
		"sFFFFFFFFs", ".sFFFFFFs.", "..sFFFFs..", "...ssss..."
	], Vector2i(12 + lean, 9 + bob), p)
	_stamp(image, [
		"hhhLLLLhhhhhh", "hhhhLLLhhhhhh", "hhhhhhhHHhhhh", "hhhHhhhHHhhh.",
		"hhhHHhHH.Hh..", "hhHHhHH...H..", "hhHH.H.......", "hHH..........", "HH..........."
	], Vector2i(10 + lean, 5 + bob), p)
	# Deliberate 2x3 anime eyes with a dark lash, bright iris, single glint.
	var eye := Color("25313e")
	var iris := Color("419f9e")
	for v in [Vector2i(15, 12), Vector2i(16, 12), Vector2i(15, 13), Vector2i(16, 14), Vector2i(21, 12), Vector2i(22, 12), Vector2i(21, 14)]:
		_pixel(image, v + Vector2i(lean, bob), eye)
	_pixel(image, Vector2i(16 + lean, 13 + bob), iris)
	_pixel(image, Vector2i(21 + lean, 13 + bob), iris)
	_pixel(image, Vector2i(15 + lean, 13 + bob), Color("fff3df"))
	_pixel(image, Vector2i(21 + lean, 12 + bob), Color("fff3df"))
	_pixel(image, Vector2i(14 + lean, 15 + bob), Color("f4a49a"))
	_pixel(image, Vector2i(22 + lean, 15 + bob), Color("f4a49a"))
	_pixel(image, Vector2i(19 + lean, 16 + bob), Color("bb6d72"))
	# Tiny navy ribbon behind her temple.
	_stamp(image, ["oT.o", "oTTo", ".bo.", "oTTo", "oT.o"], Vector2i(7 + lean, 10 + bob), p)

static func _draw_boots(image: Image, step: int, p: Dictionary) -> void:
	var left_y := 25 - (1 if step > 0 else 0)
	var right_y := 25 - (1 if step < 0 else 0)
	_stamp(image, ["oBBo.", "oBkBo", "oBBBo"], Vector2i(12 - step, left_y), p)
	_stamp(image, ["oBBo.", "oBkBo", "oBBBo"], Vector2i(18 + step, right_y), p)

static func _draw_enemy(image: Image, kind: String, bob: int, lean: int, step: int) -> void:
	var p := {
		"o": Color("202435"), "D": Color("34394d"), "d": Color("515b6b"),
		"T": Color("80575e"), "t": Color("ad7774"), "B": Color("252d3f"),
		"k": Color("536076"), "M": Color("475362"), "H": Color("637581"),
		"h": Color("81929c"), "L": Color("b3c4c8"), "g": Color("c5a26b"),
		"e": Color("8ce9df"), "f": Color("d9ede4"), "r": Color("b85858")
	}
	if kind == "ranged":
		p["M"] = Color("49384f")
		p["H"] = Color("6e4566")
		p["h"] = Color("955b82")
		p["L"] = Color("bd7b9f")
		p["T"] = Color("55516c")
		p["t"] = Color("7d7b96")
		p["D"] = Color("34384f")
		p["d"] = Color("4b506c")
		p["e"] = Color("eab784")
	elif kind == "elite":
		p["M"] = Color("554750")
		p["H"] = Color("816a64")
		p["h"] = Color("ad8c75")
		p["L"] = Color("d3bc90")
		p["T"] = Color("7e3f52")
		p["t"] = Color("b5606c")
		p["D"] = Color("343348")
		p["d"] = Color("615066")
		p["e"] = Color("ffc17e")
	_draw_boots(image, step, p)
	_stamp(image, [
		"..ooTTTToo..", ".oTTtTTTtTTo", "oTTTTggTTTTTo", "oDdddddddddDo",
		".oDDDDgDDDDo.", ".oDdDDDDdDDo.", "oDDdDDDDdDDDo", ".ooDDDDDDDoo."
	], Vector2i(10 + lean / 2, 18), p)
	if kind == "ranged":
		_stamp(image, [
			".......ooo.......", "......oMHMo......", ".....oMHhHMo.....", "....oMHhhLHMo....",
			"...oMHhLhhhHMo...", "..oMHhLhhhhHHMo..", ".oMHhHoooooHHHMo.", "oMHhHoDDDDDoHHHMo",
			"oMHHoDDDDDDDHoHMo", "oMHHoDeDDeDDoHHMo", ".oMHoDDDDDDDHoMo.", ".oMHHoDDDDDHoHMo.",
			"..oMHoooooooHMo..", "...oMHhhhhHHMo...", "....ooMMMMMoo....", "......ooooo......"
		], Vector2i(7 + lean, 3 + bob), p)
		# Side charm and a rolled bolt case, still within the chibi silhouette.
		_stamp(image, [".go.", "oggo", ".go.", ".to.", ".To."], Vector2i(23 + lean / 2, 18), p)
	else:
		_stamp(image, [
			".....ooooooo.....", "...ooMHHHHHMoo...", "..oMHHhLLhhHHMo..", ".oMHHhLhhhHhhHMo.",
			"oMHHhLhhhhHhhhHMo", "oMHHhhhhhhHhhhHMo", "oMHHHhhhhHHhhhHMo", "oMHHHoooooooHHHMo",
			"oMHHHoDDDDDDDoHMo", "oMHHHoDeeDeeDoHMo", ".oMHHoooooooHHMo.", ".oMHHHHgHHHHHHMo.",
			"..oMHHHgHHHHHMo..", "...oMHHgHHHHMo...", "....ooMMMMMoo....", "......ooooo......"
		], Vector2i(7 + lean, 3 + bob), p)
		# Rivets and a chipped brow prevent a flat helmet read.
		_pixel(image, Vector2i(11 + lean, 10 + bob), p["L"])
		_pixel(image, Vector2i(22 + lean, 9 + bob), p["L"])
		if kind == "elite":
			_stamp(image, ["LHo....", "oLHo...", ".oLHHo.", "..oHHHo", "...oMMo"], Vector2i(5 + lean, 2 + bob), p)
			_stamp(image, ["....LHo", "...oLHo", ".oHHHo.", "oHHHo..", "oMMo..."], Vector2i(21 + lean, 2 + bob), p)
			_stamp(image, [".ggg.", "ogLgo", ".ogo."], Vector2i(15 + lean, 6 + bob), p)
		else:
			_stamp(image, [".rro", "rrto", "rTo.", "o..."], Vector2i(8 + lean, 17 + bob), p)

static func _draw_dummy(image: Image, bob: int, lean: int) -> void:
	var p := {"o": Color("34303b"), "M": Color("795747"), "H": Color("aa7c58"),
		"h": Color("cba06b"), "L": Color("ecd198"), "r": Color("a45259"),
		"D": Color("556c70"), "d": Color("81948b"), "B": Color("4d474a")}
	_stamp(image, ["oMHo", "oMHo", "oMHo", "oMHo", "oMHo", "oMHo", "oMHo", "oMHo", "oMHo"], Vector2i(15, 18), p)
	_stamp(image, ["....oBBo....", "..ooBHHBoo..", "ooBBHHHHBBoo"], Vector2i(11, 25), p)
	_stamp(image, ["..ooDDDDoo..", "ooDDddddDDoo", "oDDDDDDDDDDo", ".ooDDDDDDoo.", "..oDDDDDo...", "...oDDo....."], Vector2i(10 + lean / 2, 18), p)
	_stamp(image, [
		".....oooooo.....", "...ooHHHHHHoo...", "..oHHhLLLLhHHo..", ".oHhhLhhhhhhhHo.",
		"oHhhhhhrrhhhhHHo", "oHhhhrrLLrrhhHHo", "oHhhrLLrrLLrhHHo", "oHhhrLrHHrLrhHHo",
		"oHhhrLrHHrLrhHHo", "oHhhrLLrrLLrhHHo", "oHhhhrrLLrrhhHHo", ".oHhhhhrrhhhhHo.",
		"..oHHhhhhhhHHo..", "...ooHHHHHHoo...", ".....oooooo....."
	], Vector2i(8 + lean, 4 + bob), p)
	_stamp(image, ["oMHo", "oHLo", "oHLo", "oMHo"], Vector2i(7 + lean / 2, 19), p)
	_stamp(image, ["oMHo", "oHLo", "oHLo", "oMHo"], Vector2i(23 + lean / 2, 19), p)

static func _stamp(image: Image, rows: Array, origin: Vector2i, palette: Dictionary) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var key := row.substr(x, 1)
			if palette.has(key):
				_pixel(image, origin + Vector2i(x, y), palette[key])

static func _pixel(image: Image, at: Vector2i, color: Color) -> void:
	if at.x >= 0 and at.x < image.get_width() and at.y >= 0 and at.y < image.get_height():
		image.set_pixelv(at, color)

static func _flash(image: Image) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a > 0.0:
				image.set_pixel(x, y, c.lerp(Color("ffd6c7"), 0.36))

static func _fallen(source: Image) -> Image:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in 32:
		for x in 32:
			var c := source.get_pixel(x, y)
			if c.a > 0.0:
				var dx := 30 - y
				var dy := 15 + int(float(x) * 0.40)
				_pixel(image, Vector2i(dx, dy), c.darkened(0.16))
	return image


