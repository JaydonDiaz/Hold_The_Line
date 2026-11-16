extends SceneTree
## Draws the UI overhaul mockups: three styles for the battle HUD, each shown on the
## desktop (640x1040), on a phone (the same 640-wide game on a tall screen, the panel
## grown into the extra height with bigger text and touch-sized buttons) and as a strip of
## button states (normal, hover, pressed, disabled) and hire cards.
## Needs a window (not --headless):
##   godot --path . -s tools/ui_mockups.gd -- <fonts dir> <backdrop.png> <out dir>

var fonts_dir := ""
var backdrop: Texture2D
var out_dir := ""
var canvas: Node2D
var frames := 0
var style_i := 0
const STYLES := ["forge", "ledger", "slate"]
const W := 1220
const H := 1310

var F := {}   # name -> FontFile


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	fonts_dir = args[0]
	backdrop = ImageTexture.create_from_image(Image.load_from_file(args[1]))
	out_dir = args[2]
	for n in ["PixelifySans", "Silkscreen-Regular", "Silkscreen-Bold", "AlegreyaSans-Bold", "AlegreyaSans-Medium",
			"AlegreyaSansSC-ExtraBold", "Jersey10-Regular"]:
		var f := FontFile.new()
		f.load_dynamic_font(fonts_dir + "/" + n + ".ttf")
		if n.begins_with("Pixelify") or n.begins_with("Silkscreen") or n.begins_with("Jersey"):
			f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			f.hinting = TextServer.HINTING_NONE
			f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		F[n] = f
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED   # (drawn 1:1, not stretched like the game)
	root.size = Vector2i(W, H)
	canvas = Mock.new()
	canvas.app = self
	root.add_child(canvas)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		canvas.style = STYLES[style_i]
		canvas.queue_redraw()
	if frames == 8:
		root.get_texture().get_image().save_png("%s/option_%d_%s.png" % [out_dir, style_i + 1, STYLES[style_i]])
		print("saved ", STYLES[style_i])
		style_i += 1
		frames = 0
		if style_i >= STYLES.size():
			return true
	return false


class Mock extends Node2D:
	var app
	var style := "forge"
	var S := {}   # the style's palette and fonts

	# The selected Archer's upgrade paths: name, colour, tiers bought, price, key, next tier, what it does.
	const PATHS := [
		["Damage", Color(1.0, 0.62, 0.32), 0, "30g", "Q", "Barbed Arrows", "+30% damage"],
		["Range", Color(0.45, 0.72, 1.0), 3, "145g", "W", "Skyreach", "+6 ft range, 40% chance to crit for 4x"],
		["Attack Speed", Color(0.6, 0.95, 0.45), 0, "30g", "E", "Quick Nock", "Fires 18% faster"],
		["Trick Shots", Color(0.85, 0.58, 1.0), 0, "35g", "R", "Split Shot", "Fires 2 arrows at different enemies"],
	]

	func _draw() -> void:
		_palette()
		draw_rect(Rect2(0, 0, W, H), S["page"])
		# Heading.
		_text(Vector2(24, 44), S["title"], S["head"], 30, S["page_ink"])
		_text(Vector2(24, 74), S["blurb"], S["body"], 17, S["page_ink2"])
		# Desktop.
		_caption(Vector2(24, 104), "DESKTOP  640 x 1040")
		_screen(Vector2(24, 116), false)
		# Phone (the same game on a 390 x 844 phone: 640 x 1385 in game pixels, shown at 0.75).
		_caption(Vector2(700, 104), "PHONE  390 x 844 (shown larger)")
		draw_set_transform(Vector2(700, 116), 0.0, Vector2(0.72, 0.72))
		_screen(Vector2.ZERO, true)
		draw_set_transform(Vector2.ZERO)
		# Button states.
		_caption(Vector2(700, 1135), "BUTTON STATES")
		var bx := 700.0
		for st in ["normal", "hover", "pressed", "disabled"]:
			_button(Rect2(bx, 1146, 116, 44), "Start Wave", st, 18, st == "normal")
			_text(Vector2(bx + 2, 1210), st.capitalize(), S["body"], 14, S["page_ink2"])
			bx += 126.0
		_caption(Vector2(700, 1236), "HIRE CARDS")
		_hire_card(Rect2(700, 1246, 150, 52), "Knight", "50g", "normal")
		_hire_card(Rect2(860, 1246, 150, 52), "Archer", "60g", "pressed")
		_hire_card(Rect2(1020, 1246, 150, 52), "Mage", "120g", "disabled")

	func _caption(p: Vector2, s: String) -> void:
		_text(p, s, S["label"], 12, S["page_ink2"])

	# --- One screen: the battlefield and the HUD under it -------------------------------

	func _screen(o: Vector2, phone: bool) -> void:
		var h := 1385.0 if phone else 1040.0
		draw_rect(Rect2(o - Vector2(2, 2), Vector2(644, h + 4)), Color(0, 0, 0, 0.5))
		draw_texture_rect_region(app.backdrop, Rect2(o, Vector2(640, 768)), Rect2(0, 0, 640, 768))
		var k := 1.35 if phone else 1.0   # text and touch targets grow on a phone
		var panel := Rect2(o + Vector2(0, 768), Vector2(640, h - 768))
		_panel(panel)
		var y := panel.position.y + 14.0
		# The top bar: what you have, then the battle's buttons (on a phone, a row of their own).
		if phone:
			_stat(Vector2(o.x + 20, y + 34), "GOLD", "540", S["gold"], k)
			_stat(Vector2(o.x + 230, y + 34), "CASTLE", "450", S["hp"], k)
			_stat(Vector2(o.x + 440, y + 34), "WAVE", "3", S["wave"], k)
			y += 56.0
			var bw := (640.0 - 28.0 - 3 * 10.0) / 4.0
			var names := ["Menu", "1x", "Auto", "Wave 3..."]
			for i in 4:
				_button(Rect2(o.x + 14 + i * (bw + 10), y, bw, 52), names[i], "disabled" if i == 3 else "normal", 22, i == 3)
			y += 68.0
		else:
			_stat(Vector2(o.x + 14, y + 24), "GOLD", "540", S["gold"], k)
			_stat(Vector2(o.x + 120, y + 24), "CASTLE", "450", S["hp"], k)
			_stat(Vector2(o.x + 232, y + 24), "WAVE", "3", S["wave"], k)
			_button(Rect2(o.x + 330, y - 2, 66, 36), "Menu", "normal", 15)
			_button(Rect2(o.x + 402, y - 2, 44, 36), "1x", "hover", 15)
			_button(Rect2(o.x + 452, y - 2, 60, 36), "Auto", "normal", 15)
			_button(Rect2(o.x + 518, y - 2, 108, 36), "Wave 3...", "disabled", 15, true)
			y += 50.0
		_divider(Vector2(o.x + 14, y - 6), 612.0)
		# The upgrade paths: four across on the desktop, two by two on a phone (no key hints:
		# there's no keyboard).
		var cols := 2 if phone else 4
		var cw := (640.0 - 28.0 - (cols - 1) * 8.0) / cols
		var ch := 132.0 if phone else 112.0
		for i in PATHS.size():
			var c := Rect2(o.x + 14 + (i % cols) * (cw + 8), y + (i / cols) * (ch + 8), cw, ch)
			_path_card(c, PATHS[i], k, i == 1, not phone)
		y += (ch + 8) * (PATHS.size() / cols)
		# The unit, then its buttons.
		_text(Vector2(o.x + 16, y + 18 * k), "Archer", S["head"], 20 * k, S["ink"])
		_text(Vector2(o.x + 16 + _width("Archer", S["head"], 20 * k) + 10, y + 18 * k), "Upgrades 3/6", S["body"], 13 * k, S["ink2"])
		var lines := ["HP 50/50   Damage 9   Every 0.70s   Range 27 ft", "Speed 12.5 ft/s   Crit 25% x3",
			"Closest target · Focused · Free Roam"]
		for i in lines.size():
			_text(Vector2(o.x + 16, y + (38 + i * 18) * k), lines[i], S["body"], 13 * k, S["ink2"] if i < 2 else S["muted"])
		if phone:
			y += 114.0
			_button(Rect2(o.x + 14, y, 300, 64), "Orders", "normal", 24, false, "Closest · Free")
			_button(Rect2(o.x + 326, y, 300, 64), "Sell  +141g", "normal", 24, true)
		else:
			_button(Rect2(o.x + 416, y + 12, 100, 58), "Orders", "normal", 15, false, "Closest · Free")
			_button(Rect2(o.x + 524, y + 12, 102, 58), "Sell  +141g", "hover", 15, true)

	func _stat(p: Vector2, label: String, value: String, col: Color, k: float) -> void:
		_text(p + Vector2(0, -16 * k), label, S["label"], 10 * k, S["muted"])
		_text(p + Vector2(0, 6 * k), value, S["num"], S["num_size"] * k, col)

	func _path_card(r: Rect2, p: Array, k: float, hot: bool, keys: bool) -> void:
		_card(r, p[1], "hover" if hot else "normal")
		p = p.duplicate()
		if style == "ledger":
			p[1] = (p[1] as Color).darkened(0.5)   # (ink on paper: the path colours, darker)
		var x := r.position.x + 12
		_text(Vector2(x, r.position.y + 20 * k), p[0], S["head"], 16 * k, p[1])
		# Tiers bought, as pips; the price (and its key, on a keyboard) on the right.
		for t in 4:
			var pr := Rect2(x + t * 13 * k, r.position.y + 28 * k, 10 * k, 5 * k)
			draw_rect(pr, p[1] if t < p[2] else S["pip_off"])
		var price: String = ("%s  %s" % [p[3], p[4]]) if keys else p[3]
		_text(Vector2(r.end.x - 12 - _width(price, S["body"], 13 * k), r.position.y + 36 * k), price, S["body"], 13 * k, S["gold"])
		_text(Vector2(x, r.position.y + 54 * k), p[5], S["head"], 15 * k, S["ink"])
		_wrap(Rect2(x, r.position.y + 58 * k, r.size.x - 24, 60 * k), p[6], S["body"], 12.5 * k, S["ink2"])

	func _hire_card(r: Rect2, name: String, price: String, st: String) -> void:
		_card(r, S["accent"], st)
		var dim := st == "disabled"
		var off := Vector2(0, 2) if st == "pressed" and S["press_sink"] else Vector2.ZERO
		_text(r.position + Vector2(12, 22) + off, name, S["head"], 17, S["muted"] if dim else S["ink"])
		_text(r.position + Vector2(12, 42) + off, price, S["body"], 14, S["muted"] if dim else S["gold"])

	# --- Text helpers -------------------------------------------------------------------

	func _text(p: Vector2, s: String, font: String, size: float, col: Color) -> void:
		draw_string(app.F[font], p.round(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), col)

	func _width(s: String, font: String, size: float) -> float:
		return app.F[font].get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x

	func _wrap(r: Rect2, s: String, font: String, size: float, col: Color) -> void:
		var line := ""
		var y := r.position.y + size + 2
		for word in s.split(" "):
			var tryl := word if line == "" else line + " " + word
			if _width(tryl, font, size) > r.size.x and line != "":
				_text(Vector2(r.position.x, y), line, font, size, col)
				y += size + 3
				line = word
			else:
				line = tryl
		if line != "":
			_text(Vector2(r.position.x, y), line, font, size, col)

	func _centered(r: Rect2, s: String, font: String, size: float, col: Color, dy := 0.0) -> void:
		var w := _width(s, font, size)
		_text(Vector2(r.get_center().x - w / 2.0, r.get_center().y + size * 0.36 + dy), s, font, size, col)

	# --- The styles -----------------------------------------------------------------------

	func _palette() -> void:
		match style:
			"forge":
				S = {"title": "Option 1  ·  Forge", "blurb": "Iron-framed oak, riveted. Warm and solid; reads like the castle's own gear.",
					"head": "PixelifySans", "body": "PixelifySans", "label": "Silkscreen-Regular", "num": "Jersey10-Regular", "num_size": 30,
					"page": Color(0.09, 0.075, 0.065), "page_ink": Color(0.96, 0.88, 0.7), "page_ink2": Color(0.7, 0.62, 0.5),
					"panel": Color(0.17, 0.12, 0.085), "panel_line": Color(0.13, 0.09, 0.06), "iron": Color(0.36, 0.36, 0.4),
					"iron_hi": Color(0.56, 0.56, 0.6), "iron_lo": Color(0.16, 0.16, 0.19), "fill": Color(0.24, 0.17, 0.11),
					"fill_hi": Color(0.32, 0.23, 0.15), "ink": Color(0.97, 0.9, 0.74), "ink2": Color(0.82, 0.74, 0.6),
					"muted": Color(0.55, 0.48, 0.4), "gold": Color(1.0, 0.8, 0.32), "hp": Color(1.0, 0.5, 0.42),
					"wave": Color(0.72, 0.82, 1.0), "accent": Color(1.0, 0.78, 0.3), "pip_off": Color(0.3, 0.24, 0.18),
					"press_sink": true}
			"ledger":
				S = {"title": "Option 2  ·  Field Ledger", "blurb": "The commander's ledger: parchment, ink and hard-edged tabs that press flat.",
					"head": "AlegreyaSans-Bold", "body": "AlegreyaSans-Medium", "label": "AlegreyaSansSC-ExtraBold", "num": "AlegreyaSans-Bold", "num_size": 26,
					"page": Color(0.16, 0.13, 0.1), "page_ink": Color(0.95, 0.9, 0.78), "page_ink2": Color(0.72, 0.66, 0.55),
					"panel": Color(0.9, 0.84, 0.7), "panel_line": Color(0.8, 0.72, 0.56), "iron": Color(0.23, 0.17, 0.12),
					"iron_hi": Color(0.23, 0.17, 0.12), "iron_lo": Color(0.23, 0.17, 0.12), "fill": Color(0.96, 0.92, 0.8),
					"fill_hi": Color(1.0, 0.97, 0.88), "ink": Color(0.17, 0.12, 0.08), "ink2": Color(0.32, 0.25, 0.18),
					"muted": Color(0.5, 0.42, 0.32), "gold": Color(0.6, 0.38, 0.05), "hp": Color(0.7, 0.18, 0.12),
					"wave": Color(0.18, 0.3, 0.6), "accent": Color(0.55, 0.16, 0.12), "pip_off": Color(0.78, 0.7, 0.55),
					"press_sink": true}
			"slate":
				S = {"title": "Option 3  ·  Slate", "blurb": "Lean and modern-pixel: cut-corner slabs on dark slate, colour only where it means something.",
					"head": "PixelifySans", "body": "PixelifySans", "label": "Silkscreen-Bold", "num": "Jersey10-Regular", "num_size": 30,
					"page": Color(0.07, 0.08, 0.09), "page_ink": Color(0.92, 0.94, 0.96), "page_ink2": Color(0.6, 0.64, 0.68),
					"panel": Color(0.105, 0.12, 0.14), "panel_line": Color(0.16, 0.18, 0.21), "iron": Color(0.3, 0.34, 0.39),
					"iron_hi": Color(0.42, 0.47, 0.53), "iron_lo": Color(0.06, 0.07, 0.08), "fill": Color(0.16, 0.18, 0.21),
					"fill_hi": Color(0.21, 0.24, 0.28), "ink": Color(0.93, 0.95, 0.97), "ink2": Color(0.72, 0.76, 0.8),
					"muted": Color(0.47, 0.51, 0.56), "gold": Color(1.0, 0.8, 0.35), "hp": Color(1.0, 0.45, 0.4),
					"wave": Color(0.6, 0.78, 1.0), "accent": Color(1.0, 0.72, 0.28), "pip_off": Color(0.24, 0.27, 0.31),
					"press_sink": true}

	func _panel(r: Rect2) -> void:
		match style:
			"forge":
				draw_rect(r, S["panel"])
				var y := r.position.y + 10.0
				while y < r.end.y:
					draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), S["panel_line"], 1.0)
					y += 22.0
				draw_rect(Rect2(r.position, Vector2(r.size.x, 6)), S["iron"])
				draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), S["iron_hi"])
				draw_rect(Rect2(r.position + Vector2(0, 6), Vector2(r.size.x, 2)), S["iron_lo"])
				var x := r.position.x + 10.0
				while x < r.end.x:
					draw_rect(Rect2(x, r.position.y + 2, 2, 2), S["iron_hi"].lightened(0.3))
					x += 40.0
			"ledger":
				draw_rect(r, S["panel"])
				var y := r.position.y + 30.0
				while y < r.end.y:
					draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(S["panel_line"], 0.5), 1.0)
					y += 24.0
				draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), S["iron"])
				for i in 6:   # darker towards the edges, like old paper
					draw_rect(Rect2(r.position.x, r.position.y + 3 + i * 2, r.size.x, 2), Color(0.45, 0.32, 0.18, 0.08 * (6 - i)))
			"slate":
				draw_rect(r, S["panel"])
				draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), S["iron_hi"])
				draw_rect(Rect2(r.position + Vector2(0, -18), Vector2(r.size.x, 18)), Color(S["panel"], 0.0))
				for i in 9:   # a soft fade from the field into the panel
					draw_rect(Rect2(r.position.x, r.position.y - 18 + i * 2, r.size.x, 2), Color(S["panel"], 0.06 * i))

	func _divider(p: Vector2, w: float) -> void:
		match style:
			"forge":
				draw_rect(Rect2(p, Vector2(w, 1)), S["iron_lo"])
				draw_rect(Rect2(p + Vector2(0, 1), Vector2(w, 1)), Color(S["iron_hi"], 0.25))
			"ledger":
				draw_rect(Rect2(p, Vector2(w, 1)), Color(S["iron"], 0.5))
				draw_rect(Rect2(p + Vector2(0, 3), Vector2(w, 1)), Color(S["iron"], 0.25))
			"slate":
				draw_rect(Rect2(p, Vector2(w, 1)), S["panel_line"])

	## A card: the upgrade paths' and hire buttons' frame, in the style.
	func _card(r: Rect2, col: Color, st: String) -> void:
		var dim := st == "disabled"
		var sink := Vector2(0, 2) if st == "pressed" else Vector2.ZERO
		match style:
			"forge":
				draw_rect(r.grow(1), Color(0, 0, 0, 0.6))
				draw_rect(r, S["iron_lo"] if st == "pressed" else S["iron"])
				var inner := r.grow(-2)
				draw_rect(inner, S["fill_hi"] if st == "hover" else (S["fill"].darkened(0.2) if st == "pressed" or dim else S["fill"]))
				if st != "pressed":
					draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), S["iron_hi"])
					draw_rect(Rect2(r.position, Vector2(2, r.size.y)), S["iron_hi"])
				draw_rect(Rect2(inner.position.x, inner.end.y - 3, inner.size.x, 3), Color(col, 0.25 if dim else 0.9))
				for c in [r.position + Vector2(4, 4), Vector2(r.end.x - 6, r.position.y + 4), Vector2(r.position.x + 4, r.end.y - 6), r.end - Vector2(6, 6)]:
					draw_rect(Rect2(c, Vector2(2, 2)), S["iron_hi"].lightened(0.2))
				if st == "hover":
					draw_rect(r.grow(1), S["accent"], false, 1.0)
			"ledger":
				var shadow := Vector2(3, 3)
				if st != "pressed":
					draw_rect(Rect2(r.position + shadow, r.size), Color(S["iron"], 0.85 if not dim else 0.3))
				var rr := Rect2(r.position + (shadow if st == "pressed" else Vector2.ZERO), r.size)
				draw_rect(rr, S["fill_hi"] if st == "hover" else S["fill"])
				draw_rect(rr, Color(S["iron"], 0.4 if dim else 1.0), false, 2.0)
				draw_rect(Rect2(rr.position + Vector2(2, 2), Vector2(4, rr.size.y - 4)), Color(col.darkened(0.35), 0.35 if dim else 1.0))
			"slate":
				var cut := 6.0
				var rr := Rect2(r.position + sink, r.size)
				var poly := PackedVector2Array([rr.position + Vector2(cut, 0), Vector2(rr.end.x, rr.position.y), Vector2(rr.end.x, rr.end.y - cut),
						Vector2(rr.end.x - cut, rr.end.y), Vector2(rr.position.x, rr.end.y), rr.position + Vector2(0, cut)])
				draw_colored_polygon(poly, S["fill_hi"] if st == "hover" else (S["fill"].darkened(0.25) if st == "pressed" else S["fill"]))
				draw_polyline(poly + PackedVector2Array([poly[0]]), S["iron_hi"] if st == "hover" else S["iron"], 1.0)
				draw_rect(Rect2(rr.position + Vector2(0, cut), Vector2(3, rr.size.y - cut)), Color(col, 0.3 if dim else 1.0))

	## A button in the style. `primary` is the one that matters most (Start, Sell).
	func _button(r: Rect2, label: String, st: String, size: float, primary := false, sub := "") -> void:
		var dim := st == "disabled"
		var sink := Vector2(0, 2) if st == "pressed" else Vector2.ZERO
		var text_col: Color = S["ink"]
		match style:
			"forge":
				draw_rect(r.grow(1), Color(0, 0, 0, 0.7))
				draw_rect(r, S["iron_lo"] if st == "pressed" else S["iron"])
				var inner := r.grow(-3)
				var fill: Color = S["fill"]
				if primary and not dim:
					fill = Color(0.45, 0.27, 0.1)
				if st == "hover":
					fill = fill.lightened(0.12)
				elif st == "pressed" or dim:
					fill = fill.darkened(0.25)
				draw_rect(inner, fill)
				if st != "pressed":
					draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), S["iron_hi"])
					draw_rect(Rect2(r.position, Vector2(2, r.size.y)), S["iron_hi"])
					draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1)), Color(1, 1, 1, 0.12))
				else:
					draw_rect(Rect2(inner.position, Vector2(inner.size.x, 2)), Color(0, 0, 0, 0.35))
				for c in [r.position + Vector2(4, 4), Vector2(r.end.x - 6, r.position.y + 4), Vector2(r.position.x + 4, r.end.y - 6), r.end - Vector2(6, 6)]:
					draw_rect(Rect2(c, Vector2(2, 2)), S["iron_hi"].lightened(0.25))
				if st == "hover":
					draw_rect(r.grow(1), S["accent"], false, 1.0)
				text_col = S["muted"] if dim else (S["gold"] if primary else S["ink"])
			"ledger":
				var shadow := Vector2(3, 3)
				if st != "pressed":
					draw_rect(Rect2(r.position + shadow, r.size), Color(S["iron"], 0.3 if dim else 0.9))
				var rr := Rect2(r.position + (shadow if st == "pressed" else Vector2.ZERO), r.size)
				var fill: Color = S["accent"] if primary and not dim else S["fill"]
				if st == "hover":
					fill = fill.lightened(0.1)
				draw_rect(rr, fill)
				draw_rect(rr, Color(S["iron"], 0.4 if dim else 1.0), false, 2.0)
				r = rr
				sink = Vector2.ZERO
				text_col = S["muted"] if dim else (Color(0.98, 0.94, 0.84) if primary else S["ink"])
			"slate":
				var cut := 7.0
				var rr := Rect2(r.position + sink, r.size)
				var poly := PackedVector2Array([rr.position + Vector2(cut, 0), Vector2(rr.end.x, rr.position.y), Vector2(rr.end.x, rr.end.y - cut),
						Vector2(rr.end.x - cut, rr.end.y), Vector2(rr.position.x, rr.end.y), rr.position + Vector2(0, cut)])
				if primary and not dim:
					var fill: Color = S["accent"]
					if st == "hover":
						fill = fill.lightened(0.15)
					elif st == "pressed":
						fill = fill.darkened(0.15)
					draw_colored_polygon(poly, fill)
					text_col = Color(0.1, 0.08, 0.05)
				else:
					var fill: Color = S["fill_hi"] if st == "hover" else (S["fill"].darkened(0.3) if st == "pressed" else S["fill"])
					draw_colored_polygon(poly, fill)
					draw_polyline(poly + PackedVector2Array([poly[0]]), S["accent"] if st == "hover" else (S["iron"] if not dim else S["panel_line"]), 1.0)
					text_col = S["muted"] if dim else S["ink"]
				r = rr
				sink = Vector2.ZERO
		if sub == "":
			_centered(Rect2(r.position + sink, r.size), label, S["head"], size, text_col)
		else:
			_centered(Rect2(r.position + sink, r.size), label, S["head"], size, text_col, -size * 0.55)
			_centered(Rect2(r.position + sink, r.size), sub, S["body"], size * 0.72, S["muted"] if style != "ledger" else S["ink2"], size * 0.6)
