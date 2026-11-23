extends Node2D
## A Ballista's bolt: a heavy iron-headed shaft that flies straight on to the end of its
## reach, through every enemy in its line (each hit once), hard on anything that flies.
## The Ballista's upgrades ride on it: knockback, the first enemy pinned, a net that drags
## flyers down slow, bleeding and rending tips, and a burst where it stops.

var main
var dir := Vector2.RIGHT
var dist_left := 300.0
var speed := 950.0
var damage := 30.0
var air_mult := 2.0
var credit := ""
var knockback_chance := 0.0
var knockback_force := 0.0
var impale := 0.0
var net := []
var air_crit := []
var burn := []
var corrode := {}
var blast_end := {}
var hit_ids := {}
var pinned := false


func _process(delta: float) -> void:
	if main.campaign:
		main.credit = credit
	var step := minf(speed * delta, dist_left)
	var a := position
	var b := position + dir * step
	for e in main.enemies_near((a + b) / 2.0, step / 2.0 + 44.0):
		if e.dead or hit_ids.has(e.get_instance_id()):
			continue
		if Geometry2D.get_closest_point_to_segment(e.position, a, b).distance_to(e.position) <= e.radius + 6.0:
			main.hit_from = position - Vector2.from_angle(rotation) * 80.0
			_hit(e)
			main.hit_from = Vector2.INF
	position = b
	rotation = dir.angle()
	dist_left -= step
	if main.paths.tall_at(position):
		dist_left = 0.0   # into a castle's wall: it stops (and bursts) there
	if dist_left <= 0.0:
		_burst()
		queue_free()
		return
	queue_redraw()


func _hit(e) -> void:
	hit_ids[e.get_instance_id()] = true
	var d := damage
	if e.flying:
		d *= air_mult
		if not air_crit.is_empty() and randf() < float(air_crit[0]):
			d *= float(air_crit[1])
			main.spawn_text(e.position + Vector2(0, -30), "Brought down!", Color(1, 0.85, 0.4))
		if not net.is_empty():
			e.apply_slow(float(net[0]), float(net[1]))
	e.take_damage(d)
	if not burn.is_empty():
		e.apply_burn(float(burn[0]), float(burn[1]))
	if not corrode.is_empty():
		e.apply_corrode(float(corrode["amount"]), float(corrode["duration"]))
	if knockback_chance > 0.0 and randf() < knockback_chance:
		e.apply_knockback(dir * knockback_force)
	if impale > 0.0 and not pinned:
		pinned = true
		e.apply_stun(impale)
	main.spawn_burst(e.position + Vector2(0, -8), 10.0, Color(0.85, 0.75, 0.55))
	main.sfx("hit", 0.7)


## Where it stops: a Blasting Tip bursts.
func _burst() -> void:
	if blast_end.is_empty():
		return
	var r := float(blast_end["radius"])
	for e in main.enemies_near(position, r + 30.0):
		if not e.dead and e.position.distance_to(position) <= r + e.radius:
			e.take_damage(damage * float(blast_end["share"]), true, "explosive")
			if float(blast_end["stun"]) > 0.0:
				e.apply_stun(float(blast_end["stun"]))
	main.spawn_flash(position, r * 0.7)
	main.spawn_burst(position, r, Color(1.0, 0.6, 0.25))
	main.sfx("boom", 1.1)


func _draw() -> void:
	# A long dark shaft, an iron head, three vanes of fletching.
	draw_line(Vector2(-26, 0), Vector2(4, 0), Color(0.1, 0.07, 0.1), 4.0)
	draw_line(Vector2(-25, 0), Vector2(3, 0), Color(0.55, 0.38, 0.2), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(11, 0), Vector2(3, -4), Vector2(3, 4)]), Color(0.36, 0.36, 0.4))
	draw_line(Vector2(-25, 0), Vector2(-30, -4), Color(0.85, 0.82, 0.75), 2.0)
	draw_line(Vector2(-25, 0), Vector2(-30, 4), Color(0.85, 0.82, 0.75), 2.0)
