extends RefCounted
## Setting up: building the scene (layers, HUD, signals), sizing the window, and starting a
## battle in a chosen mode.
## Part of the game controller: `main` is main.gd, which holds the battle's shared state.

const Main = preload("res://scripts/main.gd")
const Data = preload("res://scripts/data/data.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const Audio = preload("res://scripts/audio/audio.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")
const Maps = preload("res://scripts/campaign/maps.gd")
const MissionRules = preload("res://scripts/mission/rules.gd")
const Scenarios = preload("res://scripts/mission/scenarios.gd")

var main: Main

var ground_sprite := Sprite2D.new()


func _init(m: Main) -> void:
	main = m


func build() -> void:
	Engine.time_scale = 1.0
	main.rules = MissionRules.make({})   # castle defense until a mode is chosen
	main.rules.setup(main, {})
	_size_window()
	main.audio = Audio.new()
	main.add_child(main.audio)
	main.get_tree().node_added.connect(main.effects._click_on_press)   # every button, menus and HUD alike, ticks when pressed
	for b in main.find_children("*", "BaseButton", true, false):
		main.effects._click_on_press(b)
	main.paths.setup(main)
	main.castle.main = main
	# The castle goes over the warriors (it hides any standing behind it, showing their
	# silhouettes) but under the enemies, effects and overlay.
	if main.missions.on_phone():
		# A phone's screen has three pixels to every one the game is drawn in: the game is
		# drawn at its own size and the whole picture scaled up once (pixel art and the
		# pixel font stay sharp), far less work for a phone's graphics than drawing at full
		# resolution; the ground is painted at its own size too, and the scenery's moving
		# bits are fewer.
		main.get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		main.GROUND_OVERSAMPLE = 1
	main.ambience.main = main
	main.ambience.setup("normal")
	main.powers.main = main
	main.ground_vp.disable_3d = true
	main.ground_vp.transparent_bg = false
	main.ground_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	main.ground_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	main.ground_painter.scale = Vector2.ONE * main.GROUND_OVERSAMPLE   # painted at twice the size
	main.ground_vp.add_child(main.ground_painter)
	main.ground_painter.draw.connect(func(): main.drawing._paint_ground(main.ground_painter))
	main.add_child(main.ground_vp)
	ground_sprite.centered = false
	ground_sprite.texture = main.ground_vp.get_texture()
	ground_sprite.scale = Vector2.ONE / main.GROUND_OVERSAMPLE
	ground_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # smooth when shown smaller than painted
	main.add_child(ground_sprite)
	main.castle.top_part.castle = main.castle
	main.add_child(main.contracts)
	for layer in [main.hazards, main.conduits, main.grave_layer, main.corpse_layer, main.wall_layer, main.warrior_layer, main.bells, main.castle, main.castle.top_part, main.enemy_layer, main.night, main.powers, main.fx_layer, main.ambience, main.overlay]:
		main.add_child(layer)
	main.overlay.draw.connect(main.drawing._draw_overlay)
	for sig in [main.enemy_layer.child_entered_tree, main.enemy_layer.child_exiting_tree]:
		sig.connect(func(_n): main.battlefield.enemies_changed())
	for sig in [main.warrior_layer.child_entered_tree, main.warrior_layer.child_exiting_tree]:
		sig.connect(func(_n): main.battlefield.warriors_changed())
	main.hud = Hud.new()
	main.hud.process_mode = Node.PROCESS_MODE_ALWAYS   # stays clickable while the game is paused
	main.add_child(main.hud)
	main.hud.hire_pressed.connect(main.hiring._on_hire_pressed)
	main.hud.start_wave_pressed.connect(main.waves.start_wave)
	main.hud.upgrade_pressed.connect(main.groups.upgrade_selected)
	main.hud.sell_pressed.connect(main.formation_ctl.sell_selected)   # (Sell, Sell all or Rebuy: see sell_selected)
	main.hud.sell_all_confirmed.connect(main.formation_ctl.sell_group)
	main.hud.count_pressed.connect(main.hiring.cycle_hire_count)
	main.hud.target_pressed.connect(main.groups.cycle_target_priority)
	main.hud.orders_pressed.connect(func(): main.hud.toggle_orders(main))
	main.hud.song_pressed.connect(main.effects.toggle_song)
	main.hud.climb_pressed.connect(main.hiring.climb_down)
	main.hud.speed_pressed.connect(main.modes.cycle_speed)
	main.hud.auto_pressed.connect(main.castle_ctl.toggle_auto)
	main.hud.restart_pressed.connect(main.modes._restart)
	main.hud.battle_again.connect(main.modes.play_again)
	main.hud.action_pressed.connect(func(): main.rules.action())
	main.hud.contract_pressed.connect(func(): main.contracts.sign())
	main.hud.merc_pressed.connect(func(): main.contracts.hire())
	main.hud.menu_confirmed.connect(func():
		if main.waves.survival() and main.started and not main.game_over:
			main.modes._keep_survival_record(main.waves.waves_survived())   # a run left early still counts
		main.missions.back_to_map() if main.campaign else main.modes._restart())
	main.hud.campaign_retry.connect(main.missions.retry_mission)
	main.hud.campaign_map.connect(main.missions.back_to_map)
	main.hud.mode_chosen.connect(main.missions._on_mode_chosen)
	main.hud.freeplay_level_changed.connect(main.modes.change_freeplay_level)
	main.hud.freeplay_spawn_pressed.connect(main.modes.spawn_single)
	main.hud.freeplay_clear_pressed.connect(main.modes.clear_enemies)
	main.hud.castle_pressed.connect(main.castle_ctl.castle_upgrade)
	main.hud.ability_pressed.connect(main.castle_ctl.ability_item)
	main.hud.repair_pressed.connect(main.castle_ctl.repair_castle)
	main.hud.power_pressed.connect(func(k): main.powers.trigger(k))
	main.hud.group_kind_pressed.connect(func(k): main.groups.filter_group(k, Input.is_key_pressed(KEY_SHIFT)))
	main.get_viewport().size_changed.connect(_fit_screen)
	_fit_screen()
	main.missions._open_start_screen()


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
	var view := main.get_viewport().get_visible_rect().size
	var new_w := maxi(int(Hud.WIDTH), int(view.x))
	# A phone held upright (a tall, narrow screen): the field at the top and the panel,
	# drawn larger, filling everything under it. Elsewhere a tall screen centres the game.
	var phone := view.y / maxf(view.x, 1.0) >= 1.8
	main.missions._turn_upright(view)
	main.margin = Vector2.ZERO if phone else Vector2(0, maxf(0.0, floorf((view.y - Hud.HEIGHT) / 2.0)))
	main.position = main.margin
	main.hud.offset = main.margin
	main.hud.touch = main.missions.on_phone()   # (a phone held so it gets the desktop layout still has no mouse or keys)
	main.hud.layout(new_w, view.y if phone else Hud.HEIGHT, phone)
	if new_w != main.FIELD_W:
		var old_w := main.FIELD_W
		var k := float(new_w) / old_w
		main.FIELD_W = new_w
		for layer in [main.enemy_layer, main.fx_layer]:
			for n in layer.get_children():
				n.position.x *= k
				if "target_pos" in n:
					n.target_pos.x *= k
		for w in main.warrior_layer.get_children():
			if w.post != w.fitted_post:
				w.post_u = w.post.x / old_w   # placed or moved since the last resize
			w.post.x = w.post_u * main.FIELD_W
			w.fitted_post = w.post
			if w.guard_area.has_area():
				w.guard_area = Rect2(w.guard_area.position.x * k, w.guard_area.position.y, w.guard_area.size.x * k, w.guard_area.size.y)
			if w.is_emplacement():
				w.position = w.post
			else:
				w.position.x *= k
				w.route = PackedVector2Array()
		if main.objective_layer != null:
			for o in main.objective_layer.get_children():
				o.refit(k)   # objectives keep their place across the field, like the map (and their roads)
			main.paths.invalidate()
		for b in main.wall_layer.get_children():
			if b.post != b.fitted_post:
				b.end_u = Vector2(b.seg_a().x, b.seg_b().x) / old_w   # built or moved since the last resize
			var ax: float = b.end_u.x * main.FIELD_W
			var bx: float = b.end_u.y * main.FIELD_W
			b.half.x = (bx - ax) / 2.0
			b.position.x = (ax + bx) / 2.0
			b.post = b.position
			b.fitted_post = b.post
			b.queue_redraw()
		if main.wall_start != null:
			main.wall_start.x *= k
		main.paths.setup(main)
		main.battlefield.walls_changed()
		main.castle.lay_out()
	main.castle.queue_redraw()
	main.castle._drawn_state = Vector3(-1, -1, -1)
	main.queue_redraw()


## mode: a difficulty ("easy", "normal", "hard"), "freeplay" or "tutorial".
func choose_mode(mode: String) -> void:
	main._foes_seen.clear()   # (each battle introduces its foes afresh)
	main.castle_warned = 0
	main.hud.foe_queue.clear()
	main.campaign = mode == "campaign"
	main.mission = Campaign.mission() if main.campaign else (Scenarios.get_scenario(main.battle_id) if main.battle_id != "" else {})
	main.rules = MissionRules.make(main.mission)
	main.rules.setup(main, main.mission)
	main.waves._show_castle(main.rules.has_castle())
	# The battle's pace: forced auto-play gives a few seconds to deploy, then sends the
	# waves itself, a window apart (see pace_window). (Speed and pause work as ever.)
	var pace: Dictionary = main.mission.get("pace", {})
	main.forced_auto = pace.get("auto", "free") == "forced"
	if main.forced_auto:
		main.auto_play = true
		main.deploying = true
		main.auto_timer = float(pace.get("deploy", 15.0))
	# The battlefield: a campaign mission's own map (terrain, lanes, castle), Classic on
	# one the campaign has opened, or the open meadow.
	var classic := not main.campaign and main.battle_id == "" and Data.DIFFICULTIES.has(mode)
	main.map_id = main.mission.get("map", "") if main.missions.scripted() else (main.classic_map if classic and not Maps.get_map(main.classic_map).is_empty() else "")
	main.map_extra = {}
	main.fallen = []
	# Battles fill the window: a map stretches across the field like the meadow does (the
	# campaign map and the cutscenes, drawn as one picture, keep their frame).
	main.missions._lock_portrait(false)
	main.paths.set_map(Maps.get_map(main.map_id))
	main.hazards.setup(main, Maps.get_map(main.map_id), main.mission)
	main.bells.setup(main, main.mission, Maps.get_map(main.map_id))
	main.conduits.setup(main, Maps.get_map(main.map_id))
	main.contracts.setup(main, main.mission)
	main.night.setup(main, main.mission)
	if main.paths.has_terrain():
		main.drawing._repaint_ground()
	var map: Dictionary = Maps.get_map(main.map_id)
	main.stage_music = map.get("music", "mountain" if map.get("biome", "") == "mountain" else "calm")
	main.waves.set_battle_music(map)
	main.castle.set_style(map.get("castle", "keep"))
	main.freeplay = mode == "freeplay"
	main.tutorial = mode == "tutorial"
	main.difficulty = Campaign.difficulty if main.campaign else ("normal" if main.freeplay or main.tutorial else mode)
	main.ambience.setup(main.mission.get("mood", "normal") if main.campaign else mode)
	main.castle.modulate = main.ambience.castle_tint()
	main.castle.top_part.modulate = main.castle.modulate
	main.queue_redraw()
	var d: Dictionary = Data.DIFFICULTIES[main.difficulty]
	main.permadeath = d["permadeath"] and not main.freeplay and not main.tutorial   # practice and the sandbox forgive
	main.down_time = d["down_time"]
	main.cost_mult = d["cost"]
	main.price_step = d.get("round", 1)
	main.castle_max = roundf(Data.CASTLE_HP * d["castle"])
	main.castle_base = main.castle_max
	main.castle_hp = main.castle_max
	main.hud.set_prices(main.cost_mult, main.price_step)
	if main.freeplay:
		main.gold = Main.FREEPLAY_GOLD
		main.hud.show_freeplay_bar()
	main.started = true
	main.hud.hide_mode_select()
	if main.missions.scripted():
		main.missions._begin_mission()
	main.rules.start()
	if main.waves.survival():
		main.best_before = main.waves._best_record()
		if main.best_before > 0:
			main.hud.show_message("Survive as many waves as you can. Your best here: %d" % main.best_before)
		else:
			main.hud.show_message("Survive as many waves as you can")
	if main.tutorial:
		var guide := Tutorial.new()
		guide.main = main
		guide.hud = main.hud
		main.hud.add_child(guide)
