extends SceneTree
## Regional campaigns: chains of missions, a people joining before the region is secured,
## beacons, the gates they open, and Tier IV training locked behind the home region's
## beacon. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/progression_test.gd
## Uses a temporary save. Exits 1 if anything failed.

const CD = preload("res://scripts/campaign_data.gd")
const TEST_SAVE := "user://progression_test.cfg"

var campaign
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	campaign = root.get_node("Campaign")
	campaign.save_path = TEST_SAVE
	_real_data()
	_south()
	_chains()
	_gates()
	_tier4()
	_south_training()
	_north_gate()
	_replay_xp()
	_saves()
	_slots()
	await _screens()
	campaign.territories = CD.TERRITORIES
	campaign.missions = CD.MISSIONS
	campaign.reset()
	for f in [TEST_SAVE, TEST_SAVE + ".tmp", "user://progression_test_2.cfg", "user://progression_test_3.cfg"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _win(m: String) -> void:
	campaign.mission_id = m
	campaign.finish_mission(true)


## The south, as it ships: each region a chain (join on the first mission, the beacon on
## the last), and every pair of southern beacons (with Ashwatch's and Stonehollow's)
## opening Sable Crossing, whose win opens the north.
func _south() -> void:
	campaign.territories = CD.TERRITORIES
	campaign.missions = CD.MISSIONS
	var chains := {"greenwood": ["gw_exodus", "gw_watchfires"], "mercyvale": ["mv_wounded", "mv_sanctuary"], "deepdelve": ["dd_entrance", "dd_orerun"]}
	for pair in [["greenwood", "mercyvale"], ["greenwood", "deepdelve"], ["mercyvale", "deepdelve"]]:
		campaign.new_campaign("normal")
		for m in ["ashwatch", "stonehollow", "ashwatch_road", "stonehollow_workshops"]:
			_win(m)
		var ok := true
		for t in pair:
			ok = ok and campaign.playable_mission(t) == chains[t][0]
			_win(chains[t][0])
			ok = ok and campaign.allied(t) and not campaign.beacon_lit(t) and campaign.playable_mission(t) == chains[t][1]
			_win(chains[t][1])
			ok = ok and campaign.beacon_lit(t)
		ok = ok and campaign.territory_state("sable") == "attack" and campaign.playable_mission("sable") == "sable_crossing"
		var lit_before: int = campaign.beacon_count()
		_win("sable_crossing")
		ok = ok and campaign.territory_state("sable") == "secured" and campaign.requirements_met("frostmarch")
		check(ok, "South: %s and %s, each joined then their beacon lit, open Sable Crossing; its win opens the north" % pair)
		check(not campaign.has_beacon("sable") and not campaign.beacon_lit("sable") and campaign.just_lit == "" and campaign.beacon_count() == lit_before,
				"...Sable Crossing is only the bridge: held, but no beacon is lit there")
	check(campaign.beacon_territories().size() == 9 and not campaign.beacon_territories().has("sable"), "Nine beacons: Ashwatch's and the eight peoples', none at Sable Crossing")
	check(load("res://scripts/cutscene.gd").BEACONS.size() == 9, "...and the cutscene's ridge has all nine")
	campaign.new_campaign("normal")
	check(campaign.req_text(CD.TERRITORIES["frostmarch"]["requires"]) == "Hold Sable Crossing", "...the north opens on holding it (%s)" % campaign.req_text(CD.TERRITORIES["frostmarch"]["requires"]))
	campaign.new_campaign("normal")
	for m in ["ashwatch", "stonehollow", "ashwatch_road", "stonehollow_workshops", "gw_exodus", "gw_watchfires"]:
		_win(m)
	check(not campaign.requirements_met("sable"), "...one southern beacon isn't enough")
	check(campaign.optional_missions("greenwood") == ["gw_trail"] and campaign.bonus_points("archer") == 0, "...Greenwood's Hunter's Trail is there to play, optional")
	_win("gw_trail")
	check(campaign.bonus_points("archer") == 1, "...and wins the Archers a training point")
	campaign.new_campaign("normal")
	for m in ["ashwatch", "stonehollow"]:
		_win(m)
	_win("gw_exodus")
	check(campaign.optional_missions("greenwood") == ["gw_trail"] and campaign.playable_mission("greenwood") == "gw_watchfires",
			"...the Trail opens as soon as the Watch joins, beside the Watchfires")


## The campaign as it ships today (one mission in Ashwatch and in Stonehollow so far).
func _real_data() -> void:
	campaign.territories = CD.TERRITORIES
	campaign.missions = CD.MISSIONS
	campaign.new_campaign("normal")
	check(campaign.territory_state("ashwatch") == "attack" and campaign.territory_state("stonehollow") == "hidden", "Real data: a new campaign starts at Ashwatch")
	_win("ashwatch")
	check(campaign.territory_state("ashwatch") == "unfinished" and campaign.playable_mission("ashwatch") == "", "...Ashwatch held, the Armoury Wagon waiting for Stonehollow")
	check(campaign.territory_state("stonehollow") == "attack", "...Stonehollow is under attack")
	_win("stonehollow")
	check(campaign.allied("stonehollow"), "...Stonehollow joins")
	check(campaign.playable_mission("ashwatch") == "ashwatch_road", "...and the Armoury Wagon opens")
	_win("ashwatch_road")
	check(campaign.beacon_lit("ashwatch") and campaign.just_lit == "ashwatch", "...which lights Ashwatch's beacon")
	for t in ["greenwood", "mercyvale", "deepdelve"]:
		check(campaign.territory_state(t) == "attack", "...%s opens once Stonehollow's people join, under attack" % t)
	check(campaign.territory_state("sable") in ["hidden", "locked"] and not campaign.requirements_met("sable"), "...Sable Crossing waits for two southern beacons")


## A copy of the campaign's content with full regional chains, for the rules below.
func _test_content() -> void:
	var t: Dictionary = CD.TERRITORIES.duplicate(true)
	var m: Dictionary = CD.MISSIONS.duplicate(true)
	var base: Dictionary = CD.MISSIONS["stonehollow"]
	t["ashwatch"]["missions"] = ["ashwatch", "aw2"]
	t["stonehollow"]["missions"] = ["stonehollow", "sh2"]
	m["aw2"] = base.merged({"name": "Ridge Road", "territory": "ashwatch", "reward": "", "requires": {"joined": ["stonehollow"]}}, true)
	m["sh2"] = base.merged({"name": "Workshops", "territory": "stonehollow", "reward": ""}, true)
	for r in [["greenwood", "gw"], ["deepdelve", "dd"], ["mercyvale", "mv"], ["frostmarch", "fm"], ["monastery", "mo"], ["freecities", "fc"], ["spires", "sp"]]:
		var terr: String = r[0]
		var p: String = r[1]
		t[terr]["missions"] = [p + "1", p + "2"]
		t[terr]["optional"] = [p + "x"]
		m[p + "1"] = base.merged({"name": p + " one", "territory": terr, "reward": terr}, true)
		m[p + "2"] = base.merged({"name": p + " two", "territory": terr, "reward": ""}, true)
		m[p + "x"] = base.merged({"name": p + " side", "territory": terr, "reward": ""}, true)
	m["gwx"]["bonus_points"] = {"archer": 1}
	t["sable"]["missions"] = ["sable"]
	m["sable"] = base.merged({"name": "Sable", "territory": "sable", "reward": ""}, true)
	campaign.territories = t
	campaign.missions = m


func _chains() -> void:
	_test_content()
	campaign.new_campaign("normal")
	_win("ashwatch")
	check(campaign.territory_state("ashwatch") == "unfinished" and campaign.just_lit == "", "Chains: Ashwatch's first mission holds it, but its beacon isn't lit yet")
	check(campaign.next_mission("ashwatch") == "aw2" and campaign.playable_mission("ashwatch") == "", "...its second mission waits for Stonehollow's people to join")
	_win("stonehollow")
	check(campaign.allied("stonehollow") and campaign.territory_state("stonehollow") == "unfinished" and not campaign.beacon_lit("stonehollow"),
			"...Stonehollow's people join after its first mission, before the region is secured")
	check(campaign.playable_mission("ashwatch") == "aw2", "...and now Ashwatch's second mission can be played")
	check(campaign.territory_state("greenwood") == "attack" and campaign.playable_mission("greenwood") == "gw1", "...the south opens when Stonehollow joins (its beacon not needed)")
	_win("gw1")
	check(campaign.allied("greenwood") and campaign.just_joined == "greenwood" and campaign.territory_state("greenwood") == "unfinished",
			"Greenwood's first mission: the Woodland Watch joins")
	check(campaign.allows("archer") and campaign.trainable().has("archer"), "...Archers can be hired and trained at once")
	check(campaign.optional_missions("greenwood") == ["gwx"] and campaign.progress("greenwood") == [1, 2], "...its optional mission opens; 1 of 2 required won")
	var before: int = campaign.points("archer")
	_win("gwx")
	check(not campaign.beacon_lit("greenwood"), "...an optional mission doesn't light the beacon")
	check(campaign.points("archer") == before + 1 and campaign.bonus_points("archer") == 1 and campaign.last_battle.get("archer", [0, 0])[1] == 1,
			"...but its first win gives +1 Archer training point (and the map is told)")
	_win("gwx")
	check(campaign.points("archer") == before + 1, "...given once: winning it again gives no more")
	campaign.xp["archer"] = 1e9
	var opened := 0
	for path in 4:
		while campaign.unlock("archer", path):
			opened += 1
	check(campaign.untrained_tiers("archer") == 4 and opened == 8 and campaign.points("archer") == 4,
			"...bonus points still follow the rules: II and III on every path, the 4 Tier IV points kept for the beacon (%d opened)" % opened)
	campaign.xp["archer"] = 0.0
	campaign.unlocked.erase("archer")
	campaign.spent.erase("archer")
	_win("gw2")
	check(campaign.beacon_lit("greenwood") and campaign.just_lit == "greenwood" and campaign.territory_state("greenwood") == "secured",
			"...the last required mission lights it")
	_win("gw2")
	check(campaign.just_lit == "", "...and winning it again doesn't announce it again")


func _gates() -> void:
	_test_content()
	var south := ["greenwood", "deepdelve", "mercyvale"]
	var pre := {"greenwood": "gw", "deepdelve": "dd", "mercyvale": "mv"}
	for pair in [["greenwood", "deepdelve"], ["greenwood", "mercyvale"], ["deepdelve", "mercyvale"]]:
		campaign.new_campaign("normal")
		for m in ["ashwatch", "stonehollow"]:
			_win(m)
		for t in pair:
			_win(pre[t] + "1")
		check(not campaign.requirements_met("sable"), "Gates (%s): two peoples joined isn't enough for Sable Crossing" % " + ".join(pair))
		for t in pair:
			_win(pre[t] + "2")
		check(not campaign.requirements_met("sable"), "...two southern beacons, but Ashwatch and Stonehollow not secured: still shut")
		_win("aw2")
		_win("sh2")
		check(campaign.requirements_met("sable") and campaign.territory_state("sable") == "attack", "...with Ashwatch's and Stonehollow's beacons too, it opens")
		var third: String = south.filter(func(t): return not pair.has(t))[0]
		check(campaign.playable_mission(third) != "", "...and the third southern region is still there to play")
	_win("sable")
	for t in ["frostmarch", "monastery", "freecities"]:
		check(campaign.playable_mission(t) != "", "Gates: %s opens after Sable Crossing" % t)
	_win("fm1")
	_win("mo1")
	_win("fm2")
	check(not campaign.requirements_met("spires"), "...one northern beacon doesn't open the Spires")
	_win("mo2")
	check(campaign.requirements_met("spires"), "...two do")
	check(not campaign.fully_united(), "...the fully united ending needs every people's beacon")
	for m in ["dd1", "dd2", "mv1", "mv2", "gw1", "gw2", "fc1", "fc2", "sp1", "sp2"]:
		_win(m)
	check(campaign.fully_united() and campaign.beacon_count() == campaign.beacon_territories().size(), "...and with all of them lit, the Line is whole (%d beacons)" % campaign.beacon_count())


func _tier4() -> void:
	_test_content()
	campaign.new_campaign("normal")
	for m in ["ashwatch", "stonehollow", "gw1"]:
		_win(m)
	check(campaign.region_of("archer") == "greenwood" and campaign.region_of("tower") == "greenwood" and campaign.region_of("swordsman") == "ashwatch"
			and campaign.region_of("barricade") == "stonehollow" and campaign.region_of("mine") == "deepdelve" and campaign.region_of("magetower") == "spires",
			"Tier IV: each kind belongs to the region whose people bring it (the Swordsman to Ashwatch)")
	campaign.xp["archer"] = 1e9
	check(campaign.unlock("archer", 0) and campaign.unlock("archer", 0) and campaign.path_tier("archer", 0) == 3, "...Archers train Tiers II and III before the beacon")
	check(not campaign.can_unlock("archer", 0) and not campaign.unlock("archer", 0) and campaign.path_tier("archer", 0) == 3,
			"...but not Tier IV, with points to spare (%d)" % campaign.points("archer"))
	check(campaign.tier_lock_reason("archer", 0) == "Tier IV locked: complete Greenwood's regional campaign and light its beacon", "...and the Training Grounds says why")
	check(campaign.points_waiting("archer") == campaign.points("archer") - 6, "...and how many of its points wait for the beacon (%d of %d)" % [campaign.points_waiting("archer"), campaign.points("archer")])
	check(campaign.tier_lock_reason("archer", 1) == "" and campaign.can_unlock("archer", 1), "...another path at Tier I just shows its next tier")
	var pts: int = campaign.points("archer")
	_win("gw2")
	check(campaign.path_tier("archer", 0) == 3 and campaign.points("archer") == pts, "The beacon lit: nothing is granted (still Tier III, %d points)" % pts)
	check(campaign.can_unlock("archer", 0) and campaign.unlock("archer", 0) and campaign.path_tier("archer", 0) == 4, "...and Tier IV can now be bought with a point")
	check(campaign.can_unlock("archer", 1) and campaign.unlock("archer", 1) and campaign.path_tier("archer", 1) == 2, "...a path below Tier III still goes one tier at a time")
	campaign.xp["tower"] = 1e9
	campaign.unlocked["tower"] = [3, 1, 1, 1]
	campaign.spent["tower"] = 2
	check(campaign.can_unlock("tower", 0), "...Archer Towers (their own training) share Greenwood's beacon")
	campaign.xp["swordsman"] = 1e9
	campaign.unlocked["swordsman"] = [3, 1, 1, 1]
	campaign.spent["swordsman"] = 2
	check(not campaign.can_unlock("swordsman", 0) and "Ashwatch" in campaign.tier_lock_reason("swordsman", 0), "Swordsmen: Tier IV waits for Ashwatch's beacon")
	_win("aw2")
	check(campaign.can_unlock("swordsman", 0), "...which its second mission lights")
	campaign.xp["barricade"] = 1e9
	campaign.unlocked["barricade"] = [3, 1, 1, 1]
	campaign.spent["barricade"] = 2
	check(not campaign.can_unlock("barricade", 0), "Barricades: Tier IV waits for Stonehollow's beacon")
	_win("sh2")
	check(campaign.can_unlock("barricade", 0), "...which its second mission (Protect the Workshops) lights")


func _saves() -> void:
	_test_content()
	campaign.new_campaign("normal")
	for m in ["ashwatch", "stonehollow", "gw1", "gwx"]:
		_win(m)
	campaign.unlocked["swordsman"] = [4, 2, 1, 1]   # trained before Tier IV was gated: kept
	campaign.save_game()
	campaign.reset()
	campaign.load_game()
	check(campaign.completed == ["ashwatch", "stonehollow", "gw1", "gwx"] and campaign.allied("greenwood"), "Saves: missions won (optional too) and peoples joined come back")
	check(campaign.territory_state("greenwood") == "unfinished" and not campaign.beacon_lit("ashwatch"), "...beacons are worked out from them, not stored")
	check(campaign.path_tier("swordsman", 0) == 4, "...and a Tier IV trained before the rule is kept")


## The map and Training Grounds draw every state without trouble.
func _screens() -> void:
	_test_content()
	campaign.new_campaign("normal")
	for m in ["ashwatch", "stonehollow", "gw1"]:
		_win(m)
	campaign.xp["archer"] = 1e9
	campaign.unlock("archer", 0)
	campaign.unlock("archer", 0)
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.hud.hide_mode_select()
	var map = main.hud.show_world_map(campaign)
	for i in 3:
		await process_frame
	for t in CD.TERRITORIES:
		map.select(t)
	map.select("greenwood")
	check(map.info["state"].text.begins_with("Allied") and "Tier IV" in map.info["mission"].text, "Map: Greenwood shows as allied, 1/2, with what securing it brings (%s)" % map.info["state"].text)
	check("Beacons" in map.info["header"].text, "...the header counts beacons (%s)" % map.info["header"].text)
	if map.overlay != null:   # (the Woodland Watch's joining is announced first)
		map.overlay.queue_free()
		map.overlay = null
	map.training_kind = "archer"
	map.show_training()
	await process_frame
	var found := false
	for n in map.find_children("*", "Button", true, false):
		if n.text == "Tier IV locked" and n.disabled:
			found = true
	check(found, "Training Grounds: the Archer path at Tier III shows Tier IV locked")
	map.overlay = null
	_win("gw2")
	main.hud.hide_world_map()
	map = main.hud.show_world_map(campaign)
	await process_frame
	map._announce_join()
	await process_frame
	var lit := false
	for n in map.find_children("*", "Label", true, false):
		if "stands with the Line" in n.text:
			lit = true
	check(lit, "...and the map announces the lit beacon")
	main.free()


## Each southern people as it ships: their first mission brings them in (their units and
## keys, no beacon yet); the last required mission lights the beacon, which grants
## nothing but opens Tier IV, and only for a path at Tier III with a point to spend.
## Winning a mission again changes nothing; an optional mission's points come once.
## The Arcane Spires open on two LIT northern beacons (every required mission of two
## northern regions won), not on two northern peoples merely joined. (The north's
## missions are stand-ins here until Phase 4 builds them.)
func _north_gate() -> void:
	var terr: Dictionary = CD.TERRITORIES.duplicate(true)
	var mis: Dictionary = CD.MISSIONS.duplicate(true)
	var north := {"frostmarch": ["fm_1", "fm_2"], "monastery": ["mo_1", "mo_2"], "freecities": ["fc_1", "fc_2"]}
	for t in north:
		terr[t]["missions"] = north[t]
		for m in north[t]:
			mis[m] = {"name": m, "territory": t, "waves": 1, "gold": 100}
	campaign.territories = terr
	campaign.missions = mis
	for pair in [["frostmarch", "monastery"], ["monastery", "freecities"], ["frostmarch", "freecities"]]:
		campaign.new_campaign("normal")
		for m in ["ashwatch", "ashwatch_road", "stonehollow", "stonehollow_workshops", "gw_exodus", "gw_watchfires", "mv_wounded", "mv_sanctuary", "sable_crossing"]:
			_win(m)
		check(campaign.territory_state("spires") != "attack" and not campaign.requirements_met("spires"), "North %s: the Spires are shut after Sable" % "+".join(pair))
		for t in north:
			_win(north[t][0])   # all three peoples join
		check(not campaign.requirements_met("spires"), "...still shut with all three northern peoples joined but no beacon lit")
		_win(north[pair[0]][1])
		check(campaign.beacon_lit(pair[0]) and not campaign.requirements_met("spires"), "...still shut with one northern beacon lit (%s)" % pair[0])
		_win(north[pair[1]][1])
		check(campaign.requirements_met("spires"), "...open once a second northern beacon is lit (%s)" % pair[1])
	campaign.territories = CD.TERRITORIES
	campaign.missions = CD.MISSIONS


## A mission already won, played again, trains at half the rate (a loss on a replay: a
## quarter); a first win, the full rate.
func _replay_xp() -> void:
	campaign.territories = CD.TERRITORIES
	campaign.missions = CD.MISSIONS
	campaign.new_campaign("normal")
	campaign.xp = {"swordsman": 1e6}   # (past catch-up, so no doubling muddies the sums)
	campaign.mission_id = "ashwatch"
	campaign.bank_xp({"swordsman": 1000.0}, true)
	var first: float = campaign.xp["swordsman"] - 1e6
	_win("ashwatch")
	var before: float = campaign.xp["swordsman"]
	campaign.mission_id = "ashwatch"
	campaign.bank_xp({"swordsman": 1000.0}, true)
	var replay: float = campaign.xp["swordsman"] - before
	before = campaign.xp["swordsman"]
	campaign.bank_xp({"swordsman": 1000.0}, false)
	var replay_loss: float = campaign.xp["swordsman"] - before
	check(is_equal_approx(first, 1000.0) and is_equal_approx(replay, 500.0) and is_equal_approx(replay_loss, 250.0),
			"Replaying a won mission: half the XP (%d first win, %d replayed, %d replay lost)" % [first, replay, replay_loss])


func _south_training() -> void:
	campaign.territories = CD.TERRITORIES
	campaign.missions = CD.MISSIONS
	var chains := {"greenwood": ["gw_exodus", "gw_watchfires"], "mercyvale": ["mv_wounded", "mv_sanctuary"], "deepdelve": ["dd_entrance", "dd_orerun"],
			"frostmarch": ["fm_pass", "fm_vigil"]}   # (and the North, region by region in Phase 4)
	for f in chains:
		campaign.new_campaign("normal")
		_win("ashwatch")
		_win("stonehollow")
		var keys: Array = CD.FACTIONS[f]["unlocks"]
		check(keys.all(func(k): return not campaign.allows(k)), "South %s: before its first mission, none of %s" % [f, ", ".join(keys)])
		_win(chains[f][0])
		check(campaign.allied(f) and keys.all(func(k): return campaign.allows(k)) and not campaign.beacon_lit(f),
				"...its first mission brings the people in (%s), but no beacon" % ", ".join(keys))
		var kinds: Array = campaign.tier4_kinds(f)
		check(not kinds.is_empty() and kinds.all(func(k): return campaign.trainable().has(k)), "...their units can be trained at once (%s)" % ", ".join(kinds))
		for k in kinds:
			campaign.xp[k] = 1e9
			campaign.unlock(k, 0)
			campaign.unlock(k, 0)
		check(kinds.all(func(k): return campaign.path_tier(k, 0) == 3 and not campaign.can_unlock(k, 0)),
				"...Tier III trained, Tier IV refused before the beacon, points to spare")
		var before: Dictionary = campaign.unlocked.duplicate(true)
		var spent_before: Dictionary = campaign.spent.duplicate(true)
		_win(chains[f][1])
		check(campaign.beacon_lit(f) and campaign.just_lit == f, "...every required mission won: the beacon is lit")
		check(campaign.unlocked == before and campaign.spent == spent_before, "...and nothing is bought by itself: tiers and points as they were")
		check(kinds.all(func(k): return campaign.can_unlock(k, 0) and campaign.tier_lock_reason(k, 0) == ""), "...Tier IV can now be bought on a Tier III path")
		check(kinds.all(func(k): return campaign.can_unlock(k, 1) and campaign.path_tier(k, 1) == 1), "...a path at Tier I still goes to Tier II first")
		var k0: String = kinds[0]
		var xp0: float = campaign.xp[k0]
		campaign.xp[k0] = 0.0
		check(not campaign.can_unlock(k0, 0), "...and with no points to spend, %s's Tier IV still can't be bought" % k0)
		campaign.xp[k0] = xp0
		check(campaign.unlock(k0, 0) and campaign.path_tier(k0, 0) == 4, "...with a point, it can")
		# Replaying: no second beacon, nothing taken away or given.
		var done: Array = campaign.completed.duplicate()
		var trained: Dictionary = campaign.unlocked.duplicate(true)
		_win(chains[f][1])
		_win(chains[f][0])
		check(campaign.completed == done and campaign.unlocked == trained and campaign.just_lit == "" and campaign.just_joined == "",
				"...winning its missions again changes nothing (no new beacon, tiers kept)")
	# The Hunter's Trail: its Archer point comes on the first win only, however often it's played.
	campaign.new_campaign("normal")
	for m in ["ashwatch", "stonehollow", "gw_exodus"]:
		_win(m)
	for i in 5:
		_win("gw_trail")
	check(campaign.bonus_points("archer") == 1 and campaign.completed.count("gw_trail") == 1, "The Hunter's Trail won five times: still one bonus point (%d)" % campaign.bonus_points("archer"))
	# Whiteout (Frostmarch's optional mission): a Frost Witch point, the first win only, and
	# only once the Covenant has joined.
	campaign.new_campaign("normal")
	for m in ["ashwatch", "ashwatch_road", "stonehollow", "stonehollow_workshops", "gw_exodus", "gw_watchfires", "mv_wounded", "mv_sanctuary", "sable_crossing"]:
		_win(m)
	check(not campaign.optional_missions("frostmarch").has("fm_whiteout"), "Whiteout isn't open before the Covenant joins")
	_win("fm_pass")
	check(campaign.optional_missions("frostmarch").has("fm_whiteout"), "...it is once they have")
	for i in 3:
		_win("fm_whiteout")
	check(campaign.bonus_points("frost") == 1, "...won three times: one Frost Witch point (%d)" % campaign.bonus_points("frost"))


## Three campaigns side by side, one in each save: each keeps its own missions, peoples,
## training and difficulty, and none leaks into another.
func _slots() -> void:
	campaign.territories = CD.TERRITORIES
	campaign.missions = CD.MISSIONS
	var plans := {1: ["easy", "greenwood", ["gw_exodus", "gw_trail"], "archer"], 2: ["normal", "mercyvale", ["mv_wounded", "mv_sanctuary"], "healer"],
			3: ["hard", "deepdelve", ["dd_entrance"], "cannon"]}
	for n in plans:
		campaign.use_slot(n)
		campaign.new_campaign(plans[n][0])
		for m in ["ashwatch", "stonehollow"] + plans[n][2]:
			_win(m)
		campaign.xp[plans[n][3]] = 1e9
		campaign.unlock(plans[n][3], 2)
		campaign.save_game()
	for n in [3, 1, 2]:
		campaign.use_slot(n)
		campaign.reset()
		campaign.use_slot(n)
		campaign.load_game()
		var kind: String = plans[n][3]
		var others: Array = [1, 2, 3].filter(func(x): return x != n).map(func(x): return plans[x][1])
		check(campaign.difficulty == plans[n][0] and campaign.allied(plans[n][1]) and not others.any(func(f): return campaign.allied(f))
				and campaign.path_tier(kind, 2) == 2 and campaign.completed == ["ashwatch", "stonehollow"] + plans[n][2],
				"Save %d: %s, %s joined, %s trained, nothing from the other saves" % [n, plans[n][0], plans[n][1], kind])
		var info: Dictionary = campaign.slot_info(n)
		check(info["difficulty"] == plans[n][0] and info["alliances"] == 2, "...and the save menu reads it right (%s, %d alliances)" % [info["difficulty"], info["alliances"]])
	var lit2: bool = campaign.beacon_lit("mercyvale")   # (Save 2 is the one loaded last)
	campaign.use_slot(1)
	campaign.load_game()
	check(lit2 and not campaign.beacon_lit("mercyvale"), "...Mercy Vale's beacon is lit in Save 2 alone")
	for n in [2, 3]:
		campaign.delete_slot(n)
	campaign.use_slot(1)
