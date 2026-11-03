extends Node2D
## Arrow, arcane orb, frost bolt, ki blast, cannon shell or alchemist's flask. Homes on its target; if the target dies first,
## it still lands where the target was (so splash still hits).

const Zone = preload("res://scripts/zone.gd")

var main
var target
var target_pos := Vector2.ZERO
var speed := 500.0
var damage := 0.0
var splash := 0.0
var slow := 0.0
var slow_time := 0.0
var slow_radius := 0.0
var freeze_chance := 0.0
var freeze_time := 0.0
var knockback_chance := 0.0
var knockback_force := 0.0
var stun_time := 0.0  # shells: stuns everything caught in the blast
var traveled := 0.0   # shells arc up and back down over the flight
var left := 0.0
var poison := {}     # flasks: dps, duration, stacks
var source := 0      # flasks: instance id of the Alchemist that threw it (its poison doesn't stack with others')
var cloud := {}      # flasks: radius, duration of the toxic cloud left behind
var corrode := {}    # flasks: amount, duration
var melt := 0.0      # flasks: share of the direct target's max HP burned away
var burst := 0.0     # flasks: enemies killed explode for this multiple of the damage
var crit := false   # critical hit: glows gold and pops a "Crit!" on impact
var style := "arrow"
var color := Color.WHITE


func _process(delta: float) -> void:
	if is_instance_valid(target) and not target.dead:
		target_pos = target.position
	var to := target_pos - position
	var step := speed * delta
	if to.length() <= step:
		position = target_pos
		_hit()
		return
	position += to.normalized() * step
	traveled += step
	left = to.length() - step
	if style == "shell" or style == "note" or style == "flask":
		queue_redraw()
	else:
		rotation = to.angle()


func _hit() -> void:
	if melt > 0.0 and is_instance_valid(target) and not target.dead:
		target.take_damage(target.max_hp * melt * target.cc_mult, false)   # bosses resist it
	var blown := []   # where Chain Reaction kills went off
	if splash > 0.0:
		for e in main.get_enemies():
			if style == "shell" and e.flying:
				continue   # shells burst on the ground
			if e.position.distance_to(position) <= splash + e.radius:
				e.take_damage(damage)
				if e.dead:
					if burst > 0.0:
						blown.append(e.position)
					continue
				if not poison.is_empty():
					e.apply_poison(poison["dps"], poison["duration"], poison["stacks"], source)
				if not corrode.is_empty():
					e.apply_corrode(corrode["amount"], corrode["duration"])
				if knockback_chance > 0.0 and randf() < knockback_chance:
					var away: Vector2 = (e.position - position).normalized() if e.position != position else Vector2.UP
					e.apply_knockback(away * knockback_force)
				if stun_time > 0.0:
					e.apply_stun(stun_time)
		main.spawn_burst(position, splash, color)
		for at in blown:
			for e in main.get_enemies():
				if e.position.distance_to(at) <= 40.0 + e.radius:
					e.take_damage(damage * burst)
			main.spawn_burst(at, 40.0, Color(1.0, 0.6, 0.2))
			main.spawn_burst(at, 22.0, Color(1.0, 0.95, 0.6))
		if not cloud.is_empty():
			var z := Zone.new()
			z.main = main
			z.style = "toxic"
			z.radius = cloud["radius"]
			z.slow = 0.0
			z.poison = poison
			z.source = source
			z.life = cloud["duration"]
			z.position = position
			main.add_projectile(z)
		if style == "shell":
			main.spawn_burst(position, splash * 0.5, Color(1.0, 0.95, 0.7))
	elif is_instance_valid(target) and not target.dead:
		var dir := Vector2.from_angle(rotation)
		target.take_damage(damage)
		if knockback_chance > 0.0 and randf() < knockback_chance and not target.dead:
			target.apply_knockback(dir * knockback_force)
		if crit:
			main.spawn_text(position + Vector2(0, -20), "Crit!", Color(1, 0.85, 0.25))
	if slow > 0.0:
		var victims: Array = []
		if slow_radius > 0.0:
			victims = main.get_enemies().filter(func(e): return e.position.distance_to(position) <= slow_radius + e.radius)
			main.spawn_burst(position, slow_radius, color)
		elif is_instance_valid(target) and not target.dead:
			victims = [target]
		for e in victims:
			e.apply_slow(slow, slow_time)
			if randf() < freeze_chance:
				e.apply_freeze(freeze_time)
	queue_free()


func _draw() -> void:
	if crit:
		draw_circle(Vector2.ZERO, 7, Color(1, 0.85, 0.25, 0.45), true, -1.0, true)
	match style:
		"arrow":
			draw_line(Vector2(-10, 0), Vector2(8, 0), Color(0.95, 0.9, 0.75), 2.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(6, -3), Vector2(6, 3)]), Color(0.8, 0.8, 0.85))
		"barbed":
			draw_line(Vector2(-10, 0), Vector2(8, 0), Color(0.95, 0.9, 0.75), 2.0, true)
			draw_line(Vector2(-10, 0), Vector2(-13, -3), Color(0.85, 0.25, 0.2), 2.0, true)
			draw_line(Vector2(-10, 0), Vector2(-13, 3), Color(0.85, 0.25, 0.2), 2.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(13, 0), Vector2(6, -3), Vector2(6, 3)]), Color(0.8, 0.8, 0.85))
			draw_line(Vector2(6, -3), Vector2(3, -5), Color(0.8, 0.8, 0.85), 1.5, true)
			draw_line(Vector2(6, 3), Vector2(3, 5), Color(0.8, 0.8, 0.85), 1.5, true)
		"crossbow":
			draw_line(Vector2(-6, 0), Vector2(6, 0), Color(0.35, 0.25, 0.15), 3.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(10, 0), Vector2(5, -3), Vector2(5, 3)]), Color(0.7, 0.72, 0.78))
		"ki":
			draw_circle(Vector2.ZERO, 9, Color(color, 0.35), true, -1.0, true)
			draw_circle(Vector2.ZERO, 5.5, color, true, -1.0, true)
			draw_circle(Vector2.ZERO, 3, Color.WHITE, true, -1.0, true)
		"orb":
			draw_circle(Vector2.ZERO, 8, Color(color, 0.35), true, -1.0, true)
			draw_circle(Vector2.ZERO, 4.5, color.lightened(0.4), true, -1.0, true)
		"shell":
			# An iron ball lobbed in an arc, its shadow on the ground below.
			var t := traveled / maxf(traveled + left, 1.0)
			var h := sin(PI * t) * minf(traveled + left, 260.0) * 0.25
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.5))
			draw_circle(Vector2.ZERO, 5, Color(0, 0, 0, 0.3), true, -1.0, true)
			draw_set_transform(Vector2.ZERO)
			draw_circle(Vector2(0, -h), 5.5, Color(0.1, 0.08, 0.1), true, -1.0, true)
			draw_circle(Vector2(0, -h), 4.5, Color(0.3, 0.3, 0.34), true, -1.0, true)
			draw_circle(Vector2(-1.5, -h - 1.5), 1.5, Color(0.6, 0.6, 0.65), true, -1.0, true)
		"flask":
			# A round glass flask tumbling through the air, its shadow on the ground below.
			var t := traveled / maxf(traveled + left, 1.0)
			var h := sin(PI * t) * minf(traveled + left, 220.0) * 0.3
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.5))
			draw_circle(Vector2.ZERO, 4, Color(0, 0, 0, 0.3), true, -1.0, true)
			draw_set_transform(Vector2(0, -h), traveled * 0.05, Vector2.ONE)
			draw_circle(Vector2(0, 1), 5.5, Color(0.1, 0.07, 0.1), true, -1.0, true)
			draw_rect(Rect2(-2.5, -7, 5, 5), Color(0.1, 0.07, 0.1))
			draw_circle(Vector2(0, 1), 4.0, color, true, -1.0, true)
			draw_rect(Rect2(-1.5, -6, 3, 4), Color(0.85, 0.95, 0.95))
			draw_circle(Vector2(-1.5, -0.5), 1.2, Color(1, 1, 1, 0.8), true, -1.0, true)
			draw_set_transform(Vector2.ZERO)
		"note":
			# A Bard's note: an eighth note with a soft glow, always upright.
			draw_circle(Vector2.ZERO, 7, Color(color, 0.3), true, -1.0, true)
			draw_circle(Vector2(-1, 2), 3.5, color.lightened(0.3), true, -1.0, true)
			draw_line(Vector2(2, 2), Vector2(2, -8), color.lightened(0.3), 2.0, true)
			draw_line(Vector2(2, -8), Vector2(6, -5), color.lightened(0.3), 2.0, true)
		"frost":
			draw_circle(Vector2.ZERO, 6, Color(color, 0.4), true, -1.0, true)
			draw_circle(Vector2.ZERO, 3, Color.WHITE, true, -1.0, true)
