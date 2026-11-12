extends Node
## The Free Cities' business (Phase 4): contracts and sellswords, both optional.
##
## A contract ("contract" in the mission data) is offered before the first wave is out:
## sign it (U, or its button) and its bond is paid then and there; every wave after that
## held to its terms pays out; break the terms once and the contract is void (the bond's
## gone). Terms:
##   "objective"  the objective "obj" takes no damage
##   "none_lost"  no villager is caught (an evacuation)
##   "no_breach"  nobody gets past your lines (Hold the Pass, a Fighting Retreat), or
##                into the castle
##   "no_fallen"  none of your troops falls
## Mission data: "contract": {"name", "from", "bond", "pay", "terms", "obj", "desc"}
##
## Sellswords ("mercs"): a squad on loan for this battle, bought any time (H, or its
## button) at most "max" times, turning up at the camp: {"cost", "max", "squad":
## [{"kind", "tiers"}], "name"}. They don't need their kind unlocked, so they can stand in
## for what your alliance lacks (a mine-less army's gold goes a long way here).

var main
var contract := {}
var mercs := {}
var state := ""          # "" (none), "offered", "signed", "void", "closed" (offer gone unsigned)
var paid_waves := 0      # waves paid out
var earned := 0
var _wave := 0           # the wave being held to terms (0: none yet)
var _held := true        # this wave's terms kept so far
var _last := 0.0         # the measure the terms watch, last frame
var hired := 0           # squads bought
var note_t := 0.0        # seconds left showing the last change (signed, paid, broken)
var note := ""


func setup(m, mission: Dictionary) -> void:
	main = m
	contract = mission.get("contract", {})
	mercs = mission.get("mercs", {})
	state = "offered" if not contract.is_empty() else ""
	paid_waves = 0
	earned = 0
	_wave = 0
	_held = true
	hired = 0
	note = ""
	note_t = 0.0


func active() -> bool:
	return not contract.is_empty() or not mercs.is_empty()


## The measure a contract's terms watch (worse = higher): damage taken, villagers caught,
## enemies through, troops fallen.
func _measure() -> float:
	match contract.get("terms", ""):
		"objective":
			for o in main.rules.objectives():
				if is_instance_valid(o) and o.id == contract.get("obj", ""):
					return o.max_hp - o.hp if not o.dead else 1e9
			return 0.0
		"none_lost":
			return float(main.rules.get("lost")) if main.rules.get("lost") != null else 0.0
		"no_breach":
			if main.rules.has_castle():
				return main.castle_max - main.castle_hp
			return float(main.rules.get("through")) if main.rules.get("through") != null else 0.0
		"no_fallen":
			return float(main.get_warriors().filter(func(w): return not w.is_emplacement() and not w.is_active()).size())
	return 0.0


# --- The contract ----------------------------------------------------------------------------

## Whether it can be signed now: offered, the first wave not over, the bond to hand.
func can_sign() -> bool:
	return state == "offered" and main.wave <= 1 and main.gold >= int(contract.get("bond", 0))


func sign() -> bool:
	if not can_sign():
		if state == "offered" and main.gold < int(contract.get("bond", 0)):
			main.hud.show_message("The bond is %dg: not enough gold" % int(contract.get("bond", 0)))
		return false
	main.gold -= int(contract.get("bond", 0))
	state = "signed"
	_wave = maxi(main.wave, 1) if main.wave_active else main.wave + 1
	_held = true
	_last = _measure()
	_say("Contract signed: %dg for every wave held" % int(contract.get("pay", 0)))
	main.sfx("coin")
	return true


func _break() -> void:
	state = "void"
	_say("Contract broken! %s" % contract.get("broken", "The bond is lost."))
	main.sfx("hit")


func _say(text: String) -> void:
	note = text
	note_t = 4.0
	main.hud.show_message(text)


# --- Sellswords -------------------------------------------------------------------------------

func can_hire() -> bool:
	return not mercs.is_empty() and hired < int(mercs.get("max", 1)) and main.gold >= int(mercs.get("cost", 0)) \
			and main.started and not main.game_over


func hire() -> bool:
	if not can_hire():
		if not mercs.is_empty() and hired < int(mercs.get("max", 1)) and main.gold < int(mercs.get("cost", 0)):
			main.hud.show_message("Sellswords cost %dg: not enough gold" % int(mercs.get("cost", 0)))
		return false
	main.gold -= int(mercs.get("cost", 0))
	hired += 1
	var squad: Array = mercs.get("squad", [])
	for i in squad.size():
		var a: Dictionary = (squad[i] as Dictionary).duplicate()
		var x := 320.0 + (i - (squad.size() - 1) / 2.0) * 46.0 + (hired - 1) * 18.0
		a["at"] = main.paths.open_spot(Vector2(x, 650.0))
		main._lend_unit(a)
	main.warriors_changed()
	_say("%s hired: %d more for this battle" % [mercs.get("name", "Sellswords"), squad.size()])
	main.sfx("coin")
	return true


# --- Each frame -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if main == null or contract.is_empty() or main.game_over:
		return
	note_t = maxf(note_t - delta, 0.0)
	if state == "offered" and main.wave > 1:
		state = "closed"   # (the offer was for the start of the battle)
		return
	if state != "signed":
		return
	var now := _measure()
	if now > _last + 0.01 and main.wave >= _wave:
		_held = false
		_break()
		return
	_last = now
	# A new wave out: the one before it was held, and it's paid for.
	if main.wave > _wave:
		_pay()
		_wave = main.wave


func _pay() -> void:
	if not _held:
		return
	var pay := int(contract.get("pay", 0))
	main.gold += pay
	earned += pay
	paid_waves += 1
	_say("%s: +%dg, a wave held" % [contract.get("from", "The contract"), pay])


## The battle's won: the last wave's pay (it was held to the end).
func on_win() -> void:
	if state == "signed":
		_pay()


# --- The HUD's buttons ------------------------------------------------------------------------

func contract_label() -> String:
	match state:
		"offered":
			return "Sign: %s  (bond %dg) [U]" % [contract.get("name", "Contract"), int(contract.get("bond", 0))]
		"signed":
			return "%s: %dg a wave  ·  %dg so far" % [contract.get("name", "Contract"), int(contract.get("pay", 0)), earned]
		"void":
			return "%s: broken" % contract.get("name", "Contract") if note_t > 0.0 else ""
	return ""


func contract_tip() -> String:
	if contract.is_empty():
		return ""
	return "%s\n%s\nBond %dg, paid when you sign (before the first wave is over). %dg for every wave held to the terms; break them once and the contract is void." \
			% [contract.get("from", ""), contract.get("desc", ""), int(contract.get("bond", 0)), int(contract.get("pay", 0))]


func merc_label() -> String:
	if mercs.is_empty() or hired >= int(mercs.get("max", 1)) or not main.started or main.game_over:
		return ""
	return "Hire %s: %dg [H]" % [mercs.get("name", "Sellswords"), int(mercs.get("cost", 0))]


func merc_tip() -> String:
	if mercs.is_empty():
		return ""
	var kinds := []
	for a in mercs.get("squad", []):
		kinds.append(Data.WARRIORS[a["kind"]]["name"])
	return "%s for this battle only (%d left to hire): %s, already trained, waiting at the camp." \
			% [mercs.get("name", "Sellswords"), int(mercs.get("max", 1)) - hired, ", ".join(kinds)]


const Data = preload("res://scripts/data.gd")
