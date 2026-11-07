extends Control
## Classic's battlefield viewer, after the difficulty: the whole battlefield as it will be
## played (its ground, trails and terrain, the enemy camp, the castle wall) shown large,
## with its name and a few words. The arrows (or Left and Right) go through them; Start
## (or Enter) begins on the one showing; Back (or Esc) returns to the difficulties.
## Maps the campaign hasn't reached yet show too, greyed, locked, and can't be started.

signal start(map: String)
signal back

const FieldArt = preload("res://scripts/field_art.gd")
const Maps = preload("res://scripts/maps.gd")
const CD = preload("res://scripts/campaign_data.gd")
const W := 640.0
const H := 1040.0
const FIELD := Vector2(640, 768)
const SHOW := Rect2(80, 92, 480, 576)   # where the field is shown (three quarters size)
const STONE := {"keep": [Color(0.6, 0.58, 0.56), Color(0.44, 0.42, 0.42), Color(0.75, 0.15, 0.15)],
	"guildhall": [Color(0.47, 0.45, 0.47), Color(0.32, 0.3, 0.33), Color(0.62, 0.36, 0.16)]}

var maps: Array = []        # "" (the meadow) and every campaign map, in order
var open_maps: Array = []   # the ones the campaign has reached
var at := 0
var difficulty := ""
var vp: SubViewport
var painter: Node2D
var picture: TextureRect
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
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.07)
	bg.size = size
	add_child(bg)
	var head := _label(Vector2(0, 22), Vector2(W, 30), 18, Color(0.85, 0.82, 0.75))
	head.text = "Classic Survival · %s · choose your battlefield" % CD_name(difficulty)
	# The field, painted at full size into a viewport and shown scaled down.
	vp = SubViewport.new()
	vp.size = Vector2i(FIELD)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	painter = Node2D.new()
	painter.draw.connect(_paint)
	vp.add_child(painter)
	add_child(vp)
	var frame := ColorRect.new()
	frame.color = Color(0.45, 0.35, 0.2)
	frame.position = SHOW.position - Vector2(4, 4)
	frame.size = SHOW.size + Vector2(8, 8)
	add_child(frame)
	picture = TextureRect.new()
	picture.texture = vp.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.position = SHOW.position
	picture.size = SHOW.size
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	lock_band = ColorRect.new()
	lock_band.color = Color(0, 0, 0, 0.6)
	lock_band.position = Vector2(SHOW.position.x, SHOW.position.y + SHOW.size.y / 2.0 - 50)
	lock_band.size = Vector2(SHOW.size.x, 100)
	lock_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lock_band)
	lock_label = _label(Vector2(SHOW.position.x, SHOW.position.y + SHOW.size.y / 2.0 - 40), Vector2(SHOW.size.x, 80), 22, Color(1, 0.85, 0.5))
	lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for side in [-1, 1]:
		var arrow := _button(Vector2(14 if side < 0 else W - 62, SHOW.position.y + SHOW.size.y / 2.0 - 40), Vector2(48, 80), "◀" if side < 0 else "▶")
		arrow.add_theme_font_size_override("font_size", 26)
		arrow.tooltip_text = "Previous battlefield (Left)" if side < 0 else "Next battlefield (Right)"
		arrow.pressed.connect(func(): show_map(at + side))
	name_label = _label(Vector2(0, 690), Vector2(W, 40), 30, Color(1, 0.85, 0.35))
	count_label = _label(Vector2(0, 728), Vector2(W, 22), 14, Color(0.6, 0.56, 0.5))
	blurb = _label(Vector2(60, 754), Vector2(W - 120, 70), 17, Color(0.88, 0.85, 0.8))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back_button := _button(Vector2(110, 900), Vector2(190, 60), "Back")
	back_button.pressed.connect(func(): back.emit())
	start_button = _button(Vector2(340, 900), Vector2(190, 60), "Start")
	start_button.pressed.connect(_start)
	show_map(at)


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
	lock_band.visible = not opened
	lock_label.visible = not opened
	lock_label.text = "Locked\nReach %s in the campaign" % _territory(id)
	picture.modulate = Color.WHITE if opened else Color(0.45, 0.45, 0.45)
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
