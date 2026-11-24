extends RefCounted
## A warband: a part of a wave that comes on at one place, forms up at the top of the
## field, and marches on your line as one body, every kind in its place:
##   front rank   the shields and brutes in the middle (Shieldbearers, Warlords, Ogres,
##                Trolls, Orcs, Slimes), the goblins out to either end of it
##   second rank  Boltflingers and Skeleton Archers right behind the shields (in their
##                cover), the Sappers with them
##   third        the War Drummers, where the beat reaches everyone
##   rear         Horde Mages and Gravebinders
##   wings        wolves, out past either end, ready to run round the ends of your line
## It keeps the pace of its slowest. When it comes within reach of your troops (or one
## of it is fighting, or it nears the castle) it breaks into its charge: each goes about
## its own work from where the formation put it, the front rank first into your troops.

const MUSTER_Y := 96.0       # how far down the field the band forms up (its front rank)
const FORM_TIME := 6.0       # after its last has come on, it waits at most this long to be formed
const STRAY_TIME := 5.0      # one still to come that hasn't come this long after the last: given up on
const ROW_GAP := 30.0        # between its ranks
const WING_GAP := 34.0       # wolves this far out past the ends of the ranks
const FORMED := 16.0         # a member this close to its place is in it
const ENGAGE := 150.0        # one of your troops this close to its front: it charges
const CASTLE_CHARGE := 210.0 # this far from the castle wall it charges
const MAX_LEAD := 30.0       # the anchor waits for any of its ranks this far behind its place...
const MAX_WAIT := 3.0        # ...but no longer than this at a time (one stuck doesn't hold up the rest)
const CATCH_UP := 1.4        # px/s more (or less) of pace for every px a member's out of its place
const MAX_PACE := 1.15       # ...but never past this share of its own speed
const SIZE := 7              # the most in one band (a wave's foes are cut into bands of this)

# Each kind's rank (0 the front; -1 a wing) and how near the middle of it (lowest first).
const PLACE := {
	"shieldbearer": [0, 0], "warlord": [0, 0], "ogre": [0, 1], "troll": [0, 1], "orc": [0, 2], "slime": [0, 2],
	"goblin": [0, 5],
	"boltflinger": [1, 0], "skeleton_archer": [1, 1], "sapper": [1, 2],
	"drummer": [2, 0],
	"warmage": [3, 0], "gravebinder": [3, 0],
	"wolf": [-1, 0],
}

var main
var id := 0
var members: Array = []
var slots := {}                # member -> Vector2(across, forward) from the anchor
var expected := 0              # still to come on
var state := "muster"          # muster, advance, charge
var entry := Vector2.ZERO      # where its members come on (the top of the field)
var anchor := Vector2.ZERO     # the middle of its front rank
var facing := Vector2.DOWN
var pace := 45.0
var depth := 0.0               # front rank to its rearmost
var half_w := 0.0              # middle to its furthest out (wolves and all)
var since_join := 0.0
var formed_t := 0.0
var wait_t := 0.0
var lane := Vector2.ZERO       # the lane it came in by (x from, x to), or ZERO for the open top


## Whether this kind marches in a band at all (fliers and bosses don't).
static func bandable(kind: String) -> bool:
	return PLACE.has(kind)


## Cuts a wave's list of foes into bands: an index per entry (-1: not in one). A squad
## (`squads`: its kinds, in order) is kept to a band of its own wherever it turns up.
static func cut(kinds: Array, squads: Array, first_id: int) -> Array:
	var out := []
	out.resize(kinds.size())
	out.fill(-1)
	var squad_at := {}   # start index -> length
	for sq in squads:
		var run: Array = sq
		for i in kinds.size() - run.size() + 1:
			if squad_at.has(i) or kinds.slice(i, i + run.size()) != run:
				continue
			var clash := false
			for s in squad_at:
				if i < s + squad_at[s] and s < i + run.size():
					clash = true
			if not clash:
				squad_at[i] = run.size()
				break
	var id := first_id
	var n := 0
	var i := 0
	while i < kinds.size():
		if squad_at.has(i):
			if n > 0:
				id += 1
				n = 0
			for j in squad_at[i]:
				if bandable(kinds[i + j]):
					out[i + j] = id
			id += 1
			i += squad_at[i]
			continue
		if bandable(kinds[i]):
			if n >= SIZE and _left_to_band(kinds, i, squad_at) > 2:
				id += 1   # (two or fewer left over join the band before, rather than go alone)
				n = 0
			out[i] = id
			n += 1
		i += 1
	return out


## How many bandable foes there are from i to the next squad (or the end).
static func _left_to_band(kinds: Array, i: int, squad_at: Dictionary) -> int:
	var n := 0
	while i < kinds.size() and not squad_at.has(i):
		if bandable(kinds[i]):
			n += 1
		i += 1
	return n


func _init(m, band_id: int, count: int, at: Vector2) -> void:
	main = m
	id = band_id
	expected = count
	entry = at
	for l in main.paths.lanes:
		if at.x >= l.x and at.x <= l.y:
			lane = l
	_muster_at(MUSTER_Y)


## Where it forms up: `down` along the way in from its entry (down the lane it came by,
## round any terrain), facing on along it.
func _muster_at(down: float) -> void:
	var p := Vector2(entry.x, 0.0)
	var way := Vector2.DOWN
	var gone := 0.0
	while gone < down:
		var d: Vector2 = main.paths.direction(p, 14.0, null)
		way = d if d != Vector2.ZERO else Vector2.DOWN
		p += way * 6.0
		gone += 6.0
	anchor = p
	facing = Vector2(way.x, maxf(way.y, 0.3)).normalized()


## Where its next member comes on: near the band's own entry, inside its lane.
func spawn_spot(r: float) -> Vector2:
	var x := entry.x + randf_range(-46.0, 46.0)
	if lane != Vector2.ZERO:
		x = clampf(x, lane.x + r, lane.y - r)
	return Vector2(clampf(x, r + 10.0, main.FIELD_W - r - 10.0), -r)


func join(e) -> void:
	expected = maxi(expected - 1, 0)
	since_join = 0.0
	members.append(e)
	e.band = self
	_lay_out()


## One that won't come after all (sent on its own, or never spawned).
func skip() -> void:
	expected = maxi(expected - 1, 0)


func leave(e) -> void:
	members.erase(e)
	slots.erase(e)
	if is_instance_valid(e):
		e.band = null
		e.band_k = 1.0


func done() -> bool:
	return state == "charge" or (members.is_empty() and expected == 0)


## Each kind's place: its rank (from the front) and its spot across it.
func _lay_out() -> void:
	var rows := {}
	var wings := []
	for e in members:
		var rank: int = PLACE.get(e.kind, [0, 5])[0]
		if rank < 0:
			wings.append(e)
		else:
			if not rows.has(rank):
				rows[rank] = []
			rows[rank].append(e)
	slots.clear()
	var y := 0.0
	var first := true
	var prev_r := 0.0
	var half := 0.0
	for n in 4:
		if not rows.has(n):
			continue
		var rank: Array = rows[n]
		var r := 0.0
		for e in rank:
			r = maxf(r, e.radius)
		if not first:
			y -= maxf(ROW_GAP, prev_r + r + 6.0)
		first = false
		prev_r = r
		var gap := r * 2.0 + 8.0
		# (the shields in the middle of the front, the goblins out to its ends)
		rank.sort_custom(func(a, b): return PLACE.get(a.kind, [0, 5])[1] < PLACE.get(b.kind, [0, 5])[1])
		# In a narrow lane, a rank too wide for it goes as two (or more), one behind another.
		var per := rank.size() if lane == Vector2.ZERO else clampi(int((lane.y - lane.x) / gap), 1, rank.size())
		for start in range(0, rank.size(), per):
			if start > 0:
				y -= r * 2.0 + 6.0
			var part := rank.slice(start, start + per)
			var order := _middle_out(part.size())
			for k in part.size():
				var x: float = order[k] * gap
				slots[part[k]] = Vector2(x, y)
				half = maxf(half, absf(x) + r)
	depth = -y
	for k in wings.size():
		var side := -1.0 if k % 2 == 0 else 1.0
		slots[wings[k]] = Vector2(side * (half + WING_GAP + (k / 2) * 26.0), -minf(ROW_GAP, depth * 0.5) - (k / 2) * 20.0)
	half_w = half
	for e in wings:
		half_w = maxf(half_w, absf(slots[e].x) + e.radius)
	pace = INF
	for e in members:
		pace = minf(pace, e.speed)
	if state == "muster":
		_muster_at(maxf(MUSTER_Y, depth + 40.0))
		if lane == Vector2.ZERO and not main.paths.has_terrain():
			_keep_on_field()   # (in a lane, it forms up where the lane brings it)


## Spots across a rank of n from the middle out: 0, 1, -1, 2, -2...
static func _middle_out(n: int) -> Array:
	var out := []
	for k in n:
		var step := float((k + 1) / 2) * (1.0 if k % 2 == 0 else -1.0)
		out.append(step)   # (an even rank one spot longer on one side: its first is always in the middle)
	return out


## Where member e's place in the band is now.
func place_of(e) -> Vector2:
	var off: Vector2 = slots.get(e, Vector2.ZERO)
	var across := Vector2(-facing.y, facing.x)
	var p := anchor + facing * off.y + across * off.x
	if main.paths.has_terrain() and main.paths.blocked(p, e.radius):
		p = anchor + facing * off.y   # (its place is in the rocks: it falls in behind the middle)
	return p


func update(delta: float) -> void:
	for e in members.duplicate():
		if not is_instance_valid(e) or e.dead or e.band != self:
			members.erase(e)
			slots.erase(e)
	since_join += delta
	if expected > 0 and since_join > STRAY_TIME:
		expected = 0
	if members.is_empty():
		return
	if _provoked():
		_charge()
		return
	if state == "muster":
		if expected == 0:
			formed_t += delta
			if formed_t >= FORM_TIME or _formed():
				state = "advance"
		return
	# Advancing: the anchor goes on down the field (round the terrain, as they would), at
	# the pace of its slowest, waiting for ranks that have fallen behind.
	if _lag() > MAX_LEAD and wait_t < MAX_WAIT:
		wait_t += delta
		return
	if _lag() <= MAX_LEAD:
		wait_t = 0.0
	var way: Vector2 = main.paths.direction(anchor, 14.0, null)
	if way == Vector2.ZERO:
		way = Vector2.DOWN
	facing = facing.lerp(way, minf(delta * 2.0, 1.0)).normalized()
	if facing.y < 0.3:
		facing = Vector2(facing.x, 0.3).normalized()   # (always on toward the castle)
	var to := anchor + way * pace * 0.95 * delta
	anchor = main.paths.slide(anchor, to, 14.0) if main.paths.has_terrain() else to
	_keep_on_field()


func _keep_on_field() -> void:
	var m := minf(half_w + 8.0, main.FIELD_W / 2.0)
	anchor.x = clampf(anchor.x, m, main.FIELD_W - m)


func _formed() -> bool:
	for e in members:
		if e.position.distance_to(place_of(e)) > FORMED:
			return false
	return true


## How far behind its place its furthest-back member is (along the way it's going).
func _lag() -> float:
	var most := -INF
	for e in members:
		most = maxf(most, (place_of(e) - e.position).dot(facing))
	return most


## Whether it's time to charge: your troops in reach of its front, a member fighting
## (or set on a troop close by), the castle near, or the ground the rules have it wait at.
func _provoked() -> bool:
	if anchor.y >= main.CASTLE_Y - CASTLE_CHARGE or anchor.y >= main.rules.wait_y():
		return true
	for e in members:
		if e.aggro != null or e.fighting or e.sieging:
			return true   # (shot at from afar it keeps its ranks: that's what the shields are for)
	var front := anchor + facing * 10.0
	for w in main.warriors_near(front, ENGAGE):
		if w.is_active() and not w.sheltered() and front.distance_to(w.position) <= ENGAGE:
			return true
	return false


func _charge() -> void:
	state = "charge"
	for e in members.duplicate():
		leave(e)
	members.clear()


## How member e moves while it's in the band: the way to go, and its pace (its share of
## its own speed). On its way to its place while the band forms; then on with the band,
## closing up on its place as it goes.
func steer(e, route: Vector2, delta: float) -> Vector2:
	var at: Vector2 = place_of(e)
	var err: Vector2 = at - e.position
	if state == "muster" or err.length() > 80.0:
		if err.length() <= 4.0:
			e.band_k = 0.0
			return Vector2.ZERO   # in its place: it stands, waiting for the rest
		e.band_k = clampf(err.length() / 24.0, 0.35, 1.0)
		return e._chase_dir(at, delta)
	var base := route if route != Vector2.ZERO else facing
	var along: float = err.dot(facing)
	var side: Vector2 = err - facing * along
	e.band_k = clampf((pace * 0.95 + along * CATCH_UP) / e.speed, 0.0, MAX_PACE)
	return (base + (side / 24.0).limit_length(0.9)).normalized()
