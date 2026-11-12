extends "res://scripts/mission/rules.gd"
## Capture and Hold: a stretch of ground (an old fort, a crossroads) is in enemy hands.
## Move troops into it: control fills while you're in it and they aren't, stands still
## while both are, and drains while only they are. Once it's yours, hold it for a while as
## they counterattack; if they drain your control away before the time's up, it's theirs
## again and you have to take it back. All within a time limit. The attacks come at a
## forced pace. No castle.
##
## Mission data: "type": "capture", "capture": {"at", "radius", "name",
##   "time": seconds to take it, "hold": seconds to hold it, "limit": seconds in all,
##   endless: "retake": seconds to take it back once they have (default 45)}
## Endless: "limit" is the time to take it in the first place. Once it's yours, it's
## held for good, and every "hold" seconds of it pays out; if they take it back, you
## have "retake" seconds to retake it, or it's lost.

const Objective = preload("res://scripts/mission/objective.gd")

var zone
var phase := "take"     # "take", "hold", "done"
var hold_left := 0.0
var elapsed := 0.0
var mine := 0           # your troops in it, last counted
var theirs := 0
var take_left := 0.0    # endless: seconds left to take (or retake) it
var held := 0           # endless: hold periods done
var taken := false      # endless: it's been yours at some point


func has_castle() -> bool:
	return false


func _c() -> Dictionary:
	return mission.get("capture", {})


func limit() -> float:
	return float(_c().get("limit", 240.0))


func start() -> void:
	zone = Objective.new()
	zone.setup(main, {"id": "zone", "kind": "zone", "name": _c().get("name", "the fort"), "at": _c().get("at", Vector2(320, 300)),
			"radius": _c().get("radius", 80.0)})
	main.add_objective(zone)
	hold_left = float(_c().get("hold", 60.0))
	take_left = limit()


func objectives() -> Array:
	return [zone] if zone != null else []


func followable() -> Array:
	return []


func process(delta: float) -> void:
	if phase == "done" or main.game_over or main.deploying:
		return
	elapsed += delta
	mine = 0
	theirs = 0
	for w in main.get_warriors():
		if w.is_active() and not w.is_emplacement() and w.position.distance_to(zone.position) <= zone.zone_r:
			mine += 1
	for e in main.enemies_near(zone.position, zone.zone_r + 30.0):
		if not e.dead and not e.flying and e.position.distance_to(zone.position) <= zone.zone_r:
			theirs += 1
	zone.contested = mine > 0 and theirs > 0
	var take: float = float(_c().get("time", 25.0))
	if mine > 0 and theirs == 0:
		zone.progress = minf(zone.progress + delta / take, 1.0)
	elif theirs > 0 and mine == 0:
		zone.progress = maxf(zone.progress - delta / take * (1.0 if phase == "hold" else 0.5), 0.0)
		if phase == "hold":
			spoil("They took ground back")
	if endless():
		_endless(delta)
		return
	if phase == "take" and zone.progress >= 1.0:
		phase = "hold"
		main.hud.show_message("%s is yours! Hold it for %ds." % [zone.label.capitalize(), ceili(hold_left)])
		main.sfx("fanfare")
	elif phase == "hold":
		if zone.progress <= 0.0:
			phase = "take"
			main.hud.show_message("They've taken %s back! Take it again." % zone.label)
		elif not (theirs > 0 and mine == 0):
			hold_left -= delta
			if hold_left <= 0.0:
				phase = "done"
				main.call_deferred("_finish", true)
				return
	if elapsed >= limit() and phase != "done":
		phase = "done"
		main.hud.show_message("Out of time!")
		main.call_deferred("_finish", false)


## Endless: take it, then hold it for good (each spell held pays), and retake it in time
## whenever they win it back.
func _endless(delta: float) -> void:
	if phase == "take":
		if zone.progress >= 1.0:
			phase = "hold"
			taken = true
			hold_left = float(_c().get("hold", 60.0))
			main.hud.show_message("%s is yours! Hold it." % zone.label.capitalize())
			main.sfx("fanfare")
			return
		take_left -= delta
		if take_left <= 0.0:
			phase = "done"
			main.hud.show_message("Out of time!")
			main.call_deferred("_finish", false)
		elif take_left <= 10.0 and take_left + delta > 10.0:
			main.hud.show_message("10 seconds to take %s!" % zone.label)
		return
	if zone.progress <= 0.0:
		phase = "take"
		take_left = float(_c().get("retake", 45.0))
		main.hud.show_message("They've taken %s back! Retake it within %ds." % [zone.label, ceili(take_left)])
		main.sfx("horn")
		return
	if not (theirs > 0 and mine == 0):
		hold_left -= delta
		if hold_left <= 0.0:
			held += 1
			hold_left = float(_c().get("hold", 60.0))
			var pay := 60 + 20 * held
			main.gold += pay
			main.spawn_text(zone.position + Vector2(0, -zone.zone_r - 10), "+%dg" % pay, Color(1, 0.85, 0.2))
			main.hud.show_message("Held! +%d gold for holding %s." % [pay, zone.label])
			main.sfx("coin")


## The enemy makes for the ground you're after (fighting whoever's in the way).
func enemy_goal(_e):
	return zone


func guards() -> bool:
	return true


func objective_only() -> bool:
	return true


func on_reached_bottom(_e) -> bool:
	return true   # driven off at the camp


func wave_cleared(_n: int) -> bool:
	return false


func wave_text() -> String:
	return "Wave %d" % main.wave


func time_left() -> int:
	return maxi(0, ceili(limit() - elapsed))


func status() -> String:
	var where: String = zone.label.capitalize() if zone != null else ""
	var text := ""
	if endless() and zone != null:
		if phase == "hold":
			text = "Holding %s  ·  control %d%%  ·  next pay in %ds" % [zone.label, roundi(zone.progress * 100.0), ceili(hold_left)]
		else:
			text = "%s %s: %d%%  ·  %ds left" % ["Retake" if taken else "Take", zone.label, roundi(zone.progress * 100.0), ceili(take_left)]
		return text + ("  ·  contested" if zone.contested else "")
	if phase == "hold":
		text = "Hold %s: %ds  ·  control %d%%" % [where, ceili(hold_left), roundi(zone.progress * 100.0)]
	else:
		text = "Take %s: %d%%" % [where, roundi(zone.progress * 100.0) if zone != null else 0]
	if zone != null and zone.contested:
		text += "  ·  contested"
	return text + "  ·  %ds left" % time_left()


func panel_status() -> String:
	if endless():
		return "Held %d%%" % roundi(zone.progress * 100.0) if phase == "hold" else "Take %ds" % ceili(take_left)
	return "Time %d" % time_left()


func score() -> int:
	return time_left()


func score_text(s: int) -> String:
	return "held with %ds to spare" % s


func summary(won: bool) -> String:
	if endless():
		return "%s was held for %d spell%s before it was lost." % [zone.label.capitalize(), held, "" if held == 1 else "s"]
	return ("%s taken and held, with %ds to spare." % [zone.label.capitalize(), time_left()]) if won else "%s couldn't be taken and held in time." % zone.label.capitalize()
