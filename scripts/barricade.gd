extends "res://scripts/warrior.gd"
## A wall built between two points the player clicks. Enemies walk around it when
## they can (see pathing.gd) and hack at it when they can't. Its health, price and
## upgrade costs scale with its length; its health doesn't (every wall has the same). It blocks your own troops and their shots
## too (see Warrior.shoots_over_walls), until the Energy Wall path lets them through.
## Walls never heal on their own: only a Masonry crew (during waves) or an energy
## wall's recharge mends them. A wall that breaks is gone, unless Master Builders
## put it back up.
## Looks: a wooden palisade, or (by its highest path at tier 3+) a barbed-wire fence,
## a stone wall, a brick wall or a shimmering energy barrier.

const WALL_HALF := 8.0          # half the wall's thickness, for blocking enemies
const UPGRADE_LENGTH := 160.0   # upgrade prices and repair rates in data.gd are for a wall this long
const STAKE_GAP := 9.0
const WOOD := Color(0.6, 0.42, 0.24)
const WOOD_DARK := Color(0.42, 0.28, 0.15)
const STONE := Color(0.62, 0.6, 0.58)
const STONE_DARK := Color(0.42, 0.4, 0.4)
const BRICK := Color(0.72, 0.36, 0.26)
const BRICK_DARK := Color(0.55, 0.26, 0.2)
const MORTAR := Color(0.82, 0.78, 0.7)
const WIRE := Color(0.66, 0.68, 0.72)
const ENERGY := Color(0.4, 0.85, 1.0)
const IRON := Color(0.75, 0.77, 0.82)
const OUTLINE := Color(0.1, 0.07, 0.1)

var half := Vector2(50, 0)   # from the middle of the wall to one end
var thorns := 0.0
var wall_slow := []          # [strength, reach]
var repair := 0.0            # HP repaired per second during waves
var rebuild := 0.0           # Master Builders: seconds to put a broken wall back up (0 = it's gone for good)
var rubble_left := 0.0       # > 0 while it lies in rubble waiting to be rebuilt
var shots_pass := false      # Energy Wall: your troops' shots go through it
var troops_pass := false     # Energy Wall: your troops walk through it
var recharge := []           # Energy Wall: [max HP share per second, seconds unhit before it starts]
var aegis := []              # Energy Wall: [damage cut, reach] for allies near it
var since_hit := 0.0
var slow_tick := 0.0
var stakes := []             # height jitter per stake, so the palisade looks hand-built
var built_length := 0.0      # length when it was built: prices go by this,
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
	rebuild = 0.0
	shots_pass = false
	troops_pass = false
	recharge = []
	aegis = []
	for p in mini(tiers.size(), data["paths"].size()):
		var path_tiers: Array = data["paths"][p]["tiers"]
		for t in tiers[p]:
			var fx: Dictionary = path_tiers[t]["effect"]
			thorns = fx.get("thorns", thorns)
			wall_slow = fx.get("wall_slow", wall_slow)
			repair = fx.get("repair", repair)
			rebuild = fx.get("rebuild", rebuild)
			shots_pass = fx.get("shots_pass", shots_pass)
			troops_pass = fx.get("troops_pass", troops_pass)
			recharge = fx.get("recharge", recharge)
			aegis = fx.get("aegis", aegis)
	if built_length <= 0.0:
		built_length = length()
	damage = 0.0
	cooldown = 1.0
	attack_range = 0.0


## Whether your troops' shots fly through it (pathing keeps a list of the walls that don't).
func lets_shots() -> bool:
	return shots_pass


## Whether your troops walk through it (enemies never can).
func lets_troops() -> bool:
	return troops_pass


## How much bigger (or smaller) than a standard wall this one is, for upgrade
## prices. No upper limit: a wall twice as long costs twice as much to upgrade.
func length_scale() -> float:
	return maxf(stat_length() / UPGRADE_LENGTH, 0.5)


func tier_cost(p: int, t: int) -> int:
	return roundi(super(p, t) * length_scale())


## Standing (not sold, and not lying in rubble).
func is_active() -> bool:
	return not is_queued_for_deletion() and rubble_left <= 0.0


func uses_targeting() -> bool:
	return false


## Distance from the wall's face to an enemy's edge.
func _gap_to(e) -> float:
	return gap_from(e.position) - e.radius


func gap_from(p: Vector2) -> float:
	return Geometry2D.get_closest_point_to_segment(p, seg_a(), seg_b()).distance_to(p) - WALL_HALF


## Aegis Field: how much less damage an ally at p takes from this wall's field.
func aegis_at(p: Vector2) -> float:
	if aegis.is_empty() or not is_active() or gap_from(p) > aegis[1] + RADIUS:
		return 0.0
	return aegis[0]


func take_damage(amount: float) -> void:
	if not is_active():
		return
	main.earn_xp(kind, minf(hp, amount * (1.0 - armor)), "soak")   # holding the line trains it
	hp -= amount * (1.0 - armor)
	hurt = 0.1
	since_hit = 0.0
	if hp > 0.0:
		return
	hp = 0.0
	for i in 3:
		main.spawn_burst(position + half * (i - 1) * 0.7, 18.0, Color(0.6, 0.45, 0.3))
	main.sfx("crumble")
	if rebuild > 0.0:
		# Master Builders: it falls, and the crew sets about putting it back up.
		rubble_left = rebuild
		main.spawn_text(position + Vector2(0, -24), "Collapsed!", Color(1, 0.6, 0.3))
		main.walls_changed()
		return
	# Broken for good.
	main.spawn_text(position + Vector2(0, -24), "Destroyed!", Color(1, 0.3, 0.3))
	if main.selected == self:
		main.selected = null
	queue_free()
	main.walls_changed()


## An enemy hacking at the wall; barbed wire hurts it back.
func struck(attacker, amount: float) -> void:
	take_damage(amount)
	if thorns > 0.0 and is_instance_valid(attacker) and not attacker.dead:
		var was: String = main.credit
		main.credit = kind
		attacker.take_damage(attacker.max_hp * thorns * attacker.cc_mult, false)
		main.credit = was


func _process(delta: float) -> void:
	hurt = maxf(hurt - delta, 0.0)
	anim_t += delta
	queue_redraw()
	if rubble_left > 0.0:
		rubble_left -= delta
		if rubble_left <= 0.0:
			hp = max_hp * 0.5
			main.spawn_text(position + Vector2(0, -24), "Rebuilt!", Color(1, 0.85, 0.4))
			main.sfx("upgrade", 0.8)
			main.spawn_burst(position, 30.0, Color(0.85, 0.6, 0.45))
			main.walls_changed()
		return
	since_hit += delta
	if repair > 0.0 and main.wave_active:
		hp = minf(max_hp, hp + repair * delta)
	if not recharge.is_empty() and since_hit >= recharge[1]:
		hp = minf(max_hp, hp + max_hp * recharge[0] * delta)
	if not wall_slow.is_empty():
		slow_tick -= delta
		if slow_tick <= 0.0:
			slow_tick = 0.25
			for e in main.get_enemies():
				if not e.flying and _gap_to(e) <= wall_slow[1]:
					e.apply_slow(wall_slow[0], 0.4)


func stats_text() -> String:
	var s := "HP %d/%d   Length %s" % [ceili(hp), ceili(max_hp), Data.ft(length())]
	if absf(length() - stat_length()) > 5.0:
		s += " (built %s; prices go by that)" % Data.ft(stat_length())
	s += "   Upgrades %d/%d" % [total_upgrades(), MAX_UPGRADES]
	if armor > 0.0:
		s += "   Armor %d%%" % roundi(armor * 100)
	if thorns > 0.0:
		s += "   Barbs %d%% max HP" % roundi(thorns * 100)
	if not wall_slow.is_empty():
		s += "   Slows %d%% within %s" % [roundi(wall_slow[0] * 100), Data.ft(wall_slow[1])]
	if repair > 0.0:
		s += "   Repairs %.1f HP/s in waves" % repair
	if rebuild > 0.0:
		s += "   Rebuilt %.0fs after it falls" % rebuild
	if troops_pass:
		s += "   Troops and shots pass"
	elif shots_pass:
		s += "   Shots pass"
	if not recharge.is_empty():
		s += "   Recharges %d%%/s" % roundi(recharge[0] * 100)
	if not aegis.is_empty():
		s += "   Allies near: -%d%% dmg" % roundi(aegis[0] * 100)
	if rubble_left > 0.0:
		s += "\nIn rubble: rebuilt in %ds" % ceili(rubble_left)
	return s


# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	var a := -half
	var b := half
	# Shadow on the ground.
	draw_line(a + Vector2(0, 7), b + Vector2(0, 7), Color(0, 0, 0, 0.3), 10.0)
	var tint := Color(1, 0.5, 0.5) if hurt > 0.0 else Color.WHITE
	if rubble_left > 0.0:
		_draw_rubble(a, b)
	else:
		match _look_path():
			0:
				_draw_fence(a, b, tint)
			1:
				_draw_stone(a, b, tint)
			2:
				_draw_brick(a, b, tint)
			3:
				_draw_energy(a, b)
			_:
				_draw_palisade(a, b, tint)
		var look := _look_path()
		if tiers[0] > 0 and look != 0 and look != 3:
			_draw_wire_on_top(a, b)
		if tiers[3] > 0 and look != 3:
			# Arcane lattice: a glowing seam runs along the wall.
			var glow := 0.5 + 0.3 * sin(anim_t * 4.0)
			draw_line(a + Vector2(0, -10), b + Vector2(0, -10), Color(ENERGY, glow), 2.0)
			var runes := maxi(1, int(length() / 30.0))
			for i in runes:
				var p := a.lerp(b, (i + 0.5) / runes) + Vector2(0, -10)
				draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(0.8, 0.97, 1.0, glow))
	if tiers[2] > 0:
		_draw_crew(a, b)
	# Upgrade pips under the middle, one row per path.
	var row := 0
	for p in tiers.size():
		if tiers[p] == 0:
			continue
		for i in tiers[p]:
			draw_rect(Rect2(-(tiers[p] - 1) * 3.0 + i * 6.0 - 2, 12 + row * 5, 4, 4), PATH_COLORS[p])
		row += 1
	if hp < max_hp and rubble_left <= 0.0:
		var w := clampf(length() * 0.5, 30.0, 90.0)
		var top := Vector2(-w / 2, -34)
		draw_rect(Rect2(top, Vector2(w, 4)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(w * hp / max_hp, 4)), Color(0.35, 0.75, 1.0))
	elif rubble_left > 0.0 and rebuild > 0.0:
		# Rebuilding: a bar filling up as the crew works.
		var w := clampf(length() * 0.5, 30.0, 90.0)
		var top := Vector2(-w / 2, -26)
		draw_rect(Rect2(top, Vector2(w, 4)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(w * (1.0 - rubble_left / rebuild), 4)), Color(1.0, 0.8, 0.35))


## A wooden palisade of pointed stakes, lashed together.
func _draw_palisade(a: Vector2, b: Vector2, tint: Color) -> void:
	var count := int(length() / STAKE_GAP) + 1   # stretched walls get more stakes, not gappy ones
	for i in count:
		var p := a.lerp(b, i / maxf(count - 1.0, 1.0))
		var h: float = 20.0 + stakes[i % stakes.size()] + tiers[1] * 1.5
		var body := PackedVector2Array([p + Vector2(-4, 6), p + Vector2(4, 6), p + Vector2(4, -h + 4), p + Vector2(0, -h), p + Vector2(-4, -h + 4)])
		draw_colored_polygon(body, OUTLINE)
		var inner := PackedVector2Array([p + Vector2(-2.5, 4.5), p + Vector2(2.5, 4.5), p + Vector2(2.5, -h + 4.5), p + Vector2(0, -h + 2), p + Vector2(-2.5, -h + 4.5)])
		draw_colored_polygon(inner, (WOOD if i % 2 == 0 else WOOD_DARK.lightened(0.15)) * tint)
	var band := Color(0.3, 0.2, 0.12) if tiers[1] < 2 else Color(0.35, 0.36, 0.4)
	draw_line(a + Vector2(0, -6), b + Vector2(0, -6), band, 2.5)
	draw_line(a + Vector2(0, 1), b + Vector2(0, 1), band, 2.5)


## Barbed Wire tier 3+: a fence of posts strung with barbed wire, and coils of razor
## wire along the foot at tier 4.
func _draw_fence(a: Vector2, b: Vector2, tint: Color) -> void:
	var posts := maxi(2, int(length() / 24.0) + 1)
	for i in posts:
		var p := a.lerp(b, i / (posts - 1.0))
		draw_rect(Rect2(p + Vector2(-2.5, -24), Vector2(5, 30)), OUTLINE)
		draw_rect(Rect2(p + Vector2(-1.5, -23), Vector2(3, 28)), WOOD_DARK.lightened(0.1) * tint)
	var strands: int = 2 + tiers[0]
	for k in strands:
		var y: float = -20.0 + k * (22.0 / (strands - 1))
		_barbed_line(a + Vector2(0, y), b + Vector2(0, y), tint)
	if tiers[0] >= 4:
		var loops := maxi(2, int(length() / 12.0))
		for i in loops:
			var p := a.lerp(b, (i + 0.5) / loops) + Vector2(0, 2)
			draw_arc(p, 7.0, 0, TAU, 12, WIRE * tint, 1.5)


## A strand of barbed wire with little twisted barbs along it.
func _barbed_line(from: Vector2, to: Vector2, tint: Color) -> void:
	draw_line(from, to, OUTLINE, 2.5)
	draw_line(from, to, WIRE * tint, 1.2)
	var barbs := maxi(1, int(from.distance_to(to) / 8.0))
	for i in barbs:
		var p := from.lerp(to, (i + 0.5) / barbs)
		draw_line(p + Vector2(-2, -2), p + Vector2(2, 2), WIRE * tint, 1.2)
		draw_line(p + Vector2(-2, 2), p + Vector2(2, -2), WIRE * tint, 1.2)


## Barbed wire strung along the top of another kind of wall.
func _draw_wire_on_top(a: Vector2, b: Vector2) -> void:
	var top := -26.0 if _look_path() >= 1 else -24.0
	for k in mini(tiers[0], 2):
		_barbed_line(a + Vector2(0, top - k * 4.0), b + Vector2(0, top - k * 4.0), Color.WHITE)


## Fortify tier 3+: a stone wall with mortared blocks and battlements on top.
func _draw_stone(a: Vector2, b: Vector2, tint: Color) -> void:
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


## Masonry tier 3+: courses of red brick in pale mortar, capped with a brick ledge.
func _draw_brick(a: Vector2, b: Vector2, tint: Color) -> void:
	var h := 24.0
	var body := PackedVector2Array([a + Vector2(0, 6), b + Vector2(0, 6), b + Vector2(0, -h), a + Vector2(0, -h)])
	draw_colored_polygon(body, OUTLINE)
	var inner := PackedVector2Array([a + Vector2(1.5, 4.5), b + Vector2(-1.5, 4.5), b + Vector2(-1.5, -h + 1.5), a + Vector2(1.5, -h + 1.5)])
	draw_colored_polygon(inner, MORTAR * tint)
	var course := 5.0
	var rows := int((h + 4.5) / course)
	var bricks := maxi(1, int(length() / 10.0))
	for r in rows:
		var y0 := 4.5 - (r + 1) * course + 1.0
		var shift := 0.5 if r % 2 == 1 else 0.0
		for i in bricks + 1:
			var t0 := clampf((i - shift) / bricks, 0.0, 1.0)
			var t1 := clampf((i + 1 - shift) / bricks, 0.0, 1.0)
			if t1 - t0 <= 0.0:
				continue
			var p0 := a.lerp(b, t0) + Vector2(1.5 if t0 == 0.0 else 0.6, y0)
			var p1 := a.lerp(b, t1) + Vector2(-1.5 if t1 == 1.0 else -0.6, y0)
			var col := (BRICK if (i + r) % 3 != 0 else BRICK_DARK) * tint
			draw_colored_polygon(PackedVector2Array([p0, p1, p1 + Vector2(0, course - 1.2), p0 + Vector2(0, course - 1.2)]), col)
	# A ledge of headers along the top.
	draw_line(a + Vector2(0, -h - 1), b + Vector2(0, -h - 1), OUTLINE, 4.0)
	draw_line(a + Vector2(1, -h - 1), b + Vector2(-1, -h - 1), BRICK.lightened(0.15) * tint, 2.0)


## Energy Wall tier 3+: a shimmering band of force between two glowing emitters.
func _draw_energy(a: Vector2, b: Vector2) -> void:
	var h := 26.0
	var flick := 0.5 + 0.2 * sin(anim_t * 6.0)
	var hit := 1.6 if hurt > 0.0 else 1.0
	var band := PackedVector2Array([a + Vector2(0, 4), b + Vector2(0, 4), b + Vector2(0, -h), a + Vector2(0, -h)])
	draw_colored_polygon(band, Color(ENERGY, 0.22 * flick * hit))
	draw_line(a + Vector2(0, -h), b + Vector2(0, -h), Color(0.85, 0.98, 1.0, 0.9), 2.0)
	draw_line(a + Vector2(0, 4), b + Vector2(0, 4), Color(ENERGY, 0.7), 2.0)
	# Hexagon-ish ripples drifting along it.
	var cells := maxi(1, int(length() / 14.0))
	for i in cells:
		var k := fmod(i / float(cells) + anim_t * 0.15, 1.0)
		var p := a.lerp(b, k) + Vector2(0, -h * 0.5 + sin(anim_t * 3.0 + i) * 4.0)
		draw_arc(p, 4.0, 0, TAU, 6, Color(0.8, 0.97, 1.0, 0.45 * flick), 1.0)
	for end in [a, b]:
		draw_rect(Rect2(end + Vector2(-4, -h - 4), Vector2(8, h + 10)), OUTLINE)
		draw_rect(Rect2(end + Vector2(-2.5, -h - 2.5), Vector2(5, h + 7)), Color(0.35, 0.37, 0.45))
		Sprites.disc(self, end + Vector2(0, -h - 3), 3.5, Color(0.85, 0.98, 1.0, 0.6 + 0.4 * flick))
	if not aegis.is_empty():
		# Aegis Field: a faint dome of protection over the ground in front of it.
		draw_set_transform(Vector2.ZERO, half.angle(), Vector2.ONE)
		draw_rect(Rect2(Vector2(-length() / 2.0, -aegis[1] - RADIUS), Vector2(length(), (aegis[1] + RADIUS) * 2.0)), Color(ENERGY, 0.05))
		draw_set_transform(Vector2.ZERO)


## Lying in rubble: broken stones and splinters while the crew rebuilds it.
func _draw_rubble(a: Vector2, b: Vector2) -> void:
	var lumps := maxi(2, int(length() / 10.0))
	for i in lumps:
		var p := a.lerp(b, (i + 0.5) / lumps) + Vector2(0, 2 + (i % 3))
		var r := 3.0 + float(i * 7 % 4)
		Sprites.disc(self, p, r + 1.0, OUTLINE)
		Sprites.disc(self, p, r, (BRICK_DARK if i % 2 == 0 else STONE_DARK).lightened(0.1))


## Masonry: a construction crew in hard hats working along the wall (hammering away
## while there's anything to mend), with a pile of bricks at tier 3.
func _draw_crew(a: Vector2, b: Vector2) -> void:
	var n: int = 1 if tiers[2] == 1 else (2 if tiers[2] < 4 else 3)
	var working: bool = rubble_left > 0.0 or (hp < max_hp and main.wave_active)
	for i in n:
		var k := (i + 0.5) / n
		var p := a.lerp(b, 0.15 + 0.7 * k) + Vector2(0, 14)
		var swing_up: bool = working and int(anim_t * 5.0 + i * 1.7) % 2 == 0
		# Legs, high-vis vest, head and hard hat.
		draw_rect(Rect2(p + Vector2(-3, -5), Vector2(6, 6)), OUTLINE)
		draw_rect(Rect2(p + Vector2(-2, -5), Vector2(1.5, 5)), Color(0.25, 0.3, 0.5))
		draw_rect(Rect2(p + Vector2(0.5, -5), Vector2(1.5, 5)), Color(0.25, 0.3, 0.5))
		draw_rect(Rect2(p + Vector2(-4, -13), Vector2(8, 9)), OUTLINE)
		draw_rect(Rect2(p + Vector2(-3, -12), Vector2(6, 7)), Color(1.0, 0.55, 0.15))
		draw_rect(Rect2(p + Vector2(-3, -10), Vector2(6, 1.5)), Color(1.0, 0.95, 0.6))
		Sprites.disc(self, p + Vector2(0, -16), 3.2, OUTLINE)
		Sprites.disc(self, p + Vector2(0, -16), 2.4, Color(0.96, 0.77, 0.6))
		draw_rect(Rect2(p + Vector2(-4, -20), Vector2(8, 3)), OUTLINE)
		draw_rect(Rect2(p + Vector2(-3, -19.5), Vector2(6, 2)), Color(1.0, 0.85, 0.2))
		# Hammer, raised or brought down.
		var hand := p + Vector2(4, -10)
		var head := hand + (Vector2(3, -6) if swing_up else Vector2(6, 1))
		draw_line(hand, head, Color(0.45, 0.3, 0.15), 1.5)
		draw_rect(Rect2(head - Vector2(2, 1.5), Vector2(4, 3)), Color(0.5, 0.52, 0.56))
	if tiers[2] >= 3:
		# A stack of bricks and a mortar tub at one end.
		var s := b + Vector2(10, 4)
		for r in 2:
			for c in 2 - r:
				draw_rect(Rect2(s + Vector2(c * 5.0 + r * 2.5, -r * 3.0 - 3.0), Vector2(4.5, 3)), BRICK)
		draw_rect(Rect2(s + Vector2(-2, 0), Vector2(8, 3)), Color(0.45, 0.47, 0.5))
