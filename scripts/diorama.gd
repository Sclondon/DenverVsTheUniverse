class_name Diorama
extends Node3D
## The set: a long table in a dark room under a row of hanging lamps, with the painted sky board
## and the mountain cut-outs along its back edge, and the camera that follows the robot along it
## through a close-up lens. Real materials: plank table, scenic turf, resin lakes, model trees.

const FOV := 30.0
## The play box the camera must always show, in world units (the fight happens on the z = 0 plane).
const BOX_W := 17.6
const BOX_H := 15.2
const BOTTOM := -1.3
## The camera looks down on the table from above and a little to the right, like someone leaning over it.
const PITCH := 0.38
const YAW := 0.12
## The table's districts, south to north, with a lamp over each. PARKS are open ground; the
## aliens go for the others (TOWNS).
const DISTRICTS := [-56.6, -37.7, -18.9, 0.0, 18.9, 37.7, 56.6]
const NAMES := ["CHERRY\nCREEK", "WASH\nPARK", "CAP\nHILL", "DOWN\nTOWN", "LODO", "CITY\nPARK", "RINO"]
const PARKS := [1, 5]
const TOWNS := [-56.6, -18.9, 0.0, 18.9, 56.6]
## Only the lamps this close to the camera cast shadows.
const SHADOW_REACH := 28.0
## The railway embankment along the back wall: where it is and how high the train rides.
const TRACK_Z := -10.7
const TRACK_Y := 2.1
const TRAIN_SPEED := 2.6
## How far the camera turns to look the way the robot is running.
const SWIVEL := 0.11

var font: Font
var camera: Camera3D
## Height the aliens start from: just under the score bar, so a tall window gets a taller sky to fight in.
var play_top := 12.4
## Half the width of the play plane the camera can see right now.
var view_half := 13.0

var _cam_x := 0.0
var _shake := 0.0
var _clouds: Array[Cutout] = []
var _lamps: Array[SpotLight3D] = []
var _lens: ShaderMaterial
## The train: each car with how far behind the front of the engine it rides.
var _train: Array = []
var _train_x := -30.0
var _swivel := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 5
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.01, 0.018)
	# The dim room around the table: it is what the plastic and the resin lakes reflect
	var room := ProceduralSkyMaterial.new()
	room.sky_top_color = Color(0.5, 0.42, 0.34)
	room.sky_horizon_color = Color(0.16, 0.14, 0.2)
	room.ground_bottom_color = Color(0.03, 0.02, 0.02)
	room.ground_horizon_color = Color(0.16, 0.14, 0.2)
	room.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = room
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.75)
	env.ambient_light_energy = 0.3
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.6
	world.environment = env
	add_child(world)
	for x: float in DISTRICTS:
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(x, 30.0, 20.0)
		lamp.spot_range = 90.0
		lamp.spot_angle = 19.0
		lamp.spot_angle_attenuation = 0.6
		lamp.spot_attenuation = 0.0
		lamp.light_energy = 1.0
		lamp.light_color = Color(1.0, 0.93, 0.82)
		lamp.shadow_bias = 0.6
		lamp.shadow_normal_bias = 2.5
		lamp.shadow_blur = 1.5
		add_child(lamp)
		lamp.look_at(Vector3(x, 3.0, -5.0))
		_lamps.append(lamp)

	var board := MeshInstance3D.new()
	var board_quad := QuadMesh.new()
	board_quad.size = Vector2(250.0, 25.0)
	board.mesh = board_quad
	var paint := _shader("res://shaders/sky.gdshader")
	paint.set_shader_parameter("cells", Vector2(500.0, 50.0))
	board.material_override = paint
	board.position = Vector3(0.0, 12.5, -17.0)
	add_child(board)

	var table := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(250.0, 1.4, 38.0)
	table.mesh = box
	var ground := _shader("res://shaders/ground.gdshader")
	for tex: String in ["planks_c", "planks_n", "planks_r", "grass_c", "grass_n", "asphalt_c", "asphalt_n"]:
		var kind: String = {"c": "color", "n": "normal", "r": "rough"}[tex.get_slice("_", 1)]
		ground.set_shader_parameter(tex, load("res://textures/%s_%s.jpg" % [tex.get_slice("_", 0), kind]))
	ground.set_shader_parameter("mat_half", Vector2(City.HALF + 2.5, 0.0))
	ground.set_shader_parameter("parks", Vector2(DISTRICTS[PARKS[0]], DISTRICTS[PARKS[1]]))
	table.material_override = ground
	table.position = Vector3(0.0, -0.7, -3.0)
	add_child(table)

	# The range repeats along the back, mirrored each time so the joins match up
	for copy: int in [-1, 0, 1]:
		_ridge("m_far", -15.0, 9.0, copy)
		_ridge("m_mid", -13.0, 5.2, copy)
		_ridge("m_near", -11.0, 3.4, copy)

	var moon := Cutout.make("moon")
	moon.position = Vector3(-6.4, 12.4, -16.0)
	moon.scale = Vector3.ONE * 1.5
	_hang(moon)
	add_child(moon)
	for i in 14:
		var cloud := Cutout.make("cloud")
		cloud.position = Vector3(-78.0 + i * 12.0 + _rng.randf_range(-3.0, 3.0), _rng.randf_range(9.0, 11.4), _rng.randf_range(-14.0, -12.0))
		cloud.scale = Vector3.ONE * _rng.randf_range(0.9, 1.5)
		cloud.set_tint(Color(0.95, 0.8, 0.9))
		_hang(cloud)
		add_child(cloud)
		_clouds.append(cloud)

	for p: Array in [[-67.6, 2.6, 1.3], [-68.6, -1.4, 1.0], [67.4, 2.4, 1.2], [68.8, -2.6, 0.9], [-67.8, -5.5, 1.4], [67.8, -5.2, 1.3],
			[-9.2, 3.4, 0.8], [9.4, 3.3, 0.8], [-22.0, 3.6, 0.9], [23.0, 3.5, 0.9], [-52.0, 3.5, 0.9], [53.0, 3.6, 0.8]]:
		var pine := Cutout.make("pine", Cutout.PPU, true)
		pine.position = Vector3(p[0], 0.0, p[1])
		pine.scale = Vector3.ONE * p[2]
		add_child(pine)

	# The parks: plywood trees scattered round the lake, a few this side of the street
	for park: int in PARKS:
		for i in 34:
			var at := Vector3(_rng.randf_range(-9.0, 9.0), 0.0, _rng.randf_range(-9.0, -1.6) if i < 26 else _rng.randf_range(2.2, 6.4))
			# Not in the water
			if Vector2(at.x / 6.4, (at.z + 6.4) / 3.0).length() < 1.0:
				continue
			var tree := Cutout.make("px/tree_%s" % ["a", "b", "c" if i % 5 == 0 else "a"][_rng.randi() % 3], City.PPU, true)
			tree.mat.set_shader_parameter("chunk", 5.0)
			tree.add_backing()
			tree.position = at + Vector3(DISTRICTS[park], 0.0, 0.0)
			tree.scale = Vector3.ONE * _rng.randf_range(0.75, 1.2)
			add_child(tree)

	# The railway along the back wall: a gravel embankment and a freight train that never stops
	var bank := MeshInstance3D.new()
	var bank_box := BoxMesh.new()
	bank_box.size = Vector3(2.0 * City.HALF + 20.0, TRACK_Y, 0.9)
	bank.mesh = bank_box
	var gravel := StandardMaterial3D.new()
	gravel.albedo_texture = load("res://textures/asphalt_color.jpg")
	gravel.albedo_color = Color(0.75, 0.66, 0.56)
	gravel.uv1_triplanar = true
	gravel.uv1_scale = Vector3.ONE * 0.4
	gravel.roughness = 0.95
	bank.material_override = gravel
	bank.position = Vector3(0.0, TRACK_Y * 0.5, TRACK_Z)
	add_child(bank)
	var along := 0.0
	for art: String in ["train_loco", "train_car1", "train_car2", "train_car3", "train_car2", "train_car1", "train_car3"]:
		var car := Cutout.make("px/" + art, City.PPU, true)
		car.mat.set_shader_parameter("chunk", 5.0)
		car.add_backing()
		add_child(car)
		along -= car.size.x * 0.5 - Cutout.PAD / City.PPU
		_train.append([car, along])
		along -= car.size.x * 0.5 - Cutout.PAD / City.PPU + 0.06

	# Hand-painted signs: the neighbourhoods, and the roadside-attraction kind
	var signs: Array = [[-67.0, 1.0, "ALIEN\nXING", 0.06], [67.0, 1.0, "UFO\nPARKING", -0.05]]
	for i in DISTRICTS.size():
		signs.append([DISTRICTS[i] - (8.8 if i == 3 else 0.0), 7.0, NAMES[i], 0.05 if i % 2 == 0 else -0.04])
	for s: Array in signs:
		var post := Cutout.make("sign", Cutout.PPU * 1.15, true)
		post.position = Vector3(s[0], 0.0, s[1])
		post.rotation.z = s[3]
		add_child(post)
		var words := Label3D.new()
		words.text = s[2]
		words.font = font
		words.font_size = 30
		words.pixel_size = 0.008
		words.line_spacing = -9.0
		words.outline_size = 0
		words.shaded = true
		words.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		words.modulate = Color("1f7a2e")
		words.position = Vector3(0.0, 0.86, 0.01)
		post.add_child(words)

	camera = Camera3D.new()
	camera.fov = FOV
	camera.far = 300.0
	add_child(camera)
	camera.make_current()
	# The lens: one sheet across the whole view that blurs what is out of focus
	var lens := MeshInstance3D.new()
	lens.mesh = QuadMesh.new()
	_lens = _shader("res://shaders/focus.gdshader")
	_lens.render_priority = -100
	lens.material_override = _lens
	lens.extra_cull_margin = 16384.0
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(lens)
	lens.position.z = -1.0
	update_camera(0.0, 0.0)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Fits the play box to the window and tracks along the table after the robot.
func update_camera(delta: float, focus_x: float, heading := 0.0) -> void:
	var view := get_viewport().get_visible_rect().size
	var aspect := view.x / maxf(view.y, 1.0)
	var t := tan(deg_to_rad(FOV) * 0.5)
	var dist := maxf(BOX_H * 0.5 / t, BOX_W * 0.5 / (t * aspect))
	var seen := 2.0 * dist * t
	view_half = seen * aspect * 0.5
	_lens.set_shader_parameter("focus", dist)
	# Spare height (a tall phone) mostly becomes sky, with a little more of the table below.
	var centre := BOTTOM - (seen - BOX_H) * 0.2 + seen * 0.5
	play_top = minf(centre + seen * 0.5 - 1.5, 22.0)
	var limit := maxf(0.0, City.HALF + 1.5 - view_half)
	_cam_x = lerpf(_cam_x, clampf(focus_x, -limit, limit), 1.0 - exp(-4.0 * delta)) if delta > 0.0 else clampf(focus_x, -limit, limit)
	_shake = maxf(0.0, _shake - delta * 1.6)
	var jolt := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), 0.0) * _shake * _shake
	var target := Vector3(_cam_x, centre, 0.0)
	# The camera swings a little toward the way the robot is heading (`heading`, -1 to 1)
	_swivel = lerpf(_swivel, clampf(heading, -1.0, 1.0) * SWIVEL, 1.0 - exp(-2.5 * delta))
	camera.position = target + Vector3(sin(YAW - _swivel) * cos(PITCH), sin(PITCH), cos(YAW - _swivel) * cos(PITCH)) * dist + jolt
	camera.look_at(target + jolt + Vector3(_swivel * 14.0, 0.0, 0.0))
	_train_x += TRAIN_SPEED * delta
	if _train_x > City.HALF + 40.0:
		_train_x = -City.HALF - 12.0
	for car: Array in _train:
		car[0].position = Vector3(_train_x + car[1], TRACK_Y + absf(sin((_train_x + car[1]) * 6.0)) * 0.015, TRACK_Z)
	for lamp in _lamps:
		lamp.shadow_enabled = absf(lamp.position.x - _cam_x) < SHADOW_REACH
	for cloud in _clouds:
		cloud.position.x += delta * 0.25 * cloud.scale.x
		if cloud.position.x > 84.0:
			cloud.position.x = -84.0


func _shader(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	return m


func _ridge(art_name: String, z: float, height: float, copy: int) -> void:
	var ridge := Cutout.make(art_name, 2048.0 / 100.0, true)
	ridge.scale.y = height / ridge.size.y
	ridge.position = Vector3(copy * ridge.size.x, -0.1, z)
	if copy != 0:
		ridge.mat.set_shader_parameter("mirror", 1.0)
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
