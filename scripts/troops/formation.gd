extends RefCounted
## A formation: where a group of troops belongs, kept round an anchor, not exact spots to
## fight over. Each member has a slot, an offset in the formation's own frame (x across,
## to its right; y back, away from the way it faces). The formation sets each member's post
## from its slot (main._formations_step, a few times a second, only when it's moved enough
## to matter); the troops do the walking, with all their usual give and take (see
## warrior._home_spot: a slot that's taken is stood beside, not fought for).
##
## Anchors: "stationary" (a spot), "moving" (a spot the player moved it to), "objective"
## (a wagon, a ram: the formation goes with it, faced the way it rolls, and keeps out of
## the lane ahead of it). Layouts: the presets (LAYOUTS) or "custom" (as the player set the
## posts). A formation going through a gap or a door takes up a temporary column
## (travel), keeping its own layout to go back to.

const LAYOUTS := ["shield_wall", "wedge", "column", "escort"]
const NAMES := {"shield_wall": "Shield Wall", "wedge": "Wedge", "column": "Travel Column", "escort": "Convoy Escort", "custom": "Custom"}
const TIPS := {
	"shield_wall": "Knights and Martial Artists in a line at the front, ranged troops behind them, Healers and Bards at the back",
	"wedge": "The strongest fighter at the point, the other fighters down its sides, ranged troops and support inside behind",
	"column": "Two abreast, fighters first: for gaps, corridors and doors",
	"escort": "Round the wagon or ram it follows: fighters at its front corners and sides, ranged troops beside it, support behind; the road ahead kept clear",
}
const ACROSS := 40.0        # spacing along a line (a troop's width and a little)
const ROW := 48.0           # spacing between rows
const PIKE_ROW := 30.0      # Pikemen behind the front line: this close, so their pikes reach past it
const LANE := 14.0          # escort: kept clear either side of the objective's road ahead, beyond its own width
const POST_MOVE := 8.0      # a member's post is moved only when its slot's moved this far (no jitter)
const IN_PLACE := 34.0      # a member this near its slot (or fighting) counts as in place for cohesion

var id := 0
var layout := "custom"
var anchor := Vector2.ZERO
var facing := Vector2.UP    # the way it faces: up the field, at the enemy, by default
var follow = null           # objective anchor: the wagon or ram it goes with
var slots := {}             # member (warrior) -> Vector2 offset in the formation's frame
var travel := false         # in a temporary column (a door, a gap): `slots` kept for after
var travel_slots := {}


func right() -> Vector2:
	return Vector2(-facing.y, facing.x)


## A slot's place on the field.
func world(off: Vector2) -> Vector2:
	return anchor + right() * off.x - facing * off.y


## A place on the field in the formation's frame.
func local(p: Vector2) -> Vector2:
	var d := p - anchor
	return Vector2(d.dot(right()), -d.dot(facing))


func members() -> Array:
	return slots.keys().filter(func(w): return is_instance_valid(w) and not w.is_queued_for_deletion())


func slot_of(w) -> Vector2:
	return (travel_slots if travel and travel_slots.has(w) else slots).get(w, Vector2.ZERO)


## What part a troop plays: "front" (it fights close: Knights, Martial Artists, a Spellblade
## Mage still casts, so she's ranged), "ranged", or "support" (Healers, Bards).
static func role(w) -> String:
	if w.is_melee() or w.data.get("attack", "") == "combo":
		return "front"
	if w.kind == "healer" or w.kind == "bard":
		return "support"
	return "ranged"


## Each troop's slot for `kind` of layout, for these troops, as they stand now. Slots go to
## troops by where they are across the formation, left to right, so nobody crosses another
## on the way to theirs. `follow_r`: the objective's radius, for an escort.
func lay_out(kind: String, troops: Array, follow_r := 30.0) -> void:
	layout = kind
	slots.clear()
	var by_role := {"front": [], "ranged": [], "support": []}
	for w in troops:
		by_role[role(w)].append(w)
	# The strongest fighters first (a wedge's point, a shield wall's middle).
	by_role["front"].sort_custom(func(a, b): return a.max_hp * a.damage > b.max_hp * b.damage)
	match kind:
		"shield_wall":
			# Pikemen behind the other fighters, in reach past them (a second rank), unless
			# they're all the front there is.
			var pikes: Array = by_role["front"].filter(func(w): return w.data.get("pike", false))
			var blades: Array = by_role["front"].filter(func(w): return not w.data.get("pike", false))
			var rows := [blades, pikes, by_role["ranged"], by_role["support"]] if not blades.is_empty() else [pikes, [], by_role["ranged"], by_role["support"]]
			var y := 0.0
			for i in rows.size():
				var r: Array = rows[i]
				if r.is_empty():
					continue
				_line(r, y, ACROSS if i < 2 else ACROSS * 1.15)
				y += PIKE_ROW if (i == 0 and not blades.is_empty() and not pikes.is_empty()) else (ROW if i < 2 else ROW * 0.95)
		"wedge":
			var front: Array = by_role["front"]
			var spots := []
			for i in front.size():
				var rank := (i + 1) / 2
				var side := 0.0 if i == 0 else (-1.0 if i % 2 == 1 else 1.0)
				spots.append(Vector2(side * rank * ACROSS * 0.85, rank * ROW * 0.7))
			_assign(front, spots)
			var depth := (front.size() / 2) * ROW * 0.7
			var inner: Array = by_role["ranged"] + by_role["support"]
			var rows := []
			var y := depth * 0.5 + ROW * 0.8 if not front.is_empty() else 0.0
			var left := inner.duplicate()
			var per := 2
			while not left.is_empty():
				var take := left.slice(0, per)
				left = left.slice(per)
				for j in take.size():
					rows.append(Vector2((j - (take.size() - 1) / 2.0) * ACROSS, y))
				y += ROW * 0.85
				per += 1
			_assign(inner, rows)
		"column":
			var order: Array = by_role["front"] + by_role["ranged"] + by_role["support"]
			var spots := []
			for i in order.size():
				spots.append(Vector2((-0.5 if i % 2 == 0 else 0.5) * ACROSS * 0.9, (i / 2) * ROW * 0.8))
			for i in order.size():
				slots[order[i]] = spots[i]   # (in order: fighters lead)
		"escort":
			_escort(by_role, follow_r)
		_:
			for w in troops:
				slots[w] = local(w.post)


## A row of troops `gap` apart across the formation, centred, `y` back.
func _line(troops: Array, y: float, gap: float) -> void:
	var spots := []
	for i in troops.size():
		spots.append(Vector2((i - (troops.size() - 1) / 2.0) * gap, y))
	_assign(troops, spots)


## Spots to troops by order across (leftmost troop to leftmost spot, and so on).
func _assign(troops: Array, spots: Array) -> void:
	var ts := troops.duplicate()
	ts.sort_custom(func(a, b): return local(a.position).x < local(b.position).x)
	var ss := spots.duplicate()
	ss.sort_custom(func(a, b): return a.x < b.x)
	for i in mini(ts.size(), ss.size()):
		slots[ts[i]] = ss[i]


## Round a moving objective of radius r: fighters at its front corners, then its sides;
## ranged troops along its sides further out; support behind it. Nothing in the lane ahead.
func _escort(by_role: Dictionary, r: float) -> void:
	var side := r + LANE + 26.0
	var front := []
	var n_front: int = by_role["front"].size()
	for i in n_front:
		var s := -1.0 if i % 2 == 0 else 1.0
		var rank := i / 2
		front.append(Vector2(s * side, -r * 0.6 + rank * ROW * 0.8))   # (the front corners first, then down the sides)
	_assign(by_role["front"], front)
	var ranged := []
	for i in by_role["ranged"].size():
		var s := -1.0 if i % 2 == 0 else 1.0
		ranged.append(Vector2(s * (side + ACROSS), r * 0.2 + (i / 2) * ROW * 0.8))
	_assign(by_role["ranged"], ranged)
	var back := []
	for i in by_role["support"].size():
		back.append(Vector2((i - (by_role["support"].size() - 1) / 2.0) * ACROSS, r + 40.0))
	_assign(by_role["support"], back)


## Whether an escort slot is in the road ahead of the objective (it would block it).
func in_lane(off: Vector2, r: float) -> bool:
	return off.y < r * 0.3 and absf(off.x) < r + LANE


## Turned by `angle` (its slots go round with it).
func turn(angle: float) -> void:
	facing = facing.rotated(angle).normalized()


## A temporary column (a door, a gap) for these members, in the order they stand nearest
## the way through: the slots to go back to are kept.
func start_travel(toward: Vector2) -> void:
	travel = true
	travel_slots.clear()
	var ms := members()
	ms.sort_custom(func(a, b): return a.position.distance_to(toward) < b.position.distance_to(toward))
	for i in ms.size():
		travel_slots[ms[i]] = Vector2((-0.5 if i % 2 == 0 else 0.5) * ACROSS * 0.8, (i / 2) * ROW * 0.75)


func end_travel() -> void:
	travel = false
	travel_slots.clear()


## How together it is (0-1): the share of its members at their slots, or fighting (a troop
## off after an enemy is doing its job). Used only to steer movement, never in combat.
func cohesion() -> float:
	var ms := members()
	if ms.is_empty():
		return 1.0
	var n := 0
	for w in ms:
		if not w.is_active() or w.target != null or w.position.distance_to(world(slot_of(w))) <= IN_PLACE:
			n += 1
	return float(n) / ms.size()


## For saving (a custom layout): each slot by the kind of troop in it.
func to_save() -> Dictionary:
	var rows := []
	for w in members():
		var o: Vector2 = slots[w]
		rows.append([w.kind, o.x, o.y])
	return {"layout": layout, "facing": [facing.x, facing.y], "slots": rows}


## A saved layout put on these troops: each slot goes to the nearest troop of that kind
## (then of the same part, then anyone), what's left over is laid out round them.
func from_save(d: Dictionary, troops: Array) -> void:
	layout = "custom"
	var f: Array = d.get("facing", [0.0, -1.0])
	facing = Vector2(f[0], f[1]).normalized() if Vector2(f[0], f[1]).length() > 0.1 else Vector2.UP
	slots.clear()
	var free := troops.duplicate()
	var saved: Array = d.get("slots", [])
	for pass_i in 3:
		for row in saved:
			var off := Vector2(row[1], row[2])
			if slots.values().has(off):
				continue
			var best = null
			for w in free:
				var ok: bool = (pass_i == 0 and w.kind == row[0]) or (pass_i == 1 and Data.WARRIORS.has(row[0]) and role(w) == _role_of_kind(row[0])) or pass_i == 2
				if ok and (best == null or w.position.distance_to(world(off)) < best.position.distance_to(world(off))):
					best = w
			if best != null:
				slots[best] = off
				free.erase(best)
	var y := 0.0
	for v in slots.values():
		y = maxf(y, v.y)
	for i in free.size():
		slots[free[i]] = Vector2((i - (free.size() - 1) / 2.0) * ACROSS, y + ROW)


const Data = preload("res://scripts/data/data.gd")

static func _role_of_kind(k: String) -> String:
	var d: Dictionary = Data.WARRIORS.get(k, {})
	if d.get("attack", "") in ["melee", "combo"]:
		return "front"
	if k == "healer" or k == "bard":
		return "support"
	return "ranged"
