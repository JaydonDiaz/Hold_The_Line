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

const SIZE := 32
const OUTLINE := Color(0.1, 0.07, 0.1)

static var _cache := {}


static func texture(id: String, look: Dictionary) -> ImageTexture:
	if not _cache.has(id):
		_cache[id] = ImageTexture.create_from_image(image(look))
	return _cache[id]


static func image(look: Dictionary) -> Image:
	var fig := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
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
				fig.set_pixel(x, y, skin.darkened(0.12))   # shade on the right
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
			fig.set_pixel(x, int(cy + 4), Color(0.95, 0.92, 0.8))
			fig.set_pixel(x, int(cy + 3), Color(0.95, 0.92, 0.8))
	if "earring" in extras:
		_px(fig, int(cx - rx - 1), int(cy + 3), cols[2])
	_outline(fig)
	# The backdrop: the region's colours, light at the top.
	var bg: Array = look.get("bg", [Color(0.3, 0.35, 0.5), Color(0.15, 0.17, 0.25)])
	var out := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		var c: Color = (bg[0] as Color).lerp(bg[1], y / float(SIZE - 1))
		for x in SIZE:
			# A little dither between bands so the gradient reads as pixel art.
			var k := c.lightened(0.05) if (x + y) % 4 == 0 and y % 3 == 0 else c
			out.set_pixel(x, y, k)
	out.blend_rect(fig, Rect2i(0, 0, SIZE, SIZE), Vector2i.ZERO)
	return out


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
				_px(img, x, y, hi if (x + y) % 5 == 0 and y < cy - 4 else hair)
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
					if img.get_pixel(x, y).a > 0.0 and (x * 3 + y * 5) % 7 == 0:
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
					if img.get_pixel(x, y).a > 0.0:
						_px(img, x, y, second if (x + y) % 3 != 0 else second.darkened(0.12))
			_px(img, 15, 26, trim)
			_px(img, 16, 26, trim)
		"doublet":
			for x in range(4, 28, 3):
				for y in range(26, SIZE):
					if img.get_pixel(x, y).a > 0.0:
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
					if img.get_pixel(x, y).a > 0.0:
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
	for y in SIZE:
		for x in SIZE:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < SIZE and n.y < SIZE and src.get_pixel(n.x, n.y).a > 0.0:
					_px(img, x, y, OUTLINE)
					break


# --- Pixel helpers --------------------------------------------------------------------

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < SIZE and y < SIZE:
		img.set_pixel(x, y, c)


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
