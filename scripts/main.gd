# scripts/main.gd
extends Node2D

@onready var player: Node2D = $Player
@onready var spawner: Node2D = $Spawner
@onready var score_label: Label = $UI/TopLeft/VBoxContainer/ScoreLabel
@onready var time_label: Label = $UI/TopLeft/VBoxContainer/TimeLabel
@onready var combo_label: Label = $UI/TopCenter/ComboLabel

# Nuevos refs para el game over screen
@onready var game_over_screen: Control = $UI/GameOverScreen
@onready var overlay: ColorRect = $UI/GameOverScreen/Overlay
@onready var go_title: Label = $UI/GameOverScreen/StatsContainer/TitleLabel
@onready var go_score: Label = $UI/GameOverScreen/StatsContainer/ScoreLabel
@onready var go_time: Label = $UI/GameOverScreen/StatsContainer/TimeLabel
@onready var go_highscore: Label = $UI/GameOverScreen/StatsContainer/HighscoreLabel
@onready var go_prompt: Label = $UI/GameOverScreen/StatsContainer/PromptLabel

func _ready() -> void:
	GameState.reset_score()
	GameState.game_over = false
	player.died.connect(_on_player_died)
	GameState.score_changed.connect(_on_score_changed)
	GameState.combo_changed.connect(_on_combo_changed)
	score_label.text = "Score: 0"
	combo_label.text = ""
	time_label.text = "Time: 0:00"
	# Asegurar que el game over screen arranque invisible
	game_over_screen.modulate.a = 1.0  # el container sí está activo
	overlay.modulate.a = 0.0
	go_title.modulate.a = 0.0
	go_score.modulate.a = 0.0
	go_time.modulate.a = 0.0
	go_highscore.modulate.a = 0.0
	go_prompt.modulate.a = 0.0
	AudioManager.play_music()

func _process(_delta: float) -> void:
	if not player.is_dead:
		time_label.text = "Time: %s" % format_time(GameState.time_survived)

func _on_score_changed(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score

func _on_combo_changed(combo: int) -> void:
	if combo >= 2:
		combo_label.text = "x%d COMBO" % combo
		combo_label.modulate = get_combo_color(combo)
		animate_combo_pop()
	else:
		combo_label.text = ""

func get_combo_color(combo: int) -> Color:
	if combo >= 20:
		return Color(1, 0.2, 0.2)
	elif combo >= 10:
		return Color(1, 0.5, 0.1)
	elif combo >= 5:
		return Color(1, 0.85, 0.2)
	else:
		return Color(1, 1, 1)

func animate_combo_pop() -> void:
	combo_label.scale = Vector2(1.3, 1.3)
	var tween := create_tween()
	tween.tween_property(combo_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_player_died() -> void:
	print("[GAME OVER] disparado")
	GameState.trigger_game_over()
	GameState.stop_timer()
	GameState.try_update_highscore()
	
	print("[GAME OVER] antes de fade music")
	AudioManager.fade_music_to(0.3)
	print("[GAME OVER] despues de fade music")
	
	go_score.text = "Score: %d" % GameState.score
	go_time.text = "Time: %s" % format_time(GameState.time_survived)
	go_highscore.text = "Highscore: %d" % GameState.highscore
	go_prompt.text = "[R] Restart    [ESC] Menu"
	
	print("[GAME OVER] antes de await silencio")
	await get_tree().create_timer(0.4).timeout
	print("[GAME OVER] despues de await silencio")
	
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.4)
	print("[GAME OVER] tween overlay creado")
	
	await get_tree().create_timer(0.4).timeout
	print("[GAME OVER] empezando cascada")
	
	var fade_in_tween := create_tween()
	fade_in_tween.tween_property(go_title, "modulate:a", 1.0, 0.3)
	fade_in_tween.tween_interval(0.2)
	fade_in_tween.tween_property(go_score, "modulate:a", 1.0, 0.3)
	fade_in_tween.tween_interval(0.2)
	fade_in_tween.tween_property(go_time, "modulate:a", 1.0, 0.3)
	fade_in_tween.tween_interval(0.2)
	fade_in_tween.tween_property(go_highscore, "modulate:a", 1.0, 0.3)
	fade_in_tween.tween_interval(0.3)
	fade_in_tween.tween_property(go_prompt, "modulate:a", 1.0, 0.4)
	print("[GAME OVER] cascada lanzada")

func _unhandled_input(event: InputEvent) -> void:
	if not player.is_dead:
		return
	# Solo aceptar input cuando el prompt ya apareció (sino reinicia muy rápido)
	if go_prompt.modulate.a < 0.9:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()
		elif event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/start_screen.tscn")

func format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	var secs := int(seconds) % 60
	return "%d:%02d" % [minutes, secs]
