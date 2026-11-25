extends SceneTree
## The Pikeman and the Elven Assassin. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/newunits_test.gd [-- SECTIONS]
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.
##
## P  Pikeman: his stats; Readied Pike on a foe charging in (not one already at him), weaker
##    with a foe inside his point; Set Spears 1.6x and a slow; Hedge of Points catches two;
##    Hold Fast only while braced; No Passage pins, but not again for a while (two Pikemen
##    don't keep one pinned); Deep Thrust stacks and runs out; Impaling Strike every fourth;
##    Giantkiller's share capped; Phalanx: the second rank reaches past a Knight, thrusts when
##    he strikes, steadies him; Hook & Shove: the haft, the hook, Defender's Reach, the sweep
## A  Assassin: his stats; goes for the Horde Mage behind the goblins; the Opportunist's cut on
##    a busy foe; Backstab only after a rest and on an unwary foe; Chain Assassination on two
##    goblins, stopping when one lives; Silent Reaper's three, and the weak falter; Sabotage:
##    a slam set back, a kunai at a Boltflinger, a Horde Mage's spell broken off, Blackout (a
##    Warlord less; two Assassins don't stack it); Stealth: unseen further off, smoke when
##    surrounded (foes lose him, two go after the decoy), the smoke's re-ambush; Execution:
##    the wounded, Relentless Cuts, Deathblow (less on a boss), Killing Momentum
## C  Campaign: the Pikeman from the start, the Assassin with the Woodland Watch (and one fights
##    beside you in The Forest Exodus)
## F  Formations: in a Shield Wall, Pikemen stand in the second rank, in reach past the Knights
## B  The brief's mixed builds: each fights a mixed wave without a hitch

const Data = preload("res://scripts/data/data.gd")
const CD = preload("res://scripts/data/campaign_data.gd")
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
	root.get_node("Campaign").save_path = "user://newunits_test.cfg"
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
	seed(5)
	if _on("P"):
		await _pikeman()
	if _on("A"):
		await _assassin()
	if _on("C"):
		await _campaign()
	if _on("F"):
		await _formation()
	if _on("B"):
		await _builds()
	if main != null:
		main.free()
	if FileAccess.file_exists("user://newunits_test.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://newunits_test.cfg"))
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
	main.setup.choose_mode("normal")
	main.gold = 99999
	main.deploying = false
	main.wave_active = true
	await process_frame


func _hire(kind: String, at: Vector2, tiers := [0, 0, 0, 0]):
	main.placing_type = kind
	main.hiring.hire_at(at)
	main.placing_type = ""
	main.selected = null
	var all: Array = main.battlefield.get_warriors().filter(func(w): return w.kind == kind)
	var w = all[all.size() - 1]
	w.build_left = 0.0
	w.position = w.post
	w.tiers = tiers.duplicate()
	w._apply_upgrades()
	w.hp = w.max_hp
	return w


func _foe(kind: String, at: Vector2, hp := -1.0):
	main.waves._spawn_enemy(kind, 1, at)
	var e = main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)
	if hp > 0.0:
		e.max_hp = hp
		e.hp = hp
	return e


## The first blow `e` takes in `secs` (0: none).
func _first_blow(e, secs := 4.0) -> float:
	var hp0: float = e.hp
	for f in int(secs * 60):
		await process_frame
		if not is_instance_valid(e) or e.hp < hp0 - 0.01:
			return hp0 - (e.hp if is_instance_valid(e) else 0.0)
	return 0.0


# --- P ---

func _pikeman() -> void:
	var d: Dictionary = Data.WARRIORS["pikeman"]
	var kn: Dictionary = Data.WARRIORS["swordsman"]
	check(d["cost"] == 60 and d["hp"] == 100.0 and d["damage"] == 14.0 and d["cooldown"] == 0.8 and d["range"] > kn["range"] * 2.0 and d["speed"] < kn["speed"] and d["damage"] / d["cooldown"] < kn["damage"] / kn["cooldown"] and d["hp"] < kn["hp"],
			"P  the Pikeman: 60 gold, 100 health, 14 damage every 0.8s (less than a Knight in a brawl), a long reach (%.1f ft), a little slower" % (d["range"] / 10.0))
	check(d["paths"].size() == 4 and d["paths"].all(func(p): return p["tiers"].size() == 4)
			and d["paths"].map(func(p): return p["tiers"].map(func(t): return t["cost"])) == [[25, 40, 75, 140], [30, 50, 85, 150], [30, 45, 80, 145], [25, 45, 80, 145]],
			"P  four paths of four (Spearwall, Impaler, Phalanx, Hook & Shove) at their prices")
	# Readied Pike: a goblin charging in.
	await _fresh()
	var p = await _hire("pikeman", Vector2(320, 520))
	p.move_mode = "hold"
	p.facing = Vector2.UP
	var g = _foe("goblin", Vector2(320, 360), 9999.0)
	var first: float = await _first_blow(g)
	check(absf(first - 14.0 * 1.25) < 0.6, "P  Readied Pike: his first thrust at a goblin charging in hits 25%% harder (%.1f)" % first)
	var second: float = await _first_blow(g)
	check(second > 0.0 and second < first * 0.95, "P  ...not the next, at a foe already on him (%.1f)" % second)
	g.position = p.position + Vector2(0, -(p.RADIUS + g.radius + 2.0))
	g.speed = 0.0
	p.cd_timer = 0.0
	var close: float = await _first_blow(g)
	check(close > 0.0 and close < 14.0 * 0.9, "P  ...and a foe right inside his point: weaker thrusts (%.1f)" % close)
	# Set Spears, Hedge of Points: two goblins charging in side by side, both in reach.
	await _fresh()
	var sp = await _hire("pikeman", Vector2(320, 520), [2, 0, 0, 0])
	sp.facing = Vector2.UP
	sp.still_t = 1.0
	var g1 = _foe("goblin", Vector2(306, 450), 9999.0)
	var g2 = _foe("goblin", Vector2(338, 456), 9999.0)
	for gg in [g1, g2]:
		gg.walking = true
		gg.heading = gg.position.direction_to(sp.position)
	await process_frame
	sp.still_t = 1.0
	for gg in [g1, g2]:
		gg.walking = true
		gg.heading = gg.position.direction_to(sp.position)
	var h1: float = g1.hp
	var h2: float = g2.hp
	var main_hit: float = sp._pike_hit(g1, 11.0)
	var d2: float = h2 - g2.hp
	check(absf(main_hit - 11.0 * 1.6) < 0.01 and absf(d2 - 11.0 * 1.6 * 0.7) < 0.6 and g1.slow_timer > 0.0 and g2.slow_timer > 0.0,
			"P  Set Spears 1.6x and Hedge of Points: two charging goblins caught (%.1f, %.1f), both slowed" % [main_hit, d2])
	var again: float = sp._pike_hit(g1, 11.0)
	check(absf(again - 11.0) < 0.01, "P  ...not the same foe again straight after (%.1f)" % again)
	# Hold Fast: only while braced.
	await _fresh()
	var hf = await _hire("pikeman", Vector2(320, 520), [3, 0, 0, 0])
	var orc = _foe("orc", hf.position + Vector2(0, -60), 9999.0)
	hf.facing = Vector2.UP
	hf.still_t = 1.0
	main.hurt_by = orc
	var hp0: float = hf.hp
	hf.take_damage(20.0)
	var braced: float = hp0 - hf.hp
	hf.still_t = 0.0
	hp0 = hf.hp
	hf.take_damage(20.0)
	main.hurt_by = null
	var loose: float = hp0 - hf.hp
	check(absf(braced - 16.0) < 0.1 and absf(loose - 20.0) < 0.1, "P  Hold Fast: 20%% less from a blow in front while braced (%.0f), none when not (%.0f)" % [braced, loose])
	# No Passage: pinned, not again for a while.
	var w = _foe("wolf", Vector2(100, 200), 9999.0)
	w.pin(0.8)
	var pinned: bool = w.root_timer > 0.5
	w.root_timer = 0.0
	w.pin(0.8)
	check(pinned and w.root_timer == 0.0, "P  No Passage: a foe's pinned, then not again for a while (whoever's pike)")
	var tr = _foe("troll", Vector2(200, 200), 9999.0)
	tr.pin(0.8)
	check(tr.root_timer == 0.0 and tr.slow_timer > 0.0, "P  ...a big one isn't pinned, just slowed")
	# Impaler.
	await _fresh()
	var im = await _hire("pikeman", Vector2(320, 520), [0, 4, 0, 0])
	im.move_mode = "hold"
	var dummy = _foe("troll", Vector2(320, 520 - 58), 99999.0)   # (well inside his reach, not right inside his point)
	dummy.speed = 0.0
	dummy.regen = {}
	var blows := []
	var prev: float = dummy.hp
	for f in 60 * 5:
		await process_frame
		if dummy.hp < prev - 0.01:
			blows.append(prev - dummy.hp)
		prev = dummy.hp
	var base: float = 14.0 * 1.1
	var fourth: float = blows[3] if blows.size() >= 4 else 0.0
	var want4: float = base * 1.15 * 2.5 + 40.0   # (puncture at 3 deep by then: 15%; 2% of 99999 capped at 40)
	check(blows.size() >= 5 and blows[1] > blows[0] and absf(fourth - want4) < 1.5,
			"P  Impaler: Puncture deepens each thrust (%.1f, %.1f), the fourth a Giantkiller: 2.5x + 2%% capped at 40 (%.1f, want %.1f)" % [blows[0], blows[1] if blows.size() > 1 else 0.0, fourth, want4])
	im.punct_t = 0.0
	im.seq_t = 0.0
	await _frames(1)
	check(im.punct_t == 0.0 or im.punct_n >= 1, "P  ...and Puncture runs out after a while without a thrust")
	# Phalanx: behind a Knight.
	await _fresh()
	var k = await _hire("swordsman", Vector2(320, 480))
	var ph = await _hire("pikeman", Vector2(320, 510), [0, 0, 4, 0])
	k.move_mode = "hold"
	ph.move_mode = "hold"
	ph.facing = Vector2.UP
	var o2 = _foe("orc", Vector2(320, 448), 99999.0)   # (at the Knight: in his reach, and in the Pikeman's past him)
	o2.speed = 0.0
	await _frames(60 * 3)
	check(ph.backed and ph.attack_range > ph.pike_range, "P  Overlapping Spears: behind a Knight he reaches further (%.0f, %.0f)" % [ph.attack_range, ph.pike_range])
	var helped: int = 0
	var was: float = ph.support_t
	for f in 60 * 4:
		await process_frame
		if ph.support_t > was + 0.5:
			helped += 1
		was = ph.support_t
	check(helped >= 1 and ph.position.distance_to(ph.post) < 6.0, "P  Second Rank: he thrusts as the Knight strikes (%d in 4s), from where he stands" % helped)
	var from: Vector2 = k.position
	k.shove(Vector2(50, 0), 0.0)
	await _frames(15)
	check(k.position.distance_to(from) < 45.0, "P  Unbroken Line: the Knight he backs is thrown 20%% less (%.0fpx)" % k.position.distance_to(from))
	# Hook & Shove.
	await _fresh()
	var hs = await _hire("pikeman", Vector2(320, 500), [0, 0, 0, 4])
	var archer = await _hire("archer", Vector2(320, 560))
	hs.move_mode = "hold"
	var inside = _foe("orc", hs.position + Vector2(0, -(hs.RADIUS + 14.0 + 3.0)), 99999.0)
	inside.speed = 0.0
	var at0: Vector2 = inside.position
	await _frames(20)
	check(inside.position.distance_to(at0) > 8.0 and inside.slow_timer > 0.0, "P  Haft Check: a foe right inside his reach is jabbed back (%.0fpx) and slowed" % inside.position.distance_to(at0))
	var past = _foe("wolf", Vector2(355, 470), 99999.0)
	var hp_w: float = past.hp
	for f in 60 * 2:
		await process_frame
	check(past.hp < hp_w and past.position.distance_to(archer.position) > 40.0, "P  Defender's Reach / the hook: a wolf going for the Archer behind him is stopped short (%.0fpx off her)" % past.position.distance_to(archer.position))
	var sw: float = hs.sweep_t
	check(sw > 0.0 or hs.defend_t > 0.0 or hs.hook_t > 0.0, "P  ...his moves on their cooldowns")


# --- A ---

func _assassin() -> void:
	var d: Dictionary = Data.WARRIORS["assassin"]
	var kd: Dictionary = Data.WARRIORS["swordsman"]
	check(d["cost"] == 105 and d["hp"] == 60.0 and d["hp"] < kd["hp"] and d["damage"] / d["cooldown"] > kd["damage"] / kd["cooldown"] * 1.5 and absf(d["speed"] / kd["speed"] - 1.25) < 0.02,
			"A  the Assassin: a glass cannon (105 gold, 60 health, %.0f damage every %.2fs), 25%% quicker than a Knight" % [d["damage"], d["cooldown"]])
	check(d["paths"].map(func(p): return p["tiers"].map(func(t): return t["cost"])) == [[45, 70, 115, 190], [40, 65, 110, 190], [40, 65, 115, 195], [40, 70, 115, 200]],
			"A  four paths of four (Ambush, Sabotage, Stealth, Execution) at their prices")
	# Goes for the Horde Mage behind the goblins.
	await _fresh()
	var a = await _hire("assassin", Vector2(320, 560))
	for i in 3:
		_foe("goblin", Vector2(260 + i * 60, 420), 9999.0).speed = 0.0
	var mage = _foe("warmage", Vector2(470, 330), 9999.0)
	mage.speed = 0.0
	await _frames(20)
	check(a.priority == "valuable" and a.target == mage, "A  High-value by default: he goes for the Horde Mage behind the goblins (%s)" % (a.target.kind if a.target != null else "none"))
	# Opportunist / Backstab.
	await _fresh()
	var aa = await _hire("assassin", Vector2(320, 560))
	var k = await _hire("swordsman", Vector2(200, 560))
	var busy = _foe("orc", Vector2(200, 520), 9999.0)
	busy.last_foe = k
	busy.last_foe_t = 1.5
	aa.target = busy
	var h0: float = aa._assassin_hit(busy, 12.0)
	check(absf(h0 - 24.0) < 0.01, "A  his opening strike, stalked up to a foe busy with another: 2x (%.1f)" % h0)
	var h: float = aa._assassin_hit(busy, 12.0)
	check(absf(h - 18.0) < 0.01, "A  ...then the Opportunist's cut while it's still busy: 1.5x (%.1f)" % h)
	var h2: float = aa._assassin_hit(busy, 12.0)
	check(absf(h2 - 12.0) < 0.01, "A  ...not again on that foe for a while (%.1f)" % h2)
	var am = await _hire("assassin", Vector2(440, 560), [1, 0, 0, 0])
	var facing_him = _foe("orc", Vector2(440, 520), 9999.0)
	facing_him.last_foe = am
	facing_him.last_foe_t = 1.5
	facing_him.lunge_dir = Vector2.DOWN
	facing_him.fighting = true
	am.since_strike = 5.0
	var hf: float = am._assassin_hit(facing_him, 12.0)
	busy.last_foe_t = 1.5
	am.since_strike = 5.0
	var hb: float = am._assassin_hit(busy, 12.0)
	am.opening = false
	check(absf(hf - 12.0) < 0.01 and absf(hb - 12.0 * 2.5) < 0.01, "A  Backstab: 2.5x on a foe busy with another (%.1f), not on one facing and fighting him (%.1f)" % [hb, hf])
	am.since_strike = 0.0
	busy.last_foe_t = 1.5
	var hr: float = am._assassin_hit(busy, 12.0)
	check(hr < 12.0 * 2.0, "A  ...and only after a moment without striking (%.1f)" % hr)
	# Chain Assassination.
	await _fresh()
	var c = await _hire("assassin", Vector2(320, 560), [3, 0, 0, 0])
	var kk = await _hire("swordsman", Vector2(320, 470))
	var v1 = _foe("goblin", Vector2(320, 520), 25.0)
	var v2 = _foe("goblin", Vector2(350, 505), 20.0)
	for v in [v1, v2]:
		v.speed = 0.0
		v.last_foe = kk
		v.last_foe_t = 1.5
	c.rest_t = 5.0
	c.target = v1
	c.cd_timer = 0.0
	await _frames(60)
	check((not is_instance_valid(v1) or v1.dead) and (not is_instance_valid(v2) or v2.dead) and c.chain_t > 5.0,
			"A  Chain Assassination: the opener kills, he lunges to the goblin beside it and kills that too")
	await _fresh()
	var c2 = await _hire("assassin", Vector2(320, 560), [3, 0, 0, 0])
	var kk2 = await _hire("swordsman", Vector2(320, 470))
	var u1 = _foe("goblin", Vector2(320, 520), 25.0)
	var u2 = _foe("orc", Vector2(350, 505), 5000.0)
	for v in [u1, u2]:
		v.speed = 0.0
		v.last_foe = kk2
		v.last_foe_t = 1.5
	c2.rest_t = 5.0
	c2.target = u1
	await _frames(60)
	check(is_instance_valid(u2) and not u2.dead and c2.chain_mults.is_empty() and c2.lunge_left == 0.0, "A  ...a second that lives through it: the chain ends there")
	# Silent Reaper: three, and the weak falter.
	await _fresh()
	var sr = await _hire("assassin", Vector2(320, 560), [4, 0, 0, 0])
	var kk3 = await _hire("swordsman", Vector2(200, 470))
	var vs := []
	for i in 3:
		var v = _foe("goblin", Vector2(300 + i * 30, 520 - i * 8), 15.0)
		v.speed = 0.0
		v.last_foe = kk3
		v.last_foe_t = 1.5
		vs.append(v)
	var by = _foe("goblin", Vector2(380, 470), 9999.0)
	by.speed = 0.0
	sr.rest_t = 5.0
	sr.target = vs[0]
	var faltered := false
	for f in 60:
		await process_frame
		faltered = faltered or (is_instance_valid(by) and by.stun_timer > 0.0)
	var killed: int = vs.filter(func(v): return not is_instance_valid(v) or v.dead).size()
	check(killed == 3 and faltered, "A  Silent Reaper: three in one chain (%d), and a goblin by them falters" % killed)
	# Sabotage.
	await _fresh()
	var sb = await _hire("assassin", Vector2(320, 560), [0, 4, 0, 0])
	var ogre = _foe("ogre", Vector2(100, 300), 9999.0)
	ogre.slam_wind = 0.5
	var t0: float = ogre.slam_wind
	sb.sever = {}
	sb._sabotage(ogre)
	check(ogre.slam_wind > t0 + 0.3 and ogre.blackout_t > 0.0, "A  Disruptive Cut sets an Ogre's slam back (%.1fs), and Blackout follows" % ogre.slam_wind)
	sb._apply_upgrades()
	var wm = _foe("warmage", Vector2(500, 300), 9999.0)
	wm.cast_state = "charge"
	wm.cast_left = 1.0
	sb._sabotage(wm)
	check(wm.cast_state == "", "A  Spell Sever: a Horde Mage's spell broken off")
	var wl = _foe("warlord", Vector2(200, 250), 9999.0)
	wl.slam_wind = 0.5
	sb._sabotage(wl)
	check(wl.slam_wind > 0.0 and wl.blackout_t < 2.5 * 0.6, "A  ...a Warlord's blow only set back, and blacked out far less (%.2fs)" % wl.blackout_t)
	var bt: float = wm.blackout_t
	wm.blackout_t = 0.0
	wm.apply_blackout(2.5, 4.0)
	check(wm.blackout_t == 0.0, "A  ...a second Assassin can't black it out again straight after (no overlapping lock)")
	await _fresh()
	var ku = await _hire("assassin", Vector2(320, 560), [0, 2, 0, 0])
	var bolt = _foe("boltflinger", Vector2(320, 430), 9999.0)
	bolt.speed = 0.0
	var thrown := false
	for f in 60 * 4:
		await process_frame
		if ku.kunai_t > 5.0:
			thrown = true
			break
	await _frames(20)
	check(thrown and bolt.hp < 9999.0, "A  Hidden Kunai: thrown at a Boltflinger readying its bolt, and it lands")
	# Stealth.
	await _fresh()
	var st = await _hire("assassin", Vector2(320, 560), [0, 0, 4, 0])
	var sk = _foe("skeleton_archer", Vector2(320, 440), 9999.0)
	st.rest_t = 5.0
	var sk2 = _foe("skeleton_archer", st.position + Vector2(30, -30), 9999.0)
	check(st.unseen_by(sk, 150.0) and not st.unseen_by(sk2, 150.0), "A  stalking (Leafstep): an archer 12 ft off with a 15 ft bow doesn't see him; one 4 ft off does")
	st.rest_t = 0.0
	check(not st.unseen_by(sk, 150.0), "A  ...in the fight, he's seen as anyone")
	var mobbers := []
	for i in 4:
		var o = _foe("orc", st.position + Vector2.from_angle(i * TAU / 4.0) * 40.0, 9999.0)
		o.aggro = st
		mobbers.append(o)
	st.smoke_t = 0.0
	await _frames(3)
	var lost: int = mobbers.filter(func(o): return o.aggro != st).size()
	var lured: int = mobbers.filter(func(o): return o.aggro != null and o.aggro != st).size()
	check(st.smoke_hide > 0.0 and lost == 4 and lured == 2 and st.smoke_ambush == false, "A  Smoke Pellet when surrounded: the four on him lose him (%d), two go after the decoy (%d)" % [lost, lured])
	await _frames(60 * 2)
	check(st.position.distance_to(mobbers[0].position) > 40.0, "A  ...and he's slipped away")
	await _fresh()
	var both = await _hire("assassin", Vector2(320, 560), [2, 0, 2, 0])
	for i in 4:
		_foe("orc", both.position + Vector2.from_angle(i * TAU / 4.0) * 40.0, 9999.0)
	both.rest_t = 0.0
	await _frames(3)
	check(both.smoke_ambush, "A  Ambush + Smoke: the smoke gives him one more opening strike")
	# Execution.
	await _fresh()
	var ex = await _hire("assassin", Vector2(320, 560), [0, 0, 0, 4])
	var hurt = _foe("orc", Vector2(320, 520), 100.0)
	hurt.hp = 45.0
	ex.since_strike = 0.0   # (no opening strike in these: he's been at it)
	var healthy = _foe("orc", Vector2(100, 300), 100.0)
	healthy.aggro = ex
	var h_full: float = ex._assassin_hit(healthy, 12.0)
	var hs := []
	for i in 3:
		hs.append(ex._assassin_hit(hurt, 12.0))
	check(absf(h_full - 12.0) < 0.01 and hs[1] > hs[0] and hs[2] > hs[1], "A  Scent of Blood and Relentless Cuts: nothing on a healthy foe (%.1f), more each cut on a wounded one (%.1f, %.1f, %.1f)" % [h_full, hs[0], hs[1], hs[2]])
	ex.death_t = 0.0
	hurt.hp = 30.0
	var db: float = ex._assassin_hit(hurt, 12.0)
	var king = _foe("troll", Vector2(500, 300), 1000.0)
	king.boss = true
	king.hp = 300.0
	ex.death_t = 0.0
	ex.rel_t = 0.0
	var dbb: float = ex._assassin_hit(king, 12.0)
	check(db > 12.0 * 1.75 and dbb < db and dbb >= 12.0 * 1.4 * 1.2 - 0.1, "A  Final Judgment's Deathblow under 35%% (%.1f), less on a boss (%.1f)" % [db, dbb])


# --- C ---

func _campaign() -> void:
	var c = root.get_node("Campaign")
	c.new_campaign("normal")
	check(c.allows("pikeman") and c.trainable().has("pikeman") and c.region_of("pikeman") == "ashwatch", "C  the Pikeman's there from the campaign's start (Ashwatch's garrison)")
	check(not c.allows("assassin"), "C  the Assassin isn't, at first")
	c.allies.append("greenwood")
	check(c.allows("assassin") and c.region_of("assassin") == "greenwood", "C  ...the Woodland Watch joins: Elven Assassins (their Tier IV with Greenwood's beacon)")
	c.allies.erase("greenwood")
	var ally := false
	for a in CD.MISSIONS["gw_exodus"].get("allies", []):
		ally = ally or a["kind"] == "assassin"
	check(ally, "C  The Forest Exodus: an Assassin of the Watch fights beside you before they join")
	c.reset()


# --- F ---

func _formation() -> void:
	await _fresh()
	var army := []
	for i in 6:
		army.append(await _hire(["swordsman", "pikeman", "swordsman", "pikeman", "archer", "healer"][i], Vector2(80 + i * 60, 450)))
	var f = main.formation_ctl.make_formation(army, "shield_wall")
	await _frames(60 * 5)
	var knights: Array = army.filter(func(w): return w.kind == "swordsman")
	var pikes: Array = army.filter(func(w): return w.kind == "pikeman")
	var ky: float = knights[0].post.y
	var py: float = pikes[0].post.y
	check(py > ky and py - ky < pikes[0].attack_range + pikes[0].RADIUS * 2.0, "F  Shield Wall: the Pikemen in the second rank, %.0fpx behind the Knights (in reach past them)" % (py - ky))


# --- B ---

func _builds() -> void:
	var builds := {"Sentinel": ["pikeman", [4, 0, 0, 2]], "Giant Slayer": ["pikeman", [2, 4, 0, 0]], "Formation Guard": ["pikeman", [2, 0, 4, 0]],
		"Escort Guard": ["pikeman", [0, 0, 2, 4]], "Silent Killer": ["assassin", [4, 0, 2, 0]], "Spellbreaker": ["assassin", [0, 4, 2, 0]],
		"Phantom": ["assassin", [2, 0, 4, 0]], "Deathstalker": ["assassin", [0, 2, 0, 4]]}
	for name in builds:
		await _fresh()
		var b: Array = builds[name]
		var w = await _hire(b[0], Vector2(320, 560), b[1])
		await _hire("swordsman", Vector2(260, 520))
		w.max_hp *= 3.0
		w.hp = w.max_hp
		for i in 8:
			_foe(["goblin", "orc", "wolf", "warmage", "boltflinger", "ogre", "goblin", "skeleton_archer"][i], Vector2(120 + i * 55, 200 + (i % 3) * 30))
		var dealt := 0.0
		for f in 60 * 12:
			await process_frame
		var left: int = main.battlefield.get_enemies().size()
		check(w.total_upgrades() == 6 and is_instance_valid(w) and left < 8, "B  %s (%s %s): fights a mixed wave (%d of 8 left after 12s)" % [name, b[0], str(b[1]), left])
