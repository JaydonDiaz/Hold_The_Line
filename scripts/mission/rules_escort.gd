extends "res://scripts/mission/rules.gd"
## Convoy Escort: a wagon (supplies, ore) travels a long road, and the enemy means to stop
## it. The road runs through zones, one field each (a meadow, a dark wood, a mountain
## pass): the wagon comes in at the bottom and rolls up the field, and when it leaves by
## the top, the march moves on into the next zone: the field changes to it, and your
## troops (and emplacements, packed up and set up again) come along, in their places
## around the wagon. Enemies left behind stay behind; barricades are taken down and paid
## back; the wagon is patched up a little. In each zone, ambushes break out of cover as the wagon passes set points, and
## more keep coming. The wagon crawls while an enemy is at it, and picks up again once
## it's clear. Get it out of the last zone. Your camp travels with it: new troops join at the
## wagon and the Engineers set out from it. Troops can be told to follow the wagon (J, or
## right-click it). The attacks come at a forced pace. No castle.
##
## Mission data: "type": "escort", "convoy": {"name", "speed", "hp", "patch": share of its
##   health mended between zones (default 0.25),
##   "zones": [{"map": a zone (maps.gd ZONES: its ground, terrain and road), "name",
##     "ambushes": [{"at": share of that zone's road (0..1), "note", "group": [[kind, point], ...]}]}]}
## Endless: the road never ends. After the last zone it goes round them again (each time
## round, every ambush brings a few more), until the wagon is lost.
## Points are as drawn up, 640 wide. The mission's "map" is the first zone's. (Without
## "zones": one zone, its "route" and "ambushes" given in "convoy" itself.)

const Objective = preload("res://scripts/mission/objective.gd")
const Maps = preload("res://scripts/maps.gd")
const SETTLE := 6.0   # seconds to get set in a new zone before the wagon rolls on

var wagon
var zone_i := 0          # the zone the wagon's in (endless: counting on past the last, round again)
var sprung := 0          # ambushes already set off in this zone
var road_len := 0.0      # this zone's road
var over := false
var moving_on := false   # between zones (the field is changing)
var settle := 0.0        # seconds left before the wagon sets off in a new zone
var wagon_speed := 0.0


func has_castle() -> bool:
	return false


func show_camp() -> bool:
	return false   # the camp is on the wagon


func guards() -> bool:
	return true


func objective_only() -> bool:
	return true


func _c() -> Dictionary:
	return mission.get("convoy", {})


## The zones of the road, each {"map", "name", "route", "ambushes"}.
func zones() -> Array:
	var c := _c()
	if not c.has("zones"):
		return [{"map": mission.get("map", ""), "name": "", "route": c.get("route", [Vector2(60, 700), Vector2(580, 100)]),
				"ambushes": c.get("ambushes", [])}]
	var out := []
	for z in c["zones"]:
		var m: Dictionary = Maps.get_map(z.get("map", ""))
		out.append({"map": z.get("map", ""), "name": z.get("name", m.get("name", "")), "route": z.get("route", m.get("route", [])),
				"ambushes": z.get("ambushes", [])})
	return out


func zone() -> Dictionary:
	return zones()[zone_i % zones().size()]


## How many times round the zones the road has been (endless).
func loop() -> int:
	return zone_i / zones().size()


func start() -> void:
	var route: Array = _entry_route(zone()["route"])
	wagon_speed = float(_c().get("speed", 22.0))
	wagon = Objective.new()
	wagon.setup(main, {"id": "wagon", "kind": "wagon", "name": _c().get("name", "Wagon"), "at": route[0], "route": route.slice(1),
			"speed": wagon_speed, "hp": _c().get("hp", 900.0)})
	main.add_objective(wagon)
	wagon.destroyed.connect(func(_w): _end(false))
	wagon.reached.connect(_on_reached)
	_measure()


## A zone's road, starting just inside the bottom of the field (so the wagon's in sight).
func _entry_route(route: Array) -> Array:
	var out := route.duplicate()
	if not out.is_empty() and out[0].y > main.CASTLE_Y - 30.0:
		out[0] = Vector2(out[0].x, main.CASTLE_Y - 30.0)
	return out


func _measure() -> void:
	road_len = 0.0
	for i in range(1, wagon.route.size()):
		road_len += wagon.route[i - 1].distance_to(wagon.route[i])
	road_len += wagon.position.distance_to(wagon.route[0]) if not wagon.route.is_empty() else 0.0


func _on_reached(_w) -> void:
	if endless() or zone_i + 1 < zones().size():
		call_deferred("_move_on")
	else:
		_end(true)


func _end(won: bool) -> void:
	if over:
		return
	over = true
	main.hud.show_message("The %s made it through!" % wagon.label.to_lower() if won else "The %s is lost!" % wagon.label.to_lower())
	main.call_deferred("_finish", won)


## Out of the top of this zone and into the next: the screen goes dark, the field turns
## into the next zone, and everything of yours comes along.
func _move_on() -> void:
	if over or moving_on or main.game_over:
		return
	moving_on = true
	main.hud.show_message("On the road...")
	main.hud.fade_through_black(enter_next)


func enter_next() -> void:
	if over or main.game_over:
		moving_on = false
		return
	var left_at: Vector2 = wagon.position
	zone_i += 1
	sprung = 0
	var z := zone()
	change_field(z["map"])   # enemies left behind, and the new ground
	main.audio.prepare(main.Audio.battle_for(Maps.get_map(zones()[(zone_i + 1) % zones().size()]["map"])))   # (the next stretch's music, ready in time)
	# The wagon at the bottom of it, on its road.
	var k: float = main.FIELD_W / 640.0
	var route: Array = _entry_route(z["route"])
	wagon.position = Vector2(route[0].x * k, route[0].y)
	wagon.route = PackedVector2Array(route.slice(1).map(func(p): return Vector2(p.x * k, p.y)))
	wagon.leg = 0
	wagon.arrived = false
	wagon.halted = false
	var mend: float = minf(wagon.max_hp * float(_c().get("patch", 0.25)), wagon.max_hp - wagon.hp)
	wagon.hp += mend
	_measure()
	# Everything of yours comes along, keeping its place around the wagon (as near as the
	# new ground allows). Barricades are taken down, and paid back.
	var shift: Vector2 = wagon.position - left_at
	var refund := 0
	for b in main.get_barricades():
		refund += int(b.spent)
		b.queue_free()
	if refund > 0:
		main.gold += refund
	main.walls_changed()
	for w in main.warrior_layer.get_children():
		if w.is_queued_for_deletion():
			continue
		var p: Vector2 = main.paths.open_spot(main._clamp_post(w.position + shift))
		w.position = p
		w.post = p
		w.fitted_post = Vector2.INF
		w.route = PackedVector2Array()
		w.target = null
	for n in main.fx_layer.get_children():
		if n.has_method("gate"):
			n.position = main._clamp_post(n.position + shift)
	main.warriors_changed()
	main.paths.invalidate()
	# A moment to get set, then on.
	wagon.speed = 0.0
	settle = SETTLE
	moving_on = false
	main.hud.show_message("%s (%s)%s%s" % [z["name"], "stretch %d" % (zone_i + 1) if endless() else "%d of %d" % [zone_i + 1, zones().size()],
			"  ·  the %s patched up (+%d%%)" % [wagon.label.to_lower(), roundi(mend / wagon.max_hp * 100.0)] if mend >= 1.0 else "",
			"  ·  barricades taken down: %dg back" % refund if refund > 0 else ""])
	main.sfx("horn")


func objectives() -> Array:
	return [wagon] if wagon != null else []


## How far along the whole road the wagon is (0..1): zones done, and this one's share.
func along() -> float:
	return (zone_i + zone_along()) / float(zones().size())


## How far along this zone's road the wagon is (0..1).
func zone_along() -> float:
	if wagon == null or road_len <= 0.0:
		return 0.0
	var left := 0.0
	var at: Vector2 = wagon.position
	for i in range(wagon.leg, wagon.route.size()):
		left += at.distance_to(wagon.route[i])
		at = wagon.route[i]
	return clampf(1.0 - left / road_len, 0.0, 1.0)


func process(delta: float) -> void:
	if over or main.game_over or main.deploying or wagon == null or moving_on:
		return
	if settle > 0.0:
		settle -= delta
		if settle <= 0.0:
			wagon.speed = wagon_speed
			main.hud.show_message("The %s rolls on" % wagon.label.to_lower())
		return
	if wagon.speed > 0.0 and wagon.leg == 0 and not main.started:
		return
	var ambushes: Array = zone()["ambushes"]
	while sprung < ambushes.size() and zone_along() >= float(ambushes[sprung]["at"]):
		var a: Dictionary = ambushes[sprung]
		sprung += 1
		var k: float = main.FIELD_W / 640.0
		var group: Array = a.get("group", [])
		for i in group.size() + mini(loop() * 2, group.size() * 2):
			var g: Array = group[i % group.size()]
			var p: Vector2 = Vector2(g[1].x * k, g[1].y)
			if i >= group.size():   # (more each time round, close by)
				p = main._clamp_post(p + Vector2(randf_range(-30, 30), randf_range(-24, 24)))
			main._spawn_enemy(g[0], main.wave_level(maxi(main.wave, 1)), p)
		main.hud.show_message(a.get("note", "Ambush!"))
		main.sfx("horn")


## The enemy is out for the wagon.
func enemy_goal(_e):
	return wagon if wagon != null and wagon.is_target() else null


func entry_point(_post: Vector2) -> Vector2:
	if wagon == null or not wagon.is_target():
		return Vector2.INF
	return main._clamp_post(wagon.position + Vector2(0, 26))


func on_reached_bottom(_e) -> bool:
	return true


func wave_cleared(_n: int) -> bool:
	return false


func wave_text() -> String:
	return "Wave %d" % main.wave


func status() -> String:
	if wagon == null:
		return ""
	var where := ""
	var text := ""
	if endless():
		text = "%s (stretch %d)  ·  %s: %d%% through  ·  health %d%%" % [zone()["name"], zone_i + 1, wagon.label, roundi(zone_along() * 100.0),
				roundi(wagon.hp / wagon.max_hp * 100.0)]
	else:
		if zones().size() > 1:
			where = "%s (%d of %d)  ·  " % [zone()["name"], zone_i + 1, zones().size()]
		text = "%s%s: %d%% of the way  ·  health %d%%" % [where, wagon.label, roundi(along() * 100.0), roundi(wagon.hp / wagon.max_hp * 100.0)]
	if settle > 0.0:
		text += "  ·  sets off in %ds" % ceili(settle)
	elif wagon.halted:
		text += "  ·  under attack: slowed!"
	return text


func panel_status() -> String:
	if endless():
		return "Wagon %d%%" % roundi(wagon.hp / wagon.max_hp * 100.0) if wagon != null else ""
	return "Road %d%%" % roundi(along() * 100.0)


func score() -> int:
	return roundi(wagon.hp / wagon.max_hp * 100.0) if wagon != null else 0


func score_text(s: int) -> String:
	return "arrived with %d%% health" % s


func summary(won: bool) -> String:
	if endless():
		return "The %s was lost on stretch %d, in %s." % [wagon.label.to_lower(), zone_i + 1, zone()["name"]]
	return ("The %s arrived with %d%% of its health." % [wagon.label.to_lower(), score()]) if won else "The %s was destroyed %d%% of the way along." % [wagon.label.to_lower(), roundi(along() * 100.0)]
