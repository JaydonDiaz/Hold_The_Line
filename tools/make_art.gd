extends SceneTree
## Builds the boot splash (res://splash.png) and the app icon (res://icon.png). The
## troops are the game's own sprites, in their poses (the Swordsman in his idle stance,
## sword planted in front of him), each pixel drawn 3x3; everything is laid out on a
## canvas a third of the game's 640x1040 and
## tripled, pixel for pixel. Positions below are given on a 320x520 layout (D) and
## scaled onto the canvas. No dithering or noise: flat colors and clean bands.
##
## Run from the project folder:  Godot --headless --path . -s tools/make_art.gd

const HD = preload("res://tools/hd_troops.gd")   # the app icon's tower
const Sprites = preload("res://scripts/sprites.gd")
const SPRITE_SCALE := 3

const W := 214   # the canvas: 640x1040 / 3 (rounded up; the extra pixel is trimmed)
const H := 347
const K := 214.0 / 320.0   # layout units (320x520) to canvas pixels
const INK := Color(0.07, 0.05, 0.08)

var canvas: Image
var hd := HD.new()


func _initialize() -> void:
	_make_splash()
	_make_icon()
	quit()


# --- Splash ----------------------------------------------------------------------

func _make_splash() -> void:
	canvas = Image.create(W, H, false, Image.FORMAT_RGBA8)
	_sky()
	_ogre_king()
	_hills()
	_ground()
	# Back row, middle row, front row, drawn back to front: [feet y, troops, light].
	var rows := [
		[362, [["bard", "serenade", 112, true], ["alchemist", "catch", 208, false]], 0.78],
		[430, [["mage", "", 66, true], ["healer", "raise", 160, false], ["frost", "", 254, false]], 0.9],
		[490, [["archer", "draw", 62, true], ["martial", "stance", 258, false]], 1.0],
		[516, [["swordsman", "plant", 160, false]], 1.0],   # out in front of the others
	]
	for row in rows:
		var feet: int = row[0]
		var light: float = row[2]
		for spec in row[1]:
			var kind: String = spec[0]
			var x: int = spec[2]
			var flip: bool = spec[3]   # mirrored to face left
			var foot := Vector2(x, feet) * K
			_shadow(foot, 18.0)
			if kind == "healer":
				_healing_aura(foot)
			var src := _sprite(kind, spec[1])
			var art := src.duplicate()
			art.resize(src.get_width() * SPRITE_SCALE, 16 * SPRITE_SCALE, Image.INTERPOLATE_NEAREST)
			if flip:
				art.flip_x()
			# Stand each one on its spot by its feet (the middle of its boots), not by the
			# middle of its 16-pixel box: weapons and staves make the boxes lopsided.
			var at := Vector2i(roundi(foot.x - _feet_centre(art)), roundi(foot.y) - 16 * SPRITE_SCALE)
			_put(art, at, light)
			# The spell gathers on the orb at the top of the staff.
			var t := _staff_tip(src) if kind != "healer" else Vector2i(7, 0)   # the Healer holds his up in front
			var tx := (src.get_width() - 1 - t.x) if flip else t.x
			var tip := Vector2(at) + (Vector2(tx, t.y) + Vector2(0.5, 1.5)) * SPRITE_SCALE
			match kind:
				"mage":
					_spell_orb(tip, Color(0.75, 0.45, 1.0))
				"frost":
					_spell_orb(tip, Color(0.55, 0.88, 1.0))
					_snowflakes(tip)
				"healer":
					_healing_motes(foot)
					_glow(tip, 7.0, Color(0.6, 1.0, 0.5), 0.4)   # small, so it doesn't wash out his face
					_disc(tip, 1.5, Color(1, 1, 0.9))
				"alchemist":
					_tossed_flask(Vector2(at), flip)
				"bard":
					_music_notes(Vector2(at) + Vector2(1 if flip else 14, -2) * SPRITE_SCALE)
	var out := canvas.duplicate()
	out.resize(W * 3, H * 3, Image.INTERPOLATE_NEAREST)
	out.get_region(Rect2i(1, 0, 640, 1040)).save_png("res://splash.png")
	print("wrote res://splash.png")


## A night sky in bands, from near-black up top to a deep red glow at the horizon, with stars.
func _sky() -> void:
	var bands := [Color(0.04, 0.03, 0.06), Color(0.06, 0.035, 0.07), Color(0.08, 0.04, 0.08), Color(0.11, 0.045, 0.08),
		Color(0.15, 0.05, 0.08), Color(0.2, 0.065, 0.08), Color(0.26, 0.08, 0.08)]
	for y in H:
		var k := clampf(float(y) / (320.0 * K), 0.0, 0.999)
		var c: Color = bands[int(k * k * bands.size())]
		for x in W:
			canvas.set_pixel(x, y, c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 60:
		var p := Vector2i(rng.randi_range(0, W - 1), rng.randi_range(0, int(230 * K)))
		var b := rng.randf_range(0.4, 0.95)
		canvas.set_pixelv(p, Color(b, b, b * 0.95))
		if b > 0.85:   # the brightest twinkle
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = p + d
				if q.x >= 0 and q.y >= 0 and q.x < W:
					canvas.set_pixelv(q, Color(b * 0.6, b * 0.6, b * 0.65))


## The Ogre King looming in the dark behind the army: crown, head, shoulders and club as
## one huge shadow, lit at the rim by the red horizon, and his eyes burning.
func _ogre_king() -> void:
	var shade := Color(0.02, 0.01, 0.02)   # darker than the sky behind him
	var rim := Color(0.3, 0.08, 0.08)
	var crown := PackedVector2Array([Vector2(110, 132), Vector2(112, 96), Vector2(128, 118), Vector2(142, 88), Vector2(160, 112),
		Vector2(178, 88), Vector2(192, 118), Vector2(208, 96), Vector2(210, 132)])
	var club := PackedVector2Array([Vector2(258, 292), Vector2(278, 302), Vector2(304, 160), Vector2(318, 126), Vector2(298, 112), Vector2(280, 146)])
	var tusks := [PackedVector2Array([Vector2(130, 236), Vector2(138, 238), Vector2(132, 214)]),
		PackedVector2Array([Vector2(182, 238), Vector2(190, 236), Vector2(188, 214)])]
	var inside := func(p: Vector2) -> bool:
		return ((p - Vector2(160, 305)) / Vector2(172, 82)).length_squared() <= 1.0 \
				or ((p - Vector2(160, 182)) / Vector2(66, 60)).length_squared() <= 1.0 \
				or ((p - Vector2(160, 228)) / Vector2(60, 32)).length_squared() <= 1.0 \
				or Geometry2D.is_point_in_polygon(p, crown) or Geometry2D.is_point_in_polygon(p, club)
	for y in H:
		for x in W:
			var p := Vector2(x + 0.5, y + 0.5) / K
			if not inside.call(p):
				continue
			# A red rim where the silhouette meets the sky.
			var e := 2.0 / K
			var edge: bool = not inside.call(p + Vector2(0, -e)) or not inside.call(p + Vector2(-e, 0)) or not inside.call(p + Vector2(e, 0))
			canvas.set_pixel(x, y, rim if edge else shade)
	# Tusks jutting up from his jaw, pale in the dark.
	for t in tusks:
		for y in H:
			for x in W:
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5) / K, t):
					canvas.set_pixel(x, y, Color(0.42, 0.36, 0.3))
	# Crown points catch a dull gold.
	for tip in [Vector2(112, 96), Vector2(142, 88), Vector2(178, 88), Vector2(208, 96)]:
		_disc((tip + Vector2(0, 4)) * K, 1.8, Color(0.5, 0.36, 0.14))
	# Eyes: small angry slits with white-hot centres in a tight banded glow.
	for side in [-1, 1]:
		var c := Vector2(160 + side * 28, 186) * K
		_glow(c, 13.0, Color(1.0, 0.25, 0.06), 0.4, 0.45)   # wide and flat, hugging the eye
		_glow(c, 8.0, Color(1.0, 0.6, 0.15), 0.6, 0.45)
		var eye := PackedVector2Array([c + Vector2(-8 * side, -3), c + Vector2(8 * side, 1), c + Vector2(5 * side, 3), c + Vector2(-7 * side, 2)])
		for y in range(int(c.y) - 5, int(c.y) + 6):
			for x in range(int(c.x) - 9, int(c.x) + 10):
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), eye):
					var hot := absf(x + 0.5 - c.x) < 3 and absf(y + 0.5 - c.y) < 1.5
					canvas.set_pixel(x, y, Color(1.0, 0.97, 0.75) if hot else Color(1.0, 0.7, 0.2))
		# A heavy brow above each eye.
		for i in 12:
			var p := (c + Vector2(-9 * side, -6)).lerp(c + Vector2(10 * side, -4), i / 11.0)
			canvas.set_pixel(int(p.x), int(p.y), Color(0.01, 0.0, 0.01))
			canvas.set_pixel(int(p.x), int(p.y) + 1, Color(0.01, 0.0, 0.01))


## Two ranges of hills across the bottom of the sky.
func _hills() -> void:
	for layer in 2:
		var base := 292 + layer * 20
		var col := Color(0.13, 0.055, 0.075) if layer == 0 else Color(0.09, 0.045, 0.06)
		for x in W:
			var lx := x / K
			var hgt := 16.0 * sin(lx * 0.021 + layer * 2.0) + 9.0 * sin(lx * 0.057 + layer) + 5.0 * sin(lx * 0.13)
			for y in range(int((base - hgt) * K), H):
				canvas.set_pixel(x, y, col)


## The battlefield: grass in bands, with tufts and a few stones.
func _ground() -> void:
	var bands := [Color(0.11, 0.15, 0.08), Color(0.13, 0.18, 0.09), Color(0.15, 0.2, 0.1), Color(0.16, 0.22, 0.11)]
	var top := int(328 * K)
	for y in range(top, H):
		var c: Color = bands[mini(int((y - top) / (40 * K)), bands.size() - 1)]
		for x in W:
			canvas.set_pixel(x, y, c)
	for x in W:
		canvas.set_pixel(x, top, Color(0.2, 0.26, 0.13))   # the edge of the field
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 70:
		var p := Vector2i(rng.randi_range(2, W - 3), rng.randi_range(top + 4, H - 3))
		var g := Color(0.24, 0.34, 0.15) if rng.randf() < 0.7 else Color(0.3, 0.42, 0.18)
		canvas.set_pixelv(p, g)
		canvas.set_pixelv(p + Vector2i(-1, -1), g)
		canvas.set_pixelv(p + Vector2i(1, -2), g.darkened(0.1))
	for i in 8:
		var p := Vector2i(rng.randi_range(4, W - 6), rng.randi_range(top + 10, H - 4))
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]:
			canvas.set_pixelv(p + d, Color(0.38, 0.36, 0.35))
		canvas.set_pixelv(p + Vector2i(1, -1), Color(0.52, 0.5, 0.48))


func _shadow(feet: Vector2, r: float) -> void:
	for y in range(-4, 4):
		for x in range(-int(r), int(r) + 1):
			if (x / r) * (x / r) + (y / 3.5) * (y / 3.5) <= 1.0:
				_blend(Vector2i(feet) + Vector2i(x, y), Color(0, 0, 0, 0.35))


## The Healer's aura: a soft column of light and a bright ring on the ground.
func _healing_aura(feet: Vector2) -> void:
	_glow(feet + Vector2(0, -26), 32.0, Color(0.55, 1.0, 0.45), 0.3)
	for i in 72:
		var a := i * TAU / 72.0
		var p := Vector2i(feet + Vector2(cos(a) * 26.0, sin(a) * 6.0))
		canvas.set_pixelv(p, Color(0.8, 1.0, 0.6) if i % 6 != 0 else Color(1.0, 0.95, 0.6))


func _healing_motes(feet: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 8:
		var p: Vector2i = Vector2i(feet + Vector2(rng.randf_range(-26, 26), -rng.randf_range(12, 62)))
		var c := Color(0.75, 1.0, 0.55) if i % 2 else Color(1.0, 0.95, 0.6)
		canvas.set_pixelv(p, Color(1, 1, 0.9))
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			canvas.set_pixelv(p + d, c)


## A spell being gathered at the tip of a staff: a banded glow and a bright core.
func _spell_orb(at: Vector2, col: Color) -> void:
	_glow(at, 24.0, col, 0.4)
	_glow(at, 11.0, col.lightened(0.3), 0.75)
	_disc(at, 4.0, col.lightened(0.45))
	_disc(at, 2.0, Color(1, 1, 1))
	for i in 8:   # sparks drawn in
		var a := i * TAU / 8.0 + 0.4
		var p := at + Vector2(cos(a), sin(a)) * (9.0 + (i % 3) * 3.0)
		canvas.set_pixel(int(p.x), int(p.y), col.lightened(0.35))


## The Alchemist's flask tossed up out of his open hand (his idle animation), tilted as
## it spins, drawn at the sprites' pixel size, with a dotted trail back to his hand.
const FLASK := ["....kk", "...kvk", ".kkkk.", "kxXxk.", "kxxxk.", ".kkk.."]

func _tossed_flask(at: Vector2, flip: bool) -> void:
	var cols := {"k": INK, "v": Color(0.85, 0.95, 0.95), "x": Color(0.45, 0.95, 0.35), "X": Color(0.8, 1.0, 0.7)}
	var corner := Vector2(10.5, -3.5)   # sprite pixels, above the hand at (12, 8)
	for y in FLASK.size():
		for x in (FLASK[y] as String).length():
			var ch: String = FLASK[y][x]
			if ch == ".":
				continue
			var sx := corner.x + x
			if flip:
				sx = 16 - 1 - sx
			for dy in SPRITE_SCALE:
				for dx in SPRITE_SCALE:
					canvas.set_pixelv(Vector2i(at + Vector2(sx, corner.y + y) * SPRITE_SCALE) + Vector2i(dx, dy), cols[ch])
	# The arc it flew up along, fading toward the hand.
	for i in 4:
		var p := Vector2(12.5 + i * 0.3, 7.0 - i * 2.2)
		if flip:
			p.x = 16 - p.x
		_blend(Vector2i(at + p * SPRITE_SCALE), Color(0.8, 1.0, 0.7, 0.35 + i * 0.15))


## Notes rising from the Bard's song.
func _music_notes(at: Vector2) -> void:
	var gold := Color(1.0, 0.85, 0.4)
	for n in [[Vector2(2, 2), gold], [Vector2(12, -6), Color(0.6, 0.95, 0.95)], [Vector2(-4, -10), gold]]:
		var p: Vector2i = Vector2i(at + n[0])
		var col: Color = n[1]
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:   # the note head
			canvas.set_pixelv(p + d, col)
		for i in 5:   # its stem and flag
			canvas.set_pixelv(p + Vector2i(1, -1 - i), col)
		canvas.set_pixelv(p + Vector2i(2, -5), col)
		canvas.set_pixelv(p + Vector2i(3, -4), col)


func _snowflakes(at: Vector2) -> void:
	for o in [Vector2(-16, -10), Vector2(13, -18), Vector2(17, 8), Vector2(-11, 14)]:
		var c: Vector2i = Vector2i(at + o)
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			canvas.set_pixelv(c + d, Color(0.9, 0.98, 1.0))


## A troop's game sprite (in a pose, if it has one by that name) as an image.
func _sprite(kind: String, pose_name: String) -> Image:
	var tex: Texture2D = Sprites.frames(kind)[0]
	if pose_name != "":
		var posed = Sprites.pose(kind, pose_name)
		if posed != null:
			tex = posed
	return Sprites._image_of(tex)


## The middle of a figure's feet: the centre of the opaque pixels in its bottom two rows
## (in sprite pixels times SPRITE_SCALE), leaving out any staff or weapon touching the ground
## out at the side.
func _feet_centre(art: Image) -> float:
	var h := art.get_height()
	var xs := []
	for y in range(h - 2 * SPRITE_SCALE, h):
		for x in art.get_width():
			if art.get_pixel(x, y).a > 0.0:
				xs.append(x)
	if xs.is_empty():
		return art.get_width() / 2.0
	xs.sort()
	# The widest run of feet in the middle: drop pixels far from the median (a staff's foot).
	var mid: int = xs[xs.size() / 2]
	var feet := xs.filter(func(x): return absi(x - mid) <= 6 * SPRITE_SCALE)
	return (feet.min() + feet.max() + 1) / 2.0


## The top of a staff held on the right of a sprite: the highest pixel in its right columns.
func _staff_tip(src: Image) -> Vector2i:
	for y in src.get_height():
		for x in range(src.get_width() - 1, 10, -1):
			if src.get_pixel(x, y).a > 0.0:
				return Vector2i(x, y)
	return Vector2i(14, 1)


# --- Icon ------------------------------------------------------------------------

## A castle tower on a dark rounded square.
func _make_icon() -> void:
	var icon := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var corner := Vector2(maxf(absf(x - 31.5) - 24.0, 0.0), maxf(absf(y - 31.5) - 24.0, 0.0)).length()
			if corner <= 7.5:
				icon.set_pixel(x, y, Color(0.17, 0.09, 0.1) if y < 32 else Color(0.12, 0.07, 0.09))
	canvas = icon
	_glow(Vector2(32, 32), 30.0, Color(1.0, 0.55, 0.3), 0.16)
	_put(hd.tower_icon(), Vector2i(0, 0), 1.0)
	icon.resize(256, 256, Image.INTERPOLATE_NEAREST)
	icon.save_png("res://icon.png")
	print("wrote res://icon.png")


# --- Drawing helpers ------------------------------------------------------------------

## Lays `art` on the canvas at `at`, dimmed and reddened by `light` (less = further back).
func _put(art: Image, at: Vector2i, light: float) -> void:
	for y in art.get_height():
		for x in art.get_width():
			var c := art.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var p := at + Vector2i(x, y)
			if p.x < 0 or p.y < 0 or p.x >= canvas.get_width() or p.y >= canvas.get_height():
				continue
			if light < 1.0 and c != INK:
				c = c.darkened(1.0 - light).lerp(Color(0.25, 0.1, 0.12), (1.0 - light) * 0.5)
			canvas.set_pixelv(p, c)


## A glow in clean bands (four rings, each a little brighter toward the centre).
func _glow(at: Vector2, r: float, col: Color, strength: float, squash := 1.0) -> void:
	for y in range(int(at.y - r), int(at.y + r) + 1):
		for x in range(int(at.x - r), int(at.x + r) + 1):
			var d := Vector2(x + 0.5 - at.x, (y + 0.5 - at.y) / squash).length() / r
			if d > 1.0:
				continue
			var band := ceilf((1.0 - d) * 4.0) / 4.0
			_blend(Vector2i(x, y), Color(col, band * strength))


func _disc(at: Vector2, r: float, col: Color) -> void:
	for y in range(int(at.y - r) - 1, int(at.y + r) + 2):
		for x in range(int(at.x - r) - 1, int(at.x + r) + 2):
			if Vector2(x + 0.5, y + 0.5).distance_to(at) <= r:
				_blend(Vector2i(x, y), col)


func _blend(p: Vector2i, c: Color) -> void:
	if p.x < 0 or p.y < 0 or p.x >= canvas.get_width() or p.y >= canvas.get_height():
		return
	var under := canvas.get_pixelv(p)
	canvas.set_pixelv(p, Color(under.lerp(Color(c, 1.0), c.a), maxf(under.a, c.a)))
