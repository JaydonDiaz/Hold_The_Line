extends "res://tests/campaign_test.gd"
## Balance runs for the southern campaign (Phase 3, stage D6). Not a pass/fail test
## (run_all.sh skips it): it plays missions with the mixed-army bot (tests/army_bot.gd)
## and prints one "BR" line a battle, for tools to add up:
##   Godot --headless --path . --fixed-fps 60 -s tests/balance_runs.gd -- key=value ...
##     missions=gw_exodus,sable_crossing   (default: every southern mission)
##     diffs=easy,normal,hard   seeds=3   trained=0,1   style=mixed   width=640
##     prior=min,all   (a first southern mission played with no other southern people
##                      joined yet, or with the other two regions already secured)
##     sets=gw+dd,gw+mv,dd+mv,gw+dd+mv     (Sable Crossing's southern beacons; for a northern
##                      mission, which southern peoples came north with you)
## Width 640 is the campaign's portrait field; 1040 plays it stretched wide.

const ArmyBot = preload("res://tests/army_bot.gd")
const SOUTH := ["gw_exodus", "gw_watchfires", "gw_trail", "mv_wounded", "mv_sanctuary", "dd_entrance", "dd_orerun", "sable_crossing"]
const REGION := {"gw": "greenwood", "mv": "mercyvale", "dd": "deepdelve"}
const REGION_MISSIONS := {"greenwood": ["gw_exodus", "gw_watchfires"], "mercyvale": ["mv_wounded", "mv_sanctuary"], "deepdelve": ["dd_entrance", "dd_orerun"]}
const ACT1 := ["ashwatch", "ashwatch_road", "stonehollow", "stonehollow_workshops"]
const NORTH_MISSIONS := {"frostmarch": ["fm_pass", "fm_vigil"], "monastery": ["mo_steps", "mo_gate"], "freecities": ["fc_market", "fc_council"]}   # (Phase 4: grows region by region)
## Trained: what a player has typically spent on each kind by the south (a few points on
## the Knights, a couple on each people's units). Untrained: nothing (tier I only).
const TRAINED := {"swordsman": [3, 2, 3, 1], "archer": [2, 1, 2, 1], "tower": [2, 1, 2, 1], "healer": [2, 1, 2, 1],
		"medbay": [2, 1, 2, 1], "mine": [2, 1, 2, 1], "cannon": [2, 1, 2, 1], "barricade": [2, 1, 2, 1]}

var opts := {"missions": ",".join(SOUTH), "diffs": "easy,normal,hard", "seeds": "3", "trained": "0,1", "style": "mixed",
		"width": "640", "prior": "min", "sets": "gw+dd,gw+mv,dd+mv,gw+dd+mv", "seed0": "900"}


func _run() -> void:
	await process_frame
	for a in OS.get_cmdline_user_args():
		if a.contains("="):
			opts[a.get_slice("=", 0)] = a.get_slice("=", 1)
	campaign = root.get_node("Campaign")
	campaign.save_path = "user://balance_runs_%d.cfg" % OS.get_process_id()
	campaign.reset()
	var width := int(opts["width"])
	if opts.has("modes"):
		# Battle Modes scenarios (endless): played to the time limit or the end.
		for id in opts["modes"].split(","):
			for diff in opts["diffs"].split(","):
				for s in int(opts["seeds"]):
					await _battle("battle:" + id, diff, ["mode", [], []], false, int(opts["seed0"]) + s, width)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(campaign.save_path))
		quit()
		return
	for id in opts["missions"].split(","):
		var setups := []   # [label, completed, allies]
		var region: String = CD.MISSIONS[id]["territory"]
		if NORTH_MISSIONS.has(region):
			# The North: Sable won with one of the southern sets; the region's first mission
			# too for its later ones.
			for s in opts["sets"].split(","):
				var regions: Array = Array(s.split("+")).map(func(r): return REGION[r])
				var done := ACT1.duplicate()
				for r in regions:
					done += REGION_MISSIONS[r]
				done.append("sable_crossing")
				var allies := ["stonehollow"] + regions
				if (NORTH_MISSIONS[region] as Array)[0] != id:
					done.append(NORTH_MISSIONS[region][0])
					allies.append(region)
				setups.append([s, done, allies])
		elif id == "sable_crossing":
			for s in opts["sets"].split(","):
				var regions: Array = Array(s.split("+")).map(func(r): return REGION[r])
				var done := ACT1.duplicate()
				for r in regions:
					done += REGION_MISSIONS[r]
				setups.append([s, done, ["stonehollow"] + regions])
		else:
			var own: String = CD.MISSIONS[id]["territory"]
			if not REGION_MISSIONS.has(own):
				# An Act 1 mission (the Armoury Wagon, the Workshops): Stonehollow joined.
				setups.append(["act1", ["ashwatch", "stonehollow"], ["stonehollow"]])
				for st in setups:
					for diff in opts["diffs"].split(","):
						for tr in opts["trained"].split(","):
							for s in int(opts["seeds"]):
								await _battle(id, diff, st, tr == "1", int(opts["seed0"]) + s, width)
				continue
			var first: bool = (REGION_MISSIONS[own] as Array)[0] == id
			for p in opts["prior"].split(","):
				var done := ["ashwatch", "stonehollow"]
				var allies := ["stonehollow"]
				if p == "all":
					done = ACT1.duplicate()
					for r in REGION_MISSIONS:
						if r != own:
							done += REGION_MISSIONS[r]
							allies.append(r)
				if not first:
					done.append((REGION_MISSIONS[own] as Array)[0])
					allies.append(own)
				setups.append([p, done, allies])
		for st in setups:
			for diff in opts["diffs"].split(","):
				for tr in opts["trained"].split(","):
					for s in int(opts["seeds"]):
						await _battle(id, diff, st, tr == "1", int(opts["seed0"]) + s, width)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(campaign.save_path))
	quit()


func _battle(id: String, diff: String, st: Array, trained: bool, sd: int, width: int) -> void:
	seed(sd)
	campaign.new_campaign(diff)
	campaign.completed = (st[1] as Array).duplicate()
	campaign.allies = (st[2] as Array).duplicate()
	if trained:
		for k in TRAINED:
			campaign.unlocked[k] = (TRAINED[k] as Array).duplicate()
	await _fresh_main()
	main.hud.hide_mode_select()
	if id.begins_with("battle:"):
		main.records_path = ""
		main._on_mode_chosen("%s:%s" % [id, diff])
		id = id.substr(7)
	else:
		main.start_mission(id)
	await process_frame
	if opts.has("heat"):
		main.heat = int(opts["heat"])   # (as if this many other northern missions were won)
	if main.hud.story != null:
		main.hud.story.skip()
	await process_frame
	if width > 640:
		main._lock_portrait(false)
		root.size = Vector2i(width, 1040)
		await process_frame
		main._fit_screen()
	else:
		main._lock_portrait(true)
	await process_frame
	var bot = ArmyBot.new(main, opts["style"])
	Engine.time_scale = 4.0
	var frames := 0
	var tick := 0
	var low := 1.0
	var dumped := false
	var quiet := 0     # seconds of game time with no enemy on the field (once deployed)
	var limit_s := int(opts.get("limit", "540"))
	while not main.game_over and frames < limit_s * 15:
		tick -= 1
		if tick <= 0:
			tick = 15   # once a second of game time
			bot.tick()
			if not main.wave_active and not main.forced_auto:
				main.start_wave()
			low = minf(low, _margin())
			if not main.deploying and main.wave > 0 and main.get_enemies().is_empty() and main.spawn_queue.is_empty():
				quiet += 1
			if opts.get("trace", "") == "1" and int(frames / 15) % 10 == 0:
				print("   T %3ds wave %d margin %.2f gold %d enemies %d army [%s]" % [roundi(frames * 4.0 / 60.0), main.wave, _margin(), main.gold,
						main.get_enemies().size(), bot.army()])
				var kinds := {}
				for e in main.get_enemies():
					var key: String = e.kind + ("@wall" if e.position.y > main.CASTLE_Y - 160.0 else "")
					kinds[key] = kinds.get(key, 0) + 1
				print("      enemies %s" % str(kinds))
				if _margin() < float(opts.get("dump_at", "0.95")) and not dumped:
					dumped = true
					for e in main.get_enemies():
						print("      E %s at %s goal %s" % [e.kind, str(e.position.round()), e.goal.label if e.goal != null else "castle"])
					for w in main.get_warriors():
						print("      W %s at %s post %s %s/%d target %s %s" % [w.kind, str(w.position.round()), str(w.post.round()), w.move_mode,
								roundi(w.zone_rect().size.x / 2.0), (w.target.kind + str(w.target.position.round())) if is_instance_valid(w.target) and w.target != null else "-",
								"downed" if not w.is_active() else ""])
		await process_frame
		frames += 1
	Engine.time_scale = 1.0
	if not main.game_over:
		# Stuck: who's left, where, and what they're doing.
		for e in main.get_enemies():
			print("   STUCK %s at %s hp %.0f/%.0f target %s route %d" % [e.kind, str(e.position.round()), e.hp, e.max_hp,
					str(e.target_pos.round()) if "target_pos" in e else "-", e.route.size() if "route" in e else -1])
			var near = null
			for w in main.get_warriors():
				if w.is_active() and (near == null or w.position.distance_to(e.position) < near.position.distance_to(e.position)):
					near = w
			if near != null:
				print("      fighting %s shots %d goal %s | nearest troop %s at %d px, %s area %d, post %s, hp %.0f/%.0f, can reach %s" % [str(e.fighting), e.shots,
						e.goal.label if e.goal != null else "-", near.kind, roundi(near.position.distance_to(e.position)), near.move_mode,
						roundi(near.zone_rect().size.x / 2.0), str(near.post.round()), near.hp, near.max_hp, str(main.paths.melee_can_reach(e.position))])
		print("   STUCK queue %d wave_active %s" % [main.spawn_queue.size(), str(main.wave_active)])
	var result := ("WON" if main.victory else "lost") if main.game_over else "unfinished"
	print("BR mission=%s diff=%s setup=%s trained=%d style=%s seed=%d width=%d result=%s wave=%d margin=%.2f low=%.2f quiet=%d gametime=%d field=%d army=[%s] status=[%s]" % [
			id, diff, st[0], 1 if trained else 0, opts["style"], sd, width, result, main.wave, _margin(), low, quiet, roundi(frames * 4.0 / 60.0),
			main.FIELD_W, bot.army(), main.rules.status().replace("\n", " ")])


## How much the player had to spare, 0..1, by what the battle is about: the castle's
## health, the positions' health (lost ones count 0), the wagon's, how far under the
## breakthrough limit, villagers saved against the most that could be lost.
func _margin() -> float:
	var r = main.rules
	match main.mission.get("type", "castle"):
		"pass":
			return clampf(1.0 - float(r.through) / maxf(r.limit(), 1.0), 0.0, 1.0)
		"positions":
			var sum := 0.0
			for o in r.objectives():
				sum += 0.0 if o.dead else o.hp / o.max_hp
			return sum / maxf(r.objectives().size(), 1.0)
		"escort":
			return clampf(r.wagon.hp / r.wagon.max_hp, 0.0, 1.0) if r.wagon != null else 0.0
		"evac":
			var ev: Dictionary = main.mission["evac"]
			var total: int = int(ev["groups"]) * int(ev["size"])
			var can_lose: int = total - int(ev["need"])
			return clampf(1.0 - float(r.lost) / maxf(can_lose, 1.0), 0.0, 1.0)
	return clampf(main.castle_hp / maxf(main.castle_max, 1.0), 0.0, 1.0)
