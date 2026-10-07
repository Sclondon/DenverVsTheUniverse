class_name Roads
extends RefCounted
## The streets the robot can run on, as seen from above (x along the table, z toward the back):
## a ring round the city (the front street, the two ends and the road behind the last row of
## buildings) and one shortcut straight through the middle of downtown.

## Where the end roads and the back road are.
const SIDE := City.HALF - 0.5
const BACK := -16.3
const CORNERS := [
	Vector2(-SIDE, 0.0), Vector2(0.0, 0.0), Vector2(SIDE, 0.0),
	Vector2(-SIDE, BACK), Vector2(0.0, BACK), Vector2(SIDE, BACK),
]
## Each street joins two corners.
const STREETS := [[0, 1], [1, 2], [3, 4], [4, 5], [0, 3], [1, 4], [2, 5]]
const NEAR := 0.05


## The nearest point on any street to `p`.
static func snap(p: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_d := INF
	for street: Array in STREETS:
		var q := Geometry2D.get_closest_point_to_segment(p, CORNERS[street[0]], CORNERS[street[1]])
		var d := q.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = q
	return best


## Where to head next to get from `from` to `to` by the shortest way along the streets (both must
## already be on a street). It is `to` itself when they share a street, or the corner to turn at.
static func route(from: Vector2, to: Vector2) -> Vector2:
	if from.distance_to(to) < NEAR:
		return to
	# A little graph: the six corners, plus where we are (6) and where we are going (7)
	var points: Array[Vector2] = []
	points.assign(CORNERS)
	points.append(from)
	points.append(to)
	var links: Array = []
	for i in 8:
		links.append([])
	for street: Array in STREETS:
		links[street[0]].append(street[1])
		links[street[1]].append(street[0])
		var a: Vector2 = CORNERS[street[0]]
		var b: Vector2 = CORNERS[street[1]]
		var from_on := Geometry2D.get_closest_point_to_segment(from, a, b).distance_to(from) < NEAR
		var to_on := Geometry2D.get_closest_point_to_segment(to, a, b).distance_to(to) < NEAR
		if from_on and to_on:
			return to
		if from_on:
			links[6].append(street[0])
			links[6].append(street[1])
		if to_on:
			links[street[0]].append(7)
			links[street[1]].append(7)
	# Shortest way from 6 to 7, remembering the first step taken
	var cost: Array[float] = []
	var first: Array[int] = []
	var done: Array[bool] = []
	for i in 8:
		cost.append(INF)
		first.append(-1)
		done.append(false)
	cost[6] = 0.0
	for pass_n in 8:
		var at := -1
		for i in 8:
			if not done[i] and (at == -1 or cost[i] < cost[at]):
				at = i
		if at == -1 or cost[at] == INF:
			break
		if at == 7:
			break
		done[at] = true
		for next: int in links[at]:
			var c := cost[at] + points[at].distance_to(points[next])
			if c < cost[next]:
				cost[next] = c
				first[next] = next if at == 6 else first[at]
	return points[first[7]] if first[7] != -1 else from
