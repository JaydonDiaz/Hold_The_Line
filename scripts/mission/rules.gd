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


## An objective was destroyed (rules with objectives decide whether that loses).
func on_objective_lost(_o) -> void:
	pass


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
