extends "res://scripts/mission/objective.gd"
## The Liberation of Dawnspire's siege works: the things on an assault's fields besides
## the battering ram (rules_assault.gd runs them; this draws them and keeps their state).
##   gate          the gate in the wall across the top of a field ("style": "timber",
##                 "portcullis" or "dawn"). Shut, it's solid; only the ram breaks it (a
##                 portcullis is raised from its winch house instead). Nobody else can hurt it.
##   siege_tower   an enemy archer tower: a Skeleton Archer on top shoots your troops in
##                 reach. Stand troops round it with no enemy there and it's taken
##                 ("progress"); then it waits for a crew (an Archer, Mage or Frost Witch
##                 ordered into it), and becomes your emplacement.
##   stockade      a prison pen: freed the same way (prisoners come out: soldiers join the
##                 army, townsfolk make for safety)
##   cache         supplies: a troop that gets to it with no enemy there claims the gold
##   winch         the winch house that raises a portcullis: taken like a tower
##   standard      inside the castle (rules_castle.gd): the Line's standard, planted in each
##                 room the army takes; what the enemy goes for there. Lose it and the army
##                 breaks.
## And the ram itself: a wagon with "cargo": "ram" (a hide-roofed shed on wheels over a
## swinging iron-headed log).

const CAPTURE_R := {"siege_tower": 64.0, "stockade": 62.0, "winch": 58.0, "cache": 34.0}

var style := "timber"     # a gate's look
var gold := 0             # a cache's
var taken := false        # a tower, pen or winch house taken (a cache claimed, a gate open)
var crewed := false       # a taken tower now manned (it's an emplacement: this one's done)
var prisoners := 0        # a pen's: how many show behind the bars
var swing := 0.0          # the ram's log: 0..1 through a blow
var opening := 0.0        # a gate breaking open (or a portcullis going up): 0..1
var loosed := 0.0         # a tower's archer just loosed (its bow drawn, for a moment)
var aim := 1.0            # ...and which way it faces (1: right)


func setup(m, d: Dictionary) -> void:
	super.setup(m, d)
	style = str(d.get("style", "timber"))
	gold = int(d.get("gold", 0))
	prisoners = int(d.get("prisoners", 0))
	match kind:
		"gate":
			RADIUS = 40.0
			max_hp = float(d.get("hp", 900.0))   # (the enemy's: not scaled like your own structures)
			hp = max_hp
		"siege_tower":
			RADIUS = 22.0
		"stockade":
			RADIUS = 30.0
		"cache":
			RADIUS = 14.0
		"winch":
			RADIUS = 18.0
		"standard":
			RADIUS = 16.0
	zone_r = CAPTURE_R.get(kind, zone_r)


## Ground taken by standing on it: troops count within this of it.
func capture_r() -> float:
	return zone_r


func is_solid() -> bool:
	match kind:
		"gate":
			return not taken
		"siege_tower":
			return not taken   # (taken, a crew can be posted on it)
		"stockade":
			return true
		"cache", "winch":
			return false
		"standard":
			return true
	return super.is_solid()


## None of these is the enemy's to go for (they guard them; the ram's what they're after).
## The ram is, even at rest against a gate.
func is_target() -> bool:
	if kind in ["gate", "siege_tower", "stockade", "cache", "winch"]:
		return false
	if _is_ram():
		return not dead
	return super.is_target()


func _is_ram() -> bool:
	return kind == "wagon" and cargo == "ram"


## Only the ram breaks a gate (see batter); nothing else here can be hurt.
func take_damage(amount: float) -> void:
	if kind in ["gate", "siege_tower", "stockade", "cache", "winch"]:
		return
	if _is_ram() and arrived:
		arrived = false   # (at the gate it's still there to be hit)
		super.take_damage(amount)
		arrived = true
		return
	super.take_damage(amount)


## The ram's blow on a gate: its health down by `amount`; at nothing it bursts open.
func batter(amount: float) -> void:
	if kind != "gate" or taken:
		return
	hp = maxf(0.0, hp - amount)
	hit = 0.15
	if hp <= 0.0:
		open()


## A gate open: broken in (or a portcullis raised). The way through is clear.
func open() -> void:
	if taken:
		return
	taken = true
	hp = 0.0
	main.effects.spawn_burst(position + Vector2(0, -30), 46.0, Color(0.7, 0.55, 0.35) if style != "portcullis" else Color(0.6, 0.6, 0.65))
	main.effects.sfx("boom", 0.9)
	main.paths.invalidate()


func make_roof(layer: Node2D) -> void:
	if kind != "siege_tower":
		return
	roof_mask = RoofMask.new()
	roof = Roof.new()
	roof.obj = self
	roof_mask.add_child(roof)
	roof.material = roof_material()
	add_xray(roof)
	layer.add_child(roof_mask)
	roof_mask.position = position
	tree_exiting.connect(func(): if is_instance_valid(roof_mask): roof_mask.queue_free())


func _process(delta: float) -> void:
	super._process(delta)
	swing = maxf(0.0, swing - delta * 1.6)
	loosed = maxf(0.0, loosed - delta)
	if taken and opening < 1.0:
		opening = minf(1.0, opening + delta * (0.6 if style == "portcullis" else 2.5))
	if roof_mask != null:
		roof_mask.visible = not crewed


func _draw() -> void:
	match kind:
		"gate":
			_draw_gate()
		"siege_tower":
			if not crewed:
				_draw_ring()
				_draw_body()
		"stockade":
			_draw_ring()
			_draw_stockade()
		"cache":
			if not taken:
				_draw_ring()
				_draw_cache()
		"winch":
			_draw_ring()
			_draw_winch()
		"standard":
			if not dead:
				_draw_standard()
		_:
			if _is_ram():
				if not dead:
					_draw_body()
				return
			super._draw()


## The Line's standard: a tall pole on a heap of stones, the blue sun banner flying from it,
## and its health in a ring round its foot.
func _draw_standard() -> void:
	var foot := Vector2(0, 10)
	draw_set_transform(foot, 0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 20.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	# Stones round the foot.
	for k in 6:
		var a := k * TAU / 6.0 + 0.3
		var q := foot + Vector2(cos(a) * 11.0, sin(a) * 4.5 - 2.0)
		draw_rect(Rect2(q - Vector2(4, 3), Vector2(8, 6)), OUTLINE)
		draw_rect(Rect2(q - Vector2(3, 2), Vector2(6, 4)), Color(0.55, 0.53, 0.5) if k % 2 else Color(0.47, 0.45, 0.43))
	var top := Vector2(0, -62)
	draw_rect(Rect2(-2.5, top.y, 5, foot.y - top.y), OUTLINE)
	draw_rect(Rect2(-1.5, top.y + 1, 3, foot.y - top.y - 2), Color(0.5, 0.34, 0.18))
	draw_circle(top, 4.0, OUTLINE)
	draw_circle(top, 3.0, Color(0.95, 0.8, 0.35))
	# The banner, waving.
	var wv := sin(t * 3.0) * 2.5
	var flag := PackedVector2Array([top + Vector2(2, 4), top + Vector2(34, 6 + wv), top + Vector2(30, 19 + wv * 0.6), top + Vector2(35, 32 + wv), top + Vector2(2, 30)])
	draw_colored_polygon(flag, Color(0.2, 0.32, 0.62))
	draw_polyline(flag + PackedVector2Array([flag[0]]), OUTLINE, 1.5)
	var sun := top + Vector2(17, 18 + wv * 0.5)
	for k in 8:
		var a := k * TAU / 8.0 + t * 0.3
		draw_line(sun + Vector2.from_angle(a) * 4.0, sun + Vector2.from_angle(a) * 8.0, Color(1.0, 0.85, 0.4), 1.5)
	draw_circle(sun, 4.0, Color(1.0, 0.88, 0.45))
	if hp < max_hp:
		var k := clampf(hp / max_hp, 0.0, 1.0)
		draw_arc(foot, 24.0, -PI / 2.0, -PI / 2.0 + TAU * k, 32, Color(0.4, 0.85, 0.45) if k > 0.4 else Color(1.0, 0.4, 0.3), 3.0, true)


func _draw_body() -> void:
	if kind == "siege_tower":
		_draw_tower()
		return
	super._draw_body()


func _top() -> float:
	match kind:
		"gate":
			return -96.0
		"siege_tower":
			return -Sprites.SIZE * 3.0 * Sprites.TOWER_GROW - (Sprites.SIZE - Sprites.CREW_STAND) * 3.0 * Sprites.TOWER_GROW - 8.0
	return super._top()


## The ground it's taken on: a faint ring, filling with your colour as it's taken.
func _draw_ring() -> void:
	if taken and kind != "winch":
		return
	var col := Color(0.45, 0.75, 1.0) if not contested else Color(1, 0.6, 0.35)
	draw_circle(Vector2.ZERO, zone_r, Color(col, 0.07 + progress * 0.1), true, -1.0, true)
	draw_arc(Vector2.ZERO, zone_r, 0.0, TAU, 48, Color(col, 0.35), 2.0, true)
	if progress > 0.0 and not taken:
		draw_arc(Vector2.ZERO, zone_r - 5.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, Color(1, 0.85, 0.3, 0.9), 4.0, true)


# --- The gate --------------------------------------------------------------------------

func _draw_gate() -> void:
	var shake := Vector2(sin(t * 70.0) * 2.0, 0.0) if hit > 0.0 else Vector2.ZERO
	draw_set_transform(shake)
	match style:
		"portcullis":
			_draw_portcullis()
		"dawn":
			_draw_dawn_gate()
		_:
			_draw_timber_gate()
	draw_set_transform(Vector2.ZERO)
	if not taken and hp < max_hp and style != "portcullis":
		var w := 80.0
		draw_rect(Rect2(-w / 2.0 - 1, -112, w + 2, 7), OUTLINE)
		draw_rect(Rect2(-w / 2.0, -111, w * hp / max_hp, 5), Color(1, 0.7, 0.3))


## The arch the gate hangs in: dark inside, the stones of its ring round it.
func _arch(stone: Color, w: float, h: float) -> void:
	var r := Rect2(-w / 2.0, -h, w, h)
	draw_rect(r.grow(6.0), OUTLINE)
	draw_rect(r.grow(5.0), stone.darkened(0.15))
	draw_rect(r, Color(0.08, 0.06, 0.07))
	for i in 9:
		var a := PI + i * PI / 8.0
		var p := Vector2(0, -h + w * 0.25) + Vector2(cos(a) * (w / 2.0 + 2.0), sin(a) * w * 0.3)
		draw_rect(Rect2(p - Vector2(5, 4), Vector2(10, 8)), OUTLINE)
		draw_rect(Rect2(p - Vector2(4, 3), Vector2(8, 6)), stone.lightened(0.05) if i % 2 == 0 else stone)


func _draw_timber_gate() -> void:
	var wood := Color(0.5, 0.33, 0.18)
	var dark := Color(0.34, 0.22, 0.12)
	var iron := Color(0.32, 0.32, 0.36)
	_arch(Color(0.6, 0.57, 0.52), 80.0, 96.0)
	if taken:
		# Burst in: the two leaves hanging off their hinges, splinters on the ground.
		var o := opening
		for side in [-1.0, 1.0]:
			var x0: float = side * 40.0
			var x1: float = side * lerpf(4.0, 30.0, o)
			var poly := PackedVector2Array([Vector2(x0, -84), Vector2(x1, -70 + 14.0 * o), Vector2(x1, -2), Vector2(x0, 0)])
			draw_colored_polygon(poly, OUTLINE)
			draw_colored_polygon(Geometry2D.offset_polygon(poly, -2.0)[0], dark)
		for i in 7:
			draw_rect(Rect2(-30 + i * 9, 4 + (i * 5) % 9, 8, 3), wood)
		return
	for side in [-1.0, 1.0]:
		var r := Rect2(-38 if side < 0 else 1, -86, 37, 86)
		draw_rect(r, OUTLINE)
		draw_rect(r.grow(-2.0), wood)
		for x in range(int(r.position.x) + 7, int(r.end.x) - 2, 7):
			draw_rect(Rect2(x, r.position.y + 2, 1, r.size.y - 4), dark)
		for y in [-74, -44, -14]:
			draw_rect(Rect2(r.position.x + 1, y, r.size.x - 2, 5), OUTLINE)
			draw_rect(Rect2(r.position.x + 2, y + 1, r.size.x - 4, 3), iron)
			for x in range(int(r.position.x) + 5, int(r.end.x) - 3, 9):
				draw_rect(Rect2(x, y + 1, 2, 2), Color(0.6, 0.6, 0.62))
	draw_rect(Rect2(-6, -48, 12, 6), OUTLINE)   # the bar's hasp
	draw_rect(Rect2(-5, -47, 10, 4), iron)
	# Soot up from the foot where they've tried to burn it, his skull daubed across both
	# leaves in black and red, and arrows stuck in the planks.
	for i in 6:
		draw_rect(Rect2(-36 + i * 12, -18 - (i * 5) % 10, 10, 18 + (i * 5) % 10), Color(0.08, 0.06, 0.05, 0.35))
	draw_rect(Rect2(-13, -72, 26, 22), Color(0.07, 0.05, 0.05, 0.85))
	draw_rect(Rect2(-8, -66, 5, 5), Color(0.62, 0.12, 0.1))
	draw_rect(Rect2(3, -66, 5, 5), Color(0.62, 0.12, 0.1))
	draw_rect(Rect2(-2, -59, 4, 3), Color(0.62, 0.12, 0.1))
	for x in [-11, -6, 5, 10]:
		draw_rect(Rect2(x, -50, 2, 6), Color(0.9, 0.86, 0.78) if absf(x) > 8 else Color(0.07, 0.05, 0.05, 0.85))
	for p in [Vector2(-28, -60), Vector2(-20, -30), Vector2(24, -70), Vector2(30, -36), Vector2(16, -22)]:
		draw_line(p, p + Vector2(5, 6), Color(0.5, 0.36, 0.2), 1.5)
		draw_rect(Rect2(p + Vector2(4, 5), Vector2(3, 3)), Color(0.86, 0.84, 0.8))


func _draw_portcullis() -> void:
	var stone := Color(0.5, 0.5, 0.54)
	var iron := Color(0.26, 0.26, 0.3)
	var shine := Color(0.48, 0.48, 0.54)
	_arch(stone, 80.0, 96.0)
	var lift := opening * 90.0   # up into the gatehouse
	for x in range(-36, 40, 10):
		var top := -92.0
		var bottom := -lift
		if bottom > top:
			draw_rect(Rect2(x - 2, top, 5, bottom - top), OUTLINE)
			draw_rect(Rect2(x - 1, top, 3, bottom - top), iron)
			draw_rect(Rect2(x - 1, top, 1, bottom - top), shine)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 2, bottom), Vector2(x + 3, bottom), Vector2(x + 0.5, bottom + 6)]), iron)
	for y in range(-86, int(-lift), 16):
		draw_rect(Rect2(-38, y, 76, 4), OUTLINE)
		draw_rect(Rect2(-37, y + 1, 74, 2), iron)


func _draw_dawn_gate() -> void:
	var stone := Color(0.9, 0.86, 0.76)
	var gold_c := Color(0.95, 0.76, 0.3)
	var leaf := Color(0.62, 0.42, 0.24)
	_arch(stone, 80.0, 100.0)
	if taken:
		var o := opening
		for side in [-1.0, 1.0]:
			var x0: float = side * 40.0
			var x1: float = side * lerpf(6.0, 34.0, o)
			var poly := PackedVector2Array([Vector2(x0, -90), Vector2(x1, -78 + 10.0 * o), Vector2(x1, -2), Vector2(x0, 0)])
			draw_colored_polygon(poly, OUTLINE)
			draw_colored_polygon(Geometry2D.offset_polygon(poly, -2.0)[0], leaf.darkened(0.2))
		for i in 6:
			draw_rect(Rect2(-28 + i * 10, 5 + (i * 7) % 8, 7, 3), gold_c.darkened(0.3))
		return
	for side in [-1.0, 1.0]:
		var r := Rect2(-38 if side < 0 else 1, -92, 37, 92)
		draw_rect(r, OUTLINE)
		draw_rect(r.grow(-2.0), leaf)
		draw_rect(Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8)), OUTLINE)
		draw_rect(Rect2(r.position + Vector2(5, 5), r.size - Vector2(10, 10)), leaf.lightened(0.08))
		for y in [-80, -12]:
			draw_rect(Rect2(r.position.x + 2, y, r.size.x - 4, 3), gold_c)
	# The dawn sun across both leaves: a gold disc and its rays.
	var c := Vector2(0, -52)
	for i in 12:
		var a := i * TAU / 12.0
		draw_line(c + Vector2.from_angle(a) * 12.0, c + Vector2.from_angle(a) * (22.0 if i % 2 == 0 else 17.0), gold_c, 3.0)
	draw_circle(c, 12.0, OUTLINE)
	draw_circle(c, 10.5, gold_c)
	draw_circle(c + Vector2(-3, -3), 4.0, gold_c.lightened(0.35))


# --- An archer tower ----------------------------------------------------------------------

func _draw_tower() -> void:
	# The Archer Tower's own stone tower, sooty from the fighting, a Skeleton Archer on the
	# battlements (turned to whoever it's shooting, its bow drawn as it looses); the Ogre
	# King's rag of a banner on a pole lashed to its side, a skull on a spike and spent
	# arrows and bones round its foot. Taken: your blue banner over an empty top.
	var k := 3.0 * Sprites.TOWER_GROW
	var base_tex: Texture2D = Sprites.mount_frames("tower", "tower")[0]
	var crew_tex: Texture2D = null
	if not taken:
		crew_tex = Sprites.frames("skeleton_archer")[0]
		if loosed > 0.0:
			var drawn = Sprites.pose("skeleton_archer", "raise")
			if drawn != null:
				crew_tex = drawn
	var soot := Color(0.8, 0.74, 0.7)
	# Scorched earth and litter at its foot.
	cv.draw_set_transform(Vector2(0, 2), 0, Vector2(1.0, 0.45))
	cv.draw_circle(Vector2.ZERO, 30.0, Color(0.1, 0.08, 0.07, 0.35))
	cv.draw_set_transform(Vector2.ZERO)
	if crew_tex != null:
		Sprites.draw_mount(cv, "tower", Vector2.ZERO, Vector2.ZERO, aim, base_tex, crew_tex, soot, 1.0 + 0.02 * sin(t * 2.4), 3.0)
	else:
		cv.draw_set_transform(Vector2.ZERO, 0, Vector2(aim, 1))
		cv.draw_texture_rect(base_tex, Rect2(-Sprites.SIZE / 2.0 * k, -Sprites.SIZE * k, base_tex.get_width() * k, Sprites.SIZE * k), false, soot)
		cv.draw_set_transform(Vector2.ZERO)
	var top := -Sprites.SIZE * k
	# The banner pole lashed to its side, the rag on it torn ragged.
	var px := -Sprites.SIZE / 2.0 * k - 3.0
	cv.draw_rect(Rect2(px - 1, top - 24, 4, Sprites.SIZE * k + 22), OUTLINE)
	cv.draw_rect(Rect2(px, top - 23, 2, Sprites.SIZE * k + 20), Color(0.42, 0.28, 0.16))
	for y in [top + 14.0, top + 40.0]:
		cv.draw_rect(Rect2(px - 2, y, 6, 2), Color(0.7, 0.62, 0.45))   # its lashings
	var flag := Color(0.62, 0.12, 0.1) if not taken else Color(0.28, 0.42, 0.82)
	var flutter := floorf(sin(t * 5.0) * 1.5)
	var rag := PackedVector2Array([Vector2(px + 2, top - 22), Vector2(px + 20, top - 21 + flutter), Vector2(px + 18, top - 13 + flutter),
			Vector2(px + 21, top - 8 + flutter), Vector2(px + 13, top - 10), Vector2(px + 9, top - 4), Vector2(px + 6, top - 11), Vector2(px + 2, top - 8)])
	if taken:
		rag = PackedVector2Array([Vector2(px + 2, top - 22), Vector2(px + 20, top - 21 + flutter), Vector2(px + 20, top - 9 + flutter), Vector2(px + 2, top - 10)])
	preload("res://scripts/art/war_art.gd").outlined(cv, rag, flag)
	if not taken:
		cv.draw_rect(Rect2(px + 8, top - 19, 5, 5), Color(0.08, 0.06, 0.06))   # his daubed skull
		cv.draw_rect(Rect2(px + 9, top - 18, 1, 1), flag)
		cv.draw_rect(Rect2(px + 11, top - 18, 1, 1), flag)
	else:
		cv.draw_circle(Vector2(px + 11, top - 16), 3.0, Color(0.95, 0.78, 0.3))   # Dawnspire's sun, back up
	# A skull on a spike by its door, spent arrows and bones round its foot.
	var sx := Sprites.SIZE / 2.0 * k + 6.0
	cv.draw_line(Vector2(sx, 2), Vector2(sx, -20), OUTLINE, 3.0)
	cv.draw_line(Vector2(sx, 2), Vector2(sx, -20), Color(0.42, 0.28, 0.16), 1.0)
	cv.draw_rect(Rect2(sx - 3, -27, 6, 6), OUTLINE)
	cv.draw_rect(Rect2(sx - 2, -26, 4, 4), Color(0.88, 0.85, 0.76))
	cv.draw_rect(Rect2(sx - 2, -25, 1, 1), OUTLINE)
	cv.draw_rect(Rect2(sx + 1, -25, 1, 1), OUTLINE)
	for i in 5:
		var p := Vector2(-18 + i * 9, 6 + (i * 3) % 4)
		cv.draw_line(p, p + Vector2(4 - (i % 3) * 3, -6), Color(0.5, 0.36, 0.2), 1.0)
		cv.draw_rect(Rect2(p + Vector2(4 - (i % 3) * 3 - 1, -7), Vector2(2, 2)), Color(0.86, 0.84, 0.8))
	for i in 3:
		var p := Vector2(-10 + i * 11, 9)
		cv.draw_line(p, p + Vector2(5, 1 - i), Color(0.88, 0.85, 0.76), 1.5)
	if taken:
		var bob := floorf(sin(t * 3.0))
		cv.draw_string(ThemeDB.fallback_font, Vector2(-44, top - 34 + bob * 2.0), "Needs a crew", HORIZONTAL_ALIGNMENT_CENTER, 88, 11, Color(1, 0.95, 0.75))


# --- A prison pen -------------------------------------------------------------------------

func _draw_stockade() -> void:
	var wood := Color(0.46, 0.31, 0.18)
	var dark := Color(0.3, 0.2, 0.12)
	draw_texture_rect(Sprites.shadow(), Rect2(-RADIUS * 1.3, -2, RADIUS * 2.6, 14), false, Color(0, 0, 0, 0.3))
	# The prisoners inside (while they're there): heads and shoulders behind the stakes.
	if not taken:
		for i in mini(prisoners, 5):
			var x := -20.0 + i * 10.0
			var look: String = VILLAGERS[i % VILLAGERS.size()]
			var tex: Texture2D = Sprites.frames(look)[0]
			draw_texture_rect(tex, Rect2(x - 12, -40 + (i % 2) * 3, 24, 24), false)
	if style == "iron":
		_draw_bars()
		return
	# The stakes, sharpened, lashed with rope; the door open once they're out.
	for i in 13:
		var x := -30 + i * 5
		var door: bool = taken and i >= 5 and i <= 7
		if door:
			continue
		var h := 34 + (i * 7) % 6
		draw_rect(Rect2(x - 1, -h, 5, h), OUTLINE)
		draw_rect(Rect2(x, -h + 1, 3, h - 1), wood if i % 2 == 0 else wood.darkened(0.1))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 1, -h), Vector2(x + 4, -h), Vector2(x + 1.5, -h - 5)]), dark)
	for y in [-26, -10]:
		draw_rect(Rect2(-31, y, 66, 2), Color(0.72, 0.62, 0.42))
	if not taken:
		draw_rect(Rect2(-3, -20, 7, 7), OUTLINE)   # the lock
		draw_rect(Rect2(-2, -19, 5, 5), Color(0.55, 0.55, 0.6))


## A cell in the castle's dungeon ("style": "iron"): a stone sill, iron bars set in it, a
## barred door with a heavy lock, swung open once they're out.
func _draw_bars() -> void:
	var iron := Color(0.42, 0.42, 0.47)
	draw_rect(Rect2(-33, -3, 68, 6), OUTLINE)
	draw_rect(Rect2(-32, -2, 66, 4), Color(0.5, 0.48, 0.5))
	for i in 12:
		var x := -30 + i * 5.5
		var door: bool = taken and i >= 5 and i <= 7
		if door:
			continue
		draw_rect(Rect2(x - 1, -38, 4, 37), OUTLINE)
		draw_rect(Rect2(x, -37, 2, 35), iron if i % 2 == 0 else iron.lightened(0.12))
	for y in [-38, -22]:
		draw_rect(Rect2(-32, y - 1, 66, 4), OUTLINE)
		draw_rect(Rect2(-31, y, 64, 2), iron.lightened(0.08))
	if taken:
		# The door swung out.
		for i in 3:
			draw_rect(Rect2(4 + i * 4, -30, 2, 30), iron.darkened(0.2))
	else:
		draw_rect(Rect2(-4, -20, 9, 9), OUTLINE)   # the lock
		draw_rect(Rect2(-3, -19, 7, 7), Color(0.62, 0.5, 0.25))


# --- Supplies ------------------------------------------------------------------------------

func _draw_cache() -> void:
	draw_texture_rect(Sprites.shadow(), Rect2(-20, -2, 40, 10), false, Color(0, 0, 0, 0.3))
	if style == "chest":
		# A treasure chest (the Ogre King's plunder): iron-bound, the lid up, gold heaped in it.
		draw_rect(Rect2(-17, -18, 34, 18), OUTLINE)
		draw_rect(Rect2(-16, -17, 32, 16), Color(0.5, 0.3, 0.14))
		for x in [-12, 9]:
			draw_rect(Rect2(x, -17, 3, 16), Color(0.45, 0.45, 0.5))
		draw_rect(Rect2(-17, -30, 34, 10), OUTLINE)
		draw_rect(Rect2(-16, -29, 32, 8), Color(0.58, 0.36, 0.18))
		for k in 9:
			draw_circle(Vector2(-12 + k * 3.0, -18 - (k % 3) * 2.0), 3.0, Color(1.0, 0.82, 0.25) if k % 2 else Color(0.92, 0.7, 0.18))
		draw_rect(Rect2(-2, -10, 5, 5), Color(0.8, 0.7, 0.3))
		var bob2 := sin(t * 4.0) * 2.0
		draw_string(ThemeDB.fallback_font, Vector2(-30, -40 + bob2), "%dg" % gold, HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color(1, 0.85, 0.3))
		return
	var crate := Color(0.62, 0.45, 0.24)
	var sack := Color(0.82, 0.74, 0.55)
	for b in [Rect2(-16, -14, 13, 13), Rect2(2, -12, 12, 11), Rect2(-8, -25, 11, 11)]:
		draw_rect(b.grow(1.5), OUTLINE)
		draw_rect(b, crate)
		draw_line(b.position, b.end, crate.darkened(0.3), 1.0)
		draw_line(Vector2(b.end.x, b.position.y), Vector2(b.position.x, b.end.y), crate.darkened(0.3), 1.0)
	draw_circle(Vector2(15, -6), 6.5, OUTLINE)
	draw_circle(Vector2(15, -6), 5.0, sack)
	var bob := sin(t * 4.0) * 2.0
	draw_string(ThemeDB.fallback_font, Vector2(-30, -34 + bob), "%dg" % gold, HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color(1, 0.85, 0.3))


# --- The winch house ------------------------------------------------------------------------

func _draw_winch() -> void:
	var wood := Color(0.5, 0.34, 0.2)
	var stone := Color(0.55, 0.53, 0.5)
	draw_texture_rect(Sprites.shadow(), Rect2(-26, -2, 52, 12), false, Color(0, 0, 0, 0.3))
	# A low stone hut, a timber roof, and the great wheel beside it with its chain up to
	# the gatehouse.
	_b(-8, -12, 16, 12, OUTLINE)
	_b(-7, -11, 14, 11, stone)
	_b(-9, -16, 18, 5, OUTLINE)
	_b(-8, -15, 16, 3, wood)
	_b(-2, -7, 4, 7, OUTLINE)
	var c := Vector2(14, -16)
	var spin := -opening * TAU * 3.0 if taken else 0.0
	draw_circle(c, 13.0, OUTLINE)
	draw_circle(c, 11.0, wood)
	draw_circle(c, 7.0, OUTLINE)
	for k in 4:
		var a := spin + k * PI / 4.0
		draw_line(c - Vector2.from_angle(a) * 11.0, c + Vector2.from_angle(a) * 11.0, wood.lightened(0.15), 2.0)
	draw_circle(c, 2.5, Color(0.3, 0.3, 0.32))
	var flag := Color(0.3, 0.45, 0.85) if taken else Color(0.6, 0.12, 0.1)
	_b(-6, -26, 1, 10, OUTLINE)
	_b(-5, -26, 5, 3, flag)


# --- The battering ram --------------------------------------------------------------------

func _draw_wagon() -> void:
	if cargo != "ram":
		super._draw_wagon()
		return
	cv.draw_set_transform(Vector2(sin(t * 60.0) * 2.0 if hit > 0.0 else 0.0, 0.0))
	var hide := Color(0.55, 0.42, 0.3)
	var wood := Color(0.48, 0.32, 0.18)
	var dark := Color(0.32, 0.21, 0.12)
	var iron := Color(0.36, 0.36, 0.4)
	# Seen from behind, heading up the field: the log's iron head out in front (up), the
	# shed's hide roof over it, the wheels either side.
	var thrust := -sin(swing * PI) * 5.0
	_b(-2, -27 + thrust, 4, 12, OUTLINE)
	_b(-1, -26 + thrust, 2, 10, wood)
	_b(-3, -30 + thrust, 6, 4, OUTLINE)
	_b(-2, -29 + thrust, 4, 2, iron)
	# The shed: a ridge roof of hides stretched over a frame.
	_b(-10, -19, 20, 16, OUTLINE)
	_b(-9, -18, 18, 14, hide)
	for x in [-6, -2, 2, 6]:
		_b(x, -18, 1, 14, hide.darkened(0.18))
	_b(-1, -19, 2, 16, hide.lightened(0.15))   # the ridge
	_b(-9, -6, 18, 2, dark)
	# The wheels, each side.
	for side in [-1, 1]:
		var x: int = -13 if side < 0 else 10
		_b(x, -15, 3, 13, OUTLINE)
		_b(x + 1, -14, 1, 11, wood)
		_b(x, -10, 3, 2, iron)
	cv.draw_set_transform(Vector2.ZERO)
