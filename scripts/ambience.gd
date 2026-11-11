extends Node2D
## The field's mood, set by the mode (see MOODS): the light on the ground and castle,
## and what drifts over the field. Easy and the Tutorial are sunny, with butterflies and
## the odd cloud shadow; Normal is overcast, with leaves on the wind; Hard is dusk, with
## fireflies, fog, torchlight and the odd crow; Freeplay is a violet twilight full of magic motes. The enemy camp's fire
## and torches burn whatever the mood. Pure decoration: nothing here touches play.

const Sprites = preload("res://scripts/sprites.gd")
const FieldArt = preload("res://scripts/field_art.gd")

const MOODS := {
	"easy": {"ground": Color(1.04, 1.04, 0.97), "castle": Color(1, 1, 1), "shadows": 3, "butterflies": 7, "glow": 0.0},
	"tutorial": {"ground": Color(1.04, 1.04, 0.97), "castle": Color(1, 1, 1), "shadows": 2, "butterflies": 5, "glow": 0.0},
	"normal": {"ground": Color(0.93, 0.95, 0.98), "castle": Color(0.95, 0.96, 0.98), "shadows": 6, "butterflies": 2, "leaves": 6, "glow": 0.0},
	"hard": {"ground": Color(0.68, 0.72, 0.9), "castle": Color(0.76, 0.78, 0.94), "fireflies": 16, "fog": 5, "crows": 2, "glow": 1.0},
	"freeplay": {"ground": Color(0.88, 0.84, 0.98), "castle": Color(0.9, 0.88, 1.0), "motes": 18, "shadows": 2, "glow": 0.5},
}

var main
var mood := "normal"
var t := 0.0
var bits := {}            # kind -> list of particles
var flash := 0.0
var storm_cd := 4.0


func setup(mode: String) -> void:
	mood = mode if MOODS.has(mode) else "normal"
	var m: Dictionary = MOODS[mood]
	bits.clear()
	for kind in ["shadows", "butterflies", "leaves", "fireflies", "fog", "embers", "ash", "crows", "motes"]:
		var list := []
		for i in m.get(kind, 0):
			list.append(_new_bit(kind, true))
		bits[kind] = list


## How the ground and castle are lit in this mood (main.gd and castle.gd use these).
func ground_tint() -> Color:
	return MOODS[mood]["ground"]


func castle_tint() -> Color:
	return MOODS[mood]["castle"]


func glow() -> float:
	return MOODS[mood]["glow"]


func _w() -> float:
	return main.FIELD_W


func _h() -> float:
	return main.CASTLE_Y


func _new_bit(kind: String, anywhere: bool) -> Dictionary:
	var w := _w()
	var b := {"pos": Vector2(randf_range(0, w), randf_range(110, _h() - 20)), "phase": randf() * TAU, "speed": 1.0, "size": 1.0}
	match kind:
		"shadows":
			b["pos"] = Vector2(randf_range(-200, w) if anywhere else -220.0, randf_range(120, _h() - 60))
			b["speed"] = randf_range(10, 18)
			b["size"] = randf_range(0.8, 1.5)
		"fog":
			b["pos"] = Vector2(randf_range(-200, w) if anywhere else -260.0, randf_range(140, _h() - 40))
			b["speed"] = randf_range(5, 10)
			b["size"] = randf_range(1.0, 1.8)
		"leaves":
			b["pos"] = Vector2(randf_range(0, w) if anywhere else -10.0, randf_range(100, _h() - 40))
			b["speed"] = randf_range(30, 55)
			b["color"] = [Color(0.85, 0.55, 0.2), Color(0.75, 0.3, 0.15), Color(0.55, 0.65, 0.25)][randi() % 3]
		"embers":
			b["pos"] = Vector2(randf_range(0, w), randf_range(110, _h()) if anywhere else _h())
			b["speed"] = randf_range(14, 30)
		"ash":
			b["pos"] = Vector2(randf_range(0, w), randf_range(0, _h()) if anywhere else -4.0)
			b["speed"] = randf_range(12, 24)
		"crows":
			b["pos"] = Vector2(randf_range(-100, w) if anywhere else -40.0, randf_range(110, 400))
			b["speed"] = randf_range(60, 90)
		"butterflies":
			b["color"] = [Color(1, 0.95, 0.5), Color(1, 1, 1), Color(0.6, 0.8, 1.0), Color(1, 0.6, 0.85)][randi() % 4]
	return b


func _process(delta: float) -> void:
	t += delta
	var w := _w()
	for kind in bits:
		for b in bits[kind]:
			var p: Vector2 = b["pos"]
			match kind:
				"shadows", "fog":
					p.x += b["speed"] * delta
					if p.x > w + 260.0:
						b.merge(_new_bit(kind, false), true)
						continue
				"leaves":
					p += Vector2(b["speed"], sin(t * 2.0 + b["phase"]) * 12.0 + 6.0) * delta
					if p.x > w + 10.0 or p.y > _h():
						b.merge(_new_bit(kind, false), true)
						continue
				"embers":
					p += Vector2(sin(t * 1.5 + b["phase"]) * 10.0, -b["speed"]) * delta
					if p.y < 100.0:
						b.merge(_new_bit(kind, false), true)
						continue
				"ash":
					p += Vector2(sin(t + b["phase"]) * 8.0 + 4.0, b["speed"]) * delta
					if p.y > _h():
						b.merge(_new_bit(kind, false), true)
						continue
				"crows":
					p += Vector2(b["speed"], sin(t * 1.2 + b["phase"]) * 6.0) * delta
					if p.x > w + 40.0:
						b.merge(_new_bit(kind, false), true)
						b["pos"] = Vector2(-40.0 - randf_range(0, 600), b["pos"].y)   # spread out how often they pass
						continue
				"butterflies", "fireflies", "motes":
					# Wandering about a home spot.
					var home: Vector2 = b.get("home", p)
					b["home"] = home
					var k: float = 0.6 if kind == "butterflies" else 0.3
					p = home + Vector2(sin(t * k + b["phase"]) * 40.0, sin(t * k * 1.3 + b["phase"] * 2.0) * 24.0)
			b["pos"] = p
	flash = maxf(flash - delta * 2.0, 0.0)
	if MOODS[mood].get("lightning", false):
		storm_cd -= delta
		if storm_cd <= 0.0:
			storm_cd = randf_range(6.0, 14.0)
			flash = 1.0
	queue_redraw()


func _draw() -> void:
	var w := _w()
	for b in bits.get("shadows", []):
		_soft_blob(b["pos"], b["size"], Color(0.05, 0.08, 0.05, 0.07))
	for b in bits.get("fog", []):
		var fog := Color(0.85, 0.88, 0.95, 0.06)
		_soft_blob(b["pos"], b["size"] * 1.3, fog)
	_draw_fires(w)
	for b in bits.get("leaves", []):
		var p: Vector2 = b["pos"]
		draw_set_transform(p, t * 3.0 + b["phase"], Vector2.ONE)
		draw_rect(Rect2(-2, -1, 4, 2), b["color"])
		draw_set_transform(Vector2.ZERO)
	for b in bits.get("butterflies", []):
		var flap := absf(sin(t * 12.0 + b["phase"]))
		var p: Vector2 = b["pos"]
		draw_rect(Rect2(p + Vector2(-0.5, -1), Vector2(1, 3)), Color(0.15, 0.1, 0.1))
		draw_rect(Rect2(p + Vector2(-1 - 3 * flap, -2), Vector2(3 * flap + 0.5, 3)), b["color"])
		draw_rect(Rect2(p + Vector2(1, -2), Vector2(3 * flap + 0.5, 3)), b["color"])
	for b in bits.get("fireflies", []):
		var a := 0.5 + 0.5 * sin(t * 3.0 + b["phase"] * 3.0)
		Sprites.disc(self, b["pos"], 6.0, Color(0.8, 1.0, 0.4, 0.12 * a))
		draw_rect(Rect2(b["pos"] - Vector2(1, 1), Vector2(2, 2)), Color(0.85, 1.0, 0.5, a))
	for b in bits.get("motes", []):
		var a := 0.5 + 0.5 * sin(t * 2.5 + b["phase"] * 3.0)
		Sprites.disc(self, b["pos"], 7.0, Color(0.75, 0.55, 1.0, 0.12 * a))
		draw_rect(Rect2(b["pos"] - Vector2(1, 1), Vector2(2, 2)), Color(0.9, 0.8, 1.0, a))
	for b in bits.get("embers", []):
		var a := 0.5 + 0.5 * sin(t * 9.0 + b["phase"] * 5.0)
		draw_rect(Rect2(b["pos"], Vector2(2, 2)), Color(1.0, 0.5 + 0.3 * a, 0.15, 0.8 * a))
	for b in bits.get("ash", []):
		draw_rect(Rect2(b["pos"], Vector2(2, 1)), Color(0.55, 0.52, 0.52, 0.55))
	for b in bits.get("crows", []):
		var p: Vector2 = b["pos"]
		var f := sin(t * 10.0 + b["phase"]) * 3.0
		draw_polyline(PackedVector2Array([p + Vector2(-6, -2 - f), p + Vector2(-2, 0), p, p + Vector2(2, 0), p + Vector2(6, -2 - f)]), Color(0.06, 0.04, 0.06), 2.0)
	if flash > 0.0:
		draw_rect(Rect2(0, 0, w, main.FIELD_H), Color(1, 0.92, 0.95, 0.22 * flash * flash))


## A soft round shape (a cloud's shadow, a bank of fog) built from overlapping circles.
func _soft_blob(at: Vector2, s: float, col: Color) -> void:
	for o in [Vector2(-50, 4), Vector2(-15, -8), Vector2(25, -2), Vector2(55, 6), Vector2(5, 10)]:
		draw_set_transform(at + o * s, 0, Vector2(1, 0.55))
		Sprites.disc(self, Vector2.ZERO, 46.0 * s, col)
		draw_set_transform(Vector2.ZERO)


## The enemy camp's campfire and torches, and (when it's dark) the castle's torchlight.
func _draw_fires(w: float) -> void:
	var props: Dictionary = FieldArt.props(w)
	var g := glow()
	if main.paths._map.get("camp", true):   # (a convoy's road has no camp on it)
		_flame(props["fire"], 1.3, 0.25 + 0.3 * g)
		for p in props["torches"]:
			if not main.paths.blocked(p, 4.0):   # (a battlefield's cliffs can cover the camp's sides)
				_flame(p + Vector2(0, -30), 0.7, 0.2 + 0.3 * g)
	# The castle's gate torches (their flames are drawn by the castle).
	if g > 0.0:
		for side in [-1.0, 1.0]:
			var at := Vector2(w / 2.0 + side * 36.0, main.CASTLE_Y - 18.0)
			var f := 0.85 + 0.15 * sin(t * 11.0 + side)
			Sprites.disc(self, at, 34.0 * f, Color(1.0, 0.65, 0.25, 0.1 * g))
			Sprites.disc(self, at, 16.0 * f, Color(1.0, 0.7, 0.3, 0.12 * g))


func _flame(at: Vector2, s: float, glow_a: float) -> void:
	var f := 0.8 + 0.2 * sin(t * 13.0 + at.x) * sin(t * 7.1 + at.y)
	Sprites.disc(self, at, 30.0 * s * f, Color(1.0, 0.6, 0.2, glow_a * 0.4))
	var tip := at + Vector2(sin(t * 8.0 + at.x) * 2.0, -14.0 * s * f)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-6 * s, 0), at + Vector2(6 * s, 0), tip]), Color(1.0, 0.5, 0.12))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-3 * s, 0), at + Vector2(3 * s, 0), Vector2(tip.x, at.y + (tip.y - at.y) * 0.6)]), Color(1.0, 0.88, 0.4))
	# Smoke curling up from the campfire.
	if s > 1.0:
		for i in 3:
			var k := fmod(t * 0.4 + i / 3.0, 1.0)
			Sprites.disc(self, at + Vector2(sin(t + i) * 5.0 + k * 8.0, -16.0 - k * 40.0), 4.0 + k * 7.0, Color(0.4, 0.38, 0.38, 0.35 * (1.0 - k)))
