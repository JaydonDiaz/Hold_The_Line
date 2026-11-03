extends "res://scripts/warrior.gd"
## A wall built between two points the player clicks. Enemies walk around it when
## they can (see pathing.gd) and hack at it when they can't. Its health, price and
## upgrade costs scale with its length. It blocks your own troops and their shots
## too (see Warrior.shoots_over_walls).
## Walls never heal on their own: only Engineering repairs them, and only during
## waves, so waiting between waves doesn't top them up. A wall that breaks is gone.

const WALL_HALF := 8.0          # half the wall's thickness, for blocking enemies
const UPGRADE_LENGTH := 160.0   # upgrade prices and repair rates in data.gd are for a wall this long
const STAKE_GAP := 9.0
const ARCHER_EVERY := 150.0     # Arrow Slits: one archer per this much wall
const WOOD := Color(0.6, 0.42, 0.24)
const WOOD_DARK := Color(0.42, 0.28, 0.15)
const STONE := Color(0.62, 0.6, 0.58)
const STONE_DARK := Color(0.42, 0.4, 0.4)
const IRON := Color(0.75, 0.77, 0.82)
const OUTLINE := Color(0.1, 0.07, 0.1)

var half := Vector2(50, 0)   # from the middle of the wall to one end
var thorns := 0.0
var wall_slow := []          # [strength, reach]
var repair := 0.0            # HP repaired per second during waves
var slits := {}              # damage, cooldown, range
var slow_tick := 0.0
var stakes := []             # height jitter per stake, so the palisade looks hand-built
var built_length := 0.0      # length when it was built: health, prices and arrow slits go by this,
                             # even if the field is resized and the wall stretches with it
var end_u := Vector2.ZERO    # where its two ends sit across the field (0-1), kept through resizes


static func cost_for(d: Dictionary, length: float) -> int:
	return int(d["cost_base"]) + roundi(length * d["cost_per_100"] / 100.0)


func length() -> float:
	return half.length() * 2.0


## Length for its stats: what it was built at, not what a resize has stretched it to.
func stat_length() -> float:
	return built_length if built_length > 0.0 else length()


func seg_a() -> Vector2:
	return position - half


func seg_b() -> Vector2:
	return position + half


func _ready() -> void:
	for i in int(length() / STAKE_GAP) + 1:
		stakes.append(randf_range(-2.0, 2.0))


func _apply_upgrades() -> void:
	super()
	thorns = 0.0
	wall_slow = []
	repair = 0.0
	slits = {}
	for p in 3:
		var path_tiers: Array = data["paths"][p]["tiers"]
		for t in tiers[p]:
			var fx: Dictionary = path_tiers[t]["effect"]
			thorns = fx.get("thorns", thorns)
			wall_slow = fx.get("wall_slow", wall_slow)
			repair = fx.get("repair", repair)
			slits = fx.get("slits", slits)
	if built_length <= 0.0:
		built_length = length()
	max_hp *= stat_length() / 100.0
	repair *= length_scale()
	damage = slits.get("damage", 0.0)
	cooldown = slits.get("cooldown", 1.0)
	attack_range = slits.get("range", 0.0)


## How much bigger (or smaller) than a standard wall this one is, for upgrade
## prices and repair rates. No upper limit: a wall twice as long costs twice as
## much to upgrade.
func length_scale() -> float:
	return maxf(stat_length() / UPGRADE_LENGTH, 0.5)


func tier_cost(p: int, t: int) -> int:
	return roundi(super(p, t) * length_scale())


func is_active() -> bool:
	return not is_queued_for_deletion()


func uses_targeting() -> bool:
	return not slits.is_empty()


func archers() -> int:
	return maxi(1, roundi(stat_length() / ARCHER_EVERY))


## Distance from the wall's face to an enemy's edge.
func _gap_to(e) -> float:
	return gap_from(e.position) - e.radius


func gap_from(p: Vector2) -> float:
	return Geometry2D.get_closest_point_to_segment(p, seg_a(), seg_b()).distance_to(p) - WALL_HALF


func take_damage(amount: float) -> void:
	if not is_active():
		return
	hp -= amount * (1.0 - armor)
	hurt = 0.1
	if hp <= 0.0:
		# Broken for good.
		hp = 0.0
		main.spawn_text(position + Vector2(0, -24), "Destroyed!", Color(1, 0.3, 0.3))
		for i in 3:
			main.spawn_burst(position + half * (i - 1) * 0.7, 18.0, Color(0.6, 0.45, 0.3))
		if main.selected == self:
			main.selected = null
		queue_free()
		main.walls_changed()


## An enemy hacking at the wall; spikes hurt it back.
func struck(attacker, amount: float) -> void:
	take_damage(amount)
	if thorns > 0.0 and is_instance_valid(attacker) and not attacker.dead:
		attacker.take_damage(attacker.max_hp * thorns * attacker.cc_mult, false)


func _process(delta: float) -> void:
	hurt = maxf(hurt - delta, 0.0)
	cd_timer = maxf(cd_timer - delta, 0.0)
	queue_redraw()
	if repair > 0.0 and main.wave_active:
		hp = minf(max_hp, hp + repair * delta)
	if not wall_slow.is_empty():
		slow_tick -= delta
		if slow_tick <= 0.0:
			slow_tick = 0.25
			for e in main.get_enemies():
				if not e.flying and _gap_to(e) <= wall_slow[1]:
					e.apply_slow(wall_slow[0], 0.4)
	if not slits.is_empty() and cd_timer <= 0.0:
		var others: Array = main.get_enemies().filter(_in_range)
		if not others.is_empty():
			cd_timer = cooldown
			for i in archers():
				var e = _pick(others)
				if e == null:
					break
				others.erase(e)
				_loose(e)


## Arrow Slits: an arrow from the nearest stretch of wall.
func _loose(e) -> void:
	var p := Projectile.new()
	p.main = main
	p.target = e
	p.target_pos = e.position
	p.position = Geometry2D.get_closest_point_to_segment(e.position, seg_a(), seg_b()) + Vector2(0, -14)
	p.damage = damage
	p.speed = 500.0
	p.style = "arrow"
	main.add_projectile(p)


func stats_text() -> String:
	var s := "HP %d/%d   Length %s" % [ceili(hp), ceili(max_hp), Data.ft(length())]
	if absf(length() - stat_length()) > 5.0:
		s += " (built %s; health and prices go by that)" % Data.ft(stat_length())
	if armor > 0.0:
		s += "   Armor %d%%" % roundi(armor * 100)
	if thorns > 0.0:
		s += "   Thorns %d%% max HP" % roundi(thorns * 100)
	if not wall_slow.is_empty():
		s += "   Slows %d%% within %s" % [roundi(wall_slow[0] * 100), Data.ft(wall_slow[1])]
	if repair > 0.0:
		s += "   Repairs %.1f HP/s in waves" % repair
	if not slits.is_empty():
		s += "   %d archer%s: %.0f dmg / %.1fs, range %s" % [archers(), "" if archers() == 1 else "s", damage, cooldown, Data.ft(attack_range)]
	return s


func _draw() -> void:
	var a := -half
	var b := half
	var stone: bool = tiers[1] >= 3
	var along := (b - a).normalized()
	var count := int(length() / STAKE_GAP) + 1   # stretched walls get more stakes, not gappy ones
	# Shadow on the ground.
	draw_line(a + Vector2(0, 7), b + Vector2(0, 7), Color(0, 0, 0, 0.3), 10.0)
	var tint := Color(1, 0.5, 0.5) if hurt > 0.0 else Color.WHITE
	if stone:
		# Fortify tier 3+: a stone wall with mortared blocks and battlements on top.
		var h: float = 22.0 + (tiers[1] - 3) * 4.0
		var body := PackedVector2Array([a + Vector2(0, 6), b + Vector2(0, 6), b + Vector2(0, -h), a + Vector2(0, -h)])
		draw_colored_polygon(body, OUTLINE)
		var inner := PackedVector2Array([a + Vector2(1.5, 4.5), b + Vector2(-1.5, 4.5), b + Vector2(-1.5, -h + 1.5), a + Vector2(1.5, -h + 1.5)])
		draw_colored_polygon(inner, STONE * tint)
		draw_line(a + Vector2(1.5, -h + 3), b + Vector2(-1.5, -h + 3), STONE.lightened(0.2) * tint, 2.0)
		for k in [-3.0, -h * 0.5 - 1.5]:
			draw_line(a + Vector2(1.5, k), b + Vector2(-1.5, k), STONE_DARK, 1.0)
		var blocks := maxi(1, int(length() / 14.0))
		for i in blocks:
			# Staggered vertical joints, one row above the other.
			var top_j := a.lerp(b, (i + 0.5) / blocks)
			var low_j := a.lerp(b, (i + 1.0) / blocks)
			draw_line(top_j + Vector2(0, -h + 2), top_j + Vector2(0, -h * 0.5 - 1.5), STONE_DARK, 1.0)
			if i < blocks - 1:
				draw_line(low_j + Vector2(0, -h * 0.5 - 1.5), low_j + Vector2(0, 4.5), STONE_DARK, 1.0)
		var merlons := maxi(1, int(length() / 16.0))
		for i in merlons:
			var p := a.lerp(b, (i + 0.5) / merlons) + Vector2(0, -h)
			draw_rect(Rect2(p + Vector2(-4.5, -7), Vector2(9, 8)), OUTLINE)
			draw_rect(Rect2(p + Vector2(-3, -5.5), Vector2(6, 6)), STONE.lightened(0.08) * tint)
	else:
		# A wooden palisade of pointed stakes, lashed together.
		for i in count:
			var p := a.lerp(b, i / maxf(count - 1.0, 1.0))
			var h: float = 20.0 + stakes[i % stakes.size()] + tiers[1] * 1.5
			var body := PackedVector2Array([p + Vector2(-4, 6), p + Vector2(4, 6), p + Vector2(4, -h + 4), p + Vector2(0, -h), p + Vector2(-4, -h + 4)])
			draw_colored_polygon(body, OUTLINE)
			var inner := PackedVector2Array([p + Vector2(-2.5, 4.5), p + Vector2(2.5, 4.5), p + Vector2(2.5, -h + 4.5), p + Vector2(0, -h + 2), p + Vector2(-2.5, -h + 4.5)])
			draw_colored_polygon(inner, (WOOD if i % 2 == 0 else WOOD_DARK.lightened(0.15)) * tint)
			if tiers[0] > 0:
				# Spikes: iron-capped stakes.
				draw_colored_polygon(PackedVector2Array([p + Vector2(-2.5, -h + 5), p + Vector2(2.5, -h + 5), p + Vector2(0, -h + 1)]), IRON)
		var band := Color(0.3, 0.2, 0.12) if tiers[1] < 2 else Color(0.35, 0.36, 0.4)
		draw_line(a + Vector2(0, -6), b + Vector2(0, -6), band, 2.5)
		draw_line(a + Vector2(0, 1), b + Vector2(0, 1), band, 2.5)
	if tiers[0] > 0:
		# Spikes: sharpened stakes jutting out at the enemy side, more and longer per tier.
		var out := along.orthogonal()
		if out.y > 0.0:
			out = -out
		var gap: float = 26.0 - tiers[0] * 3.0
		var spikes := maxi(1, int(length() / gap))
		var reach: float = 8.0 + tiers[0] * 2.5
		for i in spikes:
			var p := a.lerp(b, (i + 0.5) / spikes) + Vector2(0, -4)
			var lean := (out + along * (0.35 if i % 2 == 0 else -0.35)).normalized()
			var tip: Vector2 = p + lean * reach + Vector2(0, -reach * 0.5)
			draw_line(p, tip, OUTLINE, 4.0)
			draw_line(p, tip, WOOD.lightened(0.1) if tiers[0] < 3 else IRON, 2.0)
	if not slits.is_empty():
		# Arrow Slits: dark slots with a helmeted archer peeking over each post.
		for i in archers():
			var p := a.lerp(b, (i + 0.5) / archers())
			draw_rect(Rect2(p + Vector2(-1.5, -12), Vector2(3, 8)), OUTLINE)
			draw_circle(p + Vector2(0, -22), 4.0, OUTLINE)
			draw_circle(p + Vector2(0, -22), 3.0, Color(0.96, 0.77, 0.6))
			draw_rect(Rect2(p + Vector2(-4, -27), Vector2(8, 3)), Color(0.55, 0.57, 0.64))
	if tiers[2] >= 1:
		# Engineering: a little work flag at one end.
		var f := a + Vector2(0, -24)
		draw_line(a + Vector2(0, 2), f, OUTLINE, 2.0)
		draw_colored_polygon(PackedVector2Array([f, f + Vector2(9, 3), f + Vector2(0, 6)]), Color(0.95, 0.75, 0.25))
	# Upgrade pips under the middle, one row per path.
	var row := 0
	for p in 3:
		if tiers[p] == 0:
			continue
		for i in tiers[p]:
			draw_rect(Rect2(-(tiers[p] - 1) * 3.0 + i * 6.0 - 2, 12 + row * 5, 4, 4), PATH_COLORS[p])
		row += 1
	if hp < max_hp:
		var w := clampf(length() * 0.5, 30.0, 90.0)
		var top := Vector2(-w / 2, -34)
		draw_rect(Rect2(top, Vector2(w, 4)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(w * hp / max_hp, 4)), Color(0.35, 0.75, 1.0))
