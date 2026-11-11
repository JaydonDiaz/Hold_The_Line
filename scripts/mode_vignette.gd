extends Control
## A Battle Modes card's own little scene, looping in place of the bobbing character: what
## that kind of battle is about, played out in pixel art (seen from the side, the ground
## along the bottom). Each card's character is in it.
##   positions  goblins run at the watchtowers, and an Archer shoots them down
##   pass       goblins rush a Swordsman holding the way, and bounce off
##   protect    a beacon's fire builds up till it blazes, a Mage beside it
##   evac       villagers walk out of their village to safety, a Healer with them
##   capture    a flag climbs the old fort's pole, turning from red to yours
##   escort     the wagon rolls down the road, a Bard walking ahead
##   retreat    a line falls back, step by step, as the horde comes on

const Sprites = preload("res://scripts/sprites.gd")
const OUTLINE := Color(0.1, 0.07, 0.1)
const S := 2.0   # sprite scale

var kind := ""
var look := ""
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


## A sprite standing at x (its feet on the ground line), facing right unless `left`.
func _spr(name: String, x: float, frame := 0, left := false, y_off := 0.0, col := Color.WHITE) -> void:
	var tex: Texture2D = Sprites.frames(name)[frame % 2]
	var w := Sprites.SIZE * S
	var foot := size.y - 2.0 + y_off
	draw_set_transform(Vector2(x, foot), 0.0, Vector2(-1.0 if left else 1.0, 1.0))
	draw_texture_rect(tex, Rect2(-w / 2.0, -w, w, w), false, col)
	draw_set_transform(Vector2.ZERO)


func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(floorf(x), floorf(y), w, h), c)


func _ground(c := Color(0.32, 0.5, 0.26)) -> void:
	_px(0, size.y - 3, size.x, 3, c)


func _walk(speed: float) -> int:
	return int(t * speed) % 2


func _draw() -> void:
	match kind:
		"positions":
			_positions()
		"pass":
			_pass()
		"protect":
			_protect()
		"evac":
			_evac()
		"capture":
			_capture()
		"escort":
			_escort()
		"retreat":
			_retreat()


func _tower(x: float, flag: Color) -> void:
	var g := size.y - 3.0
	_px(x - 7, g - 30, 3, 30, OUTLINE)
	_px(x + 4, g - 30, 3, 30, OUTLINE)
	_px(x - 6, g - 29, 1, 29, Color(0.55, 0.37, 0.22))
	_px(x + 5, g - 29, 1, 29, Color(0.55, 0.37, 0.22))
	_px(x - 9, g - 38, 18, 9, OUTLINE)
	_px(x - 8, g - 37, 16, 7, Color(0.55, 0.37, 0.22))
	_px(x - 2, g - 35, 4, 3, Color(1.0, 0.7, 0.3))
	_px(x - 10, g - 41, 20, 3, Color(0.42, 0.3, 0.3))
	_px(x, g - 48, 1, 7, OUTLINE)
	_px(x + 1, g - 48 + floorf(sin(t * 5.0 + x)), 5, 2, flag)


func _positions() -> void:
	_ground()
	var w := size.x
	_tower(w * 0.2, Color(0.3, 0.45, 0.85))
	_tower(w * 0.78, Color(0.3, 0.45, 0.85))
	# A goblin runs at the right tower; the Archer shoots it down; again.
	var loop := fmod(t, 2.6)
	var gx := w + 10.0 - loop * 40.0
	_spr(look, w * 0.45, 0)
	if loop < 1.6:
		_spr("goblin", gx, _walk(8.0), true)
		if loop > 1.1:
			var k := (loop - 1.1) / 0.5
			var ax := lerpf(w * 0.45 + 10.0, gx - 6.0, k)
			_px(ax, size.y - 20, 6, 1, Color(0.9, 0.85, 0.7))   # the arrow
	elif loop < 2.0:
		_spr("goblin", gx, 0, true, (loop - 1.6) * 20.0, Color(1, 1, 1, 1.0 - (loop - 1.6) / 0.4))   # down it goes


func _pass() -> void:
	_ground(Color(0.42, 0.36, 0.26))
	var w := size.x
	for x in [4.0, w - 10.0]:
		_px(x, size.y - 16, 6, 13, Color(0.45, 0.42, 0.4))   # the pass's rocks
	_spr(look, w * 0.5, int(t * 3.0) % 2)
	# Goblins rush in from both sides and bounce off the Swordsman.
	for side in [-1.0, 1.0]:
		var loop := fmod(t + (0.0 if side > 0.0 else 0.9), 1.8)
		var gx: float
		var hop := 0.0
		if loop < 1.2:
			gx = w * 0.5 + side * lerpf(w * 0.5 + 8.0, 22.0, loop / 1.2)
		else:
			var k := (loop - 1.2) / 0.6
			gx = w * 0.5 + side * (22.0 + k * 50.0)
			hop = -sin(k * PI) * 12.0
		_spr("goblin", gx, _walk(9.0), side > 0.0, hop)


func _protect() -> void:
	_ground()
	var w := size.x
	var g := size.y - 3.0
	var cx := w * 0.6
	# The beacon: a stone tower, its fire growing over a few seconds, then a blaze.
	_px(cx - 7, g - 30, 14, 30, OUTLINE)
	_px(cx - 6, g - 29, 12, 29, Color(0.72, 0.68, 0.62))
	for i in 4:
		_px(cx - 6, g - 26 + i * 7, 12, 1, Color(0.5, 0.47, 0.44))
	_px(cx - 8, g - 33, 16, 4, OUTLINE)
	var loop := fmod(t, 4.0)
	var k := loop / 3.4
	var h := 2.0 + minf(k, 1.0) * 14.0 + floorf(sin(t * 12.0) * 1.5)
	_px(cx - 5, g - 33 - h, 10, h, Color(0.85, 0.22, 0.08))
	_px(cx - 3, g - 33 - h * 0.75, 6, h * 0.75, Color(1.0, 0.55, 0.15))
	_px(cx - 1, g - 33 - h * 0.45, 2, h * 0.45, Color(1.0, 0.95, 0.6))
	if loop > 3.4:
		var f := (loop - 3.4) / 0.6   # lit: a bright flash, and sparks flying up
		draw_circle(Vector2(cx, g - 42), 6.0 + f * 10.0, Color(1, 0.95, 0.6, 0.8 * (1.0 - f)))
		for i in 5:
			var a := -PI / 2.0 + (i - 2) * 0.45
			var p := Vector2(cx, g - 42) + Vector2.from_angle(a) * (6.0 + f * 22.0)
			_px(p.x, p.y, 2, 2, Color(1, 0.8, 0.3, 1.0 - f))
	_spr(look, w * 0.25, int(t * 2.0) % 2)


func _evac() -> void:
	_ground()
	var w := size.x
	var g := size.y - 3.0
	# The village behind (left), and the camp's stakes ahead (right).
	_px(4, g - 14, 16, 14, OUTLINE)
	_px(5, g - 13, 14, 13, Color(0.88, 0.84, 0.74))
	_px(2, g - 20, 20, 7, Color(0.78, 0.62, 0.32))
	_px(10, g - 7, 4, 7, Color(0.5, 0.32, 0.18))
	for i in 3:
		_px(w - 6 - i * 5, g - 9, 2, 9, Color(0.5, 0.34, 0.2))
		_px(w - 6 - i * 5, g - 11, 2, 2, Color(0.75, 0.2, 0.18))
	# A family walking out, one after another, and a Healer seeing them along.
	var people := ["villager", "villager_woman", "villager_child", "villager_elder"]
	var span := w + 30.0
	for i in people.size():
		var x := fmod(t * 22.0 + i * 26.0, span) - 10.0
		_spr(people[i], x, _walk(6.0) + i, false, -absf(sin(t * 9.0 + i)) * 1.5)
	_spr(look, fmod(t * 22.0 + 4 * 26.0, span) - 10.0, _walk(6.0))


func _capture() -> void:
	_ground()
	var w := size.x
	var g := size.y - 3.0
	var cx := w * 0.6
	# The fort's broken walls, and its flagpole.
	for x in [cx - 26.0, cx - 18.0, cx + 14.0, cx + 22.0]:
		var h := 8.0 if int(x) % 3 == 0 else 12.0
		_px(x, g - h, 7, h, OUTLINE)
		_px(x + 1, g - h + 1, 5, h - 1, Color(0.62, 0.6, 0.56))
	_px(cx, g - 40, 1, 40, OUTLINE)
	var loop := fmod(t, 3.6)
	var k := minf(loop / 2.8, 1.0)
	var fy := g - 8.0 - k * 30.0
	var col := Color(0.85, 0.25, 0.2).lerp(Color(0.3, 0.45, 0.85), clampf((k - 0.5) * 2.0, 0.0, 1.0))
	_px(cx + 1, fy + floorf(sin(t * 6.0)), 9, 5, col)
	if loop > 2.8:
		_px(cx - 3, g - 44, 7, 1, Color(1, 0.9, 0.4, 1.0 - (loop - 2.8)))   # a glint up top
	_spr(look, w * 0.22, int(t * 4.0) % 2, false, -absf(sin(t * 4.0)) * 5.0)   # cheering


func _escort() -> void:
	_ground(Color(0.42, 0.36, 0.26))
	var w := size.x
	var g := size.y - 3.0
	# The road scrolls by under the wagon.
	for i in 6:
		var x := fposmod(i * 30.0 - t * 30.0, w + 30.0) - 15.0
		_px(x, g + 1, 8, 1, Color(0.3, 0.25, 0.18))
	var bob := floorf(sin(t * 10.0) * 0.6)
	var wx := w * 0.42
	# The ox.
	_px(wx + 26, g - 13 + bob, 16, 9, OUTLINE)
	_px(wx + 27, g - 12 + bob, 14, 7, Color(0.55, 0.4, 0.28))
	_px(wx + 40, g - 15 + bob, 6, 6, Color(0.55, 0.4, 0.28))
	_px(wx + 28 + _walk(6.0) * 2, g - 5, 2, 5, OUTLINE)
	_px(wx + 37 - _walk(6.0) * 2, g - 5, 2, 5, OUTLINE)
	# The wagon: bed, canvas tilt and two turning wheels.
	_px(wx - 18, g - 14 + bob, 40, 6, OUTLINE)
	_px(wx - 17, g - 13 + bob, 38, 4, Color(0.5, 0.33, 0.18))
	_px(wx - 15, g - 27 + bob, 34, 14, OUTLINE)
	_px(wx - 14, g - 26 + bob, 32, 12, Color(0.92, 0.88, 0.76))
	for x in [wx - 10.0, wx + 14.0]:
		var c := Vector2(x, g - 5)
		draw_circle(c, 5.5, OUTLINE)
		draw_circle(c, 4.0, Color(0.5, 0.33, 0.18))
		var a := t * 6.0
		draw_line(c - Vector2.from_angle(a) * 4.0, c + Vector2.from_angle(a) * 4.0, OUTLINE, 1.0)
		draw_line(c - Vector2.from_angle(a + PI / 2.0) * 4.0, c + Vector2.from_angle(a + PI / 2.0) * 4.0, OUTLINE, 1.0)
	_spr(look, w * 0.88, _walk(6.0))


func _retreat() -> void:
	_ground()
	var w := size.x
	var g := size.y - 3.0
	# Line markers scroll by as the troops fall back (to the left), facing the enemy.
	for i in 3:
		var x := fposmod(i * 55.0 + t * 18.0, w + 40.0) - 20.0
		for k in 3:
			_px(x, g - 2 - k * 4, 2, 2, Color(0.85, 0.75, 0.4))
	var step := fmod(t, 1.2)
	var back := -absf(sin(step / 1.2 * PI)) * 2.0
	_spr(look, w * 0.22 + back, _walk(3.0), false)
	_spr("swordsman", w * 0.36 + back, _walk(3.0) + 1, false)
	# The horde, coming on.
	for i in 3:
		var gx := w * 0.62 + i * 18.0 + sin(t * 3.0 + i) * 3.0
		_spr(["goblin", "orc", "goblin"][i], gx, _walk(8.0) + i, true)
