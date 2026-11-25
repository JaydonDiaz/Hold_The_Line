extends SceneTree
## The text a phone shows: in a touchscreen's words, and all of it fitting. Run from the
## project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/phone_text_test.gd
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.
##
## W  On a touchscreen nothing speaks of the mouse or keys (click, right-click, Shift, Esc,
##    "[S]", "(1-6)"): every troop's and emplacement's card, every ability's, the castle's,
##    a unit's on the field, the panel's help on each tab and while placing or casting, a
##    selected unit's, the castle's, and the buttons (tabs, repairs, abilities, Sell,
##    Orders). In the phone layout and in the desktop one (a phone in a browser whose
##    bars leave it too short for the phone layout).
## F  On phones of every height that get the phone layout (640x1152 to 640x1500), the
##    cards sit above the panel, on the screen, the panel's text is never cut off, and no
##    button's text runs past its edges or makes it grow over its neighbour (hires,
##    abilities, repairs, tabs).
## D  With a mouse nothing changes: the keys and clicks are still there.

var main
var fails := 0
var checks := 0
const MOUSE := ["click", "Click", "Shift", "hover", "Hover", "mouse", "Esc"]
var keys := RegEx.create_from_string("\\[[A-Z0-9][^\\]\\n]{0,3}\\]|\\([0-9]-[0-9]\\)|Q/W/E/R")


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	root.get_node("Campaign").save_path = "user://phone_text_test.cfg"
	_run.call_deferred()


func _run() -> void:
	await _words(true)
	await _words(false)
	for h in [1152, 1200, 1260, 1385, 1500]:
		await _fit(h)
	await _desktop()
	if main != null:
		main.free()
	if FileAccess.file_exists("user://phone_text_test.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://phone_text_test.cfg"))
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## What on a text speaks of the mouse or keys.
func _mouse(t: String) -> Array:
	var found := []
	for w in MOUSE:
		if t.contains(w):
			found.append(w)
	for m in keys.search_all(t):
		found.append(m.get_string())
	return found


func _fresh(phone: bool, h := 1385) -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	main.records_path = ""
	main.missions.pretend_phone = phone
	root.add_child(main)
	await _frames(3)
	main.hud.picking = true
	main.setup.choose_mode("normal")
	main.gold = 99999
	await _frames(2)
	if phone:
		main.hud.layout(640, h, h > 1040)
	await _frames(3)


func _card_text() -> String:
	var hud = main.hud
	return "%s\n%s\n%s" % [hud.hover_title.text, hud.hover_sub.text, hud.hover_body.text]


## Every card, the panel's help and the buttons, gathered as [where, text].
func _texts() -> Array:
	var hud = main.hud
	var out := []
	for kind in hud.hire_buttons:
		hud.show_tab(hud.tab_of(kind))
		await _frames(1)
		hud._show_hire_card(kind, hud.hire_buttons[kind])
		out.append(["%s's card" % kind, _card_text()])
		out.append(["%s's button" % kind, hud.hire_buttons[kind].text])
		hud.hide_hover()
	hud.show_tab("abilities")
	await _frames(2)
	for key in hud.ability_buttons:
		hud._show_ability_card(key, hud.ability_buttons[key])
		out.append(["%s's card" % key, _card_text()])
		out.append(["%s's button" % key, hud.ability_buttons[key].text])
		hud.hide_hover()
	hud.show_castle_card(main, Vector2(320, 700))
	out.append(["the castle's card", _card_text()])
	hud.hide_hover()
	for tab in ["troops", "emplacements", "abilities", "repair"]:
		hud.show_tab(tab)
		await _frames(3)
		out.append(["the help on " + tab, hud.info_label.text])
	for b in hud.repair_buttons:
		out.append(["a repair button", b.text])
	for b in hud.tab_buttons.values() + [hud.count_btn]:
		out.append(["a tab", b.text])
	hud.show_tab("troops")
	for kind in ["swordsman", "barricade"]:
		main.placing_type = kind
		await _frames(3)
		out.append(["the help placing " + kind, hud.info_label.text])
	main.placing_type = ""
	main.powers.owned["lightning"] = true
	main.powers.aiming = "lightning"
	await _frames(3)
	out.append(["the help casting", hud.info_label.text])
	main.powers.aiming = ""
	main.placing_type = "assassin"
	main.hiring.hire_at(Vector2(320, 400))
	main.placing_type = ""
	var ws: Array = main.battlefield.get_warriors()
	if not ws.is_empty():
		main.selected = ws[0]
		await _frames(3)
		out.append(["a selected Assassin", hud.info_label.text])
		out.append(["Sell", hud.sell_btn.text])
		out.append(["Orders", hud.target_btn.text])
		hud.show_unit_card(ws[0], Vector2(320, 400))
		out.append(["an Assassin's card on the field", _card_text()])
		main.selected = null
	main.castle_selected = true
	await _frames(3)
	out.append(["the castle selected", hud.info_label.text])
	main.castle_selected = false
	await _frames(2)
	return out


func _words(phone_layout: bool) -> void:
	await _fresh(true, 1385 if phone_layout else 1040)
	var where := "phone layout" if phone_layout else "desktop layout, on a phone"
	check(main.hud.touch, "W  (%s) the HUD knows it's a touchscreen" % where)
	var texts: Array = await _texts()
	var bad := []
	for t in texts:
		var found := _mouse(t[1])
		if not found.is_empty():
			bad.append("%s: %s" % [t[0], found])
	check(texts.size() > 40, "W  (%s) %d texts looked at" % [where, texts.size()])
	check(bad.is_empty(), "W  (%s) none speaks of the mouse or keys %s" % [where, bad])
	main.placing_type = "swordsman"
	await _frames(3)
	check(main.hud.info_label.text.begins_with("Tap the field"), "W  (%s) placing a hire: \"%s\"" % [where, main.hud.info_label.text])
	main.placing_type = ""
	main.hud.show_tab("abilities")
	main.hud._show_ability_card("lightning", main.hud.ability_buttons["lightning"])
	check(main.hud.hover_body.text.contains("where you tap"), "W  (%s) Thunderstrike strikes where you tap" % where)
	main.hud.hide_hover()


## The lines of a button's text that run past its edges (beside its icon, if any).
func _spills(b: Button) -> Array:
	var font: Font = b.get_theme_font("font")
	var fs: int = b.get_theme_font_size("font_size")
	var style: StyleBox = b.get_theme_stylebox("normal")
	var room := b.size.x - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT)
	if b.icon != null and b.icon_alignment != HORIZONTAL_ALIGNMENT_CENTER:
		var iw := float(b.icon.get_width())
		var most: int = b.get_theme_constant("icon_max_width")
		if most > 0:
			iw = minf(iw, most)
		room -= iw + b.get_theme_constant("h_separation")
	var out := []
	for line in b.text.split("\n"):
		if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room + 0.5:
			out.append(line)
	return out


func _fit(h: int) -> void:
	await _fresh(true, h)
	var hud = main.hud
	var off := []
	for kind in hud.hire_buttons:
		hud.show_tab(hud.tab_of(kind))
		await _frames(1)
		hud._show_hire_card(kind, hud.hire_buttons[kind])
		await _frames(1)
		var r := Rect2(hud.hover_card.position, hud.hover_card.size)
		if r.position.x < 0.0 or r.position.y < 0.0 or r.end.x > hud.ui_w + 0.5 or r.end.y > hud.panel_top + 0.5:
			off.append(kind)
		hud.hide_hover()
	hud.show_tab("abilities")
	await _frames(2)
	for key in hud.ability_buttons:
		hud._show_ability_card(key, hud.ability_buttons[key])
		await _frames(1)
		var r := Rect2(hud.hover_card.position, hud.hover_card.size)
		if r.position.y < 0.0 or r.end.x > hud.ui_w + 0.5 or r.end.y > hud.panel_top + 0.5:
			off.append(key)
		hud.hide_hover()
	check(off.is_empty(), "F  640x%d: every card above the panel, on the screen %s" % [h, off])
	var cut := []
	var il: Label = hud.info_label
	for tab in ["troops", "emplacements", "abilities", "repair"]:
		hud.show_tab(tab)
		await _frames(3)
		if il.get_visible_line_count() < il.get_line_count():
			cut.append(tab)
	hud.show_tab("troops")
	main.placing_type = "barricade"
	await _frames(3)
	if il.get_visible_line_count() < il.get_line_count():
		cut.append("placing a wall")
	main.placing_type = "assassin"
	main.hiring.hire_at(Vector2(320, 400))
	main.placing_type = ""
	main.selected = main.battlefield.get_warriors()[0]
	await _frames(3)
	if il.get_visible_line_count() < il.get_line_count():
		cut.append("a unit selected")
	var small: int = il.get_theme_font_size("font_size")
	main.selected = null
	check(cut.is_empty(), "F  640x%d: the panel's text is never cut off %s" % [h, cut])
	var spill := []
	for tab in ["troops", "emplacements", "abilities", "repair"]:
		hud.show_tab(tab)
		await _frames(3)
		var shown: Array = (hud.hire_buttons.values() + hud.ability_buttons.values() + hud.repair_buttons + hud.tab_buttons.values()).filter(func(b): return b.is_visible_in_tree())
		for b in shown:
			for line in _spills(b):
				spill.append("%s: %s" % [tab, line])
			# (A button too narrow for its text grows to fit it, over its neighbour.)
			var r: Rect2 = b.get_global_rect().grow(-0.5)
			if r.end.x > hud.ui_w:
				spill.append("%s: %s off the screen" % [tab, b.text.get_slice("\n", 0)])
			for o in shown:
				if o != b and o.get_instance_id() > b.get_instance_id() and r.intersects(o.get_global_rect().grow(-0.5)):
					spill.append("%s: %s over %s" % [tab, b.text.get_slice("\n", 0), o.text.get_slice("\n", 0)])
	check(spill.is_empty(), "F  640x%d: no button's text runs past its edges %s" % [h, spill])
	check(small >= 10, "F  640x%d: a selected unit's text is at least 10 (%d)" % [h, small])


func _desktop() -> void:
	await _fresh(false)
	var hud = main.hud
	check(not hud.touch, "D  with a mouse, not a touchscreen")
	await _frames(2)
	check(hud.tab_buttons["troops"].text.contains("[Z]") or hud.tab_buttons["troops"].text.contains("["), "D  the tabs still show their keys (%s)" % hud.tab_buttons["troops"].text)
	main.placing_type = "swordsman"
	await _frames(3)
	check(hud.info_label.text.begins_with("Click the field") and hud.info_label.text.contains("Right-click cancels"), "D  placing a hire still says click and right-click")
	main.placing_type = ""
	hud.show_tab("repair")
	await _frames(3)
	check(hud.repair_buttons[0].text.contains("[1]"), "D  the repair buttons still show their keys")
	hud.show_tab("abilities")
	hud._show_ability_card("lightning", hud.ability_buttons["lightning"])
	check(hud.hover_body.text.contains("where you click"), "D  Thunderstrike still strikes where you click")
	hud.hide_hover()
