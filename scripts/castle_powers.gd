extends Node2D
## The castle's upgrades (the Castle tab; see Data.CASTLE_UPGRADES): what's been
## bought, the abilities' cooldowns and aiming, and their effects on the field.
## Abilities are cast from the bar on the castle wall (or the Castle tab); "target"
## ones wait for a click on the field. Passives (Stone Walls, Ballistae) just work.

const Data = preload("res://scripts/data.gd")
const Castle = preload("res://scripts/castle.gd")

var main
var owned := {}         # upgrade key -> true
var cooldown := {}      # ability key -> seconds until it can be cast again
var aiming := ""        # a "target" ability waiting for a click on the field
var rally_left := 0.0   # Rally Horn: seconds of buff left
var ballista_cd := 0.0
var ballista_side := 0
var pending := []       # effects in flight: {"kind", "at", "t", ...}
var shows := []         # visuals: {"kind", "at", "t", "life", ...}
var t := 0.0


static func info(key: String) -> Dictionary:
	return Data.CASTLE_UPGRADES[key]


static func is_ability(key: String) -> bool:
	return info(key).has("cast")


## Abilities that have been bought, in data order (the bar shows these).
func abilities() -> Array:
	return Data.CASTLE_UPGRADES.keys().filter(func(k): return owned.has(k) and is_ability(k))


func cost(key: String) -> int:
	return main.price(info(key)["cost"])


## How hard abilities hit this wave: they keep up with enemy health.
func power() -> float:
	var level := maxi(main.wave, 1)
	if main.freeplay:
		level = main.freeplay_level
	return pow(Data.level_growth(level, Data.HP_GROWTH, Data.LATE_HP_GROWTH), Data.CASTLE_POWER_GROWTH)


func dmg(key: String) -> float:
	return info(key)["damage"] * power()


func can_buy(key: String) -> bool:
	return not owned.has(key) and main.gold >= cost(key) and not main.game_over


func buy(key: String) -> bool:
	if not can_buy(key):
		return false
	main.gold -= cost(key)
	owned[key] = true
	main.sfx("upgrade")
	var d := info(key)
	if key == "walls":
		var extra: float = roundf(main.castle_max * d["castle"])
		main.castle_max += extra
		main.castle_hp += extra
	main.hud.show_message("%s ready!" % d["name"] if is_ability(key) else "%s built!" % d["name"])
	return true


func ready_in(key: String) -> float:
	return cooldown.get(key, 0.0)


## Pressing an ability: instant ones go off, targeted ones start aiming (pressing it
## again stops aiming).
func trigger(key: String) -> void:
	if not owned.has(key) or not is_ability(key) or main.game_over or not main.started:
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
	if key == "lightning" and _nearest_enemy(p, info(key)["radius"]) == null:
		main.spawn_text(p, "No enemy there", Color(0.8, 0.85, 1.0))
		return true
	aiming = ""
	_cast(key, p)
	return true


func _cast(key: String, p: Vector2) -> void:
	var d := info(key)
	cooldown[key] = d["cooldown"]
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
		"horn":
			main.sfx("horn")
			rally_left = d["duration"]
			main.hud.show_message("Rally! The castle sounds the charge!")
			for w in main.get_warriors():
				main.spawn_burst(w.position, 26.0, d["color"])


func _thunder(p: Vector2, d: Dictionary) -> void:
	main.sfx("zap")
	var hit := []
	var e = _nearest_enemy(p, d["radius"])
	var from := Vector2(e.position.x + randf_range(-30, 30), -10.0)
	while e != null and hit.size() < d["chain"]:
		hit.append(e)
		main.spawn_bolt(PackedVector2Array([from, e.position]), d["color"])
		var at: Vector2 = e.position
		e.take_damage(dmg("lightning") * (1.0 if hit.size() == 1 else 0.8))
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
	return info("horn")["buff"].get(key, 0.0) if rally_left > 0.0 else 0.0


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
	if owned.has("ballista") and main.wave_active and not main.game_over:
		ballista_cd -= delta
		if ballista_cd <= 0.0:
			_ballista()
	queue_redraw()


func _land(f: Dictionary) -> void:
	var p: Vector2 = f["at"]
	match f["kind"]:
		"volley":
			var d := info("arrows")
			for e in _in_area(p, d["radius"]):
				e.take_damage(dmg("arrows"))
			main.sfx("hit", 1.3)
		"fireball":
			var d := info("fireball")
			main.sfx("boom")
			for e in _in_area(p, d["radius"]):
				e.take_damage(dmg("fireball"))
				e.apply_burn(d["burn"][0] * power(), d["burn"][1])
			shows.append({"kind": "blast", "at": p, "t": 0.0, "life": 0.5, "r": d["radius"], "col": d["color"]})
		"frost":
			var d := info("frost")
			main.sfx("frost", 0.7)
			for e in _in_area(p, d["radius"]):
				e.take_damage(dmg("frost"))
				e.apply_freeze(d["freeze"])
				e.apply_slow(d["slow"][0], d["freeze"] + d["slow"][1])
			shows.append({"kind": "shatter", "at": p, "t": 0.0, "life": 0.6, "r": d["radius"], "col": d["color"]})


## The tower closest to the target lets fly (they take turns when it's even).
func _ballista() -> void:
	var d := info("ballista")
	var best = null
	var best_y: float = main.CASTLE_Y - d["range"]
	for e in main.get_enemies():
		if e.position.y > best_y:
			best_y = e.position.y
			best = e
	if best == null:
		ballista_cd = 0.3
		return
	ballista_cd = d["cooldown"]
	var towers := ballista_spots()
	ballista_side = 0 if best.position.distance_to(towers[0]) < best.position.distance_to(towers[1]) else 1
	var from: Vector2 = towers[ballista_side]
	best.take_damage(dmg("ballista"))
	main.sfx("bow", 0.6)
	shows.append({"kind": "bolt", "at": best.position, "from": from, "t": 0.0, "life": 0.18})


func ballista_spots() -> Array:
	var top: float = main.CASTLE_Y - Castle.TOWER_RISE
	return [Vector2(Castle.TOWER_W / 2.0, top - 4.0), Vector2(main.FIELD_W - Castle.TOWER_W / 2.0, top - 4.0)]


# --- Drawing ---------------------------------------------------------------

func _draw() -> void:
	if owned.has("ballista"):
		for i in 2:
			_draw_ballista(ballista_spots()[i], i)
	for s in shows:
		var k: float = clampf(s["t"] / s["life"], 0.0, 1.0)
		if s["t"] < 0.0:
			continue
		var p: Vector2 = s["at"]
		match s["kind"]:
			"arrows":
				var rng := RandomNumberGenerator.new()
				rng.seed = s["seed"]
				var r: float = info("arrows")["radius"]
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
					draw_circle(back, 9.0 - j * 1.5, Color(col, 0.5 - j * 0.09))
				draw_circle(at, 10.0, col)
				draw_circle(at, 5.0, Color(1, 0.95, 0.6) if fire else Color(1, 1, 1))
			"blast":
				var r: float = s["r"] * (0.4 + 0.6 * k)
				draw_set_transform(p, 0, Vector2(1, 0.65))
				draw_circle(Vector2.ZERO, r, Color(1.0, 0.45, 0.1, 0.5 * (1.0 - k)))
				draw_circle(Vector2.ZERO, r * 0.6, Color(1.0, 0.85, 0.35, 0.6 * (1.0 - k)))
				draw_arc(Vector2.ZERO, s["r"], 0, TAU, 40, Color(1.0, 0.6, 0.2, 1.0 - k), 3.0, true)
				draw_set_transform(Vector2.ZERO)
			"shatter":
				draw_set_transform(p, 0, Vector2(1, 0.65))
				draw_circle(Vector2.ZERO, s["r"], Color(0.7, 0.95, 1.0, 0.3 * (1.0 - k)))
				draw_arc(Vector2.ZERO, s["r"] * (0.5 + 0.5 * k), 0, TAU, 40, Color(1, 1, 1, 1.0 - k), 2.5, true)
				draw_set_transform(Vector2.ZERO)
				for i in 10:
					var dir := Vector2.from_angle(i * TAU / 10.0 + 0.3)
					var a: Vector2 = p + dir * s["r"] * 0.9 * k
					draw_line(a, a + dir * 8.0, Color(0.85, 0.97, 1.0, 1.0 - k), 3.0)
			"bolt":
				var from: Vector2 = s["from"]
				var head := from.lerp(p, k)
				var dir := (p - from).normalized()
				draw_line(head - dir * 16.0, head, Color(0.45, 0.3, 0.15), 2.5)
				draw_line(head - dir * 3.0, head, Color(0.85, 0.85, 0.9), 3.0)
	if rally_left > 0.0:
		for w in main.get_warriors():
			var a := 0.5 + 0.3 * sin(t * 8.0)
			draw_circle(w.position + Vector2(0, -50), 3.0, Color(1.0, 0.85, 0.35, a))
	# Aiming: the area the ability will hit, under the mouse.
	if aiming != "" and main.mouse.y <= main.FIELD_H:
		var d := info(aiming)
		var m: Vector2 = main.mouse
		var col: Color = d["color"]
		draw_set_transform(m, 0, Vector2(1, 0.65) if aiming != "lightning" else Vector2.ONE)
		draw_circle(Vector2.ZERO, d["radius"], Color(col, 0.12))
		draw_arc(Vector2.ZERO, d["radius"], t * 2.0, t * 2.0 + TAU, 48, Color(col, 0.8), 2.0, true)
		draw_set_transform(Vector2.ZERO)
		draw_line(m + Vector2(-6, 0), m + Vector2(6, 0), col, 2.0)
		draw_line(m + Vector2(0, -6), m + Vector2(0, 6), col, 2.0)
		var label := "%s - click to cast, right-click cancels" % d["name"]
		var font := ThemeDB.fallback_font
		var at := m + Vector2(-110, -d["radius"] * 0.65 - 12)
		draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, 220, 13, 4, Color.BLACK)
		draw_string(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, 220, 13, col)


## A small bolt thrower on a tower top, swinging round to face where it last shot.
func _draw_ballista(at: Vector2, side: int) -> void:
	var wood := Color(0.45, 0.28, 0.14)
	var dark := Color(0.1, 0.07, 0.1)
	var aim := Vector2(0.4 if side == 0 else -0.4, -1.0).normalized()
	for s in shows:
		if s["kind"] == "bolt" and s["from"] == at:
			aim = (s["at"] - at).normalized()
	draw_rect(Rect2(at + Vector2(-9, 2), Vector2(18, 6)), dark)
	draw_rect(Rect2(at + Vector2(-8, 3), Vector2(16, 4)), wood)
	var side_v := aim.orthogonal()
	draw_line(at - aim * 6.0, at + aim * 12.0, dark, 5.0)
	draw_line(at - aim * 6.0, at + aim * 12.0, wood, 3.0)
	draw_line(at + aim * 6.0 - side_v * 10.0, at + aim * 6.0 + side_v * 10.0, dark, 4.0)
	draw_line(at + aim * 6.0 - side_v * 9.0, at + aim * 6.0 + side_v * 9.0, wood.lightened(0.2), 2.0)
	draw_line(at + aim * 6.0 - side_v * 9.0, at - aim * 4.0, Color(0.85, 0.85, 0.8), 1.0)
	draw_line(at + aim * 6.0 + side_v * 9.0, at - aim * 4.0, Color(0.85, 0.85, 0.8), 1.0)
