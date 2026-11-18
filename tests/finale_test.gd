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
	var dodge = _unit("swordsman", k.position + Vector2(40, 60))
	var hp_s: float = stay.hp
	var hp_d: float = dodge.hp
	var warned := false
	for i in 60:
		await process_frame
		if k.stomp_wind > 0.0:
			warned = true
			break
	check(warned and stay.hp == hp_s, "S  his stomp shows its ring on the ground first (nobody's hit yet)")
	dodge.position = k.position + Vector2(260, 200)
	dodge.post = dodge.position
	dodge.move_mode = "hold"
	await _frames(70)
	check(stay.hp < hp_s and dodge.hp == hp_d, "S  ...then lands on whoever's still in it, not on the troop that got clear")


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
func _go(to: String) -> void:
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
		if main.rules != r or (r.room()["id"] == to and r.phase == "clear"):
			break


# --- F ---------------------------------------------------------------------------------------

func _field() -> void:
	var r = main.rules
	await _go("field")
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
	check(main.temp_allies.size() == want and want >= 16, "F  ...every people's help, by what was done for them (%d units, %d points)" % [main.temp_allies.size(), want])
	check(f.escaped >= 9 and main.get_enemies().size() == f.escaped, "F  ...and his that got out of the castle are on the field (%d: the Cells' guards among them)" % f.escaped)
	check(campaign.checkpoint("ds_assault", 300).get("zone", 0) == 300, "F  ...a checkpoint for the field")
	# He comes out with the second wave.
	main.clear_enemies()
	main.wave = f.wave0 + f.KING_AT_WAVE
	await _frames(5)
	var k = f.king
	check(k != null and k.kind == "ogre_unbound" and k.aura.a > 0.0, "F  the Ogre King, Unbound, comes out with the second wave")
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
	# Burning ground, shown first.
	for i in 60 * 5:
		if k.exposed <= 0.0 and k.charging <= 0.0 and k.charge_warn <= 0.0:
			break
		await process_frame
	k.charge_timer = 99.0
	k.position = Vector2(320, 300)
	var near = _unit("archer", Vector2(260, 430))
	if near != null:
		near.move_mode = "hold"
	k.embers_timer = 0.0
	await _frames(3)
	var patches: Array = main.corpse_layer.get_children().filter(func(n): return n.get_script() == load("res://scripts/ember_patch.gd"))
	check(not patches.is_empty() and patches[0].t < patches[0].warn, "F  ...his burning ground is marked before it catches")
	# Brought down: won, the fully united ending.
	k.take_damage(1e9)
	await _frames(30)
	check(main.game_over and main.victory and campaign.flags.has("ds_united") and campaign.completed.has("ds_assault"),
			"F  brought down, the horde breaks: the Liberation won, the fully united ending")
	var outro: Array = campaign.story_lines("ds_assault_outro").map(func(l): return l["text"])
	check(outro.any(func(t): return "tenth" in t), "F  ...its story the united ending's")
	# Taken up again on the field.
	_all_nine()
	await _start(300, {"zone": 300, "name": "The Fields of Dawn", "gold": 333, "wave": 14, "army": ARMY, "xp": {}, "owned": [],
			"standard": 0.8, "escaped": 3, "garrisons": []})
	await _frames(10)
	check(main.rules.get_script() == load("res://scripts/mission/rules_finale.gd") and main.gold == 333 and main.get_warriors().filter(func(w): return not main.temp_allies.has(w)).size() == ARMY.size(),
			"F  taken up again on the field: as the army came out onto it")
