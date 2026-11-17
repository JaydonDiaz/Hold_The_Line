extends SceneTree
## Phase 5, F2: the Liberation of Dawnspire, the assault outside the walls. Run from the
## project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/dawnspire_test.gd
##   O  opening     Dawnspire opens once the Spires' beacon is lit; its mission is the assault,
##                   with help from every people that's joined
##   G  gates       the ram goes up the road and batters a timber gate while no enemy is at
##                   it (not while one is); a shut gate is solid; an open one isn't; the iron
##                   portcullis can't be battered, its winch house taken raises it
##   T  towers      an enemy tower shoots troops in reach; troops round it with no enemy there
##                   take it; an Archer ordered onto it mans it (an Archer Tower as trained as
##                   it is); moving on, the crew stays behind holding it, kept for the retreat
##   D  side duty  the "Side Objectives" target priority, offered in the assault (not in
##                   other battles): troops on it go and take the field's towers and the like,
##                   an Archer on it mans a tower taken; with nothing left, back to the ram;
##                   they keep at it in the next field
##   P  prisoners   a pen freed: its soldiers join on loan (each trained on one path only, at
##                   most tier III), its townsfolk walk out
##   S  supplies    a troop that gets to a cache claims its gold (not with an enemy on it)
##   V  volleys     an Arrow Storm or Fireball gives a ring of warning first, then hits only
##                   those still inside it
##   C  clearing    the gate open: no more waves; the army doesn't move on while an enemy is
##                   left or a troop is down; then it goes through into the next field
##   K  checkpoints each field after the first is a checkpoint: a loss there banks only the XP
##                   since it, and a retry picks up from it (field, gold, army, ram)
##   W  win         the Dawn Gate broken and its field cleared: won, the checkpoint gone
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.

const TEST_SAVE := "user://dawnspire_test_campaign.cfg"
const CD = preload("res://scripts/campaign_data.gd")

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


## The campaign with the Spires won: the south, Sable, two northern peoples and the Conclave.
func _at_dawnspire() -> void:
	campaign.new_campaign("normal")
	campaign.completed = ["ashwatch", "ashwatch_road", "stonehollow", "stonehollow_workshops", "gw_exodus", "gw_watchfires",
		"mv_wounded", "mv_sanctuary", "sable_crossing", "fm_pass", "fm_vigil", "mo_steps", "mo_gate", "sp_circle", "sp_relight"]
	campaign.allies = ["stonehollow", "greenwood", "mercyvale", "frostmarch", "monastery", "spires"]


## Into the assault, with the fighting held off (no waves, the garrison gone) so each
## check sets up only what it needs.
func _assault(resume := 0) -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud.hide_mode_select()
	campaign.op_resume_zone = resume
	main.start_mission("ds_assault")
	await process_frame
	if main.hud.story != null:
		main.hud.story.skip()
	main._lock_portrait(true)
	await _frames(3)
	_quiet()


func _quiet() -> void:
	main.deploying = false
	main.forced_auto = false
	main.auto_play = false
	main.auto_timer = 9999.0
	main.clear_enemies()


func _run() -> void:
	await _opening()
	await _gates()
	await _towers()
	await _side_orders()
	await _prisoners_and_supplies()
	await _volleys()
	await _clearing()
	await _checkpoints()
	await _win()
	if main != null:
		main.free()
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _unit(kind: String, at: Vector2):
	main.gold = 99999
	var had: Array = main.get_warriors()
	main.placing_type = kind
	main.hire_at(at)
	main.placing_type = ""
	var fresh: Array = main.get_warriors().filter(func(x): return not had.has(x))
	if fresh.is_empty():
		return null
	fresh[0].position = fresh[0].post
	return fresh[0]


func _foe(kind: String, at: Vector2):
	main._spawn_enemy(kind, 8, at)
	return main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)


## The ram brought right up to the gate.
func _ram_to_gate() -> void:
	var r = main.rules.wagon
	r.position = r.route[r.route.size() - 1] + Vector2(0, 30)
	r.leg = r.route.size() - 1
	r.speed = 40.0
	main.rules.settle = 0.0
	await _frames(60)


## Once the field's clear: the order to go on, and the field changing (into `map`).
func _go_on(map: String) -> void:
	var rules = main.rules
	for i in 60 * 6:
		if rules.phase == "ready":
			break
		await process_frame
	rules.action()
	for i in 60 * 6:
		if main.map_id == map and not rules.moving_on:
			break
		await process_frame


# --- O ---------------------------------------------------------------------------------------

func _opening() -> void:
	_at_dawnspire()
	check(campaign.territories["dawnspire"]["missions"] == ["ds_assault"] and campaign.requirements_met("dawnspire")
			and campaign.playable_mission("dawnspire") == "ds_assault", "O  the Spires won: Dawnspire opens, and its mission is the assault")
	campaign.completed.erase("sp_relight")
	check(not campaign.requirements_met("dawnspire"), "O  ...not before the Spires' beacon is lit")
	_at_dawnspire()
	await _assault()
	check(main.rules.get_script().resource_path.ends_with("rules_assault.gd") and main.map_id == "ds_approach",
			"O  the assault: on the Approach")
	var lent: Array = main.temp_allies.map(func(w): return w.kind)
	check(lent.count("mage") == 1 and lent.has("archer") and lent.has("frost") and lent.has("martial"),
			"O  help from every people that's joined (%s)" % ", ".join(lent))
	check(main.rules.wagon.cargo == "ram" and main.rules.gate.is_solid() and main.rules.towers.size() == 2 and main.rules.caches.size() == 2,
			"O  the ram, a shut gate, two archer towers and two caches of supplies")
	check(main.wave_level(1) == 8 and main.wave_level(11) == 12, "O  the enemy grows slowly over the long fight (level %d at wave 11)" % main.wave_level(11))


# --- G ---------------------------------------------------------------------------------------

func _gates() -> void:
	_at_dawnspire()
	await _assault()
	var rules = main.rules
	var gate = rules.gate
	check(main.paths.solid_objs.has(gate) and main.ground_problem(gate.position + Vector2(0, -10)) != "", "G  a shut gate blocks the way through the wall")
	await _ram_to_gate()
	check(rules.wagon.arrived, "G  the ram reaches the gate")
	var hp0: float = gate.hp
	await _frames(120)
	check(gate.hp < hp0 - 30.0, "G  ...and batters it (%d -> %d)" % [hp0, gate.hp])
	var orc = _foe("orc", rules.wagon.position + Vector2(30, 10))
	orc.goal = rules.wagon
	await _frames(20)
	var hp1: float = gate.hp
	await _frames(90)
	check(rules.wagon.halted and gate.hp >= hp1 - 1.0, "G  not while an enemy's at the ram")
	main.clear_enemies()
	await _frames(5)
	gate.batter(99999.0)
	await _frames(5)
	check(gate.taken and not gate.is_solid() and main.ground_problem(gate.position + Vector2(0, -10)) == "", "G  broken, the gate's open: the way's clear")
	# On into the Bailey, and its portcullis.
	await _go_on("ds_bailey")
	_quiet()
	gate = rules.gate
	await _ram_to_gate()
	await _frames(120)
	check(gate.style == "portcullis" and gate.hp == gate.max_hp and not gate.taken, "G  the portcullis: the ram can't break iron")
	var k := 0
	for p in [Vector2(-20, 30), Vector2(20, 30), Vector2(0, 40)]:
		_unit("swordsman", rules.winch.position + p)
		k += 1
	var winch = rules.winch
	for i in 60 * 28:
		if gate.taken:
			break
		await process_frame
	check(winch.taken and gate.taken, "G  ...the winch house taken, it goes up")


# --- T ---------------------------------------------------------------------------------------

func _towers() -> void:
	_at_dawnspire()
	await _assault()
	var rules = main.rules
	var tower = rules.towers[0]
	var sw = _unit("swordsman", tower.position + Vector2(40, 130))
	var hp0: float = sw.hp
	var low: float = hp0
	for i in 60 * 4:
		await process_frame
		low = minf(low, sw.hp)
	check(low < hp0, "T  an enemy tower shoots a troop in reach")
	sw.order_to(tower.position + Vector2(0, 40))
	var sw2 = _unit("swordsman", tower.position + Vector2(30, 40))
	await _frames(60 * 10)
	check(tower.taken and not tower.is_solid(), "T  troops round it with no enemy there take it")
	var shots := 0
	for n in main.fx_layer.get_children():
		if n.get_script() == preload("res://scripts/enemy_shot.gd"):
			shots += 1
	await _frames(60 * 3)
	var hp1: float = sw.hp
	var low1: float = hp1
	for i in 60 * 3:
		await process_frame
		low1 = minf(low1, sw.hp)
	check(low1 >= hp1, "T  ...and it shoots no more")
	var archer = _unit("archer", tower.position + Vector2(-60, 60))
	archer.tiers = [2, 0, 0, 2]
	archer._apply_upgrades()
	var base_range: float = archer.attack_range
	archer.order_to(tower.position)
	await _frames(60 * 3)
	var plain: Array = main.get_warriors().filter(func(w): return w.kind == "tower" and w.has_meta("captured"))
	check(plain.size() == 1 and plain[0].spent == 0 and plain[0].position.distance_to(tower.position) < 4.0 and tower.crewed,
			"T  the tower taken: your plain Tower stands where it stood (free)")
	check(plain.size() == 1 and archer.garrison == plain[0] and plain[0].crew_in == archer and is_instance_valid(archer),
			"T  an Archer ordered onto it climbs up into it")
	check(archer.tiers == [2, 0, 0, 2] and is_equal_approx(archer.attack_range, base_range * 1.3) and archer.xp_kind() == "archer",
			"T  ...keeping its own upgrades (2-0-0-2), reaching 30%% further, and learning as an Archer (%.0f -> %.0f)" % [base_range, archer.attack_range])
	# Moving on: the crew comes down.
	main.rules.gate.batter(99999.0)
	await _frames(5)
	rules.enter_next()
	await _frames(5)
	var archers: Array = main.get_warriors().filter(func(w): return w.kind == "archer" and not main.temp_allies.has(w))
	var held: Array = rules.garrisons
	check(main.get_warriors().filter(func(w): return w.kind == "tower").is_empty() and archers.is_empty() and held.size() == 1
			and held[0]["zone"] == 0 and held[0]["tower"] == "tower" and held[0]["crew"]["kind"] == "archer" and held[0]["crew"]["tiers"] == [2, 0, 0, 2],
			"T  moving on, the crew stays behind holding its tower, kept (as trained as it is) for the retreat (%s)" % str(held))
	rules.checkpoint()
	check((campaign.checkpoint("ds_assault", 1).get("garrisons", []) as Array).size() == 1, "T  ...and kept with the checkpoint")


# --- D ---------------------------------------------------------------------------------------

func _side_orders() -> void:
	_at_dawnspire()
	await _assault()
	var Warrior = preload("res://scripts/warrior.gd")
	var rules = main.rules
	check(Warrior.priorities_for(main).has("side") and Warrior.PRIORITY_NAMES["side"] == "Side Objectives",
			"D  the assault offers a Side Objectives target priority, beside Objective")
	for w in main.get_warriors():
		w.queue_free()
	await process_frame
	var a = _unit("swordsman", Vector2(300, 600))
	var b = _unit("swordsman", Vector2(340, 600))
	main.give_order("priority", "side", [a, b])
	await _frames(60)
	var jobs: Array = [a.get_meta("side_job", null), b.get_meta("side_job", null)]
	check(jobs.all(func(j): return j != null) and a.post.distance_to(jobs[0].position) < 70.0,
			"D  troops on it are sent to the field's side objectives")
	check(jobs[0] != jobs[1] or rules._side_jobs().size() == 1, "D  ...shared out, not all to the one")
	# Hold off everything but one tower, so the pair end up on it, and it's taken.
	var tower = rules.towers[0]
	for o in rules.towers.slice(1) + rules.caches:
		o.taken = true
	await _frames(60 * 14)
	check(tower.taken, "D  ...and take it")
	var archer = _unit("archer", Vector2(320, 560))
	main.give_order("priority", "side", [archer])
	await _frames(60 * 8)
	check(tower.crewed and archer.garrison != null, "D  an Archer on it climbs into a tower that's been taken")
	await _frames(60)
	check(is_instance_valid(a) and a.anchor == rules.wagon and b.anchor == rules.wagon, "D  with nothing left to take, back round the ram")
	rules.gate.batter(99999.0)
	await _go_on("ds_bailey")
	await _frames(60)
	check(main.map_id == "ds_bailey" and a.priority == "side" and a.get_meta("side_job", null) != null, "D  into the next field, still on Side Objectives, and off to its works (%s, %s, active %s, map %s, moving %s)" % [a.priority, a.get_meta("side_job", null), a.is_active(), main.map_id, rules.moving_on])
	# Elsewhere it isn't offered.
	main.rules.gate = null
	var esc = load("res://scripts/mission/rules.gd").new()
	check(not esc.side_objectives(), "D  other battles don't offer it")


# --- P, S --------------------------------------------------------------------------------------

func _prisoners_and_supplies() -> void:
	_at_dawnspire()
	await _assault()
	var rules = main.rules
	var cache = rules.caches[0]
	var gold0: int = main.gold
	var orc = _foe("orc", cache.position + Vector2(0, 6))
	orc.speed = 0.0
	var sw = _unit("swordsman", cache.position + Vector2(40, 30))
	sw.order_to(cache.position + Vector2(8, 10))
	await _frames(20)
	check(not cache.taken, "S  supplies with an enemy on them aren't claimed")
	main.clear_enemies()
	main.gold = gold0
	await _frames(60 * 2)
	check(cache.taken and main.gold >= gold0 + cache.gold, "S  a troop that gets to them claims the gold (+%d)" % cache.gold)
	# The Bailey's pen.
	rules.zone_i = 1
	rules.change_field("ds_bailey")
	rules._leave_zone()
	rules._setup_zone()
	_quiet()
	var pen = rules.pens[0]
	var before: int = main.temp_allies.size()
	for p in [Vector2(-40, 40), Vector2(40, 40)]:
		_unit("swordsman", pen.position + p)
	await _frames(60 * 8)
	var freed: Array = main.temp_allies.slice(before)
	var one_path := true
	for w in freed:
		var paths: Array = w.tiers.filter(func(t): return t > 0)
		if paths.size() != 1 or paths[0] > 3:
			one_path = false
	check(pen.taken and freed.size() == 3 and freed.all(func(w): return w.has_meta("freed") and w.spent == 0),
			"P  the pen freed: its three soldiers join, on loan")
	check(one_path and freed.any(func(w): return w.tiers == [3, 0, 0, 0]), "P  ...each trained on one path only, at most tier III")
	check(rules.townsfolk.size() == 5, "P  ...and its five townsfolk make for safety")
	await _frames(60 * 18)
	check(rules.freed == 5 and main.rules.objectives().filter(func(o): return o.kind == "civilian").is_empty(), "P  ...and get out (%d)" % rules.freed)
	check(not campaign.allies.has("deepdelve") and campaign.allies.size() == 6, "P  freed soldiers bring no people into the Line")


# --- V ---------------------------------------------------------------------------------------

func _volleys() -> void:
	_at_dawnspire()
	await _assault()
	for w in main.get_warriors():
		w.queue_free()
	await process_frame
	var rules = main.rules
	rules.zone_i = 2
	rules.change_field("ds_dawngate")
	rules._leave_zone()
	rules._setup_zone()
	_quiet()
	var a = _unit("swordsman", Vector2(320, 520))
	var b = _unit("swordsman", Vector2(350, 520))
	var far = _unit("swordsman", Vector2(520, 690))
	rules.volley_t = 0.01
	await _frames(3)
	var fall = null
	for n in main.fx_layer.get_children():
		if n.has_method("_land"):
			fall = n
	check(fall != null and fall.position.distance_to(Vector2(335, 520)) < 30.0, "V  a volley aims at the knot of troops, with a ring on the ground first")
	var hp_a: float = a.hp
	await _frames(int(60 * 2.0))
	check(a.hp == hp_a, "V  ...nothing lands during the warning")
	b.order_to(Vector2(335, 680))
	b.post = Vector2(335, 680)
	b.position = Vector2(335, 680)
	await _frames(int(60 * 2.5))
	check(a.hp < hp_a and b.hp == b.max_hp and far.hp == far.max_hp, "V  then it hits who's still inside, and nobody who got clear")


# --- C ---------------------------------------------------------------------------------------

func _clearing() -> void:
	_at_dawnspire()
	await _assault()
	var rules = main.rules
	var sw = _unit("swordsman", Vector2(320, 520))
	var orc = _foe("orc", Vector2(600, 400))
	orc.speed = 0.0
	rules.gate.batter(99999.0)
	await _frames(5)
	check(rules.phase == "clear" and rules.holds_waves(), "C  the gate open: no more waves")
	var w0: int = main.wave
	main.start_wave(true)
	check(main.wave == w0, "C  ...a wave won't start")
	await _frames(60)
	check(main.map_id == "ds_approach" and not rules.moving_on, "C  not on while an enemy's left")
	orc.take_damage(99999.0)
	sw.take_damage(99999.0)
	await _frames(30)
	check(sw.down_timer > 0.0 and main.map_id == "ds_approach" and not rules.moving_on, "C  ...nor while a troop's down")
	sw.down_timer = 0.0
	sw.hp = sw.max_hp
	await _frames(60 * 4)
	check(rules.phase == "ready" and main.map_id == "ds_approach" and not rules.moving_on and rules.action_label() == "Through the gate" and rules.holds_waves(),
			"C  the field clear: the army waits for the order to go on (no waves meanwhile)")
	rules.action()
	await _frames(60 * 3)
	check(main.map_id == "ds_bailey" and rules.zone_i == 1 and rules.wagon.position.y > 600, "C  ...given it, through the gate into the Outer Bailey, the ram at the bottom of it")


# --- K ---------------------------------------------------------------------------------------

func _checkpoints() -> void:
	_at_dawnspire()
	await _assault()
	var rules = main.rules
	var sw = _unit("swordsman", Vector2(240, 500))
	sw.tiers = [2, 1, 0, 0]
	sw._apply_upgrades()
	main.battle_xp = {"swordsman": 1000.0}
	rules.gate.batter(99999.0)
	await _frames(5)
	main.gold = 777
	rules.enter_next()
	await _frames(5)
	var cp: Dictionary = campaign.checkpoint("ds_assault", 1)
	check(cp.get("zone", -1) == 1 and cp.get("gold", 0) == 777 and cp.get("name", "") == "The Outer Bailey"
			and campaign.checkpoints_for("ds_assault") == [[1, "The Outer Bailey"]], "K  into the Bailey: a checkpoint (field, gold)")
	var army: Array = cp.get("army", [])
	check(army.any(func(r): return r["kind"] == "swordsman" and r["tiers"] == [2, 1, 0, 0]) and army.any(func(r): return r.get("lent", false)),
			"K  ...with the army as it stood, the lent troops too")
	# A loss in the Bailey banks only the XP since the checkpoint.
	main.battle_xp = {"swordsman": 1600.0}
	var gains: Dictionary = rules.xp_gains(false, main.battle_xp)
	check(is_equal_approx(float(gains.get("swordsman", 0.0)), 600.0) and is_equal_approx(float(rules.xp_gains(true, main.battle_xp)["swordsman"]), 1600.0),
			"K  a loss banks only the XP since the checkpoint; a win, all of it once")
	check(main.rules.checkpoint_name() == "The Outer Bailey", "K  the end screen can offer the Bailey to go back to")
	# Taken up again.
	campaign.save_game()
	campaign.load_game()
	await _assault(1)
	rules = main.rules
	var sws: Array = main.get_warriors().filter(func(w): return w.kind == "swordsman" and w.tiers == [2, 1, 0, 0])
	check(main.map_id == "ds_bailey" and rules.zone_i == 1 and main.gold == 777 and sws.size() == 1,
			"K  a retry picks up from the Bailey: the field, the gold, the army (from the save)")
	check(is_equal_approx(float(main.battle_xp.get("swordsman", 0.0)), 1000.0) and rules.gate.style == "portcullis" and rules.pens.size() == 1,
			"K  ...the XP it had, and the Bailey's works set out afresh")
	# On to the Dawn Gate: a second checkpoint, the Bailey's kept too.
	main.gold = 555
	rules.gate.open()
	rules.enter_next()
	await _frames(5)
	check(campaign.checkpoints_for("ds_assault") == [[1, "The Outer Bailey"], [2, "The Dawn Gate"]] and campaign.checkpoint("ds_assault", 1)["gold"] == 777,
			"K  the Dawn Gate a checkpoint too, the Bailey's still kept")
	await _assault(0)
	check(main.map_id == "ds_approach" and main.rules.zone_i == 0 and campaign.checkpoints_for("ds_assault").size() == 2,
			"K  from the beginning: the Approach (the checkpoints kept for another time)")
	await _assault(1)
	check(main.map_id == "ds_bailey" and main.gold == 777, "K  or from an earlier checkpoint than the last: the Bailey, as it stood")
	# From the map: a choice of where to begin.
	main.hud.show_world_map(campaign)
	main.start_mission("ds_assault")
	await _frames(3)
	var picks: Array = main.hud.find_children("*", "Button", true, false).filter(func(b): return b.text.begins_with("From "))
	check(picks.map(func(b): return b.text) == ["From the beginning", "From The Outer Bailey", "From The Dawn Gate"],
			"K  starting it from the map: from the beginning or any checkpoint (%s)" % ", ".join(picks.map(func(b): return b.text)))
	picks[2].emit_signal("pressed")
	await _frames(5)
	check(main.map_id == "ds_dawngate" and main.gold == 555, "K  ...the Dawn Gate picked: in at the Dawn Gate")
	# The loss screen offers the same.
	main.rules.wagon.take_damage(999999.0)
	await _frames(30)
	var lost: Array = main.hud.find_children("*", "Button", true, false).map(func(b): return b.text)
	check(lost.has("The beginning") and lost.has("The Outer Bailey") and lost.has("The Dawn Gate") and lost.has("Back to the map"),
			"K  lost: start again from the beginning or any checkpoint, or the map (%s)" % ", ".join(lost))


# --- W ---------------------------------------------------------------------------------------

func _win() -> void:
	_at_dawnspire()
	campaign.op_state = {"mission": "ds_assault", "zone": 2, "name": "The Dawn Gate", "gold": 500, "army": [], "xp": {}}   # (as the first build saved it)
	campaign.save_game()
	campaign.load_game()
	await _assault(2)
	var rules = main.rules
	check(main.map_id == "ds_dawngate" and rules.gate.style == "dawn", "W  the Dawn Gate")
	_unit("swordsman", Vector2(320, 600))
	rules.gate.batter(99999.0)
	await _frames(60 * 2)
	check(not main.game_over and rules.action_label() == "Into the citadel", "W  cleared, it waits for the order to finish")
	rules.action()
	await _frames(30)
	check(main.game_over and main.victory and campaign.completed.has("ds_assault") and campaign.op_state.is_empty(),
			"W  broken and its field cleared: the Liberation's assault is won, the checkpoint gone")
