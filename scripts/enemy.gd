extends Node2D
## An enemy marching from the top of the screen to the bottom. Fighters stop to
## attack any warrior in their way; non-fighters (wolves) slip around them.
## Barricades are walked around when there's a way past (see pathing.gd); when
## there isn't, everyone hacks at the wall in the way, wolves included.
## Flyers (bats) pass over walls and warriors alike. Fighters turn on a unit that's
## attacking them (one in range of them and not far off, with no wall between) before
## carrying on to the castle, unless they're already at it or nearly there (then they
## keep at the castle whatever hits them). Sappers ignore your troops: they make for the castle,
## and blow themselves up against a wall only if it blocks their way there.
## Skeleton Archers hang back: they stop once a troop (or the castle) is in bow range and
## shoot from there, but only once they're out of their camp (where your troops can't
## go) and, on a battlefield with terrain, only where melee troops can get at them.
## On terrain (campaign maps), every step slides along rock rather than into it; going
## after a unit, an enemy takes a route round anything in the way. Slimes go for your troops before the castle; blades, arrows and
## shells sink into them harmlessly ("physical" damage) unless they're iced over, while
## magic, ki and ice hurt them (ice twice over, and it ices them over). Their blows slow.

signal died(enemy)
signal reached_castle(enemy)

const Sprites = preload("res://scripts/sprites.gd")
const REACH := 6.0
const FLY_HEIGHT := 18.0   # how far above its shadow a flyer is drawn
const FUSE := 0.6          # seconds a Sapper's bomb fizzes before it goes off
const PLANT := 1.6         # ...against one of your emplacements: it has to plant the charge (time to stop it)
const ENRAGE_SPEED := 1.35
const ENRAGE_RATE := 0.7
const AGGRO_LEASH := 260.0   # furthest a fighter turns aside to go after a unit attacking it
const CASTLE_COMMIT := 90.0  # this close to the castle wall, an enemy is set on the castle and won't turn aside
const EnemyShot = preload("res://scripts/enemy_shot.gd")
const EnemyBolt = preload("res://scripts/enemy_bolt.gd")
const BarricadeScript = preload("res://scripts/barricade.gd")
# Damage schools: what a hit is made of. Only Slimes care: they shrug off physical hits
# unless iced over (or frozen); anything else, explosive or magical, hurts them as normal.
const PHYSICAL := "physical"   # blades, fists, arrows, thorns, fire
const MAGIC := "magic"         # arcane orbs, lightning, flame breath, rot, songs, holy light
const KI := "ki"               # a Martial Artist's ki blasts and beam
const ICE := "ice"             # frost bolts, frost auras, the Frost Orb
const ALCHEMY := "alchemy"     # an Alchemist's flasks (splash, acid, blasts), toxic clouds and poison
const EXPLOSIVE := "explosive" # cannon shells and their bomblets, an Alchemist's charges
const ICE_BONUS := 2.0         # ice does this much more to a Slime...
const CRUST_TIME := 2.5        # ...and ices it over for this long: physical hits land, it moves slower
const CRUST_SLOW := 0.4
const SLIME_SEEK := 420.0      # how far a Slime looks for a troop to go after

var kind := ""
var tier := 1      # enemy type rank (data.gd); higher is more dangerous
var main
var max_hp := 1.0
var hp := 1.0
var speed := 50.0
var damage := 0.0
var wall_damage := 0.0
var attack_cd := 1.0
var fights := true
var flying := false         # over walls and warriors; melee and cannon shells can't reach it
var bomb := {}              # Sapper: wall, units, radius of its blast (damage already scaled)
var fuse := -1.0            # >= 0 while the Sapper's bomb is lit
var sap_target = null       # Sapper: the emplacement (or wall) it's making for, to blow up against
var sap_check := 0.0
const SAP_SEEK := 260.0     # how far a Sapper looks for one of your emplacements to go for
var level := 1              # wave level it was spawned at (for anything it summons)
var cc_mult := 1.0          # share of stuns, freezes, roots and confusion that lands
var knock_mult := 1.0       # share of knockback that lands
var boss := false
var stomp := {}             # Ogre King: damage (scaled), radius, cooldown, push, stun
var cleave := {}            # Ogre King: reach, arc of its sweeping blows
var banner := {}            # Ash Marshal: his war banner (radius, damage, speed, break, down)
var banner_down := 0.0      # ...seconds before it's raised again, once knocked down
var banner_tick := 0.0
var recent_hurt := 0.0      # damage taken lately (fading): enough of it knocks the banner down
var rush := {}              # Ash Marshal: his charge (cooldown, min, range, speed, damage, push, stun)
var charge_timer := 6.0
var charging := 0.0         # seconds of charge left
var charge_dir := Vector2.ZERO
var charge_hit := []        # troops already struck by this charge
var rally := 0.0            # seconds left driven on by the Marshal's banner
var rally_dmg := 0.0        # ...its share more damage
var rally_speed := 0.0      # ...and speed
var summon := {}            # Ogre King: kinds, count, cooldown
var horn := {}              # Ogre King: kinds, count, cooldown of the war horn's new wave
var breath := {}            # Wyvern: damage (scaled), radius, range, cooldown
var ranged := {}            # Skeleton Archer: range, speed of its arrows
var gooey := false          # Slime: physical hits sink in harmlessly unless it's iced over
var goo := {}               # Slime: slow, time its blows slow troops by
var ice_crust := 0.0        # Slime: seconds left iced over
var absorb_note := 0.0      # Slime: keeps "Absorbed!" from popping up every frame
var on_ground := false      # walks on a battlefield with terrain (set at spawn; never for flyers)
var chase_route := PackedVector2Array()   # waypoints round the terrain to whatever it's going after
var chase_check := 0.0
var chase_goal := Vector2.INF
var shots := 0               # Skeleton Archer: arrows loosed (the tests look at where from)
var last_shot_from := Vector2.ZERO
var idle_shots := 0         # Skeleton Archer: arrows at troops since it was last hurt itself
var press_on := 0.0         # ...and seconds it's ignoring troops to push on (see PRESS_AFTER)
const PRESS_AFTER := 8      # arrows at troops that can't (or won't) come for it before it pushes on
const PRESS_TIME := 4.0
static var slimes_out := 0  # Slimes on the field, so troops only look out for them when there are any
var breath_timer := 1.0
var horn_timer := 15.0
var enrage_at := 0.0
var hp_floor := 0.0         # > 0: worn down to this, it goes no lower (rules.floor_reached is told, once)
var enraged := false
const STOMP_WARN := 0.9   # seconds a boss's slam shows its ring before it lands
var stomp_wind := 0.0     # > 0 while it's winding up a slam
var boss_hold := 0.0      # > 0: a boss stands where it is (exposed after a charge, say)
var stomp_timer := 3.0
var summon_timer := 5.0
var bounty := 5
var radius := 12.0
var sprite_scale := 2.5
var look := ""              # the sprite it's drawn with (its kind's own, unless its data names another)
var aura := Color(0, 0, 0, 0)   # a glow round it (the Ogre King unbound: the corrupted beacon's fire)
var charge_warn := 0.0      # > 0: a charge about to start (its line shown on the ground)
var exposed := 0.0          # > 0: caught off balance after a charge (rooted, and hit harder)
var embers_timer := 6.0     # the unbound King's burning ground
var flip := 1.0
var turn := 1.0             # the facing it's drawn with: swings over to flip in a quick turn, never snaps
var turn_hold := 0.0        # how long flip has pointed away from turn (a turn starts once it's held a moment)
var life_t := 0.0           # running clock (breathing while it fights)
var color := Color.WHITE
var progress := 0.0   # how far down the screen; warriors use it to judge threat
var dead := false
var cd_timer := 0.0
var slow_factor := 1.0
var slow_timer := 0.0
var freeze_timer := 0.0
var stun_timer := 0.0      # blinded by a flash: can't move or attack
var knock_timer := 0.0
var knock_velocity := Vector2.ZERO
var burn_dps := 0.0
# Bard effects.
var vuln := 0.0             # Discord: takes this much extra damage
var weaken := 0.0           # Discord: deals this much less damage
var discord_slow := 0.0     # Discord: extra slow
var discord_timer := 0.0
var root_timer := 0.0       # Vine Snare: can't move, can still fight
var confuse_timer := 0.0    # Confusion: attacks other enemies instead of marching
var confuse_vuln := 0.0     # Puppet Master: takes this much extra damage while confused
var decay_dps := 0.0        # Necromancy rot
var decay_timer := 0.0
var decay_source := 0       # instance id of the Mage whose rot it is (raises a skeleton if this dies rotting)
var thorn_dps := 0.0        # Thornwild: caught in thorny plants or vines
var thorn_timer := 0.0
var charged_timer := 0.0    # struck by lightning: a Storm mage's blasts pull it in
var burn_timer := 0.0
var burn_credit := ""       # campaign XP: whose fire, poison, rot and thorns these are
var poison_credit := ""
var decay_credit := ""
var thorn_credit := ""
# Alchemist effects.
var poisons := {}           # alchemist id -> [dps per stack, stacks, seconds left]; only the worst one hurts
var poison_stacks := 0      # stacks of the worst poison (for the bubbles)
var corrode := 0.0          # takes this much extra damage
var corrode_timer := 0.0
# Barricades.
var wall_target = null      # the barricade this enemy has set about breaking
var stuck_check := Vector2.ZERO
var stuck_time := 0.0       # how long it has been pressed against a wall
var wall_commit := 0.0      # seconds left hacking at a wall it got stuck on before trying again
var flash := 0.0
var lunge := 0.0
var lunge_dir := Vector2.DOWN
var bob := 0.0
var sieging := false        # reached the castle and attacking it
var walking := false        # moved this frame (for the waddle)
var fighting := false       # swinging at a warrior or wall (for the wind-up)
var drift := 0.0
# The roster's own ways (data.gd: pack, regen, slam, strafe).
var pack := {}              # Goblin, Wolf: bolder with its own kind round it
var pack_n := 0             # ...how many of them are (counted every PACK_EVERY seconds)
var pack_t := randf() * 0.5
const PACK_EVERY := 0.5
var flock_t := randf() * 0.4  # Bat: when it next looks round for the rest of its flock
var flock_pull := Vector2.ZERO
var regen := {}             # Troll: heals once it's been left unhurt a moment
var unhurt := 0.0           # ...seconds since it was last hurt
var mending := false        # ...healing this frame (for the drawing)
var slam := {}              # Ogre, Warlord: blows hauled back (warned on the ground), then swept
var slam_wind := 0.0        # > 0 while one's being hauled back
var strafe := {}            # Wyvern: its strafing run
var strafe_timer := 6.0
var strafe_warn := 0.0      # > 0: its line on the ground, before it swoops
var strafe_left := 0.0      # > 0: swooping down it
var strafe_from := Vector2.ZERO
var strafe_to := Vector2.ZERO
var strafe_hit := {}
var strafe_fx := 0.0
var heading := Vector2.DOWN  # which way it last went (a Shieldbearer's shield faces it)
var shield := {}            # Shieldbearer: front, arc, cover, cover_r
static var shields_out := 0 # Shieldbearers on the field (only then does a shot look for one)
var escort = null           # Shieldbearer: the archer, sapper or caster of its own it walks in front of
var escort_t := 0.0
const ESCORTED := ["sapper", "skeleton_archer", "boltflinger", "drummer", "warmage", "gravebinder"]
var block_note := 0.0
var drum := {}              # War Drummer: its beat
var drum_t := 1.0
var drum_beat := 0.0        # > 0 just after a beat (the sticks come down, the ring goes out)
var drum_ahead := 1         # of its own kinds ahead of it (with none, it hangs back)
var driven := 0.0           # seconds left driven on by a drum
var driven_speed := 0.0
var driven_rate := 0.0
var cast := {}              # Horde Mage: its spells
var cast_state := ""        # "", "charge" (gathering a spell), "flame" (pouring out fire)
var cast_spell := ""        # the spell it's charging ("lightning", "fire", "arcane")
var cast_left := 0.0
var cast_cd := 1.0
var flame_dir := Vector2.DOWN
var flame_left := 0.0
var flame_tick := 0.0
var last_chain := 0         # (for the tests) how many its last lightning struck
var last_arcane = null      # ...and whom its last arcane beam went to
var necro := {}             # Gravebinder
var minions: Array = []     # ...its Skeleton Archers out
var raised: Array = []      # ...and your fallen it's raised
var rite = null             # ...the fallen troop it's raising (a record in main.fallen)
var rite_left := 0.0
var rite_total := 1.0
var necro_t := 0.5
var summon_t := 4.0
var corrupted := false      # one of your fallen, raised by a Gravebinder to fight for the horde
var fallen_kind := ""       # ...the kind it was (its upgrades in fallen_tiers)
var fallen_tiers := []
var frames_override: Array = []   # ...drawn as it looked when it fell
var mend := {}              # a corrupted Healer: amount, every, range
var mend_t := 1.0
var volley := 1             # shots a loose (a corrupted Archer's Volley)
var shot_style := "arrow"   # what its shots look like and do (arrow, orb, frost, flask, note)
var shot_splash := 0.0
var shot_goo := []          # [slow, seconds] a frost shot leaves on a troop
var goal = null             # the objective it's been sent for (mission/objective.gd), or null for the castle / bottom line
var aggro = null            # the unit attacking it that it has turned on
var aggro_check := randf() * 0.3   # staggered, so a crowd doesn't all look around in the same frame
var goal_check := 1.0             # when to ask the rules again for an objective (see rules.objective_only)


func setup(k: String, d: Dictionary, m, start: Vector2, hp_mult: float, dmg_mult: float, bounty_mult: float) -> void:
	kind = k
	main = m
	look = str(d.get("look", k))
	aura = d.get("aura", Color(0, 0, 0, 0))
	max_hp = d["hp"] * hp_mult
	hp = max_hp
	speed = d["speed"] * randf_range(0.9, 1.1)
	damage = d["damage"] * dmg_mult
	wall_damage = d.get("wall_damage", d["damage"]) * dmg_mult
	attack_cd = d["cooldown"]
	fights = d["fights"]
	flying = d.get("flying", false)
	cc_mult = d.get("cc", 1.0)
	knock_mult = d.get("knock", 1.0)
	boss = d.get("boss", false)
	if d.has("stomp"):
		stomp = d["stomp"].duplicate()
		stomp["damage"] *= dmg_mult
	if d.has("breath"):
		breath = d["breath"].duplicate()
		breath["damage"] *= dmg_mult
	cleave = d.get("cleave", {})
	banner = d.get("banner", {})
	if d.has("charge"):
		rush = d["charge"].duplicate()
		rush["damage"] *= dmg_mult
	ranged = d.get("ranged", {})
	pack = d.get("pack", {})
	necro = (d.get("necro", {}) as Dictionary).duplicate(true)
	mend = d.get("mend", {})
	volley = int(d.get("volley", 1))
	shot_style = str(d.get("shot_style", "arrow"))
	shot_splash = float(d.get("shot_splash", 0.0))
	shot_goo = d.get("shot_goo", [])
	cast = d.get("cast", {})
	shield = d.get("shield", {})
	if not shield.is_empty():
		shields_out += 1
	drum = d.get("drum", {})
	regen = d.get("regen", {})
	slam = d.get("slam", {})
	strafe = d.get("strafe", {})
	if not strafe.is_empty():
		strafe = strafe.duplicate()
		strafe["damage"] *= dmg_mult
	gooey = d.get("gooey", false)
	if gooey:
		slimes_out += 1
	goo = d.get("goo", {})
	summon = d.get("summon", {})
	horn = d.get("horn", {})
	enrage_at = d.get("enrage", 0.0)
	if d.has("bomb"):
		bomb = {"wall": d["bomb"]["wall"] * dmg_mult, "units": d["bomb"]["units"] * dmg_mult, "radius": d["bomb"]["radius"]}
	tier = d["tier"]
	bounty = roundi(d["bounty"] * bounty_mult)
	radius = d["radius"]
	sprite_scale = d["scale"]
	color = d["color"]
	position = start
	on_ground = not flying and main.paths.has_terrain()
	bob = randf() * TAU
	drift = randf() * TAU


func _exit_tree() -> void:
	if rite != null and main != null and is_instance_valid(main):
		_end_rite(false)   # (killed mid-rite: the body's left)
	if not shield.is_empty():
		shields_out -= 1
		shield = {}
	if gooey:
		slimes_out -= 1
		gooey = false   # counted once, whatever frees it


func _process(delta: float) -> void:
	if dead:
		return
	if main.campaign:
		main.credit = ""
	walking = false
	fighting = false
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_factor = 1.0
	flash = maxf(flash - delta, 0.0)
	_turn_toward(delta)
	life_t += delta
	lunge = maxf(lunge - delta, 0.0)
	rally = maxf(rally - delta, 0.0)
	ice_crust = maxf(ice_crust - delta, 0.0)
	absorb_note = maxf(absorb_note - delta, 0.0)
	cd_timer = maxf(cd_timer - delta, 0.0)
	root_timer = maxf(root_timer - delta, 0.0)
	confuse_timer = maxf(confuse_timer - delta, 0.0)
	if discord_timer > 0.0:
		discord_timer -= delta
		if discord_timer <= 0.0:
			vuln = 0.0
			weaken = 0.0
			discord_slow = 0.0
	if burn_timer > 0.0:
		burn_timer -= delta
		main.credit = burn_credit
		take_damage(burn_dps * delta, false)
		if dead:
			return
	charged_timer = maxf(charged_timer - delta, 0.0)
	if thorn_timer > 0.0:
		thorn_timer -= delta
		main.credit = thorn_credit
		take_damage(thorn_dps * delta, false)
		if dead:
			return
	if decay_timer > 0.0:
		main.credit = decay_credit
		take_damage(decay_dps * delta, false, MAGIC)   # before the timer runs down, so a rot kill still counts
		decay_timer -= delta
		if dead:
			return
	if corrode_timer > 0.0:
		corrode_timer -= delta
		if corrode_timer <= 0.0:
			corrode = 0.0
	_roster_upkeep(delta)
	if not poisons.is_empty():
		var worst := 0.0
		poison_stacks = 0
		for id in poisons.keys():
			var dose: Array = poisons[id]
			dose[2] -= delta
			if dose[2] <= 0.0:
				poisons.erase(id)
			elif dose[0] * dose[1] > worst:
				worst = dose[0] * dose[1]
				poison_stacks = dose[1]
		main.credit = poison_credit
		take_damage(worst * delta, false, ALCHEMY)
		main.credit = ""
		if dead:
			return
	main.credit = ""
	if fuse >= 0.0:
		# Lit: stands there fizzing, then goes off. Killing it first defuses it.
		fuse -= delta
		if fuse < 0.0:
			_explode()
			return
		queue_redraw()
		return
	if cast_state != "" and (knock_timer > 0.0 or freeze_timer > 0.0 or stun_timer > 0.0 or confuse_timer > 0.0):
		_break_cast()
	if rite != null and (knock_timer > 0.0 or freeze_timer > 0.0 or stun_timer > 0.0 or confuse_timer > 0.0):
		main.spawn_text(position + Vector2(0, -50), "Rite broken!", Color(0.8, 0.9, 1.0))
		_end_rite(false)
	if knock_timer > 0.0:
		# Being knocked back: slides away, can't act.
		knock_timer -= delta
		_step_to(position + knock_velocity * delta)
		position.y = maxf(position.y, radius)
		_push_out()
		queue_redraw()
		return
	if freeze_timer > 0.0 or stun_timer > 0.0:
		# Frozen solid or blinded: no moving, no attacking.
		freeze_timer = maxf(freeze_timer - delta, 0.0)
		stun_timer = maxf(stun_timer - delta, 0.0)
		_push_out()
		queue_redraw()
		return
	if slam_wind > 0.0:
		# Hauling its blow back: it stands, the arc it'll sweep marked on the ground.
		slam_wind -= delta
		fighting = true
		if slam_wind <= 0.0:
			slam_wind = 0.0
			_slam_lands()
		_push_out()
		queue_redraw()
		return
	if not mend.is_empty():
		_mend_update(delta)
	if not necro.is_empty() and not sieging and confuse_timer <= 0.0 and _necro_update(delta):
		_push_out()
		progress = position.y
		queue_redraw()
		return
	cast_cd = maxf(cast_cd - delta, 0.0)
	if not cast.is_empty() and not sieging and confuse_timer <= 0.0 and _cast_update(delta):
		_push_out()
		progress = position.y
		queue_redraw()
		return
	if not strafe.is_empty() and _strafe_update(delta):
		queue_redraw()
		return

	if boss:
		_boss_update(delta)
		if stomp_wind > 0.0 or boss_hold > 0.0:
			boss_hold = maxf(0.0, boss_hold - delta)
			return   # (rooted while it winds up a slam, or caught off balance)
	if not rush.is_empty() and _charge_update(delta):
		_push_out()
		queue_redraw()
		return
	if not breath.is_empty():
		_breathe(delta)
	if confuse_timer > 0.0:
		_confused(delta)
		_push_out()
		queue_redraw()
		return
	aggro_check -= delta
	press_on = maxf(press_on - delta, 0.0)
	if not ranged.is_empty() and not sieging and _shoot_from_range():
		_push_out()
		progress = position.y
		queue_redraw()
		return
	if gooey and not sieging:
		# Troops before the castle: it goes after the nearest one it can get at.
		if aggro_check <= 0.0:
			aggro_check = 0.3
			aggro = _nearest_troop()
		elif aggro != null and (not is_instance_valid(aggro) or not aggro.is_active()):
			aggro = null
	elif _set_on_castle():
		aggro = null   # going for the castle, whatever's hitting it
	elif aggro_check <= 0.0:
		aggro_check = 0.3
		aggro = _attacker()
	elif aggro != null and (not is_instance_valid(aggro) or not aggro.is_active()):
		aggro = null
	if goal != null and (not is_instance_valid(goal) or not goal.is_target()):
		goal = main.rules.enemy_goal(self)   # its objective has fallen (or got away): on to the next
	goal_check -= delta
	if goal_check <= 0.0:
		goal_check = 1.0
		if (goal == null or goal.is_mover()) and main.rules.objective_only():
			goal = main.rules.enemy_goal(self)   # nothing to go for yet (or something nearer to chase)
	var holding: bool = goal != null and goal.kind == "zone" and position.distance_to(goal.position) <= goal.zone_r - radius
	var at_goal: bool = goal != null and not holding and goal.kind != "zone" and position.distance_to(goal.position) - radius - goal.RADIUS <= REACH + 4.0
	var at_castle: bool = goal == null and position.y + radius * 0.5 >= main.CASTLE_Y
	if at_castle and main.rules.on_reached_bottom(self):
		# No castle here: it got past your army, and the rules have counted it.
		dead = true
		main.enemies_changed()
		queue_free()
		return
	if at_castle and not sieging:
		sieging = true
		reached_castle.emit(self)
	# Once it's at the castle it keeps hammering the wall, even with a unit hitting it.
	var blocker = _find_blocker() if fights and bomb.is_empty() and not sieging else null
	var wall = _wall_to_break(delta) if blocker == null and not flying else null
	var at_sap := false
	if not bomb.is_empty():
		_sap_pick(delta)
		at_sap = sap_target != null and _sap_gap(sap_target) <= REACH + 6.0
	if not bomb.is_empty() and (at_castle or at_goal or wall != null or at_sap):
		# At the castle, or up against a wall in the way: light the bomb. At an emplacement
		# it plants the charge first, so there's a moment to stop it.
		fuse = PLANT if at_sap and not (sap_target is BarricadeScript) and wall == null and not at_castle else FUSE
		main.spawn_text(position + Vector2(0, -30), "Fsss!", Color(1, 0.6, 0.2))
		main.sfx("fire", 1.7)   # (the fuse hissing: get it before it goes)
		queue_redraw()
		return
	fighting = blocker != null or wall != null
	if blocker != null:
		lunge_dir = position.direction_to(blocker.position)
		if absf(lunge_dir.x) > 0.2:
			flip = signf(lunge_dir.x)
		if cd_timer <= 0.0 and not slam.is_empty():
			cd_timer = _attack_cd()
			slam_wind = float(slam["windup"])   # (hauled back first: the warning)
		elif cd_timer <= 0.0:
			cd_timer = _attack_cd()
			lunge = 0.15
			if cleave.is_empty():
				blocker.take_damage(damage * _hit_mult())
				if not goo.is_empty() and blocker.is_active():
					blocker.apply_goo(goo["slow"], goo["time"])
			else:
				_cleave()
	elif wall != null:
		lunge_dir = position.direction_to(Geometry2D.get_closest_point_to_segment(position, wall.seg_a(), wall.seg_b()))
		if absf(lunge_dir.x) > 0.2:
			flip = signf(lunge_dir.x)
		if cd_timer <= 0.0:
			cd_timer = _attack_cd()
			lunge = 0.15
			wall.struck(self, wall_damage * _hit_mult())
	elif holding:
		walking = false   # in the ground it was sent to take: it stays, and fights what comes
	elif at_goal:
		# At its objective: hack at it until something kills it (or it falls).
		fighting = true
		lunge_dir = position.direction_to(goal.position)
		if absf(lunge_dir.x) > 0.2:
			flip = signf(lunge_dir.x)
		if cd_timer <= 0.0:
			cd_timer = _attack_cd()
			lunge = 0.15
			main.dmg_src = kind
			goal.take_damage(wall_damage * _hit_mult())
			main.dmg_src = ""
	elif at_castle:
		# At the castle: hammer on its wall until something kills it.
		fighting = true
		lunge_dir = Vector2.DOWN
		if cd_timer <= 0.0:
			cd_timer = _attack_cd()
			lunge = 0.15
			main.damage_castle(wall_damage * _hit_mult())
	elif root_timer > 0.0:
		pass   # held in place by vines
	else:
		drift += delta * 1.3
		var dir := Vector2(sin(drift) * 0.3, 1.0).normalized()
		var route: Vector2
		if goal != null and (goal.is_mover() or goal.kind == "zone"):
			route = _chase_dir(goal.position, delta)   # after something that moves (or open ground): head for it, round any terrain
		else:
			route = Vector2.ZERO if flying else main.paths.direction(position, radius, goal)
		if route == Vector2.ZERO and goal != null:
			route = position.direction_to(goal.position)   # nothing in the way (or it flies): straight there
		if goal == null and aggro == null and position.y >= main.rules.wait_y():
			# Nothing to go for yet: it waits there for something to come along.
			dir = Vector2(sin(drift * 0.7) * 0.4, 0.0)
		elif aggro != null and not breath.is_empty() and position.distance_to(aggro.position) <= breath["range"] * 0.75:
			# A Wyvern hangs in the air within breath range of whoever's shooting it.
			dir = Vector2.ZERO
		elif aggro != null:
			# Going after the unit that's attacking it (round any terrain in the way).
			dir = _chase_dir(aggro.position, delta)
		elif escort != null and is_instance_valid(escort) and not escort.dead:
			# A Shieldbearer keeping in front of the archer, sapper or caster it's covering.
			dir = _chase_dir(_escort_spot(), delta) if position.distance_to(_escort_spot()) > 10.0 else Vector2(0, 1)
		elif sap_target != null:
			# A Sapper making for one of your emplacements (or a wall) to blow up against.
			dir = _chase_dir(_sap_point(sap_target), delta)
		elif route != Vector2.ZERO:
			# Barricades are up: follow the route around them, still weaving a little.
			dir = (route + Vector2(sin(drift) * 0.15, 0.0)).normalized()
		if dir != Vector2.ZERO:
			heading = heading.lerp(dir, 0.2).normalized()
		if flying and breath.is_empty() and flock_pull != Vector2.ZERO:
			dir = (dir + flock_pull).normalized()   # (a bat keeps with its flock)
		var was_at := position
		_step_to(position + dir * speed * _pace() * (main.hazards.speed_factor(kind) if main.gust > 0.0 else 1.0) * slow_factor * (1.0 - discord_slow) * (1.0 - CRUST_SLOW if ice_crust > 0.0 else 1.0) * (1.0 + rally_speed if rally > 0.0 else 1.0) * delta)
		if absf(dir.x) > 0.1:
			flip = signf(dir.x)
		if flying:
			bob += delta * 20.0   # bats flap fast
		else:
			# Steps keep pace with the ground it covers (slowed, it steps slowly; no sliding feet).
			bob += minf(position.distance_to(was_at) / (1.4 * sprite_scale), delta * 30.0)
		walking = true
	_push_out()
	progress = position.y
	position.y = minf(position.y, main.CASTLE_Y - radius * 0.5)   # the castle wall stops it
	queue_redraw()


## How hard its blows land: less weakened, more when the Marshal's banner drives it on.
func _hit_mult() -> float:
	return (1.0 - weaken) * (1.0 + rally_dmg if rally > 0.0 else 1.0) * (1.0 + float(pack["per"]) * pack_n if not pack.is_empty() else 1.0)


## Its time between blows: quicker with its pack round it.
func _attack_cd() -> float:
	var cd := attack_cd / (1.0 + float(pack["per"]) * 0.5 * pack_n) if not pack.is_empty() else attack_cd
	return cd / (1.0 + driven_rate) if driven > 0.0 else cd


## How its pace is changed by its own kind about it: bolder in a pack, warier alone.
func _pace() -> float:
	var k := 1.0
	if not pack.is_empty():
		k = 1.0 + float(pack["speed"]) * pack_n if pack_n > 0 else 1.0 - float(pack["alone"])
	if driven > 0.0:
		k *= 1.0 + driven_speed
	if not drum.is_empty() and drum_ahead == 0 and position.y > 60.0:
		k *= 0.4   # (a drummer with no one ahead of it hangs back for the rest to come up)
	if escort != null and is_instance_valid(escort) and not escort.dead:
		# A Shieldbearer keeps pace with its charge, and hurries to get in front of it.
		k = maxf(k, escort.speed * escort._pace() / speed) * (1.5 if position.distance_to(_escort_spot()) > 12.0 else 1.0)
	return k


## Where a Shieldbearer stands to cover its charge: just in front of it, toward the troops.
func _escort_spot() -> Vector2:
	if position.y < escort.position.y - 4.0:
		# Still behind it: round its side first (not shoving into its back).
		var side := 1.0 if position.x >= escort.position.x else -1.0
		return escort.position + Vector2(side * (radius + escort.radius + 6.0), 18.0)
	return escort.position + Vector2(0, 26.0)


## How much of a shot is turned aside: by its own shield, if the shot comes at its front;
## by a Shieldbearer's just in front of it, sheltering it. 0 for blows, and for shots from
## the side or behind.
func _shield_cut() -> float:
	var from: Vector2 = main.hit_from
	if from == Vector2.INF:
		return 0.0
	var to := from - position
	if not shield.is_empty() and to.length() > 1.0 and absf(heading.angle_to(to)) <= float(shield["arc"]):
		return float(shield["front"])
	if shields_out <= 0:
		return 0.0
	for e in main.enemies_near(position, 60.0):
		if e == self or e.dead or e.shield.is_empty():
			continue
		var gap: Vector2 = e.position - position
		if gap.length() <= float(e.shield["cover_r"]) and gap.dot(to) > 0.0:
			return float(e.shield["cover"])   # (it's between this one and whoever shot)
	return 0.0


## Every frame: counting its pack, keeping with its flock, a Troll's wounds closing.
func _roster_upkeep(delta: float) -> void:
	if not pack.is_empty():
		pack_t -= delta
		if pack_t <= 0.0:
			pack_t = PACK_EVERY
			var n := 0
			var r: float = pack["radius"]
			for e in main.enemies_near(position, r):
				if e != self and e.kind == kind and not e.dead and position.distance_to(e.position) <= r:
					n += 1
			pack_n = mini(n, int(pack["max"]))
	if flying and breath.is_empty():
		flock_t -= delta
		if flock_t <= 0.0:
			flock_t = 0.4
			var sum := Vector2.ZERO
			var n := 0
			for e in main.enemies_near(position, 90.0):
				if e != self and e.kind == kind and not e.dead:
					sum += e.position
					n += 1
			flock_pull = Vector2.ZERO if n == 0 else (sum / n - position).limit_length(60.0) / 60.0 * 0.45
	driven = maxf(driven - delta, 0.0)
	drum_beat = maxf(drum_beat - delta, 0.0)
	block_note = maxf(block_note - delta, 0.0)
	if not drum.is_empty() and position.y > 0.0:
		drum_t -= delta
		if drum_t <= 0.0:
			drum_t = float(drum["every"])
			drum_beat = 0.3
			var r: float = drum["radius"]
			var kinds: Array = drum["kinds"]
			drum_ahead = 0
			for e in main.enemies_near(position, r):
				if e == self or e.dead or not (kinds.has(e.kind) or kinds.has("*")) or position.distance_to(e.position) > r:
					continue
				e.driven = maxf(e.driven, float(drum["time"]))   # (driven on is driven on: drums don't add up)
				e.driven_speed = float(drum["speed"])
				e.driven_rate = float(drum["rate"])
				if e.position.y > position.y + 10.0:
					drum_ahead += 1
			main.sfx("drum", 0.75)
			queue_redraw()
	if not shield.is_empty():
		escort_t -= delta
		if escort_t <= 0.0:
			escort_t = 0.6
			escort = null
			var best := 150.0
			for e in main.enemies_near(position, 150.0):
				if e != self and not e.dead and ESCORTED.has(e.kind) and position.distance_to(e.position) < best:
					best = position.distance_to(e.position)
					escort = e
	mending = false
	if not regen.is_empty():
		unhurt += delta
		if unhurt >= float(regen["delay"]) and burn_timer <= 0.0 and hp < max_hp:
			hp = minf(max_hp, hp + max_hp * float(regen["rate"]) * delta)
			mending = true
			queue_redraw()


## A spell being charged (or poured out), broken off: stunned, frozen, knocked or confused.
func _break_cast() -> void:
	if cast_state == "charge":
		main.spawn_text(position + Vector2(0, -40), "Interrupted!", Color(0.8, 0.9, 1.0))
	cast_state = ""
	cast_cd = maxf(cast_cd, 1.5)


## Horde Mage: when a troop of yours comes within reach, it stands and charges a spell (one of
## lightning, fire and arcane, chosen once as the charge starts, its colour showing at the
## staff), then lets it go; then a cooldown. A stun, freeze or knock while it's charging
## breaks the spell off. Returns true while it's standing to cast (it does nothing else then).
func _cast_update(delta: float) -> bool:
	if cast_state == "flame":
		_flame(delta)
		return true
	if cast_state == "charge":
		cast_left -= delta
		lunge_dir = position.direction_to(_cast_aim()) if _cast_aim() != Vector2.INF else lunge_dir
		if absf(lunge_dir.x) > 0.2:
			flip = signf(lunge_dir.x)
		if cast_left <= 0.0:
			_cast_release()
		return true
	var r: float = cast["range"]
	var near = _cast_nearest(position, r * 1.1, {})
	if near == null:
		return false   # nothing to cast at: on it goes
	fighting = true
	lunge_dir = position.direction_to(near.position)
	if absf(lunge_dir.x) > 0.2:
		flip = signf(lunge_dir.x)
	if cast_cd > 0.0 or _cast_nearest(position, r, {}) == null:
		return true   # (stands its ground, out of reach, while it gathers itself)
	var spells: Array = cast.get("spells", SPELLS)
	cast_spell = spells[randi() % spells.size()]   # (once, as the charge begins: no changing its mind)
	cast_state = "charge"
	cast_left = float(cast["charge"])
	main.sfx("spell", {"lightning": 1.3, "fire": 0.8, "arcane": 1.0}[cast_spell])
	return true


const SPELLS := ["lightning", "fire", "arcane"]
const SPELL_COLORS := {"lightning": Color(0.75, 0.9, 1.0), "fire": Color(1.0, 0.5, 0.15), "arcane": Color(0.8, 0.4, 1.0)}


## Where its charging spell's pointed: the troop it would go for now (INF if none).
func _cast_aim() -> Vector2:
	var t = _arcane_mark() if cast_spell == "arcane" else _cast_nearest(position, float(cast["range"]), {})
	return t.position if t != null else Vector2.INF


## The nearest troop within `r` of `p` it could hit (not in `skip`), with no wall in the way.
func _cast_nearest(p: Vector2, r: float, skip: Dictionary):
	var best = null
	var best_d := r
	for w in main.warriors_near(p, r + 20.0):
		if not w.is_active() or w.sheltered() or w.unmanned_tower() or skip.has(w):
			continue
		var d: float = p.distance_to(w.position)
		if d <= best_d and not _wall_across(position, w.position):
			best_d = d
			best = w
	return best


## The arcane beam's mark: of the troops in reach, the one with the most health left (the
## nearer of two alike, then the older: no coin-tossing).
func _arcane_mark():
	var best = null
	var r: float = cast["range"]
	for w in main.warriors_near(position, r + 20.0):
		if not w.is_active() or w.sheltered() or w.unmanned_tower() or position.distance_to(w.position) > r or _wall_across(position, w.position):
			continue
		if best == null or w.hp > best.hp + 0.01 or (absf(w.hp - best.hp) <= 0.01 and (position.distance_to(w.position) < position.distance_to(best.position) - 0.01
				or absf(position.distance_to(w.position) - position.distance_to(best.position)) <= 0.01 and w.get_instance_id() < best.get_instance_id())):
			best = w
	return best


## The charge done: the spell goes. With nothing left to aim at, it fizzles (and it's soon
## ready again).
func _cast_release() -> void:
	cast_state = ""
	cast_cd = float(cast["cooldown"])
	lunge = 0.15
	match cast_spell:
		"lightning":
			var sp: Dictionary = cast["lightning"]
			var cur = _cast_nearest(position, float(cast["range"]), {})
			if cur == null:
				_fizzle()
				return
			var struck := {}
			var from := position + Vector2(10.0 * flip, -radius * 2.2)
			var dmg: float = float(sp["damage"]) * _hit_mult()
			while cur != null and struck.size() <= int(sp["jumps"]):
				struck[cur] = true
				cur.take_damage(dmg)
				main.spawn_beam(from, cur.position + Vector2(0, -10), Color(0.75, 0.9, 1.0), 3.0)
				main.spawn_burst(cur.position + Vector2(0, -10), 10.0, Color(0.85, 0.95, 1.0))
				from = cur.position + Vector2(0, -10)
				dmg *= 1.0 - float(sp["falloff"])
				cur = _cast_nearest(cur.position, float(sp["chain_r"]), struck)
			last_chain = struck.size()
			main.sfx("zap", 1.1)
		"fire":
			var t = _cast_nearest(position, float(cast["fire"]["range"]), {})
			if t == null:
				t = _cast_nearest(position, float(cast["range"]), {})
			if t == null:
				_fizzle()
				return
			flame_dir = position.direction_to(t.position)
			cast_state = "flame"
			flame_left = float(cast["fire"]["time"])
			flame_tick = 0.0
			main.sfx("flame", 0.7)
		"arcane":
			var sp: Dictionary = cast["arcane"]
			var t = _arcane_mark()
			if t == null:
				_fizzle()
				return
			var dmg := minf(float(sp["damage"]) * _hit_mult(), t.max_hp * float(sp["cap"]))   # (hard, but never a sure kill outright)
			t.take_damage(dmg)
			last_arcane = t
			main.spawn_beam(position + Vector2(10.0 * flip, -radius * 2.2), t.position + Vector2(0, -10), Color(0.8, 0.4, 1.0), 9.0)
			main.spawn_burst(t.position + Vector2(0, -10), 22.0, Color(0.85, 0.5, 1.0))
			main.sfx("beam", 0.9)


func _fizzle() -> void:
	cast_cd = 1.2
	main.spawn_text(position + Vector2(0, -40), "Fizzle", Color(0.7, 0.7, 0.75))


## The flamethrower: it stands and pours fire down the line it chose, for its whole length;
## everyone in the cone burns, a tick at a time (the same however fast the game runs).
func _flame(delta: float) -> void:
	fighting = true
	lunge_dir = flame_dir
	flame_left -= delta
	flame_tick -= delta
	var sp: Dictionary = cast["fire"]
	var tick: float = sp["tick"]
	while flame_tick <= 0.0 and flame_left > -tick * 0.5:
		flame_tick += tick
		var reach: float = sp["range"]
		for w in main.warriors_near(position, reach + 20.0):
			if not w.is_active() or w.sheltered():
				continue
			var off: Vector2 = w.position - position
			if off.length() - w.RADIUS <= reach and absf(flame_dir.angle_to(off)) <= float(sp["arc"]):
				w.take_damage(float(sp["dps"]) * tick * _hit_mult())
	queue_redraw()
	if flame_left <= 0.0:
		cast_state = ""



## Gravebinder: hangs back from your troops; calls up Skeleton Archers now and then (never
## more than its limit of them at once); and, its signature, raises one of your fallen
## troops against you: it picks a fallen troop in reach (the most worth the time it takes),
## and channels, a tether from its staff to the body and the troop's ghost rising, for longer
## the more had been spent on that troop; if nothing breaks it off (a stun, freeze, knock or
## confusion, or killing it), the troop rises corrupted, fighting for the horde. Returns true
## while it's standing (to channel, or to keep its distance).
func _necro_update(delta: float) -> bool:
	minions = minions.filter(func(m): return is_instance_valid(m) and not m.dead)
	raised = raised.filter(func(m): return is_instance_valid(m) and not m.dead)
	if rite != null:
		if not main.fallen.has(rite) or rite["claimed"] != self:
			_end_rite(false)
			return false
		rite_left -= delta
		fighting = true
		lunge_dir = position.direction_to(rite["at"])
		if absf(lunge_dir.x) > 0.2:
			flip = signf(lunge_dir.x)
		queue_redraw()
		if rite_left <= 0.0:
			var rec: Dictionary = rite
			_end_rite(true)
			var e = main.raise_fallen(rec, self)
			if e != null:
				raised.append(e)
		return true
	necro_t -= delta
	summon_t -= delta
	if necro_t > 0.0:
		return _keep_back()
	necro_t = 0.5
	var reach: float = necro["reach"]
	# Its signature first: one of your fallen to raise.
	if raised.size() < int(necro["max_raised"]):
		var best = null
		var best_score := -1.0
		for rec in main.fallen:
			if rec["claimed"] != null or position.distance_to(rec["at"]) > reach:
				continue
			var t := rite_time(rec)
			if rec["left"] < t + 1.0:
				continue   # (it would be gone before the rite was done)
			var score: float = (float(rec["spent"]) + 40.0) / t
			if score > best_score:
				best_score = score
				best = rec
		if best != null:
			rite = best
			best["claimed"] = self
			rite_total = rite_time(best)
			rite_left = rite_total
			main.sfx("rise", 0.6)
			main.spawn_text(best["at"] + Vector2(0, -40), "It stirs...", Color(0.6, 1.0, 0.6))
			main.hud.show_message("A Gravebinder is raising your fallen %s! Stop it!" % best["name"])
			return true
	# Then the bowmen: when there's something to shoot.
	if summon_t <= 0.0 and minions.size() < int(necro["summon_max"]) and not main.warriors_near(position, reach).is_empty():
		summon_t = float(necro["summon_every"])
		for i in mini(int(necro["summon_count"]), int(necro["summon_max"]) - minions.size()):
			var spot := position + Vector2.from_angle(-PI * 0.75 + i * PI * 0.5) * (radius + 22.0)
			main.spawn_minion("skeleton_archer", level, spot)
			minions.append(main.enemy_layer.get_child(main.enemy_layer.get_child_count() - 1))
		main.spawn_burst(position + Vector2(0, -10), 40.0, Color(0.5, 1.0, 0.55))
		main.spawn_text(position + Vector2(0, -60), "Rise, bowmen!", Color(0.6, 1.0, 0.6))
		main.sfx("rise", 0.8)
	return _keep_back()


## How long it takes to raise a fallen troop: longer the more was spent on it (its kind's
## price and every upgrade), capped.
func rite_time(rec: Dictionary) -> float:
	return minf(float(necro["raise_base"]) + float(rec["spent"]) * float(necro["raise_per_gold"]), float(necro["raise_max"]))


## A rite over: done (the body's taken), or broken off (the body's left for later).
func _end_rite(done: bool) -> void:
	if rite != null:
		if done:
			main.fallen.erase(rite)
		elif rite["claimed"] == self:
			rite["claimed"] = null
	rite = null
	rite_left = 0.0


## Whether it stands off: with your troops close enough to be a threat but not yet on it,
## it doesn't walk into them (one right up against it, it fights back as anything would).
func _keep_back() -> bool:
	var near: Array = main.warriors_near(position, float(necro["keep_back"]))
	for w in near:
		if w.is_active() and not w.sheltered() and position.distance_to(w.position) <= radius + w.RADIUS + 8.0:
			return false   # (one's on it: it fights)
	return near.any(func(w): return w.is_active() and not w.sheltered() and w.position.y > position.y)


## A corrupted Healer's mending: now and then the most hurt of the horde in reach is healed.
func _mend_update(delta: float) -> void:
	mend_t -= delta
	if mend_t > 0.0:
		return
	mend_t = float(mend["every"])
	var best = null
	var worst := 0.99
	for e in main.enemies_near(position, float(mend["range"])):
		if e.dead or e.boss or position.distance_to(e.position) > float(mend["range"]):
			continue
		var share: float = e.hp / e.max_hp
		if share < worst:
			worst = share
			best = e
	if best != null:
		best.hp = minf(best.max_hp, best.hp + float(mend["amount"]))
		main.spawn_beam(position + Vector2(0, -20), best.position + Vector2(0, -12), Color(0.55, 0.9, 0.45), 4.0)
		main.spawn_text(best.position + Vector2(0, -30), "+%d" % roundi(float(mend["amount"])), Color(0.55, 1.0, 0.5))



## One more shot at `mark` (a volley's extra arrows).
func _loose(mark, aim: Vector2) -> void:
	var shot := EnemyShot.new()
	shot.style = shot_style
	shot.splash = shot_splash
	shot.goo = shot_goo
	shot.main = main
	shot.target = mark
	shot.target_pos = aim
	shot.position = position + Vector2(8.0 * flip, -radius * 1.2)
	shot.speed = ranged["speed"]
	shot.damage = damage * _hit_mult()
	main.add_projectile(shot)


## Where its hauled-back blow will land, and how far round: [centre, radius].
func _slam_zone() -> Array:
	var reach: float = slam["reach"]
	return [position + lunge_dir * (radius + reach * 0.5), reach * 0.5 + radius * 0.6 + 10.0]


## Its blow lands: everyone in the arc in front of it is hit, thrown back and staggered.
func _slam_lands() -> void:
	lunge = 0.15
	var reach: float = slam["reach"]
	var half: float = float(slam["arc"]) / 2.0
	for w in main.warriors_near(position, radius + reach + 30.0):
		if not w.is_active() or w.sheltered():
			continue
		var off: Vector2 = w.position - position
		if off.length() - radius - w.RADIUS > reach:
			continue
		if off.length() > 0.01 and absf(lunge_dir.angle_to(off)) > half:
			continue
		w.take_damage(damage * _hit_mult())
		if w.is_active():
			w.shove((off.normalized() if off.length() > 0.01 else lunge_dir) * float(slam["push"]), float(slam["stun"]))
	var tip := position + lunge_dir * (radius + reach * 0.6)
	main.spawn_burst(tip, reach + 8.0, Color(0.75, 0.6, 0.4))
	main.sfx("stomp", 1.4 if radius < 22.0 else 1.15)


## The Wyvern's strafing run: now and then it picks out troops below, shows the line it'll
## swoop down, then dives along it breathing fire on everyone under it (once each). Returns
## true while it's at it (it does nothing else then).
func _strafe_update(delta: float) -> bool:
	if strafe_warn > 0.0:
		strafe_warn -= delta
		if strafe_warn <= 0.0:
			strafe_left = strafe_from.distance_to(strafe_to) / float(strafe["speed"])
			strafe_hit = {}
			main.sfx("flame", 0.8)
		return true
	if strafe_left > 0.0:
		strafe_left -= delta
		var dir := strafe_from.direction_to(strafe_to)
		position += dir * float(strafe["speed"]) * delta
		if absf(dir.x) > 0.1:
			flip = signf(dir.x)
		bob += delta * 30.0
		var wd: float = strafe["width"]
		for w in main.warriors_near(position, wd + 30.0):
			if w.is_active() and not w.sheltered() and not strafe_hit.has(w) and position.distance_to(w.position) <= wd + w.RADIUS:
				strafe_hit[w] = true
				w.take_damage(float(strafe["damage"]) * _hit_mult())
		strafe_fx -= delta
		if strafe_fx <= 0.0:
			strafe_fx = 0.07
			main.spawn_burst(position + Vector2(0, 6), wd, Color(1.0, 0.5, 0.15))
		return strafe_left > 0.0
	strafe_timer -= delta
	if strafe_timer > 0.0 or position.y < 30.0:
		return false
	var best = null
	var best_d := 280.0
	for w in main.warriors_near(position, 280.0):
		if not w.is_active() or w.sheltered() or w.unmanned_tower():
			continue
		var d := position.distance_to(w.position)
		if d < best_d:
			best_d = d
			best = w
	if best == null:
		strafe_timer = 1.5
		return false
	strafe_timer = float(strafe["cooldown"])
	strafe_from = position
	var dir2 := position.direction_to(best.position) if best.position != position else Vector2.DOWN
	strafe_to = (position + dir2 * float(strafe["length"])).clamp(Vector2(radius, 0.0), Vector2(main.FIELD_W - radius, main.CASTLE_Y - 60.0))
	strafe_warn = float(strafe["warn"])
	lunge_dir = dir2
	main.spawn_text(position + Vector2(0, -50), "!", Color(1, 0.45, 0.2))
	return true



## The ground about to be hit by this one's warned attacks (a slam winding up, a charge's
## line), for troops to get out of: main.dangers().
func danger_zones() -> Array:
	var out := []
	if stomp_wind > 0.0:
		out.append({"c": position, "r": float(stomp["radius"])})
	if slam_wind > 0.0:
		var z := _slam_zone()
		out.append({"c": z[0], "r": z[1]})
	if strafe_warn > 0.0 or strafe_left > 0.0:
		out.append({"a": strafe_from, "b": strafe_to, "r": float(strafe["width"])})
	if charge_warn > 0.0:   # (warned charges only: an unwarned rush, the Ash Marshal's, can't be seen coming)
		out.append({"a": position, "b": position + charge_dir * charge_len, "r": radius})
	return out


## Ogre King: stomps when anything of yours is close, calls in help, and gets
## angrier as it's worn down.
func _boss_update(delta: float) -> void:
	if exposed > 0.0 or charge_warn > 0.0 or charging > 0.0:
		return   # (busy charging, or off balance after it)
	if not enraged and enrage_at > 0.0 and hp < max_hp * enrage_at:
		enraged = true
		speed *= ENRAGE_SPEED
		attack_cd *= ENRAGE_RATE
		main.hud.show_message("%s is enraged!" % main.Data.ENEMIES[kind].get("name", "It"))
	if not banner.is_empty():
		_banner_update(delta)
	stomp_timer -= delta
	if stomp_wind > 0.0:
		# Winding up a slam: the ring on the ground fills, then it lands on whoever's still in it.
		stomp_wind -= delta
		queue_redraw()
		if stomp_wind > 0.0:
			return
		stomp_wind = 0.0
		_stomp_lands()
	elif not stomp.is_empty() and stomp_timer <= 0.0:
		var r0: float = stomp["radius"]
		var near0: Array = main.get_warriors().filter(func(w): return w.is_active() and position.distance_to(w.position) <= r0 + w.RADIUS)
		var walls0: Array = main.get_barricades().filter(func(b): return b.is_active() and b.gap_from(position) <= r0)
		if not near0.is_empty() or not walls0.is_empty():
			stomp_timer = stomp["cooldown"]
			stomp_wind = STOMP_WARN   # (the warning first: quick troops can get clear)
			main.spawn_text(position + Vector2(0, -70), "!", Color(1, 0.4, 0.3))
	_boss_rest(delta)


## The slam itself, once its warning's run out.
func _stomp_lands() -> void:
	var r: float = stomp["radius"]
	main.sfx("stomp")
	lunge = 0.15
	for w in main.get_warriors().filter(func(x): return x.is_active() and position.distance_to(x.position) <= r + x.RADIUS):
		w.take_damage(stomp["damage"])
		var away: Vector2 = position.direction_to(w.position) if w.position != position else Vector2.DOWN
		w.shove(away * stomp.get("push", 0.0), stomp.get("stun", 0.0))
	for b in main.get_barricades().filter(func(x): return x.is_active() and x.gap_from(position) <= r):
		b.take_damage(stomp["damage"] * 3.0)
	main.spawn_burst(position + Vector2(0, radius), r, Color(0.65, 0.5, 0.3))
	main.spawn_burst(position + Vector2(0, radius), r * 0.6, Color(0.85, 0.75, 0.55))
	main.spawn_text(position + Vector2(0, -60), "STOMP!", Color(1, 0.75, 0.4))


## The rest of a boss's turn: its summons and war horn.
func _boss_rest(delta: float) -> void:
	var em: Dictionary = main.Data.ENEMIES[kind].get("embers", {})
	if not em.is_empty():
		embers_timer -= delta
		if embers_timer <= 0.0:
			embers_timer = float(em["cooldown"])
			# Burning ground: under the troops nearest him, marked a moment before it catches.
			var near: Array = main.get_warriors().filter(func(w): return w.is_active() and not w.is_emplacement() and w.position.distance_to(position) < 360.0)
			near.shuffle()
			for w in near.slice(0, int(em["count"])):
				var patch = preload("res://scripts/ember_patch.gd").new()
				patch.main = main
				patch.position = w.position
				patch.radius = float(em["radius"])
				patch.dps = float(em["dps"]) * (1.0 + 0.1 * (level - 1))
				patch.duration = float(em["duration"])
				patch.warn = float(em["warn"])
				main.corpse_layer.add_child(patch)
			if not near.is_empty():
				main.spawn_text(position + Vector2(0, -70), "Burn!", Color(1, 0.5, 0.2))
	summon_timer -= delta
	if not summon.is_empty() and summon_timer <= 0.0 and position.y > 0.0:
		summon_timer = summon["cooldown"]
		for i in summon["count"]:
			var spot := position + Vector2.from_angle(PI + i * PI / maxf(summon["count"] - 1, 1)) * (radius + 20.0)
			main.spawn_minion(summon["kinds"].pick_random(), level, spot)
		main.spawn_text(position + Vector2(0, -60), "To me!", Color(1, 0.5, 0.4))
	horn_timer -= delta
	if not horn.is_empty() and horn_timer <= 0.0 and position.y > 0.0:
		horn_timer = horn["cooldown"]
		var kinds: Array = []
		for i in horn["count"]:
			kinds.append(horn["kinds"].pick_random())
		main.reinforce(kinds, level)
		main.spawn_text(position + Vector2(0, -60), "WAR HORN!", Color(1, 0.4, 0.3))


## His banner on its pole beside him, flapping (and the ground it drives on, faintly);
## knocked down, it lies in the dirt.
func _draw_banner(feet: float, size: Vector2) -> void:
	var x := radius * 1.1 * flip
	if banner_up():
		var t := Time.get_ticks_msec() / 1000.0
		draw_arc(Vector2(0, feet), float(banner["radius"]), 0.0, TAU, 48, Color(1.0, 0.45, 0.15, 0.12), 2.0)
		var top := Vector2(x, feet - size.y * 1.3)
		draw_rect(Rect2(top.x - 1.5, top.y, 3, feet - top.y), Color(0.12, 0.08, 0.06))
		var wave := sin(t * 6.0) * 3.0
		var flag := PackedVector2Array([top + Vector2(1, 2), top + Vector2(26 * flip, 4 + wave), top + Vector2(22 * flip, 14 + wave * 0.5), top + Vector2(26 * flip, 24 + wave), top + Vector2(1, 22)])
		draw_colored_polygon(flag, Color(0.55, 0.16, 0.08))
		draw_polyline(flag + PackedVector2Array([flag[0]]), Color(0.1, 0.05, 0.04), 1.5)
		draw_circle(top + Vector2(12 * flip, 13 + wave * 0.7), 4.0, Color(1.0, 0.55, 0.15, 0.7 + 0.3 * sin(t * 9.0)))
	else:
		draw_line(Vector2(x - 20, feet + 2), Vector2(x + 20, feet - 2), Color(0.12, 0.08, 0.06), 3.0)
		draw_rect(Rect2(x + 6, feet - 6, 14, 8), Color(0.4, 0.13, 0.07))


## The Ash Marshal's war banner: every half second it drives on the enemies round him (more
## damage, more speed) while it flies. Damage piling up on him (BREAK of his health, fading
## over a few seconds) knocks it down for a while, then he raises it again.
func _banner_update(delta: float) -> void:
	recent_hurt *= exp(-delta / 4.0)
	if banner_down > 0.0:
		banner_down -= delta
		if banner_down <= 0.0:
			main.hud.show_message("The Ash Marshal raises his banner again!")
			main.spawn_text(position + Vector2(0, -70), "RALLY!", Color(1, 0.5, 0.2))
		return
	if recent_hurt >= max_hp * float(banner["break"]):
		banner_down = float(banner["down"])
		recent_hurt = 0.0
		main.hud.show_message("The Ash Marshal's banner is down! His host falters.")
		main.spawn_text(position + Vector2(0, -70), "Banner down!", Color(0.6, 0.9, 1.0))
		main.sfx("crumble")
		return
	banner_tick -= delta
	if banner_tick > 0.0:
		return
	banner_tick = 0.5
	for e in main.enemies_near(position, float(banner["radius"])):
		if e != self and not e.dead and position.distance_to(e.position) <= float(banner["radius"]):
			e.rally = 0.7
			e.rally_dmg = float(banner["damage"])
			e.rally_speed = float(banner["speed"])


## Whether his banner is flying.
func banner_up() -> bool:
	return not banner.is_empty() and banner_down <= 0.0


## The Ash Marshal's charge: now and then he rushes a troop of yours that's in his way
## and out in front, straight at it, striking and throwing aside whoever he runs into. Only
## along a line that's clear: never through rock, cliffs, water (a ford included) or a
## wall, and a charge that meets one stops dead. Returns true while charging.
func _charge_update(delta: float) -> bool:
	if charge_warn > 0.0:
		charge_warn -= delta
		queue_redraw()
		if charge_warn <= 0.0:
			charge_warn = 0.0
			_charge_go()
		return true
	if exposed > 0.0:
		exposed -= delta
		queue_redraw()
		if exposed <= 0.0:
			exposed = 0.0
			vuln = maxf(0.0, vuln - float(rush.get("exposed_vuln", 0.0)))
		return true
	if charging > 0.0:
		charging -= delta
		if charging <= 0.0 and float(rush.get("exposed", 0.0)) > 0.0:
			# Spent: off balance where it stopped, open to the troops round it.
			exposed = float(rush["exposed"])
			vuln += float(rush.get("exposed_vuln", 0.0))
			main.spawn_text(position + Vector2(0, -80), "Exposed!", Color(1, 0.9, 0.4))
			return true
		var next := position + charge_dir * float(rush["speed"]) * delta
		var paths = main.paths
		if paths.blocked(next, radius) or paths.in_ford(next) or paths.any_wall_between(position, next) \
				or next.y > main.CASTLE_Y - radius or next.x < radius or next.x > main.FIELD_W - radius:
			charging = 0.0   # (something in the way: it stops dead)
			if float(rush.get("exposed", 0.0)) > 0.0:
				exposed = float(rush["exposed"])
				vuln += float(rush.get("exposed_vuln", 0.0))
				main.spawn_text(position + Vector2(0, -80), "Exposed!", Color(1, 0.9, 0.4))
				return true
			return false
		position = next
		walking = true
		bob += delta * 30.0
		for w in main.get_warriors():
			if w.is_active() and not w.sheltered() and not charge_hit.has(w) and position.distance_to(w.position) <= radius + w.RADIUS + 4.0:
				charge_hit.append(w)
				w.take_damage(float(rush["damage"]))
				var side := Vector2(-charge_dir.y, charge_dir.x)
				w.shove((side if side.dot(w.position - position) >= 0.0 else -side) * float(rush["push"]), float(rush["stun"]))
		return charging > 0.0
	charge_timer -= delta
	if charge_timer > 0.0 or position.y < 40.0 or stun_timer > 0.0 or freeze_timer > 0.0:
		return false
	var best = null
	var best_d := INF
	for w in main.get_warriors():
		if not w.is_active() or w.is_emplacement() or w.wall_guard:
			continue
		var d := position.distance_to(w.position)
		if d < float(rush["min"]) or d > float(rush["range"]) or w.position.y < position.y - 20.0 or d >= best_d:
			continue
		if _clear_run(position, w.position):
			best = w
			best_d = d
	if best == null:
		charge_timer = 1.0   # (look again shortly)
		return false
	charge_timer = float(rush["cooldown"])
	charge_dir = position.direction_to(best.position)
	charge_len = best_d + 20.0
	charge_hit = []
	lunge_dir = charge_dir
	if float(rush.get("warn", 0.0)) > 0.0:
		charge_warn = float(rush["warn"])   # (its line on the ground first: time to get out of the way)
		main.spawn_text(position + Vector2(0, -70), "!", Color(1, 0.4, 0.3))
		return true
	_charge_go()
	return true


var charge_len := 0.0

func _charge_go() -> void:
	charging = charge_len / float(rush["speed"])
	main.spawn_text(position + Vector2(0, -70), "CHARGE!", Color(1, 0.45, 0.2))
	main.sfx("dash", 0.7)


## Whether a charge from a to b would meet nothing: no rock, cliff, water, ford or wall.
func _clear_run(a: Vector2, b: Vector2) -> bool:
	var paths = main.paths
	if paths.segment_blocked(a, b, radius) or paths.any_wall_between(a, b):
		return false
	var n := int(a.distance_to(b) / 12.0) + 1
	for i in n + 1:
		if paths.in_ford(a.lerp(b, float(i) / n)):
			return false
	return true


## Ogre King's blow: sweeps an arc in front of it, hitting everyone caught in it.
func _cleave() -> void:
	var reach: float = cleave["reach"]
	var half: float = cleave["arc"] / 2.0
	for w in main.get_warriors():
		if not w.is_active() or w.sheltered():
			continue
		var off: Vector2 = w.position - position
		if off.length() - radius - w.RADIUS > reach:
			continue
		if off.length() > 0.01 and absf(lunge_dir.angle_to(off)) > half:
			continue
		w.take_damage(damage * _hit_mult())
	var tip := position + lunge_dir * (radius + reach * 0.6)
	main.spawn_burst(tip, reach + 10.0, Color(1.0, 0.85, 0.6))


## Wyvern: breathes fire down on the warrior nearest below it, splashing those around.
func _breathe(delta: float) -> void:
	breath_timer -= delta
	if breath_timer > 0.0 or position.y < 0.0:
		return
	var best = null
	var best_d: float = breath["range"]
	if aggro != null and is_instance_valid(aggro) and aggro.is_active() and position.distance_to(aggro.position) - aggro.RADIUS < best_d:
		best = aggro   # whoever's attacking it gets the fire first
	else:
		for w in main.get_warriors():
			if not w.is_active() or w.sheltered() or w.unmanned_tower():
				continue
			var d: float = position.distance_to(w.position) - w.RADIUS
			if d < best_d:
				best_d = d
				best = w
	if best == null:
		return
	breath_timer = breath["cooldown"]
	var at: Vector2 = best.position
	for w in main.get_warriors():
		if w.is_active() and not w.sheltered() and w.position.distance_to(at) <= breath["radius"] + w.RADIUS:
			w.take_damage(breath["damage"] * _hit_mult())
	lunge_dir = position.direction_to(at)
	lunge = 0.15
	main.spawn_flame(position + Vector2(0, -FLY_HEIGHT), at)
	main.spawn_burst(at, breath["radius"], Color(1.0, 0.5, 0.15))


## The unit attacking this enemy that it turns on, if any: the nearest one that has
## it as its target and is within range of it (so is shooting or swinging at it, not
## just heading its way), within AGGRO_LEASH, with no wall in between. Sappers and
## wolves never turn aside; a Wyvern flies over to breathe fire on its attacker.
func _attacker():
	if (not fights and breath.is_empty()) or not bomb.is_empty() or boss or not ranged.is_empty():
		return null   # wolves slip past, sappers have a job to do (Wyverns breathe on theirs), archers shoot back from where they stand
	var best = null
	var best_d := AGGRO_LEASH
	for w in main.get_warriors():
		if not w.is_active() or w.target != self or w.is_emplacement() and w.attack_range <= 0.0:
			continue
		var d: float = position.distance_to(w.position)
		if d > best_d or d - radius - w.RADIUS > w.attack_range + 12.0:
			continue
		if not flying and _wall_across(position, w.position):
			continue
		best_d = d
		best = w
	if best != null and best.garrison != null and is_instance_valid(best.garrison):
		return best.garrison   # shot at from a Tower: it goes for the tower
	return best


## Skeleton Archer: with a troop in bow range (and no wall in the way), or the castle,
## it stands and shoots. Returns whether it did (or is waiting to draw again).
func _shoot_from_range() -> bool:
	var r: float = ranged["range"]
	if position.y - radius < main.DEPLOY_TOP or (on_ground and not main.paths.melee_can_reach(position)):
		return false   # nowhere your troops could get at it: keep walking
	var mark = null
	var best := INF
	# A troop that stays out of its reach (holding its post, or healed as fast as it's
	# hit) would keep it shooting forever and the wave from ever ending: after a few
	# arrows that don't bring anyone to it, it leaves the troops be and pushes on.
	var troops: Array = [] if press_on > 0.0 else main.warriors_near(position, r + 40.0)
	for w in troops:
		if not w.is_active() or w.sheltered() or w.unmanned_tower():
			continue
		var d: float = position.distance_to(w.position) - w.RADIUS - radius
		if d <= r and d < best and not _wall_across(position, w.position):
			best = d
			mark = w
	var at_wall: bool = goal == null and position.y + radius >= main.CASTLE_Y - r and main.rules.has_castle()
	var at_goal: bool = goal != null and goal.kind != "zone" and goal.is_target() and position.distance_to(goal.position) - radius - goal.RADIUS <= r
	if mark == null and not at_wall and not at_goal:
		return false
	fighting = true
	if mark == null and at_goal:
		mark = goal   # shoots its objective (an EnemyShot hits whatever it was aimed at)
	var aim: Vector2 = mark.position if mark != null else Vector2(position.x, main.CASTLE_Y + 10.0)
	lunge_dir = position.direction_to(aim)
	if absf(lunge_dir.x) > 0.2:
		flip = signf(lunge_dir.x)
	if cd_timer <= 0.0:
		cd_timer = _attack_cd() / (main.hazards.rate_factor(kind) if main.gust > 0.0 else 1.0)   # (slower in a blizzard)
		lunge = 0.15
		shots += 1
		last_shot_from = position
		if ranged.has("pierce") and mark != null and mark != goal:
			# A Boltflinger's bolt: straight down the line, through whoever's in it.
			var bolt := EnemyBolt.new()
			bolt.main = main
			bolt.position = position + Vector2(8.0 * flip, -radius * 1.0)
			bolt.dir = bolt.position.direction_to(aim + Vector2(0, -6))
			bolt.speed = ranged["speed"]
			bolt.damage = damage * _hit_mult()
			bolt.pierce = int(ranged["pierce"])
			bolt.falloff = float(ranged.get("falloff", 0.0))
			bolt.left = r + 90.0
			main.add_projectile(bolt)
			main.sfx("lance", 1.3)
			idle_shots += 1
			if idle_shots >= PRESS_AFTER:
				idle_shots = 0
				press_on = PRESS_TIME
			return true
		if volley > 1 and mark != null and mark != goal:
			# A corrupted Archer's volley: more arrows, at others in reach.
			var others: Array = troops.filter(func(w): return w != mark and w.is_active() and not w.sheltered() and position.distance_to(w.position) - w.RADIUS - radius <= r)
			for k in mini(volley - 1, others.size()):
				_loose(others[k], others[k].position)
		var shot := EnemyShot.new()
		shot.style = shot_style
		shot.splash = shot_splash
		shot.goo = shot_goo
		shot.main = main
		shot.target = mark
		shot.target_pos = aim
		shot.position = position + Vector2(8.0 * flip, -radius * 1.2)
		shot.speed = ranged["speed"]
		shot.damage = (damage if mark != null else wall_damage) * _hit_mult()
		if mark != null and mark != goal:   # (a troop, not its objective)
			idle_shots += 1
			if idle_shots >= PRESS_AFTER:
				idle_shots = 0
				press_on = PRESS_TIME
		main.add_projectile(shot)
		main.sfx("bow", 0.8)
	return true


## A step to `to`: straight there on open ground; on terrain, slid along any rock it
## would have walked into.
func _step_to(to: Vector2) -> void:
	if on_ground:
		to = position + (to - position) * main.paths.wade_factor(position)   # (slow through a ford)
	position = main.paths.slide(position, to, radius) if on_ground else to


## Which way to head to reach `to`: straight at it, unless terrain is in the way; then
## along a route round it, worked out again every so often.
func _chase_dir(to: Vector2, delta: float) -> Vector2:
	if not on_ground:
		return position.direction_to(to)
	chase_check -= delta
	if chase_check <= 0.0 or to.distance_to(chase_goal) > 32.0:
		chase_check = 0.6
		chase_goal = to
		if main.paths.segment_blocked(position, to, radius):
			chase_route = main.paths.enemy_route(position, to, radius)
		else:
			chase_route = PackedVector2Array()
	while not chase_route.is_empty() and position.distance_to(chase_route[0]) < 10.0:
		chase_route.remove_at(0)
	if chase_route.is_empty():
		return position.direction_to(to)
	return position.direction_to(chase_route[0])


## Slime: the nearest of your troops (not emplacements or walls) it can get at.
func _nearest_troop():
	var best = null
	var best_d := SLIME_SEEK
	for w in main.get_warriors():
		if not w.is_active() or w.is_emplacement():
			continue
		var d: float = position.distance_to(w.position)
		if d < best_d and not _wall_across(position, w.position):
			best_d = d
			best = w
	return best


## Whether a hit of this school does nothing: only a Slime that isn't iced over
## shrugs off physical hits.
func resists(school: String) -> bool:
	return gooey and school == PHYSICAL and freeze_timer <= 0.0 and ice_crust <= 0.0


## Slime: iced over for a while, so blades and arrows bite.
func ice_over() -> void:
	if gooey:
		ice_crust = maxf(ice_crust, CRUST_TIME * cc_mult)


## At the castle, or close enough to it to be set on it: it doesn't turn aside for
## units attacking it any more.
func _set_on_castle() -> bool:
	if goal != null:
		if goal.kind == "zone" or goal.is_mover():
			return false   # it turns on whoever's hitting it on the way
		return position.distance_to(goal.position) - goal.RADIUS <= CASTLE_COMMIT * 0.6   # nearly at its objective
	return sieging or position.y >= main.CASTLE_Y - CASTLE_COMMIT


func _wall_across(a: Vector2, b: Vector2) -> bool:
	if not main.paths.sight_clear(a, b):
		return true   # (a castle's walls: no seeing through them)
	for wall in main.paths.walls:
		if Geometry2D.segment_intersects_segment(a, b, wall.seg_a(), wall.seg_b()) != null:
			return true
	return false


## Sapper's bomb: wrecks walls and hurts warriors nearby, and takes the Sapper with it
## (no bounty for an enemy that blew itself up).
func _explode() -> void:
	dead = true
	main.enemies_changed()
	var r: float = bomb["radius"]
	for b in main.get_barricades():
		if b.is_active() and b.gap_from(position) <= r:
			b.take_damage(bomb["wall"])
	for w in main.get_warriors():
		if w.is_active() and not w.sheltered() and position.distance_to(w.position) <= r + w.RADIUS:
			var was_up: bool = w.is_active()
			w.take_damage(bomb["wall"] if w.data.get("emplacement", false) else bomb["units"])   # (an emplacement takes it like a wall)
			if was_up and not w.is_active() and w.data.get("emplacement", false):
				main.sap_wrecks.append([w.kind, w.spent])   # (for the balance bots: what Sappers cost the player)
	if position.y + r * 0.5 >= main.CASTLE_Y:
		main.damage_castle(bomb["units"] * 2.0)   # the castle's walls are thicker than a barricade's
	for o in main.rules.objectives():
		if o.is_target() and position.distance_to(o.position) <= r + o.RADIUS:
			main.dmg_src = "sapper"
			o.take_damage(bomb["units"])   # (a workshop's walls are no castle's)
			main.dmg_src = ""
	main.spawn_flash(position, r * 0.7)
	main.spawn_burst(position, r, Color(1.0, 0.55, 0.2))
	main.spawn_burst(position, r * 0.55, Color(1.0, 0.9, 0.5))
	main.spawn_text(position + Vector2(0, -30), "BOOM!", Color(1, 0.55, 0.2))
	main.sfx("boom", 0.9)
	queue_free()


const CONFUSED_DAMAGE := 3.0   # confused enemies hit each other this much harder than they hit warriors


## Confused: wanders to the nearest other enemy and fights it.
func _confused(delta: float) -> void:
	var foe = null
	var best := 260.0
	for e in main.get_enemies():
		if e == self:
			continue
		var d: float = position.distance_to(e.position)
		if d < best:
			best = d
			foe = e
	if foe == null:
		return
	lunge_dir = position.direction_to(foe.position)
	if absf(lunge_dir.x) > 0.2:
		flip = signf(lunge_dir.x)
	if best - radius - foe.radius > REACH:
		if root_timer <= 0.0:
			_step_to(position + lunge_dir * speed * slow_factor * delta)
			bob += delta * 10.0
	elif cd_timer <= 0.0:
		cd_timer = attack_cd
		lunge = 0.15
		foe.take_damage(maxf(damage, 4.0) * CONFUSED_DAMAGE)


## The barricade to hack at: the one this enemy is up against when its route has
## to go through it, or one it has been pressed against without getting anywhere
## (a gap too tight to fit, or a crush of others). A stuck enemy hacks for a few
## seconds, then tries to get past again.
## A Sapper looks (every second) for the nearest of your emplacements in reach: a Tower,
## Cannoneer, Ballista, Obelisk, Medic Bay, Statue, Mine or a wall; it makes for that
## instead of the castle, and blows up against it.
func _sap_pick(delta: float) -> void:
	if sap_target != null and not _sap_valid(sap_target):
		sap_target = null
		sap_check = 0.0
	sap_check -= delta
	if sap_check > 0.0:
		return
	sap_check = 1.0
	var best = null
	var best_d := SAP_SEEK
	for w in main.warriors_near(position, SAP_SEEK):
		if _sap_valid(w):
			var d: float = _sap_gap(w)
			if d < best_d:
				best_d = d
				best = w
	for b in main.get_barricades():
		if _sap_valid(b):
			var d: float = _sap_gap(b)
			if d < best_d:
				best_d = d
				best = b
	if best != null and best != sap_target and main.has_method("sap_alert"):
		main.sap_alert(best)
	sap_target = best


## A Sapper's mark on what it's going for: a dotted line to it and a blinking red ring
## round it with a bomb sign, so the player sees which emplacement is in danger.
func _draw_sap_mark() -> void:
	if has_meta("title") and not dead:
		# A named enemy (a castle cell's Warden): its title over its head, with his keys.
		var y := -radius * 3.4 - 8.0
		var f := ThemeDB.fallback_font
		draw_string_outline(f, Vector2(-60, y), str(get_meta("title")), HORIZONTAL_ALIGNMENT_CENTER, 120, 13, 4, Color(0, 0, 0, 0.9))
		draw_string(f, Vector2(-60, y), str(get_meta("title")), HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(1.0, 0.75, 0.35))
		if has_meta("warden"):
			draw_circle(Vector2(0, y + 6), 3.0, Color(0.85, 0.7, 0.3))
			draw_line(Vector2(0, y + 9), Vector2(0, y + 15), Color(0.85, 0.7, 0.3), 2.0)
			draw_line(Vector2(0, y + 13), Vector2(3, y + 13), Color(0.85, 0.7, 0.3), 2.0)
	if bomb.is_empty() or dead:
		return
	if fuse >= 0.0:
		# The fuse burning down: a ring round it that empties as it goes.
		var left := clampf(fuse / PLANT, 0.0, 1.0)
		draw_arc(Vector2(0, -radius * 0.5), radius + 8.0, -PI / 2.0, -PI / 2.0 + TAU * left, 32, Color(1.0, 0.6, 0.2, 0.9), 3.0, true)
	if sap_target == null or not is_instance_valid(sap_target):
		return
	var to: Vector2 = _sap_point(sap_target) - position
	var t := Time.get_ticks_msec() / 1000.0
	var k := 0.55 + 0.45 * sin(t * 8.0)
	var red := Color(1.0, 0.25, 0.15, 0.75 * k)
	var n := int(to.length() / 14.0)
	for i in n:
		if i % 2 == 0:
			draw_line(to * (float(i) / n), to * (float(i + 1) / n), Color(1.0, 0.35, 0.2, 0.45), 2.0)
	var r: float = 18.0 if sap_target is BarricadeScript else sap_target.RADIUS + 10.0
	draw_arc(to, r, 0.0, TAU, 32, red, 2.5, true)
	for a in 4:
		var d := Vector2.from_angle(a * PI / 2.0 + PI / 4.0)
		draw_line(to + d * (r - 5.0), to + d * (r + 6.0), red, 2.5)
	# The bomb sign over it.
	var b := to + Vector2(0, -r - 12.0)
	draw_circle(b, 6.0, Color(0.12, 0.1, 0.1, 0.9 * k + 0.1))
	draw_line(b + Vector2(3, -4), b + Vector2(6, -9), Color(0.85, 0.7, 0.4, 0.9), 1.5)
	draw_circle(b + Vector2(6.5, -10), 2.2, Color(1.0, 0.7, 0.2, k))


func _sap_valid(o) -> bool:
	if not is_instance_valid(o) or o.is_queued_for_deletion() or not o.is_active():
		return false
	if o is BarricadeScript:
		return true
	return o.data.get("emplacement", false) and not o.unmanned_tower()


## How far it is from the Sapper's reach (0: it's there).
func _sap_gap(o) -> float:
	if o is BarricadeScript:
		return o.gap_from(position) - radius
	return position.distance_to(o.position) - radius - o.RADIUS


## Where the Sapper heads to get at it: the emplacement, or the nearest point of the wall.
func _sap_point(o) -> Vector2:
	if o is BarricadeScript:
		return Geometry2D.get_closest_point_to_segment(position, o.seg_a(), o.seg_b())
	return o.position


func _wall_to_break(delta: float):
	var touching = main.barricade_touching(position, radius + REACH)
	if touching == null:
		wall_target = null
		stuck_time = 0.0
		return null
	if main.paths.breach_at(position, radius) == touching:
		wall_target = touching
		return touching
	if touching == wall_target and wall_commit > 0.0:
		wall_commit -= delta
		return touching
	wall_target = null
	stuck_time += delta
	if stuck_time >= 1.0:
		var moved := position.distance_to(stuck_check)
		stuck_check = position
		stuck_time = 0.0
		if moved < 10.0 and root_timer <= 0.0 and slow_factor > 0.3:
			wall_target = touching
			wall_commit = 3.0
			return touching
	return null


func _find_blocker():
	var best = null
	var best_d := INF
	for w in main.warriors_near(position, radius + REACH + 24.0):
		if not w.is_active() or w.sheltered() or w.unmanned_tower():
			continue
		var d: float = position.distance_to(w.position) - radius - w.RADIUS
		if d <= REACH and d < best_d:
			best_d = d
			best = w
	return best


# Keep enemies from overlapping each other or walking through warriors.
## Flyers only bump into other flyers.
func _push_out() -> void:
	if not flying and not boss:   # nothing shoves the Ogre King around; others make way
		for w in main.warriors_near(position, radius + 24.0):
			if w.is_active() and not w.sheltered():
				_push_from(w.position, radius + w.RADIUS, 1.0)
	if not boss:
		var in_gap: bool = on_ground and main.paths.tight(position, radius)   # once, not once per neighbour
		for e in main.enemies_near(position, radius + main.MAX_ENEMY_RADIUS):
			if e != self and e.flying == flying:
				if in_gap and walking and e.walking and e.position.y < position.y - 2.0 and not e.boss:
					continue   # in a gap, whoever's ahead and still walking goes first: the ones behind don't shove it into the rock (one that's stopped makes way)
				_push_from(e.position, radius + e.radius, 1.0 if e.boss else 0.5)
	position.x = clampf(position.x, radius, main.FIELD_W - radius)
	if flying:
		return
	if on_ground:
		position = main.paths.push_out(position, radius)   # the safety net: never left inside rock
	# Walls are solid: step straight back out of them, last so nothing pushes it back in.
	for b in main.get_barricades():
		if not b.is_active():
			continue
		var c := Geometry2D.get_closest_point_to_segment(position, b.seg_a(), b.seg_b())
		var min_d: float = radius + b.WALL_HALF
		var off := position - c
		var d := off.length()
		if d < min_d:
			if d < 0.01:
				off = Vector2.UP
				d = 1.0
			position = c + off / d * min_d
	position.x = clampf(position.x, radius, main.FIELD_W - radius)


func _push_from(p: Vector2, min_d: float, share: float) -> void:
	var off := position - p
	var d := off.length()
	if d >= min_d:
		return
	if d < 0.01:
		off = Vector2(randf_range(-1, 1), -0.1)
		d = off.length()
	# Bias sideways so blocked enemies flow around obstacles instead of stalling.
	var away := off / d
	if absf(away.x) < 0.3:
		away.x = 0.3 if away.x >= 0.0 else -0.3
	position += away.normalized() * (min_d - d) * share


func take_damage(amount: float, show_hit := true, school := PHYSICAL) -> void:
	if dead:
		return
	idle_shots = 0   # (being hit back: it isn't shooting at nothing)
	if amount > 0.0:
		unhurt = 0.0   # (a Troll's wounds stop closing)
	var cut := _shield_cut() if main.hit_from != Vector2.INF else 0.0
	if cut > 0.0:
		amount *= 1.0 - cut
		if show_hit and block_note <= 0.0:
			block_note = 0.6
			main.spawn_text(position + Vector2(0, -30), "Blocked", Color(0.8, 0.85, 0.95))
			main.sfx("hit", 1.7)
	if not banner.is_empty():
		recent_hurt += amount   # (a hard enough beating knocks his banner down)
	if gooey:
		if resists(school):
			if show_hit and absorb_note <= 0.0:
				absorb_note = 0.8
				main.spawn_text(position + Vector2(0, -30), "Absorbed!", Color(0.55, 0.95, 0.5))
			return
		if school == ICE:
			amount *= ICE_BONUS
			ice_over()
	if main.campaign:
		main.earn_xp(main.credit, minf(maxf(hp - hp_floor, 0.0), amount * (1.0 + vuln + corrode + (confuse_vuln if confuse_timer > 0.0 else 0.0))))
	hp -= amount * (1.0 + vuln + corrode + (confuse_vuln if confuse_timer > 0.0 else 0.0))
	if show_hit:
		flash = 0.08
	if hp_floor > 0.0 and hp < hp_floor:
		hp = hp_floor
		if not has_meta("floored"):
			set_meta("floored", true)
			if main.rules.has_method("floor_reached"):
				main.rules.floor_reached(self)
	if hp <= 0.0 and has_meta("undying"):
		# Beaten, but this one isn't killed by it: the battle decides what happens (see the
		# rules' boss_beaten).
		hp = 1.0
		if not has_meta("beaten"):
			set_meta("beaten", true)
			main.rules.boss_beaten(self)
		return
	if hp <= 0.0:
		dead = true
		died.emit(self)
		queue_free()


## Burning keeps the strongest burn and refreshes its duration.
func apply_burn(dps: float, duration: float) -> void:
	if burn_timer <= 0.0 or dps >= burn_dps:
		burn_credit = main.credit
	if burn_timer <= 0.0:
		burn_dps = 0.0
	burn_dps = maxf(burn_dps, dps)
	burn_timer = maxf(burn_timer, duration)


## Each dose adds a stack (up to max_stacks) to the poison from that Alchemist.
## Poisons from different Alchemists don't add up: only the worst one hurts.
func apply_poison(dps: float, duration: float, max_stacks: int, source: int) -> void:
	poison_credit = main.credit
	var dose: Array = poisons.get(source, [dps, 0, 0.0])
	dose[0] = maxf(dose[0], dps)
	dose[1] = mini(dose[1] + 1, maxi(max_stacks, dose[1]))
	dose[2] = maxf(dose[2], duration)
	poisons[source] = dose


func apply_corrode(amount: float, duration: float) -> void:
	corrode = maxf(corrode if corrode_timer > 0.0 else 0.0, amount)
	corrode_timer = maxf(corrode_timer, duration)


func apply_stun(duration: float) -> void:
	duration *= cc_mult
	stun_timer = maxf(stun_timer, duration)


## Pushes the enemy along `push` (its length is the distance) over a fifth of a second.
func apply_knockback(push: Vector2) -> void:
	if knock_mult <= 0.0:
		return   # immune: not even a stagger
	push *= knock_mult
	knock_timer = 0.2
	knock_velocity = push / knock_timer


func apply_freeze(duration: float) -> void:
	duration *= cc_mult
	freeze_timer = maxf(freeze_timer, duration)
	ice_over()


## Bard Discord song: refreshed while the enemy stays in earshot.
func apply_discord(v: float, w: float, slow: float, duration: float) -> void:
	vuln = maxf(vuln, v)
	weaken = maxf(weaken, w)
	discord_slow = maxf(discord_slow, slow)
	discord_timer = maxf(discord_timer, duration)


func apply_root(duration: float) -> void:
	duration *= cc_mult
	root_timer = maxf(root_timer, duration)


func apply_confuse(duration: float, extra_vuln := 0.0) -> void:
	duration *= cc_mult
	if confuse_timer <= 0.0:
		confuse_vuln = 0.0
	confuse_vuln = maxf(confuse_vuln, extra_vuln)
	confuse_timer = maxf(confuse_timer, duration)


## Necromancy rot: the strongest rot counts, and it remembers whose it is.
func apply_decay(dps: float, duration: float, source: int) -> void:
	if decay_timer <= 0.0 or dps >= decay_dps:
		decay_dps = dps
		decay_source = source
		decay_credit = main.credit
	decay_timer = maxf(decay_timer, duration)


## Thornwild: thorny plants and vines.
func apply_thorns(dps: float, duration: float) -> void:
	thorn_credit = main.credit
	if thorn_timer <= 0.0:
		thorn_dps = 0.0
	thorn_dps = maxf(thorn_dps, dps)
	thorn_timer = maxf(thorn_timer, duration)


## Struck by lightning: a Storm mage's magnetizing blasts can pull it in.
func charge(duration: float) -> void:
	charged_timer = maxf(charged_timer, duration)


func apply_slow(strength: float, duration: float) -> void:
	slow_factor = minf(slow_factor, 1.0 - strength)
	slow_timer = maxf(slow_timer, duration)


## Turns the drawn facing round to flip, once flip has held for a moment: a path that
## wobbles left and right doesn't make it twitch back and forth.
func _turn_toward(delta: float) -> void:
	if flip == 0.0 or signf(turn) == flip and absf(turn) >= 1.0:
		turn_hold = 0.0
		return
	if signf(turn) != flip:
		turn_hold += delta
		if turn_hold < 0.12:
			return
	turn = move_toward(turn, flip, delta * 11.0)


## The walk, by kind: [offset, tilt, scale] this frame. One step per walk frame.
func _gait() -> Array:
	var ph := bob * PI / 2.5
	var s := sin(ph)
	var up := absf(s)                       # 0 on a footfall, 1 mid-stride
	var k := minf(1.0, 3.0 / sprite_scale)  # big ones bounce less (in sprite pixels)
	# On two feet (Sprites.step): planted on even frames, a foot up on odd ones, rocking
	# over onto the planted foot step by step.
	var pace := 0.5 - 0.5 * cos(PI * (bob / 2.5 - 0.5))
	var side := sin(ph * 0.5)
	match look:
		"slime":
			# Hops: squashed flat on the ground (its squashed frame: see _draw), springing
			# up tall, landing flat again.
			return [Vector2(0, -5.0 * up * k), 0.0, Vector2(1.0 - 0.08 * up, 1.0 + 0.12 * up)]
		"wolf":
			# A gallop: rocking nose-down, tail-down, stretching out with each bound.
			return [Vector2(0, -3.0 * up * k), cos(ph) * 0.13, Vector2(1.0 + 0.06 * up, 1.0 - 0.04 * up)]
		"troll", "ogre_king", "warlord", "ash_marshal", "orc", "ogre":
			# A heavy tread: rolling from foot to foot, sinking into each footfall.
			return [Vector2(0, -1.5 * pace * k), side * 0.09, Vector2(1.0 + 0.05 * (1.0 - pace), 1.0 - 0.05 * (1.0 - pace))]
		"skeleton", "skeleton_archer":
			# A clattering shamble, bones rattling.
			return [Vector2(sin(bob * 9.0) * 0.7, -2.0 * pace * k), side * 0.05 + sin(bob * 7.0) * 0.03, Vector2.ONE]
		"goblin", "sapper", "shieldbearer", "drummer", "boltflinger", "warmage", "gravebinder":
			# A scurry: quick, hunched, bouncing high.
			return [Vector2(0, -3.2 * pace * k), side * 0.11, Vector2(1.0 + 0.04 * (1.0 - pace), 1.0 - 0.06 * (1.0 - pace))]
	return [Vector2(0, -2.5 * pace * k), side * 0.06, Vector2.ONE]


func _draw() -> void:
	_draw_sap_mark()
	if stomp_wind > 0.0:
		# The slam's warning: its reach on the ground, filling as it comes.
		var r: float = stomp["radius"]
		var k: float = 1.0 - stomp_wind / STOMP_WARN
		var foot := Vector2(0, radius * 0.6)
		draw_set_transform(foot, 0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.25, 0.15, 0.12 + 0.12 * k))
		draw_circle(Vector2.ZERO, r * k, Color(1.0, 0.35, 0.2, 0.22))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.3, 0.2, 0.9), 3.0, true)
		draw_set_transform(Vector2.ZERO)
	var tint := Color.WHITE
	if corrupted:
		tint = Color(0.7, 1.05, 0.75)   # (a deathly green cast)
	if slow_timer > 0.0 or freeze_timer > 0.0 or ice_crust > 0.0:
		tint = Color(0.6, 0.85, 1.3)
	if flash > 0.0:
		tint = Color(3, 3, 3)
	if aura.a > 0.0:
		# His aura: the corrupted beacon's fire, pulsing round him.
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 160.0)
		draw_set_transform(Vector2(0, radius * 0.4), 0, Vector2(1.0, 0.6))
		draw_circle(Vector2.ZERO, radius * 2.2, Color(aura, aura.a * 0.35 * pulse))
		draw_circle(Vector2.ZERO, radius * 1.5, Color(aura, aura.a * 0.5 * pulse))
		draw_set_transform(Vector2.ZERO)
	if charge_warn > 0.0:
		# The charge coming: its line along the ground.
		var to := charge_dir * float(rush.get("range", 200.0))
		draw_line(Vector2(0, radius * 0.5), to + Vector2(0, radius * 0.5), Color(1.0, 0.25, 0.15, 0.35), radius * 1.6)
		draw_line(Vector2(0, radius * 0.5), to + Vector2(0, radius * 0.5), Color(1.0, 0.4, 0.25, 0.9), 2.0)
	if slam_wind > 0.0:
		# The blow coming: the arc it'll sweep, on the ground in front of it, filling.
		var k: float = 1.0 - slam_wind / float(slam["windup"])
		var reach: float = slam["reach"] + radius
		var a0 := lunge_dir.angle() - float(slam["arc"]) / 2.0
		var pts := PackedVector2Array([Vector2(0, radius * 0.5)])
		for i in 13:
			pts.append(Vector2(0, radius * 0.5) + Vector2.from_angle(a0 + float(slam["arc"]) * i / 12.0) * Vector2(reach, reach * 0.6))
		draw_colored_polygon(pts, Color(1.0, 0.3, 0.15, 0.2 + 0.2 * k))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1.0, 0.35, 0.2, 0.6 + 0.4 * k), 3.0, true)
	if strafe_warn > 0.0:
		# The Wyvern's run: the line it'll swoop down, fire glowing along it.
		var a := strafe_from - position
		var b := strafe_to - position
		var k := 1.0 - strafe_warn / float(strafe["warn"])
		draw_line(a, b, Color(1.0, 0.4, 0.1, 0.12 + 0.15 * k), float(strafe["width"]) * 2.0)
		draw_line(a, a + (b - a) * k, Color(1.0, 0.6, 0.2, 0.8), 2.5)
	if fuse >= 0.0 and not bomb.is_empty():
		# The bomb lit: how far the blast will reach, closing in as the fuse burns down.
		var whole: float = PLANT if fuse > FUSE else FUSE
		var k := clampf(1.0 - fuse / whole, 0.0, 1.0)
		var r: float = bomb["radius"]
		draw_set_transform(Vector2(0, radius * 0.6), 0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.3, 0.1, 0.08 + 0.12 * k))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1.0, 0.35, 0.15, 0.6 + 0.4 * k), 2.0, true)
		draw_arc(Vector2.ZERO, r * (1.0 - k), 0.0, TAU, 40, Color(1.0, 0.8, 0.3, 0.8), 1.5, true)
		draw_set_transform(Vector2.ZERO)
	if exposed > 0.0:
		var f := ThemeDB.fallback_font
		draw_string_outline(f, Vector2(-60, -radius * 3.6 - 22), "EXPOSED!", HORIZONTAL_ALIGNMENT_CENTER, 120, 14, 4, Color(0, 0, 0, 0.9))
		draw_string(f, Vector2(-60, -radius * 3.6 - 22), "EXPOSED!", HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(1.0, 0.9, 0.4))
	if corrupted:
		# Corrupted: a sickly shadow of necromancy round its feet, wisps rising off it.
		var t := life_t
		draw_set_transform(Vector2(0, radius * 0.7), 0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, radius * 1.6, Color(0.35, 0.9, 0.45, 0.18 + 0.06 * sin(t * 4.0)))
		draw_set_transform(Vector2.ZERO)
	if rite != null:
		# The rite: a wavering tether of green fire from its staff to the body, and the
		# fallen troop's ghost rising there, plainer as the rite goes on.
		var k := 1.0 - rite_left / rite_total
		var a := Vector2(14.0 * flip, -radius * 2.6)
		var b: Vector2 = rite["at"] - position + Vector2(0, -8)
		var prev := a
		for i in range(1, 13):
			var f := float(i) / 12.0
			var p := a.lerp(b, f) + Vector2(0, sin(f * 9.0 + life_t * 10.0) * 5.0 * sin(f * PI))
			draw_line(prev, p, Color(0.45, 1.0, 0.5, 0.85), 2.5, true)
			prev = p
		var ghost: Texture2D = (rite["frames"] as Array)[0]
		var gs := Vector2(Sprites.SIZE, Sprites.SIZE) * 3.0
		var rise := b + Vector2(0, 8.0 - 10.0 * k)
		draw_texture_rect(ghost, Rect2(rise - Vector2(gs.x / 2, gs.y), gs), false, Color(0.5, 1.0, 0.6, 0.15 + 0.6 * k))
		draw_set_transform(b + Vector2(0, 10), 0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, 26.0, -PI / 2.0, -PI / 2.0 + TAU * k, 32, Color(0.5, 1.0, 0.55, 0.9), 3.0, true)
		draw_set_transform(Vector2.ZERO)
	var frames: Array = frames_override if not frames_override.is_empty() else Sprites.frames(look)
	var size := Vector2(Sprites.SIZE, Sprites.SIZE) * sprite_scale
	var feet := radius
	# Shadow, sprite and health bar all come from the sprite atlas, so the renderer can
	# batch every enemy on the field together.
	var sr := radius * (0.8 if flying else 1.1)
	draw_texture_rect(Sprites.shadow(), Rect2(-sr, feet - sr * 0.35, sr * 2.0, sr * 0.7), false, Color(0, 0, 0, 0.22 if flying else 0.3))
	if flying:
		feet -= FLY_HEIGHT + sin(bob * 0.3) * 3.0   # everything else is drawn up in the air
	if fuse >= 0.0 and int(fuse * 12.0) % 2 == 0:
		tint = Color(3, 1.2, 0.6)   # a lit bomb blinks
	var frame := int(bob / 2.5) % 2
	var body_tex: Texture2D = Sprites.step(frames, int(bob / 2.5)) if walking and not flying else frames[frame]
	if kind == "slime" and walking:
		body_tex = frames[1] if absf(sin(bob * PI / 2.5)) < 0.35 else frames[0]   # squashed on the ground, round in the air
	# Attacking: the weapon hauled back as the blow comes, then brought down as it lands.
	var attack := ""
	if lunge > 0.0:
		attack = "strike"
	elif slam_wind > 0.0 or fighting and cd_timer < 0.3:
		attack = "raise"
	if attack != "" and frames_override.is_empty():
		var posed = Sprites.pose(look, attack)
		if posed != null:
			body_tex = posed
	var nudge := lunge_dir * (lunge / 0.15) * 6.0
	# Body motion: a waddling hop while walking, rearing back before a blow, and a
	# squash when hit. Pivots on the feet.
	var rot := 0.0
	var sc := Vector2.ONE
	if walking and not flying:
		var g := _gait()
		nudge += g[0]
		rot = g[1]
		sc = g[2]
	elif flying:
		# Wings beating: a little lift on each downstroke, swooping side to side.
		sc = Vector2(1.0, 1.0 + 0.05 * sin(bob * PI / 2.5))
		rot = sin(bob * 0.15) * 0.08
	else:
		sc = Vector2(1.0 - 0.012 * sin(life_t * 3.0 + drift), 1.0 + 0.022 * sin(life_t * 3.0 + drift))   # breathing hard
	if slam_wind > 0.0:
		var k := 1.0 - slam_wind / float(slam["windup"])   # (rearing right back for it)
		nudge -= lunge_dir * 7.0 * k
		rot -= 0.2 * k * signf(lunge_dir.x)
		sc = Vector2(1.0 - 0.05 * k, 1.0 + 0.08 * k)
	elif fighting and cd_timer < 0.3 and lunge <= 0.0:
		var k := 1.0 - cd_timer / 0.3
		nudge -= lunge_dir * 4.0 * k
		rot -= 0.12 * k * signf(lunge_dir.x)
		sc = Vector2(1.0 - 0.04 * k, 1.0 + 0.06 * k)
	if lunge > 0.0:
		sc = Vector2(1.1, 0.92)
	if flash > 0.0:
		sc = Vector2(1.12, 0.88)
		nudge -= lunge_dir * 2.0 * flash / 0.08   # rocked back by the blow
	var fx := signf(turn if turn != 0.0 else flip) * maxf(absf(turn), 0.5)   # squeezed thin mid-turn
	draw_set_transform(Vector2(0, feet) + nudge, rot, Vector2(fx * sc.x, sc.y))
	draw_texture_rect(body_tex, Rect2(Vector2(-size.x / 2, -size.y), Vector2(body_tex.get_width() * sprite_scale, size.y)), false, tint)   # (a wide pose reaches forward)
	if ice_crust > 0.0 and freeze_timer <= 0.0:
		# Iced over: a frosty glaze and a rim of ice.
		var glaze := Rect2(Vector2(-size.x / 2, -size.y) + Vector2(size.x * 0.1, size.y * 0.45), size * Vector2(0.8, 0.55))
		draw_texture_rect(Sprites.white(), glaze, false, Color(0.8, 0.95, 1.0, 0.3 * minf(ice_crust / 0.5, 1.0)))
		draw_rect(glaze, Color(0.9, 0.97, 1.0, 0.7 * minf(ice_crust / 0.5, 1.0)), false, 1.5)
	if freeze_timer > 0.0:
		var ice := Rect2(Vector2(-size.x / 2, -size.y) + Vector2(size.x * 0.15, size.y * 0.1), size * Vector2(0.7, 0.9))
		draw_texture_rect(Sprites.white(), ice, false, Color(0.75, 0.92, 1.0, 0.45))
		draw_rect(ice, Color(0.9, 0.97, 1.0, 0.9), false, 2.0)
	draw_set_transform(Vector2.ZERO)
	if not banner.is_empty():
		_draw_banner(feet, size)
	if gooey and ice_crust <= 0.0 and freeze_timer <= 0.0:
		# Its slick hide: a glint sliding over it (blades and arrows slide off; ice it first).
		var t := fmod(life_t * 0.6 + drift, 1.0)
		var gx := (-0.35 + 0.7 * t) * size.x
		draw_line(Vector2(gx - 3, feet - size.y * 0.62), Vector2(gx + 3, feet - size.y * 0.7), Color(1, 1, 1, 0.75 * sin(t * PI)), 2.0, true)
	elif gooey and ice_crust > 0.0:
		# Crystallized: hard facets of ice over it (now anything bites).
		var a := minf(ice_crust / 0.5, 1.0)
		var c := Vector2(0, feet - size.y * 0.45)
		for i in 5:
			var ang := -PI * 0.9 + i * PI * 0.45
			draw_line(c, c + Vector2.from_angle(ang) * Vector2(size.x * 0.32, size.y * 0.28), Color(0.95, 1.0, 1.0, 0.8 * a), 1.5, true)
	if not pack.is_empty() and pack_n > 0 and not flying:
		# Bold in a pack: a war-paint pip over its head for each of its own beside it.
		for i in pack_n:
			draw_texture_rect(Sprites.white(), Rect2(Vector2(-pack_n * 3.0 + i * 6.0, feet - size.y - 9.0), Vector2(4, 4)), false, Color(0.95, 0.3, 0.2, 0.9))
	elif not pack.is_empty() and float(pack["alone"]) > 0.0 and walking:
		# On its own: a bead of sweat, looking about for the others.
		var dp := Vector2(radius * 0.7, feet - size.y * 0.8 + fmod(life_t * 8.0, 4.0))
		Sprites.disc(self, dp, 2.0, Color(0.6, 0.85, 1.0, 0.9))
	if mending:
		# Wounds closing: green crosses rising off it.
		for i in 2:
			var k2 := fmod(life_t * 0.8 + i * 0.5, 1.0)
			var p2 := Vector2((-0.4 + 0.8 * i) * radius, feet - size.y * (0.4 + 0.5 * k2))
			var col := Color(0.4, 1.0, 0.45, 0.9 * (1.0 - k2))
			draw_texture_rect(Sprites.white(), Rect2(p2 - Vector2(3, 1), Vector2(6, 2)), false, col)
			draw_texture_rect(Sprites.white(), Rect2(p2 - Vector2(1, 3), Vector2(2, 6)), false, col)
	if cast_state == "charge":
		# Charging: its spell's colour gathering at the staff's head, a ring of it on the ground.
		var col: Color = SPELL_COLORS[cast_spell]
		var k := 1.0 - cast_left / float(cast["charge"])
		var orb := Vector2(size.x * 0.4 * flip, feet - size.y * 0.95)
		var pulse := 0.8 + 0.2 * sin(life_t * 20.0)
		Sprites.disc(self, orb, 3.0 + 6.0 * k * pulse, Color(col, 0.35))
		Sprites.disc(self, orb, 2.0 + 3.5 * k, col)
		for i in 3:
			var a := life_t * 6.0 + i * TAU / 3.0
			var p := orb + Vector2.from_angle(a) * (14.0 - 9.0 * k)
			Sprites.disc(self, p, 1.5, Color(col, 0.8))
		draw_set_transform(Vector2(0, radius * 0.6), 0, Vector2(1.0, 0.55))
		draw_arc(Vector2.ZERO, radius * 1.6, -PI / 2.0, -PI / 2.0 + TAU * k, 32, Color(col, 0.85), 2.5, true)
		draw_set_transform(Vector2.ZERO)
	if cast_state == "flame":
		# The stream of fire: a cone out from the staff, flames racing along it.
		var sp: Dictionary = cast["fire"]
		var reach: float = sp["range"]
		var arc: float = sp["arc"]
		var o := Vector2(8.0 * flip, -radius)
		var pts := PackedVector2Array([o])
		for i in 9:
			pts.append(o + Vector2.from_angle(flame_dir.angle() - arc + arc * 2.0 * i / 8.0) * reach)
		draw_colored_polygon(pts, Color(1.0, 0.45, 0.1, 0.22))
		for i in 10:
			var k2 := fmod(life_t * 2.5 + i * 0.1, 1.0)
			var a2 := flame_dir.angle() + sin(i * 2.3 + life_t * 7.0) * arc * 0.8 * k2
			var p2 := o + Vector2.from_angle(a2) * reach * k2
			Sprites.disc(self, p2, 3.0 + 6.0 * k2, Color(1.0, 0.55 + 0.35 * (1.0 - k2), 0.15, 0.75 * (1.0 - k2 * 0.6)))
	if driven > 0.0:
		# Driven on by a drum: a yellow chevron over its head, bobbing to the beat.
		var cy := feet - size.y - 6.0 + sin(life_t * 12.0) * 1.5
		draw_polyline(PackedVector2Array([Vector2(-4, cy), Vector2(0, cy - 4), Vector2(4, cy)]), Color(1.0, 0.85, 0.3, 0.95), 2.0)
	if not drum.is_empty():
		# The drumsticks: raised, then brought down on the drum with each beat.
		var down := drum_beat > 0.15
		for sgn in [-1.0, 1.0]:
			var hand := Vector2(sgn * size.x * 0.3, feet - size.y * 0.38)
			var tip := hand + (Vector2(sgn * 2.0, 6.0) if down else Vector2(sgn * 5.0, -9.0 + sin(life_t * 6.0 + sgn) * 2.0))
			draw_line(hand, tip, Color(0.4, 0.26, 0.12), 2.0, true)
			Sprites.disc(self, tip, 1.8, Color(0.9, 0.84, 0.7))
		if drum_beat > 0.0:
			# The beat going out over the horde round it.
			var k := 1.0 - drum_beat / 0.3
			draw_set_transform(Vector2(0, radius * 0.6), 0, Vector2(1.0, 0.55))
			draw_arc(Vector2.ZERO, float(drum["radius"]) * k, 0.0, TAU, 40, Color(1.0, 0.8, 0.3, 0.6 * (1.0 - k)), 3.0, true)
			draw_set_transform(Vector2.ZERO)
	if ranged.has("pierce") and fighting and cd_timer > 0.3:
		# Winding the crossbow back: a crank turning at its side.
		var c := Vector2(-size.x * 0.25 * flip, feet - size.y * 0.3)
		var a := life_t * 9.0
		draw_line(c, c + Vector2.from_angle(a) * 5.0, Color(0.75, 0.78, 0.85), 2.0, true)
		draw_arc(c, 5.0, 0.0, TAU * (1.0 - cd_timer / _attack_cd()), 14, Color(1.0, 0.9, 0.5, 0.7), 1.0)
	if not shield.is_empty() and escort != null and is_instance_valid(escort):
		# Covering one of its own: a faint line of its shield's shelter behind it.
		draw_line(Vector2.ZERO, escort.position - position, Color(0.7, 0.8, 0.95, 0.18), 6.0)
	if rally > 0.0 and not boss:
		# Driven on by the Marshal's banner: an ember over the head.
		var e := Vector2(0, feet - size.y - 4.0 + sin(bob) * 1.5)
		draw_rect(Rect2(e - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.5, 0.15, 0.9))
	if stun_timer > 0.0:
		# Dazed: little stars circling the head.
		var spin := Time.get_ticks_msec() / 200.0
		var head := Vector2(0, feet - size.y * 0.9)
		for i in 3:
			var p := head + Vector2.from_angle(spin + i * TAU / 3.0) * Vector2(radius * 0.8, 4.0)
			draw_rect(Rect2(p - Vector2(2.5, 2.5), Vector2(5, 5)), Color(1, 0.95, 0.4))
	if root_timer > 0.0:
		# Vines wrapped around the feet.
		for i in 4:
			var x := (-0.75 + i * 0.5) * radius
			var sway := sin(Time.get_ticks_msec() / 150.0 + i) * 2.0
			draw_line(Vector2(x, feet + 2), Vector2(x + sway, feet - size.y * 0.35), Color(0.2, 0.55, 0.15), 3.0, true)
			Sprites.disc(self, Vector2(x + sway, feet - size.y * 0.35), 2.5, Color(0.35, 0.75, 0.25))
	if confuse_timer > 0.0:
		# Confused: a spinning purple "?" over the head.
		var bob_y := sin(Time.get_ticks_msec() / 120.0) * 2.0
		var head := Vector2(-5, feet - size.y - 6 + bob_y)
		draw_string_outline(ThemeDB.fallback_font, head, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 3, Color.BLACK)
		draw_string(ThemeDB.fallback_font, head, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.85, 0.5, 1.0))
	if discord_timer > 0.0:
		# Unsettled by a Bard's discord: a dark purple note bobbing beside the head.
		var n := Vector2(radius * 0.9, feet - size.y * 0.85 + sin(Time.get_ticks_msec() / 200.0) * 2.0)
		Sprites.disc(self, n, 2.5, Color(0.55, 0.25, 0.7))
		draw_line(n + Vector2(2, 0), n + Vector2(2, -8), Color(0.55, 0.25, 0.7), 1.5, true)
	if not poisons.is_empty():
		# Poisoned: green bubbles rising off the body, more with each stack.
		var t := Time.get_ticks_msec() / 1000.0
		for i in mini(poison_stacks, 4) + 1:
			var k := fmod(t * 0.9 + i * 0.27 + bob * 0.01, 1.0)
			var x := sin(i * 2.1 + drift) * radius * 0.6
			Sprites.disc(self, Vector2(x, feet - size.y * (0.35 + 0.5 * k)), 1.5 + k * 1.5, Color(0.55, 1.0, 0.3, 0.9 * (1.0 - k)))
	if corrode_timer > 0.0:
		# Acid-burned: yellow-green drips down the body.
		for i in 3:
			var x := (-0.6 + i * 0.6) * radius
			var drip := fmod(Time.get_ticks_msec() / 400.0 + i * 0.4, 1.0) * 6.0
			draw_rect(Rect2(Vector2(x - 1.5, feet - size.y * 0.55 + drip), Vector2(3, 4)), Color(0.85, 0.95, 0.2, 0.85))
	if decay_timer > 0.0:
		# Rotting: sickly green wisps curling up off the body.
		var t := Time.get_ticks_msec() / 1000.0
		for i in 3:
			var k := fmod(t * 0.7 + i * 0.33, 1.0)
			var x := sin(t * 3.0 + i * 2.0) * radius * 0.5
			Sprites.disc(self, Vector2(x, feet - size.y * (0.3 + 0.6 * k)), 2.5 - k, Color(0.5, 0.9, 0.35, 0.8 * (1.0 - k)))
			Sprites.disc(self, Vector2(x + 2, feet - size.y * (0.3 + 0.6 * k) + 2), 1.5, Color(0.35, 0.2, 0.4, 0.7 * (1.0 - k)))
	if thorn_timer > 0.0:
		# Thorny briars wound round the legs.
		for i in 3:
			var x := (-0.6 + i * 0.6) * radius
			var y := feet - size.y * 0.2
			draw_line(Vector2(x - 4, y + 3), Vector2(x + 4, y - 3), Color(0.35, 0.25, 0.1), 2.0, true)
			draw_line(Vector2(x, y), Vector2(x + 2, y - 4), Color(0.6, 0.15, 0.15), 1.5, true)
	if charged_timer > 0.0 and int(Time.get_ticks_msec() / 80) % 3 != 0:
		# Charged: little blue sparks crackling over it.
		var t := Time.get_ticks_msec() / 80
		for i in 2:
			var p := Vector2(sin(t * 1.7 + i * 3.0) * radius * 0.7, feet - size.y * (0.4 + 0.3 * sin(t + i)))
			draw_line(p, p + Vector2(3, -3), Color(0.6, 0.85, 1.0), 1.5)
			draw_line(p + Vector2(3, -3), p + Vector2(1, -6), Color(0.85, 0.95, 1.0), 1.5)
	if burn_timer > 0.0:
		# Flickering pixel flames on the body.
		var t := Time.get_ticks_msec() / 90
		for i in 3:
			var x := (-0.5 + i * 0.5) * radius
			var h := 4.0 + float((t + i * 7) % 4) * 2.0
			var base := Vector2(x, feet - size.y * 0.45)
			draw_rect(Rect2(base + Vector2(-3, -h), Vector2(6, h)), Color(1.0, 0.45, 0.1, 0.85))
			draw_rect(Rect2(base + Vector2(-1.5, -h * 0.6), Vector2(3, h * 0.6)), Color(1.0, 0.9, 0.3, 0.9))
	if hp < max_hp:
		var w := radius * 2.0
		var top := Vector2(-radius, feet - size.y - 2)
		var bar := Sprites.white()
		draw_texture_rect(bar, Rect2(top, Vector2(w, 4)), false, Color(0, 0, 0, 0.6))
		draw_texture_rect(bar, Rect2(top, Vector2(w * hp / max_hp, 4)), false, Color(0.3, 0.95, 0.3))
