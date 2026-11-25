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
		for w in main.battlefield.warriors_near(position, 24.0):
			if w.is_active() and not w.sheltered() and not hit.has(w) and w.position.distance_to(position) <= w.RADIUS + 8.0:
				hit[w] = true
				w.take_damage(damage)
				main.effects.spawn_burst(w.position, 12.0, Color(1.0, 0.5, 0.15))
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
			for w in main.battlefield.get_warriors():
				if not w.is_active() or w.sheltered():
					continue
				var c := Geometry2D.get_closest_point_to_segment(w.position, from, to)
				if c.distance_to(w.position) <= WIDTH + w.RADIUS * 0.5:
					w.take_damage(damage)
					w.shove(from.direction_to(to) * 30.0, stun)
			main.effects.spawn_beam(from, to, Color(0.75, 0.75, 0.8), 10.0)
			main.effects.sfx("lance", 0.8)
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
			for w in main.battlefield.warriors_near(position, radius + 20.0):
				if w.is_active() and not w.sheltered() and w.position.distance_to(position) <= radius + w.RADIUS * 0.5:
					w.take_damage(damage)
					w.shove(Vector2.ZERO, freeze)
					main.effects.spawn_text(w.position + Vector2(0, -30), "Frozen!", Color(0.6, 0.9, 1.0))
			main.effects.spawn_burst(position, radius, Color(0.65, 0.9, 1.0))
			main.effects.sfx("freeze", 0.8)
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := t / WARN
		draw_set_transform(Vector2.ZERO, 0, Vector2(1.0, 0.6))
		draw_circle(Vector2.ZERO, radius, Color(0.6, 0.85, 1.0, 0.12))
		draw_circle(Vector2.ZERO, radius * k, Color(0.75, 0.92, 1.0, 0.3))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.7, 0.95, 1.0, 0.95), 2.5, true)


## The beacon's fire, when he's worn to a field's mark. First a warning (WARN seconds: he
## draws on the beacon, a line of fire glowing where it'll start, time for the army to fall
## back); then bursts of flame, each marked on the ground before it catches, landing across
## the field and creeping down it (a front moving at `speed`), every one burning on where it
## landed, until the field's alight from end to end (`swept`: the battle goes on below).
class BeaconWrath extends Node2D:
	const WARN := 6.0
	const EVERY := 0.3        # a burst every this many seconds
	const COLUMNS := 7        # the field's width in strips, the bursts going round them
	var main
	var front := 0.0         # how far down the field the bursts have reached (y)
	var speed := 26.0        # how fast that front creeps down (slower than any troop walks)
	var dps := 40.0
	var bottom := 700.0      # where the front stops: the field's been swept
	var swept := false
	var t := 0.0
	var spawn_t := 0.0
	var col := 0
	var left := 0.0          # once the front's at the bottom: the last bursts catching

	func _ready() -> void:
		add_to_group("danger")

	func warning() -> bool:
		return t < WARN

	## Ground well behind the bursts, burning end to end: troops caught back there get out.
	func danger_zone() -> Dictionary:
		return {} if t < WARN or swept else {"above": front - 70.0}

	func _process(delta: float) -> void:
		if main.game_over or swept:
			return
		var was := t
		t += delta
		queue_redraw()
		if t < WARN:
			return
		if was < WARN:
			main.hud.show_message("The beacon's fire bursts across the field! Fall back ahead of it!")
			main.effects.sfx("boom", 0.6)
		if front < bottom:
			front = minf(front + speed * delta, bottom)
			spawn_t -= delta
			while spawn_t <= 0.0:
				spawn_t += EVERY
				_burst()
		else:
			left += delta
			if left >= WrathFire.WARN + 0.4:
				swept = true

	## A burst: in the next strip across the field, a little behind the front.
	func _burst() -> void:
		col = (col + 3) % COLUMNS   # (round the strips out of order, so it spreads unevenly)
		var w: float = main.FIELD_W
		var f := WrathFire.new()
		f.main = main
		f.radius = randf_range(46.0, 64.0)
		f.dps = dps
		f.position = Vector2((col + randf_range(0.15, 0.85)) * w / COLUMNS, front - randf_range(0.0, 60.0))
		main.corpse_layer.add_child(f)

	func _draw() -> void:
		var w: float = main.FIELD_W
		if t < WARN:
			# The warning: a line of fire glowing across the field where it'll start, brighter
			# as it comes, and the field behind it reddening.
			var k := t / WARN
			var pulse := 0.5 + 0.5 * sin(t * (4.0 + 8.0 * k))
			draw_rect(Rect2(0, -200, w, front + 200), Color(1.0, 0.25, 0.05, 0.08 + 0.1 * k))
			draw_rect(Rect2(0, front - 3, w, 6), Color(1.0, 0.45, 0.1, 0.35 + 0.5 * pulse * k))
			return
		# Behind the bursts: the field alight, a red haze over it.
		draw_rect(Rect2(0, -200, w, maxf(front - 60.0, 0.0) + 200), Color(0.9, 0.25, 0.05, 0.12))


## One of the beacon's bursts: its ring on the ground first, then it catches and burns on
## (whoever stands in it burns, troops only) until the battle leaves this field.
class WrathFire extends Node2D:
	const WARN := 1.6
	var main
	var radius := 55.0
	var dps := 40.0
	var t := 0.0
	var tick := 0.0

	func _ready() -> void:
		add_to_group("danger")

	func danger_zone() -> Dictionary:
		return {"c": position, "r": radius}

	func _process(delta: float) -> void:
		if main.game_over:
			return
		var was := t
		t += delta
		if t >= WARN:
			if was < WARN:
				main.effects.spawn_burst(position, radius, Color(1.0, 0.45, 0.12))
				if randf() < 0.3:
					main.effects.sfx("boom", randf_range(0.8, 1.0))
			tick -= delta
			if tick <= 0.0:
				tick = 0.25
				for w in main.battlefield.warriors_near(position, radius + 20.0):
					if w.is_active() and not w.is_emplacement() and w.position.distance_to(position) <= radius + w.RADIUS * 0.5:
						w.take_damage(dps * 0.25)
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0, Vector2(1.0, 0.6))
		if t < WARN:
			var k := t / WARN
			draw_circle(Vector2.ZERO, radius, Color(1.0, 0.3, 0.08, 0.12))
			draw_circle(Vector2.ZERO, radius * k, Color(1.0, 0.45, 0.12, 0.28))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(1.0, 0.4, 0.12, 0.95), 2.5, true)
			return
		var flick := 0.85 + 0.15 * sin(t * 9.0 + position.x)
		draw_circle(Vector2.ZERO, radius, Color(0.9, 0.25, 0.05, 0.35 * flick))
		draw_circle(Vector2.ZERO, radius * 0.7, Color(1.0, 0.5, 0.12, 0.35 * flick))
		draw_set_transform(Vector2.ZERO)
		var n := int(radius / 9.0)
		for i in n:
			var a := i * TAU / n + position.x
			var p := Vector2(cos(a), sin(a) * 0.6) * radius * (0.35 + 0.5 * fmod(i * 0.37, 1.0))
			var h := 8.0 + 5.0 * sin(t * 10.0 + i * 1.3)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 0), p + Vector2(0, -h - 6), p + Vector2(5, 0)]), Color(1.0, 0.55, 0.12, 0.85))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-2.5, 0), p + Vector2(0, -h * 0.55), p + Vector2(2.5, 0)]), Color(1.0, 0.9, 0.4, 0.9))
