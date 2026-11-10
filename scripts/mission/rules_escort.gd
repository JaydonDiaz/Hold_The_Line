extends "res://scripts/mission/rules.gd"
## Convoy Escort: a wagon (supplies, ore) crosses the field along a road, and the enemy
## means to stop it: ambushes break out of cover as it passes set points on the road, and
## more keep coming. The wagon halts while an enemy is at it, and goes on once it's clear.
## Get it to the end of the road. Your camp travels with it: new troops join at the wagon
## and the Engineers set out from it. Troops can be told to follow the wagon (J, or
## right-click it). The attacks come at a forced pace. No castle.
##
## Mission data: "type": "escort", "convoy": {"name", "route": [points] (as drawn up, 640
##   wide; it starts at the first), "speed", "hp",
##   "ambushes": [{"at": share of the road (0..1), "note", "group": [[kind, point], ...]}]}

const Objective = preload("res://scripts/mission/objective.gd")

var wagon
var sprung := 0          # ambushes already set off
var road_len := 0.0
var over := false


func has_castle() -> bool:
	return false


func show_camp() -> bool:
	return false   # the camp is on the wagon


func _c() -> Dictionary:
	return mission.get("convoy", {})


func start() -> void:
	var route: Array = _c().get("route", [Vector2(60, 700), Vector2(580, 100)])
	wagon = Objective.new()
	wagon.setup(main, {"id": "wagon", "kind": "wagon", "name": _c().get("name", "Wagon"), "at": route[0], "route": route.slice(1),
			"speed": _c().get("speed", 22.0), "hp": _c().get("hp", 900.0)})
	main.add_objective(wagon)
	wagon.destroyed.connect(func(_w): _end(false))
	wagon.reached.connect(func(_w): _end(true))
	for i in range(1, wagon.route.size()):
		road_len += wagon.route[i - 1].distance_to(wagon.route[i])
	road_len += wagon.position.distance_to(wagon.route[0]) if not wagon.route.is_empty() else 0.0


func _end(won: bool) -> void:
	if over:
		return
	over = true
	main.hud.show_message("The %s made it through!" % wagon.label.to_lower() if won else "The %s is lost!" % wagon.label.to_lower())
	main.call_deferred("_finish", won)


func objectives() -> Array:
	return [wagon] if wagon != null else []


## How far along the road the wagon is (0..1).
func along() -> float:
	if wagon == null or road_len <= 0.0:
		return 0.0
	var left := 0.0
	var at: Vector2 = wagon.position
	for i in range(wagon.leg, wagon.route.size()):
		left += at.distance_to(wagon.route[i])
		at = wagon.route[i]
	return clampf(1.0 - left / road_len, 0.0, 1.0)


func process(_delta: float) -> void:
	if over or main.game_over or main.deploying or wagon == null:
		return
	if wagon.speed > 0.0 and wagon.leg == 0 and not main.started:
		return
	var ambushes: Array = _c().get("ambushes", [])
	while sprung < ambushes.size() and along() >= float(ambushes[sprung]["at"]):
		var a: Dictionary = ambushes[sprung]
		sprung += 1
		var k: float = main.FIELD_W / 640.0
		for g in a.get("group", []):
			var p: Vector2 = g[1]
			main._spawn_enemy(g[0], main.wave_level(maxi(main.wave, 1)), Vector2(p.x * k, p.y))
		main.hud.show_message(a.get("note", "Ambush!"))
		main.sfx("horn")


## The wagon waits for the deployment to finish before it sets off.
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
	return "%s: %d%% of the way  ·  health %d%%%s" % [wagon.label, roundi(along() * 100.0), roundi(wagon.hp / wagon.max_hp * 100.0),
			"  ·  held up!" if wagon.halted else ""]


func panel_status() -> String:
	return "Road %d%%" % roundi(along() * 100.0)


func score() -> int:
	return roundi(wagon.hp / wagon.max_hp * 100.0) if wagon != null else 0


func score_text(s: int) -> String:
	return "arrived with %d%% health" % s


func summary(won: bool) -> String:
	return ("The %s arrived with %d%% of its health." % [wagon.label.to_lower(), score()]) if won else "The %s was destroyed %d%% of the way along." % [wagon.label.to_lower(), roundi(along() * 100.0)]
