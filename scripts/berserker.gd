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

enum BerserkerState {
	STALK,
	ATTACK,
}

var berserker_state: BerserkerState = BerserkerState.STALK
var state_timer: float = 0.0
var orbit_direction: float = 1.0

func _ready() -> void:
	super()
	enemy_class = &"berserker"
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
	visual.modulate = visual_color
	visual.play("idle")

func _start_attack() -> void:
	berserker_state = BerserkerState.ATTACK
	visual.modulate = Color(1.0, 0.15, 0.1, 1.0)
	visual.play("attack")
	AudioManager.play_berserker_attack()

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
	super()
