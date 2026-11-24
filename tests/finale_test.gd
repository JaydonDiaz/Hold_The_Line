extends SceneTree
## Phase 5, F4 and F5: the Ogre King, and the end of the Liberation of Dawnspire, on both
## routes. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/finale_test.gd
##   S  slam        the King's stomp shows its ring first and lands only on those still in it
##   P  prepared    all nine beacons lit: he's ready for the army (a tower more in each field,
##                   sally parties twice as often, his King's Guard, his own words); fewer than
##                   nine: as before
##   T  throne      the Gallery's way on is the Throne Room: the King on his throne, his guard
##                   round him; he speaks as the army comes in; the room isn't taken while he
##                   stands
##   K  standard    fewer than nine beacons (the minimum seven too): beaten, he falls: the
##                   Liberation's won with the standard ending
##   U  unbound     all nine: beaten, he draws on the beacon instead and is gone; the castle
##                   comes down (falls of stone, shown first); the army gets out hall by hall,
##                   back the way it came (in by each hall's north door); what of his is left
##                   (and an untaken side room's guards) runs for the way out too, and any that
##                   get out are counted; every hall on the way out is a checkpoint
##   F  field       out of the castle, the Fields of Dawn: the army, the tower crews come back,
##                   help from every people by what was done for them, his escapees already
##                   there; the Unbound King comes out with the second wave: his charge shows
##                   its line first and leaves him exposed (hit harder), his burning ground shows
##                   first; brought down, the horde breaks: won with the fully united ending;
##                   taken up again from the field's checkpoint as it was
## Uses a scratch save path, never the player's own save.

const TEST_SAVE := "user://finale_test_campaign.cfg"
const CD = preload("res://scripts/campaign_data.gd")
const Data = preload("res://scripts/data.gd")
const OathArts = preload("res://scripts/mission/oath_arts.gd")

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
		_skip_story()


## Stories in the middle of the battle (the game held still): skipped.
var stories := 0   # how many have been skipped (each played, then)

func _skip_story() -> void:
	if main != null and is_instance_valid(main) and main.hud.story != null and is_instance_valid(main.hud.story):
		stories += 1
		main.hud.story.skip()


## Every region secured, every people joined: all nine beacons.
func _all_nine() -> void:
	campaign.new_campaign("normal")
	campaign.completed = CD.MISSIONS.keys().filter(func(m): return m != "ds_assault")
	campaign.allies = CD.FACTIONS.keys()


## The shortest route there: Ashwatch, Stonehollow, two of the south, Sable, two of the
## north, the Spires (seven beacons).
func _minimum() -> void:
	campaign.new_campaign("normal")
	campaign.completed = ["ashwatch", "ashwatch_road", "stonehollow", "stonehollow_workshops", "gw_exodus", "gw_watchfires",
		"mv_wounded", "mv_sanctuary", "sable_crossing", "fm_pass", "fm_vigil", "mo_steps", "mo_gate", "sp_circle", "sp_relight"]
	campaign.allies = ["stonehollow", "greenwood", "mercyvale", "frostmarch", "monastery", "spires"]


func _room(id: String) -> int:
	var rooms: Array = CD.MISSIONS["ds_assault"]["assault"]["castle"]["rooms"]
	for i in rooms.size():
		if rooms[i]["id"] == id:
			return i
	return -1


const ARMY := [
	{"kind": "swordsman", "tiers": [2, 1, 0, 0], "hp": 1.0, "post": Vector2(260, 560), "spent": 200},
	{"kind": "swordsman", "tiers": [0, 0, 1, 0], "hp": 1.0, "post": Vector2(380, 560), "spent": 120},
	{"kind": "archer", "tiers": [2, 0, 0, 2], "hp": 1.0, "post": Vector2(300, 640), "spent": 300},
	{"kind": "healer", "tiers": [1, 0, 0, 0], "hp": 1.0, "post": Vector2(340, 680), "spent": 140},
]


func _start(zone: int, cp: Dictionary = {}) -> void:
	if not cp.is_empty():
		campaign.set_checkpoint("ds_assault", zone, cp)
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud.hide_mode_select()
	campaign.op_resume_zone = zone
	campaign.mission_id = "ds_assault"
	main.start_mission("ds_assault")
	await process_frame
	_skip_story()
	main._lock_portrait(true)
	await _frames(3)
	main.deploying = false
	main.forced_auto = false
	main.auto_play = false
	main.auto_timer = 9999.0


func _throne_cp(extra := {}) -> Dictionary:
	var i := _room("throne")
	var cp := {"zone": 100 + i, "room": i, "entry": "s", "name": "The Throne Room", "gold": 400, "wave": 12, "army": ARMY,
		"xp": {}, "owned": [], "standard": 1.0, "rooms": {}, "garrisons": [], "stragglers": []}
	cp.merge(extra, true)
	return cp


func _all_in() -> void:
	for i in 60 * 12:
		await process_frame
		_skip_story()
		if main.rules.get("phase") != "enter":
			break


func _run() -> void:
	await _slam()
	await _prepared()
	await _throne_and_standard()
	await _unbound_and_escape()
	await _field()
	await _arts()
	if main != null:
		main.get_tree().paused = false
		main.free()
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


# --- S ---------------------------------------------------------------------------------------

func _slam() -> void:
	_minimum()
	await _start(100 + _room("throne"), _throne_cp())
	await _all_in()
	var r = main.rules
	var k = r.king
	main.clear_enemies() if false else null
	for e in main.get_enemies():
		if e != k:
			e.queue_free()
	for w in main.get_warriors():
		w.queue_free()
	await _frames(2)
	k.remove_meta("guard")
	k.speed = 0.0
	k.stomp_timer = 0.0
	var stay = _unit("swordsman", k.position + Vector2(-40, 60))
	stay.move_mode = "hold"
	stay.dazed = 99.0   # (stunned: it can't get out)
	var dodge = _unit("martial", k.position + Vector2(40, 60))   # (quick on his feet: a Knight would brace for it, see defense_test)
	var hp_s: float = stay.hp
	var hp_d: float = dodge.hp
	var warned := false
	for i in 60:
		await process_frame
		if k.stomp_wind > 0.0:
			warned = true
			break
	check(warned and stay.hp == hp_s, "S  his stomp shows its ring on the ground first (nobody's hit yet)")
	var at_landing := INF
	for i in 70:
		await process_frame
		if k.stomp_wind <= 0.0 and at_landing == INF:
			at_landing = dodge.position.distance_to(k.position)   # (where it stood as the stomp landed: after, it's back at him)
	check(stay.hp < hp_s and dodge.hp == hp_d, "S  ...then lands on whoever's still in it, not on the troop that got clear")
	check(at_landing > float(k.stomp["radius"]), "S  ...a quick troop free to move got out of the ring by itself (%.0fpx out as it landed)" % at_landing)


func _unit(kind: String, at: Vector2):
	main.gold += 5000
	var had: Array = main.get_warriors()
	main.placing_type = kind
	main.hire_at(main.paths.open_spot(at))
	main.placing_type = ""
	main.gold -= 5000
	var fresh: Array = main.get_warriors().filter(func(x): return not had.has(x))
	if fresh.is_empty():
		return null
	fresh[0].build_left = 0.0
	fresh[0].position = fresh[0].post
	return fresh[0]


# --- P ---------------------------------------------------------------------------------------

func _prepared() -> void:
	_minimum()
	check(campaign.beacon_count() == 7, "P  the minimum route: seven beacons (%d)" % campaign.beacon_count())
	await _start(0)
	var towers0: int = main.rules.towers.size()
	var lines0: Array = campaign.story_lines("ds_assault_intro").map(func(l): return l["text"])
	_all_nine()
	check(campaign.beacon_count() == 9, "P  every region secured: all nine (%d)" % campaign.beacon_count())
	await _start(0)
	var r = main.rules
	var guards: Array = main.get_enemies().filter(func(e): return e.has_meta("title"))
	check(r.united() and r.towers.size() == towers0 + 1, "P  all nine: he's ready: a tower more in the field (%d, not %d)" % [r.towers.size(), towers0])
	var lines9: Array = campaign.story_lines("ds_assault_intro").map(func(l): return l["text"])
	check(lines9.size() > lines0.size() and lines9.any(func(t): return "nine" in t.to_lower()), "P  ...and he says so (and Ysolde and Hale see it)")
	r.sallied = 0
	var sallies := 0
	r.wagon.leg = r.wagon.route.size() - 1
	r.wagon.position = r.wagon.route[r.wagon.route.size() - 1]
	for i in 12:
		r.phase = "advance"
		if r.spawn_point(14.0) != Vector2.INF:
			sallies += 1
	check(sallies == 6, "P  ...his sally parties come out twice as often (%d of 12)" % sallies)
	await _start(100 + _room("gallery"), {"zone": 100 + _room("gallery"), "room": _room("gallery"), "entry": "s", "name": "The Long Gallery",
			"gold": 400, "wave": 12, "army": ARMY, "xp": {}, "owned": [], "standard": 1.0})
	await _all_in()
	var kg: Array = main.get_enemies().filter(func(e): return e.get_meta("title", "") == "King's Guard")
	check(kg.size() >= 2, "P  ...and his King's Guard stand in the Long Gallery (%d)" % kg.size())


# --- T, K ------------------------------------------------------------------------------------

func _throne_and_standard() -> void:
	var gallery: Dictionary = CD.MISSIONS["ds_assault"]["assault"]["castle"]["rooms"][_room("gallery")]
	check(gallery["doors"]["n"] == "throne", "T  the Long Gallery's way on is the Throne Room")
	_minimum()
	stories = 0
	await _start(100 + _room("throne"), _throne_cp())
	# Marching in (not taken up again): he speaks the moment the army comes through the door.
	var rr = main.rules
	for e in main.get_enemies():
		e.queue_free()
	for w in main.get_warriors():
		w.queue_free()
	await process_frame
	rr.told_throne = false
	stories = 0
	rr._enter_room(rr.room_i, ARMY.map(func(rec): return [rec, 4.0]), 1.0, "s", false)
	await process_frame
	check(main.hud.story != null and main.get_tree().paused and rr.phase == "enter" and main.get_warriors().is_empty(),
			"T  his cutscene plays the moment the army comes into the throne room, the game held still (nobody in yet)")
	_skip_story()
	stories = 0
	await _start(100 + _room("throne"), _throne_cp())
	var told := stories > 0
	for i in 60 * 12:
		await process_frame
		if main.hud.story != null and is_instance_valid(main.hud.story):
			told = true
			main.hud.story.skip()
		if main.rules.phase != "enter" and told:
			break
	var r = main.rules
	check(main.map_id == "dsc_throne" and r.king != null and r.king.kind == "ogre_king" and r.king.has_meta("undying"),
			"T  the Throne Room: the Ogre King on his throne")
	check(told, "T  ...he speaks as the army comes in (the game held still)")
	var throne_at: Vector2 = r.king.position
	await _frames(60 * 3)
	check(r.phase == "fight", "T  ...and the room isn't taken while he stands")
	check(r.enemy_goal(r.king) == null and r.king.position.distance_to(throne_at) < 80.0,
			"T  ...he holds his dais (fighting whoever comes at him), not marching on the standard")
	r.king.hp = r.king.max_hp * 0.4
	r.king.enraged = true
	check(r.enemy_goal(r.king) == r.standard, "T  ...enraged, he comes for the standard himself")
	# Beaten: he falls (fewer than nine beacons).
	r.king.take_damage(1e9)
	await _frames(60)
	check(main.game_over and main.victory and campaign.completed.has("ds_assault") and not campaign.flags.has("ds_united"),
			"K  seven beacons: beaten, he falls, and the Liberation is won (the standard ending)")
	var outro: Array = campaign.story_lines("ds_assault_outro").map(func(l): return l["text"])
	check(outro.any(func(t): return "Not every people came" in t) and not outro.any(func(t): return "tenth" in t), "K  ...its story the standard ending's")


# --- U ---------------------------------------------------------------------------------------

func _unbound_and_escape() -> void:
	_all_nine()
	campaign.held_towers = []
	var cleared := {}
	for id in ["gatehall", "banners", "chapel", "gallery", "stores", "dungeon", "treasury"]:
		cleared[id] = {"cleared": true, "taken": []}   # (the Guardroom Cells left alone)
	await _start(100 + _room("throne"), _throne_cp({"rooms": cleared, "garrisons": [{"zone": 0, "field": "The Approach", "tower": "tower",
			"crew": {"kind": "archer", "tiers": [2, 0, 0, 2], "hp": 1.0, "post": Vector2(186, 214)}}]}))
	await _all_in()
	var r = main.rules
	var k = r.king
	var guards: Array = main.get_enemies().filter(func(e): return e.get_meta("title", "") == "King's Guard")
	check(guards.size() >= 2, "U  all nine: his King's Guard beside him in the throne room (%d)" % guards.size())
	k.take_damage(1e9)
	await _frames(30)
	check(not main.game_over and r.escaping and (r.king == null) and not is_instance_valid(k) or (is_instance_valid(k) and k.is_queued_for_deletion()),
			"U  all nine: beaten, he doesn't fall: he draws on the beacon and is gone, and the castle starts coming down")
	check(r.phase == "clear" and r.arrows.size() == 1 and r.arrows[0]["to"] == "gallery", "U  ...the only way: back out, to the Long Gallery")
	var cp: Dictionary = campaign.checkpoint("ds_assault", 200 + _room("throne"))
	check(cp.get("escape", false), "U  ...a checkpoint for getting out")
	# What of his is left runs for the way out: any that make it are counted.
	var fleeing: Array = main.get_enemies().filter(func(e): return e.has_meta("fleeing"))
	check(not fleeing.is_empty() and fleeing.all(func(e): return r.enemy_goal(e) == null), "U  ...the guard he leaves runs for the way out too (%d)" % fleeing.size())
	var esc0: int = r.escaped
	r.on_reached_bottom(fleeing[0])
	check(r.escaped == esc0 + 1, "U  ...one that gets out is counted (it'll be outside)")
	for e in main.get_enemies():
		e.queue_free()
	# Stone falls, shown first.
	r.rock_t = 0.0
	await _frames(5)
	var falls: Array = main.corpse_layer.get_children().filter(func(n): return "damage" in n and "t" in n and n.t < 1.4)
	check(not falls.is_empty(), "U  ...stone falls, its ring on the ground first")
	# Out, hall by hall.
	for to in ["gallery", "chapel", "banners", "gatehall"]:
		await _go(to)
		check(main.map_id == CD.MISSIONS["ds_assault"]["assault"]["castle"]["rooms"][_room(to)]["map"] and r.entry == "n" and r.escaping,
				"U  ...into %s by its north door, on the way out" % to)
		if to == "gatehall":
			var cells: Array = main.get_enemies().filter(func(e): return e.has_meta("fleeing"))
			check(cells.size() >= 4, "U  ...the Guardroom Cells weren't taken: their guards run for it through the hall (%d)" % cells.size())
			var before: int = r.escaped
			check(true, "U  (%d got out so far)" % before)
	check(r.arrows.size() == 1 and r.arrows[0]["to"] == "field", "U  ...from the Gatehouse Hall, out onto the field")


## Through the one way out, answered if asked.
func _go(to: String, hold_on_arrival := false) -> void:
	var r = main.rules
	for i in 60 * 6:
		if r.phase == "clear":
			break
		await _frames(1)
	var a = null
	for x in r.arrows:
		if x["to"] == to:
			a = x
	if a == null:
		return
	r._ask(a)
	await _frames(2)
	if main.hud.choice_box != null and is_instance_valid(main.hud.choice_box):
		for c in main.hud.choice_box.get_children():
			if c is Button and c.text == "Go on":
				c.pressed.emit()
	for i in 60 * 20:
		await _frames(1)
		if hold_on_arrival and main.rules != r:
			main.get_tree().paused = true   # (as a story the new ground starts with does)
		if main.rules != r or (r.room()["id"] == to and r.phase == "clear"):
			break


# --- F ---------------------------------------------------------------------------------------

func _field() -> void:
	var r = main.rules
	var view: Vector2 = main.position
	await _go("field", true)
	var mid: Vector2 = main.position
	await _frames(90)
	check(main.get_tree().paused and not mid.is_equal_approx(view) and main.position.is_equal_approx(view),
			"F  the view slides all the way onto the field even with the game held still at once, as a story holds it (%s, was %s)" % [main.position, view])
	_skip_story()
	main.get_tree().paused = false
	for i in 60 * 10:
		await _frames(1)
		if main.map_id == "ds_dawnfield":
			break
	await _frames(30)
	var f = main.rules
	check(f.get_script() == load("res://scripts/mission/rules_finale.gd") and main.map_id == "ds_dawnfield", "F  out of the castle: the Fields of Dawn")
	var crews: Array = main.get_warriors().filter(func(w): return w.kind == "archer" and w.tiers == [2, 0, 0, 2] and not main.temp_allies.has(w))
	check(crews.size() >= 1, "F  ...the crew who held a tower outside is back in the fight")
	var want := 0
	for fac in f.HELP:
		want += f.help_points(fac)
	check(want >= 16, "F  every people's help, by what was done for them (%d points)" % want)
	var here := 0
	for fac in f.FIELDS[0]["help"]:
		here += f.help_points(fac)
	check(main.temp_allies.size() == here and here < want, "F  ...only the peoples waiting on this field are here at first (%d of %d)" % [main.temp_allies.size(), want])
	check(campaign.checkpoint("ds_assault", 300).get("zone", 0) == 300, "F  ...a checkpoint for the field")
	# Out of the castle: it comes down, and he bursts out through the ruins, swelling to a giant.
	var shook := false
	var grew_from := 0.0
	for i in 60 * 8:
		await process_frame
		_skip_story()
		if f.intro_t > f.INTRO_SHAKE and f.intro_t < f.INTRO_FALL and main.position != Vector2.ZERO:
			shook = true
		if f.king != null and is_instance_valid(f.king) and grew_from == 0.0:
			grew_from = f.king.sprite_scale
		if f.intro_t < 0.0 and f.king != null:
			break
	main.get_tree().paused = false
	var k = f.king
	var d: Dictionary = Data.ENEMIES["ogre_unbound"]
	check(shook and f.collapsed and main.map_extra.get("ruined", false), "F  out of the castle, the ground shakes and Dawnspire's walls come down: in ruins")
	check(k != null and k.kind == "ogre_unbound" and k.aura.a > 0.0 and grew_from < k.sprite_scale, "F  the Ogre King, Unbound, bursts out through the ruins...")
	check(is_equal_approx(k.sprite_scale, float(d["scale"]) * f.GROW) and is_equal_approx(k.radius, float(d["radius"]) * f.GROW),
			"F  ...and the broken oath swells him to a giant (x%.2f)" % (k.sprite_scale / float(d["scale"])))
	check(main.position == Vector2.ZERO, "F  ...the view steady again after")
	await _frames(5)
	check(f.escaped >= 9 and main.get_enemies().filter(func(e): return e != k).size() == f.escaped, "F  ...and his that got out of the castle are on the field (%d: the Cells' guards among them)" % f.escaped)
	main.clear_enemies() if false else null
	# His charge: its line first, then the rush, then he's exposed.
	main.clear_enemies() if false else null
	for w in main.get_warriors():
		w.queue_free()
	await _frames(2)
	k.position = Vector2(320, 300)
	k.charge_timer = 0.0
	k.stomp_timer = 99.0
	var bait = _unit("swordsman", Vector2(320, 470))
	bait.move_mode = "hold"
	var warned := false
	var ex := false
	var vul0: float = k.vuln
	for i in 60 * 4:
		await process_frame
		if k.charge_warn > 0.0:
			warned = true
		if k.exposed > 0.0:
			ex = k.vuln > vul0
			break
	check(warned and ex, "F  ...his charge shows its line on the ground first, and leaves him exposed (hit harder) after")
	check(k.embers_timer == INF and k.horn.is_empty() and not k.enraged, "F  ...on the first field: the slam and the charge only")
	for i in 60 * 5:
		if k.exposed <= 0.0 and k.charging <= 0.0 and k.charge_warn <= 0.0:
			break
		await process_frame
	# Worn down to his mark: he goes no lower, roars, and the army falls back.
	k.charge_timer = 99.0
	for e in main.get_enemies():
		if e != k:
			e.queue_free()   # (the fire alone: nothing else fighting the army here)
	var slow = f._make_unit({"kind": "alchemist", "post": k.position + Vector2(40, 170)})   # (the slowest troop there is, just outside his slam)
	seed(5150)   # (where the bursts land is random: the same each run here)
	for w in main.get_warriors():
		w.hp = w.max_hp   # (the charge's bait mended: only what the fire does counts here)
	var army0: int = main.get_warriors().size()
	k.take_damage(1e9)
	check(not k.dead and is_equal_approx(k.hp, k.max_hp * 0.66) and f.wrath != null, "F  worn to 2/3 on the first field, he goes no lower: he draws on the beacon")
	await _frames(60)
	var fires: Array = main.corpse_layer.get_children().filter(func(n): return n is OathArts.WrathFire)
	check(f.wrath.warning() and fires.is_empty() and "fall back" in f.status(), "F  ...a warning first, before any fire (%s)" % f.status())
	for i in int(60 * (OathArts.BeaconWrath.WARN + 2.0)):
		await process_frame
		for e in main.get_enemies():
			if e != k:
				e.queue_free()
	fires = main.corpse_layer.get_children().filter(func(n): return n is OathArts.WrathFire)
	var burnt: Array = main.get_warriors().filter(func(w): return w.is_active() and not w.is_emplacement() and w.hp < w.max_hp * 0.5)
	check(f.field == 0 and not fires.is_empty() and fires.all(func(b): return b.position.y > k.position.y - 70.0) and burnt.is_empty(),
			"F  ...then bursts of fire across the field from him, marked first, the army getting ahead of them (%d bursts; hurt: %s; king at %.0f, bursts from %.0f)" % [fires.size(), burnt.map(func(w): return "%s %.0f/%.0f" % [w.kind, w.hp, w.max_hp]), k.position.y, fires.map(func(b): return b.position.y).min() if not fires.is_empty() else 0.0])
	var gap := 0.0
	var slow_fell := false
	var burnt_bad := false
	for i in 60 * 40:
		await process_frame
		if f.field == 1:
			break
		if not is_instance_valid(slow) or not slow.is_active():
			slow_fell = true
		for w in main.get_warriors():
			if w.is_active() and not w.is_emplacement() and w.hp < w.max_hp * 0.5:
				burnt_bad = true
		for e in main.get_enemies():
			if e != k:
				e.queue_free()   # (the fire alone)
		if f.wrath != null and is_instance_valid(f.wrath) and not f.wrath.warning():
			for w in main.get_warriors():
				if w.is_active() and not w.is_emplacement():
					gap = maxf(gap, f.wrath.front - w.position.y)
	check(gap < 70.0 and not slow_fell and not burnt_bad, "F  ...slow enough that nobody's caught as it creeps down the field, even an Alchemist that started just below him (worst %.0f px behind its front, getting round him)" % gap)
	await _frames(5)
	check(f.field == 1 and main.map_id == "ds_bailey", "F  ...the army falls back to the Outer Bailey")
	here = 0
	for fac in f.FIELDS[1]["help"]:
		here += f.help_points(fac)
	check(main.get_warriors().size() >= army0 + here - 1, "F  ...carried as it stood, and the peoples dug in there join it (%d, was %d, +%d)" % [main.get_warriors().size(), army0, here])
	var cp1: Dictionary = campaign.checkpoint("ds_assault", 301)
	check(cp1.get("field", -1) == 1 and is_equal_approx(float(cp1.get("king", 0.0)), 0.66), "F  ...a checkpoint for the Bailey (him at 66%)")
	check(f.king == null and f.king_in > 10.0, "F  ...with a lead on him (%.0fs)" % f.king_in)
	f.king_in = 0.01
	await _frames(3)
	k = f.king
	check(k != null and is_equal_approx(k.hp / k.max_hp, 0.66) and is_equal_approx(k.hp_floor / k.max_hp, 0.33), "F  he comes on after them, as he was; his mark here 1/3")
	# Burning ground on the second field, shown first.
	k.charge_timer = 99.0
	k.stomp_timer = 99.0
	k.speed = 0.0
	k.position = Vector2(320, 300)
	var near = _unit("archer", Vector2(260, 430))
	if near != null:
		near.move_mode = "hold"
	k.embers_timer = 0.0
	await _frames(3)
	var patches: Array = main.corpse_layer.get_children().filter(func(n): return n.get_script() == load("res://scripts/ember_patch.gd"))
	check(not patches.is_empty() and patches[0].t < patches[0].warn, "F  ...here his burning ground too, marked before it catches")
	await _frames(int(60 * 1.6))
	check(near == null or near.position.distance_to(patches[0].position) > patches[0].radius, "F  ...and the troop it was marked under gets off it")
	# He breaks through the bottom of the field: the army falls back anyway, the damage not done still to do.
	k.position = Vector2(320, main.CASTLE_Y - 10.0)
	k.speed = 40.0
	for i in 60 * 4:
		await process_frame
		if f.field == 2:
			break
	await _frames(5)
	check(f.field == 2 and main.map_id == "ds_approach" and f.king_hp > 0.6 and f.king_hp <= 0.66, "F  he breaks through the bottom of the Bailey: back to the Approach, him still at 66%")
	check(f.king_in > 0.0 and f.king_in <= f.KING_PUSHED, "F  ...with less of a lead (%.0fs)" % f.king_in)
	var cp2: Dictionary = campaign.checkpoint("ds_assault", 302).duplicate(true)
	f.king_in = 0.01
	await _frames(3)
	k = f.king
	check(k != null and k.enraged and not k.horn.is_empty() and k.hp_floor == 0.0, "F  on the Approach: enraged, his war horn, and nothing holding him up")
	# Brought down: won, the fully united ending.
	k.take_damage(1e9)
	await _frames(30)
	check(main.game_over and main.victory and campaign.flags.has("ds_united") and campaign.completed.has("ds_assault"),
			"F  brought down, the horde breaks: the Liberation won, the fully united ending")
	var outro: Array = campaign.story_lines("ds_assault_outro").map(func(l): return l["text"])
	check(outro.any(func(t): return "tenth" in t), "F  ...its story the united ending's")
	# Taken up again on the Approach: he reaches the camp, and it's lost.
	_all_nine()
	await _start(302, cp2)
	await _frames(10)
	f = main.rules
	check(f.field == 2 and main.map_id == "ds_approach", "F  taken up again on the Approach")
	f.king_in = 0.01
	await _frames(3)
	f.king.position = Vector2(320, f.CAMP_Y + 2.0)
	await _frames(20)
	check(main.game_over and not main.victory, "F  ...he reaches the camp: lost")
	# Taken up again on the field.
	_all_nine()
	await _start(300, {"zone": 300, "name": "The Fields of Dawn", "gold": 333, "wave": 14, "army": ARMY, "xp": {}, "owned": [],
			"standard": 0.8, "escaped": 3, "garrisons": []})
	await _frames(10)
	check(main.rules.get_script() == load("res://scripts/mission/rules_finale.gd") and main.gold == 333 and main.get_warriors().filter(func(w): return not main.temp_allies.has(w)).size() == ARMY.size(),
			"F  taken up again on the field: as the army came out onto it")


# --- O ---------------------------------------------------------------------------------------

## His arts, each the art of one people of the Line; his health by the army he faces.
func _arts() -> void:
	_all_nine()
	await _start(300, {"zone": 300, "field": 2, "name": "The Approach", "gold": 100, "wave": 14, "army": ARMY, "xp": {}, "owned": [],
			"standard": 1.0, "king": 1.0, "escaped": 0, "garrisons": []})
	await _frames(5)
	var f = main.rules
	main.clear_enemies()
	for w in main.get_warriors():
		w.queue_free()
	await _frames(2)
	# His health, by the army.
	var few = _unit("swordsman", Vector2(320, 600))
	check(is_equal_approx(f.army_mult(), 1.0), "O  against a small army he's as strong as ever (x%.2f)" % f.army_mult())
	for i in 14:
		var w = _unit(["mage", "martial", "archer", "healer"][i % 4], Vector2(80 + (i % 7) * 70, 560 + (i / 7) * 60))
		if w != null:
			w.tiers = [4, 2, 0, 0]
			w._apply_upgrades()
	var mult: float = f.army_mult()
	check(mult > 1.5, "O  against a big, well-trained army he's that much stronger (x%.2f)" % mult)
	f.king_in = 0.01
	await _frames(3)
	var k = f.king
	check(k != null and k.max_hp > Data.ENEMIES["ogre_unbound"]["hp"] * f.KING_HP * 1.4, "O  ...his health grown to match (%.0f)" % (k.max_hp if k else 0.0))
	k.speed = 0.0
	k.position = Vector2(320, 200)
	k.stomp_timer = 999.0
	k.charge_timer = 999.0
	k.embers_timer = 999.0
	k.horn_timer = 999.0
	f.art_t = 999.0
	# Greenwood's: fire arrows that follow their troops.
	f.use_art("greenwood")
	await _frames(2)
	var arrows: Array = main.fx_layer.get_children().filter(func(n): return n is OathArts.OathArrow)
	check(arrows.size() >= 4, "O  Greenwood's art turned on you: fire arrows, one at each of the farthest troops (%d)" % arrows.size())
	var t0: Array = main.get_warriors().map(func(w): return w.hp)
	await _frames(90)
	var hurt := 0
	var ws: Array = main.get_warriors()
	for i in mini(ws.size(), t0.size()):
		if ws[i].hp < t0[i]:
			hurt += 1
	check(hurt >= 4, "O  ...they find them (%d hurt)" % hurt)
	# Stonehollow's: a bolt's line on the ground first, then through whoever's in it.
	var pinned = f._make_unit({"kind": "swordsman", "post": Vector2(320, 450)})
	pinned.dazed = 99.0
	var hp_p: float = pinned.hp
	f.use_art("stonehollow")
	await _frames(2)
	var lances: Array = main.corpse_layer.get_children().filter(func(n): return n is OathArts.OathLance)
	check(lances.size() == 1 and main.dangers().size() >= 1, "O  Stonehollow's: a ballista bolt's line shown on the ground first")
	await _frames(90)
	check(pinned.hp < hp_p, "O  ...then the bolt, through whoever's still in its line")
	# Frostmarch's: a ring of frost; whoever's still in it is frozen.
	var cold = f._make_unit({"kind": "swordsman", "post": Vector2(330, 470)})
	cold.dazed = 0.3
	cold.move_mode = "hold"
	f.use_art("frostmarch")
	await _frames(2)
	var rings: Array = main.corpse_layer.get_children().filter(func(n): return n is OathArts.WinterRing)
	check(rings.size() == 1, "O  Frostmarch's: a ring of frost on the ground")
	var ring_at: Vector2 = rings[0].position if rings.size() == 1 else Vector2.ZERO
	cold.position = ring_at
	cold.dazed = 99.0
	await _frames(110)
	check(cold.dazed > 1.0 and cold.hp < cold.max_hp, "O  ...whoever's still in it when it lands is frozen")
	# Deepdelve's and the Monastery's: shells and a Spirit Bomb, rings on the ground first.
	var shells0: int = main.dangers().size()
	f.use_art("deepdelve")
	f.use_art("monastery")
	await _frames(2)
	check(main.dangers().size() >= shells0 + 3, "O  Deepdelve's shells and the Monastery's Spirit Bomb, each marked on the ground (%d)" % (main.dangers().size() - shells0))
	# The Spires': the dead rise round him.
	var e0: int = main.get_enemies().size()
	f.use_art("spires")
	await _frames(2)
	check(main.get_enemies().size() >= e0 + 3, "O  the Spires' necromancy: the dead rise round him (%d)" % (main.get_enemies().size() - e0))
	# The Free Cities': a dirge: the army round him weakened, his horde driven on.
	var near = f._make_unit({"kind": "swordsman", "post": k.position + Vector2(60, 120)})
	near.move_mode = "hold"
	main._spawn_enemy("orc", 10, k.position + Vector2(-90, 60))
	var minion = main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)
	minion.speed = 0.0
	f.use_art("freecities")
	await _frames(20)
	check(near.hex_left > 0.0 and near.buff["damage"] < 0.0 and minion.rally > 0.0, "O  the Free Cities': a dirge: the army near him weakened, his horde driven on")
	# Mercyvale's: Stolen Mercy, drawn first: hit him hard and it's broken off; let it be and it heals.
	for w in main.get_warriors():
		w.queue_free()
	var keep = f._make_unit({"kind": "swordsman", "post": Vector2(600, 700)})   # (one left: the army isn't gone)
	keep.move_mode = "hold"
	main._spawn_enemy("orc", 10, k.position + Vector2(90, 60))
	minion = main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)
	minion.speed = 0.0
	await _frames(2)
	minion.hp = minion.max_hp * 0.3
	k.hp = k.max_hp * 0.5
	f.use_art("mercyvale")
	await _frames(10)
	k.take_damage(k.max_hp * 0.05)
	await _frames(150)
	check(minion.hp < minion.max_hp * 0.5, "O  Mercyvale's: Stolen Mercy, broken off by hitting him hard while he draws it")
	f.use_art("mercyvale")
	await _frames(150)
	check(minion.hp > minion.max_hp * 0.6, "O  ...let be, it mends his horde round him")

