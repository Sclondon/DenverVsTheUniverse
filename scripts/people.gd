class_name People
extends MultiMeshInstance3D
## The townsfolk: little peg people standing along the front of the table and in the parks, hopping on the spot.
## They watch the fight. A kill nearby makes them jump for joy; a hit on a building sends them
## running. They are scenery: nothing can hurt them.

const COUNT := 150
const COLOURS := ["ff3d7f", "4fe3ff", "ffd23f", "9be33a", "ff8a3a", "b78cff", "f6f3ea", "ff6b6b"]

## Where each one stands (x along the table, z back from the front street) and where it calls home.
var _spot: PackedVector2Array = []
var _home: PackedFloat32Array = []
var _pace: PackedFloat32Array = []
## How excited (1 falling to 0) and how fast it is running (units a second, falling to 0).
var _joy: PackedFloat32Array = []
var _run: PackedFloat32Array = []
var _time := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 303
	# One peg: a tapered body with a ball for a head
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := CylinderMesh.new()
	body.top_radius = 0.055
	body.bottom_radius = 0.085
	body.height = 0.24
	body.radial_segments = 8
	body.rings = 1
	st.append_from(body, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.12, 0.0)))
	var head := SphereMesh.new()
	head.radius = 0.075
	head.height = 0.15
	head.radial_segments = 8
	head.rings = 4
	st.append_from(head, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.3, 0.0)))
	var plastic := StandardMaterial3D.new()
	plastic.vertex_color_use_as_albedo = true
	plastic.roughness = 0.4
	var peg := st.commit()
	peg.surface_set_material(0, plastic)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = peg
	multimesh.instance_count = COUNT
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in COUNT:
		# Most stand along the front edge of the table like an audience; the rest are out in the parks
		var x := rng.randf_range(-Roads.SIDE + 5.0, Roads.SIDE - 5.0)
		var z := rng.randf_range(15.0, 16.0)
		if i % 3 == 0:
			x = Roads.CUTS[i % 2] + rng.randf_range(-8.0, 8.0)
			z = rng.randf_range(-4.0, 12.0)
			if absf(z) < 1.4:
				z = 2.0
			if absf(x - Roads.CUTS[i % 2]) < 1.5:
				x += 3.0
		_spot.append(Vector2(x, z))
		_home.append(x)
		_pace.append(rng.randf_range(4.0, 7.0))
		_joy.append(0.0)
		_run.append(0.0)
		multimesh.set_instance_color(i, Color(COLOURS[rng.randi() % COLOURS.size()]))
	update(0.0)


func update(delta: float) -> void:
	_time += delta
	for i in COUNT:
		_joy[i] = maxf(0.0, _joy[i] - delta * 0.6)
		if _run[i] != 0.0:
			_spot[i].x = clampf(_spot[i].x + _run[i] * delta, -Roads.SIDE + 2.0, Roads.SIDE - 2.0)
			_run[i] = move_toward(_run[i], 0.0, delta * 2.2)
		elif absf(_spot[i].x - _home[i]) > 0.1:
			# Wander back once the fright has passed
			_spot[i].x = move_toward(_spot[i].x, _home[i], delta * 0.8)
		var hop := absf(sin(_time * _pace[i] * (1.0 + _joy[i]) + i)) * (0.05 + 0.4 * _joy[i] + 0.1 * minf(absf(_run[i]), 1.0))
		var lean := Basis(Vector3.BACK, -_run[i] * 0.12)
		multimesh.set_instance_transform(i, Transform3D(lean.scaled(Vector3.ONE * 1.5), Vector3(_spot[i].x, hop, _spot[i].y)))


## Everyone within `reach` of x jumps for joy.
func cheer(x: float, reach := 16.0) -> void:
	for i in COUNT:
		if absf(_spot[i].x - x) < reach:
			_joy[i] = 1.0


## Everyone within `reach` of x runs from it.
func scare(x: float, reach := 7.0) -> void:
	for i in COUNT:
		if absf(_spot[i].x - x) < reach:
			_run[i] = (1.0 if _spot[i].x >= x else -1.0) * 4.0
