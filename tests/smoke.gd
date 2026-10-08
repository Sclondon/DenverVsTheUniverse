extends SceneTree
## Plays whole runs on autopilot, far faster than real time, and reports how they went.
## godot --headless --path . -s tests/smoke.gd [-- --runs=5]
## Autoloads are not registered while this script compiles, so it names no game classes.
## Fails (exit code 1) if a run never ends, a state is never reached, or a rule is broken.

const STEP := 1.0 / 30.0
## Simulated seconds a single run may last before it counts as stuck.
const LIMIT := 1500.0

var main: Node
var runs := 4
var failures := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			runs = int(arg.trim_prefix("--runs="))
	main = load("res://main.tscn").instantiate()
	main.saving = false
	root.add_child(main)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + what)


## A passable player: sits under the lowest alien and sidesteps bombs about to land on it.
func _steer() -> void:
	var p = main.player
	var want: float = p.x
	var target = main.swarm.lowest()
	if target != null:
		want = target.pos.x
	for s in main.shots.list:
		if not s.friendly and s.kind != "crate" and s.pos.y < 7.5 and absf(s.pos.x - p.x) < 1.5:
			want = p.x + (2.2 if s.pos.x <= p.x else -2.2)
			if absf(want) > p.LIMIT:
				want = p.x - signf(want) * 2.2
	p.goal_x = want


func _run() -> void:
	await process_frame
	main.set_process(false)
	main.fx.muted = true
	root.get_node("Sfx").muted = true
	_check(main.state == main.State.TITLE, "starts on the title")
	_check(main.swarm.aliens.size() > 0, "title has a parade")
	var seen := {}
	var waves: Array[int] = []
	for r in runs:
		main.rng.seed = 100 + r
		main.swarm.rng.seed = 200 + r
		main.start_game()
		_check(main.state == main.State.PLAYING and main.wave == 1, "run starts on wave 1")
		# The jump is there from the first wave, and the range ring is the gun's reach whatever the robot is doing
		main.player.jump()
		main._process(STEP)
		main._process(STEP)
		_check(main.player.y > 0.2, "the robot can jump from the start")
		main.player._recoil = 1.0
		main._process(STEP)
		var ring: Transform3D = main.player._ring.global_transform
		_check(absf(ring.basis.get_scale().x - main.player.aim_range) < 0.01, "the range ring is as wide as the reach")
		_check(absf(ring.origin.x - main.player.x - 0.79) < 0.05, "the range ring is centred on the gun")
		_check(main.city.standing() == main.city.buildings.size() and main.player.hearts == 6, "run starts with a whole city")
		var t := 0.0
		var frames := 0
		while main.state != main.State.OVER and t < LIMIT:
			if main.state == main.State.PLAYING:
				_steer()
			elif main.state == main.State.PICK:
				_check(main.offer.size() >= 1 and main.offer.size() <= 3, "cards on offer")
				var ids := {}
				for u in main.offer:
					ids[u.id] = true
					seen[u.id] = true
				_check(ids.size() == main.offer.size(), "cards are all different")
				var before: int = main.wave
				main.pick_card(main.rng.randi() % main.offer.size())
				_check(main.state == main.State.SHOP, "picking opens the workshop")
				main._buy_tech(["ray", "lift", "alloy"][main.rng.randi() % 3])
				main._buy_shop("heart")
				main._leave_shop()
				_check(main.wave == before + 1 and main.state == main.State.PLAYING, "leaving the workshop starts the next wave")
			for a in main.swarm.aliens:
				seen[a.kind] = true
			main._process(STEP)
			t += STEP
			frames += 1
			if frames % 600 == 0:
				# Let queued frees and effect timers run so nodes don't pile up.
				await process_frame
		_check(main.state == main.State.OVER, "run %d ends (wave %d after %.0fs)" % [r, main.wave, t])
		_check(main.player.hearts <= 0 or main.city.fallen(), "it ended for a reason")
		print("run %d: wave %d, score %d, %.0fs, city %d%%, hearts %d, upgrades %s" % [
				r, main.wave, main.score, t, main.city.percent(), main.player.hearts, main.levels])
		waves.append(main.wave)
		await process_frame
	# Every invasion has figures of its own, and all of them load and take the field
	main.start_game()
	var used := {}
	for inv: Dictionary in main.swarm.INVASIONS:
		for kind: String in inv.ranks + [inv.kaiju]:
			_check(not used.has(kind), "%s belongs to one invasion only" % kind)
			used[kind] = true
			var a = main.swarm.spawn(kind, Vector2(0.0, 8.0))
			_check(a.body != null, "%s has a model" % kind)
			if a.def.has("splits"):
				_check(main.swarm.spawn(a.def.splits, Vector2(2.0, 8.0)).body != null, "%s has a model" % a.def.splits)
	for n: int in [7, 9, 12, 14, 15, 17, 19, 22, 24, 25]:
		main.wave = n
		main.swarm.spawn_wave(n)
		for i in 60:
			main.swarm.update(STEP)
	# The robot holds its fire until something is inside its ring
	main.swarm.clear()
	main.shots.clear()
	for i in 40:
		main.player.update(STEP, true)
	_check(main.shots.list.is_empty(), "nothing in range, nothing fired")
	var far = main.swarm.spawn("grunt", Vector2(main.player.x + main.player.aim_range + 8.0, 6.0))
	for i in 40:
		main.player.update(STEP, true)
	_check(main.shots.list.is_empty(), "an alien out of range is not shot at")
	far.pos.x = main.player.x + 3.0
	for i in 40:
		main.player.update(STEP, true)
	_check(not main.shots.list.is_empty(), "an alien in range is shot at")
	# On a phone held upright the sky is much taller: a wingman must still reach the top row
	var sky: float = main.diorama.play_top
	main.diorama.play_top = 22.0
	main.swarm.clear()
	main.shots.clear()
	var mate = main.wingmen[0]
	main.swarm.spawn("grunt", Vector2(mate.x, 21.2))
	for i in 60:
		mate.update(STEP, true)
	_check(not main.shots.list.is_empty(), "a wingman reaches the top row of a tall sky")
	main.diorama.play_top = sky
	for kind in ["grunt", "crab", "diver", "spitter", "saucer", "boss"]:
		_check(seen.has(kind), "saw a %s" % kind)
	_check(waves.max() >= 5, "autopilot reaches the first mothership")
	print("smoke: %d failure(s); waves reached %s; cards seen %d" % [failures, waves, seen.size()])
	quit(1 if failures > 0 else 0)
