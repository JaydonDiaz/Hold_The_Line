extends RefCounted
## Formations (troops/formation.gd): making, moving, turning, saving and loading them, following,
## and selling or deselecting units.
## Part of the game controller: `main` is main.gd, which holds the battle's state.

const Main = preload("res://scripts/main.gd")
const Warrior = preload("res://scripts/troops/warrior.gd")
const Barricade = preload("res://scripts/troops/barricade.gd")
const Formation = preload("res://scripts/troops/formation.gd")

var main: Main

var formations: Array = []  # the formations on the field (see formation.gd)
var formations_path := "user://formations.cfg"   # the player's saved formations ("" in tests: none)
var _formation_id := 0
var _formation_t := 0.0


func _init(m: Main) -> void:
	main = m


## Tells `units` to follow objective `o` (a wagon, civilians), each keeping its place
## around it (spread round it if they were all bunched up); null: back to a fixed post.
# --- Formations (formation.gd) -----------------------------------------------------------


func formation_of(w):
	for f in formations:
		if f.slots.has(w):
			return f
	return null


func _formations_of(units: Array) -> Array:
	var out := []
	for w in units:
		var f = formation_of(w)
		if f != null and not out.has(f):
			out.append(f)
	return out


## Makes `units` a formation laid out as `layout` (a preset), round where they are now (an
## escort: round the wagon or ram nearest them). They walk to their places.
func make_formation(units: Array, layout: String) -> Object:
	units = units.filter(func(w): return is_instance_valid(w) and not w.is_emplacement() and not w.wall_guard and not w.summoned and w.clone_of == null)
	if units.is_empty():
		return null
	leave_formation(units)
	var f = Formation.new()
	_formation_id += 1
	f.id = _formation_id
	var mid := Vector2.ZERO
	for w in units:
		mid += w.post
	mid /= units.size()
	f.anchor = mid
	var r := 30.0
	if layout == "escort":
		var best = null
		for o in main.rules.followable():
			if o.is_mover() and (best == null or o.position.distance_to(mid) < best.position.distance_to(mid)):
				best = o
		if best == null:
			main.hud.show_message("Nothing here to escort")
			return null
		f.follow = best
		f.anchor = best.position
		r = float(best.RADIUS)
		f.facing = _mover_heading(best, Vector2.UP)
	f.lay_out(layout, units, r)
	formations.append(f)
	_place_formation(f, true)
	main.effects.spawn_text(mid + Vector2(0, -50), Formation.NAMES[layout], Color(0.7, 0.95, 1.0))
	main.effects.sfx("place", 1.3)
	return f


func leave_formation(units: Array) -> void:
	for f in formations:
		for w in units:
			f.slots.erase(w)
			f.travel_slots.erase(w)
	formations = formations.filter(func(f): return not f.members().is_empty())


## Each member's post from its slot (an escort's: its place round what it follows). `walk`:
## they're ordered there (straight away, nothing on the way); else posts just move.
func _place_formation(f, walk: bool) -> void:
	var taken := []
	for w in f.members():
		var off: Vector2 = f.slot_of(w)
		if f.follow != null:
			w.anchor = f.follow
			w.anchor_off = f.world(off) - f.anchor
			w.anchor_check = 0.0
			continue
		w.anchor = null
		var want: Vector2 = main.hiring._clamp_post(f.world(off))
		var spot := _free_spot_for(want, taken, f)
		if spot == Vector2.INF:
			spot = main.paths.open_spot(want)
		taken.append(spot)
		if walk:
			var was: Vector2 = w.post
			w.order_to(spot)
			if w.guard_area.has_area():
				w.guard_area.position += spot - was
		elif w.post.distance_to(spot) > Formation.POST_MOVE and not w.ordered:
			if w.guard_area.has_area():
				w.guard_area.position += spot - w.post
			w.post = spot


## Like _free_spot, but the formation's own members' posts don't count as taken.
func _free_spot_for(p: Vector2, taken: Array, f) -> Vector2:
	var keep := main.group
	main.group = f.members()
	var q := main.groups._free_spot(p, taken)
	main.group = keep
	return q


func move_formation(f, p: Vector2) -> void:
	f.follow = null
	for w in f.members():
		w.anchor = null
	f.anchor = main.hiring._clamp_post(p)
	_place_formation(f, true)
	main.effects.sfx("place", 1.3)


## Turns the formation `units` are in (all of them that are) by `angle`.
func turn_formation(units: Array, angle: float) -> void:
	for f in _formations_of(units):
		f.turn(angle)
		_place_formation(f, f.follow == null)


## The player set one member's post by hand: that's its slot now (the formation's custom).
func _slot_moved(w) -> void:
	var f = formation_of(w)
	if f == null or f.follow != null:
		return
	f.slots[w] = f.local(w.post)
	f.layout = "custom"


## After the posts were moved as a whole (a group dragged): the anchor goes with them.
func _refit_anchor(f) -> void:
	var ms: Array = f.members()
	if ms.is_empty() or f.follow != null:
		return
	var off := Vector2.ZERO
	for w in ms:
		off += w.post - f.world(f.slot_of(w))
	f.anchor += off / ms.size()


## Which way a wagon or ram is rolling (`fallback` if it's standing).
func _mover_heading(o, fallback: Vector2) -> Vector2:
	if "route" in o and "leg" in o and o.leg < o.route.size():
		var d: Vector2 = o.route[o.leg] - o.position
		if d.length() > 1.0:
			return d.normalized()
	return fallback


## A few times a second: formations that go with something follow it (faced the way it
## rolls, a little ahead of it), members gone are let go, and posts follow slots.
func _formations_step(delta: float) -> void:
	_formation_t -= delta
	if _formation_t > 0.0 or formations.is_empty():
		return
	_formation_t = 0.25
	for f in formations.duplicate():
		for w in f.slots.keys():
			if not is_instance_valid(w) or w.is_queued_for_deletion():
				f.slots.erase(w)
				f.travel_slots.erase(w)
		if f.members().is_empty():
			formations.erase(f)
			continue
		if f.follow != null:
			if not is_instance_valid(f.follow) or f.follow.is_queued_for_deletion():
				f.follow = null
				continue
			var head: Vector2 = _mover_heading(f.follow, f.facing)
			f.facing = f.facing.slerp(head, 0.35).normalized()   # (turned smoothly as it turns)
			f.anchor = f.follow.position
			for w in f.members():
				if w.anchor != f.follow:
					continue   # (given its own orders since)
				var off: Vector2 = f.world(f.slot_of(w)) - f.anchor
				if off.distance_to(w.anchor_off) > Formation.POST_MOVE:
					w.anchor_off = off


## A troop back from a record (a new room, a loaded save) takes up its slot in its
## formation again (the formation made afresh, round it, if it's the first back).
func join_formation(w, d: Dictionary) -> void:
	var id := int(d.get("id", 0))
	var f = null
	for g in formations:
		if g.id == id:
			f = g
	var off := Vector2(d.get("slot", [0.0, 0.0])[0], d.get("slot", [0.0, 0.0])[1])
	if f == null:
		f = Formation.new()
		f.id = id
		_formation_id = maxi(_formation_id, id)
		f.layout = str(d.get("layout", "custom"))
		var fc: Array = d.get("facing", [0.0, -1.0])
		f.facing = Vector2(fc[0], fc[1]).normalized() if Vector2(fc[0], fc[1]).length() > 0.1 else Vector2.UP
		f.anchor = w.post
		f.anchor = w.post - (f.world(off) - f.anchor)   # (where its anchor must be for this troop's slot to be its post)
		formations.append(f)
	f.slots[w] = off


## Saves the formation `units` are in under `name` (as a custom layout).
func save_formation(units: Array, name := "1") -> bool:
	var fs := _formations_of(units)
	if fs.is_empty() or formations_path == "":
		return false
	var cf := ConfigFile.new()
	cf.load(formations_path)
	cf.set_value("formations", name, fs[0].to_save())
	cf.save(formations_path)
	main.effects.spawn_text(units[0].position + Vector2(0, -50), "Formation saved", Color(0.7, 0.95, 1.0))
	return true


## Puts the saved formation `name` on `units`, round where they stand.
func load_formation(units: Array, name := "1") -> Object:
	if formations_path == "" or not FileAccess.file_exists(formations_path):
		return null
	var cf := ConfigFile.new()
	cf.load(formations_path)
	var d = cf.get_value("formations", name, null)
	if d == null:
		return null
	units = units.filter(func(w): return is_instance_valid(w) and not w.is_emplacement() and not w.wall_guard and not w.summoned and w.clone_of == null)
	leave_formation(units)
	var f = Formation.new()
	_formation_id += 1
	f.id = _formation_id
	var mid := Vector2.ZERO
	for w in units:
		mid += w.post
	f.anchor = mid / maxf(units.size(), 1)
	f.from_save(d, units)
	formations.append(f)
	_place_formation(f, true)
	return f


func set_follow(o, units: Array = []) -> void:
	if units.is_empty():
		units = main.orders.order_units().filter(func(w): return not w.is_emplacement() and not w.wall_guard)
	var i := 0
	for w in units:
		if o == null:
			w.anchor = null
			continue
		var off: Vector2 = w.post - o.position
		if off.length() > 140.0 or off.length() < 30.0:
			off = Vector2.from_angle(PI * 0.15 + i * TAU / maxf(units.size(), 1.0)) * 60.0   # ring round it
		w.anchor = o
		w.anchor_off = off
		w.anchor_check = 0.0
		i += 1
	if not units.is_empty():
		main.effects.spawn_text(units[0].position + Vector2(0, -50), ("Following the " + o.label.to_lower()) if o != null else "Holding a post", Color(0.7, 0.95, 1.0))


## J: follow the nearest thing that can be followed, or stop following.
func toggle_follow() -> void:
	var units := main.orders.order_units().filter(func(w): return not w.is_emplacement() and not w.wall_guard)
	if units.is_empty():
		return
	if units[0].anchor != null:
		set_follow(null, units)
		return
	var best = null
	for o in main.rules.followable():
		if best == null or o.position.distance_to(units[0].position) < best.position.distance_to(units[0].position):
			best = o
	if best == null:
		main.hud.show_message("There's nothing here to follow")
		return
	set_follow(best, units)


## N: Focused or Reactive for the selection.
func toggle_commit() -> void:
	var units := main.orders.order_units().filter(func(w): return w.uses_targeting())
	if units.is_empty():
		return
	var next := "reactive" if units[0].commit == "focused" else "focused"
	main.orders.give_order("commit", next, units)
	main.effects.spawn_text(units[0].position + Vector2(0, -50), Warrior.COMMIT_NAMES[next], Color(1, 1, 0.6))


func sell_selected() -> void:
	if main.selected == null and main.group.is_empty() and main.selected_grave != null:
		main.hiring.rebuy_grave(main.selected_grave)   # (S on a grave: buy it back)
		return
	if main.selected == null and not main.group.is_empty():
		var units := sellable(main.group)
		if units.is_empty():
			main.hud.show_message("None of these can be sold right now")
			return
		main.hud.show_sell_confirm(units.size(), sell_total(units))   # asks first: a misclick mustn't cost an army
		return
	if main.selected == null:
		return
	if main.selected.summoned:
		main.hud.show_message("Skeletons can't be sold")
		return
	if main.selected.down_timer > 0.0:
		main.hud.show_message("A downed troop can't be sold")
		return
	main.gold += main.selected.sell_value()
	main.effects.sfx("sell")
	main.selected.queue_free()
	main.battlefield.warriors_changed()
	if main.selected is Barricade:
		main.battlefield.walls_changed()
	main.selected = null


## The ones in `units` that selling would take: not downed troops, summoned Skeletons or
## wrecked emplacements (worth nothing: they're rebuilt, not sold), as with selling one.
func sellable(units: Array) -> Array:
	return units.filter(func(w): return (is_instance_valid(w) and not w.is_queued_for_deletion()
			and not w.summoned and w.clone_of == null and w.down_timer <= 0.0 and not w.broken))


func sell_total(units: Array) -> int:
	var total := 0
	for w in units:
		total += w.sell_value()
	return total


## Sells the selected group (once the player's said yes): each at its own sell value.
func sell_group() -> void:
	var units := sellable(main.group)
	if units.is_empty():
		return
	var total := sell_total(units)
	var at: Vector2 = units[0].position
	var walls := false
	for w in units:
		walls = walls or w is Barricade
		w.queue_free()
	main.gold += total
	main.group.clear()
	main.selected = null
	main.effects.sfx("sell")
	main.effects.spawn_text(at + Vector2(0, -50), "+%dg" % total, Color(1, 0.85, 0.3))
	main.battlefield.warriors_changed()
	if walls:
		main.battlefield.walls_changed()


## Shows a hire tab, letting go of any selected unit so the hire buttons are visible.
func switch_tab(tab: String) -> void:
	if main.dragging != null:
		main.groups._end_drag()
	main.selected = null
	main.group.clear()
	if main.placing_type != "" and main.hud.tab_of(main.placing_type) != tab:
		main.placing_type = ""   # the hire being placed isn't on the new tab
		main.wall_start = null
	main.hud.show_tab(tab)


func _cancel() -> void:
	main.powers.aiming = ""
	main.ward_pick = []
	main.area_pick = []
	main.area_start = null
	main.group.clear()
	main.box_start = null
	main.castle_selected = false
	main.placing_type = ""
	main.wall_start = null
	main.selected = null
	main.selected_grave = null


func _warrior_at(p: Vector2, reach := Warrior.RADIUS + 6.0) -> Warrior:
	var best: Warrior = null
	var best_d := reach
	for w in main.battlefield.get_warriors():
		if w.summoned or w.garrison != null:
			continue   # skeletons can't be picked up, moved or sold; a Tower's crew is picked through its tower
		var d: float = w.position.distance_to(p)
		if d < best_d:
			best_d = d
			best = w
	if best == null:
		# Walls are picked anywhere along their length (they're drawn standing up from the line).
		best_d = 14.0
		for b in main.battlefield.get_barricades():
			var d: float = b.gap_from(p + Vector2(0, 8))
			if d < best_d:
				best_d = d
				best = b
	return best
