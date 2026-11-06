extends Node2D
## The castle's own upgrades. The Castle tab's four paths (Data.CASTLE_PATHS: Fortify,
## Wall Archers, Wall Mages, Ability Power) and the Abilities tab's abilities
## (Data.ABILITIES): what's been bought, the guards on the wall, the abilities'
## cooldowns and aiming, and their effects on the field. Abilities are cast from the
## bar in the field's top-left corner (or the Abilities tab); "target" ones wait for a click.

const Sprites = preload("res://scripts/sprites.gd")
const Data = preload("res://scripts/data.gd")
const Warrior = preload("res://scripts/warrior.gd")

const Castle = preload("res://scripts/castle.gd")
const GUARD_MARGIN := 70.0   # the end posts are this far in from the field's edges (off the corner towers)
const GUARD_REACH := 250.0   # wall guards hit anything this close to the castle wall (25 ft)
# Where each kind of guard stands along the wall (0 = left end, 1 = right end), by how
# many of that kind there are. Fully upgraded, left to right: Archer, Mage, Frost
# Witch, Archer (on the gatehouse), Frost Witch, Mage, Archer.
const GUARD_POSTS := {
	"archer": [[0.5], [0.0, 1.0], [0.0, 0.5, 1.0], [0.0, 0.5, 1.0, 0.25]],
	"mage": [[0.17], [0.17, 0.83]],
	"frost": [[0.67], [0.67, 0.33]],
}

var main
var owned := {}         # ability key -> true
var tiers := [0, 0, 0, 0]   # tiers bought in each castle path
var guards := []        # the Archers, Mages and Frost Witches on the wall
var guard_w := 0.0      # field width the guards' posts were spread over
var cooldown := {}      # ability key -> seconds until it can be cast again
var aiming := ""        # a "target" ability waiting for a click on the field
var rally_left := 0.0   # Rally Horn: seconds of buff left
var pending := []       # effects in flight: {"kind", "at", "t", ...}
var shows := []         # visuals: {"kind", "at", "t", "life", ...}
var t := 0.0


static func info(key: String) -> Dictionary:
	return Data.ABILITIES[key]


# --- Castle paths ----------------------------------------------------------

## The effect of the highest tier bought in each path, looked up by key (tiers give
## totals, so only the latest one counts).
func fx(key: String, default: Variant) -> Variant:
	for p in tiers.size():
		if tiers[p] > 0:
			var e: Dictionary = Data.CASTLE_PATHS[p]["tiers"][tiers[p] - 1]["effect"]
			if e.has(key):
				return e[key]
	return default


## The next tier in path p, or {} once it's maxed.
func next_tier(p: int) -> Dictionary:
	var path: Array = Data.CASTLE_PATHS[p]["tiers"]
	return path[tiers[p]] if tiers[p] < path.size() else {}


func tier_cost(p: int, i: int) -> int:
	return main.price(Data.CASTLE_PATHS[p]["tiers"][i]["cost"])


func can_upgrade(p: int) -> bool:
	return not next_tier(p).is_empty() and main.gold >= tier_cost(p, tiers[p]) and not main.game_over


func upgrade(p: int) -> bool:
	if not can_upgrade(p):
		return false
	main.gold -= tier_cost(p, tiers[p])
	var old_hp_mult: float = fx("hp", 1.0)
	tiers[p] += 1
	main.sfx("upgrade")
	var t_name: String = Data.CASTLE_PATHS[p]["tiers"][tiers[p] - 1]["name"]
	main.hud.show_message("%s!" % t_name)
	# Stronger walls keep the castle at the same share of its health (a castle at 60%
	# is still at 60% of its new, higher max).
	var new_max: float = roundf(main.castle_base * fx("hp", 1.0))
	if new_max != roundf(main.castle_base * old_hp_mult):
		main.castle_hp = main.castle_hp / main.castle_max * new_max
		main.castle_max = new_max
	if p == 1 or p == 2:
		_post_guards()
	return true


## How much less damage the castle takes.
func armor() -> float:
	return fx("armor", 0.0)


## Puts the guards the wall paths call for on the wall (replacing any already there).
func _post_guards() -> void:
	for g in guards:
		g.queue_free()
	guards.clear()
	var spec := []
	for p in [1, 2]:
		if tiers[p] > 0:
			var g: Dictionary = Data.CASTLE_PATHS[p]["tiers"][tiers[p] - 1]["effect"]["guards"]
			for kind in g:
				for i in g[kind][0]:
					spec.append([kind, g[kind][1]])
	# Each kind fills its own posts along the wall, in order (see GUARD_POSTS).
	var used := {}
	for entry in spec:
		var kind: String = entry[0]
		var n: int = used.get(kind, 0)
		used[kind] = n + 1
		var posts: Array = GUARD_POSTS[kind]
		var w: Node2D = Warrior.new()
		w.wall_guard = true
		w.setup(kind, Data.WARRIORS[kind], main, Vector2.ZERO)
		w.tiers = (entry[1] as Array).duplicate()
		w._apply_upgrades()
		w.hp = w.max_hp
		w.priority = "first"
		var count: int = spec.filter(func(e): return e[0] == kind).size()
		w.set_meta("wall_at", posts[mini(count, posts.size()) - 1][mini(n, posts.size() - 1)])
		add_child(w)
		guards.append(w)
	_spread_guards()


func _spread_guards() -> void:
	guard_w = main.FIELD_W
	for g in guards:
		var at: float = g.get_meta("wall_at")
		var x := lerpf(GUARD_MARGIN, main.FIELD_W - GUARD_MARGIN, at)
		# The middle post is up on the gatehouse.
		var y := wall_y() - (Castle.GATE_RISE if is_equal_approx(at, 0.5) else 0.0)
		g.post = Vector2(x, y)
		g.position = g.post


## Whether a wall guard can reach this enemy: anything within GUARD_REACH of the
## castle wall, anywhere along it (they shoot from their posts and never move).
func in_guard_reach(e) -> bool:
	return main.CASTLE_Y - e.position.y - e.radius <= GUARD_REACH


## Where guards stand: on the walkway along the top of the castle wall.
func wall_y() -> float:
	return main.CASTLE_Y + 10.0


# --- Abilities -------------------------------------------------------------

## Abilities that have been bought, in data order (the bar shows these).
func abilities() -> Array:
	return Data.ABILITIES.keys().filter(func(k): return owned.has(k))


func cost(key: String) -> int:
	return main.price(info(key)["cost"])


## How hard abilities hit this wave: they keep up with enemy health, times the
## Ability Power path.
func power() -> float:
	var level := maxi(main.wave, 1)
	if main.freeplay:
		level = main.freeplay_level
	return pow(Data.level_growth(level, Data.HP_GROWTH, Data.LATE_HP_GROWTH), Data.CASTLE_POWER_GROWTH) * fx("power", 1.0)


## The Ability Power path's multiplier on its own (for what doesn't grow with the
## wave: Healing Light's healing and the Rally Horn's boost).
func boost() -> float:
	return fx("power", 1.0)


func dmg(key: String) -> float:
	return info(key)["damage"] * power()


func radius(key: String) -> float:
	return info(key)["radius"] * fx("area", 1.0)


func recharge(key: String) -> float:
	return info(key)["cooldown"] * fx("recharge", 1.0)


func can_buy(key: String) -> bool:
	return not owned.has(key) and main.gold >= cost(key) and not main.game_over


func buy(key: String) -> bool:
	if not can_buy(key):
		return false
	main.gold -= cost(key)
	owned[key] = true
	main.sfx("upgrade")
	main.hud.show_message("%s ready!" % info(key)["name"])
	return true


func ready_in(key: String) -> float:
	return cooldown.get(key, 0.0)


## Pressing an ability: instant ones go off, targeted ones start aiming (pressing it
## again stops aiming).
func trigger(key: String) -> void:
	if not owned.has(key) or main.game_over or not main.started:
		return
	if ready_in(key) > 0.0:
		return
	if info(key)["cast"] == "target":
		aiming = "" if aiming == key else key
		if aiming != "":
			main.placing_type = ""
			main.wall_start = null
			main.selected = null
		return
	_cast(key, Vector2.ZERO)


## A click on the field while aiming. Returns whether it was used.
func aim_click(p: Vector2) -> bool:
	if aiming == "":
		return false
	var key := aiming
	if key == "lightning" and _nearest_enemy(p, radius(key)) == null:
		main.spawn_text(p, "No enemy there", Color(0.8, 0.85, 1.0))
		return true
	aiming = ""
	_cast(key, p)
	return true


func _cast(key: String, p: Vector2) -> void:
	var d := info(key)
	cooldown[key] = recharge(key)
	var gate := Vector2(main.FIELD_W / 2.0, main.CASTLE_Y - 40.0)
	match key:
		"arrows":
			main.sfx("bow")
			for i in d["volleys"]:
				pending.append({"kind": "volley", "at": p, "t": 0.35 + i * 0.5})
				shows.append({"kind": "arrows", "at": p, "t": -i * 0.5, "life": 0.4, "seed": randi()})
		"fireball", "frost":
			main.sfx("fire" if key == "fireball" else "frost")
			var fly := clampf(gate.distance_to(p) / 900.0, 0.25, 0.7)
			pending.append({"kind": key, "at": p, "t": fly})
			shows.append({"kind": key + "_fly", "at": p, "from": gate, "t": 0.0, "life": fly})
		"lightning":
			_thunder(p, d)
		"heal":
			_heal_light(p)
		"horn":
			main.sfx("horn")
			rally_left = d["duration"]
			main.hud.show_message("Rally! The castle sounds the charge!")
			for w in main.get_warriors() + guards:
				main.spawn_burst(w.position, 26.0, d["color"])


## Healing Light: heals every troop under it and gets the downed ones back up.
func _heal_light(p: Vector2) -> void:
	main.sfx("revive")
	var r := radius("heal")
	var raised := 0
	for w in main.get_warriors():
		if w.is_queued_for_deletion() or w.position.distance_to(p) > r + w.RADIUS:
			continue
		if w.is_active():
			w.receive_heal(w.max_hp * heal_share(), [])
		else:
			w.revived(revive_share())
			raised += 1
	if raised > 0:
		main.hud.show_message("%d troop%s back on their feet!" % [raised, "" if raised == 1 else "s"])
	shows.append({"kind": "light", "at": p, "t": 0.0, "life": 0.9, "r": r})


func _thunder(p: Vector2, d: Dictionary) -> void:
	main.sfx("zap")
	var hit := []
	var e = _nearest_enemy(p, radius("lightning"))
	var from := Vector2(e.position.x + randf_range(-30, 30), -10.0)
	while e != null and hit.size() < d["chain"]:
		hit.append(e)
		main.spawn_bolt(PackedVector2Array([from, e.position]), d["color"])
		var at: Vector2 = e.position
		e.take_damage(dmg("lightning") * (1.0 if hit.size() == 1 else 0.8), true, "magic")
		e.apply_stun(d["stun"])
		from = at
		e = _nearest_enemy(at, d["hop"], hit)
	main.spawn_flash(p, 30.0)


func _nearest_enemy(p: Vector2, within: float, skip := []):
	var best = null
	var best_d := within
	for e in main.get_enemies():
		if e in skip:
			continue
		var dist: float = e.position.distance_to(p)
		if dist <= best_d:
			best_d = dist
			best = e
	return best


func _in_area(p: Vector2, r: float) -> Array:
	return main.get_enemies().filter(func(e): return e.position.distance_to(p) <= r + e.radius)


## Rally Horn's buff on every unit (warrior.gd adds this to its other buffs).
func rally(key: String) -> float:
	return info("horn")["buff"].get(key, 0.0) * boost() if rally_left > 0.0 else 0.0


## Healing Light: what share of max health it heals, and revives downed troops with.
func heal_share() -> float:
	return info("heal")["heal"] * boost()


func revive_share() -> float:
	return minf(info("heal")["revive"] * boost(), 1.0)


func _process(delta: float) -> void:
	t += delta
	if main.game_over:
		aiming = ""
	for key in cooldown:
		cooldown[key] = maxf(cooldown[key] - delta, 0.0)
	rally_left = maxf(rally_left - delta, 0.0)
	for f in pending.duplicate():
		f["t"] -= delta
		if f["t"] <= 0.0:
			pending.erase(f)
			_land(f)
	for s in shows.duplicate():
		s["t"] += delta
		if s["t"] >= s["life"]:
			shows.erase(s)
	if not guards.is_empty() and guard_w != main.FIELD_W:
		_spread_guards()   # the field changed width
	queue_redraw()


func _land(f: Dictionary) -> void:
	var p: Vector2 = f["at"]
	match f["kind"]:
		"volley":
			var d := info("arrows")
			for e in _in_area(p, radius("arrows")):
				e.take_damage(dmg("arrows"))
			main.sfx("hit", 1.3)
		"fireball":
			var d := info("fireball")
			main.sfx("boom")
			for e in _in_area(p, radius("fireball")):
				e.take_damage(dmg("fireball"), true, "magic")
				e.apply_burn(d["burn"][0] * power(), d["burn"][1])
			shows.append({"kind": "blast", "at": p, "t": 0.0, "life": 0.5, "r": radius("fireball"), "col": d["color"]})
		"frost":
			var d := info("frost")
			main.sfx("frost", 0.7)
			for e in _in_area(p, radius("frost")):
				e.apply_freeze(d["freeze"])
				e.take_damage(dmg("frost"), true, "ice")
				e.apply_slow(d["slow"][0], d["freeze"] + d["slow"][1])
			shows.append({"kind": "shatter", "at": p, "t": 0.0, "life": 0.6, "r": radius("frost"), "col": d["color"]})


# --- Drawing ---------------------------------------------------------------

func _draw() -> void:
	for s in shows:
		var k: float = clampf(s["t"] / s["life"], 0.0, 1.0)
		if s["t"] < 0.0:
			continue
		var p: Vector2 = s["at"]
		match s["kind"]:
			"arrows":
				var rng := RandomNumberGenerator.new()
				rng.seed = s["seed"]
				var r: float = radius("arrows")
				for i in 16:
					var ang := rng.randf() * TAU
					var spot := p + Vector2(cos(ang), sin(ang) * 0.6) * r * sqrt(rng.randf())
					var fall := 1.0 - clampf(k * 1.4 - rng.randf() * 0.4, 0.0, 1.0)
					var tip := spot + Vector2(-0.35, -1.0) * 110.0 * fall
					if fall > 0.0:
						draw_line(tip, tip + Vector2(-0.35, -1.0) * 14.0, Color(0.55, 0.38, 0.2), 2.0)
						draw_line(tip, tip + Vector2(-0.35, -1.0) * 3.0, Color(0.8, 0.8, 0.85), 2.0)
					else:
						draw_line(spot, spot + Vector2(-0.35, -1.0) * 8.0, Color(0.5, 0.35, 0.2, 1.0 - k), 2.0)
				draw_set_transform(p, 0, Vector2(1, 0.6))
				draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(1, 0.9, 0.6, 0.3 * (1.0 - k)), 2.0, true)
				draw_set_transform(Vector2.ZERO)
			"fireball_fly", "frost_fly":
				var from: Vector2 = s["from"]
				var at := from.lerp(p, k) + Vector2(0, -sin(k * PI) * 120.0)
				var fire: bool = s["kind"] == "fireball_fly"
				var col := Color(1.0, 0.5, 0.15) if fire else Color(0.6, 0.9, 1.0)
				for j in 5:
					var back := from.lerp(p, maxf(k - j * 0.04, 0.0)) + Vector2(0, -sin(maxf(k - j * 0.04, 0.0) * PI) * 120.0)
					Sprites.disc(self, back, 9.0 - j * 1.5, Color(col, 0.5 - j * 0.09))
				Sprites.disc(self, at, 10.0, col)
				Sprites.disc(self, at, 5.0, Color(1, 0.95, 0.6) if fire else Color(1, 1, 1))
			"blast":
				var r: float = s["r"] * (0.4 + 0.6 * k)
				draw_set_transform(p, 0, Vector2(1, 0.65))
				Sprites.disc(self, Vector2.ZERO, r, Color(1.0, 0.45, 0.1, 0.5 * (1.0 - k)))
				Sprites.disc(self, Vector2.ZERO, r * 0.6, Color(1.0, 0.85, 0.35, 0.6 * (1.0 - k)))
				draw_arc(Vector2.ZERO, s["r"], 0, TAU, 40, Color(1.0, 0.6, 0.2, 1.0 - k), 3.0, true)
				draw_set_transform(Vector2.ZERO)
			"light":
				# A column of light pouring down, a bright ring on the ground, motes rising.
				var r: float = s["r"]
				var fade := 1.0 - k
				draw_rect(Rect2(p.x - r * 0.35, p.y - 260.0, r * 0.7, 260.0), Color(1.0, 1.0, 0.75, 0.18 * fade))
				draw_rect(Rect2(p.x - r * 0.18, p.y - 260.0, r * 0.36, 260.0), Color(1.0, 1.0, 0.9, 0.25 * fade))
				draw_set_transform(p, 0, Vector2(1, 0.6))
				Sprites.disc(self, Vector2.ZERO, r, Color(0.6, 1.0, 0.55, 0.22 * fade))
				draw_arc(Vector2.ZERO, r * (0.6 + 0.4 * k), 0, TAU, 48, Color(1.0, 1.0, 0.7, fade), 3.0, true)
				draw_set_transform(Vector2.ZERO)
				for i in 12:
					var a := i * TAU / 12.0 + k
					var m := p + Vector2(cos(a) * r * 0.7 * fmod(i * 0.37, 1.0), sin(a) * r * 0.4) - Vector2(0, k * 70.0 + fmod(i * 13.0, 30.0))
					draw_rect(Rect2(m - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1.0, 1.0, 0.7, fade))
			"shatter":
				draw_set_transform(p, 0, Vector2(1, 0.65))
				Sprites.disc(self, Vector2.ZERO, s["r"], Color(0.7, 0.95, 1.0, 0.3 * (1.0 - k)))
				draw_arc(Vector2.ZERO, s["r"] * (0.5 + 0.5 * k), 0, TAU, 40, Color(1, 1, 1, 1.0 - k), 2.5, true)
				draw_set_transform(Vector2.ZERO)
				for i in 10:
					var dir := Vector2.from_angle(i * TAU / 10.0 + 0.3)
					var a: Vector2 = p + dir * s["r"] * 0.9 * k
					draw_line(a, a + dir * 8.0, Color(0.85, 0.97, 1.0, 1.0 - k), 3.0)
	if rally_left > 0.0:
		for w in main.get_warriors() + guards:
			var a := 0.5 + 0.3 * sin(t * 8.0)
			Sprites.disc(self, w.position + Vector2(0, -50), 3.0, Color(1.0, 0.85, 0.35, a))
	# Aiming: the area the ability will hit, under the mouse.
	if aiming != "" and main.mouse.y <= main.FIELD_H:
		var d := info(aiming)
		var m: Vector2 = main.mouse
		var col: Color = d["color"]
		draw_set_transform(m, 0, Vector2(1, 0.65) if aiming != "lightning" else Vector2.ONE)
		var r := radius(aiming)
		Sprites.disc(self, Vector2.ZERO, r, Color(col, 0.12))
		draw_arc(Vector2.ZERO, r, t * 2.0, t * 2.0 + TAU, 48, Color(col, 0.8), 2.0, true)
		draw_set_transform(Vector2.ZERO)
		draw_line(m + Vector2(-6, 0), m + Vector2(6, 0), col, 2.0)
		draw_line(m + Vector2(0, -6), m + Vector2(0, 6), col, 2.0)
		var label := "%s - click to cast, right-click cancels" % d["name"]
		var font := ThemeDB.fallback_font
		var at := m + Vector2(-110, -r * 0.65 - 12)
		draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, 220, 13, 4, Color.BLACK)
		draw_string(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, 220, 13, col)

