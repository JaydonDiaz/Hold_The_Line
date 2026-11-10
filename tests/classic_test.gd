extends SceneTree
## Classic's castle and the battle around it, checked piece by piece: the castle is
## clicked and upgraded, Wall Archers stand guard, enemies lay siege and wear it down,
## Sappers blow up against it, Skeleton Archers shoot it, it can fall, repairs mend it
## with Engineers walking out of the gate, walls follow their rules, and the Tutorial and
## Freeplay start as they should. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/classic_test.gd
## Exits 1 if anything failed. (Kept in the repository so it's always there to run.)

var main
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


func _foe(kind: String, at: Vector2):
	main._spawn_enemy(kind, 1, at)
	var e = main.enemy_layer.get_children()[-1]
	e.position = at
	return e


func _run() -> void:
	await _castle()
	await _siege()
	await _walls()
	await _modes()
	if main != null:
		main.free()
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _castle() -> void:
	await _fresh()
	check(main.castle.visible and (not "camp" in main or main.camp == null), "Classic has its castle")
	check(main.on_castle(Vector2(320, main.CASTLE_Y + 10)), "...which can be clicked")
	main.select_castle()
	check(main.castle_selected, "...and selected, to upgrade")
	main.gold = 99999
	main.castle_upgrade(0)
	check(main.powers.tiers[0] == 1 and main.powers.armor() > 0.0, "Fortify bought: the walls take less damage (%.0f%%)" % (main.powers.armor() * 100.0))
	main.castle_upgrade(1)
	await _frames(5)
	var guards: Array = main.powers.guards.filter(func(w): return is_instance_valid(w))
	check(guards.size() == 2, "Wall Archers bought: two Archers stand on the wall (%d)" % guards.size())
	main.wave_active = true
	var e = _foe("orc", Vector2(guards[0].position.x, main.CASTLE_Y - 60))
	e.speed = 0.0
	var hp0: float = e.hp
	await _frames(120)
	check(e.hp < hp0, "...and shoot an enemy come close to the castle")
	check(guards.all(func(g): return g.position.distance_to(g.post) < 1.0), "...without leaving their posts")


func _siege() -> void:
	await _fresh()
	main.wave_active = true
	main.spawn_queue.clear()
	var hp0: float = main.castle_hp
	var orc = _foe("orc", Vector2(320, main.CASTLE_Y - 30))
	await _frames(150)
	check(orc.sieging and main.castle_hp < hp0, "An Orc at the castle lays siege and wears it down (%d to %d)" % [roundi(hp0), roundi(main.castle_hp)])
	orc.free()
	main.enemies_changed()
	hp0 = main.castle_hp
	_foe("sapper", Vector2(200, main.CASTLE_Y - 20))
	await _frames(90)
	check(main.castle_hp < hp0, "A Sapper blows up against the castle (%d to %d)" % [roundi(hp0), roundi(main.castle_hp)])
	hp0 = main.castle_hp
	var archer = _foe("skeleton_archer", Vector2(460, main.CASTLE_Y - 120))
	archer.speed = 0.0
	await _frames(240)
	check(main.castle_hp < hp0, "A Skeleton Archer in range shoots the castle (%d to %d)" % [roundi(hp0), roundi(main.castle_hp)])
	for x in main.get_enemies():
		x.free()
	main.enemies_changed()
	# Repairs: the Engineers walk out of the gate and mend it.
	main.wave_active = false
	main.gold = 99999
	var low: float = main.castle_hp
	check(main.can_repair(3), "Between waves the castle can be repaired")
	main.repair_castle(3)
	await _frames(5)
	var engineers: Array = main.fx_layer.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("engineer.gd"))
	check(not engineers.is_empty() and engineers[0].position.distance_to(engineers[0].gate()) < 40.0, "...Engineers come out of the gate (%d)" % engineers.size())
	await _frames(60 * 12)
	check(main.castle_hp > low, "...and mend it (%d to %d)" % [roundi(low), roundi(main.castle_hp)])
	# It can fall.
	main.wave_active = true
	main.damage_castle(1e9)
	await _frames(3)
	check(main.game_over and not main.victory, "The castle falling ends the game")


func _walls() -> void:
	await _fresh()
	main.gold = 99999
	main.placing_type = "barricade"
	main._wall_click(Vector2(200, 450))
	main._wall_click(Vector2(400, 450))
	main.placing_type = ""
	await _frames(3)
	check(main.get_barricades().size() == 1, "A barricade goes up in two clicks")
	check(main.wall_problem(Vector2(300, 500), Vector2(310, 500)) == "Too short", "...a wall can't be too short")
	main.placing_type = "swordsman"
	main.hire_at(Vector2(300, 560))
	main.placing_type = ""
	check(main.wall_problem(Vector2(250, 560), Vector2(350, 560)) == "Blocked by a unit", "...nor run through a unit's post")
	main.wave_active = true
	var gob = _foe("goblin", Vector2(300, 300))
	await _frames(60 * 6)
	check(not is_instance_valid(gob) or gob.dead or absf(gob.position.x - 300.0) > 60.0 or gob.position.y < 440.0,
			"An enemy walks round a wall (or stops at it), not through")


func _modes() -> void:
	await _fresh("freeplay")
	main.damage_castle(1e9)
	check(main.freeplay and not main.game_over and main.castle_hp >= 1.0, "Freeplay: the castle can't fall")
	await _fresh("tutorial")
	await _frames(10)
	check(main.tutorial and main.started and main.castle.visible, "The Tutorial starts, with its castle")
	await _fresh("hard")
	check(main.difficulty == "hard" and main.castle_max < 450.0 and main.permadeath, "Hard: a weaker castle (%d) and permadeath" % roundi(main.castle_max))
