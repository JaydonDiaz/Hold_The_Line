extends RefCounted
## Effects: projectiles, floating text, sparks, corpses, bolts, beams and the rest, and sounds.
## Part of the game controller: `main` is main.gd, which holds the battle's state.

const Main = preload("res://scripts/main.gd")
const Warrior = preload("res://scripts/troops/warrior.gd")
const Fx = preload("res://scripts/field/fx.gd")
const Sprites = preload("res://scripts/art/sprites.gd")

var main: Main


func _init(m: Main) -> void:
	main = m


# --- Effects -------------------------------------------------------------

func add_projectile(p: Node2D) -> void:
	main.fx_layer.add_child(p)


func spawn_text(pos: Vector2, text: String, color: Color) -> void:
	var f := Fx.new()
	f.mode = "text"
	f.text = text
	f.color = color
	f.position = pos
	main.fx_layer.add_child(f)


## Motes of light rising round a troop that's just been upgraded, in its path's colour.
func spawn_sparkle(pos: Vector2, color: Color) -> void:
	var f := Fx.new()
	f.mode = "sparkle"
	f.color = color
	f.radius = 18.0
	f.life = 0.8
	f.position = pos
	main.fx_layer.add_child(f)


## A slain enemy topples over and fades, with a puff of dust where it falls.
func spawn_corpse(e) -> void:
	if main.corpse_layer.get_child_count() > 40:   # (a huge wave dying at once: the rest just vanish)
		return
	var f := Fx.new()
	f.mode = "fall"
	f.tex = Sprites.frames(e.look)[0]
	f.radius = e.radius
	f.size = Vector2(Sprites.SIZE, Sprites.SIZE) * e.sprite_scale
	f.flip = e.flip
	f.height = 18.0 if e.flying else 0.0   # (enemy.gd FLY_HEIGHT)
	f.life = 0.55
	f.position = e.position
	main.corpse_layer.add_child(f)


func spawn_bolt(path: PackedVector2Array, color: Color) -> void:
	# Jag each segment so it reads as lightning.
	var pts := PackedVector2Array([path[0]])
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var side := (b - a).orthogonal().normalized()
		for j in range(1, 4):
			pts.append(a.lerp(b, j / 4.0) + side * randf_range(-7, 7))
		pts.append(b)
	var f := Fx.new()
	f.mode = "bolt"
	f.points = pts
	f.color = color
	f.life = 0.25
	main.fx_layer.add_child(f)


func spawn_flame(from: Vector2, to: Vector2) -> void:
	var f := Fx.new()
	f.mode = "flame"
	f.points = PackedVector2Array([from, to])
	f.life = 0.2
	main.fx_layer.add_child(f)


func spawn_flash(pos: Vector2, radius: float) -> void:
	var f := Fx.new()
	f.mode = "flash"
	f.radius = radius
	f.life = 0.4
	f.position = pos
	main.fx_layer.add_child(f)


func spawn_beam(from: Vector2, to: Vector2, color: Color, width := 30.0) -> void:
	var f := Fx.new()
	f.mode = "beam"
	f.points = PackedVector2Array([from, to])
	f.color = color
	f.radius = width
	f.life = 0.35
	main.fx_layer.add_child(f)


func spawn_tornado(pos: Vector2, radius: float) -> void:
	var f := Fx.new()
	f.mode = "tornado"
	f.radius = radius
	f.life = 0.8
	f.position = pos
	main.fx_layer.add_child(f)


func spawn_note(pos: Vector2, color: Color) -> void:
	var f := Fx.new()
	f.mode = "note"
	f.color = color
	f.life = 0.9
	f.position = pos
	main.fx_layer.add_child(f)


## Fire Rain landing on a spot.
func spawn_area(mode: String, pos: Vector2, radius: float) -> void:
	var f := Fx.new()
	f.mode = mode
	f.radius = radius
	f.life = 0.5
	f.position = pos
	main.fx_layer.add_child(f)


## A skeleton raised by Necromancy joins the warriors.
func add_summon(w: Warrior) -> void:
	main.warrior_layer.add_child(w)


## Whether a Bard is on the field for every instrument (they can play their song).
func all_bards_present() -> bool:
	return main.audio != null and main.audio.INSTRUMENTS.all(func(i): return i in main.bard_instruments)


## The Song button on a Bard's panel: play the eight-Bard song between waves, or don't.
func toggle_song() -> void:
	if main.selected == null or main.selected.kind != "bard" or not all_bards_present():
		return
	main.song_on = not main.song_on
	main.hud.show_message("The Bards' song: " + ("on" if main.song_on else "off"))


## The instruments the Bards on the field are holding (each plays along with the music).
func _bard_instruments() -> Array:
	var found := {}
	for w in main.battlefield.get_warriors():
		if w.kind == "bard":
			found[w.instrument_sound()] = true
	return found.keys()


## Gives a new button a soft click when it's pressed (see _ready).
func _click_on_press(node: Node) -> void:
	if node is BaseButton and not node.has_meta("silent"):
		node.pressed.connect(sfx.bind("click"))


## Plays a sound effect (see audio.gd).
func sfx(sound_name: String, pitch := 1.0) -> void:
	if main.audio != null:
		main.audio.play(sound_name, pitch)


func spawn_burst(pos: Vector2, radius: float, color: Color) -> void:
	var f := Fx.new()
	f.mode = "burst"
	f.radius = radius
	f.color = color
	f.life = 0.3
	f.position = pos
	main.fx_layer.add_child(f)
