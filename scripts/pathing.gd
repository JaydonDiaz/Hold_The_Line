extends RefCounted
## Routes around barricades, for enemies and for your own troops.
## Enemies: the field is a grid of cells; for each enemy size a flow field gives every
## cell its cost to reach the bottom line. Cells a wall covers cost WALL_COST to
## cross, so enemies take any way around a wall and only head into one (to break it)
## when every route is sealed.
## Troops: walls are solid to them, so they get an A* route to wherever they're going.
## Everything is rebuilt lazily whenever a wall goes up, comes down or moves.
##
## Terrain (campaign maps, see maps.gd): rocks, cliffs, trees and pits block walking,
## for good. When a map is set, two grids are worked out once:
##   clear       per cell, the distance from its centre to the nearest terrain (0 inside),
##               so a unit only routes through cells with room for its own radius
##   troop_open  cells a troop can stand in and walk to from the castle gate
## Movement goes through slide(), which stops a step short of entering terrain by
## sliding along it; push_out() puts back anything that ended up overlapping (pushes,
## knockback) and is only the safety net. With no map, every terrain call returns at
## once and nothing behaves differently.
##
## Fords ("ford" shapes) are shallow water: not terrain, anyone can walk in, but wading is
## slow (wade_factor) and costs FORD_COST times as much in every route (the enemy fields,
## enemy chase routes, troop routes), so a ford is a real way across that's weighed against
## the long way round. "bridge" shapes are only art: a bridge is a gap left in the water.

const CELL := 16
const WALL_COST := 2000.0
const DIAG := 1.4   # matches the 14-tenths diagonal step the fields are built with
const RING := 16    # open-ground steps cost at most 14 tenths, so 16 buckets go round
const HEAP_SPAN := 65536.0   # heap keys: cost * HEAP_SPAN + cell index (room for 65536 cells)
const TROOP_RADIUS := 18.0   # Warrior.RADIUS
const SOLID := -2          # a field cell terrain makes impassable (walls are their index, open ground -1)
const FORD_COST := 2       # a step into a ford costs this many times one on dry ground (the time it takes: half speed)
const FORD_SLOW := 0.5     # ...and anyone wading it goes at this share of their speed
const NOT_TERRAIN := ["ford", "bridge"]   # map shapes that don't block (a ford is waded, a bridge is walked)
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
const HALF_DIAG := 11.32   # from a cell's centre to its corner: how far `clear` can be off anywhere in the cell
const MELEE_REACH := 36.0  # a cell is in melee reach if a troop can stand this close to its centre (radius 18 + an archer's 11 + a blow's 8, less a little)

var objectives := []       # the mission's objectives (mission/objective.gd): goals for enemy fields
var solid_objs := []       # the standing structures among them (solid to enemies and troops), as of the last invalidate()
var terrain := []          # {"kind", "poly": PackedVector2Array, "box": Rect2}
var fords := []            # PackedVector2Array: the fords' shapes
var wade := PackedByteArray()   # per cell: 1 if its centre is in a ford (empty: no fords)
var lanes := []            # Vector2(x from, x to) along the top edge where enemies come in
var no_build := []         # Rect2s nothing may be posted in
var clear := PackedFloat32Array()
var troop_open := PackedByteArray()
var melee_reach := PackedByteArray()   # cells a melee troop can get within striking distance of
var enemy_grids := {}      # size key -> AStarGrid2D for enemies chasing a unit around terrain
# Per cell, the terrain edges that could be the nearest to any point in it (flat: a, b,
# a, b, ...) and the shapes they belong to, so a distance check looks at a couple of
# edges rather than every edge on the map. Built with `clear`.
var cell_edges: Array = []
var cell_shapes: Array = []
var _map := {}


func setup(m) -> void:
	main = m
	cols = ceili(float(m.FIELD_W) / CELL)
	rows = ceili(float(m.FIELD_H) / CELL)
	if not _map.is_empty():
		set_map(_map)


# --- Terrain ---------------------------------------------------------------------------

## Lays out a battlefield (a maps.gd entry), or clears it with {}: stretched across the
## field's width as it is now (set again whenever the field changes width).
func set_map(raw: Dictionary) -> void:
	_map = raw
	var m: Dictionary = preload("res://scripts/maps.gd").fitted(raw, main.FIELD_W)
	terrain.clear()
	lanes.clear()
	no_build = m.get("no_build", []).duplicate()
	for l in m.get("lanes", []):
		lanes.append(Vector2(l[0], l[1]))
	fords.clear()
	for t in m.get("terrain", []):
		var poly := PackedVector2Array(t["poly"])
		if t["kind"] in NOT_TERRAIN:
			if t["kind"] == "ford":
				fords.append(poly)
			continue
		var lo := poly[0]
		var hi := poly[0]
		for q in poly:
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
		terrain.append({"kind": t["kind"], "poly": poly, "box": Rect2(lo, hi - lo)})
	_build_clearance()
	wade = PackedByteArray()
	if not fords.is_empty():
		wade.resize(cols * rows)
		for i in cols * rows:
			var c := _center(Vector2i(i % cols, i / cols))
			for f in fords:
				if Geometry2D.is_point_in_polygon(c, f):
					wade[i] = 1
	enemy_grids.clear()
	for key in fields:
		old_fields.erase(key)
	fields.clear()
	old_fields.clear()
	troop_grid = null


func has_terrain() -> bool:
	return not terrain.is_empty()


## Whether p is in a ford.
func in_ford(p: Vector2) -> bool:
	if wade.is_empty():
		return false
	for f in fords:
		if Geometry2D.is_point_in_polygon(p, f):
			return true
	return false


## How fast something walking at p goes: slower wading a ford.
func wade_factor(p: Vector2) -> float:
	return FORD_SLOW if not wade.is_empty() and wade[_index(_cell(p))] == 1 and in_ford(p) else 1.0


## Exact distance from p to the nearest terrain (0 if it's inside some), or INF with none.
## Looks only at the edges near p's cell (see cell_edges).
func terrain_gap(p: Vector2) -> float:
	if terrain.is_empty():
		return INF
	if cell_edges.is_empty():
		return _terrain_gap_full(p)
	var i := _index(_cell(p))
	for k in cell_shapes[i]:
		if Geometry2D.is_point_in_polygon(p, terrain[k]["poly"]):
			return 0.0
	var e: PackedVector2Array = cell_edges[i]
	var best := INF
	for j in range(0, e.size(), 2):
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, e[j], e[j + 1]).distance_to(p))
	return best


## The nearest point on any terrain edge to p (for pushing a unit back out of it).
func _nearest_edge_point(p: Vector2) -> Vector2:
	var i := _index(_cell(p))
	var e: PackedVector2Array = cell_edges[i] if not cell_edges.is_empty() else PackedVector2Array()
	var best := p
	var best_d := INF
	for j in range(0, e.size(), 2):
		var c := Geometry2D.get_closest_point_to_segment(p, e[j], e[j + 1])
		var d := c.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = c
	return best


func _inside_terrain(p: Vector2) -> bool:
	for k in cell_shapes[_index(_cell(p))]:
		if Geometry2D.is_point_in_polygon(p, terrain[k]["poly"]):
			return true
	return false


func _terrain_gap_full(p: Vector2) -> float:
	var best := INF
	for t in terrain:
		var poly: PackedVector2Array = t["poly"]
		if Geometry2D.is_point_in_polygon(p, poly):
			return 0.0
		var box: Rect2 = t["box"]
		# Nothing in this shape can be nearer than its bounding box.
		var bd := Vector2(maxf(maxf(box.position.x - p.x, p.x - box.end.x), 0.0), maxf(maxf(box.position.y - p.y, p.y - box.end.y), 0.0)).length()
		if bd >= best:
			continue
		for i in poly.size():
			var c := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
			best = minf(best, c.distance_to(p))
	return best


## Whether a unit of radius r standing at p would overlap terrain.
func blocked(p: Vector2, r: float) -> bool:
	if terrain.is_empty():
		return false
	var c := _cell(p)
	var room: float = clear[_index(c)]
	if room - HALF_DIAG >= r:
		return false   # the common case: open ground all round, no geometry needed
	return terrain_gap(p) < r


## Whether something of radius r walking straight from a to b would touch terrain:
## checked every 6px along the way (far finer than any terrain is thin).
func segment_blocked(a: Vector2, b: Vector2, r: float) -> bool:
	if terrain.is_empty():
		return false
	if not cell_edges.is_empty():
		var steps := maxi(1, ceili(a.distance_to(b) / 6.0))
		for k in steps + 1:
			if blocked(a.lerp(b, float(k) / steps), r):
				return true
		return false
	return _segment_blocked_full(a, b, r)


func _segment_blocked_full(a: Vector2, b: Vector2, r: float) -> bool:
	var span := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs()).grow(r)
	for t in terrain:
		if not span.intersects(t["box"]):
			continue
		var poly: PackedVector2Array = t["poly"]
		if Geometry2D.is_point_in_polygon(a, poly) or Geometry2D.is_point_in_polygon(b, poly):
			return true
		for i in poly.size():
			var pts := Geometry2D.get_closest_points_between_segments(a, b, poly[i], poly[(i + 1) % poly.size()])
			if pts[0].distance_to(pts[1]) < r:
				return true
	return false


## The safety net: p moved the least distance that leaves a radius-r unit clear of all
## terrain (out of a shape it's inside, or off an edge it overlaps).
func push_out(p: Vector2, r: float) -> Vector2:
	if terrain.is_empty() or not blocked(p, r):
		return p
	if not cell_edges.is_empty():
		# Out along the nearest edge's normal, a couple of times for corners.
		for pass_ in 3:
			var c := _nearest_edge_point(p)
			var inside := _inside_terrain(p)
			var d := c.distance_to(p)
			if not inside and d >= r:
				break
			var out := (c - p) if inside else (p - c)
			if out.length() < 0.001:
				out = Vector2.DOWN
			p = c + out.normalized() * (r + 0.5)
			if not blocked(p, r):
				break
		return p
	for pass_ in 3:
		var moved := false
		for t in terrain:
			var box: Rect2 = t["box"]
			if not box.grow(r).has_point(p):
				continue
			var poly: PackedVector2Array = t["poly"]
			var inside := Geometry2D.is_point_in_polygon(p, poly)
			var best := Vector2.ZERO
			var best_d := INF
			for i in poly.size():
				var c := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
				var d := c.distance_to(p)
				if d < best_d:
					best_d = d
					best = c
			if not inside and best_d >= r:
				continue
			var out: Vector2
			if inside:
				out = best - p   # from inside, out through the nearest edge
			else:
				out = p - best
			if out.length() < 0.001:
				out = Vector2.DOWN
			p = best + out.normalized() * (r + 0.5)
			moved = true
		if not moved:
			break
	return p


## Where a radius-r unit stepping from `from` toward `to` ends up: `to` if that's clear,
## else slid along the terrain it would have walked into, else it stays put. Steps are
## a few pixels, far thinner than any terrain, so nothing tunnels through.
func slide(from: Vector2, to: Vector2, r: float) -> Vector2:
	if terrain.is_empty() or not blocked(to, r):
		return to
	var q := push_out(to, r)
	if blocked(q, r) or q.distance_to(from) > from.distance_to(to) + 2.0:
		return from   # wedged in a corner: don't move
	return q


## Whether p is open ground a troop could reach from the castle gate.
func troop_can_stand(p: Vector2) -> bool:
	if terrain.is_empty():
		return true
	if blocked(p, TROOP_RADIUS):
		return false
	# Room right here, and joined to the reachable ground: its cell is open, or (hard
	# against rock, where the cell's centre is too tight) a neighbouring cell is.
	var c := _cell(p)
	if troop_open[_index(c)] == 1:
		return true
	for d in NEIGHBORS:
		var n: Vector2i = c + d
		if _inside(n) and troop_open[_index(n)] == 1 and not segment_blocked(p, _center(n), TROOP_RADIUS - 2.0):
			return true
	return false


## Whether p is close in by terrain (a gap, a cliff foot) for something of radius r:
## there a crowd moves through in order rather than shoving sideways.
func tight(p: Vector2, r: float) -> bool:
	return not terrain.is_empty() and clear[_index(_cell(p))] < r + 28.0


## Whether melee troops can get close enough to strike something standing at p.
func melee_can_reach(p: Vector2) -> bool:
	if terrain.is_empty():
		return true
	return melee_reach[_index(_cell(p))] == 1


## The nearest spot to p a troop could stand on and reach (p itself if it's fine).
func open_spot(p: Vector2) -> Vector2:
	if terrain.is_empty() or troop_can_stand(p):
		return p
	var c := _cell(p)
	var best := p
	var best_d := INF
	for r in range(1, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue   # just the ring
				var n := c + Vector2i(dx, dy)
				if not _inside(n) or troop_open[_index(n)] == 0:
					continue
				var q := _center(n)
				var d := q.distance_to(p)
				if d < best_d:
					best_d = d
					best = q
		if best_d < INF:
			break
	return best


## Whether p is in one of the map's no-build zones.
func in_no_build(p: Vector2) -> bool:
	for z in no_build:
		if z.has_point(p):
			return true
	return false


## A random spot along one of the map's lanes for an enemy of radius r to come in at,
## or INF with no lanes (then it comes in anywhere along the top).
func lane_spawn(r: float) -> Vector2:
	if lanes.is_empty():
		return Vector2.INF
	var total := 0.0
	for l in lanes:
		total += maxf(l.y - l.x - 2.0 * r, 1.0)
	var pick := randf() * total
	for l in lanes:
		var w := maxf(l.y - l.x - 2.0 * r, 1.0)
		if pick <= w:
			return Vector2(l.x + r + pick, -r)
		pick -= w
	return Vector2((lanes[0].x + lanes[0].y) / 2.0, -r)


## Waypoints for an enemy of radius r from `from` to `to` around terrain (walls aside:
## it breaks those). Empty if there's no way.
func enemy_route(from: Vector2, to: Vector2, r: float) -> PackedVector2Array:
	var key := _size_key(r)
	if not enemy_grids.has(key):
		var g := AStarGrid2D.new()
		g.region = Rect2i(0, 0, cols, rows)
		g.cell_size = Vector2(CELL, CELL)
		g.offset = Vector2(CELL, CELL) / 2.0
		g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		g.update()
		for i in cols * rows:
			if clear[i] < key:
				g.set_point_solid(Vector2i(i % cols, i / cols))
			elif not wade.is_empty() and wade[i] == 1:
				g.set_point_weight_scale(Vector2i(i % cols, i / cols), FORD_COST)
		enemy_grids[key] = g
	var grid: AStarGrid2D = enemy_grids[key]
	var a := _free_near(grid, _cell(from))
	var b := _free_near(grid, _cell(to))
	var route := grid.get_point_path(a, b, true)
	if not route.is_empty():
		route.remove_at(0)
	return route


## Enemies are routed in three sizes: up to an orc's, up to a warlord's, and bigger.
func _size_key(r: float) -> int:
	return 14 if r <= 14.0 else (24 if r <= 24.0 else 32)


func _build_clearance() -> void:
	var n := cols * rows
	clear = PackedFloat32Array()
	clear.resize(n)
	troop_open = PackedByteArray()
	troop_open.resize(n)
	melee_reach = PackedByteArray()
	melee_reach.resize(n)
	if terrain.is_empty():
		clear.fill(INF)
		troop_open.fill(1)
		melee_reach.fill(1)
		cell_edges = []
		cell_shapes = []
		return
	for i in n:
		clear[i] = _terrain_gap_full(_center(Vector2i(i % cols, i / cols)))
	# Each cell's nearby edges: any edge that could be nearest to some point in the cell.
	var edges := []   # [a, b, shape]
	for k in terrain.size():
		var poly: PackedVector2Array = terrain[k]["poly"]
		for j in poly.size():
			edges.append([poly[j], poly[(j + 1) % poly.size()], k])
	cell_edges = []
	cell_shapes = []
	cell_edges.resize(n)
	cell_shapes.resize(n)
	for i in n:
		var c := _center(Vector2i(i % cols, i / cols))
		var nearest := INF
		for e in edges:
			nearest = minf(nearest, Geometry2D.get_closest_point_to_segment(c, e[0], e[1]).distance_to(c))
		var list := PackedVector2Array()
		var shapes := []
		for e in edges:
			if Geometry2D.get_closest_point_to_segment(c, e[0], e[1]).distance_to(c) <= nearest + 2.0 * HALF_DIAG + 0.5:
				list.append(e[0])
				list.append(e[1])
				if not shapes.has(e[2]):
					shapes.append(e[2])
		cell_edges[i] = list
		cell_shapes[i] = shapes
	# Troops: open ground below the enemy camp, flooded out from the castle gate.
	var top := int(ceilf((main.DEPLOY_TOP + TROOP_RADIUS) / float(CELL)))
	var gate := _cell(Vector2(main.FIELD_W / 2.0, main.CASTLE_Y - TROOP_RADIUS))
	var stack := [gate]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		var i := _index(c)
		if troop_open[i] == 1 or clear[i] < TROOP_RADIUS or c.y < top:
			continue
		troop_open[i] = 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = c + d
			if _inside(nb):
				stack.append(nb)
	# Melee reach: within MELEE_REACH of a cell a troop can stand in.
	var span := ceili(MELEE_REACH / CELL)
	for i in n:
		if troop_open[i] == 0:
			continue
		var c := Vector2i(i % cols, i / cols)
		for dy in range(-span, span + 1):
			for dx in range(-span, span + 1):
				var nb := c + Vector2i(dx, dy)
				if _inside(nb) and _center(nb).distance_to(_center(c)) <= MELEE_REACH:
					melee_reach[_index(nb)] = 1


## Call whenever a barricade is built, destroyed, sold or moved.
func invalidate() -> void:
	for key in fields:
		old_fields[key] = fields[key]   # stand-ins while the new ones are built (see _field)
	fields.clear()
	troop_grid = null
	solid_objs = objectives.filter(func(o): return is_instance_valid(o) and o.is_solid())
	walls = main.get_barricades().filter(func(b): return b.is_active())
	troop_walls = walls.filter(func(b): return not b.lets_troops())
	shot_walls = walls.filter(func(b): return not b.lets_shots())


func has_walls() -> bool:
	return not walls.is_empty()


func has_troop_walls() -> bool:
	return not troop_walls.is_empty()


## Whether a standing wall crosses the straight line from a to b (blocks a shot).
## Whether any wall at all (a Phase Gate, an Arcane Lattice too) crosses the line a-b.
func any_wall_between(a: Vector2, b: Vector2) -> bool:
	for w in walls:
		if is_instance_valid(w) and Geometry2D.segment_intersects_segment(a, b, w.seg_a(), w.seg_b()) != null:
			return true
	return false


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
		for o in solid_objs:
			if is_instance_valid(o) and o.is_solid():
				var k := clampf((o.position - a).dot(ab) / len2, 0.0, 1.0) if len2 > 0.01 else 0.0
				if (a + ab * k).distance_to(o.position) < o.RADIUS + clearance - 6.0:
					return true
	for w in troop_walls:
		var pts := Geometry2D.get_closest_points_between_segments(a, b, w.seg_a(), w.seg_b())
		if pts[0].distance_to(pts[1]) < clearance:
			return true
	return segment_blocked(a, b, minf(clearance, TROOP_RADIUS))


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
	return not _emplacements().is_empty() or not solid_objs.is_empty()


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
	if not terrain.is_empty():
		for i in cols * rows:
			if troop_open[i] == 0:
				g.set_point_solid(Vector2i(i % cols, i / cols))
			elif not wade.is_empty() and wade[i] == 1:
				g.set_point_weight_scale(Vector2i(i % cols, i / cols), FORD_COST)
	for o in _live_objectives():
		var r: float = o.RADIUS + 10.0
		var olo := _cell(o.position - Vector2(r, r))
		var ohi := _cell(o.position + Vector2(r, r))
		for cy in range(olo.y, ohi.y + 1):
			for cx in range(olo.x, ohi.x + 1):
				var c := Vector2i(cx, cy)
				if _inside(c) and _center(c).distance_to(o.position) < r:
					g.set_point_solid(c)
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
	for r in range(1, 8 if not terrain.is_empty() else 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if _inside(n) and not g.is_point_solid(n):
					return n
	return c

## The mission's objectives (enemies walk round them, and to the one they're sent for).
func set_objectives(list: Array) -> void:
	objectives = list
	invalidate()


func _live_objectives() -> Array:
	return solid_objs.filter(func(o): return is_instance_valid(o) and o.is_solid())


## Which way an enemy of this size should walk from `pos` (to the bottom line, or to
## objective `goal`), or ZERO when there's nothing in the way (enemies then just march
## straight down as usual, or straight at their goal).
func direction(pos: Vector2, radius: float, goal = null) -> Vector2:
	if walls.is_empty() and terrain.is_empty() and solid_objs.is_empty():
		return Vector2.ZERO
	var f := _field(radius, goal)
	var wall: PackedInt32Array = f["wall"]
	var c := _cell(pos)
	var best := _best_step(f, c)
	if best == c and goal != null and is_instance_valid(goal):
		return pos.direction_to(goal.position)   # arrived where its objective is in reach: close in on it
	if best == c:
		if not terrain.is_empty() and wall[_index(c)] == SOLID:
			# Squeezed into a cell too tight for it: back out away from the terrain.
			var away := push_out(pos, radius + HALF_DIAG) - pos
			if away.length() > 0.01:
				return away.normalized()
		return Vector2.DOWN
	if not terrain.is_empty() and wall[_index(c)] != SOLID and wall[_index(best)] != SOLID:
		# Head along the line between the two cell centres (not straight at the next
		# one), so the unit stays on the route the field was worked out for.
		var aim := _center(best) + (pos - _center(c)) * 0.5
		return pos.direction_to(aim)
	return pos.direction_to(_center(best))


## The neighbouring cell to step to from c on field f (c itself if none is better),
## worked out once per cell and kept with the field.
func _best_step(f: Dictionary, c: Vector2i) -> Vector2i:
	var i := _index(c)
	var nxt: PackedInt32Array = f["next"]
	if nxt[i] != -2:
		return Vector2i(nxt[i] % cols, nxt[i] / cols)
	var dist: PackedFloat64Array = f["dist"]
	var wall: PackedInt32Array = f["wall"]
	var best := c
	# A step costs what it says, so a neighbor on the best route ties with standing still.
	var best_cost: float = dist[i] + 0.001
	for d in NEIGHBORS:
		var n: Vector2i = c + d
		if not _inside(n) or not _can_step(c, d, wall) or wall[_index(n)] == SOLID:
			continue
		var cost: float = dist[_index(n)] + (DIAG if d.x != 0 and d.y != 0 else 1.0)
		if cost < best_cost:
			best_cost = cost
			best = n
	nxt[i] = _index(best)
	return best


## The barricade an enemy at `pos` has to break through to reach the bottom line
## (the first one on its best route), or null if there's a way around every wall.
func breach_at(pos: Vector2, radius: float, goal = null):
	if walls.is_empty():
		return null
	var f := _field(radius, goal)
	var i: int = f["breach"][_index(_cell(pos))]
	if i < 0:
		return null
	var w = f["walls"][i]
	return w if is_instance_valid(w) and w.is_active() else null


func _field(radius: float, goal = null) -> Dictionary:
	# Two sizes are enough: goblins, wolves and orcs share one field, trolls and
	# warlords the other. Each is built for the biggest enemy in its group.
	# Building one is the slow part of a wall going up or coming down, so only one is
	# built a frame: the other size makes do with its last field for a frame.
	# Enemies sent for an objective have fields of their own, one per objective (and size).
	var size := (14 if radius <= 14.0 else 24) if terrain.is_empty() else _size_key(radius)
	var key = size if goal == null else "%d|%d" % [size, goal.get_instance_id()]
	if not fields.has(key):
		var frame := Engine.get_process_frames()
		if frame == _built_frame and old_fields.has(key) and old_fields[key]["cols"] == cols:
			return old_fields[key]
		_built_frame = frame
		fields[key] = _build(size, goal)
		old_fields.erase(key)
	return fields[key]


func _build(radius: float, goal = null) -> Dictionary:
	var n := cols * rows
	# Mark the cells each wall covers. Slightly narrower than the enemy's real reach
	# so a cell an enemy is standing in is never counted as wall; gaps that are too
	# tight to squeeze through get caught by the enemy's stuck check instead.
	var wall := PackedInt32Array()
	wall.resize(n)
	wall.fill(-1)
	if not terrain.is_empty():
		for i in n:
			if clear[i] < radius:
				wall[i] = SOLID   # too tight for this size, for good
	# Standing objectives are solid (an enemy walks round one it isn't after, and stops at
	# the edge of the one it is).
	for o in _live_objectives():
		var r: float = o.RADIUS + radius * 0.5
		var lo := _cell(o.position - Vector2(r, r))
		var hi := _cell(o.position + Vector2(r, r))
		for cy in range(lo.y, hi.y + 1):
			for cx in range(lo.x, hi.x + 1):
				var c := Vector2i(cx, cy)
				if _inside(c) and _center(c).distance_to(o.position) < r:
					wall[_index(c)] = SOLID
	for i in walls.size():
		var a: Vector2 = walls[i].seg_a()
		var b: Vector2 = walls[i].seg_b()
		var reach := maxf(radius + walls[i].WALL_HALF - 10.0, 9.0)
		var lo := _cell(Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(reach, reach))
		var hi := _cell(Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(reach, reach))
		for cy in range(lo.y, hi.y + 1):
			for cx in range(lo.x, hi.x + 1):
				var p := _center(Vector2i(cx, cy))
				if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < reach and wall[cy * cols + cx] != SOLID:
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
	# Where the field leads: the bottom row, or the ring of cells round the goal objective.
	var seeds := PackedInt32Array()
	if goal == null:
		for cx in cols:
			seeds.append((rows - 1) * cols + cx)
	else:
		var r_in: float = goal.RADIUS + radius * 0.5
		var r_out: float = r_in + CELL * 1.5
		var lo := _cell(goal.position - Vector2(r_out, r_out))
		var hi := _cell(goal.position + Vector2(r_out, r_out))
		for cy in range(lo.y, hi.y + 1):
			for cx in range(lo.x, hi.x + 1):
				var c := Vector2i(cx, cy)
				var dd := _center(c).distance_to(goal.position)
				if _inside(c) and dd >= r_in and dd < r_out:
					seeds.append(_index(c))
	var fording := not wade.is_empty()
	for i in seeds:
		if wall[i] == SOLID:
			continue
		breach[i] = wall[i]
		if fording and wade[i] == 1 and wall[i] < 0:
			d10[i] = 10 * FORD_COST
			size = _push(heap, size, float(d10[i]) * HEAP_SPAN + i)
		elif wall[i] >= 0:
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
					# Diagonal steps can't cut the corner between two wall (or terrain) cells.
					if wall[cy * cols + nx] != -1 or wall[ny * cols + cx] != -1:
						continue
					step = 14
				var j := ny * cols + nx
				if wall[j] == SOLID:
					continue
				var into_wall := wall[j] >= 0
				var wading := fording and wade[j] == 1
				var nd := at + (step * int(WALL_COST) if into_wall else (step * FORD_COST if wading else step))
				if nd < d10[j]:
					d10[j] = nd
					breach[j] = wall[j] if into_wall else from_breach
					if into_wall or wading:   # (beyond the ring's reach: on the heap)
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
	var nxt := PackedInt32Array()
	nxt.resize(n)
	nxt.fill(-2)   # each cell's best next step, filled in as enemies ask (see _best_step)
	return {"dist": dist, "breach": breach, "wall": wall, "walls": walls.duplicate(), "cols": cols, "next": nxt}


## Diagonal steps can't cut the corner between two wall cells (that would slip
## through a diagonal wall).
func _can_step(c: Vector2i, d: Vector2i, wall: PackedInt32Array) -> bool:
	if d.x == 0 or d.y == 0:
		return true
	return wall[_index(Vector2i(c.x + d.x, c.y))] == -1 and wall[_index(Vector2i(c.x, c.y + d.y))] == -1


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
