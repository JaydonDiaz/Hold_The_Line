extends Node2D
## Arrow, arcane orb, frost bolt, ki blast, cannon shell or alchemist's flask. Homes on its target; if the target dies first,
## it still lands where the target was (so splash still hits). Piercing arrows carry on
## through more enemies; seeking ones find a new target instead of landing on nothing.

const Zone = preload("res://scripts/zone.gd")
const PIERCE_RANGE := 220.0   # how far a piercing arrow flies on after a hit
const SEEK_RANGE := 160.0     # how far a seeking arrow looks for its next target

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
var source := 0      # instance id of the unit that fired it (flask poison and mage rot are tracked by it)
var cloud := {}      # flasks: radius, duration of the toxic cloud left behind
var corrode := {}    # flasks: amount, duration
var melt := 0.0      # flasks: share of the direct target's max HP burned away
var burst := 0.0     # flasks: enemies killed explode for this multiple of the damage
var crit := false   # critical hit: glows gold and pops a "Crit!" on impact
var style := "arrow"
var color := Color.WHITE
# Upgrades from the fourth paths and the mage's tier-3 blasts.
var pierce := 0      # arrows: how many more enemies it goes on through
var seek := false    # arrows: finds a new target when its own falls, and after each pierce
var burn := []       # [dps, seconds]: sets what it hits burning
var magnet := {}     # mage Storm: radius, pull. Pulls charged enemies in, then charges what it hits
var echo := {}       # mage Arcane: damage share, radius. Everything hit bursts again
var decay := {}      # mage Necromancy: dps, duration
var cluster := {}    # shells: count, damage share, radius of the bomblets
var napalm := {}     # shells: dps, duration of the burning ground left behind
var befuddle := []   # bard notes: [chance, seconds] to confuse the target
var high_arc := false   # mortar shells go up high (and over walls)
var grade := 0          # an Archer's arrows: her Damage tier (0-4) sets what they look like
var confuse_vuln := 0.0
var hit_already := []   # piercing arrows don't hit the same enemy twice
var straight := false   # a piercing arrow without a target: flies on in a line
var dir := Vector2.RIGHT
var flown := 0.0


func _process(delta: float) -> void:
	if straight:
		_fly_on(delta)
		return
	if is_instance_valid(target) and not target.dead:
		target_pos = target.position
	elif seek and target != null:
		target = _next_target(target_pos)   # its target fell: curve off after another (or land where it was)
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
		if style == "fireball":
			queue_redraw()


## A piercing arrow after a hit, with nothing to seek: on in a straight line,
## striking the next enemy it passes through.
func _fly_on(delta: float) -> void:
	var step := speed * delta
	position += dir * step
	flown += step
	if flown > PIERCE_RANGE or position.y < -20.0 or position.y > main.FIELD_H or position.x < -20.0 or position.x > main.FIELD_W + 20.0:
		queue_free()
		return
	for e in main.get_enemies():
		if not hit_already.has(e) and e.position.distance_to(position) <= e.radius + 4.0:
			target = e
			_hit()
			return


## The nearest enemy to p it hasn't already hit, within reach, or null.
func _next_target(p: Vector2):
	var best = null
	var best_d := SEEK_RANGE
	for e in main.get_enemies():
		if hit_already.has(e) or e.position.y < 0.0:
			continue
		var d: float = e.position.distance_to(p)
		if d < best_d:
			best_d = d
			best = e
	return best


func _hit() -> void:
	if melt > 0.0 and is_instance_valid(target) and not target.dead:
		target.take_damage(target.max_hp * melt * target.cc_mult, false)   # bosses resist it
	var struck := []   # enemies this hit damaged (for burning, rot, confusion and arcane bursts)
	var blown := []   # where Chain Reaction kills went off
	if splash > 0.0:
		if not magnet.is_empty():
			_magnetize()
		for e in main.get_enemies():
			if style == "shell" and e.flying:
				continue   # shells burst on the ground
			if e.position.distance_to(position) <= splash + e.radius:
				var at: Vector2 = e.position
				e.take_damage(damage)
				struck.append([e, at])
				if e.dead:
					if burst > 0.0:
						blown.append(at)
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
		if style == "fireball":
			main.spawn_burst(position, splash * 0.6, Color(1.0, 0.85, 0.35))
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
			main.sfx("boom")
			_scatter()
		elif style == "flask":
			main.sfx("splash")
		elif style == "fireball":
			main.sfx("fire", 0.8)
	elif is_instance_valid(target) and not target.dead:
		var heading := Vector2.from_angle(rotation)
		var at: Vector2 = target.position
		target.take_damage(damage)
		struck.append([target, at])
		if knockback_chance > 0.0 and randf() < knockback_chance and not target.dead:
			target.apply_knockback(heading * knockback_force)
		if crit:
			main.spawn_text(position + Vector2(0, -20), "Crit!", Color(1, 0.85, 0.25))
	_after_hit(struck)
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
	if pierce > 0 and splash <= 0.0 and is_instance_valid(target):
		_pierce_on()
		return
	queue_free()


## Lingering effects on everything this hit damaged.
func _after_hit(struck: Array) -> void:
	for pair in struck:
		var e = pair[0]
		if not is_instance_valid(e) or e.dead:
			continue
		if not burn.is_empty():
			e.apply_burn(burn[0], burn[1])
		if not decay.is_empty():
			e.apply_decay(decay["dps"], decay["duration"], source)
		if not magnet.is_empty():
			e.charge(3.0)
		if not befuddle.is_empty() and randf() < befuddle[0]:
			e.apply_confuse(befuddle[1], confuse_vuln)
	if not echo.is_empty():
		# Arcane: each enemy struck bursts with arcane force, hurting everything around it.
		var r: float = echo["radius"]
		for pair in struck:
			var at: Vector2 = pair[1]
			for x in main.get_enemies():
				if x.position.distance_to(at) <= r + x.radius:
					x.take_damage(damage * echo["damage"])
			main.spawn_burst(at, r, Color(1.0, 0.55, 0.95))
	if not napalm.is_empty():
		var z := Zone.new()
		z.main = main
		z.style = "fire"
		z.radius = splash * 0.85
		z.slow = 0.0
		z.dps = napalm["dps"]
		z.life = napalm["duration"]
		z.position = position
		main.add_projectile(z)


## Storm: charged enemies near the blast are dragged in toward it, bunching them up.
func _magnetize() -> void:
	var r: float = magnet["radius"]
	var pulled := false
	for e in main.get_enemies():
		var off: Vector2 = position - e.position
		if e.charged_timer <= 0.0 or off.length() > r + e.radius or off.length() < 6.0:
			continue
		e.apply_knockback(off.normalized() * minf(magnet["pull"], off.length() - 4.0))
		main.spawn_bolt(PackedVector2Array([e.position, position]), Color(0.6, 0.85, 1.0))
		pulled = true
	if pulled:
		main.spawn_burst(position, r, Color(0.55, 0.8, 1.0))


## Cluster Shells: bomblets scatter around the blast and go off.
func _scatter() -> void:
	if cluster.is_empty():
		return
	var r: float = cluster["radius"]
	for i in int(cluster["count"]):
		var at := position + Vector2.from_angle(i * TAU / cluster["count"] + randf_range(-0.3, 0.3)) * (splash + randf_range(5.0, 25.0))
		for e in main.get_enemies():
			if not e.flying and e.position.distance_to(at) <= r + e.radius:
				e.take_damage(damage * cluster["damage"])
				if not e.dead and not burn.is_empty():
					e.apply_burn(burn[0], burn[1])
		main.spawn_burst(at, r, Color(1.0, 0.6, 0.25))


## A piercing arrow carries on: after the next enemy if it seeks, else straight on.
func _pierce_on() -> void:
	pierce -= 1
	hit_already.append(target)
	dir = Vector2.from_angle(rotation)
	flown = 0.0
	if seek:
		var nxt = _next_target(position)
		if nxt != null:
			target = nxt
			target_pos = nxt.position
			return
	straight = true
	target = null


# An Archer's arrows by her Damage tier: plain, barbed, heavy, piercing, dragonbone.
const ARROW_SHAFTS := [Color(0.92, 0.88, 0.78), Color(0.88, 0.8, 0.65), Color(0.5, 0.33, 0.18), Color(0.38, 0.38, 0.44), Color(0.96, 0.94, 0.86)]
const ARROW_HEADS := [Color(0.78, 0.8, 0.86), Color(0.6, 0.62, 0.68), Color(0.55, 0.57, 0.62), Color(0.88, 0.93, 1.0), Color(1.0, 0.45, 0.15)]
const ARROW_FLETCH := [Color(0.92, 0.9, 0.85), Color(0.85, 0.25, 0.2), Color(0.2, 0.15, 0.15), Color(0.45, 0.6, 0.85), Color(1.0, 0.8, 0.3)]


## An arrow pointing along +x, centered on the origin (projectiles, and the one an
## Archer twirls while idle). outline gives it a dark edge to stand out on a sprite.
static func arrow_shape(ci: CanvasItem, g: int, alpha: float, outline: bool) -> void:
	g = clampi(g, 0, 4)
	var shaft := Color(ARROW_SHAFTS[g], alpha)
	var head := Color(ARROW_HEADS[g], alpha)
	var fletch := Color(ARROW_FLETCH[g], alpha)
	var ink := Color(0.1, 0.07, 0.1, alpha)
	var thick := 3.0 if g == 2 else 2.0
	var tip := 12.0
	var tri := PackedVector2Array([Vector2(12, 0), Vector2(6, -3), Vector2(6, 3)])
	match g:
		2:
			tip = 13.0
			tri = PackedVector2Array([Vector2(13, 0), Vector2(5, -4), Vector2(5, 4)])
		3:
			tip = 16.0
			tri = PackedVector2Array([Vector2(16, 0), Vector2(6, -2), Vector2(6, 2)])
		4:
			tip = 14.0
			tri = PackedVector2Array([Vector2(14, 0), Vector2(6, -3.5), Vector2(6, 3.5)])
	if outline:
		ci.draw_line(Vector2(-11, 0), Vector2(tip - 1.0, 0), ink, thick + 2.0, true)
	ci.draw_line(Vector2(-10, 0), Vector2(8, 0), shaft, thick, true)
	ci.draw_line(Vector2(-10, 0), Vector2(-6, 0), fletch, thick + 2.0, true)
	if g == 4:
		ci.draw_circle(Vector2(tip - 3.0, 0), 5.0, Color(1.0, 0.5, 0.15, 0.35 * alpha), true, -1.0, true)
	ci.draw_colored_polygon(tri, head)
	if g == 1:
		# Barbs swept back off the head.
		ci.draw_line(Vector2(6, -3), Vector2(3, -5), head, 1.5, true)
		ci.draw_line(Vector2(6, 3), Vector2(3, 5), head, 1.5, true)


func _draw() -> void:
	if crit:
		draw_circle(Vector2.ZERO, 7, Color(1, 0.85, 0.25, 0.45), true, -1.0, true)
	match style:
		"arrow":
			arrow_shape(self, grade, 1.0, false)
			if not burn.is_empty():
				draw_circle(Vector2(11, 0), 3.5, Color(1.0, 0.55, 0.15, 0.85), true, -1.0, true)
			if seek:
				draw_line(Vector2(-10, 0), Vector2(-16, 0), Color(0.6, 0.9, 1.0, 0.6), 3.0, true)
		"crossbow":
			draw_line(Vector2(-6, 0), Vector2(6, 0), Color(0.35, 0.25, 0.15), 3.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(10, 0), Vector2(5, -3), Vector2(5, 3)]), ARROW_HEADS[grade])
			if grade >= 4:
				draw_circle(Vector2(9, 0), 4.0, Color(1.0, 0.5, 0.15, 0.4), true, -1.0, true)
		"ki":
			var r := 9.0 if splash <= 0.0 else 12.0
			draw_circle(Vector2.ZERO, r, Color(color, 0.35), true, -1.0, true)
			draw_circle(Vector2.ZERO, r * 0.6, color, true, -1.0, true)
			draw_circle(Vector2.ZERO, 3, Color.WHITE, true, -1.0, true)
		"orb":
			draw_circle(Vector2.ZERO, 8, Color(color, 0.35), true, -1.0, true)
			draw_circle(Vector2.ZERO, 4.5, color.lightened(0.4), true, -1.0, true)
		"fireball":
			# A roaring fireball with a flickering tail streaming behind it.
			var flick := Time.get_ticks_msec() / 60
			for i in 4:
				var k := float(i) / 4.0
				var off := Vector2(-6.0 - i * 5.0, sin(flick + i * 2.0) * 2.0)
				draw_circle(off, 6.0 - i * 1.2, Color(1.0, 0.45 - k * 0.2, 0.1, 0.7 - k * 0.15), true, -1.0, true)
			draw_circle(Vector2.ZERO, 10, Color(1.0, 0.45, 0.1, 0.4), true, -1.0, true)
			draw_circle(Vector2.ZERO, 6.5, Color(1.0, 0.7, 0.2), true, -1.0, true)
			draw_circle(Vector2(1, -1), 3.5, Color(1.0, 0.95, 0.6), true, -1.0, true)
		"shell":
			# An iron ball lobbed in an arc, its shadow on the ground below.
			var t := traveled / maxf(traveled + left, 1.0)
			var h := sin(PI * t) * minf(traveled + left, 260.0) * (0.6 if high_arc else 0.25)
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.5))
			draw_circle(Vector2.ZERO, 5, Color(0, 0, 0, 0.3), true, -1.0, true)
			draw_set_transform(Vector2.ZERO)
			draw_circle(Vector2(0, -h), 5.5, Color(0.1, 0.08, 0.1), true, -1.0, true)
			draw_circle(Vector2(0, -h), 4.5, Color(0.3, 0.3, 0.34) if burn.is_empty() else Color(0.75, 0.3, 0.1), true, -1.0, true)
			draw_circle(Vector2(-1.5, -h - 1.5), 1.5, Color(0.6, 0.6, 0.65) if burn.is_empty() else Color(1.0, 0.8, 0.3), true, -1.0, true)
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
