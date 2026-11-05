extends Node2D
## The castle along the bottom of the field: what the player is holding the line for.
## Enemies that reach its wall stop and attack it; if its health runs out the game is
## lost. It shakes when hit, and shows the damage (cracks, then smoke, then fire) as
## its health falls.

const Sprites = preload("res://scripts/sprites.gd")
const Data = preload("res://scripts/data.gd")
const OUTLINE := Color(0.1, 0.07, 0.1)
const STONE := Color(0.6, 0.58, 0.56)
const STONE_DARK := Color(0.44, 0.42, 0.42)
const STONE_LIGHT := Color(0.7, 0.68, 0.65)
const WOOD := Color(0.42, 0.26, 0.14)
const IRON := Color(0.3, 0.3, 0.34)
const BANNER := Color(0.75, 0.15, 0.15)
const BANNER_TRIM := Color(1.0, 0.82, 0.3)
const TOWER_W := 60.0
const TOWER_RISE := 48.0     # how far the corner towers stand above the wall
const GATE_W := 96.0
const GATE_RISE := 36.0

var main
var t := 0.0
var hit := 0.0        # > 0 just after a hit: the castle shakes and flashes (harder for big hits)
var cracks := []      # crack lines, revealed one by one as it takes damage
var top_part := Top.new()   # the moving parts, drawn over everything else of the castle
var _drawn_state := Vector3(-1, -1, -1)   # cracks shown, field width and lamplight the stonework was drawn with


func _ready() -> void:
	lay_out()
	# The castle is drawn over the warriors, so one standing behind the gatehouse or a
	# tower is hidden by it. Its silhouette shows through, clipped to the castle's shape.
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var xray := Xray.new()
	xray.main = main
	add_child(xray)


## Silhouettes of the warriors, in each one's own color. As a child of the castle with
## clip_children on, only the parts over the castle's stonework are seen.
class Xray extends Node2D:
	const SHADER := """
shader_type canvas_item;
void fragment() {
	COLOR = vec4(COLOR.rgb, COLOR.a * texture(TEXTURE, UV).a);
}
"""
	var main

	func _ready() -> void:
		var mat := ShaderMaterial.new()
		mat.shader = Shader.new()
		mat.shader.code = SHADER
		material = mat

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		for w in main.get_warriors():
			if not w.visible or w.xray_tex == null:
				continue
			draw_set_transform_matrix(Transform2D(0, w.position) * w.xray_xform)
			draw_texture_rect(w.xray_tex, w.xray_rect, false, Color(w.data["color"].lightened(0.2), 0.6))
		draw_set_transform_matrix(Transform2D.IDENTITY)


## Picks the crack lines (again when the field changes width). Seeded, so the same
## castle cracks the same way each game.
func lay_out() -> void:
	cracks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var top: float = main.CASTLE_Y
	for i in maxi(14, int(main.FIELD_W / 45.0)):
		var p := Vector2(rng.randf_range(70, main.FIELD_W - 70), rng.randf_range(top + 6, main.FIELD_H - 6))
		var line := PackedVector2Array([p])
		for j in rng.randi_range(2, 4):
			p += Vector2(rng.randf_range(-7, 7), rng.randf_range(3, 7))
			line.append(p)
		cracks.append(line)


func struck(amount: float) -> void:
	hit = maxf(hit, 0.35 * clampf(amount / 30.0, 0.15, 1.0))


func _process(delta: float) -> void:
	t += delta
	hit = maxf(hit - delta, 0.0)
	# Shaking and flashing red when hit move and tint the stonework already drawn, so
	# it only needs drawing again when cracks appear or the field changes.
	var shake := Vector2(randf_range(-2.5, 2.5), randf_range(-1, 1)) * (hit / 0.35)
	position = shake
	top_part.position = shake
	self_modulate = Color(1, 0.65, 0.6) if hit > 0.12 else Color.WHITE
	var state := Vector3(int(cracks.size() * _damage()), main.FIELD_W, main.ambience.glow())
	if state != _drawn_state:
		_drawn_state = state
		queue_redraw()


## 0 at full health, 1 when the castle is about to fall.
func _damage() -> float:
	return clampf(1.0 - main.castle_hp / main.castle_max, 0.0, 1.0)


## The towers: the gatehouse, any extra ones along a wide wall, and the two corners.
func _towers() -> Array:
	var w: float = main.FIELD_W
	var top: float = main.CASTLE_Y
	var bottom: float = main.FIELD_H
	var out := [Rect2(w / 2 - GATE_W / 2, top - GATE_RISE, GATE_W, bottom - top + GATE_RISE)]
	var extra := int(w / 400.0) - 1
	for i in extra:
		var x: float = w * (i + 1) / (extra + 1)
		if absf(x - w / 2) > GATE_W:
			out.append(Rect2(x - TOWER_W / 2, top - TOWER_RISE * 0.6, TOWER_W, bottom - top + TOWER_RISE * 0.6))
	out.append(Rect2(0, top - TOWER_RISE, TOWER_W, bottom - top + TOWER_RISE))
	out.append(Rect2(w - TOWER_W, top - TOWER_RISE, TOWER_W, bottom - top + TOWER_RISE))
	return out


## The stonework: walls, towers, gate, ivy and cracks. (Drawn only when it changes;
## the castle's own drawing is also what the x-ray silhouettes are clipped to.)
func _draw() -> void:
	var w: float = main.FIELD_W
	var top: float = main.CASTLE_Y
	var bottom: float = main.FIELD_H
	var tint := Color.WHITE
	# Curtain wall with battlements.
	_stones(Rect2(0, top, w, bottom - top), tint)
	for x in range(6, int(w), 26):
		_merlon(Vector2(x, top), tint)
	var towers := _towers()
	_tower(towers[0], tint)
	_gate(Vector2(w / 2, bottom), tint)
	for i in range(1, towers.size()):
		_tower(towers[i], tint)
	# Ivy creeping up the wall here and there.
	for i in int(w / 160.0):
		var ix: float = fposmod(i * 157.0 + 60.0, w)
		if absf(ix - w / 2.0) > GATE_W * 0.7 and ix > TOWER_W + 6.0 and ix < w - TOWER_W - 6.0:
			_ivy(Vector2(ix, bottom - 4))
	# Damage: cracks (smoke and fire are drawn by the top part).
	for i in int(cracks.size() * _damage()):
		draw_polyline(cracks[i], OUTLINE, 2.0)


## What moves on the castle: lamplit windows, torches, banners, flags, smoke, fire and
## the health bar. Drawn every frame, over the stonework (and not clipped like it).
class Top extends Node2D:
	var castle

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		castle._draw_top(self)


func _draw_top(ci: CanvasItem) -> void:
	var w: float = main.FIELD_W
	var top: float = main.CASTLE_Y
	# Tower windows, lamplit after dark.
	for r in _towers():
		var mid: float = r.position.x + r.size.x / 2
		var lit: float = main.ambience.glow() * (0.85 + 0.15 * sin(t * 3.0 + mid))
		var win := Color(0.1, 0.07, 0.1).lerp(Color(1.0, 0.78, 0.35), lit)
		ci.draw_rect(Rect2(mid - 3, r.position.y + 13, 6, 12), win)
		Sprites.disc(ci, Vector2(mid, r.position.y + 13), 3.0, win)
		ci.draw_line(Vector2(mid, r.position.y + 11), Vector2(mid, r.position.y + 25), OUTLINE, 1.0)
	for side in [-1.0, 1.0]:
		_torch(ci, Vector2(w / 2 + side * 36.0, top - 14.0))
	_banner(ci, Vector2(TOWER_W / 2, top - TOWER_RISE + 30), true)
	_banner(ci, Vector2(w - TOWER_W / 2, top - TOWER_RISE + 30), false)
	_flag(ci, Vector2(TOWER_W / 2, top - TOWER_RISE - 8), 0.0)
	_flag(ci, Vector2(w - TOWER_W / 2, top - TOWER_RISE - 8), 1.3)
	_flag(ci, Vector2(w / 2, top - GATE_RISE - 8), 2.1)
	var dmg := _damage()
	if dmg >= 0.5:
		for x in [TOWER_W / 2, w - TOWER_W / 2, w / 2]:
			_smoke(ci, Vector2(x, top - TOWER_RISE), dmg)
	if dmg > 0.0:
		# Health bar on the gatehouse.
		var bar := Rect2(w / 2 - 40, top - GATE_RISE - 34, 80, 6)
		ci.draw_rect(bar.grow(1), OUTLINE)
		ci.draw_rect(Rect2(bar.position, Vector2(bar.size.x * (1.0 - dmg), bar.size.y)), Color(0.35, 0.85, 0.35).lerp(Color(0.9, 0.2, 0.15), dmg))
	if dmg >= 0.75:
		for x in [TOWER_W / 2, w - TOWER_W / 2]:
			var flick := 0.6 + 0.4 * sin(t * 18.0 + x)
			ci.draw_rect(Rect2(x - 3, top - 26, 6, 12), Color(1.0, 0.55, 0.1, flick))


## Mortared stone: staggered courses of blocks, each a little different in tone and
## lit along its top, with a dark outline (and now and then a cracked one).
func _stones(r: Rect2, tint: Color) -> void:
	draw_rect(r, OUTLINE)
	var inner := r.grow(-2)
	draw_rect(inner, STONE_DARK * tint)
	var row := 0
	var y := inner.position.y
	while y < inner.end.y:
		var h := minf(8.0, inner.end.y - y)
		var x := inner.position.x - (0.0 if row % 2 == 0 else 8.0)
		while x < inner.end.x:
			var x0 := maxf(x, inner.position.x)
			var x1 := minf(x + 16.0, inner.end.x)
			if x1 - x0 > 1.0:
				var k := fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)
				var c := STONE.lerp(STONE_LIGHT if k > 0.5 else STONE_DARK, absf(k - 0.5) * 1.1) * tint
				var b := Rect2(x0 + (0.0 if x0 == inner.position.x else 1.0), y + 1.0, x1 - x0 - 1.0, h - 1.0)
				draw_rect(b, c)
				draw_rect(Rect2(b.position, Vector2(b.size.x, 1)), c.lightened(0.15))
				if k > 0.93:
					draw_line(b.position + Vector2(4, 1), b.position + Vector2(8, h - 2), STONE_DARK * tint, 1.0)
			x += 16.0
		y += 8.0
		row += 1
	# The wall's foot sits in a band of darker, larger stones.
	if r.end.y >= main.FIELD_H - 1.0:
		draw_rect(Rect2(inner.position.x, inner.end.y - 5, inner.size.x, 5), (STONE_DARK * tint).darkened(0.25))


func _merlon(p: Vector2, tint: Color) -> void:
	draw_rect(Rect2(p + Vector2(0, -9), Vector2(14, 11)), OUTLINE)
	draw_rect(Rect2(p + Vector2(2, -7), Vector2(10, 8)), STONE_LIGHT * tint)
	draw_rect(Rect2(p + Vector2(2, -7), Vector2(10, 2)), (STONE_LIGHT * tint).lightened(0.2))
	draw_rect(Rect2(p + Vector2(10, -5), Vector2(2, 6)), STONE * tint)


func _tower(r: Rect2, tint: Color) -> void:
	_stones(r, tint)
	var x := r.position.x + 3.0
	while x + 12.0 <= r.end.x:
		_merlon(Vector2(x, r.position.y), tint)
		x += 18.0
	# A shadow under the battlements, and an arched window that's lamplit after dark.
	draw_rect(Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, 3), Color(0, 0, 0, 0.25))
	var mid := r.position.x + r.size.x / 2
	draw_rect(Rect2(mid - 5, r.position.y + 11, 10, 15), STONE_LIGHT * tint)   # the window's frame (its pane is in _draw_top)


## The gate: an arched wooden door behind an iron portcullis, in a ring of carved stones.
func _gate(base: Vector2, tint: Color) -> void:
	var half := 20.0
	var h := 34.0
	var top := base.y - h
	var c := Vector2(base.x, top + half)
	for i in 9:
		var a0 := PI + PI * i / 9.0
		var a1 := PI + PI * (i + 1) / 9.0
		var ring := PackedVector2Array([c + Vector2.from_angle(a0) * (half + 2), c + Vector2.from_angle(a0) * (half + 8),
				c + Vector2.from_angle(a1) * (half + 8), c + Vector2.from_angle(a1) * (half + 2)])
		draw_colored_polygon(ring, (STONE_LIGHT if i % 2 == 0 or i == 4 else STONE) * tint)
		draw_polyline(ring + PackedVector2Array([ring[0]]), OUTLINE, 1.0)
	Sprites.disc(self, Vector2(base.x, top + half), half + 2, OUTLINE)
	draw_rect(Rect2(base.x - half - 2, top + half, half * 2 + 4, h - half), OUTLINE)
	Sprites.disc(self, Vector2(base.x, top + half), half, WOOD * tint)
	draw_rect(Rect2(base.x - half, top + half, half * 2, h - half), WOOD * tint)
	for i in 5:
		var x := base.x - half + 4 + i * 8.0
		draw_line(Vector2(x, top + 4), Vector2(x, base.y), IRON, 2.0)
	for y in [top + 14, top + 24]:
		draw_line(Vector2(base.x - half, y), Vector2(base.x + half, y), IRON, 2.0)


## A torch in a bracket on the gatehouse (its glow after dark is in ambience.gd).
func _torch(ci: CanvasItem, at: Vector2) -> void:
	var f := 0.8 + 0.2 * sin(t * 13.0 + at.x) * sin(t * 7.3)
	ci.draw_rect(Rect2(at.x - 3, at.y + 2, 6, 2), OUTLINE)
	ci.draw_rect(Rect2(at.x - 1.5, at.y - 4, 3, 7), Color(0.4, 0.26, 0.13))
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-3, -4), at + Vector2(3, -4), at + Vector2(sin(t * 9.0 + at.x), -12 - 2 * f)]), Color(1.0, 0.55, 0.15))
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-1.5, -4), at + Vector2(1.5, -4), at + Vector2(0, -9 - f)]), Color(1.0, 0.9, 0.45))


## A long banner hanging down a corner tower, its tail swaying.
func _banner(ci: CanvasItem, top: Vector2, blue: bool) -> void:
	var cloth := Color(0.25, 0.38, 0.75) if blue else BANNER
	var sway := sin(t * 1.6 + top.x) * 1.0
	var pts := PackedVector2Array([top + Vector2(-8, 0), top + Vector2(8, 0), top + Vector2(8 + sway, 30), top + Vector2(sway, 25), top + Vector2(-8 + sway, 30)])
	ci.draw_colored_polygon(pts, cloth)
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), OUTLINE, 1.5)
	ci.draw_line(top + Vector2(-10, 0), top + Vector2(10, 0), Color(0.4, 0.26, 0.13), 2.0)
	ci.draw_line(top + Vector2(0, 6), top + Vector2(sway * 0.5, 20), BANNER_TRIM, 1.5)
	ci.draw_line(top + Vector2(-4, 9), top + Vector2(4, 9), BANNER_TRIM, 1.5)


## A clump of ivy climbing the wall from its foot.
func _ivy(foot: Vector2) -> void:
	for i in 10:
		var k := fposmod(sin(foot.x * 3.1 + i * 7.7) * 9871.3, 1.0)
		var k2 := fposmod(sin(foot.x * 1.7 + i * 3.3) * 5431.9, 1.0)
		var p := foot + Vector2(k * 18.0 - 9.0, -k2 * 22.0)
		draw_rect(Rect2(p, Vector2(4, 3)), Color(0.22, 0.42, 0.18) if i % 3 else Color(0.32, 0.55, 0.24))


## A banner flapping on a pole.
func _flag(ci: CanvasItem, base: Vector2, phase: float) -> void:
	var top := base + Vector2(0, -24)
	ci.draw_line(base, top, OUTLINE, 3.0)
	var pts := PackedVector2Array()
	var bottom_edge := PackedVector2Array()
	for i in 6:
		var x := i * 4.0
		var wave := sin(t * 5.0 + phase - i * 0.9) * (1.0 + i * 0.5)
		pts.append(top + Vector2(x + 1, wave))
		bottom_edge.append(top + Vector2(x + 1, 11 + wave))
	bottom_edge.reverse()
	var flag := pts + bottom_edge
	ci.draw_colored_polygon(flag, BANNER)
	ci.draw_polyline(pts, BANNER_TRIM, 2.0)


func _smoke(ci: CanvasItem, at: Vector2, dmg: float) -> void:
	for i in 4:
		var k := fmod(t * 0.5 + i * 0.25, 1.0)
		var p := at + Vector2(sin(t + i * 1.7) * 6.0 + k * 10.0, -k * 50.0)
		Sprites.disc(ci, p, 6.0 + k * 10.0, Color(0.3, 0.28, 0.27, 0.8 * (1.0 - k) * dmg))
