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
# "castle" and "cost"; "down_time" is how long a knocked-out warrior stays down (with
# "permadeath", how long it has before it dies unless a Healer revives it).
const DIFFICULTIES := {
	"easy": {"name": "Easy", "castle": 1.5, "cost": 0.8, "down_time": 15.0, "permadeath": false, "color": Color(0.55, 0.9, 0.55), "icon": "healer"},
	"normal": {"name": "Normal", "castle": 1.0, "cost": 1.0, "down_time": 20.0, "permadeath": false, "color": Color(0.95, 0.85, 0.45), "icon": "swordsman"},
	"hard": {"name": "Hard", "castle": 0.8, "cost": 1.15, "down_time": 30.0, "permadeath": false, "color": Color(1.0, 0.55, 0.3), "icon": "troll"},
	"hardcore": {"name": "Hardcore", "castle": 1.0, "cost": 1.0, "down_time": 10.0, "permadeath": true, "color": Color(1.0, 0.3, 0.3), "icon": "warlord"},
}
const FINAL_WAVE := 20
const HP_GROWTH := 1.12      # enemy health multiplier per wave
const DAMAGE_GROWTH := 1.03  # enemy damage multiplier per wave
const BOUNTY_GROWTH := 0.04  # extra bounty per wave (0.04 = +4%)

# range = gap between the warrior's edge and the enemy's edge.
# Warriors go after the nearest enemy anywhere on the field.
#
# Each warrior has three upgrade paths of four tiers. Once two paths have been
# started the third locks, and only one path may go past tier 2 (so 4 + 2 is the max).
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
#   beam                   line beam hitting every enemy in its path: damage, cooldown, width
#   evade                  chance to dodge an enemy attack
#   teleport               blink to distant targets: cooldown, min_dist
#   stun                   blinding flash: radius, duration, cooldown
#   surge                  temporary power-up: cooldown, duration, damage mult, attack rate mult
#   splash                 adds to an exploding shell's blast radius
#   multishot              projectiles per attack, at different targets in range when possible
#   shell_stun             seconds every enemy caught in a shell's blast is stunned
#   heal_area              healer: [radius, fraction] other allies near the target are healed too
#   regen                  healer: [fraction of max HP per second, seconds] granted with each heal
#   revive                 healer: rez_speed (revive channel speed mult), aura (how much faster
#                          downed allies in range recover on their own), full (revive at full HP)
#
#   aura_damage / aura_rate / aura_defense / aura_speed
#                          statue: allies posted in range deal more damage, attack faster, take less
#                          damage, move faster (fractions; the strongest statue covering them counts).
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
#   thorns                 barricade: attackers take this fraction of their max HP per strike
#   wall_slow              barricade: [strength, reach] enemies this close to the wall are slowed
#   repair                 barricade: HP repaired per second during waves by a 160px wall; scales with length like the
#                          upgrade price does (walls never heal otherwise)
#   slits                  barricade: arrows at enemies near the wall: damage, cooldown, range
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
# price, health and upgrade costs scale with length ("cost" is the price of the
# shortest wall; see barricade.gd). Enemies walk around walls when they can and
# break through only when there's no way past. Walls are solid to troops as well,
# and block their attacks; emplacements and lobbed attacks (shells, flasks) fire
# over them, and a Martial Artist's Flash Step can carry it across.
# Mage and Frost Witch upgrade paths, shared with the Mage Tower and Frost Tower.
const MAGE_PATHS := [
	{"name": "Storm", "tiers": [
		{"name": "Static Charge", "cost": 50, "desc": "Casts 18% faster. Chain lightning 15 dmg x3 / 3s",
			"effect": {"rate": 0.85, "chain": {"damage": 15.0, "jumps": 3, "cooldown": 3.0}}},
		{"name": "Storm Weave", "cost": 75, "desc": "Casts 11% faster. Chain 22 dmg x4 / 2.6s",
			"effect": {"rate": 0.9, "chain": {"damage": 22.0, "jumps": 4, "cooldown": 2.6}}},
		{"name": "Thunderhead", "cost": 125, "desc": "Casts 18% faster. Chain 35 dmg x5 / 2.2s",
			"effect": {"rate": 0.85, "chain": {"damage": 35.0, "jumps": 5, "cooldown": 2.2}}},
		{"name": "Tempest", "cost": 210, "desc": "Casts 25% faster. Chain 60 dmg x7 / 1.6s",
			"effect": {"rate": 0.8, "chain": {"damage": 60.0, "jumps": 7, "cooldown": 1.6}}},
	]},
	{"name": "Arcane Lance", "tiers": [
		{"name": "Far Sight", "cost": 50, "desc": "+2.5\u00a0ft range. Lance the toughest foe: 80 dmg / 5s",
			"effect": {"range": 25.0, "lance": {"damage": 80.0, "cooldown": 5.0}}},
		{"name": "Focus", "cost": 75, "desc": "+2.5\u00a0ft range. Lance: 140 dmg / 4.5s",
			"effect": {"range": 25.0, "lance": {"damage": 140.0, "cooldown": 4.5}}},
		{"name": "Piercing Lance", "cost": 125, "desc": "+3\u00a0ft range. Lance: 240 dmg / 4s",
			"effect": {"range": 30.0, "lance": {"damage": 240.0, "cooldown": 4.0}}},
		{"name": "Annihilate", "cost": 210, "desc": "+4\u00a0ft range. Lance: 450 dmg / 3.2s",
			"effect": {"range": 40.0, "lance": {"damage": 450.0, "cooldown": 3.2}}},
	]},
	{"name": "Fire", "tiers": [
		{"name": "Kindle", "cost": 40, "desc": "+15% blast dmg. Flame breath 2 dmg / 0.3s, burns 4/s",
			"effect": {"damage": 1.15, "breath": {"damage": 2.0, "interval": 0.3, "burn_dps": 4.0, "burn_time": 2.0}}},
		{"name": "Fan the Flames", "cost": 70, "desc": "+15% blast dmg. Breath 3 dmg / 0.25s, burns 7/s",
			"effect": {"damage": 1.15, "breath": {"damage": 3.0, "interval": 0.25, "burn_dps": 7.0, "burn_time": 2.5}}},
		{"name": "Firestorm", "cost": 120, "desc": "+20% blast dmg. Breath 5 dmg / 0.2s, burns 12/s",
			"effect": {"damage": 1.2, "breath": {"damage": 5.0, "interval": 0.2, "burn_dps": 12.0, "burn_time": 3.0}}},
		{"name": "Dragon's Breath", "cost": 195, "desc": "+30% blast dmg. Breath 8 dmg / 0.15s, burns 22/s",
			"effect": {"damage": 1.3, "breath": {"damage": 8.0, "interval": 0.15, "burn_dps": 22.0, "burn_time": 3.5}}},
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
]

const WARRIORS := {
	"swordsman": {
		"name": "Swordsman", "cost": 50, "color": Color(0.9, 0.72, 0.3),
		"hp": 120.0, "speed": 90.0,
		"damage": 16.0, "range": 8.0, "cooldown": 0.6, "attack": "melee",
		"desc": "Tough and cheap. Charges in and holds enemies in place.",
		"paths": [
			{"name": "Damage", "tiers": [
				{"name": "Sharpened Blade", "cost": 25, "desc": "+30% damage", "effect": {"damage": 1.3}},
				{"name": "Heavy Strikes", "cost": 40, "desc": "+30% damage", "effect": {"damage": 1.3}},
				{"name": "Champion's Edge", "cost": 75, "desc": "+40% damage", "effect": {"damage": 1.4}},
				{"name": "Kingsblade", "cost": 140, "desc": "+60% damage; wide sweeping swings also hit enemies nearby (75%)", "effect": {"damage": 1.6, "cleave": {"arc": 160.0, "reach": 18.0, "damage": 0.75}}},
			]},
			{"name": "Speed", "tiers": [
				{"name": "Quick Hands", "cost": 25, "desc": "Attacks 18% faster, +10% move speed", "effect": {"rate": 0.85, "speed": 1.1}},
				{"name": "Flurry", "cost": 40, "desc": "Attacks 18% faster, +8% move speed", "effect": {"rate": 0.85, "speed": 1.08}},
				{"name": "Blade Dance", "cost": 75, "desc": "Dual blades: every attack is followed by an off-hand strike (60%). Attacks 18% faster, +8% move speed", "effect": {"rate": 0.85, "speed": 1.08, "dual": 0.6}},
				{"name": "Whirlwind", "cost": 140, "desc": "Off-hand strikes hit harder (80%). Attacks 25% faster, +10% move speed", "effect": {"rate": 0.8, "speed": 1.1, "dual": 0.8}},
			]},
			{"name": "Health", "tiers": [
				{"name": "Padded Armor", "cost": 20, "desc": "+35% health, takes 10% less damage", "effect": {"hp": 1.35, "armor": 0.1}},
				{"name": "Chainmail", "cost": 35, "desc": "+35% health, takes 10% less damage", "effect": {"hp": 1.35, "armor": 0.1}},
				{"name": "Plate and Shield", "cost": 65, "desc": "+40% health, 10% less damage, 15% chance to block a hit", "effect": {"hp": 1.4, "armor": 0.1, "block": 0.15}},
				{"name": "Juggernaut", "cost": 110, "desc": "+50% health, 15% less damage, 25% block chance", "effect": {"hp": 1.5, "armor": 0.15, "block": 0.25}},
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
				{"name": "Sovereign Beam", "cost": 380, "desc": "Every 5s, a beam that hits every enemy in a line: 350 dmg",
					"effect": {"blast": {"damage": 42.0, "count": 3, "range": 200.0, "cooldown": 0.9},
						"beam": {"damage": 350.0, "cooldown": 5.0, "width": 30.0}}},
			]},
			{"name": "Combat", "note": "With Ki, extra hits become extra blasts per volley.", "tiers": [
				{"name": "Rapid Strikes", "cost": 80, "desc": "+1 hit per combo", "effect": {"combo": 1}},
				{"name": "Heavy Blows", "cost": 130, "desc": "+1 hit. 15% chance the finisher knocks back",
					"effect": {"combo": 1, "knockback": [0.15, 40.0]}},
				{"name": "Battle Instinct", "cost": 220, "desc": "+1 hit, 20% finisher knockback, +30% dmg",
					"effect": {"combo": 1, "knockback": [0.2, 50.0], "damage": 1.3}},
				{"name": "Thousand Fists", "cost": 360, "desc": "+2 hits, 25% finisher knockback, +40% dmg",
					"effect": {"combo": 2, "knockback": [0.25, 60.0], "damage": 1.4}},
			]},
			{"name": "Techniques", "tiers": [
				{"name": "Afterimage", "cost": 85, "desc": "20% chance to dodge enemy attacks", "effect": {"evade": 0.2}},
				{"name": "Flash Step", "cost": 130, "desc": "Teleports straight to distant targets (every 4s)",
					"effect": {"teleport": {"cooldown": 4.0, "min_dist": 90.0}}},
				{"name": "Radiant Flash", "cost": 220, "desc": "Blinds and stuns nearby enemies for 2s (every 9s)",
					"effect": {"stun": {"radius": 110.0, "duration": 2.0, "cooldown": 9.0}}},
				{"name": "Power Surge", "cost": 360, "desc": "Every 12s: 2.5x dmg, 50% faster for 4s. Dodge 30%",
					"effect": {"evade": 0.3, "surge": {"cooldown": 12.0, "duration": 4.0, "damage": 2.5, "rate": 1.5}}},
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
				{"name": "Second Wind", "cost": 100, "desc": "Revives 40% faster; downed allies in range get up 50% sooner", "effect": {"revive": {"rez_speed": 1.67, "aura": 1.5, "full": false}}},
				{"name": "Lifebinder", "cost": 180, "desc": "Revives 3x faster at full HP; downed allies in range get up 2.5x sooner", "effect": {"revive": {"rez_speed": 3.0, "aura": 2.5, "full": true}}},
			]},
		],
	},
	"bard": {
		"name": "Bard", "cost": 100, "color": Color(0.95, 0.55, 0.85),
		"hp": 60.0, "speed": 115.0,
		"damage": 7.0, "range": 150.0, "cooldown": 1.0, "attack": "note",
		"projectile_speed": 450.0, "song_radius": 110.0,
		"desc": "Troop. Plucks sharp notes; upgrades into songs that empower allies or unsettle enemies, or into nature spells.",
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
			{"name": "Spellsong", "note": "Each tier adds a spell; all learned spells keep being cast.", "tiers": [
				{"name": "Overgrowth", "cost": 45, "desc": "Every 6s: a patch of plants slows enemies 50% for 4s",
					"effect": {"overgrowth": {"radius": 70.0, "slow": 0.5, "duration": 4.0, "cooldown": 6.0}}},
				{"name": "Vine Snare", "cost": 70, "desc": "Every 7s: vines hold enemies in place for 1.5s",
					"effect": {"vines": {"radius": 55.0, "duration": 1.5, "cooldown": 7.0}}},
				{"name": "Tornado", "cost": 120, "desc": "Every 12s: a tornado throws enemies back up the field",
					"effect": {"tornado": {"radius": 60.0, "push": 90.0, "cooldown": 12.0}}},
				{"name": "Confusion", "cost": 210, "desc": "Every 12s: enemies in an area fight each other for 4s",
					"effect": {"confuse": {"radius": 75.0, "duration": 4.0, "cooldown": 12.0}}},
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
		],
	},
	"cannon": {
		"name": "Cannoneer", "cost": 160, "color": Color(1.0, 0.55, 0.2),
		"hp": 200.0, "speed": 0.0, "emplacement": true,
		"damage": 40.0, "range": 190.0, "cooldown": 3.0, "attack": "shell", "splash": 50.0,
		"projectile_speed": 360.0,
		"desc": "Emplacement. Lobs shells that explode on impact. Slow to reload. Never moves.",
		"paths": [
			{"name": "Firepower", "tiers": [
				{"name": "Packed Powder", "cost": 50, "desc": "+30% damage", "effect": {"damage": 1.3}},
				{"name": "Iron Shot", "cost": 80, "desc": "+30% damage", "effect": {"damage": 1.3}},
				{"name": "Heavy Shells", "cost": 135, "desc": "+40% damage", "effect": {"damage": 1.4}},
				{"name": "Siege Mortar", "cost": 230, "desc": "+60% damage", "effect": {"damage": 1.6}},
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
		"desc": "Emplacement. Every few seconds, heals every ally whose post is in its radius, wherever they are.",
		"paths": [
			{"name": "Supplies", "tiers": [
				{"name": "Bandages", "cost": 40, "desc": "Heals 30% more", "effect": {"damage": 1.3}},
				{"name": "Poultices", "cost": 60, "desc": "Heals 30% more", "effect": {"damage": 1.3}},
				{"name": "Apothecary", "cost": 110, "desc": "Heals 40% more", "effect": {"damage": 1.4}},
				{"name": "Elixir Stores", "cost": 190, "desc": "Heals 70% more", "effect": {"damage": 1.7}},
			]},
			{"name": "Wards", "tiers": [
				{"name": "More Cots", "cost": 40, "desc": "+2.5\u00a0ft radius", "effect": {"range": 25.0}},
				{"name": "Second Tent", "cost": 60, "desc": "+2.5\u00a0ft radius", "effect": {"range": 25.0}},
				{"name": "Infirmary", "cost": 100, "desc": "+3\u00a0ft radius, pulses 15% faster", "effect": {"range": 30.0, "rate": 0.85}},
				{"name": "Grand Hospital", "cost": 170, "desc": "+4\u00a0ft radius, pulses 15% faster", "effect": {"range": 40.0, "rate": 0.85}},
			]},
			{"name": "Field Hospital", "tiers": [
				{"name": "Orderlies", "cost": 40, "desc": "Pulses 15% faster", "effect": {"rate": 0.85}},
				{"name": "Tonics", "cost": 60, "desc": "Healed allies regenerate 2% HP/s for 4s", "effect": {"regen": [0.02, 4.0]}},
				{"name": "Stretcher Bearers", "cost": 120, "desc": "Revives downed allies in its radius (6s each)",
					"effect": {"revive": {"rez_speed": 1.0, "aura": 1.5, "full": false}}},
				{"name": "Surgeons", "cost": 200, "desc": "Revives in 2s at full HP",
					"effect": {"revive": {"rez_speed": 3.0, "aura": 2.0, "full": true}}},
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
				{"name": "Winged Victory", "cost": 120, "desc": "Allies attack 18% faster, move 12% faster", "effect": {"aura_rate": 0.18, "aura_speed": 0.12}},
				{"name": "Swift Glory", "cost": 210, "desc": "Allies attack 26% faster, move 20% faster", "effect": {"aura_rate": 0.26, "aura_speed": 0.2}},
			]},
			{"name": "Bulwark", "tiers": [
				{"name": "Stone Skin", "cost": 45, "desc": "Allies take 8% less damage", "effect": {"aura_defense": 0.08}},
				{"name": "Iron Will", "cost": 70, "desc": "Allies take 12% less damage", "effect": {"aura_defense": 0.12}},
				{"name": "Aegis", "cost": 120, "desc": "Allies take 18% less damage, +2.5\u00a0ft radius", "effect": {"aura_defense": 0.18, "range": 25.0}},
				{"name": "Unbreakable", "cost": 210, "desc": "Allies take 24% less damage, +2.5\u00a0ft radius", "effect": {"aura_defense": 0.24, "range": 25.0}},
			]},
		],
	},
	"mine": {
		"name": "Gold Mine", "cost": 150, "color": Color(1.0, 0.85, 0.3),
		"hp": 180.0, "speed": 0.0, "emplacement": true,
		"damage": 6.0, "range": 0.0, "cooldown": 5.0, "attack": "mine", "hauls": 8,
		"desc": "Emplacement. Digs up 6 gold every 5 seconds while a wave is on, up to 8 hauls per wave. Mines share the vein: each one after the first digs 30% less than the one before, and only your best Treasury pays interest.",
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
		],
	},
	"barricade": {
		"name": "Barricade", "cost": 37, "color": Color(0.75, 0.55, 0.32),
		"hp": 200.0, "speed": 0.0, "emplacement": true,
		"damage": 0.0, "range": 0.0, "cooldown": 1.0, "attack": "wall",
		"cost_base": 15, "cost_per_100": 55, "min_length": 40.0,
		"desc": "Emplacement. Click two points to build a wall between them (price grows with length). Enemies go around it if they can, and break through if they can't. It blocks your troops and their shots too; only emplacements and lobbed flasks fire over it. Walls only heal with Engineering, and a broken wall is gone for good.",
		"paths": [
			{"name": "Spikes", "tiers": [
				{"name": "Sharpened Stakes", "cost": 30, "desc": "Attackers take 3% of their max HP per strike", "effect": {"thorns": 0.03}},
				{"name": "Spiked Palisade", "cost": 50, "desc": "Attackers take 5% of their max HP per strike", "effect": {"thorns": 0.05}},
				{"name": "Caltrops", "cost": 85, "desc": "7% thorns. Enemies near the wall are slowed 25%", "effect": {"thorns": 0.07, "wall_slow": [0.25, 50.0]}},
				{"name": "Iron Maiden", "cost": 150, "desc": "10% thorns. Enemies near the wall are slowed 40%", "effect": {"thorns": 0.1, "wall_slow": [0.4, 60.0]}},
			]},
			{"name": "Fortify", "tiers": [
				{"name": "Lashed Logs", "cost": 30, "desc": "+20% health", "effect": {"hp": 1.2}},
				{"name": "Reinforced", "cost": 50, "desc": "+20% health, takes 10% less damage", "effect": {"hp": 1.2, "armor": 0.1}},
				{"name": "Stone Wall", "cost": 85, "desc": "+30% health, takes 20% less damage", "effect": {"hp": 1.3, "armor": 0.2}},
				{"name": "Fortress Wall", "cost": 150, "desc": "+40% health, takes 30% less damage", "effect": {"hp": 1.4, "armor": 0.3}},
			]},
			{"name": "Engineering", "tiers": [
				{"name": "Repair Crew", "cost": 30, "desc": "Repairs 4 HP/s per 16\u00a0ft of wall while a wave is on", "effect": {"repair": 4.0}},
				{"name": "Work Crew", "cost": 50, "desc": "Repairs 8 HP/s per 16\u00a0ft of wall while a wave is on", "effect": {"repair": 8.0}},
				{"name": "Arrow Slits", "cost": 85, "desc": "One archer per 15\u00a0ft of wall: 12 dmg / 1s at enemies within 9\u00a0ft",
					"effect": {"slits": {"damage": 12.0, "cooldown": 1.0, "range": 90.0}}},
				{"name": "Murder Holes", "cost": 150, "desc": "Arrows hit for 30 dmg every 0.7s, reach 13\u00a0ft",
					"effect": {"slits": {"damage": 30.0, "cooldown": 0.7, "range": 130.0}}},
			]},
		],
	},
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
	"sapper": {"tier": 3, "hp": 45, "speed": 42.0, "damage": 0.0, "cooldown": 1.0, "fights": true,
			"bomb": {"wall": 250.0, "units": 40.0, "radius": 60.0},
			"bounty": 9, "radius": 12.0, "scale": 2.4, "color": Color(0.55, 0.6, 0.3)},
	"troll": {"tier": 4, "hp": 200, "speed": 25.0, "damage": 20.0, "cooldown": 1.6, "fights": true, "knock": 0.5,
			"bounty": 20, "radius": 19.0, "scale": 3.5, "color": Color(0.45, 0.55, 0.6)},
	"warlord": {"tier": 5, "hp": 600, "speed": 22.0, "damage": 35.0, "cooldown": 1.5, "fights": true, "cc": 0.5, "knock": 0.3,
			"bounty": 120, "radius": 24.0, "scale": 4.0, "color": Color(0.65, 0.2, 0.2)},
	# Flying elite: over walls and warriors, scorching whatever's below.
	"wyvern": {"tier": 5, "hp": 480, "speed": 30.0, "damage": 0.0, "cooldown": 1.5, "fights": false, "flying": true,
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
