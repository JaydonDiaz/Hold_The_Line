extends Control
## The title screen's backdrop: a front view of the castle under a sky of drifting
## clouds, with a pixel-art "Hold the Line" banner. Hovering a mode card changes the
## scene to match it (see LOOKS): a training session for the Tutorial, a clear sky and
## weak enemies for Easy, clouds and tougher ones for Normal, a dark sky and downed
## troops for Hard, a storm over graves for Hardcore, a twilight of conjured enemies
## for Freeplay. Pure decoration: nothing here touches the game.

const Sprites = preload("res://scripts/sprites.gd")
const Grave = preload("res://scripts/grave.gd")

const W := 640.0
const H := 1040.0
const GROUND_Y := 522.0     # the foot of the castle walls
const EARTH_Y := 604.0      # where the grass gives way to the earth the cards sit on
const ROWS := [556.0, 590.0]
const SPRITE_SCALE := 2.5
const OUTLINE := Color(0.1, 0.07, 0.1)

# Each look: sky colours, clouds (how many, their colour), sun / moon / stars,
# light on the land, lit windows, lightning, who's out front.
const LOOKS := {
	"": {"top": Color(0.36, 0.6, 0.93), "low": Color(0.78, 0.9, 1.0), "clouds": 6, "cloud": Color(1, 1, 1),
		"sun": 1.0, "moon": 0.0, "stars": 0.0, "light": Color(1, 1, 1), "windows": 0.0, "storm": 0.0,
		"guards": ["swordsman", "archer", "bard", "swordsman"], "foes": [], "scene": "idle"},
	"tutorial": {"top": Color(0.4, 0.66, 0.98), "low": Color(0.85, 0.95, 1.0), "clouds": 4, "cloud": Color(1, 1, 1),
		"sun": 1.0, "moon": 0.0, "stars": 0.0, "light": Color(1.04, 1.02, 0.96), "windows": 0.0, "storm": 0.0,
		"guards": [], "foes": [], "scene": "training"},
	"easy": {"top": Color(0.28, 0.6, 1.0), "low": Color(0.75, 0.92, 1.0), "clouds": 2, "cloud": Color(1, 1, 1),
		"sun": 1.0, "moon": 0.0, "stars": 0.0, "light": Color(1.05, 1.04, 0.98), "windows": 0.0, "storm": 0.0,
		"guards": ["swordsman", "archer", "healer"], "foes": ["goblin", "goblin", "bat"], "scene": "battle"},
	"normal": {"top": Color(0.46, 0.56, 0.68), "low": Color(0.74, 0.79, 0.84), "clouds": 13, "cloud": Color(0.86, 0.88, 0.91),
		"sun": 0.35, "moon": 0.0, "stars": 0.0, "light": Color(0.86, 0.88, 0.92), "windows": 0.0, "storm": 0.0,
		"guards": ["swordsman", "archer", "mage", "swordsman"], "foes": ["orc", "wolf", "goblin", "sapper"], "scene": "battle"},
	"hard": {"top": Color(0.1, 0.11, 0.22), "low": Color(0.3, 0.27, 0.4), "clouds": 10, "cloud": Color(0.3, 0.3, 0.4),
		"sun": 0.0, "moon": 1.0, "stars": 0.4, "light": Color(0.5, 0.52, 0.66), "windows": 1.0, "storm": 0.0,
		"guards": ["swordsman", "martial", "archer", "mage"], "foes": ["troll", "orc", "orc", "sapper"], "scene": "battle",
		"downed": ["swordsman", "archer"]},
	"hardcore": {"top": Color(0.06, 0.02, 0.05), "low": Color(0.36, 0.07, 0.07), "clouds": 15, "cloud": Color(0.2, 0.11, 0.13),
		"sun": 0.0, "moon": 1.0, "stars": 0.0, "light": Color(0.5, 0.34, 0.36), "windows": 0.7, "storm": 1.0,
		"guards": ["swordsman", "martial", "alchemist"], "foes": ["warlord", "troll", "orc"], "scene": "battle",
		"downed": ["archer"], "graves": 8},
	"freeplay": {"top": Color(0.1, 0.06, 0.28), "low": Color(0.6, 0.32, 0.58), "clouds": 4, "cloud": Color(0.56, 0.44, 0.7),
		"sun": 0.0, "moon": 0.7, "stars": 1.0, "light": Color(0.72, 0.64, 0.86), "windows": 1.0, "storm": 0.0,
		"guards": ["mage", "frost", "mage"], "foes": ["goblin", "orc", "wolf", "troll", "bat", "sapper", "warlord"], "scene": "conjure"},
}
const BOLT_COLORS := {"archer": Color(0.95, 0.9, 0.7), "mage": Color(0.75, 0.5, 1.0), "frost": Color(0.6, 0.9, 1.0),
		"alchemist": Color(0.5, 1.0, 0.4), "bard": Color(1.0, 0.85, 0.4), "healer": Color(1.0, 1.0, 0.6)}
const RANGED := ["archer", "mage", "frost", "alchemist", "bard", "healer"]
const GRAVE_SPOTS := [Vector2(392, 542), Vector2(560, 601), Vector2(20, 598), Vector2(505, 545),
		Vector2(452, 602), Vector2(128, 540), Vector2(612, 550), Vector2(168, 603)]   # Hardcore's graves, in the order they appear
const BIG := {"troll": 3.0, "warlord": 3.3, "wyvern": 3.0}

# A chunky 5x7 pixel font, just the letters the title needs.
const FONT := {
	"H": ["X...X", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"],
	"O": [".XXX.", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
	"L": ["X....", "X....", "X....", "X....", "X....", "X....", "XXXXX"],
	"D": ["XXXX.", "X...X", "X...X", "X...X", "X...X", "X...X", "XXXX."],
	"T": ["XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "..X.."],
	"E": ["XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "XXXXX"],
	"I": ["XXX", ".X.", ".X.", ".X.", ".X.", ".X.", "XXX"],
	"N": ["X...X", "XX..X", "X.X.X", "X.X.X", "X..XX", "X...X", "X...X"],
	" ": ["..", "..", "..", "..", "..", "..", ".."],
}
const TITLE := "HOLD THE LINE"
const PX := 7.0            # size of one title pixel
const TITLE_Y := 50.0

var t := 0.0
var look := ""
var cur := {}              # the look being shown, blended towards LOOKS[look]
var pending_default := -1.0
var clouds := []           # {pos, scale, speed, seed, leaving}: they drift in from the left edge and off the right
var cloud_cd := 0.0        # wait before the next cloud drifts in
var stars := []
var actors := []           # {kind, pos, side, hp, cd, lunge, hurt, alpha, leaving, home, role}
var bolts := []
var pops := []
var graves := []           # {pos, alpha, target}
var spawn_cd := 0.0
var flash := 0.0
var bolt_path := PackedVector2Array()
var storm_cd := 2.0
var title_pixels := []     # [col, row] lit pixels of the title, worked out once
var title_cols := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	cur = (LOOKS[""] as Dictionary).duplicate()
	# The first clouds are already in the sky when the screen opens.
	for i in int(LOOKS[""]["clouds"]):
		clouds.append(_new_cloud(randf_range(-100, 740)))
	for i in 60:
		stars.append(Vector2(randf_range(-300, 940), randf_range(0, 380)))
	_layout_title()
	_cast()


func _layout_title() -> void:
	var col := 0
	for ch in TITLE:
		var glyph: Array = FONT[ch]
		for r in glyph.size():
			for c in (glyph[r] as String).length():
				if glyph[r][c] == "X":
					title_pixels.append(Vector2i(col + c, r))
		col += (glyph[0] as String).length() + 1
	title_cols = col - 1


## Show the scene for a mode ("" is the plain title screen). Going back to "" waits a
## moment, so sliding from one card to the next doesn't flash the plain scene between.
func set_look(key: String) -> void:
	if key == "":
		pending_default = 0.25
		return
	pending_default = -1.0
	_apply(key)


func _apply(key: String) -> void:
	if key == look:
		return
	look = key
	_cast()


## Swap who's out front for the new look: the old cast fades away, the new fades in.
func _cast() -> void:
	for a in actors:
		a["leaving"] = true
	bolts.clear()
	var L: Dictionary = LOOKS[look]
	var guards: Array = L["guards"]
	match L["scene"]:
		"training":
			# Sparring partners and practice targets.
			_add_actor("archer", Vector2(70, ROWS[1]), "guard", "archery")
			_add_actor("target", Vector2(205, ROWS[1]), "prop")
			_add_actor("swordsman", Vector2(280, ROWS[0] + 4), "guard", "dummy")
			_add_actor("dummy", Vector2(330, ROWS[0] + 4), "prop")
			_add_actor("martial", Vector2(450, ROWS[1]), "guard", "spar")
			_add_actor("martial", Vector2(500, ROWS[1]), "guard", "spar_r")
			_add_actor("healer", Vector2(585, ROWS[0]), "guard", "idle")
		"idle":
			# Guards on watch either side of the gate.
			_add_actor(guards[0], Vector2(250, ROWS[1]), "guard", "idle")
			_add_actor(guards[1], Vector2(150, ROWS[0]), "guard", "idle")
			_add_actor(guards[2], Vector2(480, ROWS[0]), "guard", "idle")
			_add_actor(guards[3], Vector2(390, ROWS[1]), "guard", "idle_r")
		_:
			# Ranged at the back, melee in front, each with a spot of their own.
			var counts := {"ranged": 0, "melee": 0}
			for kind in guards:
				var group := "ranged" if kind in RANGED else "melee"
				var n: int = counts[group]
				counts[group] = n + 1
				var x: float = (55.0 if group == "ranged" else 195.0) + n * 52.0 + randf_range(-5, 5)
				_add_actor(kind, Vector2(x, ROWS[n % 2]), "guard", "fight")
	for i in (L.get("downed", []) as Array).size():
		# Fallen out on the enemies' side of the field, where the fighting was.
		_add_actor(L["downed"][i], Vector2(430 + i * 110, ROWS[i % 2] + 8), "downed")
	# Graves come and go with Hardcore.
	var want: int = L.get("graves", 0)
	if graves.is_empty():
		# Scattered, not in a row: most out where the enemies come from, a few among the troops.
		for spot in GRAVE_SPOTS:
			graves.append({"pos": spot + Vector2(randf_range(-8, 8), randf_range(-2, 2)), "alpha": 0.0})
	for i in graves.size():
		graves[i]["target"] = 1.0 if i < want else 0.0
	spawn_cd = 0.3


func _add_actor(kind: String, at: Vector2, side: String, role := "") -> void:
	actors.append({"kind": kind, "pos": at, "home": at, "side": side, "role": role, "hp": 3, "cd": randf_range(0.2, 1.0),
			"lunge": 0.0, "hurt": 0.0, "alpha": 0.0, "leaving": false, "id": randi()})


func _spawn_foe() -> void:
	var L: Dictionary = LOOKS[look]
	var foes: Array = L["foes"]
	if foes.is_empty():
		return
	var kind: String = foes[randi() % foes.size()]
	var row: float = ROWS[randi() % 2]
	var at := Vector2(700, row)
	if L["scene"] == "conjure":
		# Freeplay: enemies appear out of a magic circle wherever you like.
		at = Vector2(randf_range(360, 600), row)
		pops.append({"pos": at, "age": 0.0, "color": Color(0.8, 0.5, 1.0), "ring": true})
	_add_actor(kind, at, "foe")
	var a: Dictionary = actors[-1]
	a["hp"] = {"troll": 6, "warlord": 9, "orc": 4}.get(kind, 2)
	a["speed"] = {"wolf": 70.0, "bat": 50.0, "troll": 20.0, "warlord": 18.0}.get(kind, 34.0)


func _process(delta: float) -> void:
	t += delta
	if pending_default >= 0.0:
		pending_default -= delta
		if pending_default < 0.0:
			_apply("")
	_blend(delta)
	_drift_clouds(delta)
	for g in graves:
		g["alpha"] = move_toward(g["alpha"], g["target"], delta * 2.0)
	# Lightning in the storm.
	flash = maxf(flash - delta * 2.5, 0.0)
	if LOOKS[look]["storm"] > 0.0:
		storm_cd -= delta
		if storm_cd <= 0.0:
			storm_cd = randf_range(2.0, 4.5)
			flash = 1.0
			bolt_path = PackedVector2Array()
			var p := Vector2(randf_range(40, 600), 0)
			while p.y < 360.0:
				bolt_path.append(p)
				p += Vector2(randf_range(-30, 30), randf_range(30, 60))
			bolt_path.append(p)
	_update_actors(delta)
	queue_redraw()


## The visible part of the scene across: wider than 640 on a wide window.
func _view_x() -> Vector2:
	var inv := get_global_transform_with_canvas().affine_inverse()
	return Vector2((inv * Vector2.ZERO).x, (inv * Vector2(get_viewport_rect().size.x, 0)).x)


func _new_cloud(x: float) -> Dictionary:
	return {"pos": Vector2(x, randf_range(20, 330)), "scale": randf_range(0.7, 1.6), "speed": randf_range(12, 24),
			"seed": randi(), "leaving": false}


## Clouds never pop in or out: a look that wants more lets new ones drift in from the
## left edge, one that wants fewer lets the extras sail off the right edge.
func _drift_clouds(delta: float) -> void:
	var view := _view_x()
	var want: int = LOOKS[look]["clouds"]
	var staying := clouds.filter(func(c): return not c["leaving"])
	for i in range(staying.size() - 1, want - 1, -1):
		staying[i]["leaving"] = true
	cloud_cd -= delta
	if staying.size() < want and cloud_cd <= 0.0:
		cloud_cd = randf_range(0.6, 1.4)
		var c := _new_cloud(0.0)
		c["pos"] = Vector2(view.x - 160.0 * c["scale"], c["pos"].y)   # wholly out of sight to start with
		clouds.append(c)
	var gust: float = 1.0 + cur["storm"] * 1.5
	for c in clouds.duplicate():
		c["pos"] = c["pos"] + Vector2(c["speed"] * delta * gust, 0)
		if c["pos"].x - 160.0 * c["scale"] > view.y:
			clouds.erase(c)   # off the right edge (a staying cloud is replaced by one drifting in)


## Ease the colours and numbers of the scene towards the look being shown.
func _blend(delta: float) -> void:
	var k := 1.0 - exp(-delta * 5.0)
	var target: Dictionary = LOOKS[look]
	for key in ["top", "low", "cloud", "light"]:
		cur[key] = (cur[key] as Color).lerp(target[key], k)
	for key in ["sun", "moon", "stars", "windows", "storm"]:
		cur[key] = lerpf(cur[key], target[key], k)


func _update_actors(delta: float) -> void:
	var scene: String = LOOKS[look]["scene"]
	if scene == "battle" or scene == "conjure":
		spawn_cd -= delta
		var foes := actors.filter(func(a): return a["side"] == "foe" and not a["leaving"])
		if spawn_cd <= 0.0 and foes.size() < 5:
			spawn_cd = randf_range(0.9, 1.8)
			_spawn_foe()
	for a in actors.duplicate():
		a["alpha"] = move_toward(a["alpha"], 0.0 if a["leaving"] else 1.0, delta * 3.0)
		if a["leaving"] and a["alpha"] <= 0.0:
			actors.erase(a)
			continue
		a["lunge"] = maxf(a["lunge"] - delta, 0.0)
		a["hurt"] = maxf(a["hurt"] - delta, 0.0)
		a["cd"] -= delta
		if a["leaving"]:
			continue
		match a["side"]:
			"foe":
				_foe_step(a, delta)
			"guard":
				_guard_step(a)
	for b in bolts.duplicate():
		b["at"] += delta * 400.0 / maxf(b["len"], 1.0)
		if b["at"] >= 1.0:
			bolts.erase(b)
			var hit = _actor_by_id(b["target"])
			if hit != null:
				_hit(hit, b["color"])
	for p in pops.duplicate():
		p["age"] += delta
		if p["age"] > 0.5:
			pops.erase(p)


func _foe_step(a: Dictionary, delta: float) -> void:
	var g = _nearest(a, "guard")
	var stop := 230.0
	if g != null and not g["kind"] in RANGED:
		stop = g["pos"].x + 34.0
	if a["pos"].x > stop:
		a["pos"] = a["pos"] + Vector2(-a.get("speed", 34.0) * delta, 0)
	elif a["cd"] <= 0.0 and g != null:
		a["cd"] = 0.8
		a["lunge"] = 0.3
		g["lunge"] = 0.2
		_hit(a, Color(1, 1, 0.85))


func _guard_step(a: Dictionary) -> void:
	if a["cd"] > 0.0:
		return
	match a["role"]:
		"archery":
			a["cd"] = 1.1
			_shoot(a, _prop("target"))
		"dummy":
			a["cd"] = 0.7
			a["lunge"] = 0.25
			var d = _prop("dummy")
			if d != null:
				d["hurt"] = 0.25   # the dummy wobbles
		"spar", "spar_r":
			a["cd"] = 0.9
			a["lunge"] = 0.3
		"fight":
			if a["kind"] in RANGED:
				var e = _nearest(a, "foe")
				if e != null and e["pos"].x < 640.0:
					a["cd"] = randf_range(0.9, 1.4)
					if a["kind"] == "healer":
						a["lunge"] = 0.15
					else:
						_shoot(a, e)


func _shoot(a: Dictionary, target) -> void:
	if target == null:
		return
	a["lunge"] = 0.15
	var from: Vector2 = a["pos"] + Vector2(14, -18)
	bolts.append({"from": from, "target": target["id"], "at": 0.0, "color": BOLT_COLORS.get(a["kind"], Color.WHITE),
			"len": from.distance_to(target["pos"])})


func _hit(a: Dictionary, color: Color) -> void:
	a["hurt"] = 0.15
	if a["side"] != "foe":
		return
	a["hp"] -= 1
	if a["hp"] <= 0:
		actors.erase(a)
		pops.append({"pos": a["pos"] + Vector2(0, -16), "age": 0.0, "color": color, "ring": false})


func _actor_by_id(id: int) -> Variant:
	for a in actors:
		if a["id"] == id and not a["leaving"]:
			return a
	return null


func _prop(kind: String) -> Variant:
	for a in actors:
		if a["kind"] == kind and not a["leaving"]:
			return a
	return null


func _nearest(a: Dictionary, side: String) -> Variant:
	var best = null
	for b in actors:
		if b["side"] != side or b["leaving"]:
			continue
		if best == null or a["pos"].distance_squared_to(b["pos"]) < a["pos"].distance_squared_to(best["pos"]):
			best = b
	return best


# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	var light: Color = cur["light"]
	_draw_sky()
	_draw_hills(light)
	_draw_castle(light)
	_draw_ground(light)
	_draw_actors(light)
	for b in bolts:
		var target = _actor_by_id(b["target"])
		if target == null:
			continue
		var p: Vector2 = b["from"].lerp(target["pos"] + Vector2(0, -16), b["at"])
		draw_circle(p, 4.5, Color(b["color"], 0.35))
		draw_circle(p, 2.5, b["color"])
	for p in pops:
		var k: float = p["age"] / 0.5
		if p["ring"]:
			draw_arc(p["pos"] + Vector2(0, 12), 10.0 + 18.0 * k, 0, TAU, 24, Color(p["color"], 1.0 - k), 3.0, true)
			continue
		for i in 8:
			var d := Vector2.from_angle(i * TAU / 8.0) * (6.0 + 24.0 * k)
			draw_circle(p["pos"] + d, 3.0 * (1.0 - k), Color(p["color"], 1.0 - k))
	if flash > 0.0:
		draw_rect(Rect2(-1000, -1000, W + 2000, EARTH_Y + 1000), Color(1, 0.95, 1.0, 0.25 * flash))
		if bolt_path.size() > 1:
			draw_polyline(bolt_path, Color(1, 1, 1, flash), 3.0)
	_draw_title()


func _draw_sky() -> void:
	var top: Color = cur["top"]
	var low: Color = cur["low"]
	var bands := 24
	for i in bands:
		var y0 := -1000.0 if i == 0 else 470.0 * i / bands
		var y1 := 470.0 * (i + 1) / bands
		draw_rect(Rect2(-1000, y0, W + 2000, y1 - y0 + 1.0), top.lerp(low, float(i) / (bands - 1)))
	draw_rect(Rect2(-1000, 470, W + 2000, 60), low)
	if cur["stars"] > 0.01:
		for i in stars.size():
			var tw := 0.6 + 0.4 * sin(t * 2.0 + i * 1.7)
			draw_rect(Rect2(stars[i], Vector2(2, 2)), Color(1, 1, 0.9, cur["stars"] * tw))
	if cur["sun"] > 0.01:
		var sp := Vector2(548, 200)
		draw_circle(sp, 46.0, Color(1, 0.95, 0.6, 0.18 * cur["sun"]))
		draw_circle(sp, 32.0, Color(1, 0.92, 0.5, cur["sun"]))
		draw_circle(sp, 26.0, Color(1, 0.98, 0.75, cur["sun"]))
	if cur["moon"] > 0.01:
		var mp := Vector2(92, 196)
		var mc := Color(0.95, 0.93, 0.82).lerp(Color(1.0, 0.45, 0.35), cur["storm"])
		draw_circle(mp, 40.0, Color(mc, 0.15 * cur["moon"]))
		draw_circle(mp, 26.0, Color(mc, cur["moon"]))
		draw_circle(mp + Vector2(-8, -5), 5.0, Color(mc.darkened(0.15), cur["moon"]))
		draw_circle(mp + Vector2(7, 8), 3.5, Color(mc.darkened(0.15), cur["moon"]))
	for c in clouds:
		_draw_cloud(c["pos"], c["scale"], c["seed"], cur["cloud"])


## A puffy pixel cloud: overlapping lumps on a flat base, shaded underneath.
func _draw_cloud(at: Vector2, s: float, seed_: int, col: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var lumps := 4 + rng.randi() % 3
	var shade := Color(col.darkened(0.18), col.a)
	for pass_ in 2:
		for i in lumps:
			var x := (i - (lumps - 1) / 2.0) * 22.0 * s
			var r := (16.0 + rng.randf() * 12.0) * s
			var y := -r * 0.35
			if pass_ == 0:
				draw_circle(at + Vector2(x, y + 5 * s), r, shade)
			else:
				draw_circle(at + Vector2(x, y), r * 0.92, col)
		rng.seed = seed_
		rng.randi()


func _draw_hills(light: Color) -> void:
	var far := Color(0.42, 0.58, 0.5) * light
	var near := Color(0.32, 0.5, 0.3) * light
	for layer in 2:
		var pts := PackedVector2Array()
		var base: float = 430.0 + layer * 40.0
		pts.append(Vector2(-1000, GROUND_Y + 10))
		var x := -1000.0
		while x <= W + 1000.0:
			pts.append(Vector2(x, base - (sin(x * 0.011 + layer * 2.0) * 22.0 + sin(x * 0.027 + layer) * 10.0)))
			x += 20.0
		pts.append(Vector2(W + 1000, GROUND_Y + 10))
		draw_colored_polygon(pts, far if layer == 0 else near)


## The castle seen from the front, as detailed pixel art: a keep behind with a corner
## turret, a gatehouse with a carved arch, portcullis, doors and torches, curtain walls
## with guards walking the battlements, and two round towers with overhanging
## battlements, shingled roofs, banners and flags. Lit from the top left; windows
## glow at night (the look's "windows").
func _draw_castle(light: Color) -> void:
	var stone := Color(0.66, 0.64, 0.6)
	var dark := Color(0.5, 0.48, 0.47)
	var deep := Color(0.4, 0.38, 0.4)
	var roof := Color(0.6, 0.2, 0.2)
	var glow: float = cur["windows"]
	# A shadow on the grass along the foot.
	draw_rect(Rect2(76, GROUND_Y - 2, 488, 10), Color(0, 0, 0, 0.22))
	# A tall tower in the middle, behind the keep, rising over its battlements.
	var spire := Rect2(302, 212, 36, 60)
	_stones(spire, deep.darkened(0.08), light, 2)
	_round_shade(spire, light)
	_corbels(298, 342, 212, deep, light)
	_cone(320.0, 212.0, 24.0, 32.0, roof, light)
	_slit(Vector2(320, 228), light, glow)
	# The keep, in front of it.
	_stones(Rect2(258, 252, 124, 180), deep, light, 1)
	_shade(Rect2(258, 252, 124, 180), light, 0.18)
	_corbels(258, 382, 252, deep, light)
	_crenels(254, 386, 240, deep, light)
	_arch_window(Vector2(292, 300), 12, 22, glow, light)
	_arch_window(Vector2(348, 300), 12, 22, glow, light)
	_arch_window(Vector2(320, 352), 14, 26, glow, light)
	_flag(Vector2(374, 200), 28.0, Color(0.85, 0.2, 0.2) * light)
	# Guards walking the battlements, behind the parapet.
	for i in 2:
		var span := 36.0
		var x: float = (198.0 if i == 0 else 442.0) + sin(t * 0.35 + i * 2.0) * span
		var dir := signf(cos(t * 0.35 + i * 2.0))
		var tex: Texture2D = Sprites.frames("archer" if i == 0 else "swordsman")[int(t * 4.0) % 2]
		draw_set_transform(Vector2(x, 392), 0, Vector2(dir * 1.6, 1.6))
		draw_texture_rect(tex, Rect2(Vector2(-8, -16), Vector2(16, 16)), false, Color(light, 1))
		draw_set_transform(Vector2.ZERO)
	# Curtain walls.
	for r in [Rect2(150, 398, 100, GROUND_Y - 398), Rect2(390, 398, 100, GROUND_Y - 398)]:
		_stones(r, dark, light, 3)
		_crenels(r.position.x - 2, r.end.x + 2, r.position.y - 12, dark, light)
		_plinth(r, dark, light)
		for k in 2:
			_slit(Vector2(r.position.x + 30 + k * 40, 452), light, glow)
	_ivy(Vector2(162, 470), 3, light)
	_ivy(Vector2(470, 486), 2, light)
	# Towers: round, so shaded across, with banners hanging down their fronts.
	for tx in [88.0, 468.0]:
		var body := Rect2(tx, 330, 84, GROUND_Y - 330)
		_stones(body, stone, light, 4 + int(tx))
		_round_shade(body, light)
		_plinth(body, stone, light)
		_corbels(tx - 6, tx + 90, 330, stone, light)
		_crenels(tx - 8, tx + 92, 318, stone, light)
		_cone(tx + 42.0, 318.0, 50.0, 78.0, roof, light)
		_flag(Vector2(tx + 42, 222), 18.0, Color(0.95, 0.8, 0.25) * light)
		_hanging_banner(Vector2(tx + 42, 344), light, tx < 300.0)
		_arch_window(Vector2(tx + 42, 430), 10, 18, glow, light)
		_slit(Vector2(tx + 42, 480), light, glow)
	_ivy(Vector2(100, 500), 2, light)
	# Gatehouse.
	var gh := Rect2(246, 350, 148, GROUND_Y - 350)
	_stones(gh, stone, light, 9)
	_shade(gh, light, 0.08)
	_plinth(gh, stone, light)
	_corbels(240, 400, 350, stone, light)
	_crenels(238, 402, 338, stone, light)
	_gate(Vector2(320, 450), light)
	for side in [-1.0, 1.0]:
		_torch(Vector2(320 + side * 62.0, 444), light, glow)
	# The crest over the gate.
	var wave := sin(t * 2.0) * 2.0
	var banner := PackedVector2Array([Vector2(302, 362), Vector2(338, 362), Vector2(338 + wave, 392), Vector2(320, 385), Vector2(302 + wave, 392)])
	draw_colored_polygon(banner, Color(0.72, 0.16, 0.16) * light)
	draw_polyline(banner + PackedVector2Array([banner[0]]), OUTLINE, 2.0)
	draw_rect(Rect2(300, 359, 40, 4), Color(0.45, 0.3, 0.15) * light)
	_crest(Vector2(320, 374), light)


## Deterministic jitter for a block, so the stonework doesn't shimmer frame to frame.
static func _rand(x: float, y: float, s: int) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233 + s * 3.7) * 43758.5453, 1.0)


## Coursed stone: blocks a little different in tone, light along their tops and dark
## mortar between, rows staggered.
func _stones(r: Rect2, col: Color, light: Color, s: int) -> void:
	var mortar := col.darkened(0.42) * light
	draw_rect(r.grow(2), OUTLINE)
	draw_rect(r, mortar)
	var bh := 10.0
	var row := 0
	var y := r.position.y
	while y < r.end.y:
		var h := minf(bh, r.end.y - y)
		var bw: float = 20.0
		var x: float = r.position.x - (10.0 if row % 2 == 1 else 0.0)
		while x < r.end.x:
			var x0 := maxf(x, r.position.x)
			var x1 := minf(x + bw, r.end.x)
			if x1 - x0 > 1.5:
				var k := _rand(x, y, s)
				var c := col.lerp(col.lightened(0.12) if k > 0.5 else col.darkened(0.12), absf(k - 0.5) * 1.6) * light
				var b := Rect2(x0 + (0.0 if x0 == r.position.x else 1.0), y + 1.0, x1 - x0 - 1.0, h - 1.0)
				draw_rect(b, c)
				draw_rect(Rect2(b.position, Vector2(b.size.x, 1.0)), c.lightened(0.18))
				if k > 0.86:
					# A chipped or cracked stone here and there.
					draw_line(b.position + Vector2(b.size.x * 0.3, 2), b.position + Vector2(b.size.x * 0.5, b.size.y - 1), mortar, 1.0)
			x += bw
		y += bh
		row += 1


## A flat wall's shading: darker towards the right, away from the light.
func _shade(r: Rect2, _light: Color, amount: float) -> void:
	var bands := 6
	for i in bands:
		var k := float(i) / bands
		if k < 0.5:
			continue
		draw_rect(Rect2(r.position.x + r.size.x * k, r.position.y, r.size.x / bands + 1.0, r.size.y), Color(0, 0, 0, amount * (k - 0.5) * 2.0))


## A round tower's shading: a lit stripe on the left, deepening shadow round the right.
func _round_shade(r: Rect2, _light: Color) -> void:
	var bands := 10
	for i in bands:
		var k := (i + 0.5) / bands
		var w := r.size.x / bands
		var x := r.position.x + i * w
		if k < 0.3:
			draw_rect(Rect2(x, r.position.y, w + 0.5, r.size.y), Color(1, 1, 0.9, 0.1 * (1.0 - k / 0.3)))
		elif k > 0.55:
			draw_rect(Rect2(x, r.position.y, w + 0.5, r.size.y), Color(0, 0, 0, 0.32 * (k - 0.55) / 0.45))


## Larger, darker foundation stones along the bottom.
func _plinth(r: Rect2, col: Color, light: Color) -> void:
	var base := Rect2(r.position.x - 3, r.end.y - 12, r.size.x + 6, 12)
	draw_rect(base.grow(1.5), OUTLINE)
	draw_rect(base, col.darkened(0.3) * light)
	draw_line(base.position + Vector2(0, 1), Vector2(base.end.x, base.position.y + 1), col.darkened(0.1) * light, 1.0)
	var x := base.position.x + 14.0
	while x < base.end.x:
		draw_line(Vector2(x, base.position.y + 2), Vector2(x, base.end.y), col.darkened(0.5) * light, 1.0)
		x += 28.0


## Stone brackets under an overhanging parapet, with dark gaps between.
func _corbels(x0: float, x1: float, y: float, col: Color, light: Color) -> void:
	draw_rect(Rect2(x0, y - 4, x1 - x0, 5).grow(1), OUTLINE)
	draw_rect(Rect2(x0, y - 4, x1 - x0, 5), col.darkened(0.1) * light)
	var x := x0 + 3.0
	while x < x1 - 6.0:
		draw_rect(Rect2(x, y + 1, 6, 6), OUTLINE)
		draw_rect(Rect2(x + 1, y + 1, 4, 4), col.darkened(0.2) * light)
		x += 10.0


## Battlements: a parapet band with merlons, each lit on top and shaded on its right.
func _crenels(x0: float, x1: float, y: float, col: Color, light: Color) -> void:
	var c := col * light
	draw_rect(Rect2(x0, y + 8, x1 - x0, 6).grow(1.5), OUTLINE)
	draw_rect(Rect2(x0, y + 8, x1 - x0, 6), c)
	var n := maxi(2, int((x1 - x0) / 17.0))
	var w := (x1 - x0) / n
	for i in n:
		var m := Rect2(x0 + i * w + 2.0, y - 2, w - 6.0, 10)
		draw_rect(m.grow(1.5), OUTLINE)
		draw_rect(m, c)
		draw_rect(Rect2(m.position, Vector2(m.size.x, 2)), c.lightened(0.2))
		draw_rect(Rect2(m.end.x - 2, m.position.y, 2, m.size.y), c.darkened(0.2))


## A tall pointed roof of overlapping shingles, lit on the left, with a gold finial.
func _cone(cx: float, base_y: float, half_w: float, h: float, col: Color, light: Color) -> void:
	var apex := Vector2(cx, base_y - h)
	var l := Vector2(cx - half_w, base_y)
	var r := Vector2(cx + half_w, base_y)
	draw_colored_polygon(PackedVector2Array([l + Vector2(-3, 2), r + Vector2(3, 2), apex + Vector2(0, -4)]), OUTLINE)
	draw_colored_polygon(PackedVector2Array([l, Vector2(cx, base_y), apex]), col.lightened(0.08) * light)
	draw_colored_polygon(PackedVector2Array([Vector2(cx, base_y), r, apex]), col.darkened(0.22) * light)
	# Rows of shingles: a seam across each row, with staggered scallops.
	var rows := int(h / 7.0)
	for i in range(1, rows):
		var k := float(i) / rows
		var y := base_y - h * (1.0 - k)
		var hw := half_w * k
		var seam := col.darkened(0.4) * light
		draw_line(Vector2(cx - hw, y), Vector2(cx + hw, y), seam, 1.0)
		var step := 6.0
		var x := cx - hw + (step / 2.0 if i % 2 == 1 else 0.0)
		while x < cx + hw - 1.0:
			draw_line(Vector2(x, y - 4), Vector2(x, y), seam, 1.0)
			x += step
	draw_line(l, r, OUTLINE, 3.0)
	draw_line(apex, apex + Vector2(0, -10), OUTLINE, 2.0)
	draw_circle(apex + Vector2(0, -4), 3.0, OUTLINE)
	draw_circle(apex + Vector2(0, -4), 2.0, Color(1.0, 0.82, 0.3) * light)


## An arched window in a stone frame, with a cross of leading; dark by day, lamplit at night.
func _arch_window(c: Vector2, w: float, h: float, glow: float, light: Color) -> void:
	var frame := Color(0.78, 0.76, 0.72) * light
	var inside := Color(0.08, 0.07, 0.1).lerp(Color(1.0, 0.78, 0.35), glow * (0.85 + 0.15 * sin(t * 3.0 + c.x)))
	var top := c.y - h / 2.0 + w / 2.0
	draw_rect(Rect2(c.x - w / 2.0 - 3, top, w + 6, h / 2.0 + w / 2.0 + 3), OUTLINE)
	draw_circle(Vector2(c.x, top), w / 2.0 + 3, OUTLINE)
	draw_rect(Rect2(c.x - w / 2.0 - 2, top, w + 4, h / 2.0 + w / 2.0 + 2), frame)
	draw_circle(Vector2(c.x, top), w / 2.0 + 2, frame)
	draw_rect(Rect2(c.x - w / 2.0, top, w, h / 2.0 + w / 2.0), inside)
	draw_circle(Vector2(c.x, top), w / 2.0, inside)
	draw_line(Vector2(c.x, top - w / 2.0), Vector2(c.x, c.y + h / 2.0), OUTLINE, 1.5)
	draw_line(Vector2(c.x - w / 2.0, top + 3), Vector2(c.x + w / 2.0, top + 3), OUTLINE, 1.5)
	draw_rect(Rect2(c.x - w / 2.0 - 4, c.y + h / 2.0, w + 8, 3), frame.darkened(0.1))   # sill
	if glow > 0.05:
		draw_circle(c, w * 1.4, Color(1.0, 0.8, 0.4, 0.08 * glow))


## An arrow slit with a widened base.
func _slit(c: Vector2, light: Color, glow: float) -> void:
	var inside := Color(0.08, 0.07, 0.1).lerp(Color(1.0, 0.75, 0.3), glow * 0.7)
	draw_rect(Rect2(c.x - 3, c.y - 11, 6, 22), Color(0.75, 0.73, 0.7) * light)
	draw_rect(Rect2(c.x - 1.5, c.y - 10, 3, 20), inside)
	draw_rect(Rect2(c.x - 4, c.y - 1.5, 8, 3), inside)


## The gate: a ring of wedge-shaped stones round the arch with a keystone at the top,
## oak doors with iron straps in the opening, and the portcullis down in front.
func _gate(c: Vector2, light: Color) -> void:
	var r_in := 36.0
	var r_out := 47.0
	var stones := 11
	for i in stones:
		var a0 := PI + PI * i / stones
		var a1 := PI + PI * (i + 1) / stones
		var pts := PackedVector2Array([c + Vector2.from_angle(a0) * r_in, c + Vector2.from_angle(a0) * r_out,
				c + Vector2.from_angle(a1) * r_out, c + Vector2.from_angle(a1) * r_in])
		var key := i == stones / 2
		var col := Color(0.8, 0.78, 0.72) if key else (Color(0.7, 0.68, 0.64) if i % 2 == 0 else Color(0.62, 0.6, 0.57))
		draw_colored_polygon(pts, col * light)
		draw_polyline(pts + PackedVector2Array([pts[0]]), OUTLINE, 1.5)
	# Jambs down to the ground.
	for side in [-1.0, 1.0]:
		var jx: float = c.x + side * (r_in + 5.5)
		draw_rect(Rect2(jx - 5.5, c.y, 11, GROUND_Y - c.y).grow(1), OUTLINE)
		draw_rect(Rect2(jx - 5.5, c.y, 11, GROUND_Y - c.y), Color(0.7, 0.68, 0.64) * light)
		for y in range(int(c.y) + 12, int(GROUND_Y), 12):
			draw_line(Vector2(jx - 5.5, y), Vector2(jx + 5.5, y), OUTLINE, 1.0)
	# The opening, the doors and the portcullis.
	var hole := PackedVector2Array()
	for i in 25:
		hole.append(c + Vector2.from_angle(PI + PI * i / 24.0) * r_in)
	hole.append(Vector2(c.x + r_in, GROUND_Y))
	hole.append(Vector2(c.x - r_in, GROUND_Y))
	draw_colored_polygon(hole, Color(0.1, 0.07, 0.06))
	var oak := Color(0.46, 0.3, 0.17) * light
	for i in 7:
		var x0 := c.x - r_in + 4 + i * 9.7
		var top := c.y - sqrt(maxf(0.0, r_in * r_in - pow(x0 + 4.5 - c.x, 2))) + 6.0
		draw_rect(Rect2(x0, top, 8.5, GROUND_Y - top), oak if i % 2 == 0 else oak.darkened(0.12))
	draw_line(Vector2(c.x, c.y - r_in + 6), Vector2(c.x, GROUND_Y), OUTLINE, 2.0)
	for y in [c.y + 6.0, c.y + 44.0]:
		draw_line(Vector2(c.x - r_in + 4, y), Vector2(c.x + r_in - 4, y), Color(0.3, 0.3, 0.34) * light, 3.0)
	draw_circle(Vector2(c.x - 6, c.y + 26), 2.0, Color(0.75, 0.7, 0.5) * light)
	draw_circle(Vector2(c.x + 6, c.y + 26), 2.0, Color(0.75, 0.7, 0.5) * light)
	var iron := Color(0.24, 0.24, 0.27) * light
	for i in 7:
		var gx := c.x - r_in + 6 + i * 10.0
		var top := c.y - sqrt(maxf(0.0, r_in * r_in - pow(gx - c.x, 2)))
		draw_line(Vector2(gx, top), Vector2(gx, GROUND_Y - 4), OUTLINE, 3.5)
		draw_line(Vector2(gx, top), Vector2(gx, GROUND_Y - 4), iron.lightened(0.15), 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(gx - 2.5, GROUND_Y - 5), Vector2(gx + 2.5, GROUND_Y - 5), Vector2(gx, GROUND_Y)]), iron)
	for gy in [c.y - 16.0, c.y + 10.0, c.y + 36.0, c.y + 60.0]:
		draw_line(Vector2(c.x - r_in + 2, gy), Vector2(c.x + r_in - 2, gy), OUTLINE, 3.5)
		draw_line(Vector2(c.x - r_in + 2, gy), Vector2(c.x + r_in - 2, gy), iron.lightened(0.15), 1.5)


## A torch in an iron bracket, flickering, with a pool of light round it at night.
func _torch(at: Vector2, light: Color, glow: float) -> void:
	var f := 0.8 + 0.2 * sin(t * 13.0 + at.x) * sin(t * 7.3)
	draw_circle(at + Vector2(0, -8), 26.0 * f, Color(1.0, 0.65, 0.25, 0.08 + 0.14 * glow))
	draw_rect(Rect2(at.x - 4, at.y + 2, 8, 3), OUTLINE)
	draw_rect(Rect2(at.x - 2, at.y - 6, 4, 10), OUTLINE)
	draw_rect(Rect2(at.x - 1, at.y - 5, 2, 8), Color(0.45, 0.3, 0.15) * light)
	var flame := PackedVector2Array([at + Vector2(-4, -6), at + Vector2(4, -6), at + Vector2(sin(t * 9.0) * 2.0, -16 - 3 * f)])
	draw_colored_polygon(flame, Color(1.0, 0.55, 0.15))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-2, -6), at + Vector2(2, -6), at + Vector2(sin(t * 9.0), -12 - 2 * f)]), Color(1.0, 0.9, 0.45))


## A long banner hanging down a tower, its tail swaying.
func _hanging_banner(top: Vector2, light: Color, blue: bool) -> void:
	var cloth := (Color(0.25, 0.38, 0.75) if blue else Color(0.72, 0.18, 0.18)) * light
	var sway := sin(t * 1.6 + top.x) * 1.5
	var pts := PackedVector2Array([top + Vector2(-11, 0), top + Vector2(11, 0), top + Vector2(11 + sway, 50),
			top + Vector2(sway, 42), top + Vector2(-11 + sway, 50)])
	draw_rect(Rect2(top + Vector2(-14, -3), Vector2(28, 4)), Color(0.4, 0.28, 0.14) * light)
	draw_colored_polygon(pts, cloth)
	draw_colored_polygon(PackedVector2Array([top + Vector2(5, 0), top + Vector2(11, 0), top + Vector2(11 + sway, 50), top + Vector2(5 + sway, 45)]), cloth.darkened(0.2))
	draw_polyline(pts + PackedVector2Array([pts[0]]), OUTLINE, 1.5)
	draw_line(top + Vector2(-8, 4), top + Vector2(8, 4), Color(1.0, 0.82, 0.3) * light, 1.5)
	# A sword picked out in gold.
	draw_line(top + Vector2(0, 10), top + Vector2(sway * 0.5, 34), Color(1.0, 0.85, 0.35) * light, 2.0)
	draw_line(top + Vector2(-5, 15), top + Vector2(5, 15), Color(1.0, 0.85, 0.35) * light, 2.0)


## The gold shield on the gate banner.
func _crest(c: Vector2, light: Color) -> void:
	var gold := Color(1.0, 0.82, 0.3) * light
	var pts := PackedVector2Array([c + Vector2(-6, -6), c + Vector2(6, -6), c + Vector2(6, 1), c + Vector2(0, 7), c + Vector2(-6, 1)])
	draw_colored_polygon(pts, gold)
	draw_polyline(pts + PackedVector2Array([pts[0]]), OUTLINE, 1.0)
	draw_line(c + Vector2(0, -5), c + Vector2(0, 5), Color(0.72, 0.16, 0.16) * light, 1.5)


## A clump of ivy creeping up the stones.
func _ivy(at: Vector2, size: int, light: Color) -> void:
	for i in size * 7:
		var p := at + Vector2(_rand(i, size, 1) * 20.0 * size - 10.0 * size, -_rand(i, size, 2) * 18.0 * size)
		var c := Color(0.22, 0.42, 0.18) if i % 3 else Color(0.32, 0.55, 0.24)
		draw_rect(Rect2(p, Vector2(4, 3)), c * light)
		draw_rect(Rect2(p + Vector2(1, 3), Vector2(1, 2)), Color(0.18, 0.3, 0.14) * light)


## A pennant on a pole, rippling.
func _flag(top: Vector2, h: float, col: Color) -> void:
	draw_line(top, top + Vector2(0, h + 12), OUTLINE, 3.0)
	var pts := PackedVector2Array()
	for i in 7:
		var x := i * 5.0
		pts.append(top + Vector2(x, sin(t * 4.0 - i * 0.8) * 2.5 * i / 6.0))
	for i in range(6, -1, -1):
		var x := i * 5.0
		pts.append(top + Vector2(x, 16 + sin(t * 4.0 - i * 0.8) * 2.5 * i / 6.0))
	draw_colored_polygon(pts, col)
	draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[2], pts[11], pts[12], pts[13]]), col.lightened(0.15))
	draw_polyline(pts + PackedVector2Array([pts[0]]), OUTLINE, 1.5)


func _draw_ground(light: Color) -> void:
	draw_rect(Rect2(-1000, GROUND_Y, W + 2000, EARTH_Y - GROUND_Y), Color(0.33, 0.56, 0.26) * light)
	draw_rect(Rect2(-1000, GROUND_Y, W + 2000, 3), Color(0.25, 0.42, 0.2) * light)
	# A dirt road from the gate.
	draw_colored_polygon(PackedVector2Array([Vector2(286, GROUND_Y), Vector2(354, GROUND_Y), Vector2(400, EARTH_Y), Vector2(240, EARTH_Y)]),
			Color(0.6, 0.47, 0.3) * light)
	# Tufts of grass.
	for i in 40:
		var x := fmod(i * 97.3, W + 200.0) - 100.0
		var y := GROUND_Y + 8.0 + fmod(i * 37.1, EARTH_Y - GROUND_Y - 16.0)
		draw_line(Vector2(x, y), Vector2(x - 2, y - 5), Color(0.24, 0.44, 0.2) * light, 1.5)
		draw_line(Vector2(x, y), Vector2(x + 2, y - 5), Color(0.24, 0.44, 0.2) * light, 1.5)
	# The earth below, where the cards sit.
	draw_rect(Rect2(-1000, EARTH_Y, W + 2000, H - EARTH_Y + 1000), Color(0.2, 0.14, 0.1) * light)
	draw_rect(Rect2(-1000, EARTH_Y, W + 2000, 6), Color(0.27, 0.4, 0.18) * light)
	for i in 50:
		var p := Vector2(fmod(i * 131.7, W + 160.0) - 80.0, EARTH_Y + 18.0 + fmod(i * 71.3, H - EARTH_Y - 20.0))
		draw_circle(p, 3.0 + (i % 3), Color(0.28, 0.21, 0.16) * light)


func _draw_actors(light: Color) -> void:
	# Graves are sorted in with everyone else, so whoever stands nearer is drawn in front.
	var order := actors.duplicate()
	for g in graves:
		if g["alpha"] > 0.01:
			order.append({"kind": "grave", "pos": g["pos"], "alpha": g["alpha"]})
	order.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)
	for a in order:
		var alpha: float = a["alpha"]
		if alpha <= 0.01:
			continue
		var kind: String = a["kind"]
		var p: Vector2 = a["pos"]
		if kind == "grave":
			# Tombstones rise out of the ground as Hardcore comes in.
			Grave.draw_tombstone(self, p, 1.6 * alpha, Color(0.55, 0.1, 0.1))
			continue
		if kind == "dummy":
			_draw_dummy(p, a["hurt"], alpha, light)
			continue
		if kind == "target":
			_draw_target(p, alpha, light)
			continue
		var s: float = BIG.get(kind, SPRITE_SCALE)
		var flying: bool = kind == "bat" or kind == "wyvern"
		var foot := p + Vector2(0, 2)
		draw_set_transform(foot, 0, Vector2(1, 0.35))
		draw_circle(Vector2.ZERO, 7.0 * s, Color(0, 0, 0, 0.25 * alpha))
		draw_set_transform(Vector2.ZERO)
		var frames: Array = Sprites.frames(kind)
		var tex: Texture2D = frames[int(t * 5.0 + a["id"] % 7) % frames.size()]
		var sz := tex.get_size() * s
		var faces_left: bool = a["side"] == "foe" or a["role"] in ["idle_r", "spar_r"]
		var dir := -1.0 if faces_left else 1.0
		var tint := Color(light.r, light.g, light.b, alpha)
		if a["hurt"] > 0.0:
			tint = Color(1, 0.5, 0.5, alpha)
		if a["side"] == "downed":
			draw_set_transform(p + Vector2(0, -6), PI / 2.0, Vector2(1, 1))
			draw_texture_rect(tex, Rect2(-sz / 2.0, sz), false, Color(0.5, 0.5, 0.58, 0.85 * alpha) * Color(light, 1))
			draw_set_transform(Vector2.ZERO)
			continue
		var lunge: float = a["lunge"]
		var off := Vector2(dir * 8.0 * minf(lunge / 0.15, 1.0), 0)
		var bob := Vector2(0, sin(t * (9.0 if a["side"] == "foe" else 3.0) + a["id"] % 13) * 1.5)
		if flying:
			bob += Vector2(0, -36 + sin(t * 4.0 + a["id"] % 5) * 4.0)
		draw_set_transform(p + off + bob + Vector2(0, -sz.y / 2.0 + 4), 0, Vector2(dir, 1))
		draw_texture_rect(tex, Rect2(-sz / 2.0, sz), false, tint)
		draw_set_transform(Vector2.ZERO)


## A straw training dummy on a post; it rocks when it's hit.
func _draw_dummy(p: Vector2, hurt: float, alpha: float, light: Color) -> void:
	var tilt := sin(hurt * 40.0) * hurt * 1.2
	draw_set_transform(p, tilt, Vector2.ONE)
	var straw := Color(0.86, 0.72, 0.38, alpha) * Color(light, 1)
	draw_rect(Rect2(-2, -10, 4, 12), Color(OUTLINE, alpha))
	draw_rect(Rect2(-9, -34, 18, 24).grow(2), Color(OUTLINE, alpha))
	draw_rect(Rect2(-9, -34, 18, 24), straw)
	draw_rect(Rect2(-16, -30, 32, 5).grow(1.5), Color(OUTLINE, alpha))
	draw_rect(Rect2(-16, -30, 32, 5), straw)
	draw_circle(Vector2(0, -42), 8.5, Color(OUTLINE, alpha))
	draw_circle(Vector2(0, -42), 7.0, straw)
	draw_line(Vector2(-6, -22), Vector2(6, -22), Color(0.5, 0.3, 0.15, alpha), 2.0)
	draw_set_transform(Vector2.ZERO)


## An archery target on a stand.
func _draw_target(p: Vector2, alpha: float, light: Color) -> void:
	draw_line(p + Vector2(-8, 0), p + Vector2(0, -24), Color(0.45, 0.3, 0.15, alpha), 3.0)
	draw_line(p + Vector2(8, 0), p + Vector2(0, -24), Color(0.45, 0.3, 0.15, alpha), 3.0)
	var c := p + Vector2(0, -28)
	for ring in [[15.0, OUTLINE], [13.0, Color(0.95, 0.93, 0.88)], [10.0, Color(0.85, 0.2, 0.2)], [6.5, Color(0.95, 0.93, 0.88)], [3.5, Color(0.85, 0.2, 0.2)]]:
		draw_circle(c, ring[0], Color(ring[1], alpha) * Color(light, 1))


## "HOLD THE LINE" in chunky gold pixel letters on a red ribbon, with a glint that
## sweeps across now and then.
func _draw_title() -> void:
	var width := title_cols * PX
	var left := (W - width) / 2.0
	var top := TITLE_Y
	# The ribbon.
	var rib := Rect2(left - 34, top - 18, width + 68, 7 * PX + 36)
	for side in [-1, 1]:
		var x: float = rib.position.x if side < 0 else rib.end.x
		var tail := PackedVector2Array([Vector2(x - side * 6, rib.position.y + 14), Vector2(x + side * 46, rib.position.y + 14),
				Vector2(x + side * 30, rib.position.y + rib.size.y / 2.0 + 7), Vector2(x + side * 46, rib.end.y + 14), Vector2(x - side * 6, rib.end.y + 14)])
		draw_colored_polygon(tail, OUTLINE)
		var inner := PackedVector2Array()
		for q in tail:
			inner.append(q + (Vector2(x + side * 20, rib.position.y + rib.size.y / 2.0 + 14) - q) * 0.12)
		draw_colored_polygon(inner, Color(0.5, 0.08, 0.1))
	draw_rect(rib.grow(3), OUTLINE)
	draw_rect(rib, Color(0.68, 0.14, 0.14))
	draw_rect(Rect2(rib.position, Vector2(rib.size.x, 6)), Color(0.82, 0.25, 0.22))
	draw_rect(Rect2(rib.position + Vector2(0, rib.size.y - 6), Vector2(rib.size.x, 6)), Color(0.5, 0.08, 0.1))
	draw_line(rib.position + Vector2(0, 10), Vector2(rib.end.x, rib.position.y + 10), Color(1.0, 0.8, 0.3, 0.7), 2.0)
	draw_line(Vector2(rib.position.x, rib.end.y - 10), rib.end - Vector2(0, 10), Color(1.0, 0.8, 0.3, 0.7), 2.0)
	# Letters: shadow, outline, then gold shading row by row.
	var lit := {}
	for px in title_pixels:
		lit[px] = true
	for px in title_pixels:
		draw_rect(Rect2(left + px.x * PX - 3, top + px.y * PX + 3, PX + 6, PX + 6), Color(0.2, 0.05, 0.05, 0.6))
	for px in title_pixels:
		draw_rect(Rect2(left + px.x * PX - 3, top + px.y * PX - 3, PX + 6, PX + 6), Color(0.22, 0.1, 0.04))
	var shades := [Color(1.0, 0.95, 0.62), Color(1.0, 0.88, 0.42), Color(1.0, 0.8, 0.28), Color(0.98, 0.72, 0.2),
			Color(0.94, 0.62, 0.16), Color(0.86, 0.5, 0.12), Color(0.74, 0.4, 0.1)]
	var glint := fmod(t * 0.35, 1.6) * (title_cols + 14) - 7.0
	for px in title_pixels:
		var r := Rect2(left + px.x * PX, top + px.y * PX, PX, PX)
		draw_rect(r, shades[px.y])
		if not lit.has(Vector2i(px.x, px.y - 1)):
			draw_rect(Rect2(r.position, Vector2(PX, 2)), Color(1, 1, 0.9))
		var g := absf(px.x + px.y * 0.5 - glint)
		if g < 1.5:
			draw_rect(r, Color(1, 1, 1, 0.6 * (1.0 - g / 1.5)))
