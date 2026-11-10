extends "res://scripts/mission/rules.gd"
## Civilian Evacuation: groups of villagers leave a settlement one after another and walk
## a road to safety (the camp at the bottom of the field), and the enemy goes after them.
## Each group that gets there is saved; each one caught is lost. Save enough and you've
## won; lose so many that it can't be done any more and you've lost. The attacks come at a
## forced pace. No castle.
##
## Mission data: "type": "evac", "evac": {
##   "routes": [[points]]   the roads out (as drawn up, 640 wide); groups take them in turn
##   "groups": n, "size": n people a group, "every": seconds between groups,
##   "first": seconds after the deployment before the first, "hp": a group's health,
##   "speed": px a second, "need": people to save}

const Objective = preload("res://scripts/mission/objective.gd")

var groups: Array = []
var sent := 0
var saved := 0
var lost := 0
var next_in := 0.0
var over := false


func has_castle() -> bool:
	return false


func _evac() -> Dictionary:
	return mission.get("evac", {})


func total() -> int:
	return int(_evac().get("groups", 6)) * int(_evac().get("size", 5))


func need() -> int:
	return int(_evac().get("need", total() / 2))


func start() -> void:
	next_in = float(_evac().get("first", 2.0))


func objectives() -> Array:
	return groups


func process(delta: float) -> void:
	if over or main.game_over or main.deploying:
		return
	if sent < int(_evac().get("groups", 6)):
		next_in -= delta
		if next_in <= 0.0:
			next_in = float(_evac().get("every", 12.0))
			_send_group()
	# Settled: every group out and gone one way or the other.
	if sent >= int(_evac().get("groups", 6)) and groups.all(func(g): return g.dead or g.arrived):
		over = true
		main.call_deferred("_finish", saved >= need())


func _send_group() -> void:
	var routes: Array = _evac().get("routes", [])
	if routes.is_empty():
		return
	var route: Array = routes[sent % routes.size()]
	var g := Objective.new()
	g.setup(main, {"id": "group%d" % sent, "kind": "civilians", "name": "Villagers", "at": route[0], "route": route.slice(1),
			"speed": _evac().get("speed", 30.0), "hp": _evac().get("hp", 120.0), "size": _evac().get("size", 5)})
	main.add_objective(g)
	g.destroyed.connect(_on_lost)
	g.reached.connect(_on_saved)
	groups.append(g)
	sent += 1
	main.hud.show_message("Villagers are on the road (%d of %d)" % [sent, int(_evac().get("groups", 6))])


func _on_saved(g) -> void:
	saved += g.size
	main.spawn_text(g.position + Vector2(0, -40), "%d saved!" % g.size, Color(0.5, 1, 0.5))
	main.sfx("fanfare")


func _on_lost(g) -> void:
	lost += g.size
	if not over and total() - lost < need():
		over = true
		main.hud.show_message("Too many lost: the evacuation has failed")
		main.call_deferred("_finish", false)


## The enemy goes for the villagers on the road (the nearest group), and otherwise for
## the camp.
func enemy_goal(e):
	var best = null
	for g in groups:
		if g.is_target() and (best == null or g.position.distance_to(e.position) < best.position.distance_to(e.position)):
			best = g
	return best


func on_reached_bottom(_e) -> bool:
	return true   # driven off at the camp


func wave_cleared(_n: int) -> bool:
	return false


func wave_text() -> String:
	return "Wave %d" % main.wave


func status() -> String:
	var text := "Saved %d of %d (need %d)  ·  lost %d" % [saved, total(), need(), lost]
	if sent < int(_evac().get("groups", 6)) and not main.deploying:
		text += "  ·  next group in %ds" % ceili(next_in)
	return text


func panel_status() -> String:
	return "Saved %d/%d" % [saved, need()]


func score() -> int:
	return saved


func score_text(s: int) -> String:
	return "%d saved" % s


func summary(won: bool) -> String:
	return ("%d of %d villagers reached safety." % [saved, total()]) if won else "Only %d of %d villagers could be saved (%d were needed)." % [saved, total(), need()]
