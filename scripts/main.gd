# scripts/main.gd
extends Node2D

const BOSS_WAVE_NUMBER: int = 6
const LOW_RES_VIEWPORT_SIZE: Vector2i = Vector2i(426, 240)
const GAME_VIEW_WORLD_SIZE: Vector2 = Vector2(1280.0, 720.0)
const GAME_OVER_LINES: Array[Dictionary] = [
	{"enemy": "No one will mourn you here.", "knight": "I didn't come to be mourned."},
	{"enemy": "This is where your story ends.", "knight": "You don't get to write it."},
	{"enemy": "Kneel, and it will be quick.", "knight": "I kneel to no beast."},
	{"enemy": "Your bones will make fine tools.", "knight": "Come and take them."},
	{"enemy": "Your armor will rust on your corpse.", "knight": "Not today."},
	{"enemy": "The ground is hungry for you.", "knight": "Let it stay hungry."},
]
const TouchControlsScene := preload("res://scenes/touch_controls.tscn")
const LOW_RES_WORLD_NODES: Array[StringName] = [
	&"GroundFallback",
	&"GroundRain",
	&"Arena",
	&"Player",
	&"Spawner",
]

# Tracker de oleadas (pips) que aparece en la transición.
const PIP_SIZE: Vector2 = Vector2(16, 16)
const PIP_DONE: Color = Color(1, 0.85, 0.2)        # wave completada
const PIP_NEXT: Color = Color(1, 1, 1)             # la que viene (pop)
const PIP_DIM: Color = Color(0.3, 0.3, 0.34)       # pendiente
const PIP_BOSS_DIM: Color = Color(0.5, 0.16, 0.16)
const PIP_BOSS_ACTIVE: Color = Color(1, 0.2, 0.2)

@export var boss_scene: PackedScene
@export var boss_pending: bool = true
@export var boss_spawn_delay: float = 3.0
@export var boss_spawn_distance_buffer: float = 120.0
@export var wave_transition_delay: float = 2.0

@onready var low_res_output: SubViewportContainer = $LowResOutput
@onready var low_res_viewport: SubViewport = $LowResOutput/LowResViewport
@onready var low_res_world: Node2D = $LowResOutput/LowResViewport/World
@onready var player: Node2D = $Player
@onready var spawner: Node2D = $Spawner
@onready var arena: Node2D = $Arena
@onready var score_label: Label = $UI/TopLeftPanel/ScoreLabel
@onready var time_label: Label = $UI/TimeRow/TimeVBox/TimeLabel
@onready var wave_marker_label: Label = $UI/WaveMarkerLabel
@onready var wave_tracker: VBoxContainer = $UI/WaveTracker
@onready var wave_fromto_label: Label = $UI/WaveTracker/WaveFromToLabel
@onready var wave_pip_row: HBoxContainer = $UI/WaveTracker/PipRow
@onready var wave_progress_container: Control = $UI/WaveProgressContainer
@onready var wave_progress_fill_clip: Control = $UI/WaveProgressContainer/WaveProgressFillClip
@onready var wave_progress_fill: TextureRect = $UI/WaveProgressContainer/WaveProgressFillClip/WaveProgressFill

# Nuevos refs para el game over screen
@onready var game_over_screen: Control = $UI/GameOverScreen
@onready var overlay: ColorRect = $UI/GameOverScreen/Overlay
@onready var go_background: TextureRect = $UI/GameOverScreen/Background
@onready var go_enemy_quote: Label = $UI/GameOverScreen/StatsContainer/EnemyQuoteLabel
@onready var go_response_button: TextureButton = $UI/GameOverScreen/StatsContainer/KnightResponseButton
@onready var go_response_label: Label = $UI/GameOverScreen/StatsContainer/KnightResponseButton/Label
@onready var go_score: Label = $UI/GameOverScreen/StatsContainer/ScoreLabel
@onready var go_kills: Label = $UI/GameOverScreen/StatsContainer/KillBreakdownLabel
@onready var go_time: Label = $UI/GameOverScreen/StatsContainer/TimeLabel
@onready var go_highscore: Label = $UI/GameOverScreen/StatsContainer/HighscoreLabel

@onready var combo_value_label: Label = $UI/ComboContainer/ComboVBox/ComboValueLabel
@onready var combo_timer_bar: ProgressBar = $UI/ComboContainer/ComboVBox/ComboTimerBar

var boss_spawn_started: bool = false
var boss_instance: Node2D
var wave_transition_running: bool = false
var wave_progress_ratio: float = 0.0
var game_over_button_hovered: bool = false
var game_over_button_tween: Tween
var wave_pips: Array[ColorRect] = []

func _ready() -> void:
	_setup_low_res_render()
	GameState.reset_score()
	GameState.game_over = false
	player.died.connect(_on_player_died)
	GameState.score_changed.connect(_on_score_changed)
	GameState.combo_changed.connect(_on_combo_changed)
	GameState.kill_count_changed.connect(_on_kill_count_changed)
	spawner.wave_started.connect(_on_wave_started)
	spawner.wave_completed.connect(_on_wave_completed)
	spawner.boss_wave_reached.connect(_on_boss_wave_reached)
	score_label.text = "0"
	time_label.text = "0:00"
	combo_value_label.text = ""
	combo_timer_bar.modulate.a = 0.0
	wave_marker_label.modulate.a = 0.0
	_build_wave_pips()
	wave_tracker.modulate.a = 0.0
	wave_progress_container.visible = true
	wave_progress_container.resized.connect(_sync_wave_progress_layout)
	_set_wave_progress_ratio(0.0)
	
	# Asegurar que el game over screen arranque invisible
	game_over_screen.modulate.a = 1.0  # el container sí está activo
	overlay.modulate.a = 0.0
	go_background.modulate.a = 0.0
	go_enemy_quote.modulate.a = 0.0
	go_response_button.modulate.a = 0.0
	go_response_button.disabled = true
	go_response_button.pressed.connect(_on_game_over_response_pressed)
	go_response_button.mouse_entered.connect(_on_game_over_button_mouse_entered)
	go_response_button.mouse_exited.connect(_on_game_over_button_mouse_exited)
	go_response_button.button_down.connect(_on_game_over_button_down)
	go_response_button.button_up.connect(_on_game_over_button_up)
	_update_game_over_button_pivot()
	go_score.modulate.a = 0.0
	go_kills.modulate.a = 0.0
	go_time.modulate.a = 0.0
	go_highscore.modulate.a = 0.0
	_setup_touch_controls()
	# Si ya venía sonando la música del juego, esto es un reinicio tras game over:
	# la música NO se corta, solo se restaura el volumen (sigue desde donde estaba).
	# Si no (venimos del menú: New Game o Continue), arranca el intro -> loop.
	if AudioManager.is_game_music_active():
		AudioManager.set_music_ducked(false)
	else:
		AudioManager.play_game_music()
	spawner.start_waves()

func _setup_touch_controls() -> void:
	# Solo en dispositivos táctiles (celular/web táctil). En desktop no se instancia
	# y el control sigue siendo 100% teclado + mouse.
	if not DisplayServer.is_touchscreen_available():
		return
	var tc := TouchControlsScene.instantiate()
	add_child(tc)
	player.touch_source = tc
	# Al morir, los sticks estorban y taparían el botón de reinicio: se ocultan.
	player.died.connect(func() -> void: tc.visible = false)

func _setup_low_res_render() -> void:
	_resize_low_res_output()
	get_viewport().size_changed.connect(_resize_low_res_output)
	
	for node_name in LOW_RES_WORLD_NODES:
		var node := get_node_or_null(NodePath(node_name))
		if not node:
			continue
		node.reparent(low_res_world, true)
	
	var camera := player.get_node_or_null("Camera2D")
	if camera is Camera2D:
		camera.zoom = Vector2(
			float(LOW_RES_VIEWPORT_SIZE.x) / GAME_VIEW_WORLD_SIZE.x,
			float(LOW_RES_VIEWPORT_SIZE.y) / GAME_VIEW_WORLD_SIZE.y
		)
		camera.make_current()
		_apply_camera_arena_limits(camera)

func _apply_camera_arena_limits(camera: Camera2D) -> void:
	# La cámara sigue al jugador pero frena en el borde del arena, así nunca se
	# ve vacío más allá de la ronda. Arena_ring.gd ya publicó la geometría.
	if GameState.arena_radius <= 0.0:
		return
	camera.limit_left = int(GameState.arena_center.x - GameState.arena_radius)
	camera.limit_right = int(GameState.arena_center.x + GameState.arena_radius)
	camera.limit_top = int(GameState.arena_center.y - GameState.arena_radius)
	camera.limit_bottom = int(GameState.arena_center.y + GameState.arena_radius)

func _resize_low_res_output() -> void:
	low_res_output.size = get_viewport_rect().size

func _process(_delta: float) -> void:
	if not player.is_dead:
		time_label.text = format_time(GameState.time_survived)
		# Actualizar barra de combo
		if GameState.combo > 0:
			var ratio: float = GameState.combo_timer / GameState.COMBO_TIMEOUT
			combo_timer_bar.value = ratio * 100.0

func _on_score_changed(new_score: int) -> void:
	score_label.text = "%d" % new_score
	# Bounce animation
	score_label.scale = Vector2(1.2, 1.2)
	var tween := create_tween()
	tween.tween_property(score_label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_kill_count_changed(_kill_count: int) -> void:
	if boss_spawn_started or wave_transition_running:
		_update_wave_progress_bar()
		return
	spawner.notify_enemy_killed()
	_update_wave_progress_bar()

func _on_wave_started(wave_number: int, kills_required: int) -> void:
	# Persistir la wave alcanzada: si el jugador muere, retoma desde acá.
	GameState.set_saved_wave(wave_number)
	if wave_number >= BOSS_WAVE_NUMBER:
		wave_progress_container.visible = false
		return
	wave_progress_container.visible = true
	_set_wave_progress_ratio(0.0)
	# El banner escala en tamaño y color con la intensidad de la wave.
	var emphasis: float = 1.0 + float(mini(wave_number - 1, 6)) * 0.07
	_show_wave_marker("WAVE %d" % wave_number, "", _wave_accent_color(wave_number), emphasis)
	# La horda embiste: la ronda se sacude hacia adentro + golpe de cámara.
	if arena and arena.has_method("play_horde_surge"):
		arena.play_horde_surge()
	var surge_camera := player.get_node_or_null("Camera2D")
	if surge_camera and surge_camera.has_method("shake"):
		surge_camera.shake(6.0)

func _wave_accent_color(wave_number: int) -> Color:
	# Más alta la wave, más caliente/peligroso el color del banner.
	if wave_number >= 4:
		return Color(0.7, 0.2, 0.9)   # púrpura
	elif wave_number >= 3:
		return Color(1.0, 0.2, 0.2)   # rojo
	elif wave_number >= 2:
		return Color(1.0, 0.5, 0.1)   # naranja
	return Color(1.0, 0.85, 0.2)      # gold

func _update_wave_progress_bar() -> void:
	var kills_required: int = spawner.get_current_wave_kills_required()
	if kills_required <= 0:
		_set_wave_progress_ratio(0.0)
		return
	var current_wave_kills: int = spawner.get_current_wave_kills()
	_set_wave_progress_ratio(clampf(float(current_wave_kills) / float(kills_required), 0.0, 1.0))

func _set_wave_progress_ratio(ratio: float) -> void:
	wave_progress_ratio = ratio
	_sync_wave_progress_layout()

func _sync_wave_progress_layout() -> void:
	var full_size := wave_progress_container.size
	wave_progress_fill_clip.size = Vector2(full_size.x * wave_progress_ratio, full_size.y)
	wave_progress_fill.size = full_size

func _on_wave_completed(wave_number: int) -> void:
	if wave_transition_running:
		return
	if wave_number >= BOSS_WAVE_NUMBER - 1:
		_finish_after_last_pre_boss_wave(wave_number)
		return
	_start_wave_transition(wave_number)

func _start_wave_transition(wave_number: int) -> void:
	wave_transition_running = true
	await _wait_for_orcs_cleared()
	if GameState.game_over or player.is_dead:
		wave_transition_running = false
		return
	_set_wave_progress_ratio(1.0)
	_show_wave_tracker(wave_number, wave_number + 1)
	await get_tree().create_timer(wave_transition_delay).timeout
	if GameState.game_over or player.is_dead:
		wave_transition_running = false
		return
	_hide_wave_tracker()
	wave_transition_running = false
	spawner.start_next_wave()

func _build_wave_pips() -> void:
	# Un pip por wave: 1..(BOSS-1) de combate + el último para el boss.
	for i in range(BOSS_WAVE_NUMBER):
		var pip := ColorRect.new()
		pip.custom_minimum_size = PIP_SIZE
		pip.pivot_offset = PIP_SIZE * 0.5
		pip.color = PIP_BOSS_DIM if i == BOSS_WAVE_NUMBER - 1 else PIP_DIM
		wave_pip_row.add_child(pip)
		wave_pips.append(pip)

func _show_wave_tracker(from_wave: int, to_wave: int) -> void:
	wave_fromto_label.text = "WAVE %d  >  %d" % [from_wave, to_wave]
	_update_wave_pips(to_wave)

	wave_tracker.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(wave_tracker, "modulate:a", 1.0, 0.22)

	# Slam del texto para resaltar bien el pase de una wave a la siguiente.
	wave_fromto_label.pivot_offset = wave_fromto_label.size * 0.5
	wave_fromto_label.scale = Vector2(1.5, 1.5)
	var slam := create_tween()
	slam.tween_property(wave_fromto_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_wave_tracker() -> void:
	var tween := create_tween()
	tween.tween_property(wave_tracker, "modulate:a", 0.0, 0.3)

func _update_wave_pips(to_wave: int) -> void:
	for i in range(wave_pips.size()):
		var w: int = i + 1
		var pip: ColorRect = wave_pips[i]
		var is_boss: bool = (w == BOSS_WAVE_NUMBER)
		if w < to_wave:
			pip.color = PIP_DONE
			pip.scale = Vector2.ONE
		elif w == to_wave:
			# La que viene: se enciende con un pop.
			pip.color = PIP_BOSS_ACTIVE if is_boss else PIP_NEXT
			pip.scale = Vector2(1.7, 1.7)
			var pop := create_tween()
			pop.tween_property(pip, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			pip.color = PIP_BOSS_DIM if is_boss else PIP_DIM
			pip.scale = Vector2.ONE

func _start_boss_sequence(wave_number: int) -> void:
	boss_spawn_started = true
	wave_transition_running = true
	if spawner.has_method("set_spawning_enabled"):
		spawner.set_spawning_enabled(false)
	await _wait_for_orcs_cleared()
	if GameState.game_over or player.is_dead:
		wave_transition_running = false
		return
	_set_wave_progress_ratio(1.0)
	_show_wave_marker("WAVE %d CLEAR" % wave_number, "BOSS INCOMING")
	_clear_existing_orcs()
	
	if player.has_node("Camera2D"):
		player.get_node("Camera2D").shake(5.0)
	
	await get_tree().create_timer(boss_spawn_delay).timeout
	if GameState.game_over or player.is_dead:
		return
	spawner.start_next_wave()

func _finish_after_last_pre_boss_wave(wave_number: int) -> void:
	boss_spawn_started = true
	wave_transition_running = true
	if spawner.has_method("set_spawning_enabled"):
		spawner.set_spawning_enabled(false)
	await _wait_for_orcs_cleared()
	if GameState.game_over or player.is_dead:
		wave_transition_running = false
		return
	_set_wave_progress_ratio(1.0)
	_show_wave_marker("WAVE %d CLEAR" % wave_number, "BOSS NO HECHO")

func _on_boss_wave_reached() -> void:
	if boss_pending or not boss_scene:
		_show_boss_pending()
		return
	_spawn_boss()

func _show_boss_pending() -> void:
	_show_wave_marker("BOSS PENDING", "WARLORD NOT CONNECTED")

func _clear_existing_orcs() -> void:
	for orc in get_tree().get_nodes_in_group("orcs"):
		if not is_instance_valid(orc):
			continue
		orc.remove_from_group("orcs")
		orc.queue_free()

func _spawn_boss() -> void:
	if not boss_scene:
		return
	boss_instance = boss_scene.instantiate()
	boss_instance.global_position = _get_boss_spawn_position()
	low_res_world.add_child(boss_instance)

func _get_boss_spawn_position() -> Vector2:
	# Con arena: el jefe aparece en el punto del borde de la ronda más lejano al
	# jugador. Sin arena: anillo alrededor del centro de cámara (legacy).
	var center: Vector2
	var spawn_radius: float
	if GameState.arena_radius > 0.0:
		center = GameState.arena_center
		spawn_radius = max(GameState.arena_radius - boss_spawn_distance_buffer, 0.0)
	else:
		spawn_radius = max(GAME_VIEW_WORLD_SIZE.x, GAME_VIEW_WORLD_SIZE.y) / 2.0 + boss_spawn_distance_buffer
		center = player.global_position
		var camera := get_viewport().get_camera_2d()
		if camera:
			center = camera.global_position

	var best_position := center + Vector2.RIGHT * spawn_radius
	var best_distance := -1.0
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		var candidate := center + Vector2(cos(angle), sin(angle)) * spawn_radius
		var distance := candidate.distance_to(player.global_position)
		if distance > best_distance:
			best_distance = distance
			best_position = candidate
	return best_position

func _wait_for_orcs_cleared() -> void:
	while get_tree().get_nodes_in_group("orcs").size() > 0:
		if GameState.game_over or player.is_dead:
			return
		await get_tree().process_frame

func _show_wave_marker(title: String, subtitle: String = "", accent_color: Color = Color(1.0, 0.85, 0.2), emphasis: float = 1.0) -> void:
	wave_marker_label.text = title
	if subtitle != "":
		wave_marker_label.text += "\n%s" % subtitle
	wave_marker_label.add_theme_color_override("font_color", accent_color)
	# Pivote al centro para que el slam escale desde el medio, no desde la esquina.
	wave_marker_label.pivot_offset = wave_marker_label.size * 0.5

	# Slam con overshoot: entra grande y de golpe, asienta con rebote.
	var final_scale := Vector2.ONE * emphasis
	wave_marker_label.scale = final_scale * 1.7
	wave_marker_label.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(wave_marker_label, "modulate:a", 1.0, 0.1)
	tween.parallel().tween_property(wave_marker_label, "scale", final_scale, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if title != "BOSS PENDING":
		tween.tween_interval(1.2)
		tween.tween_property(wave_marker_label, "modulate:a", 0.0, 0.3)

func _on_combo_changed(combo: int) -> void:
	if combo >= 2:
		combo_value_label.text = "x%d" % combo
		var combo_color := get_combo_color(combo)
		combo_value_label.modulate = combo_color
		# Color de la barra también cambia
		_update_combo_bar_color(combo_color)
		# Mostrar text y bar
		combo_timer_bar.modulate.a = 1.0
		animate_combo_pop()
	else:
		combo_value_label.text = ""
		combo_timer_bar.modulate.a = 0.0
		
func _update_combo_bar_color(color: Color) -> void:
	var fill_style := combo_timer_bar.get_theme_stylebox("fill")
	if fill_style is StyleBoxFlat:
		fill_style.bg_color = color
		
func animate_combo_pop() -> void:
	combo_value_label.scale = Vector2(1.3, 1.3)
	var tween := create_tween()
	tween.tween_property(combo_value_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
func get_combo_color(combo: int) -> Color:
	if combo >= 20:
		return Color(1, 0.2, 0.2)
	elif combo >= 10:
		return Color(1, 0.5, 0.1)
	elif combo >= 5:
		return Color(1, 0.85, 0.2)
	else:
		return Color(1, 1, 1)

func _on_player_died() -> void:
	GameState.trigger_game_over()
	GameState.stop_timer()
	GameState.try_update_highscore()
	# Game over: la canción NO para ni corta, solo baja el volumen (duck). El
	# reinicio la restaura sin cortarla (ver _ready).
	AudioManager.set_music_ducked(true)
	
	# Pre-llenar labels iniciales
	var line: Dictionary = GAME_OVER_LINES.pick_random()
	go_enemy_quote.text = "\"%s\"" % String(line["enemy"])
	go_response_label.text = String(line["knight"])
	# Habilitado de inmediato: el jugador puede reiniciar apenas muere, sin esperar
	# la animación. (En gameplay sigue deshabilitado para no robar clicks de ataque.)
	go_response_button.disabled = false
	go_score.text = "Score: %d" % GameState.score
	go_kills.text = "Grunts %d   Shamans %d\nBerserkers %d   Archers %d" % [
		GameState.get_kills_of_class(&"grunt"),
		GameState.get_kills_of_class(&"mage"),
		GameState.get_kills_of_class(&"berserker"),
		GameState.get_kills_of_class(&"archer"),
	]
	go_highscore.text = "Highscore: %d" % GameState.highscore
	
	# Silencio inicial
	await get_tree().create_timer(0.25).timeout
	
	# Fade suave a negro.
	var overlay_tween := create_tween()
	overlay_tween.tween_property(overlay, "modulate:a", 1.0, 0.7)
	await overlay_tween.finished
	
	# Aparece el background de game over sobre el negro.
	var background_tween := create_tween()
	background_tween.tween_property(go_background, "modulate:a", 1.0, 0.65)
	await background_tween.finished
	await get_tree().create_timer(0.15).timeout
	
	# Cascade in de los labels iniciales
	var fade_tween := create_tween()
	fade_tween.tween_property(go_enemy_quote, "modulate:a", 1.0, 0.3)
	fade_tween.tween_interval(0.2)
	fade_tween.tween_property(go_response_button, "modulate:a", 1.0, 0.3)
	fade_tween.tween_interval(0.2)
	fade_tween.tween_property(go_score, "modulate:a", 1.0, 0.3)
	fade_tween.tween_interval(0.15)
	fade_tween.tween_property(go_kills, "modulate:a", 1.0, 0.3)

	await fade_tween.finished
	await get_tree().create_timer(0.4).timeout
	
	# Mostrar resto de stats
	print("[GAME OVER] empezando final tween")
	var final_tween := create_tween()
	final_tween.tween_property(go_highscore, "modulate:a", 1.0, 0.3)
	await final_tween.finished
	print("[GAME OVER] final tween terminado")

func _on_game_over_response_pressed() -> void:
	if not player.is_dead:
		return
	# Transición fade-to-black con carga en segundo plano (sin trabones).
	SceneTransition.transition_to_scene("res://scenes/main.tscn")

func _on_game_over_button_mouse_entered() -> void:
	if go_response_button.disabled:
		return
	game_over_button_hovered = true
	_animate_game_over_button(Vector2(1.035, 1.035), Color(1.18, 1.18, 1.18, go_response_button.modulate.a))

func _on_game_over_button_mouse_exited() -> void:
	game_over_button_hovered = false
	_animate_game_over_button(Vector2.ONE, Color(1.0, 1.0, 1.0, go_response_button.modulate.a))

func _on_game_over_button_down() -> void:
	if go_response_button.disabled:
		return
	_animate_game_over_button(Vector2(0.975, 0.975), Color(0.92, 0.92, 0.92, go_response_button.modulate.a), 0.06)

func _on_game_over_button_up() -> void:
	if go_response_button.disabled:
		return
	if game_over_button_hovered:
		_animate_game_over_button(Vector2(1.035, 1.035), Color(1.18, 1.18, 1.18, go_response_button.modulate.a), 0.08)
	else:
		_animate_game_over_button(Vector2.ONE, Color(1.0, 1.0, 1.0, go_response_button.modulate.a), 0.08)

func _animate_game_over_button(target_scale: Vector2, target_modulate: Color, duration: float = 0.12) -> void:
	if game_over_button_tween:
		game_over_button_tween.kill()
	_update_game_over_button_pivot()
	game_over_button_tween = create_tween().set_parallel(true)
	game_over_button_tween.tween_property(go_response_button, "scale", target_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	game_over_button_tween.tween_property(go_response_button, "modulate:r", target_modulate.r, duration)
	game_over_button_tween.tween_property(go_response_button, "modulate:g", target_modulate.g, duration)
	game_over_button_tween.tween_property(go_response_button, "modulate:b", target_modulate.b, duration)

func _update_game_over_button_pivot() -> void:
	go_response_button.pivot_offset = go_response_button.size * 0.5

func format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	var secs := int(seconds) % 60
	return "%d:%02d" % [minutes, secs]
