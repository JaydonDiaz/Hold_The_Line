extends Node
## The story campaign's state (an autoload, "Campaign", so it outlives the scene reloads
## between the map and battles): the difficulty, which missions are won, who has joined
## the Line, story flags, and which screen the next scene load opens. Saved to
## user://campaign.cfg, apart from the Classic records and the settings.
##
## Outside a campaign battle (Classic, Freeplay, the Tutorial) nothing here restricts
## anything: main.gd only asks allows() while it's playing a campaign mission.

const CD = preload("res://scripts/campaign_data.gd")
const Data = preload("res://scripts/data.gd")
const VERSION := 3   # bump when the save's shape changes, and migrate older saves in _read
# 1: the first campaign save.  2: adds troop training (points and trained tiers).
# 3: training is earned per unit by use (XP, points spent per path).

var save_path := "user://campaign.cfg"
var difficulty := "normal"
var completed: Array = []   # mission ids won
var allies: Array = []      # FACTIONS keys that have joined the Line
var flags := {}             # story flags (name -> true)
var seen: Array = []        # STORY keys already shown (intros aren't repeated on a retry)
var xp := {}                # unit kind -> experience earned in battles
var unlocked := {}          # unit kind -> [highest tier open on each of its four paths] (1s when missing)
var spent := {}             # unit kind -> training points spent on it
var last_battle := {}       # unit kind -> [XP, points] the last battle earned (the map shows it)
var load_error := ""        # why the save couldn't be read ("" if it could, or there's none)

# Where the next main-scene load goes ("" = the title screen, "map", "battle"), and what
# the map shows when it opens. Not saved: a fresh launch always starts at the title.
var screen := ""
var mission_id := ""
var pending_story := ""    # STORY key to play when the map opens (a mission's outro)
var just_joined := ""      # faction that joined in the battle just won (the map announces it)


func _ready() -> void:
	load_game()


# --- Saving -----------------------------------------------------------------

func reset() -> void:
	difficulty = "normal"
	completed = []
	allies = []
	flags = {}
	seen = []
	xp = {}
	unlocked = {}
	spent = {}
	last_battle = {}
	mission_id = ""
	pending_story = ""
	just_joined = ""


func new_campaign(diff: String) -> void:
	reset()
	difficulty = diff if Data.DIFFICULTIES.has(diff) else "normal"
	save_game()


## Whether there's a campaign saved to carry on with.
func has_save() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(save_path) == OK and _readable(cfg)


func _readable(cfg: ConfigFile) -> bool:
	var v = cfg.get_value("meta", "version", 0)
	return v is int and v >= 1 and v <= VERSION


## Loads the saved campaign. Returns false (and leaves a fresh state) if there's none or
## it can't be read; a save from a newer version of the game is left alone on disk.
func load_game() -> bool:
	reset()
	load_error = ""
	var cfg := ConfigFile.new()
	var err := cfg.load(save_path)
	if err == ERR_FILE_NOT_FOUND:
		return false
	if err != OK:
		load_error = "The campaign save couldn't be read."
		return false
	var v = cfg.get_value("meta", "version", 0)
	if not v is int or v < 1:
		load_error = "The campaign save is damaged."
		return false
	if v > VERSION:
		load_error = "The campaign save is from a newer version of the game."
		return false
	return _read(cfg)


func _read(cfg: ConfigFile) -> bool:
	var diff = cfg.get_value("state", "difficulty", "normal")
	difficulty = diff if diff is String and Data.DIFFICULTIES.has(diff) else "normal"
	completed = _strings(cfg.get_value("state", "completed", []), CD.MISSIONS)
	allies = _strings(cfg.get_value("state", "allies", []), CD.FACTIONS)
	seen = _strings(cfg.get_value("state", "seen", []), CD.STORY)
	var f = cfg.get_value("state", "flags", {})
	flags = {}
	if f is Dictionary:
		for k in f:
			if k is String and f[k]:
				flags[k] = true
	var v: int = cfg.get_value("meta", "version", 1)
	if v == 2:
		# Training was a tier for all four paths at once (towers shared their crew's):
		# keep every tier already trained, on every path. Unspent points don't carry over.
		var t = cfg.get_value("state", "trained", {})
		var share := {"tower": "archer", "magetower": "mage", "frosttower": "frost"}
		if t is Dictionary:
			for kind in Data.WARRIORS:
				var from: String = share.get(kind, kind)
				if t.get(from, 1) is int and int(t.get(from, 1)) > 1:
					var tier := clampi(int(t[from]), 1, 4)
					unlocked[kind] = [tier, tier, tier, tier]
	elif v >= 3:
		var x = cfg.get_value("state", "xp", {})
		var u = cfg.get_value("state", "unlocked", {})
		var sp = cfg.get_value("state", "spent", {})
		for kind in Data.WARRIORS:
			if x is Dictionary and (x.get(kind, 0.0) is float or x.get(kind, 0.0) is int):
				xp[kind] = maxf(0.0, float(x.get(kind, 0.0)))
			if u is Dictionary and u.get(kind) is Array and u[kind].size() == 4:
				var tiers := []
				for tv in u[kind]:
					tiers.append(clampi(int(tv) if (tv is int or tv is float) else 1, 1, 4))
				unlocked[kind] = tiers
			if sp is Dictionary and sp.get(kind, 0) is int and int(sp.get(kind, 0)) > 0:
				spent[kind] = clampi(int(sp.get(kind, 0)), 0, CD.MAX_TRAINING)
		for kind in xp.keys():
			if xp[kind] <= 0.0:
				xp.erase(kind)
	return true


## The strings in `list` that name something in `known` (anything else is dropped).
func _strings(list, known: Dictionary) -> Array:
	var out := []
	if list is Array:
		for x in list:
			if x is String and known.has(x) and not out.has(x):
				out.append(x)
	return out


## Writes the campaign out: to a temporary file first, then swapped in, so a crash
## mid-write can't leave a half-written save behind.
func save_game() -> bool:
	if refusing_save():
		return false
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("state", "difficulty", difficulty)
	cfg.set_value("state", "completed", completed)
	cfg.set_value("state", "allies", allies)
	cfg.set_value("state", "flags", flags)
	cfg.set_value("state", "seen", seen)
	cfg.set_value("state", "xp", xp)
	cfg.set_value("state", "unlocked", unlocked)
	cfg.set_value("state", "spent", spent)
	var tmp := save_path + ".tmp"
	if cfg.save(tmp) != OK:
		return false
	var dir := DirAccess.open(save_path.get_base_dir())
	if dir == null:
		return false
	if FileAccess.file_exists(save_path):
		dir.remove(save_path.get_file())
	return dir.rename(tmp.get_file(), save_path.get_file()) == OK


## A save from a newer version is never overwritten by this one.
func refusing_save() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(save_path) == OK and cfg.get_value("meta", "version", 0) is int and cfg.get_value("meta", "version", 0) > VERSION


# --- Unlocks ------------------------------------------------------------------

func allied(faction: String) -> bool:
	return allies.has(faction)


## Whether unlock key `key` (see campaign_data.gd) can be used, with `lend` (the
## current mission's borrowed keys) on top of what the Line has earned.
func allows(key: String, lend: Array = []) -> bool:
	if not (CD.START_UNLOCKS.has(key) or lend.has(key) or _earned(key)):
		return false
	# Emplacements also need someone to build them.
	if Data.WARRIORS.has(key) and Data.WARRIORS[key].get("emplacement", false) and key != "barricade":
		return allied(CD.BUILDERS) or lend.has(CD.LEND_BUILDERS)
	return true


func _earned(key: String) -> bool:
	for f in allies:
		if (CD.FACTIONS[f]["unlocks"] as Array).has(key):
			return true
	return false


## The faction that unlocks `key` ("" if none does, or it's there from the start).
func source_of(key: String) -> String:
	for f in CD.FACTIONS:
		if (CD.FACTIONS[f]["unlocks"] as Array).has(key):
			return f
	return ""


## Why `key` is locked, for a tooltip or message: who has to join first.
func lock_reason(key: String, lend: Array = []) -> String:
	var f := source_of(key)
	if f != "" and not allied(f) and not lend.has(key):
		return "Locked: earn the alliance of %s (%s)" % [CD.FACTIONS[f]["name"], CD.FACTIONS[f]["home"]]
	if not allied(CD.BUILDERS):
		return "Locked: needs the Engineers of Stonehollow to build it"
	return "Locked"


# --- Unit training ---------------------------------------------------------------

## XP needed to go from level n-1 to level n.
static func level_cost(n: int) -> float:
	return CD.XP_FIRST * pow(CD.XP_GROWTH, n - 1)


## The level `kind` has reached with its XP (0 to MAX_TRAINING).
func level_of(kind: String) -> int:
	var left: float = xp.get(kind, 0.0)
	var n := 0
	while n < CD.MAX_TRAINING and left >= level_cost(n + 1):
		left -= level_cost(n + 1)
		n += 1
	return n


## [XP into the current level, XP that level needs] (need is 0 at the top level).
func level_progress(kind: String) -> Array:
	var left: float = xp.get(kind, 0.0)
	var n := 0
	while n < CD.MAX_TRAINING and left >= level_cost(n + 1):
		left -= level_cost(n + 1)
		n += 1
	return [left, level_cost(n + 1) if n < CD.MAX_TRAINING else 0.0]


## Training points `kind` has to spend (earned by its levels, not yet spent; never more
## than its untrained tiers).
func points(kind: String) -> int:
	return clampi(level_of(kind) - int(spent.get(kind, 0)), 0, untrained_tiers(kind))


## Tiers still shut on `kind`'s paths (12 for a kind never trained).
func untrained_tiers(kind: String) -> int:
	var n := 0
	for p in 4:
		n += 4 - path_tier(kind, p)
	return n


## The highest tier `kind` may take on upgrade path `p` (1 until it's trained there).
func path_tier(kind: String, p: int) -> int:
	return int(unlocked.get(kind, [1, 1, 1, 1])[p])


## The highest tier open on any of `kind`'s paths.
func trained_tier(kind: String) -> int:
	var best := 1
	for p in 4:
		best = maxi(best, path_tier(kind, p))
	return best


## Every kind the Line can field now, in the game's usual order (all can be trained).
func trainable() -> Array:
	var out := []
	for kind in Data.WARRIORS:
		if allows(kind):
			out.append(kind)
	return out


func can_unlock(kind: String, p: int) -> bool:
	return points(kind) > 0 and path_tier(kind, p) < 4 and trainable().has(kind)


## Spends one of `kind`'s points on the next tier of path `p`. Returns whether it did.
func unlock(kind: String, p: int) -> bool:
	if not can_unlock(kind, p):
		return false
	var tiers: Array = unlocked.get(kind, [1, 1, 1, 1]).duplicate()
	tiers[p] += 1
	unlocked[kind] = tiers
	spent[kind] = int(spent.get(kind, 0)) + 1
	save_game()
	return true


## Banks a battle's XP (unit kind -> XP): all of it for a win, a share for a loss or a
## battle left early. Remembers what each kind earned (and any points) for the map.
func bank_xp(gains: Dictionary, won: bool) -> void:
	last_battle = {}
	var share := 1.0 if won else CD.XP_LOSS_SHARE
	for kind in gains:
		if not Data.WARRIORS.has(kind) or gains[kind] <= 0.0:
			continue
		var before := level_of(kind)
		xp[kind] = float(xp.get(kind, 0.0)) + gains[kind] * share
		last_battle[kind] = [gains[kind] * share, level_of(kind) - before]


# --- Classic on the campaign's battlefields ----------------------------------------

## The battlefields this campaign has opened, for Classic: each mission's map once the
## mission can be played (in the order the missions come). None without a campaign.
func open_maps() -> Array:
	var out := []
	if not has_save():
		return out
	for m in CD.MISSIONS:
		var d: Dictionary = CD.MISSIONS[m]
		var map: String = d.get("map", "")
		if map != "" and not out.has(map) and (completed.has(m) or requirements_met(d["territory"])):
			out.append(map)
	return out


# --- The map --------------------------------------------------------------------

func territory_done(t: String) -> bool:
	var ms: Array = CD.TERRITORIES[t]["missions"]
	return not ms.is_empty() and completed.has(ms[-1])


func requirements_met(t: String) -> bool:
	var req: Dictionary = CD.TERRITORIES[t]["requires"]
	for r in req.get("all", []):
		if not territory_done(r):
			return false
	if req.has("any"):
		var n := 0
		for r in req["any"]:
			if territory_done(r):
				n += 1
		if n < req.get("count", 1):
			return false
	return true


## "hidden", "locked", "available" (reachable, nothing to play there yet), "attack" (a
## mission to play) or "allied" (its last mission is won).
func territory_state(t: String) -> String:
	if territory_done(t):
		return "allied"
	if requirements_met(t):
		return "attack" if next_mission(t) != "" else "available"
	var d: Dictionary = CD.TERRITORIES[t]
	if d.get("known", false):
		return "locked"
	# Discovered once a road leads to it from somewhere already won.
	for r in CD.ROUTES:
		var other := ""
		if r[0] == t:
			other = r[1]
		elif r[1] == t:
			other = r[0]
		if other != "" and territory_done(other):
			return "locked"
	return "hidden"


## The first mission of territory t not yet won ("" if none is left, or none exists yet).
func next_mission(t: String) -> String:
	for m in CD.TERRITORIES[t]["missions"]:
		if not completed.has(m):
			return m
	return ""


## What has to happen before t opens up, in words.
func requirement_text(t: String) -> String:
	var req: Dictionary = CD.TERRITORIES[t]["requires"]
	var parts := []
	var all: Array = req.get("all", [])
	if not all.is_empty():
		parts.append("Defend " + " and ".join(all.map(func(r): return CD.TERRITORIES[r]["name"])))
	if req.has("any"):
		var names: Array = req["any"].map(func(r): return CD.TERRITORIES[r]["name"])
		parts.append("Defend any %d of %s" % [req.get("count", 1), ", ".join(names)])
	return "; ".join(parts)


func alliance_count() -> int:
	return allies.size()


# --- Missions -------------------------------------------------------------------

func mission() -> Dictionary:
	return CD.MISSIONS.get(mission_id, {})


## A mission was won or lost. A win records it, brings its faction into the Line, sets
## its story flags and saves; a loss changes nothing (the mission can just be retried).
func finish_mission(won: bool, new_flags: Array = [], gains: Dictionary = {}) -> void:
	var m := mission()
	if m.is_empty():
		return
	bank_xp(gains, won)
	if not won:
		save_game()
		return
	var first_win := not completed.has(mission_id)
	if first_win:
		completed.append(mission_id)
	just_joined = ""
	var f: String = m.get("reward", "")
	if f != "" and not allies.has(f):
		allies.append(f)
		just_joined = f
	for flag in new_flags:
		flags[flag] = true
	pending_story = m.get("outro", "")
	save_game()


## The lines of story `key` that apply to this campaign (conditions checked now).
func story_lines(key: String) -> Array:
	var out := []
	for line in CD.STORY.get(key, []):
		if _holds(line.get("if", {})):
			out.append(line)
	return out


func _holds(cond: Dictionary) -> bool:
	if cond.has("flag") and not flags.has(cond["flag"]):
		return false
	if cond.has("no_flag") and flags.has(cond["no_flag"]):
		return false
	if cond.has("ally") and not allied(cond["ally"]):
		return false
	if cond.has("no_ally") and allied(cond["no_ally"]):
		return false
	if cond.has("difficulty") and difficulty != cond["difficulty"]:
		return false
	return true


func mark_seen(key: String) -> void:
	if key != "" and not seen.has(key):
		seen.append(key)
		save_game()
