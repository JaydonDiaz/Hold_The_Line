extends SceneTree
## Melee chase check: sends a pack of wolves past two swordsmen and counts how many escape.
## Run: godot --headless --path . --fixed-fps 60 -s tools/wolf_test.gd

const Data = preload("res://scripts/data.gd")
const WOLVES := 12

var main
var frames := 0
var spawned := 0
var escaped := 0
var killed := 0


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		main.choose_mode("normal")
		main.gold = 1000
		for x in [250.0, 390.0]:
			main.placing_type = "swordsman"
			main.hire_at(Vector2(x, 400))
		for w in main.get_warriors():
			w.position = w.post
		main.wave = 3   # wolves get wave-3 health
	# Release a wolf every 0.75s across the middle of the field.
	if frames > 10 and spawned < WOLVES and frames % 45 == 0:
		var e = main.Enemy.new()
		e.setup("wolf", Data.ENEMIES["wolf"], main, Vector2(randf_range(200, 440), 10),
				pow(Data.HP_GROWTH, main.wave - 1), 1.0, 1.0)
		e.died.connect(func(_e): killed += 1)
		e.reached_castle.connect(func(_e): escaped += 1)
		main.enemy_layer.add_child(e)
		spawned += 1
	if spawned == WOLVES and killed + escaped == WOLVES:
		print("wolves killed %d, escaped %d" % [killed, escaped])
		return true
	return frames > 60 * 120
