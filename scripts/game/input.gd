extends RefCounted
## Input: what a click, tap, drag or key does on the field.
## Part of the game controller: `main` is main.gd, which holds the battle's state.

const Main = preload("res://scripts/main.gd")
const Data = preload("res://scripts/data/data.gd")
const Warrior = preload("res://scripts/troops/warrior.gd")
const Barricade = preload("res://scripts/troops/barricade.gd")

var main: Main

const TOUCH_PICK := 34.0   # how near a tap has to be to a troop to pick it (a fingertip is wider than a cursor)


func _init(m: Main) -> void:
	main = m


# --- Input ---------------------------------------------------------------

## A press on the field at p: a left or right click (button), with Shift held or not,
## or a tap on a touchscreen (touch). On a touchscreen there's no right-click, so in a
## wave a tap on open ground with troops selected sends them there (what right-click
## does), and a tap on the selected troop lets it go.
func pointer_down(p: Vector2, button: int, shift := false, touch := false) -> void:
	if main.powers.aiming != "":
		if button == MOUSE_BUTTON_LEFT:
			main.powers.aim_click(p)
		elif button == MOUSE_BUTTON_RIGHT:
			main.powers.aiming = ""
		return
	if main.bells.active() and button == MOUSE_BUTTON_LEFT and main.placing_type == "" and main.bells.click(p):
		return   # a temple bell, rung
	if button == MOUSE_BUTTON_LEFT and main.placing_type == "" and main.rules.click(p):
		return   # the battle's own (a way on's arrow, in the castle)
	if not main.area_pick.is_empty():
		# Drawing a Guard Area: left-drag it out; right-click cancels.
		if button == MOUSE_BUTTON_LEFT:
			main.area_start = p
		else:
			main.area_pick = []
			main.area_start = null
		return
	if not main.ward_pick.is_empty():
		# Healers waiting to be told who to stay with: that troop (anything else cancels).
		var ward := main.formation_ctl._warrior_at(p, TOUCH_PICK if touch else Warrior.RADIUS + 6.0)
		var healers := main.ward_pick.filter(func(h): return is_instance_valid(h))
		main.ward_pick = []
		if ward != null and not healers.has(ward) and ward.kind != "barricade":
			main.orders.stay_with(healers, [ward])
		else:
			main.hud.show_message("No troop there: the Healer keeps to what it was doing")
		return
	if button == MOUSE_BUTTON_RIGHT:
		_order_at(p)
	elif button == MOUSE_BUTTON_LEFT:
		if main.placing_type != "":
			main.hiring.hire_at(p)
			return
		var w := main.formation_ctl._warrior_at(p, TOUCH_PICK if touch else Warrior.RADIUS + 6.0)
		if w is Warrior and w.kind == "tower" and w.crew_in != null and is_instance_valid(w.crew_in) and w.crew_in.garrison == w \
				and main.selected != w.crew_in:
			w = w.crew_in   # a manned Tower: a click picks its crew (click again for the tower itself)
		if touch and main.hiring.fighting() and w != null and w == main.selected and main.group.is_empty():
			main.formation_ctl._cancel()   # a tap on the selected troop: let it go
			return
		if shift and w != null and main.groups._groupable(w):
			main.groups._toggle_in_group(w)   # Shift+click: add or remove one troop
			return
		if w != null and main.group.has(w) and not main.hiring.fighting():
			main.groups._start_group_drag()   # drag the whole group between waves
			return
		if w == null and not main.castle_ctl.on_castle(p) and main.battlefield._grave_at(p) == null:
			# Open field: a click clears the selection, a drag draws a selection box.
			main.box_start = p
			main.box_active = false
			main.box_add = shift
			main.box_touch = touch
			return
		main.group.clear()
		if w != null and w != main.selected and not w is Barricade and w.lift <= 0.0:
			w.land_t = Warrior.LAND_TIME * 0.6   # picked out: a little springy "yes?"
		main.selected = w
		main.selected_grave = main.battlefield._grave_at(p) if main.selected == null else null
		main.castle_selected = main.selected == null and main.selected_grave == null and main.castle_ctl.on_castle(p)
		if main.selected != null and not main.hiring.fighting():
			main.groups._start_drag(main.selected)


## Right-click at p (a tap on open ground, on a touchscreen in a wave): the selected
## troops' orders. Healers alone, on one of your troops: stay with it; on a wagon (or
## civilians): follow it; anywhere else: go there. With nothing selected, it cancels.
func _order_at(p: Vector2) -> void:
	var sel := main.orders.order_units()
	var ally := main.formation_ctl._warrior_at(p)
	if ally != null and not sel.is_empty() and not sel.has(ally) and ally.kind != "barricade" \
			and sel.all(func(w): return w.is_mobile_healer()):
		main.orders.stay_with(sel, [ally])
		return
	var mover = null
	for o in main.rules.followable():
		if o.position.distance_to(p) < o.RADIUS + 10.0:
			mover = o
	if mover != null and (not main.group.is_empty() or main.selected != null):
		main.formation_ctl.set_follow(mover)   # right-click a wagon (or civilians): follow it
	elif not main.group.is_empty():
		main.groups.order_group(p)
	elif main.selected != null:
		main.groups.order_move(p)
	else:
		main.formation_ctl._cancel()


func _key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0:
			# Number keys pick from whichever hire tab is showing (0: the tenth).
			var i: int = 9 if event.keycode == KEY_0 else event.keycode - KEY_1
			if main.castle_selected and main.selected == null:
				if i < Data.CASTLE_PATHS.size():
					main.castle_ctl.castle_upgrade(i)
				return
			match main.hud.hire_tab:
				"abilities":
					if i < Data.ABILITIES.size():
						main.castle_ctl.ability_item(Data.ABILITIES.keys()[i])
					return
				"repair":
					if i < Data.REPAIR_CHUNKS.size():
						main.castle_ctl.repair_castle(i)
					return
			var kinds: Array = main.hud.tab_kinds(main.hud.hire_tab)
			if i < kinds.size():
				main.hiring._on_hire_pressed(kinds[i])
		KEY_TAB:
			var order: Array = main.hud.TABS.map(func(t): return t[0])
			main.formation_ctl.switch_tab(order[(order.find(main.hud.hire_tab) + 1) % order.size()])
		KEY_C:
			main.castle_ctl.select_castle()
		KEY_A:
			if event.ctrl_pressed or event.meta_pressed:
				main.groups.select_all_troops()
			else:
				main.castle_ctl.toggle_auto()
		KEY_V:
			main.formation_ctl.switch_tab("abilities")
		KEY_B:
			main.formation_ctl.switch_tab("repair")
		KEY_Z:
			main.formation_ctl.switch_tab("troops")
		KEY_X:
			main.formation_ctl.switch_tab("emplacements")
		KEY_SPACE:
			main.waves.start_wave()
		KEY_Q:
			main.groups.upgrade_selected(0)
		KEY_W:
			main.groups.upgrade_selected(1)
		KEY_E:
			main.groups.upgrade_selected(2)
		KEY_R:
			main.groups.upgrade_selected(3)
		KEY_S:
			main.formation_ctl.sell_selected()   # (a group: asks first; a grave: buys it back)
		KEY_N:
			main.hiring.cycle_hire_count()
		KEY_T:
			main.groups.cycle_target_priority()
		KEY_M:
			main.orders.cycle_move_mode()
		KEY_Y:
			if main.rules.action_label() != "":
				main.rules.action()
		KEY_J:
			main.formation_ctl.toggle_follow()
		KEY_O:
			main.hud.toggle_orders(main)
		KEY_G:
			main.effects.toggle_song()
		KEY_L:
			main.hiring.climb_down()
		KEY_D:
			main.orders.start_area_pick()
		KEY_K:
			if main.bells.active():
				main.bells.ring_all()
		KEY_U:
			if main.contracts.active():
				main.contracts.sign()
		KEY_H:
			if main.contracts.active():
				main.contracts.hire()
		KEY_F:
			main.modes.cycle_speed()
		KEY_ESCAPE:
			main.formation_ctl._cancel()


## Every pointer event (mouse, or a finger's emulated one) moves `pointer` to where it
## happened, before anything acts on it.
func on_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		main.pointer = main.make_input_local(event).position
		if main.mouse_stand_in == Vector2.INF:
			main.mouse = main.pointer


func on_unhandled_input(event: InputEvent) -> void:
	if main.game_over or not main.started or main.hud.story != null:
		return
	if event is InputEventMouseButton and event.pressed:
		var p: Vector2 = main.make_input_local(event).position
		if p.y > Main.FIELD_H or p.y < 0.0 or p.x < 0.0 or p.x > main.FIELD_W:
			return   # off the field (the panel, or the scenery around a full screen)
		# (A touchscreen's taps come in as left clicks, marked as made up from the touch.)
		pointer_down(p, event.button_index, event.shift_pressed, event.device == InputEvent.DEVICE_ID_EMULATION)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if main.area_start != null:
			main.orders._finish_area()
		elif main.box_start != null:
			main.groups._finish_box()
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event)
