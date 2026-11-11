extends Node
## The story campaign's state (an autoload, "Campaign", so it outlives the scene reloads
## between the map and battles): the difficulty, which missions are won, who has joined
## the Line, story flags, and which screen the next scene load opens. Saved apart from the
## Classic records and the settings, in one of SLOTS save files: Save 1 is
## user://campaign.cfg (where the only save used to be), Save 2 user://campaign_2.cfg and
## so on. A launch picks up the one played last.
##
## Outside a campaign battle (Classic, Freeplay, the Tutorial) nothing here restricts
## anything: main.gd only asks allows() while it's playing a campaign mission.

const CD = preload("res://scripts/campaign_data.gd")
const Data = preload("res://scripts/data.gd")
const VERSION := 3   # bump when the save's shape changes, and migrate older saves in _read
# 1: the first campaign save.  2: adds troop training (points and trained tiers).
# 3: training is earned per unit by use (XP, points spent per path).

const SLOTS := 3

## The save file in use. Setting it (as the tests do, to keep off the player's saves)
## makes it Save 1, with the other slots beside it.
var save_path := "user://campaign.cfg":
	set(v):
		save_path = v
		if not _to_slot:
			base_path = v
			slot = 1
var base_path := "user://campaign.cfg"   # Save 1's file; Save n's is <base>_n.cfg
var slot := 1                            # the save slot in use (1..SLOTS)
var _to_slot := false
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
var just_lit := ""         # territory whose beacon the battle just won lit (the map announces it)
# The campaign's content (campaign_data.gd), read through these so tests can try other
# regional chains without changing the real ones.
var territories: Dictionary = CD.TERRITORIES
var missions: Dictionary = CD.MISSIONS


func _ready() -> void:
	use_slot(latest_slot())
	load_game()


# --- Saving -----------------------------------------------------------------

## Save `n`'s file.
func slot_path(n: int) -> String:
	return base_path if n <= 1 else "%s_%d.%s" % [base_path.get_basename(), n, base_path.get_extension()]


## Switches to save slot `n` (what's in memory isn't loaded or saved: see load_game).
func use_slot(n: int) -> void:
	_to_slot = true
	slot = clampi(n, 1, SLOTS)
	save_path = slot_path(slot)
	_to_slot = false


## The slot saved to last (Save 1 when there are none).
func latest_slot() -> int:
	var best := 1
	var when := -1
	for n in range(1, SLOTS + 1):
		if FileAccess.file_exists(slot_path(n)):
			var t := FileAccess.get_modified_time(slot_path(n))
			if t > when:
				when = t
				best = n
	return best


## What save `n` holds, for the title screen: {} if it's empty; else "difficulty",
## "alliances", "beacons", "missions" and "saved_at" (unix time, 0 if unknown), or "error"
## if it can't be played.
func slot_info(n: int) -> Dictionary:
	var cfg := ConfigFile.new()
	var err := cfg.load(slot_path(n))
	if err == ERR_FILE_NOT_FOUND:
		return {}
	if err != OK or not cfg.get_value("meta", "version", 0) is int or cfg.get_value("meta", "version", 0) < 1:
		return {"error": "Damaged: it can't be read"}
	if cfg.get_value("meta", "version", 0) > VERSION:
		return {"error": "From a newer version of the game"}
	var won := _strings(cfg.get_value("state", "completed", []), missions)
	var lit := beacon_territories().filter(func(t):
		var ms: Array = territories[t]["missions"]
		return not ms.is_empty() and ms.all(func(m): return won.has(m))).size()
	var diff = cfg.get_value("state", "difficulty", "normal")
	var at = cfg.get_value("meta", "saved_at", 0)
	return {"difficulty": diff if diff is String and Data.DIFFICULTIES.has(diff) else "normal",
		"alliances": _strings(cfg.get_value("state", "allies", []), CD.FACTIONS).size(),
		"beacons": lit, "missions": won.size(),
		"saved_at": int(at) if (at is int or at is float) else FileAccess.get_modified_time(slot_path(n))}


## Erases save `n` for good. If it's the one in use, the campaign in memory goes too.
func delete_slot(n: int) -> bool:
	var path := slot_path(n)
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	for f in [path, path + ".tmp"]:
		if FileAccess.file_exists(f):
			dir.remove(f.get_file())
	if n == slot:
		reset()
	return not FileAccess.file_exists(path)

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
	just_lit = ""


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
	completed = _strings(cfg.get_value("state", "completed", []), missions)
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
	cfg.set_value("meta", "saved_at", int(Time.get_unix_time_from_system()))
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
	return clampi(level_of(kind) + bonus_points(kind) - int(spent.get(kind, 0)), 0, untrained_tiers(kind))


## Of `kind`'s points, how many can't be spent until its home region's beacon is lit
## (everything below Tier IV already open, so only Tier IV is left to buy with them).
func points_waiting(kind: String) -> int:
	if tier4_open(kind):
		return 0
	var below := 0
	for p in 4:
		below += maxi(0, 3 - path_tier(kind, p))
	return maxi(0, points(kind) - below)


## Training points `kind` was given outright: an optional mission's reward on its first
## win ("bonus_points": {kind: n}). Worked out from the missions won, never stored.
func bonus_points(kind: String) -> int:
	var n := 0
	for m in completed:
		n += int(missions.get(m, {}).get("bonus_points", {}).get(kind, 0))
	return n


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
	return points(kind) > 0 and path_tier(kind, p) < 4 and trainable().has(kind) \
			and (path_tier(kind, p) < 3 or tier4_open(kind))


## The territory whose beacon opens `kind`'s Tier IV: the home of the people who bring
## it (Ashwatch for what the garrison has from the start). "" if none does.
func region_of(kind: String) -> String:
	if CD.START_UNLOCKS.has(kind):
		return "ashwatch"
	var f := source_of(kind)
	for t in territories:
		if f != "" and territories[t]["faction"] == f:
			return t
	return ""


## Whether `kind` may train Tier IV: its home region's beacon is lit.
func tier4_open(kind: String) -> bool:
	var t := region_of(kind)
	return t != "" and beacon_lit(t)


## Why the next tier of `kind`'s path `p` can't be opened now ("" if it can, or it's
## only a matter of points): for Tier IV, the home region's beacon.
func tier_lock_reason(kind: String, p: int) -> String:
	if path_tier(kind, p) == 3 and not tier4_open(kind):
		var t := region_of(kind)
		var name: String = territories[t]["name"] if t != "" else "its home region"
		return "Tier IV locked: complete %s's regional campaign and light its beacon" % name
	return ""


## The kinds a territory's beacon opens Tier IV for.
func tier4_kinds(t: String) -> Array:
	return Data.WARRIORS.keys().filter(func(k): return region_of(k) == t and not Data.WARRIORS[k].get("summon", false))


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


## Banks a battle's XP (unit kind -> XP): all of it for a win, a share for a loss. A
## kind behind the rest catches up at double XP (see catch_up_xp). Remembers what each
## kind earned for the map: [XP, training points reached, of that XP the catch-up bonus].
func bank_xp(gains: Dictionary, won: bool) -> void:
	last_battle = {}
	var share := 1.0 if won else CD.XP_LOSS_SHARE
	var target := catch_up_xp()
	for kind in gains:
		if not Data.WARRIORS.has(kind) or gains[kind] <= 0.0:
			continue
		var before := level_of(kind)
		var had: float = xp.get(kind, 0.0)
		var got: float = gains[kind] * share
		var bonus := clampf(target - had, 0.0, got)   # doubled, but only up to the catch-up mark
		xp[kind] = had + got + bonus
		last_battle[kind] = [got + bonus, level_of(kind) - before, bonus]


## XP to reach `level` from nothing.
static func xp_for_level(level: int) -> float:
	var total := 0.0
	for n in range(1, level + 1):
		total += level_cost(n)
	return total


## Catch-up: the XP of the average level among the unit kinds the Line has trained at
## all. A kind below it earns double XP until it gets there, so a people who join late
## (or a unit you've fielded less) isn't left behind, without speeding up the leaders.
func catch_up_xp() -> float:
	var levels := []
	for kind in xp:
		if xp[kind] > 0.0:
			levels.append(level_of(kind))
	if levels.is_empty():
		return 0.0
	var sum := 0
	for l in levels:
		sum += l
	return xp_for_level(floori(float(sum) / levels.size()))


## Whether `kind` earns double XP right now (it's below the catch-up mark).
func catching_up(kind: String) -> bool:
	return float(xp.get(kind, 0.0)) < catch_up_xp()


# --- Classic on the campaign's battlefields ----------------------------------------

## The battlefields this campaign has opened, for Classic: each mission's map once the
## mission can be played (in the order the missions come). None without a campaign.
func open_maps() -> Array:
	var out := []
	if not has_save():
		return out
	for m in missions:
		var d: Dictionary = missions[m]
		var map: String = d.get("map", "")
		if map != "" and not out.has(map) and (completed.has(m) or mission_open(m)):
			out.append(map)
	return out


# --- The map --------------------------------------------------------------------

## Whether territory t is secured: every one of its required missions won, so its
## beacon is lit. (Worked out from the missions won; never stored.)
func beacon_lit(t: String) -> bool:
	var ms: Array = territories[t]["missions"]
	if ms.is_empty():
		return false
	for m in ms:
		if not completed.has(m):
			return false
	return true


## (The old name: a territory is "done" once it's secured.)
func territory_done(t: String) -> bool:
	return beacon_lit(t)


## Whether t's people have joined the Line (for a territory with no people of its own,
## whether its first mission is won).
func joined(t: String) -> bool:
	var f: String = territories[t]["faction"]
	if f != "":
		return allied(f)
	var ms: Array = territories[t]["missions"]
	return not ms.is_empty() and completed.has(ms[0])


func _holds_req(req: Dictionary) -> bool:
	for r in req.get("joined", []):
		if not joined(r):
			return false
	for r in req.get("all", []):
		if not beacon_lit(r):
			return false
	if req.has("any"):
		var n := 0
		for r in req["any"]:
			if beacon_lit(r):
				n += 1
		if n < req.get("count", 1):
			return false
	return true


func requirements_met(t: String) -> bool:
	return _holds_req(territories[t]["requires"])


## Whether mission m can be played now: its territory is open and its own requirements
## are met.
## How long a mission is, for the map: its waves, or (a timed battle) what kind it is.
static func length_text(m: Dictionary) -> String:
	match m.get("type", "castle"):
		"evac":
			return "an evacuation"
		"escort":
			return "a convoy"
		"capture":
			return "take and hold"
		"protect":
			return "until it's done"
		"retreat":
			return "a fighting retreat"
	return "%d waves" % int(m.get("waves", 0))


func mission_open(m: String) -> bool:
	var d: Dictionary = missions.get(m, {})
	return not d.is_empty() and requirements_met(d["territory"]) and _holds_req(d.get("requires", {}))


## "hidden", "locked", "available" (reachable, nothing to play there yet), "attack" (its
## people not yet won over, a mission to play), "unfinished" (joined, required missions
## left) or "secured" (every required mission won: the beacon is lit).
func territory_state(t: String) -> String:
	if beacon_lit(t):
		return "secured"
	if joined(t):
		return "unfinished"
	if requirements_met(t):
		return "attack" if playable_mission(t) != "" else "available"
	var d: Dictionary = territories[t]
	if d.get("known", false):
		return "locked"
	# Discovered once a road leads to it from somewhere whose people have joined.
	for r in CD.ROUTES:
		var other := ""
		if r[0] == t:
			other = r[1]
		elif r[1] == t:
			other = r[0]
		if other != "" and territories.has(other) and joined(other):
			return "locked"
	return "hidden"


## The first required mission of territory t not yet won ("" if none is left, or none
## exists yet), whether or not it can be played yet.
func next_mission(t: String) -> String:
	for m in territories[t]["missions"]:
		if not completed.has(m):
			return m
	return ""


## The required mission to play next in t, if it can be played now ("" if not).
func playable_mission(t: String) -> String:
	var m := next_mission(t)
	return m if m != "" and mission_open(m) else ""


## t's optional missions that can be played now (once its people have joined), won or not.
func optional_missions(t: String) -> Array:
	if not joined(t):
		return []
	return (territories[t].get("optional", []) as Array).filter(func(m): return mission_open(m))


## [required missions won, required missions in all] for territory t.
func progress(t: String) -> Array:
	var ms: Array = territories[t]["missions"]
	return [ms.filter(func(m): return completed.has(m)).size(), ms.size()]


## What has to happen before `req` is met, in words.
func req_text(req: Dictionary) -> String:
	var parts := []
	var j: Array = req.get("joined", []).filter(func(r): return not joined(r))
	if not j.is_empty():
		parts.append("Win over " + " and ".join(j.map(func(r): return territories[r]["name"])))
	var all: Array = req.get("all", []).filter(func(r): return not beacon_lit(r))
	if not all.is_empty():
		parts.append("Light the beacon%s of %s" % ["s" if all.size() > 1 else "", " and ".join(all.map(func(r): return territories[r]["name"]))])
	if req.has("any"):
		var names: Array = req["any"].map(func(r): return territories[r]["name"])
		var lit: int = req["any"].filter(func(r): return beacon_lit(r)).size()
		parts.append("Light the beacons of any %d of %s (%d lit)" % [req.get("count", 1), ", ".join(names), lit])
	return "; ".join(parts)


## What has to happen before t opens up, in words.
func requirement_text(t: String) -> String:
	return req_text(territories[t]["requires"])


func alliance_count() -> int:
	return allies.size()


## Beacons lit, of the territories that have one (every territory with missions of its
## own and a people, plus Ashwatch).
func beacon_count() -> int:
	return beacon_territories().filter(func(t): return beacon_lit(t)).size()


func beacon_territories() -> Array:
	return territories.keys().filter(func(t): return territories[t]["faction"] != "" or t == "ashwatch")


## Every people's beacon lit: the fully united ending.
func fully_united() -> bool:
	for t in territories:
		if territories[t]["faction"] != "" and not beacon_lit(t):
			return false
	return true


# --- Missions -------------------------------------------------------------------

func mission() -> Dictionary:
	return missions.get(mission_id, {})


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
	var t: String = m.get("territory", "")
	var was_lit := t != "" and territories.has(t) and beacon_lit(t)
	var first_win := not completed.has(mission_id)
	if first_win:
		completed.append(mission_id)
	just_lit = t if t != "" and territories.has(t) and not was_lit and beacon_lit(t) else ""
	if first_win:
		# An optional mission's reward: training points for a unit of its region, once.
		var bonus: Dictionary = m.get("bonus_points", {})
		for kind in bonus:
			var row: Array = last_battle.get(kind, [0.0, 0, 0.0])
			row[1] = int(row[1]) + int(bonus[kind])
			last_battle[kind] = row
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
