extends Node2D
## Fires still burning on a field the Ogre King's army has fought over (map decor "fire",
## whose scorch the ground has painted): flames licking up from charred timbers, and smoke
## drifting off them. On the ground layer, under everyone.

var spots: Array = []   # where they burn (on the field as it's stretched)
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	for i in spots.size():
		var p: Vector2 = spots[i]
		var ph := i * 1.7
		# Smoke, rising and spreading as it fades.
		for k in 4:
			var life := fmod(t * 0.35 + k * 0.25 + ph * 0.13, 1.0)
			var c := p + Vector2(sin(life * 3.0 + ph) * 8.0 + life * 10.0, -14.0 - life * 70.0)
			draw_circle(c, 5.0 + life * 12.0, Color(0.22, 0.2, 0.2, 0.32 * (1.0 - life)))
		# The flames: three tongues, each flickering on its own.
		for k in 3:
			var x := -7.0 + k * 7.0
			var h := 12.0 + 6.0 * sin(t * (9.0 + k * 2.3) + ph + k) + 3.0 * sin(t * 17.0 + k)
			var base := p + Vector2(x, 0)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-5, 0), base + Vector2(5, 0), base + Vector2(sin(t * 6.0 + k) * 2.0, -h)]),
					Color(0.95, 0.35, 0.1, 0.9))
			draw_colored_polygon(PackedVector2Array([base + Vector2(-3, 0), base + Vector2(3, 0), base + Vector2(sin(t * 7.0 + k) * 1.5, -h * 0.65)]),
					Color(1.0, 0.75, 0.25, 0.95))
		draw_circle(p + Vector2(0, -4), 16.0, Color(1.0, 0.5, 0.15, 0.08 + 0.03 * sin(t * 11.0 + ph)))
		# Sparks.
		for k in 3:
			var life := fmod(t * 0.9 + k * 0.33 + ph, 1.0)
			draw_rect(Rect2(p + Vector2(sin(ph + k * 2.0) * 9.0, -6.0 - life * 34.0), Vector2(1, 1)), Color(1.0, 0.7, 0.3, 1.0 - life))
