extends "res://scripts/mission/rules_pass.gd"
## Fighting Retreat: an enemy far too big to beat comes down the field, and the job is to
## slow it and get out. Hold each defensive line for its time, then fall back to the next
## (the Fall back order, key Y, sends every troop to it; leave some behind if you like, to
## cover the rest); after the last line, fall back to the camp at the bottom and be in it
## when the time runs out. Troops in the camp then are extracted: enough of them and
## you've won. Enemies getting past everyone into the camp count, as in Hold the Pass: too
## many and it's overrun. The attacks come at a forced pace, and keep coming.
##
## Mission data: "type": "retreat", "limit" (as Hold the Pass), "stream": seconds between
##   the stragglers that come on top of the waves, "retreat": {
##   "lines": [{"y", "name", "time"}], "extract": {"y", "time", "need"}}

const Objective = preload("res://scripts/mission/objective.gd")

var phase := 0          # the line being held (lines.size(): the extraction)
var left := 0.0         # seconds left on it
var called := false     # the Fall back order for this phase has been given
var markers: Array = []
var extracted := 0
var stream_in := 0.0
var finished := false


func _r() -> Dictionary:
	return mission.get("retreat", {})


func lines() -> Array:
	return _r().get("lines", [])


func _x() -> Dictionary:
	return _r().get("extract", {"y": 680, "time": 25, "need": 4})


func start() -> void:
	for l in lines():
		var m := Objective.new()
		m.setup(main, {"id": l["name"], "kind": "line", "name": l["name"], "at": Vector2(320, l["y"])})
		main.add_objective(m)
		markers.append(m)
	left = float(lines()[0]["time"]) if not lines().is_empty() else float(_x()["time"])
	called = true   # (the first line is where you start)
	stream_in = float(mission.get("stream", 2.0))


func objectives() -> Array:
	return markers


func followable() -> Array:
	return []


func process(delta: float) -> void:
	if finished or main.game_over or main.deploying:
		return
	# Stragglers on top of the waves: the enemy is never done.
	stream_in -= delta
	if stream_in <= 0.0:
		stream_in = float(mission.get("stream", 2.0))
		main._spawn_enemy(["goblin", "goblin", "orc", "wolf"].pick_random(), main.wave_level(maxi(main.wave, 1)))
	left -= delta
	if left > 0.0:
		return
	if phase < lines().size():
		phase += 1
		called = false
		if phase < lines().size():
			left = float(lines()[phase]["time"])
			main.hud.show_message("Fall back to the %s! [Y]" % lines()[phase]["name"].to_lower())
		else:
			left = float(_x()["time"])
			main.hud.show_message("Fall back to the camp and get out! [Y]")
		main.sfx("horn")
		return
	# The extraction: whoever's in the camp gets out.
	finished = true
	extracted = 0
	for w in main.get_warriors():
		if w.is_active() and not w.is_emplacement() and w.position.y >= float(_x()["y"]) - 10.0:
			extracted += 1
	main.call_deferred("_finish", extracted >= int(_x()["need"]))


func action_label() -> String:
	if called or finished:
		return ""
	return "Fall back [Y]"


## Fall back: every troop takes a new post on the next line (the camp, at the end),
## keeping its place across the field, and goes there now (fighting nothing on the way).
func action() -> void:
	if called or finished:
		return
	called = true
	var camp := phase >= lines().size()
	var y: float = float(lines()[phase]["y"]) + 30.0 if not camp else float(_x()["y"]) + 24.0
	for w in main.get_warriors():
		if w.is_active() and not w.is_emplacement() and not w.wall_guard and not w.summoned:
			w.anchor = null
			var p: Vector2 = main._clamp_post(Vector2(w.post.x, y + randf_range(-10.0, 10.0)))
			w.order_to(main.paths.open_spot(p))
			# Troops roaming free hold the new line once they're on it (in the camp, close
			# in); orders the player gave them otherwise stand.
			if w.move_mode == "free" or camp:
				w.move_mode = "short" if camp else "guard"
				w.set_leash(40.0 if camp else 140.0)
	main.hud.show_message("Falling back: hold the camp!" if camp else "Falling back: hold the %s!" % lines()[phase]["name"].to_lower())


func wave_cleared(_n: int) -> bool:
	return false


func wave_text() -> String:
	return "Wave %d" % main.wave


func status() -> String:
	if phase < lines().size():
		return "Hold the %s: %ds  ·  past %d of %d" % [lines()[phase]["name"].to_lower(), ceili(left), through, limit()]
	var in_camp := 0
	for w in main.get_warriors():
		if w.is_active() and not w.is_emplacement() and w.position.y >= float(_x()["y"]) - 10.0:
			in_camp += 1
	return "Get out: %ds  ·  in the camp %d (need %d)" % [ceili(left), in_camp, int(_x()["need"])]


func panel_status() -> String:
	return "Line %d" % mini(phase + 1, lines().size()) if phase < lines().size() else "Extract"


func score() -> int:
	return extracted


func score_text(s: int) -> String:
	return "%d troops got out" % s


func summary(won: bool) -> String:
	if won:
		return "%d troops got out (%d were needed)." % [extracted, int(_x()["need"])]
	if through > limit():
		return "The camp was overrun (%d got past, %d allowed)." % [through, limit()]
	return "Only %d troops got out; %d were needed." % [extracted, int(_x()["need"])]
