extends Control
## The start screen's picture, drawn in code and alive: a night sky whose stars twinkle,
## the Ogre King's silhouette over the hills with a red rim and eyes that smoulder, and
## below him the Line's nine kinds of troop (the game's own sprites), each with a little
## life of its own: breathing, the Mage's and Frost Witch's staves glowing, the Healer's
## aura, the Bard's notes drifting up, the Alchemist's flask fizzing.

const Sprites = preload("res://scripts/sprites.gd")
const W := 640.0
const H := 1040.0
const OUTLINE := Color(0.06, 0.04, 0.07)
const SCALE := 6.0
# The troops: [kind, centre x, foot y, facing left].
const TROOPS := [["bard", 222.0, 726.0, false], ["alchemist", 418.0, 726.0, true],
	["mage", 120.0, 852.0, false], ["healer", 320.0, 846.0, false], ["frost", 520.0, 852.0, true],
	["archer", 128.0, 990.0, false], ["swordsman", 320.0, 1030.0, false], ["martial", 512.0, 990.0, true]]

var t := 0.0
var stars: Array = []   # [position, size, twinkle phase]


func _ready() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in 90:
		stars.append([Vector2(rng.randf_range(4, W - 4), rng.randf_range(4, 520)), 2.0 if rng.randf() < 0.8 else 4.0, rng.randf() * TAU])


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	_sky()
	_ogre()
	_hills()
	for tr in TROOPS:
		_troop(tr[0], Vector2(tr[1], tr[2]), tr[3])


func _sky() -> void:
	var bands := 26
	for i in bands:
		var k := float(i) / (bands - 1)
		var c := Color(0.03, 0.025, 0.06).lerp(Color(0.2, 0.06, 0.07), pow(k, 2.2))
		draw_rect(Rect2(0, H * 0.62 * k, W, H * 0.62 / bands + 2), c)
	for s in stars:
		var a: float = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 1.7 + s[2]))
		var p: Vector2 = s[0]
		draw_rect(Rect2(p, Vector2(s[1], s[1])), Color(1, 0.97, 0.9, a))
		if s[1] > 2.0 and a > 0.85:   # the bright ones glint
			draw_rect(Rect2(p + Vector2(-3, 1), Vector2(10, 2)), Color(1, 0.97, 0.9, (a - 0.85) * 4.0))
			draw_rect(Rect2(p + Vector2(1, -3), Vector2(2, 10)), Color(1, 0.97, 0.9, (a - 0.85) * 4.0))


## The Ogre King over the hills: shoulders, head and crown, a club over his shoulder,
## rimmed in red; tusks, and eyes that smoulder and now and then flare.
func _ogre() -> void:
	var rise := sin(t * 0.6) * 3.0   # slow breathing
	var body := PackedVector2Array([Vector2(0, 600), Vector2(40, 540), Vector2(120, 488), Vector2(196, 462), Vector2(210, 430),
		Vector2(196, 380), Vector2(192, 300), Vector2(214, 252), Vector2(262, 226), Vector2(320, 220), Vector2(378, 226),
		Vector2(426, 252), Vector2(448, 300), Vector2(444, 380), Vector2(430, 430), Vector2(444, 462), Vector2(520, 488),
		Vector2(600, 540), Vector2(640, 570), Vector2(640, 700), Vector2(0, 700)])
	for i in body.size():
		if body[i].y < 690:
			body[i].y += rise
	var club := PackedVector2Array([Vector2(540, 500), Vector2(590, 236), Vector2(606, 226), Vector2(632, 240), Vector2(578, 506)])
	draw_colored_polygon(club, Color(0.05, 0.03, 0.05))
	draw_polyline(PackedVector2Array([club[0], club[1], club[2], club[3], club[4]]), Color(0.55, 0.08, 0.06, 0.9), 3.0)
	draw_colored_polygon(body, Color(0.04, 0.025, 0.045))
	var rim := PackedVector2Array()
	for p in body:
		if p.y < 690:
			rim.append(p)
	draw_polyline(rim, Color(0.6, 0.09, 0.07, 0.9), 3.0)
	# The crown: four points, gold studs.
	var cy := 230.0 + rise
	var crown := PackedVector2Array([Vector2(222, cy), Vector2(222, cy - 40), Vector2(260, cy - 12), Vector2(284, cy - 58), Vector2(320, cy - 14),
		Vector2(356, cy - 58), Vector2(380, cy - 12), Vector2(418, cy - 40), Vector2(418, cy)])
	draw_polyline(crown, Color(0.6, 0.09, 0.07), 3.0)
	for p in [crown[1], crown[3], crown[5], crown[7]]:
		draw_circle(p, 5.0, Color(0.72, 0.5, 0.18))
	# Eyes: a slow smoulder, and every few seconds a flare.
	var flare := clampf(1.0 - absf(fmod(t, 5.0) - 4.6) * 4.0, 0.0, 1.0)
	var glow := 0.65 + 0.2 * sin(t * 2.2) + 0.35 * flare
	for side in [-1.0, 1.0]:
		var e := Vector2(320 + side * 58, 374 + rise)
		draw_circle(e, 34.0 + 10.0 * flare, Color(1.0, 0.45, 0.1, 0.12 * glow))
		var lid := PackedVector2Array([e + Vector2(-30, 4), e + Vector2(-20, -8), e + Vector2(20, -8), e + Vector2(30, 4), e + Vector2(14, 10), e + Vector2(-14, 10)])
		draw_colored_polygon(lid, Color(0.95, 0.42, 0.08).lerp(Color(1, 0.85, 0.4), glow - 0.6))
		draw_rect(Rect2(e + Vector2(-12, -3), Vector2(24, 6)), Color(1, 0.95, 0.6, glow))
	# Tusks.
	for side in [-1.0, 1.0]:
		var tusk := Vector2(320 + side * 52, 440 + rise)
		draw_colored_polygon(PackedVector2Array([tusk + Vector2(-5, 0), tusk + Vector2(5, 0), tusk + Vector2(0, 30)]), Color(0.55, 0.5, 0.45))


## The dark hills he stands behind, then the field the Line stands on.
func _hills() -> void:
	var hill := PackedVector2Array([Vector2(0, 640)])
	for i in 17:
		var x := i * 40.0
		hill.append(Vector2(x, 596 + sin(i * 1.3) * 18.0 + sin(i * 0.5) * 12.0))
	hill.append(Vector2(W, 640))
	draw_colored_polygon(hill, Color(0.17, 0.06, 0.07))
	draw_rect(Rect2(0, 640, W, H - 640), Color(0.12, 0.2, 0.1))
	for i in 140:
		var p := Vector2(fmod(i * 97.3, W), 650 + fmod(i * 53.1, H - 660))
		draw_rect(Rect2(p, Vector2(3, 3)), Color(0.2, 0.32, 0.15) if i % 3 else Color(0.08, 0.14, 0.07))
	# Fireflies drifting over the grass.
	for i in 10:
		var f := Vector2(fmod(i * 131.0 + t * (8 + i), W), 700 + fmod(i * 77.0, 300) + sin(t * 1.3 + i) * 10.0)
		draw_circle(f, 2.0, Color(0.85, 1.0, 0.5, 0.4 + 0.4 * sin(t * 3.0 + i)))


## One troop: its sprite at SCALE, breathing, and its kind's own touch of life.
func _troop(kind: String, foot: Vector2, left: bool) -> void:
	var fr: Array = Sprites.frames(kind)
	var size := Vector2(Sprites.SIZE, Sprites.SIZE) * SCALE
	var phase := foot.x * 0.01
	var breathe := sin(t * 2.0 + phase) * 2.0
	var top := foot + Vector2(-size.x / 2.0, -size.y + breathe)
	draw_texture_rect(Sprites.shadow(), Rect2(foot + Vector2(-38, -10), Vector2(76, 20)), false, Color(0, 0, 0, 0.35))
	match kind:
		"healer":
			var a := 0.18 + 0.08 * sin(t * 2.0)
			draw_circle(foot + Vector2(0, -48), 74.0, Color(0.5, 1.0, 0.5, a * 0.5))
			draw_set_transform(foot + Vector2(0, -4), 0.0, Vector2(1.0, 0.32))   # (a ring on the ground)
			draw_arc(Vector2.ZERO, 70.0, 0, TAU, 40, Color(0.75, 1.0, 0.5, a + 0.25), 4.0)
			draw_set_transform(Vector2.ZERO)
		"mage", "frost":
			var c := Color(0.8, 0.45, 1.0) if kind == "mage" else Color(0.6, 0.92, 1.0)
			var orb := foot + Vector2(-38.0 if left else 38.0, -92.0 + breathe)   # (the staff's head, on its own side)
			draw_circle(orb, 44.0 + 4.0 * sin(t * 3.0), Color(c, 0.12))
			draw_circle(orb, 20.0, Color(c, 0.3))
	draw_set_transform(Vector2(top.x + (size.x if left else 0.0), top.y), 0.0, Vector2(-1.0 if left else 1.0, 1.0))
	draw_texture_rect(fr[0], Rect2(Vector2.ZERO, size), false)
	draw_set_transform(Vector2.ZERO)
	match kind:
		"bard":
			for i in 3:
				var k := fmod(t * 0.5 + i / 3.0, 1.0)
				var n := foot + Vector2(-50 + sin(k * 6.0 + i) * 12.0, -110 - k * 90.0)
				var col: Color = [Color(1, 0.85, 0.3), Color(0.5, 0.85, 1.0), Color(1, 0.6, 0.85)][i]
				col.a = 1.0 - k
				draw_rect(Rect2(n, Vector2(7, 6)), col)
				draw_rect(Rect2(n + Vector2(5, -16), Vector2(2, 16)), col)
		"alchemist":
			for i in 4:
				var k := fmod(t * 0.8 + i * 0.25, 1.0)
				var b := foot + Vector2(54 + sin(k * 9.0 + i) * 6.0, -120 - k * 50.0)
				draw_rect(Rect2(b, Vector2(5, 5)), Color(0.55, 1.0, 0.4, 1.0 - k))
		"mage", "frost":
			for i in 3:
				var a2 := t * 1.6 + i * TAU / 3.0
				var orb2 := foot + Vector2(-38.0 if left else 38.0, -92.0 + breathe)
				draw_rect(Rect2(orb2 + Vector2(cos(a2) * 26.0, sin(a2) * 12.0) - Vector2(2, 2), Vector2(5, 5)),
						Color(1, 1, 1, 0.85))
