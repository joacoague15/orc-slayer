# scripts/archer.gd
extends "res://scripts/orc.gd"

signal arrow_shot(arrow: Area2D)

@export var arrow_scene: PackedScene
@export var archer_move_speed: float = 110.5
@export var archer_attack_range: float = 420.0
@export var arrow_speed: float = 520.0
@export var arrow_lifetime: float = 10.0
@export var shoot_windup: float = 0.5
@export var shoot_cooldown: float = 3.0
@export var muzzle_offset: Vector2 = Vector2(0.0, 66.0)

enum ArcherState {
	MOVING,
	WINDUP,
	COOLDOWN,
}

var archer_state: ArcherState = ArcherState.MOVING
var windup_timer: float = 0.0
var cooldown_timer: float = 0.0

@onready var telegraph_line: Line2D = $TelegraphLine

func _ready() -> void:
	super()
	move_speed = archer_move_speed
	_hide_telegraph()

func _physics_process(delta: float) -> void:
	if GameState.game_over:
		velocity = Vector2.ZERO
		return
	if is_dead:
		return
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		return
	
	match archer_state:
		ArcherState.MOVING:
			_process_moving()
		ArcherState.WINDUP:
			_process_windup(delta)
		ArcherState.COOLDOWN:
			_process_cooldown(delta)
	
	move_and_slide()
	_face_player()

func _process_moving() -> void:
	var to_player := player.global_position - global_position
	if to_player.length() <= archer_attack_range:
		_start_windup()
		return
	
	velocity = to_player.normalized() * archer_move_speed

func _start_windup() -> void:
	archer_state = ArcherState.WINDUP
	windup_timer = shoot_windup
	velocity = Vector2.ZERO
	visual.modulate = Color.RED
	_show_telegraph()

func _process_windup(delta: float) -> void:
	velocity = Vector2.ZERO
	windup_timer -= delta
	_update_telegraph()
	
	if windup_timer <= 0.0:
		_shoot_arrow()
		_hide_telegraph()
		visual.modulate = visual_color
		archer_state = ArcherState.COOLDOWN
		cooldown_timer = shoot_cooldown

func _process_cooldown(delta: float) -> void:
	velocity = Vector2.ZERO
	cooldown_timer -= delta
	if cooldown_timer <= 0.0:
		archer_state = ArcherState.MOVING

func _shoot_arrow() -> void:
	if not arrow_scene:
		return
	
	var muzzle_position := _get_muzzle_global_position()
	var shoot_direction := (player.global_position - muzzle_position).normalized()
	if shoot_direction == Vector2.ZERO:
		shoot_direction = Vector2.RIGHT
	
	var arrow := arrow_scene.instantiate()
	arrow.global_position = muzzle_position
	if arrow.has_method("setup"):
		arrow.setup(shoot_direction, arrow_speed, arrow_lifetime)
	get_tree().current_scene.add_child(arrow)
	AudioManager.play_archer_attack()
	_play_fire_animation()
	arrow_shot.emit(arrow)

func _play_fire_animation() -> void:
	visual.play("attack")
	visual.animation_finished.connect(_on_fire_animation_finished, CONNECT_ONE_SHOT)

func _on_fire_animation_finished() -> void:
	if is_dead:
		return
	visual.play("idle")

func _show_telegraph() -> void:
	telegraph_line.visible = true
	_update_telegraph()

func _hide_telegraph() -> void:
	telegraph_line.visible = false
	telegraph_line.clear_points()

func _update_telegraph() -> void:
	if not is_instance_valid(player):
		return
	var local_muzzle := to_local(_get_muzzle_global_position())
	var local_target := to_local(player.global_position)
	telegraph_line.clear_points()
	telegraph_line.add_point(local_muzzle)
	telegraph_line.add_point(local_target)

func _face_player() -> void:
	if is_instance_valid(player):
		visual.rotation = (player.global_position - global_position).angle() - PI / 2

func _get_muzzle_global_position() -> Vector2:
	return global_position + muzzle_offset.rotated(visual.rotation)

func die() -> void:
	_hide_telegraph()
	super()
