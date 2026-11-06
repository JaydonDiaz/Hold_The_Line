extends RefCounted
## Detailed pixel-art versions of the eight troops (48x56 each), for the splash. They're
## drawn from simple shapes - ellipses, polygons, rectangles and lines - rasterised
## without anti-aliasing, so they stay pixel art: every shape is lit from the upper
## left in four flat tones, edged in a darker shade of its own color, and the whole
## figure gets a dark outline. Each follows the look of the troop's game sprite
## (see sprites.gd), with the room to add faces, folds, buckles and the like.

const WIDTH := 48
const HEIGHT := 56
const INK := Color(0.07, 0.05, 0.08)
const LIGHT := Vector2(-0.55, -0.83)   # direction the light comes from

const SKIN := Color(0.96, 0.77, 0.6)
const EYE := Color(0.12, 0.08, 0.12)
const BOOT := Color(0.32, 0.2, 0.13)
const WOOD := Color(0.55, 0.34, 0.17)
const STEEL := Color(0.78, 0.8, 0.86)
const GOLD := Color(1.0, 0.8, 0.3)

var img: Image


## The troop `kind` drawn in its splash pose.
func draw(kind: String) -> Image:
	img = Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	call("_" + kind)
	_outline()
	return img


# --- The troops --------------------------------------------------------------------

## Swordsman: a knight in a plumed helm and gold tabard, both hands on the pommel of
## his sword, its point planted in the ground in front of him.
func _swordsman() -> void:
	_legs(Color(0.35, 0.3, 0.38))
	# Tabard over mail.
	_poly([Vector2(14, 27), Vector2(34, 27), Vector2(36, 44), Vector2(12, 44)], Color(0.6, 0.62, 0.68))   # mail
	_poly([Vector2(16, 27), Vector2(32, 27), Vector2(33, 45), Vector2(15, 45)], Color(0.9, 0.72, 0.3))
	_rect(15, 37, 18, 3, Color(0.42, 0.26, 0.14))   # belt
	_rect(22, 37, 4, 3, GOLD)                      # buckle
	_line(Vector2(24, 29), Vector2(24, 35), Color(0.75, 0.55, 0.2))   # tabard seam
	# Shoulders (pauldrons).
	_ell(14, 29, 4.5, 3.5, STEEL)
	_ell(34, 29, 4.5, 3.5, STEEL)
	# The sword, point down in front: blade, crossguard, grip, pommel.
	_poly([Vector2(22.5, 34), Vector2(25.5, 34), Vector2(25.5, 51), Vector2(24, 54), Vector2(22.5, 51)], STEEL)
	_line(Vector2(24, 35), Vector2(24, 51), Color(0.95, 0.97, 1.0))   # fuller catching the light
	_rect(17, 31, 14, 3, Color(0.7, 0.55, 0.2))   # crossguard
	_rect(22, 25, 4, 6, Color(0.4, 0.24, 0.12))   # grip
	_ell(24, 24, 2.5, 2, GOLD)                    # pommel
	# Gauntlets on the pommel.
	_ell(20.5, 27, 3, 2.5, Color(0.62, 0.64, 0.7))
	_ell(27.5, 27, 3, 2.5, Color(0.62, 0.64, 0.7))
	# Helm: a rounded steel helm with a visor slit and a red plume.
	_ell(24, 7, 3, 4, Color(0.85, 0.2, 0.2))
	_ell(26, 4, 2.5, 3, Color(0.9, 0.25, 0.22))
	_ell(24, 16, 10, 9.5, STEEL)
	_rect(15, 15, 18, 3, Color(0.2, 0.18, 0.24), false)   # visor slit
	_px(19, 16, Color(1.0, 0.85, 0.5))   # eyes glinting in the dark of the visor
	_px(28, 16, Color(1.0, 0.85, 0.5))
	for x in [18, 21, 27, 30]:
		_px(x, 21, Color(0.45, 0.47, 0.55))   # breathing holes
	_line(Vector2(24, 8), Vector2(24, 14), Color(0.95, 0.96, 1.0))   # ridge highlight


## Archer: green hood, leather jerkin, a quiver on her back, an arrow drawn to the cheek.
func _archer() -> void:
	# Quiver behind the shoulder, fletching sticking up.
	_poly([Vector2(9, 20), Vector2(14, 18), Vector2(17, 36), Vector2(12, 38)], Color(0.48, 0.3, 0.15))
	for i in 3:
		_line(Vector2(9 + i * 2, 17 - i), Vector2(10 + i * 2, 20), Color(0.92, 0.9, 0.85))
	_legs(Color(0.3, 0.26, 0.36))
	_poly([Vector2(15, 27), Vector2(31, 27), Vector2(33, 44), Vector2(13, 44)], Color(0.55, 0.36, 0.2))   # jerkin
	_rect(14, 37, 19, 3, Color(0.35, 0.22, 0.12))
	_rect(21, 37, 3, 3, GOLD)
	_poly([Vector2(15, 27), Vector2(31, 27), Vector2(29, 31), Vector2(17, 31)], Color(0.3, 0.6, 0.3))   # hood's cape
	# Bow arm reaching out to the right, the drawing hand at her cheek.
	_poly([Vector2(29, 29), Vector2(40, 30), Vector2(40, 33), Vector2(29, 33)], Color(0.55, 0.36, 0.2))
	_ell(41, 31.5, 2, 2, SKIN)
	_ell(28, 23, 2.5, 2.2, SKIN)
	# Bow: a curved limb from top to bottom, the string pulled back to her hand.
	for y in range(12, 52):
		var t := (y - 31.5) / 20.0
		var x := 42.0 + 3.5 * (1.0 - t * t)
		_px(int(x), y, Color(0.6, 0.38, 0.18))
		_px(int(x) + 1, y, Color(0.4, 0.24, 0.12))
	_line(Vector2(42, 12), Vector2(29, 23), Color(0.92, 0.9, 0.85))
	_line(Vector2(29, 23), Vector2(42, 51), Color(0.92, 0.9, 0.85))
	# The arrow, nocked: shaft, fletching at her hand, steel head past the bow.
	_line(Vector2(27, 23), Vector2(46, 23), Color(0.75, 0.6, 0.35))
	_px(26, 22, Color(0.9, 0.3, 0.25))
	_px(26, 24, Color(0.9, 0.3, 0.25))
	_poly([Vector2(46, 21), Vector2(48, 23), Vector2(46, 25)], STEEL, false)
	# Head in a green hood.
	_ell(23, 17, 11, 10.5, Color(0.3, 0.62, 0.3))
	_ell(24.5, 19.5, 7, 6.5, SKIN, false)
	_face(24.5, 19, false)
	_ell(23, 10, 7, 3, Color(0.38, 0.72, 0.36), false)   # light on the hood's crown


## Martial Artist: spiky hair, a red headband trailing behind, white gi and black belt,
## feet planted wide and both fists up in guard.
func _martial() -> void:
	# Wide stance.
	_poly([Vector2(15, 41), Vector2(21, 41), Vector2(17, 51), Vector2(11, 51)], Color(0.93, 0.93, 0.9))
	_poly([Vector2(27, 41), Vector2(33, 41), Vector2(37, 51), Vector2(31, 51)], Color(0.93, 0.93, 0.9))
	_rect(10, 50, 8, 4, SKIN)
	_rect(31, 50, 8, 4, SKIN)
	# Gi: crossed lapels, black belt with hanging ends.
	_poly([Vector2(14, 26), Vector2(34, 26), Vector2(33, 43), Vector2(15, 43)], Color(0.93, 0.93, 0.9))
	_poly([Vector2(20, 26), Vector2(28, 26), Vector2(24, 34)], SKIN, false)   # chest at the open collar
	_line(Vector2(19, 26), Vector2(25, 36), Color(0.72, 0.72, 0.7))
	_line(Vector2(29, 26), Vector2(23, 36), Color(0.72, 0.72, 0.7))
	_rect(15, 36, 18, 3, Color(0.15, 0.13, 0.15))
	_poly([Vector2(23, 38), Vector2(26, 38), Vector2(27, 44), Vector2(24, 44)], Color(0.15, 0.13, 0.15))
	# Arms bent up: sleeves, bare forearms with red wraps, fists by the chin.
	_ell(13, 30, 4, 4.5, Color(0.93, 0.93, 0.9))
	_ell(35, 30, 4, 4.5, Color(0.93, 0.93, 0.9))
	_poly([Vector2(9, 30), Vector2(13, 30), Vector2(11, 23), Vector2(7, 23)], SKIN)
	_poly([Vector2(35, 30), Vector2(39, 30), Vector2(42, 23), Vector2(38, 23)], SKIN)
	_rect(8, 26, 4, 2, Color(0.85, 0.2, 0.2))
	_rect(37, 26, 4, 2, Color(0.85, 0.2, 0.2))
	_ell(9, 21, 3.5, 3, SKIN)    # rear fist, by the chin
	_ell(41, 21, 3.5, 3, SKIN)   # lead fist, out in front
	_line(Vector2(7, 21), Vector2(11, 21), Color(0.8, 0.6, 0.45))   # knuckles
	_line(Vector2(39, 21), Vector2(43, 21), Color(0.8, 0.6, 0.45))
	# Head: face, spiky black hair, red headband with tails streaming back.
	_ell(24, 16, 9, 9, SKIN)
	_face(24.5, 17, true)
	for i in 6:
		var x := 15.0 + i * 3.6
		_poly([Vector2(x - 2.5, 12), Vector2(x + 2.5, 12), Vector2(x + 1.5 - i * 0.3, 2.5 + (i % 2) * 2)], Color(0.2, 0.17, 0.25))
	_ell(24, 10, 9.5, 3, Color(0.2, 0.17, 0.25), false)
	_rect(15, 11, 18, 3, Color(0.85, 0.2, 0.2))
	_poly([Vector2(14, 11), Vector2(16, 13), Vector2(8, 17), Vector2(7, 14)], Color(0.85, 0.2, 0.2))
	_poly([Vector2(14, 12), Vector2(15, 14), Vector2(6, 21), Vector2(5, 18)], Color(0.75, 0.16, 0.16))


## Mage: a tall purple hat with a gold star, a great white beard, purple robes, and a
## staff held upright (the splash adds the spell gathering at its tip).
func _mage() -> void:
	# Robe falling to the ground, with folds.
	_poly([Vector2(16, 26), Vector2(32, 26), Vector2(36, 53), Vector2(12, 53)], Color(0.62, 0.38, 0.88))
	for x in [18, 24, 30]:
		_line(Vector2(x, 38), Vector2(x - 1 + (x - 24) / 4, 52), Color(0.48, 0.27, 0.7))
	_rect(13, 51, 22, 2, Color(0.42, 0.22, 0.62))
	_rect(17, 52, 5, 2, BOOT)
	_rect(26, 52, 5, 2, BOOT)
	# Staff on his right.
	_rect(36, 6, 3, 48, WOOD)
	_line(Vector2(36, 7), Vector2(36, 52), Color(0.68, 0.45, 0.24))
	_ell(37.5, 5, 3, 3, Color(0.55, 0.3, 0.8))   # crystal setting
	_poly([Vector2(31, 30), Vector2(36, 28), Vector2(37, 33), Vector2(32, 34)], Color(0.62, 0.38, 0.88))   # sleeve
	_ell(37.5, 30.5, 2.5, 2.5, SKIN)
	# Face and the beard spilling over the robe.
	_ell(24, 20, 8, 6, SKIN)
	_face(24, 19.5, false)
	_poly([Vector2(17, 21), Vector2(31, 21), Vector2(29, 34), Vector2(24, 40), Vector2(19, 34)], Color(0.94, 0.94, 0.97))
	_line(Vector2(22, 26), Vector2(23, 36), Color(0.8, 0.8, 0.86))
	_line(Vector2(26, 26), Vector2(25, 36), Color(0.8, 0.8, 0.86))
	_poly([Vector2(19, 21), Vector2(23, 22), Vector2(20, 24)], Color(0.94, 0.94, 0.97))   # moustache
	_poly([Vector2(29, 21), Vector2(25, 22), Vector2(28, 24)], Color(0.94, 0.94, 0.97))
	# Hat: brim and a tall crooked cone with a gold star.
	_ell(24, 15, 13, 3, Color(0.42, 0.22, 0.62))
	_poly([Vector2(15, 14), Vector2(33, 14), Vector2(28, 4), Vector2(23, -1), Vector2(21, 4)], Color(0.45, 0.25, 0.65))
	_rect(16, 12, 16, 2, GOLD)
	_star(24, 8, GOLD)


## Healer: a white hooded robe with green trim, a gold cross on the chest, and a staff
## topped with a green leaf-crystal.
func _healer() -> void:
	_poly([Vector2(15, 26), Vector2(33, 26), Vector2(36, 53), Vector2(12, 53)], Color(0.93, 0.93, 0.9))
	_rect(13, 49, 22, 4, Color(0.35, 0.7, 0.35))   # green hem
	_line(Vector2(13, 49), Vector2(35, 49), Color(0.25, 0.55, 0.3))
	for x in [19, 29]:
		_line(Vector2(x, 36), Vector2(x - (24 - x) / 5, 48), Color(0.8, 0.8, 0.78))
	# Gold cross with a jewel.
	_rect(22, 30, 4, 12, GOLD)
	_rect(18, 33, 12, 4, GOLD)
	_px(24, 35, Color(0.4, 0.85, 0.4))
	_px(23, 34, Color(0.4, 0.85, 0.4))
	# Staff.
	_rect(36, 8, 3, 46, WOOD)
	_line(Vector2(36, 9), Vector2(36, 52), Color(0.68, 0.45, 0.24))
	_poly([Vector2(37.5, 0), Vector2(41, 5), Vector2(37.5, 11), Vector2(34, 5)], Color(0.45, 0.9, 0.45))   # leaf-crystal
	_line(Vector2(37.5, 2), Vector2(37.5, 9), Color(0.85, 1.0, 0.8))
	_poly([Vector2(31, 30), Vector2(36, 28), Vector2(37, 33), Vector2(32, 34)], Color(0.93, 0.93, 0.9))
	_rect(32, 31, 3, 3, Color(0.35, 0.7, 0.35), false)   # green cuff
	_ell(37.5, 30.5, 2.5, 2.5, SKIN)
	# Hood and a kindly face.
	_ell(24, 17, 11, 11, Color(0.93, 0.93, 0.9))
	_ell(24, 19, 7, 6.5, SKIN, false)
	_face(24, 18.5, false)
	_poly([Vector2(13, 22), Vector2(17, 22), Vector2(16, 28), Vector2(13, 27)], Color(0.93, 0.93, 0.9))
	_poly([Vector2(35, 22), Vector2(31, 22), Vector2(32, 28), Vector2(35, 27)], Color(0.93, 0.93, 0.9))
	_line(Vector2(17, 11), Vector2(31, 11), Color(0.35, 0.7, 0.35))   # green band on the hood


## Frost Witch: an icy blue cloak and hood trimmed with white fur, a pale face, and a
## staff of ice crowned with a crystal.
func _frost() -> void:
	_poly([Vector2(14, 26), Vector2(34, 26), Vector2(37, 53), Vector2(11, 53)], Color(0.45, 0.72, 0.95))
	_poly([Vector2(20, 26), Vector2(28, 26), Vector2(29, 53), Vector2(19, 53)], Color(0.82, 0.92, 1.0))   # pale gown
	_rect(11, 50, 26, 3, Color(0.96, 0.98, 1.0))   # fur hem
	for x in [15, 33]:
		_line(Vector2(x, 34), Vector2(x + (x - 24) / 6, 49), Color(0.32, 0.55, 0.82))
	_px(24, 33, Color(0.55, 0.95, 1.0))   # a snowflake brooch
	_px(23, 33, Color(0.9, 1.0, 1.0)); _px(25, 33, Color(0.9, 1.0, 1.0)); _px(24, 32, Color(0.9, 1.0, 1.0)); _px(24, 34, Color(0.9, 1.0, 1.0))
	# Ice staff.
	_rect(36, 8, 3, 46, Color(0.62, 0.78, 0.9))
	_line(Vector2(36, 9), Vector2(36, 52), Color(0.85, 0.95, 1.0))
	_poly([Vector2(37.5, -1), Vector2(40.5, 4), Vector2(37.5, 10), Vector2(34.5, 4)], Color(0.7, 0.92, 1.0))
	_line(Vector2(37.5, 1), Vector2(37.5, 8), Color(1.0, 1.0, 1.0))
	_poly([Vector2(31, 30), Vector2(36, 28), Vector2(37, 33), Vector2(32, 34)], Color(0.45, 0.72, 0.95))
	_rect(32, 31, 3, 3, Color(0.96, 0.98, 1.0), false)
	_ell(37.5, 30.5, 2.5, 2.5, Color(0.9, 0.85, 0.9))
	# Hood with a fur rim, a pale face, silver hair at the sides.
	_ell(24, 17, 11, 11, Color(0.45, 0.72, 0.95))
	_ell(24, 19, 8, 7.5, Color(0.96, 0.98, 1.0), false)   # fur rim
	_ell(24, 19.5, 6.5, 6, Color(0.95, 0.86, 0.85), false)
	_rect(17, 17, 2, 7, Color(0.85, 0.9, 0.98), false)
	_rect(29, 17, 2, 7, Color(0.85, 0.9, 0.98), false)
	_face(24, 19, false, Color(0.25, 0.5, 0.75))


## Bard: a red cap with a white feather, a teal tunic, strumming a lute.
func _bard() -> void:
	_legs(Color(0.3, 0.25, 0.36))
	_poly([Vector2(15, 27), Vector2(33, 27), Vector2(34, 44), Vector2(14, 44)], Color(0.2, 0.6, 0.6))
	_rect(14, 37, 20, 3, Color(0.42, 0.26, 0.14))
	_rect(22, 37, 3, 3, GOLD)
	_poly([Vector2(19, 27), Vector2(29, 27), Vector2(24, 32)], Color(0.95, 0.9, 0.75))   # shirt at the collar
	# Lute held across the body: neck up to the left, round body at the hip.
	_poly([Vector2(8, 22), Vector2(11, 20), Vector2(26, 34), Vector2(23, 36)], Color(0.48, 0.3, 0.15))   # neck
	_rect(6, 19, 4, 3, Color(0.4, 0.24, 0.12))   # pegbox
	_ell(29, 38, 8, 7, Color(0.75, 0.45, 0.2))
	_ell(29, 38, 2.2, 2.2, Color(0.25, 0.14, 0.08), false)   # sound hole
	_line(Vector2(10, 21), Vector2(33, 41), Color(0.95, 0.92, 0.8))   # strings
	_rect(26, 43, 6, 1, Color(0.4, 0.24, 0.12), false)   # bridge
	_ell(31, 34, 2.5, 2.2, SKIN)   # strumming hand
	_ell(13, 24, 2.3, 2.2, SKIN)   # hand on the neck
	# Head, red cap with a feather.
	_ell(24, 17, 9, 9, SKIN)
	_face(24.5, 18, false)
	_ell(22, 10.5, 11, 4.5, Color(0.85, 0.2, 0.18))
	_poly([Vector2(11, 11), Vector2(33, 11), Vector2(31, 14), Vector2(13, 14)], Color(0.72, 0.15, 0.15))
	_poly([Vector2(28, 9), Vector2(34, 1), Vector2(36, 2), Vector2(30, 10)], Color(0.97, 0.97, 0.95))   # feather
	_line(Vector2(29, 9), Vector2(35, 2), Color(0.8, 0.8, 0.82))


## Alchemist: goggles pushed up, a leather coat with vials on the belt, holding up a
## bubbling green flask.
func _alchemist() -> void:
	_legs(Color(0.28, 0.24, 0.3))
	_poly([Vector2(14, 27), Vector2(34, 27), Vector2(36, 46), Vector2(12, 46)], Color(0.5, 0.34, 0.2))   # coat
	_poly([Vector2(19, 27), Vector2(29, 27), Vector2(30, 46), Vector2(18, 46)], Color(0.82, 0.78, 0.66))   # apron
	_rect(13, 37, 22, 3, Color(0.3, 0.2, 0.12))
	for i in 3:
		_rect(15 + i * 6, 34, 3, 4, [Color(0.4, 0.9, 0.35), Color(0.95, 0.5, 0.2), Color(0.6, 0.4, 0.95)][i])   # vials on the belt
	# Arm raised, flask held up.
	_poly([Vector2(31, 29), Vector2(35, 27), Vector2(38, 17), Vector2(34, 16)], Color(0.5, 0.34, 0.2))
	_ell(37, 15, 2.5, 2.5, SKIN)
	_ell(38, 9, 4, 4, Color(0.45, 0.95, 0.4))   # flask
	_rect(37, 3, 2, 3, Color(0.85, 0.9, 0.85))
	_rect(36, 2, 4, 1, Color(0.55, 0.4, 0.25))   # cork
	_px(37, 8, Color(0.85, 1.0, 0.8)); _px(39, 10, Color(0.85, 1.0, 0.8))   # bubbles
	_ell(13, 31, 2.5, 2.5, SKIN)
	# Head: messy brown hair, goggles on the forehead.
	_ell(24, 17, 9, 9, SKIN)
	_face(24.5, 18.5, false)
	_ell(24, 10, 10, 5, Color(0.35, 0.22, 0.12))
	_rect(15, 11, 18, 2, Color(0.25, 0.2, 0.18), false)   # goggle strap
	_ell(20, 12, 2.5, 2.2, Color(1.0, 0.6, 0.2))
	_ell(28, 12, 2.5, 2.2, Color(1.0, 0.6, 0.2))
	_px(19, 11, Color(1.0, 0.9, 0.7)); _px(27, 11, Color(1.0, 0.9, 0.7))


## The app icon's tower (64x64): stone walls, a red conical roof with a pennant, a
## red banner with a gold cross, a lit window and a door.
func tower_icon() -> Image:
	img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var stone := Color(0.7, 0.68, 0.64)
	var roof := Color(0.78, 0.22, 0.2)
	_line(Vector2(31, 2), Vector2(31, 12), Color(0.3, 0.22, 0.15))   # pennant pole
	_poly([Vector2(32, 2), Vector2(42, 5), Vector2(32, 8)], Color(0.9, 0.22, 0.2))
	_rect(14, 30, 36, 30, stone)   # tower
	for row in 5:
		var y := 34 + row * 5
		_line(Vector2(15, y), Vector2(48, y), stone.darkened(0.25))
		for x in range(17 + (row % 2) * 5, 48, 10):
			_line(Vector2(x, y + 1), Vector2(x, y + 4), stone.darkened(0.25))
	_rect(11, 26, 42, 5, stone.darkened(0.08))   # corbelled ledge
	_poly([Vector2(8, 27), Vector2(56, 27), Vector2(32, 10)], roof)   # roof
	for i in 4:
		_line(Vector2(14 + i * 9, 26), Vector2(30 + i * 1, 14), roof.darkened(0.2))
	_rect(21, 34, 8, 16, Color(0.78, 0.16, 0.16))   # banner
	_poly([Vector2(21, 50), Vector2(29, 50), Vector2(25, 54)], Color(0.78, 0.16, 0.16))
	_rect(24, 37, 2, 10, GOLD, false)
	_rect(22, 40, 6, 2, GOLD, false)
	_rect(36, 36, 6, 8, Color(1.0, 0.78, 0.35))   # lamplit window
	_ell(39, 36, 3, 2, Color(1.0, 0.78, 0.35), false)
	_line(Vector2(39, 35), Vector2(39, 43), Color(0.5, 0.3, 0.15))
	_rect(35, 50, 8, 10, Color(0.42, 0.26, 0.14))   # door
	_ell(39, 50, 4, 3, Color(0.42, 0.26, 0.14), false)
	_outline()
	return img


# --- Shared parts ---------------------------------------------------------------------

## Two legs in trousers and boots.
func _legs(trousers: Color) -> void:
	_rect(17, 43, 6, 7, trousers)
	_rect(25, 43, 6, 7, trousers)
	_rect(16, 49, 8, 5, BOOT)
	_rect(25, 49, 8, 5, BOOT)
	_line(Vector2(16, 50), Vector2(23, 50), Color(0.45, 0.3, 0.2))
	_line(Vector2(25, 50), Vector2(32, 50), Color(0.45, 0.3, 0.2))


## Eyes (with a glint), brows and a mouth on a face centred at (cx, cy).
func _face(cx: float, cy: float, fierce: bool, iris := EYE) -> void:
	for side in [-1, 1]:
		var ex := int(cx + side * 3.5)
		var ey := int(cy)
		_px(ex, ey, iris); _px(ex, ey + 1, iris); _px(ex + 1, ey, iris); _px(ex + 1, ey + 1, iris)
		_px(ex, ey, Color(1, 1, 1))   # glint
		var brow := Color(0.35, 0.22, 0.15)
		if fierce:
			_line(Vector2(ex - 1, ey - 3 + (1 if side < 0 else 0)), Vector2(ex + 2, ey - 2 - (1 if side < 0 else 0) + (1 if side > 0 else 0)), brow)
		else:
			_line(Vector2(ex - 1, ey - 2), Vector2(ex + 2, ey - 2), brow)
	_line(Vector2(cx - 1, cy + 4), Vector2(cx + 1, cy + 4), Color(0.7, 0.4, 0.35))
	_px(int(cx - 6), int(cy + 2), Color(1.0, 0.65, 0.6))   # rosy cheeks
	_px(int(cx + 6), int(cy + 2), Color(1.0, 0.65, 0.6))


func _star(cx: int, cy: int, col: Color) -> void:
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(0, -2), Vector2i(2, 0), Vector2i(-2, 0)]:
		_px(cx + d.x, cy + d.y, col)


# --- Drawing ------------------------------------------------------------------------

## The four tones of a color: lit, base, shade and deep shade (shadows lean violet).
func _tone(col: Color, level: int) -> Color:
	match level:
		0:
			return col.lightened(0.22)
		2:
			return col.darkened(0.2).lerp(Color(0.3, 0.18, 0.4), 0.1)
		3:
			return col.darkened(0.4).lerp(Color(0.2, 0.1, 0.3), 0.15)
	return col


## Which tone a pixel gets from where it sits on its shape (u, v from -1 to 1 across it):
## lit toward the light, shaded away from it.
func _level(u: float, v: float) -> int:
	var d := u * LIGHT.x + v * LIGHT.y   # how much it faces the light (upper left = lit)
	if d > 0.5:
		return 0
	if d > -0.25:
		return 1
	if d > -0.7:
		return 2
	return 3


## Paints a shape's pixels (`inside` decides which), shaded as a rounded form, with its
## edge in a darker shade of its color when `edge` is set.
func _shape(lo: Vector2, hi: Vector2, inside: Callable, col: Color, edge: bool) -> void:
	var c := (lo + hi) / 2.0
	var half := ((hi - lo) / 2.0).max(Vector2(0.5, 0.5))
	var x0 := maxi(int(floor(lo.x)), 0)
	var y0 := maxi(int(floor(lo.y)), 0)
	var x1 := mini(int(ceil(hi.x)), img.get_width() - 1)
	var y1 := mini(int(ceil(hi.y)), img.get_height() - 1)
	var mask := {}
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if inside.call(Vector2(x + 0.5, y + 0.5)):
				mask[Vector2i(x, y)] = true
	for key in mask:
		var p: Vector2i = key
		var u := (p.x + 0.5 - c.x) / half.x
		var v := (p.y + 0.5 - c.y) / half.y
		var tone := _tone(col, _level(u, v))
		if edge:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not mask.has(p + d):
					tone = _tone(col, 3) if (d.x > 0 or d.y > 0) else _tone(col, 2)
					break
		img.set_pixelv(p, tone)


func _ell(cx: float, cy: float, rx: float, ry: float, col: Color, edge := true) -> void:
	var c := Vector2(cx, cy)
	_shape(c - Vector2(rx, ry), c + Vector2(rx, ry), func(p: Vector2) -> bool:
		var q := (p - c) / Vector2(rx, ry)
		return q.length_squared() <= 1.0, col, edge)


func _poly(points: Array, col: Color, edge := true) -> void:
	var pts := PackedVector2Array(points)
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	_shape(lo, hi, func(p: Vector2) -> bool: return Geometry2D.is_point_in_polygon(p, pts), col, edge)


func _rect(x: int, y: int, w: int, h: int, col: Color, edge := true) -> void:
	_shape(Vector2(x, y), Vector2(x + w, y + h), func(p: Vector2) -> bool:
		return p.x >= x and p.x < x + w and p.y >= y and p.y < y + h, col, edge)


func _line(a: Vector2, b: Vector2, col: Color) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(n, 1))
		_px(roundi(p.x), roundi(p.y), col)


func _px(x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, col)


## A dark outline round the whole figure.
func _outline() -> void:
	var src := img.duplicate()
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and src.get_pixelv(q).a > 0.0:
					img.set_pixel(x, y, INK)
					break
