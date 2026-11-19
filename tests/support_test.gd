extends SceneTree
## Troops getting round each other, Healers sharing out the fallen, and getting out of
## the way of what's warned. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/support_test.gd
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.
##
## P  Two Healers walking straight at each other get past (each steps to its right)
## R  Two Healers, two fallen: each goes to a different one; while one's being revived its
##    time to die stands still
## D  A troop standing where something warned is about to land (falling stone) runs out of
##    it by itself; a stunned one can't

const Data = preload("res://scripts/data.gd")
var main
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	root.get_node("Campaign").save_path = "user://support_test.cfg"
	_run.call_deferred()


func _run() -> void:
	await _passing()
	await _revives()
	await _dodging()
	if main != null:
		main.free()
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _fresh() -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud.picking = true
	main.choose_mode("normal")
	main.gold = 99999
	await process_frame


func _hire(kind: String, at: Vector2):
	main.placing_type = kind
	main.hire_at(at)
	main.placing_type = ""
	main.selected = null
	var all: Array = main.get_warriors().filter(func(w): return w.kind == kind)
	var w = all[all.size() - 1]
	w.build_left = 0.0
	w.position = w.post
	return w


# --- P ---------------------------------------------------------------------------------------

func _passing() -> void:
	await _fresh()
	var a = await _hire("healer", Vector2(200, 500))
	var b = await _hire("healer", Vector2(440, 500))
	a.order_to(Vector2(440, 500))
	b.order_to(Vector2(200, 500))
	var done := false
	for i in 60 * 8:
		await process_frame
		if a.position.distance_to(Vector2(440, 500)) < 12.0 and b.position.distance_to(Vector2(200, 500)) < 12.0:
			done = true
			break
	check(done, "P  two Healers walking straight at each other get past and reach their posts (%s, %s)" % [a.position, b.position])


# --- R ---------------------------------------------------------------------------------------

func _revives() -> void:
	await _fresh()
	main.permadeath = true
	main.wave_active = true
	var h1 = await _hire("healer", Vector2(300, 600))
	var h2 = await _hire("healer", Vector2(340, 600))
	var k1 = await _hire("swordsman", Vector2(320, 520))
	var k2 = await _hire("swordsman", Vector2(200, 560))
	for k in [k1, k2]:
		k.take_damage(1e6)
	await _frames(2)
	check(not k1.is_active() and not k2.is_active() and k1.down_timer > 0.0, "R  two Knights down")
	await _frames(20)
	check(h1.rez_target != null and h2.rez_target != null and h1.rez_target != h2.rez_target,
			"R  two Healers, two fallen: each goes to a different one")
	# One Healer only, reviving: the fallen one's time stands still meanwhile.
	await _fresh()
	main.permadeath = true
	main.wave_active = true
	var h = await _hire("healer", Vector2(320, 600))
	var k = await _hire("swordsman", Vector2(320, 560))
	var far = await _hire("swordsman", Vector2(560, 300))
	k.take_damage(1e6)
	far.take_damage(1e6)
	await _frames(30)
	var t0: float = k.down_timer
	var t_far: float = far.down_timer
	await _frames(30)
	check(h.rez_target == k and h.rez_progress > 0.0 and is_equal_approx(k.down_timer, t0),
			"R  while a Healer revives it, a fallen troop's time to die stands still (%.2f, was %.2f)" % [k.down_timer, t0])
	check(far.down_timer < t_far, "R  ...the one nobody's reviving yet keeps running out")


# --- D ---------------------------------------------------------------------------------------

func _dodging() -> void:
	await _fresh()
	main.wave_active = true
	var free_one = await _hire("swordsman", Vector2(320, 500))
	var stunned = await _hire("swordsman", Vector2(350, 500))
	stunned.dazed = 99.0
	var fall = load("res://scripts/mission/rules_castle.gd").RockFall.new()
	fall.main = main
	fall.position = Vector2(335, 500)
	fall.damage = 50.0
	main.corpse_layer.add_child(fall)
	var ring: float = fall.RADIUS
	var hp_free: float = free_one.hp
	var hp_stun: float = stunned.hp
	check(main.dangers().size() == 1, "D  falling stone marks where it'll land")
	await _frames(int(60 * 1.6))
	check(free_one.hp == hp_free and free_one.position.distance_to(Vector2(335, 500)) > ring,
			"D  a troop standing under it runs out of the ring by itself and isn't hit")
	check(stunned.hp < hp_stun, "D  ...a stunned one can't, and is")
