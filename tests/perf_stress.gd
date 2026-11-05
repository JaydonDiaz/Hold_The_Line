extends SceneTree
## Performance stress test. A late-game field: ~40 units with six upgrades each (tier-3
## powers everywhere), every emplacement, walls, the castle maxed (7 wall guards, all
## abilities, cast every few seconds), and ~150 enemies kept topped up, at 3x speed.
## Vsync is off and the sim steps a fixed 1/60 s a frame, so every run does the same
## work and the frame times are what the machine can do. Prints a 2-second running
## log, every frame over 55 ms (with what happened that frame), and a summary:
## frame time avg / p50 / p95 / p99 / max, frames over 33 ms, draw calls, objects.
##
## Run from the project folder:
##   Godot --path . --fixed-fps 60 -s tests/perf_stress.gd -- <seconds> <label> [mode]
## label "typical..." runs a lighter, normal-speed game (16 units, ~50 enemies);
## label "shot" also saves two screenshots to user://.
## mode:
##   profile          times each system's _process (units, enemies, effects...)
##   hide=<layer>     hides a layer (enemies, warriors, castle, fx, hud, ambience,
##                    powers, ground, all) to see what drawing it costs
##   hide=freeze,<layer>  freezes the sim (drawing only), optionally hiding a layer

const Data = preload("res://scripts/data.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const ENEMY_KINDS := ["goblin", "orc", "wolf", "bat", "sapper", "troll", "warlord", "wyvern"]
var TARGET_ENEMIES := 150

var main
var frames := 0
var start_frame := 90
var sim_frames := 60 * 40
var last_us := 0
var times := []          # ms per frame
var draws := []
var objs := []
var proc := []
var nodes_max := 0
var spikes := 0
var label := ""
var rng := RandomNumberGenerator.new()
var window := []         # frame times in the current 2 s window
var cast_i := 0
var last_cache := 0
var last_fields := 0
const SpritesS = preload("res://scripts/sprites.gd")
var profile := false
var hide_layer := ""
var extra_hide := ""
var prof := {}           # system -> total usec


func _initialize() -> void:
	rng.seed = 7
	seed(7)
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		sim_frames = int(a[0]) * 60
	label = a[1] if a.size() > 1 else "run"
	profile = a.size() > 2 and a[2] == "profile"
	hide_layer = a[2].substr(5) if a.size() > 2 and a[2].begins_with("hide=") else ""
	if hide_layer.contains(","):
		extra_hide = hide_layer.get_slice(",", 1)
		hide_layer = hide_layer.get_slice(",", 0)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _setup() -> void:
	main.hud.picking = true
	main.choose_mode("normal")
	main.endless = true
	main.wave = 30
	main.gold = 10000000
	var troops := ["swordsman", "archer", "mage", "frost", "martial", "healer", "bard", "alchemist"]
	var emps := ["tower", "cannon", "magetower", "frosttower", "medbay", "statue", "mine"]
	var i := 0
	var ys := [300.0, 380.0, 460.0, 540.0, 620.0]
	if label.begins_with("typical"):
		ys = [380.0, 620.0]
		TARGET_ENEMIES = 50
	for y in ys:
		for x in range(50, 600, 70):
			var kind: String = troops[i % troops.size()] if y < 600.0 else emps[i % emps.size()]
			main.placing_type = kind
			main.hire_at(Vector2(x + (35 if int(y) % 160 == 0 else 0), y))
			i += 1
	main.placing_type = ""
	# Six upgrades each: 3 in one path and 3 in the next (tier-3 powers everywhere).
	var n := 0
	for w in main.get_warriors():
		main.selected = w
		var p := n % 4
		for k in 3:
			main.upgrade_selected(p)
			main.upgrade_selected((p + 1) % 4)
		n += 1
	main.selected = null
	# Walls.
	main.placing_type = "barricade"
	for seg in [[Vector2(40, 230), Vector2(200, 230)], [Vector2(440, 230), Vector2(600, 230)], [Vector2(260, 700), Vector2(380, 700)]]:
		main._wall_click(seg[0])
		main._wall_click(seg[1])
	main.placing_type = ""
	# Castle: everything.
	for p in 4:
		for t in 4:
			main.castle_upgrade(p)
	for k in Data.ABILITIES:
		main.ability_item(k)
	main.wave_active = true
	Engine.time_scale = 1.0 if label.begins_with("typical") else 3.0
	if profile:
		main.set_process(false)
		for layer in [main.warrior_layer, main.enemy_layer, main.fx_layer, main.powers, main.castle, main.ambience, main.wall_layer]:
			layer.process_mode = Node.PROCESS_MODE_DISABLED
	match hide_layer:
		"enemies": main.enemy_layer.visible = false
		"warriors": main.warrior_layer.visible = false
		"castle": main.castle.visible = false
		"fx": main.fx_layer.visible = false
		"hud": main.hud.visible = false
		"ambience": main.ambience.visible = false
		"powers": main.powers.visible = false
		"overlay": main.overlay.visible = false
		"ground": RenderingServer.canvas_item_clear(main.get_canvas_item())
		"all":
			for l in [main.enemy_layer, main.warrior_layer, main.castle, main.fx_layer, main.hud, main.ambience, main.powers, main.overlay, main.wall_layer, main.grave_layer]:
				l.visible = false
	print("[%s] setup: %d warriors, %d guards, %d walls" % [label, main.get_warriors().size(), main.powers.guards.size(), main.get_barricades().size()])


func _top_up() -> void:
	var have: int = main.get_enemies().size() + main.spawn_queue.size()
	for k in range(have, TARGET_ENEMIES):
		var kind: String = ENEMY_KINDS[rng.randi() % ENEMY_KINDS.size()]
		main.spawn_queue.append([kind, 30])
	main.spawn_interval = 0.05


func _process(_d: float) -> bool:
	frames += 1
	var now := Time.get_ticks_usec()
	if frames == 5:
		_setup()
	if frames >= 5:
		main.gold = 10000000
		main.castle_hp = main.castle_max   # keep the game going
		if frames % 30 == 0:
			_top_up()
	if extra_hide != "" and frames == start_frame - 1:
		var m := {"ground": main.overlay, "enemies": main.enemy_layer, "warriors": main.warrior_layer, "castle": main.castle, "fx": main.fx_layer, "hud": main.hud, "ambience": main.ambience, "powers": main.powers}
		if m.has(extra_hide): m[extra_hide].visible = false
		if extra_hide == "ground":
			pass
	if extra_hide == "ground" and frames == start_frame + 2:
		RenderingServer.canvas_item_clear(main.get_canvas_item())
	if hide_layer == "freeze" and frames == start_frame - 1:
		main.process_mode = Node.PROCESS_MODE_DISABLED
		main.hud.process_mode = Node.PROCESS_MODE_DISABLED
		for l in [main.enemy_layer, main.warrior_layer, main.castle, main.fx_layer, main.ambience, main.powers, main.wall_layer]:
			l.process_mode = Node.PROCESS_MODE_DISABLED
		# keep redrawing what moves, as if it were live
	if hide_layer == "freeze" and frames > start_frame:
		for l in [main.enemy_layer, main.warrior_layer, main.fx_layer]:
			for n in l.get_children():
				n.queue_redraw()
		main.castle.queue_redraw()
		main.ambience.queue_redraw()
		main.powers.queue_redraw()
	if hide_layer == "ground" and frames == start_frame - 5:
		RenderingServer.canvas_item_clear(main.get_canvas_item())
	if profile and frames > 5:
		_run_profiled(0.05)
	if frames > start_frame:
		var ms := (now - last_us) / 1000.0
		times.append(ms)
		window.append(ms)
		if ms > 33.4:
			spikes += 1
		var cache_n: int = SpritesS._cache.size()
		var fields_n: int = main.paths.fields.size() + (1 if main.paths.troop_grid != null else 0)
		if ms > 55.0:
			print("[%s] SPIKE f%d %.0f ms | new sprites %d | path fields %d->%d | enemies %d fx %d" % [label, frames, ms, cache_n - last_cache, last_fields, fields_n, main.get_enemies().size(), main.fx_layer.get_child_count()])
		last_cache = cache_n
		last_fields = fields_n
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		objs.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		nodes_max = maxi(nodes_max, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		# Abilities every few seconds, at the thick of it.
		if frames % 120 == 0:
			var keys: Array = main.powers.abilities()
			var key: String = keys[cast_i % keys.size()]
			cast_i += 1
			main.powers.cooldown[key] = 0.0
			main.powers.trigger(key)
			if main.powers.aiming != "":
				var es: Array = main.get_enemies()
				if not es.is_empty():
					main.powers.aim_click(es[0].position)
		if window.size() == 120:
			window.sort()
			print("[%s] t=%3ds enemies %3d fx %3d nodes %4d | frame avg %5.1f max %5.1f ms | draws %d" % [label, (frames - start_frame) / 60,
					main.get_enemies().size(), main.fx_layer.get_child_count(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
					_avg(window), window[-1], draws[-1]])
			window.clear()
			var mix := {}
			for n in main.fx_layer.get_children():
				var k: String = n.get("mode") if n.get("mode") != null else n.get_script().resource_path.get_file()
				mix[k] = mix.get(k, 0) + 1
			print("[%s] FXMIX %s" % [label, str(mix)])
	if label == "shot" and frames in [start_frame + 200, start_frame + 420]:
		root.get_texture().get_image().save_png("%sstress_shot_%d.png" % ["user://", frames])
	last_us = now
	if frames >= start_frame + sim_frames:
		_report()
		return true
	return false


func _time(key: String, nodes: Array, d: float) -> void:
	var t0 := Time.get_ticks_usec()
	for n in nodes:
		if is_instance_valid(n) and not n.is_queued_for_deletion() and n.has_method("_process"):
			n._process(d)
	if frames > start_frame:
		prof[key] = prof.get(key, 0) + Time.get_ticks_usec() - t0


func _run_profiled(d: float) -> void:
	_time("main+hud", [main], d)
	_time("warriors", main.warrior_layer.get_children(), d)
	_time("enemies", main.enemy_layer.get_children(), d)
	_time("fx+projectiles", main.fx_layer.get_children(), d)
	_time("powers", [main.powers], d)
	_time("guards", main.powers.guards, d)
	_time("walls", main.wall_layer.get_children(), d)
	_time("castle+xray", [main.castle] + main.castle.get_children(), d)
	_time("ambience", [main.ambience], d)


func _avg(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(a.size(), 1)


func _pct(a: Array, p: float) -> float:
	var b := a.duplicate()
	b.sort()
	return b[mini(int(b.size() * p), b.size() - 1)]


func _report() -> void:
	var line := []
	for i in range(mini(300, times.size() - 1), mini(420, times.size())):
		line.append(str(roundi(times[i])))
	print("[%s] SERIES %s" % [label, " ".join(line)])
	if profile:
		var keys := prof.keys()
		keys.sort_custom(func(x, y): return prof[x] > prof[y])
		for k in keys:
			print("[%s] PROFILE %-15s %6.2f ms/frame" % [label, k, prof[k] / 1000.0 / times.size()])
	print("[%s] SUMMARY frames %d | frame ms avg %.2f p50 %.2f p95 %.2f p99 %.2f max %.2f | spikes>33ms %d | process ms avg %.2f p99 %.2f | draw calls avg %.0f max %.0f | objects avg %.0f | nodes max %d" % [
			label, times.size(), _avg(times), _pct(times, 0.5), _pct(times, 0.95), _pct(times, 0.99), _pct(times, 1.0), spikes,
			_avg(proc), _pct(proc, 0.99), _avg(draws), _pct(draws, 1.0), _avg(objs), nodes_max])
