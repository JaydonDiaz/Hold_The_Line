extends SceneTree
## Battle rules other than castle defense (scripts/mission/): Hold the Pass and Multiple
## Positions, as campaign missions and as Battle Modes scenarios. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/missions_test.gd
## Uses a temporary campaign save. Exits 1 if anything failed.

const TEST_SAVE := "user://missions_test.cfg"

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

func _pass() -> void:
	campaign.new_campaign("normal")
	campaign.completed = ["ashwatch", "stonehollow"]
	campaign.allies = ["stonehollow"]
	await _play("ashwatch_road")
	var r = main.rules
	check(r.get_script().resource_path.ends_with("rules_pass.gd") and not r.has_castle(), "Pass: the Ridge Road plays by Hold the Pass rules")
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


# --- Multiple Positions -------------------------------------------------------------------

func _positions() -> void:
	campaign.new_campaign("normal")
	campaign.completed = ["ashwatch", "stonehollow"]
	campaign.allies = ["stonehollow"]
	await _play("stonehollow_workshops")
	var r = main.rules
	var objs: Array = r.objectives()
	check(r.get_script().resource_path.ends_with("rules_positions.gd") and objs.size() == 3 and r.has_castle() and main.castle.visible,
			"Positions: Protect the Workshops has three workshops, and the guildhall")
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
	check(sent.get("castle", 0) < 20 and sent.size() >= 3, "...enemies split between the workshops and the guildhall (%s)" % str(sent))
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
	check(names == ["Multiple Positions", "Hold the Pass", "Back"], "Battle Modes: the kinds of battle (%s)" % ", ".join(names))
	hud._show_cards("bm:positions")
	names = hud.mode_cards.map(func(c): return (c.get_child(0) as Label).text)
	check(names[0] == "The Three Watchtowers", "...each with a battle to play without a campaign (%s)" % names[0])
	hud._show_cards("bmd:three_towers")
	names = hud.mode_cards.map(func(c): return (c.get_child(0) as Label).text)
	check(names == ["Easy", "Normal", "Hard", "Back"], "...on any difficulty")
	main.records_path = "user://missions_test_records.cfg"
	main._on_mode_chosen("battle:three_towers:hard")
	await _frames(3)
	main._lock_portrait(true)
	await _frames(2)
	check(not main.campaign and main.battle_id == "three_towers" and main.difficulty == "hard" and main.rules.objectives().size() == 3,
			"The Three Watchtowers on Hard: three watchtowers to hold")
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
	main.wave = main.last_wave() - 1
	main.start_wave()
	await _frames(2)
	main.spawn_queue.clear()
	for e in main.get_enemies():
		e.free()
	main.enemies_changed()
	await _frames(10)
	var cfg := ConfigFile.new()
	cfg.load(main.records_path)
	check(main.game_over and main.victory and cfg.get_value("battle", "three_towers@hard", -1) == 3, "Won with all three towers: the best is kept (3 of 3, Hard)")
	main.play_again("battle:three_towers:hard")
	check(campaign.screen == "battle:three_towers:hard", "...and Play again starts the same battle")
	campaign.screen = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://missions_test_records.cfg"))
	# The Open Road: Hold the Pass on the meadow, no castle.
	await _fresh_battle("battle:open_road:normal")
	check(main.rules.get_script().resource_path.ends_with("rules_pass.gd") and not main.castle.visible and main.rules.limit() == 20,
			"The Open Road: Hold the Pass on the meadow, no castle, 20 may get through")


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
