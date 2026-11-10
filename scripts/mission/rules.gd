extends RefCounted
## A battle's rules: what winning and losing mean, where enemies are headed, and what the
## HUD says about it. main.gd asks these at the points where a battle can turn (a wave
## cleared, an enemy reaching the bottom line, an objective lost) instead of deciding
## itself. A mission picks its rules with "type" (see make()); everything it leaves out
## keeps today's behavior.
##
## This base class is castle defense, the game as it always was: enemies head for the
## castle at the bottom of the field, the castle falling loses (main.damage_castle), and a
## mission is won by clearing its last wave. Classic (no mission) goes on to wave 20 and
## the endless offer, all handled in main.gd as before.

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


## Called once the battlefield is set up (the castle placed, the mission's allies out).
func start() -> void:
	pass


## Where enemy `e` is headed: an objective (objective.gd), or null for the castle (or,
## without one, the bottom line).
func enemy_goal(_e):
	return null


## Enemy `e` got to the bottom line. With a castle it lays siege as always (return false);
## rules without one take it off the field and count it (return true).
func on_reached_bottom(_e) -> bool:
	return false


## Wave `n` has been cleared: whether that wins the battle. A mission is won by clearing
## its last wave; Classic carries on (main.gd offers endless at wave 20).
func wave_cleared(n: int) -> bool:
	return main.scripted() and n >= main.last_wave()


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


## The objectives on the field (objective.gd nodes).
func objectives() -> Array:
	return NONE


const NONE: Array = []   # (asked every frame by every troop: no new array each time)
