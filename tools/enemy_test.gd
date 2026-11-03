extends SceneTree
## Bats and Sappers. Each case sets up a little field, releases a few enemies and
## reports what happened.
## Run: godot --headless --path . --fixed-fps 60 -s tools/enemy_test.gd
##   bats_melee   bats over a sealed wall, defended by swordsmen and a cannon: nothing should touch them
##   bats_archer  the same with an archer: it should shoot them down
##   sapper_wall  sappers against a sealed wall: they seek it out and blow it apart
##   sapper_troop sappers against a swordsman with no walls: the bomb hurts it, the sapper dies

const Data = preload("res://scripts/data.gd")
const CASES := ["bats_melee", "bats_archer", "sapper_wall", "sapper_troop"]
const LIMIT := 60 * 40

var main
var frames := 0
var current := -1
var start := 0
var enemies := []
var killed := 0
var leaked := 0
var walls := []
var units := []


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
	var live := enemies.filter(func(e): return is_instance_valid(e) and not e.dead and not e.sieging)
	if live.is_empty() or frames - start > LIMIT:
		var exploded := enemies.size() - killed - leaked - live.size()
		var wall_hp := []
		for w in walls:
			wall_hp.append("%d/%d" % [w.hp, w.max_hp] if is_instance_valid(w) else "destroyed")
		var unit_hp := []
		for u in units:
			unit_hp.append("%s %d/%d" % [u.kind, u.hp, u.max_hp])
		print("  %-12s killed %d, leaked %d, blew up %d, left %d | walls %s | units %s" % [CASES[current],
				killed, leaked, exploded, live.size(), wall_hp, unit_hp])
		if current + 1 >= CASES.size():
			return true
		_next()
	return false


func _hire(kind: String, p: Vector2) -> void:
	main.placing_type = kind
	main.hire_at(p)
	var w = main.warrior_layer.get_child(main.warrior_layer.get_child_count() - 1)
	w.position = w.post
	units.append(w)


func _wall(a: Vector2, b: Vector2) -> void:
	main.placing_type = "barricade"
	main.wall_start = null
	main.hire_at(a)
	main.hire_at(b)
	walls.append(main.wall_layer.get_child(main.wall_layer.get_child_count() - 1))


func _next() -> void:
	current += 1
	killed = 0
	leaked = 0
	main.clear_enemies()
	for w in main.get_warriors() + main.get_barricades():
		w.queue_free()
	walls = []
	units = []
	enemies = []
	await process_frame
	var kind := "bat"
	match CASES[current]:
		"bats_melee", "bats_archer":
			_wall(Vector2(0, 380), Vector2(320, 380))
			_wall(Vector2(320, 380), Vector2(640, 380))
			_hire("swordsman", Vector2(250, 470))
			_hire("swordsman", Vector2(390, 470))
			_hire("cannon", Vector2(320, 560))
			if CASES[current] == "bats_archer":
				_hire("archer", Vector2(320, 640))
		"sapper_wall":
			kind = "sapper"
			_wall(Vector2(0, 380), Vector2(320, 380))
			_wall(Vector2(320, 380), Vector2(640, 380))
		"sapper_troop":
			kind = "sapper"
			_hire("swordsman", Vector2(320, 420))
	main.walls_changed()
	for i in 4:
		main._spawn_enemy(kind, 5)
		var e = main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)
		e.position = Vector2(230 + i * 60, -10 - i * 40)
		e.died.connect(func(_e): killed += 1)
		e.reached_castle.connect(func(_e): leaked += 1)
		enemies.append(e)
	start = frames
