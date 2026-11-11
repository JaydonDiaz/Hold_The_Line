extends RefCounted
## Battle Modes: the campaign's kinds of battle, to play on their own like Classic. Each
## scenario is a mission (same keys as campaign_data.gd's MISSIONS, minus the story) with
## every unit, ability and upgrade open, as in Classic. The player picks a difficulty;
## each scenario is "endless" (see rules.gd): it goes on until it's lost, and keeps its
## best run (waves survived) per difficulty (records.cfg, section "survive").
##
## "requires_map": a campaign battlefield the scenario is fought on; it's listed but
## locked until the campaign has opened that map (Campaign.open_maps), like the Classic
## battlefield viewer. Scenarios without one are always there to play.

const TYPES := {
	"castle": {"name": "Castle Defense", "blurb": "The classic\nbattle: hold\nthe castle", "color": Color(0.95, 0.85, 0.45), "look": "archer"},
	"positions": {"name": "Multiple Positions", "blurb": "Defend several\npositions at once\nLose too many\nand it's over",
		"color": Color(0.95, 0.75, 0.45), "look": "engineer"},
	"pass": {"name": "Hold the Pass", "blurb": "No castle: stop\nthem getting past\nyour lines", "color": Color(0.7, 0.85, 1.0), "look": "swordsman"},
	"protect": {"name": "Protect the Objective", "blurb": "Keep it standing\nwhile it works,\nagain and again", "color": Color(1.0, 0.8, 0.35), "look": "mage"},
	"evac": {"name": "Evacuation", "blurb": "Get the villagers\nto safety\nNo pauses", "color": Color(0.75, 1.0, 0.55), "look": "healer"},
	"capture": {"name": "Capture and Hold", "blurb": "Take the ground,\nthen hold it\nNo pauses", "color": Color(1.0, 0.6, 0.45), "look": "martial"},
	"escort": {"name": "Convoy Escort", "blurb": "Keep the wagon\nrolling through\nthe ambushes", "color": Color(0.9, 0.75, 1.0), "look": "bard"},
	"retreat": {"name": "Fighting Retreat", "blurb": "Hold, fall back,\nget out, and\nmarch on", "color": Color(0.85, 0.85, 0.85), "look": "frost"},
}

const SCENARIOS := {
	"three_towers": {"name": "The Three Watchtowers", "type": "positions", "map": "", "endless": true,
		"objectives": [{"id": "west", "kind": "watchtower", "name": "West Tower", "at": Vector2(140, 430), "hp": 600},
			{"id": "mid", "kind": "watchtower", "name": "Middle Tower", "at": Vector2(320, 370), "hp": 600},
			{"id": "east", "kind": "watchtower", "name": "East Tower", "at": Vector2(500, 430), "hp": 600}],
		"can_lose": 1, "mend": 0.15,
		"level": 2, "gold": 360, "count": [7, 2],
		"pool": {1: ["goblin", "goblin"], 2: ["orc", "wolf"], 3: ["skeleton_archer"], 4: ["sapper"], 6: ["troll"], 8: ["bat"], 11: ["slime"]},
		"extra": {4: ["orc", "orc"], 6: ["troll"], 8: ["troll", "troll"]},
		"notes": {1: "Keep the watchtowers standing: you can lose one of the three.", 4: "Sappers! Wall off the towers.",
			8: "Trolls are coming for the towers!"},
		"allies": [], "lend": []},
	"open_road": {"name": "The Open Road", "type": "pass", "map": "", "endless": true, "limit": 20,
		"level": 2, "gold": 360, "count": [7, 2],
		"pool": {1: ["goblin", "goblin"], 2: ["wolf"], 3: ["orc", "skeleton_archer"], 5: ["sapper"], 6: ["troll"], 9: ["bat"], 11: ["slime"]},
		"extra": {3: ["wolf", "wolf"], 6: ["troll"], 8: ["troll", "troll", "orc"]},
		"notes": {1: "Hold the road: no more than 20 may get past your camp.", 2: "Wolves run for any gap!",
			8: "Trolls: each counts double if it gets through!"},
		"allies": [], "lend": []},
	"signal_beacon": {"name": "The Signal Beacon", "type": "protect", "map": "", "endless": true,
		"objectives": [{"id": "beacon", "kind": "beacon", "name": "The beacon", "at": Vector2(320, 430), "hp": 1050, "charge": 120}],
		"relight": {"gold": 80, "mend": 0.3, "longer": 1.1},
		"pace": {"auto": "forced", "deploy": 20},
		"level": 6, "gold": 420, "count": [10, 3],
		"pool": {1: ["goblin", "goblin"], 2: ["orc", "wolf"], 3: ["skeleton_archer"], 4: ["sapper"], 6: ["troll"], 9: ["bat"]},
		"extra": {5: ["orc", "orc"], 7: ["troll"]},
		"notes": {1: "The beacon is charging: keep everything off it. Each time it's lit, it burns down and starts again."},
		"allies": [], "lend": []},
	"village_road": {"name": "The Village Road", "type": "evac", "map": "village_fields", "endless": true,
		"evac": {"routes": [[Vector2(110, 250), Vector2(170, 420), Vector2(270, 580), Vector2(320, 740)],
				[Vector2(530, 250), Vector2(470, 420), Vector2(370, 580), Vector2(320, 740)]],
			"size": 5, "every": 11.0, "first": 2.0, "hp": 50, "speed": 30.0, "can_lose": 30},
		"pace": {"auto": "forced", "deploy": 18},
		"level": 5, "gold": 420, "count": [10, 3],
		"pool": {1: ["goblin", "wolf", "wolf"], 2: ["orc"], 3: ["skeleton_archer"], 5: ["troll"], 8: ["bat"]},
		"notes": {1: "Villagers are leaving by both roads, and they'll keep coming. Lose more than 30 and it's over."},
		"allies": [], "lend": []},
	"old_fort": {"name": "The Old Fort", "type": "capture", "map": "", "endless": true,
		"capture": {"at": Vector2(320, 290), "radius": 80.0, "name": "the old fort", "time": 20.0, "hold": 45.0, "limit": 120.0, "retake": 60.0},
		"pace": {"auto": "forced", "deploy": 15},
		"level": 7, "gold": 450, "count": [12, 4],
		"pool": {1: ["goblin", "goblin", "orc"], 2: ["wolf"], 3: ["skeleton_archer"], 5: ["troll"], 8: ["bat"], 10: ["sapper"]},
		"notes": {1: "Take the old fort, then hold it. If they win it back, you've a minute to retake it."},
		"allies": [], "lend": []},
	"supply_wagon": {"name": "The Supply Wagon", "type": "escort", "map": "convoy_meadow", "endless": true,
		"convoy": {"name": "Wagon", "speed": 20.0, "hp": 1800, "patch": 0.5,
			"zones": [
				{"map": "convoy_meadow", "ambushes": [
					{"at": 0.3, "note": "Raiders out of the copses!", "group": [["orc", Vector2(600, 590)], ["goblin", Vector2(580, 615)], ["goblin", Vector2(60, 520)], ["wolf", Vector2(40, 570)]]},
					{"at": 0.7, "note": "Ambush from the rocks!", "group": [["orc", Vector2(500, 290)], ["orc", Vector2(545, 280)], ["skeleton_archer", Vector2(520, 160)], ["goblin", Vector2(130, 330)]]}]},
				{"map": "convoy_forest", "ambushes": [
					{"at": 0.25, "note": "Wolves in the Darkwood!", "group": [["wolf", Vector2(180, 520)], ["wolf", Vector2(190, 560)], ["wolf", Vector2(460, 520)], ["wolf", Vector2(450, 560)], ["skeleton_archer", Vector2(440, 420)]]},
					{"at": 0.65, "note": "They're in the trees!", "group": [["orc", Vector2(200, 300)], ["orc", Vector2(210, 260)], ["orc", Vector2(440, 300)], ["orc", Vector2(430, 260)], ["troll", Vector2(330, 150)]]}]},
				{"map": "convoy_ford", "ambushes": [
					{"at": 0.3, "note": "They're waiting at the ford!", "group": [["orc", Vector2(230, 340)], ["orc", Vector2(410, 340)], ["goblin", Vector2(200, 300)], ["goblin", Vector2(440, 300)], ["skeleton_archer", Vector2(320, 250)]]},
					{"at": 0.75, "note": "Wolves across the river!", "group": [["wolf", Vector2(120, 300)], ["wolf", Vector2(160, 290)], ["wolf", Vector2(480, 300)], ["wolf", Vector2(520, 290)]]}]},
				{"map": "convoy_village", "ambushes": [
					{"at": 0.25, "note": "Out of the ruins!", "group": [["orc", Vector2(240, 520)], ["goblin", Vector2(110, 380)], ["goblin", Vector2(540, 420)], ["skeleton_archer", Vector2(560, 360)]]},
					{"at": 0.6, "note": "They've been hiding in the cottages!", "group": [["orc", Vector2(170, 280)], ["orc", Vector2(470, 220)], ["sapper", Vector2(420, 180)], ["troll", Vector2(320, 140)]]}]},
				{"map": "convoy_fens", "ambushes": [
					{"at": 0.3, "note": "Out of the reeds!", "group": [["goblin", Vector2(240, 470)], ["goblin", Vector2(420, 640)], ["orc", Vector2(250, 420)], ["skeleton_archer", Vector2(230, 360)], ["skeleton_archer", Vector2(600, 440)]]},
					{"at": 0.7, "note": "Trolls in the marsh!", "group": [["troll", Vector2(250, 180)], ["orc", Vector2(400, 300)], ["orc", Vector2(420, 120)], ["wolf", Vector2(600, 300)]]}]},
				{"map": "convoy_ridge", "ambushes": [
					{"at": 0.3, "note": "Down from the boulders!", "group": [["orc", Vector2(170, 520)], ["orc", Vector2(470, 500)], ["skeleton_archer", Vector2(260, 330)], ["goblin", Vector2(470, 350)], ["goblin", Vector2(160, 380)]]},
					{"at": 0.7, "note": "They've blocked the ridge road!", "group": [["troll", Vector2(320, 140)], ["orc", Vector2(260, 160)], ["orc", Vector2(400, 180)], ["skeleton_archer", Vector2(480, 260)]]}]},
				{"map": "convoy_pass", "ambushes": [
					{"at": 0.3, "note": "They're coming down the slopes!", "group": [["orc", Vector2(230, 460)], ["orc", Vector2(410, 460)], ["skeleton_archer", Vector2(230, 330)], ["skeleton_archer", Vector2(420, 330)], ["goblin", Vector2(250, 400)], ["goblin", Vector2(400, 400)]]},
					{"at": 0.7, "note": "Trolls hold the top of the pass!", "group": [["troll", Vector2(320, 110)], ["orc", Vector2(260, 160)], ["orc", Vector2(380, 160)], ["skeleton_archer", Vector2(330, 60)]]}]}]},
		"pace": {"auto": "forced", "deploy": 18},
		"level": 5, "gold": 450, "count": [8, 3],
		"pool": {1: ["goblin", "goblin"], 2: ["wolf"], 4: ["orc"], 7: ["skeleton_archer"], 10: ["bat"]},
		"notes": {1: "Keep the wagon going down the road as long as you can. New troops join at the wagon; J or right-click it to follow it."},
		"allies": [], "lend": []},
	"long_retreat": {"name": "The Long Retreat", "type": "retreat", "map": "", "endless": true, "limit": 15,
		"stream": 1.6, "stream_from": 4,
		"retreat": {"lines": [{"y": 250, "name": "First line", "time": 50}, {"y": 430, "name": "Second line", "time": 45},
				{"y": 600, "name": "Last line", "time": 40}], "extract": {"y": 680, "time": 25, "need": 6},
			"stretches": [{"map": "", "name": "The Meadow"}, {"map": "convoy_forest"}, {"map": "convoy_village"},
				{"map": "convoy_ridge"}, {"map": "convoy_meadow", "name": "The Farmlands"}, {"map": "convoy_pass"}]},
		"pace": {"auto": "forced", "deploy": 25},
		"level": 3, "gold": 450, "count": [3, 3],
		"pool": {1: ["goblin", "goblin", "orc"], 2: ["wolf"], 4: ["skeleton_archer"], 6: ["troll"], 9: ["bat"]},
		"notes": {1: "Hold the first line, then fall back when the horn sounds [Y]. Get at least 6 troops out of the camp to march on.",
			4: "The main army's catching up: stragglers will keep coming now."},
		"allies": [], "lend": []},
}


## The scenarios of battle type `t`, in order.
static func of_type(t: String) -> Array:
	return SCENARIOS.keys().filter(func(k): return SCENARIOS[k]["type"] == t)


static func get_scenario(id: String) -> Dictionary:
	return SCENARIOS.get(id, {})
