extends RefCounted
## Sending waves: building each wave (squads, warbands, bosses), spawning the horde, bounties,
## the pace between waves, the end of a wave, and survival records.
## Part of the game controller: `main` is main.gd, which holds the battle's state.

const Main = preload("res://scripts/main.gd")
const Data = preload("res://scripts/data/data.gd")
const Warrior = preload("res://scripts/troops/warrior.gd")
const Enemy = preload("res://scripts/enemies/enemy.gd")
const Audio = preload("res://scripts/audio/audio.gd")
const Camp = preload("res://scripts/mission/camp.gd")
const Warband = preload("res://scripts/enemies/warband.gd")
const Barricade = preload("res://scripts/troops/barricade.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")
const Engineer = preload("res://scripts/troops/engineer.gd")

var main: Main

var rout_time := 0.0      # seconds it's looked that way (it has to last a moment)
var beat_best := false    # ...and whether this one has gone past it yet
var boss_spawned := false     # this wave's boss has come out
## Classic: the wave each of the later kinds first joins the waves' mix.
const NEW_FOES := {"drummer": 8, "shieldbearer": 9, "ogre": 10, "boltflinger": 11, "warmage": 13}
## A word of warning the first time a game sees one of these.
## The first time each kind of foe comes on in a battle, a card names it and says how
## to deal with it (bosses announce themselves; goblins need no introduction).
const FOE_HINTS := {
	"orc": ["Orc", "Tough and hits hard. Hold it with a Knight."],
	"wolf": ["Wolf", "Fast, and faster in a pack. Runs past your troops to bite at the walls."],
	"bat": ["Bat", "Flies over troops and walls: only ranged troops and spells reach it."],
	"skeleton_archer": ["Skeleton Archer", "Hangs back and shoots: rush it down, or outrange it."],
	"slime": ["Slime", "Blades and arrows can't hurt it. Use magic, ki, alchemy, explosives or ice (ice lets anything bite)."],
	"sapper": ["Sapper", "Carries a bomb for the nearest of your emplacements or walls (it's marked in red). Stop it on the way, or kill it while the fuse fizzes; a cheap Barricade in front draws it off."],
	"troll": ["Troll", "Heals its wounds if it's left unhurt for a few seconds. Keep hitting it; fire stops the healing."],
	"ogre": ["Ogre", "The Wallbreaker. Hauls its club back (its swing is marked on the ground), then throws troops out of the line. Spread out and hit it hard."],
	"warlord": ["Warlord", "A champion. Shrugs off stuns, and its great sweeping blows (marked on the ground) cut through troops packed together."],
	"shieldbearer": ["Shieldbearer", "Its great shield turns aside shots from the front, and shelters the archers, sappers and casters behind it. Flank it, or fight it hand to hand, or use spells."],
	"drummer": ["War Drummer", "Its drum drives on the goblins, wolves and other light troops round it. It's weak: kill it first."],
	"boltflinger": ["Boltflinger", "Slow to wind its great crossbow, but the bolt goes straight through a line of troops. Don't stand your troops one behind another in front of it."],
	"warmage": ["Horde Mage", "Stops and charges a spell; the colour at its staff tells you which. Blue: lightning that leaps between troops close together. Orange: a stream of fire in front of it. Violet: a beam at your healthiest troop. Stun it to break the spell, or kill it first."],
	"gravebinder": ["Gravebinder", "A necromancer of the horde, as tough as a Warlord. Calls up Skeleton Archers, and raises your fallen troops against you, upgrades and all (the stronger they were, the longer it takes: a green tether shows it). Stun it or kill it to break the rite."],
	"wyvern": ["Wyvern", "Flying elite that breathes fire, and swoops down a line it marks first, burning everyone under it. Needs ranged troops."],
}
var boss_down := ""   # "<a boss> is defeated!" until the wave it fell in is over (its message leads the wave's)
var formations_on := true   # the horde marches in warbands (off in the Tutorial)
var next_band := 0
const UNBOUND_WAVE := 50   # Classic: the wave from which the Ogre King comes back unbound
const CASTLE_ALARMS := [[0.5, "The castle's walls are cracking!"], [0.25, "The castle is about to fall!"]]
const PACE_WINDOW := 25.0   # forced pace: seconds from the last of a wave arriving to the next wave
const PACE_WINDOWS := {"capture": 16.0, "escort": 15.0, "protect": 18.0, "retreat": 20.0, "evac": 25.0, "assault": 18.0}   # ...by kind of battle
const MIN_BREAK := 5.0      # ...and the shortest breather once a wave's beaten
const REST_HEAL := 0.04     # share of its health a troop gets back each second of a breather
## Kinds that can't fight, sold off to pay for troops when it comes to it.
const NON_FIGHTERS := ["mine", "statue", "medbay", "barricade"]
const ROUT_GRACE := 3.0   # seconds with no army and no way to raise one before it's over


func _init(m: Main) -> void:
	main = m


# --- Waves ---------------------------------------------------------------

func start_wave(force := false) -> void:
	if main.freeplay:
		main.modes.spawn_freeplay_wave()
		return
	if (main.wave_active and not force) or main.game_over or not main.started:
		return
	if main.rules.holds_waves():
		return
	main.wave_clock = 0.0
	if main.dragging != null:
		main.groups._end_drag()
	if main.deploying:
		main.deploying = false
		main.hud.show_message("They're coming!")
	main.wave += 1
	main.effects.sfx("horn")
	boss_down = ""
	main.wave_active = true
	boss_spawned = false
	main.gates_warned = false
	var level := main.missions.wave_level(main.wave)
	main.spawn_queue = _banded(_build_wave(main.wave), level)
	main.spawn_interval = maxf(0.35, 0.9 - level * 0.03)
	main.spawn_timer = 0.0
	if main.missions.scripted():
		main.hud.show_message(main.mission.get("notes", {}).get(main.wave, main.rules.wave_text().replace("/", " of ")))
		return
	var warlords := _warlords(main.wave)
	var wyverns := _wyverns(main.wave)
	if warlords > 1:
		main.hud.show_message("Wave %d: %d Warlords approach!" % [main.wave, warlords])
	elif warlords == 1:
		main.hud.show_message("Wave %d: a Warlord approaches!" % main.wave)
	elif wyverns > 1:
		main.hud.show_message("Wave %d: %d Wyverns circle overhead!" % [main.wave, wyverns])
	elif wyverns == 1:
		main.hud.show_message("Wave %d: a Wyvern circles overhead!" % main.wave)
	else:
		main.hud.show_message("Wave %d" % main.wave if main.wave_squads.is_empty() else "Wave %d: %s!" % [main.wave, " and ".join(main.wave_squads.map(func(q): return "a " + q))])


func _build_wave(n: int) -> Array:
	if main.missions.scripted():
		return main.missions._mission_wave(n)
	var pool := ["goblin", "goblin"]
	if n >= 2:
		pool.append("orc")
		pool.append("skeleton_archer")
	if n >= 3:
		pool.append("wolf")
	if n >= 4:
		pool.append("bat")
	if n >= 6:
		pool.append("troll")
		pool.append("slime")
	if n >= 7:
		pool.append("sapper")
	# The rest of the horde, a kind at a time (each with its card the first time).
	for k in NEW_FOES:
		if n >= NEW_FOES[k]:
			pool.append(k)
	var list := []
	var squads := squads_for(n)
	var size := wave_size(n)
	for sq in squads:
		size -= (Data.SQUADS[sq]["kinds"] as Array).size()   # (squads take the place of so many of the rest)
	for i in maxi(size, wave_size(n) / 2):
		list.append(pool.pick_random())
	for sq in squads:
		var at := randi_range(list.size() / 4, list.size())
		var kinds: Array = Data.SQUADS[sq]["kinds"]
		for j in kinds.size():
			list.insert(at + j, kinds[j])   # (together: one after another)
	main.wave_squads = squads
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


## A wave's foes as spawn entries [kind, level, warband (-1: none)]: cut into warbands
## (warband.gd) that come on and form up together, each squad a band of its own.
func _banded(kinds: Array, level: int) -> Array:
	var ids := Warband.cut(kinds, main.wave_squads.map(func(q): return Data.SQUADS[q]["kinds"]), next_band) if formations_on and not main.tutorial else []
	var out := []
	for i in kinds.size():
		var b: int = ids[i] if not ids.is_empty() else -1
		out.append([kinds[i], level, b])
		if b >= 0:
			main.band_due[b] = int(main.band_due.get(b, 0)) + 1
			next_band = maxi(next_band, b + 1)
	return out


## The warbands forming up and marching (each charges, and is done, once it meets you).
func _bands_step(delta: float) -> void:
	for id in main.bands.keys():
		var b = main.bands[id]
		b.update(delta)
		if b.done():
			main.bands.erase(id)


## Where a new warband comes on: a few spots tried (along the map's lanes, or anywhere
## along the top), the one furthest from the bands still forming up.
func _band_entry(r: float) -> Vector2:
	var best := Vector2.INF
	var best_d := -1.0
	for k in 4:
		var p := main.paths.lane_spawn(r + 4.0)
		if p == Vector2.INF:
			p = Vector2(randf_range(80.0, main.FIELD_W - 80.0), -r)
		var d := INF
		for id in main.bands:
			if main.bands[id].state == "muster":
				d = minf(d, absf(main.bands[id].entry.x - p.x))
		if d > best_d:
			best_d = d
			best = p
	return best


func _spawn_enemy(kind: String, level: int, at = null, band_id := -1) -> void:
	if FOE_HINTS.has(kind) and not main._foes_seen.has(kind) and not main.tutorial:
		main._foes_seen[kind] = true
		main.hud.show_foe(kind, FOE_HINTS[kind][0], FOE_HINTS[kind][1])
	var d: Dictionary = Data.ENEMIES[kind]
	var r: float = d["radius"]
	if at == null and not d.get("boss", false) and not d.get("flying", false):
		var sp: Vector2 = main.rules.spawn_point(r)   # (a battle's own sally parties, from the sides)
		if sp != Vector2.INF:
			at = sp
	var band = null
	if band_id >= 0:
		main.band_due[band_id] = int(main.band_due.get(band_id, 1)) - 1
		if at == null and not main.tutorial:
			band = main.bands.get(band_id)
			if band == null and main.band_due[band_id] >= 0:
				band = Warband.new(main, band_id, main.band_due[band_id] + 1, _band_entry(r))
				main.bands[band_id] = band
			if band != null:
				at = band.spawn_spot(r)
		elif main.bands.has(band_id):
			main.bands[band_id].skip()
		if main.band_due[band_id] <= 0:
			main.band_due.erase(band_id)
	if at == null:
		var lane := main.paths.lane_spawn(r + 4.0)
		if lane != Vector2.INF and not d.get("boss", false):
			at = lane   # a battlefield's own ways in
		else:
			at = Vector2(main.FIELD_W / 2.0 if d.get("boss", false) else randf_range(r + 10, main.FIELD_W - r - 10), -r)
	elif not d.get("flying", false) and (at as Vector2).y > 0.0 and main.paths.has_terrain() and main.paths.blocked(at, r):
		at = main.paths.open_spot(at)   # (a set spot that's in rock, a cliff, a wall: the nearest open ground to it)
	var e := Enemy.new()
	e.setup(kind, d, main, at,
			Data.level_growth(level, Data.HP_GROWTH, Data.LATE_HP_GROWTH),
			Data.level_growth(level, Data.DAMAGE_GROWTH, Data.LATE_DAMAGE_GROWTH),
			1.0 + Data.BOUNTY_GROWTH * (level - 1))
	e.level = level
	e.died.connect(_on_enemy_died)
	e.reached_castle.connect(_on_enemy_at_castle)
	e.goal = main.rules.enemy_goal(e)   # an objective the rules send it for (null: the castle, as ever)
	main.enemy_layer.add_child(e)
	if band != null:
		if e.goal == null:
			band.join(e)
		else:
			band.skip()   # (sent after something of its own)
	if e.boss:
		main.hud.show_message("%s approaches!" % d.get("name", kind.capitalize()))


## An enemy called in mid-fight (by the Ogre King).
func spawn_minion(kind: String, level: int, at: Vector2) -> void:
	_spawn_enemy(kind, level, at.clamp(Vector2(20, -20), Vector2(main.FIELD_W - 20, Main.CASTLE_Y - 40)))


## The Ogre King's war horn: a fresh wave marches in from the top of the field.
func reinforce(kinds: Array, level: int) -> void:
	main.effects.sfx("horn", 0.75)
	main.spawn_queue.append_array(kinds.map(func(k): return [k, level]))
	main.hud.show_message("The war horn sounds! More enemies are coming!")


## The final wave, and every tenth wave past it, ends with the Ogre King once
## everything else is beaten.
func _boss_due() -> bool:
	return not main.missions.scripted() and not boss_spawned and main.wave >= Data.FINAL_WAVE and (main.wave - Data.FINAL_WAVE) % 10 == 0


func _spawn_boss() -> void:
	boss_spawned = true
	# Back every tenth wave at full strength; from UNBOUND_WAVE on, in his full power (the
	# Ogre King, Unbound: the beacon's fire round him, his burning ground and his charge).
	_spawn_enemy("ogre_unbound" if main.wave >= UNBOUND_WAVE else "ogre_king", main.wave)


## Share of bounties and wave bonuses paid: all of it up to the final wave, then a
## little less each endless wave (Data.LATE_GOLD_STEP per wave, down to Data.LATE_GOLD_MIN).
func late_gold_share() -> float:
	return maxf(Data.LATE_GOLD_MIN, 1.0 - Data.LATE_GOLD_STEP * maxi(0, main.wave - Data.FINAL_WAVE))


## Gold from a kill or a cleared wave, trimmed in endless so late waves stay a squeeze.
func late_gold(amount: int) -> int:
	if main.wave <= Data.FINAL_WAVE or amount <= 0:
		return amount
	return maxi(1, roundi(amount * late_gold_share()))


func _on_enemy_died(e) -> void:
	main.battlefield.enemies_changed()
	main.effects.sfx("die", 1.3 if e.radius < 14.0 else (0.7 if e.radius > 20.0 else 1.0))
	main.effects.spawn_corpse(e)
	if e.boss:
		# A boss brought down: a blinding flash, a boom, and word of it.
		main.effects.spawn_flash(e.position, 90.0)
		main.effects.sfx("boom")
		boss_down = "%s is defeated!" % Data.ENEMIES[e.kind].get("name", e.kind.capitalize())
		main.hud.show_message(boss_down)
	elif e.kind == "warlord" or e.kind == "wyvern":
		main.effects.spawn_burst(e.position, 50.0, Color(1.0, 0.85, 0.35))   # an elite down
		main.effects.sfx("crumble")
	var bounty := late_gold(e.bounty)
	main.gold += bounty
	main.effects.spawn_text(e.position, "+%d" % bounty, Color(1, 0.85, 0.2))
	# Necromancy: what dies rotting gets back up on your side.
	if e.decay_timer > 0.0 and is_instance_id_valid(e.decay_source):
		var mage = instance_from_id(e.decay_source)
		if is_instance_valid(mage) and not mage.is_queued_for_deletion() and mage.is_active():
			mage.raise_from_corpse(e.position)


func _on_enemy_at_castle(_e) -> void:
	if not main.gates_warned and not main.game_over:
		main.gates_warned = true
		main.hud.show_message("The enemy is at the gates!")


## The castle at the bottom of the field, or (rules without one) the work camp in its place.
func _show_castle(on: bool) -> void:
	main.castle.visible = on
	main.castle.top_part.visible = on
	if on and main.camp != null:
		main.camp.queue_free()
		main.camp = null
	elif not on and main.camp == null and main.rules.show_camp():
		main.camp = Camp.new()
		main.camp.main = main
		main.add_child(main.camp)
		main.move_child(main.camp, main.castle.get_index())


## Where an Engineer sets out from: the castle gate, or the battle's own camp.
func engineer_gate() -> Vector2:
	var g: Vector2 = main.rules.entry_point(Vector2.ZERO)
	return g if g != Vector2.INF else Vector2(main.FIELD_W / 2.0, Main.CASTLE_Y + 6.0)


## Puts a mission objective on the field (under the troops, over the ground).
func add_objective(o: Node2D) -> void:
	if main.objective_layer == null:
		main.objective_layer = Node2D.new()
		main.add_child(main.objective_layer)
		main.move_child(main.objective_layer, main.wall_layer.get_index())
		main.roof_layer = Node2D.new()
		main.add_child(main.roof_layer)
		main.move_child(main.roof_layer, main.powers.get_index())
	main.objective_layer.add_child(o)
	o.make_roof(main.roof_layer)


## Enemies hitting the castle. In freeplay it can't fall.
func damage_castle(amount: float) -> void:
	if main.game_over or amount <= 0.0 or not main.rules.has_castle():
		return
	amount *= 1.0 - main.powers.armor()
	main.castle_hp -= amount
	main.rules.spoil("The castle was hit")   # (repairing it later doesn't undo this)
	main.castle.struck(amount)
	main.effects.sfx("castle")
	if amount >= 15.0:
		main.effects.spawn_text(Vector2(randf_range(80, main.FIELD_W - 80), Main.CASTLE_Y - 10), "-%d" % roundi(amount), Color(1, 0.3, 0.3))
	if main.freeplay or main.tutorial:
		main.castle_hp = maxf(main.castle_hp, 1.0)   # can't fall here
	elif main.castle_hp <= 0.0:
		main.castle_hp = 0.0
		main.modes._finish(false)
	else:
		_warn_castle()


func _warn_castle() -> void:
	while main.castle_warned > 0 and main.castle_hp > main.castle_max * (CASTLE_ALARMS[main.castle_warned - 1][0] + 0.1):
		main.castle_warned -= 1   # (mended well clear of it: it can ring again)
	if main.castle_warned >= CASTLE_ALARMS.size() or main.castle_hp > main.castle_max * CASTLE_ALARMS[main.castle_warned][0]:
		return
	while main.castle_warned < CASTLE_ALARMS.size() and main.castle_hp <= main.castle_max * CASTLE_ALARMS[main.castle_warned][0]:
		main.castle_warned += 1
	main.effects.sfx("alarm")
	var mend := " Repair it between waves [B]." if main.missions.allowed("repair") else ""
	main.hud.show_message(CASTLE_ALARMS[main.castle_warned - 1][1] + mend)


## Seconds between waves under auto-play. A forced pace: what's left of the window (at
## least MIN_BREAK).
func auto_delay() -> float:
	return maxf(MIN_BREAK, pace_window() - main.wave_clock) if main.forced_auto else Main.AUTO_DELAY


## A forced pace's window between waves: from the last of one wave arriving to the next
## wave ("pace": {"window"}), time to finish it off, let the troops recover and reset.
func pace_window() -> float:
	return float(main.mission.get("pace", {}).get("window", PACE_WINDOWS.get(main.mission.get("type", ""), PACE_WINDOW)))


## Seconds until the next wave under a forced pace (or auto-play), -1 if it isn't counting.
func next_wave_in() -> float:
	if main.forced_auto and main.wave_active and main.spawn_queue.is_empty():
		return maxf(0.0, pace_window() - main.wave_clock)
	if main.auto_play and not main.wave_active:
		return maxf(0.0, main.auto_timer)
	return -1.0


## A breather between waves: the troops catch their breath and get some health back.
func _rest(delta: float) -> void:
	for w in main.battlefield.get_warriors():
		if w.is_active() and not w.is_emplacement() and w.hp < w.max_hp:
			w.hp = minf(w.max_hp, w.hp + w.max_hp * REST_HEAL * delta)


func _end_wave() -> void:
	main.auto_timer = auto_delay()
	main.wave_active = false
	main.effects.sfx("fanfare")
	for w in main.battlefield.get_warriors():
		# The wave's held: they cheer, each starting at its own moment (from its id, not
		# randf: a cheer mustn't change the game's random rolls).
		w.cheer(Warrior.CHEER_HOP * 3.0, float(w.get_instance_id() % 7) * 0.05)
	var bonus := late_gold(20 + main.wave * 5)
	main.gold += bonus
	# Gold Mines pay their end-of-wave bonus on top, and every Treasury pays interest
	# (each on the gold you had before any interest came in).
	var banked := main.gold
	for w in main.battlefield.get_warriors():
		var interest := 0
		if w.is_active() and not w.interest.is_empty():
			interest = mini(int(banked * w.interest[0]), int(w.interest[1]))
		main.gold += w.wave_payout(interest)
	if main.rules.wave_cleared(main.wave):
		main.modes._finish(true)   # the mission's last wave: it's won
		return
	_survived_wave()
	if not main.missions.scripted() and main.wave == Data.FINAL_WAVE and not main.endless:
		# Classic goes on: from here the enemy toughens faster and pays less.
		main.endless = true
		main.hud.show_message("Wave %d held! From here they come harder, and pay less. How far can you go?" % main.wave)
	elif not (survival() and beat_best and main.wave == main.best_before + 1):
		main.hud.show_message("%sWave %d cleared! +%d gold" % [boss_down + " " if boss_down != "" else "", main.wave, bonus])
	boss_down = ""


## The army is gone (every troop dead, nothing on the wall either), and there's no way to
## raise another: no Gold Mine to earn with, and not enough gold to hire anything, even
## selling what can't fight. Lasting a moment (a wave's bonus about to come in still
## counts), that's the battle lost. Not in Freeplay or the Tutorial.
func _check_rout(delta: float) -> void:
	if main.freeplay or main.tutorial or main.deploying:
		rout_time = 0.0
		return
	if not _army_gone():
		rout_time = 0.0
		return
	rout_time += delta
	if rout_time >= ROUT_GRACE:
		main.routed = true
		main.hud.show_message("Your army is gone, and there's no gold to raise another")
		main.modes._finish(false)


func _army_gone() -> bool:
	var funds := main.gold
	for w in main.battlefield.get_warriors():
		if w.kind == "mine":
			return false   # it'll earn more
		if not NON_FIGHTERS.has(w.kind):
			return false   # still someone fighting (or downed, and maybe revived)
		funds += w.sell_value()
	if main.rules.has_castle() and not main.powers.guards.is_empty():
		return false   # the wall's own guards fight on
	for b in main.battlefield.get_barricades():
		funds += int(b.spent * 0.6)
	for k in Data.WARRIORS:
		if k != "barricade" and main.missions.allowed(k) and funds >= main.hiring.hire_cost(k):
			return false
	return true


## This battlefield's own battle music (getting it composed now, ready for the first wave).
func set_battle_music(map: Dictionary) -> void:
	main.battle_music = Audio.battle_for(map)
	if Audio.BATTLES.has(main.mission.get("battle", "")):
		main.battle_music = "battle_" + main.mission["battle"]   # (a mission can have its own, on a shared field)
	main.audio.prepare(main.stage_music)   # (a map's own peaceful music first, if it's made on demand: it's needed first)
	main.audio.prepare(main.battle_music)


## A survival battle (Classic, a Battle Modes scenario): the run goes on until it's
## lost, and the score is the waves survived.
func survival() -> bool:
	if main.freeplay or main.tutorial or main.campaign:
		return false
	return not main.missions.scripted() or main.mission.get("endless", false)


## Waves survived so far this run (a forced pace sends the next before the last is beaten:
## one counts once the next has come, or once it's been cleared).
func waves_survived() -> int:
	return main.wave if not main.wave_active else main.wave - 1


## Wave `wave` is behind us: a word when that beats the best.
func _survived_wave() -> void:
	if survival() and not beat_best and main.best_before > 0 and waves_survived() > main.best_before:
		beat_best = true
		main.hud.show_message("New best: %d waves!" % waves_survived())
		main.effects.sfx("fanfare", 1.2)


## This battle's best before (Classic: per difficulty and battlefield; a scenario: per difficulty).
func _best_record() -> int:
	if main.records_path == "":
		return 0
	var cfg := ConfigFile.new()
	cfg.load(main.records_path)
	if main.battle_id != "":
		return cfg.get_value("survive", "%s@%s" % [main.battle_id, main.difficulty], 0)
	return cfg.get_value("best", main.difficulty + ("@" + main.map_id if main.map_id != "" else ""), 0)


## The horde's squads that march in Classic's wave `n` (see data.gd SQUADS), at most three.
static func squads_for(n: int) -> Array:
	var out := []
	for sq in Data.SQUADS:
		var d: Dictionary = Data.SQUADS[sq]
		if n >= int(d["from"]) and (n - int(d["from"])) % int(d["every"]) == 0:
			out.append(sq)
	return out.slice(0, 3)


## How many make up Classic's wave `n` (before its Warlords and Wyverns): two more each
## wave to the final wave, then one more each wave, up to Data.MAX_WAVE_SIZE.
static func wave_size(n: int) -> int:
	var to_final := 6 + mini(n, Data.FINAL_WAVE) * 2
	return mini(to_final + maxi(0, n - Data.FINAL_WAVE) * Data.LATE_COUNT_STEP, Data.MAX_WAVE_SIZE)
