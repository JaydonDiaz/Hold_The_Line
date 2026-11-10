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
	"positions": {"name": "Multiple Positions", "blurb": "Defend several\npositions at once\nLose too many\nand it's over",
		"color": Color(0.95, 0.75, 0.45), "look": "engineer"},
	"pass": {"name": "Hold the Pass", "blurb": "No castle: stop\nthem getting past\nyour lines", "color": Color(0.7, 0.85, 1.0), "look": "swordsman"},
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
}


## The scenarios of battle type `t`, in order.
static func of_type(t: String) -> Array:
	return SCENARIOS.keys().filter(func(k): return SCENARIOS[k]["type"] == t)


static func get_scenario(id: String) -> Dictionary:
	return SCENARIOS.get(id, {})
