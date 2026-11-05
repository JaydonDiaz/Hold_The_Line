extends Node2D
## An enemy marching from the top of the screen to the bottom. Fighters stop to
## attack any warrior in their way; non-fighters (wolves) slip around them.
## Barricades are walked around when there's a way past (see pathing.gd); when
## there isn't, everyone hacks at the wall in the way, wolves included.
## Flyers (bats) pass over walls and warriors alike. Fighters turn on a unit that's
## attacking them (one in range of them and not far off, with no wall between) before
## carrying on to the castle. Sappers ignore your troops: they make for the castle,
## and blow themselves up against a wall only if it blocks their way there.

signal died(enemy)
signal reached_castle(enemy)

const Sprites = preload("res://scripts/sprites.gd")
const REACH := 6.0
const FLY_HEIGHT := 18.0   # how far above its shadow a flyer is drawn
const FUSE := 0.6          # seconds a Sapper's bomb fizzes before it goes off
const ENRAGE_SPEED := 1.35
const ENRAGE_RATE := 0.7
const AGGRO_LEASH := 260.0   # furthest a fighter turns aside to go after a unit attacking it

var kind := ""
var tier := 1      # enemy type rank (data.gd); higher is more dangerous
var main
var max_hp := 1.0
var hp := 1.0
var speed := 50.0
var damage := 0.0
var wall_damage := 0.0
var attack_cd := 1.0
var fights := true
var flying := false         # over walls and warriors; melee and cannon shells can't reach it
var bomb := {}              # Sapper: wall, units, radius of its blast (damage already scaled)
var fuse := -1.0            # >= 0 while the Sapper's bomb is lit
var level := 1              # wave level it was spawned at (for anything it summons)
var cc_mult := 1.0          # share of stuns, freezes, roots and confusion that lands
var knock_mult := 1.0       # share of knockback that lands
var boss := false
var stomp := {}             # Ogre King: damage (scaled), radius, cooldown, push, stun
var cleave := {}            # Ogre King: reach, arc of its sweeping blows
var summon := {}            # Ogre King: kinds, count, cooldown
var horn := {}              # Ogre King: kinds, count, cooldown of the war horn's new wave
var breath := {}            # Wyvern: damage (scaled), radius, range, cooldown
var breath_timer := 1.0
var horn_timer := 15.0
var enrage_at := 0.0
var enraged := false
var stomp_timer := 3.0
var summon_timer := 5.0
var bounty := 5
var radius := 12.0
var sprite_scale := 2.5
var flip := 1.0
var color := Color.WHITE
var progress := 0.0   # how far down the screen; warriors use it to judge threat
var dead := false
var cd_timer := 0.0
var slow_factor := 1.0
var slow_timer := 0.0
var freeze_timer := 0.0
var stun_timer := 0.0      # blinded by a flash: can't move or attack
var knock_timer := 0.0
var knock_velocity := Vector2.ZERO
var burn_dps := 0.0
# Bard effects.
var vuln := 0.0             # Discord: takes this much extra damage
var weaken := 0.0           # Discord: deals this much less damage
var discord_slow := 0.0     # Discord: extra slow
var discord_timer := 0.0
var root_timer := 0.0       # Vine Snare: can't move, can still fight
var confuse_timer := 0.0    # Confusion: attacks other enemies instead of marching
var confuse_vuln := 0.0     # Puppet Master: takes this much extra damage while confused
var decay_dps := 0.0        # Necromancy rot
var decay_timer := 0.0
var decay_source := 0       # instance id of the Mage whose rot it is (raises a skeleton if this dies rotting)
var thorn_dps := 0.0        # Thornwild: caught in thorny plants or vines
var thorn_timer := 0.0
var charged_timer := 0.0    # struck by lightning: a Storm mage's blasts pull it in
var burn_timer := 0.0
# Alchemist effects.
var poisons := {}           # alchemist id -> [dps per stack, stacks, seconds left]; only the worst one hurts
var poison_stacks := 0      # stacks of the worst poison (for the bubbles)
var corrode := 0.0          # takes this much extra damage
var corrode_timer := 0.0
# Barricades.
var wall_target = null      # the barricade this enemy has set about breaking
var stuck_check := Vector2.ZERO
var stuck_time := 0.0       # how long it has been pressed against a wall
var wall_commit := 0.0      # seconds left hacking at a wall it got stuck on before trying again
var flash := 0.0
var lunge := 0.0
var lunge_dir := Vector2.DOWN
var bob := 0.0
var sieging := false        # reached the castle and attacking it
var walking := false        # moved this frame (for the waddle)
var fighting := false       # swinging at a warrior or wall (for the wind-up)
var drift := 0.0
var aggro = null            # the unit attacking it that it has turned on
var aggro_check := randf() * 0.3   # staggered, so a crowd doesn't all look around in the same frame


func setup(k: String, d: Dictionary, m, start: Vector2, hp_mult: float, dmg_mult: float, bounty_mult: float) -> void:
	kind = k
	main = m
	max_hp = d["hp"] * hp_mult
	hp = max_hp
	speed = d["speed"] * randf_range(0.9, 1.1)
	damage = d["damage"] * dmg_mult
	wall_damage = d.get("wall_damage", d["damage"]) * dmg_mult
	attack_cd = d["cooldown"]
	fights = d["fights"]
	flying = d.get("flying", false)
	cc_mult = d.get("cc", 1.0)
	knock_mult = d.get("knock", 1.0)
	boss = d.get("boss", false)
	if d.has("stomp"):
		stomp = d["stomp"].duplicate()
		stomp["damage"] *= dmg_mult
	if d.has("breath"):
		breath = d["breath"].duplicate()
		breath["damage"] *= dmg_mult
	cleave = d.get("cleave", {})
	summon = d.get("summon", {})
	horn = d.get("horn", {})
	enrage_at = d.get("enrage", 0.0)
	if d.has("bomb"):
		bomb = {"wall": d["bomb"]["wall"] * dmg_mult, "units": d["bomb"]["units"] * dmg_mult, "radius": d["bomb"]["radius"]}
	tier = d["tier"]
	bounty = roundi(d["bounty"] * bounty_mult)
	radius = d["radius"]
	sprite_scale = d["scale"]
	color = d["color"]
	position = start
	bob = randf() * TAU
	drift = randf() * TAU


func _process(delta: float) -> void:
	if dead:
		return
	walking = false
	fighting = false
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_factor = 1.0
	flash = maxf(flash - delta, 0.0)
	lunge = maxf(lunge - delta, 0.0)
	cd_timer = maxf(cd_timer - delta, 0.0)
	root_timer = maxf(root_timer - delta, 0.0)
	confuse_timer = maxf(confuse_timer - delta, 0.0)
	if discord_timer > 0.0:
		discord_timer -= delta
		if discord_timer <= 0.0:
			vuln = 0.0
			weaken = 0.0
			discord_slow = 0.0
	if burn_timer > 0.0:
		burn_timer -= delta
		take_damage(burn_dps * delta, false)
		if dead:
			return
	charged_timer = maxf(charged_timer - delta, 0.0)
	if thorn_timer > 0.0:
		thorn_timer -= delta
		take_damage(thorn_dps * delta, false)
		if dead:
			return
	if decay_timer > 0.0:
		take_damage(decay_dps * delta, false)   # before the timer runs down, so a rot kill still counts
		decay_timer -= delta
		if dead:
			return
	if corrode_timer > 0.0:
		corrode_timer -= delta
		if corrode_timer <= 0.0:
			corrode = 0.0
	if not poisons.is_empty():
		var worst := 0.0
		poison_stacks = 0
		for id in poisons.keys():
			var dose: Array = poisons[id]
			dose[2] -= delta
			if dose[2] <= 0.0:
				poisons.erase(id)
			elif dose[0] * dose[1] > worst:
				worst = dose[0] * dose[1]
				poison_stacks = dose[1]
		take_damage(worst * delta, false)
		if dead:
			return
	if fuse >= 0.0:
		# Lit: stands there fizzing, then goes off. Killing it first defuses it.
		fuse -= delta
		if fuse < 0.0:
			_explode()
			return
		queue_redraw()
		return
	if knock_timer > 0.0:
		# Being knocked back: slides away, can't act.
		knock_timer -= delta
		position += knock_velocity * delta
		position.y = maxf(position.y, radius)
		_push_out()
		queue_redraw()
		return
	if freeze_timer > 0.0 or stun_timer > 0.0:
		# Frozen solid or blinded: no moving, no attacking.
		freeze_timer = maxf(freeze_timer - delta, 0.0)
		stun_timer = maxf(stun_timer - delta, 0.0)
		_push_out()
		queue_redraw()
		return

	if boss:
		_boss_update(delta)
	if not breath.is_empty():
		_breathe(delta)
	if confuse_timer > 0.0:
		_confused(delta)
		_push_out()
		queue_redraw()
		return
	aggro_check -= delta
	if aggro_check <= 0.0:
		aggro_check = 0.3
		aggro = _attacker()
	elif aggro != null and (not is_instance_valid(aggro) or not aggro.is_active()):
		aggro = null
	var blocker = _find_blocker() if fights and bomb.is_empty() else null
	var wall = _wall_to_break(delta) if blocker == null and not flying else null
	var at_castle: bool = position.y + radius * 0.5 >= main.CASTLE_Y
	if at_castle and not sieging:
		sieging = true
		reached_castle.emit(self)
	if not bomb.is_empty() and (at_castle or wall != null):
		fuse = FUSE   # at the castle, or up against a wall in the way: light the bomb
		main.spawn_text(position + Vector2(0, -30), "Fsss!", Color(1, 0.6, 0.2))
		queue_redraw()
		return
	fighting = blocker != null or wall != null
	if blocker != null:
		lunge_dir = position.direction_to(blocker.position)
		if absf(lunge_dir.x) > 0.2:
			flip = signf(lunge_dir.x)
		if cd_timer <= 0.0:
			cd_timer = attack_cd
			lunge = 0.15
			if cleave.is_empty():
				blocker.take_damage(damage * (1.0 - weaken))
			else:
				_cleave()
	elif wall != null:
		lunge_dir = position.direction_to(Geometry2D.get_closest_point_to_segment(position, wall.seg_a(), wall.seg_b()))
		if absf(lunge_dir.x) > 0.2:
			flip = signf(lunge_dir.x)
		if cd_timer <= 0.0:
			cd_timer = attack_cd
			lunge = 0.15
			wall.struck(self, wall_damage * (1.0 - weaken))
	elif at_castle:
		# At the castle: hammer on its wall until something kills it.
		fighting = true
		lunge_dir = Vector2.DOWN
		if cd_timer <= 0.0:
			cd_timer = attack_cd
			lunge = 0.15
			main.damage_castle(wall_damage * (1.0 - weaken))
	elif root_timer > 0.0:
		pass   # held in place by vines
	else:
		drift += delta * 1.3
		var dir := Vector2(sin(drift) * 0.3, 1.0).normalized()
		var route: Vector2 = Vector2.ZERO if flying else main.paths.direction(position, radius)
		if aggro != null and not breath.is_empty() and position.distance_to(aggro.position) <= breath["range"] * 0.75:
			# A Wyvern hangs in the air within breath range of whoever's shooting it.
			dir = Vector2.ZERO
		elif aggro != null:
			# Going after the unit that's attacking it.
			dir = position.direction_to(aggro.position)
		elif route != Vector2.ZERO:
			# Barricades are up: follow the route around them, still weaving a little.
			dir = (route + Vector2(sin(drift) * 0.15, 0.0)).normalized()
		position += dir * speed * slow_factor * (1.0 - discord_slow) * delta
		if absf(dir.x) > 0.1:
			flip = signf(dir.x)
		bob += delta * (20.0 if flying else 10.0)   # bats flap fast
		walking = true
	_push_out()
	progress = position.y
	position.y = minf(position.y, main.CASTLE_Y - radius * 0.5)   # the castle wall stops it
	queue_redraw()


## Ogre King: stomps when anything of yours is close, calls in help, and gets
## angrier as it's worn down.
func _boss_update(delta: float) -> void:
	if not enraged and enrage_at > 0.0 and hp < max_hp * enrage_at:
		enraged = true
		speed *= ENRAGE_SPEED
		attack_cd *= ENRAGE_RATE
		main.hud.show_message("The Ogre King is enraged!")
	stomp_timer -= delta
	if not stomp.is_empty() and stomp_timer <= 0.0:
		var r: float = stomp["radius"]
		var near: Array = main.get_warriors().filter(func(w): return w.is_active() and position.distance_to(w.position) <= r + w.RADIUS)
		var walls: Array = main.get_barricades().filter(func(b): return b.is_active() and b.gap_from(position) <= r)
		if not near.is_empty() or not walls.is_empty():
			stomp_timer = stomp["cooldown"]
			main.sfx("stomp")
			lunge = 0.15
			for w in near:
				w.take_damage(stomp["damage"])
				var away: Vector2 = position.direction_to(w.position) if w.position != position else Vector2.DOWN
				w.shove(away * stomp.get("push", 0.0), stomp.get("stun", 0.0))
			for b in walls:
				b.take_damage(stomp["damage"] * 3.0)
			main.spawn_burst(position + Vector2(0, radius), r, Color(0.65, 0.5, 0.3))
			main.spawn_burst(position + Vector2(0, radius), r * 0.6, Color(0.85, 0.75, 0.55))
			main.spawn_text(position + Vector2(0, -60), "STOMP!", Color(1, 0.75, 0.4))
	summon_timer -= delta
	if not summon.is_empty() and summon_timer <= 0.0 and position.y > 0.0:
		summon_timer = summon["cooldown"]
		for i in summon["count"]:
			var spot := position + Vector2.from_angle(PI + i * PI / maxf(summon["count"] - 1, 1)) * (radius + 20.0)
			main.spawn_minion(summon["kinds"].pick_random(), level, spot)
		main.spawn_text(position + Vector2(0, -60), "To me!", Color(1, 0.5, 0.4))
	horn_timer -= delta
	if not horn.is_empty() and horn_timer <= 0.0 and position.y > 0.0:
		horn_timer = horn["cooldown"]
		var kinds: Array = []
		for i in horn["count"]:
			kinds.append(horn["kinds"].pick_random())
		main.reinforce(kinds, level)
		main.spawn_text(position + Vector2(0, -60), "WAR HORN!", Color(1, 0.4, 0.3))


## Ogre King's blow: sweeps an arc in front of it, hitting everyone caught in it.
func _cleave() -> void:
	var reach: float = cleave["reach"]
	var half: float = cleave["arc"] / 2.0
	for w in main.get_warriors():
		if not w.is_active():
			continue
		var off: Vector2 = w.position - position
		if off.length() - radius - w.RADIUS > reach:
			continue
		if off.length() > 0.01 and absf(lunge_dir.angle_to(off)) > half:
			continue
		w.take_damage(damage * (1.0 - weaken))
	var tip := position + lunge_dir * (radius + reach * 0.6)
	main.spawn_burst(tip, reach + 10.0, Color(1.0, 0.85, 0.6))


## Wyvern: breathes fire down on the warrior nearest below it, splashing those around.
func _breathe(delta: float) -> void:
	breath_timer -= delta
	if breath_timer > 0.0 or position.y < 0.0:
		return
	var best = null
	var best_d: float = breath["range"]
	if aggro != null and is_instance_valid(aggro) and aggro.is_active() and position.distance_to(aggro.position) - aggro.RADIUS < best_d:
		best = aggro   # whoever's attacking it gets the fire first
	else:
		for w in main.get_warriors():
			if not w.is_active():
				continue
			var d: float = position.distance_to(w.position) - w.RADIUS
			if d < best_d:
				best_d = d
				best = w
	if best == null:
		return
	breath_timer = breath["cooldown"]
	var at: Vector2 = best.position
	for w in main.get_warriors():
		if w.is_active() and w.position.distance_to(at) <= breath["radius"] + w.RADIUS:
			w.take_damage(breath["damage"] * (1.0 - weaken))
	lunge_dir = position.direction_to(at)
	lunge = 0.15
	main.spawn_flame(position + Vector2(0, -FLY_HEIGHT), at)
	main.spawn_burst(at, breath["radius"], Color(1.0, 0.5, 0.15))


## The unit attacking this enemy that it turns on, if any: the nearest one that has
## it as its target and is within range of it (so is shooting or swinging at it, not
## just heading its way), within AGGRO_LEASH, with no wall in between. Sappers and
## wolves never turn aside; a Wyvern flies over to breathe fire on its attacker.
func _attacker():
	if (not fights and breath.is_empty()) or not bomb.is_empty() or boss:
		return null   # wolves slip past, sappers have a job to do (Wyverns breathe on theirs)
	var best = null
	var best_d := AGGRO_LEASH
	for w in main.get_warriors():
		if not w.is_active() or w.target != self or w.is_emplacement() and w.attack_range <= 0.0:
			continue
		var d: float = position.distance_to(w.position)
		if d > best_d or d - radius - w.RADIUS > w.attack_range + 12.0:
			continue
		if not flying and _wall_across(position, w.position):
			continue
		best_d = d
		best = w
	return best


func _wall_across(a: Vector2, b: Vector2) -> bool:
	for wall in main.paths.walls:
		if Geometry2D.segment_intersects_segment(a, b, wall.seg_a(), wall.seg_b()) != null:
			return true
	return false


## Sapper's bomb: wrecks walls and hurts warriors nearby, and takes the Sapper with it
## (no bounty for an enemy that blew itself up).
func _explode() -> void:
	dead = true
	main.enemies_changed()
	var r: float = bomb["radius"]
	for b in main.get_barricades():
		if b.is_active() and b.gap_from(position) <= r:
			b.take_damage(bomb["wall"])
	for w in main.get_warriors():
		if w.is_active() and position.distance_to(w.position) <= r + w.RADIUS:
			w.take_damage(bomb["units"])
	if position.y + r * 0.5 >= main.CASTLE_Y:
		main.damage_castle(bomb["units"] * 2.0)   # the castle's walls are thicker than a barricade's
	main.spawn_flash(position, r * 0.7)
	main.spawn_burst(position, r, Color(1.0, 0.55, 0.2))
	main.spawn_burst(position, r * 0.55, Color(1.0, 0.9, 0.5))
	main.spawn_text(position + Vector2(0, -30), "BOOM!", Color(1, 0.55, 0.2))
	main.sfx("boom", 0.9)
	queue_free()


const CONFUSED_DAMAGE := 3.0   # confused enemies hit each other this much harder than they hit warriors


## Confused: wanders to the nearest other enemy and fights it.
func _confused(delta: float) -> void:
	var foe = null
	var best := 260.0
	for e in main.get_enemies():
		if e == self:
			continue
		var d: float = position.distance_to(e.position)
		if d < best:
			best = d
			foe = e
	if foe == null:
		return
	lunge_dir = position.direction_to(foe.position)
	if absf(lunge_dir.x) > 0.2:
		flip = signf(lunge_dir.x)
	if best - radius - foe.radius > REACH:
		if root_timer <= 0.0:
			position += lunge_dir * speed * slow_factor * delta
			bob += delta * 10.0
	elif cd_timer <= 0.0:
		cd_timer = attack_cd
		lunge = 0.15
		foe.take_damage(maxf(damage, 4.0) * CONFUSED_DAMAGE)


## The barricade to hack at: the one this enemy is up against when its route has
## to go through it, or one it has been pressed against without getting anywhere
## (a gap too tight to fit, or a crush of others). A stuck enemy hacks for a few
## seconds, then tries to get past again.
func _wall_to_break(delta: float):
	var touching = main.barricade_touching(position, radius + REACH)
	if touching == null:
		wall_target = null
		stuck_time = 0.0
		return null
	if main.paths.breach_at(position, radius) == touching:
		wall_target = touching
		return touching
	if touching == wall_target and wall_commit > 0.0:
		wall_commit -= delta
		return touching
	wall_target = null
	stuck_time += delta
	if stuck_time >= 1.0:
		var moved := position.distance_to(stuck_check)
		stuck_check = position
		stuck_time = 0.0
		if moved < 10.0 and root_timer <= 0.0 and slow_factor > 0.3:
			wall_target = touching
			wall_commit = 3.0
			return touching
	return null


func _find_blocker():
	var best = null
	var best_d := INF
	for w in main.warriors_near(position, radius + REACH + 24.0):
		if not w.is_active():
			continue
		var d: float = position.distance_to(w.position) - radius - w.RADIUS
		if d <= REACH and d < best_d:
			best_d = d
			best = w
	return best


# Keep enemies from overlapping each other or walking through warriors.
## Flyers only bump into other flyers.
func _push_out() -> void:
	if not flying and not boss:   # nothing shoves the Ogre King around; others make way
		for w in main.warriors_near(position, radius + 24.0):
			if w.is_active():
				_push_from(w.position, radius + w.RADIUS, 1.0)
	if not boss:
		for e in main.enemies_near(position, radius + main.MAX_ENEMY_RADIUS):
			if e != self and e.flying == flying:
				_push_from(e.position, radius + e.radius, 1.0 if e.boss else 0.5)
	position.x = clampf(position.x, radius, main.FIELD_W - radius)
	if flying:
		return
	# Walls are solid: step straight back out of them, last so nothing pushes it back in.
	for b in main.get_barricades():
		if not b.is_active():
			continue
		var c := Geometry2D.get_closest_point_to_segment(position, b.seg_a(), b.seg_b())
		var min_d: float = radius + b.WALL_HALF
		var off := position - c
		var d := off.length()
		if d < min_d:
			if d < 0.01:
				off = Vector2.UP
				d = 1.0
			position = c + off / d * min_d
	position.x = clampf(position.x, radius, main.FIELD_W - radius)


func _push_from(p: Vector2, min_d: float, share: float) -> void:
	var off := position - p
	var d := off.length()
	if d >= min_d:
		return
	if d < 0.01:
		off = Vector2(randf_range(-1, 1), -0.1)
		d = off.length()
	# Bias sideways so blocked enemies flow around obstacles instead of stalling.
	var away := off / d
	if absf(away.x) < 0.3:
		away.x = 0.3 if away.x >= 0.0 else -0.3
	position += away.normalized() * (min_d - d) * share


func take_damage(amount: float, show_hit := true) -> void:
	if dead:
		return
	hp -= amount * (1.0 + vuln + corrode + (confuse_vuln if confuse_timer > 0.0 else 0.0))
	if show_hit:
		flash = 0.08
	if hp <= 0.0:
		dead = true
		died.emit(self)
		queue_free()


## Burning keeps the strongest burn and refreshes its duration.
func apply_burn(dps: float, duration: float) -> void:
	if burn_timer <= 0.0:
		burn_dps = 0.0
	burn_dps = maxf(burn_dps, dps)
	burn_timer = maxf(burn_timer, duration)


## Each dose adds a stack (up to max_stacks) to the poison from that Alchemist.
## Poisons from different Alchemists don't add up: only the worst one hurts.
func apply_poison(dps: float, duration: float, max_stacks: int, source: int) -> void:
	var dose: Array = poisons.get(source, [dps, 0, 0.0])
	dose[0] = maxf(dose[0], dps)
	dose[1] = mini(dose[1] + 1, maxi(max_stacks, dose[1]))
	dose[2] = maxf(dose[2], duration)
	poisons[source] = dose


func apply_corrode(amount: float, duration: float) -> void:
	corrode = maxf(corrode if corrode_timer > 0.0 else 0.0, amount)
	corrode_timer = maxf(corrode_timer, duration)


func apply_stun(duration: float) -> void:
	duration *= cc_mult
	stun_timer = maxf(stun_timer, duration)


## Pushes the enemy along `push` (its length is the distance) over a fifth of a second.
func apply_knockback(push: Vector2) -> void:
	if knock_mult <= 0.0:
		return   # immune: not even a stagger
	push *= knock_mult
	knock_timer = 0.2
	knock_velocity = push / knock_timer


func apply_freeze(duration: float) -> void:
	duration *= cc_mult
	freeze_timer = maxf(freeze_timer, duration)


## Bard Discord song: refreshed while the enemy stays in earshot.
func apply_discord(v: float, w: float, slow: float, duration: float) -> void:
	vuln = maxf(vuln, v)
	weaken = maxf(weaken, w)
	discord_slow = maxf(discord_slow, slow)
	discord_timer = maxf(discord_timer, duration)


func apply_root(duration: float) -> void:
	duration *= cc_mult
	root_timer = maxf(root_timer, duration)


func apply_confuse(duration: float, extra_vuln := 0.0) -> void:
	duration *= cc_mult
	if confuse_timer <= 0.0:
		confuse_vuln = 0.0
	confuse_vuln = maxf(confuse_vuln, extra_vuln)
	confuse_timer = maxf(confuse_timer, duration)


## Necromancy rot: the strongest rot counts, and it remembers whose it is.
func apply_decay(dps: float, duration: float, source: int) -> void:
	if decay_timer <= 0.0 or dps >= decay_dps:
		decay_dps = dps
		decay_source = source
	decay_timer = maxf(decay_timer, duration)


## Thornwild: thorny plants and vines.
func apply_thorns(dps: float, duration: float) -> void:
	if thorn_timer <= 0.0:
		thorn_dps = 0.0
	thorn_dps = maxf(thorn_dps, dps)
	thorn_timer = maxf(thorn_timer, duration)


## Struck by lightning: a Storm mage's magnetizing blasts can pull it in.
func charge(duration: float) -> void:
	charged_timer = maxf(charged_timer, duration)


func apply_slow(strength: float, duration: float) -> void:
	slow_factor = minf(slow_factor, 1.0 - strength)
	slow_timer = maxf(slow_timer, duration)


func _draw() -> void:
	var tint := Color.WHITE
	if slow_timer > 0.0 or freeze_timer > 0.0:
		tint = Color(0.6, 0.85, 1.3)
	if flash > 0.0:
		tint = Color(3, 3, 3)
	var frames: Array = Sprites.frames(kind)
	var size := Vector2(Sprites.SIZE, Sprites.SIZE) * sprite_scale
	var feet := radius
	# Shadow, sprite and health bar all come from the sprite atlas, so the renderer can
	# batch every enemy on the field together.
	var sr := radius * (0.8 if flying else 1.1)
	draw_texture_rect(Sprites.shadow(), Rect2(-sr, feet - sr * 0.35, sr * 2.0, sr * 0.7), false, Color(0, 0, 0, 0.22 if flying else 0.3))
	if flying:
		feet -= FLY_HEIGHT + sin(bob * 0.3) * 3.0   # everything else is drawn up in the air
	if fuse >= 0.0 and int(fuse * 12.0) % 2 == 0:
		tint = Color(3, 1.2, 0.6)   # a lit bomb blinks
	var frame := int(bob / 2.5) % 2
	var nudge := lunge_dir * (lunge / 0.15) * 6.0
	# Body motion: a waddling hop while walking, rearing back before a blow, and a
	# squash when hit. Pivots on the feet.
	var rot := 0.0
	var sc := Vector2.ONE
	if walking and not flying:
		var ph := bob * PI / 2.5
		nudge.y -= absf(sin(ph)) * 2.5 * minf(1.0, 3.0 / sprite_scale)
		rot = sin(ph) * 0.06
	if fighting and cd_timer < 0.3 and lunge <= 0.0:
		var k := 1.0 - cd_timer / 0.3
		nudge -= lunge_dir * 4.0 * k
		rot -= 0.12 * k * signf(lunge_dir.x)
		sc = Vector2(1.0 - 0.04 * k, 1.0 + 0.06 * k)
	if lunge > 0.0:
		sc = Vector2(1.1, 0.92)
	if flash > 0.0:
		sc = Vector2(1.12, 0.88)
	draw_set_transform(Vector2(0, feet) + nudge, rot, Vector2(flip * sc.x, sc.y))
	draw_texture_rect(frames[frame], Rect2(Vector2(-size.x / 2, -size.y), size), false, tint)
	if freeze_timer > 0.0:
		var ice := Rect2(Vector2(-size.x / 2, -size.y) + Vector2(size.x * 0.15, size.y * 0.1), size * Vector2(0.7, 0.9))
		draw_texture_rect(Sprites.white(), ice, false, Color(0.75, 0.92, 1.0, 0.45))
		draw_rect(ice, Color(0.9, 0.97, 1.0, 0.9), false, 2.0)
	draw_set_transform(Vector2.ZERO)
	if stun_timer > 0.0:
		# Dazed: little stars circling the head.
		var spin := Time.get_ticks_msec() / 200.0
		var head := Vector2(0, feet - size.y * 0.9)
		for i in 3:
			var p := head + Vector2.from_angle(spin + i * TAU / 3.0) * Vector2(radius * 0.8, 4.0)
			draw_rect(Rect2(p - Vector2(2.5, 2.5), Vector2(5, 5)), Color(1, 0.95, 0.4))
	if root_timer > 0.0:
		# Vines wrapped around the feet.
		for i in 4:
			var x := (-0.75 + i * 0.5) * radius
			var sway := sin(Time.get_ticks_msec() / 150.0 + i) * 2.0
			draw_line(Vector2(x, feet + 2), Vector2(x + sway, feet - size.y * 0.35), Color(0.2, 0.55, 0.15), 3.0, true)
			Sprites.disc(self, Vector2(x + sway, feet - size.y * 0.35), 2.5, Color(0.35, 0.75, 0.25))
	if confuse_timer > 0.0:
		# Confused: a spinning purple "?" over the head.
		var bob_y := sin(Time.get_ticks_msec() / 120.0) * 2.0
		var head := Vector2(-5, feet - size.y - 6 + bob_y)
		draw_string_outline(ThemeDB.fallback_font, head, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 3, Color.BLACK)
		draw_string(ThemeDB.fallback_font, head, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.85, 0.5, 1.0))
	if discord_timer > 0.0:
		# Unsettled by a Bard's discord: a dark purple note bobbing beside the head.
		var n := Vector2(radius * 0.9, feet - size.y * 0.85 + sin(Time.get_ticks_msec() / 200.0) * 2.0)
		Sprites.disc(self, n, 2.5, Color(0.55, 0.25, 0.7))
		draw_line(n + Vector2(2, 0), n + Vector2(2, -8), Color(0.55, 0.25, 0.7), 1.5, true)
	if not poisons.is_empty():
		# Poisoned: green bubbles rising off the body, more with each stack.
		var t := Time.get_ticks_msec() / 1000.0
		for i in mini(poison_stacks, 4) + 1:
			var k := fmod(t * 0.9 + i * 0.27 + bob * 0.01, 1.0)
			var x := sin(i * 2.1 + drift) * radius * 0.6
			Sprites.disc(self, Vector2(x, feet - size.y * (0.35 + 0.5 * k)), 1.5 + k * 1.5, Color(0.55, 1.0, 0.3, 0.9 * (1.0 - k)))
	if corrode_timer > 0.0:
		# Acid-burned: yellow-green drips down the body.
		for i in 3:
			var x := (-0.6 + i * 0.6) * radius
			var drip := fmod(Time.get_ticks_msec() / 400.0 + i * 0.4, 1.0) * 6.0
			draw_rect(Rect2(Vector2(x - 1.5, feet - size.y * 0.55 + drip), Vector2(3, 4)), Color(0.85, 0.95, 0.2, 0.85))
	if decay_timer > 0.0:
		# Rotting: sickly green wisps curling up off the body.
		var t := Time.get_ticks_msec() / 1000.0
		for i in 3:
			var k := fmod(t * 0.7 + i * 0.33, 1.0)
			var x := sin(t * 3.0 + i * 2.0) * radius * 0.5
			Sprites.disc(self, Vector2(x, feet - size.y * (0.3 + 0.6 * k)), 2.5 - k, Color(0.5, 0.9, 0.35, 0.8 * (1.0 - k)))
			Sprites.disc(self, Vector2(x + 2, feet - size.y * (0.3 + 0.6 * k) + 2), 1.5, Color(0.35, 0.2, 0.4, 0.7 * (1.0 - k)))
	if thorn_timer > 0.0:
		# Thorny briars wound round the legs.
		for i in 3:
			var x := (-0.6 + i * 0.6) * radius
			var y := feet - size.y * 0.2
			draw_line(Vector2(x - 4, y + 3), Vector2(x + 4, y - 3), Color(0.35, 0.25, 0.1), 2.0, true)
			draw_line(Vector2(x, y), Vector2(x + 2, y - 4), Color(0.6, 0.15, 0.15), 1.5, true)
	if charged_timer > 0.0 and int(Time.get_ticks_msec() / 80) % 3 != 0:
		# Charged: little blue sparks crackling over it.
		var t := Time.get_ticks_msec() / 80
		for i in 2:
			var p := Vector2(sin(t * 1.7 + i * 3.0) * radius * 0.7, feet - size.y * (0.4 + 0.3 * sin(t + i)))
			draw_line(p, p + Vector2(3, -3), Color(0.6, 0.85, 1.0), 1.5)
			draw_line(p + Vector2(3, -3), p + Vector2(1, -6), Color(0.85, 0.95, 1.0), 1.5)
	if burn_timer > 0.0:
		# Flickering pixel flames on the body.
		var t := Time.get_ticks_msec() / 90
		for i in 3:
			var x := (-0.5 + i * 0.5) * radius
			var h := 4.0 + float((t + i * 7) % 4) * 2.0
			var base := Vector2(x, feet - size.y * 0.45)
			draw_rect(Rect2(base + Vector2(-3, -h), Vector2(6, h)), Color(1.0, 0.45, 0.1, 0.85))
			draw_rect(Rect2(base + Vector2(-1.5, -h * 0.6), Vector2(3, h * 0.6)), Color(1.0, 0.9, 0.3, 0.9))
	if hp < max_hp:
		var w := radius * 2.0
		var top := Vector2(-radius, feet - size.y - 2)
		var bar := Sprites.white()
		draw_texture_rect(bar, Rect2(top, Vector2(w, 4)), false, Color(0, 0, 0, 0.6))
		draw_texture_rect(bar, Rect2(top, Vector2(w * hp / max_hp, 4)), false, Color(0.3, 0.95, 0.3))
