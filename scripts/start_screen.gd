# scripts/start_screen.gd
extends Control

const SPAWN_PANEL_FONT := preload("res://fonts/PressStart2P-Regular.ttf")
const SPAWN_ENEMY_ROWS: Array[Dictionary] = [
	{"key": "normal", "label": "GRUNT"},
	{"key": "archer", "label": "ARCHER"},
	{"key": "mage", "label": "MAGE"},
	{"key": "berserker", "label": "BERSERKER"},
]

@onready var prompt_label: Label = $VBoxContainer/PromptLabel
@onready var highscore_label: Label = $VBoxContainer/HighscoreLabel
@onready var hero_sprite: Sprite2D = $main_menu_sprite

var blink_time: float = 0.0
var spawn_panel: PanelContainer
var spawn_panel_rows: Dictionary = {}

func _ready() -> void:
	AudioManager.play_menu_music()
	
	# Mostrar highscore si existe
	if GameState.highscore > 0:
		highscore_label.text = "Highscore: %d" % GameState.highscore
	else:
		highscore_label.text = ""

	_build_spawn_panel()
	animate_intro()
	
func animate_intro() -> void:
	hero_sprite.modulate.a = 0.0
	hero_sprite.position.x -= 50  # arranca 50px a la izquierda
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(hero_sprite, "modulate:a", 1.0, 0.8)
	tween.tween_property(hero_sprite, "position:x", hero_sprite.position.x + 50, 0.8).set_ease(Tween.EASE_OUT)
	if spawn_panel:
		spawn_panel.modulate.a = 0.0
		tween.tween_property(spawn_panel, "modulate:a", 1.0, 0.8)

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
	# Bloqueamos input mientras hace la transición
	set_process_unhandled_input(false)
	
	# Fade-out de todo
	var tween := create_tween().set_parallel(true)
	tween.tween_property(hero_sprite, "modulate:a", 0.0, 0.4)
	tween.tween_property($VBoxContainer, "modulate:a", 0.0, 0.4)
	if spawn_panel:
		tween.tween_property(spawn_panel, "modulate:a", 0.0, 0.4)
	
	# Esperar a que termine el fade y cambiar de escena
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _build_spawn_panel() -> void:
	spawn_panel = PanelContainer.new()
	spawn_panel.name = "TestSpawnsPanel"
	spawn_panel.anchor_left = 0.71
	spawn_panel.anchor_top = 0.11
	spawn_panel.anchor_right = 0.98
	spawn_panel.anchor_bottom = 0.89
	spawn_panel.offset_left = 0.0
	spawn_panel.offset_top = 0.0
	spawn_panel.offset_right = 0.0
	spawn_panel.offset_bottom = 0.0
	spawn_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.025, 0.02, 0.88)
	panel_style.border_color = Color(0.45, 0.7, 0.3, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left = 18
	panel_style.content_margin_right = 18
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	spawn_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(spawn_panel)
	
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	spawn_panel.add_child(content)
	
	var title := _make_panel_label("TEST SPAWNS", 16, Color(1.0, 0.85, 0.2, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	
	for enemy in SPAWN_ENEMY_ROWS:
		_add_spawn_enemy_row(content, enemy["key"], enemy["label"])
	
	var reset_button := Button.new()
	reset_button.text = "RESET"
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.pressed.connect(_on_spawn_weights_reset_pressed)
	content.add_child(reset_button)

func _add_spawn_enemy_row(parent: VBoxContainer, enemy_key: String, display_name: String) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	row.add_child(header)
	
	var toggle := CheckButton.new()
	toggle.text = display_name
	toggle.button_pressed = GameState.is_spawn_enemy_enabled(enemy_key)
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.custom_minimum_size = Vector2(145, 0)
	header.add_child(toggle)
	
	var value_label := _make_panel_label(_format_spawn_multiplier(enemy_key), 12, Color.WHITE)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(value_label)
	
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 3.0
	slider.step = 0.1
	slider.value = GameState.get_spawn_enemy_weight_multiplier(enemy_key)
	slider.editable = toggle.button_pressed
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	
	spawn_panel_rows[enemy_key] = {
		"toggle": toggle,
		"slider": slider,
		"value_label": value_label,
	}
	
	toggle.toggled.connect(_on_spawn_enemy_toggled.bind(enemy_key))
	slider.value_changed.connect(_on_spawn_enemy_weight_changed.bind(enemy_key))

func _on_spawn_enemy_toggled(enabled: bool, enemy_key: String) -> void:
	GameState.set_spawn_enemy_enabled(enemy_key, enabled)
	_sync_spawn_enemy_row(enemy_key)

func _on_spawn_enemy_weight_changed(value: float, enemy_key: String) -> void:
	GameState.set_spawn_enemy_weight_multiplier(enemy_key, value)
	_sync_spawn_enemy_row(enemy_key)

func _on_spawn_weights_reset_pressed() -> void:
	GameState.reset_spawn_enemy_weights()
	for enemy in SPAWN_ENEMY_ROWS:
		_sync_spawn_enemy_row(enemy["key"])

func _sync_spawn_enemy_row(enemy_key: String) -> void:
	if not spawn_panel_rows.has(enemy_key):
		return
	var row: Dictionary = spawn_panel_rows[enemy_key]
	var toggle: CheckButton = row["toggle"]
	var slider: HSlider = row["slider"]
	var value_label: Label = row["value_label"]
	
	toggle.set_pressed_no_signal(GameState.is_spawn_enemy_enabled(enemy_key))
	slider.set_value_no_signal(GameState.get_spawn_enemy_weight_multiplier(enemy_key))
	slider.editable = toggle.button_pressed
	value_label.text = _format_spawn_multiplier(enemy_key)
	value_label.modulate = Color.WHITE if toggle.button_pressed else Color(0.65, 0.65, 0.65, 1.0)

func _format_spawn_multiplier(enemy_key: String) -> String:
	if not GameState.is_spawn_enemy_enabled(enemy_key):
		return "OFF"
	return "x%.1f" % GameState.get_spawn_enemy_weight_multiplier(enemy_key)

func _make_panel_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", SPAWN_PANEL_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
