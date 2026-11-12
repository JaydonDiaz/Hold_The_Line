extends SceneTree
## Battle rules other than castle defense (scripts/mission/): Hold the Pass and Multiple
## Positions, as campaign missions and as Battle Modes scenarios. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/missions_test.gd
## Uses a temporary campaign save. Exits 1 if anything failed.

const TEST_SAVE := "user://missions_test.cfg"
const Warrior = preload("res://scripts/warrior.gd")

var main
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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _play(mission_id: String) -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud.hide_mode_select()
	main.start_mission(mission_id)
	await process_frame
	if main.hud.story != null:
		main.hud.story.skip()
	await process_frame
	main._lock_portrait(true)
	await _frames(2)


func _run() -> void:
	campaign = root.get_node("Campaign")
	campaign.save_path = TEST_SAVE
	await _pass()
	await _positions()
	await _battle_modes()
	await _forced_pace()
	await _protect()
	await _evac()
	await _capture()
	await _escort()
	await _armoury()
	await _retreat()
	await _targeting()
	await _classic_unchanged()
	if main != null:
		main.free()
	campaign.reset()
	for f in [TEST_SAVE, TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


# --- Hold the Pass ----------------------------------------------------------------------

## Hold the Pass, as a campaign mission (Ashwatch's second mission was one, before it
## became the Armoury Wagon): played in Ashwatch's place, to test the pass rules and that
## winning one lights the territory's beacon.
const PASS_MISSION := {"name": "The Ridge Road", "territory": "ashwatch", "type": "pass", "limit": 10,
	"waves": 5, "level": 5, "gold": 340, "count": [7, 2], "mood": "normal", "map": "ashwatch_ridge",
	"requires": {"joined": ["stonehollow"]},
	"pool": {1: ["goblin", "goblin", "orc"], 2: ["wolf"], 3: ["sapper"], 4: ["orc"]},
	"extra": {2: ["skeleton_archer"], 3: ["troll", "skeleton_archer"], 4: ["wolf", "skeleton_archer"],
		5: ["troll", "orc", "orc", "skeleton_archer"]},
	"notes": {1: "Hold the ridge road: no more than 10 may get past your lines.", 2: "Wolves run for any gap. Wall it.",
		5: "Their column is on the road. A Troll counts double if it gets through!"},
	"allies": [{"kind": "tower", "at": Vector2(320, 560), "built": true},
		{"kind": "swordsman", "at": Vector2(250, 470)}, {"kind": "swordsman", "at": Vector2(390, 470)}],
	"lend": [], "reward": "", "track": {},
	"intro": "ashwatch_road_intro", "outro": "ashwatch_road_outro"}



func _pass() -> void:
	campaign.new_campaign("normal")
	campaign.completed = ["ashwatch", "stonehollow"]
	campaign.allies = ["stonehollow"]
	var real: Dictionary = campaign.missions
	campaign.missions = real.duplicate()
	campaign.missions["ashwatch_road"] = PASS_MISSION
	await _play("ashwatch_road")
	var r = main.rules
	check(r.get_script().resource_path.ends_with("rules_pass.gd") and not r.has_castle(), "Pass: a Hold the Pass mission plays by its rules")
	check(not main.castle.visible and main.camp != null and main.camp.is_inside_tree(), "...no castle: a work camp holds the bottom of the field")
	main.hud.refresh(main)
	check(not main.hud.tab_buttons["repair"].visible and main.hud.lives_label.text == "Past 0/10", "...no Repair tab; the panel counts who got past (%s)" % main.hud.lives_label.text)
	check(main.hud.status_label.visible and "0 of 10" in main.hud.status_label.text, "...and the field says how many may (%s)" % main.hud.status_label.text)
	main.select_castle()
	check(not main.castle_selected and not main.on_castle(Vector2(320, main.CASTLE_Y + 10)), "...there's no castle to click or upgrade")
	var hp: float = main.castle_hp
	main.damage_castle(100.0)
	check(main.castle_hp == hp and not main.game_over, "...and nothing can damage a castle that isn't there")
	# Enemies that reach the bottom are gone, and counted.
	main.wave_active = true
	main.spawn_queue.clear()
	for k in 2:
		var kind: String = ["goblin", "troll"][k]
		main._spawn_enemy(kind, 1, Vector2(260 + k * 120, main.CASTLE_Y - 30))
		var e = main.enemy_layer.get_children()[-1]   # (get_enemies() is kept for the frame)
		e.position = Vector2(260 + k * 120, main.CASTLE_Y - e.radius * 0.5 - 1.0)   # a step from the line
	await _frames(40)
	check(r.through == 3 and main.get_enemies().is_empty(), "A Goblin and a Troll reach the bottom: 3 through (a Troll counts 2), both off the field")
	# A Sapper's bomb at the bottom line doesn't go off against a castle that isn't there.
	main._spawn_enemy("sapper", 1, Vector2(200, main.CASTLE_Y - 14))
	await _frames(20)
	check(r.through == 4 and main.castle_hp == hp, "...a Sapper just gets through, its bomb unlit")
	# More than the limit: lost.
	r.through = r.limit()
	main._spawn_enemy("goblin", 1, Vector2(320, main.CASTLE_Y - 14))
	await _frames(20)
	check(main.game_over and not main.victory, "One more than the limit: the pass is lost")
	check("Too many broke through" in r.summary(false), "...and the end screen says why")
	# Clearing the last wave inside the limit: held.
	await _play("ashwatch_road")
	main.wave = main.last_wave() - 1
	main.start_wave()
	await _frames(2)
	main.spawn_queue.clear()
	for e in main.get_enemies():
		e.free()
	main.enemies_changed()
	await _frames(10)
	check(main.game_over and main.victory and campaign.beacon_lit("ashwatch"), "Clearing the last wave inside the limit holds the pass, and lights Ashwatch's beacon")
	campaign.missions = real


# --- Multiple Positions -------------------------------------------------------------------

func _positions() -> void:
	campaign.new_campaign("normal")
	campaign.completed = ["ashwatch", "stonehollow"]
	campaign.allies = ["stonehollow"]
	await _play("stonehollow_workshops")
	var r = main.rules
	var objs: Array = r.objectives()
	check(r.get_script().resource_path.ends_with("rules_positions.gd") and objs.size() == 3 and not r.has_castle() and not main.castle.visible \
			and main.camp != null and r.objective_only(), "Positions: Protect the Workshops has three workshops, no castle: they're what it's about")
	check(objs.all(func(o): return o.is_inside_tree() and main.paths.troop_can_stand(o.position + Vector2(0, o.RADIUS + 22))),
			"...each stands on open ground troops can reach")
	main.hud.refresh(main)
	check(main.hud.status_label.visible and "3 of 3" in main.hud.status_label.text, "...the field says how many stand (%s)" % main.hud.status_label.text)
	check(main.ground_problem(objs[0].position + Vector2(10, 0)) != "" and not main.can_post_at(objs[0].position + Vector2(10, 0)),
			"...nothing can be posted on a workshop")
	check(main.wall_problem(objs[1].position + Vector2(-60, 0), objs[1].position + Vector2(60, 0)) != "", "...nor a wall built through one")
	# Enemies are sent for the workshops (most of them), and get there round the terrain.
	main.wave_active = true
	main.spawn_queue.clear()
	var sent := {}
	for i in 40:
		main._spawn_enemy("goblin", 1)
		var e = main.enemy_layer.get_children()[-1]
		var key: String = e.goal.id if e.goal != null else "castle"
		sent[key] = sent.get(key, 0) + 1
	check(not sent.has("castle") and sent.size() == 3, "...every enemy goes for a workshop, split between the three (%s)" % str(sent))
	for e in main.get_enemies():
		e.free()
	main.enemies_changed()
	await process_frame
	for w in main.get_warriors():
		w.free()   # (the mission's two Swordsmen would stop it on the way)
	main.warriors_changed()
	var target = objs[0]
	main._spawn_enemy("orc", 1)
	var orc = main.enemy_layer.get_children()[-1]
	orc.goal = target
	orc.max_hp = 1e6
	orc.hp = 1e6
	var hp0: float = target.hp
	var inside := false
	for f in 60 * 30:
		await process_frame
		if not is_instance_valid(orc):
			break
		inside = inside or main.paths.blocked(orc.position, orc.radius * 0.5)
		if target.hp < hp0:
			break
	check(target.hp < hp0, "An Orc sent for the West Workshop finds its way there through the quarry and hacks at it")
	check(not inside, "...never walking into the cliffs on the way")
	# One that ends up beside its workshop, below it by the guildhall wall, closes in and
	# strikes (it used to stand there, a step short, for good).
	orc.position = target.position + Vector2(27, 58)
	orc.aggro = null
	hp0 = target.hp
	await _frames(60 * 4)
	check(target.hp < hp0, "...and one that ends up just beside it, by the wall, closes in and strikes too")
	# Workshops fall: one may go; the second loses the battle.
	target.take_damage(1e9)
	await _frames(3)
	check(target.dead and not main.game_over and "2 of 3" in r.status(), "Losing one workshop: the battle goes on (%s)" % r.status())
	check(orc.goal != target, "...and the enemies sent for it move on to another")
	objs[1].take_damage(1e9)
	await _frames(3)
	check(main.game_over and not main.victory and "Too many" in r.summary(false), "Losing a second: the battle is lost")
	# Winning: the last wave cleared with the workshops standing lights Stonehollow's beacon.
	await _play("stonehollow_workshops")
	main.wave = main.last_wave() - 1
	main.start_wave()
	await _frames(2)
	main.spawn_queue.clear()
	for e in main.get_enemies():
		e.free()
	main.enemies_changed()
	await _frames(10)
	check(main.game_over and main.victory and campaign.beacon_lit("stonehollow") and campaign.tier4_open("barricade"),
			"Clearing the last wave with the workshops standing lights Stonehollow's beacon: Barricade Tier IV opens")


# --- Battle Modes ---------------------------------------------------------------------------

func _battle_modes() -> void:
	campaign.reset()   # no campaign at all: Battle Modes don't need one
	for f in [TEST_SAVE]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	var hud = main.hud
	await create_timer(0.8).timeout
	hud._show_cards("battle")
	var names: Array = hud.mode_cards.map(func(c): return (c.get_child(0) as Label).text)
	check(names == ["Multiple Positions", "Hold the Pass", "Protect the Objective", "Evacuation", "Capture and Hold",
			"Convoy Escort", "Fighting Retreat", "Back"], "Battle Modes: the seven kinds besides Classic's castle, and Back (%s)" % ", ".join(names))
	# Two rows of four along the bottom: every card clear of the castle, inside the screen, and no
	# character used twice.
	await create_timer(1.0).timeout
	var low := true
	for c in hud.mode_cards:
		low = low and c.position.y >= 630.0 and c.position.x >= 0.0 and c.position.x + c.size.x <= 640.0
	check(low, "...laid out in two rows of four along the bottom of the screen")
	var looks: Array = hud.mode_cards.map(func(c): return (c.get_child(1) as TextureRect).texture)
	var seen := {}
	for t in looks:
		seen[t] = true
	check(seen.size() == looks.size(), "...each with its own character")
	# Hovering one sets the title screen's scene for that kind of battle, as the Classic cards do.
	var ts = hud.title_scene
	var scenes := {}
	for c in hud.mode_cards:
		var lk: String = c.get_meta("look", "")
		if ts.LOOKS.has(lk) and lk != "":
			scenes[lk] = true
	check(scenes.size() == 7 and scenes.keys().all(func(k): return main.Scenarios.TYPES.has(k)),
			"...and its own scene behind the castle while it's hovered (%s)" % ", ".join(scenes.keys()))
	hud.mode_cards[0].mouse_entered.emit()
	check(ts.look == "positions", "...hovering Multiple Positions shows its scene (%s)" % ts.look)
	hud.mode_cards[0].mouse_exited.emit()
	await create_timer(0.4).timeout
	check(ts.look == "", "...and leaving it goes back to the plain title screen")
	for lk in ["positions", "pass", "protect", "evac", "capture", "escort", "retreat"]:
		ts.set_look(lk)
		await create_timer(0.5).timeout
		var start := {}
		for a in ts.actors:
			if not a["leaving"]:
				start[a["id"]] = a["pos"]
		await create_timer(4.5).timeout
		var live: Array = ts.actors.filter(func(a): return not a["leaving"])
		var kinds: Array = live.map(func(a): return a["kind"])
		var foes: int = live.filter(func(a): return a["side"] == "foe").size()
		var ok := foes > 0
		match lk:
			"positions":
				ok = ok and live.filter(func(a): return a["kind"] == "watchtower" and a.get("objective", false)).size() == 2 \
						and "engineer" in kinds
			"pass":
				ok = ok and kinds.count("crag") == 4 and "swordsman" in kinds
			"protect":
				ok = ok and "beacon" in kinds and "mage" in kinds
			"evac":
				ok = ok and kinds.count("cottage") == 2 and ts.actors.any(func(a): return a["side"] == "walker")
			"capture":
				ok = ok and "fort" in kinds and "martial" in kinds
			"escort":
				var wagon = ts._prop("wagon")
				ok = ok and wagon != null and start.has(wagon["id"]) and wagon["pos"].x > start[wagon["id"]].x + 100.0 \
						and live.filter(func(a): return a["role"] == "escort").all(func(a): return a["pos"] == wagon["pos"] + a["off"])
			"retreat":
				ok = ok and ts.cur["storm"] > 0.9 and live.filter(func(a): return a["side"] == "guard" and start.has(a["id"])) \
						.all(func(a): return a["pos"].x < start[a["id"]].x - 40.0)
		check(ok, "...the %s scene plays out (%s, %d foes)" % [lk, ", ".join(kinds), foes])
	ts.set_look("evac")
	var reached := false
	for i in 40:
		await create_timer(0.25).timeout
		reached = reached or ts.actors.any(func(a): return a["side"] == "walker" and a["leaving"] and a["pos"].y <= ts.GROUND_Y + 12.0)
	check(reached, "...in the evacuation, villagers walk in at the castle gate")
	ts.set_look("campaign")
	await create_timer(0.3).timeout
	var dark: bool = ts.chain < 0.6
	await create_timer(3.4).timeout
	check(ts.BEACONS.size() == 8 and dark and ts.chain >= 0.6 + 7 * 0.35,
			"The far country has the eight peoples' beacons, lit one by one for the Campaign")
	ts.set_look("")
	hud._show_cards("top")
	looks = hud.mode_cards.map(func(c): return (c.get_child(1) as TextureRect).texture)
	seen = {}
	for t in looks:
		seen[t] = true
	check(seen.size() == looks.size(), "The main menu cards each have their own character too")
	hud._show_cards("bm:positions")
	names = hud.mode_cards.map(func(c): return (c.get_child(0) as Label).text)
	check(names[0] == "The Three Watchtowers", "...each with a battle to play without a campaign (%s)" % names[0])
	hud._show_cards("bmd:three_towers")
	names = hud.mode_cards.map(func(c): return (c.get_child(0) as Label).text)
	check(names == ["Easy", "Normal", "Hard", "Back"], "...on any difficulty")
	main.records_path = "user://missions_test_records.cfg"
	if FileAccess.file_exists(main.records_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(main.records_path))
	main._on_mode_chosen("battle:three_towers:hard")
	await _frames(3)
	main._lock_portrait(true)
	await _frames(2)
	check(not main.campaign and main.battle_id == "three_towers" and main.difficulty == "hard" and main.rules.objectives().size() == 3 \
			and not main.castle.visible and main.camp != null, "The Three Watchtowers on Hard: three watchtowers to hold, and no castle")
	var all_open := true
	for k in main.Data.WARRIORS:
		all_open = all_open and main.allowed(k) and main.max_tier(k, 0) == 4
	check(all_open, "...with every unit and every tier open, as in Classic")
	main.gold = 999
	main.placing_type = "swordsman"
	main.hire_at(Vector2(320, 560))
	main.placing_type = ""
	main.earn_xp("swordsman", 500.0)
	check(main.battle_xp.is_empty() and campaign.xp.is_empty(), "...and no campaign XP is earned")
	main.hud.refresh(main)
	check(main.survival() and main.hud.wave_label.text == "Wave 0" and main.hud.lives_label.text == "Towers 3/3",
			"...a survival battle: no last wave (%s, %s)" % [main.hud.wave_label.text, main.hud.lives_label.text])
	var towers: Array = main.rules.objectives()
	# A watchtower stands over whoever's behind it: its top is drawn over the troops (and
	# goes see-through while someone's back there).
	var t0 = towers[0]
	var behind = main.get_warriors()[-1]
	var was: Vector2 = behind.position
	behind.position = t0.position + Vector2(0, -90)
	await _frames(8)
	check(t0.roof_mask != null and t0.roof_mask.get_parent() == main.roof_layer and main.roof_layer.get_index() > main.warrior_layer.get_index() \
			and t0.roof_mask.modulate.a < 1.0, "A troop behind a watchtower is behind its roof (drawn over the troops, see-through)")
	behind.position = was
	await _frames(8)
	check(t0.roof_mask.modulate.a == 1.0, "...and it's solid again once nobody's there")
	towers[0].hp = towers[0].max_hp * 0.5
	main.wave = 7
	main.start_wave()
	await _frames(2)
	main.spawn_queue.clear()
	for e in main.get_enemies():
		e.free()
	main.enemies_changed()
	await _frames(10)
	check(not main.game_over and main.waves_survived() == 8 and absf(towers[0].hp / towers[0].max_hp - 0.65) < 0.01,
			"Wave 8 cleared: it goes on, and the crews patch the towers up (%d%%)" % roundi(towers[0].hp / towers[0].max_hp * 100.0))
	towers[0].take_damage(1e9)
	towers[1].take_damage(1e9)
	await _frames(5)
	var cfg := ConfigFile.new()
	cfg.load(main.records_path)
	check(main.game_over and not main.victory and cfg.get_value("survive", "three_towers@hard", -1) == 8,
			"Two towers down: the run's over, and its 8 waves kept as the best (Hard)")
	var shown := []
	for n in main.hud.get_children():
		if n is ColorRect:
			for l in n.get_children():
				if l is Label:
					shown.append(l.text)
	check("You survived 8 waves" in shown and "New best!" in shown, "...the end screen says so (%s)" % ", ".join(shown))
	main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.records_path = "user://missions_test_records.cfg"
	await create_timer(0.8).timeout
	main.hud._show_cards("bmd:three_towers")
	check("Best: 8 waves" in (main.hud.mode_cards[2].get_child(2) as Label).text and "No run yet" in (main.hud.mode_cards[0].get_child(2) as Label).text,
			"...and so does Hard's card on the menu (Easy: no run yet)")
	main.play_again("battle:three_towers:hard")
	check(campaign.screen == "battle:three_towers:hard", "...and Play again starts the same battle")
	campaign.screen = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://missions_test_records.cfg"))
	# The Open Road: Hold the Pass on the meadow, no castle.
	await _fresh_battle("battle:open_road:normal")
	check(main.rules.get_script().resource_path.ends_with("rules_pass.gd") and not main.castle.visible and main.rules.limit() == 20,
			"The Open Road: Hold the Pass on the meadow, no castle, 20 may get through")
	# No army and no way to raise one ends a battle here too (and the run's best is kept).
	await _go()
	main.spawn_queue.clear()
	main.gold = 0
	await _frames(int(main.ROUT_GRACE * 60) + 20)
	check(main.game_over and main.routed and "Every troop was lost" in main._summary(false), "No troops and no gold to hire any: the battle's lost here too")


func _fresh_battle(key: String) -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud.hide_mode_select()
	main.records_path = ""
	main._on_mode_chosen(key)
	await _frames(3)


## The battle as a campaign mission would play it (not endless), with `changes` to its data.
func _finite(changes := {}) -> void:
	var m: Dictionary = main.mission.duplicate(true)
	m["endless"] = false
	m.merge(changes, true)
	main.mission = m
	main.rules.mission = m


# --- Forced pace, and the timed and moving battles ----------------------------------------

## Skips the deployment: the first wave comes now.
func _go() -> void:
	main.auto_timer = 0.0
	await _frames(3)


func _forced_pace() -> void:
	await _fresh_battle("battle:signal_beacon:normal")
	check(main.forced_auto and main.auto_play and main.deploying and main.auto_timer > 10.0, "Forced pace: auto-play is on from the start, with time to deploy (%ds)" % ceili(main.auto_timer))
	main.hud.refresh(main)
	check(main.hud.auto_btn.disabled and "Deploy" in main.hud.start_btn.text, "...the Auto button can't be switched off; the panel counts down the deployment (%s)" % main.hud.start_btn.text)
	main.toggle_auto()
	check(main.auto_play, "...and the A key doesn't turn it off either")
	await _go()
	check(main.wave == 1 and main.wave_active and not main.deploying, "...when it's up, the first wave comes by itself")
	main.spawn_queue.clear()
	for e in main.get_enemies():
		e.free()
	main.enemies_changed()
	await _frames(5)
	check(not main.wave_active and main.auto_timer > 20.0 and main.auto_timer <= 25.0, "...beaten at once: most of the 25s window is a breather (%.1fs)" % main.auto_timer)
	main.hud.refresh(main)
	check("Rest" in main.hud.start_btn.text, "...the panel counts it down (%s)" % main.hud.start_btn.text)
	main.gold = 999
	main.placing_type = "swordsman"
	main.hire_at(Vector2(320, 600))
	main.placing_type = ""
	var sw = main.get_warriors()[-1]
	sw.hp = sw.max_hp * 0.5
	await _frames(60 * 3)
	check(sw.hp > sw.max_hp * 0.55, "...troops get some health back while they rest (%d%%)" % roundi(sw.hp / sw.max_hp * 100.0))
	# A wave not beaten: the next still waits the window from the last of this one arriving.
	main.auto_timer = 0.0
	await _frames(3)
	main.spawn_queue.clear()
	main._spawn_enemy("orc", 1, Vector2(320, 100))
	var holdout = main.enemy_layer.get_children()[-1]
	holdout.speed = 0.0
	holdout.max_hp = 1e6
	holdout.hp = 1e6
	var w0: int = main.wave
	await _frames(60 * 20)
	main.hud.refresh(main)
	check(main.wave == w0 and main.wave_active and "Wave %d in" % (w0 + 1) in main.hud.start_btn.text,
			"With enemies still on the field, 20s on: the next wave hasn't come yet (%s)" % main.hud.start_btn.text)
	await _frames(60 * 6)
	check(main.wave == w0 + 1, "...it comes once the 25s window is up, beaten or not")
	check(Engine.time_scale == 1.0 and main.cycle_speed() == null and Engine.time_scale == 2.0, "...and the speed control still works")
	Engine.time_scale = 1.0


func _protect() -> void:
	await _fresh_battle("battle:signal_beacon:normal")
	main._lock_portrait(true)
	await _frames(2)
	var r = main.rules
	var beacon = r.objectives()[0]
	check(r.get_script().resource_path.ends_with("rules_protect.gd") and beacon.kind == "beacon" and not r.has_castle() and main.camp != null,
			"Protect the Objective: a beacon to keep standing while it charges, no castle")
	await _frames(30)
	check(beacon.progress == 0.0, "...it doesn't charge during the deployment")
	await _go()
	main.spawn_queue.clear()
	for e in main.get_enemies():
		e.free()
	main.enemies_changed()
	await _frames(60)
	check(beacon.progress > 0.0 and "%" in r.status(), "...then it charges (%s)" % r.status())
	var p0: float = beacon.progress
	main._spawn_enemy("orc", 1, beacon.position + Vector2(0, -50))
	var orc = main.enemy_layer.get_children()[-1]
	orc.position = beacon.position + Vector2(0, -beacon.RADIUS - orc.radius - 4)
	orc.speed = 0.0
	await _frames(30)
	check(beacon.contested and absf(beacon.progress - p0) < 0.01 and beacon.hp < beacon.max_hp, "...an enemy at it stops the charge, and hurts it")
	orc.free()
	main.enemies_changed()
	var gold0: int = main.gold
	var c0: float = beacon.charge
	beacon.hp = beacon.max_hp * 0.5
	beacon.progress = 0.999
	await _frames(30)
	check(not main.game_over and r.lit == 1 and beacon.progress < 0.1 and main.gold > gold0 and beacon.charge > c0 and beacon.hp > beacon.max_hp * 0.7,
			"Fully charged: it's lit, paid for and patched up, and starts again (longer: %ds)" % roundi(beacon.charge))
	_finite()
	beacon.progress = 0.999
	await _frames(30)
	check(main.game_over and main.victory, "...(as a campaign mission: fully charged wins the battle)")
	await _fresh_battle("battle:signal_beacon:normal")
	await _go()
	main.rules.objectives()[0].take_damage(1e9)
	await _frames(5)
	check(main.game_over and not main.victory, "...destroyed first: lost")


func _evac() -> void:
	await _fresh_battle("battle:village_road:normal")
	main._lock_portrait(true)
	await _frames(2)
	var r = main.rules
	check(r.get_script().resource_path.ends_with("rules_evac.gd") and main.forced_auto and not r.has_castle(), "Evacuation: forced pace, no castle")
	var houses: Array = main.paths._map.get("terrain", []).filter(func(t): return t["kind"] == "house")
	check(main.map_id == "village_fields" and houses.size() == 4 and main.paths._map["trails"].size() >= 2,
			"...the villagers' cottages at the top of the field, and their two roads worn into it")
	await _frames(30)
	check(r.objectives().is_empty(), "...nobody sets out during the deployment")
	await _go()
	main.spawn_queue.clear()
	for e in main.get_enemies():
		e.free()
	main.enemies_changed()
	r.next_in = 0.0
	await _frames(5)
	var size := int(r._evac()["size"])
	check(r.sent == 1 and r.objectives().size() == size, "...then the villagers set out, a family at a time (%d people)" % r.objectives().size())
	var g = r.objectives()[0]
	check(g.kind == "civilian" and g.is_mover() and g.look in g.VILLAGERS and g.max_hp == r.objectives()[1].max_hp,
			"...each their own villager (a sprite: %s), with their own health" % g.look)
	var looks := {}
	for v in r.objectives():
		looks[v.look + str(v.variant)] = true
	check(looks.size() > 1, "...not all alike (%d looks)" % looks.size())
	var start: Vector2 = g.position
	await _frames(60)
	check(g.position.distance_to(start) > 20.0, "...walking their road")
	main._spawn_enemy("goblin", 1, Vector2(g.position.x, 120))
	var gob = main.enemy_layer.get_children()[-1]
	var nearest = r.objectives()[0]
	for v in r.objectives():
		if v.position.distance_to(gob.position) < nearest.position.distance_to(gob.position):
			nearest = v
	check(gob.goal == nearest, "...enemies go after the nearest of them")
	gob.free()
	main.enemies_changed()
	g.take_damage(g.max_hp * 0.4)
	check(not g.dead and g.panic > 0.0 and r.objectives()[1].hp == r.objectives()[1].max_hp, "A villager hit is hurt alone (and runs for it)")
	main.gold = 9999
	main.placing_type = "healer"
	main.hire_at(Vector2(g.position.x + 40, 560))
	main.placing_type = ""
	var medic = main.get_warriors()[-1]
	medic.position = g.position + Vector2(40, 10)
	var vhp: float = g.hp
	for v in r.objectives():
		v.speed = 0.0   # (held still while it's checked)
	await _frames(60 * 2)
	check(g.hp > vhp and medic.priority == "revive", "A Healer mends a hurt villager too (%d to %d)" % [roundi(vhp), roundi(g.hp)])
	medic.free()
	main.warriors_changed()
	for v in r.objectives():
		v.speed = 30.0
	for v in r.objectives():
		v.speed = 2000.0
	await _frames(30)
	check(r.saved == size, "Each villager who gets to the camp is saved (%d)" % r.saved)
	r.next_in = 0.0
	await _frames(3)
	var fam: Array = r.objectives().slice(0, size)   # (the family that got there has left the field)
	check(fam.size() == size and fam.all(func(v): return not v.arrived), "...the next family sets out, the last one done with")
	fam[0].take_damage(1e9)
	fam[1].take_damage(1e9)
	await _frames(3)
	check(r.lost == 2 and not main.game_over, "Each one caught is lost (2), and the evacuation goes on")
	# With nobody on the road, raiders wait mid-field for the next family.
	for v in fam:
		v.free()
	r.people = r.people.filter(func(v): return is_instance_valid(v))
	main._spawn_enemy("goblin", 1, Vector2(200, 200))
	gob = main.enemy_layer.get_children()[-1]
	gob.goal = null
	await _frames(60 * 6)
	check(gob.goal == null and not gob.dead and gob.position.y < r.wait_y() + 20.0, "...raiders with nobody to chase wait mid-field (y %d)" % gob.position.y)
	r.next_in = 0.0
	await _frames(70)
	check(gob.goal != null and gob.goal.kind == "civilian", "...and go for the next family once it sets out")
	gob.free()
	main.enemies_changed()
	var on_road: Array = r.objectives().duplicate()
	for v in on_road:
		v.arrived = true
	r.next_in = 0.0
	await _frames(3)
	check(on_road.all(func(v): return not r.people.has(v)) and r.people.size() == size, "Endless: the families keep coming, and the ones done with leave the field")
	r.lost = r.can_lose()
	r.objectives()[-1].take_damage(1e9)
	await _frames(5)
	check(main.game_over and not main.victory and r.lost > r.can_lose(), "...losing more than %d: it's over" % r.can_lose())
	await _fresh_battle("battle:village_road:normal")
	_finite({"evac": {"routes": main.mission["evac"]["routes"], "groups": 8, "size": 5, "every": 11.0, "first": 2.0, "hp": 40, "speed": 30.0, "need": 28}})
	await _go()
	r = main.rules
	r.next_in = 0.0
	await _frames(3)
	r.lost = r.total() - r.need()
	r.objectives()[-1].take_damage(1e9)
	await _frames(5)
	check(main.game_over and not main.victory and "Only" in r.summary(false), "...(as a campaign mission: losing so many that not enough can be saved: lost)")


func _capture() -> void:
	await _fresh_battle("battle:old_fort:normal")
	main._lock_portrait(true)
	await _frames(2)
	var r = main.rules
	var zone = r.zone
	check(r.get_script().resource_path.ends_with("rules_capture.gd") and zone.kind == "zone" and not zone.is_solid(), "Capture and Hold: a stretch of ground to take")
	await _go()
	main.spawn_queue.clear()
	for e in main.get_enemies():
		e.free()
	main.enemies_changed()
	main.gold = 9999
	main.placing_type = "swordsman"
	main.hire_at(zone.position + Vector2(0, 30))
	main.placing_type = ""
	var w = main.get_warriors()[-1]
	w.position = w.post
	w.max_hp = 1e6
	w.hp = 1e6
	await _frames(60)
	check(zone.progress > 0.0 and r.mine == 1, "...a troop in it takes control (%d%%)" % roundi(zone.progress * 100.0))
	var p0: float = zone.progress
	main._spawn_enemy("orc", 1, zone.position + Vector2(-30, -20))
	var orc = main.enemy_layer.get_children()[-1]
	orc.position = zone.position + Vector2(-30, -20)
	orc.max_hp = 1e6
	orc.hp = 1e6
	orc.speed = 0.0
	await _frames(30)
	check(zone.contested and absf(zone.progress - p0) < 0.02, "...with an enemy in it too, it's contested: control stands still")
	orc.free()
	main.enemies_changed()
	zone.progress = 0.995
	await _frames(10)
	check(r.phase == "hold", "Full control: now hold it")
	var gold0: int = main.gold
	r.hold_left = 0.2
	await _frames(30)
	check(not main.game_over and r.held == 1 and main.gold > gold0, "Endless: each spell it's held pays out, and it goes on")
	w.free()
	main.warriors_changed()
	zone.progress = 0.0
	await _frames(5)
	check(r.phase == "take" and r.take_left > 40.0 and "Retake" in r.status(), "...they take it back: retake it in time (%s)" % r.status())
	r.take_left = 0.05
	await _frames(5)
	check(main.game_over and not main.victory, "...or it's lost")
	await _fresh_battle("battle:old_fort:normal")
	_finite()
	await _go()
	main.rules.phase = "hold"
	main.rules.zone.progress = 1.0
	main.rules.hold_left = 0.2
	main.gold = 9999
	main.placing_type = "swordsman"
	main.hire_at(main.rules.zone.position + Vector2(0, 30))
	main.placing_type = ""
	main.get_warriors()[-1].position = main.get_warriors()[-1].post
	await _frames(30)
	check(main.game_over and main.victory, "...(as a campaign mission: held for the time wins)")
	await _fresh_battle("battle:old_fort:normal")
	_finite()
	await _go()
	main.rules.elapsed = main.rules.limit() - 0.05
	await _frames(10)
	check(main.game_over and not main.victory, "...(and out of time before it's held loses)")


func _escort() -> void:
	await _fresh_battle("battle:supply_wagon:normal")
	main._lock_portrait(true)
	await _frames(2)
	var r = main.rules
	var wagon = r.wagon
	check(r.get_script().resource_path.ends_with("rules_escort.gd") and wagon.kind == "wagon" and main.camp == null, "Convoy Escort: a wagon on the road, the camp with it")
	var at0: Vector2 = wagon.position
	await _frames(30)
	check(wagon.position == at0, "...it waits for the deployment")
	main.gold = 9999
	main.placing_type = "swordsman"
	main.hire_at(Vector2(300, 600))
	main.placing_type = ""
	var w = main.get_warriors()[-1]
	check(w.position.distance_to(wagon.position) < 60.0, "...a new troop joins at the wagon")
	w.position = w.post
	w.max_hp = 1e6
	w.hp = 1e6
	main.selected = w
	main.toggle_follow()
	main.selected = null
	check(w.anchor == wagon, "...and can be told to follow it (J)")
	main.selected = w
	main.hud.refresh(main)
	main.hud.toggle_orders(main)
	var fb: Array = main.hud.orders_ui.get("follow", [])
	check(fb.size() == 2 and fb[1].button_pressed and fb[1].text == "Wagon", "...the orders panel shows it following the wagon")
	fb[0].emit_signal("pressed")
	check(w.anchor == null, "...and its Its post button stops it following")
	fb[1].emit_signal("pressed")
	main.hud.toggle_orders(main)
	main.selected = null
	await _go()
	main.spawn_queue.clear()
	for e in main.get_enemies():
		e.free()
	main.enemies_changed()
	var post0: Vector2 = w.post
	await _frames(60 * 4)
	check(wagon.position.distance_to(at0) > 30.0 and w.post.distance_to(post0) > 30.0 and w.position.distance_to(wagon.position) < 120.0,
			"...it sets off along the road, and the troop following it keeps up")
	main._spawn_enemy("orc", 1, wagon.position + Vector2(0, -40))
	var orc = main.enemy_layer.get_children()[-1]
	orc.position = wagon.position + Vector2(40, 0)
	orc.max_hp = 1e6
	orc.hp = 1e6
	orc.speed = 0.0
	w.free()
	main.warriors_changed()
	await _frames(30)
	var held: Vector2 = wagon.position
	await _frames(30)
	var crawl: float = wagon.position.distance_to(held)
	check(wagon.halted and crawl > 0.0 and crawl < wagon.speed * 0.5 and wagon.hp < wagon.max_hp and orc.goal == wagon,
			"An enemy at the wagon slows it to a crawl (%.1fpx in 0.5s) and hurts it" % crawl)
	orc.free()
	main.enemies_changed()
	var before: int = main.get_enemies().size()
	r.sprung = 0
	wagon.position = wagon.route[-2]
	wagon.leg = wagon.route.size() - 1
	await _frames(5)
	check(r.sprung >= 2 and main.get_enemies().size() > before, "Ambushes break out as the wagon passes their places on the road")
	check(r.zones().size() == 7 and main.map_id == "convoy_meadow" and r.zone_i == 0, "The road runs through seven zones, starting on %s" % main.map_id)
	# Out of the top of the first zone: on into the next.
	main.gold = 9999
	main.placing_type = "swordsman"
	main.hire_at(Vector2(main.FIELD_W / 2.0, 400))
	main.placing_type = ""
	var t1 = main.get_warriors()[-1]
	t1.position = t1.post
	main.placing_type = "tower"
	main.hire_at(Vector2(main.FIELD_W / 2.0 - 80.0, 300))
	main.placing_type = ""
	var tower = main.get_warriors()[-1]
	var gold0: int = main.gold
	var left_by: int = main.get_enemies().size()
	for e in main.get_enemies():
		e.position = Vector2(e.position.x, 150.0)   # (away from the wagon: it isn't held up)
		e.speed = 0.0
	# Targeting set for this stretch: Strongest, on an enemy that stays behind; a Healer
	# staying with the Swordsman; new Swordsmen set to start on Strongest.
	t1.priority = "strongest"
	t1.target = main.get_enemies()[0] if not main.get_enemies().is_empty() else null
	main.placing_type = "healer"
	main.hire_at(Vector2(main.FIELD_W / 2.0 + 60.0, 420))
	main.placing_type = ""
	var medic = main.get_warriors()[-1]
	medic.stay_with([t1])
	main.last_priority["swordsman"] = "strongest"
	var off: Vector2 = t1.position - wagon.position
	main.set_follow(wagon, [t1])   # (following it out of the meadow)
	wagon.position = wagon.route[-1]
	wagon.leg = wagon.route.size()
	t1.position = wagon.position + off
	await create_timer(1.2).timeout
	check(t1.anchor == wagon, "...a troop following the wagon still follows it on the next stretch (it used to stop when the wagon reached the top)")
	check(r.zone_i == 1 and main.map_id == "convoy_forest" and main.paths.has_terrain() and not main.game_over,
			"...out the top of the meadow, the field turns into the next zone (%s)" % main.map_id)
	check(main.get_enemies().is_empty() and left_by > 0, "...the enemies are left behind (%d)" % left_by)
	check(wagon.position.y > 600.0 and not wagon.arrived and r.settle > 0.0 and wagon.speed == 0.0, "...the wagon starts again at the bottom, and waits a moment")
	check(t1.position.distance_to(wagon.position) < 140.0 and not main.paths.blocked(t1.position, 10.0), "...your troops come along, round the wagon")
	check(is_instance_valid(tower) and tower.position.y > 400.0 and not main.paths.blocked(tower.position, 10.0), "...and so do emplacements")
	check(t1.priority == Warrior.OBJECTIVE_PRIORITY and t1.target == null and tower.priority == Warrior.OBJECTIVE_PRIORITY,
			"...everyone's targeting is reset in the new zone: back on the wagon's attackers, nothing in their sights (%s)" % t1.priority)
	check(medic.priority == "revive" and medic.wards.is_empty() and main.last_priority.is_empty(), "...a Healer back on Revive, and new hires start on the default too")
	r.settle = 0.05
	await _frames(10)
	check(wagon.speed > 0.0, "...then it rolls on")
	wagon.position = wagon.route[-1]
	wagon.leg = wagon.route.size()
	await create_timer(1.2).timeout
	check(r.zone_i == 2 and main.map_id == "convoy_ford" and "Old Ford" in r.status() and "stretch 3" in r.status(), "...and on into the next (%s)" % r.status())
	r.zone_i = 6
	for e in main.get_enemies():
		e.free()
	main.enemies_changed()
	r.settle = 0.05
	await _frames(5)
	wagon.position = wagon.route[-1]
	wagon.leg = wagon.route.size()
	await create_timer(1.2).timeout
	check(r.zone_i == 7 and r.loop() == 1 and main.map_id == "convoy_meadow" and not main.game_over,
			"Endless: out of the last zone, the road goes round again (stretch %d, %s)" % [r.zone_i + 1, main.map_id])
	var seen_maps := {}
	for z in r.zones():
		seen_maps[z["map"]] = true
		check(main.Maps.get_map(z["map"]).has("route"), "...%s has a road for the wagon" % z["map"])
	check(seen_maps.size() == 7, "...seven different stretches of road")
	_finite({"convoy": {"name": "Wagon", "speed": 20.0, "hp": 1500, "zones": main.mission["convoy"]["zones"].slice(0, 3)}})
	r.zone_i = 2
	for e in main.get_enemies():
		e.free()
	main.enemies_changed()
	r.settle = 0.05
	await _frames(5)
	wagon.position = wagon.route[-1]
	wagon.leg = wagon.route.size()
	await _frames(10)
	check(main.game_over and main.victory, "...(as a campaign mission: out of the last zone wins)")
	await _fresh_battle("battle:supply_wagon:normal")
	await _go()
	main.rules.wagon.take_damage(1e9)
	await _frames(5)
	check(main.game_over and not main.victory, "...destroyed on the way: lost")


## Objective targeting: troops can be set to go for whatever's after the objectives first
## (new ones start on it in these battles), and enemies make for the objectives rather
## than the bottom of the field.
func _targeting() -> void:
	await _fresh_battle("battle:signal_beacon:normal")
	main._lock_portrait(true)
	await _frames(2)
	var beacon = main.rules.objectives()[0]
	check(Warrior.priorities_for(main).has("objective"), "Battles with something to protect offer the Objective target priority")
	await _go()
	main.spawn_queue.clear()
	for e in main.get_enemies():
		e.free()
	main.enemies_changed()
	main.gold = 9999
	main.placing_type = "archer"
	main.hire_at(beacon.position + Vector2(-150, 60))
	main.placing_type = ""
	var a = main.get_warriors()[-1]
	a.position = a.post
	a.move_mode = "hold"
	check(a.priority == "objective", "...and new troops start on it")
	# One enemy right by the archer but after nothing; one further off, at the beacon.
	main._spawn_enemy("orc", 1, a.position + Vector2(40, -30))
	var idle = main.enemy_layer.get_children()[-1]
	idle.position = a.position + Vector2(50, -40)
	idle.goal = null
	idle.goal_check = 999.0
	idle.speed = 0.0
	main._spawn_enemy("orc", 1, beacon.position + Vector2(0, -40))
	var raider = main.enemy_layer.get_children()[-1]
	raider.position = beacon.position + Vector2(-30, -beacon.RADIUS - raider.radius)
	raider.speed = 0.0
	for e in [idle, raider]:
		e.max_hp = 1e6
		e.hp = 1e6
	a.attack_range = 400.0
	a.target = null
	a.retarget_timer = 0.0
	await _frames(20)
	check(raider.goal == beacon and a.target == raider, "...an archer on it shoots the one at the beacon, not the nearer one")
	main.give_order("priority", "closest", [a])
	await _frames(20)
	check(a.target == idle, "...on Closest it shoots the nearest, as ever")
	for e in main.get_enemies():
		e.free()
	main.enemies_changed()
	# Capture and Hold: everything makes for the fort.
	await _fresh_battle("battle:old_fort:normal")
	await _go()
	await _frames(60 * 3)
	var all_fort: bool = not main.get_enemies().is_empty()
	for e in main.get_enemies():
		all_fort = all_fort and e.goal == main.rules.zone
	check(all_fort, "Capture and Hold: every enemy makes for the fort (%d)" % main.get_enemies().size())
	# The meadow's Classic game has no objectives: the four priorities as ever.
	await _fresh_battle("normal")
	check(Warrior.priorities_for(main) == Warrior.PRIORITIES and not main.rules.guards() and not main.rules.objective_only(),
			"Classic: no Objective priority, enemies go for the castle as ever")


func _retreat() -> void:
	await _fresh_battle("battle:long_retreat:normal")
	main._lock_portrait(true)
	await _frames(2)
	var r = main.rules
	check(r.get_script().resource_path.ends_with("rules_retreat.gd") and r.objectives().size() == 3 and main.camp != null, "Fighting Retreat: three lines, and the camp to get out to")
	main.gold = 9999
	for x in [200, 320, 440]:
		main.placing_type = "swordsman"
		main.hire_at(Vector2(x, 280))
		main.placing_type = ""
	var troops: Array = main.get_warriors()
	for t in troops:
		t.position = t.post
		t.max_hp = 1e6
		t.hp = 1e6
	await _go()
	check(r.action_label() == "", "...no order to fall back while the first line holds")
	r.left = 0.01
	await _frames(3)
	main.hud.refresh(main)
	check(r.phase == 1 and r.action_label() != "" and main.hud.action_btn.visible, "When its time is up: the Fall back order (%s)" % r.action_label())
	main._unhandled_input(_key_ev(KEY_Y))
	await _frames(3)
	check(troops.all(func(t): return absf(t.post.y - 460.0) < 20.0 and t.ordered), "...Y: every troop makes for the second line")
	r.phase = 3
	r.left = 0.01
	r.called = true
	for t in troops:
		t.position = Vector2(t.post.x, 700)
	for e in main.get_enemies():
		e.free()
	main.enemies_changed()
	r.through = 0
	await _frames(5)
	check(main.game_over and not main.victory and r.extracted == 3, "Only 3 of the 6 needed get out: lost")
	# It eases in: no stragglers for the first waves, then a few, then more and more.
	await _fresh_battle("battle:long_retreat:normal")
	r = main.rules
	var gaps := []
	for n in [1, 3, 4, 6, 12]:
		main.wave = n
		gaps.append(r.stream_gap())
	check(gaps[0] == INF and gaps[1] == INF and gaps[2] > 5.0 and gaps[3] < gaps[2] and gaps[4] == float(main.mission["stream"]),
			"Stragglers join in from wave 4, few at first, then thicker (%s)" % str(gaps))
	main.wave = 0
	check(main._mission_wave(1).size() < 10, "...and the first waves are small (%d)" % main._mission_wave(1).size())
	# Endless: enough out of the camp, and on to the next stretch.
	main.gold = 9999
	var out := []
	for x in [160, 220, 280, 340, 400, 460, 520]:
		main.placing_type = "swordsman"
		main.hire_at(Vector2(x, 690))
		main.placing_type = ""
		out.append(main.get_warriors()[-1])
	main.placing_type = "swordsman"
	main.hire_at(Vector2(320, 300))
	main.placing_type = ""
	var behind = main.get_warriors()[-1]
	main.placing_type = "tower"
	main.hire_at(Vector2(200, 500))
	main.placing_type = ""
	for t in main.get_warriors():
		t.position = t.post
	await _go()
	out[0].priority = "strongest"
	out[0].chase_time = 2.0
	r.phase = 3
	r.left = 0.01
	r.called = true
	var gold1: int = main.gold
	await create_timer(1.5).timeout
	check(r.stretch == 1 and main.map_id == "convoy_forest" and r.phase == 0 and r.settle > 0.0 and not main.game_over,
			"Endless: 7 got out, so on to the next stretch (%s)" % r.status())
	check(out.all(func(t): return is_instance_valid(t) and absf(t.post.y - 280.0) < 30.0) and not is_instance_valid(behind),
			"...the ones that got out hold its first line; the one left behind is lost")
	check(main.get_warriors().size() == out.size() and main.gold > gold1 and main.get_enemies().is_empty(), "...emplacements abandoned (half back), and the enemy left behind for now")
	check(out[0].priority == "strongest" and out[0].chase_time == 0.0 and out[0].target == null,
			"...nothing left in their sights from the old ground, but their target orders stand")
	r.settle = 0.05
	await _frames(5)
	check(r.left > 0.0 and r.action_label() == "", "...then it all starts again")
	r.through = 8
	r.phase = 3
	r.left = 0.01
	r.called = true
	for t in out:
		t.position = Vector2(t.position.x, 700)
	await create_timer(1.5).timeout
	check(r.stretch == 2 and r.through == 3, "...each new stretch forgives a few of those that got past (8 to %d)" % r.through)
	await _fresh_battle("battle:long_retreat:normal")
	await _go()
	main.rules.through = main.rules.limit()
	main._spawn_enemy("goblin", 1, Vector2(320, main.CASTLE_Y - 5))
	await _frames(20)
	check(main.game_over and not main.victory and "overrun" in main.rules.summary(false), "Too many get past into the camp: overrun")


func _key_ev(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev


## Classic is still castle defense with its castle.
func _classic_unchanged() -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud.hide_mode_select()
	main.choose_mode("normal")
	await _frames(3)
	check(main.rules.get_script().resource_path.ends_with("/rules.gd") and main.rules.has_castle() and main.castle.visible and main.camp == null,
			"Classic: castle defense, with its castle")


# --- The Armoury Wagon: Ashwatch's second mission, a convoy that opens Swordsman Tier IV ---

func _armoury() -> void:
	campaign.new_campaign("normal")
	campaign.completed = ["ashwatch", "stonehollow"]
	campaign.allies = ["stonehollow"]
	check(campaign.playable_mission("ashwatch") == "ashwatch_road" and campaign.tier4_kinds("ashwatch") == ["swordsman"],
			"Ashwatch's second mission is open once Stonehollow joins, and its beacon opens Swordsman Tier IV")
	await _play("ashwatch_road")
	var r = main.rules
	var wagon = r.wagon
	check(r.get_script().resource_path.ends_with("rules_escort.gd") and not r.endless() and r.zones().size() == 3,
			"The Armoury Wagon is a convoy escort, three stretches long, with an end")
	check(wagon.label == "Armoury Wagon" and wagon.cargo == "arms" and not main.castle.visible, "...the wagon's loaded with arms, and there's no castle")
	check(main.get_warriors().filter(func(w): return w.kind == "swordsman").size() == 2, "...two of Hale's swordsmen walk with it")
	check(main.forced_auto, "...the attacks come at a forced pace")
	# Through the last stretch: home, and Ashwatch's beacon is lit.
	r.zone_i = r.zones().size() - 1
	r._on_reached(wagon)
	await _frames(10)
	check(main.game_over and main.victory and campaign.beacon_lit("ashwatch") and campaign.tier4_open("swordsman"),
			"Bringing the wagon home wins, lights Ashwatch's beacon and opens Swordsman Tier IV")
