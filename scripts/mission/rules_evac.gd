extends "res://scripts/mission/rules.gd"
## Civilian Evacuation: villagers leave a settlement a family at a time and walk a road to
## safety (the camp at the bottom of the field), and the enemy goes after them. Every
## villager is one person with their own health: each that gets there is saved, each
## caught is lost. Save enough and you've won; lose so many that it can't be done any more
## and you've lost. The attacks come at a forced pace. No castle.
##
## Mission data: "type": "evac", "evac": {
##   "routes": [[points]]   the roads out (as drawn up, 640 wide); groups take them in turn
##   "groups": n, "size": n people a group, "every": seconds between groups,
##   "first": seconds after the deployment before the first, "hp": each villager's health,
##   "speed": px a second, "need": people to save,
##   "can_lose": endless: how many may be caught before it's lost}
## Endless: the families keep coming (no last group), and it's lost once more than
## "can_lose" villagers have been caught.

const Objective = preload("res://scripts/mission/objective.gd")

var people: Array = []   # every villager sent, on the road or not
var sent := 0            # groups sent
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


func groups() -> int:
	return 1 << 30 if endless() else int(_evac().get("groups", 6))


func can_lose() -> int:
	return int(_evac().get("can_lose", 10))


func need() -> int:
	return int(_evac().get("need", total() / 2))


func start() -> void:
	next_in = float(_evac().get("first", 2.0))


func objectives() -> Array:
	return people


func followable() -> Array:
	return []   # too many to follow one: guard their roads


func process(delta: float) -> void:
	if over or main.game_over or main.deploying:
		return
	if sent < groups():
		next_in -= delta
		if next_in <= 0.0:
			next_in = float(_evac().get("every", 12.0))
			_send_group()
	# Settled: every group out and gone one way or the other.
	if not endless() and sent >= groups() and people.all(func(g): return g.dead or g.arrived):
		over = true
		main.call_deferred("_finish", saved >= need())


## A family sets out: each villager a little apart from the next, on a slightly different
## line along the road and at their own pace (keeping together, more or less).
func _send_group() -> void:
	var routes: Array = _evac().get("routes", [])
	if routes.is_empty():
		return
	# The ones that got there (or didn't) a while back are done with: off the field.
	var done := people.filter(func(g): return g.dead or g.arrived)
	for g in done:
		g.queue_free()
	people = people.filter(func(g): return not (g.dead or g.arrived))
	var route: Array = routes[sent % routes.size()]
	var n := int(_evac().get("size", 5))
	var spd := float(_evac().get("speed", 30.0))
	for i in n:
		var off := Vector2(randf_range(-16.0, 16.0), -i * 14.0 + randf_range(-4.0, 4.0))
		var line := route.map(func(p): return p + Vector2(off.x, 0))
		line[line.size() - 1] = route[route.size() - 1] + Vector2(off.x * 0.5, 0)
		var v := Objective.new()
		v.setup(main, {"id": "villager%d" % people.size(), "kind": "civilian", "name": "Villager", "at": line[0] + Vector2(0, off.y),
				"route": line.slice(1), "speed": spd * randf_range(0.9, 1.1), "hp": _evac().get("hp", 60.0),
				"variant": randi() % 24, "look": Objective.VILLAGERS[(people.size() + i * 3) % Objective.VILLAGERS.size()]})
		main.add_objective(v)
		v.destroyed.connect(_on_lost)
		v.reached.connect(_on_saved)
		people.append(v)
	sent += 1
	if endless():
		main.hud.show_message("More villagers are on the road" if sent > 1 else "Villagers are on the road")
	else:
		main.hud.show_message("Villagers are on the road (%d of %d)" % [sent, groups()])



func _on_saved(v) -> void:
	saved += 1
	main.spawn_text(v.position + Vector2(0, -40), "Safe!", Color(0.5, 1, 0.5))
	main.sfx("coin", 1.2)


func _on_lost(_v) -> void:
	lost += 1
	if not over and endless():
		if lost > can_lose():
			over = true
			main.hud.show_message("Too many lost: the evacuation has failed")
			main.call_deferred("_finish", false)
		elif lost == can_lose():
			main.hud.show_message("Lose one more villager and it's over!")
		return
	if not over and total() - lost < need():
		over = true
		main.hud.show_message("Too many lost: the evacuation has failed")
		main.call_deferred("_finish", false)


## The enemy goes for the villagers on the road (the nearest one), and otherwise for the
## camp.
func enemy_goal(e):
	var best = null
	for g in people:
		if g.is_target() and (best == null or g.position.distance_to(e.position) < best.position.distance_to(e.position)):
			best = g
	return best


func guards() -> bool:
	return true


func objective_only() -> bool:
	return true


## Raiders with nobody on the road yet lurk mid-field, between the roads, for the next.
func wait_y() -> float:
	return 360.0


func on_reached_bottom(_e) -> bool:
	return true   # driven off at the camp


func wave_cleared(_n: int) -> bool:
	return false


func wave_text() -> String:
	return "Wave %d" % main.wave


func status() -> String:
	var text := "Saved %d  ·  lost %d of %d allowed" % [saved, lost, can_lose()] if endless() \
			else "Saved %d of %d (need %d)  ·  lost %d" % [saved, total(), need(), lost]
	if sent < groups() and not main.deploying:
		text += "  ·  next group in %ds" % ceili(next_in)
	return text


func panel_status() -> String:
	return "Lost %d/%d" % [lost, can_lose()] if endless() else "Saved %d/%d" % [saved, need()]


func score() -> int:
	return saved


func score_text(s: int) -> String:
	return "%d saved" % s


func summary(won: bool) -> String:
	if endless():
		return "%d villagers reached safety before too many were lost." % saved
	return ("%d of %d villagers reached safety." % [saved, total()]) if won else "Only %d of %d villagers could be saved (%d were needed)." % [saved, total(), need()]
