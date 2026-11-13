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
	main.free()
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
