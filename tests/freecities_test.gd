extends SceneTree
## Phase 4, the Free Cities (N3). Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/freecities_test.gd
##   K  contracts   offered at the start; signing pays the bond; every wave held to the
##                  terms pays; breaking them (a villager caught; the Exchange hit) voids it;
##                  can't be signed without the bond, or once the first wave's over
##   S  sellswords  bought any time up to their limit, turning up trained at the camp, even
##                  of a kind the alliance hasn't got (no Archers, no mines here)
##   M  Market Road the Free Cities open without Deepdelve; every street the townsfolk take
##                  is clear of buildings and canals
##   X  the Exchange the Council's vote fills while nobody's at its doors and stops while an
##                  enemy is; the Warlord comes
##   N  night       Carnival Night: dark away from the lanterns; an enemy in the dark and
##                  away from your troops is only eyes, one in a lantern's light or by a troop
##                  is plain; ones coming down in the dark are warned of
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.

const TEST_SAVE := "user://freecities_test_campaign.cfg"
const CD = preload("res://scripts/campaign_data.gd")
const Maps = preload("res://scripts/maps.gd")

var main
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	root.get_node("Campaign").save_path = TEST_SAVE
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _foe(kind: String, at: Vector2, hp := 1e5):
	main._spawn_enemy(kind, 1, at)
	var e = main.get_enemies()[-1]
	e.position = at
	e.speed = 0.0
	e.damage = 0.0
	e.max_hp = hp
	e.hp = hp
	return e


func _mission(mid: String, south: Array, extra_done := [], extra_allies := []) -> void:
	var c = root.get_node("Campaign")
	c.new_campaign("normal")
	var done := ["ashwatch", "ashwatch_road", "stonehollow", "stonehollow_workshops", "sable_crossing"]
	var chains := {"greenwood": ["gw_exodus", "gw_watchfires"], "mercyvale": ["mv_wounded", "mv_sanctuary"], "deepdelve": ["dd_entrance", "dd_orerun"]}
	for r in south:
		done += chains[r]
	c.completed = done + extra_done
	c.allies = ["stonehollow"] + south + extra_allies
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
	await _market()
	await _contracts()
	await _sellswords()
	await _exchange()
	await _night()
	if main != null:
		main.free()
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


# --- The Market Road --------------------------------------------------------------------------

func _market() -> void:
	var c = root.get_node("Campaign")
	c.new_campaign("normal")
	c.completed = ["ashwatch", "ashwatch_road", "stonehollow", "stonehollow_workshops", "gw_exodus", "gw_watchfires", "mv_wounded", "mv_sanctuary", "sable_crossing"]
	c.allies = ["stonehollow", "greenwood", "mercyvale"]
	check(c.mission_open("fc_market"), "M  the Market Road opens without Deepdelve")
	await _mission("fc_market", ["greenwood", "mercyvale"])
	check(main.map_id == "city_market", "M  ...on its own map")
	var blocked := []
	for route in CD.MISSIONS["fc_market"]["evac"]["routes"]:
		for i in route.size() - 1:
			for k in 12:
				var p: Vector2 = (route[i] as Vector2).lerp(route[i + 1], k / 12.0)
				if p.y > 60.0 and p.y < 730.0 and main.paths.blocked(p, 10.0):
					blocked.append(str(p.round()))
	check(blocked.is_empty(), "M  every street the townsfolk take is clear%s" % ("" if blocked.is_empty() else " (not at %s)" % ", ".join(blocked.slice(0, 4))))


# --- Contracts --------------------------------------------------------------------------------

func _contracts() -> void:
	await _mission("fc_market", ["greenwood", "mercyvale"])
	var k = main.contracts
	check(k.state == "offered" and k.contract_label().contains("[U]"), "K  the Merchants' Purse is offered at the start")
	main.gold = 50
	check(not k.sign() and k.state == "offered", "K  ...it can't be signed without the bond")
	main.gold = 1000
	main.deploying = false
	main.auto_timer = 1e9
	main.wave = 1
	main.wave_active = true
	check(k.sign() and k.state == "signed" and main.gold == 1000 - int(CD.MISSIONS["fc_market"]["contract"]["bond"]), "K  ...signing it pays the bond")
	await _frames(5)
	var g0: int = main.gold
	main.wave = 2
	await _frames(3)
	check(k.paid_waves == 1 and main.gold == g0 + int(CD.MISSIONS["fc_market"]["contract"]["pay"]), "K  ...a wave held pays out (%d)" % (main.gold - g0))
	main.rules.lost += 1
	await _frames(3)
	var g1: int = main.gold
	main.wave = 3
	await _frames(3)
	check(k.state == "void" and main.gold == g1, "K  ...a villager caught breaks it: void, and nothing more paid")
	# Too late: the offer's for the start of the battle.
	await _mission("fc_market", ["greenwood", "mercyvale"])
	k = main.contracts
	main.gold = 1000
	main.deploying = false
	main.wave = 2
	main.wave_active = true
	await _frames(3)
	check(not k.sign() and k.state == "closed", "K  ...and once the first wave's over, the offer's gone")
	# The Council Bond: the Exchange hit breaks it.
	await _mission("fc_council", ["greenwood", "mercyvale"], ["fc_market"], ["freecities"])
	k = main.contracts
	main.gold = 1000
	main.deploying = false
	main.auto_timer = 1e9
	main.wave = 1
	main.wave_active = true
	k.sign()
	await _frames(3)
	var ex = main.rules.objectives()[0]
	ex.take_damage(20.0)
	await _frames(3)
	check(k.state == "void", "K  the Council Bond: the Exchange taking a hit breaks it")


# --- Sellswords -------------------------------------------------------------------------------

func _sellswords() -> void:
	# Mercy Vale and Deepdelve: no Archers of their own.
	await _mission("fc_market", ["mercyvale", "deepdelve"])
	var k = main.contracts
	main.deploying = false
	main.gold = 1000
	var before: int = main.get_warriors().size()
	check(not main.allowed("archer") and k.merc_label().contains("[H]"), "S  sellswords for hire, in an army with no Archers")
	check(k.hire(), "S  ...hired")
	await _frames(2)
	var new_ones: Array = main.get_warriors().slice(before)
	var squad: Array = CD.MISSIONS["fc_market"]["mercs"]["squad"]
	check(new_ones.size() == squad.size() and main.gold == 1000 - int(CD.MISSIONS["fc_market"]["mercs"]["cost"]),
			"S  ...%d turn up, for %dg" % [new_ones.size(), 1000 - main.gold])
	check(new_ones.any(func(w): return w.kind == "archer") and new_ones.all(func(w): return w.tiers[0] >= 1 and w.position.y > 560.0 and w.spent == 0),
			"S  ...an Archer among them, trained, at the camp, on loan (nothing to sell back)")
	k.hire()
	check(not k.can_hire() and not k.hire() and k.merc_label() == "", "S  ...up to %d times" % int(CD.MISSIONS["fc_market"]["mercs"]["max"]))


# --- The Exchange -----------------------------------------------------------------------------

func _exchange() -> void:
	await _mission("fc_council", ["greenwood", "mercyvale"], ["fc_market"], ["freecities"])
	var ex = main.rules.objectives()[0]
	check(main.map_id == "city_exchange" and ex.kind == "exchange" and ex.charge > 0.0, "X  the Council's Price: the Exchange, a vote to wait out")
	main.deploying = false
	main.auto_timer = 1e9
	main.spawn_queue.clear()
	for e in main.get_enemies():
		e.free()
	await _frames(60)
	var p0: float = ex.progress
	check(p0 > 0.0, "X  ...the vote fills while nobody's at its doors (%.3f)" % p0)
	var e = _foe("orc", ex.position + Vector2(0, -ex.RADIUS - 10.0))
	await _frames(60)
	check(is_equal_approx(ex.progress, ex.progress) and ex.progress - p0 < 0.002 and ex.contested, "X  ...and stops while an enemy is there")
	e.free()
	var warlord := false
	for w in CD.MISSIONS["fc_council"].get("extra", {}):
		warlord = warlord or (CD.MISSIONS["fc_council"]["extra"][w] as Array).has("warlord")
	check(warlord, "X  ...the Warlord comes")


# --- Carnival Night ---------------------------------------------------------------------------

func _night() -> void:
	await _mission("fc_carnival", ["greenwood", "mercyvale"], ["fc_market"], ["freecities"])
	var n = main.night
	check(main.map_id == "city_carnival" and n.active() and n.lanterns.size() > 4, "N  Carnival Night: dark, %d lanterns" % n.lanterns.size())
	main.deploying = false
	main.auto_timer = 1e9
	main.spawn_queue.clear()
	for e in main.get_enemies():
		e.free()
	for w in main.get_warriors():
		w.free()
	main.gold = 999
	main.placing_type = "swordsman"
	main.hire_at(Vector2(600, 420))
	main.placing_type = ""
	var w = main.get_warriors()[-1]
	w.position = w.post
	main.wave = 1
	main.wave_active = true
	var dark = _foe("orc", Vector2(60, 430))
	var lamp = _foe("orc", n.lanterns[0] + Vector2(10, 10))
	var by = _foe("orc", w.position + Vector2(0, -60))
	var high = _foe("goblin", Vector2(600, 90))
	await _frames(4)
	check(dark.modulate.a < 0.3 and n._dim.has(dark), "N  an enemy in the dark, away from your troops: only its eyes (%.2f)" % dark.modulate.a)
	check(lamp.modulate.a > 0.95 and by.modulate.a > 0.95, "N  ...one under a lantern, or by a troop, is plain")
	check(n._called.has(high.get_instance_id()) and n._dim.has(high), "N  ...one coming down in the dark is warned of (a chevron up top, and a message)")
