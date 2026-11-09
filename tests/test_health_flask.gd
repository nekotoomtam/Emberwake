extends SceneTree
## Catches charge regeneration, lost stacked healing, refresh exploits and invalid-input mutation.
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func near(actual: float, expected: float, label: String) -> void:
	check(is_finite(actual) and absf(actual - expected) < 0.00001, label)

func finish() -> void:
	print("HEALTH_FLASK: %d checks; %s" % [checks, "PASS" if failures.is_empty() else "FAIL"])
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	if not ResourceLoader.exists("res://scripts/health_flask.gd"):
		check(false, "health flask model is required")
		finish()
		return
	var flask = load("res://scripts/health_flask.gd").new()
	var hp: float = flask.drink(0.0, 200.0)
	near(hp, 25.0, "first dose heals 25 immediately")
	check(flask.charges == 2, "first dose spends one charge")
	near(flask.rate(), 5.0, "single stream supplies 5 HP per second")
	hp = flask.advance(1.0, hp, 200.0)
	near(hp, 30.0, "one second reaches 30")
	hp = flask.advance(4.0, hp, 200.0)
	near(hp, 50.0, "five seconds reaches exactly 50")
	near(flask.rate(), 0.0, "stream expires at five seconds")
	check(flask.effects.is_empty(), "expired stream removed")
	near(flask.advance(1000.0, hp, 200.0), 50.0, "expired healing cannot repeat")
	check(flask.charges == 2, "elapsed time never regenerates charges")

	flask.reset()
	hp = flask.drink(0.0, 500.0)
	hp = flask.advance(2.0, hp, 500.0)
	hp = flask.drink(hp, 500.0)
	near(hp, 60.0, "second drink adds its own instant healing")
	near(flask.rate(), 10.0, "two overlapping streams add rates")
	hp = flask.advance(3.0, hp, 500.0)
	near(hp, 90.0, "old stream keeps all remaining three seconds")
	near(flask.rate(), 5.0, "old stream expires independently")
	hp = flask.advance(2.0, hp, 500.0)
	near(hp, 100.0, "both doses preserve all 100 potential HP")
	check(flask.effects.is_empty(), "both independent streams expire")
	hp = flask.drink(hp, 500.0)
	check(flask.charges == 0, "only three drinks per run")
	near(flask.drink(hp, 500.0), 125.0, "empty flask supplies no instant healing")
	check(flask.effects.size() == 1, "empty flask supplies no extra stream")
	near(flask.advance(999.0, hp, 500.0), 150.0, "coarse frame includes only five remaining seconds")
	check(flask.charges == 0, "coarse time does not supply free charges")

	flask.reset()
	near(flask.drink(100.0, 100.0), 100.0, "full HP drink unchanged")
	check(flask.charges == 3 and flask.effects.is_empty(), "full HP does not consume or start healing")
	hp = flask.drink(98.0, 100.0)
	near(hp, 100.0, "instant overheal capped")
	hp = flask.advance(2.0, hp, 100.0)
	near(hp, 100.0, "stream overheal capped")
	hp = flask.advance(1.0, 50.0, 100.0)
	near(hp, 55.0, "wasted overheal is not banked")
	hp = flask.advance(2.0, hp, 60.0)
	near(hp, 60.0, "reduced max HP caps existing stream")
	near(flask.rate(), 0.0, "cap does not prolong stream lifetime")
	near(flask.advance(1.0, 60.0, 40.0), 40.0, "max HP decrease clamps existing health")

	flask.reset()
	hp = flask.drink(0.0, 100.0)
	near(flask.advance(0.0, hp, 100.0), 25.0, "zero time heals nothing")
	near(flask.rate(), 5.0, "zero time retains stream")
	# Pausing means the owner does not call advance; state remains unchanged.
	near(flask.effects[0], 5.0, "uncalled paused model preserves duration")
	hp = flask.advance(0.25, hp, 100.0)
	near(hp, 26.25, "partial frame heals proportionally")
	hp = flask.advance(4.8, hp, 100.0)
	near(hp, 50.0, "partial expiry clamps final fractional interval")
	flask.drink(0.0, 100.0)
	flask.cancel_effects()
	check(flask.charges == 1 and flask.effects.is_empty(), "death cancellation clears streams without refund")
	near(flask.advance(10.0, 0.0, 100.0), 0.0, "cancelled healing cannot revive")
	flask.reset()
	check(flask.charges == 3 and flask.effects.is_empty(), "new run restores exactly three charges and clears streams")
	flask.drink(0.0, 100.0)
	flask.reset()
	near(flask.advance(20.0, 0.0, 100.0), 0.0, "reset removes active previous-run healing")

	for bad in [NAN, INF, -INF, -1.0]:
		flask.reset()
		flask.drink(bad, 100.0)
		check(flask.charges == 3 and flask.effects.is_empty(), "invalid current cannot consume: %s" % bad)
		flask.drink(0.0, bad)
		check(flask.charges == 3 and flask.effects.is_empty(), "invalid cap cannot consume: %s" % bad)
		flask.drink(0.0, 100.0)
		near(flask.advance(bad, 25.0, 100.0), 25.0, "invalid delta cannot heal: %s" % bad)
		near(flask.effects[0], 5.0, "invalid delta preserves duration: %s" % bad)
		flask.advance(1.0, bad, 100.0)
		near(flask.effects[0], 5.0, "invalid current preserves duration: %s" % bad)
		near(flask.advance(1.0, 25.0, bad), 25.0, "invalid cap cannot heal: %s" % bad)
		near(flask.effects[0], 5.0, "invalid cap preserves duration: %s" % bad)
	flask.reset()
	near(flask.drink(0.0, 0.0), 0.0, "zero cap cannot heal")
	check(flask.charges == 3, "zero cap cannot consume")
	finish()
