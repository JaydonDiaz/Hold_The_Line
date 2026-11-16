extends RefCounted
## The Forge: the game's look for every control (option 1 of the UI overhaul). Iron-framed
## dark oak with rivets at the corners, a pixel font, gold for what matters most. Buttons
## light up and gain a gold rim under the cursor, and sink into their frame when pressed.
##
## Everything is drawn here, pixel by pixel, into small textures that stretch as nine-
## patches (corners kept, edges and planks tiled), so nothing is a default Godot box:
##   theme()      the Theme every control in the game falls back on (set on the root window)
##   box(kind)    a panel's frame, for panels made in code:
##                  "bar"     the HUD's bottom bar: oak planks under an iron band
##                  "dialog"  a framed board: the story box, menus, settings, end screens
##                  "card"    a smaller dark board: hover cards, the foe card, tooltips
##                  "inset"   a sunken slot: rows in lists, the freeplay bar
##                  "ring"    just a gold frame (the tutorial's pointer at a control)
##   Buttons take a theme type variation for the one that matters most on a screen:
##     b.theme_type_variation = "ForgePrimary"   (Start Wave, Sell, Begin)
##   and "ForgeFlat" for a borderless one sitting on a card (a list row).

const INK := Color(0.97, 0.9, 0.74)          # parchment-coloured text
const INK_DIM := Color(0.6, 0.53, 0.43)
const GOLD := Color(1.0, 0.8, 0.32)
const OUTLINE := Color(0.05, 0.035, 0.03)
const IRON := Color(0.36, 0.36, 0.4)
const IRON_HI := Color(0.58, 0.58, 0.63)
const IRON_LO := Color(0.17, 0.17, 0.2)
const RIVET := Color(0.75, 0.75, 0.8)
const OAK := Color(0.24, 0.17, 0.11)
const OAK_DARK := Color(0.17, 0.12, 0.08)
const OAK_LINE := Color(0.13, 0.09, 0.06)
const OAK_HI := Color(0.32, 0.23, 0.15)
const EMBER := Color(0.46, 0.27, 0.1)         # the primary button's fill

static var _theme: Theme = null
static var _boxes := {}
static var font: FontFile = null       # Pixelify Sans: everything
static var font_num: FontFile = null   # Jersey 10: big numbers (gold, castle, wave)
static var font_label: FontFile = null  # Silkscreen: tiny captions in capitals


## Loads the fonts (crisp: no smoothing, no hinting, whole pixels).
static func fonts() -> void:
	if font != null:
		return
	font = load("res://fonts/PixelifySans.ttf")
	font_num = load("res://fonts/Jersey10-Regular.ttf")
	font_label = load("res://fonts/Silkscreen-Regular.ttf")
	for f in [font, font_num, font_label]:
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED


## Sets the look on the whole game. It goes into Godot's own default theme (every control
## falls back on that, wherever it sits: a theme set on the window doesn't reach controls
## under a CanvasLayer, like the HUD's), and the fallback font that anything drawn by hand
## (damage numbers, labels over the field) uses.
static func apply(_tree: SceneTree) -> void:
	fonts()
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 16
	var def := ThemeDB.get_default_theme()
	def.merge_with(theme())
	def.default_font = font
	def.default_font_size = 16


static func theme() -> Theme:
	if _theme != null:
		return _theme
	fonts()
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 16
	# Buttons.
	t.set_stylebox("normal", "Button", _button_box("normal", false))
	t.set_stylebox("hover", "Button", _button_box("hover", false))
	t.set_stylebox("pressed", "Button", _button_box("pressed", false))
	t.set_stylebox("hover_pressed", "Button", _button_box("pressed", false))
	t.set_stylebox("disabled", "Button", _button_box("disabled", false))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in [["font_color", INK], ["font_hover_color", Color(1, 0.96, 0.84)], ["font_pressed_color", GOLD],
			["font_hover_pressed_color", GOLD], ["font_focus_color", INK], ["font_disabled_color", INK_DIM],
			["font_outline_color", OUTLINE], ["icon_normal_color", Color.WHITE], ["icon_disabled_color", Color(1, 1, 1, 0.4)]]:
		t.set_color(c[0], "Button", c[1])
	t.set_constant("outline_size", "Button", 0)
	t.set_constant("h_separation", "Button", 6)
	# The primary button: an ember fill, gold lettering.
	t.add_type("ForgePrimary")
	t.set_type_variation("ForgePrimary", "Button")
	for st in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(st, "ForgePrimary", _button_box(st, true))
	t.set_stylebox("hover_pressed", "ForgePrimary", _button_box("pressed", true))
	t.set_color("font_color", "ForgePrimary", GOLD)
	t.set_color("font_hover_color", "ForgePrimary", Color(1, 0.9, 0.55))
	# A flat button (a row on a card): no frame until it's under the cursor.
	t.add_type("ForgeFlat")
	t.set_type_variation("ForgeFlat", "Button")
	t.set_stylebox("normal", "ForgeFlat", _flat_box(0.0))
	t.set_stylebox("hover", "ForgeFlat", _flat_box(0.12))
	t.set_stylebox("pressed", "ForgeFlat", _flat_box(0.2))
	t.set_stylebox("hover_pressed", "ForgeFlat", _flat_box(0.2))
	t.set_stylebox("disabled", "ForgeFlat", _flat_box(0.0))
	# Panels, labels, tooltips.
	t.set_stylebox("panel", "Panel", box("dialog"))
	t.set_stylebox("panel", "PanelContainer", box("card"))
	t.set_color("font_color", "Label", INK)
	t.set_color("font_outline_color", "Label", OUTLINE)
	t.set_stylebox("panel", "TooltipPanel", box("card"))
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font_size("font_size", "TooltipLabel", 14)
	# The volume sliders: an iron groove, filled with ember up to an iron knob.
	t.set_stylebox("slider", "HSlider", _groove(false))
	t.set_stylebox("grabber_area", "HSlider", _groove(true))
	t.set_stylebox("grabber_area_highlight", "HSlider", _groove(true))
	t.set_icon("grabber", "HSlider", _knob(false))
	t.set_icon("grabber_highlight", "HSlider", _knob(true))
	t.set_icon("grabber_disabled", "HSlider", _knob(false))
	t.set_icon("tick", "HSlider", ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8)))
	_theme = t
	return t


## A panel's frame (see the top of the file).
static func box(kind: String) -> StyleBox:
	if _boxes.has(kind):
		return _boxes[kind]
	var b: StyleBox
	match kind:
		"bar":
			b = _bar_box()
		"dialog":
			b = _framed_box(4, true, OAK, 12)
		"card":
			b = _framed_box(2, false, OAK_DARK, 10)
		"inset":
			b = _inset_box()
		"ring":
			b = _ring_box()
	_boxes[kind] = b
	return b


# --- The pixel art -----------------------------------------------------------------------

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


static func _nine(img: Image, margin: int, content: Vector4, tile := false) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = _tex(img)
	s.texture_margin_left = margin
	s.texture_margin_right = margin
	s.texture_margin_top = margin
	s.texture_margin_bottom = margin
	s.content_margin_left = content.x
	s.content_margin_top = content.y
	s.content_margin_right = content.z
	s.content_margin_bottom = content.w
	if tile:
		s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return s


## A button in a state: a 1px dark outline, a 2px iron frame lit along its top and left,
## an oak (or ember) fill with a faint sheen, and a rivet in each corner. Hover lightens
## the fill and rings it in gold; pressed darkens the iron, shades the top of the fill and
## drops the label 2px into the frame; disabled dulls it all.
static func _button_box(state: String, primary: bool) -> StyleBoxTexture:
	var n := 18
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var fill := EMBER if primary else OAK
	var frame := IRON
	var hi := IRON_HI
	var rivet := RIVET
	match state:
		"hover":
			fill = fill.lightened(0.14)
		"pressed":
			fill = fill.darkened(0.22)
			frame = IRON_LO.lightened(0.05)
			hi = IRON_LO.lightened(0.05)
		"disabled":
			fill = fill.darkened(0.35)
			frame = IRON.darkened(0.35)
			hi = frame
			rivet = IRON.darkened(0.1)
	_rect(img, 0, 0, n, n, Color(0, 0, 0, 0.75) if state != "hover" else GOLD)   # the outline (gold under the cursor)
	_rect(img, 1, 1, n - 2, n - 2, frame)
	if state != "pressed" and state != "disabled":
		_rect(img, 1, 1, n - 2, 1, hi)
		_rect(img, 1, 1, 1, n - 2, hi)
		_rect(img, 1, n - 2, n - 2, 1, IRON_LO)
		_rect(img, n - 2, 1, 1, n - 2, IRON_LO)
	_rect(img, 3, 3, n - 6, n - 6, fill)
	if state == "pressed":
		_rect(img, 3, 3, n - 6, 2, fill.darkened(0.3))   # in shadow: it's been pushed in
	elif state != "disabled":
		_rect(img, 3, 3, n - 6, 1, fill.lightened(0.18))   # a sheen along the top
	for c in [Vector2i(4, 4), Vector2i(n - 5, 4), Vector2i(4, n - 5), Vector2i(n - 5, n - 5)]:
		_px(img, c.x, c.y, rivet)
	var s := _nine(img, 6, Vector4(7, 5 if state != "pressed" else 7, 7, 5 if state != "pressed" else 3))
	return s


static func _flat_box(light: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 0.9, 0.7, light * 0.5)
	s.border_color = Color(GOLD, light * 4.0) if light > 0.0 else Color(0, 0, 0, 0)
	s.border_width_left = 2 if light > 0.0 else 0
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


## Oak planks: rows of boards with dark seams and the odd knot.
static func _planks(img: Image, x0: int, y0: int, w: int, h: int, base: Color) -> void:
	_rect(img, x0, y0, w, h, base)
	for y in range(y0, y0 + h):
		var row := (y - y0) % 11
		if row == 10:
			_rect(img, x0, y, w, 1, base.darkened(0.35))
		elif row == 0:
			_rect(img, x0, y, w, 1, base.lightened(0.06))
	_px(img, x0 + w / 3, y0 + 5, base.darkened(0.2))
	_px(img, x0 + w / 3 + 1, y0 + 5, base.darkened(0.2))


## The bottom bar: planks under an iron band riveted every 40px along the top.
static func _bar_box() -> StyleBoxTexture:
	var w := 40
	var h := 30
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	_planks(img, 0, 8, w, h - 8, OAK_DARK.lightened(0.04))
	_rect(img, 0, 0, w, 6, IRON)
	_rect(img, 0, 0, w, 1, OUTLINE)
	_rect(img, 0, 1, w, 1, IRON_HI)
	_rect(img, 0, 6, w, 2, IRON_LO)
	_rect(img, 18, 2, 2, 2, RIVET)
	var s := StyleBoxTexture.new()
	s.texture = _tex(img)
	s.texture_margin_top = 8
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	s.content_margin_top = 10
	return s


## A framed board: an iron frame `frame` px thick (lit top-left), a rivet in each corner
## and, for the big boards, one along each edge's middle; oak planks inside, and on the
## big boards a fine gold line just inside the iron.
static func _framed_box(frame: int, big: bool, wood: Color, pad: int) -> StyleBoxTexture:
	var m := frame + (5 if big else 3)
	var n := m * 2 + 22
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	_planks(img, 0, 0, n, n, wood)
	_rect(img, 0, 0, n, frame + 1, OUTLINE)
	_rect(img, 0, n - frame - 1, n, frame + 1, OUTLINE)
	_rect(img, 0, 0, frame + 1, n, OUTLINE)
	_rect(img, n - frame - 1, 0, frame + 1, n, OUTLINE)
	_rect(img, 1, 1, n - 2, frame - 1, IRON)
	_rect(img, 1, n - frame, n - 2, frame - 1, IRON)
	_rect(img, 1, 1, frame - 1, n - 2, IRON)
	_rect(img, n - frame, 1, frame - 1, n - 2, IRON)
	_rect(img, 1, 1, n - 2, 1, IRON_HI)
	_rect(img, 1, 1, 1, n - 2, IRON_HI)
	if big:
		_rect(img, frame + 1, frame + 1, n - 2 * frame - 2, 1, Color(GOLD, 0.45))
		_rect(img, frame + 1, n - frame - 2, n - 2 * frame - 2, 1, Color(GOLD, 0.45))
		_rect(img, frame + 1, frame + 1, 1, n - 2 * frame - 2, Color(GOLD, 0.45))
		_rect(img, n - frame - 2, frame + 1, 1, n - 2 * frame - 2, Color(GOLD, 0.45))
	var r := 1 if frame >= 3 else 0
	for c in [Vector2i(frame / 2, frame / 2), Vector2i(n - 1 - frame / 2 - r, frame / 2), Vector2i(frame / 2, n - 1 - frame / 2 - r),
			Vector2i(n - 1 - frame / 2 - r, n - 1 - frame / 2 - r)]:
		_rect(img, c.x, c.y, r + 1, r + 1, RIVET)
	var s := _nine(img, m, Vector4(pad, pad, pad, pad), true)
	return s


static func _inset_box() -> StyleBoxTexture:
	var n := 12
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	_rect(img, 0, 0, n, n, OAK_DARK.darkened(0.25))
	_rect(img, 0, 0, n, 2, Color(0, 0, 0, 0.45))
	_rect(img, 0, 0, 1, n, Color(0, 0, 0, 0.3))
	_rect(img, 0, n - 1, n, 1, OAK_HI.darkened(0.2))
	return _nine(img, 3, Vector4(8, 6, 8, 6))


static func _ring_box() -> StyleBoxTexture:
	var n := 12
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	_rect(img, 0, 0, n, 3, GOLD)
	_rect(img, 0, n - 3, n, 3, GOLD)
	_rect(img, 0, 0, 3, n, GOLD)
	_rect(img, n - 3, 0, 3, n, GOLD)
	_rect(img, 1, 1, n - 2, 1, Color(1, 0.95, 0.7))
	return _nine(img, 4, Vector4.ZERO)


static func _groove(filled: bool) -> StyleBoxTexture:
	var img := Image.create(8, 10, false, Image.FORMAT_RGBA8)
	_rect(img, 0, 0, 8, 10, OUTLINE)
	_rect(img, 1, 1, 6, 8, EMBER.lightened(0.1) if filled else IRON_LO)
	_rect(img, 1, 1, 6, 1, EMBER.lightened(0.35) if filled else Color(0, 0, 0, 0.5))
	var s := _nine(img, 3, Vector4(0, 4, 0, 4))
	return s


static func _knob(lit: bool) -> ImageTexture:
	var img := Image.create(12, 20, false, Image.FORMAT_RGBA8)
	_rect(img, 0, 0, 12, 20, OUTLINE)
	_rect(img, 1, 1, 10, 18, IRON_HI if lit else IRON)
	_rect(img, 1, 1, 10, 1, Color(1, 1, 1, 0.5))
	_rect(img, 1, 18, 10, 1, IRON_LO)
	_rect(img, 4, 5, 4, 10, GOLD if lit else IRON_LO)
	return _tex(img)
