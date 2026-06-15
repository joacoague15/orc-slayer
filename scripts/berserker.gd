# scripts/berserker.gd
extends "res://scripts/orc.gd"

const STALK_MIN_DURATION: float = 3.0
const STALK_MAX_DURATION: float = 10.0

@export var stalk_speed: float = 253.5
@export var attack_speed: float = 1047.8
@export var attack_hit_radius: float = 34.0
@export var stalk_min_distance: float = 150.0
@export var stalk_max_distance: float = 240.0
@export var orbit_bias: float = 0.75
# Telegraph antes de embestir: muestra que está por cargar (sin ponerse rojo).
@export var windup_duration: float = 0.4

enum BerserkerState {
	STALK,
	WINDUP,
	ATTACK,
}

var berserker_state: BerserkerState = BerserkerState.STALK
var state_timer: float = 0.0
var orbit_direction: float = 1.0
var windup_tween: Tween
var base_sprite_scale: Vector2 = Vector2.ONE  # escala nativa del sprite (la del .tscn)

func _ready() -> void:
	super()
	enemy_class = &"berserker"
	base_sprite_scale = visual.scale
	_start_stalk()

func _physics_process(delta: float) -> void:
	if GameState.game_over:
		velocity = Vector2.ZERO
		return
	if is_dead:
		return
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		return

	match berserker_state:
		BerserkerState.STALK:
			_process_stalk(delta)
		BerserkerState.WINDUP:
			_process_windup(delta)
		BerserkerState.ATTACK:
			_process_attack()

	move_and_slide()
	if berserker_state == BerserkerState.ATTACK:
		_try_hit_player()
	_face_player()

func _process_stalk(delta: float) -> void:
	state_timer -= delta
	velocity = _get_stalk_velocity()

	if state_timer <= 0.0:
		_start_windup()

func _process_windup(delta: float) -> void:
	# Se queda quieto telegrafiando la embestida durante windup_duration.
	state_timer -= delta
	velocity = Vector2.ZERO
	if state_timer <= 0.0:
		_start_attack()

func _process_attack() -> void:
	var attack_direction := (player.global_position - global_position).normalized()
	if attack_direction == Vector2.ZERO:
		attack_direction = Vector2.RIGHT
	velocity = attack_direction * attack_speed
	_try_hit_player()

func _start_stalk() -> void:
	berserker_state = BerserkerState.STALK
	state_timer = randf_range(STALK_MIN_DURATION, STALK_MAX_DURATION)
	orbit_direction = -1.0 if randf() < 0.5 else 1.0
	if windup_tween:
		windup_tween.kill()
	visual.modulate = visual_color
	visual.scale = base_sprite_scale
	visual.play("idle")

func _start_windup() -> void:
	# Telegraph de 0.4s: avisa que va a embestir. NO se pone rojo: pulso de brillo
	# (destello blanco que se intensifica) + leve agrandamiento, como energía que
	# se acumula antes del salto.
	berserker_state = BerserkerState.WINDUP
	state_timer = windup_duration
	velocity = Vector2.ZERO
	visual.play("idle")
	AudioManager.play_berserker_attack()
	_play_windup_feedback()

func _play_windup_feedback() -> void:
	if windup_tween:
		windup_tween.kill()
	visual.scale = base_sprite_scale
	visual.modulate = visual_color
	windup_tween = create_tween()
	windup_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Primer destello.
	windup_tween.tween_property(visual, "modulate", Color(1.9, 1.9, 2.1, 1.0), 0.12)
	windup_tween.parallel().tween_property(visual, "scale", base_sprite_scale * 1.14, 0.12)
	windup_tween.tween_property(visual, "modulate", visual_color, 0.10)
	windup_tween.parallel().tween_property(visual, "scale", base_sprite_scale * 1.02, 0.10)
	# Segundo destello, más fuerte, justo antes de soltar la embestida.
	windup_tween.tween_property(visual, "modulate", Color(2.3, 2.3, 2.6, 1.0), 0.10)
	windup_tween.parallel().tween_property(visual, "scale", base_sprite_scale * 1.24, 0.10)

func _start_attack() -> void:
	berserker_state = BerserkerState.ATTACK
	if windup_tween:
		windup_tween.kill()
	# Durante la carga NO se pone rojo: vuelve a su color/tamaño normal.
	visual.modulate = visual_color
	visual.scale = base_sprite_scale
	visual.play("attack")

	var camera := player.get_node_or_null("Camera2D")
	if camera and camera.has_method("shake"):
		camera.shake(3.0)

func _get_stalk_velocity() -> Vector2:
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if distance == 0.0:
		to_player = Vector2.RIGHT
		distance = 1.0

	var toward_player := to_player.normalized()
	var orbit_direction_vector := toward_player.rotated(PI / 2.0) * orbit_direction
	var radial_correction := Vector2.ZERO

	if distance > stalk_max_distance:
		radial_correction = toward_player
	elif distance < stalk_min_distance:
		radial_correction = -toward_player

	var stalk_direction := orbit_direction_vector * orbit_bias + radial_correction
	if stalk_direction == Vector2.ZERO:
		stalk_direction = orbit_direction_vector
	return stalk_direction.normalized() * stalk_speed

func _try_hit_player() -> void:
	if global_position.distance_to(player.global_position) > attack_hit_radius:
		return
	if player.has_method("die"):
		player.die()

func _face_player() -> void:
	visual.rotation = (player.global_position - global_position).angle() - PI / 2.0

func die() -> void:
	# Cortar el destello de wind-up para que no pise el color de cadáver.
	if windup_tween:
		windup_tween.kill()
	visual.scale = base_sprite_scale
	super()
