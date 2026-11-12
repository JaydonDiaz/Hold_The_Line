extends RefCounted
## A mixed-army bot for balance runs (Phase 3, stage D5). It fields whatever the battle
## allows (Knights, Archers, Healers, Gold Mines, Cannons, Archer Towers, Medic Bays...),
## posts them where that kind of battle needs them and gives them the orders a player
## would:
##   castle, pass  Knights on the map's chokepoints (its bot_posts) on Guard Area, or on
##                 Hold Position at a bridgehead; Archers behind them on Short Leash; a
##                 Cannon and an Archer Tower behind the line; a Gold Mine at the back
##   positions     defenders shared out between the positions, the nearest to the enemy
##                 first; when one falls its defenders go to the weakest one standing
##   evac          guards along the villagers' roads (Guard Area, objective first), Healers
##                 on Heal so they mend villagers too
##   escort        everyone follows the wagon, Knights guarding a small area round it
##   capture, protect, retreat  a ring in the zone / round the beacon / along the line
## Healers stay with the troops they're posted among. Spare gold goes on upgrades (as far
## as training allows), after the army's filled out.
## The North's units (Phase 4): with Archers locked, Frost Witches (then Alchemists) take
## their places and Frost Towers the Archer Towers', so Slimes and Wyverns can still be
## hurt; with Martial Artists to be had, every other melee slot is one (their first path,
## Spirit, gives them ki blasts that reach fliers); and a Frost Witch, a Bard, a War Statue
## and an Alchemist join the support behind the line when they're allowed.
##
## `style` changes the plan to test other strategies against the mixed army:
##   "mixed" (the default), "knights" (melee only), "ranged" (archers and towers first),
##   "economy" (two mines before anything else).
## Use: var bot = ArmyBot.new(main, "mixed"); then bot.tick() once a second of game time.

const Maps = preload("res://scripts/maps.gd")

const UPGRADE_ORDER := [0, 2, 1, 3]
const MELEE := "swordsman"
const RANGED := "archer"

var main
var style := "mixed"
var type := "castle"
var hired := {}        # kind -> how many the bot has bought
var upgrades := 0
var spent := 0
var ordered := {}      # warrior instance id -> true once it's had its orders
var slots := {}        # plan index -> the unit bought for it (gone or downed for good: bought again)
var waited := 0        # seconds spent saving for the next support unit (after 20, upgrades instead)
var lull := 0          # seconds the wave's last few enemies have held out (see _hunt)
var last_left := -1


func _init(m, s := "mixed") -> void:
	main = m
	style = s
	type = main.mission.get("type", "castle")


func can(kind: String) -> bool:
	return main.allowed(kind)


## What a battle like this calls for, in the order to buy it: [kind, where] pairs.
func plan() -> Array:
	var out := []
	match type:
		"positions":
			out = _plan_positions()
		"evac":
			out = _plan_evac()
		"escort":
			out = _plan_escort()
		"capture":
			out = _plan_ring(main.rules.zone.position, main.rules.zone.zone_r)
		"protect":
			out = _plan_ring(main.rules.objectives()[0].position, 90.0)
		"retreat":
			out = _plan_retreat()
		_:
			out = _plan_line()
	return _restyle(out)


## Swaps kinds the battle doesn't allow (or the style avoids) for ones it does.
func _restyle(out: Array) -> Array:
	var res := []
	for item in out:
		var kind: String = item[0]
		match style:
			"knights":
				if kind in ["archer", "tower", "healer", "medbay", "cannon"]:
					kind = MELEE
			"ranged":
				if kind == MELEE and res.filter(func(r): return r[0] == MELEE).size() >= 2:
					kind = RANGED
		if kind == MELEE and can("martial") and style != "ranged" and res.filter(func(r): return r[0] in [MELEE, "martial"]).size() % 2 == 1:
			kind = "martial"   # every other melee slot
		if not can(kind):
			match kind:
				"archer":
					kind = _first(["frost", "alchemist", MELEE])
				"tower":
					kind = _first(["frosttower", "magetower", MELEE])
				"cannon":
					kind = _first([MELEE])
				"frost", "bard", "statue", "alchemist", "frosttower":
					kind = ""   # (the North's extras: only when they're allowed)
				_:
					kind = ""   # (no Healer, Mine or Medic Bay to be had: just leave it out)
		if kind != "":
			res.append([kind, item[1]])
	return res


## The first of `kinds` the battle allows ("" if none).
func _first(kinds: Array) -> String:
	for k in kinds:
		if can(k):
			return k
	return ""


func _posts() -> Array:
	var map: Dictionary = Maps.get_map(main.mission.get("map", ""))
	if map.has("bot_posts"):
		return Maps.fitted(map, main.FIELD_W)["bot_posts"]
	var out := []
	for i in 7:
		out.append(Vector2(main.FIELD_W * (0.1 + i * 0.8 / 6.0), 470.0 + (i % 2) * 40.0))
	return out


func _back(p: Vector2, dy := 55.0) -> Vector2:
	return Vector2(p.x, minf(p.y + dy, 700.0))


func _economy() -> Array:
	var out := []
	if can("mine"):
		out.append(["mine", Vector2(main.FIELD_W * 0.88, 690)])
		if style == "economy":
			out.append(["mine", Vector2(main.FIELD_W * 0.12, 690)])
	return out


func _plan_line() -> Array:
	var posts := _posts()
	var n := mini(posts.size(), 7)
	var mid := Vector2.ZERO
	for i in n:
		mid += posts[i]
	mid /= maxf(n, 1)
	var out := []
	if style == "economy":
		out += _economy()
	# The first three chokepoints, then a Healer and an Archer behind them, then the rest
	# of the line with Archers behind, then artillery and more support.
	for i in mini(3, n):
		out.append([MELEE, posts[i]])
	out.append(["healer", _back(mid, 70.0)])
	out.append([RANGED, _back(posts[0])])
	for i in range(3, n):
		out.append([MELEE, posts[i]])
		if i - 2 < n:
			out.append([RANGED, _back(posts[i - 2])])
	if style != "economy":
		out += _economy()   # (a mine once the line is up: it pays back over several waves)
	out.append(["cannon", _back(mid, 110.0)])
	out.append(["healer", _back(posts[mini(1, n - 1)], 90.0)])
	out.append(["tower", _back(mid + Vector2(-90, 0), 120.0)])
	for i in range(n - 2, n):
		out.append([RANGED, _back(posts[i])])
	out.append(["medbay", _back(mid + Vector2(90, 0), 140.0)])
	# The North's support, when it's to be had (left out otherwise: see _restyle).
	out.append(["frost", _back(mid + Vector2(40, 0), 80.0)])
	out.append(["bard", _back(mid, 120.0)])
	out.append(["statue", _back(mid + Vector2(-40, 0), 150.0)])
	out.append(["alchemist", _back(posts[mini(2, n - 1)], 70.0)])
	return out


## The positions, nearest the enemy (top of the field) first, each with its share.
func _plan_positions() -> Array:
	var objs: Array = main.rules.standing().duplicate()
	objs.sort_custom(func(a, b): return a.position.y < b.position.y)
	var out := []
	if style == "economy":
		out += _economy()
	for round_ in 3:
		for o in objs:
			var p: Vector2 = o.position
			match round_:
				0:
					out.append([MELEE, p + Vector2(-34, -56)])
				1:
					out.append([RANGED, p + Vector2(0, 46)])
				2:
					out.append([MELEE, p + Vector2(34, -56)])
	if style != "economy":
		out += _economy()
	var mid := Vector2.ZERO
	for o in objs:
		mid += o.position
	mid /= maxf(objs.size(), 1)
	out.append(["healer", mid + Vector2(0, 40)])
	out.append(["cannon", mid + Vector2(0, 80)])
	for o in objs:
		out.append([RANGED, o.position + Vector2(-50, 30)])
	out.append(["tower", mid + Vector2(-60, 90)])
	return out


## Guards at the middle and the end of each road the villagers come down.
func _plan_evac() -> Array:
	var routes: Array = main.mission["evac"]["routes"]
	var k: float = main.FIELD_W / 640.0
	var out := []
	for stage in 3:
		for route in routes:
			var r: Array = route
			var i: int = clampi([1, 2, r.size() - 2][stage], 0, r.size() - 1)
			var p: Vector2 = r[i] * Vector2(k, 1.0)
			match stage:
				0:
					out.append([MELEE, p + Vector2(0, 20)])
				1:
					out.append([RANGED, p + Vector2(30, 30)])
				2:
					out.append([MELEE, p + Vector2(-30, 10)])
	var end_: Vector2 = (routes[0] as Array)[-1] * Vector2(k, 1.0)
	out.append(["healer", end_ + Vector2(0, -120)])
	out += _economy()
	for route in routes:
		var r: Array = route
		out.append([RANGED, r[mini(3, r.size() - 2)] * Vector2(k, 1.0) + Vector2(-30, 20)])
	out.append(["healer", ((routes[0] as Array)[2]) * Vector2(k, 1.0) + Vector2(20, 40)])
	return out


## A ring round the wagon: Knights out in front (up the road), Archers close in.
func _plan_escort() -> Array:
	var w: Vector2 = main.rules.wagon.position
	var out := []
	for i in 4:
		out.append([MELEE, w + Vector2.from_angle(-PI / 2.0 + (i - 1.5) * 0.7) * 75.0])
	for i in 3:
		out.append([RANGED, w + Vector2.from_angle(PI / 2.0 + (i - 1) * 0.8) * 50.0])
	out.append(["healer", w + Vector2(0, 45)])
	for i in 2:
		out.append([MELEE, w + Vector2.from_angle(PI / 2.0 + (i - 0.5) * 1.6) * 75.0])
	out.append([RANGED, w + Vector2(-60, 0)])
	out.append([RANGED, w + Vector2(60, 0)])
	return out


func _plan_ring(c: Vector2, r: float) -> Array:
	var out := []
	for i in 10:
		var kind := MELEE if i % 2 == 0 else RANGED
		out.append([kind, c + Vector2.from_angle(-PI / 2.0 + (i - 4.5) * 0.5) * (r * (0.9 if kind == MELEE else 0.55))])
	out.insert(4, ["healer", c + Vector2(0, r * 0.3)])
	out += _economy()
	return out


func _plan_retreat() -> Array:
	var r = main.rules
	var y := 280.0
	if r.phase > 0:
		y = (float(r.lines()[mini(r.phase, r.lines().size() - 1)]["y"]) + 30.0) if r.phase < r.lines().size() else 700.0
	var out := []
	for i in 5:
		var x: float = main.FIELD_W * (0.2 + i * 0.15)
		out.append([MELEE, Vector2(x, y)])
		out.append([RANGED, Vector2(x + 20, y + 50)])
	out.insert(4, ["healer", Vector2(main.FIELD_W * 0.5, y + 70)])
	return out


# --- Each second ----------------------------------------------------------------------

func tick() -> void:
	if main.game_over:
		return
	_repair()
	_fill()
	_orders()
	_react()
	_upgrade()
	main.selected = null


func _repair() -> void:
	if not main.rules.has_castle() or not main.allowed("repair") or main.wave_active:
		return
	if main.castle_hp < main.castle_max * 0.6:
		for i in [2, 1, 0]:
			if main.can_repair(i):
				main.repair_castle(i)
				return


## Whether plan slot i has its unit (still on the field: a downed one may be revived).
func _filled(i: int) -> bool:
	return slots.has(i) and is_instance_valid(slots[i]) and slots[i].is_target()


## Buys what the plan calls for, slot by slot. Loaned units count for the first slots
## of their kind.
func _fill() -> void:
	var items := plan()
	if slots.is_empty():
		var lent: Array = main.temp_allies.filter(func(w): return is_instance_valid(w))
		for i in items.size():
			for w in lent:
				if w.kind == items[i][0]:
					slots[i] = w
					lent.erase(w)
					break
	for i in items.size():
		var kind: String = items[i][0]
		var at: Vector2 = main._clamp_post(items[i][1])
		if not main.can_post_at(at):
			at = main._clamp_post(main.paths.open_spot(at))
		if _filled(i):
			continue
		if main.gold < main.hire_cost(kind):
			if _core(kind):
				return   # (the line comes first: save for it rather than skip ahead)
			continue     # (support and buildings: buy them when there's gold to spare)
		if not main.can_post_at(at):
			continue
		var before: int = main.gold
		var count: int = main.warrior_layer.get_child_count()
		main._on_hire_pressed(kind)
		main.hire_at(at)
		main.placing_type = ""
		if main.gold < before:
			hired[kind] = hired.get(kind, 0) + 1
			spent += before - main.gold
			if main.warrior_layer.get_child_count() > count:
				slots[i] = main.warrior_layer.get_child(main.warrior_layer.get_child_count() - 1)


## Orders for whoever hasn't had them yet (see the top of the file).
func _orders() -> void:
	var troops: Array = main.get_warriors().filter(func(w): return w.is_active() and not w.is_emplacement() and not w.wall_guard)
	var fresh := troops.filter(func(w): return not ordered.has(w.get_instance_id()))
	if fresh.is_empty():
		return
	var bridgeheads := []
	if type == "pass":
		bridgeheads = _posts().slice(0, 3)
	for w in fresh:
		ordered[w.get_instance_id()] = true
		if w.is_mobile_healer():
			continue
		if type == "escort":
			continue
		if w.kind in [RANGED, "alchemist", "mage", "frost", "bard"]:
			_guard([w], 80.0)
		elif bridgeheads.any(func(p): return p.distance_to(w.post) < 30.0):
			main.give_order("move_mode", "hold", [w])
		else:
			_guard([w], 170.0 if type == "evac" else 130.0)
	if type == "escort":
		var loose := troops.filter(func(w): return w.anchor == null and not w.is_mobile_healer())
		if not loose.is_empty():
			main.set_follow(main.rules.wagon, loose)
			_guard(loose, 70.0)
	# Healers: on Heal in an evacuation (villagers too), else staying with the troops near them.
	for h in fresh.filter(func(w): return w.is_mobile_healer()):
		if type == "evac":
			main.give_order("priority", "heal", [h])
			continue
		var near := troops.filter(func(w): return not w.is_mobile_healer() and w.post.distance_to(h.post) < 220.0)
		if near.is_empty():
			near = troops.filter(func(w): return not w.is_mobile_healer())
		if not near.is_empty():
			main.stay_with([h], near.slice(0, 4))


## The battle's own calls: fall back when it's time; when a position falls, its
## defenders go to the weakest one still standing.
func _react() -> void:
	if main.rules.action_label() != "":
		main.rules.action()
	_hunt()
	if type == "positions":
		var standing: Array = main.rules.standing()
		if standing.is_empty():
			return
		for o in main.rules.objectives():
			if not o.dead:
				continue
			for w in main.get_warriors():
				if w.is_active() and not w.is_emplacement() and w.post.distance_to(o.position) < 110.0:
					var weakest = standing[0]
					for s in standing:
						if s.hp / s.max_hp < weakest.hp / weakest.max_hp:
							weakest = s
					var to: Vector2 = main.paths.open_spot(main._clamp_post(weakest.position + Vector2(randf_range(-50, 50), -50)))
					w.order_to(to)


## A player sends someone after the last few enemies of a wave when they hang about out of
## everyone's reach (shooting from afar, or hacking at something that's being mended): the
## nearest troops are moved onto them.
func _hunt() -> void:
	var left: Array = main.get_enemies()
	if not main.wave_active or left.size() > 3 or not main.spawn_queue.is_empty() or left.is_empty():
		lull = 0
		last_left = -1
		return
	lull = lull + 1 if left.size() == last_left else 0
	last_left = left.size()
	if lull < 20:
		return
	lull = 0
	for e in left:
		var best = null
		for w in main.get_warriors():
			if w.is_active() and not w.is_emplacement() and not w.is_mobile_healer() and w.anchor == null \
					and (best == null or w.position.distance_to(e.position) < best.position.distance_to(e.position)):
				best = w
		if best != null:
			best.order_to(main.paths.open_spot(main._clamp_post(e.position)))


## Spends what's left on upgrades: the line first, then the rest, keeping enough back to
## replace a fallen Knight while the plan still has gaps.
func _upgrade() -> void:
	var keep := 0
	var items := plan()
	var support_seen := false
	for i in items.size():
		if _filled(i):
			continue
		var core: bool = _core(items[i][0])
		if core:
			keep = maxi(keep, main.hire_cost(items[i][0]))   # always save for the line
			break
		if not support_seen:
			support_seen = true
			if waited < 20:
				keep = main.hire_cost(items[i][0])
			waited = 0 if main.gold >= main.hire_cost(items[i][0]) else waited + 1
	var spent_any := true
	while spent_any:
		spent_any = false
		var units: Array = main.get_warriors().filter(func(w): return w.is_active() and not w.wall_guard)
		units.sort_custom(func(a, b): return (a.kind == MELEE) and not (b.kind == MELEE))
		for w in units:
			for path in UPGRADE_ORDER:
				if w.path_state(path) != "ok":
					continue
				var cost: int = w.upgrade_cost(path)
				if main.gold - cost < keep:
					continue
				main.selected = w
				var before: int = main.gold
				main.upgrade_selected(path)
				if main.gold < before:
					upgrades += 1
					spent += before - main.gold
					spent_any = true
				break


## A line summing up the army: "swordsman 7, archer 4, healer 1 | 23 upgrades".
func army() -> String:
	var counts := {}
	for w in main.get_warriors():
		if w.is_active() and not w.wall_guard:
			counts[w.kind] = counts.get(w.kind, 0) + 1
	var parts := []
	for k in counts:
		parts.append("%s %d" % [k, counts[k]])
	return ", ".join(parts) + " | %d upgrades" % upgrades


## Guard Area: a square `half` out each way from each unit's post (as the old circle was).
func _guard(units: Array, half: float) -> void:
	for w in units:
		main.give_order("area", Rect2(w.post - Vector2.ONE * half, Vector2.ONE * half * 2.0), [w])


## The line itself (bought before support): melee and ranged troops, the North's included.
func _core(kind: String) -> bool:
	return kind in [MELEE, RANGED, "martial", "frost"]
