extends Control
## The title screen's backdrop: a front view of the castle under a sky of drifting
## clouds, with a pixel-art "Hold the Line" banner. Hovering a mode card changes the
## scene to match it (see LOOKS): a training session for the Tutorial, a clear sky and
## weak enemies for Easy, clouds and tougher ones for Normal, a dark sky and downed
## troops and graves for Hard, a twilight of conjured enemies for Freeplay, and
## Engineers at work (on emplacement construction sites, mending the castle wall,
## one tossing his hammer) for Settings, and a dawn with the keep's last two
## swordsmen facing the first raiders for the Campaign. Each kind of battle in Battle
## Modes has a scene of its own too: watchtowers under attack, a pass held, a beacon
## building to a blaze, villagers making for the gate, a fort's flag raised, a convoy
## rolling by, and a line falling back through a storm. Past the castle lies the far
## country: mountains, the eight peoples' lands and their beacons (which light one by one
## for the Campaign). Pure decoration: nothing here touches the game.

const Sprites = preload("res://scripts/sprites.gd")
const Grave = preload("res://scripts/grave.gd")

const W := 640.0
const H := 1040.0
const GROUND_Y := 522.0     # the foot of the castle walls
const EARTH_Y := 604.0      # where the grass gives way to the earth the cards sit on
const ROWS := [556.0, 590.0]
const SPRITE_SCALE := 2.5
const OUTLINE := Color(0.1, 0.07, 0.1)

# Each look: sky colours, clouds (how many, their colour), sun / moon / stars,
# light on the land, lit windows, lightning, who's out front.
const LOOKS := {
	"": {"top": Color(0.36, 0.6, 0.93), "low": Color(0.78, 0.9, 1.0), "clouds": 6, "cloud": Color(1, 1, 1),
		"sun": 1.0, "moon": 0.0, "stars": 0.0, "light": Color(1, 1, 1), "windows": 0.0, "storm": 0.0,
		"guards": ["swordsman", "archer", "bard", "swordsman"], "foes": [], "scene": "idle"},
	"tutorial": {"top": Color(0.4, 0.66, 0.98), "low": Color(0.85, 0.95, 1.0), "clouds": 4, "cloud": Color(1, 1, 1),
		"sun": 1.0, "moon": 0.0, "stars": 0.0, "light": Color(1.04, 1.02, 0.96), "windows": 0.0, "storm": 0.0,
		"guards": [], "foes": [], "scene": "training"},
	"easy": {"top": Color(0.28, 0.6, 1.0), "low": Color(0.75, 0.92, 1.0), "clouds": 2, "cloud": Color(1, 1, 1),
		"sun": 1.0, "moon": 0.0, "stars": 0.0, "light": Color(1.05, 1.04, 0.98), "windows": 0.0, "storm": 0.0,
		"guards": ["swordsman", "archer", "healer"], "foes": ["goblin", "goblin", "bat"], "scene": "battle"},
	"normal": {"top": Color(0.46, 0.56, 0.68), "low": Color(0.74, 0.79, 0.84), "clouds": 13, "cloud": Color(0.86, 0.88, 0.91),
		"sun": 0.35, "moon": 0.0, "stars": 0.0, "light": Color(0.86, 0.88, 0.92), "windows": 0.0, "storm": 0.0,
		"guards": ["swordsman", "archer", "mage", "swordsman"], "foes": ["orc", "wolf", "goblin", "sapper"], "scene": "battle"},
	"hard": {"top": Color(0.1, 0.11, 0.22), "low": Color(0.3, 0.27, 0.4), "clouds": 10, "cloud": Color(0.3, 0.3, 0.4),
		"sun": 0.0, "moon": 1.0, "stars": 0.4, "light": Color(0.5, 0.52, 0.66), "windows": 1.0, "storm": 0.0,
		"guards": ["swordsman", "martial", "archer", "mage"], "foes": ["troll", "orc", "orc", "sapper"], "scene": "battle",
		"downed": ["swordsman", "archer"], "graves": 4},
	"freeplay": {"top": Color(0.1, 0.06, 0.28), "low": Color(0.6, 0.32, 0.58), "clouds": 4, "cloud": Color(0.56, 0.44, 0.7),
		"sun": 0.0, "moon": 0.7, "stars": 1.0, "light": Color(0.72, 0.64, 0.86), "windows": 1.0, "storm": 0.0,
		"guards": ["mage", "frost", "mage"], "foes": ["goblin", "orc", "wolf", "troll", "bat", "sapper", "warlord"], "scene": "conjure"},
	"campaign": {"top": Color(0.32, 0.36, 0.62), "low": Color(1.0, 0.72, 0.5), "clouds": 7, "cloud": Color(1.0, 0.86, 0.78),
		"sun": 0.6, "moon": 0.0, "stars": 0.0, "light": Color(1.0, 0.9, 0.82), "windows": 1.0, "storm": 0.0,
		"guards": ["swordsman", "swordsman"], "foes": ["goblin", "goblin", "orc"], "scene": "battle"},
	"settings": {"top": Color(0.36, 0.6, 0.93), "low": Color(0.82, 0.9, 0.98), "clouds": 5, "cloud": Color(1, 1, 1),
		"sun": 0.9, "moon": 0.0, "stars": 0.0, "light": Color(1.02, 1.0, 0.96), "windows": 0.0, "storm": 0.0,
		"guards": [], "foes": [], "scene": "workshop"},
	# The Battle Modes, one look for each kind of battle (keyed as in Scenarios.TYPES).
	"positions": {"top": Color(0.34, 0.62, 0.98), "low": Color(0.8, 0.92, 1.0), "clouds": 4, "cloud": Color(1, 1, 1),
		"sun": 1.0, "moon": 0.0, "stars": 0.0, "light": Color(1.03, 1.02, 0.97), "windows": 0.0, "storm": 0.0,
		"guards": [], "foes": ["goblin", "goblin", "wolf", "orc", "sapper"], "scene": "positions"},
	"pass": {"top": Color(0.42, 0.5, 0.62), "low": Color(0.76, 0.8, 0.84), "clouds": 11, "cloud": Color(0.88, 0.9, 0.92),
		"sun": 0.3, "moon": 0.0, "stars": 0.0, "light": Color(0.9, 0.92, 0.95), "windows": 0.0, "storm": 0.0,
		"guards": [], "foes": ["goblin", "goblin", "orc", "wolf"], "scene": "pass", "bounce": true},
	"protect": {"top": Color(0.2, 0.18, 0.42), "low": Color(0.98, 0.55, 0.38), "clouds": 5, "cloud": Color(0.95, 0.7, 0.65),
		"sun": 0.0, "moon": 0.45, "stars": 0.35, "light": Color(0.86, 0.76, 0.8), "windows": 1.0, "storm": 0.0,
		"guards": [], "foes": ["goblin", "orc", "wolf", "goblin"], "scene": "protect"},
	"evac": {"top": Color(0.5, 0.62, 0.8), "low": Color(0.95, 0.88, 0.76), "clouds": 6, "cloud": Color(1, 0.97, 0.92),
		"sun": 0.7, "moon": 0.0, "stars": 0.0, "light": Color(1.0, 0.96, 0.9), "windows": 0.0, "storm": 0.0,
		"guards": [], "foes": ["wolf", "goblin", "orc"], "scene": "evac"},
	"capture": {"top": Color(0.3, 0.55, 0.92), "low": Color(0.96, 0.88, 0.7), "clouds": 3, "cloud": Color(1, 0.98, 0.94),
		"sun": 1.0, "moon": 0.0, "stars": 0.0, "light": Color(1.05, 1.0, 0.9), "windows": 0.0, "storm": 0.0,
		"guards": [], "foes": ["goblin", "orc", "skeleton_archer", "goblin"], "scene": "capture"},
	"escort": {"top": Color(0.38, 0.6, 0.9), "low": Color(0.85, 0.9, 0.95), "clouds": 8, "cloud": Color(1, 1, 1),
		"sun": 0.8, "moon": 0.0, "stars": 0.0, "light": Color(1.0, 1.0, 0.97), "windows": 0.0, "storm": 0.0,
		"guards": [], "foes": ["goblin", "wolf", "goblin"], "scene": "escort"},
	"retreat": {"top": Color(0.15, 0.17, 0.25), "low": Color(0.4, 0.42, 0.5), "clouds": 14, "cloud": Color(0.36, 0.38, 0.46),
		"sun": 0.0, "moon": 0.0, "stars": 0.0, "light": Color(0.62, 0.64, 0.74), "windows": 0.8, "storm": 1.0,
		"guards": [], "foes": ["orc", "goblin", "troll", "wolf", "orc"], "scene": "retreat"},
}
const FIGHTS := ["battle", "conjure", "positions", "pass", "protect", "evac", "capture", "escort", "retreat"]   # scenes enemies come at
const WAGON_SPEED := 30.0      # the convoy's pace in the escort scene
const RETREAT_STEP := 2.6      # seconds between the steps back in the retreat scene
const CHARGE := 4.2            # seconds for the protect scene's beacon to build to a blaze (then a moment ablaze)
const RAISE := 3.4             # seconds for the capture scene's flag to climb its pole
# The far country seen past the castle: two ranges of mountains (x, peak y, half width;
# snow on those that rise above SNOW_Y), and the eight peoples' lands, each with its beacon.
const FAR_PEAKS := [[-700, 290, 120], [-560, 304, 110], [-420, 296, 120], [-260, 300, 120], [-120, 286, 110], [10, 276, 100], [92, 304, 80], [180, 318, 90], [258, 300, 80],
		[380, 306, 90], [470, 290, 100], [602, 262, 110], [720, 292, 120], [860, 284, 110], [1000, 300, 120], [1150, 288, 110], [1300, 302, 120]]
const NEAR_PEAKS := [[-520, 348, 120], [-180, 352, 110], [52, 334, 70], [205, 330, 60], [418, 352, 50], [700, 350, 120], [1020, 346, 120]]
const SNOW_Y := 312.0
## Where each beacon stands (in the order they light, west to east) and how far off it is
## (1 near, smaller further).
const BEACONS := [[Vector2(10, 276), 0.8], [Vector2(70, 405), 0.9], [Vector2(214, 353), 0.85], [Vector2(244, 331), 0.8],
		[Vector2(426, 334), 0.85], [Vector2(566, 452), 1.1], [Vector2(628, 316), 0.75], [Vector2(631, 410), 0.95]]
const ENGINEER_SWING := 0.36   # seconds per hammer blow in the workshop scene
const TOSS := 1.5              # seconds per hammer toss in the workshop scene
const BOLT_COLORS := {"archer": Color(0.95, 0.9, 0.7), "mage": Color(0.75, 0.5, 1.0), "frost": Color(0.6, 0.9, 1.0),
		"alchemist": Color(0.5, 1.0, 0.4), "bard": Color(1.0, 0.85, 0.4), "healer": Color(1.0, 1.0, 0.6)}
const RANGED := ["archer", "mage", "frost", "alchemist", "bard", "healer"]
const GRAVE_SPOTS := [Vector2(392, 542), Vector2(560, 601), Vector2(20, 598), Vector2(505, 545),
		Vector2(452, 602), Vector2(128, 540), Vector2(612, 550), Vector2(168, 603)]   # graves (Hard's), in the order they appear
const BIG := {"troll": 3.0, "warlord": 3.3, "wyvern": 3.0}

# A chunky 5x7 pixel font, just the letters the title needs.
const FONT := {
	"H": ["X...X", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"],
	"O": [".XXX.", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
	"L": ["X....", "X....", "X....", "X....", "X....", "X....", "XXXXX"],
	"D": ["XXXX.", "X...X", "X...X", "X...X", "X...X", "X...X", "XXXX."],
	"T": ["XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "..X.."],
	"E": ["XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "XXXXX"],
	"I": ["XXX", ".X.", ".X.", ".X.", ".X.", ".X.", "XXX"],
	"N": ["X...X", "XX..X", "X.X.X", "X.X.X", "X..XX", "X...X", "X...X"],
	" ": ["..", "..", "..", "..", "..", "..", ".."],
}
const TITLE := "HOLD THE LINE"
const PX := 7.0            # size of one title pixel
const TITLE_Y := 50.0

var t := 0.0
var look := ""
var cur := {}              # the look being shown, blended towards LOOKS[look]
var pending_default := -1.0
var clouds := []           # {pos, scale, speed, seed, leaving}: they drift in from the left edge and off the right
var cloud_cd := 0.0        # wait before the next cloud drifts in
var stars := []
var actors := []           # {kind, pos, side, hp, cd, lunge, hurt, alpha, leaving, home, role}
var bolts := []
var pops := []
var graves := []           # {pos, alpha, target}
var spawn_cd := 0.0
var flash := 0.0
var bolt_path := PackedVector2Array()
var storm_cd := 2.0
var title_pixels := []     # [col, row] lit pixels of the title, worked out once
var title_cols := 0
var bat: Batch = null      # while set, the far country's drawing goes into this mesh (see _draw_land)
var land_mesh: ArrayMesh = null
var land_key := []
var fire_mesh: ArrayMesh = null
var rain_mesh: ArrayMesh = null
var chain := 99.0          # seconds since the beacons began lighting one by one (the Campaign's look)
var step_cd := 0.0         # the retreat scene's wait before the line steps back again
var steps := 0
var scene_t := 0.0         # seconds the current look has been showing


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	cur = (LOOKS[""] as Dictionary).duplicate()
	# The first clouds are already in the sky when the screen opens.
	for i in int(LOOKS[""]["clouds"]):
		clouds.append(_new_cloud(randf_range(-100, 740)))
	for i in 60:
		stars.append(Vector2(randf_range(-300, 940), randf_range(0, 380)))
	_layout_title()
	_cast()


func _layout_title() -> void:
	var col := 0
	for ch in TITLE:
		var glyph: Array = FONT[ch]
		for r in glyph.size():
			for c in (glyph[r] as String).length():
				if glyph[r][c] == "X":
					title_pixels.append(Vector2i(col + c, r))
		col += (glyph[0] as String).length() + 1
	title_cols = col - 1


## Show the scene for a mode ("" is the plain title screen). Going back to "" waits a
## moment, so sliding from one card to the next doesn't flash the plain scene between.
func set_look(key: String) -> void:
	if not LOOKS.has(key):
		key = ""   # a card with no scene of its own (Back, the campaign's sub-menus)
	if key == "":
		pending_default = 0.25
		return
	pending_default = -1.0
	_apply(key)


func _apply(key: String) -> void:
	if key == look:
		return
	look = key
	scene_t = 0.0
	if key == "campaign":
		chain = 0.0   # the beacons go out, then light again one after another
	_cast()


## Swap who's out front for the new look: the old cast fades away, the new fades in.
func _cast() -> void:
	for a in actors:
		a["leaving"] = true
	bolts.clear()
	var L: Dictionary = LOOKS[look]
	var guards: Array = L["guards"]
	match L["scene"]:
		"training":
			# Sparring partners and practice targets.
			_add_actor("archer", Vector2(70, ROWS[1]), "guard", "archery")
			_add_actor("target", Vector2(205, ROWS[1]), "prop")
			_add_actor("swordsman", Vector2(280, ROWS[0] + 4), "guard", "dummy")
			_add_actor("dummy", Vector2(330, ROWS[0] + 4), "prop")
			_add_actor("martial", Vector2(450, ROWS[1]), "guard", "spar")
			_add_actor("martial", Vector2(500, ROWS[1]), "guard", "spar_r")
			_add_actor("healer", Vector2(585, ROWS[0]), "guard", "idle")
		"workshop":
			# Engineers at work: towers going up out on the field, the wall being mended,
			# and one carrying planks back and forth.
			_add_actor("site", Vector2(105, ROWS[1]), "prop", "0.25")
			_add_actor("engineer", Vector2(150, ROWS[1] + 2), "guard", "build_l")
			_add_actor("site", Vector2(540, ROWS[0]), "prop", "0.1")
			_add_actor("engineer", Vector2(494, ROWS[0] + 2), "guard", "build")
			_add_actor("engineer", Vector2(205, GROUND_Y + 18), "guard", "repair")
			_add_actor("engineer", Vector2(436, GROUND_Y + 18), "guard", "repair_l")
			_add_actor("engineer", Vector2(320, ROWS[1] + 6), "guard", "toss")
		"positions":
			# Two watchtowers out on the field, an Engineer patching one, Archers covering both.
			_add_actor("watchtower", Vector2(190, ROWS[0] - 2), "prop")
			actors[-1]["objective"] = true
			_add_actor("watchtower", Vector2(446, ROWS[0] + 2), "prop")
			actors[-1]["objective"] = true
			_add_actor("engineer", Vector2(418, ROWS[0] + 6), "guard", "build")
			_add_actor("archer", Vector2(120, ROWS[1]), "guard", "fight")
			_add_actor("archer", Vector2(300, ROWS[1]), "guard", "fight")
		"pass":
			# Crags either side, and Swordsmen holding the gap: the enemy bounces off them.
			for c in [[Vector2(16, 534), 1.2], [Vector2(612, 532), 1.3], [Vector2(560, 610), 0.9], [Vector2(70, 612), 0.8]]:
				_add_actor("crag", c[0], "prop", str(c[1]))
			_add_actor("swordsman", Vector2(330, ROWS[0]), "guard", "fight")
			_add_actor("swordsman", Vector2(346, ROWS[1]), "guard", "fight")
			_add_actor("archer", Vector2(230, ROWS[0]), "guard", "fight")
			_add_actor("archer", Vector2(250, ROWS[1]), "guard", "fight")
		"protect":
			# A signal beacon building to a blaze, with a Mage at its foot and a guard out front.
			_add_actor("beacon", Vector2(140, ROWS[0] - 4), "prop")
			actors[-1]["objective"] = true
			_add_actor("mage", Vector2(200, ROWS[1]), "guard", "fight")
			_add_actor("mage", Vector2(90, ROWS[1] + 4), "guard", "fight")
			_add_actor("swordsman", Vector2(300, ROWS[0]), "guard", "fight")
			_add_actor("martial", Vector2(318, ROWS[1]), "guard", "fight")
		"evac":
			# Villagers leave their cottages for the castle gate, a Healer seeing them along.
			_add_actor("cottage", Vector2(58, ROWS[0] - 12), "prop", "0")
			_add_actor("cottage", Vector2(150, ROWS[0] - 20), "prop", "1")
			_add_actor("healer", Vector2(232, ROWS[1]), "guard", "fight")
			_add_actor("archer", Vector2(400, ROWS[0]), "guard", "fight")
			_add_actor("swordsman", Vector2(470, ROWS[1]), "guard", "fight")
		"capture":
			# An old fort taken back: its flag climbs the pole, red to ours, as the Martial
			# Artists hold the ground in front.
			_add_actor("fort", Vector2(410, ROWS[0] - 6), "prop")
			_add_actor("martial", Vector2(500, ROWS[0]), "guard", "fight")
			_add_actor("martial", Vector2(520, ROWS[1]), "guard", "fight")
			_add_actor("archer", Vector2(330, ROWS[1]), "guard", "fight")
		"escort":
			# The convoy: a wagon rolling along the road, a Bard out in front and guards around it.
			_add_actor("wagon", Vector2(-40, ROWS[1] + 4), "prop")
			for e in [["bard", Vector2(96, 0)], ["swordsman", Vector2(64, -34)], ["archer", Vector2(-58, -34)]]:
				_add_actor(e[0], Vector2(-40, ROWS[1] + 4) + e[1], "guard", "escort")
				actors[-1]["off"] = e[1]
		"retreat":
			# A line falling back, step by step, the Frost Mage in the rearguard.
			_add_actor("frost", Vector2(380, ROWS[0]), "guard", "fight")
			_add_actor("archer", Vector2(350, ROWS[1]), "guard", "fight")
			_add_actor("swordsman", Vector2(456, ROWS[0]), "guard", "fight")
			_add_actor("swordsman", Vector2(470, ROWS[1]), "guard", "fight")
			step_cd = RETREAT_STEP
			steps = 0
		"idle":
			# Guards on watch either side of the gate.
			_add_actor(guards[0], Vector2(250, ROWS[1]), "guard", "idle")
			_add_actor(guards[1], Vector2(150, ROWS[0]), "guard", "idle")
			_add_actor(guards[2], Vector2(480, ROWS[0]), "guard", "idle")
			_add_actor(guards[3], Vector2(390, ROWS[1]), "guard", "idle_r")
		_:
			# Ranged at the back, melee in front, each with a spot of their own.
			var counts := {"ranged": 0, "melee": 0}
			for kind in guards:
				var group := "ranged" if kind in RANGED else "melee"
				var n: int = counts[group]
				counts[group] = n + 1
				var x: float = (55.0 if group == "ranged" else 195.0) + n * 52.0 + randf_range(-5, 5)
				_add_actor(kind, Vector2(x, ROWS[n % 2]), "guard", "fight")
	for i in (L.get("downed", []) as Array).size():
		# Fallen out on the enemies' side of the field, where the fighting was.
		_add_actor(L["downed"][i], Vector2(430 + i * 110, ROWS[i % 2] + 8), "downed")
	# Graves come and go with the looks that have them (Hard).
	var want: int = L.get("graves", 0)
	if graves.is_empty():
		# Scattered, not in a row: most out where the enemies come from, a few among the troops.
		for spot in GRAVE_SPOTS:
			graves.append({"pos": spot + Vector2(randf_range(-8, 8), randf_range(-2, 2)), "alpha": 0.0})
	for i in graves.size():
		graves[i]["target"] = 1.0 if i < want else 0.0
	spawn_cd = 0.3


func _add_actor(kind: String, at: Vector2, side: String, role := "") -> void:
	actors.append({"kind": kind, "pos": at, "home": at, "side": side, "role": role, "hp": 3, "cd": randf_range(0.2, 1.0),
			"lunge": 0.0, "hurt": 0.0, "hop": 0.0, "alpha": 0.0, "leaving": false, "id": randi()})


func _spawn_foe() -> void:
	var L: Dictionary = LOOKS[look]
	var foes: Array = L["foes"]
	if foes.is_empty():
		return
	var kind: String = foes[randi() % foes.size()]
	var row: float = ROWS[randi() % 2]
	var at := Vector2(700, row)
	if L["scene"] == "conjure":
		# Freeplay: enemies appear out of a magic circle wherever you like.
		at = Vector2(randf_range(360, 600), row)
		pops.append({"pos": at, "age": 0.0, "color": Color(0.8, 0.5, 1.0), "ring": true})
	_add_actor(kind, at, "foe")
	var a: Dictionary = actors[-1]
	a["hp"] = {"troll": 6, "warlord": 9, "orc": 4}.get(kind, 2)
	a["speed"] = {"wolf": 70.0, "bat": 50.0, "troll": 20.0, "warlord": 18.0}.get(kind, 34.0)


func _process(delta: float) -> void:
	t += delta
	chain += delta
	scene_t += delta
	if pending_default >= 0.0:
		pending_default -= delta
		if pending_default < 0.0:
			_apply("")
	_blend(delta)
	_drift_clouds(delta)
	for g in graves:
		g["alpha"] = move_toward(g["alpha"], g["target"], delta * 2.0)
	# Lightning in the storm.
	flash = maxf(flash - delta * 2.5, 0.0)
	if LOOKS[look]["storm"] > 0.0:
		storm_cd -= delta
		if storm_cd <= 0.0:
			storm_cd = randf_range(2.0, 4.5)
			flash = 1.0
			bolt_path = PackedVector2Array()
			var p := Vector2(randf_range(40, 600), 0)
			while p.y < 360.0:
				bolt_path.append(p)
				p += Vector2(randf_range(-30, 30), randf_range(30, 60))
			bolt_path.append(p)
	_update_actors(delta)
	queue_redraw()


## The visible part of the scene across: wider than 640 on a wide window.
func _view_x() -> Vector2:
	var inv := get_global_transform_with_canvas().affine_inverse()
	return Vector2((inv * Vector2.ZERO).x, (inv * Vector2(get_viewport_rect().size.x, 0)).x)


func _new_cloud(x: float) -> Dictionary:
	return {"pos": Vector2(x, randf_range(20, 330)), "scale": randf_range(0.7, 1.6), "speed": randf_range(12, 24),
			"seed": randi(), "leaving": false}


## Clouds never pop in or out: a look that wants more lets new ones drift in from the
## left edge, one that wants fewer lets the extras sail off the right edge.
func _drift_clouds(delta: float) -> void:
	var view := _view_x()
	var want: int = LOOKS[look]["clouds"]
	var staying := clouds.filter(func(c): return not c["leaving"])
	for i in range(staying.size() - 1, want - 1, -1):
		staying[i]["leaving"] = true
	cloud_cd -= delta
	if staying.size() < want and cloud_cd <= 0.0:
		cloud_cd = randf_range(0.6, 1.4)
		var c := _new_cloud(0.0)
		c["pos"] = Vector2(view.x - 160.0 * c["scale"], c["pos"].y)   # wholly out of sight to start with
		clouds.append(c)
	var gust: float = 1.0 + cur["storm"] * 1.5
	for c in clouds.duplicate():
		c["pos"] = c["pos"] + Vector2(c["speed"] * delta * gust, 0)
		if c["pos"].x - 160.0 * c["scale"] > view.y:
			clouds.erase(c)   # off the right edge (a staying cloud is replaced by one drifting in)


## Ease the colours and numbers of the scene towards the look being shown.
func _blend(delta: float) -> void:
	var k := 1.0 - exp(-delta * 5.0)
	var target: Dictionary = LOOKS[look]
	for key in ["top", "low", "cloud", "light"]:
		cur[key] = (cur[key] as Color).lerp(target[key], k)
	for key in ["sun", "moon", "stars", "windows", "storm"]:
		cur[key] = lerpf(cur[key], target[key], k)


func _update_actors(delta: float) -> void:
	var scene: String = LOOKS[look]["scene"]
	if scene in FIGHTS:
		spawn_cd -= delta
		var foes := actors.filter(func(a): return a["side"] == "foe" and not a["leaving"])
		if spawn_cd <= 0.0 and foes.size() < 5:
			spawn_cd = randf_range(0.9, 1.8)
			_spawn_foe()
	_scene_step(scene, delta)
	for a in actors.duplicate():
		a["alpha"] = move_toward(a["alpha"], 0.0 if a["leaving"] else 1.0, delta * 3.0)
		if a["leaving"] and a["alpha"] <= 0.0:
			actors.erase(a)
			continue
		a["lunge"] = maxf(a["lunge"] - delta, 0.0)
		a["hop"] = maxf(a["hop"] - delta, 0.0)
		a["hurt"] = maxf(a["hurt"] - delta, 0.0)
		a["cd"] -= delta
		if a["leaving"]:
			continue
		match a["side"]:
			"foe":
				_foe_step(a, delta)
			"guard":
				_guard_step(a)
	for b in bolts.duplicate():
		b["at"] += delta * 400.0 / maxf(b["len"], 1.0)
		if b["at"] >= 1.0:
			bolts.erase(b)
			var hit = _actor_by_id(b["target"])
			if hit != null:
				_hit(hit, b["color"])
	for p in pops.duplicate():
		p["age"] += delta
		if p["age"] > 0.5:
			pops.erase(p)


func _foe_step(a: Dictionary, delta: float) -> void:
	if a["hop"] > 0.0:
		# Knocked back (Hold the Pass): flung away before it comes on again.
		a["pos"] = a["pos"] + Vector2(90.0 * delta, 0)
		return
	var g
	var stop := 230.0
	if LOOKS[look]["scene"] in ["battle", "conjure"]:
		g = _nearest(a, "guard")
		if g != null and not g["kind"] in RANGED:
			stop = g["pos"].x + 34.0
	else:
		# The first thing in its way: a fighter (not a ranged one or an Engineer), or what's being defended.
		g = _blocker(a)
		if g != null:
			stop = g["pos"].x + 34.0
	if a["pos"].x > stop:
		a["pos"] = a["pos"] + Vector2(-a.get("speed", 34.0) * delta, 0)
	else:
		a["pos"].x = maxf(a["pos"].x, stop - 4.0)   # pushed along by a guard on the move (the convoy)
		if a["cd"] <= 0.0 and g != null:
			a["cd"] = 0.8
			a["lunge"] = 0.3
			if g["side"] == "prop":
				g["hurt"] = 0.25   # it shakes under the blow
			else:
				g["lunge"] = 0.2
			_hit(a, Color(1, 1, 0.85))
			if LOOKS[look].get("bounce", false) and a["side"] == "foe" and actors.has(a):
				a["hop"] = 0.4


func _blocker(a: Dictionary) -> Variant:
	var best = null
	for b in actors:
		if b["leaving"] or b["pos"].x > a["pos"].x + 10.0:
			continue
		var blocks: bool = b.get("objective", false) or (b["side"] == "guard" and not b["kind"] in RANGED and b["kind"] != "engineer")
		if blocks and (best == null or b["pos"].x > best["pos"].x):
			best = b
	return best


## What each Battle Modes scene does besides the fighting: the convoy rolls on, the line
## steps back, villagers set out for the gate.
func _scene_step(scene: String, delta: float) -> void:
	match scene:
		"escort":
			var wagon = _prop("wagon")
			if wagon == null:
				return
			wagon["pos"].x += WAGON_SPEED * delta
			if wagon["pos"].x > 780.0:
				wagon["pos"].x = -150.0   # round again, from the left
			for a in actors:
				if a["role"] == "escort" and not a["leaving"]:
					a["pos"] = wagon["pos"] + a["off"]
		"retreat":
			step_cd -= delta
			if step_cd <= 0.0:
				step_cd = RETREAT_STEP
				steps += 1
				if steps > 4:
					_cast()   # back to where the line started
					return
				for a in actors:
					if a["side"] == "guard" and not a["leaving"]:
						a["back_to"] = a["pos"].x - 44.0
			for a in actors:
				if a.has("back_to") and not a["leaving"]:
					a["pos"].x = move_toward(a["pos"].x, a["back_to"], 70.0 * delta)
		"evac":
			var walkers := actors.filter(func(a): return a["side"] == "walker" and not a["leaving"])
			if walkers.size() < 4 and fmod(scene_t, 1.3) < delta:
				var kind: String = ["villager", "villager_woman", "villager_child", "villager_elder"][randi() % 4]
				var from: Vector2 = [Vector2(76, ROWS[0] - 4), Vector2(168, ROWS[0] - 12)][randi() % 2]
				_add_actor(kind, from, "walker")
			for a in walkers:
				# Along the field, then up the road and in at the gate.
				var to := Vector2(320, a["pos"].y) if a["pos"].x < 300.0 else Vector2(320, GROUND_Y + 6)
				a["pos"] = a["pos"].move_toward(to, 30.0 * delta)
				if a["pos"].y <= GROUND_Y + 12.0:
					a["leaving"] = true


func _guard_step(a: Dictionary) -> void:
	if a["cd"] > 0.0:
		return
	match a["role"]:
		"archery":
			a["cd"] = 1.1
			_shoot(a, _prop("target"))
		"dummy":
			a["cd"] = 0.7
			a["lunge"] = 0.25
			var d = _prop("dummy")
			if d != null:
				d["hurt"] = 0.25   # the dummy wobbles
		"spar", "spar_r":
			a["cd"] = 0.9
			a["lunge"] = 0.3
		"fight", "escort":
			if a["kind"] in RANGED:
				var e = _nearest(a, "foe")
				if e != null and e["pos"].x < 640.0:
					a["cd"] = randf_range(0.9, 1.4)
					if a["kind"] == "healer":
						a["lunge"] = 0.15
					else:
						_shoot(a, e)


func _shoot(a: Dictionary, target) -> void:
	if target == null:
		return
	a["lunge"] = 0.15
	var from: Vector2 = a["pos"] + Vector2(14, -18)
	bolts.append({"from": from, "target": target["id"], "at": 0.0, "color": BOLT_COLORS.get(a["kind"], Color.WHITE),
			"len": from.distance_to(target["pos"])})


func _hit(a: Dictionary, color: Color) -> void:
	a["hurt"] = 0.15
	if a["side"] != "foe":
		return
	a["hp"] -= 1
	if a["hp"] <= 0:
		actors.erase(a)
		pops.append({"pos": a["pos"] + Vector2(0, -16), "age": 0.0, "color": color, "ring": false})


func _actor_by_id(id: int) -> Variant:
	for a in actors:
		if a["id"] == id and not a["leaving"]:
			return a
	return null


func _prop(kind: String) -> Variant:
	for a in actors:
		if a["kind"] == kind and not a["leaving"]:
			return a
	return null


func _nearest(a: Dictionary, side: String) -> Variant:
	var best = null
	for b in actors:
		if b["side"] != side or b["leaving"]:
			continue
		if best == null or a["pos"].distance_squared_to(b["pos"]) < a["pos"].distance_squared_to(best["pos"]):
			best = b
	return best


# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	var light: Color = cur["light"]
	_draw_sky()
	_draw_birds(light)
	_draw_land(light)
	_draw_beacon_fires(light)
	_draw_castle(light)
	_draw_ground(light)
	_draw_actors(light)
	_draw_rain()
	for b in bolts:
		var target = _actor_by_id(b["target"])
		if target == null:
			continue
		var p: Vector2 = b["from"].lerp(target["pos"] + Vector2(0, -16), b["at"])
		draw_circle(p, 4.5, Color(b["color"], 0.35))
		draw_circle(p, 2.5, b["color"])
	for p in pops:
		var k: float = p["age"] / 0.5
		if p["ring"]:
			draw_arc(p["pos"] + Vector2(0, 12), 10.0 + 18.0 * k, 0, TAU, 24, Color(p["color"], 1.0 - k), 3.0, true)
			continue
		for i in 8:
			var d := Vector2.from_angle(i * TAU / 8.0) * (6.0 + 24.0 * k)
			draw_circle(p["pos"] + d, 3.0 * (1.0 - k), Color(p["color"], 1.0 - k))
	if flash > 0.0:
		draw_rect(Rect2(-1000, -1000, W + 2000, EARTH_Y + 1000), Color(1, 0.95, 1.0, 0.25 * flash))
		if bolt_path.size() > 1:
			draw_polyline(bolt_path, Color(1, 1, 1, flash), 3.0)
	_draw_title()


func _draw_sky() -> void:
	var top: Color = cur["top"]
	var low: Color = cur["low"]
	var bands := 24
	for i in bands:
		var y0 := -1000.0 if i == 0 else 470.0 * i / bands
		var y1 := 470.0 * (i + 1) / bands
		draw_rect(Rect2(-1000, y0, W + 2000, y1 - y0 + 1.0), top.lerp(low, float(i) / (bands - 1)))
	draw_rect(Rect2(-1000, 470, W + 2000, 60), low)
	if cur["stars"] > 0.01:
		for i in stars.size():
			var tw := 0.6 + 0.4 * sin(t * 2.0 + i * 1.7)
			draw_rect(Rect2(stars[i], Vector2(2, 2)), Color(1, 1, 0.9, cur["stars"] * tw))
	if cur["sun"] > 0.01:
		var sp := Vector2(548, 200)
		draw_circle(sp, 46.0, Color(1, 0.95, 0.6, 0.18 * cur["sun"]))
		draw_circle(sp, 32.0, Color(1, 0.92, 0.5, cur["sun"]))
		draw_circle(sp, 26.0, Color(1, 0.98, 0.75, cur["sun"]))
	if cur["moon"] > 0.01:
		var mp := Vector2(92, 196)
		var mc := Color(0.95, 0.93, 0.82).lerp(Color(1.0, 0.45, 0.35), cur["storm"])
		draw_circle(mp, 40.0, Color(mc, 0.15 * cur["moon"]))
		draw_circle(mp, 26.0, Color(mc, cur["moon"]))
		draw_circle(mp + Vector2(-8, -5), 5.0, Color(mc.darkened(0.15), cur["moon"]))
		draw_circle(mp + Vector2(7, 8), 3.5, Color(mc.darkened(0.15), cur["moon"]))
	for c in clouds:
		_draw_cloud(c["pos"], c["scale"], c["seed"], cur["cloud"])


## A puffy pixel cloud: overlapping lumps on a flat base, shaded underneath.
func _draw_cloud(at: Vector2, s: float, seed_: int, col: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var lumps := 4 + rng.randi() % 3
	var shade := Color(col.darkened(0.18), col.a)
	for pass_ in 2:
		for i in lumps:
			var x := (i - (lumps - 1) / 2.0) * 22.0 * s
			var r := (16.0 + rng.randf() * 12.0) * s
			var y := -r * 0.35
			if pass_ == 0:
				draw_circle(at + Vector2(x, y + 5 * s), r, shade)
			else:
				draw_circle(at + Vector2(x, y), r * 0.92, col)
		rng.seed = seed_
		rng.randi()


func _draw_hills(light: Color) -> void:
	var far := Color(0.42, 0.58, 0.5) * light
	var near := Color(0.32, 0.5, 0.3) * light
	for layer in 2:
		var pts := PackedVector2Array()
		var base: float = 430.0 + layer * 40.0
		pts.append(Vector2(-1000, GROUND_Y + 10))
		var x := -1000.0
		while x <= W + 1000.0:
			pts.append(Vector2(x, base - (sin(x * 0.011 + layer * 2.0) * 22.0 + sin(x * 0.027 + layer) * 10.0)))
			x += 20.0
		pts.append(Vector2(W + 1000, GROUND_Y + 10))
		_poly(pts, far if layer == 0 else near)
		if layer == 0:
			_draw_lands(light, true)
		else:
			_draw_quarry(light)


## The castle seen from the front, as detailed pixel art: a keep behind with a corner
## turret, a gatehouse with a carved arch, portcullis, doors and torches, curtain walls
## with guards walking the battlements, and two round towers with overhanging
## battlements, shingled roofs, banners and flags. Lit from the top left; windows
## glow at night (the look's "windows").
func _draw_castle(light: Color) -> void:
	var stone := Color(0.66, 0.64, 0.6)
	var dark := Color(0.5, 0.48, 0.47)
	var deep := Color(0.4, 0.38, 0.4)
	var roof := Color(0.6, 0.2, 0.2)
	var glow: float = cur["windows"]
	# A shadow on the grass along the foot.
	draw_rect(Rect2(76, GROUND_Y - 2, 488, 10), Color(0, 0, 0, 0.22))
	# A tall tower in the middle, behind the keep, rising over its battlements.
	var spire := Rect2(302, 212, 36, 60)
	_stones(spire, deep.darkened(0.08), light, 2)
	_round_shade(spire, light)
	_corbels(298, 342, 212, deep, light)
	_cone(320.0, 212.0, 24.0, 32.0, roof, light)
	_slit(Vector2(320, 228), light, glow)
	# The keep, in front of it.
	_stones(Rect2(258, 252, 124, 180), deep, light, 1)
	_shade(Rect2(258, 252, 124, 180), light, 0.18)
	_corbels(258, 382, 252, deep, light)
	_crenels(254, 386, 240, deep, light)
	_arch_window(Vector2(292, 300), 12, 22, glow, light)
	_arch_window(Vector2(348, 300), 12, 22, glow, light)
	_arch_window(Vector2(320, 352), 14, 26, glow, light)
	_flag(Vector2(374, 200), 28.0, Color(0.85, 0.2, 0.2) * light)
	# Guards walking the battlements, behind the parapet.
	for i in 2:
		var span := 36.0
		var x: float = (198.0 if i == 0 else 442.0) + sin(t * 0.35 + i * 2.0) * span
		var dir := signf(cos(t * 0.35 + i * 2.0))
		var tex: Texture2D = Sprites.step(Sprites.frames("archer" if i == 0 else "swordsman"), int(t * 4.0))
		draw_set_transform(Vector2(x, 392), 0, Vector2(dir * 1.6, 1.6))
		draw_texture_rect(tex, Rect2(Vector2(-8, -16), Vector2(16, 16)), false, Color(light, 1))
		draw_set_transform(Vector2.ZERO)
	# Curtain walls.
	for r in [Rect2(150, 398, 100, GROUND_Y - 398), Rect2(390, 398, 100, GROUND_Y - 398)]:
		_stones(r, dark, light, 3)
		_crenels(r.position.x - 2, r.end.x + 2, r.position.y - 12, dark, light)
		_plinth(r, dark, light)
		for k in 2:
			_slit(Vector2(r.position.x + 30 + k * 40, 452), light, glow)
	_ivy(Vector2(162, 470), 3, light)
	_ivy(Vector2(470, 486), 2, light)
	# Towers: round, so shaded across, with banners hanging down their fronts.
	for tx in [88.0, 468.0]:
		var body := Rect2(tx, 330, 84, GROUND_Y - 330)
		_stones(body, stone, light, 4 + int(tx))
		_round_shade(body, light)
		_plinth(body, stone, light)
		_corbels(tx - 6, tx + 90, 330, stone, light)
		_crenels(tx - 8, tx + 92, 318, stone, light)
		_cone(tx + 42.0, 318.0, 50.0, 78.0, roof, light)
		_flag(Vector2(tx + 42, 222), 18.0, Color(0.95, 0.8, 0.25) * light)
		_hanging_banner(Vector2(tx + 42, 344), light, false)   # both towers red; the gate banner is blue
		_arch_window(Vector2(tx + 42, 430), 10, 18, glow, light)
		_slit(Vector2(tx + 42, 480), light, glow)
	_ivy(Vector2(100, 500), 2, light)
	# Gatehouse.
	var gh := Rect2(246, 350, 148, GROUND_Y - 350)
	_stones(gh, stone, light, 9)
	_shade(gh, light, 0.08)
	_plinth(gh, stone, light)
	_corbels(240, 400, 350, stone, light)
	_crenels(238, 402, 338, stone, light)
	_gate(Vector2(320, 450), light)
	for side in [-1.0, 1.0]:
		_torch(Vector2(320 + side * 62.0, 444), light, glow)
	# The crest over the gate.
	var wave := sin(t * 2.0) * 2.0
	var banner := PackedVector2Array([Vector2(302, 362), Vector2(338, 362), Vector2(338 + wave, 392), Vector2(320, 385), Vector2(302 + wave, 392)])
	draw_colored_polygon(banner, Color(0.25, 0.38, 0.75) * light)
	draw_polyline(banner + PackedVector2Array([banner[0]]), OUTLINE, 2.0)
	draw_rect(Rect2(300, 359, 40, 4), Color(0.45, 0.3, 0.15) * light)
	_crest(Vector2(320, 374), light)


## Deterministic jitter for a block, so the stonework doesn't shimmer frame to frame.
static func _rand(x: float, y: float, s: int) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233 + s * 3.7) * 43758.5453, 1.0)


## Coursed stone: blocks a little different in tone, light along their tops and dark
## mortar between, rows staggered.
func _stones(r: Rect2, col: Color, light: Color, s: int) -> void:
	var mortar := col.darkened(0.42) * light
	draw_rect(r.grow(2), OUTLINE)
	draw_rect(r, mortar)
	var bh := 10.0
	var row := 0
	var y := r.position.y
	while y < r.end.y:
		var h := minf(bh, r.end.y - y)
		var bw: float = 20.0
		var x: float = r.position.x - (10.0 if row % 2 == 1 else 0.0)
		while x < r.end.x:
			var x0 := maxf(x, r.position.x)
			var x1 := minf(x + bw, r.end.x)
			if x1 - x0 > 1.5:
				var k := _rand(x, y, s)
				var c := col.lerp(col.lightened(0.12) if k > 0.5 else col.darkened(0.12), absf(k - 0.5) * 1.6) * light
				var b := Rect2(x0 + (0.0 if x0 == r.position.x else 1.0), y + 1.0, x1 - x0 - 1.0, h - 1.0)
				draw_rect(b, c)
				draw_rect(Rect2(b.position, Vector2(b.size.x, 1.0)), c.lightened(0.18))
				if k > 0.86:
					# A chipped or cracked stone here and there.
					draw_line(b.position + Vector2(b.size.x * 0.3, 2), b.position + Vector2(b.size.x * 0.5, b.size.y - 1), mortar, 1.0)
			x += bw
		y += bh
		row += 1


## A flat wall's shading: darker towards the right, away from the light.
func _shade(r: Rect2, _light: Color, amount: float) -> void:
	var bands := 6
	for i in bands:
		var k := float(i) / bands
		if k < 0.5:
			continue
		draw_rect(Rect2(r.position.x + r.size.x * k, r.position.y, r.size.x / bands + 1.0, r.size.y), Color(0, 0, 0, amount * (k - 0.5) * 2.0))


## A round tower's shading: a lit stripe on the left, deepening shadow round the right.
func _round_shade(r: Rect2, _light: Color) -> void:
	var bands := 10
	for i in bands:
		var k := (i + 0.5) / bands
		var w := r.size.x / bands
		var x := r.position.x + i * w
		if k < 0.3:
			draw_rect(Rect2(x, r.position.y, w + 0.5, r.size.y), Color(1, 1, 0.9, 0.1 * (1.0 - k / 0.3)))
		elif k > 0.55:
			draw_rect(Rect2(x, r.position.y, w + 0.5, r.size.y), Color(0, 0, 0, 0.32 * (k - 0.55) / 0.45))


## Larger, darker foundation stones along the bottom.
func _plinth(r: Rect2, col: Color, light: Color) -> void:
	var base := Rect2(r.position.x - 3, r.end.y - 12, r.size.x + 6, 12)
	draw_rect(base.grow(1.5), OUTLINE)
	draw_rect(base, col.darkened(0.3) * light)
	draw_line(base.position + Vector2(0, 1), Vector2(base.end.x, base.position.y + 1), col.darkened(0.1) * light, 1.0)
	var x := base.position.x + 14.0
	while x < base.end.x:
		draw_line(Vector2(x, base.position.y + 2), Vector2(x, base.end.y), col.darkened(0.5) * light, 1.0)
		x += 28.0


## Stone brackets under an overhanging parapet, with dark gaps between.
func _corbels(x0: float, x1: float, y: float, col: Color, light: Color) -> void:
	draw_rect(Rect2(x0, y - 4, x1 - x0, 5).grow(1), OUTLINE)
	draw_rect(Rect2(x0, y - 4, x1 - x0, 5), col.darkened(0.1) * light)
	var x := x0 + 3.0
	while x < x1 - 6.0:
		draw_rect(Rect2(x, y + 1, 6, 6), OUTLINE)
		draw_rect(Rect2(x + 1, y + 1, 4, 4), col.darkened(0.2) * light)
		x += 10.0


## Battlements: a parapet band with merlons, each lit on top and shaded on its right.
func _crenels(x0: float, x1: float, y: float, col: Color, light: Color) -> void:
	var c := col * light
	draw_rect(Rect2(x0, y + 8, x1 - x0, 6).grow(1.5), OUTLINE)
	draw_rect(Rect2(x0, y + 8, x1 - x0, 6), c)
	var n := maxi(2, int((x1 - x0) / 17.0))
	var w := (x1 - x0) / n
	for i in n:
		var m := Rect2(x0 + i * w + 2.0, y - 2, w - 6.0, 10)
		draw_rect(m.grow(1.5), OUTLINE)
		draw_rect(m, c)
		draw_rect(Rect2(m.position, Vector2(m.size.x, 2)), c.lightened(0.2))
		draw_rect(Rect2(m.end.x - 2, m.position.y, 2, m.size.y), c.darkened(0.2))


## A tall pointed roof of overlapping shingles, lit on the left, with a gold finial.
func _cone(cx: float, base_y: float, half_w: float, h: float, col: Color, light: Color) -> void:
	var apex := Vector2(cx, base_y - h)
	var l := Vector2(cx - half_w, base_y)
	var r := Vector2(cx + half_w, base_y)
	draw_colored_polygon(PackedVector2Array([l + Vector2(-3, 2), r + Vector2(3, 2), apex + Vector2(0, -4)]), OUTLINE)
	draw_colored_polygon(PackedVector2Array([l, Vector2(cx, base_y), apex]), col.lightened(0.08) * light)
	draw_colored_polygon(PackedVector2Array([Vector2(cx, base_y), r, apex]), col.darkened(0.22) * light)
	# Rows of shingles: a seam across each row, with staggered scallops.
	var rows := int(h / 7.0)
	for i in range(1, rows):
		var k := float(i) / rows
		var y := base_y - h * (1.0 - k)
		var hw := half_w * k
		var seam := col.darkened(0.4) * light
		draw_line(Vector2(cx - hw, y), Vector2(cx + hw, y), seam, 1.0)
		var step := 6.0
		var x := cx - hw + (step / 2.0 if i % 2 == 1 else 0.0)
		while x < cx + hw - 1.0:
			draw_line(Vector2(x, y - 4), Vector2(x, y), seam, 1.0)
			x += step
	draw_line(l, r, OUTLINE, 3.0)
	draw_line(apex, apex + Vector2(0, -10), OUTLINE, 2.0)
	draw_circle(apex + Vector2(0, -4), 3.0, OUTLINE)
	draw_circle(apex + Vector2(0, -4), 2.0, Color(1.0, 0.82, 0.3) * light)


## An arched window in a stone frame, with a cross of leading; dark by day, lamplit at night.
func _arch_window(c: Vector2, w: float, h: float, glow: float, light: Color) -> void:
	var frame := Color(0.78, 0.76, 0.72) * light
	var inside := Color(0.08, 0.07, 0.1).lerp(Color(1.0, 0.78, 0.35), glow * (0.85 + 0.15 * sin(t * 3.0 + c.x)))
	var top := c.y - h / 2.0 + w / 2.0
	draw_rect(Rect2(c.x - w / 2.0 - 3, top, w + 6, h / 2.0 + w / 2.0 + 3), OUTLINE)
	draw_circle(Vector2(c.x, top), w / 2.0 + 3, OUTLINE)
	draw_rect(Rect2(c.x - w / 2.0 - 2, top, w + 4, h / 2.0 + w / 2.0 + 2), frame)
	draw_circle(Vector2(c.x, top), w / 2.0 + 2, frame)
	draw_rect(Rect2(c.x - w / 2.0, top, w, h / 2.0 + w / 2.0), inside)
	draw_circle(Vector2(c.x, top), w / 2.0, inside)
	draw_line(Vector2(c.x, top - w / 2.0), Vector2(c.x, c.y + h / 2.0), OUTLINE, 1.5)
	draw_line(Vector2(c.x - w / 2.0, top + 3), Vector2(c.x + w / 2.0, top + 3), OUTLINE, 1.5)
	draw_rect(Rect2(c.x - w / 2.0 - 4, c.y + h / 2.0, w + 8, 3), frame.darkened(0.1))   # sill
	if glow > 0.05:
		draw_circle(c, w * 1.4, Color(1.0, 0.8, 0.4, 0.08 * glow))


## An arrow slit with a widened base.
func _slit(c: Vector2, light: Color, glow: float) -> void:
	var inside := Color(0.08, 0.07, 0.1).lerp(Color(1.0, 0.75, 0.3), glow * 0.7)
	draw_rect(Rect2(c.x - 3, c.y - 11, 6, 22), Color(0.75, 0.73, 0.7) * light)
	draw_rect(Rect2(c.x - 1.5, c.y - 10, 3, 20), inside)
	draw_rect(Rect2(c.x - 4, c.y - 1.5, 8, 3), inside)


## The gate: a ring of wedge-shaped stones round the arch with a keystone at the top,
## oak doors with iron straps in the opening, and the portcullis down in front.
func _gate(c: Vector2, light: Color) -> void:
	var r_in := 36.0
	var r_out := 47.0
	var stones := 11
	for i in stones:
		var a0 := PI + PI * i / stones
		var a1 := PI + PI * (i + 1) / stones
		var pts := PackedVector2Array([c + Vector2.from_angle(a0) * r_in, c + Vector2.from_angle(a0) * r_out,
				c + Vector2.from_angle(a1) * r_out, c + Vector2.from_angle(a1) * r_in])
		var key := i == stones / 2
		var col := Color(0.8, 0.78, 0.72) if key else (Color(0.7, 0.68, 0.64) if i % 2 == 0 else Color(0.62, 0.6, 0.57))
		draw_colored_polygon(pts, col * light)
		draw_polyline(pts + PackedVector2Array([pts[0]]), OUTLINE, 1.5)
	# Jambs down to the ground.
	for side in [-1.0, 1.0]:
		var jx: float = c.x + side * (r_in + 5.5)
		draw_rect(Rect2(jx - 5.5, c.y, 11, GROUND_Y - c.y).grow(1), OUTLINE)
		draw_rect(Rect2(jx - 5.5, c.y, 11, GROUND_Y - c.y), Color(0.7, 0.68, 0.64) * light)
		for y in range(int(c.y) + 12, int(GROUND_Y), 12):
			draw_line(Vector2(jx - 5.5, y), Vector2(jx + 5.5, y), OUTLINE, 1.0)
	# The opening, the doors and the portcullis.
	var hole := PackedVector2Array()
	for i in 25:
		hole.append(c + Vector2.from_angle(PI + PI * i / 24.0) * r_in)
	hole.append(Vector2(c.x + r_in, GROUND_Y))
	hole.append(Vector2(c.x - r_in, GROUND_Y))
	draw_colored_polygon(hole, Color(0.1, 0.07, 0.06))
	var oak := Color(0.46, 0.3, 0.17) * light
	for i in 7:
		var x0 := c.x - r_in + 4 + i * 9.7
		var top := c.y - sqrt(maxf(0.0, r_in * r_in - pow(x0 + 4.5 - c.x, 2))) + 6.0
		draw_rect(Rect2(x0, top, 8.5, GROUND_Y - top), oak if i % 2 == 0 else oak.darkened(0.12))
	draw_line(Vector2(c.x, c.y - r_in + 6), Vector2(c.x, GROUND_Y), OUTLINE, 2.0)
	for y in [c.y + 6.0, c.y + 44.0]:
		draw_line(Vector2(c.x - r_in + 4, y), Vector2(c.x + r_in - 4, y), Color(0.3, 0.3, 0.34) * light, 3.0)
	draw_circle(Vector2(c.x - 6, c.y + 26), 2.0, Color(0.75, 0.7, 0.5) * light)
	draw_circle(Vector2(c.x + 6, c.y + 26), 2.0, Color(0.75, 0.7, 0.5) * light)
	var iron := Color(0.24, 0.24, 0.27) * light
	for i in 7:
		var gx := c.x - r_in + 6 + i * 10.0
		var top := c.y - sqrt(maxf(0.0, r_in * r_in - pow(gx - c.x, 2)))
		draw_line(Vector2(gx, top), Vector2(gx, GROUND_Y - 4), OUTLINE, 3.5)
		draw_line(Vector2(gx, top), Vector2(gx, GROUND_Y - 4), iron.lightened(0.15), 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(gx - 2.5, GROUND_Y - 5), Vector2(gx + 2.5, GROUND_Y - 5), Vector2(gx, GROUND_Y)]), iron)
	for gy in [c.y - 16.0, c.y + 10.0, c.y + 36.0, c.y + 60.0]:
		draw_line(Vector2(c.x - r_in + 2, gy), Vector2(c.x + r_in - 2, gy), OUTLINE, 3.5)
		draw_line(Vector2(c.x - r_in + 2, gy), Vector2(c.x + r_in - 2, gy), iron.lightened(0.15), 1.5)


## A torch in an iron bracket, flickering, with a pool of light round it at night.
func _torch(at: Vector2, light: Color, glow: float) -> void:
	var f := 0.8 + 0.2 * sin(t * 13.0 + at.x) * sin(t * 7.3)
	draw_circle(at + Vector2(0, -8), 26.0 * f, Color(1.0, 0.65, 0.25, 0.08 + 0.14 * glow))
	draw_rect(Rect2(at.x - 4, at.y + 2, 8, 3), OUTLINE)
	draw_rect(Rect2(at.x - 2, at.y - 6, 4, 10), OUTLINE)
	draw_rect(Rect2(at.x - 1, at.y - 5, 2, 8), Color(0.45, 0.3, 0.15) * light)
	var flame := PackedVector2Array([at + Vector2(-4, -6), at + Vector2(4, -6), at + Vector2(sin(t * 9.0) * 2.0, -16 - 3 * f)])
	draw_colored_polygon(flame, Color(1.0, 0.55, 0.15))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-2, -6), at + Vector2(2, -6), at + Vector2(sin(t * 9.0), -12 - 2 * f)]), Color(1.0, 0.9, 0.45))


## A long banner hanging down a tower, its tail swaying.
func _hanging_banner(top: Vector2, light: Color, blue: bool) -> void:
	var cloth := (Color(0.25, 0.38, 0.75) if blue else Color(0.72, 0.18, 0.18)) * light
	var sway := sin(t * 1.6 + top.x) * 1.5
	var pts := PackedVector2Array([top + Vector2(-11, 0), top + Vector2(11, 0), top + Vector2(11 + sway, 50),
			top + Vector2(sway, 42), top + Vector2(-11 + sway, 50)])
	draw_rect(Rect2(top + Vector2(-14, -3), Vector2(28, 4)), Color(0.4, 0.28, 0.14) * light)
	draw_colored_polygon(pts, cloth)
	draw_colored_polygon(PackedVector2Array([top + Vector2(5, 0), top + Vector2(11, 0), top + Vector2(11 + sway, 50), top + Vector2(5 + sway, 45)]), cloth.darkened(0.2))
	draw_polyline(pts + PackedVector2Array([pts[0]]), OUTLINE, 1.5)
	draw_line(top + Vector2(-8, 4), top + Vector2(8, 4), Color(1.0, 0.82, 0.3) * light, 1.5)
	# A sword picked out in gold.
	draw_line(top + Vector2(0, 10), top + Vector2(sway * 0.5, 34), Color(1.0, 0.85, 0.35) * light, 2.0)
	draw_line(top + Vector2(-5, 15), top + Vector2(5, 15), Color(1.0, 0.85, 0.35) * light, 2.0)


## The gold shield on the gate banner.
func _crest(c: Vector2, light: Color) -> void:
	var gold := Color(1.0, 0.82, 0.3) * light
	var pts := PackedVector2Array([c + Vector2(-6, -6), c + Vector2(6, -6), c + Vector2(6, 1), c + Vector2(0, 7), c + Vector2(-6, 1)])
	draw_colored_polygon(pts, gold)
	draw_polyline(pts + PackedVector2Array([pts[0]]), OUTLINE, 1.0)
	draw_line(c + Vector2(0, -5), c + Vector2(0, 5), Color(0.72, 0.16, 0.16) * light, 1.5)


## A clump of ivy creeping up the stones.
func _ivy(at: Vector2, size: int, light: Color) -> void:
	for i in size * 7:
		var p := at + Vector2(_rand(i, size, 1) * 20.0 * size - 10.0 * size, -_rand(i, size, 2) * 18.0 * size)
		var c := Color(0.22, 0.42, 0.18) if i % 3 else Color(0.32, 0.55, 0.24)
		draw_rect(Rect2(p, Vector2(4, 3)), c * light)
		draw_rect(Rect2(p + Vector2(1, 3), Vector2(1, 2)), Color(0.18, 0.3, 0.14) * light)


## A pennant on a pole, rippling.
func _flag(top: Vector2, h: float, col: Color) -> void:
	draw_line(top, top + Vector2(0, h + 12), OUTLINE, 3.0)
	var pts := PackedVector2Array()
	for i in 7:
		var x := i * 5.0
		pts.append(top + Vector2(x, sin(t * 4.0 - i * 0.8) * 2.5 * i / 6.0))
	for i in range(6, -1, -1):
		var x := i * 5.0
		pts.append(top + Vector2(x, 16 + sin(t * 4.0 - i * 0.8) * 2.5 * i / 6.0))
	draw_colored_polygon(pts, col)
	draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[2], pts[11], pts[12], pts[13]]), col.lightened(0.15))
	draw_polyline(pts + PackedVector2Array([pts[0]]), OUTLINE, 1.5)


func _draw_ground(light: Color) -> void:
	draw_rect(Rect2(-1000, GROUND_Y, W + 2000, EARTH_Y - GROUND_Y), Color(0.33, 0.56, 0.26) * light)
	draw_rect(Rect2(-1000, GROUND_Y, W + 2000, 3), Color(0.25, 0.42, 0.2) * light)
	# A dirt road from the gate.
	draw_colored_polygon(PackedVector2Array([Vector2(286, GROUND_Y), Vector2(354, GROUND_Y), Vector2(400, EARTH_Y), Vector2(240, EARTH_Y)]),
			Color(0.6, 0.47, 0.3) * light)
	# Tufts of grass.
	for i in 40:
		var x := fmod(i * 97.3, W + 200.0) - 100.0
		var y := GROUND_Y + 8.0 + fmod(i * 37.1, EARTH_Y - GROUND_Y - 16.0)
		draw_line(Vector2(x, y), Vector2(x - 2, y - 5), Color(0.24, 0.44, 0.2) * light, 1.5)
		draw_line(Vector2(x, y), Vector2(x + 2, y - 5), Color(0.24, 0.44, 0.2) * light, 1.5)
	# The earth below, where the cards sit.
	draw_rect(Rect2(-1000, EARTH_Y, W + 2000, H - EARTH_Y + 1000), Color(0.2, 0.14, 0.1) * light)
	draw_rect(Rect2(-1000, EARTH_Y, W + 2000, 6), Color(0.27, 0.4, 0.18) * light)
	for i in 50:
		var p := Vector2(fmod(i * 131.7, W + 160.0) - 80.0, EARTH_Y + 18.0 + fmod(i * 71.3, H - EARTH_Y - 20.0))
		draw_circle(p, 3.0 + (i % 3), Color(0.28, 0.21, 0.16) * light)


## A construction site for an emplacement that isn't built yet: a stone foundation
## with its first rough courses laid, a timber frame with a crossbeam and a ladder,
## a stack of planks, a pile of stones and a mortar bucket. `variant` changes the
## layout a little between the two sites.
func _draw_site(p: Vector2, variant: float, alpha: float, light: Color) -> void:
	var lit := Color(light, 1)
	var ink := Color(0.1, 0.07, 0.1, alpha)
	var stone := Color(0.66, 0.64, 0.6, alpha) * lit
	var stone_dk := Color(0.5, 0.48, 0.46, alpha) * lit
	var wood := Color(0.6, 0.42, 0.22, alpha) * lit
	var wood_dk := Color(0.42, 0.28, 0.14, alpha) * lit
	var flip := -1.0 if variant > 0.15 else 1.0   # the second site is laid out the other way round
	draw_set_transform(p + Vector2(0, 3), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 34.0, Color(0, 0, 0, 0.2 * alpha))
	draw_set_transform(Vector2.ZERO)
	# Foundation: a wide footing and two rough courses of stone, the top one half laid.
	var base := Rect2(p.x - 26, p.y - 10, 52, 12)
	draw_rect(base.grow(1.5), ink)
	draw_rect(base, stone_dk)
	for i in 5:
		draw_rect(Rect2(base.position.x + 1 + i * 10.4, base.position.y + 1, 9, 4), stone)
		draw_rect(Rect2(base.position.x + 6 + i * 10.4, base.position.y + 6, 9, 5), stone if i < 4 else stone_dk)
	var course := Rect2(p.x - 22, p.y - 18, 30 if flip > 0 else 44, 8)
	if flip < 0:
		course.position.x = p.x - 22
	draw_rect(course.grow(1.5), ink)
	for i in int(course.size.x / 10.0):
		draw_rect(Rect2(course.position.x + i * 10, course.position.y, 9, 7), stone)
		draw_rect(Rect2(course.position.x + i * 10, course.position.y, 9, 1), stone.lightened(0.15))
	# The timber frame: two posts and a crossbeam, braced.
	var post_l := p.x - 22.0
	var post_r := p.x + 22.0
	var top := p.y - 52.0
	for x in [post_l, post_r]:
		draw_rect(Rect2(x - 2.5, top - 1.5, 5, p.y - top - 6), ink)
		draw_rect(Rect2(x - 1.5, top, 3, p.y - top - 8), wood)
	draw_rect(Rect2(post_l - 4, top - 4, post_r - post_l + 8, 6), ink)
	draw_rect(Rect2(post_l - 3, top - 3, post_r - post_l + 6, 4), wood)
	draw_rect(Rect2(post_l - 3, top - 3, post_r - post_l + 6, 1), wood.lightened(0.2))
	draw_line(Vector2(post_l + 1, top + 4), Vector2(post_r - 1, p.y - 22), wood_dk, 2.0)
	# A ladder leaning on the frame.
	var lx := p.x + 6.0 * flip
	for side in [-3.0, 3.0]:
		draw_line(Vector2(lx + side, p.y - 6), Vector2(lx + side + 8.0 * flip, top + 6), wood_dk, 2.0)
	for i in 5:
		var k := (i + 0.5) / 5.0
		var y := lerpf(p.y - 6.0, top + 6.0, k)
		draw_line(Vector2(lx - 3 + 8.0 * flip * k, y), Vector2(lx + 3 + 8.0 * flip * k, y), wood, 1.5)
	# Materials beside it: a stack of planks, a pile of stones, a mortar bucket.
	var side_x := p.x + 38.0 * flip
	for i in 3:
		var plank := Rect2(side_x - 13, p.y - 2 - i * 4, 26, 4)
		draw_rect(plank.grow(1.0), ink)
		draw_rect(plank, wood if i % 2 == 0 else wood.lightened(0.08))
	var pile := p + Vector2(-38.0 * flip, 0)
	for o in [Vector2(-6, 0), Vector2(3, 0), Vector2(-2, -5), Vector2(9, -1)]:
		draw_rect(Rect2(pile + o - Vector2(4, 3), Vector2(8, 6)), ink)
		draw_rect(Rect2(pile + o - Vector2(3, 2), Vector2(6, 4)), stone)
	var bucket := p + Vector2(-22.0 * flip, 4)
	draw_rect(Rect2(bucket - Vector2(5, 7), Vector2(10, 8)), ink)
	draw_rect(Rect2(bucket - Vector2(4, 6), Vector2(8, 6)), Color(0.55, 0.42, 0.3, alpha) * lit)
	draw_rect(Rect2(bucket - Vector2(3, 6), Vector2(6, 2)), Color(0.82, 0.8, 0.74, alpha) * lit)   # mortar


## An Engineer: hammering at a site or the wall (a wind-up, then the blow, with sparks),
## or idling with his hammer, tossing it up end over end and catching it.
func _draw_engineer(a: Dictionary, alpha: float, light: Color) -> void:
	var p: Vector2 = a["pos"]
	var role: String = a["role"]
	var s := SPRITE_SCALE
	var foot := p + Vector2(0, 2)
	draw_set_transform(foot, 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 7.0 * s, Color(0, 0, 0, 0.25 * alpha))
	draw_set_transform(Vector2.ZERO)
	var frames: Array = Sprites.frames("engineer")
	var tex: Texture2D = frames[0]
	var dir := -1.0 if role in ["build_l", "repair_l"] else 1.0
	var off := Vector2.ZERO
	var rot := 0.0
	var sc := Vector2.ONE
	var tint := Color(light.r, light.g, light.b, alpha)
	var working := role != "toss"
	var flight := -1.0   # the tossed hammer: 0-1 through its flight, or -1 while it's in hand
	if role == "toss":
		var c := fmod(t + (a["id"] % 5) * 0.1, TOSS) / TOSS
		if c < 0.55:
			flight = c / 0.55
	if working:
		var phase := fmod(t + (a["id"] % 7) * 0.05, ENGINEER_SWING) / ENGINEER_SWING
		if phase < 0.45:
			tex = Sprites.pose("engineer", "strike")
			var hit := 1.0 - phase / 0.45
			sc = Vector2(1.0 + 0.08 * hit, 1.0 - 0.06 * hit)
			rot = 0.06 * dir * hit
			if phase < 0.12:
				# Sparks off the hammer (up against the wall for a repair).
				var at := p + Vector2(dir * 20.0, -14.0 if role.begins_with("build") else -26.0)
				for i in 4:
					var d := Vector2.from_angle(-PI / 2.0 + (i - 1.5) * 0.6) * (5.0 + phase * 60.0)
					draw_rect(Rect2(at + d, Vector2(2, 2)), Color(1.0, 0.85, 0.4, alpha))
		else:
			var wind := (phase - 0.45) / 0.55
			rot = -0.12 * dir * wind
			sc = Vector2(1.0 - 0.03 * wind, 1.0 + 0.05 * wind)
	elif flight >= 0.0:
		tex = Sprites.pose("engineer", "toss")
		# A little bounce at the throw and the catch.
		var edge := 1.0 - minf(flight, 1.0 - flight) * 2.0
		sc = Vector2(1.0 + 0.05 * edge * edge, 1.0 - 0.04 * edge * edge)
	else:
		var b := sin(t * 2.4 + a["id"] % 5)
		sc = Vector2(1.0 - 0.012 * b, 1.0 + 0.025 * b)   # breathing
	if role.begins_with("repair"):
		# The patch he's mending: freshly laid, paler stones in the wall above his hammer.
		var patch := p + Vector2(dir * 22.0 - 9.0, -46.0)
		var stone := Color(0.82, 0.8, 0.76, alpha) * Color(light, 1)
		draw_rect(Rect2(patch, Vector2(18, 14)), Color(0.25, 0.22, 0.24, alpha))
		draw_rect(Rect2(patch + Vector2(1, 1), Vector2(8, 6)), stone)
		draw_rect(Rect2(patch + Vector2(10, 1), Vector2(7, 6)), stone)
		draw_rect(Rect2(patch + Vector2(1, 8), Vector2(5, 5)), stone)
		draw_rect(Rect2(patch + Vector2(7, 8), Vector2(10, 5)), stone)
	var sz := tex.get_size() * s
	draw_set_transform(foot + off, rot, Vector2(dir * sc.x, sc.y))
	draw_texture_rect(tex, Rect2(Vector2(-8.0 * s, -sz.y + 2), sz), false, tint)
	draw_set_transform(Vector2.ZERO)
	if flight >= 0.0:
		# The hammer flipping end over end above his open hand.
		var hand := foot + Vector2(dir * 4.5 * s, -8.0 * s)
		var at := hand + Vector2(0, -sin(flight * PI) * 52.0)
		# One flip at an even pace over the whole flight, so the handle comes round to
		# point down just as it drops into his hand.
		var spin := -flight * TAU * dir
		draw_set_transform(at, spin, Vector2.ONE)
		var wood := Color(0.55, 0.35, 0.18, alpha) * Color(light, 1)
		var steel := Color(0.62, 0.64, 0.7, alpha) * Color(light, 1)
		var ink := Color(0.1, 0.07, 0.1, alpha)
		draw_rect(Rect2(-2.5, -6, 5, 16), ink)
		draw_rect(Rect2(-1.5, -5, 3, 14), wood)
		draw_rect(Rect2(-6.5, -11, 13, 7), ink)
		draw_rect(Rect2(-5.5, -10, 11, 5), steel)
		draw_rect(Rect2(-5.5, -10, 11, 1), steel.lightened(0.3))
		draw_set_transform(Vector2.ZERO)


func _draw_actors(light: Color) -> void:
	# Graves are sorted in with everyone else, so whoever stands nearer is drawn in front.
	var order := actors.duplicate()
	for g in graves:
		if g["alpha"] > 0.01:
			order.append({"kind": "grave", "pos": g["pos"], "alpha": g["alpha"]})
	order.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)
	for a in order:
		var alpha: float = a["alpha"]
		if alpha <= 0.01:
			continue
		var kind: String = a["kind"]
		var p: Vector2 = a["pos"]
		if kind == "grave":
			# Tombstones rise out of the ground as Hard comes in.
			Grave.draw_tombstone(self, p, 1.6 * alpha, Color(0.55, 0.1, 0.1))
			continue
		if kind == "dummy":
			_draw_dummy(p, a["hurt"], alpha, light)
			continue
		if kind == "target":
			_draw_target(p, alpha, light)
			continue
		if kind == "site":
			_draw_site(p, float(a["role"]), alpha, light)
			continue
		if kind == "engineer":
			_draw_engineer(a, alpha, light)
			continue
		if kind in ["watchtower", "crag", "beacon", "cottage", "fort", "wagon"]:
			draw_set_transform(Vector2(sin(a["hurt"] * 60.0) * a["hurt"] * 8.0, 0))   # shaken by a blow
			call("_draw_" + kind, a, alpha, light)
			draw_set_transform(Vector2.ZERO)
			continue
		var s: float = BIG.get(kind, SPRITE_SCALE)
		var flying: bool = kind == "bat" or kind == "wyvern"
		var foot := p + Vector2(0, 2)
		draw_set_transform(foot, 0, Vector2(1, 0.35))
		draw_circle(Vector2.ZERO, 7.0 * s, Color(0, 0, 0, 0.25 * alpha))
		draw_set_transform(Vector2.ZERO)
		var frames: Array = Sprites.frames(kind)
		var tex: Texture2D = Sprites.step(frames, int(t * 5.0 + a["id"] % 7))
		var slash := 0.0   # the training Swordsman's blow, 1 as it starts down to 0
		if kind == "swordsman" and a["role"] == "dummy" and a["lunge"] > 0.0:
			# His in-game attack: the sword swung up, then brought down (see warrior.gd).
			slash = a["lunge"] / 0.25
			tex = Sprites.pose("swordsman", "swing" if slash > 0.5 else "strike")
		var sz := tex.get_size() * s
		var faces_left: bool = a["side"] == "foe" or a["role"] in ["idle_r", "spar_r"]
		var dir := -1.0 if faces_left else 1.0
		var tint := Color(light.r, light.g, light.b, alpha)
		if a["hurt"] > 0.0:
			tint = Color(1, 0.5, 0.5, alpha)
		if a["side"] == "downed":
			draw_set_transform(p + Vector2(0, -6), PI / 2.0, Vector2(1, 1))
			draw_texture_rect(tex, Rect2(-sz / 2.0, sz), false, Color(0.5, 0.5, 0.58, 0.85 * alpha) * Color(light, 1))
			draw_set_transform(Vector2.ZERO)
			continue
		var lunge: float = a["lunge"]
		var off := Vector2(dir * 8.0 * minf(lunge / 0.15, 1.0), 0)
		var bob := Vector2(0, sin(t * (9.0 if a["side"] == "foe" else 3.0) + a["id"] % 13) * 1.5)
		if a["hop"] > 0.0:
			bob.y -= sin(a["hop"] / 0.4 * PI) * 16.0   # bounced off the line
		if flying:
			bob += Vector2(0, -36 + sin(t * 4.0 + a["id"] % 5) * 4.0)
		draw_set_transform(p + off + bob + Vector2(0, -sz.y / 2.0 + 4), 0, Vector2(dir, 1))
		draw_texture_rect(tex, Rect2(-sz / 2.0, sz), false, tint)
		draw_set_transform(Vector2.ZERO)
		if slash > 0.0:
			# The white arc of the slash in front of him, as in the game.
			var c := p + off + Vector2(dir * 7.0, -sz.y / 2.0 + 4)
			var a0 := 0.0 if dir > 0.0 else PI
			draw_arc(c, 25.0, a0 - 0.9, a0 + 0.9, 12, Color(1, 1, 1, slash * alpha), 3.0, true)


## A straw training dummy on a post; it rocks when it's hit.
func _draw_dummy(p: Vector2, hurt: float, alpha: float, light: Color) -> void:
	var tilt := sin(hurt * 40.0) * hurt * 1.2
	draw_set_transform(p, tilt, Vector2.ONE)
	var straw := Color(0.86, 0.72, 0.38, alpha) * Color(light, 1)
	draw_rect(Rect2(-2, -10, 4, 12), Color(OUTLINE, alpha))
	draw_rect(Rect2(-9, -34, 18, 24).grow(2), Color(OUTLINE, alpha))
	draw_rect(Rect2(-9, -34, 18, 24), straw)
	draw_rect(Rect2(-16, -30, 32, 5).grow(1.5), Color(OUTLINE, alpha))
	draw_rect(Rect2(-16, -30, 32, 5), straw)
	draw_circle(Vector2(0, -42), 8.5, Color(OUTLINE, alpha))
	draw_circle(Vector2(0, -42), 7.0, straw)
	draw_line(Vector2(-6, -22), Vector2(6, -22), Color(0.5, 0.3, 0.15, alpha), 2.0)
	draw_set_transform(Vector2.ZERO)


## An archery target on a stand.
func _draw_target(p: Vector2, alpha: float, light: Color) -> void:
	draw_line(p + Vector2(-8, 0), p + Vector2(0, -24), Color(0.45, 0.3, 0.15, alpha), 3.0)
	draw_line(p + Vector2(8, 0), p + Vector2(0, -24), Color(0.45, 0.3, 0.15, alpha), 3.0)
	var c := p + Vector2(0, -28)
	for ring in [[15.0, OUTLINE], [13.0, Color(0.95, 0.93, 0.88)], [10.0, Color(0.85, 0.2, 0.2)], [6.5, Color(0.95, 0.93, 0.88)], [3.5, Color(0.85, 0.2, 0.2)]]:
		draw_circle(c, ring[0], Color(ring[1], alpha) * Color(light, 1))


## "HOLD THE LINE" in chunky gold pixel letters on a red ribbon, with a glint that
## sweeps across now and then.
func _draw_title() -> void:
	var width := title_cols * PX
	var left := (W - width) / 2.0
	var top := TITLE_Y
	# The ribbon.
	var rib := Rect2(left - 34, top - 18, width + 68, 7 * PX + 36)
	for side in [-1, 1]:
		var x: float = rib.position.x if side < 0 else rib.end.x
		var tail := PackedVector2Array([Vector2(x - side * 6, rib.position.y + 14), Vector2(x + side * 46, rib.position.y + 14),
				Vector2(x + side * 30, rib.position.y + rib.size.y / 2.0 + 7), Vector2(x + side * 46, rib.end.y + 14), Vector2(x - side * 6, rib.end.y + 14)])
		draw_colored_polygon(tail, OUTLINE)
		var inner := PackedVector2Array()
		for q in tail:
			inner.append(q + (Vector2(x + side * 20, rib.position.y + rib.size.y / 2.0 + 14) - q) * 0.12)
		draw_colored_polygon(inner, Color(0.5, 0.08, 0.1))
	draw_rect(rib.grow(3), OUTLINE)
	draw_rect(rib, Color(0.68, 0.14, 0.14))
	draw_rect(Rect2(rib.position, Vector2(rib.size.x, 6)), Color(0.82, 0.25, 0.22))
	draw_rect(Rect2(rib.position + Vector2(0, rib.size.y - 6), Vector2(rib.size.x, 6)), Color(0.5, 0.08, 0.1))
	draw_line(rib.position + Vector2(0, 10), Vector2(rib.end.x, rib.position.y + 10), Color(1.0, 0.8, 0.3, 0.7), 2.0)
	draw_line(Vector2(rib.position.x, rib.end.y - 10), rib.end - Vector2(0, 10), Color(1.0, 0.8, 0.3, 0.7), 2.0)
	# Letters: shadow, outline, then gold shading row by row.
	var lit := {}
	for px in title_pixels:
		lit[px] = true
	for px in title_pixels:
		draw_rect(Rect2(left + px.x * PX - 3, top + px.y * PX + 3, PX + 6, PX + 6), Color(0.2, 0.05, 0.05, 0.6))
	for px in title_pixels:
		draw_rect(Rect2(left + px.x * PX - 3, top + px.y * PX - 3, PX + 6, PX + 6), Color(0.22, 0.1, 0.04))
	var shades := [Color(1.0, 0.95, 0.62), Color(1.0, 0.88, 0.42), Color(1.0, 0.8, 0.28), Color(0.98, 0.72, 0.2),
			Color(0.94, 0.62, 0.16), Color(0.86, 0.5, 0.12), Color(0.74, 0.4, 0.1)]
	var glint := fmod(t * 0.35, 1.6) * (title_cols + 14) - 7.0
	for px in title_pixels:
		var r := Rect2(left + px.x * PX, top + px.y * PX, PX, PX)
		draw_rect(r, shades[px.y])
		if not lit.has(Vector2i(px.x, px.y - 1)):
			draw_rect(Rect2(r.position, Vector2(PX, 2)), Color(1, 1, 0.9))
		var g := absf(px.x + px.y * 0.5 - glint)
		if g < 1.5:
			draw_rect(r, Color(1, 1, 1, 0.6 * (1.0 - g / 1.5)))


# --- The Battle Modes' props ------------------------------------------------------

## A wooden watchtower on stilts, a lookout hut on top with a lamp, and our pennant.
func _draw_watchtower(a: Dictionary, alpha: float, light: Color) -> void:
	var p: Vector2 = a["pos"]
	var lit := Color(light, 1)
	var ink := Color(OUTLINE, alpha)
	var wood := Color(0.6, 0.42, 0.24, alpha) * lit
	var wood_dk := Color(0.42, 0.28, 0.15, alpha) * lit
	draw_set_transform(p + Vector2(0, 2), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 26.0, Color(0, 0, 0, 0.22 * alpha))
	draw_set_transform(Vector2(sin(a["hurt"] * 60.0) * a["hurt"] * 8.0, 0))
	for side in [-1.0, 1.0]:
		var foot := p + Vector2(side * 16.0, 0)
		var top := p + Vector2(side * 11.0, -62)
		draw_line(foot, top, ink, 6.0)
		draw_line(foot, top, wood, 3.5)
	draw_line(p + Vector2(-14, -8), p + Vector2(12, -40), wood_dk, 2.5)
	draw_line(p + Vector2(14, -8), p + Vector2(-12, -40), wood_dk, 2.5)
	var hut := Rect2(p.x - 17, p.y - 84, 34, 24)
	draw_rect(hut.grow(2), ink)
	draw_rect(hut, wood)
	for i in 4:
		draw_line(Vector2(hut.position.x + 1, hut.position.y + 5 + i * 6), Vector2(hut.end.x - 1, hut.position.y + 5 + i * 6), wood_dk, 1.0)
	draw_rect(Rect2(p.x - 5, p.y - 80, 10, 8), Color(1.0, 0.72, 0.3, alpha) * Color(1, 1, 1).lerp(lit, 0.4))   # the lamp in the window
	var roof := PackedVector2Array([Vector2(p.x - 23, p.y - 82), Vector2(p.x + 23, p.y - 82), Vector2(p.x, p.y - 100)])
	draw_colored_polygon(PackedVector2Array([roof[0] + Vector2(-2, 2), roof[1] + Vector2(2, 2), roof[2] + Vector2(0, -3)]), ink)
	draw_colored_polygon(roof, Color(0.45, 0.32, 0.3, alpha) * lit)
	draw_line(Vector2(p.x, p.y - 100), Vector2(p.x, p.y - 116), ink, 2.0)
	var wave := sin(t * 5.0 + p.x) * 2.0
	draw_colored_polygon(PackedVector2Array([Vector2(p.x + 1, p.y - 116), Vector2(p.x + 16, p.y - 113 + wave), Vector2(p.x + 1, p.y - 108)]),
			Color(0.3, 0.45, 0.85, alpha) * lit)
	draw_set_transform(Vector2.ZERO)


## A craggy outcrop of grey rock, the sides of the pass. Its role is its size.
func _draw_crag(a: Dictionary, alpha: float, light: Color) -> void:
	var p: Vector2 = a["pos"]
	var k := float(a["role"])
	var lit := Color(light, 1)
	var rock := Color(0.52, 0.5, 0.5, alpha) * lit
	var pts := PackedVector2Array([p + Vector2(-34, 0) * k, p + Vector2(-28, -26) * k, p + Vector2(-14, -44) * k, p + Vector2(-2, -36) * k,
			p + Vector2(10, -58) * k, p + Vector2(24, -30) * k, p + Vector2(34, 0) * k])
	var out := PackedVector2Array()
	for q in pts:
		out.append(p + (q - p) * 1.06 + Vector2(0, 1))
	draw_colored_polygon(out, Color(OUTLINE, alpha))
	draw_colored_polygon(pts, rock)
	# The shaded side, away from the light, and a few cracks and ledges.
	draw_colored_polygon(PackedVector2Array([pts[4], pts[5], pts[6], p + Vector2(4, 0) * k]), rock.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([pts[1], pts[2], p + Vector2(-16, -30) * k]), rock.lightened(0.15))
	draw_line(p + Vector2(-8, -30) * k, p + Vector2(-2, -12) * k, rock.darkened(0.4), 1.5)
	draw_line(p + Vector2(14, -38) * k, p + Vector2(18, -20) * k, rock.darkened(0.45), 1.5)
	draw_rect(Rect2(p + Vector2(-26, -6) * k, Vector2(10, 3) * k), Color(0.32, 0.5, 0.26, alpha) * lit)   # moss at the foot


## A signal beacon: a stone tower whose fire builds over CHARGE seconds to a blaze that
## flares, throws sparks and settles, then builds again.
func _draw_beacon(a: Dictionary, alpha: float, light: Color) -> void:
	var p: Vector2 = a["pos"]
	var lit := Color(light, 1)
	draw_set_transform(p + Vector2(0, 2), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 26.0, Color(0, 0, 0, 0.25 * alpha))
	draw_set_transform(Vector2(sin(a["hurt"] * 60.0) * a["hurt"] * 8.0, 0))
	var body := Rect2(p.x - 16, p.y - 66, 32, 66)
	draw_rect(body.grow(2), Color(OUTLINE, alpha))
	var stone := Color(0.7, 0.66, 0.6, alpha) * lit
	draw_rect(body, stone)
	for i in 6:
		var y := body.position.y + 6 + i * 11
		draw_line(Vector2(body.position.x, y), Vector2(body.end.x, y), stone.darkened(0.3), 1.0)
		var x := body.position.x + (8.0 if i % 2 == 0 else 16.0)
		draw_line(Vector2(x, y - 11), Vector2(x, y), stone.darkened(0.3), 1.0)
	draw_rect(Rect2(body.end.x - 9, body.position.y, 9, body.size.y), Color(0, 0, 0, 0.18 * alpha))
	var brazier := Rect2(p.x - 22, p.y - 74, 44, 9)
	draw_rect(brazier.grow(2), Color(OUTLINE, alpha))
	draw_rect(brazier, Color(0.38, 0.36, 0.4, alpha) * lit)
	var cycle := fmod(scene_t, CHARGE + 1.2)
	var k := minf(cycle / CHARGE, 1.0)
	var top := Vector2(p.x, p.y - 74)
	var h := 8.0 + k * 34.0 + sin(t * 14.0) * 2.5
	var w := 10.0 + k * 10.0
	draw_circle(top + Vector2(0, -h * 0.4), 20.0 + k * 40.0, Color(1.0, 0.6, 0.25, (0.08 + 0.14 * k) * alpha))
	for layer in [[1.0, Color(0.9, 0.25, 0.08)], [0.7, Color(1.0, 0.58, 0.16)], [0.42, Color(1.0, 0.95, 0.6)]]:
		var f: float = layer[0]
		var sway := sin(t * 9.0 + f * 3.0) * 3.0 * f
		draw_colored_polygon(PackedVector2Array([top + Vector2(-w * f, 0), top + Vector2(w * f, 0), top + Vector2(sway, -h * f)]),
				Color(layer[1], alpha))
	if cycle > CHARGE:
		# Ablaze: a bright flare and sparks flying up.
		var f := (cycle - CHARGE) / 1.2
		draw_circle(top + Vector2(0, -20), 14.0 + f * 40.0, Color(1, 0.95, 0.65, 0.7 * (1.0 - f) * alpha))
		for i in 7:
			var d := Vector2.from_angle(-PI / 2.0 + (i - 3) * 0.32) * (10.0 + f * 60.0)
			draw_rect(Rect2(top + Vector2(0, -16) + d, Vector2(3, 3)), Color(1, 0.8, 0.3, (1.0 - f) * alpha))
	draw_set_transform(Vector2.ZERO)


## A thatched cottage with a door and a chimney trailing smoke. Its role picks which.
func _draw_cottage(a: Dictionary, alpha: float, light: Color) -> void:
	var p: Vector2 = a["pos"]
	var lit := Color(light, 1)
	var ink := Color(OUTLINE, alpha)
	var big: bool = a["role"] == "1"
	var w := 58.0 if big else 46.0
	var wall := Rect2(p.x - w / 2.0, p.y - 30, w, 30)
	draw_rect(wall.grow(2), ink)
	draw_rect(wall, Color(0.88, 0.83, 0.72, alpha) * lit)
	draw_rect(Rect2(wall.end.x - 12, wall.position.y, 12, 30), Color(0, 0, 0, 0.12 * alpha))
	for x in [wall.position.x + 2, wall.end.x - 5]:
		draw_rect(Rect2(x, wall.position.y, 3, 30), Color(0.45, 0.3, 0.18, alpha) * lit)   # beams
	draw_rect(Rect2(p.x - 6, p.y - 18, 12, 18).grow(1.5), ink)
	draw_rect(Rect2(p.x - 6, p.y - 18, 12, 18), Color(0.12, 0.08, 0.06, alpha))   # the door stands open
	draw_rect(Rect2(wall.position.x + 7, p.y - 22, 8, 7), Color(0.35, 0.28, 0.2, alpha) * lit)
	var roof := PackedVector2Array([Vector2(wall.position.x - 7, wall.position.y + 2), Vector2(wall.end.x + 7, wall.position.y + 2),
			Vector2(wall.end.x - 6, wall.position.y - 20), Vector2(wall.position.x + 6, wall.position.y - 20)])
	var rim := PackedVector2Array()
	for q in roof:
		rim.append(q + (q - Vector2(p.x, wall.position.y - 8)).normalized() * 2.0)
	draw_colored_polygon(rim, ink)
	draw_colored_polygon(roof, Color(0.8, 0.64, 0.34, alpha) * lit)
	for i in 3:
		var y := wall.position.y - 4 - i * 6
		draw_line(Vector2(wall.position.x - 2 + i * 2.5, y), Vector2(wall.end.x + 2 - i * 2.5, y), Color(0.62, 0.48, 0.24, alpha) * lit, 1.0)
	var chim := Rect2(wall.end.x - 16, wall.position.y - 26, 7, 12)
	draw_rect(chim.grow(1.5), ink)
	draw_rect(chim, Color(0.6, 0.56, 0.52, alpha) * lit)
	for i in 4:
		var k := fmod(t * 0.4 + i * 0.25 + (0.5 if big else 0.0), 1.0)
		draw_circle(chim.position + Vector2(3.5 + k * 16.0, -4 - k * 34.0), 3.0 + k * 5.0, Color(0.85, 0.85, 0.85, 0.5 * (1.0 - k) * alpha))


## The old fort's broken walls round a flagpole; the flag climbs, red turning to our blue
## halfway, flutters at the top, then the next capture starts it again.
func _draw_fort(a: Dictionary, alpha: float, light: Color) -> void:
	var p: Vector2 = a["pos"]
	var lit := Color(light, 1)
	var ink := Color(OUTLINE, alpha)
	var stone := Color(0.64, 0.62, 0.58, alpha) * lit
	for seg in [[-58, 34, 0], [-36, 22, 1], [22, 40, 2], [46, 26, 3]]:
		var r := Rect2(p.x + seg[0], p.y - seg[1], 20, seg[1])
		draw_rect(r.grow(2), ink)
		draw_rect(r, stone)
		draw_rect(Rect2(r.position.x + 3 + seg[2] * 3, r.position.y - 5, 8, 5).grow(1.5), ink)   # a broken stub above
		draw_rect(Rect2(r.position.x + 3 + seg[2] * 3, r.position.y - 5, 8, 5), stone)
		for y in range(int(r.position.y) + 8, int(r.end.y), 9):
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), stone.darkened(0.3), 1.0)
		draw_rect(Rect2(r.end.x - 6, r.position.y, 6, r.size.y), Color(0, 0, 0, 0.16 * alpha))
	var pole_top := p + Vector2(0, -110)
	draw_line(p, pole_top, ink, 4.0)
	draw_line(p, pole_top, Color(0.55, 0.4, 0.24, alpha) * lit, 2.0)
	draw_circle(pole_top, 3.0, Color(1.0, 0.82, 0.3, alpha) * lit)
	var cycle := fmod(scene_t, RAISE + 1.6)
	var k := minf(cycle / RAISE, 1.0)
	var fy: float = lerpf(p.y - 24.0, pole_top.y + 4.0, k)
	var col := Color(0.82, 0.22, 0.2).lerp(Color(0.3, 0.45, 0.85), clampf((k - 0.45) * 4.0, 0.0, 1.0))
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(Vector2(p.x + 2 + i * 6, fy + sin(t * 6.0 - i * 0.9) * 2.0 * i / 5.0))
	for i in range(5, -1, -1):
		pts.append(Vector2(p.x + 2 + i * 6, fy + 18 + sin(t * 6.0 - i * 0.9) * 2.0 * i / 5.0))
	draw_colored_polygon(pts, Color(col, alpha) * lit)
	draw_polyline(pts + PackedVector2Array([pts[0]]), ink, 1.5)
	if cycle > RAISE:
		var f := (cycle - RAISE) / 1.6
		draw_circle(pole_top, 6.0 + f * 26.0, Color(1, 0.92, 0.5, 0.6 * (1.0 - f) * alpha))


## The convoy's wagon: an ox in harness, the bed and a canvas tilt, wheels turning as it rolls.
func _draw_wagon(a: Dictionary, alpha: float, light: Color) -> void:
	var p: Vector2 = a["pos"]
	var lit := Color(light, 1)
	var ink := Color(OUTLINE, alpha)
	var bob := sin(t * 10.0) * 0.8
	draw_set_transform(p + Vector2(10, 2), 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 50.0, Color(0, 0, 0, 0.22 * alpha))
	draw_set_transform(Vector2.ZERO)
	# The ox, out in front.
	var hide := Color(0.55, 0.4, 0.28, alpha) * lit
	var step := sin(t * 7.0) * 3.0
	for lx in [36.0 + step, 46.0 - step, 58.0 + step, 66.0 - step]:
		draw_rect(Rect2(p.x + lx - 1, p.y - 14, 6, 14), ink)
		draw_rect(Rect2(p.x + lx, p.y - 13, 4, 12), hide.darkened(0.2))
	var body := Rect2(p.x + 32, p.y - 34 + bob, 40, 22)
	draw_rect(body.grow(2), ink)
	draw_rect(body, hide)
	draw_rect(Rect2(body.position.x, body.end.y - 6, body.size.x, 6), hide.darkened(0.15))
	var head := Rect2(p.x + 70, p.y - 40 + bob, 16, 15)
	draw_rect(head.grow(2), ink)
	draw_rect(head, hide)
	draw_rect(Rect2(head.end.x - 5, head.end.y - 6, 5, 5), Color(0.8, 0.62, 0.5, alpha) * lit)
	draw_line(head.position + Vector2(2, 0), head.position + Vector2(-4, -7), Color(0.92, 0.88, 0.76, alpha) * lit, 2.5)   # horns
	draw_line(head.position + Vector2(13, 0), head.position + Vector2(19, -7), Color(0.92, 0.88, 0.76, alpha) * lit, 2.5)
	draw_rect(Rect2(head.position.x + 8, head.position.y + 4, 2, 2), ink)
	draw_line(Vector2(p.x + 16, p.y - 22), body.position + Vector2(2, 10), ink, 2.5)   # the shaft
	# The wagon.
	var wood := Color(0.5, 0.33, 0.18, alpha) * lit
	var bed := Rect2(p.x - 48, p.y - 30 + bob, 66, 14)
	draw_rect(bed.grow(2), ink)
	draw_rect(bed, wood)
	draw_line(Vector2(bed.position.x, bed.position.y + 7), Vector2(bed.end.x, bed.position.y + 7), wood.darkened(0.3), 1.0)
	var tilt := PackedVector2Array()
	for i in 13:
		var ang := PI + PI * i / 12.0
		tilt.append(Vector2(p.x - 15, p.y - 30 + bob) + Vector2(cos(ang) * 32.0, sin(ang) * 24.0))
	draw_colored_polygon(tilt, ink)
	var inner := PackedVector2Array()
	for q in tilt:
		inner.append(q + (Vector2(p.x - 15, p.y - 30 + bob) - q) * 0.07)
	draw_colored_polygon(inner, Color(0.92, 0.88, 0.76, alpha) * lit)
	for i in 3:
		var x := p.x - 33 + i * 18
		draw_line(Vector2(x, p.y - 30 + bob), Vector2(x, p.y - 48 + bob + absf(i - 1) * 6.0), Color(0.75, 0.7, 0.6, alpha) * lit, 1.5)
	for wx in [-34.0, 6.0]:
		var c := Vector2(p.x + wx, p.y - 10)
		draw_circle(c, 12.0, ink)
		draw_circle(c, 9.5, wood.lightened(0.1))
		draw_circle(c, 3.0, ink)
		var ang := p.x / 10.0   # turning with the distance rolled
		for j in 3:
			var d := Vector2.from_angle(ang + j * PI / 3.0) * 9.0
			draw_line(c - d, c + d, ink, 1.5)


# --- The far country ----------------------------------------------------------------

## A colour washed towards the horizon's, the further off the more.
func _haze(c: Color, k: float) -> Color:
	return c.lerp(cur["low"], k)


## The mountains past the castle: a far range, then a nearer one, lit from the left,
## snow on the high peaks. Their tops show between the towers and either side.
func _draw_mountains(light: Color) -> void:
	for range_ in 2:
		var peaks: Array = FAR_PEAKS if range_ == 0 else NEAR_PEAKS
		var haze := 0.55 if range_ == 0 else 0.4
		var base_col := Color(0.42, 0.46, 0.6) if range_ == 0 else Color(0.38, 0.44, 0.5)
		var lit := _haze(base_col * light, haze)
		var shade := _haze(base_col.darkened(0.25) * light, haze)
		var snow := _haze(Color(0.95, 0.96, 1.0) * light, haze * 0.6)
		if range_ == 0:
			# A low line of hills under them, all the way across a wide window.
			var pts := PackedVector2Array([Vector2(-1000, 470)])
			var x := -1000.0
			while x <= W + 1000.0:
				pts.append(Vector2(x, 372.0 - sin(x * 0.019) * 14.0 - sin(x * 0.051) * 6.0))
				x += 24.0
			pts.append(Vector2(W + 1000, 470))
			_poly(pts, shade)
		for pk in peaks:
			var px: float = pk[0]
			var top: float = pk[1]
			var hw: float = pk[2]
			var apex := Vector2(px, top)
			var l := Vector2(px - hw, 470)
			var r := Vector2(px + hw * 0.9, 470)
			var jag := 6.0 * _rand(px, top, 3)
			_poly(PackedVector2Array([l, apex.lerp(l, 0.45) + Vector2(-jag, 0), apex, apex.lerp(r, 0.4) + Vector2(4, -jag),
					r]), shade)
			# The sunlit face, down from the peak.
			_poly(PackedVector2Array([l, apex.lerp(l, 0.45) + Vector2(-jag, 0), apex, Vector2(px + hw * 0.12, 470)]), lit)
			if top < SNOW_Y:
				var d := (SNOW_Y - top) / (470.0 - top) * 1.6 + 0.12
				var sl := apex.lerp(l, d)
				var sr := apex.lerp(r, d)
				var cap := PackedVector2Array([apex, sr, apex.lerp(sr, 0.5) + Vector2(-3, 6), apex.lerp(sl, 0.4).lerp(sr, 0.35) + Vector2(0, 8), sl])
				_poly(cap, snow)
				_poly(PackedVector2Array([apex, sr, apex.lerp(sr, 0.5) + Vector2(-3, 6)]), snow.darkened(0.12))


## The peoples' lands, small with distance: Frostmarch's snows, the Monastery high on its
## crag, the Arcane Spires on the tallest peak and Deepdelve's mine; then nearer, the
## Greenwood, Mercy Vale's sanctuary, the walls of the Free Cities and Stonehollow's quarry.
func _draw_lands(light: Color, near: bool) -> void:
	if not near:
		# Frostmarch: a hall of dark timber on the snowfield.
		_rect(Rect2(3, 302, 14, 6), _haze(Color(0.36, 0.26, 0.2) * light, 0.45))
		_poly(PackedVector2Array([Vector2(1, 303), Vector2(10, 296), Vector2(19, 303)]), _haze(Color(0.9, 0.92, 1.0) * light, 0.3))
		# The High Monastery: tiered roofs on its crag.
		var wall := _haze(Color(0.9, 0.86, 0.78) * light, 0.35)
		var roof := _haze(Color(0.75, 0.3, 0.22) * light, 0.35)
		for i in 3:
			var w := 24.0 - i * 6.0
			var y := 340.0 - i * 9.0
			_rect(Rect2(205 - w / 2.0 + 3, y - 6, w - 6, 7), wall)
			_poly(PackedVector2Array([Vector2(203 - w / 2.0, y - 5), Vector2(207 + w / 2.0, y - 5), Vector2(205, y - 11)]), roof)
		# Deepdelve: a timbered mine mouth on its mountainside, lamplight inside.
		var dd := Vector2(232, 350)
		_rect(Rect2(dd + Vector2(-6, -8), Vector2(12, 10)), _haze(Color(0.42, 0.3, 0.18) * light, 0.3))
		_rect(Rect2(dd + Vector2(-4, -6), Vector2(8, 8)), Color(0.12, 0.08, 0.06).lerp(Color(1.0, 0.7, 0.3), 0.5 + 0.4 * cur["windows"]))
		# Mercy Vale: a white sanctuary on its hilltop, the beacon up on its bell tower.
		var white := _haze(Color(0.95, 0.93, 0.86) * light, 0.25)
		var slate := _haze(Color(0.45, 0.5, 0.7) * light, 0.25)
		_rect(Rect2(404, 352, 22, 14), white)
		_poly(PackedVector2Array([Vector2(402, 353), Vector2(424, 353), Vector2(413, 345)]), slate)
		_rect(Rect2(422, 336, 8, 30), white)
		_rect(Rect2(424, 342, 4, 4), _haze(Color(0.55, 0.45, 0.3) * light, 0.25))   # the bell
		# The Arcane Spires: three slender towers on the tallest peak, their tips glowing.
		var spire := _haze(Color(0.5, 0.42, 0.62) * light, 0.4)
		for sp in [[588.0, 282.0, 30.0], [604.0, 262.0, 44.0], [618.0, 276.0, 34.0]]:
			_rect(Rect2(sp[0] - 2.5, sp[1], 5, sp[2]), spire)
			_poly(PackedVector2Array([Vector2(sp[0] - 4, sp[1]), Vector2(sp[0] + 4, sp[1]), Vector2(sp[0], sp[1] - 10)]), spire.darkened(0.2))
		return
	# Greenwood: a dark wood of pines over the western hills.
	var pine := _haze(Color(0.16, 0.34, 0.2) * light, 0.25)
	for i in 15:
		var x := -64.0 + i * 8.0 + _rand(i, 1, 4) * 5.0
		var base := _hill_y(x, 0) + 8.0
		var h := 20.0 + _rand(i, 2, 4) * 12.0
		_poly(PackedVector2Array([Vector2(x - 6, base), Vector2(x + 6, base), Vector2(x, base - h)]),
				pine if i % 2 == 0 else pine.darkened(0.12))
	# The Free Cities: walls and towers, red roofs crowded inside, on the eastern hills.
	var fc := _hill_y(600, 0) + 4.0
	var stone := _haze(Color(0.78, 0.74, 0.66) * light, 0.25)
	var tile := _haze(Color(0.75, 0.38, 0.3) * light, 0.25)
	for i in 6:
		var x := 566.0 + i * 11.0
		var y := fc - 18.0 - (i % 3) * 4.0
		_rect(Rect2(x, y, 9, 10), _haze(Color(0.9, 0.85, 0.76) * light, 0.25))
		_poly(PackedVector2Array([Vector2(x - 1, y), Vector2(x + 10, y), Vector2(x + 4.5, y - 7)]), tile)
	_rect(Rect2(560, fc - 10, 84, 10), stone)
	for x in [560.0, 594.0, 626.0]:
		_rect(Rect2(x, fc - 20, 10, 20), stone)
		_rect(Rect2(x - 1, fc - 22, 12, 3), stone.darkened(0.15))
	for x in range(564, 640, 6):
		_rect(Rect2(x, fc - 12, 3, 2), stone)


## The hills' height at x (layer 0 the further, 1 the nearer).
static func _hill_y(x: float, layer: int) -> float:
	return 430.0 + layer * 40.0 - (sin(x * 0.011 + layer * 2.0) * 22.0 + sin(x * 0.027 + layer) * 10.0)


## Stonehollow's quarry on the near eastern hill: cut steps in pale stone, and a crane.
func _draw_quarry(light: Color) -> void:
	var q := Vector2(588, _hill_y(588, 1) + 4)
	var pale := _haze(Color(0.82, 0.76, 0.62) * light, 0.12)
	for i in 3:
		_rect(Rect2(q.x - 30 + i * 10, q.y - 4 - i * 6, 60 - i * 20, 6), pale.darkened(i * 0.08))
	var wood := _haze(Color(0.45, 0.3, 0.16) * light, 0.12)
	_seg(q + Vector2(26, 0), q + Vector2(26, -34), wood, 2.0)
	_seg(q + Vector2(26, -34), q + Vector2(4, -26), wood, 2.0)


## The eight beacons, one in each people's land: a little stone tower and its fire, a
## glow round it that shows more as the light goes, and smoke drifting off by day. In the
## Campaign's look they go dark, then light one after another.
func _draw_beacon_towers(light: Color) -> void:
	for i in BEACONS.size():
		var at: Vector2 = BEACONS[i][0]
		var s: float = BEACONS[i][1]
		var tower := _haze(Color(0.5, 0.46, 0.44) * light, 0.35 * (1.1 - s))
		_rect(Rect2(at + Vector2(-3, -9) * s, Vector2(6, 9) * s), tower)
		_rect(Rect2(at + Vector2(-4, -11) * s, Vector2(8, 2) * s), tower.darkened(0.2))


## The beacons' fires (their towers are in the far country's mesh): a glow that shows more
## as the light goes, and smoke drifting off by day. In the Campaign's look they go dark,
## then light one after another. All in one mesh, made fresh each frame.
func _draw_beacon_fires(light: Color) -> void:
	var dark := clampf(1.0 - light.v, 0.0, 1.0)
	bat = Batch.new()
	for i in BEACONS.size():
		var at: Vector2 = BEACONS[i][0]
		var s: float = BEACONS[i][1]
		var lit_at := 0.6 + i * 0.35
		if chain < lit_at:
			continue
		var age := chain - lit_at
		var flare := clampf(1.0 - age / 0.6, 0.0, 1.0) if age < 0.6 else 0.0
		var f := 0.8 + 0.2 * sin(t * 11.0 + i * 1.3) * sin(t * 6.1 + i)
		var top := at + Vector2(0, -11) * s
		_circ(top + Vector2(0, -3) * s, (6.0 + 3.0 * dark + 14.0 * flare) * s * f, Color(1.0, 0.6, 0.25, 0.12 + 0.22 * dark + 0.4 * flare))
		_poly(PackedVector2Array([top + Vector2(-3.5, 0) * s, top + Vector2(3.5, 0) * s, top + Vector2(sin(t * 8.0 + i), -9.0 * f) * s]),
				Color(1.0, 0.5, 0.15))
		_poly(PackedVector2Array([top + Vector2(-1.8, 0) * s, top + Vector2(1.8, 0) * s, top + Vector2(0, -5.0 * f) * s]),
				Color(1.0, 0.92, 0.55))
		if dark < 0.35:
			for k in 3:
				var u := fmod(t * 0.3 + k / 3.0 + i * 0.13, 1.0)
				_circ(top + Vector2(u * 14.0, -10.0 - u * 26.0) * s, (1.5 + u * 3.0) * s,
						Color(0.8, 0.8, 0.82, 0.35 * (1.0 - u) * (1.0 - dark * 2.5)))
	# The glowing tips of the Arcane Spires, and the stone swinging from Stonehollow's crane.
	for sp in [[588.0, 282.0], [604.0, 262.0], [618.0, 276.0]]:
		var pulse := 0.6 + 0.4 * sin(t * 2.0 + sp[0])
		_circ(Vector2(sp[0], sp[1] - 12), 5.0 * pulse, Color(0.8, 0.55, 1.0, 0.25 * pulse))
		_circ(Vector2(sp[0], sp[1] - 12), 2.0, Color(0.9, 0.75, 1.0, 0.9))
	var q := Vector2(588, _hill_y(588, 1) + 4)
	var swing := sin(t * 0.8) * 2.0
	_seg(q + Vector2(6, -27), q + Vector2(6 + swing, -14), Color(0.2, 0.2, 0.2, 0.7), 1.0)
	_rect(Rect2(q + Vector2(3 + swing, -14), Vector2(6, 4)), _haze(Color(0.82, 0.76, 0.62) * light, 0.12))
	fire_mesh = bat.mesh()   # (held on to: the renderer draws it after this returns)
	bat = null
	if fire_mesh != null:
		draw_mesh(fire_mesh, _plain())


## The far country (mountains, the lands, the hills and the beacons' towers) as one mesh:
## a single draw instead of hundreds, made again only when the light changes.
func _draw_land(light: Color) -> void:
	var key := [light, cur["low"], cur["windows"]]
	var stale := land_mesh == null
	if not stale:
		for i in 2:
			var a: Color = key[i]
			var b: Color = land_key[i]
			stale = stale or absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.006
		stale = stale or absf(key[2] - land_key[2]) > 0.01
	if stale:
		land_key = key
		bat = Batch.new()
		_draw_mountains(light)
		_draw_lands(light, false)
		_draw_hills(light)
		_draw_beacon_towers(light)
		land_mesh = bat.mesh()
		bat = null
	draw_mesh(land_mesh, _plain())


## A plain white texture for the meshes (theirs is a whole texture, not a region of the atlas).
static var _white_tex: ImageTexture = null
static func _plain() -> ImageTexture:
	if _white_tex == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white_tex = ImageTexture.create_from_image(img)
	return _white_tex


## Draws straight away, or (while `bat` is set) adds to the mesh being made.
func _poly(pts: PackedVector2Array, col: Color) -> void:
	if bat != null:
		bat.poly(pts, col)
	else:
		draw_colored_polygon(pts, col)


func _rect(r: Rect2, col: Color) -> void:
	if bat != null:
		bat.poly(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), col)
	else:
		draw_rect(r, col)


func _circ(c: Vector2, r: float, col: Color) -> void:
	if bat != null:
		bat.circle(c, r, col)
	else:
		draw_circle(c, r, col)


func _seg(a: Vector2, b: Vector2, col: Color, w := 1.0) -> void:
	if bat != null:
		var n := (b - a).orthogonal().normalized() * w / 2.0
		bat.poly(PackedVector2Array([a + n, b + n, b - n, a - n]), col)
	else:
		draw_line(a, b, col, w)


## Coloured triangles gathered up to be drawn as one mesh.
class Batch:
	var verts := PackedVector2Array()
	var cols := PackedColorArray()

	func poly(pts: PackedVector2Array, col: Color) -> void:
		var idx := PackedInt32Array()
		if pts.size() <= 4:
			for i in range(1, pts.size() - 1):
				idx.append_array([0, i, i + 1])   # small ones are convex: a fan does
		else:
			idx = Geometry2D.triangulate_polygon(pts)
		for i in idx:
			verts.append(pts[i])
			cols.append(col)

	func circle(c: Vector2, r: float, col: Color) -> void:
		var n := clampi(int(r * 1.5), 8, 24)
		for i in n:
			verts.append_array([c, c + Vector2.from_angle(TAU * i / n) * r, c + Vector2.from_angle(TAU * (i + 1) / n) * r])
			cols.append_array([col, col, col])

	func mesh() -> ArrayMesh:
		if verts.is_empty():
			return null
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = cols
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m


## A few birds wheeling across the sky on fair days.
func _draw_birds(light: Color) -> void:
	var a: float = clampf(cur["sun"] - 0.4, 0.0, 0.6) * (1.0 - cur["storm"])
	if a <= 0.01:
		return
	var col := Color(Color(0.18, 0.18, 0.24) * light, a * 1.4)
	for i in 4:
		var x := fposmod(t * 22.0 + i * 37.0 - 200.0, W + 400.0) - 200.0 + (i % 2) * 16.0
		var y := 250.0 + i * 9.0 + sin(t * 0.7 + i) * 8.0
		var flap := sin(t * 7.0 + i * 1.7) * 3.0
		draw_polyline(PackedVector2Array([Vector2(x - 6, y - flap), Vector2(x, y), Vector2(x + 6, y - flap)]), col, 1.5)


## Rain slanting down in the storm.
func _draw_rain() -> void:
	var a: float = cur["storm"]
	if a <= 0.02:
		return
	var view := _view_x()
	bat = Batch.new()
	for i in 90:
		var x := view.x + fposmod(i * 73.1 + t * 160.0, view.y - view.x + 80.0) - 40.0
		var y := fposmod(i * 131.7 + t * 620.0, EARTH_Y + 120.0) - 100.0
		_seg(Vector2(x, y), Vector2(x - 5, y + 14), Color(0.75, 0.8, 0.95, 0.35 * a), 1.0)
	rain_mesh = bat.mesh()
	bat = null
	draw_mesh(rain_mesh, _plain())
