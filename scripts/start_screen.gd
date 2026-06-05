# scripts/start_screen.gd
extends Control

@onready var start_button: TextureButton = $VBoxContainer/StartButton
@onready var highscore_label: Label = $VBoxContainer/HighscoreLabel
@onready var hero_sprite: Sprite2D = $main_menu_sprite

var blink_time: float = 0.0

func _ready() -> void:
	AudioManager.play_menu_music()
	
	# Mostrar highscore si existe
	if GameState.highscore > 0:
		highscore_label.text = "Highscore: %d" % GameState.highscore
	else:
		highscore_label.text = ""

	start_button.pressed.connect(start_game)
	animate_intro()
	
func animate_intro() -> void:
	hero_sprite.modulate.a = 0.0
	hero_sprite.position.x -= 50  # arranca 50px a la izquierda
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(hero_sprite, "modulate:a", 1.0, 0.8)
	tween.tween_property(hero_sprite, "position:x", hero_sprite.position.x + 50, 0.8).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	blink_time += delta
	# Onda sinusoidal entre 0.4 y 1.0 de opacidad
	var alpha := 0.7 + 0.3 * sin(blink_time * 3.0)
	start_button.modulate.a = alpha

func start_game() -> void:
	# Bloqueamos input mientras hace la transición
	start_button.disabled = true
	
	# Fade-out de todo
	var tween := create_tween().set_parallel(true)
	tween.tween_property(hero_sprite, "modulate:a", 0.0, 0.4)
	tween.tween_property($VBoxContainer, "modulate:a", 0.0, 0.4)
	
	# Esperar a que termine el fade y cambiar de escena
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/main.tscn")
