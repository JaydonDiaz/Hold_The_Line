extends RefCounted
## The campaign side of a battle: the start screen, the world map and prologue, starting a
## mission, lent units and help, mission waves and limits, and going back to the map.
## Part of the game controller: `main` is main.gd, which holds the battle's state.

const Main = preload("res://scripts/main.gd")
const Data = preload("res://scripts/data/data.gd")
const Warrior = preload("res://scripts/troops/warrior.gd")
const Barricade = preload("res://scripts/troops/barricade.gd")
const Maps = preload("res://scripts/campaign/maps.gd")
const CD_XP_RATES = preload("res://scripts/data/campaign_data.gd").XP_RATES    # a story campaign battle (the Campaign autoload says which mission)

const UprightArt = preload("res://scripts/ui/upright_art.gd")
const Enemy = preload("res://scripts/enemies/enemy.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")

var main: Main

var temp_allies := []    # units the mission put on the field from the start
var help_lend := []      # unlock keys the allied peoples' help brings to this battle (see _send_help)
## Campaign maps and battles keep the 640-wide portrait field whatever the window's
## shape (scaled to fit, with bars at the sides); Classic and the rest widen the field
## on a wide window, as before.
## A phone turned on its side: the game is played upright, so it waits behind a card
## asking for the phone to be turned back (browsers mostly won't lock the screen's
## rotation, an iPhone's never). Only on phones: a laptop's touchscreen isn't asked.
var _upright: CanvasLayer = null
var _upright_paused := false
var pretend_phone := false   # (tests: behave as on a phone)
var heat := 0   # extra enemy levels: the North growing bolder as you push into it (Campaign.north_heat)
## Campaign experience: `amount` of `what` (an XP_RATES key) done by unit kind `kind`
## this battle. Outside a campaign, or with no one to credit, it counts for nothing.
## A Sapper's set out for one of your emplacements (or walls): say so, now and then.
var sap_alert_t := -100.0


func _init(m: Main) -> void:
	main = m


# --- Campaign ------------------------------------------------------------

## Where a fresh scene starts: the title screen, or (between campaign battles, which
## reload the scene) the map or a mission.
func _open_start_screen() -> void:
	var where: String = Campaign.screen
	Campaign.screen = ""
	if where.begins_with("battle:"):
		_on_mode_chosen(where)   # a Battle Modes scenario played again
	elif where == "map":
		open_world_map()
	elif where == "battle" and not Campaign.mission().is_empty():
		main.setup.choose_mode("campaign")
	elif not Campaign.started_once and DisplayServer.get_name() != "headless":   # (tests run headless, straight to the title)
		# The very first screen of a run: the splash picture and a Start button (the
		# title music waits for that click, which a browser needs before any sound).
		_lock_portrait(false)
		main.hud.show_splash(func():
			Campaign.started_once = true
			main.hud.show_mode_select())
	else:
		_lock_portrait(false)
		main.hud.show_mode_select()


## A title-screen choice: a Classic difficulty, Freeplay, the Tutorial, or the campaign
## ("campaign:continue[:<slot>]", "campaign:new:<difficulty>[:<slot>]": the save slot in
## use when there's none).
func _on_mode_chosen(key: String) -> void:
	if key.begins_with("campaign:continue"):
		if key.get_slice_count(":") > 2:
			Campaign.use_slot(int(key.get_slice(":", 2)))
		if Campaign.load_game():
			open_world_map()
		else:
			main.hud.show_mode_select()
			main.hud.show_message(Campaign.load_error if Campaign.load_error != "" else "No campaign saved yet")
	elif key.begins_with("campaign:new:"):
		if key.get_slice_count(":") > 3:
			Campaign.use_slot(int(key.get_slice(":", 3)))
		Campaign.new_campaign(key.get_slice(":", 2))
		play_prologue()
	elif key.begins_with("battle:"):
		# A Battle Modes scenario: "battle:<scenario>:<difficulty>".
		# (The difficulty is the last part: a campaign battle's id has a colon of its own,
		# "story:<mission>".)
		var cut := key.rfind(":")
		main.battle_id = key.substr(7, cut - 7)
		main.setup.choose_mode(key.substr(cut + 1))
	else:
		# Classic on a campaign battlefield comes as "<difficulty>|<map>".
		main.classic_map = key.get_slice("|", 1) if "|" in key else ""
		main.setup.choose_mode(key.get_slice("|", 0))


func open_world_map() -> void:
	_lock_portrait(true)
	main.hud.hide_mode_select()
	var m = main.hud.show_world_map(Campaign)
	m.defend.connect(start_mission)
	m.menu.connect(func():
		Campaign.screen = ""
		main.modes._restart())
	m.sound.connect(func(n): main.effects.sfx(n))
	m.prologue.connect(play_prologue)


## The prologue cutscene (a new campaign, or replayed from the Ledger), then the map.
func play_prologue() -> void:
	_lock_portrait(true)
	main.hud.hide_mode_select()
	main.hud.hide_world_map()
	main.hud.play_prologue(open_world_map)


func start_mission(id: String) -> void:
	# A long operation with checkpoints asks where to begin it first.
	var cps: Array = Campaign.checkpoints_for(id)
	if not cps.is_empty() and main.hud.world_map != null:
		main.hud.show_start_choice(Campaign.missions[id]["name"], cps, func(z):
			Campaign.op_resume_zone = z
			_go_mission(id))
		return
	_go_mission(id)


func _go_mission(id: String) -> void:
	Campaign.mission_id = id
	main.hud.hide_world_map()
	main.setup.choose_mode("campaign")


func on_phone() -> bool:
	return pretend_phone or OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")


func _turn_upright(view: Vector2) -> void:
	var sideways := on_phone() and view.x > view.y
	if sideways == (_upright != null):
		return
	if sideways:
		_upright = CanvasLayer.new()
		_upright.layer = 128
		_upright.process_mode = Node.PROCESS_MODE_ALWAYS
		var back := ColorRect.new()
		back.color = Color(0.06, 0.05, 0.04)
		back.set_anchors_preset(Control.PRESET_FULL_RECT)
		back.mouse_filter = Control.MOUSE_FILTER_STOP
		_upright.add_child(back)
		var art := UprightArt.new()
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.add_child(art)
		main.add_child(_upright)
		_upright_paused = main.get_tree().paused
		main.get_tree().paused = true
	else:
		_upright.queue_free()
		_upright = null
		main.get_tree().paused = _upright_paused


func _lock_portrait(on: bool) -> void:
	var root := main.get_tree().root
	var want := Window.CONTENT_SCALE_ASPECT_KEEP if on else Window.CONTENT_SCALE_ASPECT_EXPAND
	if root.content_scale_aspect != want:
		root.content_scale_aspect = want
		main.setup._fit_screen()


## The mission's opening: its starting gold, the help already on the field, and its story.
func _begin_mission() -> void:
	main.gold = main.mission.get("gold", Data.START_GOLD)
	heat = Campaign.north_heat(Campaign.mission_id) if main.campaign else 0
	if heat > 0:
		main.hud.show_message("The North has grown bolder: its enemies are %d level%s stronger" % [heat, "" if heat == 1 else "s"])
	for a in main.mission.get("allies", []):
		_lend_unit(a)
	if main.campaign:
		_send_help()
	var intro: String = main.mission.get("intro", "")
	if intro != "" and not Campaign.seen.has(intro):
		Campaign.mark_seen(intro)
		main.hud.play_story(Campaign.story_lines(intro))


## A unit on loan for this battle ({"kind", "at"} as drawn up): free, and worth nothing sold.
func _lend_unit(a: Dictionary) -> void:
	var kind: String = a["kind"]
	var w := Warrior.new()
	var at: Vector2 = a["at"]
	w.setup(kind, Data.WARRIORS[kind], main, Vector2(at.x * main.FIELD_W / Maps.BASE_W, at.y))   # placed on the map as stretched
	w.spent = 0   # on loan: selling it brings nothing
	if a.has("tiers"):
		w.tiers = (a["tiers"] as Array).duplicate()   # (it comes trained: the locals showing what they can do)
		w._apply_upgrades()
		w.hp = w.max_hp
	w.position = w.post
	main.warrior_layer.add_child(w)
	temp_allies.append(w)
	if a.has("crew"):
		# A Tower lent with someone already posted in it (Tamsin's watchtower).
		var c := Warrior.new()
		c.setup(a["crew"], Data.WARRIORS[a["crew"]], main, w.post)
		c.spent = 0
		c.position = w.post
		main.warrior_layer.add_child(c)
		temp_allies.append(c)
		c.enter_tower(w)


## The peoples who've joined the Line send help ("help": {faction: {...}}), each only if
## they're allied: "allies" (units on loan), "gold", "free" (abilities, owned from the
## start: they can be cast though not yet unlocked), "down_time" (fallen troops hold on
## that much longer), "walls" ([[a, b]]: barricades already up).
func _send_help() -> void:
	var sent := []
	for f in main.mission.get("help", {}):
		if not Campaign.allied(f):
			continue
		var h: Dictionary = main.mission["help"][f]
		for a in h.get("allies", []):
			_lend_unit(a)
		main.gold += int(h.get("gold", 0))
		for key in h.get("free", []):
			help_lend.append("ability:" + key)
			main.powers.owned[key] = true
		main.down_time *= float(h.get("down_time", 1.0))
		var k: float = main.FIELD_W / Maps.BASE_W
		for seg in h.get("walls", []):
			var a: Vector2 = Vector2(seg[0].x * k, seg[0].y)
			var b: Vector2 = Vector2(seg[1].x * k, seg[1].y)
			var wall := Barricade.new()
			wall.half = (b - a) / 2.0
			wall.setup("barricade", Data.WARRIORS["barricade"], main, (a + b) / 2.0)
			wall.spent = 0
			wall.position = wall.post
			main.wall_layer.add_child(wall)
		if not h.get("walls", []).is_empty():
			main.battlefield.walls_changed()
		sent.append(h.get("note", f.capitalize()))
	if not sent.is_empty():
		main.hud.show_message("Help has come: " + ", ".join(sent))


## The mission's waves: wave n draws from every enemy kind its pool has added by then,
## plus that wave's extras.
func _mission_wave(n: int) -> Array:
	main.wave_squads = main.mission.get("squads", {}).get(n, [])
	var pool := []
	for w in main.mission["pool"]:
		if n >= w:
			pool.append_array(main.mission["pool"][w])
	var c: Array = main.mission.get("count", [6, 2])
	var list := []
	for i in c[0] + c[1] * n:
		list.append(pool.pick_random())
	for k in main.mission.get("extra", {}).get(n, []):
		list.insert(randi_range(list.size() / 2, list.size()), k)
	for sq in main.mission.get("squads", {}).get(n, []):
		var at := randi_range(list.size() / 3, list.size())
		var kinds: Array = Data.SQUADS[sq]["kinds"]
		for j in kinds.size():
			list.insert(at + j, kinds[j])
	if main.mission.get("endless", false):
		# On and on: Warlords lead every fifth wave from the tenth, Wyverns swoop in on the
		# even waves between from the twelfth (one more of each every ten waves).
		if n >= 10 and n % 5 == 0:
			for i in 1 + (n - 10) / 10:
				list.append("warlord")
		elif n >= 12 and n % 2 == 0:
			for i in 1 + (n - 12) / 10:
				list.insert(randi_range(list.size() / 3, list.size()), "wyvern")
	return list


## Enemy strength on wave n (Classic: the wave number; a mission starts at its level and
## goes up one a wave, or by its "level_step": a long operation's many waves climb slowly).
func wave_level(n: int) -> int:
	if not scripted():
		return n
	return int(main.mission["level"]) + heat + int(floor((n - 1) * float(main.mission.get("level_step", 1.0))))


## The wave that ends the game (or, in Classic, offers endless).
func last_wave() -> int:
	return int(main.mission.get("waves", 0)) if scripted() else Data.FINAL_WAVE


## Whether this battle follows a mission (a campaign battle, or a Battle Modes scenario)
## rather than Classic's endless waves.
func scripted() -> bool:
	return not main.mission.is_empty()


## Story flags the mission sets on a win: each "track" flag whose starting ally is still up.
func _mission_flags() -> Array:
	var out := []
	var track: Dictionary = main.mission.get("track", {})
	for flag in track:
		for w in temp_allies:
			if is_instance_valid(w) and not w.is_queued_for_deletion() and w.kind == track[flag] and w.is_active():
				out.append(flag)
				break
	return out


## Whether unlock key `key` (a unit kind, "ability:x", "path:n", "repair") can be used
## in this game. Only a campaign mission locks anything.
func allowed(key: String) -> bool:
	return not main.campaign or Campaign.allows(key, main.mission.get("lend", []) + help_lend)


## The highest upgrade tier `kind` may take on path `p` here: all four outside the
## campaign; in it, what that unit has been trained for on that path (see
## Campaign.path_tier). Without a path: its best-trained path.
func max_tier(kind: String, p := -1) -> int:
	if not main.campaign:
		return Warrior.MAX_TIER
	return Campaign.path_tier(kind, p) if p >= 0 else Campaign.trained_tier(kind)


func sap_alert(target) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - sap_alert_t < 8.0:
		return
	sap_alert_t = now
	var what: String = "a wall" if target is Barricade else "your " + str(target.label)
	main.hud.show_message("A Sapper's going for %s! Stop it before it gets there." % what)


func earn_xp(kind: String, amount: float, what := "damage") -> void:
	if main.campaign and kind != "" and amount > 0.0:
		main.battle_xp[kind] = main.battle_xp.get(kind, 0.0) + amount * CD_XP_RATES[what]


## Why `key` is locked ("" if it isn't).
func lock_note(key: String) -> String:
	return "" if allowed(key) else Campaign.lock_reason(key, main.mission.get("lend", []) + help_lend)


## Stops a locked action with a message saying who unlocks it.
func _locked(key: String) -> bool:
	if allowed(key):
		return false
	main.hud.show_message(lock_note(key))
	return true


func retry_mission() -> void:
	Campaign.screen = "battle"
	main.modes._restart()


func back_to_map() -> void:
	_bank_unfinished()
	Campaign.screen = "map"
	main.modes._restart()


## A campaign battle left before it ended (back to the map, or the game closed) earns
## nothing: its XP is dropped, and the save keeps what it had before the battle.
func _bank_unfinished() -> void:
	if main.campaign and not main.game_over:
		main.battle_xp = {}
		Campaign.last_battle = {}
