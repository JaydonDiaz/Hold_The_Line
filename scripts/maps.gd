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
##   biome      which ground painter and palette (field_art.gd): "meadow", "mountain", "snow",
##              "city", or "void" (floating islands: see islands)
##   lanes      [x from, x to] stretches of the top edge where enemies come in
##   terrain    shapes that block walking (not flying, not shots): {"kind", "poly"} with
##              kind "rock", "cliff", "trees", "pit", "water", "ruin", "house", "hedge",
##              "building", "canal", "fountain" or "stall" (it
##              only changes the art); and two that don't block: "ford" (shallow water,
##              waded slowly and weighed as costly by every route) and "bridge" (art only:
##              a bridge is a gap left in the water)
##   no_build   rectangles nothing may be posted or built in (barricades aside)
##   trails     paths worn into the ground through the gaps (just paint)
##   castle     the castle's style (castle.gd STYLES)
##   music      its peaceful music between waves: its own (audio.gd: "calm_<style>" from
##              CALMS, or a piece by hand: "mountain", "forest", "river", "snow", "city");
##              without one, the biome's ("calm" for the meadow, "mountain" for the mountains)
##   battle     its own battle music during waves (an audio.gd BATTLES style; without
##              one, the meadow's)
##   bot_posts  where the balance test's bot holds its line (the map's chokepoints)
##   camp       false: no enemy camp drawn along the top (the road just goes on)
##   ground     a mood laid over the biome's ground (field_art._ground_mood): "fen", "burnt", "ash",
##              "war" (Dawnspire's fields fought over: war_art.gd)
##   tint       a colour the ground is lit with on top of the mode's mood (a dark wood)
##   wall       a Dawnspire field's wall across the top: "outer", "inner" or "citadel" (its look)
##   decor      little things about the field, just paint ({"kind", "at"} or a "rect"):
##              "plaza" (a dressed-stone square, its mosaic at "at", "r" across), "planter", "boat" (moored in a canal),
##              "lamp" (a street lamp), "crates"
##   lanterns   lantern posts stood about the field (just paint, lit; a night mission hangs
##              its own, which light up the dark)
##   islands    floating islands ({"at", "r", "path": the sigil's art on it, or -1}), joined
##              by "bridges" ({"from", "to", "w", "path": the colour they glow}) and "lands"
##              (rectangles: the camp's ground, the castle's); the rest is the void, which
##              nothing walks on (worked out by fitted())
##   conduits   the Arcane Spires' rune circles ({"at", "path"}: conduits.gd), lending
##              their power to Mages standing on them
##   bells      free-standing bell towers (bells.gd) in any battle on the map whose mission
##              has no bells of its own (Classic, Battle Modes)
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
		"name": "Ashwatch Ridge", "battle": "ridge", "music": "calm_ashwatch",
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
	# Stonehollow: a mountain pass between low cliffs, split by a great rock formation (the
	# quarry's spoil heaped up) into two lanes about 130-150px wide that meet again before
	# the gate. Barricades across the lanes make Sappers blow through them.
	"stonehollow_quarry": {
		"name": "Stonehollow Quarry", "battle": "quarry",
		"blurb": "A mountain pass\nsplit by a\ngreat rock",
		"biome": "mountain",
		"lanes": [[160, 480]],
		"terrain": [
			{"kind": "cliff", "poly": [Vector2(0, -120), Vector2(150, -120), Vector2(150, 96), Vector2(138, 200), Vector2(126, 330),
				Vector2(116, 470), Vector2(110, 600), Vector2(70, 636), Vector2(0, 648)]},
			{"kind": "cliff", "poly": [Vector2(490, -120), Vector2(640, -120), Vector2(640, 648), Vector2(570, 636), Vector2(530, 600),
				Vector2(524, 470), Vector2(514, 330), Vector2(502, 200), Vector2(490, 96)]},
			{"kind": "rock", "poly": [Vector2(304, 236), Vector2(340, 230), Vector2(370, 258), Vector2(386, 320), Vector2(388, 400),
				Vector2(372, 470), Vector2(352, 512), Vector2(320, 524), Vector2(288, 512), Vector2(268, 470), Vector2(252, 400),
				Vector2(254, 320), Vector2(270, 258)]},
		],
		"no_build": [Rect2(272, 688, 96, 48)],
		"trails": [[Vector2(320, 96), Vector2(290, 190), Vector2(200, 290), Vector2(186, 420), Vector2(214, 560), Vector2(320, 736)],
			[Vector2(320, 96), Vector2(350, 190), Vector2(440, 290), Vector2(454, 420), Vector2(426, 560), Vector2(320, 736)]],
		"castle": "guildhall",
		"bot_posts": [Vector2(165, 440), Vector2(225, 440), Vector2(415, 440), Vector2(475, 440), Vector2(320, 600),
			Vector2(195, 500), Vector2(445, 500), Vector2(280, 640), Vector2(360, 640)],
	},
	# Greenwood: three forest roads (each about 120-135px), between thin belts of trees on
	# the flanks and two narrow stands between the roads, meeting in a clearing above the
	# gate. Too many to wall off, too wide for a lone Swordsman.
	"greenwood_roads": {
		"name": "Greenwood Roads", "battle": "greenwood", "music": "forest",
		"blurb": "Three forest\nroads meeting\nat the gate",
		"biome": "meadow", "tint": Color(0.86, 0.96, 0.86),
		"lanes": [[92, 196], [268, 372], [444, 548]],
		"terrain": [
			{"kind": "trees", "poly": [Vector2(0, -120), Vector2(80, -120), Vector2(80, 96), Vector2(96, 250), Vector2(80, 420), Vector2(40, 560), Vector2(0, 600)]},
			{"kind": "trees", "poly": [Vector2(210, -120), Vector2(256, -120), Vector2(256, 96), Vector2(262, 220), Vector2(252, 380), Vector2(240, 480), Vector2(212, 420), Vector2(220, 260), Vector2(206, 96)]},
			{"kind": "trees", "poly": [Vector2(384, -120), Vector2(430, -120), Vector2(434, 96), Vector2(420, 260), Vector2(428, 420), Vector2(400, 480), Vector2(388, 380), Vector2(378, 220), Vector2(384, 96)]},
			{"kind": "trees", "poly": [Vector2(560, -120), Vector2(640, -120), Vector2(640, 600), Vector2(600, 560), Vector2(560, 420), Vector2(544, 250), Vector2(560, 96)]},
		],
		"no_build": [Rect2(272, 688, 96, 48)],
		"trails": [[Vector2(155, 96), Vector2(170, 260), Vector2(160, 420), Vector2(250, 560), Vector2(320, 736)], [Vector2(320, 96), Vector2(320, 300), Vector2(320, 500), Vector2(320, 736)], [Vector2(490, 96), Vector2(475, 260), Vector2(480, 420), Vector2(390, 560), Vector2(320, 736)]],
		"castle": "timberhall",
		"bot_posts": [Vector2(250, 600), Vector2(320, 580), Vector2(390, 600), Vector2(200, 640), Vector2(440, 640),
			Vector2(320, 650), Vector2(160, 560), Vector2(480, 560), Vector2(320, 520)],
	},
	# Deepdelve: a mine canyon. Three cliff spurs from alternate sides make one long road
	# zig-zag down to the gate (enemies walk about four times as far, bunching at the
	# turns); the last, nearest the castle, sends everything round by the right.
	"deepdelve_switchbacks": {
		"name": "Deepdelve Canyon", "battle": "deepdelve", "music": "calm_deepdelve",
		"blurb": "A mine canyon\nthat zig-zags\ndown to the gate",
		"biome": "mountain",
		"lanes": [[172, 468]],
		"terrain": [
			{"kind": "cliff", "poly": [Vector2(0, -120), Vector2(160, -120), Vector2(160, 96), Vector2(152, 400), Vector2(144, 640), Vector2(0, 640)]},
			{"kind": "cliff", "poly": [Vector2(480, -120), Vector2(640, -120), Vector2(640, 640), Vector2(496, 640), Vector2(488, 400), Vector2(480, 96)]},
			{"kind": "cliff", "poly": [Vector2(150, 210), Vector2(380, 226), Vector2(380, 270), Vector2(150, 282)]},
			{"kind": "cliff", "poly": [Vector2(490, 360), Vector2(260, 376), Vector2(260, 420), Vector2(490, 432)]},
			{"kind": "cliff", "poly": [Vector2(146, 506), Vector2(380, 520), Vector2(380, 558), Vector2(146, 568)]},
		],
		"no_build": [Rect2(272, 688, 96, 48)],
		"trails": [[Vector2(320, 96), Vector2(330, 160), Vector2(420, 195), Vector2(430, 260), Vector2(360, 315), Vector2(230, 335),
			Vector2(205, 400), Vector2(240, 465), Vector2(400, 480), Vector2(436, 540), Vector2(400, 610), Vector2(320, 736)]],
		"castle": "guildgate",
		"bot_posts": [Vector2(436, 590), Vector2(390, 620), Vector2(320, 640), Vector2(260, 650), Vector2(436, 470),
			Vector2(300, 470), Vector2(230, 320), Vector2(400, 320), Vector2(320, 680)],
	},
	# Mercy Vale: farmland broken by hedgerows with gaps, enemies down both flanks, and the
	# shrine in the middle (nothing can be built on it or by it).
	"mercy_fields": {
		"name": "Mercy Vale Fields", "battle": "mercy", "music": "calm_mercy",
		"blurb": "Hedged fields\nand the shrine\nbetween them",
		"biome": "meadow",
		"lanes": [[40, 200], [440, 600]],
		"terrain": [
			{"kind": "hedge", "poly": [Vector2(159, 250), Vector2(167, 253), Vector2(170, 261), Vector2(167, 269), Vector2(159, 272), Vector2(0, 272), Vector2(0, 250)]},
			{"kind": "hedge", "poly": [Vector2(369, 250), Vector2(377, 253), Vector2(380, 261), Vector2(377, 269), Vector2(369, 272), Vector2(271, 272), Vector2(263, 269), Vector2(260, 261), Vector2(263, 253), Vector2(271, 250)]},
			{"kind": "hedge", "poly": [Vector2(640, 250), Vector2(640, 272), Vector2(481, 272), Vector2(473, 269), Vector2(470, 261), Vector2(473, 253), Vector2(481, 250)]},
			{"kind": "hedge", "poly": [Vector2(249, 430), Vector2(257, 433), Vector2(260, 441), Vector2(257, 449), Vector2(249, 452), Vector2(107, 452), Vector2(99, 449), Vector2(96, 441), Vector2(99, 433), Vector2(107, 430)]},
			{"kind": "hedge", "poly": [Vector2(533, 430), Vector2(541, 433), Vector2(544, 441), Vector2(541, 449), Vector2(533, 452), Vector2(391, 452), Vector2(383, 449), Vector2(380, 441), Vector2(383, 433), Vector2(391, 430)]},
			{"kind": "shrine", "poly": [Vector2(285, 400), Vector2(355, 400), Vector2(355, 480), Vector2(285, 480)]},
		],
		"no_build": [Rect2(260, 380, 120, 120), Rect2(272, 688, 96, 48)],
		"trails": [[Vector2(120, 96), Vector2(200, 200), Vector2(215, 300), Vector2(120, 380), Vector2(40, 470), Vector2(140, 600), Vector2(320, 736)], [Vector2(520, 96), Vector2(440, 200), Vector2(425, 300), Vector2(520, 380), Vector2(600, 470), Vector2(500, 600), Vector2(320, 736)]],
		"castle": "hospice",
		"bot_posts": [Vector2(215, 330), Vector2(425, 330), Vector2(40, 470), Vector2(600, 470), Vector2(200, 560),
			Vector2(440, 560), Vector2(320, 600), Vector2(260, 640), Vector2(380, 640)],
	},
	# --- The North (Phase 4) ---------------------------------------------------------------
	# Frostmarch, the Frozen Pass: open snowfield, a rock splitting the way in, and a frozen
	# lake right across the field: solid in the middle (170px) and thin ice out to either
	# edge. A Troll that strays onto the thin ice takes it down with it, and then only the
	# middle is left to cross.
	"frostmarch_pass": {
		"name": "The Frozen Pass", "battle": "frostpass", "music": "snow",
		"blurb": "A frozen lake\nright across\nthe pass",
		"biome": "snow",
		"lanes": [[60, 580]],
		"terrain": [
			{"kind": "rock", "poly": [Vector2(292, 196), Vector2(330, 186), Vector2(352, 204), Vector2(348, 236), Vector2(318, 248),
				Vector2(290, 232)]},
			{"kind": "ice", "poly": [Vector2(0, 322), Vector2(160, 314), Vector2(480, 314), Vector2(640, 322), Vector2(640, 466),
				Vector2(480, 474), Vector2(160, 474), Vector2(0, 466)]},
			{"kind": "thin_ice", "poly": [Vector2(0, 334), Vector2(235, 328), Vector2(235, 462), Vector2(0, 456)]},
			{"kind": "thin_ice", "poly": [Vector2(405, 328), Vector2(640, 334), Vector2(640, 456), Vector2(405, 462)]},
		],
		"no_build": [Rect2(272, 688, 96, 48)],
		# Two roads down from the camp, one each side of the rock, each to its side of the
		# solid ice (they never meet), and one road on from the far shore to the gate.
		"trails": [[Vector2(170, 96), Vector2(176, 160), Vector2(206, 226), Vector2(244, 278), Vector2(266, 330)],
			[Vector2(470, 96), Vector2(464, 160), Vector2(434, 226), Vector2(396, 278), Vector2(374, 330)],
			[Vector2(320, 466), Vector2(316, 600), Vector2(320, 736)]],
		"castle": "frostkeep",
		"bot_posts": [Vector2(320, 500), Vector2(260, 540), Vector2(380, 540), Vector2(320, 600), Vector2(250, 600),
			Vector2(390, 600), Vector2(320, 650)],
	},
	# Frostmarch, the Stone Lake (the Covenant's Vigil): a snowfield of frozen ponds and
	# crags, and the two roads from the camp run straight across the ponds: the west road
	# over the west pond to the West Stone, the east road over the east pond to the East
	# Stone, and the way straight down over the great lake, past the Lake Stone out on it
	# (on a band of solid ice right across, thin ice north and south of it). Each pond is
	# thin ice ringed by solid: break it and everyone has to go round. Every stone stays
	# reachable with all the thin ice gone, and every way round is at least 64px wide.
	"frostmarch_lake": {
		"name": "The Stone Lake", "battle": "frostlake", "music": "calm_lake",
		"blurb": "Frozen ponds\nacross the roads\nto the stones",
		"biome": "snow",
		"lanes": [[40, 600]],
		"terrain": [
			# The west pond, across the west road.
			{"kind": "ice", "poly": [Vector2(84, 186), Vector2(236, 176), Vector2(300, 226), Vector2(290, 312), Vector2(196, 338),
				Vector2(96, 318), Vector2(64, 254)]},
			{"kind": "thin_ice", "poly": [Vector2(112, 204), Vector2(222, 198), Vector2(266, 238), Vector2(258, 296), Vector2(190, 316),
				Vector2(116, 302), Vector2(94, 256)]},
			# The east pond, across the east road.
			{"kind": "ice", "poly": [Vector2(372, 252), Vector2(470, 236), Vector2(574, 262), Vector2(596, 330), Vector2(552, 396),
				Vector2(440, 404), Vector2(380, 360)]},
			{"kind": "thin_ice", "poly": [Vector2(400, 272), Vector2(470, 258), Vector2(552, 280), Vector2(566, 330), Vector2(532, 374),
				Vector2(444, 380), Vector2(406, 344)]},
			# The great lake, the Lake Stone out on its band of solid ice.
			{"kind": "ice", "poly": [Vector2(214, 404), Vector2(366, 398), Vector2(442, 440), Vector2(452, 500), Vector2(424, 588),
				Vector2(320, 610), Vector2(220, 590), Vector2(190, 500)]},
			{"kind": "thin_ice", "poly": [Vector2(236, 414), Vector2(362, 410), Vector2(376, 456), Vector2(226, 456)]},
			{"kind": "thin_ice", "poly": [Vector2(222, 518), Vector2(420, 518), Vector2(404, 576), Vector2(320, 594), Vector2(236, 578)]},
			# Crags: the north one between the roads, a cliff in the north-east corner, one on
			# the west shore, and two low ones by the castle.
			{"kind": "rock", "poly": [Vector2(304, 128), Vector2(340, 120), Vector2(362, 140), Vector2(356, 174), Vector2(322, 184),
				Vector2(298, 164)]},
			{"kind": "cliff", "poly": [Vector2(508, 118), Vector2(584, 106), Vector2(640, 130), Vector2(640, 196), Vector2(556, 210),
				Vector2(512, 176)]},
			{"kind": "rock", "poly": [Vector2(0, 392), Vector2(48, 386), Vector2(84, 410), Vector2(72, 452), Vector2(30, 462),
				Vector2(0, 456)]},
			{"kind": "rock", "poly": [Vector2(570, 554), Vector2(610, 546), Vector2(640, 560), Vector2(640, 610), Vector2(590, 614)]},
			{"kind": "rock", "poly": [Vector2(0, 560), Vector2(50, 546), Vector2(70, 580), Vector2(46, 614), Vector2(0, 610)]},
		],
		"no_build": [Rect2(272, 688, 96, 48)],
		"trails": [[Vector2(232, 96), Vector2(216, 160), Vector2(186, 250), Vector2(162, 350), Vector2(146, 450), Vector2(140, 520),
				Vector2(176, 620), Vector2(254, 690), Vector2(320, 736)],
			[Vector2(410, 96), Vector2(432, 170), Vector2(464, 300), Vector2(488, 420), Vector2(500, 520), Vector2(462, 620),
				Vector2(384, 690), Vector2(320, 736)]],
		"castle": "frostkeep",
		"bot_posts": [Vector2(140, 470), Vector2(320, 640), Vector2(500, 470), Vector2(210, 640), Vector2(430, 640),
			Vector2(170, 368), Vector2(476, 432)],
	},
	# The High Monastery, the Thousand Steps: four terraces down the mountain, each ledge
	# crossed by stairs (and, on the middle one, a rope bridge over a chasm in the centre).
	# The Fighting Retreat's lines hold just below each ledge, where the enemy has to come
	# down the stairs; the camp is at the foot.
	"monastery_steps": {
		"name": "The Thousand Steps", "battle": "steps", "music": "calm_steps",
		"blurb": "Terraces and\nstairs down the\nmountain",
		"biome": "mountain",
		"lanes": [[40, 600]],
		"terrain": [
			{"kind": "cliff", "poly": [Vector2(0, 250), Vector2(196, 250), Vector2(196, 282), Vector2(0, 282)]},
			{"kind": "stairs", "poly": [Vector2(196, 246), Vector2(286, 246), Vector2(286, 286), Vector2(196, 286)]},
			{"kind": "cliff", "poly": [Vector2(286, 250), Vector2(354, 250), Vector2(354, 282), Vector2(286, 282)]},
			{"kind": "stairs", "poly": [Vector2(354, 246), Vector2(444, 246), Vector2(444, 286), Vector2(354, 286)]},
			{"kind": "cliff", "poly": [Vector2(444, 250), Vector2(640, 250), Vector2(640, 282), Vector2(444, 282)]},
			{"kind": "cliff", "poly": [Vector2(0, 392), Vector2(104, 392), Vector2(104, 424), Vector2(0, 424)]},
			{"kind": "stairs", "poly": [Vector2(104, 388), Vector2(176, 388), Vector2(176, 428), Vector2(104, 428)]},
			{"kind": "chasm", "poly": [Vector2(176, 392), Vector2(282, 392), Vector2(282, 424), Vector2(176, 424)]},
			{"kind": "rope_bridge", "poly": [Vector2(282, 384), Vector2(358, 384), Vector2(358, 432), Vector2(282, 432)]},
			{"kind": "chasm", "poly": [Vector2(358, 392), Vector2(476, 392), Vector2(476, 424), Vector2(358, 424)]},
			{"kind": "stairs", "poly": [Vector2(476, 388), Vector2(556, 388), Vector2(556, 428), Vector2(476, 428)]},
			{"kind": "cliff", "poly": [Vector2(556, 392), Vector2(640, 392), Vector2(640, 424), Vector2(556, 424)]},
			{"kind": "cliff", "poly": [Vector2(0, 524), Vector2(216, 524), Vector2(216, 556), Vector2(0, 556)]},
			{"kind": "stairs", "poly": [Vector2(216, 520), Vector2(300, 520), Vector2(300, 560), Vector2(216, 560)]},
			{"kind": "cliff", "poly": [Vector2(300, 524), Vector2(340, 524), Vector2(340, 556), Vector2(300, 556)]},
			{"kind": "stairs", "poly": [Vector2(340, 520), Vector2(424, 520), Vector2(424, 560), Vector2(340, 560)]},
			{"kind": "cliff", "poly": [Vector2(424, 524), Vector2(640, 524), Vector2(640, 556), Vector2(424, 556)]},
		],
		"no_build": [Rect2(272, 688, 96, 48)],
		"trails": [[Vector2(320, 96), Vector2(240, 200), Vector2(240, 300), Vector2(290, 360), Vector2(290, 470), Vector2(260, 600), Vector2(320, 736)]],
		"castle": "temple",
		"bot_posts": [Vector2(240, 320), Vector2(400, 320), Vector2(140, 460), Vector2(290, 460), Vector2(516, 460),
			Vector2(258, 590), Vector2(382, 590)],
	},
	# The High Monastery, the Gate: the monastery's courtyard, walled in by crags on both
	# sides, stairs up into it from the mountain road, rocks splitting the way; three bell
	# towers stand across the courtyard (the missions put them there).
	"monastery_gate": {
		"name": "The Monastery Gate", "battle": "gate", "music": "calm_gate",
		"blurb": "A courtyard of\nbell towers on\nthe mountain",
		"biome": "mountain",
		"lanes": [[120, 520]],
		"terrain": [
			{"kind": "cliff", "poly": [Vector2(0, -120), Vector2(110, -120), Vector2(96, 200), Vector2(60, 330), Vector2(70, 520),
				Vector2(40, 736), Vector2(0, 736)]},
			{"kind": "cliff", "poly": [Vector2(640, -120), Vector2(530, -120), Vector2(544, 200), Vector2(580, 330), Vector2(570, 520),
				Vector2(600, 736), Vector2(640, 736)]},
			{"kind": "rock", "poly": [Vector2(200, 226), Vector2(244, 214), Vector2(268, 240), Vector2(256, 272), Vector2(212, 276),
				Vector2(192, 252)]},
			{"kind": "rock", "poly": [Vector2(388, 230), Vector2(430, 216), Vector2(456, 244), Vector2(446, 276), Vector2(402, 278),
				Vector2(380, 254)]},
			{"kind": "stairs", "poly": [Vector2(120, 300), Vector2(520, 300), Vector2(520, 344), Vector2(120, 344)]},
		],
		"no_build": [Rect2(272, 688, 96, 48)],
		"trails": [[Vector2(320, 96), Vector2(320, 300), Vector2(320, 736)]],
		"bells": [Vector2(150, 480), Vector2(320, 430), Vector2(490, 480)],
		"castle": "temple",
		"bot_posts": [Vector2(150, 520), Vector2(320, 470), Vector2(490, 520), Vector2(220, 400), Vector2(420, 400),
			Vector2(320, 600), Vector2(160, 620)],
	},
	# The Free Cities, the Market Road: three streets down between townhouses of every size,
	# a canal across with a bridge on each street, the market's stalls set out between the
	# houses (a pair on a little square above the canal, a row below it), and the town's
	# fountain on the square in front of the city hall, the streets going round it. Tight
	# alleys (about 44px: room for a troop or a goblin, not a Troll) cut between some of the
	# houses. The townsfolk come down the three streets (the mission's routes), which stay
	# clear.
	"city_market": {
		"name": "The Market Road", "battle": "market", "music": "city",
		"blurb": "Market stalls,\nstreets and a\nfountain square",
		"biome": "city",
		"lanes": [[40, 600]],
		"terrain": [
			# Above the canal: the left edge, the block between the left and middle streets
			# (an alley across it), the fountain plaza, the right edge.
			{"kind": "building", "poly": [Vector2(0, 206), Vector2(62, 206), Vector2(62, 280), Vector2(0, 280)]},
			{"kind": "building", "poly": [Vector2(0, 300), Vector2(70, 296), Vector2(70, 372), Vector2(0, 372)]},
			{"kind": "building", "poly": [Vector2(150, 204), Vector2(224, 204), Vector2(224, 286), Vector2(150, 286)]},
			{"kind": "building", "poly": [Vector2(232, 216), Vector2(280, 216), Vector2(280, 286), Vector2(232, 286)]},
			{"kind": "building", "poly": [Vector2(154, 330), Vector2(250, 330), Vector2(250, 372), Vector2(154, 372)]},
			{"kind": "building", "poly": [Vector2(256, 336), Vector2(280, 336), Vector2(280, 372), Vector2(256, 372)]},
			{"kind": "stall", "poly": [Vector2(370, 262), Vector2(420, 262), Vector2(420, 294), Vector2(370, 294)]},
			{"kind": "stall", "poly": [Vector2(434, 262), Vector2(484, 262), Vector2(484, 294), Vector2(434, 294)]},
			{"kind": "building", "poly": [Vector2(572, 214), Vector2(640, 214), Vector2(640, 330), Vector2(580, 330)]},
			{"kind": "building", "poly": [Vector2(586, 342), Vector2(640, 342), Vector2(640, 372), Vector2(586, 372)]},
			# The canal, a bridge on each street.
			{"kind": "canal", "poly": [Vector2(0, 392), Vector2(70, 392), Vector2(70, 428), Vector2(0, 428)]},
			{"kind": "canal", "poly": [Vector2(150, 392), Vector2(280, 392), Vector2(280, 428), Vector2(150, 428)]},
			{"kind": "canal", "poly": [Vector2(360, 392), Vector2(490, 392), Vector2(490, 428), Vector2(360, 428)]},
			{"kind": "canal", "poly": [Vector2(572, 392), Vector2(640, 392), Vector2(640, 428), Vector2(572, 428)]},
			{"kind": "bridge", "poly": [Vector2(66, 386), Vector2(154, 386), Vector2(154, 434), Vector2(66, 434)]},
			{"kind": "bridge", "poly": [Vector2(276, 386), Vector2(364, 386), Vector2(364, 434), Vector2(276, 434)]},
			{"kind": "bridge", "poly": [Vector2(486, 386), Vector2(576, 386), Vector2(576, 434), Vector2(486, 434)]},
			# Below it: the left edge, a block with a stall behind it, two rows of stalls
			# between the middle and right streets, the right edge.
			{"kind": "building", "poly": [Vector2(0, 452), Vector2(60, 452), Vector2(64, 560), Vector2(0, 560)]},
			{"kind": "building", "poly": [Vector2(150, 452), Vector2(276, 452), Vector2(276, 512), Vector2(150, 512)]},
			{"kind": "stall", "poly": [Vector2(158, 552), Vector2(226, 552), Vector2(226, 584), Vector2(158, 584)]},
			{"kind": "stall", "poly": [Vector2(364, 458), Vector2(416, 458), Vector2(416, 490), Vector2(364, 490)]},
			{"kind": "stall", "poly": [Vector2(434, 458), Vector2(486, 458), Vector2(486, 490), Vector2(434, 490)]},
			{"kind": "stall", "poly": [Vector2(364, 524), Vector2(416, 524), Vector2(416, 556), Vector2(364, 556)]},
			{"kind": "stall", "poly": [Vector2(434, 524), Vector2(486, 524), Vector2(486, 556), Vector2(434, 556)]},
			{"kind": "building", "poly": [Vector2(580, 456), Vector2(640, 456), Vector2(640, 580), Vector2(576, 580)]},
			# The fountain on the square before the city hall.
			{"kind": "fountain", "poly": [Vector2(353, 634), Vector2(334, 653), Vector2(306, 653), Vector2(287, 634), Vector2(287, 606), Vector2(306, 587), Vector2(334, 587), Vector2(353, 606)]}],
		"no_build": [Rect2(272, 688, 96, 48)],
		"castle": "cityhall",
		"bot_posts": [Vector2(110, 460), Vector2(320, 460), Vector2(530, 460), Vector2(110, 300), Vector2(320, 300), Vector2(440, 350),
			Vector2(220, 640), Vector2(420, 640)],
	},
	# The Free Cities, the Exchange: the Council's great Exchange on its paved square
	# (planters at its corners), a canal across the city above it with three bridges and
	# boats moored along it, street lamps on both banks, townhouses on the flanks with
	# goods stacked at their doors.
	"city_exchange": {
		"name": "The Exchange", "battle": "council", "music": "calm_exchange",
		"blurb": "The Exchange\nbehind the\ncanal bridges",
		"biome": "city",
		"lanes": [[40, 600]],
		"terrain": [
			{"kind": "canal", "poly": [Vector2(0, 300), Vector2(110, 300), Vector2(110, 332), Vector2(0, 332)]},
			{"kind": "canal", "poly": [Vector2(180, 300), Vector2(290, 300), Vector2(290, 332), Vector2(180, 332)]},
			{"kind": "canal", "poly": [Vector2(350, 300), Vector2(460, 300), Vector2(460, 332), Vector2(350, 332)]},
			{"kind": "canal", "poly": [Vector2(530, 300), Vector2(640, 300), Vector2(640, 332), Vector2(530, 332)]},
			{"kind": "bridge", "poly": [Vector2(106, 294), Vector2(184, 294), Vector2(184, 338), Vector2(106, 338)]},
			{"kind": "bridge", "poly": [Vector2(286, 294), Vector2(354, 294), Vector2(354, 338), Vector2(286, 338)]},
			{"kind": "bridge", "poly": [Vector2(456, 294), Vector2(534, 294), Vector2(534, 338), Vector2(456, 338)]},
			{"kind": "building", "poly": [Vector2(0, 150), Vector2(84, 150), Vector2(84, 230), Vector2(0, 230)]},
			{"kind": "building", "poly": [Vector2(556, 150), Vector2(640, 150), Vector2(640, 230), Vector2(556, 230)]},
			{"kind": "building", "poly": [Vector2(170, 150), Vector2(260, 150), Vector2(260, 240), Vector2(170, 240)]},
			{"kind": "building", "poly": [Vector2(380, 150), Vector2(470, 150), Vector2(470, 240), Vector2(380, 240)]},
			{"kind": "building", "poly": [Vector2(0, 390), Vector2(110, 390), Vector2(110, 560), Vector2(0, 560)]},
			{"kind": "building", "poly": [Vector2(530, 390), Vector2(640, 390), Vector2(640, 560), Vector2(530, 560)]}],
		"no_build": [Rect2(272, 688, 96, 48)],
		"castle": "cityhall",
		# Just paint: nothing here stands in anyone's way.
		"decor": [{"kind": "plaza", "rect": Rect2(188, 440, 264, 220), "at": Vector2(320, 550), "r": 44.0},
			{"kind": "planter", "at": Vector2(200, 454)}, {"kind": "planter", "at": Vector2(440, 454)},
			{"kind": "planter", "at": Vector2(200, 650)}, {"kind": "planter", "at": Vector2(440, 650)},
			{"kind": "boat", "at": Vector2(52, 316)}, {"kind": "boat", "at": Vector2(236, 316)},
			{"kind": "boat", "at": Vector2(402, 316)}, {"kind": "boat", "at": Vector2(590, 316)},
			{"kind": "lamp", "at": Vector2(96, 296)}, {"kind": "lamp", "at": Vector2(196, 296)},
			{"kind": "lamp", "at": Vector2(444, 296)}, {"kind": "lamp", "at": Vector2(544, 296)},
			{"kind": "lamp", "at": Vector2(96, 352)}, {"kind": "lamp", "at": Vector2(196, 352)},
			{"kind": "lamp", "at": Vector2(444, 352)}, {"kind": "lamp", "at": Vector2(544, 352)},
			{"kind": "crates", "at": Vector2(126, 548)}, {"kind": "crates", "at": Vector2(514, 548)},
			{"kind": "crates", "at": Vector2(276, 232)}, {"kind": "crates", "at": Vector2(364, 232)},
			{"kind": "crates", "at": Vector2(98, 222)}, {"kind": "crates", "at": Vector2(542, 222)}],
		"bot_posts": [Vector2(145, 360), Vector2(320, 360), Vector2(495, 360), Vector2(220, 450), Vector2(420, 450),
			Vector2(320, 560), Vector2(180, 600), Vector2(460, 600)],
	},
	# The Free Cities, Carnival Night: streets running into the carnival plaza in the middle
	# of the city, stalls and townhouses round it (the mission hangs the lanterns).
	"city_carnival": {
		"name": "The Carnival Plaza", "battle": "carnival", "music": "calm_carnival",
		"blurb": "A plaza of\nstalls and\nlanterns",
		"biome": "city",
		"lanes": [[40, 600]],
		"terrain": [
			{"kind": "building", "poly": [Vector2(0, 190), Vector2(120, 190), Vector2(120, 330), Vector2(0, 330)]},
			{"kind": "building", "poly": [Vector2(200, 190), Vector2(262, 190), Vector2(262, 290), Vector2(200, 290)]},
			{"kind": "building", "poly": [Vector2(378, 190), Vector2(440, 190), Vector2(440, 290), Vector2(378, 290)]},
			{"kind": "building", "poly": [Vector2(520, 190), Vector2(640, 190), Vector2(640, 330), Vector2(520, 330)]},
			{"kind": "building", "poly": [Vector2(0, 500), Vector2(130, 500), Vector2(130, 620), Vector2(0, 620)]},
			{"kind": "building", "poly": [Vector2(210, 540), Vector2(270, 540), Vector2(270, 600), Vector2(210, 600)]},
			{"kind": "building", "poly": [Vector2(370, 540), Vector2(430, 540), Vector2(430, 600), Vector2(370, 600)]},
			{"kind": "building", "poly": [Vector2(510, 500), Vector2(640, 500), Vector2(640, 620), Vector2(510, 620)]},
			# Market stalls round the plaza (clear of the plaza itself and the lanterns).
			{"kind": "stall", "poly": [Vector2(130, 128), Vector2(182, 128), Vector2(182, 156), Vector2(130, 156)]},
			{"kind": "stall", "poly": [Vector2(458, 128), Vector2(510, 128), Vector2(510, 156), Vector2(458, 156)]},
			{"kind": "stall", "poly": [Vector2(20, 350), Vector2(80, 350), Vector2(80, 378), Vector2(20, 378)]},
			{"kind": "stall", "poly": [Vector2(560, 350), Vector2(620, 350), Vector2(620, 378), Vector2(560, 378)]},
			{"kind": "stall", "poly": [Vector2(54, 640), Vector2(106, 640), Vector2(106, 668), Vector2(54, 668)]},
			{"kind": "stall", "poly": [Vector2(534, 640), Vector2(586, 640), Vector2(586, 668), Vector2(534, 668)]}],
		"lanterns": [Vector2(320, 330), Vector2(230, 420), Vector2(410, 420), Vector2(320, 510), Vector2(160, 400), Vector2(480, 400),
			Vector2(320, 200), Vector2(140, 660), Vector2(500, 660)],
		"no_build": [Rect2(272, 688, 96, 48)],
		"castle": "cityhall",
		"bot_posts": [Vector2(320, 340), Vector2(230, 420), Vector2(410, 420), Vector2(320, 500), Vector2(160, 400), Vector2(480, 400),
			Vector2(320, 640)],
	},
	# The Arcane Spires, the Broken Circle: the Circle (the ground to take and hold) on a great
	# floating island, four small islands round it with a sigil each (one of each art), glowing
	# bridges in their sigils' colours between them, the camp above and the castle below.
	"spires_circle": {
		"name": "The Broken Circle", "battle": "spires", "music": "calm_spires",
		"blurb": "Floating islands\nround the broken\nCircle",
		"biome": "void", "tint": Color(0.92, 0.9, 1.0),
		"lanes": [[60, 580]],
		"islands": [
			{"at": Vector2(150, 228), "r": 64, "path": 0},
			{"at": Vector2(490, 228), "r": 64, "path": 1},
			{"at": Vector2(108, 522), "r": 60, "path": 2},
			{"at": Vector2(532, 522), "r": 60, "path": 3},
			{"at": Vector2(320, 440), "r": 142, "path": -1}],
		"bridges": [
			{"from": Vector2(150, 80), "to": Vector2(150, 178), "w": 84, "path": 0},
			{"from": Vector2(490, 80), "to": Vector2(490, 178), "w": 84, "path": 1},
			{"from": Vector2(320, 80), "to": Vector2(320, 312), "w": 84, "path": -1},
			{"from": Vector2(187, 274), "to": Vector2(238, 338), "w": 84, "path": 0},
			{"from": Vector2(453, 274), "to": Vector2(402, 338), "w": 84, "path": 1},
			{"from": Vector2(159, 502), "to": Vector2(198, 487), "w": 84, "path": 2},
			{"from": Vector2(481, 502), "to": Vector2(442, 487), "w": 84, "path": 3},
			{"from": Vector2(108, 568), "to": Vector2(108, 704), "w": 84, "path": 2},
			{"from": Vector2(532, 568), "to": Vector2(532, 704), "w": 84, "path": 3},
			{"from": Vector2(320, 568), "to": Vector2(320, 704), "w": 90, "path": -1}],
		"lands": [Rect2(-60, -150, 760, 250), Rect2(-60, 684, 760, 120)],
		"terrain": [
			{"kind": "crystal", "poly": [Vector2(204, 413), Vector2(219, 416), Vector2(224, 440), Vector2(217, 460), Vector2(204, 470), Vector2(191, 461), Vector2(184, 440), Vector2(190, 417)]},
			{"kind": "crystal", "poly": [Vector2(436, 406), Vector2(451, 416), Vector2(453, 440), Vector2(448, 459), Vector2(436, 473), Vector2(422, 463), Vector2(416, 440), Vector2(423, 420)]},
			{"kind": "crystal", "poly": [Vector2(104, 217), Vector2(114, 221), Vector2(117, 236), Vector2(114, 251), Vector2(104, 258), Vector2(96, 249), Vector2(92, 236), Vector2(94, 220)]},
			{"kind": "crystal", "poly": [Vector2(536, 217), Vector2(544, 223), Vector2(549, 236), Vector2(545, 249), Vector2(536, 254), Vector2(527, 250), Vector2(521, 236), Vector2(526, 220)]}],
		"conduits": [{"at": Vector2(156, 224), "path": 0}, {"at": Vector2(484, 224), "path": 1}, {"at": Vector2(116, 522), "path": 2}, {"at": Vector2(524, 522), "path": 3}],
		"no_build": [Rect2(272, 688, 96, 48)],
		"trails": [],
		"castle": "conclave",
		"bot_posts": [Vector2(320, 440), Vector2(268, 400), Vector2(372, 400), Vector2(320, 500), Vector2(150, 228), Vector2(490, 228), Vector2(320, 640)],
	},
	# The Arcane Spires, Relight the Spires: three floating islands with a spire each (to keep
	# standing) and a sigil by it, bridges glowing in their sigils' colours down to a great
	# island before the castle, which has a sigil of its own.
	"spires_relight": {
		"name": "The Three Spires", "battle": "relight", "music": "calm_relight",
		"blurb": "Three spire\nislands round\nthe Conclave's",
		"biome": "void", "tint": Color(0.92, 0.9, 1.0),
		"lanes": [[60, 580]],
		"islands": [
			{"at": Vector2(130, 420), "r": 80, "path": 2},
			{"at": Vector2(320, 262), "r": 80, "path": 0},
			{"at": Vector2(510, 420), "r": 80, "path": 1},
			{"at": Vector2(320, 566), "r": 104, "path": 3}],
		"bridges": [
			{"from": Vector2(320, 80), "to": Vector2(320, 196), "w": 84, "path": 0},
			{"from": Vector2(130, 80), "to": Vector2(130, 354), "w": 84, "path": 2},
			{"from": Vector2(510, 80), "to": Vector2(510, 354), "w": 84, "path": 1},
			{"from": Vector2(320, 336), "to": Vector2(320, 470), "w": 84, "path": 0},
			{"from": Vector2(188, 465), "to": Vector2(244, 508), "w": 84, "path": 2},
			{"from": Vector2(452, 465), "to": Vector2(396, 508), "w": 84, "path": 1},
			{"from": Vector2(320, 656), "to": Vector2(320, 704), "w": 90, "path": 3}],
		"lands": [Rect2(-60, -150, 760, 250), Rect2(-60, 684, 760, 120)],
		"terrain": [
			{"kind": "crystal", "poly": [Vector2(76, 448), Vector2(86, 454), Vector2(90, 466), Vector2(86, 478), Vector2(76, 482), Vector2(66, 478), Vector2(62, 466), Vector2(66, 454)]},
			{"kind": "crystal", "poly": [Vector2(564, 448), Vector2(574, 454), Vector2(578, 466), Vector2(574, 478), Vector2(564, 482), Vector2(554, 478), Vector2(550, 466), Vector2(554, 454)]},
			{"kind": "crystal", "poly": [Vector2(232, 544), Vector2(241, 557), Vector2(248, 572), Vector2(242, 588), Vector2(232, 600), Vector2(223, 587), Vector2(215, 572), Vector2(221, 554)]},
			{"kind": "crystal", "poly": [Vector2(408, 548), Vector2(419, 555), Vector2(423, 572), Vector2(419, 589), Vector2(408, 596), Vector2(397, 590), Vector2(394, 572), Vector2(397, 554)]}],
		"conduits": [{"at": Vector2(144, 466), "path": 2}, {"at": Vector2(334, 308), "path": 0}, {"at": Vector2(496, 466), "path": 1}, {"at": Vector2(320, 586), "path": 3}],
		"no_build": [Rect2(272, 688, 96, 48)],
		"trails": [],
		"castle": "conclave",
		"bot_posts": [Vector2(130, 470), Vector2(320, 312), Vector2(510, 470), Vector2(320, 566), Vector2(272, 600), Vector2(368, 600), Vector2(320, 690)],
	},
	# The Arcane Spires, the Lost Archive: the Archive (to keep standing while it's read) on a
	# great floating island, a sigil on each of four small islands round it: a Mage has to
	# leave the Archive's side to draw on one. Bridges glow in their sigils' colours.
	"spires_archive": {
		"name": "The Lost Archive", "battle": "archive", "music": "calm_archive",
		"blurb": "The Archive on\na floating island,\nsigils round it",
		"biome": "void", "tint": Color(0.92, 0.9, 1.0),
		"lanes": [[60, 580]],
		"islands": [
			{"at": Vector2(320, 456), "r": 140, "path": -1},
			{"at": Vector2(112, 262), "r": 62, "path": 3},
			{"at": Vector2(528, 262), "r": 62, "path": 1},
			{"at": Vector2(100, 566), "r": 58, "path": 2},
			{"at": Vector2(540, 566), "r": 58, "path": 0}],
		"bridges": [
			{"from": Vector2(112, 80), "to": Vector2(112, 214), "w": 100, "path": 3},
			{"from": Vector2(528, 80), "to": Vector2(528, 214), "w": 100, "path": 1},
			{"from": Vector2(320, 80), "to": Vector2(320, 330), "w": 100, "path": -1},
			{"from": Vector2(154, 301), "to": Vector2(226, 368), "w": 100, "path": 3},
			{"from": Vector2(486, 301), "to": Vector2(414, 368), "w": 100, "path": 1},
			{"from": Vector2(148, 542), "to": Vector2(205, 514), "w": 100, "path": 2},
			{"from": Vector2(492, 542), "to": Vector2(435, 514), "w": 100, "path": 0},
			{"from": Vector2(100, 610), "to": Vector2(100, 704), "w": 100, "path": 2},
			{"from": Vector2(540, 610), "to": Vector2(540, 704), "w": 100, "path": 0},
			{"from": Vector2(320, 582), "to": Vector2(320, 704), "w": 90, "path": -1}],
		"lands": [Rect2(-60, -150, 760, 250), Rect2(-60, 684, 760, 120)],
		"terrain": [
			{"kind": "crystal", "poly": [Vector2(64, 249), Vector2(73, 255), Vector2(77, 270), Vector2(71, 282), Vector2(64, 289), Vector2(56, 283), Vector2(53, 270), Vector2(57, 258)]},
			{"kind": "crystal", "poly": [Vector2(576, 250), Vector2(585, 255), Vector2(586, 270), Vector2(585, 285), Vector2(576, 287), Vector2(568, 284), Vector2(566, 270), Vector2(567, 256)]}],
		"conduits": [{"at": Vector2(120, 262), "path": 3}, {"at": Vector2(520, 262), "path": 1}, {"at": Vector2(106, 566), "path": 2}, {"at": Vector2(534, 566), "path": 0}],
		"no_build": [Rect2(272, 688, 96, 48)],
		"trails": [],
		"castle": "conclave",
		"bot_posts": [Vector2(320, 400), Vector2(260, 456), Vector2(380, 456), Vector2(320, 530), Vector2(112, 262), Vector2(528, 262), Vector2(320, 650)],
	},
	# Sable Crossing: a river across the field, two bridges (80px, room for the Marshal) and
	# a shallow ford between them that slows anyone wading it.
	"sable_crossing": {
		"name": "Sable Crossing", "battle": "sable", "music": "river",
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
	# Frostmarch, Whiteout: a long frozen lake the sled crosses on solid ice, thin ice well off
	# its road on both sides, pinewoods along the shores.
	"frostmarch_crossing": {
		"name": "The Long Lake", "battle": "whiteout", "music": "calm_whiteout", "camp": false,
		"blurb": "A frozen lake\nin the snow",
		"biome": "snow",
		"lanes": [[40, 600]],
		"terrain": [
			{"kind": "ice", "poly": [Vector2(150, 150), Vector2(500, 140), Vector2(560, 300), Vector2(520, 520), Vector2(420, 670),
				Vector2(220, 676), Vector2(120, 520), Vector2(110, 300)]},
			{"kind": "thin_ice", "poly": [Vector2(140, 300), Vector2(250, 300), Vector2(250, 420), Vector2(140, 420)]},
			{"kind": "thin_ice", "poly": [Vector2(410, 380), Vector2(510, 380), Vector2(505, 500), Vector2(410, 500)]},
			{"kind": "thin_ice", "poly": [Vector2(400, 570), Vector2(470, 570), Vector2(440, 640), Vector2(400, 640)]},
			{"kind": "trees", "poly": [Vector2(0, 120), Vector2(70, 130), Vector2(96, 260), Vector2(80, 400), Vector2(0, 410)]},
			{"kind": "trees", "poly": [Vector2(640, 200), Vector2(590, 210), Vector2(574, 340), Vector2(590, 480), Vector2(640, 500)]},
			{"kind": "trees", "poly": [Vector2(0, 560), Vector2(100, 570), Vector2(140, 650), Vector2(110, 736), Vector2(0, 736)]},
			{"kind": "rock", "poly": [Vector2(540, 620), Vector2(590, 606), Vector2(626, 640), Vector2(610, 690), Vector2(556, 694)]},
		],
		"no_build": [],
		"trails": [],
		"route": [Vector2(320, 760), Vector2(330, 600), Vector2(300, 470), Vector2(340, 330), Vector2(320, 200), Vector2(330, 104)],
	},
	# Open farmland: a few copses, the road winding up the middle.
	"convoy_meadow": {
		"name": "The Meadow Road", "battle": "road", "music": "calm_road", "biome": "meadow", "camp": false,
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
		"name": "The Darkwood", "battle": "darkwood", "music": "calm_darkwood", "biome": "meadow", "camp": false, "tint": Color(0.78, 0.9, 0.8),
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
		"name": "The Village Fields", "battle": "village", "music": "calm_village", "biome": "meadow",
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
		"name": "The High Pass", "battle": "highpass", "music": "calm_highpass", "biome": "mountain", "camp": false, "tint": Color(1.0, 0.94, 0.9),
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
		"name": "The Old Ford", "battle": "ford", "music": "calm_ford", "biome": "meadow", "camp": false,
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
		"name": "The Fens", "battle": "fens", "music": "calm_fens", "biome": "meadow", "ground": "fen", "camp": false, "tint": Color(0.86, 0.95, 0.88),
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
		"name": "The Burnt Village", "battle": "embers", "music": "calm_embers", "biome": "meadow", "ground": "burnt", "camp": false, "tint": Color(1.0, 0.9, 0.84),
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
		"name": "Ashen Ridge", "battle": "ashen", "music": "calm_ashen", "biome": "mountain", "ground": "ash", "camp": false, "tint": Color(0.94, 0.92, 0.94),
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
	# --- Dawnspire (Phase 5): the fortress assault --------------------------------------------
	# Each field ends at a wall across the top: a gate in the middle (the mission's, shut
	# until it's broken or raised) and a postern at each end, where the garrison comes out.
	# The battering ram comes up the road from the bottom to the gate.
	# The Approach: the fields under Dawnspire's outer wall, where the Line's army was broken
	# when the Ogre King took the citadel: scorched and cratered, the farmsteads burnt out,
	# a grove burnt black and a siege engine wrecked, the dead's shields and blades and
	# arrows everywhere, Dawnspire's sun banners trampled, and his own war-banners and
	# skull pikes planted over all of it. Fires still burn. A timber gate in the wall.
	"ds_approach": {
		"name": "The Approach", "battle": "siege", "music": "calm_dsapproach", "biome": "meadow", "ground": "war", "camp": false,
		"tint": Color(0.98, 0.88, 0.8), "wall": "outer",
		"lanes": [[40, 100], [540, 600]],
		"terrain": [
			{"kind": "curtain", "poly": [Vector2(0, -120), Vector2(28, -120), Vector2(28, 150), Vector2(0, 150)]},
			{"kind": "curtain", "poly": [Vector2(112, -120), Vector2(280, -120), Vector2(280, 150), Vector2(112, 150)]},
			{"kind": "curtain", "poly": [Vector2(360, -120), Vector2(528, -120), Vector2(528, 150), Vector2(360, 150)]},
			{"kind": "curtain", "poly": [Vector2(612, -120), Vector2(640, -120), Vector2(640, 150), Vector2(612, 150)]},
			{"kind": "ruin", "poly": [Vector2(96, 360), Vector2(176, 360), Vector2(176, 426), Vector2(96, 426)]},
			{"kind": "ruin", "poly": [Vector2(462, 452), Vector2(548, 452), Vector2(548, 516), Vector2(462, 516)]},
			{"kind": "deadwood", "poly": [Vector2(0, 520), Vector2(70, 512), Vector2(104, 580), Vector2(84, 660), Vector2(0, 672)]},
			{"kind": "deadwood", "poly": [Vector2(640, 280), Vector2(586, 292), Vector2(566, 360), Vector2(590, 424), Vector2(640, 432)]},
			{"kind": "wreck", "poly": [Vector2(190, 560), Vector2(262, 556), Vector2(270, 600), Vector2(196, 610)]},
		],
		"no_build": [],
		"trails": [[Vector2(320, 760), Vector2(316, 620), Vector2(326, 470), Vector2(318, 330), Vector2(320, 150)],
			[Vector2(70, 150), Vector2(90, 250), Vector2(200, 330), Vector2(310, 400)], [Vector2(570, 150), Vector2(550, 260), Vector2(440, 340), Vector2(330, 420)]],
		"route": [Vector2(320, 760), Vector2(316, 620), Vector2(326, 470), Vector2(318, 330), Vector2(320, 200)],
		"decor": [
			{"kind": "crater", "at": Vector2(244, 300), "r": 20.0}, {"kind": "crater", "at": Vector2(410, 392), "r": 24.0},
			{"kind": "crater", "at": Vector2(158, 486), "r": 16.0}, {"kind": "crater", "at": Vector2(530, 618), "r": 22.0},
			{"kind": "crater", "at": Vector2(386, 560), "r": 14.0}, {"kind": "crater", "at": Vector2(96, 262), "r": 13.0},
			{"kind": "crater", "at": Vector2(560, 210), "r": 15.0},
			{"kind": "line_banner", "at": Vector2(292, 470), "angle": 0.5}, {"kind": "line_banner", "at": Vector2(478, 330), "angle": -0.3},
			{"kind": "line_banner", "at": Vector2(84, 440), "angle": 2.2}, {"kind": "line_banner", "at": Vector2(420, 676), "angle": 0.9},
			{"kind": "debris", "at": Vector2(250, 410)}, {"kind": "debris", "at": Vector2(548, 560)},
			{"kind": "fire", "at": Vector2(136, 393)}, {"kind": "fire", "at": Vector2(505, 484)}, {"kind": "fire", "at": Vector2(232, 586)},
			{"kind": "fire", "at": Vector2(40, 590)},
			{"kind": "stakes", "at": Vector2(132, 196), "to": Vector2(236, 222)}, {"kind": "stakes", "at": Vector2(404, 222), "to": Vector2(508, 196)},
			{"kind": "pikes", "at": Vector2(262, 252)}, {"kind": "pikes", "at": Vector2(380, 252)}, {"kind": "pikes", "at": Vector2(470, 700)},
			{"kind": "ogre_banner", "at": Vector2(256, 188)}, {"kind": "ogre_banner", "at": Vector2(386, 188)},
			{"kind": "ogre_banner", "at": Vector2(170, 660)}, {"kind": "ogre_banner", "at": Vector2(610, 520)},
			{"kind": "deadtree", "at": Vector2(300, 640)}, {"kind": "deadtree", "at": Vector2(610, 640)}, {"kind": "deadtree", "at": Vector2(46, 330)}]},
	# The Outer Bailey: the ward between the walls, its houses burnt out, market stalls
	# overturned; an iron portcullis in the inner wall, raised from a winch house.
	"ds_bailey": {
		"name": "The Outer Bailey", "battle": "bailey", "music": "calm_bailey", "biome": "city", "ground": "war", "camp": false,
		"tint": Color(0.94, 0.9, 0.88), "wall": "inner",
		"lanes": [[40, 100], [540, 600]],
		"terrain": [
			{"kind": "curtain", "poly": [Vector2(0, -120), Vector2(28, -120), Vector2(28, 150), Vector2(0, 150)]},
			{"kind": "curtain", "poly": [Vector2(112, -120), Vector2(280, -120), Vector2(280, 150), Vector2(112, 150)]},
			{"kind": "curtain", "poly": [Vector2(360, -120), Vector2(528, -120), Vector2(528, 150), Vector2(360, 150)]},
			{"kind": "curtain", "poly": [Vector2(612, -120), Vector2(640, -120), Vector2(640, 150), Vector2(612, 150)]},
			{"kind": "ruin", "poly": [Vector2(0, 330), Vector2(76, 330), Vector2(76, 420), Vector2(0, 420)]},
			{"kind": "ruin", "poly": [Vector2(560, 400), Vector2(640, 400), Vector2(640, 500), Vector2(560, 500)]},
			{"kind": "ruin", "poly": [Vector2(150, 470), Vector2(236, 470), Vector2(236, 530), Vector2(150, 530)]},
			{"kind": "stall", "poly": [Vector2(404, 560), Vector2(456, 560), Vector2(456, 592), Vector2(404, 592)]},
			{"kind": "stall", "poly": [Vector2(178, 622), Vector2(230, 622), Vector2(230, 654), Vector2(178, 654)]},
		],
		"no_build": [],
		"trails": [[Vector2(320, 760), Vector2(324, 620), Vector2(314, 470), Vector2(322, 330), Vector2(320, 150)]],
		"route": [Vector2(320, 760), Vector2(324, 620), Vector2(314, 470), Vector2(322, 330), Vector2(320, 200)],
		"decor": [
			{"kind": "crater", "at": Vector2(400, 440), "r": 16.0}, {"kind": "crater", "at": Vector2(230, 300), "r": 14.0},
			{"kind": "line_banner", "at": Vector2(250, 600), "angle": 0.4}, {"kind": "line_banner", "at": Vector2(500, 640), "angle": -0.6},
			{"kind": "debris", "at": Vector2(380, 680)}, {"kind": "fire", "at": Vector2(38, 376)}, {"kind": "fire", "at": Vector2(600, 450)},
			{"kind": "fire", "at": Vector2(193, 500)},
			{"kind": "pikes", "at": Vector2(250, 214)}, {"kind": "pikes", "at": Vector2(392, 214)},
			{"kind": "ogre_banner", "at": Vector2(200, 400)}, {"kind": "ogre_banner", "at": Vector2(440, 260)}]},
	# The Dawn Gate: the citadel's great gate, gilded and sun-crowned, at the head of a
	# courtyard of broken pillars; the walls above it loose Arrow Storms and Fireballs.
	"ds_dawngate": {
		"name": "The Dawn Gate", "battle": "dawngate", "music": "calm_dawngate", "biome": "city", "camp": false,
		"tint": Color(1.0, 0.92, 0.82), "wall": "citadel",
		"lanes": [[40, 100], [540, 600]],
		"terrain": [
			{"kind": "curtain", "poly": [Vector2(0, -120), Vector2(28, -120), Vector2(28, 150), Vector2(0, 150)]},
			{"kind": "curtain", "poly": [Vector2(112, -120), Vector2(280, -120), Vector2(280, 150), Vector2(112, 150)]},
			{"kind": "curtain", "poly": [Vector2(360, -120), Vector2(528, -120), Vector2(528, 150), Vector2(360, 150)]},
			{"kind": "curtain", "poly": [Vector2(612, -120), Vector2(640, -120), Vector2(640, 150), Vector2(612, 150)]},
			{"kind": "ruin", "poly": [Vector2(196, 300), Vector2(232, 300), Vector2(232, 336), Vector2(196, 336)]},
			{"kind": "ruin", "poly": [Vector2(408, 300), Vector2(444, 300), Vector2(444, 336), Vector2(408, 336)]},
			{"kind": "ruin", "poly": [Vector2(196, 460), Vector2(232, 460), Vector2(232, 496), Vector2(196, 496)]},
			{"kind": "ruin", "poly": [Vector2(408, 460), Vector2(444, 460), Vector2(444, 496), Vector2(408, 496)]},
			{"kind": "ruin", "poly": [Vector2(0, 560), Vector2(70, 560), Vector2(70, 640), Vector2(0, 640)]},
			{"kind": "ruin", "poly": [Vector2(570, 590), Vector2(640, 590), Vector2(640, 660), Vector2(570, 660)]},
		],
		"no_build": [],
		"trails": [[Vector2(320, 760), Vector2(320, 600), Vector2(320, 400), Vector2(320, 150)]],
		"route": [Vector2(320, 760), Vector2(320, 600), Vector2(320, 400), Vector2(320, 202)],
		"ground": "war",
		"decor": [{"kind": "plaza", "rect": Rect2(250, 220, 140, 500), "at": Vector2(320, 398), "r": 46.0},
			{"kind": "line_banner", "at": Vector2(280, 560), "angle": 0.3}, {"kind": "line_banner", "at": Vector2(372, 300), "angle": 2.6},
			{"kind": "debris", "at": Vector2(520, 520)}, {"kind": "fire", "at": Vector2(36, 600)}, {"kind": "fire", "at": Vector2(604, 624)},
			{"kind": "pikes", "at": Vector2(240, 232)}, {"kind": "pikes", "at": Vector2(400, 232)},
			{"kind": "ogre_banner", "at": Vector2(150, 360)}, {"kind": "ogre_banner", "at": Vector2(490, 360)},
			{"kind": "ogre_banner", "at": Vector2(214, 520)}, {"kind": "ogre_banner", "at": Vector2(426, 520)}],
	},
	# --- Phase 5, F3: inside Dawnspire's citadel ---------------------------------------------
	# Rooms ("biome": "hall"; castle_art.gd): stone walls all round ("hall" terrain, tall:
	# nothing sees or shoots through), a door gap in the south wall the army comes in by and
	# one in the north wall the enemy comes through ("lanes") and the army goes on by.
	# "doors": where the ways out are ({"id", "side", "at"}; the way in may say where the army
	# comes to "stand", if not straight in from it); which room each leads to is the mission's.
	"dsc_gatehall": {
		"name": "The Gatehouse Hall", "battle": "gatehall", "music": "calm_gatehall", "biome": "hall", "camp": false,
		"tint": Color(0.98, 0.94, 0.9),
		"lanes": [[276, 364]],
		"doors": [{"id": "s", "side": "s", "at": Vector2(320, 756)}, {"id": "n", "side": "n", "at": Vector2(320, 22)}, {"id": "e", "side": "e", "at": Vector2(626, 400)}],
		"terrain": [
			{"kind": "hall", "poly": [Vector2(0, 0), Vector2(30, 0), Vector2(30, 768), Vector2(0, 768)]},
			{"kind": "hall", "poly": [Vector2(610, 0), Vector2(640, 0), Vector2(640, 360), Vector2(610, 360)]}, {"kind": "hall", "poly": [Vector2(610, 440), Vector2(640, 440), Vector2(640, 768), Vector2(610, 768)]},
			{"kind": "hall", "poly": [Vector2(30, 0), Vector2(272, 0), Vector2(272, 44), Vector2(30, 44)]},
			{"kind": "hall", "poly": [Vector2(368, 0), Vector2(610, 0), Vector2(610, 44), Vector2(368, 44)]},
			{"kind": "hall", "poly": [Vector2(30, 740), Vector2(272, 740), Vector2(272, 768), Vector2(30, 768)]},
			{"kind": "hall", "poly": [Vector2(368, 740), Vector2(610, 740), Vector2(610, 768), Vector2(368, 768)]},
			{"kind": "hall", "poly": [Vector2(30, 300), Vector2(206, 300), Vector2(206, 330), Vector2(30, 330)]},
			{"kind": "hall", "poly": [Vector2(434, 300), Vector2(610, 300), Vector2(610, 330), Vector2(434, 330)]},
			{"kind": "pillar", "poly": [Vector2(135, 155), Vector2(165, 155), Vector2(165, 185), Vector2(135, 185)]},
			{"kind": "pillar", "poly": [Vector2(475, 155), Vector2(505, 155), Vector2(505, 185), Vector2(475, 185)]},
			{"kind": "pillar", "poly": [Vector2(135, 435), Vector2(165, 435), Vector2(165, 465), Vector2(135, 465)]},
			{"kind": "pillar", "poly": [Vector2(475, 435), Vector2(505, 435), Vector2(505, 465), Vector2(475, 465)]},
			{"kind": "pillar", "poly": [Vector2(135, 595), Vector2(165, 595), Vector2(165, 625), Vector2(135, 625)]},
			{"kind": "pillar", "poly": [Vector2(475, 595), Vector2(505, 595), Vector2(505, 625), Vector2(475, 625)]},
		],
		"no_build": [],
		"trails": [],
		"decor": [{"kind": "carpet", "rect": Rect2(296, 44, 48, 696)}, {"kind": "mosaic", "at": Vector2(320, 520), "r": 44.0},
			{"kind": "brazier", "at": Vector2(250, 120)}, {"kind": "fire", "at": Vector2(250, 112)},
			{"kind": "brazier", "at": Vector2(390, 120)}, {"kind": "fire", "at": Vector2(390, 112)},
			{"kind": "brazier", "at": Vector2(250, 660)}, {"kind": "fire", "at": Vector2(250, 652)},
			{"kind": "brazier", "at": Vector2(390, 660)}, {"kind": "fire", "at": Vector2(390, 652)},
			{"kind": "ogre_banner", "at": Vector2(110, 290)}, {"kind": "ogre_banner", "at": Vector2(530, 290)},
			{"kind": "line_banner", "at": Vector2(200, 560), "angle": 0.4}, {"kind": "line_banner", "at": Vector2(470, 220), "angle": 2.2},
			{"kind": "bones", "at": Vector2(90, 400)}, {"kind": "bones", "at": Vector2(560, 680)}, {"kind": "bones", "at": Vector2(420, 380)},
			{"kind": "rubble", "at": Vector2(70, 70)}, {"kind": "rubble", "at": Vector2(570, 360)}, {"kind": "rubble", "at": Vector2(220, 720)},
			{"kind": "stain", "at": Vector2(360, 420)}, {"kind": "stain", "at": Vector2(180, 250)}, {"kind": "chains", "at": Vector2(520, 520)},
			{"kind": "rack", "at": Vector2(70, 560)}, {"kind": "rack", "at": Vector2(570, 120)}],
	},
	"dsc_banners": {
		"name": "The Hall of Banners", "battle": "banners", "music": "calm_banners", "biome": "hall", "camp": false,
		"tint": Color(0.96, 0.92, 0.9),
		"lanes": [[276, 364]],
		"doors": [{"id": "s", "side": "s", "at": Vector2(320, 756), "stand": Vector2(320, 470)}, {"id": "n", "side": "n", "at": Vector2(320, 22)}, {"id": "w", "side": "w", "at": Vector2(14, 400)}],
		"terrain": [
			{"kind": "hall", "poly": [Vector2(0, 0), Vector2(30, 0), Vector2(30, 360), Vector2(0, 360)]}, {"kind": "hall", "poly": [Vector2(0, 440), Vector2(30, 440), Vector2(30, 768), Vector2(0, 768)]},
			{"kind": "hall", "poly": [Vector2(610, 0), Vector2(640, 0), Vector2(640, 768), Vector2(610, 768)]},
			{"kind": "hall", "poly": [Vector2(30, 0), Vector2(272, 0), Vector2(272, 44), Vector2(30, 44)]},
			{"kind": "hall", "poly": [Vector2(368, 0), Vector2(610, 0), Vector2(610, 44), Vector2(368, 44)]},
			{"kind": "hall", "poly": [Vector2(30, 740), Vector2(272, 740), Vector2(272, 768), Vector2(30, 768)]},
			{"kind": "hall", "poly": [Vector2(368, 740), Vector2(610, 740), Vector2(610, 768), Vector2(368, 768)]},
			{"kind": "hall", "poly": [Vector2(30, 560), Vector2(250, 560), Vector2(250, 740), Vector2(30, 740)]},
			{"kind": "hall", "poly": [Vector2(390, 560), Vector2(610, 560), Vector2(610, 740), Vector2(390, 740)]},
			{"kind": "hall", "poly": [Vector2(30, 96), Vector2(96, 96), Vector2(96, 180), Vector2(30, 180)]},
			{"kind": "hall", "poly": [Vector2(544, 96), Vector2(610, 96), Vector2(610, 180), Vector2(544, 180)]},
			{"kind": "pillar", "poly": [Vector2(95, 285), Vector2(125, 285), Vector2(125, 315), Vector2(95, 315)]},
			{"kind": "pillar", "poly": [Vector2(515, 285), Vector2(545, 285), Vector2(545, 315), Vector2(515, 315)]},
			{"kind": "pillar", "poly": [Vector2(205, 455), Vector2(235, 455), Vector2(235, 485), Vector2(205, 485)]},
			{"kind": "pillar", "poly": [Vector2(405, 455), Vector2(435, 455), Vector2(435, 485), Vector2(405, 485)]},
			{"kind": "furniture", "poly": [Vector2(140, 236), Vector2(260, 236), Vector2(260, 262), Vector2(140, 262)]},
			{"kind": "furniture", "poly": [Vector2(380, 236), Vector2(500, 236), Vector2(500, 262), Vector2(380, 262)]},
			{"kind": "furniture", "poly": [Vector2(140, 360), Vector2(260, 360), Vector2(260, 386), Vector2(140, 386)]},
			{"kind": "furniture", "poly": [Vector2(380, 360), Vector2(500, 360), Vector2(500, 386), Vector2(380, 386)]},
		],
		"no_build": [],
		"trails": [],
		"decor": [{"kind": "carpet", "rect": Rect2(296, 44, 48, 516)}, {"kind": "carpet", "rect": Rect2(290, 560, 60, 180)},
			{"kind": "brazier", "at": Vector2(270, 620)}, {"kind": "fire", "at": Vector2(270, 612)},
			{"kind": "brazier", "at": Vector2(370, 620)}, {"kind": "fire", "at": Vector2(370, 612)},
			{"kind": "brazier", "at": Vector2(160, 520)}, {"kind": "fire", "at": Vector2(160, 512)},
			{"kind": "brazier", "at": Vector2(480, 520)}, {"kind": "fire", "at": Vector2(480, 512)},
			{"kind": "ogre_banner", "at": Vector2(60, 230)}, {"kind": "ogre_banner", "at": Vector2(580, 230)},
			{"kind": "ogre_banner", "at": Vector2(60, 430)}, {"kind": "ogre_banner", "at": Vector2(580, 430)},
			{"kind": "line_banner", "at": Vector2(200, 310), "angle": 1.2}, {"kind": "line_banner", "at": Vector2(450, 160), "angle": 2.8},
			{"kind": "line_banner", "at": Vector2(330, 440), "angle": 0.2},
			{"kind": "bones", "at": Vector2(120, 520)}, {"kind": "bones", "at": Vector2(500, 120)},
			{"kind": "rubble", "at": Vector2(250, 120)}, {"kind": "rubble", "at": Vector2(540, 520)},
			{"kind": "stain", "at": Vector2(300, 320)}, {"kind": "stain", "at": Vector2(420, 300)}, {"kind": "chains", "at": Vector2(120, 210)},
			{"kind": "rack", "at": Vector2(460, 540)}],
	},
	"dsc_cells": {
		"name": "The Guardroom Cells", "battle": "cells", "music": "calm_cells", "biome": "hall", "camp": false,
		"tint": Color(0.9, 0.88, 0.9),
		"lanes": [],
		"doors": [{"id": "w", "side": "w", "at": Vector2(14, 400)}],
		"terrain": [
			{"kind": "hall", "poly": [Vector2(0, 0), Vector2(30, 0), Vector2(30, 360), Vector2(0, 360)]},
			{"kind": "hall", "poly": [Vector2(0, 440), Vector2(30, 440), Vector2(30, 768), Vector2(0, 768)]},
			{"kind": "hall", "poly": [Vector2(610, 0), Vector2(640, 0), Vector2(640, 768), Vector2(610, 768)]},
			{"kind": "hall", "poly": [Vector2(30, 0), Vector2(610, 0), Vector2(610, 44), Vector2(30, 44)]},
			{"kind": "hall", "poly": [Vector2(30, 740), Vector2(610, 740), Vector2(610, 768), Vector2(30, 768)]},
			{"kind": "hall", "poly": [Vector2(30, 44), Vector2(40, 44), Vector2(40, 190), Vector2(30, 190)]},
			{"kind": "hall", "poly": [Vector2(220, 44), Vector2(240, 44), Vector2(240, 190), Vector2(220, 190)]},
			{"kind": "hall", "poly": [Vector2(400, 44), Vector2(420, 44), Vector2(420, 190), Vector2(400, 190)]},
			{"kind": "hall", "poly": [Vector2(600, 44), Vector2(610, 44), Vector2(610, 190), Vector2(600, 190)]},
			{"kind": "furniture", "poly": [Vector2(140, 560), Vector2(300, 560), Vector2(300, 590), Vector2(140, 590)]},
			{"kind": "furniture", "poly": [Vector2(360, 560), Vector2(500, 560), Vector2(500, 590), Vector2(360, 590)]},
		],
		"no_build": [],
		"trails": [],
		"decor": [{"kind": "chains", "at": Vector2(100, 100)}, {"kind": "chains", "at": Vector2(300, 90)}, {"kind": "chains", "at": Vector2(470, 110)},
			{"kind": "bones", "at": Vector2(560, 120)}, {"kind": "stain", "at": Vector2(320, 330)}, {"kind": "stain", "at": Vector2(180, 420)},
			{"kind": "brazier", "at": Vector2(120, 480)}, {"kind": "fire", "at": Vector2(120, 472)}, {"kind": "brazier", "at": Vector2(520, 480)}, {"kind": "fire", "at": Vector2(520, 472)},
			{"kind": "rack", "at": Vector2(560, 680)}, {"kind": "rack", "at": Vector2(80, 680)}, {"kind": "rubble", "at": Vector2(400, 690)},
			{"kind": "ogre_banner", "at": Vector2(320, 640)}, {"kind": "line_banner", "at": Vector2(240, 400), "angle": 1.0}],
	},
	"dsc_stores": {
		"name": "The Quartermaster's Store", "battle": "stores", "music": "calm_stores", "biome": "hall", "camp": false,
		"tint": Color(0.96, 0.92, 0.9),
		"lanes": [],
		"doors": [{"id": "e", "side": "e", "at": Vector2(626, 400)}],
		"terrain": [
			{"kind": "hall", "poly": [Vector2(0, 0), Vector2(30, 0), Vector2(30, 768), Vector2(0, 768)]},
			{"kind": "hall", "poly": [Vector2(610, 0), Vector2(640, 0), Vector2(640, 360), Vector2(610, 360)]},
			{"kind": "hall", "poly": [Vector2(610, 440), Vector2(640, 440), Vector2(640, 768), Vector2(610, 768)]},
			{"kind": "hall", "poly": [Vector2(30, 0), Vector2(610, 0), Vector2(610, 44), Vector2(30, 44)]},
			{"kind": "hall", "poly": [Vector2(30, 740), Vector2(610, 740), Vector2(610, 768), Vector2(30, 768)]},
			{"kind": "furniture", "poly": [Vector2(80, 100), Vector2(250, 100), Vector2(250, 126), Vector2(80, 126)]},
			{"kind": "furniture", "poly": [Vector2(390, 100), Vector2(560, 100), Vector2(560, 126), Vector2(390, 126)]},
			{"kind": "furniture", "poly": [Vector2(80, 220), Vector2(250, 220), Vector2(250, 246), Vector2(80, 246)]},
			{"kind": "furniture", "poly": [Vector2(390, 220), Vector2(560, 220), Vector2(560, 246), Vector2(390, 246)]},
			{"kind": "furniture", "poly": [Vector2(80, 560), Vector2(250, 560), Vector2(250, 586), Vector2(80, 586)]},
			{"kind": "furniture", "poly": [Vector2(390, 560), Vector2(560, 560), Vector2(560, 586), Vector2(390, 586)]},
			{"kind": "furniture", "poly": [Vector2(80, 660), Vector2(250, 660), Vector2(250, 686), Vector2(80, 686)]},
			{"kind": "pillar", "poly": [Vector2(305, 305), Vector2(335, 305), Vector2(335, 335), Vector2(305, 335)]},
			{"kind": "pillar", "poly": [Vector2(305, 465), Vector2(335, 465), Vector2(335, 495), Vector2(305, 495)]},
		],
		"no_build": [],
		"trails": [],
		"decor": [{"kind": "rubble", "at": Vector2(200, 160)}, {"kind": "rack", "at": Vector2(160, 420)}, {"kind": "rack", "at": Vector2(470, 420)},
			{"kind": "stain", "at": Vector2(420, 640)}, {"kind": "bones", "at": Vector2(560, 690)}, {"kind": "brazier", "at": Vector2(560, 300)}, {"kind": "fire", "at": Vector2(560, 292)},
			{"kind": "ogre_banner", "at": Vector2(70, 380)}],
	},
	"dsc_chapel": {
		"name": "The Chapel of the Dawn", "battle": "chapel", "music": "calm_chapel", "biome": "hall", "camp": false,
		"tint": Color(0.96, 0.92, 0.9),
		"lanes": [[276, 364]],
		"doors": [{"id": "s", "side": "s", "at": Vector2(320, 756), "stand": Vector2(320, 640)}, {"id": "n", "side": "n", "at": Vector2(320, 22)}, {"id": "e", "side": "e", "at": Vector2(626, 400)}],
		"terrain": [
			{"kind": "hall", "poly": [Vector2(0, 0), Vector2(30, 0), Vector2(30, 768), Vector2(0, 768)]},
			{"kind": "hall", "poly": [Vector2(610, 0), Vector2(640, 0), Vector2(640, 360), Vector2(610, 360)]},
			{"kind": "hall", "poly": [Vector2(610, 440), Vector2(640, 440), Vector2(640, 768), Vector2(610, 768)]},
			{"kind": "hall", "poly": [Vector2(30, 0), Vector2(272, 0), Vector2(272, 44), Vector2(30, 44)]},
			{"kind": "hall", "poly": [Vector2(368, 0), Vector2(610, 0), Vector2(610, 44), Vector2(368, 44)]},
			{"kind": "hall", "poly": [Vector2(30, 740), Vector2(272, 740), Vector2(272, 768), Vector2(30, 768)]},
			{"kind": "hall", "poly": [Vector2(368, 740), Vector2(610, 740), Vector2(610, 768), Vector2(368, 768)]},
			{"kind": "altar", "poly": [Vector2(250, 116), Vector2(390, 116), Vector2(390, 142), Vector2(250, 142)]},
			{"kind": "pillar", "poly": [Vector2(65, 205), Vector2(95, 205), Vector2(95, 235), Vector2(65, 235)]},
			{"kind": "pillar", "poly": [Vector2(545, 205), Vector2(575, 205), Vector2(575, 235), Vector2(545, 235)]},
			{"kind": "pillar", "poly": [Vector2(65, 505), Vector2(95, 505), Vector2(95, 535), Vector2(65, 535)]},
			{"kind": "pillar", "poly": [Vector2(545, 505), Vector2(575, 505), Vector2(575, 535), Vector2(545, 535)]},
			{"kind": "furniture", "poly": [Vector2(110, 250), Vector2(250, 250), Vector2(250, 264), Vector2(110, 264)]},
			{"kind": "furniture", "poly": [Vector2(110, 320), Vector2(250, 320), Vector2(250, 334), Vector2(110, 334)]},
			{"kind": "furniture", "poly": [Vector2(110, 390), Vector2(250, 390), Vector2(250, 404), Vector2(110, 404)]},
			{"kind": "furniture", "poly": [Vector2(110, 460), Vector2(250, 460), Vector2(250, 474), Vector2(110, 474)]},
			{"kind": "furniture", "poly": [Vector2(110, 530), Vector2(250, 530), Vector2(250, 544), Vector2(110, 544)]},
			{"kind": "furniture", "poly": [Vector2(390, 250), Vector2(530, 250), Vector2(530, 264), Vector2(390, 264)]},
			{"kind": "furniture", "poly": [Vector2(390, 320), Vector2(530, 320), Vector2(530, 334), Vector2(390, 334)]},
			{"kind": "furniture", "poly": [Vector2(390, 390), Vector2(530, 390), Vector2(530, 404), Vector2(390, 404)]},
			{"kind": "furniture", "poly": [Vector2(390, 460), Vector2(530, 460), Vector2(530, 474), Vector2(390, 474)]},
			{"kind": "furniture", "poly": [Vector2(390, 530), Vector2(530, 530), Vector2(530, 544), Vector2(390, 544)]},
		],
		"no_build": [],
		"trails": [],
		"decor": [{"kind": "carpet", "rect": Rect2(296, 100, 48, 640)}, {"kind": "mosaic", "at": Vector2(320, 196), "r": 44.0},
			{"kind": "brazier", "at": Vector2(220, 90)}, {"kind": "fire", "at": Vector2(220, 82)}, {"kind": "brazier", "at": Vector2(420, 90)}, {"kind": "fire", "at": Vector2(420, 82)},
			{"kind": "ogre_banner", "at": Vector2(170, 200)}, {"kind": "ogre_banner", "at": Vector2(470, 200)},
			{"kind": "line_banner", "at": Vector2(150, 620), "angle": 0.6}, {"kind": "line_banner", "at": Vector2(500, 620), "angle": 2.4},
			{"kind": "bones", "at": Vector2(80, 380)}, {"kind": "bones", "at": Vector2(560, 680)}, {"kind": "stain", "at": Vector2(330, 420)},
			{"kind": "rubble", "at": Vector2(90, 680)}, {"kind": "rubble", "at": Vector2(560, 120)}, {"kind": "sconce", "at": Vector2(60, 300)}, {"kind": "sconce", "at": Vector2(580, 300)}],
	},
	"dsc_dungeon": {
		"name": "The Deep Cells", "battle": "dungeon", "music": "calm_dungeon", "biome": "hall", "camp": false,
		"tint": Color(0.84, 0.82, 0.88),
		"lanes": [],
		"doors": [{"id": "w", "side": "w", "at": Vector2(14, 400)}],
		"terrain": [
			{"kind": "hall", "poly": [Vector2(0, 0), Vector2(30, 0), Vector2(30, 360), Vector2(0, 360)]},
			{"kind": "hall", "poly": [Vector2(0, 440), Vector2(30, 440), Vector2(30, 768), Vector2(0, 768)]},
			{"kind": "hall", "poly": [Vector2(610, 0), Vector2(640, 0), Vector2(640, 768), Vector2(610, 768)]},
			{"kind": "hall", "poly": [Vector2(30, 0), Vector2(610, 0), Vector2(610, 44), Vector2(30, 44)]},
			{"kind": "hall", "poly": [Vector2(30, 740), Vector2(610, 740), Vector2(610, 768), Vector2(30, 768)]},
			{"kind": "hall", "poly": [Vector2(30, 250), Vector2(140, 250), Vector2(140, 280), Vector2(30, 280)]},
			{"kind": "hall", "poly": [Vector2(220, 250), Vector2(420, 250), Vector2(420, 280), Vector2(220, 280)]},
			{"kind": "hall", "poly": [Vector2(500, 250), Vector2(610, 250), Vector2(610, 280), Vector2(500, 280)]},
			{"kind": "hall", "poly": [Vector2(30, 520), Vector2(140, 520), Vector2(140, 550), Vector2(30, 550)]},
			{"kind": "hall", "poly": [Vector2(220, 520), Vector2(420, 520), Vector2(420, 550), Vector2(220, 550)]},
			{"kind": "hall", "poly": [Vector2(500, 520), Vector2(610, 520), Vector2(610, 550), Vector2(500, 550)]},
			{"kind": "hall", "poly": [Vector2(310, 44), Vector2(330, 44), Vector2(330, 250), Vector2(310, 250)]},
			{"kind": "hall", "poly": [Vector2(310, 550), Vector2(330, 550), Vector2(330, 740), Vector2(310, 740)]},
		],
		"no_build": [],
		"trails": [],
		"decor": [{"kind": "chains", "at": Vector2(150, 120)}, {"kind": "chains", "at": Vector2(450, 650)}, {"kind": "bones", "at": Vector2(500, 120)},
			{"kind": "bones", "at": Vector2(120, 660)}, {"kind": "stain", "at": Vector2(320, 400)}, {"kind": "stain", "at": Vector2(470, 380)},
			{"kind": "brazier", "at": Vector2(560, 400)}, {"kind": "fire", "at": Vector2(560, 392)}, {"kind": "rubble", "at": Vector2(250, 330)},
			{"kind": "sconce", "at": Vector2(180, 300)}, {"kind": "sconce", "at": Vector2(460, 300)}],
	},
	"dsc_gallery": {
		"name": "The Long Gallery", "battle": "gallery", "music": "calm_gallery", "biome": "hall", "camp": false,
		"tint": Color(0.96, 0.92, 0.9),
		"lanes": [[276, 364]],
		"doors": [{"id": "s", "side": "s", "at": Vector2(320, 756), "stand": Vector2(320, 600)}, {"id": "n", "side": "n", "at": Vector2(320, 22)}, {"id": "w", "side": "w", "at": Vector2(14, 400)}],
		"terrain": [
			{"kind": "hall", "poly": [Vector2(0, 0), Vector2(30, 0), Vector2(30, 360), Vector2(0, 360)]},
			{"kind": "hall", "poly": [Vector2(0, 440), Vector2(30, 440), Vector2(30, 768), Vector2(0, 768)]},
			{"kind": "hall", "poly": [Vector2(610, 0), Vector2(640, 0), Vector2(640, 768), Vector2(610, 768)]},
			{"kind": "hall", "poly": [Vector2(30, 0), Vector2(272, 0), Vector2(272, 44), Vector2(30, 44)]},
			{"kind": "hall", "poly": [Vector2(368, 0), Vector2(610, 0), Vector2(610, 44), Vector2(368, 44)]},
			{"kind": "hall", "poly": [Vector2(30, 740), Vector2(272, 740), Vector2(272, 768), Vector2(30, 768)]},
			{"kind": "hall", "poly": [Vector2(368, 740), Vector2(610, 740), Vector2(610, 768), Vector2(368, 768)]},
			{"kind": "pillar", "poly": [Vector2(135, 125), Vector2(165, 125), Vector2(165, 155), Vector2(135, 155)]},
			{"kind": "pillar", "poly": [Vector2(135, 245), Vector2(165, 245), Vector2(165, 275), Vector2(135, 275)]},
			{"kind": "pillar", "poly": [Vector2(135, 365), Vector2(165, 365), Vector2(165, 395), Vector2(135, 395)]},
			{"kind": "pillar", "poly": [Vector2(135, 485), Vector2(165, 485), Vector2(165, 515), Vector2(135, 515)]},
			{"kind": "pillar", "poly": [Vector2(135, 605), Vector2(165, 605), Vector2(165, 635), Vector2(135, 635)]},
			{"kind": "pillar", "poly": [Vector2(475, 125), Vector2(505, 125), Vector2(505, 155), Vector2(475, 155)]},
			{"kind": "pillar", "poly": [Vector2(475, 245), Vector2(505, 245), Vector2(505, 275), Vector2(475, 275)]},
			{"kind": "pillar", "poly": [Vector2(475, 365), Vector2(505, 365), Vector2(505, 395), Vector2(475, 395)]},
			{"kind": "pillar", "poly": [Vector2(475, 485), Vector2(505, 485), Vector2(505, 515), Vector2(475, 515)]},
			{"kind": "pillar", "poly": [Vector2(475, 605), Vector2(505, 605), Vector2(505, 635), Vector2(475, 635)]},
			{"kind": "hall", "poly": [Vector2(30, 180), Vector2(90, 180), Vector2(90, 220), Vector2(30, 220)]},
			{"kind": "hall", "poly": [Vector2(550, 300), Vector2(610, 300), Vector2(610, 340), Vector2(550, 340)]},
			{"kind": "hall", "poly": [Vector2(30, 560), Vector2(90, 560), Vector2(90, 600), Vector2(30, 600)]},
			{"kind": "hall", "poly": [Vector2(550, 460), Vector2(610, 460), Vector2(610, 500), Vector2(550, 500)]},
		],
		"no_build": [],
		"trails": [],
		"decor": [{"kind": "carpet", "rect": Rect2(296, 44, 48, 696)},
			{"kind": "brazier", "at": Vector2(230, 200)}, {"kind": "fire", "at": Vector2(230, 192)}, {"kind": "brazier", "at": Vector2(410, 200)}, {"kind": "fire", "at": Vector2(410, 192)},
			{"kind": "brazier", "at": Vector2(230, 560)}, {"kind": "fire", "at": Vector2(230, 552)}, {"kind": "brazier", "at": Vector2(410, 560)}, {"kind": "fire", "at": Vector2(410, 552)},
			{"kind": "ogre_banner", "at": Vector2(80, 300)}, {"kind": "ogre_banner", "at": Vector2(560, 600)}, {"kind": "ogre_banner", "at": Vector2(560, 160)},
			{"kind": "line_banner", "at": Vector2(250, 380), "angle": 1.8}, {"kind": "line_banner", "at": Vector2(400, 470), "angle": 0.3},
			{"kind": "bones", "at": Vector2(380, 300)}, {"kind": "rubble", "at": Vector2(100, 440)}, {"kind": "stain", "at": Vector2(300, 640)},
			{"kind": "sconce", "at": Vector2(60, 140)}, {"kind": "sconce", "at": Vector2(580, 400)}],
	},
	"dsc_treasury": {
		"name": "The Treasury", "battle": "treasury", "music": "calm_treasury", "biome": "hall", "camp": false,
		"tint": Color(1.0, 0.94, 0.86),
		"lanes": [],
		"doors": [{"id": "e", "side": "e", "at": Vector2(626, 400)}],
		"terrain": [
			{"kind": "hall", "poly": [Vector2(0, 0), Vector2(30, 0), Vector2(30, 768), Vector2(0, 768)]},
			{"kind": "hall", "poly": [Vector2(610, 0), Vector2(640, 0), Vector2(640, 360), Vector2(610, 360)]},
			{"kind": "hall", "poly": [Vector2(610, 440), Vector2(640, 440), Vector2(640, 768), Vector2(610, 768)]},
			{"kind": "hall", "poly": [Vector2(30, 0), Vector2(610, 0), Vector2(610, 44), Vector2(30, 44)]},
			{"kind": "hall", "poly": [Vector2(30, 740), Vector2(610, 740), Vector2(610, 768), Vector2(30, 768)]},
			{"kind": "hall", "poly": [Vector2(140, 140), Vector2(180, 140), Vector2(180, 330), Vector2(140, 330)]},
			{"kind": "hall", "poly": [Vector2(140, 450), Vector2(180, 450), Vector2(180, 640), Vector2(140, 640)]},
			{"kind": "hall", "poly": [Vector2(180, 140), Vector2(280, 140), Vector2(280, 170), Vector2(180, 170)]},
			{"kind": "hall", "poly": [Vector2(180, 610), Vector2(280, 610), Vector2(280, 640), Vector2(180, 640)]},
			{"kind": "pillar", "poly": [Vector2(405, 215), Vector2(435, 215), Vector2(435, 245), Vector2(405, 245)]},
			{"kind": "pillar", "poly": [Vector2(405, 555), Vector2(435, 555), Vector2(435, 585), Vector2(405, 585)]},
		],
		"no_build": [],
		"trails": [],
		"decor": [{"kind": "mosaic", "at": Vector2(110, 400), "r": 34.0}, {"kind": "rubble", "at": Vector2(500, 120)}, {"kind": "bones", "at": Vector2(520, 680)},
			{"kind": "brazier", "at": Vector2(330, 120)}, {"kind": "fire", "at": Vector2(330, 112)}, {"kind": "brazier", "at": Vector2(330, 680)}, {"kind": "fire", "at": Vector2(330, 672)},
			{"kind": "ogre_banner", "at": Vector2(250, 400)}, {"kind": "rack", "at": Vector2(500, 400)}, {"kind": "chains", "at": Vector2(560, 240)}],
	},
}


static func get_map(id: String) -> Dictionary:
	return MAPS.get(id, ZONES.get(id, {}))


## Map `m` stretched across a field `w` wide: every x (terrain, lanes, trails, no-build
## zones, the bot's posts) scaled by w / BASE_W; heights stay as they are.
static func fitted(m: Dictionary, w: float) -> Dictionary:
	if m.is_empty() or (is_equal_approx(w, BASE_W) and not m.has("islands")):
		return m
	var k := w / BASE_W
	var out := m.duplicate(true)
	var sx := func(p: Vector2) -> Vector2: return Vector2(p.x * k, p.y)
	for t in out.get("terrain", []):
		if t["kind"] == "fountain":
			# A fountain stays round, the size it is: only moved along with the field.
			var c := Vector2.ZERO
			for q in t["poly"]:
				c += q
			c /= (t["poly"] as Array).size()
			var dx := c.x * (k - 1.0)
			t["poly"] = (t["poly"] as Array).map(func(p: Vector2) -> Vector2: return p + Vector2(dx, 0))
		else:
			t["poly"] = (t["poly"] as Array).map(sx)
	out["lanes"] = out.get("lanes", []).map(func(l): return [l[0] * k, l[1] * k])
	out["trails"] = out.get("trails", []).map(func(tr): return (tr as Array).map(sx))
	out["no_build"] = out.get("no_build", []).map(func(r: Rect2): return Rect2(r.position.x * k, r.position.y, r.size.x * k, r.size.y))
	out["bot_posts"] = out.get("bot_posts", []).map(sx)
	if out.has("route"):
		out["route"] = (out["route"] as Array).map(sx)
	if out.has("lanterns"):
		out["lanterns"] = (out["lanterns"] as Array).map(sx)
	for d in out.get("decor", []):
		if d.has("at"):
			d["at"] = sx.call(d["at"])
		if d.has("rect"):
			var r: Rect2 = d["rect"]
			d["rect"] = Rect2(r.position.x * k, r.position.y, r.size.x * k, r.size.y)
	if out.has("islands"):
		# Floating islands: stretched with the field (a circle becomes as much wider as the
		# field is), their bridges and lands with them; and everything else is the void,
		# which nothing walks on (added to the terrain, worked out once for each width).
		out["islands"] = (out["islands"] as Array).map(func(i): return {"at": sx.call(i["at"]), "r": i["r"], "rx": i["r"] * k, "path": i.get("path", -1)})
		out["bridges"] = (out.get("bridges", []) as Array).map(func(b): return {"from": sx.call(b["from"]), "to": sx.call(b["to"]), "w": b["w"], "path": b.get("path", -1)})
		out["lands"] = (out.get("lands", []) as Array).map(func(r: Rect2): return Rect2(r.position.x * k, r.position.y, r.size.x * k, r.size.y))
		out["terrain"] = (out["terrain"] as Array) + _void(out, w)
	return out


## The floating islands' walkable shapes: each island (an ellipse of 28 sides), each
## bridge (a band `w` wide from end to end, reaching a little into the islands it joins),
## and each land (a rectangle: the camp's ground, the castle's).
static func walkable(m: Dictionary) -> Array:
	var out := []
	for i in m.get("islands", []):
		var poly := PackedVector2Array()
		for n in 28:
			var a := n * TAU / 28.0
			poly.append(i["at"] + Vector2(cos(a) * float(i.get("rx", i["r"])), sin(a) * float(i["r"])))
		out.append(poly)
	for b in m.get("bridges", []):
		var a: Vector2 = b["from"]
		var z: Vector2 = b["to"]
		var d := (z - a).normalized()
		var n := Vector2(-d.y, d.x) * float(b["w"]) / 2.0
		a -= d * 14.0
		z += d * 14.0
		out.append(PackedVector2Array([a + n, z + n, z - n, a - n]))
	for r in m.get("lands", []):
		out.append(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
	return out


static var _void_cache := {}


## The void: the field (and a margin round it) less every walkable shape, as terrain
## nothing walks on. Cut in thin horizontal bands, so no piece ever has a hole in it.
static func _void(m: Dictionary, w: float) -> Array:
	var key := "%s@%d" % [m.get("name", ""), roundi(w)]
	if _void_cache.has(key):
		return _void_cache[key]
	var walk := walkable(m)
	var out := []
	var band := 24.0
	var y := -150.0
	while y < 800.0:
		var pieces := [PackedVector2Array([Vector2(-60, y), Vector2(w + 60, y), Vector2(w + 60, y + band), Vector2(-60, y + band)])]
		for shape in walk:
			var next := []
			for piece in pieces:
				for cut in Geometry2D.clip_polygons(piece, shape):
					if absf(_area(cut)) > 6.0:   # (thin bands: never a hole, only slivers to drop)
						next.append(cut)
			pieces = next
		for piece in pieces:
			out.append({"kind": "void", "poly": Array(piece)})
		y += band
	_void_cache[key] = out
	return out


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a / 2.0
