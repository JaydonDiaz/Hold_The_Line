extends SceneTree
## Phase 4, the High Monastery (N2). Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/monastery_test.gd
##   S  the Steps   the Thousand Steps: four terraces and a camp; stairs and the rope bridge
##                  walkable, cliffs and the chasm not; three lent masters trained in Spirit
##                  Bolts, which hit a Wyvern, whatever came north (here: no Archers, no
##                  magic); Martial Artists hireable, and tier I Spirit Bolts reaches the air
##   R  retreat     the Fall back order [Y] takes every troop (and its guard area) down the
##                  stairs to the next terrace on its own, and on to the camp
##   B  bells       the Gate's three towers are bells: ready only during a wave, ringing one
##                  stuns the enemies round it (a boss for half as long) and not the far
##                  ones; then it's rung till the next wave; a fallen tower can't be rung;
##                  K rings the ready ones with enemies round them. Bells of Dawn: a free
##                  standing tower is yours only with a troop by it
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.

const TEST_SAVE := "user://monastery_test_campaign.cfg"
const CD = preload("res://scripts/campaign_data.gd")
const Maps = preload("res://scripts/maps.gd")
const Data = preload("res://scripts/data.gd")

var main
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	root.get_node("Campaign").save_path = TEST_SAVE
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _foe(kind: String, at: Vector2, hp := 1e5, boss := false):
	main._spawn_enemy(kind, 1, at)
	var e = main.get_enemies()[-1]
	e.position = at
	e.speed = 0.0
	e.damage = 0.0
	e.max_hp = hp
	e.hp = hp
	e.boss = boss
	return e


func _mission(mid: String, south: Array, extra_done := [], extra_allies := []) -> void:
	var c = root.get_node("Campaign")
	c.new_campaign("normal")
	var done := ["ashwatch", "ashwatch_road", "stonehollow", "stonehollow_workshops", "sable_crossing"]
	var chains := {"greenwood": ["gw_exodus", "gw_watchfires"], "mercyvale": ["mv_wounded", "mv_sanctuary"], "deepdelve": ["dd_entrance", "dd_orerun"]}
	for r in south:
		done += chains[r]
	c.completed = done + extra_done
	c.allies = ["stonehollow"] + south + extra_allies
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud.hide_mode_select()
	main.start_mission(mid)
	await process_frame
	if main.hud.story != null:
		main.hud.story.skip()
	main._lock_portrait(true)
	await _frames(3)


func _run() -> void:
	await _steps()
	await _retreat()
	await _bells()
	if main != null:
		main.free()
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


# --- The Thousand Steps ---------------------------------------------------------------------

func _steps() -> void:
	# Coming north with Mercy Vale and Deepdelve: no Archers, no magic of their own.
	await _mission("mo_steps", ["mercyvale", "deepdelve"])
	var paths = main.paths
	check(main.map_id == "monastery_steps" and main.rules.lines().size() == 4, "S  the Thousand Steps: its map, four terraces to hold")
	var walk := [Vector2(240, 266), Vector2(400, 266), Vector2(140, 408), Vector2(320, 408), Vector2(516, 408), Vector2(258, 540), Vector2(382, 540)]
	var wall := [Vector2(100, 266), Vector2(560, 266), Vector2(50, 408), Vector2(220, 408), Vector2(420, 408), Vector2(100, 540), Vector2(530, 540)]
	check(walk.all(func(p): return not paths.blocked(p, 8.0)), "S  ...every stair and the rope bridge can be walked")
	check(wall.all(func(p): return paths.blocked(p, 8.0)), "S  ...the cliffs and the chasm can't")
	check(paths.wade_factor(Vector2(240, 266)) < 1.0 and paths.wade_factor(Vector2(320, 408)) == 1.0, "S  ...stairs are slow going; the bridge isn't")
	var lent: Array = main.get_warriors().filter(func(w): return w.kind == "martial")
	check(lent.size() == 3 and lent.all(func(w): return w.hits_air()), "S  three masters lent, trained in Spirit Bolts: they hit fliers")
	check(main.allowed("martial") and not main.allowed("archer") and not main.allowed("mage"), "S  ...and with no Archers or magic of its own, this army can hire Martial Artists here")
	var m: Dictionary = CD.MISSIONS["mo_steps"]
	var wyverns := 0
	for w in m.get("extra", {}):
		wyverns += (m["extra"][w] as Array).count("wyvern")
	check(wyverns > 0, "S  ...Wyverns fly here (%d)" % wyverns)
	main.wave_active = true
	var wy = _foe("wyvern", lent[1].position + Vector2(0, -90), 2000.0)
	var hp0: float = wy.hp
	await _frames(60 * 4)
	check(is_instance_valid(wy) and wy.hp < hp0, "S  ...the masters' bolts hurt a Wyvern (%d of %d left)" % [roundi(wy.hp if is_instance_valid(wy) else 0.0), roundi(hp0)])
	if is_instance_valid(wy):
		wy.free()
	main.wave_active = false
	# A hired Martial Artist: no reach into the air untrained, and Spirit Bolts (tier I, no
	# training needed) gives it.
	main.gold = 999
	main.placing_type = "martial"
	main.hire_at(Vector2(320, 640))
	main.placing_type = ""
	var hired = main.get_warriors()[-1]
	var fresh_reach: bool = hired.hits_air()
	hired.tiers = [1, 0, 0, 0]
	hired._apply_upgrades()
	check(hired.kind == "martial" and not fresh_reach and hired.hits_air() and int(Data.WARRIORS["martial"]["paths"][0]["tiers"][0]["cost"]) <= 120,
			"S  ...a hired one reaches the air with Spirit Bolts, its tier I (%dg)" % int(Data.WARRIORS["martial"]["paths"][0]["tiers"][0]["cost"]))


# --- The retreat, with orders ---------------------------------------------------------------

func _retreat() -> void:
	await _mission("mo_steps", ["greenwood", "deepdelve"])
	main.deploying = false
	main.auto_timer = 1e9
	_clear_foes()
	main.gold = 2000
	for p in [Vector2(120, 200), Vector2(300, 200), Vector2(520, 200)]:
		main.placing_type = "swordsman"
		main.hire_at(p)
	main.placing_type = ""
	var troops: Array = main.get_warriors().filter(func(w): return not w.is_emplacement())
	for w in troops:
		w.position = w.post
	# One with a guard area of its own, drawn round its post.
	var g = troops[0]
	g.guard_area = Rect2(g.post - Vector2(60, 40), Vector2(120, 80))
	g.move_mode = "guard"
	var rules = main.rules
	var lines: Array = rules.lines()
	var stuck := []
	var areas_ok := true
	for step in lines.size():
		rules.left = 0.0
		await _frames(2)
		var area0: Rect2 = g.guard_area
		var post0: Vector2 = g.post
		rules.action()
		var y: float = float(lines[step + 1]["y"]) + 30.0 if step + 1 < lines.size() else float(rules._x()["y"]) + 24.0
		if step + 1 < lines.size() and g.guard_area.position - area0.position != g.post - post0:   # (in the camp they close in)
			areas_ok = false
		for k in 18:
			await _frames(60)
			_clear_foes()   # (just the walk: nothing to fight on the way)
		for w in troops:
			if is_instance_valid(w) and absf(w.position.y - y) > 40.0:
				stuck.append("%s at %s (wanted y %d, step %d)" % [w.kind, str(w.position.round()), roundi(y), step + 1])
	check(stuck.is_empty(), "R  Fall back [Y] took every troop down the stairs, terrace by terrace, to the camp%s" % ("" if stuck.is_empty() else ": " + "; ".join(stuck.slice(0, 4))))
	check(areas_ok, "R  ...and a guard area fell back with its troop")
	check(rules.in_camp().size() >= troops.size(), "R  ...all of them in the camp at the end (%d)" % rules.in_camp().size())


func _clear_foes() -> void:
	main.spawn_queue.clear()
	main.rules.stream_in = 1e9
	for e in main.get_enemies():
		e.free()


# --- The bells ------------------------------------------------------------------------------

func _bells() -> void:
	await _mission("mo_gate", ["greenwood", "mercyvale"], ["mo_steps"], ["monastery"])
	var bells = main.bells
	bells._gather()
	var towers: Array = bells.towers
	check(main.map_id == "monastery_gate" and towers.size() == 3 and towers.all(func(b): return b["obj"] != null and b["obj"].kind == "bell"),
			"B  the Trial of the Gate: three bell towers, the mission's objectives")
	main.wave_active = false
	check(not bells.ready(towers[0]), "B  ...a bell can't be rung between waves")
	main.wave = 1
	main.wave_active = true
	check(bells.ready(towers[0]), "B  ...it's ready during a wave")
	var p: Vector2 = bells.pos(towers[0])
	var near = _foe("orc", p + Vector2(60, -20))
	var big = _foe("troll", p + Vector2(-60, -20), 1e5, true)
	var far = _foe("orc", p + Vector2(0, -bells.REACH - 120.0))
	check(bells.ring(towers[0]), "B  ...ringing it")
	check(near.stun_timer > 2.0 and far.stun_timer <= 0.0 and big.stun_timer > 0.5 and big.stun_timer < near.stun_timer,
			"B  ...stuns the enemies round it (%.1fs), a boss for less (%.1fs), not the far one" % [near.stun_timer, big.stun_timer])
	check(not bells.ring(towers[0]) and not bells.ready(towers[0]), "B  ...then it's rung till the next wave")
	main.wave = 2
	check(bells.ready(towers[0]), "B  ...and ready again the next wave")
	towers[1]["obj"].take_damage(1e6)
	await _frames(2)
	check(not bells.ready(towers[1]), "B  a fallen tower can't be rung")
	var near2 = _foe("orc", bells.pos(towers[2]) + Vector2(40, -10))
	var rung: int = bells.ring_all()
	check(rung == 2 and near2.stun_timer > 0.0, "B  K rings every ready bell with enemies round it (%d)" % rung)
	# The Bells of Dawn: free-standing towers, yours only with a troop by them.
	await _mission("mo_dawn", ["greenwood", "mercyvale"], ["mo_steps"], ["monastery"])
	bells = main.bells
	bells._gather()
	main.wave = 1
	main.wave_active = true
	var b: Dictionary = bells.towers[0]
	for w in main.get_warriors():
		w.free()
	await _frames(2)
	var lone: bool = bells.ready(b)
	main.gold = 999
	main.placing_type = "swordsman"
	main.hire_at(bells.pos(b) + Vector2(0, 50))
	main.placing_type = ""
	var w = main.get_warriors()[-1]
	w.position = w.post
	await _frames(2)
	main.deploying = false
	main.wave_active = true
	check(bells.towers.size() == 2 and not lone and bells.ready(b), "B  Bells of Dawn: a tower is yours to ring only with a troop by it")
