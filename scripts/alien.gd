class_name Alien
extends Figure
## One invader: an alien action figure dangling on fishing line. Swarm moves them; this holds what
## each kind is and its puppet animation.

enum Mode { FORM, DIVE, FREE, SAUCER, BOSS, GROUND }

## bomb: chance to actually drop when the swarm picks this alien. hx/hy: half-size of the hit box.
## spits: aims shots at the robot. dives: breaks formation to dive on it. heavy: one to a row, with
## a bigger bomb. splits: the kind it bursts into, two of them. loose: no fishing line. walks: lands
## and stomps (pace is how fast). crash: floors it takes off a building it lands on (4 if not given).
## The models are models/alien_<kind>.glb. These are few and large, more kaiju than swarm.
const TYPES := {
	# The Venusians: tin toys and little green men
	"grunt": {"hp": 5, "score": 40, "hx": 0.6, "hy": 1.15, "bomb": 1.0, "color": "8be04e"},
	"crab": {"hp": 9, "score": 80, "hx": 0.85, "hy": 0.6, "bomb": 0.8, "color": "c9cfd6"},
	"diver": {"hp": 3, "score": 90, "hx": 0.7, "hy": 0.6, "bomb": 0.3, "dives": true, "crash": 2, "color": "e0263c"},
	"spitter": {"hp": 7, "score": 100, "hx": 0.6, "hy": 1.15, "bomb": 0.0, "spits": true, "color": "f08ab0"},
	"kaiju": {"hp": 26, "score": 350, "hx": 1.2, "hy": 1.5, "bomb": 0.0, "walks": true, "pace": 1.2, "color": "5fbf4a"},
	# The Europans: things from the sea under the ice
	"jelly": {"hp": 6, "score": 50, "hx": 0.75, "hy": 1.05, "bomb": 1.0, "color": "9fe8ff"},
	"squid": {"hp": 4, "score": 95, "hx": 0.6, "hy": 0.8, "bomb": 0.3, "dives": true, "crash": 2, "color": "f4e9ff"},
	"angler": {"hp": 9, "score": 110, "hx": 0.8, "hy": 0.75, "bomb": 0.0, "spits": true, "color": "3b5a8c"},
	"urchin": {"hp": 9, "score": 120, "hx": 0.8, "hy": 0.8, "bomb": 0.5, "splits": "polyp", "color": "7a4fd0"},
	"polyp": {"hp": 2, "score": 20, "hx": 0.4, "hy": 0.4, "bomb": 0.0, "loose": true, "crash": 1, "color": "7a4fd0"},
	"turtle": {"hp": 42, "score": 450, "hx": 1.2, "hy": 1.5, "bomb": 0.0, "walks": true, "pace": 0.75, "color": "7a9a4a"},
	# The Titans: bronze and stone giants
	"hoplite": {"hp": 8, "score": 60, "hx": 0.7, "hy": 1.15, "bomb": 1.0, "color": "e0a040"},
	"meteor": {"hp": 5, "score": 100, "hx": 0.6, "hy": 0.65, "bomb": 0.3, "dives": true, "crash": 3, "color": "ff7a1a"},
	"saturn": {"hp": 10, "score": 130, "hx": 0.9, "hy": 0.6, "bomb": 0.5, "splits": "moon", "color": "e8b060"},
	"moon": {"hp": 3, "score": 25, "hx": 0.4, "hy": 0.4, "bomb": 0.0, "loose": true, "crash": 1, "color": "9a9aa8"},
	"brute": {"hp": 30, "score": 320, "hx": 1.15, "hy": 1.1, "bomb": 1.0, "heavy": true, "crash": 8, "color": "c8823a"},
	"cyclops": {"hp": 36, "score": 420, "hx": 1.2, "hy": 1.5, "bomb": 0.0, "walks": true, "pace": 1.0, "color": "a8623a"},
	# The Oort Cloud Collective: ice and crystal
	"cube": {"hp": 9, "score": 70, "hx": 0.75, "hy": 0.8, "bomb": 1.0, "color": "2f6bff"},
	"shard": {"hp": 5, "score": 105, "hx": 0.45, "hy": 0.85, "bomb": 0.3, "dives": true, "crash": 2, "color": "bfe0ff"},
	"prism": {"hp": 12, "score": 160, "hx": 0.9, "hy": 0.95, "bomb": 0.0, "spits": true, "color": "2f6bff"},
	"cluster": {"hp": 11, "score": 140, "hx": 0.85, "hy": 0.8, "bomb": 0.5, "splits": "chip", "color": "8a5cff"},
	"chip": {"hp": 3, "score": 25, "hx": 0.35, "hy": 0.42, "bomb": 0.0, "loose": true, "crash": 1, "color": "8a5cff"},
	"strider": {"hp": 32, "score": 480, "hx": 1.2, "hy": 1.5, "bomb": 0.0, "walks": true, "pace": 1.5, "color": "dff4ff"},
	# From deep space: the messengers
	"orb": {"hp": 10, "score": 80, "hx": 0.7, "hy": 0.75, "bomb": 1.0, "color": "f2f2ee"},
	"seraph": {"hp": 9, "score": 150, "hx": 0.8, "hy": 1.15, "bomb": 0.4, "dives": true, "crash": 2, "color": "f2f2ee"},
	"eye": {"hp": 12, "score": 170, "hx": 1.1, "hy": 0.6, "bomb": 0.0, "spits": true, "color": "ff9a2a"},
	"bulwark": {"hp": 38, "score": 380, "hx": 1.1, "hy": 1.1, "bomb": 1.0, "heavy": true, "crash": 8, "color": "f2f2ee"},
	"stalker": {"hp": 50, "score": 520, "hx": 1.0, "hy": 1.5, "bomb": 0.0, "walks": true, "pace": 1.1, "color": "1f3a34"},
	# Whoever is invading
	"saucer": {"hp": 12, "score": 240, "hx": 1.05, "hy": 0.5, "bomb": 0.0, "color": "c9cfd6"},
	"boss": {"hp": 110, "score": 2000, "hx": 2.7, "hy": 1.0, "bomb": 0.0, "color": "c9cfd6"},
}

var kind := "grunt"
var def: Dictionary
var mode := Mode.FORM
## Where it is on the play plane.
var pos := Vector2.ZERO
## Its place in the formation, relative to the formation's origin.
var slot := Vector2.ZERO
## The squad it marches with (a Swarm.Squad), while it is still in formation.
var squad: RefCounted
var hp := 1.0
var max_hp := 1.0
var hx := 0.4
var hy := 0.36
var dead := false
var color := Color.WHITE
## Kind-specific clock (spit cooldown, dive time, tractor-beam tick, boss attack cooldown).
var t := 0.0
var phase := 0.0
var speed := 0.0
var goal_pt := Vector2.ZERO
## The lean the puppet eases toward.
var tilt := 0.0
## Seconds before it flips face-on, and how far through the flip it is.
var flip_delay := 0.0
var flip := 0.0
## Saucers: the building being abducted (a City.Building) and the tractor beam.
var target_b: City.Building
var beam: MeshInstance3D
var line: MeshInstance3D

static var _line_mesh: QuadMesh
## Where the robot is along the table, for the aliens to look at.
static var watch_x := 0.0
## Boss: which attack is next, and the death ray's countdown (charging above RAY_FIRE, firing below).
var attack := 0
var ray_t := 0.0


func init(alien_kind: String, hp_scale: float) -> void:
	kind = alien_kind
	def = TYPES[kind]
	build("alien_" + kind)
	max_hp = ceilf(def.hp * hp_scale)
	hp = max_hp
	hx = def.hx
	hy = def.hy
	color = Color(def.color)
	rotation.y = PI * 0.5
	# Everything hangs from fishing line except the little ones that fall and the kaiju, which walk
	if not def.get("loose", false) and not def.get("walks", false):
		_add_line()
	if kind == "saucer":
		_add_beam()


func hurt(amount: float) -> bool:
	hp -= amount
	flash(1.0)
	return hp <= 0.0


func animate(delta: float) -> void:
	fade_flash(delta)
	if flip_delay > 0.0:
		flip_delay -= delta
	elif flip < 1.0:
		flip = minf(1.0, flip + delta * 3.5)
	rotation.y = (1.0 - flip) * PI * 0.5
	if mode == Mode.GROUND:
		# It turns to face the way it is stomping
		rotation.y = clampf(speed, -1.0, 1.0) * 1.15
	rotation.z = lerp_angle(rotation.z, tilt, 1.0 - exp(-14.0 * delta))
	position = Vector3(pos.x, pos.y, 0.0)
	# Limbs dangle and swing as it is jerked along its line
	stride(pos.x * 2.5 + phase, 0.28)
	twinkle(Time.get_ticks_msec() * 0.001 + phase)
	# Those with heads keep an eye on the robot below
	look(Vector3(clampf((watch_x - pos.x) * 0.12, -1.0, 1.0), -0.55, 0.7).normalized(), delta)


func _add_beam() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.5, 1.0, 0.6, 0.55))
	grad.set_color(1, Color(0.5, 1.0, 0.6, 0.05))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.9, 2.7)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	quad.material = m
	beam = MeshInstance3D.new()
	beam.mesh = quad
	beam.position = Vector3(0.0, -1.75, -0.02)
	beam.visible = false
	add_child(beam)


## The fishing line the puppet hangs from.
func _add_line() -> void:
	if _line_mesh == null:
		_line_mesh = QuadMesh.new()
		_line_mesh.size = Vector2(0.025, 30.0)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.85, 0.85, 0.8)
		_line_mesh.material = m
	line = MeshInstance3D.new()
	line.mesh = _line_mesh
	line.position = Vector3(0.0, 15.0 + hy * 0.8, 0.0)
	add_child(line)
