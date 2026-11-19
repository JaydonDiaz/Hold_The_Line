extends "res://scripts/mission/rules_escort.gd"
## The Liberation of Dawnspire, outside the walls: the assault. A battering ram goes up a
## road through the fortress's outer works, one field after another (an escort's zones),
## and each field ends at a gate in the wall across its top:
##   timber      the ram batters it down while no enemy is at the ram
##   portcullis  iron: the ram can't break it. Take the winch house beside it and it's raised
##   dawn        the great gate: the ram batters it, and the walls above loose Arrow
##               Storms and Fireballs (a ring on the ground gives warning first)
## Before the gate: enemy archer towers (take them by standing troops round them with no
## enemy there; what's left is your plain Tower, for any ranged troop to climb into; a
## crew in one stays to hold it when the army moves on, and comes back into play in the
## true final battle's retreat),
## prison pens (freed the same way: the soldiers in them join you, on loan, trained up to
## tier III on one path; the townsfolk make for safety), and supplies (a troop that gets to
## them claims the gold). Once the gate's open the enemy stops sending more. The army can go
## on once the field's clear (no enemy left, nobody down: the Healers get their chance), or,
## so nothing can trap it there, LINGER seconds after the last enemy came out whatever's left:
## the order then says what happens (enemies still on the field follow the army through and
## come at it in the next field; troops still down are left behind). Going on, the player
## chooses whether the crews of the towers taken there stay to hold them (out of the army
## for good, unless the Line falls back out of the castle in the true final battle; each
## tower held keeps the road open behind the army: HELD_ROAD_GOLD in supplies in every
## field after) or climb down and come along. Then it's on through the gate into the next
## field, the army, its gold and the ram with it (the ram patched up a little). Every field after the first is a
## checkpoint (Campaign.op_state): the battle can be taken up again from the start of any
## field reached, or played from the beginning (the player's choice, from the map or after
## a loss). Once a gate's open and its field cleared, the army waits for the order to go
## on through it ("Through the gate", Y), so side objectives can be finished first. Break the last gate and clear its field to win.
##
## Mission data: "type": "assault", "assault": {
##   "ram": {"name", "speed", "hp", "patch": share mended between fields, "power": the
##     gate's health it knocks off a second},
##   "zones": [{"map", "name", "note": said on entering,
##     "gate": {"name", "style", "hp", "at"}, "winch": {"at", "time"},
##     "towers": [at, ...], "prisons": [{"at", "townsfolk": n, "soldiers": [{"kind", "path", "tier"}]}],
##     "caches": [{"at", "gold"}], "garrison": [[kind, at], ...] (out as the field opens),
##     "volleys": {"first", "every": [min, max], "kinds": ["arrows", "fire"]}}]}
## Points are as drawn up, 640 wide.

const Works = preload("res://scripts/mission/siege_works.gd")
const Warrior = preload("res://scripts/warrior.gd")
const Data = preload("res://scripts/data.gd")
# An enemy tower's archer reaches as far as a plain Archer up a plain Tower (its range, 30%
# further for the height), measured to the edge of what it shoots at, as a troop's is.
const TOWER_RANGE: float = Data.WARRIORS["archer"]["range"] * (1.0 + Warrior.PERCH_BASE)
const TOWER_COOLDOWN := 1.7
const TAKE_TIME := {"siege_tower": 8.0, "stockade": 6.0, "winch": 12.0}
const BATTER_EVERY := 1.2       # seconds between the ram's blows
const WARN := 3.5               # seconds a volley's ring is on the ground before it lands
const VOLLEYS := {
	"arrows": {"name": "Arrow Storm", "radius": 72.0, "hits": 3, "gap": 0.3, "damage": 10.0, "per_level": 1.2, "color": Color(1.0, 0.85, 0.4)},
	"fire": {"name": "Fireball", "radius": 58.0, "hits": 1, "gap": 0.0, "damage": 36.0, "per_level": 2.6, "color": Color(1.0, 0.45, 0.15)},
}

var gate                 # this field's gate
var winch = null         # ...the winch house that raises it (a portcullis)
var towers: Array = []
var pens: Array = []
var caches: Array = []
var townsfolk: Array = []    # freed prisoners on their way out
var freed := 0               # townsfolk got out, in all
var joined := 0              # soldiers freed, in all
var phase := "advance"       # "advance" (the ram on its way, or at the gate), "clear" (gate open: finish them off)
var batter_t := 0.0
var shot_t := {}             # tower -> seconds to its next arrow
var volley_t := INF          # seconds to the walls' next volley
var told_iron := false
var cp_xp := {}              # the XP the checkpoint taken up again had already earned (banked only once)
var cp_name := ""            # the field a lost battle can be taken up again from ("" before the first checkpoint)
const LINGER := 20.0         # seconds after a field's last enemy came out that the army may go on anyway
const HELD_ROAD_GOLD := 50   # supplies up the road, per tower held behind the army, in each field after
var linger := 0.0
var hold_towers := true      # going on: the crews of towers taken here stay (true) or come along
var stragglers: Array = []   # enemies left on the last field: [kind, level], to come at the army in this one


func _a() -> Dictionary:
	return mission.get("assault", {})


## The ram (an escort's wagon): its name, speed, health and mending.
func _c() -> Dictionary:
	var r: Dictionary = _a().get("ram", {}).duplicate()
	r["cargo"] = "ram"
	r["zones"] = _a().get("zones", [])
	return r


## The fields, each with everything in it (the road from its map).
func zones() -> Array:
	var out := []
	for z in _a().get("zones", []):
		var m: Dictionary = Maps.get_map(z.get("map", ""))
		var d: Dictionary = z.duplicate()
		d["name"] = z.get("name", m.get("name", ""))
		d["route"] = z.get("route", m.get("route", []))
		d["ambushes"] = []
		out.append(d)
	return out


func endless() -> bool:
	return false


func start() -> void:
	var resume: Dictionary = Campaign.checkpoint(Campaign.mission_id, Campaign.op_resume_zone) \
			if main.campaign and Campaign.op_resume_zone > 0 else {}
	Campaign.op_resume_zone = 0
	if not resume.is_empty() and int(resume.get("zone", 0)) >= 300:
		# Taken up again on the Fields of Dawn (the nine-beacon finale).
		var fin = load("res://scripts/mission/rules_finale.gd").new()
		fin.setup(main, mission)
		main.rules = fin
		fin.resume(resume)
		return
	if not resume.is_empty() and int(resume.get("zone", 0)) >= 100:
		# Taken up again inside the citadel (or getting out of it): the castle's rules take
		# the battle from there.
		var castle = load("res://scripts/mission/rules_castle.gd").new()
		castle.setup(main, mission)
		main.rules = castle
		castle.resume(resume)
		return
	if not resume.is_empty():
		zone_i = clampi(int(resume.get("zone", 0)), 0, zones().size() - 1)
		if zone_i > 0:
			change_field(zone()["map"])
	var route: Array = _entry_route(zone()["route"])
	wagon_speed = float(_c().get("speed", 18.0))
	wagon = Works.new()
	wagon.setup(main, {"id": "ram", "kind": "wagon", "name": _c().get("name", "Battering ram"), "at": route[0], "route": route.slice(1),
			"speed": wagon_speed, "hp": _c().get("hp", 1500.0), "cargo": "ram"})
	main.add_objective(wagon)
	wagon.destroyed.connect(func(_w): _end(false))
	wagon.reached.connect(_on_reached)
	_measure()
	if not resume.is_empty():
		_restore(resume)
	_setup_zone()


# --- Each field's works ---------------------------------------------------------------------

## Puts out this field's gate, towers, pens, supplies and garrison.
func _setup_zone() -> void:
	var z := zone()
	phase = "advance"
	linger = 0.0
	hold_towers = true
	told_iron = false
	towers.clear()
	pens.clear()
	caches.clear()
	shot_t.clear()
	winch = null
	var g: Dictionary = z.get("gate", {})
	gate = _work({"id": "gate", "kind": "gate", "name": g.get("name", "The gate"), "style": g.get("style", "timber"),
			"hp": g.get("hp", 900.0), "at": g.get("at", Vector2(320, 150))})
	if z.has("winch"):
		winch = _work({"id": "winch", "kind": "winch", "name": "The winch house", "at": z["winch"]["at"]})
	for at in z.get("towers", []) + (_prep("towers") if united() else []):
		var t = _work({"id": "tower", "kind": "siege_tower", "name": "Archer tower", "at": at})
		towers.append(t)
		shot_t[t] = 0.0   # (it looses at the first thing in reach, straight away)
	for p in z.get("prisons", []):
		var pen = _work({"id": "pen", "kind": "stockade", "name": "Prison pen", "at": p["at"],
				"prisoners": int(p.get("townsfolk", 0)) + (p.get("soldiers", []) as Array).size()})
		pen.set_meta("spec", p)
		pens.append(pen)
	for c in z.get("caches", []):
		caches.append(_work({"id": "cache", "kind": "cache", "name": "Supplies", "at": c["at"], "gold": c.get("gold", 60)}))
	main.paths.set_objectives(objectives())
	# The fires still burning on the field (its map's "fire" decor).
	var spots := []
	for d in Maps.fitted(Maps.get_map(z["map"]), main.FIELD_W).get("decor", []):
		if d["kind"] == "fire":
			spots.append(d["at"])
	if not spots.is_empty():
		var fires = preload("res://scripts/mission/war_fires.gd").new()
		fires.spots = spots
		main.corpse_layer.add_child(fires)
	var v: Dictionary = z.get("volleys", {})
	volley_t = float(v.get("first", 40.0)) if not v.is_empty() else INF
	var k: float = main.FIELD_W / 640.0
	for g2 in z.get("garrison", []) + (_prep("garrison") if united() else []):
		main._spawn_enemy(g2[0], main.wave_level(maxi(main.wave, 1)), Vector2(g2[1].x * k, g2[1].y))
		var e = main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)
		e.set_meta("guard", true)   # (it holds its post by the gate: see enemy_goal)
		e.goal = null
		if g2.size() > 2 and g2[2] == "guard":
			kings_guard(e)
	if z.get("note", "") != "":
		main.hud.show_message(z["note"])


## All nine beacons lit: the Ogre King has seen them, and made ready for the army (more
## towers, more of his garrison, sally parties more often: the mission's "prepared").
func united() -> bool:
	return main.campaign and Campaign.beacon_count() >= 9


## This field's share of his preparations.
func _prep(key: String) -> Array:
	var list: Array = _a().get("prepared", {}).get(key, [])
	return list[zone_i] if zone_i < list.size() else []


## One of the Ogre King's own guard: a champion of his, tougher and harder-hitting than its
## kind, named over its head.
static func kings_guard(e) -> void:
	e.set_meta("title", "King's Guard")
	e.max_hp *= 1.8
	e.hp = e.max_hp
	e.damage *= 1.25
	e.cc_mult *= 0.6
	e.bounty *= 2


func _work(d: Dictionary):
	var o = Works.new()
	o.setup(main, d)
	main.add_objective(o)
	return o


## Leaving a field: its works are left behind, and so is the crew of every tower you
## manned there: they hold it (kept in `garrisons`, to come back into play when the army
## falls back out of the castle, in the true final battle).
func _leave_zone() -> void:
	var stayed := 0
	var lost := 0
	# Troops still down are left where they fell.
	for w in main.get_warriors():
		if not w.is_queued_for_deletion() and w.down_timer > 0.0 and not w.data.get("emplacement", false):
			lost += 1
			w.queue_free()
	# Enemies still on the field follow the army through.
	stragglers.clear()
	for e in main.get_enemies():
		if not e.dead and not e.is_queued_for_deletion():
			stragglers.append([e.kind, e.level])
			e.queue_free()
	for w in main.warrior_layer.get_children():
		if w.is_queued_for_deletion() or not w.has_meta("captured"):
			continue
		var c = w.crew_in
		if hold_towers and w.is_active() and c != null and is_instance_valid(c) and c.garrison == w and c.is_active():
			_hold_tower(w, c)
			stayed += 1
			c.queue_free()
		elif c != null and is_instance_valid(c) and c.garrison == w:
			c.leave_tower()   # (a wrecked tower's crew comes along)
		w.queue_free()
	if lost > 0:
		main.hud.show_message("%d troop%s left behind where %s fell." % [lost, "" if lost == 1 else "s", "it" if lost == 1 else "they"])
	if stayed > 0:
		main.hud.show_message("%d crew%s stay%s behind to hold %s tower%s." % [stayed, "" if stayed == 1 else "s", "s" if stayed == 1 else "",
				"its" if stayed == 1 else "their", "" if stayed == 1 else "s"])
	for o in [gate, winch] + towers + pens + caches + townsfolk:
		if o != null and is_instance_valid(o):
			o.queue_free()
	townsfolk.clear()
	main.warriors_changed()


func objectives() -> Array:
	var out := []
	if wagon != null:
		out.append(wagon)
	for o in [gate, winch]:
		if o != null and is_instance_valid(o):
			out.append(o)
	out.append_array(towers.filter(func(o): return is_instance_valid(o)))
	out.append_array(pens.filter(func(o): return is_instance_valid(o)))
	out.append_array(townsfolk.filter(func(o): return is_instance_valid(o) and not o.dead and not o.arrived))
	return out


func followable() -> Array:
	return [wagon] if wagon != null and wagon.is_target() else []


# --- The ram at the gate ----------------------------------------------------------------------

func _on_reached(_w) -> void:
	pass   # at the gate: it batters it (see process), or waits for a portcullis to go up


## Whether an enemy is at the ram (it can't swing while one is).
func _ram_beset() -> bool:
	for e in main.enemies_near(wagon.position, wagon.RADIUS + 50.0):
		if not e.dead and not e.flying and wagon.position.distance_to(e.position) <= wagon.RADIUS + e.radius + 10.0:
			return true
	return false


func process(delta: float) -> void:
	if over or main.game_over or wagon == null or moving_on:
		return
	_send_side(delta)   # (troops on Side Objectives set out at once, deploying or not)
	_towers(delta)      # (an enemy tower shoots whatever comes in reach, whenever)
	if main.deploying:
		return
	if not stragglers.is_empty():
		_stragglers_come()
	if settle > 0.0:
		settle -= delta
		if settle <= 0.0:
			wagon.speed = wagon_speed
			main.hud.show_message("The %s rolls on" % wagon.label.to_lower())
		return
	_pens(delta)
	_caches()
	_winch(delta)
	_volleys(delta)
	_townsfolk()
	if phase == "advance":
		if wagon.arrived and not gate.taken:
			wagon.halted = _ram_beset()
			if gate.style == "portcullis":
				if not told_iron:
					told_iron = true
					main.hud.show_message("Iron! The ram can't break a portcullis: take the winch house and raise it.")
			elif not wagon.halted:
				batter_t -= delta
				gate.batter(float(_c().get("power", 26.0)) * delta)
				if batter_t <= 0.0:
					batter_t = BATTER_EVERY
					wagon.swing = 1.0
					main.sfx("hit", 0.9)
		if gate.taken:
			phase = "clear"
			main.spawn_text(gate.position + Vector2(0, -110), "%s is open!" % gate.label, Color(1, 0.85, 0.3))
			main.hud.show_message("%s is open! Finish off the rest of them." % gate.label)
			main.sfx("fanfare")
	if phase == "clear":
		var down := _downed()
		var where: String = "through " + gate.label.to_lower() if zone_i + 1 < zones().size() else "into the citadel"
		if main.spawn_queue.is_empty() and main.get_enemies().is_empty() and down == 0:
			# The field's clear: the army waits for the order to go on (finish what's left
			# to do here first, if you like).
			phase = "ready"
			main.hud.show_message("The way is clear. Go on %s when you're ready (%s, or Y)." % [where, action_label()])
			main.sfx("horn", 1.2)
		elif main.spawn_queue.is_empty():
			# Nothing more coming: whatever's left (out of reach, say) can't keep the army here.
			linger += delta
			if linger >= LINGER:
				phase = "ready"
				main.hud.show_message("You can go on %s now (%s, or Y), or finish here first." % [where, action_label()])
				main.sfx("horn", 1.2)


## Once the field's clear: the order to go on through the gate (or, past the last, to
## finish the assault).
func action_label() -> String:
	if phase != "ready" or over or moving_on:
		return ""
	return "Through the gate" if zone_i + 1 < zones().size() else "Into the citadel"


func action() -> void:
	if action_label() == "" or (main.hud.choice_box != null and is_instance_valid(main.hud.choice_box)):
		return
	var last := zone_i + 1 >= zones().size()
	var crews := _crews_here()
	var down := _downed()
	var foes: int = main.get_enemies().size()
	if crews == 0 and down == 0 and foes == 0:
		_go(true)
		return
	# Something's left behind: say what, and let the player choose.
	var notes := []
	if crews > 0 and not last:
		notes.append("%d tower%s taken here %s a crew. Crews who stay hold their towers: they're out of the army from now on, and each tower held keeps the road open behind you (%d gold in supplies in every field after). Or they climb down and come along. (To bring some, have the rest climb down first: L.)" % [
				crews, "" if crews == 1 else "s", "has" if crews == 1 else "have", HELD_ROAD_GOLD])
	if down > 0:
		notes.append("%d troop%s down: a Healer can still get %s up. Go on now and %s left behind." % [down, " is" if down == 1 else "s are",
				"it" if down == 1 else "them", "it's" if down == 1 else "they're"])
	if foes > 0:
		notes.append("%d enem%s still on the field: %s." % [foes, "y is" if foes == 1 else "ies are",
				"they'll be left behind" if last else ("it'll follow you through" if foes == 1 else "they'll follow you through")])
	var go_text: String = "Into the citadel" if last else "Through the gate"
	var opts := []
	if crews > 0 and not last:
		opts.append(["%s: crews hold" % go_text, func(): _go(true), "The crews stay in their towers, holding the road"])
		opts.append(["%s: crews come too" % go_text, func(): _go(false), "Every crew climbs down and goes on with the army"])
	else:
		opts.append([go_text, func(): _go(true)])
	opts.append(["Not yet", null])
	main.hud.show_choice("Go on %s?" % ("into the citadel" if last else "through " + gate.label.to_lower()), "\n\n".join(notes), opts)


## Won: the towers left manned go with the campaign, for the rest of the operation (set
## afresh by each win, never added to, so a replay can't double them).
func _end(won: bool) -> void:
	if won and not over and main.campaign:
		Campaign.held_towers = garrisons.duplicate(true)
	super._end(won)


func _go(hold: bool) -> void:
	if action_label() == "":
		return
	hold_towers = hold
	if zone_i + 1 < zones().size():
		_move_on()
	elif _a().has("castle"):
		_into_castle()
	else:
		_end(true)


## Past the last gate: on into the citadel (rules_castle.gd takes the battle on from here,
## the same operation). The ram stays at the gate; the army marches in through it.
func _into_castle() -> void:
	if over or moving_on:
		return
	moving_on = true
	var at: Vector2 = gate.position + Vector2(0, 20)
	hold_towers = true
	_leave_zone_keep_army()
	if wagon != null and is_instance_valid(wagon):
		wagon.queue_free()
	wagon = null
	var castle = load("res://scripts/mission/rules_castle.gd").new()
	castle.setup(main, mission)
	main.rules = castle
	castle.take_over(self, at)


## The field's works cleared away (towers taken here keep their crews: they hold them), the
## army left standing for its march in.
func _leave_zone_keep_army() -> void:
	for w in main.warrior_layer.get_children():
		if w.is_queued_for_deletion() or not w.has_meta("captured"):
			continue
		var c = w.crew_in
		if w.is_active() and c != null and is_instance_valid(c) and c.garrison == w and c.is_active():
			_hold_tower(w, c)
			c.queue_free()
		w.queue_free()
	for o in [gate, winch] + towers + pens + caches + townsfolk:
		if o != null and is_instance_valid(o):
			o.queue_free()
	townsfolk.clear()
	main.warriors_changed()


## Towers taken in this field that have a crew up them now.
func _crews_here() -> int:
	var n := 0
	for w in main.warrior_layer.get_children():
		if not w.is_queued_for_deletion() and w.has_meta("captured") and w.is_active() and w.crew_in != null \
				and is_instance_valid(w.crew_in) and w.crew_in.garrison == w and w.crew_in.is_active():
			n += 1
	return n


## Troops down (a Healer can still reach them).
func _downed() -> int:
	var n := 0
	for w in main.get_warriors():
		if not w.is_queued_for_deletion() and w.down_timer > 0.0:
			n += 1
	return n


## Sally parties: every few of a wave's enemies come round the walls and onto the field
## from its sides, level with the ram (so a ring round it has to face every way, not only
## up the road), once it's on its way. The rest come out of the posterns.
const SALLY_EVERY := 3       # one enemy in this many
var sallied := 0
var sally_told := -1         # the field whose sally parties have been announced

func spawn_point(r: float) -> Vector2:
	if wagon == null or phase != "advance" or zone_along() < 0.08:
		return Vector2.INF
	sallied += 1
	var every: int = int(_a().get("prepared", {}).get("sally_every", SALLY_EVERY)) if united() else SALLY_EVERY
	if sallied % every != 0:
		return Vector2.INF
	var left: bool = (sallied / every) % 2 == 0
	var y := clampf(wagon.position.y + randf_range(-90.0, 50.0), 230.0, main.CASTLE_Y - 40.0)
	var p := Vector2(r + 6.0 if left else main.FIELD_W - r - 6.0, y)
	p = main.paths.open_spot(p)
	if sally_told != zone_i:
		sally_told = zone_i
		main.hud.show_message("They're coming round the walls: watch the ram's flanks!")
	return p


# --- Troops sent after the side objectives (the "side" target priority) -------------------------

func side_objectives() -> bool:
	return true


var side_t := 0.0


## The side objectives still to be done in this field: ground to take (towers, pens, the
## winch house, supplies), and towers taken that want a crew.
func _side_jobs() -> Array:
	var out := []
	for o in towers + pens + caches + ([winch] if winch != null else []):
		if is_instance_valid(o) and not o.taken:
			out.append(o)
	return out


## Every half second: each troop on Side Objectives goes to a job (the nearest, the work
## shared out so they don't all pile onto one), a ranged troop up into a tower that's been
## taken; with nothing left to do, back round the ram.
func _send_side(delta: float) -> void:
	side_t -= delta
	if side_t > 0.0:
		return
	side_t = 0.5
	var crews := _empty_captured()
	var jobs := _side_jobs()
	var busy := {}
	var troops: Array = main.get_warriors().filter(_on_side_duty)
	# Those already on a job that's still open keep it.
	for w in troops:
		var j = (w.get_meta("side_job") if w.has_meta("side_job") else null)
		if j != null and is_instance_valid(j) and ((jobs.has(j)) or (crews.has(j) and Warrior.GARRISON_KINDS.has(w.kind))):
			busy[j] = busy.get(j, 0) + 1
	for w in troops:
		var j = (w.get_meta("side_job") if w.has_meta("side_job") else null)
		if j != null and is_instance_valid(j) and (jobs.has(j) or (crews.has(j) and Warrior.GARRISON_KINDS.has(w.kind))):
			continue
		var best = null
		var best_cost := INF
		var pool: Array = (crews if Warrior.GARRISON_KINDS.has(w.kind) else []) + jobs
		for o in pool:
			if crews.has(o) and busy.get(o, 0) > 0:
				continue   # (one crew to a tower)
			var cost: float = w.position.distance_to(o.position) + 160.0 * busy.get(o, 0)
			if cost < best_cost:
				best_cost = cost
				best = o
		if best == null:
			if w.has_meta("side_job"):
				w.remove_meta("side_job")
			if w.anchor != wagon and wagon != null:
				_follow_ram(w)
			continue
		var n: int = busy.get(best, 0)
		busy[best] = n + 1
		w.set_meta("side_job", best)
		w.anchor = null
		var spot: Vector2 = best.position
		if not crews.has(best):
			var r: float = best.capture_r() * (0.25 if best.kind == "cache" else 0.6)
			spot = main.paths.open_spot(main._clamp_post(best.position + Vector2.from_angle(PI * 0.5 + n * 1.3) * r))
		w.order_to(spot)


## A troop on Side Objectives that's free to go (up, not an emplacement, not carried).
func _on_side_duty(w) -> bool:
	return w.is_active() and w.priority == Warrior.SIDE_PRIORITY and not w.is_emplacement() and not w.wall_guard \
			and not w.summoned and w.clone_of == null and not w.held


## Back to guarding the ram: following it, in a ring round it.
func _follow_ram(w) -> void:
	var off: Vector2 = w.position - wagon.position
	if off.length() > 140.0 or off.length() < 30.0:
		off = Vector2.from_angle(PI * 0.15 + (w.get_instance_id() % 8) * TAU / 8.0) * 60.0
	w.anchor = wagon
	w.anchor_off = off
	w.anchor_check = 0.0


## No more waves once the gate's open (the field's to be cleared), nor while the army's
## moving on or getting set in a new field.
## The garrison guards the gate: it holds its post until the ram is well on its way up
## (or your troops come at it); the rest of them are out for the ram.
const GUARD_UNTIL := 0.4   # share of the road

func enemy_goal(e):
	if e != null and e.has_meta("guard") and phase == "advance" and zone_along() < GUARD_UNTIL:
		return null
	return super.enemy_goal(e)


## Those with nothing to go for (the garrison at its post) stand where they are.
func wait_y() -> float:
	return 0.0


## An enemy archer tower still standing (not taken) keeps the battle on.
func hostiles() -> bool:
	for t in towers:
		if is_instance_valid(t) and not t.taken:
			return true
	return false


## The battle music plays once the fighting's begun, until the field's clear.
func battle_on() -> bool:
	return main.wave_active or (main.wave > 0 and phase != "ready" and not moving_on)


func waves_done_here() -> bool:
	return phase == "clear" or phase == "ready"


func holds_waves() -> bool:
	return phase == "clear" or phase == "ready" or moving_on or settle > 0.0


# --- Towers, pens, winch, supplies ---------------------------------------------------------------

## Your troops (and theirs) on ground `o` is taken on.
func _count(o) -> Array:
	var mine := 0
	var theirs := 0
	for w in main.warriors_near(o.position, o.capture_r()):
		if w.is_active() and not w.is_emplacement() and w.position.distance_to(o.position) <= o.capture_r():
			mine += 1
	for e in main.enemies_near(o.position, o.capture_r() + 30.0):
		if not e.dead and not e.flying and e.position.distance_to(o.position) <= o.capture_r():
			theirs += 1
	return [mine, theirs]


## Taking ground: control fills while only your troops are on it, drains (more slowly)
## while only theirs are. Returns true the moment it's taken.
func _take(o, delta: float) -> bool:
	if o.taken:
		return false
	var c := _count(o)
	o.contested = c[0] > 0 and c[1] > 0
	var time: float = TAKE_TIME.get(o.kind, 8.0)
	if o.kind == "winch":
		time = float(zone().get("winch", {}).get("time", time))
	if c[0] > 0 and c[1] == 0:
		o.progress = minf(1.0, o.progress + delta / time)
	elif c[1] > 0 and c[0] == 0:
		o.progress = maxf(0.0, o.progress - delta / time * 0.5)
	if o.progress >= 1.0:
		o.taken = true
		return true
	return false


func _towers(delta: float) -> void:
	var level: int = main.wave_level(maxi(main.wave, 1))
	for t in towers:
		if not is_instance_valid(t) or t.crewed:
			continue
		if not t.taken:
			# The archer on top shoots the nearest of yours in reach, the moment it's there.
			shot_t[t] = shot_t.get(t, 0.0) - delta
			if shot_t[t] <= 0.0:
				var mark = null
				var best := TOWER_RANGE
				for w in main.warriors_near(t.position, TOWER_RANGE + 40.0):
					if w.is_active() and not w.wall_guard and not w.sheltered():
						var d: float = t.position.distance_to(w.position) - w.RADIUS
						if d <= best:
							best = d
							mark = w
				if mark != null:
					shot_t[t] = TOWER_COOLDOWN
					t.loosed = 0.35
					t.aim = 1.0 if mark.position.x >= t.position.x else -1.0
					var shot = preload("res://scripts/enemy_shot.gd").new()
					shot.main = main
					shot.target = mark
					shot.target_pos = mark.position
					shot.position = t.position + Vector2(0, -78)
					shot.speed = 380.0
					shot.damage = 9.0 + level * 1.1
					main.add_projectile(shot)
					main.sfx("bow", 0.6)
				else:
					shot_t[t] = 0.0   # (looking every moment)
			if _take(t, delta):
				main.spawn_text(t.position + Vector2(0, -160), "Tower taken!", Color(0.6, 0.85, 1.0))
				main.hud.show_message("An archer tower is yours! Order a ranged troop onto it to post it up there.")
				main.sfx("fanfare")
				_tower_taken(t)


## A tower taken: what's left of it is your plain Tower now (free), for any ranged troop
## to climb into, as into one you'd built (see warrior.gd GARRISON_KINDS).
func _tower_taken(t) -> void:
	var tw := Warrior.new()
	tw.setup("tower", Data.WARRIORS["tower"], main, t.position)
	tw.spent = 0
	tw.position = tw.post
	tw.set_meta("captured", true)
	main.warrior_layer.add_child(tw)
	t.crewed = true   # (the enemy's tower is gone: yours stands there)
	main.paths.invalidate()
	main.warriors_changed()


## Captured towers with nobody in them yet.
func _empty_captured() -> Array:
	return main.get_warriors().filter(_is_empty_captured)


func _is_empty_captured(w) -> bool:
	return w.has_meta("captured") and w.is_active() and (w.crew_in == null or not is_instance_valid(w.crew_in))


## Crews left holding towers in the fields behind: [{"zone", "field", "tower", "crew": a
## unit record, trained as its tower was}]. They come back into play in the retreat
## (Phase 5, F5).
var garrisons: Array = []

func _hold_tower(tw, crew) -> void:
	var rec: Dictionary = _unit_record(crew)
	var k: float = main.FIELD_W / 640.0
	rec["post"] = Vector2(tw.position.x / k, tw.position.y)
	garrisons.append({"zone": zone_i, "field": zone()["name"], "tower": tw.kind, "crew": rec})


func _pens(delta: float) -> void:
	for pen in pens:
		if not is_instance_valid(pen) or pen.taken:
			continue
		if _take(pen, delta):
			_free_prisoners(pen)


## A pen opened: the soldiers in it join the army (on loan for this operation: they never
## bring their people into the Line), each trained up to tier III on one path, the rest
## left for you; the townsfolk make for safety down the field.
func _free_prisoners(pen) -> void:
	var spec: Dictionary = pen.get_meta("spec")
	var k: float = main.FIELD_W / 640.0
	var at := Vector2(pen.position.x / k, pen.position.y)
	var n := 0
	for s in spec.get("soldiers", []):
		var tiers := [0, 0, 0, 0]
		tiers[clampi(int(s.get("path", 0)), 0, 3)] = clampi(int(s.get("tier", 1)), 1, 3)
		var spot: Vector2 = at + Vector2(-26 + n * 26, 46)
		main._lend_unit({"kind": s["kind"], "at": spot, "tiers": tiers})
		var w = main.temp_allies.back()
		w.set_meta("freed", true)
		n += 1
		joined += 1
	for i in int(spec.get("townsfolk", 0)):
		var c = preload("res://scripts/mission/objective.gd").new()
		var start: Vector2 = at + Vector2(randf_range(-20, 20), 36 + randf_range(0, 10))
		var lane := clampf(start.x + randf_range(-30, 30), 40, 600)
		# Down the field the way a person would go: round the ruins and walls, not into them.
		var from: Vector2 = Vector2(start.x * k, start.y)
		var bottom: Vector2 = main.paths.open_spot(Vector2(lane * k, main.CASTLE_Y - 20.0))
		var way: Array = Array(main.paths.troop_route(from, bottom)).map(func(q): return Vector2(q.x / k, q.y))
		way.append(Vector2(bottom.x / k, 790))
		c.setup(main, {"id": "freed", "kind": "civilian", "name": "Townsfolk", "at": start, "variant": randi() % 24,
				"route": way, "speed": randf_range(30, 38), "hp": 40.0})
		main.add_objective(c)
		c.reached.connect(func(o):
			freed += 1
			o.queue_free())
		townsfolk.append(c)
	main.warriors_changed()
	main.spawn_text(pen.position + Vector2(0, -60), "Freed!", Color(0.6, 1.0, 0.6))
	var who := []
	if n > 0:
		who.append("%d soldier%s join%s you" % [n, "" if n == 1 else "s", "s" if n == 1 else ""])
	if int(spec.get("townsfolk", 0)) > 0:
		who.append("%d townsfolk run for safety" % int(spec["townsfolk"]))
	main.hud.show_message("Prisoners freed: " + ", ".join(who) + ".")
	main.sfx("fanfare")
	main.paths.invalidate()


func _townsfolk() -> void:
	townsfolk = townsfolk.filter(func(o): return is_instance_valid(o) and not o.is_queued_for_deletion())


func _caches() -> void:
	for c in caches:
		if not is_instance_valid(c) or c.taken:
			continue
		var counts := _count(c)
		if counts[0] > 0 and counts[1] == 0:
			c.taken = true
			main.gold += c.gold
			main.spawn_text(c.position + Vector2(0, -30), "+%dg supplies" % c.gold, Color(1, 0.85, 0.3))
			main.sfx("coin")


func _winch(delta: float) -> void:
	if winch == null or not is_instance_valid(winch) or winch.taken:
		return
	if _take(winch, delta):
		gate.open()
		main.hud.show_message("The winch house is yours: the portcullis goes up!")


# --- Volleys from the walls -------------------------------------------------------------------

## An Arrow Storm or a Fireball from the walls, now and then: a ring on the ground where
## it'll land (on the thickest knot of your troops), and a few seconds for them to get
## clear of it.
func _volleys(delta: float) -> void:
	if volley_t == INF or phase != "advance":
		return
	volley_t -= delta
	if volley_t > 0.0:
		return
	var v: Dictionary = zone().get("volleys", {})
	var every: Array = v.get("every", [50.0, 70.0])
	volley_t = randf_range(float(every[0]), float(every[1]))
	var spot = _volley_spot()
	if spot == null:
		volley_t = 8.0   # nobody bunched up to aim at: look again soon
		return
	var kinds: Array = v.get("kinds", ["arrows"])
	var kind: String = kinds.pick_random()
	var vd: Dictionary = VOLLEYS[kind]
	var level: int = main.wave_level(maxi(main.wave, 1))
	var fall := Volley.new()
	fall.main = main
	fall.position = spot
	fall.radius = vd["radius"]
	fall.hits = vd["hits"]
	fall.gap = vd["gap"]
	fall.damage = float(vd["damage"]) + float(vd["per_level"]) * level
	fall.color = vd["color"]
	fall.fire = kind == "fire"
	fall.warn = WARN
	main.add_projectile(fall)
	main.hud.show_message("%s from the walls! Get clear of the ring!" % vd["name"])
	main.sfx("horn", 0.7)


## Where a volley's aimed: the middle of the biggest knot of your troops (two or more,
## the ones that can move), or null.
func _volley_spot():
	var best = null
	var most := 1
	for w in main.get_warriors():
		if not w.is_active() or w.is_emplacement() or w.wall_guard:
			continue
		var near: Array = main.warriors_near(w.position, 70.0).filter(func(o): return o.is_active() and not o.is_emplacement())
		if near.size() > most:
			most = near.size()
			var c := Vector2.ZERO
			for o in near:
				c += o.position
			best = c / near.size()
	return best


## A volley coming down: its ring on the ground for `warn` seconds (filling as it comes),
## then its hits on everyone of yours still inside it.
class Volley extends Node2D:
	var main
	var radius := 70.0
	var hits := 1
	var gap := 0.3
	var damage := 30.0
	var color := Color.WHITE
	var fire := false
	var warn := 3.5
	var t := 0.0
	var landed := 0
	var next_hit := 0.0

	func _process(delta: float) -> void:
		if main.game_over:
			queue_free()
			return
		t += delta
		if t >= warn:
			next_hit -= delta
			if next_hit <= 0.0 and landed < hits:
				landed += 1
				next_hit = gap
				_land()
			if landed >= hits and t >= warn + gap * hits + 0.5:
				queue_free()
		queue_redraw()

	func _land() -> void:
		for w in main.warriors_near(position, radius + 20.0):
			if w.is_active() and position.distance_to(w.position) <= radius:
				w.take_damage(damage * (0.5 if w.is_emplacement() else 1.0))
		if fire:
			main.spawn_flash(position, radius * 0.8)
			main.spawn_burst(position, radius, Color(1.0, 0.5, 0.15))
			main.sfx("boom", 0.8)
		else:
			main.spawn_burst(position, radius * 0.8, Color(0.85, 0.8, 0.65))
			main.sfx("bow", 0.9)

	func _draw() -> void:
		var k := clampf(t / warn, 0.0, 1.0)
		if t < warn:
			draw_circle(Vector2.ZERO, radius, Color(color, 0.08 + 0.18 * k), true, -1.0, true)
			draw_circle(Vector2.ZERO, radius * k, Color(color, 0.18), true, -1.0, true)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color, 0.85), 3.0, true)
			var secs := ceili(warn - t)
			draw_string(ThemeDB.fallback_font, Vector2(-20, 6), str(secs), HORIZONTAL_ALIGNMENT_CENTER, 40, 18, Color(1, 1, 1, 0.9))
		else:
			var fade := clampf(1.0 - (t - warn) / (gap * hits + 0.5), 0.0, 1.0)
			draw_circle(Vector2.ZERO, radius, Color(color, 0.25 * fade), true, -1.0, true)
			if not fire:
				for i in 14:
					var p := Vector2.from_angle(i * 2.4) * radius * fmod(i * 0.37, 1.0)
					draw_line(p + Vector2(-3, -10), p, Color(0.3, 0.25, 0.2, fade), 2.0)


# --- Moving on ---------------------------------------------------------------------------------

func enter_next() -> void:
	if over or main.game_over:
		moving_on = false
		return
	_leave_zone()
	var side: Array = main.get_warriors().filter(func(w): return w.priority == Warrior.SIDE_PRIORITY)
	super.enter_next()   # the next field, the ram at the bottom of it, the army along with it
	for w in side:
		if is_instance_valid(w) and not w.is_queued_for_deletion():
			w.priority = Warrior.SIDE_PRIORITY   # (they keep at it in the next field)
			if w.has_meta("side_job"):
				w.remove_meta("side_job")
	_setup_zone()
	# Supplies up the road the towers behind hold open.
	if not garrisons.is_empty():
		main.gold += garrisons.size() * HELD_ROAD_GOLD
		main.hud.show_message("Supplies up the road your towers hold: +%d gold" % (garrisons.size() * HELD_ROAD_GOLD))
	checkpoint()   # (with the stragglers, so a battle taken up again here has them too)


## Enemies left on the last field come through after the army (as it gets there, or once
## it's deployed, taken up again from here).
func _stragglers_come() -> void:
	for st in stragglers:
		main._spawn_enemy(str(st[0]), int(st[1]))   # (out at the top of the field, as any enemy)
	if not stragglers.is_empty():
		main.hud.show_message("%d enem%s followed you through!" % [stragglers.size(), "y" if stragglers.size() == 1 else "ies"])
	stragglers.clear()


func _move_on() -> void:
	if over or moving_on or main.game_over:
		return
	moving_on = true
	main.hud.show_message("Through %s..." % gate.label.to_lower())
	main.hud.fade_through_black(enter_next)


# --- Checkpoints ---------------------------------------------------------------------------------

## The army as it stands at the start of a field (after the first): kept, so a lost
## battle can be taken up again from here.
func checkpoint() -> void:
	if not main.campaign:
		return
	var army := []
	for w in main.warrior_layer.get_children():
		if w.is_queued_for_deletion() or w.summoned or w.clone_of != null:
			continue
		army.append(_unit_record(w))
	cp_xp = main.battle_xp.duplicate()
	cp_name = zone()["name"]
	Campaign.set_checkpoint(Campaign.mission_id, zone_i, {"zone": zone_i, "name": cp_name, "gold": main.gold,
			"wave": main.wave, "ram": wagon.hp / wagon.max_hp, "army": army, "xp": cp_xp, "owned": main.powers.owned.keys(),
			"freed": freed, "joined": joined, "garrisons": garrisons.duplicate(true),
			"stragglers": stragglers.duplicate(true)})


## Picks the operation up from its checkpoint: the army, gold, the ram's health, the XP
## already earned, the abilities bought.
func _restore(cp: Dictionary) -> void:
	for w in main.warrior_layer.get_children():
		w.queue_free()
	main.temp_allies.clear()
	for rec in cp.get("army", []):
		if rec is Dictionary:
			_make_unit(rec)
	main.gold = int(cp.get("gold", main.gold))
	main.wave = int(cp.get("wave", 0))
	wagon.hp = wagon.max_hp * clampf(float(cp.get("ram", 1.0)), 0.05, 1.0)
	for key in cp.get("owned", []):
		main.powers.owned[key] = true
	main.battle_xp = (cp.get("xp", {}) as Dictionary).duplicate()
	cp_xp = main.battle_xp.duplicate()
	cp_name = str(cp.get("name", zone()["name"]))
	freed = int(cp.get("freed", 0))
	joined = int(cp.get("joined", 0))
	garrisons = (cp.get("garrisons", []) as Array).duplicate(true)
	stragglers = (cp.get("stragglers", []) as Array).duplicate(true)
	main.warriors_changed()
	main.hud.show_message("Taken up again from %s." % cp_name)


## The XP to bank now: on a loss, only what was earned since the checkpoint (what came
## before it is kept with the checkpoint, to be banked once, with the win).
func xp_gains(won: bool, gains: Dictionary) -> Dictionary:
	if won or cp_xp.is_empty():
		return gains
	var out := {}
	for kind in gains:
		var d: float = gains[kind] - float(cp_xp.get(kind, 0.0))
		if d > 0.0:
			out[kind] = d
	return out


## The field a lost battle can be taken up again from ("" if there's none yet).
func checkpoint_name() -> String:
	return cp_name   # (the one this battle started from, or last passed: the XP before it waits for the win)


# --- What the HUD says ---------------------------------------------------------------------

func status() -> String:
	if wagon == null:
		return ""
	var where := "%s (%d of %d)  ·  " % [zone()["name"], zone_i + 1, zones().size()]
	var text := where + "%s %d%%" % [wagon.label, roundi(wagon.hp / wagon.max_hp * 100.0)]
	if settle > 0.0:
		return text + "  ·  sets off in %ds" % ceili(settle)
	if phase == "ready":
		return text + "  ·  the way is clear: go on when you're ready (Y)"
	if phase == "clear":
		var left: int = main.get_enemies().size() + main.spawn_queue.size()
		var down := _downed()
		if left > 0:
			return text + "  ·  clear the field: %d left" % left
		if down > 0:
			return text + "  ·  %d down: the Healers' chance" % down
		return text
	if wagon.arrived:
		if gate.style == "portcullis":
			return text + "  ·  take the winch house: %d%%" % roundi(winch.progress * 100.0) if winch != null else text
		text += "  ·  %s: %d%%" % [gate.label, roundi(gate.hp / gate.max_hp * 100.0)]
		if wagon.halted:
			text += "  ·  under attack: stopped!"
		return text
	text += "  ·  to the gate: %d%%" % roundi(zone_along() * 100.0)
	if wagon.halted:
		text += "  ·  under attack: slowed!"
	return text


func panel_status() -> String:
	return "Ram %d%%" % roundi(wagon.hp / wagon.max_hp * 100.0) if wagon != null else ""


func summary(won: bool) -> String:
	var extra := ""
	if joined > 0 or freed > 0:
		extra = "  %d prisoner%s freed to fight on; %d townsfolk led out." % [joined, "" if joined == 1 else "s", freed]
	if not garrisons.is_empty():
		extra += "  %d tower%s left manned behind the army." % [garrisons.size(), "" if garrisons.size() == 1 else "s"]
	if won:
		return "Dawnspire's gates are broken: the ram came through with %d%% of its health.%s" % [score(), extra]
	return "The ram was destroyed at %s.%s" % [zone()["name"], extra]
