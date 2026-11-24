extends Node2D
## A hired warrior. Goes after an enemy on the field (chosen by its target
## priority), attacks it, and walks back to its post when the field is clear.
## Upgrades come from four paths (see data.gd): any six upgrades, in any mix of paths.

const Data = preload("res://scripts/data.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Trap = preload("res://scripts/trap.gd")
const Sprites = preload("res://scripts/sprites.gd")
const Zone = preload("res://scripts/zone.gd")
const Defense = preload("res://scripts/defense.gd")
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
const BOMB_CHARGE := 0.7   # seconds a Spirit Bomb takes to gather: its bolts drawn together into one
const MAGE_ORB_COLORS := [Color(0.5, 0.75, 1.0), Color(1.0, 0.85, 0.5), Color(1.0, 0.5, 0.15), Color(0.8, 0.75, 1.0)]   # Storm, Arcane Lance, Fire, Spellblade
const FLASK_COLORS := [Color(0.65, 0.35, 0.95), Color(0.88, 0.95, 0.2), Color(1.0, 0.45, 0.15), Color(0.95, 0.3, 0.25)]
const DASH_TIME := 0.18      # seconds a Swordsman's dash takes
const RUN_BEFORE_DASH := 1.0 # seconds of running before a dash
const LANCE_AFTER := 0.25    # seconds of running before a Charge Knight lowers his spear for it
const ESCORT_LANE := 10.0       # an escort keeps this far out of a wagon's or ram's road (beyond the two of them touching)
const ESCORT_LEAD := 0.5        # ...and makes for where it'll be this many seconds on
# Pikeman.
const STEADY_REACH := 60.0       # Unbroken Line: a Pikeman this near steadies the melee allies he backs
const HEDGE_SLACK := 12.0        # Hedge of Points: the braced thrust's sweep catches the next foe this far past his reach
const READY_AGAIN := 0.3        # Readied Pike: a held-back thrust at a fresh foe at most this often
const COMING_ON := 0.15         # a foe whose way is at least this much toward him is coming on (past him counts)
const PIKE_SET := 0.3            # stood still this long: braced, pike levelled
const PIKE_READY := 1.25         # Readied Pike: its thrust at a foe charging in (Spearwall's brace replaces it)
const PIKE_AGAIN := 4.0          # ...not again on the same foe for this long
const PIKE_CLOSE := 6.0          # a foe this far inside its reach (gap, px) is past its point...
const PIKE_CLOSE_HIT := 0.85     # ...and its thrusts at it land for this share (a modest weakness: Haft Check makes room)
const SEQ_TIME := 3.0            # Impaling Strike: a run of thrusts on one foe breaks after this long without one
# Assassin.
const SNEAK_OPENER := 2.0       # its opening strike on an unwary foe, stalked up to (Ambush: harder)
const OPENER_REST := 2.0         # ...after this long without striking
const SNEAK_SEEN := 70.0         # ...and never further than this, however far it could shoot
const SNEAK_DETECT := 0.5        # stalking, foes notice it only this much as far off (Leafstep: less again)
const OPPORTUNIST := 1.5        # its first cut on a foe busy with another...
const OPP_AGAIN := 5.0           # ...each foe once in this long
const REST_UNSEEN := 1.0         # Leafstep: out of the fight this long, it's quicker and harder to notice
const SMOKE_SEEN := 40.0         # in its smoke, only a foe this close still sees it
const SMOKE_HURT := 0.4          # Smoke Pellet: below this share of health and still being hit...
const FINISH_CUTS := 3.0        # ...unless its mark's in reach and this many cuts from dead
const SMOKE_NEAR := 30.0         # ...or SMOKE_CROWD foes within this gap of it
const SMOKE_CROWD := 3
const SMOKE_RUN := 90.0          # ...it slips this far away
const AGGRO_SMOKE := 260.0       # ...losing every foe this near that had turned on it
const DECOY_LURES := 2           # Ghost Trail: foes a decoy draws off
const GHOST_SPEED := 0.2         # ...and its speed after, for GHOST_SPEED_TIME
const GHOST_SPEED_TIME := 2.0
const REFUND_AGAIN := 8.0        # Ghost of Greenwood: smoke back sooner at most this often
const VITAL_TIME := 3.0          # Vital Strike: its foe's guard down this long
const LUNGE_TIME := 0.12         # Chain Assassination: a lunge takes this long
const FEAR_REACH := 90.0         # Silent Reaper: the weak this near falter
const MOMENTUM_TIME := 3.0       # Final Judgment: Killing Momentum lasts...
const MOMENTUM_AGAIN := 6.0      # ...and comes at most this often
const FLANK_NEAR := 70.0         # flanking: once this near its target, straight in
const FLANK_WIDE := 50.0         # ...before that, round the side this far
const BLADE_STAND := 0.15       # Spellblade: stands and fights a foe whose blow takes less than this share of her health; backs off from the rest
const BLADE_SLACK := 12.0       # Spellblade: once out, the sword stays out this much further
const BLADE_SWING := 0.22       # ...how long a sweep shows
const BLADE_STORM_CD := 3.0     # ...Storm: a chain from the blow at most this often
const BLADE_CHAIN_SHARE := 0.5  # ...for this share of the Storm's damage...
const BLADE_CHAIN_JUMPS := 3    # ...over at most this many foes
const BLADE_LANCE_CD := 3.0     # ...Arcane Lance: a focused bolt at most this often...
const BLADE_LANCE_SHARE := 0.2  # ...for this share of the Lance
const TRAP_AHEAD := 90.0       # Trapcraft: how far along a foe's route it sets a charge
const TRAP_CANDIDATES := 6      # ...looking at the nearest this many foes
const TRAP_CROWD := 80.0        # ...a spot with more foes this close to it is the better
const TRAP_GAP := 36.0          # ...never this close to another of its charges
const TRAP_CLEAR := 26.0        # ...nor this close to a foe's edge (it needs time to arm)
const TRAP_LOOK := 0.5          # ...nowhere good: look again after this long
const TRAP_LEFT_BEHIND := 260.0 # ...at its limit, the oldest is taken up only if it's this far behind
const BARRAGE_GAP := 0.07   # seconds between Evasive Barrage arrows
const FROZEN_SPEAR := 0.25  # Glacial Spear: this much harder on a foe frozen solid (times its cc_mult: a boss, less)
const WARD_BURST := 55.0
const ANGEL_COOLDOWN := 60.0  # Guardian Angel: once saved, a troop can't be again for this long    # Intercession: how far a broken ward's burst reaches
const BACKSTEP := 34.0       # Spearhead: how far he steps back to charge the same foe again (px)...
const BACKSTEP_TIME := 0.22  # ...and how long that takes
const GOLD_HAIR := {"h": Color(1.0, 0.86, 0.25)}   # Golden Ascension
const IDLE_AFTER := 0.8   # seconds with nothing to do before a troop starts its idle animation
const WINDUP := 0.18      # melee troops rear back over the last moment before a blow
const ARCHER_DRAW := 0.9  # Archer idle: draw an arrow out of the quiver (seconds)...
const ARCHER_LOOP := 3.3  # ...then twirl it, flip it, one lazy turn, over and over while she stands idle...
const ARCHER_STOW := 0.7  # ...and put it back only once she moves off (seconds)
const PRIORITIES := ["closest", "first", "strongest", "valuable"]
const VALUE := {"warmage": 5.0, "boltflinger": 5.0, "drummer": 4.0, "gravebinder": 4.0, "skeleton_archer": 3.0, "sapper": 2.0, "shieldbearer": 1.0, "wolf": 0.5}   # (on offer; "weakest" still works for anything set to it)
const PRIORITY_NAMES := {
	"closest": "Closest", "first": "First", "strongest": "Strongest", "weakest": "Weakest", "objective": "Objective", "valuable": "High-value",
	"side": "Side Objectives",
	"revive": "Heal", "heal": "Heal the hurt", "stay": "Stay with", "danger": "In danger",
}
# A Healer's own priorities: who it looks after first. "revive": the downed first (they're
# on a clock), then the hurt; "heal": the hurt first, then the downed; "stay": it keeps
# with a troop (or a group: its wards) and looks after them first, and anyone else only
# within reach without leaving them; "danger": allies in danger (see in_danger) first,
# wherever they are on the field, then the downed, then the hurt. Where there are
# villagers on the field, they're among the hurt it heals.
const HEAL_PRIORITIES := ["revive", "stay"]   # on offer: Heal (the downed first, then the hurt) or Stay with; the others still work
const WARD_GAP := Vector2(0, 34)   # where a Healer keeps itself from its ward (just behind it)
# In a battle with something to protect (rules.guards()), one more: "objective", the enemy
# nearest to getting at it. New troops start on it there.
const OBJECTIVE_PRIORITY := "objective"
# Where a battle has side objectives to take (the Dawnspire assault's towers, prison pens,
# winch house and supplies: rules.side_objectives()), one more: "side". The rules send a
# troop on it to take them (an Archer, Mage or Frost Witch also mans a tower taken), and
# back to guarding the main objective once they're all done; it fights like "objective".
const SIDE_PRIORITY := "side"
const THREAT_RANGE := 320.0   # an enemy this far from its objective (or further) is the least urgent of those after one
# Orders: where a unit may go to fight (Hold: only at its post; Guard Area: anywhere in a
# rectangle the player drew, any size, which needn't even hold its post; Free Roam:
# anywhere), and how firmly it sticks to the enemy it picked. Incidental blows on the
# way (see _victim) never change either.
const MOVE_MODES := ["hold", "guard", "free"]
const MOVE_NAMES := {"hold": "Hold Position", "guard": "Guard Area", "free": "Free Roam"}
const GUARD_DEFAULT := 200.0   # Guard Area with none drawn yet: a square this far out from the post each way
const MIN_AREA := 24.0         # a drawn area smaller than this (each way) is taken for a slip of the mouse
# In danger: low on health (under DANGER_HP of its most) and hit in the last DANGER_HIT
# seconds. What it does about it (its own orders): fights on, or falls back (to a Healer
# or a Medic Bay, else its post or the castle) till it's patched up or out of the fight
# for a moment; and, either way, calls for help or not. Others answer the call by their
# orders: never, once their own enemy's dealt with, or at once, leaving their area and
# their target priority for it (then back to their post).
const DANGER_HP := 0.35
const DANGER_HIT := 2.5
const RECOVER_HP := 0.65     # falling back: back in the fight once mended to this
const SAFE_GAP := 130.0      # ...or once no enemy has come this close for SAFE_TIME
const SAFE_TIME := 2.0
const CALL_REACH := 150.0    # answering: the enemies this close to the caller are the ones it goes for
const DANGER_MODES := ["fight", "fall_back"]
const DANGER_NAMES := {"fight": "Fight on", "fall_back": "Fall back"}
const ANSWERS := ["ignore", "after", "now"]
const ANSWER_NAMES := {"ignore": "Ignore", "after": "After target", "now": "At once"}
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
# Pikeman (see _pike_step, _pike_hit). Path effects:
var brace := {}              # Spearwall
var hold := {}               # Hold Fast: dr, knock (braced only)
var hardened := {}           # Impaler: pierce, bonus
var puncture := {}
var impaling := {}
var phalanx := {}
var haft := {}               # Hook & Shove
var hook := {}
var defend := {}
var sweep := {}
var ready_t := 0.0           # Readied Pike: not again so soon
var still_t := 0.0           # seconds it's stood still (braced once PIKE_SET)
var pike_range := 0.0        # its reach before Overlapping Spears
var pike_seen := {}          # foe id -> seconds left before it can be intercepted again
var punct_id := 0            # Deep Thrust: the foe it's puncturing, how deep, how long left
var punct_n := 0
var punct_t := 0.0
var seq_id := 0              # Impaling Strike: thrusts in a row on one foe
var seq_n := 0
var seq_t := 0.0
var shoulder := false        # Phalanx: a melee ally at its shoulder
var backed := false          # ...one in front of it (it fights from the second rank)
var phal_check := 0.0
var support_t := 0.0
var haft_t := 0.0
var hook_t := 0.0
var defend_t := 0.0
var sweep_t := 0.0
var guarded: Array = []      # Hook & Shove: where the troops and objectives it covers stand
var guard_check := 0.0
# Assassin (see _assassin_step, _assassin_hit, _chain_next).
var ambush := {}
var disrupt := {}
var kunai := {}
var sever := {}
var blackout := {}
var leafstep := {}
var smoke := {}
var scent := {}
var relentless := {}
var deathblow := {}
var since_strike := 9.0      # seconds since it last struck (its opening strike needs a moment of stalking)
var rest_t := 9.0            # seconds since it last struck or was struck (out of the fight)
var opp_seen := {}           # Opportunist: foe id -> seconds before its bonus is had again
var chain_t := 0.0           # Chain Assassination: cooldown
var chain_mults: Array = []  # ...the strikes still to come in the chain, and how many fell
var chain_kills := 0
var lunge_left := 0.0
var lunge_to := Vector2.ZERO
var lunge_target = null
var lunge_mult := 1.0
var cd_timer_scale := 1.0    # a Pikeman's braced catch: its next thrust comes this much sooner (No Passage)
var kunai_t := 0.0
var smoke_t := 0.0           # Smoke Pellet: cooldown
var smoke_hide := 0.0        # > 0: foes have lost it (save right beside it)
var stealth_t := 0.0         # Ghost of Greenwood: unseen a while after the smoke
var smoke_ambush := false    # Ambush + smoke: one more opening strike
var haste_t := 0.0           # Ghost Trail: quicker for a moment out of the smoke
var escape_left := 0.0       # slipping away under the smoke
var escape_to := Vector2.ZERO
var refund_cd := 0.0
var rel_id := 0              # Relentless Cuts
var rel_n := 0
var rel_t := 0.0
var death_t := 0.0           # Deathblow cooldown
var mom_left := 0.0          # Final Judgment: Killing Momentum, and the foe it came from
var mom_from := 0
var mom_cd := 0.0
var flank_at := Vector2.INF
var flank_check := 0.0
# Knight Charge (Vanguard): see _momentum_step, _start_backstep.
var momentum := {}           # Light Step: after, bonus, cooldown
var moved := 0.0             # px run since his last blow
var momentum_ready := false  # his next blow hits harder
var momentum_t := 0.0
var _last_pos := Vector2.INF
var dash_cd := 0.0           # seconds till he can charge again from a run
var again_t := 0.0           # seconds trading blows with this foe (Spearhead: charge it again)
var backstep_left := 0.0     # stepping back to charge the same foe again
var backstep_dir := Vector2.ZERO
var spear_reach := 0.0
# Archer Evasive Barrage.
var barrage := {}            # count, damage, cooldown
var barrage_t := 0.0
var barrage_left := 0
var barrage_timer := 0.0
var barrage_targets: Array = []
# Mage Spellblade.
var blade := {}              # damage, every, targets, reach
var blade_t := 0.0
var blade_on := false        # a foe's close: the sword's out
var blade_swing := 0.0       # > 0 while a sweep shows
var blade_storm_t := 0.0
var blade_lance_t := 0.0
var haste := 1.0             # Haste: its spells' cooldowns, times this
# Frost Witch Shattercraft.
var brittle := {}            # time, bonus, every
var shard := {}              # damage, cooldown, pierce, spear
var shard_t := 1.5
var shatter := {}            # damage, radius, window, spread
# Healer Divine Retribution: wards it gives (ward), and one it carries (shield_*).
var ward := {}
var ward_t := 2.0
var shield_hp := 0.0
var shield_max := 0.0
var shield_left := 0.0
var shield_fx := {}          # reflect, cap, burst, angel
var shield_reflected := 0.0
var angel_cd := 0.0          # Guardian Angel: this troop can't be saved again till it runs out (any Healer's)
var spent := 0
var priority := "closest"
var move_mode := "free"        # Orders: see MOVE_MODES
var guard_area := Rect2()      # Guard Area: where it fights, on the field (empty: none drawn yet; see zone_rect)
var danger_mode := "fight"     # Orders: in danger, it fights on or falls back (DANGER_MODES)
var call_help := true          # Orders: in danger, it calls for help
var answer := "ignore"         # how it answers others' calls for help (ANSWERS); no longer on the orders panel, so troops keep their line (answering by default pulled them off it)
var danger_t := 0.0            # seconds since it was last hit, counting down from DANGER_HIT
var retreating := false        # falling back, in danger
var safe_t := 0.0              # falling back: how long no enemy has come near
var answering = null           # the ally whose call for help it's answering
var free_run := false          # answering a call (or a Healer going to an ally in danger): its area doesn't hold it
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
var lifesteal := 0.0         # share of a punch's damage a Martial Artist gets back as health (Thousand Fists)
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
var rez_held := 0.0          # > 0 while a Healer is channeling a revive on this (downed) unit: its time doesn't run out
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
var burn := []               # Archer / Cannoneer / Ballista
# The plain Tower and its crew: any ranged troop ordered onto a Tower climbs in. Up there
# it counts as an emplacement (it stays put, shoots what's in reach, over walls), keeps
# all its own upgrades, reaches further from the high ground, and enemies can't get at it
# (they go for the tower). Ordered anywhere else, it climbs down.
const GARRISON_KINDS := ["archer", "mage", "frost", "alchemist", "bard"]


## Whether troop `w` can go up a Tower: a ranged kind, or a Martial Artist with Spirit bolts
## to throw from up there (a Spirit-path upgrade). Not a copy or a summoned thing.
static func can_garrison(w) -> bool:
	if w == null or w.summoned or w.clone_of != null:
		return false
	return GARRISON_KINDS.has(w.kind) or (w.kind == "martial" and int(w.tiers[0]) > 0)
const PERCH_BASE := 0.3      # how much further a crew reaches from a Tower (before its Lookout upgrades)
const CLIMB_REACH := 30.0    # a troop ordered this near an empty Tower climbs into it
var garrison = null          # the Tower this troop is posted in (null: on the ground)
var broken := false          # an emplacement brought down: rubble, out of the fight (no Healer or Medic Bay brings it back, and it's never killed off like a troop); Engineers can rebuild it for gold
const REBUILD_TIME := 8.0    # seconds an Engineer works at a broken Tower to put it up again
var crew_in = null           # a Tower's crew
var perch := 0.0             # a Tower: how much further its crew reaches (0.3: 30%)
var crew_rate := 1.0         # a Tower: its crew's attack time, times this
var tower_repair := 0.0      # a Tower: HP its masons mend a second while a wave is on
var garrison_check := 0.0
# The Ballista: bolts that fly on through everything in their line, hard on flyers.
var air_mult := 1.0          # damage against flyers, times this
var impale := 0.0            # seconds the first enemy a bolt hits is pinned
var net := []                # [slow, seconds] on flyers it hits
var air_crit := []           # [chance, multiplier] on flyers
var blast_end := {}          # share, radius, stun: the burst where a bolt stops
# The Arcane Obelisk: a boost to Mages near it, and a magic of its own for each rune.
var aura_magic := 0.0        # Mages near it hit this much harder
var storm_rune := {}         # damage, count, cooldown, fork: lightning from the sky
var ray_rune := {}           # damage, count, cooldown, mark: a ray through a line of enemies
var glyph_rune := {}         # dps, radius, duration, count, cooldown, burst: fire glyphs burned into the ground
var rift_rune := {}          # push, count, cooldown, damage, sick: rifts throwing enemies back up the field
var rune_t := {}             # rune -> seconds to its next casting
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
var hex := {}            # buffs taken off it for a while (the Ogre King's dirge): key -> share
var hex_left := 0.0
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
var bomb_charge := 0.0    # > 0 while gathering a Spirit Bomb (he stands, the bolts circling in to his hands)
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
var heading := Vector2.ZERO   # which way it last walked (for stepping round someone in its way)
var build_left := 0.0      # an emplacement still being built: seconds of an Engineer's work left
var build_total := 0.0
var kiting := false        # a ranged troop backing away from an enemy that got too close
const KITE_GAP := 45.0     # ranged troops back off from enemies closer than this...
const KITE_CLEAR := 70.0   # ...until they're this far off again
var facing := Vector2.UP
var flip := 1.0
var turn := 1.0           # the facing it's drawn with: swings over to flip in a quick turn, never snaps
var turn_hold := 0.0
var held := false         # being carried by the player's click-and-drag (main sets it)
var lift := 0.0           # 0-1: how far off the ground it's been lifted
var sway := 0.0           # carried: the dangling tilt, swinging behind the drag like a pendulum
var sway_v := 0.0
var carry_t := 0.0        # seconds since it was picked up
var down_for := 0.0       # seconds since it was knocked out (it topples over)
var land_dust := false    # the bump is a real landing (dust flies), not just a springy squash
var land_t := 0.0         # > 0 just after being set down: the bump and the dust
var _carried_from := Vector2.ZERO   # last frame's position while carried
var _carry_vel := Vector2.ZERO
var cheer_t := 0.0        # > 0 while it cheers (a wave held, an upgrade): hopping on the spot
var cheer_len := 0.0
const CHEER_HOP := 0.42   # seconds a cheering hop takes
var perk := 0.0           # 0-1: the mouse is over it between waves and it perks up, ready to be picked up
var hop_from := Vector2.ZERO   # dropped where it can't stand: it hops back from here (offset from its post)
var hop_t := 0.0
const HOP_TIME := 0.32
const LAND_TIME := 0.45
const LIFT_HEIGHT := 16.0
const GLANCERS := ["swordsman", "martial", "bard"]   # idle troops that look about (the rest have idle props drawn facing one way)
const TURN_RATE := 11.0   # turns a full about-face in under a fifth of a second
var target = null
var anim_t := 0.0         # running clock for idle loops
var idle_t := 0.0         # how long it has had nothing to do
var stow_t := 0.0         # Archer: seconds left putting her idle arrow back in the quiver
var note_timer := 0.0     # Bard: idle tunes
var route := PackedVector2Array()   # waypoints around walls to route_goal
var route_goal := Vector2.INF
var route_timer := 0.0
var dazed := 0.0          # stunned by the Ogre King's stomp: can't move or act
var shove_velocity := Vector2.ZERO
var shove_left := 0.0
var lost_time := 0.0      # seconds spent trying to get back to its post; a last resort after STUCK_LIMIT (see _teleport_home)
const STUCK_LIMIT := 30.0
# Getting about among its own (Phase 1 of the formations work): see _home_spot, _stuck_watch.
const SLOT_TOL := 12.0        # at its post, it stays settled while it's this close (no shuffling when nudged)
const SLOT_TAKEN := 1.4       # its post counts as taken by an idle ally standing within this many radii of it
const STUCK_SAMPLE := 0.4     # how often it checks whether it's getting anywhere (s)...
const STUCK_MOVE := 4.0       # ...covering less than this (px) while trying to walk is "stuck" for that long
const STUCK_SIDESTEP := 0.6   # stuck this long: it steps to one side as it goes (the same side, no dithering)
const STUCK_REROUTE := 1.4    # ...then it works out its way afresh
const STUCK_WAIT := 2.6       # ...then waits a moment for the way to clear
const STUCK_ALT := 3.4        # ...then makes for the nearest open spot by its post instead
var settled := false          # standing at (or close enough to) its post
var home_alt := Vector2.INF   # somewhere close by its post to stand instead (the post's taken, or can't be got to)
var home_alt_for := Vector2.INF
var home_alt_t := 0.0
var stuck_t := 0.0
var stuck_check := 0.0
var stuck_from := Vector2.INF
var want_move := false        # tried to walk somewhere since the last check
var side_sign := 0.0          # the side it's stepping to while stuck (0: not)
var rerouted := false
var waited := false
var yield_left := 0.0         # > 0: waiting for the way to clear
var home_check := 0.0


func setup(k: String, d: Dictionary, m, post_pos: Vector2) -> void:
	kind = k
	data = d
	main = m
	post = post_pos
	spent = d["cost"]
	_apply_upgrades()
	hp = max_hp
	if d.has("priority"):
		priority = d["priority"]   # (an Assassin goes for the dangerous ones by default)
	if d.has("danger_mode"):
		danger_mode = d["danger_mode"]   # (an Assassin badly hurt slips back to be mended, rather than fight on)
	if d.get("pike", false):
		move_mode = "guard"   # (a Pikeman holds ground by default: he catches what comes, he doesn't chase)
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
	lifesteal = 0.0
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
	momentum = {}
	spear_reach = 0.0
	for key in ["brace", "hold", "hardened", "puncture", "impaling", "phalanx", "haft", "hook", "defend", "sweep",
			"ambush", "disrupt", "kunai", "sever", "blackout", "leafstep", "smoke", "scent", "relentless", "deathblow"]:
		set(key, {})
	barrage = {}
	blade = {}
	haste = 1.0
	brittle = {}
	shard = {}
	shatter = {}
	ward = {}
	perch = PERCH_BASE if kind == "tower" else 0.0
	crew_rate = 1.0
	tower_repair = 0.0
	air_mult = data.get("air_mult", 1.0)
	impale = 0.0
	net = []
	air_crit = []
	blast_end = {}
	aura_magic = data.get("aura_magic", 0.0)
	storm_rune = {}
	ray_rune = {}
	glyph_rune = {}
	rift_rune = {}
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
					"golden", "heal_aura", "befuddle", "traps", "burn", "rain", "cluster", "napalm", "smite", "gems", "multiform",
					"momentum", "barrage", "blade", "brittle", "shard", "shatter", "ward",
					"brace", "hold", "hardened", "puncture", "impaling", "phalanx", "haft", "hook", "defend", "sweep",
					"ambush", "disrupt", "kunai", "sever", "blackout", "leafstep", "smoke", "scent", "relentless", "deathblow"]:
				if fx.has(key):
					set(key, fx[key])
			pierce = fx.get("pierce", pierce)
			haste = fx.get("haste", haste)
			spear_reach += fx.get("spear", 0.0)
			lifesteal = fx.get("lifesteal", lifesteal)
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
			perch += fx.get("perch", 0.0)
			crew_rate *= fx.get("crew_rate", 1.0)
			if kind == "tower":
				tower_repair = fx.get("repair", tower_repair)
			air_mult += fx.get("air_mult", 0.0)
			impale = fx.get("impale", impale)
			net = fx.get("net", net)
			air_crit = fx.get("air_crit", air_crit)
			for key in ["blast_end", "storm_rune", "ray_rune", "glyph_rune", "rift_rune"]:
				if fx.has(key):
					set(key, fx[key])
			wave_bonus = fx.get("wave_bonus", wave_bonus)
			hauls += fx.get("hauls", 0)
	if spear_reach > 0.0 and not _spear_on_back():
		attack_range += spear_reach   # (a spear in hand reaches further than a sword)
	pike_range = attack_range
	# Golden Ascension is the crimson aura made golden: the one form, not both at once.
	if not golden.is_empty():
		crimson = {}
	# Up in a Tower: the high ground (and the tower's upgrades) carry it further.
	if garrison != null and is_instance_valid(garrison):
		attack_range *= 1.0 + garrison.perch
		song_radius *= 1.0 + garrison.perch
		cooldown *= garrison.crew_rate
		if not blast.is_empty():
			# (a Martial Artist up there: his bolts carry further, and come quicker)
			blast = blast.duplicate()
			blast["range"] = float(blast["range"]) * (1.0 + garrison.perch)
			blast["cooldown"] = float(blast["cooldown"]) * garrison.crew_rate
	if crew_in != null and is_instance_valid(crew_in):
		crew_in.call_deferred("_apply_upgrades")   # (a Tower's upgrades reach its crew)
	# Extra combo hits turn into extra blasts per volley once ki blasts are learned.
	# (Only when Spirit's his main path: a brawler with Spirit on the side keeps his punches.)
	blast_count = 0
	if not blast.is_empty() and spirit_first():
		blast_count = int(blast["count"]) + extra_hits
	else:
		if not blast.is_empty():
			blast_count = int(blast["count"])
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
	if kind in PLAIN_LOOKS:
		return []
	var accents: Array = Sprites.ACCENTS.get(kind, [])
	return _accent_paths().map(func(p): return accents[p])


## Names this mix of accents for the sprite cache.
func accent_tag() -> String:
	var paths := _accent_paths()
	return "" if paths.is_empty() else "+a" + "".join(paths.map(func(p): return str(p)))


## Sprite to draw: tier 3 in a path swaps in that path's look, and two paths at
## tier 3 wear a combination of both.
const PLAIN_LOOKS := ["tower", "ballista", "obelisk"]   # one look whatever their upgrades (the Obelisk's runes glow its path's colour)


func sprite_name() -> String:
	if kind in PLAIN_LOOKS:
		return kind
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


## A Martial Artist whose Spirit path is his main one (no other trained further): he fights
## from bolt range. One with Spirit as a side art closes in to brawl like any other.
func spirit_first() -> bool:
	if blast.is_empty():
		return false
	for p in range(1, 4):
		if int(tiers[p]) > int(tiers[0]):
			return false
	return true


func is_melee() -> bool:
	return data["attack"] == "melee" or data["attack"] == "combo"


## What this unit's main attack is made of (see the damage schools in enemy.gd).
func school() -> String:
	match data["attack"]:
		"orb", "note":
			return "magic"
		"frost":
			return "ice"
		"flask":
			return "alchemy"
		"shell":
			return "explosive"
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
	return data.get("emplacement", false) or garrison != null   # (a troop up in a Tower stands like one)


## Out of the enemy's reach: up on the castle wall, or in a Tower (they go for the tower).
func sheltered() -> bool:
	return wall_guard or garrison != null


## Support emplacements (gold mine, medic bay, statue) never attack anything.
func is_support() -> bool:
	return data["attack"] in ["mine", "pulse", "aura", "perch", "rune"]


## Towers fire from high up, mortar shells and flasks arc over, so they clear walls;
## every other attack (a plain Cannoneer's shells too) needs a clear line to its target.
func shoots_over_walls() -> bool:
	if data["attack"] == "shell":
		return mortar
	return is_emplacement() or wall_guard or data["attack"] == "flask"   # towers and the castle wall stand above the barricades


func _sees(e) -> bool:
	return (shoots_over_walls() or not main.paths.wall_between(position, e.position)) and main.paths.sight_clear(position, e.position)   # (and never through a castle's walls)


## Whether the Target button means anything for this unit.
func uses_targeting() -> bool:
	return not is_healer() and not is_support()


func _power() -> float:
	var weather: float = 1.0 if main.gust <= 0.0 else main.hazards.power_factor(kind)   # Frost Witches in a blizzard
	return (surge["damage"] if surge_left > 0.0 else 1.0) * _form("damage") * (1.0 + buff["damage"]) * _body_share() * weather


## Mirror Self: the share of the Martial Artist's power each of his bodies has right
## now. Split between him and his copies; all of it back with him once they're gone.
func _body_share() -> float:
	var real = clone_of if clone_of != null else self
	if not is_instance_valid(real) or real.multiform.is_empty():
		return 1.0
	var bodies: int = 1 + real._clones().size()
	return 1.0 if bodies == 1 else real.multiform["power"] / bodies


## A Mirror Self copy whose Martial Artist is up a Tower: it keeps watch round the tower's
## foot, walking a round about it, and goes for whatever comes near.
var patrol_t := 0.0
var patrol_i := 0
const PATROL_R := 70.0

func _patrol_step(delta: float) -> void:
	var real = clone_of
	if real == null or not is_instance_valid(real) or real.garrison == null or not is_instance_valid(real.garrison):
		return
	var t = real.garrison
	anchor = null
	move_mode = "guard"
	guard_area = Rect2(t.position - Vector2(140, 110), Vector2(280, 230))   # (it fights what comes near the tower)
	patrol_t -= delta
	if patrol_t <= 0.0 and (target == null or not _is_valid(target)):
		patrol_t = 2.2
		patrol_i += 1
		var a := patrol_i * TAU / 6.0
		post = main.paths.open_spot(main._clamp_post(t.position + Vector2(cos(a) * PATROL_R, 26.0 + sin(a) * PATROL_R * 0.6)))


func _clones() -> Array:
	return main.get_warriors().filter(func(w): return w.clone_of == self)


func _rate() -> float:
	var weather: float = 1.0 if is_melee() or main.gust <= 0.0 else main.hazards.rate_factor(kind)   # a blizzard slows ranged fire
	return (surge["rate"] if surge_left > 0.0 else 1.0) * _form("rate") * (1.0 + buff["rate"]) * (1.0 - (1.0 - _goo_factor()) * 0.5) * weather


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
	# A Mage near an Arcane Obelisk hits harder (the best one near it counts).
	if kind == "mage":
		var arcane := 0.0
		for w in main.get_warriors():
			if w.aura_magic > 0.0 and w != self and w.is_active() and w.build_left <= 0.0 and w.covers(self):
				arcane = maxf(arcane, w.aura_magic)
		buff["damage"] += arcane
	# A Mage on one of the Spires' conduits draws on it.
	var drawn: Dictionary = main.conduits.boost(self)
	for key in drawn:
		buff[key] += drawn[key]
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
	# Hexed (the Ogre King's dirge): weaker, slower for a while.
	if hex_left > 0.0:
		for key in hex:
			buff[key] -= float(hex[key])


## Weakened for `secs` seconds: `what` (buff key -> share) off its buffs.
func hex_for(what: Dictionary, secs: float) -> void:
	hex = what.duplicate()
	hex_left = maxf(hex_left, secs)
	buff_timer = 0.0


## An empty Tower (nobody up it): nothing for the enemy to go after, so it doesn't.
func unmanned_tower() -> bool:
	return kind == "tower" and not (crew_in != null and is_instance_valid(crew_in) and crew_in.garrison == self)


func is_active() -> bool:
	return down_timer <= 0.0 and not broken and not is_queued_for_deletion()


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
	return priority if priority in ["revive", "heal", "stay", "danger"] else "revive"


func set_post(p: Vector2) -> void:
	if garrison != null and is_instance_valid(garrison) and p.distance_to(garrison.position) > CLIMB_REACH:
		leave_tower()   # sent somewhere else: it climbs down first
	post = p
	target = null


## Into Tower t: up on its top, where it stays (see GARRISON_KINDS).
func enter_tower(t) -> void:
	garrison = t
	t.crew_in = self
	anchor = null
	position = t.position + Vector2(0, -2)
	post = position
	fitted_post = Vector2.INF
	target = null
	visible = false
	_apply_upgrades()
	t.queue_redraw()
	main.spawn_text(t.position + Vector2(0, -80), "Up in the tower", Color(0.75, 0.9, 1.0))
	main.sfx("place", 1.2)
	main.warriors_changed()


## Down out of its Tower, at the foot of it.
func leave_tower() -> void:
	var t = garrison
	garrison = null
	visible = true
	if t != null and is_instance_valid(t):
		if t.crew_in == self:
			t.crew_in = null
		position = t.position + Vector2(0, 30)
		t.queue_redraw()
	_apply_upgrades()
	main.warriors_changed()


## A ranged troop: climbs into an empty Tower it's been ordered onto; up there, it stays
## on top of it (and climbs down if the tower's wrecked or sold).
func _garrison_step(delta: float) -> void:
	if garrison != null:
		if held or not is_instance_valid(garrison) or garrison.is_queued_for_deletion() or not garrison.is_active():
			leave_tower()   # (picked up and carried off it, or the tower's gone)
			return
		position = garrison.position + Vector2(0, -2)
		post = position
		return
	if not can_garrison(self) or not is_active() or held:
		return
	garrison_check -= delta
	if garrison_check > 0.0:
		return
	garrison_check = 0.2
	for t in main.get_warriors():
		if t.kind == "tower" and t.is_active() and t.build_left <= 0.0 and (t.crew_in == null or not is_instance_valid(t.crew_in)) \
				and post.distance_to(t.position) <= CLIMB_REACH and position.distance_to(t.position) <= CLIMB_REACH + 8.0:
			enter_tower(t)
			return


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
	if broken:
		return 0   # (rubble's worth nothing: rebuild it, or leave it)
	var step: int = main.price_step
	return int(spent * 0.6) if step <= 1 else roundi(spent * 0.6 / step) * step


func stats_text() -> String:
	if broken:
		return "Broken - its crew's down off it. An Engineer can rebuild it, upgrades and all, for %dg (Rebuild, L)" % rebuild_cost()
	if build_left > 0.0:
		return "Under construction - an Engineer has %.1fs of work left on it" % build_left
	var s := "HP %d/%d   Damage %.0f   Every %.2fs" % [ceili(hp), ceili(max_hp), damage, cooldown]
	var src: Dictionary = main.conduits.source(self)
	if not src.is_empty():
		var full: bool = int(src["path"]) == main.conduits.art_of(self)
		s += "   Sigil: %s (%s%s)" % [main.conduits.NAMES[int(src["path"])], main.conduits.words(main.conduits.boost(self)), "" if full else ", not its art"]
	elif not main.conduits.stationed(self).is_empty():
		s += "   Sigil: %s, held by another Mage (one to a sigil)" % main.conduits.NAMES[int(main.conduits.stationed(self)["path"])]
	if data["attack"] == "bolt":
		s += "   %.1fx against flyers (aims for them first)" % air_mult
	if garrison != null and is_instance_valid(garrison):
		s += "   Up in a Tower: reach +%d%%" % roundi(garrison.perch * 100.0)
	if is_support():
		match data["attack"]:
			"perch":
				var c = crew_in if crew_in != null and is_instance_valid(crew_in) and crew_in.garrison == self else null
				s = "HP %d/%d   %s   Its crew reaches %d%% further" % [ceili(hp), ceili(max_hp),
						("Crew: %s" % c.label) if c != null else "Empty: order a ranged troop onto it", roundi(perch * 100.0)]
				if crew_rate < 1.0:
					s += ", attacks %d%% faster" % roundi((1.0 / crew_rate - 1.0) * 100.0)
				if tower_repair > 0.0:
					s += "   Repairs %.0f HP/s in waves" % tower_repair
			"rune":
				s = "HP %d/%d   Reach %s   Mages near it +%d%% damage" % [ceili(hp), ceili(max_hp), Data.ft(attack_range), roundi(aura_magic * 100.0)]
				if not storm_rune.is_empty():
					s += "   Lightning %.0f x%d / %.1fs" % [storm_rune["damage"], int(storm_rune["count"]), storm_rune["cooldown"]]
				if not ray_rune.is_empty():
					s += "   Ray %.0f x%d / %.1fs" % [ray_rune["damage"], int(ray_rune["count"]), ray_rune["cooldown"]]
				if not glyph_rune.is_empty():
					s += "   Glyph %.0f/s x%d / %.0fs" % [glyph_rune["dps"], int(glyph_rune["count"]), glyph_rune["cooldown"]]
				if not rift_rune.is_empty():
					s += "   Rift %s x%d / %.0fs" % [Data.ft(rift_rune["push"]), int(rift_rune["count"]), rift_rune["cooldown"]]
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
		if blast.has("merge"):
			s += "   Spirit Bomb %.0f / %.1fs, range %s" % [blast["damage"] * blast_count * float(blast["merge"]), blast["cooldown"], Data.ft(blast["range"])]
		else:
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
	if data.get("pike", false):
		s += "   Readied: %.2gx on a foe charging in%s" % [float(brace["mult"]) if not brace.is_empty() else PIKE_READY, (", catches %d" % int(brace["targets"])) if not brace.is_empty() and int(brace["targets"]) > 1 else ""]
		if not brace.is_empty() and float(brace["pin"]) > 0.0:
			s += ", pins %.1fs" % float(brace["pin"])
		if pike_braced():
			s += " (BRACED)"
		if not puncture.is_empty():
			s += "   Puncture %d/%d" % [punct_n, int(puncture["max"])]
		if not impaling.is_empty():
			s += "   Every %dth thrust %.1fx" % [int(impaling["every"]), float(impaling["mult"])]
		if not phalanx.is_empty():
			s += "   Phalanx%s%s" % [": at a shoulder" if shoulder else "", ", second rank" if backed else ""]
		for k in ["haft", "hook", "defend", "sweep"]:
			if not get(k).is_empty():
				s += "   %s /%.0fs" % [{"haft": "Haft Check", "hook": "Hook", "defend": "Defender's Reach", "sweep": "Sweep"}[k], float(get(k)["every"])]
	if kind == "assassin":
		if not ambush.is_empty():
			s += "   Opener %.1fx%s" % [float(ambush["mult"]), (", chains %d (%s)" % [int(ambush["chain"]), "ready" if chain_t <= 0.0 else "%ds" % ceili(chain_t)]) if int(ambush["chain"]) > 1 else ""]
		for k in ["disrupt", "kunai", "sever", "blackout"]:
			if not get(k).is_empty():
				s += "   " + {"disrupt": "Disrupts", "kunai": "Kunai", "sever": "Severs spells", "blackout": "Blackout"}[k]
		if not smoke.is_empty():
			s += "   Smoke %s" % ("ready" if smoke_t <= 0.0 else "%ds" % ceili(smoke_t))
		if not scent.is_empty():
			s += "   +%d%% on the wounded" % roundi(float(scent["bonus"]) * 100)
		if not deathblow.is_empty():
			s += "   Deathblow under %d%%" % roundi(float(deathblow["below"]) * 100)
	if not momentum.is_empty():
		s += "   After a run: next blow +%d%%%s" % [roundi(float(momentum["bonus"]) * 100), " (ready)" if momentum_ready else ""]
	if not dash.is_empty():
		s += "   Charge %sx every %.0fs%s%s" % [str(dash["damage"]), float(dash["cooldown"]), (", again on a foe every %.0fs" % float(dash["again"])) if float(dash.get("again", 0.0)) > 0.0 else "",
				", chains" if dash.get("chain", false) else ""]
	if pierce > 0:
		s += "   Arrows hit up to %d%s" % [pierce + 1, ", seeking" if seek else ""]
	elif seek:
		s += "   Arrows seek"
	if not barrage.is_empty():
		s += "   Evasive Barrage: %d arrows at %d%% (every %.0fs)" % [int(barrage["count"]), roundi(float(barrage["damage"]) * 100), float(barrage["cooldown"])]
	if not blade.is_empty():
		s += "   Sword %.0f magic dmg, sweeps %d" % [float(blade["damage"]) * _power(), int(blade["targets"])]
	if haste < 1.0:
		s += "   Haste: spells %d%% faster" % roundi((1.0 / haste - 1.0) * 100)
	if not brittle.is_empty():
		s += "   Brittle: +%.0f ice dmg on the next hit" % float(brittle["bonus"])
	if not shard.is_empty():
		s += "   %s %.0f dmg / %.1fs" % ["Glacial Spear" if shard["spear"] else "Icicle", float(shard["damage"]) * _power(), float(shard["cooldown"])]
	if not shatter.is_empty():
		s += "   Shatter %.0f dmg%s" % [float(shatter["damage"]), (", spreads Brittle to %d" % int(shatter["spread"])) if int(shatter["spread"]) > 0 else ""]
	if not ward.is_empty():
		s += "   Ward %.0f / %.0fs%s%s%s" % [float(ward["absorb"]) * _power(), float(ward["every"]), (", %d at once" % int(ward["count"])) if int(ward["count"]) > 1 else "",
				(", reflects %d%%" % roundi(float(ward["reflect"]) * 100)) if float(ward["reflect"]) > 0.0 else "", ", Guardian Angel" if ward["angel"] else ""]
	if shield_hp > 0.0:
		s += "   Warded: %.0f" % shield_hp
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
		s += "   Charges %d/%d: %.0f dmg%s%s" % [my_traps.size(), int(traps["max"]), traps["damage"], ", stun %.0fs" % traps["stun"] if traps["stun"] > 0.0 else "",
				(", slow %d%%" % roundi(float(traps["slow"][0]) * 100)) if not traps.get("slow", []).is_empty() else ""]
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
	var heavy: int = main.heavy_key
	if heavy != 0:
		Defense.note(self, "hit_brace" if brace_key == heavy else "hit_" + String(def_seen.get(heavy, "unaware")))
	# Iron Will / Afterimage: a chance at any blow, but not twice over (a warned blow it
	# already tried to get clear of and was caught by anyway lands).
	if evade > 0.0 and not (heavy != 0 and def_seen.get(heavy, "") == "evade") and randf() < evade:
		main.spawn_text(position + Vector2(0, -40), "Dodge", Color(0.85, 0.95, 1.0))
		return
	if block > 0.0 and randf() < block:
		main.spawn_text(position + Vector2(0, -40), "Block", Color(0.75, 0.82, 1.0))
		block_flash = 0.2
		return
	if heavy != 0 and brace_key == heavy:
		amount *= 1.0 - Defense.BRACE_DAMAGE   # (braced for it)
	if data.get("pike", false) and (not hold.is_empty() or not phalanx.is_empty()):
		amount = _pike_guard(amount)
	if kind == "assassin":
		rest_t = 0.0
	if kind == "tower":
		main.earn_xp("tower", minf(hp, amount * (1.0 - armor)), "soak")   # standing up to it shields its crew: it trains like a wall
	var dmg: float = amount * (1.0 - armor) * (1.0 - buff["defense"])
	if shield_hp > 0.0:
		# A Healer's ward: soaks up what gets past armour, then throws some back.
		var soak := minf(shield_hp, dmg)
		shield_hp -= soak
		dmg -= soak
		_ward_reflect(soak)
		if hp - dmg <= 0.0 and shield_fx.get("angel", false) and angel_cd <= 0.0:
			dmg = maxf(hp - 1.0, 0.0)   # Guardian Angel: not this blow (the ward's spent on it)
			angel_cd = ANGEL_COOLDOWN
			main.spawn_text(position + Vector2(0, -48), "Saved!", Color(1.0, 0.92, 0.55))
			main.spawn_burst(position, 30.0, Color(1.0, 0.92, 0.6))
			_drop_ward(false)
		elif shield_hp <= 0.0:
			_drop_ward(true)
	hp -= dmg
	hurt = 0.1
	danger_t = DANGER_HIT
	if hp <= 0.0 and summoned:
		_crumble()
		return
	if hp <= 0.0 and data.get("emplacement", false):
		_break()   # (any emplacement: broken, to be rebuilt; never downed like a troop)
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
	if broken:
		return   # (rubble: nothing to do until it's rebuilt)
	if main.campaign:
		main.credit = xp_kind()   # whatever this unit hurts this frame counts toward its training
	if build_left > 0.0 and down_timer <= 0.0:
		queue_redraw()   # a construction site: nothing works until the Engineer's done
		return
	if summoned and (not main.fighting() or not is_instance_valid(summoner) or summoner.is_queued_for_deletion()
			or (clone_of != null and not summoner.is_active())):
		_crumble()
		return
	hurt = maxf(hurt - delta, 0.0)
	swing = maxf(swing - delta, 0.0)
	goo_timer = maxf(goo_timer - delta, 0.0)
	pose_left = maxf(pose_left - delta, 0.0)
	lance_left = maxf(lance_left - delta, 0.0)
	block_flash = maxf(block_flash - delta, 0.0)
	angel_cd = maxf(angel_cd - delta, 0.0)
	if shield_left > 0.0:
		shield_left -= delta
		if shield_left <= 0.0:
			_drop_ward(false)   # (run out: no burst)
	queue_redraw()
	_animate(delta)
	if clone_of != null:
		_patrol_step(delta)   # (its Martial Artist up a Tower: it keeps watch round the foot)
	if garrison != null or GARRISON_KINDS.has(kind) or kind == "martial":
		_garrison_step(delta)
	if down_timer > 0.0:
		# Healers and Medic Bays nearby keep a downed unit alive longer (or, without
		# permadeath, get it up sooner). While one's reviving it, its time stands still.
		if rez_held > 0.0:
			rez_held -= delta
			if main.permadeath:
				return
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
	if backstep_left > 0.0:
		_backstep_step(delta)
		return
	if lunge_left > 0.0:
		_lunge_step(delta)
		_separate()
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
	dash_cd = maxf(dash_cd - delta, 0.0)
	momentum_t = maxf(momentum_t - delta, 0.0)
	barrage_t = maxf(barrage_t - delta, 0.0)
	blade_t = maxf(blade_t - delta, 0.0)
	blade_swing = maxf(blade_swing - delta, 0.0)
	blade_storm_t = maxf(blade_storm_t - delta, 0.0)
	blade_lance_t = maxf(blade_lance_t - delta, 0.0)
	moving = false
	buff_timer -= delta
	if buff_timer <= 0.0:
		buff_timer = 0.25
		_update_buffs()
	danger_t = maxf(danger_t - delta, 0.0)
	if hex_left > 0.0:
		hex_left -= delta
		if hex_left <= 0.0:
			buff_timer = 0.0   # (its strength back at once)
	if call_help and in_danger() and not summoned:
		main.call_for_help(self)
	if _off_the_ice(delta):
		_separate()
		return
	if _defend(delta):
		if absf(facing.x) > 0.2:
			flip = signf(facing.x)
		_separate()
		return
	if escape_left > 0.0:
		# Slipping away under its smoke: it doesn't fight on the way.
		escape_left -= delta
		var d := position.distance_to(escape_to)
		if d > 3.0:
			facing = position.direction_to(escape_to)
			_move_toward(escape_to, d, delta)
		if absf(facing.x) > 0.2:
			flip = signf(facing.x)
		_separate()
		return
	if _dodge(delta):
		if absf(facing.x) > 0.2:
			flip = signf(facing.x)
		_separate()
		return
	if _fall_back(delta):
		if absf(facing.x) > 0.2:
			flip = signf(facing.x)
		_separate()
		return
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
		chain_timer = chain["cooldown"] * haste
	if not lance.is_empty() and lance_timer <= 0.0 and _cast_lance():
		lance_timer = lance["cooldown"] * haste
	if not breath.is_empty() and breath_timer <= 0.0 and _breathe():
		breath_timer = breath["interval"] * haste
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
	elif bomb_charge > 0.0:
		# Gathering the Spirit Bomb: he holds his ground, hands out, as it gathers; then it goes.
		bomb_charge -= delta
		_hold_pose("punch", 0.1)
		if volley_target != null and _is_valid(volley_target):
			facing = position.direction_to(volley_target.position)
		if bomb_charge <= 0.0:
			bomb_charge = 0.0
			_continue_volley(0.0)
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
	if not ordered:
		_update_answer()
	if ordered:
		target = null
		if position.distance_to(post) <= RADIUS:
			ordered = false
	elif answering != null:
		var t = _answer_target()
		if t != target:
			_set_target(t)   # answering a call: its target priority and area wait
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
		if not teleport.is_empty() and teleport_timer <= 0.0 and garrison == null and _should_blink(target, gap):
			_blink_to(target)
			gap = _gap_to(target)
		if not blast.is_empty() and spirit_first():
			# Spirit users hold at blast range and fire volleys; they still punch anything that
			# closes in. (A brawler with a little Spirit closes in instead, throwing bolts on the
			# way: see below.)
			var r: float = blast["range"]
			if not _sees(target):
				_chase_move(target.position, gap, delta)   # a wall's in the way: go round it
			elif gap > r:
				_chase_move(target.position, gap - r + 1.0, delta)
		elif is_melee():
			if not dash.is_empty() and dash_cd <= 0.0 and run_time >= RUN_BEFORE_DASH and gap > 6.0 and gap <= dash["reach"] and _can_dash(target):
				_start_dash(target)
				return
			var stop := 0.0
			if data.get("pike", false):
				stop = maxf(attack_range - 6.0, 0.0)   # (a pike reaches: it doesn't walk right up, nor into the ally it backs)
			if gap > stop:
				if kind == "assassin":
					var aim := _flank_point(target)
					_chase_move(aim, gap if aim == target.position else position.distance_to(aim), delta)
				else:
					_chase_move(target.position, gap - stop, delta)
		elif not _sees(target):
			_chase_move(target.position, gap, delta)
		elif gap > attack_range:
			_chase_move(target.position, gap - attack_range + 1.0, delta)
		_watch_chase(gap, delta)
	else:
		var home := _home_spot(delta)
		var d := position.distance_to(home)
		if settled and d <= SLOT_TOL:
			lost_time = 0.0   # (close enough: no shuffling back and forth on the spot)
		elif d > 2.0:
			settled = false
			facing = position.direction_to(home)
			_move_toward(home, d, delta)
			lost_time += delta
			if lost_time >= STUCK_LIMIT:
				_teleport_home()
		else:
			settled = true
			lost_time = 0.0
		if not ordered:
			_mend(max_hp * REGEN * delta)

	_strike_in_reach(delta)
	if absf(facing.x) > 0.2:
		flip = signf(facing.x)
	if not dash.is_empty():
		if target != null and _is_valid(target) and _gap_to(target) <= attack_range + 2.0:
			if engaged_id != target.get_instance_id():
				again_t = 0.0   # (a new foe: the count starts over)
			engaged = target
			engaged_id = target.get_instance_id()
			# Spearhead: a foe that won't fall gets the spear again, from a short step back.
			if float(dash.get("again", 0.0)) > 0.0:
				again_t += delta
				if again_t >= float(dash["again"]) and _start_backstep(target):
					again_t = 0.0
		elif engaged_id != 0 and is_instance_valid(engaged) and not engaged.dead \
				and (engaged != target or _gap_to(engaged) > attack_range + 12.0):
			engaged = null   # it walked off from that fight: no chain when that foe falls later
			engaged_id = 0
	# Running time toward a target (for a Swordsman's dash): any stop resets it.
	run_time = run_time + delta if moving and target != null else 0.0
	if not momentum.is_empty():
		_momentum_step()
	if target != null or ordered:
		settled = false
	_stuck_watch(delta)
	_separate()


func _victim():
	if target != null and _can_strike(target):
		return target
	if kind == "assassin" and sneaking() and target != null and _is_valid(target):
		return null   # (stalking its mark: no cut at whatever it passes, that would give it away)
	return _pick(main.get_enemies().filter(_can_strike))


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
	if lifesteal > 0.0:
		_mend(damage * _power() * lifesteal)   # (Thousand Fists: every blow puts some fight back in him)
	# Only the finishing hit can knock back, so the combo isn't cut short.
	if combo_left == 0 and randf() < knockback_chance:
		v.apply_knockback(facing * knockback_force)


func _in_combat() -> bool:
	if garrison != null and not blast.is_empty():
		return _blast_target() != null   # (up a Tower, a Martial Artist fights with his bolts)
	var reach: float = maxf(attack_range, blast.get("range", 0.0)) + 40.0
	return target != null and _is_valid(target) and _gap_to(target) <= reach


# Spirit path: a volley of homing blasts at enemies outside punching reach.
func _start_volley() -> bool:
	if _blast_target() == null:
		return false
	volley_left = blast_count
	volley_timer = 0.0
	volley_target = _blast_target()
	if blast.has("merge"):
		# Spirit Bomb: the whole volley in one blast, gathered first (see _bomb_step).
		volley_left = 1
		bomb_charge = BOMB_CHARGE
		main.sfx("powerup", 1.4)
		return true
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
	p.splash = blast.get("splash", 0.0)   # Blazing Spirit on: every blast bursts
	if blast.has("merge"):
		# Spirit Bomb: every bolt of the volley (Brawling's extra ones too) fused into one
		# great blast, worth more than all of them together.
		p.damage = blast["damage"] * blast_count * float(blast["merge"]) * _power()
		p.size = 1.0 + 0.25 * blast_count
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
	if "RADIUS" in anchor and not anchor.has_method("stay_with"):
		var keep: float = anchor.RADIUS + RADIUS + 4.0   # (never under what it follows)
		if anchor_off.length() < keep:
			anchor_off = (anchor_off.normalized() if anchor_off.length() > 0.01 else Vector2.DOWN) * keep
	var lead := Vector2.ZERO
	if anchor.has_method("is_mover") and anchor.is_mover() and "RADIUS" in anchor:
		# A wagon or ram on the move: never in the road ahead of it (out to the side of it
		# instead), and a little ahead of where it is, so it isn't for ever falling behind.
		var head: Vector2 = main._mover_heading(anchor, Vector2.ZERO)
		if head != Vector2.ZERO:
			var side := head.orthogonal()
			var ahead := anchor_off.dot(head)
			var across := anchor_off.dot(side)
			var clear: float = anchor.RADIUS + RADIUS + ESCORT_LANE
			if ahead > -anchor.RADIUS * 0.3 and absf(across) < clear:
				across = clear * (signf(across) if absf(across) > 1.0 else 1.0)
				anchor_off = head * ahead + side * across
			lead = head * float(anchor.speed) * ESCORT_LEAD
	var p: Vector2 = main._clamp_post(anchor.position + lead + anchor_off)
	p = main.paths.open_spot(_clear_of_works(p))
	if p.distance_to(post) > 6.0:
		if guard_area.has_area():
			guard_area.position += p - post   # its area goes along with what it follows
		post = p
		lost_time = 0.0


## `p` moved out of any mission structure it's inside (a shut gate, a pen, a tower) and
## clear of a wagon or ram, so a post that's followed along never lands where it can't stand.
func _clear_of_works(p: Vector2) -> Vector2:
	for o in main.rules.objectives():
		if not is_instance_valid(o) or not (o.is_solid() or (o.is_mover() and o.is_target())) or o == self:
			continue
		var off: Vector2 = p - o.position
		var room: float = o.RADIUS + RADIUS + 4.0
		if off.length_squared() < room * room:
			p = o.position + (off.normalized() if off.length() > 0.01 else Vector2.DOWN) * room
	return main._clamp_post(p)


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
	if main.heavy_key != 0 and brace_key == main.heavy_key:
		push *= Defense.BRACE_PUSH   # (braced: it gives less ground)
		stun_time *= Defense.BRACE_STUN
	if not hold.is_empty() and pike_braced():
		push *= 1.0 - float(hold["knock"])   # (Hold Fast: feet set behind the pike)
	elif is_melee() and not data.get("pike", false):
		for w in main.warriors_near(position, STEADY_REACH):
			if w != self and not w.phalanx.is_empty() and float(w.phalanx["steady"]) > 0.0 and w.is_active():
				push *= 1.0 - float(w.phalanx["steady"])   # (Unbroken Line: a Pikeman at its back; one is enough)
				break
	lunge_left = 0.0   # (knocked out of a lunge: the chain's over)
	chain_mults.clear()
	escape_left = 0.0
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

## Whether its movement is limited to a zone (troops on Hold or Guard Area; emplacements
## and wall guards never move anyway). Not while it answers a call for help.
func zoned() -> bool:
	return move_mode != "free" and not is_emplacement() and not wall_guard and not free_run


## Where it may go to fight: just its post on Hold; its Guard Area otherwise (a square
## round its post if none's been drawn).
func zone_rect() -> Rect2:
	if move_mode == "hold":
		return Rect2(post, Vector2.ZERO)
	if not guard_area.has_area():
		return Rect2(post - Vector2.ONE * GUARD_DEFAULT, Vector2.ONE * GUARD_DEFAULT * 2.0)
	return guard_area


## Its Guard Area: a square `half` out from its post each way (for orders given in code).
func guard_around(half: float) -> void:
	guard_area = Rect2(post - Vector2.ONE * half, Vector2.ONE * half * 2.0)


## How far `p` is from rectangle `r` (0 inside it).
static func rect_gap(r: Rect2, p: Vector2) -> float:
	return p.distance_to(Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y)))


func _in_zone(p: Vector2, slack := 0.0) -> bool:
	return not zoned() or rect_gap(zone_rect(), p) <= slack


## The nearest point to `p` it may stand on.
func _zone_clamp(p: Vector2) -> Vector2:
	if not zoned():
		return p
	var r := zone_rect()
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))


## How far it can reach out from where it stands to fight: its weapon, or its ki blasts.
func _engage_reach() -> float:
	return maxf(attack_range, blast.get("range", 0.0))


## Whether it can fight `e` from somewhere in its zone (always, roaming free).
func _engageable(e, slack := 0.0) -> bool:
	if not zoned():
		return true
	if rect_gap(zone_rect(), e.position) - RADIUS - e.radius > _engage_reach() + slack:
		return false
	# Behind a castle's wall: a troop that has to keep to its ground doesn't go after what it
	# can't see from there (it would only press against the wall and back, over and over).
	return main.paths.sight_clear(position, e.position) or main.paths.sight_clear(post, e.position)


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
	if data["attack"] == "bolt" and e.flying:
		return 1e8 + _priority_score_ground(e)   # (a Ballista goes for what flies first)
	return _priority_score_ground(e)


func _priority_score_ground(e) -> float:
	# Small distance term breaks ties (e.g. a row of full-health goblins) toward the nearest.
	var near := -_gap_to(e) * 0.001
	match priority:
		"objective", "side":
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
		"valuable":
			return _value_score(e)
	return -_gap_to(e)


## High-value (an Assassin's own): the dangerous ones behind the line first (Horde Mages,
## Boltflingers, Drummers, a Gravebinder, archers, a Sapper near what it's after), the
## wounded next (with Scent of Blood), the nearest of those; but not one deep in a crowd of
## its friends (he'd never come out), and he sticks with the one he picked.
func _value_score(e) -> float:
	var v: float = VALUE.get(e.kind, 0.0)
	if e.kind == "sapper" and threat(e) > 1.2:
		v += 3.0
	if not scent.is_empty() and e.hp < e.max_hp * float(scent["below"]):
		v += 1.5
	var crowd := 0
	for o in main.enemies_near(e.position, 70.0):
		if o != e and not o.dead and o.fights and not o.flying:
			crowd += 1
	return v * 1000.0 - crowd * 450.0 - _gap_to(e) + (1500.0 if e == target else 0.0)


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


## Every priority unit w understands (the offered ones, and the others it still knows).
static func known_priorities(w) -> Array:
	if w.is_mobile_healer():
		return ["revive", "heal", "stay", "danger"]
	return priorities_for(w.main) + ["weakest"]


## The target priorities on offer in this battle.
static func priorities_for(m) -> Array:
	if m.rules == null or not m.rules.guards():
		return PRIORITIES
	return PRIORITIES + [OBJECTIVE_PRIORITY] + ([SIDE_PRIORITY] if m.rules.side_objectives() else [])


## Takes on another unit's orders (a Mirror Self copy, its original's).
func copy_orders(w) -> void:
	priority = w.priority
	commit = w.commit
	move_mode = w.move_mode
	guard_area = w.guard_area
	danger_mode = w.danger_mode
	call_help = w.call_help
	answer = w.answer
	anchor = w.anchor
	anchor_off = w.anchor_off


func cycle_priority() -> void:
	var list := priorities_for_unit(self)
	priority = list[(list.find(priority) + 1) % list.size()]
	target = null
	retarget_timer = 0.0


func _move_toward(p: Vector2, max_dist: float, delta: float) -> void:
	var weather: float = 1.0 if main.gust <= 0.0 else main.hazards.speed_factor(kind)   # wading through a blizzard
	var step := minf(move_speed * (1.0 + buff["speed"]) * _form("speed") * _goo_factor() * weather * speed_mult() * delta, max_dist)
	if wall_guard:
		return   # wall guards hold their posts
	if max_dist > SLOT_TOL:
		want_move = true
	if yield_left > 0.0:
		yield_left -= delta
		return   # (waiting a moment for the way ahead to clear)
	var aim := p
	# Only go the long way round if a wall or an emplacement is in the way of where it
	# means to stop.
	var stop := position + position.direction_to(p) * minf(max_dist, position.distance_to(p))
	if not is_emplacement() and (main.paths.has_troop_walls() or main.paths.has_emplacements() or main.paths.has_terrain()) \
			and _way_blocked(stop, delta):
		aim = _route_step(p, delta)
	if stuck_t >= STUCK_REROUTE and not rerouted:
		rerouted = true
		route.clear()
		route_timer = 0.0
		way_check = 0.0
		if main.paths.has_terrain() or main.paths.has_troop_walls() or main.paths.has_emplacements():
			aim = _route_step(p, delta)   # (its way afresh)
	heading = position.direction_to(aim)
	if stuck_t >= STUCK_SIDESTEP:
		if side_sign == 0.0:
			side_sign = _free_side(heading)
		heading = (heading + heading.orthogonal() * side_sign * 0.9).normalized()   # (round whoever's in the way, always the same side)
	var next := position + heading * step
	if not main.hazards.ice.is_empty() and main.hazards.cracking_at(next, RADIUS) and not main.hazards.cracking_at(position, RADIUS):
		return   # ice cracking ahead: it won't step out onto it (it waits at the edge)
	_step_to(next)
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


## Where it goes back to: its post, unless an idle ally's standing on it (then the nearest
## open spot beside it, so nobody shoves at a taken post for ever), or it's been stuck
## getting there a while (then the nearest open spot it can get to). The post itself
## stays its post: the spot beside it is let go of once the post's free again.
func _home_spot(delta: float) -> Vector2:
	home_alt_t = maxf(home_alt_t - delta, 0.0)
	if home_alt_for != post:
		home_alt = Vector2.INF   # (a new post: the old stand-in means nothing)
	home_check -= delta
	if home_check <= 0.0:
		home_check = 0.5
		var near_post := position.distance_to(post) < 90.0
		var taken := near_post and _post_taken(post, true)
		if taken or (stuck_t >= STUCK_ALT and position.distance_to(post) > SLOT_TOL):
			if home_alt == Vector2.INF or home_alt_t <= 0.0 or _post_taken(home_alt):
				home_alt = _open_beside(post)
				home_alt_for = post
				home_alt_t = 4.0
		elif home_alt_t <= 0.0:
			home_alt = Vector2.INF
	return home_alt if home_alt != Vector2.INF else post


## Whether an ally that's standing still (not passing through) is on `p`.
## Taken: an ally standing still on `p`; or one making for that very spot that's nearer it
## (a crowd sent to one place: the nearest has it, the rest stand round); or the spot an
## ally's already taken up beside its own post.
func _post_taken(p: Vector2, own := false) -> bool:
	var mine := position.distance_to(p)
	for w in main.warriors_near(p, RADIUS * 3.0 + 30.0):
		if w == self or not w.is_active() or w.is_emplacement():
			continue
		if own and w.home_alt != Vector2.INF and w.post.distance_to(p) > 4.0:
			continue   # (its own post outranks an ally only standing in there: that one moves on)
		var d: float = w.position.distance_to(p)
		if d < RADIUS * SLOT_TAKEN and (not w.moving or (w.post.distance_to(p) < 4.0 and d < mine)):
			return true
		if not own and w.home_alt != Vector2.INF and w.home_alt.distance_to(p) < RADIUS * 1.8:
			return true
		if not own and w.post.distance_to(p) < RADIUS * 1.6:
			return true   # (a stand-in never on another's own post)
	return false


## The nearest spot round `p` it could stand on and walk to (INF-safe: p itself if none).
func _open_beside(p: Vector2) -> Vector2:
	var best := p
	var best_d := INF
	for r in [RADIUS * 2.2, RADIUS * 3.4, RADIUS * 4.6]:
		for i in 8:
			var q: Vector2 = main._clamp_post(p + Vector2.from_angle((i + 0.5 * float(r > RADIUS * 3.0)) * TAU / 8.0) * r)
			if _post_taken(q) or (main.paths.has_terrain() and not main.paths.troop_can_stand(q)):
				continue
			if main.paths.wall_between(p, q):
				continue   # (not the far side of a wall from its post)
			var d := position.distance_to(q)
			if d < best_d:
				best_d = d
				best = q
		if best_d < INF:
			return best
	return best


## Every STUCK_SAMPLE s: if it's been trying to walk and has got nowhere, it's stuck that
## much longer (see _move_toward and _home_spot for what it does about it); moving again,
## or not trying to, and it isn't.
func _stuck_watch(delta: float) -> void:
	stuck_check -= delta
	if stuck_check > 0.0:
		return
	stuck_check = STUCK_SAMPLE
	var gone := position.distance_to(stuck_from) if stuck_from != Vector2.INF else INF
	stuck_from = position
	if want_move and gone < STUCK_MOVE and yield_left <= 0.0:
		stuck_t += STUCK_SAMPLE
		if stuck_t >= STUCK_WAIT and not waited:
			waited = true
			yield_left = 0.6   # (let the way clear: whoever's in it may be on the move)
	elif not want_move or gone >= STUCK_MOVE * 2.0:
		stuck_t = 0.0
		side_sign = 0.0
		rerouted = false
		waited = false
	want_move = false


## Which side to step round to (+1/-1 of `dir`'s left): the one with fewer allies.
func _free_side(dir: Vector2) -> float:
	var left := dir.orthogonal()
	var score := 0.0
	for w in main.warriors_near(position, RADIUS * 4.0):
		if w != self and w.is_active():
			score += signf(left.dot(w.position - position))
	return -1.0 if score > 0.0 else 1.0


func _separate() -> void:
	if is_emplacement():
		return   # rooted in place; everyone else steps around it
	for o in main.rules.objectives():
		# Nobody stands inside a mission objective.
		var off: Vector2 = position - o.position
		var room: float = o.RADIUS + RADIUS
		if (o.is_solid() or (o.is_mover() and o.is_target())) and off.length_squared() < room * room:
			position = o.position + (off.normalized() if off.length() > 0.01 else Vector2.DOWN) * room
			# Its post under it too (the ram rolled up onto it, or it follows too close): the
			# post goes just clear of it, or it would keep walking back into it.
			var poff: Vector2 = post - o.position
			if poff.length_squared() < room * room and not is_emplacement():
				post = main._clamp_post(o.position + (poff.normalized() if poff.length() > 0.01 else off.normalized()) * (room + 4.0))
				if anchor == o:
					anchor_off = post - o.position
	if wall_guard:
		position = post   # standing at its post on the wall
		return
	for w in main.warriors_near(position, RADIUS * 2.0 + 4.0):
		if w == self or not w.is_active():
			continue
		var off: Vector2 = position - w.position
		var d := off.length()
		if d < RADIUS * 2.0 and d > 0.01:
			# The one on the move has the way: one standing about steps aside for it (most of
			# the overlap is the stander's to make up), rather than the two shoving evenly.
			var share := 0.5
			if w.is_emplacement():
				share = 1.0
			elif w.moving and not moving and target == null:
				share = 0.8
			elif moving and not w.moving and w.target == null:
				share = 0.2
			position += off / d * (RADIUS * 2.0 - d) * share
			# Someone in the way of where it's walking (two Healers meeting head on in a
			# doorway): it steps to its right to get past, as the other does to its own right,
			# instead of the two pushing each other back where they came from for ever.
			if moving and heading.dot(-off / d) > 0.35 and not (w.moving and w.heading.dot(heading) > 0.3):
				position += Vector2(-heading.y, heading.x) * 1.2
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
	# The Ogre King is too big to shove: troops step out of his way, and one walking into him
	# slides round his side (rather than pressing against him on the spot).
	for e in main.get_enemies():
		if e.boss and not dodging:   # (running from something warned, it slips past between his legs)
			var off: Vector2 = position - e.position
			var min_d: float = RADIUS + e.radius
			if off.length() < min_d:
				var out := off.normalized() if off.length() > 0.01 else Vector2.DOWN
				position = e.position + out * min_d
				if moving and heading.dot(-out) > 0.2:
					var round := Vector2(-out.y, out.x)
					if round.dot(heading) < 0.0:
						round = -round
					position += round * 2.0
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
		if data.get("pike", false):
			hit = _pike_hit(e, hit)
		elif kind == "assassin":
			hit = _assassin_hit(e, hit)
		if not momentum.is_empty():
			if momentum_ready:
				hit *= 1.0 + float(momentum["bonus"])   # (Light Step: the run carried into the blow)
				momentum_ready = false
				momentum_t = float(momentum["cooldown"])
				main.spawn_burst(e.position, 14.0, Color(1.0, 0.85, 0.5))
			moved = 0.0
		e.take_damage(hit)
		main.sfx("slash" if kind == "swordsman" or kind == "skeleton" or kind == "assassin" else "hit", 0.85 if kind == "skeleton" else (1.3 if kind == "assassin" else 1.0))
		_hit_spark(e)
		if kind == "assassin":
			rest_t = 0.0
			_after_assassin_hit(e)
		if cd_timer_scale != 1.0:
			cd_timer *= cd_timer_scale   # (No Passage: ready again sooner after a catch)
			cd_timer_scale = 1.0
		# Phalanx: a Pikeman behind it in Second Rank thrusts too.
		if is_instance_valid(e) and not e.dead:
			for w in main.warriors_near(position, 70.0):
				if w != self and not w.phalanx.is_empty() and (position - w.position).dot(w.facing) > 8.0:
					w.support_thrust(self, e)
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
			if kind == "archer":
				break   # (an Archer's volley goes to different enemies: with only the one, one arrow)
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


## An emplacement brought down (a Tower, a Cannon, a Ballista, a Gold Mine, a Medic Bay...):
## broken, rubble where it stood, a Tower's crew down off it. No Healer or Medic Bay can bring
## it back, and it's never killed off for good the way a fallen troop is; the player can have
## an Engineer rebuild it, upgrades and all (rebuild_cost: the more spent on it, the more).
## `quiet`: put back broken (from a record), without the crash and dust.
func _break(quiet := false) -> void:
	broken = true
	hp = 0.0
	down_timer = 0.0
	target = null
	rez_target = null
	build_left = 0.0
	if crew_in != null and is_instance_valid(crew_in) and crew_in.garrison == self:
		crew_in.leave_tower()
	# Healers on their way to it (a revive, or seeing to it) leave it be.
	for w in main.get_warriors():
		if w != self and w.rez_target == self:
			w.rez_target = null
			w.rez_progress = 0.0
	if not quiet:
		main.spawn_burst(position + Vector2(0, -30), 40.0, Color(0.6, 0.58, 0.55))
		main.spawn_text(position + Vector2(0, -50), "Broken!", Color(1, 0.4, 0.35))
		main.sfx("crumble", 1.0)
	main.paths.invalidate()
	main.warriors_changed()
	queue_redraw()


## What it costs to have a broken emplacement rebuilt: half of all that's been spent on it (its
## upgrades included, so a well-upgraded tower costs more), never less than a third of a new one.
func rebuild_cost() -> int:
	return main.price(maxf(spent * 0.5, float(data["cost"]) / 3.0))


## The order to rebuild it: an Engineer comes out and puts it up again, upgrades and all.
func start_rebuild() -> void:
	broken = false
	hp = max_hp
	build_left = REBUILD_TIME
	main.send_engineer("build", self, position)
	main.warriors_changed()


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
	var swordsmage := not blade.is_empty()   # (a Spellblade meets small fry with the sword; she still steps back from a brute)
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
		if swordsmage and e.damage < max_hp * BLADE_STAND:
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
	if garrison != null:
		return position + Vector2(10.0 * f, -46)   # up on the tower
	match kind:
		"ballista":
			return position + Vector2(16.0 * f, -22)
		"cannon":
			return position + Vector2(14.0 * f, -33)   # the mouth of the (bigger) cannon
	return position + facing * 18.0


func _shoot(e, index: int, share := 1.0):
	if data["attack"] == "bolt":
		_shoot_bolt(e, index)
		return null
	var hit := damage * _power() * share
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
	if not brittle.is_empty():
		p.brittle = brittle
		p.shatter = shatter
	main.add_projectile(p)
	return p


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
	var c := care()
	var downed = null
	var hurt = null
	free_run = false
	if c == "danger":
		# Allies in danger first, wherever they are (its area doesn't hold it for them).
		var urgent = _pick_in_zone()
		if urgent != null:
			free_run = true
			rez_target = null
			_go_within_reach(urgent, delta)
			if cd_timer <= 0.0 and _ally_gap(urgent) <= attack_range:
				cd_timer = cooldown
				_heal(urgent)
			return
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
	# Someone to see to: it goes to them, enemies about or not (it only keeps its distance
	# from enemies when there's nobody to look after).
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
	if _kite(delta):
		return   # nobody to see to: backing off from an enemy, like the other ranged troops
	var d := position.distance_to(post)
	if d > 2.0:
		facing = position.direction_to(post)
		_move_toward(post, d, delta)
	else:
		_mend(max_hp * REGEN * delta)


## The ally in the worst danger (in danger, or calling for help), or null.
func _pick_in_zone():
	var best = null
	var best_frac := INF
	for w in main.get_warriors():
		if w == self or not w.is_active() or not (w.in_danger() or main.calling(w)):
			continue
		var frac: float = w.hp / w.max_hp
		if frac < best_frac:
			best_frac = frac
			best = w
	return best


## Channels a revival on a downed ally; it gets up once the revive time is done.
func _rez_step(downed, delta: float) -> void:
	rez_progress += delta
	downed.rez_held = 0.15   # (its dying time held while this goes on)
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


## A Ballista's bolt: loosed at e (and a little apart for a second or third), flying
## straight on to the end of its reach through everything in its line.
func _shoot_bolt(e, index: int) -> void:
	var b = preload("res://scripts/bolt.gd").new()
	b.main = main
	var from := _muzzle()
	var aim: Vector2 = e.position + Vector2(0, -6)
	var dir := from.direction_to(aim).rotated((index - (multishot - 1) / 2.0) * 0.06)
	b.position = from
	b.dir = dir
	b.dist_left = attack_range + 60.0
	b.speed = data["projectile_speed"]
	b.damage = damage * _power()
	b.air_mult = air_mult
	b.credit = xp_kind()
	b.knockback_chance = knockback_chance
	b.knockback_force = knockback_force
	b.impale = impale
	b.net = net
	b.air_crit = air_crit
	b.burn = burn
	b.corrode = corrode
	b.blast_end = blast_end
	main.add_projectile(b)


# --- The Arcane Obelisk's runes --------------------------------------------

const RUNE_COLORS := {"storm_rune": Color(0.55, 0.8, 1.0), "ray_rune": Color(1.0, 0.85, 0.4), "glyph_rune": Color(1.0, 0.45, 0.15),
	"rift_rune": Color(0.7, 0.4, 1.0)}


## Each rune carved into the Obelisk casts its own magic when it's ready, at what's in
## reach: lightning out of the sky (forking on, at Tempest), a prism ray through a line of
## enemies, a glyph of fire burned into the ground under the thickest crowd, and a rift that
## throws the enemy furthest down the field back toward its camp.
func _rune_step(delta: float) -> void:
	if build_left > 0.0 or not is_active():
		return
	for key in ["storm_rune", "ray_rune", "glyph_rune", "rift_rune"]:
		var r: Dictionary = get(key)
		if r.is_empty():
			continue
		rune_t[key] = rune_t.get(key, 0.5) - delta
		if rune_t[key] > 0.0:
			continue
		var inside: Array = main.enemies_near(position, attack_range + 40.0).filter(func(e): return _in_range(e))
		if inside.is_empty():
			rune_t[key] = 0.3
			continue
		rune_t[key] = float(r["cooldown"]) / _rate()
		swing = 0.25
		match key:
			"storm_rune":
				inside.shuffle()
				for e in inside.slice(0, int(r["count"])):
					var sky: Vector2 = e.position + Vector2(randf_range(-20, 20), -190)
					main.spawn_bolt(PackedVector2Array([sky, e.position]), RUNE_COLORS[key])
					main.spawn_flash(e.position, 26.0)
					e.take_damage(float(r["damage"]) * _power(), true, "magic")
					# Tempest: the bolt forks on to enemies near the one it struck.
					var from: Vector2 = e.position
					var struck := [e]
					for i in int(r.get("fork", 0)):
						var next = null
						for x in main.enemies_near(from, 90.0):
							if not x.dead and not struck.has(x) and (next == null or x.position.distance_to(from) < next.position.distance_to(from)):
								next = x
						if next == null:
							break
						main.spawn_bolt(PackedVector2Array([from, next.position]), RUNE_COLORS[key])
						next.take_damage(float(r["damage"]) * 0.5 * _power(), true, "magic")
						struck.append(next)
						from = next.position
				main.sfx("zap")
			"ray_rune":
				var from := position + Vector2(0, -44)
				var picked := [_pick(inside)]
				if int(r["count"]) > 1:
					var rest := inside.filter(func(e): return e != picked[0])
					if not rest.is_empty():
						picked.append(_pick(rest))
				for e in picked:
					var to: Vector2 = from + from.direction_to(e.position) * (attack_range + 60.0)
					main.spawn_beam(from, to, RUNE_COLORS[key], 14.0)
					for x in main.enemies_near((from + to) / 2.0, from.distance_to(to) / 2.0 + 30.0):
						if not x.dead and Geometry2D.get_closest_point_to_segment(x.position, from, to).distance_to(x.position) <= x.radius + 8.0:
							x.take_damage(float(r["damage"]) * _power(), true, "magic")
							if float(r["mark"]) > 0.0:
								x.apply_corrode(float(r["mark"]), 5.0)
				main.sfx("beam")
			"glyph_rune":
				# Under the thickest knots of enemies in reach (a second one elsewhere).
				var spots := []
				for i in int(r["count"]):
					var best = null
					var most := 0
					for e in inside:
						if e.flying or spots.any(func(p): return p.distance_to(e.position) < float(r["radius"]) * 1.5):
							continue
						var n := 0
						for x in inside:
							if x.position.distance_to(e.position) <= float(r["radius"]):
								n += 1
						if n > most:
							most = n
							best = e.position
					if best != null:
						spots.append(best)
				for p in spots:
					var g = preload("res://scripts/rune_glyph.gd").new()
					g.main = main
					g.position = p
					g.radius = float(r["radius"])
					g.dps = float(r["dps"]) * _power()
					g.duration = float(r["duration"])
					g.burst = float(r["burst"]) * _power()
					g.burn = float(r.get("burn", 0.0)) * _power()
					g.credit = xp_kind()
					main.corpse_layer.add_child(g)
				if spots.is_empty():
					rune_t[key] = 0.3
				else:
					main.sfx("flame")
			"rift_rune":
				# The enemies furthest down the field (bosses can't be moved).
				var movable := inside.filter(func(e): return not e.boss and not e.dead)
				movable.sort_custom(func(a, b): return a.position.y > b.position.y)
				for e in movable.slice(0, int(r["count"])):
					var was: Vector2 = e.position
					var to := Vector2(was.x, maxf(main.DEPLOY_TOP + 10.0, was.y - float(r["push"])))
					if e.on_ground and main.paths.has_terrain():
						to = main.paths.open_spot(to)
					main.spawn_flash(was, 22.0)
					main.spawn_burst(was, 24.0, RUNE_COLORS[key])
					e.position = to
					main.spawn_burst(to, 24.0, RUNE_COLORS[key])
					if float(r["damage"]) > 0.0:
						e.take_damage(float(r["damage"]) * _power(), true, "magic")
					if float(r["sick"]) > 0.0:
						e.apply_corrode(float(r["sick"]), 4.0)
				if movable.is_empty():
					rune_t[key] = 0.3
				else:
					main.sfx("spell")


# --- Support emplacements -----------------------------------------------

func _support_update(delta: float) -> void:
	match data["attack"]:
		"perch":
			# A Tower: its masons mend it while a wave is on.
			if tower_repair > 0.0 and main.fighting() and hp < max_hp:
				_mend(tower_repair * delta)
		"rune":
			_rune_step(delta)
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
		var aim := _around_enemies(w.position)
		_chase_move(aim, minf(gap - attack_range + 1.0, position.distance_to(aim)), delta)


## A way toward `dest` that steps round any enemy standing in the way (rather than
## walking into it): `dest` itself if the way's clear.
func _around_enemies(dest: Vector2) -> Vector2:
	var dir := position.direction_to(dest)
	var dist := position.distance_to(dest)
	var steer := Vector2.ZERO
	for e in main.enemies_near(position, 90.0):
		if e.dead or e.flying:
			continue
		var to_e: Vector2 = e.position - position
		var ahead := to_e.dot(dir)
		if ahead <= 0.0 or ahead > minf(dist, 90.0):
			continue   # behind it, or past where it's going
		var lateral := to_e - dir * ahead
		var clear: float = RADIUS + e.radius + 12.0
		if lateral.length() >= clear:
			continue
		var side := -lateral.normalized() if lateral.length() > 0.5 else dir.orthogonal()
		steer += side * (clear - lateral.length()) / clear
	if steer == Vector2.ZERO:
		return dest
	return position + (dir + steer * 1.4).normalized() * minf(dist, 60.0)


## Whether a Healer may go to `w`: it can reach it from its zone (always, roaming free).
func _ally_in_zone(w) -> bool:
	return not zoned() or rect_gap(zone_rect(), w.position) - RADIUS * 2.0 <= attack_range


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
	# A revival under way is seen through (its time's held, so it'd look the least urgent).
	if rez_target != null and is_instance_valid(rez_target) and rez_progress > 0.0 and not rez_target.is_active() \
			and not rez_target.is_queued_for_deletion() and rez_target.down_timer > 0.0 and (pool.is_empty() or pool.has(rez_target)):
		return rez_target
	# Those another Healer (or Medic Bay) is reviving already: left to it, for the others.
	var taken := {}
	for o in main.get_warriors():
		if o != self and o.rez_target != null and o.is_active() and is_instance_valid(o.rez_target):
			taken[o.rez_target] = true
	for w in (pool if not pool.is_empty() else main.get_warriors()):
		if w == self or w.is_active() or w.is_queued_for_deletion() or w.broken or w.down_timer <= 0.0 or not _ally_in_zone(w):
			continue   # (a broken Tower, or one going up, isn't one to revive)
		if taken.has(w):
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
	if barrage_left > 0:
		_barrage_step(delta)
	if not shard.is_empty():
		_shard_step(delta)
	if not ward.is_empty():
		_ward_step(delta)
	if data.get("pike", false):
		_pike_step(delta)
	elif kind == "assassin":
		_assassin_step(delta)
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
		if golden.has("heal"):
			_mend(max_hp * float(golden["heal"]))   # (a second wind as it goes golden)
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
	if not main.fighting():
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
	if not main.fighting():
		multiform_timer = 0.0
		return
	multiform_timer = maxf(multiform_timer - delta, 0.0)
	if multiform_timer > 0.0 or not _in_combat() or _clones().size() >= int(multiform["copies"]):
		return
	multiform_timer = multiform["cooldown"]
	var side := Vector2(-facing.y, facing.x) if facing != Vector2.ZERO else Vector2.RIGHT
	var spot := _clear_of_walls(_zone_clamp(position + side * RADIUS * 2.2), position)   # (inside its zone)
	if garrison != null and is_instance_valid(garrison):
		spot = main.paths.open_spot(garrison.position + Vector2(0, 40))   # (up a Tower: the copy steps down at its foot)
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


## Trapcraft: every so often (standing still or not) sets a charge where the enemy's
## heading: a little way along the route the nearest ones are walking (the enemies' own
## flow field, so through the gaps and round the rock they really take), more so where
## several are coming and in a tight spot (a gap, a cliff foot). Never right under a foe
## (it must have time to arm), never on rock or out of its throw, never on another charge.
## At its limit it waits, unless the oldest charge has been left far behind.
func _trap_step(delta: float) -> void:
	my_traps = my_traps.filter(func(t): return is_instance_valid(t) and not t.is_queued_for_deletion())
	trap_timer -= delta
	if trap_timer > 0.0:
		return
	if my_traps.size() >= int(traps["max"]):
		var oldest = my_traps[0]
		if oldest.position.distance_to(position) < TRAP_LEFT_BEHIND:
			trap_timer = TRAP_LOOK
			return
		my_traps.pop_front().queue_free()   # (one left far behind is taken up again)
	var at := _trap_spot()
	if at == Vector2.INF:
		trap_timer = TRAP_LOOK   # (nowhere worth it yet: look again shortly)
		return
	_lay_trap(at)
	swing = 0.12


## Dodging a warned blow, it leaves a charge where it stood, if one's ready: an ordinary
## charge (the same cooldown and limit), not an extra one.
func _trap_behind() -> void:
	my_traps = my_traps.filter(func(t): return is_instance_valid(t) and not t.is_queued_for_deletion())
	if trap_timer > 0.0 or my_traps.size() >= int(traps["max"]) or not _trap_ok(position):
		return
	_lay_trap(position)


func _trap_spot() -> Vector2:
	var reach := attack_range
	var foes: Array = main.enemies_near(position, reach + TRAP_AHEAD + 40.0).filter(func(e): return not e.dead and not e.flying)
	if foes.is_empty():
		return Vector2.INF
	foes.sort_custom(func(a, b): return a.position.distance_to(position) < b.position.distance_to(position))
	var best := Vector2.INF
	var best_score := 0.0
	for e in foes.slice(0, TRAP_CANDIDATES):
		# Along its way: a few steps of the route it's on.
		var p: Vector2 = e.position
		for i in 3:
			var dir: Vector2 = main.paths.direction(p, e.radius)
			if dir == Vector2.ZERO:
				dir = Vector2.DOWN if e.heading == Vector2.ZERO else e.heading
			p += dir * (TRAP_AHEAD / 3.0)
		if p.distance_to(position) > reach or not _trap_ok(p):
			continue
		var score := 1.0
		for f in foes:
			if f.position.distance_to(p) < TRAP_CROWD:
				score += 1.0
		if main.paths.has_terrain() and main.paths.tight(p, 14.0):
			score += 1.5   # (a gap they must all come through)
		score -= p.distance_to(position) / 400.0
		if score > best_score:
			best_score = score
			best = p
	return best


func _trap_ok(p: Vector2) -> bool:
	if p.y < main.DEPLOY_TOP or p.x < RADIUS or p.x > main.FIELD_W - RADIUS or p.y > main.CASTLE_Y - RADIUS:
		return false
	if main.paths.has_terrain() and main.paths.blocked(p, 8.0):
		return false
	for t in my_traps:
		if is_instance_valid(t) and t.position.distance_to(p) < TRAP_GAP:
			return false
	for e in main.enemies_near(p, 60.0):
		if not e.dead and not e.flying and e.position.distance_to(p) < e.radius + TRAP_CLEAR:
			return false   # (not under a foe: it has to arm first)
	return true


func _lay_trap(at: Vector2) -> void:
	trap_timer = float(traps["every"])
	var t := Trap.new()
	t.main = main
	t.damage = traps["damage"] * _power()
	t.radius = traps["radius"]
	t.stun = traps["stun"]
	t.slow = traps.get("slow", [])
	t.source = get_instance_id()
	t.credit = xp_kind()
	if traps["brew"]:
		t.poison = poison
		t.corrode = corrode
	t.position = at
	main.add_projectile(t)
	my_traps.append(t)
	if at.distance_to(position) > RADIUS * 2.0:
		main.spawn_beam(position + Vector2(0, -16), at, Color(0.9, 0.6, 0.3, 0.6), 2.0)   # (thrown out)


# --- Pikeman ------------------------------------------------------------------------------

## Whether `e` is in front of it, within `arc` (radians) of the way it faces.
func _in_front(e, arc: float) -> bool:
	var to: Vector2 = e.position - position
	return to.length() < 1.0 or absf(facing.angle_to(to)) <= arc


## Coming on: walking, and closing on it (straight at it, or running past through its
## reach: a wolf slipping by is caught as surely as one charging it).
func _coming_on(e) -> bool:
	if not e.walking:
		return false
	var to: Vector2 = position - e.position
	return to.length() > 1.0 and e.heading.dot(to.normalized()) > COMING_ON


func pike_braced() -> bool:
	return data.get("pike", false) and still_t >= PIKE_SET and dazed <= 0.0 and is_active()


## Its blows (and its own taken): a melee blow from `foe` in front of it, while braced with
## Hold Fast or at an ally's shoulder (Phalanx), lands for less (the better one: no stacking).
func _pike_guard(amount: float) -> float:
	var foe = main.hurt_by
	if foe == null or not is_instance_valid(foe) or not _in_front(foe, 1.2):
		return amount
	var cut := 0.0
	if not hold.is_empty() and pike_braced():
		cut = float(hold["dr"])
	if not phalanx.is_empty() and shoulder:
		cut = maxf(cut, float(phalanx["dr"]))
	return amount * (1.0 - cut)


## A thrust: Readied Pike (or Spearwall's braced one) on a foe charging in; too close
## inside its reach, weaker; Impaler's point, puncture and fourth thrust. Returns the blow.
func _pike_hit(e, hit: float) -> float:
	var id: int = e.get_instance_id()
	var base := hit
	if _gap_to(e) < PIKE_CLOSE:
		hit *= PIKE_CLOSE_HIT   # (a foe inside its point: the haft's all it has)
	if not hardened.is_empty():
		hit *= 1.0 + float(hardened["bonus"])   # (enemies wear no armour: the harder point bites deeper)
	# Readied: braced, a foe coming on from in front, not one it's caught a moment ago.
	if still_t >= PIKE_SET and not pike_seen.has(id) and _coming_on(e) and _in_front(e, float(brace.get("arc", 0.75))):
		var mult: float = float(brace["mult"]) if not brace.is_empty() else PIKE_READY
		hit *= mult
		pike_seen[id] = PIKE_AGAIN
		_intercepted(e)
		main.spawn_burst(e.position, 16.0, Color(0.85, 0.9, 1.0))
		if not brace.is_empty():
			main.spawn_text(position + Vector2(0, -44), "Braced!", Color(0.8, 0.88, 1.0))
			cd_timer_scale = float(brace["recover"])
			# Hedge of Points: the next ones coming on, in reach, for less.
			var more := int(brace["targets"]) - 1
			if more > 0:
				for o in main.enemies_near(position, attack_range + 40.0):
					if more <= 0:
						break
					if o == e or o.dead or o.flying or pike_seen.has(o.get_instance_id()) or _gap_to(o) > attack_range + HEDGE_SLACK:
						continue
					if not _coming_on(o) or not _in_front(o, float(brace["arc"])):
						continue
					pike_seen[o.get_instance_id()] = PIKE_AGAIN
					o.take_damage(base * mult * float(brace["side"]))
					_intercepted(o)
					_hit_spark(o)
					more -= 1
	# Deep Thrust: deeper each thrust on the same foe.
	if not puncture.is_empty():
		if punct_id != id or punct_t <= 0.0:
			punct_id = id
			punct_n = 0
		hit *= 1.0 + float(puncture["per"]) * punct_n
		punct_n = mini(punct_n + 1, int(puncture["max"]))
		punct_t = float(puncture["time"])
	# Impaling Strike: every fourth thrust in a row on one foe.
	if not impaling.is_empty():
		if seq_id != id or seq_t <= 0.0:
			seq_id = id
			seq_n = 0
		seq_n += 1
		seq_t = SEQ_TIME
		if seq_n % int(impaling["every"]) == 0:
			hit *= float(impaling["mult"])
			if float(impaling["pct"]) > 0.0:
				hit += minf(e.max_hp * float(impaling["pct"]), float(impaling["cap"])) * (0.5 if e.boss else 1.0)
			if not e.boss:
				e.apply_stun(0.15)   # (whatever it was doing, broken off: a stun breaks a spell; a Warlord barely feels it)
			_hold_pose("strike", 0.25)
			main.spawn_text(position + Vector2(0, -44), "Impaled!", Color(1.0, 0.75, 0.5))
			main.spawn_burst(e.position, 22.0, Color(1.0, 0.8, 0.6))
	return hit


## A foe caught charging in: slowed (Set Spears), staggered (Hold Fast), pinned (No Passage).
func _intercepted(e) -> void:
	if brace.is_empty() or e.dead:
		return
	var sl: Array = brace["slow"]
	e.apply_slow(sl[0], sl[1])
	if float(brace["stagger"]) > 0.0:
		e.apply_stun(float(brace["stagger"]))   # (cc_mult: a boss barely staggers)
	if float(brace["pin"]) > 0.0:
		e.pin(float(brace["pin"]))


## Every frame (from _special_update): how long it's stood braced, its Phalanx place, and the
## Hook & Shove moves, each on its own cooldown.
func _pike_step(delta: float) -> void:
	still_t = 0.0 if moving or dash_left > 0.0 else still_t + delta
	for id in pike_seen.keys():
		pike_seen[id] -= delta
		if pike_seen[id] <= 0.0:
			pike_seen.erase(id)
	punct_t = maxf(punct_t - delta, 0.0)
	seq_t = maxf(seq_t - delta, 0.0)
	support_t = maxf(support_t - delta, 0.0)
	haft_t = maxf(haft_t - delta, 0.0)
	hook_t = maxf(hook_t - delta, 0.0)
	defend_t = maxf(defend_t - delta, 0.0)
	sweep_t = maxf(sweep_t - delta, 0.0)
	phal_check -= delta
	if phal_check <= 0.0:
		phal_check = 0.25
		_phalanx_check()
	ready_t = maxf(ready_t - delta, 0.0)
	# Readied: braced, a fresh foe coming into reach gets the point at once (the thrust he
	# was holding back for it), whatever his last thrust was; once a foe, not too often.
	if still_t >= PIKE_SET and ready_t <= 0.0 and cd_timer > 0.0 and is_active() and dazed <= 0.0 and garrison == null:
		for e in main.enemies_near(position, attack_range + 40.0):
			if e.dead or e.flying or pike_seen.has(e.get_instance_id()) or _gap_to(e) > attack_range:
				continue
			if not _coming_on(e) or not _in_front(e, float(brace.get("arc", 0.75))):
				continue
			cd_timer = 0.0
			ready_t = READY_AGAIN
			_set_target(e)
			facing = position.direction_to(e.position)
			break
	if haft.is_empty() and hook.is_empty() and defend.is_empty() and sweep.is_empty():
		return
	if not is_active() or dazed > 0.0 or garrison != null:
		return
	guard_check -= delta
	if guard_check <= 0.0:
		guard_check = 0.5
		guarded = _guarded_spots()
	var near: Array = main.enemies_near(position, attack_range + RADIUS + 50.0).filter(func(x): return not x.dead and not x.flying)
	if near.is_empty():
		return
	# Haft Check: a foe right inside its point gets the butt of the haft.
	if not haft.is_empty() and haft_t <= 0.0:
		for e in near:
			if _gap_to(e) < PIKE_CLOSE + 2.0:
				haft_t = float(haft["every"])
				e.take_damage(damage * 0.5 * _power())
				if not e.dead:
					e.apply_knockback(position.direction_to(e.position) * float(haft["push"]))
					e.apply_slow(haft["slow"][0], haft["slow"][1])
				_hold_pose("strike", 0.15)
				swing = 0.12
				break
	# Hooked Spear: a foe at one of its charges is hooked and dragged off them.
	if not hook.is_empty() and hook_t <= 0.0 and not guarded.is_empty():
		for e in near:
			if _gap_to(e) > attack_range + 4.0:
				continue
			var at = _guarded_near(e.position, 70.0)
			if at == null:
				continue
			hook_t = float(hook["every"])
			var away: Vector2 = (e.position - at).normalized() if e.position.distance_to(at) > 1.0 else Vector2.UP
			e.apply_knockback(away * float(hook["move"]))
			if e.knock_mult < 0.5 or e.boss:
				e.apply_slow(0.3, 1.0)   # (too big to drag: it's held up a moment instead)
			main.spawn_beam(position + Vector2(0, -14), e.position, Color(0.7, 0.6, 0.45), 3.0)
			swing = 0.12
			break
	# Defender's Reach: a foe going past it for one of its charges.
	if not defend.is_empty() and defend_t <= 0.0 and not guarded.is_empty():
		for e in near:
			if _gap_to(e) > attack_range + 18.0 or e.aggro == self:
				continue
			var at = _guarded_near(e.position, 160.0)
			if at == null or e.heading.dot(e.position.direction_to(at)) < 0.6:
				continue
			defend_t = float(defend["every"])
			facing = position.direction_to(e.position)
			e.take_damage(damage * float(defend["mult"]) * _power())
			if not e.dead:
				var away: Vector2 = (e.position - at).normalized() if e.position.distance_to(at) > 1.0 else Vector2.UP
				e.apply_knockback(away * float(defend["push"]))
			_hold_pose("strike", 0.2)
			swing = 0.15
			main.spawn_text(position + Vector2(0, -44), "Denied!", Color(0.8, 0.9, 1.0))
			break
	# Breakthrough Denied: several at it (or its charges): one sweep throws them back.
	if not sweep.is_empty() and sweep_t <= 0.0:
		var front: Array = near.filter(func(x): return _gap_to(x) <= attack_range + 12.0 and _in_front(x, 1.3))
		if front.size() >= 2:
			sweep_t = float(sweep["every"])
			front.sort_custom(func(a, b): return _gap_to(a) < _gap_to(b))
			for e in front.slice(0, int(sweep["targets"])):
				e.take_damage(damage * float(sweep["damage"]) * _power())
				if not e.dead:
					e.apply_knockback(position.direction_to(e.position) * float(sweep["push"]))
					e.apply_slow(sweep["slow"][0], sweep["slow"][1])
			main.spawn_burst(position + facing * 24.0, attack_range + 10.0, Color(0.85, 0.88, 0.95))
			main.sfx("slash", 0.7)
			_hold_pose("strike", 0.25)
			swing = 0.2


## Phalanx: a melee ally at its shoulder (beside it, about level, a little way off), and
## one in front of it (it fights from the second rank: Overlapping Spears' reach).
func _phalanx_check() -> void:
	shoulder = false
	backed = false
	if phalanx.is_empty():
		attack_range = pike_range
		return
	for w in main.warriors_near(position, 60.0):
		if w == self or not w.is_active() or w.is_emplacement() or not (w.is_melee() or w.data.get("attack", "") == "combo"):
			continue
		var off: Vector2 = w.position - position
		var ahead := off.dot(facing)
		var across := absf(off.dot(facing.orthogonal()))
		if off.length() <= 44.0 and absf(ahead) < 18.0 and across > 20.0:
			shoulder = true
		if ahead > 12.0 and across < 30.0 and off.length() <= 56.0:
			backed = true
	attack_range = pike_range + (float(phalanx["reach"]) if backed else 0.0)


## Second Rank: an ally in front of it struck `e`; it thrusts too if `e`'s in its reach
## (with a clear thrust past them: no wall in the way), once each cooldown.
func support_thrust(ally, e) -> void:
	if phalanx.is_empty() or float(phalanx["support"]) <= 0.0 or support_t > 0.0 or not is_active() or dazed > 0.0:
		return
	if not is_instance_valid(e) or e.dead or e.flying or _gap_to(e) > attack_range + 2.0 or main.paths.any_wall_between(position, e.position):
		return
	support_t = float(phalanx["every"])
	facing = position.direction_to(e.position)
	e.take_damage(damage * float(phalanx["support"]) * _power())
	_hold_pose("strike", 0.15)
	_hit_spark(e)


## Hook & Shove: where the troops and objectives it covers stand (its ranged and support
## allies near it, and the objectives the enemy's after).
func _guarded_spots() -> Array:
	var out := []
	for w in main.warriors_near(position, 150.0):
		if w != self and w.is_active() and not w.is_melee() and w.data.get("attack", "") != "combo" and not w.is_emplacement():
			out.append(w.position)
	for o in main.rules.objectives():
		if is_instance_valid(o) and o.is_target() and o.position.distance_to(position) < 220.0:
			out.append(o.position)
	return out


func _guarded_near(p: Vector2, r: float):
	var best = null
	var best_d := r
	for g in guarded:
		var d: float = g.distance_to(p)
		if d < best_d:
			best_d = d
			best = g
	return best


# --- Assassin -------------------------------------------------------------------------------

## Whether this troop can be seen by enemy `e` looking `r` out: lost in its smoke (save
## right beside it), or with Leafstep, out of the fight, only nearer.
func unseen_by(e, r := INF) -> bool:
	if kind != "assassin":
		return false
	var d: float = e.position.distance_to(position)
	if smoke_hide > 0.0 and d > SMOKE_SEEN:
		return true
	if r < INF and sneaking():
		var detect: float = SNEAK_DETECT * (float(leafstep["detect"]) if not leafstep.is_empty() else 1.0)
		if d > minf(r * detect, SNEAK_SEEN * (float(leafstep["detect"]) if not leafstep.is_empty() else 1.0)):
			return true   # (a long bow or a spell reaches far, but nothing spots a stalker far off)
	return false


## Out of the fight a moment (or just out of its smoke), stalking: foes notice it late, and
## the ones it slips past don't stop to fight it unless it's after them.
func sneaking() -> bool:
	return kind == "assassin" and is_active() and (rest_t >= REST_UNSEEN or stealth_t > 0.0)


## Whether foe `e` lets it slip by: it's stalking something else.
func slips_past(e) -> bool:
	return sneaking() and target != e and target != null


## How much faster it moves just now (Leafstep out of the fight, Ghost Trail out of smoke).
func speed_mult() -> float:
	var m := 1.0
	if not leafstep.is_empty() and rest_t >= REST_UNSEEN:
		m += float(leafstep["speed"])
	if haste_t > 0.0:
		m += GHOST_SPEED
	return m


## A cut: the opening strike (Ambush, or the Opportunist's), a Deathblow, the Execution
## bonuses; and Sabotage on what it hits. Returns the blow.
func _assassin_hit(e, hit: float) -> float:
	var id: int = e.get_instance_id()
	var special := 1.0
	var facing_me: bool = e.aggro == self or (e.last_foe == self and e.last_foe_t > 0.0)
	var unwary: bool = e.busy_with_other(self) or (position - e.position).dot(e.facing_dir()) < 0.0 or not facing_me
	var rest: float = float(ambush["rest"]) if not ambush.is_empty() else OPENER_REST
	if (since_strike >= rest or smoke_ambush) and unwary:
		# The opening strike: stalked up to, unseen or busy (Ambush: harder, and it can chain).
		special = float(ambush["mult"]) if not ambush.is_empty() else SNEAK_OPENER
		opening = true
		smoke_ambush = false
		main.spawn_text(position + Vector2(0, -46), "Backstab!" if ambush.is_empty() or int(ambush["chain"]) <= 1 else "Ambush!", Color(0.6, 1.0, 0.6))
		main.spawn_burst(e.position + Vector2(0, -e.radius), 16.0, Color(0.75, 1.0, 0.75))
	elif e.busy_with_other(self) and not opp_seen.has(id):
		special = OPPORTUNIST
		opp_seen[id] = OPP_AGAIN
	if not deathblow.is_empty() and death_t <= 0.0 and e.hp <= e.max_hp * float(deathblow["below"]):
		var m: float = float(deathblow["boss"]) if e.boss else float(deathblow["mult"])
		if m > special:
			special = m
			opening = false
		death_t = float(deathblow["every"])
		_hold_pose("strike", 0.25)
		main.spawn_text(position + Vector2(0, -46), "Deathblow!", Color(1.0, 0.45, 0.4))
	var bonus := 0.0
	var wounded: bool = e.hp < e.max_hp * 0.5
	if not scent.is_empty() and e.hp < e.max_hp * float(scent["below"]):
		bonus += float(scent["bonus"])
	if not relentless.is_empty():
		if rel_id != id or rel_t <= 0.0 or not wounded:
			rel_id = id
			rel_n = 0
		if wounded:
			bonus += float(relentless["per"]) * rel_n
			rel_n = mini(rel_n + 1, int(relentless["max"]))
			rel_t = float(relentless["time"])
	if mom_left > 0.0 and id != mom_from:
		bonus += float(deathblow["momentum"])
		mom_left = 0.0
	if exposed_id == id and exposed_t > 0.0:
		bonus += float(ambush.get("expose", 0.0))   # (Vital Strike: its guard down against this one)
	opening_hp = e.hp / maxf(e.max_hp, 1.0)
	since_strike = 0.0
	return hit * special * (1.0 + bonus)


var opening := false         # this blow was an Ambush opener (a kill can chain)
var opening_hp := 1.0        # the foe's health share before the blow
var exposed_id := 0          # Vital Strike: the foe whose guard is down against it...
var exposed_t := 0.0         # ...for this long


## After a cut landed: Sabotage (set back, break off, black out what it's readying), Vital
## Strike, and on a kill: the chain, the smoke back sooner, Killing Momentum.
func _after_assassin_hit(e) -> void:
	if opening and not ambush.is_empty() and float(ambush["expose"]) > 0.0 and is_instance_valid(e) and not e.dead:
		exposed_id = e.get_instance_id()
		exposed_t = VITAL_TIME
	if is_instance_valid(e) and not e.dead:
		_sabotage(e)
	var killed: bool = not is_instance_valid(e) or e.dead
	if killed:
		_on_kill(e)
		if opening and int(ambush.get("chain", 1)) > 1 and chain_t <= 0.0:
			chain_t = float(ambush["every"])
			chain_mults = (ambush["next"] as Array).duplicate()
			chain_kills = 1
			_chain_next(e.position if is_instance_valid(e) else position)
	opening = false


## Sabotage on a foe getting ready for something: Spell Sever breaks it off (each foe once per
## its cooldown), else Disruptive Cut sets it back; either way, Blackout after.
func _sabotage(e) -> bool:
	if not e.readying():
		return false
	var done := false
	if not sever.is_empty() and e.sever_cd <= 0.0:
		e.sever_cd = float(sever["every"])
		e.sever()
		done = true
	elif not disrupt.is_empty() and e.delay_cd <= 0.0:
		e.delay_cd = float(disrupt["every"])
		done = e.delay_windup(float(disrupt["delay"]))
	if done and not blackout.is_empty():
		e.apply_blackout(float(blackout["time"]), float(blackout["immune"]))
	return done


func _on_kill(e) -> void:
	var valuable: bool = VALUE.get(e.kind, 0.0) >= 3.0 or e.tier >= 4
	if not smoke.is_empty() and float(smoke["refund"]) > 0.0 and valuable and refund_cd <= 0.0:
		smoke_t = maxf(smoke_t - float(smoke["refund"]), 0.0)
		refund_cd = REFUND_AGAIN
	if not deathblow.is_empty() and float(deathblow["momentum"]) > 0.0 and opening_hp <= float(deathblow["below"]) and mom_cd <= 0.0:
		mom_left = MOMENTUM_TIME
		mom_from = e.get_instance_id() if is_instance_valid(e) else 0
		mom_cd = MOMENTUM_AGAIN


## Chain Assassination: after a kill, the next foe within reach of the fallen one (one it
## can get at: no wall, no rock between; the likeliest to fall to the next strike first),
## lunged at. None, or no strikes left: the chain's over (Silent Reaper: two or more killed,
## the weak round it falter).
func _chain_next(at: Vector2) -> void:
	var best = null
	var best_score := -INF
	if not chain_mults.is_empty():
		var reach: float = ambush["reach"]
		var mult: float = chain_mults[0]
		var strike: float = damage * _power() * mult
		for o in main.enemies_near(at, reach + 40.0):
			if o.dead or o.flying or o.position.distance_to(at) - o.radius > reach:
				continue
			if main.paths.path_blocked(position, o.position, RADIUS) or main.paths.any_wall_between(position, o.position):
				continue
			var score: float = (100.0 if o.hp <= strike else 0.0) + VALUE.get(o.kind, 0.0) * 10.0 - o.position.distance_to(at) * 0.1
			if score > best_score:
				best_score = score
				best = o
	if best == null:
		if chain_kills >= 2 and float(ambush.get("fear", 0.0)) > 0.0:
			for o in main.enemies_near(at, FEAR_REACH):
				if not o.dead and o.position.distance_to(at) <= FEAR_REACH:
					o.falter(float(ambush["fear"]))
			main.spawn_burst(at, FEAR_REACH * 0.6, Color(0.3, 0.45, 0.3))
		chain_mults.clear()
		return
	lunge_mult = chain_mults.pop_front()
	lunge_target = best
	var dir := position.direction_to(best.position)
	lunge_to = best.position - dir * (RADIUS + best.radius)
	lunge_left = LUNGE_TIME
	facing = dir
	main.spawn_burst(position + Vector2(0, RADIUS), 12.0, Color(0.35, 0.5, 0.35))


## Mid-lunge: a few quick steps in, then the strike. It's no less in harm's way for it.
func _lunge_step(delta: float) -> void:
	var left := lunge_left
	lunge_left = maxf(lunge_left - delta, 0.0)
	_step_to(position.lerp(lunge_to, minf(delta / left, 1.0)))
	moving = true
	walk += 0.5
	if lunge_left > 0.0:
		return
	var e = lunge_target
	lunge_target = null
	if not _is_valid(e):
		chain_mults.clear()
		return
	facing = position.direction_to(e.position)
	swing = 0.12
	_hold_pose("strike", 0.15)
	var hit := damage * _power() * lunge_mult
	if not scent.is_empty() and e.hp < e.max_hp * float(scent["below"]):
		hit *= 1.0 + float(scent["bonus"])
	e.take_damage(hit)
	_hit_spark(e)
	main.sfx("slash", 1.35)
	main.spawn_text(position + Vector2(0, -46), "Chain!", Color(0.6, 1.0, 0.6))
	if not is_instance_valid(e) or e.dead:
		chain_kills += 1
		_on_kill(e)
		_chain_next(e.position if is_instance_valid(e) else lunge_to)
	else:
		chain_mults.clear()   # (it lived: the chain's over...)
		_chain_next(e.position)   # (...and if two fell already, the weak round them falter)


## Every frame (from _special_update): its timers, the kunai, the smoke.
func _assassin_step(delta: float) -> void:
	rest_t += delta
	since_strike += delta
	for id in opp_seen.keys():
		opp_seen[id] -= delta
		if opp_seen[id] <= 0.0:
			opp_seen.erase(id)
	chain_t = maxf(chain_t - delta, 0.0)
	kunai_t = maxf(kunai_t - delta, 0.0)
	smoke_t = maxf(smoke_t - delta, 0.0)
	smoke_hide = maxf(smoke_hide - delta, 0.0)
	stealth_t = maxf(stealth_t - delta, 0.0)
	haste_t = maxf(haste_t - delta, 0.0)
	refund_cd = maxf(refund_cd - delta, 0.0)
	rel_t = maxf(rel_t - delta, 0.0)
	death_t = maxf(death_t - delta, 0.0)
	mom_left = maxf(mom_left - delta, 0.0)
	mom_cd = maxf(mom_cd - delta, 0.0)
	exposed_t = maxf(exposed_t - delta, 0.0)
	if not is_active() or dazed > 0.0 or garrison != null:
		return
	if not kunai.is_empty() and kunai_t <= 0.0:
		_throw_kunai()
	if not smoke.is_empty() and smoke_t <= 0.0 and _hard_pressed():
		_smoke_out()


## Hidden Kunai: at the nearest foe in reach that's readying a shot, a spell or a special.
func _throw_kunai() -> void:
	var r: float = kunai["range"]
	var best = null
	var best_d := INF
	for e in main.enemies_near(position, r + 30.0):
		if e.dead or not e.readying() or e.delay_cd > 0.0:
			continue
		var d := position.distance_to(e.position)
		if d <= r and d < best_d and main.paths.sight_clear(position, e.position):
			best_d = d
			best = e
	if best == null:
		kunai_t = 0.3
		return
	kunai_t = float(kunai["every"])
	var p := Projectile.new()
	p.main = main
	p.target = best
	p.target_pos = best.position
	p.position = position + Vector2(0, -14)
	p.damage = damage * _power() * float(kunai["share"])
	p.speed = 620.0
	p.style = "kunai"
	p.color = Color(0.85, 0.88, 0.95)
	p.credit = xp_kind()
	p.source = get_instance_id()
	p.sabotage = float(kunai["delay"])
	p.saboteur = self
	main.add_projectile(p)
	facing = position.direction_to(best.position)
	swing = 0.12
	_hold_pose("strike", 0.12)
	main.sfx("bow", 1.6)


## The kunai's struck: set back what it was readying (once per its cooldown), Blackout too.
func kunai_struck(e, delay: float) -> void:
	if not is_instance_valid(e) or e.dead or e.delay_cd > 0.0:
		return
	e.delay_cd = float(kunai.get("every", 8.0))
	if e.delay_windup(delay) and not blackout.is_empty():
		e.apply_blackout(float(blackout["time"]), float(blackout["immune"]))


## Surrounded (SMOKE_CROWD foes on it), or hurt and still being hit.
func _hard_pressed() -> bool:
	if target != null and _is_valid(target) and _gap_to(target) <= attack_range + 6.0 and target.hp <= damage * _power() * FINISH_CUTS:
		return false   # (its mark's in reach and all but dead: finish it first)
	if hp < max_hp * SMOKE_HURT and danger_t > 0.0:
		return true
	var n := 0
	for e in main.enemies_near(position, SMOKE_NEAR + 30.0):
		if not e.dead and not e.flying and _gap_to(e) < SMOKE_NEAR:
			n += 1
	return n >= SMOKE_CROWD


## Smoke Pellet: a cloud where it stands; the foes on it lose it (Ghost Trail: two of them
## go after a decoy left in the smoke instead); it slips away to open ground; and with
## Ambush, the next strike can be an opener again.
func _smoke_out() -> void:
	smoke_t = float(smoke["every"])
	smoke_hide = float(smoke["lose"])
	stealth_t = float(smoke["linger"]) + float(smoke["lose"])
	if not ambush.is_empty():
		smoke_ambush = true
	var cloud = preload("res://scripts/smoke.gd").new()
	cloud.main = main
	cloud.position = position
	cloud.life = float(smoke["time"])
	cloud.total = cloud.life
	main.add_projectile(cloud)
	var decoy = null
	if smoke["decoy"]:
		decoy = preload("res://scripts/smoke.gd").new()
		decoy.main = main
		decoy.decoy = true
		decoy.position = position
		decoy.life = float(smoke["time"])
		decoy.total = decoy.life
		decoy.flip = flip
		decoy.look = Sprites.frames(sprite_name())[0]
		main.add_projectile(decoy)
		haste_t = GHOST_SPEED_TIME + float(smoke["lose"])
	var lured := 0
	var mid := Vector2.ZERO
	var n := 0
	for e in main.enemies_near(position, AGGRO_SMOKE):
		if e.dead:
			continue
		mid += e.position
		n += 1
		if e.aggro == self:
			if decoy != null and lured < DECOY_LURES:
				e.aggro = decoy
				e.aggro_check = float(smoke["time"])
				lured += 1
			else:
				e.aggro = null
				e.aggro_check = float(smoke["lose"])
	# Away from them, to open ground it can stand on, in its area.
	var away: Vector2 = (position - mid / n).normalized() if n > 0 and position.distance_to(mid / n) > 1.0 else Vector2.DOWN
	var to: Vector2 = _zone_clamp(main._clamp_post(position + away * SMOKE_RUN))
	if not main.paths.has_terrain() or main.paths.troop_can_stand(to):
		escape_to = to
		escape_left = float(smoke["lose"])
	_set_target(null)
	combo_left = 0
	main.sfx("frost", 0.6)
	main.spawn_text(position + Vector2(0, -46), "Smoke!", Color(0.75, 0.78, 0.78))


## High-value targets are often behind a crowd: the way in goes round its side, while it's
## still a way off (worked out twice a second).
func _flank_point(e) -> Vector2:
	if e.cast_state == "flame" or (e.cast_state == "charge" and e.cast_spell == "fire"):
		# A Horde Mage pouring fire (or about to): round its side, out of the stream, and in
		# once it's done, rather than walking down the flames.
		var aim: Vector2 = e.lunge_dir if e.lunge_dir != Vector2.ZERO else e.position.direction_to(position)
		var side: Vector2 = aim.orthogonal() * (1.0 if aim.orthogonal().dot(position - e.position) >= 0.0 else -1.0)
		return main._clamp_post(e.position + side * FLANK_WIDE * 1.4)
	flank_check -= get_process_delta_time()
	if flank_check > 0.0 and flank_at != Vector2.INF:
		return flank_at if position.distance_to(e.position) > FLANK_NEAR else e.position
	flank_check = 0.5
	flank_at = e.position
	if position.distance_to(e.position) <= FLANK_NEAR:
		return e.position
	var mid: Vector2 = position.lerp(e.position, 0.5)
	var side: Vector2 = position.direction_to(e.position).orthogonal()
	var left := 0
	var right := 0
	for o in main.enemies_near(mid, 80.0):
		if o == e or o.dead or o.flying:
			continue
		if side.dot(o.position - mid) > 0.0:
			left += 1
		else:
			right += 1
	if left + right >= 2:
		var go: Vector2 = side * (-1.0 if left > right else 1.0)
		var p: Vector2 = main._clamp_post(e.position + go * FLANK_WIDE)
		if not main.paths.has_terrain() or main.paths.troop_can_stand(p):
			flank_at = p
	return flank_at


## Spellblade: a foe that comes close (it never goes looking for one; from a brute it
## still backs off, see _kite) meets the sword: it
## comes out once a foe's within `reach`, and stays out till none is a little further off
## (no flicking between sword and staff). True while the sword's out.
func _blade_step() -> bool:
	var reach: float = float(blade["reach"]) + (BLADE_SLACK if blade_on else 0.0)
	var near = null
	var near_gap := INF
	for e in main.enemies_near(position, reach + 60.0):
		if e.dead or e.flying or not can_hurt(e):
			continue
		var g := _gap_to(e)
		if g <= reach and g < near_gap:
			near_gap = g
			near = e
	blade_on = near != null
	if not blade_on:
		return false
	facing = position.direction_to(near.position)
	if blade_t <= 0.0:
		_blade_strike(near)
	return true


## A sweep of the sword: magic damage to the foe in front and the next nearest (2, or 3
## with Archmage's Blade), carrying her other paths' magic: Fire sets them burning (its
## breath's burn, which never stacks), Storm now and then sparks a short chain from the
## blow, Arcane Lance now and then drives a focused bolt into the one in front.
func _blade_strike(first) -> void:
	blade_t = float(blade["every"]) * haste / _rate()
	var hit: float = float(blade["damage"]) * _power()
	var reach: float = float(blade["reach"]) + BLADE_SLACK
	var victims := [first]
	var others: Array = main.enemies_near(position, reach + 50.0).filter(func(e): return e != first and not e.dead and not e.flying and can_hurt(e) and _gap_to(e) <= reach)
	others.sort_custom(func(a, b): return _gap_to(a) < _gap_to(b))
	victims.append_array(others.slice(0, int(blade["targets"]) - 1))
	for e in victims:
		e.take_damage(hit, true, "magic")
		if not e.dead and not breath.is_empty():
			e.apply_burn(breath["burn_dps"], breath["burn_time"])
		_hit_spark(e)
	if not chain.is_empty() and blade_storm_t <= 0.0 and is_instance_valid(first):
		blade_storm_t = BLADE_STORM_CD * haste
		_blade_chain(first)
	if not lance.is_empty() and blade_lance_t <= 0.0 and is_instance_valid(first) and not first.dead:
		blade_lance_t = BLADE_LANCE_CD * haste
		first.take_damage(float(lance["damage"]) * BLADE_LANCE_SHARE * _power(), true, "magic")
		main.spawn_beam(position + Vector2(0, -20), first.position, Color(1.0, 0.5, 0.95), 6.0)
	swing = 0.15
	blade_swing = BLADE_SWING
	main.sfx("slash", 1.25 if blade["targets"] < 3 else 1.05)


## Storm through the sword: a short chain from the blow (half the Storm's damage, at
## most BLADE_CHAIN_JUMPS foes).
func _blade_chain(from) -> void:
	var hit := [from]
	var points := PackedVector2Array([position + facing * 14 + Vector2(0, -14), from.position])
	var cur = from
	while hit.size() < mini(BLADE_CHAIN_JUMPS, int(chain["jumps"])):
		var nxt = null
		var nearest := CHAIN_JUMP
		for e in main.enemies_near(cur.position, CHAIN_JUMP + 30.0):
			var d: float = e.position.distance_to(cur.position)
			if not e.dead and d < nearest and not hit.has(e):
				nearest = d
				nxt = e
		if nxt == null:
			break
		hit.append(nxt)
		points.append(nxt.position)
		cur = nxt
	for e in hit:
		if is_instance_valid(e) and not e.dead:
			e.take_damage(float(chain["damage"]) * BLADE_CHAIN_SHARE * _power(), true, "magic")
	main.spawn_bolt(points, Color(0.7, 0.85, 1.0))
	main.sfx("zap", 1.3)


## Evasive Barrage: dodging a warned blow, she looses a quick fan of weaker arrows at foes
## round her, each at a different one while there are enough. Only from a real dodge (see
## _defend), once each cooldown; nothing about the dodge itself changes.
func _start_barrage() -> void:
	var near: Array = main.enemies_near(position, attack_range + 30.0).filter(func(e): return not e.dead and _in_range(e) and can_hurt(e))
	if near.is_empty():
		return
	near.sort_custom(func(a, b): return position.distance_to(a.position) < position.distance_to(b.position))
	barrage_targets = near.slice(0, int(barrage["count"]))
	barrage_left = int(barrage["count"])
	barrage_timer = 0.0
	barrage_t = float(barrage["cooldown"])
	main.spawn_text(position + Vector2(0, -46), "Barrage!", Color(1.0, 0.85, 0.45))


func _barrage_step(delta: float) -> void:
	barrage_timer -= delta
	if barrage_timer > 0.0:
		return
	barrage_timer = BARRAGE_GAP
	var n: int = int(barrage["count"]) - barrage_left
	var live: Array = barrage_targets.filter(func(e): return is_instance_valid(e) and not e.dead)
	barrage_left -= 1
	if live.is_empty():
		barrage_left = 0
		return
	var e = live[n % live.size()]
	var p = _shoot(e, 0, float(barrage["damage"]))   # (a snap shot: its share of an arrow, every other upgrade as it is)
	if p != null:
		p.rotation += (randf() - 0.5) * 0.3
	swing = 0.1
	main.sfx("bow", 1.25)


## Razor Shards / Glacial Spear: now and then an icicle (later a spear of ice) at the
## toughest Brittle foe in reach, else the toughest in reach. Frozen solid, a foe takes it
## harder (a boss, that resists the freeze, less so).
func _shard_step(delta: float) -> void:
	shard_t -= delta
	if shard_t > 0.0:
		return
	var best = null
	var best_score := -1.0
	for e in main.enemies_near(position, attack_range + 60.0):
		if e.dead or not _in_range(e) or not can_hurt(e) or not _sees(e):
			continue
		var score: float = e.hp + (100000.0 if e.brittle_t > 0.0 else 0.0)
		if score > best_score:
			best_score = score
			best = e
	if best == null:
		shard_t = 0.4
		return
	shard_t = float(shard["cooldown"])
	var p := Projectile.new()
	p.main = main
	p.target = best
	p.target_pos = best.position
	p.position = _muzzle()
	var hit: float = float(shard["damage"]) * _power()
	if best.freeze_timer > 0.0:
		hit *= 1.0 + FROZEN_SPEAR * best.cc_mult
	p.damage = hit
	p.speed = 560.0
	p.style = "spear" if shard["spear"] else "icicle"
	p.school = "ice"
	p.color = Color(0.7, 0.95, 1.0)
	p.pierce = int(shard["pierce"])
	p.credit = xp_kind()
	p.source = get_instance_id()
	p.brittle = brittle
	p.shatter = shatter
	main.add_projectile(p)
	facing = position.direction_to(best.position)
	swing = 0.15
	main.sfx("frost", 0.7 if shard["spear"] else 1.3)


## Divine Ward: every so often a ward on whoever nearby is in real danger: under an
## enemy's warned blow first (the heavier, the sooner), then those being hit while hurt.
## Nobody at risk, nothing's cast (it looks again shortly). Intercession: two at once.
func _ward_step(delta: float) -> void:
	ward_t -= delta
	if ward_t > 0.0 or not is_active():
		return
	var threats: Array = main.threats()
	var picks := []
	for w in main.warriors_near(position, attack_range + 40.0):
		if not w.is_active() or w.is_emplacement() or w.kind == "barricade" or _ally_gap(w) > attack_range:
			continue
		if w.shield_hp > 0.0 and w.shield_left > 1.0:
			continue   # (still warded: no stacking)
		var risk := 0.0
		for th in threats:
			if Defense.hits(th, w.position, w.RADIUS, 6.0):
				risk = maxf(risk, 2.0 + Defense.severity(w, th))
		if risk <= 0.0 and w.danger_t > 0.0 and w.hp < w.max_hp * 0.85:
			risk = 1.0 + (1.0 - w.hp / w.max_hp) + (0.3 if w.max_hp < 80.0 else 0.0)   # (the frail first)
		if risk > 0.0:
			picks.append([risk, w])
	if picks.is_empty():
		ward_t = 0.4
		return
	picks.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(int(ward["count"]), picks.size()):
		var w = picks[i][1]
		w.give_ward(float(ward["absorb"]) * _power(), float(ward["time"]), ward)
		main.spawn_beam(position + Vector2(0, -24), w.position + Vector2(0, -10), Color(1.0, 0.88, 0.45), 8.0)
	ward_t = float(ward["every"])
	swing = 0.15
	main.sfx("revive", 1.4)


## A ward on this troop (it doesn't stack: a fresher, stronger one replaces it).
func give_ward(absorb: float, time: float, fx: Dictionary) -> void:
	if shield_hp > absorb and shield_left > 1.0:
		return
	shield_hp = absorb
	shield_max = absorb
	shield_left = time
	shield_fx = fx
	shield_reflected = 0.0
	queue_redraw()


## Holy Rebuke: a share of what the ward soaked goes back at whoever struck (holy, so no
## ward of theirs or armour turns it), up to the ward's cap in all.
func _ward_reflect(soak: float) -> void:
	var share: float = shield_fx.get("reflect", 0.0)
	if share <= 0.0 or soak <= 0.0:
		return
	var back := minf(soak * share, float(shield_fx["cap"]) - shield_reflected)
	var foe = main.hurt_by
	if back <= 0.0 or foe == null or not is_instance_valid(foe) or foe.dead:
		return
	shield_reflected += back
	main.hurt_by = null   # (nothing it does comes back round)
	foe.take_damage(back, true, "magic")
	main.spawn_beam(position + Vector2(0, -12), foe.position, Color(1.0, 0.9, 0.5), 4.0)


## The ward's gone: broken by a blow (Intercession: it bursts on the foes round it) or
## run out (quietly).
func _drop_ward(broken_by_blow: bool) -> void:
	if broken_by_blow and float(shield_fx.get("burst", 0.0)) > 0.0:
		for e in main.enemies_near(position, WARD_BURST + 30.0):
			if not e.dead and e.position.distance_to(position) <= WARD_BURST + e.radius:
				e.take_damage(float(shield_fx["burst"]), true, "magic")
		main.spawn_burst(position, WARD_BURST, Color(1.0, 0.9, 0.5))
		main.sfx("revive", 0.8)
	shield_hp = 0.0
	shield_left = 0.0
	shield_fx = {}


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
		# Spearhead: anyone in the way is speared in passing (for less).
		var side: float = dash.get("side", 1.0)
		for x in main.enemies_near(position, RADIUS + 40.0):
			if x == dash_target or dash_hit.has(x) or x.dead or x.flying or position.distance_to(x.position) > RADIUS + x.radius + 4.0:
				continue
			dash_hit.append(x)
			x.take_damage(damage * dash["damage"] * side * _power())
			if not x.dead and dash["stun"] > 0.0:
				x.apply_stun(dash["stun"])   # (a boss shrugs most of it off: cc_mult)
			if not x.dead and float(dash.get("knock", 0.0)) > 0.0:
				var aside := position.direction_to(dash_to).orthogonal()
				if aside.dot(x.position - position) < 0.0:
					aside = -aside
				x.apply_knockback(aside * float(dash["knock"]) * 0.6)   # (bowled aside, out of his way)
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
			e.apply_stun(dash["stun"])   # (staggered; a boss shrugs most of it off)
		if not e.dead and float(dash.get("knock", 0.0)) > 0.0:
			e.apply_knockback(facing * float(dash["knock"]))   # (thrown back; nothing moves a boss that won't be moved)
		_hit_spark(e)
		dash_cd = float(dash.get("cooldown", 0.0))
		again_t = 0.0
		main.spawn_burst(e.position, 26.0, Color(1.0, 0.9, 0.6))
		main.sfx("slash", 0.8)
		cd_timer = cooldown / _rate()
		engaged = e   # if that blow felled it, Unstoppable chains on next frame
		engaged_id = e.get_instance_id()
	_separate()


## Spearhead: trading blows with a foe that won't fall, he steps back a pace and drives
## the spear in again (no long retreat for a run-up). Never out of his area, never onto
## rock or through a wall. True if he's stepping back.
func _start_backstep(e) -> bool:
	if not _is_valid(e) or e.flying or garrison != null:
		return false
	var away: Vector2 = e.position.direction_to(position) if e.position != position else Vector2.DOWN
	var to := _zone_clamp(position + away * BACKSTEP)
	if to.distance_to(position) < BACKSTEP * 0.5 or main.paths.path_blocked(position, to, RADIUS) \
			or (main.paths.has_terrain() and main.paths.blocked(to, RADIUS)):
		return false
	backstep_dir = position.direction_to(to)
	backstep_left = BACKSTEP_TIME
	dash_target = e
	_hold_pose("strike", 0.1)
	return true


func _backstep_step(delta: float) -> void:
	backstep_left = maxf(backstep_left - delta, 0.0)
	_step_to(position + backstep_dir * (BACKSTEP / BACKSTEP_TIME) * delta)
	moving = true
	var e = dash_target
	if backstep_left > 0.0:
		if _is_valid(e):
			facing = position.direction_to(e.position)
		return
	if _is_valid(e) and _can_dash(e):
		target = e
		_start_dash(e)
		main.spawn_text(position + Vector2(0, -44), "Again!", Color(1.0, 0.85, 0.4))
	else:
		dash_target = null


## Light Step: a run of any length (`after` px) since his last blow makes the next one
## hit harder (once each `cooldown` s).
func _momentum_step() -> void:
	if _last_pos != Vector2.INF and moving:
		moved += minf(_last_pos.distance_to(position), 20.0)
	_last_pos = position
	if not momentum_ready and momentum_t <= 0.0 and moved >= float(momentum["after"]):
		momentum_ready = true


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
	var was_down := down_for > 0.0
	down_for = down_for + delta if not is_active() else 0.0
	if was_down and is_active() and not is_emplacement():
		land_t = LAND_TIME   # back on its feet (revived or recovered): a springy bounce up
	var want := flip
	if _idling() and GLANCERS.has(kind) and lift <= 0.0:
		# Stood about for a while: now and then it glances back over its shoulder.
		var c := fmod(idle_t + absf(position.x) * 0.013, 7.0)
		if c > 5.4 and c < 6.5:
			want = -flip
	if want != 0.0 and signf(turn) != want:
		turn_hold += delta   # a turn starts once the new facing has held a moment (no twitching)
		if turn_hold >= 0.08:
			turn = move_toward(turn, want, delta * TURN_RATE)
	else:
		turn_hold = 0.0
		turn = move_toward(turn, want, delta * TURN_RATE)
	_carry(delta)
	var busy: bool = moving or swing > 0.0 or pose_left > 0.0 or rez_target != null or not is_active() \
			or (target != null and _is_valid(target)) or lift > 0.0
	stow_t = maxf(stow_t - delta, 0.0)
	if busy and kind == "archer" and idle_t - IDLE_AFTER >= ARCHER_DRAW and not (target != null and _is_valid(target)):
		stow_t = ARCHER_STOW   # moving off (or picked up): the arrow goes back over her shoulder (to shoot, she keeps it)
	idle_t = 0.0 if busy else idle_t + delta
	if kind == "bard" and _idling():
		# Hums to itself: a note every so often.
		note_timer -= delta
		if note_timer <= 0.0:
			note_timer = randf_range(0.9, 1.6)
			main.spawn_note(position + Vector2(randf_range(4, 14), -28), Color(1.0, 0.9, 0.55))


## Picked up and carried by a click-and-drag: it's lifted off the ground and dangles,
## swinging behind the way it's dragged (a damped pendulum) and kicking its legs; set
## down, it lands with a squash and a puff of dust.
func _carry(delta: float) -> void:
	land_t = maxf(land_t - delta, 0.0)
	cheer_t = maxf(cheer_t - delta, 0.0)
	perk = move_toward(perk, 1.0 if main.hovered == self and not held else 0.0, delta * 8.0)
	if land_t <= 0.0:
		land_dust = false
	if hop_t > 0.0:
		hop_t = maxf(hop_t - delta, 0.0)
		if hop_t <= 0.0:
			land_t = LAND_TIME
			land_dust = true
			_jostle()
	if held:
		if lift <= 0.0:
			carry_t = 0.0
			_carried_from = position
			_carry_vel = Vector2.ZERO
			sway_v = -1.5 * turn   # a little jolt as it's grabbed
			if kind == "bard":
				main.spawn_note(position + Vector2(8, -34), Color(0.75, 0.45, 0.95))   # a startled, sour note
		carry_t += delta
		lift = minf(lift + delta * 7.0, 1.0)
		if delta > 0.0:
			_carry_vel = _carry_vel.lerp((position - _carried_from) / delta, minf(1.0, delta * 12.0))
		_carried_from = position
		var aim := clampf(_carry_vel.x * 0.0022, -0.7, 0.7) + sin(carry_t * 4.5) * 0.06   # head first, feet trailing
		sway_v += ((aim - sway) * 140.0 - sway_v * 9.0) * delta
		sway += sway_v * delta
	elif lift > 0.0:
		lift = maxf(lift - delta * 9.0, 0.0)
		sway = lerpf(sway, 0.0, minf(1.0, delta * 14.0))
		if lift <= 0.0:
			land_t = LAND_TIME if hop_t <= 0.0 else 0.0
			land_dust = land_t > 0.0
			if land_dust:
				_jostle()
			sway = 0.0
			sway_v = 0.0


## Cheers: hops on the spot for `time` seconds, starting after `delay` (so a whole line
## doesn't bounce in step). Emplacements and downed troops don't.
func cheer(time := CHEER_HOP * 3.0, delay := 0.0) -> void:
	if is_emplacement() or not is_active():
		return
	cheer_len = time
	cheer_t = time + delay


## Dropped somewhere it can't stand and put back at its old post (main): rather than
## blink there, it hops back from where it was let go.
func hop_back(from: Vector2) -> void:
	hop_from = from - position
	if hop_from.length() > 2.0:
		hop_t = HOP_TIME


## Blinks every few seconds (each at its own moment), now and then twice.
func _blinking() -> bool:
	var c := fmod(anim_t + float(get_instance_id() % 997) * 0.37, 4.3)
	return c < 0.11 or (get_instance_id() % 3 == 0 and c > 0.25 and c < 0.36)


## Set down next to others: they're jostled (a little springy bump, no dust).
func _jostle() -> void:
	for o in main.warriors_near(position, RADIUS * 3.0):
		if o != self and o.is_active() and not o.is_emplacement() and o.lift <= 0.0 and o.land_t <= 0.0:
			o.land_t = LAND_TIME * 0.5


# --- Danger: falling back, calling for help, answering calls -----------------------------

## Standing on thin ice that's cracking: it drops everything and makes for the shore
## (hazards.gd). Returns whether it's doing that this frame.
func _off_the_ice(delta: float) -> bool:
	if main.hazards.ice.is_empty() or is_emplacement() or wall_guard or held:
		return false
	var spot: Vector2 = main.hazards.flee_spot(self)
	if spot == Vector2.INF:
		return false
	_set_target(null)
	facing = position.direction_to(spot)
	if absf(facing.x) > 0.2:
		flip = signf(facing.x)
	_move_toward(spot, position.distance_to(spot), delta)
	return true


## In danger: low on health and still being hit (see DANGER_HP).
func in_danger() -> bool:
	return is_active() and hp < max_hp * DANGER_HP and danger_t > 0.0


## Falling back (its orders say so, and it's in danger): breaks off and makes for a
## Healer or a Medic Bay (else its post, or the castle if its post is where the fight
## is), till it's mended or no enemy has come near for a moment. On the way a Healer keeps
## mending whoever's in reach (itself too) and a ranged troop keeps shooting; a melee troop
## just runs. Returns whether it's falling back this frame (it does nothing else then).
## An enemy's warned blow coming (main.threats()): noticed a moment after it's standing
## under it, then got clear of, braced for, or taken (Defense.choose). True while it's
## getting clear or bracing (it does nothing else then).
func _defend(delta: float) -> bool:
	def_cd = maxf(def_cd - delta, 0.0)
	var all: Array = main.threats()
	if all.is_empty():
		if evading:
			_end_evade()
		react_key = 0
		brace_key = 0
		if not def_seen.is_empty():
			def_seen.clear()
		return false
	if not reacts or is_emplacement() or sheltered() or wall_guard or lift > 0.0 or held:
		return false
	if def_seen.size() > 40:
		for k in def_seen.keys():
			if not all.any(func(th): return th["key"] == k or th["key"] == -k):
				def_seen.erase(k)
	var under := []
	var soon := INF
	var first = null   # (the soonest it hasn't decided about yet)
	for th in all:
		if Defense.hits(th, position, RADIUS, 4.0):
			under.append(th)
			var t := Defense.time_to(th, position)
			if t < soon and not def_seen.has(th["key"]):
				soon = t
				first = th
	if evading:
		evade_t -= delta
		var live: bool = all.any(func(th): return th["key"] == evade_key)
		var d := position.distance_to(evade_to)
		if (not live and under.is_empty()) or evade_t <= 0.0:
			_end_evade()
		elif d < 3.0:
			return true   # (clear: it waits there for the blow to land, rather than walk back into it)
		else:
			facing = position.direction_to(evade_to)
			_move_toward(evade_to, d, delta)
			return true
	if brace_key != 0:
		brace_left -= delta
		if brace_left <= 0.0 or not all.any(func(th): return th["key"] == brace_key):
			brace_key = 0
		else:
			var src = def_seen.get(-brace_key)
			if src != null and is_instance_valid(src):
				facing = position.direction_to(src.position)
			return true   # (shield up, feet set: no swinging till it lands)
	if first == null:
		react_key = 0
		return false
	var key: int = first["key"]
	if react_key != key:
		react_key = key
		react_left = Defense.reaction_time(self, under.size())
		Defense.note(self, "notice")
	react_left -= delta
	if react_left > 0.0:
		return false
	var c := Defense.choose(self, first, under, all)
	var act: String = c["act"]
	react_key = 0
	Defense.note(self, act)
	if act != "miss":
		def_seen[key] = act   # (decided once; a blow it'll be clear of it keeps an eye on, in case it walks into it)
	if Defense.debug:
		main.spawn_text(position + Vector2(0, -52), act + ("" if not c.has("why") else " (%s)" % c["why"]), Color(0.7, 0.9, 1.0))
	if act == "evade":
		if not barrage.is_empty() and barrage_t <= 0.0:
			_start_barrage()
		if not traps.is_empty():
			_trap_behind()
		evading = true
		evade_key = key
		evade_to = c["to"]
		evade_t = minf(Defense.time_to(first, position) + 0.3, 0.3 + 2.0 * position.distance_to(evade_to) / maxf(Defense.speed(self), 1.0) + 1.0)
		_break_off()
		facing = position.direction_to(evade_to)
		_move_toward(evade_to, position.distance_to(evade_to), delta)
		return true
	if act == "brace":
		brace_key = key
		brace_left = Defense.time_to(first, position) + 0.2
		def_seen[-key] = first["src"]
		main.spawn_text(position + Vector2(0, -40), "Brace", Color(0.8, 0.85, 1.0))
		return true
	return false


## Getting out of the way breaks off what it was doing: a combo, a volley, a beam or a
## Spirit Bomb being gathered (the bomb's bolts are kept for later), the off-hand follow-up.
## A revive's progress is kept (the Healer carries on once it's back in reach).
func _break_off() -> void:
	if combo_left > 0 or volley_left > 0 or beam_charge > 0.0 or bomb_charge > 0.0 or offhand_timer > 0.0:
		Defense.note(self, "interrupt")
	combo_left = 0
	offhand_timer = 0.0
	if beam_charge > 0.0:
		beam_charge = 0.0
		beam_timer = maxf(beam_timer, float(beam["cooldown"]) * 0.4)
	if bomb_charge > 0.0 or volley_left > 0:
		bomb_charge = 0.0
		volley_left = 0
		blast_timer = maxf(blast_timer, float(blast.get("cooldown", 1.0)) * 0.4 / _rate())


## Clear (or as clear as it'll get): settling a moment before it fights on, and some
## time before it can dodge again.
func _end_evade() -> void:
	evading = false
	evade_key = 0
	var p := Defense.profile(self)
	cd_timer = maxf(cd_timer, float(p["recover"]))
	def_cd = float(p["cooldown"])


## Out of the way of anything warned (main.dangers()): a troop standing where an Arrow
## Storm, a Fireball, falling stone or the Ogre King's slam is about to land, or on
## burning ground, or in the line of a charge, runs for the nearest open ground clear of
## it, and goes back to what it was doing once it's out. True while it's getting clear.
func _dodge(delta: float) -> bool:
	if is_emplacement() or sheltered() or lift > 0.0:
		dodging = false
		return false
	var zones: Array = main.dangers()
	if zones.is_empty():
		dodging = false
		return false
	var pad := RADIUS + (12.0 if dodging else 4.0)   # (once running, it gets well clear)
	var hit = null
	for z in zones:
		if _in_danger_zone(z, position, pad):
			hit = z
			break
	if hit == null:
		dodging = false
		return false
	if not dodging or hit.has("above"):
		dodging = true
		dodge_to = _dodge_spot(hit, zones)   # (a moving front: aimed afresh each step)
	elif _in_danger_zone(hit, dodge_to, RADIUS + 10.0) or position.distance_to(dodge_to) < 3.0:
		dodge_to = _dodge_spot(hit, zones)
	facing = position.direction_to(dodge_to)
	_move_toward(dodge_to, position.distance_to(dodge_to), delta)
	return true


var dodging := false
var dodge_to := Vector2.ZERO
# Enemies' warned blows (defense.gd): what it's doing about them.
var reacts := true          # (tests can switch it off, to see a blow land)
var def_cd := 0.0           # > 0: it got out of the way a moment ago, and can't again yet
var react_key := 0          # the blow it's noticed and is about to decide on...
var react_left := 0.0       # ...in this long
var def_seen := {}          # blow -> what it decided (decided once each)
var evading := false        # getting clear of a blow
var evade_to := Vector2.ZERO
var evade_key := 0
var evade_t := 0.0          # (gives up after this long: something's in the way)
var brace_key := 0          # bracing for this blow...
var brace_left := 0.0       # ...for this long more


static func _in_danger_zone(z: Dictionary, p: Vector2, pad: float) -> bool:
	if z.has("above"):
		return p.y < float(z["above"]) + pad   # (fire rolling down the field: everything above its front)
	if z.has("c"):
		return p.distance_to(z["c"]) < float(z["r"]) + pad
	var c := Geometry2D.get_closest_point_to_segment(p, z["a"], z["b"])
	return p.distance_to(c) < float(z["r"]) + pad


## The nearest open ground out of `z` (and every other danger): round its edge, the
## closest spot a troop can stand.
func _dodge_spot(z: Dictionary, zones: Array) -> Vector2:
	if z.has("above"):
		# Down the field, well ahead of it; round the side of anything too big to go through
		# (the Ogre King standing in the fire he's called up).
		var x := position.x
		for e in main.get_enemies():
			if e.boss and not e.dead and e.position.y > position.y - e.radius:
				var clear: float = e.radius + RADIUS + 16.0
				if absf(e.position.x - x) < clear:
					x = e.position.x + (clear if x >= e.position.x else -clear)
		var y := float(z["above"]) + RADIUS + 140.0
		var spot: Vector2 = main._clamp_post(Vector2(x, y))
		if main.paths.has_terrain() and not _walkable_line(position, spot):
			# Rock, a wreck, a wall in the way: the nearest line down that's clear.
			for d in [40.0, -40.0, 80.0, -80.0, 130.0, -130.0, 190.0, -190.0]:
				var alt: Vector2 = main._clamp_post(Vector2(x + d, y))
				if _walkable_line(position, alt):
					return alt
		return spot
	var away: Vector2
	var edge: float = float(z["r"]) + RADIUS + 16.0
	var c: Vector2
	if z.has("c"):
		c = z["c"]
	else:
		c = Geometry2D.get_closest_point_to_segment(position, z["a"], z["b"])
	away = c.direction_to(position) if position.distance_to(c) > 1.0 else c.direction_to(post) if post.distance_to(c) > 1.0 else Vector2.DOWN
	var best := position
	var best_d := INF
	for i in 16:
		var dir := away.rotated(i * TAU / 16.0)
		var spot: Vector2 = main._clamp_post(c + dir * edge)
		if zones.any(func(o): return _in_danger_zone(o, spot, RADIUS + 4.0)):
			continue
		if not main.paths.terrain.is_empty() and main.paths.blocked(spot, RADIUS):
			continue
		var d := position.distance_to(spot)
		if d < best_d:
			best_d = d
			best = spot
	if best_d == INF:
		best = main._clamp_post(c + away * edge)
	return best


## Whether a troop could walk straight from `a` to `b` (nothing on the ground it can't
## cross, low scenery included, every 8px along the way).
func _walkable_line(a: Vector2, b: Vector2) -> bool:
	var n := maxi(1, int(a.distance_to(b) / 8.0))
	for i in range(1, n + 1):
		if main.paths.blocked(a.lerp(b, float(i) / n), RADIUS):
			return false
	return true


func _fall_back(delta: float) -> bool:
	if danger_mode != "fall_back" or is_emplacement() or wall_guard or summoned or clone_of != null:
		retreating = false
		return false
	if not retreating:
		if not in_danger():
			return false
		retreating = true
		safe_t = 0.0
		_set_target(null)
		answering = null
		free_run = false
		rez_target = null
		main.spawn_text(position + Vector2(0, -44), "Falling back!", Color(1.0, 0.75, 0.35))
	var near: Array = main.enemies_near(position, SAFE_GAP).filter(func(e): return not e.dead)
	safe_t = 0.0 if not near.is_empty() else safe_t + delta
	if hp >= max_hp * RECOVER_HP or safe_t >= SAFE_TIME:
		retreating = false
		return false
	var dest := _fall_back_spot(near)
	var d := position.distance_to(dest)
	if d > 6.0:
		facing = position.direction_to(dest)
		_move_toward(dest, d, delta)
	elif not near.is_empty():
		facing = position.direction_to(near[0].position)
	# Still useful on the way: a Healer mends whoever's in reach (itself too), a ranged
	# troop shoots whatever's in reach; only melee troops just run.
	if is_mobile_healer():
		_heal_in_reach()
	elif (not is_melee() or not blast.is_empty()) and not is_healer():
		_strike_in_reach(delta)   # (a Martial Artist with Spirit Bolts counts: it shoots ki)
	return true


## Attacking happens on the move: hit the target if it's in reach, otherwise anything
## else in reach (picked by priority), including while following a move order, or (a
## ranged troop) while falling back.
func _strike_in_reach(delta: float) -> void:
	if not blade.is_empty() and _blade_step():
		return   # (a foe's close: the sword, not the staff)
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


## A Healer falling back keeps mending as it goes: whoever in reach is worst hurt
## (itself included), when it's ready.
func _heal_in_reach() -> void:
	if cd_timer > 0.0:
		return
	var best = null
	var best_frac := 0.999
	for w in main.get_warriors() + _villagers():
		if not w.is_active() or not w.is_target() or (w != self and _ally_gap(w) > attack_range):
			continue
		var frac: float = w.hp / w.max_hp
		if frac < best_frac:
			best_frac = frac
			best = w
	if best != null:
		cd_timer = cooldown
		_heal(best)


## Where to fall back to: beside the nearest Healer on its feet or Medic Bay (on the
## castle side of it); else its post, unless the fight's there, then back toward the castle.
func _fall_back_spot(near: Array) -> Vector2:
	var best = null
	for w in main.get_warriors():
		if w == self or not w.is_active() or w.build_left > 0.0 or w.retreating:
			continue
		if not (w.is_mobile_healer() or (w.data["attack"] == "pulse")):
			continue
		if best == null or position.distance_to(w.position) < position.distance_to(best.position):
			best = w
	if best != null:
		return main._clamp_post(best.position + Vector2(0, RADIUS * 2.0))
	var threat_at_post: bool = main.enemies_near(post, SAFE_GAP).any(func(e): return not e.dead)
	if position.distance_to(post) > RADIUS and not threat_at_post:
		return post
	if main.rules.has_castle():
		return main._clamp_post(Vector2(position.x, main.CASTLE_Y - RADIUS * 3.0))
	return main._clamp_post(post + (post - (near[0].position if not near.is_empty() else post)).normalized() * 120.0)


## Answering calls for help (its orders say how): takes up the nearest call, at once or
## once its own enemy's dealt with, and keeps on it till the caller's safe (or there's
## no enemy left by them). While answering its area doesn't hold it (free_run).
func _update_answer() -> void:
	if answer == "ignore" or move_mode == "hold" or is_healer() or is_emplacement() or wall_guard or summoned or retreating:   # (Healers go to the hurt their own way)
		answering = null
		free_run = false
		return
	if answering != null and (not is_instance_valid(answering) or not main.calling(answering) or _answer_target() == null):
		answering = null
	if answering == null:
		if answer == "after" and target != null and _keep_target():
			free_run = false
			return   # its own enemy first
		var best = null
		for c in main.callers():
			if c == self:
				continue
			if best == null or position.distance_to(c.position) < position.distance_to(best.position):
				best = c
		answering = best
		if answering != null and _answer_target() == null:
			answering = null
	free_run = answering != null


## The enemy to go for, answering a call: the nearest to the caller of those on it.
func _answer_target():
	var best = null
	var best_d := INF
	for e in main.enemies_near(answering.position, CALL_REACH):
		if not _is_valid(e):
			continue
		var d: float = e.position.distance_to(answering.position) - (40.0 if e.aggro == answering else 0.0)
		if d < best_d:
			best_d = d
			best = e
	return best


## The x scale it's drawn with: its facing, squeezed thin for a moment as it turns about.
func _drawn_flip() -> float:
	return signf(turn if turn != 0.0 else flip) * maxf(absf(turn), 0.5)


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
		return _carried_motion(off, rot, sc)
	var lean := signf(facing.x) if absf(facing.x) > 0.2 else 0.0
	if moving:
		# The walk cycle (Sprites.step) goes plant, left foot up, plant, right foot up: the
		# body rises as a foot lifts and settles into each footfall with a little squash,
		# rocking over onto the planted foot.
		var step := cos(PI * (walk - 0.5))   # 1 on a footfall, -1 passing
		off.y -= 1.6 * (1.0 - step)
		sc = Vector2(1.0 + 0.025 * step, 1.0 - 0.04 * step)
		rot = 0.08 * lean + 0.04 * sin(PI * walk * 0.5)
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
				var t := fmod(idle_t - IDLE_AFTER - ARCHER_DRAW, ARCHER_LOOP) if idle_t - IDLE_AFTER >= ARCHER_DRAW else -1.0
				if t > 1.5 and t < 2.3:
					rot -= 0.07 * sin(PI * (t - 1.5) / 0.8) * lean
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
	if rez_target != null and is_instance_valid(rez_target) and not moving:
		# Reviving someone: kneeling over them, leaning in, rocking gently as it prays.
		var lean_in := signf(rez_target.position.x - position.x) if absf(rez_target.position.x - position.x) > 4.0 else turn
		rot += (0.12 + 0.03 * sin(anim_t * 3.0)) * lean_in
		sc *= Vector2(1.05, 0.88)
	if hurt > 0.0:
		# Struck: knocked back a step and squashed by the blow.
		var k := hurt / 0.1
		off -= facing * 2.5 * k
		sc *= Vector2(1.0 + 0.1 * k, 1.0 - 0.09 * k)
	return _carried_motion(off, rot, sc)


## Adds being carried (lifted, dangling, stretched from the scruff) and being set down
## (a springy squash that settles) to a body motion.
func _carried_motion(off: Vector2, rot: float, sc: Vector2) -> Array:
	if cheer_t > 0.0 and cheer_t < cheer_len and lift <= 0.0:
		# Cheering: hop, hop, hop, squashing a little into each landing.
		var ph := fmod((cheer_len - cheer_t) / CHEER_HOP, 1.0)
		var h := sin(PI * ph)
		off.y -= 9.0 * h
		if kind == "martial" and cheer_len > CHEER_HOP and (cheer_len - cheer_t) >= CHEER_HOP and (cheer_len - cheer_t) < CHEER_HOP * 2.0:
			# The Martial Artist's second hop is a backflip, turning about its middle.
			rot = TAU * ph * turn
			var mid := Sprites.SIZE * SCALE * 0.5
			off += Vector2(-mid * sin(rot), mid * (cos(rot) - 1.0)) + Vector2(0, -8.0 * h)
		sc *= Vector2(1.0 - 0.06 * h, 1.0 + 0.1 * h) if h > 0.25 else Vector2(1.12 - 0.48 * h, 0.9 + 0.4 * h)
	if perk > 0.0 and lift <= 0.0:
		# Hovered: up on its toes, a little taller, bobbing as if to say "pick me".
		var e := perk * perk * (3.0 - 2.0 * perk)
		off.y -= (2.0 + absf(sin(anim_t * 6.0)) * 1.5) * e
		sc *= Vector2(1.0 - 0.03 * e, 1.0 + 0.05 * e)
	if lift > 0.0:
		var e := lift * lift * (3.0 - 2.0 * lift)   # eased
		var heavy := 0.45 if is_emplacement() else 1.0   # emplacements only come up a little
		off.y -= LIFT_HEIGHT * heavy * e + sin(carry_t * 9.0) * 1.2 * e * heavy
		rot = sway * heavy
		# It hangs from where it's held, near the top: swing about that point, not the feet.
		var grip := Sprites.SIZE * SCALE * 0.8
		off += Vector2(-grip * sin(rot), grip * (cos(rot) - 1.0))
		sc = Vector2(1.0 - 0.06 * e * heavy, 1.0 + 0.08 * e * heavy)
	if hop_t > 0.0:
		var k := hop_t / HOP_TIME   # 1 where it was let go, 0 back at its post
		off += hop_from * (k * k * (3.0 - 2.0 * k))
		off.y -= sin(PI * k) * (10.0 + hop_from.length() * 0.08)
		sc = Vector2(0.94, 1.08)
	if land_t > 0.0:
		var k := land_t / LAND_TIME
		var bounce := cos((1.0 - k) * PI * 3.0) * k
		sc *= Vector2(1.0 + 0.22 * bounce, 1.0 - 0.2 * bounce)
		if kind == "martial" and k > 0.55:
			# Set down, the Martial Artist lands it with a flip (turning about its middle).
			var f := (k - 0.55) / 0.45
			rot = -TAU * (1.0 - f) * turn
			var mid := Sprites.SIZE * SCALE * 0.5
			off += Vector2(-mid * sin(rot), mid * (cos(rot) - 1.0)) + Vector2(0, -12.0 * sin(PI * f))
			sc = Vector2.ONE
	return [off, rot, sc]


func _pose_name() -> String:
	if data.get("pike", false):
		return "level" if _pike_levelled() else ""   # (his sprite's pike taken away: drawn levelled on its own)
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


## The Pikeman's pike, levelled at the foe once he's braced on one (or thrusting, a little
## further out as it goes), as long as it really reaches. (Upright at rest it's in his sprite.)
## Hardened Point: a heavier head; Hooked Spear: a hook behind the point.
func _pike_levelled() -> bool:
	return lift <= 0.0 and is_active() and (swing > 0.0 or pose_left > 0.0 or (target != null and still_t >= PIKE_SET))


func _draw_pike() -> void:
	if not _pike_levelled():
		return   # (upright, it's in his sprite)
	var hand := Vector2(5.0 * flip, -6.0)
	var levelled := true
	var dir: Vector2 = facing
	var length: float = RADIUS + pike_range - 4.0 + (5.0 if swing > 0.0 else 0.0)
	var butt := hand - dir * 12.0
	var tip := hand + dir * (length - 8.0)
	draw_line(butt, tip, OUTLINE_COLOR, 4.0, true)
	draw_line(butt, tip, Color(0.58, 0.4, 0.22), 2.0, true)
	var side := dir.orthogonal()
	var big: bool = not hardened.is_empty()
	var head := 9.0 if big else 7.0
	var steel := Color(0.62, 0.64, 0.7) if big else Color(0.85, 0.88, 0.95)
	var pts := PackedVector2Array([tip + dir * head, tip + side * (3.0 if big else 2.5), tip - dir * 2.0, tip - side * (3.0 if big else 2.5)])
	draw_colored_polygon(pts, steel)
	draw_polyline(pts + PackedVector2Array([pts[0]]), OUTLINE_COLOR, 1.0, true)
	if not hook.is_empty():
		draw_line(tip, tip + side * 5.0 - dir * 3.0, OUTLINE_COLOR, 3.0, true)
		draw_line(tip, tip + side * 5.0 - dir * 3.0, steel, 1.5, true)
	if still_t >= PIKE_SET and not brace.is_empty() and levelled:
		draw_arc(tip, 4.0, 0, TAU, 10, Color(0.85, 0.9, 1.0, 0.5), 1.5, true)   # (set: the point held steady)


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
	if kind == "obelisk":
		# Its runes glow the colour of the rune most deeply carved.
		var best := -1
		for p in tiers.size():
			if tiers[p] > 0 and (best < 0 or tiers[p] > tiers[best]):
				best = p
		var glow: Color = [Color(0.55, 0.8, 1.0), Color(1.0, 0.85, 0.4), Color(1.0, 0.5, 0.2), Color(0.8, 0.45, 1.0)][best] if best >= 0 else Color(0.75, 0.55, 1.0)
		recolor = {"R": glow}
		tag += "+r%d" % best
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


## The Cannoneer's pose this frame, working the gun drill (a Tower's crew poses as itself:
## see _draw_tower).
func _crew_pose() -> String:
	match kind:
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
	if kind == "tower":
		_draw_tower(look, foot, base_foot, tint)
		return
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


## A plain Tower: the stone tower, and on its battlements whoever's posted in it (as it
## looks, in its own upgrades, turned to what it's fighting, going through its own poses);
## empty battlements without a crew.
## A broken Tower: the stump of its walls, its stones fallen round it, dust.
func _draw_broken() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = get_instance_id()
	draw_texture_rect(Sprites.shadow(), Rect2(-RADIUS * 1.5, RADIUS - 6, RADIUS * 3.0, 14), false, Color(0, 0, 0, 0.3))
	var stone := Color(0.55, 0.53, 0.5)
	draw_rect(Rect2(-17, -6, 34, 22), Color(0.1, 0.07, 0.1))
	draw_rect(Rect2(-16, -5, 32, 20), stone.darkened(0.2))
	for k in 3:
		var h := 6.0 + rng.randf_range(0, 12)
		draw_rect(Rect2(-16 + k * 11, -5 - h, 10, h), Color(0.1, 0.07, 0.1))
		draw_rect(Rect2(-15 + k * 11, -4 - h, 8, h), stone if k % 2 == 0 else stone.darkened(0.1))
	for k in 9:
		var p := Vector2(rng.randf_range(-28, 28), rng.randf_range(4, 20))
		draw_rect(Rect2(p, Vector2(rng.randf_range(4, 8), rng.randf_range(3, 6))), stone.darkened(rng.randf_range(0, 0.3)))
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(-60, -30), "Broken", HORIZONTAL_ALIGNMENT_CENTER, 120, 12, 3, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(-60, -30), "Broken", HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(1.0, 0.6, 0.45))


func _draw_tower(look: Dictionary, foot: Vector2, base_foot: Vector2, tint: Color) -> void:
	var base_tex: Texture2D = look["mount"][0]
	var c = crew_in if crew_in != null and is_instance_valid(crew_in) and crew_in.garrison == self else null
	if c != null:
		var clook: Dictionary = c._look()
		var crew_tex: Texture2D = clook["frames"][0]
		var pn: String = c._pose_name()
		if pn != "":
			var t = c._pose_tex(clook, pn)
			if t != null:
				crew_tex = t
		var breathe := 1.0 + 0.025 * sin(anim_t * 2.4 + position.x)
		var rect := Sprites.draw_mount(self, kind, foot, base_foot, c.flip, base_tex, crew_tex, tint, breathe, SCALE)
		_remember_body(base_tex, Transform2D(0, Vector2(c.flip, 1), 0, foot), rect)
	else:
		var lay := Sprites.mount_layout(kind, SCALE)
		var k: float = lay["k"]
		var rect := Rect2(lay["left"], -Sprites.SIZE * k, base_tex.get_width() * k, Sprites.SIZE * k)
		draw_set_transform(foot, 0, Vector2(flip, 1))
		draw_texture_rect(base_tex, rect, false, tint)
		_remember_body(base_tex, Transform2D(0, Vector2(flip, 1), 0, foot), rect)
	draw_set_transform(Vector2.ZERO)


## A construction site: scaffolding, the emplacement rising out of the ground as the
## Engineer works, and a progress bar.
func _draw_construction() -> void:
	var done := clampf(1.0 - build_left / maxf(build_total, 0.01), 0.0, 1.0)
	var look := _look()
	var tex: Texture2D = look["mount"][0] if MOUNTS.has(kind) else look["frames"][0]
	var k := SCALE * (Sprites.TOWER_GROW if kind == "tower" else (Sprites.CANNON_GROW if kind == "cannon" else 1.0))
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
		"tower":
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
	if broken:
		_draw_broken()
		return
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
	var motion := _body_motion() if is_active() else [Vector2.ZERO, 0.0, Vector2.ONE]
	# Off the ground (carried, hopping, cheering), the shadow shrinks and fades under it.
	var up := clampf(-(motion[0] as Vector2).y / 40.0, 0.0, 0.45)
	var sr := RADIUS * (1.35 if MOUNTS.has(kind) else 1.0) * (1.0 - up)
	draw_texture_rect(Sprites.shadow(), Rect2(-sr, feet - sr * 0.35, sr * 2.0, sr * 0.7), false, Color(0, 0, 0, 0.3 - 0.25 * up))
	if land_t > 0.0 and land_dust:
		# Set down: a puff of dust out to either side.
		var k := 1.0 - land_t / LAND_TIME
		var big := 1.6 if is_emplacement() else 1.0
		for side in [-1.0, 1.0]:
			for j in 2:
				var p := Vector2(side * (6.0 + (14.0 + 7.0 * j) * k) * big, feet - 1.0 - (3.0 + 3.0 * j) * k)
				Sprites.disc(self, p, (3.5 + 4.0 * k) * big * (1.0 - 0.25 * j), Color(0.86, 0.8, 0.68, 0.8 * (1.0 - k * k)))
	if not is_active():
		# Knocked out: lying on the ground (or a wrecked emplacement) with a recovery ring.
		if is_emplacement():
			draw_set_transform(Vector2(0, feet - size.y / 2 + 4), 0, Vector2(flip, 0.85))
			draw_texture_rect(frames[0], _tex_rect(frames[0]), false, Color(0.4, 0.38, 0.38, 0.85))
			_remember_body(frames[0], Transform2D(0, Vector2(flip, 0.85), 0, Vector2(0, feet - size.y / 2 + 4)), _tex_rect(frames[0]))
		else:
			# Toppling over: it tips onto its back (pivoting on its feet), hits the ground
			# with a little bounce, and greys out as it lies there.
			var k := clampf(down_for / 0.35, 0.0, 1.0)
			var tip := k * k * (3.0 - 2.0 * k)
			var bounce := sin(clampf((down_for - 0.35) / 0.2, 0.0, 1.0) * PI) * 0.12
			var ang := (PI / 2 * tip - bounce) * flip
			var half := size.y / 2
			# The feet slide back as it goes over, so it ends up lying where it stood.
			var feet_at := Vector2(0, feet).lerp(Vector2(-half * flip, 4), tip)
			var lying := Transform2D(ang, Vector2(flip, 1), 0, feet_at) * Transform2D(0, Vector2(0, -half))
			var grey := Color.WHITE.lerp(Color(0.5, 0.5, 0.55, 0.85), tip)
			draw_set_transform_matrix(lying)
			draw_texture_rect(frames[0], _tex_rect(frames[0]), false, grey)
			_remember_body(frames[0], lying, _tex_rect(frames[0]))
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
	elif hex_left > 0.0 and hurt <= 0.0:
		tint = Color(0.85, 0.65, 1.15)   # hexed by his dirge: a sickly violet
	if clone_of != null:
		# A Mirror Self copy: see-through, tinted blue and flickering, so it's never taken for the real one.
		tint *= Color(0.6, 0.85, 1.3, 0.5 + 0.12 * sin(Time.get_ticks_msec() / 90.0))
	var charging := beam_charge > 0.0
	var tex: Texture2D = Sprites.step(frames, int(walk)) if moving else frames[0]
	if lift > 0.5 and not is_emplacement():
		tex = frames[int(carry_t * 7.0) % 2]   # carried: legs kicking in the air
	elif tex == frames[0] and not is_emplacement() and _blinking():
		var shut = Sprites.blink(tex)
		if shut != null:
			tex = shut
	var pose_name := _pose_name() if lift <= 0.0 else ""
	if kind == "martial" and lift > 0.5:
		pose_name = ["punch", "kick"][int(carry_t * 5.0) % 2]   # carried: fighting the air
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
	var origin: Vector2 = Vector2(0, feet - size.y / 2) + lunge + motion[0]
	var arrow := _archer_arrow(origin) if kind == "archer" and (_idling() or stow_t > 0.0) and _readying() <= 0.0 else {}
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
		# The crew goes where the tower goes (carried, set down) but not with the cannon's recoil.
		_draw_mounted(look, origin + Vector2(0, size.y / 2), Vector2(0, feet) + motion[0], tint)
	else:
		var fx := _drawn_flip()
		draw_set_transform(origin + Vector2(0, size.y / 2), motion[1], Vector2(fx * motion[2].x, motion[2].y))
		var slung := back_weapon()
		if slung != "":
			_draw_back_weapon(slung, body.position)
		draw_texture_rect(tex, body, false, tint)
		_remember_body(tex, Transform2D(motion[1], Vector2(fx * motion[2].x, motion[2].y), 0, origin + Vector2(0, size.y / 2)), body)
	draw_set_transform(Vector2.ZERO)
	_draw_idle_props(origin, size)
	if (kind == "mine" or kind == "statue") and build_left <= 0.0:
		_draw_glint(origin, size)
	if main.calling(self):
		# Calling for help: a red speech bubble with a "!", pulsing.
		var pulse := 1.0 + 0.12 * sin(anim_t * 10.0)
		var at := origin + Vector2(size.x * 0.34, -size.y * 0.62)
		var r := 10.0 * pulse
		Sprites.disc(self, at, r + 1.5, OUTLINE_COLOR)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-3, r - 1), at + Vector2(-7, r + 6), at + Vector2(2, r - 1)]), OUTLINE_COLOR)
		Sprites.disc(self, at, r, Color(0.92, 0.25, 0.22))
		draw_colored_polygon(PackedVector2Array([at + Vector2(-2.5, r - 2), at + Vector2(-5.5, r + 4), at + Vector2(1, r - 2)]), Color(0.92, 0.25, 0.22))
		draw_texture_rect(Sprites.white(), Rect2(at + Vector2(-2, -6.5), Vector2(4, 8)), false, Color.WHITE)
		draw_texture_rect(Sprites.white(), Rect2(at + Vector2(-2, 3.5), Vector2(4, 3.5)), false, Color.WHITE)
	if held and lift > 0.5 and not is_emplacement() and main.dragging == self and not main.can_post_at(post, self):
		# Held over somewhere it can't stand: a nervous bead of sweat.
		var drip := fmod(carry_t * 1.4, 1.0)
		var at := origin + Vector2(size.x * 0.32, -size.y * 0.42 + 6.0 * drip)
		var a := 1.0 - drip * 0.6
		Sprites.disc(self, at + Vector2(0, 1.5), 3.2, Color(OUTLINE_COLOR, a))
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -5), at + Vector2(2.6, 0.5), at + Vector2(-2.6, 0.5)]), Color(OUTLINE_COLOR, a))
		Sprites.disc(self, at + Vector2(0, 1.5), 2.2, Color(0.6, 0.85, 1.0, a))
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -3.6), at + Vector2(1.6, 0.6), at + Vector2(-1.6, 0.6)]), Color(0.6, 0.85, 1.0, a))
	if lift > 0.0 and carry_t < 0.7 and (not is_emplacement() or MOUNTS.has(kind)):   # (a tower's crew is startled too)
		# Picked up: a startled "!" pops up over its head.
		var pop := minf(carry_t / 0.12, 1.0)
		var at := origin + Vector2(-3, -size.y * 0.55 - 6.0 - 4.0 * pop)
		if MOUNTS.has(kind):
			at += Vector2((Sprites.mount_layout(kind, SCALE)["crew"] as Vector2).x * flip, (Sprites.mount_layout(kind, SCALE)["crew"] as Vector2).y)   # over the crew's head
		var a := clampf((0.7 - carry_t) / 0.2, 0.0, 1.0)
		draw_string_outline(ThemeDB.fallback_font, at, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 + 6 * pop), 3, Color(0, 0, 0, a))
		draw_string(ThemeDB.fallback_font, at, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 + 6 * pop), Color(1.0, 0.92, 0.45, a))
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
	if bomb_charge > 0.0:
		# Gathering a Spirit Bomb: a ki orb for each bolt it holds, circling in to his hands and
		# merging there into one growing ball of light.
		var k := 1.0 - bomb_charge / BOMB_CHARGE
		var hands := Vector2(0, feet - size.y * 0.5) + facing * 12.0
		var spin := Time.get_ticks_msec() / 120.0
		var n := maxi(blast_count, 1)
		for i in n:
			var a := spin + i * TAU / n
			var r := 34.0 * (1.0 - k)
			var p := hands + Vector2(cos(a), sin(a) * 0.6) * r
			Sprites.disc(self, p, 7.0 * (1.0 - k * 0.5), Color(KI_COLOR, 0.35))
			Sprites.disc(self, p, 3.5, Color(1, 1, 0.9, 0.9))
		var flick := 1.0 + 0.12 * sin(Time.get_ticks_msec() / 22.0)
		Sprites.disc(self, hands, (3.0 + 13.0 * k) * flick, Color(KI_COLOR, 0.4))
		Sprites.disc(self, hands, (1.5 + 7.0 * k) * flick, Color(1, 1, 0.9, 0.95))
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
	if data.get("pike", false) and is_active():
		_draw_pike()
	if kind == "assassin" and is_active():
		if lunge_left > 0.0:
			draw_line(Vector2(0, -8), Vector2(0, -8) - facing * 30.0, Color(0.45, 0.75, 0.45, 0.55), 6.0, true)   # (a streak: the lunge)
		if smoke_hide > 0.0 or stealth_t > 0.0 or (not leafstep.is_empty() and rest_t >= REST_UNSEEN):
			draw_set_transform(Vector2(0, RADIUS), 0, Vector2(1, 0.4))
			draw_arc(Vector2.ZERO, RADIUS + 3.0, 0, TAU, 20, Color(0.3, 0.45, 0.3, 0.35), 2.0, true)   # (unseen: a faint shadow ring)
			draw_set_transform(Vector2.ZERO)
	if kind == "mage" and tiers.size() > 3 and tiers[3] >= 1:
		# Mage Armor: a faint shimmer of force round her (brighter with Archmage's Blade).
		var strong: bool = tiers[3] >= 4
		draw_arc(Vector2(0, -8), 21.0, 0.0, TAU, 24, Color(0.75, 0.7, 1.0, (0.28 if strong else 0.16) + 0.06 * sin(anim_t * 3.0)), 2.0 if strong else 1.2, true)
	if not blade.is_empty() and (blade_on or blade_swing > 0.0):
		# The sword: her staff's magic drawn out into a blade, swept through the foes in front.
		var big := int(blade["targets"]) >= 3
		var length := 30.0 if big else 22.0
		var k := blade_swing / BLADE_SWING
		var aim := facing.rotated(lerpf(-0.9, 0.9, 1.0 - k) * flip if k > 0.0 else 0.0)
		var hilt := Vector2(0, -12) + facing * 6.0
		var col: Color = _staff_color() if _high_paths().size() >= 2 else MAGE_ORB_COLORS[maxi(_look_path(), 3) if _look_path() < 0 else _look_path()]
		draw_line(hilt, hilt + aim * length, Color(col, 0.35), 7.0 if big else 5.0, true)
		draw_line(hilt, hilt + aim * length, Color(0.95, 0.95, 1.0), 2.0, true)
		draw_line(hilt - aim.orthogonal() * 4.0, hilt + aim.orthogonal() * 4.0, Color(0.85, 0.75, 0.4), 2.0, true)
		if k > 0.0:
			draw_arc(hilt, length, aim.angle() - 0.9 * flip, aim.angle(), 10, Color(col, 0.5 * k), 3.0, true)
	if shield_hp > 0.0:
		# A Healer's ward: a golden bubble, fading as it's worn down.
		var left := clampf(shield_hp / maxf(shield_max, 1.0), 0.2, 1.0)
		draw_arc(Vector2(0, -6), 25.0, 0.0, TAU, 28, Color(1.0, 0.88, 0.45, 0.55 * left + 0.1 * sin(anim_t * 6.0)), 2.5, true)
		draw_arc(Vector2(0, -6), 22.0, -2.4, -0.7, 8, Color(1.0, 0.97, 0.8, 0.5 * left), 1.5, true)
	if brace_key != 0:
		# Braced for a warned blow: shield up toward it, feet set.
		var pulse := 0.65 + 0.25 * sin(anim_t * 14.0)
		draw_arc(facing * 12 + Vector2(0, -6), 18, facing.angle() - 0.9, facing.angle() + 0.9, 10, Color(0.75, 0.85, 1.0, pulse), 3.0, true)
		draw_line(Vector2(-12, feet + 1), Vector2(12, feet + 1), Color(0.75, 0.85, 1.0, 0.5), 2.0)
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


## Now and then a glint: gold catching the light at a Gold Mine's mouth, the sun on a
## War Statue. A four-pointed twinkle that grows and fades, somewhere new each time.
func _draw_glint(origin: Vector2, size: Vector2) -> void:
	var every := 1.6 if kind == "mine" else 2.8
	var c := fmod(anim_t + float(get_instance_id() % 101) * 0.05, every)
	if c > 0.45:
		return
	var n := int((anim_t + float(get_instance_id() % 101) * 0.05) / every)
	var k := sin(PI * c / 0.45)
	var spot := Vector2(fmod(n * 0.618, 1.0) - 0.5, fmod(n * 0.382, 1.0) * 0.6 - 0.25)
	if kind == "mine":
		spot = Vector2(spot.x * 0.5, 0.15 + spot.y * 0.3)   # in the mine's mouth, on the gold
	var at := origin + spot * size * Vector2(0.9, 0.9)
	var col := Color(1.0, 0.95, 0.6, 0.95) if kind == "mine" else Color(1, 1, 1, 0.9)
	var r := 2.0 + 5.0 * k
	draw_texture_rect(Sprites.white(), Rect2(at - Vector2(r, 1), Vector2(r * 2, 2)), false, Color(col, col.a * k))
	draw_texture_rect(Sprites.white(), Rect2(at - Vector2(1, r), Vector2(2, r * 2)), false, Color(col, col.a * k))
	draw_texture_rect(Sprites.white(), Rect2(at - Vector2(2, 2), Vector2(4, 4)), false, Color(1, 1, 1, k))


## Little props for idle animations, drawn over the sprite.
func _draw_idle_props(origin: Vector2, size: Vector2) -> void:
	if kind == "archer" and stow_t > 0.0 and not _idling() and swing <= 0.0:
		var away := _archer_arrow(origin)
		if not away.is_empty() and not away["behind"]:
			_draw_arrow(away["pos"], away["angle"])
		return
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


## Archer idle: where the arrow is, as {pos, angle, behind}, or {} while her hands are
## empty. Out of the quiver once, then twirled, flipped end over end and turned, round and
## round for as long as she stands idle; back into the quiver only as she moves off
## (stow_t). Every move eases in and out so it flows.
func _archer_arrow(origin: Vector2) -> Dictionary:
	var hand := _sprite_px(origin, 2.5, 10)
	var quiver := _sprite_px(origin, 2.0, 6.0)    # on her back, just behind the shoulder
	var lifted := quiver + Vector2(0, -14)
	var up := -PI / 2
	var ahead := 0.0 if flip > 0 else PI
	if stow_t > 0.0 and not _idling():
		var s := 1.0 - stow_t / ARCHER_STOW
		if s < 0.57:
			# Back over the shoulder...
			var k := smoothstep(0.0, 1.0, s / 0.57)
			return {"pos": hand.lerp(lifted, k), "angle": lerp_angle(ahead, up, k), "behind": false}
		# ...and down into the quiver.
		var k := smoothstep(0.0, 1.0, (s - 0.57) / 0.43)
		return {"pos": lifted.lerp(quiver, k), "angle": up, "behind": true, "alpha": 1.0 - k}
	var t := idle_t - IDLE_AFTER
	if t < 0.5:
		# Reaches back and slides an arrow up out of the quiver.
		var k := smoothstep(0.0, 1.0, t / 0.5)
		return {"pos": quiver.lerp(lifted, k), "angle": up, "behind": true, "alpha": k}
	if t < ARCHER_DRAW:
		# Brings it round to her hand, turning it level.
		var k := smoothstep(0.0, 1.0, (t - 0.5) / 0.4)
		return {"pos": lifted.lerp(hand, k), "angle": lerp_angle(up, ahead, k), "behind": false}
	var u := fmod(t - ARCHER_DRAW, ARCHER_LOOP)
	if u < 1.5:
		# Twirls it: spins up, three turns, spins down.
		var k := smoothstep(0.0, 1.0, u / 1.5)
		return {"pos": hand, "angle": ahead + k * TAU * 3.0, "behind": false}
	if u < 2.3:
		# Flips it up into the air, end over end, and catches it.
		var k := (u - 1.5) / 0.8
		return {"pos": hand + Vector2(0, -sin(PI * k) * 34.0), "angle": ahead + smoothstep(0.0, 1.0, k) * TAU * 2.0, "behind": false}
	# One lazy turn, and round again.
	var k := smoothstep(0.0, 1.0, (u - 2.3) / 1.0)
	return {"pos": hand, "angle": ahead + k * TAU, "behind": false}


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
