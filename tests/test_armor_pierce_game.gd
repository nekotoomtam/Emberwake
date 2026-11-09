extends SceneTree
## Real-controller acceptance: physical E/Space, real enemies, resolved damage and collision.
## Removing delayed stab contact, post-hit armor, cancellation, LOS or lunge clipping breaks these cases.
const STEP := 1.0 / 120.0
var game
var checks := 0
var failures: Array[String] = []
var barriers: Array[Node] = []
class ContactCallbackEnemy extends "res://scripts/enemy.gd":
	# Keep the real Enemy damage path; expose a synchronous downstream callback.
	var after_damage: Callable
	func receive_damage(amount: float, force: Vector3) -> void:
		super.receive_damage(amount, force)
		if after_damage.is_valid(): after_damage.call()

func _initialize() -> void: call_deferred("run_tests")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)
func close(actual: float, expected: float, message: String, epsilon: float = .001) -> void:
	check(absf(actual - expected) <= epsilon, "%s (got %.6f, expected %.6f)" % [message, actual, expected])
func run_tests() -> void:
	Engine.physics_ticks_per_second = 120
	game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_physics_process(false)
	check(game.has_method("request_armor_skill"), "controller exposes Armor Pierce request API")
	await fresh()
	check(dummy().has_method("effective_armor") and dummy().has_method("apply_armor_break"), "real Enemy exposes armor API")
	press(KEY_E)
	check(game.skill_active, "physical E starts Sword Armor Pierce")
	if game.has_method("request_armor_skill") and dummy().has_method("effective_armor"):
		await contacts_and_damage()
		await gates()
		await cancellation()
		await movement_and_geometry()
		await armor_lifetime()
		await contact_order_regressions()
		await lifecycle()
		await regression()
	game.queue_free()
	await process_frame
	print("ARMOR PIERCE GAME TESTS: %d/%d passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
func fresh(family: String = "sword", offset: Vector3 = Vector3(1.2, 0, 0)) -> void:
	for barrier in barriers:
		if is_instance_valid(barrier): barrier.queue_free()
	barriers.clear()
	game.start_run(true)
	game.set_physics_process(false)
	check(game.set_weapon_family(family), "fixture selects " + family)
	game.test_aim = Vector3.RIGHT
	game.move_input = Vector2.ZERO
	dummy().position = game.player.position + offset
	await tick()
func dummy():
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.kind == "dummy" and not enemy.dead: return enemy
	return null
func tick(delta: float = STEP) -> void:
	await physics_frame
	game.tick(delta)
func step(seconds: float) -> void:
	for i in range(int(ceil(seconds / STEP))): await tick()
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event, true)
	Input.flush_buffered_events()
func press(code: Key) -> void:
	key(code, true)
	key(code, false)
func seek(cut: int, phase: String) -> bool:
	for i in range(300):
		if game.skill_active and game.skill_cut_index == cut and game.motion.sample().phase == phase: return true
		await tick()
	check(false, "reaches E stage %d %s" % [cut, phase])
	return false
func recover() -> void:
	for i in range(300):
		if not game.motion.busy and not game.skill_active: return
		await tick()
	check(false, "committed action completes")
func hit_count(count: int) -> bool:
	for i in range(300):
		if game.hits >= count: return true
		await tick()
	check(false, "real contacts reach %d hits" % count)
	return false
func contacts_and_damage() -> void:
	await fresh()
	var target = dummy()
	close(target.health, 1000, "fixture keeps real dummy health")
	close(target.armor_rating, 100, "baseline enemy armor preserves old damage")
	press(KEY_E)
	check(game.active_skill_id == "armor_pierce" and game.skill_cut_index == 0, "E identifies the first stage of Armor Pierce")
	check(not game.request_armor_skill() and not game.request_skill() and not game.request_attack(), "E refuses overlapping E/Q/basic")
	await tick(.12)
	check(game.hits == 0 and target.armor_break_remaining == 0, "first windup causes neither damage nor break")
	await hit_count(1)
	close(game.total_damage, 18, "first slash has ordinary 18 damage")
	close(target.health, 982, "first slash reduces real health once")
	close(target.effective_armor(), 100, "first slash applies no armor break")
	await seek(1, "windup")
	close(target.armor_break_remaining, 0, "automatic stab windup has no early break")
	await seek(1, "active")
	check(game.hits == 1 and target.armor_break_remaining == 0, "stab active begins harmless before .8 contact")
	await hit_count(2)
	close(game.total_damage, 42, "stab resolves 24 before applying its own break")
	close(target.health, 958, "actual health receives exactly 18 plus 24")
	close(target.effective_armor(), 80, "contact changes effective armor to 80")
	close(target.armor_break_fraction, .2, "contact stores twenty percent break")
	check(target.armor_break_remaining > 3.97 and target.armor_break_remaining <= 4, "contact begins four simulation seconds of break")
	await recover()
	check(not game.skill_active and game.active_skill_id == "" and game.skill_cut_index == -1, "both stages finish and restore generic controller state")
	close(game.stamina, 100, "E costs no stamina")
	check(game.request_attack() and not game.skill_active, "ordinary Sword attack resumes after E")
	await hit_count(3)
	close(game.total_damage, 64.5, "later physical basic 18 resolves as 22.5")
	close(target.health, 935.5, "later physical real health agrees with actual damage counter")
	await recover()
	check(game.set_weapon_family("staff"), "real Staff may follow finished E")
	check(game.request_attack(), "real fire projectile starts after armor break")
	await hit_count(4)
	close(game.total_damage, 136.5, "real 72 fire damage ignores reduced physical armor")
	check(game.hits == 4, "real contacts count E slash, stab, ordinary physical and fire")
	await fresh("sword", Vector3(8, 0, 0))
	press(KEY_E)
	await tick(1.1)
	check(not game.skill_active and game.hits == 0, "large frame completes both empty stages")
	check(game.request_armor_skill(), "E reusable immediately without cooldown")
	await fresh()
	press(KEY_E)
	await tick(1.1)
	check(not game.skill_active and game.hits == 2, "one large frame delivers both contacts exactly once")
	close(game.total_damage, 42, "large-frame total preserves damage-before-break order")
	await fresh()
	var adjacent = game.spawn_enemy("dummy", game.player.position + Vector3(1.2, 0, .15))
	press(KEY_E)
	await recover()
	check(game.hits == 4, "each of two real targets receives each E stage exactly once")
	close(game.total_damage, 84, "two-target contacts resolve four actual damage events")
	check(adjacent.armor_break_remaining > 0 and dummy().armor_break_remaining > 0, "stab breaks each contacted target")
func gates() -> void:
	for family in ["greatsword", "mace", "staff", "pistol", "rifle"]:
		await fresh(family)
		press(KEY_E)
		check(not game.skill_active and not game.request_armor_skill() and not game.motion.busy, family + " refuses Sword-only E")
	for mode in ["paused", "menu", "dead", "victory"]:
		await fresh()
		game.mode = mode
		press(KEY_E)
		check(not game.skill_active and not game.request_armor_skill(), mode + " refuses E")
	await fresh()
	game.health = 0
	check(not game.request_armor_skill(), "zero health refuses E before death transition")
	await fresh()
	check(game.request_attack() and not game.request_armor_skill(), "ordinary busy attack refuses E")
	await fresh()
	check(game.request_dodge() and not game.request_armor_skill(), "active dodge refuses E")
	await fresh()
	press(KEY_F)
	check(game.active_skill_id == "twin_cut" and not game.request_armor_skill(), "Twin Cut identity and busy gate retained")
func cancellation() -> void:
	for cut in [0, 1]:
		for phase in ["windup", "active", "recovery"]:
			await fresh()
			press(KEY_E)
			if not await seek(cut, phase): continue
			var before_hits: int = game.hits
			var broken: bool = dummy().armor_break_remaining > 0
			press(KEY_SPACE)
			check(not game.skill_active and not game.motion.busy and game.active_skill_id == "", "Space cancels E stage %d %s" % [cut, phase])
			check(game._dodge_left > 0 and game._hit_stop == 0, "Space immediately starts dodge and clears hitstop")
			var travel: float = game.armor_lunge_travelled
			await step(1.1)
			check(game.hits == before_hits and not game.skill_active, "cancelled E never resurrects queued stab or extra damage")
			close(game.armor_lunge_travelled, travel, "cancelled E stops remaining lunge")
			check((dummy().armor_break_remaining > 0) == broken, "Space preserves applied break and creates no uncontacted break")
	await fresh()
	press(KEY_E)
	await hit_count(2)
	check(game._hit_stop > 0, "stab contact produces real hitstop")
	press(KEY_SPACE)
	check(not game.skill_active and dummy().armor_break_remaining > 3.9, "contact-hitstop Space preserves already applied break")
	for reason in ["stamina", "recharge", "paused", "dead", "menu", "already"]:
		await fresh("sword", Vector3(8, 0, 0))
		press(KEY_E)
		await tick(.05)
		if reason == "stamina": game.stamina = 0
		elif reason == "recharge": game._dodge_recharge = .2
		elif reason == "already": game._dodge_left = .1
		else: game.mode = reason
		var elapsed: float = game.motion.elapsed
		var stamina: float = game.stamina
		press(KEY_SPACE)
		check(game.skill_active and game.motion.busy and game.motion.elapsed == elapsed and game.stamina == stamina, reason + " failed Space leaves E and resources untouched")
func add_cover(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	game.add_child(body)
	body.position = center
	barriers.append(body)
	await tick()
func movement_and_geometry() -> void:
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		await fresh("sword", direction * 8)
		game.test_aim = direction
		press(KEY_E)
		await seek(1, "windup")
		var start: Vector3 = game.player.position
		game.test_aim = -direction
		game.move_input = Vector2(direction.x, direction.z)
		await seek(1, "recovery")
		var displacement: Vector3 = game.player.position - start
		close(displacement.dot(direction), .65, "stab has only .65 lunge with movement held toward " + str(direction), .003)
		close(game.armor_lunge_travelled, .65, "actual lunge telemetry reaches authored budget")
		check(absf(displacement.cross(direction).y) < .003, "committed aim remains locked throughout stab")
		check(game._iframes == 0 and game._dodge_left == 0, "E lunge grants no invulnerability or dodge")
		await step(.15)
		close(game.player.position.distance_to(start + displacement), 0, "ordinary walking stays locked through stab recovery")
		await recover()
	# Off-axis target can receive the broad slash, but never the narrow stab.
	await fresh("sword", Vector3(1.5, 0, .85))
	press(KEY_E)
	await recover()
	check(game.hits == 1, "off-axis target receives broad slash only")
	close(game.total_damage, 18, "off-axis lane rejects stab damage")
	close(dummy().armor_break_remaining, 0, "off-axis lane rejects armor break")
	# A rectangular expanded bounding box incorrectly accepts this far corner.
	await fresh("sword", Vector3(3.18, 0, .61))
	press(KEY_E)
	await recover()
	check(game.hits == 0 and dummy().armor_break_remaining == 0, "rounded lane rejects diagonal point outside endpoint radius")
	await fresh("sword", Vector3(3.1, 0, .45))
	press(KEY_E)
	await recover()
	check(game.hits == 1 and dummy().armor_break_remaining > 0, "rounded lane accepts diagonal point inside endpoint radius")
	# Far lane target is only reached after the authored lunge.
	await fresh("sword", Vector3(2.9, 0, 0))
	press(KEY_E)
	await hit_count(1)
	close(game.total_damage, 24, "forward lane reaches with lunge while first slash misses")
	check(dummy().armor_break_remaining > 0, "forward lane contact applies break")
	await fresh("sword", Vector3(.85, 0, 0))
	var start: Vector3 = game.player.position
	press(KEY_E)
	await recover()
	check(game.player.position.x - start.x < .12 and dummy().position.x - game.player.position.x >= .735, "living target clips lunge without overlap")
	check(game.hits == 2, "target-clipped lunge retains both valid contacts")
	await fresh("sword", Vector3(1.4, 0, 0))
	await add_cover(game.player.position + Vector3(.7, .8, 0), Vector3(.16, 1.6, 2))
	press(KEY_E)
	await recover()
	check(game.hits == 0 and game.total_damage == 0, "world mask one cover blocks BOTH slash and stab")
	close(dummy().armor_break_remaining, 0, "cover never grants remote break")
	check(game.armor_lunge_travelled < .35, "world collision clips actual lunge")
	await fresh("sword", Vector3(8, 0, 0))
	game.player.position = Vector3(11.4, .03, 0)
	press(KEY_E)
	await tick(1.1)
	check(game.player.position.x <= 11.6001 and game.armor_lunge_travelled <= .2001, "large-frame lunge obeys world boundary and reports clipped travel")
func armor_lifetime() -> void:
	await fresh()
	var target = dummy()
	press(KEY_E)
	await hit_count(2)
	await recover()
	await step(.25)
	close(target.health, 1000, "real practice dummy heals after idle")
	check(target.armor_break_remaining > 0 and target.effective_armor() == 80, "practice healing preserves armor break")
	var remaining: float = target.armor_break_remaining
	press(KEY_ESCAPE)
	check(game.mode == "paused", "physical Escape pauses simulation")
	await tick(2)
	close(target.armor_break_remaining, remaining, "paused simulation does not spend break timer")
	press(KEY_ESCAPE)
	await tick(.1)
	check(target.armor_break_remaining < remaining, "unpause resumes break timer")
	press(KEY_E)
	await hit_count(4)
	close(game.total_damage, 94.5, "second E deals 22.5 plus 30 against existing break")
	close(target.effective_armor(), 80, "refresh does not stack armor reductions")
	check(target.armor_break_remaining > 3.97, "second stab refreshes full duration")
	await recover()
	await step(4.1)
	close(target.armor_break_remaining, 0, "break expires after simulation duration")
	close(target.armor_break_fraction, 0, "expiry clears stored fraction")
	close(target.effective_armor(), 100, "expiry restores baseline physical armor")
	var before: float = game.total_damage
	check(game.request_attack(), "post-expiry ordinary attack starts")
	await hit_count(5)
	close(game.total_damage - before, 18, "post-expiry actual ordinary damage returns to 18")
func lifecycle() -> void:
	for action in ["restart", "clear", "death"]:
		await fresh()
		press(KEY_E)
		await seek(1, "windup")
		if action == "restart": game.restart()
		elif action == "clear": game.clear_actors()
		else: game.damage_player(1000)
		check(not game.skill_active and game.active_skill_id == "", action + " cancels pending E")
		var hits: int = game.hits
		await step(1.1)
		check(game.hits == hits and not game.skill_active, action + " leaves no queued stab")
	await fresh()
	var target = dummy()
	press(KEY_E)
	await hit_count(2)
	game.enemy_hit(target, 2000, Vector3.ZERO)
	check(target.dead and target.armor_break_remaining == 0 and target.armor_break_fraction == 0, "real enemy death clears break status")
func gold_break_count() -> int:
	var count := 0
	for entry in game.fx.trails:
		if entry.color.is_equal_approx(Color(1, .72, .22, 1)): count += 1
	return count
func contact_order_regressions() -> void:
	# Existing status expiring within this exact step cannot discount endpoint damage.
	await fresh()
	press(KEY_E)
	await seek(1, "active")
	var target = dummy()
	check(target.apply_armor_break(.2, .05), "contact-expiry fixture starts real finite break")
	var before: float = game.total_damage
	await tick(.104)
	close(game.total_damage - before, 24, "prior break expiring before stab endpoint does not amplify contact")
	close(target.armor_break_remaining, 4, "new break begins full duration after expired prior status")
	# Cancellation from a real resolved-damage callback invalidates pending status/FX.
	for action in ["space", "death", "restart"]:
		await fresh()
		game.clear_actors()
		var actor = ContactCallbackEnemy.new()
		actor.kind = "dummy"
		actor.position = game.player.position + Vector3(1.2, 0, 0)
		game.add_child(actor)
		game.enemies.append(actor)
		press(KEY_E)
		await seek(1, "active")
		var observed := {"called": false, "health_after_hit": 0.0}
		actor.after_damage = func():
			observed.called = true
			observed.health_after_hit = actor.health
			if action == "space": press(KEY_SPACE)
			elif action == "death": game.damage_player(1000)
			else: game.restart()
		await tick(.104)
		check(observed.called, action + " runs synchronously from real stab damage")
		close(observed.health_after_hit, 958, action + " preserves the already committed 18 plus 24 health damage")
		check(not game.skill_active and game.active_skill_id == "", action + " callback cancels current cast")
		close(actor.armor_break_remaining, 0, action + " callback blocks uncommitted new armor break")
		check(gold_break_count() == 0, action + " callback blocks stale gold armor-break FX")
		actor.after_damage = Callable()
		await step(.8)
		check(not game.skill_active and gold_break_count() == 0, action + " leaves no later status/FX resurrection")
func regression() -> void:
	await fresh()
	press(KEY_F)
	await hit_count(2)
	close(game.total_damage, 37, "Q retains old 18 plus 19 two-hit damage")
	close(dummy().armor_break_remaining, 0, "Q cannot apply E armor break")
	await recover()
	await fresh("sword", Vector3(8, 0, 0))
	check(game.request_attack(), "ordinary Sword timing fixture starts")
	await tick(.129)
	check(game.motion.sample().phase == "windup", "ordinary first Sword retains .13 windup")
	await tick(.002)
	check(game.motion.sample().phase == "active", "ordinary first Sword enters active after .13")
	await tick(.29)
	check(not game.motion.busy, "ordinary first Sword retains .42 total duration")
