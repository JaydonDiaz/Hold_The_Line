extends RefCounted
## Game-wide tuning (starting gold, difficulties, how waves grow), and the one place the
## rest of the game reads all tuning from. Edit the topic files to rebalance:
##   castle_data.gd    the castle, its upgrades, abilities and repairs
##   troops_data.gd    every troop and emplacement and their upgrade paths
##   enemies_data.gd   every enemy and the squads they march in

const START_GOLD := 250
const PX_PER_FOOT := 10.0    # distances are worked out in pixels but shown to the player in feet


## A distance in pixels as the player sees it: "15 ft", "2.5 ft".
static func ft(px: float) -> String:
	var f := px / PX_PER_FOOT
	return "%d\u00a0ft" % roundi(f) if absf(f - roundf(f)) < 0.05 else "%.1f\u00a0ft" % f   # no line break before "ft"

# Difficulties: castle health and prices (hiring, upgrading, walls) are multiplied by
# "castle" and "cost". With "permadeath" a downed troop dies for good after "down_time"
# seconds unless it's revived first (by a Healer or a Medic Bay); without it (only in
# the Tutorial and Freeplay) it gets back up then.
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
# Endless (past FINAL_WAVE) is a long, slow climb: the aim is to get as far as you can, and a
# well-built army with good tactics should get a long way past it.
const LATE_HP_GROWTH := 1.06      # health multiplier per wave past FINAL_WAVE (instead of HP_GROWTH)
const LATE_DAMAGE_GROWTH := 1.03  # damage multiplier per wave past FINAL_WAVE (instead of DAMAGE_GROWTH)
const LATE_GOLD_STEP := 0.01      # past FINAL_WAVE, bounties and wave bonuses pay this much less per wave...
const LATE_GOLD_MIN := 0.6        # ...down to this share (mines and interest always pay in full)
const LATE_COUNT_STEP := 1        # past FINAL_WAVE, a wave has this many more enemies than the last (2 before it)...
const MAX_WAVE_SIZE := 80         # ...up to this many (beyond it, they only get tougher)


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


# The rest of the tuning lives in its own files, one per topic. They're listed here too,
# so the rest of the game reads them all as Data.<NAME>.
const Castle = preload("res://scripts/data/castle_data.gd")
const Troops = preload("res://scripts/data/troops_data.gd")
const Enemies = preload("res://scripts/data/enemies_data.gd")

const CASTLE_HP = Castle.CASTLE_HP
const CASTLE_POWER_GROWTH = Castle.CASTLE_POWER_GROWTH
const REPAIR_CHUNKS = Castle.REPAIR_CHUNKS
const BUILD_TIME = Castle.BUILD_TIME
const REPAIR_TIME = Castle.REPAIR_TIME
const REPAIR_FULL_COST = Castle.REPAIR_FULL_COST
const CASTLE_PATHS = Castle.CASTLE_PATHS
const ABILITIES = Castle.ABILITIES

const MAGE_PATHS = Troops.MAGE_PATHS
const FROST_PATHS = Troops.FROST_PATHS
const WARRIORS = Troops.WARRIORS
const SKELETON = Troops.SKELETON

const SQUADS = Enemies.SQUADS
const ENEMIES = Enemies.ENEMIES
