# scripts/player.gd
extends CharacterBody2D

signal died

@export var move_speed: float = 250.0
@export var slice_speed_multiplier: float = 0.5
@export var slice_scene: PackedScene

# Tiempo de espera antes de volver a idle desde slice_2_end
@export var return_to_idle_delay: float = 2.0

# Multiplicador de velocidad de animación cuando se mueve (idle)
@export var idle_walk_speed_mult: float = 2.0

var is_dead: bool = false

# Máquina de estados de slice
enum SliceState {
	IDLE,
	TRANSITIONING_TO_SLICE_1,
	SLICE_1_HOLD,
	SLICING_2,
	SLICE_2_HOLD,
	RETURNING_TO_IDLE,
}

var slice_state: SliceState = SliceState.IDLE
var slice_2_hold_timer: float = 0.0  # cuenta los 2 segundos en SLICE_2_HOLD

@onready var sprite: AnimatedSprite2D = $PlayerSprite

func _ready() -> void:
	sprite.play("idle")
	sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return
	
	# Movimiento
	var input_vector := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).normalized()
	
	var current_speed := move_speed
	if _is_in_slice_animation():
		current_speed *= slice_speed_multiplier
	
	velocity = input_vector * current_speed
	move_and_slide()
	
	# Rotación del sprite hacia el mouse
	var mouse_pos := get_global_mouse_position()
	sprite.rotation = (mouse_pos - global_position).angle() - PI / 2
	
	# Velocidad de animación: solo idle se acelera al moverse
	if slice_state == SliceState.IDLE:
		if input_vector.length() > 0:
			sprite.speed_scale = idle_walk_speed_mult
		else:
			sprite.speed_scale = 1.0
	else:
		sprite.speed_scale = 1.0
	
	# Timer para volver de slice_2_hold a idle
	if slice_state == SliceState.SLICE_2_HOLD:
		slice_2_hold_timer -= delta
		if slice_2_hold_timer <= 0.0:
			_start_return_to_idle()
	
	# Input de ataque
	if Input.is_action_just_pressed("attack"):
		_try_attack()

func _is_in_slice_animation() -> bool:
	return slice_state == SliceState.TRANSITIONING_TO_SLICE_1 \
		or slice_state == SliceState.SLICING_2

func _try_attack() -> void:
	match slice_state:
		SliceState.IDLE:
			_start_slice_1_from_idle()
		SliceState.SLICE_1_HOLD:
			_start_slice_2()
		SliceState.SLICE_2_HOLD:
			_start_slice_1_from_hold()
		SliceState.RETURNING_TO_IDLE:
			# Cancelar el retorno e iniciar slice_1 directamente
			_start_slice_1_from_hold()
		_:
			# TRANSITIONING_TO_SLICE_1 y SLICING_2 siguen sin interrumpirse
			pass

func _start_slice_1_from_idle() -> void:
	slice_state = SliceState.TRANSITIONING_TO_SLICE_1
	sprite.play("idle_to_slice_1")
	_spawn_slice()

func _start_slice_1_from_hold() -> void:
	# Desde slice_2_hold volvemos a hacer slice_1 (sin animación de transición desde idle)
	slice_state = SliceState.TRANSITIONING_TO_SLICE_1
	sprite.play("slice_1")
	_spawn_slice()

func _start_slice_2() -> void:
	slice_state = SliceState.SLICING_2
	sprite.play("slice_2")
	_spawn_slice()

func _start_return_to_idle() -> void:
	slice_state = SliceState.RETURNING_TO_IDLE
	sprite.play("go_to_idle_slice_2")

func _spawn_slice() -> void:
	AudioManager.play_slice()
	$Camera2D.shake(2.0)
	
	var mouse_pos := get_global_mouse_position()
	var direction := (mouse_pos - global_position).angle()
	
	var slice := slice_scene.instantiate()
	slice.position = global_position
	slice.rotation = direction
	get_tree().current_scene.add_child(slice)

func _on_animation_finished() -> void:
	match slice_state:
		SliceState.TRANSITIONING_TO_SLICE_1:
			# Termina la animación de transición o de slice_1, queda en último frame
			slice_state = SliceState.SLICE_1_HOLD
			# Quedar en el último frame
			sprite.frame = sprite.sprite_frames.get_frame_count(sprite.animation) - 1
			sprite.pause()
		SliceState.SLICING_2:
			# Termina slice_2, queda en último frame
			slice_state = SliceState.SLICE_2_HOLD
			sprite.frame = sprite.sprite_frames.get_frame_count(sprite.animation) - 1
			sprite.pause()
			slice_2_hold_timer = return_to_idle_delay
		SliceState.RETURNING_TO_IDLE:
			# Termina la animación de retorno, vamos a idle
			slice_state = SliceState.IDLE
			sprite.play("idle")
		_:
			pass

func die() -> void:
	if is_dead:
		return
	is_dead = true
	AudioManager.play_player_death()
	$Camera2D.shake(15.0, 3.0)
	died.emit()
	hide()
