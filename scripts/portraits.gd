extends RefCounted
## Head-and-shoulders pixel portraits for the campaign's named characters, drawn in
## code like every other sprite: a 32x32 picture built from a character's look (see
## campaign_data.gd SPEAKERS "look"): skin, hair, beard, headwear, the outfit of their
## homeland, a few extras, and a backdrop in their region's colours. The figure gets
## the same dark outline as the unit sprites. Each portrait is made once and cached.
##
## look keys:
##   skin, hair_color, beard_color, eyes (Colors)      bg: [top, bottom] Colors
##   hair     "short", "long", "braid", "bun", "bald", "topknot"
##   beard    "", "full", "short"
##   head     "", "goggles", "miner", "veil", "fur", "feather_hat", "wizard", "crown", "horned", "circlet"
##   outfit   "tabard", "apron", "leaf_cloak", "overalls", "robe", "fur_mantle", "doublet", "monk", "star_robe", "armor", "ogre"
##   colors   [main, second, trim] for the outfit (and headwear)
##   extras   any of "tusks", "soot", "scar", "tattoo", "beads", "earring", "glow", "wrinkles", "calm",
##            "elf" (long pointed ears; the elves of Greenwood also share the archers' green hair)
##   wide     a bigger head (the Ogre King)

const SIZE := 32          # the grid the figure is laid out on...
const RES := 2            # ...drawn at this many pixels a cell, so fine detail can go on top
const OUT := SIZE * RES   # the picture's real size
const OUTLINE := Color(0.1, 0.07, 0.1)

static var _cache := {}


static func texture(id: String, look: Dictionary) -> ImageTexture:
	if not _cache.has(id):
		_cache[id] = ImageTexture.create_from_image(image(look))
	return _cache[id]


static func image(look: Dictionary) -> Image:
	var fig := Image.create(OUT, OUT, false, Image.FORMAT_RGBA8)
	fig.fill(Color(0, 0, 0, 0))
	var wide: bool = look.get("wide", false)
	var cx := 15.5
	var cy := 14.0 if not wide else 14.5
	var rx := 6.0 if not wide else 8.0
	var ry := 7.0 if not wide else 7.5
	var skin: Color = look.get("skin", Color(0.95, 0.78, 0.62))
	var hair: Color = look.get("hair_color", Color(0.35, 0.22, 0.12))
	var cols: Array = look.get("colors", [Color(0.4, 0.4, 0.6), Color(0.3, 0.3, 0.45), Color(0.9, 0.8, 0.4)])
	var extras: Array = look.get("extras", [])
	var style: String = look.get("hair", "short")
	var head: String = look.get("head", "")

	# Behind the head: long hair, the back of a hood or veil.
	if style in ["long", "braid"] and head != "veil":
		_rect(fig, int(cx - rx - 1), int(cy - 2), int(rx * 2 + 3), 13 if style == "long" else 8, hair)
	if head == "veil":
		_ellipse(fig, cx, cy + 1, rx + 2.5, ry + 3, cols[0])
		_rect(fig, int(cx - rx - 2), int(cy + 2), int(rx * 2 + 5), 9, cols[0])
	if head == "fur":
		_ellipse(fig, cx, cy, rx + 2, ry + 1.5, cols[1])
	_outfit(fig, look.get("outfit", "tabard"), cols, skin, extras)
	# Neck and head.
	_rect(fig, int(cx - 2.5), int(cy + ry - 2), 6, 4, skin.darkened(0.15))
	_ellipse(fig, cx, cy, rx, ry, skin)
	for y in SIZE:
		for x in SIZE:
			if x > cx + rx - 2.5 and _in_ellipse(x, y, cx, cy, rx, ry):
				_px(fig, x, y, skin.darkened(0.12))   # shade on the right
	# Ears.
	_px(fig, int(cx - rx - 1), int(cy + 1), skin.darkened(0.1))
	_px(fig, int(cx + rx + 1), int(cy + 1), skin.darkened(0.2))
	_face(fig, cx, cy, rx, look, skin, hair, extras)
	_hair(fig, style, cx, cy, rx, ry, hair, head)
	_beard(fig, look.get("beard", ""), cx, cy, rx, ry, look.get("beard_color", hair))
	if "elf" in extras:
		# Long ears that sweep up and out, past the hair.
		for side in [-1, 1]:
			var ex := int(cx - rx - 1) if side < 0 else int(cx + rx + 1)
			var c := skin if side < 0 else skin.darkened(0.15)
			_px(fig, ex, int(cy + 1), c)
			_px(fig, ex, int(cy), c)
			_px(fig, ex + side, int(cy - 1), c)
			_px(fig, ex + side * 2, int(cy - 2), c)
	_headwear(fig, head, cx, cy, rx, ry, cols, skin)
	if "tusks" in extras:
		for x in [int(cx - 3), int(cx + 3)]:
			_px(fig, x, int(cy + 4), Color(0.95, 0.92, 0.8))
			_px(fig, x, int(cy + 3), Color(0.95, 0.92, 0.8))
	if "earring" in extras:
		_px(fig, int(cx - rx - 1), int(cy + 3), cols[2])
	_details(fig, look, cx, cy, rx, ry, skin, hair, cols, extras, style, head)
	_light(fig, RIMS.get(look.get("scene", ""), Color(0, 0, 0, 0)))
	_outline(fig)
	# The backdrop: the region's colours, light at the top.
	var bg: Array = look.get("bg", [Color(0.3, 0.35, 0.5), Color(0.15, 0.17, 0.25)])
	var out := Image.create(OUT, OUT, false, Image.FORMAT_RGBA8)
	for y in OUT:
		var c: Color = (bg[0] as Color).lerp(bg[1], y / float(OUT - 1))
		for x in OUT:
			# A little dither between bands so the gradient reads as pixel art.
			var k := c.lightened(0.04) if (x + y) % 4 == 0 and y % 3 == 0 else c
			out.set_pixel(x, y, k)
	_scene(out, look.get("scene", ""), bg)
	# A soft vignette: the corners fall away into shadow.
	for y in OUT:
		for x in OUT:
			var d := Vector2(x - OUT / 2.0 + 0.5, y - OUT / 2.0 + 0.5).length() / (OUT * 0.5)
			if d > 0.8:
				out.set_pixel(x, y, out.get_pixel(x, y).darkened(minf((d - 0.8) * 0.9, 0.35)))
	out.blend_rect(fig, Rect2i(0, 0, OUT, OUT), Vector2i.ZERO)
	return out


# --- Fine detail (at the real resolution, over the figure laid out on its grid) ----------

static func _details(img: Image, look: Dictionary, cx: float, cy: float, rx: float, ry: float, skin: Color,
		hair: Color, cols: Array, extras: Array, style: String, head: String) -> void:
	var helmed := head == "horned"
	var gap := 0 if rx < 7.0 else 1
	var ey := int(cy)
	# Hair and beard: strands, darker and lighter, running down the cap.
	var beard_col: Color = look.get("beard_color", hair)
	for y in OUT:
		for x in OUT:
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			if _near(c, hair) or _near(c, hair.lightened(0.15)) or (look.get("beard", "") != "" and _near(c, beard_col)):
				# Strands running down: a fine darker line every few pixels, broken now and then.
				if (x + y / 6) % 4 == 0 and (y / 3 + x) % 7 != 0:
					img.set_pixel(x, y, c.darkened(0.16))
				elif (x + y / 6) % 4 == 2 and y % 5 == 0:
					img.set_pixel(x, y, c.lightened(0.1))
	if not helmed:
		for side in [-1, 1]:
			var inner: int = (13 - gap) if side < 0 else (18 + gap)
			if not ("calm" in extras):
				# A glint in each eye, and a lid line over it.
				_fp(img, inner * RES + (0 if side < 0 else 1), (ey - 1) * RES, Color(1, 1, 1, 0.9))
				_fp(img, inner * RES, (ey - 1) * RES - 1, skin.darkened(0.45))
				_fp(img, inner * RES + 1, (ey - 1) * RES - 1, skin.darkened(0.45))
			# Brows: just the lower half of the cells, so they read as fine lines.
			for k in 2:
				var bx: int = (inner + side * k) * RES
				_fp(img, bx, (ey - 3) * RES, skin)
				_fp(img, bx + 1, (ey - 3) * RES, skin)
		# The mouth: a fine line with lips under it (not through a beard, a helm or tusks).
		if look.get("beard", "") == "" and not ("tusks" in extras):
			var lip := skin.lerp(Color(0.78, 0.32, 0.34), 0.45)
			if "frost_lips" in extras:
				lip = Color(0.6, 0.78, 0.95)
			for x in range(int(cx - 1) * RES, int(cx + 2) * RES):
				_fp(img, x, int(cy + 4) * RES + 1, lip)
			_fp(img, int(cx - 1) * RES, int(cy + 4) * RES + 1, skin.darkened(0.2))
			_fp(img, int(cx + 2) * RES - 1, int(cy + 4) * RES + 1, skin.darkened(0.2))
			# A little colour in the cheeks, and the nose's shadow.
			if not ("wrinkles" in extras):
				for side in [-1, 1]:
					var bx := int((cx + side * 4.0) * RES)
					_fp(img, bx, int(cy + 2) * RES, Color(0.95, 0.45, 0.45, 0.28))
					_fp(img, bx + 1, int(cy + 2) * RES, Color(0.95, 0.45, 0.45, 0.28))
			_fp(img, int(cx) * RES + 1, int(cy + 2) * RES + 1, skin.darkened(0.35))
	# Clothes: folds down from the shoulders, a seam of the trim colour along the collar.
	var main: Color = cols[0]
	for y in range(23 * RES, OUT):
		for x in OUT:
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			if _near(c, main) or _near(c, main.darkened(0.15)):
				if (x * 3 + y) % 17 == 0 or (x * 3 - y) % 19 == 0:
					img.set_pixel(x, y, c.darkened(0.14))
	_extra_details(img, look, cx, cy, rx, ry, skin, cols, extras, head)


static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.03


## Each character's own touches, at the fine resolution.
static func _extra_details(img: Image, look: Dictionary, cx: float, cy: float, rx: float, ry: float, skin: Color,
		cols: Array, extras: Array, head: String) -> void:
	var trim: Color = cols[2]
	if "pendant" in extras:
		# A sun pendant on a fine chain.
		for i in 6:
			_fp(img, 26 + i, 46 + int(absf(i - 2.5) * -0.6 + 2), trim.darkened(0.2))
			_fp(img, 37 - i, 46 + int(absf(i - 2.5) * -0.6 + 2), trim.darkened(0.2))
		var sun := Vector2(31.5, 51.5)
		for y in range(46, 58):
			for x in range(26, 38):
				var d := Vector2(x + 0.5, y + 0.5).distance_to(sun)
				var ray := fmod(Vector2(x + 0.5, y + 0.5).direction_to(sun).angle() + TAU, TAU / 8.0) < 0.3
				if d <= 2.6:
					_fp(img, x, y, trim.lightened(0.25) if d < 1.2 else trim)
				elif d <= 3.6 or (ray and d <= 5.2):
					_fp(img, x, y, OUTLINE if d <= 3.6 else trim.darkened(0.35))
	if "angry" in extras:
		# A heavy brow drawn down in a scowl, and an old scar across it.
		var gap2 := 0 if rx < 7.0 else 1
		for side in [-1, 1]:
			var inner: int = ((13 - gap2) if side < 0 else (18 + gap2)) * RES + (1 if side < 0 else 0)
			for i in 6:
				_fp(img, inner - side * i, int(cy - 3) * RES + 1 - int(i / 2.0) + 1, skin.darkened(0.55))
				_fp(img, inner - side * i, int(cy - 3) * RES + 2 - int(i / 2.0) + 1, skin.darkened(0.3))
		for i in 7:
			_fp(img, int(cx * RES) + 6 + i / 2, int(cy - 5) * RES + i, Color(0.75, 0.35, 0.3))
	if "pelt" in extras:
		# A shaggy pelt round the shoulders.
		var fur: Color = Color(0.52, 0.42, 0.32)
		for x in range(4, 60):
			var y0 := 45 + int(absf(x - 32) * 0.18) - (2 if x % 4 < 2 else 0)
			for y in range(y0, y0 + 6 + (x * 7) % 3):
				if img.get_pixel(x, mini(y + 2, OUT - 1)).a > 0.0:
					var k := (x * 3 + y * 5) % 7
					_fp(img, x, y, fur.lightened(0.18) if k == 0 else fur.darkened(0.22) if k == 3 else fur)
	if "ember_slit" in extras:
		for x in range(int(cx - 4) * RES, int(cx + 5) * RES):
			_fp(img, x, int(cy) * RES - 1, Color(1.0, 0.75, 0.3, 0.7))
			_fp(img, x, int(cy) * RES + 2, Color(1.0, 0.45, 0.15, 0.5))
		for side in [-1, 1]:
			_fp(img, int(cx * RES) + side * 5, int(cy) * RES, Color(1, 0.95, 0.7))
	if "quiver" in extras:
		# A quiver strap across the chest, arrows over the shoulder.
		for i in 22:
			_fp(img, 44 - i, 44 + i, Color(0.32, 0.2, 0.1))
			_fp(img, 45 - i, 44 + i, Color(0.45, 0.3, 0.16))
		for k in 3:
			var ax := 48 + k * 3
			for i in 9:
				_fp(img, ax + i / 3, 44 - i, Color(0.55, 0.38, 0.2))
			_fp(img, ax + 3, 34, Color(0.92, 0.92, 0.95))
			_fp(img, ax + 2, 35, Color(0.85, 0.2, 0.2) if k % 2 else Color(0.92, 0.92, 0.95))
			_fp(img, ax + 4, 35, Color(0.85, 0.2, 0.2) if k % 2 else Color(0.92, 0.92, 0.95))
	if "pick" in extras:
		# A pick over the shoulder: its haft and iron head.
		for i in 16:
			_fp(img, 50 + i / 3, 50 - i, Color(0.55, 0.38, 0.2))
			_fp(img, 51 + i / 3, 50 - i, Color(0.42, 0.28, 0.14))
		for i in 11:
			var x := 49 + i
			var y := 34 - int(sin(i / 10.0 * PI) * 3.0)
			_fp(img, x, y, Color(0.6, 0.62, 0.66))
			_fp(img, x, y + 1, Color(0.42, 0.44, 0.48))
		_fp(img, 49, 35, OUTLINE)
		_fp(img, 59, 35, OUTLINE)
	if "pencil" in extras:
		for i in 7:
			_fp(img, int((cx + rx) * RES) - 2 + i, int(cy - 2) * RES + 1 - i / 3, Color(0.95, 0.8, 0.3) if i < 5 else Color(0.35, 0.3, 0.3))
	if "lashes" in extras and not ("calm" in extras):
		# A flick of lashes at the outer corner of each eye.
		var gap3 := 0 if rx < 7.0 else 1
		for side in [-1, 1]:
			var outer: int = ((13 - gap3) if side < 0 else (18 + gap3)) + side
			var lx := outer * RES + (0 if side < 0 else 1)
			_fp(img, lx, (int(cy) - 1) * RES, skin.darkened(0.55))
			_fp(img, lx + side, (int(cy) - 1) * RES - 1, skin.darkened(0.55))
	if "beads" in extras:
		# Prayer beads hung round the neck: round wooden beads, a red one at the bottom.
		for i in 11:
			var t := i / 10.0
			var bx := int(lerpf(23.0, 41.0, t))
			var by := 45 + int(sin(t * PI) * 9.0)
			var bead := Color(0.85, 0.2, 0.18) if i == 5 else Color(0.42, 0.26, 0.14)
			_fp(img, bx, by, bead)
			_fp(img, bx + 1, by, bead.darkened(0.25))
			_fp(img, bx, by + 1, bead.darkened(0.25))
			_fp(img, bx + 1, by + 1, bead.darkened(0.4))
			_fp(img, bx, by, bead.lightened(0.3))
	if "motes" in extras:
		# Motes of magic drifting round the hat.
		for p in [Vector2i(10, 8), Vector2i(14, 20), Vector2i(50, 22), Vector2i(54, 12), Vector2i(8, 30), Vector2i(57, 32)]:
			_fp(img, p.x, p.y, Color(1, 1, 1))
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				_fp(img, p.x + d.x, p.y + d.y, Color(0.8, 0.65, 1.0, 0.8))
	if "helm_shine" in extras:
		# Light catching the helm: a streak down its left side, a band of rivets.
		var top := int(cy - ry) * RES
		for i in 12:
			_fp(img, int((cx - rx + 1.5) * RES) + i / 6, top + 2 + i, cols[0].lightened(0.35))
		for x in range(int(cx - rx + 1) * RES, int(cx + rx) * RES, 4):
			_fp(img, x, int(cy - 2) * RES, cols[0].lightened(0.5))
			_fp(img, x + 1, int(cy - 2) * RES + 1, cols[0].darkened(0.4))
	if "teeth" in extras:
		# A necklace of trophy teeth.
		for i in 9:
			var t := i / 8.0
			var tx := int(lerpf(20.0, 44.0, t))
			var ty := 47 + int(sin(t * PI) * 6.0)
			_fp(img, tx, ty, Color(0.35, 0.25, 0.15))
			_fp(img, tx + 1, ty, Color(0.35, 0.25, 0.15))
			for k in 3:
				_fp(img, tx, ty + 1 + k, Color(0.95, 0.92, 0.8) if k < 2 else Color(0.8, 0.76, 0.66))
			_fp(img, tx + 1, ty + 1, Color(0.85, 0.82, 0.72))
	if "leaves" in extras:
		# Leaves stitched over the cloak, each a little pointed oval with a vein.
		var greens := [Color(0.36, 0.58, 0.26), Color(0.28, 0.48, 0.2), Color(0.5, 0.66, 0.3)]
		for k in 14:
			var lx := 6 + (k * 23) % 52
			var ly := 47 + (k * 11) % 16
			if img.get_pixel(lx, ly).a == 0.0:
				continue
			var g: Color = greens[k % 3]
			for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, -1)]:
				_fp(img, lx + d.x, ly + d.y, g)
			_fp(img, lx, ly + 1, g.darkened(0.3))
			_fp(img, lx + 1, ly, g.darkened(0.3))
	if "tools" in extras:
		# A pocket on the apron, a wrench and a screwdriver sticking out of it.
		for y in range(52, 58):
			for x in range(36, 43):
				_fp(img, x, y, cols[1].darkened(0.18) if y > 52 else cols[2].darkened(0.1))
		for i in 6:
			_fp(img, 38, 51 - i, Color(0.7, 0.72, 0.78))
		_fp(img, 37, 45, Color(0.7, 0.72, 0.78))
		_fp(img, 39, 45, Color(0.7, 0.72, 0.78))
		for i in 4:
			_fp(img, 41, 51 - i, Color(0.85, 0.25, 0.2) if i < 2 else Color(0.75, 0.77, 0.8))
	if "cloak" in extras:
		# A red cloak falling from the shoulders behind, a gold clasp at the collar.
		var red := Color(0.68, 0.16, 0.16)
		for y in range(48, OUT):
			for x in OUT:
				var edge := absf(x + 0.5 - 32.0)
				var half := minf(12.0 + (y - 44) * 3.4, 28.0)
				if img.get_pixel(x, y).a > 0.0 and edge > half - 3.0 and edge <= half:
					_fp(img, x, y, red if (y + x / 3) % 6 else red.darkened(0.2))
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			_fp(img, 22 + d.x, 46 + d.y, cols[2])
			_fp(img, 40 + d.x, 46 + d.y, cols[2])
	if "veil_trim" in extras:
		# Gold embroidery along the veil's edge, framing the face.
		var top := int(cy - ry) * RES
		for y in range(top + 4, int(cy + 6) * RES):
			if y % 3 == 0:
				_fp(img, int(cx - rx - 1) * RES + 1, y, cols[2])
				_fp(img, int(cx + rx + 1) * RES, y, cols[2].darkened(0.15))
	if "hat_band" in extras:
		var hb := int(cy - ry) * RES + 2
		for x in range(int(cx - rx - 2) * RES, int(cx + rx + 3) * RES):
			_fp(img, x, hb, cols[1].darkened(0.2))
			_fp(img, x, hb + 1, cols[1].darkened(0.35))
		var sx := int(cx * RES) - 1
		for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			_fp(img, sx + d.x, hb + d.y, Color(0.88, 0.9, 0.98))
	if "mark" in extras:
		# A red mark on the brow.
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			_fp(img, int(cx * RES) - 1 + d.x, int(cy - 4) * RES + d.y, Color(0.85, 0.2, 0.18))
	if "rivets" in extras:
		for p in [Vector2i(12, 50), Vector2i(16, 49), Vector2i(48, 50), Vector2i(44, 49)]:
			_fp(img, p.x, p.y, Color(0.9, 0.92, 0.98))
	if "chain" in extras:
		# A chain of office: gold links across the chest, a medallion hanging from it.
		for i in 22:
			var x := 21 + i
			var y := 47 + int(sin(i / 21.0 * PI) * 5.0)
			_fp(img, x, y, trim if i % 2 == 0 else trim.darkened(0.3))
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2)]:
			_fp(img, 31 + d.x, 52 + d.y, trim)
		_fp(img, 31, 53, Color(0.85, 0.2, 0.35))
	if "monocle" in extras:
		# A gold-rimmed monocle over the right eye, on a fine chain.
		var m := Vector2(18 * RES + 1.5, int(cy) * RES)
		for y in range(int(m.y) - 5, int(m.y) + 6):
			for x in range(int(m.x) - 5, int(m.x) + 6):
				var d := Vector2(x + 0.5, y + 0.5).distance_to(m)
				if d > 3.0 and d <= 4.1:
					_fp(img, x, y, cols[2] if y < m.y + 1 else cols[2].darkened(0.25))
				elif d <= 3.0:
					_fp(img, x, y, Color(0.85, 0.95, 1.0, 0.22))
		_fp(img, int(m.x) - 1, int(m.y) - 2, Color(1, 1, 1, 0.8))
		for i in 9:
			_fp(img, int(m.x) + 3 + int(i * 0.25), int(m.y) + 4 + i, cols[2].darkened(0.3))
	if "hoops" in extras:
		for side in [-1, 1]:
			var e := Vector2((cx + side * (rx + 0.6)) * RES, int(cy + 3) * RES + 2.5)
			for y in range(int(e.y) - 4, int(e.y) + 5):
				for x in range(int(e.x) - 3, int(e.x) + 4):
					var q := (Vector2(x + 0.5, y + 0.5) - e) / Vector2(2.2, 3.0)
					if q.length() > 0.62 and q.length() <= 1.0:
						_fp(img, x, y, cols[2])
	if "frost_marks" in extras:
		# Frost tracery on the cheekbones, glowing faintly.
		var ice := Color(0.5, 0.82, 1.0)
		for side in [-1, 1]:
			# From the outer corner of the eye, sweeping up and out over the temple.
			var bx := int((cx + side * 4.5) * RES) + (0 if side < 0 else 1)
			var by := int(cy) * RES + 2
			for i in 5:
				_fp(img, bx + side * i, by - i, ice)
			_fp(img, bx + side * 2, by - 3, ice.lightened(0.3))
			_fp(img, bx + side * 1, by + 1, ice)
	if "brooch" in extras:
		var c := Vector2i(31, 46)
		for d in [Vector2i(0, -2), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)]:
			_fp(img, c.x + d.x, c.y + d.y, Color(0.55, 0.9, 1.0))
		_fp(img, c.x - 1, c.y - 1, Color(1, 1, 1))
		_fp(img, c.x + 1, c.y + 1, Color(0.3, 0.6, 0.9))
	if "ruff" in extras:
		# A white lace ruff round the neck.
		for x in range(20, 44):
			var y := 44 + (1 if x % 3 == 0 else 0)
			_fp(img, x, y, Color(0.97, 0.95, 0.9))
			_fp(img, x, y + 1, Color(0.97, 0.95, 0.9) if x % 2 == 0 else Color(0.82, 0.8, 0.78))
			_fp(img, x, y + 2, Color(0.88, 0.86, 0.82) if x % 3 != 1 else Color(0, 0, 0, 0))


# --- Backdrops: a glimpse of each homeland behind the figure (at the real resolution) ---

static func _scene(out: Image, scene: String, bg: Array) -> void:
	var far: Color = (bg[1] as Color).lerp(bg[0], 0.35)
	var near: Color = (bg[1] as Color).darkened(0.25)
	match scene:
		"keep":
			# The keep's battlements along the bottom, a tower to the left, a banner on it.
			_band(out, 46, func(x): return 46 - (4 if (x / 4) % 2 == 0 else 0), far)
			_box(out, 2, 26, 12, 38, near)
			for x in range(2, 14, 4):
				_box(out, x, 23, 2, 3, near)
			_box(out, 7, 31, 2, 4, Color(1.0, 0.8, 0.4))
			_box(out, 13, 12, 1, 14, near)
			_box(out, 14, 12, 7, 4, Color(0.25, 0.36, 0.72))
			_box(out, 14, 15, 7, 1, Color(0.95, 0.8, 0.3))
			_clouds(out, [Vector2i(44, 10), Vector2i(54, 16)], (bg[0] as Color).lightened(0.25))
		"forge":
			# Cogs turning on the wall, the forge glowing low, sparks.
			_cog(out, Vector2(52, 14), 9.0, far)
			_cog(out, Vector2(41, 7), 5.0, far.darkened(0.1))
			_cog(out, Vector2(8, 22), 6.0, far)
			for y in range(40, 64):
				for x in 64:
					var k := clampf(1.0 - Vector2(x, y).distance_to(Vector2(6, 62)) / 26.0, 0.0, 1.0)
					if k > 0.0:
						out.set_pixel(x, y, out.get_pixel(x, y).lerp(Color(1.0, 0.55, 0.2), k * 0.6))
			for p in [Vector2i(10, 40), Vector2i(16, 34), Vector2i(6, 30), Vector2i(20, 44), Vector2i(13, 27)]:
				out.set_pixel(p.x, p.y, Color(1.0, 0.85, 0.4))
		"forest":
			# Pines either side, a light shaft through them.
			for t in [[3, 6, 58], [12, 14, 52], [52, 4, 60], [60, 10, 54]]:
				_pine(out, t[0], t[1], t[2], near if t[1] < 10 else far)
			for y in 64:
				for x in range(26 + y / 3, 34 + y / 3):
					if x < 64:
						out.set_pixel(x, y, out.get_pixel(x, y).lerp(Color(1, 1, 0.8), 0.08))
		"mine":
			# Timber props and a beam framing the tunnel, lanterns hung from it.
			var wood := Color(0.36, 0.24, 0.14)
			_box(out, 0, 6, 64, 5, wood)
			_box(out, 0, 10, 64, 1, wood.darkened(0.3))
			_box(out, 2, 6, 5, 58, wood)
			_box(out, 57, 6, 5, 58, wood)
			for lx in [14, 50]:
				_box(out, lx, 11, 1, 4, Color(0.2, 0.2, 0.2))
				_glow(out, Vector2(lx + 0.5, 17), 7.0, Color(1.0, 0.8, 0.35), 0.35)
				_box(out, lx - 1, 15, 3, 4, Color(1.0, 0.85, 0.45))
		"shrine":
			# The morning sun behind, its rays, and the Sanctuary's dome below.
			for i in 10:
				var ang := -PI + i * PI / 9.0
				for r in range(10, 46):
					var p := Vector2(32, 14) + Vector2.from_angle(ang) * r
					if p.x >= 0 and p.y >= 0 and p.x < 64 and p.y < 64:
						out.set_pixel(int(p.x), int(p.y), out.get_pixel(int(p.x), int(p.y)).lerp(Color(1, 0.98, 0.85), 0.25))
			_glow(out, Vector2(32, 14), 10.0, Color(1, 0.97, 0.8), 0.6)
			_dome(out, Vector2(9, 60), 9.0, Color(0.95, 0.8, 0.4).darkened(0.1))
			_dome(out, Vector2(56, 62), 7.0, Color(0.95, 0.8, 0.4).darkened(0.2))
		"north":
			# An aurora over snowy peaks, snow falling.
			for x in 64:
				var y0 := 9.0 + sin(x / 9.0) * 4.0 + sin(x / 4.0) * 1.2
				for k in 7:
					var y := int(y0 + k)
					var c := Color(0.45, 1.0, 0.75).lerp(Color(0.4, 0.75, 1.0), k / 7.0)
					out.set_pixel(x, y, out.get_pixel(x, y).lerp(c, 0.45 * (1.0 - k / 8.0)))
			_peaks(out, [Vector2(-4, 64), Vector2(10, 40), Vector2(22, 64)], far, Color(0.92, 0.96, 1.0))
			_peaks(out, [Vector2(40, 64), Vector2(54, 36), Vector2(70, 64)], far, Color(0.92, 0.96, 1.0))
			for i in 26:
				var p := Vector2i((i * 37) % 64, (i * 23 + i * i) % 64)
				out.set_pixel(p.x, p.y, Color(1, 1, 1, 1).lerp(out.get_pixel(p.x, p.y), 0.25))
		"city":
			# The sun going down behind the Free Cities' roofs, domes and towers, windows lit.
			_glow(out, Vector2(46, 30), 11.0, Color(1.0, 0.85, 0.5), 0.75)
			var roofs := [[0, 44, 10], [9, 38, 7], [15, 47, 9], [46, 40, 8], [53, 34, 5], [57, 44, 7]]
			for r in roofs:
				_box(out, r[0], r[1], r[2], 64 - r[1], near)
				_box(out, r[0] + r[2] / 2 - 1, r[1] - 3, 2, 3, near)
				for wy in range(r[1] + 3, 64, 5):
					if (r[0] + wy) % 3 != 0:
						_box(out, r[0] + 2, wy, 2, 2, Color(1.0, 0.82, 0.45))
			_dome(out, Vector2(8, 38), 5.0, near)
			_box(out, 7, 28, 2, 6, near)
			_dome(out, Vector2(56, 34), 4.0, near)
		"monastery":
			# Peaks in mist, the sun, and the monastery's sweeping roof.
			_glow(out, Vector2(50, 14), 7.0, Color(1.0, 0.95, 0.75), 0.8)
			_peaks(out, [Vector2(-6, 64), Vector2(12, 26), Vector2(30, 64)], far.darkened(0.22), Color(0.98, 0.94, 0.9))
			_peaks(out, [Vector2(36, 64), Vector2(56, 30), Vector2(72, 64)], far.darkened(0.3), Color(0.98, 0.94, 0.9))
			for x in range(0, 18):
				var y := 50 - int(sin(x / 17.0 * PI) * 3.0)
				_box(out, x, y, 1, 2, near)
			_box(out, 3, 52, 12, 12, near)
			for y in [44, 56]:
				for x in 64:
					out.set_pixel(x, y, out.get_pixel(x, y).lerp(Color(1, 1, 1), 0.18))
		"spires":
			# Stars, a crescent moon, the Spires.
			for i in 30:
				var p := Vector2i((i * 29 + 7) % 64, (i * 17 + i * 3) % 40)
				out.set_pixel(p.x, p.y, Color(1, 1, 0.9) if i % 4 else Color(0.8, 0.75, 1.0))
			_glow(out, Vector2(50, 10), 5.0, Color(1, 1, 0.85), 1.0)
			_glow(out, Vector2(52, 8), 4.5, (bg[0] as Color), 1.0)
			for s2 in [[4, 30, 3], [10, 36, 2], [54, 32, 3], [59, 40, 2]]:
				for y in range(s2[1], 64):
					var half := int(s2[2] * clampf((y - s2[1]) / 8.0, 0.3, 1.0))
					_box(out, s2[0] - half, y, half * 2 + 1, 1, near)
				_glow(out, Vector2(s2[0], s2[1] + 8), 2.0, Color(0.8, 0.6, 1.0), 0.8)
		"ogre":
			# Flames along the bottom, smoke and embers over them.
			for x in 64:
				var h := 10 + int(abs(sin(x * 0.7) * 6.0 + sin(x * 0.23) * 5.0))
				for y in range(64 - h, 64):
					var k := (y - (64 - h)) / float(h)
					out.set_pixel(x, y, Color(1.0, 0.85, 0.3).lerp(Color(0.85, 0.2, 0.08), k))
			_clouds(out, [Vector2i(8, 14), Vector2i(52, 8), Vector2i(30, 4)], Color(0.15, 0.08, 0.08, 1.0))
			for i in 14:
				out.set_pixel((i * 41) % 64, (i * 29) % 46, Color(1.0, 0.6, 0.2))
		"embers":
			# Ash and embers drifting up, a burnt banner's rag.
			for i in 20:
				var p := Vector2i((i * 37 + 3) % 64, (i * 19 + i * i) % 64)
				out.set_pixel(p.x, p.y, Color(1.0, 0.55, 0.15) if i % 3 else Color(0.6, 0.55, 0.55))
			_box(out, 54, 6, 1, 30, near)
			for y in range(7, 20):
				_box(out, 55, y, 6 - (y % 3), 1, Color(0.45, 0.12, 0.1))


static func _box(out: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(maxi(0, y), mini(OUT, y + h)):
		for xx in range(maxi(0, x), mini(OUT, x + w)):
			out.set_pixel(xx, yy, c if c.a >= 1.0 else out.get_pixel(xx, yy).blend(c))


static func _band(out: Image, _y0: int, top: Callable, c: Color) -> void:
	for x in OUT:
		_box(out, x, int(top.call(x)), 1, OUT, c)


static func _glow(out: Image, at: Vector2, r: float, c: Color, strength: float) -> void:
	for y in range(maxi(0, int(at.y - r * 2)), mini(OUT, int(at.y + r * 2) + 1)):
		for x in range(maxi(0, int(at.x - r * 2)), mini(OUT, int(at.x + r * 2) + 1)):
			var d := Vector2(x, y).distance_to(at)
			var k := 1.0 if d <= r else clampf(1.0 - (d - r) / r, 0.0, 1.0) * 0.4
			if k > 0.0:
				out.set_pixel(x, y, out.get_pixel(x, y).lerp(c, k * strength))


static func _dome(out: Image, at: Vector2, r: float, c: Color) -> void:
	for y in range(int(at.y - r), int(at.y) + 1):
		for x in range(int(at.x - r), int(at.x + r) + 1):
			if x >= 0 and y >= 0 and x < OUT and y < OUT and Vector2(x, y).distance_to(at) <= r:
				out.set_pixel(x, y, c)
	_box(out, int(at.x - r), int(at.y), int(r * 2) + 1, OUT, c)


static func _cog(out: Image, at: Vector2, r: float, c: Color) -> void:
	for y in range(int(at.y - r - 3), int(at.y + r + 4)):
		for x in range(int(at.x - r - 3), int(at.x + r + 4)):
			if x < 0 or y < 0 or x >= OUT or y >= OUT:
				continue
			var off := Vector2(x, y) - at
			var d := off.length()
			var tooth := fmod(off.angle() + TAU, TAU / 8.0) < TAU / 16.0
			if (d <= r or (tooth and d <= r + 2.5)) and d > r * 0.35:
				out.set_pixel(x, y, c)


static func _pine(out: Image, x0: int, top: int, bottom: int, c: Color) -> void:
	for y in range(top, bottom):
		var half := int((y - top) * 0.32) + 1
		if (y - top) % 6 == 5:
			half -= 2
		_box(out, x0 - half, y, half * 2 + 1, 1, c)
	_box(out, x0, bottom, 2, OUT - bottom, c.darkened(0.2))


static func _peaks(out: Image, tri: Array, c: Color, snow: Color) -> void:
	var poly := PackedVector2Array(tri)
	for y in OUT:
		for x in OUT:
			if Geometry2D.is_point_in_polygon(Vector2(x, y), poly):
				var cap: bool = y < (tri[1] as Vector2).y + 7 + (x % 3)
				out.set_pixel(x, y, snow if cap else c)


static func _clouds(out: Image, at: Array, c: Color) -> void:
	for p in at:
		for d in [Vector2(0, 0), Vector2(4, -2), Vector2(8, 0), Vector2(4, 1)]:
			_glow(out, Vector2(p) + d, 3.0, c, 0.7)


# --- Parts --------------------------------------------------------------------------

static func _face(img: Image, cx: float, cy: float, rx: float, look: Dictionary, skin: Color, hair: Color, extras: Array) -> void:
	var eye: Color = look.get("eyes", Color(0.12, 0.1, 0.12))
	var glow := "glow" in extras
	# Eyes mirror each other across the face's centre line (between pixels 15 and 16): a
	# pupil two pixels tall on the inside, the white of the eye on the outside, and a
	# brow above. A wider head (the Ogre King) sets them a pixel further apart.
	var gap := 0 if rx < 7.0 else 1
	var ey := int(cy)
	for side in [-1, 1]:
		var inner: int = (13 - gap) if side < 0 else (18 + gap)
		var outer: int = inner + side
		if "calm" in extras:
			# Closed, in thought: a short dark line.
			_px(img, inner, ey, skin.darkened(0.5))
			_px(img, outer, ey, skin.darkened(0.5))
		elif glow:
			_px(img, inner, ey, eye.lightened(0.45))
			_px(img, inner, ey - 1, eye)
			_px(img, outer, ey, eye)
		else:
			_px(img, inner, ey, eye)
			_px(img, inner, ey - 1, eye)
			_px(img, outer, ey, Color(0.96, 0.96, 0.94))
			_px(img, outer, ey - 1, skin.darkened(0.12))
		_px(img, inner, ey - 3, hair.darkened(0.25))
		_px(img, outer, ey - 3, hair.darkened(0.25))
	# Nose and mouth.
	_px(img, int(cx), int(cy + 2), skin.darkened(0.22))
	for x in range(int(cx - 1), int(cx + 2)):
		_px(img, x, int(cy + 4), skin.darkened(0.4))
	if "scar" in extras:
		for i in 3:
			_px(img, int(cx + 2 + i * 0.5), int(cy + 1 + i), Color(0.75, 0.4, 0.38))
	if "soot" in extras:
		for p in [Vector2i(int(cx - 3), int(cy + 2)), Vector2i(int(cx - 4), int(cy + 3)), Vector2i(int(cx + 3), int(cy + 3))]:
			_px(img, p.x, p.y, skin.darkened(0.35))
	if "tattoo" in extras:
		for i in 3:
			_px(img, int(cx - 4), int(cy + 1 + i), Color(0.35, 0.65, 1.0))
		_px(img, int(cx - 3), int(cy + 2), Color(0.35, 0.65, 1.0))
	if "wrinkles" in extras:
		_px(img, int(cx - 4), int(cy + 2), skin.darkened(0.2))
		_px(img, int(cx + 4), int(cy + 2), skin.darkened(0.25))


static func _hair(img: Image, style: String, cx: float, cy: float, rx: float, ry: float, hair: Color, head: String) -> void:
	if style == "bald" or head == "veil":
		if style == "bald" and head == "":
			# A fringe of hair around the sides.
			for y in range(int(cy - 2), int(cy + 2)):
				_px(img, int(cx - rx), y, hair)
				_px(img, int(cx + rx), y, hair.darkened(0.15))
		return
	var hi := hair.lightened(0.15)
	if style == "topknot":
		_ellipse(img, cx, cy - ry - 1, 2.0, 1.6, hair)
		return
	# A cap of hair over the top of the head, down to the ears at the sides.
	for y in SIZE:
		for x in SIZE:
			var top := y < cy - 2.5 and _in_ellipse(x, y, cx, cy, rx + 1, ry + 1)
			var side := y < cy + 1.5 and _in_ellipse(x, y, cx, cy, rx + 1, ry + 1) and absf(x + 0.5 - cx) > rx - 1.2
			if top or side:
				_px(img, x, y, hi if y < cy - 4 and x < cx - 1 and (x + y) % 3 == 0 else hair)
	if style == "bun":
		_ellipse(img, cx, cy - ry - 1.5, 2.6, 2.0, hair)
	if style == "braid":
		for i in 9:
			var y := int(cy + 2 + i)
			var x := int(cx + rx + 1 + (i % 2))
			_px(img, x, y, hair if i % 3 != 2 else hair.darkened(0.3))
			_px(img, x - 1, y, hair.darkened(0.1))


static func _beard(img: Image, beard: String, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	if beard == "":
		return
	var low := cy + (ry + 4.0 if beard == "full" else ry + 1.0)
	for y in range(int(cy + 2), int(low)):
		for x in SIZE:
			var in_face := _in_ellipse(x, y, cx, cy + 1.5, rx + 0.5, ry + (3.5 if beard == "full" else 0.5))
			if in_face and (y > cy + 3 or absf(x + 0.5 - cx) > 2.0):
				_px(img, x, y, col if (x + y) % 4 != 0 else col.darkened(0.12))
	# The mouth shows through.
	for x in range(int(cx - 1), int(cx + 2)):
		_px(img, x, int(cy + 4), col.darkened(0.45))


static func _headwear(img: Image, head: String, cx: float, cy: float, rx: float, ry: float, cols: Array, skin: Color) -> void:
	var top := int(cy - ry)
	match head:
		"goggles":
			_rect(img, int(cx - rx - 1), top + 2, int(rx * 2 + 3), 2, Color(0.35, 0.22, 0.12))
			for lx in [int(cx - 3.5), int(cx + 1.5)]:
				_rect(img, lx, top + 1, 3, 3, cols[2])
				_px(img, lx + 1, top + 2, Color(0.55, 0.85, 0.95))
		"miner":
			_ellipse(img, cx, top + 2, rx + 1.5, 4.0, cols[2])
			_rect(img, int(cx - rx - 2), top + 3, int(rx * 2 + 5), 2, cols[2].darkened(0.2))
			_rect(img, int(cx - 1), top - 1, 3, 3, Color(1.0, 0.95, 0.55))
			_px(img, int(cx), top, Color(1, 1, 0.9))
		"veil":
			_rect(img, int(cx - rx - 1), top + 1, int(rx * 2 + 3), 3, cols[0])
			_rect(img, int(cx - rx - 1), top + 3, int(rx * 2 + 3), 1, cols[2])
			for y in range(top + 3, int(cy + 6)):
				_px(img, int(cx - rx - 1), y, cols[0])
				_px(img, int(cx + rx + 1), y, cols[0].darkened(0.1))
		"fur":
			_rect(img, int(cx - rx - 2), top, int(rx * 2 + 5), 4, cols[1])
			for x in range(int(cx - rx - 2), int(cx + rx + 3), 2):
				_px(img, x, top + (x % 3), cols[1].darkened(0.15))
		"feather_hat":
			_rect(img, int(cx - rx - 4), top + 2, int(rx * 2 + 9), 2, cols[0].darkened(0.15))
			_rect(img, int(cx - rx + 1), top - 3, int(rx * 2 - 1), 5, cols[0])
			_rect(img, int(cx - rx + 1), top + 1, int(rx * 2 - 1), 1, cols[2])
			for i in 7:
				_px(img, int(cx + rx + 1 + i * 0.6), top - 2 - i, cols[1] if i < 5 else Color(1, 1, 1))
		"wizard":
			for y in range(0, top + 3):
				var half := (y + 1) * (rx + 3) / float(top + 3)
				var lean := (top + 3 - y) * 0.35
				for x in SIZE:
					if absf(x + 0.5 - (cx + lean)) <= half:
						_px(img, x, y, cols[0] if (x * 7 + y * 3) % 11 != 0 else cols[2])
			_rect(img, int(cx - rx - 3), top + 2, int(rx * 2 + 7), 2, cols[0].darkened(0.2))
		"crown":
			_rect(img, int(cx - rx + 1), top - 1, int(rx * 2 - 1), 3, cols[2])
			for x in [int(cx - rx + 1), int(cx - 1), int(cx + 1), int(cx + rx - 1)]:
				_px(img, x, top - 2, cols[2])
				_px(img, x, top - 3, cols[2])
			_px(img, int(cx), top, Color(0.9, 0.15, 0.15))
		"horned":
			# A helm over the head and cheeks, an ember slit for eyes, horns sweeping out.
			for y in range(top - 1, int(cy + 3)):
				for x in SIZE:
					if _in_ellipse(x, y, cx, cy - 0.5, rx + 1.2, ry + 1.2) and not (y > cy - 1 and absf(x + 0.5 - cx) < 2.0):
						_px(img, x, y, cols[0] if x < cx + rx - 1 else cols[0].darkened(0.25))
			_rect(img, int(cx - 4), int(cy), 9, 1, Color(1.0, 0.55, 0.15))
			for i in 6:
				_px(img, int(cx - rx - 1 - i), int(top + 2 - i * 0.8), Color(0.85, 0.8, 0.7))
				_px(img, int(cx + rx + 1 + i), int(top + 2 - i * 0.8), Color(0.75, 0.7, 0.6))
				if i < 4:
					_px(img, int(cx - rx - 1 - i), int(top + 3 - i * 0.8), Color(0.72, 0.66, 0.58))
					_px(img, int(cx + rx + 1 + i), int(top + 3 - i * 0.8), Color(0.62, 0.57, 0.5))
		"ice_crown":
			# A silver circlet with a crown of ice shards rising from it, tallest in the middle.
			for x in range(int(cx - rx), int(cx + rx + 1)):
				_px(img, x, top + 2, Color(0.78, 0.82, 0.9))
			var ice := Color(0.72, 0.92, 1.0)
			for k in [[-5, 2], [-3, 4], [-1, 6], [0, 7], [2, 5], [4, 3], [6, 2]]:
				var x: int = int(cx) + k[0]
				for h in k[1]:
					_px(img, x, top + 1 - h, ice if h < k[1] - 1 else Color(0.95, 1.0, 1.0))
			_px(img, int(cx), top + 2, Color(0.4, 0.75, 1.0))
		"comb":
			# Her hair up, held with a jewelled gold comb and two long pins.
			_px(img, int(cx + 2), top - 2, cols[2])
			_px(img, int(cx + 3), top - 2, cols[2])
			_px(img, int(cx + 2), top - 3, Color(0.85, 0.2, 0.35))
			for i in 3:
				_px(img, int(cx - 3 - i), top - 2 - i, Color(0.9, 0.88, 0.8))
		"circlet":
			for x in range(int(cx - rx), int(cx + rx + 1)):
				_px(img, x, top + 3, cols[0].lightened(0.2))
			for x in [int(cx - 3), int(cx), int(cx + 3)]:
				_px(img, x, top + 2, cols[0].lightened(0.35))
				_px(img, x + 1, top + 2, cols[0])


static func _outfit(img: Image, outfit: String, cols: Array, skin: Color, extras: Array) -> void:
	var main: Color = cols[0]
	var second: Color = cols[1]
	var trim: Color = cols[2]
	# Shoulders: wider the lower they go.
	for y in range(22, SIZE):
		var half := minf(6.0 + (y - 22) * 1.7, 14.0)
		for x in SIZE:
			if absf(x + 0.5 - 16.0) <= half:
				_px(img, x, y, main if x < 22 else main.darkened(0.15))
	match outfit:
		"tabard":
			for side in [7.0, 24.0]:
				_ellipse(img, side, 25.5, 3.5, 2.5, second)
				_px(img, int(side) - 1, 24, second.lightened(0.3))
			_rect(img, 12, 23, 8, 9, main.lightened(0.08))
			_rect(img, 15, 26, 2, 2, trim)
			_rect(img, 12, 23, 8, 1, trim)
		"apron":
			_rect(img, 11, 25, 10, 7, second)
			for i in 3:
				_px(img, 11 - i, 23 + i, OUTLINE.lightened(0.2))
				_px(img, 20 + i, 23 + i, OUTLINE.lightened(0.2))
			_px(img, 13, 28, trim)
			_px(img, 18, 28, trim)
		"leaf_cloak":
			for y in range(22, SIZE):
				for x in SIZE:
					if _at(img, x, y).a > 0.0 and (x * 3 + y * 5) % 7 == 0:
						_px(img, x, y, second)
			_rect(img, 15, 23, 2, 2, trim)
		"overalls":
			_rect(img, 11, 26, 10, 6, second)
			for y in range(22, 27):
				_px(img, 12, y, second.darkened(0.2))
				_px(img, 19, y, second.darkened(0.2))
			_px(img, 12, 26, trim)
			_px(img, 19, 26, trim)
		"robe":
			_rect(img, 15, 23, 2, 9, trim)
			for x in range(10, 22):
				_px(img, x, 22 + int(absf(x - 15.5) * 0.4), trim)
		"fur_mantle":
			for y in range(22, 26):
				for x in SIZE:
					if _at(img, x, y).a > 0.0:
						_px(img, x, y, second if (x + y) % 3 != 0 else second.darkened(0.12))
			_px(img, 15, 26, trim)
			_px(img, 16, 26, trim)
		"frost_mantle":
			# A deep blue mantle, a thick collar of white fur up round the neck, frost
			# embroidery running down the front.
			for y in range(21, 26):
				for x in SIZE:
					var on := _at(img, x, y).a > 0.0 or (y < 23 and absf(x + 0.5 - 16.0) <= 9.0)
					if on and absf(x + 0.5 - 16.0) <= 4.0 + (y - 21) * 2.5:
						_px(img, x, y, second if (x * 2 + y) % 3 != 0 else second.darkened(0.1))
			for x in [12, 19]:
				for y in range(26, SIZE):
					if y % 2 == 0:
						_px(img, x, y, trim)
		"magistrate":
			# A high-collared coat, lapels turned back, gold buttons down the front.
			for i in 6:
				_px(img, 15 - i, 23 + i, second)
				_px(img, 16 + i, 23 + i, second)
				_px(img, 14 - i, 23 + i, second.darkened(0.15))
				_px(img, 17 + i, 23 + i, second.darkened(0.25))
			for y in range(27, SIZE, 2):
				_px(img, 15, y, trim)
			for side in [4.0, 27.0]:
				_px(img, int(side), 24, main.lightened(0.15))
		"doublet":
			for x in range(4, 28, 3):
				for y in range(26, SIZE):
					if _at(img, x, y).a > 0.0:
						_px(img, x, y, second)
			for x in range(10, 22):
				_px(img, x, 22 + (x % 2), trim)
				_px(img, x, 23, trim)
		"monk":
			for i in 9:
				_px(img, 12 + i, 23 + i, second)
				_px(img, 12 + i, 24 + i, second)
		"star_robe":
			for p in [Vector2i(6, 28), Vector2i(10, 25), Vector2i(21, 27), Vector2i(25, 30), Vector2i(14, 30), Vector2i(18, 25)]:
				_px(img, p.x, p.y, trim)
			_rect(img, 13, 22, 6, 2, second)
		"armor":
			for y in [25, 28, 31]:
				for x in SIZE:
					if _at(img, x, y).a > 0.0:
						_px(img, x, y, second)
			for side in [6.0, 25.0]:
				_ellipse(img, side, 25.0, 4.0, 3.0, main.lightened(0.1))
				_px(img, int(side), 24, trim)
		"ogre":
			for i in 7:
				_px(img, 10 + i * 2, 24 + int(absf(i - 3) * 0.6), trim)
	if "beads" in extras:
		for i in 9:
			_px(img, 11 + i, 24 + int(absf(i - 4) * -0.5 + 2), Color(0.45, 0.28, 0.15))


static func _outline(img: Image) -> void:
	var src := img.duplicate()
	for y in OUT:
		for x in OUT:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < OUT and n.y < OUT and src.get_pixel(n.x, n.y).a > 0.0:
					img.set_pixel(x, y, OUTLINE)
					break


## Lights the figure from the upper left at the fine resolution: a fine line of light
## just inside its top and left edges, a shade inside its bottom and right ones.
## The light each backdrop throws on the figure's right side (see _light).
const RIMS := {
	"keep": Color(0.75, 0.85, 1.0, 0.25), "forge": Color(1.0, 0.6, 0.3, 0.45), "forest": Color(0.75, 1.0, 0.6, 0.25),
	"mine": Color(1.0, 0.8, 0.4, 0.4), "shrine": Color(1.0, 0.95, 0.75, 0.4), "north": Color(0.6, 0.9, 1.0, 0.45),
	"city": Color(1.0, 0.72, 0.45, 0.45), "monastery": Color(1.0, 0.88, 0.62, 0.35), "spires": Color(0.8, 0.62, 1.0, 0.45),
	"ogre": Color(1.0, 0.5, 0.2, 0.55), "embers": Color(1.0, 0.5, 0.2, 0.45),
}


static func _light(img: Image, rim := Color(0, 0, 0, 0)) -> void:
	var src: Image = img.duplicate()
	for y in range(1, OUT - 1):
		for x in range(1, OUT - 1):
			var c := src.get_pixel(x, y)
			if c.a == 0.0 or c.is_equal_approx(OUTLINE):
				continue
			var up := src.get_pixel(x, y - 1)
			var left := src.get_pixel(x - 1, y)
			var right := src.get_pixel(x + 1, y)
			var down := src.get_pixel(x, y + 1)
			if up.a == 0.0 or left.a == 0.0:
				img.set_pixel(x, y, c.lerp(Color.WHITE, 0.16))
			elif right.a == 0.0 and rim.a > 0.0:
				# The backdrop's light catching its right edge.
				img.set_pixel(x, y, c.lerp(Color(rim.r, rim.g, rim.b), rim.a))
				var inner := src.get_pixel(x - 1, y)
				if inner.a > 0.0:
					img.set_pixel(x - 1, y, inner.lerp(Color(rim.r, rim.g, rim.b), rim.a * 0.4))
			elif right.a == 0.0 or down.a == 0.0:
				img.set_pixel(x, y, c.darkened(0.18))


# --- Pixel helpers --------------------------------------------------------------------

## A cell of the figure's grid (RES x RES real pixels).
static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < SIZE and y < SIZE:
		img.fill_rect(Rect2i(x * RES, y * RES, RES, RES), c)


## One real pixel, for the fine detail (coordinates on the real picture, 0 to OUT - 1).
static func _fp(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < OUT and y < OUT:
		if c.a < 1.0:
			img.set_pixel(x, y, img.get_pixel(x, y).blend(c))
		else:
			img.set_pixel(x, y, c)


## What's at a cell of the figure's grid.
static func _at(img: Image, x: int, y: int) -> Color:
	return img.get_pixel(x * RES, y * RES)


static func _in_ellipse(x: int, y: int, cx: float, cy: float, rx: float, ry: float) -> bool:
	var dx := (x + 0.5 - cx) / rx
	var dy := (y + 0.5 - cy) / ry
	return dx * dx + dy * dy <= 1.0


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(maxi(0, int(cy - ry - 1)), mini(SIZE, int(cy + ry + 2))):
		for x in range(maxi(0, int(cx - rx - 1)), mini(SIZE, int(cx + rx + 2))):
			if _in_ellipse(x, y, cx, cy, rx, ry):
				_px(img, x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(maxi(0, y), mini(SIZE, y + h)):
		for xx in range(maxi(0, x), mini(SIZE, x + w)):
			_px(img, xx, yy, c)
