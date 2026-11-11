extends "res://tests/campaign_test.gd"
## Balance check for Battle Modes (not a regression test: run_all.sh skips it). A
## player-like bot plays each scenario on every difficulty, two seeds each, at 4x speed,
## posting its army where that kind of battle needs it, buying and upgrading as it goes:
##   Godot --headless --path . --fixed-fps 60 -s tests/modes_bot.gd -- [scenario]
## Prints one "MB" line a game: how many waves it survived (the battles are endless: it
## stops at a time limit if it's still going), and how the battle stood.
var type := ""
var prio := ""   # (a second argument: every troop on this target priority, to compare)


func _spots() -> Array:
	var r = main.rules
	var out := []
	match type:
		"positions":
			for o in r.objectives():
				for i in 3:
					out.append(o.position + Vector2.from_angle(-PI / 2.0 + (i - 1) * 0.9) * 70.0)
		"pass":
			for x in [120, 220, 320, 420, 520]:
				out.append(Vector2(x, 520))
				out.append(Vector2(x + 30, 580))
		"protect":
			var c: Vector2 = r.objectives()[0].position
			for i in 10:
				out.append(c + Vector2.from_angle(-PI / 2.0 + (i - 4.5) * 0.45) * (85.0 if i % 2 == 0 else 140.0))
		"evac":
			for route in main.mission["evac"]["routes"]:
				for k in [1, 2]:
					var p: Vector2 = route[k] * Vector2(main.FIELD_W / 640.0, 1.0)
					out.append(p + Vector2(-40, -30))
					out.append(p + Vector2(40, -30))
		"capture":
			var z: Vector2 = r.zone.position
			for i in 10:
				out.append(z + Vector2.from_angle(i * TAU / 10.0) * (35.0 if i % 2 == 0 else 60.0))
		"escort":
			var w: Vector2 = r.wagon.position
			for i in 8:
				out.append(w + Vector2.from_angle(i * TAU / 8.0) * 70.0)
		"retreat":
			var y: float = 280.0
			if r.phase > 0:
				y = (float(r.lines()[mini(r.phase, r.lines().size() - 1)]["y"]) + 30.0) if r.phase < r.lines().size() else 700.0
			for x in [140, 230, 320, 410, 500]:
				out.append(Vector2(x, y))
				out.append(Vector2(x + 20, y + 50))
	return out


func _spend() -> void:
	var kinds := ["swordsman", "archer", "swordsman", "archer", "healer", "swordsman", "archer", "swordsman", "mage", "swordsman"]
	var i := 0
	for spot in _spots():
		var at: Vector2 = main._clamp_post(spot)
		var have: bool = main.get_warriors().any(func(w): return w.post.distance_to(at) < 12.0)
		var kind: String = kinds[i % kinds.size()]
		i += 1
		if not have and main.gold >= main.hire_cost(kind) and main.can_post_at(at):
			main._on_hire_pressed(kind)
			main.hire_at(at)
			main.placing_type = ""
	if type == "escort":
		var loose: Array = main.get_warriors().filter(func(w): return not w.is_emplacement() and w.anchor == null)
		if not loose.is_empty():
			main.set_follow(main.rules.wagon, loose)
	var spent := true
	while spent:
		spent = false
		for w in main.get_warriors():
			for path in [0, 2, 1, 3]:
				main.selected = w
				var before: int = main.gold
				main.upgrade_selected(path)
				spent = spent or main.gold < before
	main.selected = null


func _run() -> void:
	await process_frame
	campaign = root.get_node("Campaign")
	campaign.save_path = "user://modes_bot.cfg"
	campaign.reset()
	var only: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	prio = OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else ""
	for id in ["three_towers", "open_road", "signal_beacon", "village_road", "old_fort", "supply_wagon", "long_retreat"]:
		if only != "" and id != only:
			continue
		for diff in ["easy", "normal", "hard"]:
			for s in 2:
				seed(700 + s)
				await _fresh_main()
				main.hud.hide_mode_select()
				main.records_path = ""
				main._on_mode_chosen("battle:%s:%s" % [id, diff])
				await process_frame
				main._lock_portrait(true)
				await process_frame
				type = main.mission["type"]
				Engine.time_scale = 4.0
				var guard := 0
				var tick := 0
				while not main.game_over and guard < 60 * 60 * 5:
					tick -= 1
					if tick <= 0:
						tick = 60
						_spend()
						if prio != "":
							for w in main.get_warriors():
								w.priority = prio
						if not main.wave_active and not main.forced_auto:
							main.start_wave()
						if main.rules.action_label() != "":
							main.rules.action()
					await process_frame
					guard += 1
				Engine.time_scale = 1.0
				print("MB %s %s seed %d: %s %d waves  %s" % [id, diff, s, "survived" if main.game_over else "still going after", main.waves_survived(),
						main.rules.status().replace("\n", " ")])
	quit()
