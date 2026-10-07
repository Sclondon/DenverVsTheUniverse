class_name Cutout
extends MeshInstance3D
## A flat cut-out standing on the table: one quad of art with an edge of bare material around it
## (shaders/cutout.gdshader). Buildings are plywood, figures are printed card.

const PPU := 128.0
## Clear margin, in pixels, that every piece of art leaves around itself for the edge.
const PAD := 10.0
const SHADER := preload("res://shaders/cutout.gdshader")
const PLYWOOD := Color("c79a5e")

static var _cache := {}

var mat: ShaderMaterial
var size := Vector2.ONE
var ppu := PPU
var _flash := 0.0
var _backing: ShaderMaterial


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


## Turns the piece into painted plywood: a wood edge, and a backing board a little behind it that
## shows as the sheet's thickness.
func add_backing() -> void:
	mat.set_shader_parameter("paper", PLYWOOD)
	# Painted boards hold their colour in shadow, so the lamps shade the city without blotting it out
	mat.set_shader_parameter("glow", 0.36)
	_backing = mat.duplicate()
	_backing.set_shader_parameter("solid", 1.0)
	_backing.set_shader_parameter("paper", PLYWOOD.darkened(0.25))
	var board := MeshInstance3D.new()
	board.mesh = mesh
	board.material_override = _backing
	board.position = Vector3(0.05, -0.02, -0.09)
	add_child(board)


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
	if _backing != null:
		_backing.set_shader_parameter("cut", cut)


func flash(amount := 1.0) -> void:
	_flash = amount
	mat.set_shader_parameter("flash", _flash)


func fade_flash(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 6.0)
		mat.set_shader_parameter("flash", _flash)
