extends RefCounted
## The horde's tuning: every enemy type and the squads they march in.

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
# pack = {radius, per, max, speed, alone}: bolder among its own kind. For each other one of
#        its kind within `radius` (up to `max`) it hits `per` harder and swings `per` / 2
#        faster, and moves `speed` faster; with none of them near, `alone` slower.
# regen = {delay, rate}: (Troll) once it's gone `delay` seconds unhurt, it heals `rate` of
#         its health a second; any hurt stops it, and while it burns it can't start.
# slam = {windup, reach, arc, push, stun}: its blows are hauled back `windup` seconds (the
#        arc they'll sweep shown on the ground) and land on everyone in that arc in front of
#        it, throwing them back `push` and staggering them `stun` seconds.
# strafe = {cooldown, warn, length, speed, width, damage}: (Wyvern) a strafing run: its line
#        shown on the ground `warn` seconds, then it swoops down it breathing fire on every
#        troop under it (once each).
# shield = {front, arc, cover, cover_r}: (Shieldbearer) shots coming at it from in front
#          (within `arc` either side of where it faces) do `front` less; shots at one of its own
#          just behind it (within `cover_r`) do `cover` less. Blows, and shots from the side or
#          behind, land in full. It walks in front of the horde's archers, sappers and casters.
# drum = {radius, every, speed, rate, time, kinds}: (War Drummer) every `every` seconds a
#        beat drives on the `kinds` round it for `time`: `speed` quicker, `rate` quicker blows.
#        Drummers don't add up: driven on is driven on.
# ranged.pierce, ranged.falloff: (Boltflinger) its bolt flies straight on through up to
#        `pierce` troops in its line, each struck once, `falloff` less for each it's been through.
# cast = {range, charge, cooldown, lightning, fire, arcane}: (Horde Mage) a troop within
#        `range`: it stands, charges one of its three spells (picked at random as the charge
#        starts) for `charge` seconds, lets it go, then rests `cooldown`. A stun, freeze or
#        knock while it's charging breaks the spell off.
#        lightning {damage, jumps, chain_r, falloff}: strikes the nearest troop, then leaps on
#          to the next nearest within `chain_r` (never one it's struck), up to `jumps` times,
#          `falloff` weaker each leap.
#        fire {dps, time, range, arc, tick}: a stream of fire at the nearest troop, `arc` either
#          side, `range` long, for `time` seconds, burning in `tick`-second ticks.
#        arcane {damage, cap}: a beam at the troop with the most health left in reach, for
#          `damage`, never more than `cap` of that troop's health.
# necro = (Gravebinder) {reach, keep_back, summon_every, summon_count, summon_max,
#         raise_base, raise_per_gold, raise_max, max_raised, corrupt}: calls up
#         `summon_count` Skeleton Archers every `summon_every` seconds (never more than
#         `summon_max` of them at once); raises one of your fallen troops within `reach`
#         (raise_base + raise_per_gold for every gold spent on it, at most raise_max seconds of
#         channelling; never more than `max_raised` at once), corrupted: `corrupt` = {hp,
#         damage, rate, heal} shares of what it had (rate: its attacks come that much slower).
#         It keeps `keep_back` from your troops ahead of it.
# A corrupted troop (main.raise_fallen) keeps its kind, its upgrades and its look; its
# health, damage, reach and speed are what its upgrades had made them, cut by `corrupt`;
# it fights as its kind does: hand to hand, or shooting (arrows, orbs, frost, flasks, notes;
# volleys and splash kept), a Mage's Storm, Fire or Arcane path as that spell, a Healer
# mending the horde, a Bard's songs driving the horde on.
# SQUADS: the horde's own pairings, marching in together (one after another in a wave):
#   each {name, from, every, kinds}: in Classic from wave `from`, on waves where
#   (wave - from) % every == 0. A mission's "squads" {wave: [squad names]} sends them too.
# tier ranks how dangerous an enemy type is; "Strongest" targeting goes for the highest.
const SQUADS := {
	"Hunting Pack": {"from": 8, "every": 3, "kinds": ["drummer", "wolf", "wolf", "wolf", "goblin"]},
	"Breaching Party": {"from": 9, "every": 3, "kinds": ["shieldbearer", "sapper", "sapper"]},
	"Iron Assault": {"from": 10, "every": 4, "kinds": ["ogre", "goblin", "goblin", "goblin"]},
	"Piercing Volley": {"from": 11, "every": 4, "kinds": ["goblin", "goblin", "boltflinger", "boltflinger"]},
	"Regenerating Wall": {"from": 12, "every": 4, "kinds": ["shieldbearer", "troll", "troll"]},
	"Magical Onslaught": {"from": 15, "every": 5, "kinds": ["warlord", "warmage", "warmage"]},
	"Death From Above": {"from": 14, "every": 6, "kinds": ["bat", "bat", "bat", "bat", "wyvern"]},
	"Grave Procession": {"from": 16, "every": 6, "kinds": ["skeleton_archer", "skeleton_archer", "gravebinder", "skeleton_archer"]},
	"Stolen Army": {"from": 22, "every": 6, "kinds": ["troll", "shieldbearer", "gravebinder", "shieldbearer"]},
}


const ENEMIES := {
	# The horde's numbers: unsure of itself alone, bold with its own round it.
	"goblin": {"tier": 1, "hp": 30, "speed": 45.0, "damage": 4.0, "cooldown": 1.0, "fights": true,
			"pack": {"radius": 70.0, "per": 0.05, "max": 3, "speed": 0.0, "alone": 0.15},
			"bounty": 4, "radius": 11.0, "scale": 2.25, "color": Color(0.45, 0.7, 0.25)},
	"orc": {"tier": 3, "hp": 75, "speed": 35.0, "damage": 8.0, "cooldown": 1.2, "fights": true,
			"bounty": 7, "radius": 14.0, "scale": 2.75, "color": Color(0.35, 0.5, 0.3)},
	# Runs in packs: each wolf alongside makes the others quicker and their bites harder.
	"wolf": {"tier": 2, "hp": 40, "speed": 80.0, "damage": 0.0, "cooldown": 1.0, "fights": false, "wall_damage": 3.0,
			"pack": {"radius": 90.0, "per": 0.08, "max": 3, "speed": 0.03, "alone": 0.0},
			"bounty": 6, "radius": 12.0, "scale": 2.5, "color": Color(0.6, 0.6, 0.65)},
	"bat": {"tier": 2, "hp": 26, "speed": 62.0, "damage": 0.0, "cooldown": 1.0, "fights": false, "flying": true, "wall_damage": 3.0,
			"bounty": 6, "radius": 11.0, "scale": 2.5, "color": Color(0.4, 0.3, 0.45)},
	# The Wallbreaker: slow, huge, its club hauled back and brought down on whoever's in
	# front of it, throwing them back out of the line.
	"ogre": {"tier": 4, "hp": 240, "speed": 23.0, "damage": 24.0, "cooldown": 2.2, "fights": true, "knock": 0.4, "cc": 0.8,
			"wall_damage": 40.0, "slam": {"windup": 0.7, "reach": 26.0, "arc": 2.0, "push": 50.0, "stun": 0.5},
			"bounty": 22, "radius": 20.0, "scale": 3.75, "color": Color(0.6, 0.58, 0.38)},
	# A goblin behind a great shield: shots from in front glance off it, and off whoever's
	# sheltering behind it. Flank it, or hit it hand to hand, or with spells.
	"shieldbearer": {"tier": 3, "hp": 90, "speed": 32.0, "damage": 5.0, "cooldown": 1.3, "fights": true, "knock": 0.5,
			"shield": {"front": 0.75, "arc": 1.1, "cover": 0.4, "cover_r": 46.0},
			"bounty": 10, "radius": 14.0, "scale": 2.6, "color": Color(0.5, 0.55, 0.4)},
	# A goblin with a war drum: its beat drives on the light troops round it. Kill it first.
	"drummer": {"tier": 2, "hp": 40, "speed": 30.0, "damage": 0.0, "cooldown": 1.0, "fights": false, "wall_damage": 2.0,
			"drum": {"radius": 120.0, "every": 3.0, "speed": 0.25, "rate": 0.3, "time": 3.4,
				"kinds": ["goblin", "wolf", "orc", "sapper", "shieldbearer", "boltflinger", "skeleton_archer"]},
			"bounty": 12, "radius": 12.0, "scale": 2.5, "color": Color(0.6, 0.45, 0.3)},
	# A goblin with a great crossbow: slow to wind, but its bolt goes through a line of troops.
	"boltflinger": {"tier": 3, "hp": 45, "speed": 32.0, "damage": 22.0, "wall_damage": 10.0, "cooldown": 3.6, "fights": true,
			"ranged": {"range": 200.0, "speed": 520.0, "pierce": 4, "falloff": 0.2},
			"bounty": 11, "radius": 12.0, "scale": 2.5, "color": Color(0.5, 0.45, 0.3)},
	# A goblin shaman of the horde: charges a spell (its colour at the staff says which), then
	# chain lightning, a stream of fire or an arcane beam. Spread out, or kill it first.
	"warmage": {"tier": 4, "hp": 70, "speed": 30.0, "damage": 4.0, "wall_damage": 6.0, "cooldown": 1.2, "fights": true,
			"cast": {"range": 210.0, "charge": 1.6, "cooldown": 4.5,
				"lightning": {"damage": 16.0, "jumps": 4, "chain_r": 70.0, "falloff": 0.15},
				"fire": {"dps": 24.0, "time": 1.8, "range": 125.0, "arc": 0.5, "tick": 0.25},
				"arcane": {"damage": 60.0, "cap": 0.45}},
			"bounty": 18, "radius": 12.0, "scale": 2.6, "color": Color(0.45, 0.25, 0.55)},
	# The Master of the Fallen: a necromancer of the horde, Warlord-tier. Calls up Skeleton
	# Archers, and raises your fallen troops against you, upgrades and all. Kill it first.
	"gravebinder": {"tier": 5, "hp": 560, "speed": 22.0, "damage": 12.0, "wall_damage": 20.0, "cooldown": 1.4, "fights": true,
			"cc": 0.5, "knock": 0.5,
			"necro": {"reach": 240.0, "keep_back": 170.0, "summon_every": 12.0, "summon_count": 2, "summon_max": 4,
				"raise_base": 2.5, "raise_per_gold": 0.012, "raise_max": 10.0, "max_raised": 2,
				"corrupt": {"hp": 0.6, "damage": 0.6, "rate": 0.75, "heal": 0.5}},
			"bounty": 120, "radius": 18.0, "scale": 3.4, "color": Color(0.3, 0.3, 0.35)},
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
	# Heals its wounds if it's left alone for a moment: keep hitting it (fire stops it).
	"troll": {"tier": 4, "hp": 200, "speed": 25.0, "damage": 20.0, "cooldown": 1.6, "fights": true, "knock": 0.5,
			"regen": {"delay": 3.0, "rate": 0.05},
			"bounty": 20, "radius": 19.0, "scale": 3.5, "color": Color(0.45, 0.55, 0.6)},
	# Its great blade swept round in front of it: deadly to troops packed in close.
	"warlord": {"tier": 5, "hp": 600, "speed": 22.0, "damage": 35.0, "cooldown": 1.5, "fights": true, "cc": 0.5, "knock": 0.3,
			"slam": {"windup": 0.55, "reach": 30.0, "arc": 2.4, "push": 30.0, "stun": 0.3},
			"bounty": 120, "radius": 24.0, "scale": 4.0, "color": Color(0.65, 0.2, 0.2)},
	# Flying elite: over walls and warriors, scorching whatever's below.
	"wyvern": {"tier": 5, "hp": 420, "speed": 30.0, "damage": 0.0, "cooldown": 1.5, "fights": false, "flying": true,
			"wall_damage": 30.0, "cc": 0.5, "knock": 0.3,
			"breath": {"damage": 16.0, "radius": 34.0, "range": 120.0, "cooldown": 2.2},
			"strafe": {"cooldown": 10.0, "warn": 1.1, "length": 240.0, "speed": 220.0, "width": 26.0, "damage": 30.0},
			"bounty": 100, "radius": 20.0, "scale": 3.75, "color": Color(0.3, 0.55, 0.45)},
	# The Ash Marshal, the Ogre King's herald (Sable Crossing): a war banner that drives on the
	# enemies round him (until enough damage knocks it down for a while), a charge at a
	# troop in his way (never through rock, water or a wall), and a sweeping cleave.
	"ash_marshal": {"tier": 6, "name": "The Ash Marshal", "hp": 1300, "speed": 20.0, "damage": 40.0, "cooldown": 1.5, "fights": true,
			"cc": 0.3, "knock": 0.0, "wall_damage": 80.0, "boss": true,
			"cleave": {"reach": 30.0, "arc": 1.8},
			"banner": {"radius": 150.0, "damage": 0.25, "speed": 0.2, "break": 0.08, "down": 12.0},
			"charge": {"cooldown": 10.0, "min": 60.0, "range": 210.0, "speed": 230.0, "damage": 40.0, "push": 60.0, "stun": 1.0},
			"enrage": 0.35,
			"bounty": 400, "radius": 26.0, "scale": 5.0, "color": Color(0.6, 0.25, 0.15)},
	# Final boss: comes for the line once wave 20 (and every 10th wave after) is beaten.
	"ogre_king": {"tier": 6, "name": "The Ogre King", "hp": 10000, "speed": 15.0, "damage": 60.0, "cooldown": 1.8, "fights": true, "cc": 0.3, "knock": 0.0,
			"wall_damage": 120.0, "boss": true,
			"stomp": {"damage": 50.0, "radius": 100.0, "cooldown": 6.0, "push": 70.0, "stun": 1.5},
			"cleave": {"reach": 34.0, "arc": 2.1},
			"summon": {"kinds": ["orc", "bat", "sapper"], "count": 3, "cooldown": 12.0},
			"horn": {"kinds": ["goblin", "orc", "orc", "wolf", "bat", "troll", "sapper"], "count": 8, "cooldown": 30.0},
			"enrage": 0.5,
			"bounty": 500, "radius": 30.0, "scale": 5.5, "color": Color(0.5, 0.6, 0.35)},
	# The Ogre King unbound (the nine-beacon finale): his true power, drawn from the corrupted
	# Dawnspire beacon and the curse of the Line's broken oath. The same slams and blows,
	# and three new moves, each shown before it lands: a charge down a line marked on the
	# ground, after which he's off balance and exposed (rooted, hit far harder) for a few
	# seconds; burning ground under the troops nearest him; and his reinforcements.
	"ogre_unbound": {"tier": 6, "name": "The Ogre King, Unbound", "look": "ogre_king", "aura": Color(1.0, 0.25, 0.1, 1.0),
			"hp": 12000, "speed": 17.0, "damage": 70.0, "cooldown": 1.7, "fights": true, "cc": 0.25, "knock": 0.0,
			"wall_damage": 140.0, "boss": true,
			"stomp": {"damage": 60.0, "radius": 110.0, "cooldown": 7.0, "push": 80.0, "stun": 1.5},
			"cleave": {"reach": 36.0, "arc": 2.2},
			"charge": {"cooldown": 11.0, "min": 70.0, "range": 260.0, "speed": 260.0, "damage": 55.0, "push": 80.0, "stun": 1.2,
				"warn": 1.0, "exposed": 3.5, "exposed_vuln": 0.75},
			"embers": {"cooldown": 9.0, "count": 3, "radius": 46.0, "dps": 22.0, "duration": 6.0, "warn": 1.3},
			"summon": {"kinds": ["orc", "skeleton_archer", "sapper"], "count": 3, "cooldown": 14.0},
			"horn": {"kinds": ["orc", "orc", "troll", "wolf", "skeleton_archer", "warlord", "slime", "wyvern"], "count": 8, "cooldown": 32.0},
			"enrage": 0.4,
			"bounty": 1000, "radius": 32.0, "scale": 6.0, "color": Color(0.6, 0.35, 0.25)},
}
