extends SceneTree
## The start screen: the splash picture with a Start Game button; silent while it's up,
## and pressing Start leads to the title screen with its music. (Headless runs skip it at
## launch, so this drives it directly.) Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/start_test.gd
## Exits 1 if anything failed.

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
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	main.hud.hide_mode_select()
	var started := [false]
	main.hud.show_splash(func():
		started[0] = true
		main.hud.show_mode_select())
	for i in 10:
		await process_frame
	var buttons: Array = main.hud.splash.find_children("*", "Button", true, false)
	var art: Array = main.hud.splash.get_children().filter(func(c): return c.get_script() == preload("res://scripts/splash_art.gd"))
	check(buttons.size() == 1 and buttons[0].text == "Start Game" and art.size() == 1,
			"The start screen: the animated splash picture and a Start Game button")
	check(main.audio._wanted_track == "", "...silent while it's up")
	buttons[0].emit_signal("pressed")
	for i in 40:
		await process_frame
	check(started[0] and main.hud.splash == null and main.hud.mode_screen != null and main.audio._wanted_track == "title",
			"...Start leads to the title screen, and its music plays (%s)" % main.audio._wanted_track)
	# The title screen shows no game information: the bar's buttons and the castle under it
	# give no cards.
	var hb = main.hud.hire_buttons.values().filter(func(b): return b.visible)[0]
	var shown := []
	hb.emit_signal("mouse_entered")
	shown.append(main.hud.hover_card.visible)
	for key in main.hud.ability_buttons:
		main.hud._show_ability_card(key, main.hud.ability_buttons[key])
		shown.append(main.hud.hover_card.visible)
	main.hud.show_castle_card(main, Vector2(320, 300))
	shown.append(main.hud.hover_card.visible)
	main.hud.show_card_at(["Sigil", Color.WHITE, "", "x"], Vector2(320, 300))
	shown.append(main.hud.hover_card.visible)
	check(not shown.has(true), "The title screen: hovering where the troops, abilities and castle would be shows nothing (%s)" % [shown])
	# On a phone the game is played upright: turned on its side, it waits behind a card.
	main._turn_upright(Vector2(900, 420))
	check(main._upright == null and not paused, "A desktop's wide window is just a wide window")
	main.pretend_phone = true
	main._turn_upright(Vector2(900, 420))
	check(main._upright != null and paused, "A phone turned on its side: the game pauses behind a 'turn it upright' card")
	main._turn_upright(Vector2(420, 900))
	await process_frame
	check(main._upright == null and not paused, "...and turned back upright, it carries on")
	main.pretend_phone = false
	# ...and once a game is under way, the same button shows its card.
	main.choose_mode("normal")
	await process_frame
	hb.emit_signal("mouse_entered")
	check(main.hud.hover_card.visible, "...while in a game, hovering a troop's button shows its card")
	main.free()
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
