extends RefCounted
## Campaign battlefields: the ground each mission is fought on. A mission names its map
## with "map" (campaign_data.gd); Classic, Freeplay and the Tutorial have none and keep
## the open meadow.
##
## Coordinates are on the campaign field: 640 wide, the enemy camp above y 96, the
## castle wall at y 736. Each map has:
##   name       what Classic's battlefield picker calls it
##   biome      which ground painter and palette (field_art.gd): "meadow" or "mountain"
##   lanes      [x from, x to] stretches of the top edge where enemies come in
##   terrain    shapes that block walking (not flying, not shots): {"kind", "poly"} with
##              kind "rock", "cliff", "trees" or "pit" (it only changes the art)
##   no_build   rectangles nothing may be posted or built in (barricades aside)
##   trails     paths worn into the ground through the gaps (just paint)
##   castle     the castle's style (castle.gd STYLES)
##   music      its peaceful music between waves (audio.gd STAGE_TRACKS; by default the
##              biome's: "calm" for the meadow, "mountain" for the mountains)
##   bot_posts  where the balance test's bot holds its line (the map's chokepoints)
## Terrain along the top edge reaches well above it (y -120), since enemies come in
## from just above the field.
## Any gap meant to be walked through is at least 64px wide, so a Warlord (radius 24)
## gets through with room; tests/terrain_test.gd checks every lane reaches the castle.

const MAPS := {
	# Ashwatch Keep: an open meadow with a rocky ridge across the middle, broken by two
	# gaps (about 70 and 78px). Two short lines of Swordsmen can hold them.
	"ashwatch_ridge": {
		"name": "Ashwatch Ridge",
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
		"name": "Stonehollow Quarry",
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
}


static func get_map(id: String) -> Dictionary:
	return MAPS.get(id, {})
