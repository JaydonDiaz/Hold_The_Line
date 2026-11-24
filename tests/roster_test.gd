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
## N  Gravebinders: a troop fallen for good lies there a while; one channels over it (longer
##    the more was spent on it) and it rises corrupted: its kind, upgrades and look kept, its
##    strength cut, fighting as its kind did (an Archer's volleys, a Storm Mage's lightning, a
##    Healer mending the horde); one body, one Gravebinder; two raised at most; a stun or its
##    death breaks the rite off and leaves the body; the raised, the bowmen and emplacements
##    leave nothing to raise; its bowmen capped
## I  Where they're met: Classic brings the new kinds in a few at a time from wave 8, and the
##    horde's squads marching together; the campaign keeps its first missions as they were
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
	if _wants("N"):
		await _necro()
	if _wants("I"):
		await _integration()
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
	check(deepest > 400.0 and s.hp >= s.max_hp, "W  ...and still run past the troops for the walls (got to %.0f; the troop unhurt)" % deepest)


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
		t.reacts = false   # (the run itself: getting out of its way is defense_test's)
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



# --- N ---

## A troop of yours killed for good where it stands (permadeath, no one to revive it).
func _kill(w) -> void:
	main.permadeath = true
	w.take_damage(1e6)
	w.down_timer = 0.01
	await _frames(3)


func _binder(at: Vector2):
	var g = _foe("gravebinder", at)
	g.root_timer = 99.0
	g.summon_t = 999.0   # (its bowmen checked on their own)
	g.necro_t = 0.0
	return g


func _upgraded(kind: String, at: Vector2, path: int, n: int):
	var w = await _hire(kind, at)
	main.selected = w
	for i in n:
		main.upgrade_selected(path)
	main.selected = null
	return w


func _necro() -> void:
	# The plain case: a fallen Knight raised, corrupted, fighting for the horde.
	await _fresh()
	var k = await _hire("swordsman", Vector2(320, 400))
	var hp: float = k.max_hp
	var dmg: float = k.damage
	await _kill(k)
	check(main.fallen.size() == 1 and main.fallen[0]["kind"] == "swordsman", "N  a troop fallen for good lies there to be raised, for a while")
	var g = _binder(Vector2(320, 250))
	var c: Dictionary = g.necro["corrupt"]
	var t_plain: float = g.rite_time(main.fallen[0])
	var started := false
	var risen = null
	for f in 60 * 8:
		await process_frame
		if g.rite != null:
			started = true
		var cs: Array = main.get_enemies().filter(func(e): return e.corrupted)
		if not cs.is_empty():
			risen = cs[0]
			break
	check(started and risen != null, "N  a Gravebinder channels over it, and it rises corrupted (after %.1fs)" % t_plain)
	if risen == null:
		return
	check(risen.fallen_kind == "swordsman" and absf(risen.max_hp - hp * c["hp"]) < 0.5 and absf(risen.damage - dmg * c["damage"]) < 0.5,
			"N  ...still a Knight, weaker: %.0f of %.0f health, %.0f of %.0f damage" % [risen.max_hp, hp, risen.damage, dmg])
	check(main.fallen.is_empty(), "N  ...and its body's gone: it can't be raised twice")
	var foe_of = await _hire("swordsman", risen.position + Vector2(0, 40))
	var h0: float = foe_of.hp
	for f in 60 * 4:
		await process_frame
	check(foe_of.hp < h0, "N  ...it fights your troops")
	# Upgrades kept: an Archer with its Volley comes back shooting volleys; the time to raise
	# it grows with what was spent on it.
	await _fresh()
	var a = await _upgraded("archer", Vector2(320, 400), 2, 4)
	var tiers: Array = a.tiers.duplicate()
	var shots: int = a.multishot
	var spent: int = a.spent
	await _kill(a)
	g = _binder(Vector2(320, 250))
	var t_up: float = g.rite_time(main.fallen[0])
	check(t_up > t_plain + 2.0, "N  a well-upgraded troop takes longer to raise (%.1fs, %dg spent; a plain Knight %.1fs)" % [t_up, spent, t_plain])
	risen = null
	for f in 60 * 14:
		await process_frame
		var cs: Array = main.get_enemies().filter(func(e): return e.corrupted)
		if not cs.is_empty():
			risen = cs[0]
			break
	check(risen != null and risen.fallen_tiers == tiers and risen.volley == shots and shots > 1 and not risen.ranged.is_empty(),
			"N  ...raised, it keeps its upgrades (%s) and shoots as it did (volleys of %d)" % [str(tiers), shots])
	# A Storm Mage raised casts its chain lightning; a Healer mends the horde.
	await _fresh()
	var m = await _upgraded("mage", Vector2(250, 400), 0, 2)
	var h = await _hire("healer", Vector2(400, 400))
	await _kill(m)
	await _kill(h)
	g = _binder(Vector2(320, 260))
	g.necro["max_raised"] = 2
	for f in 60 * 20:
		await process_frame
		if main.get_enemies().filter(func(e): return e.corrupted).size() >= 2:
			break
	var cs2: Array = main.get_enemies().filter(func(e): return e.corrupted)
	var cm = cs2.filter(func(e): return e.fallen_kind == "mage")
	var ch = cs2.filter(func(e): return e.fallen_kind == "healer")
	check(not cm.is_empty() and cm[0].cast.get("spells", []) == ["lightning"], "N  a Storm Mage raised keeps its path: it casts chain lightning")
	var hurt = _foe("orc", Vector2(400, 200))
	hurt.root_timer = 99.0
	hurt.hp = hurt.max_hp * 0.3
	var hh: float = hurt.hp
	if not ch.is_empty():
		ch[0].position = hurt.position + Vector2(0, 40)
	for f in 60 * 4:
		await process_frame
	check(not ch.is_empty() and hurt.hp > hh, "N  a Healer raised mends the horde now")
	check(g.raised.size() <= int(g.necro["max_raised"]), "N  ...never more raised at once than it can hold")
	# One body, one Gravebinder; at most two raised at once; a stun breaks the rite off.
	await _fresh()
	var bodies := []
	for i in 3:
		var w = await _hire("swordsman", Vector2(260 + i * 60, 420))
		bodies.append(w)
	for w in bodies:
		await _kill(w)
	var g1 = _binder(Vector2(300, 260))
	var g2 = _binder(Vector2(340, 260))
	await _frames(3)
	check(g1.rite != null and g2.rite != null and g1.rite != g2.rite, "N  two Gravebinders never claim the same body")
	var was = g1.rite
	g1.apply_stun(1.0)
	await _frames(3)
	check(g1.rite == null and was["claimed"] == null and main.fallen.has(was), "N  a stun breaks the rite off; the body's left to be claimed again")
	g2.necro["max_raised"] = 1
	g2.take_damage(1e6)
	await _frames(3)
	check(main.fallen.all(func(r): return r["claimed"] == null or is_instance_valid(r["claimed"])), "N  killing one mid-rite leaves its body unclaimed")
	g1.necro_t = 0.0
	for f in 60 * 25:
		await process_frame
	check(g1.raised.size() <= 2, "N  ...and one never holds more than two raised (%d)" % g1.raised.size())
	# What can't be raised: the raised themselves, bowmen, emplacements; and the dead lie
	# only so long.
	var cs3: Array = main.get_enemies().filter(func(e): return e.corrupted)
	var n0: int = main.fallen.size()
	for e in cs3:
		e.take_damage(1e6)
	await _frames(3)
	check(main.fallen.size() == n0, "N  a raised troop, killed, leaves nothing to raise again")
	await _fresh()
	var cn = await _hire("cannon", Vector2(320, 450))
	main.permadeath = true
	cn.take_damage(1e6)
	await _frames(3)
	check(main.fallen.is_empty(), "N  a broken emplacement isn't a body to raise")
	var k2 = await _hire("swordsman", Vector2(320, 400))
	await _kill(k2)
	await _frames(int(60 * (main.FALLEN_KEEP + 1.0)))
	check(main.fallen.is_empty(), "N  the fallen lie only so long (%.0fs)" % main.FALLEN_KEEP)
	# Its bowmen: called up, never more than its limit.
	await _fresh()
	await _tough("swordsman", Vector2(320, 380))
	g = _foe("gravebinder", Vector2(320, 200))
	g.root_timer = 99.0
	g.summon_t = 0.0
	for f in 60 * 40:
		await process_frame
	var bows: int = main.get_enemies().filter(func(e): return e.kind == "skeleton_archer").size()
	check(g.minions.size() > 0 and g.minions.size() <= int(g.necro["summon_max"]) and bows <= int(g.necro["summon_max"]),
			"N  a Gravebinder calls up Skeleton Archers, never more than %d at once (%d)" % [g.necro["summon_max"], bows])


# --- I ---

func _integration() -> void:
	var M = load("res://scripts/main.gd")
	var CD = load("res://scripts/campaign_data.gd")
	# Classic: the new kinds come in a few at a time, after the old ones have all been met.
	var firsts := {}
	for k in M.NEW_FOES:
		firsts[k] = M.NEW_FOES[k]
	check(firsts.values().min() >= 8 and firsts.values().max() <= 13, "I  Classic: the new kinds join the waves one at a time, from wave 8 to 13 (%s)" % str(firsts))
	var by := {}
	for n in range(1, 31):
		for sq in M.squads_for(n):
			if not by.has(sq):
				by[sq] = n
	check(by.size() == Data.SQUADS.size() and by.values().min() >= 8 and by.get("Grave Procession", 0) >= 15,
			"I  ...the horde's squads march in from wave 8, the Gravebinders' from wave 16 (%s)" % str(by))
	check(range(1, 60).all(func(n): return M.squads_for(n).size() <= 3), "I  ...never more than three squads a wave")
	await _fresh()
	main.wave = 1
	var early: Array = main._build_wave(5)
	var late: Array = main._build_wave(16)
	var gp: Array = Data.SQUADS["Grave Procession"]["kinds"]
	var at: int = late.find("gravebinder")
	check(not early.any(func(k): return Data.SQUADS.values().any(func(q): return k in ["drummer", "shieldbearer", "ogre", "boltflinger", "warmage", "gravebinder"])),
			"I  ...early waves just as before: none of the new kinds")
	check(at > 0 and late[at - 2] == "skeleton_archer" and late[at - 1] == "skeleton_archer", "I  ...a squad marches together (its Gravebinder among its bowmen)")
	check(late.size() <= M.wave_size(16) + Data.ENEMIES.size(), "I  ...and squads take the place of others: the wave's no bigger for them (%d)" % late.size())
	# The campaign: no new kind before the Deepdelve and Stonehollow missions, none in the
	# first missions, and every kind it uses is a real one.
	var new_kinds := ["drummer", "shieldbearer", "ogre", "boltflinger", "warmage", "gravebinder"]
	var untouched := ["ashwatch", "stonehollow", "gw_exodus", "gw_watchfires", "gw_trail", "mv_wounded", "mv_sanctuary", "fm_pass", "fm_vigil", "fm_whiteout", "fc_council"]
	var bad := []
	for m in untouched:
		var txt := str(CD.MISSIONS[m])
		for k in new_kinds:
			if txt.contains('"%s"' % k):
				bad.append(m + ":" + k)
	check(bad.is_empty(), "I  the first missions, Greenwood, Mercy Vale, Frostmarch and the Council's Price meet none of the new kinds (%s)" % ", ".join(bad))
	var unknown := []
	for m in CD.MISSIONS:
		for n in CD.MISSIONS[m].get("squads", {}):
			for sq in CD.MISSIONS[m]["squads"][n]:
				if not Data.SQUADS.has(sq):
					unknown.append(m + ":" + sq)
	check(unknown.is_empty(), "I  every squad a mission sends is a real one")
	var where := {}
	for k in new_kinds:
		where[k] = []
		for m in CD.MISSIONS:
			var txt := str(CD.MISSIONS[m])
			var sq_kinds := []
			for n in CD.MISSIONS[m].get("squads", {}):
				for sq in CD.MISSIONS[m]["squads"][n]:
					sq_kinds.append_array(Data.SQUADS[sq]["kinds"])
			if txt.contains('"%s"' % k) or sq_kinds.has(k):
				where[k].append(m)
	check(new_kinds.all(func(k): return not where[k].is_empty()), "I  every new kind is met somewhere in the campaign (%s)" % str(where))
