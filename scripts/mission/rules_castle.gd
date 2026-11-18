extends "res://scripts/mission/rules.gd"
## The Liberation of Dawnspire, inside the walls (Phase 5, F3): the army fights its way
## through the citadel room by room. It carries on the assault (rules_assault.gd hands over
## once the Dawn Gate's field is clear) as the same operation: the same army, gold,
## checkpoints and towers held behind it.
##
## A room (a "hall" map: castle_art.gd) has walls all round with doors in them. The army
## comes in at one and plants the Line's standard by it: that's what the enemy goes for here,
## and if it falls the army breaks (the battle's lost). The room's garrison holds its posts
## until the army's close; then the room's waves come in through its far door. Once they're
## beaten (and nobody's down, or LINGER seconds after the last one came in, whatever's
## left), an arrow shows at each door the army can go on by. Clicking one (or Y, for the way
## on) gives the order: the troops make for that door, the view pans through to the room
## beyond as the first of them gets there, and they come in at its near door when each
## would have got there, walking on to where they stood in the last room (as near as this
## one allows). Emplacements are taken down and hauled through after them, set up again;
## barricades are taken down and paid back; troops still down are left where they fell.
## Every room is a checkpoint (Campaign.op_state, at 100 + the room's place): the battle can
## be taken up again as the army stood when it came in. Taken up with too little left to
## win with (army and gold worth less than the castle's "reserve"), reserves come up from
## the gate to make it up to that, once per try, so a bad checkpoint can't trap the player.
## Nothing that's been taken (supplies, freed prisoners) is had twice: the checkpoint's
## gold and army are as they were when the room was entered.
##
## Mission data: "assault": {"castle": {"reserve": gold, "standard": hp,
##   "rooms": [{"id", "map", "name", "note", "waves": how many come in,
##     "garrison": [[kind, at], ...], "doors": {door id: room id, or "out" to finish}}]}}

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

var rooms: Array = []
var room_i := 0
var phase := "enter"          # "enter" (coming in), "fight", "clear" (a way on open), "march" (going), "pan"
var wave0 := 0                # main.wave when this room was entered
var linger := 0.0
var standard = null
var arrows: Array = []        # [{"door", "at", "dir"}] the ways on once the room's taken
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


func has_castle() -> bool:
	return false


func show_camp() -> bool:
	return false


func endless() -> bool:
	return false


func side_objectives() -> bool:
	return false


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
	_march_to({"id": "gate", "side": "n", "at": gate_at}, 0)


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
	_enter_room(room_i, army.map(func(r): return [r, 0.0]), float(cp.get("standard", 1.0)), true)
	main.hud.show_message("Taken up again from %s." % cp_name)


# --- A room ---------------------------------------------------------------------------------

## Into room `i`: its ground, the standard planted by the door the army came in by, its
## garrison out, and the army coming in (each [record, seconds after the first]).
func _enter_room(i: int, coming: Array, standard_hp: float, restored := false) -> void:
	room_i = i
	var r := room()
	change_field(r["map"])
	var k: float = main.FIELD_W / 640.0
	var door := _door("s")
	var at: Vector2 = Vector2(door["at"].x * k, door["at"].y)
	# The standard, a little in from the door.
	if standard == null or not is_instance_valid(standard):
		standard = Works.new()
		standard.setup(main, {"id": "standard", "kind": "standard", "name": "The Line's standard", "at": at + Vector2(-60 * k, -70),
				"hp": float(_c().get("standard", 900.0))})
		main.add_objective(standard)
		standard.destroyed.connect(func(_o): _end(false))
	standard.position = main.paths.open_spot(at + Vector2(-60 * k, -70))
	standard.hp = standard.max_hp * clampf(standard_hp, 0.05, 1.0)
	main.paths.set_objectives(objectives())
	# The garrison at its posts.
	for g in r.get("garrison", []):
		main._spawn_enemy(g[0], main.wave_level(maxi(main.wave, 1)), Vector2(g[1].x * k, g[1].y))
		var e = main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)
		e.set_meta("guard", true)
		e.goal = null
	# The army, as it comes in.
	arrivals.clear()
	arrive_t = 0.0
	var c_old := Vector2.ZERO
	for row in coming:
		c_old += row[0].get("post", Vector2(320, 600))
	c_old /= maxf(coming.size(), 1)
	var c_new: Vector2 = Vector2(door["stand"].x * k, door["stand"].y) if door.has("stand") else at + Vector2(0, -ENTRY_DEPTH)   # (where the army's middle comes to stand)
	for row in coming:
		var rec: Dictionary = row[0]
		var p: Vector2 = rec.get("post", c_old)
		var post: Vector2 = c_new + Vector2((p.x - c_old.x) * k * 0.85, (p.y - c_old.y) * 0.7) if not restored else Vector2(p.x * k, p.y)
		post = Vector2(clampf(post.x, 50.0 * k, main.FIELD_W - 50.0 * k), clampf(post.y, 380.0, 720.0))
		arrivals.append([rec, float(row[1]), main.paths.open_spot(main._clamp_post(post))])
	arrivals.sort_custom(func(a, b): return a[1] < b[1])
	restored_entry = restored
	wave0 = main.wave
	linger = 0.0
	arrows.clear()
	phase = "enter"
	if r.get("note", "") != "":
		main.hud.show_message(r["note"])
	if not restored:
		checkpoint()


func _door(id: String) -> Dictionary:
	for d in Maps.get_map(room()["map"]).get("doors", []):
		if d["id"] == id:
			return d
	return {"id": id, "side": id, "at": Vector2(320, 756 if id == "s" else 22)}


## A unit back on the field: at the door, walking on to its place.
func _arrive(rec: Dictionary, post: Vector2, at_post := false) -> void:
	var k: float = main.FIELD_W / 640.0
	var door := _door("s")
	var at := Vector2(door["at"].x * k + randf_range(-10, 10), door["at"].y - 6.0)
	var w = _make_unit(rec)
	if w == null:
		return
	if w.data.get("emplacement", false) or at_post:
		w.post = post   # (hauled in and set up again where it's to stand; or taken up again where it stood)
		w.position = post
	else:
		w.position = at
		w.order_to(post)
	main.warriors_changed()


func objectives() -> Array:
	return [standard] if standard != null and is_instance_valid(standard) and not standard.dead else NONE


func enemy_goal(e):
	if e != null and e.has_meta("guard") and not _awake():
		return null
	return standard if standard != null and is_instance_valid(standard) and standard.is_target() else null


## The garrison wakes once a troop's near, or the room's waves have begun.
var _woke := false
func _awake() -> bool:
	if _woke:
		return true
	if main.wave > wave0:
		_woke = true
		return true
	for e in main.get_enemies():
		if e.has_meta("guard") and not main.warriors_near(e.position, WAKE).filter(func(w): return w.is_active() and not w.is_emplacement()).is_empty():
			_woke = true
			return true
	return false


func wait_y() -> float:
	return 0.0


func on_reached_bottom(_e) -> bool:
	return true


func holds_waves() -> bool:
	return phase != "fight" or main.wave - wave0 >= int(room().get("waves", 2))


func waves_done_here() -> bool:
	return phase == "fight" and main.wave - wave0 >= int(room().get("waves", 2)) or phase == "clear"


func wave_cleared(_n: int) -> bool:
	return false


func wave_text() -> String:
	if room_i < 0 or rooms.is_empty():
		return ""
	if phase != "fight":
		return "Room %d/%d" % [room_i + 1, rooms.size()]
	return "Wave %d/%d" % [clampi(main.wave - wave0, 0, int(room().get("waves", 2))), int(room().get("waves", 2))]


func process(delta: float) -> void:
	if over or main.game_over:
		return
	match phase:
		"enter":
			arrive_t += delta
			while not arrivals.is_empty() and arrivals[0][1] <= arrive_t:
				var a: Array = arrivals.pop_front()
				_arrive(a[0], a[2], restored_entry)
			if arrivals.is_empty():
				phase = "fight"
				_woke = false
				_stragglers_come()
		"fight":
			var done: bool = main.wave - wave0 >= int(room().get("waves", 2)) and main.spawn_queue.is_empty()
			if done and main.get_enemies().is_empty() and _downed() == 0:
				_room_taken()
			elif done:
				linger += delta
				if linger >= LINGER:
					_room_taken()
		"march":
			_march_step(delta)


## The room's taken (or nothing more is coming): the ways on show.
func _room_taken() -> void:
	phase = "clear"
	arrows.clear()
	if arrow_node == null or not is_instance_valid(arrow_node):
		arrow_node = ArrowNode.new()
		arrow_node.rules = self
		arrow_node.z_index = 50
		main.add_child(arrow_node)
	var k: float = main.FIELD_W / 640.0
	for d in Maps.get_map(room()["map"]).get("doors", []):
		var to: String = str(room().get("doors", {}).get(d["id"], ""))
		if to == "":
			continue
		arrows.append({"door": d, "at": Vector2(d["at"].x * k, d["at"].y), "to": to})
	main.hud.show_message("%s is yours. On through the door when you're ready (click its arrow, or Y)." % room()["name"])
	main.sfx("horn", 1.2)
	main.queue_redraw()


func action_label() -> String:
	if phase != "clear" or arrows.is_empty():
		return ""
	return "On through the door"


func action() -> void:
	if action_label() != "":
		_ask(arrows[0])


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
	return a["at"] + (Vector2(0, 46) if a["door"]["side"] == "n" else Vector2(0, -46))


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
	var to := str(a["to"])
	var where: String = "out of the castle's first halls" if to == "out" else _room_named(to)
	if notes.is_empty():
		_go(a)
		return
	main.hud.show_choice("On to %s?" % where, "\n\n".join(notes), [["Go on", func(): _go(a)], ["Not yet", null]])


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
	var k: float = main.FIELD_W / 640.0
	var at: Vector2 = Vector2(door["at"].x * k, door["at"].y) if door["id"] != "gate" else door["at"]
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
		w.order_to(main._clamp_post(at + Vector2(randf_range(-14, 14), 0)))
		w.move_mode = "free"
		march_units.append(w)
	main.hud.show_message("On through the door!")


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


## A marching troop's record: as it stood before the march, with the health it has now.
func _record(w) -> Dictionary:
	var rec: Dictionary = orders.get(w.get_instance_id(), _unit_record(w)).duplicate()
	rec["hp"] = w.hp / maxf(w.max_hp, 1.0)
	return rec


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
	var keep_hp: float = standard.hp / standard.max_hp if standard != null and is_instance_valid(standard) else 1.0
	var dir := -1.0 if march_door["side"] == "n" else 1.0
	var start_pos: Vector2 = main.position
	var tw = main.create_tween()
	tw.tween_property(main, "position", start_pos + Vector2(0, -dir * main.FIELD_H), PAN_TIME * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		var coming := through.duplicate()
		through.clear()
		_enter_room(march_to, coming, keep_hp)
		main.position = start_pos + Vector2(0, dir * main.FIELD_H))
	tw.tween_property(main, "position", start_pos, PAN_TIME * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _stragglers_come() -> void:
	for st in stragglers:
		main._spawn_enemy(str(st[0]), int(st[1]))
	if not stragglers.is_empty():
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
	Campaign.set_checkpoint(Campaign.mission_id, CP_BASE + room_i, {"zone": CP_BASE + room_i, "room": room_i, "name": cp_name,
			"gold": main.gold, "wave": main.wave, "army": army, "xp": cp_xp, "owned": main.powers.owned.keys(),
			"standard": standard.hp / standard.max_hp if standard != null else 1.0,
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
	main.hud.show_message("Through the castle's first halls!" if won else "The standard's fallen: the army breaks!")
	main.call_deferred("_finish", won)


# --- What the HUD shows -------------------------------------------------------------------

func status() -> String:
	if room_i < 0 or rooms.is_empty():
		return "Through the Dawn Gate..."
	var text := "%s (room %d of %d)" % [room()["name"], room_i + 1, rooms.size()]
	if standard != null and is_instance_valid(standard):
		text += "  ·  Standard %d%%" % roundi(standard.hp / standard.max_hp * 100.0)
	if phase == "clear":
		text += "  ·  the way on is open"
	return text


func panel_status() -> String:
	return "Standard %d%%" % roundi(standard.hp / standard.max_hp * 100.0) if standard != null and is_instance_valid(standard) else ""


## The standard's an objective: guard it.
func guards() -> bool:
	return true


func summary(won: bool) -> String:
	var s := "Freed %d of Dawnspire's people and %d soldiers." % [freed, joined]
	if not garrisons.is_empty():
		s += "  %d tower%s left manned behind the army." % [garrisons.size(), "" if garrisons.size() == 1 else "s"]
	if won:
		s += "  (The citadel's deeper halls are still to come.)"
	return s


## The arrows at the ways on, over the field (drawn by an ArrowNode while the way's open).
func draw_over(ci: CanvasItem) -> void:
	if phase != "clear":
		return
	var t := Time.get_ticks_msec() / 1000.0
	for a in arrows:
		var p := _arrow_point(a)
		var up: bool = a["door"]["side"] == "n"
		var bob := sin(t * 4.0) * 5.0 * (-1.0 if up else 1.0)
		var c := p + Vector2(0, bob)
		ci.draw_circle(c, 26.0, Color(0, 0, 0, 0.45))
		ci.draw_arc(c, 26.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.35, 0.9), 2.5, true)
		var s := 1.0 if up else -1.0   # (the point towards the door)
		var tri := PackedVector2Array([c + Vector2(0, -16 * s), c + Vector2(15, 4 * s), c + Vector2(6, 4 * s), c + Vector2(6, 15 * s),
				c + Vector2(-6, 15 * s), c + Vector2(-6, 4 * s), c + Vector2(-15, 4 * s)])
		ci.draw_colored_polygon(tri, Color(1.0, 0.85, 0.35))
		ci.draw_polyline(tri + PackedVector2Array([tri[0]]), Color(0.25, 0.15, 0.05), 1.5)
