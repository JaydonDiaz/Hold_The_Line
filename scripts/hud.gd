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
signal battle_again(key: String)
signal action_pressed
signal contract_pressed   # the Free Cities: sign the contract on offer
signal merc_pressed       # ...hire sellswords
signal menu_confirmed
signal mode_chosen(mode: String)
signal freeplay_level_changed(step: int)
signal freeplay_spawn_pressed(kind: String)
signal freeplay_clear_pressed
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
const Scenarios = preload("res://scripts/mission/scenarios.gd")
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
var foe_card: Panel = null   # a new kind of foe on the field (see show_foe), and the ones waiting their turn
var foe_queue: Array = []
var mode_screen: ColorRect
var title_scene: Control   # the castle scene behind the mode cards (changes as cards are hovered)
var hard_label: Label       # shows the difficulty, unless it's Normal (in the campaign: the mission)
var status_label: Label
var action_btn: Button
var contract_btn: Button   # the Free Cities: sign the contract on offer (contracts.gd)...
var merc_btn: Button       # ...and hire sellswords
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
var boss_name: Label
var ui_w := WIDTH           # screen width the HUD is laid out for (wider on a wide screen; see layout)
var panel: Panel
var menu_btn: Button
var menu_dim: ColorRect = null   # the Menu's "Return to the menu?" box, while it's up
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
			+ "T: next target priority.  M: Hold / Guard area / Free.  D: draw a guard area.")
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
	boss_name = _label(boss_bar, Vector2(0, 0), Vector2(400, 22), Color(1, 0.8, 0.35), 16)
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

	hard_label = _label(self, Vector2(WIDTH - 340, 6), Vector2(330, 24), Color(1, 0.4, 0.35), 16)
	hard_label.text = "HARD MODE"
	hard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hard_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hard_label.add_theme_constant_override("outline_size", 4)
	hard_label.visible = false
	# How the battle stands, for rules that say (objectives left, enemies through).
	status_label = _label(self, Vector2(WIDTH - 340, 30), Vector2(330, 44), Color(1, 0.95, 0.8), 14)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # (a long one goes onto a second line)
	status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	status_label.add_theme_constant_override("outline_size", 4)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.visible = false
	# A battle's own order (Fighting Retreat: Fall back), over the field's top-left corner.
	action_btn = _button(self, Vector2(10, 44), Vector2(170, 40), "")
	action_btn.add_theme_font_size_override("font_size", 15)
	action_btn.tooltip_text = "[Y]"
	action_btn.visible = false
	action_btn.pressed.connect(func(): action_pressed.emit())
	contract_btn = _button(self, Vector2(10, 44), Vector2(250, 32), "")
	contract_btn.add_theme_font_size_override("font_size", 13)
	contract_btn.visible = false
	contract_btn.pressed.connect(func(): contract_pressed.emit())
	merc_btn = _button(self, Vector2(10, 80), Vector2(250, 32), "")
	merc_btn.add_theme_font_size_override("font_size", 13)
	merc_btn.visible = false
	merc_btn.pressed.connect(func(): merc_pressed.emit())

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
	if orders_box != null and orders_box.size.x != ui_w:
		_open_orders(orders_main, orders_units)   # laid out afresh for the new width
	message_label.size.x = ui_w
	boss_bar.position.x = (ui_w - 400.0) / 2.0
	hard_label.position.x = ui_w - 340
	status_label.position.x = ui_w - 340
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
	hard_label.visible = main.started and not main.freeplay and (main.difficulty != "normal" or main.tutorial or main.scripted())
	status_label.text = main.rules.status() if main.started else ""
	status_label.visible = status_label.text != ""
	if hard_label.visible and main.scripted():
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
		boss_name.text = (Data.ENEMIES[boss.kind].get("name", boss.kind.capitalize()) as String).to_upper()
		boss_fill.size.x = 396.0 * clampf(boss.hp / boss.max_hp, 0.0, 1.0)
		boss_fill.color = Color(1.0, 0.35, 0.1) if boss.enraged else Color(0.85, 0.2, 0.15)
	speed_btn.text = "%dx" % int(Engine.time_scale)
	auto_btn.set_pressed_no_signal(main.auto_play)
	auto_btn.disabled = main.freeplay or main.forced_auto
	action_btn.text = main.rules.action_label() if main.started and not main.game_over else ""
	action_btn.visible = action_btn.text != ""
	var deals = main.contracts
	var top := 88.0 if action_btn.visible else 44.0
	contract_btn.text = deals.contract_label() if deals.active() else ""
	contract_btn.visible = contract_btn.text != "" and not main.game_over
	contract_btn.disabled = deals.state != "offered" or not deals.can_sign()
	contract_btn.tooltip_text = deals.contract_tip()
	contract_btn.position.y = top
	merc_btn.text = deals.merc_label() if deals.active() else ""
	merc_btn.visible = merc_btn.text != ""
	merc_btn.disabled = not deals.can_hire()
	merc_btn.tooltip_text = deals.merc_tip()
	merc_btn.position.y = top + (36.0 if contract_btn.visible else 0.0)
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
		lives_label.text = "Castle %d" % ceili(main.castle_hp) if main.rules.has_castle() else main.rules.panel_status()
		# A castle about to fall: its health pulses.
		var low: bool = main.rules.has_castle() and not main.game_over and main.castle_hp <= main.castle_max * 0.25
		lives_label.modulate = Color(1, 1, 1).lerp(Color(1.6, 0.6, 0.6), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 130.0)) if low else Color.WHITE
		wave_label.text = main.rules.wave_text()
		start_btn.disabled = main.wave_active or main.game_over
		start_btn.text = "Wave in progress" if main.wave_active else "Start Wave %d" % (main.wave + 1)
		var next_in: float = main.next_wave_in()
		if next_in >= 0.0 and not main.game_over:
			if main.deploying:
				start_btn.text = "Deploy: %ds" % ceili(next_in)
			elif main.forced_auto and not main.wave_active:
				start_btn.text = "Rest: wave %d in %ds" % [main.wave + 1, ceili(next_in)]
			else:
				start_btn.text = "Wave %d in %ds" % [main.wave + 1, ceili(next_in)]
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
		tab_buttons[t].visible = w == null and grave == null and not castle_sel and not in_group and (t != "repair" or main.rules.has_castle())
		tab_buttons[t].set_pressed_no_signal(t == hire_tab)
	_refresh_group(main, in_group)
	for card in path_cards:
		card["button"].visible = w != null or grave != null
	sell_btn.visible = w != null
	target_btn.visible = _takes_orders(w) or (in_group and main.group.any(_takes_orders))
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
		info_label.size = Vector2(ui_w - (26 if not target_btn.visible else ui_w - target_btn.position.x + 8.0), HEIGHT - TOP - CONTENT_Y - CONTENT_H - 12.0)
		info_label.add_theme_font_size_override("font_size", 13 if ui_w < 900.0 else 14)
		info_label.text = "%d troops selected. Right-click to move them together (they keep their formation)%s. Shift+click or Shift+drag to add or remove; click a type above to keep only those, Shift+click to drop them." % [
				main.group.size(), "" if main.wave_active else "; or drag one of them to move the group"]
		target_btn.text = "Orders [O]\n%d troops" % main.group.filter(_takes_orders).size()
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
			info_label.text = "Hire warriors to stop enemies reaching the bottom. Click a warrior to select it, or the castle to upgrade it." if main.rules.has_castle() \
					else ("Hire warriors to protect the objectives: the enemy is after them. Click a warrior to select it." if main.rules.guards() \
					else "Hire warriors to stop enemies getting past your camp at the bottom. Click a warrior to select it.")
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
	# (Under the battle's status line in the corner, where there is one, not over it.)
	var m = get_parent()
	message_label.position.y = 78.0 if m != null and m.has_method("scripted") and m.started and m.scripted() and m.rules != null and m.rules.status() != "" else 20.0
	if message_tween:
		message_tween.kill()
	message_label.modulate.a = 1.0
	message_tween = create_tween()
	message_tween.tween_interval(1.5)
	message_tween.tween_property(message_label, "modulate:a", 0.0, 0.6)


## Introduces a kind of foe the first time it comes on: a small card in the field's
## top corner with its picture, its name and a tip. Several at once take turns.
func show_foe(kind: String, title: String, tip: String) -> void:
	if foe_card != null:
		foe_queue.append([kind, title, tip])
		return
	foe_card = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.07, 0.85)
	style.border_color = Color(0.75, 0.3, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	foe_card.add_theme_stylebox_override("panel", style)
	foe_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foe_card.size = Vector2(262, 60)
	var below := 100.0   # (under the Free Cities' deal buttons, when they're up)
	for b in [contract_btn, merc_btn]:
		if b != null and b.visible:
			below = maxf(below, b.position.y + b.size.y + 8.0)
	foe_card.position = Vector2(-270, below)
	add_child(foe_card)
	var icon := TextureRect.new()
	icon.texture = Sprites.frames(kind)[0]
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.position = Vector2(4, 6)
	icon.size = Vector2(48, 48)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foe_card.add_child(icon)
	var head := _label(foe_card, Vector2(56, 2), Vector2(190, 18), Color(1, 0.55, 0.45), 13)
	head.text = "New foe: " + title
	var body := _label(foe_card, Vector2(56, 19), Vector2(200, 40), Color(0.95, 0.92, 0.85), 11)
	body.text = tip
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for l in [head, body]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := foe_card
	var tw := create_tween()
	tw.tween_property(card, "position:x", 8.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(4.5)
	tw.tween_property(card, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		card.queue_free()
		foe_card = null
		if not foe_queue.is_empty():
			var next: Array = foe_queue.pop_front()
			show_foe(next[0], next[1], next[2]))


## The title screen. Cards fly in one after another; hovering lifts a card, and
## picking a mode makes it pulse and burst while the others fall away, then the screen
## fades into the game (Classic and the Campaign open a second set of cards first).
var splash: Control = null   # the start screen, while it's up


## The start screen: the splash picture, and a Start Game button (Enter or Space too)
## that leads to the title screen. `then` is called once it's pressed.
func show_splash(then: Callable) -> void:
	splash = Control.new()
	splash.size = Vector2(WIDTH, HEIGHT)
	add_child(splash)
	_center(splash)
	var dark := ColorRect.new()
	dark.color = Color(0.04, 0.03, 0.06)
	dark.size = Vector2(WIDTH, HEIGHT)
	splash.add_child(dark)
	_bleed(dark)   # (the night sky's colour all round, on a wide or tall window)
	splash.add_child(preload("res://scripts/splash_art.gd").new())   # (the splash, drawn in code and animated)
	var go := _button(splash, Vector2(WIDTH / 2.0 - 130, 88), Vector2(260, 66), "Start Game")
	go.add_theme_font_size_override("font_size", 28)
	for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		go.add_theme_color_override(state, Color(1, 0.85, 0.35) if state != "font_hover_color" else Color(1, 0.93, 0.6))
	go.focus_mode = Control.FOCUS_ALL
	go.grab_focus.call_deferred()   # (so Enter or Space press it)
	go.pressed.connect(func():
		go.disabled = true
		var leaving := splash
		splash = null   # (the title music may start)
		then.call()   # the title screen, built underneath...
		move_child(leaving, -1)   # ...while this stays on top until it's fully in, then fades away (nothing behind shows through)
		var tw := create_tween()
		tw.tween_interval(0.45)
		tw.tween_property(leaving, "modulate:a", 0.0, 0.35)
		tw.tween_callback(leaving.queue_free))
	splash.modulate.a = 0.0
	create_tween().tween_property(splash, "modulate:a", 1.0, 0.4)


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
	# Which build this is (to tell an itch.io build from another), and on the web, why
	# it's silent at first (browsers hold sound back until the page is clicked).
	var ver := _label(mode_screen, Vector2(WIDTH - 210, HEIGHT - 26), Vector2(200, 20), Color(1, 1, 1, 0.55), 12)
	ver.text = "v%s" % ProjectSettings.get_setting("application/config/version", "")
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_show_cards("top")


## The cards on the title screen. "top": Campaign, Classic, Freeplay, Tutorial,
## Settings; "classic": the battlefields (the meadow, and the campaign's maps: open once
## the campaign reaches them, shown locked till then); "classic_diff": the three
## difficulties on the battlefield picked; "campaign": continue or start one;
## "new": a new campaign's difficulty. Each card is [key, name, text, colour, icon,
## the title scene's look]; a "goto:<set>" key opens another set of cards.
func _show_cards(set_name: String) -> void:
	for c in mode_cards:
		if not is_instance_valid(c):
			continue
		var away := create_tween()
		away.tween_property(c, "modulate:a", 0.0, 0.15)
		away.tween_callback(c.queue_free)
	mode_cards = []
	picking = false
	var modes := []
	var narrow := false   # four cards to a row
	var top := [Vector2(20, 636), Vector2(225, 636), Vector2(430, 636)]
	var spots := []
	var back := ["goto:top", "Back", "Back to the\nmain menu", Color(0.8, 0.8, 0.8), "goblin", ""]
	match set_name:
		"top":
			mode_sub.text = "Choose a mode"
			var save_note := "Alliances %d/8 so far" % Campaign.alliance_count() if Campaign.has_save() else "against the\nOgre King"
			modes = [["goto:campaign", "Campaign", "Unite the peoples\nof the continent\n" + save_note, Color(1.0, 0.72, 0.45), "swordsman", "campaign"],
				["goto:classic", "Classic", "Hold the castle\nwith every unit\nfor as many waves\nas you can", Color(0.95, 0.85, 0.45), "archer", "normal"],
				["goto:battle", "Battle Modes", "The campaign's\nkinds of battle,\nto play on\ntheir own", Color(0.85, 0.7, 1.0), "alchemist", "normal"],
				["freeplay", "Freeplay", "Unlimited gold\nSpawn any wave\nor enemy\nThe castle can't fall", Color(0.55, 0.8, 1.0), "mage", "freeplay"],
				["tutorial", "Tutorial", "Learn the basics\nstep by step\nThe castle can't fall", Color(0.75, 1.0, 0.55), "bard", "tutorial"],
				["settings", "Settings", "Music and\nsound effects\nvolume", Color(0.82, 0.84, 0.9), "engineer", "settings"]]
			spots = top + [Vector2(20, 834), Vector2(225, 834), Vector2(430, 834)]
		"classic":
			mode_sub.text = "Classic Survival: choose your difficulty"
			for key in Data.DIFFICULTIES:
				modes.append(_difficulty_card(key, "classic:" + key))
			modes.append(back)
			spots = top + [Vector2(225, 834)]
		"campaign":
			# The save slots, each with what's in it.
			mode_sub.text = "Campaign: The Line\nChoose a save"
			for n in range(1, Campaign.SLOTS + 1):
				modes.append(_slot_card(n))
			modes.append(back)
			spots = top + [Vector2(225, 834)]
		"battle":
			mode_sub.text = "Battle Modes: choose a kind of battle"
			# (Castle Defense is Classic, on its own card on the main menu.)
			for t in Scenarios.TYPES:
				if t == "castle":
					continue
				var ty: Dictionary = Scenarios.TYPES[t]
				modes.append(["goto:bm:" + t, ty["name"], ty["blurb"], ty["color"], ty["look"], t])   # its own scene behind
			modes.append(back)
			# Two rows of four along the bottom, clear of the castle (Back last).
			narrow = true
			for i in modes.size():
				spots.append(Vector2(8 + (i % 4) * (NARROW_W + 8), [636, 834][i / 4]))
	if set_name.begins_with("slot:"):
		# A save: carry on with it, start it over, or delete it.
		var n := int(set_name.substr(5))
		var info: Dictionary = Campaign.slot_info(n)
		mode_sub.text = "Save %d" % n + ("\n" + info["error"] if info.has("error") else "")
		if not info.is_empty() and not info.has("error"):
			modes.append(["campaign:continue:%d" % n, "Continue", "%s\nAlliances %d/8\nBeacons lit %d\nBack to the map" % [Data.DIFFICULTIES[info["difficulty"]]["name"],
					info["alliances"], info["beacons"]], Color(1.0, 0.72, 0.45), "swordsman", "campaign"])
		modes.append(["goto:new:%d" % n, "Start Over", "A new campaign\nin this save\n(replaces it)", Color(0.95, 0.85, 0.45), "engineer", "campaign"])
		modes.append(["goto:del:%d" % n, "Delete", "Erase this\nsave for good", Color(1.0, 0.5, 0.45), "ogre_king", ""])
		modes.append(["goto:campaign", "Back", "Back to the\nsaves", Color(0.8, 0.8, 0.8), "goblin", ""])
		spots = _row_spots(modes.size() - 1) + [Vector2(225, 834)]
	elif set_name.begins_with("new"):
		# A new campaign's difficulty, in save n.
		var n := int(set_name.substr(4)) if set_name.begins_with("new:") else Campaign.slot
		var filled := not Campaign.slot_info(n).is_empty()
		mode_sub.text = "New campaign in Save %d: choose your difficulty" % n + ("\n(this replaces what's in it)" if filled else "")
		for key in Data.DIFFICULTIES:
			modes.append(_difficulty_card(key, "campaign:new:%s:%d" % [key, n]))
		modes.append(["goto:slot:%d" % n if filled else "goto:campaign", "Back", "Back to the\nsave" if filled else "Back to the\nsaves", Color(0.8, 0.8, 0.8), "goblin", ""])
		spots = top + [Vector2(225, 834)]
	elif set_name.begins_with("del:"):
		var n := int(set_name.substr(4))
		mode_sub.text = "Delete Save %d? This can't be undone." % n
		modes.append(["delete:%d" % n, "Delete", "Erase Save %d\nfor good" % n, Color(1.0, 0.5, 0.45), "ogre_king", ""])
		modes.append(["goto:slot:%d" % n, "Keep It", "Back to the\nsave", Color(0.8, 0.8, 0.8), "swordsman", "campaign"])
		spots = _row_spots(2)
	elif set_name.begins_with("bm:"):
		# A kind of battle: its scenarios.
		var t := set_name.substr(3)
		mode_sub.text = "%s: choose a battle" % Scenarios.TYPES[t]["name"]
		for id in Scenarios.of_type(t):
			var sc: Dictionary = Scenarios.SCENARIOS[id]
			var where: String = "on the meadow" if sc["map"] == "" else Maps.get_map(sc["map"]).get("name", sc["map"])
			if sc["type"] == "escort":
				where = "from %s on" % where
			modes.append(["goto:bmd:" + id, sc["name"], "Survive as\nmany waves\nas you can\n%s" % where,
					Scenarios.TYPES[t]["color"], Scenarios.TYPES[t]["look"], t])
		modes.append(["goto:battle", "Back", "Back to the\nkinds of battle", Color(0.8, 0.8, 0.8), "goblin", ""])
		spots = _row_spots(modes.size() - 1) + [Vector2(225, 834)]
	elif set_name.begins_with("bmd:"):
		# A scenario: its difficulty.
		var id := set_name.substr(4)
		mode_sub.text = "%s: choose your difficulty" % Scenarios.SCENARIOS[id]["name"]
		var cfg := ConfigFile.new()
		cfg.load(get_parent().records_path if get_parent().records_path != "" else "user://none.cfg")
		for key in Data.DIFFICULTIES:
			var card := _difficulty_card(key, "battle:%s:%s" % [id, key])
			# (No castle in these: its health would mean nothing. The best run instead.)
			var best: int = cfg.get_value("survive", "%s@%s" % [id, key], 0)
			card[2] = (card[2] as String).replace("Castle %d HP" % roundi(Data.CASTLE_HP * Data.DIFFICULTIES[key]["castle"]),
					"Best: %d waves" % best if best > 0 else "No run yet")
			modes.append(card)
		modes.append(["goto:bm:" + Scenarios.SCENARIOS[id]["type"], "Back", "Back to the\nbattles", Color(0.8, 0.8, 0.8), "goblin", ""])
		spots = top + [Vector2(225, 834)]
	var cards := []
	for i in modes.size():
		cards.append(_mode_card(modes[i], spots[i], 0.1 + i * 0.07, NARROW_W if narrow else 190.0))
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
		elif key.begins_with("delete:"):
			card.pressed.connect(func():
				if not picking:
					var n := int(key.substr(7))
					Campaign.delete_slot(n)
					if n == Campaign.slot:
						Campaign.use_slot(Campaign.latest_slot())
						Campaign.load_game()
					title_scene.set_look("")
					_show_cards("campaign")
					show_message("Save %d deleted" % n))
		elif key.begins_with("goto:"):
			card.pressed.connect(func():
				if not picking:
					title_scene.set_look("")
					_show_cards(key.substr(5)))
		else:
			card.pressed.connect(func():
				_pick_mode(key, card, cards, mode_title, mode_sub))


## A save slot's card on the campaign menu: what's in it and when it was last played,
## or an empty one to start a campaign in.
func _slot_card(n: int) -> Array:
	var info: Dictionary = Campaign.slot_info(n)
	if info.is_empty():
		return ["goto:new:%d" % n, "Save %d" % n, "Empty\n\nStart a new\ncampaign here", Color(0.75, 0.78, 0.85), "swordsman", "campaign"]
	if info.has("error"):
		return ["goto:slot:%d" % n, "Save %d" % n, info["error"].replace(": ", ":\n"), Color(1.0, 0.5, 0.45), "goblin", ""]
	return ["goto:slot:%d" % n, "Save %d" % n, "%s\nAlliances %d/8\nBeacons lit %d\n%s" % [Data.DIFFICULTIES[info["difficulty"]]["name"], info["alliances"],
			info["beacons"], _when(info["saved_at"])], Color(1.0, 0.72, 0.45), "swordsman", "campaign"]


## A save's time, in the player's own time zone: "Today 14:05", "Nov 9" or "Nov 9 2025".
func _when(unix: int) -> String:
	if unix <= 0:
		return ""
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(unix + bias)
	var now := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + bias)
	if d["year"] == now["year"] and d["month"] == now["month"] and d["day"] == now["day"]:
		return "Today %02d:%02d" % [d["hour"], d["minute"]]
	var mon: String = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][d["month"] - 1]
	return "%s %d" % [mon, d["day"]] + ("" if d["year"] == now["year"] else " %d" % d["year"])


## Where n cards (up to three) sit in the top row, centred.
func _row_spots(n: int) -> Array:
	match n:
		1:
			return [Vector2(225, 636)]
		2:
			return [Vector2(122, 636), Vector2(327, 636)]
	return [Vector2(20, 636), Vector2(225, 636), Vector2(430, 636)]


## Classic, after the difficulty: the battlefield viewer. Start goes into the game on the
## battlefield showing ("<difficulty>|<map>", or just the difficulty on the meadow).
func show_battlefields(diff: String) -> void:
	if battlefields != null:
		return
	var v := MapViewer.new()
	v.records = get_parent().records_path
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


## Cards are 190 wide, three to a row; narrow ones (NARROW_W) go four to a row.
const NARROW_W := 150.0


func _mode_card(m: Array, at: Vector2, delay: float, w := 190.0) -> Button:
	var b := _button(mode_screen, at + Vector2(0, 420), Vector2(w, 184), "")
	b.pivot_offset = b.size / 2
	b.modulate.a = 0.0
	var name := _label(b, Vector2(0, 10), Vector2(w, 36), m[3], 28)
	name.text = m[1]
	# Long names (the battlefields) shrink to fit the card.
	var size := 28
	while size > 14 and ThemeDB.fallback_font.get_string_size(m[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > w - 14.0:
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
	icon.position = Vector2((w - 48.0) / 2.0, 42)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var desc := _label(b, Vector2(4, 90), Vector2(w - 8.0, 86), Color(0.85, 0.85, 0.85), 13)   # room for four lines
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
	r.mouse_filter = Control.MOUSE_FILTER_STOP   # (nothing beyond the middle can be clicked through it either)
	r.show_behind_parent = true
	dim.add_child(r)
	dim.color = Color(0, 0, 0, 0)   # the copy does the dimming, so the middle isn't darkened twice
	return r


## Pauses the game and asks before throwing the current run away.
func show_menu_confirm() -> void:
	if menu_dim != null and is_instance_valid(menu_dim):
		return   # (already up)
	get_tree().paused = true
	var dim := ColorRect.new()
	menu_dim = dim
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = Vector2(WIDTH, HEIGHT)
	add_child(dim)
	_center(dim)
	_bleed(dim)
	var title := _label(dim, Vector2(0, 360), Vector2(WIDTH, 40), Color.WHITE, 28)
	title.text = "Return to the menu?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(dim, Vector2(0, 404), Vector2(WIDTH, 26), Color(0.8, 0.8, 0.8), 16)
	var m = get_parent()
	sub.text = "This game's progress will be lost."
	if m.survival() and m.started and not m.game_over and m.waves_survived() > 0:
		sub.text = "The %d wave%s survived so far still count toward your best." % [m.waves_survived(), "" if m.waves_survived() == 1 else "s"]
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


## survived = waves cleared this game; previous = this mode's record before it.
func show_end(won: bool, survived: int, previous: int, endless: bool, why := "") -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = Vector2(WIDTH, HEIGHT)
	add_child(dim)
	_center(dim)
	_bleed(dim)
	var title := _label(dim, Vector2(0, 320), Vector2(WIDTH, 60),
			Color(1, 0.85, 0.3) if won or survived > previous else Color(1, 0.4, 0.35), 44)
	title.text = "Victory!" if won else (why if why != "" else "The castle has fallen")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(dim, Vector2(0, 390), Vector2(WIDTH, 30), Color.WHITE, 20)
	if won:
		sub.text = "You held out through all %d waves." % survived
	elif endless:
		sub.text = "You survived %d waves, %d past wave %d." % [survived, survived - Data.FINAL_WAVE, Data.FINAL_WAVE]
	else:
		sub.text = "You survived %d wave%s." % [survived, "" if survived == 1 else "s"]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rec := _label(dim, Vector2(0, 424), Vector2(WIDTH, 26), Color(1, 0.85, 0.3), 16)
	rec.text = "New best!" if survived > previous else "Best: %d waves" % previous
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var btn := _button(dim, Vector2(220, 480), Vector2(200, 56), "Play again")
	btn.pressed.connect(func(): restart_pressed.emit())


## The end of a Battle Modes scenario: how it went, the best result, and Play again.
func show_battle_end(won: bool, name: String, summary: String, record: String, again_key: String, survived := -1) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = Vector2(WIDTH, HEIGHT)
	add_child(dim)
	_center(dim)
	_bleed(dim)
	var title := _label(dim, Vector2(0, 280), Vector2(WIDTH, 60), Color(1, 0.85, 0.3) if won or record == "New best!" else Color(1, 0.4, 0.35), 44)
	title.text = "Victory!" if won else "The line has broken"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if survived >= 0:
		var held := _label(dim, Vector2(0, 340), Vector2(WIDTH, 30), Color.WHITE, 22)
		held.text = "You survived %d wave%s" % [survived, "" if survived == 1 else "s"]
		held.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(dim, Vector2(40, 372), Vector2(WIDTH - 80, 50), Color(0.85, 0.85, 0.85), 16)
	sub.text = name + (": " + summary if summary != "" else "")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rec := _label(dim, Vector2(0, 424), Vector2(WIDTH, 26), Color(1, 0.85, 0.3), 16)
	rec.text = record
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var again := _button(dim, Vector2(110, 470), Vector2(200, 56), "Play again")
	again.pressed.connect(func(): battle_again.emit(again_key))
	var menu := _button(dim, Vector2(330, 470), Vector2(200, 56), "Main menu")
	menu.pressed.connect(func(): restart_pressed.emit())


# --- Campaign ----------------------------------------------------------------

## A story scene over everything; `then` runs once it's over (or skipped).
## A story: the allies' lines in the dialogue box, and the enemy's (the Ogre King's and
## his heralds') each as a cutscene of their own (unless marked "box"), in order. Esc skips the rest of it.
func play_story(lines: Array, then: Callable = Callable()) -> void:
	if lines.is_empty():
		if then.is_valid():
			then.call()
		return
	# The next run of lines with the same kind of speaker.
	var villain: bool = _cutscene_line(lines[0])
	var n := 0
	while n < lines.size() and _cutscene_line(lines[n]) == villain:
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


## Whether a story line plays as a cutscene of its own: the enemy's, unless it's marked
## "box" (a villain who's there on the battlefield talks in the dialogue box like anyone).
func _cutscene_line(line: Dictionary) -> bool:
	return VILLAINS.has(line["who"]) and not line.get("box", false)


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
func show_campaign_end(won: bool, mission: Dictionary, survived: int, summary := "") -> void:
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
		sub.text = "%s: you held through all %d waves." % [mission["name"], mission["waves"]] + ("\n" + summary if summary != "" else "")
		var go := _button(dim, Vector2(200, 460), Vector2(240, 56), "Continue to the map")
		go.pressed.connect(func(): campaign_map.emit())
	else:
		sub.text = (summary + " " if summary != "" else "%s: you held %d of %d waves. " % [mission["name"], survived, mission["waves"]]) + "Half of what your troops learned still counts; try again."
		var again := _button(dim, Vector2(110, 460), Vector2(200, 56), "Try again")
		again.pressed.connect(func(): campaign_retry.emit())
		var map_btn := _button(dim, Vector2(330, 460), Vector2(200, 56), "Back to the map")
		map_btn.pressed.connect(func(): campaign_map.emit())
	# A flawless win (or what spoiled it), on its own line under the buttons.
	if won and flawless_note.size() == 2 and flawless_note[0] != "":
		var fl := _label(dim, Vector2(30, 528), Vector2(WIDTH - 60, 22), Color(1.0, 0.85, 0.3) if flawless_note[1] else Color(0.75, 0.72, 0.68), 15)
		fl.text = flawless_note[0]
		fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flawless_note = []
	# What each unit learned: XP earned, and any training points it reached.
	var earned: Array = Campaign.last_battle.keys()
	earned.sort_custom(func(a, b): return Campaign.last_battle[a][0] > Campaign.last_battle[b][0])
	if not earned.is_empty():
		var head := _label(dim, Vector2(0, 572), Vector2(WIDTH, 24), Color(1, 0.85, 0.3), 17)
		head.text = "Experience"
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		for i in mini(earned.size(), 8):
			var kind: String = earned[i]
			var got: Array = Campaign.last_battle[kind]
			var line := _label(dim, Vector2(WIDTH / 2.0 - 240, 602 + i * 24), Vector2(480, 22), Color(0.92, 0.9, 0.85), 15)
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


# --- Orders: the selected unit's (or group's) target priority, commitment, movement
# zone, danger reactions and answering calls for help ----------------------------------

var flawless_note := []       # [what to say, flawless] for the campaign's end screen (main._finish)
var orders_box: Panel = null
var orders_for = null          # the first of the units the box was built for (for a group, any one of them)
var orders_units := []         # the units the box gives orders to (one, or the group)
var orders_main = null
var orders_ui := {}            # the box's controls, by name
var orders_syncing := false    # set while the box is brought in step with its units (its controls' own signals are ignored then)


## A unit's orders in a few words, for the panel's button.
func _orders_short(w) -> String:
	var mode: String = {"hold": "Hold", "guard": "Guard", "free": "Free"}[w.move_mode] if not w.is_emplacement() and not w.wall_guard else "Fixed"
	if not w.uses_targeting() and not w.is_mobile_healer():
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
		if w.move_mode == "guard":
			var r: Rect2 = w.zone_rect()
			var preset: String = w.main.area_preset_of(r)
			mode += " (%s)" % (w.main.AREA_PRESET_NAMES[preset] if preset != "" else "%s × %s" % [Data.ft(r.size.x), Data.ft(r.size.y)])
		parts.append(mode)
		parts.append(Warrior.DANGER_NAMES[w.danger_mode] + (", calls for help" if w.call_help else ""))
		if not w.is_mobile_healer() and w.answer != "ignore":
			parts.append("answers calls " + Warrior.ANSWER_NAMES[w.answer].to_lower())
	return "  ·  ".join(parts)


## What a unit's orders mean, in a sentence or three.
func orders_meaning(w) -> String:
	var out := ""
	if w.is_mobile_healer():
		match w.care():
			"heal":
				out += "Heals whoever's hurt worst first (villagers too), then revives the downed. "
			"stay":
				var who: String = (w.wards[0].label.to_lower() if w.wards.size() == 1 else "group of %d" % w.wards.size()) if not w.wards.is_empty() else "troop"
				out += "Stays with the %s and looks after them first; anyone else only if it can reach them from there. " % who
			"danger":
				out += "Goes to allies in danger first, wherever they are; then revives the downed and heals the hurt. "
			_:
				out += "Revives the downed first (they're on a clock), then heals whoever's hurt worst. "
	if w.uses_targeting():
		var pick: String = {"closest": "the nearest enemy", "first": "the enemy closest to the castle",
				"strongest": "the toughest kind of enemy", "weakest": "the weakest kind of enemy",
				"objective": "the enemy nearest to getting at what you're protecting"}[w.priority]
		out += "Picks %s, " % pick
		out += ("and sticks with it until it falls or gets away. " if w.commit == "focused" else "and switches whenever a better one comes along. ")
	if w.is_emplacement() or w.wall_guard:
		out += "Never moves: fights what comes in range."
	else:
		match w.move_mode:
			"hold":
				out += "Stands at its post and fights only what it can reach from there."
			"guard":
				out += "Fights anywhere in its area (outlined on the field), then comes back to its post."
			_:
				out += "Chases enemies anywhere on the field."
		if w.uses_targeting() and w.move_mode != "hold":
			out += " Strikes anything it passes on the way."
		out += " When badly hurt it %s." % ("falls back to a Healer, its post or the castle (still shooting or healing on the way, if it can)" if w.danger_mode == "fall_back" else "fights on")
		if not w.is_mobile_healer() and w.answer != "ignore":
			out += " Goes to others' calls for help."
	return out


## Whether `w` has orders to give: a targeting unit, or one that moves (a Healer).
func _takes_orders(w) -> bool:
	return w != null and is_instance_valid(w) and w.kind != "barricade" and (w.uses_targeting() or (not w.is_emplacement() and not w.wall_guard))


## The units the panel is for now: the selected one, or the group's that take orders.
func _orders_targets(main) -> Array:
	if main.selected != null:
		return [main.selected] if _takes_orders(main.selected) else []
	return main.group.filter(_takes_orders)


func toggle_orders(main) -> void:
	if orders_box != null:
		_close_orders()
	else:
		var units := _orders_targets(main)
		if not units.is_empty():
			_open_orders(main, units)


func _close_orders() -> void:
	if orders_box != null:
		orders_box.queue_free()
	orders_box = null
	orders_for = null
	orders_units = []
	orders_ui = {}


## The orders window's layout: it takes the place of the upgrade cards in the bottom
## panel (under its top bar), in compact rows, a close button at the top right.
const ORDERS_TOP := 46.0      # below the panel's gold / wave / buttons bar
const ORDER_ROW := 26.0       # one row of buttons (24 high, 2 apart)
const ORDER_X0 := 104.0       # where the buttons start, right of the row's label
const ORDER_RIGHT := 44.0     # room kept clear on the right for the close button


## A row of toggle buttons: `keys` labelled by `names`, giving order `field`.
func _order_row(box: Panel, y: float, label: String, field: String, keys: Array, names: Dictionary, tips: Dictionary, x0 := ORDER_X0, width := -1.0) -> void:
	if label != "":
		var lab := _label(box, Vector2(10, y + 2), Vector2(ORDER_X0 - 12.0, 20), Color(0.85, 0.82, 0.76), 12)
		lab.text = label
	var span := (box.size.x - x0 - ORDER_RIGHT) if width < 0.0 else width
	var bw := span / keys.size() - 4.0
	var btns := {}
	for i in keys.size():
		var key = keys[i]
		var b := _button(box, Vector2(x0 + i * (bw + 4.0), y), Vector2(bw, ORDER_ROW - 2.0), names[key])
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 11 if bw < 70.0 else 12)
		b.tooltip_text = tips.get(key, "")
		b.pressed.connect(func(): _order_from_box(field, key))
		btns[key] = b
	orders_ui[field] = btns


func _open_orders(main, units: Array) -> void:
	_close_orders()
	orders_main = main
	orders_units = units.duplicate()
	orders_for = units[0]
	var fighters := units.filter(func(w): return w.uses_targeting())
	var healers := units.filter(func(w): return w.is_mobile_healer())
	var movers := units.filter(func(w): return not w.is_emplacement() and not w.wall_guard)
	# In the bottom panel, over the upgrade cards (and a group's make-up): the field stays clear.
	var box := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.11, 0.1)
	style.border_color = Color(0.45, 0.35, 0.2)
	style.border_width_top = 1
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_STOP   # nothing under it can be clicked while it's open
	box.position = Vector2(0, ORDERS_TOP)
	box.size = Vector2(ui_w, HEIGHT - TOP - ORDERS_TOP)
	panel.add_child(box)
	orders_box = box
	var close := _button(box, Vector2(box.size.x - 36, 4), Vector2(28, 24), "X")
	close.tooltip_text = "Close the orders, back to the upgrades [O]"
	close.pressed.connect(_close_orders)
	var who := _label(box, Vector2(box.size.x - 40, 30), Vector2(36, 40), Color(1, 0.85, 0.3), 11)
	who.text = str(units.size()) if units.size() > 1 else ""
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.tooltip_text = "%d troops get these orders" % units.size()
	var tips := {"focused": "Sticks to the enemy it picked until it falls, gets out of reach or leaves this unit's area (recommended)",
			"reactive": "Looks again a few times a second and switches to whichever enemy is now the best pick",
			"hold": "Stays at its post and fights only what it can reach from there (it doesn't leave it for others' calls for help)",
			"guard": "Fights anywhere in its area: pick one below, or draw your own on the field",
			"free": "Chases enemies anywhere on the field",
			"closest": "The enemy nearest this unit", "first": "The enemy closest to the castle",
			"strongest": "The toughest kind of enemy", "weakest": "The weakest kind of enemy",
			"objective": "The enemy nearest to getting at what you're protecting (then the nearest)",
			"revive": "Revives the downed first (they're on a clock), then heals the hurt",
			"heal": "Heals the hurt first (villagers too), then revives the downed",
			"stay": "Stays with a troop or a group and looks after them first: pick this, then click the troop (or right-click a troop with the Healer selected)",
			"danger": "Goes to allies in danger (badly hurt and under attack, or calling for help) first, wherever they are",
			"fight": "Badly hurt and under attack, it keeps fighting",
			"fall_back": "Badly hurt and under attack, it breaks off and falls back to a Healer or Medic Bay (else its post or the castle) until it's patched up or out of the fight",
			"ignore": "Doesn't answer calls for help",
			"after": "Answers a call for help once its own enemy's dealt with: leaves its area and its target priority to go, then comes back",
			"now": "Answers a call for help at once, dropping its enemy: leaves its area and its target priority to go, then comes back",
			"front": "The front half of the field", "left": "The left side, and a little of the middle", "center": "The middle, overlapping both flanks a little",
			"right": "The right side, and a little of the middle", "back": "The back half of the field, in front of the castle",
			"draw": "Drag out an area of your own on the field, any size [D]"}
	var y := 4.0
	if not fighters.is_empty():
		_order_row(box, y, "Target [T]", "priority", Warrior.priorities_for(main), Warrior.PRIORITY_NAMES, tips)
		y += ORDER_ROW
	if not healers.is_empty():
		_order_row(box, y, "Focus [T]" if fighters.is_empty() else "Healers", "care", Warrior.HEAL_PRIORITIES, Warrior.PRIORITY_NAMES, tips)
		y += ORDER_ROW
	if not movers.is_empty():
		_order_row(box, y, "Position [M]", "move_mode", Warrior.MOVE_MODES, {"hold": "Hold", "guard": "Guard area", "free": "Free"}, tips)
		y += ORDER_ROW
		if movers.any(func(w): return w.move_mode == "guard"):
			var keys: Array = main.AREA_PRESETS.keys() + ["draw"]
			var names: Dictionary = {"front": "Front", "left": "Left", "center": "Centre", "right": "Right", "back": "Back", "draw": "Draw…"}
			_order_row(box, y, "Area [D]", "area", keys, names, tips)
			y += ORDER_ROW
		_order_row(box, y, "When hurt", "danger_mode", Warrior.DANGER_MODES, Warrior.DANGER_NAMES, tips)
		y += ORDER_ROW
	# Something on the field to follow (a wagon, villagers): a row to follow it, or not.
	var to_follow: Array = main.rules.followable() if not movers.is_empty() else []
	if not to_follow.is_empty():
		var fl := _label(box, Vector2(10, y + 2), Vector2(ORDER_X0 - 12.0, 20), Color(0.85, 0.82, 0.76), 12)
		fl.text = "Follow [J]"
		var opts: Array = [null] + to_follow.slice(0, 2)
		var bw := (box.size.x - ORDER_X0 - ORDER_RIGHT) / opts.size() - 4.0
		var fbtns := []
		for i in opts.size():
			var o = opts[i]
			var b := _button(box, Vector2(ORDER_X0 + i * (bw + 4.0), y), Vector2(bw, ORDER_ROW - 2.0), "Its post" if o == null else o.label)
			b.toggle_mode = true
			b.add_theme_font_size_override("font_size", 12)
			b.tooltip_text = "Keeps to the post you gave it" if o == null else "Its post moves with the %s, and it keeps its place around it" % o.label.to_lower()
			b.pressed.connect(func():
				main.set_follow(o, orders_units.filter(func(w): return is_instance_valid(w) and not w.is_emplacement() and not w.wall_guard))
				_refresh_orders(main, null))
			b.set_meta("follow", o)
			fbtns.append(b)
		orders_ui["follow"] = fbtns
		y += ORDER_ROW
	# What the orders mean, in whatever room is left under the rows (all of it in a tooltip).
	var meaning := _label(box, Vector2(10, y + 2), Vector2(box.size.x - 20, maxf(box.size.y - y - 4.0, 0.0)), Color(0.9, 0.9, 0.85), 11)
	meaning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meaning.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meaning.mouse_filter = Control.MOUSE_FILTER_PASS
	orders_ui["meaning"] = meaning
	_refresh_orders(main, null)


func _order_from_box(field: String, value) -> void:
	if orders_syncing or orders_main == null:
		return
	var units := orders_units.filter(func(w): return is_instance_valid(w) and not w.is_queued_for_deletion())
	if units.is_empty():
		return
	match field:
		"care":
			orders_main.give_order("priority", value, units.filter(func(w): return w.is_mobile_healer()))
		"priority":
			orders_main.give_order("priority", value, units.filter(func(w): return not w.is_mobile_healer()))
		"area":
			if value == "draw":
				orders_main.start_area_pick(units)
			else:
				orders_main.give_order("area", orders_main.area_preset(value), units)
		_:
			orders_main.give_order(field, value, units)
	_refresh_orders(orders_main, null)


## The one value `field` has across `units`, or null if they differ (no button lit then).
func _common(units: Array, getter: Callable):
	var vals := []
	for w in units:
		var v = getter.call(w)
		if not vals.has(v):
			vals.append(v)
	return vals[0] if vals.size() == 1 else null


## Keeps the box in step with its units (and with orders given by hotkey); follows the
## selection to another unit or group, and closes when nothing that takes orders is selected.
func _refresh_orders(main, _w) -> void:
	if orders_box == null:
		return
	var now := _orders_targets(main)
	if now.is_empty():
		_close_orders()
		return
	if now != orders_units:
		_open_orders(main, now)
		return
	var fighters := now.filter(func(w): return w.uses_targeting())
	var healers := now.filter(func(w): return w.is_mobile_healer())
	var movers := now.filter(func(w): return not w.is_emplacement() and not w.wall_guard)
	if orders_ui.has("area") != movers.any(func(w): return w.move_mode == "guard"):
		_open_orders(main, now)   # (the Area row comes and goes with Guard area)
		return
	var answering := fighters.filter(func(w): return not w.is_emplacement() and not w.wall_guard)
	var current := {
		"priority": _common(fighters.filter(func(w): return not w.is_mobile_healer()), func(w): return w.priority),
		"care": _common(healers, func(w): return w.care()),
		"commit": _common(fighters, func(w): return w.commit),
		"move_mode": _common(movers, func(w): return w.move_mode),
		"area": _common(movers, func(w): return main.area_preset_of(w.zone_rect()) if w.move_mode == "guard" else ""),
		"danger_mode": _common(movers, func(w): return w.danger_mode),
		"answer": _common(answering, func(w): return w.answer),
	}
	for field in current:
		if not orders_ui.has(field):
			continue
		for key in orders_ui[field]:
			var b: Button = orders_ui[field][key]
			b.set_pressed_no_signal(current[field] != null and key == current[field])
			if field == "answer":
				b.disabled = answering.is_empty()
	if orders_ui.has("area"):
		var drawing: bool = not main.area_pick.is_empty()
		orders_ui["area"]["draw"].set_pressed_no_signal(drawing or (current["area"] == "" and current["move_mode"] == "guard"))
	if orders_ui.has("call_help"):
		var c = _common(now, func(w): return w.call_help)
		orders_ui["call_help"].set_pressed_no_signal(c == true)
		orders_ui["call_help"].text = "Call for help" + (": on" if c == true else ": off" if c == false else ": mixed")
	for b in orders_ui.get("follow", []):
		var fo = b.get_meta("follow") if b.has_meta("follow") else null
		var a = _common(movers, func(w): return w.anchor)
		b.set_pressed_no_signal(a != null and a == fo or (fo == null and a == null and _common(movers, func(w): return w.anchor == null) == true))
	var meaning: Label = orders_ui["meaning"]
	if now.size() == 1:
		meaning.text = orders_meaning(now[0])
		if now[0].anchor != null and now[0].wards.is_empty():
			meaning.text += " Follows the %s." % now[0].anchor.label.to_lower()
	else:
		meaning.text = "Orders here go to all %d. A row with nothing lit: they differ. Their areas are outlined on the field." % now.size()
	meaning.tooltip_text = meaning.text
