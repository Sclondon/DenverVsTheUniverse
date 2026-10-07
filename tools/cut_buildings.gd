extends SceneTree
## Takes the real buildings in the reference photos in conceptart/ (outline, faces, colours) and paints each as a chunky
## pixel-art cutout in art/px/. Re-run after changing SPECS:
## godot --headless --path . -s tools/cut_buildings.gd [-- --sheet=<png to review>]

## World units one chunky pixel covers, and how many texture pixels it is drawn with.
const PIXEL := 0.05
const BLOW_UP := 5
## Colours each hand-drawn landmark is painted with.
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
		made[id] = _finish(_shrink(svg, w, h))
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
	return _paint(crop)


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


## Paints a building from its photo: the photo only supplies the outline, where each face is and
## what colour it is. Faces are flattened to a few plain colours and the windows are drawn on as a
## regular grid, so it reads as pixel art and not as a scan.
func _paint(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var cells := _cells(img)
	var brights: Array[float] = []
	for at in cells:
		brights.append(img.get_pixelv(at).v)
	brights.sort()
	var gain := clampf(0.9 / maxf(brights[int(brights.size() * 0.97)], 0.05), 1.0, 2.4)
	for at in cells:
		var c := img.get_pixelv(at)
		c.v = minf(1.0, pow(c.v * gain, 0.85))
		c.s = minf(1.0, c.s * 1.2)
		img.set_pixelv(at, c)
	# Faces: the building is split into upright bands by the colour of each column, and each band
	# into blocks by the colour of each row, so every face is a plain rectangle of one colour.
	var face := {}
	var palette: Array[Vector3] = []
	var col_means: Array[Vector3] = []
	for x in w:
		col_means.append(_mean(img, cells, Rect2i(x, 0, 1, h)))
	var bands := _runs(col_means, 3, 3)
	for band: Vector2i in bands:
		var row_means: Array[Vector3] = []
		for y in h:
			row_means.append(_mean(img, cells, Rect2i(band.x, y, band.y - band.x, 1)))
		for block: Vector2i in _runs(row_means, 2, 6):
			var area := Rect2i(band.x, block.x, band.y - band.x, block.y - block.x)
			palette.append(_mean(img, cells, area))
			for at in cells:
				if area.has_point(at):
					face[at] = palette.size() - 1
	var rng := RandomNumberGenerator.new()
	rng.seed = w * 1000 + h
	for at: Vector2i in cells:
		var p := palette[face[at]]
		var c := Color(p.x, p.y, p.z)
		# Windows: bands two pixels apart, split by mullions. Sunlit faces have bright glass, shaded
		# faces dark glass with the odd office light left on.
		if at.y % 3 == 1 and at.x % 4 != 0 and face.get(at + Vector2i.UP, -1) == face[at] and face.get(at + Vector2i.DOWN, -1) == face[at]:
			if c.get_luminance() > 0.45:
				c = c.lightened(0.3)
			elif rng.randf() < 0.07:
				c = Color(1.0, 0.86, 0.45)
			else:
				c = c.darkened(0.35)
		if face.get(at + Vector2i.UP, -1) == -1 or face.get(at + Vector2i.LEFT, -1) == -1 or face.get(at + Vector2i.RIGHT, -1) == -1:
			c = c.darkened(0.5)
		img.set_pixelv(at, c)
	return _blow_up(img)


## Turns a small drawing into finished pixel art: cut down to a handful of colours, given a darker
## rim, and blown up.
func _finish(img: Image) -> Image:
	var cells := _cells(img)
	var colours: Array[Vector3] = []
	for at in cells:
		var c := img.get_pixelv(at)
		colours.append(Vector3(c.r, c.g, c.b))
	var palette: Array[Vector3] = []
	var pick := _palette(colours, COLOURS, palette)
	for i in cells.size():
		var p := palette[pick[i]]
		img.set_pixelv(cells[i], Color(p.x, p.y, p.z, 1.0))
	return _blow_up(img)


func _cells(img: Image) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				cells.append(Vector2i(x, y))
	return cells


## Fills `palette` with `count` colours that best cover `colours` (k-means, started from colours
## spread across the brightness range) and returns which one each colour is nearest.
func _palette(colours: Array[Vector3], count: int, palette: Array[Vector3]) -> PackedInt32Array:
	var ordered := colours.duplicate()
	ordered.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x + a.y + a.z < b.x + b.y + b.z)
	for i in count:
		palette.append(ordered[int((i + 0.5) / count * ordered.size())])
	var pick := PackedInt32Array()
	pick.resize(colours.size())
	for pass_n in 10:
		var sums: Array[Vector3] = []
		var counts := PackedInt32Array()
		sums.resize(count)
		counts.resize(count)
		for i in colours.size():
			var best := 0
			for k in count:
				if colours[i].distance_squared_to(palette[k]) < colours[i].distance_squared_to(palette[best]):
					best = k
			pick[i] = best
			sums[best] += colours[i]
			counts[best] += 1
		for k in count:
			if counts[k] > 0:
				palette[k] = sums[k] / counts[k]
	return pick


func _blow_up(img: Image) -> Image:
	img.resize(img.get_width() * BLOW_UP, img.get_height() * BLOW_UP, Image.INTERPOLATE_NEAREST)
	var out := Image.create(img.get_width() + PAD * 2, img.get_height() + PAD * 2, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(PAD, PAD))
	return out


## Mean colour of the solid pixels of `img` inside `area` (black if there are none).
func _mean(img: Image, cells: Array[Vector2i], area: Rect2i) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				sum += Vector3(c.r, c.g, c.b)
				n += 1
	return sum / n if n > 0 else Vector3.ZERO


## Splits a line of colours into stretches of like colour: sorted into `kinds` groups, then any
## stretch shorter than `shortest` joins the one before it. Returns each stretch as (from, to).
func _runs(line: Array[Vector3], kinds: int, shortest: int) -> Array[Vector2i]:
	var palette: Array[Vector3] = []
	var pick := _palette(line, kinds, palette)
	# Groups that came out nearly the same colour are one group
	for k in kinds:
		for j in k:
			if palette[k].distance_to(palette[j]) < 0.14:
				for i in pick.size():
					if pick[i] == k:
						pick[i] = j
	var runs: Array[Vector2i] = []
	var from := 0
	for i in range(1, line.size() + 1):
		if i == line.size() or pick[i] != pick[from]:
			if i - from < shortest and not runs.is_empty():
				runs[-1].y = i
			else:
				runs.append(Vector2i(from, i))
			from = i
	if runs.size() > 1 and runs[0].y - runs[0].x < shortest:
		runs[1].x = 0
		runs.remove_at(0)
	return runs
