extends Node2D
## A Skeleton Archer's arrow. Flies at the troop it was loosed at (following it), or at
## the castle wall; a troop that's gone down or got clear when it lands isn't hit.

var main
var target = null          # the troop it's aimed at, or null for the castle
var target_pos := Vector2.ZERO
var speed := 360.0
var damage := 0.0


func _process(delta: float) -> void:
	if target != null and is_instance_valid(target) and target.is_active():
		target_pos = target.position + Vector2(0, -8)
	var to := target_pos - position
	var step := speed * delta
	if to.length() <= step:
		position = target_pos
		_land()
		return
	position += to.normalized() * step
	rotation = to.angle()


func _land() -> void:
	if target == null:
		main.damage_castle(damage)
	elif is_instance_valid(target) and target.is_active() and target.position.distance_to(position) <= target.RADIUS + 14.0:
		target.take_damage(damage)
	queue_free()


func _draw() -> void:
	# A bone-white shaft with a dark flint head and grey fletching.
	draw_line(Vector2(-11, 0), Vector2(3, 0), Color(0.9, 0.87, 0.78), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(7, 0), Vector2(2, -3), Vector2(2, 3)]), Color(0.25, 0.22, 0.2))
	draw_line(Vector2(-11, 0), Vector2(-14, -3), Color(0.6, 0.6, 0.62), 1.5)
	draw_line(Vector2(-11, 0), Vector2(-14, 3), Color(0.6, 0.6, 0.62), 1.5)
