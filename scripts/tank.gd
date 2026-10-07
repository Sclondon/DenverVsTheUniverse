class_name Tank
extends Figure
## The player: a giant action-figure robot built from an F-15, running the street through town and
## shooting at the nearest alien in range. The Strike Eagle Refit card (id "mech") uprates it, and a second copy awakens it.

const LIMIT := City.HALF - 0.5
const BASE_HEARTS := 6
## The gun pod is in the right hand, held overhead: shots leave from this far right of centre.
const GUN_X := 0.92
## The model is built 3 units tall; the robot stands this much bigger.
const SIZE := 1.4
const DASH_SPEED := 42.0
const GRAVITY := 30.0
## Per chassis (stock, Strike Eagle, awakened): extra hearts, height the shots leave from, hit box
## (half width, centre height, half height) and seconds for the A.T. field to recharge (0 = none).
const CHASSIS := [
	{"tint": "ffffff", "hearts": 0, "muzzle": 6.0, "box": Vector3(0.8, 1.9, 1.75), "field": 0.0},
	{"tint": "9aa0b4", "hearts": 2, "muzzle": 6.0, "box": Vector3(0.8, 1.9, 1.75), "field": 12.0},
	{"tint": "f0a0e0", "hearts": 3, "muzzle": 6.0, "box": Vector3(0.8, 1.9, 1.75), "field": 7.0},
]

var game
var x := 0.0
## Where the driver is steering to; the tank chases it at `speed`.
var goal_x := 0.0
var chassis := 0
var speed := 13.0
var fire_rate := 2.6
var damage := 1.0
var barrels := 1
var pierce := 0
var splash := 0.0
var rockets := 0
var hearts := BASE_HEARTS
var max_hearts := BASE_HEARTS
var invuln := 0.0
## Seconds of doubled fire rate left from a supply crate.
var overdrive := 0.0

var _cool := 0.0
var _recoil := 0.0
var _lean := 0.0
var _field := 0.0
var _rocket_t := 2.0
var _drones: Array[Cutout] = []
var _drone_t := 0.0

## Abilities unlocked by cards (0 = not yet): the dash and the jump.
var dash_level := 0
var jump_level := 0
## Height off the street while jumping.
var y := 0.0
## Which way it last ran: the way a dash goes when no direction is given.
var facing := 1.0
var _vy := 0.0
## How far the gun can pick out a target, and the angle it is turned to (0 = straight up).
var aim_range := 9.0
var _aim := 0.0
var _arm_aim := 0.0
var _dash_t := 0.0
var _dash_dir := 0.0
var _dash_cool := 0.0


func _init() -> void:
	build("robot")


func reset() -> void:
	y = 0.0
	_vy = 0.0
	_dash_t = 0.0
	_dash_cool = 0.0
	x = 0.0
	goal_x = 0.0
	invuln = 0.0
	overdrive = 0.0
	_field = 0.0
	visible = true
	apply({})
	hearts = max_hearts


## Recomputes the tank's stats (and its body) from the upgrade levels.
func apply(levels: Dictionary) -> void:
	var want := mini(int(levels.get("mech", 0)), CHASSIS.size() - 1)
	if want != chassis:
		chassis = want
		set_tint(Color(CHASSIS[chassis].tint))
	fire_rate = 2.6 * (1.0 + 0.25 * int(levels.get("rapid", 0))) * (1.3 if chassis == 2 else 1.0)
	damage = 1.0 + int(levels.get("heavy", 0)) + chassis
	barrels = 1 + int(levels.get("twin", 0))
	pierce = int(levels.get("pierce", 0))
	var chile := int(levels.get("chile", 0))
	splash = 0.0 if chile == 0 else 0.7 + 0.35 * chile
	speed = 13.0 * (1.0 + 0.2 * int(levels.get("treads", 0)))
	max_hearts = BASE_HEARTS + int(levels.get("armor", 0)) + int(CHASSIS[chassis].hearts)
	rockets = int(levels.get("rockets", 0))
	dash_level = int(levels.get("dash", 0))
	aim_range = 9.0 + 4.0 * int(levels.get("radar", 0))
	jump_level = int(levels.get("jump", 0))
	var drones := int(levels.get("drone", 0))
	while _drones.size() > drones:
		_drones.pop_back().queue_free()
	while _drones.size() < drones:
		var d := Cutout.make("drone", Cutout.PPU * 1.1)
		add_child(d)
		_drones.append(d)


## A burst sideways that nothing can hit it during. Needs the Vector Dash card. `dir` 0 = the way it faces.
func dash(dir: float) -> void:
	if dash_level == 0 or _dash_cool > 0.0:
		return
	_dash_dir = signf(dir) if dir != 0.0 else facing
	_dash_t = 0.17
	_dash_cool = 1.6 if dash_level == 1 else 0.8
	invuln = maxf(invuln, 0.3)
	Sfx.play("missile", 1.7, -8.0)


## A leap on the engines. Needs the Vertical Takeoff card.
func jump() -> void:
	if jump_level == 0 or y > 0.0:
		return
	_vy = 13.0 if jump_level == 1 else 15.5
	Sfx.play("missile", 0.8, -8.0)


func overlaps(p: Vector2, r: float) -> bool:
	var box: Vector3 = CHASSIS[chassis].box
	return absf(p.x - x) < box.x + r and absf(p.y - box.y - y) < box.z + r


## The mech's A.T. field: soaks up one hit, then has to recharge. True if it took this one.
func absorb() -> bool:
	var recharge: float = CHASSIS[chassis].field
	if recharge <= 0.0 or _field > 0.0:
		return false
	_field = recharge
	return true


func update(delta: float, firing: bool) -> void:
	var axis := 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		axis -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		axis += 1.0
	if axis != 0.0:
		goal_x = x + axis
	goal_x = clampf(goal_x, -LIMIT, LIMIT)
	var before := x
	x = move_toward(x, goal_x, speed * delta)
	if x != before:
		facing = signf(x - before)
	_dash_cool = maxf(0.0, _dash_cool - delta)
	if _dash_t > 0.0:
		_dash_t -= delta
		x = clampf(x + _dash_dir * DASH_SPEED * delta, -LIMIT, LIMIT)
		goal_x = x
	if y > 0.0 or _vy > 0.0:
		_vy -= GRAVITY * delta
		y = maxf(0.0, y + _vy * delta)
		if y == 0.0:
			_vy = 0.0
			game.diorama.shake(0.25)
	_lean = lerpf(_lean, (x - before) / maxf(delta, 0.001) / speed, 1.0 - exp(-10.0 * delta))
	invuln = maxf(0.0, invuln - delta)
	overdrive = maxf(0.0, overdrive - delta)
	_field = maxf(0.0, _field - delta)
	visible = invuln <= 0.0 or fmod(invuln, 0.16) > 0.08
	var muzzle: float = CHASSIS[chassis].muzzle
	_cool -= delta
	if firing and _cool <= 0.0:
		_cool = 1.0 / (fire_rate * (2.0 if overdrive > 0.0 else 1.0) * (1.5 if y > 0.0 and jump_level > 1 else 1.0))
		_fire(muzzle + y)
	if firing and rockets > 0:
		_rocket_t -= delta
		if _rocket_t <= 0.0 and game.swarm.toughest() != null:
			_rocket_t = [3.5, 3.5, 2.6, 1.8][rockets]
			var m: Shots.Shot = game.shots.fire("missile", Vector2(x, 4.0), Vector2(randf_range(-4.0, 4.0), 9.0), 3.0, 0, 1.0)
			m.life = 5.0
			m.target = game.swarm.toughest()
			Sfx.play("missile", 1.2, -10.0)
	_drone_t -= delta
	for i in _drones.size():
		var side := -1.0 if i % 2 == 0 else 1.0
		_drones[i].position = Vector3(side * 1.6, 3.5 + sin(Time.get_ticks_msec() * 0.004 + i) * 0.12, 0.0)
		if firing and _drone_t <= 0.0:
			game.shots.fire("flak", Vector2(x + side * 2.0, 4.8), Vector2(0.0, 20.0), 1.0)
	if _drone_t <= 0.0:
		_drone_t = 0.8
	_recoil = maxf(0.0, _recoil - delta * 6.0)
	# It runs: legs and the free arm swing, and the gun arm stays raised to the sky
	stride(x * 3.0)
	limbs.arm_r.rotation.x = PI - 0.1 + _recoil * 0.12
	_arm_aim = lerp_angle(_arm_aim, _aim, 1.0 - exp(-18.0 * delta))
	limbs.arm_r.rotation.z = _arm_aim
	position = Vector3(x, y + absf(sin(x * 3.0)) * 0.12, 0.0)
	rotation.z = -_lean * 0.09 - (_dash_dir * 0.35 if _dash_t > 0.0 else 0.0)
	scale = Vector3(1.0 + _recoil * 0.04, 1.0 - _recoil * 0.05, 1.0) * SIZE
	fade_flash(delta)


## The nearest alien within reach of the gun, or null.
func _target(from: Vector2) -> Alien:
	var found: Alien = null
	var best := aim_range
	for a: Alien in game.swarm.aliens:
		var d := a.pos.distance_to(from)
		if not a.dead and a.pos.y > from.y - 2.0 and d < best:
			best = d
			found = a
	return found


func _fire(muzzle: float) -> void:
	_recoil = 1.0
	# It shoots at the nearest alien in range, and straight up when there is none
	var from := Vector2(x + GUN_X, muzzle)
	var target := _target(from)
	_aim = 0.0
	if target != null:
		var to := target.pos - from
		_aim = clampf(atan2(to.x, to.y), -1.35, 1.35)
	for i in barrels:
		var off := (i - (barrels - 1) * 0.5) * 0.34
		var ang := _aim + off * 0.16
		game.shots.fire("bullet", from + Vector2(off, 0.0), Vector2(sin(ang), cos(ang)) * 22.0, damage, pierce, splash)
	Sfx.play("shoot", randf_range(0.78, 0.9), -9.0)
