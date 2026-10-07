class_name Swarm
extends Node3D
## Every alien on the table. A wave is a few big aliens, not a crowd: they arrive as one squad per
## district under attack, each squad marching Space Invaders style (sideways, down a step at each
## edge, faster as it thins) over its own part of town. Some kinds break ranks.

const STEP_X := 0.5
const STEP_DOWN := 0.7
## How far either side of its district a squad marches.
const REACH := 6.4
const SPACING := Vector2(2.9, 2.7)
## A marching alien whose feet get this low without hitting a rooftop first crashes into the street.
const LAND_Y := 0.5
## The sky height STEP_DOWN was tuned for; a taller sky takes bigger steps so the march lasts as long.
const TUNED_TOP := 12.4
const RAY_CHARGE := 1.2
const RAY_FIRE := 0.6

## The wave on which each kind first shows up.
const DEBUTS := {2: "crab", 3: "diver", 4: "spitter", 6: "splitter", 8: "brute"}


class Squad:
	var centre := 0.0
	var origin := Vector2.ZERO
	var goal := Vector2.ZERO
	var dir := 1.0
	var total := 1
	var tick := 0.0
	var lean := 1.0
	var bomb_t := 3.0
	var dive_t := 4.0


var game
var aliens: Array[Alien] = []
var squads: Array[Squad] = []
var wave := 1
var hp_scale := 1.0
## Title-screen parade: marches but never descends or attacks.
var peaceful := false
var rng := RandomNumberGenerator.new()

var _top := TUNED_TOP
var _beat := 0
var _grace := 0.0
var _saucer_t := 12.0
var _time := 0.0


func clear() -> void:
	for a in aliens:
		a.dead = true
		a.queue_free()
	aliens.clear()
	squads.clear()


func cleared() -> bool:
	return aliens.is_empty()


func spawn(kind: String, at: Vector2, mode := Alien.Mode.FORM) -> Alien:
	var a := Alien.new()
	a.init(kind, hp_scale)
	a.mode = mode
	a.pos = at
	a.phase = rng.randf() * TAU
	a.position = Vector3(at.x, at.y, 0.0)
	add_child(a)
	aliens.append(a)
	return a


func remove(a: Alien) -> void:
	a.dead = true
	aliens.erase(a)
	a.queue_free()


func spawn_wave(n: int) -> void:
	clear()
	wave = n
	_top = game.diorama.play_top
	peaceful = false
	# Gentle at first, then steep: past wave 12 the aliens toughen faster than any build can keep up with forever
	hp_scale = 1.0 + maxf(0.0, n - 5) * 0.18 + pow(maxf(0.0, n - 12), 2.0) * 0.05
	var boss := n % 5 == 0
	# They strike the neighbourhoods nearest the robot: the nearest one at first, then one of the
	# nearest two, then two or three at once
	var near: Array = Diorama.TOWNS.duplicate()
	var from: float = game.player.x
	near.sort_custom(func(a: float, b: float) -> bool: return absf(a - from) < absf(b - from))
	var where: Array = [0]
	if boss:
		where = [] if n == 5 else [1, 2]
	elif n > 7:
		where = [0, 1, 2]
	elif n > 4:
		where = [[0, 1], [0, 2]][rng.randi() % 2]
	elif n > 2:
		where = [rng.randi() % 2]
	for d: int in where:
		var cols := clampi(2 + n / 4, 2, 4) - (1 if where.size() > 2 else 0)
		_squad(near[d], cols, 1 if n < 7 else 2, _row_kinds(n))
	# From the fourth wave a toy kaiju drops onto the street as well, two of them later on
	if n >= 4 and not boss:
		for i in (1 if n < 9 else 2):
			var k := spawn("kaiju", Vector2(clampf(near[0] + rng.randf_range(-9.0, 9.0), -City.HALF + 4.0, City.HALF - 4.0), _top + 5.0 + i * 4.0), Alien.Mode.GROUND)
			k.flip = 1.0
			k.t = 2.5
	_grace = 1.6
	_saucer_t = 10.0
	if boss:
		var b := spawn("boss", Vector2(0.0, _top + 5.0), Alien.Mode.BOSS)
		b.max_hp = ceilf(float(Alien.TYPES.boss.hp) * (n / 5) * hp_scale)
		b.hp = b.max_hp
		b.flip = 1.0
		b.t = 3.0


## The harmless parade behind the title.
func spawn_parade() -> void:
	clear()
	wave = 1
	hp_scale = 1.0
	peaceful = true
	_top = 9.4
	_squad(0.0, 4, 1, ["grunt", "grunt"])
	_grace = 0.5


func update(delta: float) -> void:
	_time += delta
	_grace = maxf(0.0, _grace - delta)
	var player: Tank = game.player
	for squad in squads:
		var form: Array[Alien] = []
		for a in aliens:
			if a.mode == Alien.Mode.FORM and a.squad == squad:
				form.append(a)
		if form.is_empty():
			continue
		if _grace <= 0.0:
			squad.tick -= delta
			if squad.tick <= 0.0:
				squad.tick = maxf(0.2, 0.85 - 0.035 * wave) * lerpf(0.45, 1.0, float(form.size()) / squad.total)
				_step(squad, form)
		squad.origin = squad.origin.lerp(squad.goal, 1.0 - exp(-12.0 * delta))
		if peaceful:
			continue
		squad.bomb_t -= delta
		if squad.bomb_t <= 0.0:
			squad.bomb_t = maxf(0.6, 3.0 - 0.14 * wave) * rng.randf_range(0.6, 1.4)
			_drop_bomb(form)
		squad.dive_t -= delta
		if squad.dive_t <= 0.0:
			squad.dive_t = rng.randf_range(3.0, 5.5) * maxf(0.5, 1.0 - 0.03 * wave)
			var divers: Array[Alien] = []
			for a in form:
				if a.kind == "diver" and a.flip >= 1.0:
					divers.append(a)
			if not divers.is_empty():
				start_dive(divers[rng.randi() % divers.size()])

	# Callbacks into the game remove aliens (and add mites), so walk a copy.
	for a: Alien in aliens.duplicate():
		if a.dead:
			continue
		match a.mode:
			Alien.Mode.FORM:
				var squad: Squad = a.squad
				a.pos = squad.origin + a.slot
				a.tilt = squad.lean * 0.08
				if a.kind == "spitter" and not peaceful and a.flip >= 1.0:
					a.t -= delta
					if a.t <= 0.0:
						a.t = rng.randf_range(2.5, 4.5)
						var aim := (Vector2(player.x, 1.5) - a.pos).normalized()
						game.enemy_fire("spit", a.pos + aim * 0.8, aim * (3.6 + 0.15 * wave))
				if not peaceful and (a.pos.y - a.hy < LAND_Y or game.city.building_at(a.pos.x, a.pos.y - a.hy * 0.7) != null):
					game.alien_crashed(a)
					continue
			Alien.Mode.DIVE:
				a.t += delta
				var to := a.goal_pt - a.pos
				var heading := to.normalized()
				var side := Vector2(-heading.y, heading.x)
				a.pos += (heading * a.speed + side * cos(a.t * 6.0) * 2.4) * delta
				a.tilt = clampf(-heading.x * 0.8, -0.8, 0.8)
				if a.pos.y <= 1.0 or to.length() < 0.3 or player.overlaps(a.pos, a.hx * 0.7) \
						or game.city.building_at(a.pos.x, a.pos.y) != null:
					game.alien_crashed(a)
					continue
			Alien.Mode.FREE:
				a.t += delta
				a.pos.x = clampf(a.pos.x + sin(a.t * 3.0 + a.phase) * 1.8 * delta, -City.HALF, City.HALF)
				a.pos.y -= (1.2 + 0.03 * wave) * delta
				a.tilt = sin(a.t * 3.0 + a.phase) * 0.3
				if a.pos.y <= 0.6 or player.overlaps(a.pos, a.hx) or game.city.building_at(a.pos.x, a.pos.y) != null:
					game.alien_crashed(a)
					continue
			Alien.Mode.GROUND:
				_kaiju(a, delta)
			Alien.Mode.SAUCER:
				_saucer(a, delta)
			Alien.Mode.BOSS:
				_boss(a, delta)
		a.animate(delta)

	if peaceful or wave < 4 or _count("FORM") + _count("boss") == 0:
		return
	_saucer_t -= delta
	if _saucer_t <= 0.0:
		_saucer_t = maxf(9.0, 22.0 - wave)
		if _count("saucer") < 1 + wave / 8:
			var from := -City.HALF - 3.0 if rng.randf() < 0.5 else City.HALF + 3.0
			var s := spawn("saucer", Vector2(from, rng.randf_range(7.5, 9.0)), Alien.Mode.SAUCER)
			s.flip = 1.0
			s.t = 1.0


## A toy kaiju: it drops out of the sky, then stomps along the street after the robot, kicking down
## whatever it passes.
func _kaiju(a: Alien, delta: float) -> void:
	if a.pos.y > a.hy:
		a.pos.y = maxf(a.hy, a.pos.y - 10.0 * delta)
		if a.pos.y == a.hy:
			game.diorama.shake(0.5)
			game.people.scare(a.pos.x, 9.0)
			Sfx.play("boom", 0.7, -4.0)
		return
	if peaceful:
		return
	var player: Tank = game.player
	a.speed = move_toward(a.speed, 1.2 * signf(player.x - a.pos.x), delta * 2.0)
	a.pos.x = clampf(a.pos.x + a.speed * delta, -City.HALF, City.HALF)
	a.t -= delta
	if a.t <= 0.0:
		a.t = 2.2
		var under: City.Building = game.city.column_at(a.pos.x)
		if under != null:
			game.kaiju_stomp(a, under)
	if player.z > -2.5 and player.y < 2.0 and absf(player.x - a.pos.x) < a.hx:
		game.hurt_player()


func start_dive(a: Alien) -> void:
	a.mode = Alien.Mode.DIVE
	# It cuts itself loose
	if a.line != null:
		a.line.visible = false
	a.t = 0.0
	a.speed = 6.0 + 0.15 * wave
	a.goal_pt = Vector2(clampf(game.player.x + rng.randf_range(-1.5, 1.5), -City.HALF, City.HALF), 0.6)


## The alien closest to a point, or null when the sky is empty.
func nearest(to: Vector2, max_dist := INF, skip: Array = []) -> Alien:
	var found: Alien = null
	var best := max_dist
	for a in aliens:
		if a.dead or a.pos.y > _top + 2.0 or skip.has(a):
			continue
		var d := a.pos.distance_to(to)
		if d < best:
			best = d
			found = a
	return found


func toughest() -> Alien:
	var found: Alien = null
	for a in aliens:
		if not a.dead and a.pos.y < _top + 2.0 and (found == null or a.hp > found.hp):
			found = a
	return found


## The alien that will reach the city first.
func lowest() -> Alien:
	var found: Alien = null
	for a in aliens:
		if not a.dead and (found == null or a.pos.y < found.pos.y):
			found = a
	return found


## Kinds for a squad's rows, top first: this wave's debut if it has one, otherwise a mix of what
## has been met so far.
func _row_kinds(n: int) -> Array:
	var pool := ["grunt"]
	for debut: int in DEBUTS:
		if n >= debut:
			pool.append(DEBUTS[debut])
	var kinds := []
	for r in 2:
		kinds.append(DEBUTS[n] if r == 0 and DEBUTS.has(n) else pool[rng.randi() % pool.size()])
	return kinds


func _squad(centre: float, cols: int, rows: int, kinds: Array) -> void:
	var squad := Squad.new()
	squad.centre = centre
	squad.origin = Vector2(centre, _top - 0.8)
	squad.goal = squad.origin
	squad.dir = 1.0 if rng.randf() < 0.5 else -1.0
	squad.bomb_t = rng.randf_range(2.5, 4.0)
	squad.dive_t = rng.randf_range(3.0, 5.0)
	squad.total = 0
	squads.append(squad)
	for r in rows:
		for c in cols:
			var kind: String = kinds[r]
			# A brute is a squad of its own: one per row, the rest are grunts
			if kind == "brute" and c > 0:
				kind = "grunt"
			var a := spawn(kind, squad.origin)
			a.squad = squad
			a.slot = Vector2((c - (cols - 1) * 0.5) * SPACING.x, -r * SPACING.y)
			a.pos = squad.origin + a.slot
			a.flip_delay = 0.25 + c * 0.12 + r * 0.2
			a.t = rng.randf_range(1.5, 4.0)
			squad.total += 1


func _step(squad: Squad, form: Array[Alien]) -> void:
	var lo := INF
	var hi := -INF
	for a in form:
		lo = minf(lo, a.slot.x)
		hi = maxf(hi, a.slot.x)
	var x := squad.goal.x + squad.dir * STEP_X
	if x + hi > squad.centre + REACH or x + lo < squad.centre - REACH:
		squad.dir = -squad.dir
		if not peaceful:
			squad.goal.y -= STEP_DOWN * maxf(1.0, (_top - 5.5) / (TUNED_TOP - 5.5))
	else:
		squad.goal.x = x
	squad.lean = -squad.lean
	_beat = (_beat + 1) % 4
	if not peaceful:
		Sfx.play("march%d" % _beat, 1.0, -5.0)


func _drop_bomb(form: Array[Alien]) -> void:
	var a: Alien = form[rng.randi() % form.size()]
	# Only the lowest alien in a column has a clear shot.
	for other in form:
		if absf(other.slot.x - a.slot.x) < 0.7 and other.slot.y < a.slot.y:
			a = other
	if a.flip < 1.0 or rng.randf() > float(a.def.bomb):
		return
	if a.kind == "brute":
		game.enemy_fire("big", a.pos + Vector2(0.0, -a.hy), Vector2(0.0, -3.2))
	else:
		game.enemy_fire("bomb", a.pos + Vector2(0.0, -a.hy), Vector2(0.0, -(2.7 + 0.15 * wave)))


## How many of a kind are alive ("FORM" counts everything still marching).
func _count(kind: String) -> int:
	var n := 0
	for a in aliens:
		if a.kind == kind or (kind == "FORM" and a.mode == Alien.Mode.FORM):
			n += 1
	return n


## Abductor: parks over a building and pulls it apart until someone shoots it down.
func _saucer(a: Alien, delta: float) -> void:
	if a.target_b == null or not a.target_b.alive():
		a.target_b = game.city.random_standing(rng)
	var parked := false
	# A decoy cow is irresistible: saucers hover over it and leave the buildings alone.
	var decoy: bool = game.defenses.level("cow") > 0
	if a.target_b != null or decoy:
		var hover := Vector2(Defenses.COW_X, 3.8) if decoy else Vector2(a.target_b.x, a.target_b.top() + 2.8)
		var to := hover - a.pos
		parked = to.length() < 0.12
		if not parked:
			a.pos += to.limit_length(3.6 * delta)
			a.tilt = clampf(-to.x * 0.08, -0.25, 0.25)
		else:
			a.tilt = sin(_time * 4.0) * 0.05
			a.t -= delta
			if a.t <= 0.0:
				a.t = 1.6
				if not decoy:
					game.hurt_building(a.target_b, 1, Vector3(a.target_b.x, a.target_b.top(), 0.0))
	a.beam.visible = parked


## The mothership hunts the robot along the table, stopping to fire its death ray.
func _boss(a: Alien, delta: float) -> void:
	if a.speed == 0.0:
		# Entrance: sink down from above the box (speed doubles as the "has arrived" flag).
		a.pos.y -= 2.2 * delta
		if a.pos.y <= _top - 1.4:
			a.speed = 1.0
			a.goal_pt.x = a.pos.x
		return
	if a.ray_t > 0.0:
		var before := a.ray_t
		a.ray_t -= delta
		if before > RAY_FIRE and a.ray_t <= RAY_FIRE:
			game.boss_ray(a.pos.x, a.pos.y - 1.0)
		return
	a.phase += delta * 0.55
	a.goal_pt.x = move_toward(a.goal_pt.x, game.player.x, 1.6 * delta)
	a.pos.x = clampf(a.goal_pt.x + sin(a.phase) * 4.2, -City.HALF + 2.0, City.HALF - 2.0)
	a.pos.y = _top - 1.5 + sin(_time * 1.4) * 0.2
	a.tilt = cos(a.phase) * 0.06
	a.t -= delta
	if a.t > 0.0:
		return
	a.t = lerpf(1.5, 2.6, a.hp / a.max_hp)
	a.attack += 1
	match a.attack % 4:
		1, 3:
			for i in 5:
				var ang := (i - 2) * 0.22
				game.enemy_fire("bomb", a.pos + Vector2((i - 2) * 0.9, -1.2), Vector2(sin(ang), -cos(ang)) * (4.0 + 0.1 * wave))
		2:
			for sx: float in [-2.0, 2.0]:
				var d := spawn("diver", a.pos + Vector2(sx, -1.0), Alien.Mode.DIVE)
				d.flip = 1.0
				start_dive(d)
				d.goal_pt.x = clampf(game.player.x + sx, -City.HALF, City.HALF)
		0:
			a.ray_t = RAY_CHARGE + RAY_FIRE
			game.boss_charge(a.pos.x, a.pos.y - 1.0, RAY_CHARGE)
