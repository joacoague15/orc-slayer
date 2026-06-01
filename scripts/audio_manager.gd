# scripts/audio_manager.gd
extends Node

# Streams de audio (los cargamos una vez y los reusamos)
var slice_stream: AudioStream = preload("res://audio/sfx/slice.wav")
var orc_death_stream: AudioStream = preload("res://audio/sfx/orc_death.wav")
var player_death_stream: AudioStream = preload("res://audio/sfx/player_death.wav")
var pickup_stream: AudioStream = preload("res://audio/sfx/pickup.wav")
var game_music_stream: AudioStream = preload("res://audio/music/background.ogg")
var menu_music_stream: AudioStream = preload("res://audio/music/main_menu.mp3")

# Pool de players para SFX (para que varios sonidos puedan superponerse)
const SFX_POOL_SIZE: int = 12
var sfx_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var music_tween: Tween
var current_music_key: String = ""

# Volúmenes (en dB, 0 es normal, -10 es más bajo, 6 es más alto)
@export var sfx_volume_db: float = -4.0
@export var music_volume_db: float = -12.0

# Para no spammear: cooldowns por tipo de sonido
var last_played_times: Dictionary = {}
const MIN_COOLDOWN: float = 0.04  # mínimo entre dos sonidos del mismo tipo

func _ready() -> void:
	# Crear pool de SFX players
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.volume_db = sfx_volume_db
		add_child(p)
		sfx_players.append(p)
	
	# Crear el music player
	music_player = AudioStreamPlayer.new()
	music_player.stream = game_music_stream
	music_player.volume_db = music_volume_db
	music_player.bus = "Master"
	add_child(music_player)
	
	# Si la música tiene loop activado en el archivo, va a loopear sola
	# Si no, conectamos finished para reiniciarla
	music_player.finished.connect(_on_music_finished)

func _on_music_finished() -> void:
	music_player.play()

func play_game_music(fade_duration: float = 0.5) -> void:
	_play_music_stream(game_music_stream, "game", fade_duration)

func play_menu_music(fade_duration: float = 0.5) -> void:
	_play_music_stream(menu_music_stream, "menu", fade_duration)

func play_music() -> void:
	play_game_music()

func _play_music_stream(stream: AudioStream, key: String, fade_duration: float = 0.5) -> void:
	if not music_player:
		return
	if music_tween:
		music_tween.kill()
	if current_music_key == key and music_player.playing:
		music_player.volume_db = music_volume_db
		return
	if music_player.playing:
		var fade_out := create_tween()
		music_tween = fade_out
		fade_out.tween_property(music_player, "volume_db", -80.0, fade_duration)
		await fade_out.finished
		if music_tween != fade_out:
			return
	music_player.stop()
	music_player.stream = stream
	current_music_key = key
	music_player.volume_db = -80.0 if fade_duration > 0.0 else music_volume_db
	music_player.play()
	if fade_duration > 0.0:
		var fade_in := create_tween()
		music_tween = fade_in
		fade_in.tween_property(music_player, "volume_db", music_volume_db, fade_duration)

func stop_music() -> void:
	current_music_key = ""
	music_player.stop()

func _play_sfx(stream: AudioStream, key: String, pitch_variation: float = 0.0) -> void:
	# Cooldown anti-spam
	var now := Time.get_ticks_msec() / 1000.0
	if last_played_times.has(key):
		if now - last_played_times[key] < MIN_COOLDOWN:
			return
	last_played_times[key] = now
	
	# Buscar un player libre
	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = sfx_volume_db
			if pitch_variation > 0.0:
				p.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
			else:
				p.pitch_scale = 1.0
			p.play()
			return
	# Si todos están ocupados, no suena (mejor que cortar uno)
	
func fade_music_to(target_db_offset: float, duration: float = 0.5) -> void:
	# target_db_offset es un multiplicador 0-1. 0.3 = 30% volumen
	if not music_player:
		return
	if music_tween:
		music_tween.kill()
	var target_db := music_volume_db + linear_to_db(target_db_offset)
	music_tween = create_tween()
	music_tween.tween_property(music_player, "volume_db", target_db, duration)

func play_slice() -> void:
	_play_sfx(slice_stream, "slice", 0.15)

func play_orc_death() -> void:
	_play_sfx(orc_death_stream, "orc_death", 0.2)

func play_player_death() -> void:
	_play_sfx(player_death_stream, "player_death")

func play_pickup() -> void:
	_play_sfx(pickup_stream, "pickup", 0.1)
