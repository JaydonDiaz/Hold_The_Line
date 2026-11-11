extends SceneTree
## Which music plays where. Run from the project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/music_test.gd
## The title music on the title screen and the campaign map; the story music in the
## prologue; the villain music in the Ogre King's and the Ash Marshal's cutscenes (and
## the dialogue around them back in its box); each stage's own peaceful music between
## waves (the meadow's, the mountains'); the battle music during waves, each map its own;
## and a part for every Bard instrument in every stage's music. Exits 1 if anything failed.

const TEST_SAVE := "user://music_test.cfg"

var main
var campaign
var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	campaign = root.get_node("Campaign")
	campaign.save_path = TEST_SAVE
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Waits until the composer has made every piece (they're kept for the whole run).
func _all_composed() -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 180000:   # real seconds: composing runs on its own thread
		if main.audio._picked >= main.audio._piece_count() and main.audio._music.size() >= 8:
			await _frames(2)
			return true
		await create_timer(0.2).timeout
	return false


func _playing() -> String:
	await _frames(3)
	return main.audio._playing_track


func _fresh() -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)


func _run() -> void:
	campaign.reset()
	await _fresh()
	check(await _all_composed(), "every piece is composed (%d)" % main.audio._piece_count())
	for track in main.audio.STAGE_TRACKS:
		var sync: AudioStreamSynchronized = main.audio._music[track]
		check(sync.stream_count == main.audio.INSTRUMENTS.size() + 1, "%s: a part for each of the %d Bard instruments" % [track, main.audio.INSTRUMENTS.size()])
	check(await _playing() == "title", "the title screen plays the title music")
	# Classic: the meadow's peaceful music, the battle music in a wave.
	main.hud.picking = true
	main.choose_mode("normal")
	check(await _playing() == "calm", "Classic between waves: the meadow's peaceful music (the old calm track)")
	main.start_wave()
	check(await _playing() == "battle", "Classic in a wave: the battle music")
	# A Bard on the field brings its instrument into whatever's playing.
	main.gold = 9999
	main.placing_type = "bard"
	main.hire_at(Vector2(320, 600))
	main.placing_type = ""
	await _frames(40)
	check(not main.audio._layers.is_empty(), "a Bard plays along with the battle music (%s)" % ", ".join(main.audio._layers))
	# The campaign: the prologue, the map, the villains' cutscenes, Stonehollow's mountains.
	await _fresh()
	main._on_mode_chosen("campaign:new:normal")
	check(await _playing() == "story", "the prologue plays the story music")
	main.hud.story.skip()
	check(await _playing() == "map", "the campaign map plays its own music")
	var lines: Array = campaign.story_lines("ashwatch_outro")
	main.hud.play_story(lines)
	check(main.hud.story.get_script().resource_path.ends_with("story.gd"), "Ashwatch's ending opens in the dialogue box")
	var seen := []
	for i in 30:
		if main.hud.story == null:
			break
		var kind: String = main.hud.story.get_script().resource_path.get_file()
		if seen.is_empty() or seen[-1][0] != kind:
			seen.append([kind, await _playing()])
		main.hud.story.advance()
		main.hud.story.advance()
		await _frames(30)
	var kinds: Array = seen.map(func(x): return x[0])
	check(kinds == ["story.gd", "cutscene.gd", "story.gd"], "the Ogre King's line plays as its own cutscene between the dialogue (%s)" % str(kinds))
	check(seen.size() == 3 and seen[1][1] == "villain", "...with the villain music (%s)" % str(seen.map(func(x): return x[1])))
	# Back on the map after a win: the story it plays splits the villain off the same way.
	main.hud.hide_world_map()
	campaign.pending_story = "ashwatch_outro"
	main.hud.show_world_map(campaign)
	var kinds2 := []
	for i in 30:
		if main.hud.story == null:
			break
		var kind: String = main.hud.story.get_script().resource_path.get_file()
		if kinds2.is_empty() or kinds2[-1] != kind:
			kinds2.append(kind)
		main.hud.story.advance()
		main.hud.story.advance()
		await _frames(30)
	check(kinds2 == ["story.gd", "cutscene.gd", "story.gd"], "after a win, the map's story gives the Ogre King his own cutscene (%s)" % str(kinds2))
	check(main.hud.world_map.overlay == null, "...and the map takes clicks again once it's over")
	# Esc skips the whole thing, cutscene and all.
	main.hud.play_story(lines)
	main.hud.story.skip()
	await process_frame
	check(main.hud.story == null, "Esc skips the rest of the story, the cutscene too")
	# Stonehollow: the mountains' peaceful music.
	campaign.completed = ["ashwatch"]
	await _fresh()
	main.hud.hide_mode_select()
	main.start_mission("stonehollow")
	await process_frame
	if main.hud.story != null:
		main.hud.story.skip()
	check(await _playing() == "mountain", "Stonehollow between waves: the mountains' peaceful music")
	# Each map's own battle music.
	var Maps = load("res://scripts/maps.gd")
	var styles := {"": main.Audio.battle_for({})}
	for id in Maps.MAPS.keys() + Maps.ZONES.keys():
		styles[id] = main.Audio.battle_for(Maps.get_map(id))
	var distinct := {}
	for id in styles:
		distinct[styles[id]] = true
	check(distinct.size() == styles.size(), "every map has its own battle music (%d maps, %d pieces)" % [styles.size(), distinct.size()])
	check(main.battle_music == "battle_quarry", "...Stonehollow's is its own (%s)" % main.battle_music)
	var t0 := Time.get_ticks_msec()
	while not main.audio._music.has("battle_quarry") and Time.get_ticks_msec() - t0 < 150000:
		await create_timer(0.2).timeout   # (composed while the battle's being set up)
	main.start_wave()
	await _frames(5)
	check(await _playing() == "battle_quarry", "...made while the battle's set up, and playing in the wave (%s; wanted %d, thread %s, cached %s)" % [main.audio._playing_track,
			main.audio._wanted_first.size(), main.audio._thread, main.audio._cache.has("battle_quarry")])
	t0 = Time.get_ticks_msec()
	var parts := 0
	while parts < main.audio.INSTRUMENTS.size() + 1 and Time.get_ticks_msec() - t0 < 150000:
		await create_timer(0.2).timeout
		parts = (main.audio._music["battle_quarry"] as AudioStreamSynchronized).stream_count if main.audio._music.has("battle_quarry") else 0
	check(parts == main.audio.INSTRUMENTS.size() + 1, "...with a part for every Bard instrument too")
	# Greenwood and Sable Crossing: their own peaceful music between waves (made on demand,
	# while the battle's set up).
	for pair in [["greenwood_roads", "forest"], ["sable_crossing", "river"]]:
		await _fresh()
		main.hud.picking = true
		main.records_path = ""
		main.classic_map = pair[0]
		var c0 := Time.get_ticks_msec()
		main.choose_mode("normal")
		while not main.audio._music.has(pair[1]) and Time.get_ticks_msec() - c0 < 60000:   # (real seconds: it's composed on its own thread)
			await process_frame
		var ms := Time.get_ticks_msec() - c0
		var now: String = await _playing()
		check(now == pair[1], "%s between waves: its own peaceful music, %s (ready %.1fs after the battle opened, composed in the background)" % [
				pair[0], pair[1], ms / 1000.0])
	check(main.audio._cache.has("battle_quarry") and (main.audio._cache["battle"] as AudioStreamWAV).data != (main.audio._cache["battle_quarry"] as AudioStreamWAV).data,
			"...and it isn't the meadow's")
	main.free()
	main = null
	for f in [TEST_SAVE, TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
