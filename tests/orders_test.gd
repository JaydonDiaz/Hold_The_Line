extends SceneTree
## Unit orders: target commitment (Focused / Reactive), movement zones (Hold, Guard Area:
## a rectangle drawn on the field or picked from the presets, Free Roam), blows struck in
## passing, danger reactions (falling back, calling for help), answering calls, Healers
## getting to the hurt past enemies, and the orders panel for one troop or a group.
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


## A troop posted at `at`, standing there already (no march in from the side). On Guard
## Area with a `size`, its area is a square that far out from its post each way.
func _hire(kind: String, at: Vector2, mode := "free", size := 0.0, commit := "focused", priority := "closest"):
	main.placing_type = kind
	main.hire_at(at)
	main.placing_type = ""
	var w = main.get_warriors()[-1]
	w.position = w.post
	w.max_hp = 1e6
	w.hp = 1e6
	main.give_order("move_mode", mode, [w])
	if size > 0.0:
		main.give_order("area", Rect2(w.post - Vector2.ONE * size, Vector2.ONE * size * 2.0), [w])
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
	await _areas()
	await _danger()
	await _answers()
	await _healers()
	await _group_panel()
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
	# A small area of its own (what Short Leash was).
	await _fresh()
	w = _hire("swordsman", post, "guard", 60.0)
	var c = _foe("orc", Vector2(320, 600 - 60 - Warrior.RADIUS - 14 - 4))
	far = 0.0
	for f in 90:
		await process_frame
		far = maxf(far, w.position.distance_to(post))
	check(w.target == c and c.hp < c.max_hp and far <= 62.0, "A small area (60px each way): fights at its edge and no further (%d px)" % roundi(far))


## How far `w` stands outside its area (0 inside).
func _out(w) -> float:
	return Warrior.rect_gap(w.zone_rect(), w.position)


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
		far = maxf(far, _out(sw))
		dashed = dashed or sw.dash_left > 0.0
	check(not sw.dash.is_empty() and far <= 4.0, "Swordsman with Unstoppable on Guard Area: its dashes stay in the area (at most %dpx out%s)" % [roundi(far), ", dashed" if dashed else ""])
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
				far = maxf(far, Warrior.rect_gap(ma.zone_rect(), w.position))
				if w.clone_of != null:
					copies = maxi(copies, 1)
	check(not ma.teleport.is_empty() and far <= 4.0, "Martial Artist with Shadow Step on Guard Area: never blinks out of it (at most %dpx out%s)" % [roundi(far), ", its Mirror Self copy too" if copies > 0 else ""])
	await _fresh()
	var healer = _hire("healer", post, "guard", 80.0)
	var near_ally = _hire("swordsman", post + Vector2(60, -70))
	var far_ally = _hire("swordsman", Vector2(560, 300))
	near_ally.hp = near_ally.max_hp * 0.5
	far_ally.hp = far_ally.max_hp * 0.5
	far = 0.0
	for f in 60 * 4:
		await process_frame
		far = maxf(far, _out(healer))
	# (Both mend a little on their own while idle; only the near one is healed on top.)
	check(near_ally.hp > far_ally.hp + 20.0 and far <= 4.0,
			"Healer on Guard Area: heals the ally it can reach from its area, not one across the field (at most %dpx out)" % roundi(far))


# --- Kept between waves ---------------------------------------------------------------

func _persistence() -> void:
	await _fresh()
	main.wave_active = false
	var w = _hire("swordsman", Vector2(320, 600), "guard", 150.0, "reactive", "weakest")
	main.selected = w
	main.upgrade_selected(0)
	main.upgrade_selected(2)
	main.selected = null
	var keep := [w.move_mode, w.zone_rect(), w.commit, w.priority, w.danger_mode, w.call_help, w.answer]
	check(keep == ["guard", Rect2(170, 450, 300, 300), "reactive", "weakest", "fight", true, "ignore"] and w.total_upgrades() == 2, "Orders stay through upgrades")
	for i in 2:
		main.start_wave()
		await _frames(5)
		main.spawn_queue.clear()
		for e in main.get_enemies():
			e.free()
		await _frames(90)
	check(main.wave >= 2 and [w.move_mode, w.zone_rect(), w.commit, w.priority, w.danger_mode, w.call_help, w.answer] == keep, "...and from wave to wave (now wave %d)" % main.wave)
	var w2 = _hire("swordsman", Vector2(200, 600))
	main.give_order("priority", "weakest", [w2])
	main.give_order("commit", "reactive", [w2])
	# (_hire set Free Roam and Focused, so hire one plainly to see what it starts with.)
	main.placing_type = "swordsman"
	main.hire_at(Vector2(440, 600))
	main.placing_type = ""
	var w3 = main.get_warriors()[-1]
	check(w3.priority == "weakest" and w3.commit == "reactive", "A new hire starts with the orders last given to its kind")
	# The panel: it opens without changing anything, and its buttons give orders.
	main.selected = w
	main.hud.refresh(main)
	main.hud.toggle_orders(main)
	check(main.hud.orders_box != null and w.zone_rect() == Rect2(170, 450, 300, 300), "The orders panel opens on the selected unit without changing its area")
	main.hud.orders_ui["area"]["left"].emit_signal("pressed")
	check(w.move_mode == "guard" and w.zone_rect() == main.area_preset("left") and main.hud.orders_ui["area"]["left"].button_pressed,
			"...a preset area (Left flank) is given and shown lit")
	main.hud.orders_ui["move_mode"]["hold"].emit_signal("pressed")
	check(w.move_mode == "hold" and not main.hud.orders_ui["area"]["left"].button_pressed, "...Hold: no area lit")
	main.hud.toggle_orders(main)
	check(main.hud.orders_box == null, "...and O closes it")


# --- Guard Areas: drawn on the field, or picked from the presets ---------------------------

func _areas() -> void:
	await _fresh()
	var a = _hire("swordsman", Vector2(120, 650))
	var b = _hire("swordsman", Vector2(180, 650))
	main.group = [a, b]
	main.start_area_pick()
	check(main.area_pick.size() == 2, "Draw area [D]: the group waits for an area to be drawn")
	main.mouse_stand_in = Vector2(300, 300)
	await _frames(2)
	main.area_start = Vector2(300, 300)
	main.mouse_stand_in = Vector2(560, 520)
	await _frames(2)
	main._finish_area()
	main.mouse_stand_in = Vector2.INF
	var drawn := Rect2(300, 300, 260, 220)
	check(a.move_mode == "guard" and b.move_mode == "guard" and a.zone_rect() == drawn and b.zone_rect() == drawn and main.area_pick.is_empty(),
			"...dragging out a rectangle gives them all that area (any size, away from their posts)")
	main.group = []
	# Its post is outside the area: it goes out to fight in the area, and only there.
	var inside = _foe("orc", Vector2(430, 400))
	var by_post = _foe("orc", Vector2(150, 560))
	await _frames(60 * 7)
	check(a.target == inside and inside.hp < inside.max_hp, "It fights an enemy in its area though its post is outside it")
	check(by_post.hp == by_post.max_hp, "...and leaves one by its post alone (not in its area)")
	inside.free()
	await _frames(60 * 7)
	check(a.position.distance_to(a.post) < 6.0, "...then goes back to its post")
	# A small slip of the mouse isn't an area: still waiting.
	main.start_area_pick([a])
	main.mouse_stand_in = Vector2(200, 200)
	await _frames(2)
	main.area_start = Vector2(200, 200)
	main.mouse_stand_in = Vector2(205, 204)
	await _frames(2)
	main._finish_area()
	main.mouse_stand_in = Vector2.INF
	check(a.zone_rect() == drawn and main.area_pick == [a], "A click without a drag doesn't change its area (it's still waiting for one)")
	main._cancel()
	check(main.area_pick.is_empty(), "...Esc stops waiting")
	# Presets cover the field: the flanks overlap the centre, front and back halves meet.
	var l: Rect2 = main.area_preset("left")
	var c: Rect2 = main.area_preset("center")
	var r: Rect2 = main.area_preset("right")
	var front: Rect2 = main.area_preset("front")
	var back: Rect2 = main.area_preset("back")
	check(l.intersects(c) and r.intersects(c) and not l.intersects(r) and l.position.x == 0.0 and is_equal_approx(r.end.x, main.FIELD_W),
			"Preset areas: the left and right flanks reach the edges and overlap the centre, not each other")
	check(is_equal_approx(front.end.y, back.position.y) and front.position.y == main.DEPLOY_TOP and back.end.y == main.CASTLE_Y,
			"...front and back halves split the field from the top down to the castle")
	check(main.area_preset_of(l) == "left" and main.area_preset_of(drawn) == "", "...a preset is recognised as one; a drawn area isn't")


# --- In danger: falling back, calling for help -------------------------------------------

func _danger() -> void:
	await _fresh()
	var w = _hire("swordsman", Vector2(320, 640))
	w.max_hp = 200.0
	w.hp = 200.0
	var e = _foe("orc", Vector2(320, 420))
	await _frames(60 * 2)
	check(not w.in_danger() and not main.calling(w), "Not in danger at full health")
	w.hp = 50.0
	w.take_damage(1.0)
	await _frames(2)
	check(w.in_danger() and main.calling(w), "Badly hurt and hit: in danger, and calling for help (on by default)")
	main.give_order("call_help", false, [w])
	await _frames(int(60 * (main.CALL_LINGER + 0.2)))
	w.take_damage(1.0)
	await _frames(2)
	check(w.in_danger() and not main.calling(w), "...with Call for help off, it doesn't call")
	# Fight on (the default): it keeps fighting.
	check(w.target == e and not w.retreating, "Fight on: it keeps at its enemy")
	# Fall back: it breaks off and makes for the Healer.
	var h = _hire("healer", Vector2(120, 690))
	main.give_order("priority", "heal", [h])
	h.damage = 0.0   # (so it can't mend the swordsman before we've seen it fall back)
	main.give_order("danger_mode", "fall_back", [w])
	w.take_damage(1.0)
	await _frames(60 * 2)
	check(w.retreating and w.target == null and w.position.distance_to(h.position) < 70.0,
			"Fall back: it breaks off and goes to the Healer (%dpx from it)" % roundi(w.position.distance_to(h.position)))
	var e_hp: float = e.hp
	await _frames(60)
	check(e.hp == e_hp, "...and doesn't fight while it's falling back")
	w.hp = w.max_hp * 0.7
	await _frames(10)
	check(not w.retreating, "...mended, it's back in the fight")
	await _frames(60 * 3)
	check(w.target == e, "...and goes back for the enemy")
	# No Healer: it falls back to its post, then rejoins once nothing's come near for a moment.
	h.free()
	main.warriors_changed()
	e.position = Vector2(320, 300)
	w.position = Vector2(320, 340)
	w.hp = 40.0
	w.take_damage(1.0)
	await _frames(5)
	check(w.retreating, "With no Healer about: it falls back")
	var closest := INF
	for f in int(60 * (Warrior.SAFE_TIME + 4.0)):
		await process_frame
		closest = minf(closest, w.position.distance_to(w.post))
	check(not w.retreating and closest < 20.0, "...to its post, and rejoins once no enemy has come near for a moment (got within %dpx of its post)" % roundi(closest))
	# Falling back, a ranged troop keeps shooting whatever's in reach as it goes.
	await _fresh()
	var ar = _hire("archer", Vector2(320, 600))
	ar.position = ar.post
	var foe = _foe("orc", Vector2(320, 470))
	foe.speed = 0.0
	foe.damage = 0.0
	main.give_order("danger_mode", "fall_back", [ar])
	ar.hp = ar.max_hp * 0.2
	ar.take_damage(1.0)
	await _frames(3)
	var foe_hp: float = foe.hp
	var shot_while_back := false
	for f in 60 * 3:
		await process_frame
		if ar.retreating:
			ar.danger_t = 1.0   # (still being hit)
			ar.hp = minf(ar.hp, ar.max_hp * 0.2)
			shot_while_back = shot_while_back or foe.hp < foe_hp
	check(ar.retreating and shot_while_back, "Falling back, an Archer still shoots the enemy in reach as it goes")
	# ...and a Healer keeps mending as it goes: itself, and an ally beside it.
	var hl = _hire("healer", Vector2(320, 640))
	var mate = _hire("swordsman", Vector2(350, 640))
	hl.position = hl.post
	mate.position = mate.post
	mate.hp = mate.max_hp * 0.5
	foe.free()
	var near_foe = _foe("orc", hl.position + Vector2(0, -110))
	near_foe.speed = 0.0
	near_foe.damage = 0.0   # (an enemy about, so it keeps falling back)
	main.give_order("danger_mode", "fall_back", [hl])
	hl.hp = hl.max_hp * 0.2
	hl.take_damage(1.0)
	await _frames(2)
	var was_back: bool = hl.retreating
	var self0: float = hl.hp
	var mate0: float = mate.hp
	for f in 60 * 3:
		await process_frame
		if hl.retreating:
			hl.danger_t = 1.0
	check(was_back and hl.hp > self0, "...a Healer falling back keeps healing: itself, the worst hurt (%.2f%% → %.2f%%)" % [self0 / hl.max_hp * 100.0, hl.hp / hl.max_hp * 100.0])
	mate.hp = mate.max_hp * 0.05
	mate0 = mate.hp
	for f in 60 * 3:
		await process_frame
		if hl.retreating:
			hl.danger_t = 1.0
	check(hl.retreating and mate.hp > mate0, "...and an ally beside it, once that ally's worse off")


# --- Answering calls for help ------------------------------------------------------------

func _answers() -> void:
	for how in ["ignore", "now", "after"]:
		await _fresh()
		var caller = _hire("swordsman", Vector2(100, 600))
		caller.max_hp = 200.0
		caller.hp = 200.0
		var attacker = _foe("orc", caller.position + Vector2(0, -Warrior.RADIUS - 16.0))
		var helper = _hire("swordsman", Vector2(520, 600), "guard")
		main.give_order("area", main.area_preset("right"), [helper])
		main.give_order("answer", how, [helper])
		var own = null
		if how == "after":
			own = _foe("orc", Vector2(520, 520), 100.0)   # its own enemy, in its area
		await _frames(60)
		caller.hp = 40.0
		caller.take_damage(1.0)
		var reached := false
		var hit_own_first := false
		for f in 60 * 10:
			await process_frame
			if caller.is_active() and caller.hp < 60.0:
				caller.danger_t = Warrior.DANGER_HIT   # (still under attack: the call stands)
			if own != null and is_instance_valid(own) and not own.dead and helper.target == attacker:
				hit_own_first = true
			if helper.position.distance_to(attacker.position) < 60.0:
				reached = true
		match how:
			"ignore":
				check(not reached and helper.answering == null, "Answer calls: Ignore: it stays in its area")
			"now":
				check(reached and attacker.hp < attacker.max_hp, "Answer calls: At once: it leaves its area (the right flank) to fight the caller's attacker")
			"after":
				check(how == "after" and (not is_instance_valid(own) or own.dead) and not hit_own_first and reached,
						"Answer calls: After target: it finishes its own enemy first, then goes")
	# The call over (no enemy left at the caller): back to its post and its area.
	await _fresh()
	var c2 = _hire("swordsman", Vector2(100, 600))
	c2.max_hp = 200.0
	var att = _foe("orc", c2.position + Vector2(0, -Warrior.RADIUS - 16.0), 60.0)
	var hl = _hire("swordsman", Vector2(520, 600), "guard")
	main.give_order("area", main.area_preset("right"), [hl])
	main.give_order("answer", "now", [hl])
	c2.hp = 40.0
	c2.take_damage(1.0)
	for f in 60 * 8:
		await process_frame
		if is_instance_valid(att) and not att.dead:
			c2.danger_t = Warrior.DANGER_HIT
	await _frames(60 * 5)
	check((not is_instance_valid(att) or att.dead) and hl.answering == null and hl.position.distance_to(hl.post) < 8.0,
			"...the call answered (its attacker down), it goes back to its post")


# --- Healers: past enemies to the hurt; Allies in danger -------------------------------------

func _healers() -> void:
	# An enemy standing between a Healer and a downed ally: it goes round and revives them
	# (it used to back away from the enemy and never get there).
	await _fresh()
	var h = _hire("healer", Vector2(320, 700))
	var down = _hire("swordsman", Vector2(320, 450))
	var blocker = _foe("orc", Vector2(320, 580))
	down.take_damage(1e9)
	var revived := false
	for f in 60 * 14:
		await process_frame
		if down.is_active():
			revived = true
			break
	check(revived, "Healer: an enemy in the way doesn't stop it reaching and reviving a downed ally")
	# Allies in danger: it crosses the field (out of its area) to the one in danger first.
	await _fresh()
	h = _hire("healer", Vector2(520, 650), "guard", 60.0)
	main.give_order("priority", "danger", [h])
	var hurt = _hire("swordsman", Vector2(560, 600))
	hurt.hp = hurt.max_hp * 0.5
	var danger = _hire("swordsman", Vector2(100, 450))
	danger.max_hp = 300.0
	danger.hp = 80.0
	danger.take_damage(1.0)
	var got_there := false
	for f in 60 * 12:
		await process_frame
		danger.danger_t = Warrior.DANGER_HIT
		if h.position.distance_to(danger.position) < h.attack_range + Warrior.RADIUS * 2.0:
			got_there = true
			break
	check(got_there and h.position.distance_to(danger.position) < h.attack_range + 50.0,
			"Healer on In danger: crosses the field, out of its area, to heal the ally in danger first")


# --- The orders panel for a group ----------------------------------------------------------

func _group_panel() -> void:
	await _fresh()
	main.wave_active = false
	var a = _hire("swordsman", Vector2(200, 600))
	var b = _hire("archer", Vector2(260, 600))
	var h = _hire("healer", Vector2(320, 640))
	main.give_order("priority", "weakest", [a])
	main.selected = null
	main.group = [a, b, h]
	main.hud.refresh(main)
	check(main.hud.target_btn.visible, "A group has an Orders button")
	main.hud.toggle_orders(main)
	var ui: Dictionary = main.hud.orders_ui
	check(main.hud.orders_box != null and main.hud.orders_units.size() == 3 and ui.has("priority") and ui.has("care"),
			"...the panel opens for all three, with a Target row and a Healers row")
	check(not ui["priority"]["weakest"].button_pressed and not ui["priority"]["closest"].button_pressed, "...differing targets: nothing lit in that row")
	ui["priority"]["strongest"].emit_signal("pressed")
	check(a.priority == "strongest" and b.priority == "strongest" and h.priority == "revive" and ui["priority"]["strongest"].button_pressed,
			"...Target goes to the fighters at once (not the Healer)")
	ui["care"]["danger"].emit_signal("pressed")
	check(h.priority == "danger", "...the Healers row goes to the Healer")
	ui["danger_mode"]["fall_back"].emit_signal("pressed")
	ui["answer"]["now"].emit_signal("pressed")
	ui["call_help"].button_pressed = false
	ui["call_help"].emit_signal("pressed")
	check([a, b, h].all(func(w): return w.danger_mode == "fall_back" and not w.call_help) and a.answer == "now" and b.answer == "now",
			"...In danger, Call for help and Answer calls go to them all")
	ui["area"]["center"].emit_signal("pressed")
	check([a, b, h].all(func(w): return w.move_mode == "guard" and w.zone_rect() == main.area_preset("center")), "...and a preset area")
	ui["area"]["draw"].emit_signal("pressed")
	check(main.area_pick.size() == 3, "...Draw waits for an area to be drawn for all three")
	main._cancel()
	main.hud.refresh(main)
	check(main.hud.orders_box == null, "...and with nothing selected the panel closes")
