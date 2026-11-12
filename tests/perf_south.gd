extends SceneTree
## Frame times on the southern campaign's battlefields (Phase 3, stage D7), each in its
## own mission with a crowd: an army fielded by the balance bot (tests/army_bot.gd) plus
## extra troops, ~120 enemies of the mission's own kinds kept topped up, knocked about
## every two seconds, and Engineers kept building. Run from the project folder (not
## headless; vsync is switched off):
##   Godot --path . --resolution 640x1040 --fixed-fps 60 -s tests/perf_south.gd -- <seconds> <mission> [wide]
## <mission>: gw_watchfires (three lanes, three positions), dd_entrance (the switchbacks),
## mv_sanctuary (the hedged fields), sable_crossing (the bridges, the Ash Marshal kept on
## the field), dd_orerun (an escort formation following the cart through its ambushes).
## "wide" unlocks the field to the window's width (run it with a wide --resolution).
## Prints a summary line like perf_stress.gd's: frame ms avg / p50 / p95 / p99 / max, FPS.

const ArmyBot = preload("res://tests/army_bot.gd")
const CD = preload("res://scripts/campaign_data.gd")

var main
var bot
var frames := 0
var sim_frames := 60 * 30
var mission := "sable_crossing"
var wide := false
var times := []
var last_us := 0
var rng := RandomNumberGenerator.new()
var sites := []
var pool := []


func _initialize() -> void:
	rng.seed = 21
	seed(21)
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		sim_frames = int(a[0]) * 60
	if a.size() > 1:
		mission = a[1]
	wide = a.size() > 2 and a[2] == "wide"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var c = root.get_node("Campaign")
	c.save_path = "user://perf_south.cfg"
	c.new_campaign("normal")
	c.completed = ["ashwatch", "ashwatch_road", "stonehollow", "stonehollow_workshops", "gw_exodus", "gw_watchfires", "mv_wounded", "mv_sanctuary", "dd_entrance"]
	c.allies = ["stonehollow", "greenwood", "mercyvale", "deepdelve"]
	for k in ["swordsman", "archer", "healer", "mine", "cannon", "tower", "medbay"]:
		c.unlocked[k] = [3, 2, 3, 2]
	c.save_game()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	var m: Dictionary = CD.MISSIONS[mission]
	for w in m.get("pool", {}):
		pool += m["pool"][w]
	for w in m.get("extra", {}):
		pool += m["extra"][w]
	pool = pool.filter(func(k): return k != "ash_marshal")


func _setup() -> void:
	main.hud.hide_mode_select()
	main.start_mission(mission)
	if main.hud.story != null:
		main.hud.story.skip()
	main._lock_portrait(not wide)
	main.gold = 100000
	bot = ArmyBot.new(main)
	for i in 4:
		bot.tick()   # the bot's army, upgraded
	main.gold = 100000
	print("[%s%s] setup: %d troops, field %d wide" % [mission, " wide" if wide else "", main.get_warriors().size(), main.FIELD_W])
	main.deploying = false
	main.wave_active = true
	main.castle_hp = 1e9
	main.castle_max = 1e9
	Engine.time_scale = 2.0


func _process(_d: float) -> bool:
	frames += 1
	var now := Time.get_ticks_usec()
	if frames == 5:
		_setup()
	if frames > 5:
		main.gold = 100000
		main.castle_hp = 1e9
		var r = main.rules
		if "wagon" in r and r.wagon != null:
			r.wagon.hp = r.wagon.max_hp   # (the cart never falls: the run goes on)
		if "through" in r:
			r.through = 0
		for o in r.objectives():
			if "hp" in o and o.kind != "civilian":
				o.hp = o.max_hp
		if frames % 30 == 0:
			var have: int = main.get_enemies().size() + main.spawn_queue.size()
			for k in range(have, 120):
				main.spawn_queue.append([pool[rng.randi() % pool.size()], 6])
			main.spawn_interval = 0.05
			if mission == "sable_crossing" and not main.get_enemies().any(func(e): return e.kind == "ash_marshal"):
				main._spawn_enemy("ash_marshal", 6)   # the Marshal, kept on the field: his charges and his banner
		if frames % 120 == 0:
			for e in main.get_enemies():
				e.apply_knockback(Vector2(rng.randf_range(-70, 70), rng.randf_range(-70, 70)))
		if frames % 60 == 0:
			bot.tick()   # (fills gaps, keeps the escort following the cart)
		if frames % 90 == 0 and mission != "dd_orerun":
			# Keep the Engineers walking: take a site down and build another.
			for s in sites:
				if is_instance_valid(s):
					s.free()
			main.warriors_changed()
			sites.clear()
			for k in 2:
				var p := Vector2(rng.randf_range(60, main.FIELD_W - 60), rng.randf_range(520, 680))
				if main.can_post_at(p):
					main.placing_type = ["tower", "cannon"][k]
					main.hire_at(p)
					var all: Array = main.get_warriors().filter(func(w): return w.is_emplacement())
					if not all.is_empty():
						sites.append(all[all.size() - 1])
			main.placing_type = ""
	if frames > 90:
		times.append((now - last_us) / 1000.0)
	last_us = now
	if frames >= 90 + sim_frames:
		var sorted := times.duplicate()
		sorted.sort()
		var avg := 0.0
		for t in times:
			avg += t
		avg /= times.size()
		var pct := func(q: float) -> float: return sorted[mini(sorted.size() - 1, int(sorted.size() * q))]
		var spikes := times.filter(func(t): return t > 33.3).size()
		print("[%s%s] SUMMARY frames %d | frame ms avg %.2f p50 %.2f p95 %.2f p99 %.2f max %.2f | FPS avg %.0f p5 %.0f | spikes>33ms %d | enemies %d troops %d" % [
				mission, " wide" if wide else "", times.size(), avg, pct.call(0.5), pct.call(0.95), pct.call(0.99), sorted[-1],
				1000.0 / avg, 1000.0 / pct.call(0.95), spikes, main.get_enemies().size(), main.get_warriors().size()])
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://perf_south.cfg"))
		return true
	return false
