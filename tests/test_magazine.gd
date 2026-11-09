extends SceneTree

var checks := 0
var failures: Array[String] = []
var magazine_script: Script

func _initialize() -> void:
	_check(FileAccess.file_exists("res://scripts/magazine.gd"), "magazine module exists")
	if failures.is_empty():
		magazine_script = load("res://scripts/magazine.gd")
		_test_single_consume_and_empty()
		_test_partial_reload_exact_deadline()
		_test_pause_invalid_delta_and_overshoot()
		_test_reset_and_reconfigure()
		_test_invalid_configuration()
	if failures.is_empty():
		print("PASS: magazine (%d checks)" % checks)
	else:
		for failure in failures:
			push_error("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _near(actual: float, expected: float, message: String, tolerance := 0.0000001) -> void:
	_check(is_finite(actual) and absf(actual - expected) < tolerance, "%s (got %.9f, expected %.9f)" % [message, actual, expected])

func _magazine():
	return magazine_script.new()

func _test_single_consume_and_empty() -> void:
	# Catches consumption of multiple rounds, negative ammo and hidden autoreload.
	var magazine = _magazine()
	_check(magazine.capacity == 10 and magazine.rounds == 10, "default magazine starts with ten rounds")
	_near(magazine.reload_duration, 0.5, "default reload takes half a second")
	_check(not magazine.reloading and magazine.can_fire(), "full initial magazine permits firing")
	_check(not magazine.start_reload(), "full magazine refuses reload")
	_near(magazine.progress(), 0.0, "idle magazine reports no reload progress")
	for remaining in range(9, -1, -1):
		_check(magazine.can_fire(), "remaining round permits shot")
		_check(magazine.consume(), "one consume succeeds for each available round")
		_check(magazine.rounds == remaining, "one consume removes exactly one round")
	_check(not magazine.can_fire() and not magazine.consume(), "empty magazine refuses shot and further consumption")
	_check(magazine.rounds == 0 and not magazine.reloading, "empty magazine cannot autoreload itself")
	_check(not magazine.tick(10.0) and magazine.rounds == 0, "idle time cannot restore rounds")
	_check(magazine.start_reload(), "empty magazine accepts caller requested reload")
	_check(not magazine.can_fire() and not magazine.consume(), "empty reloading magazine refuses firing")

func _test_partial_reload_exact_deadline() -> void:
	# Catches premature refill, firing during reload and extending an active reload.
	var magazine = _magazine()
	magazine.consume()
	magazine.consume()
	_check(magazine.start_reload(), "partial magazine accepts manual reload")
	_check(magazine.reloading and magazine.rounds == 8, "reload retains current rounds until deadline")
	_check(not magazine.can_fire() and not magazine.consume(), "partial reload blocks firing without consuming")
	_check(not magazine.tick(0.25), "half reload does not complete")
	_near(magazine.progress(), 0.5, "half reload reports half progress")
	_check(not magazine.start_reload(), "second reload request cannot restart timer")
	_near(magazine.elapsed, 0.25, "rejected reload preserves timer")
	_check(magazine.rounds == 8, "half reload does not refill early")
	_check(not magazine.tick(0.249999999), "reload cannot complete just before exact deadline")
	_check(magazine.rounds == 8 and magazine.reloading, "near deadline still preserves rounds and lock")
	_check(magazine.tick(0.000000001), "reload completes at exact half second deadline")
	_check(magazine.rounds == 10 and not magazine.reloading and magazine.can_fire(), "completion refills and unlocks firing together")
	_near(magazine.elapsed, 0.5, "completion clamps reload elapsed")
	_near(magazine.progress(), 1.0, "completed reload reports full progress")
	_check(not magazine.tick(1.0), "completion event cannot repeat")
	_check(not magazine.start_reload(), "newly full magazine refuses redundant reload")
	_check(magazine.consume() and magazine.rounds == 9, "first shot after reload consumes once")
	_check(magazine.start_reload(), "later partial reload can start")
	_near(magazine.elapsed, 0.0, "new reload clears elapsed")
	_near(magazine.progress(), 0.0, "new reload clears progress")
	_check(magazine.tick(0.5), "one exact duration tick completes reload")

func _test_pause_invalid_delta_and_overshoot() -> void:
	# Catches progression while paused, corrupt timers and multiple big-step events.
	var magazine = _magazine()
	magazine.consume()
	magazine.start_reload()
	magazine.tick(0.2)
	for _frame in range(20):
		_check(not magazine.can_fire() and magazine.rounds == 9, "unticked paused reload retains rounds and firing lock")
	_near(magazine.elapsed, 0.2, "pause without ticking freezes elapsed")
	_near(magazine.progress(), 0.4, "pause without ticking freezes progress")
	for dt in [0.0, -0.1, NAN, INF, -INF]:
		_check(not magazine.tick(dt), "invalid or zero delta cannot complete reload")
		_near(magazine.elapsed, 0.2, "invalid delta preserves elapsed")
		_check(magazine.rounds == 9 and magazine.reloading, "invalid delta preserves ammo and reload state")
	_check(magazine.tick(1.0e300), "large finite delta completes reload once")
	_check(magazine.rounds == 10 and not magazine.reloading, "large finite delta refills once")
	_near(magazine.elapsed, 0.5, "large delta clamps time to reload duration")
	_near(magazine.progress(), 1.0, "large delta clamps progress")
	_check(not magazine.tick(1.0e300), "later large delta cannot repeat completion")

func _test_reset_and_reconfigure() -> void:
	# Catches reload carryover through a new run and fixed pistol-only timing.
	var magazine = _magazine()
	magazine.consume()
	magazine.start_reload()
	magazine.tick(0.3)
	magazine.reset()
	_check(magazine.rounds == 10 and not magazine.reloading and magazine.can_fire(), "run reset refills and cancels reload")
	_near(magazine.elapsed, 0.0, "run reset clears timer")
	_near(magazine.progress(), 0.0, "run reset clears progress")
	_check(not magazine.tick(9.0), "cancelled reload emits no delayed completion")
	magazine.consume()
	_check(magazine.configure({"magazine_capacity": 6, "reload_time": 1.2}), "new weapon config is accepted")
	_check(magazine.capacity == 6 and magazine.rounds == 6 and not magazine.reloading, "new weapon config refills configured capacity")
	_near(magazine.reload_duration, 1.2, "new weapon config sets reload duration")
	_near(magazine.elapsed, 0.0, "new weapon config resets timer")
	for _shot in range(6):
		_check(magazine.consume(), "configured weapon consumes each of six rounds")
	_check(not magazine.consume(), "configured weapon has no seventh round")
	_check(magazine.start_reload(), "configured empty magazine starts reload")
	_check(not magazine.tick(1.1999) and magazine.rounds == 0, "configured reload cannot use default short duration")
	_check(magazine.tick(0.0001) and magazine.rounds == 6, "configured reload completes at its own deadline")
	magazine.consume()
	magazine.start_reload()
	magazine.tick(0.2)
	_check(magazine.configure({"magazine_capacity": 3, "reload_time": 0.25}), "explicit reconfigure may replace active reload")
	_check(magazine.capacity == 3 and magazine.rounds == 3 and not magazine.reloading, "reconfigure clears previous weapon reload")
	_near(magazine.elapsed, 0.0, "reconfigure cancels old elapsed")
	magazine.consume()
	magazine.reset()
	_check(magazine.rounds == 3, "reset respects current configured capacity")
	_near(magazine.reload_duration, 0.25, "reset preserves current configured timing")
	_check(magazine.configure({}), "missing configuration fields use defaults")
	_check(magazine.capacity == 10 and magazine.rounds == 10, "default configure restores base ten-round magazine")
	_near(magazine.reload_duration, 0.5, "default configure restores base reload duration")

func _test_invalid_configuration() -> void:
	# Catches coercing invalid types and partially applying an invalid definition.
	var invalids: Array[Dictionary] = [
		{"magazine_capacity": 0}, {"magazine_capacity": -1},
		{"magazine_capacity": 2.5}, {"magazine_capacity": 6.0},
		{"magazine_capacity": "10"}, {"magazine_capacity": true},
		{"magazine_capacity": null}, {"magazine_capacity": INF},
		{"reload_time": 0.0}, {"reload_time": -0.5},
		{"reload_time": NAN}, {"reload_time": INF}, {"reload_time": -INF},
		{"reload_time": "0.5"}, {"reload_time": true}, {"reload_time": null},
		{"magazine_capacity": 6, "reload_time": -1.0},
		{"magazine_capacity": -1, "reload_time": 1.2},
	]
	var magazine = _magazine()
	magazine.consume()
	magazine.start_reload()
	magazine.tick(0.2)
	for definition in invalids:
		_check(not magazine.configure(definition), "invalid definition is refused")
		_check(magazine.capacity == 10 and magazine.rounds == 9 and magazine.reloading, "invalid configuration preserves capacity rounds and reload")
		_near(magazine.reload_duration, 0.5, "invalid configuration preserves duration")
		_near(magazine.elapsed, 0.2, "invalid configuration preserves elapsed")
	_check(magazine.configure({"magazine_capacity": 2, "reload_time": 1}), "integer positive reload duration is a valid number")
	_check(magazine.capacity == 2 and magazine.rounds == 2, "valid config after rejection refills correctly")
