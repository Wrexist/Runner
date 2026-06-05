extends Node
## AudioManager (autoload) — plays themed music + sound effects.
## FAIL-SOFT: a missing/unimported audio file simply stays silent; the game must
## never crash over audio (it's a kids' app that has to keep running).
## Respects the local SaveManager.settings music/sfx toggles. No network, ever.

const POOL_SIZE := 8

var _music: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _cache: Dictionary = {}        # path -> AudioStream (or null if absent)

func _ready() -> void:
	_music = AudioStreamPlayer.new()
	add_child(_music)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_pool.append(p)
	# Auto-react to gameplay so callers don't have to wire every sound by hand.
	GameCore.run_started.connect(play_music)
	GameCore.critter_rescued.connect(_on_rescued)
	GameCore.stumbled.connect(func(_lives): play_sfx("miss"))

func _on_rescued(_id: String, _total: int) -> void:
	# Pitch climbs with the streak so a hot run literally sounds more exciting.
	play_sfx("rescue", 1.0 + minf(GameCore.streak, 8) * 0.04)

func play_sfx(sound: String, pitch: float = 1.0) -> void:
	if not bool(SaveManager.settings.get("sfx", true)):
		return
	var stream := _load(ThemeManager.audio(sound))
	if stream == null:
		return
	var p := _sfx_pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.pitch_scale = pitch
	p.play()

func play_music() -> void:
	if not bool(SaveManager.settings.get("music", true)):
		return
	var stream := _load(ThemeManager.audio("music"))
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_music.stream = stream
	if not _music.playing:
		_music.play()

func stop_music() -> void:
	_music.stop()

func _load(path: String) -> AudioStream:
	if path == "":
		return null
	if _cache.has(path):
		return _cache[path]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = ResourceLoader.load(path) as AudioStream
	else:
		push_warning("AudioManager: audio not found (silent): %s" % path)
	_cache[path] = stream
	return stream
