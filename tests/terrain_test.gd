extends SceneTree
## Phase 2 battlefields: terrain, and everything that moves over it. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/terrain_test.gd [-- <groups>]
## Groups (all by default; pass letters to run some, e.g. -- GE):
##   G  grid        shapes become the right cells; Classic has none; every lane reaches the
##                  castle for every enemy size; gaps fit a Warlord; the gate, the mission's
##                  allies and the bot's posts are open ground troops can reach
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
