class_name City
extends Node3D
## Denver in painted plywood, strung along the table. South to north: Cherry Creek, Wash Park,
## Capitol Hill, downtown, LoDo, City Park and RiNo (Diorama.DISTRICTS), low-rise filler between and
## a row of rooftops in front of the street.
## The art is pixel cut-outs of the real buildings (tools/cut_buildings.gd makes art/px/).
## Buildings crumble from the roof down as they take hits.

## What is left standing of a wrecked building, as a fraction of its height.
const RUBBLE := 0.1
const PPU := 100.0
## Half the length of the built-up strip. The robot and the aliens stay within it.
const HALF := 66.0
## Denver has fallen once less than this much of its total health is left.
const LOSS := 0.5

const NAMES := {
	"cash": "Cash Register", "republic": "Republic Plaza", "c1801": "1801 California", "qwest": "555 17th Street",
	"fourseasons": "Four Seasons", "b1144": "1144 Fifteenth", "b1999": "1999 Broadway", "b707": "707 17th Street",
	"capitol": "State Capitol", "union": "Union Station", "df": "D&F Tower", "bear": "Convention Center",
}
const ART := {
	"tall": ["gold_a", "gold_b", "mid_a", "mid_b", "mid_c", "ribbed", "dark"],
	"mid": ["qwest", "orange", "gold_a", "gold_b", "mid_a", "mid_b", "mid_c", "ribbed", "dark"],
	"low": ["pink_low", "low_wide", "low_a", "low_b", "low_c", "low_d"],
}
## How big each height of building is made: towers loom, the low-rise is small.
const SIZES := {"tall": 1.5, "mid": 1.0, "low": 0.62}
## The filler never stands taller than this, so the eight real towers are the skyline.
const MAX_HEIGHT := 4.9
## World units a foot of real building is built to: Republic Plaza (714 ft) comes out 8 units tall.
const FOOT := 8.0 / 714.0
## Half the width kept clear for the street that cuts through the middle of downtown.
const SHORTCUT := 0.85
## Denver's eight tallest buildings, at their true heights relative to each other (feet, from
## Wikipedia's list of tallest buildings in Denver) and in the left-to-right order of the skyline
## photograph in conceptart/. Four Seasons and 1144 Fifteenth were built after that photograph, so
## where they stand is a guess. Then the low landmarks along the street. id, art, x, z, feet (0 = as drawn).
const LANDMARKS := [
	["fourseasons", "fourseasons", -9.0, -3.3, 639.0],
	["cash", "cash", -6.5, -2.6, 698.0],
	["republic", "republic", -3.2, -3.4, 714.0],
	["b707", "orange", 2.7, -2.6, 522.0],
	["qwest", "qwest", 4.7, -3.5, 507.0],
	["b1144", "b1144", 6.4, -2.5, 602.0],
	["b1999", "b1999", 8.1, -3.5, 544.0],
	["c1801", "c1801", 10.6, -2.7, 709.0],
	["df", "df", -10.8, -1.9, 0.0],
	["union", "union", -6.0, -1.2, 0.0], ["capitol", "capitol", -2.8, -1.2, 0.0], ["bear", "bear", 5.4, -1.2, 0.0],
]
## Rows of filler, back to front: from x, to x, z, heights to draw from, widest gap, tint.
const ROWS := [
	# Downtown
	[-7.8, 7.8, -4.6, ["mid", "tall", "tall"], 0.1, "c6c6e6"],
	[-7.6, 7.6, -1.9, ["mid", "low"], 0.4, "f0f0fa"],
	[-7.8, 7.8, -1.8, ["low"], 0.5, "ffffff"],
	# Cherry Creek: tidy mid-rises
	[-63.8, -48.0, -4.0, ["mid"], 0.5, "c6cee6"],
	[-63.6, -48.2, -2.8, ["mid", "low"], 0.6, "e6eeff"],
	[-63.8, -48.0, -1.5, ["low"], 0.5, "f2f6ff"],
	# Capitol Hill: old apartment blocks
	[-27.6, -10.6, -4.0, ["mid", "low"], 0.5, "d8c8c0"],
	[-27.4, -10.8, -2.8, ["low", "mid", "low"], 0.6, "f0e0d6"],
	[-27.6, -10.6, -1.5, ["low"], 0.6, "fff0e6"],
	# LoDo: brick blocks by the ballpark
	[10.6, 27.6, -4.0, ["low", "mid"], 0.6, "e6c0b0"],
	[10.8, 27.4, -2.8, ["low"], 0.5, "ffd2c0"],
	[10.6, 27.6, -1.5, ["low"], 0.7, "ffdccc"],
	# RiNo: warehouses in loud paint
	[48.0, 63.8, -4.0, ["low", "mid", "low"], 0.7, "ffb0d8"],
	[48.2, 63.6, -2.8, ["low"], 0.6, "b0f0e0"],
	[48.0, 63.8, -1.5, ["low"], 0.8, "ffe6a0"],
	# The parks: just the houses along their far side
	[-46.6, -28.8, -14.4, ["low"], 0.9, "d8d8e6"],
	[28.8, 46.6, -14.4, ["low"], 0.9, "d8d8e6"],
	# The stretches either side of downtown
	[-10.3, -8.1, -3.2, ["low"], 0.4, "d8d8e6"],
	[-10.3, -8.1, -1.6, ["low"], 0.8, "ffffff"],
	[8.1, 10.3, -3.2, ["low"], 0.4, "d8d8e6"],
	[8.1, 10.3, -1.6, ["low"], 0.8, "ffffff"],
]
## The city is deep as well as long. Every built-up stretch (from x, to x) also gets these rows:
## z, heights to draw from, widest gap, tint. Behind the street they run back to the foothills,
## dimmer with distance; this side of it they run to the table edge, low so the robot stays in view.
const STRETCHES := [[-63.9, -48.0], [-27.6, 27.6], [48.0, 63.9]]
const DEPTH := [
	[-5.8, ["mid", "low", "tall"], 0.3, "c0c0de"],
	[-7.1, ["low", "mid"], 0.3, "b8b8d8"],
	[-8.5, ["low", "mid", "low"], 0.4, "b0b0d2"],
	[-10.0, ["low", "mid"], 0.4, "a8a8cc"],
	[-11.6, ["low"], 0.5, "a0a0c6"],
	[-13.3, ["low"], 0.5, "9898c0"],
	[-14.6, ["low"], 0.6, "9090ba"],
	[1.9, ["low"], 0.9, "ffffff"],
	[2.9, ["low"], 0.6, "f4f4ff"],
	[4.0, ["low"], 0.5, "ececfa"],
	[5.2, ["low"], 0.5, "e4e4f4"],
	[6.5, ["low"], 0.4, "dcdcee"],
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
	var busy := false

	func alive() -> bool:
		return hp > 0

	func fraction() -> float:
		return maxf(float(hp) / max_hp, City.RUBBLE)

	func top() -> float:
		return height * City.stands(fraction())

	func roof() -> Vector3:
		return Vector3(x, top(), z)


var buildings: Array[Building] = []

## Buildings that are crumbling, flashing or rocking right now: the only ones worked on each frame.
var _busy: Array[Building] = []
## Buildings by the one-unit stretch of table they stand over, so a falling bomb only looks at a few.
var _cells: Array = []
var _health := 1.0
var _stale := true


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5280
	var rows: Array = ROWS.duplicate()
	for stretch: Array in STRETCHES:
		for d: Array in DEPTH:
			rows.append([stretch[0], stretch[1], d[0], d[1], d[2], d[3]])
	for row: Array in rows:
		var x: float = row[0]
		while x < row[1]:
			var kind: String = row[3][rng.randi() % row[3].size()]
			var kinds: Array = ART[kind]
			var b := _add(kinds[rng.randi() % kinds.size()], 0.0, row[2] + rng.randf_range(-0.12, 0.12), "", rng.randf() < 0.5, SIZES[kind] * rng.randf_range(0.88, 1.12))
			b.x = x + b.half_w
			# Nothing is built on the shortcut through the middle of town
			if row[2] < 0.0 and absf(b.x) < b.half_w + SHORTCUT:
				buildings.pop_back()
				b.node.queue_free()
				x = SHORTCUT
				continue
			b.node.position.x = b.x
			b.node.set_tint(Color(row[5]))
			x += b.half_w * 2.0 + rng.randf_range(0.0, row[4])
	for mark: Array in LANDMARKS:
		_add(mark[1], mark[2], mark[3], mark[0], false, 1.0, mark[4] * FOOT)
	_cells.resize(int(HALF * 2.0) + 8)
	for i in _cells.size():
		_cells[i] = []
	for b in buildings:
		for cell in range(_cell(b.x - b.half_w), _cell(b.x + b.half_w) + 1):
			_cells[cell].append(b)


## `tall`, if given, is the height to build it to, whatever its art's own size.
func _add(art_name: String, x: float, z: float, id: String, mirrored: bool, size: float, tall := 0.0) -> Building:
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
		b.node.mat.set_shader_parameter("flip", 1.0)
	size = tall / b.node.content_height() if tall > 0.0 else minf(size, MAX_HEIGHT / b.node.content_height())
	b.node.scale = Vector3.ONE * size
	b.half_w = (b.node.size.x * 0.5 - Cutout.PAD / PPU) * size
	b.height = b.node.content_height() * size
	b.max_hp = clampi(roundi(b.height * 1.4), 2, 8)
	b.hp = b.max_hp
	add_child(b.node)
	buildings.append(b)
	return b


func _process(delta: float) -> void:
	var still: Array[Building] = []
	for b in _busy:
		var want := b.fraction() if b.hp < b.max_hp else 1.0
		if not is_equal_approx(b.shown, want):
			b.shown = move_toward(b.shown, want, delta * 0.9)
			b.node.set_cut(stands(b.shown))
			b.node.mat.set_shader_parameter("wear", 1.0 - b.shown)
		b.node.fade_flash(delta)
		b.node.rotation.z = lerpf(b.node.rotation.z, 0.0, 1.0 - exp(-10.0 * delta))
		if is_equal_approx(b.shown, want) and not b.node.flashing() and absf(b.node.rotation.z) < 0.002:
			b.node.rotation.z = 0.0
			b.busy = false
		else:
			still.append(b)
	_busy = still


## How much of its height a building at this health still stands to. Damage shows in stages: first
## soot and broken windows, then holes blown through it, and only below about half health does the
## roof start coming down, until it is a stump of rubble.
static func stands(health_left: float) -> float:
	return clampf(health_left / 0.55, RUBBLE, 1.0)


func _cell(x: float) -> int:
	return clampi(int(floor(x + HALF)) + 4, 0, int(HALF * 2.0) + 7)


## Call whenever a building's health changes: it needs redrawing and the city's health recounting.
func _changed(b: Building) -> void:
	_stale = true
	if not b.busy:
		b.busy = true
		_busy.append(b)


func reset() -> void:
	for b in buildings:
		if b.hp != b.max_hp:
			b.hp = b.max_hp
			_changed(b)


func standing() -> int:
	var n := 0
	for b in buildings:
		if b.alive():
			n += 1
	return n


## Health of the whole city, 0 to 1.
func health() -> float:
	if _stale:
		_stale = false
		var hp := 0
		var full := 0
		for b in buildings:
			hp += b.hp
			full += b.max_hp
		_health = float(hp) / full
	return _health


func by_id(id: String) -> Building:
	for b in buildings:
		if b.id == id:
			return b
	return null


## The tallest standing building whose footprint is under x: the one a falling bomb meets first.
func column_at(x: float) -> Building:
	var found: Building = null
	if absf(x) > HALF + 3.0:
		return null
	for b: Building in _cells[_cell(x)]:
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
	_changed(b)
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
		_changed(worst)
		used += 1
	return used


## Adds `amount` floors to every damaged building that is still standing.
func repair_each(amount: int) -> void:
	for b in buildings:
		if b.alive():
			if b.hp < b.max_hp:
				b.hp = mini(b.max_hp, b.hp + amount)
				_changed(b)


## Raises one wrecked building back to half health. Returns it, or null if none was down.
func rebuild_one() -> Building:
	for b in buildings:
		if not b.alive():
			b.hp = ceili(b.max_hp * 0.5)
			_changed(b)
			return b
	return null


## True once so much is wrecked that the city counts as lost.
func fallen() -> bool:
	return health() < LOSS


## The city's health as the player sees it: 100 when whole, 0 when it falls.
func percent() -> int:
	return clampi(ceili((health() - LOSS) / (1.0 - LOSS) * 100.0), 0, 100)
