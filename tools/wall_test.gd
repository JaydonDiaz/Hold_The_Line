extends SceneTree
## Barricade routing check. No warriors; a line of walls across y=400 and a stream of
## mixed enemies. Reports where enemies crossed the line, how many hacked at a wall,
## and when walls fell.
## Run: godot --headless --path . --fixed-fps 60 -s tools/wall_test.gd -- [gap|sealed|narrow|funnel]
##   gap     walls from x=0 to 520, open on the right: everyone should walk around
##   sealed  wall across the whole field: they have to break through
##   narrow  a 14px slit nobody fits through: they should give up on it and break the wall
##   funnel  a V of walls leaving a gap in the middle

const KINDS := ["goblin", "orc", "wolf", "goblin", "troll", "orc", "wolf", "goblin"]
const COUNT := 24

var main
var frames := 0
var scenario := "gap"
var spawned := 0
var crossings := []    # x where each enemy passed y=400
var hitters := {}      # enemies that struck a wall
var leaked := 0
var falls := []
var built := {}        # wall -> where it stood
var tracked := {}      # enemy -> last y
var seen := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		scenario = args[0]
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _wall(a: Vector2, b: Vector2) -> void:
	main.placing_type = "barricade"
	main.wall_start = null
	main.hire_at(a)
	main.hire_at(b)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		main.choose_mode("normal")
		main.gold = 5000
		main.wave = 5
		main.castle_hp = 1e9
		match scenario:
			"gap":
				_wall(Vector2(0, 400), Vector2(400, 400))
				_wall(Vector2(400, 400), Vector2(520, 400))
			"sealed":
				_wall(Vector2(0, 400), Vector2(320, 400))
				_wall(Vector2(320, 400), Vector2(640, 400))
			"narrow":
				_wall(Vector2(0, 400), Vector2(313, 400))
				_wall(Vector2(327, 400), Vector2(640, 400))
			"funnel":
				_wall(Vector2(0, 250), Vector2(290, 420))
				_wall(Vector2(640, 250), Vector2(350, 420))
		print("%s: %d walls, gold left %d" % [scenario, main.get_barricades().size(), main.gold])
		for b in main.get_barricades():
			print("  wall %s -> %s  hp %d  cost %d" % [b.seg_a(), b.seg_b(), b.max_hp, b.spent])
			built[b] = b.position
		for i in COUNT:
			main.spawn_queue.append([KINDS[i % KINDS.size()], 5])
		main.spawn_interval = 0.5
		main.wave_active = true
	for e in main.get_enemies():
		if not tracked.has(e) and not seen.has(e):
			seen[e] = true
			tracked[e] = e.position.y
			e.reached_castle.connect(func(_e): leaked += 1)
			spawned += 1
	for e in tracked.keys():
		if not is_instance_valid(e) or e.dead or e.sieging:
			tracked.erase(e)
			continue
		if e.wall_target != null:
			hitters[e] = true
		if tracked[e] < 400.0 and e.position.y >= 400.0:
			crossings.append(roundi(e.position.x))
		tracked[e] = e.position.y
	for b in built:
		if (not is_instance_valid(b) or not b.is_active()) and not falls.has(b):
			falls.append(b)
			print("  wall at %s fell at %.1fs" % [built[b], frames / 60.0])
	if spawned == COUNT and tracked.is_empty() or frames > 60 * 120:
		crossings.sort()
		print("crossed y=400 at x: ", crossings)
		print("leaked %d of %d, %d hit a wall, walls fallen %d, %.1fs" % [leaked, COUNT, hitters.size(), falls.size(), frames / 60.0])
		if not tracked.is_empty():
			for e in tracked:
				print("  still on field: %s at %s" % [e.kind, e.position])
		return true
	return false
