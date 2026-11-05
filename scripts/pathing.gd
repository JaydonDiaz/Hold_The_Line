extends RefCounted
## Routes around barricades, for enemies and for your own troops.
## Enemies: the field is a grid of cells; for each enemy size a flow field gives every
## cell its cost to reach the bottom line. Cells a wall covers cost WALL_COST to
## cross, so enemies take any way around a wall and only head into one (to break it)
## when every route is sealed.
## Troops: walls are solid to them, so they get an A* route to wherever they're going.
## Everything is rebuilt lazily whenever a wall goes up, comes down or moves.

const CELL := 16
const WALL_COST := 2000.0
const DIAG := 1.4   # matches the 14-tenths diagonal step the fields are built with
const RING := 16    # open-ground steps cost at most 14 tenths, so 16 buckets go round
const HEAP_SPAN := 65536.0   # heap keys: cost * HEAP_SPAN + cell index (room for 65536 cells)
const TROOP_RADIUS := 18.0   # Warrior.RADIUS
const NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

var main
var cols := 0
var rows := 0
var walls := []    # standing barricades as of the last invalidate() (all solid to enemies)
var troop_walls := []   # the ones your troops can't walk through (not Phase Gates)
var shot_walls := []    # the ones your troops can't shoot through (not Arcane Lattices)
var fields := {}
var _emp := []          # _emplacements() for this frame
var _emp_frame := -1
var old_fields := {}   # the fields from before the walls last changed, by size
var _built_frame := -1   # enemy radius (int) -> {"dist", "breach", "wall"}
var troop_grid: AStarGrid2D = null
var troop_sig := []     # the emplacements troop_grid was built around (it's rebuilt when they change)
const POST_CLEAR := 28.0   # cells this close to an emplacement are solid to troops (a little under two radii)


func setup(m) -> void:
	main = m
	cols = ceili(float(m.FIELD_W) / CELL)
	rows = ceili(float(m.FIELD_H) / CELL)


## Call whenever a barricade is built, destroyed, sold or moved.
func invalidate() -> void:
	for key in fields:
		old_fields[key] = fields[key]   # stand-ins while the new ones are built (see _field)
	fields.clear()
	troop_grid = null
	walls = main.get_barricades().filter(func(b): return b.is_active())
	troop_walls = walls.filter(func(b): return not b.lets_troops())
	shot_walls = walls.filter(func(b): return not b.lets_shots())


func has_walls() -> bool:
	return not walls.is_empty()


func has_troop_walls() -> bool:
	return not troop_walls.is_empty()


## Whether a standing wall crosses the straight line from a to b (blocks a shot).
func wall_between(a: Vector2, b: Vector2) -> bool:
	for w in shot_walls:
		if Geometry2D.segment_intersects_segment(a, b, w.seg_a(), w.seg_b()) != null:
			return true
	return false


## Whether something `clearance` wide (its radius plus the wall's half thickness)
## would bump into a wall walking straight from a to b (troops: Phase Gates don't count).
func path_blocked(a: Vector2, b: Vector2, clearance: float, posts := false) -> bool:
	if posts:
		# Emplacements are solid too: is one in the way (not one it's stepping away from)?
		var ab := b - a
		var len2 := ab.length_squared()
		for e in _emplacements():
			var k := clampf((e.position - a).dot(ab) / len2, 0.0, 1.0) if len2 > 0.01 else 0.0
			if k > 0.0 and (a + ab * k).distance_to(e.position) < clearance + TROOP_RADIUS - 6.0:
				return true
	for w in troop_walls:
		var pts := Geometry2D.get_closest_points_between_segments(a, b, w.seg_a(), w.seg_b())
		if pts[0].distance_to(pts[1]) < clearance:
			return true
	return false


## Waypoints for a troop from `from` to `to` around the walls. If walls cut it off,
## the route ends as close as it can get.
func troop_route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var g := _troop_grid()
	var a := _free_near(g, _cell(from))
	var b := _free_near(g, _cell(to))
	var route := g.get_point_path(a, b, true)
	if not route.is_empty():
		route.remove_at(0)   # the cell it's standing in
	return route


## Emplacements standing on the field (troops walk around them).
func _emplacements() -> Array:
	var f := Engine.get_process_frames()
	if f != _emp_frame:
		_emp_frame = f
		_emp = main.get_warriors().filter(func(w): return w.is_emplacement() and w.is_active())
	return _emp


func has_emplacements() -> bool:
	return not _emplacements().is_empty()


func _troop_grid() -> AStarGrid2D:
	var sig := _emplacements().map(func(w): return Vector2i(w.position.round()))
	if troop_grid != null and sig == troop_sig:
		return troop_grid
	troop_sig = sig
	var g := AStarGrid2D.new()
	g.region = Rect2i(0, 0, cols, rows)
	g.cell_size = Vector2(CELL, CELL)
	g.offset = Vector2(CELL, CELL) / 2.0   # points sit at cell centers
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.update()
	# Like the enemy fields, a little narrower than a troop's real reach so the cell
	# it's standing in is never solid.
	var reach := maxf(TROOP_RADIUS + troop_walls[0].WALL_HALF - 12.0, 9.0) if not troop_walls.is_empty() else 0.0
	for w in troop_walls:
		var a: Vector2 = w.seg_a()
		var b: Vector2 = w.seg_b()
		var lo := _cell(Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(reach, reach))
		var hi := _cell(Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(reach, reach))
		for cy in range(lo.y, hi.y + 1):
			for cx in range(lo.x, hi.x + 1):
				var p := _center(Vector2i(cx, cy))
				if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < reach:
					g.set_point_solid(Vector2i(cx, cy))
	for pos in sig:
		var lo := _cell(Vector2(pos) - Vector2(POST_CLEAR, POST_CLEAR))
		var hi := _cell(Vector2(pos) + Vector2(POST_CLEAR, POST_CLEAR))
		for cy in range(lo.y, hi.y + 1):
			for cx in range(lo.x, hi.x + 1):
				var c := Vector2i(cx, cy)
				if _inside(c) and _center(c).distance_to(Vector2(pos)) < POST_CLEAR:
					g.set_point_solid(c)
	troop_grid = g
	return g


## The nearest open cell to c (c itself if it's open).
func _free_near(g: AStarGrid2D, c: Vector2i) -> Vector2i:
	if not g.is_point_solid(c):
		return c
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if _inside(n) and not g.is_point_solid(n):
					return n
	return c

## Which way an enemy of this size should walk from `pos`, or ZERO when there are
## no walls (enemies then just march straight down as usual).
func direction(pos: Vector2, radius: float) -> Vector2:
	if walls.is_empty():
		return Vector2.ZERO
	var f := _field(radius)
	var dist: PackedFloat64Array = f["dist"]
	var wall: PackedInt32Array = f["wall"]
	var c := _cell(pos)
	var best := c
	# A step costs what it says, so a neighbor on the best route ties with standing still.
	var best_cost: float = dist[_index(c)] + 0.001
	for d in NEIGHBORS:
		var n: Vector2i = c + d
		if not _inside(n) or not _can_step(c, d, wall):
			continue
		var cost: float = dist[_index(n)] + (DIAG if d.x != 0 and d.y != 0 else 1.0)
		if cost < best_cost:
			best_cost = cost
			best = n
	if best == c:
		return Vector2.DOWN
	return pos.direction_to(_center(best))


## The barricade an enemy at `pos` has to break through to reach the bottom line
## (the first one on its best route), or null if there's a way around every wall.
func breach_at(pos: Vector2, radius: float):
	if walls.is_empty():
		return null
	var f := _field(radius)
	var i: int = f["breach"][_index(_cell(pos))]
	if i < 0:
		return null
	var w = f["walls"][i]
	return w if is_instance_valid(w) and w.is_active() else null


func _field(radius: float) -> Dictionary:
	# Two sizes are enough: goblins, wolves and orcs share one field, trolls and
	# warlords the other. Each is built for the biggest enemy in its group.
	# Building one is the slow part of a wall going up or coming down, so only one is
	# built a frame: the other size makes do with its last field for a frame.
	var key := 14 if radius <= 14.0 else 24
	if not fields.has(key):
		var frame := Engine.get_process_frames()
		if frame == _built_frame and old_fields.has(key) and old_fields[key]["cols"] == cols:
			return old_fields[key]
		_built_frame = frame
		fields[key] = _build(key)
		old_fields.erase(key)
	return fields[key]


func _build(radius: float) -> Dictionary:
	var n := cols * rows
	# Mark the cells each wall covers. Slightly narrower than the enemy's real reach
	# so a cell an enemy is standing in is never counted as wall; gaps that are too
	# tight to squeeze through get caught by the enemy's stuck check instead.
	var wall := PackedInt32Array()
	wall.resize(n)
	wall.fill(-1)
	for i in walls.size():
		var a: Vector2 = walls[i].seg_a()
		var b: Vector2 = walls[i].seg_b()
		var reach := maxf(radius + walls[i].WALL_HALF - 10.0, 9.0)
		var lo := _cell(Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(reach, reach))
		var hi := _cell(Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(reach, reach))
		for cy in range(lo.y, hi.y + 1):
			for cx in range(lo.x, hi.x + 1):
				var p := _center(Vector2i(cx, cy))
				if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < reach:
					wall[cy * cols + cx] = i
	# Dijkstra out from the bottom row, in whole tenths of a cell: a step costs 10 (14
	# diagonally) on open ground, and 2000 times that into a wall cell. Open-ground
	# steps only ever reach 10 or 14 past the cell being settled, so they wait in a
	# ring of 16 buckets (no sorting at all); the rare steps into walls go on a small
	# heap. Each cell is settled once.
	var d10 := PackedInt64Array()
	d10.resize(n)
	d10.fill(1 << 62)
	var breach := PackedInt32Array()
	breach.resize(n)
	breach.fill(-1)
	var ring: Array[PackedInt32Array] = []
	for k in RING:
		ring.append(PackedInt32Array())
	var near := 0         # cells waiting in the ring
	var heap := PackedFloat64Array()   # wall steps: cost * HEAP_SPAN + cell
	var size := 0
	var wall_step := int(WALL_COST) * 10
	for cx in cols:
		var i := (rows - 1) * cols + cx
		breach[i] = wall[i]
		if wall[i] >= 0:
			d10[i] = wall_step
			size = _push(heap, size, float(wall_step) * HEAP_SPAN + i)
		else:
			d10[i] = 10
			ring[10 % RING].append(i)
			near += 1
	var dxs := PackedInt32Array([1, -1, 0, 0, 1, -1, 1, -1])
	var dys := PackedInt32Array([0, 0, 1, -1, 1, 1, -1, -1])
	var at := 0   # the cost being settled
	while near > 0 or size > 0:
		var batch := PackedInt32Array()
		if near > 0:
			var slot := at % RING
			batch = ring[slot]
			ring[slot] = PackedInt32Array()
			near -= batch.size()
		while size > 0 and floorf(heap[0] / HEAP_SPAN) <= at:
			batch.append(int(fmod(heap[0], HEAP_SPAN)))
			size = _pop(heap, size)
		for i in batch:
			if d10[i] != at:
				continue   # reached more cheaply since; already settled
			var cx := i % cols
			var cy := i / cols
			var from_breach := breach[i]
			for k in 8:
				var nx := cx + dxs[k]
				var ny := cy + dys[k]
				if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
					continue
				var step := 10
				if k >= 4:
					# Diagonal steps can't cut the corner between two wall cells.
					if wall[cy * cols + nx] >= 0 or wall[ny * cols + cx] >= 0:
						continue
					step = 14
				var j := ny * cols + nx
				var into_wall := wall[j] >= 0
				var nd := at + (step * int(WALL_COST) if into_wall else step)
				if nd < d10[j]:
					d10[j] = nd
					breach[j] = wall[j] if into_wall else from_breach
					if into_wall:
						size = _push(heap, size, float(nd) * HEAP_SPAN + j)
					else:
						ring[nd % RING].append(j)
						near += 1
		if near > 0:
			at += 1
		elif size > 0:
			at = int(floorf(heap[0] / HEAP_SPAN))   # nothing nearby: jump to the next wall step
	var dist := PackedFloat64Array()
	dist.resize(n)
	for i in n:
		dist[i] = d10[i] / 10.0
	return {"dist": dist, "breach": breach, "wall": wall, "walls": walls.duplicate(), "cols": cols}


## Diagonal steps can't cut the corner between two wall cells (that would slip
## through a diagonal wall).
func _can_step(c: Vector2i, d: Vector2i, wall: PackedInt32Array) -> bool:
	if d.x == 0 or d.y == 0:
		return true
	return wall[_index(Vector2i(c.x + d.x, c.y))] < 0 and wall[_index(Vector2i(c.x, c.y + d.y))] < 0


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / CELL), 0, cols - 1), clampi(int(p.y / CELL), 0, rows - 1))


func _center(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * CELL, (c.y + 0.5) * CELL)


func _index(c: Vector2i) -> int:
	return c.y * cols + c.x


func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


## Min-heap on a flat array; returns the new size.
func _push(heap: PackedFloat64Array, size: int, key: float) -> int:
	if size == heap.size():
		heap.resize(maxi(64, size * 2))
	var i := size
	while i > 0:
		var parent := (i - 1) / 2
		if heap[parent] <= key:
			break
		heap[i] = heap[parent]
		i = parent
	heap[i] = key
	return size + 1


## Removes the smallest key (heap[0]); returns the new size.
func _pop(heap: PackedFloat64Array, size: int) -> int:
	size -= 1
	if size == 0:
		return 0
	var last := heap[size]
	var i := 0
	while true:
		var l := i * 2 + 1
		if l >= size:
			break
		var m := l
		if l + 1 < size and heap[l + 1] < heap[l]:
			m = l + 1
		if heap[m] >= last:
			break
		heap[i] = heap[m]
		i = m
	heap[i] = last
	return size
