extends Node2D
## Game controller. main.gd holds the battle's shared state (what several parts of the game
## read and change: gold, the wave, the castle, the layers, the selection...) and hands the
## engine's callbacks to the topic files in scripts/game/, which hold everything else:
##   setup          building the scene, sizing the window, starting a battle in a mode
##   loop           what happens every frame
##   battlefield    the living enemies and troops, nearby lookups, threats, graves, the fallen
##   waves          building and sending waves, bosses, bounties, pace, end of a wave, records
##   castle_ctl     castle damage and alarms, castle upgrades and abilities, repairs
##   missions       the campaign: start screen, world map, missions, lent units and help
##   modes          Freeplay, the end of a battle, playing again, game speed
##   hiring         hiring, posting troops, walls and towers
##   groups, orders, formation_ctl   selecting, ordering and arranging troops
##   input          clicks, taps, drags and keys
##   effects, drawing   visual effects and sounds; drawing the field
## Reach them through main: main.waves.start_wave(), main.battlefield.get_enemies()...

const Data = preload("res://scripts/data/data.gd")
const Warrior = preload("res://scripts/troops/warrior.gd")
const Barricade = preload("res://scripts/troops/barricade.gd")
const Pathing = preload("res://scripts/field/pathing.gd")
const Castle = preload("res://scripts/castle/castle.gd")
const Enemy = preload("res://scripts/enemies/enemy.gd")
const Fx = preload("res://scripts/field/fx.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const Sprites = preload("res://scripts/art/sprites.gd")
const Audio = preload("res://scripts/audio/audio.gd")
const Grave = preload("res://scripts/troops/grave.gd")
const FieldArt = preload("res://scripts/art/field_art.gd")
const Forge = preload("res://scripts/ui/forge.gd")
const Ambience = preload("res://scripts/field/ambience.gd")
const Tutorial = preload("res://scripts/ui/tutorial.gd")
const CastlePowers = preload("res://scripts/castle/castle_powers.gd")
const Engineer = preload("res://scripts/troops/engineer.gd")
const Maps = preload("res://scripts/campaign/maps.gd")
const MissionRules = preload("res://scripts/mission/rules.gd")
const Camp = preload("res://scripts/mission/camp.gd")
const Scenarios = preload("res://scripts/mission/scenarios.gd")
const CD_XP_RATES = preload("res://scripts/data/campaign_data.gd").XP_RATES    # a story campaign battle (the Campaign autoload says which mission)
const Formation = preload("res://scripts/troops/formation.gd")
const Warband = preload("res://scripts/enemies/warband.gd")

# The topic files (see above).
const SetupCtl = preload("res://scripts/game/setup.gd")
var setup: SetupCtl = SetupCtl.new(self)
const LoopCtl = preload("res://scripts/game/loop.gd")
var loop: LoopCtl = LoopCtl.new(self)
const BattlefieldCtl = preload("res://scripts/game/battlefield.gd")
var battlefield: BattlefieldCtl = BattlefieldCtl.new(self)
const WavesCtl = preload("res://scripts/game/waves.gd")
var waves: WavesCtl = WavesCtl.new(self)
const CastleControlCtl = preload("res://scripts/game/castle_control.gd")
var castle_ctl: CastleControlCtl = CastleControlCtl.new(self)
const MissionsCtl = preload("res://scripts/game/missions.gd")
var missions: MissionsCtl = MissionsCtl.new(self)
const ModesCtl = preload("res://scripts/game/modes.gd")
var modes: ModesCtl = ModesCtl.new(self)
const HiringCtl = preload("res://scripts/game/hiring.gd")
var hiring: HiringCtl = HiringCtl.new(self)
const GroupsCtl = preload("res://scripts/game/groups.gd")
var groups: GroupsCtl = GroupsCtl.new(self)
const OrdersCtl = preload("res://scripts/game/orders.gd")
var orders: OrdersCtl = OrdersCtl.new(self)
const FormationsCtl = preload("res://scripts/game/formations.gd")
var formation_ctl: FormationsCtl = FormationsCtl.new(self)
const InputCtl = preload("res://scripts/game/input.gd")
var input: InputCtl = InputCtl.new(self)
const EffectsCtl = preload("res://scripts/game/effects.gd")
var effects: EffectsCtl = EffectsCtl.new(self)
const DrawingCtl = preload("res://scripts/game/drawing.gd")
var drawing: DrawingCtl = DrawingCtl.new(self)


# --- The battle's shared state ----------------------------------------------------

var FIELD_W := 640         # widens to fill the screen (see _fit_screen); 640 in a normal window
const FIELD_H := 768
const CASTLE_Y := 736      # top of the castle wall: enemies that reach it get in
const TILE := 64
var DEPLOY_TOP := 96       # warriors can't be posted in the enemy entry zone (in a castle's room: only its wall, 44)
const MIN_POST_GAP := 30.0
const FREEPLAY_GOLD := 999999
const MAX_ENEMY_RADIUS := 40.0   # at least the biggest enemy's radius (the Ogre King's)
var started := false     # set once the player picks a mode
var selected_grave = null   # a grave clicked to see who fell there
var grave_layer := Node2D.new()
var hazards := preload("res://scripts/field/hazards.gd").new()   # thin ice and blizzards (the North), over the ground
var gust := 0.0                    # how hard a blizzard is blowing now (0-1; see hazards.gd)
var bells := preload("res://scripts/field/bells.gd").new()   # the High Monastery's temple bells
var conduits := preload("res://scripts/field/conduits.gd").new()   # the Arcane Spires' rune circles
var contracts := preload("res://scripts/campaign/contracts.gd").new()   # the Free Cities' contracts and sellswords
var night := preload("res://scripts/field/night.gd").new()   # a night battle's darkness and lanterns (Carnival Night)
var corpse_layer := Node2D.new()   # enemies falling as they die (see spawn_corpse), on the ground under the troops
var ambience := Ambience.new()   # the mood over the field (light, weather, critters), by mode
var powers := CastlePowers.new()   # the Castle tab: abilities, Stone Walls, Ballistae
var permadeath := false   # downed warriors die for good unless revived (every difficulty; not the Tutorial or Freeplay)
var freeplay := false    # sandbox: unlimited gold, the castle can't fall, spawn any wave at will
var tutorial := false    # tutorial mode: a normal game with a guide, where the castle can't fall
var campaign := false
var rules = null   # the battle's rules (scripts/mission/rules.gd): castle defense unless the mission says otherwise
var camp: Node2D = null   # the work camp standing in for the castle, on a battlefield without one
var battle_id := ""       # a Battle Modes scenario being played (scenarios.gd), "" otherwise
var objective_layer: Node2D = null   # the mission's objectives (see rules_positions.gd), under the troops
var roof_layer: Node2D = null        # ...and the tops of the tall ones, over everyone
var classic_map := ""      # Classic on one of the campaign's battlefields ("" = the open meadow)
var map_id := ""           # the battlefield this game is on (a maps.gd id, "" for the meadow)
var stage_music := "calm"   # this battlefield's peaceful music between waves (audio.gd STAGE_TRACKS)
var map_extra := {}   # changes the battle makes to how its field looks (Dawnspire in ruins: {"ruined": true}); cleared on a new field
var battle_music := "battle"   # ...and its own battle music during waves (audio.gd BATTLES)
var credit := ""             # campaign XP: the unit kind whose doing the damage dealt right now is
var battle_xp := {}          # campaign XP earned this battle: unit kind -> XP
var mission := {}        # that mission's data (campaign_data.gd MISSIONS); empty outside the campaign
var gold: int = Data.START_GOLD
var difficulty := "normal"   # a key of Data.DIFFICULTIES ("normal" in freeplay)
var cost_mult := 1.0         # prices for this difficulty
var price_step := 1          # ...rounded to this many gold (5 on Hard)
var castle_max: float = Data.CASTLE_HP
var castle_base: float = Data.CASTLE_HP   # castle_max before the Fortify path's extra health
var castle_hp: float = Data.CASTLE_HP
var obj_hits := {}          # damage the battle's objectives have taken, by what dealt it (the balance bots read it)
var dmg_src := ""           # ...what's dealing it right now ("" when nothing's said)
var sap_wrecks: Array = []  # emplacements a Sapper's blast has wrecked this battle: [kind, gold spent on it] (the balance bots read it)
var down_time := 20.0        # seconds a downed warrior has before it dies (or, without permadeath, gets up)
var margin := Vector2.ZERO   # spare screen above and below the game on a tall window
var gates_warned := false   # "at the gates" has been shown this wave
var wave := 0
var wave_active := false
var game_over := false
var victory := false
var endless := false     # carried on past the final wave; enemies keep scaling until the line falls
var records_path := "user://records.cfg"   # best number of waves survived, per mode ("" = don't keep)
var routed := false       # lost because the army was gone with no way to raise another
var best_before := 0      # a survival battle's best (waves) before this one
var spawn_queue: Array = []   # [enemy kind, wave level] pairs waiting to enter
var spawn_timer := 0.0
var spawn_interval := 0.8
var placing_type := ""
var castle_selected := false
var auto_play := false         # start each wave by itself after the last one's cleared
var auto_timer := 0.0          # seconds until auto-play starts the next wave
var forced_auto := false       # this battle keeps coming (a mission's "pace": {"auto": "forced"}): auto-play can't be turned off
var deploying := false         # forced pace: the opening seconds to set up, before the first wave
var wave_clock := 0.0          # forced pace: seconds since the last of the wave arrived (the next comes regardless, after pace_window())
const AUTO_DELAY := 3.0
var wall_start = null     # first click while placing a barricade (Vector2), or null
var last_priority := {}   # unit kind -> target priority new hires start with
var last_orders := {}     # unit kind -> {commit, move_mode, guard_area, danger_mode, call_help, answer} new hires start with (the last given to that kind)
var area_pick := []       # troops waiting for a Guard Area to be drawn on the field (see start_area_pick)
var area_start = null     # where the area being drawn was started (Vector2), while the button's held
var selected: Warrior = null
var group := []             # several troops selected together (box or Shift+click); `selected` is null then
var ward_pick := []         # Healers waiting for a click on the troop they're to stay with
var box_start = null        # where a left-drag on open field started (Vector2), while the button's held
var box_active := false     # it's been dragged far enough to be a selection box
var box_add := false        # Shift was held: the box adds to the group
var box_touch := false     # the selection box was started by a tap on a touchscreen
var group_drag := false     # dragging the whole group to new posts (between waves)
var mouse := Vector2.ZERO
var mouse_stand_in := Vector2.INF   # tests: where the mouse is taken to be (INF: the real one)
## Where the pointer is, from the input events themselves: a finger's taps and drags as
## much as a mouse (asking the engine where "the mouse" is gives a phone's last touch, not
## the one just made, so a unit picked up jumped away from the finger).
var pointer := Vector2.ZERO
var dragging: Warrior = null     # unit being repositioned between waves
var hovered: Warrior = null      # the troop under the mouse between waves (it perks up: see Warrior._carry)
var GROUND_OVERSAMPLE := 2   # (1 on a phone: its screen is small, and filling pixels is what costs there)
var ground_vp := SubViewport.new()     # the ground, painted once (see _repaint_ground)
var ground_painter := Node2D.new()
var castle := Castle.new()
var wall_layer := Node2D.new()
var warrior_layer := Node2D.new()
var enemy_layer := Node2D.new()
var fx_layer := Node2D.new()
var overlay := Node2D.new()
var hud: CanvasLayer
var paths := Pathing.new()
var audio: Audio
var bard_instruments := []   # what the Bards on the field are playing (see _bard_instruments)
var song_on := true   # the player can switch the eight-Bard song off (from any Bard's panel)
var hurt_by = null           # while an enemy's blow or shot lands on a troop: that enemy (a ward throws some back at it)
var heavy_key := 0            # while an enemy's warned blow is landing: its windup_key (see defense.gd)
var hit_from := Vector2.INF   # while a shot's hitting: where it came from (Shieldbearers' shields); INF for blows
## Your troops fallen for good this battle, that a Gravebinder could still raise: each a
## record of what it was (its kind, upgrades, what they'd made it, its look) and where it
## lies, for FALLEN_KEEP seconds. "claimed": the Gravebinder raising it (one at a time).
var fallen: Array = []
var wave_squads: Array = []   # the squads in the wave being sent (for its announcement)
var _foes_seen := {}
var bands := {}             # warband id -> the band (while it forms up and advances)
var band_due := {}          # warband id -> how many of it are still to come on
## The alarm bell, as the castle falls below half its health and again below a quarter.
var castle_warned := 0   # (how many of those it's rung this battle)
const AREA_PRESET_NAMES := {"front": "Front", "left": "Left flank", "center": "Centre", "right": "Right flank", "back": "Back"}


## The Forge's look goes on before anything is built (the HUD is made in its own _ready,
## which runs before this node's).
func _enter_tree() -> void:
	Forge.apply(get_tree())


func _ready() -> void:
	setup.build()


func _process(delta: float) -> void:
	loop.tick(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		missions._bank_unfinished()


func _input(event: InputEvent) -> void:
	input.on_input(event)


func _unhandled_input(event: InputEvent) -> void:
	input.on_unhandled_input(event)


func _draw() -> void:
	drawing.draw_main()
