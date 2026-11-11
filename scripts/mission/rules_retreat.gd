extends "res://scripts/mission/rules_pass.gd"
## Fighting Retreat: an enemy far too big to beat comes down the field, and the job is to
## slow it and get out. Hold each defensive line for its time, then fall back to the next
## (the Fall back order, key Y, sends every troop to it; leave some behind if you like, to
## cover the rest); after the last line, fall back to the camp at the bottom and be in it
## when the time runs out. Troops in the camp then are extracted: enough of them and
## you've won. Enemies getting past everyone into the camp count, as in Hold the Pass: too
## many and it's overrun. The attacks come at a forced pace, and keep coming.
##
## It starts small and builds up: stragglers only join in from wave "stream_from", few at
## first and more every wave, so there's time to earn the gold for a proper army before
## the full weight of it arrives.
##
## Endless: the retreat goes on. Getting enough troops out of the camp takes them on to
## the next stretch (the field changes, the enemy is left behind for a moment, and the
## lines start again); whoever wasn't in the camp is left behind (emplacements and walls
## too, for half their cost back), and a few of the enemy that got past are forgiven. Not
## enough out, or the camp overrun, and it's lost.
##
## Mission data: "type": "retreat", "limit" (as Hold the Pass), "stream": seconds between
##   the stragglers at their thickest, "stream_from": the wave they start on (default 3),
##   "retreat": {"lines": [{"y", "name", "time"}], "extract": {"y", "time", "need"},
##   "stretches": [{"map", "name"}] (endless: the fields it falls back across, in turn)}

const Objective = preload("res://scripts/mission/objective.gd")
const SETTLE := 8.0      # seconds on new ground before the enemy catches up
const REGROUP := 5       # how many of those that got past are forgiven on each new stretch
const STREAM_START := 7.0   # seconds between stragglers when they first turn up...
const STREAM_STEP := 0.7    # ...that much less each wave, down to "stream"

var phase := 0          # the line being held (lines.size(): the extraction)
var left := 0.0         # seconds left on it
var called := false     # the Fall back order for this phase has been given
var markers: Array = []
var extracted := 0
var stream_in := 0.0
var finished := false
var stretch := 0        # endless: the stretch of ground being held (0: the first)
var settle := 0.0       # seconds before the enemy catches up on new ground
var moving_on := false


func _r() -> Dictionary:
	return mission.get("retreat", {})


func lines() -> Array:
	return _r().get("lines", [])


func _x() -> Dictionary:
	return _r().get("extract", {"y": 680, "time": 25, "need": 4})


func stretches() -> Array:
	return _r().get("stretches", [{"map": mission.get("map", ""), "name": ""}])


func stretch_name() -> String:
	var st: Dictionary = stretches()[stretch % stretches().size()]
	var m: Dictionary = load("res://scripts/maps.gd").get_map(st.get("map", ""))
	return st.get("name", m.get("name", "The Meadow"))


func start() -> void:
	for l in lines():
		var m := Objective.new()
		m.setup(main, {"id": l["name"], "kind": "line", "name": l["name"], "at": Vector2(320, l["y"])})
		main.add_objective(m)
		markers.append(m)
	_first_line()
	stream_in = STREAM_START


func _first_line() -> void:
	phase = 0
	left = float(lines()[0]["time"]) if not lines().is_empty() else float(_x()["time"])
	called = true   # (the first line is where you start)


func objectives() -> Array:
	return markers


func followable() -> Array:
	return []


## Seconds between stragglers now (INF: none yet).
func stream_gap() -> float:
	var from := int(mission.get("stream_from", 3))
	if main.wave < from:
		return INF
	return maxf(float(mission.get("stream", 2.0)), STREAM_START - STREAM_STEP * (main.wave - from))


func process(delta: float) -> void:
	if finished or main.game_over or main.deploying or moving_on:
		return
	if settle > 0.0:
		settle -= delta
		if settle <= 0.0:
			main.hud.show_message("They've caught up! Hold the %s." % lines()[0]["name"].to_lower())
			main.sfx("horn")
		return
	# Stragglers on top of the waves, once the fighting's well under way: the enemy is
	# never done.
	stream_in -= delta
	if stream_in <= 0.0:
		var gap := stream_gap()
		stream_in = gap if gap != INF else 1.0
		if gap != INF:
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
	extracted = in_camp().size()
	if endless() and extracted >= int(_x()["need"]):
		_move_on()
		return
	finished = true
	main.call_deferred("_finish", extracted >= int(_x()["need"]))


## Your troops in the camp (emplacements stay where they're built).
func in_camp() -> Array:
	return main.get_warriors().filter(func(w): return w.is_active() and not w.is_emplacement() and w.position.y >= float(_x()["y"]) - 10.0)


## Endless: out of the camp and on across the next stretch of ground.
func _move_on() -> void:
	moving_on = true
	main.hud.show_message("%d got out! On to the next stretch..." % extracted)
	main.hud.fade_through_black(enter_next)


func enter_next() -> void:
	if main.game_over:
		moving_on = false
		return
	var out := in_camp()
	stretch += 1
	change_field(stretches()[stretch % stretches().size()].get("map", ""))
	# Whoever got out holds the first line of the new ground, keeping their place across
	# the field; the rest are left behind. Emplacements and walls are abandoned, for half
	# what they cost.
	var back := 0
	for w in main.get_warriors():
		if out.has(w):
			continue
		if w.is_emplacement():
			back += int(w.spent) / 2
		w.queue_free()
	for b in main.get_barricades():
		back += int(b.spent) / 2
		b.queue_free()
	var y: float = float(lines()[0]["y"]) + 30.0 if not lines().is_empty() else 400.0
	for w in out:
		var p: Vector2 = main.paths.open_spot(main._clamp_post(Vector2(w.position.x, y + randf_range(-10.0, 10.0))))
		w.position = p
		w.post = p
		w.fitted_post = Vector2.INF
		w.route = PackedVector2Array()
		w.reset_targeting(true)   # (nothing left over from the old ground: their orders stand)
		w.anchor = null
		if w.move_mode == "short":
			w.move_mode = "guard"
			w.set_leash(140.0)
	var pay := 100 + 25 * stretch
	main.gold += pay + back
	var forgiven := mini(through, REGROUP)
	through -= forgiven   # (the ones that got past are left behind too, mostly)
	main.walls_changed()
	main.warriors_changed()
	main.paths.invalidate()
	_first_line()
	settle = SETTLE
	moving_on = false
	main.hud.show_message("%s (stretch %d): +%d gold%s%s. Dig in, they're coming!" % [stretch_name(), stretch + 1, pay,
			", %dg back for what was left" % back if back > 0 else "", ", %d fewer got past" % forgiven if forgiven > 0 else ""])
	main.sfx("horn")


func action_label() -> String:
	if called or finished or moving_on or settle > 0.0:
		return ""
	return "Fall back [Y]"


## Fall back: every troop takes a new post on the next line (the camp, at the end),
## keeping its place across the field, and goes there now (fighting nothing on the way).
func action() -> void:
	if called or finished or moving_on:
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
	var where := "%s (stretch %d)  ·  " % [stretch_name(), stretch + 1] if endless() else ""
	if settle > 0.0:
		return "%sDig in: they catch up in %ds" % [where, ceili(settle)]
	if phase < lines().size():
		return "%sHold the %s: %ds  ·  past %d of %d" % [where, lines()[phase]["name"].to_lower(), ceili(left), through, limit()]
	return "%sGet out: %ds  ·  in the camp %d (need %d)" % [where, ceili(left), in_camp().size(), int(_x()["need"])]


func panel_status() -> String:
	return "Line %d" % mini(phase + 1, lines().size()) if phase < lines().size() else "Extract"


func score() -> int:
	return extracted


func score_text(s: int) -> String:
	return "%d troops got out" % s


func summary(won: bool) -> String:
	if won:
		return "%d troops got out (%d were needed)." % [extracted, int(_x()["need"])]
	var where := " on stretch %d" % (stretch + 1) if endless() else ""
	if through > limit():
		return "The camp was overrun%s (%d got past, %d allowed)." % [where, through, limit()]
	return "Only %d troops got out%s; %d were needed." % [extracted, where, int(_x()["need"])]
