extends SceneTree
## Skeleton Archers and Slimes. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/foes_test.gd
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.
##
## A  Skeleton Archers stop at bow range from a troop and shoot it; with nobody about they
##    stop short of the castle and shoot the wall; a Swordsman runs one down
## S  Slimes: blades and arrows don't hurt them and troops that only have those don't go
##    after them (Swordsmen back away instead); magic, ki and ice do; ice does double and
##    lets steel bite; they go for troops before the castle; their blows slow
## W  Classic waves bring Skeleton Archers in early and Slimes later; the first sight of
##    each puts up a warning
## M  The Ash Marshal (on Sable Crossing): his banner drives on the enemies round him and
##    falls when he's hit hard (and goes up again); he charges a troop in his way, never
##    across water, the ford, rock or a wall, and a charge stops dead short of the water;
##    he crosses each bridge with a crowd round him without sticking or wading in

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


func _run() -> void:
	await _archers()
	await _slimes()
	await _waves()
	await _marshal()
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _fresh() -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud.picking = true
	main.choose_mode("normal")
	main.gold = 99999
	await process_frame


func _hire(kind: String, at: Vector2):
	main.placing_type = kind
	main.hire_at(at)
	main.placing_type = ""
	main.selected = null
	var all: Array = main.get_warriors().filter(func(w): return w.kind == kind)
	return all[all.size() - 1]


func _spawn(kind: String, at: Vector2):
	main._spawn_enemy(kind, 1, at)
	var all: Array = main.get_enemies().filter(func(e): return e.kind == kind)
	return all[all.size() - 1]


func _hold(w) -> void:
	w.max_hp = 99999.0
	w.hp = 99999.0


# --- A: Skeleton Archers ---------------------------------------------------------------

func _archers() -> void:
	await _fresh()
	var r: float = main.Data.ENEMIES["skeleton_archer"]["ranged"]["range"]
	var sw = _hire("swordsman", Vector2(320, 560))
	sw.position = sw.post
	_hold(sw)
	sw.set_process(false)   # it stands there and takes it
	main.wave_active = true
	var sk = _spawn("skeleton_archer", Vector2(320, 200))
	_hold(sk)
	await _frames(600)
	var gap: float = sk.position.distance_to(sw.position) - sw.RADIUS - sk.radius
	check(gap > r * 0.8 and gap <= r + 2.0, "A  the Skeleton Archer stopped at bow range (%.0f px off, range %.0f)" % [gap, r])
	check(sw.hp < sw.max_hp, "A  ...and shot the Swordsman (%.0f damage)" % (sw.max_hp - sw.hp))
	var hp_before: float = sw.hp
	var pos: Vector2 = sk.position
	await _frames(240)
	check(sk.position.distance_to(pos) < 4.0 and sw.hp < hp_before, "A  it holds its spot and keeps shooting")
	# Nobody about: it stops short of the castle and shoots the wall.
	sw.queue_free()
	await process_frame
	main.warriors_changed()
	var castle: float = main.castle_hp
	await _frames(900)
	check(not sk.sieging and sk.position.y < main.CASTLE_Y - r * 0.7, "A  with no troop in range it stops short of the castle (y %.0f, wall at %d)" % [sk.position.y, main.CASTLE_Y])
	check(main.castle_hp < castle, "A  ...and shoots the castle from there (%.0f damage)" % (castle - main.castle_hp))
	# A Swordsman runs it down.
	sk.max_hp = 24.0
	sk.hp = 24.0
	var hunter = _hire("swordsman", Vector2(sk.position.x, sk.position.y + 120.0))
	_hold(hunter)
	await _frames(600)
	check(not is_instance_valid(sk) or sk.dead, "A  a Swordsman runs the Skeleton Archer down")


# --- S: Slimes -------------------------------------------------------------------------

func _slimes() -> void:
	await _fresh()
	main.wave_active = true
	var sl = _spawn("slime", Vector2(320, 300))
	sl.set_process(false)
	var hp: float = sl.hp
	sl.take_damage(50.0)
	check(sl.hp == hp, "S  a physical hit does nothing to a Slime")
	sl.take_damage(10.0, true, "magic")
	check(is_equal_approx(sl.hp, hp - 10.0), "S  magic hurts it")
	sl.take_damage(10.0, true, "ki")
	check(is_equal_approx(sl.hp, hp - 20.0), "S  ki hurts it")
	sl.take_damage(10.0, true, "ice")
	check(is_equal_approx(sl.hp, hp - 40.0) and sl.ice_crust > 0.0, "S  ice does double (20 for 10) and ices it over")
	sl.take_damage(10.0)
	check(is_equal_approx(sl.hp, hp - 50.0), "S  iced over, a physical hit lands")
	sl.ice_crust = 0.0
	sl.apply_freeze(1.0)
	sl.ice_crust = 0.0
	sl.take_damage(5.0)
	check(is_equal_approx(sl.hp, hp - 55.0), "S  frozen solid, a physical hit lands")
	sl.freeze_timer = 0.0
	sl.queue_free()
	await process_frame

	# Who goes after a Slime.
	await _fresh()
	main.wave_active = true
	var units := {}
	for k in ["swordsman", "archer", "mage", "frost", "bard", "alchemist", "martial"]:
		units[k] = _hire(k, Vector2(80 + units.size() * 75, 640))
		_hold(units[k])
	var ki = _hire("martial", Vector2(600, 640))
	_hold(ki)
	main.selected = ki
	main.upgrade_selected(0)   # Ki Blast
	main.selected = null
	var tower = _hire("tower", Vector2(320, 700))
	sl = _spawn("slime", Vector2(320, 520))
	sl.set_process(false)
	_hold_enemy(sl)
	for k in units:
		check(units[k].can_hurt(sl) == (k in ["mage", "frost", "bard"]),
				"S  %s %s go after a Slime" % [k.capitalize(), "does" if units[k].can_hurt(sl) else "doesn't"])
	check(ki.can_hurt(sl), "S  a Martial Artist with Ki Blast does")
	check(not tower.can_hurt(sl), "S  an Archer Tower doesn't")
	await _frames(240)
	check(sl.hp < sl.max_hp, "S  the magic users and the Ki Blaster wear it down (%.0f damage)" % (sl.max_hp - sl.hp))
	check(units["swordsman"].target != sl and units["archer"].target != sl, "S  the Swordsman and Archer leave it alone")
	sl.ice_crust = 3.0
	sl.set_process(true)
	sl.speed = 0.0
	await _frames(2)
	check(units["swordsman"].can_hurt(sl) and units["archer"].can_hurt(sl), "S  iced over, it's fair game for the Swordsman and the Archer too")
	sl.queue_free()
	await process_frame

	# A Slime goes for a troop before the castle, the troop backs away, and it's slowed.
	await _fresh()
	main.wave_active = true
	var sw = _hire("swordsman", Vector2(150, 420))
	_hold(sw)
	sl = _spawn("slime", Vector2(330, 360))
	_hold_enemy(sl)
	await _frames(40)
	check(sl.aggro == sw, "S  the Slime goes after the Swordsman rather than the castle")
	var closest := INF
	var gooed := false
	for i in 900:
		await process_frame
		closest = minf(closest, sl.position.distance_to(sw.position) - sl.radius - sw.RADIUS)
		gooed = gooed or sw.goo_timer > 0.0
	check(sw.target != sl, "S  the Swordsman never goes for it")
	check(sw.position.distance_to(Vector2(150, 420)) > 30.0, "S  ...and backs away from it (now %.0f px from its post)" % sw.position.distance_to(Vector2(150, 420)))
	# Pin it so the slime catches it.
	sw.set_process(false)
	for i in 600:
		await process_frame
		if sw.goo_timer > 0.0:
			break
	check(sw.goo_timer > 0.0 and sw._goo_factor() < 1.0, "S  a Slime's blow slows the troop it hits (to %d%% speed)" % roundi(sw._goo_factor() * 100))
	check(sw._rate() < 1.0, "S  ...and its attacks")


func _hold_enemy(e) -> void:
	e.max_hp = 9999.0
	e.hp = 9999.0


# --- W: Classic waves --------------------------------------------------------------------

func _waves() -> void:
	await _fresh()
	var early := {}
	var later := {}
	for i in 40:
		for k in main._build_wave(2):
			early[k] = true
		for k in main._build_wave(7):
			later[k] = true
	check(early.has("skeleton_archer") and not early.has("slime"), "W  Skeleton Archers come from wave 2; no Slimes yet")
	var first_slime := 99
	for n in range(1, 12):
		var seen := false
		for i in 40:
			if main._build_wave(n).has("slime"):
				seen = true
				break
		if seen:
			first_slime = n
			break
	check(first_slime == 6 and later.has("slime"), "W  Slimes first come on wave %d" % first_slime)
	main.wave_active = true
	main._spawn_enemy("slime", 6, Vector2(320, 100))
	await process_frame
	check("Slimes" in main.hud.message_label.text, "W  the first Slime puts up a warning")
	main.free()
	main = null



# --- M: the Ash Marshal --------------------------------------------------------------------

func _on_sable() -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud.picking = true
	main.records_path = ""
	main.classic_map = "sable_crossing"
	main.choose_mode("normal")
	main._lock_portrait(true)
	main.gold = 99999
	await _frames(2)


func _marshal() -> void:
	await _on_sable()
	var paths = main.paths
	check(main.map_id == "sable_crossing" and paths.in_ford(Vector2(325, 383)) and paths.blocked(Vector2(240, 383), 10.0), "M  Sable Crossing: the river, its bridges and the ford")
	main.start_wave()
	await _frames(2)
	main.spawn_queue.clear()
	for e in main.get_enemies():
		e.free()
	var m = _spawn("ash_marshal", Vector2(320, 200))
	m.position = Vector2(320, 200)
	m.speed = 0.0
	m.max_hp = 5000.0
	m.hp = 5000.0
	var gob = _spawn("goblin", Vector2(360, 220))
	gob.position = Vector2(360, 220)
	gob.speed = 0.0
	var far = _spawn("goblin", Vector2(600, 150))
	far.position = Vector2(600, 150)
	far.speed = 0.0
	await _frames(40)
	check(m.boss and m.banner_up() and gob.rally > 0.0 and gob._hit_mult() > 1.2 and far.rally == 0.0,
			"M  his banner drives on the enemies round him (+%d%% damage), not those far off" % roundi((gob._hit_mult() - 1.0) * 100.0))
	main.hud.refresh(main)
	check(main.hud.boss_bar.visible and main.hud.boss_name.text == "THE ASH MARSHAL", "M  ...the boss bar names him")
	m.take_damage(m.max_hp * 0.1)
	await _frames(3)
	check(not m.banner_up(), "M  hit hard, his banner goes down")
	await _frames(60)
	check(gob.rally == 0.0, "M  ...and those round him lose heart")
	m.banner_down = 0.05
	await _frames(40)
	check(m.banner_up() and gob.rally > 0.0, "M  ...until he raises it again")
	gob.free()
	far.free()
	# The charge: at a troop on his side of the river, never at one across it.
	m.speed = 20.0
	m.charge_timer = 0.0
	var across = _hire("swordsman", Vector2(240, 500))
	_hold(across)
	across.position = Vector2(240, 500)
	across.move_mode = "hold"
	m.position = Vector2(240, 250)
	check(not m._clear_run(m.position, across.position) and not m._clear_run(Vector2(325, 250), Vector2(325, 500)),
			"M  no charge across the water, nor through the ford")
	await _frames(10)
	check(m.charging <= 0.0, "M  ...so he doesn't charge the troop across the river")
	var near = _hire("swordsman", Vector2(140, 300))
	_hold(near)
	near.position = Vector2(140, 300)
	near.post = near.position
	near.move_mode = "hold"
	m.charge_timer = 0.0
	var hp0: float = near.hp
	await _frames(5)
	check(m.charging > 0.0, "M  ...but one on his side, in the open, he charges")
	await _frames(60)
	check(near.hp < hp0, "M  ...and strikes it")
	# A charge pointed at the river stops dead on the bank.
	m.position = Vector2(240, 290)
	m.charging = 2.0
	m.charge_dir = Vector2.DOWN
	await _frames(60)
	check(m.charging <= 0.0 and not paths.blocked(m.position, m.radius - 2.0) and m.position.y < 340.0,
			"M  a charge that meets the water stops on the bank (y %d)" % m.position.y)
	near.free()
	across.free()
	m.free()
	# Over each bridge, with a crowd round him.
	for bx in [150.0, 480.0]:
		await _on_sable()
		main.start_wave()
		await _frames(2)
		main.spawn_queue.clear()
		for e in main.get_enemies():
			e.free()
		var mm = _spawn("ash_marshal", Vector2(bx, 120))
		mm.position = Vector2(bx, 120)
		mm.rush = {}   # (just walking)
		for i in 14:
			var g = _spawn(["goblin", "orc", "wolf"][i % 3], Vector2(bx + (i % 5 - 2) * 26.0, 70.0 + (i / 5) * 26.0))
			g.position = Vector2(bx + (i % 5 - 2) * 26.0, 70.0 + (i / 5) * 26.0)
		var wet := false
		var forded := false
		var crossed := -1.0
		var t := 0.0
		while t < 60.0 and is_instance_valid(mm):
			await process_frame
			t += 1.0 / 60.0
			wet = wet or main.paths.blocked(mm.position, mm.radius - 3.0)
			forded = forded or main.paths.in_ford(mm.position)
			if mm.position.y > 470.0 and crossed < 0.0:
				crossed = t
				break
		check(crossed > 0.0 and not wet, "M  from above the %s bridge, he crosses with a crowd round him in %.0fs, never in the water%s" % [
				"left" if bx < 300 else "right", crossed, " (by the ford)" if forded else ""])
