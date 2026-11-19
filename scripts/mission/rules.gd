extends RefCounted
## A battle's rules: what winning and losing mean, where enemies are headed, and what the
## HUD says about it. main.gd asks these at the points where a battle can turn (a wave
## cleared, an enemy reaching the bottom line, an objective lost) instead of deciding
## itself. A mission picks its rules with "type" (see make()); everything it leaves out
## keeps today's behavior.
##
## This base class is castle defense, the game as it always was: enemies head for the
## castle at the bottom of the field, the castle falling loses (main.damage_castle), and a
## mission is won by clearing its last wave. Classic (no mission) goes on until the castle
## falls (past wave 20 the enemy toughens faster), all handled in main.gd.
##
## Battle Modes scenarios are "endless": true. There's no last wave: the battle goes on
## until it's lost, and the score is the waves survived. Each kind of battle keeps its
## objective going round (a beacon lit again, more villagers on the road, the convoy on to
## the next stretch...).

var main
var mission: Dictionary


## The rules for a mission (Classic and the rest: an empty mission, castle defense).
static func make(m: Dictionary) -> RefCounted:
	var script: GDScript
	match m.get("type", "castle"):
		"pass":
			script = load("res://scripts/mission/rules_pass.gd")
		"positions":
			script = load("res://scripts/mission/rules_positions.gd")
		"protect":
			script = load("res://scripts/mission/rules_protect.gd")
		"evac":
			script = load("res://scripts/mission/rules_evac.gd")
		"capture":
			script = load("res://scripts/mission/rules_capture.gd")
		"escort":
			script = load("res://scripts/mission/rules_escort.gd")
		"retreat":
			script = load("res://scripts/mission/rules_retreat.gd")
		"assault":
			script = load("res://scripts/mission/rules_assault.gd")
		_:
			script = load("res://scripts/mission/rules.gd")
	return script.new()


func setup(m, mis: Dictionary) -> void:
	main = m
	mission = mis


## Whether the battle has a castle at the bottom (to defend, upgrade and repair). Without
## one, the bottom of the field is open ground with a work camp, and an enemy that gets
## there is dealt with by on_reached_bottom.
func has_castle() -> bool:
	return true


## Without a castle: whether the work camp stands at the bottom of the field (an escort
## carries its camp with the wagon instead).
func show_camp() -> bool:
	return true


## Called once the battlefield is set up (the castle placed, the mission's allies out).
func start() -> void:
	pass


## Where enemy `e` is headed: an objective (objective.gd), or null for the castle (or,
## without one, the bottom line).
func enemy_goal(_e):
	return null


## Whether every enemy is out for the objectives: one without any (none standing yet, or
## its own gone) asks again every second rather than heading for the bottom line, and
## one after something that moves looks again for the nearest. (Not with a castle to
## besiege, nor where getting past is the point.)
func objective_only() -> bool:
	return false


## Whether there's something on the field for your troops to protect: troops get the
## Objective target priority (and start on it).
func guards() -> bool:
	return false


## How far down the field an enemy with nothing to go for comes before it waits (INF: all
## the way, as ever).
func wait_y() -> float:
	return INF


## Enemy `e` got to the bottom line. With a castle it lays siege as always (return false);
## rules without one take it off the field and count it (return true).
func on_reached_bottom(_e) -> bool:
	return false


## Wave `n` has been cleared: whether that wins the battle. A mission is won by clearing
## its last wave; Classic carries on (main.gd offers endless at wave 20).
func wave_cleared(n: int) -> bool:
	return main.scripted() and not endless() and n >= main.last_wave()


## Whether the battle goes on until it's lost (a Battle Modes scenario).
func endless() -> bool:
	return mission.get("endless", false)


## Where a wave's next enemy (of radius r) comes onto the field, if not by the field's
## lanes as usual: Vector2.INF for the lanes.
func spawn_point(_r: float) -> Vector2:
	return Vector2.INF


## Whether the battle has side objectives troops can be sent after (the Side Objectives
## target priority: see warrior.gd SIDE_PRIORITY).
func side_objectives() -> bool:
	return false


## Whether this field's waves are over (an assault's gate open: the HUD says so).
func waves_done_here() -> bool:
	return false


## Whether no new wave may start now (an assault clearing a field before it moves on).
func holds_waves() -> bool:
	return false


## The XP a finished battle banks (an operation taken up from a checkpoint banks what came
## before it only once: see rules_assault.gd).
func xp_gains(_won: bool, gains: Dictionary) -> Dictionary:
	return gains


## The stage a lost battle can be taken up again from ("" for none: it's played again
## from the start).
func checkpoint_name() -> String:
	return ""


## An objective was destroyed (rules with objectives decide whether that loses).
func on_objective_lost(_o) -> void:
	pass


# --- A flawless win (the campaign's bonus training: see main._finish) -----------------------
# Perfect play by the battle's own measure: the castle never hit (a repair doesn't undo a
# hit), nobody through the line, no objective fallen (the one you're guarding in Protect
# or Escort never even hit), no villager lost, no ground given back. The first thing that
# spoils it is kept, to say on the end screen.
var flaw := ""


func spoil(why: String) -> void:
	if flaw == "":
		flaw = why


func flawless() -> bool:
	return flaw == ""


## An objective was hit (objective.gd): in Protect and Escort, the one thing you're
## guarding, so that's the end of a flawless win.
func on_objective_hit(o) -> void:
	if mission.get("type", "") in ["protect", "escort"] and o.kind != "civilian":
		spoil("The %s was hit" % o.label.to_lower())


func process(_delta: float) -> void:
	pass


## A line for the top of the field about how the battle stands ("" for none).
func status() -> String:
	return ""


## What the panel shows where the castle's health would be, for rules without a castle.
func panel_status() -> String:
	return ""


## How well a won battle went, for Battle Modes records (higher is better).
func score() -> int:
	return main.wave


func score_text(s: int) -> String:
	return "%d waves" % s


## A line for the end screen about how it went ("" for none).
func summary(_won: bool) -> String:
	return ""


## Where new troops come onto the field (and Engineers set out from): Vector2.INF for the
## usual way (the side nearer the post, or the castle gate).
func entry_point(_post: Vector2) -> Vector2:
	return Vector2.INF


## The HUD's wave counter ("Wave 3/5" by default).
func wave_text() -> String:
	return "Wave %d" % main.wave if main.survival() or endless() else "Wave %d/%d" % [main.wave, main.last_wave()]


## A battle-specific order the player can give (a button over the field, key Y): its
## label, "" for none.
func action_label() -> String:
	return ""


func action() -> void:
	pass


## The objectives troops can be told to follow (a wagon, a column of civilians).
func followable() -> Array:
	return objectives().filter(func(o): return o.is_mover() and o.is_target())


## The battle moves on to new ground (a convoy's next stretch of road, a retreat's next
## field): the enemy on the field (and anything in flight, and the fallen) are left
## behind, and the field turns into map `map_id`. Engineers at work come along; the
## rules move everything else of yours.
func change_field(map_id: String) -> void:
	for e in main.enemy_layer.get_children():
		e.dead = true
		e.queue_free()
	main.spawn_queue.clear()
	main.enemies_changed()
	for n in main.fx_layer.get_children():
		if not n.has_method("gate"):   # (Engineers come along)
			n.queue_free()
	for g in main.get_graves():
		g.queue_free()
	for c in main.corpse_layer.get_children():
		c.queue_free()
	var maps = load("res://scripts/maps.gd")
	main.map_id = map_id
	main.paths.set_map(maps.get_map(map_id))
	main._repaint_ground()
	main.queue_redraw()
	var m: Dictionary = maps.get_map(map_id)
	main.stage_music = m.get("music", "mountain" if m.get("biome", "") == "mountain" else "calm")
	main.set_battle_music(m)


## The objectives on the field (objective.gd nodes).
func objectives() -> Array:
	return NONE


const NONE: Array = []   # (asked every frame by every troop: no new array each time)


# --- Operations carried over fields (the assault, the castle) --------------------------------

## What a unit is, to put it back later: its kind, training, health, post and orders.
func _unit_record(w) -> Dictionary:
	var k: float = main.FIELD_W / 640.0
	return {"kind": w.kind, "tiers": (w.tiers as Array).duplicate(), "hp": w.hp / maxf(w.max_hp, 1.0),
			"post": Vector2(w.post.x / k, w.post.y), "spent": w.spent, "lent": main.temp_allies.has(w),
			"freed": w.has_meta("freed"), "priority": w.priority, "move_mode": w.move_mode}


## A unit back from its record (on the field as it's stretched now).
func _make_unit(rec: Dictionary):
	var k: float = main.FIELD_W / 640.0
	var kind: String = rec["kind"]
	if not preload("res://scripts/data.gd").WARRIORS.has(kind):
		return null
	var p: Vector2 = rec.get("post", Vector2(320, 600))
	var w = preload("res://scripts/warrior.gd").new()
	w.setup(kind, preload("res://scripts/data.gd").WARRIORS[kind], main, main.paths.open_spot(main._clamp_post(Vector2(p.x * k, p.y))))
	w.tiers = (rec.get("tiers", [0, 0, 0, 0]) as Array).duplicate()
	w._apply_upgrades()
	w.hp = w.max_hp * clampf(float(rec.get("hp", 1.0)), 0.05, 1.0)
	w.spent = int(rec.get("spent", 0))
	w.priority = str(rec.get("priority", w.priority))
	w.move_mode = str(rec.get("move_mode", w.move_mode))
	w.position = w.post
	main.warrior_layer.add_child(w)
	if rec.get("lent", false):
		main.temp_allies.append(w)
	if rec.get("freed", false):
		w.set_meta("freed", true)
	return w


## A boss that can't simply be killed ("undying": the Ogre King) has been beaten: what
## happens is the battle's to say. Here: it falls like anything else.
func boss_beaten(e) -> void:
	e.remove_meta("undying")
	e.take_damage(1e9, false)


## Anything hostile of the battle's own on the field besides its enemies (the assault's
## archer towers), so the battle's still on while it stands.
func hostiles() -> bool:
	return false


## Whether the battle music plays (or the field's peaceful music): during a wave, as ever.
## A battle can keep it going through the breathers between its waves.
func battle_on() -> bool:
	return main.wave_active


## A click on the field that the battle takes (a way on's arrow, say): true if it did.
func click(_p: Vector2) -> bool:
	return false
