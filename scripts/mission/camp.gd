extends Node2D
## The work camp at the bottom of a battlefield without a castle: where your troops come
## from and where the Engineers set out from (they leave by the camp's gate, the spot the
## castle gate would be). It marks the line the enemy mustn't cross: a row of stakes
## along the bottom edge, tents at the sides and the banner over the middle.

const OUTLINE := Color(0.1, 0.07, 0.1)
const PX := 3.0

var main
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _b(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(floorf(x / PX) * PX, floorf(y / PX) * PX, w * PX, h * PX), c)


func _draw() -> void:
	var w: float = main.FIELD_W
	var top: float = main.CASTLE_Y
	var bottom: float = main.FIELD_H
	# Trodden ground behind the line.
	draw_rect(Rect2(0, top + 6, w, bottom - top - 6), Color(0.42, 0.34, 0.24))
	for i in int(w / 18.0):
		var x := fposmod(i * 37.0, w)
		_b(x, top + 12 + fposmod(i * 13.0, bottom - top - 18), 2, 1, Color(0.36, 0.29, 0.2))
	# The line: sharpened stakes, red tips, with gaps where the road runs through.
	for x in range(6, int(w), 15):
		if absf(x - w / 2.0) < 36.0:
			continue   # the camp's gate
		_b(x, top - 6, 2, 5, Color(0.5, 0.34, 0.2))
		_b(x, top - 9, 2, 1, Color(0.75, 0.2, 0.18))
		_b(x - 1, top - 6, 1, 5, OUTLINE)
	# Tents at the sides.
	for side in [0.12, 0.88]:
		var cx: float = w * side
		for row in 9:
			var half := row * 0.8 + 1.0
			_b(cx - half * PX - PX, top + 2 + row * PX, half * 2.0 + 2.0, 1, OUTLINE)
			_b(cx - half * PX, top + 2 + row * PX, half * 2.0, 1, Color(0.86, 0.8, 0.66) if row < 8 else Color(0.7, 0.64, 0.5))
		_b(cx - PX, top + 2 + 5 * PX, 2, 4, Color(0.3, 0.22, 0.15))
	# The banner over the gate, stirring in the wind.
	var gx: float = w / 2.0
	_b(gx - 30, top - 30, 1, 34, Color(0.45, 0.32, 0.2))
	var wave := int(t * 4.0) % 2
	_b(gx - 27, top - 30 + wave * PX, 6, 4, Color(0.3, 0.45, 0.85))
	_b(gx - 27, top - 30 + wave * PX, 6, 1, Color(1, 0.85, 0.3))
	# A campfire by the gate.
	var flick := 1.0 + floorf(1.5 + 1.5 * sin(t * 9.0))
	_b(gx + 24, top + 16, 4, 1, Color(0.4, 0.28, 0.18))
	_b(gx + 27, top + 16 - flick * PX, 2, flick, Color(1, 0.55, 0.15))
	_b(gx + 27, top + 16 - PX, 1, 1, Color(1, 0.9, 0.5))
