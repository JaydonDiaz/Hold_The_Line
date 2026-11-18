extends "res://scripts/mission/rules.gd"
## The Liberation of Dawnspire, inside the walls (Phase 5, F3): the army fights its way
## through the citadel room by room. It carries on the assault (rules_assault.gd hands over
## once the Dawn Gate's field is clear) as the same operation: the same army, gold,
## checkpoints and towers held behind it.
##
## The castle is rooms joined by doors: the main way (each room's north door to the next)
## and side rooms off it (a door in an east or west wall, and back the same way): prison
## cells (the soldiers in them join on loan, the townsfolk make for the way out), a supply
## room and a treasure room (gold). A room (a "hall" map: castle_art.gd) has walls all round.
## The army comes in at a door and plants the Line's standard by it: that's what the enemy
## goes for here, and if it falls the army breaks (the battle's lost). The room's garrison
## holds its posts until the army's close; then the room's waves (a main room's) come in
## through its far door. Once they're beaten (and nobody's down, or LINGER seconds after the
## last one came in, whatever's left), an arrow shows at each door, named for where it
## leads. Clicking one (or Y, for the way on) gives the order: the troops make for that
## door, the view pans through to the room beyond as the first of them gets there, and they
## come in at its door when each would have got there, walking on to where they stood in
## the last room (as near as this one allows). Emplacements are taken down and hauled
## through after them; barricades are taken down and paid back; troops still down are left
## where they fell; enemies still about follow the army through that door.
## A room remembers being taken: gone back into (from a side room), nobody's there, and
## what was taken in it (pens opened, supplies claimed) stays taken.
## Every room the army comes into is a checkpoint (Campaign.op_state, at 100 + the room's
## place): the battle can be taken up again as the army stood when it came in, the rooms as
## they were then (nothing taken since is had twice). Taken up with too little left to win
## with (army and gold worth less than the castle's "reserve"), reserves come up from the
## gate to make it up to that, once per try, so a bad checkpoint can't trap the player.
##
## Mission data: "assault": {"castle": {"reserve": gold, "standard": hp,
##   "rooms": [{"id", "map", "name", "note", "waves": how many come in (0: none, a side room),
##     "garrison": [[kind, at], ...], "doors": {door id: room id, or "out" to finish},
##     "pens": [{"at", "townsfolk": n, "soldiers": [{"kind", "path", "tier"}]}],
##     "caches": [{"at", "gold", "style": "" or "chest"}]}]}}

const Works = preload("res://scripts/mission/siege_works.gd")
const Warrior = preload("res://scripts/warrior.gd")
const Data = preload("res://scripts/data.gd")
const Maps = preload("res://scripts/maps.gd")
const CP_BASE := 100          # a room's checkpoint is kept at this plus its place in the rooms
const LINGER := 20.0          # seconds after its last enemy came in that the army may go on anyway
const WAKE := 200.0           # a room's garrison stays at its posts until a troop's this near
const AT_DOOR := 30.0         # a troop this near the door's middle is through it
const FIRST_LIMIT := 8.0      # the first troop not there by now: the view goes on anyway
const LATE_LIMIT := 8.0       # nobody comes in later than this after the first (a lost troop catches up)
const PAN_TIME := 0.9
const ENTRY_DEPTH := 170.0    # how far into a room the army's middle comes to stand
const TAKE_TIME := 6.0        # seconds of troops round a pen, with no enemy there, to open it

var rooms: Array = []
var room_i := 0
var entry := "s"              # the door the army came into this room by
var phase := "enter"          # "enter" (coming in), "fight", "clear" (a way on open), "march" (going), "pan"
var wave0 := 0                # main.wave when this room was entered
var linger := 0.0
var standard = null
var arrows: Array = []        # [{"door", "at", "to"}] the ways on once the room's taken
var march_door := {}          # the door being gone through
var march_t := 0.0
var march_units: Array = []   # the troops on their way to it
var through: Array = []       # [record, seconds after the first got through]
var first_t := -1.0
var arrive_t := 0.0           # in the room being entered: seconds since the view got there
var arrivals: Array = []      # [record, when, entry post]
var over := false
var garrisons: Array = []     # towers left manned outside (from the assault)
var freed := 0
var joined := 0
var cp_xp := {}
var cp_name := ""
var stragglers: Array = []
var reserve_given := false
var arrow_node: Node2D = null
var restored_entry := false   # this room taken up from its checkpoint: the army's at its posts already
var room_state := {}          # room id -> {"cleared": bool, "taken": [ids of what's been had in it]}
var pens: Array = []          # this room's prison pens (siege_works stockades, "iron")
var caches: Array = []        # ...and its supplies (or treasure)
var townsfolk: Array = []     # freed townsfolk on their way out
var fight_t := 0.0            # seconds since the army was all in the room


## Draws the ways-on arrows over everything on the field.
class ArrowNode extends Node2D:
	var rules
	func _process(_delta: float) -> void:
		if rules == null or rules.phase != "clear":
			queue_free()
			return
		queue_redraw()
	func _draw() -> void:
		rules.draw_over(self)


func _c() -> Dictionary:
	return mission.get("assault", {}).get("castle", {})


func room() -> Dictionary:
	return rooms[room_i]


func _state(id: String) -> Dictionary:
	if not room_state.has(id):
		room_state[id] = {"cleared": false, "taken": []}
	return room_state[id]


func has_castle() -> bool:
	return false


func show_camp() -> bool:
	return false


func endless() -> bool:
	return false


func side_objectives() -> bool:
	return true   # (troops on Side Objectives go to a room's cells and supplies)


## The standard's an objective: guard it.
func guards() -> bool:
	return true


## From the assault, its last field clear and the order given: the army marches in
## through the Dawn Gate (`gate_at`), and on into the first room.
func take_over(a, gate_at: Vector2) -> void:
	rooms = _c().get("rooms", [])
	garrisons = a.garrisons.duplicate(true)
	freed = a.freed
	joined = a.joined
	cp_xp = a.cp_xp.duplicate()
	cp_name = a.cp_name
	room_i = -1
	for b in main.get_barricades():
		main.gold += int(b.spent)
		b.queue_free()
	main.walls_changed()
	_march_to({"id": "gate", "side": "n", "at": gate_at, "point": gate_at}, 0)


## Taken up again from a room's checkpoint.
func resume(cp: Dictionary) -> void:
	rooms = _c().get("rooms", [])
	room_i = clampi(int(cp.get("room", 0)), 0, rooms.size() - 1)
	for w in main.warrior_layer.get_children():
		w.queue_free()
	main.temp_allies.clear()
	main.gold = int(cp.get("gold", main.gold))
	main.wave = int(cp.get("wave", 0))
	for key in cp.get("owned", []):
		main.powers.owned[key] = true
	main.battle_xp = (cp.get("xp", {}) as Dictionary).duplicate()
	cp_xp = main.battle_xp.duplicate()
	cp_name = str(cp.get("name", ""))
	freed = int(cp.get("freed", 0))
	joined = int(cp.get("joined", 0))
	garrisons = (cp.get("garrisons", []) as Array).duplicate(true)
	stragglers = (cp.get("stragglers", []) as Array).duplicate(true)
	room_state = (cp.get("rooms", {}) as Dictionary).duplicate(true)
	var army: Array = cp.get("army", [])
	# Reserves: never so little to go on with that the room can't be won.
	var worth: int = main.gold
	for rec in army:
		worth += int(rec.get("spent", 0))
	var floor_gold := int(_c().get("reserve", 0))
	if worth < floor_gold and not reserve_given:
		reserve_given = true
		main.gold += floor_gold - worth
		main.hud.show_message("Reserves come up from the gate: +%d gold" % (floor_gold - worth))
	_enter_room(room_i, army.map(func(r): return [r, 0.0]), float(cp.get("standard", 1.0)), str(cp.get("entry", "s")), true)
	main.hud.show_message("Taken up again from %s." % cp_name)


# --- A room ---------------------------------------------------------------------------------

## Which way is into the room from a door on `side`.
static func _inward(side: String) -> Vector2:
	match side:
		"n":
			return Vector2(0, 1)
		"e":
			return Vector2(-1, 0)
		"w":
			return Vector2(1, 0)
	return Vector2(0, -1)


func _door(id: String) -> Dictionary:
	for d in Maps.get_map(room()["map"]).get("doors", []):
		if d["id"] == id:
			return d
	return {"id": id, "side": id, "at": Vector2(320, 756 if id == "s" else 22)}


## A point on the field as it's drawn up (640 wide), for what's set up from data.
func _base(p: Vector2) -> Vector2:
	return Vector2(p.x * 640.0 / main.FIELD_W, p.y)


func _door_at(d: Dictionary) -> Vector2:
	var k: float = main.FIELD_W / 640.0
	return Vector2(d["at"].x * k, d["at"].y)


## Into room `i` by door `by`: its ground, the standard planted by that door, its garrison
## and what's in it (unless it's been taken), and the army coming in (each [record, seconds
## after the first]).
func _enter_room(i: int, coming: Array, standard_hp: float, by := "s", restored := false) -> void:
	room_i = i
	entry = by
	var r := room()
	var st := _state(r["id"])
	change_field(r["map"])
	var k: float = main.FIELD_W / 640.0
	var door := _door(by)
	var at := _door_at(door)
	var inward := _inward(door["side"])
	var across := Vector2(-inward.y, inward.x)
	# The standard, a little in from the door and to one side.
	var spot: Vector2 = at + inward * 70.0 + across * 60.0 * k
	if standard == null or not is_instance_valid(standard):
		standard = Works.new()
		standard.setup(main, {"id": "standard", "kind": "standard", "name": "The Line's standard", "at": _base(spot),
				"hp": float(_c().get("standard", 900.0))})
		main.add_objective(standard)
		standard.destroyed.connect(func(_o): _end(false))
	standard.position = main.paths.open_spot(spot)
	standard.hp = standard.max_hp * clampf(standard_hp, 0.05, 1.0)
	# What's in it: its garrison (not once it's taken), its pens and supplies (not what's had).
	pens.clear()
	caches.clear()
	townsfolk.clear()
	if not st["cleared"]:
		for g in r.get("garrison", []):
			main._spawn_enemy(g[0], main.wave_level(maxi(main.wave, 1)) + int(_c().get("level_bonus", 0)), Vector2(g[1].x * k, g[1].y))
			var e = main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)
			e.set_meta("guard", true)
			e.goal = null
			if g.size() > 2 and g[2] == "warden":
				_make_warden(e)
	var n := 0
	for p in r.get("pens", []):
		var id := "%s:pen%d" % [r["id"], n]
		n += 1
		if (st["taken"] as Array).has(id):
			continue
		var pen := Works.new()
		pen.setup(main, {"id": id, "kind": "stockade", "style": "iron", "name": "A cell", "at": p["at"],
				"prisoners": int(p.get("townsfolk", 0)) + (p.get("soldiers", []) as Array).size()})
		pen.set_meta("spec", p)
		main.add_objective(pen)
		pens.append(pen)
	n = 0
	for c in r.get("caches", []):
		var id := "%s:cache%d" % [r["id"], n]
		n += 1
		if (st["taken"] as Array).has(id):
			continue
		var cache := Works.new()
		cache.setup(main, {"id": id, "kind": "cache", "style": str(c.get("style", "")), "name": "Treasure" if c.get("style", "") == "chest" else "Supplies",
				"at": c["at"], "gold": int(c.get("gold", 60))})
		main.add_objective(cache)
		caches.append(cache)
	main.paths.set_objectives(objectives())
	# The army, as it comes in: its shape kept round where it comes to stand.
	arrivals.clear()
	arrive_t = 0.0
	var c_old := Vector2.ZERO
	for row in coming:
		c_old += row[0].get("post", Vector2(320, 600))
	c_old /= maxf(coming.size(), 1)
	var c_new: Vector2 = Vector2(door["stand"].x * k, door["stand"].y) if door.has("stand") else at + inward * ENTRY_DEPTH
	# (Turned to face the way it's come in: a room entered from the side gets the army's
	# depth across it.)
	for row in coming:
		var rec: Dictionary = row[0]
		var p: Vector2 = rec.get("post", c_old)
		var off := Vector2((p.x - c_old.x) * k * 0.85, (p.y - c_old.y) * 0.7)
		if door["side"] in ["e", "w"]:
			off = Vector2(-off.y * inward.x, off.x)
		var post: Vector2 = (c_new + off) if not restored else Vector2(p.x * k, p.y)
		post = Vector2(clampf(post.x, 50.0 * k, main.FIELD_W - 50.0 * k), clampf(post.y, 70.0, 720.0))
		arrivals.append([rec, float(row[1]), main.paths.open_spot(main._clamp_post(post))])
	arrivals.sort_custom(func(a, b): return a[1] < b[1])
	restored_entry = restored
	wave0 = main.wave
	linger = 0.0
	arrows.clear()
	phase = "enter"
	if st["cleared"]:
		main.hud.show_message("Back in %s." % r["name"])
	elif r.get("note", "") != "":
		main.hud.show_message(r["note"])
	if not restored:
		checkpoint()


## A unit back on the field: at the door, walking on to its place.
func _arrive(rec: Dictionary, post: Vector2, at_post := false) -> void:
	var door := _door(entry)
	var at := _door_at(door) + _inward(door["side"]) * 6.0
	var w = _make_unit(rec)
	if w == null:
		return
	if w.data.get("emplacement", false) or at_post:
		w.post = post   # (hauled in and set up again where it's to stand; or taken up again where it stood)
		w.position = post
	else:
		w.position = main.paths.open_spot(at + Vector2(randf_range(-10, 10), randf_range(-10, 10)))
		w.order_to(post)
	main.warriors_changed()


## New troops (and Engineers) come into a room by the door the army came in by.
func entry_point(_post: Vector2) -> Vector2:
	if room_i < 0 or rooms.is_empty():
		return Vector2.INF
	var door := _door(entry)
	return main.paths.open_spot(_door_at(door) + _inward(door["side"]) * 40.0)


func objectives() -> Array:
	var out := []
	if standard != null and is_instance_valid(standard) and not standard.dead:
		out.append(standard)
	for o in pens + caches + townsfolk:
		if is_instance_valid(o) and not o.is_queued_for_deletion():
			out.append(o)
	return out


func enemy_goal(e):
	if e != null and e.has_meta("guard") and not _awake():
		return null
	return standard if standard != null and is_instance_valid(standard) and standard.is_target() else null


## The garrison wakes once a troop's near, one of them is hurt, the room's waves have
## begun, or the army's been in the room ALERT seconds: then it comes for the standard (so
## nobody's left waiting behind a wall for good).
const ALERT := 15.0
var _woke := false
func _awake() -> bool:
	if _woke:
		return true
	if main.wave > wave0 or (phase == "fight" and fight_t >= ALERT):
		_woke = true
		return true
	for e in main.get_enemies():
		if not e.has_meta("guard"):
			continue
		if e.hp < e.max_hp or not main.warriors_near(e.position, WAKE).filter(func(w): return w.is_active() and not w.is_emplacement()).is_empty():
			_woke = true
			return true
	return false


## The enemy here is only ever after the standard (asked again every second, so a garrison
## that wakes sets out for it).
func objective_only() -> bool:
	return true


func wait_y() -> float:
	return 0.0


func on_reached_bottom(_e) -> bool:
	return true


func _waves() -> int:
	return 0 if _state(room()["id"])["cleared"] else int(room().get("waves", 2))


func holds_waves() -> bool:
	return phase != "fight" or main.wave - wave0 >= _waves()


func waves_done_here() -> bool:
	return phase == "fight" and main.wave - wave0 >= _waves() or phase == "clear"


func wave_cleared(_n: int) -> bool:
	return false


func wave_text() -> String:
	if room_i < 0 or rooms.is_empty():
		return ""
	if phase == "clear":
		return "Room taken"
	if phase != "fight" or _waves() == 0:
		return "Foes %d" % main.get_enemies().size()
	return "Wave %d/%d" % [clampi(main.wave - wave0, 0, _waves()), _waves()]


func process(delta: float) -> void:
	if over or main.game_over:
		return
	if phase in ["fight", "clear"]:
		_pens(delta)
		_caches()
		_send_side(delta)
	match phase:
		"enter":
			arrive_t += delta
			while not arrivals.is_empty() and arrivals[0][1] <= arrive_t:
				var a: Array = arrivals.pop_front()
				_arrive(a[0], a[2], restored_entry)
			if arrivals.is_empty():
				phase = "fight"
				fight_t = 0.0
				_woke = false
				_stragglers_come()
		"fight":
			fight_t += delta
			var done: bool = main.wave - wave0 >= _waves() and main.spawn_queue.is_empty()
			if done and main.get_enemies().is_empty() and _downed() == 0:
				_room_taken()
			elif done:
				linger += delta
				if linger >= LINGER:
					_room_taken()
		"march":
			_march_step(delta)


# --- What's in a room: cells and supplies ---------------------------------------------------

## A cell room's Warden: its jailer, far tougher than the rest (WARDEN times their health,
## harder blows, shrugging off half of what would stun or slow it), and he holds the keys:
## no cell in the room opens while he lives.
const WARDEN := {"hp": 2.6, "damage": 1.35, "cc": 0.5}

func _make_warden(e) -> void:
	e.set_meta("title", "The Warden")
	e.set_meta("warden", true)
	e.max_hp *= WARDEN["hp"]
	e.hp = e.max_hp
	e.damage *= WARDEN["damage"]
	e.wall_damage *= WARDEN["damage"]
	e.cc_mult *= WARDEN["cc"]
	e.bounty *= 3


func _warden_alive() -> bool:
	for e in main.get_enemies():
		if not e.dead and e.has_meta("warden"):
			return true
	return false


## A pen opens once troops have stood round it a while with no enemy there (and, in a
## room with a Warden, once he's down: he holds the keys).
var told_keys := false
func _pens(delta: float) -> void:
	if not pens.is_empty() and _warden_alive():
		for pen in pens:
			if is_instance_valid(pen) and not pen.taken and not told_keys and not main.warriors_near(pen.position, pen.capture_r()).is_empty():
				told_keys = true
				main.hud.show_message("Locked fast: the Warden has the keys. Bring him down first.")
		return
	for pen in pens:
		if not is_instance_valid(pen) or pen.taken:
			continue
		var mine := 0
		var theirs := 0
		for w in main.warriors_near(pen.position, pen.capture_r()):
			if w.is_active() and not w.is_emplacement() and w.position.distance_to(pen.position) <= pen.capture_r():
				mine += 1
		for e in main.enemies_near(pen.position, pen.capture_r() + 30.0):
			if not e.dead and not e.flying and e.position.distance_to(pen.position) <= pen.capture_r():
				theirs += 1
		pen.contested = mine > 0 and theirs > 0
		if mine > 0 and theirs == 0:
			pen.progress = minf(1.0, pen.progress + delta / TAKE_TIME)
		elif theirs > 0 and mine == 0:
			pen.progress = maxf(0.0, pen.progress - delta / TAKE_TIME * 0.5)
		if pen.progress >= 1.0:
			pen.taken = true
			_had(pen.id)
			_free_prisoners(pen)


## A cell opened: its soldiers join the army on loan (each trained up to tier III on one
## path), its townsfolk make for the door the army came in by, and out.
func _free_prisoners(pen) -> void:
	var spec: Dictionary = pen.get_meta("spec")
	var k: float = main.FIELD_W / 640.0
	var n := 0
	for s in spec.get("soldiers", []):
		var tiers := [0, 0, 0, 0]
		tiers[clampi(int(s.get("path", 0)), 0, 3)] = clampi(int(s.get("tier", 1)), 1, 3)
		var spot: Vector2 = main.paths.open_spot(pen.position + Vector2(-26 + n * 26, 46))
		main._lend_unit({"kind": s["kind"], "at": Vector2(spot.x / k, spot.y), "tiers": tiers})
		var w = main.temp_allies.back()
		w.set_meta("freed", true)
		n += 1
		joined += 1
	var door := _door(entry)
	var out := _door_at(door)
	var by: Vector2 = out + _inward(door["side"]) * 60.0
	for i in int(spec.get("townsfolk", 0)):
		var c = preload("res://scripts/mission/objective.gd").new()
		var start: Vector2 = pen.position + Vector2(randf_range(-20, 20), 36 + randf_range(0, 10))
		var route: PackedVector2Array = main.paths.troop_route(start, by)
		var pts: Array = Array(route) + [out]
		c.setup(main, {"id": "freed", "kind": "civilian", "name": "Townsfolk", "at": _base(start), "variant": randi() % 24,
				"route": pts.map(_base), "speed": randf_range(30, 38), "hp": 40.0})
		main.add_objective(c)
		c.reached.connect(func(o):
			freed += 1
			townsfolk.erase(o)
			o.queue_free())
		townsfolk.append(c)
	main.warriors_changed()
	main.spawn_text(pen.position + Vector2(0, -60), "Freed!", Color(0.6, 1.0, 0.6))
	var who := []
	if n > 0:
		who.append("%d soldier%s join%s you" % [n, "" if n == 1 else "s", "s" if n == 1 else ""])
	if int(spec.get("townsfolk", 0)) > 0:
		who.append("%d townsfolk make for the way out" % int(spec["townsfolk"]))
	main.hud.show_message("Prisoners freed: " + ", ".join(who) + ".")
	main.sfx("fanfare")
	main.paths.invalidate()


## Supplies (or treasure): a troop that gets to them, with no enemy there, claims the gold.
func _caches() -> void:
	for c in caches:
		if not is_instance_valid(c) or c.taken:
			continue
		if not main.enemies_near(c.position, 50.0).filter(func(e): return not e.dead).is_empty():
			continue
		for w in main.warriors_near(c.position, c.capture_r() + 14.0):
			if w.is_active() and not w.is_emplacement():
				c.taken = true
				_had(c.id)
				main.gold += c.gold
				main.spawn_text(c.position + Vector2(0, -40), "+%dg" % c.gold, Color(1, 0.85, 0.3))
				main.sfx("coin")
				main.hud.show_message("%s: +%d gold" % [c.label, c.gold])
				c.queue_free()
				break


## Troops on Side Objectives (every half second): each goes to a cell still locked or
## supplies still unclaimed in this room, the nearest, the work shared out; with nothing
## left here, back by the standard.
var side_t := 0.0

func _send_side(delta: float) -> void:
	side_t -= delta
	if side_t > 0.0:
		return
	side_t = 0.5
	var jobs := (pens + caches).filter(func(o): return is_instance_valid(o) and not o.taken and not o.is_queued_for_deletion())
	var troops: Array = main.get_warriors().filter(func(w): return w.is_active() and w.priority == Warrior.SIDE_PRIORITY \
			and not w.is_emplacement() and not w.summoned and w.clone_of == null and not w.held)
	var busy := {}
	for w in troops:
		var j = w.get_meta("side_job") if w.has_meta("side_job") else null
		if j != null and jobs.has(j):
			busy[j] = busy.get(j, 0) + 1
	for w in troops:
		var j = w.get_meta("side_job") if w.has_meta("side_job") else null
		if j != null and jobs.has(j):
			continue
		var best = null
		var best_cost := INF
		for o in jobs:
			var cost: float = w.position.distance_to(o.position) + 160.0 * busy.get(o, 0)
			if cost < best_cost:
				best_cost = cost
				best = o
		if best == null:
			if w.has_meta("side_job"):
				w.remove_meta("side_job")
				# Nothing left to do here: back by the standard.
				if standard != null and is_instance_valid(standard):
					var off := Vector2.from_angle((w.get_instance_id() % 8) * TAU / 8.0) * 70.0
					w.order_to(main.paths.open_spot(main._clamp_post(standard.position + off)))
			continue
		var n: int = busy.get(best, 0)
		busy[best] = n + 1
		w.set_meta("side_job", best)
		w.anchor = null
		var rr: float = best.capture_r() * (0.25 if best.kind == "cache" else 0.6)
		w.order_to(main.paths.open_spot(main._clamp_post(best.position + Vector2.from_angle(PI * 0.5 + n * 1.3) * rr)))


## Something in this room had (a cell opened, supplies claimed): not to be had again.
func _had(id: String) -> void:
	var taken: Array = _state(room()["id"])["taken"]
	if not taken.has(id):
		taken.append(id)


# --- The ways on --------------------------------------------------------------------------

## The room's taken (or nothing more is coming): the ways on show.
func _room_taken() -> void:
	phase = "clear"
	var first: bool = not _state(room()["id"])["cleared"]
	_state(room()["id"])["cleared"] = true
	arrows.clear()
	if arrow_node == null or not is_instance_valid(arrow_node):
		arrow_node = ArrowNode.new()
		arrow_node.rules = self
		arrow_node.z_index = 50
		main.add_child(arrow_node)
	for d in Maps.get_map(room()["map"]).get("doors", []):
		var to: String = str(room().get("doors", {}).get(d["id"], ""))
		if to == "":
			continue
		arrows.append({"door": d, "at": _door_at(d), "to": to})
	if first:
		main.hud.show_message("%s is yours. On through a door when you're ready (click its arrow; Y for the way on)." % room()["name"])
		main.sfx("horn", 1.2)
	main.queue_redraw()


## The way on: the door that leads to the next room on the main way (not a side room, nor
## back), or out.
func _forward():
	for a in arrows:
		var to := str(a["to"])
		if to == "out" or (a["door"]["side"] == "n"):
			return a
	return null


func action_label() -> String:
	if phase != "clear" or _forward() == null:
		return ""
	return "On through the door"


func action() -> void:
	if action_label() != "":
		_ask(_forward())


## A click on a way on's arrow: go that way.
func click(p: Vector2) -> bool:
	if phase != "clear":
		return false
	for a in arrows:
		if p.distance_to(_arrow_point(a)) <= 34.0:
			_ask(a)
			return true
	return false


func _arrow_point(a: Dictionary) -> Vector2:
	return a["at"] + _inward(a["door"]["side"]) * 46.0


func _where(a: Dictionary) -> String:
	var to := str(a["to"])
	return "the Throne Room" if to == "out" else _room_named(to)


## What's left behind, said before going (and the choice not to yet).
func _ask(a: Dictionary) -> void:
	if main.hud.choice_box != null and is_instance_valid(main.hud.choice_box):
		return
	var notes := []
	var down := _downed()
	var foes: int = main.get_enemies().size()
	if down > 0:
		notes.append("%d troop%s down: a Healer can still get %s up. Go now and %s left behind." % [down, " is" if down == 1 else "s are",
				"it" if down == 1 else "them", "it's" if down == 1 else "they're"])
	if foes > 0:
		notes.append("%d enem%s still here: %s." % [foes, "y is" if foes == 1 else "ies are", "it'll follow you" if foes == 1 else "they'll follow you"])
	var left := pens.filter(func(p): return is_instance_valid(p) and not p.taken).size()
	if left > 0:
		notes.append("%d cell%s still locked here." % [left, "" if left == 1 else "s"])
	if notes.is_empty():
		_go(a)
		return
	main.hud.show_choice("On to %s?" % _where(a), "\n\n".join(notes), [["Go on", func(): _go(a)], ["Not yet", null]])


func _room_named(id: String) -> String:
	for r in rooms:
		if r["id"] == id:
			return r["name"]
	return id


func _go(a: Dictionary) -> void:
	if phase != "clear":
		return
	if str(a["to"]) == "out":
		_end(true)
		return
	_march_to(a["door"], _room_index(str(a["to"])))


func _room_index(id: String) -> int:
	for i in rooms.size():
		if rooms[i]["id"] == id:
			return i
	return room_i + 1


# --- Going through a door -------------------------------------------------------------------

var march_to := 0
var orders := {}   # troop instance id -> its record as it stood before the march (its post, its orders)

## The order to go through `door` into room `to`: the troops make for it.
func _march_to(door: Dictionary, to: int) -> void:
	phase = "march"
	arrows.clear()
	march_door = door.duplicate()
	march_to = to
	march_t = 0.0
	first_t = -1.0
	through.clear()
	main.queue_redraw()
	var at: Vector2 = door["point"] if door.has("point") else _door_at(door) + _inward(door["side"]) * 30.0   # (in the doorway's mouth)
	march_door["point"] = at
	march_units.clear()
	orders.clear()
	for w in main.warrior_layer.get_children():
		if w.is_queued_for_deletion() or w.summoned or w.clone_of != null:
			continue
		if w.data.get("emplacement", false):
			continue   # (hauled through after the troops)
		if w.down_timer > 0.0:
			continue   # (left where it fell)
		if w.garrison != null:
			w.leave_tower()
		orders[w.get_instance_id()] = _unit_record(w)   # (where it stood, and its orders, for the next room)
		w.order_to(main._clamp_post(at + Vector2(randf_range(-14, 14), randf_range(-14, 14))))
		w.move_mode = "free"
		march_units.append(w)
	main.hud.show_message("On through the door!")


## A marching troop's record: as it stood before the march, with the health it has now.
func _record(w) -> Dictionary:
	var rec: Dictionary = orders.get(w.get_instance_id(), _unit_record(w)).duplicate()
	rec["hp"] = w.hp / maxf(w.max_hp, 1.0)
	return rec


## Each step of the march: troops that get to the door are through (gone from this room).
## Once the first is through, the view goes after it; the rest come in when they would
## have got there (by the way they have to go and how fast they walk).
func _march_step(delta: float) -> void:
	march_t += delta
	var at: Vector2 = march_door["point"]
	for w in march_units.duplicate():
		if not is_instance_valid(w) or w.is_queued_for_deletion():
			march_units.erase(w)
			continue
		if w.position.distance_to(at) <= AT_DOOR + w.RADIUS * 0.5:
			if first_t < 0.0:
				first_t = march_t
			through.append([_record(w), march_t - first_t])
			march_units.erase(w)
			w.queue_free()
	if first_t < 0.0 and march_t >= FIRST_LIMIT:
		first_t = march_t   # (nobody can get there: on anyway, the army catches up)
	if first_t >= 0.0 and phase == "march":
		_pan()


func _pan() -> void:
	phase = "pan"
	# The rest: when each would get there, by the way it has to go.
	var at: Vector2 = march_door["point"]
	for w in march_units:
		if not is_instance_valid(w):
			continue
		var route: PackedVector2Array = main.paths.troop_route(w.position, at)
		var length := 0.0
		var from: Vector2 = w.position
		for q in route:
			length += from.distance_to(q)
			from = q
		if route.is_empty():
			length = w.position.distance_to(at)
		var when := clampf(march_t - first_t + length / maxf(w.move_speed, 20.0), 0.0, LATE_LIMIT)
		through.append([_record(w), when])
		w.queue_free()
	march_units.clear()
	# Emplacements: taken down and hauled through last. Troops still down: left behind.
	var last := 0.0
	for row in through:
		last = maxf(last, row[1])
	var left := 0
	for w in main.warrior_layer.get_children():
		if w.is_queued_for_deletion():
			continue
		if w.data.get("emplacement", false) and w.down_timer <= 0.0 and not w.summoned:
			through.append([_unit_record(w), last + 0.6])
		elif w.down_timer > 0.0:
			left += 1
		w.queue_free()
	if left > 0:
		main.hud.show_message("%d troop%s left behind where %s fell." % [left, "" if left == 1 else "s", "it" if left == 1 else "they"])
	stragglers.clear()
	for e in main.get_enemies():
		if not e.dead and not e.is_queued_for_deletion():
			stragglers.append([e.kind, e.level])
	# Townsfolk still on their way out of here get out.
	for c in townsfolk:
		if is_instance_valid(c):
			freed += 1
			c.queue_free()
	townsfolk.clear()
	var keep_hp: float = standard.hp / standard.max_hp if standard != null and is_instance_valid(standard) else 1.0
	# The room the army goes into it by: its door back to this one (the south door, on the main way).
	var from_id: String = room()["id"] if room_i >= 0 else ""
	var by := "s"
	if march_to >= 0 and march_to < rooms.size():
		var doors: Dictionary = rooms[march_to].get("doors", {})
		for id in doors:
			if str(doors[id]) == from_id:
				by = id
	# The view pans the way the army's going.
	var out := -_inward(march_door["side"])   # (towards the door)
	var size := Vector2(main.FIELD_W, main.FIELD_H)
	var start_pos: Vector2 = main.position
	var tw = main.create_tween()
	tw.tween_property(main, "position", start_pos - out * size, PAN_TIME * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		var coming := through.duplicate()
		through.clear()
		_enter_room(march_to, coming, keep_hp, by)
		main.position = start_pos + out * size)
	tw.tween_property(main, "position", start_pos, PAN_TIME * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Enemies left behind come through the door after the army.
func _stragglers_come() -> void:
	if stragglers.is_empty():
		return
	var door := _door(entry)
	var at := _door_at(door) + _inward(door["side"]) * 20.0
	for st in stragglers:
		main._spawn_enemy(str(st[0]), int(st[1]), main.paths.open_spot(at + Vector2(randf_range(-20, 20), randf_range(-20, 20))))
	main.hud.show_message("%d enem%s followed you through!" % [stragglers.size(), "y" if stragglers.size() == 1 else "ies"])
	stragglers.clear()


func _downed() -> int:
	var n := 0
	for w in main.get_warriors():
		if not w.is_queued_for_deletion() and w.down_timer > 0.0:
			n += 1
	return n


# --- Checkpoints ----------------------------------------------------------------------------

## The army as it comes into the room (before anything's had in it): kept, so a lost battle
## can be taken up again from here.
func checkpoint() -> void:
	if not main.campaign:
		return
	cp_xp = main.battle_xp.duplicate()
	cp_name = room()["name"]
	var army := arrivals.map(func(a):
		var rec: Dictionary = (a[0] as Dictionary).duplicate()
		var k: float = main.FIELD_W / 640.0
		rec["post"] = Vector2(a[2].x / k, a[2].y)
		return rec)
	Campaign.set_checkpoint(Campaign.mission_id, CP_BASE + room_i, {"zone": CP_BASE + room_i, "room": room_i, "entry": entry, "name": cp_name,
			"gold": main.gold, "wave": main.wave, "army": army, "xp": cp_xp, "owned": main.powers.owned.keys(),
			"standard": standard.hp / standard.max_hp if standard != null else 1.0, "rooms": room_state.duplicate(true),
			"freed": freed, "joined": joined, "garrisons": garrisons.duplicate(true), "stragglers": stragglers.duplicate(true)})


func xp_gains(won: bool, gains: Dictionary) -> Dictionary:
	if won or cp_xp.is_empty():
		return gains
	var out := {}
	for kind in gains:
		out[kind] = maxf(0.0, float(gains[kind]) - float(cp_xp.get(kind, 0.0)))
	return out


func checkpoint_name() -> String:
	return cp_name


func _end(won: bool) -> void:
	if over:
		return
	over = true
	if won and main.campaign:
		Campaign.held_towers = garrisons.duplicate(true)
	main.hud.show_message("Through the castle's halls!" if won else "The standard's fallen: the army breaks!")
	main.call_deferred("_finish", won)


# --- What the HUD shows -------------------------------------------------------------------

func status() -> String:
	if room_i < 0 or rooms.is_empty():
		return "Through the Dawn Gate..."
	var main_rooms := rooms.filter(func(r): return int(r.get("waves", 2)) > 0)
	var text: String = room()["name"]
	var place := main_rooms.find(room())
	if place >= 0:
		text += " (hall %d of %d)" % [place + 1, main_rooms.size()]
	if standard != null and is_instance_valid(standard):
		text += "  ·  Standard %d%%" % roundi(standard.hp / standard.max_hp * 100.0)
	if phase == "clear":
		text += "  ·  the way on is open"
	return text


func panel_status() -> String:
	return "Standard %d%%" % roundi(standard.hp / standard.max_hp * 100.0) if standard != null and is_instance_valid(standard) else ""


func summary(won: bool) -> String:
	var s := "Freed %d of Dawnspire's people and %d soldiers." % [freed, joined]
	if not garrisons.is_empty():
		s += "  %d tower%s left manned behind the army." % [garrisons.size(), "" if garrisons.size() == 1 else "s"]
	if won:
		s += "  (The Throne Room is still to come.)"
	return s


## The arrows at the ways on, each named for where it leads, over the field (drawn by an
## ArrowNode while the way's open).
func draw_over(ci: CanvasItem) -> void:
	if phase != "clear":
		return
	var t := Time.get_ticks_msec() / 1000.0
	var font := ThemeDB.fallback_font
	for a in arrows:
		var p := _arrow_point(a)
		var out := -_inward(a["door"]["side"])   # (the arrow points out through the door)
		var c := p + out * sin(t * 4.0) * 5.0
		var seen: bool = _state(str(a["to"]))["cleared"] if str(a["to"]) != "out" else false
		var gold := Color(1.0, 0.85, 0.35) if not seen else Color(0.75, 0.75, 0.7)
		ci.draw_circle(c, 26.0, Color(0, 0, 0, 0.45))
		ci.draw_arc(c, 26.0, 0.0, TAU, 32, Color(gold, 0.9), 2.5, true)
		var side := Vector2(-out.y, out.x)
		var tri := PackedVector2Array([c + out * 16.0, c + side * 15.0 - out * 4.0, c + side * 6.0 - out * 4.0, c + side * 6.0 - out * 15.0,
				c - side * 6.0 - out * 15.0, c - side * 6.0 - out * 4.0, c - side * 15.0 - out * 4.0])
		ci.draw_colored_polygon(tri, gold)
		ci.draw_polyline(tri + PackedVector2Array([tri[0]]), Color(0.25, 0.15, 0.05), 1.5)
		# Where it leads.
		var label := _where(a) + (" (taken)" if seen else "")
		var lp := c - out * 40.0 + Vector2(-90, 4)
		ci.draw_string_outline(font, lp, label, HORIZONTAL_ALIGNMENT_CENTER, 180, 13, 4, Color(0, 0, 0, 0.85))
		ci.draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_CENTER, 180, 13, gold)
