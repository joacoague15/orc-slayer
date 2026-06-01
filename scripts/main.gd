# scripts/main.gd
extends Node2D

@export var boss_scene: PackedScene
@export var boss_kill_trigger: int = 200
@export var boss_spawn_delay: float = 3.0
@export var boss_spawn_distance_buffer: float = 120.0

@onready var player: Node2D = $Player
@onready var spawner: Node2D = $Spawner
@onready var score_label: Label = $UI/TopLeftPanel/ScoreLabel
@onready var time_label: Label = $UI/TimeRow/TimeVBox/TimeLabel

# Nuevos refs para el game over screen
@onready var game_over_screen: Control = $UI/GameOverScreen
@onready var overlay: ColorRect = $UI/GameOverScreen/Overlay
@onready var go_title: Label = $UI/GameOverScreen/StatsContainer/TitleLabel
@onready var go_score: Label = $UI/GameOverScreen/StatsContainer/ScoreLabel
@onready var go_time: Label = $UI/GameOverScreen/StatsContainer/TimeLabel
@onready var go_highscore: Label = $UI/GameOverScreen/StatsContainer/HighscoreLabel
@onready var go_prompt: Label = $UI/GameOverScreen/StatsContainer/PromptLabel

@onready var combo_value_label: Label = $UI/ComboContainer/ComboVBox/ComboValueLabel
@onready var combo_timer_bar: ProgressBar = $UI/ComboContainer/ComboVBox/ComboTimerBar

@onready var anger_container: VBoxContainer = $UI/GameOverScreen/StatsContainer/AngerContainer
@onready var level_label: Label = $UI/GameOverScreen/StatsContainer/AngerContainer/LevelLabel
@onready var anger_bar: ProgressBar = $UI/GameOverScreen/StatsContainer/AngerContainer/AngerBar
@onready var anger_value_label: Label = $UI/GameOverScreen/StatsContainer/AngerContainer/AngerValueLabel

var boss_spawn_started: bool = false
var boss_instance: Node2D

func _ready() -> void:
	GameState.reset_score()
	GameState.game_over = false
	player.died.connect(_on_player_died)
	GameState.score_changed.connect(_on_score_changed)
	GameState.combo_changed.connect(_on_combo_changed)
	GameState.kill_count_changed.connect(_on_kill_count_changed)
	score_label.text = "0"
	time_label.text = "0:00"
	combo_value_label.text = ""
	combo_timer_bar.modulate.a = 0.0
	anger_container.modulate.a = 0.0
	
	# Asegurar que el game over screen arranque invisible
	game_over_screen.modulate.a = 1.0  # el container sí está activo
	overlay.modulate.a = 0.0
	go_title.modulate.a = 0.0
	go_score.modulate.a = 0.0
	go_time.modulate.a = 0.0
	go_highscore.modulate.a = 0.0
	go_prompt.modulate.a = 0.0
	AudioManager.play_game_music()

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

func _on_kill_count_changed(kill_count: int) -> void:
	if boss_spawn_started:
		return
	if kill_count < boss_kill_trigger:
		return
	_start_boss_sequence()

func _start_boss_sequence() -> void:
	boss_spawn_started = true
	if spawner.has_method("set_spawning_enabled"):
		spawner.set_spawning_enabled(false)
	_clear_existing_orcs()
	
	if player.has_node("Camera2D"):
		player.get_node("Camera2D").shake(5.0)
	
	await get_tree().create_timer(boss_spawn_delay).timeout
	if GameState.game_over or player.is_dead:
		return
	_spawn_boss()

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
	add_child(boss_instance)

func _get_boss_spawn_position() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var spawn_radius: float = max(viewport_size.x, viewport_size.y) / 2.0 + boss_spawn_distance_buffer
	var camera := get_viewport().get_camera_2d()
	var center := player.global_position
	if camera:
		center = camera.global_position
	
	var best_position := center + Vector2.RIGHT * spawn_radius
	var best_distance := -1.0
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var candidate := center + Vector2(cos(angle), sin(angle)) * spawn_radius
		var distance := candidate.distance_to(player.global_position)
		if distance > best_distance:
			best_distance = distance
			best_position = candidate
	return best_position

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
	AudioManager.fade_music_to(0.3)
	
	# Pre-llenar labels iniciales
	go_score.text = "Score: %d" % GameState.score
	go_highscore.text = "Highscore: %d" % GameState.highscore
	go_prompt.text = "[R] Restart    [Q] Menu"
	
	# Estado inicial del anger
	_update_anger_display()
	
	# Silencio inicial
	await get_tree().create_timer(0.4).timeout
	
	# Fade in del overlay
	var overlay_tween := create_tween()
	overlay_tween.tween_property(overlay, "modulate:a", 1.0, 0.4)
	await get_tree().create_timer(0.4).timeout
	
	# Cascade in de los labels iniciales
	var fade_tween := create_tween()
	fade_tween.tween_property(go_title, "modulate:a", 1.0, 0.3)
	fade_tween.tween_interval(0.2)
	fade_tween.tween_property(go_score, "modulate:a", 1.0, 0.3)
	fade_tween.tween_interval(0.3)
	fade_tween.tween_property(anger_container, "modulate:a", 1.0, 0.3)
	
	await fade_tween.finished
	await get_tree().create_timer(0.4).timeout
	
	# Conversión de score a anger
	await _animate_score_to_anger()
	
	# Mostrar resto de stats
	print("[GAME OVER] empezando final tween")
	var final_tween := create_tween()
	final_tween.tween_property(go_highscore, "modulate:a", 1.0, 0.3)
	final_tween.tween_interval(0.2)
	final_tween.tween_property(go_prompt, "modulate:a", 1.0, 0.4)
	await final_tween.finished
	print("[GAME OVER] final tween terminado")

func _animate_score_to_anger() -> void:
	var total_anger_to_add := GameState.points_to_anger(GameState.score)
	var initial_score := GameState.score
	
	if total_anger_to_add <= 0:
		go_score.text = "Score: 0"
		return
	
	var max_duration := 4.0
	var min_duration := 1.0
	var duration: float = clamp(total_anger_to_add * 0.01, min_duration, max_duration)
	
	var anger_per_second: float = float(total_anger_to_add) / duration
	var elapsed := 0.0
	var anger_added := 0
	var safety_counter := 0
	
	while anger_added < total_anger_to_add and safety_counter < 10000:
		safety_counter += 1
		var delta := get_process_delta_time()
		elapsed += delta
		
		var target_anger_added: int = min(int(anger_per_second * elapsed) + 1, total_anger_to_add)
		var anger_this_frame := target_anger_added - anger_added
		
		if anger_this_frame > 0:
			var result := GameState.add_anger(anger_this_frame)
			anger_added = target_anger_added
			
			# Calcular score visual: empieza en initial_score, baja proporcionalmente
			var progress: float = float(anger_added) / float(total_anger_to_add)
			var visual_score: int = int(initial_score * (1.0 - progress))
			go_score.text = "Score: %d" % max(0, visual_score)
			
			_update_anger_display()
			
			if result.levels_gained > 0:
				_on_level_up()
		
		await get_tree().process_frame
	
	# Forzar score final a 0 cuando termina
	go_score.text = "Score: 0"
	print("[ANGER] animación terminada, anger_added: ", anger_added)

func _update_anger_display() -> void:
	var current := GameState.get_anger_in_current_level()
	var needed := GameState.get_anger_needed_for_current_level()
	level_label.text = "LEVEL %d" % GameState.current_level
	anger_bar.max_value = needed
	anger_bar.value = current
	anger_value_label.text = "%d / %d" % [current, needed]

func _on_level_up() -> void:
	# Efecto visual: el level label hace un pop
	level_label.scale = Vector2(1.5, 1.5)
	var tween := create_tween()
	tween.tween_property(level_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Opcional: shake de la cámara
	if player.has_node("Camera2D"):
		player.get_node("Camera2D").shake(5.0)

func _unhandled_input(event: InputEvent) -> void:
	if not player.is_dead:
		return
	if go_prompt.modulate.a < 0.9:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()
		elif event.keycode == KEY_Q:
			get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M:  # tecla de reset
			GameState.reset_save()
func format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	var secs := int(seconds) % 60
	return "%d:%02d" % [minutes, secs]
