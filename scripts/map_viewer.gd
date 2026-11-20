extends Control
## Classic's battlefield viewer, after the difficulty, covering the whole screen: the whole
## battlefield as it will be played (its ground, trails and terrain, the enemy camp, its
## bell towers and lanterns, and the castle itself in the map's own style, flags flying,
## all in the light of the difficulty picked) shown as large as fits, over a darkened copy of it filling the rest,
## with its name and a few words. The arrows (or Left and Right) go through them; Start
## (or Enter) begins on the one showing; Back (or Esc) returns to the difficulties.
## Maps the campaign hasn't reached yet show too, greyed, locked, and can't be started.
## For a kind of battle in Battle Modes (setup_battles), the same, through its battlefields:
## its own scenarios and every one from the campaign; Start picks that one (`start` gets
## the scenario's id).

signal start(map: String)
signal back

const FieldArt = preload("res://scripts/field_art.gd")
const Maps = preload("res://scripts/maps.gd")
const CD = preload("res://scripts/campaign_data.gd")
const Castle = preload("res://scripts/castle.gd")
const Bells = preload("res://scripts/bells.gd")
const Ambience = preload("res://scripts/ambience.gd")
const FIELD := Vector2(640, 768)


## What the castle needs to know to draw itself, as the battle would tell it: the field's
## size, a castle at full health, the difficulty's light, and no troops behind it.
class Stand extends RefCounted:
	var FIELD_W := 640.0
	var CASTLE_Y := 736.0
	var FIELD_H := 768.0
	var castle_hp := 1.0
	var castle_max := 1.0
	var ambience := Light.new()

	func get_warriors() -> Array:
		return []

	class Light extends RefCounted:
		var mood := "normal"

		func glow() -> float:
			return Ambience.MOODS[mood]["glow"]

var stand := Stand.new()
var castle: Node2D

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


const CLASSIC_ZONES := ["ds_approach", "ds_bailey", "ds_dawngate", "ds_dawnfield"]
const Scenarios = preload("res://scripts/mission/scenarios.gd")
const Rules = preload("res://scripts/mission/rules.gd")
var battle_type := ""      # Battle Modes: the kind of battle ("" for Classic)
var battles: Array = []    # ...its battlefields: {id, map, name, blurb, open, where, castle}


## Battle Modes: the battlefields of kind `t` (scenario ids `ids`), those the campaign has
## reached open.
func setup_battles(t: String, ids: Array, campaign, first := "") -> void:
	battle_type = t
	difficulty = "normal"
	battles = []
	for id in ids:
		var sc: Dictionary = Scenarios.get_scenario(id)
		var map: String = sc.get("map", "")
		var rules = Rules.make(sc)
		rules.mission = sc
		var where: String = "on the meadow" if map == "" else "on " + Maps.get_map(map).get("name", map)
		var blurb_text: String
		if id.begins_with("story:"):
			blurb_text = "From the campaign (%s): survive as many waves as you can %s." % [CD.TERRITORIES[CD.MISSIONS[id.substr(6)]["territory"]]["name"], where]
		else:
			blurb_text = "Survive as many waves as you can %s." % where
		battles.append({"id": id, "map": map, "name": sc.get("name", id), "blurb": blurb_text,
				"open": Scenarios.is_open(id, campaign), "where": Scenarios.where_to_open(id), "castle": rules.has_castle()})
	maps = battles.map(func(b): return b["map"])
	at = maxi(0, ids.find(first))


func setup(diff: String, opened: Array, first := "") -> void:
	difficulty = diff
	open_maps = opened
	# The campaign's battlefields, and Dawnspire's fields outside the citadel (from the
	# Liberation's stages: not its halls, or the convoy roads).
	maps = [""] + Maps.MAPS.keys() + CLASSIC_ZONES
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
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS   # (the castle's flags and torches move)
	painter = Node2D.new()
	painter.draw.connect(_paint)
	vp.add_child(painter)
	# The castle itself, as the battle draws it.
	stand.ambience.mood = difficulty if Ambience.MOODS.has(difficulty) else "normal"
	castle = Castle.new()
	castle.main = stand
	vp.add_child(castle)
	castle.top_part.castle = castle
	vp.add_child(castle.top_part)
	castle.modulate = Ambience.MOODS[stand.ambience.mood]["castle"]
	castle.top_part.modulate = castle.modulate
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
	head.text = "Classic Survival · %s · choose your battlefield" % CD_name(difficulty) if battle_type == "" \
			else "Battle Modes · %s · choose your battlefield" % Scenarios.TYPES[battle_type]["name"]
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
	name_label.text = "The Meadow" if id == "" else Maps.get_map(id).get("name", id)
	blurb.text = "Open fields with no terrain: the classic game." if id == "" else Maps.get_map(id).get("blurb", "").replace("\n", " ") + "."
	count_label.text = "%d of %d" % [at + 1, maps.size()]
	var best := 0
	var b: Dictionary = battles[at] if not battles.is_empty() else {}
	if not b.is_empty():
		opened = b["open"]
		name_label.text = b["name"]
		blurb.text = b["blurb"]
	if records != "":
		var cfg := ConfigFile.new()
		cfg.load(records)
		if b.is_empty():
			best = cfg.get_value("best", difficulty + ("@" + id if id != "" else ""), 0)
		else:
			for d in ["easy", "normal", "hard"]:
				best = maxi(best, int(cfg.get_value("survive", "%s@%s" % [b["id"], d], 0)))
	if best > 0:
		count_label.text += "  ·  your best here: %d waves" % best
	lock_band.visible = not opened
	lock_label.visible = not opened
	lock_label.text = "Locked\nReach %s in the campaign" % (b["where"] if not b.is_empty() else _territory(id))
	if castle != null:
		castle.visible = b.is_empty() or b["castle"]
		castle.top_part.visible = castle.visible
	picture.modulate = Color.WHITE if opened else Color(0.45, 0.45, 0.45)
	backdrop.modulate = Color(0.2, 0.2, 0.2) if opened else Color(0.12, 0.12, 0.12)
	start_button.disabled = not opened
	castle.set_style(Maps.get_map(id).get("castle", "keep"))
	painter.queue_redraw()


func _start() -> void:
	if not battles.is_empty():
		if battles[at]["open"]:
			start.emit(battles[at]["id"])
		return
	var id: String = maps[at]
	if id == "" or open_maps.has(id):
		start.emit(id)


func _paint() -> void:
	var id: String = maps[at]
	var m: Dictionary = Maps.get_map(id)
	# The ground in the light the battle has (the difficulty's mood, and the map's own tint).
	FieldArt.paint_field(painter, FIELD.x, FIELD.y, Ambience.MOODS[stand.ambience.mood]["ground"] * m.get("tint", Color.WHITE), m)
	# The map's bell towers (the Monastery Gate's), as the battle stands them.
	for p in m.get("bells", []):
		Bells.draw_bell_tower(painter, p, 0.0)


func _territory(map: String) -> String:
	if map == "ds_dawnfield":
		return "the Fields of Dawn (all nine beacons lit)"
	if map.begins_with("ds_"):
		return "Dawnspire"
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
