extends SceneTree
## Classic's endless waves and Dawnspire's battlefields outside the campaign. Run from the
## project folder:
##   Godot --headless --path . --fixed-fps 60 -s tests/endless_test.gd
## Prints one "ok"/"FAIL" line per check and a total; exits 1 if anything failed.
##
## E  Past wave 20: a slow climb (health +6% a wave, damage +3%), one more enemy a wave up
##    to 80, gold cut gently (1% a wave, to 60%), the Ogre King back every tenth wave at
##    half his health; up to wave 20 just as before
## D  Dawnspire's fields: open in Classic once the campaign reaches the citadel (the Fields
##    of Dawn once won on the nine-beacon route), its halls not offered at all; a Classic
##    battle on each plays (enemies come down through the wall's gaps); three Battle Modes
##    on them, locked till then

const Data = preload("res://scripts/data/data.gd")
const Scenarios = preload("res://scripts/mission/scenarios.gd")
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
	campaign.save_path = "user://endless_test.cfg"
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var M = load("res://scripts/main.gd")
	# --- E ---
	check(M.WavesCtl.wave_size(1) == 8 and M.WavesCtl.wave_size(20) == 46, "E  up to wave 20, two more enemies a wave, as before (8 ... 46)")
	check(M.WavesCtl.wave_size(21) == 47 and M.WavesCtl.wave_size(30) == 56 and M.WavesCtl.wave_size(200) == Data.MAX_WAVE_SIZE,
			"E  past it, one more a wave, up to %d (%d, %d, %d)" % [Data.MAX_WAVE_SIZE, M.WavesCtl.wave_size(21), M.WavesCtl.wave_size(30), M.WavesCtl.wave_size(200)])
	var hp20: float = Data.level_growth(20, Data.HP_GROWTH, Data.LATE_HP_GROWTH)
	var hp40: float = Data.level_growth(40, Data.HP_GROWTH, Data.LATE_HP_GROWTH)
	check(is_equal_approx(hp20, pow(1.12, 19)) and hp40 / hp20 < 3.5, "E  enemy health climbs slowly past wave 20 (x%.1f from 20 to 40; was x19.5)" % (hp40 / hp20))
	check(Data.LATE_DAMAGE_GROWTH <= 1.03 and Data.LATE_GOLD_MIN >= 0.6 and Data.LATE_GOLD_STEP <= 0.01, "E  damage +3% a wave, gold cut 1% a wave to 60%")
	await _fresh()
	main.hud.picking = true
	main.setup.choose_mode("normal")
	await _frames(3)
	var kings := {}
	for w in [20, 30, 40, 50, 60]:
		main.wave = w
		main.waves.boss_spawned = false
		main.waves._spawn_boss()
		kings[w] = main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1)
	var full := func(kind: String, w: int) -> float: return Data.ENEMIES[kind]["hp"] * Data.level_growth(w, Data.HP_GROWTH, Data.LATE_HP_GROWTH)
	check(kings[20].kind == "ogre_king" and kings[30].kind == "ogre_king" and kings[40].kind == "ogre_king"
			and absf(kings[30].max_hp - full.call("ogre_king", 30)) < 1.0 and absf(kings[40].max_hp - full.call("ogre_king", 40)) < 1.0,
			"E  the Ogre King back every tenth wave at full strength (wave 30: %.0f, 40: %.0f)" % [kings[30].max_hp, kings[40].max_hp])
	check(kings[50].kind == "ogre_unbound" and kings[60].kind == "ogre_unbound" and absf(kings[50].max_hp - full.call("ogre_unbound", 50)) < 1.0,
			"E  ...from wave 50, in his full power: the Ogre King, Unbound (wave 50: %.0f, 60: %.0f)" % [kings[50].max_hp, kings[60].max_hp])
	# --- D ---
	campaign.reset()
	campaign.new_campaign("normal")
	check(campaign.has_save() and not campaign.open_maps().has("ds_bailey"), "D  Dawnspire's fields locked before the campaign reaches it")
	var MV = load("res://scripts/ui/map_viewer.gd")
	var v = MV.new()
	v.setup("normal", [], "")
	check(not v.maps.any(func(m): return String(m).begins_with("dsc_")) and v.maps.has("ds_bailey"),
			"D  the map picker offers Dawnspire's fields, not its halls")
	v.free()
	for f in ["stonehollow", "greenwood", "mercyvale", "deepdelve", "frostmarch", "monastery", "freecities", "spires"]:
		if not campaign.allies.has(f):
			campaign.allies.append(f)
	for t in campaign.territories:
		for m in campaign.territories[t]["missions"]:
			if not campaign.completed.has(m) and m != "ds_assault":
				campaign.completed.append(m)
	var open: Array = campaign.open_maps()
	check(campaign.mission_open("ds_assault") and open.has("ds_approach") and open.has("ds_bailey") and open.has("ds_dawngate") and not open.has("ds_dawnfield"),
			"D  with Dawnspire reached: the Approach, the Bailey and the Dawn Gate open in Classic (%s)" % ", ".join(open.filter(func(m): return m.begins_with("ds_"))))
	campaign.completed.append("ds_assault")
	campaign.flags["ds_united"] = true
	check(campaign.open_maps().has("ds_dawnfield"), "D  ...the Fields of Dawn once the Line's won them")
	for map in ["ds_approach", "ds_bailey", "ds_dawngate", "ds_dawnfield"]:
		await _fresh()
		main.classic_map = map
		main.hud.picking = true
		main.setup.choose_mode("normal")
		await _frames(3)
		main.deploying = false
		main.waves.start_wave(true)
		await _frames(60 * 18)   # (the first warband forms up at the top before it marches)
		var es: Array = main.battlefield.get_enemies()
		var down: bool = es.any(func(e): return e.position.y > 300.0)
		check(main.map_id == map and main.rules.has_castle() and not es.is_empty() and down,
				"D  Classic on %s: the castle below, enemies through the wall's gaps and down the field" % map)
	for id in ["bailey_breach", "dawn_gate", "tenth_beacon"]:
		var sc: Dictionary = Scenarios.SCENARIOS.get(id, {})
		check(not sc.is_empty() and String(sc["map"]).begins_with("ds_") and Scenarios.TYPES.has(sc["type"]), "D  Battle Mode: %s (%s)" % [sc.get("name", id), sc.get("type", "?")])
		await _fresh()
		main.hud.hide_mode_select()
		main.missions._on_mode_chosen("battle:%s:normal" % id)
		await _frames(5)
		main.deploying = false
		main.waves.start_wave(true)
		await _frames(60 * 8)
		check(main.map_id == sc["map"] and not main.game_over and not main.battlefield.get_enemies().is_empty(), "D  ...it plays: %s on %s" % [sc["name"], main.map_id])
	# --- B ---
	const CD = preload("res://scripts/data/campaign_data.gd")
	for t in ["positions", "pass", "protect", "evac", "capture", "escort", "retreat"]:
		var story: Array = CD.MISSIONS.keys().filter(func(m): return CD.MISSIONS[m].get("type", "castle") == t)
		var ids: Array = Scenarios.of_type(t)
		check(story.all(func(m): return ids.has("story:" + m)), "B  %s: every campaign battle of its kind is a Battle Mode battlefield (%d of them, %d in all)" % [Scenarios.TYPES[t]["name"], story.size(), ids.size()])
	# The viewer: through a kind's battlefields, the campaign's locked till it's reached them.
	campaign.reset()
	campaign.new_campaign("normal")
	await _fresh()
	main.hud.show_battle_maps("protect")
	await _frames(3)
	var bv = main.hud.battlefields
	var ids2: Array = bv.battles.map(func(b): return b["id"])
	var shut: Array = bv.battles.filter(func(b): return not b["open"]).map(func(b): return b["id"])
	check(bv != null and ids2.has("signal_beacon") and ids2.has("story:fc_council") and shut.has("story:fc_council") and not shut.has("signal_beacon"),
			"B  Protect the Objective's viewer: its own and the campaign's battlefields, the campaign's locked for a new campaign (%s)" % ", ".join(ids2))
	bv.show_map(ids2.find("story:fc_council"))
	check(bv.lock_label.visible and bv.start_button.disabled and "Free Cities" in bv.lock_label.text, "B  ...a locked one says where to get it, and can't be started")
	bv.show_map(bv.at + 1)
	bv.show_map(bv.at - 1)
	check(bv.name_label.text == "The Council's Price", "B  ...the arrows go through them (%s)" % bv.name_label.text)
	# Every campaign battle plays as a Battle Mode.
	for m in CD.MISSIONS:
		var t: String = CD.MISSIONS[m].get("type", "castle")
		if not Scenarios.STORY_TYPES.has(t):
			continue
		await _fresh()
		main.hud.hide_mode_select()
		main.missions._on_mode_chosen("battle:story:%s:normal" % m)
		await _frames(5)
		main.deploying = false
		if not main.wave_active:
			main.waves.start_wave(true)
		await _frames(60 * 6)
		check(main.map_id == CD.MISSIONS[m]["map"] and not main.game_over and main.waves.survival() and main.mission.get("from_story", "") == m,
				"B  %s (%s) plays as a Battle Mode, endless" % [CD.MISSIONS[m]["name"], t])
	if main != null:
		main.free()
	if FileAccess.file_exists("user://endless_test.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://endless_test.cfg"))
	print("%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _fresh() -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	main.records_path = ""
	root.add_child(main)
	await _frames(3)
