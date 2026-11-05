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
const DIAG := 1.4142
const TROOP_RADIUS := 18.0   # Warrior.RADIUS
const NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

var main
var cols := 0
var rows := 0
var walls := []    # standing barricades as of the last invalidate() (all solid to enemies)
var troop_walls := []   # the ones your troops can't walk through (not Phase Gates)
var shot_walls := []    # the ones your troops can't shoot through (not Arcane Lattices)
var fields := {}   # enemy radius (int) -> {"dist", "breach", "wall"}
var troop_grid: AStarGrid2D = null


func setup(m) -> void:
	main = m
	cols = ceili(float(m.FIELD_W) / CELL)
	rows = ceili(float(m.FIELD_H) / CELL)


## Call whenever a barricade is built, destroyed, sold or moved.
func invalidate() -> void:
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
func path_blocked(a: Vector2, b: Vector2, clearance: float) -> bool:
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


func _troop_grid() -> AStarGrid2D:
	if troop_grid != null:
		return troop_grid
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
	return walls[i] if i >= 0 else null


func _field(radius: float) -> Dictionary:
	# Two sizes are enough: goblins, wolves and orcs share one field, trolls and
	# warlords the other. Each is built for the biggest enemy in its group.
	var key := 14 if radius <= 14.0 else 24
	if not fields.has(key):
		fields[key] = _build(key)
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
	# Dijkstra out from the bottom row. Heap entries pack cost and cell into one
	# number (cost in thousandths, then the cell index) so the heap is a flat array.
	var dist := PackedFloat64Array()
	dist.resize(n)
	dist.fill(INF)
	var breach := PackedInt32Array()
	breach.resize(n)
	breach.fill(-1)
	var heap := PackedFloat64Array()
	var size := 0
	var dxs := PackedInt32Array([1, -1, 0, 0, 1, -1, 1, -1])
	var dys := PackedInt32Array([0, 0, 1, -1, 1, 1, -1, -1])
	for cx in cols:
		var i := (rows - 1) * cols + cx
		dist[i] = WALL_COST if wall[i] >= 0 else 1.0
		breach[i] = wall[i]
		size = _push(heap, size, _key(dist[i], i))
	while size > 0:
		var top := heap[0]
		size = _pop(heap, size)
		var i := int(fmod(top, 4096.0))
		if floorf(dist[i] * 1000.0) < floorf(top / 4096.0):
			continue   # a stale entry; this cell was reached more cheaply since
		var cx := i % cols
		var cy := i / cols
		for k in 8:
			var nx := cx + dxs[k]
			var ny := cy + dys[k]
			if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
				continue
			var step := 1.0
			if k >= 4:
				# Diagonal steps can't cut the corner between two wall cells.
				if wall[cy * cols + nx] >= 0 or wall[ny * cols + cx] >= 0:
					continue
				step = DIAG
			var j := ny * cols + nx
			var nd: float = dist[i] + step * (WALL_COST if wall[j] >= 0 else 1.0)
			if nd < dist[j]:
				dist[j] = nd
				breach[j] = wall[j] if wall[j] >= 0 else breach[i]
				size = _push(heap, size, _key(nd, j))
	return {"dist": dist, "breach": breach, "wall": wall}


func _key(cost: float, i: int) -> float:
	return floorf(cost * 1000.0) * 4096.0 + i


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
