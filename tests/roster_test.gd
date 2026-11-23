extends SceneTree
## The enemy roster: each kind's own way of fighting. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/roster_test.gd [-- SECTIONS]
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.
##
## G  Goblins: bolder in a pack (harder, quicker blows), warier alone (slower)
## W  Wolves: quicker in a pack; still run past troops for the walls
## T  Trolls: heal once left unhurt a moment; a hit stops it, fire keeps it from starting
## O  Ogres: the blow hauled back first (its arc marked on the ground), then everyone in
##    its arc hit and thrown back, staggered only a moment
## L  Warlords: the same sweeping blow, through troops packed together
## Y  Wyverns: a strafing run, its line shown first, burning each troop under it once
## S  Sappers: the blast's reach shown while the fuse burns; killed first, no blast
## M  Slimes: blades slide off until it's iced; iced, they bite
## B  Bats keep with their flock
## H  Shieldbearers: shots from in front glance off (blows, and shots from the side, don't);
##    one of its own sheltering just behind it is covered too; it walks in front of them
## D  War Drummers: the beat drives on the light troops round it; two drummers don't add up
## F  Boltflingers: the bolt goes straight through a line of troops, each struck once, less
##    for each it's been through; long to wind again
## X  Horde Mages: a spell picked once as it starts charging (each of the three comes up);
##    lightning leaps between troops close together, each once, weaker each leap; fire a
##    stream down one line, burning in ticks the same at any frame rate; arcane a beam at the
##    troop with the most health, never a sure kill; nothing to aim at: it fizzles; a stun
##    breaks the charge
## K  The Ogre King's left as he was: none of the roster's new ways

const Data = preload("res://scripts/data.gd")
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
	root.get_node("Campaign").save_path = "user://roster_test.cfg"
	var args := OS.get_cmdline_user_args()
	only = "" if args.is_empty() else args[0]
	_run.call_deferred()


func _wants(t: String) -> bool:
	return only == "" or t in only


func _run() -> void:
	if _wants("G"):
		await _goblins()
	if _wants("W"):
		await _wolves()
	if _wants("T"):
		await _trolls()
	if _wants("O"):
		await _ogres()
	if _wants("L"):
		await _warlords()
	if _wants("Y"):
		await _wyverns()
	if _wants("S"):
		await _sappers()
	if _wants("M"):
		await _slimes()
	if _wants("B"):
		await _bats()
	if _wants("H"):
		await _shields()
	if _wants("D"):
		await _drums()
	if _wants("F"):
		await _bolts()
	if _wants("X"):
		await _mages()
	if _wants("K"):
		_king()
	if main != null:
		main.free()
	if FileAccess.file_exists("user://roster_test.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://roster_test.cfg"))
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _fresh() -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	main.records_path = ""
	root.add_child(main)
	await _frames(3)
	main.hud.picking = true
	main.choose_mode("normal")
	main.gold = 99999
	main.deploying = false
	main.wave_active = true
	await process_frame


func _hire(kind: String, at: Vector2):
	main.placing_type = kind
	main.hire_at(at)
	main.placing_type = ""
	main.selected = null
	var all: Array = main.get_warriors().filter(func(w): return w.kind == kind)
	var w = all[all.size() - 1]
	w.build_left = 0.0
	w.position = w.post
	return w


func _foe(kind: String, at: Vector2, level := 1):
	main._spawn_enemy(kind, level, at)
	return main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)


# --- G ---

func _goblins() -> void:
	await _fresh()
	var lone = _foe("goblin", Vector2(100, 120))
	var pack := []
	for i in 4:
		pack.append(_foe("goblin", Vector2(420 + i * 18, 120)))
	await _frames(40)
	var g = pack[0]
	check(g.pack_n >= 2 and g._hit_mult() > 1.08 and g._attack_cd() < g.attack_cd, "G  a goblin with three of its pack round it hits harder and quicker (x%.2f, every %.2fs)" % [g._hit_mult(), g._attack_cd()])
	check(lone.pack_n == 0 and lone._pace() < 1.0 and is_equal_approx(lone._hit_mult(), 1.0), "G  ...one alone hits as ever, and goes warily (x%.2f pace)" % lone._pace())


# --- W ---

func _wolves() -> void:
	await _fresh()
	var s = await _hire("swordsman", Vector2(320, 420))
	var a = _foe("wolf", Vector2(310, 200))
	var b = _foe("wolf", Vector2(340, 200))
	await _frames(40)
	check(a.pack_n == 1 and a._pace() > 1.0, "W  wolves running together are quicker (x%.2f)" % a._pace())
	var deepest := 0.0
	for f in 150:
		await process_frame
		for w in [a, b]:
			if is_instance_valid(w):
				deepest = maxf(deepest, w.position.y)
	check(deepest > 430.0 and s.hp >= s.max_hp, "W  ...and still run past the troops for the walls (got to %.0f; the troop unhurt)" % deepest)


# --- T ---

func _trolls() -> void:
	await _fresh()
	var t = _foe("troll", Vector2(320, 60))
	t.root_timer = 99.0
	t.take_damage(t.max_hp * 0.5)
	var hurt: float = t.hp
	await _frames(60 * 2)
	check(t.hp <= hurt + 0.01, "T  a troll's wounds don't close at once (%.0f)" % t.hp)
	await _frames(60 * 3)
	var healed: float = t.hp
	check(healed > hurt + t.max_hp * 0.05, "T  ...but left unhurt a few seconds, they do (%.0f -> %.0f of %.0f)" % [hurt, healed, t.max_hp])
	t.take_damage(1.0)
	await _frames(60)
	check(t.hp <= healed, "T  ...a hit stops it")
	t.apply_burn(0.1, 6.0)
	await _frames(60 * 4)
	check(not t.mending and t.hp < healed, "T  ...and while it burns it can't start again")
	t.burn_timer = 0.0
	await _frames(60 * 4)
	check(t.mending and t.hp > t.max_hp * 0.5, "T  ...once the fire's out, it heals again")


# --- O ---

func _ogres() -> void:
	await _fresh()
	var s = await _hire("swordsman", Vector2(320, 420))
	s.hp = s.max_hp * 10.0
	s.max_hp = s.hp
	var o = _foe("ogre", Vector2(320, 360))
	var hp0: float = s.hp
	var warned := false
	var seen_zone := false
	var hit_at := -1
	var from := Vector2.ZERO
	for f in 60 * 6:
		await process_frame
		if o.slam_wind > 0.0 and not warned:
			warned = true
			from = s.position
			seen_zone = o.danger_zones().any(func(z): return z.has("c") and s.position.distance_to(z["c"]) <= z["r"] + 6.0)
		if s.hp < hp0 - 1.0:
			hit_at = f
			break
	check(warned and hit_at > 0, "O  an ogre's blow is hauled back first, then lands")
	check(seen_zone, "O  ...the arc it'll sweep is marked on the ground over the troop it's aimed at")
	await _frames(6)
	check(s.dazed > 0.0 or s.position.distance_to(from) > 15.0, "O  ...and the troop it lands on is thrown back (%.0f)" % s.position.distance_to(from))
	await _frames(60 * 2)
	check(s.dazed <= 0.0 and s.is_active(), "O  ...staggered only a moment")
	var o2_data: Dictionary = Data.ENEMIES["ogre"]
	check(o2_data["tier"] == 4 and not o2_data.has("regen") and o2_data.has("slam"), "O  an ogre doesn't heal like a troll")


# --- L ---

func _warlords() -> void:
	await _fresh()
	var troops := []
	for i in 3:
		var t = await _hire("swordsman", Vector2(290 + i * 30, 430))
		t.max_hp = 5000.0
		t.hp = 5000.0
		troops.append(t)
	var w = _foe("warlord", Vector2(320, 380))
	for f in 60 * 6:
		await process_frame
		if troops.filter(func(t): return t.hp < 5000.0).size() >= 2:
			break
	var hit: int = troops.filter(func(t): return t.hp < 5000.0).size()
	check(hit >= 2, "L  a warlord's sweeping blow cuts through troops packed together (%d of 3)" % hit)


# --- Y ---

func _wyverns() -> void:
	await _fresh()
	var troops := []
	for i in 3:
		var t = await _hire("archer", Vector2(320, 300 + i * 40))
		t.max_hp = 5000.0
		t.hp = 5000.0
		troops.append(t)
	var y = _foe("wyvern", Vector2(320, 120))
	y.strafe_timer = 0.0
	y.breath_timer = 999.0
	var warned := false
	var lined := false
	var hits := {}
	for f in 60 * 4:
		await process_frame
		y.breath_timer = 999.0
		if y.strafe_warn > 0.0 and not warned:
			warned = true
			lined = y.danger_zones().any(func(z): return z.has("a"))
			for t in troops:
				hits[t] = t.hp
	var burnt: int = troops.filter(func(t): return t.hp < 5000.0).size()
	var once: bool = troops.all(func(t): return t.hp >= 5000.0 - y.strafe["damage"] * 1.01 - 1.0 or t.hp >= 5000.0)
	check(warned and lined, "Y  a wyvern's strafing run shows its line first")
	check(burnt >= 2 and once, "Y  ...then burns the troops under it, each once (%d of 3)" % burnt)


# --- S ---

func _sappers() -> void:
	await _fresh()
	var c = await _hire("cannon", Vector2(320, 500))
	var sp = _foe("sapper", Vector2(320, 440))
	for f in 60 * 4:
		await process_frame
		if sp.fuse >= 0.0:
			break
	check(sp.fuse >= 0.0, "S  a sapper at an emplacement lights its fuse (the blast's reach shown round it)")
	var hp0: float = c.hp
	sp.take_damage(9999.0)
	await _frames(60 * 2)
	check(c.hp >= hp0 and not c.broken, "S  ...killed before it goes off, there's no blast")


# --- M ---

func _slimes() -> void:
	await _fresh()
	var m = _foe("slime", Vector2(320, 60))
	m.root_timer = 99.0
	var h0: float = m.hp
	m.take_damage(20.0)
	check(m.hp == h0, "M  a slime: blades and arrows slide off")
	m.take_damage(5.0, true, "ice")
	var h1: float = m.hp
	m.take_damage(20.0)
	check(m.ice_crust > 0.0 and m.hp < h1, "M  ...iced over, they bite")
	m.ice_crust = 0.0
	var h2: float = m.hp
	m.take_damage(20.0)
	check(m.hp == h2, "M  ...and once the ice is gone, they slide off again")


# --- B ---

func _bats() -> void:
	await _fresh()
	var a = _foe("bat", Vector2(250, 80))
	var b = _foe("bat", Vector2(330, 80))
	var d0: float = a.position.distance_to(b.position)
	await _frames(60)
	check(a.flock_pull.x > 0.0 and b.flock_pull.x < 0.0, "B  bats keep with their flock (drawn together: %.0f apart, was %.0f)" % [a.position.distance_to(b.position), d0])


# --- K ---

func _king() -> void:
	for k in ["ogre_king", "ogre_unbound"]:
		var d: Dictionary = Data.ENEMIES[k]
		check(not d.has("pack") and not d.has("regen") and not d.has("slam") and not d.has("strafe"), "K  %s is as he was: none of the roster's new ways" % k)


# --- H ---

## A shot at `e` from `from` (as a troop's arrow lands: main.hit_from set while it hits).
func _shot(e, from: Vector2, dmg: float) -> float:
	var h0: float = e.hp
	main.hit_from = from
	e.take_damage(dmg)
	main.hit_from = Vector2.INF
	return h0 - e.hp


func _shields() -> void:
	await _fresh()
	var sb = _foe("shieldbearer", Vector2(320, 200))
	sb.root_timer = 99.0
	sb.heading = Vector2.DOWN
	var front: float = _shot(sb, sb.position + Vector2(0, 150), 20.0)
	var side: float = _shot(sb, sb.position + Vector2(-150, -40), 20.0)
	var h0: float = sb.hp
	sb.take_damage(20.0)
	var blow: float = h0 - sb.hp
	check(front < 20.0 * 0.4 and side >= 19.9 and blow >= 19.9, "H  a shieldbearer: a shot from in front glances off (%.0f of 20), one from the side doesn't (%.0f), nor a blow (%.0f)" % [front, side, blow])
	var archer = _foe("skeleton_archer", Vector2(320, 170))
	archer.root_timer = 99.0
	var covered: float = _shot(archer, archer.position + Vector2(0, 200), 10.0)
	var open: float = _shot(archer, archer.position + Vector2(0, -200), 10.0)
	check(covered < 9.0 and open >= 9.9, "H  ...one of its own just behind it is sheltered from shots through it (%.1f of 10; from behind %.1f)" % [covered, open])
	check(covered > 0.0 and front > 0.0, "H  ...but nothing's made untouchable")
	await _fresh()
	var sp = _foe("skeleton_archer", Vector2(320, 120))
	var sb2 = _foe("shieldbearer", Vector2(200, 60))
	for f in 60 * 6:
		await process_frame
	check(sb2.escort == sp and sb2.position.y > sp.position.y and sb2.position.distance_to(sp.position) < 60.0,
			"H  ...it gets out in front of the archers it's covering (%.0f from it; it at %s, they at %s)" % [sb2.position.distance_to(sp.position), sb2.position, sp.position])


# --- D ---

func _drums() -> void:
	await _fresh()
	var d = _foe("drummer", Vector2(320, 100))
	d.root_timer = 99.0
	var g = _foe("goblin", Vector2(340, 140))
	g.root_timer = 99.0
	var far = _foe("goblin", Vector2(60, 400))
	far.root_timer = 99.0
	d.drum_t = 0.05
	await _frames(10)
	check(g.driven > 0.0 and g._pace() > 1.0 and g._attack_cd() < g.attack_cd and far.driven <= 0.0,
			"H  a war drum drives on the goblins round it (x%.2f pace, every %.2fs), not those far off".replace("H  ", "D  ") % [g._pace(), g._attack_cd()])
	var one: float = g._pace()
	var d2 = _foe("drummer", Vector2(300, 110))
	d2.root_timer = 99.0
	d2.drum_t = 0.05
	d.drum_t = 0.06
	await _frames(10)
	check(is_equal_approx(g._pace(), one), "D  ...two drummers don't add up (x%.2f)" % g._pace())
	g.driven = 0.0
	await _frames(2)
	check(is_equal_approx(g._attack_cd(), g.attack_cd / (1.0 + g.pack["per"] * 0.5 * g.pack_n)), "D  ...and once the beat's worn off, it's as before")


# --- F ---

func _bolts() -> void:
	await _fresh()
	var troops := []
	for i in 3:
		var t = await _hire("swordsman", Vector2(320, 330 + i * 34))
		t.max_hp = 5000.0
		t.hp = 5000.0
		t.dazed = 99.0   # (held where they stand: a line)
		troops.append(t)
	var side = await _hire("swordsman", Vector2(470, 380))
	side.max_hp = 5000.0
	side.hp = 5000.0
	side.dazed = 99.0
	var b = _foe("boltflinger", Vector2(320, 150))
	b.root_timer = 99.0
	var first := -1
	var second := -1
	for f in 60 * 9:
		await process_frame
		if b.shots >= 1 and first < 0:
			first = f
		if b.shots >= 2 and second < 0:
			second = f
			break
	await _frames(30)
	var lost: Array = troops.map(func(t): return 5000.0 - t.hp)
	check(lost[0] > 0.0 and lost[1] > 0.0 and lost[2] > 0.0, "F  a boltflinger's bolt goes through a line of troops (%s)" % str(lost))
	check(lost[0] > lost[1] and lost[1] > lost[2] and lost[0] <= b.damage * 2.0 + 1.0, "F  ...less for each it's been through, each struck once a bolt")
	check(side.hp >= 5000.0, "F  ...a troop off the line isn't touched")
	check(second - first >= int(60 * b.attack_cd * 0.9), "F  ...and it's slow to wind again (%.1fs)" % ((second - first) / 60.0))

# --- X ---

## A Horde Mage held where it stands, ready to cast `spell` at once (the spell forced: the
## random pick is checked on its own).
func _caster(at: Vector2):
	var m = _foe("warmage", at)
	m.root_timer = 99.0
	m.cast_cd = 0.0
	return m


func _cast_now(m, spell: String) -> void:
	m.cast_state = "charge"
	m.cast_spell = spell
	m.cast_left = 0.02
	await _frames(4)


func _tough(kind: String, at: Vector2, hp := 5000.0):
	var t = await _hire(kind, at)
	t.max_hp = hp
	t.hp = hp
	t.dazed = 99.0   # (held where it stands)
	return t


func _mages() -> void:
	# The pick: each of the three comes up, and it's chosen once per charge.
	await _fresh()
	var t0 = await _tough("swordsman", Vector2(320, 300))
	var m = _caster(Vector2(320, 150))
	var seen := {}
	var steady := true
	for i in 60:
		m.cast_state = ""
		m.cast_cd = 0.0
		m._cast_update(0.016)
		var first: String = m.cast_spell
		for k in 5:
			m._cast_update(0.016)
			steady = steady and m.cast_spell == first
		seen[first] = true
	check(seen.size() == 3 and steady, "X  a mage's spell: lightning, fire or arcane, each comes up (%s), and never changes mid-charge" % ", ".join(seen.keys()))
	# Lightning: leaps between troops close together, each once; not to one far off.
	await _fresh()
	var close := []
	for i in 4:
		close.append(await _tough("swordsman", Vector2(300 + (i % 2) * 36, 300 + (i / 2) * 36)))
	var far = await _tough("swordsman", Vector2(600, 330))
	m = _caster(Vector2(320, 150))
	await _cast_now(m, "lightning")
	var lost: Array = close.map(func(t): return 5000.0 - t.hp)
	check(lost.all(func(x): return x > 0.0) and far.hp >= 5000.0 and m.last_chain == 4, "X  lightning leaps between troops close together (%d struck), not to one far off" % m.last_chain)
	var each_once: bool = lost.all(func(x): return x <= m.cast["lightning"]["damage"] * 1.001 + 0.01)
	var fades: bool = lost.max() > lost.min()
	check(each_once and fades, "X  ...each struck once, weaker with each leap (%s)" % str(lost.map(func(x): return snappedf(x, 0.1))))
	# Spread out: it can't leap.
	await _fresh()
	var a = await _tough("swordsman", Vector2(200, 300))
	var b = await _tough("swordsman", Vector2(440, 300))
	m = _caster(Vector2(320, 150))
	await _cast_now(m, "lightning")
	check(m.last_chain == 1, "X  ...troops spread apart: it can't leap (%d struck)" % m.last_chain)
	# Fire: a stream down one line, those in it burnt in ticks, the same at any frame rate.
	var burnt := []
	for fps in [60, 20]:
		await _fresh()
		Engine.physics_ticks_per_second = 60
		var front = await _tough("swordsman", Vector2(320, 240))
		var behind = await _tough("swordsman", Vector2(320, 270))
		var aside = await _tough("swordsman", Vector2(520, 160))
		m = _caster(Vector2(320, 150))
		m.cast_state = "flame"
		m.flame_dir = Vector2.DOWN
		m.flame_left = m.cast["fire"]["time"]
		m.flame_tick = 0.0
		# Stepped by hand at this rate (as the game would run it).
		var dt: float = 1.0 / float(fps)
		while m.cast_state == "flame":
			m._flame(dt)
		burnt.append([5000.0 - front.hp, 5000.0 - behind.hp, 5000.0 - aside.hp])
		m.root_timer = 0.0
	var at60: Array = burnt[0]
	var at20: Array = burnt[1]
	check(at60[0] > 0.0 and at60[1] > 0.0 and at60[2] == 0.0, "X  fire: a stream burns the troops in front of it (%.0f, %.0f), not one off to the side" % [at60[0], at60[1]])
	check(absf(at60[0] - at20[0]) < 0.01, "X  ...the same burn however fast the game runs (%.1f at 60 fps, %.1f at 20)" % [at60[0], at20[0]])
	# Arcane: the troop with the most health left; heavy, but never a sure kill.
	await _fresh()
	var small = await _tough("swordsman", Vector2(280, 300), 300.0)
	var big = await _tough("swordsman", Vector2(360, 300), 900.0)
	big.hp = 900.0
	small.hp = 300.0
	var frail = await _tough("archer", Vector2(320, 260), 100.0)
	m = _caster(Vector2(320, 150))
	await _cast_now(m, "arcane")
	check(m.last_arcane == big and big.hp < 900.0 and small.hp >= 300.0, "X  arcane: a beam at the troop with the most health left")
	await _fresh()
	var lone = await _tough("archer", Vector2(320, 300), 60.0)
	m = _caster(Vector2(320, 150))
	await _cast_now(m, "arcane")
	check(lone.is_active() and lone.hp > 0.0, "X  ...never a sure kill outright (%.0f of 60 left)" % lone.hp)
	# Nothing to aim at when it lets go: it fizzles, and is soon ready again.
	await _fresh()
	m = _caster(Vector2(320, 150))
	await _cast_now(m, "lightning")
	check(m.cast_state == "" and m.cast_cd <= 1.5, "X  with no one left in reach as it lets go, it fizzles, and isn't stuck")
	# A stun breaks the charge off.
	await _fresh()
	await _tough("swordsman", Vector2(320, 300))
	m = _caster(Vector2(320, 150))
	m.cast_state = "charge"
	m.cast_spell = "arcane"
	m.cast_left = 1.0
	m.apply_stun(1.0)
	await _frames(3)
	check(m.cast_state == "" and m.cast_cd > 0.0, "X  a stun while it's charging breaks the spell off")
	# Its fire, beams and sparks leave nothing behind.
	await _fresh()
	var t1 = await _tough("swordsman", Vector2(320, 300))
	m = _caster(Vector2(320, 150))
	m.root_timer = 99.0
	await _frames(60 * 12)
	var fx_left: int = main.fx_layer.get_child_count()
	check(fx_left < 30, "X  ...and its spells' effects are cleared away (%d left on the field)" % fx_left)

