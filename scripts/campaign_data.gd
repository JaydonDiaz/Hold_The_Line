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
const XP_REPLAY_SHARE := 0.5    # ...and a mission already won, played again, this share (on top)
const FLAWLESS_BONUS := 0.5     # a flawless win (rules.flawless: nothing lost, nobody through) trains this much more
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
#              first mission won), {"all": [territories]} (secured: their beacons lit) and/or
#              {"any": [territories], "count": n} (n of those beacons lit).
#   known      shown on the map from the start (as the goal), even before it's reachable.
#   beacon     false: no beacon (Sable Crossing, only the bridge between south and north):
#              winning its missions secures it (opening what needs it), lighting nothing.
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
		"requires": {"joined": ["stonehollow"]}, "missions": ["gw_exodus", "gw_watchfires"], "optional": ["gw_trail"],
		"blurb": "Deep forest held by the Woodland Watch, elven archers who trust no road they didn't cut themselves."},
	"mercyvale": {"name": "Mercy Vale", "pos": Vector2(300, 468), "faction": "mercyvale", "act": 2,
		"requires": {"joined": ["stonehollow"]}, "missions": ["mv_wounded", "mv_sanctuary"],
		"blurb": "A valley of hospices and shrines. The Sanctuary takes in anyone wounded, from any side."},
	"deepdelve": {"name": "Deepdelve", "pos": Vector2(506, 452), "faction": "deepdelve", "act": 2,
		"requires": {"joined": ["stonehollow"]}, "missions": ["dd_entrance", "dd_orerun"],
		"blurb": "Mine shafts and smelters under the eastern peaks. The Mining Guild's gold paid for half the old Line."},
	"sable": {"name": "Sable Crossing", "pos": Vector2(300, 352), "faction": "", "act": 2, "beacon": false,
		"requires": {"all": ["ashwatch", "stonehollow"], "any": ["greenwood", "mercyvale", "deepdelve"], "count": 2}, "missions": ["sable_crossing"],
		"blurb": "The only bridge over the Sable river. Whoever holds it decides whether the south and north ever meet."},
	"frostmarch": {"name": "Frostmarch", "pos": Vector2(112, 214), "faction": "frostmarch", "act": 3,
		"requires": {"all": ["sable"]}, "missions": ["fm_pass", "fm_vigil"], "optional": ["fm_whiteout"],
		"blurb": "Snowbound passes where the Northern Covenant's frost witches have kept to themselves for generations."},
	"monastery": {"name": "The High Monastery", "pos": Vector2(300, 236), "faction": "monastery", "act": 3,
		"requires": {"all": ["sable"]}, "missions": ["mo_steps", "mo_gate"], "optional": ["mo_dawn"],
		"blurb": "A mountain monastery whose fighters have sworn to serve no king's ambitions."},
	"freecities": {"name": "The Free Cities", "pos": Vector2(510, 268), "faction": "freecities", "act": 3,
		"requires": {"all": ["sable"]}, "missions": ["fc_market", "fc_council"], "optional": ["fc_carnival"],
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
#                "positions" (Multiple Positions: "objectives" to keep standing),
#                "evac", "escort" and the rest of scripts/mission/ (each documents its keys)
#   help         what each allied people sends ({faction: {"note", "allies", "gold", "free",
#                "down_time", "walls"}}, see main._send_help): only peoples who've joined
#   bonus_points an optional mission's reward: {kind: n} training points, on the first win
#   pace         {"auto": "forced"}: auto-play is locked on; "deploy": seconds to set up
#                first; "window": seconds from the last of a wave arriving to the next wave
#                (default 25: time to finish it off, rest and reset)
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
		"can_lose": 1,
		"waves": 5, "level": 4, "gold": 360, "count": [5, 2], "mood": "normal", "map": "stonehollow_quarry",
		"pool": {1: ["goblin", "orc"], 2: ["wolf"], 3: ["sapper"], 4: ["orc"]},
		"extra": {2: ["skeleton_archer"], 3: ["troll"], 4: ["skeleton_archer", "skeleton_archer"],
			5: ["troll", "orc", "orc"]},
		"notes": {1: "Keep the workshops standing: lose two and the guild's work is lost.", 3: "Sappers! Wall off the workshops.",
			5: "A Troll is coming for the workshops!"},
		"allies": [{"kind": "swordsman", "at": Vector2(240, 470)}, {"kind": "swordsman", "at": Vector2(400, 470)}],
		"lend": [], "reward": "", "track": {},
		"intro": "stonehollow_workshops_intro", "outro": "stonehollow_workshops_outro"},
	"ashwatch_road": {"name": "The Armoury Wagon", "territory": "ashwatch", "type": "escort", "waves": 99,
		"level": 6, "gold": 360, "count": [8, 3], "mood": "normal", "map": "convoy_pass",
		"requires": {"joined": ["stonehollow"]},
		"convoy": {"name": "Armoury Wagon", "cargo": "arms", "speed": 20.0, "hp": 900, "patch": 0.15,
			"zones": [
				{"map": "convoy_pass", "name": "The Guild Pass", "ambushes": [
					{"at": 0.3, "note": "Raiders on the slopes! They want those swords.", "group": [["orc", Vector2(230, 460)], ["goblin", Vector2(250, 400)], ["goblin", Vector2(400, 400)], ["skeleton_archer", Vector2(420, 330)], ["wolf", Vector2(80, 420)]]},
					{"at": 0.7, "note": "They've blocked the top of the pass!", "group": [["orc", Vector2(260, 160)], ["orc", Vector2(380, 160)], ["goblin", Vector2(320, 130)], ["skeleton_archer", Vector2(330, 60)]]}]},
				{"map": "convoy_meadow", "name": "The Lowland Road", "ambushes": [
					{"at": 0.3, "note": "Raiders out of the copses!", "group": [["orc", Vector2(600, 590)], ["goblin", Vector2(580, 615)], ["goblin", Vector2(60, 520)], ["wolf", Vector2(40, 570)], ["wolf", Vector2(60, 600)]]},
					{"at": 0.7, "note": "Sappers! They mean to blow the wagon apart.", "group": [["sapper", Vector2(500, 290)], ["sapper", Vector2(130, 330)], ["orc", Vector2(545, 280)], ["skeleton_archer", Vector2(520, 160)]]}]},
				{"map": "convoy_ridge", "name": "The Climb to Ashwatch", "ambushes": [
					{"at": 0.3, "note": "Down from the boulders!", "group": [["orc", Vector2(170, 520)], ["orc", Vector2(470, 500)], ["skeleton_archer", Vector2(260, 330)], ["goblin", Vector2(470, 350)], ["wolf", Vector2(560, 420)]]},
					{"at": 0.7, "note": "A Troll on the ridge road, in sight of the keep!", "group": [["troll", Vector2(320, 140)], ["orc", Vector2(260, 160)], ["orc", Vector2(400, 180)], ["skeleton_archer", Vector2(480, 260)]]}]}]},
		"pace": {"auto": "forced", "deploy": 20},
		"pool": {1: ["goblin", "goblin", "orc"], 2: ["wolf", "skeleton_archer"], 3: ["sapper"], 5: ["orc", "skeleton_archer"]},
		"notes": {1: "Bring the Armoury Wagon home to Ashwatch. Raiders will go for the wagon: J or right-click it to have troops follow it."},
		"allies": [{"kind": "swordsman", "at": Vector2(270, 640)}, {"kind": "swordsman", "at": Vector2(370, 640)}],
		"lend": [], "reward": "", "track": {},
		"intro": "ashwatch_road_intro", "outro": "ashwatch_road_outro"},
	# --- Greenwood: the Woodland Watch ------------------------------------------------------
	"gw_exodus": {"name": "The Forest Exodus", "territory": "greenwood", "type": "evac", "waves": 99, "level": 5, "gold": 320,
		"evac": {"routes": [[Vector2(155, 150), Vector2(170, 260), Vector2(160, 420), Vector2(250, 560), Vector2(320, 740)],
				[Vector2(320, 150), Vector2(320, 400), Vector2(320, 740)],
				[Vector2(490, 150), Vector2(475, 260), Vector2(480, 420), Vector2(390, 560), Vector2(320, 740)]],
			"groups": 8, "size": 5, "every": 12.0, "first": 3.0, "hp": 45, "speed": 28.0, "need": 28},
		"pace": {"auto": "forced", "deploy": 22},
		"count": [9, 3], "mood": "normal", "map": "greenwood_roads",
		"pool": {1: ["goblin", "wolf", "wolf"], 2: ["skeleton_archer", "wolf"], 3: ["bat"], 4: ["wolf"], 5: ["orc"]},
		"notes": {1: "The Watch's families are coming down the forest roads. Save at least 28.", 3: "Bats! The Watch's archers can bring them down."},
		"allies": [{"kind": "archer", "at": Vector2(240, 560)}, {"kind": "archer", "at": Vector2(400, 560)}],
		"lend": [], "reward": "greenwood", "track": {},
		"intro": "gw_exodus_intro", "outro": "gw_exodus_outro"},
	"gw_watchfires": {"name": "The Watchfires", "territory": "greenwood", "type": "positions", "waves": 6, "level": 5, "gold": 360,
		"objectives": [{"id": "west", "kind": "watchtower", "name": "West Watchfire", "at": Vector2(180, 600), "hp": 850},
			{"id": "mid", "kind": "watchtower", "name": "Middle Watchfire", "at": Vector2(320, 560), "hp": 850},
			{"id": "east", "kind": "watchtower", "name": "East Watchfire", "at": Vector2(460, 600), "hp": 850}],
		"can_lose": 1,
		"count": [7, 3], "mood": "normal", "map": "greenwood_roads",
		"pool": {1: ["goblin", "wolf"], 2: ["skeleton_archer"], 3: ["bat", "orc"], 5: ["troll"]},
		"extra": {4: ["wolf", "wolf", "wolf"], 6: ["troll", "orc", "orc"]},
		"notes": {1: "Keep the watchfires burning: lose two and the forest goes dark.", 4: "A wolf pack, running for the fires!", 6: "Trolls on the forest roads!"},
		"allies": [], "lend": [], "reward": "", "track": {},
		"intro": "gw_watchfires_intro", "outro": "gw_watchfires_outro"},
	"gw_trail": {"name": "The Hunter's Trail", "territory": "greenwood", "waves": 5, "level": 5, "gold": 360,
		"count": [8, 3], "mood": "normal", "map": "greenwood_roads", "bonus_points": {"archer": 1},
		"pool": {1: ["wolf", "wolf", "goblin"], 2: ["bat"], 3: ["skeleton_archer", "orc"]},
		"extra": {5: ["wolf", "wolf", "wolf", "wolf", "orc", "orc"]},
		"notes": {1: "The pack that's been hunting the Watch's trails. Run them down.", 5: "The pack leaders!"},
		"allies": [], "lend": [], "reward": "", "track": {},
		"intro": "gw_trail_intro", "outro": "gw_trail_outro"},
	# --- Mercy Vale: the Sanctuary -----------------------------------------------------------
	"mv_wounded": {"name": "The Wounded Road", "territory": "mercyvale", "type": "evac", "waves": 99, "level": 5, "gold": 320,
		"evac": {"routes": [[Vector2(130, 130), Vector2(200, 200), Vector2(215, 300), Vector2(120, 380), Vector2(40, 440), Vector2(50, 480),
					Vector2(140, 600), Vector2(320, 740)],
				[Vector2(510, 130), Vector2(440, 200), Vector2(425, 300), Vector2(520, 380), Vector2(600, 440), Vector2(590, 480),
					Vector2(500, 600), Vector2(320, 740)]],
			"groups": 9, "size": 4, "every": 11.0, "first": 3.0, "hp": 35, "speed": 26.0, "need": 26},
		"pace": {"auto": "forced", "deploy": 22},
		"count": [9, 3], "mood": "normal", "map": "mercy_fields",
		"pool": {1: ["goblin", "wolf", "wolf"], 2: ["orc", "wolf"], 3: ["skeleton_archer"], 4: ["wolf"]},
		"notes": {1: "The wounded are coming in down both flanks. Get at least 26 to the hospice."},
		"allies": [{"kind": "healer", "at": Vector2(320, 600)}],
		"lend": [], "reward": "mercyvale", "track": {},
		"intro": "mv_wounded_intro", "outro": "mv_wounded_outro"},
	"mv_sanctuary": {"name": "The Last Sanctuary", "territory": "mercyvale", "waves": 6, "level": 4, "gold": 440,
		"count": [6, 2], "mood": "normal", "map": "mercy_fields",
		"pool": {1: ["orc", "wolf"], 2: ["goblin"], 3: ["skeleton_archer"]},
		"extra": {3: ["skeleton_archer"], 5: ["orc", "orc"], 6: ["troll", "skeleton_archer"]},
		"notes": {1: "Long waves, Commander: keep your troops alive and the hospice will hold.", 3: "Skeleton Archers, wearing the line down from range.", 6: "Their last push on the hospice!"},
		"allies": [], "lend": [], "reward": "", "track": {},
		"intro": "mv_sanctuary_intro", "outro": "mv_sanctuary_outro"},
	# --- Deepdelve: the Mining Guild ---------------------------------------------------------
	"dd_entrance": {"name": "The Mine Entrance", "territory": "deepdelve", "waves": 5, "level": 6, "gold": 340,
		"count": [8, 3], "mood": "normal", "map": "deepdelve_switchbacks",
		"pool": {1: ["goblin", "orc"], 2: ["sapper"], 3: ["troll"], 4: ["orc"]},
		"extra": {3: ["sapper", "sapper"], 4: ["troll"], 5: ["troll", "troll", "sapper"]},
		"notes": {1: "They're at the mine. Hold the canyon road.", 2: "Sappers! Keep them off your walls and the cannon.", 5: "Trolls coming down the switchbacks!"},
		"allies": [{"kind": "cannon", "at": Vector2(320, 600), "built": true}, {"kind": "mine", "at": Vector2(560, 680), "built": true}],
		"lend": [], "reward": "deepdelve", "track": {},
		"intro": "dd_entrance_intro", "outro": "dd_entrance_outro"},
	"dd_orerun": {"name": "The Ore Run", "territory": "deepdelve", "type": "escort", "waves": 99, "level": 5, "gold": 380,
		"convoy": {"name": "Ore cart", "speed": 20.0, "hp": 1300, "patch": 0.15,
			"zones": [
				{"map": "convoy_ridge", "ambushes": [
					{"at": 0.3, "note": "Down from the boulders!", "group": [["orc", Vector2(170, 520)], ["orc", Vector2(470, 500)], ["goblin", Vector2(470, 350)], ["goblin", Vector2(160, 380)]]},
					{"at": 0.7, "note": "They've blocked the ridge road!", "group": [["troll", Vector2(320, 140)], ["orc", Vector2(260, 160)], ["sapper", Vector2(400, 180)]]}]},
				{"map": "convoy_pass", "ambushes": [
					{"at": 0.3, "note": "They're coming down the slopes!", "group": [["orc", Vector2(230, 460)], ["orc", Vector2(410, 460)], ["goblin", Vector2(250, 400)], ["goblin", Vector2(400, 400)]]},
					{"at": 0.7, "note": "Trolls hold the top of the pass!", "group": [["troll", Vector2(320, 110)], ["orc", Vector2(260, 160)], ["orc", Vector2(380, 160)]]}]}]},
		"pace": {"auto": "forced", "deploy": 20},
		"count": [7, 3], "mood": "normal", "map": "convoy_ridge",
		"pool": {1: ["goblin", "goblin"], 2: ["wolf", "skeleton_archer"], 3: ["orc", "sapper"], 4: ["skeleton_archer"]},
		"notes": {1: "Get the ore cart over the ridge and through the pass to the foundries. Right-click it (or J) to follow it."},
		"allies": [], "lend": [], "reward": "", "track": {},
		"intro": "dd_orerun_intro", "outro": "dd_orerun_outro"},
	# --- Sable Crossing: the Ash Marshal -----------------------------------------------------
	# --- Frostmarch: the Northern Covenant (Phase 4) ------------------------------------------
	# The first northern mission is meant to be fair whatever the south gave you: the Covenant
	# lends two Frost Witches, and Frost Witches can be hired for this battle, so Slimes can
	# always be hurt even if the two lent fall.
	"fm_pass": {"name": "The Frozen Pass", "territory": "frostmarch", "type": "pass", "limit": 18, "waves": 8, "level": 4, "gold": 500,
		"count": [6, 2], "mood": "normal", "map": "frostmarch_pass",
		"weather": {"blizzard": {"first": 30.0, "every": 45.0, "length": 10.0, "warn": 10.0}},
		"pool": {1: ["goblin", "wolf"], 2: ["orc", "skeleton_archer"], 3: ["slime", "slime"], 4: ["troll"], 5: ["orc"]},
		"extra": {3: ["slime", "slime"], 5: ["troll", "slime"], 6: ["orc", "slime"], 8: ["troll", "slime", "orc"]},
		"notes": {1: "Hold the pass: no more than 18 of them may get through. Blizzards blow in off the peaks.",
			3: "Slimes! Blades and arrows sink into them: only frost, magic or ki hurts them (or ice them first).",
			4: "A Troll! Thin ice won't hold it: lure it out onto the edges of the lake.",
			8: "Their last push through the pass, Trolls and all!"},
		"allies": [{"kind": "frost", "at": Vector2(280, 560)}, {"kind": "frost", "at": Vector2(360, 560)}],
		"lend": ["frost"], "reward": "frostmarch", "track": {"witches_stood": "frost"},
		"intro": "fm_pass_intro", "outro": "fm_pass_outro"},
	"fm_vigil": {"name": "The Covenant's Vigil", "territory": "frostmarch", "type": "positions", "waves": 8, "level": 4, "gold": 520,
		"objectives": [{"id": "west", "kind": "stone", "name": "West Stone", "at": Vector2(140, 520), "hp": 1250},
			{"id": "lake", "kind": "stone", "name": "Lake Stone", "at": Vector2(320, 486), "hp": 1250},
			{"id": "east", "kind": "stone", "name": "East Stone", "at": Vector2(500, 520), "hp": 1250}],
		"can_lose": 1,
		"count": [6, 2], "mood": "normal", "map": "frostmarch_lake",
		"weather": {"blizzard": {"first": 35.0, "every": 50.0, "length": 10.0, "warn": 10.0}},
		"pool": {1: ["goblin", "orc", "goblin"], 2: ["wolf", "skeleton_archer"], 3: ["slime"], 5: ["orc"]},
		"extra": {4: ["troll"], 5: ["slime"], 6: ["troll", "orc"], 8: ["troll", "orc"]},
		"notes": {1: "Keep the standing stones up through the rite: lose two and it fails.",
			4: "Trolls on the lake! The thin ice round the Lake Stone won't take their weight.",
			6: "Trolls on the lake again!", 8: "The last of them, all at the stones!"},
		"allies": [], "lend": [], "reward": "", "track": {},
		"intro": "fm_vigil_intro", "outro": "fm_vigil_outro"},
	"fm_whiteout": {"name": "Whiteout", "territory": "frostmarch", "type": "escort", "waves": 99, "level": 6, "gold": 440,
		"convoy": {"name": "Lamp-oil sled", "cargo": "sled", "speed": 18.0, "hp": 1200, "patch": 0.15,
			"zones": [
				{"map": "frostmarch_crossing", "name": "The Long Lake", "ambushes": [
					{"at": 0.3, "note": "Out of the snow! Wolves and Slimes on the ice!", "group": [["wolf", Vector2(160, 470)], ["wolf", Vector2(480, 420)], ["slime", Vector2(200, 380)], ["slime", Vector2(460, 520)], ["orc", Vector2(330, 260)]]},
					{"at": 0.65, "note": "A Troll on the lake: mind the thin ice!", "group": [["troll", Vector2(450, 300)], ["orc", Vector2(200, 260)], ["slime", Vector2(260, 200)], ["skeleton_archer", Vector2(420, 150)]]}]}]},
		"pace": {"auto": "forced", "deploy": 20},
		"count": [5, 2], "mood": "normal", "map": "frostmarch_crossing", "bonus_points": {"frost": 1},
		"weather": {"blizzard": {"first": 15.0, "every": 30.0, "length": 14.0, "warn": 10.0, "whiteout": true}},
		"pool": {1: ["wolf", "goblin"], 2: ["slime", "orc"], 3: ["skeleton_archer"], 4: ["troll"]},
		"notes": {1: "Get the lamp oil across the lake to the witches' hall. In the whiteout you'll see them late: keep troops round the sled."},
		"allies": [], "lend": [], "reward": "", "track": {},
		"intro": "fm_whiteout_intro", "outro": "fm_whiteout_outro"},
	# --- The High Monastery: the Martial Order (Phase 4) ---------------------------------------
	# Wyverns first fly here, so the first Monastery mission has to give every southern
	# alliance something that hits them: the Order lends three masters already trained in
	# Spirit Bolts (ki that reaches the air), and Martial Artists can be hired for this battle
	# (Spirit Bolts is a tier I upgrade, no training needed).
	"mo_steps": {"name": "The Thousand Steps", "territory": "monastery", "type": "retreat", "waves": 99, "level": 5, "gold": 480,
		"limit": 14, "stream": 2.2, "stream_from": 3,
		"retreat": {"lines": [{"y": 176, "name": "Upper Terrace", "time": 50}, {"y": 312, "name": "Prayer Terrace", "time": 45},
				{"y": 450, "name": "Garden Terrace", "time": 45}, {"y": 584, "name": "Gate Terrace", "time": 40}],
			"extract": {"y": 676, "time": 25, "need": 6}},
		"pace": {"auto": "forced", "deploy": 25},
		"count": [5, 2], "mood": "normal", "map": "monastery_steps",
		"pool": {1: ["goblin", "goblin", "orc"], 2: ["wolf", "skeleton_archer"], 4: ["orc"], 6: ["troll"]},
		"extra": {3: ["wyvern"], 5: ["wyvern", "orc"], 7: ["wyvern", "wyvern", "troll"]},
		"notes": {1: "Hold each terrace, then fall back down the stairs when the bell sounds [Y]. Get at least 6 troops out at the gate.",
			3: "A Wyvern! Blades can't reach it: Spirit Bolts, arrows and magic can.",
			7: "Wyverns over the terraces, and the whole army behind them!"},
		"allies": [{"kind": "martial", "at": Vector2(240, 206), "tiers": [1, 0, 0, 0]}, {"kind": "martial", "at": Vector2(320, 206), "tiers": [1, 0, 0, 0]},
			{"kind": "martial", "at": Vector2(400, 206), "tiers": [1, 0, 0, 0]}],
		"lend": ["martial"], "reward": "monastery", "track": {"masters_stood": "martial"},
		"intro": "mo_steps_intro", "outro": "mo_steps_outro"},
	# The bells: the towers are the mission's objectives, and each can be rung once a wave
	# while it stands (click it, or K) to stun every enemy round it.
	"mo_gate": {"name": "The Trial of the Gate", "territory": "monastery", "type": "positions", "waves": 8, "level": 5, "gold": 520,
		"objectives": [{"id": "west", "kind": "bell", "name": "West Bell", "at": Vector2(150, 480), "hp": 1500},
			{"id": "dawn", "kind": "bell", "name": "Dawn Bell", "at": Vector2(320, 430), "hp": 1500},
			{"id": "east", "kind": "bell", "name": "East Bell", "at": Vector2(490, 480), "hp": 1500}],
		"can_lose": 1, "bells": {"at": []},
		"count": [5, 2], "mood": "normal", "map": "monastery_gate",
		"pool": {1: ["goblin", "orc", "goblin"], 2: ["wolf", "skeleton_archer"], 3: ["orc"], 5: ["slime"]},
		"extra": {4: ["wyvern"], 5: ["troll"], 7: ["troll"], 8: ["troll", "wyvern", "orc"]},
		"notes": {1: "Keep the bell towers standing: lose two and the trial fails. Ring a bell [K, or click it] to stun everything round it, once a wave.",
			4: "A Wyvern over the courtyard! Spirit Bolts (a Martial Artist's first upgrade) reach it.", 5: "Slimes! Ki, frost and magic hurt them.", 8: "The last of them, at the gate!"},
		"allies": [{"kind": "martial", "at": Vector2(230, 470), "tiers": [1, 0, 0, 0]}, {"kind": "martial", "at": Vector2(410, 470), "tiers": [1, 0, 0, 0]},
			{"kind": "martial", "at": Vector2(320, 520), "tiers": [1, 0, 0, 0]}],
		"lend": [], "reward": "", "track": {},
		"intro": "mo_gate_intro", "outro": "mo_gate_outro"},
	"mo_dawn": {"name": "The Bells of Dawn", "territory": "monastery", "type": "capture", "waves": 99, "level": 6, "gold": 460,
		"capture": {"at": Vector2(320, 440), "radius": 84.0, "name": "the bell court", "time": 20.0, "hold": 60.0, "limit": 200.0},
		"bells": {"at": [Vector2(150, 480), Vector2(490, 480)]},
		"pace": {"auto": "forced", "deploy": 18},
		"count": [7, 2], "mood": "normal", "map": "monastery_gate", "battle": "dawn", "bonus_points": {"martial": 1},
		"pool": {1: ["goblin", "orc"], 2: ["wolf", "skeleton_archer"], 3: ["orc", "wyvern"], 5: ["troll"]},
		"notes": {1: "Take the bell court and hold it till dawn. Stand a troop by a bell tower to ring it [K]."},
		"allies": [], "lend": [], "reward": "", "track": {},
		"intro": "mo_dawn_intro", "outro": "mo_dawn_outro"},
	# --- The Free Cities: the Council (Phase 4) ------------------------------------------------
	# Business as the cities do it, all optional: a contract offered at the start (a bond
	# paid to sign, gold for every wave held to its terms, void once broken; contracts.gd),
	# and sellswords to hire any time, already trained (no need of the kinds they bring,
	# so an army without Deepdelve's mines or Greenwood's archers can buy what it lacks).
	"fc_market": {"name": "The Market Road", "territory": "freecities", "type": "evac", "waves": 99, "level": 5, "gold": 340,
		"evac": {"routes": [[Vector2(110, 120), Vector2(110, 400), Vector2(110, 600), Vector2(220, 650), Vector2(320, 740)],
				[Vector2(320, 120), Vector2(320, 400), Vector2(320, 740)],
				[Vector2(530, 120), Vector2(530, 400), Vector2(530, 600), Vector2(420, 650), Vector2(320, 740)]],
			"groups": 9, "size": 4, "every": 11.0, "first": 3.0, "hp": 40, "speed": 27.0, "need": 26},
		"pace": {"auto": "forced", "deploy": 22},
		"count": [8, 3], "mood": "normal", "map": "city_market",
		"pool": {1: ["goblin", "wolf", "wolf"], 2: ["orc", "skeleton_archer"], 3: ["bat"], 4: ["wolf", "orc"]},
		"contract": {"name": "Merchants' Purse", "from": "The Merchants' Guild", "bond": 100, "pay": 45, "terms": "none_lost",
			"desc": "Pays for every wave in which none of the townsfolk is caught."},
		"mercs": {"name": "Sellswords", "cost": 200, "max": 2,
			"squad": [{"kind": "swordsman", "tiers": [1, 1, 0, 0]}, {"kind": "archer", "tiers": [1, 0, 0, 0]}]},
		"notes": {1: "The townsfolk are coming down the three streets. Get at least 26 out. The Guild offers a contract, and sellswords are for hire.",
			3: "Bats! The Alchemist's flasks and the Bard's notes reach them."},
		"allies": [{"kind": "alchemist", "at": Vector2(250, 600)}, {"kind": "bard", "at": Vector2(390, 600)}],
		"lend": ["bard", "alchemist"], "reward": "freecities", "track": {},
		"intro": "fc_market_intro", "outro": "fc_market_outro"},
	"fc_council": {"name": "The Council's Price", "territory": "freecities", "type": "protect", "waves": 99, "level": 4, "gold": 600,
		"objectives": [{"id": "exchange", "kind": "exchange", "name": "The Exchange", "at": Vector2(320, 486), "hp": 1800, "charge": 160}],
		"pace": {"auto": "forced", "deploy": 25, "window": 24},
		"count": [6, 2], "mood": "normal", "map": "city_exchange",
		"pool": {1: ["goblin", "orc"], 2: ["wolf"], 3: ["sapper"], 4: ["skeleton_archer"], 6: ["orc"]},
		"extra": {5: ["warlord", "orc"], 7: ["troll", "skeleton_archer"]},
		"contract": {"name": "Council Bond", "from": "The Council of the Free Cities", "bond": 150, "pay": 60, "terms": "objective", "obj": "exchange",
			"desc": "Pays for every wave in which the Exchange takes no damage at all."},
		"mercs": {"name": "Sellswords", "cost": 220, "max": 2,
			"squad": [{"kind": "swordsman", "tiers": [2, 1, 0, 0]}, {"kind": "archer", "tiers": [1, 1, 0, 0]}]},
		"notes": {1: "Keep the Exchange standing until the Council has voted (the bar over it). While an enemy is at its doors, the vote stops.",
			3: "Sappers! Keep them off the Exchange.", 5: "The Warlord! He hits like a Troll and drives the rest on."},
		"allies": [], "lend": [], "reward": "", "track": {},
		"intro": "fc_council_intro", "outro": "fc_council_outro"},
	"fc_carnival": {"name": "Carnival Night", "territory": "freecities", "type": "capture", "waves": 99, "level": 6, "gold": 460,
		"capture": {"at": Vector2(320, 420), "radius": 88.0, "name": "the carnival plaza", "time": 20.0, "hold": 70.0, "limit": 220.0},
		"night": {"lanterns": [Vector2(320, 330), Vector2(230, 420), Vector2(410, 420), Vector2(320, 510), Vector2(160, 400), Vector2(480, 400),
				Vector2(320, 200), Vector2(140, 660), Vector2(500, 660)], "light": 110.0},
		"pace": {"auto": "forced", "deploy": 18},
		"count": [7, 2], "mood": "hard", "map": "city_carnival", "bonus_points": {"bard": 1, "alchemist": 1},
		"pool": {1: ["goblin", "wolf"], 2: ["orc", "skeleton_archer"], 3: ["bat", "wolf"], 5: ["troll"]},
		"mercs": {"name": "Sellswords", "cost": 200, "max": 1,
			"squad": [{"kind": "swordsman", "tiers": [1, 1, 0, 0]}, {"kind": "swordsman", "tiers": [1, 1, 0, 0]}]},
		"notes": {1: "Take the carnival plaza and hold it. Away from the lanterns it's dark: red eyes and the chevrons up top show where they're coming."},
		"allies": [], "lend": [], "reward": "", "track": {},
		"intro": "fc_carnival_intro", "outro": "fc_carnival_outro"},
	"sable_crossing": {"name": "Sable Crossing", "territory": "sable", "type": "pass", "limit": 14, "waves": 7, "level": 6, "gold": 400,
		"count": [8, 3], "mood": "normal", "map": "sable_crossing",
		"pool": {1: ["goblin", "goblin", "orc"], 2: ["wolf"], 3: ["skeleton_archer"], 4: ["sapper"], 5: ["troll"]},
		"extra": {3: ["orc", "orc"], 5: ["troll", "wolf", "wolf"], 7: ["ash_marshal", "troll", "orc", "orc", "skeleton_archer"]},
		"notes": {1: "Hold the crossing: no more than 14 may get past.", 4: "Sappers! They'll go for any wall at the bridges.", 7: "The Ash Marshal himself leads them in!"},
		"allies": [{"kind": "swordsman", "at": Vector2(150, 470)}, {"kind": "swordsman", "at": Vector2(480, 470)}],
		"help": {
			"greenwood": {"note": "two Woodland archers and Arrow Storm", "allies": [{"kind": "archer", "at": Vector2(200, 520)}, {"kind": "archer", "at": Vector2(440, 520)}], "free": ["arrows"]},
			"deepdelve": {"note": "150 gold, a Gold Mine and a cannon at the ford", "gold": 150, "allies": [{"kind": "mine", "at": Vector2(570, 660), "built": true},
				{"kind": "cannon", "at": Vector2(325, 540), "built": true}]},
			"mercyvale": {"note": "a Healer, and fallen troops hold on longer", "allies": [{"kind": "healer", "at": Vector2(325, 600)}], "down_time": 1.5},
			"stonehollow": {"note": "a barricade across the ford", "walls": [[Vector2(283, 440), Vector2(367, 440)]]}},
		"lend": [], "reward": "", "track": {},
		"intro": "sable_intro", "outro": "sable_outro"},
}

# Named characters. "look" draws their portrait (portraits.gd): each wears the dress of
# their homeland, in its colours, against its sky.
const SPEAKERS := {
	"hale": {"name": "Captain Maren Hale", "role": "Ashwatch Keep", "color": Color(0.95, 0.85, 0.45),
		"look": {"skin": Color(0.96, 0.78, 0.62), "hair": "braid", "hair_color": Color(0.62, 0.26, 0.12),
			"outfit": "tabard", "colors": [Color(0.24, 0.36, 0.72), Color(0.72, 0.74, 0.8), Color(0.95, 0.8, 0.3)],
			"extras": ["scar", "rivets", "lashes", "cloak"], "scene": "keep", "bg": [Color(0.45, 0.55, 0.75), Color(0.2, 0.24, 0.36)]}},
	"vell": {"name": "Guildmaster Brannoc Vell", "role": "The Engineers' Guild, Stonehollow", "color": Color(0.85, 0.62, 0.32),
		"look": {"skin": Color(0.86, 0.62, 0.45), "hair": "bald", "hair_color": Color(0.62, 0.6, 0.6), "beard": "full", "beard_color": Color(0.72, 0.72, 0.74),
			"head": "goggles", "outfit": "apron", "colors": [Color(0.52, 0.34, 0.2), Color(0.7, 0.47, 0.26), Color(0.88, 0.68, 0.28)],
			"extras": ["pencil", "tools"], "scene": "forge", "bg": [Color(0.6, 0.56, 0.52), Color(0.3, 0.27, 0.25)]}},
	"thorne": {"name": "Warden Sylla Thorne", "role": "The Woodland Watch, Greenwood", "color": Color(0.45, 0.85, 0.4),
		"look": {"skin": Color(0.92, 0.76, 0.6), "hair": "braid", "hair_color": Color(0.35, 0.65, 0.3), "eyes": Color(0.2, 0.42, 0.18),
			"head": "circlet", "outfit": "leaf_cloak", "colors": [Color(0.5, 0.36, 0.2), Color(0.38, 0.26, 0.14), Color(0.85, 0.2, 0.2)],
			"extras": ["elf", "quiver", "lashes", "leaves"], "scene": "forest", "bg": [Color(0.4, 0.62, 0.36), Color(0.12, 0.25, 0.14)]}},
	"dagna": {"name": "Forewoman Dagna Coalbright", "role": "The Mining Guild, Deepdelve", "color": Color(1.0, 0.8, 0.3),
		"look": {"skin": Color(0.95, 0.74, 0.58), "hair": "long", "hair_color": Color(0.8, 0.32, 0.12),
			"head": "miner", "outfit": "overalls", "colors": [Color(0.42, 0.46, 0.55), Color(0.42, 0.28, 0.16), Color(0.95, 0.72, 0.2)],
			"extras": ["soot", "pick", "lashes"], "scene": "mine", "bg": [Color(0.45, 0.33, 0.25), Color(0.14, 0.1, 0.08)]}},
	"ilse": {"name": "Mother Ilse Varrow", "role": "The Sanctuary, Mercy Vale", "color": Color(0.95, 0.95, 0.7),
		"look": {"skin": Color(0.9, 0.72, 0.6), "hair": "short", "hair_color": Color(0.7, 0.68, 0.66),
			"head": "veil", "outfit": "robe", "colors": [Color(0.94, 0.93, 0.88), Color(0.85, 0.83, 0.78), Color(0.92, 0.75, 0.3)],
			"extras": ["wrinkles", "pendant", "veil_trim"], "scene": "shrine", "bg": [Color(0.98, 0.9, 0.7), Color(0.62, 0.55, 0.42)]}},
	"ysra": {"name": "Matriarch Ysra Frostvein", "role": "The Northern Covenant, Frostmarch", "color": Color(0.6, 0.88, 1.0),
		"look": {"skin": Color(0.94, 0.88, 0.88), "hair": "long", "hair_color": Color(0.88, 0.92, 0.98), "eyes": Color(0.3, 0.7, 1.0),
			"head": "ice_crown", "outfit": "frost_mantle", "colors": [Color(0.2, 0.32, 0.62), Color(0.96, 0.97, 0.99), Color(0.6, 0.88, 1.0)],
			"extras": ["frost_marks", "frost_lips", "brooch", "lashes"], "scene": "north", "bg": [Color(0.16, 0.26, 0.48), Color(0.05, 0.08, 0.18)]}},
	"coralie": {"name": "Magistra Coralie Fenn", "role": "The Free Cities", "color": Color(1.0, 0.6, 0.85),
		"look": {"skin": Color(0.72, 0.48, 0.34), "hair": "bun", "hair_color": Color(0.14, 0.1, 0.12),
			"head": "comb", "outfit": "magistrate", "colors": [Color(0.42, 0.16, 0.38), Color(0.62, 0.26, 0.52), Color(0.98, 0.8, 0.32)],
			"extras": ["monocle", "hoops", "ruff", "chain", "lashes"], "scene": "city", "bg": [Color(0.98, 0.62, 0.42), Color(0.42, 0.18, 0.35)]}},
	"kaito": {"name": "Abbot Kaito Ren", "role": "The Martial Order, the High Monastery", "color": Color(1.0, 0.5, 0.35),
		"look": {"skin": Color(0.9, 0.7, 0.5), "hair": "bald", "hair_color": Color(0.2, 0.15, 0.12),
			"outfit": "monk", "colors": [Color(0.92, 0.5, 0.15), Color(0.7, 0.33, 0.1), Color(0.45, 0.28, 0.15)],
			"extras": ["beads", "calm", "mark"], "scene": "monastery", "bg": [Color(0.98, 0.78, 0.55), Color(0.5, 0.3, 0.3)]}},
	"ysolde": {"name": "Archmagus Ysolde Vane", "role": "The Mage Conclave, the Arcane Spires", "color": Color(0.75, 0.55, 1.0),
		"look": {"skin": Color(0.95, 0.82, 0.76), "hair": "long", "hair_color": Color(0.82, 0.78, 0.92), "eyes": Color(0.75, 0.5, 1.0),
			"head": "wizard", "outfit": "star_robe", "colors": [Color(0.4, 0.25, 0.65), Color(0.28, 0.16, 0.48), Color(1.0, 0.9, 0.4)],
			"extras": ["glow", "motes", "lashes", "hat_band"], "scene": "spires", "bg": [Color(0.35, 0.28, 0.6), Color(0.08, 0.06, 0.18)]}},
	"ogre": {"name": "The Ogre King", "role": "", "color": Color(1.0, 0.4, 0.3),
		"look": {"skin": Color(0.5, 0.62, 0.36), "hair": "bald", "hair_color": Color(0.22, 0.2, 0.12), "eyes": Color(1.0, 0.8, 0.2), "wide": true,
			"head": "crown", "outfit": "ogre", "colors": [Color(0.45, 0.3, 0.18), Color(0.35, 0.22, 0.12), Color(0.92, 0.75, 0.25)],
			"extras": ["tusks", "glow", "angry", "pelt", "teeth"], "scene": "ogre", "bg": [Color(0.7, 0.2, 0.12), Color(0.18, 0.05, 0.05)]}},
	"marshal": {"name": "The Ash Marshal", "role": "Herald of the Ogre King", "color": Color(1.0, 0.55, 0.3),
		"look": {"skin": Color(0.4, 0.34, 0.33), "hair": "bald", "hair_color": Color(0.1, 0.1, 0.1),
			"head": "horned", "outfit": "armor", "colors": [Color(0.24, 0.22, 0.24), Color(0.5, 0.18, 0.1), Color(1.0, 0.5, 0.15)],
			"extras": ["ember_slit", "helm_shine"], "scene": "embers", "bg": [Color(0.45, 0.3, 0.25), Color(0.1, 0.07, 0.07)]}},
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
# {"no_ally": faction} or {"difficulty": key}. The enemy's lines (the Ogre King's and the
# Marshal's) play as cutscenes of their own, unless "box": true puts one in the dialogue
# box like anyone else's (when he's there on that battlefield).
const STORY := {
	"ashwatch_intro": [
		{"who": "hale", "text": "Commander! Torches on the ridge. Goblins, and a lot more behind them."},
		{"who": "hale", "text": "Half the garrison rode south a week ago. What's left is you, me, two knights and old Tamsin up in the watchtower."},
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
		{"who": "vell", "text": "Your order's ready, Commander. Guild axes, mail shirts and a hundred new-forged swords, all on one wagon."},
		{"who": "hale", "text": "Enough steel for every blade in Ashwatch. And the King's raiders know it's on the road: the pass, the lowlands and the climb to the keep."},
		{"who": "vell", "text": "There's no wall out there but the wagon's sides. Keep them off it, and have your troops walk with it [J]."},
	],
	"ashwatch_road_outro": [
		{"who": "hale", "text": "The wagon's in, every axe and every hauberk. And look up, Commander: Tamsin has lit the old beacon on the ridge."},
		{"who": "hale", "text": "Two hundred years dark, and Ashwatch burns again. The first light of the Line."},
		{"who": "vell", "text": "Guild steel and guild mail. Your knights can learn the old masters' arts now: drill them hard."},
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
	# --- The south -------------------------------------------------------------------------
	"gw_exodus_intro": [
		{"who": "thorne", "text": "You're the commander who woke the old beacons. Then you came at a bad hour. The King's beasts are in the wood."},
		{"who": "thorne", "text": "My people are leaving the high camps, down all three roads at once. Keep the roads open until the last family is through."},
		{"who": "thorne", "text": "Two of the Watch will stand with you. Mind the sky: bats nest in the old oaks, and only arrows reach them."},
	],
	"gw_exodus_outro": [
		{"who": "thorne", "text": "They're through. You held three roads with what you had. The Watch has seen a promise kept."},
		{"who": "thorne", "text": "The Woodland Watch stands with the Line. Our archers will shoot from your walls, and our towers will rise where you need them."},
		{"who": "marshal", "text": "Elves, now. Then the trees can burn with them."},
	],
	"gw_watchfires_intro": [
		{"who": "thorne", "text": "Before the beacons, the Watch spoke with fire: three watchfires at the edge of the clearing, each answering the next."},
		{"who": "thorne", "text": "Keep them burning tonight, and Greenwood's beacon will be lit from their flame. Lose two and the forest goes dark."},
	],
	"gw_watchfires_outro": [
		{"who": "thorne", "text": "The watchfires held, and the beacon on the great oak burns. Greenwood answers the Line."},
		{"who": "thorne", "text": "Your archers have earned the Watch's oldest arts. Train them, and they'll shoot like the elders."},
	],
	"fm_pass_intro": [
		{"who": "ysra", "text": "So the south remembers the north at last. You've come a long way to stand in the snow, Commander."},
		{"who": "ysra", "text": "The King's army is coming up the Frozen Pass. If it gets through, the Covenant's halls burn. Hold it, and we will talk."},
		{"who": "ysra", "text": "Two of my sisters will stand with you, and more will answer if you call. Mind the lake: the ice at its edges is thin."},
	],
	"fm_pass_outro": [
		{"who": "ysra", "text": "The pass held. My sisters say you fought like someone who meant to keep a promise."},
		{"who": "ysra", "text": "Two still stand who stood beside you. The Covenant will not forget it.", "if": {"flag": "witches_stood"}},
		{"who": "ysra", "text": "The Northern Covenant stands with the Line. Our witches will freeze your enemies, and our towers will hold your walls."},
		{"who": "marshal", "text": "Witches. Ice melts, old woman, and so will you."},
	],
	"fm_vigil_intro": [
		{"who": "ysra", "text": "Frostmarch's beacon has never been lit by fire. It is lit by the rite of the stones, three of them, round the frozen lake."},
		{"who": "ysra", "text": "Keep them standing until the rite is done. Lose two and it fails. The stone on the lake is the hardest to hold."},
	],
	"fm_vigil_outro": [
		{"who": "ysra", "text": "The rite is done, and the beacon burns blue over the lake. Frostmarch answers the Line."},
		{"who": "ysra", "text": "Our oldest arts are yours now. Train your witches, and winter itself will fight for you."},
	],
	"fm_whiteout_intro": [
		{"who": "ysra", "text": "The witches' hall on the far shore is down to its last lamps. A sled of oil must cross the lake tonight, in the whiteout."},
		{"who": "ysra", "text": "You won't see them coming until they're on you. Keep your troops close to the sled."},
	],
	"fm_whiteout_outro": [
		{"who": "ysra", "text": "The lamps are lit again across the lake. My sisters will teach your witches something for that."},
	],
	"mo_steps_intro": [
		{"who": "kaito", "text": "You climbed all this way to ask us to fight, Commander. The King's army climbed after you."},
		{"who": "kaito", "text": "The Order does not serve kings, his or yours. But we will not let the Thousand Steps run with blood for nothing."},
		{"who": "kaito", "text": "Hold each terrace as long as you can, then come down when the bell sounds. Three of my masters will stand with you. Their ki reaches even the wyverns."},
	],
	"mo_steps_outro": [
		{"who": "kaito", "text": "You brought your people down the mountain and left none you didn't have to. That is a kind of discipline."},
		{"who": "kaito", "text": "My masters came back with you, all three. The novices will speak of it for years.", "if": {"flag": "masters_stood"}},
		{"who": "kaito", "text": "The Martial Order will walk with the Line. Not for your crown: for the ones on the steps."},
		{"who": "marshal", "text": "Monks. They'll find their ki is no use against my iron."},
	],
	"mo_gate_intro": [
		{"who": "kaito", "text": "Our beacon is not lit with fire either. It is lit by the three bells, rung at dawn after a night's vigil."},
		{"who": "kaito", "text": "Keep the towers standing. A bell rung in anger stuns whatever stands round it, but only once before it must rest."},
		{"who": "kaito", "text": "Three of my masters will keep the vigil with you. Their bolts reach the wyverns, and the slimes."},
	],
	"mo_gate_outro": [
		{"who": "kaito", "text": "The bells rang at dawn, and the beacon on the peak answered. The Monastery stands with the Line."},
		{"who": "kaito", "text": "Send your fighters to us. We will teach them what the mountain taught us."},
	],
	"mo_dawn_intro": [
		{"who": "kaito", "text": "The King's raiders have taken the bell court, and the dawn bells are silent for the first time in four hundred years."},
		{"who": "kaito", "text": "Take it back, and hold it until the sun is up. Stand by a tower and you can ring its bell."},
	],
	"mo_dawn_outro": [
		{"who": "kaito", "text": "The dawn bells ring again. My masters will share an old form with your fighters for that."},
	],
	"fc_market_intro": [
		{"who": "coralie", "text": "Commander. You'll forgive me if I don't curtsey: the King's raiders are in the market and my people are running."},
		{"who": "coralie", "text": "Get them down the Market Road to the gate, and the Council will hear you out. One of our alchemists and a bard will help, for nothing. This once."},
		{"who": "coralie", "text": "The Merchants' Guild will pay for every wave nobody's caught, if you post their bond. And there are always sellswords. Everything here has a price."},
	],
	"fc_market_outro": [
		{"who": "coralie", "text": "You got them out. The Guild counted, of course. Then it voted, rather quickly for once."},
		{"who": "coralie", "text": "The Free Cities will stand with the Line. Our bards, our alchemists and our statues are yours. Do try to return the statues."},
		{"who": "marshal", "text": "Merchants. They'll sell you to the King the moment the price is right."},
	],
	"fc_council_intro": [
		{"who": "coralie", "text": "The Council must vote to light the beacon, and it votes in the Exchange. The King knows it, and he's sent the Warlord."},
		{"who": "coralie", "text": "Keep the Exchange standing until the vote is done. While they're at its doors, nobody inside will say a word."},
	],
	"fc_council_outro": [
		{"who": "coralie", "text": "Unanimous. I've never seen it. The beacon's lit over the harbour, and the Free Cities answer the Line."},
		{"who": "coralie", "text": "Our oldest guild secrets are yours to learn now. Send your people to us: the training is free. Almost."},
	],
	"fc_carnival_intro": [
		{"who": "coralie", "text": "Carnival Night, and the King's goblins have crept into the plaza under the lanterns. Nobody cancels Carnival."},
		{"who": "coralie", "text": "Take the plaza back and hold it till the fireworks. Away from the lanterns, watch for eyes in the dark."},
	],
	"fc_carnival_outro": [
		{"who": "coralie", "text": "Fireworks, and not a stall burned. Our bards and alchemists will show yours a trick or two for that."},
	],
	"gw_trail_intro": [
		{"who": "thorne", "text": "A wolf pack has been running our hunting trails, and the King's goblins follow it like crows."},
		{"who": "thorne", "text": "Run it down and the trails are ours again. The Watch's hunters will teach your archers what they know."},
	],
	"gw_trail_outro": [
		{"who": "thorne", "text": "The trails are quiet. The hunters have kept their word: your archers learned a trick or two today."},
	],
	"mv_wounded_intro": [
		{"who": "ilse", "text": "Commander. Every road into the vale is full of the wounded, theirs and ours alike, and the King's raiders are hunting them."},
		{"who": "ilse", "text": "Bring them to the hospice, down both flanks, through the gaps in the hedges. Sister Anwen will go with you. She can mend anyone you keep alive long enough."},
	],
	"mv_wounded_outro": [
		{"who": "ilse", "text": "You brought them home. The Sanctuary has sworn to turn no one away, and now it will not turn you away either."},
		{"who": "ilse", "text": "Our healers will walk with your troops. Keep them alive, and they will keep your line alive."},
		{"who": "marshal", "text": "Healers. The King's army does not need patching. Neither will theirs, when I am done."},
	],
	"mv_sanctuary_intro": [
		{"who": "ilse", "text": "They are coming for the hospice itself. Long waves, Commander, and archers among them to wear us down."},
		{"who": "ilse", "text": "Hold the wall until dawn and the vale's beacon will burn from the shrine's lamp."},
	],
	"mv_sanctuary_outro": [
		{"who": "ilse", "text": "Dawn, and the hospice stands. The beacon on the shrine is lit: Mercy Vale answers the Line."},
		{"who": "ilse", "text": "Our healers will share their deepest arts with yours now. No one you bring us will be lost if it can be helped."},
	],
	"dd_entrance_intro": [
		{"who": "dagna", "text": "Ha! Reinforcements! Good timing, they're at the mine entrance and the canyon road's the only way in."},
		{"who": "dagna", "text": "The guild's lending you a cannon and a gold mine, already dug. Mind the sappers: they'll bring the canyon down on us."},
	],
	"dd_entrance_outro": [
		{"who": "dagna", "text": "That's how you hold a canyon! Deepdelve's gold and Deepdelve's guns are yours, Commander."},
		{"who": "dagna", "text": "You'll get mines that dig while you fight, and cannon crews that hit like falling rock."},
		{"who": "marshal", "text": "Gold buys swords. Swords can be broken. Cut their roads to the foundries."},
	],
	"dd_orerun_intro": [
		{"who": "dagna", "text": "The foundries need ore and the roads are crawling with them. One cart, over the ridge and through the pass."},
		{"who": "dagna", "text": "Walk your troops with it. If the cart makes it, the forges light, and so does our beacon."},
	],
	"dd_orerun_outro": [
		{"who": "dagna", "text": "The ore's in, the forges are roaring and the beacon over the mine is burning. Deepdelve answers the Line!"},
		{"who": "dagna", "text": "Your miners and gun crews can learn the guild's best work now. Train them up."},
	],
	"sable_intro": [
		{"who": "hale", "text": "Sable Crossing, Commander. Two bridges and a ford, and the Marshal's whole host on the far bank."},
		{"who": "thorne", "text": "The Watch is here. Two of our best, and the sky will rain arrows when you call for it.", "if": {"ally": "greenwood"}},
		{"who": "dagna", "text": "The guild sent gold and a mine, already digging. Don't spend it all on the first bridge!", "if": {"ally": "deepdelve"}},
		{"who": "ilse", "text": "A healer walks with your line, and the Sanctuary's prayers will keep your fallen with us a little longer.", "if": {"ally": "mercyvale"}},
		{"who": "vell", "text": "My crews walled the ford overnight. They'll have to come over the bridges, or break it."},
		{"who": "marshal", "text": "You have lit a handful of fires. I have burned a hundred villages. Come, then. Hold the river.", "box": true},   # (he's on the far bank: in the box)
		{"who": "hale", "text": "No more than a dozen past us. If the crossing falls, the north never hears the beacons."},
	],
	"sable_outro": [
		{"who": "hale", "text": "The Marshal is down and his host is breaking for the north. Sable Crossing is ours!"},
		{"who": "hale", "text": "From the bridge you can see them: beacon towers on the northern hills, all dark. The road to them is open."},
		{"who": "ogre", "text": "My herald fell to a frontier commander and a handful of quarrelling peoples. Then I will come myself."},
	],
}
