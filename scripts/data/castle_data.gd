extends RefCounted
## The castle's tuning: its health, its upgrade paths (the Castle tab), its abilities and repairs.

const CASTLE_HP := 450.0     # the castle falls (and the game is lost) when this runs out

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
