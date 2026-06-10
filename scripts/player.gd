# scripts/player.gd
extends CharacterBody2D

signal died
signal dash_started
signal dash_finished
signal dash_ready

@export var move_speed: float = 390.0          # velocidad final (máxima) — valor del context.md
@export var acceleration: float = 3200.0       # px/s² hasta la velocidad final
@export var friction: float = 4200.0           # px/s² al soltar (alto = freno casi instantáneo)
@export var rotation_speed: float = 16.0       # rad/s de giro del sprite hacia el mouse
@export var slice_speed_multiplier: float = 0.5
@export var slice_scene: PackedScene

@export_group("Dash")
@export var dash_speed: float = 1270.75
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.75
@export var dash_ghost_count: int = 7
@export var dash_ghost_lifetime: float = 0.22
@export var dash_ghost_color: Color = Color(0.8, 1.1, 1.7, 0.7)      # cian sobreexpuesto: la estela resalta sobre el fondo oscuro
@export var dash_ghost_scale: float = 1.12                           # leve "bloom" de la afterimage

# Tiempo de espera antes de volver a idle desde slice_2_end
@export var return_to_idle_delay: float = 2.0

# Multiplicador de velocidad de animación cuando se mueve (idle)
@export var idle_walk_speed_mult: float = 2.0

@export var knockback_friction: float = 2600.0  # px/s² con que se frena el rebote

var is_dead: bool = false
var is_dashing: bool = false
var is_invulnerable: bool = false
var can_dash: bool = true
var last_move_direction: Vector2 = Vector2.DOWN
var dash_direction: Vector2 = Vector2.DOWN
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_ghost_timer: float = 0.0
var dash_ghosts_spawned: int = 0

var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0

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
	
	var input_vector := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).normalized()
	
	if input_vector != Vector2.ZERO and not is_dashing:
		last_move_direction = input_vector
	
	_update_dash_cooldown(delta)
	
	if is_dashing:
		_process_dash(delta)
		move_and_slide()
		_clamp_to_arena()
		return

	if Input.is_action_just_pressed("dash"):
		_try_dash()
		if is_dashing:
			move_and_slide()
			_clamp_to_arena()
			return

	# Knockback (rebote contra el escudo del boss): anula el control mientras dura.
	if knockback_timer > 0.0:
		knockback_timer -= delta
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
		move_and_slide()
		_clamp_to_arena()
		return

	# Movimiento con aceleración hacia la velocidad final y freno al soltar.
	if input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(input_vector * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()
	_clamp_to_arena()

	# Rotación del sprite hacia el mouse, girando a rotation_speed (no instantáneo).
	var mouse_pos := get_global_mouse_position()
	var target_rotation := (mouse_pos - global_position).angle() - PI / 2
	sprite.rotation = rotate_toward(sprite.rotation, target_rotation, rotation_speed * delta)
	
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
	if Input.is_action_pressed("attack"):
		_try_attack()

func _is_in_slice_animation() -> bool:
	return slice_state == SliceState.TRANSITIONING_TO_SLICE_1 \
		or slice_state == SliceState.SLICING_2

func _try_attack() -> void:
	if is_dashing:
		return
	
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
	get_parent().add_child(slice)

func _try_dash() -> void:
	if not can_dash:
		return
	if last_move_direction == Vector2.ZERO:
		return
	
	is_dashing = true
	is_invulnerable = true
	can_dash = false
	dash_direction = last_move_direction.normalized()
	dash_timer = dash_duration
	dash_ghost_timer = dash_duration / max(float(dash_ghost_count), 1.0)
	dash_ghosts_spawned = 0
	velocity = dash_direction * dash_speed
	
	$Camera2D.shake(4.0)
	_spawn_dash_ghost()
	dash_started.emit()

func _process_dash(delta: float) -> void:
	dash_timer -= delta
	dash_ghost_timer -= delta
	velocity = dash_direction * dash_speed
	
	if dash_ghost_timer <= 0.0 and dash_timer > 0.0 and dash_ghosts_spawned < dash_ghost_count:
		_spawn_dash_ghost()
		dash_ghost_timer = dash_duration / max(float(dash_ghost_count), 1.0)
	
	if dash_timer <= 0.0:
		_finish_dash()

func _finish_dash() -> void:
	is_dashing = false
	is_invulnerable = false
	velocity = Vector2.ZERO
	dash_cooldown_timer = dash_cooldown
	dash_finished.emit()

func _update_dash_cooldown(delta: float) -> void:
	if can_dash:
		return
	if is_dashing:
		return
	
	dash_cooldown_timer -= delta
	if dash_cooldown_timer <= 0.0:
		can_dash = true
		_flash_dash_ready()
		dash_ready.emit()

func _spawn_dash_ghost() -> void:
	if dash_ghost_count <= 0:
		return
	
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if not texture:
		return
	
	dash_ghosts_spawned += 1
	
	var ghost := Sprite2D.new()
	ghost.texture = texture
	ghost.global_position = global_position
	ghost.global_rotation = sprite.global_rotation
	ghost.global_scale = sprite.global_scale * dash_ghost_scale
	ghost.z_index = sprite.z_index + 20
	# Degradé: las afterimages viejas (cola) arrancan más tenues que las recientes,
	# para una estela que se desvanece suave hacia atrás.
	var t := float(dash_ghosts_spawned) / maxf(float(dash_ghost_count), 1.0)
	var ghost_color := dash_ghost_color
	ghost_color.a *= lerpf(0.55, 1.0, t)
	ghost.modulate = ghost_color
	get_parent().add_child(ghost)
	
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, dash_ghost_lifetime)
	tween.tween_callback(ghost.queue_free)

func _flash_dash_ready() -> void:
	# Destello cian sobreexpuesto + pop de escala: feedback claro de "dash listo".
	var base_scale := sprite.scale
	var flash := create_tween()
	flash.tween_property(sprite, "modulate", Color(1.8, 2.5, 3.0, 1.0), 0.05)
	flash.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	var pop := create_tween()
	pop.tween_property(sprite, "scale", base_scale * 1.14, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(sprite, "scale", base_scale, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _clamp_to_arena() -> void:
	# Mantiene al jugador dentro del arena circular. No es colisión física: la
	# "ronda" es decorativa y el límite se aplica acá, respetando la regla de que
	# el jugador atraviesa enemigos. Se aplica también durante el dash, así no se
	# puede dashear afuera del arena.
	if GameState.arena_radius <= 0.0:
		return
	var offset := global_position - GameState.arena_center
	var max_dist := GameState.arena_radius - GameState.arena_player_margin
	if offset.length() > max_dist:
		global_position = GameState.arena_center + offset.normalized() * max_dist

func is_damage_invulnerable() -> bool:
	return is_invulnerable or is_dashing

# Empuje del jugador alejándolo de `from_position` (ej. al rebotar contra el escudo del boss).
func apply_knockback(strength: float, from_position: Vector2) -> void:
	if is_dead:
		return
	var dir := global_position - from_position
	if dir == Vector2.ZERO:
		dir = -last_move_direction
	knockback_velocity = dir.normalized() * strength
	knockback_timer = 0.2

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
	if is_damage_invulnerable():
		return
	is_dead = true
	AudioManager.play_player_death()
	$Camera2D.shake(15.0, 3.0)
	died.emit()
	hide()
