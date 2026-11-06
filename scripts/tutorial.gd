extends Control
## Tutorial mode: a panel at the top of the field walks a new player through the
## basics one step at a time. Each step either waits for the player to do something
## (hire a Swordsman, start a wave, buy an upgrade...) or has a Next button, and a
## pulsing outline points at the button to use. The castle can't fall meanwhile.

const Barricade = preload("res://scripts/barricade.gd")
const Data = preload("res://scripts/data.gd")
const WIDTH := 640.0
const MIN_SHOW := 0.6   # a step that's already done still shows this long before moving on

var main
var hud
var step := 0
var shown := 0.0
var panel: Panel
var title: Label
var body: Label
var next_btn: Button
var skip_btn: Button
var outline: Panel
var finished := false

# Each step: [title, text, what to point at (see _target), when it's done (see _done) or "" for a Next button].
var steps := [
	["Welcome!", "Enemies march down from the top of the field. Stop them before they reach your castle at the bottom. (The castle can't fall in the tutorial.)", "", ""],
	["Hire a Swordsman", "Click the Swordsman button below (or press 1), then click the field to post him. Swordsmen are tough and hold enemies in place.", "hire:swordsman", "has:swordsman"],
	["Hire an Archer", "Archers shoot from long range but are fragile. Hire one (press 2) and post it behind your Swordsman.", "hire:archer", "has:archer"],
	["Gold", "Hiring costs gold (top left). You earn more for every enemy you defeat and every wave you clear.", "gold", ""],
	["Start the wave", "Ready? Press Start Wave (or Space) to send in the enemies.", "start", "wave_on"],
	["Hold the line!", "Your warriors find enemies and fight on their own. Watch them work until the wave is cleared.", "", "wave_done:1"],
	["Select a warrior", "Click one of your warriors to select it. Its upgrades and stats appear in the panel below.", "", "selected"],
	["Upgrade it", "These four cards are its upgrade paths. Buy an upgrade by clicking a card (or press Q, W, E or R).", "card", "upgraded"],
	["Upgrade paths", "Each unit can have 6 upgrades in all, spread over its four paths however you like. Tier 3 in a path changes its look and unlocks strong new powers.", "card", ""],
	["Targeting", "The Target button picks which enemy it goes after: the closest, the first in line, the strongest or the weakest. Try it (or press T), or press Next.", "target", "retargeted"],
	["Moving units", "Between waves, drag a unit to move it anywhere. During a wave, select it and right-click where it should go. Drag a box over open ground to select several and move them together. Hover over any unit to see what it does.", "", ""],
	["Emplacements", "Emplacements are built where you place them and never move. Open the Emplacements tab (or press X) and build an Archer Tower.", "tab:emplacements", "has:tower"],
	["Barricades", "Barricades are walls: pick Barricade, then click where it starts and where it ends. Enemies walk around walls if they can, and break through if they can't.", "hire:barricade", ""],
	["Another wave", "Start the next wave when you're ready.", "start", "wave_on"],
	["Keep it up", "Clear this wave too.", "", "wave_done:2"],
	["Handy controls", "Speed (or F) makes the game run faster. Click your castle (or press C) to upgrade it; the Abilities (V) and Repair (B) tabs arm and mend it. Auto (A) starts each wave by itself. Press Escape to cancel what you're placing.", "speed", ""],
	["Tutorial complete!", "You know the basics. Keep playing here (the castle still can't fall), or head back to the menu for a real game.", "", "end"],
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.08, 0.07, 0.92)
	style.border_color = Color(1.0, 0.85, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(20, 48)
	panel.size = Vector2(WIDTH - 40, 128)
	add_child(panel)
	title = _label(Vector2(14, 8), Vector2(WIDTH - 200, 26), Color(1.0, 0.85, 0.3), 20)
	body = _label(Vector2(14, 36), Vector2(WIDTH - 72, 60), Color(0.92, 0.92, 0.88), 15)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_btn = _button(Vector2(WIDTH - 156, 88), Vector2(100, 32), "Next")
	next_btn.pressed.connect(_advance)
	skip_btn = _button(Vector2(WIDTH - 156, 6), Vector2(100, 26), "Skip tutorial")
	skip_btn.add_theme_font_size_override("font_size", 12)
	skip_btn.pressed.connect(_finish)
	outline = Panel.new()
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(0, 0, 0, 0)
	ring.border_color = Color(1.0, 0.85, 0.3)
	ring.set_border_width_all(3)
	ring.set_corner_radius_all(4)
	outline.add_theme_stylebox_override("panel", ring)
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(outline)
	_show_step()


func _label(at: Vector2, size_: Vector2, color: Color, font_size: int) -> Label:
	var l := Label.new()
	l.position = at
	l.size = size_
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(l)
	return l


func _button(at: Vector2, size_: Vector2, text: String) -> Button:
	var b := Button.new()
	b.position = at
	b.size = size_
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	panel.add_child(b)
	return b


func _process(delta: float) -> void:
	if finished:
		return
	shown += delta
	# Keep the panel in the middle of a wide screen, like the other overlays.
	position.x = (hud.ui_w - WIDTH) / 2.0
	var s: Array = steps[step]
	if s[3] != "" and s[3] != "end" and shown >= MIN_SHOW and _done(s[3]):
		_advance()
		return
	_point_at(s[2])


func _show_step() -> void:
	var s: Array = steps[step]
	shown = 0.0
	title.text = "%s   (%d/%d)" % [s[0], step + 1, steps.size()]
	body.text = s[1]
	next_btn.visible = s[3] == "" or s[3] == "retargeted" or s[3] == "end"
	next_btn.text = "Next"
	skip_btn.visible = s[3] != "end"
	if s[3] == "end":
		next_btn.text = "Main menu"
		skip_btn.visible = true
		skip_btn.text = "Keep playing"
	# Show the right hire tab, and make sure there's gold for what this step asks for.
	var target: String = s[2]
	if target.begins_with("hire:") or s[3].begins_with("has:"):
		var kind: String = s[3].substr(4) if s[3].begins_with("has:") else target.substr(5)
		if kind != "" and Data.WARRIORS.has(kind):
			if target.begins_with("hire:"):
				main.switch_tab(hud.tab_of(kind))
			var need: int = main.hire_cost(kind)
			if main.gold < need:
				main.gold = need + 20
				main.spawn_text(Vector2(main.FIELD_W / 2.0, 300), "+gold for the tutorial", Color(1, 0.85, 0.3))
	if s[3] == "upgraded":
		var w = main.selected
		if w != null and main.gold < 40:
			main.gold = 60


func _advance() -> void:
	var s: Array = steps[step]
	if s[3] == "end":
		get_tree().paused = false
		main._restart()   # back to the menu
		return
	step += 1
	if step >= steps.size():
		_finish()
		return
	_show_step()


## Skip (or Keep playing at the end): the panel goes, the game carries on.
func _finish() -> void:
	finished = true
	queue_free()


func _done(cond: String) -> bool:
	if cond.begins_with("has:"):
		var kind := cond.substr(4)
		return main.get_warriors().any(func(w): return w.kind == kind)
	if cond.begins_with("wave_done:"):
		return main.wave >= int(cond.substr(10)) and not main.wave_active
	match cond:
		"wave_on":
			return main.wave_active
		"selected":
			return main.selected != null and not (main.selected is Barricade) and not main.selected.summoned
		"upgraded":
			return main.get_warriors().any(func(w): return w.total_upgrades() > 0)
		"retargeted":
			return main.get_warriors().any(func(w): return w.priority != "closest")
	return false


## Outline the control the step is about (or nothing).
func _point_at(what: String) -> void:
	var c: Control = _target(what)
	outline.visible = c != null and c.is_visible_in_tree()
	if not outline.visible:
		return
	var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 160.0)
	outline.modulate.a = pulse
	var r := Rect2(c.global_position - global_position, c.size).grow(4)
	outline.position = r.position
	outline.size = r.size


func _target(what: String) -> Control:
	if what.begins_with("hire:"):
		return hud.hire_buttons.get(what.substr(5))
	if what.begins_with("tab:"):
		var tab := what.substr(4)
		# Once the tab is open, point at the Archer Tower instead.
		return hud.hire_buttons["tower"] if hud.hire_tab == tab else hud.tab_buttons.get(tab)
	match what:
		"gold":
			return hud.gold_label
		"start":
			return hud.start_btn
		"card":
			return hud.path_cards[0]["button"] if not hud.path_cards.is_empty() else null
		"target":
			return hud.target_btn
		"speed":
			return hud.speed_btn
	return null
