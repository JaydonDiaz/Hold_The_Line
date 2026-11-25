extends RefCounted
## Orders: target priority, commitment, calls for help, movement zones and area presets.
## Part of the game controller: `main` is main.gd, which holds the battle's state.

const Main = preload("res://scripts/main.gd")
const Warrior = preload("res://scripts/troops/warrior.gd")

var main: Main

var help_calls := {}      # troop calling for help (in danger) -> seconds the call lasts if it isn't renewed
const CALL_LINGER := 1.2
## Ready-made Guard Areas, as shares of the ground troops stand on (across the field, and
## from the top of it down to the castle): the front half, either flank (with a little of
## the middle), the middle (overlapping both flanks a little) and the back half.
const AREA_PRESETS := {
	"front": Rect2(0.0, 0.0, 1.0, 0.5),
	"left": Rect2(0.0, 0.0, 0.45, 1.0),
	"center": Rect2(0.28, 0.0, 0.44, 1.0),
	"right": Rect2(0.55, 0.0, 0.45, 1.0),
	"back": Rect2(0.0, 0.5, 1.0, 0.5),
}


func _init(m: Main) -> void:
	main = m


# --- Orders: priority, commitment, movement zone ----------------------------------------

## The units an order goes to: the selected unit, or every troop in the group. (Barricades
## take no orders.)
func order_units() -> Array:
	var out := main.group.duplicate() if main.selected == null else [main.selected]
	return out.filter(func(w): return is_instance_valid(w) and w is Warrior)


## Gives `units` an order: "priority", "commit", "move_mode", "area" (a Guard Area drawn on
## the field: they go on Guard Area there), "danger_mode", "call_help" (true/false) or
## "answer". Emplacements, wall guards and Healers skip what doesn't apply to them.
## Remembered per kind for the next hire; kept through waves and upgrades.
func give_order(field: String, value, units: Array = []) -> void:
	if units.is_empty():
		units = order_units()
	for w in units:
		match field:
			"priority":
				if not Warrior.known_priorities(w).has(value):
					continue   # (a Healer takes its own; the rest, target priorities)
				if w.is_mobile_healer():
					if value == "stay":
						continue   # (who to stay with: see below)
					w.stop_staying()
				elif not w.uses_targeting():
					continue
				w.priority = value
				w.target = null
				w.retarget_timer = 0.0
				main.last_priority[w.kind] = value
			"commit":
				if not w.uses_targeting():
					continue
				w.commit = value
			"move_mode":
				if w.is_emplacement() or w.wall_guard:
					continue
				w.move_mode = value
			"area":
				if w.is_emplacement() or w.wall_guard:
					continue
				w.guard_area = value
				w.move_mode = "guard"
			"danger_mode":
				if w.is_emplacement() or w.wall_guard:
					continue
				w.danger_mode = value
				if value == "fight":
					w.retreating = false
			"call_help":
				w.call_help = value
			"answer":
				if w.is_emplacement() or w.wall_guard or w.is_mobile_healer():
					continue   # (a Healer answers by its focus: In danger)
				w.answer = value
		if field != "priority":
			main.last_orders[w.kind] = {"commit": w.commit, "move_mode": w.move_mode, "guard_area": w.guard_area,
					"danger_mode": w.danger_mode, "call_help": w.call_help, "answer": w.answer}
	if field == "priority" and value == "stay":
		# Healers stay with the troops given the order with them; on their own, they wait
		# for a click on the troop (or right-click one).
		var healers := units.filter(func(w): return w.is_mobile_healer())
		var others := units.filter(func(w): return not w.is_mobile_healer() and w.kind != "barricade")
		if healers.is_empty():
			return
		if others.is_empty():
			main.ward_pick = healers
			main.hud.show_message("Click the troop for the Healer to stay with (Esc: cancel)")
		else:
			stay_with(healers, others)


## A troop in danger calls for help (renewed each frame it's still in danger; a call
## lingers a moment after). Others answer by their orders (Warrior._update_answer).
func call_for_help(w) -> void:
	if not help_calls.has(w):
		main.effects.spawn_text(w.position + Vector2(0, -52), "Help!", Color(1.0, 0.45, 0.35))
	help_calls[w] = CALL_LINGER


## Whether `w` is calling for help.
func calling(w) -> bool:
	return help_calls.has(w)


## Everyone calling for help right now.
func callers() -> Array:
	return help_calls.keys()


func _update_calls(delta: float) -> void:
	for w in help_calls.keys():
		help_calls[w] -= delta
		if help_calls[w] <= 0.0 or not is_instance_valid(w) or w.is_queued_for_deletion() or not w.is_active():
			help_calls.erase(w)


## D (or the orders panel): the next drag on the field draws a Guard Area for the selected
## troop or the group (any size, anywhere); Esc cancels.
func start_area_pick(units: Array = []) -> void:
	if units.is_empty():
		units = order_units()
	units = units.filter(func(w): return not w.is_emplacement() and not w.wall_guard and w.kind != "barricade")
	if units.is_empty():
		return
	main.area_pick = units
	main.area_start = null
	main.hud.show_message("Drag out an area to guard (Esc: cancel)")


## A ready-made Guard Area (see AREA_PRESETS) on this battlefield.
func area_preset(key: String) -> Rect2:
	var k: Rect2 = AREA_PRESETS[key]
	var top := float(main.DEPLOY_TOP)
	var depth := float(Main.CASTLE_Y) - top
	return Rect2(k.position.x * main.FIELD_W, top + k.position.y * depth, k.size.x * main.FIELD_W, k.size.y * depth)


## The preset `r` matches, or "" (one drawn by hand).
func area_preset_of(r: Rect2) -> String:
	for key in AREA_PRESETS:
		if area_preset(key).is_equal_approx(r):
			return key
	return ""


## The area being drawn, in field coordinates (while the button's held).
func area_box() -> Rect2:
	if main.area_start == null:
		return Rect2()
	var a: Vector2 = main.area_start
	var b := Vector2(clampf(main.mouse.x, 0.0, main.FIELD_W), clampf(main.mouse.y, 0.0, Main.FIELD_H))
	return Rect2(a.min(b), (b - a).abs())


func _finish_area() -> void:
	var r := area_box()
	main.area_start = null
	if r.size.x < Warrior.MIN_AREA and r.size.y < Warrior.MIN_AREA:
		return   # a click, not a drag: still waiting for the area
	var units := main.area_pick.filter(func(w): return is_instance_valid(w))
	main.area_pick = []
	give_order("area", r, units)
	if not units.is_empty():
		main.effects.spawn_text(r.get_center(), "Guarding here", Color(0.7, 0.95, 1.0))
	main.hud.refresh(main)


## `healers` keep with `troops` (a troop, or a group) and look after them first.
func stay_with(healers: Array, troops: Array) -> void:
	main.ward_pick = []
	for h in healers:
		h.stay_with(troops)
	if not healers.is_empty() and not troops.is_empty():
		main.effects.spawn_text(healers[0].position + Vector2(0, -50), "Staying with the %s" % (troops[0].label.to_lower() if troops.size() == 1 else "group"), Color(0.6, 1.0, 0.6))


## M: the next movement mode for the selection (Hold, Guard Area, Free Roam).
func cycle_move_mode() -> void:
	var units := order_units().filter(func(w): return not w.is_emplacement() and not w.wall_guard)
	if units.is_empty():
		return
	var modes := Warrior.MOVE_MODES
	var next: String = modes[(modes.find(units[0].move_mode) + 1) % modes.size()]
	give_order("move_mode", next, units)
	main.effects.spawn_text(units[0].position + Vector2(0, -50), Warrior.MOVE_NAMES[next], Color(0.7, 0.95, 1.0))
