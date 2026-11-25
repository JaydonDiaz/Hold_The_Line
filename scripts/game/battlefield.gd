extends RefCounted
## What's on the field: the living enemies and troops (cached once a frame, with grids for
## nearby lookups), threats and dangers, walls, graves and the fallen.
## Part of the game controller: `main` is main.gd, which holds the battle's shared state.

const Main = preload("res://scripts/main.gd")
const Data = preload("res://scripts/data/data.gd")
const Barricade = preload("res://scripts/troops/barricade.gd")
const Enemy = preload("res://scripts/enemies/enemy.gd")
const Grave = preload("res://scripts/troops/grave.gd")

var main: Main

var _enemies := []           # get_enemies() for this frame
var _enemies_frame := -1
var _grid := {}              # enemies by grid cell this frame (see enemies_near)
var _grid_frame := -1
var _wgrid := {}             # your units by grid cell this frame (see warriors_near)
var _wgrid_frame := -1
const GRID := 64.0
var _warriors := []          # get_warriors() for this frame
var _warriors_frame := -1
var _threats: Array = []
var _threats_frame := -1
var shatter_depth := 0        # > 0 while a shatter's going off (what it kills doesn't spread Brittle again)
var _dangers: Array = []
var _dangers_frame := -1
const FALLEN_KEEP := 25.0


func _init(m: Main) -> void:
	main = m


## The living enemies. Built once a frame and shared (callers mustn't change it); a
## death or a new arrival makes the next call build a fresh array, so a loop already
## going over the old one isn't disturbed.
func get_enemies() -> Array:
	var f := Engine.get_process_frames()
	if f != _enemies_frame:
		_enemies_frame = f
		_enemies = main.enemy_layer.get_children().filter(func(e): return not e.dead)
	return _enemies


## Living enemies whose centres may be within r of p (some a little further): only the
## grid cells around p, so crowds of enemies don't each check every other enemy.
## The grid is built once a frame from where enemies were then.
func enemies_near(p: Vector2, r: float) -> Array:
	var f := Engine.get_process_frames()
	if f != _grid_frame:
		_grid_frame = f
		_grid.clear()
		for e in get_enemies():
			var c := Vector2i(floori(e.position.x / GRID), floori(e.position.y / GRID))
			if _grid.has(c):
				_grid[c].append(e)
			else:
				_grid[c] = [e]
	var lo := Vector2i(floori((p.x - r) / GRID), floori((p.y - r) / GRID))
	var hi := Vector2i(floori((p.x + r) / GRID), floori((p.y + r) / GRID))
	var out := []
	for cy in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var cell = _grid.get(Vector2i(cx, cy))
			if cell != null:
				out.append_array(cell)
	return out


## Your units (active or not) whose centres may be within r of p, from a grid built
## once a frame like enemies_near's.
## The ground about to be hit by something warned (an Arrow Storm's or a Fireball's ring,
## falling stone, burning ground): {"c", "r"} circles and {"a", "b", "r"} lines. Troops
## get out of them (warrior._dodge). Worked out once a frame.
func dangers() -> Array:
	var f := Engine.get_process_frames()
	if f == _dangers_frame:
		return _dangers
	_dangers_frame = f
	_dangers = []
	for n in main.get_tree().get_nodes_in_group("danger"):
		var z: Dictionary = n.danger_zone()
		if not z.is_empty():
			_dangers.append(z)
	return _dangers   # (enemies' warned blows aren't here: troops weigh those up for themselves, see threats())


## Every warned blow an enemy has on its way (a slam hauled back, a stomp, a strafing run,
## a charge, a lit fuse): what troops weigh up (defense.gd). Worked out once a frame.
func threats() -> Array:
	var f := Engine.get_process_frames()
	if f == _threats_frame:
		return _threats
	_threats_frame = f
	_threats = []
	for e in get_enemies():
		if e.windup_key != 0 and (e.fuse >= 0.0 or e.stomp_wind > 0.0 or e.slam_wind > 0.0 or e.strafe_warn > 0.0 or e.strafe_left > 0.0
				or e.charge_warn > 0.0 or e.charging > 0.0):
			_threats.append_array(e.threats())
	return _threats


## Shattercraft: a Brittle foe killed shatters, hurting every enemy round it; a first
## shatter (gen 0, not itself set off by a shatter) at Avalanche makes a few more Brittle.
## Those, when they go, shatter too but spread nothing: no endless chain.
func shatter(at: Vector2, fx: Dictionary, brittle: Dictionary, gen: int, by: String) -> void:
	var r: float = fx["radius"]
	var near := enemies_near(at, r + 40.0).filter(func(e): return not e.dead and e.position.distance_to(at) <= r + e.radius)
	main.credit = by
	shatter_depth += 1
	for e in near:
		if is_instance_valid(e) and not e.dead:
			e.take_damage(float(fx["damage"]), true, "ice")
	shatter_depth -= 1
	if gen == 0 and int(fx.get("spread", 0)) > 0 and not brittle.is_empty():
		var rest := enemies_near(at, r * 1.8 + 40.0).filter(func(e): return not e.dead and e.brittle_t <= 0.0)
		rest.sort_custom(func(a, b): return a.position.distance_to(at) < b.position.distance_to(at))
		for e in rest.slice(0, int(fx["spread"])):
			e.apply_brittle(brittle, fx, 1, by)
	main.effects.spawn_burst(at, r, Color(0.7, 0.95, 1.0))
	main.effects.spawn_burst(at, r * 0.5, Color(0.95, 1.0, 1.0))
	main.effects.sfx("freeze", 1.3)


func warriors_near(p: Vector2, r: float) -> Array:
	var f := Engine.get_process_frames()
	if f != _wgrid_frame:
		_wgrid_frame = f
		_wgrid.clear()
		for w in get_warriors():
			var c := Vector2i(floori(w.position.x / GRID), floori(w.position.y / GRID))
			if _wgrid.has(c):
				_wgrid[c].append(w)
			else:
				_wgrid[c] = [w]
	var lo := Vector2i(floori((p.x - r) / GRID), floori((p.y - r) / GRID))
	var hi := Vector2i(floori((p.x + r) / GRID), floori((p.y + r) / GRID))
	var out := []
	for cy in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var cell = _wgrid.get(Vector2i(cx, cy))
			if cell != null:
				out.append_array(cell)
	return out


## Call when an enemy dies or leaves (get_enemies then rebuilds).
func enemies_changed() -> void:
	_enemies_frame = -1


## A unit has died for good, so a grave (or a ruin) marks the spot.
func add_grave(w) -> void:
	if w.summoned or w.clone_of != null or w is Barricade:
		return
	var g := Grave.new()
	g.setup_from(w)
	main.grave_layer.add_child(g)
	if not w.is_emplacement() and not w.wall_guard:
		main.fallen.append(_fallen_record(w))   # (a Gravebinder could raise it, for a while)


func _fallen_record(w) -> Dictionary:
	var spells := []
	if not w.chain.is_empty():
		spells.append("lightning")
	if not w.breath.is_empty():
		spells.append("fire")
	if not w.lance.is_empty():
		spells.append("arcane")
	return {"kind": w.kind, "name": w.data["name"], "tiers": w.tiers.duplicate(), "spent": w.spent,
		"at": w.position, "left": FALLEN_KEEP, "claimed": null,
		"frames": w._look()["frames"], "sprite": w.sprite_name(), "color": w.data.get("color", Color.WHITE),
		"hp": w.max_hp, "speed": w.move_speed, "damage": w.damage, "cooldown": w.cooldown, "range": w.attack_range,
		"splash": w.splash, "attack": String(w.data.get("attack", "melee")), "multishot": w.multishot,
		"combo": maxi(1, w.combo_hits), "slow": w.slow, "slow_time": w.slow_time, "song_radius": w.song_radius,
		"spells": spells, "chain": w.chain.duplicate(), "lance": w.lance.duplicate(), "breath": w.breath.duplicate()}


## The fallen lie only so long: then they're past raising.
func _tick_fallen(delta: float) -> void:
	for rec in main.fallen.duplicate():
		rec["left"] -= delta
		if rec["left"] <= 0.0 and (rec["claimed"] == null or not is_instance_valid(rec["claimed"])):
			main.fallen.erase(rec)


## A fallen troop raised by a Gravebinder: it rises where it fell, its kind, its upgrades
## and its look kept, its strength what they'd made it, cut by the corruption, and fights
## for the horde as its kind did (see data.gd, necro). Returns the new enemy.
func raise_fallen(rec: Dictionary, binder) -> Node:
	var c: Dictionary = binder.necro["corrupt"]
	var dmg: float = float(rec["damage"]) * float(c["damage"])
	var d := {"tier": 3, "hp": float(rec["hp"]) * float(c["hp"]), "speed": clampf(float(rec["speed"]) * 0.4, 24.0, 48.0),
		"damage": dmg, "wall_damage": dmg, "cooldown": float(rec["cooldown"]) / float(c["rate"]), "fights": true,
		"bounty": 8 + int(float(rec["spent"]) * 0.04), "radius": 14.0, "scale": 3.0, "color": rec["color"], "knock": 0.8,
		"look": rec["sprite"]}
	var reach: float = clampf(float(rec["range"]), 90.0, 230.0)
	match String(rec["attack"]):
		"melee", "combo":
			d["damage"] = dmg * int(rec["combo"])   # (a Martial Artist's flurry, one blow's worth)
		"arrow":
			d["ranged"] = {"range": reach, "speed": 380.0}
			d["volley"] = int(rec["multishot"])
		"orb":
			d["ranged"] = {"range": reach, "speed": 320.0}
			d["shot_style"] = "orb"
			d["shot_splash"] = float(rec["splash"])
			if not (rec["spells"] as Array).is_empty():
				# Its path's own spell, as the horde's mages cast them (corrupted: weaker).
				var cast: Dictionary = Data.ENEMIES["warmage"]["cast"].duplicate(true)
				cast["spells"] = rec["spells"]
				cast["range"] = reach
				# Its spells as strong as its path had made them, cut by the corruption.
				var ch: Dictionary = rec["chain"]
				if not ch.is_empty():
					cast["lightning"]["damage"] = float(ch["damage"]) * float(c["damage"])
					cast["lightning"]["jumps"] = int(ch["jumps"])
				var ln: Dictionary = rec["lance"]
				if not ln.is_empty():
					cast["arcane"]["damage"] = float(ln["damage"]) * float(c["damage"])
				var br: Dictionary = rec["breath"]
				if not br.is_empty():
					cast["fire"]["dps"] = maxf(float(br.get("damage", 2.0)) / maxf(float(br.get("interval", 0.3)), 0.05), float(br.get("burn_dps", 0.0))) * float(c["damage"]) * 2.0
				cast["cooldown"] = float(cast["cooldown"]) / float(c["rate"])
				d["cast"] = cast
		"frost":
			d["ranged"] = {"range": reach, "speed": 340.0}
			d["shot_style"] = "frost"
			d["shot_goo"] = [maxf(0.3, float(rec["slow"])), maxf(1.5, float(rec["slow_time"]))]
		"flask":
			d["ranged"] = {"range": reach, "speed": 300.0}
			d["shot_style"] = "flask"
			d["shot_splash"] = maxf(float(rec["splash"]), 30.0)
		"note":
			d["ranged"] = {"range": reach, "speed": 400.0}
			d["shot_style"] = "note"
			d["drum"] = {"radius": maxf(float(rec["song_radius"]), 100.0), "every": 3.0, "speed": 0.2 * float(c["heal"]) * 2.0,
				"rate": 0.25 * float(c["heal"]) * 2.0, "time": 3.4, "kinds": ["*"]}
		"heal":
			d["damage"] = 2.0
			d["mend"] = {"amount": float(rec["damage"]) * float(c["heal"]), "every": float(rec["cooldown"]) / float(c["rate"]), "range": reach}
	var e := Enemy.new()
	e.setup("corrupted", d, main, rec["at"], 1.0, 1.0, 1.0)
	e.level = binder.level
	e.corrupted = true
	e.fallen_kind = rec["kind"]
	e.fallen_tiers = (rec["tiers"] as Array).duplicate()
	e.frames_override = rec["frames"]
	e.died.connect(main.waves._on_enemy_died)
	e.reached_castle.connect(main.waves._on_enemy_at_castle)
	e.goal = main.rules.enemy_goal(e)
	main.enemy_layer.add_child(e)
	enemies_changed()
	main.effects.spawn_burst(e.position, 36.0, Color(0.45, 1.0, 0.5))
	main.effects.spawn_text(e.position + Vector2(0, -50), "Corrupted %s!" % rec["name"], Color(0.55, 1.0, 0.55))
	main.effects.sfx("rise", 0.5)
	return e


func get_graves() -> Array:
	return main.grave_layer.get_children()


func _grave_at(p: Vector2):
	for g in get_graves():
		if g.position.distance_to(p) < 18.0:
			return g
	return null


## Your units on the field (not the castle's wall guards). Shared like get_enemies.
func get_warriors() -> Array:
	var f := Engine.get_process_frames()
	if f != _warriors_frame:
		_warriors_frame = f
		_warriors = main.warrior_layer.get_children().filter(func(w): return not w.is_queued_for_deletion())
	return _warriors


func warriors_changed() -> void:
	_warriors_frame = -1
	_wgrid_frame = -1


func get_barricades() -> Array:
	return main.wall_layer.get_children().filter(func(b): return not b.is_queued_for_deletion())


## Recomputes enemy routes; call whenever a wall goes up, comes down or moves.
func walls_changed() -> void:
	main.paths.invalidate()


## The standing barricade nearest to p, if its face is within `reach` of p.
func barricade_touching(p: Vector2, reach: float):
	var best = null
	var best_d := reach
	for b in get_barricades():
		if not b.is_active():
			continue
		var d: float = b.gap_from(p)
		if d <= best_d:
			best_d = d
			best = b
	return best
