extends Node
## Separate music and effect players; ambient cues never drive the economy.
const MUSIC = [preload("res://assets/audio/meadow_lullaby.wav"), preload("res://assets/audio/seaside_waltz.wav")]
const EFFECTS = {
	"tap": preload("res://assets/audio/ui_tap.wav"),
	"income": preload("res://assets/audio/coin_idle.wav"),
	"spend": preload("res://assets/audio/coin_spend.wav"),
	"collect": preload("res://assets/audio/coin_collect.wav"),
	"open": preload("res://assets/audio/hotel_open.wav"),
	"build": preload("res://assets/audio/room_built.wav"),
	"purr": preload("res://assets/audio/cat_purr.wav"),
	"toy": preload("res://assets/audio/toy_rustle.wav"),
	"bell": preload("res://assets/audio/dinner_bell.wav")
}
const MEOWS = [preload("res://assets/audio/meow_1.wav"), preload("res://assets/audio/meow_2.wav"), preload("res://assets/audio/meow_3.wav")]
var music_players: Array[AudioStreamPlayer] = []
var voices: Array[AudioStreamPlayer] = []
var music_tween: Tween
var current_player: int = 0
var current_hotel: int = -1
var music_enabled: bool = true
var effects_enabled: bool = true
var active: bool = true
var ambience: bool = false
var income_coins: float = 0.0
var coin_timer: float = 0.0
var meow_timer: float = 12.0
var last_meow: int = -5000
var last_tap: int = -5000
var voice_index: int = 0
var meow_index: int = 0
var recent_events: Array[String] = []
var purr_player: AudioStreamPlayer

func _ready() -> void:
	purr_player = AudioStreamPlayer.new()
	purr_player.volume_db = -8
	add_child(purr_player)
	for i in range(2):
		var player = AudioStreamPlayer.new()
		player.volume_db = -17
		add_child(player)
		music_players.append(player)
	for i in range(6):
		var voice = AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)

func configure(settings: Dictionary, hotel: int, foreground: bool, hotel_visible: bool) -> void:
	music_enabled = settings.get("music", true)
	effects_enabled = settings.get("sound", true)
	active = foreground
	if not active or not effects_enabled:
		purr_player.stop()
	ambience = hotel_visible
	for voice in voices:
		if not active or not effects_enabled:
			voice.stop()
	for player in music_players:
		player.stream_paused = not active
	if not music_enabled:
		if music_tween != null:
			music_tween.kill()
		for player in music_players:
			player.stop()
		return
	if not active:
		return
	if current_hotel != hotel or not music_players[current_player].playing:
		_start_music(hotel)

func _start_music(hotel: int) -> void:
	if music_tween != null:
		music_tween.kill()
	var previous: AudioStreamPlayer = music_players[current_player]
	current_player = 1 - current_player
	var next: AudioStreamPlayer = music_players[current_player]
	var track: AudioStreamWAV = MUSIC[hotel % MUSIC.size()].duplicate()
	track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	track.loop_begin = 0
	track.loop_end = roundi(track.get_length() * track.mix_rate)
	next.stream = track
	next.volume_db = -45
	next.play()
	current_hotel = hotel
	music_tween = create_tween().set_parallel(true)
	music_tween.tween_property(next, "volume_db", -14.0, 1.0)
	music_tween.tween_property(previous, "volume_db", -55.0, 0.8)
	music_tween.chain().tween_callback(previous.stop)

func play_effect(kind: String) -> void:
	if not active or not effects_enabled or not EFFECTS.has(kind):
		return
	if kind == "purr":
		if not purr_player.playing:
			purr_player.stream = EFFECTS.purr
			purr_player.play()
			recent_events.append("purr")
		return
	if kind == "tap":
		if Time.get_ticks_msec() - last_tap < 70:
			return
		last_tap = Time.get_ticks_msec()
	_play(EFFECTS[kind], kind, -17 if kind in ["tap", "income"] else -10, 1.0 + (voice_index % 3 - 1) * 0.035)

func meow() -> void:
	if not active or not effects_enabled or Time.get_ticks_msec() - last_meow < 1500:
		return
	last_meow = Time.get_ticks_msec()
	_play(MEOWS[meow_index % 3], "meow", -12, 1.0)
	meow_index += 1
	meow_timer = 24.0 + (meow_index % 4) * 5.0

func _play(stream: AudioStream, kind: String, volume: float, pitch: float) -> void:
	var player: AudioStreamPlayer = voices[voice_index % voices.size()]
	voice_index += 1
	player.stream = stream
	player.volume_db = volume
	player.pitch_scale = pitch
	player.play()
	recent_events.append(kind)
	if recent_events.size() > 24:
		recent_events.pop_front()

func note_income(coins: float) -> void:
	if active and effects_enabled and ambience:
		income_coins += maxf(0, coins)

func _process(delta: float) -> void:
	if not active or not effects_enabled or not ambience:
		income_coins = 0
		return
	coin_timer += delta
	meow_timer -= delta
	if income_coins >= 1.0 and coin_timer >= 5.5:
		play_effect("income")
		income_coins = 0
		coin_timer = 0
	if meow_timer <= 0:
		meow()

func shutdown() -> void:
	active = false
	if purr_player != null:
		purr_player.stop()
	if music_tween != null:
		music_tween.kill()
	for player in music_players + voices:
		player.stop()
		player.stream = null

func _exit_tree() -> void:
	shutdown()
