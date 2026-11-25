extends RefCounted
## Freeplay's controls, the end of a battle (summary, records), playing again and the game speed.
## Part of the game controller: `main` is main.gd, which holds the battle's state.

const Main = preload("res://scripts/main.gd")

var main: Main

const FREEPLAY_MAX_LEVEL := 40
var freeplay_level := 1  # wave level used for freeplay spawns
var run_survived := 0     # the waves survived, as the battle ended


func _init(m: Main) -> void:
	main = m


# --- Freeplay ------------------------------------------------------------

func change_freeplay_level(step: int) -> void:
	freeplay_level = clampi(freeplay_level + step, 1, FREEPLAY_MAX_LEVEL)


## Queues the selected wave on top of whatever is already coming.
func spawn_freeplay_wave() -> void:
	if not main.started or main.game_over:
		return
	if main.dragging != null:
		main.groups._end_drag()
	main.spawn_queue.append_array(main.waves._banded(main.waves._build_wave(freeplay_level), freeplay_level))
	main.spawn_interval = maxf(0.35, 0.9 - freeplay_level * 0.03)
	main.hud.show_message("Wave %d incoming" % freeplay_level)


func spawn_single(kind: String) -> void:
	if main.dragging != null:
		main.groups._end_drag()
	main.waves._spawn_enemy(kind, freeplay_level)


func clear_enemies() -> void:
	main.spawn_queue.clear()
	main.bands.clear()
	main.band_due.clear()
	for e in main.battlefield.get_enemies():
		e.dead = true
		e.queue_free()


func _finish(won: bool) -> void:
	main.audio.set_track("")
	main.effects.sfx("victory" if won else "defeat")
	main.game_over = true
	main.victory = won
	run_survived = main.wave if won else main.waves.waves_survived()   # (counted while the wave being fought is still on)
	main.wave_active = false
	Engine.time_scale = 1.0
	main.formation_ctl._cancel()
	main.enemy_layer.process_mode = Node.PROCESS_MODE_DISABLED
	main.warrior_layer.process_mode = Node.PROCESS_MODE_DISABLED
	main.wall_layer.process_mode = Node.PROCESS_MODE_DISABLED
	var survived := run_survived
	if won:
		main.contracts.on_win()
	if main.campaign:
		var flawless: bool = won and main.rules.flawless()
		if flawless:
			for k in main.battle_xp:
				main.battle_xp[k] *= 1.0 + Campaign.CD.FLAWLESS_BONUS   # perfect play: more learned
		Campaign.finish_mission(won, main.missions._mission_flags() if won else [], main.rules.xp_gains(won, main.battle_xp))
		var note := ""
		if won:
			note = ("Flawless! Every unit learns %d%% more." % roundi(Campaign.CD.FLAWLESS_BONUS * 100.0)) if flawless else \
					"Not flawless (%s): a perfect win trains every unit %d%% more." % [main.rules.flaw.to_lower(), roundi(Campaign.CD.FLAWLESS_BONUS * 100.0)]
		main.hud.flawless_note = [note, flawless]
		main.hud.show_campaign_end(won, main.mission, survived, _summary(won))
		return
	if main.battle_id != "":
		_finish_battle_mode(won)
		return
	var previous := _save_record(survived)
	main.hud.show_end(won, survived, previous, main.endless, "Your army is gone" if main.routed else "")


## How the battle went, for the end screen.
func _summary(won: bool) -> String:
	if main.routed:
		return "Every troop was lost, with no gold left to raise more."
	return main.rules.summary(won)


## A survival run's waves, kept if they beat its best.
func _keep_survival_record(survived: int) -> void:
	if main.battle_id == "":
		_save_record(survived)
		return
	if main.records_path == "":
		return
	var cfg := ConfigFile.new()
	cfg.load(main.records_path)
	var key := "%s@%s" % [main.battle_id, main.difficulty]
	if survived > int(cfg.get_value("survive", key, 0)):
		cfg.set_value("survive", key, survived)
		cfg.save(main.records_path)


## A Battle Modes scenario over: how long it lasted, its best (waves survived, kept per
## scenario and difficulty), and the way to play it again.
func _finish_battle_mode(won: bool) -> void:
	var survived := run_survived
	var best := main.waves._best_record() if main.records_path != "" else main.best_before
	_keep_survival_record(survived)
	var record := "New best!" if survived > best else "Best: %d waves" % best
	main.hud.show_battle_end(won, main.mission["name"], _summary(won), record, "battle:%s:%s" % [main.battle_id, main.difficulty], survived)


## Plays a Battle Modes scenario again from the start (the scene reloads, as for any game).
func play_again(key: String) -> void:
	Campaign.screen = key
	_restart()


## Records the waves survived if it beats this mode's best; returns the best from before.
func _save_record(survived: int) -> int:
	if main.records_path == "" or main.tutorial:
		return 0
	var cfg := ConfigFile.new()
	cfg.load(main.records_path)
	var key := main.difficulty + ("@" + main.map_id if main.map_id != "" else "")   # each battlefield keeps its own best
	var previous: int = cfg.get_value("best", key, 0)
	if survived > previous:
		cfg.set_value("best", key, survived)
		cfg.save(main.records_path)
	return previous


func _restart() -> void:
	Engine.time_scale = 1.0
	main.get_tree().reload_current_scene()


func cycle_speed() -> void:
	if main.game_over:
		return
	Engine.time_scale = 1.0 if Engine.time_scale >= 3.0 else Engine.time_scale + 1.0
