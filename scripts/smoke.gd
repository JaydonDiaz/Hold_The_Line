extends Node2D
## An Assassin's Smoke Pellet (a cloud that drifts and thins), or with Ghost Trail a decoy
## in it: a shadow of him where he stood, that the foes chasing him go after till it's
## struck or fades. A decoy is never a fighter: it can't strike, and isn't a troop (nothing
## but the foes lured to it ever looks at it).

const Sprites = preload("res://scripts/sprites.gd")
const RADIUS := 18.0
const STRUCK := 14.0     # a lured foe this close to it (past both their edges) is swinging at it...
const SWING := 0.5       # ...and after this long, it's struck it: gone

var main
var life := 2.0
var total := 2.0
var decoy := false
var look: Texture2D = null   # the Assassin's own figure, for the decoy
var flip := 1.0
var dead := false
var struck_t := 0.0


func is_active() -> bool:
	return decoy and not dead and life > 0.0


func unseen_by(_e, _r := INF) -> bool:
	return false


func sheltered() -> bool:
	return false


func _process(delta: float) -> void:
	life -= delta
	queue_redraw()
	if decoy and not dead:
		var on_it := false
		for e in main.enemies_near(position, RADIUS + 60.0):
			if e.aggro == self and e.position.distance_to(position) <= e.radius + RADIUS + STRUCK:
				on_it = true
				break
		struck_t = struck_t + delta if on_it else maxf(struck_t - delta, 0.0)
		if struck_t >= SWING:
			_vanish()   # (a blow through a shadow)
	if life <= 0.0:
		dead = true
		queue_free()


func take_damage(_amount: float) -> void:
	_vanish()


func _vanish() -> void:
	if dead:
		return
	dead = true
	main.spawn_burst(position, 18.0, Color(0.6, 0.62, 0.62))
	queue_free()


func _draw() -> void:
	var k := clampf(life / total, 0.0, 1.0)
	if not decoy:
		# The cloud: a few grey puffs spreading out and thinning.
		var spread := 1.0 + (1.0 - k) * 0.6
		for i in 7:
			var a := i * TAU / 7.0 + (1.0 - k) * 0.8
			Sprites.disc(self, Vector2.from_angle(a) * 16.0 * spread, 16.0 * spread, Color(0.62, 0.64, 0.64, 0.42 * k))
		Sprites.disc(self, Vector2.ZERO, 20.0 * spread, Color(0.7, 0.72, 0.72, 0.5 * k))
		return
	# The decoy: his own figure, dark and see-through, flickering.
	if look != null:
		var size := look.get_size() * 3.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(flip, 1.0))
		draw_texture_rect(look, Rect2(Vector2(-size.x / 2.0, RADIUS - size.y), size), false, Color(0.35, 0.4, 0.38, (0.55 + 0.15 * sin(life * 18.0)) * minf(k * 2.0, 1.0)))
		draw_set_transform(Vector2.ZERO)
