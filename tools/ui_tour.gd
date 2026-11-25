extends SceneTree
## A tour of every screen, one screenshot each, to check the look across the whole game:
## the title and its card sets, settings, a battle's HUD (a unit picked, a hire card, the
## foe card, the orders box, the castle's tabs), the menu box, the end screens, Freeplay,
## the Tutorial, a story box, the campaign map and its Ledger, the campaign's end.
## Needs a window (not --headless):
##   godot --path . --resolution 640x1040 -s tools/ui_tour.gd -- <out dir> [only these steps]
## (Uses its own campaign save, never the player's.)

var out := ""
var only := []
var main
var step := 0
var wait := 0
var campaign
var steps := []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	only = args.slice(1)
	campaign = root.get_node("Campaign")
	campaign.save_path = "user://ui_tour_campaign.cfg"
	campaign.started_once = true
	steps = [
		["00_start", func(): _fresh(); main.hud.hide_mode_select(); main.hud.show_splash(func(): pass), 90],
		["01_title", func(): _fresh(), 80],
		["01b_campaign_slots", func(): main.hud._show_cards("campaign"), 70],
		["02_battlefields", func(): main.hud._show_cards("classic"), 70],
		["02b_viewer", func(): main.hud.show_battlefields("normal"), 60],
		["02c_viewer_greenwood", func(): _view("greenwood_roads"), 30],
		["02d_viewer_gate", func(): _view("monastery_gate"), 30],
		["02e_viewer_carnival", func(): _view("city_carnival"), 30],
		["03_battle_modes", func(): main.hud._show_cards("battle"), 70],
		["04_settings", func(): _fresh(); main.hud.show_settings(), 40],
		["05_battle_hud", func(): _battle(); _pick("archer"), 60],
		["06_hire_card", func(): main.selected = null; main.hud._show_hire_card("frost", main.hud.hire_buttons["frost"]); main.hud.show_foe("wolf", "Wolf", "Fast. Runs past your troops to bite at the walls."), 40],
		["06b_pick", func(): main.hud.hide_hover(); _pick("swordsman"), 10],
		["07_orders", func(): main.hud.toggle_orders(main), 40],
		["08_abilities", func(): main.hud.toggle_orders(main); main.selected = null; main.formation_ctl.switch_tab("abilities"), 30],
		["09_castle", func(): main.castle_ctl.select_castle(), 30],
		["10_menu", func(): main.hud.show_menu_confirm(), 30],
		["11_end", func(): _battle(); main.hud.show_end(false, 7, 9, false, "The castle fell."), 60],
		["12_freeplay", func(): _fresh(); main.hud.hide_mode_select(); main.setup.choose_mode("freeplay"), 60],
		["13_tutorial", func(): _fresh(); main.hud.hide_mode_select(); main.setup.choose_mode("tutorial"), 120],
		["14_story", func(): _battle(); main.hud.play_story([{"who": "hale", "text": "Commander, the scouts are back. Goblins on all three roads, and wolves with them."}]), 90],
		["15_world_map", func(): _map(), 90],
		["16_ledger", func(): main.hud.world_map.show_ledger(), 40],
		["16b_training", func(): _map(); main.hud.world_map.show_training(), 60],
		["19_cutscene", func(): _battle(); main.hud.play_story([{"who": "ogre", "text": "One little fire on the frontier? Let it flicker."}]), 120],
		["20_group", func(): _battle(); main.groups._set_group(main.battlefield.get_warriors()), 40],
		["21_powers", func(): main.formation_ctl._cancel(); main.gold = 5000; main.castle_ctl.ability_item("fireball"); main.castle_ctl.ability_item("arrows"); main.castle_ctl.ability_item("heal"), 40],
		["22_retreat", func(): _fresh(); main.hud.hide_mode_select(); main.missions._on_mode_chosen("battle:long_retreat:normal"), 200],
		["17_battle_end", func(): _battle(); main.hud.show_battle_end(true, "The Old Fort", "You held the fort for 12 waves.", "Best: 12 waves", "battle:old_fort", 12), 60],
		["18_campaign_end", func(): _battle(); main.hud.show_campaign_end(true, (load("res://scripts/data/campaign_data.gd").MISSIONS["stonehollow"] as Dictionary), 5, "Every workshop stood."), 60],
	]
	if not only.is_empty():
		steps = steps.filter(func(s): return only.has(s[0]))


func _fresh() -> void:
	if main != null:
		main.free()   # (gone now, not at the end of the frame: two games at once confuse the HUD)
	paused = false   # (a menu box left the game paused)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _battle() -> void:
	_fresh()
	main.classic_map = "greenwood_roads"
	main.hud.hide_mode_select()
	main.setup.choose_mode("normal")
	main.gold = 2000
	for h in [["swordsman", Vector2(200, 420)], ["archer", Vector2(440, 520)], ["mage", Vector2(320, 600)], ["frost", Vector2(240, 600)]]:
		main.placing_type = h[0]
		main.hiring.hire_at(h[1])
	main.placing_type = ""
	for w in main.battlefield.get_warriors():
		w.position = w.post


## The battlefield viewer, showing map `id`.
func _view(id: String) -> void:
	var v = main.hud.battlefields
	v.open_maps = v.maps.duplicate()   # (all of them, to see them unlocked)
	v.show_map(v.maps.find(id))


func _pick(kind: String) -> void:
	for w in main.battlefield.get_warriors():
		if w.kind == kind:
			main.selected = w
			return


func _map() -> void:
	_fresh()
	campaign.reset()
	campaign.new_campaign("normal")
	campaign.completed = ["ashwatch", "ashwatch_road", "stonehollow"]
	campaign.allies = ["stonehollow"]
	main.hud.hide_mode_select()
	main.hud.show_world_map(campaign)


func _process(_d: float) -> bool:
	if step >= steps.size():
		if main != null:
			main.queue_free()
		return true
	if wait == 0:
		steps[step][1].call()
		wait = int(steps[step][2])
		return false
	wait -= 1
	if wait == 0:
		root.get_texture().get_image().save_png("%s/%s.png" % [out, steps[step][0]])
		print("shot ", steps[step][0])
		step += 1
	return false
