extends SceneTree
## Pictures of every battlefield in every way it's played: Classic on each campaign map,
## each campaign mission, each Battle Modes scenario, and each zone an escort or a retreat
## moves through. For looking the maps over by eye. Needs a window (not --headless):
##   Godot --resolution 1380x800 --path . -s tools/map_tour.gd -- <out dir> [filter]
## Only shots whose name contains `filter` are taken. Uses a scratch campaign save.

const CD = preload("res://scripts/data/campaign_data.gd")
const Maps = preload("res://scripts/campaign/maps.gd")
const Scenarios = preload("res://scripts/mission/scenarios.gd")

var main
var out := ""
var filter := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if not args.is_empty() else "user://tour"
	filter = args[1] if args.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(out)
	var campaign = root.get_node("Campaign")
	campaign.save_path = "user://map_tour_campaign.cfg"
	campaign.started_once = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _fresh() -> void:
	if main != null:
		main.free()
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.hud.hide_mode_select()


func _quiet() -> void:
	if main.hud.story != null:
		main.hud.story.skip()
	await _frames(40)


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)


## Every zone after the first, for the rules that move through them.
func _zones(name: String) -> void:
	if not main.rules.has_method("zones") or not main.rules.has_method("enter_next"):
		return
	for i in range(1, main.rules.zones().size()):
		main.rules.enter_next()
		await _frames(30)
		_shot("%s_z%d" % [name, i])


func _run() -> void:
	var campaign = root.get_node("Campaign")
	for id in Maps.MAPS:
		if filter != "" and not ("classic_" + id).contains(filter):
			continue
		await _fresh()
		main.classic_map = id
		main.setup.choose_mode("normal")
		await _quiet()
		_shot("classic_" + id)
	for id in CD.MISSIONS:
		if filter != "" and not ("mission_" + id).contains(filter):
			continue
		campaign.new_campaign("normal")
		await _fresh()
		main.missions.start_mission(id)
		await process_frame
		await _quiet()
		_shot("mission_" + id)
		await _zones("mission_" + id)
	for id in Scenarios.SCENARIOS:
		if filter != "" and not ("battle_" + id).contains(filter):
			continue
		await _fresh()
		main.battle_id = id
		main.setup.choose_mode("normal")
		await _quiet()
		_shot("battle_" + id)
		await _zones("battle_" + id)
	if main != null:
		main.free()
	var save := ProjectSettings.globalize_path("user://map_tour_campaign.cfg")
	if FileAccess.file_exists(save):
		DirAccess.remove_absolute(save)
	quit()
