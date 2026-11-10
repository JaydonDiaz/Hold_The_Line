extends Node2D
## Something on the field the enemy is out to destroy, other than the castle: a workshop,
## a watchtower, a shrine. Enemies sent for it (see the rules' enemy_goal) walk round to it
## and hack at it, Skeleton Archers shoot it and Sappers blow up against it; it has health,
## shown in a bar over it once it's hurt, and once destroyed it's rubble.
## Troops walk round it and nothing can be posted on it. Drawn in pixel art like the rest.

signal destroyed(o)

const RADIUS := 26.0
const PX := 3.0
const OUTLINE := Color(0.1, 0.07, 0.1)

var main
var id := ""
var kind := "workshop"     # how it's drawn: "workshop", "watchtower"
var label := "Workshop"    # its name in messages
var max_hp := 400.0
var hp := 400.0
var dead := false
var hit := 0.0
var t := 0.0


## From mission data: {"id", "kind", "name", "at" (on the map as drawn up, 640 wide), "hp"}.
func setup(m, d: Dictionary) -> void:
	main = m
	id = d.get("id", "")
	kind = d.get("kind", "workshop")
	label = d.get("name", kind.capitalize())
	max_hp = float(d.get("hp", 400.0)) * Data_castle_scale(m)
	hp = max_hp
	var at: Vector2 = d["at"]
	position = Vector2(at.x * m.FIELD_W / 640.0, at.y)


## Objectives are sturdier on Easy, like the castle; on Hard they keep their full health
## (the enemy is stronger there already).
static func Data_castle_scale(m) -> float:
	return maxf(1.0, float(m.castle_max) / 450.0) if m.castle_max > 0.0 else 1.0


func is_active() -> bool:
	return not dead


func take_damage(amount: float) -> void:
	if dead or amount <= 0.0 or main.game_over:
		return
	hp -= amount
	hit = 0.2
	if hp <= 0.0:
		hp = 0.0
		dead = true
		main.spawn_burst(position, 40.0, Color(0.7, 0.6, 0.5))
		main.spawn_text(position + Vector2(0, -40), "%s destroyed!" % label, Color(1, 0.4, 0.3))
		main.sfx("boom", 0.8)
		main.paths.invalidate()   # rubble: the way through is open again
		destroyed.emit(self)


func _process(delta: float) -> void:
	t += delta
	hit = maxf(hit - delta, 0.0)
	queue_redraw()


func _b(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(x * PX, y * PX, w * PX, h * PX), c)


func _draw() -> void:
	if dead:
		_draw_rubble()
		return
	var shake := Vector2(sin(t * 60.0) * 2.0, 0.0) if hit > 0.0 else Vector2.ZERO
	draw_set_transform(shake)
	draw_rect(Rect2(-RADIUS, 4, RADIUS * 2.0, 8), Color(0, 0, 0, 0.25))
	match kind:
		"watchtower":
			_draw_watchtower()
		_:
			_draw_workshop()
	draw_set_transform(Vector2.ZERO)
	if hp < max_hp:
		var w := RADIUS * 2.0
		draw_rect(Rect2(-w / 2.0 - 1, -62, w + 2, 6), OUTLINE)
		draw_rect(Rect2(-w / 2.0, -61, w * hp / max_hp, 4), Color(0.4, 0.9, 0.4) if hp > max_hp * 0.4 else Color(1, 0.45, 0.3))
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
	# Roof.
	for row in 5:
		_b(-9 + row, -14 + row, 18 - row * 2, 1, OUTLINE)
	for row in 4:
		_b(-8 + row, -13 + row, 16 - row * 2, 1, Color(0.42, 0.4, 0.46) if row % 2 == 0 else Color(0.36, 0.34, 0.4))
	# Chimney and smoke.
	_b(4, -17, 3, 5, OUTLINE)
	_b(5, -17, 1, 4, Color(0.6, 0.35, 0.25))
	for i in 3:
		var rise := fmod(t * 6.0 + i * 5.0, 15.0)
		_b(5 + sin(t + i) * 1.5, -19 - rise, 2, 1, Color(0.6, 0.58, 0.56, 1.0 - rise / 15.0))
	# Door, with the forge's glow, and the hammer sign.
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


func _draw_rubble() -> void:
	for i in 9:
		var x := -8 + (i * 5) % 16
		var y := -3 + (i * 3) % 5
		_b(x, y, 3, 2, OUTLINE)
		_b(x, y, 2, 1, Color(0.55, 0.52, 0.48))
	for i in 2:
		var rise := fmod(t * 4.0 + i * 7.0, 14.0)
		_b(-2 + i * 4, -4 - rise, 2, 1, Color(0.35, 0.32, 0.32, 1.0 - rise / 14.0))
