class_name Diorama
extends Node3D
## The set: a big table in a dark room under three hanging lamps, with the painted sky board and
## the mountain cut-outs along its back edge, and the camera that follows the robot along it.

const FOV := 30.0
## The play box the camera must always show, in world units (the fight happens on the z = 0 plane).
const BOX_W := 17.6
const BOX_H := 15.2
const BOTTOM := -1.3
const PITCH := 0.1
## The table's three districts, left to right: Cherry Creek, downtown, RiNo.
const DISTRICTS := [-15.8, 0.0, 15.8]

var font: Font
var camera: Camera3D
## Height the aliens start from: just under the score bar, so a tall window gets a taller sky to fight in.
var play_top := 12.4
## Half the width of the play plane the camera can see right now.
var view_half := 13.0

var _cam_x := 0.0
var _shake := 0.0
var _clouds: Array[Cutout] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 5
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.01, 0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.75)
	env.ambient_light_energy = 0.34
	world.environment = env
	add_child(world)
	for i in DISTRICTS.size():
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(DISTRICTS[i], 30.0, 20.0)
		lamp.spot_range = 90.0
		lamp.spot_angle = 19.0
		lamp.spot_angle_attenuation = 0.6
		lamp.spot_attenuation = 0.0
		lamp.light_energy = 0.85
		lamp.light_color = Color(1.0, 0.95, 0.86)
		lamp.shadow_enabled = true
		lamp.shadow_bias = 0.6
		lamp.shadow_normal_bias = 2.5
		lamp.shadow_blur = 1.5
		add_child(lamp)
		lamp.look_at(Vector3(DISTRICTS[i], 3.0, -5.0))

	var sky := MeshInstance3D.new()
	var sky_quad := QuadMesh.new()
	sky_quad.size = Vector2(130.0, 25.0)
	sky.mesh = sky_quad
	sky.material_override = _shader("res://shaders/sky.gdshader")
	sky.position = Vector3(0.0, 12.5, -17.0)
	add_child(sky)

	var table := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(140.0, 1.4, 38.0)
	table.mesh = box
	table.material_override = _shader("res://shaders/ground.gdshader")
	table.position = Vector3(0.0, -0.7, -3.0)
	add_child(table)

	_ridge("m_far", -15.0, 9.0)
	_ridge("m_mid", -13.0, 5.2)
	_ridge("m_near", -11.0, 3.4)

	var moon := Cutout.make("moon")
	moon.position = Vector3(-6.4, 12.4, -16.0)
	moon.scale = Vector3.ONE * 1.5
	_hang(moon)
	add_child(moon)
	for c: Array in [[5.0, 11.2, -14.0, 1.5], [-13.0, 9.6, -12.5, 1.1], [14.5, 9.2, -12.0, 0.9], [-24.0, 11.0, -14.0, 1.3], [26.0, 10.6, -13.5, 1.2]]:
		var cloud := Cutout.make("cloud")
		cloud.position = Vector3(c[0], c[1], c[2])
		cloud.scale = Vector3.ONE * c[3]
		cloud.set_tint(Color(0.95, 0.8, 0.9))
		_hang(cloud)
		add_child(cloud)
		_clouds.append(cloud)

	for p: Array in [[-23.4, 2.6, 1.3], [-24.6, -1.4, 1.0], [23.4, 2.4, 1.2], [24.8, -2.6, 0.9], [-23.6, -5.5, 1.4], [23.8, -5.2, 1.3],
			[-9.2, 3.4, 0.8], [9.4, 3.3, 0.8], [-16.0, 3.6, 0.9], [17.0, 3.5, 0.9]]:
		var pine := Cutout.make("pine", Cutout.PPU, true)
		pine.position = Vector3(p[0], 0.0, p[1])
		pine.scale = Vector3.ONE * p[2]
		add_child(pine)

	# Hand-painted signs: the three neighbourhoods, and the roadside-attraction kind
	for s: Array in [[-15.8, 4.3, "CHERRY\nCREEK", 0.04], [-8.8, 4.3, "DOWN\nTOWN", -0.03], [15.8, 4.3, "RINO", 0.05],
			[-22.6, 1.0, "ALIEN\nXING", 0.06], [22.6, 1.0, "UFO\nPARKING", -0.05]]:
		var board := Cutout.make("sign", Cutout.PPU * 1.15, true)
		board.position = Vector3(s[0], 0.0, s[1])
		board.rotation.z = s[3]
		add_child(board)
		var words := Label3D.new()
		words.text = s[2]
		words.font = font
		words.font_size = 30
		words.pixel_size = 0.008
		words.line_spacing = -9.0
		words.outline_size = 0
		words.shaded = true
		words.modulate = Color("1f7a2e")
		words.position = Vector3(0.0, 0.86, 0.01)
		board.add_child(words)

	camera = Camera3D.new()
	camera.fov = FOV
	camera.far = 300.0
	add_child(camera)
	camera.make_current()
	update_camera(0.0, 0.0)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Fits the play box to the window and tracks along the table after the robot.
func update_camera(delta: float, focus_x: float) -> void:
	var view := get_viewport().get_visible_rect().size
	var aspect := view.x / maxf(view.y, 1.0)
	var t := tan(deg_to_rad(FOV) * 0.5)
	var dist := maxf(BOX_H * 0.5 / t, BOX_W * 0.5 / (t * aspect))
	var seen := 2.0 * dist * t
	view_half = seen * aspect * 0.5
	# Spare height (a tall phone) mostly becomes sky, with a little more of the table below.
	var centre := BOTTOM - (seen - BOX_H) * 0.2 + seen * 0.5
	play_top = minf(centre + seen * 0.5 - 1.5, 22.0)
	var limit := maxf(0.0, City.HALF + 1.5 - view_half)
	_cam_x = lerpf(_cam_x, clampf(focus_x, -limit, limit), 1.0 - exp(-4.0 * delta)) if delta > 0.0 else clampf(focus_x, -limit, limit)
	_shake = maxf(0.0, _shake - delta * 1.6)
	var jolt := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), 0.0) * _shake * _shake
	var target := Vector3(_cam_x, centre, 0.0)
	camera.position = target + Vector3(0.0, sin(PITCH) * dist, cos(PITCH) * dist) + jolt
	camera.look_at(target + jolt)
	for cloud in _clouds:
		cloud.position.x += delta * 0.25 * cloud.scale.x
		if cloud.position.x > 40.0:
			cloud.position.x = -40.0


func _shader(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	return m


func _ridge(art_name: String, z: float, height: float) -> void:
	var ridge := Cutout.make(art_name, 2048.0 / 100.0, true)
	ridge.scale.y = height / ridge.size.y
	ridge.position = Vector3(0.0, -0.1, z)
	ridge.set_border(1.0)
	ridge.set_tint(Color(0.62, 0.62, 0.72))
	ridge.mat.set_shader_parameter("paper", Cutout.PLYWOOD)
	add_child(ridge)


## The string a sky cut-out dangles from.
func _hang(piece: Cutout) -> void:
	var line := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.03, 30.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.7, 0.68, 0.62)
	quad.material = m
	line.mesh = quad
	line.position = Vector3(0.0, 15.0 + piece.size.y * 0.3, -0.01)
	piece.add_child(line)
