extends CanvasLayer
## Bottom panel (stats, hire buttons, selected warrior), wave messages and end screen.

signal hire_pressed(kind: String)
signal start_wave_pressed
signal upgrade_pressed(path: int)
signal sell_pressed
signal target_pressed
signal orders_pressed
signal song_pressed
signal speed_pressed
signal auto_pressed
signal restart_pressed
signal menu_confirmed
signal mode_chosen(mode: String)
signal freeplay_level_changed(step: int)
signal freeplay_spawn_pressed(kind: String)
signal freeplay_clear_pressed
signal endless_chosen
signal finish_chosen
signal castle_pressed(path: int)
signal ability_pressed(key: String)
signal repair_pressed(chunk: int)
signal power_pressed(key: String)
signal group_kind_pressed(kind: String)
signal campaign_retry
signal campaign_map

const Data = preload("res://scripts/data.gd")
const Warrior = preload("res://scripts/warrior.gd")
const Sprites = preload("res://scripts/sprites.gd")
const Maps = preload("res://scripts/maps.gd")
const CD = preload("res://scripts/campaign_data.gd")
const MapViewer = preload("res://scripts/map_viewer.gd")
const TitleScene = preload("res://scripts/title_scene.gd")
const WorldMap = preload("res://scripts/world_map.gd")
const Story = preload("res://scripts/story.gd")
const Cutscene = preload("res://scripts/cutscene.gd")
const LOCKED_TINT := Color(1, 1, 1, 0.4)
const PATH_KEYS := ["Q", "W", "E", "R"]
const TOP := 768.0
# The panel's tabs: key, label, hotkey.
# (The castle's own upgrades come up when the castle is clicked, not on a tab.)
const TABS := [["troops", "Troops", "Z"], ["emplacements", "Emplacements", "X"],
		["abilities", "Abilities", "V"], ["repair", "Repair", "B"]]
const TAB_W := 108.0
const CONTENT_X := 126.0   # the tabs' contents start right of the tab column
const CONTENT_Y := 50.0
const CONTENT_H := 128.0
const WIDTH := 640.0
const HEIGHT := 1040.0

var gold_label: Label
var lives_label: Label
var wave_label: Label
var speed_btn: Button
var auto_btn: Button
var start_btn: Button
var hire_buttons := {}
var tab_buttons := {}     # "troops" / "emplacements" / "abilities" / "repair"
var castle_cards := []    # the castle's upgrade paths, shown when the castle is clicked
var ability_buttons := {} # the Abilities tab: ability -> its buy / use button
var repair_buttons := []  # the Repair tab: one per Data.REPAIR_CHUNKS
var group_buttons := {}   # a selected group: troop kind -> its button (portrait and count)
var group_shown := ""      # the group's make-up the buttons were laid out for
var power_buttons := {}   # each ability -> its button on the bar in the top-left corner of the field
var hire_tab := "troops"
var last_placing := ""
var info_label: Label
var path_cards := []   # one dict of controls per upgrade path
var sell_btn: Button
var target_btn: Button
var song_btn: Button   # a Bard's switch for the eight-Bard song (only while all eight instruments are out)
var message_label: Label
var message_tween: Tween
var mode_screen: ColorRect
var title_scene: Control   # the castle scene behind the mode cards (changes as cards are hovered)
var hard_label: Label       # shows the difficulty, unless it's Normal (in the campaign: the mission)
var world_map: Control = null   # the campaign map, while it's up
var story: Control = null       # a story scene, while one is playing
var classic_map := ""      # the battlefield picked for Classic ("" = the open meadow)
var battlefields = null    # Classic's battlefield viewer, while it's up
var scene_music := ""       # while a cutscene is up, the music it wants (main plays it)
const VILLAINS := ["ogre", "marshal"]   # speakers whose lines play as cutscenes of their own
var mode_title: Label
var mode_sub: Label
var mode_cards := []            # the title screen's cards now showing
var hire_meta := {}         # kind -> [label, hotkey number, rows] to rebuild hire button text
var price_mult := 1.0
var price_step := 1         # prices are rounded to this many gold (5 on Hard)
var picking := false        # a difficulty card was clicked and its animation is playing
var freeplay_level_label: Label
var freeplay_spawn_buttons := {}
var boss_bar: Control       # the Ogre King's health, across the top of the field
var boss_fill: ColorRect
var ui_w := WIDTH           # screen width the HUD is laid out for (wider on a wide screen; see layout)
var panel: Panel
var menu_btn: Button
var tabs_box := {}          # hire tab -> its buttons are laid out by _layout_hire
var centered := []          # 640-wide overlays kept in the middle of the screen
var freeplay_bar: Panel
var freeplay_clear: Button
var hover_card: PanelContainer   # description of the unit under the mouse
var hover_style: StyleBoxFlat
var hover_title: Label
var hover_sub: Label
var hover_body: Label
var hover_kind := ""        # hire button the card is showing, or "" (field units are shown by main)
const CARD_W := 300.0


func _ready() -> void:
	panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.11, 0.1)
	style.border_color = Color(0.45, 0.35, 0.2)
	style.border_width_top = 3
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(0, TOP)
	panel.size = Vector2(WIDTH, HEIGHT - TOP)
	add_child(panel)

	gold_label = _label(panel, Vector2(12, 11), Vector2(116, 30), Color(1, 0.85, 0.3), 18)
	lives_label = _label(panel, Vector2(130, 12), Vector2(104, 30), Color(1, 0.5, 0.5), 17)
	wave_label = _label(panel, Vector2(238, 11), Vector2(104, 30), Color(0.8, 0.85, 1), 18)
	menu_btn = _button(panel, Vector2(342, 8), Vector2(58, 34), "Menu")
	menu_btn.tooltip_text = "Leave this game and go back to mode select"
	menu_btn.pressed.connect(show_menu_confirm)
	speed_btn = _button(panel, Vector2(404, 8), Vector2(42, 34), "1x")
	speed_btn.add_theme_font_size_override("font_size", 14)
	speed_btn.tooltip_text = "Change game speed [F]"
	speed_btn.pressed.connect(func(): speed_pressed.emit())
	auto_btn = _button(panel, Vector2(450, 8), Vector2(56, 34), "Auto")
	auto_btn.add_theme_font_size_override("font_size", 14)
	auto_btn.toggle_mode = true
	auto_btn.tooltip_text = "Auto-play: start each wave by itself a few seconds after the last one is cleared [A]"
	auto_btn.pressed.connect(func(): auto_pressed.emit())
	start_btn = _button(panel, Vector2(510, 8), Vector2(118, 34), "Start Wave 1")
	start_btn.add_theme_font_size_override("font_size", 14)
	start_btn.tooltip_text = "Send the next wave [Space]"
	start_btn.pressed.connect(func(): start_wave_pressed.emit())

	# The tabs down the left: hiring troops and emplacements, then the castle's own
	# upgrades, its abilities and repairs.
	for i in TABS.size():
		var t: Array = TABS[i]
		var tb := _button(panel, Vector2(12, CONTENT_Y + i * 42.0), Vector2(TAB_W, 38), "%s  [%s]" % [t[1], t[2]])
		tb.add_theme_font_size_override("font_size", 14 if t[0] != "emplacements" else 12)
		tb.tooltip_text = "Show %s [%s]  (Tab cycles through the tabs)" % [t[1].to_lower(), t[2]]
		tb.toggle_mode = true
		tb.pressed.connect(func(): show_tab(t[0]))
		tab_buttons[t[0]] = tb
	for t in ["troops", "emplacements"]:
		for kind in tab_kinds(t):
			var b := _button(panel, Vector2.ZERO, Vector2(10, 10), "")
			b.clip_text = true
			_setup_hire_button(b, kind, Data.WARRIORS[kind])

	for p in Data.CASTLE_PATHS.size():
		var card := _path_card(panel, p)
		card["button"].pressed.disconnect(card["button"].pressed.get_connections()[0]["callable"])
		card["button"].pressed.connect(func(): castle_pressed.emit(p))
		castle_cards.append(card)
	for key in Data.ABILITIES:
		var ab := _button(panel, Vector2.ZERO, Vector2(10, 10), "")
		var col: Color = Data.ABILITIES[key]["color"]
		ab.icon = _power_icon(key, 3)
		ab.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ab.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		ab.add_theme_color_override("font_color", col)
		ab.add_theme_color_override("font_hover_color", col.lightened(0.3))
		ab.add_theme_color_override("font_disabled_color", Color(col, 0.45))
		ab.pressed.connect(func(): ability_pressed.emit(key))
		ab.mouse_entered.connect(func(): _show_ability_card(key, ab))
		ab.mouse_exited.connect(func():
			if hover_kind == "ability:" + key:
				hide_hover())
		ability_buttons[key] = ab
	for i in Data.REPAIR_CHUNKS.size():
		var rb := _button(panel, Vector2.ZERO, Vector2(10, 10), "")
		rb.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
		rb.add_theme_color_override("font_hover_color", Color(0.75, 1.0, 0.75))
		rb.pressed.connect(func(): repair_pressed.emit(i))
		repair_buttons.append(rb)
	for key in Data.ABILITIES:
		power_buttons[key] = _power_button(key)
	for kind in tab_kinds("troops"):
		var gb := _button(panel, Vector2.ZERO, Vector2(10, 10), "")
		gb.icon = Sprites.frames(kind)[0]
		gb.expand_icon = true
		gb.add_theme_constant_override("icon_max_width", 40)
		gb.add_theme_color_override("font_color", Data.WARRIORS[kind]["color"])
		gb.tooltip_text = "Click: keep only these.  Shift+click: drop these from the selection."
		gb.visible = false
		gb.pressed.connect(func(): group_kind_pressed.emit(kind))
		group_buttons[kind] = gb

	for p in PATH_KEYS.size():
		path_cards.append(_path_card(panel, p))

	info_label = _label(panel, Vector2(CONTENT_X, 186), Vector2(500, 76), Color(0.9, 0.9, 0.85), 15)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sell_btn = _button(panel, Vector2(526, 212), Vector2(102, 48), "Sell")
	sell_btn.tooltip_text = "Sell for 60% of everything spent on this unit [S]"
	sell_btn.pressed.connect(func(): sell_pressed.emit())
	target_btn = _button(panel, Vector2(414, 212), Vector2(106, 48), "")
	target_btn.add_theme_font_size_override("font_size", 12)
	target_btn.tooltip_text = ("This unit's orders [O]: which enemy it picks, how firmly it sticks to it,\n"
			+ "and how far from its post it may go to fight.\n"
			+ "T: next target priority.  N: Focused / Reactive.  M: next movement mode.")
	target_btn.pressed.connect(func(): orders_pressed.emit())
	song_btn = _button(panel, Vector2(326, 212), Vector2(84, 48), "")
	song_btn.add_theme_font_size_override("font_size", 12)
	song_btn.tooltip_text = "Every instrument is on the field: play the Bards' song between waves, or not [G]"
	song_btn.pressed.connect(func(): song_pressed.emit())

	message_label = _label(self, Vector2(0, 20), Vector2(WIDTH, 40), Color.WHITE, 28)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 6)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # long warnings take two lines
	message_label.size.y = 80
	message_label.modulate.a = 0.0

	boss_bar = Control.new()
	boss_bar.position = Vector2(120, 64)
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar.visible = false
	add_child(boss_bar)
	var boss_name := _label(boss_bar, Vector2(0, 0), Vector2(400, 22), Color(1, 0.8, 0.35), 16)
	boss_name.text = "THE OGRE KING"
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.add_theme_color_override("font_outline_color", Color.BLACK)
	boss_name.add_theme_constant_override("outline_size", 4)
	var back := ColorRect.new()
	back.color = Color(0.1, 0.05, 0.05, 0.85)
	back.position = Vector2(0, 24)
	back.size = Vector2(400, 12)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar.add_child(back)
	boss_fill = ColorRect.new()
	boss_fill.color = Color(0.85, 0.2, 0.15)
	boss_fill.position = Vector2(2, 26)
	boss_fill.size = Vector2(396, 8)
	boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar.add_child(boss_fill)

	hard_label = _label(self, Vector2(WIDTH - 130, 6), Vector2(120, 24), Color(1, 0.4, 0.35), 16)
	hard_label.text = "HARD MODE"
	hard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hard_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hard_label.add_theme_constant_override("outline_size", 4)
	hard_label.visible = false

	_make_hover_card()
	layout(WIDTH)


## Lays the HUD out for a screen w wide (in game pixels; 640 in a normal window).
## The bottom panel spans the whole width: the counters on the left, the wave
## buttons on the right, and the hire buttons, upgrade cards and info spread
## across; overlays stay 640 wide in the middle.
func layout(w: float) -> void:
	ui_w = maxf(w, WIDTH)
	panel.size = Vector2(ui_w, HEIGHT - TOP)
	start_btn.position.x = ui_w - 130
	auto_btn.position.x = ui_w - 190
	speed_btn.position.x = ui_w - 236
	menu_btn.position.x = ui_w - 298
	sell_btn.position.x = ui_w - 114
	target_btn.position.x = ui_w - 226
	song_btn.position.x = ui_w - 314
	for p in path_cards.size():
		_layout_card(path_cards[p], p)
	_layout_hire()
	message_label.size.x = ui_w
	boss_bar.position.x = (ui_w - 400.0) / 2.0
	hard_label.position.x = ui_w - 130
	for c in centered:
		if is_instance_valid(c):
			c.position.x = (ui_w - WIDTH) / 2.0
	if freeplay_bar:
		_layout_freeplay()


## Hire buttons: one row (name over price) when they fit, two rows of shorter
## buttons with name and price on one line when they don't. Wide buttons show the
## unit's picture too.
func _layout_hire() -> void:
	var avail := ui_w - CONTENT_X - 12.0
	var font := ThemeDB.fallback_font
	for t in ["troops", "emplacements"]:
		var kinds := tab_kinds(t)
		var rows := 1 if kinds.size() <= 6 or avail >= kinds.size() * 92.0 else 2
		var per_row := ceili(kinds.size() / float(rows))
		var w := (avail - 6.0 * (per_row - 1)) / per_row
		if rows == 1:
			w = minf(w, 82.0 if avail < 600.0 else 180.0)
		var h := CONTENT_H if rows == 1 else (CONTENT_H - 6.0) / 2.0
		var with_icon := w >= 110.0
		var icon_w := 48.0 if rows == 1 else 40.0
		for i in kinds.size():
			var kind: String = kinds[i]
			var d: Dictionary = Data.WARRIORS[kind]
			# The room the name really has: the button less its padding, and less the
			# picture and the gap after it when there is one.
			var style: StyleBox = hire_buttons[kind].get_theme_stylebox("normal")
			var room := w - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT) - 4.0
			if with_icon:
				room -= icon_w + hire_buttons[kind].get_theme_constant("h_separation")
			var price := _price_text(d)
			var font_size := 15 if with_icon else (13 if w >= 80.0 else 12)
			var label: String = d["name"]
			var text := "%s  %s [%d]" % [label, price, i + 1]
			if font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
				# Names too wide for the button go on two lines (e.g. "Martial / Artist").
				label = label.replace(" ", "\n")
			text = "%s\n%s  [%d]" % [label, price, i + 1]
			# Then anything still too wide gets a smaller font until it fits.
			var widest := 0.0
			for line in label.split("\n"):
				widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
			while widest > room and font_size > 9:
				widest *= (font_size - 1.0) / font_size
				font_size -= 1
			# And the lines (name, maybe on two, then the price) have to fit its height.
			var lines := label.count("\n") + 2
			var tall := h - style.get_margin(SIDE_TOP) - style.get_margin(SIDE_BOTTOM)
			while lines * font.get_height(font_size) > tall and font_size > 11:
				font_size -= 1
			var b: Button = hire_buttons[kind]
			b.position = Vector2(CONTENT_X + (i % per_row) * (w + 6), CONTENT_Y + (i / per_row) * (h + 6))
			b.size = Vector2(w, h)
			b.text = text
			b.add_theme_font_size_override("font_size", font_size)
			var mounted := Sprites.MOUNT_CREW.has(kind)
			b.icon = (Sprites.mount_icon(kind) if mounted else Sprites.frames(kind)[0]) if with_icon else null
			# The mounted towers' pictures are drawn big and shrunk smoothly onto the button.
			b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if mounted else CanvasItem.TEXTURE_FILTER_PARENT_NODE
			b.expand_icon = with_icon
			b.add_theme_constant_override("icon_max_width", int(icon_w))
			hire_meta[kind] = [label, i + 1, 1]
	# The castle's tabs share the same space: four path cards, a button per ability,
	# a button per repair size.
	for p in castle_cards.size():
		_layout_card(castle_cards[p], p)   # laid out like a unit's upgrade cards
	_row(ability_buttons.values(), avail, 1000.0)
	for ab in ability_buttons.values():
		ab.add_theme_font_size_override("font_size", 13 if ab.size.x >= 96.0 else 12)
		# Tall buttons (one row) show the icon over the name; short ones (two rows) beside it.
		var tall: bool = ab.size.y >= 100.0
		ab.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if tall else HORIZONTAL_ALIGNMENT_LEFT
		ab.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP if tall else VERTICAL_ALIGNMENT_CENTER
	_row(repair_buttons, avail, 1000.0)
	for rb in repair_buttons:
		rb.add_theme_font_size_override("font_size", 15)
	for i in power_buttons.size():
		var pb: Button = power_buttons.values()[i]
		pb.position.y = 6.0


## Lays buttons out in the tab area: one row of up to `max_w` wide buttons when they
## fit at 92 or more each, otherwise two rows.
func _row(buttons: Array, avail: float, max_w: float) -> void:
	var n := buttons.size()
	var rows := 1 if avail >= n * 92.0 else 2
	var per := ceili(n / float(rows))
	var w := minf((avail - 6.0 * (per - 1)) / per, max_w)
	var h := CONTENT_H if rows == 1 else (CONTENT_H - 6.0) / 2.0
	for i in n:
		var b: Button = buttons[i]
		b.position = Vector2(CONTENT_X + (i % per) * (w + 6.0), CONTENT_Y + (i / per) * (h + 6.0))
		b.size = Vector2(w, h)


## Upgrade cards sit in a row across the top of the panel, sharing its width
## (up to 300 each, centred).
func _layout_card(card: Dictionary, p: int) -> void:
	var n := float(path_cards.size())
	var cw := minf((ui_w - 12.0 - 6.0 * n) / n, 300.0)
	var left := (ui_w - (cw * n + 6.0 * (n - 1.0))) / 2.0
	var b: Button = card["button"]
	b.position = Vector2(left + p * (cw + 6.0), CONTENT_Y)
	b.size = Vector2(cw, 104)
	card["title"].size.x = cw - 12.0
	card["cost"].position.x = cw - 76.0
	card["tier"].size.x = cw - 12.0
	card["desc"].size = Vector2(cw - 12.0, 54)
	var wide := cw >= 200.0
	card["tier"].add_theme_font_size_override("font_size", 14 if wide else 13)
	card["desc"].add_theme_font_size_override("font_size", 12)
	card["desc"].max_lines_visible = 3


## A price at this difficulty (see Data.scaled_price).
func _p(base: float) -> int:
	return Data.scaled_price(base, price_mult, price_step)


## Barricades are priced by length, so they show the cheapest.
func _price_text(d: Dictionary) -> String:
	var cost := _p(d["cost"])
	return "%dg+" % cost if d.has("cost_per_100") else "%dg" % cost


## Difficulty changes the prices on the hire buttons.
func set_prices(mult: float, step := 1) -> void:
	price_mult = mult
	price_step = step
	for kind in hire_meta:
		var m: Array = hire_meta[kind]
		var price := _price_text(Data.WARRIORS[kind])
		hire_buttons[kind].text = ("%s\n%s  [%d]" if m[2] == 1 else "%s  %s [%d]") % [m[0], price, m[1]]


func _setup_hire_button(b: Button, kind: String, d: Dictionary) -> void:
	b.toggle_mode = true
	b.mouse_entered.connect(func(): _show_hire_card(kind, b))
	b.mouse_exited.connect(func():
		if hover_kind == kind:
			hide_hover())
	b.add_theme_color_override("font_color", d["color"])
	b.add_theme_color_override("font_hover_color", (d["color"] as Color).lightened(0.3))
	b.pressed.connect(func(): hire_pressed.emit(kind))
	hire_buttons[kind] = b

# --- Hover cards -----------------------------------------------------------

func _make_hover_card() -> void:
	hover_card = PanelContainer.new()
	hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.09, 0.08, 0.07, 0.95)
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(5)
	hover_style.set_content_margin_all(10)
	hover_card.add_theme_stylebox_override("panel", hover_style)
	hover_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_card.visible = false
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	hover_card.add_child(box)
	hover_title = _label(box, Vector2.ZERO, Vector2.ZERO, Color.WHITE, 18)
	hover_sub = _label(box, Vector2.ZERO, Vector2.ZERO, Color(1, 0.85, 0.3), 13)
	hover_body = _label(box, Vector2.ZERO, Vector2.ZERO, Color(0.88, 0.88, 0.84), 13)
	for l in [hover_title, hover_sub, hover_body]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = CARD_W - 20.0
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hover_card)


func _fill_card(title: String, color: Color, sub: String, body: String) -> void:
	hover_title.text = title
	hover_title.add_theme_color_override("font_color", color)
	hover_style.border_color = Color(color, 0.8)
	hover_sub.text = sub
	hover_sub.visible = sub != ""
	hover_body.text = body
	hover_card.size = Vector2.ZERO   # shrink to the new text
	hover_card.visible = true
	hover_card.reset_size()


## Hovering a hire button: what the unit is and does, above the button.
func _show_hire_card(kind: String, b: Button) -> void:
	var d: Dictionary = Data.WARRIORS[kind]
	var sort := "Emplacement" if d.get("emplacement", false) else "Troop"
	var price := "%dg + %dg per %s of wall" % [_p(d["cost_base"]), _p(d["cost_per_100"]), Data.ft(100)] if d.has("cost_per_100") else _price_text(d)
	var body := _plain_desc(d) + "\n\n" + _base_stats(d)
	if d.get("emplacement", false) and not d.has("cost_per_100"):
		body += "\nAn Engineer builds it in %ds; it starts working once it's built." % roundi(Data.BUILD_TIME)
	var names: Array = d["paths"].map(func(path): return path["name"])
	body += "\nUpgrades: " + ", ".join(names)
	hover_kind = kind
	var note: String = get_parent().lock_note(kind) if get_parent().has_method("lock_note") else ""
	_fill_card(d["name"], d["color"], note if note != "" else "%s  -  %s" % [sort, price], body)
	# Just above the panel, lined up with the button.
	hover_card.position = Vector2(clampf(b.global_position.x, 4.0, ui_w - hover_card.size.x - 4.0), TOP - hover_card.size.y - 6.0)


## Hovering a unit on the field (main calls this every frame with the unit under the
## mouse, or null): its description, upgrades and current stats, by the mouse.
func show_unit_card(w, at: Vector2) -> void:
	if w == null:
		if hover_kind == "":
			hover_card.visible = false
		return
	if hover_kind != "":
		return   # a hire button's card is up
	var taken := []
	for p in mini(w.tiers.size(), w.data["paths"].size()):
		if w.tiers[p] > 0:
			var path: Dictionary = w.data["paths"][p]
			taken.append("%s %d/4: %s" % [path["name"], w.tiers[p], path["tiers"][w.tiers[p] - 1]["name"]])
	var sub := "No upgrades yet" if taken.is_empty() else ", ".join(taken)
	_fill_card(w.data["name"], w.data["color"], sub, _plain_desc(w.data) + "\n\n" + w.stats_text())
	var pos := at + Vector2(22, -hover_card.size.y / 2.0)
	if pos.x + hover_card.size.x > ui_w - 4.0:
		pos.x = at.x - 22.0 - hover_card.size.x   # flip to the left of the mouse near the right edge
	pos.y = clampf(pos.y, 4.0, TOP - hover_card.size.y - 4.0)
	hover_card.position = pos


## Hovering the castle: its state, and that clicking it opens its upgrades.
func show_castle_card(main, at: Vector2) -> void:
	if hover_kind != "":
		return
	var body := "HP %d/%d   Takes %d%% less damage\nClick to upgrade its walls, wall archers and mages, and ability power." % [
			ceili(main.castle_hp), roundi(main.castle_max), roundi(main.powers.armor() * 100)]
	_fill_card("Castle", Color(1.0, 0.85, 0.35), "Click to upgrade [C]", body)
	var pos := at + Vector2(22, -hover_card.size.y - 10)
	pos.x = clampf(pos.x, 4.0, ui_w - hover_card.size.x - 4.0)
	pos.y = maxf(pos.y, 4.0)
	hover_card.position = pos


func hide_hover() -> void:
	hover_kind = ""
	hover_card.visible = false


## A unit's description without the "Troop." / "Emplacement." tag (the card says that).
static func _plain_desc(d: Dictionary) -> String:
	var desc: String = d["desc"]
	for tag in ["Troop. ", "Emplacement. "]:
		if desc.begins_with(tag):
			desc = desc.substr(tag.length())
	return desc


## Starting numbers, for the hire card.
static func _base_stats(d: Dictionary) -> String:
	var parts := ["HP %d" % roundi(d["hp"])]
	match d["attack"]:
		"wall":
			parts = ["HP %d, however long" % roundi(d["hp"])]
		"mine":
			parts.append("%dg every %.0fs during waves, %d hauls a wave" % [roundi(d["damage"]), d["cooldown"], d["hauls"]])
		"pulse":
			parts.append("Heals %d every %.0fs" % [roundi(d["damage"]), d["cooldown"]])
			parts.append("Radius %s" % Data.ft(d["range"]))
		"aura":
			parts.append("Radius %s" % Data.ft(d["range"]))
		"heal":
			parts.append("Heals %d every %.1fs" % [roundi(d["damage"]), d["cooldown"]])
			parts.append("Range %s" % Data.ft(d["range"]))
		_:
			parts.append("Damage %d every %.1fs" % [roundi(d["damage"]), d["cooldown"]])
			parts.append("Range %s" % Data.ft(d["range"]))
	if d.get("speed", 0.0) > 0.0:
		parts.append("Speed %s/s" % Data.ft(d["speed"]))
	return "   ".join(parts)


func refresh(main) -> void:
	hard_label.visible = main.started and not main.freeplay and (main.difficulty != "normal" or main.tutorial or main.campaign)
	if hard_label.visible and main.campaign:
		var diff_name: String = Data.DIFFICULTIES[main.difficulty]["name"]
		hard_label.text = (main.mission["name"] as String).to_upper() + ("" if main.difficulty == "normal" else "  ·  " + diff_name.to_upper())
		hard_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	elif hard_label.visible and main.tutorial:
		hard_label.text = "TUTORIAL"
		hard_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.55))
	elif hard_label.visible:
		var diff: Dictionary = Data.DIFFICULTIES[main.difficulty]
		hard_label.text = (diff["name"] as String).to_upper()
		hard_label.add_theme_color_override("font_color", diff["color"])
	var boss = null
	for e in main.get_enemies():
		if e.boss:
			boss = e
	boss_bar.visible = boss != null
	if boss != null:
		boss_fill.size.x = 396.0 * clampf(boss.hp / boss.max_hp, 0.0, 1.0)
		boss_fill.color = Color(1.0, 0.35, 0.1) if boss.enraged else Color(0.85, 0.2, 0.15)
	speed_btn.text = "%dx" % int(Engine.time_scale)
	auto_btn.set_pressed_no_signal(main.auto_play)
	auto_btn.disabled = main.freeplay
	if main.freeplay:
		gold_label.text = "Gold: free"
		lives_label.text = "Freeplay"   # the castle can't fall here
		wave_label.text = "Level %d" % main.freeplay_level
		start_btn.disabled = false
		start_btn.text = "Spawn Wave %d" % main.freeplay_level
		freeplay_level_label.text = "Lv %d" % main.freeplay_level
		for kind in freeplay_spawn_buttons:
			freeplay_spawn_buttons[kind].tooltip_text = "Spawn one %s at level %d" % [kind.capitalize(), main.freeplay_level]
	else:
		gold_label.text = "Gold %d" % main.gold
		lives_label.text = "Castle %d" % ceili(main.castle_hp)
		wave_label.text = "Endless %d" % main.wave if main.endless else "Wave %d/%d" % [main.wave, main.last_wave()]
		start_btn.disabled = main.wave_active or main.game_over or main.choosing
		start_btn.text = "Wave in progress" if main.wave_active else "Start Wave %d" % (main.wave + 1)
		if main.auto_play and not main.wave_active and not main.game_over and not main.choosing:
			start_btn.text = "Wave %d in %ds" % [main.wave + 1, ceili(main.auto_timer)]
	for kind in hire_buttons:
		var b: Button = hire_buttons[kind]
		var cost: int = main.hire_cost(kind)
		var open: bool = main.allowed(kind)
		b.set_pressed_no_signal(main.placing_type == kind)
		b.disabled = main.game_over or not open or (main.gold < cost and main.placing_type != kind)
		b.modulate = Color.WHITE if open else LOCKED_TINT

	# A selected unit swaps the hire row for its upgrade paths (a selected grave shows
	# the paths the fallen unit had, with nothing left to buy).
	var w = main.selected
	var grave = main.selected_grave if w == null and main.placing_type == "" else null
	var castle_sel: bool = main.castle_selected and w == null and grave == null
	var in_group: bool = not main.group.is_empty()
	if in_group:
		grave = null
		castle_sel = false
	# Picking a hire by hotkey jumps to its tab.
	if main.placing_type != last_placing:
		last_placing = main.placing_type
		if last_placing != "":
			hire_tab = tab_of(last_placing)
	for kind in hire_buttons:
		hire_buttons[kind].visible = w == null and grave == null and not castle_sel and not in_group and tab_of(kind) == hire_tab
	if hover_kind != "" and hire_buttons.has(hover_kind) and not hire_buttons[hover_kind].visible:
		hide_hover()
	_refresh_castle(main, w == null and grave == null and not castle_sel and not in_group, castle_sel)
	for t in tab_buttons:
		tab_buttons[t].visible = w == null and grave == null and not castle_sel and not in_group
		tab_buttons[t].set_pressed_no_signal(t == hire_tab)
	_refresh_group(main, in_group)
	for card in path_cards:
		card["button"].visible = w != null or grave != null
	sell_btn.visible = w != null
	target_btn.visible = _takes_orders(w)
	_refresh_orders(main, w)
	song_btn.visible = w != null and w.kind == "bard" and main.all_bards_present()
	if grave != null:
		info_label.position = Vector2(14, 162)
		info_label.size = Vector2(ui_w - 26, 100)
		info_label.add_theme_font_size_override("font_size", 12 if ui_w < 900.0 else 14)
		info_label.text = grave.info_text()
		for p in path_cards.size():
			_grave_card(path_cards[p], grave, p)
		return
	if in_group:
		info_label.position = Vector2(14, CONTENT_Y + CONTENT_H + 8.0)
		info_label.size = Vector2(ui_w - 26, HEIGHT - TOP - CONTENT_Y - CONTENT_H - 12.0)
		info_label.add_theme_font_size_override("font_size", 13 if ui_w < 900.0 else 14)
		info_label.text = "%d troops selected. Right-click to move them together (they keep their formation)%s. Shift+click or Shift+drag to add or remove; click a type above to keep only those, Shift+click to drop them." % [
				main.group.size(), "" if main.wave_active else "; or drag one of them to move the group"]
		return
	if castle_sel:
		info_label.position = Vector2(14, 162)
		info_label.size = Vector2(ui_w - 26, 100)
		info_label.add_theme_font_size_override("font_size", 13 if ui_w < 900.0 else 14)
		var guards := {}
		for g in main.powers.guards:
			guards[g.data["name"]] = guards.get(g.data["name"], 0) + 1
		var on_wall := ", ".join(guards.keys().map(func(k): return "%d %s%s" % [guards[k], k, "s" if guards[k] > 1 else ""]))
		info_label.text = "Castle - every tier of every path can be bought (Q/W/E/R or 1-4). Right-click or Esc to close.\nHP %d/%d   Takes %d%% less damage   On the wall: %s" % [
				ceili(main.castle_hp), roundi(main.castle_max), roundi(main.powers.armor() * 100), on_wall if on_wall != "" else "nobody yet"]
		return
	if w == null:
		info_label.position = Vector2(CONTENT_X, CONTENT_Y + CONTENT_H + 8.0)
		info_label.size = Vector2(ui_w - CONTENT_X - 12.0, HEIGHT - TOP - CONTENT_Y - CONTENT_H - 12.0)
		info_label.add_theme_font_size_override("font_size", 14)
		if main.placing_type == "barricade":
			var d: Dictionary = Data.WARRIORS["barricade"]
			info_label.text = ("Click where the wall starts, then where it ends (%dg + %dg per %s, as long as you can afford). Enemies go around walls if they can. Right-click cancels."
					% [_p(d["cost_base"]), _p(d["cost_per_100"]), Data.ft(100)])
		elif main.placing_type != "":
			info_label.text = "Click the field to post your hire there. Hold Shift to hire several. Right-click cancels."
		elif main.powers.aiming != "":
			info_label.text = "Click the field to cast %s. Right-click cancels." % Data.ABILITIES[main.powers.aiming]["name"]
		elif hire_tab == "abilities":
			info_label.text = "Buy an ability once, then use it from here or the bar in the top-left corner (1-6). It recharges after each use."
		elif hire_tab == "repair" and not main.allowed("repair"):
			info_label.text = main.lock_note("repair") + ". Until then, the castle can't be repaired."
		elif hire_tab == "repair":
			info_label.text = "Castle %d/%d. Masons mend the castle between waves: a full repair from nothing costs %dg, smaller ones their share of that." % [
					ceili(main.castle_hp), roundi(main.castle_max), main.price(Data.REPAIR_FULL_COST)]
		else:
			info_label.text = "Hire warriors to stop enemies reaching the bottom. Click a warrior to select it, or the castle to upgrade it."
		return
	info_label.position = Vector2(14, 162)
	info_label.size = Vector2(ui_w - (332 if song_btn.visible else 244), 100)
	info_label.add_theme_font_size_override("font_size", 12 if ui_w < 900.0 else 14)
	var how := "right-click to send it somewhere" if main.wave_active else "drag to reposition"
	if w.is_emplacement():
		how = "holds its ground" if main.wave_active else "drag to reposition"
	if not w.uses_targeting():
		how += "  (no targeting)"
	info_label.text = "%s - %s   Upgrades %d/%d\n%s" % [w.data["name"], how, w.total_upgrades(), Warrior.MAX_UPGRADES, w.stats_text()]
	sell_btn.text = "Sell +%dg" % w.sell_value()
	target_btn.text = "Orders [O]\n%s" % _orders_short(w)
	info_label.text += "\nOrders: " + orders_summary(w)
	song_btn.text = "Song [G]\n%s" % ("On" if main.song_on else "Off")
	for p in path_cards.size():
		_refresh_card(path_cards[p], w, p, main.gold)


## The group's make-up: a button per kind of troop in it, with a count.
func _refresh_group(main, show: bool) -> void:
	var counts := {}
	if show:
		for g in main.group:
			counts[g.kind] = counts.get(g.kind, 0) + 1
	var key := str(counts)
	for kind in group_buttons:
		var b: Button = group_buttons[kind]
		b.visible = counts.has(kind)
		if b.visible:
			b.text = "%s\nx%d" % [Data.WARRIORS[kind]["name"], counts[kind]]
	if key != group_shown:
		group_shown = key
		var shown := group_buttons.keys().filter(func(k): return counts.has(k)).map(func(k): return group_buttons[k])
		if not shown.is_empty():
			_row(shown, ui_w - CONTENT_X - 12.0 + (CONTENT_X - 12.0), 200.0)
			for b in shown:
				b.position.x -= CONTENT_X - 12.0   # no tabs showing: use the full width
				b.add_theme_font_size_override("font_size", 13)


func _refresh_castle(main, show: bool, castle_sel := false) -> void:
	var powers = main.powers
	if (hover_kind.begins_with("ability:") and hire_tab != "abilities") or not show:
		if hover_kind.begins_with("ability:"):
			hide_hover()
	# Castle paths: like a unit's cards, but every tier can be bought.
	for p in castle_cards.size():
		var card: Dictionary = castle_cards[p]
		var b: Button = card["button"]
		b.visible = castle_sel
		var path: Dictionary = Data.CASTLE_PATHS[p]
		card["title"].text = path["name"]
		for j in Warrior.MAX_TIER:
			card["pips"][j].color = Warrior.PATH_COLORS[p] if j < powers.tiers[p] else Color(1, 1, 1, 0.15)
		var tips := []
		for i in path["tiers"].size():
			var t: Dictionary = path["tiers"][i]
			tips.append("%s (%dg): %s" % [t["name"], powers.tier_cost(p, i), t["desc"]])
		b.tooltip_text = "\n".join(tips)
		var nxt: Dictionary = powers.next_tier(p)
		var path_open: bool = main.allowed("path:%d" % p)
		if not path_open:
			card["tier"].text = path["tiers"][0]["name"]
			card["desc"].text = main.lock_note("path:%d" % p)
			card["cost"].text = "LOCKED"
			card["cost"].add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			b.disabled = true
		elif nxt.is_empty():
			var last: Dictionary = path["tiers"][-1]
			card["tier"].text = last["name"]
			card["desc"].text = last["desc"]
			card["cost"].text = "MAX"
			card["cost"].add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
			b.disabled = true
		else:
			var cost: int = powers.tier_cost(p, powers.tiers[p])
			var ok: bool = main.gold >= cost and not main.game_over
			card["tier"].text = nxt["name"]
			card["desc"].text = nxt["desc"]
			card["cost"].text = "%dg [%d]" % [cost, p + 1]
			card["cost"].add_theme_color_override("font_color", Color(1, 0.85, 0.3) if ok else Color(1, 0.4, 0.35))
			b.disabled = not ok
		b.modulate = Color.WHITE if path_open else LOCKED_TINT
	# Abilities: buy, then use (with the time left to recharge).
	var n := 0
	for key in ability_buttons:
		n += 1
		var b: Button = ability_buttons[key]
		b.visible = show and hire_tab == "abilities"
		var d: Dictionary = Data.ABILITIES[key]
		var ab_open: bool = main.allowed("ability:" + key)
		b.modulate = Color.WHITE if ab_open else LOCKED_TINT
		if not ab_open:
			b.text = "%s\nLocked  [%d]" % [d["name"], n]
			b.disabled = true
		elif not powers.owned.has(key):
			b.text = "%s\n%dg  [%d]" % [d["name"], powers.cost(key), n]
			b.disabled = main.gold < powers.cost(key) or main.game_over
		else:
			var left: float = powers.ready_in(key)
			b.text = "%s\n%s  [%d]" % [d["name"], "%ds" % ceili(left) if left > 0.0 else ("Aiming..." if powers.aiming == key else "Use"), n]
			b.disabled = left > 0.0 or main.game_over
	# Repairs: how much each size mends, and what it costs right now.
	for i in repair_buttons.size():
		var b: Button = repair_buttons[i]
		b.visible = show and hire_tab == "repair"
		var share: float = Data.REPAIR_CHUNKS[i]
		var amount: float = main.repair_amount(i)
		var label := "Full repair" if share >= 1.0 else "Repair %d%%" % roundi(share * 100)
		if share >= 1.0 and main.repair_all_gold():
			label = "Use all gold"
		b.modulate = Color.WHITE if main.allowed("repair") else LOCKED_TINT
		if not main.allowed("repair"):
			b.text = "%s\nLocked\n[%d]" % [label, i + 1]
		elif not main.repair_job.is_empty():
			b.text = "%s\nRepairing...\n%d%% done" % [label, roundi(100.0 * (1.0 - main.repair_job["left"] / main.repair_job["total"]))]
		elif amount < 1.0:
			b.text = "%s\n%s\n[%d]" % [label, "Castle at full" if main.castle_hp >= main.castle_max - 0.5 else "Not enough gold", i + 1]
		elif main.wave_active:
			b.text = "%s\n+%d HP\nafter the wave" % [label, roundi(amount)]
		else:
			b.text = "%s\n+%d HP\n%dg  [%d]" % [label, roundi(amount), main.repair_cost(amount), i + 1]
		b.disabled = not main.can_repair(i)
	# The ability bar, in the top-left corner of the field (above the enemy camp).
	var shown := 0
	for key in power_buttons:
		var pb: Button = power_buttons[key]
		pb.visible = main.started and not main.game_over and powers.owned.has(key)
		if not pb.visible:
			continue
		pb.position.x = 8.0 + shown * 38.0
		shown += 1
		var left: float = powers.ready_in(key)
		var cd: float = powers.recharge(key)
		var shade: ColorRect = pb.get_node("Shade")
		shade.size = Vector2(pb.size.x, pb.size.y * left / cd)
		shade.position.y = pb.size.y - shade.size.y
		var lbl: Label = pb.get_node("Time")
		lbl.text = "%d" % ceili(left) if left > 0.0 else ""
		pb.disabled = left > 0.0
		pb.set_pressed_no_signal(powers.aiming == key)


## A button on the ability bar (top-left of the field), with its icon, a shade that drains as
## it recharges and the seconds left.
func _power_button(key: String) -> Button:
	var d: Dictionary = Data.ABILITIES[key]
	var b := Button.new()
	b.size = Vector2(34, 26)
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.icon = _power_icon(key)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = "%s: %s" % [d["name"], d["desc"]]
	b.visible = false
	b.pressed.connect(func(): power_pressed.emit(key))
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0, 0, 0, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(shade)
	var lbl := _label(b, Vector2(0, 4), Vector2(34, 18), Color.WHITE, 13)
	lbl.name = "Time"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	add_child(b)
	return b


## 12x12 pixel icons for the abilities.
const POWER_ICONS := {
	"arrows": ["..........w.", ".........ww.", "...w....b...", "..ww...b....", ".b....b.....", "b....b......",
		"...bb.......", "..bb....w...", ".b.....ww...", "b.....b.....", "....b.......", "...b........"],
	"fireball": ["........y...", "......yo.y..", ".....oyyo...", "...ooyyyyo..", "..orryyyyo..", ".orrrryyo...",
		".orrroooo...", "rrrrro......", "rrrr........", ".rr.........", "............", "............"],
	"frost": [".....w......", "...w.w.w....", "....www.....", ".w..lwl..w..", "..w.lwl.w...", "wwwwwwwwwww.",
		"..w.lwl.w...", ".w..lwl..w..", "....www.....", "...w.w.w....", ".....w......", "............"],
	"lightning": [".......yy...", "......yy....", ".....yy.....", "....yy......", "...yyyyyy...", "......yy....",
		".....yy.....", "....yy......", "...yy.......", "..y.........", ".y..........", "............"],
	"heal": ["....wwww....", "...wGGGGw...", "...wGLGGw...", "wwwwGLGGwwww", "wGGGGLLGGGGw", "wGLLLLLLLLLw",
		"wGLLLLLLLLLw", "wGGGGLLGGGGw", "wwwwGLGGwwww", "...wGLGGw...", "...wGGGGw...", "....wwww...."],
	"horn": ["............", "..........y.", ".........yy.", "........yyy.", ".......yyyy.", "yy...yyyyyy.",
		"yyyyyyyyyyy.", "yy..yyyyyyy.", ".......yyyy.", "........yyy.", ".........yy.", "..........y."],
}
const ICON_COLORS := {"G": Color(0.45, 0.9, 0.4), "L": Color(0.9, 1.0, 0.75), "w": Color(0.95, 0.95, 1.0), "b": Color(0.6, 0.42, 0.22), "y": Color(1.0, 0.88, 0.3), "o": Color(1.0, 0.55, 0.15),
	"r": Color(0.85, 0.2, 0.1), "l": Color(0.55, 0.85, 1.0), "k": Color(0.35, 0.33, 0.36)}


static func _power_icon(key: String, scale := 2) -> ImageTexture:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rows: Array = POWER_ICONS.get(key, [])
	for y in rows.size():
		for x in (rows[y] as String).length():
			var c: String = rows[y][x]
			if ICON_COLORS.has(c):
				img.set_pixel(x, y, ICON_COLORS[c])
	img.resize(12 * scale, 12 * scale, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## Hovering an ability's button: what it does, with this wave's numbers.
func _show_ability_card(key: String, b: Button) -> void:
	var powers = get_parent().powers
	var d: Dictionary = Data.ABILITIES[key]
	hover_kind = "ability:" + key
	var sub := "Ability  -  %s" % ("Owned" if powers.owned.has(key) else "%dg" % powers.cost(key))
	var note: String = get_parent().lock_note("ability:" + key)
	if note != "":
		sub = note
	var nums := []
	if d.has("damage"):
		nums.append("Damage %d this wave" % roundi(powers.dmg(key)))
	if d.has("radius"):
		nums.append("Radius %s" % Data.ft(powers.radius(key)))
	if d.has("freeze"):
		nums.append("Freeze %.1fs, then %d%% slow for %.0fs" % [d["freeze"], roundi(d["slow"][0] * 100), d["slow"][1]])
	if d.has("chain"):
		nums.append("Up to %d enemies, stun %.1fs" % [d["chain"], d["stun"]])
	if d.has("burn"):
		nums.append("Burns %d/s for %.0fs" % [roundi(d["burn"][0] * powers.power()), d["burn"][1]])
	if key == "heal":
		nums.append("Heals %d%%, revives at %d%%" % [roundi(powers.heal_share() * 100), roundi(powers.revive_share() * 100)])
	if key == "horn":
		var buff: Dictionary = d["buff"]
		nums.append("Now +%d%% damage, %d%% faster attacks, %d%% faster moves" % [roundi(buff["damage"] * powers.boost() * 100),
				roundi(buff["rate"] * powers.boost() * 100), roundi(buff["speed"] * powers.boost() * 100)])
	nums.append("Recharge %ds" % roundi(powers.recharge(key)))
	_fill_card(d["name"], d["color"], sub, d["desc"] + "\n\n" + "   ".join(nums))
	hover_card.position = Vector2(clampf(b.global_position.x, 4.0, ui_w - hover_card.size.x - 4.0), TOP - hover_card.size.y - 6.0)


## The hire tab a unit kind is on.
static func tab_of(kind: String) -> String:
	return "emplacements" if Data.WARRIORS[kind].get("emplacement", false) else "troops"


## Unit kinds in a hire tab, in data order (number keys follow this order).
static func tab_kinds(tab: String) -> Array:
	return Data.WARRIORS.keys().filter(func(k): return tab_of(k) == tab)


func show_tab(tab: String) -> void:
	hire_tab = tab


func _path_card(parent: Node, p: int) -> Dictionary:
	var b := _button(parent, Vector2(12 + p * 156, 48), Vector2(150, 84), "")
	b.pressed.connect(func(): upgrade_pressed.emit(p))
	var card := {"button": b, "pips": []}
	card["title"] = _label(b, Vector2(6, 3), Vector2(138, 20), Warrior.PATH_COLORS[p], 14)
	card["title"].clip_text = true
	card["cost"] = _label(b, Vector2(74, 22), Vector2(70, 16), Color(1, 0.85, 0.3), 13)
	card["cost"].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for j in Warrior.MAX_TIER:
		var pip := ColorRect.new()
		pip.position = Vector2(6 + j * 14, 28)
		pip.size = Vector2(11, 5)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pip)
		card["pips"].append(pip)
	card["tier"] = _label(b, Vector2(6, 38), Vector2(138, 18), Color.WHITE, 13)
	card["tier"].clip_text = true
	card["desc"] = _label(b, Vector2(6, 56), Vector2(138, 44), Color(0.8, 0.8, 0.78), 12)
	card["desc"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card["desc"].max_lines_visible = 2
	card["desc"].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card["desc"].clip_text = true
	return card


func _refresh_card(card: Dictionary, w, p: int, gold: int) -> void:
	var path: Dictionary = w.data["paths"][p]
	var state: String = w.path_state(p)
	var b: Button = card["button"]
	card["title"].text = path["name"]
	for j in Warrior.MAX_TIER:
		card["pips"][j].color = Warrior.PATH_COLORS[p] if j < w.tiers[p] else Color(1, 1, 1, 0.15)
	var tips := []
	for i in path["tiers"].size():
		var t: Dictionary = path["tiers"][i]
		tips.append("%s (%dg): %s" % [t["name"], w.tier_cost(p, i), t["desc"]])
	if path.has("note"):
		tips.append(path["note"])
	b.tooltip_text = "\n".join(tips)
	var affordable := true
	match state:
		"ok":
			var t: Dictionary = w.next_tier(p)
			var cost: int = w.upgrade_cost(p)
			affordable = gold >= cost
			card["tier"].text = t["name"]
			card["desc"].text = t["desc"]
			card["cost"].text = "%dg [%s]" % [cost, PATH_KEYS[p]]
			card["cost"].add_theme_color_override("font_color", Color(1, 0.85, 0.3) if affordable else Color(1, 0.4, 0.35))
		"max":
			card["tier"].text = "Fully upgraded"
			card["desc"].text = ""
			card["cost"].text = ""
		"full":
			card["tier"].text = "Upgrade limit"
			card["desc"].text = "All %d upgrades are in use." % Warrior.MAX_UPGRADES
			card["cost"].text = ""
		"untrained":
			var t: Dictionary = w.next_tier(p)
			card["tier"].text = t["name"]
			card["desc"].text = "Open tier %s of %s for %s at the Training Grounds" % [["I", "II", "III", "IV"][w.tiers[p]], t_path_name(w, p), _trainee_name(w.kind)]
			card["cost"].text = "TRAINING"
			card["cost"].add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	b.disabled = state != "ok" or not affordable
	b.modulate.a = 0.45 if state == "full" or state == "untrained" else 1.0


## A unit kind's name in the plural ("Archers", "Archer Towers").
func _trainee_name(kind: String) -> String:
	var name: String = Data.WARRIORS[kind]["name"]
	return name + ("es" if name.ends_with("ch") else "s")


func t_path_name(w, p: int) -> String:
	return w.data["paths"][p]["name"]


## A fallen unit's path, as it was when it fell: no price, nothing to buy.
func _grave_card(card: Dictionary, grave, p: int) -> void:
	var b: Button = card["button"]
	b.visible = p < grave.path_names.size()
	if not b.visible:
		return
	var bought: Array = grave.tier_names[p]
	card["title"].text = grave.path_names[p]
	for j in Warrior.MAX_TIER:
		card["pips"][j].color = Warrior.PATH_COLORS[p] if j < bought.size() else Color(1, 1, 1, 0.15)
	card["tier"].text = bought[-1] if not bought.is_empty() else "Not taken"
	card["desc"].text = "Fallen - no more upgrades"
	card["cost"].text = ""
	b.tooltip_text = "\n".join(bought) if not bought.is_empty() else ""
	b.disabled = true
	b.modulate.a = 1.0 if not bought.is_empty() else 0.45


func show_message(text: String) -> void:
	message_label.text = text
	if message_tween:
		message_tween.kill()
	message_label.modulate.a = 1.0
	message_tween = create_tween()
	message_tween.tween_interval(1.5)
	message_tween.tween_property(message_label, "modulate:a", 0.0, 0.6)


## The title screen. Cards fly in one after another; hovering lifts a card, and
## picking a mode makes it pulse and burst while the others fall away, then the screen
## fades into the game (Classic and the Campaign open a second set of cards first).
func show_mode_select() -> void:
	picking = false
	mode_screen = ColorRect.new()
	mode_screen.color = Color(0, 0, 0, 0.0)
	mode_screen.size = Vector2(WIDTH, HEIGHT)
	add_child(mode_screen)
	_center(mode_screen)
	# The castle scene, with the title banner drawn on it, fills the screen.
	title_scene = TitleScene.new()
	title_scene.size = Vector2(WIDTH, HEIGHT)
	mode_screen.add_child(title_scene)
	mode_screen.modulate.a = 0.0
	create_tween().tween_property(mode_screen, "modulate:a", 1.0, 0.4)

	var title := _label(mode_screen, Vector2(0, 130), Vector2(WIDTH, 70), Color(1, 0.85, 0.3), 54)
	title.visible = false   # the scene draws the title as pixel art
	title.text = "Hold the Line"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.05))
	title.add_theme_constant_override("outline_size", 8)
	title.pivot_offset = title.size / 2
	title.scale = Vector2(0.4, 0.4)
	title.modulate.a = 0.0
	var tt := create_tween().set_parallel()
	tt.tween_property(title, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tt.tween_property(title, "modulate:a", 1.0, 0.3)
	var sub := _label(mode_screen, Vector2(0, 132), Vector2(WIDTH, 30), Color(1, 1, 1), 18)
	sub.text = "Choose your difficulty"
	sub.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.1))
	sub.add_theme_constant_override("outline_size", 6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate.a = 0.0
	create_tween().tween_property(sub, "modulate:a", 1.0, 0.4).set_delay(0.35)

	mode_title = title
	mode_sub = sub
	_show_cards("top")


## The cards on the title screen. "top": Campaign, Classic, Freeplay, Tutorial,
## Settings; "classic": the battlefields (the meadow, and the campaign's maps: open once
## the campaign reaches them, shown locked till then); "classic_diff": the three
## difficulties on the battlefield picked; "campaign": continue or start one;
## "new": a new campaign's difficulty. Each card is [key, name, text, colour, icon,
## the title scene's look]; a "goto:<set>" key opens another set of cards.
func _show_cards(set_name: String) -> void:
	for c in mode_cards:
		var away := create_tween()
		away.tween_property(c, "modulate:a", 0.0, 0.15)
		away.tween_callback(c.queue_free)
	mode_cards = []
	picking = false
	var modes := []
	var top := [Vector2(20, 636), Vector2(225, 636), Vector2(430, 636)]
	var spots := []
	var back := ["goto:top", "Back", "Back to the\nmain menu", Color(0.8, 0.8, 0.8), "goblin", ""]
	match set_name:
		"top":
			mode_sub.text = "Choose a mode"
			var save_note := "Alliances %d/8 so far" % Campaign.alliance_count() if Campaign.has_save() else "against the\nOgre King"
			modes = [["goto:campaign", "Campaign", "Unite the peoples\nof the continent\n" + save_note, Color(1.0, 0.72, 0.45), "swordsman", "campaign"],
				["goto:classic", "Classic", "Survive 20 waves\nwith every unit,\nthen go endless", Color(0.95, 0.85, 0.45), "archer", "normal"],
				["freeplay", "Freeplay", "Unlimited gold\nSpawn any wave\nor enemy\nThe castle can't fall", Color(0.55, 0.8, 1.0), "mage", "freeplay"],
				["tutorial", "Tutorial", "Learn the basics\nstep by step\nThe castle can't fall", Color(0.75, 1.0, 0.55), "bard", "tutorial"],
				["settings", "Settings", "Music and\nsound effects\nvolume", Color(0.82, 0.84, 0.9), "engineer", "settings"]]
			spots = top + [Vector2(122, 834), Vector2(327, 834)]
		"classic":
			mode_sub.text = "Classic Survival: choose your difficulty"
			for key in Data.DIFFICULTIES:
				modes.append(_difficulty_card(key, "classic:" + key))
			modes.append(back)
			spots = top + [Vector2(225, 834)]
		"campaign":
			mode_sub.text = "Campaign: The Line"
			if Campaign.has_save():
				var diff_name: String = Data.DIFFICULTIES[Campaign.difficulty]["name"]
				modes.append(["campaign:continue", "Continue", "%s\nAlliances %d/8\nBack to the map" % [diff_name, Campaign.alliance_count()], Color(1.0, 0.72, 0.45), "swordsman", "campaign"])
				modes.append(["goto:new", "New", "Start again at\nAshwatch Keep\n(replaces the\nsaved campaign)", Color(0.95, 0.85, 0.45), "engineer", "campaign"])
				spots = [Vector2(122, 636), Vector2(327, 636)]
			else:
				modes.append(["goto:new", "New", "Start at\nAshwatch Keep\nwith a handful\nof swordsmen", Color(1.0, 0.72, 0.45), "swordsman", "campaign"])
				spots = [Vector2(225, 636)]
			modes.append(back)
			spots.append(Vector2(225, 834))
		"new":
			mode_sub.text = "New campaign: choose your difficulty" + ("\n(this replaces your saved campaign)" if Campaign.has_save() else "")
			for key in Data.DIFFICULTIES:
				modes.append(_difficulty_card(key, "campaign:new:" + key))
			modes.append(["goto:campaign", "Back", "Back to the\ncampaign menu", Color(0.8, 0.8, 0.8), "goblin", ""])
			spots = top + [Vector2(225, 834)]
	var cards := []
	for i in modes.size():
		cards.append(_mode_card(modes[i], spots[i], 0.1 + i * 0.07))
	mode_cards = cards.duplicate()
	for i in cards.size():
		var key: String = modes[i][0]
		var card: Button = cards[i]
		if key == "settings":
			card.pressed.connect(func():
				if not picking:
					show_settings())
		elif key.begins_with("classic:"):
			card.pressed.connect(func():
				if not picking:
					show_battlefields(key.substr(8)))
		elif key.begins_with("goto:"):
			card.pressed.connect(func():
				if not picking:
					title_scene.set_look("")
					_show_cards(key.substr(5)))
		else:
			card.pressed.connect(func():
				_pick_mode(key, card, cards, mode_title, mode_sub))


## Classic, after the difficulty: the battlefield viewer. Start goes into the game on the
## battlefield showing ("<difficulty>|<map>", or just the difficulty on the meadow).
func show_battlefields(diff: String) -> void:
	if battlefields != null:
		return
	var v := MapViewer.new()
	v.setup(diff, Campaign.open_maps(), classic_map)
	battlefields = v
	v.start.connect(func(map: String):
		if picking:
			return
		classic_map = map
		picking = true
		fade_through_black(func():
			battlefields = null
			v.queue_free()
			mode_chosen.emit(diff + ("|" + map if map != "" else ""))))
	v.back.connect(func():
		classic_map = v.maps[v.at] if v.open_maps.has(v.maps[v.at]) else classic_map
		battlefields = null
		v.queue_free())
	# It covers the whole screen (not just the 640-wide middle), above the title screen.
	var view := get_viewport().get_visible_rect().size
	v.position = Vector2(-offset.x, -offset.y)
	v.size = view
	add_child(v)


func _battlefield_name(map: String) -> String:
	return "The Meadow" if map == "" else Maps.MAPS[map].get("name", map)


## A difficulty's card (Classic, or a new campaign's), keyed `key`.
func _difficulty_card(diff: String, key: String) -> Array:
	var d: Dictionary = Data.DIFFICULTIES[diff]
	var lines := ["Castle %d HP" % roundi(Data.CASTLE_HP * d["castle"])]
	if d["cost"] < 1.0:
		lines.append("Everything %d%% cheaper" % roundi((1.0 - d["cost"]) * 100))
	elif d["cost"] > 1.0:
		lines.append("Everything %d%% pricier" % roundi((d["cost"] - 1.0) * 100))
	else:
		lines.append("Standard prices")
	lines.append("Fallen troops die after\n%ds unless revived" % int(d["down_time"]) if d["permadeath"] else "Fallen troops get\nback up after %ds" % int(d["down_time"]))
	return [key, d["name"], "\n".join(lines), d["color"], d["icon"], diff]


func _mode_card(m: Array, at: Vector2, delay: float) -> Button:
	var b := _button(mode_screen, at + Vector2(0, 420), Vector2(190, 184), "")
	b.pivot_offset = b.size / 2
	b.modulate.a = 0.0
	var name := _label(b, Vector2(0, 10), Vector2(190, 36), m[3], 28)
	name.text = m[1]
	# Long names (the battlefields) shrink to fit the card.
	var size := 28
	while size > 16 and ThemeDB.fallback_font.get_string_size(m[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > 176.0:
		size -= 1
	name.add_theme_font_size_override("font_size", size)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_color_override("font_outline_color", Color.BLACK)
	name.add_theme_constant_override("outline_size", 4)
	var icon := TextureRect.new()
	icon.texture = m[4] if m[4] is Texture2D else Sprites.frames(m[4])[0]
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = Vector2(48, 48)
	icon.position = Vector2(71, 42)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var desc := _label(b, Vector2(4, 90), Vector2(182, 86), Color(0.85, 0.85, 0.85), 13)   # room for four lines
	desc.text = m[2]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Fly in from below, settling with a little overshoot.
	var t := create_tween().set_parallel()
	t.tween_property(b, "position", at, 0.55).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "modulate:a", 1.0, 0.3).set_delay(delay)
	# The character on the card bobs up and down, each a little out of step.
	var bob := create_tween().set_loops()
	bob.tween_property(icon, "position:y", 37.0, 0.5 + delay * 0.3).set_trans(Tween.TRANS_SINE)
	bob.tween_property(icon, "position:y", 42.0, 0.5 + delay * 0.3).set_trans(Tween.TRANS_SINE)
	icon.tree_exiting.connect(bob.kill)
	# Hovering lifts the card and sets the scene behind for that mode.
	var look: String = m[5] if m.size() > 5 else m[0]
	b.set_meta("look", look)
	b.mouse_entered.connect(func():
		if not picking:
			title_scene.set_look(look)
			create_tween().tween_property(b, "scale", Vector2(1.07, 1.07), 0.12))
	b.mouse_exited.connect(func():
		if not picking:
			title_scene.set_look("")
			create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))
	return b


## The picked card pulses and bursts, the rest fall away, then the screen fades out
## and the game starts.
func _pick_mode(key: String, card: Button, cards: Array, title: Label, sub: Label) -> void:
	if picking:
		return
	picking = true
	title_scene.set_look(card.get_meta("look", key))
	for c in cards:
		c.disabled = c != card
		if c != card:
			var away := create_tween().set_parallel()
			away.tween_property(c, "scale", Vector2(0.6, 0.6), 0.3).set_ease(Tween.EASE_IN)
			away.tween_property(c, "modulate:a", 0.0, 0.3)
	var pulse := create_tween()
	pulse.tween_property(card, "scale", Vector2(1.25, 1.25), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.parallel().tween_property(card, "modulate", Color(1.8, 1.8, 1.8), 0.15)
	pulse.tween_property(card, "scale", Vector2(1.1, 1.1), 0.2)
	pulse.parallel().tween_property(card, "modulate", Color.WHITE, 0.2)
	# Sparks fly out from the card in its color.
	var center := card.position + card.size / 2
	var col: Color = (card.get_child(0) as Label).get_theme_color("font_color")
	for i in 16:
		var spark := ColorRect.new()
		spark.color = col
		spark.size = Vector2(6, 6)
		spark.position = center
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mode_screen.add_child(spark)
		var dir := Vector2.from_angle(i * TAU / 16.0 + randf_range(-0.15, 0.15))
		var fly := create_tween().set_parallel()
		fly.tween_property(spark, "position", center + dir * randf_range(110, 170), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		fly.tween_property(spark, "modulate:a", 0.0, 0.5).set_delay(0.15)
	var out := create_tween()
	out.tween_interval(0.55)
	out.tween_property(title, "modulate:a", 0.0, 0.2)
	out.parallel().tween_property(sub, "modulate:a", 0.0, 0.2)
	out.parallel().tween_property(card, "modulate:a", 0.0, 0.3)
	# Through black into whatever's next, set up out of sight (the field behind the title
	# screen is the meadow, which isn't where every mode is played).
	out.tween_callback(func(): fade_through_black(func(): mode_chosen.emit(key)))


## Fades the whole screen to black, runs `then` (which sets up the next screen out of
## sight), lets the field be painted, and fades back in.
func fade_through_black(then: Callable) -> void:
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.modulate.a = 0.0
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	var view := get_viewport().get_visible_rect().size
	black.position = Vector2(-offset.x, -offset.y) - Vector2(8, 8)
	black.size = view + Vector2(16, 16)
	black.z_index = 100
	add_child(black)
	var t := create_tween()
	t.tween_property(black, "modulate:a", 1.0, 0.3)
	t.tween_callback(then)
	t.tween_callback(func():
		# Still over whatever `then` put up (the map, a cutscene...), and still the whole
		# screen if the field's fitting changed.
		if is_instance_valid(black):
			move_child(black, get_child_count() - 1)
			black.position = Vector2(-offset.x, -offset.y) - Vector2(8, 8)
			black.size = get_viewport().get_visible_rect().size + Vector2(16, 16))
	t.tween_interval(0.12)   # a few frames for the battlefield to be painted
	t.tween_property(black, "modulate:a", 0.0, 0.35)
	t.tween_callback(black.queue_free)


## Sandbox bar along the top of the field: wave level, single-enemy spawns, clear.
func show_freeplay_bar() -> void:
	var bar := Panel.new()
	freeplay_bar = bar
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.85)
	style.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("panel", style)
	bar.position = Vector2(2, 2)
	add_child(bar)
	var minus := _button(bar, Vector2(4, 4), Vector2(28, 30), "-")
	minus.tooltip_text = "Lower the wave level"
	minus.pressed.connect(func(): freeplay_level_changed.emit(-1))
	freeplay_level_label = _label(bar, Vector2(32, 8), Vector2(54, 24), Color(0.55, 0.8, 1.0), 15)
	freeplay_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var plus := _button(bar, Vector2(86, 4), Vector2(28, 30), "+")
	plus.tooltip_text = "Raise the wave level"
	plus.pressed.connect(func(): freeplay_level_changed.emit(1))
	for kind in Data.ENEMIES:
		# Too many enemy types for names to fit: just their pictures (names in the tooltip).
		var b := _button(bar, Vector2.ZERO, Vector2(10, 30), "")
		b.icon = Sprites.frames(kind)[0]
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon = true
		b.pressed.connect(func(): freeplay_spawn_pressed.emit(kind))
		freeplay_spawn_buttons[kind] = b
	freeplay_clear = _button(bar, Vector2.ZERO, Vector2(102, 30), "Clear field")
	freeplay_clear.add_theme_font_size_override("font_size", 13)
	freeplay_clear.pressed.connect(func(): freeplay_clear_pressed.emit())
	_layout_freeplay()


func _layout_freeplay() -> void:
	freeplay_bar.size = Vector2(ui_w - 4, 38)
	freeplay_clear.position = Vector2(ui_w - 114, 4)
	var n := freeplay_spawn_buttons.size()
	var w := minf((ui_w - 238.0 - 3.0 * (n - 1)) / n, 60.0)
	var i := 0
	for kind in freeplay_spawn_buttons:
		var b: Button = freeplay_spawn_buttons[kind]
		b.position = Vector2(120 + i * (w + 3), 4)
		b.size = Vector2(w, 30)
		i += 1


func hide_mode_select() -> void:
	if mode_screen:
		mode_screen.queue_free()
		mode_screen = null


## Keeps a 640-wide overlay in the middle of the screen (and above the hover card).
func _center(c: Control) -> void:
	centered.append(c)
	c.position.x = (ui_w - WIDTH) / 2.0
	hide_hover()


## A copy of a full-screen dim's colour reaching well past the game's 640x960, so
## it also covers the scenery around the field on a wide or tall screen.
func _bleed(dim: ColorRect) -> ColorRect:
	var r := ColorRect.new()
	r.color = dim.color
	r.position = Vector2(-2000, -2000)
	r.size = Vector2(WIDTH + 4000, HEIGHT + 4000)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.show_behind_parent = true
	dim.add_child(r)
	dim.color = Color(0, 0, 0, 0)   # the copy does the dimming, so the middle isn't darkened twice
	return r


## Pauses the game and asks before throwing the current run away.
func show_menu_confirm() -> void:
	get_tree().paused = true
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = Vector2(WIDTH, HEIGHT)
	add_child(dim)
	_center(dim)
	_bleed(dim)
	var title := _label(dim, Vector2(0, 360), Vector2(WIDTH, 40), Color.WHITE, 28)
	title.text = "Return to the menu?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(dim, Vector2(0, 404), Vector2(WIDTH, 26), Color(0.8, 0.8, 0.8), 16)
	sub.text = "This game's progress will be lost."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var leave := _button(dim, Vector2(150, 460), Vector2(160, 50), "Leave game")
	leave.pressed.connect(func():
		get_tree().paused = false
		menu_confirmed.emit())
	var stay := _button(dim, Vector2(330, 460), Vector2(160, 50), "Keep playing")
	stay.pressed.connect(func():
		get_tree().paused = false
		dim.queue_free())
	_volume_sliders(dim, 150.0, 550.0)


## Music and sound effects volume sliders (saved for next time), with a percentage
## beside each. Used by the in-game Menu and the title screen's Settings.
func _volume_sliders(parent: Control, x: float, y0: float) -> void:
	var audio = get_parent().audio
	if audio == null:
		return
	var rows := [["Music", audio.music_volume, audio.set_music_volume], ["Sound effects", audio.sfx_volume, audio.set_sfx_volume]]
	for i in rows.size():
		var y := y0 + i * 48.0
		var l := _label(parent, Vector2(x, y), Vector2(130, 30), Color(0.9, 0.9, 0.85), 17)
		l.text = rows[i][0]
		var slider := HSlider.new()
		slider.position = Vector2(x + 132, y + 4)
		slider.size = Vector2(190, 24)
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = rows[i][1]
		slider.focus_mode = Control.FOCUS_NONE
		var pct := _label(parent, Vector2(x + 330, y), Vector2(56, 30), Color(1, 0.85, 0.3), 16)
		pct.text = "%d%%" % roundi(rows[i][1] * 100)
		var setter: Callable = rows[i][2]
		slider.value_changed.connect(func(v):
			setter.call(v)
			pct.text = "%d%%" % roundi(v * 100))
		if i == 1:
			slider.drag_ended.connect(func(_changed): audio.play("coin"))   # a sample at the new volume
		parent.add_child(slider)


## The title screen's Settings panel: sound volumes, and a button to close it.
func show_settings() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = Vector2(WIDTH, HEIGHT)
	add_child(dim)
	_center(dim)
	_bleed(dim)
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.09, 0.08, 0.96)
	style.border_color = Color(1.0, 0.85, 0.3)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(90, 330)
	panel.size = Vector2(460, 250)
	dim.add_child(panel)
	var title := _label(panel, Vector2(0, 16), Vector2(460, 40), Color(1, 0.85, 0.3), 30)
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(panel, Vector2(30, 66), Vector2(400, 22), Color(0.75, 0.75, 0.72), 14)
	sub.text = "Volume"
	_volume_sliders(panel, 30.0, 96.0)
	var close := _button(panel, Vector2(170, 192), Vector2(120, 42), "Done")
	close.pressed.connect(dim.queue_free)
	panel.scale = Vector2(0.9, 0.9)
	panel.pivot_offset = panel.size / 2
	create_tween().tween_property(panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## After the final wave: stop here with the win, or keep going for a record.
func show_victory_choice(wave: int) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = Vector2(WIDTH, HEIGHT)
	add_child(dim)
	_center(dim)
	_bleed(dim)
	var title := _label(dim, Vector2(0, 300), Vector2(WIDTH, 60), Color(1, 0.85, 0.3), 44)
	title.text = "Victory!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(dim, Vector2(0, 370), Vector2(WIDTH, 60), Color.WHITE, 18)
	sub.text = "You held out through all %d waves.\nKeep going? From here enemies toughen faster, and kills and\nwaves pay a little less each wave - see how far you can get." % wave
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var go := _button(dim, Vector2(110, 460), Vector2(200, 56), "Keep going")
	go.pressed.connect(func():
		dim.queue_free()
		endless_chosen.emit())
	var stop := _button(dim, Vector2(330, 460), Vector2(200, 56), "Finish")
	stop.pressed.connect(func():
		dim.queue_free()
		finish_chosen.emit())


## survived = waves cleared this game; previous = this mode's record before it.
func show_end(won: bool, survived: int, previous: int, endless: bool) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = Vector2(WIDTH, HEIGHT)
	add_child(dim)
	_center(dim)
	_bleed(dim)
	var title := _label(dim, Vector2(0, 320), Vector2(WIDTH, 60),
			Color(1, 0.85, 0.3) if won or endless else Color(1, 0.4, 0.35), 44)
	title.text = "Victory!" if won else ("Endless run over" if endless else "The castle has fallen")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(dim, Vector2(0, 390), Vector2(WIDTH, 30), Color.WHITE, 20)
	if won:
		sub.text = "You held out through all %d waves." % survived
	elif endless:
		sub.text = "You held out through %d waves, %d past the end." % [survived, survived - Data.FINAL_WAVE]
	else:
		sub.text = "You survived %d waves." % survived
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rec := _label(dim, Vector2(0, 424), Vector2(WIDTH, 26), Color(1, 0.85, 0.3), 16)
	rec.text = "New best!" if survived > previous else "Best: %d waves" % previous
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var btn := _button(dim, Vector2(220, 480), Vector2(200, 56), "Play again")
	btn.pressed.connect(func(): restart_pressed.emit())


# --- Campaign ----------------------------------------------------------------

## A story scene over everything; `then` runs once it's over (or skipped).
## A story: the allies' lines in the dialogue box, and the enemy's (the Ogre King's and
## his heralds') each as a cutscene of their own, in order. Esc skips the rest of it.
func play_story(lines: Array, then: Callable = Callable()) -> void:
	if lines.is_empty():
		if then.is_valid():
			then.call()
		return
	# The next run of lines with the same kind of speaker.
	var villain: bool = VILLAINS.has(lines[0]["who"])
	var n := 0
	while n < lines.size() and VILLAINS.has(lines[n]["who"]) == villain:
		n += 1
	var rest := lines.slice(n)
	var next := func(skipped: bool):
		story = null
		if skipped or rest.is_empty():
			if then.is_valid():
				then.call()
		else:
			play_story(rest, then)
	if villain:
		var c := Cutscene.new()
		c.scenes = lines.slice(0, n).map(func(l): return {"scene": l["who"], "who": l["who"], "text": l["text"]})
		story = c
		scene_music = "villain"
		c.finished.connect(func():
			scene_music = ""
			centered.erase(c)
			next.call(c.skipped))
		add_child(c)
		_center(c)
		return
	var s := Story.new()
	s.setup(lines.slice(0, n))
	story = s
	s.finished.connect(func():
		next.call(s.skipped))
	add_child(s)
	_center(s)


## The campaign's prologue cutscene; `then` runs once it's over (or skipped).
func play_prologue(then: Callable) -> void:
	var c := Cutscene.new()
	story = c   # the game takes no input underneath it
	scene_music = "story"
	c.finished.connect(func():
		story = null
		scene_music = ""
		centered.erase(c)
		then.call())
	add_child(c)
	_center(c)


func show_world_map(campaign) -> Control:
	hide_world_map()
	var m := WorldMap.new()
	m.campaign = campaign
	m.ability_icon = func(key): return _power_icon(key, 3)
	m.story_player = play_story
	world_map = m
	add_child(m)
	_center(m)
	return m


func hide_world_map() -> void:
	if world_map:
		centered.erase(world_map)
		world_map.queue_free()
		world_map = null


## A mission is over: won (on to the map, where its story and reward wait) or lost
## (try it again, or go back to the map; nothing is lost either way).
func show_campaign_end(won: bool, mission: Dictionary, survived: int) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = Vector2(WIDTH, HEIGHT)
	add_child(dim)
	_center(dim)
	_bleed(dim)
	var title := _label(dim, Vector2(0, 300), Vector2(WIDTH, 60), Color(1, 0.85, 0.3) if won else Color(1, 0.4, 0.35), 44)
	title.text = "Victory!" if won else "The line has broken"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(dim, Vector2(40, 370), Vector2(WIDTH - 80, 60), Color.WHITE, 18)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if won:
		sub.text = "%s: you held through all %d waves." % [mission["name"], mission["waves"]]
		var go := _button(dim, Vector2(200, 460), Vector2(240, 56), "Continue to the map")
		go.pressed.connect(func(): campaign_map.emit())
	else:
		sub.text = "%s: you held %d of %d waves. Half of what your troops learned still counts; try again." % [mission["name"], survived, mission["waves"]]
		var again := _button(dim, Vector2(110, 460), Vector2(200, 56), "Try again")
		again.pressed.connect(func(): campaign_retry.emit())
		var map_btn := _button(dim, Vector2(330, 460), Vector2(200, 56), "Back to the map")
		map_btn.pressed.connect(func(): campaign_map.emit())
	# What each unit learned: XP earned, and any training points it reached.
	var earned: Array = Campaign.last_battle.keys()
	earned.sort_custom(func(a, b): return Campaign.last_battle[a][0] > Campaign.last_battle[b][0])
	if not earned.is_empty():
		var head := _label(dim, Vector2(0, 540), Vector2(WIDTH, 24), Color(1, 0.85, 0.3), 17)
		head.text = "Experience"
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		for i in mini(earned.size(), 8):
			var kind: String = earned[i]
			var got: Array = Campaign.last_battle[kind]
			var line := _label(dim, Vector2(WIDTH / 2.0 - 240, 570 + i * 24), Vector2(480, 22), Color(0.92, 0.9, 0.85), 15)
			var caught: bool = got.size() > 2 and got[2] > 0.0
			line.text = "%s  +%d XP%s%s" % [Data.WARRIORS[kind]["name"], roundi(got[0]), " (x2 catch-up)" if caught else "",
					"  ·  +%d training point%s!" % [got[1], "" if got[1] == 1 else "s"] if got[1] > 0 else ""]
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if got[1] > 0:
				line.add_theme_color_override("font_color", Color(1, 0.85, 0.3))


func _label(parent: Node, pos: Vector2, size: Vector2, color: Color, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l


func _button(parent: Node, pos: Vector2, size: Vector2, text: String) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = size
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # keep Space/number keys for the game
	parent.add_child(b)
	return b


# --- Orders: the selected unit's target priority, commitment and movement zone ----------

var orders_box: Panel = null
var orders_for = null          # the unit the box was built for
var orders_main = null
var orders_ui := {}            # the box's controls, by name
var orders_syncing := false    # set while the box is brought in step with its unit (its controls' own signals are ignored then)


## A unit's orders in a few words, for the panel's button.
func _orders_short(w) -> String:
	var mode: String = {"hold": "Hold", "short": "Leash", "guard": "Guard", "free": "Free"}[w.move_mode] if not w.is_emplacement() and not w.wall_guard else "Fixed"
	if not w.uses_targeting():
		return mode
	return "%s · %s" % [Warrior.PRIORITY_NAMES[w.priority], mode]


## A unit's orders spelled out (the info line under its stats).
func orders_summary(w) -> String:
	var parts := []
	if w.uses_targeting():
		parts.append(Warrior.PRIORITY_NAMES[w.priority] + " target")
		parts.append(Warrior.COMMIT_NAMES[w.commit])
	if not w.is_emplacement() and not w.wall_guard:
		var mode: String = Warrior.MOVE_NAMES[w.move_mode]
		if w.move_mode in ["short", "guard"]:
			mode += " (%s)" % Data.ft(w.zone_radius())
		parts.append(mode)
	return "  ·  ".join(parts)


## What a unit's orders mean, in a sentence or three.
func orders_meaning(w) -> String:
	var out := ""
	if w.uses_targeting():
		var pick: String = {"closest": "the nearest enemy", "first": "the enemy closest to the castle",
				"strongest": "the toughest kind of enemy", "weakest": "the weakest kind of enemy"}[w.priority]
		out += "Picks %s, " % pick
		out += ("and sees it through: no switching until it falls, gets out of reach or leaves this unit's area. "
				if w.commit == "focused" else "and switches whenever a better one comes along. ")
	if w.is_emplacement() or w.wall_guard:
		out += "Never moves: fights what comes in range."
	else:
		match w.move_mode:
			"hold":
				out += "Stands at its post and fights only what it can reach from there."
			"short", "guard":
				out += "Goes no further than %s from its post to fight, then comes back." % Data.ft(w.zone_radius())
			_:
				out += "Chases enemies anywhere on the field."
		if w.uses_targeting() and w.move_mode != "hold":
			out += " Strikes anything it passes on the way."
	return out


## Whether `w` has orders to give: a targeting unit, or one that moves (a Healer).
func _takes_orders(w) -> bool:
	return w != null and is_instance_valid(w) and w.kind != "barricade" and (w.uses_targeting() or (not w.is_emplacement() and not w.wall_guard))


func toggle_orders(main) -> void:
	if orders_box != null:
		_close_orders()
	elif _takes_orders(main.selected):
		_open_orders(main, main.selected)


func _close_orders() -> void:
	if orders_box != null:
		orders_box.queue_free()
	orders_box = null
	orders_for = null
	orders_ui = {}


func _open_orders(main, w) -> void:
	_close_orders()
	orders_main = main
	orders_for = w
	var box := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.11, 0.1, 0.96)
	style.border_color = Color(0.45, 0.35, 0.2)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_STOP   # clicks on it never reach the field
	box.size = Vector2(456, 272)
	box.position = Vector2(ui_w - box.size.x - 8.0, TOP - box.size.y - 8.0)
	add_child(box)
	orders_box = box
	var title := _label(box, Vector2(12, 8), Vector2(330, 24), Color(1, 0.85, 0.3), 17)
	title.text = "Orders  ·  " + w.data["name"]
	var close := _button(box, Vector2(box.size.x - 40, 8), Vector2(30, 26), "X")
	close.tooltip_text = "Close [O]"
	close.pressed.connect(_close_orders)
	var rows := [
		["Target [T]", "priority", Warrior.PRIORITIES, {"closest": "Closest", "first": "First", "strongest": "Strongest", "weakest": "Weakest"}],
		["Commit [N]", "commit", Warrior.COMMITS, Warrior.COMMIT_NAMES],
		["Movement [M]", "move_mode", Warrior.MOVE_MODES, {"hold": "Hold", "short": "Leash", "guard": "Guard", "free": "Free"}],
	]
	var tips := {"focused": "Sticks to the enemy it picked until it falls, gets out of reach or leaves this unit's area (recommended)",
			"reactive": "Looks again a few times a second and switches to whichever enemy is now the best pick",
			"hold": "Stays at its post and fights only what it can reach from there",
			"short": "Goes a short way from its post to fight (size below)",
			"guard": "Defends a wider area around its post (size below)",
			"free": "Chases enemies anywhere on the field",
			"closest": "The enemy nearest this unit", "first": "The enemy closest to the castle",
			"strongest": "The toughest kind of enemy", "weakest": "The weakest kind of enemy"}
	for r in rows.size():
		var y := 42.0 + r * 36.0
		var lab := _label(box, Vector2(12, y + 4), Vector2(104, 22), Color(0.85, 0.82, 0.76), 13)
		lab.text = rows[r][0]
		var keys: Array = rows[r][2]
		var bw := (box.size.x - 120.0 - 12.0) / keys.size() - 4.0
		var btns := {}
		for i in keys.size():
			var key: String = keys[i]
			var b := _button(box, Vector2(120.0 + i * (bw + 4.0), y), Vector2(bw, 30), rows[r][3][key])
			b.toggle_mode = true
			b.add_theme_font_size_override("font_size", 13)
			b.tooltip_text = tips.get(key, "")
			var field: String = rows[r][1]
			b.pressed.connect(func(): _order_from_box(field, key))
			btns[key] = b
		orders_ui[rows[r][1]] = btns
	var size_lab := _label(box, Vector2(12, 154), Vector2(96, 22), Color(0.85, 0.82, 0.76), 13)
	size_lab.text = "Area size"
	var slider := HSlider.new()
	slider.position = Vector2(120, 156)
	slider.size = Vector2(230, 20)
	slider.step = 5.0
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(v): _order_from_box("leash", v))
	box.add_child(slider)
	orders_ui["slider"] = slider
	orders_ui["size"] = _label(box, Vector2(362, 154), Vector2(84, 22), Color(0.7, 0.95, 1.0), 13)
	var meaning := _label(box, Vector2(12, 186), Vector2(box.size.x - 24, 80), Color(0.9, 0.9, 0.85), 12)
	meaning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	orders_ui["meaning"] = meaning
	_refresh_orders(main, w)


func _order_from_box(field: String, value) -> void:
	if orders_syncing or orders_main == null or orders_for == null or not is_instance_valid(orders_for):
		return
	if field == "leash" and not orders_for.zoned():
		return
	orders_main.give_order(field, value, [orders_for])
	_refresh_orders(orders_main, orders_for)


## Keeps the box in step with its unit (and with orders given by hotkey); follows the
## selection to another unit, and closes when nothing that takes orders is selected.
func _refresh_orders(main, w) -> void:
	if orders_box == null:
		return
	if not _takes_orders(w):
		_close_orders()
		return
	if w != orders_for:
		_open_orders(main, w)
		return
	var fixed: bool = w.is_emplacement() or w.wall_guard
	var current := {"priority": w.priority, "commit": w.commit, "move_mode": w.move_mode}
	for field in current:
		var off: bool = (field == "move_mode" and fixed) or (field != "move_mode" and not w.uses_targeting())
		for key in orders_ui[field]:
			var b: Button = orders_ui[field][key]
			b.set_pressed_no_signal(key == current[field] and not off)
			b.disabled = off
	var slider: HSlider = orders_ui["slider"]
	var lim: Array = Warrior.LEASH_LIMITS.get(w.move_mode, [0.0, 1.0])
	var sized: bool = Warrior.LEASH_LIMITS.has(w.move_mode) and not fixed
	slider.editable = sized
	slider.modulate.a = 1.0 if sized else 0.4
	orders_syncing = true   # (a new range moves the handle, which would otherwise count as an order)
	slider.min_value = lim[0]
	slider.max_value = lim[1]
	slider.set_value_no_signal(w.zone_radius() if sized else lim[0])
	orders_syncing = false
	var size_label: Label = orders_ui["size"]
	size_label.text = Data.ft(w.zone_radius()) if sized else ("at its post" if w.move_mode == "hold" and not fixed else "any distance" if not fixed else "-")
	var meaning: Label = orders_ui["meaning"]
	meaning.text = orders_meaning(w)
