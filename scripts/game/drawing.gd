extends RefCounted
## Drawing: the ground, the surroundings and the overlay (placement previews, formations,
## zones, areas and walls).
## Part of the game controller: `main` is main.gd, which holds the battle's state.

const Main = preload("res://scripts/main.gd")
const Data = preload("res://scripts/data/data.gd")
const Warrior = preload("res://scripts/troops/warrior.gd")
const Barricade = preload("res://scripts/troops/barricade.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const Sprites = preload("res://scripts/art/sprites.gd")
const FieldArt = preload("res://scripts/art/field_art.gd")
const Maps = preload("res://scripts/campaign/maps.gd")
const Formation = preload("res://scripts/troops/formation.gd")

var main: Main


func _init(m: Main) -> void:
	main = m


# --- Drawing -------------------------------------------------------------

## The ground never moves, but it's hundreds of tiles and bits of scenery: drawn
## live, the renderer would resend them all every frame. So it's painted once into
## a texture (at twice the size, to stay crisp on a big screen) and shown as a single
## sprite; it's painted again only when the mode or the field's width changes.
func _repaint_ground() -> void:
	var size := Vector2i(main.FIELD_W, Main.FIELD_H) * main.GROUND_OVERSAMPLE
	if main.ground_vp.size != size:
		main.ground_vp.size = size
	main.ground_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	main.ground_painter.queue_redraw()


## Pixel ground: dirt where enemies enter, grass (with the odd flower patch) below,
## lit for the mode's mood; then the scenery on it (see field_art.gd).
func _paint_ground(ci: CanvasItem) -> void:
	var map: Dictionary = Maps.get_map(main.map_id).merged(main.map_extra, true)
	FieldArt.paint_field(ci, main.FIELD_W, Main.FIELD_H, main.ambience.ground_tint() * map.get("tint", Color.WHITE), map)


## The panel's colour carried on under the field across the whole width (the
## panel's controls stay 640 wide in the middle), and dark dirt above the field
## on a tall screen.
func _draw_surroundings() -> void:
	if main.margin.y > 0.0:
		main.draw_rect(Rect2(0, -main.margin.y, main.FIELD_W, main.margin.y), Color(0.2, 0.15, 0.1))
	main.draw_rect(Rect2(0, Main.FIELD_H, main.FIELD_W, Hud.HEIGHT - Main.FIELD_H + main.margin.y), Color(0.13, 0.11, 0.1))
	main.draw_rect(Rect2(0, Main.FIELD_H, main.FIELD_W, 3), Color(0.45, 0.35, 0.2))


func _draw_overlay() -> void:
	# The selection box being dragged, and a ring under every troop in the group.
	var zones_drawn := []
	if not main.area_pick.is_empty():
		var ab := main.orders.area_box()
		if ab.size != Vector2.ZERO:
			_draw_area(ab, Color(1.0, 0.9, 0.5), 1.6)   # the Guard Area being drawn
			_overlay_text(ab.end + Vector2(6, 2), "%s × %s" % [Data.ft(ab.size.x), Data.ft(ab.size.y)], Color(1.0, 0.92, 0.6))
		else:
			_overlay_text(main.mouse + Vector2(14, -8), "Drag out the area to guard", Color(1.0, 0.92, 0.6))
	var box := main.groups.selection_box()
	if box.size != Vector2.ZERO:
		main.overlay.draw_rect(box, Color(0.6, 0.9, 1.0, 0.12))
		main.overlay.draw_rect(box, Color(0.7, 0.95, 1.0, 0.85), false, 1.5)
	for w in main.group:
		var feet: Vector2 = w.position + Vector2(0, Warrior.RADIUS)
		main.overlay.draw_set_transform(feet, 0, Vector2(1, 0.4))
		main.overlay.draw_arc(Vector2.ZERO, Warrior.RADIUS + 4.0, 0, TAU, 24, Color(0.7, 0.95, 1.0, 0.9), 2.5, true)
		main.overlay.draw_set_transform(Vector2.ZERO)
		if w.ordered:
			main.overlay.draw_line(w.position, w.post, Color(0.7, 0.95, 1.0, 0.3), 1.5, true)
		_draw_zone(w, 0.6, zones_drawn)
	for f in main.formation_ctl._formations_of(main.group if not main.group.is_empty() else ([main.selected] if main.selected != null and is_instance_valid(main.selected) else [])):
		_draw_formation(f)
	if main.castle_selected or main.castle_ctl._castle_hovered():
		# The castle outlined in gold: solid while selected, faint while hovered.
		var col := Color(1.0, 0.85, 0.35, 0.95 if main.castle_selected else 0.45)
		main.overlay.draw_rect(Rect2(1, Main.CASTLE_Y, main.FIELD_W - 2, Main.FIELD_H - Main.CASTLE_Y - 1), col, false, 2.0)
		for r in main.castle._towers():
			main.overlay.draw_rect(r.grow(1.0), col, false, 2.0)
	if main.placing_type == "barricade" and main.mouse.y <= Main.FIELD_H:
		_draw_wall_preview()
	elif main.placing_type != "" and main.mouse.y <= Main.FIELD_H:
		var d: Dictionary = Data.WARRIORS[main.placing_type]
		var ok := main.hiring.can_post_at(main.mouse)
		var tint := Color(1, 1, 1, 0.6) if ok else Color(1, 0.3, 0.3, 0.6)
		var size := Vector2(Sprites.SIZE, Sprites.SIZE) * Warrior.SCALE
		var top_left := main.mouse + Vector2(-size.x / 2, Warrior.RADIUS - size.y)
		if Sprites.MOUNT_CREW.has(main.placing_type):
			# A tower with its troop on top (or a cannon and its Cannoneer), as it'll stand.
			var foot := main.mouse + Vector2(0, Warrior.RADIUS)
			Sprites.draw_mount(main.overlay, main.placing_type, foot, foot, 1.0, Sprites.mount_frames(main.placing_type, main.placing_type)[0],
					null if main.placing_type == "tower" else Sprites.frames(Sprites.MOUNT_CREW[main.placing_type])[0], tint, 1.0, Warrior.SCALE)
		else:
			main.overlay.draw_texture_rect(Sprites.frames(main.placing_type)[0], Rect2(top_left, size), false, tint)
		var reach: float = d["range"] + Warrior.RADIUS
		main.overlay.draw_circle(main.mouse, reach, Color(1, 1, 1, 0.08), true, -1.0, true)
		main.overlay.draw_arc(main.mouse, reach, 0, TAU, 64, Color(1, 1, 1, 0.5), 2.0, true)
	# Dropped (or hired) here, it would go up a Tower: show which.
	var into = null
	if is_instance_valid(main.dragging) and not main.dragging is Barricade:
		into = main.hiring.tower_for(main.dragging.post, main.dragging)   # (where it'd be dropped: see _end_drag)
	elif main.placing_type != "" and Data.WARRIORS.has(main.placing_type) and not Data.WARRIORS[main.placing_type].get("emplacement", false):
		into = main.hiring.tower_for(main.mouse, main.placing_type)
	if into != null:
		main.hiring._draw_into_tower(into)
	if is_instance_valid(main.dragging) and main.dragging is Barricade:
		if main.hiring.wall_problem(main.dragging.seg_a(), main.dragging.seg_b()) != "":
			main.overlay.draw_line(main.dragging.seg_a(), main.dragging.seg_b(), Color(1, 0.25, 0.25, 0.45), 18.0)
	elif main.dragging != null and is_instance_valid(main.dragging) and not main.hiring.can_post_at(main.dragging.post, main.dragging):
		main.overlay.draw_circle(main.dragging.position, Warrior.RADIUS + 6, Color(1, 0.25, 0.25, 0.45), true, -1.0, true)
	if is_instance_valid(main.selected) and main.selected is Barricade:
		_draw_wall_selection(main.selected)
	elif main.selected != null and is_instance_valid(main.selected) and main.selected.data["attack"] in ["aura", "pulse"]:
		# A War Statue or Medic Bay: a thread to every unit it looks after.
		for w in main.battlefield.get_warriors():
			if w != main.selected and main.selected.covers(w):
				main.overlay.draw_line(main.selected.position, w.position, Color(1, 1, 0.6, 0.35), 1.5, true)
				main.overlay.draw_circle(w.position, 4.0, Color(1, 1, 0.6, 0.7), true, -1.0, true)
	elif main.selected != null and is_instance_valid(main.selected):
		var post := main.selected.post
		var col := Color(1, 1, 0.6)
		_draw_zone(main.selected, 1.0)
		# Attack range around the warrior, plus a marker for the post it returns to.
		var reach := main.selected.attack_range + Warrior.RADIUS
		main.overlay.draw_circle(main.selected.position, reach, Color(col, 0.1), true, -1.0, true)
		main.overlay.draw_arc(main.selected.position, reach, 0, TAU, 64, Color(col, 0.8), 2.0, true)
		if not main.selected.blast.is_empty():
			# Spirit bolt range, for Martial Artists who have learned it.
			var ki: float = main.selected.blast["range"] + Warrior.RADIUS
			main.overlay.draw_arc(main.selected.position, ki, 0, TAU, 64, Color(Warrior.KI_COLOR, 0.6), 1.5, true)
		if main.selected.position.distance_to(post) > reach:
			main.overlay.draw_line(main.selected.position, post, Color(col, 0.4), 1.5, true)
		main.overlay.draw_line(post + Vector2(-7, -7), post + Vector2(7, 7), col, 2.5, true)
		main.overlay.draw_line(post + Vector2(-7, 7), post + Vector2(7, -7), col, 2.5, true)


## A selected formation: its footprint, its anchor and the way it faces, and a ring where
## each member belongs (a dashed column while it's going through a gap).
func _draw_formation(f) -> void:
	var col := Color(0.75, 0.95, 1.0)
	var pts := []
	for w in f.members():
		var at: Vector2 = f.world(f.slot_of(w))
		pts.append(at)
		main.overlay.draw_arc(at, 7.0, 0, TAU, 14, Color(col, 0.75), 1.5, true)
		if w.position.distance_to(at) > Formation.IN_PLACE:
			main.overlay.draw_line(w.position, at, Color(col, 0.25), 1.0, true)
	if pts.size() >= 3:
		var hull := Geometry2D.convex_hull(PackedVector2Array(pts))
		for i in hull.size() - 1:
			main.overlay.draw_line(hull[i], hull[i + 1], Color(col, 0.3), 1.5 if not f.travel else 1.0, true)
	var a: Vector2 = f.anchor
	main.overlay.draw_colored_polygon(PackedVector2Array([a + Vector2(0, -6), a + Vector2(6, 0), a + Vector2(0, 6), a + Vector2(-6, 0)]), Color(col, 0.8))
	var tip: Vector2 = a + f.facing * 34.0
	main.overlay.draw_line(a, tip, Color(col, 0.85), 2.0, true)
	main.overlay.draw_line(tip, tip - f.facing.rotated(0.5) * 9.0, Color(col, 0.85), 2.0, true)
	main.overlay.draw_line(tip, tip - f.facing.rotated(-0.5) * 9.0, Color(col, 0.85), 2.0, true)
	_overlay_text(a + Vector2(10, 8), "%s  %d%%" % [Formation.NAMES.get(f.layout, "Custom"), roundi(f.cohesion() * 100)], Color(col, 0.9))


## A unit's movement zone: the ground around its post it may fight from (a ring at the
## post on Hold). Nothing for units roaming free or that never move.
func _draw_zone(w, strength: float, drawn: Array = []) -> void:
	if not (w is Warrior) or w.move_mode == "free" or w.is_emplacement() or w.wall_guard:
		return
	var col := Color(0.55, 0.85, 1.0)
	if w.move_mode == "hold":
		main.overlay.draw_arc(w.post, Warrior.RADIUS + 3.0, 0, TAU, 32, Color(col, 0.8 * strength), 2.5, true)
		return
	var r: Rect2 = w.zone_rect()
	if drawn.has(r):
		return   # (a group sharing one area: drawn once)
	drawn.append(r)
	_draw_area(r, col, strength)


## A Guard Area: a pale fill inside a dashed outline.
func _draw_area(r: Rect2, col: Color, strength: float) -> void:
	main.overlay.draw_rect(r, Color(col, 0.07 * strength))
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var n := maxi(1, int(a.distance_to(b) / 12.0))
		for j in n:
			if j % 2 == 0:
				main.overlay.draw_line(a.lerp(b, float(j) / n), a.lerp(b, float(j + 1) / n), Color(col, 0.75 * strength), 2.0)


## Placing a barricade: a marker before the first click, then the wall-to-be with
## its length and price.
func _draw_wall_preview() -> void:
	if main.wall_start == null:
		var p := main.hiring._clamp_wall_point(main.mouse)
		main.overlay.draw_circle(p, 6, Color(1, 1, 1, 0.7), true, -1.0, true)
		_overlay_text(p + Vector2(12, -10), "Click where the wall starts", Color.WHITE)
		return
	var a: Vector2 = main.wall_start
	var b := main.hiring.wall_end(a, main.mouse)
	var cost := main.hiring.wall_cost(a, b)
	var problem := main.hiring.wall_problem(a, b)
	var ok := problem == "" and main.gold >= cost
	var col := Color(1, 1, 1, 0.7) if ok else Color(1, 0.3, 0.3, 0.7)
	main.overlay.draw_line(a, b, Color(col, 0.25), Barricade.WALL_HALF * 2.0 + 8.0)
	main.overlay.draw_line(a, b, col, 4.0)
	var n := int(a.distance_to(b) / Barricade.STAKE_GAP)
	for i in n + 1:
		var p := a.lerp(b, i / maxf(n, 1.0))
		main.overlay.draw_line(p + Vector2(0, 4), p + Vector2(0, -16), col, 3.0)
	main.overlay.draw_circle(a, 5, col, true, -1.0, true)
	var label := "%s  %dg" % [Data.ft(a.distance_to(b)), cost]
	if problem != "":
		label += "  - " + problem
	elif main.gold < cost:
		label += "  - not enough gold"
	_overlay_text(b + Vector2(12, -10), label, Color(1, 0.85, 0.3) if ok else Color(1, 0.45, 0.4))


func _overlay_text(p: Vector2, text: String, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	p.x = clampf(p.x, 4.0, main.FIELD_W - w - 4.0)
	main.overlay.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color.BLACK)
	main.overlay.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)


## A selected wall: highlighted along its length, plus the reach of its arrows or spikes.
func _draw_wall_selection(w) -> void:
	var col := Color(1, 1, 0.6)
	main.overlay.draw_line(w.seg_a(), w.seg_b(), Color(col, 0.25), Barricade.WALL_HALF * 2.0 + 10.0)
	var reach: float = maxf(w.attack_range, w.wall_slow[1] if not w.wall_slow.is_empty() else 0.0)
	if reach <= 0.0:
		return
	reach += Barricade.WALL_HALF
	var a: Vector2 = w.seg_a()
	var b: Vector2 = w.seg_b()
	var n: Vector2 = (b - a).normalized().orthogonal() * reach
	var ang := n.angle()
	main.overlay.draw_line(a + n, b + n, Color(col, 0.6), 2.0, true)
	main.overlay.draw_line(a - n, b - n, Color(col, 0.6), 2.0, true)
	main.overlay.draw_arc(a, reach, ang, ang + PI, 24, Color(col, 0.6), 2.0, true)
	main.overlay.draw_arc(b, reach, ang + PI, ang + TAU, 24, Color(col, 0.6), 2.0, true)


func draw_main() -> void:
	_draw_surroundings()
	_repaint_ground()
