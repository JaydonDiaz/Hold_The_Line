extends SceneTree
## Drawing only what changed (the phone performance work). Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/redraw_test.gd
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.
##
## C  The castle's stonework is painted once into a picture of its own, the size of the
##    field's width and the wall (at the ground's oversampling), and painted again only
##    when it changes: cracks showing as it's damaged, a new style, a wider field. Not
##    while it merely shakes from a hit.
## W  A wall isn't drawn again every frame while nothing about it changes; it is when hit
##    (the flash, then the flash ending), as its health changes, when upgraded, and every
##    frame once it shimmers (the arcane seam).
## H  The HUD sets its font sizes and colours only when they change (setting one, even to
##    the same, makes the control lay its text out again): a refresh with nothing changed
##    leaves the info text, the Start button and the difficulty label alone; and they
##    still follow what changes (the difficulty label's colour, the info text's size).
## T  The castle cards' tips (every tier and its price) follow the prices.

var main
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	root.get_node("Campaign").save_path = "user://redraw_test.cfg"
	_run.call_deferred()


func _run() -> void:
	seed(5)
	await _castle()
	await _walls()
	await _hud()
	await _tips()
	if main != null:
		main.free()
	if FileAccess.file_exists("user://redraw_test.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://redraw_test.cfg"))
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _fresh(mode := "normal") -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	main.records_path = ""
	root.add_child(main)
	await _frames(3)
	main.hud.picking = true
	main.setup.choose_mode(mode)
	main.gold = 99999
	main.deploying = false
	await _frames(2)


func _castle() -> void:
	await _fresh()
	var c = main.castle
	var paints := [0]
	await _frames(2)
	check(c._bake_vp != null and c._bake_painter != null, "C  the castle's stonework has a picture of its own")
	c._bake_painter.draw.connect(func(): paints[0] += 1)
	var os: int = main.GROUND_OVERSAMPLE
	check(c._bake_vp.size == Vector2i(main.FIELD_W * os, int(main.FIELD_H - main.CASTLE_Y + c.BAKE_RISE) * os),
			"C  the picture spans the field's width and the wall, at the ground's oversampling (%s)" % str(c._bake_vp.size))
	check(c._ci == c, "C  after painting, the stonework helpers draw on the castle again")
	await _frames(30)
	check(paints[0] == 0, "C  not painted again while nothing changes (%d)" % paints[0])
	c.struck(30.0)
	await _frames(10)
	check(paints[0] == 0, "C  a hit shakes it without painting it again (%d)" % paints[0])
	main.castle_hp = main.castle_max * 0.4
	await _frames(3)
	check(paints[0] == 1, "C  painted again when cracks show (%d)" % paints[0])
	await _frames(10)
	check(paints[0] == 1, "C  ...once (%d)" % paints[0])
	c.set_style("frostkeep")
	await _frames(3)
	check(paints[0] >= 2, "C  painted again in a new style (%d)" % (paints[0] - 1))
	var before: int = paints[0]
	main.FIELD_W = 800
	c._drawn_state = Vector3(-1, -1, -1)
	await _frames(3)
	check(paints[0] > before and c._bake_vp.size.x == 800 * os, "C  painted again, wider, for a wider field (%d px)" % c._bake_vp.size.x)
	main.FIELD_W = 640
	c._drawn_state = Vector3(-1, -1, -1)
	await _frames(2)


func _walls() -> void:
	await _fresh()
	main.placing_type = "barricade"
	main.hiring._wall_click(Vector2(200, 400))
	main.hiring._wall_click(Vector2(360, 400))
	main.placing_type = ""
	var walls: Array = main.battlefield.get_barricades()
	check(walls.size() == 1, "W  a wall is built")
	if walls.is_empty():
		return
	var wall = walls[0]
	var draws := [0]
	wall.draw.connect(func(): draws[0] += 1)
	await _frames(5)
	draws[0] = 0
	await _frames(30)
	check(draws[0] == 0, "W  an untouched wall isn't drawn again (%d in 30 frames)" % draws[0])
	wall.take_damage(10.0)
	await _frames(2)
	check(draws[0] >= 1, "W  drawn again when hit (%d)" % draws[0])
	var after_hit: int = draws[0]
	await _frames(12)
	check(draws[0] == after_hit + 1, "W  ...and once more when the flash ends (%d)" % (draws[0] - after_hit))
	draws[0] = 0
	await _frames(20)
	check(draws[0] == 0, "W  then left alone again (%d)" % draws[0])
	main.selected = wall
	main.groups.upgrade_selected(1)
	main.selected = null
	await _frames(2)
	check(draws[0] >= 1, "W  drawn again when upgraded (%d)" % draws[0])
	main.selected = wall
	main.groups.upgrade_selected(3)
	main.selected = null
	await _frames(2)
	draws[0] = 0
	await _frames(20)
	check(draws[0] == 20, "W  with the arcane seam glowing it's drawn every frame (%d of 20)" % draws[0])


func _themes(c: Control, counts: Dictionary, key: String) -> void:
	counts[key] = 0
	c.theme_changed.connect(func(): counts[key] += 1)


func _hud() -> void:
	await _fresh("hard")
	var h = main.hud
	h.layout(640, 1385, true)   # as on a phone held upright
	await _frames(3)
	var counts := {}
	_themes(h.info_label, counts, "info")
	_themes(h.start_btn, counts, "start")
	_themes(h.hard_label, counts, "hard")
	_themes(h.gold_label, counts, "gold")
	await _frames(10)
	check(counts.values().all(func(n): return n == 0), "H  ten frames with nothing changed: no font or colour set again %s" % str(counts))
	check(h.hard_label.visible and h.hard_label.get_theme_color("font_color") == main.Data.DIFFICULTIES["hard"]["color"],
			"H  the difficulty label shows Hard in its colour")
	main.tutorial = true
	await _frames(2)
	check(h.hard_label.get_theme_color("font_color") == Color(0.75, 1.0, 0.55), "H  ...and the Tutorial's colour when it's the Tutorial")
	main.tutorial = false
	main.castle_selected = true
	await _frames(2)
	var sel: int = h.info_label.get_theme_font_size("font_size")
	main.castle_selected = false
	await _frames(2)
	var unsel: int = h.info_label.get_theme_font_size("font_size")
	check(sel == 13 and unsel <= 14 and unsel >= 8, "H  the info text still takes its size from what's shown (castle %d, field %d)" % [sel, unsel])
	h.layout(640, 1040, false)


func _tips() -> void:
	await _fresh("normal")
	var h = main.hud
	await _frames(2)
	var b: Button = h.castle_cards[0]["button"]
	var p0: int = main.powers.tier_cost(0, 0)
	check(b.tooltip_text.contains("(%dg)" % p0), "T  the castle card's tip shows the price (%dg)" % p0)
	main.cost_mult *= 2.0
	await _frames(2)
	var p1: int = main.powers.tier_cost(0, 0)
	check(p1 != p0 and b.tooltip_text.contains("(%dg)" % p1), "T  ...and the new price when prices change (%dg)" % p1)
