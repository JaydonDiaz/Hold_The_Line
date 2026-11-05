extends RefCounted
## Scenery painted on the field under everything else (main.gd draws it once, again
## when the field changes width): the meadow's light and dark patches, a trail worn
## down to the gate, flowers, rocks, bushes, mushrooms and tufts, and the enemy side
## at the top: a dark pine treeline they march out of, their camp (hide tents, war
## banners, a campfire, a skull on a stake) and a row of sharpened stakes along the
## line your troops can't be posted past. Seeded, so it's the same every game.
## The animated parts (fire, torches, weather) are in ambience.gd.

const OUTLINE := Color(0.1, 0.07, 0.1)
const TOP := 96.0          # main.DEPLOY_TOP: where the enemy entry zone ends
const BOTTOM := 690.0      # above here the castle's towers start


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


static func draw_meadow(ci: CanvasItem, w: float, tint: Color) -> void:
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
	var trail := _trail(w)
	ci.draw_polyline(trail, Color(Color(0.42, 0.33, 0.2) * tint, 0.35), 30.0)
	ci.draw_polyline(trail, Color(Color(0.55, 0.44, 0.28) * tint, 0.35), 16.0)
	for i in 40:
		var p := trail[rng.randi() % trail.size()] + Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12))
		ci.draw_rect(Rect2(p, Vector2(2, 2)), Color(0.62, 0.56, 0.48) * tint)
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
		var p := _spot(rng, w)
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
	# Bushes, a few with berries.
	for i in int(7 * count):
		var p := _spot(rng, w)
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
		var p := _spot(rng, w)
		for k in rng.randi_range(1, 3):
			var m := p + Vector2(k * 6.0, (k % 2) * 3.0)
			ci.draw_rect(Rect2(m + Vector2(-1, -3), Vector2(2, 4)), Color(0.92, 0.88, 0.8) * tint)
			ci.draw_rect(Rect2(m + Vector2(-3.5, -6), Vector2(7, 3.5)).grow(1), OUTLINE)
			ci.draw_rect(Rect2(m + Vector2(-3.5, -6), Vector2(7, 3.5)), Color(0.85, 0.2, 0.18) * tint)
			ci.draw_rect(Rect2(m + Vector2(-2, -5.5), Vector2(1, 1)), Color.WHITE * tint)
			ci.draw_rect(Rect2(m + Vector2(1, -5), Vector2(1, 1)), Color.WHITE * tint)


## A spot on the meadow (not in the enemy entry zone or under the castle).
static func _spot(rng: RandomNumberGenerator, w: float) -> Vector2:
	return Vector2(rng.randf_range(10, w - 10), rng.randf_range(TOP + 24, BOTTOM))


static func draw_spawn(ci: CanvasItem, w: float, tint: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
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
	# The forest they march out of: two rows of dark pines along the top edge, on a
	# band of deep shadow under the trees.
	ci.draw_rect(Rect2(0, 0, w, 20), Color(0.05, 0.09, 0.06) * tint)
	for row in 2:
		var x := -10.0 + row * 11.0
		var dark := Color(0.08, 0.17, 0.11) if row == 0 else Color(0.12, 0.25, 0.14)
		while x < w + 20.0:
			var h := rng.randf_range(26, 42) - row * 6.0
			var base_y := 22.0 + row * 9.0 + rng.randf_range(-3, 3)
			_pine(ci, Vector2(x, base_y), h, dark * tint)
			x += rng.randf_range(16, 26)
	# Sharpened stakes along the line your troops can't be posted past.
	var sx := 12.0
	while sx < w:
		var base := Vector2(sx, TOP + 2)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-3.5, 0), base + Vector2(3.5, 0), base + Vector2(0, -15)]), OUTLINE)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-2, -1), base + Vector2(2, -1), base + Vector2(0, -12)]), Color(0.62, 0.44, 0.25) * tint)
		sx += 40.0
	ci.draw_line(Vector2(0, TOP - 4), Vector2(w, TOP - 4), Color(Color(0.5, 0.38, 0.22) * tint, 0.7), 1.5)


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
