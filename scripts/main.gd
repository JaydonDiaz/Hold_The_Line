extends Node2D
## Game controller: battlefield, waves, gold, input and hiring.

const Data = preload("res://scripts/data.gd")
const Warrior = preload("res://scripts/warrior.gd")
const Barricade = preload("res://scripts/barricade.gd")
const Pathing = preload("res://scripts/pathing.gd")
const Castle = preload("res://scripts/castle.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Fx = preload("res://scripts/fx.gd")
const Hud = preload("res://scripts/hud.gd")
const Sprites = preload("res://scripts/sprites.gd")
const Audio = preload("res://scripts/audio.gd")
const Grave = preload("res://scripts/grave.gd")
const FieldArt = preload("res://scripts/field_art.gd")
const Ambience = preload("res://scripts/ambience.gd")
const Tutorial = preload("res://scripts/tutorial.gd")
const CastlePowers = preload("res://scripts/castle_powers.gd")
const Engineer = preload("res://scripts/engineer.gd")
const Maps = preload("res://scripts/maps.gd")
const MissionRules = preload("res://scripts/mission/rules.gd")
const Camp = preload("res://scripts/mission/camp.gd")
const Scenarios = preload("res://scripts/mission/scenarios.gd")

var FIELD_W := 640         # widens to fill the screen (see _fit_screen); 640 in a normal window
const FIELD_H := 768
const CASTLE_Y := 736      # top of the castle wall: enemies that reach it get in
const TILE := 64
const DEPLOY_TOP := 96     # warriors can't be posted in the enemy entry zone
const MIN_POST_GAP := 30.0

const FREEPLAY_GOLD := 999999
const FREEPLAY_MAX_LEVEL := 40

var _enemies := []           # get_enemies() for this frame
var _enemies_frame := -1
var _grid := {}              # enemies by grid cell this frame (see enemies_near)
var _grid_frame := -1
var _wgrid := {}             # your units by grid cell this frame (see warriors_near)
var _wgrid_frame := -1
const GRID := 64.0
const MAX_ENEMY_RADIUS := 40.0   # at least the biggest enemy's radius (the Ogre King's)
var _warriors := []          # get_warriors() for this frame
var _warriors_frame := -1
var started := false     # set once the player picks a mode
var selected_grave = null   # a grave clicked to see who fell there
var grave_layer := Node2D.new()
var corpse_layer := Node2D.new()   # enemies falling as they die (see spawn_corpse), on the ground under the troops
var ambience := Ambience.new()   # the mood over the field (light, weather, critters), by mode
var powers := CastlePowers.new()   # the Castle tab: abilities, Stone Walls, Ballistae
var permadeath := false   # downed warriors die for good unless revived (every difficulty; not the Tutorial or Freeplay)
var freeplay := false    # sandbox: unlimited gold, the castle can't fall, spawn any wave at will
var freeplay_level := 1  # wave level used for freeplay spawns
var tutorial := false    # tutorial mode: a normal game with a guide, where the castle can't fall
var campaign := false
var rules = null   # the battle's rules (scripts/mission/rules.gd): castle defense unless the mission says otherwise
var camp: Node2D = null   # the work camp standing in for the castle, on a battlefield without one
var battle_id := ""       # a Battle Modes scenario being played (scenarios.gd), "" otherwise
var objective_layer: Node2D = null   # the mission's objectives (see rules_positions.gd), under the troops
var roof_layer: Node2D = null        # ...and the tops of the tall ones, over everyone
var classic_map := ""      # Classic on one of the campaign's battlefields ("" = the open meadow)
var map_id := ""           # the battlefield this game is on (a maps.gd id, "" for the meadow)
var stage_music := "calm"   # this battlefield's peaceful music between waves (audio.gd STAGE_TRACKS)
var battle_music := "battle"   # ...and its own battle music during waves (audio.gd BATTLES)
var credit := ""             # campaign XP: the unit kind whose doing the damage dealt right now is
var battle_xp := {}          # campaign XP earned this battle: unit kind -> XP
const CD_XP_RATES = preload("res://scripts/campaign_data.gd").XP_RATES    # a story campaign battle (the Campaign autoload says which mission)
var mission := {}        # that mission's data (campaign_data.gd MISSIONS); empty outside the campaign
var temp_allies := []    # units the mission put on the field from the start
var help_lend := []      # unlock keys the allied peoples' help brings to this battle (see _send_help)
var gold: int = Data.START_GOLD
var difficulty := "normal"   # a key of Data.DIFFICULTIES ("normal" in freeplay)
var cost_mult := 1.0         # prices for this difficulty
var price_step := 1          # ...rounded to this many gold (5 on Hard)
var castle_max: float = Data.CASTLE_HP
var castle_base: float = Data.CASTLE_HP   # castle_max before the Fortify path's extra health
var castle_hp: float = Data.CASTLE_HP
var down_time := 20.0        # seconds a downed warrior has before it dies (or, without permadeath, gets up)
var margin := Vector2.ZERO   # spare screen above and below the game on a tall window
var gates_warned := false   # "at the gates" has been shown this wave
var wave := 0
var wave_active := false
var game_over := false
var victory := false
var endless := false     # carried on past the final wave; enemies keep scaling until the line falls
var records_path := "user://records.cfg"   # best number of waves survived, per mode ("" = don't keep)
var routed := false       # lost because the army was gone with no way to raise another
var rout_time := 0.0      # seconds it's looked that way (it has to last a moment)
var run_survived := 0     # the waves survived, as the battle ended
var best_before := 0      # a survival battle's best (waves) before this one
var beat_best := false    # ...and whether this one has gone past it yet

var spawn_queue: Array = []   # [enemy kind, wave level] pairs waiting to enter
var boss_spawned := false     # this wave's boss has come out
var spawn_timer := 0.0
var spawn_interval := 0.8

var placing_type := ""
var castle_selected := false
var repair_job := {}           # a repair the Engineers are working on: {"left": health still to come, "rate": per second}   # the castle was clicked: the panel shows its upgrades
var auto_play := false         # start each wave by itself after the last one's cleared
var auto_timer := 0.0          # seconds until auto-play starts the next wave
var forced_auto := false       # this battle keeps coming (a mission's "pace": {"auto": "forced"}): auto-play can't be turned off
var deploying := false         # forced pace: the opening seconds to set up, before the first wave
var wave_clock := 0.0          # forced pace: seconds since the last of the wave arrived (the next comes regardless, after pace_window())
const AUTO_DELAY := 3.0
var wall_start = null     # first click while placing a barricade (Vector2), or null
var last_priority := {}   # unit kind -> target priority new hires start with
var last_orders := {}     # unit kind -> {commit, move_mode, guard_area, danger_mode, call_help, answer} new hires start with (the last given to that kind)
var help_calls := {}      # troop calling for help (in danger) -> seconds the call lasts if it isn't renewed
const CALL_LINGER := 1.2
var area_pick := []       # troops waiting for a Guard Area to be drawn on the field (see start_area_pick)
var area_start = null     # where the area being drawn was started (Vector2), while the button's held
var selected: Warrior = null
var group := []             # several troops selected together (box or Shift+click); `selected` is null then
var ward_pick := []         # Healers waiting for a click on the troop they're to stay with
var box_start = null        # where a left-drag on open field started (Vector2), while the button's held
var box_active := false     # it's been dragged far enough to be a selection box
var box_add := false        # Shift was held: the box adds to the group
var group_drag := false     # dragging the whole group to new posts (between waves)
var group_from := {}        # warrior -> its post when the group drag started
var mouse := Vector2.ZERO
var mouse_stand_in := Vector2.INF   # tests: where the mouse is taken to be (INF: the real one)
var dragging: Warrior = null     # unit being repositioned between waves
var hovered: Warrior = null      # the troop under the mouse between waves (it perks up: see Warrior._carry)
var drag_origin := Vector2.ZERO
var drag_offset := Vector2.ZERO
const LIFT_AFTER := 4.0          # a dragged troop is lifted off its feet once it's moved this far (a click doesn't)

const GROUND_OVERSAMPLE := 2
var ground_vp := SubViewport.new()     # the ground, painted once (see _repaint_ground)
var ground_painter := Node2D.new()
var ground_sprite := Sprite2D.new()
var castle := Castle.new()
var wall_layer := Node2D.new()
var warrior_layer := Node2D.new()
var enemy_layer := Node2D.new()
var fx_layer := Node2D.new()
var overlay := Node2D.new()
var hud: CanvasLayer
var paths := Pathing.new()
var audio: Audio
var layer_timer := 0.0
var bard_instruments := []   # what the Bards on the field are playing (see _bard_instruments)
var last_track := ""
var song_on := true   # the player can switch the eight-Bard song off (from any Bard's panel)


func _ready() -> void:
	Engine.time_scale = 1.0
	rules = MissionRules.make({})   # castle defense until a mode is chosen
	rules.setup(self, {})
	_size_window()
	audio = Audio.new()
	add_child(audio)
	get_tree().node_added.connect(_click_on_press)   # every button, menus and HUD alike, ticks when pressed
	for b in find_children("*", "BaseButton", true, false):
		_click_on_press(b)
	paths.setup(self)
	castle.main = self
	# The castle goes over the warriors (it hides any standing behind it, showing their
	# silhouettes) but under the enemies, effects and overlay.
	ambience.main = self
	ambience.setup("normal")
	powers.main = self
	ground_vp.disable_3d = true
	ground_vp.transparent_bg = false
	ground_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	ground_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	ground_painter.scale = Vector2.ONE * GROUND_OVERSAMPLE   # painted at twice the size
	ground_vp.add_child(ground_painter)
	ground_painter.draw.connect(func(): _paint_ground(ground_painter))
	add_child(ground_vp)
	ground_sprite.centered = false
	ground_sprite.texture = ground_vp.get_texture()
	ground_sprite.scale = Vector2.ONE / GROUND_OVERSAMPLE
	ground_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # smooth when shown smaller than painted
	add_child(ground_sprite)
	castle.top_part.castle = castle
	for layer in [grave_layer, corpse_layer, wall_layer, warrior_layer, castle, castle.top_part, enemy_layer, powers, fx_layer, ambience, overlay]:
		add_child(layer)
	overlay.draw.connect(_draw_overlay)
	for sig in [enemy_layer.child_entered_tree, enemy_layer.child_exiting_tree]:
		sig.connect(func(_n): enemies_changed())
	for sig in [warrior_layer.child_entered_tree, warrior_layer.child_exiting_tree]:
		sig.connect(func(_n): warriors_changed())
	hud = Hud.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS   # stays clickable while the game is paused
	add_child(hud)
	hud.hire_pressed.connect(_on_hire_pressed)
	hud.start_wave_pressed.connect(start_wave)
	hud.upgrade_pressed.connect(upgrade_selected)
	hud.sell_pressed.connect(sell_selected)
	hud.target_pressed.connect(cycle_target_priority)
	hud.orders_pressed.connect(func(): hud.toggle_orders(self))
	hud.song_pressed.connect(toggle_song)
	hud.speed_pressed.connect(cycle_speed)
	hud.auto_pressed.connect(toggle_auto)
	hud.restart_pressed.connect(_restart)
	hud.battle_again.connect(play_again)
	hud.action_pressed.connect(func(): rules.action())
	hud.menu_confirmed.connect(func():
		if survival() and started and not game_over:
			_keep_survival_record(waves_survived())   # a run left early still counts
		back_to_map() if campaign else _restart())
	hud.campaign_retry.connect(retry_mission)
	hud.campaign_map.connect(back_to_map)
	hud.mode_chosen.connect(_on_mode_chosen)
	hud.freeplay_level_changed.connect(change_freeplay_level)
	hud.freeplay_spawn_pressed.connect(spawn_single)
	hud.freeplay_clear_pressed.connect(clear_enemies)
	hud.castle_pressed.connect(castle_upgrade)
	hud.ability_pressed.connect(ability_item)
	hud.repair_pressed.connect(repair_castle)
	hud.power_pressed.connect(func(k): powers.trigger(k))
	hud.group_kind_pressed.connect(func(k): filter_group(k, Input.is_key_pressed(KEY_SHIFT)))
	get_viewport().size_changed.connect(_fit_screen)
	_fit_screen()
	_open_start_screen()


## Opens the window big and centred: about 90% of the screen's usable height and 70%
## of its width (never narrower than the game's 640x1040 shape; the extra width
## becomes more battlefield). Not when run headless, or by a script or test that sets
## its own size.
func _size_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var args := OS.get_cmdline_args()
	if args.has("-s") or args.has("--script") or args.has("--resolution"):
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var h := int(usable.size.y * 0.9)
	var w := maxi(int(usable.size.x * 0.7), int(h * Hud.WIDTH / Hud.HEIGHT))
	w = mini(w, int(usable.size.x * 0.95))
	DisplayServer.window_set_size(Vector2i(w, h))
	DisplayServer.window_set_position(usable.position + (usable.size - Vector2i(w, h)) / 2)


## Fills the window (the project stretches with "expand"): on a wide screen the
## battlefield itself gets wider, with the panel's controls centred along the
## bottom; on a tall one the game is centred. When the width changes, everything
## on the field keeps its place relative to the field's width (a unit posted near
## the right edge of a full screen is still near the right edge in a window).
## Walls stretch or shrink with the field, each end keeping its place across it,
## so walls joined end to end (or built against the edge) stay that way; their
## health and prices stay those of the length they were built at. Everything is
## placed from where the player put it, never from the last resize, so going small
## and back to full screen puts everything back where it was.
func _fit_screen() -> void:
	var view := get_viewport().get_visible_rect().size
	var new_w := maxi(int(Hud.WIDTH), int(view.x))
	margin = Vector2(0, maxf(0.0, floorf((view.y - Hud.HEIGHT) / 2.0)))
	position = margin
	hud.offset = margin
	hud.layout(new_w)
	if new_w != FIELD_W:
		var old_w := FIELD_W
		var k := float(new_w) / old_w
		FIELD_W = new_w
		for layer in [enemy_layer, fx_layer]:
			for n in layer.get_children():
				n.position.x *= k
				if "target_pos" in n:
					n.target_pos.x *= k
		for w in warrior_layer.get_children():
			if w.post != w.fitted_post:
				w.post_u = w.post.x / old_w   # placed or moved since the last resize
			w.post.x = w.post_u * FIELD_W
			w.fitted_post = w.post
			if w.guard_area.has_area():
				w.guard_area = Rect2(w.guard_area.position.x * k, w.guard_area.position.y, w.guard_area.size.x * k, w.guard_area.size.y)
			if w.is_emplacement():
				w.position = w.post
			else:
				w.position.x *= k
				w.route = PackedVector2Array()
		if objective_layer != null:
			for o in objective_layer.get_children():
				o.refit(k)   # objectives keep their place across the field, like the map (and their roads)
			paths.invalidate()
		for b in wall_layer.get_children():
			if b.post != b.fitted_post:
				b.end_u = Vector2(b.seg_a().x, b.seg_b().x) / old_w   # built or moved since the last resize
			var ax: float = b.end_u.x * FIELD_W
			var bx: float = b.end_u.y * FIELD_W
			b.half.x = (bx - ax) / 2.0
			b.position.x = (ax + bx) / 2.0
			b.post = b.position
			b.fitted_post = b.post
			b.queue_redraw()
		if wall_start != null:
			wall_start.x *= k
		paths.setup(self)
		walls_changed()
		castle.lay_out()
	castle.queue_redraw()
	castle._drawn_state = Vector3(-1, -1, -1)
	queue_redraw()


## mode: a difficulty ("easy", "normal", "hard"), "freeplay" or "tutorial".
func choose_mode(mode: String) -> void:
	_foes_seen.clear()   # (each battle introduces its foes afresh)
	castle_warned = 0
	hud.foe_queue.clear()
	campaign = mode == "campaign"
	mission = Campaign.mission() if campaign else (Scenarios.get_scenario(battle_id) if battle_id != "" else {})
	rules = MissionRules.make(mission)
	rules.setup(self, mission)
	_show_castle(rules.has_castle())
	# The battle's pace: forced auto-play gives a few seconds to deploy, then sends the
	# waves itself, a window apart (see pace_window). (Speed and pause work as ever.)
	var pace: Dictionary = mission.get("pace", {})
	forced_auto = pace.get("auto", "free") == "forced"
	if forced_auto:
		auto_play = true
		deploying = true
		auto_timer = float(pace.get("deploy", 15.0))
	# The battlefield: a campaign mission's own map (terrain, lanes, castle), Classic on
	# one the campaign has opened, or the open meadow.
	var classic := not campaign and battle_id == "" and Data.DIFFICULTIES.has(mode)
	map_id = mission.get("map", "") if scripted() else (classic_map if classic and Maps.MAPS.has(classic_map) else "")
	# Battles fill the window: a map stretches across the field like the meadow does (the
	# campaign map and the cutscenes, drawn as one picture, keep their frame).
	_lock_portrait(false)
	paths.set_map(Maps.get_map(map_id))
	if paths.has_terrain():
		_repaint_ground()
	var map: Dictionary = Maps.get_map(map_id)
	stage_music = map.get("music", "mountain" if map.get("biome", "") == "mountain" else "calm")
	set_battle_music(map)
	castle.set_style(map.get("castle", "keep"))
	freeplay = mode == "freeplay"
	tutorial = mode == "tutorial"
	difficulty = Campaign.difficulty if campaign else ("normal" if freeplay or tutorial else mode)
	ambience.setup(mission.get("mood", "normal") if campaign else mode)
	castle.modulate = ambience.castle_tint()
	castle.top_part.modulate = castle.modulate
	queue_redraw()
	var d: Dictionary = Data.DIFFICULTIES[difficulty]
	permadeath = d["permadeath"] and not freeplay and not tutorial   # practice and the sandbox forgive
	down_time = d["down_time"]
	cost_mult = d["cost"]
	price_step = d.get("round", 1)
	castle_max = roundf(Data.CASTLE_HP * d["castle"])
	castle_base = castle_max
	castle_hp = castle_max
	hud.set_prices(cost_mult, price_step)
	if freeplay:
		gold = FREEPLAY_GOLD
		hud.show_freeplay_bar()
	started = true
	hud.hide_mode_select()
	if scripted():
		_begin_mission()
	rules.start()
	if survival():
		best_before = _best_record()
		if best_before > 0:
			hud.show_message("Survive as many waves as you can. Your best here: %d" % best_before)
		else:
			hud.show_message("Survive as many waves as you can")
	if tutorial:
		var guide := Tutorial.new()
		guide.main = self
		guide.hud = hud
		hud.add_child(guide)


func _process(delta: float) -> void:
	mouse = get_local_mouse_position() if mouse_stand_in == Vector2.INF else mouse_stand_in
	# Between waves, the troop under the mouse perks up (it can be picked up and moved).
	hovered = _warrior_at(mouse) if started and not wave_active and dragging == null and not group_drag \
			and placing_type == "" and mouse.y <= FIELD_H else null
	_update_calls(delta)
	if dragging != null:
		_update_drag()
	if group_drag:
		_update_group_drag()
	if box_start != null and not box_active and mouse.distance_to(box_start) > 6.0:
		box_active = true
	group = group.filter(func(w): return is_instance_valid(w) and not w.is_queued_for_deletion())
	if group.size() == 1:
		selected = group[0]   # down to one: it's an ordinary selection
		group.clear()
	if selected != null and (not is_instance_valid(selected) or selected.is_queued_for_deletion()):
		selected = null
	if not game_over:
		if started:
			rules.process(delta)
			_check_rout(delta)
		if not spawn_queue.is_empty():
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				var next: Array = spawn_queue.pop_front()
				_spawn_enemy(next[0], next[1])
				spawn_timer = spawn_interval
		if freeplay:
			# No wave rounds in freeplay: "active" just means enemies are around.
			gold = FREEPLAY_GOLD
			wave_active = not spawn_queue.is_empty() or not get_enemies().is_empty()
			if not wave_active:
				castle_hp = castle_max   # sandbox: patched up once the field is clear
				gates_warned = false
		elif forced_auto and wave_active and spawn_queue.is_empty():
			# The last of the wave is on the field: the next comes a window later, whether
			# this one's beaten or not. Beat it sooner and the rest of the window is a breather.
			wave_clock += delta
			if wave_clock >= pace_window():
				start_wave(true)
			elif get_enemies().is_empty():
				_end_wave()
		elif auto_play and started and not wave_active:
			if forced_auto:
				auto_timer -= delta   # (a forced pace keeps the battle's own time)
				if not deploying:
					_rest(delta)
			else:
				auto_timer -= delta / maxf(Engine.time_scale, 1.0)   # real seconds, whatever the speed
			if auto_timer <= 0.0:
				start_wave()
		elif wave_active and spawn_queue.is_empty() and get_enemies().is_empty():
			if _boss_due():
				_spawn_boss()
			else:
				_end_wave()
	hud.refresh(self)
	if hud.scene_music != "":
		audio.set_track(hud.scene_music)   # a cutscene's own music
	elif not started:
		audio.set_track("map" if hud.world_map != null else "title")   # the campaign map's own, or the title screen's
	elif not game_over:
		layer_timer -= delta
		if layer_timer <= 0.0:
			layer_timer = 0.5
			bard_instruments = _bard_instruments()
			audio.set_layers(bard_instruments)
		# Between waves, a Bard on every instrument strikes up a song together.
		var ensemble: bool = song_on and audio._music.has("ensemble") and all_bards_present()
		audio.set_track(battle_music if wave_active else ("ensemble" if ensemble else stage_music))
		if audio._playing_track != last_track:
			if audio._playing_track == "ensemble":
				hud.show_message("The Bards strike up a song together!")
			last_track = audio._playing_track
	# Hovering a unit on the field shows its description card.
	var hovered: Warrior = null
	if started and not game_over and dragging == null and placing_type == "" and mouse.y <= FIELD_H:
		hovered = _warrior_at(mouse)
	if hovered == null and not castle_selected and _castle_hovered():
		hud.show_castle_card(self, mouse)
	else:
		hud.show_unit_card(hovered, mouse)
	overlay.queue_redraw()


## The living enemies. Built once a frame and shared (callers mustn't change it); a
## death or a new arrival makes the next call build a fresh array, so a loop already
## going over the old one isn't disturbed.
func get_enemies() -> Array:
	var f := Engine.get_process_frames()
	if f != _enemies_frame:
		_enemies_frame = f
		_enemies = enemy_layer.get_children().filter(func(e): return not e.dead)
	return _enemies


## Living enemies whose centres may be within r of p (some a little further): only the
## grid cells around p, so crowds of enemies don't each check every other enemy.
## The grid is built once a frame from where enemies were then.
func enemies_near(p: Vector2, r: float) -> Array:
	var f := Engine.get_process_frames()
	if f != _grid_frame:
		_grid_frame = f
		_grid.clear()
		for e in get_enemies():
			var c := Vector2i(floori(e.position.x / GRID), floori(e.position.y / GRID))
			if _grid.has(c):
				_grid[c].append(e)
			else:
				_grid[c] = [e]
	var lo := Vector2i(floori((p.x - r) / GRID), floori((p.y - r) / GRID))
	var hi := Vector2i(floori((p.x + r) / GRID), floori((p.y + r) / GRID))
	var out := []
	for cy in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var cell = _grid.get(Vector2i(cx, cy))
			if cell != null:
				out.append_array(cell)
	return out


## Your units (active or not) whose centres may be within r of p, from a grid built
## once a frame like enemies_near's.
func warriors_near(p: Vector2, r: float) -> Array:
	var f := Engine.get_process_frames()
	if f != _wgrid_frame:
		_wgrid_frame = f
		_wgrid.clear()
		for w in get_warriors():
			var c := Vector2i(floori(w.position.x / GRID), floori(w.position.y / GRID))
			if _wgrid.has(c):
				_wgrid[c].append(w)
			else:
				_wgrid[c] = [w]
	var lo := Vector2i(floori((p.x - r) / GRID), floori((p.y - r) / GRID))
	var hi := Vector2i(floori((p.x + r) / GRID), floori((p.y + r) / GRID))
	var out := []
	for cy in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var cell = _wgrid.get(Vector2i(cx, cy))
			if cell != null:
				out.append_array(cell)
	return out


## Call when an enemy dies or leaves (get_enemies then rebuilds).
func enemies_changed() -> void:
	_enemies_frame = -1


## A unit has died for good, so a grave (or a ruin) marks the spot.
func add_grave(w) -> void:
	if w.summoned or w.clone_of != null or w is Barricade:
		return
	var g := Grave.new()
	g.setup_from(w)
	grave_layer.add_child(g)


func get_graves() -> Array:
	return grave_layer.get_children()


func _grave_at(p: Vector2):
	for g in get_graves():
		if g.position.distance_to(p) < 18.0:
			return g
	return null


## Your units on the field (not the castle's wall guards). Shared like get_enemies.
func get_warriors() -> Array:
	var f := Engine.get_process_frames()
	if f != _warriors_frame:
		_warriors_frame = f
		_warriors = warrior_layer.get_children().filter(func(w): return not w.is_queued_for_deletion())
	return _warriors


func warriors_changed() -> void:
	_warriors_frame = -1
	_wgrid_frame = -1


func get_barricades() -> Array:
	return wall_layer.get_children().filter(func(b): return not b.is_queued_for_deletion())


## Recomputes enemy routes; call whenever a wall goes up, comes down or moves.
func walls_changed() -> void:
	paths.invalidate()


## The standing barricade nearest to p, if its face is within `reach` of p.
func barricade_touching(p: Vector2, reach: float):
	var best = null
	var best_d := reach
	for b in get_barricades():
		if not b.is_active():
			continue
		var d: float = b.gap_from(p)
		if d <= best_d:
			best_d = d
			best = b
	return best


# --- Waves ---------------------------------------------------------------

func start_wave(force := false) -> void:
	if freeplay:
		spawn_freeplay_wave()
		return
	if (wave_active and not force) or game_over or not started:
		return
	wave_clock = 0.0
	if dragging != null:
		_end_drag()
	if deploying:
		deploying = false
		hud.show_message("They're coming!")
	wave += 1
	sfx("horn")
	boss_down = ""
	wave_active = true
	boss_spawned = false
	gates_warned = false
	var level := wave_level(wave)
	spawn_queue = _build_wave(wave).map(func(k): return [k, level])
	spawn_interval = maxf(0.35, 0.9 - level * 0.03)
	spawn_timer = 0.0
	if scripted():
		hud.show_message(mission.get("notes", {}).get(wave, rules.wave_text().replace("/", " of ")))
		return
	var warlords := _warlords(wave)
	var wyverns := _wyverns(wave)
	if warlords > 1:
		hud.show_message("Wave %d: %d Warlords approach!" % [wave, warlords])
	elif warlords == 1:
		hud.show_message("Wave %d: a Warlord approaches!" % wave)
	elif wyverns > 1:
		hud.show_message("Wave %d: %d Wyverns circle overhead!" % [wave, wyverns])
	elif wyverns == 1:
		hud.show_message("Wave %d: a Wyvern circles overhead!" % wave)
	else:
		hud.show_message("Wave %d" % wave)


func _build_wave(n: int) -> Array:
	if scripted():
		return _mission_wave(n)
	var pool := ["goblin", "goblin"]
	if n >= 2:
		pool.append("orc")
		pool.append("skeleton_archer")
	if n >= 3:
		pool.append("wolf")
	if n >= 4:
		pool.append("bat")
	if n >= 6:
		pool.append("troll")
		pool.append("slime")
	if n >= 7:
		pool.append("sapper")
	var list := []
	for i in 6 + n * 2:
		list.append(pool.pick_random())
	if n == 4 or n == 5:
		list.insert(list.size() / 2, "troll")  # a single troll as an early taste
	for i in _warlords(n):
		list.append("warlord")
	for i in _wyverns(n):
		list.insert(list.size() * (i + 1) / (_wyverns(n) + 1), "wyvern")
	return list


## Warlords lead every fifth wave; past the final wave, one more for every ten waves.
func _warlords(n: int) -> int:
	if n % 5 != 0:
		return 0
	return 1 + maxi(0, n - Data.FINAL_WAVE) / 10


## Wyverns, the flying elite, swoop in on the even waves from 12 that no Warlord
## leads; past the final wave, one more for every ten waves.
func _wyverns(n: int) -> int:
	if n < 12 or n % 2 == 1 or n % 5 == 0:
		return 0
	return 1 + maxi(0, n - Data.FINAL_WAVE) / 10


## A word of warning the first time a game sees one of these.
## The first time each kind of foe comes on in a battle, a card names it and says how
## to deal with it (bosses announce themselves; goblins need no introduction).
const FOE_HINTS := {
	"orc": ["Orc", "Tough and hits hard. Hold it with a Knight."],
	"wolf": ["Wolf", "Fast. Runs past your troops to bite at the walls."],
	"bat": ["Bat", "Flies over troops and walls: only ranged troops and spells reach it."],
	"skeleton_archer": ["Skeleton Archer", "Hangs back and shoots: rush it down, or outrange it."],
	"slime": ["Slime", "Blades and arrows can't hurt it. Use magic, ki or ice (ice lets steel bite)."],
	"sapper": ["Sapper", "Carries a bomb for your walls. Stop it before it gets there."],
	"troll": ["Troll", "Huge and slow, and knocks troops back. Gang up on it."],
	"warlord": ["Warlord", "A champion. Shrugs off stuns and hits like a falling tree."],
	"wyvern": ["Wyvern", "Flying elite that breathes fire on whatever's below."],
}
var _foes_seen := {}
var boss_down := ""   # "<a boss> is defeated!" until the wave it fell in is over (its message leads the wave's)


func _spawn_enemy(kind: String, level: int, at = null) -> void:
	if FOE_HINTS.has(kind) and not _foes_seen.has(kind) and not tutorial:
		_foes_seen[kind] = true
		hud.show_foe(kind, FOE_HINTS[kind][0], FOE_HINTS[kind][1])
	var d: Dictionary = Data.ENEMIES[kind]
	var r: float = d["radius"]
	if at == null:
		var lane := paths.lane_spawn(r + 4.0)
		if lane != Vector2.INF and not d.get("boss", false):
			at = lane   # a battlefield's own ways in
		else:
			at = Vector2(FIELD_W / 2.0 if d.get("boss", false) else randf_range(r + 10, FIELD_W - r - 10), -r)
	var e := Enemy.new()
	e.setup(kind, d, self, at,
			Data.level_growth(level, Data.HP_GROWTH, Data.LATE_HP_GROWTH),
			Data.level_growth(level, Data.DAMAGE_GROWTH, Data.LATE_DAMAGE_GROWTH),
			1.0 + Data.BOUNTY_GROWTH * (level - 1))
	e.level = level
	e.died.connect(_on_enemy_died)
	e.reached_castle.connect(_on_enemy_at_castle)
	e.goal = rules.enemy_goal(e)   # an objective the rules send it for (null: the castle, as ever)
	enemy_layer.add_child(e)
	if e.boss:
		hud.show_message("%s approaches!" % d.get("name", kind.capitalize()))


## An enemy called in mid-fight (by the Ogre King).
func spawn_minion(kind: String, level: int, at: Vector2) -> void:
	_spawn_enemy(kind, level, at.clamp(Vector2(20, -20), Vector2(FIELD_W - 20, CASTLE_Y - 40)))


## The Ogre King's war horn: a fresh wave marches in from the top of the field.
func reinforce(kinds: Array, level: int) -> void:
	sfx("horn", 0.75)
	spawn_queue.append_array(kinds.map(func(k): return [k, level]))
	hud.show_message("The war horn sounds! More enemies are coming!")


## The final wave, and every tenth wave past it, ends with the Ogre King once
## everything else is beaten.
func _boss_due() -> bool:
	return not scripted() and not boss_spawned and wave >= Data.FINAL_WAVE and (wave - Data.FINAL_WAVE) % 10 == 0


func _spawn_boss() -> void:
	boss_spawned = true
	_spawn_enemy("ogre_king", wave)


## Share of bounties and wave bonuses paid: all of it up to the final wave, then a
## little less each endless wave (2% per wave, down to 40%).
func late_gold_share() -> float:
	return maxf(Data.LATE_GOLD_MIN, 1.0 - Data.LATE_GOLD_STEP * maxi(0, wave - Data.FINAL_WAVE))


## Gold from a kill or a cleared wave, trimmed in endless so late waves stay a squeeze.
func late_gold(amount: int) -> int:
	if wave <= Data.FINAL_WAVE or amount <= 0:
		return amount
	return maxi(1, roundi(amount * late_gold_share()))


func _on_enemy_died(e) -> void:
	enemies_changed()
	sfx("die", 1.3 if e.radius < 14.0 else (0.7 if e.radius > 20.0 else 1.0))
	spawn_corpse(e)
	if e.boss:
		# A boss brought down: a blinding flash, a boom, and word of it.
		spawn_flash(e.position, 90.0)
		sfx("boom")
		boss_down = "%s is defeated!" % Data.ENEMIES[e.kind].get("name", e.kind.capitalize())
		hud.show_message(boss_down)
	elif e.kind == "warlord" or e.kind == "wyvern":
		spawn_burst(e.position, 50.0, Color(1.0, 0.85, 0.35))   # an elite down
		sfx("crumble")
	var bounty := late_gold(e.bounty)
	gold += bounty
	spawn_text(e.position, "+%d" % bounty, Color(1, 0.85, 0.2))
	# Necromancy: what dies rotting gets back up on your side.
	if e.decay_timer > 0.0 and is_instance_id_valid(e.decay_source):
		var mage = instance_from_id(e.decay_source)
		if is_instance_valid(mage) and not mage.is_queued_for_deletion() and mage.is_active():
			mage.raise_from_corpse(e.position)


func _on_enemy_at_castle(_e) -> void:
	if not gates_warned and not game_over:
		gates_warned = true
		hud.show_message("The enemy is at the gates!")


## The castle at the bottom of the field, or (rules without one) the work camp in its place.
func _show_castle(on: bool) -> void:
	castle.visible = on
	castle.top_part.visible = on
	if on and camp != null:
		camp.queue_free()
		camp = null
	elif not on and camp == null and rules.show_camp():
		camp = Camp.new()
		camp.main = self
		add_child(camp)
		move_child(camp, castle.get_index())


## Where an Engineer sets out from: the castle gate, or the battle's own camp.
func engineer_gate() -> Vector2:
	var g: Vector2 = rules.entry_point(Vector2.ZERO)
	return g if g != Vector2.INF else Vector2(FIELD_W / 2.0, CASTLE_Y + 6.0)


## Puts a mission objective on the field (under the troops, over the ground).
func add_objective(o: Node2D) -> void:
	if objective_layer == null:
		objective_layer = Node2D.new()
		add_child(objective_layer)
		move_child(objective_layer, wall_layer.get_index())
		roof_layer = Node2D.new()
		add_child(roof_layer)
		move_child(roof_layer, powers.get_index())
	objective_layer.add_child(o)
	o.make_roof(roof_layer)


## Enemies hitting the castle. In freeplay it can't fall.
func damage_castle(amount: float) -> void:
	if game_over or amount <= 0.0 or not rules.has_castle():
		return
	amount *= 1.0 - powers.armor()
	castle_hp -= amount
	castle.struck(amount)
	sfx("castle")
	if amount >= 15.0:
		spawn_text(Vector2(randf_range(80, FIELD_W - 80), CASTLE_Y - 10), "-%d" % roundi(amount), Color(1, 0.3, 0.3))
	if freeplay or tutorial:
		castle_hp = maxf(castle_hp, 1.0)   # can't fall here
	elif castle_hp <= 0.0:
		castle_hp = 0.0
		_finish(false)
	else:
		_warn_castle()


## The alarm bell, as the castle falls below half its health and again below a quarter.
var castle_warned := 0   # (how many of those it's rung this battle)
const CASTLE_ALARMS := [[0.5, "The castle's walls are cracking!"], [0.25, "The castle is about to fall!"]]

func _warn_castle() -> void:
	while castle_warned > 0 and castle_hp > castle_max * (CASTLE_ALARMS[castle_warned - 1][0] + 0.1):
		castle_warned -= 1   # (mended well clear of it: it can ring again)
	if castle_warned >= CASTLE_ALARMS.size() or castle_hp > castle_max * CASTLE_ALARMS[castle_warned][0]:
		return
	while castle_warned < CASTLE_ALARMS.size() and castle_hp <= castle_max * CASTLE_ALARMS[castle_warned][0]:
		castle_warned += 1
	sfx("alarm")
	var mend := " Repair it between waves [B]." if allowed("repair") else ""
	hud.show_message(CASTLE_ALARMS[castle_warned - 1][1] + mend)


# --- Castle ---------------------------------------------------------------

## An Abilities tab button: buys the ability, or uses it once it's bought.
func ability_item(key: String) -> void:
	if game_over or not started or _locked("ability:" + key):
		return
	if powers.owned.has(key):
		powers.trigger(key)
	elif not powers.buy(key):
		hud.show_message("Not enough gold")


## A Castle tab card: the next tier of castle path p.
func castle_upgrade(p: int) -> void:
	if game_over or not started or _locked("path:%d" % p):
		return
	if not powers.upgrade(p) and not powers.next_tier(p).is_empty():
		hud.show_message("Not enough gold")


## What Repair button i (see Data.REPAIR_CHUNKS) mends now. The full repair, when you
## can't afford it, becomes as much repair as all your gold buys.
func repair_amount(i: int) -> float:
	var amount := minf(roundf(castle_max * Data.REPAIR_CHUNKS[i]), castle_max - castle_hp)
	if Data.REPAIR_CHUNKS[i] >= 1.0 and repair_cost(amount) > gold:
		amount = affordable_repair()
	return amount


## Whether the full repair is beyond your gold (so it spends all you have instead).
func repair_all_gold() -> bool:
	return castle_max - castle_hp >= 1.0 and repair_cost(castle_max - castle_hp) > gold


## The most health (whole points) your gold can mend right now.
func affordable_repair() -> float:
	var lo := 0
	var hi := int(castle_max - castle_hp)
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if repair_cost(mid) <= gold:
			lo = mid
		else:
			hi = mid - 1
	return float(lo)


## What mending `amount` costs: a flat price, its share of max health times
## REPAIR_FULL_COST (whatever the wave or the castle's state), at this difficulty's prices.
func repair_cost(amount: float) -> int:
	if amount <= 0.0:
		return 0
	return price(Data.REPAIR_FULL_COST * amount / castle_max)


func can_repair(i: int) -> bool:
	var amount := repair_amount(i)
	return allowed("repair") and not wave_active and not game_over and repair_job.is_empty() and amount >= 1.0 and gold >= repair_cost(amount)


func repair_castle(i: int) -> void:
	if game_over or not started or _locked("repair"):
		return
	if wave_active:
		hud.show_message("Repairs wait until the wave is over")
		return
	var amount := repair_amount(i)
	if amount < 1.0:
		return
	if gold < repair_cost(amount):
		hud.show_message("Not enough gold")
		return
	if not repair_job.is_empty():
		hud.show_message("The Engineers are still at work")
		return
	gold -= repair_cost(amount)
	# Engineers come out to three stretches of the wall; the health comes back while
	# they work (see repair_tick).
	var share := amount / castle_max
	var seconds: float = Data.REPAIR_TIME[0] + Data.REPAIR_TIME[1] * share
	repair_job = {"left": amount, "rate": amount / seconds, "total": amount}
	for f in [0.25, 0.5, 0.75]:
		send_engineer("repair", null, Vector2(FIELD_W * f + (0.0 if f != 0.5 else 70.0), CASTLE_Y - 10.0))
	sfx("place")


## Sends an Engineer out of the gate: to build `site`, or to repair the wall at `spot`.
func send_engineer(job: String, site, spot: Vector2) -> void:
	var e := Engineer.new()
	e.main = self
	e.job = job
	e.site = site
	e.spot = spot
	e.position = e.gate()
	fx_layer.add_child(e)


## A working repair Engineer's share of the repair coming in (three of them at it).
func repair_tick(delta: float) -> void:
	if repair_job.is_empty():
		return
	var bit := minf(repair_job["rate"] / 3.0 * delta, repair_job["left"])
	repair_job["left"] -= bit
	castle_hp = minf(castle_hp + bit, castle_max)
	if repair_job["left"] <= 0.01:
		spawn_text(Vector2(FIELD_W / 2.0, CASTLE_Y - 60), "+%d castle" % roundi(repair_job["total"]), Color(0.5, 1.0, 0.5))
		repair_job = {}


## The mouse is over the castle with nothing else in the way (for its hover card and outline).
func _castle_hovered() -> bool:
	return started and not game_over and dragging == null and placing_type == "" and powers.aiming == "" \
			and on_castle(mouse) and _warrior_at(mouse) == null


## Whether p is on the castle (its wall or a tower), for clicking it.
func on_castle(p: Vector2) -> bool:
	if not rules.has_castle():
		return false
	if p.y >= CASTLE_Y - 4.0 and p.y <= FIELD_H:
		return true
	for r in castle._towers():
		if r.has_point(p):
			return true
	return false


## Selects the castle: the panel shows its upgrade paths.
func select_castle() -> void:
	if game_over or not started or not rules.has_castle():
		return
	_cancel()
	castle_selected = true


## Auto-play on or off. Turned on between waves, the next one comes after AUTO_DELAY.
func toggle_auto() -> void:
	if freeplay or game_over:
		return
	if forced_auto:
		hud.show_message("This battle doesn't wait: the attacks keep coming")
		return
	auto_play = not auto_play
	auto_timer = AUTO_DELAY
	hud.show_message("Auto-play on" if auto_play else "Auto-play off")


## Seconds between waves under auto-play. A forced pace: what's left of the window (at
## least MIN_BREAK).
func auto_delay() -> float:
	return maxf(MIN_BREAK, pace_window() - wave_clock) if forced_auto else AUTO_DELAY


const PACE_WINDOW := 25.0   # forced pace: seconds from the last of a wave arriving to the next wave
const PACE_WINDOWS := {"capture": 16.0, "escort": 15.0, "protect": 18.0, "retreat": 20.0, "evac": 25.0}   # ...by kind of battle
const MIN_BREAK := 5.0      # ...and the shortest breather once a wave's beaten
const REST_HEAL := 0.04     # share of its health a troop gets back each second of a breather


## A forced pace's window between waves: from the last of one wave arriving to the next
## wave ("pace": {"window"}), time to finish it off, let the troops recover and reset.
func pace_window() -> float:
	return float(mission.get("pace", {}).get("window", PACE_WINDOWS.get(mission.get("type", ""), PACE_WINDOW)))


## Seconds until the next wave under a forced pace (or auto-play), -1 if it isn't counting.
func next_wave_in() -> float:
	if forced_auto and wave_active and spawn_queue.is_empty():
		return maxf(0.0, pace_window() - wave_clock)
	if auto_play and not wave_active:
		return maxf(0.0, auto_timer)
	return -1.0


## A breather between waves: the troops catch their breath and get some health back.
func _rest(delta: float) -> void:
	for w in get_warriors():
		if w.is_active() and not w.is_emplacement() and w.hp < w.max_hp:
			w.hp = minf(w.max_hp, w.hp + w.max_hp * REST_HEAL * delta)


func _end_wave() -> void:
	auto_timer = auto_delay()
	wave_active = false
	sfx("fanfare")
	for w in get_warriors():
		# The wave's held: they cheer, each starting at its own moment (from its id, not
		# randf: a cheer mustn't change the game's random rolls).
		w.cheer(Warrior.CHEER_HOP * 3.0, float(w.get_instance_id() % 7) * 0.05)
	var bonus := late_gold(20 + wave * 5)
	gold += bonus
	# Gold Mines pay their end-of-wave bonus on top, and every Treasury pays interest
	# (each on the gold you had before any interest came in).
	var banked := gold
	for w in get_warriors():
		var interest := 0
		if w.is_active() and not w.interest.is_empty():
			interest = mini(int(banked * w.interest[0]), int(w.interest[1]))
		gold += w.wave_payout(interest)
	if rules.wave_cleared(wave):
		_finish(true)   # the mission's last wave: it's won
		return
	_survived_wave()
	if not scripted() and wave == Data.FINAL_WAVE and not endless:
		# Classic goes on: from here the enemy toughens faster and pays less.
		endless = true
		hud.show_message("Wave %d held! From here they come harder, and pay less. How far can you go?" % wave)
	elif not (survival() and beat_best and wave == best_before + 1):
		hud.show_message("%sWave %d cleared! +%d gold" % [boss_down + " " if boss_down != "" else "", wave, bonus])
	boss_down = ""


## Kinds that can't fight, sold off to pay for troops when it comes to it.
const NON_FIGHTERS := ["mine", "statue", "medbay", "barricade"]
const ROUT_GRACE := 3.0   # seconds with no army and no way to raise one before it's over


## The army is gone (every troop dead, nothing on the wall either), and there's no way to
## raise another: no Gold Mine to earn with, and not enough gold to hire anything, even
## selling what can't fight. Lasting a moment (a wave's bonus about to come in still
## counts), that's the battle lost. Not in Freeplay or the Tutorial.
func _check_rout(delta: float) -> void:
	if freeplay or tutorial or deploying:
		rout_time = 0.0
		return
	if not _army_gone():
		rout_time = 0.0
		return
	rout_time += delta
	if rout_time >= ROUT_GRACE:
		routed = true
		hud.show_message("Your army is gone, and there's no gold to raise another")
		_finish(false)


func _army_gone() -> bool:
	var funds := gold
	for w in get_warriors():
		if w.kind == "mine":
			return false   # it'll earn more
		if not NON_FIGHTERS.has(w.kind):
			return false   # still someone fighting (or downed, and maybe revived)
		funds += w.sell_value()
	if rules.has_castle() and not powers.guards.is_empty():
		return false   # the wall's own guards fight on
	for b in get_barricades():
		funds += int(b.spent * 0.6)
	for k in Data.WARRIORS:
		if k != "barricade" and allowed(k) and funds >= hire_cost(k):
			return false
	return true


## This battlefield's own battle music (getting it composed now, ready for the first wave).
func set_battle_music(map: Dictionary) -> void:
	battle_music = Audio.battle_for(map)
	audio.prepare(stage_music)   # (a map's own peaceful music first, if it's made on demand: it's needed first)
	audio.prepare(battle_music)


## A survival battle (Classic, a Battle Modes scenario): the run goes on until it's
## lost, and the score is the waves survived.
func survival() -> bool:
	if freeplay or tutorial or campaign:
		return false
	return not scripted() or mission.get("endless", false)


## Waves survived so far this run (a forced pace sends the next before the last is beaten:
## one counts once the next has come, or once it's been cleared).
func waves_survived() -> int:
	return wave if not wave_active else wave - 1


## Wave `wave` is behind us: a word when that beats the best.
func _survived_wave() -> void:
	if survival() and not beat_best and best_before > 0 and waves_survived() > best_before:
		beat_best = true
		hud.show_message("New best: %d waves!" % waves_survived())
		sfx("fanfare", 1.2)


## This battle's best before (Classic: per difficulty and battlefield; a scenario: per difficulty).
func _best_record() -> int:
	if records_path == "":
		return 0
	var cfg := ConfigFile.new()
	cfg.load(records_path)
	if battle_id != "":
		return cfg.get_value("survive", "%s@%s" % [battle_id, difficulty], 0)
	return cfg.get_value("best", difficulty + ("@" + map_id if map_id != "" else ""), 0)


# --- Campaign ------------------------------------------------------------

## Where a fresh scene starts: the title screen, or (between campaign battles, which
## reload the scene) the map or a mission.
func _open_start_screen() -> void:
	var where: String = Campaign.screen
	Campaign.screen = ""
	if where.begins_with("battle:"):
		_on_mode_chosen(where)   # a Battle Modes scenario played again
	elif where == "map":
		open_world_map()
	elif where == "battle" and not Campaign.mission().is_empty():
		choose_mode("campaign")
	else:
		_lock_portrait(false)
		hud.show_mode_select()


## A title-screen choice: a Classic difficulty, Freeplay, the Tutorial, or the campaign
## ("campaign:continue[:<slot>]", "campaign:new:<difficulty>[:<slot>]": the save slot in
## use when there's none).
func _on_mode_chosen(key: String) -> void:
	if key.begins_with("campaign:continue"):
		if key.get_slice_count(":") > 2:
			Campaign.use_slot(int(key.get_slice(":", 2)))
		if Campaign.load_game():
			open_world_map()
		else:
			hud.show_mode_select()
			hud.show_message(Campaign.load_error if Campaign.load_error != "" else "No campaign saved yet")
	elif key.begins_with("campaign:new:"):
		if key.get_slice_count(":") > 3:
			Campaign.use_slot(int(key.get_slice(":", 3)))
		Campaign.new_campaign(key.get_slice(":", 2))
		play_prologue()
	elif key.begins_with("battle:"):
		# A Battle Modes scenario: "battle:<scenario>:<difficulty>".
		battle_id = key.get_slice(":", 1)
		choose_mode(key.get_slice(":", 2))
	else:
		# Classic on a campaign battlefield comes as "<difficulty>|<map>".
		classic_map = key.get_slice("|", 1) if "|" in key else ""
		choose_mode(key.get_slice("|", 0))


func open_world_map() -> void:
	_lock_portrait(true)
	hud.hide_mode_select()
	var m = hud.show_world_map(Campaign)
	m.defend.connect(start_mission)
	m.menu.connect(func():
		Campaign.screen = ""
		_restart())
	m.sound.connect(func(n): sfx(n))
	m.prologue.connect(play_prologue)


## The prologue cutscene (a new campaign, or replayed from the Ledger), then the map.
func play_prologue() -> void:
	_lock_portrait(true)
	hud.hide_mode_select()
	hud.hide_world_map()
	hud.play_prologue(open_world_map)


func start_mission(id: String) -> void:
	Campaign.mission_id = id
	hud.hide_world_map()
	choose_mode("campaign")


## Campaign maps and battles keep the 640-wide portrait field whatever the window's
## shape (scaled to fit, with bars at the sides); Classic and the rest widen the field
## on a wide window, as before.
func _lock_portrait(on: bool) -> void:
	var root := get_tree().root
	var want := Window.CONTENT_SCALE_ASPECT_KEEP if on else Window.CONTENT_SCALE_ASPECT_EXPAND
	if root.content_scale_aspect != want:
		root.content_scale_aspect = want
		_fit_screen()


## The mission's opening: its starting gold, the help already on the field, and its story.
func _begin_mission() -> void:
	gold = mission.get("gold", Data.START_GOLD)
	for a in mission.get("allies", []):
		_lend_unit(a)
	if campaign:
		_send_help()
	var intro: String = mission.get("intro", "")
	if intro != "" and not Campaign.seen.has(intro):
		Campaign.mark_seen(intro)
		hud.play_story(Campaign.story_lines(intro))


## A unit on loan for this battle ({"kind", "at"} as drawn up): free, and worth nothing sold.
func _lend_unit(a: Dictionary) -> void:
	var kind: String = a["kind"]
	var w := Warrior.new()
	var at: Vector2 = a["at"]
	w.setup(kind, Data.WARRIORS[kind], self, Vector2(at.x * FIELD_W / Maps.BASE_W, at.y))   # placed on the map as stretched
	w.spent = 0   # on loan: selling it brings nothing
	w.position = w.post
	warrior_layer.add_child(w)
	temp_allies.append(w)


## The peoples who've joined the Line send help ("help": {faction: {...}}), each only if
## they're allied: "allies" (units on loan), "gold", "free" (abilities, owned from the
## start: they can be cast though not yet unlocked), "down_time" (fallen troops hold on
## that much longer), "walls" ([[a, b]]: barricades already up).
func _send_help() -> void:
	var sent := []
	for f in mission.get("help", {}):
		if not Campaign.allied(f):
			continue
		var h: Dictionary = mission["help"][f]
		for a in h.get("allies", []):
			_lend_unit(a)
		gold += int(h.get("gold", 0))
		for key in h.get("free", []):
			help_lend.append("ability:" + key)
			powers.owned[key] = true
		down_time *= float(h.get("down_time", 1.0))
		var k: float = FIELD_W / Maps.BASE_W
		for seg in h.get("walls", []):
			var a: Vector2 = Vector2(seg[0].x * k, seg[0].y)
			var b: Vector2 = Vector2(seg[1].x * k, seg[1].y)
			var wall := Barricade.new()
			wall.half = (b - a) / 2.0
			wall.setup("barricade", Data.WARRIORS["barricade"], self, (a + b) / 2.0)
			wall.spent = 0
			wall.position = wall.post
			wall_layer.add_child(wall)
		if not h.get("walls", []).is_empty():
			walls_changed()
		sent.append(h.get("note", f.capitalize()))
	if not sent.is_empty():
		hud.show_message("Help has come: " + ", ".join(sent))


## The mission's waves: wave n draws from every enemy kind its pool has added by then,
## plus that wave's extras.
func _mission_wave(n: int) -> Array:
	var pool := []
	for w in mission["pool"]:
		if n >= w:
			pool.append_array(mission["pool"][w])
	var c: Array = mission.get("count", [6, 2])
	var list := []
	for i in c[0] + c[1] * n:
		list.append(pool.pick_random())
	for k in mission.get("extra", {}).get(n, []):
		list.insert(randi_range(list.size() / 2, list.size()), k)
	if mission.get("endless", false):
		# On and on: Warlords lead every fifth wave from the tenth, Wyverns swoop in on the
		# even waves between from the twelfth (one more of each every ten waves).
		if n >= 10 and n % 5 == 0:
			for i in 1 + (n - 10) / 10:
				list.append("warlord")
		elif n >= 12 and n % 2 == 0:
			for i in 1 + (n - 12) / 10:
				list.insert(randi_range(list.size() / 3, list.size()), "wyvern")
	return list


## Enemy strength on wave n (Classic: the wave number; a mission starts at its level).
func wave_level(n: int) -> int:
	return int(mission["level"]) + n - 1 if scripted() else n


## The wave that ends the game (or, in Classic, offers endless).
func last_wave() -> int:
	return int(mission.get("waves", 0)) if scripted() else Data.FINAL_WAVE


## Whether this battle follows a mission (a campaign battle, or a Battle Modes scenario)
## rather than Classic's endless waves.
func scripted() -> bool:
	return not mission.is_empty()


## Story flags the mission sets on a win: each "track" flag whose starting ally is still up.
func _mission_flags() -> Array:
	var out := []
	var track: Dictionary = mission.get("track", {})
	for flag in track:
		for w in temp_allies:
			if is_instance_valid(w) and not w.is_queued_for_deletion() and w.kind == track[flag] and w.is_active():
				out.append(flag)
				break
	return out


## Whether unlock key `key` (a unit kind, "ability:x", "path:n", "repair") can be used
## in this game. Only a campaign mission locks anything.
func allowed(key: String) -> bool:
	return not campaign or Campaign.allows(key, mission.get("lend", []) + help_lend)


## The highest upgrade tier `kind` may take on path `p` here: all four outside the
## campaign; in it, what that unit has been trained for on that path (see
## Campaign.path_tier). Without a path: its best-trained path.
func max_tier(kind: String, p := -1) -> int:
	if not campaign:
		return Warrior.MAX_TIER
	return Campaign.path_tier(kind, p) if p >= 0 else Campaign.trained_tier(kind)


## Campaign experience: `amount` of `what` (an XP_RATES key) done by unit kind `kind`
## this battle. Outside a campaign, or with no one to credit, it counts for nothing.
func earn_xp(kind: String, amount: float, what := "damage") -> void:
	if campaign and kind != "" and amount > 0.0:
		battle_xp[kind] = battle_xp.get(kind, 0.0) + amount * CD_XP_RATES[what]


## Why `key` is locked ("" if it isn't).
func lock_note(key: String) -> String:
	return "" if allowed(key) else Campaign.lock_reason(key, mission.get("lend", []) + help_lend)


## Stops a locked action with a message saying who unlocks it.
func _locked(key: String) -> bool:
	if allowed(key):
		return false
	hud.show_message(lock_note(key))
	return true


func retry_mission() -> void:
	Campaign.screen = "battle"
	_restart()


func back_to_map() -> void:
	_bank_unfinished()
	Campaign.screen = "map"
	_restart()


## A campaign battle left before it ended (back to the map, or the game closed) earns
## nothing: its XP is dropped, and the save keeps what it had before the battle.
func _bank_unfinished() -> void:
	if campaign and not game_over:
		battle_xp = {}
		Campaign.last_battle = {}


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_bank_unfinished()


# --- Freeplay ------------------------------------------------------------

func change_freeplay_level(step: int) -> void:
	freeplay_level = clampi(freeplay_level + step, 1, FREEPLAY_MAX_LEVEL)


## Queues the selected wave on top of whatever is already coming.
func spawn_freeplay_wave() -> void:
	if not started or game_over:
		return
	if dragging != null:
		_end_drag()
	spawn_queue.append_array(_build_wave(freeplay_level).map(func(k): return [k, freeplay_level]))
	spawn_interval = maxf(0.35, 0.9 - freeplay_level * 0.03)
	hud.show_message("Wave %d incoming" % freeplay_level)


func spawn_single(kind: String) -> void:
	if dragging != null:
		_end_drag()
	_spawn_enemy(kind, freeplay_level)


func clear_enemies() -> void:
	spawn_queue.clear()
	for e in get_enemies():
		e.dead = true
		e.queue_free()


func _finish(won: bool) -> void:
	audio.set_track("")
	sfx("victory" if won else "defeat")
	game_over = true
	victory = won
	run_survived = wave if won else waves_survived()   # (counted while the wave being fought is still on)
	wave_active = false
	Engine.time_scale = 1.0
	_cancel()
	enemy_layer.process_mode = Node.PROCESS_MODE_DISABLED
	warrior_layer.process_mode = Node.PROCESS_MODE_DISABLED
	wall_layer.process_mode = Node.PROCESS_MODE_DISABLED
	var survived := run_survived
	if campaign:
		Campaign.finish_mission(won, _mission_flags() if won else [], battle_xp)
		hud.show_campaign_end(won, mission, survived, _summary(won))
		return
	if battle_id != "":
		_finish_battle_mode(won)
		return
	var previous := _save_record(survived)
	hud.show_end(won, survived, previous, endless, "Your army is gone" if routed else "")


## How the battle went, for the end screen.
func _summary(won: bool) -> String:
	if routed:
		return "Every troop was lost, with no gold left to raise more."
	return rules.summary(won)


## A survival run's waves, kept if they beat its best.
func _keep_survival_record(survived: int) -> void:
	if battle_id == "":
		_save_record(survived)
		return
	if records_path == "":
		return
	var cfg := ConfigFile.new()
	cfg.load(records_path)
	var key := "%s@%s" % [battle_id, difficulty]
	if survived > int(cfg.get_value("survive", key, 0)):
		cfg.set_value("survive", key, survived)
		cfg.save(records_path)


## A Battle Modes scenario over: how long it lasted, its best (waves survived, kept per
## scenario and difficulty), and the way to play it again.
func _finish_battle_mode(won: bool) -> void:
	var survived := run_survived
	var best := _best_record() if records_path != "" else best_before
	_keep_survival_record(survived)
	var record := "New best!" if survived > best else "Best: %d waves" % best
	hud.show_battle_end(won, mission["name"], _summary(won), record, "battle:%s:%s" % [battle_id, difficulty], survived)


## Plays a Battle Modes scenario again from the start (the scene reloads, as for any game).
func play_again(key: String) -> void:
	Campaign.screen = key
	_restart()


## Records the waves survived if it beats this mode's best; returns the best from before.
func _save_record(survived: int) -> int:
	if records_path == "" or tutorial:
		return 0
	var cfg := ConfigFile.new()
	cfg.load(records_path)
	var key := difficulty + ("@" + map_id if map_id != "" else "")   # each battlefield keeps its own best
	var previous: int = cfg.get_value("best", key, 0)
	if survived > previous:
		cfg.set_value("best", key, survived)
		cfg.save(records_path)
	return previous


func _restart() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func cycle_speed() -> void:
	if game_over:
		return
	Engine.time_scale = 1.0 if Engine.time_scale >= 3.0 else Engine.time_scale + 1.0


# --- Warriors ------------------------------------------------------------

func _on_hire_pressed(kind: String) -> void:
	if game_over or _locked(kind):
		return
	selected = null
	group.clear()
	castle_selected = false
	wall_start = null
	powers.aiming = ""
	placing_type = "" if placing_type == kind else kind


func can_post_at(p: Vector2, ignore: Warrior = null) -> bool:
	if p.x < 0 or p.x > FIELD_W or p.y < DEPLOY_TOP or p.y > CASTLE_Y:
		return false
	if ground_problem(p) != "":
		return false
	for w in get_warriors():
		if w != ignore and w.post.distance_to(p) < MIN_POST_GAP:
			return false
	for b in get_barricades():
		if b.gap_from(p) < Warrior.RADIUS:
			return false
	return true


## Why the battlefield itself won't take a post at p ("" if it will): rock, cliff,
## trees or the quarry, a spot troops can't walk to, or ground kept clear (the gate).
## Always "" on the open meadow (Classic, Freeplay, the Tutorial).
func ground_problem(p: Vector2) -> String:
	for o in rules.objectives():
		if o.is_solid() and p.distance_to(o.position) < o.RADIUS + Warrior.RADIUS:
			return "Keep the %s clear" % o.label.to_lower()
	if not paths.has_terrain():
		return ""
	if paths.in_no_build(p):
		return "Keep the gate clear"
	if paths.blocked(p, Warrior.RADIUS):
		return "Can't stand there"
	if not paths.troop_can_stand(p):
		return "Your troops can't get there"
	return ""


# --- Barricades ----------------------------------------------------------

## Where a wall started at `a` ends when the player points at `b`: clamped to the
## field and to the longest wall allowed.
## Walls can be as long as the field allows; the price is the only limit.
func wall_end(_a: Vector2, b: Vector2) -> Vector2:
	return _clamp_wall_point(b)


func _clamp_wall_point(p: Vector2) -> Vector2:
	return p.clamp(Vector2(0, DEPLOY_TOP), Vector2(FIELD_W, CASTLE_Y - 16))


func wall_cost(a: Vector2, b: Vector2) -> int:
	return price(Barricade.cost_for(Data.WARRIORS["barricade"], a.distance_to(b)))


## A price adjusted for the difficulty.
func price(base: float) -> int:
	return Data.scaled_price(base, cost_mult, price_step)


## What hiring this kind costs (the shortest wall, for a barricade).
func hire_cost(kind: String) -> int:
	return price(Data.WARRIORS[kind]["cost"])


## Why a wall can't go from a to b ("" if it can). Walls may cross each other,
## but not run through another unit's post.
func wall_problem(a: Vector2, b: Vector2) -> String:
	if a.distance_to(b) < Data.WARRIORS["barricade"]["min_length"]:
		return "Too short"
	for w in get_warriors():
		var c := Geometry2D.get_closest_point_to_segment(w.post, a, b)
		if c.distance_to(w.post) < Warrior.RADIUS + Barricade.WALL_HALF:
			return "Blocked by a unit"
	for o in rules.objectives():
		if o.is_solid() and Geometry2D.get_closest_point_to_segment(o.position, a, b).distance_to(o.position) < o.RADIUS + Barricade.WALL_HALF:
			return "Can't wall through the %s" % o.label.to_lower()
	return ""


## Barricades go down in two clicks: where the wall starts, then where it ends.
func _wall_click(p: Vector2) -> void:
	if wall_start == null:
		if p.y >= DEPLOY_TOP:
			wall_start = _clamp_wall_point(p)
		return
	var a: Vector2 = wall_start
	var b := wall_end(a, p)
	var problem := wall_problem(a, b)
	if problem != "":
		hud.show_message(problem)
		return
	var cost := wall_cost(a, b)
	if gold < cost:
		hud.show_message("Not enough gold")
		return
	gold -= cost
	sfx("place")
	var wall := Barricade.new()
	wall.half = (b - a) / 2.0
	wall.setup("barricade", Data.WARRIORS["barricade"], self, (a + b) / 2.0)
	wall.spent = cost
	wall.position = wall.post
	wall_layer.add_child(wall)
	walls_changed()
	wall_start = null
	# Hold Shift to keep building walls.
	if not Input.is_key_pressed(KEY_SHIFT) or gold < hire_cost("barricade"):
		placing_type = ""


func hire_at(p: Vector2) -> void:
	if placing_type != "" and not allowed(placing_type):
		placing_type = ""   # never place something the campaign hasn't unlocked
		return
	if placing_type == "barricade":
		_wall_click(p)
		return
	if not can_post_at(p):
		if ground_problem(p) != "":
			hud.show_message(ground_problem(p))
		return
	var data: Dictionary = Data.WARRIORS[placing_type]
	var cost := hire_cost(placing_type)
	if gold < cost:
		hud.show_message("Not enough gold")
		placing_type = ""
		return
	gold -= cost
	sfx("place")
	spawn_burst(_clamp_post(p) + Vector2(0, 10), 26.0, Color(0.9, 0.82, 0.62))   # a puff of dust where it lands
	var w := Warrior.new()
	w.setup(placing_type, data, self, _clamp_post(p))
	w.spent = cost
	w.priority = last_priority.get(placing_type, Warrior.OBJECTIVE_PRIORITY if rules.guards() else "closest")
	if w.is_mobile_healer():
		w.priority = last_priority.get(placing_type, "revive")
	if last_orders.has(placing_type):
		var o: Dictionary = last_orders[placing_type]
		w.commit = o["commit"]
		w.move_mode = o["move_mode"]
		var area: Rect2 = o["guard_area"]
		if area.has_point(w.post):
			w.guard_area = area   # hired into the area its kind was last given: it guards it too
		w.danger_mode = o["danger_mode"]
		w.call_help = o["call_help"]
		w.answer = o["answer"]
	# New hires march in from whichever side of the field is nearer their post;
	# emplacements are built on the spot.
	w.position = w.post if w.is_emplacement() else _entry_point(w.post)
	warrior_layer.add_child(w)
	if w.is_emplacement():
		# An Engineer comes out of the castle to build it.
		w.build_left = Data.BUILD_TIME
		w.build_total = Data.BUILD_TIME
		send_engineer("build", w, Vector2.ZERO)
	# Hold Shift to keep hiring the same type.
	if not Input.is_key_pressed(KEY_SHIFT) or gold < cost:
		placing_type = ""


## Where a new troop walks on: the nearer side edge, level with its post, nudged up
## or down the edge if a wall runs into it there. On a campaign battlefield (whose edges
## may be cliffs) troops come out of the castle gate instead.
func _entry_point(post: Vector2) -> Vector2:
	var r := Warrior.RADIUS
	var from: Vector2 = rules.entry_point(post)
	if from != Vector2.INF:
		return from   # the battle's own way in (a wagon carrying the camp)
	if paths.has_terrain():
		return Vector2(FIELD_W / 2.0, CASTLE_Y - r)
	var x := r if post.x < FIELD_W / 2.0 else FIELD_W - r
	for step in 40:
		for sign in [1, -1]:
			var y := clampf(post.y + sign * step * 8.0, DEPLOY_TOP, CASTLE_Y - r)
			var spot := Vector2(x, y)
			if not get_barricades().any(func(b): return b.gap_from(spot) < r + 2.0):
				return spot
	return Vector2(x, post.y)


func _clamp_post(p: Vector2) -> Vector2:
	var r := Warrior.RADIUS
	return p.clamp(Vector2(r, DEPLOY_TOP), Vector2(FIELD_W - r, CASTLE_Y - r))


# --- Group selection ---------------------------------------------------------

## Troops that can be picked up in a group (not emplacements, skeletons or copies).
func _groupable(w) -> bool:
	return w is Warrior and not w.is_emplacement() and not w.summoned and w.clone_of == null and not w is Barricade


func _set_group(units: Array) -> void:
	var picked := units.filter(_groupable)
	castle_selected = false
	selected_grave = null
	placing_type = ""
	if picked.size() == 1:
		group.clear()
		selected = picked[0]
	else:
		group = picked
		selected = null


## Shift+click: adds a troop to the selection, or takes it out.
func _toggle_in_group(w) -> void:
	var now := group.duplicate()
	if now.is_empty() and selected != null and _groupable(selected):
		now = [selected]
	if now.has(w):
		now.erase(w)
	else:
		now.append(w)
	_set_group(now)
	if now.is_empty():
		selected = null


func select_all_troops() -> void:
	if started and not game_over:
		_set_group(get_warriors())


## The selection box, in field coordinates (while one's being dragged).
func selection_box() -> Rect2:
	return Rect2(box_start, mouse - box_start).abs() if box_start != null and box_active else Rect2()


func _finish_box() -> void:
	if box_active:
		var r := selection_box()
		var inside := get_warriors().filter(func(w): return _groupable(w) and r.grow(Warrior.RADIUS * 0.5).has_point(w.position))
		var now := group.duplicate() if box_add else []
		if box_add and now.is_empty() and selected != null and _groupable(selected):
			now = [selected]
		for w in inside:
			if not now.has(w):
				now.append(w)
		_set_group(now)
		if now.is_empty():
			selected = null
	else:
		# Just a click on open field: clear the selection.
		_cancel()
	box_start = null
	box_active = false


## Keeps only the group's troops of `kind` (or, with `drop`, all but them).
func filter_group(kind: String, drop: bool) -> void:
	_set_group(group.filter(func(w): return (w.kind == kind) != drop))


## Sends the whole group to p, keeping their formation: each goes to p plus where it
## stood relative to the group's middle (nudged to the nearest free spot if that's taken).
func order_group(p: Vector2) -> void:
	if group.is_empty():
		return
	for w in group:
		w.anchor = null   # a move order sets fixed posts again
	var mid := Vector2.ZERO
	for w in group:
		mid += w.post
	mid /= group.size()
	var taken := []
	for w in group:
		var spot := _free_spot(_clamp_post(p + (w.post - mid)), taken)
		if spot != Vector2.INF:
			taken.append(spot)
			w.order_to(spot)
	sfx("place", 1.3)


## p if a group member could stand there (other troops' posts, walls and the spots
## already handed out to the group all count, the group's own old posts don't), else
## the nearest free spot close by, or INF.
func _free_spot(p: Vector2, taken: Array) -> Vector2:
	for r in [0.0, 18.0, 32.0, 46.0] + ([64.0, 84.0, 104.0] if paths.has_terrain() else []):   # further out round rock
		for i in (1 if r == 0.0 else 8):
			var q := _clamp_post(p + Vector2.from_angle(i * TAU / 8.0) * r)
			var ok := q.y >= DEPLOY_TOP and q.y <= CASTLE_Y and ground_problem(q) == ""
			for w in get_warriors():
				if not group.has(w) and w.post.distance_to(q) < MIN_POST_GAP:
					ok = false
			for t in taken:
				if t.distance_to(q) < MIN_POST_GAP:
					ok = false
			for b in get_barricades():
				if b.gap_from(q) < Warrior.RADIUS:
					ok = false
			if ok:
				return q
	return Vector2.INF


func _start_group_drag() -> void:
	group_drag = true
	group_from.clear()
	for w in group:
		group_from[w] = w.post
	drag_origin = get_local_mouse_position()   # where the press is now (not last frame's mouse)


func _update_group_drag() -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or wave_active:
		_end_group_drag()
		return
	var shift := mouse - drag_origin
	for w in group_from:
		if is_instance_valid(w):
			if shift.length() > LIFT_AFTER:
				w.held = true   # picked up: they dangle as they're carried (see Warrior._carry)
			var p := _clamp_post(group_from[w] + shift)
			w.post = p
			w.position = p


## Drops the dragged group; any that landed somewhere they can't stand go back.
func _end_group_drag() -> void:
	group_drag = false
	var taken := []
	var thud := false
	for w in group_from:
		if not is_instance_valid(w):
			continue
		if w.held and not thud:
			sfx("place")   # the group set down (one thud)
			thud = true
		w.held = false
		var p: Vector2 = w.post
		var ok := p.y >= DEPLOY_TOP and p.y <= CASTLE_Y and ground_problem(p) == ""
		for o in get_warriors():
			if not group_from.has(o) and o.post.distance_to(p) < MIN_POST_GAP:
				ok = false
		for b in get_barricades():
			if b.gap_from(p) < Warrior.RADIUS:
				ok = false
		if not ok:
			p = group_from[w]
		var let_go: Vector2 = w.position
		w.set_post(p)
		w.position = p
		if not ok:
			w.hop_back(let_go)
	group_from.clear()


func order_move(p: Vector2) -> void:
	if selected != null:
		selected.anchor = null   # a move order sets a fixed post again
	if selected == null or not can_post_at(p, selected):
		if selected != null and ground_problem(p) != "":
			hud.show_message(ground_problem(p))
		return
	if selected.is_emplacement():
		hud.show_message("Emplacements can't move during a wave")
		return
	selected.order_to(_clamp_post(p))


func upgrade_selected(path: int) -> void:
	if castle_selected and selected == null:
		castle_upgrade(path)   # Q/W/E/R buy the castle's upgrades while it's selected
		return
	if selected == null or selected.path_state(path) != "ok":
		return
	var cost := selected.upgrade_cost(path)
	if gold < cost:
		return
	var tier_name: String = selected.next_tier(path)["name"]
	gold -= cost
	selected.upgrade(path)
	selected.cheer(Warrior.CHEER_HOP)   # a hop of delight
	sfx("upgrade")
	spawn_text(selected.position + Vector2(0, -50), tier_name, Warrior.PATH_COLORS[path])
	spawn_sparkle(selected.position, Warrior.PATH_COLORS[path])
	if selected is Barricade:
		walls_changed()   # an Energy Wall may now let troops or shots through


# Between waves, units can be dragged anywhere and snap straight to the new spot.
func _start_drag(w: Warrior) -> void:
	dragging = w
	drag_origin = w.post
	drag_offset = w.post - mouse


func _update_drag() -> void:
	if not is_instance_valid(dragging):
		dragging = null
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_end_drag()
		return
	var p := _clamp_post(mouse + drag_offset)
	if dragging is Barricade:
		p = _clamp_wall_center(dragging, mouse + drag_offset)
	dragging.post = p
	dragging.position = p
	if not dragging is Barricade and p.distance_to(drag_origin) > LIFT_AFTER:
		dragging.held = true   # picked up (not just clicked): it dangles as it's carried (see Warrior._carry)


func _end_drag() -> void:
	var w := dragging
	dragging = null
	if not is_instance_valid(w):
		return
	if w.held:
		sfx("place")   # set down with a thud
	w.held = false
	var ok := can_post_at(w.post, w)
	if w is Barricade:
		ok = wall_problem(w.seg_a(), w.seg_b()) == ""
	var p := w.post if ok else drag_origin
	var let_go := w.position
	w.set_post(p)
	w.position = p
	if not ok and not w is Barricade:
		w.hop_back(let_go)
	if w is Barricade:
		walls_changed()


## Keeps a dragged wall's both ends on the field.
func _clamp_wall_center(w, p: Vector2) -> Vector2:
	var h: Vector2 = w.half.abs()
	return p.clamp(Vector2(h.x, DEPLOY_TOP + h.y), Vector2(FIELD_W - h.x, CASTLE_Y - 16 - h.y))


func cycle_target_priority() -> void:
	if selected == null:
		return
	selected.cycle_priority()
	if selected.is_mobile_healer():
		if selected.priority == "stay":
			selected.priority = "revive" if selected.wards.is_empty() else "stay"
			if selected.wards.is_empty():
				give_order("priority", "stay", [selected])   # (waits for the troop to stay with)
				return
		else:
			selected.stop_staying()
	if selected.priority != "stay":
		last_priority[selected.kind] = selected.priority
	spawn_text(selected.position + Vector2(0, -50), ("Focus: " if selected.is_mobile_healer() else "Target: ") + Warrior.PRIORITY_NAMES[selected.priority], Color(1, 1, 0.6))


# --- Orders: priority, commitment, movement zone ----------------------------------------

## The units an order goes to: the selected unit, or every troop in the group. (Barricades
## take no orders.)
func order_units() -> Array:
	var out := group.duplicate() if selected == null else [selected]
	return out.filter(func(w): return is_instance_valid(w) and w is Warrior)


## Gives `units` an order: "priority", "commit", "move_mode", "area" (a Guard Area drawn on
## the field: they go on Guard Area there), "danger_mode", "call_help" (true/false) or
## "answer". Emplacements, wall guards and Healers skip what doesn't apply to them.
## Remembered per kind for the next hire; kept through waves and upgrades.
func give_order(field: String, value, units: Array = []) -> void:
	if units.is_empty():
		units = order_units()
	for w in units:
		match field:
			"priority":
				if not Warrior.priorities_for_unit(w).has(value):
					continue   # (a Healer takes its own; the rest, target priorities)
				if w.is_mobile_healer():
					if value == "stay":
						continue   # (who to stay with: see below)
					w.stop_staying()
				elif not w.uses_targeting():
					continue
				w.priority = value
				w.target = null
				w.retarget_timer = 0.0
				last_priority[w.kind] = value
			"commit":
				if not w.uses_targeting():
					continue
				w.commit = value
			"move_mode":
				if w.is_emplacement() or w.wall_guard:
					continue
				w.move_mode = value
			"area":
				if w.is_emplacement() or w.wall_guard:
					continue
				w.guard_area = value
				w.move_mode = "guard"
			"danger_mode":
				if w.is_emplacement() or w.wall_guard:
					continue
				w.danger_mode = value
				if value == "fight":
					w.retreating = false
			"call_help":
				w.call_help = value
			"answer":
				if w.is_emplacement() or w.wall_guard or w.is_mobile_healer():
					continue   # (a Healer answers by its focus: In danger)
				w.answer = value
		if field != "priority":
			last_orders[w.kind] = {"commit": w.commit, "move_mode": w.move_mode, "guard_area": w.guard_area,
					"danger_mode": w.danger_mode, "call_help": w.call_help, "answer": w.answer}
	if field == "priority" and value == "stay":
		# Healers stay with the troops given the order with them; on their own, they wait
		# for a click on the troop (or right-click one).
		var healers := units.filter(func(w): return w.is_mobile_healer())
		var others := units.filter(func(w): return not w.is_mobile_healer() and w.kind != "barricade")
		if healers.is_empty():
			return
		if others.is_empty():
			ward_pick = healers
			hud.show_message("Click the troop for the Healer to stay with (Esc: cancel)")
		else:
			stay_with(healers, others)


## A troop in danger calls for help (renewed each frame it's still in danger; a call
## lingers a moment after). Others answer by their orders (Warrior._update_answer).
func call_for_help(w) -> void:
	if not help_calls.has(w):
		spawn_text(w.position + Vector2(0, -52), "Help!", Color(1.0, 0.45, 0.35))
	help_calls[w] = CALL_LINGER


## Whether `w` is calling for help.
func calling(w) -> bool:
	return help_calls.has(w)


## Everyone calling for help right now.
func callers() -> Array:
	return help_calls.keys()


func _update_calls(delta: float) -> void:
	for w in help_calls.keys():
		help_calls[w] -= delta
		if help_calls[w] <= 0.0 or not is_instance_valid(w) or w.is_queued_for_deletion() or not w.is_active():
			help_calls.erase(w)


## D (or the orders panel): the next drag on the field draws a Guard Area for the selected
## troop or the group (any size, anywhere); Esc cancels.
func start_area_pick(units: Array = []) -> void:
	if units.is_empty():
		units = order_units()
	units = units.filter(func(w): return not w.is_emplacement() and not w.wall_guard and w.kind != "barricade")
	if units.is_empty():
		return
	area_pick = units
	area_start = null
	hud.show_message("Drag out an area to guard (Esc: cancel)")


## Ready-made Guard Areas, as shares of the ground troops stand on (across the field, and
## from the top of it down to the castle): the front half, either flank (with a little of
## the middle), the middle (overlapping both flanks a little) and the back half.
const AREA_PRESETS := {
	"front": Rect2(0.0, 0.0, 1.0, 0.5),
	"left": Rect2(0.0, 0.0, 0.45, 1.0),
	"center": Rect2(0.28, 0.0, 0.44, 1.0),
	"right": Rect2(0.55, 0.0, 0.45, 1.0),
	"back": Rect2(0.0, 0.5, 1.0, 0.5),
}
const AREA_PRESET_NAMES := {"front": "Front", "left": "Left flank", "center": "Centre", "right": "Right flank", "back": "Back"}


## A ready-made Guard Area (see AREA_PRESETS) on this battlefield.
func area_preset(key: String) -> Rect2:
	var k: Rect2 = AREA_PRESETS[key]
	var top := float(DEPLOY_TOP)
	var depth := float(CASTLE_Y) - top
	return Rect2(k.position.x * FIELD_W, top + k.position.y * depth, k.size.x * FIELD_W, k.size.y * depth)


## The preset `r` matches, or "" (one drawn by hand).
func area_preset_of(r: Rect2) -> String:
	for key in AREA_PRESETS:
		if area_preset(key).is_equal_approx(r):
			return key
	return ""


## The area being drawn, in field coordinates (while the button's held).
func area_box() -> Rect2:
	if area_start == null:
		return Rect2()
	var a: Vector2 = area_start
	var b := Vector2(clampf(mouse.x, 0.0, FIELD_W), clampf(mouse.y, 0.0, FIELD_H))
	return Rect2(a.min(b), (b - a).abs())


func _finish_area() -> void:
	var r := area_box()
	area_start = null
	if r.size.x < Warrior.MIN_AREA and r.size.y < Warrior.MIN_AREA:
		return   # a click, not a drag: still waiting for the area
	var units := area_pick.filter(func(w): return is_instance_valid(w))
	area_pick = []
	give_order("area", r, units)
	if not units.is_empty():
		spawn_text(r.get_center(), "Guarding here", Color(0.7, 0.95, 1.0))
	hud.refresh(self)


## `healers` keep with `troops` (a troop, or a group) and look after them first.
func stay_with(healers: Array, troops: Array) -> void:
	ward_pick = []
	for h in healers:
		h.stay_with(troops)
	if not healers.is_empty() and not troops.is_empty():
		spawn_text(healers[0].position + Vector2(0, -50), "Staying with the %s" % (troops[0].label.to_lower() if troops.size() == 1 else "group"), Color(0.6, 1.0, 0.6))


## M: the next movement mode for the selection (Hold, Guard Area, Free Roam).
func cycle_move_mode() -> void:
	var units := order_units().filter(func(w): return not w.is_emplacement() and not w.wall_guard)
	if units.is_empty():
		return
	var modes := Warrior.MOVE_MODES
	var next: String = modes[(modes.find(units[0].move_mode) + 1) % modes.size()]
	give_order("move_mode", next, units)
	spawn_text(units[0].position + Vector2(0, -50), Warrior.MOVE_NAMES[next], Color(0.7, 0.95, 1.0))


## Tells `units` to follow objective `o` (a wagon, civilians), each keeping its place
## around it (spread round it if they were all bunched up); null: back to a fixed post.
func set_follow(o, units: Array = []) -> void:
	if units.is_empty():
		units = order_units().filter(func(w): return not w.is_emplacement() and not w.wall_guard)
	var i := 0
	for w in units:
		if o == null:
			w.anchor = null
			continue
		var off: Vector2 = w.post - o.position
		if off.length() > 140.0 or off.length() < 30.0:
			off = Vector2.from_angle(PI * 0.15 + i * TAU / maxf(units.size(), 1.0)) * 60.0   # ring round it
		w.anchor = o
		w.anchor_off = off
		w.anchor_check = 0.0
		i += 1
	if not units.is_empty():
		spawn_text(units[0].position + Vector2(0, -50), ("Following the " + o.label.to_lower()) if o != null else "Holding a post", Color(0.7, 0.95, 1.0))


## J: follow the nearest thing that can be followed, or stop following.
func toggle_follow() -> void:
	var units := order_units().filter(func(w): return not w.is_emplacement() and not w.wall_guard)
	if units.is_empty():
		return
	if units[0].anchor != null:
		set_follow(null, units)
		return
	var best = null
	for o in rules.followable():
		if best == null or o.position.distance_to(units[0].position) < best.position.distance_to(units[0].position):
			best = o
	if best == null:
		hud.show_message("There's nothing here to follow")
		return
	set_follow(best, units)


## N: Focused or Reactive for the selection.
func toggle_commit() -> void:
	var units := order_units().filter(func(w): return w.uses_targeting())
	if units.is_empty():
		return
	var next := "reactive" if units[0].commit == "focused" else "focused"
	give_order("commit", next, units)
	spawn_text(units[0].position + Vector2(0, -50), Warrior.COMMIT_NAMES[next], Color(1, 1, 0.6))


func sell_selected() -> void:
	if selected == null:
		return
	if selected.summoned:
		hud.show_message("Skeletons can't be sold")
		return
	gold += selected.sell_value()
	sfx("sell")
	selected.queue_free()
	warriors_changed()
	if selected is Barricade:
		walls_changed()
	selected = null


## Shows a hire tab, letting go of any selected unit so the hire buttons are visible.
func switch_tab(tab: String) -> void:
	if dragging != null:
		_end_drag()
	selected = null
	group.clear()
	if placing_type != "" and hud.tab_of(placing_type) != tab:
		placing_type = ""   # the hire being placed isn't on the new tab
		wall_start = null
	hud.show_tab(tab)


func _cancel() -> void:
	powers.aiming = ""
	ward_pick = []
	area_pick = []
	area_start = null
	group.clear()
	box_start = null
	castle_selected = false
	placing_type = ""
	wall_start = null
	selected = null
	selected_grave = null


func _warrior_at(p: Vector2) -> Warrior:
	var best: Warrior = null
	var best_d := Warrior.RADIUS + 6.0
	for w in get_warriors():
		if w.summoned:
			continue   # skeletons can't be picked up, moved or sold
		var d: float = w.position.distance_to(p)
		if d < best_d:
			best_d = d
			best = w
	if best == null:
		# Walls are picked anywhere along their length (they're drawn standing up from the line).
		best_d = 14.0
		for b in get_barricades():
			var d: float = b.gap_from(p + Vector2(0, 8))
			if d < best_d:
				best_d = d
				best = b
	return best


# --- Input ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if game_over or not started or hud.story != null:
		return
	if event is InputEventMouseButton and event.pressed:
		var p := get_local_mouse_position()
		if p.y > FIELD_H or p.y < 0.0 or p.x < 0.0 or p.x > FIELD_W:
			return   # off the field (the panel, or the scenery around a full screen)
		if powers.aiming != "":
			if event.button_index == MOUSE_BUTTON_LEFT:
				powers.aim_click(p)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				powers.aiming = ""
			return
		if not area_pick.is_empty():
			# Drawing a Guard Area: left-drag it out; right-click cancels.
			if event.button_index == MOUSE_BUTTON_LEFT:
				area_start = p
			else:
				area_pick = []
				area_start = null
			return
		if not ward_pick.is_empty():
			# Healers waiting to be told who to stay with: that troop (anything else cancels).
			var ward := _warrior_at(p)
			var healers := ward_pick.filter(func(h): return is_instance_valid(h))
			ward_pick = []
			if ward != null and not healers.has(ward) and ward.kind != "barricade":
				stay_with(healers, [ward])
			else:
				hud.show_message("No troop there: the Healer keeps to what it was doing")
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			# Healers alone, right-clicking one of your troops: stay with it.
			var sel := order_units()
			var ally := _warrior_at(p)
			if ally != null and not sel.is_empty() and not sel.has(ally) and ally.kind != "barricade" \
					and sel.all(func(w): return w.is_mobile_healer()):
				stay_with(sel, [ally])
				return
			var mover = null
			for o in rules.followable():
				if o.position.distance_to(p) < o.RADIUS + 10.0:
					mover = o
			if mover != null and (not group.is_empty() or selected != null):
				set_follow(mover)   # right-click a wagon (or civilians): follow it
			elif not group.is_empty():
				order_group(p)
			elif selected != null:
				order_move(p)
			else:
				_cancel()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if placing_type != "":
				hire_at(p)
				return
			var w := _warrior_at(p)
			if event.shift_pressed and w != null and _groupable(w):
				_toggle_in_group(w)   # Shift+click: add or remove one troop
				return
			if w != null and group.has(w) and not wave_active:
				_start_group_drag()   # drag the whole group between waves
				return
			if w == null and not on_castle(p) and _grave_at(p) == null:
				# Open field: a click clears the selection, a drag draws a selection box.
				box_start = p
				box_active = false
				box_add = event.shift_pressed
				return
			group.clear()
			if w != null and w != selected and not w is Barricade and w.lift <= 0.0:
				w.land_t = Warrior.LAND_TIME * 0.6   # picked out: a little springy "yes?"
			selected = w
			selected_grave = _grave_at(p) if selected == null else null
			castle_selected = selected == null and selected_grave == null and on_castle(p)
			if selected != null and not wave_active:
				_start_drag(selected)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if area_start != null:
			_finish_area()
		elif box_start != null:
			_finish_box()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				# Number keys pick from whichever hire tab is showing.
				var i: int = event.keycode - KEY_1
				if castle_selected and selected == null:
					if i < Data.CASTLE_PATHS.size():
						castle_upgrade(i)
					return
				match hud.hire_tab:
					"abilities":
						if i < Data.ABILITIES.size():
							ability_item(Data.ABILITIES.keys()[i])
						return
					"repair":
						if i < Data.REPAIR_CHUNKS.size():
							repair_castle(i)
						return
				var kinds: Array = hud.tab_kinds(hud.hire_tab)
				if i < kinds.size():
					_on_hire_pressed(kinds[i])
			KEY_TAB:
				var order: Array = hud.TABS.map(func(t): return t[0])
				switch_tab(order[(order.find(hud.hire_tab) + 1) % order.size()])
			KEY_C:
				select_castle()
			KEY_A:
				if event.ctrl_pressed or event.meta_pressed:
					select_all_troops()
				else:
					toggle_auto()
			KEY_V:
				switch_tab("abilities")
			KEY_B:
				switch_tab("repair")
			KEY_Z:
				switch_tab("troops")
			KEY_X:
				switch_tab("emplacements")
			KEY_SPACE:
				start_wave()
			KEY_Q:
				upgrade_selected(0)
			KEY_W:
				upgrade_selected(1)
			KEY_E:
				upgrade_selected(2)
			KEY_R:
				upgrade_selected(3)
			KEY_S:
				sell_selected()
			KEY_T:
				cycle_target_priority()
			KEY_M:
				cycle_move_mode()
			KEY_Y:
				if rules.action_label() != "":
					rules.action()
			KEY_J:
				toggle_follow()
			KEY_N:
				toggle_commit()
			KEY_O:
				hud.toggle_orders(self)
			KEY_G:
				toggle_song()
			KEY_D:
				start_area_pick()
			KEY_F:
				cycle_speed()
			KEY_ESCAPE:
				_cancel()


# --- Effects -------------------------------------------------------------

func add_projectile(p: Node2D) -> void:
	fx_layer.add_child(p)


func spawn_text(pos: Vector2, text: String, color: Color) -> void:
	var f := Fx.new()
	f.mode = "text"
	f.text = text
	f.color = color
	f.position = pos
	fx_layer.add_child(f)


## Motes of light rising round a troop that's just been upgraded, in its path's colour.
func spawn_sparkle(pos: Vector2, color: Color) -> void:
	var f := Fx.new()
	f.mode = "sparkle"
	f.color = color
	f.radius = 18.0
	f.life = 0.8
	f.position = pos
	fx_layer.add_child(f)


## A slain enemy topples over and fades, with a puff of dust where it falls.
func spawn_corpse(e) -> void:
	if corpse_layer.get_child_count() > 40:   # (a huge wave dying at once: the rest just vanish)
		return
	var f := Fx.new()
	f.mode = "fall"
	f.tex = Sprites.frames(e.kind)[0]
	f.radius = e.radius
	f.size = Vector2(Sprites.SIZE, Sprites.SIZE) * e.sprite_scale
	f.flip = e.flip
	f.height = 18.0 if e.flying else 0.0   # (enemy.gd FLY_HEIGHT)
	f.life = 0.55
	f.position = e.position
	corpse_layer.add_child(f)


func spawn_bolt(path: PackedVector2Array, color: Color) -> void:
	# Jag each segment so it reads as lightning.
	var pts := PackedVector2Array([path[0]])
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var side := (b - a).orthogonal().normalized()
		for j in range(1, 4):
			pts.append(a.lerp(b, j / 4.0) + side * randf_range(-7, 7))
		pts.append(b)
	var f := Fx.new()
	f.mode = "bolt"
	f.points = pts
	f.color = color
	f.life = 0.25
	fx_layer.add_child(f)


func spawn_flame(from: Vector2, to: Vector2) -> void:
	var f := Fx.new()
	f.mode = "flame"
	f.points = PackedVector2Array([from, to])
	f.life = 0.2
	fx_layer.add_child(f)


func spawn_flash(pos: Vector2, radius: float) -> void:
	var f := Fx.new()
	f.mode = "flash"
	f.radius = radius
	f.life = 0.4
	f.position = pos
	fx_layer.add_child(f)


func spawn_beam(from: Vector2, to: Vector2, color: Color, width := 30.0) -> void:
	var f := Fx.new()
	f.mode = "beam"
	f.points = PackedVector2Array([from, to])
	f.color = color
	f.radius = width
	f.life = 0.35
	fx_layer.add_child(f)


func spawn_tornado(pos: Vector2, radius: float) -> void:
	var f := Fx.new()
	f.mode = "tornado"
	f.radius = radius
	f.life = 0.8
	f.position = pos
	fx_layer.add_child(f)


func spawn_note(pos: Vector2, color: Color) -> void:
	var f := Fx.new()
	f.mode = "note"
	f.color = color
	f.life = 0.9
	f.position = pos
	fx_layer.add_child(f)


## Fire Rain landing on a spot.
func spawn_area(mode: String, pos: Vector2, radius: float) -> void:
	var f := Fx.new()
	f.mode = mode
	f.radius = radius
	f.life = 0.5
	f.position = pos
	fx_layer.add_child(f)


## A skeleton raised by Necromancy joins the warriors.
func add_summon(w: Warrior) -> void:
	warrior_layer.add_child(w)


## Whether a Bard is on the field for every instrument (they can play their song).
func all_bards_present() -> bool:
	return audio != null and audio.INSTRUMENTS.all(func(i): return i in bard_instruments)


## The Song button on a Bard's panel: play the eight-Bard song between waves, or don't.
func toggle_song() -> void:
	if selected == null or selected.kind != "bard" or not all_bards_present():
		return
	song_on = not song_on
	hud.show_message("The Bards' song: " + ("on" if song_on else "off"))


## The instruments the Bards on the field are holding (each plays along with the music).
func _bard_instruments() -> Array:
	var found := {}
	for w in get_warriors():
		if w.kind == "bard":
			found[w.instrument_sound()] = true
	return found.keys()


## Gives a new button a soft click when it's pressed (see _ready).
func _click_on_press(node: Node) -> void:
	if node is BaseButton and not node.has_meta("silent"):
		node.pressed.connect(sfx.bind("click"))


## Plays a sound effect (see audio.gd).
func sfx(sound_name: String, pitch := 1.0) -> void:
	if audio != null:
		audio.play(sound_name, pitch)


func spawn_burst(pos: Vector2, radius: float, color: Color) -> void:
	var f := Fx.new()
	f.mode = "burst"
	f.radius = radius
	f.color = color
	f.life = 0.3
	f.position = pos
	fx_layer.add_child(f)


# --- Drawing -------------------------------------------------------------

func _draw() -> void:
	_draw_surroundings()
	_repaint_ground()


## The ground never moves, but it's hundreds of tiles and bits of scenery: drawn
## live, the renderer would resend them all every frame. So it's painted once into
## a texture (at twice the size, to stay crisp on a big screen) and shown as a single
## sprite; it's painted again only when the mode or the field's width changes.
func _repaint_ground() -> void:
	var size := Vector2i(FIELD_W, FIELD_H) * GROUND_OVERSAMPLE
	if ground_vp.size != size:
		ground_vp.size = size
	ground_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	ground_painter.queue_redraw()


## Pixel ground: dirt where enemies enter, grass (with the odd flower patch) below,
## lit for the mode's mood; then the scenery on it (see field_art.gd).
func _paint_ground(ci: CanvasItem) -> void:
	var map: Dictionary = Maps.get_map(map_id)
	FieldArt.paint_field(ci, FIELD_W, FIELD_H, ambience.ground_tint() * map.get("tint", Color.WHITE), map)


## The panel's colour carried on under the field across the whole width (the
## panel's controls stay 640 wide in the middle), and dark dirt above the field
## on a tall screen.
func _draw_surroundings() -> void:
	if margin.y > 0.0:
		draw_rect(Rect2(0, -margin.y, FIELD_W, margin.y), Color(0.2, 0.15, 0.1))
	draw_rect(Rect2(0, FIELD_H, FIELD_W, Hud.HEIGHT - FIELD_H + margin.y), Color(0.13, 0.11, 0.1))
	draw_rect(Rect2(0, FIELD_H, FIELD_W, 3), Color(0.45, 0.35, 0.2))


func _draw_overlay() -> void:
	# The selection box being dragged, and a ring under every troop in the group.
	var zones_drawn := []
	if not area_pick.is_empty():
		var ab := area_box()
		if ab.size != Vector2.ZERO:
			_draw_area(ab, Color(1.0, 0.9, 0.5), 1.6)   # the Guard Area being drawn
			_overlay_text(ab.end + Vector2(6, 2), "%s × %s" % [Data.ft(ab.size.x), Data.ft(ab.size.y)], Color(1.0, 0.92, 0.6))
		else:
			_overlay_text(mouse + Vector2(14, -8), "Drag out the area to guard", Color(1.0, 0.92, 0.6))
	var box := selection_box()
	if box.size != Vector2.ZERO:
		overlay.draw_rect(box, Color(0.6, 0.9, 1.0, 0.12))
		overlay.draw_rect(box, Color(0.7, 0.95, 1.0, 0.85), false, 1.5)
	for w in group:
		var feet: Vector2 = w.position + Vector2(0, Warrior.RADIUS)
		overlay.draw_set_transform(feet, 0, Vector2(1, 0.4))
		overlay.draw_arc(Vector2.ZERO, Warrior.RADIUS + 4.0, 0, TAU, 24, Color(0.7, 0.95, 1.0, 0.9), 2.5, true)
		overlay.draw_set_transform(Vector2.ZERO)
		if w.ordered:
			overlay.draw_line(w.position, w.post, Color(0.7, 0.95, 1.0, 0.3), 1.5, true)
		_draw_zone(w, 0.6, zones_drawn)
	if castle_selected or _castle_hovered():
		# The castle outlined in gold: solid while selected, faint while hovered.
		var col := Color(1.0, 0.85, 0.35, 0.95 if castle_selected else 0.45)
		overlay.draw_rect(Rect2(1, CASTLE_Y, FIELD_W - 2, FIELD_H - CASTLE_Y - 1), col, false, 2.0)
		for r in castle._towers():
			overlay.draw_rect(r.grow(1.0), col, false, 2.0)
	if placing_type == "barricade" and mouse.y <= FIELD_H:
		_draw_wall_preview()
	elif placing_type != "" and mouse.y <= FIELD_H:
		var d: Dictionary = Data.WARRIORS[placing_type]
		var ok := can_post_at(mouse)
		var tint := Color(1, 1, 1, 0.6) if ok else Color(1, 0.3, 0.3, 0.6)
		var size := Vector2(Sprites.SIZE, Sprites.SIZE) * Warrior.SCALE
		var top_left := mouse + Vector2(-size.x / 2, Warrior.RADIUS - size.y)
		if Sprites.MOUNT_CREW.has(placing_type):
			# A tower with its troop on top (or a cannon and its Cannoneer), as it'll stand.
			var foot := mouse + Vector2(0, Warrior.RADIUS)
			Sprites.draw_mount(overlay, placing_type, foot, foot, 1.0, Sprites.mount_frames(placing_type, placing_type)[0],
					Sprites.frames(Sprites.MOUNT_CREW[placing_type])[0], tint, 1.0, Warrior.SCALE)
		else:
			overlay.draw_texture_rect(Sprites.frames(placing_type)[0], Rect2(top_left, size), false, tint)
		var reach: float = d["range"] + Warrior.RADIUS
		overlay.draw_circle(mouse, reach, Color(1, 1, 1, 0.08), true, -1.0, true)
		overlay.draw_arc(mouse, reach, 0, TAU, 64, Color(1, 1, 1, 0.5), 2.0, true)
	if is_instance_valid(dragging) and dragging is Barricade:
		if wall_problem(dragging.seg_a(), dragging.seg_b()) != "":
			overlay.draw_line(dragging.seg_a(), dragging.seg_b(), Color(1, 0.25, 0.25, 0.45), 18.0)
	elif dragging != null and is_instance_valid(dragging) and not can_post_at(dragging.post, dragging):
		overlay.draw_circle(dragging.position, Warrior.RADIUS + 6, Color(1, 0.25, 0.25, 0.45), true, -1.0, true)
	if is_instance_valid(selected) and selected is Barricade:
		_draw_wall_selection(selected)
	elif selected != null and is_instance_valid(selected) and selected.data["attack"] in ["aura", "pulse"]:
		# A War Statue or Medic Bay: a thread to every unit it looks after.
		for w in get_warriors():
			if w != selected and selected.covers(w):
				overlay.draw_line(selected.position, w.position, Color(1, 1, 0.6, 0.35), 1.5, true)
				overlay.draw_circle(w.position, 4.0, Color(1, 1, 0.6, 0.7), true, -1.0, true)
	elif selected != null and is_instance_valid(selected):
		var post := selected.post
		var col := Color(1, 1, 0.6)
		_draw_zone(selected, 1.0)
		# Attack range around the warrior, plus a marker for the post it returns to.
		var reach := selected.attack_range + Warrior.RADIUS
		overlay.draw_circle(selected.position, reach, Color(col, 0.1), true, -1.0, true)
		overlay.draw_arc(selected.position, reach, 0, TAU, 64, Color(col, 0.8), 2.0, true)
		if not selected.blast.is_empty():
			# Spirit bolt range, for Martial Artists who have learned it.
			var ki: float = selected.blast["range"] + Warrior.RADIUS
			overlay.draw_arc(selected.position, ki, 0, TAU, 64, Color(Warrior.KI_COLOR, 0.6), 1.5, true)
		if selected.position.distance_to(post) > reach:
			overlay.draw_line(selected.position, post, Color(col, 0.4), 1.5, true)
		overlay.draw_line(post + Vector2(-7, -7), post + Vector2(7, 7), col, 2.5, true)
		overlay.draw_line(post + Vector2(-7, 7), post + Vector2(7, -7), col, 2.5, true)


## A unit's movement zone: the ground around its post it may fight from (a ring at the
## post on Hold). Nothing for units roaming free or that never move.
func _draw_zone(w, strength: float, drawn: Array = []) -> void:
	if not (w is Warrior) or w.move_mode == "free" or w.is_emplacement() or w.wall_guard:
		return
	var col := Color(0.55, 0.85, 1.0)
	if w.move_mode == "hold":
		overlay.draw_arc(w.post, Warrior.RADIUS + 3.0, 0, TAU, 32, Color(col, 0.8 * strength), 2.5, true)
		return
	var r: Rect2 = w.zone_rect()
	if drawn.has(r):
		return   # (a group sharing one area: drawn once)
	drawn.append(r)
	_draw_area(r, col, strength)


## A Guard Area: a pale fill inside a dashed outline.
func _draw_area(r: Rect2, col: Color, strength: float) -> void:
	overlay.draw_rect(r, Color(col, 0.07 * strength))
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var n := maxi(1, int(a.distance_to(b) / 12.0))
		for j in n:
			if j % 2 == 0:
				overlay.draw_line(a.lerp(b, float(j) / n), a.lerp(b, float(j + 1) / n), Color(col, 0.75 * strength), 2.0)


## Placing a barricade: a marker before the first click, then the wall-to-be with
## its length and price.
func _draw_wall_preview() -> void:
	if wall_start == null:
		var p := _clamp_wall_point(mouse)
		overlay.draw_circle(p, 6, Color(1, 1, 1, 0.7), true, -1.0, true)
		_overlay_text(p + Vector2(12, -10), "Click where the wall starts", Color.WHITE)
		return
	var a: Vector2 = wall_start
	var b := wall_end(a, mouse)
	var cost := wall_cost(a, b)
	var problem := wall_problem(a, b)
	var ok := problem == "" and gold >= cost
	var col := Color(1, 1, 1, 0.7) if ok else Color(1, 0.3, 0.3, 0.7)
	overlay.draw_line(a, b, Color(col, 0.25), Barricade.WALL_HALF * 2.0 + 8.0)
	overlay.draw_line(a, b, col, 4.0)
	var n := int(a.distance_to(b) / Barricade.STAKE_GAP)
	for i in n + 1:
		var p := a.lerp(b, i / maxf(n, 1.0))
		overlay.draw_line(p + Vector2(0, 4), p + Vector2(0, -16), col, 3.0)
	overlay.draw_circle(a, 5, col, true, -1.0, true)
	var label := "%s  %dg" % [Data.ft(a.distance_to(b)), cost]
	if problem != "":
		label += "  - " + problem
	elif gold < cost:
		label += "  - not enough gold"
	_overlay_text(b + Vector2(12, -10), label, Color(1, 0.85, 0.3) if ok else Color(1, 0.45, 0.4))


func _overlay_text(p: Vector2, text: String, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	p.x = clampf(p.x, 4.0, FIELD_W - w - 4.0)
	overlay.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color.BLACK)
	overlay.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)


## A selected wall: highlighted along its length, plus the reach of its arrows or spikes.
func _draw_wall_selection(w) -> void:
	var col := Color(1, 1, 0.6)
	overlay.draw_line(w.seg_a(), w.seg_b(), Color(col, 0.25), Barricade.WALL_HALF * 2.0 + 10.0)
	var reach: float = maxf(w.attack_range, w.wall_slow[1] if not w.wall_slow.is_empty() else 0.0)
	if reach <= 0.0:
		return
	reach += Barricade.WALL_HALF
	var a: Vector2 = w.seg_a()
	var b: Vector2 = w.seg_b()
	var n: Vector2 = (b - a).normalized().orthogonal() * reach
	var ang := n.angle()
	overlay.draw_line(a + n, b + n, Color(col, 0.6), 2.0, true)
	overlay.draw_line(a - n, b - n, Color(col, 0.6), 2.0, true)
	overlay.draw_arc(a, reach, ang, ang + PI, 24, Color(col, 0.6), 2.0, true)
	overlay.draw_arc(b, reach, ang + PI, ang + TAU, 24, Color(col, 0.6), 2.0, true)
