extends RefCounted
## Dawnspire's citadel inside (Phase 5, F3): its rooms as the Ogre King's army holds them.
## A map with "biome": "hall" is a room: a flagstone floor under everything, its walls
## ("hall" terrain: tall, nothing sees or shoots through them), its pillars ("pillar"), its
## tables and benches ("furniture": in the way, but low), and its things ("decor"):
##   carpet    {"rect"}  the old red runner, torn and trampled, its gold edge frayed
##   mosaic    {"at", "r"} Dawnspire's sun inlaid in the floor, hacked at, daubed over
##   brazier   {"at"}    an iron fire-bowl on legs (its flames: a "fire" decor on it)
##   rubble    {"at"}    broken stone fallen from the walls
##   bones     {"at"}    what's left of the Line's defenders
##   chains    {"at"}    shackles on the floor
##   rack      {"at"}    a weapon rack, half emptied
##   stain     {"at"}    old blood on the flags
##   sconce    {"at"}    a torch in its bracket on a wall's face
## The Ogre King's war-banners and his tattered rags ("ogre_banner", "line_banner") are
## WarArt's, hung on the walls the same way.

const OUTLINE := Color(0.1, 0.07, 0.1)
const FLOOR := Color(0.42, 0.4, 0.42)
const WALL_TOP := Color(0.36, 0.34, 0.38)
const WALL_FACE := Color(0.25, 0.23, 0.27)
const FLAT := ["carpet", "mosaic", "stain", "chains", "bones", "rubble"]


## The floor: big flagstones in staggered rows, each a little different, cracked here and
## there, grimed in the cracks, straw and dirt trodden across it.
static func floor(ci: CanvasItem, w: float, h: float, tint: Color, rng: RandomNumberGenerator) -> void:
	ci.draw_rect(Rect2(0, 0, w, h), Color(0.22, 0.2, 0.22) * tint)
	var sw := 40.0
	var sh := 28.0
	var row := 0
	var y := 0.0
	while y < h:
		var x := -sw * 0.5 * float(row % 2)
		while x < w:
			var v := rng.randf_range(-0.05, 0.05)
			var c := Color(FLOOR.r + v, FLOOR.g + v, FLOOR.b + v * 0.6)
			if rng.randf() < 0.1:
				c = c.darkened(0.12)
			ci.draw_rect(Rect2(x + 1, y + 1, sw - 2, sh - 2), c * tint)
			ci.draw_rect(Rect2(x + 1, y + 1, sw - 2, 2), Color(c.lightened(0.12)) * tint)
			ci.draw_rect(Rect2(x + 1, y + sh - 3, sw - 2, 2), Color(c.darkened(0.18)) * tint)
			if rng.randf() < 0.16:
				# A crack across the stone.
				var a := Vector2(x + rng.randf_range(4, sw - 4), y + 3)
				var b := a + Vector2(rng.randf_range(-10, 10), rng.randf_range(8, sh - 6))
				ci.draw_line(a, b, Color(0.16, 0.14, 0.16) * tint, 1.0)
				ci.draw_line(b, b + Vector2(rng.randf_range(-6, 6), 5), Color(0.16, 0.14, 0.16) * tint, 1.0)
			x += sw
		y += sh
		row += 1
	# Grime, straw and grit trodden in.
	for i in int(260 * w / 640.0):
		var p := Vector2(rng.randf_range(0, w), rng.randf_range(0, h))
		var k := rng.randi() % 3
		if k == 0:
			ci.draw_rect(Rect2(p, Vector2(2, 1)), Color(0.7, 0.6, 0.35, 0.6) * tint)   # straw
		elif k == 1:
			ci.draw_rect(Rect2(p, Vector2(1, 1)), Color(0.12, 0.1, 0.1, 0.7))
		else:
			ci.draw_rect(Rect2(p, Vector2(2, 2)), Color(0.3, 0.26, 0.22, 0.5) * tint)
	for i in int(12 * w / 640.0):
		var c := Vector2(rng.randf_range(0, w), rng.randf_range(40, h - 40))
		ci.draw_set_transform(c, rng.randf_range(-0.5, 0.5), Vector2(1.0, 0.5))
		ci.draw_circle(Vector2.ZERO, rng.randf_range(20, 46), Color(0.1, 0.08, 0.08, 0.16))
		ci.draw_set_transform(Vector2.ZERO)


## A wall: its top in courses of dressed stone (lit along the top edge, the mortar dark),
## its face showing where it drops to the floor below, soot up it, a shadow at its foot.
static func wall(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	var box := _box(poly)
	# Its shadow on the floor below it.
	var sh := PackedVector2Array()
	for q in poly:
		sh.append(q + Vector2(0, 8))
	ci.draw_colored_polygon(sh, Color(0, 0, 0, 0.32))
	ci.draw_colored_polygon(poly, OUTLINE)
	var inner := Geometry2D.offset_polygon(poly, -2.0)
	if inner.is_empty():
		return
	var top: PackedVector2Array = inner[0]
	ci.draw_colored_polygon(top, WALL_TOP * tint)
	# Courses of stone over the top.
	var y := box.position.y + 2.0
	var row := 0
	while y < box.end.y - 2.0:
		ci.draw_line(Vector2(box.position.x + 2, y), Vector2(box.end.x - 2, y), Color(0.2, 0.18, 0.22) * tint, 1.0)
		var x := box.position.x + 2.0 + float(row % 2) * 9.0
		while x < box.end.x - 2.0:
			ci.draw_line(Vector2(x, y), Vector2(x, minf(y + 10.0, box.end.y - 2.0)), Color(0.2, 0.18, 0.22) * tint, 1.0)
			x += 18.0
		y += 10.0
		row += 1
	# Some stones lighter, some darker (no two alike).
	for i in int(box.size.x * box.size.y / 260.0):
		var p := Vector2(rng.randf_range(box.position.x + 3, box.end.x - 9), rng.randf_range(box.position.y + 3, box.end.y - 8))
		if Geometry2D.is_point_in_polygon(p, top) and Geometry2D.is_point_in_polygon(p + Vector2(7, 6), top):
			ci.draw_rect(Rect2(p, Vector2(7, 6)), Color(1, 1, 1, 0.06) if rng.randf() < 0.5 else Color(0, 0, 0, 0.08))
	# The face: a band of darker stone along each bottom edge (the drop to the floor).
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		if absf(a.y - b.y) < 1.0 and (a + b).y / 2.0 >= box.end.y - 1.0:
			var lo := minf(a.x, b.x)
			var hi := maxf(a.x, b.x)
			ci.draw_rect(Rect2(lo + 1, a.y - 9, hi - lo - 2, 8), WALL_FACE * tint)
			var x := lo + 4.0
			while x < hi - 4.0:
				ci.draw_line(Vector2(x, a.y - 9), Vector2(x, a.y - 1), Color(0.16, 0.14, 0.18) * tint, 1.0)
				x += 14.0
	# Lit along its top edges.
	for i in top.size():
		var a := top[i]
		var b := top[(i + 1) % top.size()]
		if absf(a.y - b.y) < 1.0 and (a + b).y / 2.0 <= box.position.y + 3.0:
			ci.draw_line(a, b, Color(0.55, 0.53, 0.58) * tint, 2.0)
	# Soot and cracks.
	for i in int(box.size.x / 60.0) + 1:
		var p := Vector2(rng.randf_range(box.position.x + 6, box.end.x - 6), rng.randf_range(box.position.y + 4, box.end.y - 4))
		if Geometry2D.is_point_in_polygon(p, top):
			ci.draw_set_transform(p, 0, Vector2(0.6, 1.0))
			ci.draw_circle(Vector2.ZERO, rng.randf_range(5, 11), Color(0.05, 0.04, 0.05, 0.25))
			ci.draw_set_transform(Vector2.ZERO)


## A pillar: a round column seen from above, its foot square, its shaft lit on one side,
## a ring of carved stone round its head.
static func pillar(ci: CanvasItem, poly: PackedVector2Array, tint: Color, _rng: RandomNumberGenerator) -> void:
	var box := _box(poly)
	var c := box.get_center()
	var r := minf(box.size.x, box.size.y) * 0.5
	ci.draw_set_transform(c + Vector2(4, 9), 0, Vector2(1.0, 0.55))
	ci.draw_circle(Vector2.ZERO, r + 4.0, Color(0, 0, 0, 0.32))
	ci.draw_set_transform(Vector2.ZERO)
	ci.draw_rect(box.grow(1.0), OUTLINE)
	ci.draw_rect(box, WALL_FACE * tint)
	ci.draw_rect(Rect2(box.position + Vector2(2, 2), box.size - Vector2(4, 4)), WALL_TOP * tint)
	ci.draw_circle(c, r - 1.0, OUTLINE)
	ci.draw_circle(c, r - 2.5, Color(0.46, 0.44, 0.48) * tint)
	ci.draw_circle(c + Vector2(-r * 0.25, -r * 0.25), r * 0.45, Color(0.56, 0.54, 0.58) * tint)
	ci.draw_arc(c, r - 5.0, 0.0, TAU, 24, Color(0.3, 0.28, 0.32) * tint, 1.5)
	for k in 8:
		var a := k * TAU / 8.0
		ci.draw_line(c + Vector2.from_angle(a) * (r - 5.0), c + Vector2.from_angle(a) * (r - 2.5), Color(0.3, 0.28, 0.32) * tint, 1.0)


## A long table or bench: dark oak boards on trestles, things left on it.
static func furniture(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	var box := _box(poly)
	ci.draw_rect(Rect2(box.position + Vector2(3, 6), box.size), Color(0, 0, 0, 0.3))
	ci.draw_rect(box.grow(1.0), OUTLINE)
	ci.draw_rect(box, Color(0.4, 0.26, 0.15) * tint)
	var y := box.position.y + 1.0
	while y < box.end.y - 1.0:
		ci.draw_line(Vector2(box.position.x + 1, y), Vector2(box.end.x - 1, y), Color(0.3, 0.19, 0.11) * tint, 1.0)
		y += 6.0
	ci.draw_line(box.position + Vector2(1, 1), Vector2(box.end.x - 1, box.position.y + 1), Color(0.55, 0.38, 0.22) * tint, 1.0)
	# Overturned cups, a platter, a dagger stuck in the wood.
	for i in int(box.size.x / 30.0):
		var p := Vector2(rng.randf_range(box.position.x + 6, box.end.x - 8), rng.randf_range(box.position.y + 4, box.end.y - 6))
		match rng.randi() % 3:
			0:
				ci.draw_rect(Rect2(p, Vector2(4, 3)), Color(0.62, 0.6, 0.58) * tint)
			1:
				ci.draw_circle(p, 3.0, Color(0.7, 0.62, 0.35) * tint)
			_:
				ci.draw_line(p, p + Vector2(6, -2), Color(0.75, 0.75, 0.8) * tint, 1.0)


## The chapel's altar: a block of pale stone, its gold-fringed cloth torn and stained, the
## Line's sun on it smashed, guttered candles, a skull left on it in mockery.
static func altar(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	var box := _box(poly)
	ci.draw_rect(Rect2(box.position + Vector2(3, 7), box.size), Color(0, 0, 0, 0.3))
	ci.draw_rect(box.grow(1.0), OUTLINE)
	ci.draw_rect(box, Color(0.7, 0.66, 0.6) * tint)
	ci.draw_rect(Rect2(box.position.x, box.end.y - 7, box.size.x, 7), Color(0.55, 0.51, 0.47) * tint)
	# The cloth over it, hanging down the front, torn.
	var cloth := Rect2(box.position.x + 20, box.position.y + 2, box.size.x - 40, box.size.y + 6)
	ci.draw_rect(cloth, Color(0.85, 0.82, 0.74) * tint)
	ci.draw_rect(Rect2(cloth.position.x, cloth.end.y - 3, cloth.size.x, 3), Color(0.82, 0.65, 0.25) * tint)
	for i in 4:
		var x := cloth.position.x + rng.randf_range(4, cloth.size.x - 8)
		ci.draw_rect(Rect2(x, cloth.end.y - rng.randf_range(4, 10), rng.randf_range(4, 8), 12), Color(0.7, 0.66, 0.6) * tint)
	ci.draw_circle(cloth.get_center() + Vector2(10, 2), 7.0, Color(0.42, 0.08, 0.06, 0.6))
	# The sun on it, broken in two.
	var c := cloth.get_center() + Vector2(0, -2)
	ci.draw_circle(c, 6.0, Color(0.9, 0.72, 0.28) * tint)
	ci.draw_line(c + Vector2(-6, -5), c + Vector2(5, 6), Color(0.3, 0.26, 0.24), 2.0)
	# Candles, guttered, and a skull.
	for x in [box.position.x + 8, box.position.x + 14, box.end.x - 10]:
		ci.draw_rect(Rect2(x, box.position.y - 6, 3, 8), Color(0.92, 0.88, 0.76) * tint)
		ci.draw_rect(Rect2(x, box.position.y - 7, 3, 1), Color(0.3, 0.2, 0.15))
	var sk := Vector2(box.end.x - 24, box.position.y + 6)
	ci.draw_circle(sk, 4.5, OUTLINE)
	ci.draw_circle(sk, 3.5, Color(0.88, 0.85, 0.76) * tint)
	ci.draw_rect(Rect2(sk + Vector2(-2, -1), Vector2(1.5, 1.5)), OUTLINE)
	ci.draw_rect(Rect2(sk + Vector2(1, -1), Vector2(1.5, 1.5)), OUTLINE)


## The room's things on the floor and walls.
static func decor(ci: CanvasItem, d: Dictionary, tint: Color, rng: RandomNumberGenerator) -> void:
	match String(d["kind"]):
		"carpet":
			var r: Rect2 = d["rect"]
			ci.draw_rect(r, Color(0.45, 0.1, 0.1) * tint)
			ci.draw_rect(Rect2(r.position.x, r.position.y, 3, r.size.y), Color(0.75, 0.58, 0.22) * tint)
			ci.draw_rect(Rect2(r.end.x - 3, r.position.y, 3, r.size.y), Color(0.75, 0.58, 0.22) * tint)
			var y := r.position.y + 18.0
			while y < r.end.y - 10.0:
				ci.draw_rect(Rect2(r.position.x + 8, y, r.size.x - 16, 2), Color(0.6, 0.2, 0.16) * tint)
				y += 36.0
			# Torn through in places (the floor showing), muddied by boots.
			for i in int(r.size.y / 90.0):
				var p := Vector2(rng.randf_range(r.position.x + 4, r.end.x - 16), rng.randf_range(r.position.y + 10, r.end.y - 20))
				ci.draw_rect(Rect2(p, Vector2(rng.randf_range(8, 14), rng.randf_range(6, 14))), FLOOR.darkened(0.1) * tint)
			for i in int(r.size.y / 12.0):
				var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
				ci.draw_rect(Rect2(p, Vector2(3, 2)), Color(0.18, 0.12, 0.08, 0.5))
		"mosaic":
			var c: Vector2 = d["at"]
			var rr: float = d.get("r", 40.0)
			ci.draw_circle(c, rr + 3.0, Color(0.5, 0.42, 0.28) * tint)
			ci.draw_circle(c, rr, Color(0.22, 0.3, 0.5) * tint)
			for k in 16:
				var a := k * TAU / 16.0
				ci.draw_line(c + Vector2.from_angle(a) * rr * 0.45, c + Vector2.from_angle(a) * rr * 0.92, Color(0.85, 0.7, 0.3) * tint, 3.0 if k % 2 == 0 else 1.5)
			ci.draw_circle(c, rr * 0.4, Color(0.9, 0.74, 0.32) * tint)
			# Hacked out and daubed with the Ogre King's mark.
			for i in 7:
				var p := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0, rr * 0.8)
				ci.draw_rect(Rect2(p - Vector2(4, 3), Vector2(rng.randf_range(5, 10), rng.randf_range(4, 8))), Color(0.2, 0.18, 0.2) * tint)
			ci.draw_line(c + Vector2(-rr * 0.6, -rr * 0.5), c + Vector2(rr * 0.6, rr * 0.5), Color(0.55, 0.12, 0.08, 0.85), 4.0)
			ci.draw_line(c + Vector2(rr * 0.6, -rr * 0.5), c + Vector2(-rr * 0.6, rr * 0.5), Color(0.55, 0.12, 0.08, 0.85), 4.0)
		"stain":
			var c: Vector2 = d["at"]
			ci.draw_set_transform(c, rng.randf_range(0, PI), Vector2(1.0, 0.6))
			ci.draw_circle(Vector2.ZERO, 11.0, Color(0.32, 0.06, 0.05, 0.55))
			ci.draw_circle(Vector2(8, 4), 5.0, Color(0.32, 0.06, 0.05, 0.45))
			ci.draw_set_transform(Vector2.ZERO)
		"chains":
			var c: Vector2 = d["at"]
			for k in 7:
				var p := c + Vector2(k * 5.0, sin(k * 1.3) * 3.0)
				ci.draw_arc(p, 2.5, 0.0, TAU, 8, Color(0.55, 0.55, 0.58) * tint, 1.0)
			ci.draw_rect(Rect2(c + Vector2(34, -4), Vector2(8, 8)), OUTLINE)
			ci.draw_rect(Rect2(c + Vector2(35, -3), Vector2(6, 6)), Color(0.4, 0.4, 0.44) * tint)
		"bones":
			var c: Vector2 = d["at"]
			ci.draw_circle(c, 5.0, OUTLINE)
			ci.draw_circle(c, 4.0, Color(0.88, 0.85, 0.76) * tint)
			ci.draw_rect(Rect2(c + Vector2(-2, -1), Vector2(1.5, 1.5)), OUTLINE)
			ci.draw_rect(Rect2(c + Vector2(1, -1), Vector2(1.5, 1.5)), OUTLINE)
			for k in 3:
				var a := rng.randf() * TAU
				var p := c + Vector2.from_angle(a) * rng.randf_range(9, 16)
				ci.draw_line(p, p + Vector2.from_angle(a + 1.0) * 9.0, Color(0.85, 0.82, 0.72) * tint, 2.0)
			# A dented helm and a shield with the old sun on it.
			ci.draw_circle(c + Vector2(14, 8), 5.0, Color(0.5, 0.52, 0.56) * tint)
			ci.draw_circle(c + Vector2(-14, 9), 7.0, OUTLINE)
			ci.draw_circle(c + Vector2(-14, 9), 6.0, Color(0.25, 0.35, 0.6) * tint)
			ci.draw_circle(c + Vector2(-14, 9), 2.5, Color(0.9, 0.75, 0.3) * tint)
		"rubble":
			var c: Vector2 = d["at"]
			for k in 9:
				var p := c + Vector2(rng.randf_range(-16, 16), rng.randf_range(-9, 9))
				var sz := Vector2(rng.randf_range(4, 9), rng.randf_range(3, 7))
				ci.draw_rect(Rect2(p - Vector2(1, 1), sz + Vector2(2, 2)), OUTLINE)
				ci.draw_rect(Rect2(p, sz), (WALL_TOP if k % 2 else Color(0.44, 0.42, 0.46)) * tint)
		"brazier":
			var c: Vector2 = d["at"]
			ci.draw_set_transform(c + Vector2(0, 12), 0, Vector2(1.0, 0.45))
			ci.draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.3))
			ci.draw_set_transform(Vector2.ZERO)
			for k in 3:
				var a := -PI / 2.0 + (k - 1) * 1.1
				ci.draw_line(c + Vector2(0, 2), c + Vector2(cos(a + PI) * -9.0, 13), OUTLINE, 3.0)
				ci.draw_line(c + Vector2(0, 2), c + Vector2(cos(a + PI) * -9.0, 13), Color(0.3, 0.28, 0.3) * tint, 1.5)
			ci.draw_set_transform(c, 0, Vector2(1.0, 0.55))
			ci.draw_circle(Vector2.ZERO, 11.0, OUTLINE)
			ci.draw_circle(Vector2.ZERO, 10.0, Color(0.28, 0.26, 0.28) * tint)
			ci.draw_circle(Vector2.ZERO, 7.5, Color(0.7, 0.25, 0.08))
			ci.draw_circle(Vector2(-2, -1), 4.0, Color(1.0, 0.6, 0.2))
			ci.draw_set_transform(Vector2.ZERO)
		"rack":
			var c: Vector2 = d["at"]
			ci.draw_rect(Rect2(c + Vector2(-18, -3), Vector2(36, 6)), OUTLINE)
			ci.draw_rect(Rect2(c + Vector2(-17, -2), Vector2(34, 4)), Color(0.42, 0.28, 0.16) * tint)
			for k in 3:
				var x := -12.0 + k * 12.0
				ci.draw_line(c + Vector2(x, -2), c + Vector2(x + 3, -18), Color(0.7, 0.72, 0.78) * tint, 2.0)
		"sconce":
			var c: Vector2 = d["at"]
			ci.draw_rect(Rect2(c + Vector2(-3, -2), Vector2(6, 8)), OUTLINE)
			ci.draw_rect(Rect2(c + Vector2(-2, -1), Vector2(4, 6)), Color(0.35, 0.3, 0.3) * tint)
			ci.draw_circle(c + Vector2(0, -5), 6.0, Color(1.0, 0.6, 0.2, 0.25))


static func _box(poly: PackedVector2Array) -> Rect2:
	var lo := poly[0]
	var hi := poly[0]
	for q in poly:
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	return Rect2(lo, hi - lo)
