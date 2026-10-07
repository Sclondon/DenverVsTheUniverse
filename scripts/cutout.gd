class_name Cutout
extends MeshInstance3D
## A cut-out standing on the table: a flat sheet of art with a rim of bare paper, or (add_backing) a
## thin cardboard slab cut to the outline of its art (shaders/cutout.gdshader).

const PPU := 128.0
## Clear margin, in pixels, that every piece of art leaves around itself for the edge.
const PAD := 10.0
const SHADER := preload("res://shaders/cutout.gdshader")
const CARDBOARD := Color("c9a06a")
const PLYWOOD := CARDBOARD
## How thick a cardboard piece is.
const THICK := 0.07

static var _cache := {}
static var _boards := {}

var mat: ShaderMaterial
var size := Vector2.ONE
var ppu := PPU
var _flash := 0.0
var _art := ""
var _standing := false


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
	_art = art_name
	_standing = standing
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


## Turns the piece into cardboard: a real thin slab cut to the outline of its art, with the art on
## the face and bare board on the edge and back. Pieces with the same art share one mesh.
func add_backing() -> void:
	mat.set_shader_parameter("paper", CARDBOARD)
	mat.set_shader_parameter("card", 1.0)
	# Painted card holds its colour in shadow, so the lamps shade the city without blotting it out
	mat.set_shader_parameter("glow", 0.3)
	var key := "%s|%s|%s" % [_art, ppu, _standing]
	if not _boards.has(key):
		_boards[key] = _cut_board()
	mesh = _boards[key]


## The slab for this art: its outline traced from the picture, filled in front and behind and
## walled round the edge.
func _cut_board() -> ArrayMesh:
	var img := art(_art).get_image()
	if img.is_compressed():
		img.decompress()
	var bits := BitMap.new()
	bits.create_from_image_alpha(img, 0.5)
	var px := Vector2(img.get_size())
	# Where the top row of the picture is, in the piece's own space
	var top := size.y - PAD / ppu if _standing else size.y * 0.5
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var sides := PackedVector2Array()
	var indices := PackedInt32Array()
	for poly: PackedVector2Array in bits.opaque_to_polygons(Rect2i(Vector2i.ZERO, img.get_size()), 1.5):
		var tris := Geometry2D.triangulate_polygon(poly)
		if tris.is_empty():
			continue
		var at := func(p: Vector2, depth: float) -> Vector3:
			return Vector3((p.x / px.x - 0.5) * size.x, top - p.y / px.y * size.y, -depth)
		# The face (UV2 0) and the back (UV2 1)
		for layer in 2:
			var base := verts.size()
			for p in poly:
				verts.append(at.call(p, THICK * layer))
				normals.append(Vector3.BACK if layer == 0 else Vector3.FORWARD)
				uvs.append(p / px)
				sides.append(Vector2(layer, layer))
			for i in tris:
				indices.append(base + i)
		# The cut edge, one strip per side of the outline
		var outward := -1.0 if Geometry2D.is_polygon_clockwise(poly) else 1.0
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			var normal := Vector3(b.y - a.y, b.x - a.x, 0.0).normalized() * outward
			var base := verts.size()
			for corner: Array in [[a, 0.0], [b, 0.0], [b, THICK], [a, THICK]]:
				verts.append(at.call(corner[0], corner[1]))
				normals.append(normal)
				uvs.append(corner[0] / px)
				sides.append(Vector2(1.0, 1.0))
			indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = sides
	arrays[Mesh.ARRAY_INDEX] = indices
	var board := ArrayMesh.new()
	board.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return board


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


func flashing() -> bool:
	return _flash > 0.0


func fade_flash(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 6.0)
		mat.set_shader_parameter("flash", _flash)
