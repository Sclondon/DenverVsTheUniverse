class_name Cutout
extends MeshInstance3D
## A flat cut-out standing on the table: one quad of art with an edge of bare material around it
## (shaders/cutout.gdshader). Buildings are plywood, figures are printed card.

const PPU := 128.0
## Clear margin, in pixels, that every piece of art leaves around itself for the edge.
const PAD := 10.0
const SHADER := preload("res://shaders/cutout.gdshader")
const PLYWOOD := Color("c79a5e")
const WOOD := preload("res://textures/plywood_color.jpg")
## How thick a plywood piece is, and how many layers that thickness is drawn with.
const THICK := 0.1
const LAYERS := 5

static var _cache := {}

var mat: ShaderMaterial
var size := Vector2.ONE
var ppu := PPU
var _flash := 0.0


## Art by file name: "robot" is art/robot.svg, "px/cash" is the pixel cut-out art/px/cash.png.
static func art(art_name: String) -> Texture2D:
	if not _cache.has(art_name):
		_cache[art_name] = load("res://art/%s.%s" % [art_name, "png" if art_name.begins_with("px/") else "svg"])
	return _cache[art_name]


static func make(art_name: String, pixels_per_unit := PPU, standing := false) -> Cutout:
	var c := Cutout.new()
	c.setup(art_name, pixels_per_unit, standing)
	return c


## `standing` puts the origin at the art's bottom edge instead of its centre.
func setup(art_name: String, pixels_per_unit := PPU, standing := false) -> void:
	var tex := art(art_name)
	var px := Vector2(tex.get_size())
	ppu = pixels_per_unit
	size = px / ppu
	var quad := QuadMesh.new()
	quad.size = size
	if standing:
		quad.center_offset = Vector3(0.0, size.y * 0.5 - PAD / ppu, 0.0)
	mesh = quad
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("tex", tex)
	mat.set_shader_parameter("texel", Vector2.ONE / px)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED


## Turns the piece into painted plywood: real wood grain on its edge, and the sheet's thickness as
## a stack of bare layers behind the painted face (all one mesh, so it is still one draw).
func add_backing() -> void:
	mat.set_shader_parameter("paper", PLYWOOD)
	mat.set_shader_parameter("wood", WOOD)
	mat.set_shader_parameter("wooden", 1.0)
	# Painted boards hold their colour in shadow, so the lamps shade the city without blotting it out
	mat.set_shader_parameter("glow", 0.3)
	var quad: QuadMesh = mesh
	var lo := Vector2(-size.x * 0.5, quad.center_offset.y - size.y * 0.5)
	var hi := lo + size
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var layers := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in LAYERS:
		var z := -THICK * i / (LAYERS - 1)
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			verts.append(Vector3(lerpf(lo.x, hi.x, corner.x), lerpf(hi.y, lo.y, corner.y), z))
			normals.append(Vector3.BACK)
			uvs.append(corner)
			layers.append(Vector2(0.0 if i == 0 else 1.0, float(i) / (LAYERS - 1)))
		indices.append_array([i * 4, i * 4 + 1, i * 4 + 2, i * 4, i * 4 + 2, i * 4 + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = layers
	arrays[Mesh.ARRAY_INDEX] = indices
	var board := ArrayMesh.new()
	board.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = board


## Height of the art itself, without the clear margin.
func content_height() -> float:
	return size.y - 2.0 * PAD / ppu


func set_tint(color: Color) -> void:
	mat.set_shader_parameter("tint", Color(color.r, color.g, color.b))


func set_border(pixels: float) -> void:
	mat.set_shader_parameter("border", pixels)


## Tears the top off, leaving `fraction` of the art's height standing.
func set_cut(fraction: float) -> void:
	var pad := PAD / ppu / size.y
	var cut := 1.0 if fraction >= 1.0 else pad + fraction * (1.0 - 2.0 * pad)
	mat.set_shader_parameter("cut", cut)


func flash(amount := 1.0) -> void:
	_flash = amount
	mat.set_shader_parameter("flash", _flash)


func fade_flash(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 6.0)
		mat.set_shader_parameter("flash", _flash)
