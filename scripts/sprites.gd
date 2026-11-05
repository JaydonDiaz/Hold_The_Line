extends RefCounted
## Pixel-art sprites defined as text and turned into textures on first use.
## Each sprite is 16x16. "k" is the outline color, "." is transparent, other letters
## come from the sprite's palette (falling back to COMMON). legs_b replaces the
## bottom rows to make the second walk frame.

const SIZE := 16
const OUTLINE := Color(0.1, 0.07, 0.1)
const COMMON := {
	"s": Color(0.96, 0.77, 0.6),   # skin
	"p": Color(0.32, 0.27, 0.38),  # pants
	"f": Color(0.3, 0.19, 0.12),   # boots
}

const SPRITES := {
	"swordsman": {
		"poses": {
			"swing": {
				1: "....................kk",
				2: "............____...kwk",
				3: "............____..kwk",
				4: "............____.kwk",
				5: "............____kwk",
				6: "............___kwk",
				7: "............__kwk",
				8: "............gkwk",
				9: "............kgk_",
				10: "............skg",
			},
			"plant": {  # idle: leaning on the sword, point planted in the dirt
				2: "............____",
				3: "............____",
				4: "............____",
				5: "............____",
				6: "............kgk_",
				7: "............ksk_",
				8: "...........kgggk",
				9: "............kwk_",
				10: "..........bkkwk_",
				11: "............kwk.",
				12: "............kwk.",
				13: "............kwk.",
				14: "............kwk.",
				15: "............_k..",
			},
			"strike": {
				2: "............____",
				3: "............____",
				4: "............____",
				5: "............____",
				6: "............____",
				7: "............_k__",
				8: "............kgkkkkkkkk",
				9: "............sgwwwwwwwwk",
				10: "............kgkkkkkkkk",
			},
		},
		"palette": {
			"r": Color(0.85, 0.2, 0.2), "h": Color(0.78, 0.8, 0.86), "H": Color(0.52, 0.55, 0.64),
			"t": Color(0.9, 0.72, 0.3), "T": Color(0.68, 0.5, 0.2), "b": Color(0.42, 0.26, 0.12),
			"w": Color(0.93, 0.95, 1.0), "g": Color(0.6, 0.4, 0.15),
		},
		"rows": [
			"......rr........",
			".....krrk.......",
			"....khhhhk....k.",
			"...khhhhhHk..kwk",
			"...khkkkkHk..kwk",
			"...khhhhhHk..kwk",
			"....kssssk...kwk",
			"..kkTttttTkk.kwk",
			"..kTttttttTk.kwk",
			"..kTttttttTkgggk",
			"..ksbbbbbbskskk.",
			"..kTttttttTk.k..",
			"...kTttttTk.....",
			"...kppkkppk.....",
			"...kffk.kffk....",
			"...kkkk.kkkk....",
		],
		"legs_b": [
			"...kppkppk......",
			"....kffkffk.....",
			"....kkkkkkk.....",
		],
	},
	"archer": {
		"poses": {
			"draw": {
				2: "..............__k",
				3: "............_k__bk",
				4: "............s__wbk",
				5: "............._w_.bk",
				6: ".............w__.bk",
				7: ".............w__.bk",
				8: ".............seeeseak",
				9: ".............w__.bk",
				10: "............._w_bk",
				11: ".............__wbk",
				12: "............._..k",
			},
		},
		"palette": {
			"g": Color(0.35, 0.65, 0.3), "G": Color(0.22, 0.45, 0.2), "l": Color(0.6, 0.42, 0.25),
			"L": Color(0.42, 0.28, 0.15), "b": Color(0.62, 0.4, 0.18), "w": Color(0.92, 0.9, 0.85),
			"a": Color(0.8, 0.82, 0.88), "e": Color(0.92, 0.88, 0.78),
		},
		"rows": [
			"................",
			".....kkkkk......",
			"....kgggggk...k.",
			".k.kgggggggk.kbk",
			".kskgGsssGgkswbk",
			"..kkGskssksGkw.b",
			"...kGssssssGkw.b",
			".kGkkGGGGGGkkw.b",
			"kGklllllllllkssb",
			"kGkLklllllkLkw.b",
			".kkskLLLLLkskwbk",
			"...kllllllk..bk.",
			"...kppppppk..k..",
			"...kppkkppk.....",
			"...kffk.kffk....",
			"...kkkk.kkkk....",
		],
		"legs_b": [
			"...kppkppk......",
			"....kffkffk.....",
			"....kkkkkkk.....",
		],
	},
	"mage": {
		"poses": {
			"cast": {
				0: "............____",
				1: "............____",
				2: "............____",
				3: "............____",
				4: "............____",
				5: "............____",
				6: "............____......k",
				7: "............_kkkkkkkkkok",
				8: ".............swwwwwwwOook",
				9: "............._kkkkkkkkok",
				10: "..............__......k",
				11: "..............__",
				12: "..............__",
				13: "..............__",
				14: "..............__",
			},
		},
		"palette": {
			"P": Color(0.45, 0.25, 0.65), "Q": Color(0.3, 0.15, 0.45), "y": Color(1.0, 0.85, 0.3),
			"W": Color(0.92, 0.92, 0.95), "r": Color(0.62, 0.38, 0.88), "R": Color(0.42, 0.22, 0.62),
			"w": Color(0.55, 0.35, 0.15), "o": Color(0.85, 0.55, 1.0), "O": Color(1.0, 0.92, 1.0),
		},
		"rows": [
			".......kk.....k.",
			"......kPPk...kok",
			"......kPPk..kOok",
			".....kPPyPk..kok",
			"....kPPPPQPk.kwk",
			"..kQQQQQQQQk.kwk",
			"....kskssksk.kwk",
			"....kWWWWWWk.swk",
			"...krWWWWWWrkswk",
			"...krrWWWWrrk.wk",
			"..krrrWWrrrRk.wk",
			"..kRrrrrrrrRk.wk",
			"..kRrrrrrrrRk.wk",
			"..kRRrrrrrRRk.wk",
			"...kkfkkfkkk..k.",
			"....kk..kk......",
		],
		"legs_b": [
			"...kkkfkkfkk..k.",
			".....kk..kk.....",
		],
	},
	"frost": {
		"poses": {
			"cast": {
				0: "............____",
				1: "............____",
				2: "............____",
				3: "............____",
				4: "............_kkkkkkkkkk",
				5: ".............swwwwwwwiIk",
				6: "............_kkkkkkkkkk",
				7: "..............__",
				8: "..............__",
				9: "..............__",
				10: "..............__",
				11: "..............__",
				12: "..............__",
				13: "..............__",
				14: "..............__",
			},
		},
		"palette": {
			"c": Color(0.55, 0.85, 1.0), "C": Color(0.35, 0.6, 0.85), "h": Color(0.95, 0.97, 1.0),
			"s": Color(0.98, 0.86, 0.78), "r": Color(0.45, 0.7, 0.95), "R": Color(0.3, 0.5, 0.8),
			"w": Color(0.7, 0.75, 0.85), "i": Color(0.75, 0.95, 1.0), "I": Color(1.0, 1.0, 1.0),
		},
		"rows": [
			".....kkkk.....k.",
			"....kcccck...kik",
			"...kccccccCk.kIk",
			"...kchhhhhCk..k.",
			"...khskssksk..wk",
			"...khssssshk.swk",
			"...kkhhhhhkk.kwk",
			"..kCrrrrrrrCk.wk",
			"..kCrRrrrRrCk.wk",
			"..kCrrrrrrrCk.wk",
			"...kRrrrrrRk..wk",
			"...kRrrrrrRk..wk",
			"..kRRrrrrrRRk.wk",
			"..kRRRrrrRRRk.wk",
			"...kkkfkfkkk..k.",
			"................",
		],
		"legs_b": [
			"...kkfkkkfkk..k.",
			"................",
		],
	},
	"goblin": {
		"palette": {
			"g": Color(0.45, 0.72, 0.28), "G": Color(0.3, 0.52, 0.18), "e": Color(1.0, 0.85, 0.2),
			"m": Color(0.3, 0.1, 0.1), "b": Color(0.5, 0.35, 0.2), "B": Color(0.36, 0.24, 0.13),
			"w": Color(0.85, 0.87, 0.9),
		},
		"rows": [
			"................",
			"................",
			"................",
			".kk..........kk.",
			".kGk..kkkk..kGk.",
			"..kGkkggggkkGk..",
			"..kgGggggggGgk..",
			"...kkgeggegkk...",
			"....kggggggk....",
			"....kggmmggk....",
			".....kkggkk.....",
			"....kbbbbbbk.k..",
			"...kgkBbbBkgkwk.",
			"....kkbbbbkk.k..",
			".....kgk.kgk....",
			".....kkk.kkk....",
		],
		"legs_b": [
			"....kgk..kgk....",
			"....kkk...kkk...",
		],
	},
	"orc": {
		"palette": {
			"g": Color(0.4, 0.55, 0.3), "G": Color(0.28, 0.4, 0.2), "e": Color(0.95, 0.3, 0.2),
			"t": Color(0.95, 0.92, 0.8), "a": Color(0.45, 0.35, 0.3), "A": Color(0.32, 0.24, 0.2),
			"x": Color(0.75, 0.78, 0.85), "w": Color(0.5, 0.32, 0.15), "p": Color(0.3, 0.25, 0.22),
		},
		"rows": [
			"................",
			".....kkkkkk.....",
			"....kggggggk.kk.",
			"...kgggggggGkxxk",
			"...kgeggggeGkxwk",
			"...kgtggggtGk.wk",
			"...kkggggggkk.wk",
			".kaaaaaaaaaaAkwk",
			".kgkaaaaaaaakgwk",
			".kgkaAaaaaAakgwk",
			".kgkaaaaaaaakkwk",
			"..kkAAAAAAAAk.wk",
			"...kpppppppk..k.",
			"...kppkkkppk....",
			"...kGGk.kGGk....",
			"...kkkk.kkkk....",
		],
		"legs_b": [
			"...kppkkppk.....",
			"..kGGk..kGGk....",
			"..kkkk..kkkk....",
		],
	},
	"wolf": {
		"palette": {
			"g": Color(0.6, 0.6, 0.66), "G": Color(0.42, 0.42, 0.5), "w": Color(0.82, 0.82, 0.86),
			"e": Color(1.0, 0.85, 0.2), "n": Color(0.1, 0.07, 0.1),
		},
		"rows": [
			"................",
			"................",
			"................",
			"................",
			"...........k.k..",
			"..........kGkGk.",
			"..........kgggk.",
			"k........kggegkk",
			"kgk.kkkkkgggggnk",
			".kgkgggggggggkk.",
			"..kgggggggggGk..",
			"..kGgggggggGGk..",
			"..kGwwwwwwwGk...",
			"..kGkGk..kGkGk..",
			"..kGkGk..kGkGk..",
			"..kkkkk..kkkkk..",
		],
		"legs_b": [
			".kGk.kGkkGk.kGk.",
			"kGk...kGGk...kGk",
			"kk.....kk.....kk",
		],
	},
	"bat": {  # A giant bat; the second frame sweeps the wings down
		"palette": {
			"b": Color(0.35, 0.26, 0.4), "B": Color(0.5, 0.4, 0.55), "w": Color(0.55, 0.38, 0.5),
			"e": Color(1.0, 0.3, 0.25),
		},
		"rows": [
			"................",
			"................",
			"................",
			"kk....k..k....kk",
			"kwk..kbkkbk..kwk",
			"kwwkkbbbbbbkkwwk",
			"kwwwkbebbebkwwwk",
			".kwwwbbbbbbwwwk.",
			"..kwkbbBBbbkwk..",
			"...k.kbbbbk.k...",
			"......kbbk......",
			"......k..k......",
			"................",
			"................",
			"................",
			"................",
		],
		"legs_b": [
			"......k..k......",
			".....kbkkbk.....",
			".....kbbbbk.....",
			"....kbebbebk....",
			"..kkkbbbbbbkkk..",
			".kwwkbbBBbbkwwk.",
			"kwwwwkbbbbkwwwwk",
			"kwwk.kkbbkk.kwwk",
			"kwk...k..k...kwk",
			".k............k.",
			"................",
			"................",
			"................",
		],
	},
	"barricade": {  # A stretch of palisade: sharpened stakes lashed to a crossbeam (the hire button's icon)
		"palette": {
			"W": Color(0.8, 0.6, 0.35), "w": Color(0.6, 0.41, 0.22), "D": Color(0.55, 0.37, 0.2),
			"d": Color(0.42, 0.27, 0.14), "m": Color(0.72, 0.72, 0.78),
		},
		"rows": [
			"................",
			".......kk.......",
			".kk...kWwk...kk.",
			"kWwk..kWwkkkkWwk",
			"kWwkkkkWwkWwkWwk",
			"kWwkWwkWwkWwkWwk",
			"kWwkWwkWwkWwkWwk",
			"kkkkkkkkkkkkkkkk",
			"kDDDDDDDDDDDDDDk",
			"kdmddddddddddmdk",
			"kkkkkkkkkkkkkkkk",
			"kWwkWwkWwkWwkWwk",
			"kWwkWwkWwkWwkWwk",
			"kWwkWwkWwkWwkWwk",
			"kWwkWwkWwkWwkWwk",
			"kkkkkkkkkkkkkkkk",
		],
	},
	"wyvern": {  # A green wyvern, horned, wings spread; the second frame beats them down
		"palette": {
			"g": Color(0.3, 0.55, 0.45), "G": Color(0.62, 0.78, 0.5), "w": Color(0.6, 0.3, 0.3),
			"e": Color(1.0, 0.8, 0.2), "h": Color(0.92, 0.88, 0.75),
		},
		"rows": [
			"......k..k......",
			".....khkkhk.....",
			"k....kggggk....k",
			"kk...keggek...kk",
			"kwk..kgGGgk..kwk",
			"kwwk.kkggkk.kwwk",
			"kwwwkggggggkwwwk",
			"kwwwwgGGGGgwwwwk",
			".kwwwgGGGGgwwwk.",
			"..kwkggGGggkwk..",
			"...k.kggggk.k...",
			"......kggk......",
			".......kgk......",
			"........kgk.....",
			".........kk.....",
			"................",
		],
		"legs_b": [
			".....kggggk.....",
			".....keggek.....",
			".....kgGGgk.....",
			"..kkkkkggkkkkk..",
			".kwwkggggggkwwk.",
			"kwwwwgGGGGgwwwwk",
			"kwwwwgGGGGgwwwwk",
			"kwwkkggGGggkkwwk",
			"kwk..kggggk..kwk",
			".k....kggk....k.",
			".......kgk......",
			"........kgk.....",
			".........kk.....",
			"................",
		],
	},
	"sapper": {  # A goblin hugging a lit bomb
		"base": "goblin",
		"palette": {
			"b": Color(0.3, 0.3, 0.37), "B": Color(0.62, 0.62, 0.7), "r": Color(0.85, 0.45, 0.15),
			"y": Color(1.0, 0.9, 0.3),
		},
		"rows": [
			"................",
			"................",
			"................",
			".kk..........kk.",
			".kGk..kkkk..kGk.",
			"..kGkkggggkkGk..",
			"..kgGggggggGgk..",
			"...kkgeggegkk...",
			"....kggggggk....",
			"....kggmmggk..y.",
			"....kkkkkkkkkr..",
			"..kgkbBBbbbbkgk.",
			"..kgkbBbbbbbkgk.",
			"...kkbbbbbbbkk..",
			".....kkkkkkk....",
			".....kgk.kgk....",
		],
		"legs_b": [
			"....kgk...kgk...",
			"....kkk...kkk...",
		],
	},
	"ogre_king": {  # The final boss: a crowned ogre with a spiked club
		"palette": {
			"g": Color(0.5, 0.6, 0.35), "G": Color(0.36, 0.45, 0.25), "y": Color(1.0, 0.82, 0.25),
			"R": Color(0.85, 0.15, 0.2), "e": Color(1.0, 0.3, 0.2), "t": Color(0.95, 0.92, 0.8),
			"a": Color(0.55, 0.3, 0.25), "Y": Color(1.0, 0.82, 0.25), "W": Color(0.45, 0.3, 0.15),
			"s": Color(0.5, 0.6, 0.35), "p": Color(0.3, 0.25, 0.22),
		},
		"rows": [
			"...k.k.k.k......",
			"...kykykyk......",
			"...kyyRyyk...kk.",
			"..kgggggggk.kWWk",
			"..kgegggegk.kWWk",
			"..kgggggggk..kWk",
			"..kgtkkktgk..kWk",
			".kkkgggggkkk.kWk",
			"kgaaaaaaaaagkkWk",
			"kgkaaaaaaakgsWk.",
			"kgkaaYaaaakgkWk.",
			".kkaaaaaaaakkk..",
			"..kppppppppk....",
			"..kppkkkkppk....",
			"..kGGk..kGGk....",
			"..kkkk..kkkk....",
		],
		"legs_b": [
			"..kppk..kppk....",
			".kGGk....kGGk...",
			".kkkk....kkkk...",
		],
	},
	"troll": {
		"palette": {
			"g": Color(0.5, 0.6, 0.65), "G": Color(0.35, 0.43, 0.5), "e": Color(1.0, 0.85, 0.2),
			"t": Color(0.95, 0.92, 0.8), "l": Color(0.5, 0.35, 0.2), "c": Color(0.45, 0.3, 0.15),
			"C": Color(0.32, 0.2, 0.1),
		},
		"rows": [
			"................",
			"....kkkkkk......",
			"...kggggggk..kk.",
			"..kggggggggkkcck",
			"..kgeggggegkkcCk",
			"..kgtggggtgkkcCk",
			".kkgggggggggk.ck",
			"kgggGGGGGGgggkck",
			"kgkgGGGGGGgkggck",
			"kgkgggggggggk.ck",
			".kklllllllllk.ck",
			"..klllllllllk.kk",
			"..kgggkkkgggk...",
			"..kgggk.kgggk...",
			".kGGGGk.kGGGGk..",
			".kkkkkk.kkkkkk..",
		],
		"legs_b": [
			"..kgggkkgggk....",
			"...kgggkkgggk...",
			"..kGGGGkGGGGk...",
			"..kkkkkkkkkkk...",
		],
	},
	"warlord": {
		"palette": {
			"r": Color(0.7, 0.18, 0.18), "R": Color(0.45, 0.1, 0.12), "y": Color(1.0, 0.8, 0.25),
			"h": Color(0.92, 0.88, 0.75), "m": Color(0.35, 0.33, 0.4), "e": Color(1.0, 0.45, 0.2),
			"w": Color(0.85, 0.88, 0.95), "c": Color(0.3, 0.08, 0.1), "g": Color(0.4, 0.25, 0.12),
		},
		"rows": [
			".kk........kk...",
			".khk.kkkk.khk.k.",
			"..khkmmmmkhk.kwk",
			"...kmmmmmmk..kwk",
			"...kmekkemk..kwk",
			"...kmmmmmmk..kwk",
			"..kykkkkkkyk.kwk",
			".kcrryrryrrckkwk",
			"kcrrRyyyyRrrkyyk",
			"kcrrrRyyRrrrkRgk",
			"kcRrrrrrrrRckkgk",
			"kcyyyyyyyyyyck.k",
			"kcRrrrRrrrrRck..",
			"kcckRRkkRRkcck..",
			".kckmmk.kmmkck..",
			".kkkkkk.kkkkkk..",
		],
		"legs_b": [
			"kcckRRkRRkccck..",
			".kckmmkmmkcck...",
			".kkkkkkkkkkkk...",
		],
	},

	"martial": {  # White gi, red headband, bare fists
		"poses": {
			"punch": {
				7: ".................kk",
				8: "............kkkkkFFk",
				9: "............AAZZXFFk",
				10: "............kkkkkkk",
				11: "............__",
			},
			"kick": {
				11: "..............kkkkk",
				12: "...........LLLLLLUUk",
				13: "...........LLLLLLUUk",
				14: "........kkkkkkkkkkk",
				15: "........____",
			},
		},
		"palette": {
			"h": Color(0.2, 0.17, 0.25), "r": Color(0.85, 0.2, 0.2), "g": Color(0.93, 0.93, 0.9),
			"G": Color(0.72, 0.72, 0.7), "b": Color(0.15, 0.13, 0.15),
			# Pose colors: A upper arm, Z forearm, X wrist, F fist, L kicking leg, U its foot.
			"A": Color(0.96, 0.77, 0.6), "Z": Color(0.96, 0.77, 0.6), "X": Color(0.85, 0.2, 0.2),
			"F": Color(0.96, 0.77, 0.6), "L": Color(0.93, 0.93, 0.9), "U": Color(0.3, 0.19, 0.12),
		},
		"rows": [
			"................",
			"....k.k..k......",
			"...khkhkkhk.....",
			"...khhhhhhk.....",
			"...krrrrrrkr....",
			"...kskssksk.r...",
			"....kssssk......",
			"..kkGggggGkk....",
			".kskgggggggksk..",
			".kskgGgggGgksk..",
			".krkbbbbbbbkrk..",
			".kskgggggggksk..",
			"...kgggkgggk....",
			"...kgggkgggk....",
			"...kffk.kffk....",
			"...kkkk.kkkk....",
		],
		"legs_b": [
			"....kggkggk.....",
			"....kffkffk.....",
			"....kkkkkkk.....",
		],
	},
	"martial_p0": {  # Ki: flame-tall hair, blue bodysuit, white armor
		"base": "martial",
		"palette": {
			"h": Color(0.22, 0.2, 0.3), "b": Color(0.22, 0.3, 0.72), "W": Color(0.96, 0.96, 0.96),
			"y": Color(0.95, 0.8, 0.35),
			"A": Color(0.22, 0.3, 0.72), "Z": Color(0.22, 0.3, 0.72), "X": Color(0.96, 0.96, 0.96),
			"F": Color(0.96, 0.96, 0.96), "L": Color(0.22, 0.3, 0.72), "U": Color(0.96, 0.96, 0.96),
		},
		"rows": [
			"......k.k.......",
			"....k.khkhk.....",
			"....khkhhhhk....",
			"...khhhhhhhk....",
			"...khsshsshk....",
			"...kskkskksk....",
			"....ksssssk.....",
			"..kyyWWWWWyyk...",
			".kbkWWWWWWWkbk..",
			".kbkWWWWWWWkbk..",
			".kbkbbbbbbbkbk..",
			".kWkbbbbbbbkWk..",
			"...kbbbkbbbk....",
			"...kbbbkbbbk....",
			"...kWWk.kWWk....",
			"...kkkk.kkkk....",
		],
		"legs_b": [
			"....kbbkbbk.....",
			"....kWWkWWk.....",
			"....kkkkkkk.....",
		],
	},
	"martial_p2": {  # Techniques (a Krillin nod): his Orin Temple gi: mustard wrap top, maroon belt, orange pants, leg wraps
		"poses": {
			"punch": {
				8: "................kk",
				9: "...........kkkkkFFk",
				10: "...........AAZZXFFk",
				11: "...........kkkkkkk",
			},
		},
		"base": "martial",
		"palette": {
			"d": Color(0.35, 0.25, 0.25), "Y": Color(0.85, 0.68, 0.25), "y": Color(0.68, 0.52, 0.18),
			"m": Color(0.5, 0.24, 0.34), "o": Color(0.92, 0.5, 0.2), "c": Color(0.93, 0.85, 0.65),
			"T": Color(0.8, 0.65, 0.35), "A": Color(0.85, 0.68, 0.25), "Z": Color(0.96, 0.77, 0.6),
			"X": Color(0.96, 0.77, 0.6), "F": Color(0.96, 0.77, 0.6), "L": Color(0.92, 0.5, 0.2),
			"U": Color(0.8, 0.65, 0.35),
		},
		"rows": [
			"................",
			"................",
			"................",
			".....kkkkk......",
			"....ksdsdsk.....",
			"...ksdsdsdsk....",
			"...ksksssksk....",
			"....ksssssk.....",
			"...kkYyYYYkk....",
			"..kYkYYyYYkYk...",
			"..kskmmmmmksk...",
			"..kskYYYYYksk...",
			"...koookoook....",
			"...kccckccck....",
			"...kTTk.kTTk....",
			"...kkkk.kkkk....",
		],
		"legs_b": [
			"....kcckcck.....",
			"....kTTkTTk.....",
			"....kkkkkkk.....",
		],
	},
	"healer": {  # White hooded robe, green trim, a gold cross and a glowing staff
		"poses": {
			"cast": {
				0: "............____",
				1: "............____",
				2: "............____",
				3: "............____",
				4: "............____",
				5: "............____",
				6: "............____......k",
				7: "............_kkkkkkkkkok",
				8: ".............swwwwwwwOook",
				9: "............._kkkkkkkkok",
				10: "..............__......k",
				11: "..............__",
				12: "..............__",
				13: "..............__",
				14: "..............__",
			},
		},
		"palette": {
			"H": Color(0.93, 0.93, 0.9), "g": Color(0.35, 0.7, 0.35), "G": Color(0.25, 0.55, 0.3),
			"y": Color(1.0, 0.85, 0.3), "w": Color(0.55, 0.35, 0.15), "o": Color(0.6, 1.0, 0.6),
			"O": Color(0.95, 1.0, 0.9),
		},
		"rows": [
			"..............k.",
			".....kkkk....kok",
			"....kHHHHk..kOok",
			"...kHHHHHHk..kok",
			"...kHskssksk.kwk",
			"...kHssssssk.kwk",
			"...kkHHHHHHk.kwk",
			"..kHHHgggHHHkswk",
			"..kHHHHyHHHHkswk",
			"..kHHHyyyHHHk.wk",
			"..kHHHHyHHHHk.wk",
			"..kHHHHHHHHHk.wk",
			"..kHHHHHHHHHk.wk",
			"..kGGGGGGGGGk.wk",
			"...kkfkkfkkk..k.",
			"....kk..kk......",
		],
		"legs_b": [
			"...kkkfkkfkk..k.",
			".....kk..kk.....",
		],
	},
	"healer_p0": {  # Mending: gold-trimmed robes and a halo
		"base": "healer",
		"palette": {"g": Color(1.0, 0.85, 0.3), "G": Color(0.85, 0.65, 0.2), "o": Color(1.0, 0.9, 0.45)},
		"rows": [
			".....yyyy.....k.",
			".....kkkk....kok",
			"....kHHHHk..kOok",
			"...kHHHHHHk..kok",
			"...kHskssksk.kwk",
			"...kHssssssk.kwk",
			"...kkHHHHHHk.kwk",
			"..kHHHgggHHHkswk",
			"..kHHHHyHHHHkswk",
			"..kHHHyyyHHHk.wk",
			"..kHHHHyHHHHk.wk",
			"..kHHHHHHHHHk.wk",
			"..kHHHHHHHHHk.wk",
			"..kGGGGGGGGGk.wk",
			"...kkfkkfkkk..k.",
			"....kk..kk......",
		],
	},
	"healer_p1": {  # Radiance: sun-yellow robes with a sunburst
		"base": "healer",
		"palette": {
			"H": Color(1.0, 0.95, 0.72), "y": Color(1.0, 0.58, 0.15), "G": Color(0.95, 0.6, 0.15),
			"g": Color(1.0, 0.75, 0.25), "o": Color(1.0, 0.95, 0.4), "O": Color(1.0, 1.0, 0.8),
		},
		"rows": [
			"..............k.",
			".....kkkk....kok",
			"....kHHHHk..kOok",
			"...kHHHHHHk..kok",
			"...kHskssksk.kwk",
			"...kHssssssk.kwk",
			"...kkHHHHHHk.kwk",
			"..kHHHgggHHHkswk",
			"..kHHyHyHyHHkswk",
			"..kHHHyyyHHHk.wk",
			"..kHHyHyHyHHk.wk",
			"..kHHHHHHHHHk.wk",
			"..kHHHHHHHHHk.wk",
			"..kGGGGGGGGGk.wk",
			"...kkfkkfkkk..k.",
			"....kk..kk......",
		],
	},
	"healer_p2": {  # Renewal: a druid in leafy green with a flower and a budding staff
		"base": "healer",
		"palette": {
			"H": Color(0.42, 0.66, 0.36), "l": Color(0.25, 0.45, 0.2), "g": Color(0.55, 0.38, 0.2),
			"G": Color(0.3, 0.5, 0.25), "y": Color(0.95, 0.55, 0.75), "o": Color(0.45, 0.85, 0.35),
			"O": Color(0.85, 1.0, 0.7), "w": Color(0.42, 0.27, 0.12),
		},
		"rows": [
			".............kk.",
			".....kkkk....kok",
			"....kHHHHk..kOok",
			"...kHHHHHHk..kok",
			"...kHskssksk.kwk",
			"...kHssssssk.kwk",
			"...kkHHHHHHk.kwk",
			"..kHHHgggHHHkswk",
			"..kHHHHyHHHHkswk",
			"..kHlHyyyHHlk.wk",
			"..kHHHHyHHHHk.wk",
			"..kHHHlHHHHHk.wk",
			"..kHHHHHHlHHk.wk",
			"..kGGGGGGGGGk.wk",
			"...kkfkkfkkk..k.",
			"....kk..kk......",
		],
	},
	"bard": {  # Feathered cap, teal tunic, a lute across the body
		"poses": {
			"strum": {
				9: "...........s",
				10: "...T......s",
			},
		},
		"palette": {
			"R": Color(0.8, 0.2, 0.25), "F": Color(0.95, 0.95, 0.85), "T": Color(0.2, 0.6, 0.6),
			"y": Color(1.0, 0.85, 0.3), "L": Color(0.75, 0.48, 0.2), "n": Color(0.5, 0.3, 0.12),
			"o": Color(0.25, 0.15, 0.08),
		},
		"rows": [
			".......kk.k.....",
			".....kkRRkFk....",
			"....kRRRRRkk....",
			"...kRRRRRRRk....",
			"....kskssksk....",
			"....kssssssk..kk",
			".....kssssk..knk",
			"...kkTTyyTTkknk.",
			"..kTTTTyyTTTnkk.",
			"..kTkTTTTTkLLLk.",
			"..kskTTTTkLLoLLk",
			"...kTTTTTkLLLLLk",
			"...kppppppkLLLk.",
			"...kppkkppk.kk..",
			"...kffk.kffk....",
			"...kkkk.kkkk....",
		],
		"legs_b": [
			"...kppkppk.kk...",
			"....kffkffk.....",
			"....kkkkkkk.....",
		],
	},
	"bard_p0": {  # Inspire: a royal herald in gold with a tall red plume, playing a red pipa
		"poses": {
			"strum": {
				9: "...........s....",
				10: "...T......s.....",
			},
		},
		"base": "bard",
		"palette": {
			"R": Color(0.25, 0.35, 0.85), "F": Color(0.9, 0.2, 0.2), "T": Color(0.9, 0.7, 0.2),
			"y": Color(0.95, 0.95, 0.95), "L": Color(0.78, 0.22, 0.2), "n": Color(0.5, 0.15, 0.12),
			"o": Color(0.25, 0.08, 0.08),
		},
		"rows": [
			"......kFFkk.....",
			".....kkRRkFFk...",
			"....kRRRRRkk....",
			"...kRRRRRRRk....",
			"....kskssksk....",
			"....kssssssk..kk",
			".....kssssk..knk",
			"...kkTTyyTTkknk.",
			"..kTTTTyyTTTnkk.",
			"..kTkTTTTTkLLLk.",
			"..kskTTTTkLLoLLk",
			"...kTTTTTkLLLLLk",
			"...kppppppkLLLk.",
			"...kppkkppk.kk..",
			"...kffk.kffk....",
			"...kkkk.kkkk....",
		],
	},
	"bard_p1": {  # Discord: a jester in purple and black with belled points, playing a little mouth instrument
		"poses": {
			"strum": {
				6: ".....ksssskmk...",
			},
		},
		"base": "bard",
		"palette": {
			"R": Color(0.5, 0.15, 0.55), "T": Color(0.22, 0.18, 0.28), "y": Color(0.6, 0.9, 0.3),
			"m": Color(0.45, 0.3, 0.18),
		},
		"rows": [
			"..ky.......yk...",
			"...kRk.kk.kRk...",
			"....kRRRRRRk....",
			"...kRRRRRRRk....",
			"....kskssksk....",
			"....kssssssk....",
			".....kssssmmk...",
			"...kkTTyyTTksk..",
			"..kTTTTyyTTTsk..",
			"..kTkTTTTTkTk...",
			"..kskTTTTkTk....",
			"...kTTTTTk......",
			"...kppppppk.....",
			"...kppkkppk.....",
			"...kffk.kffk....",
			"...kkkk.kkkk....",
		],
	},
	"bard_p2": {  # Spellsong: a green nature-bard with a flower, playing a flute
		"poses": {
			"strum": {
				6: ".....ksssskwkwwk",
			},
		},
		"base": "bard",
		"palette": {
			"R": Color(0.3, 0.6, 0.25), "F": Color(1.0, 0.6, 0.8), "T": Color(0.42, 0.55, 0.25),
			"y": Color(0.95, 0.8, 0.4), "l": Color(0.3, 0.7, 0.25), "w": Color(0.85, 0.72, 0.5),
		},
		"rows": [
			"........kk......",
			".....kkRRkFk....",
			"....kRRRRRkk....",
			"...kRRRRRRRk....",
			"....kskssksk....",
			"....kssssssk....",
			".....ksssskwwwwk",
			"...kkTTyyTTks.s.",
			"..kTTTTyyTTTsk..",
			"..kTkTTTTTkTk...",
			"..kskTTTTkTk....",
			"...kTlTTTk......",
			"...kppppppk.....",
			"...kppkkppk.....",
			"...kffk.kffk....",
			"...kkkk.kkkk....",
		],
	},
	"alchemist": {  # Brass goggles, leather apron, a bubbling green flask in hand
		"poses": {
			"catch": {  # idle: the flask is up in the air, hand open to catch it
				5: "............____",
				6: "............____",
				7: "............k___",
				8: "............sk__",
				9: "............k___",
				10: "...........k____",
			},
			"throw": {
				1: ".............kk.",
				2: ".............kvk",
				3: "............kxxk",
				4: "............kxxk",
				5: "............ks..",
				6: "............C__.",
				7: "............C___",
				8: "............____",
				9: "............____",
				10: "...........k___.",
			},
		},
		"palette": {
			"h": Color(0.45, 0.28, 0.15), "G": Color(0.8, 0.6, 0.25), "g": Color(0.6, 0.9, 0.95),
			"A": Color(0.55, 0.38, 0.22), "a": Color(0.38, 0.25, 0.13), "C": Color(0.3, 0.5, 0.35),
			"v": Color(0.85, 0.95, 0.95), "x": Color(0.45, 0.95, 0.35), "b": Color(0.15, 0.13, 0.15),
		},
		"rows": [
			"......kkkk......",
			".....khhhhk.....",
			"....khhhhhhk....",
			"....kGgGGgGk....",
			"....kssssssk....",
			"....kskssksk....",
			".....kssssk..kk.",
			"...kkCAAAACk.kvk",
			"..kCCAAAAAACkxxk",
			"..kCkAAAAAkCkxxk",
			"..kskAAAAAkssk..",
			"...kaaaaaak.....",
			"...kAAAAAAk.....",
			"...kppkkppk.....",
			"...kffk.kffk....",
			"...kkkk.kkkk....",
		],
		"legs_b": [
			"...kppkppk......",
			"....kffkffk.....",
			"....kkkkkkk.....",
		],
	},
	"alchemist_p0": {  # Toxins: a plague doctor with a beaked mask and a purple poison
		"base": "alchemist",
		"palette": {
			"H": Color(0.15, 0.13, 0.17), "m": Color(0.85, 0.8, 0.68), "g": Color(0.85, 0.25, 0.2),
			"A": Color(0.2, 0.18, 0.23), "a": Color(0.12, 0.1, 0.14), "C": Color(0.28, 0.25, 0.32),
			"x": Color(0.65, 0.35, 0.95),
		},
		"rows": [
			"....kkkkkk......",
			"....kHHHHk......",
			"..kkHHHHHHkk....",
			"...kmmmmmk......",
			"...kmgmmgk......",
			"...kmmmmmmmk....",
			"....kmmmkkk..kk.",
			"...kkCAAAACk.kvk",
			"..kCCAAAAAACkxxk",
			"..kCkAAAAAkCkxxk",
			"..kbkAAAAAkbbk..",
			"...kaaaaaak.....",
			"...kAAAAAAk.....",
			"...kAAkkAAk.....",
			"...kffk.kffk....",
			"...kkkk.kkkk....",
		],
	},
	"alchemist_p1": {  # Acids: goggles down, a yellow rubber apron and black gloves
		"base": "alchemist",
		"palette": {
			"A": Color(0.9, 0.8, 0.2), "a": Color(0.68, 0.58, 0.1), "C": Color(0.35, 0.36, 0.38),
			"x": Color(0.88, 0.95, 0.2), "g": Color(0.6, 1.0, 0.4),
		},
		"rows": [
			"......kkkk......",
			".....khhhhk.....",
			"....khhhhhhk....",
			"....khhhhhhk....",
			"....kssssssk....",
			"....kGgGGgGk....",
			".....kssssk..kk.",
			"...kkCAAAACk.kvk",
			"..kCCAAAAAACkxxk",
			"..kCkAAAAAkCkxxk",
			"..kbkAAAAAkbbk..",
			"...kaaaaaak.....",
			"...kAAAAAAk.....",
			"...kppkkppk.....",
			"...kffk.kffk....",
			"...kkkk.kkkk....",
		],
	},
	"alchemist_p2": {  # Volatiles: singed spiky hair, a scorched apron and a lit bomb
		"base": "alchemist",
		"poses": {
			"throw": {
				0: "..............y.",
				1: "..............k.",
				2: ".............kk.",
				3: "............kbbk",
				4: "............kbBk",
				5: "............ks_.",
				6: "............C._.",
				7: "............C___",
				8: "............____",
				9: "............____",
				10: "...........k___.",
			},
		},
		"palette": {
			"h": Color(0.2, 0.15, 0.12), "A": Color(0.6, 0.25, 0.15), "a": Color(0.4, 0.15, 0.1),
			"C": Color(0.85, 0.5, 0.2), "B": Color(0.45, 0.45, 0.5), "y": Color(1.0, 0.8, 0.2),
		},
		"rows": [
			".....k.kk.k.....",
			"....khkhhkhk....",
			"....khhhhhhk....",
			"....kGgGGgGk....",
			"....kssssssk....",
			"....kskssksk..y.",
			".....kssssk...k.",
			"...kkCAAAACk.kk.",
			"..kCCAAAAAACkbbk",
			"..kCkAAAAAkCkbBk",
			"..kskAAAAAkssk..",
			"...kaaaaaak.....",
			"...kAAAAAAk.....",
			"...kppkkppk.....",
			"...kffk.kffk....",
			"...kkkk.kkkk....",
		],
	},
	"magetower": {  # Stone tower, a mage on top and a violet banner
		"palette": {"P": Color(0.45, 0.25, 0.65), "Q": Color(0.3, 0.15, 0.45), "y": Color(1.0, 0.85, 0.3), "W": Color(0.92, 0.92, 0.95), "S": Color(0.62, 0.6, 0.7), "D": Color(0.42, 0.4, 0.5), "T": Color(0.52, 0.5, 0.6), "R": Color(0.55, 0.3, 0.8), "Y": Color(1.0, 0.85, 0.3)},
		"rows": [
			".......kk.......",
			"......kPPk......",
			".kkk.kPPyPk.kkk.",
			".kSkkQQQQQQkkSk.",
			".kSk.kskksk.kSk.",
			".kSSSkWWWWkSSSk.",
			".kkkkkkkkkkkkkk.",
			"..kSSkRRRRkSSk..",
			"..kSSkRYYRkSSk..",
			"..kDDkRRRRkDDk..",
			"..kSDkRYYRkDSk..",
			"..kTDSkRRkSDTk..",
			"..kDDDDkkDDDDk..",
			".kSSSDSSSSDSSSk.",
			".kTSSDSSSSDSSTk.",
			".kkkkkkkkkkkkkk.",
		],
	},
	"magetower_p2": {  # Fire: a red hat tipped with flame, and glowing ember runes
		"base": "magetower",
		"palette": {"P": Color(0.85, 0.25, 0.15), "Q": Color(0.6, 0.15, 0.1), "R": Color(0.9, 0.4, 0.12),
				"Y": Color(1.0, 0.85, 0.3), "y": Color(1.0, 0.6, 0.15), "S": Color(0.6, 0.52, 0.5)},
		"rows": [
			"......kyyk......",
			"......kPPk......",
			".kkk.kPPyPk.kkk.",
			".kSkkQQQQQQkkSk.",
			".kSk.kskksk.kSk.",
			".kSSSkWWWWkSSSk.",
			".kkkkkkkkkkkkkk.",
			"..kSSkRRRRkSSk..",
			"..kSykRYYRkySk..",
			"..kDDkRRRRkDDk..",
			"..kSDkRYYRkDyk..",
			"..kTDSkRRkSDTk..",
			"..kDDDDkkDDDDk..",
			".kSSSDSSSSDSSSk.",
			".kTSSDSSSSDSSTk.",
			".kkkkkkkkkkkkkk.",
		],
	},
	"magetower_p0": {  # Storm: blue hat and a lightning banner
		"base": "magetower",
		"palette": {"P": Color(0.25, 0.4, 0.85), "Q": Color(0.15, 0.25, 0.6), "R": Color(0.25, 0.4, 0.85), "Y": Color(0.8, 0.95, 1.0), "y": Color(0.8, 0.95, 1.0)},
		"rows": [
			".......kk.......",
			"......kPPk......",
			".kkk.kPPyPk.kkk.",
			".kSkkQQQQQQkkSk.",
			".kSk.kskksk.kSk.",
			".kSSSkWWWWkSSSk.",
			".kkkkkkkkkkkkkk.",
			"..kSSkRRRRkSSk..",
			"..kSSkRYRRkSSk..",
			"..kDDkRRYRkDDk..",
			"..kSDkRYRRkDSk..",
			"..kTDSkRRkSDTk..",
			"..kDDDDkkDDDDk..",
			".kSSSDSSSSDSSSk.",
			".kTSSDSSSSDSSTk.",
			".kkkkkkkkkkkkkk.",
		],
	},
	"magetower_p1": {  # Arcane Lance: a pink crystal crown on the hat
		"base": "magetower",
		"palette": {"P": Color(0.8, 0.3, 0.7), "Q": Color(0.55, 0.18, 0.5), "R": Color(0.85, 0.35, 0.75), "O": Color(1.0, 0.75, 1.0)},
		"rows": [
			"......kOOk......",
			"......kPOk......",
			".kkk.kPPyPk.kkk.",
			".kSkkQQQQQQkkSk.",
			".kSk.kskksk.kSk.",
			".kSSSkWWWWkSSSk.",
			".kkkkkkkkkkkkkk.",
			"..kSSkRRRRkSSk..",
			"..kSSkRYYRkSSk..",
			"..kDDkRRRRkDDk..",
			"..kSDkRYYRkDSk..",
			"..kTDSkRRkSDTk..",
			"..kDDDDkkDDDDk..",
			".kSSSDSSSSDSSSk.",
			".kTSSDSSSSDSSTk.",
			".kkkkkkkkkkkkkk.",
		],
	},
	"frosttower": {  # Icy stone tower, a frost witch on top and an ice banner
		"palette": {"c": Color(0.3, 0.55, 0.9), "C": Color(0.2, 0.4, 0.7), "h": Color(0.95, 0.97, 1.0), "s": Color(0.98, 0.86, 0.78), "r": Color(0.4, 0.65, 0.95), "S": Color(0.6, 0.74, 0.86), "D": Color(0.4, 0.54, 0.7), "T": Color(0.5, 0.64, 0.78), "R": Color(0.35, 0.6, 0.9), "Y": Color(1.0, 1.0, 1.0), "i": Color(0.75, 0.95, 1.0)},
		"rows": [
			"......kkkk......",
			".....kcccck.....",
			".kkkkcccccckkkk.",
			".kSkkhskskshkSk.",
			".kSkkCrrrrCkkSk.",
			".kSSSSSSSSSSSSk.",
			".kkkkkkkkkkkkkk.",
			"..kSSkRRRRkSSk..",
			"..kSSkRYYRkSSk..",
			"..kDDkRRRRkDDk..",
			"..kSDkRYYRkDSk..",
			"..kTDSkRRkSDTk..",
			"..kDDDDkkDDDDk..",
			".kSSSDSSSSDSSSk.",
			".kTSSDSSSSDSSTk.",
			".kkkkkkkkkkkkkk.",
		],
	},
	"frosttower_p0": {  # Deep Cold: navy robes and icicles hanging from the walls
		"base": "frosttower",
		"palette": {"c": Color(0.2, 0.3, 0.6), "C": Color(0.12, 0.2, 0.45), "r": Color(0.18, 0.28, 0.6), "R": Color(0.15, 0.25, 0.55)},
		"rows": [
			"......kkkk......",
			".....kcccck.....",
			".kkkkcccccckkkk.",
			".kSkkhskskshkSk.",
			".kSkkCrrrrCkkSk.",
			".kSSSSSSSSSSSSk.",
			".kkkkkkkkkkkkkk.",
			"..kiSkRRRRkSik..",
			"..kSSkRYYRkSSk..",
			"..kiDkRRRRkDik..",
			"..kSDkRYYRkDSk..",
			"..kTDSkRRkSDTk..",
			"..kiDDDkkDDDik..",
			".kSSSDSSSSDSSSk.",
			".kTSSDSSSSDSSTk.",
			".kkkkkkkkkkkkkk.",
		],
	},
	"frosttower_p1": {  # Blizzard: white fur hood and snow piled on the battlements
		"base": "frosttower",
		"palette": {"c": Color(0.95, 0.97, 1.0), "C": Color(0.72, 0.8, 0.9), "I": Color(1.0, 1.0, 1.0)},
		"rows": [
			"......kkkk......",
			".....kcccck.....",
			".kkkkcccccckkkk.",
			".kSkkhskskshkSk.",
			".kSkkCrrrrCkkSk.",
			".kIIIIIIIIIIIIk.",
			".kkkkkkkkkkkkkk.",
			"..kSSkRRRRkSSk..",
			"..kSSkRYYRkSSk..",
			"..kDDkRRRRkDDk..",
			"..kSDkRYYRkDSk..",
			"..kTDSkRRkSDTk..",
			"..kIIDDkkDDIIk..",
			".kSSSDSSSSDSSSk.",
			".kTSSDSSSSDSSTk.",
			".kkkkkkkkkkkkkk.",
		],
	},
	"frosttower_p2": {  # Flash Freeze: glowing eyes and ice crystals on the merlons
		"base": "frosttower",
		"palette": {"e": Color(0.4, 1.0, 1.0), "I": Color(0.85, 1.0, 1.0)},
		"rows": [
			".i....kkkk....i.",
			"kIk..kcccck..kIk",
			".kkkkcccccckkkk.",
			".kSkkhseseshkSk.",
			".kSkkCrrrrCkkSk.",
			".kSSSSSSSSSSSSk.",
			".kkkkkkkkkkkkkk.",
			"..kSSkRRRRkSSk..",
			"..kSSkRYYRkSSk..",
			"..kDDkRRRRkDDk..",
			"..kSDkRYYRkDSk..",
			"..kTDSkRRkSDTk..",
			"..kDDDDkkDDDDk..",
			".kSSSDSSSSDSSSk.",
			".kTSSDSSSSDSSTk.",
			".kkkkkkkkkkkkkk.",
		],
	},
	"medbay": {  # A canvas tent with a red cross
		"palette": {"W": Color(0.94, 0.92, 0.86), "w": Color(0.75, 0.72, 0.66), "r": Color(0.85, 0.15, 0.15), "x": Color(0.18, 0.12, 0.1), "B": Color(0.6, 0.4, 0.2)},
		"rows": [
			"................",
			"................",
			".......kk.......",
			"......kWWk......",
			".....kWWWWk.....",
			"....kWWrrWWk....",
			"...kWWWrrWWWk...",
			"..kWWrrrrrrWWk..",
			".kWWWrrrrrrWWWk.",
			"kWWWWWWrrWWWWWWk",
			"kwWWWWWrrWWWWWwk",
			"kwWWWWkkkkWWWWwk",
			"kwWWWkxxxxkWWWwk",
			"kwWWkxxxxxxkWWwk",
			"kwWWkxxxxxxkWWwk",
			"kkkkkkkkkkkkkkkk",
		],
	},
	"medbay_p0": {  # Supplies: crates of medicine stacked by the tent
		"base": "medbay",
		"palette": {},
		"rows": [
			"................",
			"................",
			".......kk.......",
			"......kWWk......",
			".....kWWWWk.....",
			"....kWWrrWWk....",
			"...kWWWrrWWWk...",
			"..kWWrrrrrrWWk..",
			".kWWWrrrrrrWWWk.",
			"kWWWWWWrrWWWWWWk",
			"kwWWWWWrrWWWWWwk",
			"kwWWWWkkkkWkkkkk",
			"kwWWWkxxxxkkBBBk",
			"kwWWkxxxxxxkBkBk",
			"kwWWkxxxxxxkBBBk",
			"kkkkkkkkkkkkkkkk",
		],
	},
	"medbay_p1": {  # Wards: a bigger blue-trimmed tent flying a pennant
		"base": "medbay",
		"palette": {"w": Color(0.35, 0.5, 0.85), "b": Color(0.3, 0.45, 0.9)},
		"rows": [
			".......kbbk.....",
			".......k........",
			".......kk.......",
			"......kWWk......",
			".....kWWWWk.....",
			"....kWWrrWWk....",
			"...kWWWrrWWWk...",
			"..kWWrrrrrrWWk..",
			".kWWWrrrrrrWWWk.",
			"kWWWWWWrrWWWWWWk",
			"kwWWWWWrrWWWWWwk",
			"kwWWWWkkkkWWWWwk",
			"kwWWWkxxxxkWWWwk",
			"kwWWkxxxxxxkWWwk",
			"kwWWkxxxxxxkWWwk",
			"kkkkkkkkkkkkkkkk",
		],
	},
	"medbay_p2": {  # Field Hospital: a healer's green cross
		"base": "medbay",
		"palette": {"r": Color(0.3, 0.75, 0.35), "W": Color(0.96, 0.95, 0.88)},
		"rows": [
			"................",
			"................",
			".......kk.......",
			"......kWWk......",
			".....kWWWWk.....",
			"....kWWrrWWk....",
			"...kWWWrrWWWk...",
			"..kWWrrrrrrWWk..",
			".kWWWrrrrrrWWWk.",
			"kWWWWWWrrWWWWWWk",
			"kwWWWWWrrWWWWWwk",
			"kwWWWWkkkkWWWWwk",
			"kwWWWkxxxxkWWWwk",
			"kwWWkxxxxxxkWWwk",
			"kwWWkxxxxxxkWWwk",
			"kkkkkkkkkkkkkkkk",
		],
	},
	"statue": {  # A stone knight raising a sword on a pedestal
		"palette": {"S": Color(0.72, 0.72, 0.7), "D": Color(0.5, 0.5, 0.5), "P": Color(0.55, 0.5, 0.45)},
		"rows": [
			"...........k....",
			"..........kSk...",
			"......kk..kSk...",
			".....kSSk.kSk...",
			".....kSSk.kSk...",
			"......kk..kDk...",
			"....kkSSkkkDk...",
			"...kSSSSSSSk....",
			"...kSkSSSSk.....",
			"...kSkSSSSk.....",
			"...kDkSSSSk.....",
			".....kSkSk......",
			"...kkkkkkkkkk...",
			"...kPPPPPPPPk...",
			"..kPPPPPPPPPPk..",
			"..kkkkkkkkkkkk..",
		],
	},
	"statue_p0": {  # Valor: cast in gold
		"base": "statue",
		"palette": {"S": Color(1.0, 0.82, 0.3), "D": Color(0.78, 0.58, 0.18)},
		"rows": [
			"...........k....",
			"..........kSk...",
			"......kk..kSk...",
			".....kSSk.kSk...",
			".....kSSk.kSk...",
			"......kk..kDk...",
			"....kkSSkkkDk...",
			"...kSSSSSSSk....",
			"...kSkSSSSk.....",
			"...kSkSSSSk.....",
			"...kDkSSSSk.....",
			".....kSkSk......",
			"...kkkkkkkkkk...",
			"...kPPPPPPPPk...",
			"..kPPPPPPPPPPk..",
			"..kkkkkkkkkkkk..",
		],
	},
	"statue_p1": {  # Haste: green-bronze with spread wings
		"base": "statue",
		"palette": {"S": Color(0.5, 0.72, 0.62), "D": Color(0.32, 0.52, 0.45), "V": Color(0.95, 0.95, 0.92)},
		"rows": [
			"...........k....",
			"..........kSk...",
			"......kk..kSk...",
			".....kSSk.kSk...",
			".....kSSk.kSk...",
			".V....kk..kDk...",
			".VV.kkSSkkkDk...",
			".VVkSSSSSSSk....",
			"..VkSkSSSSk.....",
			"...kSkSSSSk.....",
			"...kDkSSSSk.....",
			".....kSkSk......",
			"...kkkkkkkkkk...",
			"...kPPPPPPPPk...",
			"..kPPPPPPPPPPk..",
			"..kkkkkkkkkkkk..",
		],
	},
	"statue_p2": {  # Bulwark: dark iron with a tower shield
		"base": "statue",
		"palette": {"S": Color(0.5, 0.52, 0.56), "D": Color(0.34, 0.35, 0.38), "B": Color(0.3, 0.4, 0.75), "y": Color(1.0, 0.82, 0.3)},
		"rows": [
			"...........k....",
			"..........kSk...",
			"......kk..kSk...",
			".....kSSk.kSk...",
			".....kSSk.kSk...",
			"......kk..kDk...",
			"....kkSSkkkDk...",
			"...kSSSSSSSk....",
			".kBBBkSSSSk.....",
			".kByBkSSSSk.....",
			".kyyykSSSSk.....",
			".kByBkSkSk......",
			"..kBkkkkkkkkk...",
			"...kPPPPPPPPk...",
			"..kPPPPPPPPPPk..",
			"..kkkkkkkkkkkk..",
		],
	},
	"mine": {  # A mine shaft in a rocky hill with gold piled outside
		"palette": {"R": Color(0.5, 0.42, 0.36), "r": Color(0.62, 0.54, 0.46), "W": Color(0.55, 0.35, 0.17), "x": Color(0.08, 0.06, 0.06), "y": Color(1.0, 0.82, 0.25), "Y": Color(1.0, 0.95, 0.6), "M": Color(0.4, 0.42, 0.46)},
		"rows": [
			"................",
			"................",
			".....kkkkkk.....",
			"...kkRRrRRRkk...",
			"..kRRRRRRrRRRk..",
			".kRrRkkkkkkRRRk.",
			".kRRkWWWWWWkRrk.",
			"kRRRkWxxxxWkRRRk",
			"kRrRkWxxxxWkRRRk",
			"kRRRkWxxxxWkrRRk",
			"kRRRkWxxxxWkRRRk",
			"kRRRkWxxxxWkRRRk",
			"kRRRkWxxxxWkRRRk",
			"kkykkkkkkkkkkykk",
			".kyYyk....kyYyk.",
			"..kkk......kkk..",
		],
	},
	"mine_p0": {  # Mother Lode: gold veins running through the rock
		"base": "mine",
		"palette": {},
		"rows": [
			"................",
			"................",
			".....kkkkkk.....",
			"...kkRRyRRRkk...",
			"..kRyRRRRyRRRk..",
			".kRyRkkkkkkRyRk.",
			".kRRkWWWWWWkRrk.",
			"kRRRkWxxxxWkRRRk",
			"kRyRkWxxxxWkRyRk",
			"kRRRkWxxxxWkrRRk",
			"kyRRkWxxxxWkRRyk",
			"kRRRkWxxxxWkRRRk",
			"kRRRkWxxxxWkRRRk",
			"kkykkkkkkkkkkykk",
			".kyYyk....kyYyk.",
			"..kkk......kkk..",
		],
	},
	"mine_p1": {  # Mine Carts: a loaded cart on rails out front
		"base": "mine",
		"palette": {},
		"rows": [
			"................",
			"................",
			".....kkkkkk.....",
			"...kkRRrRRRkk...",
			"..kRRRRRRrRRRk..",
			".kRrRkkkkkkRRRk.",
			".kRRkWWWWWWkRrk.",
			"kRRRkWxxxxWkRRRk",
			"kRrRkWxxxxWkRRRk",
			"kRRRkWxxxxWkrRRk",
			"kRRRkWxxxxWkRRRk",
			"kRRRkWxkyYykRRRk",
			"kRRRkWkyYyYkRRRk",
			"kkykkkkMMMMkkykk",
			".kyYyk.kMkMk.yk.",
			"WWWWWWWWWWWWWWWW",
		],
	},
	"mine_p2": {  # Treasury: a locked treasure chest beside the shaft
		"base": "mine",
		"palette": {},
		"rows": [
			"................",
			"................",
			".....kkkkkk.....",
			"...kkRRrRRRkk...",
			"..kRRRRRRrRRRk..",
			".kRrRkkkkkkRRRk.",
			".kRRkWWWWWWkRrk.",
			"kRRRkWxxxxWkRRRk",
			"kRrRkWxxxxWkRRRk",
			"kRRRkWxxxxWkrRRk",
			"kRRRkWxxxxWkRRRk",
			"kRRRkWxxxxWkkkkk",
			"kRRRkWxxxxWkWWWk",
			"kkykkkkkkkkkyykk",
			".kyYyk....kWWWk.",
			"..kkk.....kkkkk.",
		],
	},
	"tower": {  # Stone tower, an archer at the battlements
		"palette": {
			"g": Color(0.35, 0.65, 0.3), "G": Color(0.22, 0.45, 0.2), "b": Color(0.62, 0.4, 0.18),
			"S": Color(0.66, 0.64, 0.6), "D": Color(0.45, 0.43, 0.42), "T": Color(0.55, 0.53, 0.5),
		},
		"rows": [
			"......kkkk......",
			".....kggggk.....",
			".kkk.kgssgk.kkk.",
			".kSk.kGGGGk.kSk.",
			".kSkkkbbbbkkkSk.",
			".kSSSSSSSSSSSSk.",
			".kkkkkkkkkkkkkk.",
			"..kSSDSSSSDSSk..",
			"..kSSDSkkSDSSk..",
			"..kDDDDkkDDDDk..",
			"..kSDSSSSSSDSk..",
			"..kTDSSSSSSDTk..",
			"..kDDDDDDDDDDk..",
			".kSSSDSSSSDSSSk.",
			".kTSSDSSSSDSSTk.",
			".kkkkkkkkkkkkkk.",
		],
	},
	"cannon": {  # A gunner beside an iron cannon on a wooden carriage
		"palette": {
			"R": Color(0.8, 0.2, 0.18), "B": Color(0.25, 0.35, 0.65), "M": Color(0.28, 0.3, 0.34),
			"N": Color(0.55, 0.57, 0.62), "W": Color(0.55, 0.35, 0.17), "t": Color(1.0, 0.6, 0.2),
		},
		"rows": [
			"................",
			"............kkk.",
			"...........kNNNk",
			"..........kMMMNk",
			".........kMMMMk.",
			"..kkk...kMMMMk..",
			".kRRRk.kMMMMk...",
			"..ksk.kMMMMk....",
			"..ksk.kMMMk.....",
			".kBBBk.kkkkk....",
			"kBBBBBkWWWWWk...",
			"ksBBBsk.kkk.....",
			".kpppk.kWWWk....",
			".kpkpk.kWkWk....",
			".kfkfk.kWWWk....",
			".kkkkk..kkk.....",
		],
	},
	# --- Tier-3 upgrade looks. "base" inherits that sprite's palette and walk frame. ---
	"tower_p0": {  # Damage: a ballista mounted on an iron-banded tower
		"base": "tower",
		"palette": {"a": Color(0.8, 0.82, 0.88), "n": Color(0.7, 0.55, 0.35), "W": Color(0.5, 0.32, 0.15), "I": Color(0.36, 0.38, 0.44)},
		"rows": [
			".......kk.......",
			"......kaak......",
			"kkk...knnk...kkk",
			"kWWkkkknnkkkkWWk",
			".kkWWWWnnWWWWkk.",
			".kSSSkWkkWkSSSk.",
			".kkkkkkkkkkkkkk.",
			"..kSSDSSSSDSSk..",
			"..kSSDSkkSDSSk..",
			"..kIIIIkkIIIIk..",
			"..kSDSSSSSSDSk..",
			"..kTDSSSSSSDTk..",
			"..kIIIIIIIIIIk..",
			".kSSSDSSSSDSSSk.",
			".kTSSDSSSSDSSTk.",
			".kkkkkkkkkkkkkk.",
		],
	},
	"tower_p1": {  # Range: a roofed lookout flying a pennant
		"base": "tower",
		"palette": {"R": Color(0.75, 0.22, 0.18), "Q": Color(0.55, 0.14, 0.12), "B": Color(0.3, 0.45, 0.85)},
		"rows": [
			".......kBBBk....",
			".......kBBk.....",
			"......kRRk......",
			".....kRRQRk.....",
			"....kRRRQRRk....",
			"..kkRRRRQRRRkk..",
			".kRRRRRRQRRRRRk.",
			".kkkkkkkkkkkkkk.",
			".kSk.kgssgk.kSk.",
			".kSkkkGGGGkkkSk.",
			".kkkkkkkkkkkkkk.",
			"..kSSDSkkSDSSk..",
			"..kDDDDkkDDDDk..",
			".kSSSDSSSSDSSSk.",
			".kTSSDSSSSDSSTk.",
			".kkkkkkkkkkkkkk.",
		],
	},
	"tower_p2": {  # Garrison: three archers on the walls and a war banner
		"base": "tower",
		"palette": {"R": Color(0.75, 0.2, 0.18), "Y": Color(1.0, 0.82, 0.3)},
		"rows": [
			"......kkkk......",
			".kkk.kggggk.kkk.",
			"kgggkkgssgkkgggk",
			"kgsgkkGGGGkkgsgk",
			"kGGGkkbbbbkkGGGk",
			".kSSSSSSSSSSSSk.",
			".kkkkkkkkkkkkkk.",
			"..kSSkRRRRkSSk..",
			"..kSSkRYYRkSSk..",
			"..kDDkRRRRkDDk..",
			"..kSDkRYYRkDSk..",
			"..kTDSkRRkSDTk..",
			"..kDDDDkkDDDDk..",
			".kSSSDSSSSDSSSk.",
			".kTSSDSSSSDSSTk.",
			".kkkkkkkkkkkkkk.",
		],
	},
	"cannon_p0": {  # Firepower: a huge bronze siege mortar
		"base": "cannon",
		"palette": {"M": Color(0.72, 0.5, 0.2), "N": Color(0.95, 0.78, 0.4)},
		"rows": [
			"...........kkkk.",
			"..........kNNNNk",
			".........kMMMMNk",
			"........kMMMMMNk",
			".......kMMMMMMk.",
			"..kkk.kMMMMMMk..",
			".kRRRkkMMMMMk...",
			"..ksk.kMMMMk....",
			"..ksk.kMMMk.....",
			".kBBBk.kkkkk....",
			"kBBBBBkWWWWWk...",
			"ksBBBsk.kkk.....",
			".kpppk.kWWWk....",
			".kpkpk.kWkWk....",
			".kfkfk.kWWWk....",
			".kkkkk..kkk.....",
		],
	},
	"cannon_p1": {  # Blast: red-banded barrel, goggles and a powder keg
		"base": "cannon",
		"palette": {"N": Color(0.85, 0.2, 0.15), "K": Color(0.5, 0.32, 0.15), "X": Color(0.3, 0.3, 0.32), "o": Color(0.55, 0.85, 1.0), "t": Color(0.45, 0.3, 0.15)},
		"rows": [
			"................",
			"............kkk.",
			"...........kNNNk",
			"..........kMMMNk",
			".........kMNMMk.",
			"..kkk...kMMNMk..",
			".kttRk.kMMMMk...",
			"..kok.kMMMMk....",
			"..ksk.kMMMk.....",
			".kBBBk.kkkkk....",
			"kBBBBBkWWWWWk...",
			"ksBBBsk.kkk.kkk.",
			".kpppk.kWWWkKKKk",
			".kpkpk.kWkWkXXXk",
			".kfkfk.kWWWkKKKk",
			".kkkkk..kkk.kkk.",
		],
	},
	"cannon_p2": {  # Crew: a double-barrelled cannon
		"base": "cannon",
		"palette": {},
		"rows": [
			"................",
			"..............kk",
			".............kNN",
			"............kMMk",
			"...........kMMkk",
			"..kkk.....kMMkNN",
			".kRRRk...kMMkMMk",
			"..ksk.k.kMMkMMk.",
			"..ksk.kkMMkMMk..",
			".kBBBkkMMkMMk...",
			"kBBBBBkWWWWWk...",
			"ksBBBsk.kkk.....",
			".kpppk.kWWWk....",
			".kpkpk.kWkWk....",
			".kfkfk.kWWWk....",
			".kkkkk..kkk.....",
		],
	},
	"swordsman_p0": {  # Damage: a broad axe on a long haft
		"poses": {
			"plant": {  # idle: resting on the axe, its head on the ground
				0: "............______",
				1: "............______",
				2: "............______",
				3: "............______",
				4: "............______",
				5: "............_k____",
				6: "............kak___",
				7: "............ksk___",
				8: "............kak___",
				9: "............kak___",
				10: "..........bkkak___",
				11: "............kakkk_",
				12: "............kakwwk",
				13: "............kakwWk",
				14: "............kakwwk",
				15: "............_kkkk.",
			},
			"swing": {  # raised high to chop
				0: "............______",
				1: "............______kkk",
				2: "............_____kwwwk",
				3: "............_____kwWWk",
				4: "............____kawwwk",
				5: "............___kakkkk",
				6: "............__kak___",
				7: "............_kak____",
				8: "............kak_____",
				9: "...........kak______",
				10: "............______",
				11: "............______",
				12: "............______",
			},
			"strike": {  # the chop, haft out level
				0: "............______",
				1: "............______",
				2: "............______",
				3: "............______",
				4: "............______",
				5: "............______",
				6: "............______..kkk.",
				7: "............______.kwwwk",
				8: "............kkkkkkkkwWWk",
				9: "............saaaaaakwWWk",
				10: "............kkkkkkkkwwwk",
				11: "............______",
				12: "............______",
			},
		},
		"base": "swordsman",
		"palette": {"a": Color(0.6, 0.42, 0.22), "w": Color(0.72, 0.75, 0.82), "W": Color(0.95, 0.97, 1.0)},
		"rows": [
			"......rr.....k....",
			".....krrk...kakkk.",
			"....khhhhk..kakwwk",
			"...khhhhhHk.kakwWk",
			"...khkkkkHk.kakwWk",
			"...khhhhhHk.kakwwk",
			"....kssssk..kakkk.",
			"..kkTttttTkkkak...",
			"..kTttttttTkkak...",
			"..kTttttttTkkak...",
			"..ksbbbbbbsksak...",
			"..kTttttttTkkak...",
			"...kTttttTk..k....",
			"...kppkkppk.......",
			"...kffk.kffk......",
			"...kkkk.kkkk......",
		],
		"legs_b": [
			"...kppkppk........",
			"....kffkffk.......",
			"....kkkkkkk.......",
		],
	},
	"swordsman_p1": {  # Speed: a sword in each hand
		"poses": {
			"plant": {  # idle: one sword planted, the other propped on his shoulder
				0: ".k..............",
				1: "kwk.............",
				2: "kwk.........____",
				3: "_kwk........____",
				4: "_kwk........____",
				5: "__kwk.......____",
				6: "__kgk.......kgk_",
				7: "__ks........ksk_",
				8: "___........kgggk",
				9: "__..........kwk_",
				10: "__.T......bkkwk_",
				11: "._..........kwk.",
				12: "............kwk.",
				13: "............kwk.",
				14: "............kwk.",
				15: "............_k..",
			},
			"strike2": {
				2: "__",
				3: "___",
				4: "___",
				5: "___",
				6: "___",
				7: "__",
				8: "__",
				9: "__..k",
				10: "__..gkkkkkkkkkkkkkkkkk",
				11: "__ksgwwwwwwwwwwwwwwwwwk",
				12: "....gkkkkkkkkkkkkkkkkk",
				13: "....k",
			},
		},
		"base": "swordsman",
		"palette": {},
		"rows": [
			"......rr........",
			".....krrk.......",
			".k..khhhhk....k.",
			"kwkkhhhhhHk..kwk",
			"kwkkhkkkkHk..kwk",
			"kwkkhhhhhHk..kwk",
			"kwk.kssssk...kwk",
			"kwkkTttttTkk.kwk",
			"kwkTttttttTk.kwk",
			"ggkTttttttTkgggk",
			"kgksbbbbbbskskk.",
			".kkTttttttTk.k..",
			"...kTttttTk.....",
			"...kppkkppk.....",
			"...kffk.kffk....",
			"...kkkk.kkkk....",
		],
	},
	"swordsman_p0p1": {  # Damage and Blades both at tier 3: an axe in each hand
		"poses": {
			"plant": {  # idle: resting on the right axe
				0: "............______",
				1: "............______",
				2: "............______",
				3: "............______",
				4: "............______",
				5: "............_k____",
				6: "............kak___",
				7: "............ksk___",
				8: "............kak___",
				9: "............kak___",
				10: "..........bkkak___",
				11: "............kakkk_",
				12: "............kakwwk",
				13: "............kakwWk",
				14: "............kakwwk",
				15: "............_kkkk.",
			},
			"swing": {
				0: "............______",
				1: "............______kkk",
				2: "............_____kwwwk",
				3: "............_____kwWWk",
				4: "............____kawwwk",
				5: "............___kakkkk",
				6: "............__kak___",
				7: "............_kak____",
				8: "............kak_____",
				9: "...........kak______",
				10: "............______",
				11: "............______",
				12: "............______",
			},
			"strike": {
				0: "............______",
				1: "............______",
				2: "............______",
				3: "............______",
				4: "............______",
				5: "............______",
				6: "............______..kkk.",
				7: "............______.kwwwk",
				8: "............kkkkkkkkwWWk",
				9: "............saaaaaakwWWk",
				10: "............kkkkkkkkwwwk",
				11: "............______",
				12: "............______",
			},
			"strike2": {  # the off-hand axe swept across
				0: "___",
				1: "___",
				2: "___",
				3: "___",
				4: "___",
				5: "___",
				6: "___",
				7: "___",
				8: "___",
				9: "__................kkkk",
				10: "__..kkkkkkkkkkkkkkkwWk",
				11: "__ksaaaaaaaaaaaaaakwWk",
				12: "....kkkkkkkkkkkkkkkwWk",
				13: "....k.............kkkk",
			},
		},
		"base": "swordsman",
		"palette": {"a": Color(0.6, 0.42, 0.22), "w": Color(0.72, 0.75, 0.82), "W": Color(0.95, 0.97, 1.0)},
		"rows": [
			".kkk..rr.....k....",
			"kwWk.krrk...kakkk.",
			"kwWkkhhhhk..kakwwk",
			"kkakhhhhhHk.kakwWk",
			"kakkhkkkkHk.kakwWk",
			"kakkhhhhhHk.kakwwk",
			"kak.kssssk..kakkk.",
			"kakkTttttTkkkak...",
			"kakTttttttTkkak...",
			"kakTttttttTkkak...",
			"kaksbbbbbbsksak...",
			".kkTttttttTkkak...",
			"...kTttttTk..k....",
			"...kppkkppk.......",
			"...kffk.kffk......",
			"...kkkk.kkkk......",
		],
		"legs_b": [
			"...kppkppk........",
			"....kffkffk.......",
			"....kkkkkkk.......",
		],
	},
	"swordsman_p2": {  # Health: full plate with gold trim and a kite shield
		"base": "swordsman",
		"palette": {"y": Color(1.0, 0.82, 0.3), "r": Color(0.25, 0.45, 0.95)},
		"rows": [
			".....rrr........",
			"....krrrk.......",
			"...kyhhhhyk...k.",
			"...khhhhhHk..kwk",
			"...khkkkkHk..kwk",
			"...kyhhhhyk..kwk",
			"....kHHHHk...kwk",
			"kkkkkkyyykhhkkwk",
			"kryyrkhhhhHk.kwk",
			"kyyyykyyhhHkgggk",
			"kryyrkyyyysksk..",
			"kryyrkhhhhHk.k..",
			".kryk.hhhHk.....",
			"..kkHHkkHHk.....",
			"...khhk.khhk....",
			"...kkkk.kkkk....",
		],
		"legs_b": [
			"..kkHHkHHk......",
			"....khhkhhk.....",
			"....kkkkkkk.....",
		],
	},
	"archer_p1": {  # Range: a crossbow
		"poses": {
			"draw": {
				6: "................kk",
				7: ".............wmnnak",
				8: "............scccck",
				9: ".............wmkk",
			},
		},
		"base": "archer",
		"palette": {"m": Color(0.6, 0.62, 0.68), "c": Color(0.5, 0.32, 0.15), "n": Color(0.7, 0.55, 0.35)},
		"rows": [
			"................",
			".....kkkkk......",
			"....kgggggk.....",
			".k.kgggggggk.k..",
			".kskgGsssGgks...",
			"..kkGskssksGk.k.",
			"...kGssssssGkkmk",
			".kGkkGGGGGGkkwmk",
			"kGklllllllllsccc",
			"kGkLklllllkLkwmk",
			".kkskLLLLLksk.mk",
			"...kllllllk...k.",
			"...kppppppk.....",
			"...kppkkppk.....",
			"...kffk.kffk....",
			"...kkkk.kkkk....",
		],
	},
	"archer_p2": {  # Attack speed: a full quiver on the back
		"base": "archer",
		"palette": {"q": Color(0.5, 0.3, 0.15), "e": Color(0.85, 0.25, 0.2)},
		"rows": [
			"................",
			".kek.kkkkk......",
			".kekkgggggk...k.",
			".kqkgggggggk.kbk",
			".kqkgGsssGgkswbk",
			".kqkGskssksGkw.b",
			".kqkGssssssGkw.b",
			".kqkkGGGGGGkkw.b",
			"kkklllllllllkssb",
			"kGkLklllllkLkw.b",
			".kkskLLLLLkskwbk",
			"...kllllllk..bk.",
			"...kppppppk..k..",
			"...kppkkppk.....",
			"...kffk.kffk....",
			"...kkkk.kkkk....",
		],
	},
	"mage_p0": {  # Storm: blue robes with lightning
		"base": "mage",
		"palette": {
			"P": Color(0.25, 0.4, 0.85), "Q": Color(0.15, 0.25, 0.6), "r": Color(0.3, 0.5, 0.95),
			"R": Color(0.18, 0.32, 0.7), "o": Color(0.6, 0.85, 1.0),
		},
		"rows": [
			".......kk.....k.",
			"......kPPk...kok",
			"......kPPk..kOok",
			".....kPPyPk..kok",
			"....kPPPPQPk.kwk",
			"..kQQQQQQQQk.kwk",
			"....kskssksk.kwk",
			"....kWWWWWWk.swk",
			"...krWWWWWWrkswk",
			"...krrWWWWrrk.wk",
			"..krrrWWryrRk.wk",
			"..kRrrrryrrRk.wk",
			"..kRrrrrryyRk.wk",
			"..kRRrrrryRRk.wk",
			"...kkfkkfkkk..k.",
			"....kk..kk......",
		],
	},
	"mage_p1": {  # Arcane Lance: deep purple robes with stars
		"base": "mage",
		"palette": {
			"P": Color(0.35, 0.18, 0.6), "Q": Color(0.22, 0.1, 0.4), "r": Color(0.45, 0.25, 0.75),
			"R": Color(0.3, 0.15, 0.55), "y": Color(1.0, 0.95, 0.6), "o": Color(1.0, 0.95, 0.6),
		},
		"rows": [
			".......kk.....k.",
			"......kPPk...kok",
			"......kPyk..kOok",
			".....kPPPPk..kok",
			"....kPPyPQPk.kwk",
			"..kQQQQQQQQk.kwk",
			"....kskssksk.kwk",
			"....kWWWWWWk.swk",
			"...krWWWWWWrkswk",
			"...kryWWWWrrk.wk",
			"..krrrWWrrrRk.wk",
			"..kRrrrrryrRk.wk",
			"..kRryrrrrrRk.wk",
			"..kRRrrryrRRk.wk",
			"...kkfkkfkkk..k.",
			"....kk..kk......",
		],
	},
	"mage_p2": {  # Fire: red robes with flames at the hem
		"base": "mage",
		"palette": {
			"P": Color(0.75, 0.15, 0.12), "Q": Color(0.5, 0.08, 0.06), "r": Color(0.85, 0.22, 0.15),
			"R": Color(0.6, 0.1, 0.08), "F": Color(1.0, 0.55, 0.1), "o": Color(1.0, 0.6, 0.2),
			"O": Color(1.0, 0.95, 0.6),
		},
		"rows": [
			".......kk.....k.",
			"......kPPk...kok",
			"......kPPk..kOok",
			".....kPPyPk..kok",
			"....kPPPPQPk.kwk",
			"..kQQQQQQQQk.kwk",
			"....kskssksk.kwk",
			"....kWWWWWWk.swk",
			"...krWWWWWWrkswk",
			"...krrWWWWrrk.wk",
			"..krrrWWrrrRk.wk",
			"..kRrrrrrrrRk.wk",
			"..kRFrrFrrFRk.wk",
			"..kFyFFyFFyFk.wk",
			"...kkfkkfkkk..k.",
			"....kk..kk......",
		],
	},
	"frost_p0": {  # Deep Cold: navy robes and an icicle crown
		"base": "frost",
		"palette": {
			"c": Color(0.2, 0.3, 0.6), "C": Color(0.12, 0.2, 0.45), "r": Color(0.18, 0.28, 0.6),
			"R": Color(0.1, 0.18, 0.42), "s": Color(0.85, 0.9, 0.98),
		},
		"rows": [
			"...kikkikkik..k.",
			"....kcccck...kik",
			"...kccccccCk.kIk",
			"...kchhhhhCk..k.",
			"...khskssksk..wk",
			"...khssssshk.swk",
			"...kkhhhhhkk.kwk",
			"..kCrrrrrrrCk.wk",
			"..kCrRrrrRrCk.wk",
			"..kCrrrrrrrCk.wk",
			"...kRrrrrrRk..wk",
			"...kRrirrrRk..wk",
			"..kRRrrrrrRRk.wk",
			"..kRRRrrrRRRk.wk",
			"...kkkfkfkkk..k.",
			"................",
		],
	},
	"frost_p1": {  # Blizzard: white fur cloak dusted with snowflakes
		"base": "frost",
		"palette": {
			"c": Color(0.95, 0.97, 1.0), "C": Color(0.72, 0.8, 0.9), "r": Color(0.88, 0.92, 0.98),
			"R": Color(0.68, 0.76, 0.88),
		},
		"rows": [
			".....kkkk.....k.",
			"....kcccck...kik",
			"...kccccccCk.kIk",
			"...kchhhhhCk..k.",
			"...khskssksk..wk",
			"...khssssshk.swk",
			"..kCCCCCCCk..kwk",
			"..kCrrrrrrrCk.wk",
			"..kCirrrrriCk.wk",
			"..kCrrrrrrrCk.wk",
			"...kRrrrrrRk..wk",
			"...kRrirrrRk..wk",
			"..kRRrrrirRRk.wk",
			"..kRRRrrrRRRk.wk",
			"...kkkfkfkkk..k.",
			"................",
		],
	},
	"frost_p2": {  # Flash Freeze: glowing eyes, ice shards and a giant crystal
		"poses": {
			"cast": {
				0: "............____",
				1: "............____",
				2: "............____",
				3: "............____.....kk",
				4: "............_kkkkkkkkiIk",
				5: ".............swwwwwwwiiIk",
				6: ".............kkkkkkkkiIk",
				7: "..............__.....kk",
				8: "..............__",
				9: "..............__",
				10: "..............__",
				11: "..............__",
				12: "..............__",
				13: "..............__",
				14: "..............__",
			},
		},
		"base": "frost",
		"palette": {"e": Color(0.4, 1.0, 1.0)},
		"rows": [
			".....kkkk....kk.",
			"....kcccck..kiIk",
			"...kccccccCkkiIk",
			"...kchhhhhCk.kik",
			"...khsessesk..wk",
			"...khssssshk.swk",
			".i.kkhhhhhkkikwk",
			".ikCrrrrrrrCkiwk",
			"..kCrRrrrRrCk.wk",
			"..kCrrrrrrrCk.wk",
			"...kRrrrrrRk..wk",
			"...kRrrrrrRk..wk",
			"..kRRrIrrrRRk.wk",
			"..kRRRrrrRRRk.wk",
			"...kkkfkfkkk..k.",
			"................",
		],
	},
	"martial_p1": {  # Combat (a Yamcha nod): his desert-bandit look: long shaggy hair, green tunic, orange scarf, white sash
		"base": "martial",
		"palette": {
			"h": Color(0.15, 0.13, 0.18), "V": Color(0.25, 0.55, 0.28), "O": Color(0.95, 0.55, 0.15),
			"W": Color(0.95, 0.95, 0.92), "R": Color(0.8, 0.22, 0.2), "c": Color(0.93, 0.87, 0.7),
			"b": Color(0.15, 0.13, 0.15), "P": Color(0.32, 0.26, 0.5), "A": Color(0.96, 0.77, 0.6),
			"Z": Color(0.96, 0.77, 0.6), "X": Color(0.15, 0.13, 0.15), "F": Color(0.96, 0.77, 0.6),
			"L": Color(0.93, 0.87, 0.7), "U": Color(0.32, 0.26, 0.5),
		},
		"rows": [
			"....k..k.k......",
			"...khkkhkhk.....",
			"..khhhhhhhhk....",
			".khhhhhhhhhhk...",
			".khhshhhshhhk...",
			".khkskssksk.hk..",
			".kh.kssssk..hk..",
			"..kkOOOOOOkk....",
			".kskVOOOOVVksk..",
			".kskVVOOVVVksk..",
			".kbkWWWWWWWkbk..",
			".kskVWVVVVVksk..",
			"...kRRRRRRRk....",
			"...kccckccck....",
			"...kPPk.kPPk....",
			"...kkkk.kkkk....",
		],
		"legs_b": [
			"....kcckcck.....",
			"....kPPkPPk.....",
			"....kkkkkkk.....",
		],
	},
	"martial_p1p2": {  # Combat and Techniques both at tier 3: Krillin's head on Yamcha's desert-bandit outfit
		"poses": {
			"punch": {
				8: "................kk",
				9: "...........kkkkkFFk",
				10: "...........AAZZXFFk",
				11: "...........kkkkkkk",
			},
		},
		"base": "martial",
		"palette": {
			"d": Color(0.35, 0.25, 0.25), "V": Color(0.25, 0.55, 0.28), "O": Color(0.95, 0.55, 0.15),
			"W": Color(0.95, 0.95, 0.92), "R": Color(0.8, 0.22, 0.2), "c": Color(0.93, 0.87, 0.7),
			"b": Color(0.15, 0.13, 0.15), "P": Color(0.32, 0.26, 0.5),
			"A": Color(0.96, 0.77, 0.6), "Z": Color(0.96, 0.77, 0.6), "X": Color(0.15, 0.13, 0.15),
			"F": Color(0.96, 0.77, 0.6), "L": Color(0.93, 0.87, 0.7), "U": Color(0.32, 0.26, 0.5),
		},
		"rows": [
			"................",
			"................",
			"................",
			".....kkkkk......",
			"....ksdsdsk.....",
			"...ksdsdsdsk....",
			"...ksksssksk....",
			"....ksssssk.....",
			"..kkOOOOOOkk....",
			".kskVVOOVVVksk..",
			".kbkWWWWWWWkbk..",
			".kskVWVVVVVksk..",
			"...kRRRRRRRk....",
			"...kccckccck....",
			"...kPPk.kPPk....",
			"...kkkk.kkkk....",
		],
		"legs_b": [
			"....kcckcck.....",
			"....kPPkPPk.....",
			"....kkkkkkk.....",
		],
	},
	"martial_p3": {  # Power (a Goku nod): wild spiky hair, orange gi, blue undershirt and belt
		"base": "martial",
		"palette": {
			"h": Color(0.2, 0.17, 0.25), "o": Color(0.95, 0.55, 0.15), "B": Color(0.2, 0.3, 0.75),
			"A": Color(0.95, 0.55, 0.15), "Z": Color(0.96, 0.77, 0.6), "X": Color(0.2, 0.3, 0.75),
			"F": Color(0.96, 0.77, 0.6), "L": Color(0.95, 0.55, 0.15), "U": Color(0.2, 0.3, 0.75),
		},
		"rows": [
			"......k..k......",
			"..k..khkkhk..k..",
			"..khkhhhhhhkhk..",
			".khhhhhhhhhhhhk.",
			"..khhshhshhhk...",
			"...kskssksk.....",
			"....kssssk......",
			"..kkoBBBBokk....",
			".kokooBBoookok..",
			".kokoooooookok..",
			".kBkBBBBBBBkBk..",
			".kskoooooooksk..",
			"...koookoook....",
			"...koookoook....",
			"...kBBk.kBBk....",
			"...kkkk.kkkk....",
		],
		"legs_b": [
			"....kookook.....",
			"....kBBkBBk.....",
			"....kkkkkkk.....",
		],
	},
	"swordsman_p3": {  # Charge: a samurai: black kabuto with a gold crest, red half-mask, red lacquered armor, hakama and a katana
		"base": "swordsman",
		"palette": {
			"y": Color(0.95, 0.8, 0.3), "h": Color(0.2, 0.18, 0.24), "r": Color(0.78, 0.18, 0.18),
			"T": Color(0.72, 0.16, 0.16), "t": Color(0.5, 0.1, 0.12), "R": Color(0.75, 0.18, 0.18),
			"n": Color(0.95, 0.8, 0.35), "p": Color(0.18, 0.2, 0.32), "f": Color(0.9, 0.9, 0.86),
			"b": Color(0.9, 0.88, 0.8), "g": Color(0.35, 0.3, 0.4),
		},
		"rows": [
			"...yy....yy.....",
			".....yy.yy......",
			"....khyyhk....k.",
			"...khhhhhhk..kwk",
			".khksksskskhkkwk",
			".khksssssskhkkwk",
			"..kkrrrrrrkk.kwk",
			"kTTkRRRRRRkTTkwk",
			"kTTkRnnnnRkTTkwk",
			".ktkRRRRRRktgggk",
			"..ksbbbbbbskskk.",
			"..kpppppppppkk..",
			"..kpppppppppk...",
			"..kpppkkpppk....",
			"...kffk.kffk....",
			"...kkkk.kkkk....",
		],
	},
	"archer_p3": {  # Trick Shots: a blue-hooded mystic with a glowing string and seeker arrows
		"base": "archer",
		"palette": {
			"g": Color(0.28, 0.42, 0.78), "G": Color(0.17, 0.27, 0.55), "w": Color(0.55, 0.95, 1.0),
			"c": Color(0.6, 1.0, 1.0),
		},
		"rows": [
			"..............c.",
			".....kkkkk......",
			"....kgggggk...k.",
			".k.kgggggggk.kbk",
			".kskgGsssGgkswbk",
			"..kkGskssksGkw.b",
			"...kGssssssGkw.b",
			".kGkkGGGGGGkkw.b",
			"kGklllllllllkssc",
			"kGkLklllllkLkw.b",
			".kkskLLLLLkskwbk",
			"...kllllllk..bk.",
			"...kppppppk..k..",
			"...kppkkppk.c...",
			"...kffk.kffk....",
			"...kkkk.kkkk....",
		],
	},
	"mage_p3": {  # Necromancy: a black hooded robe, glowing green eyes and a skull-topped staff
		"base": "mage",
		"palette": {
			"P": Color(0.2, 0.22, 0.2), "Q": Color(0.13, 0.15, 0.13), "y": Color(0.45, 0.95, 0.4),
			"e": Color(0.45, 1.0, 0.45), "W": Color(0.28, 0.3, 0.28), "r": Color(0.2, 0.22, 0.2),
			"R": Color(0.12, 0.14, 0.12), "o": Color(0.9, 0.88, 0.8), "O": Color(0.55, 0.53, 0.47),
		},
		"rows": [
			".......kk.....k.",
			"......kPPk...kok",
			"......kPPk..kOok",
			".....kPPyPk..kok",
			"....kPPPPQPk.kwk",
			"..kQQQQQQQQk.kwk",
			"....kseskesk.kwk",
			"....kWWWWWWk.swk",
			"...krWWyyWWrkswk",
			"...krrWWWWrrk.wk",
			"..krrrWWrrrRk.wk",
			"..kRrrryrrrRk.wk",
			"..kRrrrrrryRk.wk",
			"..kRyRrrrrRRk.wk",
			"...kkfkkfkkk..k.",
			"....kk..kk......",
		],
	},
	"frost_p3": {  # Frost Aura: a snow queen in a pale gown and blue cape, a tall ice crown and drifting frost
		"base": "frost",
		"palette": {
			"r": Color(0.9, 0.92, 1.0), "R": Color(0.72, 0.78, 0.95), "C": Color(0.6, 0.8, 1.0),
			"b": Color(0.3, 0.5, 0.9),
		},
		"rows": [
			"..i.kikkik.i..k.",
			"....kcccck...kik",
			"...kccccccCk.kIk",
			"...kchhhhhCk..k.",
			"...khskssksk..wk",
			"...khssssshk.swk",
			"..bkkhhhhhkk.kwk",
			".bkCrrrrrrrCk.wk",
			".bkCrRrrrRrCk.wk",
			".bkCrrrrrrrCki.k",
			".bbkRrrrrrRk..wk",
			".bbkRrirrrRk..wk",
			".bkRRrrrrrRRk.wk",
			"i.kRRRrrrRRRk.wk",
			"...kkkfkfkkk..k.",
			"..i.........i...",
		],
	},
	"healer_p3": {  # Halo: angelic white-and-gold robes, feathered wings and a halo
		"base": "healer",
		"palette": {
			"u": Color(0.97, 0.97, 1.0), "G": Color(0.95, 0.82, 0.35),
		},
		"rows": [
			".....yyyy.....k.",
			".....kkkk....kok",
			"....kHHHHk..kOok",
			"...kHHHHHHk..kok",
			"...kHskssksk.kwk",
			"...kHssssssk.kwk",
			"uu.kkHHHHHHk.kwk",
			"uukHHHgggHHHkswk",
			"kukHHHHyHHHHkswk",
			".kkHHHyyyHHHk.wk",
			"..kHHHHyHHHHk.wk",
			"..kHHHHHHHHHk.wk",
			"..kHHHHHHHHHk.wk",
			"..kyyyyyyyyyk.wk",
			"...kkfkkfkkk..k.",
			"....kk..kk......",
		],
	},
	"bard_p3": {  # Bewitch: an enchanter in magenta and a masquerade mask, playing a jingling hand drum
		"poses": {
			"strum": {
				9: "..kTkTTTTTkDsDk.",
			},
		},
		"base": "bard",
		"palette": {
			"R": Color(0.7, 0.22, 0.58), "T": Color(0.92, 0.48, 0.75), "y": Color(0.98, 0.9, 0.95),
			"F": Color(0.55, 0.95, 1.0), "m": Color(0.85, 0.3, 0.7), "p": Color(0.35, 0.18, 0.38),
			"D": Color(0.9, 0.82, 0.62), "j": Color(1.0, 0.85, 0.3),
		},
		"rows": [
			".......kk.k.....",
			".....kkRRkFk....",
			"....kRRRRRkk....",
			"...kRRRRRRRk....",
			"....kmkmmkmk....",
			"....kssssssk....",
			".....kssssk..kk.",
			"...kkTTyyTTkkDDk",
			"..kTTTTyyTTkDDDk",
			"..kTkTTTTTskDjDk",
			"..kskTTTTkkDDDk.",
			"...kTTTTTk.kDDk.",
			"...kppppppk.kk..",
			"...kppkkppk.....",
			"...kffk.kffk....",
			"...kkkk.kkkk....",
		],
	},
	"alchemist_p3": {  # Trapcraft: a sapper with goggles up on a leather cap, an olive coat and a bandolier of red charges
		"base": "alchemist",
		"palette": {
			"h": Color(0.4, 0.27, 0.15), "C": Color(0.42, 0.45, 0.25), "A": Color(0.52, 0.55, 0.32),
			"n": Color(0.4, 0.27, 0.15), "e": Color(0.88, 0.25, 0.2),
		},
		"rows": [
			"......kkkk......",
			".....khhhhk.....",
			"....kGgGGgGk....",
			"....khhhhhhk....",
			"....kssssssk....",
			"....kskssksk....",
			".....kssssk..kk.",
			"...kkCnAAACk.kek",
			"..kCCAenAAACkeek",
			"..kCkAAenAkCkeek",
			"..kskAAAenkssk..",
			"...kaaaaaak.....",
			"...kAAAAAAk.....",
			"...kppkkppk.....",
			"...kffk.kffk....",
			"...kkkk.kkkk....",
		],
	},
	"tower_p3": {  # Fire Arrows: braziers blazing on both turrets and an orange war banner
		"base": "tower",
		"palette": {
			"e": Color(1.0, 0.55, 0.15), "y": Color(1.0, 0.9, 0.4),
		},
		"rows": [
			".e....kkkk....e.",
			"eye..kggggk..eye",
			".kkk.kgssgk.kkk.",
			".kSk.kGGGGk.kSk.",
			".kSkkkbbbbkkkSk.",
			".kSSSSSSSSSSSSk.",
			".kkkkkkkkkkkkkk.",
			"..kSSDkeeekSSk..",
			"..kSSDkeyekSSk..",
			"..kDDDkeeekDDk..",
			"..kSDSkekekDSk..",
			"..kTDSSSSSSDTk..",
			"..kDDDDDDDDDDk..",
			".kSSSDSSSSDSSSk.",
			".kTSSDSSSSDSSTk.",
			".kkkkkkkkkkkkkk.",
		],
	},
	"cannon_p3": {  # Payloads: a soot-black barrel with flame stripes and a crate of incendiary shells
		"base": "cannon",
		"palette": {
			"M": Color(0.18, 0.17, 0.2), "N": Color(1.0, 0.5, 0.15), "e": Color(0.9, 0.25, 0.2),
			"d": Color(0.5, 0.33, 0.18),
		},
		"rows": [
			"..............e.",
			"............kkk.",
			"...........kNNNk",
			"..........kMNMNk",
			".........kMNMMk.",
			"..kkk...kMMNMk..",
			".kRRRk.kMNMMk...",
			"..ksk.kMMNMk....",
			"..ksk.kMMMk.....",
			".kBBBk.kkkkk....",
			"kBBBBBkWWWWWk...",
			"ksBBBsk.kkk.kkkk",
			".kpppk.kWWWkeeek",
			".kpkpk.kWkWkdddk",
			".kfkfk.kWWWkdddk",
			".kkkkk..kkk.kkkk",
		],
	},
	"magetower_p3": {  # Necromancy: dark stone, a black-hatted necromancer, a skull banner and green-lit windows
		"base": "magetower",
		"palette": {
			"P": Color(0.18, 0.2, 0.18), "Q": Color(0.12, 0.14, 0.12), "y": Color(0.45, 0.95, 0.4),
			"e": Color(0.45, 1.0, 0.45), "W": Color(0.25, 0.28, 0.25), "S": Color(0.42, 0.44, 0.42),
			"D": Color(0.3, 0.32, 0.3), "T": Color(0.36, 0.38, 0.36), "R": Color(0.15, 0.3, 0.15),
			"o": Color(0.9, 0.88, 0.8), "g": Color(0.45, 1.0, 0.45),
		},
		"rows": [
			".......kk.......",
			"......kPPk......",
			".kkk.kPPyPk.kkk.",
			".kSkkQQQQQQkkSk.",
			".kSk.keskek.kSk.",
			".kSSSkWWWWkSSSk.",
			".kkkkkkkkkkkkkk.",
			"..kSSkRRRRkSSk..",
			"..kSykRooRkySk..",
			"..kDDkRgRgkDDk..",
			"..kSDkRRRRkDSk..",
			"..kTDSkRRkSDTk..",
			"..kDDDDkkDDDDk..",
			".kSSSDSSSSDSSSk.",
			".kTSSDSSSSDSSTk.",
			".kkkkkkkkkkkkkk.",
		],
	},
	"frosttower_p3": {  # Frost Aura: an ice-blue spire with frost drifting off it and a glowing banner
		"base": "frosttower",
		"palette": {
			"S": Color(0.72, 0.85, 0.95), "D": Color(0.55, 0.7, 0.85), "T": Color(0.62, 0.78, 0.9),
			"I": Color(0.92, 0.97, 1.0), "e": Color(0.55, 0.95, 1.0), "Y": Color(0.6, 1.0, 1.0),
		},
		"rows": [
			"i.....kkkk.....i",
			".....kcccck.....",
			".kkkkcccccckkkk.",
			".kSkkhseseshkSk.",
			".kSkkCrrrrCkkSk.",
			".kIIIIIIIIIIIIk.",
			".kkkkkkkkkkkkkk.",
			"i.kSSkRRRRkSSk.i",
			"..kSSkRYYRkSSk..",
			"..kDDkRRRRkDDk..",
			"i.kSDkRYYRkDSk.i",
			"..kTDSkRRkSDTk..",
			"..kDDDDkkDDDDk..",
			".kSSSDSSSSDSSSk.",
			"ikTSSDSSSSDSSTki",
			".kkkkkkkkkkkkkk.",
		],
	},
	"medbay_p3": {  # Consecration: a gold-trimmed chapel tent with a golden cross and a sunburst
		"base": "medbay",
		"palette": {
			"r": Color(0.95, 0.78, 0.25), "w": Color(0.95, 0.8, 0.35), "y": Color(1.0, 0.92, 0.5),
		},
		"rows": [
			"......y..y......",
			".....y....y.....",
			".......kk.......",
			"......kWWk......",
			".....kWWWWk.....",
			"....kWWrrWWk....",
			"...kWWWrrWWWk...",
			"..kWWrrrrrrWWk..",
			".kWWWrrrrrrWWWk.",
			"kWWWWWWrrWWWWWWk",
			"kwWWWWWrrWWWWWwk",
			"kwWWWWkkkkWWWWwk",
			"kwWWWkxxxxkWWWwk",
			"kwWWkxxyyxxkWWwk",
			"kwWWkxxxxxxkWWwk",
			"kkkkkkkkkkkkkkkk",
		],
	},
	"statue_p3": {  # Vigor: a mossy statue on a fountain basin, water spilling over the rim
		"base": "statue",
		"palette": {
			"g": Color(0.35, 0.6, 0.3), "b": Color(0.35, 0.6, 0.95), "w": Color(0.6, 0.85, 1.0),
		},
		"rows": [
			"...........k....",
			"..........kSk...",
			"......kk..kSk...",
			".....kSSk.kSk...",
			".....kSSk.kSk...",
			"......kk..kDk...",
			"....kkSSkkkDk...",
			"...kSSgSSSSk....",
			"...kSkSSgSk.....",
			"...kgkSSSSk.....",
			"...kDkSgSSk.....",
			".....kSkSk......",
			".wkkkkkkkkkkkkw.",
			".kbbbbbbbbbbbbk.",
			"wkPPPPPPPPPPPPkw",
			".kkkkkkkkkkkkkk.",
		],
	},
	"mine_p3": {  # Gemcutters: the rock studded with big cyan and violet crystals, gems piled out front
		"base": "mine",
		"palette": {
			"c": Color(0.55, 0.95, 1.0), "C": Color(0.3, 0.7, 0.9), "v": Color(0.8, 0.5, 1.0),
			"V": Color(0.55, 0.3, 0.8),
		},
		"rows": [
			"......c.........",
			".....kckkkk..v..",
			"...kkRcCRRRkkvk.",
			"..kRRRRRRrRRvVk.",
			"..kRRRRRRrRRRk..",
			".kRrRkkkkkkRRRk.",
			".kcRkWWWWWWkRrk.",
			"kcCRkWxxxxWkRRRk",
			"kRcRkWxxxxWkvRRk",
			"kRRRkWxxxxWkVvRk",
			"kRRRkWxxxxWkRRRk",
			"kRRRkWxxxxWkRRRk",
			"kRRRkWxxxxWkRRRk",
			"kkckkkkkkkkkkvkk",
			".kcCck....kvVvk.",
			"..kkk......kkk..",
		],
	},
	"skeleton": {  # Raised by Necromancy: bare bones, green-glowing eyes and a rusty sword
		"palette": {
			"B": Color(0.9, 0.88, 0.8), "D": Color(0.62, 0.6, 0.55), "e": Color(0.45, 1.0, 0.55),
			"w": Color(0.62, 0.58, 0.52), "g": Color(0.45, 0.3, 0.15),
		},
		"rows": [
			"................",
			".....kkkkk......",
			"....kBBBBBk..k..",
			"...kBBBBBBBkkwk.",
			"...kBkeBkeBkkwk.",
			"...kBBBkBBBkkwk.",
			"....kBkBkBk.kwk.",
			".....kkkkk..kwk.",
			"...kDBDBDk.kgggk",
			"..kBkDBDkBk.kBk.",
			"..kBkkkkkBk.....",
			"....kDDDDk......",
			"....kBkkBk......",
			"....kBk.kBk.....",
			"....kBk.kBk.....",
			"...kkkk.kkkk....",
		],
		"legs_b": [
			"...kBk..kBk.....",
			"...kBk...kBk....",
			"..kkkk...kkkk...",
		],
	},
}

## Accents (see Sprites.frames): one per upgrade path, in path order, worn when that
## path is upgraded but another path sets the outfit. "behind" pixels only fill empty
## space, so they tuck in behind any outfit; "over" pixels paint over it.
const ACCENTS := {
	"swordsman": [
		{"behind": {7: "k1", 8: "k11", 9: "k11", 10: "k12", 11: "k12", 12: "k12", 13: ".kk"}, "palette": {"1": Color(0.75, 0.15, 0.15), "2": Color(0.55, 0.1, 0.12)}},
		{"over": {10: "......1111", 11: ".........1", 12: ".........1"}, "palette": {"1": Color(0.8, 0.15, 0.18)}},
		{"over": {7: "..k55k..k55k", 8: "..k6k....k6k"}, "palette": {"5": Color(0.8, 0.82, 0.88), "6": Color(0.55, 0.58, 0.66)}},
		{"behind": {0: "...3.....3", 1: "....3...3"}, "palette": {"3": Color(0.95, 0.8, 0.3)}},
	],
	"archer": [
		{"palette": {}},   # Damage: her arrows change instead (see Warrior.ARROW_GRADES)
		{"behind": {8: "k3", 9: "k33", 10: "k34", 11: "k34", 12: "k34", 13: ".kk"}, "palette": {"3": Color(0.22, 0.42, 0.22), "4": Color(0.15, 0.3, 0.15)}},
		{"behind": {1: ".5.5", 2: ".k.k", 3: "k66", 4: "k66", 5: "k66", 6: ".kk"}, "palette": {"5": Color(0.92, 0.9, 0.85), "6": Color(0.55, 0.35, 0.18)}},
		{"behind": {0: ".............7.7", 1: "..............7", 12: "..............7", 13: ".............7"}, "palette": {"7": Color(0.55, 0.95, 1.0)}},
	],
	"mage": [
		{"behind": {1: "...1", 2: "..11", 3: "...1", 4: "..1"}, "palette": {"1": Color(0.6, 0.85, 1.0)}},
		{"over": {10: ".....3", 11: "....333", 12: ".....3"}, "palette": {"3": Color(1.0, 0.55, 0.95)}},
		{"over": {1: ".............k5k", 2: "............k65k", 3: ".............k5k"}, "palette": {"5": Color(1.0, 0.55, 0.15), "6": Color(1.0, 0.9, 0.4)}},
		{"over": {9: "......777", 10: "......878"}, "palette": {"7": Color(0.9, 0.88, 0.8), "8": Color(0.2, 0.5, 0.2)}},
	],
	"frost": [
		{"behind": {0: "...1.1...1.1"}, "over": {1: ".....1..1"}, "palette": {"1": Color(0.75, 0.95, 1.0)}},
		{"behind": {7: "k3", 8: "k33", 9: "k34", 10: "k34", 11: "k34", 12: "k34", 13: ".kk"}, "palette": {"3": Color(0.95, 0.97, 1.0), "4": Color(0.8, 0.85, 0.92)}},
		{"over": {4: "......5..5"}, "palette": {"5": Color(0.5, 0.95, 1.0)}},
		{"behind": {1: "..7", 5: ".7", 9: "7", 12: ".7", 11: "............7"}, "palette": {"7": Color(0.85, 0.97, 1.0)}},
	],
	"martial": [
		{"behind": {9: "1.............1", 10: "1.............1"}, "palette": {"1": Color(1.0, 0.9, 0.35)}},
		{"behind": {2: "..............k", 3: ".............k4k", 4: "............k4k", 5: "...........k3k", 6: "..........k3k"}, "palette": {"3": Color(0.3, 0.2, 0.15), "4": Color(0.75, 0.77, 0.82)}},
		{"behind": {1: "5.5", 2: ".5", 3: "5.5"}, "palette": {"5": Color(1.0, 1.0, 0.75)}},
		{"behind": {11: "7.............7", 12: ".7..........7", 13: "..7........7"}, "palette": {"7": Color(1.0, 0.85, 0.3)}},
	],
	"healer": [
		{"behind": {8: ".k", 9: "k1", 10: "k2", 11: "k1", 12: "k1", 13: ".k"}, "over": {7: "...1", 8: "....1"}, "palette": {"1": Color(0.6, 0.4, 0.2), "2": Color(0.95, 0.3, 0.3)}},
		{"behind": {0: "..3..........3", 1: "3..........3"}, "palette": {"3": Color(1.0, 0.9, 0.4)}},
		{"behind": {5: "..5", 6: ".55", 7: "56", 8: ".5"}, "palette": {"5": Color(0.4, 0.8, 0.3), "6": Color(1.0, 0.6, 0.75)}},
		{"behind": {0: ".....7777"}, "palette": {"7": Color(1.0, 0.92, 0.45)}},
	],
	"bard": [
		{"behind": {0: "...........11", 1: "............1"}, "palette": {"1": Color(1.0, 0.85, 0.3)}},
		{"behind": {3: "..k", 4: ".343", 5: "..3"}, "palette": {"3": Color(0.55, 0.25, 0.7), "4": Color(1.0, 0.85, 0.3)}},
		{"behind": {0: "......56", 1: ".......5"}, "palette": {"5": Color(0.35, 0.75, 0.3), "6": Color(1.0, 0.6, 0.8)}},
		{"over": {4: ".....7k77k7"}, "palette": {"7": Color(0.9, 0.3, 0.7)}},
	],
	"alchemist": [
		{"over": {11: ".....11"}, "palette": {"1": Color(0.65, 0.35, 0.95)}},
		{"over": {10: "...3.......33"}, "palette": {"3": Color(0.15, 0.15, 0.18)}},
		{"behind": {9: "6", 10: ".5", 11: "565", 12: ".5"}, "palette": {"5": Color(0.2, 0.2, 0.22), "6": Color(1.0, 0.75, 0.2)}},
		{"over": {7: "....8", 8: ".....87", 9: "......87", 10: ".......8"}, "palette": {"7": Color(0.9, 0.25, 0.2), "8": Color(0.45, 0.3, 0.15)}},
	],
	"tower": [
		{"over": {9: "...1111..1111"}, "palette": {"1": Color(0.55, 0.57, 0.62)}},
		{"behind": {0: "..........k33", 1: "..........k3"}, "palette": {"3": Color(0.3, 0.5, 0.9)}},
		{"over": {7: "......5555", 8: "......5655", 9: "......5555", 10: ".......55"}, "palette": {"5": Color(0.8, 0.2, 0.2), "6": Color(0.95, 0.8, 0.3)}},
		{"behind": {0: "..7..........7", 1: ".787........787"}, "palette": {"7": Color(1.0, 0.55, 0.15), "8": Color(1.0, 0.9, 0.4)}},
	],
	"cannon": [
		{"behind": {13: ".............kk", 14: "............k11k", 15: "............kkkk"}, "palette": {"1": Color(0.25, 0.25, 0.28)}},
		{"over": {4: "..........3", 6: "........3"}, "palette": {"3": Color(0.85, 0.2, 0.2)}},
		{"behind": {9: ".............kkk", 10: ".............k5k", 11: ".............k6k", 12: ".............kkk"}, "palette": {"5": Color(0.55, 0.35, 0.18), "6": Color(0.35, 0.36, 0.4)}},
		{"behind": {0: "............8.7.", 1: "...............7"}, "palette": {"7": Color(1.0, 0.55, 0.15), "8": Color(1.0, 0.85, 0.35)}},
	],
	"magetower": [
		{"behind": {0: "..1", 1: ".1.1"}, "palette": {"1": Color(0.6, 0.85, 1.0)}},
		{"behind": {0: ".............3", 1: "............343"}, "palette": {"3": Color(1.0, 0.55, 0.95), "4": Color(1.0, 0.95, 1.0)}},
		{"behind": {7: ".5", 8: "56", 9: ".k"}, "palette": {"5": Color(1.0, 0.55, 0.15), "6": Color(1.0, 0.9, 0.4)}},
		{"over": {8: ".......77", 9: ".......88"}, "palette": {"7": Color(0.9, 0.88, 0.8), "8": Color(0.45, 1.0, 0.4)}},
	],
	"frosttower": [
		{"over": {7: "...1........1", 8: "...1........1"}, "palette": {"1": Color(0.85, 0.97, 1.0)}},
		{"over": {5: "..3..3..3..3"}, "palette": {"3": Color(0.97, 0.98, 1.0)}},
		{"over": {3: ".......5.5"}, "palette": {"5": Color(0.5, 0.95, 1.0)}},
		{"behind": {0: "7............7", 8: "7..............7", 11: ".7............7"}, "palette": {"7": Color(0.85, 0.97, 1.0)}},
	],
	"medbay": [
		{"over": {12: ".111", 13: ".121", 14: ".111"}, "palette": {"1": Color(0.6, 0.42, 0.24), "2": Color(0.42, 0.28, 0.15)}},
		{"behind": {0: ".......k33", 1: ".......k"}, "palette": {"3": Color(0.3, 0.5, 0.9)}},
		{"over": {10: "............5", 11: "...........555", 12: "............5"}, "palette": {"5": Color(0.4, 0.85, 0.4)}},
		{"behind": {0: ".....7....7", 1: "......7..7"}, "palette": {"7": Color(1.0, 0.9, 0.45)}},
	],
	"statue": [
		{"behind": {1: ".....1111"}, "palette": {"1": Color(1.0, 0.85, 0.3)}},
		{"behind": {5: "3", 6: "33", 7: "33", 8: ".3"}, "palette": {"3": Color(0.75, 0.9, 0.85)}},
		{"over": {8: ".kkk", 9: ".k5k", 10: ".k5k", 11: "..k"}, "palette": {"5": Color(0.35, 0.36, 0.42)}},
		{"over": {13: "....7..8..7", 14: "...7.88...7.8"}, "palette": {"7": Color(0.4, 0.65, 1.0), "8": Color(0.35, 0.65, 0.3)}},
	],
	"mine": [
		{"over": {4: ".....1......1", 9: "...........1", 11: "..1"}, "palette": {"1": Color(1.0, 0.85, 0.3)}},
		{"behind": {15: "33...333333...33"}, "palette": {"3": Color(0.5, 0.5, 0.55)}},
		{"over": {12: "......6.6", 13: ".....k5665k", 14: ".....k5665k", 15: ".....kkkkkk"}, "palette": {"5": Color(0.6, 0.38, 0.18), "6": Color(1.0, 0.85, 0.3)}},
		{"over": {3: "......7", 6: "..7", 10: "..............8", 11: "..8"}, "palette": {"7": Color(0.55, 0.95, 1.0), "8": Color(0.8, 0.5, 1.0)}},
	],
}

## Special Bard instruments (see Warrior.special_instrument): laid over any outfit,
## they wipe out the instrument it was holding (everything at x >= 10 below the face)
## and draw the new one there instead.
const INSTRUMENT_LAYERS := {
	"violin": {"over": {4: "............$$$$", 5: "..........____kk", 6: "..........__kk#k", 7: "..........kk@@k_", 8: "..........k@#@k_", 9: "..........k@@@k_", 10: ".........._kkk__", 11: "..........k_____", 12: "..........k_____", 13: "..........k_____"}, "palette": {"@": Color(0.62, 0.33, 0.14), "#": Color(0.35, 0.17, 0.07), "$": Color(0.95, 0.92, 0.85), "%": Color(0.95, 0.92, 0.8), "&": Color(1.0, 0.82, 0.3)}},
	"cello": {"over": {4: "..............k.", 5: "..........___k#k", 6: "..........___k#k", 7: "..........k_k@@k", 8: "..........kk@@@k", 9: "..........$$$$$$", 10: "..........kk@#@k", 11: "..........k_k@@k", 12: "..........k__kk_", 13: "..........k___k_"}, "palette": {"@": Color(0.62, 0.33, 0.14), "#": Color(0.35, 0.17, 0.07), "$": Color(0.95, 0.92, 0.85), "%": Color(0.95, 0.92, 0.8), "&": Color(1.0, 0.82, 0.3)}},
	"harp": {"over": {5: "..........______", 6: "..........__k&&k", 7: "..........kk&%&k", 8: "..........k&%%&k", 9: "..........s&%%&k", 10: "..........k&%%&k", 11: "..........k&&&&k", 12: "..........kkkkk_", 13: "..........______"}, "palette": {"@": Color(0.62, 0.33, 0.14), "#": Color(0.35, 0.17, 0.07), "$": Color(0.95, 0.92, 0.85), "%": Color(0.95, 0.92, 0.8), "&": Color(1.0, 0.82, 0.3)}},
}

static var _cache := {}


## Returns [walk frame A, walk frame B] for a sprite. recolor swaps palette letters
## for other colors (e.g. golden hair), and layers are accents laid on top (see
## ACCENTS); tag names the variant for the cache.
static func frames(sprite: String, recolor := {}, tag := "", layers := []) -> Array:
	var key := sprite + tag
	if not _cache.has(key):
		var s: Dictionary = _entry(sprite)
		var palette := _layer_palette(_palette(sprite).merged(_recolor_for(s, recolor), true), layers)
		var rows: Array = s["rows"]
		var alt: Array = s["alt"] if s.has("alt") else _alt_rows(sprite)
		_cache[key] = [_make(_layered(rows, layers), palette), _make(_layered(alt, layers), palette)]
	return _cache[key]


## An attack pose (see "poses" on the sprites), or null if the sprite has none by
## that name. Variants use the base sprite's poses unless they define their own.
static func pose(sprite: String, pose_name: String, recolor := {}, tag := "", layers := []):
	var key := sprite + tag + ":" + pose_name
	if not _cache.has(key):
		var s: Dictionary = _entry(sprite)
		_cache[key] = null
		var posed = _posed_rows(sprite, pose_name)
		if posed != null:
			var palette := _layer_palette(_palette(sprite).merged(_recolor_for(s, recolor), true), layers)
			_cache[key] = _make(_layered(posed, layers), palette)
	return _cache[key]


## A sprite's rows in an attack pose, or null if it has none by that name.
static func _posed_rows(sprite: String, pose_name: String):
	var s: Dictionary = _entry(sprite)
	if s.has("full_poses"):
		return s["full_poses"].get(pose_name)
	var poses: Dictionary = s.get("poses", {})
	if not poses.has(pose_name) and s.has("base"):
		poses = SPRITES[s["base"]].get("poses", {})
	return _overlay(s["rows"], poses[pose_name]) if poses.has(pose_name) else null


## Second walk frame: the bottom rows swapped for legs_b (the base sprite's, if the
## variant has none).
static func _alt_rows(sprite: String) -> Array:
	var s: Dictionary = _entry(sprite)
	var legs: Array = s.get("legs_b", [])
	if legs.is_empty() and s.has("base"):
		legs = SPRITES[s["base"]].get("legs_b", [])
	var rows: Array = s["rows"]
	return rows.slice(0, SIZE - legs.size()) + legs


## Variants inherit the base sprite's palette, overriding some colors.
static func _palette(sprite: String) -> Dictionary:
	var s: Dictionary = _entry(sprite)
	if s.has("base"):
		return SPRITES[s["base"]]["palette"].merged(s["palette"], true)
	return s["palette"]


## A drawn sprite, or one made up by combo().
static func _entry(sprite: String) -> Dictionary:
	return SPRITES[sprite] if SPRITES.has(sprite) else _generated[sprite]


## A recolor of the original letters (e.g. "h" for hair) also reaches a combined
## sprite, whose letters were renamed when its two outfits were put together.
static func _recolor_for(s: Dictionary, recolor: Dictionary) -> Dictionary:
	if recolor.is_empty() or not s.has("from"):
		return recolor
	var out := {}
	for sym in s["from"]:
		if recolor.has(s["from"][sym]):
			out[sym] = recolor[s["from"][sym]]
	return out


# --- Combined outfits ------------------------------------------------------------
# When two of a unit's paths are both at tier 3, it wears a mix of the two outfits:
# each part of the sprite comes from one of them. "map" cuts the sprite into parts:
#   figure  head (rows 0..head_rows, left of right_col), left (cols 0..left_col below
#           the head), right (cols right_col and on; the head rows too if right_full),
#           body (the rest)
#   top     head (rows 0..head_rows) and body (the rest)
#   sides   left (cols 0..split) and right (the rest)
# "lead" is picked first, by "order" (the first path in the list that's in the pair;
# else the second path of the pair); every other part listed in "order" goes by its
# list, and anything else comes from the other path. A hand-drawn sprite named
# <kind>_p<a>p<b> (e.g. swordsman_p0p1) is used instead when there is one.
const COMBOS := {
	"swordsman": {"map": "figure", "head_rows": 6, "left_col": 4, "right_col": 12, "right_full": true,
		"lead": "body", "order": {"body": [2, 3, 1, 0], "head": [3, 2], "left": [1, 2], "right": [0, 1]}},
	"archer": {"map": "figure", "head_rows": 7, "left_col": 3, "right_col": 12, "right_full": true,
		"lead": "head", "order": {"head": [3], "left": [2], "right": [1, 3]}},
	"mage": {"map": "figure", "head_rows": 5, "left_col": -1, "right_col": 13, "right_full": true,
		"lead": "head", "order": {"head": [2, 3, 0, 1], "right": [3, 2, 0, 1]}},
	"frost": {"map": "figure", "head_rows": 5, "left_col": 1, "right_col": 13, "right_full": true,
		"lead": "head", "order": {"head": [3, 0, 2, 1], "left": [3, 1], "right": [2, 3, 0, 1]}},
	"martial": {"map": "figure", "head_rows": 6, "left_col": -1, "right_col": 16, "right_full": false,
		"lead": "head", "order": {"head": [3, 0, 1, 2]}, "head_rows_by_body": {2: 7}},
	"healer": {"map": "figure", "head_rows": 6, "left_col": 1, "right_col": 13, "right_full": true,
		"lead": "head", "order": {"head": [0, 3, 2, 1], "left": [3], "right": [2, 0, 1, 3]}},
	"bard": {"map": "figure", "head_rows": 4, "left_col": -1, "right_col": 10, "right_full": false,
		"lead": "head", "order": {"head": [1, 0, 3, 2], "right": [2, 3, 0, 1]}},
	"alchemist": {"map": "figure", "head_rows": 6, "left_col": -1, "right_col": 12, "right_full": false,
		"lead": "head", "order": {"head": [0, 2, 3, 1], "right": [2, 0, 3, 1]}},
	"tower": {"map": "top", "head_rows": 6, "lead": "head", "order": {"head": [1, 0, 3, 2]}},
	"magetower": {"map": "top", "head_rows": 5, "lead": "head", "order": {"head": [1, 2, 0, 3]}},
	"frosttower": {"map": "top", "head_rows": 5, "lead": "head", "order": {"head": [2, 0, 1, 3]}},
	"medbay": {"map": "top", "head_rows": 10, "lead": "head", "order": {"head": [3, 2, 1, 0]}},
	"statue": {"map": "top", "head_rows": 11, "lead": "head", "order": {"head": [0, 1, 2, 3]}},
	"mine": {"map": "sides", "split": 7, "lead": "left", "order": {"left": [0, 1, 2, 3]}},
	"cannon": {"map": "sides", "split": 6, "lead": "right", "order": {"right": [0, 2, 3, 1]}},
}
const COMBO_SYMBOLS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijlmnopqrstuvwxyz"
static var _generated := {}


## The sprite for a unit with paths a and b (a < b) both at tier 3: a hand-drawn one
## if there is one, else made up from the two outfits. "" if the unit has no combos.
static func combo(kind: String, a: int, b: int) -> String:
	var sprite_name := "%s_p%dp%d" % [kind, a, b]
	if SPRITES.has(sprite_name) or _generated.has(sprite_name):
		return sprite_name
	if not COMBOS.has(kind):
		return ""
	_generated[sprite_name] = _build_combo(kind, a, b)
	return sprite_name


## Paths of a combined sprite that ended up showing nothing of their own (their
## parts look just like the plain unit), so the unit wears their accent instead.
static func combo_silent(sprite: String) -> Array:
	return _entry(sprite).get("silent", []) if (SPRITES.has(sprite) or _generated.has(sprite)) else []


## Which path a combined sprite took a part ("head", "body", "left", "right") from, or -1.
static func combo_source(sprite: String, part: String) -> int:
	if not _generated.has(sprite):
		return -1
	return _generated[sprite]["src"].get(part, -1)


static func _outfit_of(kind: String, p: int) -> String:
	var v := "%s_p%d" % [kind, p]
	return v if SPRITES.has(v) else kind


static func _combo_part(spec: Dictionary, x: int, y: int, head_rows: int) -> String:
	match spec["map"]:
		"top":
			return "head" if y <= head_rows else "body"
		"sides":
			return "left" if x <= spec["split"] else "right"
	var right: bool = x >= spec["right_col"] and (spec["right_full"] or y > head_rows)
	if right:
		return "right"
	if y <= head_rows:
		return "head"
	return "left" if x <= spec["left_col"] else "body"


static func _build_combo(kind: String, a: int, b: int) -> Dictionary:
	var spec: Dictionary = COMBOS[kind]
	var order: Dictionary = spec["order"]
	var pair := [a, b]
	var pick := func(part: String, fallback: int) -> int:
		for p in order.get(part, []):
			if pair.has(p):
				return p
		return fallback
	var src := {}
	var lead: String = spec["lead"]
	src[lead] = pick.call(lead, b)
	var other: int = a if src[lead] == b else b
	for part in ["head", "body", "left", "right"]:
		if part != lead:
			src[part] = pick.call(part, other) if order.has(part) else other
	var head_rows: int = spec.get("head_rows", 0)
	head_rows = spec.get("head_rows_by_body", {}).get(src["body"], head_rows)
	# Rename every color letter so the two outfits' palettes can't clash.
	var palette := {}
	var from := {}
	var symbol := {}   # "outfit|letter" -> new letter
	var outfits := {a: _outfit_of(kind, a), b: _outfit_of(kind, b)}
	var unify := func(outfit: String, rows: Array) -> Array:
		var pal := _palette(outfit)
		var out := []
		for row in rows:
			var r: String = row
			for x in r.length():
				var ch := r[x]
				if ch == "." or ch == "k" or ch == "_":
					continue
				var key: String = outfit + "|" + ch
				if not symbol.has(key):
					var sym := COMBO_SYMBOLS[symbol.size()]
					symbol[key] = sym
					palette[sym] = pal.get(ch, COMMON.get(ch, Color.MAGENTA))
					from[sym] = ch
				r[x] = symbol[key]
			out.append(r)
		return out
	var merge := func(by_path: Dictionary) -> Array:
		var width := SIZE
		for p in by_path:
			for row in by_path[p]:
				width = maxi(width, (row as String).length())
		var out := []
		for y in SIZE:
			var r := ""
			for x in width:
				var row: String = by_path[src[_combo_part(spec, x, y, head_rows)]][y]
				r += row[x] if x < row.length() else "."
			out.append(r)
		return out
	var rows: Array = merge.call({a: unify.call(outfits[a], _entry(outfits[a])["rows"]), b: unify.call(outfits[b], _entry(outfits[b])["rows"])})
	var alt: Array = merge.call({a: unify.call(outfits[a], _alt_rows(outfits[a])), b: unify.call(outfits[b], _alt_rows(outfits[b]))})
	var names := {}
	for o in [outfits[a], outfits[b]]:
		for n in (_entry(o).get("poses", {}) as Dictionary).keys():
			names[n] = true
		var base: String = _entry(o).get("base", "")
		if base != "":
			for n in (SPRITES[base].get("poses", {}) as Dictionary).keys():
				names[n] = true
	var full_poses := {}
	for n in names:
		var by_path := {}
		for p in pair:
			var posed = _posed_rows(outfits[p], n)
			by_path[p] = unify.call(outfits[p], posed if posed != null else _entry(outfits[p])["rows"])
		full_poses[n] = merge.call(by_path)
	# A path whose parts look the same as the plain unit's adds its accent instead.
	var silent := []
	var plain := _palette(kind)
	var plain_rows: Array = SPRITES[kind]["rows"]
	for p in pair:
		var own: Array = _entry(outfits[p])["rows"]
		var pal := _palette(outfits[p])
		var shows := false
		for y in SIZE:
			var r: String = own[y]
			for x in r.length():
				if src[_combo_part(spec, x, y, head_rows)] != p:
					continue
				var base_row: String = plain_rows[y]
				var mine := r[x]
				var theirs := base_row[x] if x < base_row.length() else "."
				var c1 = null if mine == "." else (Color.BLACK if mine == "k" else pal.get(mine, COMMON.get(mine)))
				var c2 = null if theirs == "." else (Color.BLACK if theirs == "k" else plain.get(theirs, COMMON.get(theirs)))
				if c1 != c2:
					shows = true
					break
			if shows:
				break
		if not shows:
			silent.append(p)
	return {"rows": rows, "alt": alt, "palette": palette, "from": from, "full_poses": full_poses, "silent": silent, "src": src}


## Accent colors added to a palette.
static func _layer_palette(palette: Dictionary, layers: Array) -> Dictionary:
	for l in layers:
		palette = palette.merged(l["palette"], true)
	return palette


## Lays accents on a sprite's rows: "behind" pixels only fill empty space, "over"
## pixels paint over whatever is there (see _overlay).
static func _layered(rows: Array, layers: Array) -> Array:
	for l in layers:
		if l.has("behind"):
			rows = _behind(rows, l["behind"])
		if l.has("over"):
			rows = _overlay(rows, l["over"])
	return rows


static func _behind(rows: Array, changes: Dictionary) -> Array:
	var out := []
	for y in rows.size():
		var row: String = rows[y]
		if changes.has(y):
			var c: String = changes[y]
			while row.length() < c.length():
				row += "."
			for x in c.length():
				if c[x] != "." and row[x] == ".":
					row[x] = c[x]
		out.append(row)
	return out


## Paints a pose over a sprite's rows. A pose maps row index to a row of changes:
## "." keeps the pixel, "_" erases it, anything else paints. Rows can run past 16
## to reach out to the right (sword thrusts, punches).
static func _overlay(rows: Array, changes: Dictionary) -> Array:
	var out := []
	for y in SIZE:
		var row: String = rows[y]
		if changes.has(y):
			var c: String = changes[y]
			while row.length() < c.length():
				row += "."
			for x in c.length():
				if c[x] == "_":
					row[x] = "."
				elif c[x] != ".":
					row[x] = c[x]
		out.append(row)
	return out


static func _make(rows: Array, palette: Dictionary) -> ImageTexture:
	var width := SIZE
	for row in rows:
		width = maxi(width, (row as String).length())
	var img := Image.create(width, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var col: Color = OUTLINE
			if ch != "k":
				col = palette.get(ch, COMMON.get(ch, Color.MAGENTA))
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## 16x16 ground tile. Variants 0-2 are plain grass, 3 has flowers, 4 is dirt.
static func ground_tile(variant: int) -> ImageTexture:
	var key := "ground%d" % variant
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (variant + 1)
	var base := Color(0.4, 0.3, 0.2) if variant == 4 else Color(0.25, 0.47, 0.22)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(base)
	for i in 22:
		var c := base.darkened(0.15) if rng.randf() < 0.6 else base.lightened(0.1)
		img.set_pixel(rng.randi() % SIZE, rng.randi() % SIZE, c)
	if variant != 4:
		# Grass tufts.
		for i in 3:
			var x := rng.randi_range(1, SIZE - 3)
			var y := rng.randi_range(2, SIZE - 1)
			var tuft := base.lightened(0.18)
			img.set_pixel(x, y, tuft)
			img.set_pixel(x + 1, y - 1, tuft)
			img.set_pixel(x + 2, y, tuft)
	else:
		# Pebbles.
		for i in 3:
			img.set_pixel(rng.randi() % SIZE, rng.randi() % SIZE, Color(0.55, 0.5, 0.45))
	if variant == 3:
		for i in 2:
			var x := rng.randi_range(2, SIZE - 3)
			var y := rng.randi_range(2, SIZE - 3)
			var petal := Color(1, 0.95, 0.6) if i == 0 else Color(0.95, 0.6, 0.8)
			for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				img.set_pixelv(Vector2i(x, y) + d, petal)
			img.set_pixel(x, y, Color(1, 0.75, 0.2))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
