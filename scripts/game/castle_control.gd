extends RefCounted
## The castle in battle: damage and alarms, the Castle tab's upgrades and abilities, repairs
## and the Engineers sent to do them.
## Part of the game controller: `main` is main.gd, which holds the battle's state.

const Main = preload("res://scripts/main.gd")
const Data = preload("res://scripts/data/data.gd")
const Engineer = preload("res://scripts/troops/engineer.gd")
const Castle = preload("res://scripts/castle/castle.gd")

var main: Main

var repair_job := {}           # a repair the Engineers are working on: {"left": health still to come, "rate": per second}   # the castle was clicked: the panel shows its upgrades


func _init(m: Main) -> void:
	main = m


# --- Castle ---------------------------------------------------------------

## An Abilities tab button: buys the ability, or uses it once it's bought.
func ability_item(key: String) -> void:
	if main.game_over or not main.started or main.missions._locked("ability:" + key):
		return
	if main.powers.owned.has(key):
		main.powers.trigger(key)
	elif not main.powers.buy(key):
		main.hud.show_message("Not enough gold")


## A Castle tab card: the next tier of castle path p.
func castle_upgrade(p: int) -> void:
	if main.game_over or not main.started or main.missions._locked("path:%d" % p):
		return
	if not main.powers.upgrade(p) and not main.powers.next_tier(p).is_empty():
		main.hud.show_message("Not enough gold")


## What Repair button i (see Data.REPAIR_CHUNKS) mends now. The full repair, when you
## can't afford it, becomes as much repair as all your gold buys.
func repair_amount(i: int) -> float:
	var amount := minf(roundf(main.castle_max * Data.REPAIR_CHUNKS[i]), main.castle_max - main.castle_hp)
	if Data.REPAIR_CHUNKS[i] >= 1.0 and repair_cost(amount) > main.gold:
		amount = affordable_repair()
	return amount


## Whether the full repair is beyond your gold (so it spends all you have instead).
func repair_all_gold() -> bool:
	return main.castle_max - main.castle_hp >= 1.0 and repair_cost(main.castle_max - main.castle_hp) > main.gold


## The most health (whole points) your gold can mend right now.
func affordable_repair() -> float:
	var lo := 0
	var hi := int(main.castle_max - main.castle_hp)
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if repair_cost(mid) <= main.gold:
			lo = mid
		else:
			hi = mid - 1
	return float(lo)


## What mending `amount` costs: a flat price, its share of max health times
## REPAIR_FULL_COST (whatever the wave or the castle's state), at this difficulty's prices.
func repair_cost(amount: float) -> int:
	if amount <= 0.0:
		return 0
	return main.hiring.price(Data.REPAIR_FULL_COST * amount / main.castle_max)


func can_repair(i: int) -> bool:
	var amount := repair_amount(i)
	return main.missions.allowed("repair") and not main.wave_active and not main.game_over and repair_job.is_empty() and amount >= 1.0 and main.gold >= repair_cost(amount)


func repair_castle(i: int) -> void:
	if main.game_over or not main.started or main.missions._locked("repair"):
		return
	if main.wave_active:
		main.hud.show_message("Repairs wait until the wave is over")
		return
	var amount := repair_amount(i)
	if amount < 1.0:
		return
	if main.gold < repair_cost(amount):
		main.hud.show_message("Not enough gold")
		return
	if not repair_job.is_empty():
		main.hud.show_message("The Engineers are still at work")
		return
	main.gold -= repair_cost(amount)
	# Engineers come out to three stretches of the wall; the health comes back while
	# they work (see repair_tick).
	var share := amount / main.castle_max
	var seconds: float = Data.REPAIR_TIME[0] + Data.REPAIR_TIME[1] * share
	repair_job = {"left": amount, "rate": amount / seconds, "total": amount}
	for f in [0.25, 0.5, 0.75]:
		send_engineer("repair", null, Vector2(main.FIELD_W * f + (0.0 if f != 0.5 else 70.0), Main.CASTLE_Y - 10.0))
	main.effects.sfx("place")


## Sends an Engineer out of the gate: to build `site`, or to repair the wall at `spot`.
func send_engineer(job: String, site, spot: Vector2) -> void:
	var e := Engineer.new()
	e.main = main
	e.job = job
	e.site = site
	e.spot = spot
	e.position = e.gate()
	main.fx_layer.add_child(e)


## A working repair Engineer's share of the repair coming in (three of them at it).
func repair_tick(delta: float) -> void:
	if repair_job.is_empty():
		return
	var bit := minf(repair_job["rate"] / 3.0 * delta, repair_job["left"])
	repair_job["left"] -= bit
	main.castle_hp = minf(main.castle_hp + bit, main.castle_max)
	if repair_job["left"] <= 0.01:
		main.effects.spawn_text(Vector2(main.FIELD_W / 2.0, Main.CASTLE_Y - 60), "+%d castle" % roundi(repair_job["total"]), Color(0.5, 1.0, 0.5))
		repair_job = {}


## The mouse is over the castle with nothing else in the way (for its hover card and outline).
func _castle_hovered() -> bool:
	return main.started and not main.game_over and main.dragging == null and main.placing_type == "" and main.powers.aiming == "" \
			and on_castle(main.mouse) and main.formation_ctl._warrior_at(main.mouse) == null


## Whether p is on the castle (its wall or a tower), for clicking it.
func on_castle(p: Vector2) -> bool:
	if not main.rules.has_castle():
		return false
	if p.y >= Main.CASTLE_Y - 4.0 and p.y <= Main.FIELD_H:
		return true
	for r in main.castle._towers():
		if r.has_point(p):
			return true
	return false


## Selects the castle: the panel shows its upgrade paths.
func select_castle() -> void:
	if main.game_over or not main.started or not main.rules.has_castle():
		return
	main.formation_ctl._cancel()
	main.castle_selected = true


## Auto-play on or off. Turned on between waves, the next one comes after AUTO_DELAY.
func toggle_auto() -> void:
	if main.freeplay or main.game_over:
		return
	if main.forced_auto:
		main.hud.show_message("This battle doesn't wait: the attacks keep coming")
		return
	main.auto_play = not main.auto_play
	main.auto_timer = Main.AUTO_DELAY
	main.hud.show_message("Auto-play on" if main.auto_play else "Auto-play off")
