extends Node2D
## Something on the field a battle turns on, other than the castle:
##   structures  workshop, watchtower, beacon: the enemy is out to destroy them (health,
##               a bar once hurt, rubble when destroyed); a beacon also charges up ("charge")
##   movers      civilian, wagon: walk a route ("route", "speed") to its end and are
##               "arrived" there; the enemy chases and attacks them on the way. A wagon
##               crawls while an enemy is at it; a villager presses on (running, once hurt).
##               Each villager is one person with its own health, drawn as a sprite
##               ("look": its sprite, recoloured by "variant").
##   zone        ground to take and hold ("radius"): nobody attacks it, it fills with control
##   line        a defensive line (Fighting Retreat): a marker across the field, nothing more
## Enemies sent for a structure or mover (see the rules' enemy_goal) walk round to it and
## hack at it, Skeleton Archers shoot it and Sappers blow up against it. Structures are
## solid to everyone; movers, zones and lines aren't (troops step out of a mover's way).
## Drawn in pixel art like the rest.

signal destroyed(o)
signal reached(o)

const Sprites = preload("res://scripts/sprites.gd")
const PX := 3.0
const OUTLINE := Color(0.1, 0.07, 0.1)
const MOVERS := ["civilian", "wagon"]
const VILLAGERS := ["villager", "villager_woman", "villager_child", "villager_elder"]
# Villagers' clothes and hair, picked per villager (by "variant"): the letter recoloured
# in each sprite (sprites.gd), then the colours to choose from.
const CLOTHES := {"villager": "T", "villager_woman": "D", "villager_child": "T", "villager_elder": "O"}
const CLOTH_COLORS := [Color(0.42, 0.55, 0.3), Color(0.4, 0.45, 0.7), Color(0.7, 0.35, 0.3), Color(0.62, 0.5, 0.32),
	Color(0.55, 0.38, 0.55), Color(0.35, 0.55, 0.55)]
const HAIR_COLORS := [Color(0.45, 0.28, 0.14), Color(0.85, 0.62, 0.3), Color(0.2, 0.14, 0.1), Color(0.6, 0.3, 0.15)]
const SCARF_COLORS := [Color(0.85, 0.35, 0.3), Color(0.9, 0.78, 0.35), Color(0.45, 0.65, 0.45), Color(0.92, 0.9, 0.85)]
const PANIC_TIME := 2.0    # a villager that's hit runs for this long
const PANIC_SPEED := 1.6
const HELD_SPEED := 0.35   # a wagon with an enemy at it crawls on at this share of its speed

var main
var id := ""
var kind := "workshop"     # "workshop", "watchtower", "beacon", "civilian", "wagon", "zone", "line"
var RADIUS := 26.0         # its size, for reaching it (a villager is a person's size)
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
var look := ""                      # a villager's sprite
var variant := 0                    # ...and the colours it wears
var panic := 0.0                    # a villager running from a blow
var face := 1.0                     # which way a mover faces (1: right)
# Zones, charging and lines.
var zone_r := 0.0
var progress := 0.0                 # 0..1: control of a zone, a beacon's charge
var charge := 0.0                   # seconds a beacon takes to charge (0: it doesn't)
var contested := false
var line_y := 0.0
# Tall structures (a watchtower, a beacon) stand over whoever's behind them: their upper
# part is drawn again on a layer over the troops and enemies (clipped to above a troop's
# height, so whoever's in front of the foot still stands in front), and turns see-through
# while someone's back there.
const TALL := ["watchtower", "beacon"]
const ROOF_CUT := -54.0   # px above its foot where the part drawn over everyone starts
var cv: CanvasItem = self  # what the drawing goes on (itself, or its roof)
var roof_mask: Node2D = null
var roof: Node2D = null


class RoofMask extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-160, -420, 320, 420 + ROOF_CUT), Color.WHITE)


class Roof extends Node2D:
	var obj
	func _draw() -> void:
		obj.cv = self
		obj._draw_body()
		obj.cv = obj


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
	if kind == "civilian":
		RADIUS = 12.0
		variant = int(d.get("variant", 0))
		look = d.get("look", VILLAGERS[variant % VILLAGERS.size()])
	zone_r = float(d.get("radius", 0.0))
	charge = float(d.get("charge", 0.0))
	line_y = at.y


## The field's width changed by `k`: the same place across it, and the same road.
func refit(k: float) -> void:
	position.x *= k
	for i in route.size():
		route[i] = Vector2(route[i].x * k, route[i].y)


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


## A Healer's mending (a villager): back up to full at most; returns how much it mended.
func receive_heal(amount: float, _regen: Array = []) -> float:
	if not is_target():
		return 0.0
	var before := hp
	hp = minf(max_hp, hp + amount)
	if hp - before >= 1.0:
		main.spawn_text(position + Vector2(randf_range(-8, 8), -40), "+%d" % roundi(hp - before), Color(0.5, 1.0, 0.5))
	return hp - before


func take_damage(amount: float) -> void:
	if dead or amount <= 0.0 or main.game_over or kind == "zone" or kind == "line" or arrived:
		return
	hp -= amount
	hit = 0.2
	if kind == "civilian":
		panic = PANIC_TIME
	if hp <= 0.0:
		hp = 0.0
		dead = true
		if kind == "civilian":
			main.spawn_burst(position, 18.0, Color(0.8, 0.3, 0.25))
			main.spawn_text(position + Vector2(0, -36), "Lost!", Color(1, 0.4, 0.3))
			main.sfx("hit", 0.7)
			destroyed.emit(self)
			return
		main.spawn_burst(position, 40.0, Color(0.7, 0.6, 0.5))
		main.spawn_text(position + Vector2(0, -40), "%s %s!" % [label, "lost" if is_mover() else "destroyed"], Color(1, 0.4, 0.3))
		main.sfx("boom", 0.8)
		if is_solid() or kind in ["workshop", "watchtower", "beacon"]:
			main.paths.invalidate()   # rubble: the way through is open again
		destroyed.emit(self)


## Its roof, over everyone (main.gd calls this once it's on the field).
func make_roof(layer: Node2D) -> void:
	if not kind in TALL:
		return
	roof_mask = RoofMask.new()
	roof_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	roof = Roof.new()
	roof.obj = self
	roof_mask.add_child(roof)
	layer.add_child(roof_mask)
	roof_mask.position = position
	tree_exiting.connect(func(): if is_instance_valid(roof_mask): roof_mask.queue_free())


## Whether a troop or an enemy is behind it (under its roof, as seen).
func _anyone_behind() -> bool:
	var area := Rect2(position.x - RADIUS - 14.0, position.y + _top() + 10.0, RADIUS * 2.0 + 28.0, -_top() - 34.0)
	for e in main.enemies_near(position + Vector2(0, _top() * 0.5), -_top() * 0.6 + RADIUS):
		if area.has_point(e.position):
			return true
	for w in main.get_warriors():
		if area.has_point(w.position):
			return true
	return false


func _process(delta: float) -> void:
	t += delta
	if roof_mask != null:
		roof_mask.position = position
		roof_mask.visible = not dead
		if not dead and Engine.get_process_frames() % 6 == 0:
			roof_mask.modulate.a = 0.45 if _anyone_behind() else 1.0
		roof.queue_redraw()
	hit = maxf(hit - delta, 0.0)
	panic = maxf(panic - delta, 0.0)
	if is_mover() and not dead and not arrived and speed > 0.0 and main.started and not main.game_over and not main.deploying:
		_walk(delta)
	queue_redraw()


## Along the route at its speed (a wagon crawls while an enemy is at it, so it can't be
## pinned down for good); at the last waypoint it has arrived.
func _walk(delta: float) -> void:
	halted = false
	if kind == "wagon":
		for e in main.enemies_near(position, RADIUS + 40.0):
			if not e.dead and not e.flying and position.distance_to(e.position) <= RADIUS + e.radius + 10.0:
				halted = true
				break
	if leg >= route.size():
		arrived = true
		reached.emit(self)
		return
	var to: Vector2 = route[leg]
	var step := speed * delta * (PANIC_SPEED if panic > 0.0 else 1.0) * (HELD_SPEED if halted else 1.0)
	if absf(to.x - position.x) > 2.0:
		face = signf(to.x - position.x)
	if position.distance_to(to) <= step:
		position = to
		leg += 1
	else:
		var next := position + position.direction_to(to) * step
		position = next if main.paths.terrain.is_empty() else main.paths.slide(position, next, RADIUS * 0.6)


func _b(x: float, y: float, w: float, h: float, c: Color) -> void:
	cv.draw_rect(Rect2(x * PX, y * PX, w * PX, h * PX), c)


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
	if kind == "civilian":
		_draw_villager()
		return
	_draw_body()


## A structure (or a wagon): itself, its health and its charge.
func _draw_body() -> void:
	var shake := Vector2(sin(t * 60.0) * 2.0, 0.0) if hit > 0.0 else Vector2.ZERO
	cv.draw_set_transform(shake)
	cv.draw_texture_rect(Sprites.shadow(), Rect2(-RADIUS * 1.2, 0, RADIUS * 2.4, 14), false, Color(0, 0, 0, 0.3))
	match kind:
		"watchtower":
			_draw_watchtower()
		"beacon":
			_draw_beacon()
		"wagon":
			_draw_wagon()
		_:
			_draw_workshop()
	cv.draw_set_transform(Vector2.ZERO)
	var top := _top()
	if hp < max_hp:
		var w := RADIUS * 2.0
		cv.draw_rect(Rect2(-w / 2.0 - 1, top, w + 2, 6), OUTLINE)
		cv.draw_rect(Rect2(-w / 2.0, top + 1, w * hp / max_hp, 4), Color(0.4, 0.9, 0.4) if hp > max_hp * 0.4 else Color(1, 0.45, 0.3))
	if charge > 0.0:
		var cw := RADIUS * 2.0
		cv.draw_rect(Rect2(-cw / 2.0 - 1, top - 8, cw + 2, 6), OUTLINE)
		cv.draw_rect(Rect2(-cw / 2.0, top - 7, cw * progress, 4), Color(1, 0.8, 0.3))


## Where its health bar goes (above its top).
func _top() -> float:
	match kind:
		"beacon":
			return -124.0
		"watchtower":
			return -168.0
		"wagon":
			return -66.0
	return -62.0


## One villager: their sprite at your troops' size, stepping along (and flinching, and
## running once hurt), a small health bar once hurt.
func _draw_villager() -> void:
	var frames: Array = Sprites.frames(look, _villager_colors(), "v%d" % (variant % 24))
	var size := Vector2(Sprites.SIZE, Sprites.SIZE) * 3.0
	var walking: bool = speed > 0.0 and main.started and not main.deploying and not main.game_over
	var stride := t * (16.0 if panic > 0.0 else 9.0)
	var frame := int(stride / PI) % 2 if walking else 0
	var hop := -absf(sin(stride)) * 2.0 if walking else 0.0
	cv.draw_texture_rect(Sprites.shadow(), Rect2(-13, 4, 26, 8), false, Color(0, 0, 0, 0.3))
	cv.draw_set_transform(Vector2(0, hop), 0.0, Vector2(face, 1.0))
	var tint := Color(3, 3, 3) if hit > 0.1 else Color.WHITE
	cv.draw_texture_rect(frames[frame], Rect2(-size.x / 2.0, 10.0 - size.y, size.x, size.y), false, tint)
	cv.draw_set_transform(Vector2.ZERO)
	if hp < max_hp:
		var top := -34.0 if look == "villager_child" else -40.0
		cv.draw_rect(Rect2(-13, top, 26, 5), OUTLINE)
		cv.draw_rect(Rect2(-12, top + 1, 24 * hp / max_hp, 3), Color(0.4, 0.9, 0.4) if hp > max_hp * 0.4 else Color(1, 0.45, 0.3))


func _villager_colors() -> Dictionary:
	var out := {}
	if CLOTHES.has(look):
		var c: Color = CLOTH_COLORS[variant % CLOTH_COLORS.size()]
		out[CLOTHES[look]] = c
		out[CLOTHES[look].to_lower()] = c.darkened(0.25)
	if look in ["villager", "villager_child"]:
		out["H"] = HAIR_COLORS[(variant / 2) % HAIR_COLORS.size()]
	if look == "villager_woman":
		out["R"] = SCARF_COLORS[(variant / 3) % SCARF_COLORS.size()]
		out["r"] = out["R"].darkened(0.25)
	return out


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


## A timber watchtower: stone footings, two stout legs braced crosswise with a ladder up
## between them, a plank platform, and a lookout hut with a pointed shingle roof and a
## pennant; a brazier glows in its window.
func _draw_watchtower() -> void:
	var wood := Color(0.55, 0.37, 0.22)
	var dark := Color(0.38, 0.25, 0.14)
	var lit := Color(0.68, 0.5, 0.32)
	var stone := Color(0.66, 0.63, 0.58)
	# Footings.
	for x in [-8, 3]:
		_b(x, -3, 6, 4, OUTLINE)
		_b(x + 1, -2, 4, 2, stone)
	# Legs, braced crosswise.
	_b(-7, -25, 4, 23, OUTLINE)
	_b(-6, -24, 2, 22, wood)
	_b(4, -25, 4, 23, OUTLINE)
	_b(5, -24, 2, 22, dark)
	for i in 8:
		_b(-4 + i, -20 + i, 1, 1, dark)       # one brace down to the right...
		_b(3 - i, -12 + i, 1, 1, dark)        # ...the other back down to the left
	# The ladder up the middle.
	_b(-2, -24, 1, 22, OUTLINE)
	_b(2, -24, 1, 22, OUTLINE)
	for y in range(-22, -2, 3):
		_b(-1, y, 3, 1, lit)
	# The platform.
	_b(-10, -28, 20, 4, OUTLINE)
	_b(-9, -27, 18, 2, wood)
	_b(-9, -27, 18, 1, lit)
	# The lookout hut, its window lit by a brazier inside.
	_b(-7, -37, 14, 10, OUTLINE)
	_b(-6, -36, 12, 8, wood)
	for x in [-4, 0, 4]:
		_b(x, -36, 1, 8, dark)
	_b(-2, -34, 4, 4, OUTLINE)
	var glow := 0.75 + 0.25 * sin(t * 7.0)
	_b(-1, -33, 2, 2, Color(1.0, 0.6, 0.2) * glow)
	# The roof, in steps up to a point, and a pennant on top.
	for row in 5:
		_b(-9 + row * 2, -38 - row * 2, 18 - row * 4, 2, OUTLINE)
		_b(-8 + row * 2, -38 - row * 2, 16 - row * 4, 1, Color(0.42, 0.3, 0.3) if row % 2 == 0 else Color(0.5, 0.36, 0.34))
	_b(0, -52, 1, 6, OUTLINE)
	_b(1, -52 + floorf(sin(t * 5.0) * 0.6), 4, 2, Color(0.3, 0.45, 0.85))


## A beacon tower: a stepped stone plinth and a tower of dressed stone (a door, a slit
## window), a ledge, and an iron fire-basket of stacked logs on top: cold and smoking a
## little at first, then burning higher the more it's charged, until it blazes.
func _draw_beacon() -> void:
	var stone := Color(0.72, 0.68, 0.62)
	var shade := Color(0.55, 0.52, 0.48)
	var lit := Color(0.84, 0.81, 0.75)
	var mortar := Color(0.46, 0.43, 0.4)
	var iron := Color(0.27, 0.26, 0.3)
	var wood := Color(0.48, 0.3, 0.16)
	# The plinth: two broad steps.
	_b(-11, -4, 22, 5, OUTLINE)
	_b(-10, -3, 20, 3, shade)
	_b(-10, -3, 20, 1, stone)
	_b(-9, -7, 18, 4, OUTLINE)
	_b(-8, -6, 16, 3, stone)
	_b(-8, -6, 16, 1, lit)
	# The tower: courses of stone, lit on the left and shaded on the right.
	_b(-7, -29, 14, 23, OUTLINE)
	_b(-6, -28, 12, 22, stone)
	_b(3, -28, 3, 22, shade)
	_b(-6, -28, 1, 22, lit)
	for i in 7:
		var y := -25 + i * 3
		_b(-6, y, 12, 1, mortar)
		var off := 0 if i % 2 == 0 else 3
		for x in [-5 + off, 1 + off]:
			if x < 6:
				_b(x, y - 2, 1, 2, mortar)
	# The door at its foot and a slit window up top.
	_b(-2, -12, 4, 6, OUTLINE)
	_b(-1, -11, 2, 5, Color(0.16, 0.11, 0.08))
	_b(-1, -24, 2, 4, OUTLINE)
	# The ledge it's crowned with.
	_b(-9, -32, 18, 4, OUTLINE)
	_b(-8, -31, 16, 1, lit)
	_b(-8, -30, 16, 1, shade)
	# Logs stacked in the iron basket.
	_b(-7, -37, 14, 5, OUTLINE)
	_b(-6, -36, 12, 4, wood)
	for x in [-5, -1, 3]:
		_b(x, -36, 2, 1, Color(0.7, 0.52, 0.32))   # cut ends
	# The fire: bigger with the charge, and a blaze at the end.
	var flick := floorf(1.5 * sin(t * 9.0)) + floorf(sin(t * 13.0 + 1.0))
	var h: float = 1.0 + progress * 13.0 + flick if progress > 0.01 else 0.0
	if h > 0.0:
		_b(-6, -36 - h, 12, h, Color(0.85, 0.22, 0.08))
		_b(-5, -36 - h * 0.8, 10, h * 0.8, Color(1.0, 0.5, 0.12))
		_b(-3, -36 - h * 0.55, 6, h * 0.55, Color(1.0, 0.85, 0.35))
		_b(-1, -36 - h * 0.3, 2, h * 0.3, Color(1.0, 1.0, 0.8))
		_b(-4 + floorf(sin(t * 7.0) * 2.0), -37 - h, 2, 2, Color(1.0, 0.5, 0.12))
		_b(2 + floorf(sin(t * 5.0 + 2.0) * 2.0), -37 - h * 0.85, 2, 2, Color(1.0, 0.5, 0.12))
		if progress > 0.3:
			for i in 3:
				var rise := fmod(t * 9.0 + i * 5.0, 14.0)
				_b(-3 + i * 3 + sin(t * 3.0 + i) * 2.0, -38 - h - rise, 1, 1, Color(1.0, 0.8, 0.3, 1.0 - rise / 14.0))
		cv.draw_circle(Vector2(0, (-36 - h * 0.5) * PX), 20.0 + progress * 40.0, Color(1, 0.7, 0.3, 0.06 + progress * 0.1))
	else:
		for i in 2:
			var rise := fmod(t * 4.0 + i * 7.0, 14.0)
			_b(-1 + i * 2 + sin(t + i) * 1.5, -38 - rise, 2, 1, Color(0.6, 0.58, 0.56, 0.8 - rise / 18.0))
	# The basket's iron bands and corner posts, over the logs and the fire's foot.
	_b(-8, -38, 2, 7, OUTLINE)
	_b(6, -38, 2, 7, OUTLINE)
	_b(-7, -37, 14, 1, iron)
	_b(-7, -33, 14, 1, iron)
	for x in [-4, 0, 3]:
		_b(x, -36, 1, 3, iron)
	if contested:
		# Under attack: the keeper's horn-red warning pennant shakes.
		_b(8, -42, 1, 10, OUTLINE)
		_b(9, -42 + floorf(sin(t * 20.0)), 4, 2, Color(0.9, 0.2, 0.15))


## A covered supply wagon: a canvas tilt on hoops over a plank bed, two spoked wheels
## turning as it rolls, drawn by an ox that plods along (faces the way it's going).
func _draw_wagon() -> void:
	cv.draw_set_transform(Vector2(sin(t * 60.0) * 2.0 if hit > 0.0 else 0.0, 0.0), 0.0, Vector2(face, 1.0))
	var canvas := Color(0.9, 0.86, 0.74)
	var fold := Color(0.74, 0.7, 0.6)
	var wood := Color(0.52, 0.34, 0.18)
	var dark_wood := Color(0.36, 0.23, 0.12)
	var ox := Color(0.55, 0.38, 0.24)
	var moving: bool = not halted and main.started and not main.deploying and not main.game_over and not arrived
	# The canvas tilt, rounded at the top, with its hoops.
	_b(-13, -17, 16, 1, OUTLINE)
	_b(-14, -16, 18, 9, OUTLINE)
	_b(-12, -16, 14, 1, canvas)
	_b(-13, -15, 16, 8, canvas)
	for x in [-10, -6, -2]:
		_b(x, -15, 1, 8, fold)
	_b(-13, -8, 16, 1, fold)
	# The bed: planks, and a crate at the back.
	_b(-15, -8, 21, 4, OUTLINE)
	_b(-14, -7, 19, 2, wood)
	_b(-14, -5, 19, 1, dark_wood)
	_b(-16, -11, 3, 4, OUTLINE)
	_b(-15, -10, 2, 2, Color(0.7, 0.55, 0.3))
	# The shafts out to the ox.
	_b(5, -6, 5, 1, dark_wood)
	# The ox: a body, a head low with horns, legs in step.
	var step := int(t * 6.0) % 2 if moving else 0
	_b(8, -11, 9, 7, OUTLINE)
	_b(9, -10, 7, 5, ox)
	_b(9, -10, 7, 1, ox.lightened(0.15))
	_b(16, -12, 4, 6, OUTLINE)
	_b(17, -11, 2, 4, ox)
	_b(18, -8, 2, 2, Color(0.85, 0.7, 0.6))   # its muzzle
	_b(16, -13, 1, 1, Color(0.92, 0.88, 0.75))
	_b(19, -13, 1, 1, Color(0.92, 0.88, 0.75))
	_b(18, -11, 1, 1, OUTLINE)                # its eye
	for i in 2:
		var lx := 9 + i * 5
		var lift := 1 if (i + step) % 2 == 0 and moving else 0
		_b(lx, -5, 2, 4 - lift, OUTLINE)
		_b(lx + 1, -5, 1, 3 - lift, ox.darkened(0.25))
	_b(7, -10, 1, 3, OUTLINE)   # its tail
	# The wheels (drawn round, the spokes turning while it rolls).
	for wx in [-11.0, 1.0]:
		var c := Vector2(wx * PX, -2.0 * PX)
		cv.draw_circle(c, 11.0, OUTLINE)
		cv.draw_circle(c, 8.5, wood)
		cv.draw_circle(c, 6.0, OUTLINE)
		var spin: float = (t * 3.0 if moving else 0.0)
		for k in 4:
			var a := spin + k * PI / 4.0
			cv.draw_line(c - Vector2.from_angle(a) * 8.0, c + Vector2.from_angle(a) * 8.0, wood, 2.0)
		cv.draw_circle(c, 2.5, dark_wood)
	cv.draw_set_transform(Vector2.ZERO)


## Ground to take: the ruins of an old fort, a broken ring of stone walls round a yard,
## a flagpole in the middle flying whoever's banner holds it, and the ring of control
## filling on the ground.
func _draw_zone() -> void:
	var col := Color(0.45, 0.75, 1.0) if not contested else Color(1, 0.6, 0.35)
	cv.draw_circle(Vector2.ZERO, zone_r, Color(0.45, 0.38, 0.28, 0.35), true, -1.0, true)   # the trodden yard
	cv.draw_circle(Vector2.ZERO, zone_r, Color(col, 0.05 + progress * 0.12), true, -1.0, true)
	draw_arc(Vector2.ZERO, zone_r - 8.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, Color(1, 0.85, 0.3, 0.9), 5.0, true)
	# The broken walls: stone blocks along the ring, fallen in places (gaps to walk through).
	var stone := Color(0.66, 0.63, 0.58)
	var n := 28
	for i in n:
		if i % 7 in [2, 3]:
			continue   # a breach
		var a := i * TAU / n
		var p := Vector2.from_angle(a) * (zone_r + 2.0)
		var tall := 3 + (i * 5) % 3
		var r := Rect2(p + Vector2(-8, -tall * 3.0), Vector2(16, tall * 3.0 + 3.0))
		cv.draw_rect(r.grow(2.0), OUTLINE)
		cv.draw_rect(r, stone if i % 2 == 0 else stone.darkened(0.08))
		cv.draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), stone.lightened(0.15))
		cv.draw_rect(Rect2(r.position + Vector2(7, 3), Vector2(1, r.size.y - 3)), stone.darkened(0.25))
	for i in n:
		if i % 7 == 2:
			var p := Vector2.from_angle(i * TAU / n) * (zone_r + 6.0)   # rubble in the breach
			_b(p.x / PX - 2, p.y / PX, 2, 1, stone.darkened(0.2))
			_b(p.x / PX + 1, p.y / PX - 1, 2, 2, stone.darkened(0.1))
	# The flagpole: grey while nobody holds it, blue once it's yours, red while they're taking it back.
	var flag := Color(0.6, 0.6, 0.6)
	if progress >= 1.0 or (progress > 0.0 and not contested):
		flag = Color(0.3, 0.45, 0.85)
	if contested:
		flag = Color(0.85, 0.25, 0.2)
	_b(-1, -16, 2, 17, OUTLINE)
	_b(0, -15, 1, 15, Color(0.55, 0.4, 0.25))
	var wave := floorf(sin(t * 6.0))
	_b(1, -16, 7, 5, OUTLINE)
	_b(1, -15 + wave * 0.0, 6, 3, flag)
	_b(5, -14 + wave, 2, 1, flag.darkened(0.2))
	_b(-2, 0, 4, 1, OUTLINE)


## A defensive line across the field: a row of stakes with its name at the side.
func _draw_line() -> void:
	var w: float = main.FIELD_W
	for x in range(8, int(w), 20):
		cv.draw_rect(Rect2(x - position.x, -6, 3, 8), Color(0.5, 0.34, 0.2, 0.8))
		cv.draw_rect(Rect2(x - position.x, -8, 3, 2), Color(0.85, 0.75, 0.4, 0.9))
	cv.draw_string(ThemeDB.fallback_font, Vector2(8 - position.x, -12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.95, 0.8, 0.9))


func _draw_rubble() -> void:
	for i in 9:
		var x := -8 + (i * 5) % 16
		var y := -3 + (i * 3) % 5
		_b(x, y, 3, 2, OUTLINE)
		_b(x, y, 2, 1, Color(0.55, 0.52, 0.48))
	for i in 2:
		var rise := fmod(t * 4.0 + i * 7.0, 14.0)
		_b(-2 + i * 4, -4 - rise, 2, 1, Color(0.35, 0.32, 0.32, 1.0 - rise / 14.0))
