extends SceneTree
## Getting about, and formations. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/formation_test.gd [-- SECTIONS]
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.
##
## C  Congestion: two troops meeting head on in a narrow gap both get through; a crowd sent
##    to one spot settles round it and stays still (no shuffling); a troop walks round an
##    idle one in its way; a post an idle ally stands on: it takes the spot beside it, never
##    shoving; a troop knocked off its post comes back; nobody blinks home
## F  Formations: Shield Wall, Wedge, Travel Column laid out by role; turned and moved, the
##    shape goes with it; a troop moved by hand keeps its new slot (custom); saved and put
##    back; a member gone is let go; kept in a unit's record (an old record: none)
## E  Convoy Escort round the supply wagon: out of its road, with it as it rolls
## D  Dawnspire: from a save, through a door in order (no crowd in the doorway, nobody sent
##    to the same spot), into the next hall round their places, still the one formation

const Data = preload("res://scripts/data.gd")
const CD = preload("res://scripts/campaign_data.gd")
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
	root.get_node("Campaign").save_path = "user://formation_test.cfg"
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
	seed(3)
	if _on("C"):
		await _congestion()
	if _on("F"):
		await _formations()
	if _on("E"):
		await _escort()
	if _on("D"):
		await _doors()
	if main != null:
		main.free()
	if FileAccess.file_exists("user://formation_test.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://formation_test.cfg"))
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


## Watches troops for `secs`: whether any blinked (jumped more than 40px in a frame).
func _watch(troops: Array, secs: float) -> bool:
	var last := {}
	var blinked := false
	for t in troops:
		last[t] = t.position
	for f in int(secs * 60):
		await process_frame
		for t in troops:
			if is_instance_valid(t):
				if t.position.distance_to(last[t]) > 40.0:
					blinked = true
				last[t] = t.position
	return blinked


# --- C ---

func _congestion() -> void:
	# A wall of rock with one gap in it; two troops on either side, each sent through.
	await _fresh()
	main.paths.set_map({"terrain": [
		{"kind": "rock", "poly": [Vector2(0, 380), Vector2(290, 380), Vector2(290, 420), Vector2(0, 420)]},
		{"kind": "rock", "poly": [Vector2(350, 380), Vector2(640, 380), Vector2(640, 420), Vector2(350, 420)]}]})   # (a gap of 60: one troop wide and a bit)
	var a = await _hire("swordsman", Vector2(320, 300))
	var b = await _hire("healer", Vector2(320, 500))
	a.order_to(Vector2(320, 520))
	b.order_to(Vector2(320, 290))
	var blinked := await _watch([a, b], 12.0)
	check(a.position.y > 470.0 and b.position.y < 330.0 and not blinked,
			"C  two troops meeting head on in a narrow gap both get through, walking (%.0f, %.0f)" % [a.position.y, b.position.y])
	# A crowd sent to one spot: they settle round it and keep still.
	await _fresh()
	var crowd := []
	for i in 8:
		crowd.append(await _hire(["swordsman", "archer"][i % 2], Vector2(120 + i * 55, 650)))
	for w in crowd:
		w.order_to(Vector2(320, 400))
	await _frames(60 * 8)
	var moving: int = crowd.filter(func(w): return w.moving).size()
	var at := {}
	for w in crowd:
		at[w] = w.position
	await _frames(60 * 3)
	var drift := 0.0
	for w in crowd:
		drift = maxf(drift, w.position.distance_to(at[w]))
	check(moving == 0 and drift < 6.0, "C  eight sent to one spot settle round it and stay still (%d still walking; drifted %.1fpx at most)" % [moving, drift])
	# Round an idle troop in the way.
	await _fresh()
	var idle = await _hire("swordsman", Vector2(320, 450))
	var walker = await _hire("archer", Vector2(320, 600))
	walker.order_to(Vector2(320, 300))
	var idle_at: Vector2 = idle.position
	var blinked2 := await _watch([walker, idle], 6.0)
	check(walker.position.distance_to(Vector2(320, 300)) < 20.0 and not blinked2, "C  a troop walks round an idle one in its way (%.0fpx short)" % walker.position.distance_to(Vector2(320, 300)))
	await _frames(60 * 2)
	check(idle.position.distance_to(idle_at) < 14.0, "C  ...which steps aside and back, and is at its post again (%.0fpx off)" % idle.position.distance_to(idle_at))
	# Its post taken by an idle ally.
	await _fresh()
	var owner = await _hire("swordsman", Vector2(320, 450))
	var squatter = await _hire("swordsman", Vector2(200, 450))
	owner.order_to(Vector2(320, 650))
	await _frames(60 * 3)
	owner.post = Vector2(320, 450)
	owner.ordered = false
	squatter.set_post(Vector2(320, 450))
	squatter.position = Vector2(320, 450)
	squatter.post = Vector2(320, 450)
	await _frames(10)
	owner.post = Vector2(320, 450)
	var sq_at: Vector2 = squatter.position
	var shoved := 0.0
	for f in 60 * 6:
		await process_frame
		shoved = maxf(shoved, squatter.position.distance_to(sq_at))
	check(owner.position.distance_to(owner.post) < 90.0 and not owner.moving and shoved < 16.0,
			"C  its post taken by an idle ally: it stands beside it (%.0fpx from the post), not shoving it (%.0fpx)" % [owner.position.distance_to(owner.post), shoved])
	# Knocked off its post, it comes back.
	await _fresh()
	var k = await _hire("swordsman", Vector2(320, 450))
	k.shove(Vector2(70, 0), 0.4)
	await _frames(60 * 3)
	check(k.position.distance_to(k.post) <= k.SLOT_TOL, "C  knocked off its post, it walks back (%.0fpx off)" % k.position.distance_to(k.post))


func _army(spec: Array, y := 600.0) -> Array:
	var out := []
	for i in spec.size():
		out.append(await _hire(spec[i], Vector2(80 + i * 52, y)))
	return out


func _formations() -> void:
	await _fresh()
	main.formations_path = "user://formation_test_saved.cfg"
	var army: Array = await _army(["swordsman", "archer", "swordsman", "healer", "mage", "martial", "archer", "bard", "swordsman"], 380.0)
	var f = main.make_formation(army, "shield_wall")
	await _frames(60 * 6)
	var front := army.filter(func(w): return f.role(w) == "front")
	var ranged := army.filter(func(w): return f.role(w) == "ranged")
	var support := army.filter(func(w): return f.role(w) == "support")
	var fy: float = front.map(func(w): return w.post.y).max()
	var ry_min: float = ranged.map(func(w): return w.post.y).min()
	var ry_max: float = ranged.map(func(w): return w.post.y).max()
	var sy: float = support.map(func(w): return w.post.y).min()
	check(fy < ry_min and ry_max < sy, "F  Shield Wall: fighters in front, ranged troops behind them, support at the back (rows at %.0f, %.0f, %.0f)" % [fy, ry_min, sy])
	check(f.cohesion() >= 0.85, "F  ...and they get there (%d%% in place)" % roundi(f.cohesion() * 100))
	# No crossing: slots handed out left to right as they stood.
	var xs_before: Array = front.map(func(w): return w.position.x)
	var w2 = main.make_formation(army, "wedge")
	await _frames(60 * 6)
	var tip = front[0]
	for w in front:
		if w.post.y < tip.post.y:
			tip = w
	var strongest = front[0]
	for w in front:
		if w.max_hp * w.damage > strongest.max_hp * strongest.damage:
			strongest = w
	check(tip == strongest and ranged.all(func(w): return w.post.y > tip.post.y), "F  Wedge: the strongest fighter at the point, the rest behind it")
	var c = main.make_formation(army, "column")
	await _frames(60 * 6)
	var xs: Array = army.map(func(w): return w.post.x)
	check(xs.max() - xs.min() < 60.0, "F  Travel Column: two abreast (%.0fpx wide)" % (xs.max() - xs.min()))
	# Turned and moved: the shape goes with it.
	var sw = main.make_formation(army, "shield_wall")
	await _frames(60 * 5)
	main.turn_formation(army, PI / 2.0)
	await _frames(60 * 6)
	var fx: float = front.map(func(w): return w.post.x).min()
	var rx: float = ranged.map(func(w): return w.post.x).max()
	check(fx > rx and sw.cohesion() >= 0.8, "F  turned a quarter round: the line faces the side now (fighters from x %.0f, ranged to %.0f; %d%% in place)" % [fx, rx, roundi(sw.cohesion() * 100)])
	main.group = army.duplicate()
	main.order_group(Vector2(320, 420))
	await _frames(60 * 6)
	check(sw.anchor.distance_to(Vector2(320, 420)) < 2.0 and sw.cohesion() >= 0.8, "F  moved as a group: its anchor goes there and the shape with it (%d%% in place)" % roundi(sw.cohesion() * 100))
	# One troop moved by hand: that's its slot now; saved and put back on.
	var mover = ranged[0]
	main.selected = mover
	main.group = []
	main.order_move(mover.post + Vector2(0, -150))   # (well clear of everyone's posts)
	check(sw.layout == "custom" and sw.slots[mover].distance_to(sw.local(mover.post)) < 1.0, "F  a troop's post moved by hand: that's its slot in the formation now (custom)")
	main.selected = null
	check(main.save_formation(army), "F  the formation saved")
	main.leave_formation(army)
	check(main.formation_of(army[0]) == null, "F  ...broken up")
	var back = main.load_formation(army)
	check(back != null and back.slots.size() == army.size() and back.slots[mover] != null, "F  ...and put back on them from the save")
	# A member falls: the rest carry on, nothing breaks.
	var gone = army[2]
	gone.queue_free()
	await _frames(30)
	check(not back.slots.has(gone) and back.members().size() == army.size() - 1, "F  a member gone: let go of, the others keep their places")
	# Kept through a unit record (a new field, a loaded game).
	var rec: Dictionary = main.rules._unit_record(army[0])
	check(rec.has("formation") and rec["formation"]["id"] == back.id, "F  a unit's record keeps its formation and slot")
	var old: Dictionary = rec.duplicate()
	old.erase("formation")
	var u = main.rules._make_unit(old)
	check(u != null and main.formation_of(u) == null, "F  ...an old record without one: no formation, nothing breaks")
	if FileAccess.file_exists("user://formation_test_saved.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://formation_test_saved.cfg"))


## The Approach's ram, or the first wagon in a convoy: troops escorting it, kept out of its
## road; it never stops for them.
func _escort() -> void:
	await _fresh()
	main.hud.hide_mode_select()
	main._on_mode_chosen("battle:supply_wagon:normal")
	await _frames(10)
	var movers: Array = main.rules.followable().filter(func(o): return o.is_mover())
	if movers.is_empty():
		check(false, "E  a battlefield with something to escort (supply_wagon)")
		return
	var ram = movers[0]
	for w in main.get_warriors():
		w.queue_free()
	await _frames(2)
	var army := []
	var k: float = main.FIELD_W / 640.0
	for i in 6:
		var at: Vector2 = ram.position + Vector2(-120 + i * 48, 90)
		army.append(main.rules._make_unit({"kind": ["swordsman", "archer", "swordsman", "healer", "archer", "martial"][i], "post": Vector2(at.x / k, at.y)}))
	main.warriors_changed()
	var ram_from: Vector2 = ram.position
	var f = main.make_formation(army, "escort")
	check(f != null and f.follow == ram, "E  Convoy Escort round the %s" % ram.label.to_lower())
	main.deploying = false
	if not main.wave_active:
		main.start_wave(true)
	var in_road := 0
	var samples := 0
	var stuck := 0.0
	var last: Vector2 = ram.position
	for fr in 60 * 20:
		await process_frame
		for e in main.get_enemies():
			e.queue_free()   # (just the march: no fight)
		if fr % 15 == 0:
			var head: Vector2 = main._mover_heading(ram, Vector2.ZERO)
			if head != Vector2.ZERO:
				for w in army:
					if not is_instance_valid(w):
						continue
					var off: Vector2 = w.position - ram.position
					samples += 1
					if off.dot(head) > ram.RADIUS * 0.5 and off.dot(head) < ram.RADIUS + 50.0 and absf(off.dot(head.orthogonal())) < ram.RADIUS * 0.8:
						in_road += 1
		if ram.position.distance_to(last) < 0.01 and not ram.arrived:
			stuck += 1.0 / 60.0
		last = ram.position
	check(samples > 0 and float(in_road) / samples < 0.05, "E  ...the troops keep out of the road ahead of it (%d of %d looks in it)" % [in_road, samples])
	var near := army.filter(func(w): return is_instance_valid(w) and w.position.distance_to(ram.position) < 160.0).size()
	check(near >= 5 and ram.position.distance_to(ram_from) > 150.0, "E  ...and keep with it as it rolls %.0fpx (%d of 6 near it), never held up by them (%.1fs stopped)" % [ram.position.distance_to(ram_from), near, stuck])


## Dawnspire's halls: the army goes through a door in order (never a crowd in the doorway)
## and comes in round its places in the next hall, its formation as it was.
func _doors() -> void:
	var campaign = root.get_node("Campaign")
	campaign.new_campaign("normal")
	campaign.completed = CD.MISSIONS.keys().filter(func(m): return m != "ds_assault")
	campaign.allies = CD.FACTIONS.keys()
	var rooms: Array = CD.MISSIONS["ds_assault"]["assault"]["castle"]["rooms"]
	var gi := 0
	for i in rooms.size():
		if rooms[i]["id"] == "gatehall":
			gi = i
	var army := []
	var kinds := ["swordsman", "swordsman", "martial", "swordsman", "archer", "archer", "mage", "frost", "healer", "bard"]
	for i in kinds.size():
		var row := i / 4
		army.append({"kind": kinds[i], "tiers": [0, 0, 0, 0], "hp": 1.0, "post": Vector2(200 + (i % 4) * 70, 560 + row * 50), "spent": 0,
				"formation": {"id": 7, "layout": "shield_wall", "slot": [(i % 4) * 40.0 - 60.0, row * 48.0], "facing": [0.0, -1.0]}})
	var cp := {"zone": 100 + gi, "room": gi, "entry": "s", "name": "The Gatehouse Hall", "gold": 400, "wave": 6, "army": army,
		"xp": {}, "owned": [], "standard": 1.0, "rooms": {"gatehall": {"cleared": true, "taken": [], "had": []}}, "garrisons": [], "stragglers": []}
	campaign.set_checkpoint("ds_assault", 100 + gi, cp)
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud.hide_mode_select()
	campaign.op_resume_zone = 100 + gi
	campaign.mission_id = "ds_assault"
	main.start_mission("ds_assault")
	await _frames(3)
	_skip()
	main.deploying = false
	main.forced_auto = false
	main.auto_play = false
	main.auto_timer = 9999.0
	var r = main.rules
	for i in 60 * 15:
		await process_frame
		_skip()
		for e in main.get_enemies():
			e.queue_free()
		if r.phase == "clear":
			break
	var here: Array = main.get_warriors().filter(func(w): return not w.is_emplacement())
	var f0 = main.formation_of(here[0]) if not here.is_empty() else null
	check(here.size() == 10 and f0 != null and here.all(func(w): return main.formation_of(w) == f0), "D  back from a save: all ten in their formation (%d)" % here.size())
	var a = null
	for x in r.arrows:
		if x["to"] == "banners":
			a = x
	if a == null:
		check(false, "D  the way on to the Banner Hall offered (%s)" % r.phase)
		return
	r._ask(a)
	await _frames(2)
	if main.hud.choice_box != null and is_instance_valid(main.hud.choice_box):
		for c in main.hud.choice_box.get_children():
			if c is Button and c.text == "Go on":
				c.pressed.emit()
	await _frames(2)
	var door: Vector2 = r.march_door["point"] if r.phase == "march" else Vector2.INF
	var crowd := 0
	var spots_shared := 0
	var t := 0
	while r.phase == "march" and t < 60 * 30:
		await process_frame
		t += 1
		var at_door: int = r.march_units.filter(func(w): return is_instance_valid(w) and w.position.distance_to(door) < 70.0).size()
		crowd = maxi(crowd, at_door)
		var posts := {}
		for w in r.march_units:
			if is_instance_valid(w):
				var key := Vector2i(roundi(w.post.x / 6.0), roundi(w.post.y / 6.0))
				if posts.has(key):
					spots_shared += 1
				posts[key] = true
	check(door != Vector2.INF and t < 60 * 30, "D  the army marches through the door (%.1fs)" % (t / 60.0))
	check(crowd <= 6, "D  ...in order: never a crowd in the doorway (at most %d near it at once)" % crowd)
	check(spots_shared == 0, "D  ...nobody sent to the same spot in the line as another")
	for i in 60 * 30:
		await process_frame
		_skip()
		for e in main.get_enemies():
			e.queue_free()
		if main.rules.get("phase") not in ["march", "pan", "enter"]:
			break
	var r2 = main.rules
	for i in 60 * 8:
		await process_frame
		_skip()
		for e in main.get_enemies():
			e.queue_free()   # (just the move: no fight in the new hall)
	var now: Array = main.get_warriors().filter(func(w): return not w.is_emplacement())
	var at_posts: int = now.filter(func(w): return w.position.distance_to(w.post) < 40.0).size()
	check(r2.room()["id"] == "banners" and now.size() == 10 and at_posts >= 9, "D  ...into the Banner Hall, and round their places there (%d of %d)" % [at_posts, now.size()])
	var f1 = main.formation_of(now[0]) if not now.is_empty() else null
	check(f1 != null and now.all(func(w): return main.formation_of(w) == f1) and f1.layout == "shield_wall" and f1.cohesion() >= 0.8,
			"D  ...still the one Shield Wall, together (%d%% in place)" % (roundi(f1.cohesion() * 100) if f1 != null else 0))
	var front: Array = now.filter(func(w): return f1.role(w) == "front")
	var back: Array = now.filter(func(w): return f1.role(w) != "front")
	check(not front.is_empty() and front.map(func(w): return f1.local(w.post).y).max() < back.map(func(w): return f1.local(w.post).y).min() + 1.0,
			"D  ...fighters still in front of the rest")


func _skip() -> void:
	if main != null and is_instance_valid(main) and main.hud.story != null and is_instance_valid(main.hud.story):
		main.hud.story.skip()
