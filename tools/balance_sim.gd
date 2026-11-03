extends SceneTree
## Headless balance check: plays the game with a simple bot and reports how far it gets.
## Run from the project folder:
##   godot --headless --path . --fixed-fps 60 -s tools/balance_sim.gd [-- mode=hard] [priority=first] [mage=2,0]
##   (mode = easy, normal, hard or hardcore)
##   [with=bard] [bard=0,2]   (with= swaps a unit in for the second mage; kind=a,b sets its upgrade plan)
##   [walls]   build a funnel of two barricades above the front line once wave 2 is cleared

const Data = preload("res://scripts/data.gd")
var ORDER := ["swordsman", "archer", "swordsman", "mage", "frost", "martial", "archer", "swordsman", "mage"]
# Front line of melee, ranged support behind it.
const MELEE_POSTS := [Vector2(320, 360), Vector2(160, 360), Vector2(480, 360), Vector2(80, 420), Vector2(560, 420), Vector2(240, 420), Vector2(400, 420)]
const RANGED_POSTS := [Vector2(320, 560), Vector2(160, 580), Vector2(480, 580), Vector2(240, 680), Vector2(400, 680), Vector2(80, 640), Vector2(560, 640)]
const MAX_WARRIORS := 12
# Path order per unit: the first goes to tier 4, the second to tier 2.
var PLANS := {"swordsman": [0, 1], "archer": [0, 2], "mage": [1, 2], "frost": [1, 2], "martial": [0, 1],
		"healer": [0, 2], "bard": [0, 2], "alchemist": [2, 0]}

var main
var frames := 0
var buys := 0
var last_wave := 0
var knockouts := 0
var want_walls := false
const FUNNEL := [[Vector2(0, 300), Vector2(275, 330)], [Vector2(640, 300), Vector2(365, 330)]]


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.records_path = ""   # bot games don't count toward the player's best
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		var args := OS.get_cmdline_user_args()
		var mode := "normal"
		for a in args:
			if a.begins_with("mode="):
				mode = a.trim_prefix("mode=")
		main.choose_mode(mode)
		for a in args:
			if a.begins_with("priority="):
				for k in Data.WARRIORS:
					main.last_priority[k] = a.trim_prefix("priority=")
			if a == "walls":
				want_walls = true
			if a.begins_with("with="):
				ORDER[ORDER.size() - 1] = a.trim_prefix("with=")
			elif "=" in a and Data.WARRIORS.has(a.get_slice("=", 0)):
				PLANS[a.get_slice("=", 0)] = Array(a.get_slice("=", 1).split(",")).map(func(x): return int(x))
	if main.choosing:
		main._finish(true)   # the bot stops at the final wave rather than going endless
	if main.game_over:
		print("RESULT: %s at wave %d, castle %d, gold %d, warriors %d, knockouts %d" % [
			"WON" if main.victory else "LOST", main.wave, main.castle_hp, main.gold, main.get_warriors().size(), knockouts])
		return true
	if frames > 60 * 60 * 60:
		print("RESULT: timed out at wave %d" % main.wave)
		return true
	for w in main.get_warriors():
		if w.down_timer > main.down_time - 0.02:
			knockouts += 1
	if not main.wave_active:
		if main.wave > last_wave:
			last_wave = main.wave
			print("wave %2d cleared  castle %3d  gold %4d  warriors %d  knockouts %d" % [
				main.wave, main.castle_hp, main.gold, main.get_warriors().size(), knockouts])
		_spend()
		main.start_wave()
	return false


func _spend() -> void:
	# (Re)build whichever funnel wall is missing; broken walls are gone.
	var missing = null
	for w in FUNNEL:
		if not main.get_barricades().any(func(b): return b.seg_a().is_equal_approx(w[0]) or b.seg_b().is_equal_approx(w[0])):
			missing = w
			break
	if want_walls and main.wave >= 2 and missing != null:
		var w: Array = missing
		if main.gold < main.wall_cost(w[0], w[1]):
			return
		main.placing_type = "barricade"
		main.hire_at(w[0])
		main.hire_at(w[1])
		_spend()
		return
	while true:
		var kind: String = ORDER[buys % ORDER.size()]
		var post = _free_post(MELEE_POSTS if kind == "swordsman" else RANGED_POSTS)
		if main.get_warriors().size() < MAX_WARRIORS and post != null:
			if main.gold < main.hire_cost(kind):
				return
			main.placing_type = kind
			main.hire_at(post)
			buys += 1
		else:
			# Cheapest next upgrade along each unit's planned build.
			var best = null
			var best_path := -1
			for w in main.get_warriors():
				for path in PLANS[w.kind]:
					if w.path_state(path) == "ok":
						if best == null or w.upgrade_cost(path) < best.upgrade_cost(best_path):
							best = w
							best_path = path
						break
			if best == null or main.gold < best.upgrade_cost(best_path):
				return
			main.selected = best
			main.upgrade_selected(best_path)


func _free_post(posts: Array):
	for p in posts:
		if main.can_post_at(p):
			return p
	return null
