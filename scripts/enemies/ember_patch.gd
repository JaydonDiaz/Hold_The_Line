extends Node2D
## The Ogre King unbound's burning ground: a patch marked on the ground first (a ring
## filling, `warn` seconds), then it catches and burns whoever stands in it (troops; the
## enemy's own walk through unharmed) for `duration` seconds. On the ground layer.

var main
var radius := 50.0
var dps := 20.0
var duration := 6.0
var warn := 1.2
var t := 0.0
var tick := 0.0


func _ready() -> void:
	add_to_group("danger")


## The patch, marked or burning: troops get off it (main.dangers()).
func danger_zone() -> Dictionary:
	return {"c": position, "r": radius}


func _process(delta: float) -> void:
	if main.game_over:
		queue_free()
		return
	t += delta
	if t >= warn:
		tick -= delta
		if tick <= 0.0:
			tick = 0.25
			for w in main.battlefield.warriors_near(position, radius + 20.0):
				if w.is_active() and not w.sheltered() and w.position.distance_to(position) <= radius + w.RADIUS * 0.5:
					w.take_damage(dps * 0.25)
	if t >= warn + duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1.0, 0.6))
	if t < warn:
		var k := t / warn
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.3, 0.1, 0.12))
		draw_circle(Vector2.ZERO, radius * k, Color(1.0, 0.4, 0.15, 0.25))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(1.0, 0.35, 0.15, 0.9), 2.5, true)
	else:
		var fade := clampf((warn + duration - t) / 0.6, 0.0, 1.0)
		var flick := 0.8 + 0.2 * sin(t * 14.0)
		draw_circle(Vector2.ZERO, radius, Color(0.35, 0.05, 0.02, 0.5 * fade))
		draw_circle(Vector2.ZERO, radius * 0.8, Color(0.9, 0.25, 0.05, 0.45 * fade * flick))
		draw_circle(Vector2.ZERO, radius * 0.45, Color(1.0, 0.6, 0.15, 0.55 * fade * flick))
		draw_set_transform(Vector2.ZERO)
		for i in 7:
			var a := i * TAU / 7.0 + t * 0.7
			var p := Vector2(cos(a) * radius * 0.6, sin(a) * radius * 0.35)
			var h := 6.0 + 4.0 * sin(t * 11.0 + i)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-3, 0), p + Vector2(3, 0), p + Vector2(0, -h)]), Color(1.0, 0.7, 0.2, 0.9 * fade))
	draw_set_transform(Vector2.ZERO)
