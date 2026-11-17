extends SceneTree
## Phase 5, F1: the Arcane Spires. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/spires_test.gd
##   C  conduits   a Mage on the conduit of its own art (the path it's furthest along) is
##                  powered up a good deal (damage and rate); on another conduit, or untrained,
##                  a little; off them, or any other kind of unit, nothing; the best one in
##                  reach counts, they don't add up; Mage Towers draw on them too
##   M  missions   the Broken Circle: its map (crystal, four conduits, one of each art), the
##                  Circle to take, two of the Conclave's Mages lent and Mages to hire;
##                  Relight the Spires: three spires to keep standing (one may fall); the
##                  Lost Archive: the archive to keep standing while it's read, optional
##   R  rewards    the Circle won: the Conclave joins (Mages, Mage Towers); both won: the
##                  Spires' beacon is lit, Mages may reach Tier IV, Dawnspire opens; the
##                  Archive won: a Mage training point, once
##   S  story      Ysolde tells the truth of the Line (sworn here two hundred years ago,
##                  broken by its own peoples' greed); the Ogre King answers (Sable is won)
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.

const TEST_SAVE := "user://spires_test_campaign.cfg"
const CD = preload("res://scripts/campaign_data.gd")
const Maps = preload("res://scripts/maps.gd")
const Conduits = preload("res://scripts/conduits.gd")

var main
var fails := 0
var checks := 0
var campaign


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	campaign = root.get_node("Campaign")
	campaign.save_path = TEST_SAVE
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## The campaign at the Spires' door: the south, Sable, and two northern peoples joined
## with their beacons lit.
func _at_the_spires() -> void:
	campaign.new_campaign("normal")
	campaign.completed = ["ashwatch", "ashwatch_road", "stonehollow", "stonehollow_workshops", "gw_exodus", "gw_watchfires",
		"mv_wounded", "mv_sanctuary", "sable_crossing", "fm_pass", "fm_vigil", "mo_steps", "mo_gate"]
	campaign.allies = ["stonehollow", "greenwood", "mercyvale", "frostmarch", "monastery"]


func _mission(mid: String) -> void:
	_at_the_spires()
	if mid == "sp_relight" or mid == "sp_archive":
		campaign.completed.append("sp_circle")
		campaign.allies.append("spires")
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
	await _conduits()
	await _missions()
	_rewards()
	_story()
	if main != null:
		main.free()
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


# --- C: conduits ------------------------------------------------------------------------

func _mage(at: Vector2, path := -1, kind := "mage"):
	main.gold = 99999
	var had: Array = main.get_warriors()
	main.placing_type = kind
	main.hire_at(at)
	main.placing_type = ""
	var fresh: Array = main.get_warriors().filter(func(x): return not had.has(x))
	assert(fresh.size() == 1, "nothing hired at %s" % str(at))
	var w = fresh[0]
	w.position = w.post
	if path >= 0:
		main.selected = w
		main.upgrade_selected(path)
		main.upgrade_selected(path)
		main.selected = null
	return w


func _conduits() -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud.hide_mode_select()
	main.classic_map = "spires_circle"
	main.choose_mode("normal")
	main._lock_portrait(true)
	await _frames(3)
	var c = main.conduits
	check(c.active() and c.spots.size() == 4 and c.spots.map(func(s): return s["path"]).duplicate().all(func(p): return p >= 0 and p < 4)
			and Array(c.spots.map(func(s): return s["path"])).has(0) and Array(c.spots.map(func(s): return s["path"])).has(3),
			"C  the Broken Circle has four conduits, one of each art")
	var by_path := {}
	for s in c.spots:
		by_path[int(s["path"])] = c.pos(s)
	var fire = _mage(by_path[2], 2)        # a Fire Mage on the Fire conduit
	var storm = _mage(by_path[2] + Vector2(0, 40), 0)   # a Storm Mage on the Fire conduit
	var green = _mage(by_path[3])          # an untrained Mage on the Necromancy conduit
	var away = _mage(Vector2(320, 540), 2)   # a Fire Mage on no sigil (the big island)
	var archer = _mage(by_path[0], -1, "archer")
	await _frames(30)   # (units take stock of what powers them up four times a second)
	check(Conduits.art_of(fire) == 2 and fire.buff["damage"] >= Conduits.MATCH["damage"] - 0.001 and fire.buff["rate"] >= Conduits.MATCH["rate"] - 0.001,
			"C  a Fire Mage on the Fire conduit: +%d%% damage, +%d%% rate" % [roundi(fire.buff["damage"] * 100), roundi(fire.buff["rate"] * 100)])
	check(is_equal_approx(storm.buff["damage"], Conduits.OTHER["damage"]) and storm.buff["rate"] == 0.0,
			"C  a Storm Mage on the Fire conduit: a little (+%d%% damage)" % roundi(storm.buff["damage"] * 100))
	check(is_equal_approx(green.buff["damage"], Conduits.OTHER["damage"]), "C  an untrained Mage on a conduit: a little")
	check(away.buff["damage"] == 0.0 and away.buff["rate"] == 0.0, "C  off the conduits: nothing")
	check(archer.buff["damage"] == 0.0, "C  an Archer on a conduit: nothing (it's Mages' power)")
	# Easy to read: each conduit says what it is and gives, and a Mage's info what it draws.
	var card: Array = c.card_text(c.at_point(by_path[2]))
	check(card[0] == "Fire sigil" and "+35% damage" in card[3] and "+10% damage" in card[3], "C  a conduit's card names its art and what it gives whom")
	check("Sigil: Fire (+35% dmg · +25% speed)" in fire.stats_text() and "not its art" in storm.stats_text(),
			"C  a Mage's info says which conduit it draws on and what it gets")
	# Its upgrade cards: the Fire path's card glows and says what the sigil gives; the
	# Storm Mage on the Fire sigil gets the Fire card marked faintly, with the little it gets.
	main.selected = fire
	await _frames(2)
	var cards: Array = main.hud.path_cards
	check(cards[2]["glow"].visible and cards[2]["sigil"].visible and "+35% dmg" in cards[2]["sigil"].text
			and not cards[0]["glow"].visible and not cards[1]["glow"].visible and not cards[3]["glow"].visible,
			"C  the Fire Mage's Fire card glows, and says what the sigil gives (%s)" % cards[2]["sigil"].text)
	main.selected = storm
	await _frames(2)
	check(cards[2]["glow"].visible and "+10% dmg" in cards[2]["sigil"].text and not cards[0]["glow"].visible,
			"C  a Storm Mage on the Fire sigil: its Fire card is marked, with the little it gets (%s)" % cards[2]["sigil"].text)
	main.selected = away
	await _frames(2)
	check(cards.all(func(cd): return not cd["glow"].visible), "C  a Mage off the sigils: no card is marked")
	main.selected = null
	var tower = _mage(by_path[1] + Vector2(0, 20), 1, "magetower")
	tower.build_left = 0.0   # (built: one going up has no power to draw)
	await _frames(30)
	check(tower.buff["damage"] >= Conduits.MATCH["damage"] - 0.001, "C  a Mage Tower of the Lance on the Lance conduit draws on it too")
	check(c.spots.any(func(s): return s["lit"] > 0.0), "C  a conduit lending its power lights up")


# --- M: missions ------------------------------------------------------------------------

func _missions() -> void:
	await _mission("sp_circle")
	var lent: Array = main.get_warriors().filter(func(w): return w.kind == "mage")
	check(main.map_id == "spires_circle" and main.conduits.active() and lent.size() == 2 and main.allowed("mage"),
			"M  the Broken Circle: its map and conduits, two Conclave Mages lent, Mages to hire")
	check(lent.all(func(w): return w.total_upgrades() >= 2) and Conduits.art_of(lent[0]) != Conduits.art_of(lent[1]),
			"M  ...the lent Mages trained in different arts")
	check(CD.MISSIONS["sp_circle"]["type"] == "capture" and CD.MISSIONS["sp_circle"]["reward"] == "spires", "M  ...a capture, and it wins the Conclave")
	await _mission("sp_relight")
	var objs: Array = main.rules.objectives()
	check(main.map_id == "spires_relight" and objs.size() == 3 and objs.all(func(o): return o.kind == "spire") and int(CD.MISSIONS["sp_relight"]["can_lose"]) == 1,
			"M  Relight the Spires: three spires to keep standing, one may fall")
	await _mission("sp_archive")
	objs = main.rules.objectives()
	check(main.map_id == "spires_archive" and objs.size() == 1 and CD.MISSIONS["sp_archive"]["type"] == "protect"
			and CD.TERRITORIES["spires"]["optional"].has("sp_archive"), "M  the Lost Archive: the archive to keep standing while it's read, and optional")


# --- R: rewards --------------------------------------------------------------------------

func _rewards() -> void:
	_at_the_spires()
	check(campaign.territory_state("spires") == "attack" and campaign.territory_state("dawnspire") != "attack",
			"R  two northern beacons lit: the Spires can be attacked, Dawnspire not yet")
	check(not campaign.allows("mage"), "R  ...no Mages of the Line's own yet")
	campaign.mission_id = "sp_circle"
	campaign.finish_mission(true)
	check(campaign.allied("spires") and campaign.allows("mage") and campaign.allows("magetower") and not campaign.beacon_lit("spires"),
			"R  the Circle won: the Conclave joins (Mages, Mage Towers); its beacon isn't lit yet")
	check(not campaign.tier4_open("mage"), "R  ...Tier IV still closed")
	campaign.mission_id = "sp_relight"
	campaign.finish_mission(true)
	check(campaign.beacon_lit("spires") and campaign.tier4_open("mage") and campaign.territory_state("dawnspire") in ["attack", "available"],
			"R  the spires relit: the Spires' beacon burns, Mages may reach Tier IV, Dawnspire opens (%s)" % campaign.territory_state("dawnspire"))
	var before: int = campaign.bonus_points("mage")
	campaign.mission_id = "sp_archive"
	campaign.finish_mission(true)
	var after: int = campaign.bonus_points("mage")
	campaign.mission_id = "sp_archive"
	campaign.finish_mission(true)
	var again: int = campaign.bonus_points("mage")
	check(after == before + 1 and again == after, "R  the Archive won: a Mage training point, and only the first time")


# --- S: story ----------------------------------------------------------------------------

func _story() -> void:
	var all_text := ""
	for key in ["sp_circle_intro", "sp_circle_outro", "sp_relight_intro", "sp_relight_outro", "sp_archive_intro", "sp_archive_outro"]:
		check(CD.STORY.has(key) and not (CD.STORY[key] as Array).is_empty(), "S  %s is written" % key)
		for line in CD.STORY.get(key, []):
			all_text += line["text"] + " "
	check("two hundred years" in all_text and ("greed" in all_text or "wanted the beacons for itself" in all_text),
			"S  Ysolde tells the truth: the Line sworn two hundred years ago, broken by its own peoples")
	var speakers := []
	for key in ["sp_circle_outro", "sp_relight_outro"]:
		for line in CD.STORY[key]:
			speakers.append(line["who"])
	check(speakers.has("ysolde") and speakers.has("ogre") and not speakers.has("marshal"), "S  Ysolde speaks for the Conclave; the Ogre King answers (the Marshal is gone)")
