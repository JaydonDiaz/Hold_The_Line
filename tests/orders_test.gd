extends SceneTree
## Unit orders: target commitment (Focused / Reactive), movement zones (Hold, Short
## Leash, Guard Area, Free Roam) around each unit's post, and blows struck in passing.
## Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/orders_test.gd
## Classic on the open meadow, the field held at 640 wide. Exits 1 if anything failed.

const Warrior = preload("res://scripts/warrior.gd")

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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _fresh() -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud.hide_mode_select()
	main.choose_mode("normal")
	await _frames(2)
	main._lock_portrait(true)
	await _frames(2)
	main.gold = 99999
	main.wave_active = true
	main.spawn_queue.clear()


## A troop posted at `at`, standing there already (no march in from the side).
func _hire(kind: String, at: Vector2, mode := "free", leash := 0.0, commit := "focused", priority := "closest"):
	main.placing_type = kind
	main.hire_at(at)
	main.placing_type = ""
	var w = main.get_warriors()[-1]
	w.position = w.post
	w.max_hp = 1e6
	w.hp = 1e6
	main.give_order("move_mode", mode, [w])
	if leash > 0.0:
		w.leash[mode] = leash
	main.give_order("commit", commit, [w])
	main.give_order("priority", priority, [w])
	return w


## An enemy standing still at `at` (it can't hurt anyone), with `hp` to spare.
func _foe(kind: String, at: Vector2, hp := 1e5):
	main._spawn_enemy(kind, 1, at)
	var e = main.get_enemies()[-1]
	e.position = at
	e.speed = 0.0
	e.damage = 0.0
	e.max_hp = hp
	e.hp = hp
	return e


func _run() -> void:
	await _commitment()
	await _passing_blows()
	await _target_dies()
	await _zones()
	await _opposite_sides()
	await _edge()
	await _ranged()
	await _specials()
	await _persistence()
	main.free()
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


# --- Commitment ---------------------------------------------------------------------

## For each priority: the unit picks one enemy; then another becomes the better pick.
## Focused stays on the first; Reactive switches.
func _commitment() -> void:
	for prio in ["first", "closest", "strongest", "weakest"]:
		for commit in ["focused", "reactive"]:
			await _fresh()
			var w = _hire("swordsman", Vector2(320, 640), "free", 0.0, commit, prio)
			var a
			var b
			match prio:
				"first":
					a = _foe("orc", Vector2(250, 420))
					b = _foe("orc", Vector2(430, 300))
				"closest":
					a = _foe("orc", Vector2(280, 470))
					b = _foe("orc", Vector2(560, 300))
				"strongest":
					a = _foe("orc", Vector2(260, 420))
					b = null
				"weakest":
					a = _foe("orc", Vector2(260, 420))
					b = null
			await _frames(10)
			var picked: bool = w.target == a
			# The other enemy becomes the better pick.
			match prio:
				"first":
					b.position = Vector2(430, 520)    # overtakes: now closer to the castle
				"closest":
					b.position = w.position + Vector2(70, -10)   # now right beside it
				"strongest":
					b = _foe("troll", Vector2(420, 380))   # a tougher kind turns up
				"weakest":
					b = _foe("goblin", Vector2(420, 380))  # a weaker kind turns up
			await _frames(45)
			if commit == "focused":
				check(picked and w.target == a, "Focused, %s: keeps its first pick when another becomes the better one" % prio)
			else:
				check(picked and w.target == b, "Reactive, %s: switches to the better pick, as before" % prio)


# --- Blows struck in passing --------------------------------------------------------

## A Swordsman going for a Troll (Strongest) passes a Goblin: it hits the Goblin on the way
## without stopping, switching, or staying to finish it, then reaches and kills the Troll.
func _passing_blows() -> void:
	await _fresh()
	var w = _hire("swordsman", Vector2(320, 700), "free", 0.0, "focused", "strongest")
	var troll = _foe("troll", Vector2(320, 230), 250.0)
	var gob = _foe("goblin", Vector2(320 + Warrior.RADIUS + 11.0 + 3.0, 470))
	var off_target := 0
	var passed_at := -1
	var gob_hp: float = gob.hp
	for f in 60 * 30:
		await process_frame
		if not is_instance_valid(troll) or troll.dead:
			break
		if w.target != troll:
			off_target += 1
		if passed_at < 0 and w.position.y < gob.position.y - 40.0:
			passed_at = f
	check(gob.hp < gob_hp, "Passing blows: it struck the Goblin it passed (%d damage)" % roundi(gob_hp - gob.hp))
	check(off_target == 0, "...without the Goblin ever becoming its target (%d frames off target)" % off_target)
	var travel: float = (700.0 - 470.0 + 40.0) / w.move_speed
	check(passed_at >= 0 and passed_at / 60.0 <= travel * 1.35 + 0.3, "...and walked on past it without stopping (%.1fs, a straight walk takes %.1fs)" % [passed_at / 60.0, travel])
	check(is_instance_valid(gob) and not gob.dead, "...leaving the Goblin alive behind it")
	check(not is_instance_valid(troll) or troll.dead, "...then reached the Troll and finished it")


## The enemy it's after dies on the way (to someone else): it picks another and goes on.
func _target_dies() -> void:
	await _fresh()
	var w = _hire("swordsman", Vector2(320, 700))
	var a = _foe("orc", Vector2(320, 380))   # nearest the castle: the First pick
	var c = _foe("orc", Vector2(120, 300))
	main.give_order("priority", "first", [w])
	await _frames(30)
	var had_a: bool = w.target == a
	a.take_damage(1e9)
	await _frames(20)
	check(had_a and w.target == c and w.moving, "Its target killed by someone else: it picks the next one and goes after it")


# --- Zones ---------------------------------------------------------------------------

## Guard Area: takes on what it can reach from its zone, never leaves the zone, lets go of
## an enemy that walks out of it, and comes back to its post.
func _zones() -> void:
	await _fresh()
	var post := Vector2(320, 600)
	var w = _hire("swordsman", post, "guard", 120.0)
	var a = _foe("orc", Vector2(320, 600 - 120 - Warrior.RADIUS - 14 - 4))
	var far := 0.0
	for f in 90:
		await process_frame
		far = maxf(far, w.position.distance_to(post))
	check(w.target == a and a.hp < a.max_hp, "Guard Area: goes out to fight an enemy at the edge of its area")
	check(far <= 120.0 + 2.0, "...and never leaves the area (furthest %d of 120px)" % roundi(far))
	a.position = Vector2(320, 250)   # it walks off
	await _frames(20)
	check(w.target == null, "An enemy that leaves its area is let go")
	await _frames(120)
	check(w.position.distance_to(post) <= 4.0, "...and it goes back to its post (%dpx off)" % roundi(w.position.distance_to(post)))
	# Hold: a Swordsman on Hold doesn't step out for anything it can't reach from its post.
	await _fresh()
	w = _hire("swordsman", post, "hold")
	var b = _foe("orc", Vector2(320, 520))
	await _frames(90)
	check(w.target == null and w.position.distance_to(post) <= 2.0, "Hold Position: ignores an enemy it can't reach from its post, and stays put")
	b.position = Vector2(320, 600 - Warrior.RADIUS - 14 - 4)
	await _frames(60)
	check(w.target == b and b.hp < b.max_hp and w.position.distance_to(post) <= 2.0, "...and fights one that comes within reach, without moving")
	# Short Leash, with a size of its own.
	await _fresh()
	w = _hire("swordsman", post, "short", 60.0)
	var c = _foe("orc", Vector2(320, 600 - 60 - Warrior.RADIUS - 14 - 4))
	far = 0.0
	for f in 90:
		await process_frame
		far = maxf(far, w.position.distance_to(post))
	check(w.target == c and c.hp < c.max_hp and far <= 62.0, "Short Leash at 60px: fights at the end of its leash and no further (%d px)" % roundi(far))


## Two units on Guard Area at either side of the field: all the enemies are on the right.
## The left one holds its side; the right one fights. Roaming free, the left one would cross.
func _opposite_sides() -> void:
	await _fresh()
	var left = _hire("swordsman", Vector2(120, 600), "guard", 120.0)
	var right = _hire("swordsman", Vector2(520, 600), "guard", 120.0)
	for p in [Vector2(520, 470), Vector2(560, 500), Vector2(480, 450)]:
		_foe("orc", p)
	var far_l := 0.0
	var far_r := 0.0
	for f in 300:
		await process_frame
		far_l = maxf(far_l, left.position.distance_to(left.post))
		far_r = maxf(far_r, right.position.distance_to(right.post))
	check(left.target == null and far_l <= 2.0, "Opposite sides: the left unit holds its side while the fight is on the right (moved %dpx)" % roundi(far_l))
	check(right.target != null and far_r <= 122.0, "...the right unit fights, within its own area (furthest %dpx)" % roundi(far_r))
	main.give_order("move_mode", "free", [left])
	far_l = 0.0
	for f in 240:
		await process_frame
		far_l = maxf(far_l, left.position.distance_to(left.post))
	check(far_l > 200.0, "...and set to Free Roam, the left unit crosses the field to join in (%dpx)" % roundi(far_l))


## At the edge of its area: an enemy just out of reach is left alone (no creeping to the
## edge and back); one just in reach is fought from the edge, standing still (no jitter).
func _edge() -> void:
	await _fresh()
	var post := Vector2(320, 600)
	var w = _hire("swordsman", post, "guard", 100.0)
	var reach_edge: float = 100.0 + Warrior.RADIUS + 14.0 + w.attack_range
	var out = _foe("orc", post + Vector2(0, -(reach_edge + 6.0)))
	var moved := 0.0
	var last: Vector2 = w.position
	for f in 120:
		await process_frame
		moved += w.position.distance_to(last)
		last = w.position
	check(w.target == null and moved < 1.0, "Just out of reach of its area: left alone, no creeping (%.1fpx walked)" % moved)
	out.position = post + Vector2(0, -(reach_edge - 3.0))
	await _frames(90)   # walks out to the edge and starts fighting
	moved = 0.0
	last = w.position
	var switches := 0
	var held = w.target
	var hp0: float = out.hp
	for f in 180:
		await process_frame
		moved += w.position.distance_to(last)
		last = w.position
		if w.target != held:
			switches += 1
			held = w.target
	check(w.target == out and out.hp < hp0, "Just in reach: fought from the edge of its area")
	check(moved < 4.0 and switches == 0, "...standing still there: %.1fpx of movement and %d target changes in 3s" % [moved, switches])


## Ranged troops fight from inside their area: on Hold an Archer shoots what's in range of
## its post without moving (and doesn't back away); on Guard it steps up only to its area's edge.
func _ranged() -> void:
	await _fresh()
	var post := Vector2(320, 620)
	var a = _hire("archer", post, "hold")
	var near = _foe("orc", Vector2(320, 620 - 150))
	var far = _foe("orc", Vector2(560, 620 - 300))
	var moved := 0.0
	for f in 150:
		await process_frame
		moved = maxf(moved, a.position.distance_to(post))
	check(near.hp < near.max_hp and far.hp == far.max_hp, "Archer on Hold: shoots the enemy in range of its post, leaves the one out of range")
	check(moved <= 2.0, "...without moving (%dpx)" % roundi(moved))
	near.position = post + Vector2(0, -30)   # one walks right up to it
	moved = 0.0
	for f in 90:
		await process_frame
		moved = maxf(moved, a.position.distance_to(post))
	check(moved <= 3.0, "...and holds its ground when an enemy gets close, rather than backing away (%dpx)" % roundi(moved))
	await _fresh()
	a = _hire("archer", post, "guard", 120.0)
	var e = _foe("orc", post + Vector2(0, -(120.0 + Warrior.RADIUS + 14.0 + a.attack_range - 10.0)))
	var furthest := 0.0
	for f in 180:
		await process_frame
		furthest = maxf(furthest, a.position.distance_to(post))
	check(e.hp < e.max_hp and furthest <= 122.0 and furthest >= 20.0, "Archer on Guard Area: steps up within its area until in range, and shoots (%dpx out)" % roundi(furthest))


# --- Special moves stay in the zone ------------------------------------------------------

## A Swordsman's Charge dash (Unstoppable: chaining on as each foe falls), a Martial Artist's
## Shadow Step and its Mirror Self copy, and a Healer going to a hurt ally: none leave the area.
func _specials() -> void:
	await _fresh()
	var post := Vector2(320, 600)
	var sw = _hire("swordsman", post, "guard", 110.0)
	main.selected = sw
	for i in 4:
		main.upgrade_selected(3)   # Charge: Running Strike, then Unstoppable
	main.selected = null
	for p in [Vector2(320, 470), Vector2(250, 490), Vector2(400, 480), Vector2(320, 330), Vector2(140, 420), Vector2(520, 430)]:
		_foe("orc", p, 120.0)
	var far := 0.0
	var dashed := false
	for f in 60 * 10:
		await process_frame
		far = maxf(far, sw.position.distance_to(post))
		dashed = dashed or sw.dash_left > 0.0
	check(not sw.dash.is_empty() and far <= 114.0, "Swordsman with Unstoppable on Guard Area: its dashes stay in the area (furthest %d of 110px%s)" % [roundi(far), ", dashed" if dashed else ""])
	await _fresh()
	var ma = _hire("martial", post, "guard", 110.0)
	main.selected = ma
	main.upgrade_selected(2)
	main.upgrade_selected(2)   # Mirror Self, Shadow Step
	main.selected = null
	for p in [Vector2(320, 460), Vector2(200, 260), Vector2(520, 380)]:
		_foe("orc", p)   # one it can reach from its area (Shadow Step lands inside), two it can't
	far = 0.0
	var copies := 0
	for f in 60 * 10:
		await process_frame
		for w in main.get_warriors():
			if w.kind == "martial":
				far = maxf(far, w.position.distance_to(post))
				if w.clone_of != null:
					copies = maxi(copies, 1)
	check(not ma.teleport.is_empty() and far <= 114.0, "Martial Artist with Shadow Step on Guard Area: never blinks out of it (furthest %d of 110px%s)" % [roundi(far), ", its Mirror Self copy too" if copies > 0 else ""])
	await _fresh()
	var healer = _hire("healer", post, "guard", 80.0)
	var near_ally = _hire("swordsman", post + Vector2(60, -70))
	var far_ally = _hire("swordsman", Vector2(560, 300))
	near_ally.hp = near_ally.max_hp * 0.5
	far_ally.hp = far_ally.max_hp * 0.5
	far = 0.0
	for f in 60 * 4:
		await process_frame
		far = maxf(far, healer.position.distance_to(post))
	# (Both mend a little on their own while idle; only the near one is healed on top.)
	check(near_ally.hp > far_ally.hp + 20.0 and far <= 82.0,
			"Healer on Guard Area: heals the ally it can reach from its area, not one across the field (furthest %dpx)" % roundi(far))


# --- Kept between waves ---------------------------------------------------------------

func _persistence() -> void:
	await _fresh()
	main.wave_active = false
	var w = _hire("swordsman", Vector2(320, 600), "guard", 150.0, "reactive", "weakest")
	main.selected = w
	main.upgrade_selected(0)
	main.upgrade_selected(2)
	main.selected = null
	var keep := [w.move_mode, w.zone_radius(), w.commit, w.priority]
	check(keep == ["guard", 150.0, "reactive", "weakest"] and w.total_upgrades() == 2, "Orders stay through upgrades")
	for i in 2:
		main.start_wave()
		await _frames(5)
		main.spawn_queue.clear()
		for e in main.get_enemies():
			e.free()
		await _frames(90)
	check(main.wave >= 2 and [w.move_mode, w.zone_radius(), w.commit, w.priority] == keep, "...and from wave to wave (now wave %d)" % main.wave)
	var w2 = _hire("swordsman", Vector2(200, 600))
	main.give_order("priority", "weakest", [w2])
	main.give_order("commit", "reactive", [w2])
	# (_hire set Free Roam and Focused, so hire one plainly to see what it starts with.)
	main.placing_type = "swordsman"
	main.hire_at(Vector2(440, 600))
	main.placing_type = ""
	var w3 = main.get_warriors()[-1]
	check(w3.priority == "weakest" and w3.commit == "reactive", "A new hire starts with the orders last given to its kind")
	# The panel: the slider changes the area size, and the box never resets it on opening.
	main.selected = w
	main.hud.refresh(main)
	main.hud.toggle_orders(main)
	check(main.hud.orders_box != null and w.zone_radius() == 150.0, "The orders panel opens on the selected unit without changing its area")
	main.hud.orders_ui["slider"].value = 220.0
	check(w.zone_radius() == 220.0, "...its slider sets the area size (220px)")
	main.hud.orders_ui["move_mode"]["hold"].emit_signal("pressed")
	check(w.move_mode == "hold" and not main.hud.orders_ui["slider"].editable, "...its buttons give orders (Hold: no area to size)")
	main.hud.toggle_orders(main)
	check(main.hud.orders_box == null, "...and O closes it")
