extends "res://tests/missions_test.gd"
## Performance of the busiest objective battle: the Village Road with all 40 villagers on
## the road, 100 enemies after them and 16 troops on the Objective priority; then the same
## field with no villagers (the enemies wait mid-field), to see what the villagers cost.
## Real frame times (not a regression test: run_all.sh skips it):
##   Godot --path . --fixed-fps 60 -s tests/perf_modes.gd   (vsync off)
func _run() -> void:
	campaign = root.get_node("Campaign")
	campaign.save_path = "user://perf_modes.cfg"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)   # (what the machine can do, not the screen's rate)
	Engine.max_fps = 0
	for with_people in [true, false, true, false]:
		seed(3)
		await _fresh_battle("battle:village_road:normal")
		main._lock_portrait(false)
		await _go()
		main.gold = 99999
		for i in 16:
			main.placing_type = ["swordsman", "archer"][i % 2]
			main.hire_at(Vector2(main.FIELD_W * (0.15 + 0.7 * (i % 8) / 7.0), 420 + (i / 8) * 80))
		main.placing_type = ""
		var r = main.rules
		if with_people:
			for g in 8:
				r._send_group()
			for v in r.people:
				v.max_hp = 1e6
				v.hp = 1e6
				v.speed = 6.0
		r.sent = 99   # (no more groups, and the battle doesn't settle)
		r.over = true
		main.spawn_queue.clear()
		for i in 100:
			main._spawn_enemy(["goblin", "orc", "wolf", "troll"][i % 4], 6, Vector2(randf_range(40, main.FIELD_W - 40), randf_range(-200, 200)))
		for e in main.get_enemies():
			e.max_hp *= 20.0
			e.hp = e.max_hp
		await _frames(30)
		var times := []
		for f in 600:
			var t0 := Time.get_ticks_usec()
			await process_frame
			times.append((Time.get_ticks_usec() - t0) / 1000.0)
		times.sort()
		var avg := 0.0
		for t in times:
			avg += t
		avg /= times.size()
		print("PERF village_road %s: avg %.1f ms  p95 %.1f  max %.1f  (%d villagers, %d enemies, %d troops)" % [
				"with villagers" if with_people else "no villagers", avg, times[int(times.size() * 0.95)], times[-1],
				r.people.size(), main.get_enemies().size(), main.get_warriors().size()])
	quit()
