extends Node3D
## Denver Vs The Universe: Space Invaders as a roguelike, staged in a paper diorama.
## This is the referee. It owns the pieces (set, city, swarm, shots, tank, defenses), runs the
## wave -> upgrade card -> wave loop, and settles every hit the others report.

enum State { TITLE, PLAYING, CLEARED, PICK, SHOP, OVER }

const SAVE := "user://best.cfg"

var state := State.TITLE
var wave := 0
var score := 0
var best := 0
## Upgrade id -> how many times it has been taken this run.
var levels := {}
## Alien wreckage to spend in the workshop, and the alien tech built from it so far (id -> true).
var scrap := 0
var tech := {}
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
## The two robots that steer themselves and fight beside the player. They can be destroyed.
var wingmen: Array[Tank] = []
var people: People
var defenses: Defenses
var fx: Fx
var hud: Hud

## The menu's options: name -> index of the setting chosen (Hud.OPTIONS lists them).
var options := {"sound": 1, "picture": 0, "retro": 1, "wingman": 1}

var _clear_t := 0.0
var _over_t := 0.0
## The joystick: which finger has it, where its middle is on the screen, and how far it is pushed (-1 to 1).
var _stick_touch := -1
var _stick_from := Vector2.ZERO
var _stick := Vector2.ZERO
var _stick_at := 0
const STICK_REACH := 64.0
## The swiping finger and where it came down; a swipe is this far, in screen pixels.
var _swipe_touch := -1
var _swipe_from := Vector2.ZERO
const SWIPE := 55.0
## The push the robot's present run began with, and the way it set off.
var _ref := Vector2.ZERO


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
	people = People.new()
	add_child(people)
	for side: float in [-1.0, 1.0]:
		var w := Tank.new()
		w.game = self
		w.ai = true
		w.post = side
		add_child(w)
		wingmen.append(w)
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
	hud.play_pressed.connect(start_game)
	hud.shop_bought.connect(_buy_shop)
	hud.tech_bought.connect(_buy_tech)
	hud.shop_closed.connect(_leave_shop)
	hud.option_changed.connect(_set_option)

	var cfg := ConfigFile.new()
	if cfg.load(SAVE) == OK:
		best = int(cfg.get_value("score", "best", 0))
		for key: String in options:
			options[key] = int(cfg.get_value("options", key, options[key]))
	hud.set_options(options)
	_apply_options()
	player.reset()
	_muster()
	swarm.spawn_parade()
	hud.show_title(best)


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	match state:
		State.TITLE:
			swarm.update(delta)
			player.update(delta, false)
			for w in wingmen:
				w.update(delta, false)
		State.PLAYING:
			player.update(delta, true)
			for w in wingmen:
				w.update(delta, true)
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
			for w in wingmen:
				w.update(delta, false)
			defenses.update(delta)
			shots.update(delta)
			_clear_t -= delta
			if _clear_t <= 0.0:
				# No wingmen left to drill: do not offer the card
				var held := levels.duplicate()
				if not _any_wingman():
					held["wingman"] = 99
				offer = Upgrades.roll(held, rng, city.percent() < 75, wave)
				hud.show_cards(offer, levels, wave)
				state = State.PICK
		State.OVER:
			_over_t += delta
	if state != State.TITLE:
		hud.set_stats(score, wave, player.hearts, player.max_hearts, city.percent())
		var squad: Array = []
		if options.wingman == 1:
			for w in wingmen:
				squad.append(0 if w.down else w.hearts)
		hud.set_wingmen(squad)
		_point_at_threats()
	people.update(delta)
	if state in [State.PLAYING, State.CLEARED]:
		_drive()
	hud.set_stick(_stick_touch != -1, _stick_from, _stick_from + _stick * STICK_REACH)
	diorama.drama = 1.0 if state == State.TITLE else 0.0
	diorama.update_camera(delta, player.x, player.heading(), player.z)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if state != State.PLAYING and state != State.CLEARED:
			_stick_touch = -1
			_swipe_touch = -1
			_stick = Vector2.ZERO
			return
		if e.pressed:
			# The first finger down, anywhere on the screen, is the joystick. Any finger that
			# flicks is a swipe, the joystick one included.
			if _stick_touch == -1:
				_stick_touch = e.index
				_stick_from = e.position
				_stick = Vector2.ZERO
				_stick_at = Time.get_ticks_msec()
			elif _swipe_touch == -1:
				_swipe_touch = e.index
				_swipe_from = e.position
		elif e.index == _stick_touch:
			_stick_touch = -1
			_stick = Vector2.ZERO
		elif e.index == _swipe_touch:
			_swipe_touch = -1
	elif e is InputEventScreenDrag and e.index == _stick_touch:
		var pull: Vector2 = e.position - _stick_from
		# The stick follows a thumb that wanders off, so it never has to stretch back
		if pull.length() > STICK_REACH:
			_stick_from = e.position - pull.limit_length(STICK_REACH)
			pull = e.position - _stick_from
		_stick = pull / STICK_REACH
		# A quick flick of the joystick finger is a swipe too
		if Time.get_ticks_msec() - _stick_at < 220 and e.velocity.length() > 1100.0:
			_stick_at = 0
			_flick(e.velocity)
	elif e is InputEventScreenDrag and e.index == _swipe_touch:
		# A swipe up is a jump, a swipe sideways a dash that way (once their cards are held)
		var swipe: Vector2 = e.position - _swipe_from
		# A finger that rests, or creeps, is not swiping: the swipe starts when it moves off quickly
		if e.velocity.length() < 250.0:
			_swipe_from = e.position
		elif swipe.length() > SWIPE:
			_swipe_touch = -1
			_flick(swipe)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_SPACE, KEY_ENTER:
				if state == State.TITLE or (state == State.OVER and _over_t > 1.0):
					start_game()
				elif state == State.PLAYING:
					player.jump()
			KEY_1, KEY_2, KEY_3:
				pick_card(e.keycode - KEY_1)
			KEY_SHIFT:
				if state == State.PLAYING:
					player.dash(0.0)
			KEY_M:
				_set_option("sound", 1 - int(options.sound))
				hud.set_options(options)


func start_game() -> void:
	levels = {}
	scrap = 0
	tech = {}
	score = 0
	wave = 0
	city.reset()
	defenses.reset()
	shots.clear()
	player.reset()
	_muster()
	hud.show_game()
	_next_wave()


func pick_card(index: int) -> void:
	if state != State.PICK or index < 0 or index >= offer.size():
		return
	var u: Dictionary = offer[index]
	levels[u.id] = int(levels.get(u.id, 0)) + 1
	player.apply(levels)
	for w in wingmen:
		w.enlist(int(levels.get("wingman", 0)))
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
	# Then the workshop, to spend the wreckage
	state = State.SHOP
	hud.show_workshop(scrap, tech, _no_use())


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
	scrap += ceili(float(a.def.score) / 8.0)
	fx.burst(at, a.color, 16, 5.0)
	people.cheer(a.pos.x)
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
	var struck := _wingman_at(a.pos, a.hx)
	if player.overlaps(a.pos, a.hx):
		hurt_player()
	elif struck != null:
		hurt_wingman(struck)
	else:
		# The wall only spends itself on a landing that would have hit something
		var b := city.nearest_standing(a.pos.x)
		if b != null and absf(b.x - a.pos.x) < b.half_w + 1.6:
			if defenses.wall_holds():
				fx.text(Vector3(a.pos.x, 2.0, 0.5), "THE WALL HOLDS", Color("ffd23f"), 40)
			else:
				hurt_building(b, {"mite": 1, "diver": 2, "brute": 8}.get(a.kind, 4), b.roof())
	swarm.remove(a)


## A kaiju puts its foot through the building it is standing beside.
func kaiju_stomp(a: Alien, b: City.Building) -> void:
	diorama.shake(0.3)
	if defenses.wall_holds():
		fx.text(Vector3(a.pos.x, 3.4, 0.5), "THE WALL HOLDS", Color("ffd23f"), 40)
		return
	hurt_building(b, 2, b.roof())


func hurt_player() -> void:
	if player.invuln > 0.0 or state != State.PLAYING:
		return
	if player.absorb():
		player.invuln = 0.6
		fx.burst(Vector3(player.x, 2.0, 0.2), Color("ff8a2a"), 20, 5.0)
		fx.text(Vector3(player.x, 3.6, 0.5), "FORCE FIELD", Color("ff8a2a"), 44)
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
	people.scare(b.x)
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
	for w in wingmen:
		if absf(w.x - x) < 1.25:
			hurt_wingman(w)
	var b := city.column_at(x)
	if b != null:
		hurt_building(b, 2, b.roof())


# --- The workshop ------------------------------------------------------------------------------

func _buy_shop(id: String) -> void:
	var item := Workshop.find(Workshop.SHOP, id)
	if state != State.SHOP or item.is_empty() or scrap < int(item.cost):
		return
	match id:
		"patch":
			if not city.mendable():
				return
			city.repair_each(2)
		"heart":
			if player.hearts >= player.max_hearts:
				return
			player.hearts += 1
		"rebuild":
			var lost: Tank = null
			for w in wingmen:
				if w.down:
					lost = w
			if lost == null:
				return
			lost.down = false
			lost.hearts = lost.max_hearts
			lost.x = clampf(player.x + 5.0 * lost.post, -Roads.SIDE + Roads.BEND, Roads.SIDE - Roads.BEND)
			lost.z = 0.0
			lost.goal_x = lost.x
			lost.visible = true
	scrap -= int(item.cost)
	Sfx.play("repair")
	hud.show_workshop(scrap, tech, _no_use())


func _buy_tech(id: String) -> void:
	var item := Workshop.find(Workshop.TECH, id)
	var before := Workshop.needs(id)
	if state != State.SHOP or item.is_empty() or tech.has(id) or scrap < int(item.cost) or (before != "" and not tech.has(before)):
		return
	if item.gives == "wingman" and not _any_wingman():
		return
	scrap -= int(item.cost)
	tech[id] = true
	# A refit beyond the last chassis would be wasted: it becomes plating instead
	var gives: String = item.gives
	if gives == "mech" and int(levels.get("mech", 0)) >= Tank.CHASSIS.size() - 1:
		gives = "armor"
	levels[gives] = int(levels.get(gives, 0)) + 1
	player.apply(levels)
	for w in wingmen:
		w.enlist(int(levels.get("wingman", 0)))
	if gives in ["armor", "mech"]:
		player.hearts = player.max_hearts
	Sfx.play("pick")
	hud.show_workshop(scrap, tech, _no_use())


## What in the workshop would do nothing if bought now.
func _no_use() -> Array:
	var none: Array = []
	if not city.mendable():
		none.append("patch")
	if player.hearts >= player.max_hearts:
		none.append("heart")
	var lost := false
	for w in wingmen:
		lost = lost or (w.down and not w.benched)
	if not lost:
		none.append("rebuild")
	if not _any_wingman():
		none.append("hive")
	return none


func _leave_shop() -> void:
	if state != State.SHOP:
		return
	hud.hide_workshop()
	_next_wave()


# --- Flow ------------------------------------------------------------------------------------

func _next_wave() -> void:
	_stick = Vector2.ZERO
	wave += 1
	swarm.spawn_wave(wave)
	defenses.wave_start()
	state = State.PLAYING
	var boss := wave % 5 == 0
	# Every five waves a new invasion begins
	if (wave - 1) % 5 == 0:
		hud.banner(Swarm.invasion(wave).name, "Wave %d" % wave, 2.4)
	else:
		hud.banner("WAVE %d" % wave, "The Mothership" if boss else Swarm.invasion(wave).name.capitalize())
	Sfx.play("alarm" if boss else "wave")


func _wave_cleared() -> void:
	state = State.CLEARED
	player.celebrate()
	people.cheer(player.x, 40.0)
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
	_stick_touch = -1
	_swipe_touch = -1
	_stick = Vector2.ZERO
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


func _set_option(key: String, value: int) -> void:
	options[key] = value
	_apply_options()
	if saving:
		var cfg := ConfigFile.new()
		cfg.load(SAVE)
		for name: String in options:
			cfg.set_value("options", name, options[name])
		cfg.save(SAVE)


func _apply_options() -> void:
	Sfx.muted = options.sound == 0
	diorama.configure(options.picture, options.retro == 1, false)
	for w in wingmen:
		w.benched = options.wingman == 0
		w.visible = not w.benched and not w.down


## A swipe: up is a jump, sideways a dash that way (once their cards are held).
func _flick(way: Vector2) -> void:
	if absf(way.y) > absf(way.x):
		if way.y < 0.0:
			player.jump()
	else:
		player.dash(way.x)


## Stands the wingmen either side of the robot, whole again, as they first arrive.
func _muster() -> void:
	for w in wingmen:
		w.reset()
		w.down = false
		w.benched = options.wingman == 0
		w.visible = not w.benched
		w.x = 5.0 * w.post
		w.goal_x = w.x
		w.enlist(0)
		w.hearts = w.max_hearts


## True while at least one wingman is in the fight.
func _any_wingman() -> bool:
	for w in wingmen:
		if not w.down and not w.benched:
			return true
	return false


## The wingman, if any, standing where something has come down.
func _wingman_at(at: Vector2, reach: float) -> Tank:
	for w in wingmen:
		if not w.down and not w.benched and w.overlaps(at, reach):
			return w
	return null


## A wingman is hit. Three hits and it is scrap until the next game (or a rebuild from the shop).
func hurt_wingman(w: Tank) -> void:
	if w.invuln > 0.0 or w.down or w.benched or state != State.PLAYING:
		return
	w.hearts -= 1
	w.invuln = 1.2
	w.flash(1.0)
	fx.burst(Vector3(w.x, 1.5, 0.0), Color("ffb060"), 14, 5.0)
	Sfx.play("hurt", 1.3, -6.0)
	if w.hearts <= 0:
		w.down = true
		w.visible = false
		fx.burst(Vector3(w.x, 2.0, 0.0), Color("ff8a3a"), 40, 7.0)
		fx.text(Vector3(w.x, 4.0, 0.5), "WINGMAN DOWN!", Color("ff6b6b"), 46)
		diorama.shake(0.5)
		Sfx.play("boom")


## Turns the joystick (or the arrow keys) into where the robot should run: the way pushed, along
## whichever street runs that way. Round a bend the push has to follow the street; at a fork the
## push picks the street.
func _drive() -> void:
	var push := _stick
	var keys := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		keys.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		keys.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		keys.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		keys.y += 1.0
	if keys != Vector2.ZERO:
		push = keys
	var here := Vector2(player.x, player.z)
	# A dash runs its course: steering waits for it
	if player.dashing():
		return
	if push.length() < 0.3:
		if _ref != Vector2.ZERO:
			_ref = Vector2.ZERO
			player.goal_x = here.x
			player.goal_z = here.y
		return
	# Up the screen is toward the back of the table. The robot goes exactly the way pushed, along
	# whichever street runs that way, and stops where none does.
	_ref = push
	var goal := Roads.steer(here, push.normalized())
	player.goal_x = goal.x
	player.goal_z = goal.y


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
