extends RefCounted
## Campaign battlefields: the ground each mission is fought on. A mission names its map
## with "map" (campaign_data.gd); Classic, Freeplay and the Tutorial have none and keep
## the open meadow.
##
## Maps are drawn up on a field 640 wide (BASE_W), the enemy camp above y 96, the castle
## wall at y 736. In play a map stretches across the whole field, however wide the
## window makes it (like the open meadow): every x is a share of the width (fitted()). Each map has:
##   name       what Classic's battlefield cards call it
##   blurb      a few words for its card
##   biome      which ground painter and palette (field_art.gd): "meadow" or "mountain"
##   lanes      [x from, x to] stretches of the top edge where enemies come in
##   terrain    shapes that block walking (not flying, not shots): {"kind", "poly"} with
##              kind "rock", "cliff", "trees", "pit", "water", "ruin", "house" or "hedge" (it
##              only changes the art); and two that don't block: "ford" (shallow water,
##              waded slowly and weighed as costly by every route) and "bridge" (art only:
##              a bridge is a gap left in the water)
##   no_build   rectangles nothing may be posted or built in (barricades aside)
##   trails     paths worn into the ground through the gaps (just paint)
##   castle     the castle's style (castle.gd STYLES)
##   music      its peaceful music between waves (audio.gd STAGE_TRACKS; by default the
##              biome's: "calm" for the meadow, "mountain" for the mountains)
##   battle     its own battle music during waves (an audio.gd BATTLES style; without
##              one, the meadow's)
##   bot_posts  where the balance test's bot holds its line (the map's chokepoints)
##   camp       false: no enemy camp drawn along the top (the road just goes on)
##   tint       a colour the ground is lit with on top of the mode's mood (a dark wood)
## ZONES are fields only Battle Modes use: the stretches of road a convoy passes through
## (Convoy Escort), and the like. Maps like the rest, but never Classic battlefields.
## Terrain along the top edge reaches well above it (y -120), since enemies come in
## from just above the field.
## Any gap meant to be walked through is at least 64px wide, so a Warlord (radius 24)
## gets through with room; tests/terrain_test.gd checks every lane reaches the castle.

const BASE_W := 640.0

const MAPS := {
	# Ashwatch Keep: an open meadow with a rocky ridge across the middle, broken by two
	# gaps (about 70 and 78px). Two short lines of Swordsmen can hold them.
	"ashwatch_ridge": {
		"name": "Ashwatch Ridge", "battle": "ridge",
		"blurb": "A rocky ridge\nwith two gaps\nto hold",
		"biome": "meadow",
		"lanes": [[40, 600]],
		"terrain": [
			{"kind": "rock", "poly": [Vector2(0, 318), Vector2(70, 304), Vector2(128, 300), Vector2(184, 318), Vector2(205, 350),
				Vector2(198, 384), Vector2(150, 398), Vector2(90, 402), Vector2(30, 396), Vector2(0, 390)]},
			{"kind": "rock", "poly": [Vector2(290, 312), Vector2(330, 302), Vector2(362, 312), Vector2(374, 348),
				Vector2(360, 390), Vector2(322, 400), Vector2(286, 390), Vector2(276, 350)]},
			{"kind": "rock", "poly": [Vector2(452, 352), Vector2(478, 318), Vector2(540, 302), Vector2(600, 304), Vector2(640, 312),
				Vector2(640, 394), Vector2(580, 402), Vector2(512, 400), Vector2(462, 388)]},
			{"kind": "trees", "poly": [Vector2(0, 548), Vector2(40, 538), Vector2(72, 556), Vector2(84, 600), Vector2(64, 644),
				Vector2(24, 660), Vector2(0, 656)]},
			{"kind": "trees", "poly": [Vector2(640, 548), Vector2(600, 538), Vector2(568, 556), Vector2(556, 600), Vector2(576, 644),
				Vector2(616, 660), Vector2(640, 656)]},
		],
		"no_build": [Rect2(272, 688, 96, 48)],
		"trails": [[Vector2(150, 96), Vector2(205, 230), Vector2(240, 352), Vector2(262, 480), Vector2(300, 620), Vector2(320, 736)],
			[Vector2(500, 96), Vector2(450, 230), Vector2(412, 352), Vector2(398, 480), Vector2(342, 620), Vector2(320, 736)]],
		"castle": "keep",
		"bot_posts": [Vector2(240, 440), Vector2(205, 470), Vector2(275, 470), Vector2(412, 440), Vector2(377, 470),
			Vector2(447, 470), Vector2(320, 520), Vector2(240, 520), Vector2(412, 520)],
	},
	# Stonehollow: a mountain pass between cliffs, split by the old quarry pit into two
	# lanes about 120px wide that meet again before the gate. Barricades across the
	# lanes make Sappers blow through them.
	"stonehollow_quarry": {
		"name": "Stonehollow Quarry", "battle": "quarry",
		"blurb": "A mountain pass\nsplit by the\nquarry pit",
		"biome": "mountain",
		"lanes": [[214, 426]],
		"terrain": [
			{"kind": "cliff", "poly": [Vector2(0, -120), Vector2(204, -120), Vector2(204, 96), Vector2(188, 200), Vector2(172, 330),
				Vector2(160, 470), Vector2(150, 600), Vector2(96, 636), Vector2(0, 648)]},
			{"kind": "cliff", "poly": [Vector2(436, -120), Vector2(640, -120), Vector2(640, 648), Vector2(544, 636), Vector2(490, 600),
				Vector2(480, 470), Vector2(468, 330), Vector2(452, 200), Vector2(436, 96)]},
			{"kind": "pit", "poly": [Vector2(296, 378), Vector2(344, 378), Vector2(356, 392), Vector2(358, 512), Vector2(344, 530),
				Vector2(296, 530), Vector2(282, 512), Vector2(284, 392)]},
		],
		"no_build": [Rect2(272, 688, 96, 48)],
		"trails": [[Vector2(320, 96), Vector2(296, 260), Vector2(236, 370), Vector2(222, 470), Vector2(252, 590), Vector2(320, 736)],
			[Vector2(320, 96), Vector2(344, 260), Vector2(404, 370), Vector2(418, 470), Vector2(388, 590), Vector2(320, 736)]],
		"castle": "guildhall",
		"bot_posts": [Vector2(226, 560), Vector2(266, 590), Vector2(414, 560), Vector2(374, 590), Vector2(320, 610),
			Vector2(226, 470), Vector2(414, 470), Vector2(280, 640), Vector2(360, 640)],
	},
	# Greenwood: three narrow roads through the forest (each about 72-100px), meeting in a
	# clearing above the gate. Too many to wall off, too narrow for Swordsmen alone.
	"greenwood_roads": {
		"name": "Greenwood Roads", "battle": "greenwood",
		"blurb": "Three forest\nroads meeting\nat the gate",
		"biome": "meadow", "tint": Color(0.86, 0.96, 0.86),
		"lanes": [[122, 184], [282, 358], [462, 518]],
		"terrain": [
			{"kind": "trees", "poly": [Vector2(0, -120), Vector2(110, -120), Vector2(110, 96), Vector2(140, 250), Vector2(110, 420), Vector2(60, 560), Vector2(0, 600)]},
			{"kind": "trees", "poly": [Vector2(200, -120), Vector2(270, -120), Vector2(270, 96), Vector2(290, 220), Vector2(258, 380), Vector2(240, 480), Vector2(196, 420), Vector2(214, 260), Vector2(196, 96)]},
			{"kind": "trees", "poly": [Vector2(370, -120), Vector2(450, -120), Vector2(450, 96), Vector2(436, 260), Vector2(452, 420), Vector2(400, 480), Vector2(382, 380), Vector2(362, 220), Vector2(370, 96)]},
			{"kind": "trees", "poly": [Vector2(530, -120), Vector2(640, -120), Vector2(640, 600), Vector2(580, 560), Vector2(530, 420), Vector2(510, 260), Vector2(530, 96)]},
		],
		"no_build": [Rect2(272, 688, 96, 48)],
		"trails": [[Vector2(155, 96), Vector2(170, 260), Vector2(160, 420), Vector2(250, 560), Vector2(320, 736)], [Vector2(320, 96), Vector2(320, 300), Vector2(320, 500), Vector2(320, 736)], [Vector2(490, 96), Vector2(475, 260), Vector2(480, 420), Vector2(390, 560), Vector2(320, 736)]],
		"castle": "timberhall",
		"bot_posts": [Vector2(250, 600), Vector2(320, 580), Vector2(390, 600), Vector2(200, 640), Vector2(440, 640),
			Vector2(320, 650), Vector2(160, 560), Vector2(480, 560), Vector2(320, 520)],
	},
	# Deepdelve: a mine canyon. Cliff spurs from either side make one long road zig-zag
	# down to the gate (enemies walk about three times as far, bunching at the turns).
	"deepdelve_switchbacks": {
		"name": "Deepdelve Canyon", "battle": "deepdelve",
		"blurb": "A mine canyon\nthat zig-zags\ndown to the gate",
		"biome": "mountain",
		"lanes": [[232, 408]],
		"terrain": [
			{"kind": "cliff", "poly": [Vector2(0, -120), Vector2(222, -120), Vector2(222, 96), Vector2(212, 400), Vector2(200, 640), Vector2(0, 640)]},
			{"kind": "cliff", "poly": [Vector2(418, -120), Vector2(640, -120), Vector2(640, 640), Vector2(440, 640), Vector2(428, 400), Vector2(418, 96)]},
			{"kind": "cliff", "poly": [Vector2(210, 226), Vector2(346, 246), Vector2(346, 292), Vector2(210, 302)]},
			{"kind": "cliff", "poly": [Vector2(430, 396), Vector2(292, 416), Vector2(292, 462), Vector2(430, 472)]},
			{"kind": "rock", "poly": [Vector2(210, 560), Vector2(250, 556), Vector2(256, 600), Vector2(210, 604)]},
		],
		"no_build": [Rect2(272, 688, 96, 48)],
		"trails": [[Vector2(320, 96), Vector2(330, 180), Vector2(390, 215), Vector2(390, 270), Vector2(330, 330), Vector2(250, 370), Vector2(245, 430), Vector2(300, 500), Vector2(310, 620), Vector2(320, 736)]],
		"castle": "guildgate",
		"bot_posts": [Vector2(320, 560), Vector2(270, 600), Vector2(370, 600), Vector2(320, 640), Vector2(380, 520),
			Vector2(260, 520), Vector2(300, 360), Vector2(380, 340), Vector2(320, 680)],
	},
	# Mercy Vale: farmland broken by hedgerows with gaps, enemies down both flanks, and the
	# shrine in the middle (nothing can be built on it or by it).
	"mercy_fields": {
		"name": "Mercy Vale Fields", "battle": "mercy",
		"blurb": "Hedged fields\nand the shrine\nbetween them",
		"biome": "meadow",
		"lanes": [[40, 200], [440, 600]],
		"terrain": [
			{"kind": "hedge", "poly": [Vector2(0, 250), Vector2(180, 250), Vector2(180, 272), Vector2(0, 272)]},
			{"kind": "hedge", "poly": [Vector2(250, 250), Vector2(390, 250), Vector2(390, 272), Vector2(250, 272)]},
			{"kind": "hedge", "poly": [Vector2(460, 250), Vector2(640, 250), Vector2(640, 272), Vector2(460, 272)]},
			{"kind": "hedge", "poly": [Vector2(80, 430), Vector2(260, 430), Vector2(260, 452), Vector2(80, 452)]},
			{"kind": "hedge", "poly": [Vector2(380, 430), Vector2(560, 430), Vector2(560, 452), Vector2(380, 452)]},
			{"kind": "shrine", "poly": [Vector2(285, 400), Vector2(355, 400), Vector2(355, 480), Vector2(285, 480)]},
		],
		"no_build": [Rect2(260, 380, 120, 120), Rect2(272, 688, 96, 48)],
		"trails": [[Vector2(120, 96), Vector2(200, 200), Vector2(215, 300), Vector2(120, 380), Vector2(40, 470), Vector2(140, 600), Vector2(320, 736)], [Vector2(520, 96), Vector2(440, 200), Vector2(425, 300), Vector2(520, 380), Vector2(600, 470), Vector2(500, 600), Vector2(320, 736)]],
		"castle": "hospice",
		"bot_posts": [Vector2(215, 330), Vector2(425, 330), Vector2(40, 470), Vector2(600, 470), Vector2(200, 560),
			Vector2(440, 560), Vector2(320, 600), Vector2(260, 640), Vector2(380, 640)],
	},
	# Sable Crossing: a river across the field, two bridges (80px, room for the Marshal) and
	# a shallow ford between them that slows anyone wading it.
	"sable_crossing": {
		"name": "Sable Crossing", "battle": "sable",
		"blurb": "A river, two\nbridges and\na ford",
		"biome": "meadow",
		"lanes": [[40, 600]],
		"terrain": [
			{"kind": "water", "poly": [Vector2(0, 330), Vector2(60, 326), Vector2(110, 332), Vector2(110, 420), Vector2(60, 424), Vector2(0, 420)]},
			{"kind": "bridge", "poly": [Vector2(110, 326), Vector2(190, 326), Vector2(190, 426), Vector2(110, 426)]},
			{"kind": "water", "poly": [Vector2(190, 334), Vector2(240, 338), Vector2(285, 344), Vector2(285, 422), Vector2(240, 420), Vector2(190, 424)]},
			{"kind": "ford", "poly": [Vector2(285, 344), Vector2(365, 344), Vector2(365, 422), Vector2(285, 422)]},
			{"kind": "water", "poly": [Vector2(365, 344), Vector2(410, 340), Vector2(440, 334), Vector2(440, 416), Vector2(410, 420), Vector2(365, 422)]},
			{"kind": "bridge", "poly": [Vector2(440, 324), Vector2(520, 324), Vector2(520, 424), Vector2(440, 424)]},
			{"kind": "water", "poly": [Vector2(520, 334), Vector2(580, 328), Vector2(640, 322), Vector2(640, 410), Vector2(580, 414), Vector2(520, 416)]},
		],
		"no_build": [Rect2(272, 688, 96, 48)],
		"trails": [[Vector2(150, 96), Vector2(150, 250), Vector2(150, 420), Vector2(200, 560), Vector2(320, 736)], [Vector2(480, 96), Vector2(480, 250), Vector2(480, 420), Vector2(430, 560), Vector2(320, 736)], [Vector2(325, 96), Vector2(325, 260), Vector2(325, 420), Vector2(322, 600), Vector2(320, 736)]],
		"castle": "fort",
		"bot_posts": [Vector2(150, 450), Vector2(480, 450), Vector2(325, 450), Vector2(110, 470), Vector2(190, 470),
			Vector2(440, 470), Vector2(520, 470), Vector2(325, 520), Vector2(320, 620)],
	},
}


## The stretches of road a convoy travels, one after another: the wagon comes in at the
## bottom and leaves at the treeline along the top (its "route" ends there, short of the
## enemy's way in), and the field turns into the next.
const ZONES := {
	# Open farmland: a few copses, the road winding up the middle.
	"convoy_meadow": {
		"name": "The Meadow Road", "battle": "road", "biome": "meadow", "camp": false,
		"lanes": [[40, 600]],
		"terrain": [
			{"kind": "trees", "poly": [Vector2(0, 180), Vector2(60, 170), Vector2(96, 200), Vector2(100, 250), Vector2(70, 290),
				Vector2(20, 300), Vector2(0, 296)]},
			{"kind": "trees", "poly": [Vector2(640, 430), Vector2(590, 420), Vector2(552, 446), Vector2(548, 500), Vector2(580, 536),
				Vector2(630, 540), Vector2(640, 538)]},
			{"kind": "rock", "poly": [Vector2(470, 210), Vector2(500, 196), Vector2(530, 204), Vector2(540, 232), Vector2(520, 256),
				Vector2(486, 258), Vector2(466, 238)]},
		],
		"no_build": [],
		"trails": [[Vector2(320, 740), Vector2(300, 600), Vector2(250, 470), Vector2(290, 330), Vector2(360, 200), Vector2(330, 60), Vector2(320, -20)]],
		"route": [Vector2(320, 760), Vector2(300, 600), Vector2(250, 470), Vector2(290, 330), Vector2(360, 200), Vector2(330, 104)],
	},
	# A dark pinewood: thick trees close in on both sides, the road through a long clearing.
	"convoy_forest": {
		"name": "The Darkwood", "battle": "darkwood", "biome": "meadow", "camp": false, "tint": Color(0.78, 0.9, 0.8),
		"lanes": [[186, 462]],
		"terrain": [
			{"kind": "trees", "poly": [Vector2(0, -120), Vector2(160, -120), Vector2(170, 60), Vector2(150, 200), Vector2(120, 260),
				Vector2(140, 380), Vector2(110, 470), Vector2(130, 600), Vector2(100, 760), Vector2(0, 760)]},
			{"kind": "trees", "poly": [Vector2(480, -120), Vector2(640, -120), Vector2(640, 760), Vector2(540, 760), Vector2(510, 640),
				Vector2(530, 520), Vector2(500, 400), Vector2(520, 280), Vector2(490, 150), Vector2(470, 60)]},
			{"kind": "trees", "poly": [Vector2(330, 360), Vector2(370, 350), Vector2(400, 372), Vector2(398, 410), Vector2(364, 428),
				Vector2(330, 418), Vector2(318, 390)]},
		],
		"no_build": [],
		"trails": [[Vector2(320, 740), Vector2(330, 600), Vector2(270, 470), Vector2(280, 330), Vector2(330, 200), Vector2(320, 60), Vector2(320, -20)]],
		"route": [Vector2(320, 760), Vector2(330, 600), Vector2(270, 470), Vector2(280, 330), Vector2(330, 200), Vector2(322, 104)],
	},
	# A farming village up at the top of the field, its two roads running down to safety
	# (the Village Road's evacuation: the villagers set out from the cottages).
	"village_fields": {
		"name": "The Village Fields", "battle": "village", "biome": "meadow",
		"lanes": [[200, 440], [30, 90], [550, 610]],
		"terrain": [
			{"kind": "house", "poly": [Vector2(28, 168), Vector2(92, 168), Vector2(92, 228), Vector2(28, 228)]},
			{"kind": "house", "poly": [Vector2(120, 150), Vector2(176, 150), Vector2(176, 204), Vector2(120, 204)]},
			{"kind": "house", "poly": [Vector2(464, 150), Vector2(520, 150), Vector2(520, 204), Vector2(464, 204)]},
			{"kind": "house", "poly": [Vector2(548, 168), Vector2(612, 168), Vector2(612, 228), Vector2(548, 228)]},
		],
		"no_build": [],
		"trails": [[Vector2(110, 230), Vector2(170, 420), Vector2(270, 580), Vector2(320, 736)],
			[Vector2(530, 230), Vector2(470, 420), Vector2(370, 580), Vector2(320, 736)],
			[Vector2(320, 96), Vector2(320, 300)]],
	},
	# The high pass: bare rock, cliffs either side, the road climbing to the far end.
	"convoy_pass": {
		"name": "The High Pass", "battle": "highpass", "biome": "mountain", "camp": false, "tint": Color(1.0, 0.94, 0.9),
		"lanes": [[214, 434]],
		"terrain": [
			{"kind": "cliff", "poly": [Vector2(0, -120), Vector2(190, -120), Vector2(196, 80), Vector2(170, 220), Vector2(184, 360),
				Vector2(150, 520), Vector2(120, 760), Vector2(0, 760)]},
			{"kind": "cliff", "poly": [Vector2(450, -120), Vector2(640, -120), Vector2(640, 760), Vector2(520, 760), Vector2(490, 560),
				Vector2(470, 400), Vector2(486, 240), Vector2(444, 80)]},
		],
		"no_build": [],
		"trails": [[Vector2(320, 740), Vector2(350, 600), Vector2(300, 470), Vector2(330, 330), Vector2(300, 200), Vector2(320, 60), Vector2(320, -20)]],
		"route": [Vector2(320, 760), Vector2(350, 600), Vector2(300, 470), Vector2(330, 330), Vector2(300, 200), Vector2(316, 104)],
	},
	# A river across the road, crossed at the old ford in the middle; reeds along the banks.
	"convoy_ford": {
		"name": "The Old Ford", "battle": "ford", "biome": "meadow", "camp": false,
		"lanes": [[40, 600]],
		"terrain": [
			{"kind": "water", "poly": [Vector2(0, 372), Vector2(90, 380), Vector2(180, 368), Vector2(262, 384), Vector2(272, 420),
				Vector2(258, 452), Vector2(170, 446), Vector2(80, 458), Vector2(0, 450)]},
			{"kind": "water", "poly": [Vector2(378, 386), Vector2(460, 370), Vector2(560, 382), Vector2(640, 376), Vector2(640, 454),
				Vector2(560, 462), Vector2(470, 448), Vector2(384, 450), Vector2(372, 420)]},
			{"kind": "trees", "poly": [Vector2(520, 600), Vector2(570, 580), Vector2(620, 596), Vector2(640, 640), Vector2(640, 700),
				Vector2(580, 706), Vector2(530, 680)]},
			{"kind": "rock", "poly": [Vector2(90, 200), Vector2(130, 186), Vector2(160, 206), Vector2(150, 240), Vector2(110, 246),
				Vector2(84, 228)]},
		],
		"no_build": [],
		"trails": [[Vector2(320, 740), Vector2(300, 600), Vector2(320, 420), Vector2(350, 280), Vector2(325, 140), Vector2(320, -20)]],
		"route": [Vector2(320, 760), Vector2(300, 600), Vector2(320, 420), Vector2(350, 280), Vector2(325, 104)],
	},
	# Marshland: the road picks its way between pools, under a grey-green light.
	"convoy_fens": {
		"name": "The Fens", "battle": "fens", "biome": "meadow", "camp": false, "tint": Color(0.86, 0.95, 0.88),
		"lanes": [[40, 600]],
		"terrain": [
			{"kind": "water", "poly": [Vector2(30, 230), Vector2(110, 214), Vector2(190, 236), Vector2(196, 290), Vector2(140, 318),
				Vector2(60, 312), Vector2(24, 276)]},
			{"kind": "water", "poly": [Vector2(430, 170), Vector2(500, 160), Vector2(560, 180), Vector2(566, 226), Vector2(510, 246),
				Vector2(440, 236)]},
			{"kind": "water", "poly": [Vector2(450, 520), Vector2(530, 500), Vector2(610, 520), Vector2(616, 580), Vector2(540, 604),
				Vector2(460, 590)]},
			{"kind": "water", "poly": [Vector2(90, 540), Vector2(170, 530), Vector2(220, 560), Vector2(200, 610), Vector2(120, 620),
				Vector2(80, 590)]},
			{"kind": "water", "poly": [Vector2(290, 330), Vector2(340, 322), Vector2(370, 346), Vector2(352, 380), Vector2(304, 382),
				Vector2(282, 356)]},
		],
		"no_build": [],
		"trails": [[Vector2(320, 740), Vector2(320, 620), Vector2(380, 480), Vector2(430, 380), Vector2(380, 260), Vector2(325, 140), Vector2(320, -20)]],
		"route": [Vector2(320, 760), Vector2(320, 620), Vector2(380, 480), Vector2(430, 380), Vector2(380, 260), Vector2(325, 104)],
	},
	# A village the enemy got to first: burnt-out cottages either side of the street.
	"convoy_village": {
		"name": "The Burnt Village", "battle": "embers", "biome": "meadow", "camp": false, "tint": Color(1.0, 0.9, 0.84),
		"lanes": [[40, 600]],
		"terrain": [
			{"kind": "ruin", "poly": [Vector2(60, 180), Vector2(150, 180), Vector2(150, 250), Vector2(60, 250)]},
			{"kind": "ruin", "poly": [Vector2(470, 250), Vector2(570, 250), Vector2(570, 320), Vector2(470, 320)]},
			{"kind": "ruin", "poly": [Vector2(130, 430), Vector2(220, 430), Vector2(220, 500), Vector2(130, 500)]},
			{"kind": "ruin", "poly": [Vector2(420, 520), Vector2(520, 520), Vector2(520, 590), Vector2(420, 590)]},
			{"kind": "ruin", "poly": [Vector2(236, 290), Vector2(306, 290), Vector2(306, 344), Vector2(236, 344)]},
			{"kind": "trees", "poly": [Vector2(0, 600), Vector2(50, 590), Vector2(90, 620), Vector2(80, 680), Vector2(30, 700), Vector2(0, 696)]},
		],
		"no_build": [],
		"trails": [[Vector2(320, 740), Vector2(330, 620), Vector2(320, 470), Vector2(380, 380), Vector2(360, 240), Vector2(325, 140), Vector2(320, -20)]],
		"route": [Vector2(320, 760), Vector2(330, 620), Vector2(320, 470), Vector2(380, 380), Vector2(360, 240), Vector2(325, 104)],
	},
	# A wide ridge of grey rock, boulders strewn across the road.
	"convoy_ridge": {
		"name": "Ashen Ridge", "battle": "ashen", "biome": "mountain", "camp": false, "tint": Color(0.94, 0.92, 0.94),
		"lanes": [[130, 510]],
		"terrain": [
			{"kind": "cliff", "poly": [Vector2(0, -120), Vector2(116, -120), Vector2(124, 120), Vector2(94, 300), Vector2(112, 480),
				Vector2(76, 760), Vector2(0, 760)]},
			{"kind": "cliff", "poly": [Vector2(526, -120), Vector2(640, -120), Vector2(640, 760), Vector2(570, 760), Vector2(540, 560),
				Vector2(560, 380), Vector2(520, 200)]},
			{"kind": "rock", "poly": [Vector2(200, 220), Vector2(250, 206), Vector2(280, 230), Vector2(270, 270), Vector2(220, 276),
				Vector2(196, 250)]},
			{"kind": "rock", "poly": [Vector2(380, 400), Vector2(430, 390), Vector2(460, 416), Vector2(450, 452), Vector2(400, 460),
				Vector2(376, 432)]},
			{"kind": "rock", "poly": [Vector2(190, 560), Vector2(240, 548), Vector2(266, 574), Vector2(250, 610), Vector2(206, 612),
				Vector2(184, 586)]},
		],
		"no_build": [],
		"trails": [[Vector2(320, 740), Vector2(330, 620), Vector2(300, 480), Vector2(330, 330), Vector2(340, 200), Vector2(322, 140), Vector2(320, -20)]],
		"route": [Vector2(320, 760), Vector2(330, 620), Vector2(300, 480), Vector2(330, 330), Vector2(340, 200), Vector2(322, 104)],
	},
}


static func get_map(id: String) -> Dictionary:
	return MAPS.get(id, ZONES.get(id, {}))


## Map `m` stretched across a field `w` wide: every x (terrain, lanes, trails, no-build
## zones, the bot's posts) scaled by w / BASE_W; heights stay as they are.
static func fitted(m: Dictionary, w: float) -> Dictionary:
	if m.is_empty() or is_equal_approx(w, BASE_W):
		return m
	var k := w / BASE_W
	var out := m.duplicate(true)
	var sx := func(p: Vector2) -> Vector2: return Vector2(p.x * k, p.y)
	for t in out.get("terrain", []):
		t["poly"] = (t["poly"] as Array).map(sx)
	out["lanes"] = out.get("lanes", []).map(func(l): return [l[0] * k, l[1] * k])
	out["trails"] = out.get("trails", []).map(func(tr): return (tr as Array).map(sx))
	out["no_build"] = out.get("no_build", []).map(func(r: Rect2): return Rect2(r.position.x * k, r.position.y, r.size.x * k, r.size.y))
	out["bot_posts"] = out.get("bot_posts", []).map(sx)
	if out.has("route"):
		out["route"] = (out["route"] as Array).map(sx)
	return out
