extends "res://scripts/mission/rules.gd"
## Hold the Pass: there's no castle. The bottom of the field is the far end of a pass (a
## road, a bridge, a gate) with your camp on it, and the enemy is trying to get through.
## Every enemy that reaches the bottom line is gone for good, past your army, and counts
## against you: a Troll counts 2, a Warlord 3. Let more than the mission's "limit" through
## and the pass is lost; clear the last wave inside the limit and it's held.
##
## Mission data: "type": "pass", "limit": n (how many may get through; default 8),
## "worth": {kind: n} (to override how much an enemy kind counts).

const WORTH := {"troll": 2, "warlord": 3, "ogre_king": 10}

var through := 0     # how much has broken through (by worth)
var lost := false


func has_castle() -> bool:
	return false


func limit() -> int:
	return int(mission.get("limit", 8))


func worth(kind: String) -> int:
	return int(mission.get("worth", {}).get(kind, WORTH.get(kind, 1)))


func on_reached_bottom(e) -> bool:
	var n := worth(e.kind)
	through += n
	main.spawn_text(Vector2(e.position.x, main.CASTLE_Y - 20), "Broke through!" if n == 1 else "Broke through! (x%d)" % n, Color(1, 0.4, 0.3))
	main.sfx("castle")
	if through > limit() and not lost and not main.game_over:
		lost = true
		main.call_deferred("_finish", false)
	elif through * 2 > limit() and through - n <= limit() / 2:
		main.hud.show_message("Half of what may pass has broken through. Hold the line!")
	return true


func status() -> String:
	return "Broke through: %d of %d allowed" % [through, limit()]


func panel_status() -> String:
	return "Past %d/%d" % [through, limit()]


func score() -> int:
	return limit() - through


func score_text(s: int) -> String:
	return "%d got through" % (limit() - s)


## For the end screen: how it went.
func summary(won: bool) -> String:
	if won:
		return "Only %d got through (of %d allowed)." % [through, limit()]
	return "Too many broke through the pass (%d, with %d allowed)." % [through, limit()]
