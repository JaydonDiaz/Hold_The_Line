extends RefCounted
## The Ogre King, Unbound's arts in the true final battle (rules_finale.gd): drawn from the
## broken oaths of the Line's own peoples, so each is one of their arts turned on the army.
## The pieces that need nodes of their own are here; the rules decide when he uses which.
##
##   OathArrow   Greenwood's: a fire arrow that follows its troop and burns through every
##               troop it passes on the way
##   OathLance   Stonehollow's: a ballista bolt's line shown on the ground first, then a bolt
##               down it through everything in the line (hit and pinned)
##   WinterRing  Frostmarch's: a ring of frost on the ground first; whoever's still in it is
##               frozen solid
##   BeaconWrath the beacon's fire, when he's worn to a field's mark: a wall of flame rolling
##               down the field from him; it burns whoever it catches, and the army has to
##               fall back before it (the rules move the battle on once it's swept the field)


## Greenwood's arrow, burning: follows its troop; burns every troop it passes through.
class OathArrow extends Node2D:
	var main
	var target = null
	var target_pos := Vector2.ZERO
	var speed := 300.0
	var damage := 40.0
	var hit := {}

	func _process(delta: float) -> void:
		if main.game_over:
			queue_free()
			return
		if target != null and is_instance_valid(target) and target.is_active():
			target_pos = target.position + Vector2(0, -8)
		var to := target_pos - position
		var step := speed * delta
		var arrived := to.length() <= step
		position = target_pos if arrived else position + to.normalized() * step
		rotation = to.angle()
		for w in main.warriors_near(position, 24.0):
			if w.is_active() and not w.sheltered() and not hit.has(w) and w.position.distance_to(position) <= w.RADIUS + 8.0:
				hit[w] = true
				w.take_damage(damage)
				main.spawn_burst(w.position, 12.0, Color(1.0, 0.5, 0.15))
		if arrived:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		draw_line(Vector2(-14, 0), Vector2(4, 0), Color(0.35, 0.2, 0.1), 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(9, 0), Vector2(3, -3.5), Vector2(3, 3.5)]), Color(1.0, 0.55, 0.15))
		var t := Time.get_ticks_msec() / 60.0
		for i in 3:
			draw_circle(Vector2(-14 - i * 5, sin(t + i) * 2.0), 3.0 - i * 0.7, Color(1.0, 0.45 + i * 0.15, 0.1, 0.7 - i * 0.2))


## Stonehollow's bolt: its line on the ground first, then it flies down it.
class OathLance extends Node2D:
	const WARN := 1.3
	const WIDTH := 16.0
	var main
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var damage := 80.0
	var stun := 0.8
	var t := 0.0

	func _ready() -> void:
		add_to_group("danger")

	func danger_zone() -> Dictionary:
		return {"a": from, "b": to, "r": WIDTH}

	func _process(delta: float) -> void:
		if main.game_over:
			queue_free()
			return
		t += delta
		if t >= WARN:
			for w in main.get_warriors():
				if not w.is_active() or w.sheltered():
					continue
				var c := Geometry2D.get_closest_point_to_segment(w.position, from, to)
				if c.distance_to(w.position) <= WIDTH + w.RADIUS * 0.5:
					w.take_damage(damage)
					w.shove(from.direction_to(to) * 30.0, stun)
			main.spawn_beam(from, to, Color(0.75, 0.75, 0.8), 10.0)
			main.sfx("lance", 0.8)
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := t / WARN
		var a := from - position
		var b := to - position
		draw_line(a, b, Color(0.8, 0.8, 0.85, 0.15 + 0.2 * k), WIDTH * 2.0)
		draw_line(a, a + (b - a) * k, Color(1.0, 0.85, 0.5, 0.5), 3.0)
		draw_line(a, b, Color(1.0, 0.6, 0.3, 0.9), 1.5)


## Frostmarch's winter: a ring on the ground first; whoever's still in it is frozen.
class WinterRing extends Node2D:
	const WARN := 1.6
	var main
	var radius := 80.0
	var damage := 30.0
	var freeze := 2.5
	var t := 0.0

	func _ready() -> void:
		add_to_group("danger")

	func danger_zone() -> Dictionary:
		return {"c": position, "r": radius}

	func _process(delta: float) -> void:
		if main.game_over:
			queue_free()
			return
		t += delta
		if t >= WARN:
			for w in main.warriors_near(position, radius + 20.0):
				if w.is_active() and not w.sheltered() and w.position.distance_to(position) <= radius + w.RADIUS * 0.5:
					w.take_damage(damage)
					w.shove(Vector2.ZERO, freeze)
					main.spawn_text(w.position + Vector2(0, -30), "Frozen!", Color(0.6, 0.9, 1.0))
			main.spawn_burst(position, radius, Color(0.65, 0.9, 1.0))
			main.sfx("freeze", 0.8)
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := t / WARN
		draw_set_transform(Vector2.ZERO, 0, Vector2(1.0, 0.6))
		draw_circle(Vector2.ZERO, radius, Color(0.6, 0.85, 1.0, 0.12))
		draw_circle(Vector2.ZERO, radius * k, Color(0.75, 0.92, 1.0, 0.3))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.7, 0.95, 1.0, 0.95), 2.5, true)


## The beacon's fire, rolling down the field from him: everything above its front burns;
## the army falls back before it. Done once it's swept down to the bottom (`swept`).
class BeaconWrath extends Node2D:
	var main
	var front := 0.0         # its leading edge (y)
	var speed := 70.0        # how fast it comes down the field
	var dps := 45.0
	var bottom := 700.0      # where it stops: the field's been swept
	var swept := false
	var tick := 0.0

	func _ready() -> void:
		add_to_group("danger")

	## Everything above the front, and a little below it (troops get well ahead of it).
	func danger_zone() -> Dictionary:
		return {} if swept else {"above": front + 30.0}

	func _process(delta: float) -> void:
		if main.game_over or swept:
			return
		front = minf(front + speed * delta, bottom)
		if front >= bottom:
			swept = true
		tick -= delta
		if tick <= 0.0:
			tick = 0.25
			for w in main.get_warriors():
				if w.is_active() and not w.is_emplacement() and w.position.y < front:
					w.take_damage(dps * 0.25)
		queue_redraw()

	func _draw() -> void:
		var w: float = main.FIELD_W
		var t := Time.get_ticks_msec() / 1000.0
		draw_rect(Rect2(0, -200, w, front + 200 - 24), Color(0.9, 0.25, 0.05, 0.22))
		draw_rect(Rect2(0, front - 24, w, 24), Color(1.0, 0.45, 0.1, 0.35))
		var n := int(w / 18.0) + 1
		for i in n:
			var x := i * 18.0
			var h := 14.0 + 8.0 * sin(t * 9.0 + i * 1.7)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 9, front), Vector2(x, front - h - 10), Vector2(x + 9, front)]), Color(1.0, 0.55, 0.12, 0.85))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 5, front), Vector2(x, front - h * 0.6), Vector2(x + 5, front)]), Color(1.0, 0.9, 0.4, 0.9))
