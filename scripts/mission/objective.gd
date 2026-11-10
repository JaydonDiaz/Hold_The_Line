extends Node2D
## Something on the field a battle turns on, other than the castle:
##   structures  workshop, watchtower, beacon: the enemy is out to destroy them (health,
##               a bar once hurt, rubble when destroyed); a beacon also charges up ("charge")
##   movers      civilians, wagon: walk a route ("route", "speed") to its end and are
##               "arrived" there; the enemy chases and attacks them on the way. A wagon
##               stops while an enemy is at it; civilians press on.
##   zone        ground to take and hold ("radius"): nobody attacks it, it fills with control
##   line        a defensive line (Fighting Retreat): a marker across the field, nothing more
## Enemies sent for a structure or mover (see the rules' enemy_goal) walk round to it and
## hack at it, Skeleton Archers shoot it and Sappers blow up against it. Structures are
## solid to everyone; movers, zones and lines aren't (troops step out of a mover's way).
## Drawn in pixel art like the rest.

signal destroyed(o)
signal reached(o)

const RADIUS := 26.0
const PX := 3.0
const OUTLINE := Color(0.1, 0.07, 0.1)
const MOVERS := ["civilians", "wagon"]

var main
var id := ""
var kind := "workshop"     # "workshop", "watchtower", "beacon", "civilians", "wagon", "zone", "line"
var label := "Workshop"    # its name in messages
var max_hp := 400.0
var hp := 400.0
var dead := false
var hit := 0.0
var t := 0.0
# Movers.
var route := PackedVector2Array()   # waypoints, in field coordinates
var leg := 0                        # the waypoint it's walking to
var speed := 0.0
var arrived := false
var halted := false                 # a wagon held up by an enemy at it
var size := 1                       # people in a civilian group
# Zones, charging and lines.
var zone_r := 0.0
var progress := 0.0                 # 0..1: control of a zone, a beacon's charge
var charge := 0.0                   # seconds a beacon takes to charge (0: it doesn't)
var contested := false
var line_y := 0.0


## From mission data: {"id", "kind", "name", "at" (as drawn up, 640 wide), "hp", and for
## movers "route" (waypoints) and "speed"; zones "radius"; beacons "charge"}.
func setup(m, d: Dictionary) -> void:
	main = m
	id = d.get("id", "")
	kind = d.get("kind", "workshop")
	label = d.get("name", kind.capitalize())
	max_hp = float(d.get("hp", 400.0)) * Data_castle_scale(m)
	hp = max_hp
	var k: float = m.FIELD_W / 640.0
	var at: Vector2 = d.get("at", Vector2.ZERO)
	position = Vector2(at.x * k, at.y)
	for p in d.get("route", []):
		route.append(Vector2(p.x * k, p.y))
	speed = float(d.get("speed", 0.0))
	size = int(d.get("size", 1))
	zone_r = float(d.get("radius", 0.0))
	charge = float(d.get("charge", 0.0))
	line_y = at.y


## Objectives are sturdier on Easy, like the castle; on Hard they keep their full health
## (the enemy is stronger there already).
static func Data_castle_scale(m) -> float:
	return maxf(1.0, float(m.castle_max) / 450.0) if m.castle_max > 0.0 else 1.0


func is_mover() -> bool:
	return kind in MOVERS


## Solid to enemies and troops, and can't be built on: a standing structure.
func is_solid() -> bool:
	return not dead and not is_mover() and kind != "zone" and kind != "line"


## Something the enemy can be sent to attack.
func is_target() -> bool:
	return not dead and not arrived and kind != "line"


func is_active() -> bool:
	return not dead


func take_damage(amount: float) -> void:
	if dead or amount <= 0.0 or main.game_over or kind == "zone" or kind == "line" or arrived:
		return
	hp -= amount
	hit = 0.2
	if hp <= 0.0:
		hp = 0.0
		dead = true
		main.spawn_burst(position, 40.0, Color(0.7, 0.6, 0.5))
		main.spawn_text(position + Vector2(0, -40), "%s %s!" % [label, "lost" if is_mover() else "destroyed"], Color(1, 0.4, 0.3))
		main.sfx("boom", 0.8)
		if is_solid() or kind in ["workshop", "watchtower", "beacon"]:
			main.paths.invalidate()   # rubble: the way through is open again
		destroyed.emit(self)


func _process(delta: float) -> void:
	t += delta
	hit = maxf(hit - delta, 0.0)
	if is_mover() and not dead and not arrived and speed > 0.0 and main.started and not main.game_over and not main.deploying:
		_walk(delta)
	queue_redraw()


## Along the route at its speed (a wagon waits while an enemy is at it); at the last
## waypoint it has arrived.
func _walk(delta: float) -> void:
	halted = false
	if kind == "wagon":
		for e in main.enemies_near(position, RADIUS + 40.0):
			if not e.dead and not e.flying and position.distance_to(e.position) <= RADIUS + e.radius + 10.0:
				halted = true
				return
	if leg >= route.size():
		arrived = true
		reached.emit(self)
		return
	var to: Vector2 = route[leg]
	var step := speed * delta
	if position.distance_to(to) <= step:
		position = to
		leg += 1
	else:
		var next := position + position.direction_to(to) * step
		position = next if main.paths.terrain.is_empty() else main.paths.slide(position, next, RADIUS * 0.6)


func _b(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(x * PX, y * PX, w * PX, h * PX), c)


func _draw() -> void:
	if kind == "zone":
		_draw_zone()
		return
	if kind == "line":
		_draw_line()
		return
	if dead:
		if not is_mover():
			_draw_rubble()
		return
	if arrived and is_mover():
		return
	var shake := Vector2(sin(t * 60.0) * 2.0, 0.0) if hit > 0.0 else Vector2.ZERO
	draw_set_transform(shake, 0.0, Vector2(1.4, 1.4) if is_mover() else Vector2.ONE)   # (a wagon and its people stand as tall as your troops)
	draw_rect(Rect2(-RADIUS, 4, RADIUS * 2.0, 8), Color(0, 0, 0, 0.25))
	match kind:
		"watchtower":
			_draw_watchtower()
		"beacon":
			_draw_beacon()
		"civilians":
			_draw_civilians()
		"wagon":
			_draw_wagon()
		_:
			_draw_workshop()
	draw_set_transform(Vector2.ZERO)
	if hp < max_hp:
		var w := RADIUS * 2.0
		draw_rect(Rect2(-w / 2.0 - 1, -62, w + 2, 6), OUTLINE)
		draw_rect(Rect2(-w / 2.0, -61, w * hp / max_hp, 4), Color(0.4, 0.9, 0.4) if hp > max_hp * 0.4 else Color(1, 0.45, 0.3))
	if charge > 0.0:
		var cw := RADIUS * 2.0
		draw_rect(Rect2(-cw / 2.0 - 1, -70, cw + 2, 6), OUTLINE)
		draw_rect(Rect2(-cw / 2.0, -69, cw * progress, 4), Color(1, 0.8, 0.3))
	if hit > 0.0:
		draw_rect(Rect2(-RADIUS, -50, RADIUS * 2.0, 56), Color(1, 1, 1, hit * 1.5))


## A mason's workshop: stone walls, a timber-and-slate roof, a forge chimney with smoke,
## and the guild's hammer sign over the door.
func _draw_workshop() -> void:
	var stone := Color(0.72, 0.68, 0.62)
	_b(-8, -9, 16, 11, OUTLINE)
	_b(-7, -8, 14, 9, stone)
	for row in 3:
		for col in 4:
			_b(-7 + col * 4 + (row % 2) * 2, -7 + row * 3, 1, 1, stone.darkened(0.15))
	for row in 5:
		_b(-9 + row, -14 + row, 18 - row * 2, 1, OUTLINE)
	for row in 4:
		_b(-8 + row, -13 + row, 16 - row * 2, 1, Color(0.42, 0.4, 0.46) if row % 2 == 0 else Color(0.36, 0.34, 0.4))
	_b(4, -17, 3, 5, OUTLINE)
	_b(5, -17, 1, 4, Color(0.6, 0.35, 0.25))
	for i in 3:
		var rise := fmod(t * 6.0 + i * 5.0, 15.0)
		_b(5 + sin(t + i) * 1.5, -19 - rise, 2, 1, Color(0.6, 0.58, 0.56, 1.0 - rise / 15.0))
	_b(-2, -4, 4, 5, OUTLINE)
	var glow := 0.75 + 0.25 * sin(t * 7.0)
	_b(-1, -3, 2, 4, Color(1.0, 0.55, 0.2) * glow)
	_b(-6, -6, 3, 2, Color(0.85, 0.62, 0.32))
	_b(-5, -4, 1, 2, Color(0.45, 0.3, 0.2))


## A timber watchtower on stone footings, a lookout's brazier on top.
func _draw_watchtower() -> void:
	_b(-5, -20, 10, 21, OUTLINE)
	_b(-4, -19, 8, 19, Color(0.5, 0.35, 0.22))
	for y in range(-17, 0, 4):
		_b(-4, y, 8, 1, Color(0.38, 0.26, 0.16))
	_b(-6, -22, 12, 3, OUTLINE)
	_b(-5, -21, 10, 1, Color(0.6, 0.45, 0.3))
	var f := floorf(1.5 + 1.5 * sin(t * 9.0))
	_b(-1, -24 - f, 2, 2 + f, Color(1.0, 0.55, 0.15))


## A beacon tower: a stone column with an iron cage on top, its fire growing as it charges.
func _draw_beacon() -> void:
	_b(-4, -18, 8, 19, OUTLINE)
	_b(-3, -17, 6, 17, Color(0.7, 0.66, 0.6))
	for y in range(-15, 0, 4):
		_b(-3, y, 6, 1, Color(0.58, 0.55, 0.5))
	_b(-6, -21, 12, 3, OUTLINE)
	_b(-5, -20, 10, 1, Color(0.35, 0.33, 0.33))
	var fire: float = 1.0 + progress * 6.0 + floorf(1.5 * sin(t * 9.0))
	_b(-3, -21 - fire, 6, fire, Color(1.0, 0.5, 0.12))
	_b(-1, -21 - fire * 0.7, 2, fire * 0.7, Color(1.0, 0.9, 0.45))
	if progress > 0.05:
		draw_circle(Vector2(0, -66 - fire * PX * 0.5), 18.0 + progress * 30.0, Color(1, 0.75, 0.3, 0.08 + progress * 0.08))


## A family on the road: three villagers with a bundle, walking (a bob in step).
func _draw_civilians() -> void:
	var colors := [Color(0.75, 0.45, 0.35), Color(0.45, 0.55, 0.75), Color(0.7, 0.65, 0.4)]
	for i in 3:
		var x := -7 + i * 5
		var bob := 1 if int(t * 6.0 + i) % 2 == 0 and not halted else 0
		var tall := 8 if i != 2 else 6
		_b(x, -tall - bob, 4, tall, OUTLINE)
		_b(x + 1, -tall + 3 - bob, 2, tall - 4, colors[i])
		_b(x + 1, -tall + 1 - bob, 2, 2, Color(0.95, 0.8, 0.65))
	_b(4, -5, 3, 3, OUTLINE)
	_b(4, -5, 2, 2, Color(0.6, 0.48, 0.3))
	if size > 1:
		draw_string(ThemeDB.fallback_font, Vector2(14, -6), str(size), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.95, 0.85))


## A covered supply wagon on two wheels, drawn by an ox.
func _draw_wagon() -> void:
	_b(-8, -9, 13, 7, OUTLINE)
	_b(-7, -8, 11, 5, Color(0.88, 0.84, 0.72))
	_b(-7, -4, 11, 2, Color(0.5, 0.34, 0.2))
	for wx in [-6, 1]:
		var spin := int(t * 8.0) % 2 if not halted else 0
		_b(wx, -2, 3, 3, OUTLINE)
		_b(wx + 1, -1, 1, 1, Color(0.6, 0.45, 0.3) if spin == 0 else Color(0.4, 0.3, 0.2))
	_b(6, -6, 5, 5, OUTLINE)
	_b(7, -5, 3, 3, Color(0.55, 0.42, 0.3))
	_b(10, -7, 2, 2, Color(0.9, 0.88, 0.8))


## Ground to take: a ring on the ground, banners at its edge, filling with control.
func _draw_zone() -> void:
	var col := Color(0.45, 0.75, 1.0) if not contested else Color(1, 0.6, 0.35)
	draw_circle(Vector2.ZERO, zone_r, Color(col, 0.08 + progress * 0.14), true, -1.0, true)
	var n := 40
	for i in n:
		if i % 2 == 0:
			draw_arc(Vector2.ZERO, zone_r, i * TAU / n, (i + 1) * TAU / n, 4, Color(col, 0.8), 3.0, true)
	draw_arc(Vector2.ZERO, zone_r - 8.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, Color(1, 0.85, 0.3, 0.9), 5.0, true)
	_b(-1, -10, 1, 10, OUTLINE)
	_b(0, -10, 4, 3, Color(0.3, 0.45, 0.85) if progress >= 1.0 else Color(0.6, 0.6, 0.6))


## A defensive line across the field: a row of stakes with its name at the side.
func _draw_line() -> void:
	var w: float = main.FIELD_W
	for x in range(8, int(w), 20):
		draw_rect(Rect2(x - position.x, -6, 3, 8), Color(0.5, 0.34, 0.2, 0.8))
		draw_rect(Rect2(x - position.x, -8, 3, 2), Color(0.85, 0.75, 0.4, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(8 - position.x, -12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.95, 0.8, 0.9))


func _draw_rubble() -> void:
	for i in 9:
		var x := -8 + (i * 5) % 16
		var y := -3 + (i * 3) % 5
		_b(x, y, 3, 2, OUTLINE)
		_b(x, y, 2, 1, Color(0.55, 0.52, 0.48))
	for i in 2:
		var rise := fmod(t * 4.0 + i * 7.0, 14.0)
		_b(-2 + i * 4, -4 - rise, 2, 1, Color(0.35, 0.32, 0.32, 1.0 - rise / 14.0))
