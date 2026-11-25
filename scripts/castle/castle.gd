extends Node2D
## The castle along the bottom of the field: what the player is holding the line for.
## Enemies that reach its wall stop and attack it; if its health runs out the game is
## lost. It shakes when hit, and shows the damage (cracks, then smoke, then fire) as
## its health falls.

const Sprites = preload("res://scripts/art/sprites.gd")
const Data = preload("res://scripts/data/data.gd")
const OUTLINE := Color(0.1, 0.07, 0.1)
const STONE := Color(0.6, 0.58, 0.56)
const STONE_DARK := Color(0.44, 0.42, 0.42)
const STONE_LIGHT := Color(0.7, 0.68, 0.65)
const WOOD := Color(0.42, 0.26, 0.14)
const IRON := Color(0.3, 0.3, 0.34)
const BANNER := Color(0.75, 0.15, 0.15)
const BANNER_TRIM := Color(1.0, 0.82, 0.3)
# Castle styles (a map picks one; the open meadow has the keep). Same walls, towers, gate
# and wall-guard posts; the look is the region's: its stone, its banners and their emblem
# ("emblem"), a roof on the corner towers ("roof": "" for plain battlements), and the
# details on the wall ("extras").
#   emblems  hammer, leaf, anvil, sun, snowflake, lotus, coin (or "": a plain cross-stitch)
#   roofs    leaf (slender elven spires), pagoda (tiered, red, upturned eaves), tile
#            (terracotta), snow (slate under snow)
#   extras   chimney (forge stacks, smoking), garland (leafy swags with white flowers along
#            the wall), runes (carved, glowing), flowers (window boxes), stakes (sharpened
#            stakes at the wall's foot), icicles (and snow on the battlements), lattice
#            (a red-lacquered beam with gold studs), shields (guild shields hung on the wall)
const STYLES := {
	# Ashwatch's keep: pale frontier stone, red and blue banners, ivy.
	"keep": {"stone": STONE, "stone_dark": STONE_DARK, "stone_light": STONE_LIGHT, "wood": WOOD, "iron": IRON,
		"banner": BANNER, "banner_trim": BANNER_TRIM, "left_banner": Color(0.25, 0.38, 0.75), "ivy": true,
		"emblem": "", "roof": "", "extras": []},
	# Stonehollow's guildhall: dark basalt, bronze-banded gate, forge chimneys, the hammer.
	"guildhall": {"stone": Color(0.47, 0.45, 0.47), "stone_dark": Color(0.32, 0.3, 0.33), "stone_light": Color(0.58, 0.56, 0.58),
		"wood": Color(0.3, 0.19, 0.11), "iron": Color(0.66, 0.47, 0.2), "banner": Color(0.62, 0.36, 0.16),
		"banner_trim": Color(0.95, 0.72, 0.3), "left_banner": Color(0.62, 0.36, 0.16), "ivy": false,
		"emblem": "hammer", "roof": "", "extras": ["chimney"]},
	# Greenwood's elven hall: silvered timber, slender leaf-tipped spires, garlands of leaves
	# and white flowers, the Watch's green with a golden leaf.
	"timberhall": {"stone": Color(0.6, 0.5, 0.38), "stone_dark": Color(0.42, 0.33, 0.24), "stone_light": Color(0.74, 0.64, 0.5),
		"wood": Color(0.3, 0.2, 0.12), "iron": Color(0.78, 0.7, 0.4), "banner": Color(0.22, 0.52, 0.3),
		"banner_trim": Color(0.92, 0.82, 0.42), "left_banner": Color(0.22, 0.52, 0.3), "ivy": true,
		"emblem": "leaf", "roof": "leaf", "extras": ["garland"]},
	# Deepdelve's guild gate: dark granite cut square, bronze fittings, glowing rune-stones,
	# the Guild's ochre with an anvil.
	"guildgate": {"stone": Color(0.38, 0.37, 0.4), "stone_dark": Color(0.24, 0.23, 0.27), "stone_light": Color(0.5, 0.49, 0.52),
		"wood": Color(0.26, 0.17, 0.1), "iron": Color(0.72, 0.55, 0.25), "banner": Color(0.72, 0.52, 0.14),
		"banner_trim": Color(0.3, 0.22, 0.12), "left_banner": Color(0.72, 0.52, 0.14), "ivy": false,
		"emblem": "anvil", "roof": "", "extras": ["runes"]},
	# Mercy Vale's hospice wall: whitewashed stone, window boxes in flower, the Sanctuary's
	# blue and white with a sun.
	"hospice": {"stone": Color(0.86, 0.84, 0.78), "stone_dark": Color(0.66, 0.64, 0.6), "stone_light": Color(0.95, 0.94, 0.9),
		"wood": Color(0.42, 0.3, 0.2), "iron": Color(0.55, 0.56, 0.6), "banner": Color(0.3, 0.45, 0.8),
		"banner_trim": Color(0.96, 0.95, 0.9), "left_banner": Color(0.3, 0.45, 0.8), "ivy": true,
		"emblem": "sun", "roof": "", "extras": ["flowers"]},
	# The forward fort at Sable Crossing: rough field stone, soot-dark, stakes at its foot,
	# the Line's red.
	"fort": {"stone": Color(0.52, 0.5, 0.46), "stone_dark": Color(0.34, 0.32, 0.3), "stone_light": Color(0.62, 0.6, 0.55),
		"wood": Color(0.28, 0.18, 0.11), "iron": Color(0.45, 0.45, 0.48), "banner": Color(0.75, 0.2, 0.18),
		"banner_trim": Color(0.9, 0.78, 0.4), "left_banner": Color(0.75, 0.2, 0.18), "ivy": false,
		"emblem": "", "roof": "", "extras": ["stakes"]},
	# Frostmarch's frost keep: blue-grey stone under snow, icicles, slate roofs, the
	# Covenant's ice-blue with a snowflake.
	"frostkeep": {"stone": Color(0.64, 0.7, 0.76), "stone_dark": Color(0.45, 0.51, 0.58), "stone_light": Color(0.8, 0.86, 0.91),
		"wood": Color(0.32, 0.26, 0.22), "iron": Color(0.55, 0.62, 0.7), "banner": Color(0.35, 0.6, 0.85),
		"banner_trim": Color(0.95, 0.97, 1.0), "left_banner": Color(0.35, 0.6, 0.85), "ivy": false,
		"emblem": "snowflake", "roof": "snow", "extras": ["icicles"]},
	# The High Monastery's temple wall: grey mountain stone, tiered red pagoda roofs, a
	# lacquered beam with gold studs, the Order's saffron with a lotus.
	"temple": {"stone": Color(0.62, 0.58, 0.54), "stone_dark": Color(0.44, 0.4, 0.38), "stone_light": Color(0.74, 0.7, 0.65),
		"wood": Color(0.58, 0.16, 0.12), "iron": Color(0.85, 0.66, 0.26), "banner": Color(0.92, 0.58, 0.16),
		"banner_trim": Color(0.62, 0.12, 0.1), "left_banner": Color(0.62, 0.12, 0.1), "ivy": false,
		"emblem": "lotus", "roof": "pagoda", "extras": ["lattice"]},
	# The Free Cities' city wall: warm sandstone, terracotta roofs, guild shields hung along
	# it, the merchants' purple and teal with a gold coin.
	"cityhall": {"stone": Color(0.82, 0.72, 0.58), "stone_dark": Color(0.62, 0.52, 0.4), "stone_light": Color(0.92, 0.84, 0.7),
		"wood": Color(0.4, 0.25, 0.15), "iron": Color(0.8, 0.65, 0.3), "banner": Color(0.45, 0.25, 0.55),
		"banner_trim": Color(0.95, 0.78, 0.3), "left_banner": Color(0.2, 0.5, 0.55), "ivy": false,
		"emblem": "coin", "roof": "tile", "extras": ["shields"]},
	# The Arcane Spires' Conclave wall: pale starstone banded in violet, crystal spires
	# on the towers, rune-stones in the wall, the Conclave's violet with a star.
	"conclave": {"stone": Color(0.72, 0.7, 0.78), "stone_dark": Color(0.5, 0.48, 0.58), "stone_light": Color(0.84, 0.82, 0.9),
		"wood": Color(0.3, 0.22, 0.36), "iron": Color(0.62, 0.5, 0.9), "banner": Color(0.48, 0.32, 0.8),
		"banner_trim": Color(0.95, 0.85, 0.5), "left_banner": Color(0.48, 0.32, 0.8), "ivy": false,
		"emblem": "star", "roof": "crystal", "extras": ["runes"]},
}
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
var pal: Dictionary = STYLES["keep"]


## Dresses the castle in one of STYLES.
func set_style(style: String) -> void:
	pal = STYLES.get(style, STYLES["keep"])
	_drawn_state = Vector3(-1, -1, -1)
	queue_redraw()


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
		for w in main.battlefield.get_warriors():
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
	for i in (int(w / 160.0) if pal["ivy"] else 0):
		var ix: float = fposmod(i * 157.0 + 60.0, w)
		if absf(ix - w / 2.0) > GATE_W * 0.7 and ix > TOWER_W + 6.0 and ix < w - TOWER_W - 6.0:
			_ivy(Vector2(ix, bottom - 4))
	_extras(w, top, bottom, towers)
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
	var towers := _towers()
	var peak := 0.0   # how far a roof lifts the corner towers' flags
	if pal["roof"] != "":
		for i in range(1, towers.size()):
			peak = _roof(ci, towers[i])
	if pal["extras"].has("chimney"):
		for i in range(1, towers.size()):
			_chimney(ci, towers[i])
	_flag(ci, Vector2(TOWER_W / 2, top - TOWER_RISE - 8 - peak), 0.0)
	_flag(ci, Vector2(w - TOWER_W / 2, top - TOWER_RISE - 8 - peak), 1.3)
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
	draw_rect(inner, pal["stone_dark"] * tint)
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
				var c: Color = pal["stone"].lerp(pal["stone_light"] if k > 0.5 else pal["stone_dark"], absf(k - 0.5) * 1.1) * tint
				var b := Rect2(x0 + (0.0 if x0 == inner.position.x else 1.0), y + 1.0, x1 - x0 - 1.0, h - 1.0)
				draw_rect(b, c)
				draw_rect(Rect2(b.position, Vector2(b.size.x, 1)), c.lightened(0.15))
				if k > 0.93:
					draw_line(b.position + Vector2(4, 1), b.position + Vector2(8, h - 2), pal["stone_dark"] * tint, 1.0)
			x += 16.0
		y += 8.0
		row += 1
	# The wall's foot sits in a band of darker, larger stones.
	if r.end.y >= main.FIELD_H - 1.0:
		draw_rect(Rect2(inner.position.x, inner.end.y - 5, inner.size.x, 5), (pal["stone_dark"] * tint).darkened(0.25))


func _merlon(p: Vector2, tint: Color) -> void:
	draw_rect(Rect2(p + Vector2(0, -9), Vector2(14, 11)), OUTLINE)
	draw_rect(Rect2(p + Vector2(2, -7), Vector2(10, 8)), pal["stone_light"] * tint)
	draw_rect(Rect2(p + Vector2(2, -7), Vector2(10, 2)), (pal["stone_light"] * tint).lightened(0.2))
	draw_rect(Rect2(p + Vector2(10, -5), Vector2(2, 6)), pal["stone"] * tint)
	if pal["extras"].has("icicles"):
		draw_rect(Rect2(p + Vector2(0, -11), Vector2(14, 4)), OUTLINE)
		draw_rect(Rect2(p + Vector2(1, -10), Vector2(12, 3)), Color(0.96, 0.98, 1.0))


func _tower(r: Rect2, tint: Color) -> void:
	_stones(r, tint)
	var x := r.position.x + 3.0
	while x + 12.0 <= r.end.x:
		_merlon(Vector2(x, r.position.y), tint)
		x += 18.0
	# A shadow under the battlements, and an arched window that's lamplit after dark.
	draw_rect(Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, 3), Color(0, 0, 0, 0.25))
	var mid := r.position.x + r.size.x / 2
	draw_rect(Rect2(mid - 5, r.position.y + 11, 10, 15), pal["stone_light"] * tint)   # the window's frame (its pane is in _draw_top)


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
		draw_colored_polygon(ring, (pal["stone_light"] if i % 2 == 0 or i == 4 else pal["stone"]) * tint)
		draw_polyline(ring + PackedVector2Array([ring[0]]), OUTLINE, 1.0)
	Sprites.disc(self, Vector2(base.x, top + half), half + 2, OUTLINE)
	draw_rect(Rect2(base.x - half - 2, top + half, half * 2 + 4, h - half), OUTLINE)
	Sprites.disc(self, Vector2(base.x, top + half), half, pal["wood"] * tint)
	draw_rect(Rect2(base.x - half, top + half, half * 2, h - half), pal["wood"] * tint)
	for i in 5:
		var x := base.x - half + 4 + i * 8.0
		draw_line(Vector2(x, top + 4), Vector2(x, base.y), pal["iron"], 2.0)
	for y in [top + 14, top + 24]:
		draw_line(Vector2(base.x - half, y), Vector2(base.x + half, y), pal["iron"], 2.0)


## A torch in a bracket on the gatehouse (its glow after dark is in ambience.gd).
func _torch(ci: CanvasItem, at: Vector2) -> void:
	var f := 0.8 + 0.2 * sin(t * 13.0 + at.x) * sin(t * 7.3)
	ci.draw_rect(Rect2(at.x - 3, at.y + 2, 6, 2), OUTLINE)
	ci.draw_rect(Rect2(at.x - 1.5, at.y - 4, 3, 7), Color(0.4, 0.26, 0.13))
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-3, -4), at + Vector2(3, -4), at + Vector2(sin(t * 9.0 + at.x), -12 - 2 * f)]), Color(1.0, 0.55, 0.15))
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-1.5, -4), at + Vector2(1.5, -4), at + Vector2(0, -9 - f)]), Color(1.0, 0.9, 0.45))


## A long banner hanging down a corner tower, its tail swaying.
func _banner(ci: CanvasItem, top: Vector2, blue: bool) -> void:
	var cloth: Color = pal["left_banner"] if blue else pal["banner"]
	var sway := sin(t * 1.6 + top.x) * 1.0
	var pts := PackedVector2Array([top + Vector2(-8, 0), top + Vector2(8, 0), top + Vector2(8 + sway, 30), top + Vector2(sway, 25), top + Vector2(-8 + sway, 30)])
	ci.draw_colored_polygon(pts, cloth)
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), OUTLINE, 1.5)
	ci.draw_line(top + Vector2(-10, 0), top + Vector2(10, 0), Color(0.4, 0.26, 0.13), 2.0)
	var trim: Color = pal["banner_trim"]
	var c := top + Vector2(sway * 0.4, 13)
	match pal["emblem"]:
		"hammer":   # the guild's hammer
			ci.draw_line(top + Vector2(sway * 0.3, 8), top + Vector2(sway * 0.5, 22), trim, 2.0)
			ci.draw_rect(Rect2(top + Vector2(-4 + sway * 0.3, 6), Vector2(8, 4)), trim)
		"anvil":    # the Mining Guild's anvil
			ci.draw_rect(Rect2(c + Vector2(-5, -3), Vector2(10, 3)), trim)
			ci.draw_rect(Rect2(c + Vector2(-2, 0), Vector2(4, 4)), trim)
			ci.draw_rect(Rect2(c + Vector2(-4, 4), Vector2(8, 2)), trim)
		"leaf":     # the Watch's leaf
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(4, -1), c + Vector2(0, 6), c + Vector2(-4, -1)]), trim)
			ci.draw_line(c + Vector2(0, -5), c + Vector2(0, 7), cloth.darkened(0.3), 1.0)
		"sun":      # the Sanctuary's sun
			Sprites.disc(ci, c, 3.0, trim)
			for k in 8:
				ci.draw_line(c + Vector2.from_angle(k * TAU / 8.0) * 4.0, c + Vector2.from_angle(k * TAU / 8.0) * 6.5, trim, 1.0)
		"snowflake":   # the Covenant's snowflake
			for k in 3:
				var d := Vector2.from_angle(k * PI / 3.0) * 6.0
				ci.draw_line(c - d, c + d, trim, 1.5)
		"lotus":    # the Order's lotus
			for k in [-1.0, 0.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(k * 4.0, 3), c + Vector2(k * 4.0 - 2.5 + k, -2 + absf(k) * 2.0),
						c + Vector2(k * 5.0, -6 + absf(k) * 3.0), c + Vector2(k * 4.0 + 2.5 + k, -2 + absf(k) * 2.0)]), trim)
			ci.draw_line(c + Vector2(-6, 4), c + Vector2(6, 4), trim, 1.0)
		"star":     # the Conclave's star
			for k in 4:
				var d := Vector2.from_angle(k * PI / 4.0) * (6.0 if k % 2 == 0 else 4.0)
				ci.draw_line(c - d, c + d, trim, 1.5)
			Sprites.disc(ci, c, 1.5, Color(1, 1, 1))
		"coin":     # the merchants' coin
			Sprites.disc(ci, c, 5.0, trim)
			Sprites.disc(ci, c, 3.0, trim.darkened(0.25))
			ci.draw_line(c + Vector2(0, -2), c + Vector2(0, 2), trim, 1.0)
		_:
			ci.draw_line(top + Vector2(0, 6), top + Vector2(sway * 0.5, 20), trim, 1.5)
			ci.draw_line(top + Vector2(-4, 9), top + Vector2(4, 9), trim, 1.5)


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
	ci.draw_colored_polygon(flag, pal["banner"])
	ci.draw_polyline(pts, pal["banner_trim"], 2.0)


func _smoke(ci: CanvasItem, at: Vector2, dmg: float) -> void:
	for i in 4:
		var k := fmod(t * 0.5 + i * 0.25, 1.0)
		var p := at + Vector2(sin(t + i * 1.7) * 6.0 + k * 10.0, -k * 50.0)
		Sprites.disc(ci, p, 6.0 + k * 10.0, Color(0.3, 0.28, 0.27, 0.8 * (1.0 - k) * dmg))


# --- The region's details --------------------------------------------------------------------

## The wall's details for the style's "extras" (with the stonework: drawn when it changes).
func _extras(w: float, top: float, bottom: float, towers: Array) -> void:
	var ex: Array = pal["extras"]
	var clear := func(x: float, half: float) -> bool:   # clear of the towers (and the gatehouse)
		for r in towers:
			if x + half > r.position.x - 2.0 and x - half < r.end.x + 2.0:
				return false
		return true
	if ex.has("garland"):
		# Leafy swags hung between the merlons' feet, white flowers in them.
		var x := 0.0
		while x < w:
			var x1 := x + 52.0
			if clear.call(x + 26.0, 30.0):
				for k in 13:
					var f := k / 12.0
					var p := Vector2(lerpf(x, x1, f), top + 6.0 + sin(f * PI) * 9.0)
					draw_rect(Rect2(p + Vector2(-2, -2), Vector2(5, 4)), OUTLINE)
					draw_rect(Rect2(p + Vector2(-1, -1), Vector2(3, 2)), Color(0.28, 0.55, 0.26) if k % 2 else Color(0.38, 0.66, 0.3))
					if k % 4 == 2:
						draw_rect(Rect2(p + Vector2(0, 1), Vector2(2, 2)), Color(0.98, 0.96, 0.9))
			x = x1 + 6.0
	if ex.has("runes"):
		# Carved rune-stones set in the wall, their marks glowing amber.
		var x := 100.0
		while x < w - 100.0:
			var c := Vector2(x, top + 16.0)
			x += 120.0
			if not clear.call(c.x, 12.0):
				continue
			draw_rect(Rect2(c + Vector2(-9, -9), Vector2(18, 18)), OUTLINE)
			draw_rect(Rect2(c + Vector2(-8, -8), Vector2(16, 16)), pal["stone_light"])
			var glow := Color(1.0, 0.7, 0.25)
			draw_line(c + Vector2(-4, -5), c + Vector2(-4, 5), glow, 1.5)
			draw_line(c + Vector2(-4, -1), c + Vector2(4, -5), glow, 1.5)
			draw_line(c + Vector2(-4, 1), c + Vector2(4, 5), glow, 1.5)
			draw_line(c + Vector2(4, -5), c + Vector2(4, 5), glow, 1.5)
	if ex.has("flowers"):
		# Window boxes along the wall, in flower.
		var x := 70.0
		while x < w - 70.0:
			if clear.call(x, 16.0):
				var p := Vector2(x, top + 18.0)
				draw_rect(Rect2(p + Vector2(-7, -10), Vector2(14, 10)), OUTLINE)
				draw_rect(Rect2(p + Vector2(-6, -9), Vector2(12, 8)), Color(0.22, 0.2, 0.26))
				draw_rect(Rect2(p + Vector2(-10, 0), Vector2(20, 6)), OUTLINE)
				draw_rect(Rect2(p + Vector2(-9, 1), Vector2(18, 4)), pal["wood"])
				for k in 5:
					draw_rect(Rect2(p + Vector2(-8 + k * 4, -3), Vector2(3, 3)), [Color(0.95, 0.4, 0.5), Color(1.0, 0.85, 0.3), Color(0.95, 0.95, 0.95)][k % 3])
					draw_rect(Rect2(p + Vector2(-8 + k * 4, -1), Vector2(3, 1)), Color(0.3, 0.6, 0.28))
			x += 110.0
	if ex.has("stakes"):
		# Sharpened stakes along the wall's foot, leaning out.
		var x := TOWER_W + 6.0
		while x < w - TOWER_W - 6.0:
			if absf(x - w / 2.0) > GATE_W * 0.5 + 8.0:
				var foot := Vector2(x, bottom - 2.0)
				var tip := foot + Vector2(-5, -18)
				draw_line(foot, tip, OUTLINE, 4.0)
				draw_line(foot, tip, Color(0.5, 0.36, 0.22), 2.0)
				draw_rect(Rect2(tip + Vector2(-1, -1), Vector2(2, 2)), Color(0.82, 0.72, 0.55))
			x += 14.0
	if ex.has("icicles"):
		# Icicles hanging from under the battlements.
		var x := 4.0
		var i := 0
		while x < w:
			var drop := 4.0 + fposmod(sin(x * 7.13) * 431.7, 1.0) * 9.0
			draw_colored_polygon(PackedVector2Array([Vector2(x - 2, top + 2), Vector2(x + 2, top + 2), Vector2(x, top + 2 + drop)]), Color(0.86, 0.94, 1.0))
			draw_line(Vector2(x - 1, top + 3), Vector2(x - 1, top + 1 + drop * 0.6), Color(1, 1, 1, 0.8), 1.0)
			x += 9.0 + (i % 3) * 3.0
			i += 1
	if ex.has("lattice"):
		# A red-lacquered beam along the wall, gold studs on it.
		for seg in [[TOWER_W, w / 2.0 - GATE_W / 2.0], [w / 2.0 + GATE_W / 2.0, w - TOWER_W]]:
			var r := Rect2(seg[0], top + 6.0, seg[1] - seg[0], 6.0)
			draw_rect(r.grow(1.0), OUTLINE)
			draw_rect(r, pal["wood"])
			draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), pal["wood"].lightened(0.3))
			var x: float = r.position.x + 8.0
			while x < r.end.x - 4.0:
				draw_rect(Rect2(x - 1, r.position.y + 2, 2, 2), pal["iron"])
				x += 16.0
	if ex.has("shields"):
		# Guild shields hung along the wall, each in a different livery.
		var cols := [Color(0.45, 0.25, 0.55), Color(0.2, 0.5, 0.55), Color(0.75, 0.25, 0.2), Color(0.25, 0.4, 0.7)]
		var x := 90.0
		var i := 0
		while x < w - 90.0:
			if clear.call(x, 12.0):
				var p := Vector2(x, top + 12.0)
				var sh := PackedVector2Array([p + Vector2(-7, -6), p + Vector2(7, -6), p + Vector2(7, 2), p + Vector2(0, 9), p + Vector2(-7, 2)])
				draw_colored_polygon(sh, OUTLINE)
				var inner := PackedVector2Array([p + Vector2(-6, -5), p + Vector2(6, -5), p + Vector2(6, 2), p + Vector2(0, 7.5), p + Vector2(-6, 2)])
				draw_colored_polygon(inner, cols[i % cols.size()])
				draw_line(p + Vector2(0, -5), p + Vector2(0, 7), pal["iron"], 1.5)
			x += 96.0
			i += 1


## A roof on tower r in the style's "roof"; returns how far above the battlements it
## rises (a flag goes on top of it).
func _roof(ci: CanvasItem, r: Rect2) -> float:
	var mid := r.position.x + r.size.x / 2.0
	var base := r.position.y - 6.0
	var half := r.size.x / 2.0 + 4.0
	match pal["roof"]:
		"leaf":
			# A slender elven spire, curving to a point, a golden leaf at its tip.
			var green := Color(0.24, 0.5, 0.32)
			var pts := PackedVector2Array()
			for k in 9:
				var f := k / 8.0
				pts.append(Vector2(mid - half * 0.8 * (1.0 - f) * (1.0 - f * 0.3), base - f * 46.0))
			for k in range(8, -1, -1):
				var f := k / 8.0
				pts.append(Vector2(mid + half * 0.8 * (1.0 - f) * (1.0 - f * 0.3), base - f * 46.0))
			ci.draw_colored_polygon(pts, green)
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), OUTLINE, 2.0)
			ci.draw_line(Vector2(mid, base - 4), Vector2(mid, base - 40), green.lightened(0.25), 1.5)
			for k in 3:
				var y := base - 8.0 - k * 11.0
				var hw := half * 0.8 * (1.0 - (base - y) / 46.0)
				ci.draw_line(Vector2(mid - hw + 2, y), Vector2(mid + hw - 2, y), Color(0.85, 0.76, 0.4), 1.0)
			var tip := Vector2(mid, base - 50.0)
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -6), tip + Vector2(4, 0), tip + Vector2(0, 5), tip + Vector2(-4, 0)]), Color(0.92, 0.8, 0.35))
			return 52.0
		"pagoda":
			# Two tiers of red roof with upturned eaves, a gold finial.
			var red := Color(0.62, 0.15, 0.12)
			for tier in 2:
				var y := base - tier * 18.0
				var hw := half + 6.0 - tier * 12.0
				var roof := PackedVector2Array([Vector2(mid - hw - 4, y - 6), Vector2(mid - hw + 6, y - 2), Vector2(mid - hw * 0.4, y - 14),
						Vector2(mid + hw * 0.4, y - 14), Vector2(mid + hw - 6, y - 2), Vector2(mid + hw + 4, y - 6), Vector2(mid + hw - 2, y + 2),
						Vector2(mid - hw + 2, y + 2)])
				ci.draw_colored_polygon(roof, red)
				ci.draw_polyline(roof + PackedVector2Array([roof[0]]), OUTLINE, 2.0)
				ci.draw_line(Vector2(mid - hw + 4, y), Vector2(mid + hw - 4, y), Color(0.85, 0.66, 0.26), 1.5)
				if tier == 0:
					ci.draw_rect(Rect2(mid - hw * 0.45, y - 18, hw * 0.9, 5), Color(0.3, 0.12, 0.1))
			ci.draw_line(Vector2(mid, base - 32), Vector2(mid, base - 44), OUTLINE, 3.0)
			ci.draw_line(Vector2(mid, base - 32), Vector2(mid, base - 44), Color(0.9, 0.7, 0.28), 1.5)
			Sprites.disc(ci, Vector2(mid, base - 44), 2.5, Color(0.95, 0.78, 0.35))
			return 46.0
		"crystal":
			# A spire of violet crystal standing out of the tower, lit along one face.
			var tip := Vector2(mid, base - 46)
			var body := PackedVector2Array([Vector2(mid - half * 0.55, base), Vector2(mid - half * 0.4, base - 24), tip,
					Vector2(mid + half * 0.4, base - 24), Vector2(mid + half * 0.55, base)])
			ci.draw_colored_polygon(body, Color(0.52, 0.36, 0.86))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(mid, base), Vector2(mid, base - 24), tip, Vector2(mid + half * 0.4, base - 24), Vector2(mid + half * 0.55, base)]), Color(0.68, 0.5, 1.0))
			ci.draw_polyline(body + PackedVector2Array([body[0]]), OUTLINE, 2.0)
			ci.draw_line(Vector2(mid + 3, base - 6), tip + Vector2(1, 6), Color(0.9, 0.8, 1.0), 1.5)
			var glow := 0.5 + 0.5 * sin(t * 2.0 + mid)
			ci.draw_circle(tip + Vector2(0, 8), 7.0 + glow * 2.0, Color(0.75, 0.6, 1.0, 0.18))
			return 50.0
		"tile", "snow":
			# A cone of terracotta tiles, or of slate with snow on it.
			var col := Color(0.72, 0.36, 0.22) if pal["roof"] == "tile" else Color(0.36, 0.4, 0.48)
			var roof := PackedVector2Array([Vector2(mid - half, base), Vector2(mid + half, base), Vector2(mid, base - 38)])
			ci.draw_colored_polygon(roof, col)
			for k in 4:
				var y := base - 6.0 - k * 8.0
				var hw := half * (1.0 - (base - y) / 38.0)
				ci.draw_line(Vector2(mid - hw, y), Vector2(mid + hw, y), col.darkened(0.25), 1.0)
			if pal["roof"] == "snow":
				ci.draw_colored_polygon(PackedVector2Array([Vector2(mid - half * 0.45, base - 21), Vector2(mid, base - 38),
						Vector2(mid + half * 0.45, base - 21), Vector2(mid + half * 0.2, base - 18), Vector2(mid, base - 22),
						Vector2(mid - half * 0.25, base - 17)]), Color(0.96, 0.98, 1.0))
				ci.draw_rect(Rect2(mid - half, base - 3, half * 2.0, 4), Color(0.96, 0.98, 1.0))
			ci.draw_polyline(roof + PackedVector2Array([roof[0]]), OUTLINE, 2.0)
			return 38.0
	return 0.0


## A forge chimney on tower r, smoke curling from it.
func _chimney(ci: CanvasItem, r: Rect2) -> void:
	var at := Vector2(r.end.x - 15.0, r.position.y - 4.0)
	var brick := Color(0.55, 0.3, 0.22)
	ci.draw_rect(Rect2(at + Vector2(-8, -28), Vector2(16, 30)), OUTLINE)
	ci.draw_rect(Rect2(at + Vector2(-7, -27), Vector2(14, 28)), brick)
	for y in range(-24, 0, 6):
		ci.draw_line(at + Vector2(-7, y), at + Vector2(7, y), brick.darkened(0.3), 1.0)
	ci.draw_rect(Rect2(at + Vector2(-7, -14), Vector2(14, 3)), pal["iron"])   # a bronze band
	ci.draw_rect(Rect2(at + Vector2(-10, -32), Vector2(20, 6)), OUTLINE)
	ci.draw_rect(Rect2(at + Vector2(-9, -31), Vector2(18, 4)), brick.lightened(0.15))
	var ember := 0.6 + 0.4 * sin(t * 5.0 + at.x)
	ci.draw_rect(Rect2(at + Vector2(-6, -31), Vector2(12, 2)), Color(1.0, 0.5, 0.15, ember))
	for i in 4:
		var k := fmod(t * 0.35 + i / 4.0, 1.0)
		Sprites.disc(ci, at + Vector2(sin(t * 0.8 + i * 2.0) * 3.0 + k * 10.0, -36.0 - k * 40.0), 4.0 + k * 7.0, Color(0.3, 0.28, 0.28, 0.7 * (1.0 - k)))
