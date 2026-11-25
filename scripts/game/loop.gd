extends RefCounted
## The frame loop: what happens every frame (hover, drags, the wave's spawning and pace,
## music, the HUD and the cards).
## Part of the game controller: `main` is main.gd, which holds the battle's shared state.

const Main = preload("res://scripts/main.gd")
const Warrior = preload("res://scripts/troops/warrior.gd")

var main: Main

var layer_timer := 0.0
var last_track := ""


func _init(m: Main) -> void:
	main = m


func tick(delta: float) -> void:
	main.mouse = main.pointer if main.mouse_stand_in == Vector2.INF else main.mouse_stand_in
	# Between waves, the troop under the mouse perks up (it can be picked up and moved).
	main.hovered = main.formation_ctl._warrior_at(main.mouse) if main.started and not main.hiring.fighting() and main.dragging == null and not main.group_drag \
			and main.placing_type == "" and main.mouse.y <= Main.FIELD_H else null
	main.orders._update_calls(delta)
	main.formation_ctl._formations_step(delta)
	if main.dragging != null:
		main.groups._update_drag()
	if main.group_drag:
		main.groups._update_group_drag()
	if main.box_start != null and not main.box_active and main.mouse.distance_to(main.box_start) > 6.0:
		main.box_active = true
	main.group = main.group.filter(func(w): return is_instance_valid(w) and not w.is_queued_for_deletion())
	if main.group.size() == 1:
		main.selected = main.group[0]   # down to one: it's an ordinary selection
		main.group.clear()
	if main.selected != null and (not is_instance_valid(main.selected) or main.selected.is_queued_for_deletion()):
		main.selected = null
	if not main.game_over:
		main.battlefield._tick_fallen(delta)
		if main.started:
			main.rules.process(delta)
			main.waves._check_rout(delta)
		main.waves._bands_step(delta)
		if not main.spawn_queue.is_empty():
			main.spawn_timer -= delta
			if main.spawn_timer <= 0.0:
				var next: Array = main.spawn_queue.pop_front()
				main.waves._spawn_enemy(next[0], next[1], null, int(next[2]) if next.size() > 2 else -1)
				main.spawn_timer = main.spawn_interval
		if main.freeplay:
			# No wave rounds in freeplay: "active" just means enemies are around.
			main.gold = Main.FREEPLAY_GOLD
			main.wave_active = not main.spawn_queue.is_empty() or not main.battlefield.get_enemies().is_empty()
			if not main.wave_active:
				main.castle_hp = main.castle_max   # sandbox: patched up once the field is clear
				main.gates_warned = false
		elif main.forced_auto and main.wave_active and main.spawn_queue.is_empty():
			# The last of the wave is on the field: the next comes a window later, whether
			# this one's beaten or not. Beat it sooner and the rest of the window is a breather.
			main.wave_clock += delta
			if main.wave_clock >= main.waves.pace_window():
				main.waves.start_wave(true)
			elif main.battlefield.get_enemies().is_empty():
				main.waves._end_wave()
		elif main.auto_play and main.started and not main.wave_active:
			if main.forced_auto:
				main.auto_timer -= delta   # (a forced pace keeps the battle's own time)
				if not main.deploying and not main.hiring.fighting():
					main.waves._rest(delta)
			else:
				main.auto_timer -= delta / maxf(Engine.time_scale, 1.0)   # real seconds, whatever the speed
			if main.auto_timer <= 0.0:
				main.waves.start_wave()
		elif main.wave_active and main.spawn_queue.is_empty() and main.battlefield.get_enemies().is_empty():
			if main.waves._boss_due():
				main.waves._spawn_boss()
			else:
				main.waves._end_wave()
	main.hud.refresh(main)
	main.hud.touch_words()
	if main.hud.compact:
		main.hud._fit_text(main.hud.start_btn, 15, main.hud.start_btn.size.x - 14.0)
	if main.hud.scene_music != "":
		main.audio.set_track(main.hud.scene_music)   # a cutscene's own music
	elif not main.started:
		main.audio.set_track("" if main.hud.splash != null else ("map" if main.hud.world_map != null else "title"))   # (silent on the start screen) the campaign map's own, or the title screen's
	elif not main.game_over:
		layer_timer -= delta
		if layer_timer <= 0.0:
			layer_timer = 0.5
			main.bard_instruments = main.effects._bard_instruments()
			main.audio.set_layers(main.bard_instruments)
		# Between waves, a Bard on every instrument strikes up a song together.
		var ensemble: bool = main.song_on and main.audio._music.has("ensemble") and main.effects.all_bards_present()
		main.audio.set_track(main.battle_music if main.rules.battle_on() else ("ensemble" if ensemble else main.stage_music))
		if main.audio._playing_track != last_track:
			if main.audio._playing_track == "ensemble":
				main.hud.show_message("The Bards strike up a song together!")
			last_track = main.audio._playing_track
	# Hovering a unit on the field shows its description card.
	var hovered: Warrior = null
	if main.started and not main.game_over and main.dragging == null and main.placing_type == "" and main.mouse.y <= Main.FIELD_H:
		hovered = main.formation_ctl._warrior_at(main.mouse)
	var sigil: Dictionary = main.conduits.at_point(main.mouse) if hovered == null and main.started and main.mouse.y <= Main.FIELD_H else {}
	if hovered == null and not main.castle_selected and main.castle_ctl._castle_hovered():
		main.hud.show_castle_card(main, main.mouse)
	elif not sigil.is_empty():
		main.hud.show_card_at(main.conduits.card_text(sigil), main.mouse)
	else:
		main.hud.show_unit_card(hovered, main.mouse)
	main.overlay.queue_redraw()
