# scripts/start_screen.gd
extends Control

@onready var prompt_label: Label = $VBoxContainer/PromptLabel
@onready var highscore_label: Label = $VBoxContainer/HighscoreLabel

var blink_time: float = 0.0

func _ready() -> void:
	# Mostrar highscore si existe
	if GameState.highscore > 0:
		highscore_label.text = "Highscore: %d" % GameState.highscore
	else:
		highscore_label.text = ""

func _process(delta: float) -> void:
	blink_time += delta
	# Onda sinusoidal entre 0.4 y 1.0 de opacidad
	var alpha := 0.7 + 0.3 * sin(blink_time * 3.0)
	prompt_label.modulate.a = alpha

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			start_game()

func start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
