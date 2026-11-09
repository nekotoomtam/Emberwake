extends SceneTree
func _initialize() -> void:
	var sword = load("res://scripts/sword_motion.gd").new()
	var skill = load("res://scripts/twin_cut_motion.gd").new()
	var expected = [[.13,.11,.18,18.0,2.1],[.14,.12,.20,19.0,2.2],[.25,.16,.28,34.0,2.55]]
	var passed := 0
	for i in range(3):
		var a: Dictionary = sword.definition(i)
		for n in range(5):
			if is_equal_approx(float(a[["windup","active","recovery","damage","reach"][n]]),expected[i][n]): passed += 1
	if is_equal_approx(float(skill.definition(0).windup),.055) and is_equal_approx(float(skill.definition(1).windup),.040): passed += 1
	print("SWORD PACE TESTS: %d/16 passed" % passed)
	quit(0 if passed == 16 else 1)
