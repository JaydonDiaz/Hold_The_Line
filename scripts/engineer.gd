extends Node2D
## An Engineer: walks out of the castle gate to a job, hammers at it, then walks back
## in and is gone. Jobs:
##   build   a newly placed emplacement (`site`): it only counts down its build time
##           (Warrior.build_left) while he's there working on it.
##   repair  a stretch of the castle wall (`spot`): while he's hammering, the castle's
##           paid-for repair (main.repair_job) comes in, a share of it from each of
##           the Engineers on the job.

const Sprites = preload("res://scripts/sprites.gd")
const SPEED := 120.0
const SCALE := 3.0
const SWING := 0.32   # seconds per hammer blow

var main
var job := "build"
var site = null        # the emplacement being built
var spot := Vector2.ZERO
var state := "out"     # "out" (walking to the job), "work", "home" (walking back)
var walk := 0.0
var swing_t := 0.0
var flip := 1.0
var route := PackedVector2Array()   # on terrain: waypoints round it to where he's going
var route_goal := Vector2.INF
var route_timer := 0.0
const RADIUS := 12.0


func gate() -> Vector2:
	return main.engineer_gate() if main.has_method("engineer_gate") else Vector2(main.FIELD_W / 2.0, main.CASTLE_Y + 6.0)


func _target() -> Vector2:
	if state == "home":
		return gate()
	if job == "build":
		# Beside the site, on the side nearer the castle (on open ground, on terrain).
		var beside: Vector2 = site.position + Vector2(-26.0 if site.position.x > main.FIELD_W / 2.0 else 26.0, 10.0)
		if main.paths.has_terrain() and main.paths.blocked(beside, RADIUS):
			beside = site.position + Vector2(26.0 if site.position.x > main.FIELD_W / 2.0 else -26.0, 10.0)
		return beside
	return spot


func _process(delta: float) -> void:
	if job == "build" and state != "home" and (not is_instance_valid(site) or site.is_queued_for_deletion() or site.build_left <= 0.0):
		state = "home"   # sold, wrecked or done
	if job == "repair" and state != "home" and (main.repair_job.is_empty() or main.game_over):
		state = "home"
	var to := _target()
	var d := position.distance_to(to)
	if state == "work":
		swing_t += delta
		if job == "build":
			flip = signf(site.position.x - position.x)   # facing the work
		if fmod(swing_t, SWING) < delta:   # a blow lands
			main.spawn_burst(position + Vector2(18.0 * flip, -6), 8.0, Color(1.0, 0.85, 0.4))
			main.sfx("hit", 1.6)
		if job == "build":
			site.build_left = maxf(site.build_left - delta, 0.0)
			if site.build_left <= 0.0:
				site.finish_build()
				state = "home"
		else:
			main.repair_tick(delta)
	elif d > 2.0:
		var step := minf(SPEED * delta, d)
		var dir := position.direction_to(_waypoint(to, delta))
		var next := position + dir * step
		position = next if main.paths.terrain.is_empty() else main.paths.slide(position, next, RADIUS)
		walk += step / 12.0
		if absf(dir.x) > 0.1:
			flip = signf(dir.x)
	elif state == "home":
		queue_free()
		return
	else:
		state = "work"
		swing_t = 0.0
	queue_redraw()


## Where to head for next on the way to `to`: straight there, or on terrain, along a
## troop route round it (worked out again when the goal moves or every second).
func _waypoint(to: Vector2, delta: float) -> Vector2:
	var paths = main.paths
	if paths.terrain.is_empty():
		return to
	route_timer -= delta
	if route_goal.distance_to(to) > 16.0 or route_timer <= 0.0:
		route_goal = to
		route_timer = 0.5
		route = paths.troop_route(position, to) if paths.segment_blocked(position, to, RADIUS) else PackedVector2Array()
	while not route.is_empty() and position.distance_to(route[0]) < 8.0:
		route.remove_at(0)
	if route.is_empty():
		return to   # a clear walk straight there (checked when the route was worked out)
	return route[0]


func _draw() -> void:
	var size := Vector2(Sprites.SIZE, Sprites.SIZE) * SCALE
	var feet := Vector2(0, 16)
	draw_texture_rect(Sprites.shadow(), Rect2(-14, 12, 28, 8), false, Color(0, 0, 0, 0.3))
	var walking := state != "work" and position.distance_to(_target()) > 2.0
	var tex: Texture2D = Sprites.step(Sprites.frames("engineer"), int(walk)) if walking else Sprites.frames("engineer")[0]
	# Body motion, like the troops': a hop and a lean while walking (with dust kicked
	# up behind), a wind-up and a squash with each hammer blow.
	var off := Vector2.ZERO
	var rot := 0.0
	var sc := Vector2.ONE
	if walking:
		var stride := cos(PI * (walk - 0.5))   # 1 on a footfall, -1 with a foot up (Sprites.step)
		off.y -= 1.6 * (1.0 - stride)
		sc = Vector2(1.0 + 0.025 * stride, 1.0 - 0.04 * stride)
		rot = 0.08 * flip + 0.04 * sin(PI * walk * 0.5)
		var k := fmod(walk, 1.0)
		var puff := feet + Vector2(-flip * (6.0 + 8.0 * k), -2)
		Sprites.disc(self, puff, 3.0 + 3.0 * k, Color(0.75, 0.68, 0.55, 0.45 * (1.0 - k)))
	elif state == "work":
		var phase := fmod(swing_t, SWING) / SWING   # 0 = the blow lands, then the next wind-up
		if phase < 0.45:
			tex = Sprites.pose("engineer", "strike")
			var hit := 1.0 - phase / 0.45
			sc = Vector2(1.0 + 0.08 * hit, 1.0 - 0.06 * hit)   # squash on impact
			rot = 0.06 * flip * hit
		else:
			var wind := (phase - 0.45) / 0.55
			rot = -0.12 * flip * wind   # rearing back for the next blow
			sc = Vector2(1.0 - 0.03 * wind, 1.0 + 0.05 * wind)
	else:
		var b := sin(walk * 0.5 + swing_t * 2.4)
		sc = Vector2(1.0 - 0.012 * b, 1.0 + 0.025 * b)   # breathing
	# Tilt and squash pivot on the feet.
	draw_set_transform(feet + off, rot, Vector2(flip * sc.x, sc.y))
	draw_texture_rect(tex, Rect2(-size.x / 2, -size.y, tex.get_width() * SCALE, size.y), false)
	draw_set_transform(Vector2.ZERO)
