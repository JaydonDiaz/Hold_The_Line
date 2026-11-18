extends SceneTree
## Towers and the new emplacements. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/towers_test.gd
##   A  archer      Volley (third path): faster, then 2 and 3 arrows; Trick Shots (fourth):
##                   pierce, seek, fire arrows and rain, all of it sharpened at Tier IV
##   T  tower       a plain Tower doesn't fight by itself; a ranged troop ordered (or hired)
##                   onto it climbs in, keeps its upgrades, reaches 30% further (more with the
##                   Lookout path), and enemies go for the tower, not it; sent elsewhere (or
##                   the tower wrecked) it climbs down; melee troops can't go up
##   C  crews       every ranged kind keeps its attack, upgrades, targeting and support up in
##                   a Tower: reach x(1 + the tower's perch), attack time x its crew_rate, and
##                   nothing more however often upgrades are reapplied or it climbs up and down;
##                   what the crew does trains the crew's kind, what the tower takes trains the
##                   Tower (the two kept apart)
##   B  ballista    aims for flyers first and hits them twice as hard; a bolt goes on through
##                   everything in its line; the Chain Net slows flyers; Blasting Tips burst
##   O  obelisk     Mages near it hit harder; a Storm Rune strikes, Sunfire Glyphs burn the
##                   crowd they're laid under, a Rift Rune throws the enemy furthest down the
##                   field back up it (not a boss); nothing like the Medic Bay or War Statue
##   S  sappers     go for the nearest of your emplacements in reach (any kind, walls too) and
##                   blow up against it, an emplacement taking it as a wall does; it's marked
##                   for the player, and the charge takes time to plant (killed then: no blast);
##                   with none near, they make for the castle as before
##   U  unlocks     Stonehollow brings Towers and Ballistae; the Conclave the Obelisk; the old
##                   Archer, Mage and Frost Towers are gone
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.

const Data = preload("res://scripts/data.gd")
const CD = preload("res://scripts/campaign_data.gd")

var main
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	root.get_node("Campaign").save_path = "user://towers_test_campaign.cfg"
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _fresh() -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud.hide_mode_select()
	main.choose_mode("normal")
	main._lock_portrait(true)
	await _frames(3)


func _hire(kind: String, at: Vector2):
	main.gold = 99999
	var had: Array = main.get_warriors()
	main.placing_type = kind
	main.hire_at(at)
	main.placing_type = ""
	var fresh: Array = main.get_warriors().filter(func(x): return not had.has(x))
	if fresh.is_empty():
		return null
	var w = fresh[0]
	w.build_left = 0.0
	w.position = w.post
	return w


func _foe(kind: String, at: Vector2, hp := 0.0):
	main._spawn_enemy(kind, 1, at)
	var e = main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)
	if hp > 0.0:
		e.max_hp = hp
		e.hp = hp
	return e


func _run() -> void:
	_archer_paths()
	await _tower()
	await _crews()
	await _ballista()
	await _obelisk()
	await _sappers()
	_unlocks()
	if main != null:
		main.free()
	var save := ProjectSettings.globalize_path("user://towers_test_campaign.cfg")
	if FileAccess.file_exists(save):
		DirAccess.remove_absolute(save)
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


# --- A ---------------------------------------------------------------------------------------

func _archer_paths() -> void:
	var paths: Array = Data.WARRIORS["archer"]["paths"]
	var volley: Array = paths[2]["tiers"]
	check(paths[2]["name"] == "Volley" and volley[0]["effect"].has("rate") and volley[1]["effect"].has("rate")
			and volley[2]["effect"].get("multishot", 1) == 2 and volley[3]["effect"].get("multishot", 1) == 3,
			"A  the Archer's third path: faster, faster, then 2 arrows, then 3")
	var tricks: Array = paths[3]["tiers"]
	check(tricks[0]["effect"].get("pierce", 0) == 1 and tricks[1]["effect"].get("seek", false) and tricks[2]["effect"].has("burn") and tricks[2]["effect"].has("rain")
			and tricks.all(func(t): return not t["effect"].has("multishot")),
			"A  the fourth: pierce, seek, then fire arrows with fire rain (no more extra arrows here)")
	var t4: Dictionary = tricks[3]["effect"]
	check(t4.get("pierce", 0) > tricks[1]["effect"]["pierce"] and t4["burn"][0] > tricks[2]["effect"]["burn"][0]
			and t4["rain"]["damage"] > tricks[2]["effect"]["rain"]["damage"] and t4["rain"]["cooldown"] < tricks[2]["effect"]["rain"]["cooldown"],
			"A  ...and Tier IV sharpens every trick: more pierce, hotter burn, bigger and quicker rain")


# --- C ---------------------------------------------------------------------------------------

## For each ranged kind: its stats on the ground, up a Tower with two Lookout and four Hoardings
## upgrades, after reapplying upgrades and climbing up and down, and what training it earns.
func _crews() -> void:
	var builds := {"archer": [2, 0, 2, 0], "mage": [0, 2, 0, 2], "frost": [2, 2, 0, 0], "alchemist": [0, 0, 2, 2], "bard": [2, 0, 0, 2]}
	for kind in builds:
		await _fresh()
		var t = _hire("tower", Vector2(320, 500))
		for k in 2:
			t.upgrade(1)
		for k in 4:
			t.upgrade(2)
		var c = _hire(kind, Vector2(160, 640))
		c.tiers = builds[kind].duplicate()
		c._apply_upgrades()
		var reach: float = c.attack_range
		var cool: float = c.cooldown
		var song: float = c.song_radius
		main.selected = c
		main.order_move(t.position)
		main.selected = null
		await _frames(60 * 4)
		var up: bool = c.garrison == t
		var want_r: float = reach * (1.0 + t.perch)
		var want_c: float = cool * t.crew_rate
		var same: bool = is_equal_approx(c.attack_range, want_r) and is_equal_approx(c.cooldown, want_c) and is_equal_approx(c.song_radius, song * (1.0 + t.perch))
		for k in 3:
			c._apply_upgrades()
			t._apply_upgrades()
		await _frames(2)
		var still: bool = is_equal_approx(c.attack_range, want_r) and is_equal_approx(c.cooldown, want_c)
		check(absf(1.0 / t.crew_rate - 1.4) < 0.005 and is_equal_approx(t.perch, 0.4), "C  %s ...two Lookout and four Hoardings: reach +40%%, attacks 40%% faster, as their cards say" % kind)
		check(up and same and still and c.tiers == builds[kind],
				"C  %s up a Tower keeps %s; reach %.0f -> %.0f (x%.2f), attack time %.2fs -> %.2fs, unchanged after reapplying" %
				[kind, str(builds[kind]), reach, c.attack_range, 1.0 + t.perch, cool, c.cooldown])
		# Up and down three times: back to its ground stats exactly, then the same again up there.
		for k in 3:
			main.selected = c
			main.climb_down()
			main.selected = null
			await _frames(20)
			main.selected = c
			main.order_move(t.position)
			main.selected = null
			await _frames(60 * 2)
		check(c.garrison == t and is_equal_approx(c.attack_range, want_r) and is_equal_approx(c.cooldown, want_c),
				"C  %s ...after climbing down and up three times, still x%.2f and no more" % [kind, 1.0 + t.perch])
		# It fights from up there: a foe past its ground reach but in its tower reach.
		main.campaign = true   # (so training is counted)
		main.battle_xp = {}
		main.wave_active = true
		var foe = _foe("orc", t.position + Vector2(0, -minf(reach * 1.15, want_r - 8.0)), 1e5)
		foe.speed = 0.0
		await _frames(60 * 6)
		var hit: bool = foe.hp < foe.max_hp
		check(hit and main.battle_xp.get(kind, 0.0) > 0.0 and not main.battle_xp.has("tower"),
				"C  %s attacks (or plays) from the tower past its ground reach; the %s trains, not the Tower (%s)" % [kind, kind, str(main.battle_xp.keys())])
		foe.queue_free()
		# The tower takes a beating: that trains the Tower, not the crew.
		main.battle_xp = {}
		t.take_damage(40.0)
		check(main.battle_xp.get("tower", 0.0) > 0.0 and not main.battle_xp.has(kind), "C  %s ...damage the tower takes trains the Tower only" % kind)
		main.wave_active = false
		main.campaign = false


# --- T ---------------------------------------------------------------------------------------

func _tower() -> void:
	await _fresh()
	var t = _hire("tower", Vector2(320, 480))
	var e = _foe("orc", Vector2(320, 380), 1e5)
	e.speed = 0.0
	main.wave_active = true
	await _frames(120)
	check(t != null and e.hp == e.max_hp and not Data.WARRIORS.has("magetower") and not Data.WARRIORS.has("frosttower"),
			"T  a plain Tower doesn't fight by itself (and there's no Mage or Frost Tower any more)")
	e.queue_free()
	main.wave_active = false
	var a = _hire("archer", Vector2(200, 620))
	a.tiers = [2, 0, 0, 2]
	a._apply_upgrades()
	var reach: float = a.attack_range
	main.selected = a
	main.order_move(t.position)
	main.selected = null
	await _frames(60 * 4)
	check(a.garrison == t and t.crew_in == a and a.tiers == [2, 0, 0, 2], "T  an Archer ordered onto it climbs in, keeping its upgrades")
	check(is_equal_approx(a.attack_range, reach * 1.3), "T  ...and reaches 30%% further from the high ground (%.0f -> %.0f)" % [reach, a.attack_range])
	main.selected = t
	main.upgrade_selected(1)
	main.selected = null
	await _frames(2)
	check(is_equal_approx(a.attack_range, reach * 1.35), "T  ...35%% with the tower's first Lookout upgrade (%.0f)" % a.attack_range)
	# The enemy goes for the tower, not the crew.
	main.wave_active = true
	var orc = _foe("orc", t.position + Vector2(0, 28), 1e5)
	orc.speed = 0.0
	var hp_a: float = a.hp
	var hp_t: float = t.hp
	await _frames(60 * 4)
	check(a.hp == hp_a and t.hp < hp_t, "T  an enemy at its foot hits the tower, never the crew (tower %d -> %d)" % [hp_t, t.hp])
	orc.queue_free()
	# Taken out with Climb down (L): it comes down to the foot and stays down.
	main.wave_active = false
	main.selected = a
	main.climb_down()
	await _frames(60)
	check(a.garrison == null and t.crew_in == null and a.visible and a.position.distance_to(t.position) < 60.0,
			"T  Climb down (L) takes it out of the tower, to its foot, and it stays out")
	main.selected = a
	main.order_move(t.position)
	main.selected = null
	await _frames(60 * 2)
	check(a.garrison == t, "T  ...and ordered back onto it, up it goes again")
	main.wave_active = true
	# Sent elsewhere: down it climbs.
	main.selected = a
	main.order_move(Vector2(200, 640))
	main.selected = null
	await _frames(30)
	check(a.garrison == null and t.crew_in == null and a.visible and is_equal_approx(a.attack_range, reach), "T  ordered elsewhere, it climbs down (its reach back to normal)")
	# Hired straight onto it.
	var m = null
	main.gold = 99999
	main.placing_type = "mage"
	main.hire_at(t.position + Vector2(6, 4))
	main.placing_type = ""
	await _frames(60 * 6)
	for w in main.get_warriors():
		if w.kind == "mage":
			m = w
	check(m != null and m.garrison == t, "T  a Mage hired onto an empty Tower walks over and climbs in")
	# The tower wrecked: the crew drops down, alive.
	t.take_damage(1e6)
	await _frames(10)
	check(m.garrison == null and m.is_active() and m.visible, "T  the tower wrecked, its crew drops down unhurt")
	# Who can go up.
	await _fresh()
	var t2 = _hire("tower", Vector2(320, 480))
	var ok := []
	for k in ["frost", "alchemist", "bard"]:
		ok.append(main.tower_for(t2.position, k) == t2)
	var sw = _hire("swordsman", Vector2(200, 620))
	main.selected = sw
	main.order_move(t2.position)
	main.selected = null
	await _frames(60 * 3)
	check(ok.all(func(x): return x) and sw.garrison == null, "T  any ranged troop can go up (Frost Witch, Alchemist, Bard); a Knight can't")


# --- B ---------------------------------------------------------------------------------------

func _ballista() -> void:
	await _fresh()
	# Its flyer bonus adds up along Skyhunter (2x base, 4x at Wyvernbane), never multiplies.
	var bb = _hire("ballista", Vector2(500, 650))
	bb.tiers = [0, 4, 0, 0]
	bb._apply_upgrades()
	check(is_equal_approx(bb.air_mult, 4.0) and bb.air_crit == [0.35, 2.0], "B  Skyhunter IV: 4x on flyers in all (the base 2x included, not multiplied), a 35%% crit (%.1fx)" % bb.air_mult)
	bb.queue_free()
	await _frames(2)
	main.wave_active = true
	var b = _hire("ballista", Vector2(320, 650))
	var orc = _foe("orc", Vector2(320, 520), 1e5)
	orc.speed = 0.0
	var wy = _foe("wyvern", Vector2(380, 470), 1e5)
	wy.speed = 0.0
	await _frames(20)
	check(b.target == wy, "B  a Ballista aims for the Wyvern before the Orc in front of it")
	var w0: float = wy.hp
	await _frames(60 * 3)
	var flyer_hit: float = w0 - wy.hp
	wy.queue_free()
	await _frames(5)
	var o0: float = orc.hp
	await _frames(60 * 3)
	var ground_hit: float = o0 - orc.hp
	check(flyer_hit > 0.0 and flyer_hit >= ground_hit * 1.8, "B  ...and hits flyers about twice as hard (%.0f vs %.0f)" % [flyer_hit, ground_hit])
	# A bolt goes through everything in its line.
	await _fresh()
	main.wave_active = true
	b = _hire("ballista", Vector2(320, 680))
	var front = _foe("orc", Vector2(320, 560), 1e5)
	var behind = _foe("orc", Vector2(320, 470), 1e5)
	front.speed = 0.0
	behind.speed = 0.0
	await _frames(60 * 4)
	check(front.hp < front.max_hp and behind.hp < behind.max_hp, "B  a bolt flies on through every enemy in its line")
	# The Chain Net, and Blasting Tips.
	for p in [1, 1, 1]:
		main.selected = b
		main.upgrade_selected(p)
	main.selected = null
	check(not b.net.is_empty(), "B  Skyhunter's Chain Net: its bolts net flyers")
	var bolt = preload("res://scripts/bolt.gd").new()
	bolt.main = main
	bolt.blast_end = {"share": 1.0, "radius": 60.0, "stun": 1.0}
	bolt.damage = 50.0
	bolt.position = front.position
	main.add_projectile(bolt)
	var f0: float = front.hp
	bolt._burst()
	check(front.hp < f0 and front.stun_timer > 0.0, "B  a Thunderbolt bursts where it stops, and stuns")
	bolt.queue_free()


# --- O ---------------------------------------------------------------------------------------

func _obelisk() -> void:
	await _fresh()
	var ob = _hire("obelisk", Vector2(320, 500))
	var m = _hire("mage", Vector2(360, 560))
	var far = _hire("mage", Vector2(60, 700))
	await _frames(30)
	check(m.buff["damage"] >= 0.15 - 0.001 and far.buff["damage"] < 0.01, "O  a Mage near an Obelisk hits 15% harder (one far off doesn't)")
	main.wave_active = true
	main.selected = ob
	main.upgrade_selected(0)   # Storm Rune
	main.selected = null
	var e = _foe("orc", Vector2(320, 420), 1e5)
	e.speed = 0.0
	await _frames(60 * 4)
	check(e.hp < e.max_hp, "O  its Storm Rune strikes an enemy in reach")
	# Sunfire Glyphs: a glyph burned under the crowd, burning what stands in it.
	await _fresh()
	main.wave_active = true
	ob = _hire("obelisk", Vector2(320, 520))
	main.selected = ob
	main.upgrade_selected(2)
	main.selected = null
	var crowd := []
	for p in [Vector2(300, 420), Vector2(330, 425), Vector2(315, 445)]:
		var x = _foe("orc", p, 1e5)
		x.speed = 0.0
		crowd.append(x)
	await _frames(60 * 2)
	var glyphs: Array = main.corpse_layer.get_children().filter(func(n): return n.get_script() == preload("res://scripts/rune_glyph.gd"))
	check(glyphs.size() == 1 and glyphs[0].position.distance_to(Vector2(315, 430)) < 40.0 and crowd.all(func(x): return x.hp < x.max_hp),
			"O  Sunfire Glyphs: a glyph burns into the ground under the crowd and burns all of them")
	check(crowd.all(func(x): return x.burn_timer > 0.0 and x.burn_dps >= 4.0 - 0.01), "O  ...and sets them on fire")
	# Rift Rune: the enemy furthest down the field thrown back up it.
	await _fresh()
	main.wave_active = true
	ob = _hire("obelisk", Vector2(320, 520))
	main.selected = ob
	main.upgrade_selected(3)
	main.selected = null
	var low = _foe("orc", Vector2(300, 600), 1e5)
	var high = _foe("orc", Vector2(360, 440), 1e5)
	low.speed = 0.0
	high.speed = 0.0
	await _frames(60)
	check(low.position.y < 600.0 - 50.0 and absf(high.position.y - 440.0) < 10.0, "O  Rift Rune: the enemy furthest down the field is thrown back up it (%d -> %d)" % [600, low.position.y])
	var boss = _foe("warlord", Vector2(320, 600), 1e5)
	boss.boss = true
	boss.speed = 0.0
	low.queue_free()
	high.queue_free()
	await _frames(60 * 9)
	check(absf(boss.position.y - 600.0) < 10.0, "O  ...but not a boss")
	# None of it does what the Medic Bay or War Statue does.
	var fx_keys := []
	for path in Data.WARRIORS["obelisk"]["paths"]:
		for tier in path["tiers"]:
			fx_keys.append_array(tier["effect"].keys())
	check(not fx_keys.any(func(k): return k.begins_with("aura_") or k in ["regen", "revive", "heal_area", "slow", "stun"]),
			"O  no Obelisk upgrade heals, revives, guards, slows, stuns or boosts allies like the Medic Bay or War Statue (%s)" % ", ".join(fx_keys))


# --- S ---------------------------------------------------------------------------------------

func _sappers() -> void:
	await _fresh()
	main.wave_active = true
	var b = _hire("ballista", Vector2(500, 560))
	var hp0: float = b.hp
	var sap = _foe("sapper", Vector2(330, 420), 1e5)   # (sturdy: a Ballista would shoot an ordinary one down first)
	var start: Vector2 = sap.position
	var went := false
	for i in 60 * 8:
		await process_frame
		if not is_instance_valid(sap) or sap.dead:
			break
		if sap.position.x > start.x + 60.0:
			went = true
	check(went and b.hp < hp0 - 100.0, "S  a Sapper goes for the Ballista (not the castle) and blows up against it (%d -> %d)" % [hp0, b.hp])
	# Warned: the Sapper's mark is on it and the player's told; at it, the charge takes time
	# to plant, and killing the Sapper then means no blast.
	await _fresh()
	main.wave_active = true
	var b2 = _hire("cannon", Vector2(500, 560))
	var sap2 = _foe("sapper", Vector2(420, 470), 1e5)
	var told := false
	var lit := -1.0
	for i in 60 * 6:
		await process_frame
		if "Sapper's going for your" in main.hud.message_label.text:
			told = true
		if is_instance_valid(sap2) and sap2.fuse >= 0.0:
			lit = sap2.fuse
			break
	check(told and is_instance_valid(sap2) and sap2.sap_target == b2 and lit > sap2.FUSE, "S  told, marked for the player, the Sapper plants its charge at the Cannoneer (%.1fs to go, not %.1fs)" % [lit, sap2.FUSE])
	var hp_c: float = b2.hp
	sap2.take_damage(1e6)
	await _frames(60 * 2)
	check(b2.hp == hp_c and b2.is_active(), "S  ...killed while the fuse fizzes: no blast, the Cannoneer's whole")
	await _fresh()
	main.wave_active = true
	var lone = _foe("sapper", Vector2(320, 300))
	var y0: float = lone.position.y
	await _frames(60 * 2)
	check(is_instance_valid(lone) and lone.position.y > y0 + 30.0 and lone.sap_target == null, "S  ...with none in reach it makes for the castle as before")
	main.placing_type = "barricade"
	main._wall_click(Vector2(200, 520))
	main._wall_click(Vector2(320, 520))
	main.placing_type = ""
	await _frames(70)
	check(is_instance_valid(lone) and lone.sap_target != null and lone.sap_target.get_script() == preload("res://scripts/barricade.gd"), "S  ...and goes for a wall in its reach too")


# --- U ---------------------------------------------------------------------------------------

func _unlocks() -> void:
	check(CD.FACTIONS["stonehollow"]["unlocks"].has("tower") and CD.FACTIONS["stonehollow"]["unlocks"].has("ballista")
			and CD.FACTIONS["spires"]["unlocks"].has("obelisk") and not CD.FACTIONS["greenwood"]["unlocks"].has("tower"),
			"U  Stonehollow brings Towers and Ballistae, the Conclave the Arcane Obelisk")
	var emps: Array = Data.WARRIORS.keys().filter(func(k): return Data.WARRIORS[k].get("emplacement", false))
	check(emps.size() == 8 and emps.has("ballista") and emps.has("obelisk"), "U  still eight emplacements (%s)" % ", ".join(emps))
