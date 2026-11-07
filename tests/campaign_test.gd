extends SceneTree
## Phase 1 acceptance tests for the story campaign. Run headless:
##   Godot --headless --path . --fixed-fps 60 -s tests/campaign_test.gd
## Prints "ok"/"FAIL" per check, then "FAILS: n". Uses its own save file
## (user://campaign_test.cfg), never the player's campaign, records or settings.
##
## P  persistence     saves, reloads, damaged / missing / newer saves, other files untouched
## U  unlocks         locked troops, emplacements, abilities, castle paths and repairs can't
##                    be used by button, hotkey or direct call; earned and lent ones can
## M  missions        waves, pools, starting gold and allies; winning, losing, retrying,
##                    leaving mid-mission; the map's territory states; story conditions
## D  data            every mission, faction and story entry is well-formed; no Slime
##                    without magic, ki or ice in every alliance set it could meet; no flying enemy
##                    where some valid alliance set would have nothing to hit it with
## T  training       tiers II-IV need training, path by path: enforced by card, hotkey and call;
##                    units earn XP by what they do (losses and early exits count half), each
##                    level is a point, a point opens one path's next tier, 12 max a unit; saved
## C  cutscene        a new campaign opens with the prologue; every scene plays; every named
##                    character's portrait builds
## B  balance         a simple swordsmen-first bot, held to its training, wins each playable
##                    mission on every difficulty
## R  regression      Classic, Freeplay and the title menu behave as before

const CD = preload("res://scripts/campaign_data.gd")
const Maps = preload("res://scripts/maps.gd")
const Data = preload("res://scripts/data.gd")
const TEST_SAVE := "user://campaign_test.cfg"
const AIR_ATTACKS := ["arrow", "frost", "orb", "flask", "note"]   # Data "attack"s that can hit fliers
const AIR_KEYS := ["path:1", "path:2"]   # wall archers and wall mages shoot fliers too
# What can hurt a Slime: magic, ice and ki (Martial Artists' Ki Blast is a tier I path).
const SLIME_ATTACKS := ["orb", "frost", "note", "combo"]
const SLIME_KEYS := ["path:2", "ability:fireball", "ability:lightning", "ability:frost"]

var main
var campaign
var fails := 0
var only := ""   # run just one group (P, U, M, D, B, R): pass it after "--"


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	only = args[0] if args.size() > 0 else ""
	_run()


func _run() -> void:
	await process_frame
	campaign = root.get_node("Campaign")
	campaign.save_path = TEST_SAVE
	_delete_save()
	var guarded := _hash_other_files()
	if _wants("P"):
		await _persistence()
	if _wants("U"):
		await _unlocks()
	if _wants("M"):
		await _missions()
	if _wants("D"):
		_data()
	if _wants("T"):
		await _training()
	if _wants("C"):
		await _cutscene()
	if _wants("B"):
		await _balance()
	if _wants("R"):
		await _regression()
	check(_hash_other_files() == guarded, "P  the Classic records and the settings files were never touched")
	_delete_save()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _wants(group: String) -> bool:
	return only == "" or only == group


# --- Helpers -----------------------------------------------------------------------

func _delete_save() -> void:
	for f in [TEST_SAVE, TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


func _hash_other_files() -> String:
	var out := ""
	for f in ["user://records.cfg", "user://settings.cfg", "user://campaign.cfg"]:
		out += f + ":" + (FileAccess.get_md5(f) if FileAccess.file_exists(f) else "none") + ";"
	return out


## A new main scene, as a reload would make one (it opens where Campaign.screen says).
func _fresh_main() -> void:
	if main != null and is_instance_valid(main):
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame


## Straight into a mission (the map's Defend button), with its intro skipped.
func _play(mission_id: String) -> void:
	await _fresh_main()
	main.hud.hide_mode_select()
	main.start_mission(mission_id)
	await process_frame
	if main.hud.story != null:
		main.hud.story.skip()
	await process_frame


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	main._unhandled_input(ev)


## Ends the current wave at once: nothing left to spawn, every enemy gone.
func _clear_wave() -> void:
	main.spawn_queue.clear()
	for e in main.get_enemies():
		e.free()
	main.enemies_changed()
	await process_frame
	await process_frame


func _win_mission() -> void:
	for i in main.last_wave():
		main.start_wave()
		await _clear_wave()
		if main.game_over:
			break


# --- P: persistence ------------------------------------------------------------------

func _persistence() -> void:
	_delete_save()
	check(not campaign.load_game() and campaign.load_error == "", "P  no save: nothing loads, and that's not an error")
	check(not campaign.has_save(), "P  no save: has_save is false")
	campaign.new_campaign("hard")
	var cfg := ConfigFile.new()
	check(cfg.load(TEST_SAVE) == OK and cfg.get_value("meta", "version", 0) == campaign.VERSION, "P  a new campaign writes a versioned save (v%d)" % campaign.VERSION)
	check(cfg.get_value("state", "difficulty", "") == "hard", "P  the save keeps the chosen difficulty")
	check(not FileAccess.file_exists(TEST_SAVE + ".tmp"), "P  no temporary file is left behind")
	campaign.completed = ["ashwatch", "stonehollow"]
	campaign.allies = ["stonehollow"]
	campaign.flags = {"watchtower_stood": true}
	campaign.seen = ["ashwatch_intro"]
	campaign.save_game()
	campaign.reset()
	check(campaign.allies.is_empty(), "P  reset clears the state in memory")
	check(campaign.load_game(), "P  the save loads back")
	check(campaign.difficulty == "hard" and campaign.completed == ["ashwatch", "stonehollow"] and campaign.allies == ["stonehollow"]
			and campaign.flags.has("watchtower_stood") and campaign.seen == ["ashwatch_intro"], "P  difficulty, missions, allies, flags and seen stories all survive a reload")
	# Damaged, unknown and newer saves.
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string("this is not a config file {{{")
	f.close()
	check(not campaign.load_game() and campaign.load_error != "", "P  a damaged save doesn't load (\"%s\")" % campaign.load_error)
	check(campaign.allies.is_empty() and campaign.completed.is_empty(), "P  ...and leaves a fresh state, not half a campaign")
	cfg = ConfigFile.new()
	cfg.set_value("meta", "version", 1)
	cfg.set_value("state", "allies", ["stonehollow", "atlantis", 42])
	cfg.set_value("state", "completed", ["ashwatch", "no_such_mission"])
	cfg.set_value("state", "difficulty", "impossible")
	cfg.save(TEST_SAVE)
	check(campaign.load_game() and campaign.allies == ["stonehollow"] and campaign.completed == ["ashwatch"] and campaign.difficulty == "normal",
			"P  unknown factions, missions and difficulties in a save are dropped")
	cfg = ConfigFile.new()
	cfg.set_value("meta", "version", 99)
	cfg.set_value("state", "allies", ["stonehollow"])
	cfg.save(TEST_SAVE)
	check(not campaign.load_game() and "newer" in campaign.load_error, "P  a save from a newer version isn't loaded")
	check(not campaign.save_game(), "P  ...and is never overwritten")
	cfg = ConfigFile.new()
	check(cfg.load(TEST_SAVE) == OK and cfg.get_value("meta", "version", 0) == 99, "P  ...it's still there, untouched")
	# A save from version 1 (before troop training) loads, nothing trained.
	cfg = ConfigFile.new()
	cfg.set_value("meta", "version", 1)
	cfg.set_value("state", "completed", ["ashwatch"])
	cfg.save(TEST_SAVE)
	check(campaign.load_game() and campaign.completed == ["ashwatch"] and campaign.unlocked.is_empty() and campaign.xp.is_empty(),
			"P  a version 1 save loads, with nothing trained")
	# A version 2 save (a tier for all four paths; towers shared their crew's) keeps its tiers.
	cfg = ConfigFile.new()
	cfg.set_value("meta", "version", 2)
	cfg.set_value("state", "completed", ["ashwatch"])
	cfg.set_value("state", "training_points", 3)
	cfg.set_value("state", "trained", {"swordsman": 3, "archer": 2})
	cfg.save(TEST_SAVE)
	check(campaign.load_game() and campaign.unlocked.get("swordsman") == [3, 3, 3, 3] and campaign.unlocked.get("archer") == [2, 2, 2, 2]
			and campaign.unlocked.get("tower") == [2, 2, 2, 2] and campaign.points("swordsman") == 0,
			"P  a version 2 save keeps every tier it trained, on all four paths (Archer Towers' too)")
	campaign.save_game()
	cfg = ConfigFile.new()
	cfg.load(TEST_SAVE)
	check(cfg.get_value("meta", "version", 0) == campaign.VERSION, "P  ...and is saved back as version %d" % campaign.VERSION)
	_delete_save()
	campaign.reset()


# --- U: unlock enforcement --------------------------------------------------------------

func _unlocks() -> void:
	campaign.new_campaign("normal")
	await _play("ashwatch")
	check(main.campaign and main.started, "U  Ashwatch starts as a campaign battle")
	var gold0: int = main.gold
	# Troops: Swordsmen only.
	main._on_hire_pressed("swordsman")
	main.hire_at(Vector2(200, 480))
	check(main.gold == gold0 - main.hire_cost("swordsman"), "U  a Swordsman can be hired")
	main._on_hire_pressed("archer")
	check(main.placing_type == "", "U  the Archer button does nothing (locked)")
	main.hud.hire_tab = "troops"
	_key(KEY_2)   # the Archer's hotkey
	check(main.placing_type == "", "U  ...nor does its hotkey, 2")
	main.placing_type = "archer"   # even if something sets it directly
	var n: int = main.get_warriors().size()
	main.hire_at(Vector2(300, 480))
	check(main.get_warriors().size() == n and main.placing_type == "", "U  ...and hire_at refuses a locked kind outright")
	for kind in ["mage", "frost", "martial", "healer", "bard", "alchemist"]:
		main._on_hire_pressed(kind)
	check(main.placing_type == "", "U  every other troop is locked too")
	# Emplacements and barricades.
	main.hud.hire_tab = "emplacements"
	for i in 8:
		_key(KEY_1 + i)
	main._on_hire_pressed("barricade")
	check(main.placing_type == "", "U  no emplacement or barricade can be picked, by button or hotkeys 1-8")
	# Abilities.
	main.hud.hire_tab = "abilities"
	for i in 6:
		_key(KEY_1 + i)
	for key in Data.ABILITIES:
		main.ability_item(key)
	check(main.powers.owned.is_empty() and main.gold == gold0 - main.hire_cost("swordsman"), "U  no ability can be bought, by button or hotkeys 1-6")
	# Castle paths: by card, by number key and by Q/W/E/R with the castle selected.
	main.select_castle()
	for p in 4:
		main.castle_upgrade(p)
	for i in 4:
		_key(KEY_1 + i)
	for k in [KEY_Q, KEY_W, KEY_E, KEY_R]:
		_key(k)
	check(main.powers.tiers == [0, 0, 0, 0], "U  no castle path can be bought: cards, 1-4 or Q/W/E/R")
	main._cancel()
	# Repairs.
	main.castle_hp = main.castle_max * 0.5
	main.hud.hire_tab = "repair"
	_key(KEY_1)
	main.repair_castle(3)
	check(main.repair_job.is_empty() and not main.can_repair(0), "U  the castle can't be repaired")
	# The HUD shows it all as locked.
	main.hud.refresh(main)
	check(main.hud.hire_buttons["archer"].disabled and main.hud.hire_buttons["archer"].modulate.a < 1.0
			and not main.hud.hire_buttons["swordsman"].disabled, "U  the HUD greys out locked hires, not the Swordsman")
	check(main.hud.ability_buttons["arrows"].disabled and main.hud.castle_cards[0]["cost"].text == "LOCKED"
			and main.hud.repair_buttons[0].disabled, "U  ...and locked abilities, castle paths and repairs")
	check("Woodland Watch" in main.lock_note("archer") and "Engineers" in main.lock_note("path:0"), "U  locks say who unlocks them")
	# A mission's lent help: Stonehollow lends barricades, repairs and Engineers.
	await _play("stonehollow")
	check(main.allowed("barricade") and main.allowed("repair"), "U  Stonehollow's mission lends barricades and repairs")
	check(not main.allowed("tower") and not main.allowed("path:0") and not main.allowed("archer"), "U  ...but not towers, Fortify or archers")
	main._on_hire_pressed("barricade")
	main.hire_at(Vector2(200, 480))
	main.hire_at(Vector2(360, 480))
	check(main.get_barricades().size() == 1, "U  a barricade can be built there")
	# Once Stonehollow has joined: its unlocks everywhere, emplacements still need their people.
	campaign.allies = ["stonehollow"]
	campaign.completed = ["ashwatch", "stonehollow"]
	await _play("ashwatch")
	check(main.allowed("barricade") and main.allowed("repair") and main.allowed("path:0"), "U  after Stonehollow joins: barricades, repairs and Fortify are open in every mission")
	check(not main.allowed("tower") and not main.allowed("path:1") and not main.allowed("ability:arrows"), "U  ...Archer Towers, Wall Archers and Arrow Storm still wait for Greenwood")
	campaign.allies = ["stonehollow", "greenwood"]
	check(main.allowed("tower") and main.allowed("archer") and main.allowed("ability:arrows"), "U  with Greenwood too: Archers, Archer Towers and Arrow Storm")
	campaign.allies = ["greenwood"]
	check(main.allowed("archer") and not main.allowed("tower"), "U  Greenwood without the Engineers: Archers, but no towers to put them in")
	campaign.reset()


# --- M: missions ---------------------------------------------------------------------

func _missions() -> void:
	campaign.new_campaign("normal")
	check(campaign.territory_state("ashwatch") == "attack" and campaign.territory_state("stonehollow") == "hidden"
			and campaign.territory_state("dawnspire") == "locked" and campaign.territory_state("greenwood") == "hidden",
			"M  a new campaign: Ashwatch under attack, Dawnspire known but locked, the rest undiscovered")
	await _fresh_main()
	main.hud.hide_mode_select()
	main.start_mission("ashwatch")
	await process_frame
	check(main.hud.story != null, "M  Ashwatch opens with its story")
	main.hud.story.advance()
	main.hud.story.advance()
	_key(KEY_SPACE)
	check(main.wave == 0, "M  ...and the game ignores keys while the story is up")
	main.hud.story.skip()
	await process_frame
	check(main.hud.story == null and campaign.seen.has("ashwatch_intro"), "M  the story can be skipped, and is remembered as seen")
	var m: Dictionary = CD.MISSIONS["ashwatch"]
	check(main.gold == m["gold"] and main.last_wave() == m["waves"] and main.wave == 0, "M  starting gold %d, %d waves" % [m["gold"], m["waves"]])
	var kinds: Array = main.get_warriors().map(func(w): return w.kind)
	check(kinds.count("tower") == 1 and kinds.count("swordsman") == 2, "M  the garrison's watchtower and two swordsmen are on the field")
	check(main.get_warriors().all(func(w): return w.sell_value() == 0), "M  ...and are on loan: selling them pays nothing")
	# Waves come from the mission's pool, at the mission's level.
	var w1: Array = main._build_wave(1)
	check(w1.size() == m["count"][0] + m["count"][1] and w1.all(func(k): return k == "goblin"), "M  wave 1: %d goblins" % w1.size())
	var w4: Array = main._build_wave(4)
	check(w4.count("orc") >= 2 and w4.count("troll") == m["extra"][4].count("troll") and not w4.has("bat") and not w4.has("warlord"),
			"M  wave 4 adds its orcs and its trolls; no bats or warlords")
	check(main.wave_level(1) == m["level"], "M  enemies start at level %d" % m["level"])
	main.hud.refresh(main)
	check(main.hud.wave_label.text == "Wave 0/%d" % m["waves"], "M  the HUD counts waves out of %d" % m["waves"])
	# Leaving mid-mission changes nothing.
	main.start_wave()
	var before := FileAccess.get_md5(TEST_SAVE)
	main.back_to_map()
	check(campaign.screen == "map" and campaign.completed.is_empty() and FileAccess.get_md5(TEST_SAVE) == before, "M  leaving mid-mission for the map changes nothing")
	await _fresh_main()
	check(main.hud.world_map != null, "M  ...and the reload opens the map")
	# Losing.
	await _play("ashwatch")
	main.start_wave()
	main.damage_castle(99999)
	check(main.game_over and not main.victory and campaign.completed.is_empty(), "M  losing ends the battle and records nothing")
	check(not campaign.flags.has("watchtower_stood"), "M  ...and sets no story flags")
	main.retry_mission()
	check(campaign.screen == "battle", "M  Try again reloads into the same mission")
	await _fresh_main()
	check(main.campaign and main.mission["name"] == m["name"] and main.gold == m["gold"] and main.wave == 0 and main.castle_hp == main.castle_max,
			"M  ...with its starting gold, wave 0 and a whole castle")
	check(main.hud.story == null, "M  ...and without replaying the intro")
	# Winning.
	await _win_mission()
	check(main.game_over and main.victory, "M  clearing the last wave wins (no endless offer)")
	check(campaign.completed == ["ashwatch"] and campaign.allies.is_empty(), "M  Ashwatch is recorded as won (it brings no faction)")
	check(campaign.flags.has("watchtower_stood"), "M  the watchtower stood, so its story flag is set")
	var cfg := ConfigFile.new()
	cfg.load(TEST_SAVE)
	check((cfg.get_value("state", "completed", []) as Array).has("ashwatch"), "M  ...and saved straight away")
	check(campaign.territory_state("ashwatch") == "allied" and campaign.territory_state("stonehollow") == "attack", "M  Stonehollow is discovered and under attack")
	check(campaign.pending_story == "ashwatch_outro", "M  the map will play Ashwatch's outro")
	main.back_to_map()
	await _fresh_main()
	check(main.hud.world_map != null and main.hud.world_map.overlay != null, "M  the map opens with the outro playing")
	var lines: Array = campaign.story_lines("ashwatch_outro")
	check(lines.any(func(l): return "held the whole time" in l["text"]) and not lines.any(func(l): return "lost the watchtower" in l["text"]),
			"M  the outro picks the line for a watchtower that stood")
	check(campaign.story_lines("stonehollow_intro").size() == CD.STORY["stonehollow_intro"].size(), "M  Stonehollow's intro includes the watchtower lines")
	campaign.flags.erase("watchtower_stood")
	check(campaign.story_lines("stonehollow_intro").size() == CD.STORY["stonehollow_intro"].size() - 2, "M  ...and leaves them out when it fell")
	# Stonehollow: the Engineers join.
	await _play("stonehollow")
	await _win_mission()
	check(campaign.allies == ["stonehollow"] and campaign.just_joined == "stonehollow", "M  winning Stonehollow brings the Engineers' Guild into the Line")
	for t in ["greenwood", "mercyvale", "deepdelve"]:
		check(campaign.territory_state(t) == "available", "M  %s opens up (no battle there until Phase 3)" % t)
	check(campaign.territory_state("sable") == "hidden", "M  Sable Crossing is still undiscovered")
	main.back_to_map()
	await _fresh_main()
	var map = main.hud.world_map
	if map.overlay.has_method("skip"):
		map.overlay.skip()
	await process_frame
	check(map.overlay != null, "M  after the outro, the map announces who joined")
	map.select("greenwood")
	check(map.info["defend"].disabled, "M  a territory with no battle yet can't be defended")
	map.select("ashwatch")
	check(map.info["defend"].disabled, "M  ...nor one already won")
	# Any 2 of 3 southern territories opens Sable Crossing (checked on the data, ahead of Phase 3).
	campaign.completed = ["ashwatch", "stonehollow"]
	check(_sable_opens_with(["greenwood", "deepdelve"]) and _sable_opens_with(["mercyvale", "greenwood"]) and not _sable_opens_with(["deepdelve"]),
			"M  Sable Crossing needs any two of Greenwood, Mercy Vale and Deepdelve")
	campaign.reset()


## Whether Sable Crossing's requirements hold with these southern territories won.
func _sable_opens_with(won: Array) -> bool:
	var req: Dictionary = CD.TERRITORIES["sable"]["requires"]
	var n := 0
	for r in req["any"]:
		if won.has(r):
			n += 1
	return n >= req["count"]


# --- D: data -----------------------------------------------------------------------------

func _data() -> void:
	var problems := []
	for f in CD.FACTIONS:
		for key in CD.FACTIONS[f]["unlocks"]:
			if not _valid_key(key):
				problems.append("%s unlocks unknown %s" % [f, key])
	for t in CD.TERRITORIES:
		var d: Dictionary = CD.TERRITORIES[t]
		if d["faction"] != "" and not CD.FACTIONS.has(d["faction"]):
			problems.append("%s: unknown faction" % t)
		for r in d["requires"].get("all", []) + d["requires"].get("any", []):
			if not CD.TERRITORIES.has(r):
				problems.append("%s requires unknown %s" % [t, r])
		for mid in d["missions"]:
			if not CD.MISSIONS.has(mid) or CD.MISSIONS[mid]["territory"] != t:
				problems.append("%s: bad mission %s" % [t, mid])
	for r in CD.ROUTES:
		if not CD.TERRITORIES.has(r[0]) or not CD.TERRITORIES.has(r[1]):
			problems.append("bad route %s" % str(r))
	for mid in CD.MISSIONS:
		var m: Dictionary = CD.MISSIONS[mid]
		for w in m["pool"]:
			for e in m["pool"][w]:
				if not Data.ENEMIES.has(e):
					problems.append("%s: unknown enemy %s" % [mid, e])
		for w in m.get("extra", {}):
			for e in m["extra"][w]:
				if not Data.ENEMIES.has(e):
					problems.append("%s: unknown enemy %s" % [mid, e])
			if int(w) > m["waves"]:
				problems.append("%s: extras on wave %d of %d" % [mid, w, m["waves"]])
		if not m["pool"].has(1):
			problems.append("%s: nothing to send on wave 1" % mid)
		for a in m.get("allies", []):
			if not Data.WARRIORS.has(a["kind"]):
				problems.append("%s: unknown ally %s" % [mid, a["kind"]])
			elif a["at"].x < 0 or a["at"].x > 640 or a["at"].y < 96 or a["at"].y > 736:
				problems.append("%s: ally off the field" % mid)
		for key in m.get("lend", []):
			if key != CD.LEND_BUILDERS and not _valid_key(key):
				problems.append("%s lends unknown %s" % [mid, key])
		if m["reward"] != "" and not CD.FACTIONS.has(m["reward"]):
			problems.append("%s: unknown reward" % mid)
		for k in ["intro", "outro"]:
			if m.get(k, "") != "" and not CD.STORY.has(m[k]):
				problems.append("%s: no story %s" % [mid, m[k]])
	for key in CD.STORY:
		for line in CD.STORY[key]:
			if not CD.SPEAKERS.has(line["who"]):
				problems.append("%s: unknown speaker %s" % [key, line["who"]])
	check(problems.is_empty(), "D  campaign data is well-formed%s" % ("" if problems.is_empty() else ": " + "; ".join(problems)))
	# Flying enemies only where every valid alliance set (plus the mission's own help)
	# has something that can hit them.
	# Likewise Slimes, which only magic, ki and ice can hurt.
	var air_problems := []
	var slime_problems := []
	var sets_checked := 0
	for mid in CD.MISSIONS:
		var m: Dictionary = CD.MISSIONS[mid]
		var fliers := false
		var slimes := false
		for list in m["pool"].values() + m.get("extra", {}).values():
			for e in list:
				fliers = fliers or Data.ENEMIES[e].get("flying", false)
				slimes = slimes or Data.ENEMIES[e].get("gooey", false)
		for allies in alliance_sets_for(m["territory"]):
			sets_checked += 1
			if fliers and not _has_cover(allies, m, AIR_KEYS, AIR_ATTACKS):
				air_problems.append("%s with %s" % [mid, str(allies)])
			if slimes and not _has_cover(allies, m, SLIME_KEYS, SLIME_ATTACKS):
				slime_problems.append("%s with %s" % [mid, str(allies)])
	check(air_problems.is_empty(), "D  no flying enemies without anti-air (%d alliance sets checked)%s" % [sets_checked, "" if air_problems.is_empty() else ": " + ", ".join(air_problems)])
	check(slime_problems.is_empty(), "D  no Slimes without magic, ki or ice to fight them%s" % ("" if slime_problems.is_empty() else ": " + ", ".join(slime_problems)))
	# The check itself: a mission with Slimes and only Swordsmen fails it; lend a Mage and it passes.
	check(not _has_cover([], {"lend": []}, SLIME_KEYS, SLIME_ATTACKS) and _has_cover([], {"lend": ["mage"]}, SLIME_KEYS, SLIME_ATTACKS),
			"D  ...(Swordsmen alone can't fight Slimes; a lent Mage can)")


func _valid_key(key: String) -> bool:
	if key.begins_with("ability:"):
		return Data.ABILITIES.has(key.substr(8))
	if key.begins_with("path:"):
		return int(key.substr(5)) >= 0 and int(key.substr(5)) < Data.CASTLE_PATHS.size()
	return key == "repair" or Data.WARRIORS.has(key)


## Every set of factions the player could have when territory t's mission is up: each
## combination of won territories that's reachable (everything won had its requirements
## met by the rest) with t open and not yet won.
func alliance_sets_for(t: String) -> Array:
	var names: Array = CD.TERRITORIES.keys()
	var out := []
	var seen := {}
	for mask in 1 << names.size():
		var won := []
		for i in names.size():
			if mask & (1 << i):
				won.append(names[i])
		if won.has(t) or not _consistent(won) or not _met(t, won):
			continue
		var allies := []
		for w in won:
			if CD.TERRITORIES[w]["faction"] != "":
				allies.append(CD.TERRITORIES[w]["faction"])
		allies.sort()
		if not seen.has(str(allies)):
			seen[str(allies)] = true
			out.append(allies)
	return out


func _met(t: String, won: Array) -> bool:
	var req: Dictionary = CD.TERRITORIES[t]["requires"]
	for r in req.get("all", []):
		if not won.has(r):
			return false
	if req.has("any"):
		var n := 0
		for r in req["any"]:
			if won.has(r):
				n += 1
		if n < req.get("count", 1):
			return false
	return true


func _consistent(won: Array) -> bool:
	for w in won:
		if not _met(w, won):
			return false
	return true


func _has_cover(allies: Array, m: Dictionary, cover_keys: Array, attacks: Array) -> bool:
	var keys: Array = CD.START_UNLOCKS.duplicate() + m.get("lend", [])
	for f in allies:
		keys.append_array(CD.FACTIONS[f]["unlocks"])
	for a in m.get("allies", []):
		keys.append(a["kind"])
	for k in keys:
		if cover_keys.has(k) or (Data.WARRIORS.has(k) and attacks.has(Data.WARRIORS[k].get("attack", ""))):
			return true
	return false


# --- T: troop training -------------------------------------------------------------------

func _training() -> void:
	campaign.new_campaign("normal")
	check(campaign.level_of("swordsman") == 0 and campaign.points("swordsman") == 0 and campaign.path_tier("swordsman", 0) == 1,
			"T  a new campaign: level 0, no points, tier I only")
	check(campaign.trainable() == ["swordsman"], "T  only the Swordsmen can be trained at the start")
	check(not campaign.can_unlock("swordsman", 0) and not campaign.unlock("swordsman", 0), "T  no points, no training")
	await _play("ashwatch")
	main.gold = 99999
	main._on_hire_pressed("swordsman")
	main.hire_at(Vector2(300, 470))
	var w = main.get_warriors().filter(func(x): return x.kind == "swordsman" and x.spent > 0)[0]
	main.selected = w
	_key(KEY_Q)
	check(w.tiers[0] == 1, "T  tier I can be bought (Q)")
	var gold: int = main.gold
	_key(KEY_Q)
	main.upgrade_selected(0)
	check(w.tiers[0] == 1 and main.gold == gold, "T  tier II can't, by Q or directly, and costs nothing")
	check(w.path_state(0) == "untrained" and w.path_state(1) == "ok", "T  the path shows as needing training; untouched paths are still open")
	main.hud.refresh(main)
	check(main.hud.path_cards[0]["cost"].text == "TRAINING" and main.hud.path_cards[0]["button"].disabled
			and "Training Grounds" in main.hud.path_cards[0]["desc"].text, "T  the upgrade card says to open it at the Training Grounds")
	# Fighting earns the Swordsmen XP; winning banks all of it.
	main.selected = null
	w.position = w.post
	main.wave_active = true
	main._spawn_enemy("orc", 3, w.position + Vector2(0, -40))
	for f in 60 * 4:
		await process_frame
	main.wave_active = false
	await _win_mission()
	var fought: float = main.battle_xp.get("swordsman", 0.0)
	check(fought > 0.0 and is_equal_approx(campaign.xp.get("swordsman", 0.0), fought), "T  the Swordsmen's fighting earned them %d XP, all banked on a win" % roundi(fought))
	check(campaign.last_battle.has("swordsman") and not main.battle_xp.has("castle") and not main.battle_xp.has(""), "T  ...and the map is told what they earned")
	print("   (Ashwatch XP by unit: %s)" % str(main.battle_xp))
	# Points from levels, spent a path at a tier.
	campaign.xp["swordsman"] = campaign.level_cost(1) + campaign.level_cost(2) + 1.0
	check(campaign.level_of("swordsman") == 2 and campaign.points("swordsman") == 2, "T  two levels: two points")
	check(campaign.unlock("swordsman", 0) and campaign.path_tier("swordsman", 0) == 2 and campaign.points("swordsman") == 1, "T  a point opens tier II of one path")
	check(campaign.unlock("swordsman", 0) and campaign.path_tier("swordsman", 0) == 3, "T  ...and the next point tier III of the same path")
	check(campaign.points("swordsman") == 0 and not campaign.unlock("swordsman", 1) and campaign.path_tier("swordsman", 1) == 1, "T  out of points, the other paths stay at tier I")
	check(not campaign.can_unlock("archer", 0), "T  Archers can't be trained before Greenwood joins")
	var cfg := ConfigFile.new()
	cfg.load(TEST_SAVE)
	check(cfg.get_value("state", "unlocked", {}).get("swordsman", []) == [3, 1, 1, 1] and cfg.get_value("state", "spent", {}).get("swordsman", 0) == 2,
			"T  training is saved")
	await _play("stonehollow")
	main.gold = 99999
	main._on_hire_pressed("swordsman")
	main.hire_at(Vector2(226, 560))
	w = main.get_warriors().filter(func(x): return x.kind == "swordsman" and x.spent > 0)[0]
	main.selected = w
	for i in 4:
		main.upgrade_selected(0)
	main.upgrade_selected(1)
	main.upgrade_selected(1)
	check(w.tiers[0] == 3 and w.tiers[1] == 1, "T  in the next battle: path 1 goes to tier III (not IV), path 2 stops at tier I")
	main.selected = null
	# Twelve points train a unit fully, and no more.
	campaign.xp["swordsman"] = 1e9
	check(campaign.level_of("swordsman") == CD.MAX_TRAINING and campaign.points("swordsman") == 10, "T  at the top level: 12 points, 2 of them spent")
	var opened := 0
	for p in 4:
		while campaign.unlock("swordsman", p):
			opened += 1
	check(opened == 10 and campaign.untrained_tiers("swordsman") == 0 and campaign.points("swordsman") == 0 and not campaign.can_unlock("swordsman", 2),
			"T  ...which open every tier of every path, and that's all")
	# Losing (or leaving) banks half.
	campaign.xp["archer"] = 0.0
	campaign.mission_id = "stonehollow"
	campaign.finish_mission(false, [], {"archer": 1000.0})
	check(is_equal_approx(campaign.xp["archer"], 1000.0 * CD.XP_LOSS_SHARE), "T  a lost battle banks %d%% of its XP" % roundi(CD.XP_LOSS_SHARE * 100))
	main.battle_xp = {"archer": 400.0}
	main.back_to_map()
	check(is_equal_approx(campaign.xp["archer"], 1000.0 * CD.XP_LOSS_SHARE + 400.0 * CD.XP_LOSS_SHARE), "T  leaving a battle early banks half of it too")
	# Who gets the credit: an Archer's arrows, a Healer's mending, a Mine's gold, a burn
	# for whoever lit it; the castle's own abilities train no one.
	campaign.new_campaign("normal")
	campaign.completed = ["ashwatch"]
	await _play("stonehollow")
	campaign.allies = CD.FACTIONS.keys()
	main.gold = 99999
	for x in main.get_warriors():
		x.free()
	main.warriors_changed()
	var archer = _hire_at("archer", Vector2(320, 560))
	var healer = _hire_at("healer", Vector2(260, 600))
	var hurt = _hire_at("swordsman", Vector2(380, 600))
	var mine = _hire_at("mine", Vector2(220, 660))
	mine.finish_build()
	hurt.max_hp = 1e5
	hurt.hp = 1e4
	main.wave_active = true
	main._spawn_enemy("orc", 3, Vector2(320, 430))
	var orc = main.get_enemies()[0]
	orc.max_hp = 1e5
	orc.hp = 1e5
	orc.speed = 0.0
	for f in 60 * 8:
		await process_frame
	check(main.battle_xp.get("archer", 0.0) > 0.0, "T  an Archer's arrows train Archers (%d XP)" % roundi(main.battle_xp.get("archer", 0.0)))
	check(main.battle_xp.get("healer", 0.0) > 0.0, "T  a Healer's mending trains Healers (%d XP)" % roundi(main.battle_xp.get("healer", 0.0)))
	check(main.battle_xp.get("mine", 0.0) > 0.0, "T  a Gold Mine's gold trains Gold Mines (%d XP)" % roundi(main.battle_xp.get("mine", 0.0)))
	var before: Dictionary = main.battle_xp.duplicate()
	main.credit = "alchemist"
	orc.apply_burn(50.0, 1.0)
	main.credit = "archer"
	for f in 30:
		await process_frame
	check(main.battle_xp.get("alchemist", 0.0) > before.get("alchemist", 0.0), "T  a burn counts for whoever set it, as it burns")
	before = main.battle_xp.duplicate()
	var total_before := 0.0
	for k in before:
		total_before += before[k]
	archer.free()
	healer.free()
	main.warriors_changed()
	main.powers.owned["fireball"] = true
	main.powers.cooldown["fireball"] = 0.0
	main.powers.trigger("fireball")
	main.powers.aim_click(orc.position)
	for f in 90:
		await process_frame
	var total_after := 0.0
	for k in main.battle_xp:
		total_after += main.battle_xp[k]
	check(orc.hp < 1e5 and absf(total_after - total_before) < 200.0 * CD.XP_RATES["gold"] + 1.0 and not main.battle_xp.has(""), "T  the castle's Fireball trains no one")
	# Classic earns nothing.
	await _fresh_main()
	main.hud.picking = true
	main.choose_mode("normal")
	main.gold = 9999
	main._on_hire_pressed("swordsman")
	main.hire_at(Vector2(320, 600))
	main.wave_active = true
	main._spawn_enemy("goblin", 1, Vector2(320, 560))
	for f in 120:
		await process_frame
	check(main.battle_xp.is_empty(), "T  Classic earns no XP")
	main.free()
	main = null
	campaign.reset()


func _hire_at(kind: String, at: Vector2):
	main.placing_type = kind
	main.hire_at(at)
	main.placing_type = ""
	main.selected = null
	var all: Array = main.get_warriors().filter(func(x): return x.kind == kind)
	var w = all[all.size() - 1]
	w.position = w.post
	return w


# --- C: the prologue and portraits ---------------------------------------------------------

func _cutscene() -> void:
	campaign.reset()
	_delete_save()
	await _fresh_main()
	main._on_mode_chosen("campaign:new:normal")
	await process_frame
	var cut = main.hud.story
	check(cut != null and cut.get_script().resource_path.ends_with("cutscene.gd"), "C  a new campaign opens with the prologue")
	check(main.hud.world_map == null, "C  ...before the map")
	# Play every scene through (each a second of drawing, then on).
	var shown := []
	while is_instance_valid(cut) and not cut.is_queued_for_deletion():
		shown.append(cut._scene().get("scene", ""))
		for i in 30:
			await process_frame
		cut.advance()
		cut.advance()
		for i in 25:
			await process_frame
	check(shown.size() >= CD.PROLOGUE.size(), "C  all %d scenes played: %s" % [CD.PROLOGUE.size(), ", ".join(shown.slice(0, 4)) + "..."])
	check(shown.count("nation") == 8, "C  ...one for each of the eight peoples")
	await process_frame
	check(main.hud.world_map != null and main.hud.story == null, "C  the map opens after it")
	# Esc skips straight to the map.
	await _fresh_main()
	main._on_mode_chosen("campaign:new:hard")
	await process_frame
	main.hud.story.skip()
	await process_frame
	check(main.hud.world_map != null and campaign.difficulty == "hard", "C  skipping it goes straight to the map")
	# The Ledger can replay it.
	main.hud.world_map.prologue.emit()
	await process_frame
	check(main.hud.story != null and main.hud.world_map == null, "C  the Ledger's Replay button plays it again")
	main.hud.story.skip()
	await process_frame
	# Every named character has their own portrait.
	var Portraits = load("res://scripts/portraits.gd")
	var hashes := {}
	for id in CD.SPEAKERS:
		var img: Image = Portraits.image(CD.SPEAKERS[id]["look"])
		hashes[img.get_data().hex_encode().md5_text()] = id
		if img.get_width() != 32:
			check(false, "C  %s's portrait is 32x32" % id)
	check(hashes.size() == CD.SPEAKERS.size(), "C  all %d named characters have distinct portraits" % CD.SPEAKERS.size())
	var leaders := []
	for f in CD.FACTIONS:
		leaders.append(CD.FACTIONS[f]["leader"])
	check(leaders.all(func(l): return CD.SPEAKERS.has(l)), "C  every people has a named leader")
	main.free()
	main = null
	campaign.reset()


# --- B: balance bot ----------------------------------------------------------------------

## A plain bot: hires Swordsmen in a line across the field (on a map with terrain, at its
## chokepoints), upgrades them as far as their training allows between waves, repairs if it can, and starts the next wave. It's no
## good at the game, so a mission it wins with Swordsmen alone is one a player can win.
## Each mission is tried untrained (the worst case: the player spent nothing on it), and
## Stonehollow also with two points in the Swordsmen (tier II of Damage and Health: about
## what a Swordsmen-heavy Ashwatch earns).
func _balance() -> void:
	for diff in ["easy", "normal", "hard"]:
		for run in [["ashwatch", 1], ["stonehollow", 1], ["stonehollow", 2]]:
			var mid: String = run[0]
			campaign.new_campaign(diff)
			if mid == "stonehollow":
				campaign.completed = ["ashwatch"]
			campaign.unlocked = {"swordsman": [run[1], 1, run[1], 1]}
			await _play(mid)
			Engine.time_scale = 4.0
			var guard := 0
			while not main.game_over and guard < 60 * 60 * 10:
				if not main.wave_active:
					_bot_spend()
					main.start_wave()
				await process_frame
				guard += 1
			Engine.time_scale = 1.0
			print("   %s %s: XP earned %s" % [mid, diff, str(main.battle_xp)])
			check(main.victory, "B  %s on %s, Swordsmen tier %s: the bot %s (castle %d/%d, %d troops left)" % [CD.MISSIONS[mid]["name"], diff, ["I", "II"][run[1] - 1],
					"wins" if main.victory else "LOSES on wave %d" % main.wave, ceili(main.castle_hp), roundi(main.castle_max),
					main.get_warriors().filter(func(w): return w.kind == "swordsman" and w.is_active()).size()])
	campaign.reset()


func _bot_spend() -> void:
	# Repair first (where repairs are lent), then fill the line, then upgrade.
	if main.allowed("repair") and main.castle_hp < main.castle_max * 0.6:
		for i in [2, 1, 0]:
			if main.can_repair(i):
				main.repair_castle(i)
				break
	# Fill any empty spot in the line (a Swordsman lost for good leaves a gap). On a
	# battlefield with terrain the line holds the map's chokepoints (its bot_posts).
	var spots := []
	var map: Dictionary = Maps.get_map(main.mission.get("map", ""))
	if map.has("bot_posts"):
		spots = map["bot_posts"].slice(0, 7)
	else:
		for i in 7:
			spots.append(Vector2(60.0 + i * (520.0 / 6.0), 420.0 + (i % 2) * 40.0))
	for spot in spots:
		if main.gold < main.hire_cost("swordsman"):
			break
		if main.can_post_at(spot):
			main._on_hire_pressed("swordsman")
			main.hire_at(spot)
	var troops: Array = main.get_warriors().filter(func(w): return w.kind == "swordsman")
	var spent := true
	while spent:
		spent = false
		for w in troops:
			if not is_instance_valid(w) or not w.is_active():
				continue
			for path in [0, 2, 1, 3]:
				main.selected = w
				var before: int = main.gold
				main.upgrade_selected(path)
				spent = spent or main.gold < before
	main.selected = null


# --- R: regression ------------------------------------------------------------------------

func _regression() -> void:
	campaign.reset()
	_delete_save()
	await _fresh_main()
	var hud = main.hud
	await create_timer(0.8).timeout
	var names: Array = hud.mode_cards.map(func(c): return (c.get_child(0) as Label).text)
	check(names == ["Campaign", "Classic", "Freeplay", "Tutorial", "Settings"], "R  the title menu: %s" % ", ".join(names))
	hud._show_cards("classic")
	names = hud.mode_cards.map(func(c): return (c.get_child(0) as Label).text)
	check(names == ["Easy", "Normal", "Hard", "Back"], "R  Classic opens the three difficulties: %s" % ", ".join(names))
	hud._show_cards("campaign")
	names = hud.mode_cards.map(func(c): return (c.get_child(0) as Label).text)
	check(names == ["New", "Back"], "R  Campaign with no save: %s" % ", ".join(names))
	# Classic plays as before: everything open, 20 waves, the endless offer.
	await _fresh_main()
	main.hud.hide_mode_select()
	main.choose_mode("normal")
	check(not main.campaign and main.mission.is_empty() and main.gold == Data.START_GOLD, "R  Classic Normal: not a campaign, %d starting gold" % Data.START_GOLD)
	var all_open := true
	for k in Data.WARRIORS:
		all_open = all_open and main.allowed(k)
	for k in Data.ABILITIES:
		all_open = all_open and main.allowed("ability:" + k)
	for p in 4:
		all_open = all_open and main.allowed("path:%d" % p)
	check(all_open and main.allowed("repair"), "R  ...every unit, ability, castle path and repair is open")
	main._on_hire_pressed("archer")
	main.hire_at(Vector2(300, 480))
	check(main.get_warriors().size() == 1 and main.get_warriors()[0].kind == "archer", "R  ...an Archer can be hired")
	main.hud.hire_tab = "abilities"
	main.gold = 5000
	_key(KEY_1)
	check(main.powers.owned.has("arrows"), "R  ...the ability hotkeys still buy")
	check(main.last_wave() == Data.FINAL_WAVE and main._build_wave(5).has("warlord") and main.wave_level(7) == 7, "R  ...20 waves, Classic's wave mix and levels")
	main.hud.refresh(main)
	check(main.hud.wave_label.text == "Wave 0/20", "R  ...the HUD counts to 20")
	main.wave = Data.FINAL_WAVE - 1
	main.start_wave()
	await _clear_wave()
	if main.wave_active:   # the Ogre King came out: beat him too
		await _clear_wave()
	check(main.choosing and not main.game_over, "R  ...clearing wave 20 offers endless, as before")
	check(get_root().content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "R  ...and the field still widens with the window")
	# Freeplay.
	await _fresh_main()
	main.hud.hide_mode_select()
	main.choose_mode("freeplay")
	check(main.freeplay and not main.campaign and main.gold == main.FREEPLAY_GOLD and main.allowed("magetower"), "R  Freeplay: free gold, everything open")
	# The campaign keeps a portrait field.
	campaign.new_campaign("normal")
	await _play("ashwatch")
	check(get_root().content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP and main.FIELD_W == 640, "R  a campaign battle keeps the 640-wide field")
	main.free()
	main = null
	campaign.reset()
