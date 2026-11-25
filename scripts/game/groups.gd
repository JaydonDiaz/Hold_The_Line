extends RefCounted
## Selecting troops: groups, the selection box, dragging units and groups about, upgrading.
## Part of the game controller: `main` is main.gd, which holds the battle's state.

const Main = preload("res://scripts/main.gd")
const Warrior = preload("res://scripts/troops/warrior.gd")
const Barricade = preload("res://scripts/troops/barricade.gd")

var main: Main

var group_from := {}        # warrior -> its post when the group drag started
var drag_origin := Vector2.ZERO
var drag_offset := Vector2.ZERO
const LIFT_AFTER := 4.0          # a dragged troop is lifted off its feet once it's moved this far (a click doesn't)


func _init(m: Main) -> void:
	main = m


# --- Group selection ---------------------------------------------------------

## Troops that can be picked up in a group (not emplacements, skeletons or copies).
func _groupable(w) -> bool:
	return w is Warrior and not w.is_emplacement() and not w.summoned and w.clone_of == null and not w is Barricade


func _set_group(units: Array) -> void:
	var picked := units.filter(_groupable)
	main.castle_selected = false
	main.selected_grave = null
	main.placing_type = ""
	if picked.size() == 1:
		main.group.clear()
		main.selected = picked[0]
	else:
		main.group = picked
		main.selected = null


## Shift+click: adds a troop to the selection, or takes it out.
func _toggle_in_group(w) -> void:
	var now := main.group.duplicate()
	if now.is_empty() and main.selected != null and _groupable(main.selected):
		now = [main.selected]
	if now.has(w):
		now.erase(w)
	else:
		now.append(w)
	_set_group(now)
	if now.is_empty():
		main.selected = null


func select_all_troops() -> void:
	if main.started and not main.game_over:
		_set_group(main.battlefield.get_warriors())


## The selection box, in field coordinates (while one's being dragged).
func selection_box() -> Rect2:
	return Rect2(main.box_start, main.mouse - main.box_start).abs() if main.box_start != null and main.box_active else Rect2()


func _finish_box() -> void:
	if main.box_active:
		var r := selection_box()
		var inside := main.battlefield.get_warriors().filter(func(w): return _groupable(w) and r.grow(Warrior.RADIUS * 0.5).has_point(w.position))
		var now := main.group.duplicate() if main.box_add else []
		if main.box_add and now.is_empty() and main.selected != null and _groupable(main.selected):
			now = [main.selected]
		for w in inside:
			if not now.has(w):
				now.append(w)
		_set_group(now)
		if now.is_empty():
			main.selected = null
	elif main.box_touch and main.hiring.fighting() and (main.selected != null or not main.group.is_empty()):
		main.input._order_at(main.box_start)   # a tap on open ground, on a touchscreen: send them there
	else:
		# Just a click on open field: clear the selection.
		main.formation_ctl._cancel()
	main.box_start = null
	main.box_active = false


## Keeps only the group's troops of `kind` (or, with `drop`, all but them).
func filter_group(kind: String, drop: bool) -> void:
	_set_group(main.group.filter(func(w): return (w.kind == kind) != drop))


## Sends the whole group to p, keeping their formation: each goes to p plus where it
## stood relative to the group's middle (nudged to the nearest free spot if that's taken).
func order_group(p: Vector2) -> void:
	if main.group.is_empty():
		return
	var f = main.formation_ctl.formation_of(main.group[0])
	if f != null and main.group.all(func(w): return main.formation_ctl.formation_of(w) == f) and f.members().size() == main.group.size():
		main.formation_ctl.move_formation(f, p)   # (a whole formation: its anchor goes there, its shape with it)
		return
	for w in main.group:
		w.anchor = null   # a move order sets fixed posts again
	var mid := Vector2.ZERO
	for w in main.group:
		mid += w.post
	mid /= main.group.size()
	var taken := []
	for w in main.group:
		var spot := _free_spot(main.hiring._clamp_post(p + (w.post - mid)), taken)
		if spot != Vector2.INF:
			taken.append(spot)
			w.order_to(spot)
	main.effects.sfx("place", 1.3)


## p if a group member could stand there (other troops' posts, walls and the spots
## already handed out to the group all count, the group's own old posts don't), else
## the nearest free spot close by, or INF.
func _free_spot(p: Vector2, taken: Array) -> Vector2:
	for r in [0.0, 18.0, 32.0, 46.0] + ([64.0, 84.0, 104.0] if main.paths.has_terrain() else []):   # further out round rock
		for i in (1 if r == 0.0 else 8):
			var q := main.hiring._clamp_post(p + Vector2.from_angle(i * TAU / 8.0) * r)
			var ok := q.y >= main.DEPLOY_TOP and q.y <= Main.CASTLE_Y and main.hiring.ground_problem(q) == ""
			for w in main.battlefield.get_warriors():
				if not main.group.has(w) and w.post.distance_to(q) < Main.MIN_POST_GAP:
					ok = false
			for t in taken:
				if t.distance_to(q) < Main.MIN_POST_GAP:
					ok = false
			for b in main.battlefield.get_barricades():
				if b.gap_from(q) < Warrior.RADIUS:
					ok = false
			if ok:
				return q
	return Vector2.INF


func _start_group_drag() -> void:
	main.group_drag = true
	group_from.clear()
	for w in main.group:
		group_from[w] = w.post
	drag_origin = main.mouse   # where the press is now


func _update_group_drag() -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or main.hiring.fighting():
		_end_group_drag()
		return
	var shift := main.mouse - drag_origin
	for w in group_from:
		if is_instance_valid(w):
			if shift.length() > LIFT_AFTER:
				w.held = true   # picked up: they dangle as they're carried (see Warrior._carry)
			var p := main.hiring._clamp_post(group_from[w] + shift)
			w.post = p
			w.position = p


## Drops the dragged group; any that landed somewhere they can't stand go back.
func _end_group_drag() -> void:
	main.group_drag = false
	var taken := []
	var thud := false
	for w in group_from:
		if not is_instance_valid(w):
			continue
		if w.held and not thud:
			main.effects.sfx("place")   # the group set down (one thud)
			thud = true
		w.held = false
		var p: Vector2 = w.post
		var ok := p.y >= main.DEPLOY_TOP and p.y <= Main.CASTLE_Y and main.hiring.ground_problem(p) == ""
		for o in main.battlefield.get_warriors():
			if not group_from.has(o) and o.post.distance_to(p) < Main.MIN_POST_GAP:
				ok = false
		for b in main.battlefield.get_barricades():
			if b.gap_from(p) < Warrior.RADIUS:
				ok = false
		if not ok:
			p = group_from[w]
		var let_go: Vector2 = w.position
		w.set_post(p)
		w.position = p
		if not ok:
			w.hop_back(let_go)
	for f in main.formation_ctl._formations_of(group_from.keys()):
		main.formation_ctl._refit_anchor(f)   # (a whole formation carried somewhere else: it's there now, the same shape)
	group_from.clear()


func order_move(p: Vector2) -> void:
	if main.selected != null:
		main.selected.anchor = null   # a move order sets a fixed post again
	if main.selected == null or not main.hiring.can_post_at(p, main.selected):
		if main.selected != null and main.hiring.ground_problem(p) != "":
			main.hud.show_message(main.hiring.ground_problem(p))
		return
	if main.selected.is_emplacement() and main.selected.garrison == null:
		main.hud.show_message("Emplacements can't move during a wave")
		return
	var tower := main.hiring.tower_for(p, main.selected)
	main.selected.order_to(tower.position if tower != null else main.hiring._clamp_post(p))   # (onto a Tower: it climbs in; a Tower's crew sent elsewhere climbs down)
	main.formation_ctl._slot_moved(main.selected)


func upgrade_selected(path: int) -> void:
	if main.castle_selected and main.selected == null:
		main.castle_ctl.castle_upgrade(path)   # Q/W/E/R buy the castle's upgrades while it's selected
		return
	if main.selected == null or main.selected.path_state(path) != "ok":
		return
	var cost := main.selected.upgrade_cost(path)
	if main.gold < cost:
		return
	var tier_name: String = main.selected.next_tier(path)["name"]
	main.gold -= cost
	main.selected.upgrade(path)
	main.selected.cheer(Warrior.CHEER_HOP)   # a hop of delight
	main.effects.sfx("upgrade")
	main.effects.spawn_text(main.selected.position + Vector2(0, -50), tier_name, Warrior.PATH_COLORS[path])
	main.effects.spawn_sparkle(main.selected.position, Warrior.PATH_COLORS[path])
	if main.selected is Barricade:
		main.battlefield.walls_changed()   # an Energy Wall may now let troops or shots through


# Between waves, units can be dragged anywhere and snap straight to the new spot.
func _start_drag(w: Warrior) -> void:
	main.dragging = w
	drag_origin = w.post
	drag_offset = w.post - main.mouse


func _update_drag() -> void:
	if not is_instance_valid(main.dragging):
		main.dragging = null
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_end_drag()
		return
	var p := main.hiring._clamp_post(main.mouse + drag_offset)
	if main.dragging is Barricade:
		p = _clamp_wall_center(main.dragging, main.mouse + drag_offset)
	main.dragging.post = p
	main.dragging.position = p
	if not main.dragging is Barricade and p.distance_to(drag_origin) > LIFT_AFTER:
		main.dragging.held = true   # picked up (not just clicked): it dangles as it's carried (see Warrior._carry)


func _end_drag() -> void:
	var w := main.dragging
	main.dragging = null
	if not is_instance_valid(w):
		return
	if w.held:
		main.effects.sfx("place")   # set down with a thud
	w.held = false
	var ok := main.hiring.can_post_at(w.post, w)
	if w is Barricade:
		ok = main.hiring.wall_problem(w.seg_a(), w.seg_b()) == ""
	var p := w.post if ok else drag_origin
	var into := main.hiring.tower_for(p, w)
	if ok and into != null:
		p = into.position   # dropped on an empty Tower: up into it
	var let_go := w.position
	w.set_post(p)
	w.position = p
	if ok and not w is Barricade:
		main.formation_ctl._slot_moved(w)
	if not ok and not w is Barricade:
		w.hop_back(let_go)
	if w is Barricade:
		main.battlefield.walls_changed()


## Keeps a dragged wall's both ends on the field.
func _clamp_wall_center(w, p: Vector2) -> Vector2:
	var h: Vector2 = w.half.abs()
	return p.clamp(Vector2(h.x, main.DEPLOY_TOP + h.y), Vector2(main.FIELD_W - h.x, Main.CASTLE_Y - 16 - h.y))


func cycle_target_priority() -> void:
	if main.selected == null:
		return
	main.selected.cycle_priority()
	if main.selected.is_mobile_healer():
		if main.selected.priority == "stay":
			main.selected.priority = "revive" if main.selected.wards.is_empty() else "stay"
			if main.selected.wards.is_empty():
				main.orders.give_order("priority", "stay", [main.selected])   # (waits for the troop to stay with)
				return
		else:
			main.selected.stop_staying()
	if main.selected.priority != "stay":
		main.last_priority[main.selected.kind] = main.selected.priority
	main.effects.spawn_text(main.selected.position + Vector2(0, -50), ("Focus: " if main.selected.is_mobile_healer() else "Target: ") + Warrior.PRIORITY_NAMES[main.selected.priority], Color(1, 1, 0.6))
