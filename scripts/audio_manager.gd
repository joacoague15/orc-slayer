# scripts/audio_manager.gd
extends Node

# Streams de audio (los cargamos una vez y los reusamos)
var slice_stream: AudioStream = preload("res://audio/sfx/slice.wav")
var orc_death_stream: AudioStream = preload("res://audio/sfx/orc_death.wav")
var player_death_stream: AudioStream = preload("res://audio/sfx/player_death.wav")
var pickup_stream: AudioStream = preload("res://audio/sfx/pickup.wav")
var berserker_attack_stream: AudioStream = preload("res://audio/sfx/berserker_attack.wav")
var mage_attack_stream: AudioStream = preload("res://audio/sfx/mage_attack.wav")
var archer_attack_stream: AudioStream = preload("res://audio/sfx/archer_attack.wav")
# Música del menú.
var menu_music_stream: AudioStream = preload("res://audio/music/contemplation.mp3")
# Música del juego: arranca con el intro y luego cruza al loop de combate.
var game_intro_stream: AudioStream = preload("res://audio/music/revenges_waiting_mini_combat_loop.ogg")
var game_loop_stream: AudioStream = preload("res://audio/music/pixel-damnation-_combat-loop_.ogg")

# Pool de players para SFX (para que varios sonidos puedan superponerse)
const SFX_POOL_SIZE: int = 12
var sfx_players: Array[AudioStreamPlayer] = []
# Dos players para hacer crossfade suave entre pistas (intro -> loop, menú <-> juego).
var music_player_a: AudioStreamPlayer
var music_player_b: AudioStreamPlayer
var music_fg: AudioStreamPlayer       # player que suena en primer plano
var music_tween: Tween
var current_music_key: String = ""
# Se incrementa en cada cambio de música; cancela transiciones diferidas (intro->loop)
# si el jugador navega a otra pantalla antes de que disparen.
var music_generation: int = 0

# Volúmenes (en dB, 0 es normal, -10 es más bajo, 6 es más alto)
@export var sfx_volume_db: float = -4.0
@export var music_volume_db: float = -12.0
# Cuánto baja la música en game over (offset en dB sobre el volumen normal). La
# canción NO para: solo se duckea y se restaura al reiniciar. -10.5 dB ≈ 30%.
@export var music_duck_db: float = -10.5
# Duración del crossfade entre el intro y el loop de combate.
@export var music_crossfade: float = 1.2

# Game over baja el volumen pero la pista sigue sonando; el reinicio la restaura.
var music_ducked: bool = false

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
	
	# Crear los dos music players para crossfade. Empiezan en silencio y sin
	# pista hasta que se pida reproducir música.
	music_player_a = _make_music_player()
	music_player_b = _make_music_player()
	music_fg = null

func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = -80.0
	p.bus = "Master"
	add_child(p)
	return p

# Menú: contemplation en loop.
func play_menu_music(fade_duration: float = 0.5) -> void:
	music_generation += 1
	music_ducked = false
	_crossfade_to(menu_music_stream, "menu", true, fade_duration)

# Juego: arranca con el intro (una vez) y, cerca de su final, cruza suave al
# loop de combate, que queda sonando indefinidamente. Se usa al entrar al juego
# desde el menú (New Game o Continue), NO al reiniciar tras game over.
func play_game_music(fade_duration: float = 0.6) -> void:
	music_generation += 1
	var gen := music_generation
	music_ducked = false
	_crossfade_to(game_intro_stream, "game_intro", false, fade_duration)

	var intro_len := game_intro_stream.get_length()
	if intro_len <= 0.0:
		# Sin duración legible: vamos directo al loop.
		_crossfade_to(game_loop_stream, "game_loop", true, music_crossfade)
		return
	# Empezar el crossfade un poco antes de que el intro termine para que se solapen.
	var wait := maxf(intro_len - music_crossfade, 0.05)
	await get_tree().create_timer(wait).timeout
	# Si en el medio se cambió de música (volver al menú, game over, etc.), abortar.
	if gen != music_generation:
		return
	_crossfade_to(game_loop_stream, "game_loop", true, music_crossfade)

func play_music() -> void:
	play_game_music()

# Cruza del player en primer plano al otro: levanta la pista nueva y baja la
# vieja en paralelo. loop_enabled controla si la pista loopea sola (lo seteamos
# por código porque los .import vienen con loop=false).
func _crossfade_to(stream: AudioStream, key: String, loop_enabled: bool, fade_duration: float) -> void:
	if not music_player_a or not music_player_b:
		return
	_set_stream_loop(stream, loop_enabled)
	if music_tween:
		music_tween.kill()

	var incoming: AudioStreamPlayer = music_player_b if music_fg == music_player_a else music_player_a
	var outgoing: AudioStreamPlayer = music_fg

	# Defensivo: si no hay saliente conocido (music_fg en null, p. ej. tras
	# stop_music), frenamos el otro player por si quedó una pista huérfana sonando,
	# para que no siga "desde donde estaba" por debajo de la pista nueva.
	if outgoing == null:
		var other: AudioStreamPlayer = music_player_a if incoming == music_player_b else music_player_b
		other.stop()

	# Arrancar limpio: si en este player quedó una pista huérfana sonando (p. ej.
	# un crossfade interrumpido), la frenamos antes de reusarlo.
	incoming.stop()
	incoming.stream = stream
	incoming.volume_db = -80.0 if fade_duration > 0.0 else _fg_target_volume()
	incoming.play()
	current_music_key = key
	music_fg = incoming

	if fade_duration <= 0.0:
		if outgoing:
			outgoing.stop()
		incoming.volume_db = _fg_target_volume()
		return

	music_tween = create_tween().set_parallel(true)
	music_tween.tween_property(incoming, "volume_db", _fg_target_volume(), fade_duration)
	if outgoing and outgoing.playing:
		music_tween.tween_property(outgoing, "volume_db", -80.0, fade_duration)
		music_tween.chain().tween_callback(outgoing.stop)

func _set_stream_loop(stream: AudioStream, enabled: bool) -> void:
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.set("loop", enabled)

func stop_music() -> void:
	music_generation += 1
	current_music_key = ""
	if music_tween:
		music_tween.kill()
	if music_player_a:
		music_player_a.stop()
	if music_player_b:
		music_player_b.stop()
	music_fg = null

func _play_sfx(stream: AudioStream, key: String, pitch_variation: float = 0.0, volume_multiplier: float = 1.0) -> void:
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
			p.volume_db = sfx_volume_db + linear_to_db(volume_multiplier)
			if pitch_variation > 0.0:
				p.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
			else:
				p.pitch_scale = 1.0
			p.play()
			return
	# Si todos están ocupados, no suena (mejor que cortar uno)
	
# Volumen objetivo del player en primer plano, según esté duckeado o no.
func _fg_target_volume() -> float:
	return music_volume_db + (music_duck_db if music_ducked else 0.0)

# ¿Está sonando la música del juego (intro o loop)? Sirve para distinguir, al
# entrar a main, un reinicio tras game over (sigue el juego) de una entrada
# fresca desde el menú.
func is_game_music_active() -> bool:
	return current_music_key == "game_intro" or current_music_key == "game_loop"

# Game over / reinicio: baja o restaura el volumen SIN cortar la pista. La música
# sigue sonando desde donde está; solo cambia el volumen. No toca la transición
# intro->loop pendiente (el crossfade ya usa _fg_target_volume()).
func set_music_ducked(ducked: bool, duration: float = 0.5) -> void:
	music_ducked = ducked
	if not music_fg:
		return
	if music_tween:
		music_tween.kill()
	music_tween = create_tween()
	music_tween.tween_property(music_fg, "volume_db", _fg_target_volume(), duration)

func play_slice() -> void:
	_play_sfx(slice_stream, "slice", 0.15)

func play_orc_death() -> void:
	_play_sfx(orc_death_stream, "orc_death", 0.2)

func play_player_death() -> void:
	_play_sfx(player_death_stream, "player_death")

func play_pickup() -> void:
	_play_sfx(pickup_stream, "pickup", 0.1)

func play_berserker_attack() -> void:
	# Volumen 0.42 = 30% menos que el 0.6 original.
	_play_sfx(berserker_attack_stream, "berserker_attack", 0.05, 0.42)

func play_mage_attack() -> void:
	_play_sfx(mage_attack_stream, "mage_attack", 0.05, 1.5)

func play_archer_attack() -> void:
	_play_sfx(archer_attack_stream, "archer_attack", 0.05, 0.8)
