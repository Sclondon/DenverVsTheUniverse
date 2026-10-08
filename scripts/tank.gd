class_name Tank
extends Figure
## The player: a giant action-figure robot built from an F-15, running the street through town and
## shooting at the nearest alien in range. The Strike Eagle Refit card (id "mech") uprates it, and a second copy awakens it.

const LIMIT := City.HALF - 0.5
const BASE_HEARTS := 6
## The gun pod is in the right hand, held overhead: shots leave from this far right of centre.
const GUN_X := 0.79
## The model is built 3 units tall; the robot stands this much bigger.
const SIZE := 1.2
const DASH_SPEED := 30.0
const DASH_TIME := 0.26
const SPIN_TIME := 0.38
const LAND_TIME := 0.2
## The point the model turns about when it flips, in its own units.
const MIDDLE := Vector3(0.0, 1.6, 0.0)
const GRAVITY := 30.0
## Per chassis (stock, Strike Eagle, awakened): extra hearts, height the shots leave from, hit box
## (half width, centre height, half height) and seconds for the A.T. field to recharge (0 = none).
const CHASSIS := [
	{"tint": "ffffff", "hearts": 0, "muzzle": 5.25, "box": Vector3(0.7, 1.65, 1.5), "field": 0.0},
	{"tint": "9aa0b4", "hearts": 2, "muzzle": 5.25, "box": Vector3(0.7, 1.65, 1.5), "field": 12.0},
	{"tint": "f0a0e0", "hearts": 3, "muzzle": 5.25, "box": Vector3(0.7, 1.65, 1.5), "field": 7.0},
]

var game
var x := 0.0
## How far back from the front street it is (Roads): 0 on the front street, negative behind.
var z := 0.0
var goal_z := 0.0
## A wingman: a robot that steers itself (see _think). `post` is the side of the leader it keeps to,
## and `down` is true once it has been destroyed.
var ai := false
var post := 1.0
var down := false
## True while wingmen are switched off in the options.
var benched := false
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

## How good the dash and the jump are: 1 to start with, more with cards and tech.
var dash_level := 0
var jump_level := 0
## Height off the street while jumping.
var y := 0.0
## Which way it last ran: the way a dash goes when no direction is given.
var facing := 1.0
var _vy := 0.0
## How far the gun can pick out a target, and the angle it is turned to (0 = straight up).
var aim_range := 17.0
var _aim := 0.0
var _arm_aim := 0.0
var _dash_t := 0.0
var _dash_dir := 0.0
var _dash_cool := 0.0
var _air_t := 0.0
var _air_len := 0.0
var _flips := 1.0
var _land := 0.0
var _spin_t := 0.0
var _spin_dir := 1.0
var _was_facing := 1.0
var _dir := Vector2.RIGHT
var _lean_z := 0.0
## Whether the gun has a target, and how far (0 to 1) the gun arm has dropped to the ready.
var _locked := false
var _at_ease := 1.0
var _bubble: MeshInstance3D
var _ring: MeshInstance3D
var _bubble_mat: ShaderMaterial
var _power := 0.0
var _pop := 0.0
## How far through its run cycle it is.
var _run := 0.0
## Standing still: how settled into its stance it is (0 to 1), how long it has stood, and an offset
## so the three robots do not fidget in step.
var _still := 0.0
var _idle_t := 0.0
var _idle_from := randf() * 5.5
## Where the nearest alien is from the gun, in range or not, for the head to watch.
var _watching := false
var _watch := Vector2.UP


func _init() -> void:
	build("robot")
	# The force field the refits carry: a bubble that shows while it is charged
	var ball := SphereMesh.new()
	ball.radius = 2.25
	ball.height = 4.5
	_bubble_mat = ShaderMaterial.new()
	_bubble_mat.shader = preload("res://shaders/shield.gdshader")
	_bubble = MeshInstance3D.new()
	_bubble.mesh = ball
	_bubble.material_override = _bubble_mat
	_bubble.position.y = 1.7
	_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bubble)
	# A faint circle showing how far the gun can pick out a target
	var hoop := TorusMesh.new()
	hoop.inner_radius = 0.994
	hoop.outer_radius = 1.006
	hoop.rings = 96
	hoop.ring_segments = 4
	var faint := StandardMaterial3D.new()
	faint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	faint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	faint.albedo_color = Color(0.6, 1.0, 0.45, 0.2)
	faint.no_depth_test = true
	hoop.material = faint
	_ring = MeshInstance3D.new()
	_ring.mesh = hoop
	# It stands apart from the body, so nothing the body does (recoil, bobbing, flips) moves it
	_ring.top_level = true
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func reset() -> void:
	y = 0.0
	_vy = 0.0
	_dash_t = 0.0
	_dash_cool = 0.0
	x = 0.0
	z = 0.0
	goal_x = 0.0
	goal_z = 0.0
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
	# Every robot can dash and jump from the start; the cards and tech make them better
	dash_level = 1 + int(levels.get("dash", 0))
	aim_range = 17.0 + 4.0 * int(levels.get("radar", 0))
	jump_level = 1 + int(levels.get("jump", 0))
	var drones := int(levels.get("drone", 0))
	while _drones.size() > drones:
		_drones.pop_back().queue_free()
	while _drones.size() < drones:
		var d := Cutout.make("drone", Cutout.PPU * 1.1)
		add_child(d)
		_drones.append(d)


## A burst sideways that nothing can hit it during. The Vector Dash card makes it ready sooner. `dir` 0 = the way it faces.
func dash(dir: float) -> void:
	if dash_level == 0 or _dash_cool > 0.0:
		return
	_dash_dir = signf(dir) if dir != 0.0 else facing
	# It dashes on down the street it is on
	var ahead := Roads.ahead(Vector2(x, z), Vector2(_dash_dir, 0.0) if dir != 0.0 else _dir, 8.0)
	if ahead.distance_to(Vector2(x, z)) < 0.1:
		ahead = Roads.ahead(Vector2(x, z), _dir, 8.0)
	goal_x = ahead.x
	goal_z = ahead.y
	_dash_t = DASH_TIME
	_dash_cool = [1.6, 1.6, 0.8, 0.5][mini(dash_level, 3)]
	invuln = maxf(invuln, DASH_TIME + 0.1)
	Sfx.play("missile", 1.7, -8.0)


## A showy backflip on the spot, for when a wave is beaten. Needs no card.
func celebrate() -> void:
	if y > 0.0:
		return
	_vy = 10.0
	_take_off(-1.0)


func _take_off(flips: float) -> void:
	_air_t = 0.0
	_air_len = 2.0 * _vy / GRAVITY
	_flips = flips


func dashing() -> bool:
	return _dash_t > 0.0


## A leap on the engines. The Vertical Takeoff card makes it higher.
func jump() -> void:
	if jump_level == 0 or y > 0.0:
		return
	_vy = [13.0, 13.0, 15.5, 17.5][mini(jump_level, 3)]
	_take_off(1.0 if jump_level == 1 else 2.0)
	Sfx.play("missile", 0.8, -8.0)


## Which way it is running and how hard: -1 (flat out left) to 1.
func heading() -> float:
	return _lean


func overlaps(p: Vector2, r: float) -> bool:
	var box: Vector3 = CHASSIS[chassis].box
	return absf(p.x - x) < box.x + r and absf(p.y - box.y - y) < box.z + r


## The mech's A.T. field: soaks up one hit, then has to recharge. True if it took this one.
func absorb() -> bool:
	var recharge: float = CHASSIS[chassis].field
	if recharge <= 0.0 or _field > 0.0:
		return false
	_field = recharge
	_pop = 1.0
	return true


func update(delta: float, firing: bool) -> void:
	if down or benched:
		visible = false
		return
	var here := Vector2(x, z)
	if ai:
		_think()
	var goal := Roads.snap(Vector2(goal_x, goal_z))
	goal_x = goal.x
	goal_z = goal.y
	var before := x
	_dash_cool = maxf(0.0, _dash_cool - delta)
	var pace_now := speed
	if _dash_t > 0.0:
		_dash_t -= delta
		pace_now = DASH_SPEED
	var moved := here.move_toward(Roads.route(here, goal), pace_now * delta)
	if moved != here:
		_dir = (moved - here).normalized()
		if absf(_dir.x) > 0.3:
			facing = signf(_dir.x)
		_run += moved.distance_to(here) * 2.3 / SIZE
	x = moved.x
	z = moved.y
	_lean_z = lerpf(_lean_z, (moved.y - here.y) / maxf(delta, 0.001) / speed, 1.0 - exp(-10.0 * delta))
	if y > 0.0 or _vy > 0.0:
		_vy -= GRAVITY * delta
		y = maxf(0.0, y + _vy * delta)
		if y == 0.0:
			_vy = 0.0
			game.diorama.shake(0.25)
			_land = LAND_TIME
	_lean = lerpf(_lean, (x - before) / maxf(delta, 0.001) / speed, 1.0 - exp(-10.0 * delta))
	invuln = maxf(0.0, invuln - delta)
	overdrive = maxf(0.0, overdrive - delta)
	_field = maxf(0.0, _field - delta)
	visible = invuln <= 0.0 or fmod(invuln, 0.16) > 0.08
	var muzzle: float = CHASSIS[chassis].muzzle
	_cool -= delta
	# It only shoots at what its gun can reach: with nothing in the ring, everything holds fire
	var from := Vector2(x + GUN_X, muzzle + y)
	var target := _target(from) if firing else null
	_locked = target != null
	firing = _locked
	if target != null:
		_aim = clampf(atan2(target.pos.x - from.x, target.pos.y - from.y), -2.7, 2.7)
	var near: Alien = game.swarm.nearest(from)
	_watching = near != null
	if near != null:
		_watch = near.pos - from
	if firing and _cool <= 0.0:
		_cool = 1.0 / (fire_rate * (2.0 if overdrive > 0.0 else 1.0) * (1.5 if y > 0.0 and jump_level > 1 else 1.0))
		_fire(from, target)
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
	_acrobatics(delta)
	# The ring is exactly the gun's reach, centred where its shots are measured from
	_ring.global_transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3.ONE * aim_range), Vector3(x + GUN_X, muzzle + y, z))
	_pop = maxf(0.0, _pop - delta * 2.5)
	var shielded: bool = float(CHASSIS[chassis].field) > 0.0 and _field <= 0.0
	_power = move_toward(_power, 1.0 if shielded else 0.0, delta * 3.0)
	_bubble.visible = _power > 0.0 or _pop > 0.0
	_bubble.scale = Vector3.ONE * (1.0 + (1.0 - _pop) * 0.25 * signf(_pop))
	_bubble_mat.set_shader_parameter("power", _power)
	_bubble_mat.set_shader_parameter("pop", _pop)
	position = Vector3(x, y + absf(sin(_run)) * 0.1 * clampf(Vector2(_lean, _lean_z).length(), 0.0, 1.0), z)
	rotation.z = 0.0
	var squash := maxf(_recoil * 0.03, _land * 0.5)
	scale = Vector3(1.0 + squash * 0.8, 1.0 - squash, 1.0) * SIZE
	fade_flash(delta)


## The robot is an athlete: it turns and leans into a proper run (knees driving, free arm
## pumping), spins on its heel when it doubles back, cartwheels through a dash and tucks into a
## flip off the ground. Through all of it the gun arm stays on its target.
func _acrobatics(delta: float) -> void:
	var pace := clampf(Vector2(_lean, _lean_z).length(), 0.0, 1.0)
	_land = maxf(0.0, _land - delta)
	if facing != _was_facing and pace > 0.45 and _spin_t <= 0.0:
		_spin_t = SPIN_TIME
		_spin_dir = facing
	_was_facing = facing

	# The run cycle. Each leg swings from the hip and folds at the knee as it comes forward;
	# the free arm pumps against its leg with the elbow bent.
	var breath := sin(Time.get_ticks_msec() * 0.003)
	for side: String in ["l", "r"]:
		var phase := _run + (0.0 if side == "l" else PI)
		limbs["leg_" + side].rotation = Vector3(sin(phase) * 0.95 * pace, 0.0, 0.0)
		limbs["knee_" + side].rotation.x = 0.06 + breath * 0.02 + pace * (0.2 + 1.25 * pow(maxf(0.0, -cos(phase)), 1.4))
	limbs.arm_l.rotation = Vector3(-sin(_run) * 0.9 * pace + breath * 0.03, 0.0, -0.08)
	limbs.elbow_l.rotation.x = -0.15 - 1.25 * pace
	# Standing still it does not just stop. It settles into a stance (turned a little, weight on one
	# leg, free hand on its hip, breathing) and every few seconds it fidgets: checks the blaster,
	# shades its eyes to scan the sky, or bounces on its toes.
	var still_now := pace < 0.08 and y <= 0.0 and _dash_t <= 0.0 and _land <= 0.0
	_still = move_toward(_still, 1.0 if still_now else 0.0, delta * (3.0 if still_now else 8.0))
	_idle_t = _idle_t + delta if still_now else 0.0
	var beat := fmod(_idle_t + _idle_from, 5.5) / 2.4
	var act := -1
	var fidget := 0.0
	if _idle_t > 1.2 and beat < 1.0 and not _locked:
		act = int((_idle_t + _idle_from) / 5.5) % 3
		fidget = smoothstep(0.0, 0.25, beat) * (1.0 - smoothstep(0.75, 1.0, beat))
	if _still > 0.0:
		var bounce := absf(sin(beat * TAU * 1.5)) * fidget if act == 2 else 0.0
		limbs.leg_l.rotation = limbs.leg_l.rotation.lerp(Vector3(-0.08 - bounce * 0.3, 0.0, -0.13), _still)
		limbs.leg_r.rotation = limbs.leg_r.rotation.lerp(Vector3(-0.2 - bounce * 0.3, 0.0, 0.1), _still)
		limbs.knee_l.rotation.x = lerpf(limbs.knee_l.rotation.x, 0.12 + breath * 0.03 + bounce * 0.6, _still)
		limbs.knee_r.rotation.x = lerpf(limbs.knee_r.rotation.x, 0.38 + breath * 0.03 + bounce * 0.6, _still)
		# The free hand rests on the hip, elbow out
		var arm := Vector3(0.25, 0.0, -0.62 + breath * 0.03)
		var elbow := Vector3(-0.35, 0.0, 1.5)
		if act == 1:
			# Hand up to the brow, shading its eyes
			arm = arm.lerp(Vector3(-2.2, 0.0, -0.55), fidget)
			elbow = elbow.lerp(Vector3(-2.1, 0.0, 0.5), fidget)
		elif act == 2:
			# Shaking the arm loose
			arm = arm.lerp(Vector3(sin(beat * TAU * 3.0) * 0.25, 0.0, -0.3), fidget)
			elbow = elbow.lerp(Vector3(-0.4 - absf(sin(beat * TAU * 3.0)) * 0.5, 0.0, 0.0), fidget)
		limbs.arm_l.rotation = limbs.arm_l.rotation.lerp(arm, _still)
		limbs.elbow_l.rotation = limbs.elbow_l.rotation.lerp(elbow, _still)
	else:
		limbs.elbow_l.rotation.y = 0.0
		limbs.elbow_l.rotation.z = 0.0
	# It turns to face the way it is running: side on along a street, its back to us going away
	var yaw := atan2(_lean, _lean_z + 0.35) * pace + sin(_run) * 0.16 * pace
	# Hips sway and shoulders counter-turn with each stride
	var roll := sin(_run) * 0.06 * pace
	var flip := 0.0
	var lean := 0.24 * pace
	if _still > 0.0:
		var scan := sin(beat * TAU) * 0.35 * fidget if act == 1 else 0.0
		yaw = lerp_angle(yaw, facing * 0.5 + sin(_idle_t * 0.5) * 0.08 + scan, _still)
		roll += (0.035 + sin(_idle_t * 0.9) * 0.02) * _still
		lean += breath * 0.02 * _still
	if _spin_t > 0.0:
		_spin_t -= delta
		yaw += _spin_dir * TAU * ease(1.0 - maxf(_spin_t, 0.0) / SPIN_TIME, -2.0)
	if _dash_t > 0.0:
		# A cartwheel: limbs flung out like spokes
		roll = -_dash_dir * TAU * (1.0 - _dash_t / DASH_TIME)
		yaw = 0.0
		lean = 0.0
		limbs.arm_l.rotation = Vector3(0.0, 0.0, -2.6)
		limbs.elbow_l.rotation.x = 0.0
		limbs.leg_l.rotation = Vector3(0.0, 0.0, -0.55)
		limbs.leg_r.rotation = Vector3(0.0, 0.0, 0.55)
		limbs.knee_l.rotation.x = 0.0
		limbs.knee_r.rotation.x = 0.0
	elif y > 0.0 and _air_len > 0.0:
		_air_t += delta
		var through := clampf(_air_t / _air_len, 0.0, 1.0)
		flip = TAU * ease(through, -1.6) * _flips
		# Knees to the chest and the free arm out while it turns over
		var tuck := sin(through * PI)
		limbs.leg_l.rotation.x = -1.5 * tuck
		limbs.leg_r.rotation.x = -1.2 * tuck
		limbs.knee_l.rotation.x = 1.9 * tuck
		limbs.knee_r.rotation.x = 1.6 * tuck
		limbs.arm_l.rotation = Vector3(-0.4 * tuck, 0.0, -1.4 * tuck)
	elif _land > 0.0:
		# It lands in a crouch
		var crouch := _land / LAND_TIME
		limbs.leg_l.rotation.x = -0.7 * crouch
		limbs.leg_r.rotation.x = -0.7 * crouch
		limbs.knee_l.rotation.x = 1.4 * crouch
		limbs.knee_r.rotation.x = 1.4 * crouch
	# Everything turns about the robot's middle, not its feet
	var turn := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, roll) * Basis(Vector3.RIGHT, flip + lean)
	body.transform = Transform3D(turn, MIDDLE - turn * MIDDLE)
	# The gun arm: elbow bent, forearm and blaster laid along the line of fire whichever way up the
	# robot is. With nothing to shoot at it comes down to the low ready, muzzle at the ground.
	_arm_aim = lerp_angle(_arm_aim, _aim, 1.0 - exp(-14.0 * delta))
	_at_ease = move_toward(_at_ease, 0.0 if _locked else 1.0, delta * 3.0)
	var bend := lerpf(0.7, 1.2, _at_ease) + _recoil * 0.4
	var ready := Vector3(facing * 0.5, -0.4, 0.75).normalized()
	if act == 0:
		# Checking the blaster: up in front of the face, turned this way and that
		ready = ready.slerp(Vector3(facing * 0.25 + sin(beat * TAU * 2.0) * 0.12, 0.8, 0.55).normalized(), fidget)
		bend += 0.6 * fidget
	var line := Vector3(sin(_arm_aim), cos(_arm_aim), 0.15).normalized().slerp(ready, _at_ease)
	var at := (turn.inverse() * line).normalized()
	var raised := Basis(Vector3.RIGHT, PI)
	var forearm := (raised * Basis(Vector3.RIGHT, -bend) * Vector3.DOWN).normalized()
	limbs.arm_r.basis = Basis(Quaternion(forearm, at)) * raised
	limbs.elbow_r.rotation.x = -bend
	# The head watches what the gun is on. With nothing in reach it watches the nearest alien
	# wherever that is, or looks about the sky; it never just stares out at the player.
	var gaze := line
	if not _locked:
		gaze = Vector3(sin(_idle_t * 0.6 + _idle_from) * 0.8, 0.5, 0.5)
		if _watching:
			gaze = Vector3(_watch.x, _watch.y, 0.0).normalized() + Vector3(0.0, 0.0, 0.25)
		if act == 0:
			gaze = gaze.normalized().slerp(Vector3(facing * 0.3, 0.15, 0.9).normalized(), fidget)
		elif act == 1:
			gaze = gaze.normalized().slerp(Vector3(sin(beat * TAU) * 0.9, 0.5, 0.45).normalized(), fidget)
	look((turn.inverse() * gaze.normalized()).normalized(), delta)


## Sets the wingman up at this level of the Wingman Drills card (0 = as it first arrives).
func enlist(level: int) -> void:
	ai = true
	set_tint(Color(1.0, 0.74, 0.46))
	speed = 9.0 + level
	fire_rate = 1.3 + 0.45 * level
	damage = 1.0 + floorf(level * 0.5)
	barrels = 2 if level >= 3 else 1
	aim_range = 14.0 + 2.5 * level
	max_hearts = 3
	_ring.visible = false


## A wingman's whole mind: hold its side of the leader (`post`: -1 left, 1 right), go and stand
## under the alien furthest out on that side, and never crowd the leader.
func _think() -> void:
	var lead: Tank = game.player
	var pick: Alien = null
	var best := -4.0
	for a: Alien in game.swarm.aliens:
		if a.dead or a.pos.y > game.diorama.play_top + 1.0:
			continue
		var out := (a.pos.x - lead.x) * post
		if out > best:
			best = out
			pick = a
	var want := lead.x + post * 7.0 if pick == null else pick.pos.x - GUN_X
	if absf(want - lead.x) < 3.5 and lead.z > -2.0:
		want = lead.x + post * 3.5
	# The front street stops where the ring bends away
	goal_x = clampf(want, -Roads.SIDE + Roads.BEND, Roads.SIDE - Roads.BEND)
	goal_z = 0.0


## The nearest alien within reach of the gun, or null.
func _target(from: Vector2) -> Alien:
	var found: Alien = null
	var best := aim_range
	for a: Alien in game.swarm.aliens:
		var d := a.pos.distance_to(from)
		if not a.dead and d < best:
			best = d
			found = a
	return found


func _fire(from: Vector2, _target_now: Alien) -> void:
	_recoil = 1.0
	for i in barrels:
		var off := (i - (barrels - 1) * 0.5) * 0.34
		var ang := _aim + off * 0.16
		var dart: Shots.Shot = game.shots.fire("bullet", from + Vector2(off, 0.0), Vector2(sin(ang), cos(ang)) * 22.0, damage, pierce, splash)
		# Fired from a back street, it climbs forward to the plane the aliens hang in
		dart.depth = z
		dart.rise_from = from.y
		dart.position.z = z
	Sfx.play("shoot", randf_range(0.78, 0.9), -9.0)
