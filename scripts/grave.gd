extends Node2D
## Hardcore: where a troop fell for good (a wrecked emplacement leaves a ruin instead).
## Clicking it shows who it was, what it had been upgraded with and when it fell,
## but there's nothing left to upgrade or sell.

const OUTLINE := Color(0.1, 0.07, 0.1)
const STONE := Color(0.62, 0.62, 0.66)
const STONE_DARK := Color(0.42, 0.42, 0.47)
const DIRT := Color(0.36, 0.25, 0.16)

var main
var kind := ""
var unit_name := ""
var tiers := []
var path_names := []       # the unit's path names, for the info panel
var tier_names := []       # per path, the names of the tiers it bought
var portrait: Texture2D    # how it looked when it fell
var fell_wave := 0
var emplacement := false
var color := Color.WHITE
var age := 0.0


## Takes down who's buried here: the unit that has just died for good.
func setup_from(w) -> void:
	var g = self
	g.main = w.main
	g.kind = w.kind
	g.unit_name = w.data["name"]
	g.tiers = w.tiers.duplicate()
	g.color = w.data.get("color", Color.WHITE)
	g.emplacement = w.is_emplacement()
	g.fell_wave = w.main.wave
	g.position = w.position
	var paths: Array = w.data["paths"]
	for p in paths.size():
		g.path_names.append(paths[p]["name"])
		var bought := []
		for t in w.tiers[p]:
			bought.append(paths[p]["tiers"][t]["name"])
		g.tier_names.append(bought)
	g.portrait = w.Sprites.frames(w.sprite_name(), {}, w.accent_tag(), w.accent_layers())[0]


func _process(delta: float) -> void:
	age += delta
	if age < 1.0 or main.selected_grave == self:
		queue_redraw()


func info_text() -> String:
	var bought := []
	for p in tier_names.size():
		if not tier_names[p].is_empty():
			bought.append("%s %d (%s)" % [path_names[p], tier_names[p].size(), tier_names[p][-1]])
	var what := "Ruins of a %s" % unit_name if emplacement else "Grave of a %s" % unit_name
	var when := "destroyed" if emplacement else "fell"
	return "%s - %s in wave %d. It can't be upgraded or sold.\n%s" % [
			what, when, fell_wave, "Upgrades: " + ", ".join(bought) if not bought.is_empty() else "No upgrades"]


func _draw() -> void:
	var rise := clampf(age / 0.6, 0.0, 1.0)   # the stone settles in when it appears
	if main.selected_grave == self:
		draw_arc(Vector2(0, 8), 20.0, 0, TAU, 32, Color(1, 1, 1, 0.8), 2.0, true)
	if emplacement:
		draw_ruin(self, Vector2(0, 6), 1.0, color)
	else:
		draw_tombstone(self, Vector2(0, 8), rise, color)


## A little tombstone on a mound of earth, with the fallen unit's colour as a ribbon.
## Shared with the title screen's Hardcore scene. `at` is the foot of the stone.
static func draw_tombstone(ci: CanvasItem, at: Vector2, s: float, ribbon := Color(0.8, 0.2, 0.2)) -> void:
	ci.draw_set_transform(at, 0, Vector2(s, s))
	# Mound.
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-13, 2), Vector2(-8, -3), Vector2(8, -3), Vector2(13, 2)]), DIRT)
	ci.draw_line(Vector2(-13, 2), Vector2(13, 2), OUTLINE, 1.5)
	# Stone: a slab with a rounded top.
	var body := PackedVector2Array([Vector2(-8, -1), Vector2(8, -1), Vector2(8, -15), Vector2(6, -19), Vector2(2, -21),
			Vector2(-2, -21), Vector2(-6, -19), Vector2(-8, -15)])
	var rim := PackedVector2Array()
	for p in body:
		rim.append(p * 1.18 + Vector2(0, 0.3))
	ci.draw_colored_polygon(rim, OUTLINE)
	ci.draw_colored_polygon(body, STONE)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(4, -1), Vector2(8, -1), Vector2(8, -15), Vector2(6, -19), Vector2(4, -20)]), STONE_DARK)
	# A cross carved in it, and a ribbon tied round the foot in the unit's colour.
	ci.draw_rect(Rect2(-1, -17, 2, 10), STONE_DARK)
	ci.draw_rect(Rect2(-4, -14, 8, 2), STONE_DARK)
	ci.draw_rect(Rect2(-8, -5, 16, 2), ribbon)
	ci.draw_set_transform(Vector2.ZERO)


## A wrecked emplacement: scattered blocks and a broken beam.
static func draw_ruin(ci: CanvasItem, at: Vector2, s: float, tint := Color(0.6, 0.45, 0.3)) -> void:
	ci.draw_set_transform(at, 0, Vector2(s, s))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-15, 3), Vector2(-10, -2), Vector2(10, -2), Vector2(15, 3)]), DIRT)
	for b in [[-9, -6, 7, 6], [-2, -9, 8, 9], [6, -5, 6, 5], [-5, -14, 6, 5]]:
		ci.draw_rect(Rect2(b[0] - 1, b[1] - 1, b[2] + 2, b[3] + 2), OUTLINE)
		ci.draw_rect(Rect2(b[0], b[1], b[2], b[3]), STONE_DARK.lerp(STONE, 0.5))
	ci.draw_line(Vector2(-12, -3), Vector2(9, -16), OUTLINE, 4.0)
	ci.draw_line(Vector2(-12, -3), Vector2(9, -16), tint.darkened(0.2), 2.0)
	ci.draw_set_transform(Vector2.ZERO)
