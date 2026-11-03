extends SceneTree
## Ogre King check. Plays out wave 20 with a strong late-game army, then reports
## when the boss came out, what it did and whether the army beat it.
## Run: godot --headless --path . --fixed-fps 60 -s tools/boss_test.gd [-- army=N]
##   army = how many upgrade tiers each unit gets (default 6: a 4 + 2 build)

var main
var frames := 0
var boss = null
var boss_frame := 0
var fight := 0.0      # seconds the boss lasted
var stomps := 0
var summons := 0
var horns := 0
var pushed_back := 0.0   # furthest the boss was ever moved back up the field in one frame (should be 0)
var last_y := 0.0
var most_hit := 0        # most warriors one of its blows hurt at once
var dazed_seen := 0      # warriors seen stunned by a stomp
var tiers := 6
const ARMY := [
	["swordsman", Vector2(240, 380), [0, 2]], ["swordsman", Vector2(400, 380), [2, 0]], ["swordsman", Vector2(320, 420), [0, 1]],
	["martial", Vector2(160, 420), [0, 1]], ["archer", Vector2(200, 600), [0, 2]], ["archer", Vector2(440, 600), [0, 2]],
	["mage", Vector2(320, 620), [1, 2]], ["mage", Vector2(120, 640), [0, 2]], ["frost", Vector2(520, 560), [1, 2]],
	["healer", Vector2(320, 700), [2, 0]], ["bard", Vector2(260, 540), [1, 0]], ["alchemist", Vector2(380, 540), [1, 2]],
	["tower", Vector2(80, 520), [0, 2]], ["cannon", Vector2(320, 660), [1, 0]], ["martial", Vector2(480, 420), [1, 0]], ["magetower", Vector2(560, 680), [2, 0]],
]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("army="):
			tiers = int(a.trim_prefix("army="))
	main = load("res://main.tscn").instantiate()
	main.records_path = ""
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		main.choose_mode("normal")
		main.gold = 999999
		for a in ARMY:
			main.placing_type = a[0]
			main.hire_at(a[1])
			var w = main.warrior_layer.get_child(main.warrior_layer.get_child_count() - 1)
			w.position = w.post
			for t in tiers:
				main.selected = w
				main.upgrade_selected(a[2][0] if t < 4 else a[2][1])
		main.selected = null
		main.wave = 19
		main.start_wave()
	if boss_frame == 0:
		for e in main.get_enemies():
			if e.boss:
				boss = e
				boss_frame = frames
				last_y = e.position.y
				print("wave 20 cleared at %.0fs; Ogre King out with %d hp (castle %d)" % [frames / 60.0, e.max_hp, main.castle_hp])
	elif is_instance_valid(boss) and not boss.dead:
		fight = (frames - boss_frame) / 60.0
		if boss.stomp_timer > 5.9 and boss.stomp_timer <= 5.9 + 1.0 / 60.0:
			stomps += 1
		if boss.summon_timer > 11.9 and boss.summon_timer <= 11.9 + 1.0 / 60.0:
			summons += 1
		if boss.horn_timer > 29.9 and boss.horn_timer <= 29.9 + 1.0 / 60.0:
			horns += 1
		pushed_back = maxf(pushed_back, last_y - boss.position.y)
		last_y = boss.position.y
		if boss.lunge > 0.149:
			var hurt: int = main.get_warriors().filter(func(w): return w.hurt > 0.099).size()
			most_hit = maxi(most_hit, hurt)
		for w in main.get_warriors():
			if w.dazed > 1.49:
				dazed_seen += 1
	if main.choosing or main.game_over or frames > 60 * 400:
		var how := "BEATEN" if main.choosing else ("LINE FELL" if main.game_over else "TIMEOUT")
		print("  pushed back at most %.1fpx in a frame, most hurt by one blow %d, stunned by stomps %d, %d war horns" % [
				pushed_back, most_hit, dazed_seen, horns])
		print("%s after %.0fs of boss fight (castle %d, %d stomps, %d summons, %d of %d warriors standing)" % [how,
				fight, main.castle_hp, stomps, summons,
				main.get_warriors().filter(func(w): return w.is_active()).size(), main.get_warriors().size()])
		return true
	return false
