extends SceneTree
## Walks the street graph the way the joystick does, without the rest of the game.
## godot --headless --path . -s tests/roads.gd

var failures := 0


func _initialize() -> void:
	var roads = load("res://scripts/roads.gd")
	var cut: float = roads.CUTS[1]
	var back: float = roads.BACK

	# Pushing right along the front street carries on to where it bends away
	var at := _walk(roads, Vector2(0.0, 0.0), Vector2.RIGHT, 400)
	_check(at.x > roads.SIDE - roads.BEND and at.y > -roads.BEND, "right along the front street ends on the bend, got %s" % at)

	# Standing on the shortcut's corner and pushing up takes it to the back road
	at = _walk(roads, Vector2(cut, 0.0), Vector2.UP, 400)
	_check(at.distance_to(Vector2(cut, back)) < 0.2, "up from the corner reaches the back road, got %s" % at)

	# Pushing up from a little short of the shortcut, or a little past it, still finds it
	for start: float in [cut - 3.0, cut + 3.0]:
		at = _walk(roads, Vector2(start, 0.0), Vector2.UP, 400)
		_check(at.distance_to(Vector2(cut, back)) < 0.2, "up from x=%.1f reaches the back road, got %s" % [start, at])

	# The same with the stick leaning away from the shortcut
	at = _walk(roads, Vector2(cut - 3.0, 0.0), Vector2(-0.4, -1.0).normalized(), 400)
	_check(at.y < -8.0, "up and a little left, short of the shortcut, still takes it, got %s" % at)

	# Far from any shortcut, pushing up does nothing
	at = _walk(roads, Vector2(10.0, 0.0), Vector2.UP, 60)
	_check(at.distance_to(Vector2(10.0, 0.0)) < 0.1, "up in the middle of a block stays put, got %s" % at)

	# Down the shortcut again from the back road
	at = _walk(roads, Vector2(cut, back), Vector2.DOWN, 400)
	_check(at.distance_to(Vector2(cut, 0.0)) < 0.2, "down from the back corner reaches the front street, got %s" % at)

	# Round the whole ring by turning the stick with the street: right, up, left, down
	at = Vector2(0.0, 0.0)
	for push: Vector2 in [Vector2.RIGHT, Vector2(1, -1).normalized(), Vector2.UP, Vector2(-1, -1).normalized(), Vector2.LEFT,
			Vector2(-1, 1).normalized(), Vector2.DOWN, Vector2(1, 1).normalized(), Vector2.RIGHT]:
		at = _walk(roads, at, push, 600)
	_check(at.x > roads.SIDE - roads.BEND and at.y > -roads.BEND, "a lap of the ring comes back round to the same bend, got %s" % at)
	# and it really went round: half way through it was on the back road
	var half := Vector2(0.0, 0.0)
	for push: Vector2 in [Vector2.RIGHT, Vector2(1, -1).normalized(), Vector2.UP]:
		half = _walk(roads, half, push, 600)
	half = _walk(roads, half, Vector2(-1, -1).normalized(), 30)
	half = _walk(roads, half, Vector2.LEFT, 100)
	_check(absf(half.y - back) < 0.2 and half.x < roads.SIDE - roads.BEND, "half a lap is on the back road, got %s" % half)

	# The shortest way between two far corners is found and followed
	at = Vector2(-50.0, 0.0)
	var goal := Vector2(50.0, back)
	for i in 3000:
		at = at.move_toward(roads.route(at, goal), 0.2)
	_check(at.distance_to(goal) < 0.3, "route gets from the front left to the back right, got %s" % at)

	print("roads: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


## Holds the stick one way for `steps` frames of a robot moving 0.2 a frame, and returns where it ends up.
func _walk(roads, from: Vector2, push: Vector2, steps: int) -> Vector2:
	var at: Vector2 = roads.snap(from)
	for i in steps:
		var goal: Vector2 = roads.steer(at, push)
		at = at.move_toward(roads.route(at, goal), 0.2)
	return at


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)
