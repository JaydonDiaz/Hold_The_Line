extends SceneTree
## Checks the rules that keep supports from piling up, plus troop movement limits.
## Run: godot --headless --path . --fixed-fps 60 -s tools/stack_test.gd
##   statues   two War Statues give one statue's buff; a statue and a Bard add up
##   medbays   two Medic Bays covering a unit heal it like one
##   poison    two Alchemists poison like one
##   mines     each Gold Mine after the first digs 70% of the one before
##   teleport  a unit walled off from its post blinks there after 10s
##   spawn     troops never go up into the enemy spawn area

var main
var frames := 0


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.records_path = ""
	root.add_child(main)


func _hire(kind: String, p: Vector2, path := -1, tiers := 0):
	main.placing_type = kind
	main.hire_at(p)
	var w = main.warrior_layer.get_child(main.warrior_layer.get_child_count() - 1)
	w.position = w.post
	for t in tiers:
		main.selected = w
		main.upgrade_selected(path)
	main.selected = null
	return w


func _clear() -> void:
	main.clear_enemies()
	for w in main.get_warriors() + main.get_barricades():
		w.queue_free()
	main.paths.walls = []
	main.walls_changed()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		_run()
	return false


func _run() -> void:
	main.choose_mode("freeplay")
	await _wait(2)

	# Statues.
	var sw = _hire("swordsman", Vector2(320, 400))
	_hire("statue", Vector2(280, 460))
	await _wait(30)
	var one: float = sw.buff["damage"]
	_hire("statue", Vector2(360, 460))
	await _wait(30)
	var two: float = sw.buff["damage"]
	_hire("bard", Vector2(320, 440), 0, 1)
	await _wait(30)
	print("  statues   one %.2f, two %.2f, two + bard %.2f, bard rate %.2f" % [one, two, sw.buff["damage"], sw.buff["rate"]])
	_clear()
	await _wait(2)

	# Medic Bays.
	var heals := []
	for n in [1, 2]:
		sw = _hire("swordsman", Vector2(320, 400))
		for i in n:
			_hire("medbay", Vector2(280 + i * 80, 460))
		await _wait(2)
		sw.hp = 10.0
		await _wait(60 * 5)
		heals.append(roundi(sw.hp - 10.0))
		_clear()
		await _wait(2)
	print("  medbays   healed in 5s: one bay %d, two bays %d" % heals)

	# Alchemists.
	for n in [1, 2]:
		for i in n:
			_hire("alchemist", Vector2(260 + i * 120, 400), 0, 2)
		main._spawn_enemy("troll", 1)
		var dummy = main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)
		dummy.position = Vector2(320, 300)
		dummy.speed = 0.0
		dummy.fights = false
		dummy.max_hp = 100000.0
		dummy.hp = dummy.max_hp
		await _wait(60 * 8)
		var worst := 0.0
		for dose in dummy.poisons.values():
			worst = maxf(worst, dose[0] * dose[1])
		print("  poison    %d alchemist(s): poison doing %.0f dmg/s, %d separate doses" % [n, worst, dummy.poisons.size()])
		_clear()
		await _wait(2)

	# Mines.
	var mines := []
	for i in 3:
		mines.append(_hire("mine", Vector2(200 + i * 120, 600)))
	await _wait(2)
	print("  mines     shares %s" % [mines.map(func(m): return snappedf(m.mine_share(), 0.01))])
	_clear()
	await _wait(2)

	# Teleport: a box of walls around the post, the unit outside it.
	sw = _hire("swordsman", Vector2(320, 500))
	for seg in [[Vector2(260, 440), Vector2(380, 440)], [Vector2(380, 440), Vector2(380, 560)],
			[Vector2(380, 560), Vector2(260, 560)], [Vector2(260, 560), Vector2(260, 440)]]:
		main.placing_type = "barricade"
		main.wall_start = null
		main.hire_at(seg[0])
		main.hire_at(seg[1])
	main.walls_changed()
	sw.position = Vector2(320, 650)
	var t0 := frames
	while sw.position.distance_to(sw.post) > 3.0 and frames - t0 < 60 * 15:
		await process_frame
	print("  teleport  reached post after %.1fs" % ((frames - t0) / 60.0))
	_clear()
	await _wait(2)

	# Spawn area.
	sw = _hire("swordsman", Vector2(320, 140))
	main._spawn_enemy("orc", 1)
	var orc = main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)
	orc.position = Vector2(320, 40)
	orc.speed = 0.0
	var top := 1000.0
	for i in 60 * 4:
		top = minf(top, sw.position.y)
		await process_frame
	print("  spawn     highest troop y %.0f (spawn area ends at %d)" % [top, main.DEPLOY_TOP])
	quit()


func Data():
	return preload("res://scripts/data.gd")
