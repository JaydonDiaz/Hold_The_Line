extends Node2D
## A hired warrior. Goes after an enemy on the field (chosen by its target
## priority), attacks it, and walks back to its post when the field is clear.
## Upgrades come from three paths (see data.gd): two can be used, only one past tier 2.

const Data = preload("res://scripts/data.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Sprites = preload("res://scripts/sprites.gd")
const Zone = preload("res://scripts/zone.gd")
const MAX_TIER := 4
const SECOND_PATH_CAP := 2
const PATH_COLORS := [Color(1.0, 0.6, 0.3), Color(0.45, 0.8, 1.0), Color(0.7, 1.0, 0.45)]
const RADIUS := 18.0
const SCALE := 3.0      # sprite pixels to screen pixels
const REGEN := 0.06     # fraction of max HP healed per second while idle
const CHAIN_JUMP := 100.0
const COMBO_GAP := 0.12   # seconds between hits in a combo, and between blasts in a volley
const KI_COLOR := Color(1.0, 0.88, 0.35)
const OUTLINE_COLOR := Color(0.1, 0.07, 0.1)
const BEAM_CHARGE := 0.5   # seconds spent gathering ki before the beam fires
const MAGE_ORB_COLORS := [Color(0.5, 0.75, 1.0), Color(1.0, 0.85, 0.5), Color(1.0, 0.5, 0.15)]
const FLASK_COLORS := [Color(0.65, 0.35, 0.95), Color(0.88, 0.95, 0.2), Color(1.0, 0.45, 0.15)]
const IDLE_AFTER := 0.8   # seconds with nothing to do before a troop starts its idle animation
const WINDUP := 0.18      # melee troops rear back over the last moment before a blow
const ARCHER_LOOP := 5.6  # Archer idle: draw an arrow, twirl it, flip it, twirl, put it back, rest
const PRIORITIES := ["closest", "first", "strongest", "weakest"]
const PRIORITY_NAMES := {
	"closest": "Closest", "first": "First", "strongest": "Strongest", "weakest": "Weakest",
}

var kind := ""
var data: Dictionary
var main
var post := Vector2.ZERO
var post_u := 0.0              # post's place across the field (0 = left edge, 1 = right), kept through window resizes
var fitted_post := Vector2.INF # post as of the last resize; if it's changed since, post_u is taken afresh
var tiers := [0, 0, 0]
var spent := 0
var priority := "closest"

# Current stats, rebuilt from data + tiers by _apply_upgrades().
var max_hp := 1.0
var hp := 1.0
var move_speed := 100.0
var armor := 0.0   # fraction of incoming damage blocked
var damage := 0.0
var attack_range := 0.0
var cooldown := 1.0
var splash := 0.0
var slow := 0.0
var slow_time := 0.0
var slow_radius := 0.0
var freeze_chance := 0.0
var freeze_time := 0.0
var crit_chance := 0.0
var crit_mult := 1.0
var chain := {}   # damage, jumps, cooldown (mage Storm path)
var lance := {}   # damage, cooldown (mage Arcane Lance path)
var breath := {}  # damage, interval, burn_dps, burn_time (mage Fire path)
# Martial Artist.
var combo_hits := 0          # hits per melee combo
var knockback_chance := 0.0
var knockback_force := 0.0
var blast := {}              # damage, count, range, cooldown (Ki path)
var blast_count := 0         # blasts per volley (Combat tiers add to this when Ki is taken)
var beam := {}               # damage, cooldown, width
var evade := 0.0
var teleport := {}           # cooldown, min_dist
var stun := {}               # radius, duration, cooldown
var surge := {}              # cooldown, duration, damage, rate
# Swordsman.
var cleave := {}             # arc (degrees), reach, damage: Damage tier 4 sweeps
var dual := 0.0              # off-hand strike damage (fraction), Speed tier 3+
var block := 0.0             # chance to block a hit outright, Health tier 3+
# Emplacements.
var multishot := 1           # projectiles per attack
var shell_stun := 0.0        # seconds a shell's blast stuns everything it catches
# Healer.
var heal_area := []          # [radius, fraction] splash healing around the target
var regen_grant := []        # [fraction of max HP per second, seconds] given with each heal
var revive := {}             # rez_speed, aura, full
var rez_target = null        # downed ally this healer is reviving
var rez_progress := 0.0      # seconds of channeling done on rez_target
# Support emplacements.
var aura := {}               # statue buffs given: damage, rate, defense, speed
var interest := []           # gold mine: [fraction, cap] paid at the end of each wave
var wave_bonus := 0          # gold mine: flat gold at the end of each wave
var hauls := 0               # gold mine: hauls allowed per wave
var hauls_done := 0          # gold mine: hauls dug this wave
# Bard.
var song_radius := 0.0       # reach of its songs (Inspire buffs and Discord debuffs)
var discord := {}            # vuln, weaken, slow given to enemies in earshot
var overgrowth := {}         # radius, slow, duration, cooldown
var vines := {}              # radius, duration, cooldown
var tornado := {}            # radius, push, cooldown
var confuse := {}            # radius, duration, cooldown
var spell_timers := {"overgrowth": 1.0, "vines": 2.0, "tornado": 3.0, "confuse": 4.0}
var song_tick := 0.0
# The body as last drawn (texture, local transform, rect, tint), so the castle can draw
# a silhouette of a warrior standing behind it. xray_tex is null when nothing was drawn.
var xray_tex: Texture2D = null
var xray_xform := Transform2D.IDENTITY
var xray_rect := Rect2()
# Alchemist.
var poison := {}             # dps, duration, stacks added by each flask
var cloud := {}              # radius, duration of the toxic cloud a flask leaves
var corrode := {}            # amount, duration: splashed enemies take more damage
var melt := 0.0              # share of the direct target's max HP each flask burns away
var burst := 0.0             # enemies a flask kills explode for this multiple of its damage
# Statue buffs this unit is standing in (the strongest nearby statue for each).
var buff := {"damage": 0.0, "rate": 0.0, "defense": 0.0, "speed": 0.0}
var buff_timer := 0.0
# Regeneration received from a Healer.
var regen_rate := 0.0
var regen_left := 0.0

var cd_timer := 0.0
var retarget_timer := 0.0
var ordered := false   # following a move order; ignores enemies until it arrives
var chain_timer := 0.0
var lance_timer := 0.0
var breath_timer := 0.0
var combo_left := 0
var combo_timer := 0.0
var blast_timer := 0.0
var volley_left := 0      # blasts still to throw in the current volley
var volley_timer := 0.0
var volley_hand := 1.0    # alternates which side each blast leaves from
var volley_target = null  # a volley stays on its first target while it lives
var beam_timer := 0.0
var beam_charge := 0.0    # > 0 while charging the beam
var beam_target = null
var teleport_timer := 0.0
var stun_timer := 0.0
var surge_timer := 0.0
var surge_left := 0.0   # seconds of Power Surge remaining
var swing := 0.0
var offhand_timer := 0.0   # > 0 while the off-hand blade's follow-up strike is coming
var block_flash := 0.0
var pose := ""          # attack pose held for pose_left seconds (Martial Artist)
var pose_left := 0.0
var hurt := 0.0
var down_timer := 0.0
var walk := 0.0
var moving := false
var facing := Vector2.UP
var flip := 1.0
var target = null
var anim_t := 0.0         # running clock for idle loops
var idle_t := 0.0         # how long it has had nothing to do
var note_timer := 0.0     # Bard: idle tunes
var route := PackedVector2Array()   # waypoints around walls to route_goal
var route_goal := Vector2.INF
var route_timer := 0.0
var dazed := 0.0          # stunned by the Ogre King's stomp: can't move or act
var shove_velocity := Vector2.ZERO
var shove_left := 0.0
var lost_time := 0.0      # seconds spent trying to get back to its post; teleports there after STUCK_LIMIT
const STUCK_LIMIT := 10.0
const MINE_FALLOFF := 0.7   # each Gold Mine after the first digs this much of the one before


func setup(k: String, d: Dictionary, m, post_pos: Vector2) -> void:
	kind = k
	data = d
	main = m
	post = post_pos
	spent = d["cost"]
	_apply_upgrades()
	hp = max_hp


func _apply_upgrades() -> void:
	max_hp = data["hp"]
	armor = 0.0
	move_speed = data["speed"]
	damage = data["damage"]
	attack_range = data["range"]
	cooldown = data["cooldown"]
	splash = data.get("splash", 0.0)
	slow = data.get("slow", 0.0)
	slow_time = data.get("slow_time", 0.0)
	slow_radius = 0.0
	freeze_chance = 0.0
	freeze_time = 0.0
	crit_chance = 0.0
	crit_mult = 1.0
	chain = {}
	lance = {}
	breath = {}
	combo_hits = data.get("combo", 0)
	var extra_hits := 0
	knockback_chance = 0.0
	knockback_force = 0.0
	blast = {}
	beam = {}
	evade = 0.0
	teleport = {}
	stun = {}
	surge = {}
	cleave = {}
	dual = 0.0
	block = 0.0
	multishot = 1
	shell_stun = 0.0
	heal_area = []
	regen_grant = []
	revive = {}
	aura = {}
	for key in ["damage", "rate", "defense", "speed"]:
		if data.has("aura_" + key):
			aura[key] = data["aura_" + key]
	interest = []
	wave_bonus = 0
	hauls = data.get("hauls", 0)
	song_radius = data.get("song_radius", 0.0)
	discord = {}
	overgrowth = {}
	vines = {}
	tornado = {}
	confuse = {}
	poison = {}
	cloud = {}
	corrode = {}
	melt = 0.0
	burst = 0.0
	for p in 3:
		var path_tiers: Array = data["paths"][p]["tiers"]
		for t in tiers[p]:
			var fx: Dictionary = path_tiers[t]["effect"]
			damage *= fx.get("damage", 1.0)
			cooldown *= fx.get("rate", 1.0)
			move_speed *= fx.get("speed", 1.0)
			attack_range += fx.get("range", 0.0)
			max_hp *= fx.get("hp", 1.0)
			armor = 1.0 - (1.0 - armor) * (1.0 - fx.get("armor", 0.0))
			slow = minf(slow + fx.get("slow", 0.0), 0.9)
			slow_time += fx.get("slow_time", 0.0)
			if fx.has("slow_radius"):
				slow_radius = fx["slow_radius"]
			if fx.has("freeze"):
				freeze_chance = fx["freeze"][0]
				freeze_time = fx["freeze"][1]
			if fx.has("crit"):
				crit_chance = fx["crit"][0]
				crit_mult = fx["crit"][1]
			if fx.has("chain"):
				chain = fx["chain"]
			if fx.has("lance"):
				lance = fx["lance"]
			if fx.has("breath"):
				breath = fx["breath"]
			extra_hits += fx.get("combo", 0)
			if fx.has("knockback"):
				knockback_chance = fx["knockback"][0]
				knockback_force = fx["knockback"][1]
			for key in ["blast", "beam", "teleport", "stun", "surge"]:
				if fx.has(key):
					set(key, fx[key])
			if fx.has("evade"):
				evade = fx["evade"]
			if fx.has("cleave"):
				cleave = fx["cleave"]
			dual = fx.get("dual", dual)
			block = fx.get("block", block)
			splash += fx.get("splash", 0.0)
			multishot = fx.get("multishot", multishot)
			shell_stun = fx.get("shell_stun", shell_stun)
			heal_area = fx.get("heal_area", heal_area)
			regen_grant = fx.get("regen", regen_grant)
			revive = fx.get("revive", revive)
			for key in ["damage", "rate", "defense", "speed"]:
				if fx.has("aura_" + key):
					aura[key] = fx["aura_" + key]
			interest = fx.get("interest", interest)
			song_radius += fx.get("song_radius", 0.0)
			for key in ["discord", "overgrowth", "vines", "tornado", "confuse", "poison", "cloud", "corrode"]:
				if fx.has(key):
					set(key, fx[key])
			melt = fx.get("melt", melt)
			burst = fx.get("burst", burst)
			wave_bonus = fx.get("wave_bonus", wave_bonus)
			hauls += fx.get("hauls", 0)
	# Extra combo hits turn into extra blasts per volley once ki blasts are learned.
	blast_count = 0
	if not blast.is_empty():
		blast_count = int(blast["count"]) + extra_hits
	else:
		combo_hits += extra_hits
	queue_redraw()


## Index of the path at tier 3 or higher (only one can be), or -1.
func _look_path() -> int:
	for p in 3:
		if tiers[p] >= 3:
			return p
	return -1


## Sprite to draw: tier 3 in a path swaps in that path's look.
func sprite_name() -> String:
	var p := _look_path()
	var look := "%s_p%d" % [kind, p]
	return look if p >= 0 and Sprites.SPRITES.has(look) else kind


func is_melee() -> bool:
	return data["attack"] == "melee" or data["attack"] == "combo"


func is_healer() -> bool:
	return data["attack"] == "heal"


## Emplacements stay where they were built and only shoot what comes into range.
func is_emplacement() -> bool:
	return data.get("emplacement", false)


## Support emplacements (gold mine, medic bay, statue) never attack anything.
func is_support() -> bool:
	return data["attack"] in ["mine", "pulse", "aura"]


## Emplacements fire from high up and lobbed shells and flasks arc over, so they
## clear walls; every other attack needs a clear line to its target.
func shoots_over_walls() -> bool:
	return is_emplacement() or data["attack"] in ["shell", "flask"]


func _sees(e) -> bool:
	return shoots_over_walls() or not main.paths.wall_between(position, e.position)


## Whether the Target button means anything for this unit.
func uses_targeting() -> bool:
	return not is_healer() and not is_support()


func _power() -> float:
	return (surge["damage"] if surge_left > 0.0 else 1.0) * (1.0 + buff["damage"])


func _rate() -> float:
	return (surge["rate"] if surge_left > 0.0 else 1.0) * (1.0 + buff["rate"])


## How far this unit's buffs reach: a statue's radius, or a bard's song.
func aura_reach() -> float:
	return (attack_range if is_support() else song_radius) + RADIUS


## Whether this unit's support reaches w. War Statues and Medic Bays look after the
## units posted in their radius, wherever those units have run off to fight; a
## Bard's songs reach whoever is in earshot right now.
func covers(w) -> bool:
	if is_support():
		return position.distance_to(w.post) <= attack_range + RADIUS
	return position.distance_to(w.position) <= aura_reach()


## Picks up buffs from the War Statues and Bards covering it. Two of the same kind
## don't stack (only the strongest statue and the strongest bard count), but a
## statue and a bard do.
func _update_buffs() -> void:
	for key in buff:
		buff[key] = 0.0
	var best := {}   # source kind -> strongest value of each buff from that kind
	for w in main.get_warriors():
		if w == self or w.aura.is_empty() or not w.is_active():
			continue
		if w.covers(self):
			var from: Dictionary = best.get_or_add(w.kind, {})
			for key in w.aura:
				from[key] = maxf(from.get(key, 0.0), w.aura[key])
	for from in best.values():
		for key in from:
			buff[key] += from[key]


func is_active() -> bool:
	return down_timer <= 0.0 and not is_queued_for_deletion()


func set_post(p: Vector2) -> void:
	post = p
	target = null


## A player move order: walk to the new post without stopping to fight.
func order_to(p: Vector2) -> void:
	set_post(p)
	ordered = true


## "ok", "max", "locked" (two other paths already started) or
## "capped" (another path is past tier 2, so this one stops at 2).
func path_state(p: int) -> String:
	if tiers[p] >= MAX_TIER:
		return "max"
	var started := 0
	var other_high := false
	for i in 3:
		if i == p:
			continue
		if tiers[i] > 0:
			started += 1
		if tiers[i] > SECOND_PATH_CAP:
			other_high = true
	if tiers[p] == 0 and started >= 2:
		return "locked"
	if tiers[p] >= SECOND_PATH_CAP and other_high:
		return "capped"
	return "ok"


func next_tier(p: int) -> Dictionary:
	return data["paths"][p]["tiers"][tiers[p]]


func upgrade_cost(p: int) -> int:
	return tier_cost(p, tiers[p])


## Price of tier t (0-based) of path p.
func tier_cost(p: int, t: int) -> int:
	return main.price(data["paths"][p]["tiers"][t]["cost"])


func upgrade(p: int) -> void:
	spent += upgrade_cost(p)
	var ratio := hp / max_hp
	tiers[p] += 1
	_apply_upgrades()
	hp = max_hp * ratio


func sell_value() -> int:
	return int(spent * 0.6)


func stats_text() -> String:
	var s := "HP %d/%d   Damage %.0f   Every %.2fs" % [ceili(hp), ceili(max_hp), damage, cooldown]
	if is_support():
		match data["attack"]:
			"mine":
				var share := mine_share()
				s = "HP %d/%d   %dg every %.1fs during waves   Hauls %d/%d this wave" % [ceili(hp), ceili(max_hp), maxi(1, roundi(damage * share)), cooldown, hauls_done, hauls]
				if wave_bonus > 0:
					s += "   +%dg per wave" % roundi(wave_bonus * share)
				if share < 1.0:
					s += "\nShares the vein with earlier mines: digs %d%%" % roundi(share * 100)
				if not interest.is_empty():
					s += "   Interest %d%% (max %d, only your best Treasury pays)" % [roundi(interest[0] * 100), interest[1]]
			"pulse":
				s = "HP %d/%d   Heals %.0f to all in radius every %.2fs   Radius %s" % [ceili(hp), ceili(max_hp), damage, cooldown, Data.ft(attack_range)]
				if not regen_grant.is_empty():
					s += "   Regen %.1f%%/s for %.0fs" % [regen_grant[0] * 100, regen_grant[1]]
				if not revive.is_empty():
					s += "   Revives in %.1fs" % _revive_time()
			"aura":
				s = "HP %d/%d   Radius %s  " % [ceili(hp), ceili(max_hp), Data.ft(attack_range)]
				var names := {"damage": " +%d%% damage", "rate": " +%d%% attack speed", "defense": " -%d%% damage taken", "speed": " +%d%% move speed"}
				for key in aura:
					s += names[key] % roundi(aura[key] * 100)
		if not is_active():
			s += "\nWrecked" + (" - destroyed in %ds unless revived" % ceili(down_timer) if main.permadeath else ", back in %ds" % ceili(down_timer))
		return s
	if kind == "bard":
		s = "HP %d/%d   Damage %.0f   Every %.2fs   Range %s   Speed %s/s   Song reach %s" % [ceili(hp), ceili(max_hp), damage, cooldown, Data.ft(attack_range), Data.ft(move_speed), Data.ft(song_radius)]
		if not aura.is_empty():
			s += "   Allies:"
			if aura.has("rate"):
				s += " +%d%% atk speed" % roundi(aura["rate"] * 100)
			if aura.has("damage"):
				s += " +%d%% dmg" % roundi(aura["damage"] * 100)
			if aura.has("speed"):
				s += " +%d%% move" % roundi(aura["speed"] * 100)
		if not discord.is_empty():
			s += "   Enemies: +%d%% dmg taken" % roundi(discord["vuln"] * 100)
			if discord["weaken"] > 0.0:
				s += ", -%d%% dmg dealt" % roundi(discord["weaken"] * 100)
			if discord["slow"] > 0.0:
				s += ", -%d%% speed" % roundi(discord["slow"] * 100)
		var spells := []
		var spell_names := {"overgrowth": "Overgrowth", "vines": "Vine Snare", "tornado": "Tornado", "confuse": "Confusion"}
		for spell in spell_names:
			if not (get(spell) as Dictionary).is_empty():
				spells.append(spell_names[spell])
		if not spells.is_empty():
			s += "   Spells: " + ", ".join(spells)
		if not is_active():
			s += "\nDown!"
		return s
	if kind == "alchemist":
		s += "   Range %s   Speed %s/s   Splash %s" % [Data.ft(attack_range), Data.ft(move_speed), Data.ft(splash)]
		if multishot > 1:
			s += "   %d flasks" % multishot
		if not poison.is_empty():
			s += "   Poison %.0f/s x%d" % [poison["dps"], poison["stacks"]]
		if not cloud.is_empty():
			s += "   Cloud %s for %.0fs" % [Data.ft(cloud["radius"]), cloud["duration"]]
		if not corrode.is_empty():
			s += "   Acid +%d%% dmg taken" % roundi(corrode["amount"] * 100)
		if melt > 0.0:
			s += "   Melts %d%% max HP" % roundi(melt * 100)
		if burst > 0.0:
			s += "   Kills explode %.0fx" % burst
		if not is_active():
			s += "\nDown!"
		return s
	if is_healer():
		s = "HP %d/%d   Heals %.0f   Every %.2fs   Range %s   Revive %.1fs" % [
				ceili(hp), ceili(max_hp), damage, cooldown, Data.ft(attack_range), _revive_time()]
		if not heal_area.is_empty():
			s += "   Area %s at %d%%" % [Data.ft(heal_area[0]), roundi(heal_area[1] * 100)]
		if not regen_grant.is_empty():
			s += "   Regen %.1f%%/s for %.0fs" % [regen_grant[0] * 100, regen_grant[1]]
		if not revive.is_empty():
			s += "   Downed allies in range recover %.1fx faster" % revive["aura"]
	elif not is_melee():
		s += "   Range %s" % Data.ft(attack_range)
	if move_speed > 0.0:
		s += "   Speed %s/s" % Data.ft(move_speed)
	if combo_hits > 0:
		s += "   Combo %d hits" % combo_hits
	if not blast.is_empty():
		s += "   Ki %.0f x%d / %.1fs, range %s" % [blast["damage"], blast_count, blast["cooldown"], Data.ft(blast["range"])]
	if not beam.is_empty():
		s += "   Beam %.0f / %.0fs" % [beam["damage"], beam["cooldown"]]
	if knockback_chance > 0.0:
		s += "   Knockback %d%%" % roundi(knockback_chance * 100)
	if evade > 0.0:
		s += "   Dodge %d%%" % roundi(evade * 100)
	if block > 0.0:
		s += "   Block %d%%" % roundi(block * 100)
	if dual > 0.0:
		s += "   Off-hand %d%%" % roundi(dual * 100)
	if not cleave.is_empty():
		s += "   Sweep %d%%" % roundi(cleave["damage"] * 100)
	if not stun.is_empty():
		s += "   Flash stun %.0fs / %.0fs" % [stun["duration"], stun["cooldown"]]
	if surge_left > 0.0:
		s += "   SURGING"

	if armor > 0.0:
		s += "   Armor %d%%" % roundi(armor * 100)
	if slow > 0.0:
		s += "   Slow %d%% for %.1fs" % [int(slow * 100), slow_time]
	if slow_radius > 0.0:
		s += "   Area %s" % Data.ft(slow_radius)
	if crit_chance > 0.0:
		s += "   Crit %d%% x%.0f" % [roundi(crit_chance * 100), crit_mult]
	if freeze_chance > 0.0:
		s += "   Freeze %d%% %.1fs" % [int(freeze_chance * 100), freeze_time]
	if splash > 0.0:
		s += "   Blast radius %s" % Data.ft(splash)
	if multishot > 1:
		s += "   %d shots" % multishot
	if shell_stun > 0.0:
		s += "   Stun %.0fs" % shell_stun
	if not chain.is_empty():
		s += "   Chain %.0f x%d / %.1fs" % [chain["damage"], chain["jumps"], chain["cooldown"]]
	if not lance.is_empty():
		s += "   Lance %.0f / %.1fs" % [lance["damage"], lance["cooldown"]]
	if not breath.is_empty():
		s += "   Breath %.0f / %.2fs, burn %.0f/s" % [breath["damage"], breath["interval"], breath["burn_dps"]]
	if not is_active():
		if main.permadeath:
			s += "\nDown! Dies in %ds unless a Healer revives it" % ceili(down_timer)
		else:
			s += "\nKnocked out, back in %ds" % ceili(down_timer)
	return s


func take_damage(amount: float) -> void:
	if not is_active():
		return
	if evade > 0.0 and randf() < evade:
		main.spawn_text(position + Vector2(0, -40), "Dodge", Color(0.85, 0.95, 1.0))
		return
	if block > 0.0 and randf() < block:
		main.spawn_text(position + Vector2(0, -40), "Block", Color(0.75, 0.82, 1.0))
		block_flash = 0.2
		return
	hp -= amount * (1.0 - armor) * (1.0 - buff["defense"])
	hurt = 0.1
	if hp <= 0.0:
		hp = 0.0
		# Gets back up after the difficulty's down time. Hardcore: dies then, unless a Healer revives it first.
		down_timer = main.down_time
		dazed = 0.0
		shove_left = 0.0
		rez_target = null
		regen_left = 0.0
		target = null
		combo_left = 0
		offhand_timer = 0.0
		volley_left = 0
		beam_charge = 0.0
		surge_left = 0.0
		main.spawn_text(position + Vector2(0, -24), "Wrecked!" if is_emplacement() else "Down!", Color(1, 0.4, 0.35))


func _process(delta: float) -> void:
	hurt = maxf(hurt - delta, 0.0)
	swing = maxf(swing - delta, 0.0)
	pose_left = maxf(pose_left - delta, 0.0)
	block_flash = maxf(block_flash - delta, 0.0)
	queue_redraw()
	_animate(delta)
	if down_timer > 0.0:
		down_timer -= delta * (1.0 if main.permadeath else _recovery_aura())
		if down_timer <= 0.0:
			if main.permadeath:
				main.spawn_text(position + Vector2(0, -24), "Destroyed!" if is_emplacement() else "Fallen!", Color(1, 0.3, 0.3))
				queue_free()
			else:
				hp = max_hp   # gets back up where it fell
		return
	if dazed > 0.0 or shove_left > 0.0:
		# Knocked flying and seeing stars: slides back, then stands dazed.
		dazed = maxf(dazed - delta, 0.0)
		if shove_left > 0.0:
			shove_left -= delta
			position += shove_velocity * delta
		_separate()
		return
	if regen_left > 0.0:
		regen_left -= delta
		hp = minf(max_hp, hp + max_hp * regen_rate * delta)
	cd_timer = maxf(cd_timer - delta, 0.0)
	chain_timer = maxf(chain_timer - delta, 0.0)
	lance_timer = maxf(lance_timer - delta, 0.0)
	breath_timer = maxf(breath_timer - delta, 0.0)
	blast_timer = maxf(blast_timer - delta, 0.0)
	beam_timer = maxf(beam_timer - delta, 0.0)
	teleport_timer = maxf(teleport_timer - delta, 0.0)
	stun_timer = maxf(stun_timer - delta, 0.0)
	surge_timer = maxf(surge_timer - delta, 0.0)
	surge_left = maxf(surge_left - delta, 0.0)
	moving = false
	buff_timer -= delta
	if buff_timer <= 0.0:
		buff_timer = 0.25
		_update_buffs()
	if is_support():
		_support_update(delta)
		return
	if is_healer():
		_healer_update(delta)
		if absf(facing.x) > 0.2:
			flip = signf(facing.x)
		_separate()
		return
	if kind == "bard":
		_bard_update(delta)
	if not chain.is_empty() and chain_timer <= 0.0 and _cast_chain():
		chain_timer = chain["cooldown"]
	if not lance.is_empty() and lance_timer <= 0.0 and _cast_lance():
		lance_timer = lance["cooldown"]
	if not breath.is_empty() and breath_timer <= 0.0 and _breathe():
		breath_timer = breath["interval"]
	# The beam is a separate special: it waits for any volley to finish, charges up,
	# then fires; blasting pauses while it charges.
	if beam_charge > 0.0:
		beam_charge -= delta
		if beam_charge <= 0.0:
			_fire_beam()
			beam_timer = beam["cooldown"]
			blast_timer = maxf(blast_timer, 0.4)
	elif not beam.is_empty() and beam_timer <= 0.0 and volley_left == 0 and _beam_target() != null:
		beam_target = _beam_target()
		beam_charge = BEAM_CHARGE
	elif volley_left > 0:
		_continue_volley(delta)
	elif not blast.is_empty() and blast_timer <= 0.0 and _start_volley():
		blast_timer = blast["cooldown"] / _rate()
	if not stun.is_empty() and stun_timer <= 0.0 and _flash():
		stun_timer = stun["cooldown"]
	if not surge.is_empty() and surge_timer <= 0.0 and _in_combat():
		surge_left = surge["duration"]
		surge_timer = surge["cooldown"]
		main.spawn_text(position + Vector2(0, -50), "Power Surge!", Color(1, 0.35, 0.3))

	# Re-pick a target a few times a second, or right away if the current one is gone.
	retarget_timer -= delta
	if ordered:
		target = null
		if position.distance_to(post) <= RADIUS:
			ordered = false
	elif not _is_valid(target) or retarget_timer <= 0.0 or (is_emplacement() and not _in_range(target)):
		target = _find_target()
		retarget_timer = 0.3
	# Movement: chase the target (melee closes all the way in, ranged stops at range),
	# otherwise head back to the post.
	if is_emplacement():
		# Never moves; just turns to face what it's shooting at.
		if target != null:
			facing = position.direction_to(target.position)
		else:
			hp = minf(max_hp, hp + max_hp * REGEN * delta)
	elif target != null:
		var gap := _gap_to(target)
		facing = position.direction_to(target.position)
		if not teleport.is_empty() and teleport_timer <= 0.0 and _should_blink(target, gap):
			_blink_to(target)
			gap = _gap_to(target)
		if not blast.is_empty():
			# Ki users hold at blast range and fire volleys; they still punch anything that closes in.
			var r: float = blast["range"]
			if not _sees(target):
				_move_toward(target.position, gap, delta)   # a wall's in the way: go round it
			elif gap > r:
				_move_toward(target.position, gap - r + 1.0, delta)
		elif is_melee():
			if gap > 0.0:
				_move_toward(target.position, gap, delta)
		elif not _sees(target):
			_move_toward(target.position, gap, delta)
		elif gap > attack_range:
			_move_toward(target.position, gap - attack_range + 1.0, delta)
	else:
		var d := position.distance_to(post)
		if d > 2.0:
			facing = position.direction_to(post)
			_move_toward(post, d, delta)
			lost_time += delta
			if lost_time >= STUCK_LIMIT:
				_teleport_home()
		else:
			lost_time = 0.0
		if not ordered:
			hp = minf(max_hp, hp + max_hp * REGEN * delta)

	# Attacking happens on the move: hit the target if it's in reach, otherwise anything
	# else in reach (picked by priority), including while following a move order.
	if offhand_timer > 0.0:
		offhand_timer -= delta
		if offhand_timer <= 0.0:
			_offhand_strike()
	if combo_left > 0:
		_continue_combo(delta)
	elif cd_timer <= 0.0:
		var victim = _victim()
		if victim != null:
			cd_timer = cooldown / _rate()
			facing = position.direction_to(victim.position)
			if data["attack"] == "combo":
				combo_left = combo_hits
				combo_timer = 0.0
				_continue_combo(0.0)
			else:
				_attack(victim)
	if absf(facing.x) > 0.2:
		flip = signf(facing.x)
	_separate()


func _victim():
	return target if target != null and _can_strike(target) else _pick(main.get_enemies().filter(_can_strike))


## In reach for this unit's main attack: melee blows can't reach a flyer (a Martial
## Artist's ki can, but its punches can't).
func _can_strike(e) -> bool:
	return _in_range(e) and not (is_melee() and e.flying)


## Whether this unit can hurt flyers at all: not with melee blows (unless it has ki
## blasts) and not with cannon shells.
func hits_air() -> bool:
	return (not is_melee() or not blast.is_empty()) and data["attack"] != "shell"


# Martial Artist: a quick string of punches, re-aiming at whatever is in reach each hit.
func _continue_combo(delta: float) -> void:
	combo_timer -= delta
	if combo_timer > 0.0:
		return
	var v = _victim()
	if v == null:
		combo_left = 0
		return
	combo_left -= 1
	combo_timer = COMBO_GAP
	facing = position.direction_to(v.position)
	swing = 0.1
	_hold_pose("kick" if combo_left == 0 else "punch", COMBO_GAP)
	v.take_damage(damage * _power())
	_hit_spark(v)
	# Only the finishing hit can knock back, so the combo isn't cut short.
	if combo_left == 0 and randf() < knockback_chance:
		v.apply_knockback(facing * knockback_force)


func _in_combat() -> bool:
	var reach: float = maxf(attack_range, blast.get("range", 0.0)) + 40.0
	return target != null and _is_valid(target) and _gap_to(target) <= reach


# Ki path: a volley of homing blasts at enemies outside punching reach.
func _start_volley() -> bool:
	if _blast_target() == null:
		return false
	volley_left = blast_count
	volley_timer = 0.0
	volley_target = _blast_target()
	_continue_volley(0.0)
	return true


func _blast_target():
	# Blasts are for enemies outside punching reach; anything in reach gets punched instead.
	if not main.get_enemies().filter(_can_strike).is_empty():
		return null
	var r: float = blast["range"]
	if target != null and _is_valid(target) and _gap_to(target) <= r and _sees(target):
		return target
	return _pick(main.get_enemies().filter(func(x): return _is_valid(x) and _gap_to(x) <= r and _sees(x)))


# Throws the volley's blasts one at a time, like the punches of a combo.
func _continue_volley(delta: float) -> void:
	volley_timer -= delta
	if volley_timer > 0.0:
		return
	var e = volley_target if _is_valid(volley_target) else _blast_target()
	if e == null:
		volley_left = 0
		return
	volley_target = e
	volley_left -= 1
	volley_timer = COMBO_GAP
	volley_hand = -volley_hand
	facing = position.direction_to(e.position)
	var p := Projectile.new()
	p.main = main
	p.target = e
	p.target_pos = e.position
	p.position = position + facing * 16.0 + facing.orthogonal() * volley_hand * 6.0
	p.damage = blast["damage"] * _power()
	# Like the punch combo, only the volley's last blast can knock back.
	p.knockback_chance = knockback_chance if volley_left == 0 else 0.0
	p.knockback_force = knockback_force
	p.speed = 520.0
	p.style = "ki"
	p.color = KI_COLOR
	main.add_projectile(p)
	swing = 0.1
	_hold_pose("punch", COMBO_GAP)


# Ki tier 4: a beam to the edge of the field hitting every enemy along the line.
func _beam_target():
	var r: float = blast["range"] * 1.3
	return _pick(main.get_enemies().filter(func(x): return _is_valid(x) and _gap_to(x) <= r and _sees(x)))


func _fire_beam() -> void:
	var e = beam_target if _is_valid(beam_target) else _beam_target()
	if e == null:
		return
	var dir := position.direction_to(e.position)
	var from := position + Vector2(0, -14)
	var to := from + dir * 1200.0
	# The beam stops at the first wall it hits.
	for w in main.paths.walls:
		var hit = Geometry2D.segment_intersects_segment(from, to, w.seg_a(), w.seg_b())
		if hit != null:
			to = hit
	for x in main.get_enemies():
		var closest := Geometry2D.get_closest_point_to_segment(x.position, from, to)
		if closest.distance_to(x.position) <= beam["width"] / 2.0 + x.radius:
			x.take_damage(beam["damage"] * _power())
	main.spawn_beam(from, to, Color(1.0, 0.85, 0.3), beam["width"])
	facing = dir
	swing = 0.15
	_hold_pose("punch", 0.35)


# Techniques tier 2: vanish and reappear near a far-off target: right beside it for
# brawlers, or just inside blast range for Ki users.
## Flash Step is used once the target is out of range and either far away or already
## past this warrior on its way to the goal.
func _should_blink(e, gap: float) -> bool:
	var reach: float = attack_range if blast.is_empty() else blast["range"]
	if gap <= reach and _sees(e):
		return false
	# Flash Step is also the way through walls.
	return gap > teleport["min_dist"] or e.position.y > position.y or not _sees(e)


func _blink_to(e) -> void:
	main.spawn_burst(position, 22, Color(0.9, 0.95, 1.0))
	# Land between the enemy and the goal (the bottom line): right below it for
	# brawlers, or just inside blast range below it for Ki users.
	var gap_after: float = 2.0 if blast.is_empty() else blast["range"] * 0.8
	var spot: Vector2 = e.position + Vector2(0, RADIUS + e.radius + gap_after)
	spot.y = minf(spot.y, main.CASTLE_Y - RADIUS)
	if spot.distance_to(e.position) < RADIUS + e.radius:
		# Squeezed against the bottom edge: step to the side instead.
		spot.x += (RADIUS + e.radius) * (1.0 if e.position.x < main.FIELD_W / 2.0 else -1.0)
	position = _clear_of_walls(spot, e.position)
	main.spawn_burst(position, 22, Color(0.9, 0.95, 1.0))
	teleport_timer = teleport["cooldown"]
	route = PackedVector2Array()


## Couldn't find its way back to its post in time: blinks straight there.
func _teleport_home() -> void:
	main.spawn_burst(position, 22, Color(0.75, 0.85, 1.0))
	position = post
	main.spawn_burst(position, 22, Color(0.75, 0.85, 1.0))
	lost_time = 0.0
	ordered = false
	route = PackedVector2Array()


## Thrown back `push` (its length is the distance) over a fifth of a second, then
## stunned for `stun` seconds. Emplacements don't budge but are still stunned.
func shove(push: Vector2, stun_time: float) -> void:
	if not is_active():
		return
	dazed = maxf(dazed, stun_time)
	if not is_emplacement() and push != Vector2.ZERO:
		shove_left = 0.2
		shove_velocity = push / shove_left
	target = null
	combo_left = 0
	volley_left = 0
	beam_charge = 0.0


## A spot that isn't inside a wall: nudged out onto the side `toward` is on.
func _clear_of_walls(spot: Vector2, toward: Vector2) -> Vector2:
	for w in main.paths.walls:
		var c := Geometry2D.get_closest_point_to_segment(spot, w.seg_a(), w.seg_b())
		var min_d: float = RADIUS + w.WALL_HALF + 1.0
		if c.distance_to(spot) >= min_d:
			continue
		var n: Vector2 = (w.seg_b() - w.seg_a()).normalized().orthogonal()
		if n.dot(toward - c) < 0.0:
			n = -n
		spot = c + n * min_d
	return spot.clamp(Vector2(RADIUS, main.DEPLOY_TOP + RADIUS), Vector2(main.FIELD_W - RADIUS, main.CASTLE_Y - RADIUS))


# Techniques tier 3: a blinding flash that stuns everything close by.
func _flash() -> bool:
	var r: float = stun["radius"]
	var victims: Array = main.get_enemies().filter(func(x): return _is_valid(x) and position.distance_to(x.position) <= r + x.radius)
	if victims.is_empty():
		return false
	for x in victims:
		x.apply_stun(stun["duration"])
	main.spawn_flash(position, r)
	return true


func _gap_to(e) -> float:
	return position.distance_to(e.position) - RADIUS - e.radius


func _is_valid(e) -> bool:
	if e == null or not is_instance_valid(e) or e.dead or e.position.y < 0.0 or (e.flying and not hits_air()):
		return false
	# Brawlers can't follow enemies up into their spawn area.
	return not is_melee() or is_emplacement() or e.position.y + e.radius >= main.DEPLOY_TOP


func _find_target():
	if is_emplacement():
		return _pick(main.get_enemies().filter(_in_range))
	var all: Array = main.get_enemies().filter(_is_valid)
	if main.paths.has_walls() and not shoots_over_walls():
		# Rather go after an enemy on this side of the walls than one it can't get at.
		var seen: Array = all.filter(_sees)
		if not seen.is_empty():
			return _pick(seen)
	return _pick(all)


func _in_range(e) -> bool:
	return _is_valid(e) and _gap_to(e) <= attack_range and _sees(e)


## Best enemy among candidates according to this warrior's target priority.
func _pick(candidates: Array):
	var best = null
	var best_score := -INF
	for e in candidates:
		var score := _priority_score(e)
		if score > best_score:
			best_score = score
			best = e
	return best


func _priority_score(e) -> float:
	# Small distance term breaks ties (e.g. a row of full-health goblins) toward the nearest.
	var near := -_gap_to(e) * 0.001
	match priority:
		"first":
			return e.position.y + near
		"strongest":
			# Highest enemy tier first (an orc over a wolf), never mind current health.
			# Within a tier, stick with the current target, then go for the nearest.
			return e.tier * 10000.0 - _gap_to(e) + (1000.0 if e == target else 0.0)
		"weakest":
			# Lowest enemy tier first (a goblin over a wolf), with the same stickiness.
			return -e.tier * 10000.0 - _gap_to(e) + (1000.0 if e == target else 0.0)
	return -_gap_to(e)


func cycle_priority() -> void:
	priority = PRIORITIES[(PRIORITIES.find(priority) + 1) % PRIORITIES.size()]
	target = null
	retarget_timer = 0.0


func _move_toward(p: Vector2, max_dist: float, delta: float) -> void:
	var step := minf(move_speed * (1.0 + buff["speed"]) * delta, max_dist)
	var aim := p
	# Only go the long way round if a wall is in the way of where it means to stop.
	var stop := position + position.direction_to(p) * minf(max_dist, position.distance_to(p))
	if main.paths.has_walls() and main.paths.path_blocked(position, stop, RADIUS + 6.0):
		aim = _route_step(p, delta)
	position += position.direction_to(aim) * step
	walk += step / 12.0   # swap walk frames every 12px
	moving = step > 0.01


## Next waypoint on the way around the walls to p. The route is worked out again
## when p moves away or every half second.
func _route_step(p: Vector2, delta: float) -> Vector2:
	route_timer -= delta
	if route.is_empty() or route_timer <= 0.0 or route_goal.distance_to(p) > 24.0:
		route = main.paths.troop_route(position, p)
		route_goal = p
		route_timer = 0.5
	# Drop waypoints it has reached, and skip ahead while the next one is in plain view.
	while route.size() > 1 and (position.distance_to(route[0]) < 8.0
			or not main.paths.path_blocked(position, route[1], RADIUS + 6.0)):
		route.remove_at(0)
	if route.is_empty():
		return p
	if position.distance_to(route[0]) < 8.0:
		route.remove_at(0)
		return p
	return route[0]


func _separate() -> void:
	if is_emplacement():
		return   # rooted in place; everyone else steps around it
	for w in main.get_warriors():
		if w == self or not w.is_active():
			continue
		var off: Vector2 = position - w.position
		var d := off.length()
		if d < RADIUS * 2.0 and d > 0.01:
			position += off / d * (RADIUS * 2.0 - d) * (1.0 if w.is_emplacement() else 0.5)
	# Walls are solid to troops too.
	for b in main.paths.walls:
		var c := Geometry2D.get_closest_point_to_segment(position, b.seg_a(), b.seg_b())
		var min_d: float = RADIUS + b.WALL_HALF
		var off := position - c
		var d := off.length()
		if d < min_d:
			if d < 0.01:
				off = Vector2.DOWN
				d = 1.0
			position = c + off / d * min_d
	# The Ogre King is too big to shove: troops step out of his way.
	for e in main.get_enemies():
		if e.boss:
			var off: Vector2 = position - e.position
			var min_d: float = RADIUS + e.radius
			if off.length() < min_d:
				position = e.position + (off.normalized() if off.length() > 0.01 else Vector2.DOWN) * min_d
	# Troops never go up into the enemy's spawn area.
	position = position.clamp(Vector2(RADIUS, main.DEPLOY_TOP + RADIUS), Vector2(main.FIELD_W - RADIUS, main.CASTLE_Y - RADIUS))


func _attack(e) -> void:
	swing = 0.15
	var hit := damage * _power()
	var crit := randf() < crit_chance
	if crit:
		hit *= crit_mult
	if is_melee():
		e.take_damage(hit)
		_hit_spark(e)
		if not cleave.is_empty():
			_sweep(e, hit * cleave["damage"])
		if dual > 0.0:
			offhand_timer = 0.12
		return
	# Multishot: extra projectiles go to other enemies in range, by priority.
	var targets := [e]
	var others: Array = main.get_enemies().filter(func(x): return x != e and _in_range(x))
	while targets.size() < multishot:
		var nxt = _pick(others)
		if nxt == null:
			nxt = e
		else:
			others.erase(nxt)
		targets.append(nxt)
	for i in targets.size():
		_shoot(targets[i], i)
	if data["attack"] == "shell":
		main.spawn_burst(_muzzle(), 14.0, Color(1.0, 0.8, 0.45))


## Where projectiles leave from: the hands, or an emplacement's archer or muzzle.
func _muzzle() -> Vector2:
	var f := signf(facing.x) if absf(facing.x) > 0.2 else flip
	match kind:
		"tower":
			return position + Vector2(0, -24)
		"cannon":
			return position + Vector2(19.0 * f, -22)
	return position + facing * 18.0


func _shoot(e, index: int) -> void:
	var hit := damage * _power()
	var crit := randf() < crit_chance
	if crit:
		hit *= crit_mult
	var p := Projectile.new()
	p.main = main
	p.target = e
	p.target_pos = e.position
	p.position = _muzzle() + Vector2(0, -6) * index
	p.damage = hit
	p.crit = crit
	p.splash = splash
	p.knockback_chance = knockback_chance
	p.knockback_force = knockback_force
	p.stun_time = shell_stun
	p.slow = slow
	p.slow_time = slow_time
	p.slow_radius = slow_radius
	p.freeze_chance = freeze_chance
	p.freeze_time = freeze_time
	p.speed = data["projectile_speed"]
	p.style = data["attack"]
	p.color = data["color"]
	p.poison = poison
	p.source = get_instance_id()
	p.cloud = cloud
	p.corrode = corrode
	p.melt = melt
	p.burst = burst
	# Tier-3 looks carry over to some attacks.
	var look := _look_path()
	if kind == "archer" and look == 0:
		p.style = "barbed"
	elif kind == "archer" and look == 1:
		p.style = "crossbow"
	elif (kind == "mage" or kind == "magetower") and look >= 0:
		p.color = MAGE_ORB_COLORS[look]
	elif kind == "alchemist" and look >= 0:
		p.color = FLASK_COLORS[look]
	main.add_projectile(p)


## A quick flash where a melee blow lands.
func _hit_spark(e) -> void:
	if is_instance_valid(e):
		main.spawn_burst(e.position + (position - e.position).normalized() * e.radius * 0.6, 9.0, Color(1, 1, 0.85))


# Swordsman Damage tier 4: the swing carries on through other enemies in a wide arc.
func _sweep(main_target, hit: float) -> void:
	var half := deg_to_rad(cleave["arc"]) / 2.0
	for x in main.get_enemies():
		if x == main_target or not _is_valid(x) or x.flying or _gap_to(x) > attack_range + cleave["reach"]:
			continue
		if absf(angle_difference(facing.angle(), position.direction_to(x.position).angle())) <= half:
			x.take_damage(hit)


# Swordsman Speed tier 3+: the second blade follows up a moment after each attack.
func _offhand_strike() -> void:
	var v = _victim()
	if v == null:
		return
	facing = position.direction_to(v.position)
	swing = 0.15
	_hold_pose("strike2", 0.15)
	v.take_damage(damage * dual * _power())
	_hit_spark(v)


# Mage Storm path: lightning that jumps from enemy to enemy.
func _cast_chain() -> bool:
	var cur = _pick(main.get_enemies().filter(_in_range))
	if cur == null:
		return false
	var hit := []
	var points := PackedVector2Array([position + Vector2(0, -24)])
	while cur != null and hit.size() < int(chain["jumps"]):
		hit.append(cur)
		points.append(cur.position)
		var nxt = null
		var nearest := CHAIN_JUMP
		for e in main.get_enemies():
			var d: float = e.position.distance_to(cur.position)
			if d < nearest and not hit.has(e):
				nearest = d
				nxt = e
		cur = nxt
	for e in hit:
		e.take_damage(chain["damage"] * _power())
	main.spawn_bolt(points, Color(0.7, 0.85, 1.0))
	swing = 0.15
	return true


# Mage Fire path: rapid flame puffs that set the target burning.
func _breathe() -> bool:
	var e = _pick(main.get_enemies().filter(_in_range))
	if e == null:
		return false
	facing = position.direction_to(e.position)
	e.take_damage(breath["damage"] * _power())
	e.apply_burn(breath["burn_dps"], breath["burn_time"])
	main.spawn_flame(position + facing * 16 + Vector2(0, -16), e.position)
	swing = 0.15
	return true


# Mage Arcane Lance path: a heavy beam at the toughest enemy in range.
func _cast_lance() -> bool:
	var best = null
	for e in main.get_enemies():
		if e.position.y >= 0.0 and _gap_to(e) <= attack_range and _sees(e) and (best == null or e.hp > best.hp):
			best = e
	if best == null:
		return false
	main.spawn_beam(position + Vector2(0, -24), best.position, Color(1.0, 0.5, 0.95))
	best.take_damage(lance["damage"] * _power())
	swing = 0.15
	return true


# --- Healer -------------------------------------------------------------

## Healers revive downed allies first (they're on a clock), then heal whoever has the
## lowest share of their health left, then head back to their post.
func _healer_update(delta: float) -> void:
	if ordered:
		rez_target = null
		if position.distance_to(post) <= RADIUS:
			ordered = false
		else:
			facing = position.direction_to(post)
			_move_toward(post, position.distance_to(post), delta)
			return
	var downed = _pick_downed()
	if downed != rez_target:
		rez_target = downed
		rez_progress = 0.0
	if downed != null:
		_go_within_reach(downed, delta)
		if _ally_gap(downed) <= attack_range:
			_rez_step(downed, delta)
		return
	var hurt = _pick_hurt()
	if hurt != null:
		_go_within_reach(hurt, delta)
		if cd_timer <= 0.0 and _ally_gap(hurt) <= attack_range:
			cd_timer = cooldown
			_heal(hurt)
		return
	var d := position.distance_to(post)
	if d > 2.0:
		facing = position.direction_to(post)
		_move_toward(post, d, delta)
	else:
		hp = minf(max_hp, hp + max_hp * REGEN * delta)


## Channels a revival on a downed ally; it gets up once the revive time is done.
func _rez_step(downed, delta: float) -> void:
	rez_progress += delta
	if rez_progress >= _revive_time():
		downed.revived(1.0 if revive.get("full", false) else data["revive_hp"])
		main.spawn_beam(position + Vector2(0, -24), downed.position, Color(1, 1, 0.7), 14.0)
		rez_target = null
		rez_progress = 0.0


# --- Bard ---------------------------------------------------------------

func _bard_update(delta: float) -> void:
	song_tick -= delta
	if song_tick <= 0.0:
		song_tick = 0.25
		if not discord.is_empty():
			for e in main.get_enemies():
				if position.distance_to(e.position) <= aura_reach() + e.radius:
					e.apply_discord(discord["vuln"], discord["weaken"], discord["slow"], 0.4)
		# Notes drift up while a song is playing.
		if (not aura.is_empty() or not discord.is_empty()) and randf() < 0.5:
			var col := Color(1.0, 0.85, 0.35) if not aura.is_empty() else Color(0.65, 0.35, 0.85)
			main.spawn_note(position + Vector2(randf_range(-6, 14), -30), col)
	for spell in spell_timers:
		spell_timers[spell] = maxf(spell_timers[spell] - delta, 0.0)
		var sp: Dictionary = get(spell)
		if sp.is_empty() or spell_timers[spell] > 0.0:
			continue
		var spot = _spell_spot(sp["radius"])
		if spot == null:
			continue
		spell_timers[spell] = sp["cooldown"]
		_cast_spell(spell, sp, spot.position)


## The enemy with the most others around it, within casting reach.
func _spell_spot(radius: float):
	var reach := attack_range + 40.0
	var best = null
	var best_n := 0
	var enemies: Array = main.get_enemies()
	for e in enemies:
		if not _is_valid(e) or _gap_to(e) > reach:
			continue
		var n := 0
		for x in enemies:
			if x.position.distance_to(e.position) <= radius + x.radius:
				n += 1
		if n > best_n:
			best_n = n
			best = e
	return best


func _cast_spell(spell: String, sp: Dictionary, at: Vector2) -> void:
	swing = 0.15
	facing = position.direction_to(at)
	var r: float = sp["radius"]
	var caught: Array = main.get_enemies().filter(func(x): return x.position.distance_to(at) <= r + x.radius)
	match spell:
		"overgrowth":
			var z := Zone.new()
			z.main = main
			z.radius = r
			z.slow = sp["slow"]
			z.life = sp["duration"]
			z.position = at
			main.add_projectile(z)
			main.spawn_text(at + Vector2(0, -30), "Overgrowth", Color(0.5, 0.9, 0.4))
		"vines":
			for x in caught:
				if not x.flying:   # vines can't catch what's in the air
					x.apply_root(sp["duration"])
			main.spawn_burst(at, r, Color(0.35, 0.75, 0.25))
			main.spawn_text(at + Vector2(0, -30), "Vine Snare", Color(0.4, 0.85, 0.3))
		"tornado":
			for x in caught:
				x.apply_knockback(Vector2(randf_range(-20, 20), -sp["push"]))
			main.spawn_tornado(at, r)
			main.spawn_text(at + Vector2(0, -30), "Tornado!", Color(0.85, 0.9, 0.95))
		"confuse":
			for x in caught:
				x.apply_confuse(sp["duration"])
			main.spawn_burst(at, r, Color(0.8, 0.45, 1.0))
			main.spawn_text(at + Vector2(0, -30), "Confusion!", Color(0.85, 0.5, 1.0))
	for i in 3:
		main.spawn_note(position + Vector2(randf_range(-10, 14), -28), Color(0.6, 1.0, 0.6))


# --- Support emplacements -----------------------------------------------

func _support_update(delta: float) -> void:
	match data["attack"]:
		"mine":
			# Digs while a wave is on, until it has made this wave's hauls.
			if not main.wave_active:
				hauls_done = 0
			elif cd_timer <= 0.0 and hauls_done < hauls:
				cd_timer = cooldown
				hauls_done += 1
				var amount := maxi(1, roundi(damage * mine_share()))
				main.gold += amount
				swing = 0.15
				main.spawn_text(position + Vector2(0, -44), "+%dg" % amount, Color(1, 0.85, 0.3))
				if hauls_done == hauls:
					main.spawn_text(position + Vector2(0, -64), "Tapped out", Color(0.85, 0.8, 0.6))
		"pulse":
			# Medic Bay: revive a downed ally in range (once upgraded), and pulse healing.
			if not revive.is_empty():
				var downed = _pick_downed()
				if downed != null and not _in_radius(downed):
					downed = null
				if downed != rez_target:
					rez_target = downed
					rez_progress = 0.0
				if downed != null:
					_rez_step(downed, delta)
			if cd_timer <= 0.0:
				var patients: Array = main.get_warriors().filter(func(w): return w != self and w.is_active() and _in_radius(w) and _best_bay(w) == self)
				if patients.any(func(w): return w.hp < w.max_hp):
					cd_timer = cooldown
					swing = 0.15
					for w in patients:
						if w.hp < w.max_hp:
							main.spawn_burst(w.position, 16.0, Color(0.55, 1.0, 0.55))   # reaches them wherever they are
						w.receive_heal(damage * _power(), regen_grant)
					main.spawn_burst(position, attack_range + RADIUS, Color(0.55, 1.0, 0.55))
		"aura":
			pass   # buffs are read by the units around it (see _update_buffs)
	if target == null:
		hp = minf(max_hp, hp + max_hp * REGEN * delta)


## Gold paid out by a Gold Mine when a wave ends: its wave bonus (shared like its
## hauls), plus `extra` (interest, which main pays only through the best Treasury).
func wave_payout(extra: int) -> int:
	if not is_active() or data["attack"] != "mine":
		return 0
	var amount := roundi(wave_bonus * mine_share()) + extra
	if amount > 0:
		main.spawn_text(position + Vector2(0, -44), "+%dg" % amount, Color(1, 0.85, 0.3))
	return amount


func _in_radius(w) -> bool:
	return covers(w)


## The Medic Bay that looks after w: the strongest one covering it (two bays don't
## both heal the same unit).
func _best_bay(w):
	var best = null
	var best_heal := -1.0
	for b in main.get_warriors():
		if b.kind != "medbay" or not b.is_active() or not b._in_radius(w):
			continue
		var heal: float = b.damage * b._power() / b.cooldown
		if heal > best_heal + 0.001 or (absf(heal - best_heal) <= 0.001 and b.get_instance_id() < best.get_instance_id()):
			best_heal = heal
			best = b
	return best


## Share of a full haul this Gold Mine digs: every mine built before it takes some of the vein.
func mine_share() -> float:
	var rank := 0
	for w in main.get_warriors():
		if w == self:
			break
		if w.data["attack"] == "mine":
			rank += 1
	return pow(MINE_FALLOFF, rank)


func _ally_gap(w) -> float:
	return position.distance_to(w.position) - RADIUS * 2.0


func _go_within_reach(w, delta: float) -> void:
	if w != self:
		facing = position.direction_to(w.position)
	var gap := _ally_gap(w)
	if gap > attack_range:
		_move_toward(w.position, gap - attack_range + 1.0, delta)


func _revive_time() -> float:
	return data["revive_time"] / revive.get("rez_speed", 1.0)


## Downed ally to revive: the one closest to dying (Hard) or to this healer (Normal).
func _pick_downed():
	var best = null
	var best_score := INF
	for w in main.get_warriors():
		if w == self or w.is_active() or w.is_queued_for_deletion():
			continue
		var score: float = w.down_timer * 100.0 if main.permadeath else position.distance_to(w.position)
		if w == rez_target:
			score -= 50.0   # don't abandon a revival halfway
		if score < best_score:
			best_score = score
			best = w
	return best


func _pick_hurt():
	var best = null
	var best_frac := 0.999
	for w in main.get_warriors():
		if not w.is_active():
			continue
		var frac: float = w.hp / w.max_hp
		if frac < best_frac:
			best_frac = frac
			best = w
	return best


func _heal(w) -> void:
	swing = 0.15
	var from := position + Vector2(0, -24)
	main.spawn_beam(from, w.position, Color(0.55, 1.0, 0.55), 8.0)
	w.receive_heal(damage * _power(), regen_grant)
	if not heal_area.is_empty():
		var r: float = heal_area[0]
		for x in main.get_warriors():
			if x != w and x.is_active() and x.position.distance_to(w.position) <= r:
				x.receive_heal(damage * _power() * heal_area[1], regen_grant)
		main.spawn_burst(w.position, r, Color(0.55, 1.0, 0.55))


func receive_heal(amount: float, regen: Array) -> void:
	if not is_active():
		return
	var before := hp
	hp = minf(max_hp, hp + amount)
	if hp - before >= 1.0:
		main.spawn_text(position + Vector2(randf_range(-8, 8), -40), "+%d" % roundi(hp - before), Color(0.5, 1.0, 0.5))
	if not regen.is_empty():
		regen_rate = maxf(regen_rate if regen_left > 0.0 else 0.0, regen[0])
		regen_left = maxf(regen_left, regen[1])


## Brought back by a Healer, with this share of max HP.
func revived(frac: float) -> void:
	hp = max_hp * frac
	down_timer = 0.0
	main.spawn_text(position + Vector2(0, -40), "Revived!", Color(1, 1, 0.6))
	main.spawn_burst(position, 30, Color(1, 1, 0.7))


## Downed (Normal mode): Renewal healers nearby make this unit get up sooner.
func _recovery_aura() -> float:
	var rate := 1.0
	for w in main.get_warriors():
		if w != self and w.is_active() and not w.revive.is_empty() and (w.covers(self) if w.is_support() else w._ally_gap(self) <= w.attack_range):
			rate = maxf(rate, w.revive["aura"])
	return rate


func _hold_pose(p: String, t: float) -> void:
	pose = p
	pose_left = t


## Ranged units ready their next shot (draw the bow, charge the staff) as the
## cooldown runs out while a target is in reach.
func _readying() -> float:
	if target == null or not _is_valid(target) or _gap_to(target) > attack_range + 20.0:
		return 0.0
	var lead := minf(cooldown * 0.6, 0.5)
	return clampf(1.0 - cd_timer / lead, 0.0, 1.0)


## Name of the attack pose to draw this frame (see Sprites.pose), or "".
## Idle tracking (using last frame's state) and the little things troops do with it.
func _animate(delta: float) -> void:
	anim_t += delta
	var busy: bool = moving or swing > 0.0 or pose_left > 0.0 or rez_target != null or not is_active() \
			or (target != null and _is_valid(target))
	idle_t = 0.0 if busy else idle_t + delta
	if kind == "bard" and _idling():
		# Hums to itself: a note every so often.
		note_timer -= delta
		if note_timer <= 0.0:
			note_timer = randf_range(0.9, 1.6)
			main.spawn_note(position + Vector2(randf_range(4, 14), -28), Color(1.0, 0.9, 0.55))


func _idling() -> bool:
	return idle_t > IDLE_AFTER and not is_emplacement()


## Alchemist idle: tosses its flask up and catches it. Height of the toss (0-1), or -1 while it's in hand.
func _toss() -> float:
	if kind != "alchemist" or not _idling():
		return -1.0
	var c := fmod(idle_t - IDLE_AFTER, 1.8)
	return sin(PI * c / 0.7) if c < 0.7 else -1.0


## Melee troops rear back just before a blow lands (0-1).
func _windup() -> float:
	if not is_melee() or swing > 0.0 or combo_left > 0 or target == null or not _is_valid(target):
		return 0.0
	if _gap_to(target) > attack_range + 6.0 or cd_timer > WINDUP:
		return 0.0
	return 1.0 - cd_timer / WINDUP


## Body motion this frame: [offset, tilt, scale]. Walking bounces and leans into the
## step, idling breathes, attacks squash and stretch.
func _body_motion() -> Array:
	var off := Vector2.ZERO
	var rot := 0.0
	var sc := Vector2.ONE
	if is_emplacement():
		return [off, rot, sc]
	var lean := signf(facing.x) if absf(facing.x) > 0.2 else 0.0
	if moving:
		off.y -= absf(sin(walk * PI)) * 3.0
		rot = 0.08 * lean
	elif _idling():
		var b := sin(anim_t * 2.4)
		sc = Vector2(1.0 - 0.012 * b, 1.0 + 0.025 * b)   # breathing
		match kind:
			"martial":
				off.y -= absf(sin(anim_t * 7.0)) * 2.5   # light on its feet, like a boxer
			"bard":
				if fmod(anim_t, 0.6) < 0.1:
					off.y -= 1.5   # tapping a foot
			"healer":
				rot = sin(anim_t * 1.3) * 0.04   # swaying in prayer
			"archer":
				# Easy-going: a lazy sway from foot to foot, leaning back to watch the
				# arrow when she flips it.
				rot = sin(anim_t * 1.6) * 0.05
				off.y -= absf(sin(anim_t * 1.6)) * 1.0
				var t := fmod(idle_t - IDLE_AFTER, ARCHER_LOOP)
				if t > 2.4 and t < 3.2:
					rot -= 0.07 * sin(PI * (t - 2.4) / 0.8) * lean
	else:
		sc.y = 1.0 + 0.015 * sin(anim_t * 4.0)   # ready, weight shifting
	var w := _windup()
	if w > 0.0:
		rot -= 0.14 * w * lean
		off -= facing * 2.0 * w
		sc *= Vector2(1.0 + 0.04 * w, 1.0 - 0.05 * w)
	var a := swing / 0.15
	if a > 0.0:
		if is_melee():
			sc *= Vector2(1.0 + 0.12 * a, 1.0 - 0.1 * a)   # squash into the blow
		else:
			sc *= Vector2(1.0 - 0.05 * a, 1.0 + 0.08 * a)   # stretch up into the cast or shot
	return [off, rot, sc]


func _pose_name() -> String:
	if pose_left > 0.0:
		return pose
	if swing <= 0.0 and _idling():
		var t := idle_t - IDLE_AFTER
		match kind:
			"swordsman":
				if t > 0.3:
					return "plant"   # leans on its sword, point in the dirt
			"martial":
				# Shadow-boxing: jab, jab, kick, then a breather.
				var c := fmod(t, 3.2)
				if c < 0.15 or (c > 0.3 and c < 0.45):
					return "punch"
				if c > 0.6 and c < 0.85:
					return "kick"
			"bard":
				if fmod(t, 0.6) < 0.12:
					return "strum"
			"alchemist":
				if _toss() >= 0.0:
					return "catch"
	match kind:
		"swordsman":
			if swing > 0.0:
				return "swing" if swing > 0.1 else "strike"
		"mage", "frost", "healer":
			if swing > 0.0:
				return "cast"
		"bard":
			if swing > 0.0:
				return "strum"
		"alchemist":
			if swing > 0.0:
				return "throw"
		"archer":
			if swing <= 0.0 and _readying() > 0.0:
				return "draw"
	return ""


## Screen-local position of a pixel of the sprite as drawn this frame.
func _sprite_px(origin: Vector2, x: float, y: float) -> Vector2:
	var half := Sprites.SIZE / 2.0
	return origin + Vector2((x + 0.5 - half) * SCALE * flip, (y + 0.5 - half) * SCALE)


func _draw() -> void:
	var frames: Array = Sprites.frames(sprite_name())
	var size := Vector2(Sprites.SIZE, Sprites.SIZE) * SCALE
	var feet := RADIUS
	xray_tex = null
	draw_set_transform(Vector2(0, feet), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, RADIUS, Color(0, 0, 0, 0.3))
	if not is_active():
		# Knocked out: lying on the ground (or a wrecked emplacement) with a recovery ring.
		if is_emplacement():
			draw_set_transform(Vector2(0, feet - size.y / 2 + 4), 0, Vector2(flip, 0.85))
			draw_texture_rect(frames[0], _tex_rect(frames[0]), false, Color(0.4, 0.38, 0.38, 0.85))
			_remember_body(frames[0], Transform2D(0, Vector2(flip, 0.85), 0, Vector2(0, feet - size.y / 2 + 4)), _tex_rect(frames[0]))
		else:
			draw_set_transform(Vector2(0, 4), PI / 2 * flip, Vector2(flip, 1))
			draw_texture_rect(frames[0], _tex_rect(frames[0]), false, Color(0.5, 0.5, 0.55, 0.85))
			_remember_body(frames[0], Transform2D(PI / 2 * flip, Vector2(flip, 1), 0, Vector2(0, 4)), _tex_rect(frames[0]))
		draw_set_transform(Vector2.ZERO)
		if main.permadeath:
			# Bleeding out: a red ring that drains away.
			var left: float = down_timer / main.down_time
			draw_arc(Vector2.ZERO, RADIUS + 6, -PI / 2, -PI / 2 + TAU * left, 32, Color(1, 0.3, 0.25, 0.85), 2.5, true)
		else:
			var t: float = 1.0 - down_timer / main.down_time
			draw_arc(Vector2.ZERO, RADIUS + 6, -PI / 2, -PI / 2 + TAU * t, 32, Color(1, 1, 1, 0.7), 2.0, true)
		var rez := _rez_progress()
		if rez > 0.0:
			# A Healer is reviving this unit: a golden ring fills up.
			draw_arc(Vector2.ZERO, RADIUS + 11, -PI / 2, -PI / 2 + TAU * rez, 32, Color(1, 0.9, 0.4, 0.95), 3.0, true)
		return
	if data["attack"] == "pulse" or data["attack"] == "aura":
		# Medic Bay and War Statue always show the reach of their effect, faintly.
		var col := Color(0.55, 1.0, 0.55) if data["attack"] == "pulse" else Color(1.0, 0.85, 0.4)
		draw_set_transform(Vector2.ZERO)
		draw_arc(Vector2.ZERO, attack_range + RADIUS, 0, TAU, 64, Color(col, 0.25), 1.5, true)
	elif kind == "bard" and (not aura.is_empty() or not discord.is_empty()):
		# A Bard's song carries this far: gold for Inspire, purple for Discord.
		var col := Color(1.0, 0.85, 0.4) if not aura.is_empty() else Color(0.7, 0.4, 0.95)
		draw_set_transform(Vector2.ZERO)
		draw_arc(Vector2.ZERO, aura_reach(), 0, TAU, 64, Color(col, 0.22), 1.5, true)
	if buff["damage"] + buff["rate"] + buff["defense"] + buff["speed"] > 0.0:
		# Empowered by a War Statue: a gold ring at the feet.
		draw_set_transform(Vector2(0, feet), 0, Vector2(1, 0.35))
		draw_arc(Vector2.ZERO, RADIUS + 6, 0, TAU, 24, Color(1.0, 0.85, 0.35, 0.55), 2.0, true)
		draw_set_transform(Vector2.ZERO)
	if regen_left > 0.0:
		# Regenerating: a soft green glow at the feet.
		draw_set_transform(Vector2(0, feet), 0, Vector2(1, 0.35))
		draw_arc(Vector2.ZERO, RADIUS + 3, 0, TAU, 24, Color(0.5, 1.0, 0.5, 0.6), 3.0, true)
		draw_set_transform(Vector2.ZERO)
	if surge_left > 0.0:
		# Power Surge: a flickering red aura.
		var pulse := 0.25 + 0.1 * sin(Time.get_ticks_msec() / 60.0)
		draw_circle(Vector2(0, feet - size.y * 0.45), size.y * 0.55, Color(1, 0.2, 0.15, pulse), true, -1.0, true)
	var tint := Color(1, 0.45, 0.45) if hurt > 0.0 else Color.WHITE
	var charging := beam_charge > 0.0
	var tex: Texture2D = frames[int(walk) % 2 if moving else 0]
	var pose_tex = Sprites.pose(sprite_name(), _pose_name())
	if pose_tex != null:
		tex = pose_tex
	var lunge := facing * (swing / 0.15) * 5.0
	if is_emplacement() and kind != "cannon":
		lunge = Vector2.ZERO
	elif kind == "cannon":
		lunge = -facing * (swing / 0.15) * 4.0   # recoil
	if moving:
		# Little puffs of dust kicked up behind each step.
		var k := fmod(walk, 1.0)
		var back := Vector2(-signf(facing.x) if absf(facing.x) > 0.2 else 0.0, 0.0)
		var puff := Vector2(0, feet - 2) + back * (6.0 + 8.0 * k)
		draw_circle(puff, 3.0 + 3.0 * k, Color(0.75, 0.68, 0.55, 0.45 * (1.0 - k)), true, -1.0, true)
	var motion := _body_motion()
	var origin: Vector2 = Vector2(0, feet - size.y / 2) + lunge + motion[0]
	var arrow := _archer_arrow(origin) if kind == "archer" and _idling() and _readying() <= 0.0 else {}
	if not arrow.is_empty() and arrow["behind"]:
		draw_set_transform(Vector2.ZERO)
		_draw_arrow(arrow["pos"], arrow["angle"], arrow["alpha"])   # sliding out of (or into) the quiver, behind her
	var body := _tex_rect(tex)
	body.position.y -= size.y / 2
	# Tilt and squash pivot on the feet, so it leans and squashes without lifting off.
	draw_set_transform(origin + Vector2(0, size.y / 2), motion[1], Vector2(flip * motion[2].x, motion[2].y))
	draw_texture_rect(tex, body, false, tint)
	_remember_body(tex, Transform2D(motion[1], Vector2(flip * motion[2].x, motion[2].y), 0, origin + Vector2(0, size.y / 2)), body)
	draw_set_transform(Vector2.ZERO)
	_draw_idle_props(origin, size)
	if dazed > 0.0:
		# Stunned by the Ogre King's stomp: stars circling the head.
		var spin := Time.get_ticks_msec() / 200.0
		var head := Vector2(0, feet - size.y * 0.85)
		for i in 3:
			var p := head + Vector2.from_angle(spin + i * TAU / 3.0) * Vector2(RADIUS * 0.9, 4.0)
			draw_rect(Rect2(p - Vector2(2.5, 2.5), Vector2(5, 5)), Color(1, 0.95, 0.4))
	if kind == "mage" or kind == "frost" or kind == "healer":
		var glow := _orb_color()
		if swing > 0.0:
			# Flash at the tip of the thrust staff as the spell leaves it.
			var tip := _sprite_px(origin, 22, 8) if kind == "mage" else _sprite_px(origin, 22, 5)
			draw_circle(tip, 9.0 * swing / 0.15 + 3.0, Color(glow, 0.5 * swing / 0.15 + 0.2), true, -1.0, true)
		elif _readying() > 0.0:
			# Gathering power in the staff's orb before the next cast.
			var k := _readying()
			var orb := _sprite_px(origin, 14, 2) if kind == "mage" else _sprite_px(origin, 14, 1.5)
			draw_circle(orb, 3.0 + 6.0 * k, Color(glow, 0.45 * k), true, -1.0, true)
	if charging:
		# Gathering ki for the beam: a growing, flickering orb in front of the hands.
		var k := 1.0 - beam_charge / BEAM_CHARGE
		var orb := Vector2(0, feet - size.y * 0.45) + facing * 14.0
		var flicker := 1.0 + 0.15 * sin(Time.get_ticks_msec() / 25.0)
		draw_circle(orb, (4.0 + 10.0 * k) * flicker, Color(KI_COLOR, 0.35), true, -1.0, true)
		draw_circle(orb, (2.0 + 5.0 * k) * flicker, Color(1, 1, 0.9, 0.9), true, -1.0, true)
	if swing > 0.0 and kind == "swordsman":
		var a := facing.angle()
		if cleave.is_empty():
			draw_arc(facing * 8, 30, a - 0.9, a + 0.9, 12, Color(1, 1, 1, swing / 0.15), 3.0, true)
		else:
			# Kingsblade: a broad golden sweep.
			var half := deg_to_rad(cleave["arc"]) / 2.0
			var r: float = 30.0 + cleave["reach"]
			draw_arc(facing * 4, r, a - half, a + half, 20, Color(1, 0.85, 0.35, swing / 0.15), 4.0, true)
			draw_arc(facing * 4, r - 6, a - half * 0.8, a + half * 0.8, 16, Color(1, 1, 1, 0.6 * swing / 0.15), 2.0, true)
	if block_flash > 0.0:
		# Shield glint on a blocked hit.
		var k := block_flash / 0.2
		draw_arc(facing * 10 + Vector2(0, -6), 20, facing.angle() - 1.1, facing.angle() + 1.1, 12, Color(0.8, 0.88, 1.0, k), 4.0, true)
	# Upgrade pips, one row per path in that path's color.
	var row := 0
	for p in 3:
		if tiers[p] == 0:
			continue
		for i in tiers[p]:
			draw_rect(Rect2(-(tiers[p] - 1) * 3.0 + i * 6.0 - 2, feet + 4 + row * 5, 4, 4), PATH_COLORS[p])
		row += 1
	if hp < max_hp:
		var top := Vector2(-RADIUS, feet - size.y - 2)
		draw_rect(Rect2(top, Vector2(RADIUS * 2, 4)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(top, Vector2(RADIUS * 2 * hp / max_hp, 4)), Color(0.35, 0.75, 1.0))


func _remember_body(tex: Texture2D, xform: Transform2D, rect: Rect2) -> void:
	xray_tex = tex
	xray_xform = xform
	xray_rect = rect


## Little props for idle animations, drawn over the sprite.
func _draw_idle_props(origin: Vector2, size: Vector2) -> void:
	if not _idling() or swing > 0.0:
		return
	match kind:
		"archer":
			if _readying() <= 0.0:
				var arrow := _archer_arrow(origin)
				if not arrow.is_empty() and not arrow["behind"]:
					_draw_arrow(arrow["pos"], arrow["angle"])
		"mage":
			# Motes of magic circling the staff's orb.
			var orb := _sprite_px(origin, 14, 2)
			draw_circle(orb, 5.0 + sin(anim_t * 3.0), Color(_orb_color(), 0.25), true, -1.0, true)
			for i in 3:
				var p := orb + Vector2.from_angle(anim_t * 3.0 + i * TAU / 3.0) * Vector2(10, 5)
				draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(_orb_color(), 0.9))
		"frost":
			# Snowflakes drifting around her.
			var mid := origin + Vector2(0, size.y * 0.05)
			for i in 5:
				var ang := anim_t * 1.6 + i * TAU / 5.0
				var p := mid + Vector2(cos(ang) * 20.0, sin(ang) * 7.0 - 6.0 + sin(anim_t * 2.0 + i) * 4.0)
				var col := Color(0.92, 0.98, 1.0, 0.6 + 0.4 * (0.5 + 0.5 * sin(ang)))
				draw_circle(p, 4.0, Color(0.6, 0.85, 1.0, 0.25), true, -1.0, true)
				draw_rect(Rect2(p - Vector2(1, 4), Vector2(2, 8)), col)
				draw_rect(Rect2(p - Vector2(4, 1), Vector2(8, 2)), col)
		"healer":
			# Sparks of light rising from its prayer.
			for i in 3:
				var k := fmod(anim_t * 0.6 + i / 3.0, 1.0)
				var p := origin + Vector2(sin(i * 2.1 + anim_t) * 14.0, size.y * 0.2 - k * 44.0)
				draw_circle(p, 5.0, Color(0.7, 1.0, 0.6, 0.3 * (1.0 - k)), true, -1.0, true)
				draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.95, 0.6, 1.0 - k))
		"alchemist":
			var h := _toss()
			if h >= 0.0:
				# The flask (or bomb) spinning up out of its hand and back down.
				var p := _sprite_px(origin, 13.5, 8) + Vector2(0, -h * 28.0)
				var look := _look_path()
				draw_set_transform(p, anim_t * 12.0, Vector2.ONE)
				if look == 2:
					draw_circle(Vector2.ZERO, 6.0, OUTLINE_COLOR, true, -1.0, true)
					draw_circle(Vector2.ZERO, 4.5, Color(0.35, 0.35, 0.42), true, -1.0, true)
					draw_rect(Rect2(-1, -9, 2, 3), Color(1.0, 0.8, 0.25))
				else:
					draw_circle(Vector2(0, 1), 5.5, OUTLINE_COLOR, true, -1.0, true)
					draw_rect(Rect2(-2.5, -7, 5, 5), OUTLINE_COLOR)
					draw_circle(Vector2(0, 1), 4.0, FLASK_COLORS[look] if look >= 0 else data["color"], true, -1.0, true)
					draw_rect(Rect2(-1.5, -6, 3, 4), Color(0.85, 0.95, 0.95))
				draw_set_transform(Vector2.ZERO)


## Archer idle: where the arrow is in its loop, as {pos, angle, behind}, or {} while
## her hands are empty. Every move eases in and out so it flows.
func _archer_arrow(origin: Vector2) -> Dictionary:
	var t := fmod(idle_t - IDLE_AFTER, ARCHER_LOOP)
	var hand := _sprite_px(origin, 2.5, 10)
	var quiver := _sprite_px(origin, 2.0, 6.0)    # on her back, just behind the shoulder
	var lifted := quiver + Vector2(0, -14)
	var up := -PI / 2
	var ahead := 0.0 if flip > 0 else PI
	if t < 0.5:
		# Reaches back and slides an arrow up out of the quiver.
		var k := smoothstep(0.0, 1.0, t / 0.5)
		return {"pos": quiver.lerp(lifted, k), "angle": up, "behind": true, "alpha": k}
	if t < 0.9:
		# Brings it round to her hand, turning it level.
		var k := smoothstep(0.0, 1.0, (t - 0.5) / 0.4)
		return {"pos": lifted.lerp(hand, k), "angle": lerp_angle(up, ahead, k), "behind": false}
	if t < 2.4:
		# Twirls it: spins up, three turns, spins down.
		var k := smoothstep(0.0, 1.0, (t - 0.9) / 1.5)
		return {"pos": hand, "angle": ahead + k * TAU * 3.0, "behind": false}
	if t < 3.2:
		# Flips it up into the air, end over end, and catches it.
		var k := (t - 2.4) / 0.8
		return {"pos": hand + Vector2(0, -sin(PI * k) * 34.0), "angle": ahead + smoothstep(0.0, 1.0, k) * TAU * 2.0, "behind": false}
	if t < 4.2:
		# One last lazy turn.
		var k := smoothstep(0.0, 1.0, (t - 3.2) / 1.0)
		return {"pos": hand, "angle": ahead + k * TAU, "behind": false}
	if t < 4.6:
		# Back over the shoulder...
		var k := smoothstep(0.0, 1.0, (t - 4.2) / 0.4)
		return {"pos": hand.lerp(lifted, k), "angle": lerp_angle(ahead, up, k), "behind": false}
	if t < 4.9:
		# ...and down into the quiver.
		var k := smoothstep(0.0, 1.0, (t - 4.6) / 0.3)
		return {"pos": lifted.lerp(quiver, k), "angle": up, "behind": true, "alpha": 1.0 - k}
	return {}


## An arrow centered on p, pointing along angle.
func _draw_arrow(p: Vector2, angle: float, alpha := 1.0) -> void:
	var d := Vector2.from_angle(angle) * 9.0
	draw_line(p - d, p + d, Color(OUTLINE_COLOR, alpha), 3.5, true)
	draw_line(p - d, p + d, Color(0.92, 0.88, 0.78, alpha), 1.5, true)
	var side := d.orthogonal().normalized() * 3.0
	draw_colored_polygon(PackedVector2Array([p + d * 1.35, p + d + side, p + d - side]), Color(0.78, 0.8, 0.86, alpha))
	draw_line(p - d, p - d * 0.65, Color(0.85, 0.25, 0.2, alpha), 3.5, true)   # fletching


## Where to draw a sprite texture: centered on the body, wide poses reaching forward.
func _tex_rect(tex: Texture2D) -> Rect2:
	var half := Sprites.SIZE / 2.0 * SCALE
	return Rect2(-half, -half, tex.get_width() * SCALE, Sprites.SIZE * SCALE)


## How far along any Healer's revival of this unit is (0-1).
func _rez_progress() -> float:
	var best := 0.0
	for w in main.get_warriors():
		if w.is_active() and w.rez_target == self:
			best = maxf(best, w.rez_progress / w._revive_time())
	return best


func _orb_color() -> Color:
	if kind == "frost":
		return Color(0.75, 0.95, 1.0)
	if kind == "healer":
		return Color(0.6, 1.0, 0.6)
	var look := _look_path()
	return MAGE_ORB_COLORS[look] if look >= 0 else Color(0.85, 0.55, 1.0)
