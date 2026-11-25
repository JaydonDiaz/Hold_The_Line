extends Node2D
## A Skeleton Archer's arrow. Flies at the troop it was loosed at (following it), or at
## the castle wall; a troop that's gone down or got clear when it lands isn't hit.

var main
var shooter = null   # the enemy that loosed it (a ward throws some back at it)
var target = null          # the troop it's aimed at, or null for the castle
var target_pos := Vector2.ZERO
var speed := 360.0
var damage := 0.0
var style := "arrow"       # arrow, orb, frost, flask, note (a corrupted troop shoots as it did)
var splash := 0.0          # (an orb's or flask's burst: every troop this close to where it lands)
var goo := []              # [slow, seconds]: a frost shot slows the troop it hits


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
	if main.paths.tall_at(position):
		queue_free()   # into a castle's wall



func _land() -> void:
	if target == null:
		main.waves.damage_castle(damage)
	elif splash > 0.0:
		main.dmg_src = "arrows"
		for w in main.battlefield.warriors_near(position, splash + 20.0):
			if w.is_active() and not w.sheltered() and w.position.distance_to(position) <= splash + w.RADIUS:
				main.hurt_by = shooter if is_instance_valid(shooter) else null
				w.take_damage(damage)
				main.hurt_by = null
		main.dmg_src = ""
		main.effects.spawn_burst(position, splash, Color(0.6, 1.0, 0.5) if style == "flask" else Color(0.75, 0.5, 1.0))
	elif is_instance_valid(target) and target.is_active() and target.position.distance_to(position) <= target.RADIUS + 14.0:
		main.dmg_src = "arrows"
		main.hurt_by = shooter if is_instance_valid(shooter) else null
		target.take_damage(damage)
		main.hurt_by = null
		main.dmg_src = ""
		if not goo.is_empty() and target.is_active():
			target.apply_goo(float(goo[0]), float(goo[1]))
	queue_free()


func _draw() -> void:
	match style:
		"orb", "note":
			var c := Color(0.7, 0.45, 1.0) if style == "orb" else Color(0.85, 0.5, 0.95)
			draw_circle(Vector2.ZERO, 5.0, Color(c, 0.4))
			draw_circle(Vector2.ZERO, 3.0, c)
			return
		"frost":
			draw_circle(Vector2.ZERO, 4.5, Color(0.7, 0.95, 1.0, 0.45))
			draw_circle(Vector2.ZERO, 2.5, Color(0.9, 1.0, 1.0))
			return
		"flask":
			draw_circle(Vector2.ZERO, 4.0, Color(0.45, 0.85, 0.35))
			draw_rect(Rect2(-1.5, -7, 3, 4), Color(0.6, 0.5, 0.4))
			return
	# A bone-white shaft with a dark flint head and grey fletching.
	draw_line(Vector2(-11, 0), Vector2(3, 0), Color(0.9, 0.87, 0.78), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(7, 0), Vector2(2, -3), Vector2(2, 3)]), Color(0.25, 0.22, 0.2))
	draw_line(Vector2(-11, 0), Vector2(-14, -3), Color(0.6, 0.6, 0.62), 1.5)
	draw_line(Vector2(-11, 0), Vector2(-14, 3), Color(0.6, 0.6, 0.62), 1.5)
