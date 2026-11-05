extends Node2D
## Game controller: battlefield, waves, gold, input and hiring.

const Data = preload("res://scripts/data.gd")
const Warrior = preload("res://scripts/warrior.gd")
const Barricade = preload("res://scripts/barricade.gd")
const Pathing = preload("res://scripts/pathing.gd")
const Castle = preload("res://scripts/castle.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Fx = preload("res://scripts/fx.gd")
const Hud = preload("res://scripts/hud.gd")
const Sprites = preload("res://scripts/sprites.gd")
const Audio = preload("res://scripts/audio.gd")
const Grave = preload("res://scripts/grave.gd")
const FieldArt = preload("res://scripts/field_art.gd")
const Ambience = preload("res://scripts/ambience.gd")
const Tutorial = preload("res://scripts/tutorial.gd")
const CastlePowers = preload("res://scripts/castle_powers.gd")

var FIELD_W := 640         # widens to fill the screen (see _fit_screen); 640 in a normal window
const FIELD_H := 768
const CASTLE_Y := 736      # top of the castle wall: enemies that reach it get in
const TILE := 64
const DEPLOY_TOP := 96     # warriors can't be posted in the enemy entry zone
const MIN_POST_GAP := 30.0

const FREEPLAY_GOLD := 999999
const FREEPLAY_MAX_LEVEL := 40

var started := false     # set once the player picks a mode
var selected_grave = null   # Hardcore: a grave clicked to see who fell there
var grave_layer := Node2D.new()
var ambience := Ambience.new()   # the mood over the field (light, weather, critters), by mode
var powers := CastlePowers.new()   # the Castle tab: abilities, Stone Walls, Ballistae
var permadeath := false   # Hardcore: knocked-out warriors die for good unless a Healer revives them
var freeplay := false    # sandbox: unlimited gold, the castle can't fall, spawn any wave at will
var freeplay_level := 1  # wave level used for freeplay spawns
var tutorial := false    # tutorial mode: a normal game with a guide, where the castle can't fall
var gold: int = Data.START_GOLD
var difficulty := "normal"   # a key of Data.DIFFICULTIES ("normal" in freeplay)
var cost_mult := 1.0         # prices for this difficulty
var castle_max: float = Data.CASTLE_HP
var castle_hp: float = Data.CASTLE_HP
var down_time := 20.0        # seconds a knocked-out warrior stays down (Hardcore: before it dies)
var margin := Vector2.ZERO   # spare screen above and below the game on a tall window
var gates_warned := false   # "at the gates" has been shown this wave
var wave := 0
var wave_active := false
var game_over := false
var victory := false
var endless := false     # carried on past the final wave; enemies keep scaling until the line falls
var choosing := false    # the "keep going?" screen is up after the final wave
var records_path := "user://records.cfg"   # best number of waves survived, per mode ("" = don't keep)

var spawn_queue: Array = []   # [enemy kind, wave level] pairs waiting to enter
var boss_spawned := false     # this wave's boss has come out
var spawn_timer := 0.0
var spawn_interval := 0.8

var placing_type := ""
var wall_start = null     # first click while placing a barricade (Vector2), or null
var last_priority := {}   # unit kind -> target priority new hires start with
var selected: Warrior = null
var mouse := Vector2.ZERO
var dragging: Warrior = null     # unit being repositioned between waves
var drag_origin := Vector2.ZERO
var drag_offset := Vector2.ZERO

var castle := Castle.new()
var wall_layer := Node2D.new()
var warrior_layer := Node2D.new()
var enemy_layer := Node2D.new()
var fx_layer := Node2D.new()
var overlay := Node2D.new()
var hud: CanvasLayer
var paths := Pathing.new()
var audio: Audio
var layer_timer := 0.0
var bard_instruments := []   # what the Bards on the field are playing (see _bard_instruments)
var last_track := ""
var song_on := true   # the player can switch the eight-Bard song off (from any Bard's panel)


func _ready() -> void:
	Engine.time_scale = 1.0
	audio = Audio.new()
	add_child(audio)
	audio.set_track("calm")
	paths.setup(self)
	castle.main = self
	# The castle goes over the warriors (it hides any standing behind it, showing their
	# silhouettes) but under the enemies, effects and overlay.
	ambience.main = self
	ambience.setup("normal")
	powers.main = self
	for layer in [grave_layer, wall_layer, warrior_layer, castle, enemy_layer, powers, fx_layer, ambience, overlay]:
		add_child(layer)
	overlay.draw.connect(_draw_overlay)
	hud = Hud.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS   # stays clickable while the game is paused
	add_child(hud)
	hud.hire_pressed.connect(_on_hire_pressed)
	hud.start_wave_pressed.connect(start_wave)
	hud.upgrade_pressed.connect(upgrade_selected)
	hud.sell_pressed.connect(sell_selected)
	hud.target_pressed.connect(cycle_target_priority)
	hud.song_pressed.connect(toggle_song)
	hud.speed_pressed.connect(cycle_speed)
	hud.restart_pressed.connect(_restart)
	hud.menu_confirmed.connect(_restart)
	hud.endless_chosen.connect(continue_endless)
	hud.finish_chosen.connect(func(): _finish(true))
	hud.mode_chosen.connect(choose_mode)
	hud.freeplay_level_changed.connect(change_freeplay_level)
	hud.freeplay_spawn_pressed.connect(spawn_single)
	hud.freeplay_clear_pressed.connect(clear_enemies)
	hud.castle_pressed.connect(castle_item)
	hud.power_pressed.connect(func(k): powers.trigger(k))
	hud.show_mode_select()
	get_viewport().size_changed.connect(_fit_screen)
	_fit_screen()


## Fills the window (the project stretches with "expand"): on a wide screen the
## battlefield itself gets wider, with the panel's controls centred along the
## bottom; on a tall one the game is centred. When the width changes, everything
## on the field keeps its place relative to the field's width (a unit posted near
## the right edge of a full screen is still near the right edge in a window).
## Walls stretch or shrink with the field, each end keeping its place across it,
## so walls joined end to end (or built against the edge) stay that way; their
## health and prices stay those of the length they were built at. Everything is
## placed from where the player put it, never from the last resize, so going small
## and back to full screen puts everything back where it was.
func _fit_screen() -> void:
	var view := get_viewport().get_visible_rect().size
	var new_w := maxi(int(Hud.WIDTH), int(view.x))
	margin = Vector2(0, maxf(0.0, floorf((view.y - Hud.HEIGHT) / 2.0)))
	position = margin
	hud.offset = margin
	hud.layout(new_w)
	if new_w != FIELD_W:
		var old_w := FIELD_W
		var k := float(new_w) / old_w
		FIELD_W = new_w
		for layer in [enemy_layer, fx_layer]:
			for n in layer.get_children():
				n.position.x *= k
				if "target_pos" in n:
					n.target_pos.x *= k
		for w in warrior_layer.get_children():
			if w.post != w.fitted_post:
				w.post_u = w.post.x / old_w   # placed or moved since the last resize
			w.post.x = w.post_u * FIELD_W
			w.fitted_post = w.post
			if w.is_emplacement():
				w.position = w.post
			else:
				w.position.x *= k
				w.route = PackedVector2Array()
		for b in wall_layer.get_children():
			if b.post != b.fitted_post:
				b.end_u = Vector2(b.seg_a().x, b.seg_b().x) / old_w   # built or moved since the last resize
			var ax: float = b.end_u.x * FIELD_W
			var bx: float = b.end_u.y * FIELD_W
			b.half.x = (bx - ax) / 2.0
			b.position.x = (ax + bx) / 2.0
			b.post = b.position
			b.fitted_post = b.post
			b.queue_redraw()
		if wall_start != null:
			wall_start.x *= k
		paths.setup(self)
		walls_changed()
		castle.lay_out()
	castle.queue_redraw()
	queue_redraw()


## mode: a difficulty ("easy", "normal", "hard", "hardcore"), "freeplay" or "tutorial".
func choose_mode(mode: String) -> void:
	freeplay = mode == "freeplay"
	tutorial = mode == "tutorial"
	difficulty = "normal" if freeplay or tutorial else mode
	ambience.setup(mode)
	castle.modulate = ambience.castle_tint()
	queue_redraw()
	var d: Dictionary = Data.DIFFICULTIES[difficulty]
	permadeath = d["permadeath"]
	down_time = d["down_time"]
	cost_mult = d["cost"]
	castle_max = roundf(Data.CASTLE_HP * d["castle"])
	castle_hp = castle_max
	hud.set_prices(cost_mult)
	if freeplay:
		gold = FREEPLAY_GOLD
		hud.show_freeplay_bar()
	started = true
	hud.hide_mode_select()
	if tutorial:
		var guide := Tutorial.new()
		guide.main = self
		guide.hud = hud
		hud.add_child(guide)


func _process(delta: float) -> void:
	mouse = get_local_mouse_position()
	if dragging != null:
		_update_drag()
	if selected != null and (not is_instance_valid(selected) or selected.is_queued_for_deletion()):
		selected = null
	if not game_over:
		if not spawn_queue.is_empty():
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				var next: Array = spawn_queue.pop_front()
				_spawn_enemy(next[0], next[1])
				spawn_timer = spawn_interval
		if freeplay:
			# No wave rounds in freeplay: "active" just means enemies are around.
			gold = FREEPLAY_GOLD
			wave_active = not spawn_queue.is_empty() or not get_enemies().is_empty()
			if not wave_active:
				castle_hp = castle_max   # sandbox: patched up once the field is clear
				gates_warned = false
		elif wave_active and spawn_queue.is_empty() and get_enemies().is_empty():
			if _boss_due():
				_spawn_boss()
			else:
				_end_wave()
	hud.refresh(self)
	if not game_over:
		layer_timer -= delta
		if layer_timer <= 0.0:
			layer_timer = 0.5
			bard_instruments = _bard_instruments()
			audio.set_layers(bard_instruments)
		# Between waves, a Bard on every instrument strikes up a song together.
		var ensemble: bool = song_on and audio._music.has("ensemble") and all_bards_present()
		audio.set_track("battle" if wave_active else ("ensemble" if ensemble else "calm"))
		if audio._playing_track != last_track:
			if audio._playing_track == "ensemble":
				hud.show_message("The Bards strike up a song together!")
			last_track = audio._playing_track
	# Hovering a unit on the field shows its description card.
	var hovered: Warrior = null
	if started and not game_over and dragging == null and placing_type == "" and mouse.y <= FIELD_H:
		hovered = _warrior_at(mouse)
	hud.show_unit_card(hovered, mouse)
	overlay.queue_redraw()


func get_enemies() -> Array:
	return enemy_layer.get_children().filter(func(e): return not e.dead)


## Hardcore: a unit has died for good, so a grave (or a ruin) marks the spot.
func add_grave(w) -> void:
	if w.summoned or w.clone_of != null or w is Barricade:
		return
	var g := Grave.new()
	g.setup_from(w)
	grave_layer.add_child(g)


func get_graves() -> Array:
	return grave_layer.get_children()


func _grave_at(p: Vector2):
	for g in get_graves():
		if g.position.distance_to(p) < 18.0:
			return g
	return null


func get_warriors() -> Array:
	return warrior_layer.get_children().filter(func(w): return not w.is_queued_for_deletion())


func get_barricades() -> Array:
	return wall_layer.get_children().filter(func(b): return not b.is_queued_for_deletion())


## Recomputes enemy routes; call whenever a wall goes up, comes down or moves.
func walls_changed() -> void:
	paths.invalidate()


## The standing barricade nearest to p, if its face is within `reach` of p.
func barricade_touching(p: Vector2, reach: float):
	var best = null
	var best_d := reach
	for b in get_barricades():
		if not b.is_active():
			continue
		var d: float = b.gap_from(p)
		if d <= best_d:
			best_d = d
			best = b
	return best


# --- Waves ---------------------------------------------------------------

func start_wave() -> void:
	if freeplay:
		spawn_freeplay_wave()
		return
	if wave_active or game_over or not started or choosing:
		return
	if dragging != null:
		_end_drag()
	wave += 1
	sfx("horn")
	wave_active = true
	boss_spawned = false
	gates_warned = false
	spawn_queue = _build_wave(wave).map(func(k): return [k, wave])
	spawn_interval = maxf(0.35, 0.9 - wave * 0.03)
	spawn_timer = 0.0
	var warlords := _warlords(wave)
	var wyverns := _wyverns(wave)
	if warlords > 1:
		hud.show_message("Wave %d: %d Warlords approach!" % [wave, warlords])
	elif warlords == 1:
		hud.show_message("Wave %d: a Warlord approaches!" % wave)
	elif wyverns > 1:
		hud.show_message("Wave %d: %d Wyverns circle overhead!" % [wave, wyverns])
	elif wyverns == 1:
		hud.show_message("Wave %d: a Wyvern circles overhead!" % wave)
	else:
		hud.show_message("Wave %d" % wave)


func _build_wave(n: int) -> Array:
	var pool := ["goblin", "goblin"]
	if n >= 2:
		pool.append("orc")
	if n >= 3:
		pool.append("wolf")
	if n >= 4:
		pool.append("bat")
	if n >= 6:
		pool.append("troll")
	if n >= 7:
		pool.append("sapper")
	var list := []
	for i in 6 + n * 2:
		list.append(pool.pick_random())
	if n == 4 or n == 5:
		list.insert(list.size() / 2, "troll")  # a single troll as an early taste
	for i in _warlords(n):
		list.append("warlord")
	for i in _wyverns(n):
		list.insert(list.size() * (i + 1) / (_wyverns(n) + 1), "wyvern")
	return list


## Warlords lead every fifth wave; past the final wave, one more for every ten waves.
func _warlords(n: int) -> int:
	if n % 5 != 0:
		return 0
	return 1 + maxi(0, n - Data.FINAL_WAVE) / 10


## Wyverns, the flying elite, swoop in on the even waves from 12 that no Warlord
## leads; past the final wave, one more for every ten waves.
func _wyverns(n: int) -> int:
	if n < 12 or n % 2 == 1 or n % 5 == 0:
		return 0
	return 1 + maxi(0, n - Data.FINAL_WAVE) / 10


func _spawn_enemy(kind: String, level: int, at = null) -> void:
	var d: Dictionary = Data.ENEMIES[kind]
	var r: float = d["radius"]
	if at == null:
		at = Vector2(FIELD_W / 2.0 if d.get("boss", false) else randf_range(r + 10, FIELD_W - r - 10), -r)
	var e := Enemy.new()
	e.setup(kind, d, self, at,
			Data.level_growth(level, Data.HP_GROWTH, Data.LATE_HP_GROWTH),
			Data.level_growth(level, Data.DAMAGE_GROWTH, Data.LATE_DAMAGE_GROWTH),
			1.0 + Data.BOUNTY_GROWTH * (level - 1))
	e.level = level
	e.died.connect(_on_enemy_died)
	e.reached_castle.connect(_on_enemy_at_castle)
	enemy_layer.add_child(e)
	if e.boss:
		hud.show_message("The Ogre King approaches!")


## An enemy called in mid-fight (by the Ogre King).
func spawn_minion(kind: String, level: int, at: Vector2) -> void:
	_spawn_enemy(kind, level, at.clamp(Vector2(20, -20), Vector2(FIELD_W - 20, CASTLE_Y - 40)))


## The Ogre King's war horn: a fresh wave marches in from the top of the field.
func reinforce(kinds: Array, level: int) -> void:
	sfx("horn", 0.75)
	spawn_queue.append_array(kinds.map(func(k): return [k, level]))
	hud.show_message("The war horn sounds! More enemies are coming!")


## The final wave, and every tenth wave past it, ends with the Ogre King once
## everything else is beaten.
func _boss_due() -> bool:
	return not boss_spawned and wave >= Data.FINAL_WAVE and (wave - Data.FINAL_WAVE) % 10 == 0


func _spawn_boss() -> void:
	boss_spawned = true
	_spawn_enemy("ogre_king", wave)


## Share of bounties and wave bonuses paid: all of it up to the final wave, then a
## little less each endless wave (2% per wave, down to 40%).
func late_gold_share() -> float:
	return maxf(Data.LATE_GOLD_MIN, 1.0 - Data.LATE_GOLD_STEP * maxi(0, wave - Data.FINAL_WAVE))


## Gold from a kill or a cleared wave, trimmed in endless so late waves stay a squeeze.
func late_gold(amount: int) -> int:
	if wave <= Data.FINAL_WAVE or amount <= 0:
		return amount
	return maxi(1, roundi(amount * late_gold_share()))


func _on_enemy_died(e) -> void:
	sfx("die", 1.3 if e.radius < 14.0 else (0.7 if e.radius > 20.0 else 1.0))
	var bounty := late_gold(e.bounty)
	gold += bounty
	spawn_text(e.position, "+%d" % bounty, Color(1, 0.85, 0.2))
	# Necromancy: what dies rotting gets back up on your side.
	if e.decay_timer > 0.0 and is_instance_id_valid(e.decay_source):
		var mage = instance_from_id(e.decay_source)
		if is_instance_valid(mage) and not mage.is_queued_for_deletion() and mage.is_active():
			mage.raise_from_corpse(e.position)


func _on_enemy_at_castle(_e) -> void:
	if not gates_warned and not game_over:
		gates_warned = true
		hud.show_message("The enemy is at the gates!")


## Enemies hitting the castle. In freeplay it can't fall.
func damage_castle(amount: float) -> void:
	if game_over or amount <= 0.0:
		return
	castle_hp -= amount
	castle.struck(amount)
	sfx("castle")
	if amount >= 15.0:
		spawn_text(Vector2(randf_range(80, FIELD_W - 80), CASTLE_Y - 10), "-%d" % roundi(amount), Color(1, 0.3, 0.3))
	if freeplay or tutorial:
		castle_hp = maxf(castle_hp, 1.0)   # can't fall here
	elif castle_hp <= 0.0:
		castle_hp = 0.0
		_finish(false)


# --- Castle ---------------------------------------------------------------

## A Castle tab button: "repair", or a castle upgrade (bought if it isn't yet, cast
## if it's an ability that is).
func castle_item(key: String) -> void:
	if game_over or not started:
		return
	if key == "repair":
		repair_castle()
	elif powers.owned.has(key):
		powers.trigger(key)
	elif powers.buy(key):
		pass
	elif not powers.owned.has(key):
		hud.show_message("Not enough gold")


## What a repair mends now, and what it costs (less than a full repair's price when
## the castle needs less than that).
func repair_amount() -> float:
	return minf(castle_max * Data.REPAIR_SHARE, castle_max - castle_hp)


func repair_cost() -> int:
	var full := price(Data.REPAIR_BASE + Data.REPAIR_PER_WAVE * wave)
	return maxi(1, ceili(full * repair_amount() / (castle_max * Data.REPAIR_SHARE)))


func can_repair() -> bool:
	return not wave_active and not game_over and repair_amount() >= 1.0 and gold >= repair_cost()


func repair_castle() -> void:
	if wave_active:
		hud.show_message("Repairs wait until the wave is over")
		return
	if not can_repair():
		return
	var amount := repair_amount()
	gold -= repair_cost()
	castle_hp += amount
	sfx("place")
	spawn_text(Vector2(FIELD_W / 2.0, CASTLE_Y - 60), "+%d castle" % roundi(amount), Color(0.5, 1.0, 0.5))


func _end_wave() -> void:
	wave_active = false
	sfx("fanfare")
	var bonus := late_gold(20 + wave * 5)
	gold += bonus
	# Gold Mines pay their end-of-wave bonus on top, and every Treasury pays interest
	# (each on the gold you had before any interest came in).
	var banked := gold
	for w in get_warriors():
		var interest := 0
		if w.is_active() and not w.interest.is_empty():
			interest = mini(int(banked * w.interest[0]), int(w.interest[1]))
		gold += w.wave_payout(interest)
	if wave == Data.FINAL_WAVE and not endless:
		choosing = true
		Engine.time_scale = 1.0
		_cancel()
		hud.show_victory_choice(wave)
	else:
		hud.show_message("Wave %d cleared! +%d gold" % [wave, bonus])


# --- Freeplay ------------------------------------------------------------

func change_freeplay_level(step: int) -> void:
	freeplay_level = clampi(freeplay_level + step, 1, FREEPLAY_MAX_LEVEL)


## Queues the selected wave on top of whatever is already coming.
func spawn_freeplay_wave() -> void:
	if not started or game_over:
		return
	if dragging != null:
		_end_drag()
	spawn_queue.append_array(_build_wave(freeplay_level).map(func(k): return [k, freeplay_level]))
	spawn_interval = maxf(0.35, 0.9 - freeplay_level * 0.03)
	hud.show_message("Wave %d incoming" % freeplay_level)


func spawn_single(kind: String) -> void:
	if dragging != null:
		_end_drag()
	_spawn_enemy(kind, freeplay_level)


func clear_enemies() -> void:
	spawn_queue.clear()
	for e in get_enemies():
		e.dead = true
		e.queue_free()


## After the final wave: carry on with ever-stronger waves.
func continue_endless() -> void:
	endless = true
	choosing = false
	hud.show_message("Endless: enemies grow stronger faster, and bounties shrink")


func _finish(won: bool) -> void:
	audio.set_track("")
	sfx("victory" if won else "defeat")
	choosing = false
	game_over = true
	victory = won
	wave_active = false
	Engine.time_scale = 1.0
	_cancel()
	enemy_layer.process_mode = Node.PROCESS_MODE_DISABLED
	warrior_layer.process_mode = Node.PROCESS_MODE_DISABLED
	wall_layer.process_mode = Node.PROCESS_MODE_DISABLED
	var survived := wave if won else wave - 1
	var previous := _save_record(survived)
	hud.show_end(won, survived, previous, endless)


## Records the waves survived if it beats this mode's best; returns the best from before.
func _save_record(survived: int) -> int:
	if records_path == "" or tutorial:
		return 0
	var cfg := ConfigFile.new()
	cfg.load(records_path)
	var key := difficulty
	var previous: int = cfg.get_value("best", key, 0)
	if survived > previous:
		cfg.set_value("best", key, survived)
		cfg.save(records_path)
	return previous


func _restart() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func cycle_speed() -> void:
	if game_over:
		return
	Engine.time_scale = 1.0 if Engine.time_scale >= 3.0 else Engine.time_scale + 1.0


# --- Warriors ------------------------------------------------------------

func _on_hire_pressed(kind: String) -> void:
	if game_over:
		return
	selected = null
	wall_start = null
	powers.aiming = ""
	placing_type = "" if placing_type == kind else kind


func can_post_at(p: Vector2, ignore: Warrior = null) -> bool:
	if p.x < 0 or p.x > FIELD_W or p.y < DEPLOY_TOP or p.y > CASTLE_Y:
		return false
	for w in get_warriors():
		if w != ignore and w.post.distance_to(p) < MIN_POST_GAP:
			return false
	for b in get_barricades():
		if b.gap_from(p) < Warrior.RADIUS:
			return false
	return true


# --- Barricades ----------------------------------------------------------

## Where a wall started at `a` ends when the player points at `b`: clamped to the
## field and to the longest wall allowed.
## Walls can be as long as the field allows; the price is the only limit.
func wall_end(_a: Vector2, b: Vector2) -> Vector2:
	return _clamp_wall_point(b)


func _clamp_wall_point(p: Vector2) -> Vector2:
	return p.clamp(Vector2(0, DEPLOY_TOP), Vector2(FIELD_W, CASTLE_Y - 16))


func wall_cost(a: Vector2, b: Vector2) -> int:
	return price(Barricade.cost_for(Data.WARRIORS["barricade"], a.distance_to(b)))


## A price adjusted for the difficulty.
func price(base: int) -> int:
	return maxi(1, roundi(base * cost_mult))


## What hiring this kind costs (the shortest wall, for a barricade).
func hire_cost(kind: String) -> int:
	return price(Data.WARRIORS[kind]["cost"])


## Why a wall can't go from a to b ("" if it can). Walls may cross each other,
## but not run through another unit's post.
func wall_problem(a: Vector2, b: Vector2) -> String:
	if a.distance_to(b) < Data.WARRIORS["barricade"]["min_length"]:
		return "Too short"
	for w in get_warriors():
		var c := Geometry2D.get_closest_point_to_segment(w.post, a, b)
		if c.distance_to(w.post) < Warrior.RADIUS + Barricade.WALL_HALF:
			return "Blocked by a unit"
	return ""


## Barricades go down in two clicks: where the wall starts, then where it ends.
func _wall_click(p: Vector2) -> void:
	if wall_start == null:
		if p.y >= DEPLOY_TOP:
			wall_start = _clamp_wall_point(p)
		return
	var a: Vector2 = wall_start
	var b := wall_end(a, p)
	var problem := wall_problem(a, b)
	if problem != "":
		hud.show_message(problem)
		return
	var cost := wall_cost(a, b)
	if gold < cost:
		hud.show_message("Not enough gold")
		return
	gold -= cost
	sfx("place")
	var wall := Barricade.new()
	wall.half = (b - a) / 2.0
	wall.setup("barricade", Data.WARRIORS["barricade"], self, (a + b) / 2.0)
	wall.spent = cost
	wall.position = wall.post
	wall_layer.add_child(wall)
	walls_changed()
	wall_start = null
	# Hold Shift to keep building walls.
	if not Input.is_key_pressed(KEY_SHIFT) or gold < hire_cost("barricade"):
		placing_type = ""


func hire_at(p: Vector2) -> void:
	if placing_type == "barricade":
		_wall_click(p)
		return
	if not can_post_at(p):
		return
	var data: Dictionary = Data.WARRIORS[placing_type]
	var cost := hire_cost(placing_type)
	if gold < cost:
		hud.show_message("Not enough gold")
		placing_type = ""
		return
	gold -= cost
	sfx("place")
	var w := Warrior.new()
	w.setup(placing_type, data, self, _clamp_post(p))
	w.spent = cost
	w.priority = last_priority.get(placing_type, "closest")
	# New hires march in from whichever side of the field is nearer their post;
	# emplacements are built on the spot.
	w.position = w.post if w.is_emplacement() else _entry_point(w.post)
	warrior_layer.add_child(w)
	# Hold Shift to keep hiring the same type.
	if not Input.is_key_pressed(KEY_SHIFT) or gold < cost:
		placing_type = ""


## Where a new troop walks on: the nearer side edge, level with its post, nudged up
## or down the edge if a wall runs into it there.
func _entry_point(post: Vector2) -> Vector2:
	var r := Warrior.RADIUS
	var x := r if post.x < FIELD_W / 2.0 else FIELD_W - r
	for step in 40:
		for sign in [1, -1]:
			var y := clampf(post.y + sign * step * 8.0, DEPLOY_TOP, CASTLE_Y - r)
			var spot := Vector2(x, y)
			if not get_barricades().any(func(b): return b.gap_from(spot) < r + 2.0):
				return spot
	return Vector2(x, post.y)


func _clamp_post(p: Vector2) -> Vector2:
	var r := Warrior.RADIUS
	return p.clamp(Vector2(r, DEPLOY_TOP), Vector2(FIELD_W - r, CASTLE_Y - r))


func order_move(p: Vector2) -> void:
	if selected == null or not can_post_at(p, selected):
		return
	if selected.is_emplacement():
		hud.show_message("Emplacements can't move during a wave")
		return
	selected.order_to(_clamp_post(p))


func upgrade_selected(path: int) -> void:
	if selected == null or selected.path_state(path) != "ok":
		return
	var cost := selected.upgrade_cost(path)
	if gold < cost:
		return
	var tier_name: String = selected.next_tier(path)["name"]
	gold -= cost
	selected.upgrade(path)
	sfx("upgrade")
	spawn_text(selected.position + Vector2(0, -50), tier_name, Warrior.PATH_COLORS[path])
	if selected is Barricade:
		walls_changed()   # an Energy Wall may now let troops or shots through


# Between waves, units can be dragged anywhere and snap straight to the new spot.
func _start_drag(w: Warrior) -> void:
	dragging = w
	drag_origin = w.post
	drag_offset = w.post - mouse


func _update_drag() -> void:
	if not is_instance_valid(dragging):
		dragging = null
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_end_drag()
		return
	var p := _clamp_post(mouse + drag_offset)
	if dragging is Barricade:
		p = _clamp_wall_center(dragging, mouse + drag_offset)
	dragging.post = p
	dragging.position = p


func _end_drag() -> void:
	var w := dragging
	dragging = null
	if not is_instance_valid(w):
		return
	var ok := can_post_at(w.post, w)
	if w is Barricade:
		ok = wall_problem(w.seg_a(), w.seg_b()) == ""
	var p := w.post if ok else drag_origin
	w.set_post(p)
	w.position = p
	if w is Barricade:
		walls_changed()


## Keeps a dragged wall's both ends on the field.
func _clamp_wall_center(w, p: Vector2) -> Vector2:
	var h: Vector2 = w.half.abs()
	return p.clamp(Vector2(h.x, DEPLOY_TOP + h.y), Vector2(FIELD_W - h.x, CASTLE_Y - 16 - h.y))


func cycle_target_priority() -> void:
	if selected == null:
		return
	selected.cycle_priority()
	last_priority[selected.kind] = selected.priority
	spawn_text(selected.position + Vector2(0, -50), "Target: " + Warrior.PRIORITY_NAMES[selected.priority], Color(1, 1, 0.6))


func sell_selected() -> void:
	if selected == null:
		return
	if selected.summoned:
		hud.show_message("Skeletons can't be sold")
		return
	gold += selected.sell_value()
	sfx("sell")
	selected.queue_free()
	if selected is Barricade:
		walls_changed()
	selected = null


## Shows a hire tab, letting go of any selected unit so the hire buttons are visible.
func switch_tab(tab: String) -> void:
	if dragging != null:
		_end_drag()
	selected = null
	if placing_type != "" and (tab == "castle" or hud.tab_of(placing_type) != tab):
		placing_type = ""   # the hire being placed isn't on the new tab
		wall_start = null
	hud.show_tab(tab)


func _cancel() -> void:
	powers.aiming = ""
	placing_type = ""
	wall_start = null
	selected = null
	selected_grave = null


func _warrior_at(p: Vector2) -> Warrior:
	var best: Warrior = null
	var best_d := Warrior.RADIUS + 6.0
	for w in get_warriors():
		if w.summoned:
			continue   # skeletons can't be picked up, moved or sold
		var d: float = w.position.distance_to(p)
		if d < best_d:
			best_d = d
			best = w
	if best == null:
		# Walls are picked anywhere along their length (they're drawn standing up from the line).
		best_d = 14.0
		for b in get_barricades():
			var d: float = b.gap_from(p + Vector2(0, 8))
			if d < best_d:
				best_d = d
				best = b
	return best


# --- Input ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if game_over or not started:
		return
	if event is InputEventMouseButton and event.pressed:
		var p := get_local_mouse_position()
		if p.y > FIELD_H or p.y < 0.0 or p.x < 0.0 or p.x > FIELD_W:
			return   # off the field (the panel, or the scenery around a full screen)
		if powers.aiming != "":
			if event.button_index == MOUSE_BUTTON_LEFT:
				powers.aim_click(p)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				powers.aiming = ""
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if selected != null:
				order_move(p)
			else:
				_cancel()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if placing_type != "":
				hire_at(p)
			else:
				selected = _warrior_at(p)
				selected_grave = _grave_at(p) if selected == null else null
				if selected != null and not wave_active:
					_start_drag(selected)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				# Number keys pick from whichever hire tab is showing.
				var i: int = event.keycode - KEY_1
				if hud.hire_tab == "castle":
					var items: Array = hud.castle_items()
					if i < items.size():
						castle_item(items[i])
					return
				var kinds: Array = hud.tab_kinds(hud.hire_tab)
				if i < kinds.size():
					_on_hire_pressed(kinds[i])
			KEY_TAB:
				var order := ["troops", "emplacements", "castle"]
				switch_tab(order[(order.find(hud.hire_tab) + 1) % order.size()])
			KEY_C:
				switch_tab("castle")
			KEY_Z:
				switch_tab("troops")
			KEY_X:
				switch_tab("emplacements")
			KEY_SPACE:
				start_wave()
			KEY_Q:
				upgrade_selected(0)
			KEY_W:
				upgrade_selected(1)
			KEY_E:
				upgrade_selected(2)
			KEY_R:
				upgrade_selected(3)
			KEY_S:
				sell_selected()
			KEY_T:
				cycle_target_priority()
			KEY_G:
				toggle_song()
			KEY_F:
				cycle_speed()
			KEY_ESCAPE:
				_cancel()


# --- Effects -------------------------------------------------------------

func add_projectile(p: Node2D) -> void:
	fx_layer.add_child(p)


func spawn_text(pos: Vector2, text: String, color: Color) -> void:
	var f := Fx.new()
	f.mode = "text"
	f.text = text
	f.color = color
	f.position = pos
	fx_layer.add_child(f)


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
	fx_layer.add_child(f)


func spawn_flame(from: Vector2, to: Vector2) -> void:
	var f := Fx.new()
	f.mode = "flame"
	f.points = PackedVector2Array([from, to])
	f.life = 0.2
	fx_layer.add_child(f)


func spawn_flash(pos: Vector2, radius: float) -> void:
	var f := Fx.new()
	f.mode = "flash"
	f.radius = radius
	f.life = 0.4
	f.position = pos
	fx_layer.add_child(f)


func spawn_beam(from: Vector2, to: Vector2, color: Color, width := 30.0) -> void:
	var f := Fx.new()
	f.mode = "beam"
	f.points = PackedVector2Array([from, to])
	f.color = color
	f.radius = width
	f.life = 0.35
	fx_layer.add_child(f)


func spawn_tornado(pos: Vector2, radius: float) -> void:
	var f := Fx.new()
	f.mode = "tornado"
	f.radius = radius
	f.life = 0.8
	f.position = pos
	fx_layer.add_child(f)


func spawn_note(pos: Vector2, color: Color) -> void:
	var f := Fx.new()
	f.mode = "note"
	f.color = color
	f.life = 0.9
	f.position = pos
	fx_layer.add_child(f)


## Fire Rain landing on a spot.
func spawn_area(mode: String, pos: Vector2, radius: float) -> void:
	var f := Fx.new()
	f.mode = mode
	f.radius = radius
	f.life = 0.5
	f.position = pos
	fx_layer.add_child(f)


## A skeleton raised by Necromancy joins the warriors.
func add_summon(w: Warrior) -> void:
	warrior_layer.add_child(w)


## Whether a Bard is on the field for every instrument (they can play their song).
func all_bards_present() -> bool:
	return audio != null and audio.INSTRUMENTS.all(func(i): return i in bard_instruments)


## The Song button on a Bard's panel: play the eight-Bard song between waves, or don't.
func toggle_song() -> void:
	if selected == null or selected.kind != "bard" or not all_bards_present():
		return
	song_on = not song_on
	hud.show_message("The Bards' song: " + ("on" if song_on else "off"))


## The instruments the Bards on the field are holding (each plays along with the music).
func _bard_instruments() -> Array:
	var found := {}
	for w in get_warriors():
		if w.kind == "bard":
			found[w.instrument_sound()] = true
	return found.keys()


## Plays a sound effect (see audio.gd).
func sfx(sound_name: String, pitch := 1.0) -> void:
	if audio != null:
		audio.play(sound_name, pitch)


func spawn_burst(pos: Vector2, radius: float, color: Color) -> void:
	var f := Fx.new()
	f.mode = "burst"
	f.radius = radius
	f.color = color
	f.life = 0.3
	f.position = pos
	fx_layer.add_child(f)


# --- Drawing -------------------------------------------------------------

func _draw() -> void:
	_draw_surroundings()
	# Pixel ground: dirt where enemies enter, grass (with the odd flower patch) below,
	# lit for the mode's mood; then the scenery on it (see field_art.gd).
	var tint: Color = ambience.ground_tint()
	for x in ceili(float(FIELD_W) / TILE):
		for y in FIELD_H / TILE:
			var variant := 4
			if (y + 1) * TILE > DEPLOY_TOP:
				var h := (x * 73856093) ^ (y * 19349663)
				variant = 3 if h % 11 == 0 else absi(h) % 3
			draw_texture_rect(Sprites.ground_tile(variant), Rect2(x * TILE, y * TILE, TILE, TILE), false, tint)
	draw_rect(Rect2(0, TILE, FIELD_W, DEPLOY_TOP - TILE), Color(Color(0.4, 0.3, 0.2) * tint, 0.55))
	FieldArt.draw_meadow(self, FIELD_W, tint)
	FieldArt.draw_spawn(self, FIELD_W, tint)
	for x in range(0, FIELD_W, 16):
		draw_rect(Rect2(x, DEPLOY_TOP - 2, 8, 4), Color(0.1, 0.05, 0.05, 0.6))


## The panel's colour carried on under the field across the whole width (the
## panel's controls stay 640 wide in the middle), and dark dirt above the field
## on a tall screen.
func _draw_surroundings() -> void:
	if margin.y > 0.0:
		draw_rect(Rect2(0, -margin.y, FIELD_W, margin.y), Color(0.2, 0.15, 0.1))
	draw_rect(Rect2(0, FIELD_H, FIELD_W, Hud.HEIGHT - FIELD_H + margin.y), Color(0.13, 0.11, 0.1))
	draw_rect(Rect2(0, FIELD_H, FIELD_W, 3), Color(0.45, 0.35, 0.2))


func _draw_overlay() -> void:
	if placing_type == "barricade" and mouse.y <= FIELD_H:
		_draw_wall_preview()
	elif placing_type != "" and mouse.y <= FIELD_H:
		var d: Dictionary = Data.WARRIORS[placing_type]
		var ok := can_post_at(mouse)
		var tint := Color(1, 1, 1, 0.6) if ok else Color(1, 0.3, 0.3, 0.6)
		var size := Vector2(Sprites.SIZE, Sprites.SIZE) * Warrior.SCALE
		var top_left := mouse + Vector2(-size.x / 2, Warrior.RADIUS - size.y)
		overlay.draw_texture_rect(Sprites.frames(placing_type)[0], Rect2(top_left, size), false, tint)
		var reach: float = d["range"] + Warrior.RADIUS
		overlay.draw_circle(mouse, reach, Color(1, 1, 1, 0.08), true, -1.0, true)
		overlay.draw_arc(mouse, reach, 0, TAU, 64, Color(1, 1, 1, 0.5), 2.0, true)
	if is_instance_valid(dragging) and dragging is Barricade:
		if wall_problem(dragging.seg_a(), dragging.seg_b()) != "":
			overlay.draw_line(dragging.seg_a(), dragging.seg_b(), Color(1, 0.25, 0.25, 0.45), 18.0)
	elif dragging != null and is_instance_valid(dragging) and not can_post_at(dragging.post, dragging):
		overlay.draw_circle(dragging.position, Warrior.RADIUS + 6, Color(1, 0.25, 0.25, 0.45), true, -1.0, true)
	if is_instance_valid(selected) and selected is Barricade:
		_draw_wall_selection(selected)
	elif selected != null and is_instance_valid(selected) and selected.data["attack"] in ["aura", "pulse"]:
		# A War Statue or Medic Bay: a thread to every unit it looks after.
		for w in get_warriors():
			if w != selected and selected.covers(w):
				overlay.draw_line(selected.position, w.position, Color(1, 1, 0.6, 0.35), 1.5, true)
				overlay.draw_circle(w.position, 4.0, Color(1, 1, 0.6, 0.7), true, -1.0, true)
	elif selected != null and is_instance_valid(selected):
		var post := selected.post
		var col := Color(1, 1, 0.6)
		# Attack range around the warrior, plus a marker for the post it returns to.
		var reach := selected.attack_range + Warrior.RADIUS
		overlay.draw_circle(selected.position, reach, Color(col, 0.1), true, -1.0, true)
		overlay.draw_arc(selected.position, reach, 0, TAU, 64, Color(col, 0.8), 2.0, true)
		if not selected.blast.is_empty():
			# Ki blast range, for Martial Artists who have learned it.
			var ki: float = selected.blast["range"] + Warrior.RADIUS
			overlay.draw_arc(selected.position, ki, 0, TAU, 64, Color(Warrior.KI_COLOR, 0.6), 1.5, true)
		if selected.position.distance_to(post) > reach:
			overlay.draw_line(selected.position, post, Color(col, 0.4), 1.5, true)
		overlay.draw_line(post + Vector2(-7, -7), post + Vector2(7, 7), col, 2.5, true)
		overlay.draw_line(post + Vector2(-7, 7), post + Vector2(7, -7), col, 2.5, true)


## Placing a barricade: a marker before the first click, then the wall-to-be with
## its length and price.
func _draw_wall_preview() -> void:
	if wall_start == null:
		var p := _clamp_wall_point(mouse)
		overlay.draw_circle(p, 6, Color(1, 1, 1, 0.7), true, -1.0, true)
		_overlay_text(p + Vector2(12, -10), "Click where the wall starts", Color.WHITE)
		return
	var a: Vector2 = wall_start
	var b := wall_end(a, mouse)
	var cost := wall_cost(a, b)
	var problem := wall_problem(a, b)
	var ok := problem == "" and gold >= cost
	var col := Color(1, 1, 1, 0.7) if ok else Color(1, 0.3, 0.3, 0.7)
	overlay.draw_line(a, b, Color(col, 0.25), Barricade.WALL_HALF * 2.0 + 8.0)
	overlay.draw_line(a, b, col, 4.0)
	var n := int(a.distance_to(b) / Barricade.STAKE_GAP)
	for i in n + 1:
		var p := a.lerp(b, i / maxf(n, 1.0))
		overlay.draw_line(p + Vector2(0, 4), p + Vector2(0, -16), col, 3.0)
	overlay.draw_circle(a, 5, col, true, -1.0, true)
	var label := "%s  %dg" % [Data.ft(a.distance_to(b)), cost]
	if problem != "":
		label += "  - " + problem
	elif gold < cost:
		label += "  - not enough gold"
	_overlay_text(b + Vector2(12, -10), label, Color(1, 0.85, 0.3) if ok else Color(1, 0.45, 0.4))


func _overlay_text(p: Vector2, text: String, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	p.x = clampf(p.x, 4.0, FIELD_W - w - 4.0)
	overlay.draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color.BLACK)
	overlay.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)


## A selected wall: highlighted along its length, plus the reach of its arrows or spikes.
func _draw_wall_selection(w) -> void:
	var col := Color(1, 1, 0.6)
	overlay.draw_line(w.seg_a(), w.seg_b(), Color(col, 0.25), Barricade.WALL_HALF * 2.0 + 10.0)
	var reach: float = maxf(w.attack_range, w.wall_slow[1] if not w.wall_slow.is_empty() else 0.0)
	if reach <= 0.0:
		return
	reach += Barricade.WALL_HALF
	var a: Vector2 = w.seg_a()
	var b: Vector2 = w.seg_b()
	var n: Vector2 = (b - a).normalized().orthogonal() * reach
	var ang := n.angle()
	overlay.draw_line(a + n, b + n, Color(col, 0.6), 2.0, true)
	overlay.draw_line(a - n, b - n, Color(col, 0.6), 2.0, true)
	overlay.draw_arc(a, reach, ang, ang + PI, 24, Color(col, 0.6), 2.0, true)
	overlay.draw_arc(b, reach, ang + PI, ang + TAU, 24, Color(col, 0.6), 2.0, true)
