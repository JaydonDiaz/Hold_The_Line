extends SceneTree
## Troops answering enemies' warned blows (defense.gd). Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/defense_test.gd [-- SECTIONS]
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed. At the end
## it prints how often each kind got clear, braced or was hit (Defense.stats).
##
## A  One on one: an idle Archer gets clear of a strafing run; a Knight trading blows with
##    an Ogre braces (less damage, thrown less far) and keeps his ground; a Martial Artist
##    weaves out of the Ogre's arc more often than a Knight; a Mage loosing spells reacts
##    later than one standing idle; a Healer partway through a revive keeps at it for a light
##    blow and breaks off for a heavy one
## I  Iron Will: still a chance at any blow, but not on top of a dodge that was caught
## C  Crowds: Knights in a line hold it under a Warlord's sweep; two blows at once, slower;
##    boxed in by enemies, nowhere to go (it takes it, no dithering); just after a dodge, it
##    can't dodge the next
## U  Upgrades: Charge and buffs make a troop really quicker (and so able to get clear of
##    more); Knight armour makes a blow less of a threat; a frozen Ogre's blow comes later;
##    a braced blow cut once (a Halo's or Bulwark's cut on top, not instead); Trapcraft lays
##    no more traps for dodging than walking
## F  Formation: getting clear keeps to its Guard Area (and near its post on Hold); its
##    post and target stay as they were; back where it was useful after
## T  Up a Tower, on an emplacement: no reaction at all
## B  A mixed fight: some blows land, some are dodged, some braced; agile troops get clear
##    more than Knights; nobody spends the fight dodging

const Data = preload("res://scripts/data/data.gd")
const Defense = preload("res://scripts/troops/defense.gd")
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
	var c = root.get_node("Campaign")
	c.save_path = "user://defense_test.cfg"
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
	if _on("A"):
		await _one_on_one()
	if _on("I"):
		await _iron_will()
	if _on("C"):
		await _crowds()
	if _on("U"):
		await _upgrades()
	if _on("F"):
		await _formation()
	if _on("T"):
		await _towers()
	if _on("B"):
		await _battle()
	print("")
	print("Warned blows, by troop:   noticed / got clear / braced / took it / natural miss | hit after dodging / braced / taking / unaware | broke off")
	for k in Defense.stats:
		var s: Dictionary = Defense.stats[k]
		print("  %-10s %3d / %3d / %3d / %3d / %3d | %3d / %3d / %3d / %3d | %3d" % [k, s.get("notice", 0), s.get("evade", 0), s.get("brace", 0),
				s.get("continue", 0), s.get("miss", 0), s.get("hit_evade", 0), s.get("hit_brace", 0), s.get("hit_continue", 0) + s.get("hit_miss", 0),
				s.get("hit_unaware", 0), s.get("interrupt", 0)])
	if main != null:
		main.free()
	if FileAccess.file_exists("user://defense_test.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://defense_test.cfg"))
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


func _hire(kind: String, at: Vector2):
	main.placing_type = kind
	main.hiring.hire_at(at)
	main.placing_type = ""
	main.selected = null
	var all: Array = main.battlefield.get_warriors().filter(func(w): return w.kind == kind)
	var w = all[all.size() - 1]
	w.build_left = 0.0
	w.position = w.post
	return w


func _foe(kind: String, at: Vector2, level := 1):
	main.waves._spawn_enemy(kind, level, at)
	return main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)


func _tough(w, hp := 5000.0) -> void:
	w.max_hp = hp
	w.hp = hp


## A Wyvern's strafing run at three troops of `kind` standing in a column: how many it burns.
func _strafe_at(kind: String, busy := false) -> int:
	await _fresh()
	var troops := []
	for i in 3:
		var t = await _hire(kind, Vector2(320, 300 + i * 40))
		_tough(t, 400.0)
		troops.append(t)
	if busy:
		for i in 3:
			_tough(_foe("goblin", Vector2(250 + i * 60, 180)), 99999.0)   # (something to shoot at, out of the run's way)
		await _frames(30)
	var y = _foe("wyvern", Vector2(320, 120))
	y.strafe_timer = 0.0
	var burnt := {}
	for f in 60 * 4:
		await process_frame
		y.breath_timer = 999.0
		for t in troops:
			if t.hp < 400.0 - 1.0:
				burnt[t] = true   # (it mends again, idle)
	return burnt.size()


## An Ogre slamming a troop of `kind` that's fighting it: [hit, how far it was thrown, the troop].
func _ogre_on(kind: String, reacts := true, s := 1) -> Array:
	seed(s)
	await _fresh()
	var w = await _hire(kind, Vector2(320, 420))
	_tough(w, 600.0)
	w.reacts = reacts
	var o = _foe("ogre", Vector2(320, 372))
	o.cd_timer = 0.6
	var from := Vector2.ZERO
	var hp0: float = w.hp
	var hit := false
	var thrown := 0.0
	var landed := -1
	for f in 60 * 3:
		await process_frame
		if o.slam_wind > 0.0 and from == Vector2.ZERO:
			from = w.position
		if o.slam_wind <= 0.0 and from != Vector2.ZERO and landed < 0:
			landed = f
			hit = w.hp < hp0 - 1.0
		if landed >= 0 and f == landed + 14:
			thrown = w.position.distance_to(from)
			break
	return [hit, thrown, w.def_seen.values().duplicate(), hp0 - w.hp, w.post.distance_to(w.position)]


# --- A ---

func _one_on_one() -> void:
	seed(7)
	var archers := await _strafe_at("archer")
	var knights := await _strafe_at("swordsman")
	check(archers <= 1 and knights == 3, "A  an idle Archer gets clear of a strafing run (%d of 3 burnt); Knights brace and take it (%d of 3)" % [archers, knights])
	var r: Array = await _ogre_on("swordsman")
	var r0: Array = await _ogre_on("swordsman", false)
	check(r[0] and r[2].has("brace"), "A  a Knight trading blows with an Ogre braces for its slam, and takes it (%s)" % [r[2]])
	check(r[3] < r0[3] * 0.85 and r[1] < r0[1] * 0.7, "A  ...braced: less damage (%.1f, unbraced %.1f), thrown less far (%.0fpx, unbraced %.0fpx)" % [r[3], r0[3], r[1], r0[1]])
	check(r[4] < 45.0, "A  ...and keeps his ground (%.0fpx from his post)" % r[4])
	var ma_clear := 0
	var kn_clear := 0
	for s in 6:
		var m: Array = await _ogre_on("martial", true, 100 + s)
		ma_clear += 0 if m[0] else 1
		var k: Array = await _ogre_on("swordsman", true, 100 + s)
		kn_clear += 0 if k[0] else 1
	check(ma_clear >= 3 and ma_clear > kn_clear, "A  a Martial Artist weaves out of an Ogre's arc more often than a Knight (%d of 6, Knight %d of 6)" % [ma_clear, kn_clear])
	await _fresh()
	var ma = await _hire("martial", Vector2(320, 420))
	ma.cd_timer = 1.0
	seed(8)
	var ma_idle: float = Defense.reaction_time(ma, 1)
	ma.combo_left = 5   # (a long Brawling combo under way)
	seed(8)
	var ma_combo: float = Defense.reaction_time(ma, 1)
	ma.combo_left = 0
	check(ma_combo > ma_idle + 0.4, "A  ...but deep in a long combo he's slow to break off (%.2fs, idle %.2fs)" % [ma_combo, ma_idle])
	# Mage: reacting while loosing spells vs standing idle.
	await _fresh()
	var mage = await _hire("mage", Vector2(320, 420))
	var g = _foe("goblin", Vector2(320, 330))
	_tough(g, 99999.0)
	mage.target = g
	mage.cd_timer = 0.05
	seed(3)
	var busy: float = Defense.reaction_time(mage, 1)
	mage.target = null
	mage.cd_timer = 1.0
	seed(3)
	var idle: float = Defense.reaction_time(mage, 1)
	check(busy > idle + 0.1, "A  a Mage about to loose a spell reacts later than one standing idle (%.2fs, idle %.2fs)" % [busy, idle])
	# Healer reviving.
	await _fresh()
	var h = await _hire("healer", Vector2(320, 420))
	var down = await _hire("swordsman", Vector2(380, 420))
	down.take_damage(9999.0)
	h.rez_target = down
	h.rez_progress = 1.0
	var light := {"key": 1, "kind": "slam", "src": g, "t": 0.9, "c": h.position, "r": 30.0, "dmg": 4.0, "push": 0.0, "stun": 0.0}
	var heavy := light.duplicate()
	heavy["dmg"] = 60.0
	var cl: Dictionary = Defense.choose(h, light, [light], [light])
	var ch: Dictionary = Defense.choose(h, heavy, [heavy], [heavy])
	check(cl["act"] == "continue" and ch["act"] == "evade", "A  a Healer reviving keeps at it for a light blow (%s), gets clear of a heavy one (%s)" % [cl["act"], ch["act"]])
	check(Defense.commitment(h) >= 0.25, "A  ...and a revive under way is a commitment (%.2fs)" % Defense.commitment(h))


# --- I ---

func _iron_will() -> void:
	await _fresh()
	var m = await _hire("martial", Vector2(320, 420))
	_tough(m)
	m.evade = 1.0   # (every chance a dodge, to see when it's used)
	var hp0: float = m.hp
	for i in 10:
		m.take_damage(5.0)
	check(m.hp == hp0, "I  Iron Will: a dodge chance at any blow (none of 10 landed at 100%)")
	m.def_seen[77] = "evade"
	main.heavy_key = 77
	for i in 10:
		m.take_damage(5.0)
	main.heavy_key = 0
	check(m.hp < hp0 - 40.0, "I  ...but a warned blow it tried to get clear of and was caught by lands anyway (%.0f taken)" % (hp0 - m.hp))
	m.def_seen.clear()
	main.heavy_key = 78
	var hp1: float = m.hp
	for i in 10:
		m.take_damage(5.0)
	main.heavy_key = 0
	check(m.hp == hp1, "I  ...one it didn't try to get clear of still gets its chance")


# --- C ---

func _crowds() -> void:
	seed(11)
	await _fresh()
	var line := []
	for i in 5:
		var k = await _hire("swordsman", Vector2(260 + i * 30, 430))
		_tough(k, 400.0)
		line.append(k)
	var wl = _foe("warlord", Vector2(320, 385))
	var hits := {}
	var braced := {}
	var ran := 0
	var spread: float = 0.0
	for f in 60 * 2:
		await process_frame
		for k in line:
			if k.hp < 400.0 - 1.0:
				hits[k] = true
			if k.brace_key != 0:
				braced[k] = true
			if k.evading:
				ran += 1
			spread = maxf(spread, k.post.distance_to(k.position))
	check(hits.size() >= 2 and braced.size() >= 2 and ran == 0,
			"C  Knights in a line hold it under a Warlord's sweep: brace and take it, none runs (%d hit, %d braced, %d frames running)" % [hits.size(), braced.size(), ran])
	# Two blows at once: slower to react.
	var k0 = line[0]
	k0.target = null
	k0.cd_timer = 1.0
	k0.def_cd = 0.0
	seed(5)
	var one: float = Defense.reaction_time(k0, 1)
	seed(5)
	var two: float = Defense.reaction_time(k0, 2)
	check(two >= one + Defense.PER_THREAT - 0.001, "C  under two blows at once it's slower to react (%.2fs, one: %.2fs)" % [two, one])
	# Boxed in.
	await _fresh()
	var a = await _hire("archer", Vector2(320, 420))
	for i in 8:
		var e = _foe("orc", a.position + Vector2.from_angle(i * TAU / 8.0) * 40.0)
		e.speed = 0.0
	var box := {"key": 2, "kind": "stomp", "src": main.battlefield.get_enemies()[0], "t": 0.9, "c": a.position, "r": 60.0, "dmg": 30.0, "push": 0.0, "stun": 0.0}
	var cb: Dictionary = Defense.choose(a, box, [box], [box])
	check(cb["act"] == "continue", "C  boxed in by enemies, nowhere to go: it takes it (%s)" % cb["act"])
	# Just after a dodge.
	a.def_cd = 1.0
	var open := box.duplicate()
	open["r"] = 20.0
	var ca: Dictionary = Defense.choose(a, open, [open], [open])
	check(ca["act"] == "continue", "C  just after a dodge, it can't dodge the next (%s)" % ca["act"])
	# ...and in the field: a second run straight after the first catches the Archer that got clear.
	seed(9)
	await _fresh()
	var arch = await _hire("archer", Vector2(320, 320))
	_tough(arch, 400.0)
	var y1 = _foe("wyvern", Vector2(320, 120))
	y1.strafe_timer = 0.0
	var dodged_first := false
	var hit_second := false
	var second = null
	for f in 60 * 5:
		await process_frame
		y1.breath_timer = 999.0
		if second != null:
			second.breath_timer = 999.0
		if second == null and arch.def_seen.values().has("evade"):
			dodged_first = true
			second = _foe("wyvern", arch.evade_to + Vector2(0, -150) if arch.evading else arch.position + Vector2(0, -150))
			second.strafe_timer = 0.0
		if second != null and arch.hp < 400.0 - 1.0:
			hit_second = true
	check(dodged_first and (hit_second or arch.def_seen.values().count("evade") <= 1), "C  consecutive runs: it gets clear of the first, not both (%s)" % ("hit by the second" if hit_second else "took the second"))


# --- U ---

func _upgrades() -> void:
	await _fresh()
	var k = await _hire("swordsman", Vector2(300, 420))
	var s0: float = Defense.speed(k)
	k.tiers = [0, 0, 0, 2]
	k._apply_upgrades()
	var s1: float = Defense.speed(k)
	check(s1 > s0 * 1.15, "U  Charge upgrades make a Knight really quicker to get clear (%.0f -> %.0f px/s)" % [s0, s1])
	var th := {"key": 3, "kind": "slam", "src": null, "t": 0.7, "c": k.position, "r": 30.0, "dmg": 40.0, "push": 0.0, "stun": 0.0}
	var sev0: float = Defense.severity(k, th)
	k.tiers = [0, 0, 2, 0]
	k._apply_upgrades()
	k.hp = k.max_hp
	var sev1: float = Defense.severity(k, th)
	check(sev1 < sev0 * 0.7, "U  Padded Armor and Chainmail make a blow less of a threat (%.0f%% of health, was %.0f%%)" % [sev1 * 100, sev0 * 100])
	var a = await _hire("archer", Vector2(400, 420))
	var sa: float = Defense.speed(a)
	a.buff["speed"] = 0.2   # (a Bard's Legendary Ballad, a War Statue)
	check(Defense.speed(a) > sa * 1.15, "U  a speed buff (Bard, War Statue) makes it really quicker (%.0f -> %.0f)" % [sa, Defense.speed(a)])
	a.buff["speed"] = 0.0
	# A frozen Ogre's blow waits.
	var o = _foe("ogre", Vector2(300, 372))
	o.slam_wind = 0.5
	o._new_windup()
	var t0: float = o.threats()[0]["t"]
	o.freeze_timer = 1.0
	var t1: float = o.threats()[0]["t"]
	check(t1 > t0 + 0.9, "U  a Frost Witch's freeze holds an Ogre's blow back, and troops see it coming later (%.1fs, unfrozen %.1fs)" % [t1, t0])
	o.queue_free()
	# Braced and buffed: each cut once.
	await _fresh()
	var kb = await _hire("swordsman", Vector2(320, 420))
	_tough(kb, 1000.0)
	kb.block = 0.0
	kb.buff["defense"] = 0.2   # (a Halo, a War Statue's Bulwark)
	kb.brace_key = 55
	main.heavy_key = 55
	var hp0: float = kb.hp
	kb.take_damage(100.0)
	main.heavy_key = 0
	var want: float = 100.0 * (1.0 - Defense.BRACE_DAMAGE) * (1.0 - kb.armor) * (1.0 - 0.2)
	check(absf((hp0 - kb.hp) - want) < 0.5, "U  braced under a Halo: each cut once (%.1f taken, %.1f expected)" % [hp0 - kb.hp, want])
	var hp1: float = kb.hp
	kb.take_damage(100.0)   # (an ordinary blow: no brace)
	check(absf((hp1 - kb.hp) - 100.0 * (1.0 - kb.armor) * 0.8) < 0.5, "U  ...an ordinary blow while braced isn't cut by it")
	# Trapcraft: dodging lays traps as walking does, no more.
	seed(4)
	await _fresh()
	var al = await _hire("alchemist", Vector2(320, 360))
	_tough(al, 2000.0)
	al.tiers = [0, 0, 0, 2]
	al._apply_upgrades()
	var every: float = al.traps["every"]
	var ys := []
	var yv = _foe("wyvern", Vector2(320, 120))
	_tough(yv, 99999.0)
	ys.append(yv)
	var laid := {}
	var dodges := 0
	var ev0: int = Defense.stats.get("alchemist", {}).get("evade", 0)
	var was := false
	for f in 60 * 10:
		await process_frame
		for y in ys:
			y.breath_timer = 999.0
			if y.strafe_timer > 2.0:
				y.strafe_timer = 2.0   # (runs one after another)
		for t in al.my_traps:
			if is_instance_valid(t):
				laid[t.get_instance_id()] = true
		was = al.evading
	dodges = Defense.stats.get("alchemist", {}).get("evade", 0) - ev0
	print("     (alchemist: %s)" % [Defense.stats.get("alchemist", {})])
	check(dodges >= 2 and laid.size() <= int(10.0 / every) + 1 and al.my_traps.size() <= int(al.traps["max"]),
			"U  Trapcraft: dodging (%d times) lays no more charges than walking would (%d in 10s, one each %.1fs; %d down, at most %d)" % [dodges, laid.size(), every, al.my_traps.size(), al.traps["max"]])


# --- F ---

func _formation() -> void:
	seed(21)
	await _fresh()
	var a = await _hire("archer", Vector2(150, 400))
	a.move_mode = "guard"
	a.guard_area = Rect2(110, 360, 80, 80)
	_tough(a, 400.0)
	var g = _foe("goblin", Vector2(150, 260))
	_tough(g, 99999.0)
	await _frames(20)
	var tgt = a.target
	var post0: Vector2 = a.post
	var y = _foe("wyvern", Vector2(150, 120))
	y.strafe_timer = 0.0
	var worst := 0.0
	var went := false
	for f in 60 * 3:
		await process_frame
		y.breath_timer = 999.0
		went = went or a.evading
		worst = maxf(worst, a.rect_gap(a.guard_area, a.position))
	check(went and worst <= 14.0, "F  getting clear keeps to its Guard Area (furthest %.0fpx outside it)" % worst)
	check(a.post == post0 and a.move_mode == "guard" and a.guard_area == Rect2(110, 360, 80, 80), "F  ...its post and orders stay as they were")
	check(a.target == tgt or a.target == g, "F  ...and it's still after the same enemy")
	await _frames(60 * 2)
	check(a.rect_gap(a.guard_area, a.position) <= 6.0 and not a.evading and a.target != null,
			"F  ...back in its area, fighting on (%.0fpx out, %s)" % [a.rect_gap(a.guard_area, a.position), "evading" if a.evading else "after %s" % [a.target]])
	# Hold Position: only a short step from its post.
	await _fresh()
	var h = await _hire("archer", Vector2(320, 420))
	h.move_mode = "hold"
	var th := {"key": 4, "kind": "slam", "src": _foe("ogre", Vector2(320, 300)), "t": 2.0, "c": h.position + Vector2(10, 0), "r": 30.0, "dmg": 30.0, "push": 0.0, "stun": 0.0}
	var c: Dictionary = Defense.choose(h, th, [th], [th])
	var far: float = h.post.distance_to(c.get("to", h.post))
	var big := th.duplicate()
	big["r"] = 120.0
	var cb: Dictionary = Defense.choose(h, big, [big], [big])
	check(c["act"] == "evade" and far <= 60.0 and cb["act"] == "continue", "F  on Hold Position: a short step from its post (%.0fpx), never a long run (%s)" % [far, cb["act"]])
	# Knights get clear sideways or forward, not back toward the castle.
	var k = await _hire("swordsman", Vector2(200, 420))
	var side := {"key": 5, "kind": "slam", "src": th["src"], "t": 3.0, "c": k.position, "r": 20.0, "dmg": 9999.0, "push": 0.0, "stun": 0.0}
	var ck: Dictionary = Defense.choose(k, side, [side], [side])
	check(ck["act"] == "evade" and (ck["to"] - k.position).y < 10.0, "F  a Knight getting clear of a heavy blow doesn't give ground to the castle (%.0f, %.0f)" % [(ck["to"] - k.position).x, (ck["to"] - k.position).y])


# --- T ---

func _towers() -> void:
	await _fresh()
	var t = await _hire("tower", Vector2(320, 440))
	var a = await _hire("archer", Vector2(320, 440))
	a.enter_tower(t)
	await _frames(5)
	var c = await _hire("cannon", Vector2(200, 440))
	var o = _foe("ogre", Vector2(320, 400))
	o.slam_wind = 0.6
	o._new_windup()
	o.lunge_dir = Vector2.DOWN
	await _frames(60)
	check(a.garrison == t and a.def_seen.is_empty() and not a.evading, "T  an Archer up a Tower doesn't leave it to dodge")
	check(c.def_seen.is_empty() and c.position == c.post, "T  an emplacement never reacts")


# --- B ---

func _battle() -> void:
	Defense.stats.clear()
	seed(31)
	await _fresh()
	var troops := []
	for i in 4:
		troops.append(await _hire("swordsman", Vector2(200 + i * 70, 400)))
	for i in 2:
		troops.append(await _hire("martial", Vector2(230 + i * 140, 420)))
	for i in 3:
		troops.append(await _hire("archer", Vector2(210 + i * 100, 480)))
	troops.append(await _hire("mage", Vector2(260, 520)))
	troops.append(await _hire("healer", Vector2(380, 520)))
	for t in troops:
		_tough(t, t.max_hp * 4.0)
	for i in 3:
		_tough(_foe("ogre", Vector2(220 + i * 100, 300)), 1500.0)
	_tough(_foe("warlord", Vector2(320, 260)), 3000.0)
	var y = _foe("wyvern", Vector2(320, 100))
	_tough(y, 3000.0)
	var dodging_frames := 0
	var troop_frames := 0
	for f in 60 * 25:
		await process_frame
		for t in troops:
			if is_instance_valid(t) and t.is_active():
				troop_frames += 1
				if t.evading or t.brace_key != 0:
					dodging_frames += 1
	var tot := {}
	for k in Defense.stats:
		for e in Defense.stats[k]:
			tot[e] = int(tot.get(e, 0)) + int(Defense.stats[k][e])
	var landed: int = tot.get("hit_brace", 0) + tot.get("hit_continue", 0) + tot.get("hit_evade", 0) + tot.get("hit_unaware", 0) + tot.get("hit_miss", 0)
	check(landed >= 5 and tot.get("evade", 0) >= 3 and tot.get("brace", 0) >= 3,
			"B  a mixed fight: blows land (%d), some dodged (%d), some braced (%d)" % [landed, tot.get("evade", 0), tot.get("brace", 0)])
	var ks: Dictionary = Defense.stats.get("swordsman", {})
	var ms: Dictionary = Defense.stats.get("martial", {})
	var kn_rate: float = float(ks.get("evade", 0)) / maxf(1.0, float(ks.get("notice", 0)))
	var ma_rate: float = float(ms.get("evade", 0)) / maxf(1.0, float(ms.get("notice", 0)))
	check(ma_rate > kn_rate, "B  Martial Artists get clear more than Knights (%.0f%% of blows noticed, Knights %.0f%%)" % [ma_rate * 100, kn_rate * 100])
	var share: float = float(dodging_frames) / maxf(1.0, float(troop_frames))
	check(share < 0.12, "B  nobody spends the fight dodging (%.1f%% of the time getting clear or bracing)" % (share * 100))
