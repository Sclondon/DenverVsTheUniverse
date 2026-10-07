class_name Roads
extends RefCounted
## The streets the robot can run on, as seen from above (x along the table, z toward the back):
## a ring round the city with rounded corners (the front street, the two ends and the road behind
## the last row of buildings) and two shortcuts across it, one through each park.

## Where the end roads and the back road are, how tight the corners are, and where the shortcuts cross.
const SIDE := City.HALF - 0.5
const BACK := -16.3
const BEND := 4.5
const CUTS := [-37.7, 37.7]
const NEAR := 0.05

## Every point the streets pass through, and for each the points it joins to.
static var points: Array[Vector2] = []
static var links: Array = []


static func _static_init() -> void:
	# Round the ring: along the front, up the right end, back along the rear, down the left end
	var ring: Array[Vector2] = [Vector2(-SIDE + BEND, 0.0), Vector2(CUTS[0], 0.0), Vector2(CUTS[1], 0.0), Vector2(SIDE - BEND, 0.0)]
	_bend(ring, Vector2(SIDE - BEND, -BEND), 90.0)
	ring.append(Vector2(SIDE, BACK + BEND))
	_bend(ring, Vector2(SIDE - BEND, BACK + BEND), 0.0)
	ring.append_array([Vector2(CUTS[1], BACK), Vector2(CUTS[0], BACK), Vector2(-SIDE + BEND, BACK)])
	_bend(ring, Vector2(-SIDE + BEND, BACK + BEND), -90.0)
	ring.append(Vector2(-SIDE, -BEND))
	_bend(ring, Vector2(-SIDE + BEND, -BEND), -180.0)
	ring.pop_back()
	points = ring
	for i in points.size():
		links.append([(i + points.size() - 1) % points.size(), (i + 1) % points.size()])
	# The shortcuts join the front street to the back road
	for cut: float in CUTS:
		var front := points.find(Vector2(cut, 0.0))
		var rear := points.find(Vector2(cut, BACK))
		links[front].append(rear)
		links[rear].append(front)


## Adds a quarter turn about `centre`, starting at `from` degrees and turning toward the back.
static func _bend(ring: Array[Vector2], centre: Vector2, from: float) -> void:
	for i in range(1, 7):
		var a := deg_to_rad(from - 15.0 * i)
		ring.append(centre + Vector2(cos(a), sin(a)) * BEND)


## The nearest point on any street to `p`.
static func snap(p: Vector2) -> Vector2:
	return _nearest(p)[0]


## How far `p` is from the nearest street.
static func clearance(p: Vector2) -> float:
	return _nearest(p)[0].distance_to(p)


## [the nearest point on a street to p, and the two points that street runs between]
static func _nearest(p: Vector2) -> Array:
	var best := [Vector2.ZERO, 0, 0]
	var best_d := INF
	for a in points.size():
		for b: int in links[a]:
			if b < a:
				continue
			var q := Geometry2D.get_closest_point_to_segment(p, points[a], points[b])
			var d := q.distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = [q, a, b]
	return best


## Where to head next to get from `from` to `to` by the shortest way along the streets (both must
## already be on a street): `to` itself when they share a street, else the next corner.
static func route(from: Vector2, to: Vector2) -> Vector2:
	if from.distance_to(to) < NEAR:
		return to
	var here := _nearest(from)
	var there := _nearest(to)
	if Geometry2D.get_closest_point_to_segment(to, points[here[1]], points[here[2]]).distance_to(to) < NEAR:
		return to
	# Shortest way over the points, from the two ends of the street we are on
	var count := points.size()
	var cost: Array[float] = []
	var first: Array[int] = []
	var done: Array[bool] = []
	for i in count:
		cost.append(INF)
		first.append(-1)
		done.append(false)
	for end: int in [here[1], here[2]]:
		cost[end] = from.distance_to(points[end])
		# -2 marks a corner we are already standing on: the first step is whatever comes after it
		first[end] = -2 if cost[end] < NEAR else end
	var best_total := INF
	var best_first := -1
	for pass_n in count:
		var at := -1
		for i in count:
			if not done[i] and cost[i] < INF and (at == -1 or cost[i] < cost[at]):
				at = i
		if at == -1:
			break
		done[at] = true
		if at == there[1] or at == there[2]:
			var total := cost[at] + points[at].distance_to(to)
			if total < best_total:
				best_total = total
				best_first = first[at]
				if best_first == -2:
					best_first = -3
		for next: int in links[at]:
			var c := cost[at] + points[at].distance_to(points[next])
			if c < cost[next]:
				cost[next] = c
				first[next] = next if first[at] == -2 else first[at]
	if best_first == -3:
		return to
	return points[best_first] if best_first >= 0 else from


## The point `reach` further along the streets from `from`, setting off the way that best matches
## `dir` and then keeping straight on round the bends. Where a street forks, it takes the fork that
## points along `turn` if one clearly does. Returns `from` if no street leads that way.
static func ahead(from: Vector2, dir: Vector2, reach: float, turn := Vector2.ZERO) -> Vector2:
	var here := _nearest(from)
	var at := from
	var came := -1
	var next := -1
	var best := 0.25
	for end: int in [here[1], here[2]]:
		var to := points[end] - from
		if to.length() < NEAR:
			# Standing on a corner: any street out of it will do
			for other: int in links[end]:
				var out := (points[other] - points[end]).normalized().dot(dir)
				if out > best:
					best = out
					next = other
					came = end
			continue
		var d := to.normalized().dot(dir)
		if d > best:
			best = d
			next = end
			came = here[2] if end == here[1] else here[1]
	if next == -1:
		return from
	var going := (points[next] - at).normalized()
	while reach > 0.0:
		var step := points[next].distance_to(at)
		if step >= reach:
			return at + going * reach
		reach -= step
		at = points[next]
		# Straight on, unless a fork points where the player is pushing
		var onward := -1
		var straight := -2.0
		for other: int in links[next]:
			if other == came:
				continue
			var way := (points[other] - at).normalized()
			var score := way.dot(going)
			if turn != Vector2.ZERO and links[next].size() > 2 and way.dot(turn) > 0.7:
				score += 2.0
			if score > straight:
				straight = score
				onward = other
		if onward == -1:
			return at
		came = next
		next = onward
		going = (points[next] - at).normalized()
	return at


## Where a push of the joystick should take a robot standing at `from`: a few steps along whichever
## street runs the way pushed, choosing at each corner the street that best matches the push and
## stopping where the streets no longer lead that way. Near a fork whose side street runs the way
## pushed, it heads for that street. Returns `from` when nothing leads that way.
static func steer(from: Vector2, push: Vector2, reach := 3.0) -> Vector2:
	var here := _nearest(from)
	var at := from
	var came := -1
	var next := -1
	var best := 0.3
	for end: int in [here[1], here[2]]:
		var to := points[end] - from
		if to.length() < NEAR:
			for other: int in links[end]:
				var out := (points[other] - points[end]).normalized().dot(push)
				if out > best:
					best = out
					next = other
					came = end
			continue
		var d := to.normalized().dot(push)
		if d > best:
			best = d
			next = end
			came = here[2] if end == here[1] else here[1]
	if next == -1:
		# Nothing along this street: is there a side street close by that goes that way?
		for end: int in [here[1], here[2]]:
			if links[end].size() > 2 and points[end].distance_to(from) < 4.0:
				for other: int in links[end]:
					var side := (points[other] - points[end]).normalized()
					if side.dot(push) > 0.7:
						return points[end] + side * 2.0
		return from
	while reach > 0.0:
		var step := points[next].distance_to(at)
		if step >= reach:
			return at + (points[next] - at).normalized() * reach
		reach -= step
		at = points[next]
		var onward := -1
		var match_best := 0.3
		for other: int in links[next]:
			if other == came:
				continue
			var way := (points[other] - at).normalized().dot(push)
			if way > match_best:
				match_best = way
				onward = other
		if onward == -1:
			return at
		came = next
		next = onward
	return at
