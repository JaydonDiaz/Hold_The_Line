extends Node2D
## An Alchemist's charge (Trapcraft), dropped on the ground while walking. Arms after a
## moment, then blows up when an enemy on foot steps on it, hurting everything in the
## blast. It stays put until something sets it off, even between waves.

const ARM_TIME := 0.6
const TRIGGER := 12.0   # how close an enemy's edge must come to set it off

var main
var damage := 25.0
var radius := 40.0
var stun := 0.0
var poison := {}    # with Alchemical Mines: the flasks' poison and acid come along
var corrode := {}
var source := 0     # instance id of the Alchemist that laid it (its poison doesn't stack with others')
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if t < ARM_TIME:
		return
	for e in main.get_enemies():
		if not e.flying and e.position.distance_to(position) <= TRIGGER + e.radius:
			_explode()
			return


func _explode() -> void:
	for e in main.get_enemies():
		if e.flying or e.position.distance_to(position) > radius + e.radius:
			continue
		e.take_damage(damage)
		if e.dead:
			continue
		if stun > 0.0:
			e.apply_stun(stun)
		if not poison.is_empty():
			e.apply_poison(poison["dps"], poison["duration"], poison["stacks"], source)
		if not corrode.is_empty():
			e.apply_corrode(corrode["amount"], corrode["duration"])
	main.spawn_burst(position, radius, Color(1.0, 0.55, 0.2))
	main.spawn_burst(position, radius * 0.5, Color(1.0, 0.95, 0.6))
	main.sfx("boom", 1.2)
	if not poison.is_empty():
		main.spawn_burst(position, radius * 0.8, Color(0.55, 1.0, 0.3))
	queue_free()


func _draw() -> void:
	# A squat clay pot half-buried in the dirt, its fuse light blinking once armed.
	var a := minf(t / ARM_TIME, 1.0)
	draw_set_transform(Vector2(0, 3), 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 8.0, Color(0, 0, 0, 0.3 * a), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2(0, 0), 6.0, Color(0.1, 0.07, 0.1, 0.9), true, -1.0, true)
	draw_circle(Vector2(0, 0), 4.5, Color(0.55, 0.35, 0.2, 0.9) if poison.is_empty() else Color(0.4, 0.55, 0.25, 0.9), true, -1.0, true)
	draw_rect(Rect2(-1.5, -8, 3, 3), Color(0.1, 0.07, 0.1, 0.9))
	if t >= ARM_TIME and int(t * 2.5) % 2 == 0:
		draw_circle(Vector2(0, -8), 2.0, Color(1.0, 0.3, 0.2), true, -1.0, true)
