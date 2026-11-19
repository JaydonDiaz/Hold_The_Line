extends "res://scripts/mission/rules.gd"
## The Liberation of Dawnspire's last battle (Phase 5, F5: the nine-beacon route only): a
## fighting retreat. The army has got out of the castle with the Ogre King, Unbound, after
## it; it falls back the way it came, field by field, to its camp at the foot of the
## Approach, wearing him down as it goes. The Line's help is dug in along the way.
##
##   The fields    the Fields of Dawn (below the gate), the Outer Bailey, the Approach (the
##                 camp at its foot): FIELDS. On each of the first two he can't be worn below
##                 a mark ("floor": 2/3, then 1/3 of his health): reach it and he roars, drawing
##                 on the beacon, and the army falls back with a head start (KING_EARNED). If he
##                 walks off the bottom of a field first, it falls back anyway, with less of a
##                 lead (KING_PUSHED), the damage not done still to do. On the Approach he can
##                 be brought down; if he reaches the camp (CAMP_Y), it's lost.
##   His moves     one more each field: the slam and the charge; then burning ground; then
##                 enraged, with his war horn. And his arts (ARTS, oath_arts.gd): the Line's own,
##                 drawn from the oaths its peoples broke, more of them each field and more often
##   The retreat   worn to a field's mark, he calls up the beacon's fire (BeaconWrath): a wall
##                 of flame rolls down the field from him, burning whoever it catches; the army
##                 runs before it, and once it's swept the field the battle goes on below
##   His strength  his health grows with the army he's up against (ARMY_REF: what it'd cost to
##                 field, the Line's help counted), worked out again on each field
##   The army      everyone who came out of the castle, as they were, and the crews who held
##                 the towers outside the walls; carried from field to field as it stands
##   The Line      help from every people, by what the army did for them (HELP): a point
##                 each for joining, for lighting their beacon, and for their optional
##                 mission; a unit of theirs for every point, trained further the more; each
##                 people waits on its own field (FIELDS' "help")
##   The standard  planted before the army on every field: what his horde goes for. If it
##                 falls, lost
## Taken up again from a field's checkpoint (300 + the field), it's as the army came onto it.

const Works = preload("res://scripts/mission/siege_works.gd")
const Warrior = preload("res://scripts/warrior.gd")
const Data = preload("res://scripts/data.gd")
const CD = preload("res://scripts/campaign_data.gd")
const CP := 300
const MAP := "ds_dawnfield"
const FIELDS := [
	{"map": "ds_dawnfield", "name": "The Fields of Dawn", "floor": 0.66, "help": ["spires", "monastery", "greenwood"]},
	{"map": "ds_bailey", "name": "The Outer Bailey", "floor": 0.33, "help": ["stonehollow", "deepdelve", "frostmarch"]},
	{"map": "ds_approach", "name": "The Approach", "floor": 0.0, "help": ["mercyvale", "freecities"]},
]
const STAND := Vector2(320, 640)      # where the standard's planted (as drawn up)
const CAMP_Y := 600.0                 # on the Approach: him this far down is him at the camp
const KING_AT_WAVE := 2               # on the first field he comes out with this wave
const KING_EARNED := 14.0             # seconds' lead, falling back once he's worn to his mark
const KING_PUSHED := 5.0              # ...and once he's walked off the bottom of a field instead
const FALL_DELAY := 1.5               # his roar before the army falls back
const KING_LEVEL := 13
const KING_HP := 0.7                  # his health, times his data's (against an army of ARMY_REF)
const ARMY_REF := 6000.0              # an army worth this much (gold to field it) meets him at KING_HP; more, and he's that much the stronger
const WRATH_SPEED := 75.0             # how fast the beacon's fire comes down the field
const OathArts = preload("res://scripts/mission/oath_arts.gd")
const Assault = preload("res://scripts/mission/rules_assault.gd")
# His arts, by field: which he has (each the art of one people of the Line), and how often.
const ARTS := [
	{"every": 8.0, "arts": ["greenwood", "deepdelve", "stonehollow"]},
	{"every": 6.5, "arts": ["greenwood", "deepdelve", "stonehollow", "spires", "frostmarch", "monastery"]},
	{"every": 5.0, "arts": ["greenwood", "deepdelve", "stonehollow", "spires", "frostmarch", "monastery", "freecities", "mercyvale"]},
]
const ART_NAMES := {"greenwood": "Oathbreaker's Volley", "deepdelve": "Deep Charges", "stonehollow": "Iron Bolt", "spires": "Grave Rite",
	"frostmarch": "Oath of Winter", "monastery": "Spirit Bomb", "freecities": "Discordant Dirge", "mercyvale": "Stolen Mercy"}
# Each people's help on the field: its kind, and the path it's trained on.
const HELP := {"stonehollow": ["ballista", 0], "greenwood": ["archer", 2], "deepdelve": ["cannon", 0], "mercyvale": ["healer", 0],
	"frostmarch": ["frost", 0], "monastery": ["martial", 0], "freecities": ["bard", 0], "spires": ["mage", 1]}

var standard = null
var king = null
var king_out := false
var king_in := -1.0        # > 0: seconds until he comes onto this field after the army
var king_hp := 1.0         # his health (share) as he comes onto the next field
var field := 0             # which of FIELDS
var fall_t := -1.0         # > 0: his roar, then the army falls back
var fall_earned := false
var wrath = null           # the beacon's fire sweeping the field (oath_arts.gd BeaconWrath)
var art_t := 4.0           # seconds to his next art
var last_art := ""
var mercy_t := -1.0        # > 0: he's drawing Stolen Mercy (hit hard enough, it's broken off)
var mercy_hp := 0.0
var seen_arts := {}        # those he's used (each named the first time)
var over := false
var garrisons: Array = []
var freed := 0
var joined := 0
var escaped := 0
var cp_xp := {}
var cp_name := ""
var wave0 := 0


func has_castle() -> bool:
	return false


func show_camp() -> bool:
	return true


func endless() -> bool:
	return false


func guards() -> bool:
	return true


func objective_only() -> bool:
	return true


func objectives() -> Array:
	return [standard] if standard != null and is_instance_valid(standard) and not standard.dead else NONE


## His horde goes for the standard; he goes on down the field (on the Approach, for the camp).
func enemy_goal(e):
	if e == king and field < FIELDS.size() - 1:
		return null
	return standard if standard != null and is_instance_valid(standard) and standard.is_target() else null


func on_reached_bottom(e) -> bool:
	if e == king:
		_king_through()
	return true


func wave_cleared(_n: int) -> bool:
	return false


## The last battle: its music all the way through, until it's won.
func battle_on() -> bool:
	return not over


func holds_waves() -> bool:
	return over


func last_field() -> bool:
	return field >= FIELDS.size() - 1


## From the castle: the army as it came out (each [record, when]), the standard's health.
func take_over(c, coming: Array, std_hp: float) -> void:
	garrisons = c.garrisons.duplicate(true)
	freed = c.freed
	joined = c.joined
	escaped = c.escaped
	cp_xp = c.cp_xp.duplicate()
	field = 0
	var army: Array = coming.map(func(r): return r[0])
	_set_field(army, std_hp, false)
	checkpoint()
	_story_then_fight()


## Taken up again from its checkpoint.
func resume(cp: Dictionary) -> void:
	for w in main.warrior_layer.get_children():
		w.queue_free()
	main.temp_allies.clear()
	main.gold = int(cp.get("gold", main.gold))
	main.wave = int(cp.get("wave", 0))
	for key in cp.get("owned", []):
		main.powers.owned[key] = true
	main.battle_xp = (cp.get("xp", {}) as Dictionary).duplicate()
	cp_xp = main.battle_xp.duplicate()
	freed = int(cp.get("freed", 0))
	joined = int(cp.get("joined", 0))
	escaped = int(cp.get("escaped", 0))
	garrisons = (cp.get("garrisons", []) as Array).duplicate(true)
	field = clampi(int(cp.get("field", 0)), 0, FIELDS.size() - 1)
	king_hp = float(cp.get("king", 1.0))
	_set_field(cp.get("army", []), float(cp.get("standard", 1.0)), true, not cp.has("field"))
	wave0 = main.wave
	if field == 0:
		_escaped_out()
	else:
		king_in = KING_EARNED
	main.hud.show_message("Taken up again on %s." % FIELDS[field]["name"])


## Field `field`: the army (its shape kept, drawn up before the standard), the crews from
## the towers (first field), the Line's help waiting there, the standard.
## `help_again`: a checkpoint from before the help was kept with the army (send it again).
func _set_field(army: Array, std_hp: float, restored: bool, help_again := false) -> void:
	var f: Dictionary = FIELDS[field]
	change_field(f["map"])
	if standard != null and is_instance_valid(standard):
		standard.queue_free()
	standard = Works.new()
	standard.setup(main, {"id": "standard", "kind": "standard", "name": "The Line's standard", "at": STAND,
			"hp": float(mission.get("assault", {}).get("castle", {}).get("standard", 900.0))})
	standard.hp = standard.max_hp * clampf(std_hp, 0.05, 1.0)
	main.add_objective(standard)
	standard.destroyed.connect(func(_o): _end(false))
	main.paths.set_objectives(objectives())
	var c_old := Vector2.ZERO
	for rec in army:
		c_old += rec.get("post", Vector2(320, 600))
	c_old /= maxf(army.size(), 1)
	for rec in army:
		var r: Dictionary = (rec as Dictionary).duplicate()
		var p: Vector2 = r.get("post", c_old)
		if not restored:
			r["post"] = Vector2(320 + (p.x - c_old.x) * 0.9, 540 + (p.y - c_old.y) * 0.6)
		_make_unit(r)
	cp_name = f["name"]
	if restored:
		if help_again:
			_send_line_help(0)
		main.warriors_changed()
		return
	if field == 0:
		# The crews who held the towers outside the walls come back into the fight.
		var n := 0
		for g in garrisons:
			var crew: Dictionary = (g.get("crew", {}) as Dictionary).duplicate()
			if crew.is_empty():
				continue
			crew["post"] = Vector2(120 + (n % 6) * 80, 600 - (n / 6) * 40)
			_make_unit(crew)
			n += 1
		if n > 0:
			main.hud.show_message("The crews who held the towers outside come back to fight beside you.")
		garrisons.clear()
	_send_line_help(field)
	main.warriors_changed()


## The help of the peoples waiting on field `fi`: a unit for every point (joined; its
## beacon lit; its optional mission won), trained a tier further for each; on loan for this
## battle (it goes on with the army from field to field).
func _send_line_help(fi: int) -> void:
	var row := 0
	var who := []
	for f in FIELDS[fi]["help"]:
		var pts := help_points(f)
		if pts <= 0:
			continue
		who.append(CD.FACTIONS[f]["name"])
		var kind: String = HELP[f][0]
		var tiers := [0, 0, 0, 0]
		tiers[int(HELP[f][1])] = clampi(pts + 1, 1, 4)
		for i in pts:
			var x := 60.0 + fmod(row * 46.0, 520.0)
			var y := 700.0 - float(row / 12) * 36.0 - (40.0 if Data.WARRIORS[kind].get("emplacement", false) else 0.0)
			main._lend_unit({"kind": kind, "at": Vector2(x, y), "tiers": tiers})
			row += 1
	if fi > 0 and not who.is_empty():
		main.hud.show_message("%s: dug in here, waiting for you." % ", ".join(who))


## What the army did for people `f`: joined, beacon lit, optional mission won (0 to 3).
static func help_points(f: String) -> int:
	var pts := 0
	if Campaign.allied(f):
		pts += 1
	var t := ""
	for id in CD.TERRITORIES:
		if CD.TERRITORIES[id].get("faction", "") == f:
			t = id
	if t != "" and Campaign.beacon_lit(t):
		pts += 1
	if t != "":
		for m in CD.TERRITORIES[t].get("optional", []):
			if Campaign.completed.has(m):
				pts += 1
				break
	return pts


## The field's story (the game holding still), then the battle: his that got out of the
## castle are on the field already.
func _story_then_fight() -> void:
	var then := func():
		_escaped_out()
		wave0 = main.wave
	var lines: Array = Campaign.story_lines("ds_field") if main.campaign else []
	if lines.is_empty():
		then.call()
		return
	main.get_tree().paused = true
	main.hud.play_story(lines, func():
		main.get_tree().paused = false
		then.call())


func _escaped_out() -> void:
	if escaped <= 0:
		return
	var kinds := ["orc", "skeleton_archer", "troll", "orc", "wolf", "warlord"]
	for i in escaped:
		main._spawn_enemy(kinds[i % kinds.size()], main.wave_level(maxi(main.wave, 1)))
	main.hud.show_message("%d of his got out of the castle ahead of you: they're here." % escaped)


func process(delta: float) -> void:
	if over or main.game_over:
		return
	if fall_t > 0.0:
		fall_t -= delta
		if fall_t <= 0.0:
			_fall_back(fall_earned)
		return
	if wrath != null:
		if king != null and is_instance_valid(king):
			king.boss_hold = 1.0   # (he stands in the fire he's called up)
		if wrath.swept:
			_fall_back(true)
		return
	if not king_out:
		if field == 0 and king_in < 0.0:
			if main.wave - wave0 >= KING_AT_WAVE:
				_king_comes()
		else:
			king_in -= delta
			if king_in <= 0.0:
				_king_comes()
		return
	if last_field() and king != null and is_instance_valid(king) and not king.dead and king.position.y >= CAMP_Y:
		main.hud.show_message("The Ogre King has reached the camp!")
		_end(false)
		return
	if king != null and is_instance_valid(king) and not king.dead:
		_arts_step(delta)


## He comes onto the field after the army: from the gate (or the way the army's come), his
## health as it was, his mark on this field, and one more of his moves each field.
func _king_comes() -> void:
	king_out = true
	main._spawn_enemy("ogre_unbound", KING_LEVEL, Vector2(main.FIELD_W / 2.0, 60.0))
	king = main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)
	king.max_hp *= KING_HP * army_mult()
	king.hp = king.max_hp * clampf(king_hp, 0.02, 1.0)
	art_t = 4.0
	mercy_t = -1.0
	king.hp_floor = king.max_hp * float(FIELDS[field]["floor"])
	king.goal = enemy_goal(king)
	king.died.connect(_slain)
	match field:
		0:
			king.embers_timer = INF   # (the slam and the charge only)
			king.horn = {}
			king.enrage_at = 0.0
		1:
			king.embers_timer = 4.0   # (and his burning ground)
			king.horn = {}
			king.enrage_at = 0.0
		_:
			king.enrage_at = 2.0      # (enraged from the start here, his war horn too)
	if field == 0:
		main.hud.show_message("The Ogre King comes out of the Dawn Gate, the beacon's fire all round him!")
	else:
		main.hud.show_message("The Ogre King comes on after you!")
	main.sfx("horn", 0.6)


## He's been worn down to this field's mark: he roars, drawing on the beacon, and the
## army falls back with a lead on him.
func floor_reached(e) -> void:
	if e != king or over or fall_t > 0.0:
		return
	if wrath != null:
		return
	# The beacon's fire: a wall of flame from him, rolling down the field. The army runs
	# before it; once it's swept the field, the battle goes on below.
	mercy_t = -1.0
	wrath = OathArts.BeaconWrath.new()
	wrath.main = main
	wrath.front = e.position.y
	wrath.speed = WRATH_SPEED
	wrath.bottom = main.CASTLE_Y - 40.0
	main.corpse_layer.add_child(wrath)
	e.boss_hold = 1.0
	main.spawn_burst(e.position, 140.0, Color(1.0, 0.3, 0.1))
	main.spawn_flash(e.position, 110.0)
	main.spawn_text(e.position + Vector2(0, -80), "THE BEACON'S WRATH!", Color(1.0, 0.4, 0.2))
	main.sfx("boom", 0.6)
	main.hud.show_message("He calls up the beacon's fire! Fall back to %s, ahead of the flames!" % FIELDS[field + 1]["name"])


## He's walked off the bottom of the field, through the army: it falls back after him.
func _king_through() -> void:
	if over or fall_t > 0.0:
		return
	if last_field():
		main.hud.show_message("The Ogre King has reached the camp!")
		_end(false)
		return
	king_hp = king.hp / king.max_hp if king != null and is_instance_valid(king) else king_hp
	king = null
	fall_earned = false
	fall_t = 0.01
	main.hud.show_message("He's broken through! Fall back to %s!" % FIELDS[field + 1]["name"])


## Onto the next field: the army as it stands (on loan or not; the fallen carried), the
## standard with it; his horde on this field left behind; he follows after his lead.
func _fall_back(earned: bool) -> void:
	if over or last_field():
		return
	if king != null and is_instance_valid(king):
		king_hp = king.hp / king.max_hp
	king = null
	king_out = false
	king_in = KING_EARNED if earned else KING_PUSHED
	wrath = null
	var army := []
	for w in main.warrior_layer.get_children():
		if w.is_queued_for_deletion() or w.summoned or w.clone_of != null:
			continue
		army.append(_unit_record(w))
		w.queue_free()
	main.temp_allies.clear()
	var std: float = standard.hp / standard.max_hp if standard != null and is_instance_valid(standard) else 1.0
	field += 1
	_set_field(army, std, false)
	checkpoint()


## How much stronger he is for the army he's up against: what it'd cost to field (every
## troop and emplacement and their training, the Line's help counted), against ARMY_REF.
func army_mult() -> float:
	var worth := 0.0
	for w in main.get_warriors():
		if w.is_queued_for_deletion() or w.summoned or w.clone_of != null:
			continue
		var d: Dictionary = Data.WARRIORS[w.kind]
		worth += float(d["cost"])
		for p in mini(d.get("paths", []).size(), 4):
			for t in int(w.tiers[p]):
				worth += float(d["paths"][p]["tiers"][t]["cost"])
	return maxf(1.0, worth / ARMY_REF)


## His arts: one every so often (more often each field), never the same twice running.
func _arts_step(delta: float) -> void:
	if mercy_t > 0.0:
		# Drawing Stolen Mercy: hurt hard enough while he does, and it's broken off.
		king.boss_hold = 0.2
		if mercy_hp - king.hp >= king.max_hp * 0.04:
			mercy_t = -1.0
			main.spawn_text(king.position + Vector2(0, -80), "Broken off!", Color(1.0, 0.9, 0.5))
			return
		mercy_t -= delta
		if mercy_t <= 0.0:
			_mercy_lands()
		return
	if king.stomp_wind > 0.0 or king.charge_warn > 0.0 or king.charging > 0.0:
		return
	art_t -= delta
	if art_t > 0.0:
		return
	var pack: Dictionary = ARTS[field]
	art_t = float(pack["every"])
	var pick: Array = (pack["arts"] as Array).filter(func(a): return a != last_art)
	var art: String = pick.pick_random()
	last_art = art
	use_art(art)


## The troops he can see to use his arts on (not those up a tower), farthest first.
func _marks() -> Array:
	var out: Array = main.get_warriors().filter(func(w): return w.is_active() and not w.sheltered() and not w.is_emplacement())
	out.sort_custom(func(a, b): return a.position.distance_to(king.position) > b.position.distance_to(king.position))
	return out


## The middle of the thickest knot of troops (or the troop nearest it).
func _knot():
	var best = null
	var most := 0
	for w in _marks():
		var n: int = main.warriors_near(w.position, 70.0).filter(func(o): return o.is_active()).size()
		if n > most:
			most = n
			best = w.position
	return best


## Art `art` (a people of the Line's), now.
func use_art(art: String) -> void:
	var at: Vector2 = king.position
	var title: String = ART_NAMES[art]
	main.spawn_text(at + Vector2(0, -90), title + "!", Color(1.0, 0.55, 0.25))
	if not seen_arts.has(art):
		seen_arts[art] = true
		main.hud.show_message("%s: he turns %s's own art on you!" % [title, CD.FACTIONS[art]["name"]])
	var lvl: float = 1.0 + 0.25 * field
	match art:
		"greenwood":
			# Fire arrows that follow their troops, burning through any on the way.
			for w in _marks().slice(0, 4 + field):
				var a := OathArts.OathArrow.new()
				a.main = main
				a.target = w
				a.position = at + Vector2(0, -king.radius)
				a.damage = 38.0 * lvl
				main.add_projectile(a)
			main.sfx("bow", 0.7)
		"deepdelve":
			# Mortar shells on where the army stands thickest (rings first).
			var spots := []
			var k = _knot()
			if k != null:
				spots.append(k)
			for w in _marks().slice(0, 2 + field):
				spots.append(w.position)
			for p in spots.slice(0, 2 + field):
				var v := Assault.Volley.new()
				v.main = main
				v.position = p + Vector2(randf_range(-15, 15), randf_range(-15, 15))
				v.radius = 60.0
				v.hits = 1
				v.damage = 70.0 * lvl
				v.color = Color(1.0, 0.6, 0.2)
				v.fire = true
				v.warn = 1.8
				main.add_projectile(v)
			main.sfx("cannon", 0.7)
		"stonehollow":
			# A ballista bolt's line, through the thickest of them, then the bolt.
			var k = _knot()
			if k == null:
				return
			var dir: Vector2 = at.direction_to(k)
			var l := OathArts.OathLance.new()
			l.main = main
			l.from = at
			l.to = at + dir * 900.0
			l.damage = 75.0 * lvl
			main.corpse_layer.add_child(l)
			main.sfx("lance", 0.6)
		"spires":
			# Necromancy: the dead rise round him.
			for i in 3 + field:
				main.spawn_minion("skeleton_archer", main.wave_level(maxi(main.wave, 1)), at + Vector2.from_angle(PI * 0.15 + i * 0.6) * (king.radius + 30.0))
			main.spawn_burst(at, 90.0, Color(0.55, 0.9, 0.55))
			main.sfx("rise", 0.8)
		"frostmarch":
			# A ring of frost under the thickest of them: frozen, whoever's still in it.
			var k = _knot()
			if k == null:
				return
			var r := OathArts.WinterRing.new()
			r.main = main
			r.position = k
			r.radius = 70.0 + 10.0 * field
			r.damage = 30.0 * lvl
			main.corpse_layer.add_child(r)
			main.sfx("frost", 0.7)
		"monastery":
			# A Spirit Bomb, gathered and thrown at the far end of the army.
			var m: Array = _marks()
			if m.is_empty():
				return
			var v := Assault.Volley.new()
			v.main = main
			v.position = m[0].position
			v.radius = 85.0
			v.hits = 1
			v.damage = 110.0 * lvl
			v.color = Color(1.0, 0.9, 0.4)
			v.fire = true
			v.warn = 2.2
			main.add_projectile(v)
			main.sfx("ki", 0.6)
		"freecities":
			# A dirge: the army round him weakened and slowed; his horde driven on.
			for w in main.warriors_near(at, 220.0):
				if w.is_active():
					w.hex_for({"damage": 0.3, "rate": 0.25, "speed": 0.2}, 6.0)
			for e in main.enemies_near(at, 220.0):
				if not e.dead and e != king:
					e.rally = 6.0
					e.rally_dmg = 0.3
					e.rally_speed = 0.25
			main.spawn_burst(at, 220.0, Color(0.7, 0.4, 0.9))
			main.sfx("violin", 0.6)
		"mercyvale":
			# Stolen Mercy: he draws it for a moment (break it off by hitting him hard), then
			# it mends his horde round him, and him a little.
			mercy_t = 2.0
			mercy_hp = king.hp
			main.spawn_burst(at, 60.0, Color(0.5, 1.0, 0.6))
			main.sfx("heal", 0.6)


## Stolen Mercy, drawn: his horde round him healed, and him a little.
func _mercy_lands() -> void:
	mercy_t = -1.0
	var at: Vector2 = king.position
	for e in main.enemies_near(at, 220.0):
		if not e.dead and e != king:
			e.hp = minf(e.max_hp, e.hp + e.max_hp * 0.4)
	king.hp = minf(king.max_hp, king.hp + king.max_hp * 0.04)
	main.spawn_burst(at, 220.0, Color(0.5, 1.0, 0.6))
	main.spawn_text(at + Vector2(0, -80), "Healed!", Color(0.5, 1.0, 0.6))


## Brought down (on the Approach): the horde breaks.
func _slain(_e) -> void:
	if over:
		return
	for e in main.get_enemies():
		if not e.dead:
			e.take_damage(1e9, false)
	Campaign.flags["ds_united"] = true
	_end(true)


func checkpoint() -> void:
	if not main.campaign:
		return
	cp_xp = main.battle_xp.duplicate()
	var army := []
	for w in main.warrior_layer.get_children():
		if w.is_queued_for_deletion() or w.summoned or w.clone_of != null:
			continue
		army.append(_unit_record(w))
	Campaign.set_checkpoint(Campaign.mission_id, CP + field, {"zone": CP + field, "field": field, "name": FIELDS[field]["name"],
			"gold": main.gold, "wave": main.wave, "army": army, "xp": cp_xp, "owned": main.powers.owned.keys(),
			"standard": standard.hp / standard.max_hp, "king": king_hp,
			"freed": freed, "joined": joined, "escaped": escaped, "garrisons": garrisons.duplicate(true)})


func xp_gains(won: bool, gains: Dictionary) -> Dictionary:
	if won or cp_xp.is_empty():
		return gains
	var out := {}
	for kind in gains:
		out[kind] = maxf(0.0, float(gains[kind]) - float(cp_xp.get(kind, 0.0)))
	return out


func checkpoint_name() -> String:
	return cp_name


func _end(won: bool) -> void:
	if over:
		return
	over = true
	main.hud.show_message("The Ogre King has fallen! The Line holds!" if won else "The army breaks!")
	main.call_deferred("_finish", won)


func status() -> String:
	var text := "%s (%d of %d)" % [FIELDS[field]["name"], field + 1, FIELDS.size()]
	if standard != null and is_instance_valid(standard):
		text += "  ·  Standard %d%%" % roundi(standard.hp / standard.max_hp * 100.0)
	if king != null and is_instance_valid(king) and not king.dead:
		text += "  ·  The Ogre King %d%%" % roundi(king.hp / king.max_hp * 100.0)
		if not last_field():
			text += " (fall back at %d%%)" % roundi(float(FIELDS[field]["floor"]) * 100.0)
	elif not king_out and field == 0 and king_in < 0.0:
		text += "  ·  he comes out with wave %d" % (wave0 + KING_AT_WAVE)
	elif not king_out and king_in > 0.0:
		text += "  ·  he's coming: %ds" % ceili(king_in)
	return text


func panel_status() -> String:
	return "Standard %d%%" % roundi(standard.hp / standard.max_hp * 100.0) if standard != null and is_instance_valid(standard) else ""


func wave_text() -> String:
	return "Wave %d" % maxi(main.wave - wave0, 0)


func summary(won: bool) -> String:
	var s := "Freed %d of Dawnspire's people and %d soldiers." % [freed, joined]
	if won:
		s += "  Every people of the Line stood on the Fields of Dawn."
	return s
