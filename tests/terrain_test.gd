extends SceneTree
## Phase 2 battlefields: terrain, and everything that moves over it. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/terrain_test.gd [-- <groups>]
## Groups (all by default; pass letters to run some, e.g. -- GE):
##   G  grid        shapes become the right cells; Classic has none; every lane reaches the
##                  castle for every enemy size; gaps fit a Warlord; the gate, the mission's
##                  allies and the bot's posts are open ground troops can reach
##   E  enemies     spawn in lanes; full mixed waves (and knockback into rock) never leave a
##                  walking enemy inside terrain; chasers (Slimes too) route round rock to
##                  reach troops and still slow them; Skeleton Archers never shoot from where
##                  melee troops can't reach them (a tight channel, cliffs, the enemy camp)
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.

const Maps = preload("res://scripts/maps.gd")
const CD = preload("res://scripts/campaign_data.gd")
const Data = preload("res://scripts/data.gd")

const TEST_SAVE := "user://terrain_test_campaign.cfg"

var main
var campaign
var fails := 0
var checks := 0
var only := ""


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	only = args[0] if args.size() > 0 else ""
	campaign = root.get_node("Campaign")
	campaign.save_path = TEST_SAVE   # never the player's own campaign
	_run.call_deferred()


func _wants(g: String) -> bool:
	return only == "" or g in only


func _run() -> void:
	if _wants("G"):
		await _grid()
	if _wants("E"):
		await _enemies()
	print("%d checks, %d failed" % [checks, fails])
	if main != null:
		main.free()
	for f in [TEST_SAVE, TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	quit(1 if fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## A fresh game in Classic (normal), then the given map laid on its field ("" for none).
func _fresh(map_id := "") -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud.picking = true
	main.choose_mode("normal")
	main.gold = 99999
	if map_id != "":
		main.paths.set_map(Maps.get_map(map_id))
	await process_frame


## Straight into a campaign mission on its own map (Normal, intro skipped), with the
## earlier territories won so it's open.
func _mission(mid: String, diff := "normal") -> void:
	if main != null:
		main.free()
	campaign.new_campaign(diff)
	if mid == "stonehollow":
		campaign.completed = ["ashwatch"]
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.hud.hide_mode_select()
	main.start_mission(mid)
	await process_frame
	if main.hud.story != null:
		main.hud.story.skip()
	await process_frame
	main.gold = 99999


# --- G: the grid ------------------------------------------------------------------------

func _grid() -> void:
	await _fresh()
	var paths = main.paths
	check(not paths.has_terrain() and not paths.blocked(Vector2(320, 400), 30.0) and paths.direction(Vector2(320, 400), 12.0) == Vector2.ZERO,
			"G  Classic has no terrain: nothing is blocked and enemies march straight down as before")
	check(paths.open_spot(Vector2(320, 400)) == Vector2(320, 400) and paths.troop_can_stand(Vector2(5, 120)) and paths.melee_can_reach(Vector2(320, 50)),
			"G  ...and every terrain check passes everything through")
	# A known shape: a 64px square at (96..160, 192..256).
	paths.set_map({"terrain": [{"kind": "rock", "poly": [Vector2(96, 192), Vector2(160, 192), Vector2(160, 256), Vector2(96, 256)]}]})
	var wrong := []
	for c in [Vector2i(7, 13), Vector2i(3, 13), Vector2i(7, 9), Vector2i(12, 18), Vector2i(20, 30)]:
		var p: Vector2 = paths._center(c)
		var expect := 0.0
		var dx := maxf(maxf(96.0 - p.x, p.x - 160.0), 0.0)
		var dy := maxf(maxf(192.0 - p.y, p.y - 256.0), 0.0)
		expect = Vector2(dx, dy).length()
		if absf(paths.clear[paths._index(c)] - expect) > 0.01:
			wrong.append("%s: %.1f, not %.1f" % [c, paths.clear[paths._index(c)], expect])
	check(wrong.is_empty(), "G  a square's cells: inside 0, outside the exact distance to it%s" % ("" if wrong.is_empty() else " (" + ", ".join(wrong) + ")"))
	check(paths.blocked(Vector2(128, 224), 1.0) and paths.blocked(Vector2(90, 224), 10.0) and not paths.blocked(Vector2(80, 224), 10.0),
			"G  blocked(): inside the square, 6px off it with radius 10, but not 16px off")
	check(paths.segment_blocked(Vector2(60, 224), Vector2(200, 224), 4.0) and not paths.segment_blocked(Vector2(60, 300), Vector2(200, 300), 30.0),
			"G  a walk straight through it is blocked; one 44px below it isn't, even 30px wide")
	var out: Vector2 = paths.push_out(Vector2(100, 224), 18.0)
	check(not paths.blocked(out, 18.0) and out.distance_to(Vector2(78, 224)) < 1.0, "G  push_out moves a unit inside it out through the nearest edge (%s)" % out)
	var slid: Vector2 = paths.slide(Vector2(76, 210), Vector2(80, 214), 18.0)
	check(not paths.blocked(slid, 18.0) and slid.y > 210.0, "G  slide() turns a step into the rock into a step along it (%s)" % slid)

	# The campaign maps.
	for mid in CD.MISSIONS:
		var map_id: String = CD.MISSIONS[mid].get("map", "")
		check(Maps.MAPS.has(map_id), "G  %s has a map (%s)" % [mid, map_id])
		if not Maps.MAPS.has(map_id):
			continue
		var m: Dictionary = Maps.MAPS[map_id]
		await _mission(mid)
		paths = main.paths
		check(main.FIELD_W == 640 and paths.has_terrain(), "G  %s: laid on the 640px field" % map_id)
		var gate: Vector2 = Vector2(320, main.CASTLE_Y - 20)
		check(paths.troop_can_stand(gate), "G  %s: troops can stand at the gate" % map_id)
		# Every lane reaches the castle, for every enemy size.
		for r in [11.0, 14.0, 19.0, 24.0]:
			var stuck := []
			for l in m["lanes"]:
				for x in range(int(l[0]) + int(r) + 2, int(l[1]) - int(r) - 1, 8):
					var dist: float = paths._field(r)["dist"][paths._index(paths._cell(Vector2(x, 4)))]
					if dist > 1e9:
						stuck.append(x)
			check(stuck.is_empty(), "G  %s: radius %d enemies can reach the castle from all along the lanes%s" % [map_id, r, "" if stuck.is_empty() else " (not from x %s)" % str(stuck)])
		# Walking a radius-24 enemy down its field from each lane never touches terrain.
		var touched := 0
		var arrived := 0
		for l in m["lanes"]:
			for x in range(int(l[0]) + 30, int(l[1]) - 29, 40):
				var p := Vector2(x, 10)
				for step in 600:
					var d: Vector2 = paths.direction(p, 24.0)
					p += d * 4.0
					if paths.blocked(p, 24.0 - 2.0):
						touched += 1
						break
					if p.y >= main.CASTLE_Y - 30:
						arrived += 1
						break
		check(touched == 0 and arrived > 0, "G  %s: Warlords following the field from %d starts reach the castle without grazing terrain (%d touched)" % [map_id, arrived, touched])
		# Where the mission's units start, and the bot's chokepoint posts.
		var bad := []
		for a in CD.MISSIONS[mid].get("allies", []):
			if not paths.troop_can_stand(a["at"]):
				bad.append(str(a["at"]))
		for q in m.get("bot_posts", []):
			if not paths.troop_can_stand(q):
				bad.append(str(q))
		check(bad.is_empty(), "G  %s: the allies' and the bot's posts are open, reachable ground%s" % [map_id, "" if bad.is_empty() else " (" + ", ".join(bad) + ")"])
		var above := 0
		for i in paths.cols * paths.rows:
			if paths.troop_open[i] == 1 and paths._center(Vector2i(i % paths.cols, i / paths.cols)).y < main.DEPLOY_TOP:
				above += 1
		check(above == 0, "G  %s: troops can't stand in the enemy camp" % map_id)
		for z in m["no_build"]:
			check(paths.in_no_build(z.get_center()) and not paths.in_no_build(z.position - Vector2(10, 10)), "G  %s: the no-build zone %s is kept" % [map_id, z])


# --- E: enemies on terrain ---------------------------------------------------------------

func _spawn(kind: String, at: Vector2, level := 3):
	main._spawn_enemy(kind, level, at)
	var all: Array = main.get_enemies().filter(func(e): return e.kind == kind)
	return all[all.size() - 1]


func _hire(kind: String, at: Vector2, place := true):
	main.placing_type = kind
	main.hire_at(at)
	main.placing_type = ""
	main.selected = null
	var all: Array = main.get_warriors().filter(func(w): return w.kind == kind)
	var w = all[all.size() - 1]
	if place:
		w.position = w.post
	return w


## Enemies standing in terrain right now (walking ones; a little slack for rounding).
func _inside_terrain() -> Array:
	var out := []
	for e in main.get_enemies():
		if not e.flying and main.paths.blocked(e.position, e.radius - 1.5):
			out.append("%s at %s" % [e.kind, e.position.round()])
	return out


func _enemies() -> void:
	for mid in ["ashwatch", "stonehollow"]:
		await _mission(mid)
		var m: Dictionary = Maps.MAPS[CD.MISSIONS[mid]["map"]]
		# Spawns.
		var outside := 0
		for i in 200:
			var p: Vector2 = main.paths.lane_spawn(14.0)
			var ok := false
			for l in m["lanes"]:
				ok = ok or (p.x >= l[0] + 14.0 and p.x <= l[1] - 14.0)
			if not ok:
				outside += 1
		check(outside == 0, "E  %s: 200 spawns all inside the lanes" % mid)
		# A big mixed wave, straight to the castle, checked every frame (no one to stop them).
		for w in main.get_warriors():
			w.free()
		main.warriors_changed()
		main.wave_active = true
		main.castle_hp = 1e9
		main.castle_max = 1e9
		var kinds := ["goblin", "orc", "wolf", "troll", "warlord", "skeleton_archer", "slime", "sapper"]
		for i in 64:
			main.spawn_queue.append([kinds[i % kinds.size()], 3])
		main.spawn_interval = 0.15
		var worst := []
		var seen := 0
		var sieged := {}   # reached the castle, or (archers) shooting it from bow range
		var spawned := {}
		for f in 60 * 80:
			await process_frame
			var bad := _inside_terrain()
			if not bad.is_empty():
				seen += 1
				if worst.size() < 4:
					worst.append_array(bad.slice(0, 1))
			for e in main.get_enemies():
				spawned[e.get_instance_id()] = true
				if e.sieging or e.position.y > main.CASTLE_Y - 175.0:
					sieged[e.get_instance_id()] = true
			if main.spawn_queue.is_empty() and sieged.size() >= spawned.size():
				break
		check(seen == 0, "E  %s: 64 mixed enemies (Skeleton Archers and Slimes too) walk the map without ever standing in terrain%s" % [mid, "" if seen == 0 else " (%d frames, e.g. %s)" % [seen, ", ".join(worst)]])
		var late: Array = main.get_enemies().filter(func(e): return not sieged.has(e.get_instance_id())).map(func(e): return "%s at %s" % [e.kind, e.position.round()])
		check(spawned.size() == 64 and sieged.size() == 64, "E  %s: all %d reach the castle (archers: within bow range of it)%s" % [mid, sieged.size(), "" if late.is_empty() else " (not: %s; %d spawned)" % [", ".join(late), spawned.size()]])
		for e in main.get_enemies():
			e.queue_free()
		await process_frame

	# Knockback straight into rock, over and over.
	await _mission("ashwatch")
	main.wave_active = true
	var victims := []
	for i in 12:
		var e = _spawn(["orc", "troll", "goblin", "warlord"][i % 4], Vector2(150 + (i % 4) * 110, 290 - (i / 4) * 30))
		e.max_hp = 1e6
		e.hp = 1e6
		e.speed = 0.0
		victims.append(e)
	var inside := 0
	for k in 40:
		for e in victims:
			e.apply_knockback(Vector2(randf_range(-30, 30), 90.0))   # down into the ridge
		for f in 6:
			await process_frame
			inside += _inside_terrain().size()
	check(inside == 0, "E  enemies knocked back into the ridge 40 times each slide along it, never into it")
	for e in victims:
		e.queue_free()

	# A Slime going after a troop on the far side of the centre rock: round it, not into it.
	await _mission("ashwatch")
	main.wave_active = true
	var sw = _hire("swordsman", Vector2(322, 440))
	sw.max_hp = 1e6
	sw.hp = 1e6
	sw.set_process(false)
	var sl = _spawn("slime", Vector2(322, 270))
	sl.max_hp = 1e6
	sl.hp = 1e6
	var touched := 0
	var reached := false
	for f in 60 * 20:
		await process_frame
		if main.paths.blocked(sl.position, sl.radius - 1.5):
			touched += 1
		if sl.position.distance_to(sw.position) - sl.radius - sw.RADIUS < 8.0:
			reached = true
		if sw.goo_timer > 0.0:
			break
	check(reached and touched == 0, "E  a Slime goes round the rock to the Swordsman behind it (in it: %d frames)" % touched)
	check(sw.goo_timer > 0.0 and sw._goo_factor() < 1.0, "E  ...and its blows slow him there")

	# Skeleton Archers in a tight channel: one wide enough for a goblin, too tight for a troop.
	await _mission("ashwatch")
	for w in main.get_warriors():
		w.free()
	main.warriors_changed()
	main.paths.set_map({"lanes": [[288, 352]], "terrain": [
		{"kind": "rock", "poly": [Vector2(0, 0), Vector2(296, 0), Vector2(296, 380), Vector2(0, 380)]},
		{"kind": "rock", "poly": [Vector2(344, 0), Vector2(640, 0), Vector2(640, 380), Vector2(344, 380)]}]})
	main.wave_active = true
	var target = _hire("swordsman", Vector2(320, 520))
	target.max_hp = 1e6
	target.hp = 1e6
	target.set_process(false)
	check(not main.paths.melee_can_reach(Vector2(320, 300)) and main.paths.melee_can_reach(Vector2(320, 420)),
			"E  the test channel: melee can't reach inside it, can just below it")
	var archers := []
	for i in 4:
		var a = _spawn("skeleton_archer", Vector2(320, -11 - i * 40))
		a.max_hp = 1e6
		a.hp = 1e6
		a.on_ground = true
		archers.append(a)
	var shots_from := []
	var fired := {}
	for f in 60 * 25:
		await process_frame
		for a in archers:
			if a.shots > fired.get(a, 0):
				shots_from.append(a.last_shot_from)
			fired[a] = a.shots
	var unreachable := shots_from.filter(func(p): return not main.paths.melee_can_reach(p) or p.y < main.DEPLOY_TOP)
	check(not shots_from.is_empty() and unreachable.is_empty(),
			"E  Skeleton Archers walk out of the channel before shooting (%d shots, %d from out of reach)" % [shots_from.size(), unreachable.size()])
	var out_front: Array = archers.filter(func(a): return a.shots > 0)
	check(out_front.size() >= 1 and out_front.all(func(a): return main.paths.melee_can_reach(a.position)),
			"E  ...and the %d that got out and shot stand where melee troops can get at them (the rest wait in line, not shooting)" % out_front.size())

	# The enemy camp, in Classic: a troop posted at the top line can't be shot from the camp.
	await _fresh()
	main.wave_active = true
	var front = _hire("swordsman", Vector2(320, main.DEPLOY_TOP + 70))
	front.max_hp = 1e6
	front.hp = 1e6
	front.set_process(false)
	var a2 = _spawn("skeleton_archer", Vector2(320, -11))
	a2.max_hp = 1e6
	a2.hp = 1e6
	var first_shot := INF
	for f in 60 * 8:
		await process_frame
		if a2.shots > 0 and first_shot == INF:
			first_shot = a2.last_shot_from.y
	check(first_shot != INF and first_shot - a2.radius >= main.DEPLOY_TOP,
			"E  (all modes) a Skeleton Archer only starts shooting once it's out of its camp (first shot at y %.0f, camp ends at %d)" % [first_shot, main.DEPLOY_TOP])

	# Around Stonehollow's cliffs, against a line at the bot's posts: every shot from reach.
	await _mission("stonehollow")
	main.wave_active = true
	for q in Maps.MAPS["stonehollow_quarry"]["bot_posts"].slice(0, 5):
		var w = _hire("swordsman", q)
		w.max_hp = 1e6
		w.hp = 1e6
	var skels := []
	for i in 10:
		var s2 = _spawn("skeleton_archer", main.paths.lane_spawn(15.0))
		s2.max_hp = 1e6
		s2.hp = 1e6
		skels.append(s2)
	var shots := []
	var fired2 := {}
	for f in 60 * 15:
		await process_frame
		for a in skels:
			if is_instance_valid(a) and a.shots > fired2.get(a, 0):
				shots.append(a.last_shot_from)
			if is_instance_valid(a):
				fired2[a] = a.shots
	var out_of_reach := shots.filter(func(p): return not main.paths.melee_can_reach(p))
	check(not shots.is_empty() and out_of_reach.is_empty(), "E  Stonehollow: %d Skeleton Archer shots, none from a spot melee can't reach%s" % [shots.size(), "" if out_of_reach.is_empty() else " (%s)" % str(out_of_reach.slice(0, 3))])
