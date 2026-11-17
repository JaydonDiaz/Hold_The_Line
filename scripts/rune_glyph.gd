extends Node2D
## A Sunfire Glyph (the Arcane Obelisk's third rune): a circle of fire runes burned into the
## ground under a crowd of enemies. While it lasts it burns whatever walks in it (not what
## flies over), and sets it on fire, burning on after it's out; at Solar Seal it bursts as
## it fades. On the ground layer, under everyone.

var main
var radius := 50.0
var dps := 12.0
var duration := 4.0
var burst := 0.0
var burn := 0.0      # what walks in it catches fire: this much a second, for 3s after
var credit := ""
var t := 0.0
var tick := 0.0


func _process(delta: float) -> void:
	if main.game_over:
		queue_free()
		return
	t += delta
	tick -= delta
	if tick <= 0.0:
		tick = 0.25
		if main.campaign:
			main.credit = credit
		for e in main.enemies_near(position, radius + 30.0):
			if not e.dead and not e.flying and e.position.distance_to(position) <= radius + e.radius * 0.5:
				e.take_damage(dps * 0.25, false, "magic")
				if burn > 0.0:
					e.apply_burn(burn, 3.0)
	if t >= duration:
		if burst > 0.0:
			if main.campaign:
				main.credit = credit
			for e in main.enemies_near(position, radius + 30.0):
				if not e.dead and e.position.distance_to(position) <= radius + e.radius:
					e.take_damage(burst, true, "magic")
			main.spawn_flash(position, radius * 0.8)
			main.spawn_burst(position, radius, Color(1.0, 0.6, 0.2))
			main.sfx("boom", 1.2)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var fade := clampf(minf(t / 0.3, (duration - t) / 0.6), 0.0, 1.0)
	var flick := 0.85 + 0.15 * sin(t * 13.0)
	# The scorched circle, the ring of runes round it turning slowly, a star at its heart.
	draw_circle(Vector2.ZERO, radius, Color(0.35, 0.08, 0.02, 0.35 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 0.55, 0.15, 0.85 * fade * flick), 3.0, true)
	draw_arc(Vector2.ZERO, radius - 9.0, 0.0, TAU, 48, Color(1.0, 0.75, 0.3, 0.6 * fade * flick), 1.5, true)
	for i in 8:
		var a := t * 0.6 + i * TAU / 8.0
		var p := Vector2.from_angle(a) * (radius - 4.5)
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.85, 0.4, fade * flick))
	for i in 5:
		var a := -PI / 2.0 + i * TAU / 5.0
		var b := -PI / 2.0 + (i + 2) * TAU / 5.0
		draw_line(Vector2.from_angle(a) * radius * 0.6, Vector2.from_angle(b) * radius * 0.6, Color(1.0, 0.6, 0.2, 0.7 * fade * flick), 2.0)
