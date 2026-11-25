extends RefCounted
## Dawnspire under the Ogre King: the art of a conquered land, painted once into the ground
## like the rest of field_art.gd (which calls these).
##   ground "war"    the fields fought over: scorched, trampled to mud, wheel-rutted along the
##                   roads, and littered with what's left of the defenders: arrows stuck in the
##                   earth, broken shields in the Line's blue and gold, helmets, swords, bones
##   decor kinds     "crater", "ogre_banner" (his war-banner on a skull-topped pole),
##                   "line_banner" (Dawnspire's sun banner, torn down and trampled), "pikes"
##                   (skulls on stakes), "debris" (a smashed cart), "deadtree", "stakes"
##                   (a row of sharpened stakes, from "at" to "to"), "fire" (its scorch: the
##                   flames themselves are war_fires.gd)
##   terrain kinds   "deadwood" (a burnt grove), "wreck" (a broken siege engine)
##   walls           war_wall(): scorch, cracks, broken merlons, rubble at the foot, the Line's
##                   banners hanging torn under his

const OUTLINE := Color(0.1, 0.07, 0.1)
const LINE_BLUE := Color(0.24, 0.36, 0.72)
const LINE_GOLD := Color(0.95, 0.78, 0.3)
const OGRE_RED := Color(0.62, 0.12, 0.1)
const BONE := Color(0.88, 0.85, 0.76)
const CHAR := Color(0.13, 0.1, 0.09)
const WOOD := Color(0.42, 0.28, 0.16)
const STEEL := Color(0.62, 0.64, 0.68)

## Decor drawn flat on the ground (before the terrain and anything standing).
const FLAT := ["crater", "line_banner", "fire", "debris"]


# --- The ground ------------------------------------------------------------------------------

static func ground(ci: CanvasItem, w: float, tint: Color, m: Dictionary, rng: RandomNumberGenerator) -> void:
	var city: bool = m.get("biome", "") == "city"
	var y0 := 0.0
	var k := w / 640.0
	# The grass (or the cobbles) dulled with smoke, mud and ash.
	ci.draw_rect(Rect2(0, y0, w, 768.0), Color(Color(0.32, 0.26, 0.18) * tint, 0.24 if city else 0.64))
	# Trampled earth showing through in ragged patches (overlapping blots, no hard edges).
	if not city:
		for i in int(26 * k):
			var c := Vector2(rng.randf_range(0, w), rng.randf_range(150, 760))
			var r := rng.randf_range(22, 52)
			for j in 6:
				var off := Vector2(rng.randf_range(-r, r), rng.randf_range(-r, r) * 0.5)
				ci.draw_set_transform(c + off, rng.randf_range(-0.6, 0.6), Vector2(1.0, 0.55))
				ci.draw_circle(Vector2.ZERO, r * rng.randf_range(0.4, 0.75), Color(Color(0.38, 0.29, 0.18) * tint, 0.22))
				ci.draw_set_transform(Vector2.ZERO)
	# Burn scars: wide, ragged, black at the heart.
	for i in int((10 if city else 18) * k):
		var c := Vector2(rng.randf_range(0, w), rng.randf_range(170, 740))
		var r := rng.randf_range(26, 60)
		for j in 5:
			var off := Vector2(rng.randf_range(-r, r) * 0.6, rng.randf_range(-r, r) * 0.35)
			ci.draw_set_transform(c + off, rng.randf_range(-0.4, 0.4), Vector2(1.0, 0.55))
			ci.draw_circle(Vector2.ZERO, r * rng.randf_range(0.45, 0.8), Color(CHAR * tint, 0.16))
			ci.draw_set_transform(Vector2.ZERO)
		ci.draw_set_transform(c, 0, Vector2(1.0, 0.5))
		ci.draw_circle(Vector2.ZERO, r * 0.3, Color(Color(0.06, 0.05, 0.05) * tint, 0.25))
		ci.draw_set_transform(Vector2.ZERO)
	# The roads churned to mud, rutted by wheels and boots.
	if not city:
		for tr in m.get("trails", []):
			var pts: Array = tr
			for i in pts.size() - 1:
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[i + 1]
				var d := a.direction_to(b)
				var n := Vector2(-d.y, d.x)
				var steps := int(a.distance_to(b) / 6.0)
				for s in steps:
					var p := a.lerp(b, float(s) / maxf(steps, 1)) + Vector2(sin(a.y * 0.05 + s * 0.3) * 4.0, 0)
					ci.draw_circle(p, 13.0, Color(Color(0.3, 0.22, 0.14) * tint, 0.16))
					for side in [-6.0, 6.0]:
						ci.draw_rect(Rect2(p + n * side - Vector2(1, 1), Vector2(2, 2)), Color(Color(0.18, 0.13, 0.08) * tint, 0.7))
					if rng.randf() < 0.25:
						ci.draw_rect(Rect2(p + n * rng.randf_range(-10, 10), Vector2(2, 1)), Color(Color(0.16, 0.11, 0.07) * tint, 0.8))
	# Dead grass.
	if not city:
		for i in int(60 * k):
			var p := Vector2(rng.randf_range(4, w - 4), rng.randf_range(160, 760))
			var g := Color(0.5, 0.42, 0.24) * tint
			ci.draw_line(p, p + Vector2(-2, -5), g, 1.0)
			ci.draw_line(p, p + Vector2(1, -6), g, 1.0)
	# The fallen: arrows in the earth (in volleys), broken shields, helmets, blades, bones.
	for v in int(16 * k):
		var c := Vector2(rng.randf_range(10, w - 10), rng.randf_range(170, 740))
		var lean := rng.randf_range(-0.5, 0.5)
		for j in rng.randi_range(2, 6):
			_arrow(ci, c + Vector2(rng.randf_range(-16, 16), rng.randf_range(-8, 8)), lean + rng.randf_range(-0.2, 0.2), tint)
	for i in int(12 * k):
		_shield(ci, Vector2(rng.randf_range(10, w - 10), rng.randf_range(180, 740)), tint, rng)
	for i in int(9 * k):
		_helmet(ci, Vector2(rng.randf_range(10, w - 10), rng.randf_range(180, 740)), tint)
	for i in int(10 * k):
		_blade(ci, Vector2(rng.randf_range(10, w - 10), rng.randf_range(180, 740)), rng.randf_range(0, TAU), tint)
	for i in int(16 * k):
		_bone(ci, Vector2(rng.randf_range(10, w - 10), rng.randf_range(180, 740)), rng.randf_range(0, PI), tint)
	for i in int(6 * k):
		_skull(ci, Vector2(rng.randf_range(10, w - 10), rng.randf_range(190, 740)), tint)
	for i in int(14 * k):
		var p := Vector2(rng.randf_range(10, w - 10), rng.randf_range(180, 740))
		var cloth: Color = [LINE_BLUE, OGRE_RED, Color(0.55, 0.5, 0.42)][rng.randi() % 3]
		ci.draw_colored_polygon(PackedVector2Array([p, p + Vector2(5, -1), p + Vector2(6, 3), p + Vector2(1, 4)]), cloth.darkened(0.2) * tint)
	# Ash and embers.
	for i in int(180 * k):
		var p := Vector2(rng.randf_range(0, w), rng.randf_range(150, 764))
		ci.draw_rect(Rect2(p, Vector2(1, 1)), Color(Color(0.62, 0.6, 0.58) * tint, 0.6) if i % 4 else Color(Color(0.08, 0.06, 0.06), 0.6))
	for i in int(20 * k):
		ci.draw_rect(Rect2(Vector2(rng.randf_range(0, w), rng.randf_range(170, 750)), Vector2(1, 1)), Color(1.0, 0.5, 0.18, 0.85))


static func _arrow(ci: CanvasItem, p: Vector2, lean: float, tint: Color) -> void:
	var top := p + Vector2(sin(lean) * 9.0, -cos(lean) * 9.0)
	ci.draw_line(p, top, OUTLINE, 2.0)
	ci.draw_line(p, top, Color(0.52, 0.38, 0.22) * tint, 1.0)
	ci.draw_line(top, top + Vector2(-2, 2), Color(0.86, 0.84, 0.8) * tint, 1.0)
	ci.draw_line(top, top + Vector2(2, 2), Color(0.86, 0.84, 0.8) * tint, 1.0)
	ci.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), Color(0, 0, 0, 0.3))


static func _shield(ci: CanvasItem, p: Vector2, tint: Color, rng: RandomNumberGenerator) -> void:
	var r := rng.randf_range(4.5, 6.5)
	var line: bool = rng.randf() < 0.65
	var face: Color = LINE_BLUE if line else Color(0.45, 0.32, 0.2)
	ci.draw_set_transform(p, 0, Vector2(1.0, 0.6))
	if rng.randf() < 0.45:
		# Split in two: one half, its edge splintered.
		var a := rng.randf_range(0, TAU)
		var half := PackedVector2Array()
		for j in 9:
			half.append(Vector2.from_angle(a + j * PI / 8.0) * r)
		ci.draw_colored_polygon(half, OUTLINE)
		var inner := PackedVector2Array()
		for q in half:
			inner.append(q * 0.8)
		ci.draw_colored_polygon(inner, face * tint)
	else:
		ci.draw_circle(Vector2.ZERO, r + 1.0, OUTLINE)
		ci.draw_circle(Vector2.ZERO, r, face * tint)
		if line:
			ci.draw_arc(Vector2.ZERO, r - 0.5, 0, TAU, 16, LINE_GOLD * tint, 1.0)
		ci.draw_circle(Vector2.ZERO, 1.5, STEEL * tint)
	ci.draw_set_transform(Vector2.ZERO)


static func _helmet(ci: CanvasItem, p: Vector2, tint: Color) -> void:
	ci.draw_rect(Rect2(p + Vector2(-4, -4), Vector2(8, 5)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(-3, -3), Vector2(6, 3)), STEEL * tint)
	ci.draw_rect(Rect2(p + Vector2(-3, -3), Vector2(3, 1)), STEEL.lightened(0.3) * tint)
	ci.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(2, 1)), OUTLINE)


static func _blade(ci: CanvasItem, p: Vector2, a: float, tint: Color) -> void:
	var d := Vector2.from_angle(a)
	ci.draw_line(p - d * 6.0, p + d * 6.0, OUTLINE, 3.0)
	ci.draw_line(p - d * 5.0, p + d * 5.0, STEEL * tint, 1.0)
	ci.draw_line(p - d * 6.0, p - d * 3.0, Color(0.35, 0.22, 0.12) * tint, 2.0)
	ci.draw_line(p - d * 3.0 + d.orthogonal() * 2.0, p - d * 3.0 - d.orthogonal() * 2.0, LINE_GOLD.darkened(0.3) * tint, 1.0)


static func _bone(ci: CanvasItem, p: Vector2, a: float, tint: Color) -> void:
	var d := Vector2.from_angle(a) * 3.0
	ci.draw_line(p - d, p + d, BONE * tint, 1.5)
	for e in [p - d, p + d]:
		ci.draw_rect(Rect2(e - Vector2(1, 1), Vector2(2, 2)), BONE * tint)


static func _skull(ci: CanvasItem, p: Vector2, tint: Color) -> void:
	ci.draw_rect(Rect2(p + Vector2(-3, -4), Vector2(6, 6)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(-2, -3), Vector2(4, 4)), BONE * tint)
	ci.draw_rect(Rect2(p + Vector2(-2, -2), Vector2(1, 1)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(1, -2), Vector2(1, 1)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(-1, 1), Vector2(2, 1)), BONE.darkened(0.2) * tint)


## A shape with a pixel outline round it (drawn shifted a pixel each way behind it, so a
## ragged edge never folds over itself).
static func outlined(ci: CanvasItem, poly: PackedVector2Array, col: Color) -> void:
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		var shifted := PackedVector2Array()
		for q in poly:
			shifted.append(q + o)
		ci.draw_colored_polygon(shifted, OUTLINE)
	ci.draw_colored_polygon(poly, col)


# --- Decor -------------------------------------------------------------------------------------

static func decor(ci: CanvasItem, d: Dictionary, tint: Color, rng: RandomNumberGenerator) -> void:
	var at: Vector2 = d.get("at", Vector2.ZERO)
	match d["kind"]:
		"crater":
			_crater(ci, at, float(d.get("r", 20.0)), tint, rng)
		"ogre_banner":
			_ogre_banner(ci, at, tint, rng)
		"line_banner":
			_line_banner(ci, at, float(d.get("angle", 0.4)), tint, rng)
		"pikes":
			_pikes(ci, at, tint, rng)
		"debris":
			_debris(ci, at, tint, rng)
		"deadtree":
			_deadtree(ci, at, tint, rng)
		"stakes":
			_stakes(ci, at, d.get("to", at + Vector2(80, 0)), tint)
		"fire":
			_scorch(ci, at, tint, rng)


## A shell crater: a dark pit, a raised lip of thrown-up earth, clods flung round it.
static func _crater(ci: CanvasItem, c: Vector2, r: float, tint: Color, rng: RandomNumberGenerator) -> void:
	ci.draw_set_transform(c, 0, Vector2(1.0, 0.6))
	ci.draw_circle(Vector2.ZERO, r * 1.7, Color(CHAR * tint, 0.22))
	ci.draw_circle(Vector2.ZERO, r + 4.0, Color(0.36, 0.27, 0.18) * tint)
	ci.draw_circle(Vector2(0, -1.5), r + 2.0, Color(0.48, 0.37, 0.24) * tint)
	ci.draw_circle(Vector2(0, 1.5), r - 1.0, Color(0.2, 0.15, 0.11) * tint)
	ci.draw_circle(Vector2(0, 3.0), r * 0.6, Color(0.12, 0.09, 0.08) * tint)
	ci.draw_set_transform(Vector2.ZERO)
	for i in 10:
		var a := rng.randf_range(0, TAU)
		var p := c + Vector2(cos(a), sin(a) * 0.6) * rng.randf_range(r + 6.0, r * 1.9)
		ci.draw_rect(Rect2(p, Vector2(3, 2)), Color(0.4, 0.3, 0.2) * tint)
		ci.draw_rect(Rect2(p, Vector2(3, 1)), Color(0.55, 0.43, 0.3) * tint)
	for i in 3:
		var p := c + Vector2(rng.randf_range(-r, r) * 0.5, rng.randf_range(-r, r) * 0.25)
		ci.draw_rect(Rect2(p, Vector2(4, 3)), Color(0.5, 0.48, 0.45) * tint)


## The Ogre King's war-banner: a crude pole driven into the ground, a skull on top, a
## crossbar, and his red banner hanging ragged from it, a black tusked skull daubed on.
static func _ogre_banner(ci: CanvasItem, p: Vector2, tint: Color, rng: RandomNumberGenerator) -> void:
	ci.draw_set_transform(p + Vector2(8, 2), 0, Vector2(1.0, 0.35))
	ci.draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.25))
	ci.draw_set_transform(Vector2.ZERO)
	# Rocks heaped round the foot.
	for o in [Vector2(-5, 0), Vector2(4, 1), Vector2(0, -2)]:
		ci.draw_rect(Rect2(p + o - Vector2(3, 2), Vector2(6, 4)), OUTLINE)
		ci.draw_rect(Rect2(p + o - Vector2(2, 1), Vector2(4, 2)), Color(0.5, 0.48, 0.45) * tint)
	# The pole and crossbar.
	ci.draw_rect(Rect2(p + Vector2(-2, -60), Vector2(4, 60)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(-1, -59), Vector2(2, 58)), WOOD * tint)
	ci.draw_rect(Rect2(p + Vector2(-14, -52), Vector2(28, 4)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(-13, -51), Vector2(26, 2)), WOOD * tint)
	# The banner: ragged at the bottom, torn through in places.
	var top := p + Vector2(-12, -49)
	var poly := PackedVector2Array([top, top + Vector2(24, 0)])
	var x := 24.0
	while x > 0.0:
		var drop := rng.randf_range(24, 36)
		poly.append(top + Vector2(x, drop))
		x -= rng.randf_range(3, 6)
		poly.append(top + Vector2(maxf(x, 0.0), drop - rng.randf_range(5, 10)))
	poly.append(top + Vector2(0, 30))
	outlined(ci, poly, OGRE_RED * tint)
	ci.draw_rect(Rect2(top + Vector2(0, 0), Vector2(24, 2)), OGRE_RED.lightened(0.15) * tint)
	ci.draw_rect(Rect2(top + Vector2(17, 6), Vector2(3, 18)), OGRE_RED.darkened(0.25) * tint)   # a fold
	# The daubed skull, tusks up.
	var s := top + Vector2(7, 8)
	ci.draw_rect(Rect2(s, Vector2(10, 9)), Color(0.08, 0.06, 0.06))
	ci.draw_rect(Rect2(s + Vector2(2, 3), Vector2(2, 2)), OGRE_RED * tint)
	ci.draw_rect(Rect2(s + Vector2(6, 3), Vector2(2, 2)), OGRE_RED * tint)
	ci.draw_rect(Rect2(s + Vector2(1, 8), Vector2(1, 3)), BONE * tint)
	ci.draw_rect(Rect2(s + Vector2(8, 8), Vector2(1, 3)), BONE * tint)
	# A rent torn through it, and a skull on the pole's top.
	ci.draw_line(top + Vector2(4, 19), top + Vector2(8, 26), OUTLINE, 2.0)
	_skull(ci, p + Vector2(0, -61), tint)


## Dawnspire's own banner, torn down: its broken pole on the ground, the blue-and-gold sun
## banner trampled into the mud, its edge burnt.
static func _line_banner(ci: CanvasItem, p: Vector2, a: float, tint: Color, rng: RandomNumberGenerator) -> void:
	var d := Vector2.from_angle(a)
	var n := d.orthogonal()
	# The pole, snapped.
	ci.draw_line(p - d * 22.0, p + d * 6.0, OUTLINE, 4.0)
	ci.draw_line(p - d * 22.0, p + d * 6.0, Color(0.55, 0.4, 0.22) * tint, 2.0)
	ci.draw_line(p + d * 10.0 + n * 3.0, p + d * 20.0 + n * 5.0, OUTLINE, 4.0)
	ci.draw_line(p + d * 10.0 + n * 3.0, p + d * 20.0 + n * 5.0, Color(0.55, 0.4, 0.22) * tint, 2.0)
	ci.draw_circle(p - d * 23.0, 2.5, LINE_GOLD * tint)   # its finial
	# The cloth, lying crumpled beside it.
	var c := p - d * 8.0 + n * 9.0
	var cloth := PackedVector2Array([c - d * 12.0 - n * 6.0, c + d * 10.0 - n * 7.0, c + d * 13.0 + n * 2.0, c + d * 6.0 + n * 8.0,
			c - d * 2.0 + n * 5.0, c - d * 9.0 + n * 9.0, c - d * 14.0 + n * 2.0])
	ci.draw_colored_polygon(cloth, OUTLINE)
	var inner := PackedVector2Array()
	for q in cloth:
		inner.append(c + (q - c) * 0.88)
	ci.draw_colored_polygon(inner, LINE_BLUE.darkened(0.15) * tint)
	ci.draw_circle(c + d * 1.0, 4.0, LINE_GOLD.darkened(0.15) * tint)   # the sun, half hidden
	for i in 6:
		var ray := Vector2.from_angle(a + i * TAU / 6.0)
		ci.draw_line(c + d + ray * 4.0, c + d + ray * 6.5, LINE_GOLD.darkened(0.25) * tint, 1.0)
	# Burnt along one edge, a boot print across it.
	for i in 5:
		ci.draw_rect(Rect2(c + d * (8.0 + i) + n * (rng.randf_range(-6, 6)), Vector2(2, 2)), CHAR * tint)
	ci.draw_rect(Rect2(c - d * 5.0 - Vector2(2, 1), Vector2(5, 3)), Color(0.22, 0.16, 0.1, 0.7))


## Skulls on stakes, the Ogre King's warning to anyone coming up the road.
static func _pikes(ci: CanvasItem, p: Vector2, tint: Color, rng: RandomNumberGenerator) -> void:
	for i in 3:
		var b := p + Vector2(-12 + i * 12, (i % 2) * 4)
		var h := 30.0 + (i * 7) % 9
		var lean := (i - 1) * 2.0
		ci.draw_line(b, b + Vector2(lean, -h), OUTLINE, 4.0)
		ci.draw_line(b, b + Vector2(lean, -h), WOOD * tint, 2.0)
		_skull(ci, b + Vector2(lean, -h - 1), tint)
		ci.draw_rect(Rect2(b + Vector2(-3, -1), Vector2(6, 2)), Color(0, 0, 0, 0.25))
	for i in 3:
		_bone(ci, p + Vector2(rng.randf_range(-16, 16), rng.randf_range(2, 8)), rng.randf_range(0, PI), tint)


## A smashed supply cart: one wheel off and lying flat, its bed tipped, crates split open.
static func _debris(ci: CanvasItem, p: Vector2, tint: Color, rng: RandomNumberGenerator) -> void:
	var wood := Color(0.5, 0.34, 0.18) * tint
	ci.draw_set_transform(p + Vector2(4, 4), 0, Vector2(1.0, 0.4))
	ci.draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.22))
	ci.draw_set_transform(Vector2.ZERO)
	var bed := PackedVector2Array([p + Vector2(-18, -6), p + Vector2(10, -12), p + Vector2(14, -2), p + Vector2(-14, 4)])
	ci.draw_colored_polygon(bed, OUTLINE)
	var inner := PackedVector2Array()
	for q in bed:
		inner.append(p + (q - p) * 0.88 + Vector2(0, -1))
	ci.draw_colored_polygon(inner, wood)
	for i in 4:
		ci.draw_line(p + Vector2(-14 + i * 7, -7 - i * 1.4), p + Vector2(-11 + i * 7, 2 - i * 1.4), wood.darkened(0.3), 1.0)
	# The wheel off it, flat on the ground.
	var c := p + Vector2(20, 6)
	ci.draw_set_transform(c, 0, Vector2(1.0, 0.55))
	ci.draw_circle(Vector2.ZERO, 8.0, OUTLINE)
	ci.draw_circle(Vector2.ZERO, 6.5, wood)
	ci.draw_circle(Vector2.ZERO, 4.5, OUTLINE)
	for k in 3:
		var a := k * PI / 3.0 + 0.3
		ci.draw_line(-Vector2.from_angle(a) * 6.0, Vector2.from_angle(a) * 6.0, wood, 1.5)
	ci.draw_set_transform(Vector2.ZERO)
	# A split crate and spilled sacks.
	ci.draw_rect(Rect2(p + Vector2(-26, -2), Vector2(9, 8)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(-25, -1), Vector2(7, 6)), Color(0.62, 0.45, 0.24) * tint)
	ci.draw_line(p + Vector2(-25, -1), p + Vector2(-18, 5), OUTLINE, 1.0)
	for i in 3:
		var q := p + Vector2(rng.randf_range(-8, 8), rng.randf_range(6, 12))
		ci.draw_circle(q, 3.0, OUTLINE)
		ci.draw_circle(q, 2.2, Color(0.78, 0.7, 0.52) * tint)


## A tree burnt to a black trunk and bare, broken limbs.
static func _deadtree(ci: CanvasItem, p: Vector2, tint: Color, rng: RandomNumberGenerator) -> void:
	ci.draw_set_transform(p + Vector2(6, 1), 0, Vector2(1.0, 0.35))
	ci.draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.25))
	ci.draw_set_transform(Vector2.ZERO)
	var h := rng.randf_range(34, 46)
	ci.draw_rect(Rect2(p + Vector2(-4, -h), Vector2(8, h)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(-3, -h + 1), Vector2(6, h - 1)), CHAR * tint)
	ci.draw_rect(Rect2(p + Vector2(-3, -h + 1), Vector2(2, h - 1)), Color(0.22, 0.18, 0.16) * tint)
	for i in 4:
		var y := -h + 6 + i * 7.0
		var side := 1.0 if i % 2 == 0 else -1.0
		var tip := p + Vector2(side * rng.randf_range(10, 16), y - rng.randf_range(6, 12))
		ci.draw_line(p + Vector2(0, y), tip, OUTLINE, 4.0)
		ci.draw_line(p + Vector2(0, y), tip, CHAR * tint, 2.0)
		ci.draw_line(tip, tip + Vector2(side * 4, -4), CHAR * tint, 1.0)
	ci.draw_rect(Rect2(p + Vector2(-1, -h * 0.4), Vector2(2, 2)), Color(1.0, 0.45, 0.15))   # an ember in a crack
	for o in [Vector2(-7, 0), Vector2(6, 1)]:
		ci.draw_line(p + o, p + o + Vector2(o.x * 0.6, 3), CHAR * tint, 2.0)   # roots


## A row of sharpened stakes leaning out toward the attackers.
static func _stakes(ci: CanvasItem, a: Vector2, b: Vector2, tint: Color) -> void:
	var n := int(a.distance_to(b) / 9.0)
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(n, 1))
		var tip := p + Vector2(0, 8) + Vector2(0, -20)
		ci.draw_line(p, tip + Vector2(0, 3), OUTLINE, 5.0)
		ci.draw_line(p, tip + Vector2(0, 3), Color(0.56, 0.4, 0.22) * tint, 3.0)
		ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-2, 3), tip + Vector2(2, 3), tip + Vector2(0, -2)]), Color(0.75, 0.62, 0.42) * tint)
	ci.draw_line(a + Vector2(0, -6), b + Vector2(0, -6), Color(0.62, 0.55, 0.4) * tint, 1.0)   # the lashing rope


## Where a fire burns: charred timbers in a black scorch (the flames are war_fires.gd).
static func _scorch(ci: CanvasItem, p: Vector2, tint: Color, rng: RandomNumberGenerator) -> void:
	ci.draw_set_transform(p, 0, Vector2(1.0, 0.55))
	ci.draw_circle(Vector2.ZERO, 22.0, Color(CHAR * tint, 0.5))
	ci.draw_circle(Vector2.ZERO, 12.0, Color(0.06, 0.05, 0.05, 0.7))
	ci.draw_set_transform(Vector2.ZERO)
	for i in 4:
		var d := Vector2.from_angle(rng.randf_range(0, PI))
		ci.draw_line(p - d * 9.0, p + d * 9.0, OUTLINE, 4.0)
		ci.draw_line(p - d * 8.0, p + d * 8.0, Color(0.2, 0.14, 0.1) * tint, 2.0)


# --- Terrain ---------------------------------------------------------------------------------

## A burnt grove: an ash floor, black trunks standing and fallen, embers.
static func deadwood(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	ci.draw_colored_polygon(poly, Color(0.2, 0.17, 0.15) * tint)
	for q in Geometry2D.offset_polygon(poly, -5.0):
		ci.draw_colored_polygon(q, Color(0.26, 0.22, 0.19) * tint)
	for p in _inside(poly, 8.0, 10, rng):
		var d := Vector2.from_angle(rng.randf_range(-0.6, 0.6))
		ci.draw_line(p - d * 12.0, p + d * 12.0, OUTLINE, 5.0)
		ci.draw_line(p - d * 11.0, p + d * 11.0, CHAR * tint, 3.0)
	var trees: Array = _inside(poly, 12.0, 14, rng)
	trees.sort_custom(func(a, b): return a.y < b.y)
	for p in trees:
		_deadtree(ci, p, tint, rng)
	for p in _inside(poly, 4.0, 18, rng):
		ci.draw_rect(Rect2(p, Vector2(1, 1)), Color(1.0, 0.5, 0.18, 0.9))


## A wrecked siege engine: a catapult's great arm snapped, its frame broken and charred, a
## wheel off, ropes trailing.
static func wreck(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	var box := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		box = box.expand(q)
	var c := box.get_center()
	var wood := Color(0.42, 0.28, 0.15) * tint
	ci.draw_set_transform(c + Vector2(6, 10), 0, Vector2(1.0, 0.45))
	ci.draw_circle(Vector2.ZERO, box.size.x * 0.55, Color(0, 0, 0, 0.25))
	ci.draw_circle(Vector2.ZERO, box.size.x * 0.4, Color(CHAR * tint, 0.4))
	ci.draw_set_transform(Vector2.ZERO)
	# The base frame: two long beams and cross-timbers.
	for side in [-1.0, 1.0]:
		var a := c + Vector2(-box.size.x * 0.42, side * 9.0)
		var b := c + Vector2(box.size.x * 0.4, side * 9.0 + 4.0)
		ci.draw_line(a, b, OUTLINE, 8.0)
		ci.draw_line(a, b, wood, 6.0)
		ci.draw_line(a + Vector2(0, -2), b + Vector2(0, -2), wood.lightened(0.15), 1.0)
	for i in 4:
		var x := lerpf(-box.size.x * 0.36, box.size.x * 0.34, i / 3.0)
		ci.draw_line(c + Vector2(x, -9), c + Vector2(x, 11), OUTLINE, 6.0)
		ci.draw_line(c + Vector2(x, -9), c + Vector2(x, 11), wood.darkened(0.15), 4.0)
	# The uprights and the snapped throwing arm across them, charred at the break.
	ci.draw_line(c + Vector2(-6, -9), c + Vector2(-2, -30), OUTLINE, 7.0)
	ci.draw_line(c + Vector2(-6, -9), c + Vector2(-2, -30), wood, 5.0)
	ci.draw_line(c + Vector2(6, -9), c + Vector2(4, -26), OUTLINE, 7.0)
	ci.draw_line(c + Vector2(6, -9), c + Vector2(4, -26), wood, 5.0)
	ci.draw_line(c + Vector2(-26, -2), c + Vector2(8, -30), OUTLINE, 7.0)
	ci.draw_line(c + Vector2(-26, -2), c + Vector2(8, -30), wood.lightened(0.05), 5.0)
	ci.draw_line(c + Vector2(4, -27), c + Vector2(8, -30), CHAR * tint, 5.0)
	ci.draw_line(c + Vector2(14, -20), c + Vector2(28, -6), OUTLINE, 6.0)   # the arm's far end, fallen
	ci.draw_line(c + Vector2(14, -20), c + Vector2(28, -6), wood, 4.0)
	# Its bucket, and a stone that never flew.
	ci.draw_rect(Rect2(c + Vector2(-32, -6), Vector2(10, 8)), OUTLINE)
	ci.draw_rect(Rect2(c + Vector2(-31, -5), Vector2(8, 6)), wood.darkened(0.2))
	ci.draw_circle(c + Vector2(-27, -6), 4.0, Color(0.55, 0.52, 0.48) * tint)
	# A wheel off, leaning, and rope trailing.
	var wc := c + Vector2(box.size.x * 0.38, 10)
	ci.draw_circle(wc, 10.0, OUTLINE)
	ci.draw_circle(wc, 8.5, wood)
	ci.draw_circle(wc, 6.0, OUTLINE)
	for k in 3:
		var a := k * PI / 3.0
		ci.draw_line(wc - Vector2.from_angle(a) * 8.0, wc + Vector2.from_angle(a) * 8.0, wood, 2.0)
	var rope := Color(0.7, 0.62, 0.45) * tint
	ci.draw_polyline(PackedVector2Array([c + Vector2(-2, -28), c + Vector2(-12, -18), c + Vector2(-16, -4), c + Vector2(-22, 8)]), rope, 1.0)
	for i in 6:
		ci.draw_rect(Rect2(c + Vector2(rng.randf_range(-30, 30), rng.randf_range(-12, 14)), Vector2(1, 1)), Color(1.0, 0.5, 0.18, 0.9))


## Up to n random points inside poly, at least `margin` in from its edge.
static func _inside(poly: PackedVector2Array, margin: float, n: int, rng: RandomNumberGenerator) -> Array:
	var box := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		box = box.expand(q)
	var shrunk: Array = Geometry2D.offset_polygon(poly, -margin)
	if shrunk.is_empty():
		return []
	var out := []
	for i in n * 6:
		if out.size() >= n:
			break
		var p := Vector2(rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y))
		if Geometry2D.is_point_in_polygon(p, shrunk[0]):
			out.append(p)
	return out


# --- The walls ---------------------------------------------------------------------------------

## The siege's marks on a stretch of wall (over what field_art._curtain painted): soot up
## the face, cracks, merlons knocked off, rubble heaped at the foot, arrows in the stone,
## skulls on spikes along the walk, and Dawnspire's sun banners hanging torn.
static func war_wall(ci: CanvasItem, box: Rect2, face_top: float, foot: float, stone: Color, tint: Color, rng: RandomNumberGenerator,
		banners: bool) -> void:
	var x0 := box.position.x
	var x1 := box.end.x
	# Soot streaks rising from where fire's licked at it.
	for i in int((x1 - x0) / 60.0) + 1:
		var x := rng.randf_range(x0 + 6, x1 - 16)
		var h := rng.randf_range(20, 46)
		for j in 4:
			ci.draw_rect(Rect2(x + j * 2.0, foot - h + j * 6.0, 8.0 - j * 2.0, h - j * 6.0), Color(CHAR, 0.12))
	# Cracks.
	for i in int((x1 - x0) / 80.0) + 1:
		var p := Vector2(rng.randf_range(x0 + 10, x1 - 10), rng.randf_range(face_top + 6, foot - 12))
		var pts := PackedVector2Array([p])
		for j in 4:
			p += Vector2(rng.randf_range(-5, 5), rng.randf_range(3, 7))
			pts.append(p)
		ci.draw_polyline(pts, Color(0.12, 0.1, 0.1, 0.8) * tint, 1.0)
	# Merlons knocked off: gaps along the top, and the stones fallen below.
	for i in int((x1 - x0) / 70.0):
		var x := rng.randf_range(x0 + 8, x1 - 20)
		ci.draw_rect(Rect2(x, face_top - 11, 14, 11), stone.darkened(0.3) * tint)
		ci.draw_rect(Rect2(x + 2, face_top - 3, 10, 3), stone.darkened(0.45) * tint)
	# Rubble at the foot.
	for i in int((x1 - x0) / 45.0) + 1:
		var c := Vector2(rng.randf_range(x0 + 8, x1 - 8), foot + rng.randf_range(2, 8))
		for j in 5:
			var b := c + Vector2(rng.randf_range(-10, 10), rng.randf_range(-3, 4))
			var s := rng.randf_range(3, 6)
			ci.draw_rect(Rect2(b, Vector2(s + 2, s)), OUTLINE)
			ci.draw_rect(Rect2(b + Vector2(1, 1), Vector2(s, s - 2)), stone.darkened(rng.randf_range(0.0, 0.2)) * tint)
	# Arrows stuck in the stone.
	for i in int((x1 - x0) / 30.0):
		var p := Vector2(rng.randf_range(x0 + 4, x1 - 4), rng.randf_range(face_top + 8, foot - 6))
		ci.draw_line(p, p + Vector2(rng.randf_range(-3, 3), 6), Color(0.5, 0.36, 0.2) * tint, 1.0)
		ci.draw_rect(Rect2(p + Vector2(-1, 5), Vector2(2, 2)), Color(0.86, 0.84, 0.8) * tint)
	# Skulls on spikes along the walk.
	for i in int((x1 - x0) / 90.0):
		var x := rng.randf_range(x0 + 10, x1 - 10)
		ci.draw_line(Vector2(x, face_top - 10), Vector2(x, face_top - 22), OUTLINE, 2.0)
		_skull(ci, Vector2(x, face_top - 22), tint)
	# Dawnspire's own banners, cut down to hang torn from the parapet.
	if banners and x1 - x0 > 120.0:
		var bx := rng.randf_range(x0 + 30, x1 - 60)
		var top := face_top - 2.0
		var cloth := PackedVector2Array([Vector2(bx, top), Vector2(bx + 20, top), Vector2(bx + 22, top + 18), Vector2(bx + 16, top + 26),
				Vector2(bx + 12, top + 20), Vector2(bx + 6, top + 34), Vector2(bx + 2, top + 22)])
		ci.draw_colored_polygon(cloth, OUTLINE)
		var inner := PackedVector2Array()
		var cc := Vector2(bx + 11, top + 14)
		for q in cloth:
			inner.append(cc + (q - cc) * 0.86)
		ci.draw_colored_polygon(inner, LINE_BLUE * tint)
		ci.draw_circle(Vector2(bx + 11, top + 10), 4.0, LINE_GOLD * tint)
		ci.draw_rect(Rect2(bx + 14, top + 16, 6, 6), Color(CHAR, 0.8))   # burnt through
		ci.draw_rect(Rect2(bx - 1, top - 2, 24, 3), OUTLINE)
