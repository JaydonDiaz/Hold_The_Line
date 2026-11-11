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
##   T  troops      new hires come out of the gate and route to posts round the ridge; move
##                  orders cross the map through the gaps; Engineers reach and finish build
##                  sites on both sides of it; troops and Healers backing away from enemies
##                  never cross or enter terrain or back into a dead end; shoves into rock
##                  slide; a full battle (every troop kind, trained upgrades, Slimes, Skeleton
##                  Archers, knockback) never leaves a unit or Engineer inside terrain
##   W  water       a river crossed by two bridges and a ford, and hedgerows: enemies take a
##                  bridge when one's on their way, the ford down the middle, and the ford
##                  when the bridges are walled off; wading is slow; nobody ever walks into
##                  water or hedge; troops route over a bridge or the ford; same on a wide field
##   Z  zones       the Battle Modes fields (convoy stretches, the village): every lane
##                  reaches the bottom for every enemy size; the wagon's road is clear
##   L  placement   hires, emplacements, move orders, drags and group moves are refused on
##                  terrain, in no-build zones and out of reach (with a message), by click,
##                  hotkey or drag; barricades may rest their ends on rock to seal a gap
##   K  classic     Classic can be played on each battlefield the campaign has opened (none
##                  without a campaign): the map's terrain, castle and music, Classic's
##                  rules (every unit, every tier, 20 waves), its own best record, and the
##                  Ogre King, the biggest enemy, walking it to the castle
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
	if _wants("T"):
		await _troops()
	if _wants("L"):
		await _placement()
	if _wants("K"):
		await _classic_maps()
	if _wants("Z"):
		await _zones()
	if _wants("W"):
		await _water()
	print("%d checks, %d failed" % [checks, fails])
	if main != null:
		main.free()
	for f in [TEST_SAVE, TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	quit(1 if fails > 0 else 0)


const RIVER := {
	"name": "Test River", "biome": "meadow", "lanes": [[40, 600]],
	"terrain": [
		{"kind": "water", "poly": [Vector2(0, 340), Vector2(60, 340), Vector2(60, 410), Vector2(0, 410)]},
		{"kind": "bridge", "poly": [Vector2(60, 336), Vector2(130, 336), Vector2(130, 414), Vector2(60, 414)]},
		{"kind": "water", "poly": [Vector2(130, 340), Vector2(290, 340), Vector2(290, 410), Vector2(130, 410)]},
		{"kind": "ford", "poly": [Vector2(290, 340), Vector2(360, 340), Vector2(360, 410), Vector2(290, 410)]},
		{"kind": "water", "poly": [Vector2(360, 340), Vector2(510, 340), Vector2(510, 410), Vector2(360, 410)]},
		{"kind": "bridge", "poly": [Vector2(510, 336), Vector2(580, 336), Vector2(580, 414), Vector2(510, 414)]},
		{"kind": "water", "poly": [Vector2(580, 340), Vector2(640, 340), Vector2(640, 410), Vector2(580, 410)]},
		{"kind": "hedge", "poly": [Vector2(0, 560), Vector2(200, 560), Vector2(200, 578), Vector2(0, 578)]},
		{"kind": "hedge", "poly": [Vector2(270, 560), Vector2(370, 560), Vector2(370, 578), Vector2(270, 578)]},
		{"kind": "hedge", "poly": [Vector2(440, 560), Vector2(640, 560), Vector2(640, 578), Vector2(440, 578)]},
	],
	"no_build": [], "trails": [],
}


## Follows an enemy's field from `from` down to the bottom: [crossed the ford, touched
## terrain, got there].
func _walk_down(from: Vector2, r: float) -> Array:
	var paths = main.paths
	var p := from
	var forded := false
	var touched := false
	for step in 900:
		var d: Vector2 = paths.direction(p, r)
		p = paths.slide(p, p + d * 4.0, r)
		forded = forded or paths.in_ford(p)
		touched = touched or paths.blocked(p, r - 2.0)
		if p.y >= main.CASTLE_Y - 30:
			return [forded, touched, true]
	return [forded, touched, false]


func _water() -> void:
	for wide in [false, true]:
		await _fresh()
		main._lock_portrait(not wide)
		await _frames(2)
		var paths = main.paths
		paths.set_map(RIVER)
		var k: float = main.FIELD_W / 640.0
		var tag := "W  %s:" % ("wide (%dpx)" % main.FIELD_W if wide else "640")
		check(not paths.in_ford(Vector2(150 * k, 375)) and paths.in_ford(Vector2(325 * k, 375)) and paths.blocked(Vector2(200 * k, 375), 4.0)
				and not paths.blocked(Vector2(95 * k, 375), 14.0) and paths.blocked(Vector2(100 * k, 569), 4.0),
				"%s water and hedges block, the bridges and the ford don't" % tag)
		var by_bridge: Array = _walk_down(Vector2(95 * k, 120), 11.0)
		check(by_bridge[2] and not by_bridge[0] and not by_bridge[1], "%s an enemy above a bridge crosses by it (%s)" % [tag, str(by_bridge)])
		var mid: Array = _walk_down(Vector2(325 * k, 120), 11.0)
		check(mid[2] and mid[0] and not mid[1], "%s one down the middle wades the ford rather than go round (%s)" % [tag, str(mid)])
		var big: Array = _walk_down(Vector2(95 * k, 120), 24.0)
		check(big[2] and not big[1], "%s a Warlord gets over a bridge too, without touching the water" % tag)
		# Wall off both bridges: the ford it is.
		for x in [95.0, 545.0]:
			var w = main.Barricade.new()
			w.half = Vector2(40 * k, 0)
			w.setup("barricade", main.Data.WARRIORS["barricade"], main, Vector2(x * k, 430))
			w.position = w.post
			main.wall_layer.add_child(w)
		main.walls_changed()
		await _frames(2)
		var walled: Array = _walk_down(Vector2(95 * k, 120), 11.0)
		check(walled[2] and walled[0] and not walled[1], "%s with both bridges walled off, it goes by the ford instead (%s)" % [tag, str(walled)])
		# Troops: over a bridge, or through the ford, never the water.
		var route: PackedVector2Array = paths.troop_route(Vector2(95 * k, 480), Vector2(95 * k, 250))
		var wet := false
		for q in route:
			wet = wet or paths.blocked(q, 10.0)
		check(not route.is_empty() and not wet, "%s a troop sent across the river goes round by a crossing (%d steps)" % [tag, route.size()])
	# Wading is slow.
	await _fresh()
	main._lock_portrait(true)
	await _frames(2)
	main.paths.set_map(RIVER)
	main._spawn_enemy("orc", 1, Vector2(325, 300))
	var orc = main.enemy_layer.get_children()[-1]
	orc.position = Vector2(325, 300)
	main._spawn_enemy("orc", 1, Vector2(200, 450))
	var dry = main.enemy_layer.get_children()[-1]
	dry.position = Vector2(200, 450)
	await _frames(20)
	var y0: float = orc.position.y
	var d0: float = dry.position.y
	orc.position = Vector2(325, 350)
	y0 = orc.position.y
	d0 = dry.position.y
	await _frames(30)
	var wet_step: float = orc.position.y - y0
	var dry_step: float = dry.position.y - d0
	check(main.paths.in_ford(orc.position) and wet_step > 0.0 and wet_step < dry_step * 0.65, "W  wading the ford is slow (%.0fpx against %.0fpx on dry ground)" % [wet_step, dry_step])
	main.paths.set_map({})


## The Battle Modes fields (maps.gd ZONES): every lane reaches the bottom for every enemy
## size, and a wagon's road (where it has one) runs clear of the terrain all the way.
func _zones() -> void:
	for wide in [false, true]:
		await _fresh()
		main._lock_portrait(not wide)
		await _frames(2)
		var paths = main.paths
		var tag := "Z  %s" % ("(wide) " if wide else "")
		for id in Maps.MAPS.keys() + Maps.ZONES.keys():
			paths.set_map(Maps.get_map(id))
			var m: Dictionary = Maps.fitted(Maps.get_map(id), main.FIELD_W)
			var stuck := []
			for r in [11.0, 14.0, 19.0, 24.0]:
				for l in m["lanes"]:
					for x in range(int(l[0]) + int(r) + 2, int(l[1]) - int(r) - 1, 8):
						if paths._field(r)["dist"][paths._index(paths._cell(Vector2(x, 4)))] > 1e9:
							stuck.append([r, x])
			var touched := 0
			var arrived := 0
			for l in m["lanes"]:
				for x in range(int(l[0]) + 30, int(l[1]) - 29, 30):
					var walk: Array = _walk_down(Vector2(x, 10), 24.0)
					touched += 1 if walk[1] else 0
					arrived += 1 if walk[2] else 0
			check(stuck.is_empty() and touched == 0 and arrived > 0 and paths.troop_can_stand(Vector2(main.FIELD_W / 2.0, main.CASTLE_Y - 20)),
					"%s%s: every size of enemy reaches the bottom from its lanes, Warlords from %d starts without grazing terrain, troops can stand at the gate%s" % [
					tag, id, arrived, "" if stuck.is_empty() else " (stuck: %s)" % str(stuck.slice(0, 3))])
	await _fresh()
	main._lock_portrait(true)
	await _frames(2)
	var paths = main.paths
	for id in Maps.ZONES:
		var m: Dictionary = Maps.ZONES[id]
		paths.set_map(m)
		var stuck := []
		for r in [11.0, 14.0, 19.0, 24.0]:
			for l in m["lanes"]:
				for x in range(int(l[0]) + int(r) + 2, int(l[1]) - int(r) - 1, 8):
					if paths._field(r)["dist"][paths._index(paths._cell(Vector2(x, 4)))] > 1e9:
						stuck.append([r, x])
		check(stuck.is_empty(), "Z  %s: every size of enemy reaches the bottom from all along its lanes%s" % [id, "" if stuck.is_empty() else " (%s)" % str(stuck.slice(0, 3))])
		if m.has("route"):
			var road: Array = m["route"]
			var hit := []
			for i in road.size() - 1:
				var a: Vector2 = road[i]
				var b: Vector2 = road[i + 1]
				for k in 20:
					var p: Vector2 = a.lerp(b, k / 20.0)
					if p.y < main.CASTLE_Y and paths.blocked(p, 16.0):
						hit.append(p)
			check(hit.is_empty(), "Z  %s: the wagon's road is clear of the terrain%s" % [id, "" if hit.is_empty() else " (at %s)" % str(hit[0])])
	paths.set_map({})


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
	# Battles stretch to the window; these tests hold the field at the width the maps are
	# drawn up for (as wide windows are checked in G).
	main._lock_portrait(true)
	await process_frame
	main.gold = 99999
	campaign.allies = CD.FACTIONS.keys()   # every troop and emplacement open, for the tests


# --- G: the grid ------------------------------------------------------------------------

func _grid() -> void:
	await _fresh()
	var paths = main.paths
	check(not paths.has_terrain() and not paths.blocked(Vector2(320, 400), 30.0) and paths.direction(Vector2(320, 400), 12.0) == Vector2.ZERO,
			"G  Classic has no terrain: nothing is blocked and enemies march straight down as before")
	check(main.castle.pal == main.castle.STYLES["keep"], "G  Classic's castle is the usual keep")
	check(paths.open_spot(Vector2(320, 400)) == Vector2(320, 400) and paths.troop_can_stand(Vector2(5, 120)) and paths.melee_can_reach(Vector2(320, 50)),
			"G  ...and every terrain check passes everything through")
	# A known shape: a 64px square at (96..160, 192..256), on a field held at the width
	# maps are drawn up for (so it isn't stretched).
	main._lock_portrait(true)
	await process_frame
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
		if Maps.ZONES.has(map_id):
			# (a convoy's roads: checked with the other Battle Modes fields, group Z). Its
			# stretches are all roads there, and its troops start on open ground.
			var zs: Array = CD.MISSIONS[mid].get("convoy", {}).get("zones", [])
			check(not zs.is_empty() and zs.all(func(z): return Maps.ZONES.has(z["map"])), "G  %s: every stretch of its road is a convoy field" % mid)
			await _mission(mid)
			var open := []
			for a in CD.MISSIONS[mid].get("allies", []):
				if not main.paths.troop_can_stand(a["at"]):
					open.append(str(a["at"]))
			check(open.is_empty(), "G  %s: its troops start on open ground%s" % [mid, "" if open.is_empty() else " (" + ", ".join(open) + ")"])
			continue
		check(Maps.MAPS.has(map_id), "G  %s has a map (%s)" % [mid, map_id])
		if not Maps.MAPS.has(map_id):
			continue
		var m: Dictionary = Maps.MAPS[map_id]
		await _mission(mid)
		paths = main.paths
		check(main.FIELD_W == 640 and paths.has_terrain(), "G  %s: laid on the 640px field" % map_id)
		check(main.castle.pal == main.castle.STYLES[m["castle"]], "G  %s: the castle is dressed as its %s" % [map_id, m["castle"]])
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
		# The same map stretched across a wide window's field.
		main._lock_portrait(false)
		await _frames(2)
		paths = main.paths
		var k: float = main.FIELD_W / Maps.BASE_W
		var wide: Dictionary = Maps.fitted(m, main.FIELD_W)
		var first_rock: Vector2 = Vector2(wide["terrain"][0]["poly"][0])
		check(main.FIELD_W > 700 and paths.has_terrain() and is_equal_approx(first_rock.x, float(m["terrain"][0]["poly"][0].x) * k),
				"G  %s on a %dpx field: the map stretches across it (x %.2f times)" % [map_id, main.FIELD_W, k])
		var stuck_w := []
		for r in [11.0, 24.0]:
			for l in wide["lanes"]:
				for x in range(int(l[0]) + int(r) + 2, int(l[1]) - int(r) - 1, 12):
					if paths._field(r)["dist"][paths._index(paths._cell(Vector2(x, 4)))] > 1e9:
						stuck_w.append([r, x])
		check(stuck_w.is_empty(), "G  %s, wide: every lane still reaches the castle for every size%s" % [map_id, "" if stuck_w.is_empty() else " (%s)" % str(stuck_w.slice(0, 3))])
		var arrived_w := 0
		var touched_w := 0
		for l in wide["lanes"]:
			for x in range(int(l[0]) + 30, int(l[1]) - 29, 60):
				var p := Vector2(x, 10)
				for step in 700:
					p += paths.direction(p, 24.0) * 4.0
					if paths.blocked(p, 22.0):
						touched_w += 1
						break
					if p.y >= main.CASTLE_Y - 30:
						arrived_w += 1
						break
		check(touched_w == 0 and arrived_w > 0, "G  %s, wide: Warlords walk it to the castle (%d arrived, %d touched rock)" % [map_id, arrived_w, touched_w])
		var bad_w := []
		for w in main.get_warriors():
			if not paths.troop_can_stand(w.post):
				bad_w.append("%s %s" % [w.kind, w.post.round()])
		for q in wide["bot_posts"]:
			if not paths.troop_can_stand(q):
				bad_w.append(str(q.round()))
		check(bad_w.is_empty(), "G  %s, wide: the mission's allies and the bot's posts stand on open ground%s" % [map_id, "" if bad_w.is_empty() else " (%s)" % ", ".join(bad_w)])


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


# --- T: troops and Engineers on terrain ----------------------------------------------------

## Your units (and Engineers) standing in terrain right now.
func _troops_inside() -> Array:
	var out := []
	for w in main.get_warriors():
		if not w.wall_guard and not w.is_emplacement() and main.paths.blocked(w.position, w.RADIUS - 1.5):
			out.append("%s at %s" % [w.kind, w.position.round()])
	for g in main.fx_layer.get_children():
		if g.get_script() == preload("res://scripts/engineer.gd") and main.paths.blocked(g.position, g.RADIUS - 1.5):
			out.append("engineer at %s" % g.position.round())
	return out


## Watches `w` for `frames` frames: how often it was inside terrain, and how often a
## frame's step crossed terrain.
func _watch(units: Array, frames: int, until := Callable()) -> Dictionary:
	var inside := 0
	var crossed := 0
	var last := {}
	for f in frames:
		await process_frame
		for w in units:
			if not is_instance_valid(w):
				continue
			if main.paths.blocked(w.position, w.RADIUS - 1.5):
				inside += 1
			if last.has(w) and main.paths.segment_blocked(last[w], w.position, 1.0):
				crossed += 1
			last[w] = w.position
		if until.is_valid() and until.call():
			break
	return {"inside": inside, "crossed": crossed}


func _troops() -> void:
	# New hires: out of the gate, round the ridge to posts on either side of it.
	await _mission("ashwatch")
	for w in main.get_warriors():
		w.free()
	main.warriors_changed()
	main.wave_active = false
	var hires := []
	for q in [Vector2(100, 460), Vector2(560, 470), Vector2(240, 250), Vector2(420, 230)]:
		main.placing_type = "swordsman"
		main.hire_at(q)
		main.placing_type = ""
		var all: Array = main.get_warriors()
		hires.append(all[all.size() - 1])
	var gate_ok: bool = hires.all(func(w): return w.position.distance_to(Vector2(320, main.CASTLE_Y - w.RADIUS)) < 2.0)
	check(gate_ok, "T  new hires on a campaign map come out of the castle gate")
	var seen: Dictionary = await _watch(hires, 60 * 20, func(): return hires.all(func(w): return w.position.distance_to(w.post) < 4.0))
	check(hires.all(func(w): return w.position.distance_to(w.post) < 4.0), "T  ...and reach posts on both sides of the ridge (%s)" % ", ".join(hires.map(func(w): return str(w.position.round()))))
	check(seen["inside"] == 0 and seen["crossed"] == 0, "T  ...never stepping into or across rock (inside %d, crossed %d)" % [seen["inside"], seen["crossed"]])
	# Move orders straight across the ridge.
	hires[0].order_to(Vector2(560, 230))
	hires[2].order_to(Vector2(100, 470))
	seen = await _watch(hires, 60 * 20, func(): return hires[0].position.distance_to(hires[0].post) < 4.0 and hires[2].position.distance_to(hires[2].post) < 4.0)
	check(hires[0].position.distance_to(hires[0].post) < 4.0 and hires[2].position.distance_to(hires[2].post) < 4.0 and seen["inside"] == 0 and seen["crossed"] == 0,
			"T  move orders across the ridge go through the gaps (inside %d, crossed %d)" % [seen["inside"], seen["crossed"]])
	# Engineers: build sites below and above the ridge.
	var sites := []
	for q in [Vector2(150, 520), Vector2(510, 250), Vector2(330, 250)]:
		main.placing_type = "tower"
		main.hire_at(q)
		main.placing_type = ""
		var all: Array = main.get_warriors().filter(func(w): return w.kind == "tower")
		sites.append(all[all.size() - 1])
	var eng_inside := 0
	for f in 60 * 30:
		await process_frame
		eng_inside += _troops_inside().filter(func(x): return x.begins_with("engineer")).size()
		if sites.all(func(t): return not t.under_construction()):
			break
	check(sites.all(func(t): return not t.under_construction()), "T  Engineers reach and finish towers on both sides of the ridge")
	check(eng_inside == 0, "T  ...without ever walking into rock (%d)" % eng_inside)

	# Backing away near rock: an Archer and a Healer with the ridge behind them, a troll coming.
	await _mission("ashwatch")
	for w in main.get_warriors():
		w.free()
	main.warriors_changed()
	main.wave_active = true
	var archer = _hire("archer", Vector2(110, 430))
	var healer = _hire("healer", Vector2(330, 430))
	var hurt = _hire("swordsman", Vector2(250, 600))
	hurt.max_hp = 1e6
	hurt.hp = 5e5
	for w in [archer, healer]:
		w.max_hp = 1e6
		w.hp = 1e6
	var trolls := []
	for x in [110, 330]:
		var t = _spawn("troll", Vector2(x, 560))
		t.max_hp = 1e6
		t.hp = 1e6
		t.damage = 0.0
		trolls.append(t)
	var kited := false
	var stand_bad := 0
	var watch_units := [archer, healer]
	var inside2 := 0
	var crossed2 := 0
	var last2 := {}
	for f in 60 * 12:
		await process_frame
		kited = kited or archer.kiting or healer.kiting
		for w in watch_units:
			if main.paths.blocked(w.position, w.RADIUS - 1.5):
				inside2 += 1
			if last2.has(w) and main.paths.segment_blocked(last2[w], w.position, 1.0):
				crossed2 += 1
			if not main.paths.troop_can_stand(main.paths.push_out(w.position, w.RADIUS)):
				stand_bad += 1
			last2[w] = w.position
	check(kited, "T  an Archer and a Healer with the ridge at their backs back away from the trolls")
	check(inside2 == 0 and crossed2 == 0, "T  ...without stepping into or across the rock (inside %d, crossed %d)" % [inside2, crossed2])
	check(stand_bad == 0, "T  ...or into anywhere troops can't get to (%d)" % stand_bad)
	# A Healer in the corner between the trees and the field edge: she stays put.
	await _mission("ashwatch")
	for w in main.get_warriors():
		w.free()
	main.warriors_changed()
	main.wave_active = true
	var cornered = _hire("healer", Vector2(108, 690))
	cornered.max_hp = 1e6
	cornered.hp = 1e6
	var t2 = _spawn("orc", Vector2(200, 640))
	t2.max_hp = 1e6
	t2.hp = 1e6
	t2.damage = 0.0
	var seen3: Dictionary = await _watch([cornered], 60 * 8)
	check(seen3["inside"] == 0 and seen3["crossed"] == 0 and main.paths.troop_can_stand(cornered.position),
			"T  a Healer backed into the corner by the trees holds there, on open ground (at %s)" % cornered.position.round())

	# Shoves into rock slide along it.
	await _mission("ashwatch")
	for w in main.get_warriors():
		w.free()
	main.warriors_changed()
	var pushed := []
	for x in [90, 240, 330, 520]:
		var w = _hire("swordsman", Vector2(x, 450))
		pushed.append(w)
	var shove_in := 0
	for k in 12:
		for w in pushed:
			w.shove(Vector2(randf_range(-40, 40), -140.0), 0.1)
		var r: Dictionary = await _watch(pushed, 20)
		shove_in += r["inside"] + r["crossed"]
	check(shove_in == 0, "T  troops shoved hard into the ridge slide along it (%d frames in it)" % shove_in)

	# A full battle on each map: every troop kind (trained, upgraded), Slimes and Skeleton
	# Archers, knockback, Engineers building; nobody ever inside terrain.
	for mid in ["ashwatch", "stonehollow"]:
		await _mission(mid)
		for w in main.get_warriors():
			w.free()
		main.warriors_changed()
		for k in ["swordsman", "archer", "mage", "frost", "martial", "healer", "bard", "alchemist"]:
			campaign.unlocked[k] = [3, 3, 3, 3]
		var posts: Array = Maps.MAPS[CD.MISSIONS[mid]["map"]]["bot_posts"]
		var kinds := ["swordsman", "martial", "archer", "healer", "mage", "frost", "bard", "alchemist", "swordsman"]
		var army := []
		for i in posts.size():
			var w = _hire(kinds[i % kinds.size()], posts[i])
			w.max_hp *= 20.0
			w.hp = w.max_hp
			main.selected = w
			for path in [0, 1, 0, 2, 0]:
				main.upgrade_selected(path)
			main.selected = null
			army.append(w)
		var trained_ok: bool = army.all(func(w): return w.tiers.max() >= 2)
		check(trained_ok and army.all(func(w): return w.tiers.max() <= 3), "T  %s: trained troops take their tier II-III upgrades, and no further" % mid)
		main.placing_type = "cannon"
		main.hire_at(Vector2(320, 680) if mid == "ashwatch" else Vector2(320, 660))
		main.placing_type = ""
		main.wave_active = true
		main.castle_hp = 1e9
		main.castle_max = 1e9
		var kinds2 := ["slime", "skeleton_archer", "orc", "troll", "goblin", "wolf", "slime", "skeleton_archer", "warlord", "sapper"]
		for i in 60:
			main.spawn_queue.append([kinds2[i % kinds2.size()], 4])
		main.spawn_interval = 0.2
		var bad_frames := 0
		var example := ""
		for f in 60 * 45:
			await process_frame
			if f % 300 == 0:
				for e in main.get_enemies():
					e.apply_knockback(Vector2(randf_range(-60, 60), randf_range(-60, 60)))
			var bad := _troops_inside() + _inside_terrain()
			if not bad.is_empty():
				bad_frames += 1
				if example == "":
					example = bad[0]
		check(bad_frames == 0, "T  %s: a 45s battle (Slimes, Skeleton Archers, knockback every 5s) never leaves anyone inside terrain%s" % [mid, "" if bad_frames == 0 else " (%d frames, e.g. %s)" % [bad_frames, example]])
		for e in main.get_enemies():
			e.free()
		main.enemies_changed()


# --- L: placement rules -------------------------------------------------------------------

func _placement() -> void:
	await _mission("ashwatch")
	for w in main.get_warriors():
		w.free()
	main.warriors_changed()
	var gold: int = main.gold
	var count: int = main.get_warriors().size()
	main._on_hire_pressed("swordsman")   # as the hotkey does
	main.hire_at(Vector2(330, 350))      # the centre rock
	check(main.get_warriors().size() == count and main.gold == gold, "L  a Swordsman can't be posted on the rock (and costs nothing)")
	check(main.hud.message_label.text != "", "L  ...and a message says why (\"%s\")" % main.hud.message_label.text)
	main._on_hire_pressed("tower")
	main.hire_at(Vector2(560, 600))      # the trees
	check(main.get_warriors().size() == count, "L  an Archer Tower can't be built in the trees")
	main._on_hire_pressed("swordsman")
	main.hire_at(Vector2(320, 712))      # the gate
	check(main.get_warriors().size() == count and "gate" in main.hud.message_label.text, "L  nothing goes in front of the gate (\"%s\")" % main.hud.message_label.text)
	main._on_hire_pressed("swordsman")
	main.hire_at(Vector2(20, 330))       # tucked between the field edge and the ridge
	check(main.get_warriors().size() == count, "L  nor where troops can't stand")
	main.placing_type = ""
	var w = _hire("swordsman", Vector2(240, 470))
	check(main.get_warriors().size() == count + 1, "L  open ground is fine")
	# Move orders, drags and group moves.
	main.selected = w
	main.order_move(Vector2(330, 350))
	check(w.post == Vector2(240, 470), "L  a move order onto the rock is refused")
	main._start_drag(w)
	w.post = Vector2(110, 350)
	w.position = w.post
	main._end_drag()
	check(w.post == Vector2(240, 470) and w.position == Vector2(240, 470), "L  a unit dragged onto the rock goes back where it was")
	main.selected = null
	var w2 = _hire("archer", Vector2(300, 470))
	main._set_group([w, w2])
	main.order_group(Vector2(330, 350))
	await process_frame
	var on_ground: bool = [w, w2].all(func(x): return main.ground_problem(x.post) == "")
	check(on_ground, "L  a group sent onto the rock is given spots on open ground beside it (%s, %s)" % [w.post.round(), w2.post.round()])
	main.group = []
	for x in main.get_warriors():
		x.free()
	main.warriors_changed()
	# Barricades: their ends may rest on rock, sealing a gap.
	var walls_before: int = main.get_barricades().size()
	main.placing_type = "barricade"
	main.hire_at(Vector2(190, 360))   # in the left rock
	main.hire_at(Vector2(290, 360))   # in the centre rock
	main.placing_type = ""
	check(main.get_barricades().size() == walls_before + 1, "L  a barricade across the left gap may rest its ends on the rocks")
	await process_frame
	check(main.paths.breach_at(Vector2(240, 250), 14.0) == null, "L  ...and enemies route through the other gap rather than break it")
	# Classic: nothing changes.
	await _fresh()
	var n: int = main.get_warriors().size()
	main._on_hire_pressed("swordsman")
	main.hire_at(Vector2(330, 350))
	check(main.get_warriors().size() == n + 1 and main.ground_problem(Vector2(330, 350)) == "", "L  Classic: the same spot is open meadow")


# --- K: Classic on the campaign's battlefields --------------------------------------------

func _classic_maps() -> void:
	for f in [TEST_SAVE, TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	campaign.reset()
	check(campaign.open_maps().is_empty(), "K  no campaign: Classic is on the meadow only")
	campaign.new_campaign("normal")
	check(campaign.open_maps() == ["ashwatch_ridge"], "K  a new campaign opens Ashwatch Ridge for Classic (%s)" % str(campaign.open_maps()))
	campaign.completed = ["ashwatch"]
	campaign.save_game()
	check(campaign.open_maps() == ["ashwatch_ridge", "stonehollow_quarry"], "K  ...and Stonehollow Quarry once that mission opens (%s)" % str(campaign.open_maps()))
	# Classic: the difficulties first, then the battlefield viewer (every map shows,
	# locked till the campaign reaches it).
	campaign.completed = []
	campaign.save_game()
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud._show_cards("classic")
	await _frames(2)
	var names := {}
	for c in main.hud.mode_cards:
		names[(c.get_child(0) as Label).text] = c
	check(names.has("Easy") and names.has("Normal") and names.has("Hard") and "difficulty" in main.hud.mode_sub.text, "K  Classic opens on the difficulties (%s)" % ", ".join(names.keys()))
	names["Normal"].pressed.emit()
	await _frames(3)
	var v = main.hud.battlefields
	check(v != null and v.name_label.text == "The Meadow" and not v.start_button.disabled, "K  ...then the battlefield viewer, on the meadow")
	check(v.maps == [""] + Maps.MAPS.keys() and v.maps.slice(0, 3) == ["", "ashwatch_ridge", "stonehollow_quarry"], "K  ...with every battlefield to go through (%s)" % str(v.maps))
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	v._input(key)
	check(v.name_label.text == "Ashwatch Ridge" and not v.start_button.disabled and not v.lock_band.visible, "K  Right shows Ashwatch Ridge in full, open")
	v.show_map(v.at + 1)
	check(v.name_label.text == "Stonehollow Quarry" and v.start_button.disabled and v.lock_band.visible and "Stonehollow" in v.lock_label.text,
			"K  ...then Stonehollow Quarry, shown but locked (\"%s\")" % v.lock_label.text.replace("\n", " "))
	var picked := []
	main.hud.mode_chosen.connect(func(k): picked.append(k))
	v._start()
	await _frames(10)
	check(picked.is_empty(), "K  ...and a locked battlefield can't be started")
	v.show_map(v.maps.size())
	check(v.name_label.text == "The Meadow", "K  ...and it goes round to the meadow again")
	v.back.emit()
	await process_frame
	check(main.hud.battlefields == null and "difficulty" in main.hud.mode_sub.text, "K  Back returns to the difficulties")
	for c in main.hud.mode_cards:
		if (c.get_child(0) as Label).text == "Hard":
			c.pressed.emit()
	await _frames(3)
	v = main.hud.battlefields
	v.show_map(1)
	v.start_button.pressed.emit()
	for f in 120:
		await process_frame
		if not picked.is_empty():
			break
	check(picked == ["hard|ashwatch_ridge"], "K  Start begins on the battlefield showing (%s)" % str(picked))
	campaign.completed = ["ashwatch"]
	campaign.save_game()
	# A Classic game on Stonehollow Quarry.
	main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main._on_mode_chosen("normal|stonehollow_quarry")
	await _frames(3)
	check(not main.campaign and main.map_id == "stonehollow_quarry" and main.paths.has_terrain() and main.FIELD_W == main.get_viewport().get_visible_rect().size.x,
			"K  Classic on Stonehollow Quarry: its terrain, across the whole %dpx field (no letterbox)" % main.FIELD_W)
	check(main.castle.pal == main.castle.STYLES["guildhall"] and main.stage_music == "mountain", "K  ...its guildhall and its mountain music")
	check(main.allowed("mage") and main.allowed("ability:fireball") and main.max_tier("swordsman", 0) == 4 and main.last_wave() == 20,
			"K  ...and Classic's rules: every unit, every tier, 20 waves")
	main.gold = 99999
	main._on_hire_pressed("mage")
	main.hire_at(Maps.fitted(Maps.MAPS["stonehollow_quarry"], main.FIELD_W)["bot_posts"][0])   # open ground on the stretched map
	check(main.get_warriors().any(func(w): return w.kind == "mage"), "K  a Mage can be posted (no campaign locks)")
	check(main.battle_xp.is_empty(), "K  ...and Classic earns no campaign XP")
	# Its own best record, apart from the meadow's.
	main.records_path = "user://terrain_test_records.cfg"
	main._save_record(7)
	var cfg := ConfigFile.new()
	cfg.load(main.records_path)
	check(cfg.get_value("best", "normal@stonehollow_quarry", 0) == 7 and cfg.get_value("best", "normal", 0) == 0, "K  its best is kept apart from the meadow's")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.records_path))
	# The Ogre King, Classic's last enemy, walks each map to the castle.
	for map_id in Maps.MAPS:
		main.free()
		main = load("res://main.tscn").instantiate()
		root.add_child(main)
		await _frames(3)
		main._on_mode_chosen("normal|" + map_id)
		await _frames(2)
		var r: float = Data.ENEMIES["ogre_king"]["radius"]
		var p := Vector2(main.FIELD_W / 2.0, -r)
		var arrived := false
		var grazed := 0
		for step in 900:
			p += main.paths.direction(p, r) * 3.0
			p = main.paths.slide(p, p, r)
			if main.paths.blocked(p, r - 2.0):
				grazed += 1
			if p.y >= main.CASTLE_Y - r:
				arrived = true
				break
		check(arrived and grazed == 0, "K  %s: the Ogre King can walk it to the castle (grazed rock %d times)" % [map_id, grazed])
	# Classic on the meadow is just as it was.
	main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main._on_mode_chosen("normal")
	await _frames(2)
	check(main.map_id == "" and not main.paths.has_terrain() and main.castle.pal == main.castle.STYLES["keep"] and main.stage_music == "calm",
			"K  Classic picked without a battlefield is the open meadow, as before")
	campaign.reset()
