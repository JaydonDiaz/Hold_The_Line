extends "res://scripts/mission/rules.gd"
## The Liberation of Dawnspire's last battle (Phase 5, F5: the nine-beacon route only): the
## Fields of Dawn, below the citadel's walls. The army has got out of the castle; the Line's
## whole host has come up behind it; the Ogre King comes out after it with his true power,
## his horde, and whatever of his got out of the castle ahead of the army.
##
##   The army      everyone who came out of the castle, as they were, and the crews who held
##                 the towers outside the walls (come back into the fight here)
##   The Line      help from every people, by what the army did for them (HELP): a point
##                 each for joining, for lighting their beacon, and for their optional
##                 mission; a unit of theirs for every point, trained further the more
##   The enemy     waves at the field's pace; those of his that escaped the castle are out
##                 already; the Ogre King, Unbound (data.gd ogre_unbound) comes out of the
##                 Dawn Gate with the second wave. Bring him down and the horde breaks: won
##   The standard  planted before the Line's camp: what the enemy's after. If it falls, lost
## Taken up again from its checkpoint (300), it's as the army came out onto the field.

const Works = preload("res://scripts/mission/siege_works.gd")
const Warrior = preload("res://scripts/warrior.gd")
const Data = preload("res://scripts/data.gd")
const CD = preload("res://scripts/campaign_data.gd")
const CP := 300
const MAP := "ds_dawnfield"
const STAND := Vector2(320, 640)      # where the standard's planted (as drawn up)
const KING_AT_WAVE := 2               # he comes out with this wave
const KING_LEVEL := 13
const KING_HP := 0.55                 # his health, times his data's
# Each people's help on the field: its kind, and the path it's trained on.
const HELP := {"stonehollow": ["ballista", 0], "greenwood": ["archer", 2], "deepdelve": ["cannon", 0], "mercyvale": ["healer", 0],
	"frostmarch": ["frost", 0], "monastery": ["martial", 0], "freecities": ["bard", 0], "spires": ["mage", 1]}

var standard = null
var king = null
var king_out := false
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


func enemy_goal(_e):
	return standard if standard != null and is_instance_valid(standard) and standard.is_target() else null


func on_reached_bottom(_e) -> bool:
	return true


func wave_cleared(_n: int) -> bool:
	return false


## The last battle: its music all the way through, until it's won.
func battle_on() -> bool:
	return not over


func holds_waves() -> bool:
	return over


## From the castle: the army as it came out (each [record, when]), the standard's health.
func take_over(c, coming: Array, std_hp: float) -> void:
	garrisons = c.garrisons.duplicate(true)
	freed = c.freed
	joined = c.joined
	escaped = c.escaped
	cp_xp = c.cp_xp.duplicate()
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
	_set_field(cp.get("army", []), float(cp.get("standard", 1.0)), true)
	_escaped_out()
	wave0 = main.wave
	main.hud.show_message("Taken up again on the Fields of Dawn.")


## The field: the army (its shape kept, drawn up before the camp), the crews from the
## towers, the Line's help, the standard; and his that got out of the castle, waiting.
func _set_field(army: Array, std_hp: float, restored: bool) -> void:
	change_field(MAP)
	var k: float = main.FIELD_W / 640.0
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
	if restored:
		_send_line_help()   # (on loan for the battle: here again, as they were)
		main.warriors_changed()
		cp_name = "The Fields of Dawn"
		return
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
	# The Line's help.
	_send_line_help()
	main.warriors_changed()
	cp_name = "The Fields of Dawn"


## Each people's help: a unit for every point (joined; its beacon lit; its optional mission
## won), trained a tier further for each; on loan for this battle.
func _send_line_help() -> void:
	var row := 0
	for f in HELP:
		var pts := help_points(f)
		if pts <= 0:
			continue
		var kind: String = HELP[f][0]
		var tiers := [0, 0, 0, 0]
		tiers[int(HELP[f][1])] = clampi(pts + 1, 1, 4)
		for i in pts:
			var x := 60.0 + fmod(row * 46.0, 520.0)
			var y := 700.0 - float(row / 12) * 36.0 - (40.0 if Data.WARRIORS[kind].get("emplacement", false) else 0.0)
			main._lend_unit({"kind": kind, "at": Vector2(x, y), "tiers": tiers})
			row += 1


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


func process(_delta: float) -> void:
	if over or main.game_over:
		return
	if not king_out and main.wave - wave0 >= KING_AT_WAVE:
		king_out = true
		main._spawn_enemy("ogre_unbound", KING_LEVEL, Vector2(main.FIELD_W / 2.0, 60.0))
		king = main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)
		king.max_hp *= KING_HP
		king.hp = king.max_hp
		king.goal = standard
		main.hud.show_message("The Ogre King comes out of the Dawn Gate, the beacon's fire all round him!")
		main.sfx("horn", 0.6)
	if king_out and (king == null or not is_instance_valid(king) or king.dead):
		# He's down: the horde breaks.
		for e in main.get_enemies():
			if not e.dead:
				e.take_damage(1e9, false)
		Campaign.flags["ds_united"] = true
		_end(true)


func checkpoint() -> void:
	if not main.campaign:
		return
	cp_xp = main.battle_xp.duplicate()
	var k: float = main.FIELD_W / 640.0
	var army := []
	for w in main.warrior_layer.get_children():
		if w.is_queued_for_deletion() or w.summoned or w.clone_of != null or main.temp_allies.has(w):
			continue
		army.append(_unit_record(w))
	Campaign.set_checkpoint(Campaign.mission_id, CP, {"zone": CP, "name": "The Fields of Dawn", "gold": main.gold, "wave": main.wave,
			"army": army, "xp": cp_xp, "owned": main.powers.owned.keys(), "standard": standard.hp / standard.max_hp,
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
	main.hud.show_message("The Ogre King has fallen! The Line holds!" if won else "The standard's fallen: the army breaks!")
	main.call_deferred("_finish", won)


func status() -> String:
	var text := "The Fields of Dawn"
	if standard != null and is_instance_valid(standard):
		text += "  ·  Standard %d%%" % roundi(standard.hp / standard.max_hp * 100.0)
	if king != null and is_instance_valid(king) and not king.dead:
		text += "  ·  The Ogre King %d%%" % roundi(king.hp / king.max_hp * 100.0)
	elif not king_out:
		text += "  ·  he comes out with wave %d" % (wave0 + KING_AT_WAVE)
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
