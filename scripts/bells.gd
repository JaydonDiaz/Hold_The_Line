extends Node2D
## The High Monastery's temple bells (Phase 4). A mission with "bells" has bell towers on
## the field: the mission's own objectives of kind "bell" (Trial of the Gate: towers to
## keep standing), and/or towers standing on their own ("bells": {"at": [...]}, Bells of
## Dawn). A bell can be rung:
##   - when it's yours: a bell objective while it stands; a free-standing tower while one
##     of your troops is within HOLD of it;
##   - once a wave (it's ready again when the next wave starts).
## Ringing it (click it, or K for every ready bell with enemies round it) stuns every enemy
## within its reach for a while (a boss for less), with a shockwave of gold. A ready bell
## glows and says so; a rung one is grey till the next wave.

const Data = preload("res://scripts/data.gd")
const OUTLINE := Color(0.1, 0.07, 0.1)
const HOLD := 100.0          # a free-standing tower is yours with a troop this close
const REACH := 150.0         # how far a bell's ringing carries
const STUN := 2.5            # seconds it stuns for (a boss for half)
const PICK := 34.0           # how near a click has to be

var main
var spec := {}
var towers: Array = []       # {"at": Vector2 (drawn up 640 wide), "obj": the objective or null, "rung_wave": the wave it was last rung in, "flash": 0..1}
var t := 0.0


func setup(m, mission: Dictionary) -> void:
	main = m
	spec = mission.get("bells", {})
	towers.clear()
	if spec.is_empty():
		visible = false
		return
	for p in spec.get("at", []):
		towers.append({"at": p, "obj": null, "rung_wave": -1, "flash": 0.0})
	visible = true


## Bell objectives can only be gathered once the rules have made them (after setup).
func _gather() -> void:
	if spec.is_empty() or towers.any(func(b): return b["obj"] != null):
		return
	for o in main.rules.objectives():
		if o.kind == "bell":
			towers.append({"at": Vector2.INF, "obj": o, "rung_wave": -1, "flash": 0.0})


func active() -> bool:
	return not spec.is_empty()


## Where tower b stands on the field now.
func pos(b: Dictionary) -> Vector2:
	if b["obj"] != null:
		return b["obj"].position
	var at: Vector2 = b["at"]
	return Vector2(at.x * main.FIELD_W / 640.0, at.y)


## Whether tower b is yours to ring (standing, or held by a troop).
func held(b: Dictionary) -> bool:
	if b["obj"] != null:
		return is_instance_valid(b["obj"]) and not b["obj"].dead
	var p := pos(b)
	for w in main.warriors_near(p, HOLD):
		if w.is_active() and w.position.distance_to(p) <= HOLD:
			return true
	return false


## Whether tower b can be rung right now.
func ready(b: Dictionary) -> bool:
	return main.wave_active and held(b) and int(b["rung_wave"]) != main.wave


## Rings tower b: every enemy in reach stunned (a boss for half as long).
func ring(b: Dictionary) -> bool:
	if not ready(b):
		return false
	b["rung_wave"] = main.wave
	b["flash"] = 1.0
	var p := pos(b)
	var stunned := 0
	for e in main.enemies_near(p, REACH + 40.0):
		if e.dead or e.position.distance_to(p) > REACH + e.radius:
			continue
		e.apply_stun(STUN * (0.5 if e.boss else 1.0))
		stunned += 1
	main.spawn_burst(p + Vector2(0, -20), REACH, Color(1.0, 0.85, 0.35))
	main.spawn_text(p + Vector2(0, -90), "BONG!  %d stunned" % stunned, Color(1.0, 0.85, 0.35))
	main.sfx("horn")
	return true


## A click on the field: a ready bell under it is rung (returns whether one was).
func click(p: Vector2) -> bool:
	_gather()
	for b in towers:
		if pos(b).distance_to(p + Vector2(0, 30)) <= PICK + 20.0 and pos(b).distance_to(p) <= PICK * 2.0:
			if ring(b):
				return true
			main.hud.show_message("That bell's been rung this wave" if held(b) and int(b["rung_wave"]) == main.wave
					else ("Ring the bells during a wave" if not main.wave_active else "Get a troop to the bell tower to ring it"))
			return true
	return false


## K: every ready bell with enemies round it rung. Returns how many were.
func ring_all() -> int:
	_gather()
	var n := 0
	for b in towers:
		var near: Array = main.enemies_near(pos(b), REACH).filter(func(e): return not e.dead)
		if ready(b) and not near.is_empty() and ring(b):
			n += 1
	if n == 0:
		main.hud.show_message("No bell is ready with enemies in reach" if active() else "There are no bells here")
	return n


func _process(delta: float) -> void:
	if main == null or not active():
		return
	t += delta
	_gather()
	for b in towers:
		b["flash"] = maxf(float(b["flash"]) - delta * 1.5, 0.0)
	queue_redraw()


## The free-standing towers (objective towers draw themselves), and over every tower its
## state: ready (gold, glowing), rung (grey, till the next wave), or not yours yet.
func _draw() -> void:
	for b in towers:
		var p := pos(b)
		if b["obj"] == null:
			draw_bell_tower(self, p, t)
		var r := ready(b)
		var mark := p + Vector2(0, -112)
		var col := Color(1.0, 0.85, 0.35) if r else Color(0.6, 0.6, 0.62)
		if r:
			draw_circle(mark, 14.0 + 2.0 * sin(t * 5.0), Color(1.0, 0.85, 0.35, 0.3))
		draw_circle(mark, 10.0, OUTLINE)
		draw_circle(mark, 8.0, col)
		var txt := "Ring [K]" if r else ("next wave" if held(b) and int(b["rung_wave"]) == main.wave else ("hold it" if not held(b) else ""))
		if txt != "":
			draw_string_outline(ThemeDB.fallback_font, mark + Vector2(-26, -14), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, OUTLINE)
			draw_string(ThemeDB.fallback_font, mark + Vector2(-26, -14), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		if float(b["flash"]) > 0.0:
			draw_arc(p + Vector2(0, -20), REACH * (1.0 - float(b["flash"]) * 0.5), 0, TAU, 48, Color(1.0, 0.9, 0.5, float(b["flash"])), 4.0, true)


## A temple bell tower: a stone base, four timber posts, a curved roof, and a bronze bell
## hung in the middle (swinging when it's just been rung).
static func draw_bell_tower(ci: CanvasItem, p: Vector2, t: float, swing := 0.0) -> void:
	var stone := Color(0.62, 0.58, 0.52)
	var wood := Color(0.55, 0.22, 0.16)
	ci.draw_rect(Rect2(p + Vector2(-26, -14), Vector2(52, 16)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(-24, -12), Vector2(48, 12)), stone)
	ci.draw_rect(Rect2(p + Vector2(-24, -12), Vector2(48, 2)), stone.lightened(0.2))
	for x in [-20.0, 14.0]:
		ci.draw_rect(Rect2(p + Vector2(x - 1, -74), Vector2(8, 62)), OUTLINE)
		ci.draw_rect(Rect2(p + Vector2(x, -74), Vector2(6, 62)), wood)
	ci.draw_rect(Rect2(p + Vector2(-22, -74), Vector2(44, 6)), OUTLINE)
	ci.draw_rect(Rect2(p + Vector2(-21, -73), Vector2(42, 4)), wood.darkened(0.2))
	var roof := PackedVector2Array([p + Vector2(-38, -72), p + Vector2(-26, -86), p + Vector2(0, -96), p + Vector2(26, -86), p + Vector2(38, -72), p + Vector2(0, -78)])
	ci.draw_colored_polygon(PackedVector2Array([roof[0] + Vector2(-2, 2), roof[1] + Vector2(-2, -2), roof[2] + Vector2(0, -3), roof[3] + Vector2(2, -2), roof[4] + Vector2(2, 2), roof[5] + Vector2(0, 2)]), OUTLINE)
	ci.draw_colored_polygon(roof, Color(0.32, 0.36, 0.42))
	ci.draw_line(p + Vector2(-26, -86), p + Vector2(26, -86), Color(0.45, 0.5, 0.56), 2.0)
	var a := sin(t * 14.0) * 0.4 * swing
	ci.draw_set_transform(p + Vector2(0, -66), a, Vector2.ONE)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-11, 22), Vector2(-8, 4), Vector2(-4, 0), Vector2(4, 0), Vector2(8, 4), Vector2(11, 22)]), OUTLINE)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-9, 20), Vector2(-6, 5), Vector2(-3, 2), Vector2(3, 2), Vector2(6, 5), Vector2(9, 20)]), Color(0.78, 0.55, 0.22))
	ci.draw_line(Vector2(-5, 6), Vector2(-7, 18), Color(0.95, 0.78, 0.4), 2.0)
	ci.draw_set_transform(Vector2.ZERO)
