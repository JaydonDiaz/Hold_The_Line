extends SceneTree
## Troop balance bench (not a pass/fail test: run_all.sh skips it). One troop of a kind, in
## each of its common builds (every 4-2 and 3-3 split of its six upgrades, and the 2-2-2s),
## through the same three fights on an open field, at 4x speed:
##   duel     one Warlord walks down at it: how long it takes to bring down (or how much of it
##            is left after the time), and how the troop stands at the end
##   swarm    a stream of 36 goblins and orcs (one every 0.45s) at it: how many it kills, how many
##            get past it, how it stands
##   brutes   8 Trolls, one every 2.5s: kills, past, how it stands
## Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/balance_units.gd -- <kind> [level] [builds]
## builds: "all" (default) or a comma list like 4200,0402. Prints one "BU" line a build:
## the build, its gold cost, and each fight's figures, for comparing paths with each other.

const Data = preload("res://scripts/data/data.gd")
var main
var kind := "martial"
var level := 6


func _initialize() -> void:
	root.get_node("Campaign").save_path = "user://balance_units.cfg"
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _fresh() -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud.hide_mode_select()
	main.setup.choose_mode("normal")
	main.missions._lock_portrait(true)
	await _frames(3)
	main.castle_hp = 1e9
	main.castle_max = 1e9


func _builds() -> Array:
	var out := []
	for a in 4:
		for b in 4:
			if a != b:
				var t := [0, 0, 0, 0]
				t[a] = 4
				t[b] = 2
				out.append(t)
	for a in 4:
		for b in range(a + 1, 4):
			var t := [0, 0, 0, 0]
			t[a] = 3
			t[b] = 3
			out.append(t)
	for skip in 4:
		var t := [2, 2, 2, 2]
		t[skip] = 0
		out.append(t)
	return out


func _cost(tiers: Array) -> int:
	var d: Dictionary = Data.WARRIORS[kind]
	var c: int = int(d["cost"])
	for p in 4:
		for t in tiers[p]:
			c += int(d["paths"][p]["tiers"][t]["cost"])
	return c


## One troop, built `tiers`, at its post mid-field.
func _troop(tiers: Array):
	main.gold = 99999
	main.placing_type = kind
	main.hiring.hire_at(Vector2(320, 470))
	main.placing_type = ""
	var w = main.battlefield.get_warriors()[-1]
	w.build_left = 0.0
	w.position = w.post
	w.tiers = tiers.duplicate()
	w._apply_upgrades()
	w.hp = w.max_hp
	w.priority = "first"
	return w


## The fight: `spawns` [kind, seconds] sent down at it from the top; `secs` seconds of it.
## Returns {kills, past, dmg (enemy health taken off), hp (the troop's share left, 0 if
## it fell), fell_at, ttk (seconds to clear them all, or -1)}.
func _fight(tiers: Array, spawns: Array, secs: float) -> Dictionary:
	await _fresh()
	var w = await _troop(tiers)
	main.wave_active = true
	var t := 0.0
	var next := 0
	var all := []
	var past := 0
	var fell_at := -1.0
	var ttk := -1.0
	var dt := 1.0 / 60.0 * 4.0
	Engine.time_scale = 4.0
	while t < secs:
		while next < spawns.size() and t >= spawns[next][1]:
			main.waves._spawn_enemy(spawns[next][0], level, Vector2(320 + randf_range(-30, 30), 40))
			all.append(main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1))
			next += 1
		await process_frame
		t += dt
		for e in all.duplicate():
			if is_instance_valid(e) and not e.dead and e.position.y > 690.0:
				past += 1
				all.erase(e)
				e.queue_free()
		if fell_at < 0.0 and (not is_instance_valid(w) or not w.is_active()):
			fell_at = t
		if next >= spawns.size() and all.all(func(e): return not is_instance_valid(e) or e.dead):
			if past == 0:
				ttk = t   # (only if it brought them all down: one that walked past isn't cleared)
			break
	Engine.time_scale = 1.0
	var kills := 0
	var dmg := 0.0
	for e in all:
		if not is_instance_valid(e) or e.dead:
			kills += 1   # (those that got past were taken out of `all`)
		else:
			dmg += e.max_hp - e.hp
	var hp_left: float = (w.hp / w.max_hp) if is_instance_valid(w) and w.is_active() else 0.0
	return {"kills": kills, "past": past, "dmg": dmg, "hp": hp_left, "fell_at": fell_at, "ttk": ttk}


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		kind = args[0]
	if args.size() > 1:
		level = int(args[1])
	var builds := _builds()
	if args.size() > 2 and args[2] != "all":
		builds = Array((args[2] as String).split(",")).map(func(x): return [int(x[0]), int(x[1]), int(x[2]), int(x[3])])
	seed(4242)
	var duel := [["warlord", 0.0]]
	var swarm := []
	for i in 36:
		swarm.append(["goblin" if i % 3 != 2 else "orc", i * 0.45])
	var brutes := []
	for i in 8:
		brutes.append(["troll", i * 2.5])
	for b in builds:
		seed(4242)
		var d: Dictionary = await _fight(b, duel, 30.0)
		seed(4242)
		var s: Dictionary = await _fight(b, swarm, 40.0)
		seed(4242)
		var r: Dictionary = await _fight(b, brutes, 45.0)
		print("BU %s %d%d%d%d cost %4d | duel ttk %5.1f dealt %4.0f past %d hp %.2f | swarm kills %2d past %2d hp %.2f | brutes kills %d past %d hp %.2f fell %5.1f" % [
				kind, b[0], b[1], b[2], b[3], _cost(b), d["ttk"], 0.0 if d["ttk"] >= 0.0 else _left(d), d["past"], d["hp"],
				s["kills"], s["past"], s["hp"], r["kills"], r["past"], r["hp"], r["fell_at"]])
	if main != null:
		main.free()
	quit()


func _left(d: Dictionary) -> float:
	return d["dmg"]
