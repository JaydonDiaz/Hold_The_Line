extends Node2D
## A Boltflinger's bolt: flies straight on along the line it was loosed down (it doesn't
## follow anyone), through every troop in its way, each struck once, up to `pierce` of them,
## a little weaker for each it's been through; it stops at the end of its flight, or a wall.

var main
var shooter = null   # the enemy that loosed it (a ward throws some back at it)
var dir := Vector2.DOWN
var speed := 520.0
var damage := 20.0
var pierce := 4            # how many troops it goes through
var falloff := 0.2         # ...this much less for each it's been through
var left := 260.0          # how much further it flies
var hit := {}              # troops it's struck (each once)


func _ready() -> void:
	rotation = dir.angle()


func _process(delta: float) -> void:
	var step := speed * delta
	var from := position
	position += dir * minf(step, left)
	left -= step
	# Everyone along the stretch it covered this frame (so a fast bolt can't skip a troop).
	for w in main.warriors_near(position, step + 30.0):
		if not w.is_active() or w.sheltered() or hit.has(w):
			continue
		var c := Geometry2D.get_closest_point_to_segment(w.position + Vector2(0, -6), from, position)
		if c.distance_to(w.position + Vector2(0, -6)) <= w.RADIUS + 5.0:
			hit[w] = true
			main.dmg_src = "bolts"
			main.hurt_by = shooter if is_instance_valid(shooter) else null
			w.take_damage(damage * pow(1.0 - falloff, hit.size() - 1))
			main.hurt_by = null
			main.dmg_src = ""
			main.spawn_burst(w.position + Vector2(0, -8), 8.0, Color(0.85, 0.8, 0.7))
			if hit.size() > pierce:
				queue_free()
				return
	if left <= 0.0 or main.paths.tall_at(position):
		queue_free()


func _draw() -> void:
	# A heavy iron-headed bolt with dark fletching, a streak behind it.
	draw_line(Vector2(-26, 0), Vector2(-10, 0), Color(1.0, 0.95, 0.8, 0.25), 3.0)
	draw_line(Vector2(-13, 0), Vector2(5, 0), Color(0.45, 0.3, 0.15), 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(11, 0), Vector2(4, -4), Vector2(4, 4)]), Color(0.75, 0.78, 0.85))
	draw_line(Vector2(-13, 0), Vector2(-17, -4), Color(0.25, 0.2, 0.15), 2.0)
	draw_line(Vector2(-13, 0), Vector2(-17, 4), Color(0.25, 0.2, 0.15), 2.0)
