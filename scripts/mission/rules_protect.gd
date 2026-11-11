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
var lit := 0     # endless: how many times it's been lit


## (Endless: when it's done, it's lit, paid for and patched up, and the work starts again,
## a little longer each time; "relight": {"gold", "mend", "longer"}.)


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
		if endless():
			_relight()
			return
		done = true
		main.hud.show_message("%s is done: it held!" % _charging()[0].label)
		main.call_deferred("_finish", true)


## Endless: it's lit (the signal's away), then it burns down and has to be built up again.
func _relight() -> void:
	lit += 1
	var r: Dictionary = mission.get("relight", {})
	var pay := int(r.get("gold", 80)) + 20 * lit
	main.gold += pay
	for o in _charging():
		if o.dead:
			continue
		o.hp = minf(o.max_hp, o.hp + o.max_hp * float(r.get("mend", 0.3)))
		o.progress = 0.0
		o.charge *= float(r.get("longer", 1.1))
		main.spawn_text(o.position + Vector2(0, -150), "+%dg" % pay, Color(1, 0.85, 0.2))
	main.hud.show_message("%s is lit (%d)! +%d gold. It burns down: build it up again." % [_charging()[0].label, lit, pay])
	main.sfx("fanfare")


func wave_cleared(_n: int) -> bool:
	return false   # the battle ends when the work is done


func wave_text() -> String:
	return "Wave %d" % main.wave


func status() -> String:
	var c := _charging()
	if c.is_empty():
		return super.status()
	var o = c[0]
	return "%s: %d%%%s%s" % [o.label, roundi(o.progress * 100.0), "  ·  lit %d" % lit if lit > 0 else "",
			"  ·  under attack: stopped!" if o.contested else ""]


func panel_status() -> String:
	var c := _charging()
	if c.is_empty():
		return super.panel_status()
	return ("Lit %d · %d%%" % [lit, roundi(c[0].progress * 100.0)]) if endless() else "Done %d%%" % roundi(c[0].progress * 100.0)


func score() -> int:
	var c := _charging()
	return roundi(c[0].hp / c[0].max_hp * 100.0) if not c.is_empty() else 0


func score_text(s: int) -> String:
	return "finished with %d%% of its health" % s


func summary(won: bool) -> String:
	var c := _charging()
	if c.is_empty():
		return super.summary(won)
	if endless():
		return "%s was lit %d time%s before it fell." % [c[0].label, lit, "" if lit == 1 else "s"]
	return ("%s finished its work, at %d%% health." % [c[0].label, score()]) if won else "%s was destroyed before its work was done (%d%%)." % [c[0].label, roundi(c[0].progress * 100.0)]
