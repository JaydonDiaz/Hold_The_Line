extends SceneTree
## Sets up a battle, lets it play for a few seconds, and saves a screenshot.
## Needs a window (not --headless):
##   godot --path . -s tools/screenshot.gd -- /path/to/out.png [wave]

var main
var frames := 0
var out := "res://screenshot.png"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = args[0]
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _setup(args: Array) -> void:
	main.choose_mode("normal")
	main.gold = 2000
	main.wave = int(args[1]) - 1 if args.size() > 1 else 5
	var hires := [
		["swordsman", Vector2(200, 380)], ["swordsman", Vector2(440, 380)], ["swordsman", Vector2(320, 420)],
		["archer", Vector2(180, 600)], ["archer", Vector2(460, 600)], ["mage", Vector2(320, 620)],
		["frost", Vector2(320, 520)],
	]
	for h in hires:
		main.placing_type = h[0]
		main.hire_at(h[1])
	for w in main.get_warriors():
		w.position = w.post
	# Show off a few upgrade builds: [kind, path, tiers].
	var builds := [["mage", 2, 3], ["mage", 1, 1], ["frost", 2, 3], ["frost", 1, 2], ["swordsman", 0, 4], ["swordsman", 2, 2], ["archer", 1, 3]]
	for b in builds:
		for w in main.get_warriors():
			if w.kind == b[0]:
				for i in b[2]:
					main.selected = w
					main.upgrade_selected(b[1])
				break
	main.start_wave()


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		_setup(OS.get_cmdline_user_args())
	if frames == 30:
		for w in main.get_warriors():
			if w.kind == "mage":
				main.selected = w
				break
	if frames >= 420:
		root.get_texture().get_image().save_png(out)
		print("saved ", out)
		return true
	return false
