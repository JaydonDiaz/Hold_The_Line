extends SceneTree
## Troops vs walls. Each case puts one unit below a wall and a dummy enemy (can't
## move or fight) above it, then reports when the unit first hurt the enemy, from
## where, and whether it ever stood inside the wall.
## Run: godot --headless --path . --fixed-fps 60 -s tools/troop_wall_test.gd
##   swordsman, archer, mage, frost, ki: have to walk around the wall's end first
##   tower, alchemist: fire over it straight away
##   flashstep: a Martial Artist with Flash Step teleports across a wall with no way around

const Data = preload("res://scripts/data.gd")
const CASES := [
	# [name, unit, upgrades [path, tiers], wall across the whole field?]
	["swordsman", "swordsman", [], false],
	["archer", "archer", [], false],
	["mage", "mage", [], false],
	["frost", "frost", [], false],
	["ki", "martial", [0, 1], false],
	["tower", "tower", [], false],
	["alchemist", "alchemist", [], false],
	["flashstep", "martial", [2, 2], true],
]
const LIMIT := 60 * 25

var main
var frames := 0
var current := -1
var start := 0
var unit
var dummy
var dummy_hp := 0.0
var clipped := false
var done := false


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		main.choose_mode("freeplay")
		_next()
		return false
	if frames < 3:
		return false
	var c: Array = CASES[current]
	if is_instance_valid(unit) and not unit.is_emplacement():
		for b in main.get_barricades():
			if b.gap_from(unit.position) < unit.RADIUS - 3.0:
				clipped = true
	var hurt: bool = not is_instance_valid(dummy) or dummy.hp < dummy_hp
	if hurt or frames - start > LIMIT:
		var sees: bool = is_instance_valid(dummy) and not main.paths.wall_between(unit.position, dummy.position)
		print("  %-10s %s after %.1fs, from %s (%s)%s" % [c[0], "HIT" if hurt else "NO HIT",
				(frames - start) / 60.0, unit.position.round(), "clear line" if sees else "over the wall",
				"  STOOD IN WALL" if clipped else ""])
		if current + 1 >= CASES.size():
			return true
		_next()
	return false


func _next() -> void:
	current += 1
	clipped = false
	main.clear_enemies()
	for w in main.get_warriors():
		w.queue_free()
	for b in main.get_barricades():
		b.queue_free()
	var c: Array = CASES[current]
	main.placing_type = "barricade"
	main.wall_start = null
	if c[3]:
		main.hire_at(Vector2(0, 400))
		main.hire_at(Vector2(320, 400))
		main.placing_type = "barricade"
		main.hire_at(Vector2(320, 400))
		main.hire_at(Vector2(640, 400))
	else:
		main.hire_at(Vector2(140, 400))
		main.hire_at(Vector2(500, 400))
	main.walls_changed()
	main.placing_type = c[1]
	main.hire_at(Vector2(320, 520))
	unit = main.warrior_layer.get_child(main.warrior_layer.get_child_count() - 1)
	unit.position = unit.post
	if not c[2].is_empty():
		for t in c[2][1]:
			main.selected = unit
			main.upgrade_selected(c[2][0])
	main.selected = null
	main._spawn_enemy("orc", 5)
	dummy = main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)
	dummy.position = Vector2(320, 300)
	dummy.speed = 0.0
	dummy.fights = false
	dummy.max_hp = 100000.0
	dummy.hp = dummy.max_hp
	dummy_hp = dummy.hp
	start = frames
