extends SceneTree
## Buying and selling several at once, and buying the fallen back. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/buysell_test.gd
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.
##
## N  The hire count (N, or the button by the tabs) goes 1, 3, 5 and round; at 3 or 5 one
##    click posts that many together, apart, round the click, as many as the gold covers
## S  Sell all: with a group selected, Sell asks first (and does nothing if told no); told
##    yes, it sells each at its own value, skipping downed troops
## R  Rebuy: a grave's troop comes back with every upgrade it had, near where it fell, for
##    its hire and upgrades at today's prices, all at once; not without the gold; the grave
##    and its body stay (it's only a quicker way to replace the troop), and each grave's
##    troop is replaced once; S on a selected grave does it too; a castle wall guard's
##    grave can't be rebought

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
	await _count()
	await _sell_all()
	await _rebuy()
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
	main.formation_ctl.formations_path = ""
	root.add_child(main)
	await _frames(3)
	main.hud.picking = true
	main.setup.choose_mode("normal")
	main.gold = 99999
	await process_frame


func _hire(kind: String, at: Vector2):
	main.placing_type = kind
	main.hiring.hire_at(at)
	main.placing_type = ""
	main.selected = null
	var all: Array = main.warrior_layer.get_children().filter(func(w): return w.kind == kind)
	return all[all.size() - 1]


func _of(kind: String) -> Array:
	return main.warrior_layer.get_children().filter(func(w): return w.kind == kind and not w.is_queued_for_deletion())


# --- N: the hire count ------------------------------------------------------------------
func _count() -> void:
	await _fresh()
	var seen := [main.hiring.hire_count]
	for i in 3:
		main.hiring.cycle_hire_count()
		seen.append(main.hiring.hire_count)
	check(seen == [1, 3, 5, 1], "N  the hire count goes 1, 3, 5 and round (%s)" % str(seen))

	var cost: int = main.hiring.hire_cost("swordsman")
	main.gold = 1000
	main.hiring.hire_count = 3
	main.placing_type = "swordsman"
	main.hiring.hire_at(Vector2(320, 450))
	var s := _of("swordsman")
	var apart := true
	for a in s:
		for b in s:
			if a != b and a.post.distance_to(b.post) < main.MIN_POST_GAP:
				apart = false
	var near: bool = s.all(func(w): return w.post.distance_to(Vector2(320, 450)) < 80.0)
	check(s.size() == 3 and main.gold == 1000 - 3 * cost, "N  at x3 one click hires three, paid for (%d hired, %dg left)" % [s.size(), main.gold])
	check(apart and near, "N  ...posted together round the click, apart from each other")
	check(main.placing_type == "", "N  ...and the hire's done (no Shift held)")

	main.gold = main.hiring.hire_cost("archer") * 2 + 5
	main.hiring.hire_count = 5
	main.placing_type = "archer"
	main.hiring.hire_at(Vector2(320, 600))
	check(_of("archer").size() == 2 and main.gold == 5, "N  at x5 with gold for two, two are hired (%d)" % _of("archer").size())

	main.gold = 1000
	main.hiring.hire_count = 1
	main.placing_type = "swordsman"
	main.hiring.hire_at(Vector2(150, 300))
	check(_of("swordsman").size() == 4, "N  at x1, a click hires one as ever")


# --- S: selling a group -----------------------------------------------------------------
func _sell_all() -> void:
	await _fresh()
	main.hiring.hire_count = 1
	var units := []
	for x in [200.0, 260.0, 320.0, 380.0]:
		units.append(await _hire("swordsman", Vector2(x, 500)))
	await process_frame
	units[3].down_timer = 10.0   # a downed one: it isn't sold
	main.group = units.duplicate()
	var worth: int = units[0].sell_value() + units[1].sell_value() + units[2].sell_value()
	var gold0: int = main.gold
	main.formation_ctl.sell_selected()
	var asked: bool = main.hud.sell_dim != null and is_instance_valid(main.hud.sell_dim)
	check(asked and paused and main.gold == gold0 and _of("swordsman").size() == 4, "S  Sell with a group selected asks first (nothing sold yet)")
	# "Keep them"
	paused = false
	main.hud.sell_dim.queue_free()
	await process_frame
	check(main.gold == gold0 and _of("swordsman").size() == 4, "S  ...told no, nothing's sold")
	main.formation_ctl.sell_selected()
	paused = false
	main.hud.sell_dim.queue_free()
	main.hud.sell_all_confirmed.emit()
	await process_frame
	check(main.gold == gold0 + worth, "S  told yes, it sells each at its own value (+%d, expected +%d)" % [main.gold - gold0, worth])
	check(_of("swordsman").size() == 1 and _of("swordsman")[0] == units[3], "S  ...all but the downed one")
	check(main.group.is_empty(), "S  ...and the group's let go")


# --- R: buying back from a grave --------------------------------------------------------
func _rebuy() -> void:
	await _fresh()
	main.hiring.hire_count = 1
	var a = await _hire("archer", Vector2(320, 520))
	await _frames(2)
	main.selected = a
	for p in [0, 0, 2]:
		main.groups.upgrade_selected(p)
	main.selected = null
	var tiers: Array = a.tiers.duplicate()
	var expect: int = main.hiring.hire_cost("archer") + a.tier_cost(0, 0) + a.tier_cost(0, 1) + a.tier_cost(2, 0)
	var at: Vector2 = a.position
	main.battlefield.add_grave(a)   # (falls for good)
	a.queue_free()
	await _frames(2)
	var g = main.battlefield.get_graves()[0]
	check(main.hiring.rebuy_cost(g) == expect, "R  rebuying costs the hire and every upgrade it had (%dg, expected %dg)" % [main.hiring.rebuy_cost(g), expect])
	check(main.fallen.any(func(r): return r["kind"] == "archer"), "R  (its body lies there for a Gravebinder to raise)")

	main.gold = expect - 1
	main.hiring.rebuy_grave(g)
	await process_frame
	check(_of("archer").is_empty() and main.gold == expect - 1 and is_instance_valid(g), "R  one gold short, nothing's bought")

	main.gold = expect + 7
	main.selected_grave = g
	main.formation_ctl.sell_selected()   # S on the grave
	await _frames(2)
	var back := _of("archer")
	check(back.size() == 1 and back[0].tiers == tiers, "R  S on the grave buys it back with every upgrade (%s, had %s)" % [str(back[0].tiers) if not back.is_empty() else "none", str(tiers)])
	check(main.gold == 7, "R  ...paid all at once (%dg left, expected 7)" % main.gold)
	check(not back.is_empty() and back[0].post.distance_to(at) < 60.0, "R  ...posted where it fell")
	check(is_instance_valid(g) and not g.is_queued_for_deletion() and main.battlefield.get_graves().has(g), "R  ...and the grave stays (it's only a quicker way to replace the troop)")
	check(main.fallen.any(func(r): return r["kind"] == "archer"), "R  ...and so does its body (a Gravebinder could still raise it)")
	main.gold = 99999
	check(main.hiring.rebuy_problem(g) != "", "R  each grave's troop is replaced once (%s)" % main.hiring.rebuy_problem(g))
	main.hiring.rebuy_grave(g)
	await process_frame
	check(_of("archer").size() == 1 and main.gold == 99999, "R  ...a second Rebuy buys nothing")

	var guard = await _hire("swordsman", Vector2(200, 400))
	main.battlefield.add_grave(guard)
	guard.queue_free()
	await _frames(2)
	var g2 = main.battlefield.get_graves().filter(func(x): return x.kind == "swordsman")[0]
	g2.rebuyable = false   # (as a castle wall guard's)
	main.gold = 99999
	check(main.hiring.rebuy_problem(g2) != "", "R  a wall guard's grave can't be rebought (%s)" % main.hiring.rebuy_problem(g2))
