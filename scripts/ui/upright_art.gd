extends Control
## The card: a phone turning from its side to upright, and the words.
var t := 0.0

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	# Drawn to the screen's size (a phone on its side is short: the game's scale is tiny there).
	var k := minf(size.x, size.y) / 300.0
	var c := size / 2.0 - Vector2(0, 30 * k)
	var turn := clampf(fmod(t, 2.4) / 1.2 - 0.5, 0.0, 1.0)
	draw_set_transform(c, -PI / 2.0 * (1.0 - turn), Vector2(k, k))
	draw_rect(Rect2(-34, -60, 68, 120), Color(0.05, 0.035, 0.03))
	draw_rect(Rect2(-31, -57, 62, 114), Color(0.58, 0.58, 0.63))
	draw_rect(Rect2(-26, -48, 52, 92), Color(0.24, 0.17, 0.11))
	draw_rect(Rect2(-6, 48, 12, 4), Color(0.36, 0.36, 0.4))
	draw_set_transform(Vector2.ZERO)
	var f: Font = ThemeDB.fallback_font
	var line := "Turn your phone upright to play"
	var fs := int(22 * k)
	while fs > 12 and f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 24.0:
		fs -= 1
	var w := f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2((size.x - w) / 2.0, c.y + 100 * k), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.8, 0.32))
