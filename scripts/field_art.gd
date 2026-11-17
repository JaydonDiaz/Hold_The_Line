extends RefCounted
## Scenery painted on the field under everything else (main.gd draws it once, again
## when the field changes width): the meadow's light and dark patches, a trail worn
## down to the gate, flowers, rocks, bushes, mushrooms and tufts, and the enemy side
## at the top: a dark pine treeline they march out of, their camp (hide tents, war
## banners, a campfire, a skull on a stake) and a row of sharpened stakes along the
## line your troops can't be posted past. Seeded, so it's the same every game.
## The animated parts (fire, torches, weather) are in ambience.gd.

const Sprites = preload("res://scripts/sprites.gd")
const CampArt = preload("res://scripts/camp_art.gd")   # the enemy camp, dressed for the map's region
const OUTLINE := Color(0.1, 0.07, 0.1)
const TOP := 96.0          # main.DEPLOY_TOP: where the enemy entry zone ends
const BOTTOM := 690.0      # above here the castle's towers start


## The whole field's ground, w by h: grass tiles (dirt where the enemy camps), the
## camp, the line troops can't be posted past, then the meadow's scenery or, for a
## campaign map (maps.gd), its own ground, trails and terrain. Painted once (main.gd
## bakes it into a texture), and by the Classic battlefield viewer.
static func paint_field(ci: CanvasItem, w: float, h: float, tint: Color, map: Dictionary) -> void:
	var tile := 64
	var camp: bool = map.get("camp", true)
	for x in ceili(w / tile):
		for y in int(h) / tile:
			var variant := 4
			if (y + 1) * tile > TOP or not camp:   # (no camp: the grass runs on up into the trees)
				var hh := (x * 73856093) ^ (y * 19349663)
				variant = 3 if hh % 11 == 0 else absi(hh) % 3
				if map.get("ground", "") == "war" and map.get("biome", "") != "city":
					variant = absi(hh) % 3   # (no flower patches on ground fought over)
			ci.draw_texture_rect(Sprites.ground_tile(variant), Rect2(x * tile, y * tile, tile, tile), false, tint)
	var th := CampArt.theme(map) if camp else ""
	var themed := camp and CampArt.paint_ground(ci, w, tint, th)
	if camp and not themed:
		ci.draw_rect(Rect2(0, tile, w, TOP - tile), Color(Color(0.4, 0.3, 0.2) * tint, 0.55))
	if map.get("biome", "") == "snow" and camp:
		ci.draw_rect(Rect2(0, 0, w, TOP), Color(Color(0.88, 0.91, 0.95) * tint, 0.78))   # the enemy's ground snowed over too
	# The region's own ground, from under the camp (or the top edge, where there's no camp:
	# the road goes on) right down to the bottom edge (under the castle, or your camp).
	var y0 := TOP if camp else 0.0
	match String(map.get("biome", "")):
		"mountain":
			draw_mountain(ci, w, tint, y0, h)
		"snow":
			draw_snow(ci, w, tint, y0, h)
		"city":
			draw_city(ci, w, tint, y0, h)
	if map.is_empty():
		draw_meadow(ci, w, tint)
	if themed or th == "frostkeep":
		CampArt.draw_camp(ci, w, tint, th, props(w)["fire"], props(w)["torches"])
	elif not camp and map.get("biome", "") == "snow":
		CampArt._backdrop(ci, w, tint, "frostkeep", RandomNumberGenerator.new())   # snow-laden pines
	else:
		draw_spawn(ci, w, tint, camp, map.get("biome", "") == "mountain")
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
const WarArt = preload("res://scripts/war_art.gd")


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
	# Clumps of wildflowers (none on ground a war's been fought over).
	var petals := [Color(1, 0.97, 0.9), Color(1, 0.9, 0.4), Color(0.95, 0.55, 0.75), Color(0.55, 0.7, 1.0), Color(0.75, 0.55, 0.95)]
	for i in int(22 * count * (0.0 if barren else 1.0)):
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
	for i in int(6 * count * (0.0 if barren else 1.0)):
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

## A map's own mood on its ground ("ground" in maps.gd), over the biome's:
##   fen     marsh: dark sodden moss, standing mud, reeds in clumps away from the pools too
##   burnt   a village burnt out: scorched earth round each ruin, ash, charred stumps, embers
##   ash     grey ash fallen over the rock, drifted in the hollows
static func _ground_mood(ci: CanvasItem, w: float, tint: Color, m: Dictionary, rng: RandomNumberGenerator) -> void:
	var y0 := TOP if m.get("camp", true) else 0.0
	match String(m.get("ground", "")):
		"fen":
			for i in int(26 * w / 640.0):
				var c := Vector2(rng.randf_range(0, w), rng.randf_range(y0 + 10, 760))
				var r := rng.randf_range(18, 46)
				ci.draw_set_transform(c, 0, Vector2(1.0, 0.55))
				ci.draw_circle(Vector2.ZERO, r, Color(Color(0.16, 0.26, 0.14) * tint, 0.35))
				ci.draw_circle(Vector2(r * 0.2, 0), r * 0.55, Color(Color(0.3, 0.26, 0.16) * tint, 0.3))
				ci.draw_set_transform(Vector2.ZERO)
			for i in int(40 * w / 640.0):
				var p := Vector2(rng.randf_range(6, w - 6), rng.randf_range(y0 + 16, 756))
				for j in 4:
					ci.draw_line(p + Vector2(j * 2.0 - 3.0, 0), p + Vector2(j * 2.5 - 4.0, -6.0 - rng.randf_range(0, 6)), Color(0.38, 0.48, 0.24) * tint, 1.0)
				if rng.randf() < 0.5:
					ci.draw_rect(Rect2(p + Vector2(0, -11), Vector2(2, 4)), Color(0.42, 0.28, 0.16) * tint)
		"burnt":
			# The whole village's ground dulled by smoke and ash, the grass gone brown.
			ci.draw_rect(Rect2(0, y0, w, 768.0 - y0), Color(Color(0.36, 0.3, 0.22) * tint, 0.42))
			for t in m.get("terrain", []):
				if t["kind"] != "ruin":
					continue
				var poly := PackedVector2Array(t["poly"])
				var c := Vector2.ZERO
				for q in poly:
					c += q
				c /= poly.size()
				for k in 5:
					var off := Vector2(rng.randf_range(-40, 40), rng.randf_range(-24, 30))
					ci.draw_set_transform(c + off, 0, Vector2(1.0, 0.65))
					ci.draw_circle(Vector2.ZERO, rng.randf_range(40, 70), Color(Color(0.14, 0.11, 0.1) * tint, 0.3))
					ci.draw_set_transform(Vector2.ZERO)
			for i in int(160 * w / 640.0):
				var p := Vector2(rng.randf_range(0, w), rng.randf_range(y0, 760))
				ci.draw_rect(Rect2(p, Vector2(2, 1)), Color(Color(0.62, 0.6, 0.58) * tint, 0.6) if i % 3 else Color(Color(0.12, 0.1, 0.1) * tint, 0.6))
			for i in int(10 * w / 640.0):
				var p := Vector2(rng.randf_range(10, w - 10), rng.randf_range(y0 + 30, 740))
				ci.draw_rect(Rect2(p + Vector2(-3, -8), Vector2(6, 9)), OUTLINE)
				ci.draw_rect(Rect2(p + Vector2(-2, -7), Vector2(4, 7)), Color(0.16, 0.12, 0.1) * tint)
				ci.draw_rect(Rect2(p + Vector2(-1, -8), Vector2(2, 1)), Color(1.0, 0.45, 0.15))   # still smouldering
			for i in int(24 * w / 640.0):
				var p := Vector2(rng.randf_range(0, w), rng.randf_range(y0 + 10, 750))
				ci.draw_rect(Rect2(p, Vector2(1, 1)), Color(1.0, 0.55, 0.2, 0.8))
		"war":
			WarArt.ground(ci, w, tint, m, rng)
		"ash":
			for i in int(14 * w / 640.0):
				var c := Vector2(rng.randf_range(0, w), rng.randf_range(y0 + 10, 760))
				ci.draw_set_transform(c, rng.randf_range(-0.3, 0.3), Vector2(1.0, 0.4))
				ci.draw_circle(Vector2.ZERO, rng.randf_range(24, 54), Color(Color(0.72, 0.7, 0.7) * tint, 0.16))
				ci.draw_set_transform(Vector2.ZERO)
			for i in int(220 * w / 640.0):
				var p := Vector2(rng.randf_range(0, w), rng.randf_range(y0, 764))
				ci.draw_rect(Rect2(p, Vector2(1, 1)), Color(Color(0.8, 0.78, 0.78) * tint, 0.7))


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
	snowy = m.get("biome", "meadow") == "snow"
	barren = m.get("ground", "") == "war"
	match m.get("biome", "meadow"):
		"mountain", "snow", "city":
			pass   # (painted first, by paint_field: it reaches under the camp and the castle)
		"void":
			draw_islands(ci, w, tint, m)
		_:
			draw_meadow(ci, w, tint, false, clear)
	_ground_mood(ci, w, tint, m, rng)
	for d in m.get("decor", []):
		if d["kind"] == "plaza":
			_plaza(ci, d["rect"], d.get("at", (d["rect"] as Rect2).get_center()), d.get("r", 40.0), tint)
	for tr in m.get("trails", []):
		var pts := PackedVector2Array()
		var src := PackedVector2Array(tr)
		# A curve through the trail's points (no sharp corners where it turns).
		for i in src.size() - 1:
			var p0 := src[maxi(i - 1, 0)]
			var p3 := src[mini(i + 2, src.size() - 1)]
			for k in 8:
				var a := src[i].cubic_interpolate(src[i + 1], p0, p3, k / 8.0)
				pts.append(a + Vector2(sin(a.y * 0.05) * 4.0, 0))
		pts.append(src[src.size() - 1])
		_worn_trail(ci, pts, tint, rng)
	for d in m.get("decor", []):
		if d["kind"] in WarArt.FLAT:
			WarArt.decor(ci, d, tint, rng)
	var shapes: Array = m.get("terrain", [])
	# Ice lies flat on the ground: under everything else, thin ice over the lake it's in.
	for t in shapes:
		if t["kind"] == "ice":
			_ice(ci, PackedVector2Array(t["poly"]), tint, rng, false)
	for t in shapes:
		if t["kind"] == "thin_ice":
			_ice(ci, PackedVector2Array(t["poly"]), tint, rng, true)
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
			"chasm":
				_chasm(ci, poly, tint, rng)
			"building":
				_building(ci, poly, tint, rng)
			"canal":
				_canal(ci, poly, tint, rng)
			"fountain":
				_fountain(ci, poly, tint, rng)
			"stall":
				_stall(ci, poly, tint, rng)
			"crystal":
				_crystal(ci, poly, tint, rng)
			"curtain":
				_curtain(ci, poly, tint, String(m.get("wall", "outer")), w, rng)
			"deadwood":
				WarArt.deadwood(ci, poly, tint, rng)
			"wreck":
				WarArt.wreck(ci, poly, tint, rng)
	# Fords, stairs and bridges go over what they cross.
	for t in shapes:
		var poly := PackedVector2Array(t["poly"])
		match t["kind"]:
			"ford":
				_ford(ci, poly, tint, rng)
			"bridge":
				_bridge(ci, poly, tint, rng)
			"rope_bridge":
				_rope_bridge(ci, poly, tint, rng)
			"stairs":
				_stairs(ci, poly, tint, rng)
	for d in m.get("decor", []):
		match d["kind"]:
			"boat":
				_boat(ci, d["at"], tint, rng)
			"planter":
				_planter(ci, d["at"], tint, rng)
			"crates":
				_crates(ci, d["at"], tint, rng)
			"lamp":
				_street_lamp(ci, d["at"], tint)
			"ogre_banner", "pikes", "deadtree", "stakes":
				WarArt.decor(ci, d, tint, rng)
	for l in m.get("lanterns", []):
		_lantern(ci, l, tint)
	snowy = false
	barren = false


## A stretch of Dawnspire's wall across the top of a field: the walk along its top (flags,
## merlons along the front), its face of dressed stone in courses down to its foot, and a
## tower at each end that stands by a gap (the gate's, or a postern's), with the Ogre
## King's red banners hung from it. "outer": weathered grey, soot from the burning;
## "inner": darker stone; "citadel": pale stone trimmed in gold.
static func _curtain(ci: CanvasItem, poly: PackedVector2Array, tint: Color, style: String, w: float, rng: RandomNumberGenerator) -> void:
	var box := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		box = box.expand(q)
	var x0 := box.position.x
	var x1 := box.end.x
	var foot := box.end.y
	var face_top := foot - 54.0
	var stone: Color = {"outer": Color(0.6, 0.57, 0.52), "inner": Color(0.5, 0.48, 0.47), "citadel": Color(0.86, 0.82, 0.72)}.get(style, Color(0.6, 0.57, 0.52))
	var walk := stone.darkened(0.28)
	var trim := Color(0.92, 0.74, 0.3)
	# The walk along the top.
	ci.draw_rect(Rect2(x0, 0, x1 - x0, face_top), walk * tint)
	var y := 6.0
	while y < face_top - 8.0:
		var x := x0 + (12.0 if int(y / 14.0) % 2 == 0 else 0.0)
		while x < x1:
			ci.draw_rect(Rect2(x, y, 22, 12), (walk.lightened(0.06) if rng.randf() < 0.5 else walk) * tint, false, 1.0)
			x += 24.0
		y += 14.0
	# The face, its courses of blocks.
	ci.draw_rect(Rect2(x0, face_top, x1 - x0, foot - face_top), OUTLINE)
	ci.draw_rect(Rect2(x0, face_top + 2, x1 - x0, foot - face_top - 4), stone * tint)
	var row := 0
	y = face_top + 2.0
	while y < foot - 3.0:
		var x := x0 + (0.0 if row % 2 == 0 else 9.0)
		while x < x1:
			var c := stone if rng.randf() < 0.6 else stone.darkened(0.07)
			if style == "outer" and rng.randf() < 0.12:
				c = c.darkened(0.3)   # soot
			ci.draw_rect(Rect2(x + 1, y + 1, minf(17.0, x1 - x - 1.0), 8), c * tint)
			ci.draw_rect(Rect2(x + 1, y + 1, minf(17.0, x1 - x - 1.0), 1), stone.lightened(0.12) * tint)
			x += 18.0
		y += 10.0
		row += 1
	ci.draw_rect(Rect2(x0, foot - 4, x1 - x0, 4), Color(0, 0, 0, 0.25))
	if style == "citadel":
		ci.draw_rect(Rect2(x0, face_top + 3, x1 - x0, 3), trim * tint)
	# Merlons along the front edge of the walk.
	var mx := x0 + 4.0
	while mx < x1 - 10.0:
		ci.draw_rect(Rect2(mx - 1, face_top - 11, 14, 13), OUTLINE)
		ci.draw_rect(Rect2(mx, face_top - 10, 12, 11), stone.lightened(0.05) * tint)
		ci.draw_rect(Rect2(mx, face_top - 10, 12, 2), stone.lightened(0.2) * tint)
		mx += 22.0
	# What the siege has done to it, and the Line's banners torn down over it.
	WarArt.war_wall(ci, Rect2(x0, 0, x1 - x0, foot), face_top, foot, stone, tint, rng, true)
	# The towers by the gaps (not at the field's own edges).
	for end in [x0, x1]:
		if end <= 1.0 or end >= w - 1.0:
			continue
		var big: bool = absf(end - w / 2.0) < w * 0.15   # the gate's towers stand bigger
		var tw := 44.0 if big else 34.0
		var tx: float = end - tw / 2.0 if end == x0 else end - tw / 2.0
		tx = clampf(tx, x0, x1 - tw)
		var tb := foot + (14.0 if big else 8.0)
		var tt := face_top - (30.0 if big else 20.0)
		ci.draw_rect(Rect2(tx + 5, tt + 8, tw, tb - tt), Color(0, 0, 0, 0.25))
		ci.draw_rect(Rect2(tx - 2, tt - 2, tw + 4, tb - tt + 4), OUTLINE)
		ci.draw_rect(Rect2(tx, tt, tw, tb - tt), stone.lightened(0.04) * tint)
		ci.draw_rect(Rect2(tx, tt, 4, tb - tt), stone.lightened(0.16) * tint)
		ci.draw_rect(Rect2(tx + tw - 5, tt, 5, tb - tt), stone.darkened(0.14) * tint)
		var ty := tt + 14.0
		while ty < tb - 4.0:
			ci.draw_rect(Rect2(tx, ty, tw, 1), stone.darkened(0.2) * tint)
			ty += 10.0
		for k in int(tw / 11.0):
			ci.draw_rect(Rect2(tx + 1 + k * 11, tt - 9, 8, 9), OUTLINE)
			ci.draw_rect(Rect2(tx + 2 + k * 11, tt - 8, 6, 8), stone.lightened(0.1) * tint)
		ci.draw_rect(Rect2(tx + tw / 2.0 - 2, tt + 18, 4, 10), OUTLINE)   # an arrow slit
		if style == "citadel":
			ci.draw_rect(Rect2(tx, tt + 2, tw, 3), trim * tint)
		# The Ogre King's banner hung down its face: red, a black tusked skull.
		var bx := tx + tw / 2.0 - 8.0
		var by := tt + 30.0
		var rag := PackedVector2Array([Vector2(bx, by), Vector2(bx + 16, by), Vector2(bx + 16, by + 26), Vector2(bx + 13, by + 31),
				Vector2(bx + 11, by + 25), Vector2(bx + 8, by + 34), Vector2(bx + 5, by + 27), Vector2(bx + 2, by + 32), Vector2(bx, by + 24)])
		WarArt.outlined(ci, rag, Color(0.62, 0.12, 0.1) * tint)
		ci.draw_rect(Rect2(bx - 2, by - 2, 20, 3), OUTLINE)   # its pole
		ci.draw_rect(Rect2(bx + 11, by + 3, 2, 18), Color(0.46, 0.08, 0.07) * tint)   # a fold
		ci.draw_rect(Rect2(bx + 4, by + 7, 8, 7), Color(0.1, 0.07, 0.07))   # the daubed skull
		ci.draw_rect(Rect2(bx + 5, by + 9, 2, 2), Color(0.62, 0.12, 0.1) * tint)
		ci.draw_rect(Rect2(bx + 9, by + 9, 2, 2), Color(0.62, 0.12, 0.1) * tint)
		ci.draw_rect(Rect2(bx + 4, by + 14, 1, 3), Color(0.9, 0.86, 0.78))
		ci.draw_rect(Rect2(bx + 11, by + 14, 1, 3), Color(0.9, 0.86, 0.78))


## A square paved in dressed stone: a dark kerb, big pale flags in courses, and a round
## mosaic (a sun of two stones) set in it.
static func _plaza(ci: CanvasItem, r: Rect2, c: Vector2, rad: float, tint: Color) -> void:
	ci.draw_rect(r.grow(3), Color(0.36, 0.33, 0.3) * tint)
	ci.draw_rect(r, Color(0.7, 0.66, 0.58) * tint)
	var y := r.position.y
	var row := 0
	while y < r.end.y - 1:
		var x := r.position.x - (12.0 if row % 2 else 0.0)
		while x < r.end.x - 1:
			var cell := Rect2(maxf(x, r.position.x), y, minf(x + 24.0, r.end.x) - maxf(x, r.position.x), minf(16.0, r.end.y - y))
			ci.draw_rect(cell, Color(0.6, 0.56, 0.5) * tint, false, 1.0)
			ci.draw_rect(Rect2(cell.position + Vector2(1, 1), Vector2(cell.size.x - 2, 1)), Color(0.78, 0.74, 0.66) * tint)
			x += 24.0
		y += 16.0
		row += 1
	ci.draw_circle(c, rad + 3.0, Color(0.42, 0.38, 0.34) * tint)
	ci.draw_circle(c, rad, Color(0.78, 0.72, 0.6) * tint)
	ci.draw_circle(c, rad - 8.0, Color(0.56, 0.44, 0.34) * tint)
	ci.draw_circle(c, rad - 11.0, Color(0.8, 0.75, 0.64) * tint)
	for i in 16:
		var a := i * TAU / 16.0
		var tip := c + Vector2.from_angle(a) * (rad - 13.0) * (1.0 if i % 2 == 0 else 0.62)
		var side := Vector2.from_angle(a + PI / 2.0) * rad * 0.1
		ci.draw_colored_polygon(PackedVector2Array([c + side, tip, c - side]),
				(Color(0.62, 0.5, 0.36) if i % 2 == 0 else Color(0.5, 0.52, 0.56)) * tint)
	ci.draw_circle(c, rad * 0.16, Color(0.42, 0.38, 0.34) * tint)
	ci.draw_circle(c, rad * 0.1, Color(0.86, 0.72, 0.4) * tint)


## A rowing boat moored in a canal, its rope to the bank.
static func _boat(ci: CanvasItem, at: Vector2, tint: Color, rng: RandomNumberGenerator) -> void:
	var hull := PackedVector2Array([at + Vector2(-17, -6), at + Vector2(12, -6), at + Vector2(19, 0), at + Vector2(12, 6),
			at + Vector2(-17, 6), at + Vector2(-20, 0)])
	ci.draw_colored_polygon(_shifted(hull, Vector2(2, 3)), Color(0, 0, 0, 0.25))
	ci.draw_colored_polygon(PackedVector2Array(Geometry2D.offset_polygon(hull, 1.5)[0]), OUTLINE)
	var wood: Color = [Color(0.55, 0.36, 0.2), Color(0.45, 0.3, 0.2), Color(0.36, 0.42, 0.5)][rng.randi() % 3]
	ci.draw_colored_polygon(hull, wood * tint)
	ci.draw_rect(Rect2(at + Vector2(-15, -3), Vector2(26, 6)), wood.darkened(0.35) * tint)
	for x in [-9, 1]:
		ci.draw_rect(Rect2(at + Vector2(x, -4), Vector2(3, 8)), wood.lightened(0.2) * tint)
	ci.draw_line(at + Vector2(-20, 0), at + Vector2(-26, -14), Color(0.75, 0.68, 0.5) * tint, 1.0)


## A stone tub with a clipped bush in it, and flowers.
static func _planter(ci: CanvasItem, at: Vector2, tint: Color, rng: RandomNumberGenerator) -> void:
	ci.draw_rect(Rect2(at + Vector2(-9, 0), Vector2(22, 6)), Color(0, 0, 0, 0.22))
	ci.draw_rect(Rect2(at + Vector2(-11, -4), Vector2(22, 10)), OUTLINE)
	ci.draw_rect(Rect2(at + Vector2(-10, -3), Vector2(20, 8)), Color(0.66, 0.62, 0.56) * tint)
	ci.draw_rect(Rect2(at + Vector2(-10, -3), Vector2(20, 2)), Color(0.8, 0.76, 0.7) * tint)
	ci.draw_circle(at + Vector2(0, -11), 10.5, OUTLINE)
	ci.draw_circle(at + Vector2(0, -11), 9.5, Color(0.24, 0.46, 0.24) * tint)
	ci.draw_circle(at + Vector2(-3, -14), 5.0, Color(0.34, 0.58, 0.3) * tint)
	for i in 5:
		var p := at + Vector2(rng.randf_range(-7, 7), rng.randf_range(-17, -6))
		ci.draw_rect(Rect2(p, Vector2(2, 2)), [Color(0.95, 0.4, 0.45), Color(1.0, 0.85, 0.35), Color(0.95, 0.95, 0.9)][rng.randi() % 3] * tint)


## Goods stacked at a door: a crate or two and a barrel.
static func _crates(ci: CanvasItem, at: Vector2, tint: Color, rng: RandomNumberGenerator) -> void:
	var wood := Color(0.62, 0.44, 0.26)
	ci.draw_rect(Rect2(at + Vector2(-10, 2), Vector2(26, 5)), Color(0, 0, 0, 0.22))
	var boxes := [Rect2(at + Vector2(-11, -8), Vector2(11, 11))]
	if rng.randf() < 0.6:
		boxes.append(Rect2(at + Vector2(-8, -17), Vector2(9, 9)))
	for b in boxes:
		ci.draw_rect(b.grow(1), OUTLINE)
		ci.draw_rect(b, wood * tint)
		ci.draw_line(b.position, b.end, wood.darkened(0.3) * tint, 1.0)
		ci.draw_line(Vector2(b.end.x, b.position.y), Vector2(b.position.x, b.end.y), wood.darkened(0.3) * tint, 1.0)
	ci.draw_rect(Rect2(at + Vector2(2, -9), Vector2(10, 13)), OUTLINE)
	ci.draw_rect(Rect2(at + Vector2(3, -8), Vector2(8, 11)), Color(0.5, 0.32, 0.18) * tint)
	for y in [-6, 0]:
		ci.draw_rect(Rect2(at + Vector2(3, y), Vector2(8, 1)), Color(0.3, 0.3, 0.32) * tint)


## A city street lamp: an iron post with a glass lamp atop.
static func _street_lamp(ci: CanvasItem, at: Vector2, tint: Color) -> void:
	ci.draw_rect(Rect2(at + Vector2(-3, -1), Vector2(7, 3)), Color(0, 0, 0, 0.25))
	ci.draw_rect(Rect2(at + Vector2(-2, -26), Vector2(4, 27)), OUTLINE)
	ci.draw_rect(Rect2(at + Vector2(-1, -25), Vector2(2, 25)), Color(0.24, 0.24, 0.27) * tint)
	ci.draw_rect(Rect2(at + Vector2(-4, -3), Vector2(8, 3)), Color(0.24, 0.24, 0.27) * tint)
	ci.draw_rect(Rect2(at + Vector2(-5, -36), Vector2(10, 11)), OUTLINE)
	ci.draw_rect(Rect2(at + Vector2(-4, -35), Vector2(8, 9)), Color(1.0, 0.86, 0.55) * tint)
	ci.draw_rect(Rect2(at + Vector2(-6, -38), Vector2(12, 3)), OUTLINE)
	ci.draw_rect(Rect2(at + Vector2(-1, -41), Vector2(2, 3)), OUTLINE)


static func _bottom(poly: Array) -> float:
	var y := -INF
	for p in poly:
		y = maxf(y, p.y)
	return y


static var snowy := false
static var barren := false   # painting war-torn ground: no wildflowers   # painting a snow battlefield: trees and rocks wear snow


## Snowfields: blue-white drifts in light and shadow, wind ripples, the odd frozen tuft
## and stone poking through, sparkles of frost.
static func draw_snow(ci: CanvasItem, w: float, tint: Color, y0 := TOP, y1 := 736.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7272
	ci.draw_rect(Rect2(0, y0, w, y1 - y0), Color(0.88, 0.91, 0.95) * tint)
	var y := y0
	while y < y1:
		var x := 0.0
		while x < w:
			var v := sin(x * 0.011 + 0.4) * sin(y * 0.015 + 0.9) + sin(x * 0.027 - y * 0.019) * 0.5
			if absf(v) > 0.2:
				var c := Color(1.0, 1.0, 1.0) if v > 0.0 else Color(0.66, 0.74, 0.86)
				ci.draw_rect(Rect2(x, y, 32, 32), Color(c * tint, minf(absf(v) * 0.2, 0.22)))
			x += 32.0
		y += 32.0
	# Wind ripples: long shallow curves of shadow across the drifts.
	for i in int(70 * w / 640.0):
		var p := Vector2(rng.randf_range(0, w), rng.randf_range(y0 + 6, y1 - 6))
		var len := rng.randf_range(18, 46)
		ci.draw_line(p, p + Vector2(len, rng.randf_range(-3, 3)), Color(0.7, 0.78, 0.9, 0.55) * tint, 1.5)
		ci.draw_line(p + Vector2(2, 1.5), p + Vector2(len - 2, 1.5), Color(1, 1, 1, 0.5) * tint, 1.0)
	for i in int(40 * w / 640.0):
		var p := Vector2(rng.randf_range(0, w), rng.randf_range(y0 + 10, y1 - 8))
		var s := rng.randf_range(2.0, 4.0)
		ci.draw_rect(Rect2(p, Vector2(s, s * 0.7)), Color(0.45, 0.48, 0.55) * tint)
		ci.draw_rect(Rect2(p - Vector2(0, 1), Vector2(s, 1)), Color(1, 1, 1) * tint)
	for i in int(30 * w / 640.0):
		var p := Vector2(rng.randf_range(10, w - 10), rng.randf_range(y0 + 20, y1 - 46))
		for k in 3:
			ci.draw_line(p + Vector2(k * 2 - 2, 0), p + Vector2(k * 3 - 3, -5), Color(0.5, 0.56, 0.44) * tint, 1.0)
	for i in int(120 * w / 640.0):
		var p := Vector2(rng.randf_range(0, w), rng.randf_range(y0 + 4, y1 - 6))
		ci.draw_rect(Rect2(p, Vector2(1, 1)), Color(1, 1, 1))


## A city's ground: cobbles laid in rows, worn paler down the middle of the streets,
## gutters and the odd drain grate.
static func draw_city(ci: CanvasItem, w: float, tint: Color, y0 := TOP, y1 := 736.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6363
	ci.draw_rect(Rect2(0, y0, w, y1 - y0), Color(0.52, 0.48, 0.44) * tint)
	var y := y0
	var row := 0
	while y < y1:
		var x := -float(row % 2) * 7.0
		while x < w:
			var c := Color(0.6, 0.56, 0.5) if rng.randf() < 0.5 else Color(0.56, 0.52, 0.47)
			if rng.randf() < 0.08:
				c = Color(0.48, 0.44, 0.4)
			ci.draw_rect(Rect2(x + 1, y + 1, 12, 7), c * tint)
			ci.draw_rect(Rect2(x + 1, y + 1, 12, 1), Color(0.68, 0.64, 0.58) * tint)
			x += 14.0
		y += 9.0
		row += 1
	for i in int(10 * w / 640.0):
		var p := Vector2(rng.randf_range(20, w - 20), rng.randf_range(y0 + 30, y1 - 46))
		ci.draw_rect(Rect2(p, Vector2(10, 8)), OUTLINE)
		for k in 3:
			ci.draw_rect(Rect2(p + Vector2(2 + k * 3, 1), Vector2(1, 6)), Color(0.32, 0.3, 0.3) * tint)


## A chasm: the ground falls away to a blue-grey depth, mist in it, a rim of broken rock.
static func _chasm(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	ci.draw_colored_polygon(poly, Color(0.28, 0.26, 0.26) * tint)
	var depth := [Color(0.2, 0.2, 0.24), Color(0.14, 0.15, 0.2), Color(0.1, 0.11, 0.16)]
	for i in depth.size():
		for p in Geometry2D.offset_polygon(poly, -4.0 - i * 7.0):
			ci.draw_colored_polygon(p, depth[i] * tint)
	for p in _inside(poly, 10.0, 10, rng):
		ci.draw_circle(p, rng.randf_range(5, 10), Color(0.75, 0.8, 0.88, 0.12))
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var n := int(a.distance_to(b) / 10.0)
		for k in n:
			var q: Vector2 = a.lerp(b, (k + rng.randf()) / maxf(n, 1))
			ci.draw_rect(Rect2(q - Vector2(2, 2), Vector2(rng.randf_range(3, 6), rng.randf_range(3, 5))), (Color(0.92, 0.94, 0.98) if snowy else Color(0.5, 0.46, 0.42)) * tint)


## A city building (its shape's bounding box): plastered walls under a tiled roof, seen
## from above at an angle, windows, a door onto the street, a chimney.
static func _building(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	var box := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		box = box.expand(q)
	ci.draw_colored_polygon(_shifted(poly, Vector2(5, 7)), Color(0, 0, 0, 0.25))
	var plaster: Color = [Color(0.9, 0.84, 0.72), Color(0.86, 0.74, 0.62), Color(0.8, 0.82, 0.78), Color(0.92, 0.8, 0.7)][rng.randi() % 4]
	var roof_c: Color = [Color(0.66, 0.3, 0.22), Color(0.4, 0.36, 0.5), Color(0.55, 0.42, 0.3)][rng.randi() % 3]
	var wall_top := box.position.y + box.size.y * 0.5
	var walls := Rect2(box.position.x, wall_top, box.size.x, box.end.y - wall_top)
	ci.draw_rect(walls.grow(1.5), OUTLINE)
	ci.draw_rect(walls, plaster * tint)
	for x in range(int(walls.position.x) + 6, int(walls.end.x) - 8, 14):
		ci.draw_rect(Rect2(x, walls.position.y + 5, 7, 8), OUTLINE)
		ci.draw_rect(Rect2(x + 1, walls.position.y + 6, 5, 6), (Color(1.0, 0.82, 0.45) if rng.randf() < 0.4 else Color(0.32, 0.38, 0.48)) * tint)
	var door := walls.position.x + walls.size.x * rng.randf_range(0.3, 0.7)
	ci.draw_rect(Rect2(door - 5, walls.end.y - 14, 10, 14), OUTLINE)
	ci.draw_rect(Rect2(door - 4, walls.end.y - 13, 8, 13), Color(0.45, 0.28, 0.16) * tint)
	var roof := Rect2(box.position.x - 2, box.position.y, box.size.x + 4, wall_top - box.position.y + 3)
	ci.draw_rect(roof.grow(1.5), OUTLINE)
	ci.draw_rect(roof, roof_c * tint)
	var ty := roof.position.y + 4
	while ty < roof.end.y - 1:
		ci.draw_line(Vector2(roof.position.x, ty), Vector2(roof.end.x, ty), roof_c.darkened(0.25) * tint, 1.0)
		ty += 5
	ci.draw_line(Vector2(roof.position.x, roof.get_center().y), Vector2(roof.end.x, roof.get_center().y), roof_c.lightened(0.2) * tint, 2.0)
	if rng.randf() < 0.7:
		var cx := roof.position.x + roof.size.x * rng.randf_range(0.15, 0.85)
		ci.draw_rect(Rect2(cx - 4, roof.position.y - 6, 8, 10), OUTLINE)
		ci.draw_rect(Rect2(cx - 3, roof.position.y - 5, 6, 8), Color(0.55, 0.5, 0.46) * tint)


## A fountain in a paved plaza: a ring of flagstones round it, a stone basin of water,
## and a pillar in the middle with water spilling from its bowl.
static func _fountain(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	var c := Vector2.ZERO
	for q in poly:
		c += q
	c /= poly.size()
	var r := 0.0
	for q in poly:
		r = maxf(r, q.distance_to(c))
	var stone := Color(0.74, 0.71, 0.64) * tint
	# The plaza's paving, out round the basin.
	ci.draw_circle(c, r + 46.0, Color(0.6, 0.57, 0.5, 0.55) * tint)
	ci.draw_circle(c, r + 42.0, Color(0.7, 0.67, 0.6, 0.55) * tint)
	for i in 40:
		var a := rng.randf() * TAU
		var p := c + Vector2.from_angle(a) * rng.randf_range(r + 6.0, r + 40.0)
		ci.draw_rect(Rect2(p, Vector2(8, 5)), Color(0.62, 0.59, 0.52, 0.6) * tint, false, 1.0)
	# The basin.
	ci.draw_circle(c + Vector2(0, 4), r + 2.0, Color(0, 0, 0, 0.22))
	ci.draw_circle(c, r + 1.5, OUTLINE)
	ci.draw_circle(c, r, stone)
	ci.draw_circle(c, r - 6.0, OUTLINE)
	ci.draw_circle(c, r - 7.0, Color(0.22, 0.42, 0.55) * tint)
	ci.draw_circle(c, r - 12.0, Color(0.28, 0.5, 0.62) * tint)
	for i in 6:
		var a := rng.randf() * TAU
		var p := c + Vector2.from_angle(a) * rng.randf_range(10.0, r - 12.0)
		ci.draw_line(p, p + Vector2(rng.randf_range(4, 8), 0), Color(0.7, 0.85, 0.92, 0.7) * tint, 1.5)
	# The pillar and its bowl, water spilling down.
	ci.draw_rect(Rect2(c + Vector2(-5, -18), Vector2(10, 20)), OUTLINE)
	ci.draw_rect(Rect2(c + Vector2(-4, -17), Vector2(8, 18)), stone.lightened(0.1))
	ci.draw_rect(Rect2(c + Vector2(-12, -22), Vector2(24, 7)), OUTLINE)
	ci.draw_rect(Rect2(c + Vector2(-11, -21), Vector2(22, 5)), stone.lightened(0.15))
	for x in [-10.0, -4.0, 4.0, 10.0]:
		ci.draw_line(c + Vector2(x, -16), c + Vector2(x * 1.4, -2), Color(0.75, 0.9, 1.0, 0.8) * tint, 1.5)
	ci.draw_circle(c + Vector2(0, -26), 3.0, Color(0.75, 0.9, 1.0, 0.85) * tint)


## A crystal outcrop (the Arcane Spires): a dark plinth of rock with shards of violet
## crystal standing out of it, lit along one face, a few small ones round their feet.
static func _crystal(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	var box := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		box = box.expand(q)
	ci.draw_colored_polygon(_shifted(poly, Vector2(4, 6)), Color(0, 0, 0, 0.25))
	ci.draw_colored_polygon(poly, OUTLINE)
	for p in Geometry2D.offset_polygon(poly, -2.0):
		ci.draw_colored_polygon(p, Color(0.27, 0.24, 0.32) * tint)
	for p in Geometry2D.offset_polygon(poly, -6.0):
		ci.draw_colored_polygon(p, Color(0.33, 0.3, 0.4) * tint)
	# Shards, back to front: tall ones in the middle, shorter towards the edges.
	var n := clampi(int(box.size.x / 12.0), 3, 9)
	var shards := []
	for i in n:
		var f := (i + 0.5) / n
		var x := box.position.x + box.size.x * (0.12 + 0.76 * f) + rng.randf_range(-4, 4)
		var foot := box.position.y + box.size.y * rng.randf_range(0.55, 0.85)
		var h := box.size.y * (0.7 + 0.6 * (1.0 - absf(f - 0.5) * 2.0)) * rng.randf_range(0.8, 1.15)
		shards.append([x, foot, h, rng.randf_range(6, 11), rng.randf_range(-0.25, 0.25)])
	shards.sort_custom(func(a, b): return a[1] < b[1])
	var hues := [Color(0.62, 0.42, 0.95), Color(0.5, 0.45, 1.0), Color(0.75, 0.5, 1.0)]
	for s in shards:
		var col: Color = hues[rng.randi() % hues.size()] * tint
		var base := Vector2(s[0], s[1])
		var w: float = s[3]
		var tip: Vector2 = base + Vector2(s[4] * s[2], -s[2])
		var body := PackedVector2Array([base + Vector2(-w, 0), base + Vector2(-w * 0.8, -s[2] * 0.75), tip, base + Vector2(w * 0.8, -s[2] * 0.75), base + Vector2(w, 0)])
		ci.draw_colored_polygon(PackedVector2Array([body[0] + Vector2(-1.5, 1), body[1] + Vector2(-1.5, 0), body[2] + Vector2(0, -2), body[3] + Vector2(1.5, 0), body[4] + Vector2(1.5, 1)]), OUTLINE)
		ci.draw_colored_polygon(body, col.darkened(0.2))
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.1, 0), base + Vector2(-w * 0.15, -s[2] * 0.75), tip, base + Vector2(w * 0.8, -s[2] * 0.75), base + Vector2(w, 0)]), col)
		ci.draw_line(base + Vector2(w * 0.35, -2), tip.lerp(base + Vector2(w * 0.35, 0), 0.15), col.lightened(0.45), 1.5)
	for i in 4:
		var q := box.position + Vector2(rng.randf_range(0.1, 0.9) * box.size.x, box.size.y * rng.randf_range(0.75, 0.95))
		ci.draw_colored_polygon(PackedVector2Array([q + Vector2(-3, 0), q + Vector2(0, -8), q + Vector2(3, 0)]), Color(0.7, 0.55, 1.0) * tint)


## The Arcane Spires' floating islands (biome "void"): a night sky of violet haze and
## stars under the camp's ground, great crystal spires drifting in it, the bridges
## glowing in their sigils' colours, and the islands themselves, pale flagstones on top
## of rock that tapers away beneath them; the castle's ground along the bottom.
static func draw_islands(ci: CanvasItem, w: float, tint: Color, m: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var top := 100.0
	var h := 768.0
	# The sky: bands from deep indigo to violet, haze, stars.
	for i in 12:
		var y0 := top + i * (h - top) / 12.0
		ci.draw_rect(Rect2(0, y0, w, (h - top) / 12.0 + 1), Color(0.07, 0.05, 0.16).lerp(Color(0.2, 0.12, 0.32), i / 11.0) * tint)
	for i in 9:
		var c := Vector2(rng.randf_range(0, w), rng.randf_range(top + 40, h - 60))
		for k in 4:
			ci.draw_circle(c, rng.randf_range(60, 120) * (1.0 - k * 0.2), Color(Color(0.45, 0.3, 0.75) * tint, 0.05))
	for i in 140:
		var p := Vector2(rng.randf_range(0, w), rng.randf_range(top, h))
		var b := rng.randf_range(0.4, 1.0)
		ci.draw_rect(Rect2(p, Vector2(2, 2) if rng.randf() < 0.2 else Vector2(1, 1)), Color(Color(0.85, 0.8, 1.0) * tint, b))
	# Great crystal spires drifting in the void, far below and between the islands.
	var walk: Array = preload("res://scripts/maps.gd").walkable(m)
	var placed := 0
	var tries := 0
	while placed < 7 and tries < 200:
		tries += 1
		var at := Vector2(rng.randf_range(20, w - 20), rng.randf_range(top + 60, h - 40))
		var clear := true
		for shape in walk:
			if Geometry2D.is_point_in_polygon(at, shape) or Geometry2D.is_point_in_polygon(at + Vector2(0, -50), shape):
				clear = false
				break
		if clear:
			_drifting_spire(ci, at, rng.randf_range(0.6, 1.1), tint, rng)
			placed += 1
	# The lands: the camp's ground hangs over the void at its foot; the castle's ground.
	for land in m.get("lands", []):
		var r: Rect2 = land
		if r.position.y > 300.0:
			_island_rock(ci, PackedVector2Array([Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y + 18), Vector2(r.position.x, r.position.y + 18)]), tint, false)
			_flagstones(ci, Rect2(r.position.x, r.position.y + 2, r.size.x, r.size.y), tint, rng, func(_p): return true)
		else:
			var lip := PackedVector2Array()
			for i in 24:
				var x: float = r.position.x + r.size.x * i / 23.0
				lip.append(Vector2(x, r.end.y + 14.0 + sin(x * 0.11) * 6.0 + rng.randf_range(0, 6)))
			var hang := PackedVector2Array([Vector2(r.position.x, r.end.y - 2), Vector2(r.end.x, r.end.y - 2)])
			lip.reverse()
			hang.append_array(lip)
			ci.draw_colored_polygon(hang, Color(0.22, 0.18, 0.26) * tint)
			ci.draw_polyline(hang + PackedVector2Array([hang[0]]), OUTLINE, 2.0)
	# The islands, back to front.
	var isles: Array = (m.get("islands", []) as Array).duplicate()
	isles.sort_custom(func(a, b): return a["at"].y < b["at"].y)
	for i in isles:
		var c: Vector2 = i["at"]
		var rx: float = i.get("rx", i["r"])
		var ry: float = i["r"]
		# Underneath: rock in strata, tapering to a point far below.
		var pts := PackedVector2Array()
		for n in 24:
			var a := n * TAU / 24.0
			pts.append(c + Vector2(cos(a) * rx * 0.96, sin(a) * ry * 0.9 + ry * 0.3))
		pts.append(c + Vector2(rx * 0.2, ry * 1.55))
		pts.append(c + Vector2(-rx * 0.05, ry * 1.8))
		pts.append(c + Vector2(-rx * 0.3, ry * 1.5))
		var under := Geometry2D.convex_hull(pts)   # (always a shape that draws)
		under.remove_at(under.size() - 1)   # (the hull repeats its first point at the end)
		_island_rock(ci, under, tint, true)
	# The bridges: over the rock beneath the islands, under their tops.
	var colors: Array = preload("res://scripts/conduits.gd").COLORS
	for b in m.get("bridges", []):
		var col: Color = colors[int(b["path"])] if int(b["path"]) >= 0 else Color(0.78, 0.66, 1.0)
		_arcane_bridge(ci, b["from"], b["to"], float(b["w"]), col * tint)
	for i in isles:
		var c: Vector2 = i["at"]
		var rx: float = i.get("rx", i["r"])
		var ry: float = i["r"]
		# The top: pale flagstones within its edge, a lit rim.
		var disc := PackedVector2Array()
		for n in 32:
			var a := n * TAU / 32.0
			disc.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		ci.draw_colored_polygon(disc, OUTLINE)
		var inner := PackedVector2Array()
		for q in disc:
			inner.append(c + (q - c) * ((rx - 3.0) / rx))
		ci.draw_colored_polygon(inner, Color(0.56, 0.53, 0.62) * tint)
		_flagstones(ci, Rect2(c - Vector2(rx, ry), Vector2(rx, ry) * 2.0), tint, rng,
				func(p: Vector2): return Vector2((p.x - c.x) / (rx - 8.0), (p.y - c.y) / (ry - 8.0)).length() < 1.0)
		ci.draw_polyline(inner + PackedVector2Array([inner[0]]), Color(0.78, 0.74, 0.88) * tint, 2.0)
		var path: int = int(i.get("path", -1))
		if path >= 0:
			ci.draw_arc(c, ry - 6.0, PI * 1.1, PI * 1.9, 20, Color(colors[path] * tint, 0.35), 2.0, true)


## Rock seen from beside: dark strata with lighter seams and an outline.
static func _island_rock(ci: CanvasItem, poly: PackedVector2Array, tint: Color, strata: bool) -> void:
	ci.draw_colored_polygon(poly, Color(0.25, 0.21, 0.3) * tint)
	if strata:
		# Darker rock inside, layer on layer, each within the last.
		for k in [1, 2, 3]:
			for inner in Geometry2D.offset_polygon(poly, -7.0 * k):
				ci.draw_colored_polygon(inner, (Color(0.25, 0.21, 0.3).darkened(0.12 * k)) * tint)
	ci.draw_polyline(poly + PackedVector2Array([poly[0]]), OUTLINE, 2.0)


## Pale flagstones over `r`, only where `inside` says (an island's top, the castle's ground).
static func _flagstones(ci: CanvasItem, r: Rect2, tint: Color, rng: RandomNumberGenerator, inside: Callable) -> void:
	var y := r.position.y + 4.0
	var row := 0
	while y < r.end.y - 4.0:
		var x := r.position.x + (0.0 if row % 2 == 0 else 9.0)
		while x < r.end.x - 4.0:
			var stone := Rect2(x, y, rng.randf_range(12, 20), 9)
			if inside.call(stone.get_center()):
				var shade := rng.randf_range(-0.05, 0.05)
				ci.draw_rect(stone.grow(-1), (Color(0.62, 0.59, 0.68) + Color(shade, shade, shade, 0)) * tint)
				ci.draw_rect(Rect2(stone.position + Vector2(1, 1), Vector2(stone.size.x - 2, 1)), Color(0.72, 0.69, 0.78) * tint)
			x += stone.size.x
		y += 10.0
		row += 1


## A bridge of rune-stone and light between islands: dark slabs edged in its colour, a
## band of glow down the middle, runes along it.
static func _arcane_bridge(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * w / 2.0
	ci.draw_colored_polygon(PackedVector2Array([a + n * 1.35, b + n * 1.35, b - n * 1.35, a - n * 1.35]), Color(col, 0.12))
	var deck := PackedVector2Array([a + n, b + n, b - n, a - n])
	ci.draw_colored_polygon(deck, OUTLINE)
	ci.draw_colored_polygon(PackedVector2Array([a + n * 0.9, b + n * 0.9, b - n * 0.9, a - n * 0.9]), Color(0.18, 0.15, 0.24))
	var steps := int(a.distance_to(b) / 12.0)
	for i in steps:
		var p := a.lerp(b, (i + 0.5) / steps)
		ci.draw_line(p + n * 0.85, p - n * 0.85, Color(0.12, 0.1, 0.16), 1.0)
	ci.draw_colored_polygon(PackedVector2Array([a + n * 0.28, b + n * 0.28, b - n * 0.28, a - n * 0.28]), Color(col, 0.55))
	ci.draw_colored_polygon(PackedVector2Array([a + n * 0.1, b + n * 0.1, b - n * 0.1, a - n * 0.1]), Color(col.lightened(0.4), 0.85))
	ci.draw_line(a + n * 0.9, b + n * 0.9, col, 2.0)
	ci.draw_line(a - n * 0.9, b - n * 0.9, col, 2.0)
	for i in range(1, steps, 3):
		var p := a.lerp(b, float(i) / steps)
		ci.draw_rect(Rect2(p + n * 0.55 - Vector2(2, 2), Vector2(4, 4)), col.lightened(0.3))
		ci.draw_rect(Rect2(p - n * 0.55 - Vector2(2, 2), Vector2(4, 4)), col.lightened(0.3))


## A great crystal spire drifting in the void: a tall shard and its smaller kin, glowing.
static func _drifting_spire(ci: CanvasItem, at: Vector2, s: float, tint: Color, rng: RandomNumberGenerator) -> void:
	ci.draw_circle(at + Vector2(0, -30 * s), 34.0 * s, Color(Color(0.6, 0.4, 1.0) * tint, 0.08))
	for k in 3:
		var off := Vector2([0.0, -14.0, 13.0][k] * s, [0.0, 10.0, 8.0][k] * s)
		var hh: float = [80.0, 46.0, 38.0][k] * s
		var ww: float = [10.0, 7.0, 6.0][k] * s
		var base := at + off
		var tip := base + Vector2(rng.randf_range(-4, 4) * s, -hh)
		var body := PackedVector2Array([base + Vector2(-ww, 0), base + Vector2(-ww * 0.8, -hh * 0.7), tip, base + Vector2(ww * 0.8, -hh * 0.7), base + Vector2(ww, 0), base + Vector2(0, ww * 1.4)])
		ci.draw_colored_polygon(body, Color(0.36, 0.26, 0.62) * tint)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(0, ww * 1.4), base + Vector2(0, -hh * 0.7), tip, base + Vector2(ww * 0.8, -hh * 0.7), base + Vector2(ww, 0)]), Color(0.52, 0.4, 0.86) * tint)
		ci.draw_polyline(body + PackedVector2Array([body[0]]), Color(0.08, 0.05, 0.14), 1.5)


## A market stall: a striped awning on two posts over a counter of goods.
static func _stall(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	var box := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		box = box.expand(q)
	var stripe: Color = [Color(0.85, 0.25, 0.25), Color(0.25, 0.45, 0.8), Color(0.3, 0.65, 0.35), Color(0.9, 0.6, 0.2)][rng.randi() % 4]
	var cream := Color(0.96, 0.92, 0.82)
	var wood := Color(0.5, 0.33, 0.18)
	ci.draw_rect(Rect2(box.position + Vector2(4, 6), box.size), Color(0, 0, 0, 0.22))
	# The counter, with goods on it.
	var counter := Rect2(box.position.x + 2, box.end.y - 12, box.size.x - 4, 12)
	ci.draw_rect(counter.grow(1.5), OUTLINE)
	ci.draw_rect(counter, wood * tint)
	ci.draw_rect(Rect2(counter.position, Vector2(counter.size.x, 2)), wood.lightened(0.25) * tint)
	for x in range(int(counter.position.x) + 4, int(counter.end.x) - 4, 6):
		ci.draw_rect(Rect2(x, counter.position.y - 3, 4, 4), OUTLINE)
		ci.draw_rect(Rect2(x + 1, counter.position.y - 2, 2, 2), [Color(0.95, 0.4, 0.3), Color(1.0, 0.82, 0.3), Color(0.5, 0.8, 0.3), Color(0.7, 0.45, 0.9)][rng.randi() % 4] * tint)
	# The posts.
	for x in [box.position.x + 3, box.end.x - 6]:
		ci.draw_rect(Rect2(x - 1, box.position.y + 8, 5, box.size.y - 12), OUTLINE)
		ci.draw_rect(Rect2(x, box.position.y + 8, 3, box.size.y - 12), wood * tint)
	# The striped awning, scalloped along its edge.
	var aw := Rect2(box.position.x - 3, box.position.y, box.size.x + 6, 11)
	ci.draw_rect(aw.grow(1.5), OUTLINE)
	var n := int(aw.size.x / 6.0)
	for i in n:
		ci.draw_rect(Rect2(aw.position.x + i * aw.size.x / n, aw.position.y, aw.size.x / n + 0.5, aw.size.y), (stripe if i % 2 == 0 else cream) * tint)
		ci.draw_circle(Vector2(aw.position.x + (i + 0.5) * aw.size.x / n, aw.end.y), aw.size.x / n * 0.5, (stripe if i % 2 == 0 else cream) * tint)


## A lantern post: a pole with a paper lantern hung from it, glowing warm.
static func _lantern(ci: CanvasItem, l: Vector2, tint: Color) -> void:
	ci.draw_circle(l + Vector2(0, -26), 22.0, Color(1.0, 0.75, 0.35, 0.16))
	ci.draw_circle(l + Vector2(0, -26), 13.0, Color(1.0, 0.8, 0.4, 0.2))
	ci.draw_rect(Rect2(l + Vector2(-2, -24), Vector2(4, 26)), OUTLINE)
	ci.draw_rect(Rect2(l + Vector2(-1, -23), Vector2(2, 24)), Color(0.4, 0.28, 0.18) * tint)
	ci.draw_rect(Rect2(l + Vector2(-7, -36), Vector2(14, 14)), OUTLINE)
	ci.draw_rect(Rect2(l + Vector2(-6, -35), Vector2(12, 12)), Color(1.0, 0.62, 0.3).lerp(Color(1, 0.95, 0.7), 0.3))
	ci.draw_line(l + Vector2(-6, -29), l + Vector2(6, -29), Color(0.8, 0.45, 0.2), 1.0)


## A canal: water between stone embankments.
static func _canal(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	ci.draw_colored_polygon(poly, Color(0.6, 0.56, 0.5) * tint)   # the embankment
	for p in Geometry2D.offset_polygon(poly, -5.0):
		ci.draw_colored_polygon(p, Color(0.2, 0.36, 0.46) * tint)
	for p in Geometry2D.offset_polygon(poly, -12.0):
		ci.draw_colored_polygon(p, Color(0.17, 0.32, 0.42) * tint)
	for p in _inside(poly, 10.0, 16, rng):
		ci.draw_line(p, p + Vector2(rng.randf_range(6, 14), 0), Color(0.55, 0.72, 0.82, 0.6) * tint, 1.5)


## Ice: a frozen lake, pale blue and glassy, with bands of light across it and snow
## blown along its edges. Thin ice is darker (water shows through) and crazed with fine
## cracks, ringed with warning stakes, so it's plain where it can give way.
static func _ice(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator, thin: bool) -> void:
	ci.draw_colored_polygon(poly, Color(0.82, 0.9, 0.96) * tint)
	var body := Color(0.55, 0.72, 0.85) if thin else Color(0.7, 0.84, 0.94)
	for p in Geometry2D.offset_polygon(poly, -4.0):
		ci.draw_colored_polygon(p, body * tint)
	if thin:
		for p in Geometry2D.offset_polygon(poly, -12.0):
			ci.draw_colored_polygon(p, Color(0.42, 0.6, 0.76) * tint)
		for c in _inside(poly, 10.0, 8, rng):
			var q: Vector2 = c
			for k in 4:
				var nq: Vector2 = q + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(6, 12)
				ci.draw_line(q, nq, Color(0.9, 0.96, 1.0, 0.8) * tint, 1.0)
				q = nq
	for p in _inside(poly, 10.0, 10, rng):
		ci.draw_line(p, p + Vector2(rng.randf_range(10, 22), -rng.randf_range(2, 6)), Color(1, 1, 1, 0.6) * tint, 1.5)
	if thin:
		# Warning stakes round the edge, each with a red rag.
		for ring in Geometry2D.offset_polygon(poly, 6.0):
			for i in ring.size():
				var a: Vector2 = ring[i]
				var b: Vector2 = ring[(i + 1) % ring.size()]
				var n := int(a.distance_to(b) / 40.0)
				for k in n:
					var q: Vector2 = a.lerp(b, (k + 0.5) / maxf(n, 1))
					ci.draw_rect(Rect2(q + Vector2(-1, -10), Vector2(3, 11)), OUTLINE)
					ci.draw_rect(Rect2(q + Vector2(0, -9), Vector2(1, 9)), Color(0.5, 0.36, 0.22) * tint)
					ci.draw_rect(Rect2(q + Vector2(1, -10), Vector2(4, 3)), Color(0.85, 0.2, 0.18) * tint)


## Stairs cut into the slope (the shape's bounding box, climbing up the field): stone
## treads with dark risers between.
static func _stairs(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	var box := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		box = box.expand(q)
	ci.draw_colored_polygon(poly, Color(0.5, 0.47, 0.42) * tint)
	var y := box.position.y
	var i := 0
	while y < box.end.y:
		ci.draw_rect(Rect2(box.position.x + 2, y, box.size.x - 4, 6), Color(0.72, 0.68, 0.6) * tint)
		ci.draw_rect(Rect2(box.position.x + 2, y, box.size.x - 4, 1), Color(0.84, 0.8, 0.72) * tint)
		ci.draw_rect(Rect2(box.position.x + 2, y + 6, box.size.x - 4, 3), Color(0.32, 0.29, 0.26) * tint)
		if snowy and i % 2 == 0:
			ci.draw_rect(Rect2(box.position.x + 4 + rng.randf_range(0, 6), y, rng.randf_range(8, 18), 2), Color(0.95, 0.97, 1.0) * tint)
		y += 9.0
		i += 1
	for x in [box.position.x, box.end.x - 3.0]:
		ci.draw_rect(Rect2(x, box.position.y, 3, box.size.y), Color(0.38, 0.35, 0.32) * tint)


## A rope bridge across a chasm (its bounding box, running up the field): plank slats on
## two ropes, posts at each end, sagging a little in the middle.
static func _rope_bridge(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	var box := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		box = box.expand(q)
	var y := box.position.y
	while y < box.end.y:
		var sag := sin((y - box.position.y) / box.size.y * PI) * 3.0
		var plank := Color(0.58, 0.42, 0.25) if rng.randf() < 0.7 else Color(0.48, 0.34, 0.2)
		ci.draw_rect(Rect2(box.position.x + 3 + sag * 0.3, y, box.size.x - 6, 5), OUTLINE)
		ci.draw_rect(Rect2(box.position.x + 4 + sag * 0.3, y + 0.5, box.size.x - 8, 4), plank * tint)
		y += 7.0
	for x in [box.position.x + 2.0, box.end.x - 3.0]:
		var pts := PackedVector2Array()
		for k in 9:
			var t := k / 8.0
			pts.append(Vector2(x + sin(t * PI) * 1.5, box.position.y + t * box.size.y))
		ci.draw_polyline(pts, Color(0.75, 0.62, 0.4) * tint, 2.0)
	for p in [box.position, Vector2(box.end.x - 6, box.position.y), Vector2(box.position.x, box.end.y - 8), box.end - Vector2(6, 8)]:
		ci.draw_rect(Rect2(p, Vector2(6, 8)), OUTLINE)
		ci.draw_rect(Rect2(p + Vector2(1, 1), Vector2(4, 6)), Color(0.45, 0.32, 0.2) * tint)


## Rocky mountain ground: grey-brown scree in light and dark patches, stones and the odd
## tough tuft of grass.
static func draw_mountain(ci: CanvasItem, w: float, tint: Color, y0 := TOP, y1 := 736.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5151
	ci.draw_rect(Rect2(0, y0, w, y1 - y0), Color(0.47, 0.43, 0.38) * tint)
	var y := y0
	while y < y1:
		var x := 0.0
		while x < w:
			var v := sin(x * 0.013 + 0.7) * sin(y * 0.017 + 1.1) + sin(x * 0.029 - y * 0.021) * 0.5
			if absf(v) > 0.2:
				var c := Color(0.6, 0.55, 0.48) if v > 0.0 else Color(0.32, 0.29, 0.26)
				ci.draw_rect(Rect2(x, y, 32, 32), Color(c * tint, minf(absf(v) * 0.14, 0.16)))
			x += 32.0
		y += 32.0
	for i in int(260 * w / 640.0):
		var p := Vector2(rng.randf_range(0, w), rng.randf_range(y0 + 4, y1 - 6))
		var s := rng.randf_range(1.5, 3.5)
		ci.draw_rect(Rect2(p, Vector2(s, s * 0.7)), (Color(0.62, 0.58, 0.52) if rng.randf() < 0.6 else Color(0.3, 0.27, 0.24)) * tint)
	for i in int(36 * w / 640.0):
		var p := Vector2(rng.randf_range(10, w - 10), rng.randf_range(y0 + 24, y1 - 46))
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
	if snowy:
		# Snow lying on top, thickest on the upper ledges.
		for p in Geometry2D.offset_polygon(poly, -12.0):
			ci.draw_colored_polygon(_shifted(p, Vector2(-1, -8)), Color(0.9, 0.93, 0.98) * tint)
		for p in Geometry2D.offset_polygon(poly, -20.0):
			ci.draw_colored_polygon(_shifted(p, Vector2(-3, -11)), Color(1, 1, 1) * tint)
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
		if cliff or snowy:
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
		if snowy:
			# Snow on the crown, heaped up top-left where it settles.
			ci.draw_circle(c + Vector2(-r * 0.2, -r * 0.35), r * 0.62, Color(0.9, 0.93, 0.98) * tint)
			ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.5), r * 0.32, Color(1, 1, 1) * tint)


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


## Mercy Vale's shrine (its shape's bounding box): a little whitewashed chapel in a paved
## court ringed with flowering herb beds. Four columns carry a pediment (a gold sun in
## it) before the door, arched windows glow between them, and a gold dome rises behind
## with the shrine's lamp burning on top (the one the vale's beacon is lit from). Steps
## and a path lead down, a lantern either side.
static func _shrine(ci: CanvasItem, poly: PackedVector2Array, tint: Color, rng: RandomNumberGenerator) -> void:
	var box := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		box = box.expand(q)
	var L := box.position.x
	var T := box.position.y
	var W := box.size.x
	var H := box.size.y
	var cx := box.get_center().x
	var white := Color(0.95, 0.94, 0.9) * tint
	var shade := Color(0.82, 0.8, 0.76) * tint
	var gold := Color(0.95, 0.76, 0.28) * tint
	var gold_hi := Color(1.0, 0.9, 0.55) * tint
	var warm := Color(1.0, 0.8, 0.42) * tint
	var stone := Color(0.74, 0.71, 0.64) * tint
	# The court: an octagon of pale paving, ringed by herb beds in flower (open at the
	# front, where the path runs out).
	var court := PackedVector2Array()
	var mid := Vector2(cx, T + H * 0.6)
	for i in 8:
		court.append(mid + Vector2.from_angle(PI / 8.0 + i * TAU / 8.0) * Vector2(W * 0.74, H * 0.6))
	ci.draw_colored_polygon(_shifted(court, Vector2(0, 2)), Color(0, 0, 0, 0.18))
	ci.draw_colored_polygon(court, Color(0.6, 0.57, 0.5) * tint)
	for p in Geometry2D.offset_polygon(court, -3.0):
		ci.draw_colored_polygon(p, stone)
	for i in 26:
		var q := mid + Vector2.from_angle(rng.randf() * TAU) * Vector2(W * 0.66, H * 0.52) * sqrt(rng.randf())
		ci.draw_rect(Rect2(q, Vector2(rng.randf_range(4, 8), 1)), Color(0.64, 0.61, 0.55) * tint)
	for i in 18:
		var ang := -PI / 2.0 + (i + 0.5) * TAU / 18.0
		if absf(wrapf(ang - PI / 2.0, -PI, PI)) < 0.45:
			continue   # the gap for the path
		var q := mid + Vector2.from_angle(ang) * Vector2(W * 0.82, H * 0.68)
		ci.draw_circle(q + Vector2(0, 1.5), 5.5, Color(0.16, 0.28, 0.14) * tint)
		ci.draw_circle(q, 5.0, Color(0.3, 0.5, 0.26) * tint)
		ci.draw_circle(q + Vector2(-1.5, -1.5), 2.5, Color(0.42, 0.62, 0.34) * tint)
		var bloom: Color = [Color(0.95, 0.5, 0.6), Color(1, 0.9, 0.4), Color(0.72, 0.62, 1.0), Color(1, 1, 1)][i % 4]
		ci.draw_rect(Rect2(q + Vector2(rng.randf_range(-3, 2), rng.randf_range(-3, 1)), Vector2(2, 2)), bloom)
	# The path out of the court, and the shadow the chapel throws.
	var path := Rect2(cx - 9, T + H - 2, 18, H * 0.3)
	ci.draw_rect(path, Color(0.6, 0.57, 0.5) * tint)
	ci.draw_rect(path.grow_individual(-2, 0, -2, 0), stone)
	for y in range(int(path.position.y) + 4, int(path.end.y), 6):
		ci.draw_line(Vector2(path.position.x + 2, y), Vector2(path.end.x - 2, y), Color(0.62, 0.59, 0.53) * tint, 1.0)
	ci.draw_rect(Rect2(L + 12, T + 22, W - 18, H - 22), Color(0, 0, 0, 0.2))
	# The dome on its drum, behind the portico: gold, lit from the left, the lamp on top.
	var drum := Rect2(cx - 15, T + 6, 30, 14)
	ci.draw_rect(drum.grow(1.5), OUTLINE)
	ci.draw_rect(drum, white)
	ci.draw_rect(Rect2(drum.end.x - 6, drum.position.y, 6, drum.size.y), shade)
	for x in [cx - 9.0, cx - 1.0, cx + 7.0]:
		ci.draw_rect(Rect2(x, drum.position.y + 4, 3, 7), OUTLINE)
		ci.draw_rect(Rect2(x + 0.5, drum.position.y + 4.5, 2, 6), warm)
	var dome := PackedVector2Array()
	var dome_out := PackedVector2Array()
	for i in 17:
		var ang := PI + i * PI / 16.0
		dome.append(Vector2(cx, T + 7) + Vector2(cos(ang) * 14.0, sin(ang) * 13.0))
		dome_out.append(Vector2(cx, T + 7) + Vector2(cos(ang) * 16.0, sin(ang) * 15.0))
	ci.draw_colored_polygon(dome_out, OUTLINE)
	ci.draw_colored_polygon(dome, gold)
	for i in 4:
		var ang := PI + 0.35 + i * 0.22
		ci.draw_line(Vector2(cx, T + 7) + Vector2(cos(ang), sin(ang)) * 10.0, Vector2(cx, T + 7) + Vector2(cos(ang), sin(ang)) * 12.5, gold_hi, 2.0)
	ci.draw_line(Vector2(cx, T - 6), Vector2(cx, T + 6), Color(0.85, 0.66, 0.22) * tint, 1.0)   # a rib
	ci.draw_rect(Rect2(cx - 3, T - 13, 6, 7), OUTLINE)
	ci.draw_rect(Rect2(cx - 2, T - 12, 4, 5), warm)
	ci.draw_circle(Vector2(cx, T - 10), 9.0, Color(1.0, 0.85, 0.45, 0.18))
	ci.draw_circle(Vector2(cx, T - 10), 5.0, Color(1.0, 0.9, 0.55, 0.3))
	ci.draw_rect(Rect2(cx - 4, T - 14, 8, 2), OUTLINE)
	# The walls behind the columns: whitewash over a stone footing, the right side in shade.
	var walls := Rect2(L + 8, T + 30, W - 16, H - 40)
	ci.draw_rect(walls.grow(2), OUTLINE)
	ci.draw_rect(walls, white)
	ci.draw_rect(Rect2(walls.end.x - 6, walls.position.y, 6, walls.size.y), shade)
	ci.draw_rect(Rect2(walls.position.x, walls.end.y - 5, walls.size.x, 5), Color(0.66, 0.62, 0.56) * tint)
	# Arched windows between the outer columns, lit from inside.
	for wx in [L + 15.0, L + W - 21.0]:
		ci.draw_rect(Rect2(wx - 1, walls.position.y + 9, 8, 13), OUTLINE)
		ci.draw_circle(Vector2(wx + 3, walls.position.y + 9), 4.0, OUTLINE)
		ci.draw_rect(Rect2(wx, walls.position.y + 10, 6, 11), warm)
		ci.draw_circle(Vector2(wx + 3, walls.position.y + 10), 3.0, warm)
		ci.draw_rect(Rect2(wx + 2.5, walls.position.y + 8, 1, 13), Color(0.55, 0.4, 0.25) * tint)
	# The door: arched, of dark wood, standing ajar on a warm light.
	var door := Rect2(cx - 7, walls.end.y - 21, 14, 21)
	ci.draw_rect(door.grow_individual(1, 0, 1, 0), OUTLINE)
	ci.draw_circle(Vector2(cx, door.position.y), 8.0, OUTLINE)
	ci.draw_rect(door.grow_individual(0, -1, 0, 0), Color(0.42, 0.28, 0.16) * tint)
	ci.draw_circle(Vector2(cx, door.position.y + 1), 7.0, Color(0.42, 0.28, 0.16) * tint)
	ci.draw_rect(Rect2(cx - 1, door.position.y - 4, 3, door.size.y + 4), warm)
	ci.draw_rect(Rect2(cx + 3, door.position.y + 11, 2, 2), gold)
	# The portico: four columns, an architrave with a gold band, and the pediment.
	for x in [L + 10.0, L + 23.0, L + W - 27.0, L + W - 14.0]:
		ci.draw_rect(Rect2(x - 1, T + 31, 6, H - 40), OUTLINE)
		ci.draw_rect(Rect2(x, T + 32, 4, H - 42), white)
		ci.draw_rect(Rect2(x + 3, T + 32, 1, H - 42), shade)
		ci.draw_rect(Rect2(x - 2, T + 30, 8, 3), Color(0.88, 0.86, 0.8) * tint)
		ci.draw_rect(Rect2(x - 2, T + H - 12, 8, 3), Color(0.88, 0.86, 0.8) * tint)
	var arch := Rect2(L + 4, T + 24, W - 8, 7)
	ci.draw_rect(arch.grow(1.5), OUTLINE)
	ci.draw_rect(arch, Color(0.92, 0.9, 0.84) * tint)
	ci.draw_rect(Rect2(arch.position.x, arch.position.y + 3, arch.size.x, 2), gold)
	var ped := PackedVector2Array([Vector2(L + 2, T + 24), Vector2(cx, T + 12), Vector2(L + W - 2, T + 24)])
	ci.draw_colored_polygon(PackedVector2Array([ped[0] + Vector2(-2, 1.5), ped[1] + Vector2(0, -2.5), ped[2] + Vector2(2, 1.5)]), OUTLINE)
	ci.draw_colored_polygon(ped, Color(0.93, 0.91, 0.86) * tint)
	ci.draw_line(ped[0] + Vector2(3, -1), ped[1] + Vector2(0, 2), shade, 1.0)
	ci.draw_line(ped[1] + Vector2(0, 2), ped[2] + Vector2(-3, -1), shade, 1.0)
	ci.draw_circle(Vector2(cx, T + 19), 3.5, OUTLINE)
	ci.draw_circle(Vector2(cx, T + 19), 2.5, gold)   # the sun of the Sanctuary
	for i in 8:
		var ang := i * TAU / 8.0
		ci.draw_line(Vector2(cx, T + 19) + Vector2.from_angle(ang) * 3.5, Vector2(cx, T + 19) + Vector2.from_angle(ang) * 5.0, gold, 1.0)
	# Steps down to the court, widening.
	for i in 3:
		var st := Rect2(L + 15 - i * 3, T + H - 10 + i * 3, W - 30 + i * 6, 3)
		ci.draw_rect(st.grow(0.5), Color(0.5, 0.47, 0.42) * tint)
		ci.draw_rect(st.grow_individual(0, 0, 0, -1), Color(0.86, 0.84, 0.78) * tint)
	# A lantern on a post either side of the steps.
	for x in [L - 4.0, L + W + 2.0]:
		ci.draw_rect(Rect2(x, T + H - 22, 3, 22), OUTLINE)
		ci.draw_rect(Rect2(x + 1, T + H - 21, 1, 20), Color(0.4, 0.3, 0.2) * tint)
		ci.draw_circle(Vector2(x + 1.5, T + H - 25), 8.0, Color(1.0, 0.85, 0.45, 0.16))
		ci.draw_rect(Rect2(x - 2, T + H - 29, 7, 8), OUTLINE)
		ci.draw_rect(Rect2(x - 1, T + H - 28, 5, 6), warm)
		ci.draw_rect(Rect2(x - 3, T + H - 30, 9, 2), OUTLINE)


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
static func draw_spawn(ci: CanvasItem, w: float, tint: Color, camp := true, mountain := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	if not camp:
		if mountain:
			_high_treeline(ci, w, tint, rng)
		else:
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


## Where a mountain road goes on over the top: scattered hardy pines and boulders on the
## rock, thinning out (no forest floor under them).
static func _high_treeline(ci: CanvasItem, w: float, tint: Color, rng: RandomNumberGenerator) -> void:
	var x := -6.0
	while x < w + 10.0:
		var b := Vector2(x, rng.randf_range(6, 30))
		if rng.randf() < 0.3:
			ci.draw_circle(b + Vector2(0, -3), rng.randf_range(4, 7), OUTLINE)
			ci.draw_circle(b + Vector2(-0.5, -3.5), rng.randf_range(3, 5), Color(0.52, 0.48, 0.44) * tint)
		else:
			var h := rng.randf_range(18, 30)
			ci.draw_set_transform(b + Vector2(0, 2), 0, Vector2(1, 0.4))
			ci.draw_circle(Vector2.ZERO, h * 0.32, Color(0, 0, 0, 0.22))
			ci.draw_set_transform(Vector2.ZERO)
			_pine(ci, b, h, Color(0.16, 0.3, 0.2) * tint)
		x += rng.randf_range(14, 34)


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
