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
const ACTIONS := {"engineer": "strike", "miner": "strike", "archer": "draw", "bard": "strum", "alchemist": "brew", "martial": "punch"}
# Spellcasters keep their staff upright and the magic plays out at its tip instead.
const SPELLS := ["frost", "mage", "healer"]
const STAFF_TIP := Vector2(6.5, -14.0)   # the staff's orb or crystal, in sprite pixels from the feet (all three casters)
const ACT_CYCLE := 1.6    # seconds in each folk's work loop...
const ACT_AT := 1.05      # ...the action starting this far in
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
var skipped := false   # Esc: whatever follows is skipped too


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
		"ogre", "marshal":
			who = s["who"]
			name_label.text = CD.SPEAKERS[who]["name"]
			name_label.add_theme_color_override("font_color", CD.SPEAKERS[who]["color"])
			sub_label.text = CD.SPEAKERS[who]["role"]
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
	hint.text = ("Click to begin" if s["scene"] == "title" else "Click or Space to continue  ·  Esc to skip") + ("   %d/%d" % [at + 1, scenes.size()] if scenes.size() > 1 else "")


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
	skipped = true
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
			"ogre":
				_draw_ogre_court()
			"marshal":
				_draw_marshal_road()
			"ashwatch":
				_draw_ashwatch()
			"title":
				_draw_title()
	# A frame line between the art and the text.
	draw_rect(Rect2(0, ART_H, W, 4), Color(0.45, 0.35, 0.2))
	if fade > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, fade))


## One art pixel (or a block of them).
## Nothing goes below the art's foot (GH), where the text panel starts.
func _b(x: float, y: float, w: float, h: float, c: Color) -> void:
	var top := floorf(y)
	var rows := minf(maxf(1.0, roundf(h)), GH - top)
	if rows <= 0.0:
		return
	draw_rect(Rect2(floorf(x) * PX, top * PX, maxf(1.0, roundf(w)) * PX, rows * PX), c)


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


## A troop sprite standing with its feet at art pixel (x, y), at 4x. Now and then it
## acts: a pose swap with a one-pixel hop into it, or, for the spellcasters, their magic
## gathering at the staff and going off. Sprites are only ever moved by whole art pixels,
## never stretched or turned, so the pixel art stays crisp.
func _figure(kind: String, x: float, y: float, phase: float, flip := false, scale := 4.0, act := true, prop := "") -> void:
	var tex: Texture2D = Sprites.frames(kind)[0]
	var cycle := fmod(t + phase, ACT_CYCLE)
	var acting := act and cycle > ACT_AT
	var hop := 0.0
	if acting and ACTIONS.has(kind):
		var posed = Sprites.pose(kind, ACTIONS[kind])
		if posed != null:
			tex = posed
		if cycle - ACT_AT < 0.12:
			hop = PX   # a little lift as it goes into the action
	var sz := Vector2(tex.get_width(), tex.get_height()) * scale
	var foot := Vector2(x * PX, y * PX)
	var dir := -1.0 if flip else 1.0
	if act and kind in SPELLS:
		_spell_ground(kind, foot, cycle)
	if prop != "" and act and ACTIONS.has(kind):
		_prop(prop, x + dir * 10.0, y, acting and cycle - ACT_AT < 0.2, dir)
	draw_rect(Rect2(foot.x - sz.x * 0.3, foot.y - 4, sz.x * 0.6, 6), Color(0, 0, 0, 0.25))
	draw_set_transform(foot - Vector2(0, hop), 0.0, Vector2(dir, 1.0))
	draw_texture_rect(tex, Rect2(-sz.x / 2.0, -sz.y, sz.x, sz.y), false)
	draw_set_transform(Vector2.ZERO)
	if act and kind in SPELLS:
		_spell(kind, foot + Vector2(STAFF_TIP.x * dir, STAFF_TIP.y) * scale, cycle, phase)


## What a spell does on the ground at the caster's feet (drawn under the sprite).
func _spell_ground(kind: String, foot: Vector2, cycle: float) -> void:
	var after := (cycle - ACT_AT) / (ACT_CYCLE - ACT_AT)
	match kind:
		"frost":
			# Frost creeping out over the snow as the spell builds, and cracking away after.
			var reach := clampf(cycle / ACT_AT, 0.0, 1.0) * 9.0 if after <= 0.0 else 9.0 * (1.0 - after)
			for i in 10:
				var a := i * TAU / 10.0 + 0.2
				for r in int(reach):
					if (i + r) % 3 != 0:
						_px_at(foot + Vector2(cos(a) * (r + 2) * PX, sin(a) * (r + 2) * PX * 0.35), PX, Color(0.55, 0.8, 1.0, 0.75))
		"healer":
			if after > 0.0:
				# A ring of light spreading out over the ground.
				var r := (3.0 + after * 10.0) * PX
				for i in 16:
					var a := i * TAU / 16.0
					_px_at(foot + Vector2(cos(a) * r, sin(a) * r * 0.35), PX, Color(1.0, 0.95, 0.55, 0.9 * (1.0 - after)))


## What a worker strikes, standing at art pixel (x, y) on the striker's `dir` side; `hit`
## while the blow lands (chips, sparks, a jolt).
func _prop(kind: String, x: float, y: float, hit: bool, dir: float) -> void:
	match kind:
		"stone":
			# A cut block on a low trestle, a mason's chisel marks on its face.
			_b(x - 4, y - 3, 1, 3, Color(0.35, 0.24, 0.14))
			_b(x + 3, y - 3, 1, 3, Color(0.35, 0.24, 0.14))
			_b(x - 5, y - 4, 10, 1, Color(0.45, 0.3, 0.18))
			_b(x - 4, y - 10, 8, 6, OUTLINE)
			_b(x - 3, y - 9, 6, 5, Color(0.62, 0.58, 0.52))
			_b(x - 3, y - 9, 6, 1, Color(0.72, 0.68, 0.62))
			_b(x - 1, y - 7, 2, 1, Color(0.48, 0.44, 0.4))
			if hit:
				for k in 4:
					_b(x - dir * 3 + dir * k * 0.5, y - 10 - k, 1, 1, Color(1.0, 0.85, 0.4))
					_b(x - dir * (2 + k), y - 8 - k * 0.5, 1, 1, Color(0.75, 0.72, 0.66))
		"ore":
			# An outcrop of rock with a seam of gold.
			_b(x - 5, y - 9, 10, 9, OUTLINE)
			_b(x - 4, y - 8, 8, 8, Color(0.36, 0.3, 0.26))
			_b(x - 4, y - 8, 8, 2, Color(0.46, 0.4, 0.34))
			_b(x - 2, y - 5, 2, 1, Color(1.0, 0.8, 0.3))
			_b(x + 1, y - 3, 2, 1, Color(1.0, 0.8, 0.3))
			if hit:
				for k in 4:
					_b(x - dir * (4 + k), y - 7 - k, 1, 1, Color(1.0, 0.85, 0.35) if k % 2 == 0 else Color(0.55, 0.48, 0.4))
		"dummy":
			# A wooden training dummy, rocking back when it's struck.
			var lean := dir * (1.0 if hit else 0.0)
			_b(x - 0.5, y - 3, 1, 3, Color(0.35, 0.24, 0.14))
			_b(x - 3, y - 1, 6, 1, Color(0.35, 0.24, 0.14))
			_b(x - 2 + lean, y - 12, 4, 9, OUTLINE)
			_b(x - 1 + lean, y - 11, 2, 8, Color(0.62, 0.45, 0.26))
			_b(x - 4 + lean, y - 10, 8, 1, Color(0.5, 0.36, 0.2))
			_b(x - 1 + lean, y - 14, 2, 2, Color(0.62, 0.45, 0.26))
			if hit:
				_b(x - dir * 3, y - 9, 1, 1, Color(1, 1, 0.85))
				_b(x - dir * 4, y - 10, 1, 1, Color(1, 1, 0.85))


## A spellcaster's magic at its staff tip (screen pixels): it gathers through the loop
## and goes off at the action.
func _spell(kind: String, tip: Vector2, cycle: float, phase: float) -> void:
	var charge := clampf(cycle / ACT_AT, 0.0, 1.0)
	var after := (cycle - ACT_AT) / (ACT_CYCLE - ACT_AT)   # 0..1 once it's gone off
	var tt := t + phase
	match kind:
		"frost":
			# Ice crystals spiral in to the staff, the crystal blazes, and shards burst out.
			_px_at(tip, 8.0 + 12.0 * charge, Color(0.45, 0.8, 1.0, 0.25 + 0.25 * charge))
			_px_at(tip, 4.0 + 4.0 * charge, Color(0.9, 0.98, 1.0, 0.6 + 0.4 * charge))
			if after <= 0.0:
				for i in 5:
					var a := tt * 3.5 + i * TAU / 5.0
					var r := 26.0 * (1.0 - charge) + 8.0
					var q := tip + Vector2(cos(a), sin(a) * 0.7) * r
					_px_at(q, 8.0, Color(0.3, 0.6, 0.95, 0.85))
					_px_at(q, 4.0, Color(0.95, 1.0, 1.0))
			else:
				for i in 8:
					var dir := Vector2.from_angle(i * TAU / 8.0 + 0.4)
					var q := tip + dir * (10.0 + after * 44.0)
					_px_at(q, 8.0, Color(0.3, 0.6, 0.95, 0.9 * (1.0 - after)))
					_px_at(q - dir * 6.0, 4.0, Color(0.95, 1.0, 1.0, 1.0 - after))
		"mage":
			# An arcane orb swells at the staff, then lifts off and bursts into sparks.
			if after <= 0.0:
				var r := 4.0 + 8.0 * charge
				_px_at(tip, r * 2.0, Color(0.7, 0.4, 1.0, 0.3))
				_px_at(tip, r + 4.0, Color(0.55, 0.25, 0.85))
				_px_at(tip, r, Color(1.0, 0.85, 1.0))
			else:
				var orb := tip + Vector2(0, -after * 48.0)
				if after < 0.55:
					_px_at(orb, 24.0, Color(0.7, 0.4, 1.0, 0.3))
					_px_at(orb, 16.0, Color(0.55, 0.25, 0.85))
					_px_at(orb, 8.0, Color(1.0, 0.9, 1.0))
				else:
					for i in 8:
						var q := orb + Vector2.from_angle(i * TAU / 8.0 + 0.3) * (after - 0.55) * 80.0
						_px_at(q, 8.0, Color(0.85, 0.5, 1.0, (1.0 - after) * 2.2))
						_px_at(q, 4.0, Color(1.0, 0.9, 1.0, (1.0 - after) * 2.2))
		"healer":
			# Light gathers at the staff with motes rising, then a cross of light lifts away.
			_px_at(tip, 10.0 + 10.0 * charge, Color(1.0, 0.95, 0.6, 0.2 + 0.25 * charge))
			_px_at(tip, 4.0 + 4.0 * charge, Color(1.0, 1.0, 0.85))
			for i in 4:
				var k := fmod(tt * 0.7 + i * 0.25, 1.0)
				_px_at(tip + Vector2(sin(tt * 2.0 + i * 1.7) * 12.0, -k * 40.0), 4.0, Color(1.0, 1.0, 0.75, 0.9 * (1.0 - k)))
			if after > 0.0:
				var c := tip + Vector2(0, -16.0 - after * 24.0)
				var a := 1.0 - after
				draw_rect(Rect2(c.x - 6, c.y - 14, 12, 28), Color(1.0, 0.9, 0.4, 0.3 * a))
				draw_rect(Rect2(c.x - 14, c.y - 6, 28, 12), Color(1.0, 0.9, 0.4, 0.3 * a))
				draw_rect(Rect2(c.x - 2, c.y - 10, 4, 20), Color(1.0, 1.0, 0.8, a))
				draw_rect(Rect2(c.x - 10, c.y - 2, 20, 4), Color(1.0, 1.0, 0.8, a))


## A square of light centred on a screen point, snapped to the art grid.
func _px_at(p: Vector2, size: float, c: Color) -> void:
	var sz := maxf(PX, roundf(size / PX) * PX)
	draw_rect(Rect2(floorf((p.x - sz / 2.0) / PX) * PX, floorf((p.y - sz / 2.0) / PX) * PX, sz, sz), c)


func _walker(kind: String, x: float, y: float, phase: float, scale := 4.0) -> void:
	var frames: Array = Sprites.frames(kind)
	var tex: Texture2D = Sprites.step(frames, int((t + phase) * 6.0))
	var sz := Vector2(tex.get_width(), tex.get_height()) * scale
	var foot := Vector2(x * PX, y * PX - (1.5 - 1.5 * cos(PI * ((t + phase) * 6.0 - 0.5))) * 1.0)
	draw_texture_rect(tex, Rect2(foot.x - sz.x / 2.0, foot.y - sz.y, sz.x, sz.y), false)


# --- The beacons ----------------------------------------------------------------------

# The nine beacons of the Line (Ashwatch's and one for each of the eight peoples), hill
# to hill across the ridge.
const BEACONS := [Vector2(8, 94), Vector2(26, 82), Vector2(44, 90), Vector2(62, 78), Vector2(80, 88),
		Vector2(98, 76), Vector2(116, 86), Vector2(134, 80), Vector2(152, 90)]
const LIGHT_STEP := 0.5   # seconds between one beacon catching and the next
const DARK_STEP := 0.6    # seconds between one going out and the next


func _draw_beacons(going_dark: bool) -> void:
	var cold := 1.0 if not going_dark else clampf(t / 8.0, 0.0, 1.0)
	_sky(Color(0.05, 0.06, 0.16).lerp(Color(0.03, 0.03, 0.06), cold), Color(0.24, 0.2, 0.38).lerp(Color(0.1, 0.1, 0.16), cold), 12, 110)
	_stars()
	# The moon, and a thread of cloud across it.
	_b(26, 14, 12, 12, Color(0.95, 0.93, 0.82, 0.12))
	_b(28, 16, 8, 8, Color(0.95, 0.93, 0.82))
	_b(30, 18, 2, 2, Color(0.82, 0.8, 0.7))
	_b(33, 21, 2, 1, Color(0.82, 0.8, 0.7))
	_b(fmod(t * 2.0, GW + 30.0) - 20.0, 20, 26, 2, Color(0.3, 0.28, 0.42, 0.8))
	_ridge(92, 10, 1.0, Color(0.13, 0.13, 0.25))
	# Far-off pines along the first ridge.
	for i in 26:
		var px := i * 6 + (i * 7) % 4
		var top := 92.0 - 10.0 * (0.6 * sin(px * 0.07 + 1.0) + 0.4 * sin(px * 0.19 + 2.0))
		_b(px, top - 3, 1, 3, Color(0.1, 0.1, 0.2))
		_b(px - 1, top - 1, 3, 1, Color(0.1, 0.1, 0.2))
	# The towers, each on a hill rising out of the ridge.
	for i in BEACONS.size():
		var p: Vector2 = BEACONS[i]
		for r in range(0, 30):
			var half := 3.0 + sqrt(float(r)) * 5.5
			_b(p.x - half, p.y + 2 + r, half * 2.0, 1, Color(0.13, 0.13, 0.25))
	# A band of mist in the valley.
	for x in range(0, GW, 2):
		_b(x, 100 + 2 * sin(x * 0.1 + t * 0.3), 2, 4, Color(0.5, 0.5, 0.7, 0.12))
	_ridge(112, 10, 4.0, Color(0.09, 0.09, 0.17))
	_ridge(128, 6, 7.0, Color(0.06, 0.06, 0.11))
	for i in BEACONS.size():
		var p: Vector2 = BEACONS[i]
		var lit: bool = (t > 0.6 + i * LIGHT_STEP) if not going_dark else (t < 1.0 + i * DARK_STEP)
		# The tower: outlined stone with mortar lines, a slit window and a brazier.
		_b(p.x - 4, p.y - 13, 8, 16, OUTLINE)
		_b(p.x - 3, p.y - 12, 6, 15, Color(0.42, 0.4, 0.45))
		_b(p.x + 1, p.y - 12, 2, 15, Color(0.33, 0.31, 0.36))
		for row in range(-10, 3, 3):
			_b(p.x - 3, p.y + row, 6, 1, Color(0.3, 0.28, 0.33))
		_b(p.x - 1, p.y - 7, 1, 3, Color(1.0, 0.75, 0.35) if lit else Color(0.12, 0.11, 0.15))
		_b(p.x - 5, p.y - 15, 10, 3, OUTLINE)
		_b(p.x - 4, p.y - 14, 8, 1, Color(0.35, 0.33, 0.38))
		if lit:
			# Firelight on the stone and the ground around it.
			_b(p.x - 3, p.y - 12, 2, 15, Color(1.0, 0.6, 0.25, 0.25))
			_flame(p.x, p.y - 15, 1.0, i * 1.3)
		elif going_dark:
			# Smoke rising from the dead brazier.
			for k in 4:
				var rise := fmod(t * 6.0 + k * 5.0, 22.0)
				_b(p.x - 1 + sin(t + k) * 1.5, p.y - 17 - rise, 2, 2, Color(0.5, 0.5, 0.55, 0.5 * (1.0 - rise / 22.0)))
	# The light leaping from beacon to beacon as each one catches.
	if not going_dark:
		for i in BEACONS.size() - 1:
			var start := 0.6 + i * LIGHT_STEP
			var k := (t - start) / LIGHT_STEP
			if k > 0.0 and k < 1.0:
				var a: Vector2 = BEACONS[i] + Vector2(0, -17)
				var b: Vector2 = BEACONS[i + 1] + Vector2(0, -17)
				var p := a.lerp(b, k) + Vector2(0, -sin(k * PI) * 10.0)
				_b(p.x - 1, p.y - 1, 2, 2, Color(1, 0.85, 0.4))
				_b(p.x - 2, p.y - 2, 4, 4, Color(1, 0.7, 0.3, 0.25))


# --- The peoples ----------------------------------------------------------------------

func _draw_nation(f: String) -> void:
	var banner: Color = CD.FACTIONS[f]["color"]
	match f:
		"stonehollow":
			_sky(Color(0.42, 0.55, 0.72), Color(0.78, 0.82, 0.86))
			_cloud(fmod(20.0 + t * 2.0, GW + 30.0) - 30.0, 14, 24, Color(0.95, 0.96, 0.98))
			_cloud(fmod(100.0 + t * 1.4, GW + 30.0) - 30.0, 26, 18, Color(0.92, 0.94, 0.97))
			_peaks([[20, 62, 34], [70, 34, 48], [128, 52, 40]], Color(0.5, 0.47, 0.5), true, 104)
			# The cliff the town is cut into: blocks of stone, terraces and a stair.
			_b(0, 84, GW, 36, Color(0.47, 0.42, 0.38))
			for row in range(86, 120, 6):
				for x in range(0, GW, 2):
					if _h(x, row) < 0.7:
						_b(x, row + int(_h(row, x) * 2.0), 2, 1, Color(0.4, 0.36, 0.32))
			_speckle(0, 84, GW, 36, Color(0.53, 0.48, 0.43), 0.06)
			_b(0, 98, GW, 2, Color(0.36, 0.32, 0.29))
			for i in 9:
				_b(70 + i * 2, 100 + i * 2, 6, 2, Color(0.56, 0.5, 0.45))
			# Doorways in the rock, warm light inside; chimneys smoking above.
			for i in 6:
				var hx := 8 + i * 25
				var hy := 87 + (i % 2) * 15
				if hx > 62 and hx < 92:
					continue
				_b(hx - 1, hy - 1, 14, 11, OUTLINE)
				_b(hx, hy, 12, 10, Color(0.6, 0.55, 0.5))
				_b(hx + 4, hy + 3, 4, 7, Color(0.18, 0.12, 0.1))
				_b(hx + 5, hy + 5, 2, 5, Color(1.0, 0.7, 0.3, 0.6 + 0.2 * sin(t * 3.0 + i)))
				_b(hx + 1, hy + 2, 2, 2, Color(1.0, 0.82, 0.4))
				_b(hx + 9, hy + 2, 2, 2, Color(1.0, 0.82, 0.4))
				_b(hx + 9, hy - 4, 2, 3, Color(0.35, 0.31, 0.28))
				_smoke(hx + 10, hy - 5, i * 0.31)
			# Banners in the clan's colours.
			for bx in [36, 120]:
				_b(bx, 76, 1, 22, Color(0.3, 0.25, 0.2))
				var wave := int(t * 4.0) % 2
				_b(bx + 1, 77 + wave, 6, 8, banner)
				_b(bx + 1, 85 + wave, 3, 2, banner)
			# The street: cobbles.
			_b(0, 120, GW, 30, Color(0.42, 0.37, 0.33))
			_speckle(0, 120, GW, 30, Color(0.5, 0.45, 0.4), 0.18)
			_speckle(0, 120, GW, 30, Color(0.33, 0.29, 0.26), 0.12, 7.0)
			# The forge: an anvil glowing, a brazier beside it.
			_b(140, 117, 10, 3, Color(0.25, 0.25, 0.28))
			_b(143, 120, 4, 4, Color(0.25, 0.25, 0.28))
			_b(141, 116, 5, 1, Color(1.0, 0.55, 0.2, 0.7 + 0.3 * sin(t * 6.0)))
			_b(151, 117, 5, 6, Color(0.2, 0.18, 0.18))
			_flame(153.5, 117, 0.8, 0.5)
		"greenwood":
			_sky(Color(0.42, 0.66, 0.74), Color(0.82, 0.92, 0.78))
			_ridge(70, 6, 1.0, Color(0.5, 0.66, 0.6))
			# Shaded undergrowth under the trees, so every row stands on the forest floor.
			_b(0, 74, GW, 50, Color(0.16, 0.3, 0.18))
			for layer in 3:
				var col := Color(0.22, 0.44, 0.27).darkened(0.22 * (2 - layer))
				_b(0, 74 + layer * 18, GW, mini(50, GH - (74 + layer * 18)), Color(0.16, 0.3, 0.18).lightened(0.06 * layer))   # (not past the art's foot, into the text)
				for i in 12:
					_pine(6 + i * 14 + layer * 5, 76 + layer * 22, 16 + layer * 4 + (i * 3 + layer) % 5, col)
			# Sunbeams slanting down through the canopy.
			for i in 4:
				var bx := 18.0 + i * 38.0
				var a := 0.06 + 0.03 * sin(t * 0.8 + i)
				for row in range(30, 122, 2):
					_b(bx + (row - 30) * 0.35, row, 6, 2, Color(1.0, 0.98, 0.75, a))
			# A great tree at each side, and a walkway strung between them.
			for tx in [4, 146]:
				_b(tx, 50, 10, 72, Color(0.36, 0.24, 0.14))
				_b(tx + 2, 50, 3, 72, Color(0.45, 0.31, 0.18))
				_b(tx - 10, 34, 30, 18, Color(0.2, 0.38, 0.2))
				_b(tx - 6, 30, 22, 6, Color(0.25, 0.46, 0.24))
				_speckle(tx - 10, 30, 30, 22, Color(0.32, 0.55, 0.28), 0.25)
			for x in range(14, 146, 2):
				var sag := 62.0 + 5.0 * sin((x - 14) / 132.0 * PI)
				_b(x, sag, 2, 1, Color(0.42, 0.3, 0.18))
				if x % 6 == 0:
					_b(x, sag - 4, 1, 4, Color(0.35, 0.25, 0.15))
			# The forest floor: grass, ferns, mushrooms and flowers.
			_b(0, 122, GW, 28, Color(0.3, 0.5, 0.24))
			_speckle(0, 122, GW, 28, Color(0.38, 0.6, 0.28), 0.2)
			_speckle(0, 122, GW, 28, Color(0.22, 0.4, 0.18), 0.12, 3.0)
			for i in 7:
				var fx := 10 + i * 22 + (i * 7) % 9
				_b(fx, 120, 1, 3, Color(0.3, 0.55, 0.25))
				_b(fx - 2, 121, 2, 1, Color(0.3, 0.55, 0.25))
				_b(fx + 1, 121, 2, 1, Color(0.3, 0.55, 0.25))
			for mx in [28, 98, 134]:
				_b(mx, 143, 1, 2, Color(0.9, 0.88, 0.8))
				_b(mx - 1, 142, 3, 1, Color(0.8, 0.25, 0.2))
			_speckle(0, 124, GW, 26, Color(0.95, 0.85, 0.4), 0.01, 11.0)
			# Fireflies drifting through the trees.
			for k in 10:
				_b(fmod(k * 37.0 + t * 4.0 * (1 + k % 3), GW), 80 + 25 * sin(t * 0.8 + k), 1, 1, Color(1, 1, 0.6, 0.5 + 0.5 * sin(t * 3.0 + k)))
		"deepdelve":
			_sky(Color(0.1, 0.08, 0.07), Color(0.24, 0.18, 0.14))
			# Rock: strata, rubble and glinting veins of ore.
			for row in range(4, 124, 9):
				_b(0, row, GW, 1, Color(0.17, 0.13, 0.11))
			_speckle(0, 0, GW, 124, Color(0.2, 0.15, 0.12), 0.06)
			_speckle(0, 0, GW, 124, Color(0.26, 0.2, 0.16), 0.02, 9.0)
			for i in 12:
				var gx := _h(i, 1.0) * GW
				var gy := 6.0 + _h(i, 2.0) * 100.0
				var tw := 0.5 + 0.5 * sin(t * 3.0 + i * 1.9)
				_b(gx, gy, 1, 1, Color(1.0, 0.85, 0.35, tw) if i % 3 else Color(0.5, 0.85, 1.0, tw))
			# Stalactites along the roof.
			for i in 16:
				var sx := i * 10 + (i * 3) % 5
				var sl := 3 + (i * 5) % 7
				for r in sl:
					_b(sx + r / 3, r, maxf(1.0, 3.0 - r / 2.0), 1, Color(0.22, 0.17, 0.14))
			# The mine mouth, timbered, with the forge glowing inside.
			_b(46, 40, 68, 84, Color(0.2, 0.15, 0.12))
			_b(54, 56, 52, 68, Color(0.06, 0.04, 0.04))
			var glow := 0.7 + 0.3 * sin(t * 4.0)
			_b(62, 90, 36, 34, Color(1.0, 0.45, 0.1, 0.35 * glow))
			_b(70, 104, 20, 20, Color(1.0, 0.6, 0.2, 0.5 * glow))
			_b(76, 112, 8, 4, Color(1.0, 0.85, 0.45, 0.7 * glow))
			for x in [50, 104]:
				_b(x, 52, 6, 72, Color(0.45, 0.3, 0.16))
				_b(x + 1, 52, 1, 72, Color(0.55, 0.38, 0.2))
				for by in [60, 90, 116]:
					_b(x + 2, by, 2, 2, Color(0.6, 0.6, 0.65))
			_b(48, 48, 64, 6, Color(0.5, 0.33, 0.18))
			_b(48, 48, 64, 1, Color(0.6, 0.42, 0.24))
			# Lanterns hanging from the beam.
			for lx in [58, 100]:
				_b(lx, 54, 1, 4, Color(0.3, 0.3, 0.3))
				var fl := 0.75 + 0.25 * sin(t * 9.0 + lx)
				_b(lx - 4, 56, 9, 9, Color(1.0, 0.7, 0.3, 0.12 * fl))
				_b(lx - 1, 58, 3, 4, Color(1.0, 0.8, 0.35, fl))
			# Crates of powder by the entrance.
			_b(20, 112, 12, 10, OUTLINE)
			_b(21, 113, 10, 8, Color(0.5, 0.35, 0.2))
			_b(21, 116, 10, 1, Color(0.38, 0.26, 0.15))
			_b(24, 104, 8, 8, OUTLINE)
			_b(25, 105, 6, 6, Color(0.55, 0.38, 0.22))
			_b(0, 124, GW, 26, Color(0.28, 0.22, 0.18))
			_speckle(0, 124, GW, 26, Color(0.34, 0.27, 0.22), 0.15)
			# Rails on sleepers.
			for x in range(0, GW, 6):
				_b(x, 127, 3, 7, Color(0.38, 0.27, 0.18))
			_b(0, 128, GW, 1, Color(0.6, 0.6, 0.66))
			_b(0, 132, GW, 1, Color(0.6, 0.6, 0.66))
			# (The cart itself rolls by among the miners: see _minecart.)
		"mercyvale":
			_sky(Color(0.95, 0.72, 0.52), Color(1.0, 0.93, 0.8))
			# The low sun, its rays turning slowly.
			_b(24, 30, 10, 10, Color(1.0, 0.95, 0.75))
			_b(26, 28, 6, 14, Color(1.0, 0.95, 0.75))
			_b(22, 32, 14, 6, Color(1.0, 0.95, 0.75))
			for i in 8:
				var a := i * TAU / 8.0 + t * 0.15
				for r in range(10, 16, 2):
					_b(29 + cos(a) * r, 35 + sin(a) * r, 1, 1, Color(1.0, 0.95, 0.7, 0.6))
			_birds(22, 4, 6.0)
			_ridge(92, 5, 1.5, Color(0.62, 0.75, 0.5))
			_ridge(100, 6, 3.0, Color(0.52, 0.68, 0.4))
			# The shrine: white walls, columns, a gold dome and a bell.
			_b(63, 69, 34, 32, OUTLINE)
			_b(64, 70, 32, 30, Color(0.96, 0.95, 0.9))
			for cx in [66, 72, 86, 92]:
				_b(cx, 74, 2, 26, Color(0.85, 0.83, 0.78))
			_b(62, 68, 36, 3, Color(0.88, 0.86, 0.8))
			_b(71, 60, 18, 8, Color(0.95, 0.78, 0.3))
			_b(73, 56, 14, 4, Color(0.95, 0.78, 0.3))
			_b(76, 52, 8, 4, Color(1.0, 0.85, 0.4))
			_b(72, 60, 3, 6, Color(1.0, 0.9, 0.55))
			_b(79, 46, 2, 6, Color(1, 0.95, 0.7))
			_b(77, 48, 6, 1, Color(1, 0.95, 0.7))
			_b(76, 84, 8, 16, Color(0.55, 0.4, 0.28))
			_b(77, 85, 6, 2, Color(1.0, 0.85, 0.5, 0.6 + 0.3 * sin(t * 2.0)))
			for i in 4:
				_b(72 - i * 2, 100 + i * 2, 16 + i * 4, 2, Color(0.88, 0.86, 0.8))
			# The hospice halls either side.
			_house(14, 86, 24, 14, Color(0.93, 0.9, 0.82), Color(0.6, 0.72, 0.5))
			_house(122, 86, 24, 14, Color(0.93, 0.9, 0.82), Color(0.6, 0.72, 0.5))
			# Gardens: rows of herbs and flowers, and the path up.
			_b(0, 108, GW, 42, Color(0.45, 0.62, 0.35))
			_b(72, 108, 16, 42, Color(0.8, 0.72, 0.58))
			_speckle(72, 108, 16, 42, Color(0.7, 0.62, 0.5), 0.15)
			for row in range(112, 120, 3):
				for x in range(4, 68, 3):
					_b(x, row, 2, 2, Color(0.35, 0.55, 0.3))
					if _h(x, row) < 0.4:
						_b(x, row, 1, 1, [Color(0.95, 0.5, 0.6), Color(1.0, 0.9, 0.4), Color(0.7, 0.6, 1.0)][int(_h(row, x) * 3.0)])
				for x in range(92, 158, 3):
					_b(x, row, 2, 2, Color(0.35, 0.55, 0.3))
					if _h(x, row) < 0.4:
						_b(x, row, 1, 1, [Color(0.95, 0.5, 0.6), Color(1.0, 0.9, 0.4), Color(0.7, 0.6, 1.0)][int(_h(row, x) * 3.0)])
			_speckle(0, 122, GW, 28, Color(0.53, 0.7, 0.4), 0.15)
			# Motes of healing light rising.
			for k in 12:
				var rise := fmod(t * 8.0 + k * 9.0, 60.0)
				_b(20 + k * 11, 118 - rise, 1, 1, Color(1, 1, 0.7, 1.0 - rise / 60.0))
		"frostmarch":
			_sky(Color(0.12, 0.2, 0.38), Color(0.55, 0.68, 0.85))
			# The northern lights rippling over the peaks.
			for band in 2:
				var col := Color(0.4, 1.0, 0.7) if band == 0 else Color(0.5, 0.75, 1.0)
				for x in range(0, GW, 2):
					var y := 16.0 + band * 10.0 + 6.0 * sin(x * 0.05 + t * 0.7 + band * 2.0)
					var a := (0.18 + 0.12 * sin(x * 0.11 + t * 1.3 + band)) * (1.0 if band == 0 else 0.8)
					_b(x, y, 2, 10, Color(col, a))
					_b(x, y + 3, 2, 4, Color(col, a))
			_stars()
			_peaks([[15, 52, 32], [60, 32, 42], [110, 46, 40], [150, 60, 26]], Color(0.68, 0.75, 0.88), true, 110)
			_ridge(104, 5, 5.0, Color(0.86, 0.91, 0.97))
			for i in 9:
				_pine(6 + i * 19 + (i * 5) % 7, 112 + (i % 3) * 2, 14 + (i * 3) % 6, Color(0.2, 0.35, 0.32), true)
			# A longhouse with a steep roof, a lit window and smoke.
			_b(96, 100, 30, 14, OUTLINE)
			_b(97, 101, 28, 13, Color(0.45, 0.32, 0.22))
			for i in 7:
				_b(95 + i * 2, 99 - i * 2, 32 - i * 4, 2, Color(0.95, 0.97, 1.0) if i % 2 == 0 else Color(0.85, 0.9, 0.96))
			_b(102, 105, 4, 3, Color(1.0, 0.8, 0.4))
			_b(116, 105, 4, 3, Color(1.0, 0.8, 0.4))
			_b(109, 106, 4, 8, Color(0.25, 0.17, 0.12))
			_b(120, 88, 2, 6, Color(0.35, 0.28, 0.24))
			_smoke(121, 87, 0.0, Color(0.85, 0.88, 0.92))
			# Snowfields, a frozen lake glinting, and the trodden path the witches stand on.
			_b(0, 114, GW, 36, Color(0.93, 0.95, 1.0))
			_b(0, 124, GW, 18, Color(0.76, 0.84, 0.94))
			_speckle(0, 124, GW, 18, Color(0.68, 0.76, 0.88), 0.18)
			_speckle(0, 114, GW, 36, Color(1, 1, 1), 0.05, 5.0)
			for i in snow.size():
				var p: Vector2 = snow[i]
				_b(fmod(p.x + sin(t + i) * 3.0, GW), fmod(p.y + t * (10.0 + i % 5 * 2.0), GH), 1, 1, Color(1, 1, 1, 0.9))
		"freecities":
			_sky(Color(0.92, 0.5, 0.38), Color(1.0, 0.83, 0.56))
			# The harbour behind the town: water and the masts of ships.
			_b(0, 70, GW, 12, Color(0.35, 0.5, 0.65))
			for x in range(0, GW, 5):
				_b(x + int(t * 3.0) % 5, 73 + (x / 5) % 3 * 3, 2, 1, Color(0.6, 0.75, 0.85))
			for mx in [22, 60, 138]:
				_b(mx, 46, 1, 26, Color(0.35, 0.25, 0.2))
				_b(mx - 6, 50, 6, 8, Color(0.95, 0.92, 0.85))
				_b(mx + 1, 52, 5, 6, Color(0.92, 0.88, 0.8))
				_b(mx - 8, 70, 18, 3, Color(0.4, 0.28, 0.2))
			# A bell tower with a pennant.
			_b(94, 30, 14, 50, OUTLINE)
			_b(95, 31, 12, 49, Color(0.88, 0.8, 0.66))
			_b(98, 38, 6, 7, Color(0.3, 0.22, 0.18))
			_b(100, 40, 2, 3, Color(0.95, 0.8, 0.35))
			for i in 4:
				_b(93 + i * 2, 29 - i * 2, 16 - i * 4, 2, Color(0.75, 0.3, 0.3))
			_b(100, 14, 1, 8, Color(0.3, 0.25, 0.2))
			_b(101, 14 + int(t * 3.0) % 2, 6, 3, banner)
			# Rooftops: timbered houses with windows and doors.
			var roofs := [Color(0.75, 0.3, 0.3), Color(0.35, 0.45, 0.7), Color(0.85, 0.6, 0.25), Color(0.55, 0.3, 0.55)]
			for i in 9:
				var hx := i * 18 - 4
				var hh := 26 + (i * 7) % 14
				var top := 112 - hh
				_b(hx - 1, top - 1, 18, hh + 1, OUTLINE)
				_b(hx, top, 16, hh, Color(0.92, 0.85, 0.72))
				_b(hx, top + 6, 16, 1, Color(0.5, 0.35, 0.22))
				_b(hx + 7, top, 1, hh, Color(0.5, 0.35, 0.22))
				_b(hx - 1, top - 4, 18, 5, roofs[i % roofs.size()])
				_b(hx + 1, top - 6, 14, 2, roofs[i % roofs.size()].darkened(0.15))
				for wy in range(top + 9, 104, 7):
					_b(hx + 2, wy, 3, 3, Color(1, 0.85, 0.45) if _h(i, wy) < 0.6 else Color(0.4, 0.32, 0.3))
					_b(hx + 10, wy, 3, 3, Color(1, 0.85, 0.45) if _h(wy, i) < 0.6 else Color(0.4, 0.32, 0.3))
				_b(hx + 9, 105, 4, 7, Color(0.42, 0.28, 0.18))
			# Bunting with lanterns between the eaves.
			for x in range(0, GW, 4):
				var sag := 54.0 + 6.0 * sin(x / float(GW) * PI * 3.0)
				_b(x, sag, 1, 1, Color(0.3, 0.25, 0.2))
				if x % 8 == 0:
					_b(x, sag + 1, 2, 3, roofs[(x / 8) % roofs.size()].lightened(0.2))
				if x % 24 == 12:
					_b(x - 1, sag + 1, 3, 4, Color(1.0, 0.75, 0.3, 0.75 + 0.25 * sin(t * 4.0 + x)))
			# Market stalls with striped awnings, and the cobbled square.
			for sx in [6, 126]:
				for i in 7:
					_b(sx + i * 4, 104, 4, 4, Color(0.95, 0.92, 0.85) if i % 2 else banner)
				_b(sx + 1, 108, 1, 10, Color(0.4, 0.28, 0.18))
				_b(sx + 26, 108, 1, 10, Color(0.4, 0.28, 0.18))
				_b(sx + 2, 113, 24, 5, Color(0.55, 0.38, 0.22))
				for i in 5:
					_b(sx + 4 + i * 4, 112, 2, 1, [Color(0.95, 0.4, 0.3), Color(1.0, 0.8, 0.3), Color(0.5, 0.8, 0.3)][i % 3])
			_b(0, 118, GW, 32, Color(0.6, 0.5, 0.42))
			for row in range(120, 150, 3):
				for x in range(((row / 3) % 2) * 2, GW, 5):
					_b(x, row, 4, 2, Color(0.66, 0.56, 0.47))
			_birds(24, 3, 5.0)
		"monastery":
			_sky(Color(0.92, 0.58, 0.55), Color(1.0, 0.86, 0.66))
			_peaks([[20, 60, 30], [140, 54, 34]], Color(0.68, 0.58, 0.62), false, 118)
			_peaks([[80, 20, 52]], Color(0.56, 0.46, 0.5), false, 118)
			# Stairs zigzagging up the mountain.
			for i in 40:
				var sy := 114.0 - i * 2.0
				var k := sy / 114.0
				var sx := 80.0 + sin(i * 0.45) * 10.0 * k
				_b(sx - 2, sy, 5, 1, Color(0.85, 0.76, 0.68))
				_b(sx - 2, sy + 1, 5, 1, Color(0.45, 0.36, 0.4))
			# The monastery on the peak: tiers with upturned eaves.
			_b(72, 20, 16, 14, Color(0.75, 0.25, 0.2))
			_b(68, 18, 24, 3, Color(0.3, 0.2, 0.2))
			_b(66, 17, 2, 2, Color(0.3, 0.2, 0.2))
			_b(92, 17, 2, 2, Color(0.3, 0.2, 0.2))
			_b(74, 10, 12, 8, Color(0.75, 0.25, 0.2))
			_b(71, 8, 18, 3, Color(0.3, 0.2, 0.2))
			_b(69, 7, 2, 2, Color(0.3, 0.2, 0.2))
			_b(89, 7, 2, 2, Color(0.3, 0.2, 0.2))
			_b(79, 3, 2, 5, Color(0.95, 0.8, 0.35))
			_b(77, 24, 6, 10, Color(0.35, 0.18, 0.15))
			_b(78, 25, 4, 3, Color(1.0, 0.8, 0.4, 0.7))
			# Prayer flags strung down from the roof, fluttering.
			var flags := [Color(0.95, 0.35, 0.3), Color(0.95, 0.85, 0.35), Color(0.35, 0.65, 0.95), Color(0.4, 0.8, 0.45), Color(0.98, 0.98, 0.95)]
			for i in 14:
				var fx := 92 + i * 4
				var fy := 19 + i * 3.2
				_b(fx, fy, 4, 1, Color(0.4, 0.3, 0.25))
				_b(fx + 1, fy + 1 + int(t * 5.0 + i) % 2, 2, 3, flags[i % flags.size()])
			for k in 4:
				var cx := fmod(k * 50.0 + t * 5.0, GW + 40.0) - 30.0
				_cloud(cx, 58 + k * 9, 30, Color(1, 0.95, 0.92, 0.85))
			# Pines on the lower slopes, a blossom tree in front, stone lanterns.
			for i in 6:
				_pine(6 + i * 9, 116, 10 + (i * 3) % 5, Color(0.25, 0.4, 0.3))
				_pine(110 + i * 9, 116, 10 + (i * 5) % 5, Color(0.25, 0.4, 0.3))
			_b(0, 116, GW, 34, Color(0.52, 0.44, 0.44))
			_speckle(0, 116, GW, 34, Color(0.6, 0.52, 0.5), 0.12)
			_b(138, 84, 4, 34, Color(0.35, 0.22, 0.18))
			_b(130, 92, 8, 2, Color(0.35, 0.22, 0.18))
			for c in [[132, 76, 9], [144, 74, 10], [138, 68, 9], [126, 80, 6], [150, 80, 6]]:
				for row in range(-c[2], c[2] + 1):
					var hw := sqrt(float(c[2] * c[2] - row * row))
					_b(c[0] - hw, c[1] + row, hw * 2.0, 1, Color(0.98, 0.72, 0.8))
			for c in [[136, 66, 5], [146, 70, 4]]:
				for row in range(-c[2], c[2] + 1):
					var hw := sqrt(float(c[2] * c[2] - row * row))
					_b(c[0] - hw, c[1] + row, hw * 2.0, 1, Color(1.0, 0.84, 0.9))
			for lx in [14, 54, 104]:
				_b(lx, 108, 6, 2, Color(0.6, 0.58, 0.55))
				_b(lx + 1, 110, 4, 3, Color(0.7, 0.68, 0.62))
				_b(lx + 2, 111, 2, 1, Color(1.0, 0.8, 0.4, 0.8))
				_b(lx + 2, 113, 2, 4, Color(0.6, 0.58, 0.55))
			for k in 10:
				var fall := fmod(t * 9.0 + k * 13.0, 90.0)
				_b(fmod(118.0 + k * 13.0 + sin(t + k) * 6.0 - fall * 0.6, GW), 60 + fall, 1, 1, Color(1, 0.75, 0.85))
		"spires":
			_sky(Color(0.05, 0.03, 0.14), Color(0.26, 0.15, 0.42))
			# A band of starry mist across the sky.
			for x in range(0, GW, 2):
				_b(x, 30 + 8 * sin(x * 0.04), 2, 10, Color(0.6, 0.4, 0.9, 0.08 + 0.04 * sin(x * 0.2 + t)))
			_stars()
			_b(120, 10, 14, 14, Color(0.95, 0.95, 0.85, 0.15))
			_b(122, 12, 10, 10, Color(0.95, 0.95, 0.85))
			_b(125, 15, 2, 2, Color(0.82, 0.82, 0.74))
			_b(128, 18, 2, 1, Color(0.82, 0.82, 0.74))
			# Rocks floating over the city, bobbing.
			for i in 3:
				var fx := 26.0 + i * 52.0
				var fy := 44.0 + i * 7.0 + sin(t * 0.9 + i * 2.0) * 2.0
				_b(fx, fy, 12, 3, Color(0.35, 0.28, 0.45))
				_b(fx + 2, fy + 3, 8, 2, Color(0.28, 0.22, 0.36))
				_b(fx + 4, fy + 5, 4, 2, Color(0.22, 0.17, 0.3))
				_b(fx + 1, fy - 1, 10, 1, Color(0.35, 0.6, 0.4))
			# Crystal spires: a lit facet, a shadowed facet, a bright edge and a glowing tip.
			for i in 5:
				var sx := 14 + i * 32
				var sh := 50 + (i * 17) % 34
				_b(sx - 1, 119 - sh, 12, sh + 1, Color(0.18, 0.1, 0.3))
				_b(sx, 120 - sh, 5, sh, Color(0.55, 0.42, 0.82))
				_b(sx + 5, 120 - sh, 5, sh, Color(0.38, 0.26, 0.62))
				_b(sx + 4, 120 - sh, 1, sh, Color(0.85, 0.75, 1.0))
				for wy in range(124 - sh, 116, 9):
					_b(sx + 2, wy, 2, 3, Color(1.0, 0.85, 0.55, 0.85))
				_b(sx + 2, 116 - sh, 6, 4, Color(0.6, 0.45, 0.85))
				_b(sx + 3, 112 - sh, 4, 4, Color(0.8, 0.65, 1.0))
				var pulse := 0.5 + 0.5 * sin(t * 2.5 + i)
				_b(sx + 4, 108 - sh, 2, 4, Color(1, 0.9, 1.0, pulse))
				_b(sx + 1, 106 - sh, 8, 8, Color(0.85, 0.6, 1.0, 0.15 * pulse))
			_b(0, 120, GW, 30, Color(0.18, 0.12, 0.28))
			_speckle(0, 120, GW, 30, Color(0.24, 0.17, 0.36), 0.15)
			# A ring of runes in the plaza, glowing in turn.
			for i in 12:
				var a := i * TAU / 12.0
				var rp := Vector2(80 + cos(a) * 36.0, 138 + sin(a) * 6.0)
				var on := 0.3 + 0.7 * maxf(0.0, sin(t * 2.0 - i * 0.6))
				_b(rp.x, rp.y, 2, 1, Color(0.75, 0.55, 1.0, on))
			for k in 14:
				_b(fmod(k * 41.0, GW), fmod(110.0 - t * (4.0 + k % 4) - k * 9.0, 110.0), 1, 1, Color(0.85, 0.7, 1.0, 0.7))
	if f == "deepdelve":
		_draw_gun_crew()
	# The folk, at work (on something: hammers ring on stone, picks bite ore, fists land
	# on a training dummy).
	if f == "greenwood":
		_draw_archery()
		return
	var folk: Array = CD.FACTIONS[f]["folk"]
	var prop: String = {"stonehollow": "stone", "deepdelve": "ore", "monastery": "dummy"}.get(f, "")
	for i in folk.size():
		_figure(folk[i], 40 + i * 40, 128 + (i % 2) * 6, i * 0.53, i == 2, 4.0, true, prop)
		if f == "deepdelve" and i == 0:
			_minecart()   # in front of the miner on the rails, behind the one nearer us


## Deepdelve's cart of ore, rolling along the rails.
func _minecart() -> void:
	var cx := fmod(t * 14.0, GW + 30.0) - 20.0
	_b(cx - 1, 119, 18, 10, OUTLINE)
	_b(cx, 120, 16, 8, Color(0.35, 0.3, 0.3))
	_b(cx, 122, 16, 1, Color(0.45, 0.4, 0.4))
	_b(cx + 2, 117, 12, 4, Color(0.95, 0.75, 0.25))
	_b(cx + 4, 116, 3, 2, Color(1.0, 0.9, 0.5))
	_b(cx + 2, 128, 3, 3, OUTLINE)
	_b(cx + 11, 128, 3, 3, OUTLINE)


## Greenwood's archers at the butts: the two at the sides shoot at targets by the forest
## edge (each loose sinks an arrow in its target), the one in the middle stands easy,
## twirling an arrow as she does between waves.
func _draw_archery() -> void:
	var shooters := [[40.0, 12.0, 0.0], [120.0, 148.0, 0.8]]   # x, target x, phase
	for sh in shooters:
		_target(sh[1], 128.0)
	for sh in shooters:
		var x: float = sh[0]
		var tx: float = sh[1]
		var dir := signf(tx - x)
		var cycle := fmod(t + sh[2], ACT_CYCLE)
		_figure("archer", x, 128, sh[2], dir < 0.0)
		# The arrow: in flight just after the loose, then stuck in the target.
		var from := Vector2(x + dir * 7.0, 119.0)
		var to := Vector2(tx - dir * 1.0, 117.0)
		if cycle < 0.22 and t > 0.3:
			var k := cycle / 0.22
			_arrow_at(from.lerp(to, k) + Vector2(0, -sin(k * PI) * 2.0), dir)
		elif t > 0.3:
			_arrow_at(to, dir, true)
	# The middle archer at ease: a slow sway, an arrow drawn, then twirled and flipped on and on.
	var sway := 1.0 if fmod(t * 0.6, 2.0) < 1.0 else 0.0
	_figure("archer", 80 + sway * 0.25, 134, 0.0, false, 4.0, false)
	_idle_arrow(Vector2((80 + sway * 0.25) * PX, 134 * PX))


## An archery target on a stand, its foot at art pixel (x, y).
func _target(x: float, y: float) -> void:
	for k in 9:
		_b(x - 3 + k * 0.3, y - k, 1, 1, Color(0.42, 0.28, 0.15))
		_b(x + 3 - k * 0.3, y - k, 1, 1, Color(0.42, 0.28, 0.15))
	var rings := [[6.4, OUTLINE], [5.4, Color(0.95, 0.93, 0.86)], [4.2, Color(0.85, 0.2, 0.2)], [2.9, Color(0.95, 0.93, 0.86)], [1.5, Color(0.85, 0.2, 0.2)]]
	var cx := int(x)
	for ring in rings:
		var r: float = ring[0]
		for row in range(-int(r), int(r) + 1):
			var hw := int(round(sqrt(maxf(r * r - row * row, 0.0))))
			_b(cx - hw, y - 12 + row, hw * 2 + 1, 1, ring[1])


## An arrow (art pixels), flying along `dir` or (stuck) with its fletching sticking out.
func _arrow_at(p: Vector2, dir: float, stuck := false) -> void:
	var back := 3.0 if stuck else 4.0
	for k in int(back):
		_b(p.x - dir * k, p.y, 1, 1, Color(0.6, 0.42, 0.22))
	_b(p.x - dir * back, p.y - 1, 1, 1, Color(0.95, 0.95, 0.95))
	_b(p.x - dir * back, p.y + 1, 1, 1, Color(0.95, 0.95, 0.95))
	if not stuck:
		_b(p.x + dir, p.y, 1, 1, Color(0.75, 0.78, 0.82))


## The idle archer's arrow, as in battle: out of the quiver, then twirled three times,
## flipped end over end and caught, one lazy turn, and round again (she never moves off,
## so it never goes back). `foot` in screen pixels.
func _idle_arrow(foot: Vector2) -> void:
	var c := t + 0.4
	var hand := foot + Vector2(10, -26)
	var quiver := foot + Vector2(-10, -44)
	var lifted := quiver + Vector2(0, -16)
	var up := -PI / 2.0
	var pos: Vector2
	var ang: float
	if c < 0.5:
		var k := smoothstep(0.0, 1.0, c / 0.5)
		pos = quiver.lerp(lifted, k)
		ang = up
	elif c < 0.9:
		var k := smoothstep(0.0, 1.0, (c - 0.5) / 0.4)
		pos = lifted.lerp(hand, k)
		ang = lerp_angle(up, 0.0, k)
	else:
		var u := fmod(c - 0.9, 3.3)
		if u < 1.5:
			pos = hand
			ang = smoothstep(0.0, 1.0, u / 1.5) * TAU * 3.0
		elif u < 2.3:
			var k := (u - 1.5) / 0.8
			pos = hand + Vector2(0, -sin(PI * k) * 40.0)
			ang = smoothstep(0.0, 1.0, k) * TAU * 2.0
		else:
			pos = hand
			ang = smoothstep(0.0, 1.0, (u - 2.3) / 1.0) * TAU
	var d := Vector2.from_angle(ang)
	draw_line(pos - d * 14.0, pos + d * 12.0, OUTLINE, 5.0)
	draw_line(pos - d * 13.0, pos + d * 11.0, Color(0.62, 0.44, 0.24), 3.0)
	draw_line(pos + d * 10.0, pos + d * 15.0, Color(0.78, 0.8, 0.85), 4.0)
	var n := d.orthogonal()
	draw_line(pos - d * 14.0, pos - d * 9.0 + n * 4.0, Color(0.95, 0.95, 0.95), 2.0)
	draw_line(pos - d * 14.0, pos - d * 9.0 - n * 4.0, Color(0.95, 0.95, 0.95), 2.0)


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


## Mountains as [x, top, half-width]: lit on the left, shaded on the right, with a few
## rock seams, and (snowy) white caps with blue shadow.
func _peaks(list: Array, col: Color, snowy: bool, base := 120) -> void:
	for m in list:
		var x: float = m[0]
		var top: float = m[1]
		var half: float = m[2]
		for row in range(int(top), base):
			var w := (row - top) / (base - top) * half
			var lit := col if row < top + 0.35 * (base - top) or not snowy else col.darkened(0.08)
			# The lit half runs a pixel past the middle so rounding never leaves a gap.
			_b(x - w, row, w + 2.0, 1, lit)
			_b(x + 1.0, row, w, 1, lit.darkened(0.16))
			if snowy and row < top + (base - top) * 0.22:
				_b(x - w, row, w + 2.0, 1, Color(0.97, 0.98, 1.0))
				_b(x + 1.0, row, w, 1, Color(0.8, 0.86, 0.96))


## A pine: tiers of boughs, lit on the left; snowy ones carry snow on each tier.
func _pine(x: float, base: float, h: float, col: Color, snowy := false) -> void:
	for row in int(h):
		var w := (row % 4 + 2 + row * 0.25) * 0.55
		_b(x - w, base - h + row, w + 2.0, 1, col.lightened(0.08))
		_b(x + 1.0, base - h + row, w, 1, col.darkened(0.12))
		if snowy and row % 4 == 0 and row > 0:
			_b(x - w + 1.0, base - h + row, w * 1.4, 1, Color(0.95, 0.97, 1.0))
	_b(x, base, 1, 3, Color(0.3, 0.2, 0.12))


## A steady pseudo-random 0..1 for an art pixel (for textures that don't crawl).
func _h(x: float, y: float) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)


## Scattered single pixels over a block: pebbles, grass, flowers, glints. The pattern
## never changes, so where the pixels go is worked out once and kept.
var _speckles := {}


func _speckle(x0: int, y0: int, w: int, h: int, col: Color, density: float, salt := 0.0) -> void:
	var key := Vector4(x0 * 1000 + y0, w * 1000 + h, density, salt)
	var pts = _speckles.get(key)
	if pts == null:
		pts = PackedVector2Array()
		for yy in range(y0, y0 + h):
			for xx in range(x0, x0 + w):
				if _h(xx + salt, yy) < density:
					pts.append(Vector2(xx * PX, yy * PX))
		_speckles[key] = pts
	for q in pts:
		draw_rect(Rect2(q, Vector2(PX, PX)), col)


## Stonework: mortar lines every three rows and staggered joints.
func _bricks(x0: int, y0: int, w: int, h: int, col: Color) -> void:
	var mortar := col.darkened(0.2)
	for row in range(0, h, 3):
		_b(x0, y0 + row, w, 1, mortar)
		for jx in range(((row / 3) % 2) * 3, w, 6):
			_b(x0 + jx, y0 + row + 1, 1, 2, mortar)


## Smoke curling up from (x, y).
func _smoke(x: float, y: float, phase: float, col := Color(0.62, 0.6, 0.62)) -> void:
	# Overlapping puffs that swell and thin out as they drift up and away, so it reads
	# as a plume rather than a dotted line.
	for k in 10:
		var age := fmod(t * 0.35 + k * 0.1 + phase, 1.0)
		var r := 2.0 + age * 5.0
		var c := Vector2(x + sin(age * 4.0 + phase) * 1.5 + age * 6.0, y - age * 18.0)
		_b(c.x - r / 2.0, c.y - r / 2.0, r, r, Color(col, 0.32 * (1.0 - age)))
		_b(c.x - r / 4.0, c.y - r / 4.0, r / 2.0, r / 2.0, Color(col.lightened(0.1), 0.25 * (1.0 - age)))


func _cloud(x: float, y: float, w: float, col: Color) -> void:
	_b(x, y + 2, w, 3, col)
	_b(x + 2, y, w * 0.55, 3, col)
	_b(x + w * 0.45, y + 1, w * 0.4, 2, col)
	_b(x + 1, y + 5, w - 2, 1, col.darkened(0.12))


## A small house: outlined walls, a stepped roof, a door and a lit window.
func _house(x: float, y: float, w: float, h: float, wall: Color, roof: Color, lit := true) -> void:
	_b(x - 1, y - 1, w + 2, h + 1, OUTLINE)
	_b(x, y, w, h, wall)
	_b(x + w - 2, y, 2, h, wall.darkened(0.12))
	for i in 3:
		_b(x - 2 + i * 2, y - 2 - i * 2, w + 4 - i * 4, 2, roof.darkened(0.1 * i))
	_b(x + 2, y + h - 5, 3, 5, wall.darkened(0.45))
	_b(x + w - 6, y + 2, 3, 3, Color(1.0, 0.82, 0.4) if lit else wall.darkened(0.3))


## A flock of two-pixel birds crossing the sky.
func _birds(y: float, n: int, speed: float) -> void:
	for i in n:
		var bx := fmod(i * 23.0 + t * speed, GW + 20.0) - 10.0
		var by := y + i * 3.0 + sin(t * 2.0 + i) * 1.5
		var flap := int(t * 6.0 + i) % 2
		_b(bx, by + flap, 1, 1, Color(0.2, 0.18, 0.22))
		_b(bx + 1, by + 1 - flap, 1, 1, Color(0.2, 0.18, 0.22))
		_b(bx + 2, by + flap, 1, 1, Color(0.2, 0.18, 0.22))


# --- The horde, Ashwatch, the title ----------------------------------------------------

func _draw_horde() -> void:
	_sky(Color(0.3, 0.06, 0.06), Color(0.85, 0.35, 0.12))
	# A burning village on the skyline.
	for i in 7:
		var hx := 8 + i * 22
		_b(hx, 84, 14, 16, Color(0.12, 0.06, 0.06))
		_b(hx + 2, 78, 10, 6, Color(0.12, 0.06, 0.06))
		_b(hx + 3, 88, 2, 3, Color(1.0, 0.55, 0.2, 0.7) if i % 2 == 0 else Color(0.08, 0.04, 0.04))
		if i % 2 == 0:
			_flame(hx + 7, 80, 1.6, i)
			# A column of smoke leaning off on the wind.
			for k in 20:
				var age := fmod(t * 0.3 + k / 20.0 + i * 0.13, 1.0)
				var r := 4.0 + age * 10.0
				_b(hx + 7 + age * 18.0 - r / 2.0, 74 - age * 60.0, r, r, Color(0.18, 0.1, 0.1, 0.55 * (1.0 - age)))
	_ridge(102, 3, 9.0, Color(0.16, 0.08, 0.07))
	# Embers swirling up from the fires.
	for k in 12:
		var age := fmod(t * 0.5 + k * 0.083, 1.0)
		_b(10 + k * 13 + sin(t * 2.0 + k) * 4.0, 96 - age * 70.0, 1, 1, Color(1.0, 0.7, 0.3, 1.0 - age))
	_b(0, 118, GW, 32, Color(0.22, 0.12, 0.1))
	_speckle(0, 118, GW, 32, Color(0.17, 0.09, 0.08), 0.15)
	_speckle(0, 118, GW, 32, Color(0.3, 0.17, 0.13), 0.06, 4.0)
	# Ash drifting down.
	for k in 20:
		_b(fmod(k * 29.0 + t * 3.0, GW), fmod(k * 17.0 + t * 12.0, 118.0), 1, 1, Color(0.6, 0.55, 0.5, 0.6))
	# The Ogre King looming behind his column as it marches past.
	_walker("ogre_king", 80 + sin(t * 0.4) * 6.0, 132, 0.0, 8.0)
	var kinds := ["goblin", "orc", "goblin", "wolf", "orc", "troll", "goblin", "orc"]
	for i in kinds.size():
		var x := fmod(i * 24.0 + t * 9.0, GW + 40.0) - 20.0
		_walker(kinds[i], x, 140 + (i % 3) * 3, i * 0.37)


## The Ogre King in his war camp: a blood-red sky, his host filing along the ridge behind,
## war banners and braziers, and the King himself on a throne of bones.
func _draw_ogre_court() -> void:
	_sky(Color(0.18, 0.03, 0.04), Color(0.62, 0.18, 0.08))
	# A swollen red moon behind the smoke.
	_b(112, 16, 22, 22, Color(0.9, 0.35, 0.2, 0.25))
	_b(115, 19, 16, 16, Color(0.95, 0.45, 0.25))
	_b(118, 22, 4, 3, Color(0.8, 0.3, 0.18))
	for k in 3:
		_b(fmod(t * 3.0 + k * 60.0, GW + 40.0) - 30.0, 26 + k * 5, 36, 3, Color(0.12, 0.03, 0.03, 0.7))
	# His host, a column of torches and spears along the ridge.
	_ridge(78, 4, 2.0, Color(0.1, 0.03, 0.03))
	for i in 20:
		var x := fmod(i * 9.0 + t * 6.0, GW + 20.0) - 10.0
		var y := 74.0 - 4.0 * sin(x * 0.05 + 2.0)
		_b(x, y - 4, 2, 4, Color(0.06, 0.02, 0.02))
		_b(x + 1, y - 8, 1, 4, Color(0.25, 0.2, 0.2))
		if i % 4 == 0:
			_b(x + 1, y - 10, 1, 2, Color(1.0, 0.55 + 0.3 * sin(t * 9.0 + i), 0.2))
	_b(0, 88, GW, 62, Color(0.16, 0.06, 0.05))
	_speckle(0, 88, GW, 62, Color(0.22, 0.09, 0.07), 0.12)
	# Bones scattered on the ground.
	for i in 9:
		var bx := 8.0 + i * 17.0 + (i * 7) % 5
		_b(bx, 132 + (i % 3) * 4, 5, 1, Color(0.82, 0.78, 0.68))
		_b(bx - 1, 131 + (i % 3) * 4, 1, 3, Color(0.82, 0.78, 0.68))
	# War banners and braziers either side of the throne.
	for side in [-1, 1]:
		var bx: float = 80 + side * 50
		_b(bx, 64, 1, 50, Color(0.25, 0.15, 0.1))
		var wave := int(t * 3.0 + side) % 2
		_b(bx + 1, 66 + wave, 10, 14, Color(0.45, 0.06, 0.06))
		_b(bx + 1, 80 + wave, 5, 3, Color(0.45, 0.06, 0.06))
		_b(bx + 4, 70 + wave, 4, 4, Color(0.85, 0.82, 0.72))
		_b(bx + 5, 74 + wave, 2, 2, Color(0.85, 0.82, 0.72))
		var px: float = 80 + side * 30
		_b(px - 4, 112, 8, 3, Color(0.3, 0.26, 0.24))
		_b(px - 1, 115, 2, 10, Color(0.3, 0.26, 0.24))
		_flame(px, 112, 1.8, side * 2.0)
	# The throne of bones and, on it, the King.
	_b(60, 84, 40, 44, Color(0.05, 0.02, 0.02))
	_b(62, 86, 36, 40, Color(0.24, 0.13, 0.1))
	# Ribs and long bones lashed up the back, tusks at the corners, skulls along the top.
	for i in 5:
		_b(64 + i * 8, 87, 2, 38, Color(0.74, 0.7, 0.6))
		_b(64 + i * 8, 87, 1, 38, Color(0.86, 0.83, 0.74))
	for side in [-1, 1]:
		var tx: float = 80 + side * 20
		for k in 6:
			_b(tx - (k * 0.6 if side < 0 else -k * 0.6) - 1, 84 - k * 2, 2, 2, Color(0.9, 0.86, 0.76))
	for i in 6:
		_b(62 + i * 6, 80 - (i % 2) * 3, 4, 5, Color(0.85, 0.82, 0.72))
		_b(63 + i * 6, 81 - (i % 2) * 3, 1, 1, Color(0.1, 0.05, 0.05))
		_b(65 + i * 6, 81 - (i % 2) * 3, 1, 1, Color(0.1, 0.05, 0.05))
	_b(64, 98, 32, 30, Color(0.5, 0.1, 0.08))
	_b(64, 98, 32, 2, Color(0.62, 0.14, 0.1))
	var breathe := 1.0 if int(t * 1.2) % 2 == 0 else 0.0
	_figure_at("ogre_king", 80, 128 - breathe * 0.25, 7.0)
	# Embers rising.
	for k in 16:
		var age := fmod(t * 0.35 + k * 0.0625, 1.0)
		_b(10 + k * 9 + sin(t * 2.0 + k) * 4.0, 140 - age * 120.0, 1, 1, Color(1.0, 0.6, 0.25, 1.0 - age))


## The Ash Marshal on the road he's burning: farmsteads alight either side, his host
## marching behind him through falling ash, his ember banner raised.
func _draw_marshal_road() -> void:
	_sky(Color(0.12, 0.06, 0.06), Color(0.75, 0.32, 0.12))
	_ridge(70, 5, 4.0, Color(0.14, 0.07, 0.06))
	# Burning farmsteads, and their smoke leaning on the wind.
	for i in 5:
		var hx := 6.0 + i * 34.0
		if absf(hx + 8.0 - 80.0) < 22.0:
			continue
		_b(hx, 78, 18, 14, Color(0.1, 0.05, 0.04))
		_b(hx + 2, 72, 14, 6, Color(0.1, 0.05, 0.04))
		_b(hx + 5, 83, 3, 4, Color(1.0, 0.6, 0.2, 0.8))
		_flame(hx + 9, 74, 1.4, i * 1.7)
		for k in 8:
			var age := fmod(t * 0.3 + k / 8.0 + i * 0.2, 1.0)
			var r := 2.0 + age * 6.0
			_b(hx + 9 + age * 14.0 - r / 2.0, 68 - age * 50.0, r, r, Color(0.15, 0.08, 0.07, 0.5 * (1.0 - age)))
	# The road running back toward the horizon.
	_b(0, 92, GW, 58, Color(0.2, 0.11, 0.08))
	for row in range(92, 150):
		var half := 6.0 + (row - 92) * 0.7
		_b(80 - half, row, half * 2.0, 1, Color(0.32, 0.22, 0.16))
	_speckle(0, 92, GW, 58, Color(0.12, 0.06, 0.05), 0.08)
	# His host, coming up the road behind him.
	for i in 6:
		var depth := fmod(t * 0.12 + i / 6.0, 1.0)
		var sx := 80.0 + (i % 2 * 2 - 1) * (4.0 + depth * 22.0)
		var sy := 94.0 + depth * 22.0
		var sc := 1.0 + depth * 1.5
		_b(sx - sc, sy - 4.0 * sc, 2.0 * sc, 4.0 * sc, Color(0.06, 0.03, 0.03, 0.4 + 0.6 * depth))
	# The Marshal, his banner of embers beside him.
	_b(102, 72, 1, 54, Color(0.2, 0.12, 0.08))
	var wave := int(t * 4.0) % 2
	_b(103, 74 + wave, 14, 10, Color(0.6, 0.18, 0.08))
	_b(103, 84 + wave, 7, 3, Color(0.6, 0.18, 0.08))
	_b(108, 77 + wave, 4, 4, Color(1.0, 0.6, 0.2, 0.7 + 0.3 * sin(t * 6.0)))
	_figure_at("warlord", 80, 134, 6.0, Color(0.8, 0.62, 0.55))
	# Ash and embers falling.
	for k in 22:
		var fall := fmod(t * (6.0 + k % 4) + k * 13.0, 150.0)
		_b(fmod(k * 23.0 + sin(t + k) * 5.0, GW), fall, 1, 1, Color(0.6, 0.55, 0.5, 0.7) if k % 3 else Color(1.0, 0.55, 0.2, 0.9))


## A large sprite standing with its feet at art pixel (x, y), scaled, tinted.
func _figure_at(kind: String, x: float, y: float, scale: float, tint := Color.WHITE) -> void:
	var tex: Texture2D = Sprites.frames(kind)[0]
	var sz := Vector2(tex.get_width(), tex.get_height()) * scale
	var foot := Vector2(x * PX, y * PX)
	draw_rect(Rect2(foot.x - sz.x * 0.35, foot.y - 6, sz.x * 0.7, 8), Color(0, 0, 0, 0.35))
	draw_texture_rect(tex, Rect2(foot.x - sz.x / 2.0, foot.y - sz.y, sz.x, sz.y), false, tint)


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
	# Dark woods on the slope between the ridge and the keep.
	for i in 16:
		var px := i * 10 + (i * 7) % 5
		_pine(px, 80 + (i % 3) * 2, 8 + (i * 3) % 4, Color(0.14, 0.2, 0.15))
	_speckle(0, 84, GW, 66, Color(0.29, 0.36, 0.25), 0.12)
	# The road up to the gate.
	for row in range(130, 150):
		var half := 6.0 + (row - 130) * 0.6
		_b(80 - half, row, half * 2.0, 1, Color(0.42, 0.36, 0.28))
	# The keep, in the foreground: walls, two towers and a lit gate.
	var stone := Color(0.42, 0.4, 0.46)
	_b(30, 92, 100, 38, OUTLINE)
	_b(31, 93, 98, 37, stone)
	_bricks(31, 93, 98, 37, stone)
	for x in range(31, 129, 6):
		_b(x, 89, 3, 4, stone)
	for tx in [24, 118]:
		_b(tx - 1, 74, 20, 56, OUTLINE)
		_b(tx, 75, 18, 55, stone.darkened(0.1))
		_bricks(tx, 75, 18, 55, stone.darkened(0.1))
		_b(tx + 12, 75, 6, 55, Color(0, 0, 0, 0.12))
		_b(tx + 7, 84, 4, 6, Color(1.0, 0.75, 0.35))
		_b(tx - 2, 70, 22, 5, Color(0.55, 0.22, 0.2))
		# A pennant flying from each tower.
		_b(tx + 9, 60, 1, 10, Color(0.3, 0.25, 0.2))
		var wave := int(t * 4.0 + tx) % 2
		_b(tx + 10, 61 + wave, 6, 3, Color(0.8, 0.2, 0.2))
		_b(tx + 16, 62 + wave, 2, 1, Color(0.8, 0.2, 0.2))
	_b(72, 108, 16, 22, Color(0.25, 0.16, 0.1))
	_b(74, 110, 12, 4, Color(1.0, 0.7, 0.3, 0.6 + 0.3 * sin(t * 5.0)))
	_flame(66, 104, 0.8, 1.0)
	_flame(94, 104, 0.8, 2.0)
	# Two swordsmen on the wall, watching the ridge.
	_figure("swordsman", 56, 92, 0.0, false, 3.0, false)
	_figure("swordsman", 104, 92, 0.7, true, 3.0, false)
	_b(0, 130, GW, 20, Color(0.18, 0.22, 0.16))
	# The road up to the gate, across the foreground.
	for row in range(130, 150):
		var half := 8.0 + (row - 130) * 0.6
		_b(80 - half, row, half * 2.0, 1, Color(0.42, 0.36, 0.28))
		if row % 3 == 0:
			_b(80 - half + _h(row, 1.0) * half * 2.0, row, 2, 1, Color(0.34, 0.29, 0.22))


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
