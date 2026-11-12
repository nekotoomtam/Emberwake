extends RefCounted

const RifleSkills = preload("res://scripts/rifle_motion.gd")
static var _textures: Dictionary = {}

static func texture(round_id: String = "") -> Texture2D:
	if _textures.has(round_id): return _textures[round_id]
	var art := Image.create(12, 24, false, Image.FORMAT_RGBA8)
	art.fill(Color.TRANSPARENT)
	var outline := Color("#3d2b29")
	art.fill_rect(Rect2i(5, 0, 2, 2), outline)
	art.fill_rect(Rect2i(4, 2, 4, 3), outline)
	art.fill_rect(Rect2i(3, 5, 6, 5), outline)
	art.fill_rect(Rect2i(2, 10, 8, 2), outline)
	art.fill_rect(Rect2i(1, 12, 10, 10), outline)
	art.fill_rect(Rect2i(0, 22, 12, 2), outline)
	art.fill_rect(Rect2i(5, 2, 2, 3), Color("#f3bc87"))
	art.fill_rect(Rect2i(4, 5, 4, 5), Color("#d58d60"))
	art.fill_rect(Rect2i(5, 5, 1, 5), Color("#ffe1aa"))
	art.fill_rect(Rect2i(3, 10, 6, 2), Color("#c8914f"))
	art.fill_rect(Rect2i(2, 12, 8, 9), Color("#c39142"))
	art.fill_rect(Rect2i(3, 12, 2, 9), Color("#ffdb85"))
	art.fill_rect(Rect2i(8, 12, 2, 9), Color("#8d633b"))
	art.fill_rect(Rect2i(1, 22, 10, 1), Color("#e8bd6a"))
	if round_id == RifleSkills.PIERCING_ROUND_ID:
		art.fill_rect(Rect2i(5, 0, 2, 2), Color("#b8dfe8"))
		art.fill_rect(Rect2i(5, 2, 2, 3), Color("#eefaff"))
		art.fill_rect(Rect2i(4, 5, 4, 5), Color("#9dc8d6"))
		art.fill_rect(Rect2i(5, 5, 1, 5), Color("#effdff"))
		art.fill_rect(Rect2i(2, 13, 8, 3), Color("#519ebc"))
		art.fill_rect(Rect2i(3, 13, 2, 3), Color("#c5f4ff"))
	elif round_id == RifleSkills.ARMOR_ROUND_ID:
		art.fill_rect(Rect2i(5, 2, 2, 3), Color("#fff0b0"))
		art.fill_rect(Rect2i(4, 5, 4, 5), Color("#e7aa58"))
		art.fill_rect(Rect2i(2, 13, 8, 4), Color("#984c29"))
		art.fill_rect(Rect2i(3, 14, 6, 2), Color("#ffdf87"))
	elif round_id == RifleSkills.MARK_ROUND_ID:
		art.fill_rect(Rect2i(5, 2, 2, 3), Color("#ffd5ff"))
		art.fill_rect(Rect2i(4, 5, 4, 5), Color("#ae72c8"))
		art.fill_rect(Rect2i(2, 13, 8, 5), Color("#5b336e"))
		art.fill_rect(Rect2i(5, 13, 2, 5), Color("#e7acff"))
		art.fill_rect(Rect2i(4, 15, 4, 1), Color("#fff1ff"))
	elif round_id == RifleSkills.SCATTER_ROUND_ID:
		art.fill_rect(Rect2i(3, 5, 6, 5), Color("#547344"))
		art.fill_rect(Rect2i(4, 5, 4, 1), Color("#d5f8b8"))
		art.fill_rect(Rect2i(2, 12, 8, 8), Color("#396444"))
		art.fill_rect(Rect2i(3, 13, 2, 6), Color("#a7dc88"))
	elif round_id == RifleSkills.SPLIT_ROUND_ID:
		art.fill_rect(Rect2i(4, 5, 4, 5), Color("#d57a51"))
		art.fill_rect(Rect2i(3, 12, 6, 7), Color("#9f5035"))
		art.fill_rect(Rect2i(5, 13, 2, 2), Color("#ffd3a0"))
		art.fill_rect(Rect2i(4, 16, 1, 2), Color("#ffd3a0"))
		art.fill_rect(Rect2i(7, 16, 1, 2), Color("#ffd3a0"))
	elif round_id == RifleSkills.FINISHER_ID:
		art.fill_rect(Rect2i(5, 2, 2, 3), Color("#e6ffff"))
		art.fill_rect(Rect2i(4, 5, 4, 5), Color("#9ed5ee"))
		art.fill_rect(Rect2i(2, 12, 8, 8), Color("#233c55"))
		art.fill_rect(Rect2i(5, 12, 2, 8), Color("#c0eeff"))
	var result := ImageTexture.create_from_image(art)
	_textures[round_id] = result
	return result
