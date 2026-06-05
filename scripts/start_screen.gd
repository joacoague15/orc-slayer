# scripts/start_screen.gd
extends Control

@onready var start_button: TextureButton = $VBoxContainer/StartButton
@onready var highscore_label: Label = $VBoxContainer/HighscoreLabel
@onready var hero_sprite: Sprite2D = $main_menu_sprite

var blink_time: float = 0.0
var start_button_hovered: bool = false
var start_button_tween: Tween

func _ready() -> void:
	AudioManager.play_menu_music()
	
	# Mostrar highscore si existe
	if GameState.highscore > 0:
		highscore_label.text = "Highscore: %d" % GameState.highscore
	else:
		highscore_label.text = ""

	start_button.pressed.connect(start_game)
	start_button.mouse_entered.connect(_on_start_button_mouse_entered)
	start_button.mouse_exited.connect(_on_start_button_mouse_exited)
	start_button.button_down.connect(_on_start_button_down)
	start_button.button_up.connect(_on_start_button_up)
	_update_start_button_pivot()
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

func _on_start_button_mouse_entered() -> void:
	start_button_hovered = true
	_animate_start_button(Vector2(1.035, 1.035), Color(1.18, 1.18, 1.18, start_button.modulate.a))

func _on_start_button_mouse_exited() -> void:
	start_button_hovered = false
	_animate_start_button(Vector2.ONE, Color(1.0, 1.0, 1.0, start_button.modulate.a))

func _on_start_button_down() -> void:
	_animate_start_button(Vector2(0.975, 0.975), Color(0.92, 0.92, 0.92, start_button.modulate.a), 0.06)

func _on_start_button_up() -> void:
	if start_button_hovered:
		_animate_start_button(Vector2(1.035, 1.035), Color(1.18, 1.18, 1.18, start_button.modulate.a), 0.08)
	else:
		_animate_start_button(Vector2.ONE, Color(1.0, 1.0, 1.0, start_button.modulate.a), 0.08)

func _animate_start_button(target_scale: Vector2, target_modulate: Color, duration: float = 0.12) -> void:
	if start_button_tween:
		start_button_tween.kill()
	_update_start_button_pivot()
	start_button_tween = create_tween().set_parallel(true)
	start_button_tween.tween_property(start_button, "scale", target_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	start_button_tween.tween_property(start_button, "modulate:r", target_modulate.r, duration)
	start_button_tween.tween_property(start_button, "modulate:g", target_modulate.g, duration)
	start_button_tween.tween_property(start_button, "modulate:b", target_modulate.b, duration)

func _update_start_button_pivot() -> void:
	start_button.pivot_offset = start_button.size * 0.5

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
