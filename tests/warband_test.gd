extends SceneTree
## Enemy warbands (scripts/enemies/warband.gd): a wave is cut into bands (each squad a band of its
## own), a band comes on at one place, forms up in its ranks (shields and brutes in front,
## goblins and sappers next, drummers, then archers and Boltflingers, casters at the back,
## wolves on the wings), marches on at its slowest's pace keeping them, holds its ranks
## under fire from afar, and charges once your troops are close. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/warband_test.gd
## Exits 1 if anything failed. (Kept in the repository so it's always there to run.)

const Warband = preload("res://scripts/enemies/warband.gd")

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
	main.setup.choose_mode(mode)
	await _frames(2)
	main.missions._lock_portrait(true)
	await _frames(2)
	main.wave_active = true


## Sends these kinds in as one wave's worth of bands, and waits till they've all come on.
func _send(kinds: Array) -> Array:
	main.wave_squads = []
	main.spawn_queue = main.waves._banded(kinds, 1)
	main.spawn_interval = 0.2
	main.spawn_timer = 0.0
	await _frames(int(kinds.size() * 0.2 * 60.0) + 20)
	return main.battlefield.get_enemies()


func _of(list: Array, kind: String) -> Array:
	return list.filter(func(e): return e.kind == kind)


func _run() -> void:
	_cutting()
	await _forming()
	await _marching()
	await _charging()
	await _tutorial()
	if main != null:
		main.free()
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _cutting() -> void:
	var kinds := ["goblin", "goblin", "orc", "bat", "goblin", "goblin", "wolf", "goblin", "goblin", "skeleton_archer",
			"shieldbearer", "sapper", "sapper", "goblin", "goblin", "wyvern", "warlord"]
	var ids: Array = Warband.cut(kinds, [["shieldbearer", "sapper", "sapper"]], 0)
	check(ids[3] == -1 and ids[15] == -1, "Fliers march in no band (%s)" % str(ids))
	var squad_id: int = ids[10]
	check(squad_id >= 0 and ids[11] == squad_id and ids[12] == squad_id and ids[9] != squad_id and ids[13] != squad_id,
			"A squad (Shieldbearer and two Sappers) is a band of its own")
	var count := {}
	for b in ids:
		if b >= 0:
			count[b] = int(count.get(b, 0)) + 1
	check(count.values().all(func(n): return n <= Warband.SIZE + 2), "No band is much bigger than %d (%s)" % [Warband.SIZE, str(count)])
	var tail: Array = Warband.cut(["goblin", "goblin", "goblin", "goblin", "goblin", "goblin", "goblin", "wolf"], [], 0)
	check(tail.all(func(b): return b == 0), "One left over joins the band before, rather than go alone (%s)" % str(tail))
	check(ids[16] >= 0, "A Warlord marches with a band (in its front rank)")


func _forming() -> void:
	await _fresh()
	var foes: Array = await _send(["shieldbearer", "goblin", "boltflinger", "drummer", "wolf", "goblin", "warmage"])
	check(foes.size() == 7 and foes.all(func(e): return e.band != null), "All seven come on in one band (%d, banded: %d)" % [foes.size(), foes.filter(func(e): return e.band != null).size()])
	var xs := foes.map(func(e): return e.position.x)
	check(xs.max() - xs.min() < 150.0, "...at one place along the top (spread %.0f)" % (xs.max() - xs.min()))
	var band = foes[0].band
	for i in 600:
		await process_frame
		if band.state != "muster":
			break
	check(band.state == "advance", "It forms up, then advances (%s)" % band.state)
	await _frames(60)
	var off := 0.0
	for e in foes:
		off = maxf(off, e.position.distance_to(band.place_of(e)))
	check(off < 16.0, "...every one in its place as it goes (furthest out %.0f px)" % off)
	var y := func(k): return _of(foes, k)[0].position.y
	var x := func(k): return absf(_of(foes, k)[0].position.x - band.anchor.x)
	check(absf(y.call("shieldbearer") - y.call("goblin")) < 10.0 and x.call("shieldbearer") + 10.0 < x.call("goblin"),
			"The front rank: the Shieldbearer in the middle, the goblins out to its ends (%.0f, %.0f out)" % [x.call("shieldbearer"), x.call("goblin")])
	check(y.call("shieldbearer") > y.call("boltflinger") + 10.0, "...the Boltflinger right behind it (%.0f vs %.0f)" % [y.call("shieldbearer"), y.call("boltflinger")])
	check(y.call("boltflinger") > y.call("drummer") + 10.0, "...then the Drummer (%.0f vs %.0f)" % [y.call("boltflinger"), y.call("drummer")])
	check(y.call("drummer") > y.call("warmage") + 10.0, "...and the Horde Mage at the back (%.0f vs %.0f)" % [y.call("drummer"), y.call("warmage")])
	var wolf = _of(foes, "wolf")[0]
	var mid: float = band.anchor.x
	var widest := 0.0
	for e in foes:
		if e != wolf:
			widest = maxf(widest, absf(e.position.x - mid))
	check(absf(wolf.position.x - mid) > widest + 20.0, "The wolf is out on a wing (%.0f out, the ranks %.0f)" % [absf(wolf.position.x - mid), widest])
	var bolt = _of(foes, "boltflinger")[0]
	main.hit_from = bolt.position + Vector2(0, 220)
	var cut: float = bolt._shield_cut()
	main.hit_from = Vector2.INF
	check(cut > 0.0, "The Boltflinger is in the Shieldbearer's cover from shots in front (%.0f%% turned aside)" % (cut * 100.0))


func _marching() -> void:
	await _fresh()
	var foes: Array = await _send(["ogre", "goblin", "goblin", "goblin"])
	var band = foes[0].band
	for i in 900:
		await process_frame
		if band.state == "advance":
			break
	var ogre = _of(foes, "ogre")[0]
	var start: Vector2 = band.anchor
	var gob = _of(foes, "goblin")[0]
	var gob_y: float = gob.position.y
	await _frames(240)
	var went: float = band.anchor.y - start.y
	check(went > 30.0 and went <= ogre.speed * 4.0 + 2.0, "It marches at its slowest's pace: the Ogre's (%.0f px in 4 s, the Ogre's speed %.0f)" % [went, ogre.speed])
	check(gob.position.y - gob_y < gob.speed * 4.0 * 0.7, "...the goblins don't run on ahead (%.0f px)" % (gob.position.y - gob_y))
	var off := 0.0
	for e in foes:
		off = maxf(off, e.position.distance_to(band.place_of(e)))
	check(off < 24.0, "...and every one keeps its place (furthest out %.0f px)" % off)
	var gobs := _of(foes, "goblin")
	check(gobs.all(func(g): return absf(g.position.x - band.anchor.x) > absf(ogre.position.x - band.anchor.x) + 20.0 and g.position.y < ogre.position.y + 4.0),
			"The Ogre in the middle of the front rank, the goblins out to either side of it")
	# Shot from afar: it keeps its ranks.
	gob.take_damage(5.0)
	await _frames(30)
	check(band.state == "advance" and gob.band == band, "Hurt by a shot from afar, it keeps its ranks")


func _charging() -> void:
	await _fresh()
	var foes: Array = await _send(["shieldbearer", "goblin", "goblin", "skeleton_archer"])
	var band = foes[0].band
	for i in 600:
		await process_frame
		if band.state == "advance":
			break
	main.gold = 100000
	main.placing_type = "swordsman"
	main.hiring.hire_at(Vector2(band.anchor.x, band.anchor.y + 260.0))
	main.placing_type = ""
	var w = main.battlefield.get_warriors()[-1]
	var charged := false
	for i in 900:
		await process_frame
		if band.state == "charge":
			charged = true
			break
	check(charged, "Your troops close: the band charges")
	var gap: float = band.anchor.distance_to(w.position)
	check(gap <= Warband.ENGAGE + 30.0, "...once they're near its front (%.0f px)" % gap)
	check(foes.all(func(e): return not is_instance_valid(e) or e.band == null), "...every one off about its own work")
	check(not main.bands.values().has(band), "...and the band is gone")


func _tutorial() -> void:
	await _fresh("tutorial")
	main.spawn_queue = main.waves._banded(["goblin", "goblin", "orc"], 1)
	check(main.spawn_queue.all(func(q): return int(q[2]) == -1), "The Tutorial's foes come on as before, in no band")
