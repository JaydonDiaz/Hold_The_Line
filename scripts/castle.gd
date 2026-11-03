extends Node2D
## The castle along the bottom of the field: what the player is holding the line for.
## Enemies that reach its wall stop and attack it; if its health runs out the game is
## lost. It shakes when hit, and shows the damage (cracks, then smoke, then fire) as
## its health falls.

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
	queue_redraw()


## 0 at full health, 1 when the castle is about to fall.
func _damage() -> float:
	return clampf(1.0 - main.castle_hp / main.castle_max, 0.0, 1.0)


func _draw() -> void:
	var w: float = main.FIELD_W
	var top: float = main.CASTLE_Y
	var bottom: float = main.FIELD_H
	var shake := Vector2(randf_range(-2.5, 2.5), randf_range(-1, 1)) * (hit / 0.35)
	draw_set_transform(shake)
	var tint := Color(1, 0.65, 0.6) if hit > 0.12 else Color.WHITE
	# Curtain wall with battlements.
	_stones(Rect2(0, top, w, bottom - top), tint)
	for x in range(6, int(w), 26):
		_merlon(Vector2(x, top), tint)
	# Gatehouse in the middle, corner towers at each end.
	var gate := Rect2(w / 2 - GATE_W / 2, top - GATE_RISE, GATE_W, bottom - top + GATE_RISE)
	_tower(gate, tint)
	_gate(Vector2(w / 2, bottom), tint)
	# A wide field gets extra towers along the wall, roughly every 400 pixels.
	var extra := int(w / 400.0) - 1
	for i in extra:
		var x: float = w * (i + 1) / (extra + 1)
		if absf(x - w / 2) > GATE_W:
			_tower(Rect2(x - TOWER_W / 2, top - TOWER_RISE * 0.6, TOWER_W, bottom - top + TOWER_RISE * 0.6), tint)
	_tower(Rect2(0, top - TOWER_RISE, TOWER_W, bottom - top + TOWER_RISE), tint)
	_tower(Rect2(w - TOWER_W, top - TOWER_RISE, TOWER_W, bottom - top + TOWER_RISE), tint)
	_flag(Vector2(TOWER_W / 2, top - TOWER_RISE - 8), 0.0)
	_flag(Vector2(w - TOWER_W / 2, top - TOWER_RISE - 8), 1.3)
	_flag(Vector2(w / 2, top - GATE_RISE - 8), 2.1)
	# Damage: cracks first, then smoke from the towers, then fire in the windows.
	var dmg := _damage()
	for i in int(cracks.size() * dmg):
		draw_polyline(cracks[i], OUTLINE, 2.0)
	if dmg >= 0.5:
		for x in [TOWER_W / 2, w - TOWER_W / 2, w / 2]:
			_smoke(Vector2(x, top - TOWER_RISE), dmg)
	if dmg > 0.0:
		# Health bar on the gatehouse.
		var bar := Rect2(w / 2 - 40, top - GATE_RISE - 34, 80, 6)
		draw_rect(bar.grow(1), OUTLINE)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * (1.0 - dmg), bar.size.y)), Color(0.35, 0.85, 0.35).lerp(Color(0.9, 0.2, 0.15), dmg))
	if dmg >= 0.75:
		for x in [TOWER_W / 2, w - TOWER_W / 2]:
			var flick := 0.6 + 0.4 * sin(t * 18.0 + x)
			draw_rect(Rect2(x - 3, top - 26, 6, 12), Color(1.0, 0.55, 0.1, flick))
	draw_set_transform(Vector2.ZERO)


## Mortared stone: staggered courses of blocks with a dark outline.
func _stones(r: Rect2, tint: Color) -> void:
	draw_rect(r, OUTLINE)
	var inner := r.grow(-2)
	draw_rect(inner, STONE * tint)
	var row := 0
	var y := inner.position.y
	while y < inner.end.y:
		draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), STONE_DARK, 1.0)
		draw_line(Vector2(inner.position.x, y + 1), Vector2(inner.end.x, y + 1), STONE_LIGHT * tint, 1.0)
		var x := inner.position.x + (0.0 if row % 2 == 0 else 8.0)
		while x < inner.end.x:
			draw_line(Vector2(x, y), Vector2(x, minf(y + 8, inner.end.y)), STONE_DARK, 1.0)
			x += 16.0
		y += 8.0
		row += 1


func _merlon(p: Vector2, tint: Color) -> void:
	draw_rect(Rect2(p + Vector2(0, -9), Vector2(14, 11)), OUTLINE)
	draw_rect(Rect2(p + Vector2(2, -7), Vector2(10, 8)), STONE_LIGHT * tint)


func _tower(r: Rect2, tint: Color) -> void:
	_stones(r, tint)
	var x := r.position.x + 3.0
	while x + 12.0 <= r.end.x:
		_merlon(Vector2(x, r.position.y), tint)
		x += 18.0
	# An arrow slit near the top.
	var mid := r.position.x + r.size.x / 2
	draw_rect(Rect2(mid - 3, r.position.y + 10, 6, 14), OUTLINE)


## The gate: an arched wooden door behind an iron portcullis.
func _gate(base: Vector2, tint: Color) -> void:
	var half := 20.0
	var h := 34.0
	var top := base.y - h
	draw_circle(Vector2(base.x, top + half), half + 2, OUTLINE)
	draw_rect(Rect2(base.x - half - 2, top + half, half * 2 + 4, h - half), OUTLINE)
	draw_circle(Vector2(base.x, top + half), half, WOOD * tint)
	draw_rect(Rect2(base.x - half, top + half, half * 2, h - half), WOOD * tint)
	for i in 5:
		var x := base.x - half + 4 + i * 8.0
		draw_line(Vector2(x, top + 4), Vector2(x, base.y), IRON, 2.0)
	for y in [top + 14, top + 24]:
		draw_line(Vector2(base.x - half, y), Vector2(base.x + half, y), IRON, 2.0)


## A banner flapping on a pole.
func _flag(base: Vector2, phase: float) -> void:
	var top := base + Vector2(0, -24)
	draw_line(base, top, OUTLINE, 3.0)
	var pts := PackedVector2Array()
	var bottom_edge := PackedVector2Array()
	for i in 6:
		var x := i * 4.0
		var wave := sin(t * 5.0 + phase - i * 0.9) * (1.0 + i * 0.5)
		pts.append(top + Vector2(x + 1, wave))
		bottom_edge.append(top + Vector2(x + 1, 11 + wave))
	bottom_edge.reverse()
	var flag := pts + bottom_edge
	draw_colored_polygon(flag, BANNER)
	draw_polyline(pts, BANNER_TRIM, 2.0)


func _smoke(at: Vector2, dmg: float) -> void:
	for i in 4:
		var k := fmod(t * 0.5 + i * 0.25, 1.0)
		var p := at + Vector2(sin(t + i * 1.7) * 6.0 + k * 10.0, -k * 50.0)
		draw_circle(p, 6.0 + k * 10.0, Color(0.3, 0.28, 0.27, 0.8 * (1.0 - k) * dmg), true, -1.0, true)
