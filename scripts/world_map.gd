extends Control
## The campaign map: the continent as pixel art (made in code like everything else, at
## a quarter of the screen's resolution and shown 4x), with each territory as a keep on
## the roads of the old Line. A keep's look tells its state:
##   hidden      not drawn (nor the roads to it)
##   locked      grey, with a padlock
##   available   reachable, nothing to defend there yet
##   attack      under attack: flames, and a red ring that pulses
##   allied      its people's banner, and a lit beacon on top
## Click a keep to see it in the panel below (who lives there, the mission, the threats
## and what joining brings); "Defend" starts its mission. The Alliance Ledger lists who
## has joined and what each people gives; the Training Grounds spend training points on
## higher upgrade tiers.

signal defend(mission_id: String)
signal menu
signal sound(name: String)
signal prologue

const Sprites = preload("res://scripts/sprites.gd")
const Data = preload("res://scripts/data.gd")
const CD = preload("res://scripts/campaign_data.gd")
const Story = preload("res://scripts/story.gd")
const Portraits = preload("res://scripts/portraits.gd")

const W := 640.0
const H := 1040.0
const PANEL_Y := 700.0
const PICK_R := 30.0
const OUTLINE := Color(0.1, 0.07, 0.1)
const COAST := [Vector2(44, 128), Vector2(96, 74), Vector2(184, 62), Vector2(300, 40), Vector2(424, 56),
	Vector2(560, 70), Vector2(612, 132), Vector2(598, 236), Vector2(626, 330), Vector2(588, 420),
	Vector2(616, 520), Vector2(566, 612), Vector2(474, 676), Vector2(340, 688), Vector2(196, 680),
	Vector2(92, 640), Vector2(40, 560), Vector2(62, 470), Vector2(24, 380), Vector2(56, 290), Vector2(28, 204)]
const RIVER := [Vector2(24, 396), Vector2(130, 384), Vector2(226, 372), Vector2(300, 364), Vector2(384, 374),
	Vector2(470, 360), Vector2(560, 378), Vector2(626, 366)]

var campaign            # the Campaign autoload
var ability_icon: Callable   # key -> Texture2D (the HUD's ability icons)
var selected := ""
var t := 0.0
var labels := {}
var info: Dictionary = {}   # the panel's controls
var reward_box: HBoxContainer
var threat_box: HBoxContainer
var mission_rows: VBoxContainer
var chosen := ""          # the mission picked in the selected region's list (what Defend plays)
const THREAT_W := 176.0   # the threats' column, left of what joining brings
var overlay: Control = null   # the Ledger, a story scene or an announcement, while one is up
var story_player := Callable()   # the HUD's play_story(lines, then): villains' lines get their own cutscenes
var training_kind := ""      # the unit picked in the Training Grounds


func _ready() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bake()
	for k in CD.TERRITORIES:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
		l.add_theme_color_override("font_outline_color", OUTLINE)
		l.add_theme_constant_override("outline_size", 5)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(150, 18)
		l.position = CD.TERRITORIES[k]["pos"] + Vector2(-75, 14)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.text = CD.TERRITORIES[k]["name"]
		add_child(l)
		labels[k] = l
	_build_header()
	_build_panel()
	selected = _default_selection()
	refresh()
	# Back from a win: its story, then the news of who joined.
	if campaign.pending_story != "":
		var key: String = campaign.pending_story
		campaign.pending_story = ""
		play_story(key, _announce_join)
	elif campaign.just_joined != "" or not _new_points().is_empty():
		_announce_join()


func _default_selection() -> String:
	for k in CD.TERRITORIES:
		if campaign.playable_mission(k) != "":
			return k
	return "ashwatch"


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


# --- Header and panel ---------------------------------------------------------

func _build_header() -> void:
	var title := _label(self, Vector2(16, 8), Vector2(300, 36), Color(1, 0.85, 0.3), 28)
	title.text = "The Line"
	title.add_theme_color_override("font_outline_color", OUTLINE)
	title.add_theme_constant_override("outline_size", 6)
	info["header"] = _label(self, Vector2(300, 14), Vector2(324, 24), Color(0.95, 0.93, 0.88), 15)
	info["header"].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info["header"].add_theme_color_override("font_outline_color", OUTLINE)
	info["header"].add_theme_constant_override("outline_size", 5)


func _build_panel() -> void:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.11, 0.1)
	style.border_color = Color(0.45, 0.35, 0.2)
	style.border_width_top = 3
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(0, PANEL_Y)
	panel.size = Vector2(W, H - PANEL_Y)
	add_child(panel)
	info["name"] = _label(panel, Vector2(16, 10), Vector2(420, 30), Color.WHITE, 22)
	info["state"] = _label(panel, Vector2(430, 14), Vector2(194, 24), Color.WHITE, 14)
	info["state"].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info["people"] = _label(panel, Vector2(16, 40), Vector2(530, 20), Color(0.75, 0.7, 0.62), 14)
	info["blurb"] = _label(panel, Vector2(16, 62), Vector2(530, 44), Color(0.9, 0.88, 0.84), 14)
	# The territory's leader, in the dress of their homeland.
	var lf := ColorRect.new()
	lf.color = Color(0.22, 0.18, 0.15)
	lf.position = Vector2(554, 40)
	lf.size = Vector2(72, 72)
	panel.add_child(lf)
	info["leader_frame"] = lf
	var lp := TextureRect.new()
	lp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lp.position = Vector2(4, 4)
	lp.size = Vector2(64, 64)
	lf.add_child(lp)
	info["leader"] = lp
	info["blurb"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info["mission"] = _label(panel, Vector2(16, 110), Vector2(530, 40), Color(1, 0.85, 0.3), 14)
	info["mission"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# The region's missions, one row each: pick one to play (or play again), or watch its story.
	mission_rows = VBoxContainer.new()
	mission_rows.position = Vector2(16, 108)
	mission_rows.size = Vector2(608, 0)
	mission_rows.add_theme_constant_override("separation", 3)
	panel.add_child(mission_rows)
	info["threat_title"] = _label(panel, Vector2(16, 152), Vector2(100, 18), Color(1, 0.55, 0.45), 12)
	info["threat_title"].text = "THREATS"
	threat_box = HBoxContainer.new()
	threat_box.position = Vector2(16, 170)
	threat_box.add_theme_constant_override("separation", 4)
	panel.add_child(threat_box)
	info["reward_title"] = _label(panel, Vector2(200, 152), Vector2(420, 18), Color(0.6, 0.95, 0.6), 12)
	reward_box = HBoxContainer.new()
	reward_box.position = Vector2(200, 170)
	reward_box.add_theme_constant_override("separation", 6)
	panel.add_child(reward_box)
	info["defend"] = _button(panel, Vector2(16, 270), Vector2(176, 52), "Defend")
	info["defend"].add_theme_font_size_override("font_size", 20)
	info["defend"].pressed.connect(_on_defend)
	info["training"] = _button(panel, Vector2(202, 270), Vector2(150, 52), "Training")
	info["training"].pressed.connect(show_training)
	info["ledger"] = _button(panel, Vector2(362, 270), Vector2(136, 52), "Ledger")
	info["ledger"].tooltip_text = "The Alliance Ledger: who has joined the Line, and what they bring"
	info["ledger"].pressed.connect(show_ledger)
	info["menu"] = _button(panel, Vector2(508, 270), Vector2(116, 52), "Menu")
	info["menu"].pressed.connect(func(): menu.emit())


func refresh() -> void:
	info["header"].text = "%s  ·  Alliances %d/%d  ·  Beacons %d/%d" % [Data.DIFFICULTIES[campaign.difficulty]["name"], campaign.alliance_count(), CD.FACTIONS.size(),
			campaign.beacon_count(), campaign.beacon_territories().size()]
	var pts := 0
	for kind in campaign.trainable():
		pts += campaign.points(kind)
	info["training"].text = "Training (%d)" % pts if pts > 0 else "Training"
	info["training"].add_theme_color_override("font_color", Color(1, 0.85, 0.3) if pts > 0 else Color(0.9, 0.9, 0.9))
	for k in labels:
		var st: String = campaign.territory_state(k)
		labels[k].visible = st != "hidden"
		labels[k].add_theme_color_override("font_color", Color(0.7, 0.7, 0.7) if st == "locked" else Color(1, 0.97, 0.88))
	_show_info(selected)


func _show_info(k: String) -> void:
	var d: Dictionary = CD.TERRITORIES[k]
	var st: String = campaign.territory_state(k)
	var f: String = d["faction"]
	info["name"].text = d["name"]
	info["name"].add_theme_color_override("font_color", CD.FACTIONS[f]["color"] if f != "" else Color(1, 0.85, 0.3))
	var prog: Array = campaign.progress(k)
	info["state"].text = {"locked": "Locked", "available": "Open", "attack": "Under attack!",
			"unfinished": ("Allied" if f != "" else "Held") + "  ·  %d/%d" % prog, "secured": "Beacon lit" if campaign.has_beacon(k) else "Held", "hidden": ""}[st]
	info["state"].add_theme_color_override("font_color", {"locked": Color(0.7, 0.7, 0.7), "available": Color(0.9, 0.85, 0.6),
			"attack": Color(1, 0.45, 0.35), "unfinished": Color(0.75, 0.95, 0.6), "secured": Color(1, 0.85, 0.35), "hidden": Color.WHITE}[st])
	if f != "":
		info["people"].text = CD.FACTIONS[f]["name"]
	elif k == "ashwatch":
		info["people"].text = "Your keep"
	else:
		info["people"].text = "Story battle"
	info["blurb"].text = d["blurb"]
	var leader: String = CD.FACTIONS[f]["leader"] if f != "" else ("hale" if k == "ashwatch" else "")
	info["leader_frame"].visible = leader != "" and st != "locked"
	if leader != "":
		info["leader"].texture = Portraits.texture(leader, CD.SPEAKERS[leader]["look"])
		info["leader_frame"].tooltip_text = CD.SPEAKERS[leader]["name"]
	var listed := _region_missions(k)
	if not listed.has(chosen):
		chosen = _mission_here(k)
	var mid: String = chosen
	var m: Dictionary = campaign.missions.get(mid, {})
	var optional: bool = mid != "" and (d.get("optional", []) as Array).has(mid)
	info["state"].tooltip_text = ("Light its beacon to open Tier IV training for %s." if st != "secured" else "Its beacon burns: Tier IV training is open for %s.") \
			% _kind_names(campaign.tier4_kinds(k)) if f != "" and not campaign.tier4_kinds(k).is_empty() else ""
	for c in mission_rows.get_children():
		c.queue_free()
	var rows := st in ["attack", "unfinished", "secured"] and not listed.is_empty()
	info["mission"].visible = not rows
	mission_rows.visible = rows
	match st:
		"locked":
			info["mission"].text = "To reach it: " + campaign.requirement_text(k)
		"available":
			info["mission"].text = "No battle here yet. This territory's story arrives in a later update."
		"secured":
			info["mission"].text = "Secured."
	if rows:
		for id in listed:
			mission_rows.add_child(_mission_row(k, id))
	# Threats: the enemies the mission sends.
	for c in threat_box.get_children():
		c.queue_free()
	info["threat_title"].visible = not m.is_empty()
	if not m.is_empty():
		var kinds := []
		for w in m["pool"]:
			for e in m["pool"][w]:
				if not kinds.has(e):
					kinds.append(e)
		for w in m.get("extra", {}):
			for e in m["extra"][w]:
				if not kinds.has(e):
					kinds.append(e)
		# As many as there are, shrunk to fit their column (left of what joining brings).
		var size := clampf((THREAT_W - 4.0 * (kinds.size() - 1)) / maxf(kinds.size(), 1), 18.0, 34.0)
		for e in kinds:
			threat_box.add_child(_icon(Sprites.frames(e)[0], (e as String).capitalize(), size))
	# The rows below the mission text start under however many lines it took.
	var ml: Label = info["mission"]
	var font: Font = ml.get_theme_font("font")
	var tall: float = font.get_multiline_string_size(ml.text, HORIZONTAL_ALIGNMENT_LEFT, ml.size.x, ml.get_theme_font_size("font_size"), -1,
			TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND).y
	var row_y := 110.0 + maxf(tall, 38.0) + 4.0
	if mission_rows.visible:
		row_y = 112.0 + listed.size() * 29.0
	info["threat_title"].position.y = row_y
	info["reward_title"].position.y = row_y
	threat_box.position.y = row_y + 18.0
	reward_box.position.y = row_y + 18.0
	# Rewards: what joining brings.
	for c in reward_box.get_children():
		c.queue_free()
	var unlocks: Array = CD.FACTIONS[f]["unlocks"] if f != "" and not campaign.joined(k) else []   # (once they've joined, it's in the Ledger)
	info["reward_title"].visible = not unlocks.is_empty()
	info["reward_title"].text = "JOINED THE LINE, THEY BRING" if campaign.joined(k) else "IF THEY JOIN THE LINE"
	for key in unlocks:
		reward_box.add_child(_reward(key))
	info["defend"].disabled = mid == "" or not _can_play(k, mid)
	info["defend"].text = ("Replay" if campaign.completed.has(mid) else ("Play" if optional else "Defend")) if mid != "" \
			else ("Secured" if st == "secured" else ("Allied" if f != "" else "Held"))


func _on_defend() -> void:
	if chosen != "" and _can_play(selected, chosen):
		defend.emit(chosen)


## Territory k's missions, as the list shows them: the required ones in order, then the
## optional ones once its people have joined.
func _region_missions(k: String) -> Array:
	var out: Array = (CD.TERRITORIES[k]["missions"] as Array).duplicate()
	if campaign.joined(k):
		out += CD.TERRITORIES[k].get("optional", [])
	return out.filter(func(id): return campaign.missions.has(id))


## Whether mission id (in territory k) can be played now: won already (to play again), the
## next required one, or an optional one that's open.
func _can_play(k: String, id: String) -> bool:
	if campaign.completed.has(id):
		return campaign.mission_open(id)
	if id == campaign.playable_mission(k):
		return true
	return campaign.optional_missions(k).has(id)


## One row of the region's mission list: its state, name and length, picked by a click;
## and a Story button to watch its scenes again (the intro once seen, the outro once won).
func _mission_row(k: String, id: String) -> Control:
	var m: Dictionary = campaign.missions[id]
	var optional: bool = (CD.TERRITORIES[k].get("optional", []) as Array).has(id)
	var won: bool = campaign.completed.has(id)
	var state := "Won" if won else ("Next" if id == campaign.playable_mission(k) else ("Optional" if optional else "Later"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var pick := Button.new()
	pick.focus_mode = Control.FOCUS_NONE
	pick.custom_minimum_size = Vector2(500, 26)
	pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	pick.add_theme_font_size_override("font_size", 13)
	var extra := ""
	var bonus: Dictionary = m.get("bonus_points", {})
	if optional and not bonus.is_empty() and not won:
		extra = "  ·  first win: " + ", ".join(bonus.keys().map(func(kind): return "+%d %s point" % [bonus[kind], Data.WARRIORS[kind]["name"]]))
	pick.text = "%s   %s  ·  %s%s" % [{"Won": "✓", "Next": "▶", "Optional": "◇", "Later": "·"}[state], m["name"], campaign.length_text(m), extra]
	var col: Color = {"Won": Color(0.75, 0.95, 0.6), "Next": Color(1, 0.85, 0.3), "Optional": Color(0.85, 0.8, 1.0), "Later": Color(0.6, 0.58, 0.55)}[state]
	pick.add_theme_color_override("font_color", col)
	pick.add_theme_color_override("font_hover_color", col.lightened(0.2))
	var sel := StyleBoxFlat.new()
	sel.bg_color = Color(0.32, 0.26, 0.16) if id == chosen else Color(0.18, 0.15, 0.13)
	sel.border_color = Color(1, 0.85, 0.35) if id == chosen else Color(0.3, 0.25, 0.2)
	sel.set_border_width_all(1)
	sel.set_corner_radius_all(3)
	sel.content_margin_left = 8
	for st_name in ["normal", "hover", "pressed"]:
		pick.add_theme_stylebox_override(st_name, sel)
	var tip := "Won: play it again any time (replays earn half XP)." if won else ("Play it now." if state != "Later" else "Win the missions before it first.")
	if not (m.get("lend", []) as Array).is_empty():
		tip += "\nThe locals lend you: " + ", ".join(m["lend"].filter(func(x): return x != CD.LEND_BUILDERS).map(unlock_name))
	pick.tooltip_text = tip
	pick.pressed.connect(func():
		chosen = id
		sound.emit("click")
		_show_info(k))
	row.add_child(pick)
	var story := Button.new()
	story.focus_mode = Control.FOCUS_NONE
	story.custom_minimum_size = Vector2(96, 26)
	story.add_theme_font_size_override("font_size", 13)
	story.text = "Story"
	var keys := []
	if m.get("intro", "") != "" and (won or campaign.seen.has(m["intro"])):
		keys.append(m["intro"])
	if won and m.get("outro", "") != "":
		keys.append(m["outro"])
	story.disabled = keys.is_empty()
	story.tooltip_text = "Watch this mission's scenes again" if not keys.is_empty() else "Its scenes play when you first take it on"
	story.pressed.connect(func(): _replay_story(keys))
	row.add_child(story)
	return row


## The mission list as text, one row a line (for tests and tooltips).
func rows_text() -> String:
	var out := []
	for row in mission_rows.get_children():
		if not row.is_queued_for_deletion():
			out.append(row.get_child(0).text)
	return "\n".join(out)


## Plays story keys one after another (the intro, then the outro).
func _replay_story(keys: Array) -> void:
	if keys.is_empty() or overlay != null:
		return
	var rest := keys.slice(1)
	play_story(keys[0], func(): _replay_story(rest) if not rest.is_empty() else null)


## The mission Defend plays in territory k: the next required one if it can be played;
## otherwise an optional one (one not yet won first, then any, to play it again).
func _mission_here(k: String) -> String:
	var mid: String = campaign.playable_mission(k)
	if mid != "":
		return mid
	var opts: Array = campaign.optional_missions(k)
	for o in opts:
		if not campaign.completed.has(o):
			return o
	return opts[0] if not opts.is_empty() else ""


func _optional_text(mid: String) -> String:
	var m: Dictionary = campaign.missions[mid]
	var text := "Optional: %s  ·  %s" % [m["name"], campaign.length_text(m)]
	var bonus: Dictionary = m.get("bonus_points", {})
	if not bonus.is_empty():
		var parts: Array = bonus.keys().map(func(kind): return "+%d %s training point%s" % [bonus[kind], Data.WARRIORS[kind]["name"], "" if bonus[kind] == 1 else "s"])
		text += ("  ·  won: " if campaign.completed.has(mid) else "  ·  first win: ") + ", ".join(parts)
	return text


## "Archers and Archer Towers": unit kinds by name, for the beacon lines.
func _kind_names(kinds: Array) -> String:
	var names: Array = kinds.map(func(k): return Data.WARRIORS[k]["name"] + "s")
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, -1)) + " and " + names[-1]


# --- Unlock names and icons ---------------------------------------------------

func unlock_name(key: String) -> String:
	if key.begins_with("ability:"):
		return Data.ABILITIES[key.substr(8)]["name"]
	if key.begins_with("path:"):
		return "%s (castle)" % Data.CASTLE_PATHS[int(key.substr(5))]["name"]
	if key == "repair":
		return "Castle repairs"
	return Data.WARRIORS[key]["name"]


func unlock_icon(key: String):
	if key.begins_with("ability:"):
		return ability_icon.call(key.substr(8)) if ability_icon.is_valid() else null
	if key == "repair" or key == "path:0":
		return Sprites.frames("engineer")[0]
	if key == "path:1":
		return Sprites.frames("archer")[0]
	if key == "path:2" or key == "path:3":
		return Sprites.frames("mage")[0]
	if Sprites.MOUNT_CREW.has(key):
		return Sprites.mount_icon(key)
	return Sprites.frames(key)[0]


func _reward(key: String) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(66, 0)
	box.add_theme_constant_override("separation", 0)
	box.tooltip_text = unlock_name(key)
	var icon = unlock_icon(key)
	box.add_child(_icon(icon, unlock_name(key), 40))
	var l := Label.new()
	l.text = unlock_name(key).replace(" (castle)", "")
	l.add_theme_font_size_override("font_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(66, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	return box


func _icon(tex, tip: String, s: float) -> Control:
	var r := TextureRect.new()
	r.texture = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if tex is Texture2D and tex.get_width() <= 24 else CanvasItem.TEXTURE_FILTER_LINEAR
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(s, s)
	r.tooltip_text = tip
	return r


# --- Input --------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if overlay != null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.position.y < PANEL_Y:
		var k := territory_at(event.position)
		if k != "":
			select(k)
			accept_event()


func territory_at(p: Vector2) -> String:
	var best := ""
	var best_d := PICK_R
	for k in CD.TERRITORIES:
		if campaign.territory_state(k) == "hidden":
			continue
		var d: float = (CD.TERRITORIES[k]["pos"] as Vector2).distance_to(p)
		if d < best_d:
			best_d = d
			best = k
	return best


func select(k: String) -> void:
	if k != selected:
		chosen = ""
	selected = k
	_show_info(k)


# --- Overlays: story, ledger, the news that a people joined --------------------

func play_story(key: String, then: Callable = Callable()) -> void:
	var lines: Array = campaign.story_lines(key)
	campaign.mark_seen(key)
	if lines.is_empty():
		if then.is_valid():
			then.call()
		return
	if story_player.is_valid():
		# The HUD plays it over the map, splitting off the villains' lines as cutscenes.
		overlay = Control.new()   # (a stand-in: keeps the map's clicks off while it plays)
		var hold := overlay
		story_player.call(lines, func():
			hold.free()
			overlay = null
			if then.is_valid():
				then.call())
		return
	var s := Story.new()
	s.setup(lines)
	overlay = s
	s.finished.connect(func():
		overlay = null
		if then.is_valid():
			then.call())
	add_child(s)


## A beacon was lit in the battle just won: the region is secured, and its people's
## units can now train Tier IV (nothing is granted: the points still have to be spent).
func _announce_beacon() -> void:
	var t: String = campaign.just_lit
	campaign.just_lit = ""
	var d: Dictionary = CD.TERRITORIES[t]
	var f: String = d["faction"]
	var col: Color = CD.FACTIONS[f]["color"] if f != "" else Color(1, 0.85, 0.3)
	var dim := _dim()
	var panel := _panel(dim, Rect2(50, 360, 540, 250), Color(1, 0.8, 0.3))
	var title := _label(panel, Vector2(0, 22), Vector2(540, 34), col, 26)
	title.text = "%s stands with the Line!" % d["name"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(panel, Vector2(30, 70), Vector2(480, 30), Color(1, 0.85, 0.35), 17)
	sub.text = "Its beacon is lit."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var kinds: Array = campaign.tier4_kinds(t)
	var body := _label(panel, Vector2(30, 104), Vector2(480, 70), Color(0.9, 0.88, 0.84), 15)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.text = ("Tier IV %s training is now available at the Training Grounds, for any path already trained to Tier III." % _kind_names(kinds)) if not kinds.is_empty() else ""
	var ok := _button(panel, Vector2(170, 184), Vector2(200, 50), "Onward")
	ok.pressed.connect(func():
		overlay = null
		dim.queue_free()
		_announce_join())
	sound.emit("fanfare")


## Unit kinds the last battle levelled up: kind -> training points it earned.
func _new_points() -> Dictionary:
	var out := {}
	for kind in campaign.last_battle:
		if int(campaign.last_battle[kind][1]) > 0:
			out[kind] = int(campaign.last_battle[kind][1])
	return out


func _announce_join() -> void:
	if campaign.just_lit != "":
		_announce_beacon()
		return
	var f: String = campaign.just_joined
	var gained := _new_points()
	var pts := 0
	for kind in gained:
		pts += gained[kind]
	campaign.just_joined = ""
	campaign.last_battle = {}
	refresh()
	if f == "" and pts <= 0:
		return
	var col: Color = CD.FACTIONS[f]["color"] if f != "" else Color(1, 0.85, 0.3)
	var dim := _dim()
	var panel := _panel(dim, Rect2(50, 290, 540, 360) if f != "" else Rect2(50, 380, 540, 220), col)
	var title := _label(panel, Vector2(0, 18), Vector2(540, 34), col, 26)
	title.text = "%s joins the Line!" % CD.FACTIONS[f]["name"] if f != "" else "The line holds!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var y := 60.0
	if f != "":
		var faction: Dictionary = CD.FACTIONS[f]
		var sub := _label(panel, Vector2(30, y), Vector2(480, 44), Color(0.9, 0.88, 0.84), 15)
		sub.text = "From now on, in every battle: %s." % faction["gives"].replace("Engineers: ", "Engineers for ")
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.position = Vector2(20, 116)
		row.size = Vector2(500, 110)
		row.add_theme_constant_override("separation", 10)
		panel.add_child(row)
		for key in faction["unlocks"]:
			row.add_child(_reward(key))
		y = 236.0
	if pts > 0:
		var names := []
		for kind in gained:
			names.append("%s +%d" % [Data.WARRIORS[kind]["name"], gained[kind]])
		var tp := _label(panel, Vector2(30, y), Vector2(480, 64), Color(1, 0.85, 0.3), 16)
		tp.text = "Training points earned in battle: %s. Spend them at the Training Grounds." % ", ".join(names)
		tp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ok := _button(panel, Vector2(170, panel.size.y - 70), Vector2(200, 50), "Onward")
	ok.pressed.connect(func():
		overlay = null
		dim.queue_free())
	sound.emit("fanfare")


func show_ledger() -> void:
	if overlay != null:
		return
	var dim := _dim()
	var panel := _panel(dim, Rect2(16, 40, 608, 960), Color(1, 0.85, 0.3))
	var title := _label(panel, Vector2(0, 12), Vector2(608, 34), Color(1, 0.85, 0.3), 26)
	title.text = "Alliance Ledger"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(panel, Vector2(0, 46), Vector2(608, 20), Color(0.75, 0.7, 0.62), 14)
	sub.text = "%d of %d peoples have joined the Line" % [campaign.alliance_count(), CD.FACTIONS.size()]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var y := 76.0
	for f in CD.FACTIONS:
		var faction: Dictionary = CD.FACTIONS[f]
		var home := _home_of(f)
		var st: String = campaign.territory_state(home) if home != "" else "hidden"
		var joined: bool = campaign.allied(f)
		var known := joined or st != "hidden"
		var name := _label(panel, Vector2(16, y), Vector2(360, 24), faction["color"] if known else Color(0.5, 0.5, 0.5), 18)
		name.text = faction["name"] if known else "Undiscovered"
		var status := _label(panel, Vector2(380, y + 2), Vector2(212, 22), Color(0.55, 1.0, 0.55) if joined else Color(0.7, 0.7, 0.7), 14)
		status.text = ("Beacon lit" if campaign.beacon_lit(home) else "Allied") if joined else ("Not yet allied" if known else "")
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var where := _label(panel, Vector2(16, y + 24), Vector2(576, 20), Color(0.75, 0.7, 0.62), 13)
		where.text = "%s  ·  %s" % [faction["home"], faction["gives"]] if known else "Somewhere beyond the roads you know."
		where.clip_text = true
		var row := HBoxContainer.new()
		row.position = Vector2(16, y + 46)
		row.add_theme_constant_override("separation", 4)
		row.modulate = Color.WHITE if joined else Color(1, 1, 1, 0.35)
		panel.add_child(row)
		if known:
			for key in faction["unlocks"]:
				row.add_child(_icon(unlock_icon(key), unlock_name(key), 30))
		y += 104.0
	var close := _button(panel, Vector2(320, 900), Vector2(200, 46), "Close")
	close.pressed.connect(func():
		overlay = null
		dim.queue_free())
	var again := _button(panel, Vector2(88, 900), Vector2(200, 46), "Replay the prologue")
	again.pressed.connect(func():
		overlay = null
		dim.queue_free()
		prologue.emit())


## The Training Grounds: every unit the Line can field, with the level its battles have
## earned it. Pick one to spend its training points, a tier of one upgrade path at a time.
func show_training() -> void:
	if overlay != null:
		return
	var dim := _dim()
	_fill_training(dim)


func _fill_training(dim: Control) -> void:
	for c in dim.get_children():
		c.queue_free()
	var kinds: Array = campaign.trainable()
	if not kinds.has(training_kind):
		training_kind = kinds[0] if not kinds.is_empty() else ""
		for kind in kinds:
			if campaign.points(kind) > 0:
				training_kind = kind
				break
	var panel := _panel(dim, Rect2(16, 40, 608, 960), Color(1, 0.85, 0.3))
	var title := _label(panel, Vector2(0, 12), Vector2(608, 34), Color(1, 0.85, 0.3), 26)
	title.text = "Training Grounds"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var help := _label(panel, Vector2(24, 48), Vector2(560, 60), Color(0.75, 0.7, 0.62), 13)
	help.text = "Units learn by doing: damage dealt, wounds healed, gold dug, blows taken. Each level a unit reaches gives it a training point, and a point opens the next tier of one of its upgrade paths. Twelve points train a unit fully."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The units, four to a row.
	for i in kinds.size():
		var kind: String = kinds[i]
		var tile := Button.new()
		tile.position = Vector2(16 + (i % 4) * 146, 116 + (i / 4) * 80)
		tile.size = Vector2(140, 74)
		tile.focus_mode = Control.FOCUS_NONE
		tile.toggle_mode = true
		tile.button_pressed = kind == training_kind
		tile.tooltip_text = Data.WARRIORS[kind]["name"]
		tile.pressed.connect(func():
			training_kind = kind
			_fill_training(dim))
		panel.add_child(tile)
		var icon := _icon(unlock_icon(kind), Data.WARRIORS[kind]["name"], 36)
		icon.position = Vector2(6, 6)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(icon)
		var nm := _label(tile, Vector2(46, 4), Vector2(92, 20), Data.WARRIORS[kind]["color"], 13)
		nm.text = Data.WARRIORS[kind]["name"]
		nm.clip_text = true
		var lv := _label(tile, Vector2(46, 24), Vector2(92, 20), Color(0.9, 0.88, 0.84), 13)
		lv.text = "Level %d" % campaign.level_of(kind)
		var pts: int = campaign.points(kind)
		if pts > 0:
			var badge := _label(tile, Vector2(46, 42), Vector2(92, 18), Color(1, 0.85, 0.3), 12)
			badge.text = "%d point%s" % [pts, "" if pts == 1 else "s"]
		var prog: Array = campaign.level_progress(kind)
		var bar_bg := ColorRect.new()
		bar_bg.color = Color(0.1, 0.09, 0.08)
		bar_bg.position = Vector2(6, 64)
		bar_bg.size = Vector2(128, 5)
		bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(bar_bg)
		var bar := ColorRect.new()
		bar.color = Color(0.55, 0.85, 0.4)
		bar.position = bar_bg.position
		bar.size = Vector2(128.0 * (1.0 if prog[1] <= 0.0 else prog[0] / prog[1]), 5)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(bar)
		for c in [nm, lv]:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The picked unit: its level, its points, and its four paths.
	if training_kind != "":
		var kind := training_kind
		var d: Dictionary = Data.WARRIORS[kind]
		var top := 116.0 + ceilf(kinds.size() / 4.0) * 80.0 + 10.0
		var name := _label(panel, Vector2(24, top), Vector2(400, 30), d["color"], 22)
		name.text = d["name"]
		var prog: Array = campaign.level_progress(kind)
		var lvl := _label(panel, Vector2(24, top + 32), Vector2(560, 20), Color(0.85, 0.82, 0.76), 14)
		lvl.text = "Level %d  ·  %s%s" % [campaign.level_of(kind), "%d / %d XP to the next point" % [roundi(prog[0]), roundi(prog[1])] if prog[1] > 0.0 else "top level",
				"  ·  catching up: double XP" if campaign.catching_up(kind) else ""]
		var pts_l := _label(panel, Vector2(380, top + 4), Vector2(204, 24), Color(1, 0.85, 0.3), 16)
		var pts: int = campaign.points(kind)
		pts_l.text = "%d point%s to spend" % [pts, "" if pts == 1 else "s"] if pts > 0 else ("Fully trained" if campaign.untrained_tiers(kind) == 0 else "No points yet")
		pts_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var waiting: int = campaign.points_waiting(kind)
		if waiting > 0:
			var wl := _label(panel, Vector2(300, top + 28), Vector2(284, 20), Color(1, 0.6, 0.4), 12)
			wl.text = "%d wait for %s's beacon (Tier IV)" % [waiting, CD.TERRITORIES[campaign.region_of(kind)]["name"]]
			wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var row_h := minf(84.0, (880.0 - (top + 60.0)) / 4.0)
		for p in 4:
			var path: Dictionary = d["paths"][p]
			var y := top + 60.0 + p * row_h
			var row := Panel.new()
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.18, 0.15, 0.13)
			style.set_corner_radius_all(4)
			row.add_theme_stylebox_override("panel", style)
			row.position = Vector2(16, y)
			row.size = Vector2(576, row_h - 6.0)
			panel.add_child(row)
			var pn := _label(row, Vector2(10, 4), Vector2(220, 22), Color(1, 0.95, 0.85), 16)
			pn.text = path["name"]
			var tier: int = campaign.path_tier(kind, p)
			for i in 4:
				var pip := _label(row, Vector2(10 + i * 30, 28), Vector2(28, 20), Color(1, 0.85, 0.3) if i < tier else Color(0.4, 0.38, 0.35), 15)
				pip.text = ["I", "II", "III", "IV"][i]
				pip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if tier < 4:
				var nt: Dictionary = path["tiers"][tier]
				var desc := _label(row, Vector2(140, 26), Vector2(250, row_h - 34.0), Color(0.72, 0.68, 0.62), 12)
				desc.text = "Next: %s. %s" % [nt["name"], nt["desc"]]
				desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				desc.clip_text = true
			var b := _button(row, Vector2(400, (row_h - 6.0) / 2.0 - 20.0), Vector2(166, 40), "Fully open" if tier >= 4 else "Open tier %s · 1 pt" % ["I", "II", "III", "IV"][tier])
			b.disabled = not campaign.can_unlock(kind, p)
			var why: String = campaign.tier_lock_reason(kind, p)
			if why != "":
				b.text = "Tier IV locked"
				b.tooltip_text = why + "."
				var lock := _label(row, Vector2(140, row_h - 26.0), Vector2(256, 18), Color(1, 0.6, 0.4), 11)
				lock.text = "Needs %s's beacon lit" % CD.TERRITORIES[campaign.region_of(kind)]["name"]
			b.pressed.connect(func():
				if campaign.unlock(kind, p):
					sound.emit("upgrade")
					refresh()
					_fill_training(dim))
	var close := _button(panel, Vector2(204, 900), Vector2(200, 46), "Done")
	close.pressed.connect(func():
		overlay = null
		dim.queue_free())


func _home_of(f: String) -> String:
	for k in CD.TERRITORIES:
		if CD.TERRITORIES[k]["faction"] == f:
			return k
	return ""


func _dim() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = Vector2(W, H)
	add_child(dim)
	overlay = dim
	return dim


func _panel(parent: Control, r: Rect2, border: Color) -> Panel:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.09, 0.08, 0.97)
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = r.position
	panel.size = r.size
	parent.add_child(panel)
	return panel


func _label(parent: Node, pos: Vector2, sz: Vector2, color: Color, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(parent: Node, pos: Vector2, sz: Vector2, text: String) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = sz
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b


# --- Drawing ----------------------------------------------------------------------
# The continent is a 160x175 picture (one pixel per 4 screen pixels), made once in
# _bake(): sea with foam and shallows, a sandy coast, dithered grass and snow, the
# river, and stamps for mountains, pines, rooftops, crystal spires and a shrine.
# Roads, keeps and everything that moves are drawn on the same 4px grid each frame.

const PX := 4
const MW := 160
const MH := 175
const STAMP_PAL := {
	"k": Color(0.1, 0.07, 0.1), "w": Color(0.96, 0.97, 1.0), "g": Color(0.6, 0.57, 0.56), "d": Color(0.44, 0.41, 0.41),
	"t": Color(0.18, 0.42, 0.2), "T": Color(0.12, 0.3, 0.15), "b": Color(0.4, 0.26, 0.14), "s": Color(0.86, 0.9, 0.96),
	"r": Color(0.72, 0.28, 0.24), "c": Color(0.92, 0.85, 0.7), "y": Color(0.95, 0.8, 0.3), "p": Color(0.6, 0.42, 0.9),
	"P": Color(0.82, 0.68, 1.0), "o": Color(0.85, 0.42, 0.18), "n": Color(0.2, 0.14, 0.12),
}
const STAMPS := {
	"mountain": [".....k.....", "....kwk....", "...kwwwk...", "..kwgwggk..", "..kggggddk.", ".kgggggddk.", ".kggggdddk.", "kkkkkkkkkkk"],
	"hill": ["...kkk...", ".kkgggkk.", "kgggggddk", "kkkkkkkkk"],
	"pine": ["..k..", ".ktk.", ".ktk.", "ktttk", "ktTtk", "kkbkk"],
	"snowpine": ["..k..", ".ksk.", ".ktk.", "kstsk", "ktTtk", "kkbkk"],
	"house": ["..k..", ".krk.", "krrrk", "kcyck", "kcccc"],
	"spire": [".k.", "kPk", "kPk", "kpk", "kpk", "kpk", "kkk"],
	"shrine": ["..y..", ".kyk.", "kcccck", "kcnck.", "kkkkk."],
	"mine": [".kkkkk.", "kbbbbbk", "kbnnnbk", "kbnnnbk", "kkkkkkk"],
	"pagoda": ["..k..", ".kok.", "kkkkk", ".kok.", "kkkkk", ".knk."],
}
const SNOW := [Vector2(44, 128), Vector2(96, 74), Vector2(184, 62), Vector2(212, 150), Vector2(196, 256),
	Vector2(124, 296), Vector2(56, 290), Vector2(28, 204)]
const KEEP := ["kkk...kkk", "ksk...ksk", "kskkkkksk", "ksssssssk", "ksskdkssk", "ksskdkssk", "kkkkkkkkk"]

var land_tex: ImageTexture


func _bake() -> void:
	var img := Image.create(MW, MH, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.09
	var grain := FastNoiseLite.new()
	grain.seed = 11
	grain.frequency = 0.22
	var coast := PackedVector2Array(COAST)
	var snowy := PackedVector2Array(SNOW)
	var land := PackedByteArray()
	land.resize(MW * MH)
	for y in MH:
		for x in MW:
			var p := Vector2(x * PX + 2, y * PX + 2)
			var wob := Vector2(noise.get_noise_2d(x, y), noise.get_noise_2d(x + 97, y + 31)) * 14.0
			land[y * MW + x] = 1 if Geometry2D.is_point_in_polygon(p + wob, coast) else 0
	# Distance (in pixels, up to 4) from each sea pixel to the land, for foam and shallows.
	var dist := PackedInt32Array()
	dist.resize(MW * MH)
	dist.fill(99)
	var front := []
	for i in MW * MH:
		if land[i] == 1:
			dist[i] = 0
			front.append(i)
	for step in 4:
		var next := []
		for i in front:
			var x: int = i % MW
			var y: int = i / MW
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < MW and ny < MH and dist[ny * MW + nx] > step + 1:
					dist[ny * MW + nx] = step + 1
					next.append(ny * MW + nx)
		front = next
	for y in MH:
		for x in MW:
			var i := y * MW + x
			var n := grain.get_noise_2d(x, y)
			var c: Color
			if land[i] == 0:
				match dist[i]:
					1:
						c = Color(0.78, 0.88, 0.92)
					2, 3:
						c = Color(0.24, 0.45, 0.6)
					_:
						c = Color(0.15, 0.29, 0.45) if n < 0.45 else Color(0.2, 0.36, 0.52)
			elif _sea_next(land, x, y):
				c = Color(0.86, 0.78, 0.55)
			elif Geometry2D.is_point_in_polygon(Vector2(x * PX + 2, y * PX + 2), snowy):
				c = Color(0.9, 0.93, 0.98) if n < 0.2 or (x + y) % 2 == 0 else Color(0.78, 0.84, 0.93)
			else:
				c = Color(0.43, 0.6, 0.32)
				if n > 0.3 or (n > 0.15 and (x + y) % 2 == 0):
					c = Color(0.36, 0.52, 0.27)
				elif n < -0.35 or (n < -0.2 and (x + y) % 2 == 0):
					c = Color(0.5, 0.67, 0.37)
			img.set_pixel(x, y, c)
	# The Sable river, two pixels wide with a bright middle.
	for i in RIVER.size() - 1:
		var a: Vector2 = RIVER[i] / PX
		var b: Vector2 = RIVER[i + 1] / PX
		var steps := int(a.distance_to(b)) + 1
		for s in steps + 1:
			var p := a.lerp(b, s / float(steps))
			for dy in [0, 1]:
				var x := int(p.x)
				var y: int = int(p.y) + dy
				if x >= 0 and x < MW and y >= 0 and y < MH:
					img.set_pixel(x, y, Color(0.32, 0.58, 0.85) if dy == 0 else Color(0.22, 0.45, 0.72))
	# Stamps: (kind, centre in screen px).
	var stamps := [["mountain", Vector2(470, 604)], ["mountain", Vector2(392, 530)], ["hill", Vector2(452, 520)],
		["mountain", Vector2(566, 500)], ["mountain", Vector2(548, 410)], ["hill", Vector2(590, 450)],
		["mountain", Vector2(246, 214)], ["mountain", Vector2(356, 206)], ["hill", Vector2(300, 196)],
		["mountain", Vector2(204, 140)], ["mountain", Vector2(140, 250)], ["hill", Vector2(380, 300)],
		["hill", Vector2(200, 560)], ["hill", Vector2(150, 330)], ["hill", Vector2(420, 430)],
		["shrine", Vector2(330, 488)], ["mine", Vector2(536, 466)], ["pagoda", Vector2(300, 212)]]
	for i in 6:
		stamps.append(["house", Vector2(468 + i * 18, 298 + (i % 2) * 14)])
	for i in 4:
		stamps.append(["spire", Vector2(500 + i * 16, 112 + (i % 2) * 10)])
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 26:
		stamps.append(["pine", Vector2(rng.randf_range(62, 190), rng.randf_range(400, 520))])
	for i in 10:
		stamps.append(["snowpine", Vector2(rng.randf_range(60, 190), rng.randf_range(110, 280))])
	for i in 10:
		stamps.append(["pine", Vector2(rng.randf_range(80, 560), rng.randf_range(80, 660))])
	stamps.sort_custom(func(a, b): return a[1].y < b[1].y)   # nearer (lower) things over farther ones
	for st in stamps:
		var rows: Array = STAMPS[st[0]]
		var origin := Vector2i(int(st[1].x / PX) - rows[0].length() / 2, int(st[1].y / PX) - rows.size())
		# Keep stamps off the keeps and the sea.
		var clear := true
		for k in CD.TERRITORIES:
			if (CD.TERRITORIES[k]["pos"] as Vector2).distance_to(st[1]) < 34.0:
				clear = false
		var ci := clampi(origin.y + rows.size() - 1, 0, MH - 1) * MW + clampi(origin.x + rows[0].length() / 2, 0, MW - 1)
		if not clear or land[ci] == 0:
			continue
		for ry in rows.size():
			var row: String = rows[ry]
			for rx in row.length():
				var ch := row[rx]
				if ch == ".":
					continue
				var x := origin.x + rx
				var y := origin.y + ry
				if x >= 0 and x < MW and y >= 0 and y < MH:
					img.set_pixel(x, y, STAMP_PAL[ch])
	land_tex = ImageTexture.create_from_image(img)


func _sea_next(land: PackedByteArray, x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if nx < 0 or ny < 0 or nx >= MW or ny >= MH or land[ny * MW + nx] == 0:
			return true
	return false


## One map pixel (or a block of them), on the 4px grid.
func _b(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(floorf(x) * PX, floorf(y) * PX, maxf(1.0, w) * PX, maxf(1.0, h) * PX), c)


func _draw() -> void:
	draw_texture_rect(land_tex, Rect2(0, 0, MW * PX, MH * PX), false)
	# Glints on the sea.
	for i in 18:
		var x := fmod(i * 53.0 + t * 1.5, MW)
		var y := fmod(i * 37.0, MH)
		if absf(sin(t * 1.3 + i)) > 0.7:
			_b(x, y, 2, 1, Color(0.45, 0.65, 0.85, 0.6))
	_draw_roads()
	for k in CD.TERRITORIES:
		var st: String = campaign.territory_state(k)
		if st != "hidden":
			_draw_keep(k, st)


func _draw_roads() -> void:
	for r in CD.ROUTES:
		var a: String = r[0]
		var b: String = r[1]
		if campaign.territory_state(a) == "hidden" or campaign.territory_state(b) == "hidden":
			continue
		var pa: Vector2 = CD.TERRITORIES[a]["pos"] / PX
		var pb: Vector2 = CD.TERRITORIES[b]["pos"] / PX
		var restored: bool = campaign.territory_done(a) and campaign.territory_done(b)
		var n := int(maxf(absf(pb.x - pa.x), absf(pb.y - pa.y)))
		for i in n + 1:
			var p := pa.lerp(pb, i / float(maxi(n, 1))).floor()
			if p.distance_to(pa) < 4.0 or p.distance_to(pb) < 4.0:
				continue   # stop short of the keeps
			if restored:
				# The road of the Line, lit gold, with a light running along it.
				var run := fmod(t * 20.0, float(n + 12))
				var bright := absf(i - run) < 2.0
				_b(p.x, p.y, 1, 1, Color(1, 0.95, 0.6) if bright else Color(0.95, 0.75, 0.25))
			elif i % 3 != 2:
				_b(p.x, p.y, 1, 1, Color(0.5, 0.36, 0.2))


func _draw_keep(k: String, st: String) -> void:
	var c: Vector2 = (CD.TERRITORIES[k]["pos"] / PX).floor()
	var f: String = CD.TERRITORIES[k]["faction"]
	var stone := Color(0.8, 0.76, 0.7)
	match st:
		"locked":
			stone = Color(0.48, 0.48, 0.5)
		"available":
			stone = Color(0.86, 0.8, 0.62)
	var ox := c.x - 4
	var oy := c.y - 5
	for ry in KEEP.size():
		var row: String = KEEP[ry]
		for rx in row.length():
			match row[rx]:
				"k":
					_b(ox + rx, oy + ry, 1, 1, OUTLINE)
				"s":
					_b(ox + rx, oy + ry, 1, 1, stone if rx < 6 else stone.darkened(0.12))
				"d":
					_b(ox + rx, oy + ry, 1, 1, Color(0.3, 0.2, 0.12) if st != "attack" else Color(1.0, 0.55, 0.2))
	# Selected: blinking corner brackets.
	if k == selected and fmod(t, 1.0) < 0.75:
		var w := Color(1, 1, 1)
		for corner in [Vector2(-2, -3), Vector2(10, -3), Vector2(-2, 9), Vector2(10, 9)]:
			var p: Vector2 = Vector2(ox, oy) + corner
			var sx := 1.0 if corner.x < 0 else -1.0
			var sy := 1.0 if corner.y < 0 else -1.0
			_b(p.x, p.y, 1, 1, w)
			_b(p.x + sx, p.y, 1, 1, w)
			_b(p.x, p.y + sy, 1, 1, w)
	match st:
		"locked":
			_b(ox + 9, oy + 4, 3, 3, Color(0.9, 0.78, 0.3))
			_b(ox + 10, oy + 2, 1, 2, Color(0.9, 0.78, 0.3))
			_b(ox + 10, oy + 5, 1, 1, OUTLINE)
		"attack":
			for i in 3:
				var fx := ox + 1 + i * 3
				var h := 2.0 + floorf(1.5 + 1.5 * sin(t * 9.0 + i * 2.1))
				_b(fx, oy - h, 2, h, Color(1.0, 0.45, 0.1))
				_b(fx, oy - maxf(1.0, h - 1.0), 1, maxf(1.0, h - 1.0), Color(1.0, 0.85, 0.35))
			# Smoke drifting off.
			for i in 3:
				var rise := fmod(t * 5.0 + i * 4.0, 12.0)
				_b(ox + 4 + sin(t + i) * 2.0, oy - 4 - rise, 1, 1, Color(0.35, 0.32, 0.32, 1.0 - rise / 12.0))
		"unfinished":
			# The people's banner on the left tower; the beacon on the right stands cold,
			# with a pip for each required mission (gold once won).
			var colu: Color = CD.FACTIONS[f]["color"] if f != "" else Color(0.3, 0.45, 0.85)
			_b(ox + 1, oy - 4, 1, 4, OUTLINE)
			_b(ox + 2, oy - 4, 3, 2, colu)
			_b(ox + 5, oy - 3, 5, 3, OUTLINE)
			_b(ox + 6, oy - 3, 3, 2, Color(0.55, 0.52, 0.5))
			_b(ox + 7, oy - 3, 1, 1, Color(0.22, 0.2, 0.2))   # cold coals
			var pr: Array = campaign.progress(k)
			for i in pr[1]:
				# A pip per required mission, gold once won, above the keep.
				_b(ox + 4 - pr[1] + i * 2 + 1, oy - 7, 1, 1, Color(1, 0.85, 0.3) if i < pr[0] else Color(0.6, 0.56, 0.5))
		"secured":
			# The people's banner on the left tower, and the beacon lit on the right.
			var col: Color = CD.FACTIONS[f]["color"] if f != "" else Color(0.3, 0.45, 0.85)
			_b(ox + 1, oy - 4, 1, 4, OUTLINE)
			_b(ox + 2, oy - 4, 3, 2, col)
			if not campaign.has_beacon(k):
				# No beacon here (Sable Crossing): held, a banner flies on the right tower too.
				_b(ox + 7, oy - 4, 1, 4, OUTLINE)
				_b(ox + 8, oy - 4, 3, 2, col)
				return
			var glow := 0.6 + 0.4 * sin(t * 5.0 + c.x)
			_b(ox + 5, oy - 4, 5, 4, Color(1, 0.7, 0.2, 0.25 * glow))
			_b(ox + 7, oy - 2, 1, 2, Color(1, 0.6, 0.15))
			_b(ox + 7, oy - 3, 1, 1, Color(1, 0.92, 0.5))
