extends RefCounted
## Hiring and building: where troops and emplacements may be posted, prices, walls (barricades)
## and placing them, towers and climbing down from them; hiring several at a click (the
## count button, N) and buying a fallen troop back from its grave, upgrades and all.
## Part of the game controller: `main` is main.gd, which holds the battle's state.

const Main = preload("res://scripts/main.gd")
const Data = preload("res://scripts/data/data.gd")
const Warrior = preload("res://scripts/troops/warrior.gd")
const Barricade = preload("res://scripts/troops/barricade.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")
const Engineer = preload("res://scripts/troops/engineer.gd")

var main: Main

const HIRE_COUNTS := [1, 3, 5]
var hire_count := 1   # how many one click on the field hires (the count button by the tabs, N)
const CLUSTER_STEP := 34.0   # how far apart several hires at once are posted (a little over MIN_POST_GAP)


func _init(m: Main) -> void:
	main = m


## N (or the count button): one click on the field hires 1, then 3, then 5 of a kind.
func cycle_hire_count() -> void:
	hire_count = HIRE_COUNTS[(HIRE_COUNTS.find(hire_count) + 1) % HIRE_COUNTS.size()]


# --- Warriors ------------------------------------------------------------

func _on_hire_pressed(kind: String) -> void:
	if main.game_over or main.missions._locked(kind):
		return
	main.selected = null
	main.group.clear()
	main.castle_selected = false
	main.wall_start = null
	main.powers.aiming = ""
	main.placing_type = "" if main.placing_type == kind else kind


func can_post_at(p: Vector2, ignore: Warrior = null) -> bool:
	if p.x < 0 or p.x > main.FIELD_W or p.y < main.DEPLOY_TOP or p.y > Main.CASTLE_Y:
		return false
	if tower_for(p, ignore if ignore != null else main.placing_type) != null:
		return true   # a ranged troop onto an empty Tower (or hired straight onto one): it climbs in
	if ground_problem(p) != "":
		return false
	if _emplacing(ignore) and main.hazards.on_thin_ice(p):
		return false   # nothing is built on thin ice: it couldn't get off
	for w in main.battlefield.get_warriors():
		if w != ignore and w.post.distance_to(p) < Main.MIN_POST_GAP:
			return false
	for b in main.battlefield.get_barricades():
		if b.gap_from(p) < Warrior.RADIUS:
			return false
	return true


## L (or the Climb down button): the selected troop comes down out of its Tower, to its
## foot (and stays there until it's sent somewhere).
func climb_down() -> void:
	if main.selected is Warrior and main.selected.broken:
		rebuild_selected()
		return
	if main.selected == null or not (main.selected is Warrior) or main.selected.garrison == null or not is_instance_valid(main.selected.garrison):
		return
	var t = main.selected.garrison
	main.selected.leave_tower()
	main.selected.set_post(main.paths.open_spot(_clamp_post(t.position + Vector2(0, 34))))
	main.effects.spawn_text(main.selected.position + Vector2(0, -40), "Climbs down", Color(0.75, 0.9, 1.0))


## The marker on a Tower a troop would go up if dropped (or hired) where it is: a pulsing
## ring round it, an arrow up into it, and a word saying so.
func _draw_into_tower(t) -> void:
	var k := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 140.0)
	var c := Color(0.55, 0.85, 1.0)
	var foot: Vector2 = t.position + Vector2(0, Warrior.RADIUS * 0.6)
	main.overlay.draw_set_transform(foot, 0, Vector2(1.0, 0.55))
	main.overlay.draw_circle(Vector2.ZERO, Warrior.CLIMB_REACH, Color(c, 0.12 * k), true, -1.0, true)
	main.overlay.draw_arc(Vector2.ZERO, Warrior.CLIMB_REACH, 0.0, TAU, 40, Color(c, 0.9 * k), 3.0, true)
	main.overlay.draw_set_transform(Vector2.ZERO)
	var top: Vector2 = t.position + Vector2(0, -62 - 5.0 * k)
	var arrow := PackedVector2Array([top + Vector2(0, -12), top + Vector2(10, 0), top + Vector2(4, 0), top + Vector2(4, 12),
			top + Vector2(-4, 12), top + Vector2(-4, 0), top + Vector2(-10, 0)])
	main.overlay.draw_colored_polygon(arrow, Color(c, 0.95))
	main.overlay.draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color(0.1, 0.15, 0.25), 1.5)
	var f := ThemeDB.fallback_font
	main.overlay.draw_string_outline(f, top + Vector2(-70, -18), "Into the tower", HORIZONTAL_ALIGNMENT_CENTER, 140, 13, 4, Color(0, 0, 0, 0.85))
	main.overlay.draw_string(f, top + Vector2(-70, -18), "Into the tower", HORIZONTAL_ALIGNMENT_CENTER, 140, 13, c)


## The selected broken emplacement rebuilt (if there's the gold): an Engineer comes out to it.
func rebuild_selected() -> void:
	if not (main.selected is Warrior) or not main.selected.broken:
		return
	var cost: int = main.selected.rebuild_cost()
	if main.gold < cost:
		main.hud.show_message("Rebuilding it takes %dg." % cost)
		return
	main.gold -= cost
	main.selected.spent += cost
	main.selected.start_rebuild()
	main.effects.spawn_text(main.selected.position + Vector2(0, -50), "Rebuilding", Color(1.0, 0.9, 0.6))
	main.effects.sfx("place")


## Whether the battle's on: a wave, or anything hostile on the field (an enemy, or one of
## the battle's own, like the assault's archer towers). Troops can't be picked up and
## moved about, and the breathers' mending waits, until it's over.
func fighting() -> bool:
	return main.wave_active or not main.battlefield.get_enemies().is_empty() or main.rules.hostiles()


## An empty Tower at p that troop w could climb into (its own, if it's already in one), or
## null: w must be one of the ranged kinds (Warrior.GARRISON_KINDS).
func tower_for(p: Vector2, w) -> Warrior:
	if w is String:
		if not Warrior.GARRISON_KINDS.has(w):
			return null   # (hiring: a ranged kind can be hired straight onto a Tower)
		w = null
	elif w == null or not (w is Warrior) or not Warrior.can_garrison(w):
		return null
	for t in main.battlefield.get_warriors():
		if t.kind == "tower" and t.is_active() and t.build_left <= 0.0 and t.position.distance_to(p) <= Warrior.CLIMB_REACH \
				and (t.crew_in == null or not is_instance_valid(t.crew_in) or t.crew_in == w):
			return t
	return null


## Whether an emplacement is being placed (or `w`, being moved, is one).
func _emplacing(w) -> bool:
	if w != null:
		return w.is_emplacement()
	return main.placing_type != "" and Data.WARRIORS.has(main.placing_type) and Data.WARRIORS[main.placing_type].get("emplacement", false)


## Why the battlefield itself won't take a post at p ("" if it will): rock, cliff,
## trees or the quarry, a spot troops can't walk to, or ground kept clear (the gate).
## Always "" on the open meadow (Classic, Freeplay, the Tutorial).
func ground_problem(p: Vector2) -> String:
	for o in main.rules.objectives():
		if o.is_solid() and p.distance_to(o.position) < o.RADIUS + Warrior.RADIUS:
			return "Keep the %s clear" % o.label.to_lower()
	if not main.paths.has_terrain():
		return ""
	if main.paths.in_no_build(p):
		return "Keep the gate clear"
	if main.paths.blocked(p, Warrior.RADIUS):
		return "Can't stand there"
	if not main.paths.troop_can_stand(p):
		return "Your troops can't get there"
	return ""


# --- Barricades ----------------------------------------------------------

## Where a wall started at `a` ends when the player points at `b`: clamped to the
## field and to the longest wall allowed.
## Walls can be as long as the field allows; the price is the only limit.
func wall_end(_a: Vector2, b: Vector2) -> Vector2:
	return _clamp_wall_point(b)


func _clamp_wall_point(p: Vector2) -> Vector2:
	return p.clamp(Vector2(0, main.DEPLOY_TOP), Vector2(main.FIELD_W, Main.CASTLE_Y - 16))


func wall_cost(a: Vector2, b: Vector2) -> int:
	return price(Barricade.cost_for(Data.WARRIORS["barricade"], a.distance_to(b)))


## A price adjusted for the difficulty.
func price(base: float) -> int:
	return Data.scaled_price(base, main.cost_mult, main.price_step)


## What hiring this kind costs (the shortest wall, for a barricade).
func hire_cost(kind: String) -> int:
	return price(Data.WARRIORS[kind]["cost"])


## Why a wall can't go from a to b ("" if it can). Walls may cross each other,
## but not run through another unit's post.
func wall_problem(a: Vector2, b: Vector2) -> String:
	if a.distance_to(b) < Data.WARRIORS["barricade"]["min_length"]:
		return "Too short"
	for w in main.battlefield.get_warriors():
		var c := Geometry2D.get_closest_point_to_segment(w.post, a, b)
		if c.distance_to(w.post) < Warrior.RADIUS + Barricade.WALL_HALF:
			return "Blocked by a unit"
	for o in main.rules.objectives():
		if o.is_solid() and Geometry2D.get_closest_point_to_segment(o.position, a, b).distance_to(o.position) < o.RADIUS + Barricade.WALL_HALF:
			return "Can't wall through the %s" % o.label.to_lower()
	return ""


## Barricades go down in two clicks: where the wall starts, then where it ends.
func _wall_click(p: Vector2) -> void:
	if main.wall_start == null:
		if p.y >= main.DEPLOY_TOP:
			main.wall_start = _clamp_wall_point(p)
		return
	var a: Vector2 = main.wall_start
	var b := wall_end(a, p)
	var problem := wall_problem(a, b)
	if problem != "":
		main.hud.show_message(problem)
		return
	var cost := wall_cost(a, b)
	if main.gold < cost:
		main.hud.show_message("Not enough gold")
		return
	main.gold -= cost
	main.effects.sfx("place")
	var wall := Barricade.new()
	wall.half = (b - a) / 2.0
	wall.setup("barricade", Data.WARRIORS["barricade"], main, (a + b) / 2.0)
	wall.spent = cost
	wall.position = wall.post
	main.wall_layer.add_child(wall)
	main.battlefield.walls_changed()
	main.wall_start = null
	# Hold Shift to keep building walls.
	if not Input.is_key_pressed(KEY_SHIFT) or main.gold < hire_cost("barricade"):
		main.placing_type = ""


func hire_at(p: Vector2) -> void:
	if main.placing_type != "" and not main.missions.allowed(main.placing_type):
		main.placing_type = ""   # never place something the campaign hasn't unlocked
		return
	if main.placing_type == "barricade":
		_wall_click(p)
		return
	if hire_count > 1 and main.placing_type != "" and tower_for(p, main.placing_type) == null:
		_hire_several(p, hire_count)
		return
	if not can_post_at(p):
		if ground_problem(p) != "":
			main.hud.show_message(ground_problem(p))
		elif _emplacing(null) and main.hazards.on_thin_ice(p):
			main.hud.show_message("Nothing can be built on thin ice")
		return
	var onto := tower_for(p, main.placing_type)
	if onto != null:
		p = onto.position   # hired onto an empty Tower: it walks over and climbs in
	var data: Dictionary = Data.WARRIORS[main.placing_type]
	var cost := hire_cost(main.placing_type)
	if main.gold < cost:
		main.hud.show_message("Not enough gold")
		main.placing_type = ""
		return
	main.gold -= cost
	main.effects.sfx("place")
	main.effects.spawn_burst(_clamp_post(p) + Vector2(0, 10), 26.0, Color(0.9, 0.82, 0.62))   # a puff of dust where it lands
	var w := Warrior.new()
	w.setup(main.placing_type, data, main, _clamp_post(p))
	w.spent = cost
	w.priority = main.last_priority.get(main.placing_type, data.get("priority", Warrior.OBJECTIVE_PRIORITY if main.rules.guards() else "closest"))   # (an Assassin: High-value)
	if w.is_mobile_healer():
		w.priority = main.last_priority.get(main.placing_type, "revive")
	if main.last_orders.has(main.placing_type):
		var o: Dictionary = main.last_orders[main.placing_type]
		w.commit = o["commit"]
		w.move_mode = o["move_mode"]
		var area: Rect2 = o["guard_area"]
		if area.has_point(w.post):
			w.guard_area = area   # hired into the area its kind was last given: it guards it too
		w.danger_mode = o["danger_mode"]
		w.call_help = o["call_help"]
		w.answer = o["answer"]
	# New hires march in from whichever side of the field is nearer their post;
	# emplacements are built on the spot.
	w.position = w.post if w.is_emplacement() else _entry_point(w.post)
	main.warrior_layer.add_child(w)
	if w.is_emplacement():
		# An Engineer comes out of the castle to build it.
		w.build_left = Data.BUILD_TIME
		w.build_total = Data.BUILD_TIME
		main.castle_ctl.send_engineer("build", w, Vector2.ZERO)
	# Hold Shift to keep hiring the same type.
	if not Input.is_key_pressed(KEY_SHIFT) or main.gold < cost:
		main.placing_type = ""


## Several of the kind being placed at one click: posted in a tight cluster round where
## the click was (nearest spots first), as many as there's room for and gold to pay for.
func _hire_several(p: Vector2, n: int) -> void:
	var kind: String = main.placing_type
	var cost := hire_cost(kind)
	var spots := _cluster(p, n, kind)
	if spots.is_empty():
		main.hud.show_message(ground_problem(p) if ground_problem(p) != "" else "No room to post them here")
		return
	if main.gold < cost:
		main.hud.show_message("Not enough gold")
		main.placing_type = ""
		return
	var keep := hire_count
	hire_count = 1
	var hired := 0
	for q in spots:
		if main.gold < cost:
			break
		main.placing_type = kind
		hire_at(q)
		hired += 1
	hire_count = keep
	main.placing_type = kind if Input.is_key_pressed(KEY_SHIFT) and main.gold >= cost else ""
	if hired < n:
		main.hud.show_message("Hired %d of %d: %s" % [hired, n, "not enough gold for more" if main.gold < cost else "no more room here"])


## Up to n free posts for `kind` round p, nearest first, far enough apart to all be taken.
func _cluster(p: Vector2, n: int, kind: String) -> Array:
	var out := []
	for r in [0.0, CLUSTER_STEP, CLUSTER_STEP * 2.0, CLUSTER_STEP * 3.0]:
		var steps := 1 if r == 0.0 else int(TAU * r / CLUSTER_STEP)
		for i in steps:
			var q := _clamp_post(p + Vector2.from_angle(i * TAU / steps + PI / 2.0) * r)
			if tower_for(q, kind) != null or not can_post_at(q):
				continue
			if out.any(func(o): return o.distance_to(q) < Main.MIN_POST_GAP + 1.0):
				continue
			out.append(q)
			if out.size() >= n:
				return out
	return out


# --- Graves: buying a fallen troop back ------------------------------------------------

## The tiers a fallen troop had that can be bought again now: all of them, unless the
## campaign's training doesn't reach that far yet.
func rebuy_tiers(g) -> Array:
	var out := []
	for p in g.tiers.size():
		out.append(mini(int(g.tiers[p]), main.missions.max_tier(g.kind, p)))
	return out


## What buying it back costs: the hire and every upgrade it had, at today's prices.
func rebuy_cost(g) -> int:
	var total := hire_cost(g.kind)
	var paths: Array = Data.WARRIORS[g.kind]["paths"]
	var tiers := rebuy_tiers(g)
	for p in tiers.size():
		for t in tiers[p]:
			total += price(paths[p]["tiers"][t]["cost"])
	return total


## Why a grave's troop can't be bought back now ("" if it can).
func rebuy_problem(g) -> String:
	if g == null or not is_instance_valid(g):
		return "Nothing to rebuy"
	if not g.rebuyable:
		return "The castle's own wall guards come back with its upgrades"
	if g.replaced:
		return "Already replaced"
	if main.game_over:
		return "The battle's over"
	if not main.missions.allowed(g.kind):
		return main.missions.lock_note(g.kind)
	if main.gold < rebuy_cost(g):
		return "Not enough gold (%dg needed)" % rebuy_cost(g)
	if _rebuy_spot(g) == Vector2.INF:
		return "No room to post it here"
	return ""


## Where the bought-back troop is posted: on the grave, or the nearest free spot to it.
func _rebuy_spot(g) -> Vector2:
	var keep: String = main.placing_type
	main.placing_type = g.kind   # (the posting rules depend on what's being placed)
	var spots := _cluster(g.position, 1, g.kind)
	main.placing_type = keep
	return spots[0] if not spots.is_empty() else Vector2.INF


## Replaces a fallen troop from its grave: the same kind, hired near where it fell, with
## every upgrade it had (that can be bought now), all paid for at once. Just a quicker way
## to hire its like again: the grave stays (each grave's troop is replaced once).
func rebuy_grave(g) -> void:
	var why := rebuy_problem(g)
	if why != "":
		main.hud.show_message(why)
		return
	var spot := _rebuy_spot(g)
	var keep_type: String = main.placing_type
	var keep_count := hire_count
	var before: Array = main.warrior_layer.get_children()
	main.placing_type = g.kind
	hire_count = 1
	hire_at(spot)
	main.placing_type = keep_type if keep_type != g.kind else ""
	hire_count = keep_count
	var w = null
	for c in main.warrior_layer.get_children():
		if not before.has(c) and c is Warrior and c.kind == g.kind:
			w = c
	if w == null:
		return   # (hire_at said why)
	var tiers := rebuy_tiers(g)
	for p in tiers.size():
		for t in tiers[p]:
			if w.path_state(p) != "ok":
				break
			main.gold -= w.upgrade_cost(p)
			w.upgrade(p)
	main.effects.sfx("upgrade")
	main.effects.spawn_text(w.post + Vector2(0, -50), "Back in the line!", Color(1, 0.9, 0.5))
	g.replaced = true
	if main.selected_grave == g:
		main.selected_grave = null


## Where a new troop walks on: the nearer side edge, level with its post, nudged up
## or down the edge if a wall runs into it there. On a campaign battlefield (whose edges
## may be cliffs) troops come out of the castle gate instead.
func _entry_point(post: Vector2) -> Vector2:
	var r := Warrior.RADIUS
	var from: Vector2 = main.rules.entry_point(post)
	if from != Vector2.INF:
		return from   # the battle's own way in (a wagon carrying the camp)
	if main.paths.has_terrain():
		return Vector2(main.FIELD_W / 2.0, Main.CASTLE_Y - r)
	var x := r if post.x < main.FIELD_W / 2.0 else main.FIELD_W - r
	for step in 40:
		for sign in [1, -1]:
			var y := clampf(post.y + sign * step * 8.0, main.DEPLOY_TOP, Main.CASTLE_Y - r)
			var spot := Vector2(x, y)
			if not main.battlefield.get_barricades().any(func(b): return b.gap_from(spot) < r + 2.0):
				return spot
	return Vector2(x, post.y)


func _clamp_post(p: Vector2) -> Vector2:
	var r := Warrior.RADIUS
	return p.clamp(Vector2(r, main.DEPLOY_TOP), Vector2(main.FIELD_W - r, Main.CASTLE_Y - r))
