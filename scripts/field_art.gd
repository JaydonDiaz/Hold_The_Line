extends RefCounted
## Scenery painted on the field under everything else (main.gd draws it once, again
## when the field changes width): the meadow's light and dark patches, a trail worn
## down to the gate, flowers, rocks, bushes, mushrooms and tufts, and the enemy side
## at the top: a dark pine treeline they march out of, their camp (hide tents, war
## banners, a campfire, a skull on a stake) and a row of sharpened stakes along the
## line your troops can't be posted past. Seeded, so it's the same every game.
## The animated parts (fire, torches, weather) are in ambience.gd.

const Sprites = preload("res://scripts/sprites.gd")
const OUTLINE := Color(0.1, 0.07, 0.1)
const TOP := 96.0          # main.DEPLOY_TOP: where the enemy entry zone ends
const BOTTOM := 690.0      # above here the castle's towers start


## The whole field's ground, w by h: grass tiles (dirt where the enemy camps), the
## camp, the line troops can't be posted past, then the meadow's scenery or, for a
## campaign map (maps.gd), its own ground, trails and terrain. Painted once (main.gd
## bakes it into a texture), and by the Classic battlefield viewer.
static func paint_field(ci: CanvasItem, w: float, h: float, tint: Color, map: Dictionary) -> void:
	var tile := 64
	for x in ceili(w / tile):
		for y in int(h) / tile:
			var variant := 4
			if (y + 1) * tile > TOP:
				var hh := (x * 73856093) ^ (y * 19349663)
				variant = 3 if hh % 11 == 0 else absi(hh) % 3
			ci.draw_texture_rect(Sprites.ground_tile(variant), Rect2(x * tile, y * tile, tile, tile), false, tint)
	ci.draw_rect(Rect2(0, tile, w, TOP - tile), Color(Color(0.4, 0.3, 0.2) * tint, 0.55))
	if map.is_empty():
		draw_meadow(ci, w, tint)
	var camp: bool = map.get("camp", true)
	draw_spawn(ci, w, tint, camp)
	if camp:
		for x in range(0, int(w), 16):
			ci.draw_rect(Rect2(x, TOP - 2, 8, 4), Color(0.1, 0.05, 0.05, 0.6))
	if not map.is_empty():
		draw_battlefield(ci, w, tint, map)   # its own ground, trails and terrain


## Where the animated bits sit, for ambience.gd: the campfire and the camp torches.
static func props(w: float) -> Dictionary:
	return {"fire": Vector2(w * 0.5, 58.0),
			"torches": [Vector2(w * 0.16, 70.0), Vector2(w * 0.84, 70.0)]}


static func _trail(w: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 25:
		var k := i / 24.0
		var y := lerpf(TOP - 30.0, 740.0, k)
		var x := w / 2.0 + sin(k * 5.2 + 0.8) * 60.0 * (1.0 - k) + sin(k * 13.0) * 10.0 * (1.0 - k)
		pts.append(Vector2(x, y))
	return pts


## `clear` (a campaign map's terrain shapes and trails) keeps the bushes, rocks and the
## like off them and out of the way, so nothing that's only scenery looks like terrain.
static func draw_meadow(ci: CanvasItem, w: float, tint: Color, trail := true, clear: Array = []) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# Light and shade across the meadow, in 32px patches.
	var y := TOP
	while y < 736.0:
		var x := 0.0
		while x < w:
			var v := sin(x * 0.011 + 1.3) * sin(y * 0.014 + 0.4) + sin(x * 0.031 + y * 0.019) * 0.5
			if absf(v) > 0.25:
				var c := Color(0.42, 0.68, 0.3) if v > 0.0 else Color(0.12, 0.3, 0.12)
				ci.draw_rect(Rect2(x, y, 32, 32), Color(c * tint, minf(absf(v) * 0.09, 0.11)))
			x += 32.0
		y += 32.0
	# A trail worn down to the gate by everything that's marched along it.
	if trail:
		_worn_trail(ci, _trail(w), tint, rng)
	var count := w / 640.0
	# Tufts of taller grass.
	for i in int(70 * count):
		var p := _spot(rng, w)
		var g := Color(0.2, 0.4, 0.16) * tint
		ci.draw_line(p, p + Vector2(-2, -6), g, 1.5)
		ci.draw_line(p, p + Vector2(0, -8), g, 1.5)
		ci.draw_line(p, p + Vector2(2, -6), g, 1.5)
	# Clumps of wildflowers.
	var petals := [Color(1, 0.97, 0.9), Color(1, 0.9, 0.4), Color(0.95, 0.55, 0.75), Color(0.55, 0.7, 1.0), Color(0.75, 0.55, 0.95)]
	for i in int(22 * count):
		var p := _spot(rng, w)
		var col: Color = petals[rng.randi() % petals.size()] * tint
		for k in rng.randi_range(3, 6):
			var f := p + Vector2(rng.randf_range(-10, 10), rng.randf_range(-6, 6))
			ci.draw_line(f, f + Vector2(0, 4), Color(0.2, 0.42, 0.16) * tint, 1.0)
			ci.draw_rect(Rect2(f + Vector2(-1.5, -1.5), Vector2(3, 3)), col)
			ci.draw_rect(Rect2(f + Vector2(-0.5, -0.5), Vector2(1, 1)), Color(1, 0.8, 0.25) * tint)
	# Rocks, some mossy.
	for i in int(11 * count):
		var p := _spot(rng, w, clear)
		var s := rng.randf_range(4, 9)
		var rock := PackedVector2Array([p + Vector2(-s, 2), p + Vector2(-s * 0.7, -s * 0.6), p + Vector2(s * 0.1, -s * 0.9),
				p + Vector2(s, -s * 0.3), p + Vector2(s * 0.9, 2)])
		ci.draw_set_transform(p + Vector2(0, 3), 0, Vector2(1, 0.4))
		ci.draw_circle(Vector2.ZERO, s * 1.1, Color(0, 0, 0, 0.2))
		ci.draw_set_transform(Vector2.ZERO)
		var outline := PackedVector2Array()
		for q in rock:
			outline.append(p + (q - p) * 1.2)
		ci.draw_colored_polygon(outline, OUTLINE)
		ci.draw_colored_polygon(rock, Color(0.58, 0.57, 0.55) * tint)
		ci.draw_colored_polygon(PackedVector2Array([rock[1], rock[2], p + Vector2(0, -s * 0.3)]), Color(0.72, 0.71, 0.68) * tint)
		if rng.randf() < 0.4:
			ci.draw_rect(Rect2(p + Vector2(-s * 0.6, -s * 0.5), Vector2(s * 0.7, 2)), Color(0.35, 0.55, 0.25) * tint)
	# Bushes, a few with berries (not on a campaign battlefield, where green clumps would
	# pass for its trees, which block the way: these don't).
	for i in (int(7 * count) if clear.is_empty() else 0):
		var p := _spot(rng, w, clear)
		ci.draw_set_transform(p + Vector2(0, 6), 0, Vector2(1, 0.4))
		ci.draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.22))
		ci.draw_set_transform(Vector2.ZERO)
		var lumps := [Vector2(-8, 0), Vector2(8, 0), Vector2(0, -6), Vector2(-3, 3), Vector2(4, 3)]
		for l in lumps:
			ci.draw_circle(p + l, 9.5, OUTLINE)
		for l in lumps:
			ci.draw_circle(p + l, 8.0, Color(0.16, 0.36, 0.14) * tint)
		for l in lumps.slice(0, 3):
			ci.draw_circle(p + l + Vector2(-2, -2), 4.5, Color(0.26, 0.5, 0.2) * tint)
		if rng.randf() < 0.5:
			for k in 4:
				ci.draw_rect(Rect2(p + Vector2(rng.randf_range(-12, 10), rng.randf_range(-8, 4)), Vector2(2, 2)), Color(0.85, 0.15, 0.2) * tint)
	# Little red mushrooms.
	for i in int(6 * count):
		var p := _spot(rng, w, clear)
		for k in rng.randi_range(1, 3):
			var m := p + Vector2(k * 6.0, (k % 2) * 3.0)
			ci.draw_rect(Rect2(m + Vector2(-1, -3), Vector2(2, 4)), Color(0.92, 0.88, 0.8) * tint)
			ci.draw_rect(Rect2(m + Vector2(-3.5, -6), Vector2(7, 3.5)).grow(1), OUTLINE)
			ci.draw_rect(Rect2(m + Vector2(-3.5, -6), Vector2(7, 3.5)), Color(0.85, 0.2, 0.18) * tint)
			ci.draw_rect(Rect2(m + Vector2(-2, -5.5), Vector2(1, 1)), Color.WHITE * tint)
			ci.draw_rect(Rect2(m + Vector2(1, -5), Vector2(1, 1)), Color.WHITE * tint)


static func _worn_trail(ci: CanvasItem, trail: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	ci.draw_polyline(trail, Color(Color(0.42, 0.33, 0.2) * tint, 0.35), 30.0)
	ci.draw_polyline(trail, Color(Color(0.55, 0.44, 0.28) * tint, 0.35), 16.0)
	for i in 40:
		var p := trail[rng.randi() % trail.size()] + Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12))
		ci.draw_rect(Rect2(p, Vector2(2, 2)), Color(0.62, 0.56, 0.48) * tint)


# --- Campaign battlefields (maps.gd) ---------------------------------------------------------

## A campaign map's ground: its biome, the trails worn through its gaps, then its terrain
## (rock, cliffs, trees, the quarry), all painted once into the field. Tall parts (rock
## tops, canopies) stay inside each shape, which is exactly where nothing can stand.
static func draw_battlefield(ci: CanvasItem, w: float, tint: Color, raw: Dictionary) -> void:
	var m: Dictionary = preload("res://scripts/maps.gd").fitted(raw, w)   # stretched across the field
	var rng := RandomNumberGenerator.new()
	rng.seed = 9090
	var clear := []
	for t in m.get("terrain", []):
		clear.append({"pts": t["poly"], "poly": true})
	for tr in m.get("trails", []):
		clear.append({"pts": tr, "poly": false})
	if m.get("biome", "meadow") == "mountain":
		draw_mountain(ci, w, tint)
	else:
		draw_meadow(ci, w, tint, false, clear)
	for tr in m.get("trails", []):
		var pts := PackedVector2Array()
		var src := PackedVector2Array(tr)
		for i in src.size() - 1:
			for k in 6:
				var a := src[i].lerp(src[i + 1], k / 6.0)
				pts.append(a + Vector2(sin(a.y * 0.05) * 4.0, 0))
		pts.append(src[src.size() - 1])
		_worn_trail(ci, pts, tint, rng)
	var shapes: Array = m.get("terrain", [])
	# Back to front, so lower shapes overlap the ones behind them.
	shapes = shapes.duplicate()
	shapes.sort_custom(func(a, b): return _bottom(a["poly"]) < _bottom(b["poly"]))
	for t in shapes:
		var poly := PackedVector2Array(t["poly"])
		match t["kind"]:
			"rock":
				_crag(ci, poly, tint, false, rng)
			"cliff":
				_crag(ci, poly, tint, true, rng)
			"trees":
				_grove(ci, poly, tint, rng)
			"pit":
				_pit(ci, poly, tint, rng)
			"water":
				_pond(ci, poly, tint, rng)
			"ruin":
				_ruin(ci, poly, tint, rng)
			"house":
				_house(ci, poly, tint, rng)
			"hedge":
				_hedge(ci, poly, tint, rng)
			"shrine":
				_shrine(ci, poly, tint, rng)
	# Fords and bridges go over the water they cross.
	for t in shapes:
		var poly := PackedVector2Array(t["poly"])
		match t["kind"]:
			"ford":
				_ford(ci, poly, tint, rng)
			"bridge":
				_bridge(ci, poly, tint, rng)


static func _bottom(poly: Array) -> float:
	var y := -INF
	for p in poly:
		y = maxf(y, p.y)
	return y


## Rocky mountain ground: grey-brown scree in light and dark patches, stones and the odd
## tough tuft of grass.
static func draw_mountain(ci: CanvasItem, w: float, tint: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5151
	ci.draw_rect(Rect2(0, TOP, w, 736.0 - TOP), Color(0.47, 0.43, 0.38) * tint)
	var y := TOP
	while y < 736.0:
		var x := 0.0
		while x < w:
			var v := sin(x * 0.013 + 0.7) * sin(y * 0.017 + 1.1) + sin(x * 0.029 - y * 0.021) * 0.5
			if absf(v) > 0.2:
				var c := Color(0.6, 0.55, 0.48) if v > 0.0 else Color(0.32, 0.29, 0.26)
				ci.draw_rect(Rect2(x, y, 32, 32), Color(c * tint, minf(absf(v) * 0.14, 0.16)))
			x += 32.0
		y += 32.0
	for i in int(260 * w / 640.0):
		var p := Vector2(rng.randf_range(0, w), rng.randf_range(TOP + 4, 730))
		var s := rng.randf_range(1.5, 3.5)
		ci.draw_rect(Rect2(p, Vector2(s, s * 0.7)), (Color(0.62, 0.58, 0.52) if rng.randf() < 0.6 else Color(0.3, 0.27, 0.24)) * tint)
	for i in int(36 * w / 640.0):
		var p := Vector2(rng.randf_range(10, w - 10), rng.randf_range(TOP + 24, BOTTOM))
		var g := Color(0.32, 0.4, 0.2) * tint
		ci.draw_line(p, p + Vector2(-2, -5), g, 1.5)
		ci.draw_line(p, p + Vector2(1, -6), g, 1.5)


## Points inside `poly` at least `inset` from its edges, scattered (for detail on a shape).
static func _inside(poly: PackedVector2Array, inset: float, n: int, rng: RandomNumberGenerator) -> Array:
	var shrunk := Geometry2D.offset_polygon(poly, -inset)
	if shrunk.is_empty():
		return []
	var lo := poly[0]
	var hi := poly[0]
	for q in poly:
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	var out := []
	var tries := 0
	while out.size() < n and tries < n * 30:
		tries += 1
		var p := Vector2(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y))
		for s in shrunk:
			if Geometry2D.is_point_in_polygon(p, s):
				out.append(p)
				break
	return out


static func _shifted(poly: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in poly:
		out.append(q + by)
	return out


## Rock (a ridge outcrop) or cliff: outlined, a shaded skirt round its foot, a lit top
## stepped up inside it, cracks, and moss on rock or rock strata on a cliff.
static func _crag(ci: CanvasItem, poly: PackedVector2Array, tint: Color, cliff: bool, rng: RandomNumberGenerator) -> void:
	var base := (Color(0.46, 0.43, 0.41) if not cliff else Color(0.42, 0.37, 0.33)) * tint
	# A soft shadow cast down onto the ground below.
	ci.draw_colored_polygon(_shifted(poly, Vector2(4, 6)), Color(0, 0, 0, 0.22))
	ci.draw_colored_polygon(poly, OUTLINE)
	for p in Geometry2D.offset_polygon(poly, -2.0):
		ci.draw_colored_polygon(p, base.darkened(0.3))
	if cliff:
		for p in Geometry2D.offset_polygon(poly, -6.0):
			ci.draw_colored_polygon(p, base.darkened(0.42))
	for p in Geometry2D.offset_polygon(poly, -8.0 if not cliff else -12.0):
		ci.draw_colored_polygon(_shifted(p, Vector2(0, -5)), base)
	for p in Geometry2D.offset_polygon(poly, -16.0):
		ci.draw_colored_polygon(_shifted(p, Vector2(-2, -9)), base.lightened(0.1))
	var area := 1.0
	for q in poly:
		area += 1.0
	if cliff:
		# Strata: short level ledges across the face.
		for p in _inside(poly, 10.0, int(40 + area * 4), rng):
			var len := rng.randf_range(10, 28)
			ci.draw_line(p, p + Vector2(len, 0), base.darkened(0.22), 2.0)
			ci.draw_line(p + Vector2(0, -2), p + Vector2(len * 0.8, -2), base.lightened(0.14), 1.0)
	# Cracks.
	for p in _inside(poly, 12.0, 6 + int(area), rng):
		var a := rng.randf_range(0.4, 2.6)
		var q: Vector2 = p + Vector2.from_angle(a) * rng.randf_range(6, 14)
		ci.draw_line(p, q, base.darkened(0.45), 1.5)
		ci.draw_line(q, q + Vector2.from_angle(a + rng.randf_range(-0.8, 0.8)) * rng.randf_range(4, 8), base.darkened(0.45), 1.5)
	if cliff:
		# Hardy mountain pines up on top, kept well inside the cliff.
		var pines := _inside(poly, 20.0, 10 + int(area * 1.5), rng)
		pines.sort_custom(func(a, b): return a.y < b.y)
		for p in pines:
			var h := rng.randf_range(20, 30)
			ci.draw_set_transform(p + Vector2(0, 2), 0, Vector2(1, 0.4))
			ci.draw_circle(Vector2.ZERO, h * 0.35, Color(0, 0, 0, 0.25))
			ci.draw_set_transform(Vector2.ZERO)
			_pine(ci, p, h, Color(0.16, 0.3, 0.2) * tint)
	# Moss (rock) or loose stones (cliff) on top.
	for p in _inside(poly, 14.0, 5 + int(area * 0.6), rng):
		if cliff:
			ci.draw_rect(Rect2(p, Vector2(4, 3)), base.lightened(0.2))
			ci.draw_rect(Rect2(p + Vector2(0, 3), Vector2(4, 1)), base.darkened(0.4))
		else:
			ci.draw_circle(p, rng.randf_range(3, 6), Color(0.3, 0.48, 0.22) * tint)
			ci.draw_circle(p + Vector2(-1, -1), 2.0, Color(0.42, 0.6, 0.28) * tint)


## A stand of trees: a dark floor of undergrowth, then crowns overlapping back to front.
## A copse: trees whose crowns overlap to make its edge (no hard outline), shaded
## undergrowth between them, and trunks showing under the trees along the front.
## Everything stays inside the shape (where nothing can stand).
static func _grove(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	ci.draw_colored_polygon(_shifted(poly, Vector2(4, 7)), Color(0, 0, 0, 0.2))
	for p in Geometry2D.offset_polygon(poly, -7.0):
		ci.draw_colored_polygon(p, Color(0.08, 0.18, 0.09) * tint)
	# Trees round the edge (their crowns are the edge), then more filling the middle.
	var trees := []
	for ring in Geometry2D.offset_polygon(poly, -11.0):
		for i in ring.size():
			var a: Vector2 = ring[i]
			var b: Vector2 = ring[(i + 1) % ring.size()]
			var n := maxi(1, int(a.distance_to(b) / 15.0))
			for k in n:
				trees.append([a.lerp(b, float(k) / n) + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2)), rng.randf_range(10.5, 12.5)])
	for c in _inside(poly, 18.0, 14, rng):
		trees.append([c, rng.randf_range(12.0, 15.0)])
	trees.sort_custom(func(x, y): return x[0].y < y[0].y)
	var trunk := Color(0.36, 0.24, 0.13) * tint
	for tr in trees:
		var c: Vector2 = tr[0]
		var r: float = tr[1]
		# A trunk under the crown, where there's room for it inside the copse.
		var foot := c + Vector2(0, r * 0.75)
		if Geometry2D.is_point_in_polygon(foot + Vector2(0, 4), poly):
			ci.draw_rect(Rect2(foot + Vector2(-2.5, -3), Vector2(5, 7)), OUTLINE)
			ci.draw_rect(Rect2(foot + Vector2(-1.5, -3), Vector2(3, 6)), trunk)
		ci.draw_circle(c, r + 1.5, OUTLINE)
		ci.draw_circle(c, r, Color(0.13, 0.32, 0.14) * tint)
		ci.draw_circle(c + Vector2(r * 0.2, r * 0.25), r * 0.7, Color(0.1, 0.26, 0.11) * tint)   # shade low and right
		ci.draw_circle(c + Vector2(-r * 0.25, -r * 0.3), r * 0.62, Color(0.2, 0.44, 0.2) * tint)
		ci.draw_circle(c + Vector2(-r * 0.4, -r * 0.45), r * 0.3, Color(0.32, 0.58, 0.28) * tint)
		for k in 3:
			var leaf := c + Vector2.from_angle(rng.randf_range(0, TAU)) * r * rng.randf_range(0.2, 0.75)
			ci.draw_rect(Rect2(leaf, Vector2(2, 2)), Color(0.26, 0.5, 0.24) * tint)


## Water (a river, a pool in the fens): a muddy bank, deep water shading to the middle,
## ripples catching the light and reeds along the edge. Nobody wades in.
static func _pond(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	ci.draw_colored_polygon(poly, Color(0.36, 0.3, 0.2) * tint)   # the bank
	var water := [Color(0.22, 0.42, 0.55), Color(0.18, 0.35, 0.5), Color(0.15, 0.3, 0.44)]
	for i in water.size():
		for p in Geometry2D.offset_polygon(poly, -4.0 - i * 9.0):
			ci.draw_colored_polygon(p, water[i] * tint)
	for p in _inside(poly, 12.0, 14, rng):
		var len := rng.randf_range(6, 16)
		ci.draw_line(p, p + Vector2(len, 0), Color(0.55, 0.72, 0.82, 0.7) * tint, 1.5)
	# Reeds and the odd lily pad round the edge.
	for ring in Geometry2D.offset_polygon(poly, -5.0):
		for i in ring.size():
			var a: Vector2 = ring[i]
			var b: Vector2 = ring[(i + 1) % ring.size()]
			var n := int(a.distance_to(b) / 22.0)
			for k in n:
				var r: Vector2 = a.lerp(b, (k + rng.randf()) / maxf(n, 1))
				if rng.randf() < 0.6:
					for j in 3:
						var top := r + Vector2(j * 2.0 - 2.0, -7.0 - rng.randf_range(0, 5))
						ci.draw_line(r + Vector2(j * 2.0 - 2.0, 0), top, Color(0.32, 0.5, 0.22) * tint, 1.5)
					ci.draw_rect(Rect2(r + Vector2(-1, -12), Vector2(2, 4)), Color(0.42, 0.28, 0.16) * tint)
				else:
					ci.draw_circle(r + Vector2(0, 6), 3.0, Color(0.3, 0.55, 0.28) * tint)


## A hedgerow: a long bank of bushes, dense and dark at the foot, leafy on top, with the
## odd hawthorn blossom. Nobody gets through but by its gaps.
static func _hedge(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	ci.draw_colored_polygon(_shifted(poly, Vector2(3, 6)), Color(0, 0, 0, 0.22))
	ci.draw_colored_polygon(poly, OUTLINE)
	for p in Geometry2D.offset_polygon(poly, -2.0):
		ci.draw_colored_polygon(p, Color(0.16, 0.32, 0.14) * tint)
	var box := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		box = box.expand(q)
	var x := box.position.x + 4.0
	while x < box.end.x - 3.0:
		var c := Vector2(x, box.get_center().y - 2.0 + rng.randf_range(-2, 2))
		if Geometry2D.is_point_in_polygon(c, poly):
			var r := minf(box.size.y * 0.55, rng.randf_range(7.0, 10.0))
			ci.draw_circle(c, r, Color(0.24, 0.45, 0.2) * tint)
			ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.35), r * 0.55, Color(0.34, 0.58, 0.28) * tint)
			if rng.randf() < 0.25:
				ci.draw_rect(Rect2(c + Vector2(rng.randf_range(-4, 4), -r * 0.6), Vector2(2, 2)), Color(0.97, 0.93, 0.88))
		x += rng.randf_range(8.0, 12.0)


## Mercy Vale's shrine (its shape's bounding box): a little whitewashed chapel on a
## paved square, a bell under the gable and candles at the door, flowers round about.
static func _shrine(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	var box := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		box = box.expand(q)
	ci.draw_rect(box.grow(4), Color(0.62, 0.6, 0.55) * tint)   # the paving
	for i in 6:
		ci.draw_rect(Rect2(box.position.x - 4 + i * (box.size.x + 8) / 6.0, box.position.y - 4, 1, box.size.y + 8), Color(0.5, 0.48, 0.44) * tint)
	ci.draw_rect(Rect2(box.position + Vector2(5, 8), box.size - Vector2(4, 4)), Color(0, 0, 0, 0.22))
	var walls := Rect2(box.position.x + 8, box.position.y + box.size.y * 0.4, box.size.x - 16, box.size.y * 0.6 - 2)
	ci.draw_rect(walls.grow(2), OUTLINE)
	ci.draw_rect(walls, Color(0.95, 0.94, 0.9) * tint)
	var cx := box.get_center().x
	var roof := PackedVector2Array([Vector2(walls.position.x - 6, walls.position.y + 2), Vector2(cx, box.position.y + 2),
			Vector2(walls.end.x + 6, walls.position.y + 2)])
	ci.draw_colored_polygon(PackedVector2Array([roof[0] + Vector2(-2, 2), roof[1] + Vector2(0, -3), roof[2] + Vector2(2, 2)]), OUTLINE)
	ci.draw_colored_polygon(roof, Color(0.3, 0.42, 0.72) * tint)
	ci.draw_rect(Rect2(cx - 4, box.position.y + 12, 8, 8), OUTLINE)
	ci.draw_rect(Rect2(cx - 3, box.position.y + 13, 6, 6), Color(0.85, 0.7, 0.3) * tint)   # the bell
	ci.draw_rect(Rect2(cx - 7, walls.end.y - 18, 14, 18), OUTLINE)
	ci.draw_rect(Rect2(cx - 6, walls.end.y - 17, 12, 17), Color(0.45, 0.3, 0.18) * tint)
	for x in [cx - 12.0, cx + 10.0]:
		ci.draw_rect(Rect2(x, walls.end.y - 6, 2, 6), Color(0.95, 0.92, 0.8))
		ci.draw_rect(Rect2(x, walls.end.y - 8, 2, 2), Color(1.0, 0.8, 0.3))
	for i in 10:
		var p := Vector2(box.position.x - 2 + rng.randf() * (box.size.x + 4), box.end.y + 2 + rng.randf() * 4)
		ci.draw_rect(Rect2(p, Vector2(2, 2)), [Color(0.95, 0.5, 0.6), Color(1, 0.9, 0.4), Color(0.7, 0.6, 1)][i % 3])


## A ford: the river runs shallow here, pale over a stony bed, stepping stones across and
## ripples where it runs over them.
static func _ford(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	ci.draw_colored_polygon(poly, Color(0.42, 0.6, 0.66) * tint)
	for p in Geometry2D.offset_polygon(poly, -6.0):
		ci.draw_colored_polygon(p, Color(0.5, 0.68, 0.72) * tint)
	for p in _inside(poly, 6.0, 22, rng):
		var s := rng.randf_range(3.0, 6.0)
		ci.draw_circle(p, s + 1.0, Color(0.32, 0.4, 0.42) * tint)
		ci.draw_circle(p + Vector2(-1, -1), s, Color(0.62, 0.62, 0.58) * tint)
	for p in _inside(poly, 8.0, 10, rng):
		ci.draw_line(p, p + Vector2(rng.randf_range(6, 12), 0), Color(0.85, 0.93, 0.95, 0.7) * tint, 1.5)


## A bridge (its shape's bounding box, running up the field): planks across, a beam
## along each side for a rail, and posts at the ends.
static func _bridge(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	var box := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		box = box.expand(q)
	ci.draw_rect(Rect2(box.position + Vector2(4, 6), box.size), Color(0, 0, 0, 0.22))
	ci.draw_rect(box.grow(2), OUTLINE)
	var wood := Color(0.55, 0.38, 0.22) * tint
	ci.draw_rect(box, wood)
	var y := box.position.y + 2.0
	while y < box.end.y:
		ci.draw_rect(Rect2(box.position.x, y, box.size.x, 1.5), wood.darkened(0.3))
		if rng.randf() < 0.3:
			ci.draw_rect(Rect2(box.position.x + rng.randf_range(4, box.size.x - 8), y + 2, 3, 1), wood.lightened(0.15))
		y += 7.0
	for x in [box.position.x - 2.0, box.end.x - 3.0]:
		ci.draw_rect(Rect2(x, box.position.y - 4, 5, box.size.y + 8), OUTLINE)
		ci.draw_rect(Rect2(x + 1, box.position.y - 3, 3, box.size.y + 6), wood.lightened(0.12))
		for py in [box.position.y - 6.0, box.end.y]:
			ci.draw_rect(Rect2(x - 1, py, 7, 7), OUTLINE)
			ci.draw_rect(Rect2(x, py + 1, 5, 5), wood.darkened(0.15))


## A village cottage (its shape's bounding box): whitewashed walls under a thick thatch,
## a door and a lit window facing the road, a chimney, and a little garden fence.
static func _house(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	ci.draw_colored_polygon(_shifted(poly, Vector2(5, 7)), Color(0, 0, 0, 0.22))
	var wall_top := box.position.y + box.size.y * 0.45
	var walls := Rect2(box.position.x + 4, wall_top, box.size.x - 8, box.end.y - wall_top)
	ci.draw_rect(walls.grow(2), OUTLINE)
	ci.draw_rect(walls, Color(0.88, 0.84, 0.74) * tint)
	ci.draw_rect(Rect2(walls.position.x, walls.end.y - 4, walls.size.x, 4), Color(0.6, 0.55, 0.48) * tint)   # the stone footing
	for x in [walls.position.x, walls.end.x - 3]:
		ci.draw_rect(Rect2(x, walls.position.y, 3, walls.size.y), Color(0.45, 0.3, 0.18) * tint)   # corner timbers
	# The door, and a window lit from inside.
	var mid := walls.position.x + walls.size.x * (0.3 + rng.randf() * 0.4)
	ci.draw_rect(Rect2(mid - 6, walls.end.y - 18, 12, 18), OUTLINE)
	ci.draw_rect(Rect2(mid - 5, walls.end.y - 17, 10, 17), Color(0.5, 0.32, 0.18) * tint)
	var wx := walls.position.x + 8.0 if mid > walls.get_center().x else walls.end.x - 20.0
	ci.draw_rect(Rect2(wx, walls.position.y + 8, 12, 10), OUTLINE)
	ci.draw_rect(Rect2(wx + 1, walls.position.y + 9, 10, 8), Color(1.0, 0.78, 0.4) * tint)
	ci.draw_rect(Rect2(wx + 5.5, walls.position.y + 9, 1, 8), OUTLINE)
	# The thatch: a deep roof overhanging the walls, in layered straw.
	var roof := PackedVector2Array([Vector2(box.position.x - 2, wall_top + 4), Vector2(box.position.x + 10, box.position.y),
			Vector2(box.end.x - 10, box.position.y), Vector2(box.end.x + 2, wall_top + 4)])
	var outline := PackedVector2Array()
	for p in roof:
		outline.append(p + (p - Vector2(box.get_center().x, wall_top)).normalized() * 2.0)
	ci.draw_colored_polygon(outline, OUTLINE)
	ci.draw_colored_polygon(roof, Color(0.78, 0.62, 0.32) * tint)
	for i in 4:
		var y := box.position.y + 4.0 + i * (wall_top - box.position.y) / 4.0
		ci.draw_line(Vector2(box.position.x + 6 - i * 2, y), Vector2(box.end.x - 6 + i * 2, y), Color(0.62, 0.48, 0.22) * tint, 2.0)
	# A chimney.
	var cx := box.position.x + box.size.x * 0.72
	ci.draw_rect(Rect2(cx - 1, box.position.y - 10, 10, 16), OUTLINE)
	ci.draw_rect(Rect2(cx, box.position.y - 9, 8, 14), Color(0.55, 0.5, 0.46) * tint)


## A burnt-out cottage: charred stone walls standing in a broken square, fallen roof
## beams black across the floor, ash and the odd wisp of smoke-stained rubble.
static func _ruin(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	var stone := Color(0.52, 0.48, 0.45) * tint
	ci.draw_colored_polygon(_shifted(poly, Vector2(4, 6)), Color(0, 0, 0, 0.2))
	ci.draw_colored_polygon(poly, Color(0.22, 0.2, 0.19) * tint)   # the ash floor
	for p in Geometry2D.offset_polygon(poly, -6.0):
		ci.draw_colored_polygon(p, Color(0.3, 0.27, 0.25) * tint)
	# Walls: the outline in thick broken stretches, with gaps where they've fallen.
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var n := maxi(1, int(a.distance_to(b) / 10.0))
		for k in n:
			if rng.randf() < 0.18:
				continue
			var q: Vector2 = a.lerp(b, float(k) / n)
			var h := rng.randf_range(5, 13)
			ci.draw_rect(Rect2(q + Vector2(-5, -h), Vector2(11, h + 3)), OUTLINE)
			ci.draw_rect(Rect2(q + Vector2(-4, -h + 1), Vector2(9, h + 1)), stone)
			ci.draw_rect(Rect2(q + Vector2(-4, -h + 1), Vector2(9, 2)), stone.lightened(0.15))
			ci.draw_rect(Rect2(q + Vector2(-4, -h + 3), Vector2(9, 2)), Color(0.15, 0.12, 0.1, 0.5))   # soot
	# Fallen beams, and rubble.
	for p in _inside(poly, 12.0, 4, rng):
		var d := Vector2.from_angle(rng.randf_range(0, PI))
		ci.draw_line(p - d * 12.0, p + d * 12.0, OUTLINE, 5.0)
		ci.draw_line(p - d * 11.0, p + d * 11.0, Color(0.16, 0.12, 0.1) * tint, 3.0)
	for p in _inside(poly, 10.0, 10, rng):
		ci.draw_rect(Rect2(p, Vector2(4, 3)), stone.darkened(0.2))
		ci.draw_rect(Rect2(p + Vector2(1, 0), Vector2(2, 1)), Color(1.0, 0.45, 0.15, 0.6) if rng.randf() < 0.2 else stone)


## The old quarry: a cut stone rim, terraces stepping down, and a dark floor with rubble
## and a wooden ladder.
static func _pit(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	ci.draw_colored_polygon(poly, OUTLINE)
	var steps := [Color(0.55, 0.5, 0.44), Color(0.42, 0.38, 0.33), Color(0.32, 0.28, 0.25), Color(0.2, 0.17, 0.15)]
	for i in steps.size():
		for p in Geometry2D.offset_polygon(poly, -2.0 - i * 7.0):
			ci.draw_colored_polygon(_shifted(p, Vector2(0, i * 1.5)), steps[i] * tint)
	for p in _inside(poly, 26.0, 18, rng):
		var s := rng.randf_range(2.0, 4.5)
		ci.draw_rect(Rect2(p, Vector2(s, s * 0.8)), Color(0.45, 0.4, 0.35) * tint)
	var top := _inside(poly, 4.0, 1, rng)
	if not top.is_empty():
		var lad: Vector2 = Vector2(poly[0].x + 10.0, poly[0].y + 4.0)
		ci.draw_line(lad, lad + Vector2(0, 26), Color(0.45, 0.3, 0.16) * tint, 2.0)
		ci.draw_line(lad + Vector2(6, 0), lad + Vector2(6, 26), Color(0.45, 0.3, 0.16) * tint, 2.0)
		for k in 5:
			ci.draw_line(lad + Vector2(0, 3 + k * 5), lad + Vector2(6, 3 + k * 5), Color(0.55, 0.38, 0.2) * tint, 1.5)


## A spot on the meadow (not in the enemy entry zone or under the castle).
static func _spot(rng: RandomNumberGenerator, w: float, clear: Array = []) -> Vector2:
	var p := Vector2(rng.randf_range(10, w - 10), rng.randf_range(TOP + 24, BOTTOM))
	for tries in 30:
		if not _crowded(p, clear):
			return p
		p = Vector2(rng.randf_range(10, w - 10), rng.randf_range(TOP + 24, BOTTOM))
	return Vector2(-100, -100)   # nowhere free: left off the field


## Whether p is on or near any of `clear` (terrain polygons, or trails as polylines).
static func _crowded(p: Vector2, clear: Array) -> bool:
	for c in clear:
		var pts := PackedVector2Array(c["pts"])
		if c["poly"]:
			for g in Geometry2D.offset_polygon(pts, 34.0):
				if Geometry2D.is_point_in_polygon(p, g):
					return true
		else:
			for i in pts.size() - 1:
				if Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1]).distance_to(p) < 30.0:
					return true
	return false


## (Without the camp, just the trees along the top: the road goes on into them.)
static func draw_spawn(ci: CanvasItem, w: float, tint: Color, camp := true) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	if not camp:
		_treeline(ci, w, tint, rng)
		return
	# Trampled ruts in the dirt.
	for i in int(w / 30.0):
		var p := Vector2(rng.randf_range(0, w), rng.randf_range(34, TOP - 8))
		ci.draw_line(p, p + Vector2(rng.randf_range(10, 26), rng.randf_range(-2, 2)), Color(Color(0.28, 0.2, 0.13) * tint, 0.6), 2.0)
	# Hide tents at the sides of their camp.
	for x in [w * 0.06, w * 0.29, w * 0.72, w * 0.94]:
		_tent(ci, Vector2(x, 62), tint)
	# War banners and torches on poles.
	for x in [w * 0.16, w * 0.84]:
		_torch_pole(ci, Vector2(x, 78), tint)
	for x in [w * 0.4, w * 0.6]:
		_war_banner(ci, Vector2(x, 80), tint)
	# A ring of stones for the campfire (the flames are animated in ambience.gd).
	var fire: Vector2 = props(w)["fire"]
	for i in 8:
		var s := fire + Vector2.from_angle(i * TAU / 8.0) * Vector2(11, 6)
		ci.draw_circle(s, 3.5, OUTLINE)
		ci.draw_circle(s, 2.5, Color(0.55, 0.53, 0.5) * tint)
	ci.draw_line(fire + Vector2(-7, 2), fire + Vector2(7, -2), Color(0.35, 0.22, 0.12) * tint, 3.0)
	ci.draw_line(fire + Vector2(-7, -2), fire + Vector2(7, 2), Color(0.3, 0.18, 0.1) * tint, 3.0)
	# A skull on a stake, and scattered bones.
	var sk := Vector2(w * 0.5 - 90.0, 84)
	ci.draw_line(sk, sk + Vector2(0, -22), OUTLINE, 3.0)
	ci.draw_line(sk, sk + Vector2(0, -22), Color(0.45, 0.3, 0.16) * tint, 1.5)
	ci.draw_circle(sk + Vector2(0, -26), 5.5, OUTLINE)
	ci.draw_circle(sk + Vector2(0, -26), 4.5, Color(0.9, 0.88, 0.8) * tint)
	ci.draw_rect(Rect2(sk + Vector2(-3, -28), Vector2(2, 2)), OUTLINE)
	ci.draw_rect(Rect2(sk + Vector2(1, -28), Vector2(2, 2)), OUTLINE)
	for i in int(w / 160.0):
		var b := Vector2(rng.randf_range(20, w - 20), rng.randf_range(40, TOP - 6))
		var a := rng.randf_range(0, PI)
		var d := Vector2.from_angle(a) * 4.0
		ci.draw_line(b - d, b + d, Color(0.88, 0.86, 0.78) * tint, 2.0)
	_treeline(ci, w, tint, rng)
	# Sharpened stakes along the line your troops can't be posted past.
	var sx := 12.0
	while sx < w:
		var base := Vector2(sx, TOP + 2)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-3.5, 0), base + Vector2(3.5, 0), base + Vector2(0, -15)]), OUTLINE)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-2, -1), base + Vector2(2, -1), base + Vector2(0, -12)]), Color(0.62, 0.44, 0.25) * tint)
		sx += 40.0
	ci.draw_line(Vector2(0, TOP - 4), Vector2(w, TOP - 4), Color(Color(0.5, 0.38, 0.22) * tint, 0.7), 1.5)


## The forest they march out of: two rows of dark pines along the top edge, on a band of
## deep shadow under the trees.
static func _treeline(ci: CanvasItem, w: float, tint: Color, rng: RandomNumberGenerator) -> void:
	ci.draw_rect(Rect2(0, 0, w, 20), Color(0.05, 0.09, 0.06) * tint)
	for row in 2:
		var x := -10.0 + row * 11.0
		var dark := Color(0.08, 0.17, 0.11) if row == 0 else Color(0.12, 0.25, 0.14)
		while x < w + 20.0:
			var h := rng.randf_range(26, 42) - row * 6.0
			var base_y := 22.0 + row * 9.0 + rng.randf_range(-3, 3)
			_pine(ci, Vector2(x, base_y), h, dark * tint)
			x += rng.randf_range(16, 26)


static func _pine(ci: CanvasItem, base: Vector2, h: float, col: Color) -> void:
	for k in 3:
		var y := base.y - k * h * 0.28
		var hw := h * (0.42 - k * 0.1)
		var tri := PackedVector2Array([Vector2(base.x - hw, y), Vector2(base.x + hw, y), Vector2(base.x, y - h * 0.5)])
		ci.draw_colored_polygon(tri, col)
		ci.draw_line(Vector2(base.x - hw, y), Vector2(base.x + hw, y), col.darkened(0.3), 1.0)
		ci.draw_line(Vector2(base.x, y - h * 0.5), Vector2(base.x - hw * 0.5, y - h * 0.25), col.lightened(0.15), 1.0)


static func _tent(ci: CanvasItem, base: Vector2, tint: Color) -> void:
	var hide := Color(0.55, 0.4, 0.26) * tint
	var pts := PackedVector2Array([base + Vector2(-18, 0), base + Vector2(18, 0), base + Vector2(0, -26)])
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-21, 2), base + Vector2(21, 2), base + Vector2(0, -30)]), OUTLINE)
	ci.draw_colored_polygon(pts, hide)
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(0, 0), base + Vector2(18, 0), base + Vector2(0, -26)]), hide.darkened(0.2))
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-5, 0), base + Vector2(5, 0), base + Vector2(0, -12)]), Color(0.12, 0.08, 0.06))
	ci.draw_line(base + Vector2(0, -26), base + Vector2(-4, -33), OUTLINE, 2.0)
	ci.draw_line(base + Vector2(0, -26), base + Vector2(4, -33), OUTLINE, 2.0)
	for k in [-10.0, 9.0]:
		ci.draw_rect(Rect2(base + Vector2(k, -9 + absf(k) * 0.2), Vector2(3, 2)), hide.lightened(0.2))


static func _torch_pole(ci: CanvasItem, base: Vector2, tint: Color) -> void:
	ci.draw_line(base, base + Vector2(0, -26), OUTLINE, 4.0)
	ci.draw_line(base, base + Vector2(0, -26), Color(0.42, 0.28, 0.14) * tint, 2.0)
	ci.draw_rect(Rect2(base + Vector2(-3, -30), Vector2(6, 5)), OUTLINE)


static func _war_banner(ci: CanvasItem, base: Vector2, tint: Color) -> void:
	ci.draw_line(base, base + Vector2(0, -40), OUTLINE, 3.5)
	ci.draw_line(base, base + Vector2(0, -40), Color(0.4, 0.26, 0.13) * tint, 1.5)
	ci.draw_line(base + Vector2(-9, -38), base + Vector2(9, -38), OUTLINE, 3.0)
	var cloth := PackedVector2Array([base + Vector2(-8, -37), base + Vector2(8, -37), base + Vector2(8, -18), base + Vector2(4, -22),
			base + Vector2(0, -16), base + Vector2(-4, -21), base + Vector2(-8, -17)])
	ci.draw_colored_polygon(cloth, Color(0.18, 0.1, 0.1) * tint)
	ci.draw_polyline(cloth + PackedVector2Array([cloth[0]]), OUTLINE, 1.5)
	# A crude red skull daubed on it.
	ci.draw_circle(base + Vector2(0, -30), 3.5, Color(0.8, 0.16, 0.12) * tint)
	ci.draw_rect(Rect2(base + Vector2(-2, -27.5), Vector2(4, 3)), Color(0.8, 0.16, 0.12) * tint)
	ci.draw_rect(Rect2(base + Vector2(-2, -31), Vector2(1.5, 1.5)), OUTLINE)
	ci.draw_rect(Rect2(base + Vector2(0.5, -31), Vector2(1.5, 1.5)), OUTLINE)
