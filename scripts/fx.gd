extends Node2D
## Short-lived visual effect: floating text, an expanding ring, a lightning bolt,
## a flame stream, a beam, a tornado, a musical note or a rain of fire arrows.

const Sprites = preload("res://scripts/sprites.gd")
var mode := "text"
var text := ""
var color := Color.WHITE
var radius := 30.0
var points := PackedVector2Array()   # bolt/beam path in local coordinates
var life := 0.7
var tex: Texture2D = null   # "fall": the enemy's sprite, its drawn size and facing, and how high it flew
var size := Vector2.ZERO
var flip := 1.0
var height := 0.0
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	if mode == "text":
		position.y -= 35.0 * delta
	elif mode == "tornado":
		position.y -= 220.0 * delta   # whirls off up the field, the way the enemies came
	elif mode == "note":
		position += Vector2(sin(t * 9.0) * 25.0, -45.0) * delta
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - t / life
	match mode:
		"fall":
			# Tips over sideways (a flyer drops out of the air first), then fades into the grass.
			var k := minf(t / (life * 0.45), 1.0)
			var fade := clampf((1.0 - t / life) * 2.2, 0.0, 1.0)
			var ease_k := k * k
			var drop := height * (1.0 - ease_k)
			draw_set_transform(Vector2(0, radius - drop), -flip * ease_k * PI * 0.5, Vector2(flip, 1.0))
			draw_texture_rect(tex, Rect2(Vector2(-size.x / 2, -size.y), size), false, Color(1, 0.75, 0.75, fade))
			draw_set_transform(Vector2.ZERO)
			if k >= 1.0 or height == 0.0:
				# The dust it kicks up.
				var d := t / life
				for i in 5:
					var ang := PI + i * PI / 4.0
					var p := Vector2(cos(ang) * radius * (0.6 + d), radius + sin(ang) * radius * 0.25 * (1.0 + d))
					var sz := 3.0 + 3.0 * d
					draw_texture_rect(Sprites.white(), Rect2(p - Vector2(sz, sz) / 2, Vector2(sz, sz)), false, Color(0.75, 0.68, 0.55, 0.5 * (1.0 - d)))
		"text":
			draw_string_outline(ThemeDB.fallback_font, Vector2(-40, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 80, 18, 4, Color(0, 0, 0, a))
			draw_string(ThemeDB.fallback_font, Vector2(-40, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 80, 18, Color(color, a))
		"burst":
			draw_arc(Vector2.ZERO, radius * (0.4 + 0.6 * t / life), 0, TAU, 32, Color(color, a), 3.0, true)
		"bolt":
			draw_polyline(points, Color(color, a), 4.0, true)
			draw_polyline(points, Color(1, 1, 1, a), 1.5, true)
		"flame":
			# Puffs streaming from the mouth to the target, yellow near the source, red at the end.
			var from := points[0]
			var to := points[1]
			for i in 6:
				var k := fmod(t / life + i / 6.0, 1.0)
				var p := from.lerp(to, k) + Vector2(sin(i * 2.3 + t * 30.0), cos(i * 1.7 + t * 25.0)) * 4.0 * k
				var col := Color(1.0, 0.9, 0.3).lerp(Color(1.0, 0.3, 0.1), k)
				var sz := 3.0 + 5.0 * k
				draw_rect(Rect2(p - Vector2(sz, sz) / 2, Vector2(sz, sz)), Color(col, a * 0.9))
		"flash":
			Sprites.disc(self, Vector2.ZERO, radius * (0.6 + 0.4 * t / life), Color(1, 1, 0.9, a * 0.7))
			draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(1, 1, 0.8, a), 3.0, true)
		"beam":
			draw_line(points[0], points[1], Color(color, a * 0.5), radius * 0.4 * a + 2.0, true)
			draw_line(points[0], points[1], Color(1, 1, 1, a), 3.0, true)
			Sprites.disc(self, points[1], 14.0 * (1.0 - a) + 6.0, Color(color, a * 0.6))
		"tornado":
			# A grey funnel of spinning bands, wide at the top.
			var spin := t * 25.0
			for i in 7:
				var y := -i * 8.0
				var w := radius * (0.25 + i * 0.12)
				var sway := sin(spin * 0.3 + i * 0.8) * 4.0
				draw_arc(Vector2(sway, y), w, spin + i, spin + i + PI * 1.4, 12, Color(0.85, 0.88, 0.92, a * 0.8), 3.0, true)
		"rain":
			# Flaming arrows streaking down into a circle, then a flare on the ground.
			for i in 10:
				var ang := i * 2.4
				var spot := Vector2(cos(ang), sin(ang) * 0.6) * radius * fmod(i * 0.37, 1.0)
				var k := clampf(t / life * 1.6 - fmod(i * 0.13, 0.5), 0.0, 1.0)
				var tip := spot + Vector2(-0.3, -1.0) * 70.0 * (1.0 - k)
				if k < 1.0:
					draw_line(tip, tip + Vector2(-0.3, -1.0) * 12.0, Color(0.95, 0.85, 0.7, a), 2.0, true)
					Sprites.disc(self, tip, 2.5, Color(1.0, 0.6, 0.15, a))
				else:
					Sprites.disc(self, spot, 4.0, Color(1.0, 0.5, 0.1, a * 0.8))
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.6))
			Sprites.disc(self, Vector2.ZERO, radius, Color(1.0, 0.45, 0.1, 0.18 * a))
			draw_set_transform(Vector2.ZERO)
		"note":
			# A musical note floating up from the Bard.
			Sprites.disc(self, Vector2.ZERO, 3.5, Color(color, a))
			draw_line(Vector2(3, 0), Vector2(3, -11), Color(color, a), 2.0, true)
			draw_line(Vector2(3, -11), Vector2(8, -8), Color(color, a), 2.0, true)
