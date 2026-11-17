extends Node2D
## The Arcane Spires' conduits (Phase 5, F1): rune circles set in the ground, each charged
## with one of the Mage's four arts in its colour (Storm blue, like a Storm Mage's orb;
## Arcane Lance gold, Fire red, Necromancy green). A Mage stationed on one (its post on the sigil: it keeps the
## power while it steps off to fight, but not one just passing over), or a Mage Tower built
## on one, draws on it:
##   - the conduit of its own art (the path it's furthest along) powers it up a good deal:
##     MATCH damage and rate;
##   - any other conduit still lends a little: OTHER damage;
##   - an untrained Mage (no path yet) takes the little from any of them.
## One Mage to a sigil: the one posted nearest its middle draws on it, and any other
## posted there gets nothing until it's free. The best conduit it holds counts; they
## don't add up. A conduit that's lending its power
## glows and its runes turn.
## Map data: "conduits": [{"at": Vector2 (drawn up 640 wide), "path": 0-3}].

const STATION := 34.0         # a Mage whose post is this near a sigil's middle is stationed on it
const MATCH := {"damage": 0.35, "rate": 0.25}
const OTHER := {"damage": 0.1}
const COLORS := [Color(0.38, 0.68, 1.0), Color(1.0, 0.82, 0.38), Color(1.0, 0.36, 0.22), Color(0.5, 0.95, 0.42)]
const NAMES := ["Storm", "Arcane Lance", "Fire", "Necromancy"]
const OUTLINE := Color(0.1, 0.07, 0.1)
const MAGES := ["mage", "magetower"]

var main
var spots: Array = []     # {"at": Vector2 (640 wide), "path": int, "lit": 0..1, "drawing": [[unit, give]]}
var t := 0.0


func setup(m, map: Dictionary) -> void:
	main = m
	spots.clear()
	for c in map.get("conduits", []):
		spots.append({"at": c["at"], "path": int(c["path"]), "lit": 0.0, "drawing": []})
	visible = not spots.is_empty()
	queue_redraw()


func active() -> bool:
	return not spots.is_empty()


## Where conduit c is on the field now (the field's width stretches the map).
func pos(c: Dictionary) -> Vector2:
	var at: Vector2 = c["at"]
	return Vector2(at.x * main.FIELD_W / 640.0, at.y)


## The art a Mage follows: the path it's furthest along (-1 untrained).
static func art_of(w) -> int:
	var best := -1
	var most := 0
	for p in (w.tiers as Array).size():
		if int(w.tiers[p]) > most:
			most = int(w.tiers[p])
			best = p
	return best


## What the conduits give unit w ({"damage", "rate"} shares on top of 1), or {}.
func boost(w) -> Dictionary:
	var src := source(w)
	return {} if src.is_empty() else (MATCH if int(src["path"]) == art_of(w) else OTHER)


## The conduit unit w draws on (the best one it holds), or {}.
func source(w) -> Dictionary:
	if spots.is_empty() or not MAGES.has(w.kind):
		return {}
	var art := art_of(w)
	var best := {}
	var best_d := -1.0
	for c in spots:
		if pos(c).distance_to(w.post) > STATION or holder(c) != w:
			continue
		var d: float = (MATCH if int(c["path"]) == art else OTHER)["damage"]
		if d > best_d:
			best_d = d
			best = c
	return best


## The conduit unit w is posted on (held or not), or {}.
func stationed(w) -> Dictionary:
	if spots.is_empty() or not MAGES.has(w.kind):
		return {}
	for c in spots:
		if pos(c).distance_to(w.post) <= STATION:
			return c
	return {}


## The Mage (or Mage Tower) that holds conduit c, one to a sigil: of those stationed on
## it, the one posted nearest its middle (the first posted, if two are as near), or null.
func holder(c: Dictionary):
	var p := pos(c)
	var best = null
	var best_d := INF
	for w in main.get_warriors():
		if not MAGES.has(w.kind) or not w.is_active():
			continue
		var d: float = p.distance_to(w.post)
		if d > STATION:
			continue
		if best == null or d < best_d - 0.01 or (absf(d - best_d) <= 0.01 and w.get_instance_id() < best.get_instance_id()):
			best = w
			best_d = d
	return best


## What a boost says, in a few words ("+35% dmg · +25% speed").
static func words(give: Dictionary, short := true) -> String:
	var parts := []
	if give.get("damage", 0.0) > 0.0:
		parts.append(("+%d%% dmg" if short else "+%d%% damage") % roundi(give["damage"] * 100))
	if give.get("rate", 0.0) > 0.0:
		parts.append(("+%d%% speed" if short else "+%d%% attack speed") % roundi(give["rate"] * 100))
	return " · ".join(parts) if short else ", ".join(parts)


## The conduit under p (a hover), or {}.
func at_point(p: Vector2) -> Dictionary:
	for c in spots:
		if pos(c).distance_to(p) <= 28.0:
			return c
	return {}


## A conduit's card: which art it holds, and what it gives whom.
func card_text(c: Dictionary) -> Array:
	var art: String = NAMES[int(c["path"])]
	return ["%s sigil" % art, COLORS[int(c["path"])], "Post a Mage on it",
		"%s %s Mage (its furthest path) draws %s.\nAny other Mage draws %s.\nOne Mage to a sigil; it keeps the power while it moves to fight.\nMage Towers too." % [
			"An" if art[0] in "AEIOU" else "A", art, words(MATCH, false), words(OTHER, false)]]


func _process(delta: float) -> void:
	if main == null or spots.is_empty():
		return
	t += delta
	for c in spots:
		c["drawing"] = []
	for w in main.get_warriors():
		if MAGES.has(w.kind) and w.is_active():
			var src := source(w)
			if not src.is_empty():
				src["drawing"].append([w, MATCH if int(src["path"]) == art_of(w) else OTHER])
	for c in spots:
		c["lit"] = move_toward(float(c["lit"]), 1.0 if not (c["drawing"] as Array).is_empty() else 0.0, delta * 2.5)
	queue_redraw()


## Each conduit: a ring of dark stone set in the ground, inlaid with its colour, runes
## round it that turn while it lends its power, and a glow over it then.
func _draw() -> void:
	for c in spots:
		var p := pos(c)
		var col: Color = COLORS[int(c["path"])]
		var lit: float = c["lit"]
		var pulse := 0.5 + 0.5 * sin(t * 2.0 + p.x)
		# Where to post a Mage, faintly.
		draw_arc(p, STATION, 0.0, TAU, 32, Color(col, 0.18 + 0.25 * lit), 1.5, true)
		# The stone ring and its inlay.
		draw_circle(p, 26.0, OUTLINE)
		draw_circle(p, 24.0, Color(0.22, 0.2, 0.26))
		draw_circle(p, 18.0, Color(0.14, 0.12, 0.18))
		draw_arc(p, 21.0, 0.0, TAU, 32, col.darkened(0.35 - 0.35 * lit), 3.0, true)
		# Runes round the ring.
		var turn := t * (0.9 if lit > 0.1 else 0.15)
		for i in 8:
			var a := turn + i * TAU / 8.0
			var q := p + Vector2.from_angle(a) * 21.0
			draw_rect(Rect2(q - Vector2(1.5, 1.5), Vector2(3, 3)), col.lightened(0.3) if (i % 2 == 0) else col)
		# The core: a cut gem of its colour.
		var gem := PackedVector2Array([p + Vector2(0, -9), p + Vector2(8, 0), p + Vector2(0, 9), p + Vector2(-8, 0)])
		draw_colored_polygon(gem, col.darkened(0.25 * (1.0 - lit)))
		draw_polyline(gem + PackedVector2Array([gem[0]]), OUTLINE, 1.5)
		draw_line(p + Vector2(-3, -3), p + Vector2(0, -6), Color(1, 1, 1, 0.7), 1.5)
		# A beam to each Mage it's powering: bright and broad for one of its own art (the
		# full boost), faint for any other (the little one). What it gives shows on the
		# Mage's upgrade cards (hud.gd), not here.
		for d in c["drawing"]:
			var w = d[0]
			if not is_instance_valid(w):
				continue
			var full: bool = (d[1] as Dictionary).has("rate")
			draw_line(p, w.position + Vector2(0, -14), Color(col, (0.75 if full else 0.35) * lit), 3.0 if full else 1.5, true)
		# Lending its power: a column of light and motes rising.
		if lit > 0.01:
			draw_circle(p, 34.0 + 4.0 * pulse, Color(col, 0.12 * lit))
			for i in 4:
				var k := fmod(t * 0.7 + i * 0.25, 1.0)
				var m := p + Vector2(sin(t * 2.0 + i * 1.7) * 12.0, -k * 46.0)
				draw_rect(Rect2(m, Vector2(2, 2)), Color(col.lightened(0.4), lit * (1.0 - k)))
