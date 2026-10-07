class_name City
extends Node3D
## Denver in painted plywood, strung along the table: downtown in the middle, Cherry Creek to the
## left, RiNo to the right, low-rise filler between and a row of rooftops in front of the street.
## The art is pixel cut-outs of the real buildings (tools/cut_buildings.gd makes art/px/).
## Buildings crumble from the roof down as they take hits.

## What is left standing of a wrecked building, as a fraction of its height.
const RUBBLE := 0.1
const PPU := 100.0
## Half the length of the built-up strip. The robot and the aliens stay within it.
const HALF := 22.0
## Denver has fallen once less than this much of its total health is left.
const LOSS := 0.5

const NAMES := {
	"cash": "Cash Register", "republic": "Republic Plaza", "c1801": "1801 California", "qwest": "Qwest Tower",
	"capitol": "State Capitol", "union": "Union Station", "df": "D&F Tower", "bear": "Convention Center",
}
const ART := {
	"tall": ["cash", "republic", "c1801"],
	"mid": ["qwest", "orange", "gold_a", "gold_b", "mid_a", "mid_b", "mid_c", "ribbed", "dark"],
	"low": ["pink_low", "low_wide", "low_a", "low_b", "low_c", "low_d"],
}
## The landmarks stand where you'd look for them: art, x, z.
const LANDMARKS := [
	["df", -6.9, -2.5], ["cash", -4.6, -2.5], ["republic", -1.3, -2.5], ["c1801", 2.4, -2.5], ["qwest", 5.4, -2.5],
	["union", -5.4, -1.2], ["capitol", 0.0, -1.2], ["bear", 5.4, -1.2],
]
## Rows of filler, back to front: from x, to x, z, heights to draw from, widest gap, tint.
const ROWS := [
	# Downtown
	[-7.8, 7.8, -4.4, ["mid", "mid", "tall"], 0.1, "c6c6e6"],
	[-7.6, 7.6, -3.4, ["mid"], 0.3, "e6e6f2"],
	[-7.8, 7.8, -1.8, ["low"], 0.5, "ffffff"],
	# Cherry Creek: tidy mid-rises
	[-21.4, -10.6, -4.0, ["mid"], 0.5, "c6cee6"],
	[-21.0, -10.8, -2.8, ["mid", "low"], 0.6, "e6eeff"],
	[-21.4, -10.6, -1.5, ["low"], 0.5, "f2f6ff"],
	# RiNo: low brick and warehouses
	[10.6, 21.4, -4.0, ["low", "mid"], 0.6, "e6c0b0"],
	[10.8, 21.0, -2.8, ["low"], 0.5, "ffd2c0"],
	[10.6, 21.4, -1.5, ["low"], 0.7, "ffdccc"],
	# The stretches between
	[-10.3, -8.1, -3.2, ["low"], 0.4, "d8d8e6"],
	[-10.3, -8.1, -1.6, ["low"], 0.8, "ffffff"],
	[8.1, 10.3, -3.2, ["low"], 0.4, "d8d8e6"],
	[8.1, 10.3, -1.6, ["low"], 0.8, "ffffff"],
	# Rooftops this side of the street, in front of the robot
	[-21.5, 21.5, 1.9, ["low"], 3.2, "ffffff"],
]


class Building:
	var id: String
	var title: String
	var node: Cutout
	var x: float
	var z: float
	var half_w: float
	var height: float
	var hp: int
	var max_hp: int
	## What the art shows, eased toward hp / max_hp so damage visibly crumbles.
	var shown := 1.0

	func alive() -> bool:
		return hp > 0

	func fraction() -> float:
		return maxf(float(hp) / max_hp, City.RUBBLE)

	func top() -> float:
		return height * fraction()

	func roof() -> Vector3:
		return Vector3(x, top(), z)


var buildings: Array[Building] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5280
	for row: Array in ROWS:
		var x: float = row[0]
		while x < row[1]:
			var kinds: Array = ART[row[3][rng.randi() % row[3].size()]]
			var b := _add(kinds[rng.randi() % kinds.size()], 0.0, row[2] + rng.randf_range(-0.12, 0.12), "", rng.randf() < 0.5)
			b.x = x + b.half_w
			b.node.position.x = b.x
			b.node.set_tint(Color(row[5]))
			x += b.half_w * 2.0 + rng.randf_range(0.0, row[4])
	for mark: Array in LANDMARKS:
		_add(mark[0], mark[1], mark[2], mark[0], false)


func _add(art_name: String, x: float, z: float, id: String, mirrored: bool) -> Building:
	var b := Building.new()
	b.id = id
	b.title = NAMES.get(id, "")
	b.x = x
	b.z = z
	b.node = Cutout.make("px/" + art_name, PPU, true)
	b.node.mat.set_shader_parameter("chunk", 5.0)
	b.node.add_backing()
	b.node.position = Vector3(x, 0.0, z)
	if mirrored:
		b.node.scale.x = -1.0
	b.half_w = b.node.size.x * 0.5 - Cutout.PAD / PPU
	b.height = b.node.content_height()
	b.max_hp = clampi(roundi(b.height * 1.4), 2, 8)
	b.hp = b.max_hp
	add_child(b.node)
	buildings.append(b)
	return b


func _process(delta: float) -> void:
	for b in buildings:
		var want := b.fraction() if b.hp < b.max_hp else 1.0
		if not is_equal_approx(b.shown, want):
			b.shown = move_toward(b.shown, want, delta * 0.9)
			b.node.set_cut(b.shown)
		b.node.fade_flash(delta)
		b.node.rotation.z = lerpf(b.node.rotation.z, 0.0, 1.0 - exp(-10.0 * delta))


func reset() -> void:
	for b in buildings:
		b.hp = b.max_hp


func standing() -> int:
	var n := 0
	for b in buildings:
		if b.alive():
			n += 1
	return n


## Health of the whole city, 0 to 1.
func health() -> float:
	var hp := 0
	var full := 0
	for b in buildings:
		hp += b.hp
		full += b.max_hp
	return float(hp) / full


func by_id(id: String) -> Building:
	for b in buildings:
		if b.id == id:
			return b
	return null


## The tallest standing building whose footprint is under x: the one a falling bomb meets first.
func column_at(x: float) -> Building:
	var found: Building = null
	for b in buildings:
		if b.alive() and absf(x - b.x) < b.half_w and (found == null or b.top() > found.top()):
			found = b
	return found


## The standing building a falling thing at (x, y) has run into, if any.
func building_at(x: float, y: float) -> Building:
	var b := column_at(x)
	return b if b != null and y <= b.top() else null


func nearest_standing(x: float) -> Building:
	var found: Building = null
	for b in buildings:
		if b.alive() and (found == null or absf(b.x - x) < absf(found.x - x)):
			found = b
	return found


func random_standing(rng: RandomNumberGenerator) -> Building:
	var alive: Array[Building] = []
	for b in buildings:
		if b.alive():
			alive.append(b)
	return null if alive.is_empty() else alive[rng.randi() % alive.size()]


## Returns true if that blow brought the building down.
func damage(b: Building, amount: int) -> bool:
	if not b.alive():
		return false
	b.hp = maxi(0, b.hp - amount)
	b.node.flash(0.8)
	b.node.rotation.z = 0.05 if b.hp % 2 == 0 else -0.05
	return not b.alive()


## Gives `amount` points of repair to whichever standing buildings need it most. Returns what was used.
func repair(amount: int) -> int:
	var used := 0
	while used < amount:
		var worst: Building = null
		for b in buildings:
			if b.alive() and b.hp < b.max_hp and (worst == null or float(b.hp) / b.max_hp < float(worst.hp) / worst.max_hp):
				worst = b
		if worst == null:
			break
		worst.hp += 1
		used += 1
	return used


## Adds `amount` floors to every damaged building that is still standing.
func repair_each(amount: int) -> void:
	for b in buildings:
		if b.alive():
			b.hp = mini(b.max_hp, b.hp + amount)


## Raises one wrecked building back to half health. Returns it, or null if none was down.
func rebuild_one() -> Building:
	for b in buildings:
		if not b.alive():
			b.hp = ceili(b.max_hp * 0.5)
			return b
	return null


## True once so much is wrecked that the city counts as lost.
func fallen() -> bool:
	return health() < LOSS


## The city's health as the player sees it: 100 when whole, 0 when it falls.
func percent() -> int:
	return clampi(ceili((health() - LOSS) / (1.0 - LOSS) * 100.0), 0, 100)
