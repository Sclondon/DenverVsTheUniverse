class_name Workshop
extends RefCounted
## What the workshop between waves sells. Everything is paid for in scrap, the alien wreckage the
## robots bring down.

## Over-the-counter repairs.
const SHOP := [
	{"id": "patch", "name": "PATCH UP THE TOWN", "cost": 40, "does": "mend standing buildings"},
	{"id": "heart", "name": "SPARE HEART", "cost": 30, "does": "mend one heart"},
	{"id": "rebuild", "name": "REBUILD A WINGMAN", "cost": 90, "does": "one wingman returns"},
]

## Alien tech, reverse-engineered: three lines of three, each needing the one above it. `gives` is
## the upgrade (Upgrades.LIST id) the robot gains a level of.
const TECH := [
	{"id": "ray", "line": 0, "name": "RAY OPTICS", "cost": 60, "gives": "heavy", "does": "+1 damage"},
	{"id": "plasma", "line": 0, "name": "PLASMA ROUNDS", "cost": 140, "gives": "pierce", "does": "darts pierce"},
	{"id": "core", "line": 0, "name": "MOTHERSHIP CORE", "cost": 260, "gives": "rapid", "does": "fire faster"},
	{"id": "lift", "line": 1, "name": "SAUCER LIFT", "cost": 60, "gives": "treads", "does": "run faster"},
	{"id": "boots", "line": 1, "name": "GRAVITY BOOTS", "cost": 140, "gives": "jump", "does": "jump higher"},
	{"id": "warp", "line": 1, "name": "WARP DASH", "cost": 260, "gives": "dash", "does": "dash sooner"},
	{"id": "alloy", "line": 2, "name": "ALIEN ALLOY", "cost": 60, "gives": "armor", "does": "+1 heart"},
	{"id": "field", "line": 2, "name": "FORCE FIELD", "cost": 140, "gives": "mech", "does": "refit + shield"},
	{"id": "hive", "line": 2, "name": "HIVE MIND", "cost": 260, "gives": "wingman", "does": "better wingmen"},
]


static func find(list: Array, id: String) -> Dictionary:
	for item: Dictionary in list:
		if item.id == id:
			return item
	return {}


## The tech that must be owned before `id` can be bought ("" if it is the first of its line).
static func needs(id: String) -> String:
	var before := ""
	for item: Dictionary in TECH:
		if item.id == id:
			return before
		before = item.id if item.line == find(TECH, id).line else before
	return ""
