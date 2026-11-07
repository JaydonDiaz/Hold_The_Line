extends SceneTree
## Frame times on a campaign battlefield with terrain, against the same fight on open
## ground. Run from the project folder (not headless; vsync is switched off):
##   Godot --path . --resolution 640x1040 --fixed-fps 60 -s tests/perf_terrain.gd -- <seconds> <map>
## <map> is a maps.gd id (stonehollow_quarry, ashwatch_ridge) or "open" for no terrain.
## The fight: ~30 upgraded troops of every kind, Engineers kept busy building and
## rebuilding emplacements, ~150 enemies kept topped up (a third of them Skeleton Archers
## and Slimes), and every enemy knocked about every two seconds. A third argument
## "notroops" leaves the troops (and Engineers) out, to time the enemies alone. Prints a summary line
## like perf_stress.gd's: frame ms avg / p50 / p95 / p99 / max.

const Maps = preload("res://scripts/maps.gd")
const KINDS := ["goblin", "orc", "wolf", "skeleton_archer", "slime", "troll", "skeleton_archer", "slime", "sapper", "warlord"]

var main
var frames := 0
var sim_frames := 60 * 30
var map_id := "stonehollow_quarry"
var times := []
var last_us := 0
var rng := RandomNumberGenerator.new()
var sites := []
var no_troops := false   # "notroops": enemies only, to see what their movement costs


func _initialize() -> void:
	rng.seed = 11
	seed(11)
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		sim_frames = int(a[0]) * 60
	if a.size() > 1:
		map_id = a[1]
	no_troops = a.size() > 2 and a[2] == "notroops"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var c = root.get_node("Campaign")
	c.save_path = "user://perf_terrain.cfg"
	c.new_campaign("normal")
	c.completed = ["ashwatch"]
	c.allies = c.CD.FACTIONS.keys()
	c.save_game()   # the game reloads the save as it starts
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _setup() -> void:
	main.hud.hide_mode_select()
	main.start_mission("stonehollow")
	if main.hud.story != null:
		main.hud.story.skip()
	main.paths.set_map(Maps.get_map(map_id) if map_id != "open" else {})
	main.gold = 10000000
	for w in main.get_warriors():
		w.free()
	main.warriors_changed()
	# Troops on every open spot of a coarse grid below the camp.
	var kinds := ["swordsman", "archer", "mage", "frost", "martial", "healer", "bard", "alchemist"]
	var i := 0
	for y in (range(470, 690, 44) if not no_troops else []):
		for x in range(40, 620, 44):
			if i >= 30:
				break
			var p := Vector2(x, y)
			if main.can_post_at(p):
				main.placing_type = kinds[i % kinds.size()]
				main.hire_at(p)
				i += 1
	main.placing_type = ""
	for w in main.get_warriors():
		w.position = w.post
		main.selected = w
		for k in 3:
			main.upgrade_selected(k % 4)
	main.selected = null
	main.wave_active = true
	main.castle_hp = 1e9
	main.castle_max = 1e9
	Engine.time_scale = 2.0
	print("[%s] setup: %d troops" % [map_id, main.get_warriors().size()])


func _process(_d: float) -> bool:
	frames += 1
	var now := Time.get_ticks_usec()
	if frames == 5:
		_setup()
	if frames > 5:
		main.gold = 10000000
		main.castle_hp = 1e9
		if frames % 30 == 0:
			var have: int = main.get_enemies().size() + main.spawn_queue.size()
			for k in range(have, 150):
				main.spawn_queue.append([KINDS[rng.randi() % KINDS.size()], 6])
			main.spawn_interval = 0.05
		if frames % 120 == 0:
			for e in main.get_enemies():
				e.apply_knockback(Vector2(rng.randf_range(-70, 70), rng.randf_range(-70, 70)))
		if frames % 90 == 0 and not no_troops:
			# Keep the Engineers walking: sell a site and build another somewhere else.
			for s in sites:
				if is_instance_valid(s):
					s.free()
			main.warriors_changed()
			sites.clear()
			for k in 3:
				var p := Vector2(rng.randf_range(60, 580), rng.randf_range(480, 680))
				if main.can_post_at(p):
					main.placing_type = ["tower", "cannon", "magetower"][k]
					main.hire_at(p)
					var all: Array = main.get_warriors().filter(func(w): return w.is_emplacement())
					if not all.is_empty():
						sites.append(all[all.size() - 1])
			main.placing_type = ""
	if frames > 90:
		times.append((now - last_us) / 1000.0)
	last_us = now
	if frames >= 90 + sim_frames:
		var sorted := times.duplicate()
		sorted.sort()
		var avg := 0.0
		for t in times:
			avg += t
		avg /= times.size()
		var pick := func(q: float) -> float: return sorted[mini(int(q * sorted.size()), sorted.size() - 1)]
		print("[%s] SUMMARY frames %d | frame ms avg %.2f p50 %.2f p95 %.2f p99 %.2f max %.2f | enemies %d" % [map_id, times.size(), avg,
				pick.call(0.5), pick.call(0.95), pick.call(0.99), sorted[sorted.size() - 1], main.get_enemies().size()])
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://perf_terrain.cfg"))
		return true
	return false
