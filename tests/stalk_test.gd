extends SceneTree
## The Assassin stalking his mark. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/stalk_test.gd
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.
##
## V  Seen to stalk: out of the fight with his opener ready he fades (half seen), and near
##    his mark he creeps (slower); once he's struck he's plain to see and back to full pace
## F  Flanking: put in front of a goblin coming down the field, he goes round its side (the
##    quieter one) and comes at it from its flank, not its front; his first blow is the
##    opening strike
## P  The pounce: near an unwary mark he leaps in, and the opening strike follows at once;
##    not at one looking straight at him (he goes round), unless he's run out of patience
## D  The distraction holds: a Warlord at grips with a Knight doesn't turn on the Assassin
##    who's struck it from behind (it goes on fighting the Knight); with the Knight gone,
##    it does

var main
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	root.get_node("Campaign").save_path = "user://stalk_test.cfg"
	_run.call_deferred()


func _run() -> void:
	seed(7)
	await _seen()
	await _flank()
	await _pounce()
	await _distraction()
	if main != null:
		main.free()
	if FileAccess.file_exists("user://stalk_test.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://stalk_test.cfg"))
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
	main.deploying = false
	main.wave_active = true
	await process_frame


func _hire(kind: String, at: Vector2):
	main.placing_type = kind
	main.hiring.hire_at(at)
	main.placing_type = ""
	main.selected = null
	var all: Array = main.battlefield.get_warriors().filter(func(w): return w.kind == kind)
	var w = all[all.size() - 1]
	w.build_left = 0.0
	w.position = w.post
	return w


func _foe(kind: String, at: Vector2, hp := 9999.0):
	main.waves._spawn_enemy(kind, 1, at)
	var e = main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)
	e.max_hp = hp
	e.hp = hp
	return e


# --- V ---

func _seen() -> void:
	await _fresh()
	var a = await _hire("assassin", Vector2(320, 640))
	var g = _foe("goblin", Vector2(320, 300))
	g.speed = 0.0
	a.target = g
	await _frames(30)
	check(a.stalking() and a.stalk_k > 0.9, "V  out of the fight, his opener ready, he stalks: faded (%.2f)" % a.stalk_k)
	var far: bool = a.position.distance_to(g.position) > a.STALK_RANGE
	check(far and a.speed_mult() >= 1.0, "V  ...at full pace while his mark's far off (x%.2f)" % a.speed_mult())
	a.position = g.position + Vector2(0, 120)
	check(is_equal_approx(a.speed_mult(), a.STALK_SPEED), "V  ...creeping once near it (x%.2f)" % a.speed_mult())
	a.since_strike = 0.0   # (he's just struck)
	await _frames(12)
	check(not a.stalking() and a.stalk_k < 0.05 and a.speed_mult() >= 1.0, "V  having struck, he's plain to see (%.2f) and back to full pace" % a.stalk_k)


# --- F ---

func _flank() -> void:
	await _fresh()
	var a = await _hire("assassin", Vector2(320, 600))
	a.move_mode = "free"   # (free to go where his mark leads him)
	var g = _foe("goblin", Vector2(320, 420))
	g.speed = 14.0   # (creeping down, so he can get round it)
	var crowd := []
	for i in 2:
		var o = _foe("goblin", Vector2(258, 400 + i * 30))   # its fellows on its left (his left, looking up the field)
		o.speed = 0.0
		crowd.append(o)
	a.target = g
	a.priority = "valuable"
	var went := 0.0   # which way he went round, by his x (vs the goblin's)
	var blow := 0.0
	var behind_when_struck := false
	var hp0: float = g.hp
	for f in 600:
		await process_frame
		if not is_instance_valid(g):
			break
		a.target = g   # (keep him on this mark)
		if a.position.y < g.position.y + 30.0 and went == 0.0:
			went = signf(a.position.x - g.position.x)
		if g.hp < hp0:
			blow = hp0 - g.hp
			behind_when_struck = (a.position - g.position).normalized().dot(Vector2.DOWN) < 0.5   # (well off its front: its side or its back)
			break
	check(went > 0.0, "F  in front of it, he goes round its quieter side (the right: %s)" % ("right" if went > 0.0 else ("left" if went < 0.0 else "never")))
	check(behind_when_struck, "F  ...and comes at it from its side or behind, not the front")
	check(blow >= a.damage * a._power() * a.SNEAK_OPENER - 0.5, "F  ...his first blow the opening strike (%.0f)" % blow)


# --- P ---

func _pounce() -> void:
	await _fresh()
	var a = await _hire("assassin", Vector2(320, 560))
	var k = await _hire("swordsman", Vector2(120, 640))   # (off to the side: it's only what the goblin's busy with)
	var g = _foe("goblin", Vector2(320, 470))
	g.speed = 0.0
	g.last_foe = k
	g.last_foe_t = 5.0   # (busy with the Knight)
	a.move_mode = "free"
	a.position = g.position + Vector2(0, -62)   # behind it
	a.target = g
	var leapt := false
	var hp0: float = g.hp
	var blow := 0.0
	for f in 40:
		await process_frame
		g.last_foe_t = 5.0
		if a.pounce and a.lunge_left > 0.0:
			leapt = true
		if g.hp < hp0 - 0.01:
			blow = hp0 - g.hp
			break
	check(leapt, "P  near an unwary mark, he pounces")
	check(blow >= a.damage * a._power() * a.SNEAK_OPENER - 0.5, "P  ...and the opening strike follows (%.0f)" % blow)

	await _fresh()
	var b = await _hire("assassin", Vector2(320, 560))
	var h = _foe("goblin", Vector2(320, 500))
	h.speed = 0.0
	h.heading = Vector2.DOWN   # looking straight at him
	b.move_mode = "free"
	b.position = h.position + Vector2(0, 55)
	b.target = h
	check(not b._can_pounce(h), "P  not at a mark looking straight at him...")
	var aim: Vector2 = b._stalk_point(h)
	check(absf(aim.x - h.position.x) > 30.0, "P  ...he goes round it first (heads %s)" % str(aim - h.position))
	b.stalk_near_t = b.STALK_PATIENCE
	check(b._can_pounce(h) and b._stalk_point(h) == h.position, "P  ...unless he's been at it too long: then straight in")


# --- D ---

func _distraction() -> void:
	await _fresh()
	var k = await _hire("swordsman", Vector2(320, 520))
	k.max_hp = 99999.0
	k.hp = k.max_hp
	var w = _foe("warlord", Vector2(320, 470), 99999.0)
	await _frames(90)   # (the Warlord and the Knight come to grips)
	check(w.aggro == k, "D  the Warlord's at grips with the Knight (%s)" % (w.aggro.kind if w.aggro != null else "none"))
	var a = await _hire("assassin", Vector2(320, 600))
	a.move_mode = "free"
	a.max_hp = 99999.0
	a.hp = a.max_hp
	a.position = w.position + Vector2(0, -70)   # behind the Warlord
	a.target = w
	var hp0: float = w.hp
	var struck := false
	var turned := false
	for f in 240:
		await process_frame
		if w.hp < hp0 and a.since_strike < 1.0:
			struck = true
		if struck and w.aggro == a:
			turned = true
	check(struck, "D  the Assassin strikes it from behind")
	check(not turned and w.aggro == k, "D  ...and it doesn't turn on him: it goes on fighting the Knight (%s)" % (w.aggro.kind if w.aggro != null else "none"))
	k.queue_free()
	await _frames(60)
	check(w.aggro == a, "D  with the Knight gone, it turns on the Assassin (%s)" % (w.aggro.kind if w.aggro != null and is_instance_valid(w.aggro) else "none"))
