extends SceneTree
## Phase 4 (the North) foundations. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/north_test.gd
##   G  ground     stairs are climbed slowly, ice (a frozen lake) is walked, thin ice is
##                 walked until it breaks; none of them blocks
##   I  thin ice   only heavy enemies crack it; a crack gives warning and a countdown, then
##                 the patch gives way: enemies on it are lost (a boss climbs out onto the
##                 shore, stunned); troops on a cracking patch run for the shore, and one
##                 that can't (stunned) falls through, goes down and is hauled ashore; it's
##                 open water after, every lane still reaching the castle; nothing can be
##                 built on thin ice
##   F  Frostmarch the Frozen Pass is fair whatever came north: two Frost Witches lent, more
##                 to be hired if they fall, so Slimes can always be hurt; blizzards blow;
##                 the Vigil's stones stay reachable with every patch of thin ice broken;
##                 Whiteout's sled road keeps well clear of thin ice, and enemies far from
##                 your troops fade into the snow
##   B  blizzard   gusts are announced before they blow, then slow everyone's movement and
##                 ranged fire for a while; Frost Witches aren't slowed and get stronger;
##                 Classic has none
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.

const TEST_SAVE := "user://north_test_campaign.cfg"

# A small test field: a rock on the left, thin ice in the middle (A) and bottom-left (B),
# a frozen lake on the right, and stairs near the gate.
const MAP := {"name": "North test", "biome": "snow", "lanes": [[40, 600]], "castle": "keep",
	"terrain": [
		{"kind": "rock", "poly": [Vector2(0, 300), Vector2(180, 300), Vector2(180, 420), Vector2(0, 420)]},
		{"kind": "thin_ice", "poly": [Vector2(200, 300), Vector2(440, 300), Vector2(440, 420), Vector2(200, 420)]},
		{"kind": "thin_ice", "poly": [Vector2(20, 480), Vector2(170, 480), Vector2(170, 580), Vector2(20, 580)]},
		{"kind": "ice", "poly": [Vector2(480, 480), Vector2(620, 480), Vector2(620, 580), Vector2(480, 580)]},
		{"kind": "stairs", "poly": [Vector2(260, 600), Vector2(380, 600), Vector2(380, 680), Vector2(260, 680)]}],
	"no_build": []}

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


func _fresh(map := MAP, mission := {}) -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud.hide_mode_select()
	main.records_path = ""
	main.choose_mode("normal")
	await _frames(2)
	main._lock_portrait(true)
	await _frames(2)
	main.gold = 99999
	main.spawn_queue.clear()
	main.paths.set_map(map)
	main.hazards.setup(main, map, mission)
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


func _hire(kind: String, at: Vector2):
	main.placing_type = kind
	main.hire_at(at)
	main.placing_type = ""
	var w = main.get_warriors()[-1]
	w.position = w.post
	return w


func _run() -> void:
	await _ground()
	await _ice()
	await _blizzard()
	await _frostmarch()
	if main != null:
		main.free()
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


# --- Ground ---------------------------------------------------------------------------------

func _ground() -> void:
	await _fresh()
	var paths = main.paths
	var stairs := Vector2(320, 640)
	var lake := Vector2(550, 530)
	var thin := Vector2(320, 360)
	check(not paths.blocked(stairs, 10.0) and is_equal_approx(paths.wade_factor(stairs), 0.65), "G  stairs: walkable, climbed at 65%% speed (%.2f)" % paths.wade_factor(stairs))
	check(not paths.blocked(lake, 10.0) and paths.wade_factor(lake) == 1.0, "G  a frozen lake: walked at full speed")
	check(not paths.blocked(thin, 10.0) and paths.troop_can_stand(thin), "G  thin ice: walkable while whole")
	check(paths.wade_factor(Vector2(320, 560)) == 1.0, "G  ...and open ground is unchanged")


# --- Thin ice -------------------------------------------------------------------------------

func _ice() -> void:
	await _fresh()
	var hz = main.hazards
	main.wave_active = true
	check(hz.ice.size() == 2 and hz.ice_state(0) == "whole" and hz.ice_state(1) == "whole", "I  the map's two thin-ice patches, whole")
	# Light enemies never crack it.
	var gob = _foe("goblin", Vector2(300, 330))
	var orc = _foe("orc", Vector2(360, 380))
	await _frames(60 * 4)
	check(hz.ice_state(0) == "whole", "I  a Goblin and an Orc standing on it: it holds")
	# Nothing is built on thin ice (an emplacement couldn't get off); troops may stand there.
	main.placing_type = "tower"
	check(not main.can_post_at(Vector2(320, 360)) and main.can_post_at(Vector2(320, 520)), "I  an emplacement can't be built on thin ice (it can elsewhere)")
	main.placing_type = "swordsman"
	check(main.can_post_at(Vector2(330, 340)), "I  ...a troop can be posted on it")
	main.placing_type = ""
	# Two troops out on the ice, one of them stunned; then a Troll steps onto it.
	var sw = _hire("swordsman", Vector2(400, 400))
	sw.max_hp = 1e6
	sw.hp = 1e6
	var stuck_one = _hire("swordsman", Vector2(330, 340))
	stuck_one.dazed = 30.0   # (stunned: it can't get off)
	var troll = _foe("troll", Vector2(240, 330))
	await _frames(5)
	check(hz.ice_state(0) == "cracking", "I  a Troll steps on: it starts cracking")
	check(hz.ice[0]["t"] > 2.0, "I  ...with %.1fs warning before it goes" % hz.ice[0]["t"])
	await _frames(30)
	check(sw.position.distance_to(Vector2(400, 400)) > 10.0, "I  ...the Swordsman on it drops everything and makes for the shore")
	await _frames(30)
	check(hz.ice_state(0) == "cracking", "I  ...still standing a second later")
	await _frames(int(60 * (hz.CRACK_TIME - 0.9)))
	check(hz.ice_state(0) == "broken", "I  ...and it gives way on time")
	var gone := func(e): return not is_instance_valid(e) or e.dead
	check(gone.call(troll) and gone.call(gob) and gone.call(orc), "I  every enemy on it went through the ice")
	var poly: PackedVector2Array = hz.polys[0]
	check(not Geometry2D.is_point_in_polygon(sw.position, poly) and not main.paths.blocked(sw.position, 16.0) and sw.is_active() and sw.hp == sw.max_hp,
			"I  the Swordsman got off before it broke, unhurt (%s, %d/%d)" % [str(sw.position.round()), sw.hp, sw.max_hp])
	check(not Geometry2D.is_point_in_polygon(sw.post, poly), "I  ...and its post moved off the water with it")
	check(not stuck_one.is_active() and not Geometry2D.is_point_in_polygon(stuck_one.position, poly) and not main.paths.blocked(stuck_one.position, 16.0),
			"I  the stunned one couldn't get off: it fell through, went down, and was hauled onto the shore")
	check(main.paths.blocked(Vector2(320, 360), 4.0), "I  the patch is open water now: nobody crosses it")
	var stuck := []
	for r in [11.0, 14.0, 19.0, 24.0]:
		for x in range(60, 590, 20):
			if main.paths._field(r)["dist"][main.paths._index(main.paths._cell(Vector2(x, 4)))] > 1e9:
				stuck.append([r, x])
	check(stuck.is_empty(), "I  ...and every lane still reaches the castle round it, for every enemy size%s" % ("" if stuck.is_empty() else " (%s)" % str(stuck.slice(0, 3))))
	await _frames(30)
	check(main.paths.troop_can_stand(sw.position) and not main.paths.blocked(sw.position, 16.0), "I  ...the Swordsman can still stand and move where it is")
	# A boss doesn't go under: the Ogre King climbs out onto the shore, stunned.
	var king = _foe("ogre_king", Vector2(95, 530), 1e5)
	king.boss = true
	await _frames(int(60 * (hz.CRACK_TIME + 0.3)))
	var poly_b: PackedVector2Array = hz.polys[1]
	check(hz.ice_state(1) == "broken" and not king.dead and not Geometry2D.is_point_in_polygon(king.position, poly_b) and king.stun_timer > 0.0 and king.hp < 1e5,
			"I  the Ogre King breaks the other patch but climbs out onto the shore, stunned and hurt")


# --- Blizzard -------------------------------------------------------------------------------

func _blizzard() -> void:
	await _fresh({}, {"weather": {"blizzard": {"first": 2.0, "every": 20.0, "length": 3.0, "warn": 1.5}}})
	var hz = main.hazards
	main.wave_active = true
	_foe("orc", Vector2(600, 120))   # (someone on the field, so the wave goes on)
	var sw = _hire("swordsman", Vector2(320, 650))
	sw.max_hp = 1e6
	sw.hp = 1e6
	await _frames(20)
	check(hz.gust_warning() < 0.0 and main.gust == 0.0, "B  no gust and no warning at first")
	await _frames(int(60 * 0.9))
	check(hz.gust_warning() > 0.0 and main.gust == 0.0, "B  a warning before the gust blows (%.1fs to go)" % hz.gust_warning())
	sw.order_to(Vector2(320, 150))
	await _frames(10)
	var p0: Vector2 = sw.position
	await _frames(30)
	var calm: float = sw.position.distance_to(p0)
	await _frames(int(60 * 1.6))
	check(main.gust > 0.95, "B  the gust blows (%.2f)" % main.gust)
	p0 = sw.position
	await _frames(30)
	var gusting: float = sw.position.distance_to(p0)
	check(gusting < calm * 0.88 and gusting > calm * 0.7, "B  troops move slower in it (%.0fpx against %.0fpx in half a second)" % [gusting, calm])
	check(is_equal_approx(hz.rate_factor("archer"), 0.7) and is_equal_approx(hz.speed_factor("orc"), 0.8), "B  ranged fire 30% slower, enemies 20% slower too")
	check(hz.speed_factor("frost") == 1.0 and hz.rate_factor("frost") > 1.15 and hz.power_factor("frost") > 1.25 and hz.power_factor("archer") == 1.0,
			"B  Frost Witches aren't slowed, and they're stronger in it (%.2fx damage, %.2fx rate)" % [hz.power_factor("frost"), hz.rate_factor("frost")])
	var fw = _hire("frost", Vector2(200, 650))
	var archer = _hire("archer", Vector2(440, 650))
	check(fw._power() > 1.25 and fw._rate() > 1.15 and archer._rate() < 0.75, "B  ...and it shows in their own attacks (Frost Witch %.2fx damage, %.2fx rate; Archer %.2fx rate)" % [fw._power(), fw._rate(), archer._rate()])
	await _frames(int(60 * 3.0))
	check(main.gust < 0.05 and hz.gust_left <= 0.0, "B  it eases off after a while")
	# Classic: no hazards at all.
	await _fresh({}, {})
	main.wave_active = true
	await _frames(60 * 3)
	check(not main.hazards.active() and main.gust == 0.0, "B  Classic: no ice, no weather")


# --- Frostmarch's missions -------------------------------------------------------------------

const CD = preload("res://scripts/campaign_data.gd")
const Maps = preload("res://scripts/maps.gd")

## Straight into a northern mission, with the south behind you (Sable won with `south`).
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


func _frostmarch() -> void:
	# The Frozen Pass, coming north with Mercy Vale and Deepdelve (no Archers, no magic).
	await _mission("fm_pass", ["mercyvale", "deepdelve"])
	var lent: Array = main.get_warriors().filter(func(w): return w.kind == "frost")
	check(main.map_id == "frostmarch_pass" and lent.size() == 2 and not main.hazards.blizzard.is_empty(),
			"F  the Frozen Pass: its map, two Frost Witches lent, blizzards blowing")
	var m: Dictionary = CD.MISSIONS["fm_pass"]
	var slimes := 0
	for w in m["pool"]:
		slimes += (m["pool"][w] as Array).count("slime")
	check(slimes > 0 and main.allowed("frost") and not main.allowed("mage") and not main.allowed("martial"),
			"F  ...Slimes come, and with no magic or ki of its own this army can hire Frost Witches here")
	for w in lent:
		w.free()
	main.warriors_changed()
	main.gold = 999
	main.placing_type = "frost"
	main.hire_at(Vector2(320, 600))
	main.placing_type = ""
	var fresh = main.get_warriors().filter(func(w): return w.kind == "frost")
	check(fresh.size() == 1, "F  ...the two lent fallen, another Frost Witch can still be hired")
	main.wave_active = true
	var slime = _foe("slime", fresh[0].position + Vector2(0, -60), 70.0)
	var hp0: float = slime.hp
	await _frames(60 * 3)
	check(not is_instance_valid(slime) or slime.dead or slime.hp < hp0, "F  ...and it hurts a Slime")
	# The Vigil: every stone reachable by your troops with all the thin ice broken.
	await _mission("fm_vigil", ["greenwood", "deepdelve"], ["fm_pass"], ["frostmarch"])
	var hz = main.hazards
	for n in hz.ice.size():
		hz._break(n)
	await _frames(3)
	var unreached := []
	for o in main.rules.objectives():
		var ok := false
		for d in [Vector2(0, 50), Vector2(0, -50), Vector2(50, 0), Vector2(-50, 0)]:
			if main.paths.troop_can_stand(o.position + d) and not main.paths.blocked(o.position + d, 18.0):
				ok = true
		if not ok:
			unreached.append(o.label)
	check(hz.ice.all(func(p): return p["state"] == "broken") and unreached.is_empty(),
			"F  the Vigil: every stone still reachable with all the thin ice broken%s" % ("" if unreached.is_empty() else " (not: %s)" % ", ".join(unreached)))
	# Whiteout: the sled's road keeps clear of thin ice (by more than the sled's size).
	var map: Dictionary = Maps.get_map("frostmarch_crossing")
	var route: Array = map["route"]
	var nearest := INF
	for t in map["terrain"]:
		if t["kind"] != "thin_ice":
			continue
		var poly := PackedVector2Array(t["poly"])
		for i in route.size() - 1:
			for k in 20:
				var q: Vector2 = (route[i] as Vector2).lerp(route[i + 1], k / 20.0)
				var d := INF
				for j in poly.size():
					d = minf(d, q.distance_to(Geometry2D.get_closest_point_to_segment(q, poly[j], poly[(j + 1) % poly.size()])))
				if Geometry2D.is_point_in_polygon(q, poly):
					d = 0.0
				nearest = minf(nearest, d)
	check(nearest > 40.0, "F  Whiteout: the sled's road keeps %dpx clear of any thin ice" % roundi(nearest))
	await _mission("fm_whiteout", ["greenwood", "mercyvale"], ["fm_pass"], ["frostmarch"])
	main.wave_active = true
	var near = _foe("orc", main.rules.wagon.position + Vector2(0, -80))
	var far = _foe("orc", Vector2(560, 150))
	await _frames(5)
	check(near.modulate.a > 0.95 and far.modulate.a < 0.3, "F  ...in the whiteout an enemy far from your troops fades into the snow (%.2f), one near the sled is plain (%.2f)" % [far.modulate.a, near.modulate.a])
