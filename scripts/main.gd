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
var classic_map := ""      # Classic on one of the campaign's battlefields ("" = the open meadow)
var map_id := ""           # the battlefield this game is on (a maps.gd id, "" for the meadow)
var stage_music := "calm"   # this battlefield's peaceful music between waves (audio.gd STAGE_TRACKS)
var credit := ""             # campaign XP: the unit kind whose doing the damage dealt right now is
var battle_xp := {}          # campaign XP earned this battle: unit kind -> XP
const CD_XP_RATES = preload("res://scripts/campaign_data.gd").XP_RATES    # a story campaign battle (the Campaign autoload says which mission)
var mission := {}        # that mission's data (campaign_data.gd MISSIONS); empty outside the campaign
var temp_allies := []    # units the mission put on the field from the start
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
var choosing := false    # the "keep going?" screen is up after the final wave
var records_path := "user://records.cfg"   # best number of waves survived, per mode ("" = don't keep)

var spawn_queue: Array = []   # [enemy kind, wave level] pairs waiting to enter
var boss_spawned := false     # this wave's boss has come out
var spawn_timer := 0.0
var spawn_interval := 0.8

var placing_type := ""
var castle_selected := false
var repair_job := {}           # a repair the Engineers are working on: {"left": health still to come, "rate": per second}   # the castle was clicked: the panel shows its upgrades
var auto_play := false         # start each wave by itself after the last one's cleared
var auto_timer := 0.0          # seconds until auto-play starts the next wave
const AUTO_DELAY := 3.0
var wall_start = null     # first click while placing a barricade (Vector2), or null
var last_priority := {}   # unit kind -> target priority new hires start with
var last_orders := {}     # unit kind -> {commit, move_mode, leash} new hires start with (the last given to that kind)
var selected: Warrior = null
var group := []             # several troops selected together (box or Shift+click); `selected` is null then
var box_start = null        # where a left-drag on open field started (Vector2), while the button's held
var box_active := false     # it's been dragged far enough to be a selection box
var box_add := false        # Shift was held: the box adds to the group
var group_drag := false     # dragging the whole group to new posts (between waves)
var group_from := {}        # warrior -> its post when the group drag started
var mouse := Vector2.ZERO
var dragging: Warrior = null     # unit being repositioned between waves
var drag_origin := Vector2.ZERO
var drag_offset := Vector2.ZERO

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
	for layer in [grave_layer, wall_layer, warrior_layer, castle, castle.top_part, enemy_layer, powers, fx_layer, ambience, overlay]:
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
	hud.menu_confirmed.connect(func(): back_to_map() if campaign else _restart())
	hud.campaign_retry.connect(retry_mission)
	hud.campaign_map.connect(back_to_map)
	hud.endless_chosen.connect(continue_endless)
	hud.finish_chosen.connect(func(): _finish(true))
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
			if w.is_emplacement():
				w.position = w.post
			else:
				w.position.x *= k
				w.route = PackedVector2Array()
		if objective_layer != null:
			for o in objective_layer.get_children():
				o.position.x *= k   # objectives keep their place across the field, like the map
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
	campaign = mode == "campaign"
	mission = Campaign.mission() if campaign else (Scenarios.get_scenario(battle_id) if battle_id != "" else {})
	rules = MissionRules.make(mission)
	rules.setup(self, mission)
	_show_castle(rules.has_castle())
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
	if tutorial:
		var guide := Tutorial.new()
		guide.main = self
		guide.hud = hud
		hud.add_child(guide)


func _process(delta: float) -> void:
	mouse = get_local_mouse_position()
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
		elif auto_play and started and not wave_active and not choosing:
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
		audio.set_track("battle" if wave_active else ("ensemble" if ensemble else stage_music))
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

func start_wave() -> void:
	if freeplay:
		spawn_freeplay_wave()
		return
	if wave_active or game_over or not started or choosing:
		return
	if dragging != null:
		_end_drag()
	wave += 1
	sfx("horn")
	wave_active = true
	boss_spawned = false
	gates_warned = false
	var level := wave_level(wave)
	spawn_queue = _build_wave(wave).map(func(k): return [k, level])
	spawn_interval = maxf(0.35, 0.9 - level * 0.03)
	spawn_timer = 0.0
	if scripted():
		hud.show_message(mission.get("notes", {}).get(wave, "Wave %d of %d" % [wave, last_wave()]))
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
const FOE_HINTS := {
	"skeleton_archer": "Skeleton Archers! They hang back and shoot: rush them down.",
	"slime": "Slimes! Blades and arrows can't hurt them. Use magic, ki or ice (ice lets steel bite).",
}
var _foes_seen := {}


func _spawn_enemy(kind: String, level: int, at = null) -> void:
	if FOE_HINTS.has(kind) and not _foes_seen.has(kind):
		_foes_seen[kind] = true
		hud.show_message(FOE_HINTS[kind])
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
		hud.show_message("The Ogre King approaches!")


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
	elif not on and camp == null:
		camp = Camp.new()
		camp.main = self
		add_child(camp)
		move_child(camp, castle.get_index())


## Puts a mission objective on the field (under the troops, over the ground).
func add_objective(o: Node2D) -> void:
	if objective_layer == null:
		objective_layer = Node2D.new()
		add_child(objective_layer)
		move_child(objective_layer, wall_layer.get_index())
	objective_layer.add_child(o)


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
	auto_play = not auto_play
	auto_timer = AUTO_DELAY
	hud.show_message("Auto-play on" if auto_play else "Auto-play off")


func _end_wave() -> void:
	auto_timer = AUTO_DELAY
	wave_active = false
	sfx("fanfare")
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
	if wave == Data.FINAL_WAVE and not endless:
		choosing = true
		Engine.time_scale = 1.0
		_cancel()
		hud.show_victory_choice(wave)
	else:
		hud.show_message("Wave %d cleared! +%d gold" % [wave, bonus])


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
## ("campaign:continue", "campaign:new:<difficulty>").
func _on_mode_chosen(key: String) -> void:
	if key == "campaign:continue":
		if Campaign.load_game():
			open_world_map()
		else:
			hud.show_mode_select()
			hud.show_message(Campaign.load_error if Campaign.load_error != "" else "No campaign saved yet")
	elif key.begins_with("campaign:new:"):
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
		var kind: String = a["kind"]
		var w := Warrior.new()
		var at: Vector2 = a["at"]
		w.setup(kind, Data.WARRIORS[kind], self, Vector2(at.x * FIELD_W / Maps.BASE_W, at.y))   # placed on the map as stretched
		w.spent = 0   # on loan: selling it brings nothing
		w.position = w.post
		warrior_layer.add_child(w)
		temp_allies.append(w)
	var intro: String = mission.get("intro", "")
	if intro != "" and not Campaign.seen.has(intro):
		Campaign.mark_seen(intro)
		hud.play_story(Campaign.story_lines(intro))


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
	return list


## Enemy strength on wave n (Classic: the wave number; a mission starts at its level).
func wave_level(n: int) -> int:
	return int(mission["level"]) + n - 1 if scripted() else n


## The wave that ends the game (or, in Classic, offers endless).
func last_wave() -> int:
	return int(mission["waves"]) if scripted() else Data.FINAL_WAVE


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
	return not campaign or Campaign.allows(key, mission.get("lend", []))


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
	return "" if allowed(key) else Campaign.lock_reason(key, mission.get("lend", []))


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


## After the final wave: carry on with ever-stronger waves.
func continue_endless() -> void:
	endless = true
	choosing = false
	hud.show_message("Endless: enemies grow stronger faster, and bounties shrink")


func _finish(won: bool) -> void:
	audio.set_track("")
	sfx("victory" if won else "defeat")
	choosing = false
	game_over = true
	victory = won
	wave_active = false
	Engine.time_scale = 1.0
	_cancel()
	enemy_layer.process_mode = Node.PROCESS_MODE_DISABLED
	warrior_layer.process_mode = Node.PROCESS_MODE_DISABLED
	wall_layer.process_mode = Node.PROCESS_MODE_DISABLED
	var survived := wave if won else wave - 1
	if campaign:
		Campaign.finish_mission(won, _mission_flags() if won else [], battle_xp)
		hud.show_campaign_end(won, mission, survived, rules.summary(won) if rules.has_method("summary") else "")
		return
	if battle_id != "":
		_finish_battle_mode(won)
		return
	var previous := _save_record(survived)
	hud.show_end(won, survived, previous, endless)


## A Battle Modes scenario over: its result, its best (kept per scenario and
## difficulty, for wins), and the way to play it again.
func _finish_battle_mode(won: bool) -> void:
	var key := "%s@%s" % [battle_id, difficulty]
	var score: int = rules.score() if won else -1
	var best := -1
	if records_path != "":
		var cfg := ConfigFile.new()
		cfg.load(records_path)
		best = cfg.get_value("battle", key, -1)
		if score > best:
			cfg.set_value("battle", key, score)
			cfg.save(records_path)
	var record := ""
	if won:
		record = "New best!" if score > best else "Best: " + rules.score_text(best)
	elif best >= 0:
		record = "Best: " + rules.score_text(best)
	hud.show_battle_end(won, mission["name"], rules.summary(won), record, "battle:%s:%s" % [battle_id, difficulty])


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
		if not o.dead and p.distance_to(o.position) < o.RADIUS + Warrior.RADIUS:
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
		if not o.dead and Geometry2D.get_closest_point_to_segment(o.position, a, b).distance_to(o.position) < o.RADIUS + Barricade.WALL_HALF:
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
	var w := Warrior.new()
	w.setup(placing_type, data, self, _clamp_post(p))
	w.spent = cost
	w.priority = last_priority.get(placing_type, "closest")
	if last_orders.has(placing_type):
		var o: Dictionary = last_orders[placing_type]
		w.commit = o["commit"]
		w.move_mode = o["move_mode"]
		w.leash = o["leash"].duplicate()
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
			var p := _clamp_post(group_from[w] + shift)
			w.post = p
			w.position = p


## Drops the dragged group; any that landed somewhere they can't stand go back.
func _end_group_drag() -> void:
	group_drag = false
	var taken := []
	for w in group_from:
		if not is_instance_valid(w):
			continue
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
		w.set_post(p)
		w.position = p
	group_from.clear()


func order_move(p: Vector2) -> void:
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
	sfx("upgrade")
	spawn_text(selected.position + Vector2(0, -50), tier_name, Warrior.PATH_COLORS[path])
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


func _end_drag() -> void:
	var w := dragging
	dragging = null
	if not is_instance_valid(w):
		return
	var ok := can_post_at(w.post, w)
	if w is Barricade:
		ok = wall_problem(w.seg_a(), w.seg_b()) == ""
	var p := w.post if ok else drag_origin
	w.set_post(p)
	w.position = p
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
	last_priority[selected.kind] = selected.priority
	spawn_text(selected.position + Vector2(0, -50), "Target: " + Warrior.PRIORITY_NAMES[selected.priority], Color(1, 1, 0.6))


# --- Orders: priority, commitment, movement zone ----------------------------------------

## The units an order goes to: the selected unit, or every troop in the group. (Barricades
## take no orders.)
func order_units() -> Array:
	var out := group.duplicate() if selected == null else [selected]
	return out.filter(func(w): return is_instance_valid(w) and w is Warrior)


## Gives `units` an order: "priority", "commit", "move_mode" or "leash" (a size for the
## current zone mode). Emplacements, wall guards and Healers skip what doesn't apply to
## them. Remembered per kind for the next hire; kept through waves and upgrades.
func give_order(field: String, value, units: Array = []) -> void:
	if units.is_empty():
		units = order_units()
	for w in units:
		match field:
			"priority":
				if not w.uses_targeting():
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
			"leash":
				w.set_leash(value)
		if field != "priority":
			last_orders[w.kind] = {"commit": w.commit, "move_mode": w.move_mode, "leash": w.leash.duplicate()}


## M: the next movement mode for the selection (Hold, Short Leash, Guard Area, Free Roam).
func cycle_move_mode() -> void:
	var units := order_units().filter(func(w): return not w.is_emplacement() and not w.wall_guard)
	if units.is_empty():
		return
	var modes := Warrior.MOVE_MODES
	var next: String = modes[(modes.find(units[0].move_mode) + 1) % modes.size()]
	give_order("move_mode", next, units)
	spawn_text(units[0].position + Vector2(0, -50), Warrior.MOVE_NAMES[next], Color(0.7, 0.95, 1.0))


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
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if not group.is_empty():
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
			selected = w
			selected_grave = _grave_at(p) if selected == null else null
			castle_selected = selected == null and selected_grave == null and on_castle(p)
			if selected != null and not wave_active:
				_start_drag(selected)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if box_start != null:
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
			KEY_N:
				toggle_commit()
			KEY_O:
				hud.toggle_orders(self)
			KEY_G:
				toggle_song()
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
	FieldArt.paint_field(ci, FIELD_W, FIELD_H, ambience.ground_tint(), Maps.get_map(map_id))


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
		_draw_zone(w, 0.5)
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
			# Ki blast range, for Martial Artists who have learned it.
			var ki: float = selected.blast["range"] + Warrior.RADIUS
			overlay.draw_arc(selected.position, ki, 0, TAU, 64, Color(Warrior.KI_COLOR, 0.6), 1.5, true)
		if selected.position.distance_to(post) > reach:
			overlay.draw_line(selected.position, post, Color(col, 0.4), 1.5, true)
		overlay.draw_line(post + Vector2(-7, -7), post + Vector2(7, 7), col, 2.5, true)
		overlay.draw_line(post + Vector2(-7, 7), post + Vector2(7, -7), col, 2.5, true)


## A unit's movement zone: the ground around its post it may fight from (a ring at the
## post on Hold). Nothing for units roaming free or that never move.
func _draw_zone(w, strength: float) -> void:
	if not (w is Warrior) or not w.zoned():
		return
	var col := Color(0.55, 0.85, 1.0)
	var r: float = w.zone_radius()
	if r <= 0.0:
		overlay.draw_arc(w.post, Warrior.RADIUS + 3.0, 0, TAU, 32, Color(col, 0.8 * strength), 2.5, true)
		return
	overlay.draw_circle(w.post, r, Color(col, 0.07 * strength), true, -1.0, true)
	var n := 48
	for i in n:
		if i % 2 == 0:
			overlay.draw_arc(w.post, r, i * TAU / n, (i + 1) * TAU / n, 4, Color(col, 0.75 * strength), 2.0, true)


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
