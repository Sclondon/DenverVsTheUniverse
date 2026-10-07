class_name Upgrades
## The roguelike part: what can turn up on the three cards between waves.
## kind: "defense" builds something in the city, "tank" improves the player, "city" is a one-off.
## desc has one line per level, shown when that level is on offer.

const LIST := [
	{"id": "flak", "name": "Rooftop Flak", "kind": "defense", "max": 4, "icon": "turret", "desc": [
		"An auto-cannon on a downtown rooftop that shoots the nearest alien.",
		"A second rooftop gun.", "A third rooftop gun.", "A fourth rooftop gun."]},
	{"id": "blucifer", "name": "Blucifer", "kind": "defense", "max": 3, "icon": "blucifer", "desc": [
		"The airport's demon mustang stands guard. Its eyes burn a laser through every alien in line.",
		"Fires sooner and burns hotter.", "Fires almost constantly. Do not look it in the eye."]},
	{"id": "dome", "name": "Mile High Dome", "kind": "defense", "max": 3, "icon": "i_dome", "desc": [
		"An energy dome over downtown soaks up 4 bombs every wave.",
		"The dome soaks up 8 bombs every wave.", "The dome soaks up 12 bombs every wave."]},
	{"id": "battery", "name": "Front Range Battery", "kind": "defense", "max": 3, "icon": "missile", "desc": [
		"A launcher in the foothills fires homing missiles that explode on impact.",
		"Reloads faster, bigger blast.", "Reloads faster still, and fires in pairs."]},
	{"id": "tesla", "name": "Tesla Spire", "kind": "defense", "max": 3, "icon": "tesla", "desc": [
		"A coil on Republic Plaza zaps an alien and arcs to 2 more.",
		"Arcs through 5 aliens and hits harder.", "Arcs through 8 aliens, twice as often."]},
	{"id": "hail", "name": "Hail Storm", "kind": "defense", "max": 3, "icon": "cloud", "desc": [
		"Classic Colorado weather: every so often golf-ball hail pelts every alien in the sky.",
		"Storms roll in more often.", "Constant storms, baseball-sized hail."]},
	{"id": "bear", "name": "Big Blue Bear Crew", "kind": "defense", "max": 3, "icon": "b_bear", "desc": [
		"After every wave the Big Blue Bear patches up 2 floors of your most battered buildings.",
		"Patches up 4 floors after every wave.", "Patches up 7 floors after every wave."]},
	{"id": "cow", "name": "Decoy Cow", "kind": "defense", "max": 1, "icon": "cow", "desc": [
		"A plywood cow out on the plains. Saucers can't resist it and leave your buildings alone."]},
	{"id": "watchtower", "name": "UFO Watchtower", "kind": "defense", "max": 2, "icon": "watchtower", "desc": [
		"Spotters from the San Luis Valley call the shots: every city defense works 25% faster.",
		"More spotters, more coffee: every city defense works 50% faster."]},
	{"id": "mech", "name": "Strike Eagle Refit", "kind": "tank", "max": 2, "icon": "robot", "desc": [
		"Refit the robot as an F-15E Strike Eagle: +2 hearts, +1 damage, and an A.T. field that soaks up a hit every 12 seconds.",
		"The robot awakens: another heart, +1 damage, 30% faster fire, and the A.T. field recharges in 7 seconds."]},
	{"id": "rockets", "name": "Shoulder Rockets", "kind": "tank", "max": 3, "icon": "missile", "desc": [
		"Every few seconds the robot looses a homing rocket at the toughest alien.",
		"Rockets reload faster.", "Rockets reload faster still."]},
	{"id": "drone", "name": "Wingman Drone", "kind": "tank", "max": 2, "icon": "drone", "desc": [
		"A drone flies at your shoulder and fires alongside you.", "A second drone on the other shoulder."]},
	{"id": "rapid", "name": "Rapid Fire", "kind": "tank", "max": 5, "icon": "i_rapid", "desc": [
		"The robot fires 25% faster.", "Faster again.", "Faster again.", "Faster again.", "As fast as it gets."]},
	{"id": "twin", "name": "Extra Barrel", "kind": "tank", "max": 3, "icon": "i_twin", "desc": [
		"A second barrel: two shots at once.", "A third barrel.", "A fourth barrel."]},
	{"id": "heavy", "name": "Heavy Rounds", "kind": "tank", "max": 4, "icon": "i_heavy", "desc": [
		"Every shot does +1 damage.", "Another +1 damage.", "Another +1 damage.", "Another +1 damage."]},
	{"id": "pierce", "name": "Piercing Rounds", "kind": "tank", "max": 3, "icon": "i_pierce", "desc": [
		"Shots punch through one alien and keep going.", "Shots punch through two aliens.", "Shots punch through three aliens."]},
	{"id": "chile", "name": "Green Chile Rounds", "kind": "tank", "max": 3, "icon": "i_chile", "desc": [
		"Shots burst on impact and scorch the aliens next door.", "A bigger, hotter burst.", "Christmas style: the biggest burst."]},
	{"id": "treads", "name": "Afterburners", "kind": "tank", "max": 3, "icon": "i_treads", "desc": [
		"The robot runs 20% faster.", "Faster again.", "Top speed."]},
	{"id": "radar", "name": "Targeting Radar", "kind": "tank", "max": 3, "icon": "i_pierce", "desc": [
		"The gun locks on to aliens from farther away.", "Farther again.", "It can pick them out right across the sky."]},
	{"id": "dash", "name": "Vector Dash", "kind": "tank", "max": 2, "icon": "i_treads", "desc": [
		"Unlocks the dash: flick sideways, press Shift or double-tap a direction. Nothing can hit the robot mid-dash.", "The dash is ready again twice as fast."]},
	{"id": "jump", "name": "Vertical Takeoff", "kind": "tank", "max": 2, "icon": "robot", "desc": [
		"Unlocks the jump: flick up, or press Up or W, to leap over what is coming.", "Leaps higher, and fires half again as fast in the air."]},
	{"id": "armor", "name": "Extra Armor", "kind": "tank", "max": 3, "icon": "heart", "desc": [
		"One more heart, and all hearts refilled.", "One more heart, and all hearts refilled.", "One more heart, and all hearts refilled."]},
	{"id": "repair", "name": "Emergency Repairs", "kind": "city", "max": 999, "icon": "i_wrench", "desc": [
		"Rebuild one wrecked landmark, add 3 floors to every damaged one, and mend a heart."]},
]

const KIND_LABELS := {"defense": "CITY DEFENSE", "tank": "ROBOT UPGRADE", "city": "CITY"}
const KIND_COLORS := {"defense": "2f6fe0", "tank": "d62839", "city": "2f8f5a"}


static func find(id: String) -> Dictionary:
	for u: Dictionary in LIST:
		if u.id == id:
			return u
	return {}


static func describe(u: Dictionary, level: int) -> String:
	var lines: Array = u.desc
	return lines[mini(level, lines.size() - 1)]


## Three different cards. There is always a city defense among them while any is left to buy,
## and Emergency Repairs turns up whenever the city needs it. The mech has to be earned: it is not
## offered before wave 3, and beating a mothership always puts it on the table.
static func roll(levels: Dictionary, rng: RandomNumberGenerator, needs_repair: bool, wave: int) -> Array:
	var defenses := []
	var others := []
	for u: Dictionary in LIST:
		if int(levels.get(u.id, 0)) >= int(u.max) or u.id == "repair" or (u.id == "mech" and (wave < 3 or wave % 5 == 0)):
			continue
		if u.kind == "defense":
			defenses.append(u)
		else:
			others.append(u)
	var picks := []
	if wave % 5 == 0 and int(levels.get("mech", 0)) < int(find("mech").max):
		picks.append(find("mech"))
	if needs_repair:
		picks.append(find("repair"))
	if not defenses.is_empty():
		picks.append(_take(defenses, rng))
	var rest := defenses + others
	while picks.size() < 3 and not rest.is_empty():
		picks.append(_take(rest, rng))
	if picks.size() < 3 and not needs_repair:
		picks.append(find("repair"))
	# Shuffle so the guaranteed cards aren't always in the same seats.
	for i in range(picks.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = picks[i]
		picks[i] = picks[j]
		picks[j] = tmp
	return picks


static func _take(from: Array, rng: RandomNumberGenerator) -> Dictionary:
	var i := rng.randi() % from.size()
	var u: Dictionary = from[i]
	from.remove_at(i)
	return u
