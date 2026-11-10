extends SceneTree
## Classic's units and enemies, checked behavior by behavior (rebuilt from the old
## scratch tests that were lost; kept in the repository from now on):
##   upgrades     four paths, six upgrades in all, tier IV the top, stats that grow
##   statue       a War Statue boosts troops near it, not ones far off
##   horn         the Rally Horn boosts every unit for a while
##   heal         a Healer mends a hurt ally and revives a downed one; Healing Light too
##   kite         ranged troops back off from a close enemy and keep shooting; a
##                Swordsman stands; a Healer backs off too
##   aggro        a fighter turns on a unit attacking it; a Wolf doesn't
##   commit       an enemy at the castle stays at the castle whatever hits it
##   wyvern       flies, can't be hit by melee, breathes fire on troops
##   spawn        Classic's waves: who comes when, from the top, the Ogre King on wave 20
##   engineer     an emplacement waits for an Engineer to build it
##   route        a troop walks round a wall to get where it's going
##   group        box-style groups: select all, keep only a kind, move together
## Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/units_test.gd [-- <section>]
## Exits 1 if anything failed.

const Warrior = preload("res://scripts/warrior.gd")

var main
var fails := 0
var checks := 0
var only := ""


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	only = args[0] if args.size() > 0 else ""
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _fresh(mode := "normal") -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud.hide_mode_select()
	main.records_path = ""
	main.choose_mode(mode)
	await _frames(2)
	main._lock_portrait(true)
	await _frames(2)
	main.gold = 99999
	main.spawn_queue.clear()


func _hire(kind: String, at: Vector2):
	main.placing_type = kind
	main.hire_at(at)
	main.placing_type = ""
	var w = main.get_warriors().filter(func(x): return x.kind == kind and x.post.distance_to(at) < 30.0)[-1]
	w.position = w.post
	if w.is_emplacement():
		w.finish_build()
	return w


func _foe(kind: String, at: Vector2, hp := -1.0):
	main._spawn_enemy(kind, 1, at)
	var e = main.enemy_layer.get_children()[-1]
	e.position = at
	if hp > 0.0:
		e.max_hp = hp
		e.hp = hp
	return e


func _wants(s: String) -> bool:
	return only == "" or only == s


func _run() -> void:
	for s in ["upgrades", "statue", "horn", "heal", "kite", "aggro", "commit", "wyvern", "spawn", "engineer", "route", "group"]:
		if _wants(s):
			await call("_" + s)
	if main != null:
		main.free()
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _upgrades() -> void:
	await _fresh()
	var w = _hire("swordsman", Vector2(320, 560))
	var dmg0: float = w.damage
	var hp0: float = w.max_hp
	main.selected = w
	for i in 4:
		main.upgrade_selected(0)
	check(w.tiers[0] == 4 and w.path_state(0) == "max", "Upgrades: a path tops out at tier IV")
	check(w.damage > dmg0, "...and each Damage tier hits harder (%.0f to %.0f)" % [dmg0, w.damage])
	main.upgrade_selected(2)
	main.upgrade_selected(2)
	check(w.total_upgrades() == 6 and w.path_state(1) == "full", "...six upgrades in all, then the unit is full")
	var gold: int = main.gold
	main.upgrade_selected(1)
	check(w.tiers[1] == 0 and main.gold == gold, "...a full unit can't take more, and pays nothing")
	check(w.max_hp > hp0, "Health tiers give more health (%.0f to %.0f)" % [hp0, w.max_hp])
	check(w.spent > Warrior.new().spent and w.sell_value() > 0, "Upgrades add to what selling it gives back")
	main.selected = null


func _statue() -> void:
	await _fresh()
	var statue = _hire("statue", Vector2(320, 600))
	var near = _hire("swordsman", Vector2(320, 520))
	var far = _hire("swordsman", Vector2(60, 300))
	await _frames(40)
	check(near.buff["damage"] > 0.0, "War Statue: a troop near it is boosted (+%d%% damage)" % roundi(near.buff["damage"] * 100.0))
	check(far.buff["damage"] == 0.0, "...a troop far off isn't")
	check(statue.covers(near) and not statue.covers(far), "...and its threads show who it's looking after")


func _horn() -> void:
	await _fresh()
	var w = _hire("archer", Vector2(320, 560))
	main.ability_item("horn")
	check(main.powers.owned.has("horn"), "Rally Horn: bought")
	main.ability_item("horn")
	await _frames(10)
	check(main.powers.rally("damage") > 0.0, "...sounded: every unit deals more damage (+%d%%)" % roundi(main.powers.rally("damage") * 100.0))
	await _frames(60 * 9)
	check(main.powers.rally("damage") == 0.0, "...for a while, then it wears off")
	check(main.powers.ready_in("horn") > 0.0, "...and it has to recharge")


func _heal() -> void:
	await _fresh()
	var healer = _hire("healer", Vector2(320, 620))
	var hurt = _hire("swordsman", Vector2(360, 560))
	hurt.hp = hurt.max_hp * 0.3
	main.wave_active = true
	var hp0: float = hurt.hp
	await _frames(60 * 3)
	check(hurt.hp > hp0 + 10.0, "Healer: mends a hurt ally (%d to %d)" % [roundi(hp0), roundi(hurt.hp)])
	hurt.take_damage(1e9)
	await _frames(5)
	check(not hurt.is_active(), "...a troop at no health goes down")
	await _frames(60 * 8)
	check(hurt.is_active() and is_instance_valid(hurt), "...and the Healer gets it back up before it's lost")
	# Healing Light.
	await _fresh()
	var a = _hire("swordsman", Vector2(320, 560))
	a.hp = a.max_hp * 0.2
	main.ability_item("heal")
	main.ability_item("heal")
	main.powers.aim_click(Vector2(320, 560))
	await _frames(10)
	check(a.hp >= a.max_hp * 0.5, "Healing Light: heals the troops under it (%d%% now)" % roundi(a.hp / a.max_hp * 100.0))


func _kite() -> void:
	await _fresh()
	var archer = _hire("archer", Vector2(320, 560))
	main.wave_active = true
	var e = _foe("orc", Vector2(320, 520), 1e5)
	e.speed = 0.0
	var start: Vector2 = archer.position
	await _frames(90)
	check(archer.position.distance_to(e.position) > start.distance_to(e.position) + 15.0, "Kiting: an Archer backs away from an enemy right up against it")
	check(e.hp < e.max_hp, "...and keeps shooting it")
	await _fresh()
	var sw = _hire("swordsman", Vector2(320, 560))
	main.wave_active = true
	var o = _foe("orc", Vector2(320, 520), 1e5)
	o.speed = 0.0
	await _frames(90)
	check(sw.position.distance_to(o.position) < 50.0 and o.hp < o.max_hp, "...a Swordsman stands and fights")
	await _fresh()
	var healer = _hire("healer", Vector2(320, 560))
	main.wave_active = true
	var h = _foe("orc", Vector2(320, 525), 1e5)
	h.speed = 0.0
	var hs: Vector2 = healer.position
	await _frames(90)
	check(healer.position.distance_to(h.position) > hs.distance_to(h.position) + 15.0, "...a Healer backs away too")


func _aggro() -> void:
	await _fresh()
	var archer = _hire("archer", Vector2(150, 420))
	main.wave_active = true
	var orc = _foe("orc", Vector2(300, 300), 1e5)
	await _frames(60 * 3)
	check(orc.aggro == archer, "Aggro: an Orc shot at turns on the Archer shooting it")
	check(orc.position.distance_to(archer.position) < Vector2(300, 300).distance_to(Vector2(150, 420)), "...and goes for it")
	await _fresh()
	var a2 = _hire("archer", Vector2(150, 420))
	main.wave_active = true
	var wolf = _foe("wolf", Vector2(300, 300), 1e5)
	await _frames(60 * 2)
	check(wolf.aggro == null and wolf.position.y > 300.0, "...a Wolf doesn't: it runs on for the castle")


func _commit() -> void:
	await _fresh()
	var archer = _hire("archer", Vector2(320, 560))
	main.wave_active = true
	var orc = _foe("orc", Vector2(500, main.CASTLE_Y - 20), 1e5)
	await _frames(60 * 3)
	check(orc.sieging and orc.aggro == null, "Commit: an Orc at the castle keeps at the castle, even with an Archer shooting it")
	check(orc.hp < orc.max_hp and orc.position.y >= main.CASTLE_Y - 30.0, "...it's being hit, and it stays at the wall")


func _wyvern() -> void:
	await _fresh()
	var sw = _hire("swordsman", Vector2(320, 560))
	var archer = _hire("archer", Vector2(420, 600))
	main.wave_active = true
	var wy = _foe("wyvern", Vector2(320, 450), 1e5)
	check(wy.flying, "Wyvern: it flies")
	check(not sw._can_strike(wy) and archer.hits_air(), "...a Swordsman can't hit it, an Archer can")
	var hp0: float = sw.hp
	await _frames(60 * 6)
	check(sw.hp < hp0 or archer.hp < archer.max_hp, "...and it breathes fire on the troops below")
	check(wy.hp < wy.max_hp, "...while the Archer shoots it")


func _spawn() -> void:
	await _fresh()
	var w1: Array = main._build_wave(1)
	var w5: Array = main._build_wave(5)
	check(not w1.is_empty() and w1.all(func(k): return k == "goblin"), "Spawn: wave 1 is goblins (%d)" % w1.size())
	check(w5.size() > w1.size() and w5.any(func(k): return k != "goblin"), "...later waves are bigger and mixed (%d on wave 5)" % w5.size())
	main.start_wave()
	await _frames(60 * 4)
	var es: Array = main.get_enemies()
	check(not es.is_empty() and es.all(func(e): return e.position.x >= 0.0 and e.position.x <= main.FIELD_W and e.position.y < 300.0),
			"...enemies come in from the top, across the field (%d so far)" % es.size())
	main.wave = 19
	main.wave_active = false
	main.spawn_queue.clear()
	for e in main.get_enemies():
		e.free()
	main.enemies_changed()
	main.start_wave()
	main.spawn_queue.clear()
	for e in main.get_enemies():
		e.free()
	main.enemies_changed()
	await _frames(10)
	check(main.get_enemies().any(func(e): return e.boss), "...and wave 20 ends with the Ogre King")


func _engineer() -> void:
	await _fresh()
	main.placing_type = "tower"
	main.hire_at(Vector2(320, 560))
	main.placing_type = ""
	var t = main.get_warriors().filter(func(w): return w.kind == "tower")[0]
	check(t.under_construction(), "Engineer: a new Archer Tower starts as a building site")
	var engineers: Array = main.fx_layer.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("engineer.gd"))
	check(engineers.size() >= 1, "...an Engineer sets out to build it")
	main.wave_active = true
	var e = _foe("goblin", Vector2(320, 470), 1e5)
	e.speed = 0.0
	await _frames(30)
	check(e.hp == e.max_hp, "...it doesn't shoot while it's being built")
	await _frames(60 * 10)
	check(not t.under_construction() and e.hp < e.max_hp, "...once built, it shoots")


func _route() -> void:
	await _fresh()
	main.placing_type = "barricade"
	main._wall_click(Vector2(220, 450))
	main._wall_click(Vector2(420, 450))
	main.placing_type = ""
	await _frames(3)
	var w = _hire("swordsman", Vector2(320, 560))
	main.selected = w
	main.order_move(Vector2(320, 340))
	main.selected = null
	var crossed := false
	for f in 60 * 8:
		await process_frame
		if absf(w.position.x - 320.0) < 90.0 and absf(w.position.y - 450.0) < 10.0:
			crossed = true
	check(w.position.distance_to(Vector2(320, 340)) < 30.0, "Route: a Swordsman ordered past a wall gets there")
	check(not crossed, "...by going round it, not through")


func _group() -> void:
	await _fresh()
	var a = _hire("swordsman", Vector2(200, 560))
	var b = _hire("swordsman", Vector2(260, 560))
	var c = _hire("archer", Vector2(320, 600))
	_hire("tower", Vector2(500, 600))
	main.select_all_troops()
	check(main.group.size() == 3 and main.selected == null, "Group: select all takes the three troops (not the tower)")
	main.filter_group("swordsman", false)
	check(main.group.size() == 2 and main.group.all(func(w): return w.kind == "swordsman"), "...keep only the Swordsmen")
	main.wave_active = true
	var gap: Vector2 = b.post - a.post
	main.order_group(Vector2(300, 420))
	await _frames(60 * 4)
	check(a.post.y < 450.0 and b.post.y < 450.0 and (b.post - a.post).distance_to(gap) < 20.0, "...and they move together, keeping their formation")
	main.filter_group("swordsman", true)
	check(main.group.is_empty() or main.selected == null, "...dropping the Swordsmen leaves no group")
	main._set_group([c])
	check(main.selected == c and main.group.is_empty(), "A group of one is an ordinary selection")
