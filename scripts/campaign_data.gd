extends RefCounted
## The story campaign's content, as plain data (campaign.gd works out the state from it):
##   FACTIONS     the eight peoples who can join the Line, and what each one unlocks
##   TERRITORIES  places on the continent map: where they are, what opens them, their missions
##   ROUTES       the roads drawn between territories
##   MISSIONS     one battle each: waves, enemies, starting gold, help on the field, reward
##   SPEAKERS / STORY   who talks, and what they say before and after missions
##
## Unlock keys, used everywhere a thing can be locked (see Campaign.allows):
##   a Data.WARRIORS kind ("archer", "tower", "barricade", ...)
##   "ability:<Data.ABILITIES key>"   ("ability:arrows")
##   "path:<index into Data.CASTLE_PATHS>"   ("path:0" is Fortify)
##   "repair"   the Repair tab (the Engineers mending the castle)

const START_UNLOCKS := ["swordsman"]   # what Ashwatch's garrison has from the start
const BUILDERS := "stonehollow"        # emplacements (not barricades) need the Engineers too...
const LEND_BUILDERS := "engineers"     # ...or a mission that lends them (see MISSIONS "lend")
const ENDING_ALLIES := 8               # every regional alliance: the fully united ending

# Troop training: in the campaign, a unit kind can only take upgrade tiers it has been
# trained for. Tier I is always open; II, III and IV are opened one path at a time with
# training points at the Training Grounds on the map. Every kind trains on its own
# (towers apart from their crews). Tier IV also needs the beacon of the kind's home
# region lit (see TERRITORIES; the Swordsman's home is Ashwatch).
# Unit experience: in a campaign battle every kind of unit (emplacements too) earns XP by
# being used. Each level it reaches gives that kind a training point; a point opens the
# next tier (II, III, IV) of one of its four upgrade paths, so 12 points train it fully.
#   damage    XP per point of damage dealt (summons and copies count for their maker)
#   heal      per HP healed;  revive  per ally brought back
#   gold      per gold a Gold Mine digs;  soak  per point of damage a Barricade takes
#   aura      per second a War Statue spends boosting an ally during a wave
const XP_RATES := {"damage": 1.0, "heal": 1.5, "revive": 150.0, "gold": 12.0, "soak": 0.6, "aura": 4.0}
const XP_FIRST := 2000.0        # XP to a kind's first level (a Swordsmen-only Ashwatch earns about 6000: 2 points)
const XP_GROWTH := 1.2          # each level after that needs this much more than the one before (79k XP in all)
const XP_LOSS_SHARE := 0.5      # a battle lost (or left) counts for this share of its XP
const MAX_TRAINING := 12        # points that train a kind fully: tiers II-IV on all four paths

const FACTIONS := {
	"stonehollow": {"name": "The Engineers' Guild", "home": "Stonehollow", "color": Color(0.85, 0.62, 0.32),
		"unlocks": ["barricade", "repair", "path:0"],
		"gives": "Engineers: emplacements, barricades, repairs and Fortify",
		"leader": "vell", "folk": ["engineer", "engineer", "engineer"],
		"people": "Stonehollow's masons and engineers carve their town out of the mountain. Stubborn, proud and practical, they built the beacon towers of the old Line, and they still keep the plans."},
	"greenwood": {"name": "The Woodland Watch", "home": "Greenwood", "color": Color(0.45, 0.85, 0.4),
		"unlocks": ["archer", "tower", "path:1", "ability:arrows"],
		"gives": "Archers, Archer Towers, Wall Archers and Arrow Storm",
		"leader": "thorne", "folk": ["archer", "archer", "archer"],
		"people": "The elves of the Woodland Watch, green-haired archers all, guard a forest older than any kingdom. Patient and wary, they trust no road they did not cut themselves, and no promise they have not seen kept."},
	"deepdelve": {"name": "The Mining Guild", "home": "Deepdelve", "color": Color(1.0, 0.8, 0.3),
		"unlocks": ["mine", "cannon"],
		"gives": "Gold Mines and Cannoneers",
		"leader": "dagna", "folk": ["miner", "miner"],   # and a gun crew test-firing a cannon (cutscene.gd)
		"people": "Under the eastern peaks, the miners of Deepdelve dig gold and iron and cast cannon in roaring forges. Loud, generous and quick to bargain, their gold once paid for half the Line."},
	"mercyvale": {"name": "The Sanctuary", "home": "Mercy Vale", "color": Color(0.95, 0.95, 0.7),
		"unlocks": ["healer", "medbay", "ability:heal"],
		"gives": "Healers, Medic Bays and Healing Light",
		"leader": "ilse", "folk": ["healer", "healer", "healer"],
		"people": "In the valley of shrines, the healers of the Sanctuary tend anyone wounded who reaches their gates, friend or foe. Gentle but unbending, they have sworn never to turn anyone away."},
	"frostmarch": {"name": "The Northern Covenant", "home": "Frostmarch", "color": Color(0.6, 0.88, 1.0),
		"unlocks": ["frost", "frosttower", "ability:frost"],
		"gives": "Frost Witches, Frost Towers and Frost Orb",
		"leader": "ysra", "folk": ["frost", "frost", "frost"],
		"people": "In the frozen passes of the north, the frost witches of the Covenant keep old pacts with winter itself. Solemn and self-reliant, they remember every promise the south ever broke."},
	"freecities": {"name": "The Free Cities", "home": "The Free Cities", "color": Color(1.0, 0.6, 0.85),
		"unlocks": ["bard", "alchemist", "statue", "ability:horn"],
		"gives": "Bards, Alchemists, War Statues and Rally Horn",
		"leader": "coralie", "folk": ["bard", "alchemist", "bard"],
		"people": "The Free Cities glitter with music, markets and alchemy. Clever, worldly and always practical, their councils have stayed out of every war, and some say they profited from all of them."},
	"monastery": {"name": "The Martial Order", "home": "The High Monastery", "color": Color(1.0, 0.5, 0.35),
		"unlocks": ["martial"],
		"gives": "Martial Artists",
		"leader": "kaito", "folk": ["martial", "martial", "martial"],
		"people": "High on the mountain, the fighters of the Martial Order train body and spirit in silence. Disciplined and humble, they swore long ago to serve no king's ambition."},
	"spires": {"name": "The Mage Conclave", "home": "The Arcane Spires", "color": Color(0.75, 0.55, 1.0),
		"unlocks": ["mage", "magetower", "path:2", "path:3", "ability:fireball", "ability:lightning"],
		"gives": "Mages, Mage Towers, Wall Mages, Ability Power, Fireball and Thunderstrike",
		"leader": "ysolde", "folk": ["mage", "mage", "mage"],
		"people": "In towers of crystal and starglass, the mages of the Conclave study the deepest arts. Brilliant and secretive, they alone remember how the beacons were truly lit."},
}

# A territory is a short regional campaign:
#   missions   its required missions, played in order. The one whose "reward" is the
#              territory's people brings them into the Line (usually the first); winning
#              the last lights the territory's beacon: it's secured.
#   optional   missions that open once its people have joined (or, with no people, once
#              its first mission is won); they never count toward the beacon. Their reward
#              is training points for a unit of the region on the first win (a mission's
#              "bonus_points": {kind: n}, 1 or 2): help for a player who's struggling,
#              never needed, and given once, so there's nothing to farm.
#   requires   what opens it: {"joined": [territories]} (their people joined, or their
#              first mission won), {"all": [territories]} (their beacons lit) and/or
#              {"any": [territories], "count": n} (n of those beacons lit).
#   known      shown on the map from the start (as the goal), even before it's reachable.
# A mission may have "requires" of its own (same keys) before it can be played.
# Territories with no missions yet are reachable but have nothing to play (later phases).
const TERRITORIES := {
	"ashwatch": {"name": "Ashwatch Keep", "pos": Vector2(250, 640), "faction": "", "act": 1,
		"requires": {}, "missions": ["ashwatch", "ashwatch_road"],
		"blurb": "Your frontier keep, at the southern edge of the continent. Half its garrison rode south a week ago and never came back."},
	"stonehollow": {"name": "Stonehollow", "pos": Vector2(430, 566), "faction": "stonehollow", "act": 1,
		"requires": {"joined": ["ashwatch"]}, "missions": ["stonehollow", "stonehollow_workshops"],
		"blurb": "A guild town cut into the mountain. Its masons raised the old beacon towers, and they still keep the plans."},
	"greenwood": {"name": "Greenwood", "pos": Vector2(118, 452), "faction": "greenwood", "act": 2,
		"requires": {"joined": ["stonehollow"]}, "missions": [],
		"blurb": "Deep forest held by the Woodland Watch, elven archers who trust no road they didn't cut themselves."},
	"mercyvale": {"name": "Mercy Vale", "pos": Vector2(300, 468), "faction": "mercyvale", "act": 2,
		"requires": {"joined": ["stonehollow"]}, "missions": [],
		"blurb": "A valley of hospices and shrines. The Sanctuary takes in anyone wounded, from any side."},
	"deepdelve": {"name": "Deepdelve", "pos": Vector2(506, 452), "faction": "deepdelve", "act": 2,
		"requires": {"joined": ["stonehollow"]}, "missions": [],
		"blurb": "Mine shafts and smelters under the eastern peaks. The Mining Guild's gold paid for half the old Line."},
	"sable": {"name": "Sable Crossing", "pos": Vector2(300, 352), "faction": "", "act": 2,
		"requires": {"all": ["ashwatch", "stonehollow"], "any": ["greenwood", "mercyvale", "deepdelve"], "count": 2}, "missions": [],
		"blurb": "The only bridge over the Sable river. Whoever holds it decides whether the south and north ever meet."},
	"frostmarch": {"name": "Frostmarch", "pos": Vector2(112, 214), "faction": "frostmarch", "act": 3,
		"requires": {"all": ["sable"]}, "missions": [],
		"blurb": "Snowbound passes where the Northern Covenant's frost witches have kept to themselves for generations."},
	"monastery": {"name": "The High Monastery", "pos": Vector2(300, 236), "faction": "monastery", "act": 3,
		"requires": {"all": ["sable"]}, "missions": [],
		"blurb": "A mountain monastery whose fighters have sworn to serve no king's ambitions."},
	"freecities": {"name": "The Free Cities", "pos": Vector2(510, 268), "faction": "freecities", "act": 3,
		"requires": {"all": ["sable"]}, "missions": [],
		"blurb": "Rich merchant cities that have stayed out of the war, and some say profited from it."},
	"spires": {"name": "The Arcane Spires", "pos": Vector2(472, 136), "faction": "spires", "act": 4,
		"requires": {"any": ["frostmarch", "monastery", "freecities"], "count": 2}, "missions": [],
		"blurb": "The towers of the Mage Conclave, keepers of the beacon network's oldest secrets."},
	"dawnspire": {"name": "Dawnspire Citadel", "pos": Vector2(250, 76), "faction": "", "act": 4, "known": true,
		"requires": {"all": ["spires"]}, "missions": [],
		"blurb": "The ancient heart of the Line. Its central beacon has been dark for two hundred years."},
}

const ROUTES := [["ashwatch", "stonehollow"], ["stonehollow", "greenwood"], ["stonehollow", "mercyvale"],
	["stonehollow", "deepdelve"], ["greenwood", "sable"], ["mercyvale", "sable"], ["deepdelve", "sable"],
	["sable", "frostmarch"], ["sable", "monastery"], ["sable", "freecities"], ["frostmarch", "spires"],
	["monastery", "spires"], ["freecities", "spires"], ["spires", "dawnspire"]]

# A mission:
#   waves        how many waves to survive; clearing the last one wins
#   level        enemy strength on wave 1 (as in Classic's wave numbers); +1 each wave
#   gold         starting gold
#   count        enemies per wave: [base, extra per wave]
#   pool         wave -> enemy kinds that join the mix from that wave on
#   extra        wave -> enemies added to that wave on top of the mix
#   notes        wave -> a message shown when it starts
#   allies       units on the field from the start, free: {"kind", "at", "built"}
#   lend         unlock keys usable in this mission only (the locals' help)
#   reward       the faction that joins the Line on victory ("" = none)
#   track        story flag -> kind: set if one of the starting allies of that kind is still standing at the end
#   mood         the field's light (an ambience.gd mood)
#   map          the battlefield it's fought on (maps.gd)
#   intro / outro   STORY keys: before the first wave, and on the map after a win
#   type         the battle's rules (scripts/mission/rules.gd): "castle" (the default),
#                "pass" (Hold the Pass: no castle, at most "limit" enemies may get through),
#                "positions" (Multiple Positions: "objectives" to keep standing)
#   requires     what has to happen in the campaign before it can be played (see TERRITORIES)
const MISSIONS := {
	"ashwatch": {"name": "The Ridge Fires", "territory": "ashwatch", "waves": 4, "level": 3, "gold": 240,
		"count": [10, 4], "mood": "normal", "map": "ashwatch_ridge",
		"pool": {1: ["goblin", "goblin"], 2: ["wolf"], 3: ["orc"]},
		"extra": {3: ["orc", "orc", "skeleton_archer"], 4: ["orc", "orc", "orc", "wolf", "wolf", "troll", "troll", "skeleton_archer", "skeleton_archer"]},
		"notes": {2: "Wolves! They run straight for the walls.", 4: "Their vanguard is coming in force!"},
		"allies": [{"kind": "tower", "at": Vector2(320, 560), "built": true},
			{"kind": "swordsman", "at": Vector2(250, 470)}, {"kind": "swordsman", "at": Vector2(390, 470)}],
		"lend": [], "reward": "", "track": {"watchtower_stood": "tower"},
		"intro": "ashwatch_intro", "outro": "ashwatch_outro"},
	"stonehollow": {"name": "The Quarry Road", "territory": "stonehollow", "waves": 5, "level": 4, "gold": 340,
		"count": [6, 2], "mood": "normal", "map": "stonehollow_quarry",
		"pool": {1: ["goblin", "orc"], 2: ["wolf"], 3: ["sapper"], 4: ["orc"]},
		"extra": {2: ["skeleton_archer"], 3: ["troll", "skeleton_archer"], 4: ["skeleton_archer", "skeleton_archer", "troll"],
			5: ["troll", "skeleton_archer", "skeleton_archer", "orc"]},
		"notes": {3: "Sappers! They'll blow holes in any wall in their way.", 5: "Trolls at the quarry gate!"},
		"allies": [{"kind": "swordsman", "at": Vector2(220, 520)}, {"kind": "swordsman", "at": Vector2(420, 520)}],
		"lend": ["barricade", "repair", "engineers"], "reward": "stonehollow", "track": {},
		"intro": "stonehollow_intro", "outro": "stonehollow_outro"},
	"stonehollow_workshops": {"name": "Protect the Workshops", "territory": "stonehollow", "type": "positions",
		"objectives": [{"id": "west", "kind": "workshop", "name": "West Workshop", "at": Vector2(186, 664), "hp": 700},
			{"id": "forge", "kind": "workshop", "name": "Forge", "at": Vector2(320, 612), "hp": 700},
			{"id": "east", "kind": "workshop", "name": "East Workshop", "at": Vector2(454, 664), "hp": 700}],
		"can_lose": 1, "castle_share": 0.1,
		"waves": 5, "level": 4, "gold": 360, "count": [5, 2], "mood": "normal", "map": "stonehollow_quarry",
		"pool": {1: ["goblin", "orc"], 2: ["wolf"], 3: ["sapper"], 4: ["orc"]},
		"extra": {2: ["skeleton_archer"], 3: ["troll"], 4: ["skeleton_archer", "skeleton_archer"],
			5: ["troll", "orc", "orc"]},
		"notes": {1: "Keep the workshops standing: lose two and the guild's work is lost.", 3: "Sappers! Wall off the workshops.",
			5: "A Troll is coming for the workshops!"},
		"allies": [{"kind": "swordsman", "at": Vector2(240, 470)}, {"kind": "swordsman", "at": Vector2(400, 470)}],
		"lend": [], "reward": "", "track": {},
		"intro": "stonehollow_workshops_intro", "outro": "stonehollow_workshops_outro"},
	"ashwatch_road": {"name": "The Ridge Road", "territory": "ashwatch", "type": "pass", "limit": 10,
		"waves": 5, "level": 5, "gold": 340, "count": [7, 2], "mood": "normal", "map": "ashwatch_ridge",
		"requires": {"joined": ["stonehollow"]},
		"pool": {1: ["goblin", "goblin", "orc"], 2: ["wolf"], 3: ["sapper"], 4: ["orc"]},
		"extra": {2: ["skeleton_archer"], 3: ["troll", "skeleton_archer"], 4: ["wolf", "skeleton_archer"],
			5: ["troll", "orc", "orc", "skeleton_archer"]},
		"notes": {1: "Hold the ridge road: no more than 10 may get past your lines.", 2: "Wolves run for any gap. Wall it.",
			5: "Their column is on the road. A Troll counts double if it gets through!"},
		"allies": [{"kind": "tower", "at": Vector2(320, 560), "built": true},
			{"kind": "swordsman", "at": Vector2(250, 470)}, {"kind": "swordsman", "at": Vector2(390, 470)}],
		"lend": [], "reward": "", "track": {},
		"intro": "ashwatch_road_intro", "outro": "ashwatch_road_outro"},
}

# Named characters. "look" draws their portrait (portraits.gd): each wears the dress of
# their homeland, in its colours, against its sky.
const SPEAKERS := {
	"hale": {"name": "Captain Maren Hale", "role": "Ashwatch Keep", "color": Color(0.95, 0.85, 0.45),
		"look": {"skin": Color(0.96, 0.78, 0.62), "hair": "braid", "hair_color": Color(0.62, 0.26, 0.12),
			"outfit": "tabard", "colors": [Color(0.24, 0.36, 0.72), Color(0.72, 0.74, 0.8), Color(0.95, 0.8, 0.3)],
			"extras": ["scar"], "bg": [Color(0.45, 0.55, 0.75), Color(0.2, 0.24, 0.36)]}},
	"vell": {"name": "Guildmaster Brannoc Vell", "role": "The Engineers' Guild, Stonehollow", "color": Color(0.85, 0.62, 0.32),
		"look": {"skin": Color(0.86, 0.62, 0.45), "hair": "bald", "hair_color": Color(0.62, 0.6, 0.6), "beard": "full", "beard_color": Color(0.72, 0.72, 0.74),
			"head": "goggles", "outfit": "apron", "colors": [Color(0.52, 0.34, 0.2), Color(0.7, 0.47, 0.26), Color(0.88, 0.68, 0.28)],
			"bg": [Color(0.6, 0.56, 0.52), Color(0.3, 0.27, 0.25)]}},
	"thorne": {"name": "Warden Sylla Thorne", "role": "The Woodland Watch, Greenwood", "color": Color(0.45, 0.85, 0.4),
		"look": {"skin": Color(0.92, 0.76, 0.6), "hair": "braid", "hair_color": Color(0.35, 0.65, 0.3), "eyes": Color(0.2, 0.42, 0.18),
			"head": "circlet", "outfit": "leaf_cloak", "colors": [Color(0.5, 0.36, 0.2), Color(0.38, 0.26, 0.14), Color(0.85, 0.2, 0.2)],
			"extras": ["elf"], "bg": [Color(0.4, 0.62, 0.36), Color(0.12, 0.25, 0.14)]}},
	"dagna": {"name": "Forewoman Dagna Coalbright", "role": "The Mining Guild, Deepdelve", "color": Color(1.0, 0.8, 0.3),
		"look": {"skin": Color(0.95, 0.74, 0.58), "hair": "long", "hair_color": Color(0.8, 0.32, 0.12),
			"head": "miner", "outfit": "overalls", "colors": [Color(0.42, 0.46, 0.55), Color(0.42, 0.28, 0.16), Color(0.95, 0.72, 0.2)],
			"extras": ["soot"], "bg": [Color(0.45, 0.33, 0.25), Color(0.14, 0.1, 0.08)]}},
	"ilse": {"name": "Mother Ilse Varrow", "role": "The Sanctuary, Mercy Vale", "color": Color(0.95, 0.95, 0.7),
		"look": {"skin": Color(0.9, 0.72, 0.6), "hair": "short", "hair_color": Color(0.7, 0.68, 0.66),
			"head": "veil", "outfit": "robe", "colors": [Color(0.94, 0.93, 0.88), Color(0.85, 0.83, 0.78), Color(0.92, 0.75, 0.3)],
			"extras": ["wrinkles"], "bg": [Color(0.98, 0.9, 0.7), Color(0.62, 0.55, 0.42)]}},
	"ysra": {"name": "Matriarch Ysra Frostvein", "role": "The Northern Covenant, Frostmarch", "color": Color(0.6, 0.88, 1.0),
		"look": {"skin": Color(0.84, 0.78, 0.8), "hair": "long", "hair_color": Color(0.6, 0.7, 0.88), "eyes": Color(0.2, 0.45, 0.8),
			"head": "fur", "outfit": "fur_mantle", "colors": [Color(0.3, 0.45, 0.68), Color(0.93, 0.92, 0.88), Color(0.75, 0.85, 0.95)],
			"extras": ["tattoo"], "bg": [Color(0.55, 0.7, 0.88), Color(0.16, 0.22, 0.38)]}},
	"coralie": {"name": "Magistra Coralie Fenn", "role": "The Free Cities", "color": Color(1.0, 0.6, 0.85),
		"look": {"skin": Color(0.72, 0.48, 0.34), "hair": "long", "hair_color": Color(0.14, 0.1, 0.12),
			"head": "feather_hat", "outfit": "doublet", "colors": [Color(0.55, 0.22, 0.55), Color(0.95, 0.5, 0.75), Color(0.97, 0.95, 0.9)],
			"extras": ["earring"], "bg": [Color(0.85, 0.55, 0.45), Color(0.35, 0.16, 0.3)]}},
	"kaito": {"name": "Abbot Kaito Ren", "role": "The Martial Order, the High Monastery", "color": Color(1.0, 0.5, 0.35),
		"look": {"skin": Color(0.9, 0.7, 0.5), "hair": "bald", "hair_color": Color(0.2, 0.15, 0.12),
			"outfit": "monk", "colors": [Color(0.92, 0.5, 0.15), Color(0.7, 0.33, 0.1), Color(0.45, 0.28, 0.15)],
			"extras": ["beads", "calm"], "bg": [Color(0.98, 0.78, 0.55), Color(0.5, 0.3, 0.3)]}},
	"ysolde": {"name": "Archmagus Ysolde Vane", "role": "The Mage Conclave, the Arcane Spires", "color": Color(0.75, 0.55, 1.0),
		"look": {"skin": Color(0.95, 0.82, 0.76), "hair": "long", "hair_color": Color(0.82, 0.78, 0.92), "eyes": Color(0.75, 0.5, 1.0),
			"head": "wizard", "outfit": "star_robe", "colors": [Color(0.4, 0.25, 0.65), Color(0.28, 0.16, 0.48), Color(1.0, 0.9, 0.4)],
			"extras": ["glow"], "bg": [Color(0.35, 0.28, 0.6), Color(0.08, 0.06, 0.18)]}},
	"ogre": {"name": "The Ogre King", "role": "", "color": Color(1.0, 0.4, 0.3),
		"look": {"skin": Color(0.5, 0.62, 0.36), "hair": "bald", "hair_color": Color(0.22, 0.2, 0.12), "eyes": Color(1.0, 0.8, 0.2), "wide": true,
			"head": "crown", "outfit": "ogre", "colors": [Color(0.45, 0.3, 0.18), Color(0.35, 0.22, 0.12), Color(0.92, 0.75, 0.25)],
			"extras": ["tusks", "glow"], "bg": [Color(0.7, 0.2, 0.12), Color(0.18, 0.05, 0.05)]}},
	"marshal": {"name": "The Ash Marshal", "role": "Herald of the Ogre King", "color": Color(1.0, 0.55, 0.3),
		"look": {"skin": Color(0.4, 0.34, 0.33), "hair": "bald", "hair_color": Color(0.1, 0.1, 0.1),
			"head": "horned", "outfit": "armor", "colors": [Color(0.24, 0.22, 0.24), Color(0.5, 0.18, 0.1), Color(1.0, 0.5, 0.15)],
			"bg": [Color(0.45, 0.3, 0.25), Color(0.1, 0.07, 0.07)]}},
}

# The prologue that opens a new campaign (cutscene.gd draws each scene). Nation scenes
# take their text and leader from FACTIONS ("people", "leader", "folk").
const PROLOGUE := [
	{"scene": "beacons", "text": "Long ago, the peoples of this land swore an oath: when one was threatened, all would come. Beacon towers carried the call from hill to hill. They called it the Line."},
	{"scene": "dark", "text": "But oaths grow old. Rivals quarrelled, kingdoms looked away while their neighbours burned, and one by one the beacons went dark."},
	{"scene": "nation", "faction": "stonehollow"},
	{"scene": "nation", "faction": "greenwood"},
	{"scene": "nation", "faction": "deepdelve"},
	{"scene": "nation", "faction": "mercyvale"},
	{"scene": "nation", "faction": "frostmarch"},
	{"scene": "nation", "faction": "freecities"},
	{"scene": "nation", "faction": "monastery"},
	{"scene": "nation", "faction": "spires"},
	{"scene": "horde", "who": "ogre", "text": "Now the Ogre King marches out of the wastes, and his herald, the Ash Marshal, burns the road ahead. He knows the old truth: alone, every people falls."},
	{"scene": "ashwatch", "who": "hale", "text": "On the southern frontier stands Ashwatch Keep. Its garrison is small, and its commander is you. Tonight, there are torches on the ridge."},
	{"scene": "title", "text": "No one holds the line alone."},
]

# Each line: {"who": SPEAKERS key, "text": ...}, optionally "if": a condition that must
# hold for the line to be shown: {"flag": name}, {"no_flag": name}, {"ally": faction},
# {"no_ally": faction} or {"difficulty": key}.
const STORY := {
	"ashwatch_intro": [
		{"who": "hale", "text": "Commander! Torches on the ridge. Goblins, and a lot more behind them."},
		{"who": "hale", "text": "Half the garrison rode south a week ago. What's left is you, me, two swordsmen and old Tamsin up in the watchtower."},
		{"who": "hale", "text": "We can hire more swords with what's in the strongbox. Post them on the trail and keep everything out of the keep."},
	],
	"ashwatch_outro": [
		{"who": "hale", "text": "They're pulling back. But those weren't raiders, Commander. That was a vanguard."},
		{"who": "hale", "text": "Tamsin's tower held the whole time. Stubborn as the stone it's built from.", "if": {"flag": "watchtower_stood"}},
		{"who": "hale", "text": "We lost the watchtower. Tamsin got out, but she says the old stones went down hard.", "if": {"no_flag": "watchtower_stood"}},
		{"who": "hale", "text": "Look at this. It was in the cellar behind the barrels: a map of beacons, from when the peoples of this land still answered each other."},
		{"who": "hale", "text": "They called it the Line. Every keep and every hold, sworn to come when a beacon was lit. Ours hasn't burned in two hundred years."},
		{"who": "ogre", "text": "One little fire on the frontier? Let it flicker. They will fall one by one, as they always have."},
		{"who": "hale", "text": "We can't stop an army alone. Stonehollow's guild built these beacons. If anyone remembers the oath, it's them."},
	],
	"ashwatch_road_intro": [
		{"who": "hale", "text": "Commander, the King's column has turned for the high road. Past the ridge it runs to every village in the south."},
		{"who": "vell", "text": "Then it goes no further. No castle out there, but my crews will pitch a camp on the road and wall whatever you point at."},
		{"who": "hale", "text": "Tamsin's tower covers the road. A few stragglers we can hunt down later, but if more than ten get past us, the south is open to them."},
	],
	"ashwatch_road_outro": [
		{"who": "hale", "text": "The road held. Look up, Commander: Tamsin has lit the old beacon on the ridge."},
		{"who": "hale", "text": "Two hundred years dark, and Ashwatch burns again. The first light of the Line."},
		{"who": "vell", "text": "Your swordsmen fight like veterans now. Drill them hard: the old masters' arts are open to them."},
	],
	"stonehollow_workshops_intro": [
		{"who": "vell", "text": "They're back, and this time they want the workshops. Every beacon plan, every lens and every pulley in the south was made in there."},
		{"who": "vell", "text": "The forge by the gate, and the two shops under the cliffs. Wall them in, post guards, whatever it takes. We can lose one. Not two."},
		{"who": "hale", "text": "Barricades round the workshops, swords in front of them. Sappers first, Commander, they'll go for the walls."},
	],
	"stonehollow_workshops_outro": [
		{"who": "vell", "text": "The workshops stand. And look there, on the cliff: the masons have lit Stonehollow's beacon."},
		{"who": "vell", "text": "Your walls held better than some of mine. Our engineers will teach your crews the guild's best work: the strongest walls there are."},
		{"who": "marshal", "text": "Two fires in the south now. The King will not like it. Burn the roads before a third is lit."},
	],
	"stonehollow_intro": [
		{"who": "vell", "text": "You're the ones from Ashwatch? Bad timing. They've come for the quarry road."},
		{"who": "vell", "text": "My crews will raise walls wherever you point and patch the gate between waves. You keep the brutes off my masons."},
		{"who": "vell", "text": "Mind the ones with the powder kegs. Sappers. They love a good wall almost as much as I do."},
		{"who": "hale", "text": "Guildmaster, Tamsin's watchtower held at Ashwatch. Your stone is still doing its job.", "if": {"flag": "watchtower_stood"}},
		{"who": "vell", "text": "Ha! Two hundred years and the old work stands. Let's give them some new work to break their teeth on.", "if": {"flag": "watchtower_stood"}},
	],
	"stonehollow_outro": [
		{"who": "vell", "text": "The guild has voted. Stonehollow stands with the Line, the first to do it in two hundred years."},
		{"who": "vell", "text": "You'll have engineers wherever you fight: walls, repairs, a stronger keep. When the other peoples join, we'll build their towers too."},
		{"who": "marshal", "text": "Masons with ideas. The King wants the southern roads cut before they spread them."},
		{"who": "vell", "text": "Three roads run south from here, to Greenwood, Mercy Vale and Deepdelve. All three are burning. Choose where to go first."},
	],
}
