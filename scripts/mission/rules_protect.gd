extends "res://scripts/mission/rules_positions.gd"
## Protect the Objective: something on the field has a job to finish (a beacon to light, a
## drill to run, a ritual), and it takes time: its "charge" fills while it works, and
## stops while an enemy is at it. Keep it standing until it's done. The attacks keep coming
## until then (usually at a forced pace). Without "castle": true there's no castle, just
## your camp at the bottom.
##
## Mission data: "type": "protect", "objectives" (as Multiple Positions; the ones with
## "charge": seconds are the job), "can_lose" (default 0).

var done := false


func has_castle() -> bool:
	return mission.get("castle", false)


func _charging() -> Array:
	return objs.filter(func(o): return o.charge > 0.0)


func process(delta: float) -> void:
	if done or main.game_over or main.deploying:
		return
	var all_full := true
	for o in _charging():
		if o.dead:
			continue
		o.contested = false
		for e in main.enemies_near(o.position, o.RADIUS + 60.0):
			if not e.dead and o.position.distance_to(e.position) <= o.RADIUS + e.radius + 14.0:
				o.contested = true   # an enemy at it: the work stops
				break
		if not o.contested:
			o.progress = minf(o.progress + delta / o.charge, 1.0)
		all_full = all_full and o.progress >= 1.0
	if all_full and not _charging().is_empty():
		done = true
		main.hud.show_message("%s is done: it held!" % _charging()[0].label)
		main.call_deferred("_finish", true)


func wave_cleared(_n: int) -> bool:
	return false   # the battle ends when the work is done


func wave_text() -> String:
	return "Wave %d" % main.wave


func on_reached_bottom(_e) -> bool:
	return not has_castle()   # past your camp: gone (it's the objective that matters)


func status() -> String:
	var c := _charging()
	if c.is_empty():
		return super.status()
	var o = c[0]
	return "%s: %d%%%s" % [o.label, roundi(o.progress * 100.0), "  ·  under attack: stopped!" if o.contested else ""]


func panel_status() -> String:
	var c := _charging()
	return "Done %d%%" % roundi(c[0].progress * 100.0) if not c.is_empty() else super.panel_status()


func score() -> int:
	var c := _charging()
	return roundi(c[0].hp / c[0].max_hp * 100.0) if not c.is_empty() else 0


func score_text(s: int) -> String:
	return "finished with %d%% of its health" % s


func summary(won: bool) -> String:
	var c := _charging()
	if c.is_empty():
		return super.summary(won)
	return ("%s finished its work, at %d%% health." % [c[0].label, score()]) if won else "%s was destroyed before its work was done (%d%%)." % [c[0].label, roundi(c[0].progress * 100.0)]
