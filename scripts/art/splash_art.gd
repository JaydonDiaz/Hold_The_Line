extends Control
## The start screen's picture, drawn in code and alive: a night sky whose stars twinkle,
## the Ogre King's silhouette over the hills with a red rim and eyes that smoulder, and
## below him the Line's ten kinds of troop (the game's own sprites) in rows of three, four and three, each with a little
## life of its own: breathing, the Mage's and Frost Witch's staves glowing, the Healer's
## aura, the Bard's notes drifting up, the Alchemist's flask fizzing. Round them: a crescent
## moon and drifting cloud; his host's torches, tents and banners along the hills; mist at
## their foot; the Line's camp on the field: a campfire, a tent, its blue-and-gold
## standard, supplies; a path, grass, stones and flowers.

const Sprites = preload("res://scripts/art/sprites.gd")
const W := 640.0
const H := 1040.0
const OUTLINE := Color(0.06, 0.04, 0.07)
const SCALE := 6.0
# The troops: [kind, centre x, foot y, facing left].
const TROOPS := [["bard", 176.0, 724.0, true], ["healer", 320.0, 728.0, false], ["alchemist", 464.0, 724.0, false],
	["mage", 138.0, 852.0, true], ["pikeman", 259.0, 856.0, false], ["assassin", 381.0, 856.0, true], ["frost", 502.0, 852.0, false],
	["archer", 188.0, 986.0, true], ["swordsman", 312.0, 984.0, false], ["martial", 452.0, 986.0, true]]
const EXT := 1600.0   # how far the sky, hills and grass reach either side (a wide window: no bars)
const PIX := 4.0   # the Ogre King is drawn at a quarter size and shown 4x: chunky pixels, like the rest of the game

var t := 0.0
var stars: Array = []   # [position, size, twinkle phase]
var ogre_tex: ImageTexture   # his silhouette, rim, crown and club, pixel by pixel


func _ready() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in 90:
		stars.append([Vector2(rng.randf_range(4, W - 4), rng.randf_range(4, 520)), 2.0 if rng.randf() < 0.8 else 4.0, rng.randf() * TAU])
	for i in 240:   # (more out to either side, for a wide window)
		var x := rng.randf_range(-EXT, -4) if i % 2 == 0 else rng.randf_range(W + 4, W + EXT)
		stars.append([Vector2(x, rng.randf_range(4, 560)), 2.0 if rng.randf() < 0.8 else 4.0, rng.randf() * TAU])
	ogre_tex = _bake_ogre()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	_sky()
	_moon()
	_clouds()
	_ogre()
	_hills()
	_hill_details()
	_host()
	_mist()
	_field()
	_tent(Vector2(66, 708))
	_supplies(Vector2(560, 968))
	_standard(Vector2(52, 920))
	_campfire(Vector2(572, 712))   # (off to the right: the Healer stands in the middle of the back row)
	for tr in TROOPS:
		_troop(tr[0], Vector2(tr[1], tr[2]), tr[3])
	_foreground()


## A block on the art's 4px grid.
func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(snappedf(x, PIX), snappedf(y, PIX), snappedf(w, PIX), snappedf(h, PIX)), c)


## A crescent moon high to the right, faintly haloed.
func _moon() -> void:
	var m := Vector2(540, 116)
	for r in [64.0, 48.0]:
		draw_circle(m, r, Color(1.0, 0.92, 0.75, 0.035))
	for y in range(-28, 32, 4):
		for x in range(-28, 32, 4):
			var d := Vector2(x, y).length()
			var bite := Vector2(x - 14, y - 6).length()
			if d <= 28.0 and bite > 24.0:
				var shade := 0.85 if (x + y) % 16 == 0 else 1.0
				_px(m.x + x, m.y + y, 4, 4, Color(0.98, 0.93, 0.78) * shade)
	_px(m.x - 20, m.y + 4, 4, 4, Color(0.82, 0.76, 0.62))   # (a crater or two)
	_px(m.x - 12, m.y + 16, 4, 4, Color(0.82, 0.76, 0.62))


## Long thin wisps of cloud drifting across the stars, lit from below by the red glow.
func _clouds() -> void:
	for i in 7:
		var y := 150.0 + i * 52.0 + sin(i * 2.1) * 20.0
		var w := 160.0 + fmod(i * 73.0, 140.0)
		var x := fmod(i * 211.0 + t * (5.0 + i), W + EXT + w) - EXT * 0.5 - w
		var c := Color(0.16, 0.07, 0.1, 0.55) if i % 2 else Color(0.2, 0.08, 0.1, 0.4)
		_px(x, y, w, 4, c)
		_px(x + 24, y - 4, w - 60, 4, Color(c, c.a * 0.7))
		_px(x + 12, y + 4, w - 28, 4, Color(0.3, 0.1, 0.08, 0.25))   # (the underside, red-lit)
	# Now and then a shooting star.
	var k := fmod(t, 9.0)
	if k < 0.6:
		var a := Vector2(80 + fmod(floorf(t / 9.0) * 173.0, 420.0), 60)
		for j in 6:
			_px(a.x + (k * 300.0) - j * 8, a.y + (k * 120.0) - j * 3, 4, 4, Color(1, 0.97, 0.88, (1.0 - j / 6.0) * (1.0 - k / 0.6)))


## His host along the hills behind him: tents, war banners, and torches moving on the crest.
func _host() -> void:
	var crest := func(x: float) -> float:
		var k := x / 40.0
		return 596 + sin(k * 1.3) * 18.0 + sin(k * 0.5) * 12.0
	# Tents and banners, dark against the red glow.
	for i in 14:
		var x := -EXT * 0.4 + i * 196.0 + fmod(i * 61.0, 80.0)
		if x > 40.0 and x < W - 40.0:
			continue   # (behind him: only out at the sides)
		var y: float = crest.call(x) + 4.0
		for r in 5:
			_px(x - 12 + r * 4, y - r * 4, 24 - r * 8 + 4, 4, Color(0.1, 0.03, 0.04))
		_px(x + 20, y - 36, 4, 36, Color(0.08, 0.03, 0.03))
		_px(x + 24, y - 36 + (int(t * 3.0 + i) % 2) * 4, 12, 8, Color(0.38, 0.06, 0.05))
	# Torches along the crest, some moving.
	for i in 46:
		var base := -EXT * 0.5 + i * 72.0
		var x := base + sin(t * 0.3 + i) * (12.0 if i % 3 == 0 else 0.0)
		var y: float = crest.call(x) - 6.0
		var flick := 0.6 + 0.4 * sin(t * 9.0 + i * 1.7)
		draw_circle(Vector2(x, y), 10.0, Color(1.0, 0.45, 0.1, 0.1 * flick))
		_px(x, y, 4, 4, Color(1.0, 0.6 + 0.3 * flick, 0.2))


## Dead trees and rocks on the hills, out at the sides of him.
func _hill_details() -> void:
	for i in 8:
		var x := -EXT * 0.3 + i * 140.0 + fmod(i * 53.0, 60.0)
		if x > 0.0 and x < 120.0:
			x -= 140.0   # (clear of the standard)
		var k := x / 40.0
		var y := 600.0 + sin(k * 1.3) * 18.0 + sin(k * 0.5) * 12.0
		if i % 2 == 0:   # a dead tree, branches bare
			_px(x, y - 40, 4, 40, Color(0.08, 0.03, 0.04))
			_px(x - 8, y - 32, 8, 4, Color(0.08, 0.03, 0.04))
			_px(x + 4, y - 24, 8, 4, Color(0.08, 0.03, 0.04))
			_px(x - 12, y - 36, 4, 4, Color(0.08, 0.03, 0.04))
		else:            # a boulder
			_px(x - 8, y - 8, 20, 12, Color(0.1, 0.04, 0.05))
			_px(x - 4, y - 12, 12, 4, Color(0.13, 0.05, 0.06))


## Mist lying along the foot of the hills, drifting.
func _mist() -> void:
	for i in 12:
		var w := 120.0 + fmod(i * 47.0, 100.0)
		var x := fmod(i * 157.0 + t * 6.0, W + EXT * 2.0 + w) - EXT - w
		_px(x, 636 + (i % 3) * 8, w, 4, Color(0.55, 0.45, 0.55, 0.06))
		_px(x + 16, 640 + (i % 3) * 8, w - 40, 4, Color(0.55, 0.45, 0.55, 0.05))


## The field: a path up through the camp, grass tufts, stones and flowers.
func _field() -> void:
	# The path, winding up from the foot of the picture to the hills.
	for y in range(640, int(H), 4):
		var k := (y - 640.0) / (H - 640.0)
		var half := 8.0 + k * 40.0
		var cx := 320.0 + sin(k * 3.4) * 30.0 * k
		_px(cx - half, y, half * 2.0, 4, Color(0.27, 0.22, 0.14))
		if y % 12 == 0:
			_px(cx - half + fmod(y * 7.3, half * 2.0), y, 4, 4, Color(0.34, 0.28, 0.18))
	# Tufts of taller grass, stones, flowers.
	for i in 90:
		var p := Vector2(fmod(i * 173.7, W + 600.0) - 300.0, 660 + fmod(i * 91.3, H - 680))
		match i % 6:
			0, 1, 2:
				var c := Color(0.16, 0.28, 0.13) if i % 2 else Color(0.22, 0.36, 0.16)
				_px(p.x, p.y - 8, 4, 8, c)
				_px(p.x - 4, p.y - 4, 4, 4, c)
				_px(p.x + 4, p.y - 12, 4, 12, c.lightened(0.05))
			3:
				_px(p.x, p.y, 12, 8, OUTLINE)
				_px(p.x + 4, p.y, 8, 4, Color(0.4, 0.4, 0.42))
			4:
				_px(p.x, p.y, 4, 4, [Color(0.95, 0.9, 0.7), Color(0.95, 0.8, 0.3), Color(0.6, 0.7, 1.0)][i % 3])
			5:
				_px(p.x, p.y, 4, 4, Color(0.95, 0.85, 0.95))
				_px(p.x, p.y + 4, 4, 4, Color(0.2, 0.32, 0.15))


## A fire in pixel blocks: a few tongues of flame flickering at `base`, `s` its size.
func _flame_px(base: Vector2, s: float) -> void:
	# Tongues that taper as they rise: the middle ones tallest, a hot core low down.
	for i in 5:
		var tall := (1.0 - absf(i - 2) * 0.28) * (20.0 + 8.0 * sin(t * 8.0 + i * 1.9)) * s
		var x := base.x + (i - 2) * 5.0 * s
		var rows := int(tall / PIX)
		for r in rows:
			var k := float(r) / maxf(rows, 1)
			var w := (8.0 if k < 0.4 else 4.0) * s
			var c := Color(1.0, 0.85, 0.35) if k < 0.3 and absf(i - 2) <= 1 else (Color(1.0, 0.55, 0.12) if k < 0.7 else Color(0.9, 0.3, 0.08))
			_px(x - w / 2.0 + sin(t * 6.0 + r + i) * 2.0 * k, base.y - (r + 1) * PIX, w, PIX, c)


## A tent of the camp: blue canvas striped white, its flap open on a lamp inside.
func _tent(foot: Vector2) -> void:
	var blue := Color(0.22, 0.32, 0.58)
	for r in 12:
		var half := 4.0 + r * 4.0
		_px(foot.x - half - 4, foot.y - 48 + r * 4, half * 2.0 + 8, 4, OUTLINE)
		_px(foot.x - half, foot.y - 48 + r * 4, half * 2.0, 4, blue if r % 3 else Color(0.85, 0.85, 0.82))
	_px(foot.x - 8, foot.y - 24, 16, 24, Color(0.08, 0.06, 0.05))   # the open flap
	_px(foot.x - 4, foot.y - 12, 8, 8, Color(1.0, 0.75, 0.35, 0.8 + 0.2 * sin(t * 4.0)))   # a lamp lit inside
	_px(foot.x - 2, foot.y - 64, 4, 16, Color(0.3, 0.22, 0.14))   # its pole, a pennant
	_px(foot.x + 2, foot.y - 64 + (int(t * 3.0) % 2) * 4, 12, 4, Color(0.95, 0.75, 0.3))
	draw_texture_rect(Sprites.shadow(), Rect2(foot + Vector2(-56, -8), Vector2(112, 16)), false, Color(0, 0, 0, 0.3))


## The camp's supplies: crates and a barrel.
func _supplies(foot: Vector2) -> void:
	var wood := Color(0.45, 0.3, 0.16)
	for c in [[-28, 0, 28], [4, 0, 24], [-16, -24, 24]]:
		var x: float = foot.x + c[0]
		var y: float = foot.y + c[1]
		var sz: float = c[2]
		_px(x - 4, y - sz - 4, sz + 8, sz + 8, OUTLINE)
		_px(x, y - sz, sz, sz, wood)
		_px(x, y - sz, sz, 4, wood.lightened(0.15))
		_px(x + sz / 2.0 - 2, y - sz, 4, sz, wood.darkened(0.25))
	_px(foot.x + 32, foot.y - 32, 24, 36, OUTLINE)   # a barrel
	_px(foot.x + 36, foot.y - 28, 16, 28, Color(0.4, 0.26, 0.14))
	_px(foot.x + 36, foot.y - 24, 16, 4, Color(0.3, 0.3, 0.32))
	_px(foot.x + 36, foot.y - 8, 16, 4, Color(0.3, 0.3, 0.32))
	draw_texture_rect(Sprites.shadow(), Rect2(foot + Vector2(-44, -8), Vector2(108, 16)), false, Color(0, 0, 0, 0.3))


## The Line's standard planted at the camp's edge: blue and gold, the rising sun on it.
func _standard(foot: Vector2) -> void:
	_px(foot.x - 2, foot.y - 168, 4, 168, Color(0.3, 0.22, 0.14))
	_px(foot.x - 6, foot.y - 172, 12, 4, Color(0.9, 0.72, 0.3))
	var wave := int(t * 3.0) % 2
	_px(foot.x + 2, foot.y - 160 + wave * 4, 48, 56, OUTLINE)
	_px(foot.x + 4, foot.y - 156 + wave * 4, 40, 48, Color(0.2, 0.3, 0.6))
	_px(foot.x + 4, foot.y - 112 + wave * 4, 16, 8, Color(0.2, 0.3, 0.6))
	_px(foot.x + 28, foot.y - 112 + wave * 4, 16, 8, Color(0.2, 0.3, 0.6))
	# The sun: a disc with rays.
	var sun := Vector2(foot.x + 24, foot.y - 132 + wave * 4)
	var gold := Color(0.95, 0.75, 0.3)
	_px(sun.x - 4, sun.y - 4, 8, 8, gold)
	for d in [Vector2(0, -12), Vector2(0, 8), Vector2(-12, 0), Vector2(8, 0)]:
		_px(sun.x + d.x, sun.y + d.y, 4, 4, gold)
	for d in [Vector2(-8, -8), Vector2(4, -8), Vector2(-8, 4), Vector2(4, 4)]:
		_px(sun.x + d.x, sun.y + d.y, 4, 4, gold.darkened(0.15))
	draw_texture_rect(Sprites.shadow(), Rect2(foot + Vector2(-14, -6), Vector2(28, 12)), false, Color(0, 0, 0, 0.35))


## The camp's fire: logs, flames, embers rising, its light on the grass.
func _campfire(at: Vector2) -> void:
	draw_circle(at + Vector2(0, -8), 70.0, Color(1.0, 0.55, 0.15, 0.07 + 0.02 * sin(t * 6.0)))
	_px(at.x - 20, at.y - 4, 40, 8, OUTLINE)
	_px(at.x - 16, at.y - 4, 32, 4, Color(0.4, 0.26, 0.14))
	for k in 6:   # stones round it
		_px(at.x - 28 + k * 11, at.y + 4, 8, 4, Color(0.38, 0.37, 0.4))
	_flame_px(at + Vector2(0, -4), 0.8)
	for i in 6:
		var k := fmod(t * 0.7 + i / 6.0, 1.0)
		_px(at.x + sin(k * 7.0 + i) * 10.0, at.y - 24 - k * 70.0, 4, 4, Color(1.0, 0.7, 0.3, 1.0 - k))


## Dark grass and a pine or two at the very bottom corners, framing the picture.
func _foreground() -> void:
	for side in [-1.0, 1.0]:
		var x0: float = 0.0 if side < 0 else W
		for i in 4:
			var x: float = x0 - side * (8.0 + i * 20.0) + (0.0 if side < 0 else -4.0)
			var h := 28.0 + fmod(i * 17.0, 24.0)
			_px(x, H - h, 4, h, Color(0.05, 0.09, 0.05))
			_px(x + 4 * side, H - h * 0.7, 4, h * 0.7, Color(0.05, 0.09, 0.05))


func _sky() -> void:
	var bands := 26
	for i in bands:
		var k := float(i) / (bands - 1)
		var c := Color(0.03, 0.025, 0.06).lerp(Color(0.2, 0.06, 0.07), pow(k, 2.2))
		draw_rect(Rect2(-EXT, H * 0.62 * k, W + EXT * 2.0, H * 0.62 / bands + 2), c)
	for s in stars:
		var a: float = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 1.7 + s[2]))
		var p: Vector2 = s[0]
		draw_rect(Rect2(p, Vector2(s[1], s[1])), Color(1, 0.97, 0.9, a))
		if s[1] > 2.0 and a > 0.85:   # the bright ones glint
			draw_rect(Rect2(p + Vector2(-3, 1), Vector2(10, 2)), Color(1, 0.97, 0.9, (a - 0.85) * 4.0))
			draw_rect(Rect2(p + Vector2(1, -3), Vector2(2, 10)), Color(1, 0.97, 0.9, (a - 0.85) * 4.0))


## The Ogre King's shape, made once as pixel art: shoulders, head and club in near-black,
## a one-pixel red rim round them, and his crown's spikes and studs.
const BODY := [Vector2(0, 600), Vector2(40, 540), Vector2(120, 488), Vector2(196, 462), Vector2(210, 430),
	Vector2(196, 380), Vector2(192, 300), Vector2(214, 252), Vector2(262, 226), Vector2(320, 220), Vector2(378, 226),
	Vector2(426, 252), Vector2(448, 300), Vector2(444, 380), Vector2(430, 430), Vector2(444, 462), Vector2(520, 488),
	Vector2(600, 540), Vector2(626, 584), Vector2(640, 630), Vector2(640, 720), Vector2(0, 720)]   # (the right shoulder sloping into the hills)
const CLUB := [Vector2(540, 500), Vector2(590, 236), Vector2(606, 226), Vector2(632, 240), Vector2(578, 506)]
const CROWN := [Vector2(250, 236), Vector2(248, 184), Vector2(278, 212), Vector2(298, 164), Vector2(320, 206),
	Vector2(342, 164), Vector2(362, 212), Vector2(392, 184), Vector2(390, 236)]   # a solid crown sitting on his head

func _bake_ogre() -> ImageTexture:
	var w := int(W / PIX)
	var h := int(720 / PIX)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var body := PackedVector2Array(BODY.map(func(p): return p / PIX))
	var crown := PackedVector2Array(CROWN.map(func(p): return p / PIX))
	var inside := {}
	for y in h:
		for x in w:
			var c := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(c, body) or Geometry2D.is_point_in_polygon(c, crown):
				inside[Vector2i(x, y)] = true
	var dark := Color(0.02, 0.015, 0.03)   # (barely there against the night: his eyes are what you see)
	var rim := Color(0.2, 0.045, 0.05)
	for p in inside:
		var edge := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if q.x >= 0 and q.x < w and q.y >= 0 and q.y < h - 4 and not inside.has(q):
				edge = true
		img.set_pixelv(p, rim if edge else dark)
	# Gold studs on the crown's points (the crown itself is part of the silhouette, rimmed like the rest).
	for i in [1, 3, 5, 7]:
		var g: Vector2 = CROWN[i] / PIX
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			img.set_pixel(int(g.x) + d.x - 1, int(g.y) + d.y - 1, Color(0.3, 0.21, 0.09))
	# Tusks.
	for side in [-1.0, 1.0]:
		var tx := int((320 + side * 52) / PIX)
		for k in 7:
			var half := 1 if k < 4 else 0
			for dx in range(-half, half + 1):
				img.set_pixel(tx + dx, int(440 / PIX) + k, Color(0.12, 0.11, 0.11))
	return ImageTexture.create_from_image(img)


## The Ogre King over the hills, breathing slowly; his eyes smoulder, and
## every few seconds flare.
func _ogre() -> void:
	var rise := sin(t * 0.6) * 3.0   # (smooth: the pixels keep their size, the whole figure glides)
	draw_texture_rect(ogre_tex, Rect2(0, rise, W, 720), false)
	var flare := clampf(1.0 - absf(fmod(t, 5.0) - 4.6) * 4.0, 0.0, 1.0)
	var glow := 0.65 + 0.2 * sin(t * 2.2) + 0.35 * flare
	for side in [-1.0, 1.0]:
		var e := Vector2(320 + side * 56, 372 + rise)
		draw_circle(e, 34.0 + 10.0 * flare, Color(1.0, 0.45, 0.1, 0.12 * glow))
		var hot := Color(0.95, 0.42, 0.08).lerp(Color(1, 0.85, 0.4), glow - 0.6)
		# A slanted eye in whole pixels: a long bar, shorter ones above and below, a white-hot core.
		draw_rect(Rect2(e + Vector2(-28, -4), Vector2(56, 8)), hot)
		draw_rect(Rect2(e + Vector2(-20 + side * 4, -8), Vector2(40, 4)), hot)
		draw_rect(Rect2(e + Vector2(-16, 4), Vector2(32, 4)), hot.darkened(0.2))
		draw_rect(Rect2(e + Vector2(-12, -4), Vector2(24, 4)), Color(1, 0.95, 0.6, glow))


## The dark hills he stands behind, then the field the Line stands on.
func _hills() -> void:
	var hill := PackedVector2Array([Vector2(-EXT, 640)])
	var n := int((W + EXT * 2.0) / 40.0)
	for i in n + 1:
		var k := i - int(EXT / 40.0)   # (the same hills as ever in the middle)
		var x := k * 40.0
		hill.append(Vector2(x, 596 + sin(k * 1.3) * 18.0 + sin(k * 0.5) * 12.0))
	hill.append(Vector2(W + EXT, 640))
	draw_colored_polygon(hill, Color(0.17, 0.06, 0.07))
	draw_rect(Rect2(-EXT, 640, W + EXT * 2.0, H - 640), Color(0.12, 0.2, 0.1))
	for i in 640:
		var p := Vector2(fmod(i * 97.3, W + EXT * 2.0) - EXT, 650 + fmod(i * 53.1, H - 660))
		draw_rect(Rect2(p, Vector2(3, 3)), Color(0.2, 0.32, 0.15) if i % 3 else Color(0.08, 0.14, 0.07))
	# Fireflies drifting over the grass.
	for i in 10:
		var f := Vector2(fmod(i * 131.0 + t * (8 + i), W), 700 + fmod(i * 77.0, 300) + sin(t * 1.3 + i) * 10.0)
		draw_circle(f, 2.0, Color(0.85, 1.0, 0.5, 0.4 + 0.4 * sin(t * 3.0 + i)))


## One troop: its sprite at SCALE, breathing, and its kind's own touch of life.
func _troop(kind: String, foot: Vector2, left: bool) -> void:
	var fr: Array = Sprites.frames(kind)
	var tex: Texture2D = fr[0]
	if kind == "swordsman":
		var rest = Sprites.pose("swordsman", "plant")   # at ease: leaning on his sword, point in the dirt
		if rest != null:
			tex = rest
	var size := Vector2(Sprites.SIZE, Sprites.SIZE) * SCALE
	var phase := foot.x * 0.01
	var breathe := sin(t * 2.0 + phase) * 2.0
	var top := foot + Vector2(-size.x / 2.0, -size.y + breathe)
	draw_texture_rect(Sprites.shadow(), Rect2(foot + Vector2(-38, -10), Vector2(76, 20)), false, Color(0, 0, 0, 0.35))
	match kind:
		"healer":
			var a := 0.18 + 0.08 * sin(t * 2.0)
			draw_circle(foot + Vector2(0, -48), 74.0, Color(0.5, 1.0, 0.5, a * 0.5))
			draw_set_transform(foot + Vector2(0, -4), 0.0, Vector2(1.0, 0.32))   # (a ring on the ground)
			draw_arc(Vector2.ZERO, 70.0, 0, TAU, 40, Color(0.75, 1.0, 0.5, a + 0.25), 4.0)
			draw_set_transform(Vector2.ZERO)
		"mage", "frost":
			var c := Color(0.8, 0.45, 1.0) if kind == "mage" else Color(0.6, 0.92, 1.0)
			var orb := foot + Vector2(-38.0 if left else 38.0, -92.0 + breathe)   # (the staff's head, on its own side)
			draw_circle(orb, 44.0 + 4.0 * sin(t * 3.0), Color(c, 0.12))
			draw_circle(orb, 20.0, Color(c, 0.3))
	draw_set_transform(Vector2(top.x + (size.x if left else 0.0), top.y), 0.0, Vector2(-1.0 if left else 1.0, 1.0))
	draw_texture_rect(tex, Rect2(Vector2.ZERO, Vector2(tex.get_width(), Sprites.SIZE) * SCALE), false)
	draw_set_transform(Vector2.ZERO)
	match kind:
		"bard":
			for i in 3:
				var k := fmod(t * 0.5 + i / 3.0, 1.0)
				var n := foot + Vector2((50.0 if left else -50.0) + sin(k * 6.0 + i) * 12.0, -110 - k * 90.0)
				var col: Color = [Color(1, 0.85, 0.3), Color(0.5, 0.85, 1.0), Color(1, 0.6, 0.85)][i]
				col.a = 1.0 - k
				draw_rect(Rect2(n, Vector2(7, 6)), col)
				draw_rect(Rect2(n + Vector2(5, -16), Vector2(2, 16)), col)
		"alchemist":
			for i in 4:
				var k := fmod(t * 0.8 + i * 0.25, 1.0)
				var b := foot + Vector2((54.0 if left else -54.0) + sin(k * 9.0 + i) * 6.0, -120 - k * 50.0)
				draw_rect(Rect2(b, Vector2(5, 5)), Color(0.55, 1.0, 0.4, 1.0 - k))
		"mage", "frost":
			for i in 3:
				var a2 := t * 1.6 + i * TAU / 3.0
				var orb2 := foot + Vector2(-38.0 if left else 38.0, -92.0 + breathe)
				draw_rect(Rect2(orb2 + Vector2(cos(a2) * 26.0, sin(a2) * 12.0) - Vector2(2, 2), Vector2(5, 5)),
						Color(1, 1, 1, 0.85))
