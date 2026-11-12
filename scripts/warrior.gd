extends Node2D
## A hired warrior. Goes after an enemy on the field (chosen by its target
## priority), attacks it, and walks back to its post when the field is clear.
## Upgrades come from four paths (see data.gd): any six upgrades, in any mix of paths.

const Data = preload("res://scripts/data.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Trap = preload("res://scripts/trap.gd")
const Sprites = preload("res://scripts/sprites.gd")
const Zone = preload("res://scripts/zone.gd")
const MAX_TIER := 4
const MAX_UPGRADES := 6   # upgrades a unit can have in all, spread over its four paths however you like
const PATH_COLORS := [Color(1.0, 0.6, 0.3), Color(0.45, 0.8, 1.0), Color(0.7, 1.0, 0.45), Color(0.9, 0.55, 1.0)]
const RADIUS := 18.0
const SCALE := 3.0      # sprite pixels to screen pixels
const REGEN := 0.06     # fraction of max HP healed per second while idle
const CHAIN_JUMP := 100.0
const COMBO_GAP := 0.12   # seconds between hits in a combo, and between blasts in a volley
const KI_COLOR := Color(1.0, 0.88, 0.35)
const OUTLINE_COLOR := Color(0.1, 0.07, 0.1)
const BEAM_CHARGE := 0.5   # seconds spent gathering ki before the beam fires
const MAGE_ORB_COLORS := [Color(0.5, 0.75, 1.0), Color(1.0, 0.85, 0.5), Color(1.0, 0.5, 0.15), Color(0.55, 0.95, 0.45)]
const FLASK_COLORS := [Color(0.65, 0.35, 0.95), Color(0.88, 0.95, 0.2), Color(1.0, 0.45, 0.15), Color(0.95, 0.3, 0.25)]
const DASH_TIME := 0.18      # seconds a Swordsman's dash takes
const RUN_BEFORE_DASH := 1.0 # seconds of running before a dash
const LANCE_AFTER := 0.25    # seconds of running before a Charge Knight lowers his spear for it
const GOLD_HAIR := {"h": Color(1.0, 0.86, 0.25)}   # Golden Ascension
const IDLE_AFTER := 0.8   # seconds with nothing to do before a troop starts its idle animation
const WINDUP := 0.18      # melee troops rear back over the last moment before a blow
const ARCHER_LOOP := 5.6  # Archer idle: draw an arrow, twirl it, flip it, twirl, put it back, rest
const PRIORITIES := ["closest", "first", "strongest", "weakest"]
const PRIORITY_NAMES := {
	"closest": "Closest", "first": "First", "strongest": "Strongest", "weakest": "Weakest", "objective": "Objective",
	"revive": "Revive", "heal": "Heal", "stay": "Stay with",
}
# A Healer's own priorities: who it looks after first. "revive": the downed first (they're
# on a clock), then the hurt; "heal": the hurt first, then the downed; "stay": it keeps
# with a troop (or a group: its wards) and looks after them first, and anyone else only
# within reach without leaving them. Where there are villagers on the field, they're
# among the hurt it heals.
const HEAL_PRIORITIES := ["revive", "heal", "stay"]
const WARD_GAP := Vector2(0, 34)   # where a Healer keeps itself from its ward (just behind it)
# In a battle with something to protect (rules.guards()), one more: "objective", the enemy
# nearest to getting at it. New troops start on it there.
const OBJECTIVE_PRIORITY := "objective"
const THREAT_RANGE := 320.0   # an enemy this far from its objective (or further) is the least urgent of those after one
# Orders: how far a unit may go from its post (its anchor) to fight, and how firmly it
# sticks to the enemy it picked. Incidental blows on the way (see _victim) never change either.
const MOVE_MODES := ["hold", "short", "guard", "free"]
const MOVE_NAMES := {"hold": "Hold Position", "short": "Short Leash", "guard": "Guard Area", "free": "Free Roam"}
const LEASH_LIMITS := {"short": [40.0, 160.0], "guard": [120.0, 400.0]}   # each zone's size range, px from the post
const LEASH_DEFAULT := {"short": 90.0, "guard": 200.0}
const COMMITS := ["focused", "reactive"]
const COMMIT_NAMES := {"focused": "Focused", "reactive": "Reactive"}
const ZONE_SLACK := 16.0   # a target already picked is let go only this far past where it could be picked (no flicker at the edge)
const STALL_TIME := 2.5    # chasing without getting any closer for this long: the target's out of its way, so let it go
const SHUN_TIME := 3.0     # ...and don't pick that one again for this long

var kind := ""
var data: Dictionary
var main
var post := Vector2.ZERO
var post_u := 0.0              # post's place across the field (0 = left edge, 1 = right), kept through window resizes
var fitted_post := Vector2.INF # post as of the last resize; if it's changed since, post_u is taken afresh
var tiers := [0, 0, 0, 0]
var wall_guard := false      # posted on the castle wall by a castle upgrade: stands at its post, out of reach
var last_path := -1   # the path upgraded most recently (its look wins a tie)
var summoned := false # a skeleton raised by Necromancy: can't be sold, crumbles at the end of the wave
var summoner = null   # the Mage (or Mage Tower) that raised it, or the Martial Artist a copy came from
var clone_of = null   # Mirror Self: the real Martial Artist this copy is part of (null for the real one)
var multiform := {}   # Mirror Self: copies, power, hp, cooldown
var multiform_timer := 0.0
var spent := 0
var priority := "closest"
var move_mode := "free"        # Orders: see MOVE_MODES
var leash := LEASH_DEFAULT.duplicate()   # each zone mode's size (px from the post)
var commit := "focused"        # Orders: see COMMITS
var chase_best := INF          # nearest it has got to its target (for spotting a chase going nowhere)
var chase_time := 0.0          # seconds since it last got closer
var anchor = null              # Orders: an objective it follows (a wagon, civilians), or a Healer's ward: its post goes where that goes
var wards: Array = []          # a Healer staying with troops ("stay"): who it keeps with and looks after first
var anchor_off := Vector2.ZERO # where it keeps itself, from the anchor
var anchor_check := 0.0
var shun_id := 0               # an enemy it gave up on, not picked again until shun_left runs out
var shun_left := 0.0

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
var way_check := 0.0       # on terrain: when to look again whether the straight way is blocked
var way_goal := Vector2.INF
var way_blocked := false
var retreat_to := Vector2.INF   # on terrain: where it's backing off to
var retreat_check := 0.0
var aura_tick := 1.0     # War Statue: next count of the allies it's boosting (campaign XP)
var goo_timer := 0.0     # hit by a Slime: slowed (moving, and attacking at half that) until this runs out
var goo_slow := 0.0
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
var blast := {}              # damage, count, range, cooldown (Spirit path)
var blast_count := 0         # blasts per volley (Brawling tiers add to this when Spirit is taken)
var beam := {}               # damage, cooldown, width
var evade := 0.0
var teleport := {}           # cooldown, min_dist
var stun := {}               # radius, duration, cooldown
var surge := {}              # cooldown, duration, damage, rate
# Swordsman.
var cleave := {}             # arc (degrees), reach, damage: Damage tier 3 cleaves, tier 4 spins (arc 360)
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
var _look_key := -1           # see _look()
var _look_cache := {}
var xray_xform := Transform2D.IDENTITY
var xray_rect := Rect2()
# Alchemist.
var poison := {}             # dps, duration, stacks added by each flask
var cloud := {}              # radius, duration of the toxic cloud a flask leaves
var corrode := {}            # amount, duration: splashed enemies take more damage
var melt := 0.0              # share of the direct target's max HP each flask burns away
var burst := 0.0             # enemies a flask kills explode for this multiple of its damage
# Fourth paths and tier-3 specials (see data.gd for what each holds).
var dash := {}               # Swordsman Charge
var run_time := 0.0          # seconds it has been running at its target without stopping
var dash_left := 0.0         # > 0 while dashing
var dash_to := Vector2.ZERO
var dash_target = null
var dash_hit := []           # enemies already bowled over by this dash
var engaged = null           # the enemy it's trading blows with (Unstoppable chains on when it falls)
var engaged_id := 0          # its instance id (0 = none)
var pierce := 0              # Archer Trick Shots
var seek := false
var magnet := {}             # Mage tier-3 blasts
var echo := {}
var fireball := {}
var decay := {}
var summon := {}             # Mage Necromancy
var summon_timer := 2.0
var frost_aura := {}         # Frost Witch / Frost Tower
var frost_tick := 0.0
var aura_freeze_timer := 0.0
var rage := {}               # Martial Artist Power
var crimson := {}
var golden := {}
var crimson_timer := 0.0
var crimson_left := 0.0
var golden_timer := 0.0
var golden_left := 0.0
var heal_aura := {}          # Healer Halo
var heal_tick := 0.0
var thorns_dps := 0.0        # Bard
var befuddle := []
var confuse_vuln := 0.0
var traps := {}              # Alchemist Trapcraft
var trap_timer := 0.0
var my_traps := []
var burn := []               # Archer Tower / Cannoneer
var rain := {}
var rain_timer := 0.0
var cluster := {}
var napalm := {}
var smite := {}              # Medic Bay Consecration
var smite_timer := 0.0
var gems := []               # Gold Mine Gemcutters
var mortar := false          # Cannoneer Mortar: shells clear walls
# Statue buffs this unit is standing in (the strongest nearby statue for each).
var buff := {"damage": 0.0, "rate": 0.0, "defense": 0.0, "speed": 0.0, "regen": 0.0, "recover": 0.0}
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
var lance_left := 0.0   # a Charge Knight's spear blow at the end of a dash, still showing
var hurt := 0.0
var down_timer := 0.0
var walk := 0.0
var moving := false
var build_left := 0.0      # an emplacement still being built: seconds of an Engineer's work left
var build_total := 0.0
var kiting := false        # a ranged troop backing away from an enemy that got too close
const KITE_GAP := 45.0     # ranged troops back off from enemies closer than this...
const KITE_CLEAR := 70.0   # ...until they're this far off again
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


func setup(k: String, d: Dictionary, m, post_pos: Vector2) -> void:
	kind = k
	data = d
	main = m
	post = post_pos
	spent = d["cost"]
	_apply_upgrades()
	hp = max_hp
	# Units re-pick targets every 0.3s; start each at a different point in that cycle
	# so an army hired together doesn't all re-pick in the same frame.
	retarget_timer = randf() * 0.3
	buff_timer = randf() * 0.25


func _apply_upgrades() -> void:
	max_hp = data["hp"]
	armor = data.get("armor", 0.0)
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
	dash = {}
	pierce = 0
	seek = false
	magnet = {}
	echo = {}
	fireball = {}
	decay = {}
	summon = {}
	frost_aura = {}
	rage = {}
	crimson = {}
	golden = {}
	heal_aura = {}
	thorns_dps = 0.0
	befuddle = []
	confuse_vuln = 0.0
	traps = {}
	burn = []
	rain = {}
	cluster = {}
	napalm = {}
	smite = {}
	gems = []
	mortar = false
	multiform = {}
	for p in mini(tiers.size(), data["paths"].size()):
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
				evade = maxf(evade, fx["evade"])   # Afterimage and Iron Will don't stack: the better one counts
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
			for key in ["damage", "rate", "defense", "speed", "regen", "recover"]:
				if fx.has("aura_" + key):
					aura[key] = fx["aura_" + key]
			for key in ["dash", "magnet", "echo", "fireball", "decay", "summon", "frost_aura", "rage", "crimson",
					"golden", "heal_aura", "befuddle", "traps", "burn", "rain", "cluster", "napalm", "smite", "gems", "multiform"]:
				if fx.has(key):
					set(key, fx[key])
			pierce = fx.get("pierce", pierce)
			mortar = fx.get("mortar", mortar)
			seek = fx.get("seek", seek)
			thorns_dps = fx.get("thorns_dps", thorns_dps)
			confuse_vuln = fx.get("confuse_vuln", confuse_vuln)
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


## The path whose look the unit wears: the highest one at tier 3 or more (the one
## upgraded last if two tie), or -1.
func _look_path() -> int:
	var best := -1
	for p in tiers.size():
		if tiers[p] < 3:
			continue
		if best < 0 or tiers[p] > tiers[best] or (tiers[p] == tiers[best] and p == last_path):
			best = p
	return best


## Upgrades bought so far, over all paths.
func total_upgrades() -> int:
	var n := 0
	for t in tiers:
		n += t
	return n


const STAFF_PERIOD := 4.0   # seconds for a two-path Mage's staff to shift there and back
const STAFF_STEPS := 16     # shades it passes through (each is a cached sprite)


## How far a two-path Mage's staff has shifted from the first path's color to the
## second's, in STAFF_STEPS steps.
func _staff_step() -> int:
	var t := 0.5 - 0.5 * cos(TAU * Time.get_ticks_msec() / 1000.0 / STAFF_PERIOD)
	return roundi(t * (STAFF_STEPS - 1))


## A two-path Mage's staff color right now: between his two paths' orb colors.
func _staff_color() -> Color:
	var high := _high_paths()
	return (MAGE_ORB_COLORS[high[0]] as Color).lerp(MAGE_ORB_COLORS[high[1]], _staff_step() / float(STAFF_STEPS - 1))


## Paths at tier 3 or more (two at most, with six upgrades).
func _high_paths() -> Array:
	var out := []
	for p in tiers.size():
		if tiers[p] >= 3:
			out.append(p)
	return out


## The combined outfit for two paths both at tier 3, or "".
func _combo_sprite() -> String:
	var high := _high_paths()
	return Sprites.combo(kind, high[0], high[1], Sprites.look_kind(kind)) if high.size() >= 2 else ""


## Paths that add an accent to the look: every upgraded path except the one (or two)
## whose outfit it's wearing, unless that outfit shows nothing of it.
func _accent_paths() -> Array:
	var combo := _combo_sprite()
	var wearing := _high_paths().filter(func(p): return not Sprites.combo_silent(combo).has(p)) if combo != "" else [_look_path()]
	var out := []
	var accents: Array = Sprites.ACCENTS.get(kind, [])
	for p in mini(accents.size(), tiers.size()):
		if tiers[p] > 0 and not wearing.has(p):
			out.append(p)
	return out


func accent_layers() -> Array:
	var accents: Array = Sprites.ACCENTS.get(kind, [])
	return _accent_paths().map(func(p): return accents[p])


## Names this mix of accents for the sprite cache.
func accent_tag() -> String:
	var paths := _accent_paths()
	return "" if paths.is_empty() else "+a" + "".join(paths.map(func(p): return str(p)))


## Sprite to draw: tier 3 in a path swaps in that path's look, and two paths at
## tier 3 wear a combination of both.
func sprite_name() -> String:
	var combo := _combo_sprite()
	if combo != "":
		return combo
	var p := _look_path()
	var look := "%s_p%d" % [Sprites.look_kind(kind), p]
	return look if p >= 0 and Sprites.SPRITES.has(look) else Sprites.look_kind(kind)


## The unit kind this unit's deeds train (campaign XP): its own, its summoner's for a
## raised skeleton, the real one's for a Mirror Self copy; none for the castle's wall guards.
func xp_kind() -> String:
	if wall_guard:
		return ""
	if clone_of != null:
		return clone_of.kind if is_instance_valid(clone_of) else ""
	if summoned:
		return summoner.xp_kind() if is_instance_valid(summoner) else ""
	return kind


func is_melee() -> bool:
	return data["attack"] == "melee" or data["attack"] == "combo"


## What this unit's main attack is made of (see the damage schools in enemy.gd).
func school() -> String:
	match data["attack"]:
		"orb", "note":
			return "magic"
		"frost":
			return "ice"
	return "physical"


## Whether this unit can hurt e at all: a Slime that isn't iced over takes nothing from
## blades and arrows, so only magic, ice and ki users go after one.
func can_hurt(e) -> bool:
	return not e.gooey or not e.resists(school()) or not blast.is_empty()


## Slime blows: slowed (moving and attacking) for a while.
func apply_goo(strength: float, duration: float) -> void:
	goo_slow = maxf(goo_slow if goo_timer > 0.0 else 0.0, strength)
	goo_timer = maxf(goo_timer, duration)


func _goo_factor() -> float:
	return 1.0 - goo_slow if goo_timer > 0.0 else 1.0


func is_healer() -> bool:
	return data["attack"] == "heal"


## Emplacements stay where they were built and only shoot what comes into range.
func is_emplacement() -> bool:
	return data.get("emplacement", false)


## Support emplacements (gold mine, medic bay, statue) never attack anything.
func is_support() -> bool:
	return data["attack"] in ["mine", "pulse", "aura"]


## Towers fire from high up, mortar shells and flasks arc over, so they clear walls;
## every other attack (a plain Cannoneer's shells too) needs a clear line to its target.
func shoots_over_walls() -> bool:
	if data["attack"] == "shell":
		return mortar
	return is_emplacement() or wall_guard or data["attack"] == "flask"   # towers and the castle wall stand above the barricades


func _sees(e) -> bool:
	return shoots_over_walls() or not main.paths.wall_between(position, e.position)


## Whether the Target button means anything for this unit.
func uses_targeting() -> bool:
	return not is_healer() and not is_support()


func _power() -> float:
	return (surge["damage"] if surge_left > 0.0 else 1.0) * _form("damage") * (1.0 + buff["damage"]) * _body_share()


## Mirror Self: the share of the Martial Artist's power each of his bodies has right
## now. Split between him and his copies; all of it back with him once they're gone.
func _body_share() -> float:
	var real = clone_of if clone_of != null else self
	if not is_instance_valid(real) or real.multiform.is_empty():
		return 1.0
	var bodies: int = 1 + real._clones().size()
	return 1.0 if bodies == 1 else real.multiform["power"] / bodies


func _clones() -> Array:
	return main.get_warriors().filter(func(w): return w.clone_of == self)


func _rate() -> float:
	return (surge["rate"] if surge_left > 0.0 else 1.0) * _form("rate") * (1.0 + buff["rate"]) * (1.0 - (1.0 - _goo_factor()) * 0.5)


## Martial Artist Discipline path: what Iron Will, the crimson aura and the golden form
## multiply `key` (damage, rate or speed) by right now.
func _form(key: String) -> float:
	var m := 1.0
	if not rage.is_empty() and hp < max_hp * rage["below"]:
		m *= rage.get(key, 1.0)
	if crimson_left > 0.0:
		m *= crimson.get(key, 1.0)
	if golden_left > 0.0:
		m *= golden.get(key, 1.0)
	return m


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
		if w == self or w.aura.is_empty() or not w.is_active() or w.build_left > 0.0:
			continue
		if w.covers(self):
			var from: Dictionary = best.get_or_add(w.kind, {})
			for key in w.aura:
				from[key] = maxf(from.get(key, 0.0), w.aura[key])
	for from in best.values():
		for key in from:
			buff[key] += from[key]
	# The castle's Rally Horn.
	for key in ["damage", "rate", "speed"]:
		buff[key] += main.powers.rally(key)
	# A Healer's halo: the best one covering this unit guards it (on top of statues and songs).
	var guard := 0.0
	for w in main.get_warriors():
		if w != self and not w.heal_aura.is_empty() and w.is_active() and w.position.distance_to(position) <= w.heal_aura["radius"] + RADIUS:
			guard = maxf(guard, w.heal_aura["defense"])
	buff["defense"] += guard
	# An Aegis Field wall guards allies standing near it.
	var field := 0.0
	for b in main.paths.walls:
		field = maxf(field, b.aegis_at(position))
	buff["defense"] += field


func is_active() -> bool:
	return down_timer <= 0.0 and not is_queued_for_deletion()


## Something a Healer can keep with (as an anchor): there to follow while it's on the
## field, downed or not.
func is_target() -> bool:
	return not is_queued_for_deletion()


## Its name, as a thing to follow or stay with.
var label: String:
	get:
		return data.get("name", kind.capitalize()) if not data.is_empty() else kind


## A Healer that walks the field (not a Medic Bay): it takes HEAL_PRIORITIES.
func is_mobile_healer() -> bool:
	return is_healer() and not is_emplacement() and not wall_guard


## Who a Healer looks after first ("revive", "heal" or "stay"; anything else: "revive").
func care() -> String:
	return priority if priority in HEAL_PRIORITIES else "revive"


func set_post(p: Vector2) -> void:
	post = p
	target = null


## A player move order: walk to the new post without stopping to fight.
func order_to(p: Vector2) -> void:
	if care() == "stay" and is_mobile_healer():
		stop_staying()   # sent somewhere: it leaves its ward
	set_post(p)
	ordered = true


## A Healer stays with `troops` (its wards): keeps with them and looks after them first.
func stay_with(troops: Array) -> void:
	wards = troops.filter(func(t): return t != self and is_instance_valid(t))
	if wards.is_empty():
		return
	priority = "stay"
	anchor = null
	_keep_wards()


func stop_staying() -> void:
	wards = []
	if anchor != null and is_instance_valid(anchor) and anchor.has_method("stay_with"):   # (a ward, not a wagon)
		anchor = null
	if priority == "stay":
		priority = "revive"


## Back to the battle's default targeting, with nothing in its sights (a convoy entering a
## new stretch): the Objective priority (or Closest with nothing to guard), a mobile
## Healer's Revive, and no target, chase, volley, beam, dash or revive carried over.
func reset_targeting(keep_priority := false) -> void:
	if keep_priority:
		pass   # (only what it was aiming at and in the middle of goes)
	elif is_mobile_healer():
		stop_staying()
		priority = "revive"
	else:
		priority = OBJECTIVE_PRIORITY if main.rules.guards() else "closest"
	target = null
	dash_target = null
	volley_target = null
	volley_left = 0
	beam_target = null
	beam_charge = 0.0
	rez_target = null
	rez_progress = 0.0
	chase_best = INF
	chase_time = 0.0
	run_time = 0.0
	retarget_timer = 0.0


## Its wards still on the field, and its post kept with the nearest of them.
func _keep_wards() -> void:
	wards = wards.filter(func(t): return is_instance_valid(t) and not t.is_queued_for_deletion())
	if wards.is_empty():
		stop_staying()
		main.spawn_text(position + Vector2(0, -50), "Back to its post", Color(0.7, 0.95, 1.0))
		return
	if not wards.has(anchor):
		var near = wards[0]
		for t in wards:
			if t.position.distance_to(position) < near.position.distance_to(position):
				near = t
		anchor = near
		anchor_off = WARD_GAP
		anchor_check = 0.0


## "ok", "max" (this path is at tier 4) or "full" (all six upgrades are used).
func path_state(p: int) -> String:
	if p >= data["paths"].size() or (data["paths"][p]["tiers"] as Array).is_empty():
		return "none"   # (a raised Skeleton has no upgrades)
	if tiers[p] >= MAX_TIER:
		return "max"
	if total_upgrades() >= MAX_UPGRADES:
		return "full"
	if tiers[p] >= main.max_tier(kind, p):
		return "untrained"   # campaign: the next tier needs troop training first
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
	last_path = p
	_apply_upgrades()
	hp = max_hp * ratio


func sell_value() -> int:
	var step: int = main.price_step
	return int(spent * 0.6) if step <= 1 else roundi(spent * 0.6 / step) * step


func stats_text() -> String:
	if build_left > 0.0:
		return "Under construction - an Engineer has %.1fs of work left on it" % build_left
	var s := "HP %d/%d   Damage %.0f   Every %.2fs" % [ceili(hp), ceili(max_hp), damage, cooldown]
	if is_support():
		match data["attack"]:
			"mine":
				s = "HP %d/%d   %dg every %.1fs during waves   Hauls %d/%d this wave" % [ceili(hp), ceili(max_hp), maxi(1, roundi(damage)), cooldown, hauls_done, hauls]
				if wave_bonus > 0:
					s += "   +%dg per wave" % roundi(wave_bonus)
				if not interest.is_empty():
					s += "   Interest %d%% (max %d)" % [roundi(interest[0] * 100), interest[1]]
			"pulse":
				s = "HP %d/%d   Heals %.0f to all in radius every %.2fs   Radius %s" % [ceili(hp), ceili(max_hp), damage, cooldown, Data.ft(attack_range)]
				if not regen_grant.is_empty():
					s += "   Regen %.1f%%/s for %.0fs" % [regen_grant[0] * 100, regen_grant[1]]
				if not revive.is_empty():
					s += "   Revives in %.1fs" % _revive_time()
				if aura.has("regen"):
					s += "   Allies regen %s%% HP/s" % _pct(aura["regen"])
				if aura.has("recover"):
					s += ("   Downed allies hold on %d%% longer" if main.permadeath else "   Downed allies get up %d%% sooner") % roundi(aura["recover"] * 100)
			"aura":
				s = "HP %d/%d   Radius %s  " % [ceili(hp), ceili(max_hp), Data.ft(attack_range)]
				var names := {"damage": " +%d%% damage", "rate": " +%d%% attack speed", "defense": " -%d%% damage taken", "speed": " +%d%% move speed",
						"recover": " downed hold on %d%% longer" if main.permadeath else " downed get up %d%% sooner"}
				for key in aura:
					if key == "regen":
						s += " +%s%% HP/s" % _pct(aura[key])
					else:
						s += names[key] % roundi(aura[key] * 100)
		s += _extra_stats()
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
		s += _extra_stats()
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
		s += _extra_stats()
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
		s += "   Spirit %.0f x%d / %.1fs, range %s" % [blast["damage"], blast_count, blast["cooldown"], Data.ft(blast["range"])]
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
		s += "   %s %d%%" % ["Spin" if cleave["arc"] >= 360.0 else "Cleave", roundi(cleave["damage"] * 100)]
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
	s += _extra_stats()
	if not is_active():
		if main.permadeath:
			s += "\nDown! Dies in %ds unless a Healer revives it" % ceili(down_timer)
		else:
			s += "\nKnocked out, back in %ds" % ceili(down_timer)
	return s


## A fraction as a percentage: "4.5", "10".
static func _pct(f: float) -> String:
	var v := f * 100.0
	return "%d" % roundi(v) if absf(v - roundf(v)) < 0.05 else "%.1f" % v


## Stats from the fourth paths and the tier-3 specials.
func _extra_stats() -> String:
	var s := ""
	if clone_of != null:
		s += "   Mirror Self copy: fades when it falls or the wave ends"
	elif summoned:
		s += "   Raised by Necromancy: crumbles when the wave ends"
	if not multiform.is_empty():
		var bodies := 1 + _clones().size()
		s += "   Mirror Self: %d bod%s, %d%% power each" % [bodies, "y" if bodies == 1 else "ies", roundi(_body_share() * 100)]
	if not dash.is_empty():
		s += "   Dash %.0fx%s" % [dash["damage"], " (bowls through)" if dash["through"] else ""]
	if pierce > 0:
		s += "   Arrows hit up to %d%s" % [pierce + 1, ", seeking" if seek else ""]
	if not magnet.is_empty():
		s += "   Blasts magnetize"
	if not echo.is_empty():
		s += "   Arcane burst %d%%" % roundi(echo["damage"] * 100)
	if not fireball.is_empty():
		s += "   Fireballs, burn %.0f/s" % fireball["burn_dps"]
	if not decay.is_empty():
		s += "   Rot %.0f/s" % decay["dps"]
	if not summon.is_empty():
		s += "   Skeletons %d/%d (%.0f HP, %.0f dmg)" % [_minions().size(), int(summon["max"]), summon["hp"], summon["damage"]]
	if not frost_aura.is_empty():
		s += "   Frost aura %s: -%d%% speed" % [Data.ft(frost_aura["radius"]), roundi(frost_aura["slow"] * 100)]
		if frost_aura["dps"] > 0.0:
			s += ", %.0f dmg/s" % frost_aura["dps"]
		if frost_aura["freeze_every"] > 0.0:
			s += ", freezes %.1fs / %.1fs" % [frost_aura["freeze_time"], frost_aura["freeze_every"]]
	if not rage.is_empty():
		s += "   Iron Will below %d%% HP" % roundi(rage["below"] * 100)
	if golden_left > 0.0:
		s += "   GOLDEN %ds" % ceili(golden_left)
	elif not golden.is_empty():
		s += "   Golden in %ds" % ceili(golden_timer)
	if crimson_left > 0.0:
		s += "   CRIMSON AURA %ds" % ceili(crimson_left)
	elif not crimson.is_empty():
		s += "   Aura in %ds" % ceili(crimson_timer)
	if not heal_aura.is_empty():
		s += "   Halo %s: +%s%% HP/s" % [Data.ft(heal_aura["radius"]), _pct(heal_aura["regen"])]
		if heal_aura["defense"] > 0.0:
			s += ", -%d%% dmg taken" % roundi(heal_aura["defense"] * 100)
	if thorns_dps > 0.0:
		s += "   Thorns %.0f/s" % thorns_dps
	if not befuddle.is_empty():
		s += "   Notes confuse %d%% for %.1fs" % [roundi(befuddle[0] * 100), befuddle[1]]
	if confuse_vuln > 0.0:
		s += "   Confused foes +%d%% dmg taken" % roundi(confuse_vuln * 100)
	if not traps.is_empty():
		s += "   Charges %d/%d: %.0f dmg%s" % [my_traps.size(), int(traps["max"]), traps["damage"], ", stun %.0fs" % traps["stun"] if traps["stun"] > 0.0 else ""]
	if not burn.is_empty() and fireball.is_empty():
		s += "   Burn %.0f/s" % burn[0]
	if not rain.is_empty():
		s += "   Fire rain %.0f / %.0fs" % [rain["damage"], rain["cooldown"]]
	if not cluster.is_empty():
		s += "   %d bomblets" % int(cluster["count"])
	if not napalm.is_empty():
		s += "   Napalm %.0f/s" % napalm["dps"]
	if not smite.is_empty():
		s += "   Sears foes %.0f" % smite["damage"]
	if not gems.is_empty():
		s += "   Gems %d%% x%.0f" % [roundi(gems[0] * 100), gems[1]]
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
	if hp <= 0.0 and summoned:
		_crumble()
		return
	if hp <= 0.0:
		hp = 0.0
		# Dies after the difficulty's down time unless it's revived first (in the Tutorial
		# and Freeplay it gets back up then instead).
		down_timer = main.down_time
		dazed = 0.0
		shove_left = 0.0
		rez_target = null
		regen_left = 0.0
		target = null
		combo_left = 0
		offhand_timer = 0.0
		engaged = null
		engaged_id = 0
		volley_left = 0
		beam_charge = 0.0
		surge_left = 0.0
		main.spawn_text(position + Vector2(0, -24), "Wrecked!" if is_emplacement() else "Down!", Color(1, 0.4, 0.35))
		main.sfx("down")


func _process(delta: float) -> void:
	if main.campaign:
		main.credit = xp_kind()   # whatever this unit hurts this frame counts toward its training
	if build_left > 0.0 and down_timer <= 0.0:
		queue_redraw()   # a construction site: nothing works until the Engineer's done
		return
	if summoned and (not main.wave_active or not is_instance_valid(summoner) or summoner.is_queued_for_deletion()
			or (clone_of != null and not summoner.is_active())):
		_crumble()
		return
	hurt = maxf(hurt - delta, 0.0)
	swing = maxf(swing - delta, 0.0)
	goo_timer = maxf(goo_timer - delta, 0.0)
	pose_left = maxf(pose_left - delta, 0.0)
	lance_left = maxf(lance_left - delta, 0.0)
	block_flash = maxf(block_flash - delta, 0.0)
	queue_redraw()
	_animate(delta)
	if down_timer > 0.0:
		# Healers and Medic Bays nearby keep a downed unit alive longer (or, without
		# permadeath, get it up sooner).
		down_timer -= delta / _recovery_aura() if main.permadeath else delta * _recovery_aura()
		if down_timer <= 0.0:
			if main.permadeath:
				main.spawn_text(position + Vector2(0, -24), "Destroyed!" if is_emplacement() else "Fallen!", Color(1, 0.3, 0.3))
				main.add_grave(self)
				if main.selected == self:
					main.selected = null
				main.warriors_changed()
				queue_free()
			else:
				hp = max_hp   # gets back up where it fell
		return
	if dazed > 0.0 or shove_left > 0.0:
		# Knocked flying and seeing stars: slides back, then stands dazed.
		dazed = maxf(dazed - delta, 0.0)
		if shove_left > 0.0:
			shove_left -= delta
			_step_to(position + shove_velocity * delta)
		_separate()
		return
	if dash_left > 0.0:
		_dash_step(delta)
		return
	if not dash.is_empty() and dash.get("chain", false) and _chain_dash():
		return
	if regen_left > 0.0:
		regen_left -= delta
		_mend(max_hp * regen_rate * delta)
	if buff["regen"] > 0.0:
		_mend(max_hp * buff["regen"] * delta)
	_special_update(delta)
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
		if priority == "stay":
			_keep_wards()
		_follow_anchor(delta)   # (a wagon it follows, or its ward)
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
		main.sfx("powerup")

	# Re-pick a target a few times a second, or right away if the current one is gone.
	retarget_timer -= delta
	shun_left = maxf(shun_left - delta, 0.0)
	_follow_anchor(delta)
	if ordered:
		target = null
		if position.distance_to(post) <= RADIUS:
			ordered = false
	elif not _keep_target() or (commit == "reactive" and retarget_timer <= 0.0):
		_set_target(_find_target())
		retarget_timer = 0.3
	# Movement: chase the target (melee closes all the way in, ranged stops at range),
	# otherwise head back to the post.
	if is_emplacement():
		# Never moves; just turns to face what it's shooting at.
		if target != null:
			facing = position.direction_to(target.position)
		else:
			_mend(max_hp * REGEN * delta)
	elif not ordered and _kite(delta):
		pass   # backing off from an enemy that got too close (still shooting)
	elif target != null:
		var gap := _gap_to(target)
		facing = position.direction_to(target.position)
		if not teleport.is_empty() and teleport_timer <= 0.0 and _should_blink(target, gap):
			_blink_to(target)
			gap = _gap_to(target)
		if not blast.is_empty():
			# Spirit users hold at blast range and fire volleys; they still punch anything that closes in.
			var r: float = blast["range"]
			if not _sees(target):
				_chase_move(target.position, gap, delta)   # a wall's in the way: go round it
			elif gap > r:
				_chase_move(target.position, gap - r + 1.0, delta)
		elif is_melee():
			if not dash.is_empty() and run_time >= RUN_BEFORE_DASH and gap > 6.0 and gap <= dash["reach"] and _can_dash(target):
				_start_dash(target)
				return
			if gap > 0.0:
				_chase_move(target.position, gap, delta)
		elif not _sees(target):
			_chase_move(target.position, gap, delta)
		elif gap > attack_range:
			_chase_move(target.position, gap - attack_range + 1.0, delta)
		_watch_chase(gap, delta)
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
			_mend(max_hp * REGEN * delta)

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
	if not dash.is_empty():
		if target != null and _is_valid(target) and _gap_to(target) <= attack_range + 2.0:
			engaged = target
			engaged_id = target.get_instance_id()
		elif engaged_id != 0 and is_instance_valid(engaged) and not engaged.dead \
				and (engaged != target or _gap_to(engaged) > attack_range + 12.0):
			engaged = null   # it walked off from that fight: no chain when that foe falls later
			engaged_id = 0
	# Running time toward a target (for a Swordsman's dash): any stop resets it.
	run_time = run_time + delta if moving and target != null else 0.0
	_separate()


func _victim():
	return target if target != null and _can_strike(target) else _pick(main.get_enemies().filter(_can_strike))


## In reach for this unit's main attack: melee blows can't reach a flyer (a Martial
## Artist's ki can, but its punches can't).
func _can_strike(e) -> bool:
	return _in_range(e) and not (is_melee() and (e.flying or e.gooey and e.resists("physical")))


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
	main.sfx("punch", 0.85 if combo_left == 0 else 1.0 + 0.05 * combo_left)
	v.take_damage(damage * _power())
	_hit_spark(v)
	# Only the finishing hit can knock back, so the combo isn't cut short.
	if combo_left == 0 and randf() < knockback_chance:
		v.apply_knockback(facing * knockback_force)


func _in_combat() -> bool:
	var reach: float = maxf(attack_range, blast.get("range", 0.0)) + 40.0
	return target != null and _is_valid(target) and _gap_to(target) <= reach


# Spirit path: a volley of homing blasts at enemies outside punching reach.
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
	p.splash = blast.get("splash", 0.0)   # Sunburst Volley: every blast explodes
	# Like the punch combo, only the volley's last blast can knock back.
	p.knockback_chance = knockback_chance if volley_left == 0 else 0.0
	p.knockback_force = knockback_force
	p.speed = 520.0
	p.credit = xp_kind()
	p.style = "ki"
	p.school = "ki"
	p.color = KI_COLOR
	main.add_projectile(p)
	main.sfx("ki")
	swing = 0.1
	_hold_pose("punch", COMBO_GAP)


# Secret Arts tier 4: a beam to the edge of the field hitting every enemy along the line.
func _beam_target():
	var r: float = beam.get("range", blast.get("range", 200.0) * 1.3)
	return _pick(main.get_enemies().filter(func(x): return _is_valid(x) and _gap_to(x) <= r and _sees(x)))


func _fire_beam() -> void:
	var e = beam_target if _is_valid(beam_target) else _beam_target()
	if e == null:
		return
	var dir := position.direction_to(e.position)
	var from := position + Vector2(0, -14)
	var to := from + dir * 1200.0
	# The beam stops at the first wall it hits.
	for w in main.paths.shot_walls:
		var hit = Geometry2D.segment_intersects_segment(from, to, w.seg_a(), w.seg_b())
		if hit != null:
			to = hit
	for x in main.get_enemies():
		var closest := Geometry2D.get_closest_point_to_segment(x.position, from, to)
		if closest.distance_to(x.position) <= beam["width"] / 2.0 + x.radius:
			x.take_damage(beam["damage"] * _power(), true, "ki")
	main.spawn_beam(from, to, Color(1.0, 0.85, 0.3), beam["width"])
	main.sfx("beam")
	facing = dir
	swing = 0.15
	_hold_pose("punch", 0.35)


# Secret Arts tier 2: vanish and reappear near a far-off target: right beside it for
# brawlers, or just inside blast range for Spirit users.
## Shadow Step is used once the target is out of range and either far away or already
## past this warrior on its way to the goal.
func _should_blink(e, gap: float) -> bool:
	if zoned() and not _in_zone(_blink_spot(e), 4.0):
		return false   # it would land outside its zone
	var reach: float = attack_range if blast.is_empty() else blast["range"]
	if gap <= reach and _sees(e):
		return false
	# Shadow Step is also the way through walls.
	return gap > teleport["min_dist"] or e.position.y > position.y or not _sees(e)


func _blink_to(e) -> void:
	main.spawn_burst(position, 22, Color(0.9, 0.95, 1.0))
	main.sfx("dash", 1.4)
	position = _clear_of_walls(_blink_spot(e), e.position)
	main.spawn_burst(position, 22, Color(0.9, 0.95, 1.0))
	teleport_timer = teleport["cooldown"]
	route = PackedVector2Array()


## Where a Shadow Step toward `e` lands: between the enemy and the goal (the bottom line),
## right below it for brawlers, or just inside blast range below it for Spirit users.
func _blink_spot(e) -> Vector2:
	var gap_after: float = 2.0 if blast.is_empty() else blast["range"] * 0.8
	var spot: Vector2 = e.position + Vector2(0, RADIUS + e.radius + gap_after)
	spot.y = minf(spot.y, main.CASTLE_Y - RADIUS)
	if spot.distance_to(e.position) < RADIUS + e.radius:
		# Squeezed against the bottom edge: step to the side instead.
		spot.x += (RADIUS + e.radius) * (1.0 if e.position.x < main.FIELD_W / 2.0 else -1.0)
	return spot


## Following something: a few times a second its post moves with it (kept on open ground
## a troop can stand on), so its zone, its orders and its way back all go along. It walks
## there like anywhere else: round terrain, never through it.
func _follow_anchor(delta: float) -> void:
	if anchor == null:
		return
	# Kept until what it follows is gone (a villager saved or lost, a wagon destroyed): a
	# wagon at the end of its stretch isn't a target any more, but the troops stay with it
	# onto the next one.
	if not is_instance_valid(anchor) or anchor.is_queued_for_deletion() or ("dead" in anchor and anchor.dead):
		anchor = null
		return
	anchor_check -= delta
	if anchor_check > 0.0:
		return
	anchor_check = 0.25
	var p: Vector2 = main._clamp_post(anchor.position + anchor_off)
	p = main.paths.open_spot(p)
	if p.distance_to(post) > 6.0:
		post = p
		lost_time = 0.0


## Couldn't find its way back to its post in time: blinks straight there.
func _teleport_home() -> void:
	if anchor != null:
		lost_time = 0.0
		return   # a moving post: it keeps walking after it, it never blinks
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
	for w in main.paths.troop_walls:
		var c := Geometry2D.get_closest_point_to_segment(spot, w.seg_a(), w.seg_b())
		var min_d: float = RADIUS + w.WALL_HALF + 1.0
		if c.distance_to(spot) >= min_d:
			continue
		var n: Vector2 = (w.seg_b() - w.seg_a()).normalized().orthogonal()
		if n.dot(toward - c) < 0.0:
			n = -n
		spot = c + n * min_d
	spot = spot.clamp(Vector2(RADIUS, main.DEPLOY_TOP + RADIUS), Vector2(main.FIELD_W - RADIUS, main.CASTLE_Y - RADIUS))
	return main.paths.open_spot(spot)   # never onto terrain or somewhere troops can't get to


# Secret Arts tier 3: a blinding flash that stuns everything close by.
func _flash() -> bool:
	var r: float = stun["radius"]
	var victims: Array = main.get_enemies().filter(func(x): return _is_valid(x) and position.distance_to(x.position) <= r + x.radius)
	if victims.is_empty():
		return false
	for x in victims:
		x.apply_stun(stun["duration"])
	main.spawn_flash(position, r)
	main.sfx("flash")
	return true


func _gap_to(e) -> float:
	return position.distance_to(e.position) - RADIUS - e.radius


func _is_valid(e) -> bool:
	if e == null or not is_instance_valid(e) or e.dead or (e.flying and not hits_air()) or (e.gooey and not can_hurt(e)):
		return false
	# Nothing reaches into the enemy's spawn area: no one follows them up there or shoots
	# them there (one poking out of it is fair game).
	return e.position.y + e.radius >= main.DEPLOY_TOP


func _find_target():
	if is_emplacement():
		return _pick(main.get_enemies().filter(_in_range))
	if wall_guard:
		return _pick(main.get_enemies().filter(_in_range))
	var all: Array = main.get_enemies().filter(_eligible)
	if main.paths.has_walls() and not shoots_over_walls():
		# Rather go after an enemy on this side of the walls than one it can't get at.
		var seen: Array = all.filter(_sees)
		if not seen.is_empty():
			return _pick(seen)
	return _pick(all)


## Whether it may pick `e`: a valid target it can fight without leaving its zone, and not
## one it just gave up on.
func _eligible(e) -> bool:
	return _is_valid(e) and _engageable(e) and not (shun_left > 0.0 and e.get_instance_id() == shun_id)


## Whether it keeps the target it has. Units that can't move keep it while it's in
## reach; the rest while it's valid and still engageable from their zone (a little slack,
## so an enemy on the edge isn't dropped and picked up over and over). Reactive units
## also look again every 0.3s (in _process); Focused ones only when this says no.
func _keep_target() -> bool:
	if target == null:
		return false
	if is_emplacement() or wall_guard:
		return _in_range(target)
	return _is_valid(target) and _engageable(target, ZONE_SLACK)


func _set_target(e) -> void:
	if e != target:
		chase_best = INF
		chase_time = 0.0
	target = e


## A chase going nowhere (round a wall it can't find a way past, or an enemy that keeps
## its distance): after STALL_TIME without getting closer, give it up for a while.
func _watch_chase(gap: float, delta: float) -> void:
	if target == null or _can_strike(target) or (not blast.is_empty() and gap <= blast["range"]):
		chase_best = INF
		chase_time = 0.0
		return
	if gap < chase_best - 4.0:
		chase_best = gap
		chase_time = 0.0
		return
	chase_time += delta
	if chase_time >= STALL_TIME:
		shun_id = target.get_instance_id()
		shun_left = SHUN_TIME
		_set_target(null)
		retarget_timer = 0.0


# --- Orders: the zone around the post --------------------------------------------------

## Whether its movement is limited to a zone around its post (troops on Hold, Short
## Leash or Guard Area; emplacements and wall guards never move anyway).
func zoned() -> bool:
	return move_mode != "free" and not is_emplacement() and not wall_guard


## How far from its post it may go: 0 on Hold, the zone's size otherwise.
func zone_radius() -> float:
	if move_mode == "hold":
		return 0.0
	return leash.get(move_mode, INF)


func set_leash(r: float) -> void:
	if LEASH_LIMITS.has(move_mode):
		leash[move_mode] = clampf(r, LEASH_LIMITS[move_mode][0], LEASH_LIMITS[move_mode][1])


func _in_zone(p: Vector2, slack := 0.0) -> bool:
	return not zoned() or p.distance_to(post) <= zone_radius() + slack


## The nearest point to `p` it may stand on.
func _zone_clamp(p: Vector2) -> Vector2:
	if not zoned():
		return p
	return post + (p - post).limit_length(zone_radius())


## How far it can reach out from where it stands to fight: its weapon, or its ki blasts.
func _engage_reach() -> float:
	return maxf(attack_range, blast.get("range", 0.0))


## Whether it can fight `e` from somewhere in its zone (always, roaming free).
func _engageable(e, slack := 0.0) -> bool:
	if not zoned():
		return true
	return post.distance_to(e.position) - zone_radius() - RADIUS - e.radius <= _engage_reach() + slack


## Moves toward `p` (at most `max_dist`) to fight, but never out of its zone: the stop
## is pulled back to the zone's edge, where it waits (no stepping back and forth).
func _chase_move(p: Vector2, max_dist: float, delta: float) -> void:
	if not zoned():
		_move_toward(p, max_dist, delta)
		return
	var stop := position + position.direction_to(p) * minf(max_dist, position.distance_to(p))
	var q := _zone_clamp(stop)
	var d := position.distance_to(q)
	if d > 1.5:
		_move_toward(q, d, delta)


func _in_range(e) -> bool:
	if wall_guard:
		return _is_valid(e) and main.powers.in_guard_reach(e)   # a set reach out from the castle wall
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
		"objective":
			# Enemies after an objective first, the nearest to getting at it first of all; then
			# the rest by distance. A little stickiness keeps it from flicking between two.
			return threat(e) * 10000.0 - _gap_to(e) + (600.0 if e == target else 0.0)
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


## How urgently enemy `e` needs stopping for the objectives (the castle, where there is one,
## among them): 0 if it isn't after one, 1 to 2
## the nearer it is to getting at it (2: at it, or in the ground it's taking).
static func threat(e) -> float:
	var g = e.goal
	if g == null and e.main.rules.has_castle() and e.main.rules.guards():
		return 2.0 - clampf((e.main.CASTLE_Y - e.position.y - e.radius) / THREAT_RANGE, 0.0, 1.0)   # the castle's an objective too
	if g == null or not is_instance_valid(g) or not g.is_target():
		return 0.0
	var gap: float = e.position.distance_to(g.position) - (g.zone_r if g.kind == "zone" else g.RADIUS) - e.radius
	return 1.0 + 1.0 - clampf(gap / THREAT_RANGE, 0.0, 1.0)


## The priorities `w` can be given: a Healer's own, or the target priorities on offer.
static func priorities_for_unit(w) -> Array:
	return HEAL_PRIORITIES if w.is_mobile_healer() else priorities_for(w.main)


## The target priorities on offer in this battle.
static func priorities_for(m) -> Array:
	return PRIORITIES + [OBJECTIVE_PRIORITY] if m.rules != null and m.rules.guards() else PRIORITIES


## Takes on another unit's orders (a Mirror Self copy, its original's).
func copy_orders(w) -> void:
	priority = w.priority
	commit = w.commit
	move_mode = w.move_mode
	leash = w.leash.duplicate()
	anchor = w.anchor
	anchor_off = w.anchor_off


func cycle_priority() -> void:
	var list := priorities_for_unit(self)
	priority = list[(list.find(priority) + 1) % list.size()]
	target = null
	retarget_timer = 0.0


func _move_toward(p: Vector2, max_dist: float, delta: float) -> void:
	var step := minf(move_speed * (1.0 + buff["speed"]) * _form("speed") * _goo_factor() * delta, max_dist)
	if wall_guard:
		return   # wall guards hold their posts
	var aim := p
	# Only go the long way round if a wall or an emplacement is in the way of where it
	# means to stop.
	var stop := position + position.direction_to(p) * minf(max_dist, position.distance_to(p))
	if not is_emplacement() and (main.paths.has_troop_walls() or main.paths.has_emplacements() or main.paths.has_terrain()) \
			and _way_blocked(stop, delta):
		aim = _route_step(p, delta)
	_step_to(position + position.direction_to(aim) * step)
	walk += step / 12.0   # swap walk frames every 12px
	moving = step > 0.01


## Whether walls, emplacements or terrain are in the way of walking straight to `stop`.
## On terrain the answer is kept for a moment (it's the costly check, and a few frames'
## walk changes little); everywhere else it's asked fresh each frame, as before.
func _way_blocked(stop: Vector2, delta: float) -> bool:
	if main.paths.terrain.is_empty():
		return main.paths.path_blocked(position, stop, RADIUS + 6.0, true)
	way_check -= delta
	if way_check <= 0.0 or stop.distance_to(way_goal) > 12.0:
		way_check = 0.2
		way_goal = stop
		way_blocked = main.paths.path_blocked(position, stop, RADIUS + 6.0, true)
	return way_blocked


## A step to `to`: straight there on open ground; on terrain, slid along any rock it
## would have walked into (so it never walks into a cliff, only along it).
func _step_to(to: Vector2) -> void:
	if main.paths.terrain.is_empty():
		position = to
		return
	to = position + (to - position) * main.paths.wade_factor(position)   # (slow through a ford)
	position = main.paths.slide(position, to, RADIUS)


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
			or not main.paths.path_blocked(position, route[1], RADIUS + 6.0, true)):
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
	for o in main.rules.objectives():
		# Nobody stands inside a mission objective.
		var off: Vector2 = position - o.position
		var room: float = o.RADIUS + RADIUS
		if (o.is_solid() or (o.is_mover() and o.is_target())) and off.length_squared() < room * room:
			position = o.position + (off.normalized() if off.length() > 0.01 else Vector2.DOWN) * room
	if wall_guard:
		position = post   # standing at its post on the wall
		return
	for w in main.get_warriors():
		if w == self or not w.is_active():
			continue
		var off: Vector2 = position - w.position
		var d := off.length()
		if d < RADIUS * 2.0 and d > 0.01:
			position += off / d * (RADIUS * 2.0 - d) * (1.0 if w.is_emplacement() else 0.5)
	# Walls are solid to troops too (Phase Gates aside).
	for b in main.paths.troop_walls:
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
	# Terrain: put back anything a push left overlapping rock (the safety net; steps
	# themselves slide along it).
	if not main.paths.terrain.is_empty():
		position = main.paths.push_out(position, RADIUS)
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
		main.sfx("slash" if kind == "swordsman" or kind == "skeleton" else "hit", 0.85 if kind == "skeleton" else 1.0)
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
	_shot_sound()
	if data["attack"] == "shell":
		main.spawn_burst(_muzzle(), 14.0, Color(1.0, 0.8, 0.45))


## The sound of this unit's ranged attack.
func _shot_sound() -> void:
	match data["attack"]:
		"arrow":
			main.sfx("bow", 0.85 if kind == "tower" else 1.0)
		"orb":
			main.sfx("fire" if not fireball.is_empty() else "magic")
		"frost":
			main.sfx("frost")
		"shell":
			main.sfx("cannon", 0.8 if mortar else 1.0)
		"flask":
			main.sfx("toss")
		"note":
			main.audio.play_note(instrument_sound())


## A Bard with an unusual spread of upgrades plays a special instrument: a violin
## with two paths at tier 3, a cello with three at tier 2, a harp with every path
## started. "" for the rest (they play their outfit's instrument).
func special_instrument() -> String:
	if kind != "bard":
		return ""
	if _high_paths().size() >= 2:
		return "violin"
	if tiers.count(2) >= 3:
		return "cello"
	if tiers.all(func(t): return t >= 1):
		return "harp"
	return ""


## The Bard's note sound: the instrument it's holding (pipa, mouth instrument, flute
## or drum for its tier-3 outfits; a mix of two plays whichever instrument it shows).
func instrument_sound() -> String:
	var special := special_instrument()
	if special != "":
		return special
	var instrument := ["pluck", "reed", "flute", "drum"]
	var look := _look_path()
	var combo := _combo_sprite()
	if combo != "":
		var src := Sprites.combo_source(combo, "right")
		if src >= 0:
			look = src
	return instrument[look] if look >= 0 else "note"


## An Engineer has finished building this emplacement: it starts working.
func finish_build() -> void:
	build_left = 0.0
	main.spawn_burst(position + Vector2(0, -20), 30.0, Color(1.0, 0.9, 0.6))
	main.spawn_text(position + Vector2(0, -50), "Built!", Color(1.0, 0.9, 0.6))
	main.sfx("upgrade", 1.2)
	main.warriors_changed()


func under_construction() -> bool:
	return build_left > 0.0


## Ranged troops (Healers too) keep their distance: when an enemy that can hurt them gets close,
## they step back away from it (leaning toward their post) and keep shooting, until
## there's room again. Melee troops (Martial Artists too, ki blasts and all, since they
## can still brawl) stand and fight, except against a Slime their blows can't hurt:
## that they back away from too. Returns whether it's backing off this frame.
func _kite(delta: float) -> bool:
	if wall_guard or move_mode == "hold":
		return false   # (on Hold it stands its ground)
	var brawler := is_melee() or summoned or clone_of != null
	if brawler and main.Enemy.slimes_out <= 0:
		return false   # only Slimes make a brawler back off
	var threat = null
	var near := INF
	for e in main.enemies_near(position, KITE_CLEAR + RADIUS + 30.0):
		if e.dead or not e.fights or not e.bomb.is_empty() or e.stun_timer > 0.0 or e.freeze_timer > 0.0:
			continue
		if brawler and not e.resists("physical"):
			continue
		var gap: float = _gap_to(e)
		if gap < near:
			near = gap
			threat = e
	if threat == null or near > (KITE_CLEAR if kiting else KITE_GAP):
		kiting = false
		return false
	# Away from the threat, drawn a little back toward its post; within the deployment area.
	var away: Vector2 = (position - threat.position).normalized()
	var home := position.direction_to(post) if position.distance_to(post) > 4.0 else Vector2.ZERO
	var dir := (away + home * 0.35).normalized()
	var dest: Vector2 = (position + dir * 60.0).clamp(Vector2(RADIUS, main.DEPLOY_TOP + RADIUS), Vector2(main.FIELD_W - RADIUS, main.CASTLE_Y - RADIUS))
	if not main.paths.terrain.is_empty():
		# Worked out a few times a second (it tries several spots), and kept between.
		retreat_check -= get_process_delta_time()
		if retreat_check <= 0.0 or retreat_to == Vector2.INF or position.distance_to(retreat_to) < 8.0:
			retreat_check = 0.25
			retreat_to = _retreat_spot(dir, threat)
		dest = retreat_to
	if zoned():
		dest = _zone_clamp(dest)   # backs off only as far as its zone allows
		if not main.paths.terrain.is_empty() and not main.paths.troop_can_stand(dest):
			dest = position
	if position.distance_to(dest) < 10.0:
		kiting = false   # cornered: stand and fight
		return false
	kiting = true
	if target != null and _is_valid(target):
		facing = position.direction_to(target.position)
	_move_toward(dest, position.distance_to(dest), delta)
	return true


## On terrain: somewhere to back off to, away from `threat`, that's open ground troops can
## reach with a clear straight walk there (so it never cuts across rock or backs into a
## pocket it can't get out of). Tries straight away first, then turning further and
## further aside; if nothing works it's cornered and stays put.
func _retreat_spot(dir: Vector2, threat) -> Vector2:
	var paths = main.paths
	var now := position.distance_to(threat.position)
	for turn in [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5]:
		for reach in [60.0, 36.0]:
			var q: Vector2 = (position + dir.rotated(turn) * reach).clamp(Vector2(RADIUS, main.DEPLOY_TOP + RADIUS), Vector2(main.FIELD_W - RADIUS, main.CASTLE_Y - RADIUS))
			if q.distance_to(threat.position) <= now + 4.0:
				continue   # not actually getting away
			if paths.troop_can_stand(q) and not paths.segment_blocked(position, q, RADIUS):
				return q
	return position


## Where projectiles leave from: the hands, or an emplacement's archer or muzzle.
func _muzzle() -> Vector2:
	var f := signf(facing.x) if absf(facing.x) > 0.2 else flip
	match kind:
		"tower":
			return position + Vector2(10.0 * f, -36)   # the archer on top
		"magetower", "frosttower":
			return position + Vector2(10.0 * f, -42)   # the staff of the Mage or Frost Witch on top
		"cannon":
			return position + Vector2(14.0 * f, -33)   # the mouth of the (bigger) cannon
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
	p.credit = xp_kind()
	p.style = data["attack"]
	p.school = school()
	p.color = data["color"]
	p.poison = poison
	p.source = get_instance_id()
	p.cloud = cloud
	p.corrode = corrode
	p.melt = melt
	p.burst = burst
	p.pierce = pierce
	p.seek = seek
	p.burn = burn
	p.cluster = cluster
	p.napalm = napalm
	p.befuddle = befuddle
	p.confuse_vuln = confuse_vuln
	p.high_arc = mortar
	if data["attack"] == "orb":
		# The Mage's blast changes with each path taken to tier 3.
		p.magnet = magnet
		p.echo = echo
		p.decay = decay
		if not fireball.is_empty():
			p.style = "fireball"
			p.splash = splash * fireball["splash"]
			p.burn = [fireball["burn_dps"], fireball["burn_time"]]
	# Tier-3 looks carry over to some attacks.
	var look := _look_path()
	if kind == "archer":
		p.grade = tiers[0]   # her Damage path upgrades the arrows themselves
	if kind == "archer" and look == 1:
		p.style = "crossbow"
	elif (kind == "mage" or kind == "magetower") and look >= 0:
		p.color = _staff_color() if kind == "mage" and _high_paths().size() >= 2 else MAGE_ORB_COLORS[look]
	if data["attack"] == "orb" and not decay.is_empty() and look != 3 and fireball.is_empty():
		p.color = p.color.lerp(MAGE_ORB_COLORS[3], 0.5)
	elif kind == "alchemist" and look >= 0:
		p.color = FLASK_COLORS[look]
	main.add_projectile(p)


## A quick flash where a melee blow lands.
func _hit_spark(e) -> void:
	if is_instance_valid(e):
		main.spawn_burst(e.position + (position - e.position).normalized() * e.radius * 0.6, 9.0, Color(1, 1, 0.85))


# Swordsman Damage tier 3+: the swing carries on through other enemies in a wide arc
# (tier 4: all the way round, a spin attack).
func _sweep(main_target, hit: float) -> void:
	var half := deg_to_rad(cleave["arc"]) / 2.0
	for x in main.get_enemies():
		if x == main_target or not _is_valid(x) or x.flying or _gap_to(x) > attack_range + cleave["reach"]:
			continue
		if half >= PI or absf(angle_difference(facing.angle(), position.direction_to(x.position).angle())) <= half:
			x.take_damage(hit)


# Swordsman Speed tier 3+: the second blade follows up a moment after each attack.
func _offhand_strike() -> void:
	var v = _victim()
	if v == null:
		return
	facing = position.direction_to(v.position)
	swing = 0.15
	_hold_pose("strike2", 0.15)
	main.sfx("slash", 1.15)
	v.take_damage(damage * dual * _power())
	_hit_spark(v)


# Mage Storm path: lightning that jumps from enemy to enemy.
func _cast_chain() -> bool:
	var cur = _pick(main.get_enemies().filter(_in_range))
	if cur == null:
		return false
	var hit := []
	var points := PackedVector2Array([_muzzle() if kind == "magetower" else position + Vector2(0, -24)])
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
		e.take_damage(chain["damage"] * _power(), true, "magic")
		if not magnet.is_empty() and not e.dead:
			e.charge(3.0)   # Thunderhead: lightning-struck foes get dragged in by the next blast
	main.spawn_bolt(points, Color(0.7, 0.85, 1.0))
	main.sfx("zap")
	swing = 0.15
	return true


# Mage Fire path: rapid flame puffs that set the target burning.
func _breathe() -> bool:
	var e = _pick(main.get_enemies().filter(_in_range))
	if e == null:
		return false
	facing = position.direction_to(e.position)
	e.take_damage(breath["damage"] * _power(), true, "magic")
	e.apply_burn(breath["burn_dps"], breath["burn_time"])
	main.spawn_flame(position + facing * 16 + Vector2(0, -16), e.position)
	main.sfx("flame")
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
	main.spawn_beam(_muzzle() if kind == "magetower" else position + Vector2(0, -24), best.position, Color(1.0, 0.5, 0.95))
	main.sfx("lance")
	best.take_damage(lance["damage"] * _power(), true, "magic")
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
	if _kite(delta):
		# Backing off from an enemy, like the other ranged troops; still heals (or keeps
		# channelling a revive) on anyone already within reach, but won't close in.
		var downed_near = _pick_downed()
		if downed_near != null and downed_near == rez_target and _ally_gap(downed_near) <= attack_range:
			_rez_step(downed_near, delta)
		else:
			var hurt_near = _pick_hurt()
			if hurt_near != null and cd_timer <= 0.0 and _ally_gap(hurt_near) <= attack_range:
				cd_timer = cooldown
				_heal(hurt_near)
		return
	var c := care()
	var downed = null
	var hurt = null
	if c == "stay":
		# Its wards first; anyone else only once it's with them, and only if it can reach
		# them from there.
		downed = _pick_downed(wards)
		hurt = _pick_hurt(wards)
		var with_them := position.distance_to(post) <= attack_range * 0.5 + 20.0
		if downed == null and with_them:
			downed = _within_reach(_pick_downed())
		if hurt == null and with_them:
			hurt = _within_reach(_pick_hurt())
	else:
		downed = _pick_downed()
		hurt = _pick_hurt()
	var order := ["heal", "revive"] if c == "heal" else ["revive", "heal"]
	for act in order:
		if act == "revive" and downed != null:
			if downed != rez_target:
				rez_target = downed
				rez_progress = 0.0
			_go_within_reach(downed, delta)
			if _ally_gap(downed) <= attack_range:
				_rez_step(downed, delta)
			return
		if act == "heal" and hurt != null:
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
		_mend(max_hp * REGEN * delta)


## Channels a revival on a downed ally; it gets up once the revive time is done.
func _rez_step(downed, delta: float) -> void:
	rez_progress += delta
	if rez_progress >= _revive_time():
		downed.revived(1.0 if revive.get("full", false) else data["revive_hp"])
		main.earn_xp(xp_kind(), 1.0, "revive")
		main.spawn_beam(position + Vector2(0, -24), downed.position, Color(1, 1, 0.7), 14.0)
		main.sfx("revive")
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
			z.credit = xp_kind()
			z.radius = r
			z.slow = sp["slow"]
			z.life = sp["duration"]
			z.dps = thorns_dps
			z.position = at
			main.add_projectile(z)
			main.spawn_text(at + Vector2(0, -30), "Thornwild" if thorns_dps > 0.0 else "Overgrowth", Color(0.5, 0.9, 0.4))
		"vines":
			for x in caught:
				if not x.flying:   # vines can't catch what's in the air
					x.apply_root(sp["duration"])
					if thorns_dps > 0.0:
						x.apply_thorns(thorns_dps, sp["duration"] * x.cc_mult + 0.5)
			main.spawn_burst(at, r, Color(0.35, 0.75, 0.25))
			main.spawn_text(at + Vector2(0, -30), "Vine Snare", Color(0.4, 0.85, 0.3))
		"tornado":
			for x in caught:
				x.apply_knockback(Vector2(randf_range(-20, 20), -sp["push"]))
			main.spawn_tornado(at, r)
			main.spawn_text(at + Vector2(0, -30), "Tornado!", Color(0.85, 0.9, 0.95))
		"confuse":
			for x in caught:
				x.apply_confuse(sp["duration"], confuse_vuln)
			main.spawn_burst(at, r, Color(0.8, 0.45, 1.0))
			main.spawn_text(at + Vector2(0, -30), "Confusion!", Color(0.85, 0.5, 1.0))
	main.sfx("spell")
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
				var amount := maxi(1, roundi(damage))
				var gem: bool = not gems.is_empty() and randf() < gems[0]
				if gem:
					amount = roundi(amount * gems[1])
				main.gold += amount
				main.earn_xp(xp_kind(), amount, "gold")
				swing = 0.15
				main.sfx("gem" if gem else "coin")
				if gem:
					main.spawn_text(position + Vector2(0, -44), "Gem! +%dg" % amount, Color(0.55, 0.95, 1.0))
					main.spawn_burst(position + Vector2(0, -20), 18.0, Color(0.55, 0.95, 1.0))
				else:
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
				patients += _villagers().filter(func(v): return position.distance_to(v.position) <= attack_range + RADIUS)   # (villagers passing by too)
				if patients.any(func(w): return w.hp < w.max_hp):
					cd_timer = cooldown
					swing = 0.15
					for w in patients:
						if w.hp < w.max_hp:
							main.spawn_burst(w.position, 16.0, Color(0.55, 1.0, 0.55))   # reaches them wherever they are
						main.earn_xp(xp_kind(), w.receive_heal(damage * _power(), regen_grant), "heal")
					main.spawn_burst(position, attack_range + RADIUS, Color(0.55, 1.0, 0.55))
					main.sfx("heal", 0.8)
			# Consecration: the pulse sears enemies in its radius too.
			smite_timer = maxf(smite_timer - delta, 0.0)
			if not smite.is_empty() and smite_timer <= 0.0:
				var foes: Array = main.get_enemies().filter(func(e): return position.distance_to(e.position) <= attack_range + RADIUS + e.radius)
				if not foes.is_empty():
					smite_timer = cooldown
					swing = 0.15
					for e in foes:
						e.take_damage(smite["damage"] * _power(), true, "magic")
						if e.dead:
							continue
						if smite["slow"] > 0.0:
							e.apply_slow(smite["slow"], 2.0)
						if smite["stun"] > 0.0:
							e.apply_stun(smite["stun"])
					main.spawn_burst(position, attack_range + RADIUS, Color(1.0, 0.95, 0.55))
					main.sfx("flash", 0.7)
		"aura":
			# Buffs are read by the units around it (see _update_buffs). In a campaign
			# wave, each ally it covers trains it a little, counted once a second.
			if main.campaign and main.wave_active:
				aura_tick -= delta
				if aura_tick <= 0.0:
					aura_tick = 1.0
					main.earn_xp(xp_kind(), main.get_warriors().filter(func(w): return w != self and w.is_active() and not w.is_emplacement() and covers(w)).size(), "aura")
	if target == null:
		_mend(max_hp * REGEN * delta)


## Gold paid out by a Gold Mine when a wave ends: its wave bonus, plus `extra` (its
## Treasury's interest, worked out by main).
func wave_payout(extra: int) -> int:
	if not is_active() or data["attack"] != "mine":
		return 0
	var amount := roundi(wave_bonus) + extra
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


func _ally_gap(w) -> float:
	return position.distance_to(w.position) - RADIUS * 2.0


func _go_within_reach(w, delta: float) -> void:
	if w != self:
		facing = position.direction_to(w.position)
	var gap := _ally_gap(w)
	if gap > attack_range:
		_chase_move(w.position, gap - attack_range + 1.0, delta)


## Whether a Healer may go to `w`: it can reach it from its zone (always, roaming free).
func _ally_in_zone(w) -> bool:
	return not zoned() or post.distance_to(w.position) - zone_radius() - RADIUS * 2.0 <= attack_range


func _revive_time() -> float:
	return data["revive_time"] / revive.get("rez_speed", 1.0)


## `who` if it's within this Healer's reach right now, else null.
func _within_reach(who):
	return who if who != null and _ally_gap(who) <= attack_range else null


## Downed ally to revive: the one closest to dying (Hard) or to this healer (Normal);
## among `pool` only, if one's given.
func _pick_downed(pool: Array = []):
	var best = null
	var best_score := INF
	for w in (pool if not pool.is_empty() else main.get_warriors()):
		if w == self or w.is_active() or w.is_queued_for_deletion() or not _ally_in_zone(w):
			continue
		var score: float = w.down_timer * 100.0 if main.permadeath else position.distance_to(w.position)
		if w == rez_target:
			score -= 50.0   # don't abandon a revival halfway
		if score < best_score:
			best_score = score
			best = w
	return best


## The ally (or villager) with the lowest share of its health left; among `pool` only, if
## one's given.
func _pick_hurt(pool: Array = []):
	var best = null
	var best_frac := 0.999
	var who: Array = pool if not pool.is_empty() else main.get_warriors() + _villagers()
	for w in who:
		if not w.is_active() or not w.is_target() or not _ally_in_zone(w):
			continue
		var frac: float = w.hp / w.max_hp
		if frac < best_frac:
			best_frac = frac
			best = w
	return best


## The villagers on the field (Evacuation): a Healer mends them too.
func _villagers() -> Array:
	return main.rules.objectives().filter(func(o): return o.kind == "civilian" and o.is_target()) if main.rules.guards() else []


func _heal(w) -> void:
	swing = 0.15
	var from := position + Vector2(0, -24)
	main.spawn_beam(from, w.position, Color(0.55, 1.0, 0.55), 8.0)
	main.sfx("heal")
	var healed: float = w.receive_heal(damage * _power(), regen_grant)
	if not heal_area.is_empty():
		var r: float = heal_area[0]
		for x in main.get_warriors() + _villagers():
			if x != w and x.is_active() and x.position.distance_to(w.position) <= r:
				healed += x.receive_heal(damage * _power() * heal_area[1], regen_grant)
		main.spawn_burst(w.position, r, Color(0.55, 1.0, 0.55))
	main.earn_xp(xp_kind(), healed, "heal")


## Healed by `amount`; returns how much it actually mended (for the healer's training).
func receive_heal(amount: float, regen: Array) -> float:
	if not is_active():
		return 0.0
	var before := hp
	_mend(amount)
	if hp - before >= 1.0:
		main.spawn_text(position + Vector2(randf_range(-8, 8), -40), "+%d" % roundi(hp - before), Color(0.5, 1.0, 0.5))
	if not regen.is_empty():
		regen_rate = maxf(regen_rate if regen_left > 0.0 else 0.0, regen[0])
		regen_left = maxf(regen_left, regen[1])
	return hp - before


## Healing that tops up to full but never cuts back overheal.
func _mend(amount: float) -> void:
	hp = maxf(hp, minf(max_hp, hp + amount))


## Brought back by a Healer, with this share of max HP.
func revived(frac: float) -> void:
	hp = max_hp * frac
	down_timer = 0.0
	main.spawn_text(position + Vector2(0, -40), "Revived!", Color(1, 1, 0.6))
	main.spawn_burst(position, 30, Color(1, 1, 0.7))


## Downed: how much more slowly this unit bleeds out (or, in the Tutorial and Freeplay,
## how much sooner it gets up) with Renewal healers, a Seraph's Halo or a Medic Bay's
## Field Hospital nearby. 1 = no help.
func _recovery_aura() -> float:
	var rate := 1.0
	for w in main.get_warriors():
		if w == self or not w.is_active() or w.build_left > 0.0:
			continue
		if not w.revive.is_empty() and (w.covers(self) if w.is_support() else w._ally_gap(self) <= w.attack_range):
			rate = maxf(rate, w.revive["aura"])
		if w.aura.has("recover") and w.covers(self):
			rate = maxf(rate, 1.0 + w.aura["recover"])
		if not w.heal_aura.is_empty() and w.heal_aura["recover"] > 0.0 and w.position.distance_to(position) <= w.heal_aura["radius"] + RADIUS:
			rate = maxf(rate, 1.0 + w.heal_aura["recover"])
	return rate


# --- Fourth-path specials ---------------------------------------------------

## Abilities that tick on their own: auras, forms, summons, traps and fire rain.
func _special_update(delta: float) -> void:
	if not frost_aura.is_empty():
		_frost_aura_step(delta)
	if not heal_aura.is_empty():
		_heal_aura_step(delta)
	if not crimson.is_empty() or not golden.is_empty():
		_forms_step(delta)
	if not summon.is_empty():
		_summon_step(delta)
	if not multiform.is_empty() and clone_of == null:
		_multiform_step(delta)
	if not traps.is_empty():
		_trap_step(delta)
	if not rain.is_empty():
		rain_timer = maxf(rain_timer - delta, 0.0)
		if rain_timer <= 0.0:
			var spot = _spell_spot(rain["radius"])
			if spot != null:
				rain_timer = rain["cooldown"]
				_rain_on(spot.position)


## Frost Aura: everything close is slowed and chilled, and now and then frozen solid.
func _frost_aura_step(delta: float) -> void:
	var r: float = frost_aura["radius"]
	frost_tick -= delta
	aura_freeze_timer = maxf(aura_freeze_timer - delta, 0.0)
	if frost_tick > 0.0:
		return
	frost_tick = 0.25
	var inside: Array = main.get_enemies().filter(func(e): return position.distance_to(e.position) <= r + RADIUS + e.radius)
	for e in inside:
		e.apply_slow(frost_aura["slow"], 0.4)
		e.ice_over()
		if frost_aura["dps"] > 0.0:
			e.take_damage(frost_aura["dps"] * 0.25 * _power(), false, "ice")
	if frost_aura["freeze_every"] > 0.0 and aura_freeze_timer <= 0.0 and not inside.is_empty():
		aura_freeze_timer = frost_aura["freeze_every"]
		for e in inside:
			if not e.dead:
				e.apply_freeze(frost_aura["freeze_time"])
		main.spawn_burst(position, r + RADIUS, Color(0.75, 0.95, 1.0))
		main.sfx("freeze")


## Halo: allies close by mend a little every moment.
func _heal_aura_step(delta: float) -> void:
	heal_tick -= delta
	if heal_tick > 0.0:
		return
	heal_tick = 0.25
	var r: float = heal_aura["radius"] + RADIUS
	for w in main.get_warriors():
		if w.is_active() and w.position.distance_to(position) <= r and w.hp < w.max_hp:
			w._mend(w.max_hp * heal_aura["regen"] * 0.25)


## Power path: the crimson aura and golden form flare up once it's fighting.
func _forms_step(delta: float) -> void:
	crimson_timer = maxf(crimson_timer - delta, 0.0)
	golden_timer = maxf(golden_timer - delta, 0.0)
	crimson_left = maxf(crimson_left - delta, 0.0)
	golden_left = maxf(golden_left - delta, 0.0)
	var fighting := _in_combat()
	if not golden.is_empty() and golden_timer <= 0.0 and fighting:
		golden_left = golden["duration"]
		golden_timer = golden["cooldown"]
		main.spawn_text(position + Vector2(0, -50), "Golden Ascension!", Color(1.0, 0.88, 0.3))
		main.sfx("powerup", 1.25)
		main.spawn_flash(position + Vector2(0, -16), 46.0)
	if not crimson.is_empty() and crimson_timer <= 0.0 and fighting:
		crimson_left = crimson["duration"]
		crimson_timer = crimson["cooldown"]
		main.spawn_text(position + Vector2(0, -64), "Crimson Aura!", Color(1.0, 0.3, 0.25))
		main.sfx("powerup", 0.8)
		main.spawn_burst(position + Vector2(0, -16), 40.0, Color(1.0, 0.25, 0.2))
	if crimson_left > 0.0:
		# The aura strains the body (golden or not): it burns health, but never knocks itself out.
		hp = maxf(1.0, hp - max_hp * crimson["drain"] * delta)


## Necromancy: raise a skeleton now and then while a wave is on.
func _summon_step(delta: float) -> void:
	if not main.wave_active:
		summon_timer = minf(summon_timer, 2.0)
		return
	summon_timer -= delta
	if summon_timer > 0.0 or main.get_enemies().is_empty():
		return
	summon_timer = summon["cooldown"]
	if _minions().size() < int(summon["max"]):
		var side := Vector2(randf_range(-1.0, 1.0), randf_range(0.2, 1.0)).normalized()
		raise_skeleton(position + side * (RADIUS * 2.0 + 4.0))


## Mirror Self: once fighting in a wave, split off copies (again a while after one falls).
func _multiform_step(delta: float) -> void:
	if not main.wave_active:
		multiform_timer = 0.0
		return
	multiform_timer = maxf(multiform_timer - delta, 0.0)
	if multiform_timer > 0.0 or not _in_combat() or _clones().size() >= int(multiform["copies"]):
		return
	multiform_timer = multiform["cooldown"]
	var side := Vector2(-facing.y, facing.x) if facing != Vector2.ZERO else Vector2.RIGHT
	var spot := _clear_of_walls(_zone_clamp(position + side * RADIUS * 2.2), position)   # (inside its zone)
	var w = get_script().new()
	w.tiers = tiers.duplicate()
	w.last_path = last_path
	w.summoned = true
	w.summoner = self
	w.clone_of = self
	w.setup(kind, data, main, post)
	w.multiform = {}   # a copy can't split again
	w.max_hp *= multiform["hp"]
	w.hp = w.max_hp
	w.position = spot
	w.priority = priority
	w.copy_orders(self)
	main.add_summon(w)
	main.spawn_burst(position, 26.0, Color(0.7, 0.9, 1.0))
	main.spawn_burst(spot, 26.0, Color(0.7, 0.9, 1.0))
	main.spawn_text(position + Vector2(0, -50), "Mirror Self!", Color(0.75, 0.9, 1.0))
	main.sfx("flash", 1.3)


func _minions() -> Array:
	return main.get_warriors().filter(func(w): return w.summoned and w.summoner == self)


## A skeleton claws its way up at `at`.
func raise_skeleton(at: Vector2) -> void:
	var d: Dictionary = Data.SKELETON.duplicate()
	d["hp"] = summon["hp"]
	d["damage"] = summon["damage"]
	d["armor"] = summon["armor"]
	var w = get_script().new()
	w.summoned = true
	w.summoner = self
	var spot := _clear_of_walls(at, position)
	w.setup("skeleton", d, main, spot)
	w.position = spot
	w.priority = priority
	w.commit = commit   # (a skeleton roams free from where it rose)
	main.add_summon(w)
	main.spawn_burst(spot, 20.0, Color(0.55, 0.95, 0.45))
	main.spawn_burst(spot, 12.0, Color(0.9, 0.88, 0.8))
	main.sfx("rise")


## Rotting Touch: an enemy that died rotting rises as a skeleton, if there's room.
func raise_from_corpse(at: Vector2) -> void:
	if summon.is_empty() or decay.is_empty() or not main.wave_active:
		return
	if _minions().size() >= int(summon["max"]):
		return
	raise_skeleton(at)
	main.spawn_text(at + Vector2(0, -30), "Rise!", Color(0.55, 0.95, 0.45))


## A skeleton falls apart (or a Mirror Self copy fades out, its power going back to the
## real fighter): when it's beaten, when the wave ends, or when its maker is gone.
func _crumble() -> void:
	if is_queued_for_deletion():
		return
	if clone_of != null:
		main.spawn_burst(position, 22.0, Color(0.7, 0.9, 1.0))
		if is_instance_valid(clone_of) and clone_of.is_active():
			main.spawn_beam(position + Vector2(0, -16), clone_of.position + Vector2(0, -16), Color(0.7, 0.9, 1.0), 6.0)
			clone_of.multiform_timer = clone_of.multiform["cooldown"]   # splits again a while after losing it
		main.warriors_changed()
		queue_free()
		return
	main.spawn_burst(position, 18.0, Color(0.9, 0.88, 0.8))
	main.sfx("crumble", 1.3)
	if main.selected == self:
		main.selected = null
	main.warriors_changed()
	queue_free()


## Trapcraft: drops a charge every so often while walking.
func _trap_step(delta: float) -> void:
	my_traps = my_traps.filter(func(t): return is_instance_valid(t) and not t.is_queued_for_deletion())
	if not moving:
		return
	trap_timer -= delta
	if trap_timer > 0.0:
		return
	for t in my_traps:
		if t.position.distance_to(position) < 30.0:
			return   # already one here
	trap_timer = traps["every"]
	while my_traps.size() >= int(traps["max"]):
		my_traps.pop_front().queue_free()   # the oldest is taken up again
	var t := Trap.new()
	t.main = main
	t.damage = traps["damage"] * _power()
	t.radius = traps["radius"]
	t.stun = traps["stun"]
	t.source = get_instance_id()
	t.credit = xp_kind()
	if traps["brew"]:
		t.poison = poison
		t.corrode = corrode
	t.position = position + Vector2(0, RADIUS * 0.6)
	main.add_projectile(t)
	my_traps.append(t)


## Fire Rain: a volley of flaming arrows on a spot.
func _rain_on(at: Vector2) -> void:
	var r: float = rain["radius"]
	for e in main.get_enemies():
		if e.position.distance_to(at) <= r + e.radius:
			e.take_damage(rain["damage"] * _power())
			if not e.dead and not burn.is_empty():
				e.apply_burn(burn[0], burn[1])
	main.spawn_area("rain", at, r)
	main.sfx("rain")
	swing = 0.15


## Charge: a dash needs a clear run at the target.
func _can_dash(e) -> bool:
	return _is_valid(e) and not e.flying and not main.paths.path_blocked(position, e.position, RADIUS) \
			and _in_zone(e.position - position.direction_to(e.position) * (RADIUS + e.radius), 4.0)


func _start_dash(e) -> void:
	dash_target = e
	dash_hit = []
	var dir := position.direction_to(e.position)
	dash_to = e.position - dir * (RADIUS + e.radius)
	dash_left = DASH_TIME
	facing = dir
	run_time = 0.0
	main.spawn_burst(position + Vector2(0, RADIUS), 14.0, Color(0.75, 0.68, 0.55))
	main.sfx("dash")


## Mid-dash: rushes in, bowling over anything on the way (Unstoppable), then strikes.
func _dash_step(delta: float) -> void:
	var left := dash_left
	dash_left = maxf(dash_left - delta, 0.0)
	_step_to(position.lerp(dash_to, minf(delta / left, 1.0)))
	walk += 0.5
	moving = true
	if dash["through"]:
		for x in main.get_enemies():
			if x == dash_target or dash_hit.has(x) or x.flying or position.distance_to(x.position) > RADIUS + x.radius + 4.0:
				continue
			dash_hit.append(x)
			x.take_damage(damage * dash["damage"] * _power())
			if not x.dead and dash["stun"] > 0.0:
				x.apply_stun(dash["stun"])
			_hit_spark(x)
	if dash_left > 0.0:
		return
	var e = dash_target
	dash_target = null
	if _is_valid(e):
		facing = position.direction_to(e.position)
		swing = 0.15
		_hold_pose("strike", 0.2)
		lance_left = 0.2   # (the blow is the spear's)
		e.take_damage(damage * dash["damage"] * _power())
		if not e.dead and dash["stun"] > 0.0:
			e.apply_stun(dash["stun"])
		_hit_spark(e)
		main.spawn_burst(e.position, 26.0, Color(1.0, 0.9, 0.6))
		main.sfx("slash", 0.8)
		cd_timer = cooldown / _rate()
		engaged = e   # if that blow felled it, Unstoppable chains on next frame
		engaged_id = e.get_instance_id()
	_separate()


## Unstoppable: the foe it was fighting has fallen, so it dashes straight on to the
## next one in reach (no run-up needed). True if it set off.
func _chain_dash() -> bool:
	# (A freed enemy compares equal to null, so "was fighting" is kept by its id.)
	if engaged_id == 0 or (is_instance_id_valid(engaged_id) and not instance_from_id(engaged_id).dead):
		return false
	engaged = null
	engaged_id = 0
	var next = _pick(main.get_enemies().filter(func(x): return _can_dash(x) and _gap_to(x) > 6.0 and _gap_to(x) <= dash["reach"]))
	if next == null:
		return false
	target = next
	_start_dash(next)
	main.spawn_text(position + Vector2(0, -44), "Chain!", Color(1.0, 0.85, 0.4))
	return true


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


# --- The Knight's spear (Charge tier 3) ------------------------------------------
# A Knight with Charge at tier 3 is a spear knight. With Damage or Blades at tier 3 as
# well, he fights with the axe or the two swords, and the spear rides on his back; when
# he runs at a foe to charge, it comes down level and the axe (or the swords) go on his
# back instead, till the blow that ends the dash is struck.

## Whether his spear is out: the run-up to a charge, the dash and the blow at its end.
func _lance_out() -> bool:
	return kind == "swordsman" and tiers[3] >= 3 and not dash.is_empty() \
			and (dash_left > 0.0 or lance_left > 0.0 or run_time >= LANCE_AFTER)


## An axe or two swords in hand, beside Charge: the spear is carried on his back.
func _spear_on_back() -> bool:
	return kind == "swordsman" and tiers[3] >= 3 and (tiers[0] >= 3 or tiers[1] >= 3)


## His look with the spear out: his own, if he carries it already; else the same mixed
## armor with the spear in his hand (and the axe or swords on his back).
func _lance_look(look: Dictionary) -> Dictionary:
	if not _spear_on_back():
		return look
	if not look.has("lance"):
		var high := _high_paths()
		var spear := Sprites.combo_forced(kind, high[0], high[1], {"right": 3, "left": "body"}, look["name"] + "_lance")
		look["lance"] = {"name": spear, "layers": look["layers"], "tag": look["tag"], "recolor": look["recolor"],
				"frames": Sprites.frames(spear, look["recolor"], look["tag"], look["layers"]), "poses": {}}
	return look["lance"]


## What's slung on his back right now: "spear", "axe", "swords" or "".
func back_weapon() -> String:
	if not _spear_on_back():
		return ""
	if not _lance_out():
		return "spear"
	return "axe" if tiers[0] >= 3 else "swords"


## The slung weapon, drawn before the body so only what sticks out past it shows.
## `top_left` is the sprite's top-left corner, in the body's own (unflipped) space.
func _draw_back_weapon(what: String, top_left: Vector2) -> void:
	var px := func(x: float, y: float) -> Vector2: return top_left + Vector2(x + 0.5, y + 0.5) * SCALE
	var wood := Color(0.58, 0.4, 0.22)
	var steel := Color(0.85, 0.88, 0.95)
	var gold := Color(0.95, 0.78, 0.3)
	var pole := func(a: Vector2, b: Vector2, col: Color) -> void:
		draw_line(a, b, OUTLINE_COLOR, SCALE * 3.0)
		draw_line(a, b, col, SCALE)
	match what:
		"spear":
			var butt: Vector2 = px.call(11.5, 13.0)
			var top: Vector2 = px.call(0.5, -1.5)
			pole.call(butt, top, wood)
			var d := butt.direction_to(top)
			var n := d.orthogonal()
			var blade := PackedVector2Array([top + d * SCALE * 3.0, top + n * SCALE * 1.2, top - d * SCALE * 0.5, top - n * SCALE * 1.2])
			draw_colored_polygon(PackedVector2Array(Array(blade).map(func(q): return top + (q - top) * 1.6)), OUTLINE_COLOR)
			draw_colored_polygon(blade, steel)
		"axe":
			var low: Vector2 = px.call(10.0, 12.5)
			var high: Vector2 = px.call(2.5, -0.5)
			pole.call(low, high, wood)
			var head := PackedVector2Array([px.call(2.0, -1.5), px.call(-0.8, -2.5), px.call(-1.5, 2.0), px.call(1.5, 1.5)])
			var mid := Vector2.ZERO
			for q in head:
				mid += q / 4.0
			draw_colored_polygon(PackedVector2Array(Array(head).map(func(q): return mid + (q - mid) * 1.35)), OUTLINE_COLOR)
			draw_colored_polygon(head, steel)
		"swords":
			for blade in [[px.call(0.0, -3.0), px.call(9.5, 11.0)], [px.call(11.5, -3.0), px.call(2.0, 11.0)]]:
				var hilt: Vector2 = blade[0]
				var tip: Vector2 = blade[1]
				pole.call(hilt, tip, steel)
				var d := hilt.direction_to(tip)
				var guard := hilt + d * SCALE * 1.5
				draw_line(guard - d.orthogonal() * SCALE * 1.5, guard + d.orthogonal() * SCALE * 1.5, OUTLINE_COLOR, SCALE * 2.0)
				draw_line(guard - d.orthogonal() * SCALE, guard + d.orthogonal() * SCALE, gold, SCALE)
				draw_rect(Rect2(hilt - Vector2(SCALE, SCALE) * 0.5, Vector2(SCALE, SCALE)), gold)


## Screen-local position of a pixel of the sprite as drawn this frame.
func _sprite_px(origin: Vector2, x: float, y: float) -> Vector2:
	var half := Sprites.SIZE / 2.0
	return origin + Vector2((x + 0.5 - half) * SCALE * flip, (y + 0.5 - half) * SCALE)


## What this unit looks like right now (sprite, accents, recolors, frames). Worked
## out again only when something that changes the look does (tiers, the path it last
## upgraded, Golden form, a Mage's shifting staff), not every frame.
func _look() -> Dictionary:
	var high := 0
	for t in tiers:
		if t >= 3:
			high += 1
	var step := _staff_step() if kind == "mage" and high >= 2 else 0
	var key: int = tiers[0] | tiers[1] << 3 | tiers[2] << 6 | tiers[3] << 9 | (last_path + 1) << 12 \
			| (1 if golden_left > 0.0 else 0) << 16 | step << 17
	if key == _look_key:
		return _look_cache
	_look_key = key
	var look_name := sprite_name()
	var layers := accent_layers()
	var tag := accent_tag()
	var special := special_instrument()
	if special != "":
		layers.append(Sprites.INSTRUMENT_LAYERS[special])
		tag += "+" + special
	var recolor := {}
	if kind == "mage" and high >= 2:
		# Two paths at tier 3: the staff slowly shifts between their colors.
		var c := _staff_color()
		recolor = {"o": c, "O": c.darkened(0.3), "w": Color(0.92, 0.9, 0.85).lerp(c, 0.45)}
		tag += "+orb%d" % step
	if kind == "archer" and tiers[0] > 0:
		# The arrow nocked in her bow matches the ones she shoots.
		recolor = {"e": Projectile.ARROW_SHAFTS[tiers[0]], "a": Projectile.ARROW_HEADS[tiers[0]]}
		tag += "+g%d" % tiers[0]
	if golden_left > 0.0:
		recolor = recolor.merged(GOLD_HAIR, true)
		tag += "+gold"
	_look_cache = {"name": look_name, "layers": layers, "tag": tag, "recolor": recolor,
			"frames": Sprites.frames(look_name, recolor, tag, layers), "poses": {}}
	if MOUNTS.has(kind):
		_look_cache["mount"] = Sprites.mount_frames(look_name, kind, recolor, tag, layers)
		_look_cache["crew"] = _crew_look()
	return _look_cache


# --- Mounted emplacements ----------------------------------------------------
# The Archer, Mage and Frost Witch towers are drawn bigger, with the troop they're
# named for standing on the battlements: it turns to face its target and goes through
# its own attack poses. The Cannon has a Cannoneer beside it who works the gun drill:
# flinching at the blast, fetching and loading a ball, ramming it home, and touching
# off the fuse for the next shot. (See Sprites.mount_frames.)
const MOUNTS := Sprites.MOUNT_CREW   # see Sprites.draw_mount for the layout


## The troop on a tower (or the crew of a cannon), dressed for the tower's upgrades:
## a Mage or Frost Witch tower's crew wears its path's robes, an Archer tower's
## carries a crossbow (Range) or a full quiver (Garrison), and arrows colored like its
## damage.
func _crew_look() -> Dictionary:
	var troop: String = MOUNTS[kind]
	var look_name := troop
	var recolor := {}
	var tag := ""
	if troop != "cannoneer":
		var high := []
		for p in tiers.size():
			if tiers[p] >= 3:
				var q := p
				if troop == "archer":
					q = {1: 1, 2: 2}.get(p, -1)   # the tower's Range and Garrison look like the troop's
				if q >= 0:
					high.append(q)
		if high.size() >= 2:
			look_name = Sprites.combo(troop, high[0], high[1])
		elif high.size() == 1 and Sprites.SPRITES.has("%s_p%d" % [troop, high[0]]):
			look_name = "%s_p%d" % [troop, high[0]]
		if troop == "archer" and tiers[0] > 0:
			recolor = {"e": Projectile.ARROW_SHAFTS[tiers[0]], "a": Projectile.ARROW_HEADS[tiers[0]]}
			tag = "+g%d" % tiers[0]
	return {"name": look_name, "recolor": recolor, "tag": tag, "layers": [],
			"frames": Sprites.frames(look_name, recolor, tag), "poses": {}}


## The crew's pose this frame: an Archer drawing, a Mage or Frost Witch casting, a
## Cannoneer working the gun drill (see the "cannon" case).
func _crew_pose() -> String:
	match kind:
		"tower":
			if swing <= 0.0 and _readying() > 0.0:
				return "draw"
		"magetower", "frosttower":
			if swing > 0.0:
				return "cast"
		"cannon":
			# The gun drill: flinch at the blast, fetch a ball, load it, ram it home,
			# then stand ready and touch off the fuse as the next shot comes up.
			var reload := cooldown / _rate()
			var since := reload - cd_timer   # time since the last shot
			if _readying() > 0.45:
				return "light"
			if since < 0.0 or since >= reload * 0.7 or (target == null and since > 0.35):
				return ""
			var k := since / reload
			if since < 0.35:
				return "cover"
			if k < 0.3:
				return "carry"
			if k < 0.42:
				return "load"
			return "ram" if fmod(since, 0.36) < 0.18 else ""
	return ""


func _draw_mounted(look: Dictionary, foot: Vector2, base_foot: Vector2, tint: Color) -> void:
	var crew: Dictionary = look["crew"]
	var crew_tex: Texture2D = crew["frames"][0]
	var pose_name := _crew_pose()
	if pose_name != "":
		var poses: Dictionary = crew["poses"]
		if not poses.has(pose_name):
			poses[pose_name] = Sprites.pose(crew["name"], pose_name, crew["recolor"], crew["tag"])
		if poses[pose_name] != null:
			crew_tex = poses[pose_name]
	var breathe := 1.0 + 0.025 * sin(anim_t * 2.4 + position.x)
	var base_tex: Texture2D = look["mount"][0]
	var rect := Sprites.draw_mount(self, kind, foot, base_foot, flip, base_tex, crew_tex, tint, breathe, SCALE)
	_remember_body(base_tex, Transform2D(0, Vector2(flip, 1), 0, foot), rect)
	draw_set_transform(Vector2.ZERO)


## A construction site: scaffolding, the emplacement rising out of the ground as the
## Engineer works, and a progress bar.
func _draw_construction() -> void:
	var done := clampf(1.0 - build_left / maxf(build_total, 0.01), 0.0, 1.0)
	var look := _look()
	var tex: Texture2D = look["mount"][0] if MOUNTS.has(kind) else look["frames"][0]
	var k := SCALE * (Sprites.TOWER_GROW if kind in ["tower", "magetower", "frosttower"] else (Sprites.CANNON_GROW if kind == "cannon" else 1.0))
	var left: float = Sprites.mount_layout(kind, SCALE)["left"] if MOUNTS.has(kind) else -Sprites.SIZE / 2.0 * k
	var foot := Vector2(0, RADIUS)
	draw_texture_rect(Sprites.shadow(), Rect2(-RADIUS * 1.3, foot.y - 6, RADIUS * 2.6, 12), false, Color(0, 0, 0, 0.3))
	# The finished shape, faint, and as much of it as is built so far, solid from the ground up.
	var full := Rect2(left, foot.y - Sprites.SIZE * k, tex.get_width() * k, Sprites.SIZE * k)
	draw_texture_rect(tex, full, false, Color(1, 1, 1, 0.22))
	var rows := ceili(Sprites.SIZE * done)
	if rows > 0:
		var src_y := Sprites.SIZE - rows
		var dst := Rect2(full.position.x, foot.y - rows * k, full.size.x, rows * k)
		draw_texture_rect_region(tex, dst, Rect2(0, src_y, tex.get_width(), rows), Color(1, 1, 1, 1))
	# Scaffolding round it.
	var wood := Color(0.6, 0.42, 0.22)
	var top := foot.y - Sprites.SIZE * k * 0.9
	for x in [full.position.x + 2.0, full.end.x - 2.0]:
		draw_line(Vector2(x, foot.y), Vector2(x, top), wood, 2.0)
	for i in 3:
		var y := lerpf(foot.y - 6.0, top, i / 2.0)
		draw_line(Vector2(full.position.x, y), Vector2(full.end.x, y), wood, 2.0)
	draw_line(Vector2(full.position.x + 2, foot.y - 6), Vector2(full.end.x - 2, top), Color(wood, 0.7), 1.5)
	# Progress.
	var bar := Rect2(-RADIUS, top - 10, RADIUS * 2, 4)
	draw_texture_rect(Sprites.white(), bar, false, Color(0, 0, 0, 0.6))
	draw_texture_rect(Sprites.white(), Rect2(bar.position, Vector2(bar.size.x * done, 4)), false, Color(1.0, 0.8, 0.3))


## How far above its post a unit's health bar sits (above the troop on a tower).
func _bar_height() -> float:
	match kind:
		"tower", "magetower", "frosttower":
			return (Sprites.SIZE - Sprites.CREW_STAND) * SCALE * Sprites.TOWER_GROW + Sprites.SIZE * SCALE + 4.0 - RADIUS
		"cannon":
			return Sprites.SIZE * SCALE * Sprites.CANNON_GROW + 2.0 - RADIUS
	return Sprites.SIZE * SCALE + 2.0 - RADIUS


func _pose_tex(look: Dictionary, pose_name: String):
	var poses: Dictionary = look["poses"]
	if not poses.has(pose_name):
		poses[pose_name] = Sprites.pose(look["name"], pose_name, look["recolor"], look["tag"], look["layers"])
	return poses[pose_name]


func _draw() -> void:
	if build_left > 0.0:
		_draw_construction()
		return
	var look := _look()
	var frames: Array = look["frames"]
	var size := Vector2(Sprites.SIZE, Sprites.SIZE) * SCALE
	var feet := RADIUS
	xray_tex = null
	# The shadow, sprite, pips and health bar all come from the sprite atlas, so the
	# renderer can batch the whole army together.
	var sr := RADIUS * (1.35 if MOUNTS.has(kind) else 1.0)
	draw_texture_rect(Sprites.shadow(), Rect2(-sr, feet - sr * 0.35, sr * 2.0, sr * 0.7), false, Color(0, 0, 0, 0.3))
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
		Sprites.disc(self, Vector2(0, feet - size.y * 0.45), size.y * 0.55, Color(1, 0.2, 0.15, pulse))
	if not frost_aura.is_empty():
		# Frost Aura: a frosty ring on the ground with snowflakes drifting round it.
		var r: float = frost_aura["radius"] + RADIUS
		draw_set_transform(Vector2.ZERO)
		draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(0.75, 0.95, 1.0, 0.3), 1.5, true)
		var spin := Time.get_ticks_msec() / 1500.0
		for i in 6:
			var p := Vector2.from_angle(spin + i * TAU / 6.0) * r * (0.55 + 0.4 * fmod(i * 0.37, 1.0))
			draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.9, 0.97, 1.0, 0.7))
	if not heal_aura.is_empty():
		# Halo: a soft golden-green ring around the Healer.
		var r: float = heal_aura["radius"] + RADIUS
		var pulse := 0.2 + 0.08 * sin(Time.get_ticks_msec() / 300.0)
		draw_set_transform(Vector2.ZERO)
		draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(0.85, 1.0, 0.55, pulse + 0.1), 1.5, true)
		Sprites.disc(self, Vector2.ZERO, r, Color(0.7, 1.0, 0.5, pulse * 0.25))
	if crimson_left > 0.0 or golden_left > 0.0:
		# Power forms: a roaring aura of flames around the body, crimson, gold or both.
		var t := Time.get_ticks_msec() / 70
		var cols := []
		if golden_left > 0.0:
			cols.append(Color(1.0, 0.85, 0.3))
		if crimson_left > 0.0:
			cols.append(Color(1.0, 0.25, 0.2))
		for c in cols.size():
			var col: Color = cols[c]
			var grow := 1.0 + c * 0.25
			Sprites.disc(self, Vector2(0, feet - size.y * 0.45), size.y * 0.5 * grow, Color(col, 0.18))
			for i in 9:
				var x := (-1.0 + i / 4.0) * size.x * 0.42 * grow
				var h := (10.0 + float((t + i * 5 + c * 3) % 5) * 4.0) * grow
				var base := Vector2(x, feet - 2.0 - absf(x) * 0.6)
				draw_colored_polygon(PackedVector2Array([base + Vector2(-3, 0), base + Vector2(3, 0), base + Vector2(0, -h - size.y * 0.35)]), Color(col, 0.45))
	var tint := Color(1, 0.45, 0.45) if hurt > 0.0 else Color.WHITE
	if goo_timer > 0.0 and hurt <= 0.0:
		tint = Color(0.7, 1.15, 0.6)   # slimed: green and sticky
	if clone_of != null:
		# A Mirror Self copy: see-through, tinted blue and flickering, so it's never taken for the real one.
		tint *= Color(0.6, 0.85, 1.3, 0.5 + 0.12 * sin(Time.get_ticks_msec() / 90.0))
	var charging := beam_charge > 0.0
	var tex: Texture2D = frames[int(walk) % 2 if moving else 0]
	var pose_name := _pose_name()
	var pose_tex = _pose_tex(look, pose_name) if pose_name != "" else null
	if pose_tex != null:
		tex = pose_tex
	if _lance_out():
		# The spear comes down level for the charge (and the blow that ends it).
		var spear = _pose_tex(_lance_look(look), "strike" if lance_left > 0.0 else "couch")
		if spear != null:
			tex = spear
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
		Sprites.disc(self, puff, 3.0 + 3.0 * k, Color(0.75, 0.68, 0.55, 0.45 * (1.0 - k)))
	var motion := _body_motion()
	var origin: Vector2 = Vector2(0, feet - size.y / 2) + lunge + motion[0]
	var arrow := _archer_arrow(origin) if kind == "archer" and _idling() and _readying() <= 0.0 else {}
	if not arrow.is_empty() and arrow["behind"]:
		draw_set_transform(Vector2.ZERO)
		_draw_arrow(arrow["pos"], arrow["angle"], arrow["alpha"])   # sliding out of (or into) the quiver, behind her
	var body := _tex_rect(tex)
	body.position.y -= size.y / 2
	if dash_left > 0.0:
		# Charging in: fading afterimages trail behind.
		for i in range(3, 0, -1):
			draw_set_transform(origin + Vector2(0, size.y / 2) - facing * 12.0 * i, 0, Vector2(flip, 1))
			draw_texture_rect(tex, body, false, Color(1, 1, 1, 0.12 * (4 - i)))
	# Tilt and squash pivot on the feet, so it leans and squashes without lifting off.
	if MOUNTS.has(kind):
		_draw_mounted(look, origin + Vector2(0, size.y / 2), Vector2(0, feet), tint)
	else:
		draw_set_transform(origin + Vector2(0, size.y / 2), motion[1], Vector2(flip * motion[2].x, motion[2].y))
		var slung := back_weapon()
		if slung != "":
			_draw_back_weapon(slung, body.position)
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
			Sprites.disc(self, tip, 9.0 * swing / 0.15 + 3.0, Color(glow, 0.5 * swing / 0.15 + 0.2))
		elif _readying() > 0.0:
			# Gathering power in the staff's orb before the next cast.
			var k := _readying()
			var orb := _sprite_px(origin, 14, 2) if kind == "mage" else _sprite_px(origin, 14, 1.5)
			Sprites.disc(self, orb, 3.0 + 6.0 * k, Color(glow, 0.45 * k))
	if charging:
		# Gathering ki for the beam: a growing, flickering orb in front of the hands.
		var k := 1.0 - beam_charge / BEAM_CHARGE
		var orb := Vector2(0, feet - size.y * 0.45) + facing * 14.0
		var flicker := 1.0 + 0.15 * sin(Time.get_ticks_msec() / 25.0)
		Sprites.disc(self, orb, (4.0 + 10.0 * k) * flicker, Color(KI_COLOR, 0.35))
		Sprites.disc(self, orb, (2.0 + 5.0 * k) * flicker, Color(1, 1, 0.9, 0.9))
	if swing > 0.0 and kind == "swordsman":
		var a := facing.angle()
		if cleave.is_empty():
			draw_arc(facing * 8, 30, a - 0.9, a + 0.9, 12, Color(1, 1, 1, swing / 0.15), 3.0, true)
		elif cleave["arc"] >= 360.0:
			# Damage tier 4: a spin attack, a golden whirl all the way round him.
			var k := swing / 0.15
			var r: float = 18.0 + cleave["reach"] * (1.2 - 0.4 * k)
			var turn := (1.0 - k) * TAU * 1.5 + a
			draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(1, 0.85, 0.35, 0.35 * k), 3.0, true)
			draw_arc(Vector2.ZERO, r, turn, turn + PI * 1.3, 24, Color(1, 0.85, 0.35, k), 5.0, true)
			draw_arc(Vector2.ZERO, r - 6, turn + 0.3, turn + PI, 18, Color(1, 1, 1, 0.7 * k), 2.0, true)
		else:
			# Damage tier 3: a broad golden cleave.
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
	for p in (tiers.size() if clone_of == null else 0):   # copies carry no pips
		if tiers[p] == 0:
			continue
		for i in tiers[p]:
			draw_texture_rect(Sprites.white(), Rect2(-(tiers[p] - 1) * 3.0 + i * 6.0 - 2, feet + 4 + row * 5, 4, 4), false, PATH_COLORS[p])
		row += 1
	if not multiform.is_empty() and clone_of == null and not _clones().is_empty():
		# The real one, while split: a small gold marker over his head.
		var m := Vector2(0, feet - size.y - 10)
		draw_colored_polygon(PackedVector2Array([m + Vector2(0, -5), m + Vector2(4, 0), m + Vector2(0, 5), m + Vector2(-4, 0)]), OUTLINE_COLOR)
		draw_colored_polygon(PackedVector2Array([m + Vector2(0, -3.5), m + Vector2(2.5, 0), m + Vector2(0, 3.5), m + Vector2(-2.5, 0)]), Color(1.0, 0.85, 0.3))
	if hp < max_hp:
		var top := Vector2(-RADIUS, -_bar_height())
		draw_texture_rect(Sprites.white(), Rect2(top, Vector2(RADIUS * 2, 4)), false, Color(0, 0, 0, 0.6))
		draw_texture_rect(Sprites.white(), Rect2(top, Vector2(RADIUS * 2 * hp / max_hp, 4)), false, Color(0.35, 0.75, 1.0))


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
			Sprites.disc(self, orb, 5.0 + sin(anim_t * 3.0), Color(_orb_color(), 0.25))
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
				Sprites.disc(self, p, 4.0, Color(0.6, 0.85, 1.0, 0.25))
				draw_rect(Rect2(p - Vector2(1, 4), Vector2(2, 8)), col)
				draw_rect(Rect2(p - Vector2(4, 1), Vector2(8, 2)), col)
		"healer":
			# Sparks of light rising from its prayer.
			for i in 3:
				var k := fmod(anim_t * 0.6 + i / 3.0, 1.0)
				var p := origin + Vector2(sin(i * 2.1 + anim_t) * 14.0, size.y * 0.2 - k * 44.0)
				Sprites.disc(self, p, 5.0, Color(0.7, 1.0, 0.6, 0.3 * (1.0 - k)))
				draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.95, 0.6, 1.0 - k))
		"alchemist":
			var h := _toss()
			if h >= 0.0:
				# The flask (or bomb) spinning up out of its hand and back down.
				var p := _sprite_px(origin, 13.5, 8) + Vector2(0, -h * 28.0)
				var look := _look_path()
				draw_set_transform(p, anim_t * 12.0, Vector2.ONE)
				if look == 2:
					Sprites.disc(self, Vector2.ZERO, 6.0, OUTLINE_COLOR)
					Sprites.disc(self, Vector2.ZERO, 4.5, Color(0.35, 0.35, 0.42))
					draw_rect(Rect2(-1, -9, 2, 3), Color(1.0, 0.8, 0.25))
				else:
					Sprites.disc(self, Vector2(0, 1), 5.5, OUTLINE_COLOR)
					draw_rect(Rect2(-2.5, -7, 5, 5), OUTLINE_COLOR)
					Sprites.disc(self, Vector2(0, 1), 4.0, FLASK_COLORS[look] if look >= 0 else data["color"])
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
## The arrow she twirls while idle: the same kind she shoots (her Damage tier).
func _draw_arrow(p: Vector2, angle: float, alpha := 1.0) -> void:
	draw_set_transform(p, angle, Vector2(0.85, 0.85))
	Projectile.arrow_shape(self, tiers[0], alpha, true)
	draw_set_transform(Vector2.ZERO)


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
	if kind == "mage" and _high_paths().size() >= 2:
		return _staff_color()
	var look := _look_path()
	return MAGE_ORB_COLORS[look] if look >= 0 else Color(0.85, 0.55, 1.0)
