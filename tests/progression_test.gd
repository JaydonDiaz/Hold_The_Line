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
	_chains()
	_gates()
	_tier4()
	_saves()
	await _screens()
	campaign.territories = CD.TERRITORIES
	campaign.missions = CD.MISSIONS
	campaign.reset()
	for f in [TEST_SAVE, TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _win(m: String) -> void:
	campaign.mission_id = m
	campaign.finish_mission(true)


## The campaign as it ships today (one mission in Ashwatch and in Stonehollow so far).
func _real_data() -> void:
	campaign.territories = CD.TERRITORIES
	campaign.missions = CD.MISSIONS
	campaign.new_campaign("normal")
	check(campaign.territory_state("ashwatch") == "attack" and campaign.territory_state("stonehollow") == "hidden", "Real data: a new campaign starts at Ashwatch")
	_win("ashwatch")
	check(campaign.territory_state("ashwatch") == "secured" and campaign.just_lit == "ashwatch", "...Ashwatch's one mission so far lights its beacon")
	check(campaign.territory_state("stonehollow") == "attack", "...Stonehollow is under attack")
	_win("stonehollow")
	check(campaign.allied("stonehollow") and campaign.territory_state("stonehollow") == "secured", "...Stonehollow joins, and is secured")
	for t in ["greenwood", "mercyvale", "deepdelve"]:
		check(campaign.territory_state(t) == "available", "...%s opens once Stonehollow's people join" % t)
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
