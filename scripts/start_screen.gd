# scripts/start_screen.gd
extends Control

@onready var continue_button: TextureButton = $VBoxContainer/ContinueButton
@onready var continue_label: Label = $VBoxContainer/ContinueButton/Label
@onready var start_button: TextureButton = $VBoxContainer/StartButton
@onready var highscore_label: Label = $VBoxContainer/HighscoreLabel
@onready var boss_only_toggle: CheckButton = $VBoxContainer/BossOnlyToggle
@onready var hero_sprite: Sprite2D = $main_menu_sprite

var blink_time: float = 0.0
var start_button_hovered: bool = false
var start_button_tween: Tween
# El botón "Continue" solo aparece si hay una partida a medias (saved_wave > 1).
var has_saved_run: bool = false

func _ready() -> void:
	AudioManager.play_menu_music()

	# Precargar la escena del juego en segundo plano mientras el jugador está en el
	# menú, así al tocar el botón ya está en caché y la transición no espera a cargar.
	ResourceLoader.load_threaded_request("res://scenes/main.tscn")

	# Mostrar highscore si existe
	if GameState.highscore > 0:
		highscore_label.text = "Highscore: %d" % GameState.highscore
	else:
		highscore_label.text = ""

	# Retomar partida: solo se ofrece si el jugador dejó una run en una wave > 1.
	has_saved_run = GameState.saved_wave > 1
	continue_button.visible = has_saved_run
	if has_saved_run:
		continue_label.text = "Continue (Wave %d)" % GameState.saved_wave
		continue_button.pressed.connect(continue_game)
		continue_button.mouse_entered.connect(_on_continue_button_mouse_entered)
		continue_button.mouse_exited.connect(_on_continue_button_mouse_exited)
		continue_button.button_down.connect(func() -> void: _animate_button(continue_button, Vector2(0.975, 0.975), Color(0.92, 0.92, 0.92, continue_button.modulate.a), 0.06))
		continue_button.button_up.connect(_on_continue_button_up)
		continue_button.pivot_offset = continue_button.size * 0.5

	start_button.pressed.connect(start_new_game)
	start_button.mouse_entered.connect(_on_start_button_mouse_entered)
	start_button.mouse_exited.connect(_on_start_button_mouse_exited)
	start_button.button_down.connect(_on_start_button_down)
	start_button.button_up.connect(_on_start_button_up)

	# Toggle de test "BOSS ONLY": persiste en GameState (autoload) hacia la partida.
	boss_only_toggle.button_pressed = GameState.boss_only_mode
	boss_only_toggle.toggled.connect(_on_boss_only_toggled)

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
	# Onda sinusoidal entre 0.4 y 1.0 de opacidad. Parpadea el botón primario:
	# "Continue" cuando hay partida guardada, si no "New Game".
	var alpha := 0.7 + 0.3 * sin(blink_time * 3.0)
	if has_saved_run:
		continue_button.modulate.a = alpha
		start_button.modulate.a = 1.0
	else:
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

func _on_continue_button_mouse_entered() -> void:
	start_button_hovered = true
	_animate_button(continue_button, Vector2(1.035, 1.035), Color(1.18, 1.18, 1.18, continue_button.modulate.a))

func _on_continue_button_mouse_exited() -> void:
	start_button_hovered = false
	_animate_button(continue_button, Vector2.ONE, Color(1.0, 1.0, 1.0, continue_button.modulate.a))

func _on_continue_button_up() -> void:
	if start_button_hovered:
		_animate_button(continue_button, Vector2(1.035, 1.035), Color(1.18, 1.18, 1.18, continue_button.modulate.a), 0.08)
	else:
		_animate_button(continue_button, Vector2.ONE, Color(1.0, 1.0, 1.0, continue_button.modulate.a), 0.08)

func _animate_start_button(target_scale: Vector2, target_modulate: Color, duration: float = 0.12) -> void:
	_animate_button(start_button, target_scale, target_modulate, duration)

func _animate_button(button: TextureButton, target_scale: Vector2, target_modulate: Color, duration: float = 0.12) -> void:
	if button == start_button and start_button_tween:
		start_button_tween.kill()
	button.pivot_offset = button.size * 0.5
	var tween := create_tween().set_parallel(true)
	if button == start_button:
		start_button_tween = tween
	tween.tween_property(button, "scale", target_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate:r", target_modulate.r, duration)
	tween.tween_property(button, "modulate:g", target_modulate.g, duration)
	tween.tween_property(button, "modulate:b", target_modulate.b, duration)

func _update_start_button_pivot() -> void:
	start_button.pivot_offset = start_button.size * 0.5

func _on_boss_only_toggled(pressed: bool) -> void:
	GameState.boss_only_mode = pressed

func continue_game() -> void:
	# Retoma la partida desde GameState.saved_wave (no se toca).
	_begin_transition()

func start_new_game() -> void:
	# Partida nueva: vuelve a la wave 1.
	GameState.start_new_run()
	_begin_transition()

func _begin_transition() -> void:
	# Bloqueamos input mientras hace la transición
	start_button.disabled = true
	continue_button.disabled = true
	set_process(false)  # frenar el blink de los botones
	# Transición fade-to-black con carga en segundo plano (sin trabones).
	SceneTransition.transition_to_scene("res://scenes/main.tscn")
