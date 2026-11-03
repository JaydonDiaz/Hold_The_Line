extends SceneTree
## Solo duels: every max build (4 tiers in one path, 2 in another) of every unit
## against a single Warlord. Reports which builds kill it before it reaches the bottom.
## Run: godot --headless --path . --fixed-fps 60 -s tools/duel_test.gd -- [level] [unit]

const Data = preload("res://scripts/data.gd")

var main
var frames := 0
var level := 10
var only := ""
var duels := []      # [kind, tiers]
var current := -1
var warlord = null
var result := ""
var start_frame := 0
var hp_left := 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		level = int(args[0])
	if args.size() > 1:
		only = args[1]
	for kind in Data.WARRIORS:
		if only != "" and kind != only:
			continue
		if Data.WARRIORS[kind]["attack"] == "wall":
			continue   # walls are placed with two clicks and don't fight
		for a in 3:
			for b in 3:
				if a != b:
					var tiers := [0, 0, 0]
					tiers[a] = 4
					tiers[b] = 2
					duels.append([kind, tiers])
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		main.choose_mode("freeplay")
		main.freeplay_level = level
		print("Solo vs Warlord, level %d" % level)
		_next()
		return false
	if frames < 2:
		return false
	if result == "":
		if not is_instance_valid(warlord) or warlord.dead:
			result = "WIN" if not is_instance_valid(warlord) or warlord.hp <= 0.0 else "LOSE"
		elif frames - start_frame > 60 * 120:
			result = "TIMEOUT"
	if result != "":
		var d: Array = duels[current]
		if result == "TIMEOUT":
			hp_left = warlord.hp / warlord.max_hp
		print("  %-9s %s  %s%s" % [d[0], "-".join(d[1].map(func(t): return str(t))), result,
				"" if result == "WIN" else "  (warlord at %d%% hp)" % roundi(hp_left * 100)])
		if current + 1 >= duels.size():
			return true
		_next()
	return false


func _next() -> void:
	current += 1
	result = ""
	main.clear_enemies()
	for w in main.get_warriors():
		w.queue_free()
	var d: Array = duels[current]
	main.placing_type = d[0]
	main.hire_at(Vector2(320, 450))
	# The new hire isn't in the tree's warrior list until next frame; grab it directly.
	var w = main.warrior_layer.get_child(main.warrior_layer.get_child_count() - 1)
	w.position = w.post
	for p in 3:
		for t in d[1][p]:
			main.selected = w
			main.upgrade_selected(p)
	main.selected = null
	main._spawn_enemy("warlord", level)
	warlord = main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)
	warlord.position.x = 320
	warlord.reached_castle.connect(_on_leak)
	start_frame = frames


func _on_leak(e) -> void:
	result = "LOSE"
	hp_left = e.hp / e.max_hp
