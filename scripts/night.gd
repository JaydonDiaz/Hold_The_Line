extends Node2D
## Night battles (Phase 4, the Free Cities' Carnival Night): the field is dark but for
## pools of lantern light (and the camp's fires), drawn over the troops and enemies.
## Kept readable:
##   - an enemy out of the light and away from your troops fades to a pair of red eyes
##     (plain within SEE_CLEAR of a troop or inside a lantern's light, fading out to
##     SEE_FAR), so you can always tell something's there;
##   - an enemy coming down onto the field is warned of: a red chevron at the top edge over
##     each one still in the dark up there, and a message saying which side they're
##     coming from (once for each new band of them);
##   - your troops fight whatever's in reach as ever: only the drawing changes.
## Mission data: "night": {"lanterns": [Vector2 (drawn up 640 wide)], "light": radius}

const OUTLINE := Color(0.1, 0.07, 0.1)
const SEE_CLEAR := 110.0
const SEE_FAR := 190.0
const CELL := 8.0           # the darkness is worked out in cells this big (once, then stretched)
const DARK := 0.62          # how dark it is away from any light
const TOP_BAND := 170.0     # enemies above this, in the dark, get a chevron at the top edge
const CALL_GAP := 6.0       # seconds between "coming from..." messages
const CHEVRON := 24.0       # the top edge's columns: one chevron each at most

var main
var spec := {}
var lanterns := PackedVector2Array()   # where they stand now (fitted to the field's width)
var light := 120.0
var tex: ImageTexture
var fitted_w := -1.0
var t := 0.0
var call_in := 0.0
var _called := {}            # enemy instance id -> warned of
var _dim := []               # enemies drawn as eyes this frame


func setup(m, mission: Dictionary) -> void:
	main = m
	_vis.clear()
	spec = mission.get("night", {})
	light = float(spec.get("light", 120.0))
	fitted_w = -1.0
	_called.clear()
	call_in = 0.0
	visible = active()
	z_index = 30
	if active():
		_refit()


func active() -> bool:
	return not spec.is_empty()


func _refit() -> void:
	if is_equal_approx(fitted_w, main.FIELD_W):
		return
	fitted_w = main.FIELD_W
	lanterns = PackedVector2Array()
	for p in spec.get("lanterns", []):
		lanterns.append(Vector2(p.x * main.FIELD_W / 640.0, p.y))
	# The darkness: one cell at a time, lightened round each lantern and along the camp.
	var cw := int(ceil(main.FIELD_W / CELL)) + 1
	var ch := int(ceil(main.FIELD_H / CELL)) + 1
	var img := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	for y in ch:
		for x in cw:
			var p := Vector2(x * CELL, y * CELL)
			var lit := 0.0
			for l in lanterns:
				var d := p.distance_to(l)
				if d < light:
					lit = maxf(lit, 1.0 - smoothstep(light * 0.45, light, d))
			lit = maxf(lit, smoothstep(main.CASTLE_Y - 90.0, main.CASTLE_Y - 10.0, p.y))   # the camp's fires
			img.set_pixel(x, y, Color(0.04, 0.05, 0.14, DARK * (1.0 - lit)))
	tex = ImageTexture.create_from_image(img)


## Whether p is in a lantern's light.
func lit_at(p: Vector2) -> bool:
	for l in lanterns:
		if p.distance_to(l) < light * 0.7:
			return true
	return p.y > main.CASTLE_Y - 40.0


## How plainly an enemy at p can be seen (1: plainly; 0.12 in the dark, eyes only).
func visibility(p: Vector2) -> float:
	if not active():
		return 1.0
	if lit_at(p):
		return 1.0
	var d := SEE_FAR + 1.0
	for w in main.warriors_near(p, SEE_FAR):
		if w.is_active():
			d = minf(d, p.distance_to(w.position))
	return clampf(1.0 - (d - SEE_CLEAR) / (SEE_FAR - SEE_CLEAR), 0.12, 1.0)


const SLICES := 10           # each enemy's visibility is worked out again every this many frames

var _slice := 0
var _vis := {}               # enemy instance id -> its visibility, last worked out


func _process(delta: float) -> void:
	if main == null or not active():
		return
	t += delta
	_refit()
	_slice = (_slice + 1) % SLICES
	_dim.clear()
	var fresh := {"west": 0, "centre": 0, "east": 0}
	var enemies: Array = main.get_enemies()
	for i in enemies.size():
		var e = enemies[i]
		if e.dead:
			continue
		var id: int = e.get_instance_id()
		var v: float = _vis.get(id, -1.0)
		if v < 0.0 or i % SLICES == _slice:
			v = visibility(e.position)
			_vis[id] = v
		if absf(e.modulate.a - v) > 0.02:
			e.modulate.a = v
		if v < 0.5:
			_dim.append(e)
		if not _called.has(id) and e.position.y < TOP_BAND:
			_called[id] = true
			var third: float = e.position.x / main.FIELD_W
			fresh["west" if third < 0.36 else ("east" if third > 0.64 else "centre")] += 1
	if _vis.size() > enemies.size() * 2 + 50:
		_vis.clear()   # (the dead's entries, now and then)
	call_in -= delta
	var sides := fresh.keys().filter(func(k): return fresh[k] > 0)
	if not sides.is_empty() and call_in <= 0.0 and main.wave_active:
		call_in = CALL_GAP
		var where := ", ".join(sides.map(func(s): return "the " + s)) if sides.size() < 3 else "every side"
		main.hud.show_message("In the dark: enemies coming from %s!" % where)
	queue_redraw()


func _draw() -> void:
	if tex == null:
		return
	draw_texture_rect(tex, Rect2(0, 0, tex.get_width() * CELL, tex.get_height() * CELL), false)
	# The lanterns: a pole, a paper lantern, a warm halo that breathes.
	for i in lanterns.size():
		var l := lanterns[i]
		var glow := 0.8 + 0.2 * sin(t * 3.0 + i * 1.7)
		draw_circle(l + Vector2(0, -26), 22.0 * glow, Color(1.0, 0.75, 0.35, 0.16))
		draw_rect(Rect2(l + Vector2(-2, -24), Vector2(4, 26)), OUTLINE)
		draw_rect(Rect2(l + Vector2(-1, -23), Vector2(2, 24)), Color(0.4, 0.28, 0.18))
		var col: Color = [Color(1.0, 0.45, 0.35), Color(1.0, 0.8, 0.35), Color(0.95, 0.5, 0.85)][i % 3]
		draw_rect(Rect2(l + Vector2(-7, -36), Vector2(14, 14)), OUTLINE)
		draw_rect(Rect2(l + Vector2(-6, -35), Vector2(12, 12)), col.lerp(Color(1, 0.95, 0.7), 0.3 * glow))
		draw_line(l + Vector2(-6, -29), l + Vector2(6, -29), col.darkened(0.3), 1.0)
	# Eyes in the dark, so nothing's ever truly hidden (two little squares each: cheap
	# enough for a whole horde).
	var eye_c := Color(1.0, 0.25, 0.2, 0.9)
	var cols := {}   # top-edge column (CHEVRON px wide) -> an enemy coming down in it
	for e in _dim:
		if not is_instance_valid(e):
			continue
		if fmod(t + e.get_instance_id() % 7, 3.5) > 0.15:   # (a blink now and then)
			var eye: Vector2 = e.position + Vector2(0, -e.radius * 1.1)
			draw_rect(Rect2(eye + Vector2(-4.5, -1.5), Vector2(3, 3)), eye_c)
			draw_rect(Rect2(eye + Vector2(1.5, -1.5), Vector2(3, 3)), eye_c)
		if e.position.y <= TOP_BAND:
			cols[int(clampf(e.position.x, 0.0, main.FIELD_W - 1.0) / CHEVRON)] = true
	# A chevron at the top edge over each stretch where they're coming down in the dark
	# (one a column, however many are in it).
	var bob := 3.0 * sin(t * 6.0)
	for c in cols:
		var x: float = (c + 0.5) * CHEVRON
		var pts := PackedVector2Array([Vector2(x - 9, 34 + bob), Vector2(x + 9, 34 + bob), Vector2(x, 46 + bob)])
		draw_colored_polygon(PackedVector2Array([pts[0] + Vector2(-2, -1), pts[1] + Vector2(2, -1), pts[2] + Vector2(0, 2)]), OUTLINE)
		draw_colored_polygon(pts, Color(1.0, 0.3, 0.25, 0.9))
