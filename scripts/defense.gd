extends RefCounted
## How troops answer an enemy's warned blow (a slam hauled back, a stomp, a strafing run,
## a charge's line, a lit fuse): one shared way of deciding, set per troop by PROFILES.
##
## A troop standing where a warned blow will land notices it only after a moment (its
## reaction time: quicker for an idle Archer or a Martial Artist, slower for a Knight
## mid-swing or a Mage about to loose a spell, slower again with more coming at once or
## just after it last got out of the way). Then it picks one of three:
##   evade:    makes for the nearest good ground out of every blow coming (in its area,
##             to the side rather than back, never into enemies or burning ground), if it
##             reckons it can get there in time at its real speed; it stops fighting to
##             go, and needs a moment to settle after (its next attack waits, and it
##             can't dodge again for a while). Where it ends up when the blow lands is what
##             counts: nothing's made to miss.
##   brace:    (Knights, by default) holds its ground behind its shield: a modest cut to
##             that blow's damage and how far it's thrown, no swinging till it lands.
##   continue: takes it: it was going to miss anyway, there's no time or room, it's
##             holding its post, or it's still settling from the last dodge.
## Stunned, knocked flying, dashing, carried, up a Tower, on the castle wall, or an
## emplacement: no reaction at all (the troop's _process doesn't get this far).
##
## Development: set HTL_DEFENSE=1 in the environment to see each decision over the troop
## that made it; Defense.stats counts them (see tests/defense_test.gd).

# Per troop kind (anything not listed uses "default"):
#   react      seconds before it reacts to a blow it's standing under, doing nothing else
#   jitter     up to this much more, at random (no troop is a machine)
#   busy       its commitment (see commitment()) counts this many times over
#   brace      whether it braces when it can't (or won't) get clear
#   prefer     "evade": gets clear whenever it can; "brace": only gets clear of a heavy blow,
#              with time to spare (see SPARE), else braces
#   heavy      a blow that would take this share of its health (or more) is a heavy one
#   recover    seconds after a dodge before its next attack
#   cooldown   seconds after a dodge before it can dodge again
#   reach      how far it goes to get clear (px; further, up to FAR, if it has the time)
#   hold_reach ...on Hold Position, from its post
#   toward     how much it dislikes getting clear toward the enemy throwing the blow
#   back       ...back toward the castle (a front line that gives ground opens the way)
#   keep       ...away from whoever it's working on (its target, the ally it's healing)
const PROFILES := {
	"swordsman": {"react": 0.30, "jitter": 0.10, "busy": 1.3, "brace": true, "prefer": "brace", "heavy": 0.4,
			"recover": 0.45, "cooldown": 2.2, "reach": 70.0, "hold_reach": 36.0, "toward": 0.6, "back": 1.2, "keep": 0.4},
	"archer": {"react": 0.18, "jitter": 0.08, "busy": 1.0, "brace": false, "prefer": "evade", "heavy": 0.3,
			"recover": 0.35, "cooldown": 1.3, "reach": 90.0, "hold_reach": 50.0, "toward": 1.5, "back": 0.25, "keep": 0.6},
	"mage": {"react": 0.26, "jitter": 0.10, "busy": 1.4, "brace": false, "prefer": "evade", "heavy": 0.3,
			"recover": 0.45, "cooldown": 1.6, "reach": 80.0, "hold_reach": 44.0, "toward": 1.5, "back": 0.3, "keep": 0.6},
	"frost": {"react": 0.24, "jitter": 0.10, "busy": 1.2, "brace": false, "prefer": "evade", "heavy": 0.3,
			"recover": 0.4, "cooldown": 1.5, "reach": 60.0, "hold_reach": 40.0, "toward": 1.2, "back": 0.4, "keep": 1.2},
	"martial": {"react": 0.12, "jitter": 0.06, "busy": 0.8, "brace": false, "prefer": "evade", "heavy": 0.3,
			"recover": 0.25, "cooldown": 0.9, "reach": 60.0, "hold_reach": 40.0, "toward": 0.4, "back": 0.6, "keep": 0.8},
	"healer": {"react": 0.22, "jitter": 0.08, "busy": 1.2, "brace": false, "prefer": "evade", "heavy": 0.25,
			"recover": 0.35, "cooldown": 1.4, "reach": 80.0, "hold_reach": 44.0, "toward": 1.5, "back": 0.3, "keep": 1.0},
	"bard": {"react": 0.24, "jitter": 0.10, "busy": 1.1, "brace": false, "prefer": "evade", "heavy": 0.3,
			"recover": 0.35, "cooldown": 1.5, "reach": 70.0, "hold_reach": 44.0, "toward": 1.4, "back": 0.4, "keep": 1.0},
	"alchemist": {"react": 0.22, "jitter": 0.08, "busy": 1.1, "brace": false, "prefer": "evade", "heavy": 0.3,
			"recover": 0.4, "cooldown": 1.5, "reach": 60.0, "hold_reach": 40.0, "toward": 1.5, "back": 0.4, "keep": 0.6},
	"skeleton": {"react": 0.34, "jitter": 0.12, "busy": 1.2, "brace": false, "prefer": "evade", "heavy": 0.5,
			"recover": 0.4, "cooldown": 2.0, "reach": 50.0, "hold_reach": 30.0, "toward": 0.6, "back": 0.8, "keep": 0.3},
	"default": {"react": 0.25, "jitter": 0.10, "busy": 1.0, "brace": false, "prefer": "evade", "heavy": 0.3,
			"recover": 0.4, "cooldown": 1.5, "reach": 70.0, "hold_reach": 40.0, "toward": 1.0, "back": 0.5, "keep": 0.5},
}
const BRACE_DAMAGE := 0.25   # a braced blow does this much less (after armour, a block can still turn it)...
const BRACE_PUSH := 0.4      # ...throws it back this much as far...
const BRACE_STUN := 0.5      # ...and staggers it this much as long
const PER_THREAT := 0.10     # each more blow it's under at once: this much slower to react
const AFTER_DODGE := 0.15    # ...and this much slower again while still settling from the last dodge
const SPARE := 0.75          # a bracer gets clear only if it'd take this share of the time left, or less
const START := 0.05          # seconds it takes to get going
const MARGIN := 6.0          # how far clear of a blow's edge it aims for (px)
const STEP := 8.0            # how finely it looks for ground (px)
const DIRS := 16
const FAR := 160.0          # the furthest it ever goes to get clear (when there's the time to)

static var stats := {}       # kind -> event -> count (notice, evade, brace, take, miss, hit_evade, hit_brace, hit_take, hit_unaware, interrupt)
static var debug := OS.get_environment("HTL_DEFENSE") != ""


static func profile(w) -> Dictionary:
	return PROFILES.get(w.kind, PROFILES["default"])


static func note(w, what: String) -> void:
	var k: String = w.kind if w.clone_of == null else "martial"
	if not stats.has(k):
		stats[k] = {}
	stats[k][what] = int(stats[k].get(what, 0)) + 1


# --- The blows ---------------------------------------------------------------
# A threat (enemy.threats()): {"key", "kind", "src", "t": seconds till it lands (a line:
# till it starts along it), "dmg", "push", "stun"} and its shape: "c"+"r" (a ring),
# "o"+"dir"+"half"+"reach"+"body" (a slam's arc), or "a"+"b"+"r"+"speed" (a line swept
# from a to b).

## Whether a troop of radius `rad` standing at `p` would be caught (`pad`: that much
## further out counts too).
static func hits(th: Dictionary, p: Vector2, rad: float, pad := 0.0) -> bool:
	if th.has("c"):
		return p.distance_to(th["c"]) <= float(th["r"]) + rad + pad
	if th.has("o"):
		var off: Vector2 = p - th["o"]
		if off.length() - float(th["body"]) - rad > float(th["reach"]) + pad:
			return false
		if off.length() < 0.01:
			return true
		var spare := asin(clampf(pad / maxf(off.length(), 1.0), 0.0, 1.0))
		return absf((th["dir"] as Vector2).angle_to(off)) <= float(th["half"]) + spare
	var c := Geometry2D.get_closest_point_to_segment(p, th["a"], th["b"])
	return p.distance_to(c) <= float(th["r"]) + rad + pad


## Seconds till the blow reaches a troop at `p`: a swept line gets there later further
## along it.
static func time_to(th: Dictionary, p: Vector2) -> float:
	var t: float = th["t"]
	if th.has("a"):
		var a: Vector2 = th["a"]
		var b: Vector2 = th["b"]
		var c := Geometry2D.get_closest_point_to_segment(p, a, b)
		t += a.distance_to(c) / maxf(float(th["speed"]), 1.0)
	return t


# --- Deciding ----------------------------------------------------------------

## How tied up it is in what it's doing (seconds more before it can break off): a
## combo, a volley, a beam or Spirit Bomb being gathered, a blow about to land, an arrow
## or spell about to go, a revive under way. Walking about: nothing.
static func commitment(w) -> float:
	var c := 0.0
	if w.combo_left > 0:
		c = maxf(c, w.combo_left * w.COMBO_GAP + 0.05)
	if w.volley_left > 0:
		c = maxf(c, w.volley_left * w.COMBO_GAP)
	if w.beam_charge > 0.0:
		c = maxf(c, minf(w.beam_charge, 0.35) + 0.05)
	if w.bomb_charge > 0.0:
		c = maxf(c, minf(w.bomb_charge, 0.4) + 0.05)
	if w.offhand_timer > 0.0:
		c = maxf(c, w.offhand_timer)
	if w.swing > 0.0:
		c = maxf(c, w.swing)   # (a blow just thrown: following through)
	var t = w.target
	if t != null and is_instance_valid(t) and not t.dead:
		if w.is_melee() or w.data.get("attack", "") == "combo":
			if w.cd_timer < w.WINDUP and w._gap_to(t) <= w.attack_range + 4.0:
				c = maxf(c, w.cd_timer + (0.14 if not w.cleave.is_empty() else 0.06))   # (rearing back: a cleave's the bigger swing)
		elif w.cd_timer < 0.25 and w._gap_to(t) <= w.attack_range + 4.0:
			c = maxf(c, 0.12)   # (drawing, aiming, the spell gathering)
	if w.rez_target != null and w.rez_progress > 0.0:
		c = maxf(c, 0.25)
	return c


static func reaction_time(w, under: int) -> float:
	var p := profile(w)
	var r: float = p["react"] + commitment(w) * float(p["busy"]) + PER_THREAT * maxi(under - 1, 0)
	if w.def_cd > 0.0:
		r += AFTER_DODGE
	return r + randf() * float(p["jitter"])


## How fast it can really move just now (its upgrades, buffs, auras, slows, weather).
static func speed(w) -> float:
	var weather: float = 1.0 if w.main.gust <= 0.0 else w.main.hazards.speed_factor(w.kind)
	return w.move_speed * (1.0 + w.buff["speed"]) * w._form("speed") * w._goo_factor() * weather


## Its share of health that a blow would take (armour, defence buffs; a block's a chance,
## not counted).
static func severity(w, th: Dictionary) -> float:
	var dmg: float = float(th["dmg"]) * (1.0 - w.armor) * (1.0 - w.buff["defense"])
	return dmg / maxf(w.hp, 1.0)


## Decides about `th`, the soonest of `under` (every blow it's standing under), with
## `all` every blow coming anywhere. Returns {"act": "evade"/"brace"/"continue"/"miss",
## "to": where to (evade)}.
static func choose(w, th: Dictionary, under: Array, all: Array) -> Dictionary:
	var p := profile(w)
	if not hits(th, w.position, w.RADIUS):
		return {"act": "miss"}
	var t_left := time_to(th, w.position)
	var heavy := severity(w, th) >= float(p["heavy"])
	# A lit fuse: a melee troop's answer is to cut the Sapper down (killing it puts the bomb
	# out; bracing or backing off only lets it go off, at the wall as like as not).
	if th["kind"] == "fuse" and (w.is_melee() or w.data.get("attack", "") == "combo"):
		return {"act": "continue", "why": "cut it down"}
	# A Healer partway through a revive keeps at it unless this one would really hurt.
	if w.rez_target != null and w.rez_progress > 0.0 and not heavy:
		return {"act": "continue", "why": "reviving"}
	var spd := speed(w)
	if w.def_cd <= 0.0 and spd > 1.0:
		var spot := escape_spot(w, under, all, spd * (t_left - START))
		if spot != Vector2.INF:
			var need: float = START + w.position.distance_to(spot) / spd
			var go: bool = need <= t_left
			if p["prefer"] == "brace":
				go = heavy and need <= t_left * SPARE
			if go:
				return {"act": "evade", "to": spot}
	if p["brace"]:
		return {"act": "brace"}
	return {"act": "continue", "why": "no time" if w.def_cd <= 0.0 else "settling"}


## Somewhere close it can stand clear of every blow coming (and any burning ground):
## within its reach, in its area (by its post, on Hold Position), out of enemies' way,
## somewhere it can walk straight to; to the side rather than toward the enemy or back
## to the castle, and not leaving what it's working on. Vector2.INF: nowhere.
static func escape_spot(w, under: Array, all: Array, could := 0.0) -> Vector2:
	var p := profile(w)
	var main = w.main
	var pos: Vector2 = w.position
	var rad: float = w.RADIUS
	var hazards: Array = main.dangers()
	var reach: float = minf(maxf(float(p["reach"]), could), FAR)   # (a big ring, and time to get out of it: further)
	if could > 0.0:
		reach = minf(reach, could)   # (nowhere it couldn't get to in time)
	if w.move_mode == "hold":
		reach = minf(reach, float(p["hold_reach"]) + maxf(0.0, float(p["hold_reach"]) - pos.distance_to(w.post)))
	var src = under[0]["src"]
	var to_src := pos.direction_to(src.position) if is_instance_valid(src) and src.position != pos else Vector2.UP
	var focus := _focus(w)
	var enemies: Array = main.enemies_near(pos, reach + 60.0)
	var friends: Array = main.warriors_near(pos, reach + 30.0)
	var zoned: bool = w.zoned() and w.move_mode != "hold"
	var zone: Rect2 = w.zone_rect()
	var gap_now: float = w.rect_gap(zone, pos) if zoned else 0.0
	var lo := Vector2(rad, rad)
	var hi := Vector2(main.FIELD_W - rad, main.CASTLE_Y - rad)
	var best := Vector2.INF
	var best_cost := INF
	var turn := randf() * TAU / DIRS   # (not always the same way round)
	for i in DIRS:
		var dir := Vector2.from_angle(turn + i * TAU / DIRS)
		var s := STEP
		var q := Vector2.INF
		while s <= reach:
			var c := pos + dir * s
			if c != c.clamp(lo, hi):
				break
			if not all.any(func(o): return hits(o, c, rad, MARGIN)) and not hazards.any(func(z): return w._in_danger_zone(z, c, rad + 4.0)):
				q = c
				break
			s += STEP
		if q == Vector2.INF:
			continue
		if zoned and w.rect_gap(zone, q) > maxf(gap_now, 0.0) + 12.0:
			continue   # (out of its area)
		if enemies.any(func(e): return not e.dead and not e.flying and Geometry2D.get_closest_point_to_segment(e.position, pos, q).distance_to(e.position) < e.radius + rad * 0.6):
			continue   # (into the enemy, or through them)
		var cost := s * (1.0 + float(p["toward"]) * maxf(0.0, dir.dot(to_src)) + float(p["back"]) * maxf(0.0, dir.y))
		if focus != Vector2.INF:
			cost += float(p["keep"]) * maxf(0.0, q.distance_to(focus) - pos.distance_to(focus))
		for f in friends:
			if f != w and f.is_active() and q.distance_to(f.position) < rad * 1.6:
				cost += 10.0   # (someone's standing there)
		if cost >= best_cost:
			continue
		if main.paths.has_terrain() and (main.paths.blocked(q, rad) or not w._walkable_line(pos, q)):
			continue
		if main.paths.has_troop_walls() and main.paths.path_blocked(pos, q, rad, true):
			continue
		best_cost = cost
		best = q
	return best


## What it's working on, that getting clear shouldn't take it away from: its target (an
## Archer's, a Frost Witch's whose aura's on it), the ally a Healer's reviving, its post
## for a Healer or Bard minding the troops about it. INF: nothing in particular.
static func _focus(w) -> Vector2:
	if w.rez_target != null and is_instance_valid(w.rez_target):
		return w.rez_target.position
	if w.kind == "healer" or w.kind == "bard":
		var best := Vector2.INF
		var best_d := INF
		for f in w.main.warriors_near(w.position, 160.0):
			if f != w and f.is_active() and not f.is_emplacement():
				var d: float = f.position.distance_to(w.position)
				if d < best_d:
					best_d = d
					best = f.position
		return best if best != Vector2.INF else w.post
	if w.target != null and is_instance_valid(w.target) and not w.target.dead:
		return w.target.position
	return Vector2.INF
