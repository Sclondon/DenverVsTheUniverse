class_name Hud
extends CanvasLayer
## Everything drawn flat on the glass: score bar, wave banner, title, the upgrade cards, game over.

signal card_picked(index: int)
signal again_pressed
signal play_pressed
## An option on the menu was changed: its name and the index of its new setting.
signal option_changed(key: String, value: int)

const INK := Color("22223b")
const PAPER := Color("f6f3ea")
const GOLD := Color("ffd23f")

var font: Font
## The lettering of a home-made sideshow: a carnival poster face for the big words, marker pen for
## labels and a neat hand for anything longer.
const POSTER := preload("res://fonts/Rye-Regular.ttf")
const MARKER := preload("res://fonts/PermanentMarker-Regular.ttf")
const HAND := preload("res://fonts/PatrickHand-Regular.ttf")
const CRAFT := preload("res://shaders/craft.gdshader")
const CARDBOARD := Color("cfa56d")

var _root: Control
var _bar: Control
var _score: Label
var _wave: Label
var _hearts: HBoxContainer
var _hearts_shown := Vector2i(-1, -1)
var _boss: ColorRect
var _boss_fill: ColorRect
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _banner_tween: Tween
var _title: Control
var _title_best: Label
var _title_tap: Label
var _cards: Control
var _cards_sub: Label
var _card_list: VBoxContainer
var _over: Control
var _over_lines: Array[Label] = []
var _time := 0.0
var _threats: Array[Label] = []
var _menu: HBoxContainer
var _options: Control
var _option_rows: Array[Button] = []
var _settings := {}
var _abilities: Array[ColorRect] = []


func _ready() -> void:
	var theme := Theme.new()
	theme.default_font = MARKER
	_root = Control.new()
	_root.theme = theme
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_bar()
	_build_banner()
	_build_title()
	_build_cards()
	_build_over()


func _process(delta: float) -> void:
	_time += delta
	_title_tap.modulate.a = 0.55 + 0.45 * sin(_time * 4.0)


func set_stats(score: int, wave: int, hearts: int, max_hearts: int, city: int) -> void:
	_score.text = "%d" % score
	_wave.text = "WAVE %d\nCITY %d%%" % [wave, city]
	var want := Vector2i(hearts, max_hearts)
	if want == _hearts_shown:
		return
	_hearts_shown = want
	for c in _hearts.get_children():
		c.queue_free()
	for i in max_hearts:
		var h := TextureRect.new()
		h.texture = Cutout.art("heart")
		h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.custom_minimum_size = Vector2(34, 34)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i >= hearts:
			h.modulate = Color(0.1, 0.1, 0.2, 0.55)
		_hearts.add_child(h)


## Boss health, 0 to 1; anything below zero hides the bar.
func set_boss(fraction: float) -> void:
	_boss.visible = fraction >= 0.0
	_boss_fill.anchor_right = clampf(fraction, 0.0, 1.0)


func banner(title: String, sub := "", hold := 1.6) -> void:
	_banner_title.text = title
	_banner_sub.text = sub
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.2)
	_banner_tween.tween_interval(hold)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)


func show_title(best: int) -> void:
	_title.visible = true
	_bar.visible = false
	_cards.visible = false
	_over.visible = false
	_banner.modulate.a = 0.0
	_title_best.text = "BEST  %d" % best if best > 0 else ""


func show_game() -> void:
	_title.visible = false
	_options.visible = false
	_cards.visible = false
	_over.visible = false
	_bar.visible = true
	set_boss(-1.0)


func show_cards(offer: Array, levels: Dictionary, wave: int) -> void:
	for c in _card_list.get_children():
		c.queue_free()
	for i in offer.size():
		_card_list.add_child(_card(offer[i], int(levels.get(offer[i].id, 0)), i))
	_cards_sub.text = "Wave %d survived. Choose one." % wave
	_cards.visible = true
	_cards.modulate.a = 0.0
	create_tween().tween_property(_cards, "modulate:a", 1.0, 0.25)


func hide_cards() -> void:
	_cards.visible = false


func show_over(score: int, wave: int, best: int, reason: String) -> void:
	_over_lines[0].text = reason
	_over_lines[1].text = "%d" % score
	_over_lines[2].text = "Fell on wave %d" % wave
	_over_lines[3].text = "NEW BEST!" if score >= best and score > 0 else "Best  %d" % best
	_over.visible = true
	_over.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_property(_over, "modulate:a", 1.0, 0.4)
	set_boss(-1.0)


func _label(words: String, size: int, color := PAPER, outline := true, face: Font = null) -> Label:
	var l := Label.new()
	if face != null:
		l.add_theme_font_override("font", face)
	l.text = words
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", maxi(6, size / 4))
	return l


func _gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


## Makes a button look cut from cardboard and taped up (shaders/craft.gdshader): the board is a
## sheet behind the button that tints as it is hovered and pressed.
func _handmade(b: Button, board: Color, seed: float) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var sheet := ColorRect.new()
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.show_behind_parent = true
	var m := ShaderMaterial.new()
	m.shader = CRAFT
	m.set_shader_parameter("base", board)
	m.set_shader_parameter("seed", seed)
	sheet.material = m
	_passive(sheet)
	b.add_child(sheet)
	sheet.resized.connect(func() -> void: m.set_shader_parameter("size", sheet.size))
	b.mouse_entered.connect(func() -> void: sheet.color = Color(1.12, 1.1, 1.0))
	b.mouse_exited.connect(func() -> void: sheet.color = Color.WHITE)
	b.button_down.connect(func() -> void: sheet.color = Color(0.86, 0.84, 0.8))


func _passive(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _paper(bg: Color, border := 4, radius := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = INK
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 5)
	s.set_content_margin_all(14)
	return s


func _build_bar() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_passive(margin)
	_root.add_child(margin)
	_bar = margin
	var col := VBoxContainer.new()
	_passive(col)
	margin.add_child(col)
	var row := HBoxContainer.new()
	_passive(row)
	col.add_child(row)
	_score = _label("0", 36, GOLD, true, POSTER)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_score)
	_wave = _label("WAVE 1", 24)
	_wave.add_theme_constant_override("line_spacing", -8)
	_wave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_wave)
	_hearts = HBoxContainer.new()
	_hearts.alignment = BoxContainer.ALIGNMENT_END
	_hearts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hearts.add_theme_constant_override("separation", 2)
	_passive(_hearts)
	row.add_child(_hearts)
	_boss = ColorRect.new()
	_boss.color = INK
	_boss.custom_minimum_size = Vector2(0, 16)
	_boss.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boss.custom_minimum_size.x = 360
	_passive(_boss)
	col.add_child(_boss)
	_boss_fill = ColorRect.new()
	_boss_fill.color = Color("e040fb")
	_boss_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_fill.offset_left = 3
	_boss_fill.offset_top = 3
	_boss_fill.offset_right = -3
	_boss_fill.offset_bottom = -3
	_passive(_boss_fill)
	_boss.add_child(_boss_fill)


func _build_banner() -> void:
	_banner = VBoxContainer.new()
	_banner.anchor_right = 1.0
	_banner.anchor_top = 0.2
	_banner.anchor_bottom = 0.2
	_banner.modulate.a = 0.0
	_passive(_banner)
	_root.add_child(_banner)
	_banner_title = _label("", 60, GOLD, true, POSTER)
	_banner.add_child(_banner_title)
	_banner_sub = _label("", 30)
	_banner.add_child(_banner_sub)


func _build_title() -> void:
	# The name goes in the sky and the prompt on the grass, leaving the city and the parade in view.
	_title = Control.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_passive(_title)
	_root.add_child(_title)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	box.offset_top = 8
	box.add_theme_constant_override("separation", -22)
	_passive(box)
	_title.add_child(box)
	box.add_child(_label("DENVER", 100, Color("9be33a"), true, POSTER))
	box.add_child(_label("VS", 40, Color("ff3d7f")))
	box.add_child(_label("THE UNIVERSE", 62, Color("9be7f5"), true, POSTER))
	box.add_child(_passive(_gap(46)))
	box.add_child(_label("A  COLORADO  ALIEN  SIDESHOW", 22, GOLD))
	var foot := VBoxContainer.new()
	foot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	foot.offset_bottom = -34
	foot.add_theme_constant_override("separation", -2)
	_passive(foot)
	_title.add_child(foot)
	_title_best = _label("", 22, GOLD)
	_title_best.position = Vector2(14, 10)
	_title.add_child(_title_best)
	_title_tap = _label("STEP RIGHT UP!", 28)
	foot.add_child(_title_tap)
	_build_menu()
	foot.add_child(_menu)
	foot.add_child(_passive(_gap(8)))
	foot.add_child(_label("Hold and drag to run; drag up or down at a corner to take the other street. The robots aim and fire on their own.", 20, Color("e6dfc8"), true, HAND))


func _build_cards() -> void:
	_cards = Control.new()
	_cards.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cards.visible = false
	_root.add_child(_cards)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.1, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cards.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	_passive(box)
	_cards.add_child(box)
	box.add_child(_label("REINFORCEMENTS", 48, GOLD, true, POSTER))
	_cards_sub = _label("", 22)
	box.add_child(_cards_sub)
	_card_list = VBoxContainer.new()
	_card_list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_list.add_theme_constant_override("separation", 2)
	_passive(_card_list)
	box.add_child(_card_list)


func _card(u: Dictionary, level: int, index: int) -> Button:
	var kind_color := Color(Upgrades.KIND_COLORS[u.kind])
	var b := Button.new()
	b.custom_minimum_size = Vector2(680, 176)
	b.focus_mode = Control.FOCUS_NONE
	_handmade(b, CARDBOARD, index + 1.0)
	b.pressed.connect(func() -> void: card_picked.emit(index))
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_passive(margin)
	b.add_child(margin)
	# Lettered by hand, so never quite straight
	margin.pivot_offset = b.custom_minimum_size * 0.5
	margin.rotation = [-0.012, 0.014, -0.008][index % 3]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_passive(row)
	margin.add_child(row)
	var icon := TextureRect.new()
	icon.texture = Cutout.art(u.icon)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_passive(icon)
	# A night-sky tile behind the icon, so pale art (clouds, the bear's glass hall) still reads.
	var tile := PanelContainer.new()
	var night := _paper(Color("2b2d5b"), 0, 4)
	night.shadow_size = 0
	night.set_content_margin_all(8)
	tile.add_theme_stylebox_override("panel", night)
	tile.custom_minimum_size = Vector2(118, 0)
	_passive(tile)
	tile.add_child(icon)
	row.add_child(tile)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	_passive(col)
	row.add_child(col)
	var head := HBoxContainer.new()
	_passive(head)
	col.add_child(head)
	var title := _label(u.name, 30, INK, false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var tag := "" if int(u.max) > 99 else ("NEW" if level == 0 else "LEVEL %d" % (level + 1))
	head.add_child(_label(tag, 20, kind_color, false))
	var kind := _label(Upgrades.KIND_LABELS[u.kind], 17, kind_color, false)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(kind)
	var desc := _label(Upgrades.describe(u, level), 21, Color("2b2b40"), false, HAND)
	desc.add_theme_constant_override("line_spacing", -4)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(desc)
	return b


func _build_over() -> void:
	_over = Control.new()
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.visible = false
	_root.add_child(_over)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.1, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	_passive(box)
	_over.add_child(box)
	for spec: Array in [[50, Color("ff6b6b")], [96, GOLD], [28, PAPER], [26, Color("9be7f5")]]:
		var l := _label("", spec[0], spec[1], true, POSTER if spec[0] > 40 else null)
		box.add_child(l)
		_over_lines.append(l)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	_passive(gap)
	box.add_child(gap)
	var again := Button.new()
	again.text = "DEFEND AGAIN"
	again.focus_mode = Control.FOCUS_NONE
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.custom_minimum_size = Vector2(320, 76)
	again.add_theme_font_size_override("font_size", 32)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		again.add_theme_color_override(state, INK)
	_handmade(again, Color("f2c94c"), 9.0)
	again.pressed.connect(func() -> void: again_pressed.emit())
	box.add_child(again)


## The two ability buttons at the bottom right, shown once their cards are held. They are not real
## buttons: Main asks `ability_at` about each new touch, so a thumb can steer and tap at once.
func set_abilities(jump: bool, dash: bool, dash_ready: bool) -> void:
	if _abilities.is_empty():
		for i in 2:
			var pad := ColorRect.new()
			pad.anchor_left = 1.0
			pad.anchor_right = 1.0
			pad.anchor_top = 1.0
			pad.anchor_bottom = 1.0
			pad.offset_left = -150.0 - i * 140.0
			pad.offset_right = pad.offset_left + 136.0
			pad.offset_top = -150.0 - i * 26.0
			pad.offset_bottom = pad.offset_top + 136.0
			var m := ShaderMaterial.new()
			m.shader = CRAFT
			m.set_shader_parameter("base", [Color("8fd94a"), Color("ff8a3a")][i])
			m.set_shader_parameter("seed", 20.0 + i)
			m.set_shader_parameter("size", Vector2(136, 136))
			m.set_shader_parameter("taped", 0.0)
			pad.material = m
			_passive(pad)
			var word := _label(["JUMP", "DASH"][i], 30, INK, false)
			word.set_anchors_preset(Control.PRESET_FULL_RECT)
			word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			word.rotation = [-0.06, 0.05][i]
			word.pivot_offset = Vector2(68, 68)
			pad.add_child(word)
			_root.add_child(pad)
			_abilities.append(pad)
	_abilities[0].visible = jump
	_abilities[1].visible = dash
	_abilities[1].color = Color.WHITE if dash_ready else Color(0.55, 0.55, 0.6)


## Which ability button, if any, is under this point on the screen: "jump", "dash" or "".
func ability_at(point: Vector2) -> String:
	for i in _abilities.size():
		if _abilities[i].visible and _abilities[i].get_global_rect().grow(10.0).has_point(point):
			return ["jump", "dash"][i]
	return ""


## Arrows at the screen edges for aliens that are off to the left or right.
func set_threats(left: int, right: int) -> void:
	if _threats.is_empty():
		for side in 2:
			var l := _label("", 34, Color("ff3d7f"))
			l.anchor_top = 0.4
			l.anchor_bottom = 0.4
			l.anchor_left = float(side)
			l.anchor_right = float(side)
			l.grow_horizontal = Control.GROW_DIRECTION_END if side == 0 else Control.GROW_DIRECTION_BEGIN
			l.offset_left = 12 if side == 0 else -12
			l.offset_right = l.offset_left
			_bar.add_sibling(l)
			_threats.append(l)
	_threats[0].text = "<< %d" % left if left > 0 else ""
	_threats[1].text = "%d >>" % right if right > 0 else ""
	for l in _threats:
		l.visible = _bar.visible
		l.modulate.a = 0.6 + 0.4 * sin(_time * 8.0)


# --- The main menu and its options ---------------------------------------------------------------

## What each option is called and the words for each of its settings, in the order they cycle.
const OPTIONS := [
	["sound", "SOUND", ["OFF", "ON"]],
	["picture", "PICTURE", ["AUTO", "SHARP", "FAST"]],
	["retro", "RETRO FILTER", ["OFF", "ON"]],
	["blur", "LENS BLUR", ["OFF", "ON"]],
	["wingman", "WINGMAN", ["OFF", "ON"]],
]


## A cardboard button with marker lettering.
func _sign(words: String, board: Color, size: Vector2, seed: float) -> Button:
	var b := Button.new()
	b.text = words
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = size
	b.add_theme_font_size_override("font_size", 30)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, INK)
	_handmade(b, board, seed)
	return b


func _build_menu() -> void:
	_menu = HBoxContainer.new()
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu.add_theme_constant_override("separation", 10)
	var play := _sign("PLAY", Color("f2c94c"), Vector2(300, 96), 31.0)
	play.add_theme_font_size_override("font_size", 40)
	play.pressed.connect(func() -> void: play_pressed.emit())
	_menu.add_child(play)
	var options := _sign("OPTIONS", CARDBOARD, Vector2(260, 96), 32.0)
	options.pressed.connect(func() -> void: _options.visible = true)
	_menu.add_child(options)

	_options = Control.new()
	_options.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options.visible = false
	_root.add_child(_options)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.1, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", -6)
	_passive(box)
	_options.add_child(box)
	box.add_child(_label("OPTIONS", 48, GOLD, true, POSTER))
	box.add_child(_passive(_gap(14)))
	for i in OPTIONS.size():
		var row := _sign("", CARDBOARD, Vector2(520, 84), 40.0 + i)
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.pressed.connect(func() -> void:
			var key: String = OPTIONS[i][0]
			_settings[key] = (int(_settings.get(key, 0)) + 1) % OPTIONS[i][2].size()
			set_options(_settings)
			option_changed.emit(key, int(_settings[key])))
		box.add_child(row)
		_option_rows.append(row)
	box.add_child(_passive(_gap(14)))
	var back := _sign("BACK", Color("f2c94c"), Vector2(260, 84), 49.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: _options.visible = false)
	box.add_child(back)


## Shows the options as they are now set (option name -> index of its setting).
func set_options(settings: Dictionary) -> void:
	_settings = settings
	for i in OPTIONS.size():
		_option_rows[i].text = "%s:  %s" % [OPTIONS[i][1], OPTIONS[i][2][int(settings.get(OPTIONS[i][0], 0))]]
