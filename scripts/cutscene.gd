extends Control
## The prologue: a short animated cutscene that opens a new campaign (campaign_data.gd
## PROLOGUE). Each scene is pixel art drawn in code on a 4px grid across the top of the
## screen, with its narration typed out below: the beacons of the old Line lit and then
## going dark, each of the eight peoples at home (their folk at work, their leader's
## portrait and a few words about them), the Ogre King's horde on the march, Ashwatch
## Keep with torches on the ridge, and the title line. Scenes move on by themselves, or
## on a click / Space; Esc skips the rest. Emits `finished` at the end and frees itself.

signal finished

const CD = preload("res://scripts/campaign_data.gd")
const Sprites = preload("res://scripts/sprites.gd")
const Portraits = preload("res://scripts/portraits.gd")

const W := 640.0
const H := 1040.0
const PX := 4.0           # one art pixel
const GW := 160           # the art is 160 x 150 art pixels
const GH := 150
const ART_H := 600.0
const READ_SPEED := 40.0  # characters a second while typing
const LINGER := 2.6       # seconds a scene stays once its text is out
const OUTLINE := Color(0.1, 0.07, 0.1)
# What each people's folk do in their scene (a pose to swap to now and then).
const ACTIONS := {"engineer": "strike", "archer": "draw", "healer": "raise", "frost": "cast", "bard": "strum",
		"alchemist": "brew", "martial": "punch", "mage": "cast"}
# Deepdelve's gun crew: the Cannoneer's drill, as [from second, pose] on a loop of DRILL
# seconds (the shot goes off at FIRE_AT).
const DRILL := 4.4
const FIRE_AT := 3.3
const DRILL_POSES := [[0.0, "carry"], [0.7, "load"], [1.3, "ram"], [1.48, ""], [1.66, "ram"], [1.84, ""], [2.02, "ram"],
		[2.2, ""], [2.9, "light"], [3.3, "cover"], [3.9, ""]]

var scenes: Array = CD.PROLOGUE
var at := -1
var t := 0.0
var fade := 1.0            # black over everything: 1 at a cut, 0 once it's faded in
var switching := false
var text_label: Label
var name_label: Label
var sub_label: Label
var hint: Label
var title_label: Label
var portrait: TextureRect
var frame: ColorRect
var typing: Tween
var rng := RandomNumberGenerator.new()
var stars := []
var snow := []


func _ready() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rng.seed = 2026
	for i in 70:
		stars.append(Vector2i(rng.randi_range(0, GW - 1), rng.randi_range(0, 70)))
	for i in 60:
		snow.append(Vector2(rng.randf() * GW, rng.randf() * GH))
	# The text panel under the art.
	frame = ColorRect.new()
	frame.color = Color(0.2, 0.17, 0.14)
	frame.position = Vector2(24, ART_H + 30)
	frame.size = Vector2(140, 140)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	portrait = TextureRect.new()
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.position = Vector2(6, 6)
	portrait.size = Vector2(128, 128)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(portrait)
	name_label = _label(Vector2(184, ART_H + 26), Vector2(430, 34), 26)
	sub_label = _label(Vector2(184, ART_H + 62), Vector2(430, 22), 14)
	sub_label.add_theme_color_override("font_color", Color(0.72, 0.68, 0.6))
	text_label = _label(Vector2(184, ART_H + 92), Vector2(430, 280), 18)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_color_override("font_color", Color(0.94, 0.92, 0.87))
	hint = _label(Vector2(16, H - 34), Vector2(W - 32, 22), 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_color_override("font_color", Color(0.55, 0.52, 0.48))
	title_label = _label(Vector2(0, 250), Vector2(W, 80), 40)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	title_label.add_theme_color_override("font_outline_color", OUTLINE)
	title_label.add_theme_constant_override("outline_size", 8)
	_next()


func _label(pos: Vector2, sz: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


# --- Moving through the scenes ---------------------------------------------------------

func _scene() -> Dictionary:
	return scenes[at] if at >= 0 and at < scenes.size() else {}


func _next() -> void:
	at += 1
	if at >= scenes.size():
		_close()
		return
	t = 0.0
	var s := _scene()
	var text: String = s.get("text", "")
	var who := ""
	name_label.text = ""
	sub_label.text = ""
	title_label.text = ""
	match s["scene"]:
		"nation":
			var f: Dictionary = CD.FACTIONS[s["faction"]]
			text = f["people"]
			who = f["leader"]
			name_label.text = f["name"]
			name_label.add_theme_color_override("font_color", f["color"])
			sub_label.text = "%s  ·  led by %s" % [f["home"], CD.SPEAKERS[who]["name"]]
		"horde", "ashwatch":
			who = s.get("who", "")
			name_label.text = CD.SPEAKERS[who]["name"] if s["scene"] == "horde" else "Ashwatch Keep"
			name_label.add_theme_color_override("font_color", CD.SPEAKERS[who]["color"] if s["scene"] == "horde" else Color(1, 0.85, 0.35))
			sub_label.text = CD.SPEAKERS[who]["role"] if s["scene"] == "horde" else "The southern frontier"
		"title":
			title_label.text = text
			text = ""
	frame.visible = who != ""
	if who != "":
		portrait.texture = Portraits.texture(who, CD.SPEAKERS[who]["look"])
	# Narration without a portrait runs the panel's full width.
	var x := 184.0 if who != "" else 40.0
	text_label.position = Vector2(x, ART_H + (92.0 if name_label.text != "" else 40.0))
	text_label.size = Vector2(W - x - 26.0, 280)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if who != "" else HORIZONTAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", 18 if who != "" else 21)
	text_label.text = text
	text_label.visible_ratio = 0.0
	if typing:
		typing.kill()
	typing = create_tween()
	typing.tween_property(text_label, "visible_ratio", 1.0, maxf(0.3, text.length() / READ_SPEED)).set_delay(0.5)
	hint.text = ("Click to begin" if s["scene"] == "title" else "Click or Space to continue  ·  Esc to skip") + "   %d/%d" % [at + 1, scenes.size()]


## How long the current scene plays before moving on by itself.
func _duration() -> float:
	var n := text_label.text.length()
	if _scene().get("scene", "") == "title":
		return 6.0
	return 0.5 + n / READ_SPEED + LINGER


func _process(delta: float) -> void:
	t += delta
	if not switching:
		fade = maxf(0.0, fade - delta * 2.5)
		if t > _duration():
			_cut()
	queue_redraw()


## Fades to black, then on to the next scene.
func _cut() -> void:
	if switching:
		return
	switching = true
	var tw := create_tween()
	tw.tween_property(self, "fade", 1.0, 0.35)
	tw.tween_callback(func():
		switching = false
		_next())


## A click or key: show the rest of the text, or move on.
func advance() -> void:
	if text_label.visible_ratio < 1.0:
		if typing:
			typing.kill()
		text_label.visible_ratio = 1.0
		t = maxf(t, _duration() - LINGER)
	else:
		_cut()


func skip() -> void:
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


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			advance()
		KEY_ESCAPE:
			skip()
	get_viewport().set_input_as_handled()


# --- Drawing ----------------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.07, 0.06, 0.05))
	var s := _scene()
	if not s.is_empty():
		match s["scene"]:
			"beacons":
				_draw_beacons(false)
			"dark":
				_draw_beacons(true)
			"nation":
				_draw_nation(s["faction"])
			"horde":
				_draw_horde()
			"ashwatch":
				_draw_ashwatch()
			"title":
				_draw_title()
	# A frame line between the art and the text.
	draw_rect(Rect2(0, ART_H, W, 4), Color(0.45, 0.35, 0.2))
	if fade > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, fade))


## One art pixel (or a block of them).
func _b(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(floorf(x) * PX, floorf(y) * PX, maxf(1.0, roundf(w)) * PX, maxf(1.0, roundf(h)) * PX), c)


## A sky in flat bands, lighter toward the horizon.
func _sky(top: Color, low: Color, bands := 10, height := GH) -> void:
	for i in bands:
		var y0 := float(height) * i / bands
		_b(0, y0, GW, float(height) / bands + 1, top.lerp(low, i / float(bands - 1)))


## A ridge of land across the art: its top follows a few sine waves; filled to the bottom.
func _ridge(base: float, amp: float, seed_: float, col: Color, step := 2) -> void:
	for x in range(0, GW, step):
		var h := base - amp * (0.6 * sin(x * 0.07 + seed_) + 0.4 * sin(x * 0.19 + seed_ * 2.0))
		_b(x, h, step, GH - h, col)


func _stars() -> void:
	for i in stars.size():
		var p: Vector2i = stars[i]
		var tw := 0.5 + 0.5 * sin(t * 2.0 + i * 1.7)
		_b(p.x, p.y, 1, 1, Color(1, 1, 0.9, 0.35 + 0.6 * tw))


func _flame(x: float, y: float, s: float, phase: float) -> void:
	var flick := sin(t * 11.0 + phase) * 0.5 + 0.5
	# A soft glow, then the flame in three colours.
	for r in [6.0, 4.0]:
		_b(x - r * s, y - r * s, r * 2.0 * s, r * 2.0 * s, Color(1.0, 0.6, 0.2, 0.08))
	_b(x - 1.5 * s, y - (3.0 + flick) * s, 3.0 * s, (3.0 + flick) * s, Color(1.0, 0.45, 0.1))
	_b(x - 1.0 * s, y - (2.0 + flick) * s, 2.0 * s, (2.0 + flick) * s, Color(1.0, 0.75, 0.2))
	_b(x - 0.5 * s, y - 1.5 * s, 1.0 * s, 1.0 * s, Color(1.0, 0.95, 0.6))


## A troop sprite standing with its feet at art pixel (x, y), at 4x, with a little bob.
func _figure(kind: String, x: float, y: float, phase: float, flip := false, scale := 4.0, act := true) -> void:
	var tex: Texture2D = Sprites.frames(kind)[0]
	var cycle := fmod(t + phase, 1.6)
	if act and ACTIONS.has(kind) and cycle > 1.1:
		var posed = Sprites.pose(kind, ACTIONS[kind])
		if posed != null:
			tex = posed
	var bob := -absf(sin((t + phase) * 3.0)) * 2.0 if not act else 0.0
	var sz := Vector2(tex.get_width(), tex.get_height()) * scale
	var foot := Vector2(x * PX, y * PX + bob)
	draw_rect(Rect2(foot.x - sz.x * 0.3, foot.y - 4, sz.x * 0.6, 6), Color(0, 0, 0, 0.25))
	draw_set_transform(foot, 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
	draw_texture_rect(tex, Rect2(-sz.x / 2.0, -sz.y, sz.x, sz.y), false)
	draw_set_transform(Vector2.ZERO)


func _walker(kind: String, x: float, y: float, phase: float, scale := 4.0) -> void:
	var frames: Array = Sprites.frames(kind)
	var tex: Texture2D = frames[int((t + phase) * 6.0) % frames.size()]
	var sz := Vector2(tex.get_width(), tex.get_height()) * scale
	var foot := Vector2(x * PX, y * PX - absf(sin((t + phase) * 9.0)) * 3.0)
	draw_texture_rect(tex, Rect2(foot.x - sz.x / 2.0, foot.y - sz.y, sz.x, sz.y), false)


# --- The beacons ----------------------------------------------------------------------

const BEACONS := [Vector2(14, 92), Vector2(40, 80), Vector2(66, 88), Vector2(93, 76), Vector2(120, 86), Vector2(146, 78)]


func _draw_beacons(going_dark: bool) -> void:
	var cold := 1.0 if not going_dark else clampf(t / 8.0, 0.0, 1.0)
	_sky(Color(0.05, 0.06, 0.16).lerp(Color(0.03, 0.03, 0.06), cold), Color(0.24, 0.2, 0.38).lerp(Color(0.1, 0.1, 0.16), cold), 12, 110)
	_stars()
	_ridge(100, 8, 1.0, Color(0.13, 0.13, 0.25))
	_ridge(112, 10, 4.0, Color(0.09, 0.09, 0.17))
	_ridge(128, 6, 7.0, Color(0.06, 0.06, 0.11))
	for i in BEACONS.size():
		var p: Vector2 = BEACONS[i]
		# The tower: grey stone with a dark outline, its brazier on top.
		_b(p.x - 3, p.y - 12, 6, 14, OUTLINE)
		_b(p.x - 2, p.y - 11, 4, 13, Color(0.42, 0.4, 0.45))
		_b(p.x - 3, p.y - 13, 6, 2, Color(0.3, 0.28, 0.32))
		var lit: bool = (t > 0.6 + i * 0.55) if not going_dark else (t < 1.2 + i * 0.7)
		if lit:
			_flame(p.x, p.y - 13, 1.0, i * 1.3)
		elif going_dark:
			# Smoke rising from the dead brazier.
			for k in 4:
				var rise := fmod(t * 6.0 + k * 5.0, 22.0)
				_b(p.x - 1 + sin(t + k) * 1.5, p.y - 15 - rise, 2, 2, Color(0.5, 0.5, 0.55, 0.5 * (1.0 - rise / 22.0)))
	# The light leaping from beacon to beacon as each one catches.
	if not going_dark:
		for i in BEACONS.size() - 1:
			var start := 0.6 + i * 0.55
			var k := (t - start) / 0.55
			if k > 0.0 and k < 1.0:
				var a: Vector2 = BEACONS[i] + Vector2(0, -15)
				var b: Vector2 = BEACONS[i + 1] + Vector2(0, -15)
				var p := a.lerp(b, k) + Vector2(0, -sin(k * PI) * 10.0)
				_b(p.x - 1, p.y - 1, 2, 2, Color(1, 0.85, 0.4))


# --- The peoples ----------------------------------------------------------------------

func _draw_nation(f: String) -> void:
	match f:
		"stonehollow":
			_sky(Color(0.45, 0.55, 0.7), Color(0.75, 0.8, 0.85))
			_peaks([[20, 70, 30], [70, 40, 45], [125, 60, 35]], Color(0.45, 0.43, 0.45), true)
			_ridge(105, 4, 2.0, Color(0.42, 0.37, 0.33))
			# Houses cut into the mountainside, windows lit.
			for i in 6:
				var hx := 10 + i * 25
				var hy := 92 + (i % 2) * 6
				_b(hx, hy, 14, 10, Color(0.55, 0.5, 0.45))
				_b(hx + 3, hy + 3, 3, 3, Color(1.0, 0.8, 0.4))
				_b(hx + 8, hy + 3, 3, 3, Color(1.0, 0.8, 0.4))
				_b(hx - 1, hy - 2, 16, 2, Color(0.35, 0.3, 0.27))
			_b(0, 120, GW, 30, Color(0.4, 0.36, 0.32))
			# Sparks fly off the hammers.
			for k in 6:
				var sp := fmod(t * 2.0 + k * 0.37, 1.0)
				_b(48 + k * 13 + sp * 6.0, 108 - sp * 10.0 + sp * sp * 14.0, 1, 1, Color(1, 0.85, 0.3, 1.0 - sp))
		"greenwood":
			_sky(Color(0.45, 0.68, 0.72), Color(0.8, 0.9, 0.75))
			for layer in 3:
				var col := Color(0.22, 0.42, 0.26).darkened(0.25 * (2 - layer))
				for i in 12:
					_pine(6 + i * 14 + layer * 5, 70 + layer * 18, 14 + layer * 4, col)
			_b(0, 122, GW, 28, Color(0.32, 0.5, 0.25))
			# Fireflies drifting through the trees.
			for k in 10:
				_b(fmod(k * 37.0 + t * 4.0 * (1 + k % 3), GW), 80 + 25 * sin(t * 0.8 + k), 1, 1, Color(1, 1, 0.6, 0.5 + 0.5 * sin(t * 3.0 + k)))
		"deepdelve":
			_sky(Color(0.12, 0.09, 0.08), Color(0.3, 0.22, 0.16))
			# The mine mouth, timbered, with the forge glowing inside.
			_b(46, 40, 68, 84, Color(0.2, 0.15, 0.12))
			_b(54, 56, 52, 68, Color(0.06, 0.04, 0.04))
			var glow := 0.7 + 0.3 * sin(t * 4.0)
			_b(62, 90, 36, 34, Color(1.0, 0.45, 0.1, 0.35 * glow))
			_b(70, 104, 20, 20, Color(1.0, 0.6, 0.2, 0.5 * glow))
			for x in [50, 104]:
				_b(x, 52, 6, 72, Color(0.45, 0.3, 0.16))
			_b(48, 48, 64, 6, Color(0.5, 0.33, 0.18))
			_b(0, 124, GW, 26, Color(0.28, 0.22, 0.18))
			# Rails, and a cart of ore rolling along them.
			_b(0, 128, GW, 1, Color(0.55, 0.55, 0.6))
			_b(0, 132, GW, 1, Color(0.55, 0.55, 0.6))
			var cx := fmod(t * 14.0, GW + 30.0) - 20.0
			_b(cx, 120, 16, 8, Color(0.35, 0.3, 0.3))
			_b(cx + 2, 117, 12, 4, Color(0.95, 0.75, 0.25))
			_b(cx + 2, 128, 3, 3, OUTLINE)
			_b(cx + 11, 128, 3, 3, OUTLINE)
		"mercyvale":
			_sky(Color(0.95, 0.75, 0.55), Color(1.0, 0.92, 0.78))
			_ridge(98, 6, 3.0, Color(0.55, 0.7, 0.42))
			# The shrine, white with a gold dome.
			_b(66, 70, 28, 30, Color(0.95, 0.94, 0.9))
			_b(72, 60, 16, 10, Color(0.95, 0.78, 0.3))
			_b(76, 54, 8, 6, Color(0.95, 0.78, 0.3))
			_b(79, 50, 2, 4, Color(1, 0.95, 0.7))
			_b(76, 84, 8, 16, Color(0.6, 0.45, 0.3))
			for x in [20, 120]:
				_b(x, 88, 20, 12, Color(0.92, 0.9, 0.82))
				_b(x + 8, 82, 4, 6, Color(0.92, 0.9, 0.82))
			_b(0, 118, GW, 32, Color(0.45, 0.62, 0.35))
			# Motes of healing light rising.
			for k in 12:
				var rise := fmod(t * 8.0 + k * 9.0, 60.0)
				_b(20 + k * 11, 118 - rise, 1, 1, Color(1, 1, 0.7, 1.0 - rise / 60.0))
		"frostmarch":
			_sky(Color(0.5, 0.65, 0.85), Color(0.85, 0.92, 1.0))
			_peaks([[15, 55, 30], [60, 35, 40], [110, 50, 38], [150, 65, 25]], Color(0.75, 0.82, 0.92), true)
			_ridge(110, 5, 5.0, Color(0.9, 0.94, 0.98))
			_b(0, 122, GW, 28, Color(0.94, 0.96, 1.0))
			for i in snow.size():
				var p: Vector2 = snow[i]
				_b(fmod(p.x + sin(t + i) * 3.0, GW), fmod(p.y + t * (10.0 + i % 5 * 2.0), GH), 1, 1, Color(1, 1, 1, 0.9))
		"freecities":
			_sky(Color(0.95, 0.55, 0.4), Color(1.0, 0.82, 0.55))
			# Rooftops, towers and a line of bunting.
			var roofs := [Color(0.75, 0.3, 0.3), Color(0.35, 0.45, 0.7), Color(0.85, 0.6, 0.25), Color(0.55, 0.3, 0.55)]
			for i in 9:
				var hx := i * 18 - 4
				var hh := 26 + (i * 7) % 14
				_b(hx, 112 - hh, 16, hh, Color(0.92, 0.85, 0.72))
				_b(hx - 1, 108 - hh, 18, 5, roofs[i % roofs.size()])
				_b(hx + 5, 118 - hh + 8, 4, 5, Color(1, 0.85, 0.45))
			for x in range(0, GW, 4):
				var sag := 54.0 + 6.0 * sin(x / float(GW) * PI * 3.0)
				_b(x, sag, 1, 1, Color(0.3, 0.25, 0.2))
				if x % 8 == 0:
					_b(x, sag + 1, 2, 3, roofs[(x / 8) % roofs.size()].lightened(0.2))
			_b(0, 118, GW, 32, Color(0.6, 0.5, 0.42))
		"monastery":
			_sky(Color(0.95, 0.6, 0.55), Color(1.0, 0.85, 0.65))
			_peaks([[80, 20, 50]], Color(0.55, 0.45, 0.5), false)
			# The monastery on the peak, and clouds drifting below it.
			_b(72, 20, 16, 14, Color(0.75, 0.25, 0.2))
			_b(68, 18, 24, 3, Color(0.3, 0.2, 0.2))
			_b(74, 10, 12, 8, Color(0.75, 0.25, 0.2))
			_b(71, 8, 18, 3, Color(0.3, 0.2, 0.2))
			for k in 4:
				var cx := fmod(k * 50.0 + t * 5.0, GW + 40.0) - 30.0
				_b(cx, 60 + k * 9, 30, 4, Color(1, 0.95, 0.92, 0.85))
				_b(cx + 6, 57 + k * 9, 16, 3, Color(1, 0.95, 0.92, 0.85))
			_b(0, 118, GW, 32, Color(0.5, 0.42, 0.42))
			for k in 8:
				var fall := fmod(t * 9.0 + k * 13.0, 90.0)
				_b(fmod(k * 23.0 + sin(t + k) * 6.0, GW), 40 + fall, 1, 1, Color(1, 0.7, 0.8))
		"spires":
			_sky(Color(0.06, 0.04, 0.16), Color(0.25, 0.15, 0.4))
			_stars()
			_b(124, 14, 10, 10, Color(0.95, 0.95, 0.85))
			# Crystal spires with glowing tips.
			for i in 5:
				var sx := 14 + i * 32
				var sh := 50 + (i * 17) % 34
				_b(sx, 120 - sh, 10, sh, Color(0.45, 0.32, 0.7))
				_b(sx + 2, 116 - sh, 6, 4, Color(0.6, 0.45, 0.85))
				_b(sx + 3, 112 - sh, 4, 4, Color(0.8, 0.65, 1.0))
				var pulse := 0.5 + 0.5 * sin(t * 2.5 + i)
				_b(sx + 4, 108 - sh, 2, 4, Color(1, 0.9, 1.0, pulse))
			_b(0, 120, GW, 30, Color(0.18, 0.12, 0.28))
			for k in 14:
				_b(fmod(k * 41.0, GW), fmod(110.0 - t * (4.0 + k % 4) - k * 9.0, 110.0), 1, 1, Color(0.85, 0.7, 1.0, 0.7))
	if f == "deepdelve":
		_draw_gun_crew()
	# The folk, at work.
	var folk: Array = CD.FACTIONS[f]["folk"]
	for i in folk.size():
		_figure(folk[i], 40 + i * 40, 128 + (i % 2) * 6, i * 0.53, i == 2)


## Deepdelve's gun crew test-firing a cannon: the Cannoneer fetches a ball, loads it,
## rams it home and touches off the fuse; the gun bucks, flashes and smokes, and the
## ball arcs away over the hills.
func _draw_gun_crew() -> void:
	var d := fmod(t + 1.0, DRILL)
	var pose := ""
	for step in DRILL_POSES:
		if d >= step[0]:
			pose = step[1]
	var since := d - FIRE_AT   # seconds since the shot (negative before it)
	var recoil := 2.0 if since >= 0.0 and since < 0.15 else (1.0 if since >= 0.15 and since < 0.3 else 0.0)
	var cx := 142.0 - recoil
	var wood := Color(0.48, 0.3, 0.16)
	var iron := Color(0.26, 0.26, 0.3)
	# Carriage, wheel and barrel, outlined.
	_b(cx - 11, 121, 20, 8, OUTLINE)
	_b(cx - 10, 122, 18, 6, wood)
	for i in 14:
		var bx := cx - 9 + i * 1.3
		var by := 121.0 - i * 0.62
		_b(bx - 1, by - 2, 3, 5, OUTLINE)
	for i in 14:
		var bx := cx - 9 + i * 1.3
		var by := 121.0 - i * 0.62
		_b(bx, by - 1, 2, 3, iron if i % 5 != 4 else iron.lightened(0.25))
	# A spoked wheel.
	for wy in range(-4, 4):
		for wx in range(-4, 4):
			var dist := Vector2(wx + 0.5, wy + 0.5).length()
			if dist <= 4.1:
				var col := OUTLINE
				if dist <= 3.0:
					col = wood.lightened(0.15) if wx == 0 or wy == 0 or wx == -1 or wy == -1 else wood.darkened(0.3)
				_b(cx + 1 + wx, 127 + wy, 1, 1, col)
	var muzzle := Vector2(cx + 9.5, 111.5)
	if since >= 0.0:
		# Flash, smoke rolling out, and the ball on its way.
		if since < 0.14:
			_b(muzzle.x, muzzle.y - 3, 6, 6, Color(1.0, 0.95, 0.6))
			_b(muzzle.x + 1, muzzle.y - 5, 8, 10, Color(1.0, 0.6, 0.2, 0.6))
		for k in 5:
			var age := since - k * 0.05
			if age > 0.0 and age < 1.0:
				var r := 2.0 + age * 6.0
				_b(muzzle.x + 2 + age * 10.0 + k * 2.0 - r / 2.0, muzzle.y - age * 6.0 - r / 2.0 + k, r, r, Color(0.75, 0.73, 0.72, 0.7 * (1.0 - age)))
		if since < 0.9:
			var bx2 := muzzle.x + since * 60.0
			var by2 := muzzle.y - since * 55.0 + since * since * 40.0
			_b(bx2, by2, 2, 2, OUTLINE)
	# The Cannoneer beside his gun.
	var tex: Texture2D = Sprites.frames("cannoneer")[0]
	if pose != "":
		var posed = Sprites.pose("cannoneer", pose)
		if posed != null:
			tex = posed
	var sz := Vector2(tex.get_width(), tex.get_height()) * PX
	var foot := Vector2(124 * PX, 131 * PX)
	draw_rect(Rect2(foot.x - 20, foot.y - 4, 40, 6), Color(0, 0, 0, 0.25))
	draw_texture_rect(tex, Rect2(foot.x - 8 * PX, foot.y - sz.y, sz.x, sz.y), false)


func _peaks(list: Array, col: Color, snowy: bool) -> void:
	for m in list:
		var x: float = m[0]
		var top: float = m[1]
		var half: float = m[2]
		for row in range(int(top), 120):
			var w := (row - top) / (120.0 - top) * half
			_b(x - w, row, w * 2.0 + 1.0, 1, col if row < top + 0.35 * (120 - top) or not snowy else col.darkened(0.15))
			if snowy and row < top + (120 - top) * 0.22:
				_b(x - w, row, w * 2.0 + 1.0, 1, Color(0.97, 0.98, 1.0))


func _pine(x: float, base: float, h: float, col: Color) -> void:
	for row in int(h):
		var w := (row + 2) * 0.45
		_b(x - w, base - h + row, w * 2.0 + 1.0, 1, col)
	_b(x, base, 1, 4, Color(0.3, 0.2, 0.12))


# --- The horde, Ashwatch, the title ----------------------------------------------------

func _draw_horde() -> void:
	_sky(Color(0.3, 0.06, 0.06), Color(0.85, 0.35, 0.12))
	# A burning village on the skyline.
	for i in 7:
		var hx := 8 + i * 22
		_b(hx, 84, 14, 16, Color(0.12, 0.06, 0.06))
		_b(hx + 2, 78, 10, 6, Color(0.12, 0.06, 0.06))
		if i % 2 == 0:
			_flame(hx + 7, 80, 1.6, i)
	_ridge(102, 3, 9.0, Color(0.16, 0.08, 0.07))
	_b(0, 118, GW, 32, Color(0.22, 0.12, 0.1))
	# Ash drifting down.
	for k in 20:
		_b(fmod(k * 29.0 + t * 3.0, GW), fmod(k * 17.0 + t * 12.0, 118.0), 1, 1, Color(0.6, 0.55, 0.5, 0.6))
	# The Ogre King looming behind his column as it marches past.
	_walker("ogre_king", 80 + sin(t * 0.4) * 6.0, 132, 0.0, 8.0)
	var kinds := ["goblin", "orc", "goblin", "wolf", "orc", "troll", "goblin", "orc"]
	for i in kinds.size():
		var x := fmod(i * 24.0 + t * 9.0, GW + 40.0) - 20.0
		_walker(kinds[i], x, 140 + (i % 3) * 3, i * 0.37)


func _draw_ashwatch() -> void:
	_sky(Color(0.18, 0.12, 0.3), Color(0.9, 0.45, 0.3), 12, 90)
	# The ridge, with the enemy's torches gathering along it.
	_ridge(62, 4, 3.0, Color(0.2, 0.14, 0.22))
	for i in 14:
		var tx := 8 + i * 11 + sin(t * 0.7 + i) * 2.0
		var on := t > 0.4 + i * 0.25
		if on:
			_b(tx, 56 + sin(i * 1.3) * 2.0, 1, 2, Color(1.0, 0.6 + 0.3 * sin(t * 9.0 + i), 0.2))
	_b(0, 70, GW, 80, Color(0.24, 0.3, 0.22))
	# The keep, in the foreground: walls, two towers and a lit gate.
	var stone := Color(0.42, 0.4, 0.46)
	_b(30, 92, 100, 38, OUTLINE)
	_b(31, 93, 98, 37, stone)
	for x in range(31, 129, 6):
		_b(x, 89, 3, 4, stone)
	for tx in [24, 118]:
		_b(tx - 1, 74, 20, 56, OUTLINE)
		_b(tx, 75, 18, 55, stone.darkened(0.1))
		_b(tx + 7, 84, 4, 6, Color(1.0, 0.75, 0.35))
		_b(tx - 2, 70, 22, 5, Color(0.55, 0.22, 0.2))
	_b(72, 108, 16, 22, Color(0.25, 0.16, 0.1))
	_b(74, 110, 12, 4, Color(1.0, 0.7, 0.3, 0.6 + 0.3 * sin(t * 5.0)))
	_flame(66, 104, 0.8, 1.0)
	_flame(94, 104, 0.8, 2.0)
	# Two swordsmen on the wall, watching the ridge.
	_figure("swordsman", 56, 92, 0.0, false, 3.0, false)
	_figure("swordsman", 104, 92, 0.7, true, 3.0, false)
	_b(0, 130, GW, 20, Color(0.18, 0.22, 0.16))


func _draw_title() -> void:
	_sky(Color(0.03, 0.03, 0.08), Color(0.12, 0.1, 0.2), 8, 120)
	_stars()
	_ridge(118, 4, 2.0, Color(0.07, 0.07, 0.12))
	# One beacon, catching again.
	var p := Vector2(80, 112)
	_b(p.x - 4, p.y - 18, 8, 20, OUTLINE)
	_b(p.x - 3, p.y - 17, 6, 19, Color(0.42, 0.4, 0.45))
	_b(p.x - 4, p.y - 19, 8, 2, Color(0.3, 0.28, 0.32))
	if t > 1.0:
		_flame(p.x, p.y - 19, minf(2.0, (t - 1.0) * 2.0), 0.0)
	title_label.modulate.a = clampf((t - 1.6) / 1.0, 0.0, 1.0)
