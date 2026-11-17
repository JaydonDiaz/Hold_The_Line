extends Node2D
## The work camp at the bottom of a battlefield without a castle: where your troops come
## from and where the Engineers set out from (they leave by the camp's gate, the spot the
## castle gate would be). It marks the line the enemy mustn't cross: a row of markers
## along the bottom edge, tents at the sides and the banner over the middle.
## Dressed for the region the map is in (its castle style), in that region's colours:
##   keep, fort   trodden dirt, sharpened stakes, canvas tents
##   guildhall    gravel, a low wall of cut blocks (Stonehollow)
##   guildgate    dark rock, a low wall of granite blocks with rune-lit caps (Deepdelve)
##   timberhall   leaf-strewn grass, a woven hurdle fence, green tents (Greenwood)
##   hospice      meadow grass, a white picket fence, white tents (Mercy Vale)
##   frostkeep    snow, snow-capped stakes, tents with snow on them (Frostmarch)
##   temple       stone flags, stone lanterns, saffron tents (the High Monastery)
##   cityhall     cobbles, a barricade of crates and barrels, striped pavilions (Free Cities)
##   conclave     starstone flags, rune posts glowing in the conduits' colours, violet
##                pavilions with gold finials (the Arcane Spires)

const OUTLINE := Color(0.1, 0.07, 0.1)
const PX := 3.0
const Maps = preload("res://scripts/maps.gd")

var main
var t := 0.0
var ground := Ground.new()   # everything that doesn't move, drawn once


func _ready() -> void:
	ground.camp = self
	add_child(ground)
	ground.show_behind_parent = true


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


## Which camp: the map's castle style ("keep" on the open meadow).
func theme() -> String:
	return String(Maps.get_map(main.map_id).get("castle", "keep"))


func _b(ci: CanvasItem, x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(floorf(x / PX) * PX, floorf(y / PX) * PX, w * PX, h * PX), c)


## The moving parts: the banner over the gate and the campfire.
func _draw() -> void:
	var w: float = main.FIELD_W
	var top: float = main.CASTLE_Y
	var pal: Dictionary = main.castle.pal
	var gx: float = w / 2.0
	_b(self, gx - 30, top - 30, 1, 34, pal["wood"].lightened(0.15))
	var wave := int(t * 4.0) % 2
	_b(self, gx - 27, top - 30 + wave * PX, 6, 4, pal["banner"])
	_b(self, gx - 27, top - 30 + wave * PX, 6, 1, pal["banner_trim"])
	var flick := 1.0 + floorf(1.5 + 1.5 * sin(t * 9.0))
	var th := theme()
	var flame := Color(0.75, 0.5, 1.0) if th == "conclave" else Color(1, 0.55, 0.15)
	if th == "temple" or th == "conclave":
		_b(self, gx + 22, top + 13, 6, 2, pal["stone_dark"])   # a stone brazier
	else:
		_b(self, gx + 24, top + 16, 4, 1, Color(0.4, 0.28, 0.18))
	_b(self, gx + 27, top + 16 - flick * PX, 2, flick, flame)
	_b(self, gx + 27, top + 16 - PX, 1, 1, Color(1, 0.9, 0.5) if th != "conclave" else Color(0.95, 0.9, 1.0))


class Ground extends Node2D:
	var camp
	var _key := ""

	func _process(_delta: float) -> void:
		var key := "%s@%d" % [camp.theme(), camp.main.FIELD_W]
		if key != _key:
			_key = key
			queue_redraw()

	func _draw() -> void:
		camp._draw_ground(self)


func _draw_ground(ci: CanvasItem) -> void:
	var w: float = main.FIELD_W
	var top: float = main.CASTLE_Y
	var bottom: float = main.FIELD_H
	var th := theme()
	var pal: Dictionary = main.castle.pal
	# The ground behind the line.
	var soil := Color(0.42, 0.34, 0.24)
	var fleck := Color(0.36, 0.29, 0.2)
	match th:
		"guildhall":
			soil = Color(0.5, 0.48, 0.46); fleck = Color(0.4, 0.38, 0.37)
		"guildgate":
			soil = Color(0.34, 0.32, 0.33); fleck = Color(0.7, 0.54, 0.26)
		"timberhall":
			soil = Color(0.24, 0.36, 0.18); fleck = Color(0.58, 0.4, 0.16)
		"hospice":
			soil = Color(0.36, 0.55, 0.26); fleck = Color(0.95, 0.95, 0.85)
		"frostkeep":
			soil = Color(0.88, 0.91, 0.96); fleck = Color(0.74, 0.8, 0.88)
		"temple", "cityhall", "conclave":
			soil = pal["stone_dark"].lerp(pal["stone"], 0.4); fleck = pal["stone_light"]
	ci.draw_rect(Rect2(0, top + 6, w, bottom - top - 6), soil)
	if th in ["temple", "cityhall", "conclave"]:
		# Paving: rows of flags (or cobbles), joints showing.
		var row := 0
		for y in range(int(top + 6), int(bottom), 6):
			var x := -6.0 if row % 2 else 0.0
			while x < w:
				var sw := 12.0 if th == "cityhall" else 18.0
				ci.draw_rect(Rect2(x + 1, y + 1, sw - 2, 4), soil.lerp(fleck, 0.35 + 0.1 * float(int(x / sw + row) % 2)))
				x += sw
			row += 1
	else:
		for i in int(w / 18.0):
			var x := fposmod(i * 37.0, w)
			_b(ci, x, top + 12 + fposmod(i * 13.0, bottom - top - 18), 2, 1, fleck)
	# The line, with a gap where the road runs through.
	_line(ci, w, top, th, pal)
	# Tents (or pavilions) at the sides.
	for side in [0.12, 0.88]:
		_tent(ci, w * side, top, th, pal)


func _line(ci: CanvasItem, w: float, top: float, th: String, pal: Dictionary) -> void:
	var gate := func(x: float) -> bool: return absf(x - w / 2.0) < 36.0
	match th:
		"guildhall", "guildgate":
			# A low wall of cut blocks; rune-lit caps in Deepdelve.
			var x := 0.0
			var n := 0
			while x < w:
				if not gate.call(x + 6.0):
					_b(ci, x, top - 6, 4, 3, OUTLINE)
					_b(ci, x + PX * 0.0, top - 6, 4, 2, pal["stone"] if n % 2 else pal["stone_light"])
					if th == "guildgate" and n % 4 == 0:
						_b(ci, x + PX, top - 6, 2, 1, Color(0.95, 0.7, 0.3))
				x += 4 * PX
				n += 1
		"timberhall":
			# A woven hurdle fence.
			for x in range(0, int(w), 6):
				if gate.call(x):
					continue
				_b(ci, x, top - 8, 1, 7, Color(0.36, 0.24, 0.13))
				_b(ci, x, top - 7 + (x / 6 % 2) * PX, 2, 1, Color(0.55, 0.4, 0.22))
				_b(ci, x, top - 4 + ((x / 6 + 1) % 2) * PX, 2, 1, Color(0.5, 0.36, 0.2))
			for x in range(9, int(w), 45):
				if not gate.call(x):
					_b(ci, x, top - 10, 2, 1, Color(0.3, 0.55, 0.25))   # leaves caught in it
		"hospice":
			# A white picket fence.
			for x in range(3, int(w), 9):
				if gate.call(x):
					continue
				_b(ci, x, top - 9, 1, 3, OUTLINE)
				_b(ci, x, top - 8, 1, 7, Color(0.94, 0.93, 0.88))
			for y in [top - 6, top - 3]:
				for x in range(0, int(w), 3):
					if not gate.call(x):
						_b(ci, x, y, 1, 1, Color(0.82, 0.8, 0.74))
		"temple":
			# Stone lanterns, lit.
			for x in range(18, int(w), 48):
				if gate.call(x):
					continue
				_b(ci, x - PX, top - 3, 3, 1, pal["stone_dark"])
				_b(ci, x, top - 9, 1, 2, pal["stone"])
				_b(ci, x - PX, top - 15, 3, 2, pal["stone"])
				_b(ci, x, top - 12, 1, 1, Color(1.0, 0.75, 0.35))
				_b(ci, x - PX * 2, top - 18, 5, 1, pal["stone_dark"])
			for x in range(6, int(w), 15):
				if not gate.call(x):
					_b(ci, x, top - 3, 2, 1, pal["stone_dark"])   # a kerb between them
		"cityhall":
			# Crates and barrels pulled across the street.
			var x := 0.0
			var n := 0
			while x < w:
				if not gate.call(x + 6.0):
					if n % 3 == 2:
						_b(ci, x + PX, top - 9, 3, 4, OUTLINE)
						_b(ci, x + PX, top - 9, 3, 3, Color(0.5, 0.32, 0.18))
						_b(ci, x + PX, top - 6, 3, 1, Color(0.35, 0.35, 0.38))
					else:
						_b(ci, x, top - 9 + (n % 2) * PX, 4, 4 - (n % 2), OUTLINE)
						_b(ci, x, top - 9 + (n % 2) * PX, 4, 3 - (n % 2), Color(0.66, 0.48, 0.28))
						_b(ci, x + PX, top - 8 + (n % 2) * PX, 2, 1, Color(0.5, 0.35, 0.2))
				x += 5 * PX
				n += 1
		"conclave":
			# Rune posts glowing in the conduits' colours, a low starstone kerb.
			var cols: Array = preload("res://scripts/conduits.gd").COLORS
			var n := 0
			for x in range(12, int(w), 30):
				if gate.call(x):
					continue
				_b(ci, x - PX, top - 3, 3, 1, pal["stone_dark"])
				_b(ci, x, top - 12, 1, 3, pal["stone"])
				_b(ci, x, top - 15, 1, 1, cols[n % cols.size()])
				n += 1
			for x in range(0, int(w), 3):
				if not gate.call(x):
					_b(ci, x, top - 2, 1, 1, pal["stone_dark"])
		_:
			# Sharpened stakes, red tips (snow on them in the north).
			for x in range(6, int(w), 15):
				if gate.call(x):
					continue
				_b(ci, x, top - 6, 2, 5, Color(0.5, 0.34, 0.2))
				_b(ci, x, top - 9, 2, 1, Color(0.95, 0.97, 1.0) if th == "frostkeep" else Color(0.75, 0.2, 0.18))
				_b(ci, x - 1, top - 6, 1, 5, OUTLINE)


func _tent(ci: CanvasItem, cx: float, top: float, th: String, pal: Dictionary) -> void:
	var cloth := Color(0.86, 0.8, 0.66)
	var stripe := Color(-1, 0, 0)
	match th:
		"timberhall":
			cloth = Color(0.42, 0.6, 0.36)
		"hospice":
			cloth = Color(0.96, 0.95, 0.9); stripe = pal["banner"]
		"temple":
			cloth = pal["banner"]
		"cityhall":
			cloth = Color(0.92, 0.88, 0.76); stripe = pal["banner"]
		"conclave":
			cloth = pal["banner"].lightened(0.15); stripe = pal["banner_trim"]
		"guildhall", "guildgate":
			cloth = Color(0.78, 0.68, 0.5); stripe = pal["banner"]
	var pavilion := th in ["cityhall", "conclave", "temple"]
	for row in 9:
		var half := row * 0.8 + 1.0
		var c := cloth if row < 8 else cloth.darkened(0.2)
		if stripe.r >= 0.0 and row % 3 == 1 and not pavilion:
			c = stripe
		_b(ci, cx - half * PX - PX, top + 2 + row * PX, half * 2.0 + 2.0, 1, OUTLINE)
		_b(ci, cx - half * PX, top + 2 + row * PX, half * 2.0, 1, c)
		if pavilion and stripe.r >= 0.0:
			# Panels running down from the peak.
			_b(ci, cx - PX, top + 2 + row * PX, 1, 1, stripe)
			_b(ci, cx - half * PX + PX, top + 2 + row * PX, 1, 1, stripe if row > 2 else c)
		if th == "frostkeep" and row < 4:
			_b(ci, cx - half * PX, top + 2 + row * PX, half * 2.0, 1, Color(0.97, 0.98, 1.0))
	_b(ci, cx - PX, top + 2 + 5 * PX, 2, 4, Color(0.3, 0.22, 0.15))
	if pavilion:
		# A finial and pennant on top.
		_b(ci, cx - PX, top - 4, 1, 2, pal["banner_trim"] if th == "conclave" else pal["wood"])
		_b(ci, cx, top - 4, 2, 1, pal["banner_trim"] if th != "conclave" else pal["banner"])
