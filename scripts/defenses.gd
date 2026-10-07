class_name Defenses
extends Node3D
## The city's own defenses, bought between waves: rooftop flak, Blucifer, the dome, the foothill
## missile battery, the Tesla spire, hail storms and the Big Blue Bear's repair crew.

const FLAK_ROOFS := ["cash", "c1801", "qwest", "df"]
## Where the decoy cow grazes.
const COW_X := -7.9
const DOME_RX := 7.9
const DOME_RY := 6.1
const BLUCIFER_X := 7.75
const BLUCIFER_PPU := Cutout.PPU * 1.15
const BLUCIFER_EYE := Vector3(BLUCIFER_X - 0.37, 1.83, 1.0)
const BATTERY_AT := Vector2(-7.6, 2.0)

var game
var levels := {}
var dome_charges := 0
## Landings and stomps the city wall will still stop this wave.
var wall_charges := 0
var _walls: Array[MeshInstance3D] = []
var _wall_flash := 0.0
var _summit: Cutout
var _summit_t := 0.0
## The top of Mount Blue Sky on the backdrop, where the summit laser sits.
const SUMMIT := Vector3(-5.9, 14.4, -62.6)

var _turrets: Array[Dictionary] = []
var _blucifer: Cutout
var _blucifer_t := 0.0
var _dome: MeshInstance3D
var _dome_mat: ShaderMaterial
var _dome_max := 0
var _dome_hit := 0.0
var _battery: Cutout
var _battery_t := 0.0
var _tesla: Cutout
var _tesla_t := 0.0
var _hail_cloud: Cutout
var _hail: CPUParticles3D
var _hail_t := 0.0
var _hail_ticks := 0
var _hail_tick_t := 0.0
var _cow: Cutout
var _watchtower: Cutout
var _rng := RandomNumberGenerator.new()


func level(id: String) -> int:
	return int(levels.get(id, 0))


func reset() -> void:
	levels = {}
	for t in _turrets:
		t.node.queue_free()
	_turrets.clear()
	for wall in _walls:
		wall.queue_free()
	_walls.clear()
	wall_charges = 0
	for node: Node in [_blucifer, _dome, _battery, _tesla, _hail_cloud, _hail, _cow, _watchtower, _summit]:
		if node != null:
			node.queue_free()
	_blucifer = null
	_cow = null
	_watchtower = null
	_dome = null
	_battery = null
	_summit = null
	_tesla = null
	_hail_cloud = null
	_hail = null
	dome_charges = 0
	_dome_max = 0


## Builds whatever the upgrade levels say should exist and doesn't yet.
func sync(new_levels: Dictionary) -> void:
	levels = new_levels
	while _turrets.size() < mini(level("flak"), FLAK_ROOFS.size()):
		var node := Cutout.make("turret", Cutout.PPU, true)
		add_child(node)
		_turrets.append({"node": node, "roof": game.city.by_id(FLAK_ROOFS[_turrets.size()]), "t": _rng.randf()})
		_pop_in(node)
	if level("cow") > 0 and _cow == null:
		_cow = Cutout.make("cow", Cutout.PPU * 1.3, true)
		_cow.position = Vector3(COW_X, 0.0, 1.3)
		add_child(_cow)
		_pop_in(_cow)
	if level("watchtower") > 0 and _watchtower == null:
		_watchtower = Cutout.make("watchtower", Cutout.PPU * 0.8, true)
		_watchtower.position = Vector3(8.3, 0.0, -4.4)
		add_child(_watchtower)
		_pop_in(_watchtower)
	if level("blucifer") > 0 and _blucifer == null:
		_blucifer = Cutout.make("blucifer", BLUCIFER_PPU, true)
		_blucifer.position = Vector3(BLUCIFER_X, 0.0, 1.0)
		add_child(_blucifer)
		_pop_in(_blucifer)
		_blucifer_t = 2.0
	if level("battery") > 0 and _battery == null:
		_battery = Cutout.make("battery", Cutout.PPU * 0.8, true)
		_battery.position = Vector3(BATTERY_AT.x - 0.4, 0.0, -3.4)
		add_child(_battery)
		_pop_in(_battery)
		_battery_t = 1.5
	if level("tesla") > 0 and _tesla == null:
		_tesla = Cutout.make("tesla", Cutout.PPU * 1.3, true)
		add_child(_tesla)
		_pop_in(_tesla)
		_tesla_t = 1.5
	if level("hail") > 0 and _hail == null:
		_build_hail()
		_hail_t = 5.0
	if level("wall") > 0:
		_build_wall()
	if level("summit") > 0 and _summit == null:
		_summit = Cutout.make("turret", Cutout.PPU * 0.14, true)
		_summit.position = SUMMIT
		add_child(_summit)
		_pop_in(_summit)
		_summit_t = 2.0
	if level("dome") > 0:
		if _dome == null:
			_build_dome()
		var was := _dome_max
		_dome_max = 4 * level("dome")
		dome_charges += _dome_max - was


func wave_start() -> void:
	dome_charges = _dome_max
	wall_charges = [0, 3, 6, 10][level("wall")]
	_hail_ticks = 0
	if _hail != null:
		_hail.emitting = false
		_hail_t = minf(_hail_t, 6.0)


## The bear's rounds once the sky is clear. Returns how many floors were patched.
func wave_end() -> int:
	if _hail != null:
		_hail.emitting = false
	_hail_ticks = 0
	var crew: int = [0, 2, 4, 7][level("bear")]
	return game.city.repair(crew) if crew > 0 else 0


## True if the city wall took a landing or a stomp (and is one hit nearer to giving out).
func wall_holds() -> bool:
	if wall_charges <= 0:
		return false
	wall_charges -= 1
	_wall_flash = 1.0
	return true


## The wall: cardboard boards along the city side of the ring, with gaps where the shortcuts cross.
## Each level makes it taller.
func _build_wall() -> void:
	if _walls.is_empty():
		var card := StandardMaterial3D.new()
		card.albedo_color = Cutout.CARDBOARD.darkened(0.25)
		card.roughness = 1.0
		card.emission_enabled = true
		card.emission = Cutout.CARDBOARD
		card.emission_energy_multiplier = 0.08
		var inset := 1.2
		var runs: Array = []
		for z: float in [-inset, Roads.BACK + inset]:
			var stops: Array = [-Roads.SIDE + Roads.BEND, Roads.CUTS[0], Roads.CUTS[1], Roads.SIDE - Roads.BEND]
			for i in 3:
				runs.append([Vector3(stops[i] + inset, 0.0, z), Vector3(stops[i + 1] - inset, 0.0, z)])
		for x: float in [-Roads.SIDE + inset, Roads.SIDE - inset]:
			runs.append([Vector3(x, 0.0, -Roads.BEND), Vector3(x, 0.0, Roads.BACK + Roads.BEND)])
		for run: Array in runs:
			var board := BoxMesh.new()
			var span: Vector3 = run[1] - run[0]
			board.size = Vector3(maxf(absf(span.x), 0.12), 1.0, maxf(absf(span.z), 0.12))
			board.material = card
			var wall := MeshInstance3D.new()
			wall.mesh = board
			wall.position = (run[0] + run[1]) * 0.5
			add_child(wall)
			_walls.append(wall)
	var tall := 0.3 + 0.16 * level("wall")
	for wall in _walls:
		wall.scale.y = tall
		wall.position.y = tall * 0.5


## True if the dome swallowed an alien shot at `p`.
func dome_blocks(p: Vector2, heavy: bool) -> bool:
	if dome_charges <= 0 or p.y > DOME_RY:
		return false
	var e := Vector2(p.x / DOME_RX, p.y / DOME_RY)
	if e.length_squared() > 1.0:
		return false
	dome_charges = maxi(0, dome_charges - (2 if heavy else 1))
	_dome_hit = 1.0
	game.fx.burst(Vector3(p.x, p.y, 0.4), Color("9be7f5"), 8, 3.0)
	Sfx.play("dome", _rng.randf_range(0.9, 1.1), -6.0)
	return true


func update(delta: float) -> void:
	# The watchtower's spotters speed up every cooldown below
	delta *= 1.0 + 0.25 * level("watchtower")
	var swarm: Swarm = game.swarm

	for t in _turrets:
		var roof: City.Building = t.roof
		var node: Cutout = t.node
		node.position = roof.roof() + Vector3(0.0, -0.04, 0.02)
		node.visible = roof.alive()
		if not roof.alive():
			continue
		t.t -= delta
		if t.t <= 0.0:
			var from := Vector2(roof.x, roof.top() + 0.6)
			var a := swarm.nearest(from)
			if a != null:
				t.t = 1.0
				game.shots.fire("flak", from, (a.pos - from).normalized() * 18.0, 1.0)
				Sfx.play("flak", _rng.randf_range(0.9, 1.1), -12.0)

	if _summit != null:
		_summit_t -= delta
		if _summit_t <= 0.0:
			var mark := swarm.toughest()
			if mark != null:
				_summit_t = [5.0, 5.0, 3.5, 2.0][level("summit")]
				var hit := Vector3(mark.pos.x, mark.pos.y, 0.0)
				game.fx.beam(SUMMIT + Vector3(0.0, 1.2, 0.0), hit, Color(0.4, 1.0, 0.9), 0.3, 0.3)
				game.fx.beam(SUMMIT + Vector3(0.0, 1.2, 0.0), hit, Color.WHITE, 0.1, 0.3)
				game.hit_alien(mark, 3.0 + 2.0 * level("summit"), mark.pos)
				Sfx.play("beam", 1.4, -8.0)

	if _blucifer != null:
		_blucifer_t -= delta
		_blucifer.fade_flash(delta)
		if _blucifer_t <= 0.0:
			var a := swarm.toughest()
			if a != null:
				_blucifer_t = [7.0, 7.0, 5.0, 3.0][level("blucifer")]
				_stare(a)

	if _battery != null:
		_battery_t -= delta
		if _battery_t <= 0.0 and swarm.toughest() != null:
			var lv := level("battery")
			_battery_t = [4.5, 4.5, 3.4, 2.6][lv]
			for i in (2 if lv >= 3 else 1):
				var m: Shots.Shot = game.shots.fire("missile", BATTERY_AT, Vector2(1.5 + i * 2.5, 9.0), 3.0, 0, 1.0 + 0.3 * lv)
				m.life = 5.0
				m.target = swarm.toughest() if i == 0 else swarm.lowest()
				m.position.z = -3.2
				m.create_tween().tween_property(m, "position:z", 0.0, 0.6)
			Sfx.play("missile", 1.0, -8.0)

	if _tesla != null:
		var roof: City.Building = game.city.by_id("republic")
		_tesla.position = roof.roof() + Vector3(0.0, -0.04, 0.02)
		_tesla.visible = roof.alive()
		_tesla_t -= delta
		if roof.alive() and _tesla_t <= 0.0:
			var tip := Vector2(roof.x, roof.top() + 1.0)
			if swarm.nearest(tip) != null:
				_tesla_t = 1.5 if level("tesla") >= 3 else 3.0
				_zap(tip)

	if _hail != null:
		_hail_t -= delta
		if _hail_ticks > 0:
			_hail_cloud.position.x = lerpf(_hail_cloud.position.x, game.player.x, 1.0 - exp(-3.0 * delta))
			_hail_tick_t -= delta
			if _hail_tick_t <= 0.0:
				_hail_tick_t = 0.7
				_hail_ticks -= 1
				for a: Alien in swarm.aliens.duplicate():
					if not a.dead:
						game.hit_alien(a, 2.0 if level("hail") >= 3 else 1.0, a.pos + Vector2(0.0, a.hy))
				if _hail_ticks == 0:
					_hail.emitting = false
		else:
			_hail_cloud.position.x = lerpf(_hail_cloud.position.x, -40.0, 1.0 - exp(-1.5 * delta))
			if _hail_t <= 0.0 and not swarm.cleared():
				_hail_t = [14.0, 14.0, 9.0, 6.0][level("hail")]
				_hail_ticks = 3
				_hail_tick_t = 0.8
				var top: float = game.diorama.play_top
				_hail_cloud.position.y = top + 1.5
				_hail.position.y = top + 1.0
				_hail.lifetime = (top + 1.0) / 16.0
				_hail.emitting = true
				Sfx.play("hail")

	if _dome != null:
		_dome_hit = maxf(0.0, _dome_hit - delta * 4.0)
		_dome_mat.set_shader_parameter("hit", _dome_hit)
		_dome_mat.set_shader_parameter("charge", float(dome_charges) / maxf(1.0, _dome_max))


## Blucifer's laser: a line from its eye through the target to the edge of the sky.
func _stare(target: Alien) -> void:
	var eye := Vector2(BLUCIFER_EYE.x, BLUCIFER_EYE.y)
	var dir := (target.pos - eye).normalized()
	var far := eye + dir * 26.0
	var dmg: float = [5.0, 5.0, 9.0, 14.0][level("blucifer")]
	for a: Alien in game.swarm.aliens.duplicate():
		if a.dead:
			continue
		var along := clampf((a.pos - eye).dot(dir), 0.0, 26.0)
		if (eye + dir * along).distance_to(a.pos) < maxf(a.hx, a.hy) + 0.2:
			game.hit_alien(a, dmg, a.pos)
	game.fx.beam(BLUCIFER_EYE, Vector3(far.x, far.y, 0.0), Color(1.0, 0.15, 0.2), 0.34, 0.4)
	game.fx.beam(BLUCIFER_EYE, Vector3(far.x, far.y, 0.0), Color(1.0, 0.8, 0.7), 0.1, 0.4)
	_blucifer.flash(0.7)
	Sfx.play("beam", 1.0, -4.0)


func _zap(tip: Vector2) -> void:
	var lv := level("tesla")
	var jumps: int = [3, 3, 5, 8][lv]
	var dmg := 2.0 if lv == 1 else 3.0
	var from := tip
	var done: Array = []
	for i in jumps:
		var a: Alien = game.swarm.nearest(from, INF if i == 0 else 3.2, done)
		if a == null:
			break
		done.append(a)
		game.fx.bolt(Vector3(from.x, from.y, 0.05), Vector3(a.pos.x, a.pos.y, 0.05), Color(0.6, 0.95, 1.0))
		from = a.pos
		game.hit_alien(a, dmg, a.pos)
	Sfx.play("zap", _rng.randf_range(0.9, 1.1), -5.0)


func _pop_in(node: Node3D) -> void:
	node.scale = Vector3(1.0, 0.0, 1.0)
	node.create_tween().tween_property(node, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_dome() -> void:
	_dome = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(DOME_RX * 2.0, DOME_RY) / 0.955
	quad.center_offset = Vector3(0.0, quad.size.y * 0.5, 0.0)
	_dome.mesh = quad
	_dome_mat = ShaderMaterial.new()
	_dome_mat.shader = load("res://shaders/dome.gdshader")
	_dome.material_override = _dome_mat
	_dome.position = Vector3(0.0, 0.0, 0.5)
	add_child(_dome)


func _build_hail() -> void:
	_hail_cloud = Cutout.make("cloud", Cutout.PPU * 0.7)
	_hail_cloud.set_tint(Color(0.55, 0.58, 0.7))
	_hail_cloud.set_border(1.5)
	_hail_cloud.position = Vector3(-22.0, 13.5, 0.6)
	add_child(_hail_cloud)
	_hail = CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.92, 0.97, 1.0)
	quad.material = m
	_hail.mesh = quad
	_hail.amount = 240
	_hail.lifetime = 0.8
	_hail.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_hail.emission_box_extents = Vector3(City.HALF + 1.0, 0.2, 0.4)
	_hail.direction = Vector3.DOWN
	_hail.spread = 2.0
	_hail.gravity = Vector3.ZERO
	_hail.initial_velocity_min = 15.0
	_hail.initial_velocity_max = 18.0
	_hail.position = Vector3(0.0, 13.4, 0.2)
	_hail.emitting = false
	add_child(_hail)
