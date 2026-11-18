extends SceneTree
## Saves from before the Mage and Frost Towers were retired (version 3) load without losing
## training, in each of the three save slots on its own. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/migration_test.gd
##   M  migration   a version-3 save's Mage Tower XP becomes Arcane Obelisk XP, its Frost
##                   Tower XP is added to the Tower's (old Archer Tower training kept as it
##                   was); the same XP, so the same training points, unspent; capped at full
##                   training; nothing to the Mage or Frost Witch; carried once, not again on
##                   the next load; a kind the game doesn't know is kept, not dropped
##   S  slots       three slots, each migrated on its own, none touching the others
## Uses scratch save paths, never the player's own saves.
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.

const CD = preload("res://scripts/campaign_data.gd")
const BASE := "user://migration_test.cfg"

var campaign
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	campaign = root.get_node("Campaign")
	campaign.save_path = BASE
	_run.call_deferred()


## A save as version 3 wrote it.
func _write_v3(path: String, xp: Dictionary, unlocked: Dictionary, spent: Dictionary, completed: Array) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 3)
	cfg.set_value("meta", "saved_at", 1794544878)
	cfg.set_value("state", "difficulty", "normal")
	cfg.set_value("state", "completed", completed)
	cfg.set_value("state", "allies", ["stonehollow", "greenwood", "spires"])
	cfg.set_value("state", "flags", {})
	cfg.set_value("state", "seen", [])
	cfg.set_value("state", "xp", xp)
	cfg.set_value("state", "unlocked", unlocked)
	cfg.set_value("state", "spent", spent)
	cfg.save(path)


func _run() -> void:
	var p1: String = campaign.slot_path(1)
	var p2: String = campaign.slot_path(2)
	var p3: String = campaign.slot_path(3)
	var full: float = campaign.xp_for_level(CD.MAX_TRAINING)
	_write_v3(p1, {"archer": 40000.0, "tower": 15000.0, "magetower": 14000.0, "frosttower": 6000.0, "mage": 30000.0, "frost": 9000.0, "lavatower": 900.0},
			{"tower": [2, 2, 3, 2], "magetower": [3, 2, 1, 1], "frosttower": [2, 1, 1, 1], "mage": [3, 3, 1, 1]},
			{"tower": 5, "magetower": 3, "frosttower": 1, "mage": 4}, ["ashwatch", "stonehollow"])
	_write_v3(p2, {"archer": 9000.0, "tower": full - 1000.0, "frosttower": 50000.0}, {"tower": [3, 3, 3, 3]}, {"tower": 8}, ["ashwatch"])
	if FileAccess.file_exists(p3):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p3))

	# Slot 1.
	campaign.use_slot(1)
	check(campaign.load_game(), "S  slot 1 (version 3) loads")
	check(is_equal_approx(float(campaign.xp.get("obelisk", 0.0)), 14000.0) and not campaign.xp.has("magetower"),
			"M  the Mage Tower's 14,000 XP is now the Arcane Obelisk's (%s)" % campaign.xp.get("obelisk", 0.0))
	check(is_equal_approx(float(campaign.xp.get("tower", 0.0)), 21000.0) and campaign.unlocked.get("tower") == [2, 2, 3, 2] and int(campaign.spent.get("tower", 0)) == 5,
			"M  the Frost Tower's 6,000 XP added to the Tower's 15,000, its old Archer Tower training kept (%s)" % campaign.xp.get("tower", 0.0))
	check(campaign.points("obelisk") == campaign.level_of("obelisk") and int(campaign.spent.get("obelisk", 0)) == 0 and campaign.level_of("obelisk") > 0,
			"M  the Obelisk's training points are all unspent, to choose on its runes (%d)" % campaign.points("obelisk"))
	check(is_equal_approx(float(campaign.xp.get("mage", 0.0)), 30000.0) and is_equal_approx(float(campaign.xp.get("frost", 0.0)), 9000.0)
			and campaign.unlocked.get("mage") == [3, 3, 1, 1] and int(campaign.spent.get("mage", 0)) == 4,
			"M  the Mage and Frost Witch are left as they were (nothing trained twice)")
	check(campaign.retired.has("lavatower") and is_equal_approx(float(campaign.retired["lavatower"]["xp"]), 900.0),
			"M  a kind the game doesn't know is kept aside, not dropped")
	campaign.save_game()
	campaign.load_game()
	check(is_equal_approx(float(campaign.xp.get("tower", 0.0)), 21000.0) and is_equal_approx(float(campaign.xp.get("obelisk", 0.0)), 14000.0)
			and campaign.retired.has("magetower") and campaign.retired.has("lavatower"),
			"M  saved and loaded again: carried once only (Tower %s), the old records kept" % campaign.xp.get("tower", 0.0))
	var cfg := ConfigFile.new()
	cfg.load(p1)
	check(int(cfg.get_value("meta", "version", 0)) == campaign.VERSION, "M  the slot is saved at the new version")

	# Slot 2: a Tower near full training can't be pushed past it.
	campaign.use_slot(2)
	check(campaign.load_game(), "S  slot 2 (version 3) loads on its own")
	check(campaign.xp.get("tower", 0.0) <= full + 0.01 and campaign.xp.get("tower", 0.0) >= full - 0.01 and not campaign.xp.has("obelisk"),
			"M  a big Frost Tower XP stops at full training for the Tower (%s of %s)" % [campaign.xp.get("tower", 0.0), full])
	check(campaign.completed == ["ashwatch"], "S  ...with its own progress, not slot 1's")

	# Slot 3: empty.
	campaign.use_slot(3)
	check(not campaign.load_game() and campaign.xp.is_empty() and campaign.retired.is_empty(), "S  slot 3 is empty, and nothing from the others leaks in")
	campaign.use_slot(1)
	campaign.load_game()
	check(campaign.completed == ["ashwatch", "stonehollow"] and is_equal_approx(float(campaign.xp.get("obelisk", 0.0)), 14000.0),
			"S  back to slot 1: still its own")

	for p in [p1, p2, p3]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
