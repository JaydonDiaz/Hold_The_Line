extends "res://scripts/mission/rules.gd"
## Multiple Positions: several objectives stand on the field (workshops, watchtowers...)
## and the enemy splits up to go for them. There's no castle: the positions are what the
## battle is about, and your camp is at the bottom. Lose too many (more than "can_lose")
## and the battle is lost. Clear the last wave with enough of them standing to win.
##
## Mission data: "type": "positions",
##   "objectives": [{"id", "kind", "name", "at", "hp"}]   placed on the map as drawn up (640 wide)
##   "can_lose": n          how many may be destroyed (default 0: keep them all)
##   "castle": true         keep a castle too (default: none)
##   "castle_share": 0.25   with a castle: share of enemies that go for it instead
##   "mend": 0.15           endless: share of its health each standing one gets back
##                          when a wave is cleared (the crews patch them up)
## Each enemy picks its objective when it comes in: most go for the one nearest where they
## enter, the rest for any other still standing, so the attack spreads but has a weight.

const Objective = preload("res://scripts/mission/objective.gd")

var objs: Array = []
var lost := 0
var over := false


func has_castle() -> bool:
	return mission.get("castle", false)


func can_lose() -> int:
	return int(mission.get("can_lose", 0))


func start() -> void:
	for d in mission.get("objectives", []):
		var o := Objective.new()
		o.setup(main, d)
		main.add_objective(o)
		o.destroyed.connect(on_objective_lost)
		objs.append(o)
	main.paths.set_objectives(objs)


func objectives() -> Array:
	return objs


func standing() -> Array:
	return objs.filter(func(o): return not o.dead)


func guards() -> bool:
	return true


func objective_only() -> bool:
	return not has_castle()


func enemy_goal(e):
	var alive := standing()
	if alive.is_empty():
		return null
	if has_castle() and randf() < float(mission.get("castle_share", 0.25)):
		return null
	if randf() < 0.7:
		var best = alive[0]
		for o in alive:
			if absf(o.position.x - e.position.x) < absf(best.position.x - e.position.x):
				best = o
		return best
	return alive.pick_random()


func wave_cleared(n: int) -> bool:
	if endless():
		var mended := false
		for o in standing():
			if o.hp < o.max_hp:
				o.hp = minf(o.max_hp, o.hp + o.max_hp * float(mission.get("mend", 0.15)))
				mended = true
		if mended:
			main.spawn_text(Vector2(main.FIELD_W / 2.0, 200), "The crews patch them up", Color(0.6, 1, 0.6))
	return super.wave_cleared(n)


## Without a castle, one that gets past the positions is off the field (it's them that matter).
func on_reached_bottom(_e) -> bool:
	return not has_castle()


func on_objective_lost(o) -> void:
	lost += 1
	spoil("The %s fell" % o.label.to_lower())
	if lost > can_lose() and not over and not main.game_over:
		over = true
		main.hud.show_message("The %s has fallen. The line is broken!" % o.label)
		main.call_deferred("_finish", false)
	else:
		var left := can_lose() - lost
		main.hud.show_message("The %s has fallen! %s" % [o.label, "Lose one more and it's over." if left == 0 else "%d more can be lost." % left])


func _plural() -> String:
	var name: String = (objs[0].kind as String).capitalize() if not objs.is_empty() else "Position"
	return name + "s"


func status() -> String:
	if objs.is_empty():
		return ""
	var text := "%s standing: %d of %d" % [_plural(), standing().size(), objs.size()]
	if can_lose() > 0:
		text += "  ·  can lose %d" % (can_lose() - mini(lost, can_lose()))
	return text


const SHORT := {"watchtower": "Towers", "workshop": "Shops", "beacon": "Beacon", "stone": "Stones"}


func panel_status() -> String:
	var kind: String = objs[0].kind if not objs.is_empty() else ""
	return "%s %d/%d" % [SHORT.get(kind, _plural().left(6)), standing().size(), objs.size()]


func score() -> int:
	return standing().size()


func score_text(s: int) -> String:
	return "%d of %d %s kept" % [s, objs.size(), _plural().to_lower()]


func summary(won: bool) -> String:
	if won:
		return "%d of %d %s still stand." % [standing().size(), objs.size(), _plural().to_lower()]
	if lost > can_lose():
		return "Too many %s fell (%d of %d)." % [_plural().to_lower(), lost, objs.size()]
	return ""
