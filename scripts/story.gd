extends Control
## A story scene: a few lines of dialogue in a box along the bottom of the screen, each
## with the speaker's portrait (portraits.gd, in the dress of their homeland) and name. The text types out;
## a click, Space or Enter shows the rest of the line, then the next one. Esc skips to
## the end. Blocks the game underneath while it's up, then emits `finished` and frees itself.

signal finished

const Sprites = preload("res://scripts/sprites.gd")
const CD = preload("res://scripts/campaign_data.gd")
const Portraits = preload("res://scripts/portraits.gd")
const W := 640.0
const H := 1040.0
const BOX := Rect2(12, 774, 616, 254)
const TYPE_SPEED := 55.0   # characters a second

var lines: Array = []
var at := -1
var box: Panel
var portrait: TextureRect
var name_label: Label
var role_label: Label
var text_label: Label
var hint: Label
var typing: Tween


## lines: STORY entries ({"who", "text"}), already filtered for the campaign's state.
func setup(story_lines: Array) -> void:
	lines = story_lines


func _ready() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.size = Vector2(W, H)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	box = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.07, 0.97)
	style.border_color = Color(1.0, 0.85, 0.3)
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	box.add_theme_stylebox_override("panel", style)
	box.position = BOX.position
	box.size = BOX.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	# The portrait sits in a framed square on the left.
	var frame := ColorRect.new()
	frame.color = Color(0.2, 0.17, 0.14)
	frame.position = Vector2(14, 16)
	frame.size = Vector2(124, 124)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(frame)
	portrait = TextureRect.new()
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(6, 6)
	portrait.size = Vector2(112, 112)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(portrait)
	name_label = _label(Vector2(152, 12), Vector2(450, 28), 22)
	role_label = _label(Vector2(152, 40), Vector2(450, 20), 13)
	role_label.add_theme_color_override("font_color", Color(0.7, 0.66, 0.6))
	text_label = _label(Vector2(152, 66), Vector2(450, 150), 17)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	hint = _label(Vector2(14, 222), Vector2(588, 22), 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_color_override("font_color", Color(0.6, 0.56, 0.5))
	_next()


func _label(pos: Vector2, sz: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	return l


func _next() -> void:
	at += 1
	if at >= lines.size():
		_close()
		return
	var line: Dictionary = lines[at]
	var who: Dictionary = CD.SPEAKERS.get(line["who"], {"name": "", "role": "", "color": Color.WHITE})
	portrait.texture = Portraits.texture(line["who"], who["look"]) if who.has("look") else Sprites.frames("swordsman")[0]
	name_label.text = who["name"]
	name_label.add_theme_color_override("font_color", who["color"])
	role_label.text = who["role"]
	text_label.text = line["text"]
	text_label.visible_ratio = 0.0
	hint.text = "Click or Space to continue  ·  Esc to skip  (%d/%d)" % [at + 1, lines.size()]
	if typing:
		typing.kill()
	typing = create_tween()
	typing.tween_property(text_label, "visible_ratio", 1.0, maxf(0.2, (line["text"] as String).length() / TYPE_SPEED))


## A click or key: finish typing the line, or go on to the next one.
func advance() -> void:
	if text_label.visible_ratio < 1.0:
		if typing:
			typing.kill()
		text_label.visible_ratio = 1.0
	else:
		_next()


func skip() -> void:
	at = lines.size()
	_close()


func _close() -> void:
	if is_queued_for_deletion():
		return
	finished.emit()
	queue_free()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()


## Keys go to the story first (before the game sees them) while it's up.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			advance()
		KEY_ESCAPE:
			skip()
	get_viewport().set_input_as_handled()
