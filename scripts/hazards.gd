extends Node2D
## Battlefield hazards (the North): thin ice that heavy enemies break through, and
## blizzards. main.gd keeps one of these over the ground (under the troops); with no thin
## ice on the map and no "weather" in the mission it does nothing at all.
##
## Thin ice ("thin_ice" shapes, maps.gd), by rules meant to be predictable:
##   - it holds your troops, and any enemy that isn't HEAVY, for ever;
##   - a HEAVY enemy (a Troll, the Warlord, the Ash Marshal, the Ogre King) stepping onto a
##     patch sets it cracking: cracks spread, its edge flashes red, and a countdown shows;
##   - your troops on a cracking patch drop everything and make for the nearest shore;
##   - CRACK_TIME later the whole patch gives way, whoever is on it then: enemies fall
##     through and are lost (a boss scrambles out onto the shore instead, stunned and
##     hurt); troops still on it fall through too and go down (a Healer can revive them,
##     as for any troop knocked out), dragged out onto the shore;
##   - nothing can be built on thin ice (an emplacement couldn't get off it);
##   - the patch is open water from then on: nobody can cross it, and every route
##     (enemies', your troops') is worked out afresh round it.
## Maps keep objectives, lanes and the castle reachable with every patch broken
## (tests/terrain_test.gd checks).
##
## Whiteout (the blizzard's "whiteout": true): a haze hangs over the field all the while,
## and an enemy fades into the snow the further it is from any of your troops (and any
## mover you're escorting): plain within SEE_CLEAR, faint beyond SEE_FAR, nearer still in
## a gust. Only the drawing changes; your troops fight what's in reach as ever.
##
## Blizzards (mission "weather": {"blizzard": {"first", "every", "length", "warn"}}): while
## a wave is on, a gust blows in every so often, announced WARN seconds ahead. In a gust
## everyone moves GUST_SLOW slower and ranged attacks come GUST_RATE slower (troops and
## enemies alike); the Covenant's Frost Witches and Frost Towers are at home in it: not
## slowed at all, they hit FROST_POWER harder and attack FROST_RATE faster while it blows.

const Maps = preload("res://scripts/maps.gd")
const Data = preload("res://scripts/data.gd")
const HEAVY := ["troll", "warlord", "ash_marshal", "ogre_king"]
const CRACK_TIME := 2.5
const GUST_SLOW := 0.2     # a share off everyone's speed in a gust
const GUST_RATE := 0.3     # ...and off ranged attack rates
const IMMUNE := ["frost", "frosttower"]
const FROST_POWER := 0.3   # Frost Witches and Frost Towers in a gust: this much more damage...
const FROST_RATE := 0.2    # ...and this much faster
const OUTLINE := Color(0.1, 0.07, 0.1)
const SEE_CLEAR := 150.0
const SEE_FAR := 230.0

var main
var raw := {}              # the map as given (thin ice still whole)
var ice := []              # {"i": index in raw terrain, "state": "whole"|"cracking"|"broken", "t", "by": the enemy kind that cracked it, "at": where}
var polys := []            # each patch's shape, fitted to the field's width as it is now
var fitted_w := -1.0
var blizzard := {}
var gust_in := 0.0         # seconds to the next gust (counting while a wave is on)
var gust_left := 0.0       # seconds of the gust blowing now
var warned := false        # the coming gust has been announced
const WARN := 10.0         # seconds of warning before a gust, unless the mission says otherwise
var t := 0.0
var sky := Node2D.new()    # the snow, drawn over everything


func _ready() -> void:
	sky.z_index = 40
	sky.draw.connect(_draw_sky)
	add_child(sky)


## A new battle: its map (for thin ice) and its mission (for weather).
func setup(m, map: Dictionary, mission: Dictionary) -> void:
	main = m
	raw = map.duplicate(true)
	ice.clear()
	var terr: Array = raw.get("terrain", [])
	for i in terr.size():
		if terr[i]["kind"] == "thin_ice":
			ice.append({"i": i, "state": "whole", "t": 0.0, "by": "", "at": Vector2.ZERO})
	fitted_w = -1.0
	_refit()
	_flee.clear()
	_fled.clear()
	blizzard = mission.get("weather", {}).get("blizzard", {})
	gust_in = float(blizzard.get("first", blizzard.get("every", 40.0)))
	gust_left = 0.0
	warned = false
	main.gust = 0.0
	visible = active()
	queue_redraw()


func active() -> bool:
	return not ice.is_empty() or not blizzard.is_empty()


func _refit() -> void:
	if main == null or is_equal_approx(fitted_w, main.FIELD_W):
		return
	fitted_w = main.FIELD_W
	var m: Dictionary = Maps.fitted(raw, main.FIELD_W)
	polys.clear()
	for p in ice:
		polys.append(PackedVector2Array(m["terrain"][p["i"]]["poly"]))


# --- Per frame ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if main == null or not active():
		return
	t += delta
	_refit()
	_update_ice(delta)
	_update_blizzard(delta)
	if blizzard.get("whiteout", false):
		for e in main.get_enemies():
			e.modulate.a = visibility(e.position)
	queue_redraw()
	sky.queue_redraw()


func _update_ice(delta: float) -> void:
	for n in ice.size():
		var p: Dictionary = ice[n]
		match p["state"]:
			"whole":
				for e in main.get_enemies():
					if not e.dead and not e.flying and HEAVY.has(e.kind) and Geometry2D.is_point_in_polygon(e.position, polys[n]):
						p["state"] = "cracking"
						p["t"] = CRACK_TIME
						p["by"] = e.kind
						p["at"] = e.position
						# Troops posted out on it get posts on the shore, so none heads back out.
						for w in main.get_warriors():
							if not w.is_emplacement() and Geometry2D.is_point_in_polygon(w.post, polys[n]):
								var spot := _shore(polys[n], w.position, w.RADIUS)
								_flee["%d:%d" % [n, w.get_instance_id()]] = spot
								w.set_post(spot)
						main.hud.show_message("The ice is cracking under the %s!" % Data.ENEMIES[e.kind].get("name", e.kind.capitalize()))
						main.sfx("crumble")
						break
			"cracking":
				p["t"] -= delta
				if p["t"] <= 0.0:
					_break(n)


## Patch n gives way: everyone on it is dealt with, and it's open water from now on.
func _break(n: int) -> void:
	var p: Dictionary = ice[n]
	p["state"] = "broken"
	var poly: PackedVector2Array = polys[n]
	for e in main.get_enemies():
		if e.dead or e.flying or not Geometry2D.is_point_in_polygon(e.position, poly):
			continue
		if e.boss:
			# Too big to go under: it hauls itself out onto the shore, stunned and hurt.
			e.position = _shore(poly, e.position, e.radius)
			e.take_damage(e.max_hp * 0.2)
			e.apply_stun(1.5)
		else:
			main.spawn_text(e.position + Vector2(0, -30), "Through the ice!", Color(0.7, 0.9, 1.0))
			e.take_damage(1e9)
	for w in main.get_warriors():
		if w.is_emplacement() or not Geometry2D.is_point_in_polygon(w.position, poly):
			continue
		var safe := _shore(poly, w.position, w.RADIUS)
		if w.is_active():
			# Still on it: it goes through like anything else, and is hauled out downed.
			var dodge: float = w.evade
			var guard: float = w.block
			w.evade = 0.0
			w.block = 0.0
			main.spawn_text(w.position + Vector2(0, -30), "Through the ice!", Color(0.7, 0.9, 1.0))
			w.take_damage(1e9)
			w.evade = dodge
			w.block = guard
		if is_instance_valid(w) and not w.is_queued_for_deletion():
			w.position = safe
			if Geometry2D.is_point_in_polygon(w.post, poly):
				w.set_post(safe)   # its post was out on the ice: it's on the shore now
	# The patch is water now: every route is worked out afresh round it (only what it
	# changes, so there's no hitch), and it stays water if the field is laid out again.
	raw["terrain"][p["i"]]["kind"] = "water"
	main.paths.add_terrain("water", poly)
	main.paths._map = raw
	main.warriors_changed()
	main.sfx("splash")
	main.spawn_burst(_centre(poly), 40, Color(0.75, 0.9, 1.0))
	main.hud.show_message("The ice gave way! That's open water now.")


## The nearest point on solid ground just off patch `poly` from `from`, with room for `r`.
func _shore(poly: PackedVector2Array, from: Vector2, r: float) -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var q := Geometry2D.get_closest_point_to_segment(from, a, b)
		var out := (q - _centre(poly)).normalized()
		for step in [r + 6.0, r + 18.0, r + 34.0]:
			var c: Vector2 = q + out * step
			if c.x < r or c.x > main.FIELD_W - r or c.y < main.DEPLOY_TOP or c.y > main.CASTLE_Y - r:
				continue   # off the field (it would only be pushed back onto the water)
			if Geometry2D.is_point_in_polygon(c, poly) or _gap(c, poly) < r + 2.0 or main.paths.blocked(c, r):
				continue
			var d := from.distance_to(c)
			if d < best_d:
				best_d = d
				best = c
			break
	if best == Vector2.INF:
		best = main.paths.open_spot(main._clamp_post(from + Vector2(0, 80)))
	return best


## How far `p` is from patch `poly`'s edge.
func _gap(p: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	for i in poly.size():
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])))
	return best


func _centre(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for q in poly:
		c += q
	return c / maxf(poly.size(), 1)


## Whether p is on thin ice that's still there (whole or cracking).
func on_thin_ice(p: Vector2) -> bool:
	_refit()
	for n in ice.size():
		if ice[n]["state"] != "broken" and Geometry2D.is_point_in_polygon(p, polys[n]):
			return true
	return false


## Where troop `w` should run to, standing on a patch that's cracking (Vector2.INF if it's
## safe where it is). Worked out a few times a second and kept between.
func flee_spot(w) -> Vector2:
	for n in ice.size():
		if ice[n]["state"] != "cracking":
			continue
		var key := "%d:%d" % [n, w.get_instance_id()]
		var on: bool = _gap(w.position, polys[n]) < w.RADIUS or Geometry2D.is_point_in_polygon(w.position, polys[n])
		if on and not _flee.has(key):
			_flee[key] = _shore(polys[n], w.position, w.RADIUS)
		# Once it's running it keeps going till it's there, clear of the ice.
		if _flee.has(key) and w.position.distance_to(_flee[key]) > 4.0 and (on or _fled.get(key, false) == false):
			_fled[key] = false
			return _flee[key]
		if _flee.has(key):
			_fled[key] = true
	return Vector2.INF


var _fled := {}   # "patch:troop" -> it's reached its shore spot


## Whether p is on (or at the very edge of) ice that's cracking: troops don't step there.
func cracking_at(p: Vector2, r := 0.0) -> bool:
	for n in ice.size():
		if ice[n]["state"] == "cracking" and (Geometry2D.is_point_in_polygon(p, polys[n]) or _gap(p, polys[n]) < r):
			return true
	return false


var _flee := {}   # "patch:troop" -> the shore spot it's running for


## Whether patch n is still there to walk on.
func ice_state(n: int) -> String:
	return ice[n]["state"]


func _update_blizzard(delta: float) -> void:
	if blizzard.is_empty():
		return
	if gust_left > 0.0:
		gust_left -= delta
		if gust_left <= 0.0:
			main.hud.show_message("The blizzard eases")
	elif main.wave_active:
		gust_in -= delta
		if not warned and gust_in <= float(blizzard.get("warn", WARN)):
			warned = true
			main.hud.show_message("A blizzard is coming! %ds to get ready" % ceili(gust_in))
			main.sfx("frost")
		if gust_in <= 0.0:
			warned = false
			gust_left = float(blizzard.get("length", 10.0))
			gust_in = float(blizzard.get("every", 40.0))
			main.hud.show_message("Blizzard! Everyone slowed, ranged attacks slowed; Frost Witches stronger")
	# Gust strength, easing in and out over a second.
	var target := 1.0 if gust_left > 0.0 else 0.0
	main.gust = move_toward(main.gust, target, delta)


## Seconds until a gust, while one's coming soon (else -1): the warning.
func gust_warning() -> float:
	if blizzard.is_empty() or gust_left > 0.0 or not main.wave_active:
		return -1.0
	return gust_in if gust_in <= float(blizzard.get("warn", WARN)) else -1.0


## How plainly an enemy at p can be seen in a whiteout (1: plainly; at least 0.1).
func visibility(p: Vector2) -> float:
	if not blizzard.get("whiteout", false):
		return 1.0
	var far: float = SEE_FAR - 60.0 * main.gust
	var clear: float = SEE_CLEAR - 50.0 * main.gust
	var d: float = far + 1.0
	for w in main.warriors_near(p, far):
		if w.is_active():
			d = minf(d, p.distance_to(w.position))
	for o in main.rules.objectives():
		if o.is_mover() and o.is_target():
			d = minf(d, p.distance_to(o.position))
	return clampf(1.0 - (d - clear) / maxf(far - clear, 1.0), 0.1, 1.0)


## How much a unit of `kind` is slowed by the weather now (1: not at all).
func speed_factor(kind: String) -> float:
	return 1.0 if IMMUNE.has(kind) else 1.0 - GUST_SLOW * main.gust


## ...how fast its ranged attacks come (under 1: slowed; a Frost Witch's: faster).
func rate_factor(kind: String) -> float:
	return 1.0 + FROST_RATE * main.gust if IMMUNE.has(kind) else 1.0 - GUST_RATE * main.gust


## ...and how hard it hits (a Frost Witch's or Frost Tower's: harder in a blizzard).
func power_factor(kind: String) -> float:
	return 1.0 + FROST_POWER * main.gust if IMMUNE.has(kind) else 1.0


# --- Drawing --------------------------------------------------------------------------------

## The ice as it is now (over the painted ground): cracks spreading on a patch that's
## giving way, its edge flashing, a countdown; open water where a patch has gone.
func _draw() -> void:
	for n in ice.size():
		var p: Dictionary = ice[n]
		var poly: PackedVector2Array = polys[n]
		match p["state"]:
			"cracking":
				var k: float = 1.0 - p["t"] / CRACK_TIME
				var flash := 0.45 + 0.45 * sin(t * (8.0 + 10.0 * k))
				draw_polyline(poly + PackedVector2Array([poly[0]]), Color(1.0, 0.3, 0.25, flash), 3.0, true)
				var rng := RandomNumberGenerator.new()
				rng.seed = 400 + n
				for arm in 9:
					var q: Vector2 = p["at"]
					var ang := arm * TAU / 9.0 + rng.randf_range(-0.3, 0.3)
					var steps := int(2 + k * 8.0)
					for s in steps:
						var nq: Vector2 = q + Vector2.from_angle(ang + rng.randf_range(-0.5, 0.5)) * rng.randf_range(8, 14)
						if not Geometry2D.is_point_in_polygon(nq, poly):
							break
						draw_line(q, nq, Color(0.12, 0.22, 0.35, 0.9), 2.0)
						draw_line(q + Vector2(1, 1), nq + Vector2(1, 1), Color(1, 1, 1, 0.6), 1.0)
						q = nq
				var c := _centre(poly)
				var txt := "%.1f" % maxf(p["t"], 0.0)
				draw_string_outline(ThemeDB.fallback_font, c + Vector2(-14, 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 4, OUTLINE)
				draw_string(ThemeDB.fallback_font, c + Vector2(-14, 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.45, 0.35))
			"broken":
				draw_colored_polygon(poly, Color(0.12, 0.26, 0.38))
				for q in Geometry2D.offset_polygon(poly, -8.0):
					draw_colored_polygon(q, Color(0.08, 0.2, 0.32))
				# Broken floes bobbing round the edge.
				for i in poly.size():
					var a: Vector2 = poly[i]
					var b: Vector2 = poly[(i + 1) % poly.size()]
					var m := int(a.distance_to(b) / 16.0)
					for j in m:
						var q: Vector2 = a.lerp(b, (j + 0.5) / maxf(m, 1)).lerp(_centre(poly), 0.08)
						var bob := sin(t * 2.0 + i + j) * 1.0
						draw_rect(Rect2(q + Vector2(-4, -3 + bob), Vector2(8, 5)), Color(0.85, 0.93, 1.0, 0.9))


## The blizzard over everything: a white haze, snow driving across the field, and a
## banner while it blows (and a warning just before).
func _draw_sky() -> void:
	if main == null or blizzard.is_empty():
		return
	var w: float = main.FIELD_W
	var h: float = main.FIELD_H
	var g: float = main.gust
	var coming := gust_warning()
	if coming >= 0.0:
		# The warning: the sky whitens and the first snow drifts in, more as it nears.
		g = maxf(g, 0.35 * (1.0 - coming / float(blizzard.get("warn", WARN))))
	if blizzard.get("whiteout", false):
		sky.draw_rect(Rect2(0, 0, w, h), Color(0.92, 0.95, 1.0, 0.1))   # the haze that never lifts
	if g > 0.0:
		sky.draw_rect(Rect2(0, 0, w, h), Color(0.92, 0.95, 1.0, 0.22 * g))
		var n := int(160 * g * w / 640.0)
		for i in n:
			var seed_x := fmod(i * 97.13, w)
			var x := fmod(seed_x + t * (420.0 + (i % 7) * 30.0), w + 60.0) - 30.0
			var y := fmod(i * 53.7 + t * (90.0 + (i % 5) * 20.0), h)
			sky.draw_line(Vector2(x, y), Vector2(x - 10.0, y - 3.0), Color(1, 1, 1, 0.75 * g), 1.5)
	var warn := gust_warning()
	var msg := ""
	if gust_left > 0.0:
		msg = "BLIZZARD  %ds  -  everyone slowed, ranged attacks slowed, Frost Witches stronger" % ceili(gust_left)
	elif warn >= 0.0:
		msg = "Blizzard coming in %ds" % ceili(warn)
	if msg != "":
		var font := ThemeDB.fallback_font
		var size := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		var at := Vector2((w - size.x) / 2.0, 176.0)   # (below the foe cards and the mission's status line)
		sky.draw_rect(Rect2(at - Vector2(10, 18), size + Vector2(20, 10)), Color(0.08, 0.12, 0.2, 0.75))
		sky.draw_string(font, at, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.85, 0.95, 1.0))
