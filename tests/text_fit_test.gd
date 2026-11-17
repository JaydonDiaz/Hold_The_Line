extends SceneTree
## Text stays inside its boxes: every unit's upgrade cards (each path, each tier), its info
## lines, the castle's cards and every "New foe" card, laid out as on a desktop and as on a
## phone. A box that would spill shrinks its text to fit (hud._fit_label); on a phone's
## short info box, only the lines that fit show. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/text_fit_test.gd
## Exits 1 if anything spills.

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
	root.get_node("Campaign").started_once = true
	_run.call_deferred()


func _spills(l: Label) -> bool:
	if l.text == "" or not l.is_visible_in_tree():
		return false
	var size: int = l.get_theme_font_size("font_size")
	var shown: float = main.hud._text_height(l, size)
	if l.max_lines_visible > 0:
		shown = minf(shown, l.max_lines_visible * (l.get_theme_font("font").get_height(size) + l.get_theme_constant("line_spacing")))
	return shown > l.size.y + 1.0


func _audit(phone: bool) -> Array:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.pretend_phone = phone
	main._fit_screen()
	main.hud.hide_mode_select()
	main.choose_mode("normal")
	for i in 3:
		await process_frame
	var bad := []
	var x := 120.0
	for kind in Data.WARRIORS:
		if kind == "barricade":
			continue
		main.gold = 999999
		main.placing_type = kind
		main.hire_at(Vector2(x, 560))
		main.placing_type = ""
		x = 120.0 if x > 520.0 else x + 40.0
		var w = main.get_warriors().back()
		w.build_left = 0.0
		main.selected = w
		for p in 4:
			for t in 4:
				w.tiers = [0, 0, 0, 0]
				w.tiers[p] = t
				w._apply_upgrades()
				for i in 2:
					await process_frame
				var card: Dictionary = main.hud.path_cards[p]
				for part in ["desc", "tier"]:
					if _spills(card[part]):
						bad.append("%s %s, path %d tier %d: %s" % [kind, part, p + 1, t + 1, card[part].text])
		if _spills(main.hud.info_label):
			bad.append("%s info" % kind)
		w.queue_free()
		main.selected = null
		for i in 2:
			await process_frame
	main.select_castle()
	for i in 3:
		await process_frame
	for c in main.hud.castle_cards:
		if _spills(c["desc"]):
			bad.append("castle: " + c["desc"].text)
	for k in main.FOE_HINTS:
		main.hud.foe_card = null
		main.hud.show_foe(k, main.FOE_HINTS[k][0], main.FOE_HINTS[k][1])
		await process_frame
		for l in main.hud.foe_card.get_children():
			if l is Label and _spills(l):
				bad.append("New foe %s: %s" % [k, l.text])
	return bad


func _run() -> void:
	var desk: Array = await _audit(false)
	check(desk.is_empty(), "Desktop: every upgrade card, info line, castle card and New foe card keeps its text inside%s" % (
			"" if desk.is_empty() else " (spills: %s)" % "; ".join(desk.slice(0, 4))))
	var phone: Array = await _audit(true)
	check(phone.is_empty(), "Phone: the same, in the phone's smaller boxes%s" % ("" if phone.is_empty() else " (spills: %s)" % "; ".join(phone.slice(0, 4))))
	main.free()
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
