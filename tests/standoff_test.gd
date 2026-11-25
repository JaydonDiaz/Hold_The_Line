extends SceneTree
## Foes that stand off and fight from a distance can't hold up a wave forever. Run from the
## project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/standoff_test.gd
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.
##
## C  With troops posted right below the enemy camp, a Warmage and a Gravebinder still come
##    out of the camp (where troops can't go) instead of standing in it
## H  Troops holding their posts just out of a Warmage's or Gravebinder's reach don't keep it
##    standing off forever: it presses on, into reach

var main
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(3)
	for kind in ["warmage", "gravebinder"]:
		await _camp(kind)
		await _held_off(kind)
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _fresh() -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	main.records_path = ""
	root.add_child(main)
	await _frames(3)
	main.hud.picking = true
	main.setup.choose_mode("normal")
	main.gold = 99999
	main.wave_active = true   # (the foes are set down by hand; no wave rolls in)
	await process_frame


func _hire(kind: String, at: Vector2):
	main.placing_type = kind
	main.hiring.hire_at(at)
	main.placing_type = ""
	main.selected = null
	var all: Array = main.battlefield.get_warriors().filter(func(w): return w.kind == kind)
	var w = all[all.size() - 1]
	w.max_hp = 99999.0
	w.hp = 99999.0
	return w


func _spawn(kind: String, at: Vector2):
	main.waves._spawn_enemy(kind, 1, at)
	var all: Array = main.battlefield.get_enemies().filter(func(e): return e.kind == kind)
	var e = all[all.size() - 1]
	e.max_hp = 99999.0   # (it's how it moves that's being watched, not who wins)
	e.hp = 99999.0
	return e


## Troops posted along the camp's edge, and the foe set down inside the camp: within a
## while it has come out where they can reach it.
func _camp(kind: String) -> void:
	await _fresh()
	var top: float = main.DEPLOY_TOP
	for x in [200.0, 320.0, 440.0]:
		var w = await _hire("swordsman", Vector2(x, top + 24.0))
		w.move_mode = "hold"
	var e = await _spawn(kind, Vector2(320.0, top - 40.0))
	var out := false
	for i in 60 * 30:
		await process_frame
		if not is_instance_valid(e) or e.dead or e.position.y + e.radius >= top:   # (troops can get at it: warrior._is_valid)
			out = true
			break
	check(out, "C  %s: troops right below its camp, it still comes out where they can reach it (at y %d, camp edge %d)"
			% [kind.capitalize(), int(e.position.y) if is_instance_valid(e) else -1, int(top)])


## A troop holding its post just beyond the foe's reach: before long the foe closes in.
func _held_off(kind: String) -> void:
	await _fresh()
	var w = await _hire("swordsman", Vector2(320.0, 420.0))
	w.move_mode = "hold"
	var e = await _spawn(kind, Vector2(320.0, 260.0))
	var start_gap: float = e.position.distance_to(w.position)
	var closed := false
	for i in 60 * 40:
		await process_frame
		if not is_instance_valid(e) or e.dead or e.position.distance_to(w.position) <= e.radius + w.RADIUS + 12.0:
			closed = true
			break
	check(closed, "H  %s: a troop holding its post just out of reach doesn't keep it standing off forever (gap %d -> %d)"
			% [kind.capitalize(), int(start_gap), int(e.position.distance_to(w.position)) if is_instance_valid(e) else -1])
