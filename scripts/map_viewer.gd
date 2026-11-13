extends Control
## Classic's battlefield viewer, after the difficulty, covering the whole screen: the whole
## battlefield as it will be played (its ground, trails and terrain, the enemy camp, the
## castle wall) shown as large as fits, over a darkened copy of it filling the rest,
## with its name and a few words. The arrows (or Left and Right) go through them; Start
## (or Enter) begins on the one showing; Back (or Esc) returns to the difficulties.
## Maps the campaign hasn't reached yet show too, greyed, locked, and can't be started.

signal start(map: String)
signal back

const FieldArt = preload("res://scripts/field_art.gd")
const Maps = preload("res://scripts/maps.gd")
const CD = preload("res://scripts/campaign_data.gd")
const FIELD := Vector2(640, 768)
const STONE := {"keep": [Color(0.6, 0.58, 0.56), Color(0.44, 0.42, 0.42), Color(0.75, 0.15, 0.15)],
	"guildhall": [Color(0.47, 0.45, 0.47), Color(0.32, 0.3, 0.33), Color(0.62, 0.36, 0.16)]}

var maps: Array = []        # "" (the meadow) and every campaign map, in order
var open_maps: Array = []   # the ones the campaign has reached
var at := 0
var difficulty := ""
var records := ""          # where the best runs are kept (main.records_path; "" for none)
var vp: SubViewport
var painter: Node2D
var picture: TextureRect
var backdrop: TextureRect
var top_bar: ColorRect
var panel: ColorRect
var head: Label
var arrows := []
var back_button: Button
var name_label: Label
var blurb: Label
var lock_band: ColorRect
var lock_label: Label
var count_label: Label
var start_button: Button


func setup(diff: String, opened: Array, first := "") -> void:
	difficulty = diff
	open_maps = opened
	maps = [""] + Maps.MAPS.keys()
	at = maxi(0, maps.find(first))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# The field, painted at full size into a viewport.
	vp = SubViewport.new()
	vp.size = Vector2i(FIELD)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	painter = Node2D.new()
	painter.draw.connect(_paint)
	vp.add_child(painter)
	add_child(vp)
	# Behind everything, the same battlefield, darkened, filling the whole screen; in
	# front, the battlefield itself as large as fits between the top bar and the panel.
	backdrop = TextureRect.new()
	backdrop.texture = vp.get_texture()
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(0.2, 0.2, 0.2)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	picture = TextureRect.new()
	picture.texture = vp.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	top_bar = ColorRect.new()
	top_bar.color = Color(0.06, 0.05, 0.04, 0.85)
	add_child(top_bar)
	head = _label(Vector2.ZERO, Vector2.ZERO, 18, Color(0.88, 0.85, 0.78))
	head.text = "Classic Survival · %s · choose your battlefield" % CD_name(difficulty)
	panel = ColorRect.new()
	panel.color = Color(0.06, 0.05, 0.04, 0.88)
	add_child(panel)
	lock_band = ColorRect.new()
	lock_band.color = Color(0, 0, 0, 0.6)
	lock_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lock_band)
	lock_label = _label(Vector2.ZERO, Vector2.ZERO, 24, Color(1, 0.85, 0.5))
	lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for side in [-1, 1]:
		var arrow := _button(Vector2.ZERO, Vector2(52, 90), "")
		arrow.icon = _arrow_icon(side)   # (drawn, not a text arrow: the game's font has none, and the web has no system fonts to borrow one from)
		arrow.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		arrow.tooltip_text = "Previous battlefield (Left)" if side < 0 else "Next battlefield (Right)"
		arrow.pressed.connect(func(): show_map(at + side))
		arrows.append(arrow)
	name_label = _label(Vector2.ZERO, Vector2.ZERO, 30, Color(1, 0.85, 0.35))
	count_label = _label(Vector2.ZERO, Vector2.ZERO, 14, Color(0.6, 0.56, 0.5))
	blurb = _label(Vector2.ZERO, Vector2.ZERO, 17, Color(0.88, 0.85, 0.8))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	back_button = _button(Vector2.ZERO, Vector2(190, 56), "Back")
	back_button.pressed.connect(func(): back.emit())
	start_button = _button(Vector2.ZERO, Vector2(190, 56), "Start")
	start_button.pressed.connect(_start)
	resized.connect(_lay_out)
	_lay_out()
	show_map(at)


## Places everything for the screen's size: the whole screen is covered, the panel's
## text and buttons stay in a 640-wide column in the middle.
func _lay_out() -> void:
	var s := size
	var mid := s.x / 2.0
	backdrop.size = s
	top_bar.size = Vector2(s.x, 48)
	head.position = Vector2(0, 12)
	head.size = Vector2(s.x, 26)
	var panel_h := 230.0
	panel.position = Vector2(0, s.y - panel_h)
	panel.size = Vector2(s.x, panel_h)
	var area := Rect2(0, 48, s.x, s.y - panel_h - 48)
	picture.position = area.position
	picture.size = area.size
	lock_band.position = Vector2(0, area.get_center().y - 60)
	lock_band.size = Vector2(s.x, 120)
	lock_label.position = lock_band.position
	lock_label.size = lock_band.size
	arrows[0].position = Vector2(12, area.get_center().y - 45)
	arrows[1].position = Vector2(s.x - 64, area.get_center().y - 45)
	name_label.position = Vector2(0, s.y - panel_h + 16)
	name_label.size = Vector2(s.x, 40)
	count_label.position = Vector2(0, s.y - panel_h + 54)
	count_label.size = Vector2(s.x, 22)
	blurb.position = Vector2(mid - 280, s.y - panel_h + 80)
	blurb.size = Vector2(560, 50)
	back_button.position = Vector2(mid - 210, s.y - 84)
	start_button.position = Vector2(mid + 20, s.y - 84)


func CD_name(diff: String) -> String:
	return preload("res://scripts/data.gd").DIFFICULTIES.get(diff, {}).get("name", diff)


## Shows map number i (wrapping round).
func show_map(i: int) -> void:
	at = posmod(i, maps.size())
	var id: String = maps[at]
	var opened := id == "" or open_maps.has(id)
	name_label.text = "The Meadow" if id == "" else Maps.MAPS[id].get("name", id)
	blurb.text = "Open fields with no terrain: the classic game." if id == "" else Maps.MAPS[id].get("blurb", "").replace("\n", " ") + "."
	count_label.text = "%d of %d" % [at + 1, maps.size()]
	var best := 0
	if records != "":
		var cfg := ConfigFile.new()
		cfg.load(records)
		best = cfg.get_value("best", difficulty + ("@" + id if id != "" else ""), 0)
	if best > 0:
		count_label.text += "  ·  your best here: %d waves" % best
	lock_band.visible = not opened
	lock_label.visible = not opened
	lock_label.text = "Locked\nReach %s in the campaign" % _territory(id)
	picture.modulate = Color.WHITE if opened else Color(0.45, 0.45, 0.45)
	backdrop.modulate = Color(0.2, 0.2, 0.2) if opened else Color(0.12, 0.12, 0.12)
	start_button.disabled = not opened
	painter.queue_redraw()
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _start() -> void:
	var id: String = maps[at]
	if id == "" or open_maps.has(id):
		start.emit(id)


func _paint() -> void:
	var id: String = maps[at]
	var m: Dictionary = Maps.get_map(id)
	FieldArt.paint_field(painter, FIELD.x, FIELD.y, Color.WHITE, m)
	# The castle wall along the bottom, in its style.
	var pal: Array = STONE.get(m.get("castle", "keep"), STONE["keep"])
	var top := 736.0
	painter.draw_rect(Rect2(0, top, FIELD.x, FIELD.y - top), Color(0.1, 0.07, 0.1))
	painter.draw_rect(Rect2(0, top + 2, FIELD.x, FIELD.y - top - 2), pal[1])
	for y in range(int(top) + 3, int(FIELD.y), 8):
		for x in range(-8 * ((y / 8) % 2), int(FIELD.x), 16):
			painter.draw_rect(Rect2(x + 1, y, 14, 7), pal[0])
	for x in range(6, int(FIELD.x), 26):
		painter.draw_rect(Rect2(x, top - 9, 14, 11), pal[1])
	for tx in [0.0, FIELD.x - 60.0, FIELD.x / 2.0 - 48.0]:
		var wide := 96.0 if tx == FIELD.x / 2.0 - 48.0 else 60.0
		painter.draw_rect(Rect2(tx, top - 40, wide, 72), pal[1])
		painter.draw_rect(Rect2(tx + 3, top - 37, wide - 6, 66), pal[0])
		painter.draw_rect(Rect2(tx + wide / 2.0 - 8, top - 70, 2, 30), Color(0.25, 0.2, 0.15))
		painter.draw_rect(Rect2(tx + wide / 2.0 - 6, top - 70, 16, 10), pal[2])
	painter.draw_rect(Rect2(FIELD.x / 2.0 - 20, top - 4, 40, 36), Color(0.42, 0.26, 0.14))


func _territory(map: String) -> String:
	for m in CD.MISSIONS:
		if CD.MISSIONS[m].get("map", "") == map:
			return CD.TERRITORIES[CD.MISSIONS[m]["territory"]]["name"]
	return "it"


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_LEFT, KEY_A:
			show_map(at - 1)
		KEY_RIGHT, KEY_D:
			show_map(at + 1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_start()
		KEY_ESCAPE:
			back.emit()
		_:
			return
	get_viewport().set_input_as_handled()


func _label(pos: Vector2, sz: Vector2, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _button(pos: Vector2, sz: Vector2, text: String) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = sz
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	add_child(b)
	return b


## A solid arrowhead pointing left (side -1) or right (side 1), as a little texture.
static func _arrow_icon(side: int) -> ImageTexture:
	var w := 18
	var h := 30
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var half := 1.0 - absf(y - (h - 1) / 2.0) / ((h - 1) / 2.0)   # 0 at the top and bottom, 1 in the middle
		for x in w:
			var reach := float(x if side > 0 else w - 1 - x) / (w - 1)
			if reach <= half:
				img.set_pixel(x, y, Color(1, 0.95, 0.85))
	return ImageTexture.create_from_image(img)
