extends RefCounted
## Tuning values for warriors, enemies and waves. Edit these to rebalance the game.

const START_GOLD := 250
const PX_PER_FOOT := 10.0    # distances are worked out in pixels but shown to the player in feet


## A distance in pixels as the player sees it: "15 ft", "2.5 ft".
static func ft(px: float) -> String:
	var f := px / PX_PER_FOOT
	return "%d\u00a0ft" % roundi(f) if absf(f - roundf(f)) < 0.05 else "%.1f\u00a0ft" % f   # no line break before "ft"
const CASTLE_HP := 450.0     # the castle falls (and the game is lost) when this runs out

# Difficulties: castle health and prices (hiring, upgrading, walls) are multiplied by
# "castle" and "cost". With "permadeath" a downed troop dies for good after "down_time"
# seconds unless it's revived first (by a Healer or a Medic Bay); without it (only in
# the Tutorial and Freeplay) it gets back up then.
# The castle. Three tabs of its own:
#   Castle     four upgrade paths of four tiers (CASTLE_PATHS). Unlike a unit's, every
#              tier of every path can be bought; they just cost more.
#   Abilities  bought once each (ABILITIES), then used from the bar in the field's top-left corner
#              and recharged for "cooldown" seconds; "target" ones are aimed with a click.
#   Repair     mends the castle between waves, a chunk at a time (REPAIR_CHUNKS), at a
#              flat price: each share of max health costs that share of REPAIR_FULL_COST.
# Ability damage grows with the wave, like enemy health (see CASTLE_POWER_GROWTH).
const CASTLE_POWER_GROWTH := 0.9   # ability damage x (enemy health multiplier ^ this)
const REPAIR_CHUNKS := [0.1, 0.25, 0.5, 1.0]   # share of max health each Repair button mends (1.0 = all the way,
                                               # or as far as your gold goes when that's not enough)
const BUILD_TIME := 4.0           # seconds an Engineer takes to build an emplacement (not barricades)
const REPAIR_TIME := [2.0, 4.0]   # a repair takes [base] + [per share of max health] seconds of Engineers' work
const REPAIR_FULL_COST := 750     # gold to mend the castle from nothing to full; smaller repairs cost their share of it

# Castle path tier effects (each tier's numbers are the totals so far, not added on):
#   armor      the castle takes this much less damage
#   hp         castle max health x this (the castle gets the extra health at once)
#   guards     units posted on the castle wall: kind -> [how many, tiers per path]. They
#              hold fixed posts on the wall (see GUARD_POSTS in castle_powers.gd) and hit
#              anything within 25 ft of the castle; enemies can't reach them. Each tier
#              replaces the last one's guards. Priced a little under hiring and upgrading
#              the same troops; maxing Wall Archers costs about two 3-0-3-0 Archers,
#              maxing Wall Mages about a 2-2-2-0 Mage plus a 2-2-2-0 Frost Witch.
#   power      ability damage, Healing Light's healing and the Rally Horn's boost x this
#   recharge   ability recharge times x this
#   area       ability areas x this
const CASTLE_PATHS := [
	{"name": "Fortify", "tiers": [
		{"name": "Iron Gate", "cost": 120, "desc": "The castle takes 10% less damage", "effect": {"armor": 0.1}},
		{"name": "Stone Walls", "cost": 200, "desc": "+30% castle health, takes 15% less damage", "effect": {"armor": 0.15, "hp": 1.3}},
		{"name": "Buttresses", "cost": 320, "desc": "+30% castle health, takes 25% less damage", "effect": {"armor": 0.25, "hp": 1.3}},
		{"name": "Citadel", "cost": 500, "desc": "+60% castle health, takes 35% less damage", "effect": {"armor": 0.35, "hp": 1.6}},
	]},
	{"name": "Wall Archers", "tiers": [
		{"name": "Archer Post", "cost": 125, "desc": "2 Archers at the ends of the wall shoot anything within 25\u00a0ft of the castle", "effect": {"guards": {"archer": [2, [0, 0, 0, 0]]}}},
		{"name": "Bowmen", "cost": 205, "desc": "A third Archer on the gatehouse; all 3 upgraded 1-0-1-0", "effect": {"guards": {"archer": [3, [1, 0, 1, 0]]}}},
		{"name": "Veteran Bowmen", "cost": 270, "desc": "The 3 wall Archers are upgraded 2-0-2-0", "effect": {"guards": {"archer": [3, [2, 0, 2, 0]]}}},
		{"name": "Royal Longbows", "cost": 210, "desc": "The 3 wall Archers are upgraded 3-0-3-0", "effect": {"guards": {"archer": [3, [3, 0, 3, 0]]}}},
	]},
	{"name": "Wall Mages", "tiers": [
		{"name": "Arcane Watch", "cost": 195, "desc": "A Mage and a Frost Witch on the wall hit anything within 25\u00a0ft of the castle", "effect": {"guards": {"mage": [1, [0, 0, 0, 0]], "frost": [1, [0, 0, 0, 0]]}}},
		{"name": "Apprentices", "cost": 105, "desc": "A second Mage joins the wall", "effect": {"guards": {"mage": [2, [0, 0, 0, 0]], "frost": [1, [0, 0, 0, 0]]}}},
		{"name": "Circle of Magi", "cost": 300, "desc": "The 2 Mages and the Frost Witch are upgraded 1-1-1-0", "effect": {"guards": {"mage": [2, [1, 1, 1, 0]], "frost": [1, [1, 1, 1, 0]]}}},
		{"name": "Archmage Tower", "cost": 215, "desc": "2 Mages and 2 Frost Witches, upgraded 2-2-2-0", "effect": {"guards": {"mage": [2, [2, 2, 2, 0]], "frost": [2, [2, 2, 2, 0]]}}},
	]},
	{"name": "Ability Power", "tiers": [
		{"name": "Focus Stones", "cost": 120, "desc": "Abilities 20% stronger (damage, healing and the Rally Horn boost)", "effect": {"power": 1.2}},
		{"name": "War Council", "cost": 200, "desc": "Abilities 35% stronger, recharge 15% faster", "effect": {"power": 1.35, "recharge": 0.85}},
		{"name": "Ley Lines", "cost": 320, "desc": "Abilities 55% stronger, recharge 20% faster, 20% wider", "effect": {"power": 1.55, "recharge": 0.8, "area": 1.2}},
		{"name": "Crown of Storms", "cost": 500, "desc": "Abilities 90% stronger, recharge 30% faster, 30% wider", "effect": {"power": 1.9, "recharge": 0.7, "area": 1.3}},
	]},
]

const ABILITIES := {
	"arrows": {"name": "Arrow Storm", "cost": 160, "cast": "target", "cooldown": 25.0, "color": Color(0.95, 0.85, 0.6),
		"radius": 85.0, "damage": 20.0, "volleys": 4,
		"desc": "Archers on the walls loose 4 volleys over 2 seconds onto a wide area. Every enemy under them takes damage each volley, flyers too."},
	"fireball": {"name": "Fireball", "cost": 200, "cast": "target", "cooldown": 30.0, "color": Color(1.0, 0.5, 0.2),
		"radius": 50.0, "damage": 110.0, "burn": [14.0, 4.0],
		"desc": "Hurls a ball of fire at a tight group: heavy damage to everything it hits, and it leaves them burning."},
	"frost": {"name": "Frost Orb", "cost": 180, "cast": "target", "cooldown": 30.0, "color": Color(0.6, 0.9, 1.0),
		"radius": 58.0, "damage": 25.0, "freeze": 2.5, "slow": [0.45, 5.0],
		"desc": "A ball of ice shatters over a group: they're frozen solid, then slowed while they thaw."},
	"lightning": {"name": "Thunderstrike", "cost": 220, "cast": "target", "cooldown": 28.0, "color": Color(0.75, 0.85, 1.0),
		"radius": 70.0, "damage": 75.0, "chain": 6, "hop": 130.0, "stun": 0.6,
		"desc": "Lightning strikes the enemy nearest where you click, then jumps from foe to foe, stunning each one."},
	"horn": {"name": "Rally Horn", "cost": 180, "cast": "instant", "cooldown": 45.0, "color": Color(1.0, 0.85, 0.35),
		"duration": 8.0, "buff": {"damage": 0.3, "rate": 0.25, "speed": 0.2},
		"desc": "The castle sounds the charge: for 8 seconds every unit deals 30% more damage, attacks 25% faster and moves 20% faster."},
	"heal": {"name": "Healing Light", "cost": 190, "cast": "target", "cooldown": 35.0, "color": Color(0.6, 1.0, 0.55),
		"radius": 90.0, "heal": 0.45, "revive": 0.35,
		"desc": "A column of holy light falls where you click: every troop in it heals 45% of its health, and downed troops there get back up with 35%."},
}

const DIFFICULTIES := {
	"easy": {"name": "Easy", "castle": 1.5, "cost": 0.8, "down_time": 30.0, "permadeath": true, "color": Color(0.55, 0.9, 0.55), "icon": "healer"},
	"normal": {"name": "Normal", "castle": 1.0, "cost": 1.0, "down_time": 20.0, "permadeath": true, "color": Color(0.95, 0.85, 0.45), "icon": "swordsman"},
	"hard": {"name": "Hard", "castle": 0.8, "cost": 1.15, "round": 5, "down_time": 15.0, "permadeath": true, "color": Color(1.0, 0.55, 0.3), "icon": "troll"},
}
const FINAL_WAVE := 20
const HP_GROWTH := 1.12      # enemy health multiplier per wave
const DAMAGE_GROWTH := 1.03  # enemy damage multiplier per wave
const BOUNTY_GROWTH := 0.04  # extra bounty per wave (0.04 = +4%)
# Past the final wave (endless), enemies toughen faster and gold comes in slower.
const LATE_HP_GROWTH := 1.16      # health multiplier per wave past FINAL_WAVE (instead of HP_GROWTH)
const LATE_DAMAGE_GROWTH := 1.06  # damage multiplier per wave past FINAL_WAVE (instead of DAMAGE_GROWTH)
const LATE_GOLD_STEP := 0.02      # past FINAL_WAVE, bounties and wave bonuses pay this much less per wave...
const LATE_GOLD_MIN := 0.4        # ...down to this share (mines and interest always pay in full)


## A price at a difficulty: base x mult, rounded to the nearest `step` gold (Hard
## rounds every price to 5g so it doesn't show odd amounts like 863g).
static func scaled_price(base: float, mult: float, step: int) -> int:
	var p := base * mult
	if step > 1:
		return maxi(step, roundi(p / step) * step)
	return maxi(1, roundi(p))


## How much an enemy's stat is multiplied at a level: growth per level up to the
## final wave, then the faster late growth on top.
static func level_growth(level: int, growth: float, late: float) -> float:
	var early := mini(level, FINAL_WAVE) - 1
	return pow(growth, early) * pow(late, maxi(0, level - FINAL_WAVE))

# range = gap between the warrior's edge and the enemy's edge.
# Warriors go after the nearest enemy anywhere on the field.
#
# Each warrior has four upgrade paths of four tiers. Any six upgrades can be bought,
# in any mix of paths (MAX_UPGRADES in warrior.gd): 4 + 2, 3 + 3, 2 + 2 + 1 + 1...
# Tier effects stack in order:
#   damage / rate / speed  multiply damage, attack cooldown, move speed
#   hp                     multiplies max health
#   armor                  cuts damage taken by this fraction (stacks multiplicatively)
#   range                  adds pixels
#   slow / slow_time       add to slow strength (0-1) and duration
#   slow_radius            frost bolts slow everything within this radius
#   freeze                 [chance per enemy slowed, seconds frozen]
#   crit                   [chance per attack, damage multiplier]
#   chain                  mage chain lightning: damage, jumps, cooldown
#   lance                  mage arcane lance on the toughest enemy in range: damage, cooldown
#   breath                 mage flame breath: damage per puff, interval, burn damage/s, burn seconds
#   combo                  extra hits per melee combo (extra blasts per volley if Ki is also taken)
#   knockback              [chance per combo finisher or ki blast, push distance]
#   blast                  ki blasts at range, thrown one after another: damage, count per volley, range, cooldown
#   beam                   line beam hitting every enemy in its path: damage, cooldown, width, range (aiming reach)
#   evade                  chance to dodge an enemy attack (the best one a unit has counts)
#   multiform              martial Techniques 1: once fighting in a wave, splits into copies that share his
#                          power: copies (how many), power (all bodies together; each gets power / bodies,
#                          and a lone body is back to 1), hp (a copy's share of max health), cooldown (to
#                          split again after a copy falls). Copies can't be sold and merge back when the wave ends.
#   teleport               blink to distant targets: cooldown, min_dist
#   stun                   blinding flash: radius, duration, cooldown
#   surge                  temporary power-up: cooldown, duration, damage mult, attack rate mult
#   splash                 adds to an exploding shell's blast radius
#   dash                   swordsman: after a second of running, dashes into a new target:
#                          damage (x normal), reach (px), stun, through (hits everything on the way),
#                          chain (when the foe it's fighting falls, dashes at once to the next in reach)
#   pierce / seek          archer: arrows go on through this many more enemies; seeking arrows
#                          find a new target when theirs falls and after each pierce
#   magnet                 mage Storm 3+: blasts pull charged (lightning-struck) enemies in: radius, pull
#   echo                   mage Arcane 3+: everything a blast hits bursts again: damage share, radius
#   fireball               mage Fire 3+: blasts are fireballs: splash mult, burn_dps, burn_time
#   decay                  mage Necromancy 3+: blasts rot what they hit: dps, duration; foes
#                          that die rotting rise as skeletons (up to the summon max)
#   summon                 mage Necromancy: raises skeletons during waves: cooldown, max, hp, damage, armor
#                          (they can't be sold and crumble when the wave ends)
#   frost_aura             frost: enemies near it are slowed and chilled: radius, slow, dps,
#                          freeze_every (0 = never), freeze_time
#   rage / crimson / golden
#                          martial Power path: rage {below, damage, rate} when hurt; crimson aura and
#                          golden form {cooldown, duration, damage, rate, speed, drain (HP share/s)}
#   heal_aura              healer: allies near it regenerate and are guarded: radius, regen
#                          (max HP share/s), defense, recover (downed allies hold on this much longer)
#   thorns_dps             bard Spellsong 4: plants and vines hurt what they catch (dmg/s)
#   befuddle               bard: [chance per note, seconds] a note confuses its target
#   confuse_vuln           bard: confused enemies take this much more damage
#   traps                  alchemist: drops charges while walking: every, max, damage, radius,
#                          stun, brew (carries the flasks' poison and acid)
#   burn                   [dps, seconds] arrows/shells set what they hit burning
#   rain                   archer tower: flaming arrows on the thickest crowd: damage, radius, cooldown
#   cluster                cannon: each shell scatters bomblets: count, damage share, radius
#   napalm                 cannon: shells leave burning ground: dps, duration
#   smite                  medic bay: each pulse hurts enemies in its radius: damage, slow, stun
#   gems                   gold mine: [chance per haul, value multiplier]
#   multishot              projectiles per attack, at different targets in range when possible
#   shell_stun             seconds every enemy caught in a shell's blast is stunned
#   heal_area              healer: [radius, fraction] other allies near the target are healed too
#   regen                  healer: [fraction of max HP per second, seconds] granted with each heal
#   revive                 healer: rez_speed (revive channel speed mult), aura (how much faster
#                          longer downed allies in range hold on), full (revive at full HP)
#
#   aura_damage / aura_rate / aura_defense / aura_speed / aura_regen / aura_recover
#                          statue / medic bay: allies posted in range deal more damage, attack
#                          faster, take less damage, move faster, regenerate (max HP share/s), hold
#                          on longer when downed (fractions; the strongest of each kind counts).
#                          A Bard's songs work the same way but on whoever is in earshot right now.
#   song_radius            bard: adds to how far its songs (buffs and debuffs) carry
#   discord                bard: enemies in earshot take more damage (vuln), deal less (weaken), move slower (slow)
#   overgrowth / vines / tornado / confuse
#                          bard spells, each on its own cooldown, cast on the thickest crowd in reach:
#                          a slowing patch of plants, rooting vines, a tornado that throws enemies back
#                          up the field, and confusion that makes enemies fight each other
#   poison                 alchemist: {dps, duration, stacks} each flask adds a stack (up to stacks)
#   cloud                  alchemist: {radius, duration} flasks leave a toxic cloud that poisons
#   corrode                alchemist: {amount, duration} splashed enemies take this much more damage
#   melt                   alchemist: the direct target also takes this fraction of its max HP
#   burst                  alchemist: enemies killed by a flask explode for this multiple of its damage
#   thorns                 barricade: attackers take this fraction of their max HP per strike (barbed wire)
#   wall_slow              barricade: [strength, reach] enemies this close to the wall are slowed
#   repair                 barricade: HP repaired per second during waves (the same for any length)
#   rebuild                barricade: seconds after breaking that the crew puts it back up (at half health)
#   shots_pass / troops_pass
#                          barricade: your troops' shots / your troops themselves go through it (enemies never do)
#   recharge               barricade: [max HP share per second, seconds unhit before it starts]
#   aegis                  barricade: [damage cut, reach] for allies near the wall
#   mortar                 cannoneer: shells arc high enough to clear walls (a plain cannon's can't)
#   interest               gold mine: [fraction of your gold paid at the end of each wave, cap]
#   wave_bonus             gold mine: flat gold paid at the end of each wave
#   hauls                  gold mine: more hauls allowed per wave (on top of the mine's "hauls")
#
# The Healer ("attack": "heal") never attacks: "damage" is the amount healed per cast.
# Support emplacements don't attack either; "damage" is their main number:
#   "mine"   gold paid every "cooldown" seconds while a wave is on, at most "hauls" times a wave
#   "pulse"  medic bay: HP healed for every ally posted in range every "cooldown" seconds
#   "aura"   statue: no attack; buffs allies within range
#
# Emplacements ("emplacement": true) are built where they're placed and never move:
# they shoot whatever comes into range. They can still be repositioned between waves.
#
# The Barricade ("attack": "wall") is drawn as a line from one click to another. Its
# price and upgrade costs scale with length, its health doesn't ("cost" is the price of the
# shortest wall; see barricade.gd). Enemies walk around walls when they can and
# break through only when there's no way past. Walls are solid to troops as well,
# and block their attacks (until the Energy Wall path lets them through); emplacements
# other than a plain Cannoneer, and lobbed flasks, fire over them (a Cannoneer needs
# the Mortar path), and a Martial Artist's Flash Step can carry it across.
# Mage and Frost Witch upgrade paths, shared with the Mage Tower and Frost Tower.
const MAGE_PATHS := [
	{"name": "Storm", "tiers": [
		{"name": "Static Charge", "cost": 50, "desc": "Casts 18% faster. Chain lightning 15 dmg x3 / 3s",
			"effect": {"rate": 0.85, "chain": {"damage": 15.0, "jumps": 3, "cooldown": 3.0}}},
		{"name": "Storm Weave", "cost": 75, "desc": "Casts 11% faster. Chain 22 dmg x4 / 2.6s",
			"effect": {"rate": 0.9, "chain": {"damage": 22.0, "jumps": 4, "cooldown": 2.6}}},
		{"name": "Thunderhead", "cost": 125, "desc": "Chain 35 dmg x5 / 2.2s. Blasts magnetize: they pull charged foes together",
			"effect": {"rate": 0.85, "chain": {"damage": 35.0, "jumps": 5, "cooldown": 2.2}, "magnet": {"radius": 90.0, "pull": 45.0}}},
		{"name": "Tempest", "cost": 210, "desc": "Casts 25% faster. Chain 60 dmg x7 / 1.6s. Stronger pull",
			"effect": {"rate": 0.8, "chain": {"damage": 60.0, "jumps": 7, "cooldown": 1.6}, "magnet": {"radius": 115.0, "pull": 65.0}}},
	]},
	{"name": "Arcane Lance", "tiers": [
		{"name": "Far Sight", "cost": 50, "desc": "+2.5\u00a0ft range. Lance the toughest foe: 80 dmg / 5s",
			"effect": {"range": 25.0, "lance": {"damage": 80.0, "cooldown": 5.0}}},
		{"name": "Focus", "cost": 75, "desc": "+2.5\u00a0ft range. Lance: 140 dmg / 4.5s",
			"effect": {"range": 25.0, "lance": {"damage": 140.0, "cooldown": 4.5}}},
		{"name": "Piercing Lance", "cost": 125, "desc": "Lance: 240 dmg / 4s. Everything a blast hits bursts again (50%)",
			"effect": {"range": 30.0, "lance": {"damage": 240.0, "cooldown": 4.0}, "echo": {"damage": 0.5, "radius": 35.0}}},
		{"name": "Annihilate", "cost": 210, "desc": "+4\u00a0ft range. Lance: 450 dmg / 3.2s. Bursts hit for 75%",
			"effect": {"range": 40.0, "lance": {"damage": 450.0, "cooldown": 3.2}, "echo": {"damage": 0.75, "radius": 45.0}}},
	]},
	{"name": "Fire", "tiers": [
		{"name": "Kindle", "cost": 40, "desc": "+15% blast dmg. Flame breath 2 dmg / 0.3s, burns 4/s",
			"effect": {"damage": 1.15, "breath": {"damage": 2.0, "interval": 0.3, "burn_dps": 4.0, "burn_time": 2.0}}},
		{"name": "Fan the Flames", "cost": 70, "desc": "+15% blast dmg. Breath 3 dmg / 0.25s, burns 7/s",
			"effect": {"damage": 1.15, "breath": {"damage": 3.0, "interval": 0.25, "burn_dps": 7.0, "burn_time": 2.5}}},
		{"name": "Firestorm", "cost": 120, "desc": "Breath 5 dmg / 0.2s, burns 12/s. Blasts become fireballs: 40% wider, burn 6/s",
			"effect": {"damage": 1.2, "breath": {"damage": 5.0, "interval": 0.2, "burn_dps": 12.0, "burn_time": 3.0},
				"fireball": {"splash": 1.4, "burn_dps": 6.0, "burn_time": 3.0}}},
		{"name": "Dragon's Breath", "cost": 195, "desc": "+30% dmg. Breath 8 / 0.15s, burns 22/s. Fireballs 60% wider, burn 12/s",
			"effect": {"damage": 1.3, "breath": {"damage": 8.0, "interval": 0.15, "burn_dps": 22.0, "burn_time": 3.5},
				"fireball": {"splash": 1.6, "burn_dps": 12.0, "burn_time": 3.5}}},
	]},
	{"name": "Necromancy", "note": "Skeletons rise only during waves, can't be sold, and crumble when the wave ends.", "tiers": [
		{"name": "Grave Call", "cost": 50, "desc": "Raises a skeleton every 8s (up to 2): 45 HP, 6 dmg",
			"effect": {"summon": {"cooldown": 8.0, "max": 2, "hp": 45.0, "damage": 6.0, "armor": 0.0}}},
		{"name": "Bone Legion", "cost": 75, "desc": "A skeleton every 7s (up to 3): 70 HP, 9 dmg",
			"effect": {"summon": {"cooldown": 7.0, "max": 3, "hp": 70.0, "damage": 9.0, "armor": 0.0}}},
		{"name": "Rotting Touch", "cost": 125, "desc": "Blasts rot foes (5 dmg/s); the rotting dead rise as skeletons. Up to 4: 100 HP, 13 dmg",
			"effect": {"summon": {"cooldown": 6.0, "max": 4, "hp": 100.0, "damage": 13.0, "armor": 0.0},
				"decay": {"dps": 5.0, "duration": 4.0}}},
		{"name": "Lich Lord", "cost": 210, "desc": "Rot 12 dmg/s. A skeleton every 5s (up to 6): 160 HP, 22 dmg, 20% armor",
			"effect": {"summon": {"cooldown": 5.0, "max": 6, "hp": 160.0, "damage": 22.0, "armor": 0.2},
				"decay": {"dps": 12.0, "duration": 4.0}}},
	]},
]
const FROST_PATHS := [
	{"name": "Deep Cold", "tiers": [
		{"name": "Chill", "cost": 30, "desc": "Slow +10%, lasts 0.4s longer", "effect": {"slow": 0.1, "slow_time": 0.4}},
		{"name": "Frostbite", "cost": 45, "desc": "Slow +10%, lasts 0.4s longer", "effect": {"slow": 0.1, "slow_time": 0.4}},
		{"name": "Bitter Wind", "cost": 75, "desc": "Slow +10%, lasts 0.5s longer", "effect": {"slow": 0.1, "slow_time": 0.5}},
		{"name": "Absolute Zero", "cost": 135, "desc": "Slow +15%, lasts 0.8s longer", "effect": {"slow": 0.15, "slow_time": 0.8}},
	]},
	{"name": "Blizzard", "tiers": [
		{"name": "Frost Nova", "cost": 35, "desc": "Bolts slow all enemies within 4.5\u00a0ft", "effect": {"slow_radius": 45.0}},
		{"name": "Snowstorm", "cost": 55, "desc": "Slow area grows to 6.5\u00a0ft", "effect": {"slow_radius": 65.0}},
		{"name": "Whiteout", "cost": 90, "desc": "Slow area grows to 8.5\u00a0ft", "effect": {"slow_radius": 85.0}},
		{"name": "Eternal Winter", "cost": 145, "desc": "Slow area grows to 11\u00a0ft", "effect": {"slow_radius": 110.0}},
	]},
	{"name": "Flash Freeze", "tiers": [
		{"name": "Rime", "cost": 35, "desc": "10% chance to freeze for 1s", "effect": {"freeze": [0.10, 1.0]}},
		{"name": "Hoarfrost", "cost": 55, "desc": "18% chance to freeze for 1.2s", "effect": {"freeze": [0.18, 1.2]}},
		{"name": "Glacial Grip", "cost": 100, "desc": "26% chance to freeze for 1.5s", "effect": {"freeze": [0.26, 1.5]}},
		{"name": "Shatterfrost", "cost": 155, "desc": "35% chance to freeze for 2s", "effect": {"freeze": [0.35, 2.0]}},
	]},
	{"name": "Frost Aura", "tiers": [
		{"name": "Chill Aura", "cost": 35, "desc": "Enemies within 6\u00a0ft are slowed 20%",
			"effect": {"frost_aura": {"radius": 60.0, "slow": 0.2, "dps": 0.0, "freeze_every": 0.0, "freeze_time": 0.0}}},
		{"name": "Biting Cold", "cost": 55, "desc": "Aura: 8\u00a0ft, slows 30%, 3 dmg/s",
			"effect": {"frost_aura": {"radius": 80.0, "slow": 0.3, "dps": 3.0, "freeze_every": 0.0, "freeze_time": 0.0}}},
		{"name": "Frozen Ground", "cost": 95, "desc": "Aura: 10\u00a0ft, slows 40%, 5 dmg/s; freezes all in it for 1s every 5s",
			"effect": {"frost_aura": {"radius": 100.0, "slow": 0.4, "dps": 5.0, "freeze_every": 5.0, "freeze_time": 1.0}}},
		{"name": "Heart of Winter", "cost": 155, "desc": "Aura: 12\u00a0ft, slows 50%, 9 dmg/s; freezes for 1.5s every 3.5s",
			"effect": {"frost_aura": {"radius": 120.0, "slow": 0.5, "dps": 9.0, "freeze_every": 3.5, "freeze_time": 1.5}}},
	]},
]

const WARRIORS := {
	"swordsman": {
		"name": "Swordsman", "cost": 50, "color": Color(0.9, 0.72, 0.3),
		"hp": 120.0, "speed": 90.0,
		"damage": 16.0, "range": 8.0, "cooldown": 0.6, "attack": "melee",
		"desc": "Tough and cheap. Charges in and holds enemies in place.",
		"paths": [
			{"name": "Damage", "tiers": [
				{"name": "Sharpened Edge", "cost": 25, "desc": "+30% damage", "effect": {"damage": 1.3}},
				{"name": "Heavy Strikes", "cost": 40, "desc": "+30% damage", "effect": {"damage": 1.3}},
				{"name": "Champion's Axe", "cost": 75, "desc": "+40% damage; cleaving blows hit every enemy in a wide arc in front (60%)", "effect": {"damage": 1.4, "cleave": {"arc": 150.0, "reach": 22.0, "damage": 0.6}}},
				{"name": "Kingsplitter", "cost": 140, "desc": "+60% damage; every blow is a spin attack that hits all enemies around him (100%)", "effect": {"damage": 1.6, "cleave": {"arc": 360.0, "reach": 34.0, "damage": 1.0}}},
			]},
			{"name": "Blades", "tiers": [
				{"name": "Quick Hands", "cost": 25, "desc": "Attacks 18% faster", "effect": {"rate": 0.85}},
				{"name": "Flurry", "cost": 40, "desc": "Attacks 18% faster", "effect": {"rate": 0.85}},
				{"name": "Blade Dance", "cost": 75, "desc": "Dual blades: every attack is followed by an off-hand strike (60%). Attacks 18% faster", "effect": {"rate": 0.85, "dual": 0.6}},
				{"name": "Whirlwind", "cost": 140, "desc": "Off-hand strikes hit harder (80%). Attacks 25% faster", "effect": {"rate": 0.8, "dual": 0.8}},
			]},
			{"name": "Health", "tiers": [
				{"name": "Padded Armor", "cost": 20, "desc": "+35% health, takes 10% less damage", "effect": {"hp": 1.35, "armor": 0.1}},
				{"name": "Chainmail", "cost": 35, "desc": "+35% health, takes 10% less damage", "effect": {"hp": 1.35, "armor": 0.1}},
				{"name": "Plate and Shield", "cost": 65, "desc": "+40% health, 10% less damage, 15% chance to block a hit", "effect": {"hp": 1.4, "armor": 0.1, "block": 0.15}},
				{"name": "Juggernaut", "cost": 110, "desc": "+50% health, 15% less damage, 25% block chance", "effect": {"hp": 1.5, "armor": 0.15, "block": 0.25}},
			]},
			{"name": "Charge", "tiers": [
				{"name": "Light Step", "cost": 25, "desc": "+10% move speed", "effect": {"speed": 1.1}},
				{"name": "Forced March", "cost": 40, "desc": "+8% move speed", "effect": {"speed": 1.08}},
				{"name": "Running Strike", "cost": 75, "desc": "+8% move speed. After a second of running, dashes into a new target for a 2x strike",
					"effect": {"speed": 1.08, "dash": {"damage": 2.0, "reach": 70.0, "stun": 0.0, "through": false, "chain": false}}},
				{"name": "Unstoppable", "cost": 140, "desc": "Dash strikes 3x, bowls through foes and stuns 0.6s. When his foe falls, he dashes straight to the next",
					"effect": {"speed": 1.1, "dash": {"damage": 3.0, "reach": 90.0, "stun": 0.6, "through": true, "chain": true}}},
			]},
		],
	},
	"archer": {
		"name": "Archer", "cost": 70, "color": Color(0.4, 0.75, 0.35),
		"hp": 50.0, "speed": 125.0,
		"damage": 9.0, "range": 170.0, "cooldown": 0.7, "attack": "arrow",
		"projectile_speed": 650.0,
		"desc": "Long range, steady single-target damage. Fragile up close.",
		"paths": [
			{"name": "Damage", "tiers": [
				{"name": "Barbed Arrows", "cost": 30, "desc": "+30% damage", "effect": {"damage": 1.3}},
				{"name": "Heavy Draw", "cost": 50, "desc": "+30% damage", "effect": {"damage": 1.3}},
				{"name": "Piercing Tips", "cost": 90, "desc": "+40% damage", "effect": {"damage": 1.4}},
				{"name": "Dragonbone Bow", "cost": 160, "desc": "+60% damage", "effect": {"damage": 1.6}},
			]},
			{"name": "Range", "tiers": [
				{"name": "Longbow", "cost": 30, "desc": "+3\u00a0ft range", "effect": {"range": 30.0}},
				{"name": "Eagle Eye", "cost": 50, "desc": "+3\u00a0ft range", "effect": {"range": 30.0}},
				{"name": "Sharpshooter", "cost": 85, "desc": "+4\u00a0ft range, 25% chance to crit for 3x", "effect": {"range": 40.0, "crit": [0.25, 3.0]}},
				{"name": "Skyreach", "cost": 145, "desc": "+6\u00a0ft range, 40% chance to crit for 4x", "effect": {"range": 60.0, "crit": [0.4, 4.0]}},
			]},
			{"name": "Attack Speed", "tiers": [
				{"name": "Quick Nock", "cost": 30, "desc": "Fires 18% faster", "effect": {"rate": 0.85}},
				{"name": "Rapid Fire", "cost": 50, "desc": "Fires 18% faster", "effect": {"rate": 0.85}},
				{"name": "Volley", "cost": 90, "desc": "Fires 25% faster", "effect": {"rate": 0.8}},
				{"name": "Arrow Storm", "cost": 160, "desc": "Fires 43% faster", "effect": {"rate": 0.7}},
			]},
			{"name": "Trick Shots", "tiers": [
				{"name": "Split Shot", "cost": 35, "desc": "Fires 2 arrows at different enemies", "effect": {"multishot": 2}},
				{"name": "Bodkin Points", "cost": 55, "desc": "Arrows pierce: each hits up to 2 enemies", "effect": {"pierce": 1}},
				{"name": "Seeker Arrows", "cost": 95, "desc": "Arrows home in: a new foe if theirs falls, the next one after each pierce. Hits up to 3",
					"effect": {"pierce": 2, "seek": true}},
				{"name": "Storm of Seekers", "cost": 165, "desc": "Fires 3 seeking arrows, each hitting up to 4 enemies", "effect": {"multishot": 3, "pierce": 3}},
			]},
		],
	},
	"mage": {
		"name": "Mage", "cost": 120, "color": Color(0.7, 0.4, 0.95),
		"hp": 45.0, "speed": 95.0,
		"damage": 12.0, "range": 130.0, "cooldown": 1.4, "attack": "orb",
		"projectile_speed": 380.0, "splash": 55.0,
		"desc": "Arcane blasts that hit every enemy in a small area.",
		"paths": MAGE_PATHS,
	},
	"frost": {
		"name": "Frost Witch", "cost": 90, "color": Color(0.5, 0.85, 1.0),
		"hp": 55.0, "speed": 105.0,
		"damage": 4.0, "range": 130.0, "cooldown": 0.9, "attack": "frost",
		"projectile_speed": 500.0, "slow": 0.4, "slow_time": 1.6,
		"desc": "Slows enemies so your other warriors get more hits in.",
		"paths": FROST_PATHS,
	},
	"martial": {
		"name": "Martial Artist", "cost": 150, "color": Color(0.95, 0.55, 0.15),
		"hp": 170.0, "speed": 150.0,
		"damage": 14.0, "range": 8.0, "cooldown": 1.0, "attack": "combo", "combo": 3,
		"desc": "Strong close-range brawler: lightning-fast three-hit combos.",
		"paths": [
			{"name": "Ki", "tiers": [
				{"name": "Ki Blast", "cost": 90, "desc": "Volleys of 3 ki blasts at range, 10 dmg each / 1.4s",
					"effect": {"blast": {"damage": 10.0, "count": 3, "range": 160.0, "cooldown": 1.4}}},
				{"name": "Ki Barrage", "cost": 140, "desc": "Blasts hit for 15 dmg each, volley every 1.2s",
					"effect": {"blast": {"damage": 15.0, "count": 3, "range": 175.0, "cooldown": 1.2}}},
				{"name": "Prince's Pride", "cost": 230, "desc": "Blasts hit for 34 dmg each, volley every 1.0s",
					"effect": {"blast": {"damage": 34.0, "count": 3, "range": 190.0, "cooldown": 1.0}}},
				{"name": "Starburst Barrage", "cost": 380, "desc": "Blasts hit for 42 dmg / 0.9s and explode, hitting everything in a 4\u00a0ft splash",
					"effect": {"blast": {"damage": 42.0, "count": 3, "range": 200.0, "cooldown": 0.9, "splash": 40.0}}},
			]},
			{"name": "Combat", "note": "With Ki, extra hits become extra blasts per volley.", "tiers": [
				{"name": "Desert Bandit", "cost": 80, "desc": "+1 hit per combo", "effect": {"combo": 1}},
				{"name": "Wolf Fang Fist", "cost": 130, "desc": "+1 hit. 15% chance the finisher knocks back",
					"effect": {"combo": 1, "knockback": [0.15, 40.0]}},
				{"name": "Battle Instinct", "cost": 220, "desc": "+1 hit, 20% finisher knockback, +30% dmg",
					"effect": {"combo": 1, "knockback": [0.2, 50.0], "damage": 1.3}},
				{"name": "Neo Wolf Fang Fist", "cost": 360, "desc": "+2 hits, 25% finisher knockback, +40% dmg",
					"effect": {"combo": 2, "knockback": [0.25, 60.0], "damage": 1.4}},
			]},
			{"name": "Techniques", "tiers": [
				{"name": "Multiform", "cost": 85, "desc": "In battle, splits into 2 bodies sharing his power (60% each). A copy that falls gives its power back",
					"effect": {"multiform": {"copies": 1, "power": 1.2, "hp": 0.6, "cooldown": 10.0}}},
				{"name": "Flash Step", "cost": 130, "desc": "Teleports straight to distant targets (every 4s)",
					"effect": {"teleport": {"cooldown": 4.0, "min_dist": 90.0}}},
				{"name": "Radiant Flash", "cost": 220, "desc": "Blinds and stuns nearby enemies for 2s (every 9s)",
					"effect": {"stun": {"radius": 110.0, "duration": 2.0, "cooldown": 9.0}}},
				{"name": "Turtle Wave", "cost": 360, "desc": "Every 5s, a beam that hits every enemy in a line: 350 dmg",
					"effect": {"beam": {"damage": 350.0, "cooldown": 5.0, "width": 30.0, "range": 260.0}}},
			]},
			{"name": "Power", "note": "The crimson aura and the golden form stack.", "tiers": [
				{"name": "Turtle Shell Training", "cost": 85, "desc": "+15% damage, attacks 10% faster", "effect": {"damage": 1.15, "rate": 0.9}},
				{"name": "Limit Break", "cost": 130, "desc": "30% chance to dodge enemy attacks. Below half health: +40% damage, attacks 25% faster",
					"effect": {"evade": 0.3, "rage": {"below": 0.5, "damage": 1.4, "rate": 1.25}}},
				{"name": "Tenfold Aura", "cost": 220, "desc": "Every 15s, a crimson aura for 5s: 2x dmg, 50% faster attacks and moves; burns 3% HP/s",
					"effect": {"crimson": {"cooldown": 15.0, "duration": 5.0, "damage": 2.0, "rate": 1.5, "speed": 1.5, "drain": 0.03}}},
				{"name": "Golden Warrior", "cost": 380, "desc": "Goes golden for 12s (every 30s): 2.5x dmg, 40% faster attacks, 30% faster moves",
					"effect": {"golden": {"cooldown": 30.0, "duration": 12.0, "damage": 2.5, "rate": 1.4, "speed": 1.3}}},
			]},
		],
	},
	"healer": {
		"name": "Healer", "cost": 90, "color": Color(0.55, 0.95, 0.55),
		"hp": 70.0, "speed": 110.0,
		"damage": 16.0, "range": 140.0, "cooldown": 1.1, "attack": "heal",
		"revive_time": 3.0, "revive_hp": 0.4,
		"desc": "Troop. Heals the most injured ally nearby and revives downed allies. Never attacks.",
		"paths": [
			{"name": "Mending", "tiers": [
				{"name": "Herbal Salves", "cost": 35, "desc": "Heals 30% more", "effect": {"damage": 1.3}},
				{"name": "Blessed Water", "cost": 55, "desc": "Heals 30% more", "effect": {"damage": 1.3}},
				{"name": "Greater Heal", "cost": 100, "desc": "Heals 40% more, casts 15% faster", "effect": {"damage": 1.4, "rate": 0.85}},
				{"name": "Divine Light", "cost": 180, "desc": "Heals 70% more, +4\u00a0ft range", "effect": {"damage": 1.7, "range": 40.0}},
			]},
			{"name": "Radiance", "tiers": [
				{"name": "Soothing Aura", "cost": 40, "desc": "Allies near the target are healed for 40%", "effect": {"heal_area": [50.0, 0.4]}},
				{"name": "Wide Blessing", "cost": 60, "desc": "Area heal: wider, 55%", "effect": {"heal_area": [70.0, 0.55]}},
				{"name": "Sunburst", "cost": 110, "desc": "Area heal: wider still, 75%", "effect": {"heal_area": [95.0, 0.75]}},
				{"name": "Sanctuary", "cost": 190, "desc": "Area heal: huge, full strength", "effect": {"heal_area": [130.0, 1.0]}},
			]},
			{"name": "Renewal", "tiers": [
				{"name": "Rejuvenate", "cost": 35, "desc": "Healed allies regenerate 2% HP/s for 5s", "effect": {"regen": [0.02, 5.0]}},
				{"name": "Lifebloom", "cost": 55, "desc": "Regeneration: 3.5% HP/s for 6s", "effect": {"regen": [0.035, 6.0]}},
				{"name": "Second Wind", "cost": 100, "desc": "Revives 40% faster; downed allies in range hold on 50% longer before they die", "effect": {"revive": {"rez_speed": 1.67, "aura": 1.5, "full": false}}},
				{"name": "Lifebinder", "cost": 180, "desc": "Revives 3x faster at full HP; downed allies in range hold on 2.5x longer", "effect": {"revive": {"rez_speed": 3.0, "aura": 2.5, "full": true}}},
			]},
			{"name": "Halo", "tiers": [
				{"name": "Gentle Presence", "cost": 40, "desc": "Allies within 6\u00a0ft regain 1% HP/s",
					"effect": {"heal_aura": {"radius": 60.0, "regen": 0.01, "defense": 0.0, "recover": 0.0}}},
				{"name": "Warm Glow", "cost": 60, "desc": "Aura: 8\u00a0ft, 1.5% HP/s",
					"effect": {"heal_aura": {"radius": 80.0, "regen": 0.015, "defense": 0.0, "recover": 0.0}}},
				{"name": "Holy Ground", "cost": 110, "desc": "Aura: 10\u00a0ft, 2.5% HP/s; allies in it take 10% less damage",
					"effect": {"heal_aura": {"radius": 100.0, "regen": 0.025, "defense": 0.1, "recover": 0.0}}},
				{"name": "Seraph's Halo", "cost": 190, "desc": "Aura: 12\u00a0ft, 4% HP/s, 20% less damage; downed allies in it hold on 2x longer",
					"effect": {"heal_aura": {"radius": 120.0, "regen": 0.04, "defense": 0.2, "recover": 1.0}}},
			]},
		],
	},
	"bard": {
		"name": "Bard", "cost": 100, "color": Color(0.95, 0.55, 0.85),
		"hp": 60.0, "speed": 115.0,
		"damage": 7.0, "range": 150.0, "cooldown": 1.0, "attack": "note",
		"projectile_speed": 450.0, "song_radius": 110.0,
		"desc": "Troop. Plucks sharp notes; upgrades into songs that empower allies or unsettle enemies, or into nature spells. Its instrument changes with its upgrades.",
		"paths": [
			{"name": "Inspire", "tiers": [
				{"name": "Marching Song", "cost": 40, "desc": "Allies in earshot attack 10% faster", "effect": {"aura_rate": 0.1}},
				{"name": "Battle Hymn", "cost": 65, "desc": "Allies: +15% attack speed, +10% damage", "effect": {"aura_rate": 0.15, "aura_damage": 0.1}},
				{"name": "Anthem of Heroes", "cost": 115, "desc": "Allies: +20% attack speed, +20% damage; song carries 3\u00a0ft further", "effect": {"aura_rate": 0.2, "aura_damage": 0.2, "song_radius": 30.0}},
				{"name": "Legendary Ballad", "cost": 200, "desc": "Allies: +30% attack speed, +30% damage, +15% move speed", "effect": {"aura_rate": 0.3, "aura_damage": 0.3, "aura_speed": 0.15}},
			]},
			{"name": "Discord", "tiers": [
				{"name": "Mocking Verse", "cost": 40, "desc": "Enemies in earshot take 10% more damage", "effect": {"discord": {"vuln": 0.1, "weaken": 0.0, "slow": 0.0}}},
				{"name": "Dirge", "cost": 65, "desc": "Enemies: take 15% more damage, deal 15% less", "effect": {"discord": {"vuln": 0.15, "weaken": 0.15, "slow": 0.0}}},
				{"name": "Cacophony", "cost": 115, "desc": "Enemies: take 22% more, deal 25% less; song carries 3\u00a0ft further", "effect": {"discord": {"vuln": 0.22, "weaken": 0.25, "slow": 0.0}, "song_radius": 30.0}},
				{"name": "Requiem", "cost": 200, "desc": "Enemies: take 32% more, deal 35% less, move 20% slower", "effect": {"discord": {"vuln": 0.32, "weaken": 0.35, "slow": 0.2}}},
			]},
			{"name": "Spellsong", "note": "Each of the first three tiers adds a spell; all learned spells keep being cast.", "tiers": [
				{"name": "Overgrowth", "cost": 45, "desc": "Every 6s: a patch of plants slows enemies 50% for 4s",
					"effect": {"overgrowth": {"radius": 70.0, "slow": 0.5, "duration": 4.0, "cooldown": 6.0}}},
				{"name": "Vine Snare", "cost": 70, "desc": "Every 7s: vines hold enemies in place for 1.5s",
					"effect": {"vines": {"radius": 55.0, "duration": 1.5, "cooldown": 7.0}}},
				{"name": "Tornado", "cost": 120, "desc": "Every 12s: a tornado throws enemies back up the field",
					"effect": {"tornado": {"radius": 60.0, "push": 90.0, "cooldown": 12.0}}},
				{"name": "Thornwild", "cost": 210, "desc": "Plants and vines grow thorns: anything caught in them takes 10 dmg/s",
					"effect": {"thorns_dps": 10.0}},
			]},
			{"name": "Bewitch", "tiers": [
				{"name": "Befuddle", "cost": 40, "desc": "Notes have a 15% chance to confuse their target for 1.5s", "effect": {"befuddle": [0.15, 1.5]}},
				{"name": "Mesmerize", "cost": 65, "desc": "Notes: 25% chance to confuse for 2s", "effect": {"befuddle": [0.25, 2.0]}},
				{"name": "Confusion", "cost": 115, "desc": "Every 12s: enemies in an area fight each other for 4s",
					"effect": {"befuddle": [0.25, 2.0], "confuse": {"radius": 75.0, "duration": 4.0, "cooldown": 12.0}}},
				{"name": "Puppet Master", "cost": 210, "desc": "Confusion every 8s, wider, 5s; confused foes take 25% more damage. Notes: 35% for 2.5s",
					"effect": {"befuddle": [0.35, 2.5], "confuse": {"radius": 95.0, "duration": 5.0, "cooldown": 8.0}, "confuse_vuln": 0.25}},
			]},
		],
	},
	"alchemist": {
		"name": "Alchemist", "cost": 110, "color": Color(0.55, 0.9, 0.35),
		"hp": 65.0, "speed": 85.0,
		"damage": 10.0, "range": 135.0, "cooldown": 1.3, "attack": "flask",
		"projectile_speed": 330.0, "splash": 28.0,
		"desc": "Troop. Lobs flasks that splash a small area; upgrades into poison, acid or explosives.",
		"paths": [
			{"name": "Toxins", "tiers": [
				{"name": "Nightshade", "cost": 35, "desc": "Flasks poison: 3 dmg/s for 4s, stacks twice", "effect": {"poison": {"dps": 3.0, "duration": 4.0, "stacks": 2}}},
				{"name": "Hemlock", "cost": 55, "desc": "Poison: 5 dmg/s, stacks 3 times", "effect": {"poison": {"dps": 5.0, "duration": 4.0, "stacks": 3}}},
				{"name": "Plague Cloud", "cost": 100, "desc": "Poison 6 dmg/s. Flasks leave a toxic cloud for 3s",
					"effect": {"poison": {"dps": 6.0, "duration": 4.0, "stacks": 3}, "cloud": {"radius": 45.0, "duration": 3.0}}},
				{"name": "Black Death", "cost": 180, "desc": "Poison 10 dmg/s, stacks 4 times. Bigger clouds last 4s",
					"effect": {"poison": {"dps": 10.0, "duration": 4.0, "stacks": 4}, "cloud": {"radius": 60.0, "duration": 4.0}}},
			]},
			{"name": "Acids", "tiers": [
				{"name": "Caustic Brew", "cost": 35, "desc": "Splashed enemies take 10% more damage for 4s", "effect": {"corrode": {"amount": 0.1, "duration": 4.0}}},
				{"name": "Etching Acid", "cost": 55, "desc": "Splashed enemies take 16% more damage", "effect": {"corrode": {"amount": 0.16, "duration": 4.0}}},
				{"name": "Dissolve", "cost": 100, "desc": "Splashed enemies take 24% more damage; +1.2\u00a0ft splash", "effect": {"corrode": {"amount": 0.24, "duration": 4.0}, "splash": 12.0}},
				{"name": "Universal Solvent", "cost": 180, "desc": "32% more damage taken; flasks melt 3% of the target's max HP",
					"effect": {"corrode": {"amount": 0.32, "duration": 4.0}, "melt": 0.03}},
			]},
			{"name": "Volatiles", "tiers": [
				{"name": "Blasting Salts", "cost": 40, "desc": "+35% damage, +0.8\u00a0ft splash", "effect": {"damage": 1.35, "splash": 8.0}},
				{"name": "Quick Fuse", "cost": 65, "desc": "Throws 20% faster, +30% damage", "effect": {"rate": 0.8, "damage": 1.3}},
				{"name": "Chain Reaction", "cost": 115, "desc": "Enemies killed by a flask explode for 2x its damage", "effect": {"burst": 2.0}},
				{"name": "Philosopher's Fire", "cost": 200, "desc": "+50% damage; throws 3 flasks at different enemies", "effect": {"damage": 1.5, "multishot": 3}},
			]},
			{"name": "Trapcraft", "note": "Charges are dropped while walking and stay until something steps on them.", "tiers": [
				{"name": "Tripwire Charges", "cost": 40, "desc": "Drops a hidden charge every 3s while walking (up to 3): 25 dmg blast",
					"effect": {"traps": {"every": 3.0, "max": 3, "damage": 25.0, "radius": 40.0, "stun": 0.0, "brew": false}}},
				{"name": "Black Powder", "cost": 65, "desc": "Up to 4 charges: 45 dmg, wider blast",
					"effect": {"traps": {"every": 2.5, "max": 4, "damage": 45.0, "radius": 48.0, "stun": 0.0, "brew": false}}},
				{"name": "Alchemical Mines", "cost": 115, "desc": "Up to 5 charges: 70 dmg; they carry your flasks' poison and acid",
					"effect": {"traps": {"every": 2.0, "max": 5, "damage": 70.0, "radius": 52.0, "stun": 0.0, "brew": true}}},
				{"name": "Minefield", "cost": 200, "desc": "A charge every 1.5s (up to 8): 110 dmg, stuns 1s",
					"effect": {"traps": {"every": 1.5, "max": 8, "damage": 110.0, "radius": 58.0, "stun": 1.0, "brew": true}}},
			]},
		],
	},
	"tower": {
		"name": "Archer Tower", "cost": 110, "color": Color(0.78, 0.74, 0.62),
		"hp": 260.0, "speed": 0.0, "emplacement": true,
		"damage": 14.0, "range": 250.0, "cooldown": 0.9, "attack": "arrow",
		"projectile_speed": 750.0,
		"desc": "Emplacement. Very long range, picks off single enemies. Never moves.",
		"paths": [
			{"name": "Damage", "tiers": [
				{"name": "Broadheads", "cost": 35, "desc": "+30% damage", "effect": {"damage": 1.3}},
				{"name": "Heavy Shafts", "cost": 55, "desc": "+30% damage", "effect": {"damage": 1.3}},
				{"name": "Ballista Bolts", "cost": 100, "desc": "+40% damage", "effect": {"damage": 1.4}},
				{"name": "Siege Bolts", "cost": 175, "desc": "+60% damage", "effect": {"damage": 1.6}},
			]},
			{"name": "Range", "tiers": [
				{"name": "Taller Walls", "cost": 35, "desc": "+4\u00a0ft range", "effect": {"range": 40.0}},
				{"name": "Lookout Post", "cost": 55, "desc": "+4\u00a0ft range", "effect": {"range": 40.0}},
				{"name": "Marksmen", "cost": 95, "desc": "+5\u00a0ft range, 20% chance to crit for 3x", "effect": {"range": 50.0, "crit": [0.2, 3.0]}},
				{"name": "Eagle's Nest", "cost": 165, "desc": "+7\u00a0ft range, 35% chance to crit for 3.5x", "effect": {"range": 70.0, "crit": [0.35, 3.5]}},
			]},
			{"name": "Garrison", "tiers": [
				{"name": "Drilled Crew", "cost": 35, "desc": "Fires 15% faster", "effect": {"rate": 0.87}},
				{"name": "Quick Hands", "cost": 55, "desc": "Fires 15% faster", "effect": {"rate": 0.87}},
				{"name": "Second Archer", "cost": 110, "desc": "Fires 2 arrows at different enemies", "effect": {"multishot": 2}},
				{"name": "Full Garrison", "cost": 190, "desc": "Fires 3 arrows, 10% faster", "effect": {"multishot": 3, "rate": 0.9}},
			]},
			{"name": "Fire Arrows", "tiers": [
				{"name": "Pitch-Soaked", "cost": 35, "desc": "Arrows set enemies burning: 4 dmg/s for 3s", "effect": {"burn": [4.0, 3.0]}},
				{"name": "Oil Pots", "cost": 55, "desc": "Burn 7 dmg/s", "effect": {"burn": [7.0, 3.0]}},
				{"name": "Fire Rain", "cost": 100, "desc": "Burn 10/s. Every 6s, flaming arrows rain on the thickest crowd: 40 dmg in 6\u00a0ft",
					"effect": {"burn": [10.0, 3.0], "rain": {"damage": 40.0, "radius": 60.0, "cooldown": 6.0}}},
				{"name": "Inferno Volley", "cost": 175, "desc": "Burn 18/s. Fire rain every 4s: 90 dmg in 7.5\u00a0ft",
					"effect": {"burn": [18.0, 3.0], "rain": {"damage": 90.0, "radius": 75.0, "cooldown": 4.0}}},
			]},
		],
	},
	"cannon": {
		"name": "Cannoneer", "cost": 160, "color": Color(1.0, 0.55, 0.2),
		"hp": 200.0, "speed": 0.0, "emplacement": true,
		"damage": 40.0, "range": 190.0, "cooldown": 3.0, "attack": "shell", "splash": 50.0,
		"projectile_speed": 360.0,
		"desc": "Emplacement. Fires shells that explode on impact. Slow to reload. Never moves. Walls block its shots until it's upgraded to a mortar.",
		"paths": [
			{"name": "Mortar", "tiers": [
				{"name": "Mortar Tube", "cost": 50, "desc": "Lobs shells high enough to clear walls. +20% damage", "effect": {"damage": 1.2, "mortar": true}},
				{"name": "Iron Shot", "cost": 80, "desc": "+30% damage", "effect": {"damage": 1.3}},
				{"name": "Siege Mortar", "cost": 135, "desc": "A huge mortar: +40% damage, +3\u00a0ft range", "effect": {"damage": 1.4, "range": 30.0}},
				{"name": "Great Mortar", "cost": 230, "desc": "+60% damage, +5\u00a0ft range", "effect": {"damage": 1.6, "range": 50.0}},
			]},
			{"name": "Blast", "tiers": [
				{"name": "Wider Charge", "cost": 50, "desc": "+1.5\u00a0ft blast radius", "effect": {"splash": 15.0}},
				{"name": "Shrapnel", "cost": 80, "desc": "+1.5\u00a0ft blast radius", "effect": {"splash": 15.0}},
				{"name": "Shockwave", "cost": 135, "desc": "+1.5\u00a0ft blast radius, 35% chance the blast knocks enemies back", "effect": {"splash": 15.0, "knockback": [0.35, 25.0]}},
				{"name": "Concussion Shells", "cost": 230, "desc": "+2\u00a0ft blast radius, stuns everything caught for 1s", "effect": {"splash": 20.0, "shell_stun": 1.0}},
			]},
			{"name": "Crew", "tiers": [
				{"name": "Practiced Loader", "cost": 50, "desc": "Reloads 15% faster", "effect": {"rate": 0.85}},
				{"name": "Powder Monkey", "cost": 80, "desc": "Reloads 15% faster", "effect": {"rate": 0.85}},
				{"name": "Gun Crew", "cost": 135, "desc": "Reloads 20% faster, +3\u00a0ft range", "effect": {"rate": 0.8, "range": 30.0}},
				{"name": "Double Barrel", "cost": 230, "desc": "Fires 2 shells per reload", "effect": {"multishot": 2}},
			]},
			{"name": "Payloads", "tiers": [
				{"name": "Incendiary Shot", "cost": 50, "desc": "Shells set enemies burning: 6 dmg/s for 3s", "effect": {"burn": [6.0, 3.0]}},
				{"name": "Cluster Shells", "cost": 80, "desc": "Burn 8/s. Each shell scatters 3 bomblets (35% dmg)",
					"effect": {"burn": [8.0, 3.0], "cluster": {"count": 3, "damage": 0.35, "radius": 28.0}}},
				{"name": "Napalm", "cost": 135, "desc": "Shells leave burning ground for 3s: 15 dmg/s",
					"effect": {"napalm": {"dps": 15.0, "duration": 3.0}}},
				{"name": "Hellfire", "cost": 230, "desc": "Burn 14/s. 5 bomblets (50%). Napalm 30 dmg/s for 4s",
					"effect": {"burn": [14.0, 3.0], "cluster": {"count": 5, "damage": 0.5, "radius": 32.0}, "napalm": {"dps": 30.0, "duration": 4.0}}},
			]},
		],
	},
	"magetower": {
		"name": "Mage Tower", "cost": 180, "color": Color(0.7, 0.4, 0.95),
		"hp": 220.0, "speed": 0.0, "emplacement": true,
		"damage": 18.0, "range": 190.0, "cooldown": 1.5, "attack": "orb",
		"projectile_speed": 400.0, "splash": 55.0,
		"desc": "Emplacement. Arcane blasts that hit every enemy in a small area.",
		"paths": MAGE_PATHS,
	},
	"frosttower": {
		"name": "Frost Tower", "cost": 140, "color": Color(0.5, 0.85, 1.0),
		"hp": 220.0, "speed": 0.0, "emplacement": true,
		"damage": 6.0, "range": 180.0, "cooldown": 0.8, "attack": "frost",
		"projectile_speed": 520.0, "slow": 0.45, "slow_time": 1.8,
		"desc": "Emplacement. Frost bolts that slow enemies over a long range.",
		"paths": FROST_PATHS,
	},
	"medbay": {
		"name": "Medic Bay", "cost": 130, "color": Color(1.0, 0.5, 0.5),
		"hp": 200.0, "speed": 0.0, "emplacement": true,
		"damage": 8.0, "range": 110.0, "cooldown": 2.0, "attack": "pulse",
		"revive_time": 6.0, "revive_hp": 0.4,
		"desc": "Emplacement. Every few seconds, heals every ally whose post is in its radius, wherever they are. All your healing upgrades (regeneration, keeping downed allies alive longer, revives) come from here.",
		"paths": [
			{"name": "Supplies", "tiers": [
				{"name": "Bandages", "cost": 40, "desc": "Heals 30% more", "effect": {"damage": 1.3}},
				{"name": "Poultices", "cost": 60, "desc": "Heals 30% more", "effect": {"damage": 1.3}},
				{"name": "Apothecary", "cost": 110, "desc": "Heals 40% more; allies in its radius regenerate 1.5% HP/s", "effect": {"damage": 1.4, "aura_regen": 0.015}},
				{"name": "Elixir Stores", "cost": 190, "desc": "Heals 70% more; allies in its radius regenerate 3% HP/s", "effect": {"damage": 1.7, "aura_regen": 0.03}},
			]},
			{"name": "Wards", "tiers": [
				{"name": "More Cots", "cost": 40, "desc": "+2.5\u00a0ft radius", "effect": {"range": 25.0}},
				{"name": "Second Tent", "cost": 60, "desc": "+2.5\u00a0ft radius", "effect": {"range": 25.0}},
				{"name": "Infirmary", "cost": 100, "desc": "+3\u00a0ft radius, pulses 15% faster", "effect": {"range": 30.0, "rate": 0.85}},
				{"name": "Grand Hospital", "cost": 170, "desc": "+4\u00a0ft radius, pulses 15% faster", "effect": {"range": 40.0, "rate": 0.85}},
			]},
			{"name": "Field Hospital", "tiers": [
				{"name": "Orderlies", "cost": 40, "desc": "Pulses 15% faster; downed allies in its radius hold on 30% longer before they die", "effect": {"rate": 0.85, "aura_recover": 0.3}},
				{"name": "Tonics", "cost": 60, "desc": "Healed allies regenerate 2% HP/s for 4s; downed allies hold on 60% longer", "effect": {"regen": [0.02, 4.0], "aura_recover": 0.6}},
				{"name": "Stretcher Bearers", "cost": 120, "desc": "Revives downed allies in its radius (6s each)",
					"effect": {"revive": {"rez_speed": 1.0, "aura": 1.5, "full": false}}},
				{"name": "Surgeons", "cost": 200, "desc": "Revives in 2s at full HP",
					"effect": {"revive": {"rez_speed": 3.0, "aura": 2.0, "full": true}}},
			]},
			{"name": "Consecration", "note": "Pulses at enemies in its radius whenever any are there, hurt allies or not.", "tiers": [
				{"name": "Blessed Ground", "cost": 40, "desc": "Each pulse sears enemies in its radius for 12 dmg",
					"effect": {"smite": {"damage": 12.0, "slow": 0.0, "stun": 0.0}}},
				{"name": "Holy Fire", "cost": 60, "desc": "Pulses sear enemies for 22 dmg and slow them 20%",
					"effect": {"smite": {"damage": 22.0, "slow": 0.2, "stun": 0.0}}},
				{"name": "Judgment", "cost": 110, "desc": "Pulses sear enemies for 40 dmg, slow 30%",
					"effect": {"smite": {"damage": 40.0, "slow": 0.3, "stun": 0.0}}},
				{"name": "Wrath of Heaven", "cost": 190, "desc": "Pulses sear enemies for 70 dmg, slow 30% and stun 1s",
					"effect": {"smite": {"damage": 70.0, "slow": 0.3, "stun": 1.0}}},
			]},
		],
	},
	"statue": {
		"name": "War Statue", "cost": 140, "color": Color(0.95, 0.8, 0.4),
		"hp": 260.0, "speed": 0.0, "emplacement": true,
		"damage": 0.0, "range": 120.0, "cooldown": 1.0, "attack": "aura", "aura_damage": 0.12,
		"desc": "Emplacement. Allies whose post is in its radius deal 12% more damage, wherever they fight.",
		"paths": [
			{"name": "Valor", "tiers": [
				{"name": "Polished Bronze", "cost": 45, "desc": "Allies deal 18% more damage", "effect": {"aura_damage": 0.18}},
				{"name": "Heroic Pose", "cost": 70, "desc": "Allies deal 24% more damage", "effect": {"aura_damage": 0.24}},
				{"name": "Golden Hero", "cost": 120, "desc": "Allies deal 32% more damage, +2.5\u00a0ft radius", "effect": {"aura_damage": 0.32, "range": 25.0}},
				{"name": "Monument of Kings", "cost": 210, "desc": "Allies deal 44% more damage, +2.5\u00a0ft radius", "effect": {"aura_damage": 0.44, "range": 25.0}},
			]},
			{"name": "Haste", "tiers": [
				{"name": "War Drums", "cost": 45, "desc": "Allies attack 8% faster", "effect": {"aura_rate": 0.08}},
				{"name": "Battle Hymn", "cost": 70, "desc": "Allies attack 12% faster", "effect": {"aura_rate": 0.12}},
				{"name": "Winged Victory", "cost": 120, "desc": "Allies attack 18% faster, +2.5\u00a0ft radius", "effect": {"aura_rate": 0.18, "range": 25.0}},
				{"name": "Swift Glory", "cost": 210, "desc": "Allies attack 26% faster, +2.5\u00a0ft radius", "effect": {"aura_rate": 0.26, "range": 25.0}},
			]},
			{"name": "Bulwark", "tiers": [
				{"name": "Stone Skin", "cost": 45, "desc": "Allies take 8% less damage", "effect": {"aura_defense": 0.08}},
				{"name": "Iron Will", "cost": 70, "desc": "Allies take 12% less damage", "effect": {"aura_defense": 0.12}},
				{"name": "Aegis", "cost": 120, "desc": "Allies take 18% less damage, +2.5\u00a0ft radius", "effect": {"aura_defense": 0.18, "range": 25.0}},
				{"name": "Unbreakable", "cost": 210, "desc": "Allies take 24% less damage, +2.5\u00a0ft radius", "effect": {"aura_defense": 0.24, "range": 25.0}},
			]},
			{"name": "March", "tiers": [
				{"name": "Marching Orders", "cost": 45, "desc": "Allies move 8% faster", "effect": {"aura_speed": 0.08}},
				{"name": "Forced March", "cost": 70, "desc": "Allies move 14% faster", "effect": {"aura_speed": 0.14}},
				{"name": "Swift Banners", "cost": 120, "desc": "Allies move 22% faster, +2.5\u00a0ft radius", "effect": {"aura_speed": 0.22, "range": 25.0}},
				{"name": "Lightning March", "cost": 210, "desc": "Allies move 32% faster, +2.5\u00a0ft radius", "effect": {"aura_speed": 0.32, "range": 25.0}},
			]},
		],
	},
	"mine": {
		"name": "Gold Mine", "cost": 150, "color": Color(1.0, 0.85, 0.3),
		"hp": 180.0, "speed": 0.0, "emplacement": true,
		"damage": 6.0, "range": 0.0, "cooldown": 5.0, "attack": "mine", "hauls": 8,
		"desc": "Emplacement. Digs up 6 gold every 5 seconds while a wave is on, up to 8 hauls per wave.",
		"paths": [
			{"name": "Deeper Shafts", "tiers": [
				{"name": "Pickaxes", "cost": 50, "desc": "+40% gold per haul", "effect": {"damage": 1.4}},
				{"name": "Blasting Powder", "cost": 80, "desc": "+40% gold per haul", "effect": {"damage": 1.4}},
				{"name": "Rich Vein", "cost": 130, "desc": "+50% gold per haul", "effect": {"damage": 1.5}},
				{"name": "Mother Lode", "cost": 220, "desc": "Double gold per haul", "effect": {"damage": 2.0}},
			]},
			{"name": "Mine Carts", "tiers": [
				{"name": "Rails", "cost": 50, "desc": "+2 hauls per wave, hauls 15% faster", "effect": {"hauls": 2, "rate": 0.85}},
				{"name": "More Carts", "cost": 80, "desc": "+2 hauls per wave, hauls 15% faster", "effect": {"hauls": 2, "rate": 0.85}},
				{"name": "Foreman", "cost": 130, "desc": "+3 hauls per wave, 15% faster, +30 gold every wave", "effect": {"hauls": 3, "rate": 0.85, "wave_bonus": 30}},
				{"name": "Gold Rush", "cost": 220, "desc": "+4 hauls per wave, 20% faster, +60 gold every wave", "effect": {"hauls": 4, "rate": 0.8, "wave_bonus": 60}},
			]},
			{"name": "Treasury", "tiers": [
				{"name": "Strongbox", "cost": 50, "desc": "End of wave: 2% interest on your gold (max 40)", "effect": {"interest": [0.02, 40]}},
				{"name": "Counting House", "cost": 80, "desc": "Interest: 3% (max 70)", "effect": {"interest": [0.03, 70]}},
				{"name": "Vault", "cost": 130, "desc": "Interest: 4% (max 100)", "effect": {"interest": [0.04, 100]}},
				{"name": "Royal Treasury", "cost": 220, "desc": "Interest: 6% (max 180)", "effect": {"interest": [0.06, 180]}},
			]},
			{"name": "Gemcutters", "tiers": [
				{"name": "Gem Sifting", "cost": 50, "desc": "Each haul: 10% chance of a gem worth 5x", "effect": {"gems": [0.1, 5.0]}},
				{"name": "Crystal Seam", "cost": 80, "desc": "Gems: 15% chance, worth 6x", "effect": {"gems": [0.15, 6.0]}},
				{"name": "Jewelers", "cost": 130, "desc": "Gems: 22% chance, worth 7x", "effect": {"gems": [0.22, 7.0]}},
				{"name": "Dragon's Hoard", "cost": 220, "desc": "Gems: 30% chance, worth 10x", "effect": {"gems": [0.3, 10.0]}},
			]},
		],
	},
	"barricade": {
		"name": "Barricade", "cost": 37, "color": Color(0.75, 0.55, 0.32),
		"hp": 320.0, "speed": 0.0, "emplacement": true,
		"damage": 0.0, "range": 0.0, "cooldown": 1.0, "attack": "wall",
		"cost_base": 15, "cost_per_100": 55, "min_length": 40.0,
		"desc": "Emplacement. Click two points to build a wall between them (price grows with length). Enemies go around it if they can, and break through if they can't. It blocks your troops and their shots too (unless it's an Energy Wall); towers, mortars and lobbed flasks fire over it. Walls only heal with Masonry or as an energy barrier, and a broken wall is gone for good unless Master Builders rebuild it.",
		"paths": [
			{"name": "Barbed Wire", "tiers": [
				{"name": "Barbed Strand", "cost": 30, "desc": "Attackers take 3% of their max HP per strike", "effect": {"thorns": 0.03}},
				{"name": "Double Strand", "cost": 50, "desc": "Attackers take 5% of their max HP per strike", "effect": {"thorns": 0.05}},
				{"name": "Razor Wire", "cost": 85, "desc": "Rebuilt as a barbed fence: 7% barbs. Enemies near it are slowed 25%", "effect": {"thorns": 0.07, "wall_slow": [0.25, 50.0]}},
				{"name": "Concertina Coils", "cost": 150, "desc": "10% barbs. Enemies near it are slowed 40%", "effect": {"thorns": 0.1, "wall_slow": [0.4, 60.0]}},
			]},
			{"name": "Fortify", "tiers": [
				{"name": "Lashed Logs", "cost": 30, "desc": "+20% health", "effect": {"hp": 1.2}},
				{"name": "Reinforced", "cost": 50, "desc": "+20% health, takes 10% less damage", "effect": {"hp": 1.2, "armor": 0.1}},
				{"name": "Stone Wall", "cost": 85, "desc": "+30% health, takes 20% less damage", "effect": {"hp": 1.3, "armor": 0.2}},
				{"name": "Fortress Wall", "cost": 150, "desc": "+40% health, takes 30% less damage", "effect": {"hp": 1.4, "armor": 0.3}},
			]},
			{"name": "Masonry", "note": "The crew repairs while a wave is on.", "tiers": [
				{"name": "Repair Crew", "cost": 30, "desc": "A builder repairs 4 HP/s during waves", "effect": {"repair": 4.0}},
				{"name": "Work Crew", "cost": 50, "desc": "Two builders: repairs 8 HP/s", "effect": {"repair": 8.0}},
				{"name": "Brick and Mortar", "cost": 85, "desc": "Rebuilt in brick: +30% health, repairs 12 HP/s", "effect": {"hp": 1.3, "repair": 12.0}},
				{"name": "Master Builders", "cost": 150, "desc": "+30% health, repairs 20 HP/s. If it breaks, the crew rebuilds it 12s later at half health",
					"effect": {"hp": 1.3, "repair": 20.0, "rebuild": 12.0}},
			]},
			{"name": "Energy Wall", "tiers": [
				{"name": "Arcane Lattice", "cost": 35, "desc": "Your troops' shots pass straight through the wall", "effect": {"shots_pass": true}},
				{"name": "Phase Gate", "cost": 55, "desc": "Your troops can walk through it too (enemies still can't)", "effect": {"troops_pass": true}},
				{"name": "Energy Barrier", "cost": 90, "desc": "Turned to pure energy: +30% health; recharges 3% HP/s after 3s unhit",
					"effect": {"hp": 1.3, "recharge": [0.03, 3.0]}},
				{"name": "Aegis Field", "cost": 160, "desc": "Recharges 6% HP/s after 2s. Allies within 6\u00a0ft of it take 15% less damage",
					"effect": {"recharge": [0.06, 2.0], "aegis": [0.15, 60.0]}},
			]},
		],
	},
}

# Raised by a Mage's (or Mage Tower's) Necromancy. Health, damage and armor come
# from the summoner's tier; these are the rest. Not hireable.
const SKELETON := {
	"name": "Skeleton", "cost": 0, "color": Color(0.88, 0.86, 0.78),
	"hp": 45.0, "speed": 100.0,
	"damage": 6.0, "range": 8.0, "cooldown": 0.9, "attack": "melee",
	"desc": "Raised by Necromancy. Can't be sold; crumbles when the wave ends.",
	"paths": [],
}

# Enemies that reach the castle stop and attack it until they're killed.
# fights = stops to attack warriors in its way (wolves slip around them instead).
# wall_damage = what an enemy does to a barricade or the castle per blow (default: its damage).
# flying = flies over walls and warriors; melee blows and cannon shells can't reach it.
# cc = how much of a stun, freeze, root or confusion still lands (bosses shrug most of it off);
# knock = how much of a knockback still lands (0 = immune, e.g. the Ogre King).
# boss = (Ogre King) the final boss, with a health bar across the top of the screen:
#   stomp   {damage, radius, cooldown, push, stun} hits every warrior (and 3x to walls) around
#           it, throws them back "push" pixels and stuns them for "stun" seconds
#   cleave  {reach, arc} its blows sweep an arc (radians) in front, hitting every warrior
#           within "reach" of its edge
#   summon  {kinds, count, cooldown} calls in enemies (picked at random from kinds) around it
#   horn    {kinds, count, cooldown} blows a war horn: a whole new wave marches in from the top
#   enrage  below this share of its health it moves 35% faster and attacks 30% faster
# breath = (Wyvern) breathes fire down on warriors as it flies over:
#          {damage, radius of the splash, range, cooldown}
# bomb = (Sapper) heads for walls and blows itself up against the first wall or warrior
#        it reaches: "wall" damage to walls, "units" to warriors, within "radius".
# ranged = (Skeleton Archer) {range, speed}: stops once a troop or the castle wall is within
#          "range" and shoots arrows ("damage" at troops, "wall_damage" at the castle)
# gooey = (Slime) blades, arrows, shells, flasks and fire sink in harmlessly unless it's iced
#         over; magic, ki and ice hurt it, ice twice over (see enemy.gd). It goes after troops
#         before the castle. goo = {slow, time}: its blows slow a troop's moving (and its
#         attacking by half as much).
# tier ranks how dangerous an enemy type is; "Strongest" targeting goes for the highest.
const ENEMIES := {
	"goblin": {"tier": 1, "hp": 30, "speed": 45.0, "damage": 4.0, "cooldown": 1.0, "fights": true,
			"bounty": 4, "radius": 11.0, "scale": 2.25, "color": Color(0.45, 0.7, 0.25)},
	"orc": {"tier": 3, "hp": 75, "speed": 35.0, "damage": 8.0, "cooldown": 1.2, "fights": true,
			"bounty": 7, "radius": 14.0, "scale": 2.75, "color": Color(0.35, 0.5, 0.3)},
	"wolf": {"tier": 2, "hp": 40, "speed": 80.0, "damage": 0.0, "cooldown": 1.0, "fights": false, "wall_damage": 3.0,
			"bounty": 6, "radius": 12.0, "scale": 2.5, "color": Color(0.6, 0.6, 0.65)},
	"bat": {"tier": 2, "hp": 26, "speed": 62.0, "damage": 0.0, "cooldown": 1.0, "fights": false, "flying": true, "wall_damage": 3.0,
			"bounty": 6, "radius": 11.0, "scale": 2.5, "color": Color(0.4, 0.3, 0.45)},
	# Hangs back out of reach and shoots: send something quick (or a ranged troop) at it.
	"skeleton_archer": {"tier": 2, "hp": 24, "speed": 40.0, "damage": 5.0, "wall_damage": 4.0, "cooldown": 1.7, "fights": true,
			"ranged": {"range": 150.0, "speed": 340.0},
			"bounty": 5, "radius": 11.0, "scale": 2.4, "color": Color(0.88, 0.86, 0.78)},
	# Only magic, ki and ice touch it, until it's iced over.
	"slime": {"tier": 3, "hp": 70, "speed": 30.0, "damage": 6.0, "wall_damage": 8.0, "cooldown": 1.3, "fights": true,
			"gooey": true, "goo": {"slow": 0.45, "time": 2.5},
			"bounty": 9, "radius": 14.0, "scale": 2.6, "color": Color(0.4, 0.85, 0.35)},
	"sapper": {"tier": 3, "hp": 45, "speed": 42.0, "damage": 0.0, "cooldown": 1.0, "fights": true,
			"bomb": {"wall": 250.0, "units": 40.0, "radius": 60.0},
			"bounty": 9, "radius": 12.0, "scale": 2.4, "color": Color(0.55, 0.6, 0.3)},
	"troll": {"tier": 4, "hp": 200, "speed": 25.0, "damage": 20.0, "cooldown": 1.6, "fights": true, "knock": 0.5,
			"bounty": 20, "radius": 19.0, "scale": 3.5, "color": Color(0.45, 0.55, 0.6)},
	"warlord": {"tier": 5, "hp": 600, "speed": 22.0, "damage": 35.0, "cooldown": 1.5, "fights": true, "cc": 0.5, "knock": 0.3,
			"bounty": 120, "radius": 24.0, "scale": 4.0, "color": Color(0.65, 0.2, 0.2)},
	# Flying elite: over walls and warriors, scorching whatever's below.
	"wyvern": {"tier": 5, "hp": 420, "speed": 30.0, "damage": 0.0, "cooldown": 1.5, "fights": false, "flying": true,
			"wall_damage": 30.0, "cc": 0.5, "knock": 0.3,
			"breath": {"damage": 16.0, "radius": 34.0, "range": 120.0, "cooldown": 2.2},
			"bounty": 100, "radius": 20.0, "scale": 3.75, "color": Color(0.3, 0.55, 0.45)},
	# Final boss: comes for the line once wave 20 (and every 10th wave after) is beaten.
	"ogre_king": {"tier": 6, "hp": 10000, "speed": 15.0, "damage": 60.0, "cooldown": 1.8, "fights": true, "cc": 0.3, "knock": 0.0,
			"wall_damage": 120.0, "boss": true,
			"stomp": {"damage": 50.0, "radius": 100.0, "cooldown": 6.0, "push": 70.0, "stun": 1.5},
			"cleave": {"reach": 34.0, "arc": 2.1},
			"summon": {"kinds": ["orc", "bat", "sapper"], "count": 3, "cooldown": 12.0},
			"horn": {"kinds": ["goblin", "orc", "orc", "wolf", "bat", "troll", "sapper"], "count": 8, "cooldown": 30.0},
			"enrage": 0.5,
			"bounty": 500, "radius": 30.0, "scale": 5.5, "color": Color(0.5, 0.6, 0.35)},
}
