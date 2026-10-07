extends Node3D
## Denver Vs The Universe: Space Invaders as a roguelike, staged in a paper diorama.
## This is the referee. It owns the pieces (set, city, swarm, shots, tank, defenses), runs the
## wave -> upgrade card -> wave loop, and settles every hit the others report.

enum State { TITLE, PLAYING, CLEARED, PICK, OVER }

const SAVE := "user://best.cfg"
const WAVE_NAMES := {
	1: "First Contact", 2: "The Crab Nebula", 3: "Dive Bombers", 4: "Spit Take", 5: "The Mothership",
	6: "Mitosis", 7: "The Heavies", 10: "The Mothership Returns",
}

var state := State.TITLE
var wave := 0
var score := 0
var best := 0
## Upgrade id -> how many times it has been taken this run.
var levels := {}
var offer: Array = []
var rng := RandomNumberGenerator.new()
## Tests turn this off so they do not write a best score.
var saving := true

var font: FontVariation
var diorama: Diorama
var city: City
var swarm: Swarm
var shots: Shots
var player: Tank
var defenses: Defenses
var fx: Fx
var hud: Hud

var _clear_t := 0.0
var _over_t := 0.0
var _touch := -1
var _touch_x := 0.0
## Finger speed, in screen pixels a second, that counts as a flick.
const SWIPE := 900.0
var _tap_dir := 0.0
var _tap_at := 0


func _ready() -> void:
	rng.randomize()
	font = FontVariation.new()
	font.base_font = load("res://fonts/Jost.ttf")
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}

	diorama = Diorama.new()
	diorama.font = font
	add_child(diorama)
	city = City.new()
	add_child(city)
	defenses = Defenses.new()
	defenses.game = self
	add_child(defenses)
	swarm = Swarm.new()
	swarm.game = self
	swarm.rng.seed = rng.randi()
	add_child(swarm)
	player = Tank.new()
	player.game = self
	add_child(player)
	shots = Shots.new()
	shots.game = self
	add_child(shots)
	fx = Fx.new()
	fx.font = font
	add_child(fx)
	hud = Hud.new()
	hud.font = font
	add_child(hud)
	hud.card_picked.connect(pick_card)
	hud.again_pressed.connect(start_game)

	var cfg := ConfigFile.new()
	if cfg.load(SAVE) == OK:
		best = int(cfg.get_value("score", "best", 0))
	player.reset()
	swarm.spawn_parade()
	hud.show_title(best)


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	match state:
		State.TITLE:
			swarm.update(delta)
			player.update(delta, false)
		State.PLAYING:
			player.update(delta, true)
			swarm.update(delta)
			defenses.update(delta)
			shots.update(delta)
			var boss: Alien = null
			for a in swarm.aliens:
				if a.kind == "boss":
					boss = a
			hud.set_boss(boss.hp / boss.max_hp if boss != null else -1.0)
			if player.hearts <= 0 or city.fallen():
				_game_over()
			elif swarm.cleared() and shots.hostile() == 0:
				_wave_cleared()
		State.CLEARED:
			player.update(delta, false)
			defenses.update(delta)
			shots.update(delta)
			_clear_t -= delta
			if _clear_t <= 0.0:
				offer = Upgrades.roll(levels, rng, city.percent() < 75, wave)
				hud.show_cards(offer, levels, wave)
				state = State.PICK
		State.OVER:
			_over_t += delta
	if state != State.TITLE:
		hud.set_stats(score, wave, player.hearts, player.max_hearts, city.percent())
		_point_at_threats()
	diorama.update_camera(delta, player.x)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed:
			if state == State.TITLE:
				start_game()
			_touch = e.index
			_touch_x = _world_x(e.position)
		elif e.index == _touch:
			_touch = -1
	elif e is InputEventScreenDrag and e.index == _touch:
		# Relative steering: the tank moves as far as the finger does, wherever the finger is.
		var wx := _world_x(e.position)
		player.goal_x = clampf(player.goal_x + (wx - _touch_x) * 1.2, -Tank.LIMIT, Tank.LIMIT)
		# A flick is an ability (once its card is held): up to jump, sideways to dash
		if state == State.PLAYING:
			if e.velocity.y < -SWIPE and absf(e.velocity.y) > absf(e.velocity.x):
				player.jump()
			elif absf(e.velocity.x) > SWIPE * 1.5:
				player.dash(e.velocity.x)
		_touch_x = wx
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_SPACE, KEY_ENTER:
				if state == State.TITLE or (state == State.OVER and _over_t > 1.0):
					start_game()
			KEY_1, KEY_2, KEY_3:
				pick_card(e.keycode - KEY_1)
			KEY_UP, KEY_W:
				if state == State.PLAYING:
					player.jump()
			KEY_SHIFT:
				if state == State.PLAYING:
					player.dash(0.0)
			KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D:
				# Tapping a direction twice quickly is a dash too
				var dir := -1.0 if e.keycode in [KEY_LEFT, KEY_A] else 1.0
				var now := Time.get_ticks_msec()
				if state == State.PLAYING and dir == _tap_dir and now - _tap_at < 260:
					player.dash(dir)
				_tap_dir = dir
				_tap_at = now
			KEY_M:
				Sfx.muted = not Sfx.muted


func start_game() -> void:
	levels = {}
	score = 0
	wave = 0
	city.reset()
	defenses.reset()
	shots.clear()
	player.reset()
	hud.show_game()
	_next_wave()


func pick_card(index: int) -> void:
	if state != State.PICK or index < 0 or index >= offer.size():
		return
	var u: Dictionary = offer[index]
	levels[u.id] = int(levels.get(u.id, 0)) + 1
	player.apply(levels)
	match u.id:
		"repair":
			city.repair_each(3)
			var raised := city.rebuild_one()
			if raised != null:
				fx.text(raised.roof() + Vector3(0.0, 1.0, 0.5), "REBUILT!", Color("9be7f5"))
			player.hearts = mini(player.max_hearts, player.hearts + 1)
			Sfx.play("repair")
		"armor", "mech":
			player.hearts = player.max_hearts
		_:
			defenses.sync(levels)
	Sfx.play("pick")
	hud.hide_cards()
	_next_wave()


# --- What the other pieces report -------------------------------------------------------------

func enemy_fire(kind: String, at: Vector2, vel: Vector2) -> void:
	shots.fire(kind, at, vel)
	Sfx.play("bomb", rng.randf_range(0.85, 1.15), -14.0)


func hit_alien(a: Alien, dmg: float, _at: Vector2) -> void:
	if a.dead:
		return
	if not a.hurt(dmg):
		Sfx.play("hit", rng.randf_range(0.9, 1.2), -13.0)
		return
	var at := Vector3(a.pos.x, a.pos.y, 0.0)
	score += int(a.def.score * (1.0 + 0.25 * (wave - 1)))
	fx.burst(at, a.color, 16, 5.0)
	Sfx.play("pop", rng.randf_range(0.85, 1.2), -7.0)
	match a.kind:
		"splitter":
			for side: float in [-0.4, 0.4]:
				var mite := swarm.spawn("mite", a.pos + Vector2(side, 0.0), Alien.Mode.FREE)
				mite.flip = 1.0
				mite.phase = 0.0 if side > 0.0 else PI
		"saucer":
			shots.fire("crate", a.pos, Vector2(0.0, -1.7))
		"boss":
			for i in 6:
				fx.burst(at + Vector3(rng.randf_range(-2.0, 2.0), rng.randf_range(-0.8, 0.8), 0.0), [a.color, Hud.GOLD, Color.WHITE][i % 3], 24, 7.0)
			fx.text(at, "MOTHERSHIP DOWN!", Hud.GOLD, 84)
			diorama.shake(0.9)
			Sfx.play("boom")
	swarm.remove(a)


## An alien reached the ground: it wrecks whatever it lands on and is gone, with no points.
func alien_crashed(a: Alien) -> void:
	fx.burst(Vector3(a.pos.x, a.pos.y, 0.0), a.color, 12, 4.0)
	if player.overlaps(a.pos, a.hx):
		hurt_player()
	else:
		var b := city.nearest_standing(a.pos.x)
		if b != null and absf(b.x - a.pos.x) < b.half_w + 1.6:
			hurt_building(b, {"mite": 1, "diver": 2, "brute": 8}.get(a.kind, 4), b.roof())
	swarm.remove(a)


func hurt_player() -> void:
	if player.invuln > 0.0 or state != State.PLAYING:
		return
	if player.absorb():
		player.invuln = 0.6
		fx.burst(Vector3(player.x, 2.0, 0.2), Color("ff8a2a"), 20, 5.0)
		fx.text(Vector3(player.x, 3.6, 0.5), "A.T. FIELD", Color("ff8a2a"), 44)
		Sfx.play("dome", 0.7)
		return
	player.hearts -= 1
	player.invuln = 1.6
	player.flash(1.0)
	diorama.shake(0.55)
	fx.burst(Vector3(player.x, 0.6, 0.0), Color("ff6b6b"), 18, 5.0)
	Sfx.play("hurt")


func hurt_building(b: City.Building, dmg: int, at: Vector3) -> void:
	if not b.alive():
		return
	if city.damage(b, dmg):
		fx.burst(Vector3(b.x, 1.0, b.z + 0.2), Color("b9b6ad"), 40, 6.0)
		if b.title != "":
			fx.text(Vector3(b.x, b.height * 0.5 + 1.0, 0.5), "%s LOST!" % b.title.to_upper(), Color("ff6b6b"), 46)
		diorama.shake(0.7)
		Sfx.play("boom")
	else:
		fx.burst(at, Color("e4e0d6"), 8, 3.5)
		diorama.shake(0.2)
		Sfx.play("crunch", rng.randf_range(0.9, 1.1), -5.0)


## A blast that hurts every alien within `radius` (except the one that was hit directly).
func explode(at: Vector2, radius: float, dmg: float, skip: Alien = null) -> void:
	fx.burst(Vector3(at.x, at.y, 0.0), Color("a8e05f"), 10, radius * 4.0)
	for a: Alien in swarm.aliens.duplicate():
		if a != skip and not a.dead and a.pos.distance_to(at) < radius + maxf(a.hx, a.hy) * 0.5:
			hit_alien(a, dmg, a.pos)


func bomb_shot_down(at: Vector2) -> void:
	score += 2
	fx.burst(Vector3(at.x, at.y, 0.0), Color("a8ff60"), 5, 2.5)
	Sfx.play("hit", 1.5, -12.0)


## Supply crate from a downed saucer: a spell of double fire rate, some repairs and points.
func collect_crate(at: Vector2) -> void:
	player.overdrive = 8.0
	score += 100
	city.repair(2)
	fx.text(Vector3(at.x, at.y + 0.8, 0.5), "OVERDRIVE!", Hud.GOLD)
	Sfx.play("crate")


## The mothership's death ray: a warning line, then (boss_ray) the real thing down the same column.
func boss_charge(x: float, y: float, seconds: float) -> void:
	fx.beam(Vector3(x, y, 0.1), Vector3(x, 0.0, 0.1), Color(1.0, 0.25, 0.3), 0.14, seconds)
	Sfx.play("alarm")


func boss_ray(x: float, y: float) -> void:
	var stop := 0.0
	# The dome can take the ray, at the price of two charges.
	var dome_y := Defenses.DOME_RY * sqrt(maxf(0.0, 1.0 - pow(x / Defenses.DOME_RX, 2.0)))
	var blocked := defenses.dome_blocks(Vector2(x, dome_y * 0.98), true)
	if blocked:
		stop = dome_y
	fx.beam(Vector3(x, y, 0.1), Vector3(x, stop, 0.1), Color(1.0, 0.3, 0.9), 1.3, 0.6)
	fx.beam(Vector3(x, y, 0.12), Vector3(x, stop, 0.12), Color(1.0, 0.9, 1.0), 0.5, 0.6)
	diorama.shake(0.45)
	Sfx.play("beam", 0.6)
	if blocked:
		return
	if absf(player.x - x) < 1.25:
		hurt_player()
	var b := city.column_at(x)
	if b != null:
		hurt_building(b, 2, b.roof())


# --- Flow ------------------------------------------------------------------------------------

func _next_wave() -> void:
	wave += 1
	swarm.spawn_wave(wave)
	defenses.wave_start()
	state = State.PLAYING
	var boss := wave % 5 == 0
	hud.banner("WAVE %d" % wave, WAVE_NAMES.get(wave, "The Mothership Again" if boss else ""))
	Sfx.play("alarm" if boss else "wave")


func _wave_cleared() -> void:
	state = State.CLEARED
	_clear_t = 2.0
	var bonus := 5 * wave * city.percent()
	score += bonus
	var patched := defenses.wave_end()
	if patched > 0:
		fx.text(Vector3(5.7, 2.6, 0.5), "+%d FLOORS" % patched, Color("7fa8f5"))
		Sfx.play("repair")
	hud.banner("WAVE CLEARED", "+%d for a city %d%% intact" % [bonus, city.percent()])
	Sfx.play("clear")


func _game_over() -> void:
	state = State.OVER
	_over_t = 0.0
	_touch = -1
	var reason := "DENVER HAS FALLEN" if city.fallen() else "THE ROBOT IS DOWN"
	if score > best and saving:
		best = score
		var cfg := ConfigFile.new()
		cfg.set_value("score", "best", best)
		cfg.save(SAVE)
	# Hand the score to the hosting page (the Scareathon arcade cabinet) for its leaderboard
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.parent.postMessage({ type: 'PLAYER_DIED', score: %d }, '*')" % score, true)
	diorama.shake(0.9)
	Sfx.play("over")
	hud.show_over(score, wave, best, reason)


func _world_x(screen: Vector2) -> float:
	var from := diorama.camera.project_ray_origin(screen)
	var dir := diorama.camera.project_ray_normal(screen)
	return from.x if absf(dir.z) < 0.0001 else from.x - dir.x * from.z / dir.z


## Tells the HUD how many aliens are off each side of the screen, so the player knows where to run.
func _point_at_threats() -> void:
	var left := 0
	var right := 0
	var mid := diorama.camera.position.x
	for a in swarm.aliens:
		if a.pos.x < mid - diorama.view_half - 0.5:
			left += 1
		elif a.pos.x > mid + diorama.view_half + 0.5:
			right += 1
	hud.set_threats(left, right)
