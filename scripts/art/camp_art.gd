extends RefCounted
## The enemy camp along the top of a campaign battlefield, dressed for the region the map
## is in (the map's castle style picks it: castle.gd STYLES). Same layout everywhere (the
## fire in the middle and the two torches where ambience.gd animates them, tents at the
## sides, war banners, the stakes along the line your troops can't be posted past); what
## changes is the ground they camp on, what stands behind them, their tents and the loot
## and wreckage lying about:
##   keep, fort   the frontier: dirt, a dark pine forest (field_art's own camp)
##   guildhall    Stonehollow: a seized quarry, gravel, a cut rock face, stacked blocks
##   guildgate    Deepdelve: dark canyon rock, a timbered mine mouth, an ore cart
##   timberhall   Greenwood: leaf litter under great broadleaf trees, felled logs, stumps
##   hospice      Mercy Vale: ploughed fields, an orchard, hay bales, a broken fence
##   frostkeep    Frostmarch: snowy pines, snow on the tents, ice
##   temple       the High Monastery: mountain rock under snowy peaks, torn prayer flags
##   cityhall     the Free Cities: cobbles, sacked townhouses, crates and barrels
##   conclave     the Arcane Spires: dark starstone over the night void, crystal shards,
##                a toppled rune obelisk

const OUTLINE := Color(0.1, 0.07, 0.1)
const TOP := 96.0


## Which camp a map gets (the open meadow, Classic's own, gets the frontier one).
static func theme(map: Dictionary) -> String:
	return String(map.get("castle", "keep"))


## The ground the camp stands on, over the field's tiles (0 to TOP). False: keep the
## frontier dirt (or the snow the biome already laid).
static func paint_ground(ci: CanvasItem, w: float, tint: Color, th: String) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 313
	match th:
		"guildhall", "temple":
			ci.draw_rect(Rect2(0, 0, w, TOP), Color(0.5, 0.47, 0.44) * tint if th == "guildhall" else Color(0.54, 0.5, 0.46) * tint)
			for i in int(w / 6.0):
				var p := Vector2(rng.randf_range(0, w), rng.randf_range(30, TOP))
				ci.draw_rect(Rect2(p, Vector2(2, 2)), Color(0.38, 0.36, 0.34) * tint if i % 2 else Color(0.62, 0.6, 0.57) * tint)
		"guildgate":
			ci.draw_rect(Rect2(0, 0, w, TOP), Color(0.34, 0.31, 0.3) * tint)
			for i in int(w / 7.0):
				var p := Vector2(rng.randf_range(0, w), rng.randf_range(30, TOP))
				ci.draw_rect(Rect2(p, Vector2(2, 2)), Color(0.25, 0.23, 0.23) * tint if i % 3 else Color(0.72, 0.55, 0.25) * tint)
		"timberhall":
			ci.draw_rect(Rect2(0, 0, w, TOP), Color(0.27, 0.27, 0.15) * tint)
			for i in int(w / 3.0):
				var p := Vector2(rng.randf_range(0, w), rng.randf_range(26, TOP))
				var c: Color = [Color(0.55, 0.36, 0.14), Color(0.42, 0.42, 0.16), Color(0.62, 0.5, 0.2), Color(0.2, 0.2, 0.1)][i % 4]
				ci.draw_rect(Rect2(p, Vector2(3, 2)), c * tint)
		"hospice":
			ci.draw_rect(Rect2(0, 0, w, TOP), Color(0.45, 0.33, 0.21) * tint)
			# Furrows of a ploughed field, stubble of the harvest, trampled where they camp.
			var y := 34.0
			while y < TOP - 4.0:
				var x := 0.0
				while x < w:
					var l := rng.randf_range(20, 60)
					ci.draw_line(Vector2(x, y + rng.randf_range(-1, 1)), Vector2(x + l, y + rng.randf_range(-1, 1)), Color(0.39, 0.28, 0.17) * tint, 1.5)
					x += l + rng.randf_range(10, 40)
				y += 9.0
			for i in int(w / 5.0):
				var p := Vector2(rng.randf_range(0, w), rng.randf_range(32, TOP))
				ci.draw_line(p, p + Vector2(rng.randf_range(-1, 1), -3), Color(0.78, 0.66, 0.36) * tint, 1.0)
		"cityhall":
			ci.draw_rect(Rect2(0, 0, w, TOP), Color(0.52, 0.48, 0.44) * tint)
			var y := 30.0
			var row := 0
			while y < TOP:
				var x := -6.0 if row % 2 else 0.0
				while x < w:
					var cw := rng.randf_range(9, 13)
					var s := rng.randf_range(-0.05, 0.05)
					ci.draw_rect(Rect2(x + 1, y + 1, cw - 2, 5), Color(0.6 + s, 0.56 + s, 0.51 + s) * tint)
					x += cw
				y += 7.0
				row += 1
		"conclave":
			ci.draw_rect(Rect2(0, 0, w, TOP), Color(0.19, 0.16, 0.26) * tint)
			# Starstone flags, cracked and dimmed where the enemy camps on them.
			var y := 34.0
			var row := 0
			while y < TOP - 2.0:
				var x := 0.0 if row % 2 == 0 else 9.0
				while x < w:
					var sw := rng.randf_range(12, 20)
					if rng.randf() > 0.18:
						var s := rng.randf_range(-0.03, 0.03)
						ci.draw_rect(Rect2(x + 1, y + 1, sw - 2, 8), Color(0.3 + s, 0.27 + s, 0.38 + s) * tint)
						ci.draw_rect(Rect2(x + 1, y + 1, sw - 2, 1), Color(0.38, 0.35, 0.48) * tint)
					x += sw
				y += 10.0
				row += 1
		_:
			return false
	return true


## Everything behind and in the camp, for a themed map (draw_spawn does the frontier one).
static func draw_camp(ci: CanvasItem, w: float, tint: Color, th: String, fire: Vector2, torches: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	_backdrop(ci, w, tint, th, rng)
	# What's lying about, under the tents.
	_litter(ci, w, tint, th, rng)
	for x in [w * 0.06, w * 0.29, w * 0.72, w * 0.94]:
		_tent(ci, Vector2(x, 62), tint, th)
	for t in torches:
		_torch_post(ci, t + Vector2(0, 8), tint, th)
	var FieldArt = load("res://scripts/art/field_art.gd")
	for x in [w * 0.4, w * 0.6]:
		FieldArt._war_banner(ci, Vector2(x, 80), tint)
	if th == "temple":
		_prayer_flags(ci, Vector2(w * 0.4 + 9, 43), Vector2(w * 0.6 - 9, 43), tint, true)
		_prayer_flags(ci, Vector2(w * 0.29 + 22, 36), Vector2(w * 0.4 - 9, 43), tint, false)
	# The fire pit.
	for i in 8:
		var s := fire + Vector2.from_angle(i * TAU / 8.0) * Vector2(11, 6)
		ci.draw_circle(s, 3.5, OUTLINE)
		var stone := Color(0.55, 0.53, 0.5)
		if th == "conclave":
			stone = Color(0.45, 0.38, 0.62)
		elif th == "frostkeep":
			stone = Color(0.7, 0.75, 0.82)
		ci.draw_circle(s, 2.5, stone * tint)
	ci.draw_line(fire + Vector2(-7, 2), fire + Vector2(7, -2), Color(0.35, 0.22, 0.12) * tint, 3.0)
	ci.draw_line(fire + Vector2(-7, -2), fire + Vector2(7, 2), Color(0.3, 0.18, 0.1) * tint, 3.0)
	# A skull on a stake by the fire.
	var sk := Vector2(w * 0.5 - 90.0, 84)
	ci.draw_line(sk, sk + Vector2(0, -22), OUTLINE, 3.0)
	ci.draw_line(sk, sk + Vector2(0, -22), Color(0.45, 0.3, 0.16) * tint, 1.5)
	ci.draw_circle(sk + Vector2(0, -26), 5.5, OUTLINE)
	ci.draw_circle(sk + Vector2(0, -26), 4.5, Color(0.9, 0.88, 0.8) * tint)
	ci.draw_rect(Rect2(sk + Vector2(-3, -28), Vector2(2, 2)), OUTLINE)
	ci.draw_rect(Rect2(sk + Vector2(1, -28), Vector2(2, 2)), OUTLINE)
	# The line your troops can't be posted past.
	_line(ci, w, tint, th)


# --- Behind the camp -----------------------------------------------------------------------

static func _backdrop(ci: CanvasItem, w: float, tint: Color, th: String, rng: RandomNumberGenerator) -> void:
	var FieldArt = load("res://scripts/art/field_art.gd")
	match th:
		"timberhall":
			# Great broadleaf trees, crowns overlapping, trunks showing under the front row.
			ci.draw_rect(Rect2(0, 0, w, 24), Color(0.04, 0.1, 0.05) * tint)
			for row in 2:
				var x := -14.0 + row * 17.0
				while x < w + 30.0:
					var r := rng.randf_range(14, 20) - row * 2.0
					var c := Vector2(x, 10.0 + row * 12.0 + rng.randf_range(-3, 3))
					if row == 1:
						ci.draw_rect(Rect2(c.x - 2, c.y + r * 0.5, 4, 10), Color(0.25, 0.17, 0.1) * tint)
					var leaf := (Color(0.1, 0.24, 0.11) if row == 0 else Color(0.15, 0.33, 0.14)) * tint
					ci.draw_circle(c, r + 1.5, OUTLINE)
					ci.draw_circle(c, r, leaf)
					ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.45, leaf.lightened(0.15))
					x += rng.randf_range(22, 30)
		"hospice":
			# A hedgerow, and an orchard behind it, the apples still on the trees.
			ci.draw_rect(Rect2(0, 0, w, 22), Color(0.2, 0.36, 0.17) * tint)
			var x := 8.0
			while x < w:
				var c := Vector2(x, 12.0 + rng.randf_range(-2, 2))
				ci.draw_rect(Rect2(c.x - 1.5, c.y + 6, 3, 10), Color(0.32, 0.22, 0.13) * tint)
				ci.draw_circle(c, 11.5, OUTLINE)
				ci.draw_circle(c, 10.0, Color(0.27, 0.48, 0.2) * tint)
				ci.draw_circle(c + Vector2(-3, -3), 5.0, Color(0.36, 0.58, 0.25) * tint)
				for k in 3:
					ci.draw_rect(Rect2(c + Vector2(rng.randf_range(-7, 6), rng.randf_range(-6, 5)), Vector2(2, 2)), Color(0.82, 0.2, 0.15) * tint)
				x += rng.randf_range(30, 42)
			for i in int(w / 9.0):
				var p := Vector2(i * 9.0 + rng.randf_range(-2, 2), 27.0 + rng.randf_range(-1, 1))
				ci.draw_circle(p, 6.5, Color(0.17, 0.3, 0.14) * tint)
				ci.draw_circle(p + Vector2(-1, -2), 3.0, Color(0.25, 0.42, 0.19) * tint)
		"frostkeep":
			ci.draw_rect(Rect2(0, 0, w, 20), Color(0.12, 0.17, 0.2) * tint)
			for row in 2:
				var x := -10.0 + row * 11.0
				while x < w + 20.0:
					var h := rng.randf_range(26, 42) - row * 6.0
					var b := Vector2(x, 22.0 + row * 9.0 + rng.randf_range(-3, 3))
					FieldArt._pine(ci, b, h, (Color(0.12, 0.22, 0.2) if row == 0 else Color(0.16, 0.3, 0.26)) * tint)
					# Snow on each tier.
					for k in 3:
						var y := b.y - k * h * 0.28 - h * 0.5 * 0.55
						var hw := h * (0.42 - k * 0.1) * 0.45
						ci.draw_colored_polygon(PackedVector2Array([Vector2(b.x - hw, y + 2), Vector2(b.x + hw, y + 2), Vector2(b.x, y - h * 0.22)]), Color(0.92, 0.95, 1.0) * tint)
					x += rng.randf_range(16, 26)
		"guildhall", "guildgate":
			# A rock face: cut square in the quarry, raw strata in the canyon.
			var base := (Color(0.46, 0.44, 0.43) if th == "guildhall" else Color(0.3, 0.28, 0.29)) * tint
			var face := PackedVector2Array([Vector2(-10, -10), Vector2(w + 10, -10)])
			var x := w + 10.0
			while x > -10.0:
				face.append(Vector2(x, 26.0 + rng.randf_range(-4, 6)))
				x -= rng.randf_range(18, 34)
			face.append(Vector2(-10, 28))
			ci.draw_colored_polygon(face, base)
			ci.draw_polyline(face.slice(2), OUTLINE, 2.0)
			for i in int(w / 14.0):
				var p := Vector2(rng.randf_range(0, w), rng.randf_range(2, 22))
				var l := rng.randf_range(12, 30)
				ci.draw_line(p, p + Vector2(l, 0), base.darkened(0.25), 2.0)
				ci.draw_line(p + Vector2(0, -2), p + Vector2(l * 0.8, -2), base.lightened(0.12), 1.0)
				if th == "guildhall" and i % 3 == 0:
					ci.draw_line(p, p + Vector2(0, 8), base.darkened(0.3), 1.5)   # where blocks were cut
			# Rubble at the foot.
			for i in int(w / 22.0):
				var p := Vector2(rng.randf_range(0, w), rng.randf_range(27, 34))
				ci.draw_circle(p, rng.randf_range(2.5, 4.5), OUTLINE)
				ci.draw_circle(p + Vector2(0, -0.5), rng.randf_range(1.5, 3.0), base.lightened(0.08))
			if th == "guildgate":
				_mine_mouth(ci, Vector2(w * 0.5 + 60.0, 34), tint)
		"temple":
			# Peaks under snow behind a dark ridge.
			ci.draw_rect(Rect2(0, 0, w, 30), Color(0.32, 0.31, 0.34) * tint)
			var x := -30.0
			while x < w + 30.0:
				var hw := rng.randf_range(26, 44)
				var hgt := rng.randf_range(22, 34)
				var foot := 32.0
				var peak := Vector2(x + rng.randf_range(-6, 6), foot - hgt)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x - hw, foot), peak, Vector2(x + hw, foot)]), Color(0.42, 0.4, 0.43) * tint)
				ci.draw_colored_polygon(PackedVector2Array([peak, Vector2(x + hw, foot), Vector2(x + hw * 0.2, foot)]), Color(0.34, 0.32, 0.36) * tint)
				ci.draw_colored_polygon(PackedVector2Array([peak + Vector2(-hw * 0.32, hgt * 0.32), peak, peak + Vector2(hw * 0.32, hgt * 0.32), peak + Vector2(0, hgt * 0.22)]), Color(0.93, 0.94, 0.97) * tint)
				ci.draw_polyline(PackedVector2Array([Vector2(x - hw, foot), peak, Vector2(x + hw, foot)]), OUTLINE, 1.5)
				x += rng.randf_range(40, 60)
			ci.draw_rect(Rect2(0, 30, w, 4), Color(0.3, 0.28, 0.3) * tint)
		"cityhall":
			# The sacked outskirts: a row of townhouses, roofs broken here and there.
			ci.draw_rect(Rect2(0, 0, w, 34), Color(0.18, 0.15, 0.14) * tint)
			var x := -8.0
			var n := 0
			while x < w:
				var hw := rng.randf_range(30, 44)
				var wall: Color = [Color(0.86, 0.8, 0.66), Color(0.8, 0.7, 0.55), Color(0.74, 0.68, 0.6)][n % 3] * tint
				var roof: Color = [Color(0.66, 0.3, 0.2), Color(0.42, 0.36, 0.48), Color(0.55, 0.38, 0.24)][(n * 2 + 1) % 3] * tint
				var top := rng.randf_range(10, 16)
				ci.draw_rect(Rect2(x, top, hw, 34 - top), OUTLINE)
				ci.draw_rect(Rect2(x + 1.5, top + 1.5, hw - 3, 34 - top - 1.5), wall)
				var burnt := n % 4 == 2
				var rp := PackedVector2Array([Vector2(x - 3, top + 2), Vector2(x + hw * 0.5, top - 12), Vector2(x + hw + 3, top + 2)])
				if burnt:
					rp = PackedVector2Array([Vector2(x - 3, top + 2), Vector2(x + hw * 0.3, top - 7), Vector2(x + hw * 0.45, top - 2), Vector2(x + hw * 0.6, top - 9), Vector2(x + hw + 3, top + 2)])
				ci.draw_colored_polygon(rp, OUTLINE)
				ci.draw_colored_polygon(Geometry2D.offset_polygon(rp, -1.5)[0] if not Geometry2D.offset_polygon(rp, -1.5).is_empty() else rp, roof.darkened(0.35) if burnt else roof)
				for k in 2:
					var wx := x + hw * (0.25 + k * 0.4)
					ci.draw_rect(Rect2(wx, top + 6, 5, 6), Color(0.12, 0.1, 0.1) if (burnt or (n + k) % 3) else Color(0.95, 0.75, 0.35) * tint)
				if burnt:
					ci.draw_rect(Rect2(x + hw * 0.5, top + 4, 6, 3), Color(0.1, 0.08, 0.08))
				x += hw + rng.randf_range(0, 3)
				n += 1
		"conclave":
			# The night void, broken arches of the old Conclave, crystal shards adrift.
			for i in 4:
				ci.draw_rect(Rect2(0, i * 8.0, w, 8.0), Color(0.06, 0.04, 0.14).lerp(Color(0.12, 0.08, 0.22), i / 3.0) * tint)
			for i in int(w / 6.0):
				var p := Vector2(rng.randf_range(0, w), rng.randf_range(0, 30))
				ci.draw_rect(Rect2(p, Vector2(1, 1)), Color(Color(0.85, 0.8, 1.0) * tint, rng.randf_range(0.4, 1.0)))
			for i in int(w / 160.0) + 1:
				var ax := rng.randf_range(40, w - 40)
				_broken_arch(ci, Vector2(ax, 34), tint, rng)
			for i in int(w / 90.0) + 2:
				var p := Vector2(rng.randf_range(0, w), rng.randf_range(16, 30))
				_shard(ci, p, rng.randf_range(0.5, 0.9), tint, rng)
			# The camp's ground ends in a lit edge of starstone.
			ci.draw_rect(Rect2(0, 32, w, 3), Color(0.42, 0.36, 0.6) * tint)
			ci.draw_rect(Rect2(0, 35, w, 1), OUTLINE)


static func _mine_mouth(ci: CanvasItem, base: Vector2, tint: Color) -> void:
	var wood := Color(0.4, 0.27, 0.14) * tint
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-16, 0), base + Vector2(-14, -24), base + Vector2(0, -30), base + Vector2(14, -24), base + Vector2(16, 0)]), OUTLINE)
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-12, 0), base + Vector2(-11, -21), base + Vector2(0, -26), base + Vector2(11, -21), base + Vector2(12, 0)]), Color(0.05, 0.04, 0.05))
	for s in [-1.0, 1.0]:
		ci.draw_rect(Rect2(base + Vector2(s * 14 - 2.5, -26), Vector2(5, 26)), OUTLINE)
		ci.draw_rect(Rect2(base + Vector2(s * 14 - 1.5, -25), Vector2(3, 25)), wood)
	ci.draw_rect(Rect2(base + Vector2(-19, -30), Vector2(38, 5)), OUTLINE)
	ci.draw_rect(Rect2(base + Vector2(-18, -29), Vector2(36, 3)), wood)
	# Rails running out of it, and a cart of ore left by them.
	for s in [-5.0, 5.0]:
		ci.draw_line(base + Vector2(s, 0), base + Vector2(s * 1.6, 20), Color(0.42, 0.42, 0.46) * tint, 1.5)
	var c := base + Vector2(-34, 14)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-10, -10), c + Vector2(10, -10), c + Vector2(8, 0), c + Vector2(-8, 0)]), OUTLINE)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-8.5, -8.5), c + Vector2(8.5, -8.5), c + Vector2(7, -1.5), c + Vector2(-7, -1.5)]), Color(0.42, 0.36, 0.3) * tint)
	for k in 4:
		ci.draw_circle(c + Vector2(-6 + k * 4, -11), 2.5, Color(0.75, 0.56, 0.22) * tint if k % 2 else Color(0.3, 0.28, 0.3) * tint)
	for s in [-5.0, 5.0]:
		ci.draw_circle(c + Vector2(s, 1), 2.5, OUTLINE)


static func _broken_arch(ci: CanvasItem, base: Vector2, tint: Color, rng: RandomNumberGenerator) -> void:
	var stone := Color(0.3, 0.26, 0.42) * tint
	var hw := rng.randf_range(14, 20)
	for s in [-1.0, 1.0]:
		var hh := 26.0 if s < 0 else rng.randf_range(10, 18)
		ci.draw_rect(Rect2(base + Vector2(s * hw - 4, -hh), Vector2(8, hh)), OUTLINE)
		ci.draw_rect(Rect2(base + Vector2(s * hw - 3, -hh + 1), Vector2(6, hh - 1)), stone)
	# Half the arch still standing over the left pillar.
	var pts := PackedVector2Array()
	for k in 6:
		var a := PI + k * PI * 0.5 / 5.0
		pts.append(base + Vector2(0, -26) + Vector2(cos(a) * hw, sin(a) * 10.0))
	ci.draw_polyline(pts, OUTLINE, 6.0)
	ci.draw_polyline(pts, stone, 4.0)
	ci.draw_circle(base + Vector2(-hw, -18), 1.5, Color(0.72, 0.55, 1.0) * tint)


static func _shard(ci: CanvasItem, at: Vector2, s: float, tint: Color, rng: RandomNumberGenerator) -> void:
	var hh := 18.0 * s
	var ww := 4.0 * s
	var tip := at + Vector2(rng.randf_range(-2, 2), -hh)
	var body := PackedVector2Array([at + Vector2(-ww, 0), tip, at + Vector2(ww, 0), at + Vector2(0, ww * 1.6)])
	ci.draw_circle(at + Vector2(0, -hh * 0.4), hh * 0.6, Color(Color(0.6, 0.4, 1.0) * tint, 0.1))
	ci.draw_colored_polygon(body, Color(0.36, 0.26, 0.62) * tint)
	ci.draw_colored_polygon(PackedVector2Array([tip, at + Vector2(ww, 0), at + Vector2(0, ww * 1.6)]), Color(0.55, 0.42, 0.9) * tint)
	ci.draw_polyline(body + PackedVector2Array([body[0]]), Color(0.08, 0.05, 0.14), 1.0)


# --- In the camp ---------------------------------------------------------------------------

## The loot and wreckage lying about (kept clear of the tents, banners and fire).
static func _litter(ci: CanvasItem, w: float, tint: Color, th: String, rng: RandomNumberGenerator) -> void:
	var spots := [w * 0.17, w * 0.83, w * 0.5 + 64.0]
	match th:
		"guildhall":
			for x in spots:
				_blocks(ci, Vector2(x + 18.0, 88), tint)
		"guildgate":
			for x in [w * 0.17, w * 0.83]:
				_blocks(ci, Vector2(x + 18.0, 88), tint * Color(0.8, 0.8, 0.85))
			_rune_stone(ci, Vector2(w * 0.35, 90), tint)
		"timberhall":
			for x in spots:
				_log(ci, Vector2(x + 18.0, 86), tint)
			for i in int(w / 70.0):
				_stump(ci, Vector2(rng.randf_range(10, w - 10), rng.randf_range(40, 52)), tint)
		"hospice":
			for x in spots:
				_hay(ci, Vector2(x + 16.0, 88), tint)
			# A broken field fence along the back of the camp.
			var x := 6.0
			while x < w:
				if rng.randf() > 0.3:
					ci.draw_rect(Rect2(x, 34, 3, 10), Color(0.48, 0.34, 0.2) * tint)
					if rng.randf() > 0.4:
						ci.draw_line(Vector2(x, 37), Vector2(x + 24, 37 + rng.randf_range(-3, 4)), Color(0.55, 0.4, 0.24) * tint, 2.0)
				x += 24.0
		"frostkeep":
			for i in int(w / 60.0):
				var p := Vector2(rng.randf_range(10, w - 10), rng.randf_range(40, 90))
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-9, 0), p + Vector2(-3, -5), p + Vector2(6, -4), p + Vector2(10, 0)]), Color(0.97, 0.98, 1.0) * tint)
			for x in spots:
				_ice_chunk(ci, Vector2(x + 18.0, 88), tint)
		"temple":
			for x in [w * 0.17, w * 0.83]:
				_stone_lantern(ci, Vector2(x + 20.0, 90), tint)
			for i in int(w / 50.0):
				var p := Vector2(rng.randf_range(10, w - 10), rng.randf_range(40, 92))
				ci.draw_circle(p, rng.randf_range(2, 3.5), Color(0.4, 0.38, 0.38) * tint)
		"cityhall":
			for x in spots:
				_crates(ci, Vector2(x + 18.0, 88), tint)
		"conclave":
			_obelisk(ci, Vector2(w * 0.35, 90), tint)
			for x in [w * 0.17 + 18.0, w * 0.83 + 18.0, w * 0.5 + 70.0]:
				for k in 3:
					_shard(ci, Vector2(x + (k - 1) * 6.0, 90 - absf(k - 1) * 2.0), 0.6 - absf(k - 1) * 0.15, tint, rng)
	# Scattered bones, everywhere they've camped.
	for i in int(w / 160.0):
		var b := Vector2(rng.randf_range(20, w - 20), rng.randf_range(40, TOP - 6))
		var d := Vector2.from_angle(rng.randf_range(0, PI)) * 4.0
		ci.draw_line(b - d, b + d, Color(0.88, 0.86, 0.78) * tint, 2.0)


static func _blocks(ci: CanvasItem, at: Vector2, tint: Color) -> void:
	var c := Color(0.66, 0.63, 0.6) * tint
	for r in [Rect2(-14, -8, 13, 8), Rect2(0, -8, 13, 8), Rect2(-7, -16, 13, 8)]:
		var q := Rect2(at + r.position, r.size)
		ci.draw_rect(q.grow(1), OUTLINE)
		ci.draw_rect(q, c)
		ci.draw_rect(Rect2(q.position, Vector2(q.size.x, 2)), c.lightened(0.15))


static func _rune_stone(ci: CanvasItem, at: Vector2, tint: Color) -> void:
	var p := PackedVector2Array([at + Vector2(-14, 0), at + Vector2(-12, -8), at + Vector2(12, -9), at + Vector2(15, 0)])
	ci.draw_colored_polygon(p, OUTLINE)
	ci.draw_colored_polygon(Geometry2D.offset_polygon(p, -1.5)[0], Color(0.32, 0.31, 0.35) * tint)
	for k in 3:
		ci.draw_rect(Rect2(at + Vector2(-7 + k * 6, -6), Vector2(2, 3)), Color(0.55, 0.42, 0.22) * tint)   # its runes gone dark


static func _log(ci: CanvasItem, at: Vector2, tint: Color) -> void:
	for k in 2:
		var p := at + Vector2(k * 4.0 - 4.0, -k * 6.0)
		ci.draw_rect(Rect2(p + Vector2(-15, -4), Vector2(30, 8)).grow(1), OUTLINE)
		ci.draw_rect(Rect2(p + Vector2(-15, -4), Vector2(30, 8)), Color(0.42, 0.28, 0.16) * tint)
		ci.draw_rect(Rect2(p + Vector2(-15, -4), Vector2(30, 2)), Color(0.5, 0.35, 0.2) * tint)
		ci.draw_circle(p + Vector2(15, 0), 4.5, OUTLINE)
		ci.draw_circle(p + Vector2(15, 0), 3.5, Color(0.78, 0.62, 0.4) * tint)


static func _stump(ci: CanvasItem, at: Vector2, tint: Color) -> void:
	ci.draw_rect(Rect2(at + Vector2(-5, -6), Vector2(10, 7)), OUTLINE)
	ci.draw_rect(Rect2(at + Vector2(-4, -5), Vector2(8, 5)), Color(0.4, 0.27, 0.15) * tint)
	ci.draw_set_transform(at + Vector2(0, -6), 0, Vector2(1, 0.45))
	ci.draw_circle(Vector2.ZERO, 6.0, OUTLINE)
	ci.draw_circle(Vector2.ZERO, 5.0, Color(0.76, 0.6, 0.38) * tint)
	ci.draw_set_transform(Vector2.ZERO)


static func _hay(ci: CanvasItem, at: Vector2, tint: Color) -> void:
	for k in 2:
		var p := at + Vector2(k * 16.0 - 8.0, 0)
		ci.draw_rect(Rect2(p + Vector2(-8, -10), Vector2(16, 10)).grow(1), OUTLINE)
		ci.draw_rect(Rect2(p + Vector2(-8, -10), Vector2(16, 10)), Color(0.85, 0.72, 0.36) * tint)
		ci.draw_line(p + Vector2(-8, -5), p + Vector2(8, -5), Color(0.62, 0.48, 0.22) * tint, 1.0)
		ci.draw_line(p + Vector2(-3, -10), p + Vector2(-3, 0), Color(0.5, 0.36, 0.2) * tint, 1.0)


static func _ice_chunk(ci: CanvasItem, at: Vector2, tint: Color) -> void:
	var p := PackedVector2Array([at + Vector2(-12, 0), at + Vector2(-9, -11), at + Vector2(-1, -16), at + Vector2(8, -9), at + Vector2(12, 0)])
	ci.draw_colored_polygon(p, OUTLINE)
	ci.draw_colored_polygon(Geometry2D.offset_polygon(p, -1.5)[0], Color(0.62, 0.8, 0.92) * tint)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-8, -10), at + Vector2(-1, -14), at + Vector2(-2, -4)]), Color(0.86, 0.95, 1.0) * tint)


static func _stone_lantern(ci: CanvasItem, at: Vector2, tint: Color) -> void:
	# A shrine's stone lantern, its light put out and its cap knocked askew.
	var c := Color(0.58, 0.55, 0.52) * tint
	for r in [Rect2(-7, -4, 14, 4), Rect2(-3, -14, 6, 10), Rect2(-6, -22, 12, 8)]:
		var q := Rect2(at + r.position, r.size)
		ci.draw_rect(q.grow(1), OUTLINE)
		ci.draw_rect(q, c)
	ci.draw_rect(Rect2(at + Vector2(-3, -20), Vector2(6, 4)), Color(0.15, 0.12, 0.12))
	var cap := PackedVector2Array([at + Vector2(-10, -21), at + Vector2(9, -25), at + Vector2(1, -31)])
	ci.draw_colored_polygon(cap, OUTLINE)
	ci.draw_colored_polygon(Geometry2D.offset_polygon(cap, -1.5)[0], c.darkened(0.15))


static func _crates(ci: CanvasItem, at: Vector2, tint: Color) -> void:
	var wood := Color(0.6, 0.42, 0.24) * tint
	for r in [Rect2(-16, -11, 11, 11), Rect2(-4, -11, 11, 11), Rect2(-10, -22, 11, 11)]:
		var q := Rect2(at + r.position, r.size)
		ci.draw_rect(q.grow(1), OUTLINE)
		ci.draw_rect(q, wood)
		ci.draw_line(q.position, q.end, wood.darkened(0.3), 1.0)
		ci.draw_line(q.position + Vector2(q.size.x, 0), q.position + Vector2(0, q.size.y), wood.darkened(0.3), 1.0)
	# A barrel beside them.
	var b := at + Vector2(14, 0)
	ci.draw_rect(Rect2(b + Vector2(-5, -12), Vector2(10, 12)).grow(1), OUTLINE)
	ci.draw_rect(Rect2(b + Vector2(-5, -12), Vector2(10, 12)), Color(0.5, 0.32, 0.18) * tint)
	for y in [-10.0, -3.0]:
		ci.draw_line(b + Vector2(-5, y), b + Vector2(5, y), Color(0.35, 0.35, 0.38) * tint, 1.5)


static func _obelisk(ci: CanvasItem, at: Vector2, tint: Color) -> void:
	# A Conclave rune obelisk, toppled and broken in two.
	var stone := Color(0.42, 0.38, 0.55) * tint
	for k in 2:
		var p := at + Vector2(k * 26.0 - 20.0, k * -2.0)
		var body := PackedVector2Array([p + Vector2(-12, 0), p + Vector2(-12, -7), p + Vector2(10, -8), p + Vector2(14, -4), p + Vector2(10, 0)])
		ci.draw_colored_polygon(body, OUTLINE)
		ci.draw_colored_polygon(Geometry2D.offset_polygon(body, -1.5)[0], stone)
		ci.draw_rect(Rect2(p + Vector2(-8, -5), Vector2(14, 1)), stone.lightened(0.15))
		ci.draw_rect(Rect2(p + Vector2(-4, -4), Vector2(2, 2)), Color(0.75, 0.6, 1.0) * tint)


static func _prayer_flags(ci: CanvasItem, a: Vector2, b: Vector2, tint: Color, torn: bool) -> void:
	ci.draw_line(a, b, Color(0.3, 0.24, 0.2) * tint, 1.0)
	var cols := [Color(0.85, 0.25, 0.2), Color(0.95, 0.75, 0.25), Color(0.3, 0.6, 0.35), Color(0.3, 0.45, 0.8), Color(0.92, 0.9, 0.85)]
	var n := int(a.distance_to(b) / 9.0)
	for i in n:
		if torn and i % 3 == 1:
			continue
		var p := a.lerp(b, (i + 0.5) / n) + Vector2(0, sin(i * 0.9) * 1.5 + 1)
		ci.draw_rect(Rect2(p + Vector2(-3, 0), Vector2(6, 6 if not (torn and i % 4 == 0) else 3)), cols[i % 5] * tint)


## Their tents: hide everywhere, with snow on them in the north, patched with stolen
## market awnings in the cities, black hide in the Spires.
static func _tent(ci: CanvasItem, base: Vector2, tint: Color, th: String) -> void:
	var hide := Color(0.55, 0.4, 0.26) * tint
	match th:
		"conclave":
			hide = Color(0.32, 0.25, 0.3) * tint
		"guildgate":
			hide = Color(0.46, 0.36, 0.26) * tint
		"frostkeep":
			hide = Color(0.6, 0.5, 0.4) * tint
	var pts := PackedVector2Array([base + Vector2(-18, 0), base + Vector2(18, 0), base + Vector2(0, -26)])
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-21, 2), base + Vector2(21, 2), base + Vector2(0, -30)]), OUTLINE)
	ci.draw_colored_polygon(pts, hide)
	ci.draw_colored_polygon(PackedVector2Array([base, base + Vector2(18, 0), base + Vector2(0, -26)]), hide.darkened(0.2))
	if th == "cityhall":
		# A looted awning thrown over one side, red and cream.
		var apex := base + Vector2(0, -26)
		for k in 4:
			var a := base + Vector2(-18 + k * 4.5, 0)
			var b := base + Vector2(-18 + (k + 1) * 4.5, 0)
			var c := Color(0.78, 0.2, 0.18) if k % 2 == 0 else Color(0.92, 0.88, 0.76)
			ci.draw_colored_polygon(PackedVector2Array([a, b, b.lerp(apex, 0.7), a.lerp(apex, 0.7)]), c * tint)
	elif th == "frostkeep":
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-9, -13), base + Vector2(0, -26), base + Vector2(9, -13), base + Vector2(4, -15), base + Vector2(0, -12), base + Vector2(-5, -15)]), Color(0.95, 0.97, 1.0) * tint)
	elif th == "conclave":
		ci.draw_line(base + Vector2(-12, -6), base + Vector2(-4, -20), Color(0.5, 0.36, 0.8) * tint, 1.0)   # a stolen Conclave sash
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-5, 0), base + Vector2(5, 0), base + Vector2(0, -12)]), Color(0.12, 0.08, 0.06))
	ci.draw_line(base + Vector2(0, -26), base + Vector2(-4, -33), OUTLINE, 2.0)
	ci.draw_line(base + Vector2(0, -26), base + Vector2(4, -33), OUTLINE, 2.0)


## A torch's post (ambience.gd lights the flame on top): a pole, or a stone brazier stand.
static func _torch_post(ci: CanvasItem, base: Vector2, tint: Color, th: String) -> void:
	if th in ["guildhall", "guildgate", "temple", "conclave"]:
		var c := (Color(0.36, 0.3, 0.46) if th == "conclave" else Color(0.48, 0.46, 0.45)) * tint
		ci.draw_rect(Rect2(base + Vector2(-5, -24), Vector2(10, 24)), OUTLINE)
		ci.draw_rect(Rect2(base + Vector2(-4, -23), Vector2(8, 22)), c)
		ci.draw_rect(Rect2(base + Vector2(-6, -30), Vector2(12, 6)), OUTLINE)
		ci.draw_rect(Rect2(base + Vector2(-5, -29), Vector2(10, 4)), c.darkened(0.2))
		return
	ci.draw_line(base, base + Vector2(0, -26), OUTLINE, 4.0)
	ci.draw_line(base, base + Vector2(0, -26), Color(0.42, 0.28, 0.14) * tint, 2.0)
	ci.draw_rect(Rect2(base + Vector2(-3, -30), Vector2(6, 5)), OUTLINE)


## The line your troops can't be posted past: sharpened stakes (snow-capped in the north,
## shards of black crystal in the Spires).
static func _line(ci: CanvasItem, w: float, tint: Color, th: String) -> void:
	var wood := Color(0.62, 0.44, 0.25) * tint
	if th == "conclave":
		wood = Color(0.38, 0.28, 0.6) * tint
	elif th in ["guildhall", "guildgate", "temple"]:
		wood = Color(0.55, 0.42, 0.28) * tint
	var sx := 12.0
	while sx < w:
		var base := Vector2(sx, TOP + 2)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-3.5, 0), base + Vector2(3.5, 0), base + Vector2(0, -15)]), OUTLINE)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-2, -1), base + Vector2(2, -1), base + Vector2(0, -12)]), wood)
		if th == "frostkeep":
			ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-1.5, -6), base + Vector2(1.5, -6), base + Vector2(0, -12)]), Color(0.95, 0.97, 1.0) * tint)
		elif th == "conclave":
			ci.draw_line(base + Vector2(0, -2), base + Vector2(0, -10), Color(0.7, 0.55, 1.0) * tint, 1.0)
		sx += 40.0
	ci.draw_line(Vector2(0, TOP - 4), Vector2(w, TOP - 4), Color(Color(0.5, 0.38, 0.22) * tint, 0.7), 1.5)
