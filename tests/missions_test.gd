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
	await _forced_pace()
	await _protect()
	await _evac()
	await _capture()
	await _escort()
	await _retreat()
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
	check(names == ["Castle Defense", "Multiple Positions", "Hold the Pass", "Protect the Objective", "Evacuation", "Capture and Hold",
			"Convoy Escort", "Fighting Retreat", "Back"], "Battle Modes: all eight kinds of battle (%s)" % ", ".join(names))
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
	check(not main.wave_active and main.auto_timer <= 5.0 and main.auto_timer > 0.0, "...with only a short break before the next (%.1fs)" % main.auto_timer)
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
	beacon.progress = 0.999
	await _frames(30)
	check(main.game_over and main.victory, "Fully charged: the battle is won")
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
	await _frames(30)
	check(r.objectives().is_empty(), "...nobody sets out during the deployment")
	await _go()
	main.spawn_queue.clear()
	for e in main.get_enemies():
		e.free()
	main.enemies_changed()
	r.next_in = 0.0
	await _frames(5)
	var g = r.objectives()[0]
	check(r.sent == 1 and g.kind == "civilians" and g.is_mover(), "...then the villagers set out, a group at a time")
	var start: Vector2 = g.position
	await _frames(60)
	check(g.position.distance_to(start) > 20.0, "...walking their road")
	main._spawn_enemy("goblin", 1, Vector2(g.position.x, 120))
	var gob = main.enemy_layer.get_children()[-1]
	check(gob.goal == g, "...enemies go after them")
	gob.free()
	main.enemies_changed()
	g.speed = 2000.0
	await _frames(30)
	check(g.arrived and r.saved == 5, "A group that gets to the camp is saved (%d)" % r.saved)
	r.next_in = 0.0
	await _frames(3)
	var g2 = r.objectives()[1]
	g2.take_damage(1e9)
	await _frames(3)
	check(r.lost == 5 and not main.game_over, "A group caught is lost (5), and the evacuation goes on")
	r.lost = r.total() - r.need()
	r.next_in = 0.0
	await _frames(3)
	r.objectives()[2].take_damage(1e9)
	await _frames(5)
	check(main.game_over and not main.victory and "Only" in r.summary(false), "Losing so many that not enough can be saved: lost")


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
	r.hold_left = 0.2
	await _frames(30)
	check(main.game_over and main.victory, "...held for the time: won")
	await _fresh_battle("battle:old_fort:normal")
	await _go()
	main.rules.elapsed = main.rules.limit() - 0.05
	await _frames(10)
	check(main.game_over and not main.victory, "Out of time before it's held: lost")


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
	check(wagon.halted and wagon.position == held and wagon.hp < wagon.max_hp and orc.goal == wagon, "An enemy at the wagon holds it up and hurts it")
	orc.free()
	main.enemies_changed()
	var before: int = main.get_enemies().size()
	r.sprung = 0
	wagon.position = wagon.route[-2]
	wagon.leg = wagon.route.size() - 1
	await _frames(5)
	check(r.sprung >= 2 and main.get_enemies().size() > before, "Ambushes break out as the wagon passes their places on the road")
	for e in main.get_enemies():
		e.free()
	main.enemies_changed()
	wagon.position = wagon.route[-1]
	wagon.leg = wagon.route.size()
	await _frames(10)
	check(main.game_over and main.victory, "The wagon reaches the end of the road: won")
	await _fresh_battle("battle:supply_wagon:normal")
	await _go()
	main.rules.wagon.take_damage(1e9)
	await _frames(5)
	check(main.game_over and not main.victory, "...destroyed on the way: lost")


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
	check(main.game_over and not main.victory and r.extracted == 3, "Only 3 of the 8 needed get out: lost")
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
