extends CanvasLayer
## Bottom panel (stats, hire buttons, selected warrior), wave messages and end screen.

signal hire_pressed(kind: String)
signal start_wave_pressed
signal upgrade_pressed(path: int)
signal sell_pressed
signal target_pressed
signal song_pressed
signal speed_pressed
signal restart_pressed
signal menu_confirmed
signal mode_chosen(mode: String)
signal freeplay_level_changed(step: int)
signal freeplay_spawn_pressed(kind: String)
signal freeplay_clear_pressed
signal endless_chosen
signal finish_chosen

const Data = preload("res://scripts/data.gd")
const Warrior = preload("res://scripts/warrior.gd")
const Sprites = preload("res://scripts/sprites.gd")
const PATH_KEYS := ["Q", "W", "E", "R"]
const TOP := 768.0
const WIDTH := 640.0
const HEIGHT := 960.0

var gold_label: Label
var lives_label: Label
var wave_label: Label
var speed_btn: Button
var start_btn: Button
var hire_buttons := {}
var tab_buttons := {}     # "troops" / "emplacements"
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
var hard_label: Label       # shows the difficulty, unless it's Normal
var hire_meta := {}         # kind -> [label, hotkey number, rows] to rebuild hire button text
var price_mult := 1.0
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

	gold_label = _label(panel, Vector2(14, 10), Vector2(112, 30), Color(1, 0.85, 0.3), 20)
	lives_label = _label(panel, Vector2(122, 12), Vector2(104, 30), Color(1, 0.5, 0.5), 17)
	wave_label = _label(panel, Vector2(226, 10), Vector2(116, 30), Color(0.8, 0.85, 1), 20)
	menu_btn = _button(panel, Vector2(342, 8), Vector2(58, 34), "Menu")
	menu_btn.tooltip_text = "Leave this game and go back to mode select"
	menu_btn.pressed.connect(show_menu_confirm)
	speed_btn = _button(panel, Vector2(404, 8), Vector2(68, 34), "Speed 1x")
	speed_btn.add_theme_font_size_override("font_size", 14)
	speed_btn.tooltip_text = "Change game speed [F]"
	speed_btn.pressed.connect(func(): speed_pressed.emit())
	start_btn = _button(panel, Vector2(476, 8), Vector2(152, 34), "Start Wave 1")
	start_btn.tooltip_text = "Send the next wave [Space]"
	start_btn.pressed.connect(func(): start_wave_pressed.emit())

	# Hire buttons come in two tabs: troops that move and fight, and emplacements.
	for t in [["troops", "Troops  [Z]", 50, "Z"], ["emplacements", "Emplacements [X]", 84, "X"]]:
		var tb := _button(panel, Vector2(12, t[2]), Vector2(98, 32), t[1])
		tb.add_theme_font_size_override("font_size", 13 if t[0] == "troops" else 10)
		tb.tooltip_text = "Show %s [%s]  (Tab switches between the two)" % [t[0], t[3]]
		tb.toggle_mode = true
		tb.pressed.connect(func(): show_tab(t[0]))
		tab_buttons[t[0]] = tb
	for t in ["troops", "emplacements"]:
		for kind in tab_kinds(t):
			var b := _button(panel, Vector2.ZERO, Vector2(10, 10), "")
			b.clip_text = true
			_setup_hire_button(b, kind, Data.WARRIORS[kind])

	for p in PATH_KEYS.size():
		path_cards.append(_path_card(panel, p))

	info_label = _label(panel, Vector2(14, 122), Vector2(614, 64), Color(0.9, 0.9, 0.85), 15)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sell_btn = _button(panel, Vector2(526, 142), Vector2(102, 40), "Sell")
	sell_btn.tooltip_text = "Sell for 60% of everything spent on this unit [S]"
	sell_btn.pressed.connect(func(): sell_pressed.emit())
	target_btn = _button(panel, Vector2(414, 142), Vector2(106, 40), "")
	target_btn.add_theme_font_size_override("font_size", 12)
	target_btn.tooltip_text = ("Which enemy this unit goes after [T]:\n"
			+ "Closest - nearest to this unit\n"
			+ "First - closest to the bottom line\n"
			+ "Strongest - toughest enemy type (warlord > troll > orc, sapper > wolf, bat > goblin)\n"
			+ "Weakest - weakest enemy type (goblin first, warlord last)\n"
			+ "Bats fly: melee units and Cannoneers can't hit them.")
	target_btn.pressed.connect(func(): target_pressed.emit())
	song_btn = _button(panel, Vector2(326, 142), Vector2(84, 40), "")
	song_btn.add_theme_font_size_override("font_size", 12)
	song_btn.tooltip_text = "Every instrument is on the field: play the Bards' song between waves, or not [G]"
	song_btn.pressed.connect(func(): song_pressed.emit())

	message_label = _label(self, Vector2(0, 20), Vector2(WIDTH, 40), Color.WHITE, 28)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 6)
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
	start_btn.position.x = ui_w - 164
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
	var avail := ui_w - 126.0
	var font := ThemeDB.fallback_font
	for t in ["troops", "emplacements"]:
		var kinds := tab_kinds(t)
		var rows := 1 if kinds.size() <= 6 or avail >= kinds.size() * 92.0 else 2
		var per_row := ceili(kinds.size() / float(rows))
		var w := (avail - 4.0 * (per_row - 1)) / per_row
		if rows == 1:
			w = minf(w, 82.0 if avail < 600.0 else 180.0)
		var h := 66.0 if rows == 1 else 31.0
		var with_icon := rows == 1 and w >= 120.0
		var room := w - 12.0 - (40.0 if with_icon else 0.0)
		for i in kinds.size():
			var kind: String = kinds[i]
			var d: Dictionary = Data.WARRIORS[kind]
			var price := _price_text(d)
			var font_size := 14 if with_icon else (12 if w >= 80.0 or rows == 2 else 11)
			var label: String = d["name"]
			var text := "%s  %s [%d]" % [label, price, i + 1]
			if rows == 1:
				# Names too wide for the button go on two lines (e.g. "Martial / Artist").
				if font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
					label = label.replace(" ", "\n")
				text = "%s\n%s  [%d]" % [label, price, i + 1]
			# Then anything still too wide gets a smaller font until it fits.
			var widest := 0.0
			for line in (label if rows == 1 else text).split("\n"):
				widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
			while widest > room and font_size > 9:
				widest *= (font_size - 1.0) / font_size
				font_size -= 1
			var b: Button = hire_buttons[kind]
			b.position = Vector2(114 + (i % per_row) * (w + 4), 50 + (i / per_row) * (h + 4))
			b.size = Vector2(w, h)
			b.text = text
			b.add_theme_font_size_override("font_size", font_size)
			b.icon = Sprites.frames(kind)[0] if with_icon else null
			b.expand_icon = with_icon
			b.add_theme_constant_override("icon_max_width", 36)
			hire_meta[kind] = [label, i + 1, rows]


## Upgrade cards sit in a row across the top of the panel, sharing its width
## (up to 300 each, centred).
func _layout_card(card: Dictionary, p: int) -> void:
	var n := float(path_cards.size())
	var cw := minf((ui_w - 12.0 - 6.0 * n) / n, 300.0)
	var left := (ui_w - (cw * n + 6.0 * (n - 1.0))) / 2.0
	var b: Button = card["button"]
	b.position = Vector2(left + p * (cw + 6.0), 48)
	b.size = Vector2(cw, 84)
	card["title"].size.x = cw - 12.0
	card["cost"].position.x = cw - 76.0
	card["tier"].size.x = cw - 12.0
	card["desc"].size.x = cw - 12.0
	var wide := cw >= 200.0
	card["tier"].add_theme_font_size_override("font_size", 13 if wide else 12)
	card["desc"].add_theme_font_size_override("font_size", 11)
	card["desc"].max_lines_visible = 2


## Barricades are priced by length, so they show the cheapest.
func _price_text(d: Dictionary) -> String:
	var cost := maxi(1, roundi(d["cost"] * price_mult))
	return "%dg+" % cost if d.has("cost_per_100") else "%dg" % cost


## Difficulty changes the prices on the hire buttons.
func set_prices(mult: float) -> void:
	price_mult = mult
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
	var price := "%dg + %dg per %s of wall" % [roundi(d["cost_base"] * price_mult), roundi(d["cost_per_100"] * price_mult), Data.ft(100)] if d.has("cost_per_100") else _price_text(d)
	var body := _plain_desc(d) + "\n\n" + _base_stats(d)
	var names: Array = d["paths"].map(func(path): return path["name"])
	body += "\nUpgrades: " + ", ".join(names)
	hover_kind = kind
	_fill_card(d["name"], d["color"], "%s  -  %s" % [sort, price], body)
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
	hard_label.visible = main.started and not main.freeplay and (main.difficulty != "normal" or main.tutorial)
	if hard_label.visible and main.tutorial:
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
	speed_btn.text = "Speed %dx" % int(Engine.time_scale)
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
		wave_label.text = "Endless %d" % main.wave if main.endless else "Wave %d/%d" % [main.wave, Data.FINAL_WAVE]
		start_btn.disabled = main.wave_active or main.game_over or main.choosing
		start_btn.text = "Wave in progress" if main.wave_active else "Start Wave %d" % (main.wave + 1)
	for kind in hire_buttons:
		var b: Button = hire_buttons[kind]
		var cost: int = main.hire_cost(kind)
		b.set_pressed_no_signal(main.placing_type == kind)
		b.disabled = main.game_over or (main.gold < cost and main.placing_type != kind)

	# A selected unit swaps the hire row for its upgrade paths.
	var w = main.selected
	# Picking a hire by hotkey jumps to its tab.
	if main.placing_type != last_placing:
		last_placing = main.placing_type
		if last_placing != "":
			hire_tab = tab_of(last_placing)
	for kind in hire_buttons:
		hire_buttons[kind].visible = w == null and tab_of(kind) == hire_tab
	if hover_kind != "" and not hire_buttons[hover_kind].visible:
		hide_hover()
	for t in tab_buttons:
		tab_buttons[t].visible = w == null
		tab_buttons[t].set_pressed_no_signal(t == hire_tab)
	for card in path_cards:
		card["button"].visible = w != null
	sell_btn.visible = w != null
	target_btn.visible = w != null and w.uses_targeting()
	song_btn.visible = w != null and w.kind == "bard" and main.all_bards_present()
	if w == null:
		info_label.position = Vector2(14, 122)
		info_label.size = Vector2(ui_w - 26, 64)
		info_label.add_theme_font_size_override("font_size", 15)
		if main.placing_type == "barricade":
			var d: Dictionary = Data.WARRIORS["barricade"]
			info_label.text = ("Click where the wall starts, then where it ends (%dg + %dg per %s, as long as you can afford). Enemies go around walls if they can. Right-click cancels."
					% [roundi(d["cost_base"] * price_mult), roundi(d["cost_per_100"] * price_mult), Data.ft(100)])
		elif main.placing_type != "":
			info_label.text = "Click the field to post your hire there. Hold Shift to hire several. Right-click cancels."
		else:
			info_label.text = "Hire warriors to stop enemies reaching the bottom. Click a warrior to select it."
		return
	info_label.position = Vector2(14, 136)
	info_label.size = Vector2(ui_w - (332 if song_btn.visible else 244), 52)
	info_label.add_theme_font_size_override("font_size", 12 if ui_w < 900.0 else 14)
	var how := "right-click to send it somewhere" if main.wave_active else "drag to reposition"
	if w.is_emplacement():
		how = "holds its ground" if main.wave_active else "drag to reposition"
	if not w.uses_targeting():
		how += "  (no targeting)"
	info_label.text = "%s - %s   Upgrades %d/%d\n%s" % [w.data["name"], how, w.total_upgrades(), Warrior.MAX_UPGRADES, w.stats_text()]
	sell_btn.text = "Sell +%dg" % w.sell_value()
	target_btn.text = "Target [T]\n%s" % Warrior.PRIORITY_NAMES[w.priority]
	song_btn.text = "Song [G]\n%s" % ("On" if main.song_on else "Off")
	for p in path_cards.size():
		_refresh_card(path_cards[p], w, p, main.gold)


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
	card["title"] = _label(b, Vector2(6, 2), Vector2(138, 18), Warrior.PATH_COLORS[p], 13)
	card["title"].clip_text = true
	card["cost"] = _label(b, Vector2(74, 17), Vector2(70, 16), Color(1, 0.85, 0.3), 12)
	card["cost"].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for j in Warrior.MAX_TIER:
		var pip := ColorRect.new()
		pip.position = Vector2(6 + j * 14, 23)
		pip.size = Vector2(11, 5)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pip)
		card["pips"].append(pip)
	card["tier"] = _label(b, Vector2(6, 31), Vector2(138, 16), Color.WHITE, 12)
	card["tier"].clip_text = true
	card["desc"] = _label(b, Vector2(6, 46), Vector2(138, 36), Color(0.8, 0.8, 0.78), 11)
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
	b.disabled = state != "ok" or not affordable
	b.modulate.a = 0.45 if state == "full" else 1.0


func show_message(text: String) -> void:
	message_label.text = text
	if message_tween:
		message_tween.kill()
	message_label.modulate.a = 1.0
	message_tween = create_tween()
	message_tween.tween_interval(1.5)
	message_tween.tween_property(message_label, "modulate:a", 0.0, 0.6)


## The difficulty picker. Cards fly in one after another; hovering lifts a card, and
## picking one makes it pulse and burst while the others fall away, then the screen
## fades into the game.
func show_mode_select() -> void:
	picking = false
	mode_screen = ColorRect.new()
	mode_screen.color = Color(0, 0, 0, 0.0)
	mode_screen.size = Vector2(WIDTH, HEIGHT)
	add_child(mode_screen)
	_center(mode_screen)
	var bleed := _bleed(mode_screen)
	create_tween().tween_property(bleed, "color:a", 0.8, 0.4)

	var title := _label(mode_screen, Vector2(0, 130), Vector2(WIDTH, 70), Color(1, 0.85, 0.3), 54)
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
	var sub := _label(mode_screen, Vector2(0, 210), Vector2(WIDTH, 30), Color(0.85, 0.85, 0.85), 18)
	sub.text = "Choose your difficulty"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate.a = 0.0
	create_tween().tween_property(sub, "modulate:a", 1.0, 0.4).set_delay(0.35)

	var castle := Data.CASTLE_HP
	var modes := []
	for key in Data.DIFFICULTIES:
		var d: Dictionary = Data.DIFFICULTIES[key]
		var lines := ["Castle %d HP" % roundi(castle * d["castle"])]
		if d["cost"] < 1.0:
			lines.append("Everything %d%% cheaper" % roundi((1.0 - d["cost"]) * 100))
		elif d["cost"] > 1.0:
			lines.append("Everything %d%% pricier" % roundi((d["cost"] - 1.0) * 100))
		else:
			lines.append("Standard prices")
		lines.append("Fallen troops die in\n%ds unless revived" % int(d["down_time"]) if d["permadeath"] else "Fallen troops get\nback up after %ds" % int(d["down_time"]))
		modes.append([key, d["name"], "\n".join(lines), d["color"], d["icon"]])
	modes.append(["freeplay", "Freeplay", "Unlimited gold\nSpawn any wave\nor enemy\nThe castle can't fall", Color(0.55, 0.8, 1.0), "mage"])
	modes.append(["tutorial", "Tutorial", "Learn the basics\nstep by step\nThe castle can't fall", Color(0.75, 1.0, 0.55), "bard"])
	# Three cards on top, three below.
	var spots := [Vector2(20, 270), Vector2(225, 270), Vector2(430, 270), Vector2(20, 470), Vector2(225, 470), Vector2(430, 470)]
	var cards := []
	for i in modes.size():
		cards.append(_mode_card(modes[i], spots[i], 0.25 + i * 0.09))
	for i in cards.size():
		var key: String = modes[i][0]
		var card: Button = cards[i]
		card.pressed.connect(func(): _pick_mode(key, card, cards, title, sub))


func _mode_card(m: Array, at: Vector2, delay: float) -> Button:
	var b := _button(mode_screen, at + Vector2(0, 420), Vector2(190, 180), "")
	b.pivot_offset = b.size / 2
	b.modulate.a = 0.0
	var name := _label(b, Vector2(0, 10), Vector2(190, 36), m[3], 28)
	name.text = m[1]
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_color_override("font_outline_color", Color.BLACK)
	name.add_theme_constant_override("outline_size", 4)
	var icon := TextureRect.new()
	icon.texture = Sprites.frames(m[4])[0]
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = Vector2(48, 48)
	icon.position = Vector2(71, 46)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var desc := _label(b, Vector2(0, 98), Vector2(190, 80), Color(0.85, 0.85, 0.85), 13)
	desc.text = m[2]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Fly in from below, settling with a little overshoot.
	var t := create_tween().set_parallel()
	t.tween_property(b, "position", at, 0.55).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "modulate:a", 1.0, 0.3).set_delay(delay)
	# The character on the card bobs up and down, each a little out of step.
	var bob := create_tween().set_loops()
	bob.tween_property(icon, "position:y", 40.0, 0.5 + delay * 0.3).set_trans(Tween.TRANS_SINE)
	bob.tween_property(icon, "position:y", 46.0, 0.5 + delay * 0.3).set_trans(Tween.TRANS_SINE)
	icon.tree_exiting.connect(bob.kill)
	# Hovering lifts the card.
	b.mouse_entered.connect(func():
		if not picking:
			create_tween().tween_property(b, "scale", Vector2(1.07, 1.07), 0.12))
	b.mouse_exited.connect(func():
		if not picking:
			create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))
	return b


## The picked card pulses and bursts, the rest fall away, then the screen fades out
## and the game starts.
func _pick_mode(key: String, card: Button, cards: Array, title: Label, sub: Label) -> void:
	if picking:
		return
	picking = true
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
	out.tween_property(mode_screen.get_child(0), "color:a", 0.0, 0.3)   # the dimming backdrop (see _bleed)
	out.tween_callback(func(): mode_chosen.emit(key))


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
	# Sound: music and effects volume (saved for next time).
	var audio = get_parent().audio
	if audio != null:
		var rows := [["Music", audio.music_volume, audio.set_music_volume], ["Effects", audio.sfx_volume, audio.set_sfx_volume]]
		for i in rows.size():
			var y := 550.0 + i * 44.0
			var l := _label(dim, Vector2(150, y), Vector2(90, 30), Color(0.9, 0.9, 0.85), 18)
			l.text = rows[i][0]
			var slider := HSlider.new()
			slider.position = Vector2(240, y + 4)
			slider.size = Vector2(250, 24)
			slider.min_value = 0.0
			slider.max_value = 1.0
			slider.step = 0.05
			slider.value = rows[i][1]
			slider.focus_mode = Control.FOCUS_NONE
			var setter: Callable = rows[i][2]
			slider.value_changed.connect(func(v): setter.call(v))
			if i == 1:
				slider.drag_ended.connect(func(_changed): audio.play("coin"))   # a sample at the new volume
			dim.add_child(slider)


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
	sub.text = "You held out through all %d waves.\nKeep going? From here enemies toughen faster and gold\nearns 40%% less - see how far you can get." % wave
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
