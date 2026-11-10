extends RefCounted
## Battle Modes: the campaign's kinds of battle, to play on their own like Classic. Each
## scenario is a mission (same keys as campaign_data.gd's MISSIONS, minus the story) with
## every unit, ability and upgrade open, as in Classic. The player picks a difficulty;
## each scenario keeps its own best result per difficulty (records.cfg, section "battle").
##
## "requires_map": a campaign battlefield the scenario is fought on; it's listed but
## locked until the campaign has opened that map (Campaign.open_maps), like the Classic
## battlefield viewer. Scenarios without one are always there to play.

const TYPES := {
	"castle": {"name": "Castle Defense", "blurb": "The classic\nbattle: hold\nthe castle", "color": Color(0.95, 0.85, 0.45), "look": "archer"},
	"positions": {"name": "Multiple Positions", "blurb": "Defend several\npositions at once\nLose too many\nand it's over",
		"color": Color(0.95, 0.75, 0.45), "look": "engineer"},
	"pass": {"name": "Hold the Pass", "blurb": "No castle: stop\nthem getting past\nyour lines", "color": Color(0.7, 0.85, 1.0), "look": "swordsman"},
	"protect": {"name": "Protect the Objective", "blurb": "Keep it standing\nuntil its work\nis done", "color": Color(1.0, 0.8, 0.35), "look": "mage"},
	"evac": {"name": "Evacuation", "blurb": "Get the villagers\nto safety\nNo pauses", "color": Color(0.75, 1.0, 0.55), "look": "healer"},
	"capture": {"name": "Capture and Hold", "blurb": "Take the ground,\nthen hold it\nNo pauses", "color": Color(1.0, 0.6, 0.45), "look": "martial"},
	"escort": {"name": "Convoy Escort", "blurb": "Get the wagon\nthrough the\nambushes", "color": Color(0.9, 0.75, 1.0), "look": "engineer"},
	"retreat": {"name": "Fighting Retreat", "blurb": "Hold, fall back,\nhold again,\nthen get out", "color": Color(0.85, 0.85, 0.85), "look": "frost"},
}

const SCENARIOS := {
	"three_towers": {"name": "The Three Watchtowers", "type": "positions", "map": "", "castle": true,
		"objectives": [{"id": "west", "kind": "watchtower", "name": "West Tower", "at": Vector2(140, 430), "hp": 600},
			{"id": "mid", "kind": "watchtower", "name": "Middle Tower", "at": Vector2(320, 370), "hp": 600},
			{"id": "east", "kind": "watchtower", "name": "East Tower", "at": Vector2(500, 430), "hp": 600}],
		"can_lose": 1, "castle_share": 0.3,
		"waves": 8, "level": 2, "gold": 360, "count": [7, 2],
		"pool": {1: ["goblin", "goblin"], 2: ["orc", "wolf"], 3: ["skeleton_archer"], 4: ["sapper"], 6: ["troll"]},
		"extra": {4: ["orc", "orc"], 6: ["troll"], 8: ["troll", "troll"]},
		"notes": {1: "Keep the watchtowers standing: you can lose one of the three.", 4: "Sappers! Wall off the towers.",
			8: "Trolls lead the last attack!"},
		"allies": [], "lend": []},
	"open_road": {"name": "The Open Road", "type": "pass", "map": "", "limit": 20,
		"waves": 8, "level": 2, "gold": 360, "count": [7, 2],
		"pool": {1: ["goblin", "goblin"], 2: ["wolf"], 3: ["orc", "skeleton_archer"], 5: ["sapper"], 6: ["troll"]},
		"extra": {3: ["wolf", "wolf"], 6: ["troll"], 8: ["troll", "troll", "orc"]},
		"notes": {1: "Hold the road: no more than 20 may get past your camp.", 2: "Wolves run for any gap!",
			8: "Trolls: each counts double if it gets through!"},
		"allies": [], "lend": []},
	"signal_beacon": {"name": "The Signal Beacon", "type": "protect", "map": "",
		"objectives": [{"id": "beacon", "kind": "beacon", "name": "The beacon", "at": Vector2(320, 430), "hp": 900, "charge": 150}],
		"pace": {"auto": "forced", "deploy": 20, "break": 3, "interval": 20},
		"waves": 99, "level": 8, "gold": 420, "count": [12, 4],
		"pool": {1: ["goblin", "goblin"], 2: ["orc", "wolf"], 3: ["skeleton_archer"], 4: ["sapper"], 6: ["troll"]},
		"extra": {5: ["orc", "orc"], 7: ["troll"]},
		"notes": {1: "The beacon is charging: keep everything off it until it's lit."},
		"allies": [], "lend": []},
	"village_road": {"name": "The Village Road", "type": "evac", "map": "",
		"evac": {"routes": [[Vector2(110, 250), Vector2(170, 420), Vector2(270, 580), Vector2(320, 740)],
				[Vector2(530, 250), Vector2(470, 420), Vector2(370, 580), Vector2(320, 740)]],
			"groups": 8, "size": 5, "every": 11.0, "first": 2.0, "hp": 150, "speed": 30.0, "need": 25},
		"pace": {"auto": "forced", "deploy": 18, "break": 3, "interval": 15},
		"waves": 99, "level": 9, "gold": 420, "count": [12, 4],
		"pool": {1: ["goblin", "wolf", "wolf"], 2: ["orc"], 3: ["skeleton_archer"], 4: ["troll"]},
		"notes": {1: "Villagers are leaving by both roads. Keep the raiders off them!"},
		"allies": [], "lend": []},
	"old_fort": {"name": "The Old Fort", "type": "capture", "map": "",
		"capture": {"at": Vector2(320, 290), "radius": 80.0, "name": "the old fort", "time": 20.0, "hold": 60.0, "limit": 220.0},
		"pace": {"auto": "forced", "deploy": 15, "break": 3, "interval": 16},
		"waves": 99, "level": 9, "gold": 450, "count": [14, 4],
		"pool": {1: ["goblin", "goblin", "orc"], 2: ["wolf"], 3: ["skeleton_archer"], 5: ["troll"]},
		"notes": {1: "Take the old fort: get your troops into it and drive them out."},
		"allies": [], "lend": []},
	"supply_wagon": {"name": "The Supply Wagon", "type": "escort", "map": "",
		"convoy": {"name": "Wagon", "route": [Vector2(70, 700), Vector2(170, 560), Vector2(320, 480), Vector2(470, 360),
				Vector2(540, 220), Vector2(590, 110)], "speed": 20.0, "hp": 1100,
			"ambushes": [
				{"at": 0.2, "note": "Ambush on the road!", "group": [["orc", Vector2(380, 430)], ["orc", Vector2(400, 470)], ["orc", Vector2(420, 450)], ["goblin", Vector2(90, 420)], ["goblin", Vector2(110, 440)], ["wolf", Vector2(70, 470)]]},
				{"at": 0.5, "note": "Wolves from the woods!", "group": [["wolf", Vector2(620, 380)], ["wolf", Vector2(620, 420)], ["wolf", Vector2(40, 330)], ["wolf", Vector2(40, 370)], ["skeleton_archer", Vector2(560, 300)], ["troll", Vector2(600, 330)]]},
				{"at": 0.75, "note": "Trolls block the road ahead!", "group": [["troll", Vector2(560, 140)], ["troll", Vector2(500, 120)], ["orc", Vector2(500, 160)], ["orc", Vector2(610, 250)], ["skeleton_archer", Vector2(620, 160)]]}]},
		"pace": {"auto": "forced", "deploy": 18, "break": 3, "interval": 16},
		"waves": 99, "level": 8, "gold": 450, "count": [10, 3],
		"pool": {1: ["goblin", "goblin"], 2: ["wolf"], 4: ["orc"]},
		"notes": {1: "Get the wagon to the far road. New troops join at the wagon; J or right-click it to follow it."},
		"allies": [], "lend": []},
	"long_retreat": {"name": "The Long Retreat", "type": "retreat", "map": "", "limit": 15, "stream": 1.4,
		"retreat": {"lines": [{"y": 250, "name": "First line", "time": 45}, {"y": 430, "name": "Second line", "time": 45},
				{"y": 600, "name": "Last line", "time": 40}], "extract": {"y": 680, "time": 25, "need": 8}},
		"pace": {"auto": "forced", "deploy": 20, "break": 3, "interval": 22},
		"waves": 99, "level": 5, "gold": 600, "count": [9, 3],
		"pool": {1: ["goblin", "goblin", "orc"], 2: ["wolf"], 3: ["skeleton_archer"], 4: ["troll"]},
		"notes": {1: "Hold the first line, then fall back when the horn sounds [Y]. Get at least 8 troops out."},
		"allies": [], "lend": []},
}


## The scenarios of battle type `t`, in order.
static func of_type(t: String) -> Array:
	return SCENARIOS.keys().filter(func(k): return SCENARIOS[k]["type"] == t)


static func get_scenario(id: String) -> Dictionary:
	return SCENARIOS.get(id, {})
