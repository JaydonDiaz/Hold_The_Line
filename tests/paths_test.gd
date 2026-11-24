extends SceneTree
## The reworked upgrade paths. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/paths_test.gd [-- SECTIONS]
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.
##
## K  Knight Charge: Light Step's harder blow after a run; Vanguard's lunge (1.5x, a stagger,
##    5s apart); Spearhead's spear (seen, longer reach), bystanders speared for less, the same
##    surviving foe charged again from a short step back (in its area); Unstoppable Lancer's
##    3x, throw and stun, a boss still hurt but hardly stunned; prices kept
## A  Archer: Piercing Tips pierces (2 hits), Trick Shots doesn't; Seeker Arrows home without
##    piercing; Evasive Barrage only from a real dodge (3 arrows at 30%, 5 at Tier IV), not
##    from walking, not again within its cooldown, not while stunned
## M  Mage Spellblade: armour and haste totals (Tier IV replaces, doesn't add); the sword for
##    foes that come close, the staff at range, no flicking at the edge, no running in, no
##    backing off; sweeps 2 then 3; Fire, Storm and Lance carried in it (bounded); Necromancy gone
## F  Frost Witch Shattercraft: Brittle from bolts, broken by anyone's hit for 8 ice dmg, once
##    per 2s; icicles at the toughest Brittle foe; the spear through two; a Brittle kill
##    shatters; Avalanche spreads Brittle from a first shatter only (no endless chain)
## H  Healer Divine Retribution: a ward only for an ally at risk, soaking damage after armour,
##    no stacking; Holy Rebuke throws back a share of what it soaked, capped; Intercession wards
##    two and bursts when broken (not when it runs out); Guardian Angel stops one fatal blow a
##    minute, however many Healers
## T  Alchemist Trapcraft: charges set in the enemy's way standing still, never under a foe, up
##    to its limit, on its cooldown; Crippling Charges slow; a dodge leaves one only if one's ready
## P  Prices and the six-upgrade limit as they were; old saves' path picks land on the new paths

const Data = preload("res://scripts/data.gd")
const Defense = preload("res://scripts/defense.gd")
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
	root.get_node("Campaign").save_path = "user://paths_test.cfg"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		only = args[0]
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _on(s: String) -> bool:
	return only == "" or s in only


func _run() -> void:
	seed(12)
	if _on("K"):
		await _knight()
	if _on("A"):
		await _archer()
	if _on("M"):
		await _mage()
	if _on("F"):
		await _frost()
	if _on("H"):
		await _healer()
	if _on("T"):
		await _traps()
	if _on("P"):
		await _prices()
	if main != null:
		main.free()
	if FileAccess.file_exists("user://paths_test.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://paths_test.cfg"))
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


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


func _hire(kind: String, at: Vector2, tiers := [0, 0, 0, 0]):
	main.placing_type = kind
	main.hire_at(at)
	main.placing_type = ""
	main.selected = null
	var all: Array = main.get_warriors().filter(func(w): return w.kind == kind)
	var w = all[all.size() - 1]
	w.build_left = 0.0
	w.position = w.post
	w.tiers = tiers.duplicate()
	w._apply_upgrades()
	w.hp = w.max_hp
	return w


func _foe(kind: String, at: Vector2, hp := -1.0):
	main._spawn_enemy(kind, 1, at)
	var e = main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)
	if hp > 0.0:
		e.max_hp = hp
		e.hp = hp
	return e


func _damage_taken(e, frames: int) -> float:
	var hp0: float = e.hp
	await _frames(frames)
	return hp0 - e.hp if is_instance_valid(e) else hp0


# --- K ---

func _knight() -> void:
	var path: Array = Data.WARRIORS["swordsman"]["paths"][3]["tiers"]
	check(path.map(func(t): return t["cost"]) == [25, 40, 75, 140], "K  Charge keeps its prices (25/40/75/140)")
	await _fresh()
	var k0 = await _hire("swordsman", Vector2(320, 500))
	var base_speed: float = k0.move_speed
	var k2 = await _hire("swordsman", Vector2(200, 500), [0, 0, 0, 2])
	check(absf(k2.move_speed / base_speed - 1.2) < 0.01, "K  Light Step and Vanguard's Advance: +20%% move speed in all (x%.3f)" % (k2.move_speed / base_speed))
	# Light Step: a run, then a harder blow.
	await _fresh()
	var k1 = await _hire("swordsman", Vector2(440, 500), [0, 0, 0, 1])
	var dummy = _foe("orc", Vector2(440, 300), 99999.0)   # (not a Troll: its mending would muddle the count)
	dummy.speed = 0.0
	var first := -1.0
	var later := -1.0
	var hp_prev: float = dummy.hp
	for f in 60 * 5:
		await process_frame
		if dummy.hp < hp_prev - 0.5:
			var d: float = hp_prev - dummy.hp
			if first < 0.0:
				first = d
			elif later < 0.0:
				later = d
				break
		hp_prev = dummy.hp
	check(first > 0.0 and later > 0.0 and first > later * 1.15, "K  Light Step: after a run his first blow hits harder (%.1f, then %.1f)" % [first, later])
	dummy.queue_free()
	# Vanguard: a lunge at 1.5x, staggering; not again for 5s.
	await _fresh()
	var kv = await _hire("swordsman", Vector2(320, 560), [0, 0, 0, 2])
	var t = _foe("orc", Vector2(320, 380), 99999.0)
	t.speed = 0.0
	var dashes := 0
	var stunned := false
	var hp0: float = t.hp
	var hit_first := 0.0
	var was_dashing := false
	for f in 60 * 4:
		await process_frame
		if kv.dash_left > 0.0 and not was_dashing:
			dashes += 1
		was_dashing = kv.dash_left > 0.0
		if t.stun_timer > 0.0:
			stunned = true
			if hit_first == 0.0:
				hit_first = hp0 - t.hp
	check(dashes == 1 and stunned and absf(hit_first - kv.damage * 1.5) < 1.0,
			"K  Vanguard's Advance: one lunge in 4s (%d), 1.5x (%.1f of %.1f), the foe staggered" % [dashes, hit_first, kv.damage * 1.5])
	# Spearhead: the spear, longer reach, the same foe charged again after ~4s.
	await _fresh()
	var ks = await _hire("swordsman", Vector2(320, 560), [0, 0, 0, 3])
	var ksword = await _hire("swordsman", Vector2(200, 560), [2, 0, 0, 0])
	check(ks.attack_range > ksword.attack_range + 5.0 and ks.back_weapon() == "", "K  Spearhead: a spear in hand, reaching further (%.0f, a sword %.0f)" % [ks.attack_range, ksword.attack_range])
	var kmix = await _hire("swordsman", Vector2(440, 560), [3, 0, 0, 3])
	check(kmix.back_weapon() == "spear" and kmix.attack_range == ksword.attack_range, "K  ...with the axe too, the spear rides on his back (no extra reach) till he charges")
	var tr = _foe("troll", Vector2(320, 380), 99999.0)
	tr.speed = 0.0
	ks.move_mode = "guard"
	ks.guard_area = Rect2(220, 300, 200, 300)
	var starts := 0
	var steps := 0
	var spear_seen := false
	var worst := 0.0
	var was_dash := false
	var was_step := false
	for f in 60 * 11:
		await process_frame
		if ks.dash_left > 0.0 and not was_dash:
			starts += 1
		if ks.backstep_left > 0.0 and not was_step:
			steps += 1
		was_dash = ks.dash_left > 0.0
		was_step = ks.backstep_left > 0.0
		spear_seen = spear_seen or ks._lance_out()
		worst = maxf(worst, ks.rect_gap(ks.guard_area, ks.position))
	check(starts >= 2 and steps >= 1 and spear_seen, "K  ...a Troll that won't fall is charged again from a short step back (%d charges, %d steps back in 11s)" % [starts, steps])
	check(worst <= 4.0, "K  ...never out of his Guard Area for it (%.0fpx out at worst)" % worst)
	# Bystanders speared for less.
	await _fresh()
	var kb = await _hire("swordsman", Vector2(320, 600), [0, 0, 0, 3])
	var far = _foe("orc", Vector2(320, 400), 99999.0)
	var mid = _foe("goblin", Vector2(322, 500), 99999.0)
	far.speed = 0.0
	mid.speed = 0.0
	kb.target = far
	kb._start_dash(far)
	var hp_far: float = far.hp
	var hp_mid: float = mid.hp
	await _frames(20)
	var d_far: float = hp_far - far.hp
	var d_mid: float = hp_mid - mid.hp
	check(d_mid > 0.0 and d_mid < d_far, "K  ...anyone on the way is speared for less (%.0f, the target %.0f)" % [d_mid, d_far])
	# Lancer: 3x, thrown, stunned; a boss hurt but barely stunned.
	await _fresh()
	var kl = await _hire("swordsman", Vector2(320, 600), [0, 0, 0, 4])
	var o = _foe("orc", Vector2(320, 450), 99999.0)
	o.speed = 0.0
	kl.target = o
	var at0: Vector2 = o.position
	kl._start_dash(o)
	var hp_o: float = o.hp
	await _frames(15)
	check(absf((hp_o - o.hp) - kl.damage * 3.0) < 1.5 and o.position.distance_to(at0) > 10.0 and o.stun_timer > 0.3,
			"K  Unstoppable Lancer: 3x (%.0f), thrown back (%.0fpx), stunned" % [hp_o - o.hp, o.position.distance_to(at0)])
	var w = _foe("warlord", Vector2(200, 450), 99999.0)
	w.speed = 0.0
	kl.dash_left = 0.0
	kl.target = w
	kl._start_dash(w)
	var hp_w: float = w.hp
	await _frames(15)
	check(hp_w - w.hp > kl.damage * 2.5 and w.stun_timer < 0.6, "K  ...a Warlord still takes the charge (%.0f) but shrugs off most of the stun (%.2fs)" % [hp_w - w.hp, w.stun_timer])


# --- A ---

func _archer() -> void:
	await _fresh()
	var plain = await _hire("archer", Vector2(150, 600))
	var tips = await _hire("archer", Vector2(250, 600), [3, 0, 0, 0])
	var tricks = await _hire("archer", Vector2(350, 600), [0, 0, 0, 4])
	var seek = await _hire("archer", Vector2(450, 600), [0, 0, 0, 2])
	check(plain.pierce == 0 and tips.pierce == 1 and tricks.pierce == 0, "A  Piercing Tips: arrows hit 2 (pierce %d); Trick Shots pierces nothing (%d)" % [tips.pierce, tricks.pierce])
	check(seek.seek and seek.pierce == 0, "A  Seeker Arrows home in without piercing")
	var both = await _hire("archer", Vector2(550, 600), [3, 0, 0, 2])
	check(both.seek and both.pierce == 1, "A  ...with Piercing Tips, a pierced arrow seeks on (still 2 hits)")
	# Barrage: only from a real dodge.
	await _fresh()
	var a = await _hire("archer", Vector2(320, 560), [0, 0, 0, 1])
	a.hp = 9999.0
	a.max_hp = 9999.0
	for i in 3:
		_foe("goblin", Vector2(260 + i * 60, 470), 99999.0).speed = 0.0
	a.order_to(Vector2(200, 560))
	await _frames(60)
	check(a.barrage_t == 0.0 and a.barrage_left == 0, "A  Evasive Barrage: never from just walking about")
	# A dodge.
	a.ordered = false
	a.set_post(Vector2(320, 560))   # (back where she was: the walk moved her post)
	a.position = a.post
	a.cd_timer = 999.0   # (her ordinary arrows aside)
	var arrows := []
	var aims := {}
	main.fx_layer.child_entered_tree.connect(func(n):
		if n.get("style") == "arrow":
			arrows.append(n.damage)
			aims[n.target] = true)
	a._start_barrage()
	await _frames(30)
	var full: float = a.damage * a._power()
	var ok_dmg: bool = arrows.all(func(d): return absf(d - full * 0.3) < 0.01 or absf(d - full * 0.3 * a.crit_mult) < 0.01)
	check(arrows.size() >= 3 and ok_dmg and aims.size() == 3, "A  ...a dodge looses 3 arrows at 30%% each (%d, at %d different foes)" % [arrows.size(), aims.size()])
	# Through the real dodge path: a wyvern's run, twice in a row.
	await _fresh()
	var b = await _hire("archer", Vector2(320, 330), [0, 0, 0, 4])
	b.hp = 9999.0
	b.max_hp = 9999.0
	for i in 5:
		_foe("goblin", Vector2(160 + i * 80, 200), 99999.0).speed = 0.0
	var y = _foe("wyvern", Vector2(320, 110), 99999.0)
	y.strafe_timer = 0.0
	var fired := []
	main.fx_layer.child_entered_tree.connect(func(n): fired.append([Engine.get_process_frames(), n]))
	var barrages := 0
	var was := 0
	for f in 60 * 5:
		await process_frame
		y.breath_timer = 999.0
		if y.strafe_timer > 2.0:
			y.strafe_timer = 2.0
		if b.barrage_left > 0 and was == 0:
			barrages += 1
		was = b.barrage_left
	var dodges: int = Defense.stats.get("archer", {}).get("evade", 0)
	check(barrages >= 1 and barrages <= 1 + int(5.0 / 7.0), "A  Master of Tricks: a barrage on a dodge, not again within 7s (%d barrages, %d dodges in 5s)" % [barrages, dodges])
	# Stunned: no barrage.
	b.dazed = 5.0
	b.barrage_t = 0.0
	b.barrage_left = 0
	await _frames(30)
	check(b.barrage_left == 0, "A  ...and none while stunned")


func _arrows() -> int:
	return main.fx_layer.get_children().size()


# --- M ---

func _mage() -> void:
	var path: Array = Data.WARRIORS["mage"]["paths"][3]["tiers"]
	check(path[0]["name"] == "Mage Armor" and path.map(func(t): return t["cost"]) == [70, 100, 170, 285], "M  Spellblade replaces Necromancy at its prices (70/100/170/285)")
	check(not str(Data.WARRIORS["mage"]["paths"]).contains("summon"), "M  ...and no path raises skeletons any more")
	await _fresh()
	var m0 = await _hire("mage", Vector2(150, 600))
	var m2 = await _hire("mage", Vector2(250, 600), [0, 0, 0, 2])
	var m4 = await _hire("mage", Vector2(350, 600), [0, 0, 0, 4])
	check(absf(m2.max_hp / m0.max_hp - 1.55) < 0.01 and absf(m2.armor - 0.15) < 0.005 and absf(m2.move_speed / m0.move_speed - 1.2) < 0.01 and absf(m0.cooldown / m2.cooldown - 1.0 / 0.87) < 0.01,
			"M  Armor and Haste: +55%% health, 15%% less damage, +20%% speed, 15%% faster (x%.2f hp, %.0f%%)" % [m2.max_hp / m0.max_hp, m2.armor * 100])
	check(absf(m4.max_hp / m0.max_hp - 2.1) < 0.02 and absf(m4.armor - 0.25) < 0.005 and absf(m4.move_speed / m0.move_speed - 1.35) < 0.01 and absf(m0.cooldown / m4.cooldown - 1.25) < 0.01 and absf(m4.haste - 0.8) < 0.001,
			"M  Archmage's Blade: totals of +110%% health, 25%% less damage, +35%% speed, 25%% faster (x%.2f, %.0f%%, x%.2f, x%.2f)" % [m4.max_hp / m0.max_hp, m4.armor * 100, m4.move_speed / m0.move_speed, m0.cooldown / m4.cooldown])
	check(m4.max_hp >= m4.hp and m4.hp == m4.max_hp, "M  ...health brought up to the new most when bought")
	# The sword: close foes only.
	await _fresh()
	var m = await _hire("mage", Vector2(320, 560), [0, 0, 0, 3])
	_tough(m)
	var far = _foe("orc", Vector2(320, 460), 99999.0)
	far.speed = 0.0
	await _frames(90)
	check(not m.blade_on and m.position.distance_to(m.post) < 5.0, "M  a foe at range: the staff, as before (she doesn't run in to use the sword)")
	var near = _foe("orc", Vector2(345, 528), 99999.0)
	var near2 = _foe("goblin", Vector2(296, 530), 99999.0)
	var near3 = _foe("goblin", Vector2(320, 520), 99999.0)
	for e in [near, near2, near3]:
		e.speed = 0.0
	var h1: float = near.hp
	var h2: float = near2.hp
	var h3: float = near3.hp
	var pos0: Vector2 = m.position
	await _frames(70)
	var swept: int = [near.hp < h1, near2.hp < h2, near3.hp < h3].count(true)
	check(m.blade_on and swept == 2 and m.position.distance_to(pos0) < 6.0, "M  Arcane Edge: foes close in, the sword sweeps 2 of them (%d), and she stands her ground" % swept)
	# The edge: no flicking.
	var flips := 0
	var was: bool = m.blade_on
	for f in 60:
		near.position.x = 345.0 + 6.0 * sin(f * 0.5)
		await process_frame
		if m.blade_on != was:
			flips += 1
		was = m.blade_on
	check(flips == 0, "M  ...a foe shuffling at the edge doesn't flick it between sword and staff (%d)" % flips)
	# Fire, Storm, Lance through the sword.
	await _fresh()
	var mf = await _hire("mage", Vector2(320, 560), [0, 0, 2, 4])
	_tough(mf)
	var g = _foe("troll", Vector2(330, 525), 99999.0)
	g.speed = 0.0
	mf.breath = {}   # (her own breath aside: the sword's fire is what's checked)
	mf.breath = Data.WARRIORS["mage"]["paths"][2]["tiers"][1]["effect"]["breath"]
	mf.breath_timer = 999.0
	await _frames(80)
	check(g.burn_timer > 0.0 and g.burn_dps <= float(mf.breath["burn_dps"]) + 0.01, "M  Spellblade IV + Fire II: the sword sets them burning, at the Fire path's burn (%.0f/s), no stacking" % g.burn_dps)
	await _fresh()
	var ms = await _hire("mage", Vector2(320, 560), [2, 0, 0, 4])
	_tough(ms)
	ms.chain_timer = 999.0
	var s1 = _foe("troll", Vector2(330, 525), 99999.0)
	var s2 = _foe("goblin", Vector2(390, 500), 99999.0)
	for e in [s1, s2]:
		e.speed = 0.0
	var h_s2: float = s2.hp
	await _frames(60 * 4)
	check(s2.hp < h_s2 and ms.blade_storm_t > 0.0, "M  Spellblade IV + Storm II: a short chain leaps from the blow, on its own cooldown")
	await _fresh()
	var ml = await _hire("mage", Vector2(320, 560), [0, 2, 0, 4])
	_tough(ml)
	ml.lance_timer = 999.0
	var l1 = _foe("troll", Vector2(330, 525), 999999.0)
	l1.speed = 0.0
	var hl: float = l1.hp
	await _frames(60 * 6)
	var per_s: float = (hl - l1.hp) / 6.0
	var sword_only: float = float(ml.blade["damage"]) * ml._power() / (float(ml.blade["every"]) * ml.haste / ml._rate())
	var lance_share: float = float(ml.lance["damage"]) * ml.BLADE_LANCE_SHARE / (ml.BLADE_LANCE_CD * ml.haste)
	check(per_s > sword_only * 1.1 and per_s < (sword_only + lance_share) * 1.3, "M  Spellblade IV + Lance II: focused bolts through the sword now and then, bounded (%.0f dmg/s; sword %.0f, +lance %.0f)" % [per_s, sword_only, lance_share])
	await _fresh()
	var mfire = await _hire("mage", Vector2(320, 560), [0, 0, 4, 2])
	check(mfire.blade.is_empty() and not mfire.breath.is_empty() and mfire.haste < 1.0, "M  Spellblade II + Fire IV: Haste on her breath and blasts, no sword")


func _tough(w, hp := 9999.0) -> void:
	w.max_hp = hp
	w.hp = hp


# --- F ---

func _frost() -> void:
	var path: Array = Data.WARRIORS["frost"]["paths"][3]["tiers"]
	check(path[0]["name"] == "Brittle Ice" and path.map(func(t): return t["cost"]) == [35, 55, 95, 155], "F  Shattercraft replaces Frost Aura at its prices (35/55/95/155)")
	await _fresh()
	var f = await _hire("frost", Vector2(320, 560), [0, 0, 0, 1])
	var e = _foe("troll", Vector2(320, 440), 99999.0)
	e.speed = 0.0
	for i in 120:
		await process_frame
		if e.brittle_t > 0.0:
			break
	check(e.brittle_t > 0.0, "F  Brittle Ice: her bolts make a foe Brittle")
	f.queue_free()
	await process_frame
	var hp0: float = e.hp
	e.take_damage(10.0)
	var first: float = hp0 - e.hp
	hp0 = e.hp
	e.take_damage(10.0)
	var second: float = hp0 - e.hp
	check(absf(first - 18.0) < 0.5 and absf(second - 10.0) < 0.5 and e.brittle_t == 0.0, "F  ...anyone's next hit breaks it for 8 more ice dmg (%.0f, then %.0f)" % [first, second])
	e.apply_brittle(Data.WARRIORS["frost"]["paths"][3]["tiers"][0]["effect"]["brittle"], {}, 0, "")
	check(e.brittle_t == 0.0, "F  ...and it can't be Brittle again for 2s")
	e.burn_timer = 0.0
	# Shards and spears.
	await _fresh()
	var fs = await _hire("frost", Vector2(320, 600), [0, 0, 0, 2])
	var weak = _foe("goblin", Vector2(260, 480), 99999.0)
	var tough = _foe("troll", Vector2(380, 480), 50000.0)
	for x in [weak, tough]:
		x.speed = 0.0
	tough.brittle_t = 4.0
	tough.brittle_fx = fs.brittle
	fs.shard_t = 0.0
	var shot := []
	main.fx_layer.child_entered_tree.connect(func(n): shot.append(n))
	await _frames(3)
	var icicles: Array = shot.filter(func(n): return n.get("style") == "icicle")
	check(icicles.size() == 1 and icicles[0].target == tough and absf(icicles[0].damage - 18.0 * fs._power()) < 0.5, "F  Razor Shards: an icicle (18) at the toughest Brittle foe in reach")
	await _fresh()
	var fp = await _hire("frost", Vector2(320, 600), [0, 0, 0, 3])
	var a1 = _foe("orc", Vector2(320, 520), 199999.0)   # (the toughest, nearest: the spear's aimed at it)
	var a2 = _foe("orc", Vector2(320, 480), 99999.0)
	var a3 = _foe("orc", Vector2(320, 440), 99999.0)
	for x in [a1, a2, a3]:
		x.speed = 0.0
	fp.cd_timer = 999.0
	var hs := [a1.hp, a2.hp, a3.hp]
	fp.shard_t = 0.0
	await _frames(40)
	var struck: int = [a1.hp < hs[0], a2.hp < hs[1], a3.hp < hs[2]].count(true)
	check(struck == 2, "F  Glacial Spear: through two foes, not three (%d)" % struck)
	# Shatter, and Avalanche's spread: bounded.
	await _fresh()
	var fa = await _hire("frost", Vector2(320, 640), [0, 0, 0, 4])
	fa.cd_timer = 999.0
	fa.shard_t = 999.0
	var swarm := []
	for i in 30:
		var x = _foe("goblin", Vector2(200 + (i % 6) * 40, 300 + (i / 6) * 30), 25.0)
		x.speed = 0.0
		swarm.append(x)
	var head = swarm[14]
	head.apply_brittle(fa.brittle, fa.shatter, 0, "frost")
	head.take_damage(9999.0)
	await _frames(20)
	var dead: int = swarm.filter(func(x): return not is_instance_valid(x) or x.dead).size()
	check(dead >= 2 and dead < 30, "F  Avalanche on a Brittle swarm: shatters chain on, but stop (%d of 30 fell)" % dead)
	await _fresh()
	var fb = await _hire("frost", Vector2(320, 640), [0, 0, 0, 4])
	var ring := []
	var center = _foe("goblin", Vector2(320, 300), 10.0)
	for i in 6:
		var x = _foe("goblin", Vector2(320, 300) + Vector2.from_angle(i * TAU / 6.0) * 50.0, 99999.0)
		x.speed = 0.0
		ring.append(x)
	center.apply_brittle(fb.brittle, fb.shatter, 0, "frost")
	center.take_damage(9999.0)
	await _frames(5)
	var marked: int = ring.filter(func(x): return x.brittle_t > 0.0).size()
	var hurt: int = ring.filter(func(x): return x.hp < 99999.0).size()
	check(marked == 3 and hurt == 6, "F  ...a first shatter hurts all round it (%d of 6) and makes 3 Brittle (%d)" % [hurt, marked])
	for x in ring:
		if x.brittle_t > 0.0:
			x.hp = 1.0
			x.take_damage(5.0)
	await _frames(5)
	var marked2: int = ring.filter(func(x): return is_instance_valid(x) and not x.dead and x.brittle_t > 0.0 and x.brittle_gen == 1).size()
	var gen0: int = ring.filter(func(x): return is_instance_valid(x) and not x.dead and x.brittle_t > 0.0 and x.brittle_gen == 0).size()
	check(gen0 == 0, "F  ...and those shatter in turn but spread no more Brittle (%d newly marked)" % marked2)


# --- H ---

func _healer() -> void:
	var path: Array = Data.WARRIORS["healer"]["paths"][3]["tiers"]
	check(path[0]["name"] == "Divine Ward" and path.map(func(t): return t["cost"]) == [40, 60, 110, 190], "H  Divine Retribution replaces Halo at its prices (40/60/110/190)")
	await _fresh()
	var h = await _hire("healer", Vector2(320, 600), [0, 0, 0, 1])
	var k = await _hire("swordsman", Vector2(320, 540))
	h.ward_t = 0.0
	await _frames(30)
	check(k.shield_hp == 0.0, "H  Divine Ward: nobody at risk, no ward")
	var o = _foe("ogre", Vector2(320, 490), 99999.0)
	o.speed = 0.0
	o.lunge_dir = Vector2.DOWN
	o.slam_wind = 0.7
	o._new_windup()
	k.reacts = false
	await _frames(30)
	check(k.shield_hp > 0.0 and absf(k.shield_max - 30.0 * h._power()) < 0.5, "H  ...an Ogre's slam coming: the Knight it's aimed at gets a ward (%.0f)" % k.shield_hp)
	var hp0: float = k.hp
	k.shield_hp = 30.0
	k.take_damage(20.0)
	check(k.hp == hp0 and absf(k.shield_hp - 10.0) < 0.01, "H  ...it soaks up what gets past armour (%.0f left)" % k.shield_hp)
	k.shield_hp = 50.0
	k.shield_left = 4.0
	k.give_ward(30.0, 5.0, h.ward)
	check(k.shield_hp == 50.0, "H  ...wards don't stack: a weaker one doesn't replace a fresh, stronger one")
	# Rebuke: 30% of what's soaked, capped at 15.
	await _fresh()
	var h2 = await _hire("healer", Vector2(320, 600), [0, 0, 0, 2])
	var k2 = await _hire("swordsman", Vector2(320, 540))
	var foe = _foe("orc", Vector2(320, 500), 99999.0)
	foe.speed = 0.0
	k2.give_ward(100.0, 5.0, h2.ward)   # (a big one, to see the cap)
	var fhp: float = foe.hp
	main.hurt_by = foe
	k2.take_damage(20.0)
	main.hurt_by = null
	var back1: float = fhp - foe.hp
	fhp = foe.hp
	main.hurt_by = foe
	k2.take_damage(100.0)
	main.hurt_by = null
	var back2: float = fhp - foe.hp
	check(absf(back1 - 6.0) < 0.3 and absf(back1 + back2 - 15.0) < 0.3, "H  Holy Rebuke: 30%% of what it soaks goes back (%.1f of 20), 15 at most a ward (%.1f in all)" % [back1, back1 + back2])
	# Intercession: two at once, a burst when broken (not when run out).
	await _fresh()
	var h3 = await _hire("healer", Vector2(320, 640), [0, 0, 0, 3])
	var ka = await _hire("swordsman", Vector2(280, 560))
	var kb = await _hire("swordsman", Vector2(360, 560))
	for x in [ka, kb]:
		x.hp = x.max_hp * 0.5
		x.danger_t = 2.0
		x.reacts = false
	h3.ward_t = 0.0
	await _frames(3)
	check(ka.shield_hp > 0.0 and kb.shield_hp > 0.0 and h3.ward_t > 10.0, "H  Intercession: two hurt allies warded at once, on the one cooldown")
	var near = _foe("bat", ka.position + Vector2(0, -30), 99999.0)   # (a flyer: the Knights can't hit it themselves)
	near.speed = 0.0
	var gh: float = near.hp
	kb.shield_left = 0.01
	await _frames(3)
	var after_expiry: float = gh - near.hp
	gh = near.hp
	ka.take_damage(500.0)
	check(after_expiry < 0.01 and gh - near.hp >= 14.0, "H  ...a ward broken by a blow bursts (%.0f), one run out doesn't" % (gh - near.hp))
	# Guardian Angel.
	await _fresh()
	var h4 = await _hire("healer", Vector2(260, 640), [0, 0, 0, 4])
	var h5 = await _hire("healer", Vector2(380, 640), [0, 0, 0, 4])
	var kc = await _hire("swordsman", Vector2(320, 560))
	kc.give_ward(10.0, 5.0, h4.ward)
	kc.take_damage(9999.0)
	var saved: bool = kc.is_active() and kc.hp == 1.0
	kc.give_ward(10.0, 5.0, h5.ward)
	kc.take_damage(9999.0)
	check(saved and not kc.is_active(), "H  Guardian Angel: a warded ally's fatal blow leaves it at 1 HP, once a minute (another Healer's ward doesn't save it again)")


# --- T ---

func _traps() -> void:
	await _fresh()
	var al = await _hire("alchemist", Vector2(320, 600), [0, 0, 0, 2])
	al.move_mode = "hold"
	al.cd_timer = 999.0
	for i in 5:
		var e = _foe("goblin", Vector2(200 + i * 60, 150), 99999.0)
	var laid := {}
	var under := 0
	var moved := 0.0
	for f in 60 * 12:
		await process_frame
		al.cd_timer = 999.0
		moved = maxf(moved, al.position.distance_to(al.post))
		for t in al.my_traps:
			if is_instance_valid(t) and not laid.has(t.get_instance_id()):
				laid[t.get_instance_id()] = true
				for e in main.get_enemies():
					if e.position.distance_to(t.position) < e.radius + 10.0:
						under += 1
	check(laid.size() >= 2 and moved < 3.0, "T  Trapcraft: standing at its post, it sets charges in the enemy's way (%d in 12s)" % laid.size())
	check(under == 0, "T  ...never right under a foe")
	check(al.my_traps.size() <= int(al.traps["max"]) and laid.size() <= int(12.0 / float(al.traps["every"])) + 2,
			"T  ...no more than its limit (%d down of %d) or its cooldown allows" % [al.my_traps.size(), int(al.traps["max"])])
	var slow_e = _foe("orc", Vector2(100, 400), 99999.0)
	var t = preload("res://scripts/trap.gd").new()
	t.main = main
	t.slow = al.traps["slow"]
	t.radius = 40.0
	t.damage = 1.0
	t.position = slow_e.position
	main.add_projectile(t)
	t._explode()
	check(slow_e.slow_timer > 2.0 and slow_e.slow_factor < 0.7, "T  Crippling Charges: the blast slows what it catches 35%")
	# A dodge leaves one only when one's ready.
	al.trap_timer = 2.0
	var n0: int = al.my_traps.size()
	al._trap_behind()
	var n1: int = al.my_traps.filter(func(x): return is_instance_valid(x) and not x.is_queued_for_deletion()).size()
	check(n1 == n0, "T  ...a dodge with the cooldown still running leaves nothing behind")


# --- P ---

func _prices() -> void:
	var want := {"swordsman": [25, 40, 75, 140], "archer": [35, 55, 100, 175], "mage": [70, 100, 170, 285],
			"frost": [35, 55, 95, 155], "healer": [40, 60, 110, 190], "alchemist": [40, 65, 115, 200]}
	var ok := true
	for k in want:
		var path: Array = Data.WARRIORS[k]["paths"][3]["tiers"]
		ok = ok and path.map(func(t): return t["cost"]) == want[k]
	check(ok, "P  the reworked paths keep their prices")
	check(Data.WARRIORS["archer"]["paths"][0]["tiers"].map(func(t): return t["cost"]) == [30, 50, 90, 160], "P  ...the Archer's Damage path too")
	await _fresh()
	var m = await _hire("mage", Vector2(320, 600), [2, 0, 0, 3])
	check(m.total_upgrades() == 5 and m.upgrade_cost(3) > 0, "P  the six-upgrade limit is as it was")
	m.upgrade(3)
	check(m.total_upgrades() == 6 and m.path_state(0) == "full", "P  ...six bought, nothing more on offer")
	check(m.summon.is_empty() and m.decay.is_empty() and not m.blade.is_empty(), "P  an old save's Mage with Necromancy picks comes back with Spellblade's (no skeletons)")
