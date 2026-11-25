extends SceneTree
## Phase 5, F3: inside Dawnspire's citadel, its foundations (rules_castle.gd, pathing's sight
## and doors, castle_art.gd), tried on its first two rooms. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/castle_test.gd
##   S  sight       a castle's walls block sight: an Archer doesn't shoot (and an enemy archer
##                   doesn't) at what's behind one, but does through a doorway; a shot that
##                   flies into a wall stops there; a map with no such walls sees through all
##                   (and a villager walking into one finds its way round)
##   D  doors       a shut door is solid; opened, troops route through it
##   C  crowding    a score of troops sent through a hall's gap all get there, none stuck
##   E  entering    taken up in the Gatehouse Hall: the army comes in at its south door a few at
##                   a time (not all at once), each walking on to its place; its kinds, training,
##                   health, orders and the troops on loan as they were; the gold too; the
##                   standard planted; the garrison holds its posts till the army's near, then
##                   goes for the standard
##   T  through     the room taken: an arrow at the way on; clicked, the troops make for the
##                   door, and the view moves on once the first gets there; in the Hall of
##                   Banners they come in at its door in the order they'd have got there; a
##                   troop still down is left behind, an emplacement hauled through and set up;
##                   health, training and orders kept; a checkpoint for the new room
##   R  side rooms  from a hall taken, its side door's arrow leads to its side room (the army in
##                   by that room's own door, from the side); its cells open when troops stand
##                   round them: the soldiers join on loan, the townsfolk walk out by the door
##                   the army came in by (but not while its Warden lives: he has the keys); a
##                   troop on Side Objectives goes after a room's cells and supplies by itself;
##                   new troops come into a room by its door; back in the hall it's still taken (nobody there, the
##                   way on open at once), the cells shown as taken; supplies claimed for gold;
##                   taken up again from a checkpoint after, nothing had is there to be had again
##   M  music       a room's first wave comes as the army comes in, and the battle music holds
##                   through the breathers until the room's taken; the siege's battles all carry
##                   the Dawnspire hymn
##   K  checkpoints taken up again from the Hall of Banners: as the army came in (gold, army,
##                   the standard's health), the XP before it banked once; a checkpoint with
##                   too little left to win with brings reserves up to the floor, once a try
##   L  stuck       a troop that can't get to the door doesn't hold the army: the view moves on
##                   anyway, and it comes in a little after the rest
##   W  standard    the standard falls: the army breaks (the battle's lost); and the Ogre King's
##                   cutscenes come from Dawnspire's throne room once it's open
## Uses a scratch save path, never the player's own save.
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.

const TEST_SAVE := "user://castle_test_campaign.cfg"
const CD = preload("res://scripts/data/campaign_data.gd")
const BANNERS := 2   # (the rooms' places: the Gatehouse Hall, its cells, the Hall of Banners...)
const Maps = preload("res://scripts/campaign/maps.gd")

var main
var fails := 0
var checks := 0
var campaign


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	campaign = root.get_node("Campaign")
	campaign.save_path = TEST_SAVE
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _at_dawnspire() -> void:
	campaign.new_campaign("normal")
	campaign.completed = ["ashwatch", "ashwatch_road", "stonehollow", "stonehollow_workshops", "gw_exodus", "gw_watchfires",
		"mv_wounded", "mv_sanctuary", "sable_crossing", "fm_pass", "fm_vigil", "mo_steps", "mo_gate", "sp_circle", "sp_relight"]
	campaign.allies = ["stonehollow", "greenwood", "mercyvale", "frostmarch", "monastery", "spires"]


## A room checkpoint as the castle keeps one.
func _room_cp(room: int, army: Array, gold: int, std := 1.0) -> Dictionary:
	var spec: Dictionary = CD.MISSIONS["ds_assault"]["assault"]["castle"]["rooms"][room]
	var entry := "s"
	for d in spec["doors"]:
		if d in ["e", "w"] and int(spec.get("waves", 2)) == 0:
			entry = d   # (a side room's only door)
	return {"zone": 100 + room, "room": room, "entry": entry, "name": spec["name"],
		"gold": gold, "wave": 6, "army": army, "xp": {"swordsman": 500.0}, "owned": [], "standard": std,
		"freed": 3, "joined": 2, "garrisons": [], "stragglers": []}


const ARMY := [
	{"kind": "swordsman", "tiers": [2, 1, 0, 0], "hp": 0.8, "post": Vector2(260, 560), "spent": 200, "lent": false, "freed": false, "priority": "strongest", "move_mode": "hold"},
	{"kind": "swordsman", "tiers": [0, 0, 1, 0], "hp": 1.0, "post": Vector2(380, 560), "spent": 120, "lent": true, "freed": false, "priority": "first", "move_mode": "guard"},
	{"kind": "archer", "tiers": [2, 0, 0, 2], "hp": 0.6, "post": Vector2(300, 640), "spent": 300, "lent": false, "freed": false, "priority": "first", "move_mode": "guard"},
	{"kind": "healer", "tiers": [1, 0, 0, 0], "hp": 1.0, "post": Vector2(340, 680), "spent": 140, "lent": false, "freed": true, "priority": "first", "move_mode": "guard"},
	{"kind": "mage", "tiers": [0, 2, 0, 0], "hp": 1.0, "post": Vector2(200, 650), "spent": 220, "lent": false, "freed": false, "priority": "first", "move_mode": "guard"},
	{"kind": "cannon", "tiers": [1, 0, 0, 0], "hp": 1.0, "post": Vector2(440, 680), "spent": 220, "lent": false, "freed": false, "priority": "first", "move_mode": "guard"},
]


## Into the castle, taken up from room `room`'s checkpoint.
func _castle(room: int, army: Array = ARMY, gold := 420, quiet := true) -> void:
	_at_dawnspire()
	campaign.set_checkpoint("ds_assault", 100 + room, _room_cp(room, army, gold))
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud.hide_mode_select()
	campaign.op_resume_zone = 100 + room
	main.missions.start_mission("ds_assault")
	await process_frame
	if main.hud.story != null:
		main.hud.story.skip()
	main.missions._lock_portrait(true)
	await _frames(3)
	main.deploying = false
	main.forced_auto = false
	main.auto_play = false
	main.auto_timer = 9999.0
	if quiet:
		main.modes.clear_enemies()


## Everyone in: the room's arrivals done.
func _all_in() -> void:
	for i in 60 * 12:
		if main.rules.phase != "enter":
			break
		await process_frame


func _unit(kind: String, at: Vector2):
	main.gold += 5000
	var had: Array = main.battlefield.get_warriors()
	main.placing_type = kind
	main.hiring.hire_at(main.paths.open_spot(at))
	main.placing_type = ""
	main.gold -= 5000
	var fresh: Array = main.battlefield.get_warriors().filter(func(x): return not had.has(x))
	if fresh.is_empty():
		return null
	fresh[0].build_left = 0.0
	fresh[0].position = fresh[0].post
	return fresh[0]


func _foe(kind: String, at: Vector2):
	main.waves._spawn_enemy(kind, 8, at)
	var e = main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)
	e.max_hp = 1e5
	e.hp = 1e5
	e.speed = 0.0
	e.goal = null
	e.set_meta("guard", true)
	return e


func _run() -> void:
	await _sight()
	await _crowding()
	await _entering()
	await _through()
	await _side_rooms()
	await _checkpoints()
	await _stuck()
	await _standard()
	if main != null:
		main.free()
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


# --- S, D ------------------------------------------------------------------------------------

func _sight() -> void:
	await _castle(0)
	await _all_in()
	for w in main.battlefield.get_warriors():
		w.queue_free()
	await _frames(2)
	var paths = main.paths
	# The Gatehouse Hall: a cross wall from x 30 to 206 at y 300-330, the gap 206-434.
	check(paths.has_sight_walls() and not paths.sight_clear(Vector2(120, 400), Vector2(120, 230))
			and paths.sight_clear(Vector2(320, 400), Vector2(320, 230)), "S  the hall's walls block sight; its gap doesn't")
	var a = _unit("archer", Vector2(120, 380))
	a.priority = "first"
	a.move_mode = "hold"   # (left free, it'd walk round to the gap for a shot: as it should)
	var behind = _foe("orc", Vector2(110, 250))
	main.wave_active = true
	await _frames(60 * 3)
	check(behind.hp == behind.max_hp, "S  an Archer doesn't shoot at an orc behind the wall, though it's in reach")
	var through = _foe("orc", Vector2(300, 250))
	a.position = Vector2(290, 400)
	a.post = a.position
	await _frames(60 * 3)
	check(through.hp < through.max_hp, "S  ...but does at one it can see through the gap")
	behind.queue_free()
	through.queue_free()
	a.queue_free()
	await _frames(2)
	# An enemy archer behind the wall doesn't shoot your troop.
	var sk = _foe("skeleton_archer", Vector2(110, 260))
	sk.speed = 0.0
	sk.remove_meta("guard")
	var sw = _unit("swordsman", Vector2(110, 380))
	sw.move_mode = "hold"
	var hp0: float = sw.hp
	await _frames(60 * 4)
	check(sw.hp == hp0, "S  an enemy archer behind the wall doesn't shoot the troop beyond it")
	sk.queue_free()
	sw.queue_free()
	await _frames(2)
	# A shot into the wall stops there.
	var P = preload("res://scripts/troops/projectile.gd")
	var shot = P.new()
	shot.main = main
	shot.target = null
	shot.target_pos = Vector2(120, 200)
	shot.position = Vector2(120, 400)
	shot.speed = 400.0
	shot.damage = 10.0
	main.fx_layer.add_child(shot)
	var stopped := false
	for i in 90:
		await process_frame
		if not is_instance_valid(shot):
			stopped = true
			break
		if shot.position.y < 296.0:
			break
	check(stopped, "S  a shot flown into the wall stops there")
	# A villager whose road runs into a wall finds its way round.
	var O = preload("res://scripts/mission/objective.gd")
	var v = O.new()
	v.setup(main, {"id": "freed", "kind": "civilian", "name": "Townsfolk", "at": Vector2(110, 420), "variant": 1,
			"route": [Vector2(110, 200), Vector2(110, 120)], "speed": 60.0, "hp": 40.0})
	main.waves.add_objective(v)
	for i in 60 * 20:
		if v.arrived:
			break
		await process_frame
	check(v.arrived and v.position.distance_to(Vector2(110, 120)) < 20.0, "S  a villager whose road runs into a wall finds its way round it (and gets where it's going) (at %s, leg %d of %d, deploying %s)" % [v.position.round(), v.leg, v.route.size(), main.deploying])
	v.queue_free()
	# Elsewhere nothing changes.
	paths.set_map(Maps.get_map("ds_approach"))
	check(not paths.has_sight_walls() and paths.sight_clear(Vector2(0, 0), Vector2(640, 768)), "S  a map with no castle walls: sight is never blocked")
	# Doors: a shut one is solid; opened, a way through.
	var room := {"name": "door test", "camp": false, "biome": "hall", "terrain": [
		{"kind": "hall", "poly": [Vector2(0, 380), Vector2(290, 380), Vector2(290, 410), Vector2(0, 410)]},
		{"kind": "hall", "poly": [Vector2(350, 380), Vector2(640, 380), Vector2(640, 410), Vector2(350, 410)]},
		{"kind": "door", "door": "t", "poly": [Vector2(290, 380), Vector2(350, 380), Vector2(350, 410), Vector2(290, 410)]}]}
	paths.set_map(room)
	var shut: bool = paths.blocked(Vector2(320, 395), 10.0) and not paths.sight_clear(Vector2(320, 500), Vector2(320, 300))
	paths.open_door("t")
	var route: PackedVector2Array = paths.troop_route(Vector2(320, 520), Vector2(320, 260))
	check(shut and not paths.blocked(Vector2(320, 395), 10.0) and paths.sight_clear(Vector2(320, 500), Vector2(320, 300))
			and route.size() > 0 and route[route.size() - 1].distance_to(Vector2(320, 260)) < 24.0,
			"D  a shut door is solid (and blocks sight); opened, troops route through it")


# --- C ---------------------------------------------------------------------------------------

func _crowding() -> void:
	await _castle(0, [])
	await _all_in()
	main.gold = 99999
	var troops := []
	for i in 20:
		var w = _unit("swordsman" if i % 2 == 0 else "archer", Vector2(80 + (i % 10) * 50, 560 + (i / 10) * 100))
		if w == null:
			continue   # (no room to post one just there: a pillar's foot)
		troops.append(w)
	await _frames(5)
	for i in troops.size():
		troops[i].order_to(main.paths.open_spot(Vector2(130 + (i % 10) * 40, 150 + (i / 10) * 50)))
		troops[i].move_mode = "free"
	var t := 0
	var done := false
	while t < 60 * 30:
		await process_frame
		t += 1
		if troops.all(func(w): return w.position.distance_to(w.post) < 12.0):
			done = true
			break
	var left: Array = troops.filter(func(w): return w.position.distance_to(w.post) >= 12.0)
	check(done and troops.size() >= 18, "C  %d troops sent through the hall's gap all get there (%.1fs; %d not there)" % [troops.size(), t / 60.0, left.size()])


# --- E ---------------------------------------------------------------------------------------

func _entering() -> void:
	await _castle(0, ARMY, 420, false)
	var rules = main.rules
	check(rules.get_script() == load("res://scripts/mission/rules_castle.gd") and main.map_id == "dsc_gatehall" and rules.phase in ["enter", "fight"],
			"E  taken up in the Gatehouse Hall, by the castle's rules")
	check(main.gold == 420 and rules.standard != null and rules.standard.is_target(), "E  the gold as it was; the standard planted")
	var first_hp := {}
	for i in 60 * 6:
		await process_frame
		for w in main.battlefield.get_warriors():
			if not first_hp.has(w):
				first_hp[w] = w.hp / w.max_hp   # (as it came in: a Healer gets to work soon after)
		if rules.phase != "enter" and first_hp.size() >= ARMY.size():
			break
	check(main.battlefield.get_warriors().size() == ARMY.size(), "E  the whole army in (%d)" % main.battlefield.get_warriors().size())
	var by_kind := {}
	for w in main.battlefield.get_warriors():
		by_kind[w.kind + str(w.tiers)] = w
	var ok := true
	var bad := []
	for rec in ARMY:
		var w = by_kind.get(rec["kind"] + str(rec["tiers"]))
		if w == null or first_hp.get(w, -1.0) < rec["hp"] - 0.02 or first_hp.get(w, -1.0) > rec["hp"] + 0.02 and rec["kind"] != "archer" or w.priority != rec["priority"] or w.move_mode != rec["move_mode"] \
				or main.missions.temp_allies.has(w) != rec["lent"] or w.has_meta("freed") != rec["freed"]:
			ok = false
			bad.append("%s: %s" % [rec["kind"], "missing" if w == null else "hp %.2f %s %s lent %s freed %s" % [w.hp / w.max_hp, w.priority, w.move_mode, main.missions.temp_allies.has(w), w.has_meta("freed")]])
	check(ok, "E  each as it was: its kind, training, health (the Archer's topped up by the Healer at once), orders, on loan or freed %s" % str(bad))
	# The garrison holds; then, the army near, it goes for the standard.
	for e in main.battlefield.get_enemies():
		e.queue_free()
	await _frames(2)
	rules._woke = false
	var g = null
	main.waves._spawn_enemy("orc", 8, Vector2(320, 200))
	g = main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)
	g.set_meta("guard", true)
	g.goal = null
	var y0: float = g.position.y
	await _frames(60 * 2)
	check(rules.enemy_goal(g) == null and absf(g.position.y - y0) < 20.0, "E  the garrison holds its post while the army's off")
	var sw = _unit("swordsman", Vector2(320, 330))
	sw.move_mode = "hold"
	await _frames(30)
	check(rules.enemy_goal(g) == rules.standard, "E  ...and, a troop near, goes for the standard")
	# Nobody's left waiting behind a wall: a garrison archer out of everyone's sight, and a
	# troop on Guard that can't see it doesn't keep pressing at the wall for it; the
	# garrison comes out on its own soon after the army's in.
	for e in main.battlefield.get_enemies():
		e.queue_free()
	for w in main.battlefield.get_warriors():
		w.queue_free()
	await _frames(2)
	rules._woke = false
	rules.fight_t = 0.0
	main.spawn_queue.clear()   # (the room's first wave held off: only the hidden archer here)
	main.wave_active = false
	main.wave = rules.wave0
	main.waves._spawn_enemy("skeleton_archer", 8, Vector2(110, 240))
	var hid = main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)
	hid.set_meta("guard", true)
	hid.goal = null
	var gd = _unit("archer", Vector2(110, 420))
	gd.move_mode = "guard"
	var post0: Vector2 = gd.post
	await _frames(60 * 4)
	check(not gd._engageable(hid) and gd.position.distance_to(post0) < 30.0, "E  a troop on Guard doesn't go after an enemy behind the wall it can't see (it stays by its post)")
	for i in 60 * int(rules.ALERT + 6):
		if hid.goal != null:
			break
		await process_frame
	check(hid.goal == rules.standard, "E  the garrison comes out for the standard on its own within %ds of the army being in" % int(rules.ALERT + 1))


# --- T ---------------------------------------------------------------------------------------

func _through() -> void:
	await _castle(0, ARMY, 420)
	var rules = main.rules
	await _all_in()
	# The room's first wave comes at once; the battle music holds through the breathers until
	# the room's taken.
	check(main.wave == rules.wave0 + 1 and main.wave_active and rules.battle_on(), "M  in a room: its first wave at once, the battle music on")
	main.modes.clear_enemies()
	main.spawn_queue.clear()
	main.wave_active = false
	await _frames(5)
	check(rules.phase == "fight" and rules.battle_on(), "M  ...between its waves, still the battle music (no peaceful music till the room's taken)")
	var A = preload("res://scripts/audio/audio.gd")
	var siege := ["siege", "bailey", "dawngate", "gatehall", "banners", "cells", "stores", "chapel", "dungeon", "gallery", "treasury", "throne", "dawnfield"]
	check(siege.all(func(k): return A.BATTLES[k].get("motif", false)) and not A.BATTLES["ridge"].get("motif", false),
			"M  every battle of Dawnspire's siege carries the Dawnspire hymn (nowhere else does)")
	main.modes.clear_enemies()
	main.wave = rules.wave0 + int(rules.room()["waves"])
	main.spawn_queue.clear()
	main.wave_active = false
	var fallen = _unit("swordsman", Vector2(500, 600))
	await _frames(3)
	fallen.take_damage(1e6)
	await _frames(3)
	fallen.down_timer = 9999.0
	for i in 60 * int(rules.LINGER + 2):
		if rules.phase == "clear":
			break
		await process_frame
	var ways: Array = rules.arrows.map(func(a): return a["to"])
	check(rules.phase == "clear" and ways.has("banners") and ways.has("cells") and rules.action_label() != "", "T  the room taken: an arrow at each way on: the hall beyond, the cells (%s)" % str(ways))
	check(not rules.battle_on(), "M  the room taken: the peaceful music at last")
	var before := {}
	for w in main.battlefield.get_warriors():
		if w != fallen:
			before[w.kind + str(w.tiers)] = [w.hp / w.max_hp, w.priority, w.move_mode, w.position.distance_to(rules.arrows[0]["at"])]
	var gold0: int = main.gold
	# Click its arrow (a troop's down: asked first).
	main.input.pointer_down(rules._arrow_point(rules._forward()), MOUSE_BUTTON_LEFT)
	await _frames(2)
	var box = main.hud.choice_box
	check(box != null and is_instance_valid(box), "T  clicked, with a troop down: asked first (it'd be left behind)")
	for c in box.get_children():
		if c is Button and c.text == "Go on":
			c.pressed.emit()
	await _frames(2)
	check(rules.phase == "march" and main.map_id == "dsc_gatehall", "T  ...on: the troops make for the door, the view still here")
	var order := []
	var when := {}
	var t0 := -1
	for i in 60 * 20:
		await process_frame
		if main.map_id == "dsc_banners":
			if t0 < 0:
				t0 = i
			for w in main.battlefield.get_warriors():
				var key: String = w.kind + str(w.tiers)
				if not order.has(key):
					order.append(key)
					when[key] = (i - t0) / 60.0
			if rules.phase == "fight":
				break
	check(main.map_id == "dsc_banners" and rules.room()["name"] == "The Hall of Banners", "T  into the Hall of Banners")
	check(order.size() >= 5 and not main.battlefield.get_warriors().any(func(w): return w.kind == "swordsman" and w.tiers == [0, 0, 0, 0]),
			"T  they came in a few at a time (%s); the troop that was down left behind" % ", ".join(order))
	var span: float = when.values().max() - when.values().min() if not when.is_empty() else 0.0
	check(span >= 0.5 and order[order.size() - 1] == "cannon[1, 0, 0, 0]", "T  ...over %.1fs as each would have got there, the Cannoneer hauled in last (%s)" % [span, str(when)])
	var kept := true
	var bad := []
	for w in main.battlefield.get_warriors():
		var key: String = w.kind + str(w.tiers)
		if before.has(key) and (w.hp / w.max_hp < before[key][0] - 0.05 or w.priority != before[key][1] or w.move_mode != before[key][2]):
			kept = false
			bad.append("%s hp %.2f/%.2f %s/%s %s/%s" % [key, w.hp / w.max_hp, before[key][0], w.priority, before[key][1], w.move_mode, before[key][2]])
	var cannon = main.battlefield.get_warriors().filter(func(w): return w.kind == "cannon")
	check(kept and cannon.size() == 1 and cannon[0].is_active() and main.gold == gold0,
			"T  health, training and orders kept; the Cannoneer hauled through and set up; the gold the same %s gold %d/%d" % [str(bad), main.gold, gold0])
	var cp: Dictionary = campaign.checkpoint("ds_assault", 100 + BANNERS)
	check(cp.get("room", -1) == BANNERS and (cp.get("army", []) as Array).size() == main.battlefield.get_warriors().size() and int(cp.get("gold", -1)) == main.gold,
			"T  a checkpoint for the Hall of Banners (army, gold)")
	check(main.battlefield.get_warriors().all(func(w): return w.position.y > 380.0 and main.paths.troop_can_stand(w.position)),
			"T  everyone came in at the south door and stands in the room")


# --- R ---------------------------------------------------------------------------------------

## Through the way named `to` (asked, if need be, and gone on).
func _through_to(to: String) -> void:
	var rules = main.rules
	for i in 60 * int(rules.LINGER + 2):
		if rules.phase == "clear":
			break
		await process_frame
	var a = null
	for x in rules.arrows:
		if x["to"] == to:
			a = x
	if a == null:
		return
	main.input.pointer_down(rules._arrow_point(a), MOUSE_BUTTON_LEFT)
	await _frames(2)
	if main.hud.choice_box != null and is_instance_valid(main.hud.choice_box):
		for c in main.hud.choice_box.get_children():
			if c is Button and c.text == "Go on":
				c.pressed.emit()
	for i in 60 * 20:
		if rules.phase in ["fight", "clear"] and rules.room()["id"] == to:
			break
		await process_frame


func _side_rooms() -> void:
	await _castle(0, ARMY.slice(0, 3), 300)
	var rules = main.rules
	await _all_in()
	main.modes.clear_enemies()
	main.wave = rules.wave0 + int(rules.room()["waves"])
	main.spawn_queue.clear()
	await _through_to("cells")
	check(main.map_id == "dsc_cells" and rules.entry == "w" and main.battlefield.get_warriors().all(func(w): return w.position.x < 400.0),
			"R  through the side door into the Guardroom Cells, the army in by its west door")
	var warden: Array = main.battlefield.get_enemies().filter(func(e): return e.has_meta("warden"))
	check(main.battlefield.get_enemies().size() == 8 and rules.pens.size() == 3 and warden.size() == 1 and warden[0].kind == "troll" and warden[0].max_hp > 2.0 * 200.0, "R  ...its jailers there with their Warden (a Troll, far tougher), three cells locked")
	# The Warden holds the keys: troops round a cell get nowhere while he lives.
	for e in main.battlefield.get_enemies():
		if not e.has_meta("warden"):
			e.queue_free()
	warden[0].position = Vector2(560, 650)
	warden[0].speed = 0.0
	await _frames(2)
	var locked = rules.pens[2]
	var sw = _unit("swordsman", locked.position + Vector2(0, 62))
	sw.move_mode = "hold"
	await _frames(60 * 8)
	check(not locked.taken and locked.progress == 0.0, "R  the Warden alive, troops round a cell get it no nearer open (he has the keys)")
	warden[0].take_damage(1e7)
	for i in 60 * 10:
		if locked.taken:
			break
		await process_frame
	check(locked.taken, "R  ...he's down: the cell opens")
	main.modes.clear_enemies()
	await _frames(2)
	var pen = rules.pens[0]
	var lent0: int = main.missions.temp_allies.size()
	for w in main.battlefield.get_warriors():
		w.order_to(pen.position + Vector2(randf_range(-20, 20), 40))
	for i in 60 * 14:
		if pen.taken:
			break
		await process_frame
	await _frames(5)
	var joined: Array = main.missions.temp_allies.slice(lent0).filter(func(w): return w.tiers[0] == 3)
	joined = joined.filter(func(w): return w.kind == "swordsman")
	check(pen.taken and joined.size() == 1 and joined[0].kind == "swordsman" and joined[0].has_meta("freed") and joined[0].tiers[0] == 3,
			"R  a cell broken open: its soldier joins on loan (a Knight, trained to tier III)")
	var walking: int = rules.townsfolk.size()
	check(walking >= 3, "R  ...its townsfolk make for the way out (%d on their way)" % walking)
	var freed0: int = rules.freed
	for i in 60 * 25:
		if rules.townsfolk.is_empty():
			break
		await process_frame
	check(rules.townsfolk.is_empty() and rules.freed == freed0 + walking, "R  ...and get out by the door the army came in by (%d out)" % (rules.freed - freed0))
	# Back to the hall.
	await _through_to("gatehall")
	await _frames(30)
	var back_arrow = rules.arrows.filter(func(a): return a["to"] == "cells")
	check(main.map_id == "dsc_gatehall" and rules.entry == "e" and main.battlefield.get_enemies().is_empty() and rules.phase == "clear" and back_arrow.size() == 1,
			"R  back in the Gatehouse Hall by its east door: still taken, nobody there, the ways on open at once")
	var cp: Dictionary = campaign.checkpoint("ds_assault", 100)
	check((cp.get("rooms", {}).get("cells", {}).get("taken", []) as Array).has("cells:pen0") and cp["rooms"]["gatehall"]["cleared"],
			"R  the checkpoint knows what's been had (the cell opened, the hall taken)")
	# Taken up again from there: the opened cell stays open.
	campaign.save_game()
	campaign.load_game()
	await _castle_from(cp)
	rules = main.rules
	await _all_in()
	check(rules.phase == "clear" and main.battlefield.get_enemies().is_empty(), "R  taken up again in the hall: still taken")
	await _through_to("cells")
	await _frames(10)
	check(rules.pens.size() == 1 and rules.pens.all(func(p): return p.id != "cells:pen0" and p.id != "cells:pen2"), "R  ...and in the cells, the ones opened stay open (1 still locked)")
	# The stores: supplies for gold, once.
	await _castle(3, ARMY.slice(0, 3), 300)   # (room 3: the Quartermaster's Store)
	rules = main.rules
	await _all_in()
	main.modes.clear_enemies()
	await _frames(2)
	var c = rules.caches[0]
	var g0: int = main.gold
	main.gold += 500
	main.placing_type = "swordsman"
	main.hiring.hire_at(Vector2(320, 560))
	main.placing_type = ""
	var fresh = main.battlefield.get_warriors()[-1]
	await _frames(2)
	check(fresh.position.distance_to(rules.entry_point(Vector2.ZERO)) < 120.0 or fresh.position.x > 480.0,
			"R  a troop hired in a side room comes in by its door (at %s)" % fresh.position.round())
	for w in main.battlefield.get_warriors():
		w.move_mode = "hold"
	main.orders.give_order("priority", "side", [main.battlefield.get_warriors()[0]])
	for i in 60 * 10:
		if c == null or not is_instance_valid(c) or c.taken:
			break
		await process_frame
	await _frames(60 * 6)
	var claimed: int = (rules._state("stores")["taken"] as Array).size()
	check(claimed >= 2 and main.gold >= g0 + 90 - main.hiring.price(Data_cost("swordsman")), "R  a troop on Side Objectives goes after the stores' supplies on its own and claims them (%d of 3, gold %d -> %d)" % [claimed, g0, main.gold])


func Data_cost(kind: String) -> int:
	return int(preload("res://scripts/data/data.gd").WARRIORS[kind]["cost"])


## Into the castle from a checkpoint as it was saved.
func _castle_from(cp: Dictionary) -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud.hide_mode_select()
	campaign.op_resume_zone = int(cp["zone"])
	main.missions.start_mission("ds_assault")
	await process_frame
	if main.hud.story != null:
		main.hud.story.skip()
	main.missions._lock_portrait(true)
	await _frames(3)
	main.deploying = false
	main.forced_auto = false
	main.auto_play = false
	main.auto_timer = 9999.0


# --- K ---------------------------------------------------------------------------------------

func _checkpoints() -> void:
	await _castle(BANNERS, ARMY, 300)
	var rules = main.rules
	await _all_in()
	check(main.map_id == "dsc_banners" and main.gold == 300 and main.battlefield.get_warriors().size() == ARMY.size() and absf(rules.standard.hp / rules.standard.max_hp - 1.0) < 0.01,
			"K  taken up from the Hall of Banners as the army came in")
	main.battle_xp = {"swordsman": 900.0}
	var gains: Dictionary = rules.xp_gains(false, main.battle_xp)
	check(is_equal_approx(float(gains["swordsman"]), 400.0) and is_equal_approx(float(rules.xp_gains(true, main.battle_xp)["swordsman"]), 900.0),
			"K  a loss here banks only the XP since the checkpoint; a win, all of it once")
	# Too little left to win with: reserves, up to the floor, once.
	var thin := [ARMY[0].duplicate()]
	thin[0]["spent"] = 60
	await _castle(BANNERS, thin, 40)
	rules = main.rules
	var floor_gold: int = int(rules._c()["reserve"])
	check(main.gold == floor_gold - 60, "K  a checkpoint with little left: reserves bring it up to %d in all (gold %d)" % [floor_gold, main.gold])
	rules.resume(_room_cp(BANNERS, thin, 40))
	await _frames(2)
	check(main.gold == 40, "K  ...once a try, not again (gold %d)" % main.gold)


# --- L ---------------------------------------------------------------------------------------

func _stuck() -> void:
	await _castle(0, [ARMY[0]], 300)
	var rules = main.rules
	await _all_in()
	main.modes.clear_enemies()
	# A troop walled in where it can't get out.
	var boxed = _unit("archer", Vector2(560, 640))
	await _frames(2)
	main.paths.add_terrain("hall", PackedVector2Array([Vector2(520, 600), Vector2(600, 600), Vector2(600, 610), Vector2(520, 610)]))
	main.paths.add_terrain("hall", PackedVector2Array([Vector2(520, 680), Vector2(600, 680), Vector2(600, 690), Vector2(520, 690)]))
	main.paths.add_terrain("hall", PackedVector2Array([Vector2(520, 600), Vector2(530, 600), Vector2(530, 690), Vector2(520, 690)]))
	main.paths.add_terrain("hall", PackedVector2Array([Vector2(590, 600), Vector2(600, 600), Vector2(600, 690), Vector2(590, 690)]))
	main.wave = rules.wave0 + int(rules.room()["waves"])
	main.spawn_queue.clear()
	for i in 60 * 3:
		if rules.phase == "clear":
			break
		await process_frame
	rules.action()
	await _frames(2)
	if main.hud.choice_box != null and is_instance_valid(main.hud.choice_box):
		for c in main.hud.choice_box.get_children():
			if c is Button and c.text == "Go on":
				c.pressed.emit()
	var t := 0
	while main.map_id != "dsc_banners" and t < 60 * 20:
		await process_frame
		t += 1
	check(main.map_id == "dsc_banners" and t / 60.0 <= rules.FIRST_LIMIT + 2.0, "T  ...on into the next room (%.1fs)" % (t / 60.0))
	for i in 60 * int(rules.LATE_LIMIT + 3):
		if rules.phase == "fight":
			break
		await process_frame
	check(main.battlefield.get_warriors().filter(func(w): return w.kind == "archer").size() == 1, "L  the walled-in Archer doesn't hold the army up: it comes in a little after")


# --- W ---------------------------------------------------------------------------------------

func _standard() -> void:
	await _castle(0, [ARMY[0]], 300)
	var rules = main.rules
	await _all_in()
	rules.standard.take_damage(1e6)
	await _frames(30)
	check(main.game_over and not main.victory, "W  the standard falls: the army breaks, the battle's lost")
	# The Ogre King's cutscenes: from Dawnspire's throne room once the citadel's open.
	var C = preload("res://scripts/campaign/cutscene.gd")
	var c = C.new()
	root.add_child(c)
	var at_ds: bool = c._at_dawnspire()
	campaign.new_campaign("normal")
	var before: bool = c._at_dawnspire()
	c.queue_free()
	check(at_ds and not before, "W  the Ogre King speaks from Dawnspire's throne room once the citadel's open (not before)")
