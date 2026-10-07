extends SceneTree
## Cuts the real buildings out of the reference photos in conceptart/ and turns each into a chunky
## pixel-art cutout in art/px/. Re-run after changing SPECS:
## godot --headless --path . -s tools/cut_buildings.gd [-- --sheet=<png to review>]

## World units one chunky pixel covers, and how many texture pixels it is drawn with.
const PIXEL := 0.05
const BLOW_UP := 5
## Colours each building is painted with.
const COLOURS := 10
const PAD := 10
## World units per photo pixel (in the 2000-wide coordinates the outlines below are measured in).
const UNITS_PER_PX := 0.0145
const PHOTO := "res://conceptart/Denver-Skyline-Wallpaper-Mural.jpg"
const PHOTO_SCALE := 1.6

## Outlines in photo coordinates. Four numbers are a rectangle (left, top, right, bottom).
const SPECS := {
	"cash": [335, 722, 335, 402, 348, 378, 372, 364, 430, 362, 468, 424, 468, 722],
	"republic": [515, 370, 666, 722],
	"orange": [600, 565, 710, 772],
	"gold_a": [65, 642, 210, 790],
	"gold_b": [208, 612, 326, 768],
	"pink_low": [315, 722, 520, 820],
	"mid_a": [712, 790, 712, 655, 730, 655, 730, 606, 810, 606, 810, 632, 838, 632, 838, 790],
	"qwest": [997, 762, 997, 540, 1050, 527, 1132, 527, 1132, 762],
	"mid_b": [1132, 605, 1200, 800],
	"mid_c": [1213, 832, 1213, 695, 1235, 695, 1235, 627, 1335, 627, 1335, 700, 1315, 700, 1315, 832],
	"low_wide": [925, 745, 1115, 832],
	"ribbed": [1385, 583, 1500, 812],
	"c1801": [1540, 812, 1540, 515, 1583, 515, 1583, 483, 1668, 483, 1668, 370, 1797, 370, 1797, 812],
	"dark": [1830, 638, 1968, 816],
	"low_a": [1352, 785, 1482, 832],
	"low_b": [850, 720, 1000, 800],
	"low_c": [522, 765, 600, 822],
	"low_d": [640, 782, 780, 812],
}


## Hand-drawn landmarks that aren't in the photo get the same pixel treatment (art/b_<name>.svg).
const DRAWN := ["capitol", "union", "df", "bear"]
## The drawn landmarks' art is this many SVG pixels per world unit.
const DRAWN_PPU := 94.8


func _initialize() -> void:
	var sheet_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sheet="):
			sheet_path = arg.trim_prefix("--sheet=")
	var photo := Image.load_from_file(ProjectSettings.globalize_path(PHOTO))
	photo.convert(Image.FORMAT_RGBA8)
	var sheet := Image.create(2600, 760, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.2, 0.0, 0.3))
	var sheet_x := 10
	var made := {}
	for id: String in SPECS:
		made[id] = _cut(photo, SPECS[id])
	for id: String in DRAWN:
		var svg := Image.new()
		svg.load_svg_from_buffer(FileAccess.get_file_as_bytes("res://art/b_%s.svg" % id))
		svg = svg.get_region(Rect2i(PAD, PAD, svg.get_width() - PAD * 2, svg.get_height() - PAD * 2))
		var w := roundi(svg.get_width() / DRAWN_PPU / PIXEL)
		var h := roundi(svg.get_height() / DRAWN_PPU / PIXEL)
		made[id] = _finish(_shrink(svg, w, h), false)
	for id: String in made:
		var out: Image = made[id]
		out.save_png("res://art/px/%s.png" % id)
		if sheet_x + out.get_width() < sheet.get_width():
			sheet.blend_rect(out, Rect2i(Vector2i.ZERO, out.get_size()), Vector2i(sheet_x, 750 - out.get_height()))
			sheet_x += out.get_width() + 6
	if sheet_path != "":
		sheet.save_png(sheet_path)
	print("cut %d buildings" % made.size())
	quit()


func _cut(photo: Image, spec: Array) -> Image:
	var pts := PackedVector2Array()
	if spec.size() == 4:
		pts = PackedVector2Array([Vector2(spec[0], spec[1]), Vector2(spec[2], spec[1]), Vector2(spec[2], spec[3]), Vector2(spec[0], spec[3])])
	else:
		for i in range(0, spec.size(), 2):
			pts.append(Vector2(spec[i], spec[i + 1]))
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	var size := hi - lo
	var w := maxi(2, roundi(size.x * UNITS_PER_PX / PIXEL))
	var h := maxi(2, roundi(size.y * UNITS_PER_PX / PIXEL))
	var crop := _shrink(photo.get_region(Rect2i(Vector2i(lo * PHOTO_SCALE), Vector2i(size * PHOTO_SCALE))), w, h)
	# Each chunky pixel is in or out by whether its centre is inside the outline
	for y in h:
		for x in w:
			if not Geometry2D.is_point_in_polygon(lo + Vector2((x + 0.5) / w, (y + 0.5) / h) * size, pts):
				crop.set_pixel(x, y, Color(0, 0, 0, 0))
	return _finish(crop, true)


## Shrinks to w x h by averaging everything under each new pixel, so window grids turn into clean
## stripes instead of speckle. Transparent source pixels don't count.
func _shrink(src: Image, w: int, h: int) -> Image:
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var sw := src.get_width()
	var sh := src.get_height()
	for y in h:
		var y0 := y * sh / h
		var y1 := maxi(y0 + 1, (y + 1) * sh / h)
		for x in w:
			var x0 := x * sw / w
			var x1 := maxi(x0 + 1, (x + 1) * sw / w)
			var sum := Vector3.ZERO
			var solid := 0.0
			for sy in range(y0, y1):
				for sx in range(x0, x1):
					var c := src.get_pixel(sx, sy)
					sum += Vector3(c.r, c.g, c.b) * c.a
					solid += c.a
			var n := float((y1 - y0) * (x1 - x0))
			if solid / n > 0.5:
				out.set_pixel(x, y, Color(sum.x / solid, sum.y / solid, sum.z / solid, 1.0))
	return out


## Turns a small image into finished pixel art: brightened so the dusk photo isn't murky under the
## lamps (`levels`), cut down to a handful of colours, given a darker rim, and blown up.
func _finish(img: Image, levels: bool) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var cells: Array[Vector2i] = []
	var brights: Array[float] = []
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				cells.append(Vector2i(x, y))
				brights.append(c.v)
	brights.sort()
	var gain := clampf(0.94 / maxf(brights[int(brights.size() * 0.97)], 0.05), 1.0, 2.4) if levels else 1.0
	var colours: Array[Vector3] = []
	for at in cells:
		var c := img.get_pixelv(at)
		if levels:
			c.v = minf(1.0, pow(c.v * gain, 0.85))
			c.s = minf(1.0, c.s * 1.15)
		colours.append(Vector3(c.r, c.g, c.b))
	# A small palette, by k-means from colours spread across the brightness range
	var ordered := colours.duplicate()
	ordered.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x + a.y + a.z < b.x + b.y + b.z)
	var palette: Array[Vector3] = []
	for i in COLOURS:
		palette.append(ordered[int((i + 0.5) / COLOURS * ordered.size())])
	var pick := PackedInt32Array()
	pick.resize(colours.size())
	for pass_n in 10:
		var sums: Array[Vector3] = []
		var counts := PackedInt32Array()
		sums.resize(COLOURS)
		counts.resize(COLOURS)
		for i in colours.size():
			var best := 0
			for k in COLOURS:
				if colours[i].distance_squared_to(palette[k]) < colours[i].distance_squared_to(palette[best]):
					best = k
			pick[i] = best
			sums[best] += colours[i]
			counts[best] += 1
		for k in COLOURS:
			if counts[k] > 0:
				palette[k] = sums[k] / counts[k]
	for i in cells.size():
		var at := cells[i]
		var p := palette[pick[i]]
		# The rim: any pixel with open air beside it
		var rim := false
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
			var q: Vector2i = at + d
			if q.x < 0 or q.y < 0 or q.x >= w or img.get_pixelv(q).a < 0.5:
				rim = true
		if rim:
			p *= 0.5
		img.set_pixelv(at, Color(p.x, p.y, p.z, 1.0))
	img.resize(w * BLOW_UP, h * BLOW_UP, Image.INTERPOLATE_NEAREST)
	var out := Image.create(img.get_width() + PAD * 2, img.get_height() + PAD * 2, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(PAD, PAD))
	return out
