class_name Figure
extends Node3D
## A plastic action figure: the robot and every alien are one of these. The models are built in
## Blender by tools/blender/figures.py and live in models/ as .glb files. They are real 3D models
## standing among the flat plywood scenery, shiny under the lamps.

## Joint pivots by name ("arm_l", "leg_r", and "knee_l", "elbow_r" on models that have them).
var limbs := {}
## The model itself, under this node: turn it to tumble the figure about its middle.
var body: Node3D

## Each figure's own copy of the model's materials, so one can flash or change colour by itself:
## the copy, and the colours it was made with.
var _mats: Array[StandardMaterial3D] = []
var _made: Array[Dictionary] = []
var _flash := 0.0
## The head's own pose, and which way it is turned from it (yaw, pitch).
var _head_rest := Basis.IDENTITY
var _head_found := false
var _look := Vector2.ZERO


## Loads models/<model>.glb as this figure's body.
func build(model: String) -> void:
	var scene: PackedScene = load("res://models/%s.glb" % model)
	var made: Node3D = scene.instantiate()
	add_child(made)
	body = made
	_adopt(made, {})


func flash(amount := 1.0) -> void:
	_flash = amount
	_light_up()


func fade_flash(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 6.0)
		_light_up()


## Recolours the whole figure, as if moulded in a different plastic.
func set_tint(color: Color) -> void:
	for i in _mats.size():
		var base: Color = _made[i].albedo
		_mats[i].albedo_color = Color(base.r * color.r, base.g * color.g, base.b * color.b, base.a)


## Turns the head (on models that have one) to look along `dir`, given in the body's own space with
## +z straight ahead. It can only turn so far.
func look(dir: Vector3, delta: float) -> void:
	var head: Node3D = limbs.get("head")
	if head == null:
		return
	if not _head_found:
		_head_found = true
		_head_rest = head.basis
	var want := Vector2(clampf(atan2(dir.x, maxf(dir.z, 0.05)), -1.1, 1.1), clampf(-asin(clampf(dir.y, -1.0, 1.0)) * 0.7, -0.7, 0.5))
	_look = _look.lerp(want, 1.0 - exp(-8.0 * delta))
	head.basis = Basis(Vector3.UP, _look.x) * Basis(Vector3.RIGHT, _look.y) * _head_rest


## Swings the arms and legs as if walking; `phase` is distance covered.
func stride(phase: float, amount := 0.5) -> void:
	for side: String in ["l", "r"]:
		var swing := sin(phase) * amount * (1.0 if side == "l" else -1.0)
		if limbs.has("leg_" + side):
			limbs["leg_" + side].rotation.x = swing
		if limbs.has("arm_" + side):
			limbs["arm_" + side].rotation.x = -swing * 0.6


## Makes the lamps on the figure (anything that glows) flicker out of step, like fairground bulbs.
func twinkle(time: float) -> void:
	if _flash > 0.0:
		return
	for i in _mats.size():
		if _made[i].glows:
			_mats[i].emission_energy_multiplier = float(_made[i].energy) * (0.45 + 0.75 * absf(sin(time * 5.0 + i * 1.9)))


func _adopt(node: Node, copies: Dictionary) -> void:
	if String(node.name).get_slice("_", 0) in ["arm", "leg", "knee", "elbow", "head"]:
		limbs[String(node.name)] = node
	var piece := node as MeshInstance3D
	if piece != null:
		for i in piece.mesh.get_surface_count():
			var src := piece.mesh.surface_get_material(i) as StandardMaterial3D
			if src == null:
				continue
			if not copies.has(src):
				var copy: StandardMaterial3D = src.duplicate()
				copy.metallic_specular = 0.6
				# The models carry soft contact shading painted into their vertex colours
				copy.vertex_color_use_as_albedo = true
				copies[src] = copy
				_mats.append(copy)
				_made.append({"albedo": copy.albedo_color, "glows": copy.emission_enabled, "emission": copy.emission, "energy": copy.emission_energy_multiplier})
			piece.set_surface_override_material(i, copies[src])
	for child in node.get_children():
		_adopt(child, copies)


func _light_up() -> void:
	for i in _mats.size():
		var m := _mats[i]
		var made := _made[i]
		var glows: bool = made.glows
		m.emission_enabled = glows or _flash > 0.0
		var own: Color = made.emission if glows else made.albedo
		m.emission = own.lerp(Color.WHITE, minf(_flash, 1.0))
		m.emission_energy_multiplier = (float(made.energy) if glows else 0.0) + _flash * 1.5
