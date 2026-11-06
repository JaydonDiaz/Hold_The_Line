extends Node
## Sound effects and music, all made in code when the game starts: a tiny
## synthesizer (square, triangle, saw, sine and noise voices with pitch sweeps and
## decaying envelopes) renders each effect once, and two chiptune loops (a calm one
## between waves and a battle one during them) are composed note by note on a
## background thread. Each loop also gets a part for every Bard instrument, played in
## sync and faded in while a Bard with that instrument is on the field. Music and effects have their own volume (saved between games).
## Each finished piece is kept for as long as the game runs (see _cache), so the scene
## reloads between campaign battles don't compose everything again; a scene that's
## leaving stops its composer after the piece in hand instead of waiting for the rest.

const RATE := 22050
const SETTINGS := "user://settings.cfg"
const VOICES := 3          # copies of one effect that can sound at once
const MIN_GAP := 0.045     # seconds before the same effect can start again (busy fights stay listenable)

# Each effect is a list of layers, mixed together:
#   [wave, start Hz, end Hz, seconds, volume, delay, decay curve, duty / notes]
# wave: "square", "tri", "saw", "sine" or "noise" (its Hz is how fast it crackles).
# The pitch slides from start to end. A higher curve dies away faster. For squares
# the last value is the pulse width; an Array there plays those semitones in turn
# (an arpeggio) across the layer.
const SOUNDS := {
	"slash": [["noise", 9000, 2500, 0.09, 0.5, 0.0, 3.0, 0.5], ["square", 900, 300, 0.06, 0.12, 0.0, 2.0, 0.5]],
	"hit": [["noise", 4000, 700, 0.07, 0.5, 0.0, 3.0, 0.5], ["square", 220, 90, 0.06, 0.25, 0.0, 2.0, 0.5]],
	"punch": [["noise", 2500, 600, 0.06, 0.45, 0.0, 3.0, 0.5], ["sine", 170, 60, 0.08, 0.5, 0.0, 2.0, 0.5]],
	"bow": [["tri", 700, 1400, 0.05, 0.25, 0.0, 2.0, 0.5], ["noise", 6000, 4000, 0.09, 0.18, 0.0, 4.0, 0.5]],
	"magic": [["square", 600, 1200, 0.12, 0.18, 0.0, 2.0, 0.25], ["sine", 1200, 2400, 0.15, 0.18, 0.02, 2.0, 0.5]],
	"fire": [["noise", 1500, 400, 0.25, 0.4, 0.0, 1.5, 0.5], ["saw", 120, 60, 0.2, 0.15, 0.0, 2.0, 0.5]],
	"flame": [["noise", 1800, 900, 0.1, 0.18, 0.0, 2.0, 0.5]],
	"frost": [["sine", 1800, 2600, 0.12, 0.22, 0.0, 2.0, 0.5], ["tri", 2600, 3200, 0.1, 0.12, 0.03, 2.0, 0.5]],
	"ki": [["square", 300, 900, 0.12, 0.25, 0.0, 2.0, 0.5], ["noise", 3000, 3000, 0.08, 0.15, 0.0, 3.0, 0.5]],
	"beam": [["saw", 220, 110, 0.6, 0.3, 0.0, 1.0, 0.5], ["square", 440, 220, 0.6, 0.12, 0.0, 1.0, 0.5], ["noise", 2000, 1000, 0.5, 0.18, 0.0, 1.5, 0.5]],
	"cannon": [["noise", 1200, 150, 0.35, 0.65, 0.0, 2.0, 0.5], ["sine", 90, 35, 0.3, 0.7, 0.0, 2.0, 0.5]],
	"boom": [["noise", 900, 100, 0.45, 0.7, 0.0, 1.5, 0.5], ["sine", 70, 30, 0.4, 0.65, 0.0, 1.5, 0.5]],
	"toss": [["tri", 300, 520, 0.08, 0.22, 0.0, 2.0, 0.5]],
	"splash": [["noise", 3000, 800, 0.15, 0.3, 0.0, 2.0, 0.5], ["tri", 600, 300, 0.1, 0.15, 0.0, 2.0, 0.5]],
	"note": [["tri", 880, 880, 0.18, 0.28, 0.0, 1.5, 0.5], ["sine", 1760, 1760, 0.18, 0.1, 0.0, 2.0, 0.5]],
	"pluck": [["square", 660, 655, 0.22, 0.2, 0.0, 3.0, 0.25], ["tri", 1320, 1310, 0.15, 0.1, 0.0, 3.0, 0.5]],   # the herald's pipa
	"reed": [["square", 523, 523, 0.25, 0.14, 0.0, 1.0, 0.35], ["saw", 1046, 1046, 0.25, 0.05, 0.0, 1.2, 0.5]],   # the jester's mouth instrument
	"flute": [["sine", 1046, 1050, 0.3, 0.26, 0.0, 0.8, 0.5], ["noise", 6000, 6000, 0.12, 0.03, 0.0, 2.0, 0.5]],   # the nature-bard's flute
	"violin": [["saw", 880, 880, 0.35, 0.12, 0.0, 0.6, 0.5], ["square", 1760, 1760, 0.35, 0.03, 0.0, 0.8, 0.5]],   # two paths at tier 3
	"cello": [["saw", 220, 220, 0.45, 0.16, 0.0, 0.6, 0.5], ["tri", 110, 110, 0.45, 0.12, 0.0, 0.7, 0.5]],   # three paths at tier 2
	"harp": [["tri", 1046, 1046, 0.35, 0.22, 0.0, 2.0, [0, 4, 7]], ["sine", 2093, 2093, 0.3, 0.06, 0.0, 2.5, 0.5]],   # every path started
	"drum": [["sine", 200, 80, 0.18, 0.5, 0.0, 2.0, 0.5], ["noise", 3000, 3000, 0.08, 0.15, 0.0, 3.0, 0.5], ["tri", 2400, 2400, 0.12, 0.05, 0.03, 3.0, 0.5]],   # a jingling hand drum
	"zap": [["noise", 7000, 3000, 0.18, 0.3, 0.0, 2.0, 0.5], ["square", 1500, 600, 0.15, 0.15, 0.0, 2.0, 0.3]],
	"lance": [["saw", 900, 300, 0.25, 0.25, 0.0, 1.5, 0.5], ["sine", 1800, 900, 0.25, 0.18, 0.0, 1.5, 0.5]],
	"flash": [["square", 1500, 3000, 0.2, 0.18, 0.0, 1.5, 0.5], ["noise", 9000, 9000, 0.2, 0.12, 0.0, 2.0, 0.5]],
	"spell": [["sine", 784, 784, 0.3, 0.22, 0.0, 1.0, [0, 3, 7, 12]], ["tri", 1568, 1568, 0.3, 0.08, 0.0, 1.5, [0, 3, 7, 12]]],
	"heal": [["sine", 660, 660, 0.3, 0.25, 0.0, 1.0, [0, 4, 7, 12]]],
	"revive": [["tri", 523, 523, 0.5, 0.3, 0.0, 0.8, [0, 4, 7, 12, 16]], ["sine", 1046, 1046, 0.5, 0.1, 0.0, 1.0, [0, 4, 7, 12, 16]]],
	"coin": [["square", 988, 988, 0.16, 0.18, 0.0, 1.0, [0, 5]]],
	"gem": [["tri", 1319, 1319, 0.3, 0.25, 0.0, 1.0, [0, 4, 7, 12]], ["sine", 2637, 2637, 0.3, 0.08, 0.0, 1.5, [0, 4, 7, 12]]],
	"die": [["noise", 2000, 300, 0.15, 0.3, 0.0, 2.0, 0.5], ["square", 300, 80, 0.15, 0.15, 0.0, 2.0, 0.5]],
	"down": [["square", 400, 100, 0.4, 0.25, 0.0, 1.0, 0.5], ["noise", 1500, 300, 0.2, 0.2, 0.0, 2.0, 0.5]],
	"castle": [["noise", 600, 80, 0.3, 0.55, 0.0, 2.0, 0.5], ["sine", 60, 30, 0.3, 0.6, 0.0, 2.0, 0.5]],
	"upgrade": [["square", 523, 523, 0.28, 0.2, 0.0, 0.8, [0, 4, 7, 12]], ["tri", 1046, 1046, 0.28, 0.1, 0.0, 1.0, [0, 4, 7, 12]]],
	"place": [["tri", 220, 330, 0.08, 0.28, 0.0, 2.0, 0.5], ["noise", 3000, 1500, 0.05, 0.15, 0.0, 3.0, 0.5]],
	"sell": [["square", 659, 659, 0.15, 0.2, 0.0, 1.0, [7, 0]]],
	"horn": [["saw", 196, 196, 0.35, 0.22, 0.0, 0.8, 0.5], ["saw", 262, 262, 0.5, 0.22, 0.25, 0.8, 0.5], ["square", 131, 131, 0.75, 0.1, 0.0, 0.8, 0.5]],
	"fanfare": [["square", 523, 523, 0.6, 0.2, 0.0, 0.6, [0, 4, 7, 12, 7, 12]], ["tri", 262, 262, 0.6, 0.18, 0.0, 0.6, [0, 0, 7, 7, 4, 7]]],
	"victory": [["square", 523, 523, 1.2, 0.2, 0.0, 0.5, [0, 4, 7, 12, 7, 12, 16, 19]], ["tri", 131, 131, 1.2, 0.2, 0.0, 0.5, [0, 7, 5, 7, 0, 7, 12, 12]]],
	"defeat": [["square", 392, 392, 1.0, 0.2, 0.0, 0.7, [7, 3, 0, -5]], ["tri", 98, 98, 1.0, 0.2, 0.0, 0.7, [7, 3, 0, -5]]],
	"stomp": [["sine", 60, 25, 0.45, 0.85, 0.0, 1.5, 0.5], ["noise", 400, 80, 0.35, 0.45, 0.0, 1.5, 0.5]],
	"rise": [["saw", 110, 220, 0.4, 0.2, 0.0, 1.0, 0.5], ["noise", 800, 2500, 0.35, 0.12, 0.0, 1.5, 0.5]],
	"powerup": [["square", 200, 1600, 0.5, 0.2, 0.0, 0.6, 0.5], ["noise", 2000, 6000, 0.5, 0.1, 0.0, 1.0, 0.5]],
	"dash": [["noise", 5000, 1500, 0.15, 0.32, 0.0, 2.0, 0.5], ["tri", 300, 600, 0.1, 0.12, 0.0, 2.0, 0.5]],
	"freeze": [["tri", 3000, 1500, 0.15, 0.18, 0.0, 2.0, 0.5], ["noise", 8000, 8000, 0.1, 0.1, 0.0, 3.0, 0.5]],
	"rain": [["noise", 6000, 2000, 0.3, 0.28, 0.0, 1.5, 0.5], ["noise", 1500, 300, 0.25, 0.3, 0.2, 2.0, 0.5]],
	"crumble": [["noise", 1200, 200, 0.25, 0.4, 0.0, 1.5, 0.5]],
}

# Bard notes and the like are pitched to a pentatonic scale so they sound musical.
const PENTATONIC := [0, 2, 4, 7, 9, 12]

var _streams := {}     # effect name -> AudioStreamWAV
var _players := {}     # effect name -> [AudioStreamPlayer]
var _next := {}        # effect name -> index of the voice to use next
var _last := {}        # effect name -> when it last started (seconds)
var _music := {}       # "calm" / "battle" -> AudioStreamWAV, once composed
var _music_players: Array[AudioStreamPlayer] = []
var _layers := []      # Bard instruments playing along with the music right now
var _stop := false     # the scene is going: the composer thread stops after its current piece
var _picked := 0       # how many cached pieces this player has taken up so far
static var _cache := {}             # piece -> AudioStreamWAV: "fx:<effect>", "calm", "battle", "<track>:<instrument>", "ensemble"
static var _cache_lock := Mutex.new()
const INSTRUMENTS := ["note", "pluck", "reed", "flute", "drum", "violin", "cello", "harp"]   # lute, pipa, mouth instrument, flute, hand drum, and the special three
const LAYER_OFF := -60.0
var _playing_track := ""
var _wanted_track := ""
var _thread: Thread
var music_volume := 0.6
var sfx_volume := 0.8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # music carries on (and sliders work) while paused
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_load_settings()
	for sound_name in SOUNDS:
		var voices := []
		for i in VOICES:
			var p := AudioStreamPlayer.new()
			p.bus = "SFX"
			add_child(p)
			voices.append(p)
		_players[sound_name] = voices
		_next[sound_name] = 0
		_last[sound_name] = -1.0
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
		_music_players.append(m)
	# Making the sounds and composing the music takes a few seconds, so it's done off
	# the main thread (once per run of the game: later scenes reuse the pieces); effects
	# are ready first, and play() skips any that aren't yet.
	_pick_up()
	if _picked < _piece_count():
		_thread = Thread.new()
		_thread.start(_compose_all)


func _exit_tree() -> void:
	_stop = true
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	# Stop everything so no sound is left playing as the game closes.
	for p in get_children():
		if p is AudioStreamPlayer:
			p.stop()
			p.stream = null
	_streams.clear()
	_music.clear()


## Plays an effect. pitch shifts it (1 = as made); every play is nudged a little
## so repeats don't sound identical.
func play(sound_name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not _streams.has(sound_name) or sfx_volume <= 0.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last[sound_name] < MIN_GAP:
		return
	_last[sound_name] = now
	var voices: Array = _players[sound_name]
	var p: AudioStreamPlayer = voices[_next[sound_name]]
	_next[sound_name] = (_next[sound_name] + 1) % voices.size()
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.volume_db = volume_db
	p.play()


## A note from the pentatonic scale (for Bard notes and other musical bits).
func play_note(sound_name: String, base := 1.0) -> void:
	play(sound_name, base * pow(2.0, PENTATONIC.pick_random() / 12.0))


## Which music should be playing: "calm", "battle" or "" for none. Fades between them.
func set_track(track: String) -> void:
	_wanted_track = track


func _process(_delta: float) -> void:
	if _picked < _piece_count():
		_pick_up()
	if _wanted_track == _playing_track:
		return
	if _wanted_track != "" and not _music.has(_wanted_track):
		return   # still being composed
	_playing_track = _wanted_track
	var out: AudioStreamPlayer = _music_players[0]
	var into: AudioStreamPlayer = _music_players[1]
	_music_players.reverse()
	if not out.playing and _playing_track == "":
		return   # nothing to fade out or in
	var fade := create_tween().set_parallel(true)
	if out.playing:
		fade.tween_property(out, "volume_db", -60.0, 1.2)
		fade.chain().tween_callback(out.stop)
	if _playing_track != "":
		into.stream = _music[_playing_track]
		into.volume_db = -40.0
		into.play()
		fade.tween_property(into, "volume_db", 0.0, 1.2)


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func _apply_volumes() -> void:
	for pair in [["Music", music_volume], ["SFX", sfx_volume]]:
		var i := AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_mute(i, pair[1] <= 0.0)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(pair[1], 0.001)))


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		music_volume = cfg.get_value("audio", "music", music_volume)
		sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	_apply_volumes()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(SETTINGS)


# --- Synthesis -------------------------------------------------------------------

func _render_effect(layers: Array) -> AudioStreamWAV:
	var length := 0.0
	for l in layers:
		length = maxf(length, l[5] + l[3])
	var buf := PackedFloat32Array()
	buf.resize(int(length * RATE) + 1)
	for l in layers:
		var notes = l[7] if l[7] is Array else []
		var duty: float = l[7] if not (l[7] is Array) else 0.5
		_voice(buf, int(l[5] * RATE), l[3], l[1], l[2], l[0], l[4], l[6], duty, notes)
	return _to_stream(buf, false)


## Adds one voice into buf starting at sample `at`: the pitch sliding from f0 to f1
## (or stepping through `notes`, in semitones), fading in quickly and dying away.
static func _voice(buf: PackedFloat32Array, at: int, dur: float, f0: float, f1: float, wave: String,
		vol: float, curve: float, duty := 0.5, notes := [], rng_seed := 0) -> void:
	var n := int(dur * RATE)
	var attack := maxi(1, int(0.004 * RATE))
	var phase := 0.0
	var held := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed if rng_seed != 0 else 12345 + int(f0)
	var steps: int = notes.size()
	for i in n:
		var t := float(i) / n
		var f := f0 * pow(f1 / f0, t)
		var env := pow(1.0 - t, curve)
		if steps > 0:
			var k := mini(int(t * steps), steps - 1)
			f = f0 * pow(2.0, notes[k] / 12.0)
			var local := t * steps - k
			env = pow(1.0 - local, curve * 0.6) * (1.0 - 0.3 * t)
		env *= minf(1.0, float(i) / attack)
		phase += f / RATE
		var wrapped := phase >= 1.0
		phase -= floorf(phase)
		var v := 0.0
		match wave:
			"square":
				v = 1.0 if phase < duty else -1.0
			"tri":
				v = 4.0 * absf(phase - 0.5) - 1.0
			"saw":
				v = 2.0 * phase - 1.0
			"sine":
				v = sin(TAU * phase)
			"noise":
				if wrapped or i == 0:
					held = rng.randf_range(-1.0, 1.0)
				v = held
		var j := at + i
		if j < buf.size():
			buf[j] += v * vol * env


## Float samples to a 16-bit sound, gently limited so loud mixes don't clip harshly.
static func _to_stream(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		var x := buf[i]
		x = x / (1.0 + absf(x) * 0.35)
		bytes.encode_s16(i * 2, int(clampf(x, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = buf.size()
	return s


# --- Music -------------------------------------------------------------------------

static func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## Every piece, in the order they're made: the effects, both tracks (so the music can
## start), then the Bard parts, and the ensemble.
static func _pieces() -> Array:
	var out := []
	for sound_name in SOUNDS:
		out.append("fx:" + sound_name)
	out.append_array(["calm", "battle"])
	for track in ["calm", "battle"]:
		for instrument in INSTRUMENTS:
			out.append(track + ":" + instrument)
	out.append("ensemble")
	return out


static func _piece_count() -> int:
	return SOUNDS.size() + 2 + 2 * INSTRUMENTS.size() + 1


## The composer thread: makes each piece not already cached, and caches it.
func _compose_all() -> void:
	for piece in _pieces():
		if _stop:
			return
		_cache_lock.lock()
		var have := _cache.has(piece)
		_cache_lock.unlock()
		if have:
			continue
		var made: AudioStreamWAV
		if piece.begins_with("fx:"):
			made = _render_effect(SOUNDS[piece.substr(3)])
		elif piece == "calm":
			made = _compose_calm()
		elif piece == "battle":
			made = _compose_battle()
		elif piece == "ensemble":
			made = _compose_ensemble()
		else:
			made = _compose_part(piece.get_slice(":", 0), piece.get_slice(":", 1))
		_cache_lock.lock()
		_cache[piece] = made
		_cache_lock.unlock()


## Takes up the pieces cached so far: effects as they come, each track plain at first
## and swapped for its full version (in place, without a skip) once all its parts are in.
func _pick_up() -> void:
	_cache_lock.lock()
	var cache := _cache.duplicate()
	_cache_lock.unlock()
	if cache.size() == _picked:
		return
	_picked = cache.size()
	var effects := {}
	for sound_name in SOUNDS:
		if not _streams.has(sound_name) and cache.has("fx:" + sound_name):
			effects[sound_name] = cache["fx:" + sound_name]
	if not effects.is_empty():
		_effects_ready(effects)
	for track in ["calm", "battle"]:
		if not cache.has(track):
			continue
		var parts := [cache[track]]
		for instrument in INSTRUMENTS:
			if cache.has(track + ":" + instrument):
				parts.append(cache[track + ":" + instrument])
		var full := parts.size() == INSTRUMENTS.size() + 1
		var shown: int = (_music[track] as AudioStreamSynchronized).stream_count if _music.has(track) else 0
		if shown == 0 or (full and shown < parts.size()):
			_music_ready({track: parts if full else [parts[0]]})
	if cache.has("ensemble") and not _music.has("ensemble"):
		_music_ready({"ensemble": [cache["ensemble"]]})


func _effects_ready(effects: Dictionary) -> void:
	for sound_name in effects:
		for p in _players[sound_name]:
			p.stream = effects[sound_name]
		_streams[sound_name] = effects[sound_name]


func _music_ready(tracks: Dictionary) -> void:
	for track in tracks:
		var parts: Array = tracks[track]
		var sync := AudioStreamSynchronized.new()
		sync.stream_count = parts.size()
		for i in parts.size():
			sync.set_sync_stream(i, parts[i])
			sync.set_sync_stream_volume(i, 0.0 if i == 0 or INSTRUMENTS[i - 1] in _layers else LAYER_OFF)
		# Already playing the plain version? Carry on from the same spot with the parts in.
		for m in _music_players:
			if m.playing and _music.has(track) and m.stream == _music[track]:
				var at := m.get_playback_position()
				m.stream = sync
				m.play(at)
		_music[track] = sync


## Which Bard instruments are on the field (by their note sound names): each one adds
## its part to the music, once, however many Bards play it.
func set_layers(instruments: Array) -> void:
	instruments = instruments.duplicate()
	instruments.sort()
	if instruments == _layers:
		return
	_layers = instruments
	for track in _music:
		var sync: AudioStreamSynchronized = _music[track]
		for i in mini(INSTRUMENTS.size(), sync.stream_count - 1):   # the plain version has no parts yet
			var to := 0.0 if INSTRUMENTS[i] in _layers else LAYER_OFF
			var from := sync.get_sync_stream_volume(i + 1)
			if not is_equal_approx(from, to):
				var idx := i + 1
				create_tween().tween_method(func(v): sync.set_sync_stream_volume(idx, v), from, to, 1.0)


## Tempo (a sixteenth's length) and chords (root MIDI note, chord tones) of a track.
static func _track_info(track: String) -> Dictionary:
	if track == "calm":
		return {"step": 60.0 / 84.0 / 4.0, "chords": [[48, [0, 4, 7]], [45, [0, 3, 7]], [41, [0, 4, 7]], [43, [0, 4, 7]],
				[48, [0, 4, 7]], [45, [0, 3, 7]], [41, [0, 4, 7]], [43, [0, 4, 7, 10]]]}
	var am := [0, 3, 7]
	var maj := [0, 4, 7]
	return {"step": 60.0 / 138.0 / 4.0, "chords": [[57, am], [53, maj], [55, maj], [52, maj], [57, am], [53, maj], [55, maj], [52, maj],
			[53, maj], [55, maj], [57, am], [57, am], [50, am], [55, maj], [48, maj], [52, maj]]}


## A silent buffer as long as one loop of the track.
static func _track_buffer(info: Dictionary) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(info["chords"].size() * 16 * info["step"] * RATE) + 1)
	return buf


## One Bard instrument's part for a track, the same length and chords, so it can
## play along in time. Instruments are named after their note sounds: "note" (the
## lute), "pluck" (pipa), "reed" (mouth instrument), "flute" and "drum".
static func _compose_part(track: String, instrument: String) -> AudioStreamWAV:
	var info := _track_info(track)
	var step: float = info["step"]
	var chords: Array = info["chords"]
	var buf := _track_buffer(info)
	var busy := track == "battle"
	for b in chords.size():
		var root: int = chords[b][0]
		var tones: Array = chords[b][1]
		var t0: float = b * 16 * step
		match instrument:
			"note":
				# Lute: bright plucks on the offbeats.
				for i in 8:
					var midi: int = root + 24 + tones[(i + b) % tones.size()]
					_voice(buf, int((t0 + (i * 2 + 1) * step) * RATE), step * 1.6, _hz(midi), _hz(midi), "square", 0.045, 3.0, 0.25)
			"pluck":
				# Pipa: a quick tremolo on one chord tone a beat.
				for i in 16:
					if not busy and i % 2 == 1:
						continue
					var midi: int = root + 24 + tones[(i / 4) % tones.size()]
					_voice(buf, int((t0 + i * step) * RATE), step * 0.9, _hz(midi), _hz(midi), "square", 0.035, 2.5, 0.125)
			"reed":
				# Mouth instrument: long reedy notes on the third, then the fifth.
				for half in 2:
					var midi: int = root + 12 + tones[mini(1 + half, tones.size() - 1)]
					_voice(buf, int((t0 + half * 8 * step) * RATE), step * 7.6, _hz(midi), _hz(midi), "square", 0.04, 0.5, 0.35)
			"flute":
				# Flute: a high countermelody, a note a beat (two in battle).
				var shape := [2, 1, 0, 1, 2, 3, 2, 1]
				var per := 8 if busy else 4
				for i in per:
					var sh: int = shape[(i + b) % shape.size()]
					var midi: int = root + 24 + tones[sh % tones.size()] + (12 if sh == 3 else 0)
					var at := int((t0 + i * (16 / per) * step) * RATE)
					_voice(buf, at, step * (16 / per) * 0.9, _hz(midi), _hz(midi), "sine", 0.06, 0.8)
					_voice(buf, at, 0.05, 6000.0, 6000.0, "noise", 0.008, 2.0, 0.5, [], 31 + i)
			"violin":
				# Violin: a singing line over the chords, an eighth at a time (quarters when calm).
				var per := 8 if busy else 4
				for i in per:
					var midi: int = root + 24 + tones[(i * 2 + b) % tones.size()] + (12 if i == per - 1 else 0)
					_voice(buf, int((t0 + i * (16 / per) * step) * RATE), step * (16 / per) * 1.05, _hz(midi), _hz(midi), "saw", 0.03, 0.4)
			"cello":
				# Cello: deep bowed notes, the root then the fifth.
				for half in 2:
					var midi: int = root - (0 if half == 0 else 5)
					_voice(buf, int((t0 + half * 8 * step) * RATE), step * 7.8, _hz(midi), _hz(midi), "saw", 0.05, 0.35)
			"harp":
				# Harp: a rippling run up the chord at the start of each bar.
				for i in 8:
					var midi: int = root + 12 + tones[i % tones.size()] + 12 * (i / tones.size())
					_voice(buf, int((t0 + i * step) * RATE), step * 6.0, _hz(midi), _hz(midi), "tri", 0.035, 2.2)
			"drum":
				# Hand drum: a syncopated beat, with a jingle on the backbeats.
				var hits := [0, 6, 10, 12] if busy else [0, 8, 10]
				for i in hits:
					_voice(buf, int((t0 + i * step) * RATE), 0.16, 210.0, 90.0, "sine", 0.26, 2.0)
				for i in [4, 12]:
					_voice(buf, int((t0 + i * step) * RATE), 0.08, 2400.0, 2400.0, "tri", 0.03, 3.0)
	return _to_stream(buf, true)


## All eight Bard instruments on the field between waves: they play a song together.
## An original D-major piece; the instruments come in one after another (harp and
## cello, then lute and hand drum, then pipa and mouth instrument), the violin carries
## the tune and the flute joins it in harmony for the second half.
static func _compose_ensemble() -> AudioStreamWAV:
	var step := 60.0 / 100.0 / 4.0
	var maj := [0, 4, 7]
	var mn := [0, 3, 7]
	var chords := [[50, maj], [57, maj], [59, mn], [55, maj], [50, maj], [57, maj], [55, maj], [57, maj],
			[59, mn], [55, maj], [50, maj], [57, maj], [55, maj], [57, maj], [50, maj], [50, maj]]
	var melody := [
		[[74, 4], [76, 4], [78, 4], [81, 4]], [[81, 6], [79, 2], [76, 8]], [[78, 4], [74, 4], [78, 4], [83, 4]], [[81, 4], [79, 4], [78, 8]],
		[[74, 2], [76, 2], [78, 4], [81, 4], [78, 4]], [[76, 8], [73, 4], [76, 4]], [[74, 4], [71, 4], [74, 4], [79, 4]], [[76, 12], [73, 4]],
		[[78, 4], [83, 4], [81, 4], [78, 4]], [[79, 6], [78, 2], [76, 8]], [[74, 4], [78, 4], [81, 8]], [[85, 4], [83, 4], [81, 8]],
		[[83, 6], [81, 2], [79, 4], [78, 4]], [[76, 4], [78, 4], [79, 4], [81, 4]], [[86, 8], [81, 8]], [[74, 16]],
	]
	var buf := PackedFloat32Array()
	buf.resize(int(chords.size() * 16 * step * RATE) + 1)
	for b in chords.size():
		var root: int = chords[b][0]
		var tones: Array = chords[b][1]
		var t0 := b * 16 * step
		# Harp: a ripple up the chord every bar (the opening two bars on their own, louder).
		for i in 8:
			var midi: int = root + 12 + tones[i % 3] + 12 * (i / 3)
			_voice(buf, int((t0 + i * step) * RATE), step * 6.0, _hz(midi), _hz(midi), "tri", 0.06 if b < 2 else 0.035, 2.2)
		# Cello: the bass, bowed in half notes.
		for half in 2:
			var midi: int = root - 12 + (0 if half == 0 else 7)
			_voice(buf, int((t0 + half * 8 * step) * RATE), step * 7.8, _hz(midi), _hz(midi), "saw", 0.06, 0.35)
		if b >= 2:
			# Lute on the offbeats, hand drum underneath.
			for i in 8:
				var midi: int = root + 12 + tones[(i + b) % 3]
				_voice(buf, int((t0 + (i * 2 + 1) * step) * RATE), step * 1.6, _hz(midi), _hz(midi), "square", 0.035, 3.0, 0.25)
			for i in [0, 6, 10, 12]:
				_voice(buf, int((t0 + i * step) * RATE), 0.16, 210.0, 90.0, "sine", 0.24, 2.0)
			for i in [4, 12]:
				_voice(buf, int((t0 + i * step) * RATE), 0.08, 2400.0, 2400.0, "tri", 0.03, 3.0)
		if b >= 4:
			# Pipa tremolo on the fifth, mouth instrument holding the third.
			for i in 16:
				var midi: int = root + 19
				_voice(buf, int((t0 + i * step) * RATE), step * 0.9, _hz(midi), _hz(midi), "square", 0.022, 2.5, 0.125)
			_voice(buf, int(t0 * RATE), step * 15.5, _hz(root + 12 + tones[1]), _hz(root + 12 + tones[1]), "square", 0.03, 0.4, 0.35)
		# Violin: the tune. Flute: a harmony above it in the second half.
		var at := t0
		for note in melody[b]:
			var len: float = step * note[1]
			_voice(buf, int(at * RATE), len * 1.02, _hz(note[0]), _hz(note[0]), "saw", 0.05, 0.5)
			if b >= 8:
				# The nearest chord note at least a minor third above the tune.
				var above := 999
				for tone in tones:
					var cand: int = root + tone
					while cand < note[0] + 3:
						cand += 12
					above = mini(above, cand)
				_voice(buf, int(at * RATE), len, _hz(above), _hz(above), "sine", 0.045, 0.7)
			at += len
	return _to_stream(buf, true)


## Between waves: a gentle C-major loop. Triangle arpeggios over a soft bass, with a
## slow sine melody on top.
static func _compose_calm() -> AudioStreamWAV:
	var info := _track_info("calm")
	var step: float = info["step"]
	var chords: Array = info["chords"]
	var bar := 16
	var buf := _track_buffer(info)
	var melody := [[76, 8], [74, 4], [72, 4], [72, 8], [69, 8], [69, 6], [72, 2], [74, 8], [71, 8], [74, 8],
			[76, 4], [79, 4], [76, 8], [72, 8], [77, 6], [76, 2], [74, 8], [74, 12], [71, 4]]
	for b in chords.size():
		var root: int = chords[b][0]
		var tones: Array = chords[b][1]
		var t0 := b * bar * step
		# Bass: the root on beats one and three.
		for beat in [0, 8]:
			_voice(buf, int((t0 + beat * step) * RATE), step * 8, _hz(root - 12), _hz(root - 12), "tri", 0.22, 0.8)
		# Arpeggio: chord tones in eighths, up and back.
		var order := [0, 1, 2, 3, 2, 1, 0, 1]
		for i in 8:
			var k: int = order[i] % (tones.size() + 1)
			var midi: int = root + 12 + (tones[k] if k < tones.size() else 12)
			_voice(buf, int((t0 + i * 2 * step) * RATE), step * 3, _hz(midi), _hz(midi), "tri", 0.09, 1.5)
	var at := 0.0
	for note in melody:
		_voice(buf, int(at * RATE), step * note[1] * 1.1, _hz(note[0]), _hz(note[0]), "sine", 0.12, 0.7)
		at += step * note[1]
	return _to_stream(buf, true)


## During waves: a driving A-minor loop. Square lead and bass, a thin pulse
## arpeggio, and kick, snare and hi-hat.
static func _compose_battle() -> AudioStreamWAV:
	var info := _track_info("battle")
	var step: float = info["step"]
	var chords: Array = info["chords"]
	var bar := 16
	var buf := _track_buffer(info)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	# Lead rhythm per bar: [step, length]. Phrases repeat with a twist.
	var rhythm_a := [[0, 3], [3, 1], [4, 2], [6, 2], [8, 4], [12, 2], [14, 2]]
	var rhythm_b := [[0, 2], [2, 2], [4, 4], [8, 3], [11, 1], [12, 4]]
	var last := 69
	var phrase := {}   # bar -> notes, so bars 5-8 echo bars 1-4
	for b in chords.size():
		var root: int = chords[b][0]
		var tones: Array = chords[b][1]
		var t0 := b * bar * step
		# Bass: driving eighths, root with an octave jump.
		for i in 8:
			var midi: int = root - 12 + (12 if i % 4 == 2 else 0)
			_voice(buf, int((t0 + i * 2 * step) * RATE), step * 1.8, _hz(midi), _hz(midi), "square", 0.1, 1.2, 0.5)
		# Arpeggio: a quiet thin pulse on every sixteenth.
		for i in 16:
			var k: int = [0, 1, 2, 1][i % 4]
			var midi: int = root + 12 + tones[k]
			_voice(buf, int((t0 + i * step) * RATE), step * 0.9, _hz(midi), _hz(midi), "square", 0.035, 2.0, 0.125)
		# Drums.
		for i in 16:
			var at := int((t0 + i * step) * RATE)
			if i == 0 or i == 8 or (i == 10 and b % 2 == 1):
				_voice(buf, at, 0.14, 130.0, 40.0, "sine", 0.45, 2.0)
			if i == 4 or i == 12:
				_voice(buf, at, 0.12, 3500.0, 1200.0, "noise", 0.2, 2.5, 0.5, [], 77 + i)
			if i % 2 == 0:
				_voice(buf, at, 0.03, 9000.0, 9000.0, "noise", 0.05, 3.0, 0.5, [], 99 + i)
		# Lead: chord tones, moving to the nearest one each time.
		var notes := []
		if phrase.has(b - 4) and b >= 4 and b < 8 and b != 7:
			notes = phrase[b - 4]
		else:
			var rhythm: Array = rhythm_a if b < 8 else rhythm_b
			for r in rhythm:
				var options := []
				for oct in [12, 24]:
					for tone in tones:
						options.append(root + oct + tone)
				options.sort_custom(func(x, y): return absi(x - last) < absi(y - last))
				var pick: int = options[rng.randi_range(0, mini(2, options.size() - 1))]
				pick = clampi(pick, 64, 84)
				notes.append([r[0], r[1], pick])
				last = pick
			phrase[b] = notes
		for nt in notes:
			_voice(buf, int((t0 + nt[0] * step) * RATE), step * nt[1] * 0.95, _hz(nt[2]), _hz(nt[2]), "square", 0.07, 0.9, 0.5)
	return _to_stream(buf, true)
