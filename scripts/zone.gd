extends Node2D
## A patch of ground that works on every enemy inside it until it fades: the Bard's
## Overgrowth (tangled grass that slows) or an Alchemist's toxic cloud (poisons).

var main
var radius := 70.0
var slow := 0.5
var poison := {}         # dps, duration, stacks: a stack every POISON_TICK while inside
var source := 0          # instance id of the Alchemist whose cloud it is
var style := "plants"    # "plants" or "toxic"
var poison_tick := 0.0
var life := 4.0
var t := 0.0
const POISON_TICK := 0.5
var tufts := []   # [offset, height, flower?] picked once so the patch doesn't flicker


func _ready() -> void:
	for i in int(radius * 0.5):
		var off := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * radius
		tufts.append([off * Vector2(1, 0.6), randf_range(4, 9), randf() < 0.2])


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	poison_tick -= delta
	var dose := not poison.is_empty() and poison_tick <= 0.0
	if dose:
		poison_tick = POISON_TICK
	for e in main.get_enemies():
		var off: Vector2 = e.position - position
		if style == "plants" and e.flying:
			continue   # grass doesn't slow what flies over it
		if (off * Vector2(1, 1.0 / 0.6)).length() <= radius + e.radius:
			if slow > 0.0:
				e.apply_slow(slow, 0.25)
			if dose:
				e.apply_poison(poison["dps"], poison["duration"], poison["stacks"], source)
	queue_redraw()


func _draw() -> void:
	var grow := minf(t / 0.4, 1.0)            # sprouts up quickly
	var fade := clampf((life - t) / 0.6, 0.0, 1.0)  # and withers at the end
	var a := grow * fade
	if style == "toxic":
		_draw_toxic(a)
		return
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.6))
	draw_circle(Vector2.ZERO, radius, Color(0.2, 0.45, 0.15, 0.35 * a), true, -1.0, true)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(0.35, 0.7, 0.25, 0.6 * a), 2.0, true)
	draw_set_transform(Vector2.ZERO)
	for tuft in tufts:
		var p: Vector2 = tuft[0]
		var h: float = tuft[1] * grow
		var sway := sin(t * 4.0 + p.x * 0.1) * 1.5
		draw_line(p, p + Vector2(sway, -h), Color(0.3, 0.7, 0.2, a), 2.0)
		if tuft[2]:
			draw_circle(p + Vector2(sway, -h), 2.0, Color(1.0, 0.75, 0.85, a), true, -1.0, true)


func _draw_toxic(a: float) -> void:
	# A sickly green haze with bubbles rising and popping.
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.6))
	draw_circle(Vector2.ZERO, radius, Color(0.45, 0.8, 0.2, 0.22 * a), true, -1.0, true)
	draw_circle(Vector2(radius * 0.2, -radius * 0.1), radius * 0.6, Color(0.55, 0.3, 0.7, 0.14 * a), true, -1.0, true)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(0.55, 0.9, 0.3, 0.5 * a), 2.0, true)
	draw_set_transform(Vector2.ZERO)
	for i in tufts.size() / 2:
		var p: Vector2 = tufts[i][0]
		var k := fmod(t * 0.8 + i * 0.37, 1.0)
		draw_circle(p + Vector2(0, -k * 14.0), 1.5 + k * 2.0, Color(0.6, 1.0, 0.35, a * (1.0 - k)), false, 1.0, true)
